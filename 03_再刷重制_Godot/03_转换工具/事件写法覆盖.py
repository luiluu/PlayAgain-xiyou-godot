#!/usr/bin/env python3
"""事件写法有没有原版对照（cc eventsreg1，只读）：切片里地图事件页与公共事件的每条指令按「写法」归类，
再看 xiyou_event_compare 跑原版对照用例时（--coverage 记下的「位置:下标」）有没有真执行到它。

写法键：指令码＋要紧的子类——111 按条件类型（脚本条件再按脚本形状）、122 按操作数类型（脚本操作数按脚本形状）、
355／655 按整段脚本的形状（数字→N、字符串→S、空白合并，前 80 字）、356 按插件指令前两个词、201／301 按指定方式，其余只看指令码。
续行（401／405／408／605 等）、分支尾（0／411／412／402／403／404／601～604 的结构行）不单算。

  事件写法覆盖.py --coverage <xiyou_event_compare --coverage 写的 JSON> [--out 报告.md] [--json 结果.json]
  事件写法覆盖.py --coverage <JSON> --missed 126,128 [--missed-out 簇.md] [--missed-json 簇.json] [--suggest 候选预设.json]

--missed（八戒 events8）：按实例列出这些写法「出现但没执行到」的位置，按「门」聚簇——门＝离它最近、本身执行到了的上层分支头
（111 条件、402 选项、411 否则、601～603 战斗结果、403 取消、413 循环），门下没走进去的一串算一簇；整页没执行到的算「整页没进」。
簇再按地图／公共事件归组，按簇里目标实例数排序，只列玩家走得到的。--suggest 给「简单门」（开关、变量比常量、物品、武器、防具、
角色在队、角色学会技能、金钱、独立开关）写出能让门打开的预设候选（event_presets.json 的 cases 格式，tag 用 e8），要不要采用由人挑。
没选中的选项（402）出 answers（外层选项项号＋本项号，events9）；取消（403）、随机、脚本条件这类门列成「留给新能力」。

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


GATE = {111, 402, 403, 411, 601, 602, 603, 413, 112}


def top_of(lst, i):
    """i 所在的顶层（缩进 0）那条指令的下标（i 自己在顶层时就是 i）。"""
    ind = int(lst[i].get('indent', 0))
    j = i
    while j > 0 and ind > 0:
        j -= 1
        if int(lst[j].get('indent', 0)) < ind:
            ind = int(lst[j].get('indent', 0))
    return j


def label_jump(lst, i):
    """i 在顶层标签段里（前面最近的顶层 118 之后）时，跳进这一段的 119 的下标；不在标签段或没有段外的跳转时返回 None（八戒 interp5）。
    标签段多在 115 之后，只有 119 跳进来才走得到（m116 等「见面礼」：外层选项 119 跳到标签，标签段里再出选单）。"""
    top = top_of(lst, i)
    k = top
    while k >= 0 and not (int(lst[k]['code']) == 118 and int(lst[k].get('indent', 0)) == 0):
        k -= 1
    if k < 0:
        return None
    name = str(lst[k]['parameters'][0])
    end = k + 1
    while end < len(lst) and not (int(lst[end]['code']) == 118 and int(lst[end].get('indent', 0)) == 0):
        end += 1
    jumps = [x for x, c in enumerate(lst) if int(c['code']) == 119 and str(c['parameters'][0]) == name and not (k <= x < end)]
    return jumps[0] if jumps else None


def gate_of(lst, i, executed, loc, depth=0):
    """挡住 i 的门：离它最近、本身执行到了的上层分支头；中间隔着没选中的选项（402／403 头没执行到）时，门是最外那个选项头。
    整页没进返回 None。顶层没有执行到的头、又在标签段里时，沿跳进来的 119 往外找门（interp5）。"""
    ind = int(lst[i].get('indent', 0))
    j = i - 1
    choice = None
    while j >= 0 and ind > 0:
        cj = lst[j]
        if int(cj.get('indent', 0)) == ind - 1:
            if '%s:%d' % (loc, j) in executed:
                return choice if choice is not None else j
            if int(cj['code']) in (402, 403):
                choice = j
            ind -= 1
        j -= 1
    if choice is None and depth < 4:
        x = label_jump(lst, i)
        if x is not None and '%s:%d' % (loc, x) not in executed:
            return gate_of(lst, x, executed, loc, depth + 1)
    return choice


def describe_gate(lst, j):
    c = lst[j]
    code, p = int(c['code']), c.get('parameters', [])
    if code == 111:
        return '111 ' + cond_text(p)
    if code == 411:
        k = j - 1
        while k >= 0 and not (int(lst[k]['code']) == 111 and lst[k].get('indent', 0) == c.get('indent', 0)):
            k -= 1
        return '411 否则（%s）' % (cond_text(lst[k]['parameters']) if k >= 0 else '?')
    if code == 402:
        return '402 选项 %s「%s」（没选中）' % (p[0], p[1])
    if code == 403:
        return '403 取消（没选中）'
    if code in (601, 602, 603):
        return {601: '601 战胜', 602: '602 逃跑', 603: '603 战败'}[code]
    return str(code)


OPS = ['==', '>=', '<=', '>', '<', '!=']


def cond_text(p):
    t = int(p[0])
    if t == 0:
        return '开关 %s 为 %s' % (p[1], 'ON' if int(p[2]) == 0 else 'OFF')
    if t == 1:
        return '变量 %s %s %s%s' % (p[1], OPS[int(p[4])], '变量 ' if int(p[2]) else '', p[3])
    if t == 2:
        return '独立开关 %s 为 %s' % (p[1], 'ON' if int(p[2]) == 0 else 'OFF')
    if t == 4:
        return '角色 %s 子类 %s %s' % (p[1], p[2], p[3] if len(p) > 3 else '')
    if t == 7:
        return '金钱 %s %s' % (['>=', '<=', '<'][int(p[2])], p[1])
    if t in (8, 9, 10):
        return '%s %s 持有' % (COND[t], p[1])
    if t == 12:
        return '脚本 ' + str(p[1])[:60]
    return COND.get(t, str(t)) + ' ' + str(p[1:])[:40]


def choice_index(lst, j):
    """402（下标 j）在玩家看到的选项里是第几项：紧挨着的几个 102（中间只隔 404）会并成一个菜单（再刷的选项扩展），
    后面 102 的项号要加上前面 102 的项数（m187 种植 14 项分三段）。"""
    ind = lst[j].get('indent', 0)
    k = j - 1
    while k >= 0 and not (int(lst[k]['code']) == 102 and lst[k].get('indent', 0) == ind):
        k -= 1
    off = 0
    while k > 0 and int(lst[k - 1]['code']) == 404 and lst[k - 1].get('indent', 0) == ind:
        k2 = k - 2
        while k2 >= 0 and not (int(lst[k2]['code']) == 102 and lst[k2].get('indent', 0) == ind):
            k2 -= 1
        if k2 < 0:
            break
        off += len(lst[k2]['parameters'][0])
        k = k2
    return off + int(lst[j]['parameters'][0])


def choice_path(lst, j):
    """选到 402（下标 j）要的应答串：外层每个 402 祖先的项号（从外到里），最后是 j 自己的项号（八戒 events9）。
    同一页里在它前面还先问过别的选项时会错位，由对照覆盖核实。"""
    picks = [choice_index(lst, j)]
    ind = int(lst[j].get('indent', 0))
    k = j - 1
    while k >= 0 and ind > 0:
        ck = lst[k]
        if int(ck.get('indent', 0)) == ind - 1:
            if int(ck['code']) == 402:
                picks.insert(0, choice_index(lst, k))
            ind -= 1
        k -= 1
    return picks


def open_preset(lst, j, loc):
    """让门 j 打开的预设（只管简单门）；做不到返回 None。"""
    c = lst[j]
    code, p = int(c['code']), c.get('parameters', [])
    want = True
    if code == 411:
        k = j - 1
        while k >= 0 and not (int(lst[k]['code']) == 111 and lst[k].get('indent', 0) == c.get('indent', 0)):
            k -= 1
        if k < 0:
            return None
        p, want = lst[k]['parameters'], False
    elif code == 402:
        return {'answers': choice_path(lst, j)}
    elif code in (602, 603):
        # 战斗结果门（八戒 interp4）：两边都认预设 battleResult（0 胜、1 逃、2 败），参照 event_state_probe 的战斗回调、
        # 重制 xiyou_event_compare 的 preset_battle_result 都按它走；602 逃跑、603 战败
        return {'battleResult': 1 if code == 602 else 2}
    elif code != 111:
        return None
    t = int(p[0])
    if t == 0:
        on = int(p[2]) == 0
        return {'switches': {str(p[1]): on == want}}
    if t == 1 and not int(p[2]):
        v, op = float(p[3]), int(p[4])
        sat = {0: v, 1: v, 2: v, 3: v + 1, 4: v - 1, 5: v + 1}[op]
        uns = {0: v + 1, 1: v - 1, 2: v + 1, 3: v, 4: v, 5: v}[op]
        x = sat if want else uns
        return {'variables': {str(p[1]): int(x) if x == int(x) else x}}
    if t == 2 and loc.startswith('m'):
        m, e = loc[1:].split('p')[0].split('e')
        on = int(p[2]) == 0
        return {'selfSwitches': {'%s,%s,%s' % (m, e, p[1]): on == want}} if on == want else None
    if t in (8, 9, 10) and want:
        return {{8: 'items', 9: 'weapons', 10: 'armors'}[t]: {str(p[1]): 1}}
    if t in (8, 9, 10) and not want:
        # 「否则（没持有）」：新开局本来就没有，给 0 个（两边 gain 0 不改状态），只为祖先链合成时不当开不了的门（八戒 DR w13：矿洞层层「否则物品」）
        return {{8: 'items', 9: 'weapons', 10: 'armors'}[t]: {str(p[1]): 0}}
    if t == 4 and int(p[2]) == 0 and want:
        return {'party': [int(p[1])]}
    if t == 4 and int(p[2]) == 3 and want:   # 角色学会了技能
        return {'actors': {str(p[1]): {'skills': [int(p[3])]}}}
    if t == 4 and int(p[2]) == 5 and want:   # 角色装备了防具（八戒 DR：ce1213 命运之手「角色 94 装备 4521」）
        return {'actors': {str(p[1]): {'armors': [int(p[3])]}}}
    if t == 4 and int(p[2]) == 4 and want:   # 角色装备了武器（八戒 DR w15：ce682 等）
        return {'actors': {str(p[1]): {'weapons': [int(p[3])]}}}
    if t == 4 and int(p[2]) in (3, 4) and not want:   # 「否则（没学会技能／没装备武器）」：新开局默认没有，空预设占位，走不到的会被剪掉
        return {'actors': {str(p[1]): {}}}
    if t == 4 and int(p[2]) == 5 and not want:   # 「否则（没装备）」：新开局默认没穿，空预设占位（角色本来就穿着的，目标走不到会被剪掉）
        return {'actors': {str(p[1]): {}}}
    if t == 1 and int(p[2]) and int(p[3]) != int(p[1]):
        # 变量比变量（八戒 interp4）：右边变量设 0，左边按比常量 0 取值
        op = int(p[4])
        sat = {0: 0, 1: 0, 2: 0, 3: 1, 4: -1, 5: 1}[op]
        uns = {0: 1, 1: -1, 2: 1, 3: 0, 4: 0, 5: 0}[op]
        return {'variables': {str(p[1]): sat if want else uns, str(p[3]): 0}}
    if t == 6 and int(p[1]) == -1:
        # 玩家朝向（八戒 interp4）：预设 playerDirection 两边都认（accept5）；「否则」取别的方向
        d = int(p[2])
        return {'playerDirection': d if want else (8 if d == 2 else 2)}
    if t == 7 and want and int(p[2]) == 0:
        return {'gold': int(p[1])}
    if t == 12 and want:
        m = VAR_OR.match(str(p[1]))
        if m:   # 「$gameVariables.value(V) === N || …」：取第一项（八戒 interp4）
            return {'variables': {m.group(1): int(m.group(2))}}
    if t == 12:
        return playtime_preset(str(p[1]), want)
    return None


VAR_OR = re.compile(r'^\s*\$gameVariables\.value\((\d+)\)\s*===?\s*(-?\d+)\s*(?:\|\|.*)?;?\s*$')
PLAYTIME = re.compile(r'^\s*\$gameSystem\.playtime\(\)\s*(?:-\s*\$gameVariables\.value\((\d+)\)\s*)?(>=|>|<=|<)\s*(\d+)\s*;?\s*$')


def playtime_preset(js, want):
    """脚本条件「$gameSystem.playtime() [- 变量 V] 比 N」（cc 八戒 events14，playtime 预设键见 BY）：
    给游玩秒数 playtime，有变量时把 V 设 0。要「不成立」时只认 >= ／> 且 N>0（游玩 0 秒）。其余脚本返回 None。"""
    m = PLAYTIME.match(js)
    if not m:
        return None
    v, op, n = m.group(1), m.group(2), int(m.group(3))
    if want:
        sec = {'>=': n, '>': n + 1, '<=': 0, '<': 0}[op]
        if op == '<' and n <= 0:
            return None
    else:
        if op not in ('>=', '>') or n <= 0:
            return None
        sec = 0
    out = {'playtime': sec}
    if v:
        out['variables'] = {v: 0}
    return out


def missed(executed: set, targets: set, cases: set):
    known = json.loads(KNOWN.read_text())
    unreachable = set('ce' + k for k in known.get('unreachable', {}))
    clusters = {}
    entered = {x.split(':')[0] for x in executed}   # 开头的 101 常随 102 一起消费、不单记下标，所以按「本页有任何一条执行到」算进过
    for loc, lst in locations():
        if loc in unreachable:
            continue
        for i, c in enumerate(lst):
            if int(c['code']) in SKIP:
                continue
            k = key_of(lst, i)
            if k not in targets or '%s:%d' % (loc, i) in executed:
                continue
            g = gate_of(lst, i, executed, loc) if loc in entered else None
            ck = (loc, g)
            cl = clusters.get(ck)
            if cl is None:
                if g is None:
                    why = '整页没进' if loc in cases else '不在对照用例里'
                    gate, pre = why, None
                else:
                    gate, pre = describe_gate(lst, g), open_preset(lst, g, loc)
                cl = clusters[ck] = {'loc': loc, 'gate': g, 'gateText': gate, 'preset': pre, 'hits': {}, 'first': i}
            cl['hits'][k] = cl['hits'].get(k, 0) + 1
    out = list(clusters.values())
    for cl in out:
        cl['n'] = sum(cl['hits'].values())
        cl['group'] = cl['loc'].split('e')[0] if cl['loc'].startswith('m') else cl['loc']
    out.sort(key=lambda c: (-c['n'], c['loc']))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--coverage', required=True)
    ap.add_argument('--out')
    ap.add_argument('--json')
    ap.add_argument('--missed', help='写法键（逗号分隔，可写指令码前缀如 126）')
    ap.add_argument('--missed-out')
    ap.add_argument('--missed-json')
    ap.add_argument('--suggest')
    a = ap.parse_args(argv)
    executed = set(json.loads(Path(a.coverage).read_text())['executed'])
    if a.missed:
        return run_missed(a, executed)
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


def run_missed(a, executed):
    want = [w.strip() for w in a.missed.split(',') if w.strip()]
    keys = {r['key'] for r in analyse(executed)}
    targets = {k for k in keys if any(k == w or k.split(' ')[0] == w for w in want)}
    oracle = json.loads((GEN / 'oracle/events.json').read_text())
    cases = {str(c['id']) for c in oracle['cases']}
    out = missed(executed, targets, cases)
    groups = {}
    for cl in out:
        g = groups.setdefault(cl['group'], {'group': cl['group'], 'n': 0, 'clusters': []})
        g['n'] += cl['n']
        g['clusters'].append(cl)
    gl = sorted(groups.values(), key=lambda g: -g['n'])
    simple = [c for c in out if c['preset']]
    need = {}
    for c in out:
        if not c['preset']:
            kind = c['gateText'].split(' ')[0] if c['gate'] is not None else c['gateText']
            if c['gateText'].startswith('111 脚本') or c['gateText'].startswith('411 否则（脚本'):
                kind = '脚本条件'
            need[kind] = need.get(kind, 0) + c['n']
    total = sum(c['n'] for c in out)
    lines = ['# 没执行到的实例（按门聚簇）', '', '写法：' + '、'.join('`%s`' % t for t in sorted(targets)), '',
             f'玩家走得到、没执行到的实例 {total} 个，{len(out)} 簇；其中门是简单条件、能直接写预设的 {sum(c["n"] for c in simple)} 个（{len(simple)} 簇）。', '',
             '## 门的种类（不能直接写预设的）', '', '| 门 | 实例 |', '| --- | --- |']
    for k, n in sorted(need.items(), key=lambda x: -x[1]):
        lines.append('| %s | %d |' % (k, n))
    lines += ['', '## 按地图／公共事件（前 60 组）', '']
    for g in gl[:60]:
        lines.append('### %s（%d）' % (g['group'], g['n']))
        lines.append('')
        for c in g['clusters'][:12]:
            hits = '、'.join('%s×%d' % (k.split(' ')[0], n) for k, n in c['hits'].items())
            where = '%s:%s' % (c['loc'], c['gate']) if c['gate'] is not None else c['loc']
            lines.append('- `%s` %s → %s%s' % (where, c['gateText'].replace('|', '\\|'), hits,
                                                '　预设 `%s`' % json.dumps(c['preset'], ensure_ascii=False) if c['preset'] else ''))
        if len(g['clusters']) > 12:
            lines.append('- ……另 %d 簇' % (len(g['clusters']) - 12))
        lines.append('')
    text = '\n'.join(lines) + '\n'
    if a.missed_out:
        Path(a.missed_out).write_text(text, encoding='utf-8')
    if a.missed_json:
        Path(a.missed_json).write_text(json.dumps({'clusters': out}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    if a.suggest:
        sug = [{'base': c['loc'], 'tag': 'e8', 'preset': c['preset'], 'gate': '%s:%s %s' % (c['loc'], c['gate'], c['gateText']), 'n': c['n']}
               for c in simple if c['loc'] in cases]
        Path(a.suggest).write_text(json.dumps(sug, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    print(f'没执行到 {total} 个，{len(out)} 簇；简单门 {sum(c["n"] for c in simple)} 个（{len(simple)} 簇）')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
