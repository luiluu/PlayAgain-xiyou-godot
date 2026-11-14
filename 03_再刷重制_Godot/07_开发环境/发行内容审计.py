#!/usr/bin/env python3
"""发行内容审计（cc 2026-11-13，漩涡异化设计稿外泄之后加）：没发行的内容不许进玩家手里的包和补丁。

v0.01.05 补丁（0.475）和 v0.01.06 整包（dev476）都带出了 rift_alien.json（漩涡五阶段异化的设计数值），
整包还带出了 tianqi_data/ 下的天启篇数值表。原因是发行预设是「全部资源＋所有 json」，只排除了几项。

这里是「哪些不许进发行包」的唯一名单（DENY，Godot 过滤写法：* 和 ?，不分大小写，* 跨目录）：
  - 发行预设（Windows／安卓／macOS 发行）的 exclude_filter 必须盖住 DENY，测试导出过滤.py 查；
  - 发行出包.py 导完三平台、发布补丁.py 导完补丁，都用 audit() 把包里的文件名单逐条过 DENY，有一条就停。
新加一类没发行的内容（天启篇新数据目录、新设计数值表、新美术目录）：加进 DENY，再把同样的写法加进三个发行预设。
对玩家开放时从 DENY 和预设里一起删掉。

天启篇脚本（发行空壳.targets：XTianqi*、XRiftAlien 和 EXTRA 名单）在包里必须是空壳
（11-14 以前出的包里的空壳没有这个标记，会被报成真脚本；审旧包看体积和字符串常量，别用这个）（cc 11-14 release-stub-gojo，XGojo 曾漏在名单外）：
审计把包里这些脚本的 .gdc 解开（zstd），找空壳编进去的标记字符串 发行空壳.STUB_TAG；找不到就是真脚本进包了，算违规。

  python3 发行内容审计.py <包>…        包可以是 .pck、带内嵌 pck 的 .exe、.apk、mac 的 .zip；有违规退出 1
  python3 发行内容审计.py --tree <工程>  出包前查源工程（发行空壳 tree 的产物）：天启篇脚本都换成空壳、没有没归类的天启篇脚本
"""
import fnmatch
import importlib.util
from pathlib import Path
import re
import struct
import sys
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent

# 还没发行的内容（Kyo 11-12：天启篇只在本地；漩涡三阶起的异化没开放）
DENY = [
    'modes/xiyou/tianqi_data/*',      # 天启篇全部数值表、词条、四线、七印、技能重构
    'content/tianqi/*',               # 天启篇美术（骑士、七印）
    'content/gojo/*',                 # 五条悟（只进天启篇）
    'modes/xiyou/rift_alien.json',    # 漩涡五阶段怪物异化设计数值
    'modes/xiyou/ui/tianqi/*',        # 天启篇五档难度徽章
]
RELEASE_PRESETS = ('Windows 发行', '安卓 发行', 'macOS 发行')


def denied(path: str) -> bool:
    p = path.lower().removeprefix('res://').lstrip('/')
    if p.startswith('assets/'):
        p = p[len('assets/'):]
    # 导出后脚本是 .gdc／.gd.remap、贴图是 .png.import＋.godot/imported/…；名单按源路径写，这里把常见后缀剥掉再比
    return any(fnmatch.fnmatchcase(p, d.lower()) or fnmatch.fnmatchcase(p.rsplit('.', 1)[0], d.lower()) for d in DENY)


# ---- 读包里的文件名单 ----

def _pck_names(f, base: int) -> list:
    return list(_pck_entries(f, base))


def _pck_entries(f, base: int) -> dict:
    """pck 目录：文件名 → (绝对偏移, 长度)。"""
    f.seek(base)
    if f.read(4) != b'GDPC':
        raise ValueError('不是 Godot pck')
    ver, _maj, _min, _pat, flags, fbase = struct.unpack('<IIIIIQ', f.read(28))
    if flags & 1:
        raise ValueError('pck 目录加密了，读不了名单（加密包要换法子审）')
    if ver >= 3:
        diroff, = struct.unpack('<Q', f.read(8))
        f.seek(base + diroff)
    else:
        f.read(64)
    n, = struct.unpack('<I', f.read(4))
    out = {}
    for _ in range(n):
        ln, = struct.unpack('<I', f.read(4))
        name = f.read(ln).rstrip(b'\0').decode('utf-8', 'replace')
        ofs, size = struct.unpack('<QQ', f.read(16))
        f.read(16 + (4 if ver >= 2 else 0))
        out[name.removeprefix('res://')] = (base + fbase + ofs if ver >= 2 else ofs, size)
    return out


def _pck_base(f, path: Path) -> int:
    f.seek(0)
    if f.read(4) == b'GDPC':
        return 0
    f.seek(-12, 2)  # 内嵌在 exe 末尾：…pck…［8 字节 pck 长度］GDPC
    size, = struct.unpack('<Q', f.read(8))
    if f.read(4) != b'GDPC':
        raise ValueError(f'{Path(path).name} 里找不到 pck')
    f.seek(-12 - size, 2)
    return f.tell()


def pck_names(path: Path) -> list:
    with open(path, 'rb') as f:
        return _pck_names(f, _pck_base(f, path))


