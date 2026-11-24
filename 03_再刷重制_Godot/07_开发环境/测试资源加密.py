#!/usr/bin/env python3
"""资源加密.py（T452）与发行内容审计读加密包的专项：不起 Godot，用 openssl 按 Godot 的格式造加密 pck／apk。
  python3 测试资源加密.py
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import unittest
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f'{name}.py')
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


E = load('资源加密')
A = load('发行内容审计')
KEY = bytes(range(32))
WRONG = bytes(32 - i for i in range(32))


def enc_blob(data: bytes, key: bytes, iv: bytes = b'\x07' * 16) -> bytes:
    """同 Godot FileAccessEncrypted 写法：md5＋长度＋IV＋AES-256-CFB（补齐 16）。"""
    pad = data + b'\0' * ((-len(data)) % 16)
    ct = subprocess.run(['openssl', 'enc', '-aes-256-cfb', '-K', key.hex(), '-iv', iv.hex(), '-nopad'],
                        input=pad, capture_output=True, check=True).stdout
    return hashlib.md5(data).digest() + struct.pack('<Q', len(data)) + iv + ct


def make_pck(path: Path, files: dict, key: bytes = KEY, encrypt=lambda n: E.must_encrypt(n), sparse=False):
    """files：名字 → 原文。sparse＝True 时只写目录（安卓 assets.sparsepck 那样，偏移 0），返回 {名字: 存的字节}。"""
    stored = {}
    with open(path, 'wb') as f:
        hdr = b'GDPC' + struct.pack('<IIIII', 3, 4, 7, 2, 2 | (4 if sparse else 0))
        f.write(hdr + b'\0' * 16 + b'\0' * 32)
        fbase = f.tell()
        rows = []
        for n, data in files.items():
            fl = 1 if encrypt(n) else 0
            blob = enc_blob(data, key) if fl else data
            stored[n] = blob
            if sparse:
                rows.append((n, 0, len(data), hashlib.md5(data).digest(), fl))
            else:
                rows.append((n, f.tell() - fbase, len(data), hashlib.md5(data).digest(), fl))
                f.write(blob + b'\0' * ((-len(blob)) % 32))
        diroff = f.tell()
        f.write(struct.pack('<I', len(rows)))
        for n, ofs, size, md5, fl in rows:
            b = n.encode() + b'\0' * ((-len(n.encode())) % 4)
            f.write(struct.pack('<I', len(b)) + b + struct.pack('<QQ', ofs, size) + md5 + struct.pack('<I', fl))
        f.seek(len(hdr))
        f.write(struct.pack('<QQ', fbase, diroff))
    return stored


def make_apk(path: Path, files: dict, key: bytes = KEY, extra: dict = None, encrypt=lambda n: E.must_encrypt(n)):
    with tempfile.TemporaryDirectory() as td:
        sp = Path(td) / 's.pck'
        stored = make_pck(sp, files, key, encrypt, sparse=True)
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr(E.SPARSE, sp.read_bytes())
            for n, blob in stored.items():
                z.writestr('assets/' + n, blob)
            for n, b in (extra or {}).items():
                z.writestr(n, b)


FILES = {
    'modes/xiyou/core/x.gdc': b'GDSC' + b'\0' * 8 + b'func x(): pass',
    'modes/xiyou/generated/db/Skills.json': '{"技能":"中文"}'.encode(),
    'content/save_seal_key.json': b'{"current":1}',
    'content/a.png.import': b'[remap]',
    '.godot/imported/a.ctex': b'GST2' + b'\x01' * 50,
}


class Crypto(unittest.TestCase):
    def test_roundtrip_and_wrong_key(self):
        data = '中文对话、技能 JSON'.encode() * 7
        blob = enc_blob(data, KEY)
        self.assertEqual(E.decrypt(blob, KEY), data)
        with self.assertRaises(ValueError):
            E.decrypt(blob, WRONG)
        with self.assertRaises(ValueError):
            E.decrypt(blob, b'')

    def test_stored_size(self):
        self.assertEqual(E.stored_size(5, 0), 5)
        self.assertEqual(E.stored_size(5, 1), 56)
        self.assertEqual(E.stored_size(16, 1), 56)
        self.assertEqual(len(enc_blob(b'x' * 17, KEY)), E.stored_size(17, 1))

    def test_must_encrypt(self):
        for n in ('modes/a.gd', 'modes/a.gdc', 'res://a/b.json', '.godot/exported/1/x.scn', 'a.gd.remap', '.godot/global_script_class_cache.cfg'):
            self.assertTrue(E.must_encrypt(n), n)
        for n in ('content/a.png', '.godot/imported/a.ctex', 'fonts/a.ttf', 'project.binary'):
            self.assertFalse(E.must_encrypt(n), n)


class Scan(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.d = Path(self.td.name)

    def tearDown(self):
        self.td.cleanup()

    def test_pck_clean_and_audit_reads_plain(self):
        p = self.d / 'g.pck'
        make_pck(p, FILES)
        self.assertEqual(E.scan(p, KEY), [])
        old = os.environ.get(E.ENV_KEY)
        os.environ[E.ENV_KEY] = KEY.hex()
        try:
            got = A.read_files(p, lambda n: n.endswith('.json'))
        finally:
            os.environ.pop(E.ENV_KEY) if old is None else os.environ.__setitem__(E.ENV_KEY, old)
        self.assertEqual(got['modes/xiyou/generated/db/Skills.json'].decode(), '{"技能":"中文"}')
        self.assertEqual(got['content/save_seal_key.json'], b'{"current":1}')

    def test_pck_plaintext_json_flagged(self):
        p = self.d / 'g.pck'
        make_pck(p, FILES, encrypt=lambda n: n.endswith('.gdc'))
        v = E.scan(p, KEY)
        self.assertTrue(any('Skills.json 没加密' in x for x in v), v)

    def test_wrong_key_flagged(self):
        p = self.d / 'g.pck'
        make_pck(p, FILES, key=WRONG)
        v = E.scan(p, KEY)
        self.assertTrue(v and all('解不开' in x for x in v), v)

    def test_audit_without_key_is_problem_not_clean(self):
        p = self.d / 'g.pck'
        make_pck(p, FILES)
        saved = (os.environ.pop(E.ENV_KEY, None), E.KEY_FILE)
        try:
            os.environ['XIYOU_PCK_KEY'] = str(self.d / 'nope.json')
            with self.assertRaises(ValueError):
                A.read_files(p, lambda n: n.endswith('.json'))
        finally:
            os.environ.pop('XIYOU_PCK_KEY', None)
            if saved[0] is not None:
                os.environ[E.ENV_KEY] = saved[0]

    def test_apk_clean_extra_and_outside(self):
        a = self.d / 'g.apk'
        make_apk(a, FILES)
        self.assertEqual(E.scan(a, KEY), [])
        b = self.d / 'h.apk'
        make_apk(b, FILES, extra={'assets/modes/leak.json': b'{}', 'res/raw/x.json': b'{}', 'lib/arm64-v8a/libgodot_android.so': b'\0'})
        v = E.scan(b, KEY)
        self.assertTrue(any('leak.json' in x and '包外明文' in x for x in v), v)
        self.assertTrue(any('res/raw/x.json' in x for x in v), v)

    def test_apk_read_files_decrypts(self):
        a = self.d / 'g.apk'
        make_apk(a, FILES)
        os.environ[E.ENV_KEY] = KEY.hex()
        try:
            got = A.read_files(a, lambda n: n == 'content/save_seal_key.json')
        finally:
            os.environ.pop(E.ENV_KEY)
        self.assertEqual(got, {'content/save_seal_key.json': b'{"current":1}'})

    def test_zip_with_loose_json_flagged(self):
        p = self.d / 'g.pck'
        make_pck(p, FILES)
        z = self.d / 'mac.zip'
        with zipfile.ZipFile(z, 'w') as zf:
            zf.write(p, 'a.app/Contents/Resources/g.pck')
            zf.writestr('a.app/Contents/Info.plist', b'x')
            zf.writestr('a.app/Contents/Resources/leak.json', b'{}')
        v = E.scan(z, KEY)
        self.assertEqual(len(v), 1, v)
        self.assertIn('leak.json', v[0])

    def test_apk_to_pck_keeps_encryption(self):
        a = self.d / 'g.apk'
        make_apk(a, FILES)
        out = self.d / 'o.pck'
        self.assertEqual(E.apk_to_pck(a, out), len(FILES))
        self.assertEqual(E.scan(out, KEY), [])
        with open(out, 'rb') as f:
            ents = E.pck_entries(f, 0)
            ofs, size, fl = ents['modes/xiyou/generated/db/Skills.json']
            f.seek(ofs)
            self.assertEqual(E.decrypt(f.read(size), KEY).decode(), '{"技能":"中文"}')
            ofs, size, fl = ents['.godot/imported/a.ctex']
            f.seek(ofs)
            self.assertEqual((f.read(size), fl), (FILES['.godot/imported/a.ctex'], 0))


class PatchBase(unittest.TestCase):
    def test_old_unencrypted_base_refused(self):
        """发布补丁.py：加密前的旧整包当底包时不出加密补丁（旧程序没密钥，装上就进不了游戏）。"""
        P = load('发布补丁')
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            make_pck(d / 'old.pck', FILES, encrypt=lambda n: False)
            make_pck(d / 'new.pck', FILES)
            self.assertFalse(P.base_encrypted(d / 'old.pck'))
            self.assertTrue(P.base_encrypted(d / 'new.pck'))
            saved = P._export_env
            P._export_env = lambda src: {'GODOT_SCRIPT_ENCRYPTION_KEY': KEY.hex()}
            try:
                with self.assertRaises(P.Fail) as cm:
                    P._export_presets(d / 'old.pck', d, False, {}, d)
            finally:
                P._export_env = saved
            self.assertIn('加密前的旧整包', str(cm.exception))


class Templates(unittest.TestCase):
    def test_template_has_key(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            (d / 'w.exe').write_bytes(b'MZ' + b'\0' * 100 + KEY + b'\0' * 10)
            self.assertTrue(E.template_has_key(d / 'w.exe', KEY))
            self.assertFalse(E.template_has_key(d / 'w.exe', WRONG))
            with zipfile.ZipFile(d / 'macos.zip', 'w') as z:
                z.writestr('macos_template.app/Contents/MacOS/godot_macos_release.universal', b'\0' * 9 + KEY)
            self.assertTrue(E.template_has_key(d / 'macos.zip', KEY))
            import io
            aar = io.BytesIO()
            with zipfile.ZipFile(aar, 'w') as z:
                z.writestr('jni/arm64-v8a/libgodot_android.so', b'\0' + KEY)
            with zipfile.ZipFile(d / 'android_source.zip', 'w') as z:
                z.writestr('libs/release/godot-lib.template_release.aar', aar.getvalue())
            self.assertTrue(E.template_has_key(d / 'android_source.zip', KEY))

    def test_template_problems(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            os.environ['XIYOU_AES_TEMPLATES'] = str(d)
            try:
                self.assertIn('没装', E.template_problems(KEY)[0])
                (d / E.FINGERPRINT_FILE).write_text(E.fingerprint(WRONG))
                self.assertIn('另一把密钥', E.template_problems(KEY)[0])
                (d / E.FINGERPRINT_FILE).write_text(E.fingerprint(KEY))
                for f in list(E.TEMPLATE_FILES.values()) + [E.ANDROID_SOURCE]:
                    (d / f).write_bytes(b'\0' + KEY)
                self.assertEqual(E.template_problems(KEY), [])
                (d / 'macos.zip').write_bytes(b'\0' + WRONG)
                self.assertTrue(any('找不到这把密钥' in x for x in E.template_problems(KEY)))
                self.assertIn('没有资源加密密钥', E.template_problems(b'')[0])
            finally:
                os.environ.pop('XIYOU_AES_TEMPLATES')


class Presets(unittest.TestCase):
    CFG = (ROOT / '03_再刷重制_Godot' / '01_Godot工程' / 'export_presets.cfg').read_text(encoding='utf-8')

    def test_release_presets_encrypted_acceptance_not(self):
        for name in E.RELEASE_PRESETS:
            self.assertEqual(E.preset_value(self.CFG, name, 'encrypt_pck'), 'true', name)
            self.assertEqual(E.preset_value(self.CFG, name, 'encrypt_directory'), 'false', name)  # 只加密文件，名单可审计
            self.assertEqual(E.preset_value(self.CFG, name, 'encryption_include_filters'), '"' + E.ENC_INCLUDE_TEXT + '"', name)
            self.assertEqual(E.preset_value(self.CFG, name, 'seed'), str(E.ENC_SEED), name)
        for name in ('macOS 验收', 'Windows 验收', '安卓 验收'):
            self.assertIn(E.preset_value(self.CFG, name, 'encrypt_pck'), (None, 'false'), name)

    def test_release_templates_point_to_aes(self):
        for sec, f in (('1', 'macos.zip'), ('3', 'windows_release_x86_64.exe'), ('5', 'android_release.apk')):
            body = re.search(r'^\[preset\.%s\.options\]\n(.*?)(?=^\[|\Z)' % sec, self.CFG, re.M | re.S).group(1)
            self.assertIn(f'custom_template/release="', body)
            self.assertIn(f'/{E.TEMPLATE_VERSION}_aes/{f}"', body)

    def test_no_key_material_in_public_repo_files(self):
        """公开仓零密钥：预设、本工具、工作流里没有 64 位十六进制串，也没有 script_encryption_key 赋值。"""
        files = [ROOT / '03_再刷重制_Godot' / '01_Godot工程' / 'export_presets.cfg', HERE / '资源加密.py',
                 ROOT / '.github' / 'workflows' / 'encrypted-templates.yml']
        for p in files:
            t = p.read_text(encoding='utf-8')
            self.assertIsNone(re.search(r'(?<![0-9a-fA-F])[0-9a-fA-F]{64}(?![0-9a-fA-F])', t), p.name)
            self.assertNotIn('script_encryption_key=', t, p.name)
        real = E.load_key()
        if real:  # 本机有真密钥时：公开仓里所有被跟踪的文本文件都不含它
            out = subprocess.run(['git', '-C', str(ROOT), 'grep', '-I', '-l', '-F', real.hex()], capture_output=True, text=True)
            self.assertEqual(out.stdout.strip(), '', '公开仓里有密钥明文：' + out.stdout)

    def test_strip_encryption(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / 'export_presets.cfg'
            p.write_text(self.CFG, encoding='utf-8')
            E.strip_encryption(p)
            t = p.read_text(encoding='utf-8')
            for name in E.RELEASE_PRESETS:
                self.assertEqual(E.preset_value(t, name, 'encrypt_pck'), 'false')


if __name__ == '__main__':
    unittest.main()
