#!/usr/bin/env python3
"""生成更新清单.py 的离线测试：假的新旧版本目录、临时生成的 RSA 密钥（测试结束即删），不碰真私钥、不联网。"""
import contextlib
import hashlib
import importlib.util
import io
import json
import subprocess
import tempfile
import unicodedata
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('生成更新清单', HERE / '生成更新清单.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


def genkey(path: Path) -> None:
    subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(path)],
                   check=True, capture_output=True)


def write(root: Path, rel: str, data) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(data if isinstance(data, bytes) else data.encode('utf-8'))


class T(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.td = tempfile.TemporaryDirectory()
        cls.key = Path(cls.td.name) / 'fake_private.pem'
        genkey(cls.key)
        cls.pub = Path(cls.td.name) / 'fake_public.pem'
        subprocess.run(['openssl', 'pkey', '-in', str(cls.key), '-pubout', '-out', str(cls.pub)], check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.td.cleanup()

    def setUp(self):
        self.d = tempfile.TemporaryDirectory()
        t = Path(self.d.name)
        self.old, self.new, self.out = t / 'old', t / 'new', t / 'out'
        for root, code in ((self.old, 470), (self.new, 471)):
            write(root, M.BUILD_INFO, json.dumps({'developmentVersion': f'dev.{code}'}))
            write(root, 'core/boot_patch.gd', 'extends Node\n')
            write(root, 'core/same.gd', 'same\n')
            write(root, 'content/图/立绘.png', b'\x89PNG' + b'0' * 100)
        write(self.old, 'modes/xiyou/data/old_only.json', '{}')
        write(self.old, 'core/changed.gd', 'v1\n')
        write(self.new, 'core/changed.gd', 'v2 longer\n')
        write(self.new, 'content/图/立绘.png', b'\x89PNG' + b'1' * 100)  # 同字节数、内容不同
        write(self.new, 'modes/xiyou/data/新增.json', '{"a":1}')
        write(self.new, '.godot/imported/x.ctex', 'cache')
        write(self.new, '.DS_Store', 'junk')

    def tearDown(self):
        self.d.cleanup()

    def run_tool(self, *args, key=True):
        argv = ['--old', str(self.old), '--new', str(self.new), '--out', str(self.out), *args]
        if key:
            argv += ['--key', str(self.key)]
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = M.main(argv)
        self.output = buf.getvalue()
        return rc

    def manifest(self):
        return json.loads((self.out / M.MANIFEST).read_text(encoding='utf-8'))

    def test_end_to_end(self):
        self.assertEqual(self.run_tool('--date', '2026-11-11'), 0, self.output)
        m = self.manifest()
        self.assertEqual((m['schema'], m['kind'], m['version'], m['code'], m['base_code'], m['min_base'], m['date']),
                         (1, 'xiyou-patch-files', '0.471', 471, 470, 470, '2026-11-11'))
        by = {f['path']: f for f in m['files']}
        self.assertEqual(sorted(by), sorted([M.BUILD_INFO, 'content/图/立绘.png', 'core/changed.gd', 'modes/xiyou/data/新增.json']))
        self.assertEqual(by['core/changed.gd']['change'], 'modified')
        self.assertEqual(by['content/图/立绘.png']['change'], 'modified')
        self.assertEqual(by['modes/xiyou/data/新增.json']['change'], 'added')
        for rel, f in by.items():
            data = (self.new / rel).read_bytes()
            self.assertEqual((f['size'], f['sha256']), (len(data), hashlib.sha256(data).hexdigest()), rel)
        self.assertEqual(m['removed'], ['modes/xiyou/data/old_only.json'])
        self.assertEqual(m['total'], {'files': 4, 'bytes': sum(f['size'] for f in m['files']), 'removed': 1})
        self.assertNotIn('core/same.gd', by)
        self.assertFalse(any('.godot' in p or '.DS_Store' in p for p in by), '默认排除没生效')
        self.assertEqual((self.out / M.FILES_TXT).read_text(encoding='utf-8').splitlines(), [f['path'] for f in m['files']])
        # 签名：openssl 用公钥验得过；改一个字节就验不过
        sig, mj = self.out / M.SIG, self.out / M.MANIFEST
        ok = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(self.pub), '-signature', str(sig), str(mj)], capture_output=True)
        self.assertEqual(ok.returncode, 0)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(M.main(['--verify', str(mj), '--pubkey', str(self.pub), '--new', str(self.new)]), 0)
        (self.new / 'core/changed.gd').write_text('tampered\n')
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(M.main(['--verify', str(mj), '--pubkey', str(self.pub), '--new', str(self.new)]), 1, '目录被改没认出')
        mj.write_bytes(mj.read_bytes().replace(b'"0.471"', b'"0.472"'))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(M.main(['--verify', str(mj), '--pubkey', str(self.pub)]), 1, '改过的清单验签居然通过')

    def test_other_key_fails_verify(self):
        self.assertEqual(self.run_tool(), 0, self.output)
        other = Path(self.d.name) / 'other.pem'
        genkey(other)
        other_pub = Path(self.d.name) / 'other_pub.pem'
        subprocess.run(['openssl', 'pkey', '-in', str(other), '-pubout', '-out', str(other_pub)], check=True, capture_output=True)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(M.main(['--verify', str(self.out / M.MANIFEST), '--pubkey', str(other_pub)]), 1)

    def test_key_required_and_unsigned_preview(self):
        import os
        saved = os.environ.pop('XIYOU_UPDATE_KEY', None)
        try:
            self.assertEqual(self.run_tool(key=False), 1)
            self.assertIn('--key', self.output)
            self.assertEqual(self.run_tool('--unsigned', key=False), 0, self.output)
            self.assertTrue((self.out / M.MANIFEST).exists())
            self.assertFalse((self.out / M.SIG).exists())
        finally:
            if saved is not None:
                os.environ['XIYOU_UPDATE_KEY'] = saved

    def test_unsigned_rerun_drops_stale_sig(self):
        self.assertEqual(self.run_tool(), 0)
        self.assertTrue((self.out / M.SIG).exists())
        self.assertEqual(self.run_tool('--unsigned', key=False), 0)
        self.assertFalse((self.out / M.SIG).exists(), '旧签名留着会配上新清单')

    def test_key_inside_repo_refused(self):
        self.assertTrue(M.inside_repo(M.REPO / 'x.pem'))
        self.assertFalse(M.inside_repo(self.key))
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = M.main(['--old', str(self.old), '--new', str(self.new), '--out', str(self.out), '--key', str(M.REPO / 'k.pem')])
        self.assertEqual(rc, 1)
        self.assertIn('仓库', buf.getvalue())

    def test_embedded_key_checked(self):
        other = Path(self.d.name) / 'other.pem'
        genkey(other)
        write(self.new, 'core/update_check.gd', 'const PUBLIC_KEY := """' + M.public_of(other) + '"""\n')
        self.assertEqual(self.run_tool(), 1)
        self.assertIn('内嵌', self.output)
        self.assertEqual(self.run_tool('--skip-embedded-check'), 0, self.output)
        write(self.new, 'core/update_check.gd', 'const PUBLIC_KEY := """' + M.public_of(self.key) + '"""\n')
        self.assertEqual(self.run_tool(), 0, self.output)

    def test_min_base_rules(self):
        self.assertEqual(self.run_tool('--min-base', '465'), 0, self.output)
        self.assertEqual(self.manifest()['min_base'], 465)
        self.assertEqual(self.run_tool('--min-base', '471'), 1)
        self.assertIn('最低基线', self.output)
        self.assertEqual(self.run_tool('--first-patchable', '468', '--min-base', '465'), 1)
        self.assertEqual(self.run_tool('--first-patchable', '471'), 1)
        self.assertEqual(self.run_tool('--first-patchable', '468'), 0, self.output)

    def test_old_without_loader_refused(self):
        (self.old / 'core/boot_patch.gd').unlink()
        self.assertEqual(self.run_tool(), 1)
        self.assertIn('载入器', self.output)
        self.assertEqual(self.run_tool('--allow-no-loader'), 0, self.output)
        (self.old / 'core/boot_patch.gdc').write_bytes(b'GDSC')  # 导出后的字节码也算
        self.assertEqual(self.run_tool(), 0, self.output)

    def test_versions(self):
        self.assertEqual(self.run_tool('--new-code', '470'), 1)
        self.assertIn('不比旧版本', self.output)
        (self.old / M.BUILD_INFO).unlink()
        self.assertEqual(self.run_tool(), 1)
        self.assertEqual(self.run_tool('--old-code', '469'), 0, self.output)
        self.assertEqual(self.manifest()['base_code'], 469)

    def test_no_diff_and_same_dir(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(M.main(['--old', str(self.old), '--new', str(self.old), '--out', str(self.out), '--unsigned']), 1)
        self.assertIn('同一个目录', buf.getvalue())
        import shutil
        shutil.rmtree(self.new)
        shutil.copytree(self.old, self.new)
        self.assertEqual(self.run_tool('--new-code', '471'), 1)
        self.assertIn('没有差别', self.output)

    def test_exclude_and_nfc(self):
        self.assertEqual(self.run_tool('--exclude', 'modes/', '--exclude', '*.png'), 0, self.output)
        paths = [f['path'] for f in self.manifest()['files']]
        self.assertEqual(sorted(paths), sorted([M.BUILD_INFO, 'core/changed.gd']))
        self.assertEqual(self.manifest()['removed'], [])
        # 旧目录用 NFD 写同一个中文名、内容相同：不算改动
        nfc = 'content/图/角色立绘.json'
        write(self.new, nfc, '{}')
        write(self.old, unicodedata.normalize('NFD', nfc), '{}')
        self.assertEqual(self.run_tool(), 0, self.output)
        self.assertNotIn(nfc, [f['path'] for f in self.manifest()['files']])

    def test_symlink_refused(self):
        (self.new / 'link.gd').symlink_to(self.new / 'core/same.gd')
        self.assertEqual(self.run_tool(), 1)
        self.assertIn('符号链接', self.output)

    def test_out_inside_repo_must_be_ignored(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = M.main(['--old', str(self.old), '--new', str(self.new), '--unsigned',
                         '--out', str(M.REPO / '03_再刷重制_Godot/07_开发环境/_不该写这里')])
        self.assertEqual(rc, 1)
        self.assertIn('gitignore', buf.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=1)
