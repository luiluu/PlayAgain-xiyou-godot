#!/usr/bin/env python3
"""探针登记检查.py 的五乘区检查（tools49）：读伤害的探针没提 CodexZones 要报，存量清单与真实工程一致。夹具用临时目录。"""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('probe_check', HERE / '探针登记检查.py')
pc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pc)
sys.path.insert(0, str(HERE.parent / '03_转换工具'))


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


class ReadsCheck(unittest.TestCase):
    """读法检查（审查 probe-deps 指纹）：同步探针里缓存键看不见的读法要报。"""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.tools = self.root / '03_转换工具'
        self.oracle = self.tools / 'mv_oracle'
        (self.oracle / 'shared').mkdir(parents=True)
        (self.tools / 'incremental_sync.py').write_text('')
        (self.tools / '同步正式西游.py').write_text("PROBES = [(['a_probe.cjs'], ['a.json'])]")
        (self.oracle / 'shared/host.cjs').write_text("const fs = require('fs');")
        (self.tools / 'extra.json').write_text('{}')

    def tearDown(self):
        self.tmp.cleanup()

    def bad(self, text, name='a_probe.cjs'):
        (self.oracle / name).write_text(text)
        return pc.reads_check(self.root)

    def test_recognised_forms_pass(self):
        self.assertEqual(self.bad(
            "const {start} = require('./shared/host.cjs');\n"
            "const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\n"
            "const GEN = process.env.XIYOU_GENERATED || path.resolve(__dirname, '../../01_Godot工程/modes/xiyou/generated');\n"
            "// fs.readFileSync(__dirname + '/commented.json')\n"
            "fs.writeFileSync(path.join(__dirname, '.sandbox/a.json'), '');"), [])

    def test_blind_read_forms_are_reported(self):
        for text in ("fs.readFileSync(__dirname + '/data.json');", "const D = __dirname; fs.readFileSync(path.join(D, 'data.json'));",
                     "fs.readFileSync('shared/data.json');", "fs.readFileSync(path.join(process.cwd(), 'data.json'));",
                     "require.resolve('./shared/host.cjs');"):
            bad = self.bad(text)
            self.assertEqual(len(bad), 1, text)
            self.assertIn('静态扫描认不出', bad[0])

    def test_blind_form_in_a_required_helper_is_reported_for_the_probe(self):
        (self.oracle / 'shared/host.cjs').write_text("fs.readFileSync(__dirname + '/cases.json');")
        bad = self.bad("require('./shared/host.cjs');")
        self.assertEqual(len(bad), 1)
        self.assertIn('a_probe.cjs 依赖的 mv_oracle/shared/host.cjs', bad[0])

    def test_unresolvable_require_is_reported_not_raised(self):
        bad = self.bad("require('./shared/missing.cjs');")
        self.assertEqual(len(bad), 1)
        self.assertIn('无法确认探针依赖', bad[0])

    def test_unregistered_probe_is_not_checked(self):
        self.assertEqual(self.bad("fs.readFileSync(__dirname + '/data.json');", 'fixture_only_probe.cjs'), [])

    def test_dynamic_read_needs_review_and_stale_review_is_reported(self):
        import incremental_sync
        bad = self.bad("const m = require('./shared/' + process.argv[2] + '.cjs');")
        self.assertEqual(len(bad), 1)
        self.assertIn('REVIEWED_DYNAMIC', bad[0])
        with mock.patch.dict(incremental_sync.REVIEWED_DYNAMIC, {'a_probe.cjs': '夹具'}, clear=True):
            self.assertEqual(pc.reads_check(self.root), [])
            bad = self.bad("require('./shared/host.cjs');")
            self.assertEqual(len(bad), 1)
            self.assertIn('删掉这一行', bad[0])

    def test_file_outside_oracle_needs_probe_inputs(self):
        import incremental_sync
        bad = self.bad("fs.readFileSync(path.join(__dirname, '../extra.json'));")
        self.assertEqual(len(bad), 1)
        self.assertIn('PROBE_INPUTS', bad[0])
        with mock.patch.dict(incremental_sync.PROBE_INPUTS, {'a_probe.cjs': ('extra.json',)}):
            self.assertEqual(pc.reads_check(self.root), [])
        # 拼出来的名字认不出是哪份文件，也报
        self.assertEqual(len(self.bad("fs.readFileSync(path.join(__dirname, '../' + name));")), 1)

    def test_environment_variable_needs_classifying(self):
        import incremental_sync
        bad = self.bad("if (process.env.XIYOU_NEW_SWITCH === '0') {}")
        self.assertEqual(len(bad), 1)
        self.assertIn('SWITCH_ENV', bad[0])
        self.assertEqual(len(self.bad("const v = process.env[name];")), 1)
        with mock.patch.object(incremental_sync, 'SWITCH_ENV', ('XIYOU_NEW_SWITCH',)):
            self.assertEqual(self.bad("if (process.env['XIYOU_NEW_SWITCH'] === '0') {}"), [])
        self.assertEqual(self.bad("const APP = process.env.XIYOU_APP; if (process.env.XIYOU_HBOOT_FILE_XHR !== '0') {}"), [])


class RealProject(unittest.TestCase):
    def test_real_project_clean(self):
        stock = json.loads((HERE / '探针五乘区存量.json').read_text())['stock']
        self.assertEqual(pc.zones_check(pc.REMAKE, stock), [])

    def test_real_sync_probes_reads_are_fingerprinted_or_reviewed(self):
        self.assertEqual(pc.reads_check(pc.REMAKE), [])


if __name__ == '__main__':
    unittest.main()
