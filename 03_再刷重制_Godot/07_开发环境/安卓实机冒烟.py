#!/usr/bin/env python3
"""安卓实机冒烟（cc 平台 FB 二批 2026-11-07）：在真安卓系统（云端 x86_64 模拟器）上装「安卓 发行」包跑一遍。

  python3 安卓实机冒烟.py --apk <apk> [--out <目录>] [--serial emulator-5554] [--package local.kyo.remake]

云端用法：.github/workflows/export-smoke.yml 的 android-run 任务（ubuntu＋KVM，reactivecircus/android-emulator-runner 起
x86_64 模拟器）。包在同一次运行的安卓任务里导出：CI 副本的「安卓 发行」多开 x86_64 架构（正式预设只有 arm64-v8a，
模拟器不用 ARM 转译），用那次运行现生成的一次性调试 keystore 签名；经 Actions 缓存传过来（不做附件，跑完删）。
只认 emulator-* 序列号，不往真机上装（Kyo 的手机要他同意）。

查的（发行模板：11-06 那类对空指针调方法，只有发行版会闪退）：
  - 装包（adb install -r）、清数据（pm clear）
  - 启动 25 秒后进程活着；logcat 里看到 ENTRY_SCENE=res://modes/xiyou/entry.tscn 算进了标题（启动参数带 --report-entry，
    看不到只记 INFO：Godot 安卓的 command_line_params 传参没在真机核实过）
  - 返回键：标题按一次进程还在（出「再按一次返回键退出」），两秒内再按一次进程结束（O-202）
  - 新游戏：重开，标题按回车（11-06 闪退那条路），10 秒后进程活着
  - 切后台：按 HOME、等 5 秒、再拉起来：还是同一个进程（回前台而不是重开）、活着
  - 全程 logcat 里本包进程没有 FATAL EXCEPTION／Fatal signal／SIGSEGV／ANR
看不到的：触屏手感、帧率、声音、文件选择器，见 00_项目管理/安卓发行包验收清单.md。退出码：通过 0，失败 1，装不上或没有模拟器 2。
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

PACKAGE = 'local.kyo.remake'
ACTIVITY = 'com.godot.game.GodotAppLauncher'
TITLE = 'res://modes/xiyou/entry.tscn'
KEY_BACK, KEY_HOME, KEY_ENTER = 4, 3, 66
FATAL = re.compile(r'FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGABRT|ANR in ')
# 等待时长（测试里调小）
WAIT = {'launch': 25.0, 'after_key': 10.0, 'back_exit': 6.0, 'home': 5.0}


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


class Adb:
    def __init__(self, adb: str, serial: str):
        self.adb, self.serial = adb, serial

    def run(self, *args, timeout=120) -> str:
        p = subprocess.run([self.adb, '-s', self.serial, *args], capture_output=True, text=True, errors='replace', timeout=timeout)
        return (p.stdout + p.stderr).strip()

    def rc(self, *args, timeout=600) -> tuple:
        p = subprocess.run([self.adb, '-s', self.serial, *args], capture_output=True, text=True, errors='replace', timeout=timeout)
        return p.returncode, (p.stdout + p.stderr).strip()

    def pid(self, pkg) -> str:
        out = self.run('shell', 'pidof', pkg, timeout=30).split()
        return out[0] if out and out[0].isdigit() else ''

    def key(self, code: int):
        self.run('shell', 'input', 'keyevent', str(code), timeout=30)

    def launch(self, pkg):
        # Godot 安卓读 intent 的 command_line_params（字符串数组）当启动参数；-- 之后是游戏自己的参数
        self.run('shell', 'am', 'start', '-W', '-n', f'{pkg}/{ACTIVITY}', '--esa', 'command_line_params', '--,--report-entry', timeout=120)


def emulators(adb: str) -> list:
    out = subprocess.run([adb, 'devices'], capture_output=True, text=True, timeout=30).stdout
    rows = [l.split('\t') for l in out.splitlines()[1:] if '\t' in l]
    return [s for s, st in rows if st.strip() == 'device' and s.startswith('emulator-')]


def fatal_lines(log: str, pids, pkg: str = PACKAGE) -> list:
    """logcat（threadtime 格式）里属于这些进程的崩溃行；带包名的崩溃行（ANR、Java 崩溃、原生崩溃的 >>> 包名 <<<）也算。"""
    out = []
    for line in log.splitlines():
        if not FATAL.search(line):
            continue
        parts = line.split()
        if pkg in line or (len(parts) > 2 and parts[2] in pids):
            out.append(line.strip())
    return out


def sleep(key):
    time.sleep(WAIT[key])


def smoke(adb: Adb, apk: str, pkg: str, work: Path, rep: Report) -> None:
    code, out = adb.rc('install', '-r', apk)
    rep.check('android_install', code == 0 and 'Success' in out, out.splitlines()[-1] if out else f'退出码 {code}')
    if code != 0:
        return
    adb.run('shell', 'pm', 'clear', pkg)
    adb.run('logcat', '-c')
    pids = set()
    # 1. 启动进标题
    adb.launch(pkg)
    sleep('launch')
    p1 = adb.pid(pkg)
    pids.add(p1)
    rep.check('android_alive_after_launch', bool(p1), f'pid={p1 or "无"}')
    log = adb.run('logcat', '-d', '-v', 'threadtime', timeout=120)
    entries = sorted(set(re.findall(r'ENTRY_SCENE=(\S+)', log)))
    if entries:
        rep.check('android_enters_title', entries == [TITLE], ','.join(entries))
    else:
        rep.info('android_enters_title', 'logcat 里没有 ENTRY_SCENE（启动参数可能没传进去），只看进程活着')
    # 2. 返回键：一次留着，两秒内再一次退出
    adb.key(KEY_BACK)
    time.sleep(1.0)
    rep.check('android_back_once_stays', adb.pid(pkg) == p1 and bool(p1), '标题按一次返回键')
    adb.key(KEY_BACK)
    sleep('back_exit')
    rep.check('android_back_twice_exits', not adb.pid(pkg), '两秒内按第二次')
    # 3. 新游戏（回车）
    adb.launch(pkg)
    sleep('launch')
    pids.add(adb.pid(pkg))  # 按键前记下：按完闪退的话之后就查不到这个 pid 了
    adb.key(KEY_ENTER)
    sleep('after_key')
    p2 = adb.pid(pkg)
    pids.add(p2)
    rep.check('android_enter_new_game_alive', bool(p2), f'标题按回车开新游戏后 pid={p2 or "无"}')
    # 4. 切后台再回来
    adb.key(KEY_HOME)
    sleep('home')
    alive_bg = adb.pid(pkg)
    adb.run('shell', 'am', 'start', '-n', f'{pkg}/{ACTIVITY}', timeout=60)
    sleep('home')
    p3 = adb.pid(pkg)
    pids.add(p3)
    rep.check('android_resume_same_process', bool(p3) and p3 == p2, f'切后台时 pid={alive_bg or "无"}，回来 pid={p3 or "无"}（应同 {p2 or "无"}）')
    # 5. 崩溃行
    log = adb.run('logcat', '-d', '-v', 'threadtime', timeout=120)
    (work / 'logcat.txt').write_text(log, encoding='utf-8')
    bad = fatal_lines(log, {p for p in pids if p}, pkg)
    rep.check('android_no_fatal', not bad, '；'.join(bad[:3]) if bad else 'logcat 里本包没有崩溃行')
    adb.run('shell', 'am', 'force-stop', pkg)


def write_report(work: Path, rep: Report):
    lines = ['# 安卓实机冒烟（模拟器）', '', f'- 结果：{"通过" if not rep.failed else "失败 %d 项" % len(rep.failed)}', '',
             '| 项 | 结果 | 说明 |', '| --- | --- | --- |']
    lines += [f'| {n} | {"—" if o is None else ("过" if o else "**不过**")} | {t} |' for n, o, t in rep.rows]
    (work / '报告.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (work / '结果.json').write_text(json.dumps([{'name': n, 'ok': o, 'note': t} for n, o, t in rep.rows], ensure_ascii=False, indent=1),
                                    encoding='utf-8')


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--apk', required=True)
    ap.add_argument('--out')
    ap.add_argument('--serial')
    ap.add_argument('--package', default=PACKAGE)
    ap.add_argument('--adb', default=str(Path(os.environ.get('ANDROID_HOME') or Path.home() / 'Library/Android/sdk') / 'platform-tools' / 'adb'))
    a = ap.parse_args(argv)
    work = Path(a.out or tempfile.mkdtemp(prefix='xiyou_android_run_'))
    work.mkdir(parents=True, exist_ok=True)
    rep = Report()
    emus = emulators(a.adb)
    serial = a.serial or (emus[0] if emus else None)
    if serial is None or not serial.startswith('emulator-') or serial not in emus:
        rep.check('android_emulator', False, '没有在跑的模拟器（只认 emulator-*，不装真机）')
        write_report(work, rep)
        return 2
    if not Path(a.apk).is_file():
        rep.check('android_apk', False, f'没有 {a.apk}')
        write_report(work, rep)
        return 2
    smoke(Adb(a.adb, serial), a.apk, a.package, work, rep)
    write_report(work, rep)
    print(f'报告：{work / "报告.md"}')
    if any(n == 'android_install' and o is False for n, o, _ in rep.rows):
        return 2
    return 1 if rep.failed else 0


if __name__ == '__main__':
    sys.exit(main())
