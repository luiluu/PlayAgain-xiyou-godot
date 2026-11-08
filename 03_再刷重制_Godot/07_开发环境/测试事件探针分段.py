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
                     mock.patch.object(sys, 'argv', argv), contextlib.redirect_stdout(out):
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
            deadline = time.monotonic() + 5
            while buf.getvalue().count('还在跑') < 3 and time.monotonic() < deadline:
                time.sleep(0.05)
            prog.done(0)
        lines = buf.getvalue().splitlines()
        self.assertIn('开始，3 段并行', lines[0])
        beats = [l for l in lines if '还在跑' in l]
        self.assertGreaterEqual(len(beats), 3, lines)
        self.assertTrue(all('0/3 段完成' in l for l in beats), beats)
        self.assertIn('1/3 段完成（第 1 段刚结束）', lines[-1])
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
            time.sleep(0.25)
            part = {'sourceIdentity': 's', 'setup': {}, 'cases': [{'id': '%s-%d' % (label[-3:].strip('/'), k)} for k in range(2)]}
            Path(e['XIYOU_EVENT_OUT']).write_text(json.dumps(part))
            return subprocess.CompletedProcess(['fake'], 0, '', '')
        results = []
        for secs in ('0.05', '0'):
            with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {'XIYOU_STATE_PROGRESS_SECS': secs}):
                tmp = Path(tmp)
                buf = io.StringIO()
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

        def launch(e, label):
            time.sleep(0.2)
            return subprocess.CompletedProcess(['fake'], 0, 'ok', '')
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {'XIYOU_STATE_PROGRESS_SECS': '0.05'}):
            tmp = Path(tmp)
            buf = io.StringIO()
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
