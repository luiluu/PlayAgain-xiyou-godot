#!/usr/bin/env python3
"""找出（并可删除）04_验证/本地结果/ 下的 Godot 工程副本，磁盘告急时用（哪吒_10，Kyo 2026-10-30）。

背景：核查、选测有人在 本地结果/<运行名>/ 下整份拷 01_Godot工程（含 generated 与 .godot 导入缓存），每份约 1.4～1.8 GB；
沙僧工作树里 review-backlog-* 攒了 27 份。仓库自己的工具不拷（并行测试.py 直接在工程里跑，同步备份已改 APFS 克隆），
要隔离运行请用 `cp -cR`（APFS 克隆，同卷不另占空间）或直接在工作树里跑，跑完删掉。

判定：本地结果下含 project.godot 的目录（深度 ≤ 4）就是工程副本。默认只列清单；--delete 才删，且只删这些目录本身，
日志、结果 JSON、其他证据都不动。--older-than-hours N 只处理最后修改超过 N 小时的；小于 --min-mb（默认 50）的不算（测试小样本）。
用法：清理本地缓存.py [--root 路径 ...] [--delete] [--older-than-hours N]
没给 --root 时扫主工作区和 git worktree list 里的全部工作树。
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
RESULTS = Path('03_再刷重制_Godot/04_验证/本地结果')
MAX_DEPTH = 4


def worktrees(here: Path) -> list:
    out = subprocess.run(['git', '-C', str(here), 'worktree', 'list', '--porcelain'], capture_output=True, text=True).stdout
    return [Path(line.split(' ', 1)[1]) for line in out.splitlines() if line.startswith('worktree ')]


def size_kb(path: Path) -> int:
    total = 0
    for dirpath, _, files in os.walk(path):
        for f in files:
            try:
                total += os.lstat(os.path.join(dirpath, f)).st_blocks // 2
            except OSError:
                pass
    return total


def find_copies(results: Path) -> list:
    """本地结果下含 project.godot 的目录（不进入已找到的副本内部）。"""
    found = []
    if not results.is_dir():
        return found
    for dirpath, dirs, files in os.walk(results):
        depth = len(Path(dirpath).relative_to(results).parts)
        if 'project.godot' in files:
            found.append(Path(dirpath))
            dirs[:] = []
        elif depth >= MAX_DEPTH:
            dirs[:] = []
    return found


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', type=Path, action='append', default=[], help='工作树根目录（可多次）；省略则扫全部工作树')
    ap.add_argument('--delete', action='store_true', help='真删；省略只列清单')
    ap.add_argument('--older-than-hours', type=float, default=0)
    ap.add_argument('--min-mb', type=float, default=50)
    a = ap.parse_args(argv)
    roots = a.root or worktrees(HERE)
    now, total, rows = time.time(), 0, []
    for root in roots:
        for d in find_copies(root / RESULTS):
            age = (now - d.stat().st_mtime) / 3600
            if age < a.older_than_hours:
                continue
            kb = size_kb(d)
            if kb < a.min_mb * 1024:
                continue
            total += kb
            rows.append((root, d, kb, age))
    for root, d, kb, age in rows:
        print('%7.2f GB  %6.1f 小时前  %s' % (kb / 1048576, age, d))
        if a.delete:
            shutil.rmtree(d)
    print('%s %d 份工程副本，合计约 %.2f GB' % ('已删除' if a.delete else '可清理', len(rows), total / 1048576))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
