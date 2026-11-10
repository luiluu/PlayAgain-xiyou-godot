#!/usr/bin/env python3
"""event_probe 分段并行：分组均衡且不拆单元、拼回与单进程顺序逐字相同；仅用临时夹具。"""
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1] / '03_转换工具'
spec = importlib.util.spec_from_file_location('xiyou_sync', TOOLS / '同步正式西游.py')
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class SplitTests(unittest.TestCase):
    def test_balanced_keeps_units_and_order(self):
        weighted = [('m1', 5), ('m2', 1355), ('m3', 300), ('m4', 320), ('m5', 200), ('ce1', 1), ('ce2', 1)]
        groups = sync.split_balanced(weighted, 4)
        self.assertEqual(sorted(u for g in groups for u in g), sorted(u for u, _ in weighted))
        pos = {u: i for i, (u, _) in enumerate(weighted)}
        for g in groups:
            self.assertEqual(g, sorted(g, key=pos.get))
        self.assertEqual([g for g in groups if 'm2' in g], [['m2']])   # 最大的单元独占一组

    def test_fewer_units_than_shards(self):
        self.assertEqual(sync.split_balanced([('m1', 3)], 4), [['m1']])


class PresetsMergeTests(unittest.TestCase):
    """tools73：车道只改了 event_presets.json、main 又多了别的车道的预设行时，event_states.json 由车道结果＋main 结果按合并后预设顺序拼回。"""
    HEAD = {'sourceIdentity': {'releaseVersion': 'v0'}, 'setup': {'party': [1]}}

    def case(self, base, tag, preset, val=1):
        return {'id': base + '#' + tag, 'base': base, 'preset': preset, 'trace': [val]}

    def run_merge(self, tmp, order, lane, main, rows, head_main=None):
        paths = {}
        for name, doc in [('lane', dict(self.HEAD, cases=lane)), ('main', dict(head_main or self.HEAD, cases=main)),
                          ('presets', {'cases': rows})]:
            paths[name] = tmp / (name + '.json'); paths[name].write_text(json.dumps(doc, ensure_ascii=False))
        out = tmp / 'out.json'
        r = subprocess.run(['node', '-e', sync.PRESETS_MERGE_JS, str(out), json.dumps(order), str(paths['lane']), str(paths['main']), str(paths['presets'])],
                           capture_output=True, text=True)
        return r, out

    def test_lane_and_main_rows_are_stitched_in_presets_order(self):
        a, b, c = {'a': 1}, {'b': 2}, {'c': 3}
        rows = [{'base': 'x', 'tag': 'a', 'preset': a}, {'base': 'y', 'tag': 'b', 'preset': b}, {'base': 'z', 'tag': 'c', 'preset': c}]
        lane = [self.case('x', 'a', a), self.case('y', 'b', b, val=22)]          # 车道有 a、b
        main = [self.case('x', 'a', a), self.case('z', 'c', c)]                # main 有 a、c（c 是别的车道合进来的）
        with tempfile.TemporaryDirectory() as tmp:
            r, out = self.run_merge(Path(tmp), ['x#a', 'y#b', 'z#c'], lane, main, rows)
            self.assertEqual(r.returncode, 0, r.stderr)
            expect = [lane[0], lane[1], main[1]]
            self.assertEqual(out.read_text(), json.dumps(dict(self.HEAD, cases=expect), ensure_ascii=False, separators=(',', ':')))

    def test_rejects_when_a_row_has_no_matching_result(self):
        a, b = {'a': 1}, {'b': 2}
        rows = [{'base': 'x', 'tag': 'a', 'preset': a}, {'base': 'y', 'tag': 'b', 'preset': {'b': 3}}]   # 合并后 b 的预设与两边结果都对不上
        with tempfile.TemporaryDirectory() as tmp:
            r, _ = self.run_merge(Path(tmp), ['x#a', 'y#b'], [self.case('x', 'a', a), self.case('y', 'b', b)], [self.case('x', 'a', a)], rows)
            self.assertEqual(r.returncode, 3)
            self.assertIn('没有可用结果', r.stderr)

    def test_rejects_when_source_or_setup_differs(self):
        a = {'a': 1}
        rows = [{'base': 'x', 'tag': 'a', 'preset': a}]
        with tempfile.TemporaryDirectory() as tmp:
            r, _ = self.run_merge(Path(tmp), ['x#a'], [self.case('x', 'a', a)], [self.case('x', 'a', a)], rows,
                                  head_main={'sourceIdentity': {'releaseVersion': 'v1'}, 'setup': {'party': [1]}})
            self.assertEqual(r.returncode, 3)

    def test_tools_digest_can_skip_presets(self):
        self.assertEqual(sync.tools_digest(skip={sync.PRESETS_REL}), sync.tools_digest(skip={sync.PRESETS_REL}))
        self.assertNotEqual(sync.tools_digest(), sync.tools_digest(skip={sync.PRESETS_REL}))

class TroopShardMergeTests(unittest.TestCase):
    """GC：troop_event_probe 分段拼回（全局用例序号 % n）与单进程逐字相同；来源不一致、用例数对不上就失败。"""
    def merge(self, docs):
        with tempfile.TemporaryDirectory() as tmp:
            paths = []
            for i, d in enumerate(docs):
                p = Path(tmp) / ('p%d.json' % i); p.write_text(json.dumps(d, indent=1)); paths.append(str(p))
            out = Path(tmp) / 'out.json'
            r = subprocess.run(['node', '-e', sync.TROOP_MERGE_JS, str(out)] + paths, capture_output=True, text=True)
            return r, (out.read_text() if r.returncode == 0 else None)

    @staticmethod
    def case(i):
        return {'troop': i, 'actions': [], 'invokes': [], 'errors': [], 'turnCount': 2, 'phase': 'x', 'note': '中文%d' % i}

    def docs(self, total, n):
        head = {'sourceIdentity': {'releaseVersion': 'v'}, 'party': [1, 8], 'difficulty': 3}
        return [dict(head, cases=[self.case(k) for k in range(total) if k % n == i]) for i in range(n)]

    def test_merge_equals_single_process(self):
        for total, n in [(10, 3), (9, 3), (2, 4), (7, 1)]:
            r, text = self.merge(self.docs(total, n)[: min(n, total)] if total < n else self.docs(total, n))
            self.assertEqual(r.returncode, 0, r.stderr)
            single = dict(self.docs(total, 1)[0])
            self.assertEqual(text, json.dumps(single, indent=1, ensure_ascii=False), (total, n))

    def test_merge_rejects_mismatch(self):
        docs = self.docs(6, 2)
        docs[1]['difficulty'] = 4
        self.assertNotEqual(self.merge(docs)[0].returncode, 0)
        docs = self.docs(6, 2)
        docs[1]['cases'].append(self.case(99))   # 段 1 多一例：轮转的个数对不上
        self.assertNotEqual(self.merge(docs)[0].returncode, 0)

    def test_probe_shard_guard(self):
        src = (sync.HERE / 'mv_oracle/troop_event_probe.cjs').read_text()
        self.assertIn("process.env.XIYOU_PROBE_SHARD", src)
        self.assertIn("idx % SHARD.n !== SHARD.i", src)
        self.assertIn("XIYOU_PROBE_FROM", src)
        self.assertIn("XIYOU_COVER 记录的下标是全局的", src)


