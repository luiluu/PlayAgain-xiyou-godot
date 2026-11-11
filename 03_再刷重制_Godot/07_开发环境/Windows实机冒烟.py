#!/usr/bin/env python3
"""Windows 实机冒烟（cc 平台 FB 2026-11-07）：在真 Windows 上跑「Windows 发行」导出的 exe，补上以前只能用替身模板验的那一截。

  python Windows实机冒烟.py --dir <目录> [--out <目录>] [--no-keys] [--try-window]

<目录> 里要有 再刷一把_天启篇.exe 和同名 .pck（发行出包.py 的 Windows 目录、或云端 export-smoke 工作流在 Linux 上导出的）。
云端用法：.github/workflows/export-smoke.yml 的 windows-run 任务（windows-latest），包从同一次运行的 Linux 任务经 Actions 缓存
传过来（缓存不对外，跑完删掉），不做成附件——仓库公开，附件谁都能下。

查的（每次运行都用新建的临时 APPDATA／LOCALAPPDATA，不碰机器上的真实存档目录）：
  - 入口：exe --headless -- --report-entry 只打印 ENTRY_SCENE=res://modes/xiyou/entry.tscn、退出码 0
  - 存档目录（O-200）：写到 <APPDATA>\\KYO\\再刷重制，没有出现调试用的 KYO\\再刷重制_开发
  - 按键（--keys，默认开）：照 发行入口冒烟.py 的 KEY_RUNS，标题按空格／J／回车开新游戏、再按一串确认取消；每组新进程，
    退出码 0、有 SMOKE_DONE、开新游戏那几组最后在地图。Windows 上闪退的退出码是 0xC0000005 一类大数，直接算失败
  - --try-window：另外不加 --headless、用 ANGLE（opengl3_angle，云端机器没显卡走软件渲染）开窗口进一次标题，只提示不算失败
跟替身的区别：这里跑的是 Windows 发行模板本身（Windows 上的 GDScript 发行版、文件系统路径、%APPDATA%），
看不到的仍是窗口／全屏／高 DPI／输入法／手柄（无头），那些在 00_项目管理/Windows发行包验收清单.md。
只用标准库，Mac 上也能跑它的单元测试（测试Windows实机冒烟.py 用假 exe）。退出码：通过 0，失败 1，包不全 2。
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

EXE = '再刷一把_天启篇.exe'
TITLE = 'res://modes/xiyou/entry.tscn'
MAP = 'res://modes/xiyou/map/map_scene.tscn'
SAVE_DIR = ('KYO', '再刷重制')
DEV_DIR = ('KYO', '再刷重制_开发')
# 同 发行入口冒烟.py 的 KEY_RUNS（那边改了这里跟着改；测试Windows实机冒烟.py 核对两边一致）
# 天启篇开局（11-10 起）：新的游戏 → 选存档位（1 号）→ 选难度（第一档）→ 随机阵容（焦点在「重新随机」，down 到「就是他们了」）→ 地图；
# 只按一下停在选存档位，三组新游戏会挂（平台 release450 2026-11-11）。
KEY_RUNS = [
    ('title_space_new_game', 'space,space,space,down,space', MAP),
    ('title_j_new_game', 'j,j,j,down,j', MAP),
    ('title_enter_new_game', 'accept,accept,accept,down,accept', MAP),
    ('title_cancel_then_map_keys', 'cancel,x,k,down,up,z,wait:90,accept,space,j,accept,cancel,cancel,x,k,cancel,accept', None),
]


class Report:
    def __init__(self):
        self.rows = []

    def check(self, name, ok, note=''):
        self.rows.append((name, bool(ok), note))
        print(('PASS ' if ok else 'FAIL ') + name + (f'（{note}）' if note else ''), flush=True)

    def info(self, name, note):
        self.rows.append((name, None, note))
        print(f'INFO {name}（{note}）', flush=True)

    @property
    def failed(self):
        return [r for r in self.rows if r[1] is False]


def run(cmd, appdata: Path, timeout: int):
    """跑一次，返回 (输出, 退出码, 秒数)。APPDATA／LOCALAPPDATA 指到临时目录，Godot 的 user:// 就落在那里。"""
    env = dict(os.environ, APPDATA=str(appdata / 'Roaming'), LOCALAPPDATA=str(appdata / 'Local'))
    (appdata / 'Roaming').mkdir(parents=True, exist_ok=True)
    (appdata / 'Local').mkdir(parents=True, exist_ok=True)
    t0 = time.monotonic()
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8',
                           errors='replace', env=env, cwd=str(appdata), timeout=timeout)
        out, rc = p.stdout, p.returncode
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode('utf-8', 'replace') if isinstance(e.stdout, bytes) else (e.stdout or '')
        rc = 124
    # 发行 exe 是图形界面程序：标准输出接管道一般照样能收到；收不到时退到游戏自己写的 user://logs/godot.log
    if 'ENTRY_SCENE=' not in out and 'SMOKE_' not in out:
        log = (appdata / 'Roaming').joinpath(*SAVE_DIR, 'logs', 'godot.log')
        if log.is_file():
            out += '\n[godot.log]\n' + log.read_text(encoding='utf-8', errors='replace')
    return out, rc, time.monotonic() - t0


