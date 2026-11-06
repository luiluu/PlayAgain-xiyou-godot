#!/usr/bin/env python3
"""发行包入口冒烟（BI 正式入口，cc 2026-11-05）：导出「macOS 发行」包，确认打开就进西游标题、名字和图标对。

  python3 发行入口冒烟.py               导出 release 包 → 解开 → 只读查 Info.plist 与图标 → 隔离 HOME 里无头跑一次
  python3 发行入口冒烟.py --zip <包>     不导出，直接查现成的包
  python3 发行入口冒烟.py --keep         留下解开的 .app
  python3 发行入口冒烟.py --platform windows   导出「Windows 发行」：查 exe 资源里的名字和 256 图标，
                                         再把 macOS 发行模板改成同名、放在 .pck 旁边跑一次（发行模板不认 --main-pack）
  python3 发行入口冒烟.py --keys         另外按键冒烟（platform-crash1）：每组新开一个进程、新临时 HOME，
                                         标题按空格／J／回车开新游戏，再按一串确认、取消键，看进程活着、没有新崩溃报告
  python3 发行入口冒烟.py --keys-only --zip <包>   只做按键冒烟（不查名字图标），给验证旧包／修后包用
  python3 发行入口冒烟.py --arch x86_64 [--keys]  macOS 包在 Rosetta 下跑 x86_64 切片（arch -x86_64；包是 universal 才有这个切片）
  python3 发行入口冒烟.py --keys-only --app <.app>  同上，直接跑一个已解开的 .app（只执行、不改它；HOME 照旧是临时的）

查的：
  - 包名、CFBundleName／CFBundleDisplayName 是「再刷一把：天启篇」，包里有 icns 图标且和 content/app_icon/icon.icns 一致
  - 包内运行（--headless --quit-after，加 --report-entry 让游戏打印进了哪个场景）：只出现 ENTRY_SCENE=res://modes/xiyou/entry.tscn
发行包排除了 tests/、不认 --verify-export，所以这里只看入口，不跑包内测试（那是 导出冒烟.py 对「macOS 验收」调试包做的）。
按键冒烟（--keys）：发行模板的 GDScript 对 null 调方法不查空、直接 SIGSEGV（11-06 标题按空格/J 闪退），调试版只报错，
所以只有发行包里真按键才看得到。游戏带 `-- --smoke-keys=<序列>` 时自己注入按键（core/key_smoke.gd，经 Input.parse_input_event），
按完打印 SMOKE_DONE 并退出 0；这里查：退出码 0、有 SMOKE_DONE、新游戏那几组最后在地图场景、~/Library/Logs/DiagnosticReports 没多出本包的崩溃报告。
发行构建直达西游标题、没有「返回版本选择」（BI），那一项只有调试构建有（tests/xiyou_input_handled 覆盖）。
每次运行用新建的临时 HOME，跑完删掉；不碰真实玩家存档，不签名、不公证。退出码：通过 0，失败 1，导出或解包出错 2。
"""
import argparse
import os
from pathlib import Path
import plistlib
import re
import struct
import shutil
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
GODOT = HERE / 'godot'
PRESET = 'macOS 发行'
APP_NAME = '再刷一把：天启篇'
TITLE = 'res://modes/xiyou/entry.tscn'
MAP = 'res://modes/xiyou/map/map_scene.tscn'
CRASH_WAIT = 40
RUN_PREFIX: list = []  # --arch x86_64 时是 ['arch', '-x86_64']
CRASH_DIR = Path.home() / 'Library' / 'Logs' / 'DiagnosticReports'
# (名字, 按键序列, 最后应在的场景或 None)。每组新开进程：新游戏后就离开标题了。
KEY_RUNS = [
    ('title_space_new_game', 'space', MAP),
    ('title_j_new_game', 'j', MAP),
    ('title_enter_new_game', 'accept', MAP),
    ('title_cancel_then_map_keys', 'cancel,x,k,down,up,z,wait:90,accept,space,j,accept,cancel,cancel,x,k,cancel,accept', None),
]


