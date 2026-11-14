#!/usr/bin/env python3
"""天启篇存档登记检查（cc/save-rng-facade S1）：游戏代码里读写的 flags.tianqi 键、装备上写的 tq_ 键，都要在存档门面登记过。

登记表在 modes/xiyou/core/tianqi_save.gd（XTianqiSave）：
  SECTIONS（分区名、分区自带的根上老键 keys、版本标记键 vkey）、ROOT_KEYS、COUNTER_KEYS、OUTSIDE_KEYS；装备键 GEAR_KEYS。
认的写法（只认字面量键和同文件 const 字符串；flags.tianqi[变量] 这种动态键认不出，跳过）：
  flags.tianqi["k"]、flags.tianqi.get("k" …)、.has("k")、.erase("k")、flags.tianqi.k；
  同文件里 var X = …flags.tianqi 或 var X = XTianqiSave.root(s) 的别名 X["k"]、X.get("k" …)、X.has("k")、X.k；
  装备键（赋值处）：["tq_xxx"] = …、.tq_xxx = …、[同文件 const 值是 "tq_xxx"] = …；XTianqiSave.section／peek／version／set_version(s, "名") 的分区名。
用法：
  python3 天启篇存档登记.py             检查，没登记的逐条打出 文件:行，退出码 1
  python3 天启篇存档登记.py --list      打印登记表认到的键
为什么：天启篇加存档字段返修了一轮又一轮（缺字段、迁移、关开关读档），根子是字段散在各模块、没人看得全；
门面把字段收成一张表，这个检查保证新字段不绕过它（教派等车道新加的键，合并时就会报出来）。"""
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
FACADE = 'modes/xiyou/core/tianqi_save.gd'
DICT_METHODS = {'get', 'has', 'erase', 'keys', 'values', 'duplicate', 'is_empty', 'size', 'merge', 'clear', 'hash', 'has_all'}


def _block(text, name, open_ch, close_ch):
    m = re.search(r'^const %s\s*:?=\s*\%s' % (re.escape(name), open_ch), text, re.M)
    if not m:
        return ''
    depth, i = 0, m.end() - 1
    for j in range(i, len(text)):
        if text[j] == open_ch:
            depth += 1
        elif text[j] == close_ch:
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    return ''


def registry(text):
    """从门面源码读登记表：返回 (根上认的键, 装备键)"""
    root = set()
    sections = _block(text, 'SECTIONS', '{', '}')
    for line in sections.splitlines():
        m = re.match(r'\s*"(\w+)"\s*:\s*\{', line)
        if not m:
            continue
        root.add(m.group(1))
        vk = re.search(r'"vkey"\s*:\s*"(\w+)"', line)
        if vk:
            root.add(vk.group(1))
        ks = re.search(r'"keys"\s*:\s*\[([^\]]*)\]', line)
        if ks:
            root.update(re.findall(r'"(\w+)"', ks.group(1)))
    for name in ('ROOT_KEYS', 'COUNTER_KEYS', 'OUTSIDE_KEYS'):
        root.update(re.findall(r'"(\w+)"', _block(text, name, '[', ']')))
    if 'VKEY' in _block(text, 'ROOT_KEYS', '[', ']'):
        m = re.search(r'^const VKEY\s*:?=\s*"(\w+)"', text, re.M)
        if m:
            root.add(m.group(1))
    gear = set()
    for line in _block(text, 'GEAR_KEYS', '{', '}').splitlines():
        m = re.match(r'\s*"(\w+)"\s*:', line)
        if m:
            gear.add(m.group(1))
    return root, gear


TQ = r'flags(?:\.tianqi|\["tianqi"\])'
ROOT_CALL = r'XTianqiSave\.root\(\s*[\w.]*\s*\)'


def uses(text):
    """一份 .gd 里读写 flags.tianqi 的字面量键：[(行号, 键)]；装备 tq_ 键赋值：[(行号, 键)]"""
    consts = dict(re.findall(r'^const (\w+)\s*:?=\s*"(\w+)"', text, re.M))
    aliases = set(re.findall(r'var (\w+)(?:\s*:\s*Dictionary)?\s*:?=\s*(?:[\w.]*' + TQ + r'|' + ROOT_CALL + r')\s*(?:#.*)?$', text, re.M))
    heads = [TQ] + [r'\b%s' % re.escape(a) for a in aliases]
    pat = re.compile(r'(?:%s)(?:\[\s*(?:"(\w+)"|([A-Z_][A-Z0-9_]*))\s*\]|\.(?:get|has|erase)\(\s*(?:"(\w+)"|([A-Z_][A-Z0-9_]*))|\.([a-z_]\w*)\b(?!\s*\())' % '|'.join(heads))
    out, gear = [], []
    for n, line in enumerate(text.splitlines(), 1):
        code = line.split('#', 1)[0] if not line.lstrip().startswith('##') else ''
        for m in pat.finditer(code):
            lit = m.group(1) or m.group(3) or m.group(5)
            const = m.group(2) or m.group(4)
            key = lit or consts.get(const or '')
            if key and key not in DICT_METHODS:
                out.append((n, key))
        for m in re.finditer(r'\["(tq_\w+)"\]\s*=[^=]', code):
            gear.append((n, m.group(1)))
        for m in re.finditer(r'\w\.(tq_\w+)\s*=[^=]', code):
            gear.append((n, m.group(1)))
        for m in re.finditer(r'\[\s*([A-Z_][A-Z0-9_]*)\s*\]\s*=[^=]', code):
            v = consts.get(m.group(1), '')
            if v.startswith('tq_'):
                gear.append((n, v))
        for m in re.finditer(r'XTianqiSave\.(?:section|peek|version|set_version)\(\s*[\w.]+\s*,\s*"(\w+)"', code):
            out.append((n, m.group(1)))
    return out, gear


def check(project=PROJECT):
    root_ok, gear_ok = registry((project / FACADE).read_text(encoding='utf-8'))
    bad = []
    for p in sorted((project / 'modes').rglob('*.gd')):
        rel = p.relative_to(project).as_posix()
        text = p.read_text(encoding='utf-8')
        if 'tianqi' not in text.lower() and 'tq_' not in text:
            continue
        keys, gear = uses(text)
        bad += ['%s:%d flags.tianqi.%s 没在 XTianqiSave 登记' % (rel, n, k) for n, k in keys if k not in root_ok]
        bad += ['%s:%d 装备键 %s 没在 XTianqiSave.GEAR_KEYS 登记' % (rel, n, k) for n, k in gear if k not in gear_ok]
    return bad, root_ok, gear_ok


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--project', type=Path, default=PROJECT)
    a = ap.parse_args(argv)
    bad, root_ok, gear_ok = check(a.project)
    if a.list:
        print('flags.tianqi：' + '、'.join(sorted(root_ok)))
        print('装备键：' + '、'.join(sorted(gear_ok)))
        return 0
    for b in bad:
        print('  ✗ ' + b)
    print('  ✓ 天启篇存档字段都已登记' if not bad else '天启篇存档登记：%d 处没登记（在 %s 的 SECTIONS／ROOT_KEYS／GEAR_KEYS 加一行）' % (len(bad), FACADE))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
