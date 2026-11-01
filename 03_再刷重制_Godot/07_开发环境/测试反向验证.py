#!/usr/bin/env python3
"""反向验证.py 自测：定位（恰好一次）、还原字节一致、dry-run 不动文件。"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('rv', HERE / '反向验证.py')
rv = importlib.util.module_from_spec(spec); spec.loader.exec_module(rv)


class ReverseVerify(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.f = self.tmp / 'a.gd'
        self.f.write_text('x = 1\ny = 2\ny = 2\n')
        self.root = mock.patch.object(rv, 'ROOT', self.tmp); self.root.start()
        self.addCleanup(self.root.stop)

    def manifest(self, items):
        m = self.tmp / 'm.json'
        m.write_text(json.dumps({'tests': ['t'], 'items': items}))
        return m

    def run_main(self, *argv):
        with mock.patch('sys.argv', ['rv', *argv]):
            return rv.main()

    def test_locate_requires_exactly_one(self):
        with self.assertRaises(ValueError):
            rv.locate({'file': 'a.gd', 'find': 'y = 2', 'replace': 'y = 3'})      # 两处
        with self.assertRaises(ValueError):
            rv.locate({'file': 'a.gd', 'find': 'zzz', 'replace': 'q'})           # 零处
        path, text, new = rv.locate({'file': 'a.gd', 'find': 'x = 1', 'replace': 'x = 9'})
        self.assertEqual((path, new.startswith('x = 9')), (self.f, True))

    def test_dry_run_leaves_file_and_reports_locate_failures(self):
        before = self.f.read_bytes()
        m = self.manifest([{'name': 'ok', 'file': 'a.gd', 'find': 'x = 1', 'replace': 'x = 0'},
                           {'name': 'dup', 'file': 'a.gd', 'find': 'y = 2', 'replace': 'y = 0'}])
        self.assertEqual(self.run_main(str(m), '--dry-run'), 1)
        self.assertEqual(self.f.read_bytes(), before)

    def test_restore_after_run_and_bite_verdicts(self):
        before = self.f.read_bytes()
        m = self.manifest([{'name': 'bites', 'file': 'a.gd', 'find': 'x = 1', 'replace': 'x = 0'}])
        # 基线过、改动后失败 → 咬住；文件还原
        results = iter([(True, ''), (False, '1 个失败')])
        with mock.patch.object(rv, 'run_tests', lambda *a: next(results)):
            self.assertEqual(self.run_main(str(m)), 0)
        self.assertEqual(self.f.read_bytes(), before)
        # 改动后仍全过 → 没咬住，退出 1，仍还原
        results = iter([(True, ''), (True, '')])
        with mock.patch.object(rv, 'run_tests', lambda *a: next(results)):
            self.assertEqual(self.run_main(str(m)), 1)
        self.assertEqual(self.f.read_bytes(), before)

    def test_failing_baseline_aborts_without_touching_files(self):
        before = self.f.read_bytes()
        m = self.manifest([{'name': 'x', 'file': 'a.gd', 'find': 'x = 1', 'replace': 'x = 0'}])
        with mock.patch.object(rv, 'run_tests', lambda *a: (False, 'boom')):
            self.assertEqual(self.run_main(str(m)), 2)
        self.assertEqual(self.f.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
