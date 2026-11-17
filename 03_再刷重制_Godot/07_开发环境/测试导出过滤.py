#!/usr/bin/env python3
"""导出过滤保护：各导出预设都不带参照数据，发行预设另外不带测试和没发行的内容（发行内容审计.DENY）；游戏数据不能被排除。

「macOS 验收」「Windows 验收」保留 tests/（--verify-export 在包内跑 tests/xiyou_mac_export.tscn）；
「macOS 发行」「Windows 发行」整个排除 tests/（Windows 两档 cc 2026-11-05 加；安卓 验收／发行同理，cc BH 同日）。Godot 的过滤只认 * 和 ?，不分大小写。
"""
import configparser
import fnmatch
from pathlib import Path
import sys
import importlib.util

PROJECT = Path(__file__).resolve().parent.parent / '01_Godot工程'
NOT_GAME = ['modes/xiyou/generated/oracle/zhenqi.json', 'modes/xiyou/generated/oracle_batch.json', 'modes/xiyou/generated/oracle_pending.json', 'modes/xiyou/generated/manifest.json',
            'modes/xiyou/generated/sync_stamp.json', 'builds/再刷重制_验收.zip']
GAME = ['modes/xiyou/generated/db/System.json', 'modes/xiyou/generated/maps/Map001.json',
        'modes/xiyou/generated/slice.json', 'modes/xiyou/generated/img/system/Window.png',
        'content/modes.json', 'scenes/entry_menu.tscn']
_spec = importlib.util.spec_from_file_location('发行内容审计', Path(__file__).resolve().parent / '发行内容审计.py')
审计 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(审计)
# 没发行的内容（发行内容审计.DENY）：发行预设必须排除，验收预设不管（调试包只给自己试）
UNRELEASED = [d.replace('*', 'x.json') for d in 审计.DENY] + ['content/tianqi/knight_war.png', 'modes/xiyou/tianqi_data/skill_rework.json']
TESTS = [p.relative_to(PROJECT).as_posix() for p in (PROJECT / 'tests').rglob('*') if p.is_file()]
PRESETS = {'macOS 验收': [], 'macOS 发行': TESTS + UNRELEASED, 'Windows 验收': [], 'Windows 发行': TESTS + UNRELEASED, '安卓 验收': [], '安卓 发行': TESTS + UNRELEASED}  # 预设名 → 另外必须排除的文件

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
    if name in ('macOS 验收', 'Windows 验收', '安卓 验收') and hit('tests/xiyou_mac_export.tscn'):
        problems.append(f'{name}: 导出验收场景 tests/xiyou_mac_export.tscn 被排除')
# 名单自己也测一下：天启篇数据要拦、西游游戏数据不能误拦
problems += [f'发行内容审计：{p} 没被 DENY 拦下' for p in UNRELEASED if not 审计.denied(p)]
problems += [f'发行内容审计：游戏文件 {p} 被 DENY 误拦' for p in GAME + ['modes/xiyou/alienation.json', 'modes/xiyou/core/rift_alien.gdc', 'content/intro/tianqi_intro_v8.ogv'] if 审计.denied(p)]
# 读包名单：造一个最小的 pck（格式 3，目录在尾部）和一个内嵌在 exe 末尾的同一份，审计要能读出并拦下
import struct, tempfile
def _fake_pck(paths):
    entries = b''.join(struct.pack('<I', len(x.encode()) + (-len(x.encode())) % 4) + x.encode() + b'\0' * ((-len(x.encode())) % 4)
                       + struct.pack('<QQ', 0, 0) + b'\0' * 16 + struct.pack('<I', 0) for x in paths)
    head = b'GDPC' + struct.pack('<IIIIIQ', 3, 4, 7, 2, 2, 0)
    diroff = len(head) + 8 + 64
    return head + struct.pack('<Q', diroff) + b'\0' * 64 + struct.pack('<I', len(paths)) + entries
with tempfile.TemporaryDirectory() as td:
    raw = _fake_pck(['res://modes/xiyou/rift_alien.json', 'res://content/modes.json'])
    (Path(td) / 'a.pck').write_bytes(raw)
    (Path(td) / 'a.exe').write_bytes(b'MZ' + b'\0' * 30 + raw + struct.pack('<Q', len(raw)) + b'GDPC')
    for f in ('a.pck', 'a.exe'):
        got = 审计.audit(Path(td) / f)
        if got != ['modes/xiyou/rift_alien.json']:
            problems.append(f'发行内容审计读 {f} 不对：{got}')
# 天启篇脚本在包里必须是空壳（11-14 release-stub-gojo，XGojo 曾漏）：造带内容的 pck，真脚本要报、带标记的空壳（压缩／不压缩／文本）放过
def _fake_pck_files(files):
    head = b'GDPC' + struct.pack('<IIIIIQ', 3, 4, 7, 2, 2, 0)
    data, ofs, rows = b'', len(head) + 8 + 64, []
    for path, blob in files.items():
        rows.append((path, ofs + len(data), len(blob)))
        data += blob
    diroff = len(head) + 8 + 64 + len(data)
    ent = b''
    for path, o, n in rows:
        x = path.encode()
        pad = (-len(x)) % 4
        ent += struct.pack('<I', len(x) + pad) + x + b'\0' * pad + struct.pack('<QQ', o, n) + b'\0' * 16 + struct.pack('<I', 0)
    return head + struct.pack('<Q', diroff) + b'\0' * 64 + data + struct.pack('<I', len(rows)) + ent