class TroopCaseIncrementalTests(unittest.TestCase):
    """tools-probe-deps2：troop 探针按用例增量。公共指纹不含用例清单；账与审计时机用假 node 走一遍；
    真 node 小样本（XIYOU_TROOP_LIMIT）验证取回、抽查不一致整份重跑、审计失败。"""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_core_key_ignores_cases_file_only(self):
        import sys
        sys.path.insert(0, str(TOOLS))
        from incremental_sync import ProbeCache
        r = Path(self.tmp.name)
        tools, app, gen = r / 'tools', r / 'app', r / 'gen'
        oracle = tools / 'mv_oracle'
        for d in (oracle / '.sandbox', gen / 'oracle', gen / 'maps', app):
            d.mkdir(parents=True)
        (app / 's.js').write_text('s'); (tools / 'xiyou_slice.json').write_text('{}')
        (gen / 'manifest.json').write_text('{}'); (gen / 'slice.json').write_text('{}')
        (oracle / 'troop_event_probe.cjs').write_text("require('./troop_event_cases.cjs'); require('./hboot.cjs');")
        (oracle / 'troop_event_cases.cjs').write_text('// cases v1')
        (oracle / 'hboot.cjs').write_text('// hboot v1')
        cmd = ['troop_event_probe.cjs']
        excl = {sync.TROOP_CASES_REL}

        def keys():
            c = ProbeCache(tools, app, gen)
            return c.key(cmd), c.key(cmd, exclude=excl, store=False)
        full0, core0 = keys()
        self.assertNotEqual(full0, core0)
        (oracle / 'troop_event_cases.cjs').write_text('// cases v2 加了一例')
        full1, core1 = keys()
        self.assertNotEqual(full0, full1)          # 完整键变了：要进探针
        self.assertEqual(core0, core1)             # 公共指纹没变：别的用例取回
        (oracle / 'hboot.cjs').write_text('// hboot v2')
        self.assertNotEqual(core1, keys()[1])      # helper 变了：全部重跑
        (oracle / 'hboot.cjs').write_text('// hboot v1')
        (oracle / 'troop_event_probe.cjs').write_text("require('./troop_event_cases.cjs'); require('./hboot.cjs'); // 改了记录")
        self.assertNotEqual(core1, keys()[1])      # 探针本体变了：全部重跑

    def test_audit_due(self):
        self.assertTrue(sync.troop_audit_due({}))
        self.assertTrue(sync.troop_audit_due({'auditedAt': 1000.0}, now=1000.0 + 25 * 3600))
        self.assertFalse(sync.troop_audit_due({'auditedAt': 1000.0}, now=1000.0 + 23 * 3600))
        with mock.patch.dict(os.environ, {'XIYOU_TROOP_AUDIT_HOURS': '0'}):
            self.assertFalse(sync.troop_audit_due({}))

    def run_flow(self, core, published_ok=True, now=None):
        """假 node：写结果文件和键表（键＝用例序号），记下收到的环境。"""
        import event_state_shards  # noqa: F401  (sync 里 import)
        seen = {}

        def fake(cmd, env, weight=None):
            seen.update(env)
            out = Path(env.get('XIYOU_TROOP_OUT') or sync.SANDBOX / 'troop_events.json')
            out.parent.mkdir(parents=True, exist_ok=True)
            reuse = 'XIYOU_TROOP_PREV' in env and env.get('XIYOU_TROOP_AUDIT') != '1'
            out.write_text('{"cases":[1,2,3]}')
            Path(env['XIYOU_TROOP_KEYS_OUT']).write_text(json.dumps(
                {'version': 1, 'core': env.get('XIYOU_TROOP_CORE'), 'keys': ['a#0', 'b#0', 'c#0'], 'reused': 2 if reuse else 0, 'checked': 1 if reuse else 0}))
            return subprocess.CompletedProcess(cmd, 0, '', '')
        gen = Path(self.tmp.name) / 'gen'
        (gen / 'oracle').mkdir(parents=True, exist_ok=True)
        env = {'XIYOU_GENERATED': str(gen)}
        with mock.patch.object(sync, 'run_node', fake):
            p = sync.run_troop_sharded(['troop_event_probe.cjs'], env, Path(self.tmp.name) / 'box', core)
        if published_ok:
            shutil.copy2(sync.SANDBOX / 'troop_events.json', gen / 'oracle/troop_events.json')
        return p, seen

    def test_ledger_flow(self):
        sandbox = Path(self.tmp.name) / 'sandbox'
        sandbox.mkdir()
        with mock.patch.object(sync, 'SANDBOX', sandbox), mock.patch.object(sync, 'TROOP_KEYS', sandbox / 'troop_event_keys.json'):
            # 第一次：账上没有 → 整份，记账，auditedAt 现在
            p1, e1 = self.run_flow('core1')
            self.assertNotIn('XIYOU_TROOP_PREV', e1)
            book = json.loads((sandbox / 'troop_event_keys.json').read_text())['entries']
            self.assertEqual(len(book), 1)
            self.assertEqual(book[0]['core'], 'core1')
            self.assertGreater(book[0]['auditedAt'], 0)
            # 第二次：同公共指纹、审计没到期 → 增量（有上次结果与键表，不审计）
            p2, e2 = self.run_flow('core1')
            self.assertIn('XIYOU_TROOP_PREV', e2)
            self.assertNotEqual(e2.get('XIYOU_TROOP_AUDIT'), '1')
            self.assertIn('按用例增量', p2.stdout)
            self.assertIn('取回 2 个', p2.stdout)
            book = json.loads((sandbox / 'troop_event_keys.json').read_text())['entries']
            self.assertEqual(len(book), 1)             # 同一份结果文件摘要，不重复
            # 公共指纹变了 → 整份
            p3, e3 = self.run_flow('core2')
            self.assertNotIn('XIYOU_TROOP_PREV', e3)
            self.assertIn('公共指纹变了', p3.stdout)
            # 审计到期 → 带审计标记、整份重跑，之后 auditedAt 更新
            entries = json.loads((sandbox / 'troop_event_keys.json').read_text())
            entries['entries'][-1]['auditedAt'] = 1.0
            (sandbox / 'troop_event_keys.json').write_text(json.dumps(entries))
            p4, e4 = self.run_flow('core2')
            self.assertEqual(e4.get('XIYOU_TROOP_AUDIT'), '1')
            self.assertIn('已超 24 小时', p4.stdout)
            self.assertGreater(json.loads((sandbox / 'troop_event_keys.json').read_text())['entries'][-1]['auditedAt'], 1e9)
            # 回退开关
            with mock.patch.dict(os.environ, {'XIYOU_TROOP_INCREMENTAL': '0'}):
                p5, e5 = self.run_flow('core2')
            self.assertNotIn('XIYOU_TROOP_PREV', e5)

    def test_ledger_carry_and_absorb(self):
        import sys
        sys.path.insert(0, str(TOOLS))
        import incremental_sync
        import event_state_shards as ess
        src, dst = Path(self.tmp.name) / 's', Path(self.tmp.name) / 'd'
        src.mkdir(); dst.mkdir()
        f1, f2 = Path(self.tmp.name) / 'k1.json', Path(self.tmp.name) / 'k2.json'
        f1.write_text(json.dumps({'version': 1, 'core': 'c', 'keys': ['a'], 'fileSha': 'a' * 64}))
        f2.write_text(json.dumps({'version': 1, 'core': 'c', 'keys': ['b'], 'fileSha': 'b' * 64}))
        ess.KeyHistory(src / 'troop_event_keys.json', 1).add(f1)
        self.assertIn('troop_event_keys.json', incremental_sync.carry_cache(src, dst))
        ess.KeyHistory(src / 'troop_event_keys.json', 1).add(f2)
        self.assertIn('troop_event_keys-merged', incremental_sync.carry_cache(src, dst))
        self.assertEqual(len(ess.KeyHistory(dst / 'troop_event_keys.json', 1)._load()), 2)
        self.assertEqual(ess.KeyHistory(dst / 'troop_event_keys.json', 2)._load(), [])   # 版本不同的不认

    def probe(self, out, limit, **extra):
        app = TOOLS.parent / '02_内容与素材/冻结正式源/app.nw'
        if not app.exists():
            self.skipTest('没有冻结正式源')
        sandbox = TOOLS / 'mv_oracle/.sandbox'
        d = sandbox / 'tt_troop_inc'
        d.mkdir(parents=True, exist_ok=True)
        self.addCleanup(shutil.rmtree, d, True)
        env = dict(os.environ, XIYOU_APP=str(app), XIYOU_TROOP_LIMIT=str(limit), XIYOU_TROOP_OUT=str(d / out),
                   XIYOU_TROOP_CORE='test-core', XIYOU_TROOP_CHECK_EVERY='100')
        for k in ('XIYOU_TROOP_PREV', 'XIYOU_TROOP_PREV_KEYS', 'XIYOU_TROOP_AUDIT', 'XIYOU_TROOP_INCREMENTAL'):
            env.pop(k, None)
        env.update(extra)
        r = subprocess.run(['node', 'troop_event_probe.cjs'], cwd=TOOLS / 'mv_oracle', env=env, capture_output=True, text=True, timeout=900)
        return r, d

    def test_real_probe_incremental_mismatch_and_audit(self):
        r1, d = self.probe('a.json', 5)
        self.assertEqual(r1.returncode, 0, r1.stderr[-800:])
        k1 = json.loads((d / 'a.keys.json').read_text())
        self.assertEqual((len(k1['keys']), k1['reused'], k1['checked']), (5, 0, 0))
        # 清单变长：前 5 例取回（抽查第 1 个），后 2 例新跑；结果与不取回的整份逐字相同
        env = {'XIYOU_TROOP_PREV': str(d / 'a.json'), 'XIYOU_TROOP_PREV_KEYS': str(d / 'a.keys.json')}
        r2, _ = self.probe('b.json', 7, **env)
        self.assertEqual(r2.returncode, 0, r2.stderr[-800:])
        k2 = json.loads((d / 'b.keys.json').read_text())
        self.assertEqual((len(k2['keys']), k2['reused'], k2['checked']), (7, 4, 1))
        r3, _ = self.probe('c.json', 7)
        self.assertEqual((d / 'b.json').read_text(), (d / 'c.json').read_text())
        self.assertEqual(k2['keys'], json.loads((d / 'c.keys.json').read_text())['keys'])
        # 公共指纹不同：不取回
        r4, _ = self.probe('e.json', 7, XIYOU_TROOP_CORE='other', **env)
        self.assertEqual(json.loads((d / 'e.keys.json').read_text())['reused'], 0)
        # 把上次结果里被抽查的第 0 例改坏：抽查发现不一致，整份重跑，结果仍与整份相同
        doc = json.loads((d / 'a.json').read_text())
        doc['cases'][0]['turnCount'] = 99
        (d / 'bad.json').write_text(json.dumps(doc, indent=1))
        keys = dict(k1, fileSha=hashlib_sha(d / 'bad.json'))
        (d / 'bad.keys.json').write_text(json.dumps(keys))
        r5, _ = self.probe('f.json', 7, XIYOU_TROOP_PREV=str(d / 'bad.json'), XIYOU_TROOP_PREV_KEYS=str(d / 'bad.keys.json'))
        self.assertEqual(r5.returncode, 0, r5.stderr[-800:])
        self.assertIn('TROOP_INCREMENTAL_MISMATCH', r5.stderr)
        self.assertEqual((d / 'f.json').read_text(), (d / 'c.json').read_text())
        self.assertEqual(json.loads((d / 'f.keys.json').read_text())['reused'], 0)
        # 审计：改坏的是第 3 例（抽查碰不到的），审计要失败（退出码 3）；没改坏的审计通过
        doc = json.loads((d / 'a.json').read_text())
        doc['cases'][3]['turnCount'] = 99
        (d / 'bad2.json').write_text(json.dumps(doc, indent=1))
        (d / 'bad2.keys.json').write_text(json.dumps(dict(k1, fileSha=hashlib_sha(d / 'bad2.json'))))
        r6, _ = self.probe('g.json', 7, XIYOU_TROOP_AUDIT='1', XIYOU_TROOP_PREV=str(d / 'bad2.json'), XIYOU_TROOP_PREV_KEYS=str(d / 'bad2.keys.json'))
        self.assertEqual(r6.returncode, 3)
        self.assertIn('TROOP_AUDIT_FAIL', r6.stderr)
        r7, _ = self.probe('h.json', 7, XIYOU_TROOP_AUDIT='1', **env)
        self.assertEqual(r7.returncode, 0, r7.stderr[-800:])
        self.assertIn('TROOP_AUDIT_OK', r7.stderr)
        self.assertEqual((d / 'h.json').read_text(), (d / 'c.json').read_text())


