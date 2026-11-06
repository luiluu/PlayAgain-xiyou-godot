#!/usr/bin/env python3
"""发行入口冒烟.py 的安卓分支（cc 平台 DZ 2026-11-06）：离线部分——认模拟器、不碰真机、入口文件清单、命令行。
真导出要 1～3 分钟，不在这里跑：手动 `python3 发行入口冒烟.py --platform android --keys`。"""
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('发行入口冒烟', HERE / '发行入口冒烟.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


def fake_adb(d: Path, devices: str) -> Path:
    adb = d / 'adb'
    adb.write_text('#!/bin/sh\nprintf "%s"\n' % devices.replace('\n', '\\n').replace('\t', '\\t'), encoding='utf-8')
    adb.chmod(0o755)
    return adb


class EmulatorTests(unittest.TestCase):
    def test_only_emulators_used(self):
        with tempfile.TemporaryDirectory() as d:
            adb = fake_adb(Path(d), 'List of devices attached\nemulator-5554\tdevice\nR58N123ABC\tdevice\nemulator-5556\toffline\n\n')
            self.assertEqual(M.emulators(adb), (['emulator-5554'], ['R58N123ABC']))

    def test_none(self):
        with tempfile.TemporaryDirectory() as d:
            adb = fake_adb(Path(d), 'List of devices attached\n\n')
            self.assertEqual(M.emulators(adb), ([], []))


class AndroidStaticTests(unittest.TestCase):
    def test_entry_files(self):
        # 入口：发行构建从 project.binary 起、进西游标题（entry.tscn）、build_info 给版本号和 ReleaseEntry 用
        self.assertIn('assets/project.binary', M.ANDROID_NEED)
        self.assertIn('assets/modes/xiyou/entry.tscn.remap', M.ANDROID_NEED)
        self.assertIn('assets/content/build_info.json', M.ANDROID_NEED)
        self.assertEqual(M.ANDROID_PRESET, '安卓 发行')

    def test_cli_accepts_android(self):
        out = subprocess.run([sys.executable, str(HERE / '发行入口冒烟.py'), '--help'], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0)
        self.assertIn('android', out.stdout)
        self.assertIn('--apk', out.stdout)

    def test_debug_keystore_lookup_is_tuple(self):
        ks, pw = M.editor_debug_keystore()
        self.assertEqual(ks is None, pw is None)

    def test_never_installs_on_phones(self):
        src = (HERE / '发行入口冒烟.py').read_text(encoding='utf-8')
        body = src[src.index('def android('):src.index('def crash_reports')] if 'def crash_reports' in src[src.index('def android('):] else src[src.index('def android('):]
        self.assertIn("serial, pkg = emus[0]", body)
        self.assertNotIn('phones[0]', body)


if __name__ == '__main__':
    unittest.main()
