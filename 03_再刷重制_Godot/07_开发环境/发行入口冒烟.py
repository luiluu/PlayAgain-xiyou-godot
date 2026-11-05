#!/usr/bin/env python3
"""发行包入口冒烟（BI 正式入口，cc 2026-11-05）：导出「macOS 发行」包，确认打开就进西游标题、名字和图标对。

  python3 发行入口冒烟.py               导出 release 包 → 解开 → 只读查 Info.plist 与图标 → 隔离 HOME 里无头跑一次
  python3 发行入口冒烟.py --zip <包>     不导出，直接查现成的包
  python3 发行入口冒烟.py --keep         留下解开的 .app

查的：
  - 包名、CFBundleName／CFBundleDisplayName 是「再刷一把：天启篇」，包里有 icns 图标且和 content/app_icon/icon.icns 一致
  - 包内运行（--headless --quit-after，加 --report-entry 让游戏打印进了哪个场景）：只出现 ENTRY_SCENE=res://modes/xiyou/entry.tscn
发行包排除了 tests/、不认 --verify-export，所以这里只看入口，不跑包内测试（那是 导出冒烟.py 对「macOS 验收」调试包做的）。
每次运行用新建的临时 HOME，跑完删掉；不碰真实玩家存档，不签名、不公证。退出码：通过 0，失败 1，导出或解包出错 2。
"""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
GODOT = HERE / 'godot'
PRESET = 'macOS 发行'
APP_NAME = '再刷一把：天启篇'
TITLE = 'res://modes/xiyou/entry.tscn'


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--zip')
    ap.add_argument('--keep', action='store_true')
    a = ap.parse_args()
    work = Path(tempfile.mkdtemp(prefix='xiyou_release_entry_'))
    checks = []

    def check(name, ok, note=''):
        checks.append((name, ok))
        print(('PASS ' if ok else 'FAIL ') + name + (f'（{note}）' if note else ''))

    try:
        if a.zip:
            pkg = Path(a.zip).resolve()
        else:
            pkg = work / 'release.zip'
            p = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-release', PRESET, str(pkg)],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', timeout=900)
            (work / '导出.log').write_text(p.stdout, encoding='utf-8')
            if p.returncode != 0 or not pkg.is_file():
                print(p.stdout[-3000:])
                print('导出失败')
                return 2
        unz = work / 'app'
        unz.mkdir()
        if subprocess.run(['ditto', '-x', '-k', str(pkg), str(unz)]).returncode != 0:
            print('解包失败')
            return 2
        apps = sorted(unz.glob('*.app'))
        if not apps:
            print('包里没有 .app')
            return 2
        app = apps[0]
        check('app_bundle_name', app.stem == APP_NAME, app.name)
        info = plistlib.loads((app / 'Contents' / 'Info.plist').read_bytes())
        check('bundle_name', info.get('CFBundleName') == APP_NAME, str(info.get('CFBundleName')))
        icon = app / 'Contents' / 'Resources' / (str(info.get('CFBundleIconFile', 'icon')).removesuffix('.icns') + '.icns')
        want = PROJECT / 'content' / 'app_icon' / 'icon.icns'
        check('icon_from_app_icon', icon.is_file() and want.is_file() and icon.read_bytes() == want.read_bytes(), icon.name)
        exe_dir = app / 'Contents' / 'MacOS'
        exes = [p for p in exe_dir.iterdir() if p.is_file() and os.access(p, os.X_OK)]
        if not exes:
            print('包里没有可执行文件')
            return 2
        home = Path(tempfile.mkdtemp(prefix='xiyou_export_home_'))
        try:
            p = subprocess.run([str(exes[0]), '--headless', '--quit-after', '600', '--', '--report-entry'],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace',
                               timeout=300, env=dict(os.environ, HOME=str(home)), cwd=str(home))
        finally:
            shutil.rmtree(home, ignore_errors=True)
        (work / '运行.log').write_text(p.stdout, encoding='utf-8')
        entries = [l.split('=', 1)[1].strip() for l in p.stdout.splitlines() if l.startswith('ENTRY_SCENE=')]
        check('release_enters_title', entries == [TITLE], ','.join(entries) or '没有 ENTRY_SCENE')
        check('release_exit_clean', p.returncode == 0, f'退出码 {p.returncode}')
        ok = all(c[1] for c in checks)
        print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）；日志在 {work}')
        if a.keep:
            print(f'留下的包：{app}')
        return 0 if ok else 1
    finally:
        if not a.keep:
            for name in ['app', 'release.zip']:
                t = work / name
                if t.is_dir():
                    shutil.rmtree(t, ignore_errors=True)
                elif t.exists():
                    t.unlink()


if __name__ == '__main__':
    sys.exit(main())