def hashlib_sha(path):
    import hashlib
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class StateShardMergeTests(unittest.TestCase):
    """BO：补跑事件状态探针.py 的分段拼回（序号轮转 i % n）与单进程顺序逐字相同；段数或来源对不上就失败。"""
    def load(self):
        spec = importlib.util.spec_from_file_location('state_probe', Path(__file__).resolve().parent / '补跑事件状态探针.py')
        mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        return mod

    def test_worktree_script_seeds_event_states(self):
        """GC：新建工作树.sh 在补跑前把主工作区 .sandbox 的 event_states*.json 克隆过来，且不覆盖已有的。"""
        text = (Path(__file__).resolve().parent / '新建工作树.sh').read_text()
        seed = text.index('for n in event_states.json event_states.keys.json')
        self.assertLess(text.index('--carry-cache'), seed)
        self.assertLess(seed, text.index('补跑事件状态探针.py'))
        self.assertIn('[[ -e $tools/mv_oracle/.sandbox/$n ||', text[seed:seed + 300])

    def test_changed_probe_needs_confirm_full(self):
        """GC：探针相对 main 改过时补跑只提示、不跑；--confirm-full 才跑；关守卫退回旧行为。"""
        import contextlib, io, sys
        from unittest import mock
        mod = self.load()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'node_modules').mkdir(); (root / 'gen/maps').mkdir(parents=True)
            ran = []
            def fake(env):
                ran.append(1)
                return subprocess.CompletedProcess([], 1, '', 'stop')
            cases = [(['x'], {}, ['03_转换工具/mv_oracle/event_state_probe.cjs'], False),
                     (['x', '--confirm-full'], {}, ['03_转换工具/mv_oracle/event_state_probe.cjs'], True),
                     (['x'], {'XIYOU_PROBE_CHANGE_GUARD': '0'}, ['03_转换工具/mv_oracle/event_state_probe.cjs'], True),
                     (['x'], {'XIYOU_CONFIRM_FULL': '1'}, ['03_转换工具/mv_oracle/event_state_probe.cjs'], True),
                     (['x'], {}, [], True)]
            for argv, env, changed, should_run in cases:
                ran.clear(); out = io.StringIO()
                with mock.patch.object(mod, 'ORACLE', root), mock.patch.object(mod, 'GEN', root / 'gen'), \
                        mock.patch.object(mod, 'OUT', root / 'none.json'), mock.patch.object(mod, 'run_probe', fake), \
                        mock.patch.object(mod, 'changed_probe_files', lambda base='main': changed), \
                        mock.patch.dict(os.environ, env), mock.patch.object(sys, 'argv', argv), contextlib.redirect_stdout(out):
                    rc = mod.main()
                self.assertEqual(bool(ran), should_run, (argv, env, changed))
                if not should_run:
                    self.assertEqual(rc, 0)
                    self.assertIn('--confirm-full', out.getvalue())

    def test_force_warns_that_it_runs_everything(self):
        """tools-merge-args3：--force 关增量整份重量，开跑前打一行提示；不加不提示。"""
        import contextlib, io, sys
        from unittest import mock
        mod = self.load()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'node_modules').mkdir(); (root / 'gen/maps').mkdir(parents=True)
            seen = {}
            def fake(env):
                seen['incremental'] = env.get('XIYOU_STATE_INCREMENTAL')
                return subprocess.CompletedProcess([], 1, '', 'stop')
            for argv, warn in [(['x', '--force'], True), (['x'], False)]:
                out = io.StringIO()
                with mock.patch.object(mod, 'ORACLE', root), mock.patch.object(mod, 'GEN', root / 'gen'), \
                     mock.patch.object(mod, 'needs', return_value=True), mock.patch.object(mod, 'run_probe', side_effect=fake), \
                     mock.patch.object(sys, 'argv', argv), mock.patch.object(mod, 'changed_probe_files', return_value=[]), contextlib.redirect_stdout(out):
                    self.assertEqual(mod.main(), 1)
                self.assertEqual('会关掉增量' in out.getvalue(), warn, out.getvalue())
                self.assertEqual(seen['incremental'], '0' if warn else None)

    def test_round_robin_merge_restores_order(self):
        mod = self.load()
        cases = [{'id': 'v%d' % i, 'finished': True} for i in range(7)]
        head = {'sourceIdentity': {'releaseVersion': 'v0'}, 'setup': {'party': [1]}}
        single = json.dumps(dict(head, cases=cases), ensure_ascii=False, separators=(',', ':'))
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            paths = []
            for i in range(3):
                p = tmp / ('p%d.json' % i)
                p.write_text(json.dumps(dict(head, cases=[c for k, c in enumerate(cases) if k % 3 == i]), ensure_ascii=False))
                paths.append(str(p))
            out = tmp / 'o.json'
            r = subprocess.run(['node', '-e', mod.SHARD_MERGE_JS, str(out)] + paths, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(out.read_text(), single)
            # 少一个用例（某段被截断）：拼不回就报错
            short = json.loads(Path(paths[1]).read_text()); short['cases'].pop()
            Path(paths[1]).write_text(json.dumps(short))
            r = subprocess.run(['node', '-e', mod.SHARD_MERGE_JS, str(out)] + paths, capture_output=True, text=True)
            self.assertNotEqual(r.returncode, 0)


ORACLE = TOOLS / 'mv_oracle'
APP = TOOLS.parent / '02_内容与素材/冻结正式源/app.nw'


@unittest.skipUnless((ORACLE / 'node_modules').exists() and APP.exists() and (TOOLS.parent / '01_Godot工程/modes/xiyou/generated/maps').exists(),
                     '需要参照引擎依赖、冻结正式源和转换产物（云端等没有就跳过）')
class StateIncrementalTests(unittest.TestCase):
    """BV：事件状态探针增量——摘要没变的变体原样取回，结果与整份重跑逐字节相同；旁边的 .keys.json 对不上就整份重跑。"""
    def run_probe(self, out, **env):
        e = dict(os.environ, XIYOU_EVENT_OUT=str(out), **env)
        e.pop('XIYOU_PROBE_SHARD', None)
        r = subprocess.run(['node', 'event_state_probe.cjs', 'm163e6p7#e8c', 'm163e6p7#e8d'], cwd=ORACLE, env=e, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr[-500:])
        return json.loads(r.stdout.strip().splitlines()[-1])

    def test_reuse_is_byte_identical_and_tampering_forces_rerun(self):
        sandbox = ORACLE / '.sandbox'
        sandbox.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=sandbox) as tmp:
            out = Path(tmp) / 'states.json'
            first = self.run_probe(out, XIYOU_STATE_INCREMENTAL='0')
            self.assertEqual(first['reused'], 0)
            full = out.read_bytes()
            second = self.run_probe(out)
            self.assertEqual(second['reused'], second['cases'])
            self.assertGreaterEqual(second['sampled'], 1)                     # 1% 自检至少抽 1 个
            self.assertEqual(out.read_bytes(), full)
            out.write_bytes(full.replace(b'"finished":true', b'"finished":false', 1))   # 上次的文件被改过：文件摘要对不上，整份重跑
            third = self.run_probe(out)
            self.assertEqual(third['reused'], 0)
            self.assertEqual(out.read_bytes(), full)


    def test_only_variants_on_changed_maps_rerun(self):
        """tools81：摘要按本例读到的地图算。换源只改了无关地图时全部取回；改了变体所在地图时只有它们重跑，结果照旧一致。"""
        sandbox = ORACLE / '.sandbox'
        sandbox.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=sandbox) as tmp:
            app = Path(tmp) / 'app.nw'
            subprocess.run(['cp', '-cR', str(APP.resolve()) + '/', str(app)], check=True)   # APFS 克隆，不占空间
            subprocess.run(['chmod', '-R', 'u+w', str(app)], check=True)   # 冻结源只读；只改克隆（新 inode），原件不动，也让临时目录删得掉
            out = Path(tmp) / 'states.json'
            first = self.run_probe(out, XIYOU_APP=str(app), XIYOU_STATE_INCREMENTAL='0')
            self.assertEqual(first['reused'], 0)
            cases = json.loads(out.read_text())['cases']
            keys = json.loads(out.with_suffix('.keys.json').read_text())
            self.assertEqual(keys['version'], 2)
            for c in cases:
                self.assertIn(163, keys['maps'][c['id']])
            unrelated = next(m for m in range(1, 200) if (app / ('data/Map%03d.json' % m)).is_file()
                             and all(m not in v for v in keys['maps'].values()))

            def touch(m):   # 末尾加一个换行：内容摘要变、JSON 不变
                f = app / ('data/Map%03d.json' % m)
                data = f.read_bytes()
                f.unlink()   # 先断开再写新文件
                f.write_bytes(data + b'\n')
            touch(unrelated)
            second = self.run_probe(out, XIYOU_APP=str(app))
            self.assertEqual(second['reused'], second['cases'])
            self.assertEqual(json.loads(out.read_text())['cases'], cases)
            touch(163)
            third = self.run_probe(out, XIYOU_APP=str(app))
            self.assertEqual(third['reused'], 0)
            self.assertEqual(json.loads(out.read_text())['cases'], cases)


    def test_sync_sharded_run_reuses_from_published_result_via_history(self):
        """tools81：同步的分段路径——上次已发布的结果＋摘要账认领 → 第二轮全部取回、结果逐字相同；账上没有就整份重量。"""
        import sys
        sys.path.insert(0, str(TOOLS))
        import event_state_shards as ess
        sandbox = ORACLE / '.sandbox'
        sandbox.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=sandbox) as tmp:
            tmp = Path(tmp)
            published, history = tmp / 'gen/event_states.json', ess.KeyHistory(tmp / 'keys-history.json')
            env = dict(os.environ)
            env.pop('XIYOU_PROBE_SHARD', None)

            def launch(e, label):
                return subprocess.run(['node', 'event_state_probe.cjs', 'm163e6p7#e8c', 'm163e6p7#e8d'], cwd=ORACLE, env=e,
                                      capture_output=True, text=True)

            def one_round():
                e = dict(env)
                ok = ess.prepare_prev(e, history, published, tmp / 'work')
                out, keys = tmp / 'out.json', tmp / 'work/keys.json'
                r = ess.run_sharded(e, ORACLE, tmp / 'work', out, keys, 2, launch)
                self.assertEqual(r.returncode, 0, r.stdout[-500:] + r.stderr[-500:])
                self.assertTrue(history.add(keys))
                published.parent.mkdir(exist_ok=True)
                published.write_bytes(out.read_bytes())   # 「发布」
                stats = [json.loads(l) for l in r.stdout.splitlines() if l.startswith('{"version"')]
                return ok, sum(x['reused'] for x in stats), sum(x['cases'] for x in stats), out.read_bytes()
            (tmp / 'work').mkdir()
            ok1, reused1, n1, first = one_round()
            self.assertEqual((ok1, reused1, n1), (False, 0, 2))
            ok2, reused2, n2, second = one_round()
            self.assertEqual((ok2, reused2, n2), (True, 2, 2))
            self.assertEqual(second, first)
            published.write_bytes(first.replace(b'"finished":true', b'"finished":false', 1))   # 发布的那份被改过：账上认不出
            self.assertFalse(ess.prepare_prev(dict(env), history, published, tmp / 'work'))


