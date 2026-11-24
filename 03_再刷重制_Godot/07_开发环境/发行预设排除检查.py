#!/usr/bin/env python3
"""发行预设排除检查（T458，cc 2026-11-24）：发行预设的 exclude_filter 不许把发行包要跑的脚本踢出包。

起因：dev.887 的 export_presets.cfg 三个发行预设带 `modes/xiyou/ui/tianqi/*`，把空壳 tianqi_hall_intro.gd（XTianqiHallIntro）
踢出 PCK，发行包一开就 SCRIPT ERROR，冒烟只看退出码报了绿（T424）。

  python3 发行预设排除检查.py                         查本工作树的 01_Godot工程/export_presets.cfg
  python3 发行预设排除检查.py --rev ad238e50e         查某个提交：预设和脚本／场景都取那个提交的（git archive 解到临时目录）
  python3 发行预设排除检查.py --presets <cfg> [--root <工程或空壳树>]

查谁（都不算 tests/、.godot/）：
  - 空壳：发行空壳.py targets() 要换成空壳的脚本（换了壳照样要进包，西游代码按类名调它们）
  - KEEP：发行空壳.KEEP 里带真脚本进包的类
  - class_name：其余所有带 class_name 的 .gd（全局类表里有它，包里缺了就 Failed to load script）
  - 脚本：其余所有 .gd（跟 T457 测试导出过滤.py 的「非测试脚本不许踢」同一口径；场景 .tscn 只认被引用的）
  - 被引用：project.godot 的主场景与自动加载，以及进包的 .gd／.tscn 里写死的 res://….gd／.tscn／.scn（preload、load、ext_resource）
只认脚本和场景；png、json 之类资源被排除不报（天启篇美术、数据本来就该排除）。
匹配照 Godot 导出（EditorExportPlatform::_edit_files_with_filter）：规则按逗号分开、去空白，跟 `res://<路径>` 或 `<路径>` 比，
不分大小写，`*` 跨目录、`?` 一个字符。
退出码：0 没有被排除的；1 有，逐条列出「文件、哪个预设、命中哪条规则、为什么要进包」；2 读不到预设或发行预设不是三个。
"""
import argparse
import importlib.util
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
PRESETS_REL = '03_再刷重制_Godot/01_Godot工程/export_presets.cfg'
RELEASE_PRESETS = ('macOS 发行', 'Windows 发行', '安卓 发行')
SKIP_DIRS = ('tests/', '.godot/', 'builds/')
SCRIPT_EXT = ('.gd', '.tscn', '.scn')
CLASS_RE = re.compile(r'^class_name (\w+)\b', re.M)
REF_RE = re.compile(r'res://([^"\'\s)\]]+\.(?:gd|tscn|scn))\b')


def _stub_mod():
    spec = importlib.util.spec_from_file_location('发行空壳', HERE / '发行空壳.py')
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def parse_presets(text: str) -> dict:
    """export_presets.cfg → {预设名: [exclude 规则]}（只看 [preset.N] 段，不看 .options）。"""
    out, name, filt, in_preset = {}, None, None, False

    def flush():
        if in_preset and name is not None:
            out[name] = filt or []

    for raw in text.splitlines():
        ln = raw.strip()
        if ln.startswith('['):
            flush()
            in_preset = re.fullmatch(r'\[preset\.\d+\]', ln) is not None
            name, filt = None, None
            continue
        if not in_preset or '=' not in ln:
            continue
        k, v = ln.split('=', 1)
        v = v.strip()
        if v.startswith('"') and v.endswith('"'):
            v = v[1:-1]
        if k.strip() == 'name':
            name = v
        elif k.strip() == 'exclude_filter':
            filt = [f.strip() for f in v.split(',') if f.strip()]
    flush()
    return out


def _glob_re(pattern: str):
    parts = []
    for ch in pattern:
        parts.append('.*' if ch == '*' else '.' if ch == '?' else re.escape(ch))
    return re.compile(''.join(parts), re.I | re.S)


def matching_rule(rel: str, rules: list):
    """rel（相对工程、用 /）被哪条规则排除；没有返回 None。"""
    for r in rules:
        rx = _glob_re(r)
        if rx.fullmatch('res://' + rel) or rx.fullmatch(rel):
            return r
    return None


def _skipped(rel: str) -> bool:
    return rel.startswith(SKIP_DIRS) or '/.' in '/' + rel


