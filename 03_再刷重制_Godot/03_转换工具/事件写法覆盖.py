#!/usr/bin/env python3
"""事件写法有没有原版对照（cc eventsreg1，只读）：切片里地图事件页与公共事件的每条指令按「写法」归类，
再看 xiyou_event_compare 跑原版对照用例时（--coverage 记下的「位置:下标」）有没有真执行到它。

写法键：指令码＋要紧的子类——111 按条件类型（脚本条件再按脚本形状）、122 按操作数类型（脚本操作数按脚本形状）、
355／655 按整段脚本的形状（数字→N、字符串→S、空白合并，前 80 字）、356 按插件指令前两个词、201／301 按指定方式，其余只看指令码。
续行（401／405／408／605 等）、分支尾（0／411／412／402／403／404／601～604 的结构行）不单算。

  事件写法覆盖.py --coverage <xiyou_event_compare --coverage 写的 JSON> [--out 报告.md] [--json 结果.json]

位置可达：公共事件在 tests/fixtures/script_census_known.json 的 unreachable 里→「走不到」，在 battleRoots 或只被战斗调用的→不分（本工具不追调用方，只看 unreachable）。
排序：没有对照例的写法按出现次数降序；有对照例的写法只计数。
"""
import argparse
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'
KNOWN = HERE.parent / '01_Godot工程/tests/fixtures/script_census_known.json'
SKIP = {0, 401, 405, 408, 411, 412, 402, 403, 404, 601, 602, 603, 604, 605, 655, 413, 505, 108}
COND = {0: '开关', 1: '变量', 2: '独立开关', 3: '计时器', 4: '角色', 5: '敌人', 6: '角色朝向', 7: '金钱', 8: '物品', 9: '武器',
        10: '防具', 11: '按键', 12: '脚本', 13: '载具'}
OPER = {0: '常量', 1: '变量', 2: '随机', 3: '游戏数据', 4: '脚本'}
NUM = re.compile(r'(?<![\w$])-?\d+(?:\.\d+)?')
STR = re.compile(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"")


def shape(text: str) -> str:
    s = STR.sub('S', text)
    s = NUM.sub('N', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s[:80]


def key_of(lst, i):
    c = lst[i]
    code, p = int(c['code']), c.get('parameters', [])
    if code == 111:
        t = int(p[0])
        if t == 12:
            return '111 条件·脚本: ' + shape(str(p[1]))
        if t == 1:
            return '111 条件·变量（%s）' % ('比变量' if int(p[2]) else '比常量')
        return '111 条件·' + COND.get(t, str(t))
    if code == 122:
        t = int(p[3])
        if t == 4:
            return '122 变量·脚本: ' + shape(str(p[4]))
        if t == 3:
            return '122 变量·游戏数据（类型 %s）' % p[4]
        return '122 变量·' + OPER.get(t, str(t))
    if code == 355:
        text = [str(p[0])]
        j = i + 1
        while j < len(lst) and int(lst[j]['code']) == 655:
            text.append(str(lst[j]['parameters'][0]))
            j += 1
        return '355 脚本: ' + shape('\n'.join(text))
    if code == 356:
        return '356 插件: ' + ' '.join(str(p[0]).split()[:2])
    if code in (201, 301, 202, 203):
        return '%d（指定方式 %s）' % (code, p[0])
    return str(code)


def locations():
    manifest = json.loads((GEN / 'manifest.json').read_text())
    for mid in manifest['slice']['maps']:
        m = json.loads((GEN / 'maps' / ('Map%03d.json' % int(mid))).read_text())
        for ev in m.get('events', []):
            if not ev:
                continue
            for pi, page in enumerate(ev['pages']):
                yield 'm%de%dp%d' % (int(mid), ev['id'], pi), page['list']
    ces = json.loads((GEN / 'db/CommonEvents.json').read_text())
    for cid in manifest['slice']['commonEvents']:
        ce = ces[int(cid)]
        if ce:
            yield 'ce%d' % int(cid), ce['list']


def analyse(executed: set):
    known = json.loads(KNOWN.read_text())
    unreachable = set('ce' + k for k in known.get('unreachable', {}))
    rows = {}
    for loc, lst in locations():
        for i, c in enumerate(lst):
            if int(c['code']) in SKIP:
                continue
            k = key_of(lst, i)
            r = rows.setdefault(k, {'key': k, 'count': 0, 'reachableCount': 0, 'covered': 0, 'examples': []})
            r['count'] += 1
            reach = loc not in unreachable
            r['reachableCount'] += reach
            if '%s:%d' % (loc, i) in executed:
                r['covered'] += 1
            elif reach and len(r['examples']) < 4:
                r['examples'].append('%s:%d' % (loc, i))
    return sorted(rows.values(), key=lambda r: (r['covered'] > 0, -r['reachableCount'], r['key']))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--coverage', required=True)
    ap.add_argument('--out')
    ap.add_argument('--json')
    a = ap.parse_args(argv)
    executed = set(json.loads(Path(a.coverage).read_text())['executed'])
    rows = analyse(executed)
    missing = [r for r in rows if r['covered'] == 0 and r['reachableCount'] > 0]
    dead = [r for r in rows if r['covered'] == 0 and r['reachableCount'] == 0]
    have = [r for r in rows if r['covered'] > 0]
    lines = ['# 事件写法原版对照覆盖', '',
             f'写法 {len(rows)} 类：有对照例（xiyou_event_compare 里真执行到）{len(have)} 类；没有、玩家走得到 {len(missing)} 类；只在走不到的公共事件里 {len(dead)} 类。',
             '「位置」是 mMeEpP（地图 M 事件 E 第 P 页，从 0 数）或 ceN 加「:指令下标」。', '',
             '## 没有对照例（玩家走得到，按出现次数）', '', '| 写法 | 出现 | 走得到 | 例子 |', '| --- | --- | --- | --- |']
    for r in missing:
        lines.append('| `%s` | %d | %d | %s |' % (r['key'].replace('|', '\\|'), r['count'], r['reachableCount'], '、'.join(r['examples'])))
    lines += ['', '## 有对照例', '', '| 写法 | 出现 | 执行到 |', '| --- | --- | --- |']
    for r in sorted(have, key=lambda r: -r['count']):
        lines.append('| `%s` | %d | %d |' % (r['key'].replace('|', '\\|'), r['count'], r['covered']))
    if dead:
        lines += ['', '## 只在走不到的公共事件里', ''] + ['- `%s`（%d）' % (r['key'], r['count']) for r in dead]
    text = '\n'.join(lines) + '\n'
    if a.out:
        Path(a.out).write_text(text, encoding='utf-8')
    if a.json:
        Path(a.json).write_text(json.dumps({'rows': rows}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    print(f'写法 {len(rows)} 类：有对照 {len(have)}，没有且走得到 {len(missing)}，只在走不到处 {len(dead)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