class StateScopeTests(unittest.TestCase):
    """tools-probe-deps2 阶段②：事件状态探针本文件的指纹按 probe_change_scope.json 折算、每日审计。临时拷一份探针目录，改一行让文件 SHA 变。"""
    PREFIXES = ['m163e6p7#e8c', 'ce820#e8c']     # 前者预设只有 variables，后者带 actors

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        if not APP.exists():
            self.skipTest('没有冻结正式源')
        self.tools = Path(self.tmp.name) / 'tools'
        self.mo = self.tools / 'mv_oracle'
        self.mo.mkdir(parents=True)
        for f in ORACLE.glob('*.cjs'):
            shutil.copy2(f, self.mo / f.name)
        subprocess.run(['cp', '-cR', str(ORACLE / 'node_modules'), str(self.mo / 'node_modules')], check=True)
        for n in ('xiyou_slice.json', 'event_presets.json'):
            shutil.copy2(TOOLS / n, self.tools / n)
        self.probe = self.mo / 'event_state_probe.cjs'

    def sha(self):
        import hashlib
        return hashlib.sha256(self.probe.read_bytes()).hexdigest()

    def scope(self, rows):
        (self.tools / 'probe_change_scope.json').write_text(json.dumps({'changes': rows}))

    def run_probe(self, out, **env):
        e = dict(os.environ, XIYOU_EVENT_OUT=str(out), XIYOU_APP=str(APP.resolve()), XIYOU_GENERATED=str(TOOLS.parent / '01_Godot工程/modes/xiyou/generated'), **env)
        for k in ('XIYOU_PROBE_SHARD', 'XIYOU_STATE_PREV', 'XIYOU_STATE_PREV_KEYS', 'XIYOU_STATE_AUDIT'):
            if k not in env:
                e.pop(k, None)
        return subprocess.run(['node', 'event_state_probe.cjs'] + self.PREFIXES, cwd=self.mo, env=e, capture_output=True, text=True)

    def stats(self, r):
        self.assertEqual(r.returncode, 0, r.stderr[-600:])
        return json.loads(r.stdout.strip().splitlines()[-1])

    def test_scope_declaration_and_audit(self):
        sb = self.mo / '.sandbox'
        sb.mkdir(exist_ok=True)
        out0 = sb / 'o0.json'
        first = self.stats(self.run_probe(out0, XIYOU_STATE_INCREMENTAL='0'))
        n = first['cases']
        presets = {'%s#%s' % (c['base'], c['tag']): c['preset'] for c in json.loads((self.tools / 'event_presets.json').read_text())['cases']}
        n_actors = sum('actors' in presets[c['id']] for c in json.loads(out0.read_text())['cases'])
        self.assertTrue(n >= 3 and 0 < n_actors < n, (n, n_actors))
        keys0 = sb / 'o0.keys.json'
        s0 = self.sha()
        prev = {'XIYOU_STATE_PREV': str(out0), 'XIYOU_STATE_PREV_KEYS': str(keys0)}
        # 探针没改：全部取回
        self.assertEqual(self.stats(self.run_probe(sb / 'o1.json', **prev))['reused'], n)
        # 改一行（文件 SHA 变），没有声明：全部重跑
        self.probe.write_text(self.probe.read_text() + '\n// 改了一行\n')
        s1 = self.sha()
        self.assertNotEqual(s0, s1)
        self.assertEqual(self.stats(self.run_probe(sb / 'o2.json', **prev))['reused'], 0)
        # 声明不影响任何变体：全部取回，结果逐字相同
        row = {'file': 'mv_oracle/event_state_probe.cjs', 'from': s0, 'to': s1, 'presetKeys': [], 'why': '测试'}
        self.scope([row])
        r3 = self.stats(self.run_probe(sb / 'o3.json', **prev))
        self.assertEqual(r3['reused'], n)
        self.assertEqual((sb / 'o3.json').read_bytes(), out0.read_bytes())
        # 声明影响 actors：带 actors 的变体重跑，另一个取回
        self.scope([dict(row, presetKeys=['actors'])])
        self.assertEqual(self.stats(self.run_probe(sb / 'o4.json', **prev))['reused'], n - n_actors)
        # 声明只能折算到 to：to 对不上当前文件就不生效
        self.scope([dict(row, to='0' * 63 + '1')])
        self.assertEqual(self.stats(self.run_probe(sb / 'o5.json', **prev))['reused'], 0)
        # 最新声明的键在任何变体的预设键路径里都没有（拼错、数字键没写 *）：报错，不当成「不影响任何变体」（审查 76 P3-2）
        for bad_keys in (['nonexistent'], ['actor'], ['actors.79'], ['actors', 'nonexistent']):
            self.scope([dict(row, presetKeys=bad_keys)])
            rb = self.run_probe(sb / 'o5b.json', **prev)
            self.assertNotEqual(rb.returncode, 0, bad_keys)
            self.assertIn('presetKeys', rb.stderr, bad_keys)
        # 只查最新那条（to＝当前 SHA）：旧条目里的键对不上不报错
        old_row = {'file': 'mv_oracle/event_state_probe.cjs', 'from': '0' * 63 + '2', 'to': s0, 'presetKeys': ['nonexistent'], 'why': '旧条目'}
        self.scope([old_row, dict(row, presetKeys=['actors.*'])])
        self.assertEqual(self.stats(self.run_probe(sb / 'o5c.json', **prev))['reused'], n - n_actors)
        # 格式错直接报错，不静默忽略
        self.scope([{'file': 'mv_oracle/event_state_probe.cjs', 'from': s0, 'to': s1, 'why': '缺 presetKeys'}])
        self.assertNotEqual(self.run_probe(sb / 'o6.json', **prev).returncode, 0)
        # 审计：把上次结果里第二个变体改坏。不审计时只抽查第一个，发现不了；审计整份重跑并逐个比对，退出码 3
        self.scope([dict(row, presetKeys=[])])
        doc = json.loads(out0.read_text())
        doc['cases'][1]['finished'] = not doc['cases'][1]['finished']
        bad = sb / 'bad.json'
        bad.write_text(json.dumps(doc))
        import hashlib
        badkeys = json.loads(keys0.read_text())
        badkeys['fileSha'] = hashlib.sha256(bad.read_bytes()).hexdigest()
        (sb / 'bad.keys.json').write_text(json.dumps(badkeys))
        badprev = {'XIYOU_STATE_PREV': str(bad), 'XIYOU_STATE_PREV_KEYS': str(sb / 'bad.keys.json')}
        self.assertEqual(self.stats(self.run_probe(sb / 'o7.json', **badprev))['reused'], n)    # 抽查碰不到：坏结果被取回
        r8 = self.run_probe(sb / 'o8.json', XIYOU_STATE_AUDIT='1', **badprev)
        self.assertEqual(r8.returncode, 3)
        self.assertIn('STATE_AUDIT_FAIL', r8.stderr)
        r9 = self.run_probe(sb / 'o9.json', XIYOU_STATE_AUDIT='1', **prev)
        self.assertEqual(self.stats(r9)['reused'], 0)
        self.assertIn('STATE_AUDIT_OK', r9.stderr)
        self.assertEqual((sb / 'o9.json').read_bytes(), out0.read_bytes())

    def test_state_audit_due(self):
        self.assertFalse(sync.state_audit_due(None))
        self.assertFalse(sync.state_audit_due({}))                                     # 旧条目没有 auditedAt：不算到期
        self.assertTrue(sync.state_audit_due({'auditedAt': 1.0}, now=1.0 + 25 * 3600))
        self.assertFalse(sync.state_audit_due({'auditedAt': 1.0}, now=1.0 + 23 * 3600))
        with mock.patch.dict(os.environ, {'XIYOU_STATE_AUDIT_HOURS': '0'}):
            self.assertFalse(sync.state_audit_due({'auditedAt': 1.0}, now=1e12))


