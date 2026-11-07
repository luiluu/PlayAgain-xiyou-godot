#!/usr/bin/env python3
"""发行出包.py 离线部分（cc 平台 EA 2026-11-06）：发行说明摘取与去内部信息、旧目录压 zip 不删、体积表、发行目录排序、dry-run。
真导出加冒烟约 15 分钟，不在这里跑：手动 `python3 发行出包.py`。"""
import importlib.util
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('发行出包', HERE / '发行出包.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)

LOG = """# 变更记录

## 2026-11-06 【cc·平台·未经审查】安卓切后台自动存档：标题页可「继续」，不碰手动存档位（O-213，dev.383）

- 正文 `core/xsave.gd`

## 2026-11-06 【cc·哪吒·未经审查】云端选测提速：检查.sh 少跑一轮（dev.384）

## 2026-11-07 【cc·悟空·未经审查】新角色哪吒：Map012 EV3 招募，掉率 5%（dev.385）

## 2026-11-07 【cc·八戒·未经审查】这条标题写得很内部（dev.386）

- 玩家可见：商店买东西会提示背包满了

## 2026-11-05 【cc·平台·未经审查】更早的改动（dev.380）

## 2026-11-07 【cc·唐僧】没有编号的条目
"""


class NotesTests(unittest.TestCase):
    def test_range_and_filters(self):
        lines = M.release_notes(LOG, 382, 386)
        self.assertEqual(lines, ['安卓切后台自动存档：标题页可「继续」，不碰手动存档位', '新角色哪吒：招募', '商店买东西会提示背包满了'])

    def test_no_internal_leftovers(self):
        text = M.notes_text(386, 382, M.release_notes(LOG, 382, 386))
        for bad in ('O-213', 'dev.', 'Map012', 'EV3', '5%', '掉率', '.gd', '云端'):
            self.assertNotIn(bad, text)
        self.assertIn('0.386', text)
        self.assertIn('上一个发行包是 0.382', text)

    def test_empty(self):
        self.assertIn('没有玩家能看到的改动', M.notes_text(384, 383, M.release_notes(LOG, 383, 384)))

    def test_real_changelog_parses(self):
        text = M.CHANGELOG.read_text(encoding='utf-8')
        self.assertGreater(len(M.entries(text)), 100)
        for line in M.release_notes(text, 360, 400):
            self.assertNotRegex(line, r'O-\d+|dev\.\d+|`|\.gd\b|\.py\b')


class DirsTests(unittest.TestCase):
    def make(self, parent: Path, n: int):
        d = parent / f'dev{n}_三平台发行'
        (d / 'windows').mkdir(parents=True)
        (d / M.MAC_ZIP).write_bytes(b'm' * 10)
        (d / 'windows' / M.WIN_FILES[0]).write_bytes(b'e' * 3)
        (d / 'windows' / M.WIN_FILES[1]).write_bytes(b'p' * 4)
        (d / M.APK).write_bytes(b'a' * 5)
        return d

    def test_tidy_keeps_two_zips_rest_without_deleting(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            for n in (99, 380, 383, 384):
                self.make(p, n)
            (p / '再刷一把：天启篇_dev380备份.zip').write_bytes(b'x')  # 不是发行目录，不碰
            done = M.tidy_old(p)
            self.assertEqual([d.name for d, _, _ in done], ['dev99_三平台发行', 'dev380_三平台发行'])
            for d, z, new in done:
                self.assertTrue(new and z.is_file() and d.is_dir())
                with zipfile.ZipFile(z) as zf:
                    self.assertIn(f'{d.name}/windows/{M.WIN_FILES[1]}', zf.namelist())
            self.assertFalse((p / 'dev383_三平台发行.zip').exists())
            # 再跑一次：已有 zip 就跳过
            self.assertEqual([new for _, _, new in M.tidy_old(p)], [False, False])

    def test_sizes_and_table(self):
        with tempfile.TemporaryDirectory() as t:
            d = self.make(Path(t), 384)
            s = M.sizes(d)
            self.assertEqual(s, {'macOS': 10, 'Windows': 7, '安卓': 5})
            table = M.size_table(384, {'macOS': 351_700_000}, 383, {'macOS': 501_500_000})
            self.assertIn('| macOS | 351.7 MB | 501.5 MB | −149.8 MB |', table)

    def test_release_dirs_sorted_numeric(self):
        with tempfile.TemporaryDirectory() as t:
            for n in (1000, 99, 383):
                self.make(Path(t), n)
            self.assertEqual([n for n, _ in M.release_dirs(Path(t))], [99, 383, 1000])

    def test_dry_run(self):
        with tempfile.TemporaryDirectory() as t:
            for n in (1, 2, 3):
                self.make(Path(t), n)
            out = subprocess.run([sys.executable, str(HERE / '发行出包.py'), '--dry-run', '--out', t], capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stderr)
            self.assertIn('会压缩旧目录：dev1_三平台发行', out.stdout)
            self.assertFalse((Path(t) / 'dev1_三平台发行.zip').exists())


if __name__ == '__main__':
    unittest.main()
