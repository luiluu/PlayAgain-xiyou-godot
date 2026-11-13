#!/usr/bin/env python3
"""发行内容审计（cc 2026-11-13，漩涡异化设计稿外泄之后加）：没发行的内容不许进玩家手里的包和补丁。

v0.01.05 补丁（0.475）和 v0.01.06 整包（dev476）都带出了 rift_alien.json（漩涡五阶段异化的设计数值），
整包还带出了 tianqi_data/ 下的天启篇数值表。原因是发行预设是「全部资源＋所有 json」，只排除了几项。

这里是「哪些不许进发行包」的唯一名单（DENY，Godot 过滤写法：* 和 ?，不分大小写，* 跨目录）：
  - 发行预设（Windows／安卓／macOS 发行）的 exclude_filter 必须盖住 DENY，测试导出过滤.py 查；
  - 发行出包.py 导完三平台、发布补丁.py 导完补丁，都用 audit() 把包里的文件名单逐条过 DENY，有一条就停。
新加一类没发行的内容（天启篇新数据目录、新设计数值表、新美术目录）：加进 DENY，再把同样的写法加进三个发行预设。
对玩家开放时从 DENY 和预设里一起删掉。

  python3 发行内容审计.py <包>…        包可以是 .pck、带内嵌 pck 的 .exe、.apk、mac 的 .zip；有违规退出 1
"""
import fnmatch
from pathlib import Path
import struct
import sys
import zipfile

# 还没发行的内容（Kyo 11-12：天启篇只在本地；漩涡三阶起的异化没开放）
DENY = [
    'modes/xiyou/tianqi_data/*',      # 天启篇全部数值表、词条、四线、七印、技能重构
    'content/tianqi/*',               # 天启篇美术（骑士、七印）
    'content/gojo/*',                 # 五条悟（只进天启篇）
    'modes/xiyou/rift_alien.json',    # 漩涡五阶段怪物异化设计数值
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
    f.seek(base)
    if f.read(4) != b'GDPC':
        raise ValueError('不是 Godot pck')
    ver, _maj, _min, _pat, flags, _fbase = struct.unpack('<IIIIIQ', f.read(28))
    if flags & 1:
        raise ValueError('pck 目录加密了，读不了名单（加密包要换法子审）')
    if ver >= 3:
        diroff, = struct.unpack('<Q', f.read(8))
        f.seek(base + diroff)
    else:
        f.read(64)
    n, = struct.unpack('<I', f.read(4))
    out = []
    for _ in range(n):
        ln, = struct.unpack('<I', f.read(4))
        out.append(f.read(ln).rstrip(b'\0').decode('utf-8', 'replace'))
        f.read(16 + 16 + (4 if ver >= 2 else 0))
    return out


def pck_names(path: Path) -> list:
    with open(path, 'rb') as f:
        if f.read(4) == b'GDPC':
            return _pck_names(f, 0)
        f.seek(-12, 2)  # 内嵌在 exe 末尾：…pck…［8 字节 pck 长度］GDPC
        size, = struct.unpack('<Q', f.read(8))
        if f.read(4) != b'GDPC':
            raise ValueError(f'{path.name} 里找不到 pck')
        f.seek(-12 - size, 2)
        return _pck_names(f, f.tell())


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
                    import tempfile
                    with tempfile.TemporaryDirectory() as td:
                        p = Path(z.extract(n, td))
                        out += pck_names(p)
        if not out:
            raise ValueError(f'{path.name} 里没有 .pck')
        return out
    return pck_names(path)


def audit(path: Path) -> list:
    """包里不许有的文件（空＝干净）。读不了名单也算问题，不当成干净。"""
    try:
        got = names(path)
    except Exception as e:  # noqa: BLE001
        return [f'{Path(path).name}：读不了包内名单（{e}）']
    return sorted({n.removeprefix('res://') for n in got if denied(n)})


def main(argv) -> int:
    if not argv:
        print(__doc__)
        return 2
    bad = 0
    for a in argv:
        v = audit(Path(a))
        if v:
            bad += 1
            print(f'✗ {a}：{len(v)} 个没发行的文件')
            for x in v[:40]:
                print('   ' + x)
        else:
            print(f'✓ {a}：没有没发行的内容')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