class ProgressTests(unittest.TestCase):
    """tools83：分段跑事件状态探针期间定期打进度，免得整份重量跑近一小时没输出被会话 idle 超时掐掉。"""
    def setUp(self):
        import sys
        sys.path.insert(0, str(TOOLS))
        import event_state_shards
        self.ess = event_state_shards

    def test_heartbeat_lines_while_running_and_on_each_shard(self):
        import io, time
        buf = io.StringIO()
        with self.ess.Progress(3, interval=0.05, out=buf) as prog:
            # 等到至少 3 拍再收（最多 5 秒）：launchd 后台低优先级调度时 0.3 秒固定等待只出 2 拍（总装三十一 11-07 复现）
            # 只设上限（防死等），不靠墙钟断言：等到 3 拍为止，高负载下慢一点也只是多等
            deadline = time.monotonic() + 60
            while buf.getvalue().count('还在跑') < 3 and time.monotonic() < deadline:
                time.sleep(0.05)
            before = buf.getvalue().splitlines()
            prog.done(0)
        lines = buf.getvalue().splitlines()
        self.assertIn('开始，3 段并行', lines[0])
        beats = [l for l in before if '还在跑' in l]       # done 之前的心跳
        self.assertGreaterEqual(len(beats), 3, lines)
        self.assertTrue(all('0/3 段完成' in l for l in beats), beats)
        self.assertTrue(any('1/3 段完成（第 1 段刚结束）' in l for l in lines), lines)
        n = len(lines)
        time.sleep(0.2)
        self.assertEqual(len(buf.getvalue().splitlines()), n, '退出后心跳线程要停')

    def test_interval_zero_prints_nothing(self):
        import io, time
        buf = io.StringIO()
        with self.ess.Progress(2, interval=0, out=buf) as prog:
            time.sleep(0.1)
            prog.done(1)
        self.assertEqual(buf.getvalue(), '')

    def test_env_sets_interval_and_zero_turns_off(self):
        from unittest import mock
        with mock.patch.dict(os.environ, {'XIYOU_STATE_PROGRESS_SECS': '7.5'}):
            self.assertEqual(self.ess.Progress(1).interval, 7.5)
        with mock.patch.dict(os.environ, {'XIYOU_STATE_PROGRESS_SECS': '0'}):
            self.assertEqual(self.ess.Progress(1).interval, 0)
        with mock.patch.dict(os.environ, {'XIYOU_STATE_PROGRESS_SECS': '乱写'}):
            self.assertEqual(self.ess.Progress(1).interval, self.ess.PROGRESS_SECS)
        os.environ.pop('XIYOU_STATE_PROGRESS_SECS', None)
        self.assertEqual(self.ess.Progress(1).interval, 60)

    @unittest.skipUnless(shutil.which('node'), '没有 node')
    def test_run_sharded_prints_progress_and_result_unchanged(self):
        """真走 run_sharded：假探针睡一会儿再写分段结果；心跳打在标准输出，拼回的结果与不开心跳时逐字相同。"""
        import contextlib, io, sys, time
        from unittest import mock

        def launch(e, label):
            # 等到心跳线程至少打出一拍再结束（开了心跳时），不靠固定睡眠
            deadline = time.monotonic() + 60
            while os.environ.get('XIYOU_STATE_PROGRESS_SECS') != '0' and '还在跑' not in cur[0].getvalue() and time.monotonic() < deadline:
                time.sleep(0.02)
            part = {'sourceIdentity': 's', 'setup': {}, 'cases': [{'id': '%s-%d' % (label[-3:].strip('/'), k)} for k in range(2)]}
            Path(e['XIYOU_EVENT_OUT']).write_text(json.dumps(part))
            return subprocess.CompletedProcess(['fake'], 0, '', '')
        results = []
        cur = [io.StringIO()]
        for secs in ('0.05', '0'):
            with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {'XIYOU_STATE_PROGRESS_SECS': secs}):
                tmp = Path(tmp)
                buf = io.StringIO()
                cur[0] = buf
                with contextlib.redirect_stdout(buf):
                    r = self.ess.run_sharded(dict(os.environ), tmp, tmp / 'work', tmp / 'out.json', tmp / 'keys.json', 2, launch)
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
                results.append(((tmp / 'out.json').read_text(), buf.getvalue()))
        (with_beat, text_on), (without, text_off) = results
        self.assertEqual(with_beat, without)
        self.assertIn('2 段并行', text_on)
        self.assertIn('还在跑', text_on)
        self.assertIn('2/2 段完成', text_on)
        self.assertEqual(text_off, '')

    def test_single_shard_also_reports(self):
        import contextlib, io, time
        from unittest import mock

        cur = [io.StringIO()]

        def launch(e, label):
            deadline = time.monotonic() + 60
            while '开始' not in cur[0].getvalue() and time.monotonic() < deadline:
                time.sleep(0.02)
            return subprocess.CompletedProcess(['fake'], 0, 'ok', '')
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {'XIYOU_STATE_PROGRESS_SECS': '0.05'}):
            tmp = Path(tmp)
            buf = io.StringIO()
            cur[0] = buf
            with contextlib.redirect_stdout(buf):
                r = self.ess.run_sharded(dict(os.environ), tmp, tmp / 'work', tmp / 'out.json', tmp / 'keys.json', 1, launch)
        self.assertEqual(r.stdout, 'ok')
        self.assertIn('1 段并行', buf.getvalue())
        self.assertIn('1/1 段完成', buf.getvalue())


