#!/usr/bin/env python3
"""只载工程、不跑场景的 GDScript 语法检查（白龙 garou3 提，tools27）。

`godot --check-only --script` 在本工程会报 GameApp 等 autoload 找不到（--script 方式不载 autoload），没法单独查语法；
写错一个类型推断，原来要等测试槽、跑到场景里才看到 Parse Error。这里沿用合并工具的解析检查（合并车道.py parse_check）：
godot --import 刷新类缓存，再用外置脚本逐个 load 工程里全部 .gd，autoload 名的「Identifier not found」不算。不占测试槽，约 1 分钟。

  语法检查.py [--root 资料库根] [--base 提交]

--base 给了时另查 base..HEAD 改过的 .gd 有没有同名 func（合并时 git 自动合进两份同名函数的那类）。有问题退出 1。
"""
import argparse
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent


def load_merge():
    spec = importlib.util.spec_from_file_location('lane_merge', HERE / '合并车道.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default=str(HERE.parents[1]))
    ap.add_argument('--base', default='HEAD', help='同名 func 检查的基准（默认 HEAD＝只做加载检查）')
    a = ap.parse_args(argv)
    merge = load_merge()
    problems = merge.parse_check(Path(a.root), a.base)
    for p in problems[:30]:
        print('  ✗ ' + p)
    if len(problems) > 30:
        print('  ……另 %d 条（多是连带错误）' % (len(problems) - 30))
    if not problems:
        print('  ✓ 语法检查通过')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
