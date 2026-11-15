#!/usr/bin/env python3
"""新界面开关关掉时与 main 逐像素一致（ui-skin-p0 验收；核查也可重跑）。

做法：
 1. 在临时目录 git clone --shared 本库、只检出 Godot 工程（sparse），切到 --base（默认 main）；
 2. generated 软链到本工作树的（转换产物不入库，两边一样），.godot 导入缓存用 cp -c 克隆（APFS 写时复制，不占空间、免重导）；
 3. 把本分支的 tests/xiyou_ui_skin_offshot.gd/.tscn 拷进去（脚本不引用新类，main 上能跑）；
 4. main 克隆和本工作树各开窗口跑一次截图（主菜单、状态、物品、装备、设置 × 西游存档默认／天启篇存档关新皮肤；战斗指令窗、战技列表、选目标 × 西游存档，2A 加）；
 5. 用同一个脚本的 --compare 逐像素比，全部 SAME 退出 0。

  python3 皮肤关闭对照.py [--base main] [--out 目录] [--keep]
要窗口（会弹出 Godot 窗口几十秒）；只读本库，临时克隆用完删（--keep 留着）。
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PROJ_REL = '03_再刷重制_Godot/01_Godot工程'
PROJECT = ROOT / PROJ_REL
GODOT = HERE / 'godot'
TEST = 'tests/xiyou_ui_skin_offshot'


def run(cmd, **kw):
    print('$', ' '.join(str(c) for c in cmd), flush=True)
    return subprocess.run(cmd, check=True, **kw)


def shoot(project: Path, out: Path):
    out.mkdir(parents=True, exist_ok=True)
    r = subprocess.run([str(GODOT), '--path', str(project), f'res://{TEST}.tscn', '--', f'--out={out}'],
                       capture_output=True, text=True, timeout=600)
    tail = [x for x in (r.stdout + r.stderr).splitlines() if 'TEST_RESULT' in x or 'SCRIPT ERROR' in x or x.startswith('SKIP') or 'ENABLED' in x]
    print('\n'.join(tail))
    return sorted(p.name for p in out.glob('*.png'))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', default='main')
    ap.add_argument('--out', default=str(ROOT / '03_再刷重制_Godot/04_验证/本地结果/ui_skin_p0/关闭对照'))
    ap.add_argument('--keep', action='store_true')
    a = ap.parse_args()
    out = Path(a.out)
    if out.exists():
        shutil.rmtree(out)
    work = Path(tempfile.mkdtemp(prefix='skin_off_'))
    clone = work / 'base'
    try:
        run(['git', 'clone', '--shared', '--no-checkout', '--quiet', str(ROOT), str(clone)])
        run(['git', '-C', str(clone), 'sparse-checkout', 'set', PROJ_REL])
        base = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', a.base], capture_output=True, text=True, check=True).stdout.strip()
        run(['git', '-C', str(clone), 'checkout', '--quiet', base])
        cp = clone / PROJ_REL
        (cp / 'modes/xiyou/generated').symlink_to(PROJECT / 'modes/xiyou/generated')
        run(['cp', '-cR', str(PROJECT / '.godot'), str(cp / '.godot')])
        for ext in ('.gd', '.tscn', '.gd.uid'):
            src = PROJECT / (TEST + ext)
            if src.exists():
                shutil.copy2(src, cp / (TEST + ext))
        print(f'== 基线 {a.base}（{base[:9]}）')
        got_a = shoot(cp, out / 'base')
        print('== 本分支')
        got_b = shoot(PROJECT, out / 'branch')
        if not got_a or got_a != got_b:
            print(f'✗ 截图对不上：基线 {got_a}，本分支 {got_b}')
            return 1
        r = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), f'res://{TEST}.tscn', '--',
                            f'--compare={out / "base"},{out / "branch"}'], capture_output=True, text=True, timeout=300)
        lines = [x for x in r.stdout.splitlines() if x.startswith(('SAME', 'DIFF', 'TEST_RESULT'))]
        print('\n'.join(lines))
        print('✓ 开关关掉与基线逐像素一致' if r.returncode == 0 else '✗ 有不同')
        return r.returncode
    finally:
        if a.keep:
            print('留着临时克隆：', work)
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