def windows(work: Path, check, keys=False) -> int:
    exe = work / 'win' / '再刷一把_天启篇.exe'
    exe.parent.mkdir()
    p = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-release', 'Windows 发行', str(exe)],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', timeout=900)
    (work / '导出.log').write_text(p.stdout, encoding='utf-8')
    pck = exe.with_suffix('.pck')
    if p.returncode != 0 or not exe.is_file() or not pck.is_file():
        print(p.stdout[-3000:])
        print('导出失败')
        return 2
    blob = exe.read_bytes()
    check('exe_product_name', APP_NAME.encode('utf-16-le') in blob)
    ico = (PROJECT / 'content' / 'app_icon' / 'icon.ico').read_bytes()
    n = struct.unpack('<H', ico[4:6])[0]
    size, off = struct.unpack('<II', ico[6 + 16 * (n - 1) + 8:6 + 16 * (n - 1) + 16])
    check('exe_icon_256', ico[off:off + size] in blob)
    cfg = (PROJECT / 'export_presets.cfg').read_text(encoding='utf-8')
    tpl = Path(re.search(r'custom_template/release="([^"]*macos[^"]*)"', cfg).group(1))
    tdir = work / 'tpl'
    if subprocess.run(['ditto', '-x', '-k', str(tpl), str(tdir)]).returncode != 0:
        print('解不开 macOS 模板')
        return 2
    rel = next(tdir.rglob('godot_macos_release*'))
    runner = pck.with_suffix('')
    shutil.copy(rel, runner)
    runner.chmod(0o755)
    run_entry(work, runner, check)
    return run_keys(work, runner, check) if keys else 0


def run_entry(work: Path, exe: Path, check) -> int:
    home = Path(tempfile.mkdtemp(prefix='xiyou_export_home_'))
    try:
        p = subprocess.run([*RUN_PREFIX, str(exe), '--headless', '--quit-after', '600', '--', '--report-entry'],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace',
                           timeout=300, env=dict(os.environ, HOME=str(home)), cwd=str(home))
    finally:
        shutil.rmtree(home, ignore_errors=True)
    (work / '运行.log').write_text(p.stdout, encoding='utf-8')
    entries = [l.split('=', 1)[1].strip() for l in p.stdout.splitlines() if l.startswith('ENTRY_SCENE=')]
    check('release_enters_title', entries == [TITLE], ','.join(entries) or '没有 ENTRY_SCENE')
    check('release_exit_clean', p.returncode == 0, f'退出码 {p.returncode}')
    return 0


def crash_reports(stem: str) -> set:
    """本包的崩溃报告（.ips 名字以可执行文件名开头）；目录不存在（非 Mac）返回空集合。"""
    if not CRASH_DIR.is_dir():
        return set()
    return {p.name for p in CRASH_DIR.iterdir() if p.name.startswith(stem) and p.suffix in ('.ips', '.crash')}