def rc_note(rc: int) -> str:
    if rc in (0, 124):
        return f'退出码 {rc}' + ('（超时）' if rc == 124 else '')
    u = rc & 0xFFFFFFFF
    return f'退出码 {rc}（0x{u:08X}{"，多半是闪退" if u >= 0xC0000000 else ""}）'


def save_dirs(appdata: Path):
    roaming = appdata / 'Roaming'
    return roaming.joinpath(*SAVE_DIR).is_dir(), roaming.joinpath(*DEV_DIR).is_dir()


def entry(exe: Path, work: Path, rep: Report, tmp_root: Path) -> dict:
    appdata = Path(tempfile.mkdtemp(prefix='appdata_', dir=tmp_root))
    out, rc, secs = run([str(exe), '--headless', '--quit-after', '600', '--', '--report-entry'], appdata, 300)
    (work / '运行.log').write_text(out, encoding='utf-8')
    entries = [l.split('=', 1)[1].strip() for l in out.splitlines() if l.startswith('ENTRY_SCENE=')]
    rep.check('win_enters_title', entries == [TITLE], ','.join(entries) or '没有 ENTRY_SCENE')
    rep.check('win_exit_clean', rc == 0, rc_note(rc))
    rep.info('win_startup_time', f'起进程到退出 {secs:.1f} 秒（含 --quit-after 600 帧）')
    has, dev = save_dirs(appdata)
    return {'save': has, 'dev': dev, 'listing': listing(appdata / 'Roaming')}


def listing(root: Path, limit=40):
    return sorted(str(p.relative_to(root)).replace('\\', '/') for p in root.rglob('*'))[:limit]


def keys(exe: Path, work: Path, rep: Report, tmp_root: Path, runs=KEY_RUNS) -> list:
    seen = []
    for name, seq, want in runs:
        appdata = Path(tempfile.mkdtemp(prefix='appdata_', dir=tmp_root))
        out, rc, _ = run([str(exe), '--headless', '--quit-after', '6000', '--', f'--smoke-keys={seq}'], appdata, 300)
        (work / f'按键_{name}.log').write_text(out, encoding='utf-8')
        done = [l.split('scene=', 1)[1].strip() for l in out.splitlines() if l.startswith('SMOKE_DONE scene=')]
        steps = sum(1 for l in out.splitlines() if l.startswith('SMOKE_KEY='))
        note = f'{rc_note(rc)}，按完 {steps}/{len(seq.split(","))} 步' + (f'，最后在 {done[0]}' if done else '，没有 SMOKE_DONE')
        rep.check('win_keys_' + name, rc == 0 and bool(done) and (want is None or done[0] == want), note)
        has, dev = save_dirs(appdata)
        seen.append({'save': has, 'dev': dev, 'listing': listing(appdata / 'Roaming')})
    return seen


