#!/usr/bin/env python3
"""优化开关的回退支有没有测试碰过（75% 审查 G3：O-101/102/103/107/117 的回退支没有任何测试，总装七 tools26）。

读 00_设计/优化登记.md 里状态是「保留／待用户决定／待用户确认／已做」的行，从「恢复方法」列解析出开关名与回退值
（`XPetCapture.FLEE_ALIVE_ONLY = false`、`XHelpCard.MIN_FONT` 设 0、`XAchievement.A`、`B` 分别设 false 这几种写法），
再在 01_Godot工程/tests/ 的 .gd 里找有没有把它赋成回退值的语句（`NAME = 值`，或 `set("NAME", 值)`）。

  回退开关覆盖.py [--root 资料库根] [--strict] [--all] [--json]

输出三类：
  缺口       有开关、没有测试把它设成回退值（不在豁免清单里的才算新缺口）；const 开关另注「测试改不了，要先改成 static var」
  人工确认   只找到赋成非字面量的语句（如循环里 `NAME = flag`），可能覆盖了，脚本不猜
  解析不了   恢复方法列提到了像开关的名字（全大写或 o_ 开头），但认不出回退值，或代码里找不到／有多处定义；不硬猜
默认只警告、退出 0（检查.sh 里只提示不挡）；--strict 有新缺口时退出 1。--all 连豁免里的也列出。
豁免清单 回退开关豁免.json：{"enabled": true, "known": {"O-101 XPetCapture.SHOW_REFRESH_TEXT": "原因", "O-062": "原因"}}
（键是缺口／人工确认的「编号 开关」，或解析不了的「编号」；默认只打出不在清单里的项）；
enabled 设 false（或环境变量 XIYOU_ROLLBACK_CHECK=0）整个检查关掉。豁免里的项已有测试覆盖时提示可以删。
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REGISTER = '03_再刷重制_Godot/00_设计/优化登记.md'
PROJECT = '03_再刷重制_Godot/01_Godot工程'
TOOLS = '03_再刷重制_Godot/07_开发环境'
ALLOW = HERE / '回退开关豁免.json'
ACTIVE = ('保留', '待用户决定', '待用户确认', '已做')

IDENT = r'[A-Za-z_]\w*'
# 回退值：字面量（true/false/数字/{}/[]/"…"）
VALUE = r'(true|false|-?\d+(?:\.\d+)?|\{\}|\[\]|"[^"]*")'
# `X.NAME = v`、`NAME := v`（反引号里整段）
ASSIGN_IN_TICKS = re.compile(r'`(?:(%s)\.)?(%s)\s*:?=\s*%s`' % (IDENT, IDENT, VALUE))
# `X.NAME` 设 v ／ `X.NAME` 设为 `v`
SET_AFTER_TICKS = re.compile(r'`(?:(%s)\.)?(%s)`\s*设为?\s*`?%s`?' % (IDENT, IDENT, VALUE))
# `X.A`、`B`、`C` 分别设 v
EACH = re.compile(r'((?:`[\w.]+`\s*[、，,]\s*)+`[\w.]+`)\s*分别设为?\s*`?%s`?' % VALUE)
# `X.NAME` 删 `条目` 一条（字典常量里删一个条目回退，如 O-062 的 MVInterpreter.TRANSFER_FIX）：回退值记成「删:条目」，测试里要有 NAME.erase("条目")
REMOVE_ENTRY = re.compile(r'`(?:(%s)\.)?(%s)`\s*删\s*`([^`]+)`\s*一条' % (IDENT, IDENT))
SWITCHY = re.compile(r'`(?:%s\.)?([A-Z][A-Z0-9_]{2,}|o\d*_\w+)`' % IDENT)


def rows(text):
    """登记表各行：(编号, 位置, 恢复方法, 状态)；列数不对的整行原样返回在 bad 里。"""
    out, bad = [], []
    for line in text.splitlines():
        if not line.startswith('| O-'):
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) != 8:
            bad.append((cells[0], '列数 %d，不是 8' % len(cells)))
            continue
        out.append((cells[0], cells[1], cells[5], cells[7]))
    return out, bad


def parse_switches(restore):
    """恢复方法列 → [(类名或 None, 开关名, 回退值)]，按出现顺序去重。"""
    found = []
    for m in EACH.finditer(restore):
        names = re.findall(r'`([\w.]+)`', m.group(1))
        cls = names[0].split('.')[0] if '.' in names[0] else None
        for n in names:
            c, _, name = n.rpartition('.')
            found.append((c or cls, name, m.group(2)))
    for rx in (ASSIGN_IN_TICKS, SET_AFTER_TICKS):
        for m in rx.finditer(restore):
            found.append((m.group(1), m.group(2), m.group(3)))
    for m in REMOVE_ENTRY.finditer(restore):
        found.append((m.group(1), m.group(2), '删:' + m.group(3)))
    seen, uniq = set(), []
    for c, n, v in found:
        if (c, n) not in seen:
            seen.add((c, n))
            uniq.append((c, n, v))
    return uniq


def index_project(project):
    """非测试 .gd：class_name → 文件；开关名 → [(文件, 声明种类)]；tests/ 下 .gd 的 (路径, 文本)。"""
    classes, decls, tests = {}, {}, []
    decl = re.compile(r'^(static var|const|var)\s+(%s)\b' % IDENT, re.M)
    for f in sorted(project.rglob('*.gd')):
        rel = f.relative_to(project)
        if '.godot' in rel.parts:
            continue
        text = f.read_text(encoding='utf-8', errors='replace')
        if rel.parts[0] == 'tests':
            tests.append((rel.as_posix(), text))
            continue
        m = re.search(r'^class_name\s+(%s)' % IDENT, text, re.M)
        if m:
            classes[m.group(1)] = rel.as_posix()
        for kind, name in decl.findall(text):
            decls.setdefault(name, []).append((rel.as_posix(), kind))
    return classes, decls, tests


def locate(cls, name, classes, decls):
    """开关声明在哪：返回 ((文件, 种类), 问题)；找不到或多处时问题非空。"""
    cands = decls.get(name, [])
    if cls:
        if cls not in classes:
            # MVInterpreter 这类类名与 class_name 一致的才认；对不上就退回只按名字找
            pass
        else:
            cands = [d for d in cands if d[0] == classes[cls]]
    if not cands:
        return None, '代码里找不到 %s 的声明' % ('%s.%s' % (cls, name) if cls else name)
    if len(cands) > 1:
        return None, '%s 有 %d 处声明（%s），认不出是哪个' % (name, len(cands), '、'.join(f for f, _ in cands[:3]))
    return cands[0], ''


def coverage(name, value, tests):
    """('literal', [位置]) 有测试赋回退值；('dynamic', [位置]) 只有非字面量赋值；(None, []) 没碰。"""
    if value.startswith('删:'):
        erase = re.compile(r'(?<![\w.])(?:\w+\.)*%s\.erase\(\s*["\']%s["\']\s*\)' % (name, re.escape(value[2:])))
        hits = ['%s:%d' % (path, i) for path, text in tests if name in text
                for i, line in enumerate(text.splitlines(), 1) if erase.search(line.split('#', 1)[0])]
        return ('literal', hits) if hits else (None, [])
    v = re.escape(value).replace(r'\{\}', r'\{\s*\}').replace(r'\[\]', r'\[\s*\]')
    lit = re.compile(r'(?<![\w.])(?:\w+\.)*%s\s*:?=(?!=)\s*%s(?![\w.])|\.set\(\s*["\']%s["\']\s*,\s*%s\s*\)' % (name, v, name, v))
    anyset = re.compile(r'(?<![\w.])(?:\w+\.)*%s\s*:?=(?!=)\s*(?!true\b|false\b|-?\d|\{|\[|")(\S+)|\.set\(\s*["\']%s["\']\s*,\s*(?!true\b|false\b|-?\d|\{|\[|")' % (name, name))
    hits, dyn = [], []
    for path, text in tests:
        if name not in text:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            s = line.split('#', 1)[0]
            if lit.search(s):
                hits.append('%s:%d' % (path, i))
            elif anyset.search(s):
                dyn.append('%s:%d' % (path, i))
    if hits:
        return 'literal', hits
    if dyn:
        return 'dynamic', dyn
    return None, []


def index_tools(tools):
    """工具开关的声明与测试：环境变量名 → 声明它的非测试 .py；(JSON 文件, 键, 字段) 三元组；测试 .py 的 (路径, 文本)。
    O-153 之类工具类优化的开关不在 .gd 里：写成对照表 JSON 的字段（`hookLines.enabled = false`）或环境变量（`XIYOU_HOOKS=0`），tools56 起认。"""
    envs, fields, tests = {}, set(), []
    if not tools.is_dir():
        return envs, fields, tests
    for f in sorted(tools.glob('*.py')):
        text = f.read_text(encoding='utf-8', errors='replace')
        if f.name.startswith('测试'):
            tests.append((f.name, text))
            continue
        for name in re.findall(r'\b(XIYOU_[A-Z0-9_]+)\b', text):
            envs.setdefault(name, f.name)
    for f in sorted(tools.glob('*.json')):
        try:
            data = json.loads(f.read_text(encoding='utf-8'))
        except ValueError:
            continue
        stack = [data]
        while stack:
            node = stack.pop()
            if isinstance(node, dict):
                for k, v in node.items():
                    if isinstance(v, dict):
                        fields.update((f.name, k, n) for n in v)
                        stack.append(v)
    return envs, fields, tests


def tool_coverage(cls, name, value, tests):
    """工具开关的测试覆盖：环境变量看 `'NAME': '值'`／`NAME=值`，JSON 字段看 `[...]['键']['字段'] = 值`（Python 字面量）。"""
    py = {'true': 'True', 'false': 'False'}.get(value, value.strip('"'))
    q = r'[\'"]'
    if cls is None:
        lit = re.compile(r'%s%s%s\s*:\s*%s?%s%s?(?![\w.])|\b%s=%s(?![\w.])' % (q, re.escape(name), q, q, re.escape(py), q, re.escape(name), re.escape(py)))
        dyn = re.compile(r'%s%s%s\s*:\s*(?![\'"\d{\[]|True\b|False\b)\w' % (q, re.escape(name), q))
    else:
        lit = re.compile(r'\[%s%s%s\]\s*\[%s%s%s\]\s*=\s*%s?%s%s?(?![\w.])' % (q, re.escape(cls), q, q, re.escape(name), q, q, re.escape(py), q))
        dyn = re.compile(r'\[%s%s%s\]\s*\[%s%s%s\]\s*=\s*(?![\'"\d{\[]|True\b|False\b)\w' % (q, re.escape(cls), q, q, re.escape(name), q))
    hits, dynamic = [], []
    for path, text in tests:
        for i, line in enumerate(text.splitlines(), 1):
            s = line.split('#', 1)[0]
            if lit.search(s):
                hits.append('%s:%d' % (path, i))
            elif dyn.search(s):
                dynamic.append('%s:%d' % (path, i))
    return ('literal', hits) if hits else ('dynamic', dynamic) if dynamic else (None, [])


def scan(root):
    """返回 {'switches': [...], 'unparsed': [...]}；每个开关 {id, key, cls, name, value, file, kind, status, where}。"""
    text = (root / REGISTER).read_text(encoding='utf-8')
    table, bad = rows(text)
    classes, decls, tests = index_project(root / PROJECT)
    tool_envs, tool_fields, tool_tests = index_tools(root / TOOLS)
    switches, unparsed = [], [{'id': i, 'why': w} for i, w in bad]
    for oid, _where, restore, status in table:
        if not status.startswith(ACTIVE):
            continue
        parsed = parse_switches(restore)
        named = {n for _, n, _ in parsed}
        loose = [n for n in SWITCHY.findall(restore) if n not in named]
        if loose:
            unparsed.append({'id': oid, 'why': '提到 %s 但认不出回退值' % '、'.join(dict.fromkeys(loose))})
        for cls, name, value in parsed:
            decl, why = locate(cls, name, classes, decls)
            if why and ((cls is None and name in tool_envs) or any(f[1:] == (cls, name) for f in tool_fields)):
                file = tool_envs[name] if cls is None else next(f[0] for f in sorted(tool_fields) if f[1:] == (cls, name))
                state, where = tool_coverage(cls, name, value, tool_tests)
                switches.append({'id': oid, 'key': '%s %s' % (oid, '%s.%s' % (cls, name) if cls else name),
                                 'cls': cls, 'name': name, 'value': value, 'file': '%s/%s' % (TOOLS, file), 'kind': 'tool',
                                 'status': {'literal': '覆盖', 'dynamic': '人工确认'}.get(state, '缺口'), 'where': where[:3]})
                continue
            if why:
                unparsed.append({'id': oid, 'why': why})
                continue
            state, where = coverage(name, value, tests)
            switches.append({'id': oid, 'key': '%s %s' % (oid, '%s.%s' % (cls, name) if cls else name),
                             'cls': cls, 'name': name, 'value': value, 'file': decl[0], 'kind': decl[1],
                             'status': {'literal': '覆盖', 'dynamic': '人工确认'}.get(state, '缺口'), 'where': where[:3]})
    return {'switches': switches, 'unparsed': unparsed}


def last_lane(root, rel, name):
    """最后改动该开关声明的车道：找最后一次动了 name 的提交，再找把它并进主线的那次合并（「合并 cc/xxx」）；
    返回「合并标题 · 短号 提交标题」，没有车道合并时只给提交，找不到返回空串。
    tools43：原来 --reverse -1 先截 1 条再反转，取到的是最新的合并（O-147 报成 tusu4，实为 events3）；
    现在按时间从早到晚逐个看，取第一个「提交在第二父、不在第一父」的合并。"""
    def git(*args):
        return subprocess.run(['git', '-C', str(root), *args], capture_output=True, text=True, timeout=30).stdout.strip()

    def ancestor(a, b):
        return subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', a, b], capture_output=True, timeout=30).returncode == 0
    try:
        # -G（改动行里出现 name）而不是 -S（name 出现次数变了）：只改回退值（true → false）的提交 -S 看不见（tools43）
        commit = git('log', '-1', '--format=%H', '-G' + r'(^|[^A-Za-z0-9_])' + re.escape(name) + r'([^A-Za-z0-9_]|$)', '--', '%s/%s' % (PROJECT, rel))
        if not commit:
            return ''
        own = git('log', '-1', '--format=%h %s', commit)
        merges = git('log', '--merges', '--ancestry-path', '--reverse', '-E', '--grep=^合并 (cc|claude|codex)/', '--format=%H %s', commit + '..HEAD')
        for line in merges.splitlines()[:200]:
            sha, _, title = line.partition(' ')
            if ancestor(commit, sha + '^2') and not ancestor(commit, sha + '^1'):
                return '%s · %s' % (title, own)
        return own
    except (OSError, subprocess.SubprocessError):
        return ''


def load_allow(path):
    try:
        data = json.loads(Path(path).read_text(encoding='utf-8'))
    except FileNotFoundError:
        return {'enabled': True, 'known': {}}
    return {'enabled': data.get('enabled', True) is not False, 'known': dict(data.get('known') or {})}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default=str(HERE.parents[1]))
    ap.add_argument('--allow', default=str(ALLOW))
    ap.add_argument('--strict', action='store_true')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args(argv)
    allow = load_allow(a.allow)
    if os.environ.get('XIYOU_ROLLBACK_CHECK') == '0' or not allow['enabled']:
        print('  - 回退开关覆盖检查已关（回退开关豁免.json enabled=false 或 XIYOU_ROLLBACK_CHECK=0）')
        return 0
    res = scan(Path(a.root))
    known = allow['known']
    gaps = [s for s in res['switches'] if s['status'] == '缺口']
    new = [s for s in gaps if s['key'] not in known]
    stale = sorted(k for k in known if any(s['key'] == k and s['status'] == '覆盖' for s in res['switches']))
    new_review = [s['key'] for s in res['switches'] if s['status'] == '人工确认' and s['key'] not in known]
    new_unparsed = [u['id'] for u in res['unparsed'] if u['id'] not in known]
    if a.json:
        print(json.dumps(dict(res, newGaps=[s['key'] for s in new], newReview=new_review, newUnparsed=new_unparsed,
                              staleAllow=stale), ensure_ascii=False, indent=1))
        return 1 if a.strict and new else 0
    covered = sum(s['status'] == '覆盖' for s in res['switches'])
    print('  回退开关 %d 个：测试覆盖回退值 %d，缺口 %d（新 %d、豁免 %d），人工确认 %d，解析不了 %d 行' % (
        len(res['switches']), covered, len(gaps), len(new), len(gaps) - len(new),
        sum(s['status'] == '人工确认' for s in res['switches']), len(res['unparsed'])))
    for s in (gaps if a.all else new):
        note = '；const，测试改不了，要先改成 static var' if s['kind'] == 'const' else ''
        tag = '' if s['key'] not in known else '（豁免）'
        lane = last_lane(Path(a.root), s['file'], s['name'])
        print('  ⚠ 缺口%s %s = %s（%s%s%s）' % (tag, s['key'], s['value'], s['file'], note, '；最后改它的：' + lane[:100] if lane else ''))
    for s in res['switches']:
        if s['status'] == '人工确认' and (a.all or s['key'] not in known):
            print('  ? 人工确认 %s：只见非字面量赋值 %s' % (s['key'], '、'.join(s['where'])))
    for u in res['unparsed']:
        if a.all or u['id'] not in known:
            print('  ? 解析不了 %s：%s' % (u['id'], u['why']))
    for k in stale:
        print('  ✓ %s 已有测试设回退值，可从 回退开关豁免.json 删掉' % k)
    return 1 if a.strict and new else 0


if __name__ == '__main__':
    sys.exit(main())