def _pck_read(path: Path, want) -> dict:
    with open(path, 'rb') as f:
        ents = _pck_entries(f, _pck_base(f, path))
        out = {}
        for n, (ofs, size) in ents.items():
            if want(n):
                f.seek(ofs)
                out[n] = f.read(size)
        return out


def read_files(path: Path, want) -> dict:
    """包里名字满足 want(源路径写法) 的文件内容：名字 → bytes。"""
    path = Path(path)
    suf = path.suffix.lower()
    if suf == '.apk':
        with zipfile.ZipFile(path) as z:
            return {n[len('assets/'):]: z.read(n) for n in z.namelist() if n.startswith('assets/') and want(n[len('assets/'):])}
    if suf == '.zip':
        out = {}
        with zipfile.ZipFile(path) as z, tempfile.TemporaryDirectory() as td:
            for n in z.namelist():
                if n.lower().endswith('.pck') and '__MACOSX' not in n:
                    out.update(_pck_read(Path(z.extract(n, td)), want))
        return out
    return _pck_read(path, want)


def names(path: Path) -> list:
    """包里的文件名单（源路径写法，不带 res://）。"""
    path = Path(path)
    if path.suffix.lower() == '.apk':
        with zipfile.ZipFile(path) as z:
            return [n[len('assets/'):] for n in z.namelist() if n.startswith('assets/')]
    if path.suffix.lower() == '.zip':
        out = []
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():
                if n.lower().endswith('.pck') and '__MACOSX' not in n:
                    with tempfile.TemporaryDirectory() as td:
                        p = Path(z.extract(n, td))
                        out += pck_names(p)
        if not out:
            raise ValueError(f'{path.name} 里没有 .pck')
        return out
    return pck_names(path)


# ---- 天启篇脚本必须是空壳 ----

def _stub_mod():
    sp = importlib.util.spec_from_file_location('发行空壳', HERE / '发行空壳.py')
    m = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(m)
    return m


def stub_paths(root: Path = None) -> list:
    """要换成空壳的脚本源路径（发行空壳.targets）。"""
    m = _stub_mod()
    return sorted(str(p) for p in m.targets(root or m.PROJECT).values())


def script_text(data: bytes) -> bytes:
    """包里脚本的内容：.gd 原样；.gdc（GDSC＋版本＋解压后长度＋zstd，长度 0＝没压缩）解开。"""
    if data[:4] != b'GDSC':
        return data
    size, = struct.unpack('<I', data[8:12])
    if size == 0:
        return data[12:]
    try:
        from compression import zstd  # Python 3.14+
        return zstd.decompress(data[12:])
    except ImportError:
        import zstandard  # 旧 Python：pip 的 zstandard
        return zstandard.ZstdDecompressor().decompress(data[12:], max_output_size=size)


def stub_problems(path: Path, scripts: list = None) -> list:
    """包里还是真脚本的天启篇脚本（空＝都是空壳，或包里没有这些脚本）。"""
    tag = _stub_mod().STUB_TAG.encode()
    scripts = stub_paths() if scripts is None else scripts
    alias = {}
    for p in scripts:
        alias[p] = p
        alias[p[:-3] + '.gdc'] = p
    got = read_files(path, lambda n: n in alias)
    out = []
    for n, data in sorted(got.items()):
        try:
            txt = script_text(data)
        except Exception as e:  # noqa: BLE001
            out.append(f'{alias[n]}：解不开（{e}），当真脚本算')
            continue
        if tag in txt:
            continue
        out.append(f'{alias[n]}：不是发行空壳（天启篇真脚本进包了）')
    return out


def audit(path: Path, scripts: list = None) -> list:
    """包里不许有的文件和没换成空壳的天启篇脚本（空＝干净）。读不了也算问题，不当成干净。"""
    try:
        got = names(path)
        bad = sorted({n.removeprefix('res://') for n in got if denied(n)})
        return bad + stub_problems(path, scripts)
    except Exception as e:  # noqa: BLE001
        return [f'{Path(path).name}：读不了包内名单（{e}）']


def tree_problems(root: Path) -> list:
    """出包前的源工程：天启篇脚本都换成空壳、没有没归类的天启篇脚本。"""
    m = _stub_mod()
    root = Path(root)
    out = [f'{p}：没换成空壳' for p in m.is_stub_tree(root)]
    out += [f'{p}：像天启篇专属却没归类（{w}）' for p, w in m.suspects(root)]
    return out


def main(argv) -> int:
    if not argv:
        print(__doc__)
        return 2
    if argv[0] == '--tree':
        v = tree_problems(Path(argv[1]))
        print('\n'.join(['✗ ' + x for x in v]) if v else f'✓ {argv[1]}：天启篇脚本都是空壳，没有没归类的')
        return 1 if v else 0
    bad = 0
    for a in argv:
        v = audit(Path(a))
        if v:
            bad += 1
            print(f'✗ {a}：{len(v)} 个问题（没发行的文件或天启篇真脚本）')
            for x in v[:40]:
                print('   ' + x)
        else:
            print(f'✓ {a}：没有没发行的内容，天启篇脚本都是空壳')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
