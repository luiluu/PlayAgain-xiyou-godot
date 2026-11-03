#!/usr/bin/env python3
"""扫描_flags整数查找.py 的回归：审查 34 P2-2 的写法必须报，归一过的写法不报（tools53）。"""
import importlib.util
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('scan', HERE / '扫描_flags整数查找.py')
scan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scan)

GD = '''class_name XFoo

static func chart(s: XState) -> Dictionary:
	var c: Dictionary = s.flags["_chart"]
	return c


static func wrap(s: XState) -> Dictionary:
	return chart(s)


static func is_roster(s: XState, t) -> bool:
	var c := wrap(s)
	return t != null and (c.roster as Array).slice(0, 3).has(int(t.actor_id))


static func toggle(s: XState, id: int) -> void:
	var c := chart(s)
	var i: int = c.roster.find(id)


static func by_name(s: XState, w: String) -> bool:
	var k: Array = s.flags.get("_k", [])
	return k.has("a") or k.has(str(w)) or k.has(float(w))


static func clean(s: XState, id: int) -> bool:
	var arr := []
	return arr.has(id)
'''


class ScanTests(unittest.TestCase):
    def run_scan(self, show_all=False):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'modes').mkdir()
            (root / 'modes' / 'foo.gd').write_text(GD, encoding='utf-8')
            files = {p: p.read_text(encoding='utf-8').splitlines() for p in (root / 'modes').rglob('*.gd')}
            sources = scan.source_functions(files)
            hits = {}
            for lines in files.values():
                for name, _, body in scan.functions(lines):
                    hits[name] = scan.scan_function(body, sources, show_all)
            return sources, hits

    def test_sources_follow_returns_and_wrappers(self):
        sources, _ = self.run_scan()
        self.assertTrue({'chart', 'wrap'} <= sources)
        self.assertNotIn('clean', sources)

    def test_p2_2_pattern_reported(self):
        _, hits = self.run_scan()
        self.assertEqual([h[3] for h in hits['is_roster']], ['int(t.actor_id)'])
        self.assertEqual([h[2] for h in hits['toggle']], ['find'])

    def test_normalised_and_unrelated_not_reported(self):
        _, hits = self.run_scan()
        self.assertEqual(hits['by_name'], [])
        self.assertEqual(hits['clean'], [])
        _, all_hits = self.run_scan(show_all=True)
        self.assertEqual(len(all_hits['by_name']), 3)


if __name__ == '__main__':
    unittest.main()
