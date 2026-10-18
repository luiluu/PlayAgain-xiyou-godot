#!/usr/bin/env python3
"""导出过滤保护：export_presets.cfg 的 exclude_filter 要挡住测试与参照数据，只留导出验收场景。

导出验收（--verify-export）要在包内跳到 tests/xiyou_mac_export.tscn，所以 tests/ 不能整个排除，
只能按文件名前缀逐个排除；新增测试的前缀没被挡住时这里报出来。Godot 的过滤只认 * 和 ?，不分大小写。
"""
import configparser
import fnmatch
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parent.parent / '01_Godot工程'
KEEP = 'tests/xiyou_mac_export.'  # 导出验收场景及其脚本
MUST = ['modes/xiyou/generated/oracle/zhenqi.json', 'modes/xiyou/generated/manifest.json',
        'modes/xiyou/generated/sync_stamp.json', 'builds/再刷重制_验收.zip']
GAME = ['modes/xiyou/generated/db/System.json', 'modes/xiyou/generated/maps/Map001.json',
        'modes/xiyou/generated/slice.json', 'modes/xiyou/generated/img/system/Window.png',
        'content/modes.json', 'scenes/entry_menu.tscn']

cfg = configparser.ConfigParser(interpolation=None)
cfg.read(PROJECT / 'export_presets.cfg', encoding='utf-8')
problems = []
for sec in [s for s in cfg.sections() if s.startswith('preset.') and s.count('.') == 1]:
    pats = [p.strip() for p in cfg[sec].get('exclude_filter', '""').strip('"').split(',') if p.strip()]
    hit = lambda path: any(fnmatch.fnmatchcase(path.lower(), p.lower()) for p in pats)
    tests = [p.relative_to(PROJECT).as_posix() for p in (PROJECT / 'tests').rglob('*') if p.is_file()]
    for path in tests + MUST:
        if hit(path) == path.startswith(KEEP):
            problems.append(f'{sec}: {path} ' + ('不该被排除' if path.startswith(KEEP) else '没被排除'))
    problems += [f'{sec}: 游戏文件 {p} 被排除' for p in GAME if hit(p)]

for p in problems:
    print('导出过滤：' + p)
sys.exit(1 if problems else 0)
