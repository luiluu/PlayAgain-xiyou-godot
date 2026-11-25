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
        self._saved = (M.embedded_public_key, M.export_patch, M.current_code, M.NEW_TREE, M.save_gate)
        self.gate_calls = []
        self.gate_result = []
        M.save_gate = lambda *a: (self.gate_calls.append(a), list(self.gate_result))[1]  # 存档门禁要跑真 mac 包：离线测试打桩
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
        M.embedded_public_key, M.export_patch, M.current_code, M.NEW_TREE, M.save_gate = self._saved
        M.ALLOW_REMOVAL[:] = []
        M.SKIP_SAVE_GATE = ''
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
            self.assertEqual((r / 'godot2/patch_453_470.pck').read_bytes(), self.patch_bytes)
        m = json.loads((self.repos[0] / 'godot2/channel.json').read_text(encoding='utf-8'))
        self.assertEqual(m['latest'], {'version': '0.470', 'code': 470, 'date': '2026-11-20', 'notes': ['修了一处']})
        p = m['bases']['453']['patch']
        self.assertEqual((p['code'], p['size'], p['sha256']), (470, len(self.patch_bytes), M.sha256(self.repos[0] / 'godot2/patch_453_470.pck')))
        gitee_pkg = sh('git', 'rev-parse', 'HEAD~1', cwd=self.repos[0])
        github_pkg = sh('git', 'rev-parse', 'HEAD~1', cwd=self.repos[1])
        self.assertEqual(p['urls'][0], f'https://gitee.com/someone/some-repo/raw/{gitee_pkg}/godot2/patch_453_470.pck')
        self.assertIn(f'https://cdn.jsdelivr.net/gh/someone/updates@{github_pkg}/godot2/patch_453_470.pck', p['urls'])
        # T153：gh-proxy（GitHub raw 加前缀）排第二，在 jsDelivr 前；置空 GH_PROXY 就不写
        self.assertEqual(p['urls'][1], f'https://gh-proxy.com/https://raw.githubusercontent.com/someone/updates/{github_pkg}/godot2/patch_453_470.pck')
        self.assertTrue(p['urls'][2].startswith('https://cdn.jsdelivr.net/'))
        self.assertIn(f'https://raw.githubusercontent.com/someone/updates/{github_pkg}/godot2/patch_453_470.pck', p['urls'])
        self.assertTrue(all(u.startswith('https://') and '/main/' not in u and '@main' not in u for u in p['urls']))
        # 两个仓库里的清单逐字节相同，签名用公钥验得过
        self.assertEqual((self.repos[0] / 'godot2/channel.json').read_bytes(), (self.repos[1] / 'godot2/channel.json').read_bytes())
        self.assertTrue(M.verify(self.pub, self.repos[1] / 'godot2/channel.json', self.repos[1] / 'godot2/channel.sig'))
        # 清单改一个字节就验不过
        bad = self.t / 'bad.json'
        bad.write_bytes((self.repos[0] / 'godot2/channel.json').read_bytes().replace(b'470', b'471', 1))
        self.assertFalse(M.verify(self.pub, bad, self.repos[0] / 'godot2/channel.sig'))

    def test_next_patch_replaces_old_file_and_keeps_other_bases(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '460', '--stage'), 0)
        M.current_code = lambda: 475
        self.patch_bytes = b'NEWER' * 500
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--revoke', '470'), 0)
        r = self.repos[0]
        self.assertFalse((r / 'godot2/patch_453_470.pck').exists())
        self.assertTrue((r / 'godot2/patch_453_475.pck').exists())
        self.assertTrue((r / 'godot2/patch_460_470.pck').exists())
        m = json.loads((r / 'godot2/channel.json').read_text(encoding='utf-8'))
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
        m = json.loads((self.repos[0] / 'godot2/channel.json').read_text(encoding='utf-8'))
        self.assertEqual((m['latest']['code'], m['bases'], m['min_base']), (480, {}, 480))


