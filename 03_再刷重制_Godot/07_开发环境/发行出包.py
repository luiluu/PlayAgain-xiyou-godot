#!/usr/bin/env python3
"""出包一条龙（cc 平台 EA 2026-11-06）：一条命令出三平台发行包，各跑发行入口冒烟，写校验和、体积表、发行说明，整理旧发行目录。

  python3 发行出包.py                  导出 → 冒烟 → SHA256SUMS.txt、体积.md、发行说明.txt → 冒烟全过就删掉旧发行目录
  python3 发行出包.py --no-smoke       不跑冒烟（只导包、写清单）
  python3 发行出包.py --notes-only     只重写当前发行目录的发行说明（不导包）
  python3 发行出包.py --notes-audit    列出会进发行说明、但没写「- 玩家可见：」行的变更记录条目（只读，出包前补）
  python3 发行出包.py --out <目录>     发行目录的上一级（默认主工作区 03_再刷重制_Godot/05_发布/导出包）
  python3 发行出包.py --dry-run        只打印会做什么
  python3 发行出包.py --keep-old       出完不删旧发行目录
  python3 发行出包.py --since <号>     发行说明从这个开发编号之后算（默认上一个发行目录的号）

产物：<上一级>/dev<号>_三平台发行/
  再刷一把_天启篇_mac.zip              macOS 发行（universal）
  再刷一把_天启篇_windows.zip          Windows 发行（exe＋pck 两个文件，Kyo 11-12 要 zip；文件名带 UTF-8 标记）
  windows/再刷一把_天启篇.exe、.pck     zip 的原料，冒烟用（--win-dir）
  再刷一把_天启篇_安卓.apk              安卓发行；发行 keystore 没配时用本机 Godot 调试 keystore 签（只能试装，不能上架）
  SHA256SUMS.txt、体积.md、冒烟.md、发行说明.txt
三个包都在这台 Mac 上导（Godot 在 Mac 上能直接导 Windows 和安卓，不用虚拟机）。不走云端：云端导入为了不超时去掉了 WebP 最高档，
包会大约 150 MB；下载包要把完整游戏包作公开附件；云端每次现生成的调试 keystore 跟本机签名不同，手机上不能覆盖安装。
冒烟：Mac `--keys` 和 `--arch x86_64 --keys`；Windows `--win-dir --keys`（macOS 发行模板当替身）；安卓 `--apk --keys`（静态检查＋替身）。
旧发行目录：新包导出成功、冒烟全过后，dev*_三平台发行 只留本次这一个，号更小的目录和以前压的同名 .zip 直接删
（Kyo 11-06「直接删」，平台 EC；原来是留两个、其余压 zip）。导出或冒烟失败时不删，旧包还能用。号比本次大的、别的备份不碰。
发行说明：变更记录里「上一个发行目录的号 < dev 号 ≤ 本号」的条目，去掉工具／流程／审查类，标题去掉内部编号、路径、掉率后一条一行。
条目正文里有「- 玩家可见：……」的行时用那一行代替标题（没有就用标题）。
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import zipfile

HERE = Path(__file__).resolve().parent
REMAKE = HERE.parent
ROOT = REMAKE.parent
PROJECT = REMAKE / '01_Godot工程'
GODOT = Path(os.environ.get('XIYOU_GODOT') or HERE / 'godot')
SMOKE = HERE / '发行入口冒烟.py'
CHANGELOG = ROOT / '00_项目管理' / '变更记录.md'
APP_NAME = '再刷一把：天启篇'
DIR_RE = re.compile(r'^dev(\d+)_三平台发行$')
MAC_ZIP = '再刷一把_天启篇_mac.zip'
WIN_DIR = 'windows'
WIN_FILES = ('再刷一把_天启篇.exe', '再刷一把_天启篇.pck')
WIN_ZIP = '再刷一把_天启篇_windows.zip'
ZIP_UTF8 = 0x800  # 通用标志第 11 位：文件名是 UTF-8（Windows 资源管理器据此不把中文名解成乱码）
APK = '再刷一把_天启篇_安卓.apk'

# 发行说明：标题里有这些词的条目算内部（工具、流程、审查、记录），不进玩家看的说明
INTERNAL_WORDS = ('工具', '云端', '检查', '探针', '测试', '冒烟', '交付', '进度账', '审查', '核查', '选测', '合并', '扫描',
                  '规则', '交接', '同步', '车道', '派单', '积压', '记录', '扩展账', '基线', '清单', '验收', '导出', '出包',
                  '补齐', '工作树', '编号', '版本号', '提速', '缓存', '签名', '公证', '盘点', '参照', '转换器', '回归', '门禁',
                  '对照', '覆盖', '变体', '专项', '预设', '量具', '调查', '估算', '核实', '查清', '写法', '实测', '钩子', '报告',
                  '下标', '--', '偶发', '修稳', '换源', '更正', '连通性', '切片', '死代码', '逐张比')
# 去掉的内部写法：优化登记号、开发编号、地图／事件号、开关／变量／状态号、代码与路径、百分比概率
SCRUB = [
    (re.compile(r'（[^（）]*\b(?:O|dev)[-.]\S*?[^（）]*）'), ''),
    (re.compile(r'\((?:dev|O)[-.][^()]*\)'), ''),
    (re.compile(r'`[^`]*`'), ''),
    (re.compile(r'\b(?:O-\d+|O-待定|dev\.\d+|dev\.待定)\b'), ''),
    (re.compile(r'(?:\bMap\d+\s*[、，,]?\s*)+的'), '部分地图的'),  # 「Map152、Map032 的并行事件」去号后别只剩「的…」
    (re.compile(r'\b(?:Map|EV|ce|CE|m)\d+\S*'), ''),
    (re.compile(r'(?:开关|变量|状态|技能|物品|敌群)\s*\d+'), ''),
    (re.compile(r'\S+\.(?:gd|py|json|tscn|cfg|md|sh)\b'), ''),
    (re.compile(r'[A-Za-z0-9_.\-]+/[A-Za-z0-9_./\-]*'), ''),
]
RATE_RE = re.compile(r'掉率|掉落率|概率|\d+(?:\.\d+)?\s*[%％]')


def main_root() -> Path:
    """主工作区根（发行目录放在那里，不随工作树清理掉）。"""
    try:
        common = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute', '--git-common-dir'],
                                capture_output=True, text=True, check=True).stdout.strip()
        return Path(common).parent
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ROOT


def dev_number() -> int:
    info = json.loads((PROJECT / 'content' / 'build_info.json').read_text(encoding='utf-8'))
    m = re.fullmatch(r'dev\.(\d+)', str(info.get('developmentVersion', '')))
    if not m:
        raise SystemExit('build_info.json 里没有 dev.<号>')
    return int(m.group(1))


def release_dirs(parent: Path) -> list:
    """[(号, 目录)]，号从小到大。"""
    out = []
    if parent.is_dir():
        for p in parent.iterdir():
            m = DIR_RE.match(p.name)
            if m and p.is_dir():
                out.append((int(m.group(1)), p))
    return sorted(out)


# ---- 发行说明 ----

def entries(text: str) -> list:
    """变更记录 → [(dev 号或 None, 标题, 正文)]。"""
    out = []
    parts = re.split(r'^## ', text, flags=re.M)[1:]
    for part in parts:
        head, _, body = part.partition('\n')
        m = re.search(r'dev\.(\d+)', head)
        out.append((int(m.group(1)) if m else None, head.strip(), body))
    return out


def player_line(title: str, body: str):
    """一条变更记录 → 玩家看的一句话；内部条目返回 None。"""
    m = re.search(r'^- 玩家可见[：:]\s*(.+)$', body, re.M)
    if m:
        text = m.group(1)
        if re.match(r'无(?:[（(：:，,。.；;]|明显|\s*$)', text):
            return None  # 「无（只加测试）」「无明显变化」：玩家看不到，不进说明
    else:
        t = re.sub(r'^\d{4}-\d{2}-\d{2}\s*', '', title)
        t = re.sub(r'【[^】]*】', '', t)
        if any(w in t for w in INTERNAL_WORDS):
            return None
        text = t
    for pat, rep in SCRUB:
        text = pat.sub(rep, text)
    # 掉率之类的分句整句去掉
    parts = re.split(r'([；;，,])', text)
    text = ''.join(s + sep for s, sep in zip(parts[::2], parts[1::2] + ['']) if not RATE_RE.search(s))
    text = re.sub(r'\s+', ' ', text).strip(' ：:，,；;、。')
    text = re.sub(r'\s*([：，；、。「」（）])\s*', r'\1', text)
    text = re.sub(r'（\s*）|\(\s*\)', '', text).strip()
    return text or None


def release_notes(text: str, since: int, upto: int) -> list:
    lines = []
    for dev, title, body in entries(text):
        if dev is None or not since < dev <= upto:
            continue
        line = player_line(title, body)
        if line and line not in lines:
            lines.append(line)
    return lines


def notes_audit(text: str, since: int, upto: int) -> list:
    """本次会进发行说明、但没写「- 玩家可见：」行（说明里用的是标题凑的句子）的条目：[(dev 号, 标题, 凑出来的句子)]。"""
    out = []
    for dev, title, body in entries(text):
        if dev is None or not since < dev <= upto or re.search(r'^- 玩家可见[：:]', body, re.M):
            continue
        line = player_line(title, body)
        if line:
            out.append((dev, title, line))
    return out


def notes_text(dev: int, since: int, lines: list) -> str:
    out = [f'{APP_NAME}  0.{dev}', '',
           f'这一版的改动（上一个发行包是 0.{since}）：' if since else '这一版的改动：', '']
    out += [f'・{l}' for l in lines] if lines else ['・没有玩家能看到的改动（这一版只改了内部工具和流程）。']
    out += ['', '安装：', '・Mac：解开 再刷一把_天启篇_mac.zip，把「再刷一把：天启篇」拖进「应用程序」。',
            f'・Windows：解开 {WIN_ZIP}，里面的 再刷一把_天启篇.exe 和 .pck 留在同一个文件夹里，双击 exe。',
            '・安卓：装 再刷一把_天启篇_安卓.apk；这个包是测试签名，只能自己装着试，不是商店版。',
            '・不会自动搬原版的存档，原版可以照常接着玩。', '']
    return '\n'.join(out)


# ---- 导出、冒烟、清单 ----

def run(cmd, log: Path, env=None, timeout=1800) -> int:
    t = time.time()
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', env=env, timeout=timeout)
    log.write_text(p.stdout, encoding='utf-8')
    print(f'  {time.time() - t:.0f} 秒，退出码 {p.returncode}（日志 {log.name}）')
    return p.returncode


def android_env():
    env = dict(os.environ)
    if env.get('GODOT_ANDROID_KEYSTORE_RELEASE_PATH'):
        return env, '发行 keystore（环境变量）'
    sys.path.insert(0, str(HERE))
    import importlib.util
    spec = importlib.util.spec_from_file_location('发行入口冒烟', SMOKE)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    ks, pw = m.editor_debug_keystore()
    if ks is None:
        return None, '没有'
    env.update(GODOT_ANDROID_KEYSTORE_RELEASE_PATH=ks, GODOT_ANDROID_KEYSTORE_RELEASE_USER='androiddebugkey',
               GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=pw)
    return env, '本机 Godot 调试 keystore（只能试装，不能上架）'


def export_all(out: Path, logs: Path) -> list:
    problems = []
    print('== 导出 macOS 发行')
    if run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-release', 'macOS 发行', str(out / MAC_ZIP)], logs / '导出_mac.log') or not (out / MAC_ZIP).is_file():
        problems.append('macOS 导出失败')
    print('== 导出 Windows 发行')
    (out / WIN_DIR).mkdir(exist_ok=True)
    if run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-release', 'Windows 发行', str(out / WIN_DIR / WIN_FILES[0])], logs / '导出_windows.log') \
            or not all((out / WIN_DIR / f).is_file() for f in WIN_FILES):
        problems.append('Windows 导出失败')
    else:
        win_zip(out)
    print('== 导出 安卓 发行')
    env, how = android_env()
    if env is None:
        problems.append('安卓：没配发行 keystore，本机也找不到 Godot 调试 keystore')
    else:
        print(f'  签名：{how}')
        if run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-release', '安卓 发行', str(out / APK)], logs / '导出_安卓.log', env=env) \
                or not (out / APK).is_file():
            problems.append('安卓导出失败')
        idsig = out / (APK + '.idsig')
        if idsig.exists():
            idsig.unlink()  # 只给 adb 增量安装用，玩家用不着
    return problems


def audit_unreleased(out: Path) -> list:
    """发行内容审计（11-13 漩涡异化设计稿外泄后加）：三个包里不许有没发行的内容，有就不往下走。"""
    spec = importlib.util.spec_from_file_location('发行内容审计', HERE / '发行内容审计.py')
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    problems = []
    for pkg in (out / WIN_DIR / WIN_FILES[1], out / APK, out / MAC_ZIP):
        if not pkg.is_file():
            continue
        bad = m.audit(pkg)
        if bad:
            problems.append(f'{pkg.name} 带了 {len(bad)} 个没发行的文件（{"、".join(bad[:5])}…）；看 export_presets.cfg 发行预设的 exclude_filter')
    print('== 发行内容审计：' + ('有问题' if problems else '通过'))
    return problems


SMOKES = [
    ('Mac', lambda out: ['--zip', str(out / MAC_ZIP), '--keys']),
    ('Mac x86_64', lambda out: ['--zip', str(out / MAC_ZIP), '--arch', 'x86_64', '--keys']),
    ('Windows', lambda out: ['--platform', 'windows', '--win-dir', str(out / WIN_DIR), '--keys']),
    ('安卓', lambda out: ['--platform', 'android', '--apk', str(out / APK), '--keys']),
]


def smoke_all(out: Path, logs: Path) -> list:
    rows = []
    for name, args in SMOKES:
        print(f'== 冒烟 {name}')
        log = logs / f'冒烟_{name}.log'
        rc = run([sys.executable, str(SMOKE), *args(out)], log, timeout=3600)
        text = log.read_text(encoding='utf-8')
        verdict = ([l for l in text.splitlines() if l.startswith('结论：')] or ['结论：没有结论行'])[-1]
        note = [l for l in text.splitlines() if l.startswith('没有在跑的安卓模拟器')]
        note += [l.split('（', 1)[1].rstrip('）') for l in text.splitlines() if l.startswith(('INFO startup_time', 'WARN startup_time'))]
        rows.append((name, rc == 0, verdict.split('；')[0].removeprefix('结论：') + ''.join('；' + n for n in note)))
    return rows


def win_zip(out: Path) -> Path:
    """把 windows/ 里的 exe、pck 打成 再刷一把_天启篇_windows.zip（只放这两个文件、不带目录；文件名标 UTF-8）。"""
    z = out / WIN_ZIP
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        for name in WIN_FILES:
            src = out / WIN_DIR / name
            info = zipfile.ZipInfo.from_file(src, name)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.flag_bits |= ZIP_UTF8
            with src.open('rb') as fin, zf.open(info, 'w', force_zip64=True) as fout:
                shutil.copyfileobj(fin, fout, 1 << 20)
    print(f'  打包 {WIN_ZIP}：{z.stat().st_size / 1e6:.1f} MB')
    return z


def package_files(out: Path) -> list:
    return [p for p in [out / MAC_ZIP, out / WIN_ZIP, *(out / WIN_DIR / f for f in WIN_FILES), out / APK] if p.is_file()]


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def sizes(out: Path) -> dict:
    """平台 → 字节（Windows 是 exe＋pck，Windows zip 是发给玩家的压缩包）。"""
    d = {}
    if (out / MAC_ZIP).is_file():
        d['macOS'] = (out / MAC_ZIP).stat().st_size
    if all((out / WIN_DIR / f).is_file() for f in WIN_FILES):
        d['Windows'] = sum((out / WIN_DIR / f).stat().st_size for f in WIN_FILES)
    if (out / WIN_ZIP).is_file():
        d['Windows zip'] = (out / WIN_ZIP).stat().st_size
    if (out / APK).is_file():
        d['安卓'] = (out / APK).stat().st_size
    return d


def size_table(dev: int, now: dict, prev_dev, prev: dict) -> str:
    mb = lambda b: f'{b / 1e6:.1f} MB'
    lines = [f'# 体积（0.{dev}）', '', f'| 包 | 本次 | 上一版{f"（0.{prev_dev}）" if prev_dev else ""} | 差 |', '| --- | --- | --- | --- |']
    for k, v in now.items():
        p = prev.get(k)
        lines.append(f'| {k} | {mb(v)} | {mb(p) if p else "—"} | {(("+" if v >= p else "−") + mb(abs(v - p))) if p else "—"} |')
    return '\n'.join(lines) + '\n'


def tidy_old(parent: Path, current: int, dry=False) -> list:
    """删掉号比 current 小的旧发行目录和它们以前压的同名 .zip（只留最新一版），返回删了的路径。dry 只列不删。"""
    gone = []
    for n, d in release_dirs(parent):
        if n >= current:
            continue
        for t in (d, d.with_name(d.name + '.zip')):
            if not t.exists():
                continue
            if not dry:
                if t.is_dir() and not t.is_symlink():
                    shutil.rmtree(t)
                else:
                    t.unlink()
            gone.append(t)
    # 只剩 zip、目录已经不在的旧版（以前的做法留下的）
    for z in parent.glob('dev*_三平台发行.zip') if parent.is_dir() else []:
        m = DIR_RE.match(z.name[:-4])
        if m and int(m.group(1)) < current and z not in gone:
            if not dry:
                z.unlink()
            gone.append(z)
    return gone


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', help='发行目录的上一级')
    ap.add_argument('--no-smoke', action='store_true')
    ap.add_argument('--notes-only', action='store_true')
    ap.add_argument('--notes-audit', action='store_true', help='列出会进说明但没写「- 玩家可见：」行的条目')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--keep-old', action='store_true', help='出完不删旧发行目录')
    ap.add_argument('--since', type=int, help='发行说明从哪个开发编号之后算起（默认上一个发行目录的号）')
    a = ap.parse_args(argv)
    parent = Path(a.out).resolve() if a.out else main_root() / '03_再刷重制_Godot' / '05_发布' / '导出包'
    dev = dev_number()
    out = parent / f'dev{dev}_三平台发行'
    older = [(n, d) for n, d in release_dirs(parent) if n < dev]
    prev_dev, prev_dir = older[-1] if older else (None, None)
    print(f'本次 0.{dev} → {out}；上一个发行目录：{prev_dir or "无"}')
    if a.dry_run:
        print(f'会导出：macOS 发行、Windows 发行（另打 {WIN_ZIP}）、安卓 发行；' + ('不跑冒烟' if a.no_smoke else '冒烟：' + '、'.join(n for n, _ in SMOKES)))
        for t in ([] if a.keep_old else tidy_old(parent, dev, dry=True)):
            print(f'冒烟全过后会删旧发行：{t.name}')
        return 0
    since = a.since if a.since is not None else (prev_dev or 0)
    notes = notes_text(dev, since, release_notes(CHANGELOG.read_text(encoding='utf-8'), since, dev))
    if a.notes_audit:
        rows = notes_audit(CHANGELOG.read_text(encoding='utf-8'), since, dev)
        print(f'0.{since} 之后到 0.{dev}：会进发行说明、没写「- 玩家可见：」的条目 {len(rows)} 条' + ('（都写了）' if not rows else '：'))
        for n, title, line in rows:
            print(f'  dev.{n}  {title}\n      现在会写成：{line}')
        return 0
    if a.notes_only:
        out.mkdir(parents=True, exist_ok=True)
        (out / '发行说明.txt').write_text(notes, encoding='utf-8')
        print(notes)
        return 0
    # 贴图缓存不全会导出默认档或缺图的包：先确认（整轮重导入用 新建工作树.sh --补齐，它会走长任务）
    sys.path.insert(0, str(HERE))
    import importlib.util
    spec = importlib.util.spec_from_file_location('导入超时', HERE / '导入超时.py')
    imp = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(imp)
    mode, missing, total = imp.classify(PROJECT)
    if missing:
        print(f'✗ 贴图缓存缺 {missing}/{total} 张，先 godot --import（缺得多就 新建工作树.sh --补齐）再出包')
        return 2
    if out.exists():
        print(f'✗ {out} 已经有了：要重出就先把它挪走（不覆盖已有的发行包）')
        return 2
    out.mkdir(parents=True)
    logs = out / '日志'
    logs.mkdir()
    problems = export_all(out, logs)
    if not problems:
        problems = audit_unreleased(out)
    if problems:
        print('✗ ' + '；'.join(problems))
        return 1
    rows = [] if a.no_smoke else smoke_all(out, logs)
    files = package_files(out)
    (out / 'SHA256SUMS.txt').write_text(''.join(f'{sha256(f)}  {f.relative_to(out)}\n' for f in files), encoding='utf-8')
    now = sizes(out)
    (out / '体积.md').write_text(size_table(dev, now, prev_dev, sizes(prev_dir) if prev_dir else {}), encoding='utf-8')
    smoke_md = ['# 冒烟', '', '| 包 | 结果 | 说明 |', '| --- | --- | --- |'] + [f'| {n} | {"通过" if ok else "失败"} | {v} |' for n, ok, v in rows]
    (out / '冒烟.md').write_text('\n'.join(smoke_md if rows else ['# 冒烟', '', '没跑（--no-smoke）']) + '\n', encoding='utf-8')
    (out / '发行说明.txt').write_text(notes, encoding='utf-8')
    print((out / '体积.md').read_text(encoding='utf-8'))
    print('\n'.join(smoke_md))
    ok = all(r[1] for r in rows)
    if a.keep_old:
        print('--keep-old：旧发行目录没删')
    elif not rows:
        print('没跑冒烟（--no-smoke）：旧发行目录没删')
    elif not ok:
        print('冒烟有失败：旧发行目录留着没删')
    else:
        for t in tidy_old(parent, dev):
            print(f'删掉旧发行：{t.name}')
    print(f'结论：{"通过" if ok else "冒烟有失败"}；发行目录 {out}')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
