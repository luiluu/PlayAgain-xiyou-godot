#!/usr/bin/env python3
"""Mac 导出包启动冒烟（哪吒 mac1，2026-11-05）：一条命令导出「macOS 验收」调试包、解开、在隔离 HOME 里无头跑包内检查，写报告。

  python3 导出冒烟.py                 导出 → 解包 → 签名与架构只读检查 → 包内跑下面几项 → 报告
  python3 导出冒烟.py --zip <包.zip>   不导出，直接冒烟现成的包
  python3 导出冒烟.py --keep           留下解开的 .app（给 Kyo 实机验收用，见 00_项目管理/Mac实机验收清单.md）
  python3 导出冒烟.py --out <目录>     报告目录（默认 04_验证/本地结果/导出冒烟/<时间>/）
  python3 导出冒烟.py --scenes xiyou_mac_export,xiyou_flow   只跑这几项
  python3 导出冒烟.py --platform windows   导出「Windows 验收」，离线检查（cc BA，2026-11-05）：
                                     exe 的 PE 头（x86_64、图形界面）、旁边的 .pck 与控制台包装 exe；
                                     本机不跑 exe，把这个 .pck 放到 macOS 调试模板旁边（同名，硬链接）跑下面几项包内检查
                                     （验的是 Windows 包里的内容与资源，不是 Windows 上的引擎行为）。
                                     --zip 这时给现成的 .exe。
  python3 导出冒烟.py --platform android   导出「安卓 验收」（调试签名，cc BH 2026-11-05）：apksigner verify、aapt2 看
                                     包名／arm64-v8a／横屏、包内关键文件；再把 apk 的 assets/ 用 打包pck.gd 打成 pck 放到 macOS 调试模板旁
                                     跑包内检查（验内容；安卓贴图是 ETC2／ASTC，无头跑得起来就算，跑不起来报告里写明）。
                                     要 ~/Library/Android/sdk（或 ANDROID_HOME）的 build-tools 和 JDK（JAVA_HOME 或 ~/Library/Android/jdk）。
                                     --zip 这时给现成的 .apk。

包内跑的（都是调试包里的 tests/，发行包排除 tests/、跑不到）：
  xiyou_mac_export  字体、中文换行、皮肤、角色图、音效资源、隔离存档的写读删（--verify-export 默认场景）
  xiyou_flow        入口 → 西游 → 新游戏开局事件 → 大厅存档 → 进一层 → 遇敌自动战斗获胜 → 守层者战败回大厅 → 存档／读档一致
每项各用一个新建的临时 HOME（xiyou_export_home_*，在系统临时目录），跑完删掉；不碰真实玩家存档。
云端（cc BW 2026-11-06）：GitHub Actions「导出冒烟」工作流在 Linux 上跑 --platform windows／android：
  XIYOU_GODOT＝Linux 版 godot，XIYOU_SMOKE_RUNNER＝Linux 调试模板（包内检查用它代替 macOS 调试模板），模板与预设由 云端导出.py 准备。
  两个平台都另核版本号与图标（exe 的 VERSIONINFO／RT_GROUP_ICON；apk 的 versionCode／versionName／application-icon），与预设比。
签名只做 codesign --verify（只读）；不签名、不公证、不上传，不动钥匙串（派单 AS 第 3 条）。
退出码：全过 0，有失败 1，导出或解包出错 2。
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PROJECT = ROOT / '01_Godot工程'
GODOT = Path(os.environ.get('XIYOU_GODOT') or HERE / 'godot')
PRESET = 'macOS 验收'
PRESETS = {'macos': 'macOS 验收', 'windows': 'Windows 验收', 'android': '安卓 验收'}
LANDSCAPE = {0, 6, 8, 11}  # screenOrientation：横屏、传感器横屏、反向横屏、用户横屏
PE_MACHINES = {0x8664: 'x86_64', 0xAA64: 'arm64', 0x14C: 'x86_32'}
PE_SUBSYSTEMS = {2: '图形界面', 3: '控制台'}
SCENES = ['xiyou_mac_export', 'xiyou_flow']
TIMEOUT = {'xiyou_mac_export': 180, 'xiyou_flow': 900}
RESULT = re.compile(r'^TEST_RESULT=(\{.*\})\s*$', re.M)
FAIL = re.compile(r'^FAIL .*$', re.M)


def parse_result(log: str):
    """包内测试的输出：最后一行 TEST_RESULT 的 passed／total，加所有 FAIL 行。没有 TEST_RESULT 返回 None。"""
    found = RESULT.findall(log)
    if not found:
        return None
    try:
        data = json.loads(found[-1])
    except json.JSONDecodeError:
        return None
    return {'passed': int(data.get('passed', 0)), 'total': int(data.get('total', 0)), 'fails': FAIL.findall(log)[:20]}


def find_app(folder: Path):
    apps = sorted(folder.glob('*.app'))
    if not apps:
        return None, None
    exe_dir = apps[0] / 'Contents' / 'MacOS'
    exes = sorted(p for p in exe_dir.iterdir() if p.is_file() and os.access(p, os.X_OK)) if exe_dir.is_dir() else []
    return apps[0], (exes[0] if exes else None)


def pe_info(exe: Path):
    """Windows exe 的 PE 头：{'machine': 'x86_64', 'subsystem': '图形界面'}；不是 PE 返回 None。只读文件头，不运行。"""
    try:
        with open(exe, 'rb') as f:
            head = f.read(4096)
    except OSError:
        return None
    if len(head) < 0x40 or head[:2] != b'MZ':
        return None
    off = int.from_bytes(head[0x3C:0x40], 'little')
    if off + 24 + 70 > len(head) or head[off:off + 4] != b'PE\0\0':
        return None
    machine = int.from_bytes(head[off + 4:off + 6], 'little')
    subsystem = int.from_bytes(head[off + 24 + 68:off + 24 + 70], 'little')
    return {'machine': PE_MACHINES.get(machine, hex(machine)), 'subsystem': PE_SUBSYSTEMS.get(subsystem, str(subsystem))}


def pe_resources(data: bytes) -> dict:
    """PE 资源：有没有图标组（RT_GROUP_ICON＝14）、版本信息（RT_VERSION＝16），以及 FileVersion／ProductVersion 字符串。只读字节。"""
    out = {'icon': False, 'versionInfo': False, 'fileVersion': None, 'productVersion': None}
    try:
        off = int.from_bytes(data[0x3C:0x40], 'little')
        nsec = int.from_bytes(data[off + 6:off + 8], 'little')
        opt = int.from_bytes(data[off + 20:off + 22], 'little')
        magic = int.from_bytes(data[off + 24:off + 26], 'little')
        dirs = off + 24 + (112 if magic == 0x20B else 96)
        rva = int.from_bytes(data[dirs + 16:dirs + 20], 'little')  # 第 3 个数据目录＝资源
        base = None
        sec = off + 24 + opt
        for i in range(nsec):
            h = sec + 40 * i
            va, vsize = int.from_bytes(data[h + 12:h + 16], 'little'), int.from_bytes(data[h + 8:h + 12], 'little')
            raw = int.from_bytes(data[h + 20:h + 24], 'little')
            if rva and va <= rva < va + max(vsize, 1):
                base = raw + (rva - va)
        if base is not None:
            named = int.from_bytes(data[base + 12:base + 14], 'little')
            ids = int.from_bytes(data[base + 14:base + 16], 'little')
            types = {int.from_bytes(data[base + 16 + 8 * i:base + 20 + 8 * i], 'little') for i in range(named, named + ids)}
            out['icon'], out['versionInfo'] = 14 in types, 16 in types
    except (IndexError, ValueError):
        pass
    for key, name in (('fileVersion', 'FileVersion'), ('productVersion', 'ProductVersion')):
        tag = (name + '\0').encode('utf-16-le')
        i = data.find(tag)
        if i < 0:
            continue
        j = i + len(tag)
        j += (-j) % 4  # 值按 4 字节对齐
        end = j
        while end + 1 < len(data) and data[end:end + 2] != b'\0\0':
            end += 2
        out[key] = data[j:end].decode('utf-16-le', 'replace')
    return out


def windows_layout(exe: Path, debug: bool = True):
    """Windows 包结构检查（godot 导出 exe＋同名 .pck；调试包另有 .console.exe）。返回 (问题列表, PE 信息)。"""
    problems = []
    info = pe_info(exe)
    if info is None:
        return [f'{exe.name} 不是 Windows exe（PE 头不对）'], None
    if info['machine'] != 'x86_64':
        problems.append(f'架构是 {info["machine"]}，应为 x86_64')
    if info['subsystem'] != '图形界面':
        problems.append(f'子系统是 {info["subsystem"]}，应为图形界面')
    pck = exe.with_suffix('.pck')
    if not pck.is_file() or pck.stat().st_size < (1 << 20):
        problems.append(f'缺 {pck.name}（或小于 1 MB）')
    elif pck.read_bytes()[:4] != b'GDPC':
        problems.append(f'{pck.name} 不是 Godot 资源包（文件头不是 GDPC）')
    console = exe.with_name(exe.stem + '.console.exe')
    if debug and not console.is_file():
        problems.append(f'调试包缺 {console.name}')
    res = pe_resources(exe.read_bytes())
    info.update(res)
    preset = PRESETS['windows'] if debug else 'Windows 发行'
    if not res['icon']:
        problems.append('exe 里没有图标（RT_GROUP_ICON）')
    # 版本号：XDesktopVersion（平台 EC）导出时按开发编号改写成 0.N.0.0，预设里的 0.0.0.0 只是占位；开关关着才比预设
    # （平台 FB 2026-11-07：云端导出冒烟 Windows 那条一直拿 0.398.0.0 去比预设 0.0.0.0 报失败）
    auto = expected_desktop_version('windows')
    for key, opt in (('fileVersion', 'application/file_version'), ('productVersion', 'application/product_version')):
        want = auto if auto else preset_template(preset, opt)
        if want is not None and res[key] != str(want):
            problems.append(f'{key} 是 {res[key]}，' + (f'按开发编号应是 {want}' if auto else f'预设是 {want}'))
    return problems, info


def android_tools():
    """(apksigner, aapt2, JAVA_HOME)；找不到的是 None。只认用户目录（不动系统）。"""
    sdk = Path(os.environ.get('ANDROID_HOME') or Path.home() / 'Library' / 'Android' / 'sdk')
    tools = sorted((sdk / 'build-tools').glob('*/apksigner'))
    java = os.environ.get('JAVA_HOME')
    if not java:
        homes = sorted((Path.home() / 'Library' / 'Android' / 'jdk').glob('*/Contents/Home'))
        java = str(homes[-1]) if homes else None
    if not tools:
        return None, None, java
    return tools[-1], tools[-1].with_name('aapt2'), java


def parse_android(badging: str, xmltree: str) -> dict:
    """aapt2 dump badging／xmltree 的输出 → 包名、原生架构、屏幕方向、权限。"""
    import re as _re
    pkg = _re.search(r"package: name='([^']+)'", badging)
    vcode = _re.search(r"versionCode='([^']*)'", badging)
    vname = _re.search(r"versionName='([^']*)'", badging)
    icon = _re.search(r"application: .*icon='([^']+)'", badging)
    label = _re.search(r"application-label:'([^']*)'", badging)
    native = _re.search(r"native-code: (.*)", badging)
    orient = _re.search(r'screenOrientation\(0x[0-9a-f]+\)=(-?\d+)', xmltree)
    return {'package': pkg.group(1) if pkg else None,
            'native': _re.findall(r"'([^']+)'", native.group(1)) if native else [],
            'orientation': int(orient.group(1)) if orient else None,
            'permissions': _re.findall(r"uses-permission: name='([^']+)'", badging),
            'versionCode': vcode.group(1) if vcode else None, 'versionName': vname.group(1) if vname else None,
            'icon': icon.group(1) if icon else None, 'label': label.group(1) if label else None}


def android_layout(apk: Path, names, debug: bool = True):
    """安卓包检查：签名、包信息（parse_android 的结果）、包内关键文件。返回 (问题列表, 包信息)。"""
    problems = []
    apksigner, aapt2, java = android_tools()
    if apksigner is None or java is None:
        return ['找不到安卓 build-tools 或 JDK（~/Library/Android/sdk、~/Library/Android/jdk）'], None
    env = dict(os.environ, JAVA_HOME=java)
    v = subprocess.run([str(apksigner), 'verify', str(apk)], capture_output=True, text=True, env=env)
    if v.returncode != 0:
        problems.append('apksigner verify 不通过：' + ((v.stderr or v.stdout).strip().splitlines() or ['?'])[-1])
    badging = subprocess.run([str(aapt2), 'dump', 'badging', str(apk)], capture_output=True, text=True).stdout
    xmltree = subprocess.run([str(aapt2), 'dump', 'xmltree', '--file', 'AndroidManifest.xml', str(apk)], capture_output=True, text=True).stdout
    info = parse_android(badging, xmltree)
    problems += android_problems(info, set(names), debug)
    return problems, info


def android_problems(info: dict, names: set, debug: bool = True):
    problems = []
    if 'arm64-v8a' not in info['native']:
        problems.append(f'原生架构没有 arm64-v8a（{info["native"]}）')
    if info['orientation'] not in LANDSCAPE:
        problems.append(f'屏幕方向不是横屏（screenOrientation={info["orientation"]}）')
    if not info['package']:
        problems.append('读不出包名')
    preset = PRESETS['android'] if debug else '安卓 发行'
    want_version = expected_android_version(preset)
    for key, opt in (('package', 'package/unique_name'), ('versionCode', 'version/code'), ('versionName', 'version/name')):
        want = want_version[key] if key in want_version else preset_template(preset, opt)
        if want is not None and info.get(key) is not None and str(info[key]) != str(want):
            problems.append(f'{key} 是 {info[key]}，应是 {want}')
    if not info.get('icon'):
        problems.append('读不出应用图标（application-icon）')
    need = ['assets/project.binary', 'assets/modes/xiyou/generated/db/System.json', 'assets/scenes/entry_menu.tscn.remap']
    if debug:
        need.append('assets/tests/xiyou_mac_export.tscn.remap')
    problems += [f'包里缺 {n}' for n in need if n not in names]
    return problems


def expected_android_version(preset: str) -> dict:
    """安卓包该有的版本号：导出插件 addons/xiyou_export 的 XAndroidVersion.AUTO 开着时按 build_info 的开发编号
    （versionCode＝数字、versionName＝0.数字，O-待定·安卓版本号）；关着或读不出就用预设里填的。"""
    gd = PROJECT / 'addons' / 'xiyou_export' / 'android_version.gd'
    cfg = (PROJECT / 'project.godot').read_text(encoding='utf-8')
    auto = gd.is_file() and re.search(r'^static var AUTO := true', gd.read_text(encoding='utf-8'), re.M) \
        and 'res://addons/xiyou_export/plugin.cfg' in cfg
    if auto:
        try:
            dev = json.loads((PROJECT / 'content' / 'build_info.json').read_text(encoding='utf-8')).get('developmentVersion', '')
        except (OSError, ValueError):
            dev = ''
        m = re.fullmatch(r'dev\.(\d+)', str(dev))
        if m and int(m.group(1)) > 0:
            return {'versionCode': str(int(m.group(1))), 'versionName': '0.%d' % int(m.group(1))}
    return {'versionCode': preset_template(preset, 'version/code'), 'versionName': preset_template(preset, 'version/name')}


def expected_desktop_version(platform: str):
    """Mac／Windows 发行包该有的版本号（XDesktopVersion，O-待定·桌面版本号，平台 EC）：开关开着、插件启用、
    读得出开发编号时 Mac 是 (CFBundleShortVersionString, CFBundleVersion)＝('0.N', 'N')，Windows 是 '0.N.0.0'；否则 None（不查）。"""
    gd = PROJECT / 'addons' / 'xiyou_export' / 'desktop_version.gd'
    cfg = (PROJECT / 'project.godot').read_text(encoding='utf-8')
    if not (gd.is_file() and re.search(r'^static var AUTO := true', gd.read_text(encoding='utf-8'), re.M)
            and 'res://addons/xiyou_export/plugin.cfg' in cfg):
        return None
    try:
        dev = json.loads((PROJECT / 'content' / 'build_info.json').read_text(encoding='utf-8')).get('developmentVersion', '')
    except (OSError, ValueError):
        return None
    m = re.fullmatch(r'dev\.(\d+)', str(dev))
    if not m or int(m.group(1)) <= 0:
        return None
    n = int(m.group(1))
    return ('0.%d' % n, str(n)) if platform == 'macos' else '0.%d.0.0' % n


def preset_template(preset: str, key: str = 'custom_template/debug'):
    """从 export_presets.cfg 读某个预设的模板路径（模板在主工作区，工作树里没有）。"""
    import configparser
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.read(PROJECT / 'export_presets.cfg', encoding='utf-8')
    for sec in cfg.sections():
        if sec.startswith('preset.') and sec.count('.') == 1 and cfg[sec].get('name', '').strip('"') == preset:
            opts = cfg[sec + '.options'] if cfg.has_section(sec + '.options') else {}
            value = opts.get(key, '').strip('"')
            if not key.startswith('custom_template'):
                return value if key in opts else None
            return Path(value) if value else None
    return None


def mac_runner(work: Path, pck: Path, link: bool = True):
    """解出 macOS 调试模板的可执行文件，旁边放同名的 Windows 包 .pck（导出模板不认 --main-pack，只认 exe 旁的同名 .pck）。
    设了 XIYOU_SMOKE_RUNNER（云端 Linux：linux_debug.x86_64 模板）就用它。"""
    linux = os.environ.get('XIYOU_SMOKE_RUNNER')
    if linux:
        dest = work / 'runner'
        dest.mkdir(exist_ok=True)
        exe = dest / Path(linux).name
        shutil.copyfile(linux, exe)
        os.chmod(exe, 0o755)
        target = exe.with_suffix('.pck')
        shutil.move(str(pck), target) if not link else shutil.copyfile(pck, target)
        return exe
    zip_path = preset_template(PRESETS['macos'])
    member = 'macos_template.app/Contents/MacOS/godot_macos_debug.universal'
    if zip_path is None or not zip_path.is_file():
        return None
    dest = work / 'runner'
    dest.mkdir(exist_ok=True)
    if subprocess.run(['unzip', '-q', '-o', '-j', str(zip_path), member, '-d', str(dest)]).returncode != 0:
        return None
    exe = dest / Path(member).name
    os.chmod(exe, 0o755)
    target = exe.with_suffix('.pck')
    if not link:
        shutil.move(str(pck), target)
        return exe
    try:
        os.link(pck, target)
    except OSError:
        shutil.copyfile(pck, target)
    return exe


def run(cmd, log_path: Path, timeout: int, env=None, cwd=None):
    t0 = time.time()
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace',
                           timeout=timeout, env=env, cwd=cwd)
        out, code = p.stdout, p.returncode
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b'').decode('utf-8', 'replace') if isinstance(e.stdout, bytes) else (e.stdout or '')
        out += f'\n[导出冒烟] 超时 {timeout} 秒，已停\n'
        code = 124
    log_path.write_text(out, encoding='utf-8')
    return code, out, round(time.time() - t0, 1)


def smoke_scene(exe: Path, scene: str, out_dir: Path) -> dict:
    home = Path(tempfile.mkdtemp(prefix='xiyou_export_home_'))
    env = dict(os.environ, HOME=str(home))
    env.pop('XIYOU_TEST_FAST_FORWARD', None)
    args = [str(exe), '--headless', '--', '--verify-export']
    if scene != 'xiyou_mac_export':
        args.append('--verify-scene=' + scene)
    try:
        code, log, secs = run(args, out_dir / f'{scene}.log', TIMEOUT.get(scene, 600), env=env, cwd=str(home))
    finally:
        shutil.rmtree(home, ignore_errors=True)
    res = parse_result(log)
    ok = code == 0 and res is not None and res['total'] > 0 and res['passed'] == res['total']
    return {'scene': scene, 'ok': ok, 'exit': code, 'seconds': secs, 'result': res}


def runner_name() -> str:
    return 'Linux 调试模板' if os.environ.get('XIYOU_SMOKE_RUNNER') else 'macOS 调试模板'


def apk_sizes(infos) -> list:
    """apk 各部分占多少（压缩后）：[(部分, 压缩字节, 解开字节, 个数)]，大的在前。assets/.godot/imported 按源文件类型再分。"""
    import collections
    import re as _re
    packed, raw, count = collections.Counter(), collections.Counter(), collections.Counter()
    for i in infos:
        parts = i.filename.split('/')
        if i.filename.startswith('assets/.godot/imported/'):
            m = _re.match(r'.*\.([^.]+)-[0-9a-f]{32}\.([^.]+)$', parts[-1])
            key = 'assets/.godot/imported（%s→%s）' % (m.group(1).lower(), m.group(2)) if m else 'assets/.godot/imported（其它）'
        elif parts[0] == 'assets':
            key = '/'.join(parts[:2]) if len(parts) > 2 else 'assets（根）'
        else:
            key = parts[0] if len(parts) > 1 else '（根）'
        packed[key] += i.compress_size
        raw[key] += i.file_size
        count[key] += 1
    return [(k, v, raw[k], count[k]) for k, v in packed.most_common()]


def report(out_dir: Path, info: dict) -> Path:
    platform = info.get('platform', 'macos')
    windows = platform == 'windows'
    title = {'windows': '# Windows 导出冒烟报告', 'android': '# 安卓导出冒烟报告'}.get(platform, '# Mac 导出冒烟报告')
    lines = [title, '',
             f'- 时间：{info["time"]}；预设：{info["preset"]}；包：`{info["zip"]}`',
             f'- 工程提交：{info.get("commit", "?")}；Godot：{info.get("godot", "?")}',
             (f'- 架构：{info.get("archs", "?")}；包结构（PE 头、.pck、控制台包装）：{info.get("layout", "?")}；包内检查用 {runner_name()}旁放同名 .pck 跑' if windows else
              f'- 包名：{info.get("package", "?")}；架构：{info.get("archs", "?")}；签名与包结构（apksigner verify、aapt2）：{info.get("layout", "?")}；包内检查把 assets/ 打成 pck 放到 {runner_name()}旁跑' if platform == 'android' else
              f'- 架构：{info.get("archs", "?")}；签名检查（codesign --verify，只读）：{info.get("codesign", "?")}'),
             f'- 版本与图标：{info.get("versionText", "?")}',
             f'- 结论：**{"全部通过" if info["ok"] else "有失败"}**'] + ([f'- 留下的验收包（--keep）：`{info["keptApp"]}`'] if info.get('keptApp') else []) + ['',
             '| 项目 | 结果 | 断言 | 用时（秒） | 退出码 |', '| --- | --- | --- | --- | --- |']
    for r in info['scenes']:
        res = r['result']
        lines.append(f'| {r["scene"]} | {"通过" if r["ok"] else "失败"} | {f"{res["passed"]}/{res["total"]}" if res else "没有 TEST_RESULT"} | {r["seconds"]} | {r["exit"]} |')
    if info.get('sizes'):
        total = sum(x[1] for x in info['sizes']) or 1
        lines += ['', '## 包体积（压缩后，大的在前）', '', '| 部分 | 压缩后 MB | 占比 | 解开 MB | 个数 |', '| --- | --- | --- | --- | --- |']
        lines += [f'| {k} | {v / 2**20:.1f} | {100 * v / total:.1f}% | {u / 2**20:.1f} | {n} |' for k, v, u, n in info['sizes'][:15]]
    for r in info['scenes']:
        if r['result'] and r['result']['fails']:
            lines += ['', f'## {r["scene"]} 失败项', ''] + [f'- `{f}`' for f in r['result']['fails']]
    lines += ['', '各项完整输出在同目录 `<场景>.log`；导出日志 `导出.log`。',
              ('没覆盖的（要 Windows 实机）：exe 真在 Windows 上启动、DPI 缩放与全屏（Alt+Enter）、中文输入法、存档目录 %APPDATA%、杀毒误报、SmartScreen。' if windows else
               '没覆盖的（要安卓真机）：安装启动、触屏按键与两指取消、返回键、切后台与补跑、横屏与刘海、帧率与发热、ETC2／ASTC 贴图显示。' if platform == 'android' else
               '没覆盖的（要 Kyo 实机）：主观听音、Intel 实机、Developer ID 签名与公证、首次打开的 Gatekeeper，见 `00_项目管理/Mac实机验收清单.md`。')]
    p = out_dir / '报告.md'
    p.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (out_dir / '结果.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return p


def main_windows(a) -> int:
    preset = PRESETS['windows']
    stamp = time.strftime('%Y%m%d_%H%M%S')
    out_dir = Path(a.out) if a.out else ROOT / '04_验证' / '本地结果' / '导出冒烟' / (stamp + '_windows')
    out_dir.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='xiyou_export_smoke_'))
    info = {'time': stamp, 'platform': 'windows', 'preset': preset, 'scenes': [], 'ok': False}
    try:
        info['commit'] = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
        info['godot'] = (subprocess.run([str(GODOT), '--version'], capture_output=True, text=True).stdout.strip().splitlines()[-1:] or ['?'])[0]
        if a.zip:
            exe = Path(a.zip).resolve()
        else:
            exe = work / 'win' / '再刷重制_验收.exe'
            exe.parent.mkdir()
            print(f'== 导出「{preset}」（约 2～5 分钟）')
            code, _, secs = run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-debug', preset, str(exe)],
                                out_dir / '导出.log', 1800)
            if code != 0 or not exe.is_file():
                print(f'✗ 导出失败（退出码 {code}），见 {out_dir / "导出.log"}')
                return 2
            print(f'  导出完成 {secs} 秒，pck {exe.with_suffix(".pck").stat().st_size // (1 << 20) if exe.with_suffix(".pck").is_file() else 0} MB')
        info['zip'] = str(exe)
        problems, pe = windows_layout(exe)
        info['archs'] = pe['machine'] if pe else '?'
        info['versionText'] = f'FileVersion {pe.get("fileVersion")}、ProductVersion {pe.get("productVersion")}、图标{"有" if pe.get("icon") else "无"}' if pe else '?'
        info['layout'] = '通过' if not problems else '不通过：' + '；'.join(problems)
        print(f'  包结构：{info["layout"]}')
        pck = exe.with_suffix('.pck')
        runner = mac_runner(work, pck)
        if runner is None:
            print('✗ 找不到 macOS 调试模板，跑不了包内检查')
            return 2
        for scene in [s.strip() for s in a.scenes.split(',') if s.strip()]:
            print(f'== 包内跑 {scene}（macOS 调试模板＋{pck.name}）')
            r = smoke_scene(runner, scene, out_dir)
            info['scenes'].append(r)
            res = r['result']
            print(f'  {"✓" if r["ok"] else "✗"} {scene} {f"{res["passed"]}/{res["total"]}" if res else "没有 TEST_RESULT"}，{r["seconds"]} 秒')
        info['ok'] = bool(info['scenes']) and all(r['ok'] for r in info['scenes']) and not problems
        if a.keep and not a.zip:
            kept = out_dir / 'windows'
            shutil.move(str(exe.parent), kept)
            info['keptApp'] = str(kept)
            print(f'  留下 {kept}')
        p = report(out_dir, info)
        print(f'{"✓ 导出冒烟全部通过" if info["ok"] else "✗ 导出冒烟有失败"}；报告 {p}')
        return 0 if info['ok'] else 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main_android(a) -> int:
    preset = PRESETS['android']
    stamp = time.strftime('%Y%m%d_%H%M%S')
    out_dir = Path(a.out) if a.out else ROOT / '04_验证' / '本地结果' / '导出冒烟' / (stamp + '_android')
    out_dir.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='xiyou_export_smoke_'))
    info = {'time': stamp, 'platform': 'android', 'preset': preset, 'scenes': [], 'ok': False}
    try:
        info['commit'] = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
        info['godot'] = (subprocess.run([str(GODOT), '--version'], capture_output=True, text=True).stdout.strip().splitlines()[-1:] or ['?'])[0]
        if a.zip:
            apk = Path(a.zip).resolve()
        else:
            apk = work / '再刷重制_验收.apk'
            print(f'== 导出「{preset}」（约 2～5 分钟）')
            code, _, secs = run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-debug', preset, str(apk)],
                                out_dir / '导出.log', 1800)
            if code != 0 or not apk.is_file():
                print(f'✗ 导出失败（退出码 {code}），见 {out_dir / "导出.log"}')
                return 2
            print(f'  导出完成 {secs} 秒，{apk.stat().st_size // (1 << 20)} MB')
        info['zip'] = str(apk)
        import zipfile
        with zipfile.ZipFile(apk) as z:
            names = z.namelist()
            info['sizes'] = apk_sizes(z.infolist())
            info['apkBytes'] = apk.stat().st_size
            problems, pk = android_layout(apk, names)
            info['package'] = pk['package'] if pk else '?'
            info['archs'] = ','.join(pk['native']) if pk else '?'
            info['versionText'] = f'versionCode {pk.get("versionCode")}、versionName {pk.get("versionName")}、图标 {pk.get("icon")}' if pk else '?'
            info['layout'] = '通过' if not problems else '不通过：' + '；'.join(problems)
            print(f'  签名与包结构：{info["layout"]}')
            z.extractall(work / 'apk', [n for n in names if n.startswith('assets/')])
        # assets/ 原样打成真 pck（导出模板不认 zip 包和 --main-pack），用编辑器跑 打包pck.gd
        pck = work / 'assets.pck'
        empty = work / 'empty_project'
        empty.mkdir()
        (empty / 'project.godot').write_text('config_version=5\n', encoding='utf-8')
        code, log, secs = run([str(GODOT), '--headless', '--path', str(empty), '--script', str(HERE / '打包pck.gd'), '--',
                               str(work / 'apk' / 'assets'), str(pck)], out_dir / '打包pck.log', 900)
        shutil.rmtree(work / 'apk', ignore_errors=True)
        if code != 0 or not pck.is_file():
            print(f'✗ 把 apk 的 assets/ 打成 pck 失败（退出码 {code}），见 {out_dir / "打包pck.log"}')
            return 2
        print(f'  assets/ 打成 pck {secs} 秒')
        runner = mac_runner(work, pck, link=False)
        if runner is None:
            print('✗ 找不到 macOS 调试模板，跑不了包内检查')
            return 2
        for scene in [s.strip() for s in a.scenes.split(',') if s.strip()]:
            print(f'== 包内跑 {scene}（macOS 调试模板＋apk 的 assets/）')
            r = smoke_scene(runner, scene, out_dir)
            info['scenes'].append(r)
            res = r['result']
            print(f'  {"✓" if r["ok"] else "✗"} {scene} {f"{res["passed"]}/{res["total"]}" if res else "没有 TEST_RESULT"}，{r["seconds"]} 秒')
        info['ok'] = bool(info['scenes']) and all(r['ok'] for r in info['scenes']) and not problems
        if a.keep and not a.zip:
            kept = out_dir / apk.name
            shutil.move(str(apk), kept)
            info['keptApp'] = str(kept)
            print(f'  留下 {kept}')
        p = report(out_dir, info)
        print(f'{"✓ 导出冒烟全部通过" if info["ok"] else "✗ 导出冒烟有失败"}；报告 {p}')
        return 0 if info['ok'] else 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--zip', help='不导出，冒烟这个现成的包')
    ap.add_argument('--out', help='报告目录')
    ap.add_argument('--keep', action='store_true', help='留下解开的 .app 与导出的 zip')
    ap.add_argument('--scenes', default=','.join(SCENES))
    ap.add_argument('--platform', choices=sorted(PRESETS), default='macos')
    a = ap.parse_args(argv)
    if a.platform == 'windows':
        return main_windows(a)
    if a.platform == 'android':
        return main_android(a)
    stamp = time.strftime('%Y%m%d_%H%M%S')
    out_dir = Path(a.out) if a.out else ROOT / '04_验证' / '本地结果' / '导出冒烟' / stamp
    out_dir.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='xiyou_export_smoke_'))
    info = {'time': stamp, 'preset': PRESET, 'scenes': [], 'ok': False}
    try:
        info['commit'] = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
        info['godot'] = subprocess.run([str(GODOT), '--version'], capture_output=True, text=True).stdout.strip().splitlines()[-1:] or ['?']
        info['godot'] = info['godot'][0]
        if a.zip:
            zip_path = Path(a.zip).resolve()
        else:
            zip_path = work / '再刷重制_验收.zip'
            print(f'== 导出「{PRESET}」（约 2～5 分钟）')
            code, _, secs = run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-debug', PRESET, str(zip_path)],
                                out_dir / '导出.log', 1800)
            if code != 0 or not zip_path.is_file():
                print(f'✗ 导出失败（退出码 {code}），见 {out_dir / "导出.log"}')
                return 2
            print(f'  导出完成 {secs} 秒，{zip_path.stat().st_size // (1 << 20)} MB')
        info['zip'] = str(zip_path)
        app_dir = work / 'app'
        app_dir.mkdir()
        if subprocess.run(['ditto', '-x', '-k', str(zip_path), str(app_dir)]).returncode != 0:
            print('✗ 解包失败')
            return 2
        app, exe = find_app(app_dir)
        if exe is None:
            print('✗ 包里找不到 .app 或可执行文件')
            return 2
        info['archs'] = subprocess.run(['lipo', '-archs', str(exe)], capture_output=True, text=True).stdout.strip() or '?'
        cs = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], capture_output=True, text=True)
        info['codesign'] = '通过（ad-hoc）' if cs.returncode == 0 else '不通过：' + (cs.stderr.strip().splitlines() or ['?'])[-1]
        for scene in [s.strip() for s in a.scenes.split(',') if s.strip()]:
            print(f'== 包内跑 {scene}')
            r = smoke_scene(exe, scene, out_dir)
            info['scenes'].append(r)
            res = r['result']
            print(f'  {"✓" if r["ok"] else "✗"} {scene} {f"{res["passed"]}/{res["total"]}" if res else "没有 TEST_RESULT"}，{r["seconds"]} 秒')
        info['ok'] = bool(info['scenes']) and all(r['ok'] for r in info['scenes']) and cs.returncode == 0
        if a.keep:
            kept = out_dir / app.name
            shutil.move(str(app), kept)
            info['keptApp'] = str(kept)
            if not a.zip:
                shutil.move(str(zip_path), out_dir / zip_path.name)
            print(f'  留下 {kept}')
        p = report(out_dir, info)
        print(f'{"✓ 导出冒烟全部通过" if info["ok"] else "✗ 导出冒烟有失败"}；报告 {p}')
        return 0 if info['ok'] else 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
