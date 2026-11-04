#!/usr/bin/env python3
"""工具回归.py（tools65 快速门禁）的回归：门禁里每一项都存在、都被 检查.sh 的 tools 组调用；失败时早停并打印日志。"""
import importlib.util
import re
import sys
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('gate', HERE / '工具回归.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class GateTests(unittest.TestCase):
    def test_every_entry_exists_and_runs_in_checker(self):
        checker = (HERE / '检查.sh').read_text()
        for name, script, args, why in gate.GATE:
            self.assertTrue((HERE / script).is_file(), script)
            self.assertIn('$ENV_DIR/' + script, checker, '%s 不在 检查.sh 里：门禁不另造一套' % script)

    def test_gate_catches_the_known_late_failures(self):
        """三次合并才挂的那类回归必须在门禁里：替身名单、插件备注覆盖、状态 js 翻译。"""
        scripts = {g[1]: g[2] for g in gate.GATE}
        self.assertIn('CheckerTests', scripts['测试选测.py'])
        self.assertIn('测试插件备注覆盖.py', scripts)
        self.assertIn('测试状态js翻译.py', scripts)

    def test_list(self):
        with mock.patch('builtins.print') as pr:
            self.assertEqual(gate.main(['--list']), 0)
        self.assertEqual(pr.call_count, len(gate.GATE))

    def test_failure_stops_with_rc1_and_prints_tail(self):
        fake = [('好', 'x.py', [], ''), ('坏', 'y.py', [], '')]
        def run_one(entry):
            return (entry, 0, 'ok', 0.1) if entry[0] == '好' else (entry, 1, 'a\nb\nboom', 0.2)
        with mock.patch.object(gate, 'GATE', fake), mock.patch.object(gate, 'run_one', run_one), mock.patch('builtins.print') as pr:
            self.assertEqual(gate.main(['--jobs', '2']), 1)
        text = '\n'.join(str(c.args[0]) for c in pr.call_args_list)
        self.assertIn('✗ 坏', text)
        self.assertIn('boom', text)
        self.assertIn('✓ 好', text)

    def test_all_pass_rc0(self):
        def run_one(entry):
            return entry, 0, '', 0.0
        with mock.patch.object(gate, 'run_one', run_one), mock.patch('builtins.print'):
            self.assertEqual(gate.main([]), 0)

    def test_real_script_failure_is_reported(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            bad = Path(d) / 'bad.py'
            bad.write_text('import sys\nprint("nope")\nsys.exit(3)\n')
            with mock.patch.object(gate, 'HERE', Path(d)):
                entry, rc, out, _ = gate.run_one(('x', 'bad.py', [], ''))
            self.assertEqual(rc, 3)
            self.assertIn('nope', out)


if __name__ == '__main__':
    unittest.main()