def try_window(exe: Path, work: Path, rep: Report, tmp_root: Path):
    appdata = Path(tempfile.mkdtemp(prefix='appdata_', dir=tmp_root))
    out, rc, _ = run([str(exe), '--rendering-driver', 'opengl3_angle', '--quit-after', '300', '--', '--report-entry'], appdata, 180)
    (work / '窗口.log').write_text(out, encoding='utf-8')
    entries = [l.split('=', 1)[1].strip() for l in out.splitlines() if l.startswith('ENTRY_SCENE=')]
    rep.info('win_windowed_angle', f'{rc_note(rc)}，' + (f'进了 {entries[0]}' if entries else '没进标题') + '（只提示：云端没显卡）')


def write_report(work: Path, rep: Report, dirs: list):
    lines = ['# Windows 实机冒烟', '', f'- 结果：{"通过" if not rep.failed else "失败 %d 项" % len(rep.failed)}', '',
             '| 项 | 结果 | 说明 |', '| --- | --- | --- |']
    for name, ok, note in rep.rows:
        lines.append(f'| {name} | {"—" if ok is None else ("过" if ok else "**不过**")} | {note} |')
    if dirs:
        lines += ['', '存档目录里出现的文件（第一次运行，节选）：', '']
        lines += [f'- `{p}`' for p in dirs[0]['listing']] or ['- （空）']
    (work / '报告.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (work / '结果.json').write_text(json.dumps([{'name': n, 'ok': o, 'note': t} for n, o, t in rep.rows],
                                             ensure_ascii=False, indent=1), encoding='utf-8')


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--dir', required=True)
    ap.add_argument('--out')
    ap.add_argument('--exe', default=EXE, help='可执行文件名（测试用假 exe 时改）')
    ap.add_argument('--no-keys', action='store_true')
    ap.add_argument('--try-window', action='store_true')
    a = ap.parse_args(argv)
    src = Path(a.dir)
    exe = src / a.exe
    pck = exe.with_suffix('.pck')
    work = Path(a.out or tempfile.mkdtemp(prefix='xiyou_win_run_'))
    work.mkdir(parents=True, exist_ok=True)
    rep = Report()
    if not exe.is_file() or not pck.is_file():
        rep.check('win_package_present', False, f'{src} 里缺 {exe.name} 或 {pck.name}')
        write_report(work, rep, [])
        return 2
    rep.check('win_package_present', True, f'{exe.name} {exe.stat().st_size // 1048576} MB，{pck.name} {pck.stat().st_size // 1048576} MB')
    tmp_root = Path(tempfile.mkdtemp(prefix='xiyou_win_appdata_'))
    try:
        dirs = [entry(exe, work, rep, tmp_root)]
        if not a.no_keys:
            dirs += keys(exe, work, rep, tmp_root)
        rep.check('win_save_dir_release', any(d['save'] for d in dirs),
                  '写到了 %APPDATA%\\KYO\\再刷重制' if any(d['save'] for d in dirs) else '没有哪次运行建出 %APPDATA%\\KYO\\再刷重制')
        rep.check('win_no_dev_save_dir', not any(d['dev'] for d in dirs),
                  '出现了 KYO\\再刷重制_开发（发行包不该用调试目录，O-200）' if any(d['dev'] for d in dirs) else '没有 _开发 目录')
        if a.try_window:
            try_window(exe, work, rep, tmp_root)
    finally:
        shutil.rmtree(tmp_root, ignore_errors=True)
    write_report(work, rep, dirs)
    print(f'报告：{work / "报告.md"}')
    return 1 if rep.failed else 0


if __name__ == '__main__':
    sys.exit(main())