def _gdc(text: bytes, compress=True):
    from compression import zstd
    return b'GDSC' + struct.pack('<II', 101, len(text) if compress else 0) + (zstd.compress(text) if compress else text)
_stubs = 审计.stub_paths()
for need in ('modes/xiyou/core/gojo.gd', 'modes/xiyou/core/guardian_rework.gd', 'modes/xiyou/core/tianqi_gojo_trial.gd'):
    if need not in _stubs:
        problems.append(f'发行内容审计：{need} 不在空壳名单（发行空壳.targets）里')
_tag = 审计._stub_mod().STUB_TAG.encode()
with tempfile.TemporaryDirectory() as td:
    cases = {
        'real.pck': ({'res://modes/xiyou/core/gojo.gdc': _gdc(b'\x04\x00\x00\x00secret real script'), 'res://modes/xiyou/core/gojo.gd.remap': b'[remap]'},
                     ['modes/xiyou/core/gojo.gd：不是发行空壳（天启篇真脚本进包了）']),
        'stub.pck': ({'res://modes/xiyou/core/gojo.gdc': _gdc(b'xx' + _tag + b'yy')}, []),
        'stub_raw.pck': ({'res://modes/xiyou/core/gojo.gdc': _gdc(b'xx' + _tag, compress=False)}, []),
        'stub_text.pck': ({'res://modes/xiyou/core/guardian_rework.gd': b'const _RELEASE_STUB := "' + _tag + b'"'}, []),
        'text_real.pck': ({'res://modes/xiyou/core/guardian_rework.gd': b'class_name XGuardianRework'},
                          ['modes/xiyou/core/guardian_rework.gd：不是发行空壳（天启篇真脚本进包了）']),
        # T109：text_fix/rules.json 带 tianqi_dict／说明字段要拦，剔干净的放行
        'rules_bad.pck': ({'res://modes/xiyou/text_fix/rules.json': b'{"dict": [], "tianqi_dict": [{"from": "a", "to": "b"}]}'},
                          ['modes/xiyou/text_fix/rules.json：带 tianqi_dict（天启篇改名词典进包了）']),
        'rules_note.pck': ({'res://modes/xiyou/text_fix/rules.json': '{"_说明": "x", "dict": []}'.encode()},
                           ['modes/xiyou/text_fix/rules.json：带注释字段 _说明']),
        'rules_ok.pck': ({'res://modes/xiyou/text_fix/rules.json': b'{"dict": [{"from": "a", "to": "b"}], "trad": {}}'}, []),
    }
    for f, (files, want) in cases.items():
        (Path(td) / f).write_bytes(_fake_pck_files(files))
        got = 审计.audit(Path(td) / f)
        if got != want:
            problems.append(f'发行内容审计查空壳 {f} 不对：{got}')
# T109：发行克隆的 rules.json 剔掉 tianqi_dict 与注释字段，西游档 dict／trad／namebox_skip 原样
import json as _json
_spec = importlib.util.spec_from_file_location('发行空壳', Path(__file__).resolve().parent / '发行空壳.py')
_K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_K)
_real = _json.loads((_K.PROJECT / _K.RULES_REL).read_text(encoding='utf-8'))
_clean = _K.scrub_rules_data(_real)
if 'tianqi_dict' in _clean or not _real.get('tianqi_dict'):
    problems.append('scrub_rules_data 没剔掉 tianqi_dict（或真表本来就是空，回归失效）')
for _k in ('dict', 'trad', 'namebox_skip'):
    _a = _K.scrub_rules_data({_k: _real.get(_k)})[_k]
    if _clean.get(_k) != _a or not _a:
        problems.append(f'西游档 {_k} 被改动或为空')
if len(_clean['dict']) != len(_real['dict']):
    problems.append('西游档 dict 条数变了')
_txt = _json.dumps(_clean, ensure_ascii=False)
for _w in ('晨星币', '霸主', '见证使者', '远古首领', 'D126'):
    if _w in _txt:
        problems.append(f'发行 rules.json 仍含 {_w}')
with tempfile.TemporaryDirectory() as td:
    (Path(td) / _K.RULES_REL).parent.mkdir(parents=True)
    (Path(td) / _K.RULES_REL).write_text(_json.dumps(_real, ensure_ascii=False), encoding='utf-8')
    if not _K.scrub_rules(Path(td)) or 'tianqi_dict' in _json.loads((Path(td) / _K.RULES_REL).read_text(encoding='utf-8')):
        problems.append('scrub_rules 落盘后仍带 tianqi_dict')
problems += [f'缺少导出预设「{n}」' for n in PRESETS if n not in seen]

for p in problems:
    print('导出过滤：' + p)
sys.exit(1 if problems else 0)
