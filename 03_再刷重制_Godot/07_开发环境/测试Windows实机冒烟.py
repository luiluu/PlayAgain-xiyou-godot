#!/usr/bin/env python3
"""Windows实机冒烟.py 的离线测试（cc 平台 FB 2026-11-07）：用假 exe（shell 脚本）模拟发行包，Mac／Linux 上就能跑。
真跑在云端 windows-latest（export-smoke 工作流的 windows-run 任务）。"""
import importlib.util
import os
import re
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


W = load('Windows实机冒烟', 'Windows实机冒烟.py')

# 假 exe：按参数打印入口或按键结果，往 $APPDATA 下建存档目录；FAKE_MODE 控制出错方式
FAKE = r'''#!/bin/sh
mode="${FAKE_MODE:-ok}"
dir="$APPDATA/KYO/再刷重制"
[ "$mode" = dev ] && dir="$APPDATA/KYO/再刷重制_开发"
mkdir -p "$dir/logs"
case "$*" in
  *--report-entry*)
    if [ "$mode" = logonly ]; then echo "ENTRY_SCENE=res://modes/xiyou/entry.tscn" > "$dir/logs/godot.log"; exit 0; fi
    echo "ENTRY_SCENE=res://modes/xiyou/entry.tscn"; exit 0 ;;
  *--smoke-keys=*)
    [ "$mode" = crash ] && exit 139
    echo "SMOKE_KEY=space"; echo "SMOKE_DONE scene=res://modes/xiyou/map/map_scene.tscn"; exit 0 ;;
esac
exit 3
'''


class FakeExeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name) / 'pkg'
        self.d.mkdir()
        exe = self.d / 'fake.sh'
        exe.write_text(FAKE, encoding='utf-8')
        exe.chmod(0o755)
        (self.d / 'fake.pck').write_bytes(b'GDPC')
        self.out = Path(self.tmp.name) / 'out'
        self.old = os.environ.get('FAKE_MODE')

    def tearDown(self):
        if self.old is None:
            os.environ.pop('FAKE_MODE', None)
        else:
            os.environ['FAKE_MODE'] = self.old
        self.tmp.cleanup()

    def go(self, mode, *extra):
        os.environ['FAKE_MODE'] = mode
        return W.main(['--dir', str(self.d), '--exe', 'fake.sh', '--out', str(self.out), *extra])

    def results(self):
        import json
        return {r['name']: r['ok'] for r in json.loads((self.out / '结果.json').read_text(encoding='utf-8'))}

    def test_all_pass(self):
        self.assertEqual(self.go('ok'), 0)
        r = self.results()
        self.assertTrue(r['win_enters_title'])
        self.assertTrue(r['win_save_dir_release'])
        self.assertTrue(r['win_no_dev_save_dir'])
        self.assertTrue(r['win_keys_title_space_new_game'])
        # 最后一组不要求在地图（want=None）
        self.assertTrue(r['win_keys_title_cancel_then_map_keys'])

    def test_dev_dir_fails(self):
        # 发行包写进 _开发 目录＝O-200 坏了
        self.assertEqual(self.go('dev', '--no-keys'), 1)
        r = self.results()
        self.assertFalse(r['win_save_dir_release'])
        self.assertFalse(r['win_no_dev_save_dir'])

    def test_crash_in_keys_fails(self):
        self.assertEqual(self.go('crash'), 1)
        r = self.results()
        self.assertTrue(r['win_enters_title'])
        self.assertFalse(r['win_keys_title_space_new_game'])

    def test_falls_back_to_godot_log(self):
        # 标准输出收不到时读 user://logs/godot.log
        self.assertEqual(self.go('logonly', '--no-keys'), 0)
        self.assertTrue(self.results()['win_enters_title'])

    def test_missing_package(self):
        (self.d / 'fake.pck').unlink()
        self.assertEqual(self.go('ok'), 2)

    def test_real_appdata_untouched(self):
        # 每次都用临时 APPDATA，跑完删掉；本进程的 APPDATA 不变
        before = os.environ.get('APPDATA')
        self.go('ok', '--no-keys')
        self.assertEqual(os.environ.get('APPDATA'), before)


class SyncTests(unittest.TestCase):
    def test_key_runs_match_release_entry_smoke(self):
        # 两边的按键组要一致（Windows实机冒烟.py 只用标准库、不 import 发行入口冒烟.py，所以抄了一份）
        R = load('发行入口冒烟', '发行入口冒烟.py')
        self.assertEqual(W.KEY_RUNS, R.KEY_RUNS)
        self.assertEqual(W.TITLE, R.TITLE)
        self.assertEqual(W.MAP, R.MAP)

    def test_save_dir_matches_project(self):
        cfg = (HERE.parent / '01_Godot工程' / 'project.godot').read_text(encoding='utf-8')
        rel = re.search(r'(?m)^config/custom_user_dir_name\.release="([^"]+)"', cfg).group(1)
        dev = re.search(r'(?m)^config/custom_user_dir_name="([^"]+)"', cfg).group(1)
        self.assertEqual('/'.join(W.SAVE_DIR), rel)
        self.assertEqual('/'.join(W.DEV_DIR), dev)

    def test_rc_note_crash(self):
        self.assertIn('闪退', W.rc_note(-1073741819))  # 0xC0000005
        self.assertIn('闪退', W.rc_note(3221225477))
        self.assertNotIn('闪退', W.rc_note(1))


if __name__ == '__main__':
    unittest.main()
