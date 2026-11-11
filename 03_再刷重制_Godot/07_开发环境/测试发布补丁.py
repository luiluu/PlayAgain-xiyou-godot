#!/usr/bin/env python3
"""发布补丁.py 离线部分（自动更新第③批）：清单合并规则、说明里的内部信息、签名与公钥核对、--stage 的两次提交与固定到提交的地址。
用临时密钥、临时 git 仓库和假的补丁导出，不碰真私钥、真发版仓库，不联网、不推送。真导出手动跑。"""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('发布补丁', HERE / '发布补丁.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


def sh(*a, cwd=None):
    return subprocess.run(a, cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


class Base(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.t = Path(self.td.name)
        self.key = self.t / 'k.pem'
        sh('openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(self.key))
        self.pub = M.public_of(self.key)
        self._saved = (M.embedded_public_key, M.export_patch, M.current_code)
        M.embedded_public_key = lambda: self.pub
        M.current_code = lambda: 470
        self.patch_bytes = b'PATCH' * 1000

        def fake_export(base, out, dry):
            d = out / '_export'
            d.mkdir(parents=True, exist_ok=True)
            (d / 'Windows.pck').write_bytes(self.patch_bytes)
            return d / 'Windows.pck'
        M.export_patch = fake_export
        self.base = self.t / 'base.pck'
        self.base.write_bytes(b'BASE')
        self.repos = []
        for name, url in (('gitee', 'git@gitee.com:someone/some-repo.git'), ('github', 'https://github.com/someone/updates.git')):
            r = self.t / name
            r.mkdir()
            sh('git', 'init', '-q', '-b', 'main', cwd=r)
            sh('git', 'config', 'user.email', 't@example.invalid', cwd=r)
            sh('git', 'config', 'user.name', 't', cwd=r)
            sh('git', 'remote', 'add', 'origin', url, cwd=r)
            (r / 'README.md').write_text('x\n')
            sh('git', 'add', '-A', cwd=r)
            sh('git', 'commit', '-q', '-m', 'init', cwd=r)
            self.repos.append(r)

    def tearDown(self):
        M.embedded_public_key, M.export_patch, M.current_code = self._saved
        self.td.cleanup()

    def run_tool(self, *args):
        return M.main(['--key', str(self.key), '--repos', str(self.repos[0]), str(self.repos[1]), '--out', str(self.t / 'out'),
                       '--date', '2026-11-20', *args])


class StageTests(Base):
    def test_stage_commits_package_then_channel_and_pins_urls(self):
        rc = self.run_tool('--base', str(self.base), '--base-code', '453', '--note', '修了一处', '--stage')
        self.assertEqual(rc, 0)
        for r in self.repos:
            log = sh('git', 'log', '--format=%s', cwd=r).splitlines()
            self.assertEqual(log[:2], ['重制版清单指向 0.470', '重制版 0.470 补丁（底包 0.453）'])
            self.assertEqual(sh('git', 'status', '--porcelain', cwd=r), '')
            self.assertEqual((r / 'godot/patch_453_470.pck').read_bytes(), self.patch_bytes)
        m = json.loads((self.repos[0] / 'godot/channel.json').read_text(encoding='utf-8'))
        self.assertEqual(m['latest'], {'version': '0.470', 'code': 470, 'date': '2026-11-20', 'notes': ['修了一处']})
        p = m['bases']['453']['patch']
        self.assertEqual((p['code'], p['size'], p['sha256']), (470, len(self.patch_bytes), M.sha256(self.repos[0] / 'godot/patch_453_470.pck')))
        gitee_pkg = sh('git', 'rev-parse', 'HEAD~1', cwd=self.repos[0])
        github_pkg = sh('git', 'rev-parse', 'HEAD~1', cwd=self.repos[1])
        self.assertEqual(p['urls'][0], f'https://gitee.com/someone/some-repo/raw/{gitee_pkg}/godot/patch_453_470.pck')
        self.assertIn(f'https://cdn.jsdelivr.net/gh/someone/updates@{github_pkg}/godot/patch_453_470.pck', p['urls'])
        self.assertIn(f'https://raw.githubusercontent.com/someone/updates/{github_pkg}/godot/patch_453_470.pck', p['urls'])
        self.assertTrue(all(u.startswith('https://') and '/main/' not in u and '@main' not in u for u in p['urls']))
        # 两个仓库里的清单逐字节相同，签名用公钥验得过
        self.assertEqual((self.repos[0] / 'godot/channel.json').read_bytes(), (self.repos[1] / 'godot/channel.json').read_bytes())
        self.assertTrue(M.verify(self.pub, self.repos[1] / 'godot/channel.json', self.repos[1] / 'godot/channel.sig'))
        # 清单改一个字节就验不过
        bad = self.t / 'bad.json'
        bad.write_bytes((self.repos[0] / 'godot/channel.json').read_bytes().replace(b'470', b'471', 1))
        self.assertFalse(M.verify(self.pub, bad, self.repos[0] / 'godot/channel.sig'))

    def test_next_patch_replaces_old_file_and_keeps_other_bases(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '460', '--stage'), 0)
        M.current_code = lambda: 475
        self.patch_bytes = b'NEWER' * 500
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--revoke', '470'), 0)
        r = self.repos[0]
        self.assertFalse((r / 'godot/patch_453_470.pck').exists())
        self.assertTrue((r / 'godot/patch_453_475.pck').exists())
        self.assertTrue((r / 'godot/patch_460_470.pck').exists())
        m = json.loads((r / 'godot/channel.json').read_text(encoding='utf-8'))
        self.assertEqual(sorted(m['bases']), ['453', '460'])
        self.assertEqual(m['bases']['453']['patch']['code'], 475)
        self.assertEqual(m['latest']['code'], 475)
        self.assertEqual(m['revoked'], [470])

    def test_never_pushes(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        for r in self.repos:  # 远端是假的地址，没有任何远端跟踪分支＝没推过
            self.assertEqual(sh('git', 'branch', '-r', cwd=r), '')

    def test_dirty_repo_refused(self):
        (self.repos[1] / 'x.txt').write_text('脏')
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 1)
        self.assertFalse((self.repos[0] / 'godot').exists())

    def test_full_only(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        M.current_code = lambda: 480
        self.assertEqual(self.run_tool('--full-only', '--min-base', '480', '--drop-base', '453', '--stage'), 0)
        m = json.loads((self.repos[0] / 'godot/channel.json').read_text(encoding='utf-8'))
        self.assertEqual((m['latest']['code'], m['bases'], m['min_base']), (480, {}, 480))


class RuleTests(Base):
    def test_without_stage_urls_are_placeholder(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453'), 0)
        m = json.loads((self.t / 'out/channel.json').read_text(encoding='utf-8'))
        self.assertTrue(m['bases']['453']['patch']['urls'][0].startswith('https://example.invalid/'))
        self.assertFalse((self.repos[0] / 'godot').exists())

    def test_wrong_key_refused(self):
        other = self.t / 'other.pem'
        sh('openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(other))
        rc = M.main(['--key', str(other), '--repos', str(self.repos[0]), str(self.repos[1]), '--out', str(self.t / 'out'),
                     '--base', str(self.base), '--base-code', '453'])
        self.assertEqual(rc, 1)
        self.assertFalse((self.t / 'out/channel.json').exists())

    def test_base_not_older_refused(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '470'), 1)

    def test_big_patch_refused(self):
        self.patch_bytes = b'x' * (M.MAX_PATCH + 1)
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453'), 1)
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--allow-big'), 0)

    def test_internal_words_in_notes_refused(self):
        for bad in ('修了 dev.453 的问题', '见 O-123', '改了 core/x.gd', '掉率提高'):
            self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--note', bad), 1, bad)

    def test_latest_cannot_go_back(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        M.current_code = lambda: 465
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 1)

    def test_base_from_release_dir(self):
        d = self.t / 'dev453_三平台发行' / 'windows'
        d.mkdir(parents=True)
        (d / '再刷一把_天启篇.pck').write_bytes(b'BASE')
        p, code = M.resolve_base(str(d.parent), None)
        self.assertEqual((p.name, code), ('再刷一把_天启篇.pck', 453))

    def test_embedded_key_is_read_from_game_code(self):
        self.assertIn('BEGIN PUBLIC KEY', self._saved[0]())


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *sys.argv[1:]])
