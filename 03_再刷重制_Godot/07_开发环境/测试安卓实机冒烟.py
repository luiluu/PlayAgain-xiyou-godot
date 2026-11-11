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
def cl():
    import zipfile
    try:
        with zipfile.ZipFile(st.get('apk', '')) as z:
            d = z.read('assets/_cl_')
    except Exception:
        return []
    n, i, out = int.from_bytes(d[:4], 'little'), 4, []
    for _ in range(n):
        k = int.from_bytes(d[i:i+4], 'little'); out.append(d[i+4:i+4+k].decode()); i += 4 + k
    return out
def start():
    if not st['pid']:
        st['pid'] = str(st['next']); st['next'] += 1
        args = cl()
        if mode == 'always_entry' or '--report-entry' in args:
            st['log'].append('11-07 10:00:00.000  %s  %s I godot   : ENTRY_SCENE=res://modes/xiyou/entry.tscn' % (st['pid'], st['pid']))
        keys = [x.split('=', 1)[1] for x in args if x.startswith('--smoke-keys=')]
        if '--smoke-arm-bgidle' in args:
            st['bg'] = True
            st['log'].append('11-09 10:00:00.600  %s  %s I godot   : BGIDLE_ARMED=true' % (st['pid'], st['pid']))
        if '--report-entry' in args and not keys:
            st['log'].append('11-07 10:00:00.500  %s  %s I godot   : AUTO_SAVE_PRESENT=%s' % (st['pid'], st['pid'], 'true' if st.get('auto') else 'false'))
        if keys and keys[0].endswith('wait:7200'):
            st['autosave_run'] = True
        elif keys:
            seq = keys[0].split(',')
            if mode == 'keys_crash' and seq[0] == 'j':
                st['log'].append('11-07 10:00:05.000  %s  %s F libc    : Fatal signal 11 (SIGSEGV)' % (st['pid'], st['pid']))
            else:
                for k in seq:
                    st['log'].append('11-07 10:00:01.000  %s  %s I godot   : SMOKE_KEY=%s' % (st['pid'], st['pid'], k))
                st['log'].append('11-07 10:00:02.000  %s  %s I godot   : SMOKE_DONE scene=res://modes/xiyou/map/map_scene.tscn' % (st['pid'], st['pid']))
            st['pid'] = ''
out = ''
if a[0] == 'install':
    out = 'Performing Streamed Install\nSuccess'
    st['apk'] = a[-1]
elif a[0] == 'logcat':
    if '-c' in a: st['log'] = []
    else: out = '\n'.join(st['log'])
elif a[:3] == ['shell', 'pm', 'clear']:
    st['auto'] = False
elif a[:2] == ['shell', 'pidof']:
    out = st['pid']
elif a[:3] == ['shell', 'dumpsys', 'activity']:
    out = '  * ServiceRecord{1 u0 local.kyo.remake/local.kyo.xiyou.bgidle.XiyouIdleService}' if st.get('svc') else '(nothing)'
elif a[:3] == ['shell', 'dumpsys', 'notification']:
    out = '  NotificationRecord(0x1: pkg=local.kyo.remake user=UserHandle{0} id=2061 tag=null importance=2 key=x: Notification(channel=xiyou_idle))' if st.get('svc') else ''
