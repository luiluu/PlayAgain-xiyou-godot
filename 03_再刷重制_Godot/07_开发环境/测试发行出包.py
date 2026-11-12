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

    def test_none_and_internal_dropped(self):
        log = """## 2026-11-10 【cc·甲】不重要（dev.390）

- 玩家可见：无（只加测试）

## 2026-11-10 【cc·乙】也不重要（dev.391）

- 玩家可见：无明显变化（极少数情况先后与原版一致）

## 2026-11-10 【cc·丙】SlotWeightTests 偶发失败修稳（dev.392）

## 2026-11-10 【cc·丁】一护副本 6 个入口进切片（dev.393）

## 2026-11-10 【cc·戊】地图事件（dev.394）

- 玩家可见：Map152、Map032 的并行事件会动了；鬼火会动了
"""
        self.assertEqual(M.release_notes(log, 389, 394), ['部分地图的并行事件会动了；鬼火会动了'])

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

    def test_tidy_keeps_only_current(self):
        # 平台 EC（Kyo 11-06「直接删」）：只留本次这一版；旧目录和以前压的 zip 都删；号更大的、备份不碰
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            for n in (99, 380, 383, 384, 390):
                self.make(p, n)
            (p / 'dev380_三平台发行.zip').write_bytes(b'z')
            (p / 'dev377_三平台发行.zip').write_bytes(b'z')  # 目录早就不在、只剩 zip
            (p / '再刷一把：天启篇_dev380备份.zip').write_bytes(b'x')
            (p / '再刷一把：天启篇_dev377备份.app').mkdir()
            dry = M.tidy_old(p, 384, dry=True)
            self.assertTrue((p / 'dev99_三平台发行').is_dir())  # dry 不动
            gone = M.tidy_old(p, 384)
            self.assertEqual(sorted(x.name for x in gone), sorted(x.name for x in dry))
            self.assertEqual(sorted(x.name for x in p.iterdir()),
                             sorted(['dev384_三平台发行', 'dev390_三平台发行', '再刷一把：天启篇_dev380备份.zip', '再刷一把：天启篇_dev377备份.app']))
            self.assertEqual(M.tidy_old(p, 384), [])

    def test_notes_audit(self):
        log = ('## 2026-11-06 【cc·平台·未经审查】商店页存档键（dev.385）\n\n- 玩家可见：商店页不再显示存档键\n\n'
               '## 2026-11-06 【cc·悟空·未经审查】流萤可以招募了（dev.386）\n\n- 做了什么\n\n'
               '## 2026-11-06 【cc·哪吒·未经审查】探针提速（dev.386）\n\n- 工具\n')
        rows = M.notes_audit(log, 384, 386)
        self.assertEqual([(n, line) for n, _, line in rows], [(386, '流萤可以招募了')])
        self.assertEqual(M.release_notes(log, 384, 386), ['商店页不再显示存档键', '流萤可以招募了'])

    def test_old_kept_when_smoke_fails(self):
        src = (HERE / '发行出包.py').read_text(encoding='utf-8')
        tail = src[src.index('ok = all(r[1] for r in rows)'):]
        self.assertLess(tail.index('elif not ok'), tail.index('tidy_old(parent, dev)'))
        self.assertLess(tail.index('elif not rows'), tail.index('tidy_old(parent, dev)'))

    def test_sizes_and_table(self):
        with tempfile.TemporaryDirectory() as t:
            d = self.make(Path(t), 384)
            s = M.sizes(d)
            self.assertEqual(s, {'macOS': 10, 'Windows': 7, '安卓': 5})
            table = M.size_table(384, {'macOS': 351_700_000}, 383, {'macOS': 501_500_000})
            self.assertIn('| macOS | 351.7 MB | 501.5 MB | −149.8 MB |', table)

    def test_win_zip_and_manifests(self):
        # Kyo 11-12：Windows 发一个 zip（exe＋pck 两个文件，文件名标 UTF-8），写进校验和与体积表
        with tempfile.TemporaryDirectory() as t:
            d = self.make(Path(t), 384)
            z = M.win_zip(d)
            self.assertEqual(z, d / '再刷一把_天启篇_windows.zip')
            with zipfile.ZipFile(z) as zf:
                self.assertEqual(sorted(zf.namelist()), sorted(M.WIN_FILES))
                for info in zf.infolist():
                    self.assertTrue(info.flag_bits & 0x800, info.filename)
                self.assertEqual(zf.read(M.WIN_FILES[0]), b'e' * 3)
                self.assertEqual(zf.read(M.WIN_FILES[1]), b'p' * 4)
            raw = z.read_bytes()   # 本地文件头里的通用标志也带 UTF-8 位（不只中央目录）
            self.assertTrue(int.from_bytes(raw[6:8], 'little') & 0x800)
            names = [str(f.relative_to(d)) for f in M.package_files(d)]
            self.assertIn('再刷一把_天启篇_windows.zip', names)
            self.assertEqual(M.sizes(d)['Windows zip'], z.stat().st_size)
            self.assertIn('| Windows zip |', M.size_table(384, M.sizes(d), None, {}))

    def test_export_makes_win_zip_and_notes_say_unzip(self):
        src = (HERE / '发行出包.py').read_text(encoding='utf-8')
        body = src[src.index('def export_all('):src.index('def ', src.index('def export_all(') + 10)]
        self.assertIn('win_zip(out)', body)
        self.assertLess(body.index("'Windows 导出失败'"), body.index('win_zip(out)'))
        notes = M.notes_text(386, 382, [])
        self.assertIn('解开 再刷一把_天启篇_windows.zip', notes)
        self.assertNotIn('Windows：再刷一把_天启篇.exe 和', notes)

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
            self.assertIn('冒烟全过后会删旧发行：dev1_三平台发行', out.stdout)
            self.assertTrue(all((Path(t) / f'dev{n}_三平台发行').is_dir() for n in (1, 2, 3)))


if __name__ == '__main__':
    unittest.main()
