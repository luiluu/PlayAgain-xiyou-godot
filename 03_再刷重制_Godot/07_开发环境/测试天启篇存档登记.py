#!/usr/bin/env python3
"""天启篇存档登记.py 的回归：没登记的根键、别名、const 键、分区名、装备 tq_ 键都报；登记过的、注释里的、动态键不报。"""
import importlib.util
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('reg', HERE / '天启篇存档登记.py')
reg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reg)

FACADE = '''class_name XTianqiSave
const VKEY := "v"
const SECTIONS := {
	"drop": {"v": 1, "owner": "XTianqiDrop"},
	"gojo": {"v": 3, "owner": "XTianqiGojoTrial", "vkey": "gojo_adv_v", "keys": ["gojo_trials"]},
}
const ROOT_KEYS := ["rules", "difficulty", VKEY]
const COUNTER_KEYS := ["src_n"]
const OUTSIDE_KEYS := ["_gojoTrial"]
const GEAR_KEYS := {
	"tq_seed_id": {"owner": "XTianqi", "copy": false},
}
'''


class RegistryTests(unittest.TestCase):
    def run_on(self, code):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'modes/xiyou/core').mkdir(parents=True)
            (root / reg.FACADE).write_text(FACADE, encoding='utf-8')
            (root / 'modes/xiyou/core/tianqi_x.gd').write_text(code, encoding='utf-8')
            bad, _, _ = reg.check(root)
            return bad

    def test_registry_parsed(self):
        root, gear = reg.registry(FACADE)
        self.assertTrue({'drop', 'gojo', 'gojo_adv_v', 'gojo_trials', 'rules', 'difficulty', 'v', 'src_n', '_gojoTrial'} <= root)
        self.assertEqual(gear, {'tq_seed_id'})

    def test_registered_ok(self):
        self.assertEqual(self.run_on('func f(s):\n\tvar d = s.flags.tianqi.get("difficulty")\n\ts.flags.tianqi["rules"] = 1\n'
                                     '\tvar tq: Dictionary = s.flags.tianqi\n\ttq["src_n"] = {}\n\tXTianqiSave.section(s, "drop")\n'), [])

    def test_unregistered_direct(self):
        bad = self.run_on('func f(s):\n\ts.flags.tianqi["sect"] = {}\n\tvar x = s.flags.tianqi.get("famine2", 0)\n\tif s.flags.tianqi.has("zz"): pass\n\tvar y = s.flags.tianqi.foo\n')
        self.assertEqual(len(bad), 4, bad)
        self.assertTrue(all('tianqi_x.gd' in b for b in bad))

    def test_alias_and_const(self):
        bad = self.run_on('const K := "newkey"\nfunc f(s):\n\tvar tq: Dictionary = s.flags.tianqi\n\ttq["sect"] = 1\n\ttq.get("cult")\n\ts.flags.tianqi[K] = 1\n')
        self.assertEqual(sorted(b.split('flags.tianqi.')[1].split(' ')[0] for b in bad), ['cult', 'newkey', 'sect'], bad)

    def test_dynamic_and_comments_skipped(self):
        self.assertEqual(self.run_on('func f(s, key):\n\ts.flags.tianqi[key] = {}\n\t## s.flags.tianqi["doc"]\n\tpass  # s.flags.tianqi["c"]\n\tvar n = s.flags.tianqi.size()\n'), [])

    def test_section_name(self):
        bad = self.run_on('func f(s):\n\tXTianqiSave.section(s, "sect")\n\tXTianqiSave.peek(s, "drop")\n')
        self.assertEqual(len(bad), 1, bad)

    def test_gear_keys(self):
        bad = self.run_on('func f(item):\n\titem["tq_seed_id"] = "x"\n\titem["tq_new"] = 1\n\tif item["tq_new"] == 1: pass\n')
        self.assertEqual(len(bad), 1, bad)
        self.assertIn('tq_new', bad[0])

    def test_root_alias(self):
        # 小A 甲档 P2-2：var X = XTianqiSave.root(s) 的别名也要认
        bad = self.run_on('func f(s):\n\tvar tq := XTianqiSave.root(s)\n\ttq["sect"] = 1\n\ttq.get("rules")\n'
                          '\tvar t2: Dictionary = XTianqiSave.root(XState.current)\n\tt2.cult = 2\n')
        self.assertEqual(sorted(b.split('flags.tianqi.')[1].split(' ')[0] for b in bad), ['cult', 'sect'], bad)

    def test_gear_dot_and_const(self):
        # 小A 甲档 P2-2：装备键点号赋值、const 键赋值也要认；非 tq_ 的 const、比较、set_meta 不算
        bad = self.run_on('const F := "tq_new"\nconst OK := "tq_seed_id"\nconst M := "tq_meta"\nconst X := "plain"\n'
                          'func f(item, a):\n\titem.tq_dot = 1\n\titem[F] = 2\n\titem[OK] = 3\n\titem[X] = 4\n'
                          '\tif item.tq_dot == 1: pass\n\ta.set_meta(M, 1)\n\titem.tq_seed_id = "y"\n')
        self.assertEqual(sorted(b.split('装备键 ')[1].split(' ')[0] for b in bad), ['tq_dot', 'tq_new'], bad)

    def test_real_project_clean(self):
        bad, _, _ = reg.check()
        self.assertEqual(bad, [])


if __name__ == '__main__':
    unittest.main()