class FilesManifestTests(Base):
    """Kyo 11-11「接」：--stage 顺带调 生成更新清单.py，签名的补丁文件清单和补丁同一提交进发版仓库。"""
    def test_files_manifest_committed_with_package(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        for r in self.repos:
            pkg_commit_files = sh('git', 'show', '--name-only', '--format=', 'HEAD~1', cwd=r).splitlines()
            self.assertEqual(sorted(pkg_commit_files), ['godot2/patch_453_470.files.json', 'godot2/patch_453_470.files.sig', 'godot2/patch_453_470.pck'])
        r = self.repos[0]
        fm = json.loads((r / 'godot2/patch_453_470.files.json').read_text(encoding='utf-8'))
        self.assertEqual((fm['kind'], fm['code'], fm['base_code'], fm['min_base']), ('xiyou-patch-files', 470, 453, 453))
        paths = [f['path'] for f in fm['files']]
        self.assertIn('core/changed.gd', paths)
        self.assertNotIn('tests/only_in_tests.gd', paths, '发行预设排除的 tests/ 不该进补丁文件清单')
        self.assertTrue(M.verify(self.pub, r / 'godot2/patch_453_470.files.json', r / 'godot2/patch_453_470.files.sig'))

    def test_next_patch_replaces_old_files_manifest(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        M.current_code = lambda: 475
        self.patch_bytes = b'NEWER' * 500
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage'), 0)
        names = sorted(x.name for x in (self.repos[0] / 'godot2').iterdir())
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
        return json.loads((self.repos[0] / 'godot2/channel.json').read_text(encoding='utf-8'))

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
        # 没给下载页且原清单无 min_playable：默认填 Gitee 发行版页面（Kyo 11-14）
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--min-playable', 'latest'), 0)
        self.assertEqual(self._channel()['download_url'], M.DEFAULT_DOWNLOAD_URL)
        self.assertTrue(M.DEFAULT_DOWNLOAD_URL.startswith('https://gitee.com/') and M.DEFAULT_DOWNLOAD_URL.endswith('/releases'))
        self.assertEqual(self._channel()['min_playable'], 470)
        M.current_code = lambda: 475
        self.assertEqual(self.run_tool('--full-only', '--stage', '--min-playable', '0', '--download-url', 'none'), 0)
        self.assertNotIn('min_playable', self._channel())
        self.assertNotIn('download_url', self._channel())
        self.assertEqual(self.run_tool('--full-only', '--min-playable', '476'), 1)   # 比本次发布还大：会一直卡住
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'abc'), 1)
        self.assertEqual(self.run_tool('--full-only', '--download-url', 'http://example.invalid/dl'), 1)
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'dev.475'), 0)   # 清单里已去掉 min_playable：重新开启时默认补上
        self.assertEqual(json.loads((self.t / 'out/channel.json').read_text(encoding='utf-8'))['download_url'], M.DEFAULT_DOWNLOAD_URL)
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'dev.475', '--download-url', 'https://example.invalid/dl'), 0)
        self.assertEqual(json.loads((self.t / 'out/channel.json').read_text(encoding='utf-8'))['min_playable'], 475)

    def test_min_playable_allows_empty_download_url_none(self):
        # T457（Kyo 11-24「download_url 留空指 QQ 群」）：--min-playable 允许搭配 --download-url none 或空串
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--stage', '--min-playable', 'latest',
                                       '--download-url', 'none'), 0)
        ch = self._channel()
        self.assertEqual(ch['min_playable'], 470)
        self.assertNotIn('download_url', ch)
        # 已有 min_playable 且留空 download_url 时，后续不传 --download-url 应保持留空，不偷偷回填 Gitee URL
        M.current_code = lambda: 475
        self.assertEqual(self.run_tool('--full-only', '--stage'), 0)
        ch = self._channel()
        self.assertEqual(ch['min_playable'], 470)
        self.assertNotIn('download_url', ch)
        # 传入空串 "" 同样允许搭配 --min-playable
        self.assertEqual(self.run_tool('--full-only', '--min-playable', 'dev.475', '--download-url', ''), 0)
        out_ch = json.loads((self.t / 'out/channel.json').read_text(encoding='utf-8'))
        self.assertEqual(out_ch['min_playable'], 475)
        self.assertNotIn('download_url', out_ch)
        # 原清单带 download_url 时，搭配 --min-playable 与 --download-url none 应清掉原链接
        self.assertEqual(self.run_tool('--full-only', '--stage', '--min-playable', '475',
                                       '--download-url', 'https://example.invalid/dl'), 0)
        self.assertEqual(self._channel()['download_url'], 'https://example.invalid/dl')
        M.current_code = lambda: 480
        self.assertEqual(self.run_tool('--full-only', '--stage', '--min-playable', '480', '--download-url', 'none'), 0)
        ch = self._channel()
        self.assertEqual(ch['min_playable'], 480)
        self.assertNotIn('download_url', ch)

    def test_embedded_key_is_read_from_game_code(self):
        self.assertIn('BEGIN PUBLIC KEY', self._saved[0]())


