#!/usr/bin/env python3
"""导出过滤保护：各导出预设都不带参照数据，发行预设另外不带测试；游戏数据不能被排除。

「macOS 验收」保留 tests/（--verify-export 在包内跑 tests/xiyou_mac_export.tscn）；
「macOS 发行」整个排除 tests/。Godot 的过滤只认 * 和 ?，不分大小写。
"""
import configparser
import fnmatch
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parent.parent / '01_Godot工程'
NOT_GAME = ['modes/xiyou/generated/oracle/zhenqi.json', 'modes/xiyou/generated/manifest.json',
            'modes/xiyou/generated/sync_stamp.json', 'builds/再刷重制_验收.zip']
GAME = ['modes/xiyou/generated/db/System.json', 'modes/xiyou/generated/maps/Map001.json',
        'modes/xiyou/generated/slice.json', 'modes/xiyou/generated/img/system/Window.png',
        'content/modes.json', 'scenes/entry_menu.tscn']
TESTS = [p.relative_to(PROJECT).as_posix() for p in (PROJECT / 'tests').rglob('*') if p.is_file()]
PRESETS = {'macOS 验收': [], 'macOS 发行': TESTS}  # 预设名 → 另外必须排除的文件

cfg = configparser.ConfigParser(interpolation=None)
cfg.read(PROJECT / 'export_presets.cfg', encoding='utf-8')
problems, seen = [], set()
for sec in [s for s in cfg.sections() if s.startswith('preset.') and s.count('.') == 1]:
    name = cfg[sec].get('name', '').strip('"')
    seen.add(name)
    pats = [p.strip() for p in cfg[sec].get('exclude_filter', '""').strip('"').split(',') if p.strip()]
    hit = lambda path: any(fnmatch.fnmatchcase(path.lower(), p.lower()) for p in pats)
    problems += [f'{name}: {p} 没被排除' for p in NOT_GAME + PRESETS.get(name, []) if not hit(p)]
    problems += [f'{name}: 游戏文件 {p} 被排除' for p in GAME if hit(p)]
    if name == 'macOS 验收' and hit('tests/xiyou_mac_export.tscn'):
        problems.append(f'{name}: 导出验收场景 tests/xiyou_mac_export.tscn 被排除')
problems += [f'缺少导出预设「{n}」' for n in PRESETS if n not in seen]

for p in problems:
    print('导出过滤：' + p)
sys.exit(1 if problems else 0)