def must_ship(root: Path, stub=None) -> dict:
    """发行包里必须有的脚本／场景：相对路径 → 为什么（空壳／KEEP／class_name／被引用：谁引用）。"""
    stub = stub or _stub_mod()
    need = {}
    for cls, p in stub.targets(root).items():
        need[str(p).replace('\\', '/')] = f'空壳 {cls}'
    shipped_src = []
    for p in sorted(root.rglob('*')):
        if not p.is_file() or p.suffix not in SCRIPT_EXT:
            continue
        rel = p.relative_to(root).as_posix()
        if _skipped(rel):
            continue
        shipped_src.append((rel, p))
        if p.suffix != '.gd':
            continue
        m = CLASS_RE.search(p.read_text(encoding='utf-8', errors='replace'))
        if rel not in need:
            need[rel] = (f'KEEP {m.group(1)}' if m and m.group(1) in stub.KEEP else f'class_name {m.group(1)}' if m else '脚本')
    pg = root / 'project.godot'
    if pg.is_file():
        for ref in REF_RE.findall(pg.read_text(encoding='utf-8', errors='replace')):
            if need.get(ref, '脚本') == '脚本':
                need[ref] = 'project.godot（主场景／自动加载）'
    for rel, p in shipped_src:
        for ref in REF_RE.findall(p.read_text(encoding='utf-8', errors='replace')):
            if not _skipped(ref) and (root / ref).is_file() and need.get(ref, '脚本') == '脚本':
                need[ref] = f'被引用：{rel}'
    return need


def check(presets_text: str, root: Path = PROJECT, stub=None) -> tuple:
    """返回 (问题行, 查了几个文件)。问题行为空＝通过。"""
    presets = parse_presets(presets_text)
    missing = [n for n in RELEASE_PRESETS if n not in presets]
    if missing:
        raise ValueError('export_presets.cfg 里没有发行预设：' + '、'.join(missing))
    need = must_ship(root, stub)
    probs = []
    for rel in sorted(need):
        for name in RELEASE_PRESETS:
            r = matching_rule(rel, presets[name])
            if r:
                probs.append(f'{rel}｜{name}｜命中 {r}｜{need[rel]}')
    return probs, len(need)


def extract_rev(rev: str, dest: Path) -> Path:
    """把提交 rev 的工程里的脚本、场景、project.godot、export_presets.cfg 解到 dest，返回工程目录。"""
    top = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=HERE, capture_output=True, text=True).stdout.strip() or str(HERE)
    proj = PRESETS_REL.rsplit('/', 1)[0]
    ls = subprocess.run(['git', 'ls-tree', '-r', '--name-only', rev, '--', proj], cwd=top, capture_output=True, text=True)
    if ls.returncode:
        raise ValueError(f'git ls-tree {rev} 失败：{ls.stderr.strip()}')
    want = [f for f in ls.stdout.splitlines() if f.endswith(SCRIPT_EXT) or f in (f'{proj}/project.godot', PRESETS_REL)]
    if PRESETS_REL not in want:
        raise ValueError(f'{rev} 里没有 {PRESETS_REL}')
    cat = subprocess.run(['git', 'cat-file', '--batch'], cwd=top, input=''.join(f'{rev}:{f}\n' for f in want).encode('utf-8'), capture_output=True)
    if cat.returncode:
        raise ValueError('git cat-file 失败：' + cat.stderr.decode('utf-8', 'replace').strip())
    buf, i = cat.stdout, 0
    for f in want:
        j = buf.index(b'\n', i)
        head = buf[i:j].split()
        if len(head) < 3 or head[1] != b'blob':
            raise ValueError(f'读不到 {rev}:{f}')
        n = int(head[2])
        out = dest / f
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(buf[j + 1:j + 1 + n])
        i = j + 1 + n + 1
    return dest / proj


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--presets', help='export_presets.cfg 路径（默认 --root 下的）')
    ap.add_argument('--rev', help='改读某个提交里的 export_presets.cfg')
    ap.add_argument('--root', help='工程或空壳树目录（默认本工作树工程）')
    a = ap.parse_args(argv)
    root = Path(a.root).resolve() if a.root else PROJECT
    try:
        with tempfile.TemporaryDirectory(prefix='presets_rev_') as tmp:
            if a.rev:
                root = extract_rev(a.rev, Path(tmp))
                text, src = (root / 'export_presets.cfg').read_text(encoding='utf-8'), f'{a.rev}:export_presets.cfg'
            else:
                f = Path(a.presets) if a.presets else root / 'export_presets.cfg'
                text, src = f.read_text(encoding='utf-8'), str(f)
            probs, n = check(text, root)
    except (OSError, ValueError) as e:
        print(f'✗ 发行预设排除检查：{e}')
        return 2
    if probs:
        print(f'✗ 发行预设排除检查：{src} 的 exclude_filter 把 {len({p.split("｜")[0] for p in probs})} 个要进包的脚本／场景踢出了发行包'
              '（文件｜预设｜规则｜为什么要进包）：')
        for p in probs:
            print('  ' + p)
        print('  改法：缩窄那条规则（只排除资源，如 *.png），或把脚本挪出被排除的目录')
        return 1
    print(f'发行预设排除检查通过：{n} 个要进包的脚本／场景 × {len(RELEASE_PRESETS)} 个发行预设，没有被排除（{src}）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
