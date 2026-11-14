#!/usr/bin/env python3
"""发行包入口冒烟（BI 正式入口，cc 2026-11-05）：导出「macOS 发行」包，确认打开就进西游标题、名字和图标对。

  python3 发行入口冒烟.py               导出 release 包 → 解开 → 只读查 Info.plist 与图标 → 隔离 HOME 里无头跑一次
  python3 发行入口冒烟.py --zip <包>     不导出，直接查现成的包
  python3 发行入口冒烟.py --keep         留下解开的 .app
  python3 发行入口冒烟.py --platform windows   导出「Windows 发行」：查 exe 资源里的名字和 256 图标，
                                         再把 macOS 发行模板改成同名、放在 .pck 旁边跑一次（发行模板不认 --main-pack）
  python3 发行入口冒烟.py --platform android [--keys] [--apk <包>]   导出「安卓 发行」（发行 keystore 没配就用本机 Godot 调试
                                         keystore 签，只给冒烟和试装）：静态查签名、包名、应用名、版本号（按开发编号，O-待定·安卓版本号）、
                                         入口与资源、没有 tests/；apk 的 assets/ 打成 pck 放到 macOS 发行模板旁跑入口（和按键）；
                                         有在跑的模拟器（emulator-*）就装上启动、20 秒后看进程活着；没有就在输出里写明只做了静态检查。
                                         真机不碰（cc 平台 DZ 2026-11-06）
  python3 发行入口冒烟.py --keys         另外按键冒烟（platform-crash1）：每组新开一个进程、新临时 HOME，
                                         标题按空格／J／回车开新游戏，再按一串确认、取消键，看进程活着、没有新崩溃报告
  python3 发行入口冒烟.py --keys-only --zip <包>   只做按键冒烟（不查名字图标），给验证旧包／修后包用
  python3 发行入口冒烟.py --arch x86_64 [--keys]  macOS 包在 Rosetta 下跑 x86_64 切片（arch -x86_64；包是 universal 才有这个切片）
  python3 发行入口冒烟.py --update-baseline   全部通过时把启动用时记进 发行入口启动基线.json（按平台／架构各一份）
  python3 发行入口冒烟.py --keys-only --app <.app>  同上，直接跑一个已解开的 .app（只执行、不改它；HOME 照旧是临时的）

查的：
  - 包名、CFBundleName／CFBundleDisplayName 是「再刷一把：天启篇」，包里有 icns 图标且和 content/app_icon/icon.icns 一致
  - Windows：.pck 里原样带着运行时窗口图标 content/app_icon_runtime/icon.png、icon.ico（标题栏、任务栏用）
  - 版本号（平台 EC）：Mac CFBundleShortVersionString／CFBundleVersion＝0.<号>／<号>，Windows exe 资源里有 0.<号>.0.0；
    号取当前工程的 build_info（查旧包时号对不上会报失败）；XDesktopVersion.AUTO 关着就不查
  - 包内运行（--headless --quit-after，加 --report-entry 让游戏打印进了哪个场景）：只出现 ENTRY_SCENE=res://modes/xiyou/entry.tscn
  - 启动基线（平台 EC）：起进程到打印 ENTRY_SCENE 的秒数，跟 发行入口启动基线.json 比；慢一倍以上且多 2 秒打 WARN「变慢」，
    只提示不算失败（机器忙时会抖）；Windows／安卓是 macOS 发行模板当替身，量的是读包数据进标题，不是真机
发行包排除了 tests/、不认 --verify-export，所以这里只看入口，不跑包内测试（那是 导出冒烟.py 对「macOS 验收」调试包做的）。
按键冒烟（--keys）：发行模板的 GDScript 对 null 调方法不查空、直接 SIGSEGV（11-06 标题按空格/J 闪退），调试版只报错，
所以只有发行包里真按键才看得到。游戏带 `-- --smoke-keys=<序列>` 时自己注入按键（core/key_smoke.gd，经 Input.parse_input_event），
按完打印 SMOKE_DONE 并退出 0；这里查：退出码 0、有 SMOKE_DONE、新游戏那几组最后在地图场景、~/Library/Logs/DiagnosticReports 没多出本包的崩溃报告。
发行构建直达西游标题、没有「返回版本选择」（BI），那一项只有调试构建有（tests/xiyou_input_handled 覆盖）。
每次运行用新建的临时 HOME，跑完删掉；临时目录 xiyou_release_entry_* 通过就整个删、失败只留 .log、
被 SIGTERM 结束也收尾，下次运行清掉上次被杀残留的（cc 平台 EC 2026-11-06，以前每次留 0.5～1 GB）；不碰真实玩家存档，不签名、不公证。退出码：通过 0，失败 1，导出或解包出错 2。
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
# 天启篇开局（11-10 起）：新的游戏 → 选存档位（1 号）→ 选难度（第一档）→ 随机阵容（焦点在「重新随机」，down 到「就是他们了」）→ 地图；
# 只按一下停在选存档位，三组新游戏会挂（平台 release450 2026-11-11）。
KEY_RUNS = [
    ('title_space_new_game', 'space,space,space,down,space', MAP),
    ('title_j_new_game', 'j,j,j,down,j', MAP),
    ('title_enter_new_game', 'accept,accept,accept,down,accept', MAP),
    ('title_cancel_then_map_keys', 'cancel,x,k,down,up,z,wait:90,accept,space,j,accept,cancel,cancel,x,k,cancel,accept', None),
]


def windows(work: Path, check, keys=False, win_dir=None) -> int:
    exe = work / 'win' / '再刷一把_天启篇.exe'
    exe.parent.mkdir()
    if win_dir:
        # 现成的包（发行出包.py）：exe 和 pck 拷进工作目录再跑，替身模板写在 pck 旁边，不往发行目录里放东西
        src = Path(win_dir)
        for f in ('再刷一把_天启篇.exe', '再刷一把_天启篇.pck'):
            if not (src / f).is_file():
                print(f'{src} 里没有 {f}')
                return 2
            shutil.copy(src / f, exe.parent / f)
    else:
        p = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-release', 'Windows 发行', str(exe)],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', timeout=900)
        (work / '导出.log').write_text(p.stdout, encoding='utf-8')
        if p.returncode != 0:
            print(p.stdout[-3000:])
    pck = exe.with_suffix('.pck')
    if not exe.is_file() or not pck.is_file():
        print('导出失败')
        return 2
    blob = exe.read_bytes()
    check('exe_product_name', APP_NAME.encode('utf-16-le') in blob)
    ico = (PROJECT / 'content' / 'app_icon' / 'icon.ico').read_bytes()
    n = struct.unpack('<H', ico[4:6])[0]
    size, off = struct.unpack('<II', ico[6 + 16 * (n - 1) + 8:6 + 16 * (n - 1) + 16])
    check('exe_icon_256', ico[off:off + size] in blob)
    # 运行时窗口图标（标题栏／任务栏）：project.godot 的 config/icon 与 windows_native_icon 原样进 .pck（11-13，原来是 Godot 默认图标）
    pck_blob = pck.read_bytes()
    runtime = PROJECT / 'content' / 'app_icon_runtime'
    check('pck_window_icon_png', (runtime / 'icon.png').read_bytes() in pck_blob)
    check('pck_window_icon_ico', (runtime / 'icon.ico').read_bytes() in pck_blob)
    want_v = desktop_version('windows')
    if want_v:
        check('exe_version', want_v.encode('utf-16-le') in blob, f'资源里{"有" if want_v.encode("utf-16-le") in blob else "没有"} {want_v}')
    runner = release_runner(work, pck)
    if runner is None:
        return 2
    run_entry(work, runner, check, 'windows')
    return run_keys(work, runner, check) if keys else 0


def desktop_version(platform: str):
    sys.path.insert(0, str(HERE))
    import 导出冒烟 as smoke
    return smoke.expected_desktop_version(platform)


def release_runner(work: Path, pck: Path):
    """macOS 发行模板的可执行文件，改成和 pck 同名、放在它旁边（发行模板不认 --main-pack，只认同名 .pck）。"""
    cfg = (PROJECT / 'export_presets.cfg').read_text(encoding='utf-8')
    tpl = Path(re.search(r'custom_template/release="([^"]*macos[^"]*)"', cfg).group(1))
    tdir = work / 'tpl'
    if subprocess.run(['ditto', '-x', '-k', str(tpl), str(tdir)]).returncode != 0:
        print('解不开 macOS 模板')
        return None
    rel = next(tdir.rglob('godot_macos_release*'))
    runner = pck.with_suffix('')
    shutil.copy(rel, runner)
    runner.chmod(0o755)
    return runner


ANDROID_PRESET = '安卓 发行'
ANDROID_NEED = ['assets/project.binary', 'assets/modes/xiyou/entry.tscn.remap', 'assets/content/build_info.json',
                'assets/modes/xiyou/generated/db/System.json']


def editor_debug_keystore():
    """本机 Godot 编辑器设置里的调试 keystore（路径, 密码）；没有返回 (None, None)。只在发行 keystore 没配时用来签冒烟包。"""
    for f in sorted((HERE / '当前Godot.app').resolve().parent.glob('editor_data/editor_settings-*.tres')):
        text = f.read_text(encoding='utf-8', errors='replace')
        path = re.search(r'^export/android/debug_keystore = "([^"]*)"', text, re.M)
        pw = re.search(r'^export/android/debug_keystore_pass = "([^"]*)"', text, re.M)
        if path and pw and Path(path.group(1)).is_file():
            return path.group(1), pw.group(1)
    return None, None


def emulators(adb: Path) -> tuple:
    """adb devices 里的（模拟器, 真机）序列号。真机不碰（装到 Kyo 手机上要他同意）。"""
    out = subprocess.run([str(adb), 'devices'], capture_output=True, text=True, timeout=30).stdout
    rows = [l.split('\t') for l in out.splitlines()[1:] if '\t' in l]
    online = [s for s, st in rows if st.strip() == 'device']
    return [s for s in online if s.startswith('emulator-')], [s for s in online if not s.startswith('emulator-')]


def android(work: Path, check, keys=False, apk=None) -> int:
    """安卓发行包：静态查 apk（签名、包名、应用名、版本号、入口和资源、没有 tests/）；
    把 apk 的 assets/ 打成 pck 放到 macOS 发行模板旁跑入口（和按键）；有模拟器就装机启动，没有就写明只做了静态检查。"""
    import zipfile
    sys.path.insert(0, str(HERE))
    import 导出冒烟 as smoke
    if apk is None:
        apk = work / 'android' / '再刷一把_天启篇.apk'
        apk.parent.mkdir()
        env = dict(os.environ)
        if not env.get('GODOT_ANDROID_KEYSTORE_RELEASE_PATH'):
            ks, pw = editor_debug_keystore()
            if ks is None:
                print('没配发行 keystore，本机也找不到 Godot 调试 keystore，导不了安卓发行包')
                return 2
            env.update(GODOT_ANDROID_KEYSTORE_RELEASE_PATH=ks, GODOT_ANDROID_KEYSTORE_RELEASE_USER='androiddebugkey',
                       GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=pw)
            print('发行 keystore 没配：用本机 Godot 调试 keystore 签名（只给冒烟和真机试装，不能上架）')
        p = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-release', ANDROID_PRESET, str(apk)],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', timeout=1800, env=env)
        (work / '导出.log').write_text(p.stdout, encoding='utf-8')
        if p.returncode != 0 or not apk.is_file():
            print(p.stdout[-3000:])
            print('导出失败')
            return 2
    with zipfile.ZipFile(apk) as z:
        names = z.namelist()
        problems, info = smoke.android_layout(apk, names, debug=False)
        check('apk_layout', not problems, '；'.join(problems) or f'apksigner、包名 {info["package"]}、arm64-v8a、横屏')
        if info is None:
            return 2
        check('apk_label', info.get('label') == APP_NAME, str(info.get('label')))
        want = smoke.expected_android_version(ANDROID_PRESET)
        check('apk_version', str(info.get('versionCode')) == str(want['versionCode']) and str(info.get('versionName')) == str(want['versionName']),
              f'versionCode {info.get("versionCode")}、versionName {info.get("versionName")}（应是 {want["versionCode"]}、{want["versionName"]}）')
        missing = [n for n in ANDROID_NEED if n not in names]
        check('apk_entry_files', not missing, '缺 ' + '、'.join(missing) if missing else '、'.join(n.removeprefix('assets/') for n in ANDROID_NEED))
        check('apk_no_tests', not any(n.startswith('assets/tests/') for n in names))
        z.extractall(work / 'apk', [n for n in names if n.startswith('assets/')])
    # 桌面替身：assets/ 打成 pck（打包pck.gd），放到 macOS 发行模板旁跑——查的是包里的数据能不能进标题、按键闪不闪退，不是安卓本身
    pck = work / 'run' / '再刷一把_天启篇.pck'
    pck.parent.mkdir()
    empty = work / 'empty_project'
    empty.mkdir()
    (empty / 'project.godot').write_text('config_version=5\n', encoding='utf-8')
    p = subprocess.run([str(GODOT), '--headless', '--path', str(empty), '--script', str(HERE / '打包pck.gd'), '--',
                        str(work / 'apk' / 'assets'), str(pck)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, errors='replace', timeout=900)
    (work / '打包pck.log').write_text(p.stdout, encoding='utf-8')
    shutil.rmtree(work / 'apk', ignore_errors=True)
    if p.returncode != 0 or not pck.is_file():
        print('把 apk 的 assets/ 打成 pck 失败，见 ' + str(work / '打包pck.log'))
        return 2
    runner = release_runner(work, pck)
    if runner is None:
        return 2
    run_entry(work, runner, check, 'android')
    if keys:
        run_keys(work, runner, check)
    # 模拟器：有就装上、启动、看进程活着；没有（或只有真机）就只写明
    sdk = Path(os.environ.get('ANDROID_HOME') or Path.home() / 'Library' / 'Android' / 'sdk')
    adb = sdk / 'platform-tools' / 'adb'
    emus, phones = emulators(adb) if adb.is_file() else ([], [])
    if phones:
        print(f'注意：连着 {len(phones)} 台真机，冒烟不往真机上装（要装请手动 adb install）')
    if not emus:
        print('没有在跑的安卓模拟器：只做了静态检查和桌面替身运行，没在安卓上装机启动' + ('' if adb.is_file() else f'（找不到 {adb}）'))
        return 0
    serial, pkg = emus[0], info['package']
    inst = subprocess.run([str(adb), '-s', serial, 'install', '-r', str(apk)], capture_output=True, text=True, timeout=600)
    check('emulator_install', inst.returncode == 0, (inst.stdout + inst.stderr).strip().splitlines()[-1:] and (inst.stdout + inst.stderr).strip().splitlines()[-1])
    if inst.returncode != 0:
        return 0
    subprocess.run([str(adb), '-s', serial, 'shell', 'monkey', '-p', pkg, '-c', 'android.intent.category.LAUNCHER', '1'],
                   capture_output=True, text=True, timeout=60)
    time.sleep(20)
    pid = subprocess.run([str(adb), '-s', serial, 'shell', 'pidof', pkg], capture_output=True, text=True, timeout=30).stdout.strip()
    check('emulator_alive_20s', bool(pid), f'{serial} 上 {pkg} pid={pid or "无"}')
    subprocess.run([str(adb), '-s', serial, 'shell', 'am', 'force-stop', pkg], capture_output=True, timeout=30)
    return 0


BASELINE = HERE / '发行入口启动基线.json'
SLOW_FACTOR = 2.0   # 比基线慢一倍以上（且多 2 秒以上）算变慢
SLOW_MARGIN = 2.0


def timed_run(cmd, env, cwd, timeout=300):
    """跑一次，返回 (输出, 退出码, 看到 ENTRY_SCENE 的秒数或 None)。秒数从起进程算到游戏打印 ENTRY_SCENE（读完资源、切进标题）。"""
    t0 = time.monotonic()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', env=env, cwd=cwd)
    import threading
    killer = threading.Timer(timeout, p.kill)  # 不出声地卡住时也能到点结束
    killer.start()
    lines, seen = [], None
    try:
        for line in p.stdout:
            lines.append(line)
            if seen is None and line.startswith('ENTRY_SCENE='):
                seen = time.monotonic() - t0
        rc = p.wait(timeout=30)
    finally:
        killer.cancel()
        if p.poll() is None:
            p.kill()
            p.wait()
    return ''.join(lines), rc, seen


def baseline_key(platform: str) -> str:
    return platform + ('_' + RUN_PREFIX[1].lstrip('-') if RUN_PREFIX else '')


def load_baseline() -> dict:
    import json
    try:
        return json.loads(BASELINE.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def compare_baseline(key: str, secs, base: dict) -> str:
    """启动到标题的用时跟基线比：返回一句说明；明显变慢以「变慢」开头（只提示，不算失败——机器忙时会抖）。"""
    if secs is None:
        return '没量到启动用时'
    b = base.get(key, {}).get('seconds')
    if not b:
        return f'启动到标题 {secs:.1f} 秒（{key} 还没有基线，--update-baseline 记一份）'
    if secs > b * SLOW_FACTOR and secs - b > SLOW_MARGIN:
        return f'变慢：启动到标题 {secs:.1f} 秒，基线 {b:.1f} 秒（{key}）'
    return f'启动到标题 {secs:.1f} 秒，基线 {b:.1f} 秒（{key}）'


def run_entry(work: Path, exe: Path, check, platform='macos') -> int:
    home = Path(tempfile.mkdtemp(prefix='xiyou_export_home_'))
    try:
        out, rc, secs = timed_run([*RUN_PREFIX, str(exe), '--headless', '--quit-after', '600', '--', '--report-entry'],
                                  env=dict(os.environ, HOME=str(home)), cwd=str(home))
    finally:
        shutil.rmtree(home, ignore_errors=True)
    (work / '运行.log').write_text(out, encoding='utf-8')
    entries = [l.split('=', 1)[1].strip() for l in out.splitlines() if l.startswith('ENTRY_SCENE=')]
    check('release_enters_title', entries == [TITLE], ','.join(entries) or '没有 ENTRY_SCENE')
    check('release_exit_clean', rc == 0, f'退出码 {rc}')
    key = baseline_key(platform)
    note = compare_baseline(key, secs, load_baseline())
    print(('WARN ' if note.startswith('变慢') else 'INFO ') + 'startup_time（' + note + '）')
    STARTUP[key] = secs
    return 0


STARTUP: dict = {}


def update_baseline(results: dict) -> None:
    import json
    base = load_baseline()
    for k, v in results.items():
        if v is not None:
            base[k] = {'seconds': round(v, 2), 'date': time.strftime('%Y-%m-%d'), 'host': os.uname().machine}
    BASELINE.write_text(json.dumps(base, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(f'基线已更新：{BASELINE.name} ' + '、'.join(f'{k}={v:.1f}s' for k, v in results.items() if v is not None))


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


WORK_PREFIX = 'xiyou_release_entry_'
PID_FILE = '.pid'


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def sweep_stale(tmp: Path = None) -> list:
    """删掉上次被杀（SIGKILL、断电）没走到收尾的 xiyou_release_entry_* 目录：.pid 里的进程已不在、或没有 .pid 且超过 6 小时。"""
    tmp = Path(tmp or tempfile.gettempdir())
    removed = []
    for d in tmp.glob(WORK_PREFIX + '*'):
        if not d.is_dir():
            continue
        pf = d / PID_FILE
        try:
            stale = not pid_alive(int(pf.read_text().strip())) if pf.is_file() else time.time() - d.stat().st_mtime > 6 * 3600
        except (ValueError, OSError):
            stale = True
        if stale:
            shutil.rmtree(d, ignore_errors=True)
            removed.append(d.name)
    return removed


def cleanup(work: Path, ok: bool, keep: bool) -> str:
    """跑完收尾：--keep 全留；通过就整个目录删掉；失败只留 *.log（几百 KB）方便查，大件全删。返回给用户看的一句话。"""
    if keep:
        return f'日志和产物留在 {work}（--keep，用完请自己删）'
    if ok:
        shutil.rmtree(work, ignore_errors=True)
        return '临时目录已删'
    for t in work.iterdir():
        if t.is_file() and (t.suffix == '.log' or t.name == PID_FILE):  # 留 .pid：下次运行认得出是死进程的残留、清掉
            continue
        if t.is_dir() and not t.is_symlink():
            shutil.rmtree(t, ignore_errors=True)
        else:
            t.unlink(missing_ok=True)
    return f'失败日志留在 {work}（只有 .log，看完可删；下次运行本脚本时自动清掉）'


def _raise_on_signal(signum, _frame):
    raise SystemExit(128 + signum)


def main() -> int:
    import signal
    # 被 SIGTERM／SIGHUP 结束（超时、会话关闭）时也走 finally 收尾，不留 0.5～1 GB 的解包目录
    for s in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, _raise_on_signal)
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--zip')
    ap.add_argument('--arch', choices=['x86_64', 'arm64'], help='用 arch -<架构> 跑 macOS 包的某个切片（x86_64 走 Rosetta）')
    ap.add_argument('--app', help='已解开的 .app（只配 --keys-only）')
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--platform', choices=['macos', 'windows', 'android'], default='macos')
    ap.add_argument('--apk', help='--platform android：不导出，直接查现成的 apk')
    ap.add_argument('--win-dir', help='--platform windows：不导出，直接查这个目录里现成的 再刷一把_天启篇.exe／.pck')
    ap.add_argument('--keys', action='store_true', help='另外跑按键冒烟')
    ap.add_argument('--keys-only', action='store_true', help='只跑按键冒烟（配合 --zip 验证现成的包）')
    ap.add_argument('--update-baseline', action='store_true', help='全部通过时把这次的启动用时记成基线（发行入口启动基线.json）')
    a = ap.parse_args()
    a.keys = a.keys or a.keys_only
    if a.arch:
        if a.platform != 'macos':
            print('--arch 只配 macOS 包')
            return 2
        RUN_PREFIX[:] = ['arch', '-' + a.arch]
    gone = sweep_stale()
    if gone:
        print(f'清掉上次残留的临时目录 {len(gone)} 个：' + '、'.join(gone))
    work = Path(tempfile.mkdtemp(prefix=WORK_PREFIX))
    (work / PID_FILE).write_text(str(os.getpid()))
    checks = []
    code = 2

    def check(name, ok, note=''):
        checks.append((name, ok))
        print(('PASS ' if ok else 'FAIL ') + name + (f'（{note}）' if note else ''))

    def run() -> int:
        if a.platform in ('windows', 'android'):
            code = windows(work, check, a.keys, a.win_dir) if a.platform == 'windows' else \
                android(work, check, a.keys, Path(a.apk).resolve() if a.apk else None)
            if code:
                return code
            ok = all(c[1] for c in checks)
            print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）')
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
            print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）')
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
            print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）')
            return 0 if ok else 1
        check('app_bundle_name', app.stem == APP_NAME, app.name)
        info = plistlib.loads((app / 'Contents' / 'Info.plist').read_bytes())
        check('bundle_name', info.get('CFBundleName') == APP_NAME, str(info.get('CFBundleName')))
        want_v = desktop_version('macos')
        if want_v:
            got = (info.get('CFBundleShortVersionString'), info.get('CFBundleVersion'))
            check('bundle_version', got == want_v, f'{got[0]}／{got[1]}（应是 {want_v[0]}／{want_v[1]}）')
        icon = app / 'Contents' / 'Resources' / (str(info.get('CFBundleIconFile', 'icon')).removesuffix('.icns') + '.icns')
        want = PROJECT / 'content' / 'app_icon' / 'icon.icns'
        check('icon_from_app_icon', icon.is_file() and want.is_file() and icon.read_bytes() == want.read_bytes(), icon.name)
        run_entry(work, exes[0], check)
        if a.keys:
            run_keys(work, exes[0], check)
        ok = all(c[1] for c in checks)
        print(f'结论：{"通过" if ok else "有失败"}（{sum(c[1] for c in checks)}/{len(checks)}）')
        if a.keep:
            print(f'留下的包：{app}')
        return 0 if ok else 1
    try:
        code = run()
        if a.update_baseline:
            if code == 0 and STARTUP:
                update_baseline(STARTUP)
            else:
                print('没更新基线：' + ('有失败' if code else '这次没跑入口'))
        return code
    finally:
        print(cleanup(work, code == 0, a.keep))


if __name__ == '__main__':
    sys.exit(main())