elif a[:2] == ['shell', 'am'] and a[2] == 'start' and st.get('svc'):
    st['svc'] = False
    st['log'].append('11-09 10:01:00.000  %s  %s I XiyouBgIdle: 回前台：离开 %d 毫秒，点过停止 false' % (st['pid'], st['pid'], int((time.time() - st['home_at']) * 1000)))
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
    elif k == '3' and st['pid'] and st.get('autosave_run'):
        r = 'skip:event' if mode == 'autosave_event' else 'saved'
        st['log'].append('11-07 10:00:06.000  %s  %s I godot   : PAUSE_SAVE=%s' % (st['pid'], st['pid'], r))
        st['auto'] = r == 'saved' and mode != 'autosave_lost'
        st['autosave_run'] = False
    elif k == '3' and st['pid'] and st.get('bg'):
        st['bg'] = False
        st['svc'] = mode != 'bgidle_none'
        st['home_at'] = time.time()
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
        import zipfile
        self.apk = d / 'x.apk'
        with zipfile.ZipFile(self.apk, 'w') as z:
            z.writestr('AndroidManifest.xml', b'x')
            z.writestr('META-INF/CERT.RSA', b'old')
            z.writestr('assets/_cl_', A.cl_bytes([]))
        # 假 build-tools：zipalign 照抄（-p -f 4 in out），apksigner 什么都不做
        self.bt = d / 'bt'
        self.bt.mkdir()
        (self.bt / 'zipalign').write_text('#!/bin/sh\ncp "$4" "$5"\n', encoding='utf-8')
        (self.bt / 'apksigner').write_text('#!/bin/sh\nexit 0\n', encoding='utf-8')
        (self.bt / 'ks').write_bytes(b'')
        for f in ('zipalign', 'apksigner'):
            (self.bt / f).chmod(0o755)
        self.out = d / 'out'
        os.environ['FAKE_STATE'] = str(d / 'state.json')

    def tearDown(self):
        os.environ.pop('FAKE_MODE', None)
        os.environ.pop('FAKE_STATE', None)
        self.tmp.cleanup()

    def go(self, mode, resign=False):
        os.environ['FAKE_MODE'] = mode
        extra = ['--build-tools', str(self.bt), '--keystore', str(self.bt / 'ks')] if resign else ['--no-resign']
        return A.main(['--apk', str(self.apk), '--adb', str(self.adb), '--out', str(self.out), *extra])

    def results(self):
        return {r['name']: r['ok'] for r in json.loads((self.out / '结果.json').read_text(encoding='utf-8'))}

    def test_all_pass(self):
        self.assertEqual(self.go('always_entry'), 0, self.results())
        r = self.results()
        for k in ('android_install', 'android_alive_after_launch', 'android_enters_title', 'android_back_once_stays',
                  'android_back_twice_exits', 'android_enter_new_game_alive', 'android_resume_same_process', 'android_no_fatal'):
            self.assertTrue(r[k], k)

    def test_resign_entry_and_keys(self):
        # 重签副本：_cl_ 里带 --report-entry 才有 ENTRY_SCENE；四组按键都到 SMOKE_DONE；原包和副本都不留在输出目录
        self.assertEqual(self.go('ok', resign=True), 0, self.results())
        r = self.results()
        self.assertTrue(r['android_enters_title'])
        for name, _, _ in A.KEY_RUNS:
            self.assertTrue(r['android_keys_' + name], name)
        self.assertEqual(list(self.out.glob('*.apk')), [])

    def test_bgidle(self):
        self.assertEqual(self.go('ok', resign=True), 0)
        r = self.results()
        for n in ('android_bgidle_armed', 'android_bgidle_alive_in_background', 'android_bgidle_service', 'android_bgidle_notification',
                  'android_bgidle_stops_on_resume', 'android_bgidle_away_measured'):
            self.assertTrue(r[n], n)

    def test_bgidle_service_missing_fails(self):
        self.assertEqual(self.go('bgidle_none', resign=True), 1)
        r = self.results()
        self.assertFalse(r['android_bgidle_service'])
        self.assertFalse(r['android_bgidle_notification'])
        self.assertFalse(r['android_bgidle_away_measured'])

    def test_autosave(self):
        self.go('ok', resign=True)
        r = self.results()
        self.assertTrue(r['android_pause_hook_fires'])
        self.assertTrue(r['android_autosave_continue'])

    def test_autosave_lost_fails(self):
        # 切后台说存成了，重开标题却没有「继续」
        self.assertEqual(self.go('autosave_lost', resign=True), 1)
        self.assertFalse(self.results()['android_autosave_continue'])

    def test_autosave_skipped_is_info(self):
        self.assertEqual(self.go('autosave_event', resign=True), 0)
        self.assertIsNone(self.results()['android_autosave_continue'])

    def test_resign_keys_crash(self):
        self.assertEqual(self.go('keys_crash', resign=True), 1)
        r = self.results()
        self.assertFalse(r['android_keys_title_j_new_game'])
        self.assertTrue(r['android_keys_title_space_new_game'])

    def test_no_entry_without_cl(self):
        # 不重签时看不到 ENTRY_SCENE 只记 INFO（不算失败）
        self.assertEqual(self.go('ok'), 0)
        self.assertIsNone(self.results()['android_enters_title'])

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
    def test_patch_checks(self):
        mod = A
        expect = 'PATCH_PROBE script=patched class=new_class data=dev.9999 img=123456'
        good = '11-11 I godot: BOOT_PATCH loaded=true reason=已载入 base=453 code=9999\n11-11 I godot: ' + expect + '\n11-11 I godot: ENTRY_SCENE=res://modes/xiyou/entry.tscn\n'
        ok = {n: o for n, o, _ in mod.patch_checks(good, expect, '{"confirmed": true}')}
        self.assertTrue(all(ok.values()), ok)
        self.assertEqual(len(ok), 4)
        bad = {n: o for n, o, _ in mod.patch_checks('I godot: ENTRY_SCENE=res://modes/xiyou/entry.tscn\n', expect, '')}
        self.assertEqual(bad, {'android_patch_loaded': False, 'android_patch_replaces_script_class_data_image': False,
                               'android_patch_enters_title': True, 'android_patch_confirmed_after_boot': False})
        half = {n: o for n, o, _ in mod.patch_checks(good.replace('img=123456', 'img=000000'), expect, '{"confirmed": false}')}
        self.assertEqual(half, {'android_patch_loaded': True, 'android_patch_replaces_script_class_data_image': False,
                                'android_patch_enters_title': True, 'android_patch_confirmed_after_boot': False})

    def test_fatal_lines_by_pid(self):
        log = ('11-07 10:00:05.000  123  130 F libc    : Fatal signal 11 (SIGSEGV)\n'
               '11-07 10:00:05.000  999  999 F libc    : Fatal signal 11 (SIGSEGV)\n'
               '11-07 10:00:06.000  500  520 E ActivityManager: ANR in local.kyo.remake\n')
        got = A.fatal_lines(log, {'123'})
        self.assertEqual(len(got), 2)
        self.assertTrue(any('ANR' in g for g in got))

    def test_cl_roundtrip_and_rewrite(self):
        import zipfile
        args = ['--', '--report-entry', '--smoke-keys=cancel,x,中文']
        self.assertEqual(A.parse_cl(A.cl_bytes(args)), args)
        with tempfile.TemporaryDirectory() as d:
            src, dst = Path(d) / 'a.apk', Path(d) / 'b.apk'
            with zipfile.ZipFile(src, 'w') as z:
                z.writestr('META-INF/CERT.SF', b's')
                z.writestr('META-INF/CERT.RSA', b'r')
                z.writestr('META-INF/MANIFEST.MF', b'm')
                z.writestr('assets/_cl_', A.cl_bytes(['old']))
                z.writestr('lib/x86_64/libgodot_android.so', b'so')
            A.with_cmdline(str(src), dst, args)
            with zipfile.ZipFile(dst) as z:
                names = z.namelist()
                self.assertEqual(A.parse_cl(z.read('assets/_cl_')), args)
                self.assertEqual(z.getinfo('assets/_cl_').compress_type, zipfile.ZIP_STORED)
            self.assertNotIn('META-INF/CERT.RSA', names)
            self.assertIn('lib/x86_64/libgodot_android.so', names)
            self.assertEqual(names.count('assets/_cl_'), 1)

    def test_key_runs_match_release_entry_smoke(self):
        spec2 = importlib.util.spec_from_file_location('发行入口冒烟', HERE / '发行入口冒烟.py')
        R = importlib.util.module_from_spec(spec2)
        spec2.loader.exec_module(R)
        self.assertEqual(A.KEY_RUNS, R.KEY_RUNS)
        self.assertEqual(A.MAP, R.MAP)

    def test_preset_has_launcher(self):
        # 启动的 Activity 名跟 Godot 安卓模板一致（GodotAppLauncher）；包名跟「安卓 发行」预设一致
        cfg = (HERE.parent / '01_Godot工程' / 'export_presets.cfg').read_text(encoding='utf-8')
        self.assertIn(f'package/unique_name="{A.PACKAGE}"', cfg)


if __name__ == '__main__':
    unittest.main()
