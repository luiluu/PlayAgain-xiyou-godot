#!/usr/bin/env python3
"""递增 Godot 开发编号，并同步 project.godot 与 build_info.json。

用法：
  开发编号.py            显示当前编号与三处是否一致
  开发编号.py bump "说明" [--kind 类型] [--gameplay]
                         dev.N → dev.N+1，三处一起写入

开发编号.json 是唯一登记；不要手改另外两处。
"""
import json
import re
import sys
from pathlib import Path

GODOT_DIR = Path(__file__).resolve().parent.parent
REGISTRY = GODOT_DIR / '开发编号.json'
PROJECT = GODOT_DIR / '01_Godot工程/project.godot'
BUILD = GODOT_DIR / '01_Godot工程/content/build_info.json'


def load(p):
    return json.loads(p.read_text())


def dump(p, data):
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def show():
    reg = load(REGISTRY)
    proj = re.search(r'config/version="([^"]+)"', PROJECT.read_text()).group(1)
    build = load(BUILD)['developmentVersion']
    same = reg['current'] == proj == build
    print(f"开发编号.json={reg['current']} project.godot={proj} build_info={build} {'一致' if same else '不一致'}")
    return 0 if same else 1


def bump(note, kind=None, gameplay=None):
    reg = load(REGISTRY)
    seq = reg['nextSequence']
    new = f'dev.{seq:03d}'
    reg.update({'current': new, 'sequence': seq, 'next': f'dev.{seq + 1:03d}', 'nextSequence': seq + 1, 'currentChange': note})
    dump(REGISTRY, reg)
    text = PROJECT.read_text()
    text, n = re.subn(r'config/version="[^"]+"', f'config/version="{new}"', text)
    assert n == 1, 'project.godot 缺少 config/version'
    PROJECT.write_text(text)
    build = load(BUILD)
    build['developmentVersion'] = new
    if kind:
        build['kind'] = kind
    if gameplay is not None:
        build['gameplayAvailable'] = gameplay
    dump(BUILD, build)
    print(f'已递增到 {new}：{note}')
    return show()


if __name__ == '__main__':
    args = sys.argv[1:]
    if not args:
        sys.exit(show())
    if args[0] == 'bump' and len(args) >= 2:
        kind = args[args.index('--kind') + 1] if '--kind' in args else None
        sys.exit(bump(args[1], kind, True if '--gameplay' in args else None))
    print(__doc__)
    sys.exit(2)
