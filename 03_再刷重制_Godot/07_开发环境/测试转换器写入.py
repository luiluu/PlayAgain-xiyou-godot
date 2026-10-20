#!/usr/bin/env python3
"""转换器写入生命周期：不改字节／时间戳，清理退出产物，中断不暴露半文件。"""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1] / '03_转换工具'
sys.path.insert(0, str(TOOLS))
import xiyou_export as exporter


class FixtureExporter(exporter.Exporter):
    """只替换游戏引用遍历；真实运行写入、素材复制、来源检查、清理和 manifest。"""
    def export_db(self):
        self.db = {'Skills': [None], 'Items': [None]}
        # 生产路径也会先写原始表，再补行动序列／装备字段，最后才得到最终表。
        self.write_json('db/Items.json', {'stage': 'intermediate'})

    def export_plugins(self):
        self.write_json('db/Items.json', {'stage': 'final', 'value': self.cfg.get('value', 1)})

    def collect_slice(self):
        self.slice_info = {'skills': [], 'items': [], 'maps': self.cfg['maps']}
        for mid in self.cfg['maps']:
            rel = f'maps/Map{mid:03d}.json'
            self.write_json(rel, self.read('data/' + Path(rel).name))
        self.img.update(self.cfg.get('pictures', []))
        self.audio.update(self.cfg.get('audio', []))


class ExportWriteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app, self.out = self.root / 'app', self.root / 'incremental'
        for rel, content in {
            'package.json': b'{"releaseVersion":"fixture"}', 'js/rules.js': b'// fixture',
            'data/Map001.json': b'{"id":1}', 'data/Map002.json': b'{"id":2}',
            'img/pictures/a.png': b'image-a', 'img/pictures/b.png': b'image-b',
            'audio/se/a.ogg': b'audio-a', 'fonts/font.ttf': b'font',
        }.items():
            path = self.app / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        self.cfg = {'maps': [1, 2], 'pictures': ['pictures/a', 'pictures/b'],
                    'audio': ['se/a'], 'fonts': ['font.ttf']}

    def run_export(self, out=None, cfg=None):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            FixtureExporter(self.app, out or self.out, cfg or self.cfg).run()
        return json.loads(output.getvalue())

    def snapshot(self, directory, metadata=False):
        return {p.relative_to(directory).as_posix():
                (p.read_bytes(), p.stat().st_mtime_ns, p.stat().st_ino) if metadata else p.read_bytes()
                for p in directory.rglob('*') if p.is_file()}

    def products(self, directory):
        return {k: v for k, v in self.snapshot(directory).items()
                if not k.startswith('oracle/') and k != 'sync_stamp.json' and not k.endswith('.import')}

    def test_no_change_preserves_all_files_and_never_creates_temporary(self):
        first = self.run_export()
        for rel in ['img/pictures/a.png.import', 'db/Items.json.import', 'oracle/keep.json', 'sync_stamp.json']:
            path = self.out / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'keep')
        before = self.snapshot(self.out, metadata=True)
        with mock.patch.object(exporter.tempfile, 'mkstemp', side_effect=AssertionError('unexpected write')):
            second = self.run_export()
        self.assertEqual(before, self.snapshot(self.out, metadata=True))
        self.assertEqual(second['written'], 0)
        self.assertEqual(second['deleted'], 0)
        self.assertEqual(second['unchanged'], first['written'])

    def test_shrink_and_add_match_clean_export_and_remove_imports_and_empty_dirs(self):
        self.run_export()
        for rel in ['maps/Map002.json.import', 'img/pictures/b.png.import',
                    'db/old/nested.json', 'audio/old/a.ogg.import', 'fonts/old/font.ttf']:
            path = self.out / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'stale')
        smaller = dict(self.cfg, maps=[1], pictures=['pictures/a'])
        summary = self.run_export(cfg=smaller)
        clean = self.root / 'clean-small'
        self.run_export(clean, smaller)
        self.assertEqual(self.products(self.out), self.products(clean))
        self.assertGreaterEqual(summary['deleted'], 7)
        for rel in ['maps/Map002.json', 'maps/Map002.json.import', 'img/pictures/b.png',
                    'img/pictures/b.png.import', 'db/old', 'audio/old', 'fonts/old']:
            self.assertFalse((self.out / rel).exists(), rel)
        self.run_export(cfg=self.cfg)
        clean = self.root / 'clean-added'
        self.run_export(clean)
        self.assertEqual(self.products(self.out), self.products(clean))

    def test_same_size_same_mtime_source_changes_are_detected_and_copy_metadata_preserved(self):
        self.run_export()
        source = self.app / 'img/pictures/a.png'
        before = source.stat()
        source.write_bytes(b'image-X')
        os.utime(source, ns=(before.st_atime_ns, before.st_mtime_ns))
        source.chmod(0o640)
        summary = self.run_export()
        target = self.out / 'img/pictures/a.png'
        self.assertEqual(target.read_bytes(), b'image-X')
        self.assertEqual(target.stat().st_mtime_ns, source.stat().st_mtime_ns)
        self.assertEqual(target.stat().st_mode & 0o777, 0o640)
        self.assertEqual(summary['written'], 2)  # 素材与其新摘要所在的 manifest。

    def test_manifest_serialization_stays_compatible_and_slice_is_in_outputs(self):
        self.run_export()
        raw = (self.out / 'manifest.json').read_bytes()
        manifest = json.loads(raw)
        self.assertEqual(raw, (json.dumps(manifest, ensure_ascii=False, indent=1) + '\n').encode())
        self.assertEqual(manifest['toolVersion'], 19)
        self.assertNotIn('manifest.json', manifest['outputs'])
        self.assertEqual(manifest['outputs']['slice.json'], exporter.sha((self.out / 'slice.json').read_bytes()))
        self.assertEqual((self.out / 'db/Items.json').read_bytes(), b'{"stage":"final","value":1}\n')

    def test_interruption_before_replace_keeps_complete_old_file_and_recovers(self):
        self.run_export()
        old = (self.out / 'db/Items.json').read_bytes()
        cfg = dict(self.cfg, value=2)
        real_replace = exporter.os.replace
        def interrupted(source, destination):
            if Path(destination).name == 'Items.json':
                self.assertEqual(Path(source).parent, Path(destination).parent)
                self.assertEqual(json.loads(Path(source).read_bytes())['value'], 2)
                self.assertEqual(Path(destination).read_bytes(), old)
                raise KeyboardInterrupt('fixture interruption')
            return real_replace(source, destination)
        with mock.patch.object(exporter.os, 'replace', side_effect=interrupted):
            with self.assertRaises(KeyboardInterrupt):
                self.run_export(cfg=cfg)
        self.assertEqual((self.out / 'db/Items.json').read_bytes(), old)
        self.assertFalse(list(self.out.rglob('.xiyou-export-*.tmp')))
        # 模拟 SIGKILL 在关闭临时文件前留下的残片：重跑后连根目录临时文件一起清除。
        for rel in ['db/.xiyou-export-dead.tmp', '.xiyou-export-dead.tmp']:
            (self.out / rel).write_bytes(b'partial')
        self.run_export(cfg=cfg)
        clean = self.root / 'clean-recovered'
        self.run_export(clean, cfg)
        self.assertEqual(self.products(self.out), self.products(clean))

    def test_failure_before_completion_does_not_prune_previous_files(self):
        self.run_export()
        stale = self.out / 'maps/previous.json'
        stale.write_bytes(b'old-complete')
        with mock.patch.object(FixtureExporter, 'copy_assets', side_effect=RuntimeError('fixture failure')):
            with self.assertRaises(RuntimeError):
                self.run_export(cfg=dict(self.cfg, maps=[1]))
        self.assertEqual(stale.read_bytes(), b'old-complete')
        self.assertTrue((self.out / 'maps/Map002.json').exists())

    def test_cleanup_cannot_follow_managed_directory_symlink_into_source(self):
        self.out.mkdir()
        (self.out / 'audio').symlink_to(self.app, target_is_directory=True)
        before = self.snapshot(self.app, metadata=True)
        with self.assertRaises(ValueError):
            self.run_export(cfg=dict(self.cfg, audio=[]))
        self.assertEqual(before, self.snapshot(self.app, metadata=True))

    def test_asset_parent_symlink_cannot_redirect_writes_into_oracle(self):
        oracle = self.out / 'oracle'
        oracle.mkdir(parents=True)
        (oracle / 'sentinel').write_bytes(b'keep')
        (self.out / 'img').mkdir()
        (self.out / 'img/pictures').symlink_to(oracle, target_is_directory=True)
        before = self.snapshot(oracle, metadata=True)
        with self.assertRaises(ValueError):
            self.run_export()
        self.assertEqual(before, self.snapshot(oracle, metadata=True))


if __name__ == '__main__':
    unittest.main()