class StateKeysTests(unittest.TestCase):
    """tools81：分段摘要合并、摘要账（按结果文件摘要认领、只留最近几份、新建工作树带账时合并）。"""
    def setUp(self):
        import sys
        sys.path.insert(0, str(TOOLS))
        import event_state_shards
        self.ess = event_state_shards
        self.tmpdir = tempfile.TemporaryDirectory()
        self.tmp = Path(self.tmpdir.name)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_merge_keys_unions_parts_and_rejects_mixed_fingerprints(self):
        out = self.tmp / 'out.json'
        out.write_text('{"cases":[]}')
        a, b = self.tmp / 'a.json', self.tmp / 'b.json'
        a.write_text(json.dumps({'version': 2, 'coreFingerprint': 'x', 'keys': {'v0': 'k0'}, 'maps': {'v0': [3]}}))
        b.write_text(json.dumps({'version': 2, 'coreFingerprint': 'x', 'keys': {'v1': 'k1'}, 'maps': {'v1': [4, 9]}}))
        self.assertTrue(self.ess.merge_keys([a, b], out, self.tmp / 'k.json'))
        doc = json.loads((self.tmp / 'k.json').read_text())
        self.assertEqual((doc['keys'], doc['maps'], doc['fileSha']), ({'v0': 'k0', 'v1': 'k1'}, {'v0': [3], 'v1': [4, 9]}, self.ess.file_sha(out)))
        b.write_text(json.dumps({'version': 2, 'coreFingerprint': 'y', 'keys': {}, 'maps': {}}))
        self.assertFalse(self.ess.merge_keys([a, b], out, self.tmp / 'k2.json'))
        self.assertFalse((self.tmp / 'k2.json').exists())

    def test_history_finds_by_result_sha_keeps_recent_and_absorbs(self):
        h = self.ess.KeyHistory(self.tmp / 'h.json')
        results = []
        for i in range(self.ess.KEEP + 2):
            r = self.tmp / ('r%d.json' % i)
            r.write_text('{"n":%d}' % i)
            k = self.tmp / ('k%d.json' % i)
            k.write_text(json.dumps({'version': 2, 'fileSha': self.ess.file_sha(r), 'keys': {'i': str(i)}, 'maps': {}}))
            self.assertTrue(h.add(k))
            results.append(r)
        self.assertIsNone(h.find(results[0]))                      # 最早的两份挤掉了
        self.assertEqual(h.find(results[-1])['keys'], {'i': str(self.ess.KEEP + 1)})
        other = self.ess.KeyHistory(self.tmp / 'other.json')
        k = self.tmp / 'ko.json'
        r = self.tmp / 'ro.json'
        r.write_text('{"main":1}')
        k.write_text(json.dumps({'version': 2, 'fileSha': self.ess.file_sha(r), 'keys': {}, 'maps': {}}))
        other.add(k)
        self.assertEqual(h.absorb(other.path), 1)
        self.assertIsNotNone(h.find(r))
        self.assertEqual(h.absorb(other.path), 0)
        bad = self.tmp / 'bad.json'
        bad.write_text(json.dumps({'version': 1, 'keys': {}}))     # 旧版摘要（没有地图）不进账
        self.assertFalse(h.add(bad))

    def test_carry_cache_brings_and_merges_key_history(self):
        sys_path = str(TOOLS)
        import sys
        if sys_path not in sys.path:
            sys.path.insert(0, sys_path)
        import incremental_sync
        src, dst = self.tmp / 'main', self.tmp / 'lane'
        src.mkdir()
        r = self.tmp / 'r.json'
        r.write_text('{}')
        k = self.tmp / 'k.json'
        k.write_text(json.dumps({'version': 2, 'fileSha': self.ess.file_sha(r), 'keys': {}, 'maps': {}}))
        self.ess.KeyHistory(src / 'event_state_keys.json').add(k)
        self.assertIn('event_state_keys.json', incremental_sync.carry_cache(src, dst))
        self.assertIsNotNone(self.ess.KeyHistory(dst / 'event_state_keys.json').find(r))
        r2 = self.tmp / 'r2.json'
        r2.write_text('{"x":2}')
        k.write_text(json.dumps({'version': 2, 'fileSha': self.ess.file_sha(r2), 'keys': {}, 'maps': {}}))
        self.ess.KeyHistory(src / 'event_state_keys.json').add(k)
        self.assertIn('event_state_keys-merged', incremental_sync.carry_cache(src, dst))   # 车道已有账：合并，不覆盖
        self.assertIsNotNone(self.ess.KeyHistory(dst / 'event_state_keys.json').find(r2))


