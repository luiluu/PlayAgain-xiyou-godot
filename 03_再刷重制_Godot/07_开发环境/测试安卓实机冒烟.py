#!/usr/bin/env python3
"""安卓实机冒烟.py 的离线测试（cc 平台 FB 二批 2026-11-07）：用假 adb（记状态的 Python 脚本）模拟模拟器，Mac 上就能跑。
真跑在云端 export-smoke 工作流的 android-run 任务。"""
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('安卓实机冒烟', HERE / '安卓实机冒烟.py')
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
for k in A.WAIT:
    A.WAIT[k] = 0.0

# 假 adb：状态存在 $FAKE_STATE（pid、上次返回键时间）；FAKE_MODE＝ok／crash_enter（回车后进程没了＋logcat 有崩溃）／
# restart_on_resume（回前台换了进程）／no_back_exit（按两次返回不退出）／phone（只连真机）
FAKE = r'''#!/usr/bin/env python3
import json, os, sys, time
st_path = os.environ['FAKE_STATE']
st = json.load(open(st_path)) if os.path.exists(st_path) else {'pid': '', 'next': 1000, 'back': 0, 'log': []}
mode = os.environ.get('FAKE_MODE', 'ok')
a = sys.argv[1:]
if a[:1] == ['devices']:
    print('List of devices attached')
    print(('R58N123ABC' if mode == 'phone' else 'emulator-5554') + '\tdevice')
    sys.exit(0)
a = a[2:]  # -s <serial>
def start():
    if not st['pid']:
        st['pid'] = str(st['next']); st['next'] += 1
        st['log'].append('11-07 10:00:00.000  %s  %s I godot   : ENTRY_SCENE=res://modes/xiyou/entry.tscn' % (st['pid'], st['pid']))
out = ''
if a[0] == 'install':
    out = 'Performing Streamed Install\nSuccess'
elif a[0] == 'logcat':
    if '-c' in a: st['log'] = []
    else: out = '\n'.join(st['log'])
elif a[:2] == ['shell', 'pidof']:
    out = st['pid']
elif a[:2] == ['shell', 'am'] and a[2] == 'start':
    if mode == 'restart_on_resume' and st['pid'] and '-W' not in a: st['pid'] = ''
    start()
elif a[:2] == ['shell', 'am'] and a[2] == 'force-stop':
    st['pid'] = ''
elif a[:3] == ['shell', 'input', 'keyevent']:
    k = a[3]
    if k == '4' and st['pid']:
        if st['back'] and time.time() - st['back'] < 2 and mode != 'no_back_exit':
            st['pid'] = ''; st['back'] = 0
        else:
            st['back'] = time.time()
    elif k == '66' and mode == 'crash_enter' and st['pid']:
        st['log'].append('11-07 10:00:05.000  %s  %s F libc    : Fatal signal 11 (SIGSEGV), code 1' % (st['pid'], st['pid']))
        st['pid'] = ''
json.dump(st, open(st_path, 'w'))
print(out)
'''


class FakeAdbTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = Path(self.tmp.name)
        self.adb = d / 'adb'
        self.adb.write_text(FAKE.replace('#!/usr/bin/env python3', '#!' + sys.executable), encoding='utf-8')
        self.adb.chmod(0o755)
        self.apk = d / 'x.apk'
        self.apk.write_bytes(b'PK')
        self.out = d / 'out'
        os.environ['FAKE_STATE'] = str(d / 'state.json')

    def tearDown(self):
        os.environ.pop('FAKE_MODE', None)
        os.environ.pop('FAKE_STATE', None)
        self.tmp.cleanup()

    def go(self, mode):
        os.environ['FAKE_MODE'] = mode
        return A.main(['--apk', str(self.apk), '--adb', str(self.adb), '--out', str(self.out)])

    def results(self):
        return {r['name']: r['ok'] for r in json.loads((self.out / '结果.json').read_text(encoding='utf-8'))}

    def test_all_pass(self):
        self.assertEqual(self.go('ok'), 0, self.results())
        r = self.results()
        for k in ('android_install', 'android_alive_after_launch', 'android_enters_title', 'android_back_once_stays',
                  'android_back_twice_exits', 'android_enter_new_game_alive', 'android_resume_same_process', 'android_no_fatal'):
            self.assertTrue(r[k], k)

    def test_crash_on_enter(self):
        self.assertEqual(self.go('crash_enter'), 1)
        r = self.results()
        self.assertFalse(r['android_enter_new_game_alive'])
        self.assertFalse(r['android_no_fatal'])

    def test_restart_on_resume_fails(self):
        self.assertEqual(self.go('restart_on_resume'), 1)
        self.assertFalse(self.results()['android_resume_same_process'])

    def test_back_twice_must_exit(self):
        self.assertEqual(self.go('no_back_exit'), 1)
        self.assertFalse(self.results()['android_back_twice_exits'])

    def test_phone_never_used(self):
        self.assertEqual(self.go('phone'), 2)
        self.assertFalse(Path(os.environ['FAKE_STATE']).exists())  # 一条装机命令都没发


class ParseTests(unittest.TestCase):
    def test_fatal_lines_by_pid(self):
        log = ('11-07 10:00:05.000  123  130 F libc    : Fatal signal 11 (SIGSEGV)\n'
               '11-07 10:00:05.000  999  999 F libc    : Fatal signal 11 (SIGSEGV)\n'
               '11-07 10:00:06.000  500  520 E ActivityManager: ANR in local.kyo.remake\n')
        got = A.fatal_lines(log, {'123'})
        self.assertEqual(len(got), 2)
        self.assertTrue(any('ANR' in g for g in got))

    def test_preset_has_launcher(self):
        # 启动的 Activity 名跟 Godot 安卓模板一致（GodotAppLauncher）；包名跟「安卓 发行」预设一致
        cfg = (HERE.parent / '01_Godot工程' / 'export_presets.cfg').read_text(encoding='utf-8')
        self.assertIn(f'package/unique_name="{A.PACKAGE}"', cfg)


if __name__ == '__main__':
    unittest.main()
