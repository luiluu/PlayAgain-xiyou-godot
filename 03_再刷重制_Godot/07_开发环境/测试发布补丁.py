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
        self._saved = (M.embedded_public_key, M.export_patch, M.current_code, M.NEW_TREE)
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
        # 补丁文件清单用的假工程目录：新版本（当前工程的替身）和各底包的工程目录
        self.new_tree = self.t / 'tree_new'
        self._tree(self.new_tree, 0)
        (self.new_tree / 'core/changed.gd').write_text('v2\n')
        (self.new_tree / 'tests/only_in_tests.gd').parent.mkdir(parents=True)
        (self.new_tree / 'tests/only_in_tests.gd').write_text('不进发行包\n')
        M.NEW_TREE = self.new_tree
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

    def _tree(self, root, code):
        (root / 'core').mkdir(parents=True, exist_ok=True)
        (root / 'content').mkdir(parents=True, exist_ok=True)
        (root / 'core/boot_patch.gd').write_text('extends Node\n')
        (root / 'core/changed.gd').write_text('v1\n')
        (root / 'content/build_info.json').write_text(json.dumps({'developmentVersion': f'dev.{code}'}))
        return root

    def old_tree(self, code):
        return self._tree(self.t / f'tree_{code}', code)

    def tearDown(self):
        M.embedded_public_key, M.export_patch, M.current_code, M.NEW_TREE = self._saved
        self.td.cleanup()

    def run_tool(self, *args):
        if '--stage' in args and '--base-code' in args and '--no-files-manifest' not in args and '--old-tree' not in args:
            args = (*args, '--old-tree', str(self.old_tree(int(args[args.index('--base-code') + 1]))))
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


class FilesManifestTests(Base):
    """Kyo 11-11「接」：--stage 顺带调 生成更新清单.py，签名的补丁文件清单和补丁同一提交进发版仓库。"""
    def test_files_manifest_committed_with_package(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        for r in self.repos:
            pkg_commit_files = sh('git', 'show', '--name-only', '--format=', 'HEAD~1', cwd=r).splitlines()
            self.assertEqual(sorted(pkg_commit_files), ['godot/patch_453_470.files.json', 'godot/patch_453_470.files.sig', 'godot/patch_453_470.pck'])
        r = self.repos[0]
        fm = json.loads((r / 'godot/patch_453_470.files.json').read_text(encoding='utf-8'))
        self.assertEqual((fm['kind'], fm['code'], fm['base_code'], fm['min_base']), ('xiyou-patch-files', 470, 453, 453))
        paths = [f['path'] for f in fm['files']]
        self.assertIn('core/changed.gd', paths)
        self.assertNotIn('tests/only_in_tests.gd', paths, '发行预设排除的 tests/ 不该进补丁文件清单')
        self.assertTrue(M.verify(self.pub, r / 'godot/patch_453_470.files.json', r / 'godot/patch_453_470.files.sig'))

    def test_next_patch_replaces_old_files_manifest(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        M.current_code = lambda: 475
        self.patch_bytes = b'NEWER' * 500
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        names = sorted(x.name for x in (self.repos[0] / 'godot').iterdir())
        self.assertEqual(names, ['channel.json', 'channel.sig', 'patch_453_475.files.json', 'patch_453_475.files.sig', 'patch_453_475.pck'])

    def test_stage_without_old_tree_refused(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--no-files-manifest'), 0)
        self.assertFalse(list((self.repos[0] / 'godot').glob('*.files.*')))
        M.current_code = lambda: 475
        rc = M.main(['--key', str(self.key), '--repos', str(self.repos[0]), str(self.repos[1]), '--out', str(self.t / 'out'),
                     '--base', str(self.base), '--base-code', '453', '--stage'])
        self.assertEqual(rc, 1)
        self.assertEqual(sh('git', 'log', '-1', '--format=%s', cwd=self.repos[0]), '重制版清单指向 0.470', '被拒时不该有新提交')

    def test_old_tree_of_other_base_refused(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--old-tree', str(self.old_tree(450))), 1)
        self.assertFalse((self.repos[0] / 'godot').exists())

    def test_without_stage_written_locally(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--old-tree', str(self.old_tree(453))), 0)
        self.assertTrue((self.t / 'out/文件清单/patch_manifest.json').exists())
        self.assertTrue((self.t / 'out/文件清单/patch_manifest.sig').exists())
        self.assertFalse((self.repos[0] / 'godot').exists())

    def test_release_excludes_read_from_presets(self):
        ex = M.release_excludes()
        self.assertIn('tests/*', ex)
        self.assertIn('modes/xiyou/generated/oracle/*', ex)


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

    def _channel(self):
        return json.loads((self.repos[0] / 'godot/channel.json').read_text(encoding='utf-8'))

    def test_min_playable_default_unchanged(self):
        # 强制更新（Kyo 11-14）：不给参数就不写、也不改原值
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        self.assertNotIn('min_playable', self._channel())
        self.assertNotIn('download_url', self._channel())
        M.current_code = lambda: 475
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--min-playable', '470',
                                       '--download-url', 'https://example.invalid/dl'), 0)
        self.assertEqual((self._channel()['min_playable'], self._channel()['download_url']), (470, 'https://example.invalid/dl'))
        M.current_code = lambda: 480
        self.assertEqual(self.run_tool('--full-only', '--stage'), 0)
        self.assertEqual((self._channel()['min_playable'], self._channel()['download_url']), (470, 'https://example.invalid/dl'))

    def test_min_playable_latest_zero_and_limits(self):
        # 强制更新同时去掉下载页：拒绝，且发版仓库里什么都没提交
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--min-playable', 'latest',
                                       '--download-url', 'none'), 1)
        self.assertFalse((self.repos[0] / 'godot').exists())
        # 没给下载页：默认填 Gitee 发行版页面（Kyo 11-14）
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--min-playable', 'latest'), 0)
        self.assertEqual(self._channel()['download_url'], M.DEFAULT_DOWNLOAD_URL)
        self.assertTrue(M.DEFAULT_DOWNLOAD_URL.startswith('https://gitee.com/') and M.DEFAULT_DOWNLOAD_URL.endswith('/releases'))
        self.assertEqual(self._channel()['min_playable'], 470)
        M.current_code = lambda: 475
        self.assertEqual(self.run_tool('--full-only', '--stage', '--min-playable', '0', '--download-url', 'none'), 0)
        self.assertNotIn('min_playable', self._channel())
        self.assertEqual(self.run_tool('--full-only', '--min-playable', '476'), 1)   # 比本次发布还大：会一直卡住
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'abc'), 1)
        self.assertEqual(self.run_tool('--full-only', '--download-url', 'http://example.invalid/dl'), 1)
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'dev.475', '--download-url', 'none'), 1)
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'dev.475'), 0)   # 清单里已去掉：默认补上
        self.assertEqual(json.loads((self.t / 'out/channel.json').read_text(encoding='utf-8'))['download_url'], M.DEFAULT_DOWNLOAD_URL)
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'dev.475', '--download-url', 'https://example.invalid/dl'), 0)
        self.assertEqual(json.loads((self.t / 'out/channel.json').read_text(encoding='utf-8'))['min_playable'], 475)

    def test_embedded_key_is_read_from_game_code(self):
        self.assertIn('BEGIN PUBLIC KEY', self._saved[0]())


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *sys.argv[1:]])