class MergeTests(unittest.TestCase):
    def test_merge_restores_single_process_order(self):
        cases = [{'id': 'm7e1p0', 'kind': 'map', 'map': 7}, {'id': 'm7e2p0', 'kind': 'map', 'map': 7},
                 {'id': 'm3e1p0', 'kind': 'map', 'map': 3}, {'id': 'ce5', 'kind': 'common', 'map': 4, 'common': 5},
                 {'id': 'ce2', 'kind': 'common', 'map': 4, 'common': 2}]
        order = ['m7', 'm3', 'ce5', 'ce2']
        head = {'sourceIdentity': {'releaseVersion': 'v0'}, 'setup': {'party': [1]}}
        single = json.dumps(dict(head, cases=cases), ensure_ascii=False, separators=(',', ':'))
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            parts = [[cases[2], cases[4]], [cases[0], cases[1], cases[3]]]   # 分组后各段只含自己的单元
            paths = []
            for i, part in enumerate(parts):
                p = tmp / ('p%d.json' % i)
                p.write_text(json.dumps(dict(head, cases=part), ensure_ascii=False))
                paths.append(str(p))
            out = tmp / 'events.json'
            r = subprocess.run(['node', '-e', sync.EVENT_MERGE_JS, str(out), json.dumps(order)] + paths,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(out.read_text(), single)

    def test_merge_rejects_mismatched_setup(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            a, b = tmp / 'a.json', tmp / 'b.json'
            a.write_text(json.dumps({'sourceIdentity': {}, 'setup': {'x': 1}, 'cases': []}))
            b.write_text(json.dumps({'sourceIdentity': {}, 'setup': {'x': 2}, 'cases': []}))
            r = subprocess.run(['node', '-e', sync.EVENT_MERGE_JS, str(tmp / 'o.json'), '[]', str(a), str(b)],
                               capture_output=True, text=True)
            self.assertNotEqual(r.returncode, 0)


ROUND = importlib.util.spec_from_file_location('preset_round', TOOLS / '事件预设加一轮.py')
preset_round = importlib.util.module_from_spec(ROUND)
ROUND.loader.exec_module(preset_round)
PROBE = TOOLS / 'mv_oracle/event_state_probe.cjs'
COMPARE = TOOLS.parent / '01_Godot工程/tests/xiyou_event_compare.gd'


class PresetKeysTests(unittest.TestCase):
    """tools75：两边预设键白名单一致（含 playtime），参照侧 playtime 按 秒×60 设 frameCount、只收非负整数。"""

    def test_whitelists_match_and_have_playtime(self):
        import re
        js = re.search(r"const PRESET_KEYS = \[([^\]]*)\]", PROBE.read_text())[1]
        gd = re.search(r'const PRESET_KEYS := \[([^\]]*)\]', COMPARE.read_text())[1]
        keys = lambda t: sorted(re.findall(r"""['"]([A-Za-z_]+)['"]""", t))
        self.assertEqual(keys(js), keys(gd))
        self.assertIn('playtime', keys(js))

    def run_apply(self, preset):
        src = PROBE.read_text()
        start = src.index('function applyPreset(p) {')
        body = src[start:src.index('\n}\n', start) + 3]
        keys = src[src.index('const PRESET_KEYS'):src.index('\n', src.index('const PRESET_KEYS'))]
        js = keys + '\nconst w = {Graphics: {frameCount: 0}};\n' + body + (
            '\ntry { applyPreset(%s); console.log(JSON.stringify({fc: w.Graphics.frameCount, pt: Math.floor(w.Graphics.frameCount / 60)})); }'
            ' catch (e) { console.log(JSON.stringify({err: e.message})); }\nprocess.exit(0);' % json.dumps(preset))
        r = subprocess.run(['node', '-e', js], capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout)

    def test_probe_playtime_sets_frame_count(self):
        self.assertEqual(self.run_apply({'playtime': 30}), {'fc': 1800, 'pt': 30})
        self.assertEqual(self.run_apply({}), {'fc': 0, 'pt': 0})

    def test_probe_playtime_rejects_fraction_and_negative(self):
        self.assertIn('playtime', self.run_apply({'playtime': 1.5}).get('err', ''))
        self.assertIn('playtime', self.run_apply({'playtime': -1}).get('err', ''))

    def test_regression_variants_present(self):
        cases = json.loads((TOOLS / 'event_presets.json').read_text())['cases']
        got = {c['tag']: c['preset'] for c in cases if c['base'] == 'm187e3p1'}
        self.assertEqual(got.get('t75'), {'playtime': 30})   # 边界：30－0≥30，进收获分支，变量 321＝playtime
        # 29－(－1)≥30：游玩秒数和变量一起进脚本条件（单 29 秒走「30 秒后再来」，一条效果都不走，空绿扫描 --check 不收）
        self.assertEqual(got.get('t75b'), {'playtime': 29, 'variables': {'321': -1}})


class PresetContributionReportTests(unittest.TestCase):
    """tools75：事件预设加一轮.py --report 按 tag 前缀统计新增与独有，列零贡献，不改预设。"""
    BY_CASE = {
        'm1e1p0': ['m1e1p0:0', 'm1e1p0:1'],
        'm1e1p0#o4': ['m1e1p0:0', 'm1e1p0:1', 'm1e1p0:5'],
        'm1e1p0#o4_2': ['m1e1p0:0', 'm1e1p0:1', 'm1e1p0:5'],      # 新增 1、被 o4 覆盖 → 独有 0
        'm1e1p0#o4_3': ['m1e1p0:0'],                              # 零贡献
        'ce9': ['ce9:0'],
        'ce9#e8b2': ['ce9:0', 'ce9:3', 'ce9:4'],
        'ce7#a1': ['ce7:0'],                                      # 基础用例不在覆盖里
    }

    def test_groups(self):
        self.assertEqual([preset_round.tag_group(t) for t in ('o4_3', 'o4', 'e8b2', 'e8b', 'a1', 'e8', 't75b')],
                         ['o4', 'o4', 'e8b', 'e8b', 'a1', 'e8', 't75b'])

    def test_contribution_and_report(self):
        rows = {r['id']: r for r in preset_round.contribution(self.BY_CASE)}
        self.assertEqual((rows['m1e1p0#o4']['new'], rows['m1e1p0#o4']['own']), (1, 0))
        self.assertEqual((rows['m1e1p0#o4_2']['new'], rows['m1e1p0#o4_2']['own']), (1, 0))
        self.assertEqual(rows['m1e1p0#o4_3']['new'], 0)
        self.assertEqual((rows['ce9#e8b2']['new'], rows['ce9#e8b2']['own']), (2, 2))
        self.assertTrue(rows['ce7#a1']['base_missing'])
        groups = {g['group']: g for g in preset_round.report(list(rows.values()))}
        self.assertEqual(groups['o4'], {'group': 'o4', 'variants': 3, 'new': 2, 'own': 0, 'zero': 1, 'zero_own': 3})
        self.assertEqual(groups['e8b']['own'], 2)
        only = preset_round.contribution(self.BY_CASE, ('e8',))
        self.assertEqual([r['id'] for r in only], ['ce9#e8b2'])

    def test_report_cli_does_not_touch_presets(self):
        before = (TOOLS / 'event_presets.json').read_bytes()
        with tempfile.TemporaryDirectory() as td:
            cov, out = Path(td) / 'cov.json', Path(td) / 'rep.json'
            cov.write_text(json.dumps({'executed': [], 'byCase': self.BY_CASE}))
            r = subprocess.run(['python3', str(TOOLS / '事件预设加一轮.py'), '--report', str(cov), '--json', str(out)],
                               capture_output=True, text=True, timeout=60)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn('m1e1p0#o4_3', r.stdout)
            self.assertEqual(json.loads(out.read_text())['groups'][0]['group'], 'o4')
        self.assertEqual((TOOLS / 'event_presets.json').read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
