#!/usr/bin/env python3
"""导出冒烟.py 的离线回归：结果解析、报告生成、找 .app、Windows 包结构（不导出、不跑 Godot）。"""
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


def fake_pe(machine=0x8664, subsystem=2) -> bytes:
    head = bytearray(512)
    head[:2] = b'MZ'
    head[0x3C:0x40] = (0x80).to_bytes(4, 'little')
    head[0x80:0x84] = b'PE\0\0'
    head[0x84:0x86] = machine.to_bytes(2, 'little')
    head[0x80 + 24 + 68:0x80 + 24 + 70] = subsystem.to_bytes(2, 'little')
    return bytes(head)


class WindowsLayoutTests(unittest.TestCase):
    def test_pe_info(self):
        with tempfile.TemporaryDirectory() as d:
            exe = Path(d) / 'a.exe'
            exe.write_bytes(fake_pe())
            self.assertEqual(smoke.pe_info(exe), {'machine': 'x86_64', 'subsystem': '图形界面'})
            exe.write_bytes(fake_pe(0xAA64, 3))
            self.assertEqual(smoke.pe_info(exe), {'machine': 'arm64', 'subsystem': '控制台'})
            exe.write_bytes(b'\x7fELF' + bytes(200))
            self.assertIsNone(smoke.pe_info(exe))

    def test_layout(self):
        with tempfile.TemporaryDirectory() as d:
            exe = Path(d) / '再刷重制_验收.exe'
            exe.write_bytes(fake_pe())
            problems, _ = smoke.windows_layout(exe)
            self.assertTrue(any('.pck' in p for p in problems) and any('console' in p for p in problems), problems)
            exe.with_suffix('.pck').write_bytes(b'GDPC' + bytes(1 << 20))
            exe.with_name('再刷重制_验收.console.exe').write_bytes(fake_pe(subsystem=3))
            self.assertEqual(smoke.windows_layout(exe)[0], [])
            self.assertEqual(smoke.windows_layout(exe.with_name('x.exe'), debug=False)[0][0], 'x.exe 不是 Windows exe（PE 头不对）')
            exe.with_suffix('.pck').write_bytes(b'ZZZZ' + bytes(1 << 20))
            self.assertIn('不是 Godot 资源包', smoke.windows_layout(exe)[0][0])

    def test_windows_report(self):
        with tempfile.TemporaryDirectory() as d:
            info = {'time': 't', 'platform': 'windows', 'preset': 'Windows 验收', 'zip': 'z.exe', 'ok': True, 'layout': '通过', 'archs': 'x86_64',
                    'scenes': [{'scene': 'xiyou_mac_export', 'ok': True, 'exit': 0, 'seconds': 3, 'result': {'passed': 2, 'total': 2, 'fails': []}}]}
            text = smoke.report(Path(d), info).read_text(encoding='utf-8')
            self.assertIn('# Windows 导出冒烟报告', text)
            self.assertIn('同名 .pck', text)
            self.assertIn('Alt+Enter', text)

    def test_preset_template(self):
        self.assertTrue(str(smoke.preset_template('Windows 验收')).endswith('windows_debug_x86_64.exe'))
        self.assertTrue(str(smoke.preset_template('macOS 验收')).endswith('macos.zip'))
        self.assertIsNone(smoke.preset_template('没有这个预设'))


if __name__ == '__main__':
    unittest.main()
