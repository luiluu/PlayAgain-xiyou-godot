#!/usr/bin/env python3
"""导出冒烟.py 的离线回归：结果解析、报告生成、找 .app、Windows 包结构（不导出、不跑 Godot）。"""
import importlib.util
import os
from pathlib import Path
import tempfile
import json
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


def fake_pe(machine=0x8664, subsystem=2, resources=False, version='0.0.0.0') -> bytes:
    head = bytearray(0x800 if resources else 512)
    head[:2] = b'MZ'
    head[0x3C:0x40] = (0x80).to_bytes(4, 'little')
    head[0x80:0x84] = b'PE\0\0'
    head[0x84:0x86] = machine.to_bytes(2, 'little')
    head[0x80 + 24 + 68:0x80 + 24 + 70] = subsystem.to_bytes(2, 'little')
    if resources:  # PE32+：一个 .rsrc 节，资源根目录有图标组（14）和版本（16），后面跟版本字符串
        opt = 0x80 + 24
        head[0x86:0x88] = (1).to_bytes(2, 'little')
        head[0x94:0x96] = (240).to_bytes(2, 'little')
        head[opt:opt + 2] = (0x20B).to_bytes(2, 'little')
        head[opt + 112 + 16:opt + 112 + 20] = (0x1000).to_bytes(4, 'little')
        sec = opt + 240
        head[sec:sec + 8] = b'.rsrc\0\0\0'
        head[sec + 8:sec + 12] = (0x400).to_bytes(4, 'little')
        head[sec + 12:sec + 16] = (0x1000).to_bytes(4, 'little')
        head[sec + 20:sec + 24] = (0x400).to_bytes(4, 'little')
        head[0x40E:0x410] = (2).to_bytes(2, 'little')
        head[0x410:0x414] = (14).to_bytes(4, 'little')
        head[0x418:0x41C] = (16).to_bytes(4, 'little')
        at = 0x500
        for key in ('FileVersion', 'ProductVersion'):
            tag = (key + '\0').encode('utf-16-le')
            head[at:at + len(tag)] = tag
            at += len(tag)
            at += (-at) % 4
            val = (version + '\0').encode('utf-16-le')
            head[at:at + len(val)] = val
            at += len(val) + 4
    return bytes(head)


class WindowsLayoutTests(unittest.TestCase):
    def test_pe_info(self):
        with tempfile.TemporaryDirectory() as d:
            exe = Path(d) / 'a.exe'
            exe.write_bytes(fake_pe())
            self.assertEqual(smoke.pe_info(exe), {'machine': 'x86_64', 'subsystem': '图形界面'})
            exe.write_bytes(fake_pe(0xAA64, 3))
            self.assertEqual(smoke.pe_info(exe), {'machine': 'arm64', 'subsystem': '控制台'})
            self.assertEqual(smoke.pe_resources(fake_pe(resources=True, version='9.8.7.6')),
                             {'icon': True, 'versionInfo': True, 'fileVersion': '9.8.7.6', 'productVersion': '9.8.7.6'})
            self.assertEqual(smoke.pe_resources(fake_pe())['icon'], False)
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
            probs = smoke.windows_layout(exe)[0]
            self.assertTrue(any('图标' in p for p in probs) and any('fileVersion' in p for p in probs), probs)
            # 版本号按开发编号（XDesktopVersion 开着时导出改写成 0.N.0.0；关着才比预设的 0.0.0.0，平台 FB）
            v = smoke.expected_desktop_version('windows') or '0.0.0.0'
            exe.write_bytes(fake_pe(resources=True, version=v))
            self.assertEqual(smoke.windows_layout(exe)[0], [])
            if v != '0.0.0.0':
                exe.write_bytes(fake_pe(resources=True))  # 预设占位 0.0.0.0 没被改写＝版本号没生效
                self.assertEqual(len(smoke.windows_layout(exe)[0]), 2)
            exe.write_bytes(fake_pe(resources=True, version='1.2.3.4'))
            self.assertEqual(len(smoke.windows_layout(exe)[0]), 2)
            exe.write_bytes(fake_pe(resources=True))
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
        self.assertEqual(smoke.preset_template('安卓 验收', 'version/code'), '1')
        self.assertIsNone(smoke.preset_template('安卓 验收', '没有这个键'))