def run_keys(work: Path, exe: Path, check, runs=KEY_RUNS) -> int:
    """发行包里按键冒烟：每组一个新进程、新临时 HOME；看活着、按完、场景对、没有新崩溃报告。"""
    before = crash_reports(exe.name)
    crashed = False
    for name, seq, want in runs:
        home = Path(tempfile.mkdtemp(prefix='xiyou_keys_home_'))
        try:
            p = subprocess.run([*RUN_PREFIX, str(exe), '--headless', '--quit-after', '6000', '--', f'--smoke-keys={seq}'],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace',
                               timeout=300, env=dict(os.environ, HOME=str(home)), cwd=str(home))
            out, rc = p.stdout, p.returncode
        except subprocess.TimeoutExpired as e:
            out, rc = (e.stdout or b'').decode('utf-8', 'replace') if isinstance(e.stdout, bytes) else (e.stdout or ''), 124
        finally:
            shutil.rmtree(home, ignore_errors=True)
        (work / f'按键_{name}.log').write_text(out, encoding='utf-8')
        done = [l.split('scene=', 1)[1].strip() for l in out.splitlines() if l.startswith('SMOKE_DONE scene=')]
        steps = sum(1 for l in out.splitlines() if l.startswith('SMOKE_KEY='))
        note = f'退出码 {rc}，按完 {steps}/{len(seq.split(","))} 步' + (f'，最后在 {done[0]}' if done else '，没有 SMOKE_DONE')
        if rc < 0 or rc > 128:
            crashed = True
            note += '（被信号结束，多半是闪退）'
        ok = rc == 0 and bool(done) and (want is None or done[0] == want)
        check('keys_' + name, ok, note)
    # 崩溃报告由系统 ReportCrash 事后写，闪退后要过几秒到十几秒才出现：有进程被信号结束时最多等 CRASH_WAIT 秒
    deadline = time.time() + (CRASH_WAIT if crashed else 3)
    new = []
    while time.time() < deadline:
        new = sorted(crash_reports(exe.name) - before)
        if new:
            break
        time.sleep(1)
    check('keys_no_new_crash_report', not new, '新增 ' + '、'.join(new) if new else f'{CRASH_DIR} 没有新增')
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--zip')
    ap.add_argument('--arch', choices=['x86_64', 'arm64'], help='用 arch -<架构> 跑 macOS 包的某个切片（x86_64 走 Rosetta）')
    ap.add_argument('--app', help='已解开的 .app（只配 --keys-only）')
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--platform', choices=['macos', 'windows'], default='macos')
    ap.add_argument('--keys', action='store_true', help='另外跑按键冒烟')
    ap.add_argument('--keys-only', action='store_true', help='只跑按键冒烟（配合 --zip 验证现成的包）')
    a = ap.parse_args()
    a.keys = a.keys or a.keys_only
    if a.arch:
        if a.platform != 'macos':
            print('--arch 只配 macOS 包')
            return 2
        RUN_PREFIX[:] = ['arch', '-' + a.arch]
    work = Path(tempfile.mkdtemp(prefix='xiyou_release_entry_'))
    checks = []

    def check(name, ok, note=''):
        checks.append((name, ok))
        print(('PASS ' if ok else 'FAIL ') + name + (f'（{note}）' if note else ''))

    try:
        if a.platform == 'windows':
            code = windows(work, check, a.keys)
            if code:
                return code
            ok = all(c[1] for c in checks)
            print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）；日志在 {work}')
            return 0 if ok else 1
        if a.app:
            if not a.keys_only:
                print('--app 只配 --keys-only')
                return 2
            exes = [p for p in (Path(a.app) / 'Contents' / 'MacOS').iterdir() if p.is_file() and os.access(p, os.X_OK)]
            if not exes:
                print('包里没有可执行文件')
                return 2
            run_keys(work, exes[0], check)
            ok = all(c[1] for c in checks)
            print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）；日志在 {work}')
            return 0 if ok else 1
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
        exe_dir = app / 'Contents' / 'MacOS'
        exes = [p for p in exe_dir.iterdir() if p.is_file() and os.access(p, os.X_OK)]
        if not exes:
            print('包里没有可执行文件')
            return 2
        if a.keys_only:
            run_keys(work, exes[0], check)
            ok = all(c[1] for c in checks)
            print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）；日志在 {work}')
            return 0 if ok else 1
        check('app_bundle_name', app.stem == APP_NAME, app.name)
        info = plistlib.loads((app / 'Contents' / 'Info.plist').read_bytes())
        check('bundle_name', info.get('CFBundleName') == APP_NAME, str(info.get('CFBundleName')))
        icon = app / 'Contents' / 'Resources' / (str(info.get('CFBundleIconFile', 'icon')).removesuffix('.icns') + '.icns')
        want = PROJECT / 'content' / 'app_icon' / 'icon.icns'
        check('icon_from_app_icon', icon.is_file() and want.is_file() and icon.read_bytes() == want.read_bytes(), icon.name)
        run_entry(work, exes[0], check)
        if a.keys:
            run_keys(work, exes[0], check)
        ok = all(c[1] for c in checks)
        print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）；日志在 {work}')
        if a.keep:
            print(f'留下的包：{app}')
        return 0 if ok else 1
    finally:
        if not a.keep:
            for name in ['app', 'release.zip', 'win', 'tpl']:
                t = work / name
                if t.is_dir():
                    shutil.rmtree(t, ignore_errors=True)
                elif t.exists():
                    t.unlink()


if __name__ == '__main__':
    sys.exit(main())
