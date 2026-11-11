#!/usr/bin/env python3
"""判断这次 godot --import 是不是整轮重导入（cc 平台 DZ 2026-11-06）：新建工作树.sh --补齐 据此选导入方式。

  python3 导入超时.py <工程目录>     打印一行「full|normal <缺的贴图缓存数> <应有数>」，退出码 0

依据：工程里各 .import 文件写的 path="res://.godot/imported/…ctex"（贴图导入后的缓存）在 .godot/imported 里有没有。
缺的超过 FULL_RATIO（或 .godot/imported 不存在、为空）就算整轮：删过 ctex（换压缩档，O-210）或新工作树没带缓存时，
3000 多张贴图重导要 25～40 分钟，普通补齐的 300 秒上限会把它掐掉（DX 11-06：3065 张只导了 640 张就报「导入失败」）。
"""
import re
import sys
from pathlib import Path

FULL_RATIO = 0.2
PATH_RE = re.compile(r'^path(?:\.[a-z0-9_]+)?="res://(\.godot/imported/[^"]+\.ctex)"', re.M)
SKIP_DIRS = {'.godot', 'builds', 'node_modules'}


def expected_ctex(proj: Path) -> list:
    out = []
    for imp in proj.rglob('*.import'):
        rel = imp.relative_to(proj).parts
        if rel and rel[0] in SKIP_DIRS:
            continue
        if any((proj.joinpath(*rel[:i]) / '.gdignore').exists() for i in range(1, len(rel))):
            continue  # Godot 不导入带 .gdignore 的目录（如安卓构建模板 android/build 里自带的 .import）
        try:
            text = imp.read_text(encoding='utf-8', errors='replace')
        except OSError:
            continue
        out += PATH_RE.findall(text)
    return out


def classify(proj: Path) -> tuple:
    imported = proj / '.godot' / 'imported'
    want = expected_ctex(proj)
    if not imported.is_dir() or not any(imported.iterdir()):
        return 'full', len(want), len(want)
    missing = sum(1 for p in want if not (proj / p).is_file())
    full = bool(want) and missing > FULL_RATIO * len(want)
    return ('full' if full else 'normal'), missing, len(want)


def main(argv) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 64
    mode, missing, total = classify(Path(argv[1]))
    print(mode, missing, total)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
