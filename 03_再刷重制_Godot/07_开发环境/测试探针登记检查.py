#!/usr/bin/env python3
"""探针登记检查.py 的五乘区检查（tools49）：读伤害的探针没提 CodexZones 要报，存量清单与真实工程一致。夹具用临时目录。"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('probe_check', HERE / '探针登记检查.py')
pc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pc)


class ZonesCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.oracle = self.root / '03_转换工具/mv_oracle'
        self.oracle.mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def probe(self, name, text):
        (self.oracle / name).write_text(text)

    def test_damage_without_switch_is_reported(self):
        self.probe('a_probe.cjs', "w.eval('x'); r.hpDamage;")
        bad = pc.zones_check(self.root, {})
        self.assertEqual(len(bad), 1)
        self.assertIn('a_probe.cjs', bad[0])

    def test_each_damage_keyword_counts(self):
        for i, kw in enumerate(['hpDamage', 'makeDamage', 'executeDamage', 'applyDamage', 'startAction', 'invokeAction', 'evalDamageFormula', 'a.result()']):
            self.probe(f'k{i}_probe.cjs', kw)
        self.assertEqual(len(pc.zones_check(self.root, {})), 8)

    def test_switch_set_passes(self):
        self.probe('a_probe.cjs', "w.eval('CodexZones.ENABLED=false;'); r.hpDamage;")
        self.probe('b_probe.cjs', "w.CodexZones = undefined; makeDamage")
        self.assertEqual(pc.zones_check(self.root, {}), [])

    def test_probe_without_damage_passes(self):
        self.probe('a_probe.cjs', "w.eval('newGame');")
        self.assertEqual(pc.zones_check(self.root, {}), [])

    def test_stock_listed_passes(self):
        self.probe('a_probe.cjs', 'hpDamage')
        self.assertEqual(pc.zones_check(self.root, {'a_probe.cjs': '存量'}), [])

    def test_stale_stock_is_reported(self):
        self.probe('a_probe.cjs', "CodexZones.ENABLED=false; hpDamage")
        bad = pc.zones_check(self.root, {'a_probe.cjs': '存量', 'gone_probe.cjs': '存量'})
        self.assertEqual(len(bad), 2)
        self.assertTrue(all('删掉这一行' in b for b in bad))


class RealProject(unittest.TestCase):
    def test_real_project_clean(self):
        stock = json.loads((HERE / '探针五乘区存量.json').read_text())['stock']
        self.assertEqual(pc.zones_check(pc.REMAKE, stock), [])


if __name__ == '__main__':
    unittest.main()
