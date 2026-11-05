#!/usr/bin/env python3
"""event_probe 分段并行：分组均衡且不拆单元、拼回与单进程顺序逐字相同；仅用临时夹具。"""
import importlib.util
import json
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


if __name__ == '__main__':
    unittest.main()
