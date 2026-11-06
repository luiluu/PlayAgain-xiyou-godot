#!/usr/bin/env python3
"""event_probe 分段并行：分组均衡且不拆单元、拼回与单进程顺序逐字相同；仅用临时夹具。"""
import importlib.util
import json
import os
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
        self.assertEqual(got.get('t75b'), {'playtime': 29})  # 差一秒：走「30 秒后再来」


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