class AndroidLayoutTests(unittest.TestCase):
    BADGING = "package: name='local.kyo.remake.verification' versionCode='1' versionName='0.0.0'\napplication: label='x' icon='res/mipmap/icon.png'\nuses-permission: name='android.permission.WAKE_LOCK'\nnative-code: 'arm64-v8a'\n"
    XML = "      A: http://schemas.android.com/apk/res/android:screenOrientation(0x0101001e)=11\n"

    def test_parse(self):
        info = smoke.parse_android(self.BADGING, self.XML)
        self.assertEqual(info, {'package': 'local.kyo.remake.verification', 'native': ['arm64-v8a'], 'orientation': 11,
                                'permissions': ['android.permission.WAKE_LOCK'], 'versionCode': '1', 'versionName': '0.0.0',
                                'icon': 'res/mipmap/icon.png', 'label': None})
        self.assertEqual(smoke.parse_android('', '')['orientation'], None)

    def test_problems(self):
        names = {'assets/project.binary', 'assets/modes/xiyou/generated/db/System.json', 'assets/scenes/entry_menu.tscn.remap',
                 'assets/tests/xiyou_mac_export.tscn.remap'}
        info = dict(smoke.parse_android(self.BADGING, self.XML), **smoke.expected_android_version('安卓 验收'))
        self.assertEqual(smoke.android_problems(info, names), [])
        portrait = dict(info, orientation=1, native=['armeabi-v7a'])
        probs = smoke.android_problems(portrait, names - {'assets/project.binary'})
        self.assertEqual(len(probs), 3, probs)
        bumped = dict(info, versionName='9.9', icon=None)
        self.assertEqual(len(smoke.android_problems(bumped, names)), 2, smoke.android_problems(bumped, names))
        self.assertEqual(smoke.android_problems(dict(info, package=smoke.preset_template('安卓 发行', 'package/unique_name')), names - {'assets/tests/xiyou_mac_export.tscn.remap'}, debug=False), [])

    def test_expected_version_from_dev(self):
        # 导出插件开着（XAndroidVersion.AUTO）：versionCode＝开发编号数字、versionName＝0.数字；预设里的 1／0.0.0 不再是对的
        info = json.loads((smoke.PROJECT / 'content' / 'build_info.json').read_text(encoding='utf-8'))
        n = int(info['developmentVersion'].removeprefix('dev.'))
        self.assertEqual(smoke.expected_android_version('安卓 发行'), {'versionCode': str(n), 'versionName': '0.%d' % n})
        stale = dict(smoke.parse_android(self.BADGING, self.XML), package=smoke.preset_template('安卓 发行', 'package/unique_name'))
        probs = smoke.android_problems(stale, {'assets/project.binary', 'assets/modes/xiyou/generated/db/System.json', 'assets/scenes/entry_menu.tscn.remap'}, debug=False)
        self.assertEqual(len(probs), 2, probs)

    def test_apk_sizes(self):
        import zipfile
        with tempfile.TemporaryDirectory() as d:
            apk = Path(d) / 'a.apk'
            with zipfile.ZipFile(apk, 'w', zipfile.ZIP_STORED) as z:
                z.writestr('assets/.godot/imported/Bg.png-' + '0' * 32 + '.ctex', b'x' * 300)
                z.writestr('assets/.godot/imported/Bgm.ogg-' + '1' * 32 + '.oggvorbisstr', b'x' * 200)
                z.writestr('assets/tests/a.gdc', b'x' * 50)
                z.writestr('lib/arm64-v8a/libgodot.so', b'x' * 100)
            with zipfile.ZipFile(apk) as z:
                sizes = smoke.apk_sizes(z.infolist())
            self.assertEqual([k for k, *_ in sizes], ['assets/.godot/imported（png→ctex）', 'assets/.godot/imported（ogg→oggvorbisstr）', 'lib', 'assets/tests'])
            info = {'time': 't', 'platform': 'android', 'preset': '安卓 验收', 'zip': 'x.apk', 'ok': True, 'layout': '通过',
                    'archs': 'arm64-v8a', 'package': 'p', 'scenes': [], 'sizes': sizes}
            text = smoke.report(Path(d), info).read_text(encoding='utf-8')
            self.assertIn('## 包体积', text)
            self.assertIn('| lib | 0.0 | 15.4% |', text)

    def test_android_report(self):
        with tempfile.TemporaryDirectory() as d:
            info = {'time': 't', 'platform': 'android', 'preset': '安卓 验收', 'zip': 'x.apk', 'ok': False, 'layout': '通过',
                    'archs': 'arm64-v8a', 'package': 'p', 'scenes': []}
            text = smoke.report(Path(d), info).read_text(encoding='utf-8')
            self.assertIn('# 安卓导出冒烟报告', text)
            self.assertIn('apksigner', text)
            self.assertIn('两指取消', text)



class CloudExportTests(unittest.TestCase):
    """云端导出.py：预设模板路径改写只动指定预设、登记段齐全（不联网）。"""
    def setUp(self):
        spec2 = importlib.util.spec_from_file_location('cloud_export', HERE / '云端导出.py')
        self.ce = importlib.util.module_from_spec(spec2)
        spec2.loader.exec_module(self.ce)

    def test_rewrite_presets(self):
        text = (HERE.parent / '01_Godot工程' / 'export_presets.cfg').read_text(encoding='utf-8')
        conf = self.ce.cloud_export()
        out = self.ce.rewrite_presets(text, Path('/c/t'), conf['presets'])
        self.assertIn('custom_template/debug="/c/t/windows_debug_x86_64.exe"', out)
        self.assertIn('custom_template/debug="/c/t/android_debug.apk"', out)
        # 「Windows 发行」只换 release 模板（给 windows-run 真跑，平台 FB）；它的 debug、Mac／安卓发行都不动
        self.assertIn('custom_template/release="/c/t/windows_release_x86_64.exe"', out)
        self.assertIn('custom_template/release="/c/t/android_release.apk"', out)  # android-run 用（平台 FB 二批）
        self.assertEqual(out.count('/c/t/'), 4)
        self.assertEqual(len(out.splitlines()), len(text.splitlines()))
        self.assertIn('Windows 发行', out)

    def test_registry(self):
        conf = self.ce.cloud_export()
        self.assertTrue({'windows_debug_x86_64.exe', 'windows_debug_x86_64_console.exe', 'android_debug.apk', conf['runner']} <= set(conf['templates']))
        for files in conf['presets'].values():
            self.assertTrue(set(files.values()) <= set(conf['templates']))
        entry = self.ce.tpz_entry(self.ce.registry())
        self.assertEqual(len(entry['sha512']), 128)
        self.assertEqual(len(entry['sha256']), 64)
        self.assertEqual(conf['artifactRetentionDays'], 3)

if __name__ == '__main__':
    unittest.main()
