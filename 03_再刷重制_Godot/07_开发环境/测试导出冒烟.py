#!/usr/bin/env python3
"""导出冒烟.py 的离线回归：结果解析、报告生成、找 .app（不导出、不跑 Godot）。"""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('smoke', HERE / '导出冒烟.py')
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class ParseTests(unittest.TestCase):
    def test_last_result_and_fails(self):
        log = 'x\nFAIL a 1\nTEST_RESULT={"passed":1,"total":2}\nFAIL b\nTEST_RESULT={"passed":11,"total":12}\n'
        r = smoke.parse_result(log)
        self.assertEqual((r['passed'], r['total']), (11, 12))
        self.assertEqual(r['fails'], ['FAIL a 1', 'FAIL b'])

    def test_missing_or_bad(self):
        self.assertIsNone(smoke.parse_result('崩了\n'))
        self.assertIsNone(smoke.parse_result('TEST_RESULT={坏\n'))


class AppAndReportTests(unittest.TestCase):
    def test_find_app_and_report(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            self.assertEqual(smoke.find_app(d), (None, None))
            exe = d / '再刷重制.app' / 'Contents' / 'MacOS' / '再刷重制'
            exe.parent.mkdir(parents=True)
            exe.write_text('')
            os.chmod(exe, 0o755)
            self.assertEqual(smoke.find_app(d)[1], exe)
            info = {'time': 't', 'preset': 'macOS 验收', 'zip': 'z', 'ok': False, 'scenes': [
                {'scene': 'xiyou_flow', 'ok': False, 'exit': 1, 'seconds': 3, 'result': {'passed': 1, 'total': 2, 'fails': ['FAIL x']}},
                {'scene': 'xiyou_mac_export', 'ok': False, 'exit': 124, 'seconds': 9, 'result': None}]}
            text = smoke.report(d, info).read_text(encoding='utf-8')
            self.assertIn('有失败', text)
            self.assertIn('| xiyou_flow | 失败 | 1/2 |', text)
            self.assertIn('没有 TEST_RESULT', text)
            self.assertIn('`FAIL x`', text)
            self.assertTrue((d / '结果.json').is_file())


if __name__ == '__main__':
    unittest.main()
