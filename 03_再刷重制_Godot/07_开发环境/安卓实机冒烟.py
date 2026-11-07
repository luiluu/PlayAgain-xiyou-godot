#!/usr/bin/env python3
"""安卓实机冒烟（cc 平台 FB 二批 2026-11-07）：在真安卓系统（云端 x86_64 模拟器）上装「安卓 发行」包跑一遍。

  python3 安卓实机冒烟.py --apk <apk> [--out <目录>] [--serial emulator-5554] [--package local.kyo.remake]

云端用法：.github/workflows/export-smoke.yml 的 android-run 任务（ubuntu＋KVM，reactivecircus/android-emulator-runner 起
x86_64 模拟器）。包在同一次运行的安卓任务里导出：CI 副本的「安卓 发行」多开 x86_64 架构（正式预设只有 arm64-v8a，
模拟器不用 ARM 转译），用那次运行现生成的一次性调试 keystore 签名；经 Actions 缓存传过来（不做附件，跑完删）。
只认 emulator-* 序列号，不往真机上装（Kyo 的手机要他同意）。

查的（发行模板：11-06 那类对空指针调方法，只有发行版会闪退）：
  - 装包（adb install -r）、清数据（pm clear）
  - 启动 25 秒后进程活着；logcat 里 ENTRY_SCENE=res://modes/xiyou/entry.tscn＝进了标题。启动参数写进副本的 assets/_cl_
    （Godot 4.7 对外部启动的 intent 一律删掉 command_line_params），副本用一次性 keystore 重签；原包不动
  - 按键（默认开，同 发行入口冒烟.py 的四组）：每组一个 _cl_ 带 --smoke-keys=<序列> 的副本，清数据启动，等 SMOKE_DONE
    （按完游戏自己退出），新游戏三组要停在地图；logcat 里本包没有崩溃行
  - 切后台自动存档（O-215）：新游戏后在地图上按 HOME，游戏打出 PAUSE_SAVE=<结果>；存成了（saved）就杀进程重开，
    标题要打出 AUTO_SAVE_PRESENT=true（有「继续」）且进程活着；没存成（开场事件在跑等）只记 INFO
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
WAIT = {'launch': 25.0, 'after_key': 10.0, 'back_exit': 6.0, 'home': 5.0, 'poll': 2.0, 'autosave': 75.0}


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
        # 启动参数不走 intent：Godot 4.7 对导出的 Activity（GodotAppLauncher）一律删掉 command_line_params，
        # 不导出的 GodotApp 外面又起不来；所以参数写进 apk 的 assets/_cl_（见 with_cmdline）
        self.run('shell', 'am', 'start', '-W', '-n', f'{pkg}/{ACTIVITY}', timeout=120)


# 同 发行入口冒烟.py／Windows实机冒烟.py 的 KEY_RUNS（测试安卓实机冒烟.py 核对一致）
MAP = 'res://modes/xiyou/map/map_scene.tscn'
KEY_RUNS = [
    ('title_space_new_game', 'space', MAP),
    ('title_j_new_game', 'j', MAP),
    ('title_enter_new_game', 'accept', MAP),
    ('title_cancel_then_map_keys', 'cancel,x,k,down,up,z,wait:90,accept,space,j,accept,cancel,cancel,x,k,cancel,accept', None),
]
KEY_TIMEOUT = 120.0


def cl_bytes(args) -> bytes:
    """Godot 安卓 assets/_cl_ 的格式（CommandLineFileParser）：小端 int32 个数，每个参数小端 int32 长度＋UTF-8。"""
    out = len(args).to_bytes(4, 'little')
    for a in args:
        b = a.encode('utf-8')
        out += len(b).to_bytes(4, 'little') + b
    return out


def parse_cl(data: bytes) -> list:
    n, i, out = int.from_bytes(data[:4], 'little'), 4, []
    for _ in range(n):
        k = int.from_bytes(data[i:i + 4], 'little')
        out.append(data[i + 4:i + 4 + k].decode('utf-8'))
        i += 4 + k
    return out


def with_cmdline(src: str, dst: Path, args) -> None:
    """复制 apk，把 assets/_cl_ 换成 args，去掉旧签名（之后 zipalign＋apksigner 重签）。只给冒烟用的副本，原包不动。"""
    import zipfile
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, 'w') as zout:
        for info in zin.infolist():
            n = info.filename
            if n == 'assets/_cl_' or (n.startswith('META-INF/') and n.rsplit('.', 1)[-1] in ('SF', 'RSA', 'EC', 'DSA', 'MF')):
                continue
            zout.writestr(info, zin.read(n))
        zout.writestr(zipfile.ZipInfo('assets/_cl_'), cl_bytes(args), compress_type=zipfile.ZIP_STORED)


class Signer:
    """一次性 keystore＋build-tools 里的 zipalign／apksigner，给改过 _cl_ 的副本重签。"""
    def __init__(self, build_tools: Path, keystore: Path, password: str):
        self.bt, self.ks, self.pw = build_tools, keystore, password

    @staticmethod
    def find(build_tools_arg, work: Path, keystore_arg=None):
        sdk = Path(os.environ.get('ANDROID_HOME') or Path.home() / 'Library/Android/sdk')
        bt = Path(build_tools_arg) if build_tools_arg else (sorted((sdk / 'build-tools').glob('*'))[-1:] or [None])[0]
        if bt is None or not (bt / 'zipalign').is_file() or not (bt / 'apksigner').is_file():
            return None
        if keystore_arg:
            return Signer(bt, Path(keystore_arg), 'android')
        import secrets
        pw, ks = secrets.token_hex(8), work / 'smoke.keystore'
        java = os.environ.get('JAVA_HOME')
        keytool = str(Path(java) / 'bin' / 'keytool') if java else 'keytool'
        r = subprocess.run([keytool, '-genkeypair', '-keystore', str(ks), '-storepass', pw, '-keypass', pw, '-alias', 'smoke',
                            '-keyalg', 'RSA', '-keysize', '2048', '-validity', '2', '-dname', 'CN=Smoke'], capture_output=True)
        return Signer(bt, ks, pw) if r.returncode == 0 else None

    def make(self, src: str, dst: Path, args) -> bool:
        raw = dst.with_suffix('.raw.apk')
        with_cmdline(src, raw, args)
        a = subprocess.run([str(self.bt / 'zipalign'), '-p', '-f', '4', str(raw), str(dst)], capture_output=True)
        raw.unlink(missing_ok=True)
        if a.returncode != 0:
            return False
        b = subprocess.run([str(self.bt / 'apksigner'), 'sign', '--ks', str(self.ks), '--ks-pass', 'pass:' + self.pw,
                            '--ks-key-alias', 'smoke', str(dst)], capture_output=True)
        return b.returncode == 0


def key_runs(adb: 'Adb', signer: Signer, apk: str, pkg: str, work: Path, rep: Report) -> None:
    """四组按键：每组一个 _cl_ 写着 -- --report-entry --smoke-keys=<序列> 的重签副本；清数据、启动，等 SMOKE_DONE（游戏按完自己退出）。"""
    for name, seq, want in KEY_RUNS:
        v = work / f'keys_{name}.apk'
        if not signer.make(apk, v, ['--', '--report-entry', f'--smoke-keys={seq}']):
            rep.check('android_keys_' + name, False, '重签副本没做出来')
            continue
        code, out = adb.rc('install', '-r', str(v))
        if code != 0:
            v.unlink(missing_ok=True)
            rep.check('android_keys_' + name, False, '装不上：' + (out.splitlines()[-1] if out else str(code)))
            continue
        adb.run('shell', 'pm', 'clear', pkg)
        adb.run('logcat', '-c')
        adb.launch(pkg)
        first = adb.pid(pkg)
        t0, log, done = time.monotonic(), '', None
        while time.monotonic() - t0 < KEY_TIMEOUT:
            log = adb.run('logcat', '-d', '-v', 'threadtime', timeout=120)
            m = re.search(r'SMOKE_DONE scene=(\S+)', log)
            if m:
                done = m.group(1)
                break
            if not adb.pid(pkg) and time.monotonic() - t0 > 5:
                break
            time.sleep(WAIT['poll'])
        (work / f'logcat_keys_{name}.txt').write_text(log, encoding='utf-8')
        steps = len(re.findall(r'SMOKE_KEY=', log))
        bad = fatal_lines(log, {first} if first else set(), pkg)
        note = f'按完 {steps}/{len(seq.split(","))} 步' + (f'，最后在 {done}' if done else '，没有 SMOKE_DONE') + (f'；崩溃：{bad[0]}' if bad else '')
        rep.check('android_keys_' + name, bool(done) and not bad and (want is None or done == want), note)
        adb.run('shell', 'am', 'force-stop', pkg)
        v.unlink(missing_ok=True)


# 开新游戏，再连按 40 次确认把开场剧情（Map001 自动事件，有对话和选项）点过去，最后在地图上等着，由 adb 按 HOME 切后台。
# 开场没点完时 PAUSE_SAVE 是 skip:event，只记 INFO
AUTOSAVE_SEQ = 'accept' + ',wait:30,accept' * 40 + ',wait:7200'


def autosave_run(adb: 'Adb', signer: Signer, apk: str, base: str, pkg: str, work: Path, rep: Report) -> None:
    """切后台自动存档（O-215）在真安卓上：新游戏进地图 → HOME → 看 PAUSE_SAVE → 杀进程 → 重开，标题有没有「继续」（AUTO_SAVE_PRESENT）。"""
    v = work / 'autosave.apk'
    if not signer.make(apk, v, ['--', '--report-entry', f'--smoke-keys={AUTOSAVE_SEQ}']):
        rep.check('android_pause_save', False, '重签副本没做出来')
        return
    adb.rc('install', '-r', str(v))
    adb.run('shell', 'pm', 'clear', pkg)
    adb.run('logcat', '-c')
    adb.launch(pkg)
    v.unlink(missing_ok=True)
    sleep('autosave')
    adb.key(KEY_HOME)
    sleep('home')
    log = adb.run('logcat', '-d', '-v', 'threadtime', timeout=120)
    got = re.findall(r'PAUSE_SAVE=(\S+)', log)
    adb.run('shell', 'am', 'force-stop', pkg)
    # 重开用基础副本（同一把 key，install -r 保留数据）
    adb.rc('install', '-r', base)
    adb.run('logcat', '-c')
    adb.launch(pkg)
    sleep('launch')
    log2 = adb.run('logcat', '-d', '-v', 'threadtime', timeout=120)
    (work / 'logcat_autosave.txt').write_text(log + '\n---- 重开 ----\n' + log2, encoding='utf-8')
    present = re.findall(r'AUTO_SAVE_PRESENT=(\w+)', log2)
    alive = adb.pid(pkg)
    adb.run('shell', 'am', 'force-stop', pkg)
    rep.check('android_pause_hook_fires', bool(got), '切后台时 XAutoSave.on_pause 结果：' + ('、'.join(got) or '没打出来（切后台通知没到游戏？）'))
    if 'saved' in got:
        rep.check('android_autosave_continue', present[-1:] == ['true'] and bool(alive), f'重开后标题 AUTO_SAVE_PRESENT={present[-1] if present else "没打出来"}，pid={alive or "无"}')
    elif got:
        rep.info('android_autosave_continue', f'切后台那一刻没存（{got[-1]}，如开场事件还在跑），重开 AUTO_SAVE_PRESENT={present[-1] if present else "没打出来"}')


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


def smoke(adb: 'Adb', apk: str, pkg: str, work: Path, rep: Report, expect_entry=False) -> None:
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
    if entries or expect_entry:
        rep.check('android_enters_title', entries == [TITLE], ','.join(entries) or '_cl_ 带了 --report-entry，logcat 里却没有 ENTRY_SCENE')
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
    ap.add_argument('--no-keys', action='store_true', help='不跑四组按键')
    ap.add_argument('--no-resign', action='store_true', help='不改 _cl_、不重签，直接装原包')
    ap.add_argument('--build-tools', help='zipalign／apksigner 所在目录（默认 $ANDROID_HOME/build-tools 下最新的）')
    ap.add_argument('--keystore', help='重签用的 keystore（口令 android、别名 smoke；默认现生成一次性的）')
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
    adb = Adb(a.adb, serial)
    signer = None if a.no_resign else Signer.find(a.build_tools, work, a.keystore)
    apk = a.apk
    if signer is not None:
        # 重签的副本和原包签名不同，先卸掉旧的（模拟器上的冒烟包，不是玩家的）
        adb.run('uninstall', a.package)
        base = work / 'base.apk'
        if signer.make(a.apk, base, ['--', '--report-entry']):
            apk = str(base)
        else:
            rep.info('android_resign', '重签副本没做出来，用原包（看不到 ENTRY_SCENE，也跑不了按键组）')
            signer = None
    else:
        rep.info('android_resign', '没有 build-tools 的 zipalign／apksigner 或 keytool：用原包，看不到 ENTRY_SCENE，跳过按键组')
    smoke(adb, apk, a.package, work, rep, expect_entry=signer is not None)
    if signer is not None and not a.no_keys and not any(n == 'android_install' and o is False for n, o, _ in rep.rows):
        key_runs(adb, signer, a.apk, a.package, work, rep)
        autosave_run(adb, signer, a.apk, apk, a.package, work, rep)
    for f in work.glob('*.apk'):
        f.unlink()
    write_report(work, rep)
    print(f'报告：{work / "报告.md"}')
    if any(n == 'android_install' and o is False for n, o, _ in rep.rows):
        return 2
    return 1 if rep.failed else 0


if __name__ == '__main__':
    sys.exit(main())