def fake_pck(path: Path, entries) -> Path:
    """造一个只有目录的 Godot pck（格式 3）：entries＝[(名字, 标志)]。"""
    import struct
    d = bytearray(struct.pack('<I', len(entries)))
    for name, fl in entries:
        n = ('res://' + name).encode()
        n += b'\0' * ((4 - len(n) % 4) % 4)
        d += struct.pack('<I', len(n)) + n + struct.pack('<QQ', 0, 0 if fl & 2 else 10) + b'\0' * 16 + struct.pack('<I', fl)
    head = b'GDPC' + struct.pack('<IIIIIQQ', 3, 4, 7, 2, 2, 0, 104) + b'\0' * 64
    path.write_bytes(head + bytes(d))
    return path


class T489Tests(Base):
    """v0.04.01 事故：补丁把底包里的存档密钥记成删除，玩家 .ksv 存档全看不见。"""
    def test_removal_entry_refused_unless_allowed(self):
        pck = fake_pck(self.t / 'p.pck', [('content/build_info.json', 1), ('content/save_seal_key.json', 2)])
        probs = M.removal_problems(pck)
        self.assertEqual(len(probs), 1)
        self.assertIn('content/save_seal_key.json', probs[0])
        self.assertEqual(M.removal_problems(pck, ['content/save_seal_key.json']), [])
        self.assertEqual(M.removal_problems(fake_pck(self.t / 'q.pck', [('a.gd', 1), ('b.json', 0)])), [])

    def test_check_patch_refuses_removal(self):
        d = self.t / 'exp'
        d.mkdir()
        fake_pck(d / 'Windows.pck', [('content/save_seal_key.json', 2)])
        with self.assertRaises(M.Fail) as cm:
            M._check_patch(d, False, {'a': 'x', 'b': 'x'})
        self.assertIn('删除条目', str(cm.exception))

    def test_base_key_detected_and_injected(self):
        import os
        key = self.t / 'save_seal_key.json'
        key.write_text(json.dumps({'current': 1, 'keys': {'1': 'ab' * 32}}))
        old = os.environ.get('XIYOU_SAVE_KEY')
        os.environ['XIYOU_SAVE_KEY'] = str(key)
        try:
            src = self.t / 'src'
            (src / 'content').mkdir(parents=True)
            no_key = fake_pck(self.t / 'b0.pck', [('content/build_info.json', 1)])
            with_key = fake_pck(self.t / 'b1.pck', [('content/build_info.json', 1), ('content/save_seal_key.json', 1)])
            self.assertFalse(M.base_has_save_key(no_key))
            self.assertIsNone(M.inject_save_key(src, no_key))  # 底包没密钥（加密前的旧整包）：不往补丁里加
            self.assertTrue(M.base_has_save_key(with_key))
            got = M.inject_save_key(src, with_key)
            self.assertEqual(got.read_bytes(), key.read_bytes())
            key.write_text('{"current": 1}')  # 格式不对：不出包
            with self.assertRaises(M.Fail):
                M.inject_save_key(src, with_key)
        finally:
            if old is None:
                os.environ.pop('XIYOU_SAVE_KEY', None)
            else:
                os.environ['XIYOU_SAVE_KEY'] = old

    def test_save_gate_runs_and_blocks(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453'), 0)
        self.assertEqual(len(self.gate_calls), 1)
        self.gate_result = ['存档门禁：装补丁后读不到发行密钥封存的存档']
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453'), 1)

    def test_skip_save_gate_needs_reason(self):
        self.gate_result = ['不该跑到']
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--skip-save-gate', '本机不是 Mac'), 0)
        self.assertEqual(self.gate_calls, [])
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--skip-save-gate', '  '), 1)

    def test_sign_guard_blocks_dangerous_targets_and_positional_args(self):
        data = self.t / 'channel.json'
        data.write_text('{"schema": 1}\n', encoding='utf-8')
        key_bytes = self.key.read_bytes()

        # 1. 强制关键字参数：禁止位置参数（防传反顺序）
        with self.assertRaises(TypeError):
            M.sign(self.key, data, self.t / 'pos.sig')

        # 2. 禁止 -out 指向 .pem / .key 等敏感后缀，且不截断原私钥
        with self.assertRaises(M.Fail):
            M.sign(key=self.key, data=data, sig=self.key)
        self.assertEqual(self.key.read_bytes(), key_bytes)
        with self.assertRaises(M.Fail):
            M.sign(key=self.key, data=data, sig=self.t / 'other.PEM')

        # 3. 禁止 -out 落入「发版密钥」目录
        fake_key_dir = self.t / '发版密钥'
        fake_key_dir.mkdir()
        with self.assertRaises(M.Fail):
            M.sign(key=self.key, data=data, sig=fake_key_dir / 'channel.sig')
        self.assertFalse((fake_key_dir / 'channel.sig').exists())

        # 4. 无 .pem 后缀但与 key 或 data 同路径也必须拦截且不改原文件
        plain_key = self.t / 'priv_raw'
        plain_key.write_bytes(key_bytes)
        with self.assertRaises(M.Fail):
            M.sign(key=plain_key, data=data, sig=plain_key)
        self.assertEqual(plain_key.read_bytes(), key_bytes)
        with self.assertRaises(M.Fail):
            M.sign(key=self.key, data=data, sig=data)
        self.assertEqual(data.read_text(encoding='utf-8'), '{"schema": 1}\n')

        # 5. 非私钥文件 / 损坏私钥 / data 是私钥均拦截，且不破坏已有 sig（原子替换）
        existing_sig = self.t / 'existing.sig'
        existing_sig.write_bytes(b'KEEP_ME')
        with self.assertRaises(M.Fail):
            M.sign(key=data, data=data, sig=existing_sig)
        self.assertEqual(existing_sig.read_bytes(), b'KEEP_ME')
        bad_key = self.t / 'broken.pem'
        bad_key.write_text('-----BEGIN PRIVATE KEY-----\nBROKEN\n-----END PRIVATE KEY-----\n', encoding='utf-8')
        with self.assertRaises(M.Fail):
            M.sign(key=bad_key, data=data, sig=existing_sig)
        self.assertEqual(existing_sig.read_bytes(), b'KEEP_ME')
        self.assertEqual(list(self.t.glob('.sig_*.tmp')), [])
        with self.assertRaises(M.Fail):
            M.sign(key=self.key, data=self.key, sig=existing_sig)
        self.assertEqual(existing_sig.read_bytes(), b'KEEP_ME')

        # 6. 正常按名传参签出有效签名并验签通过
        ok_sig = self.t / 'ok.sig'
        M.sign(key=self.key, data=data, sig=ok_sig)
        self.assertTrue(M.verify(self.pub, data, ok_sig))
        self.assertEqual(list(self.t.glob('.sig_*.tmp')), [])

    def test_explicit_version_flag(self):
        self.assertEqual(self.run_tool('--base', str(self.base), '--base-code', '453', '--version', 'v0.04.05'), 0)
        m = json.loads((self.t / 'out/channel.json').read_text(encoding='utf-8'))
        self.assertEqual(m['latest']['version'], '0.04.05')


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *sys.argv[1:]])
