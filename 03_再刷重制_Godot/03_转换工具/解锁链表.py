#!/usr/bin/env python3
"""传送／解锁链表（cc 悟空 accept3，只读）。

扫切片里全部地图事件页与公共事件，找出每条「场所移动」（指令 201、脚本里的 reserveTransfer），
记下它要满足的条件：事件页出现条件（开关、变量、独立开关、物品、角色）＋外层「条件分歧」（111）链
＋所在选项分支（402），以及触发方式。再按「来源图 → 目标图」汇总，对照 tests/*.gd 有没有专项
真走过这一跳（测试里同时点名来源图、并 `_wait_map(目标图)`），列出缺口。

用法：解锁链表.py [--md 输出.md] [--json 输出.json] [--gaps-only]
重制在哪实现：地图事件页由 `modes/xiyou/map` 的事件解释器按原版页条件执行（`xiyou_event_compare` 逐页对照），
本表只列原版条件；「测试」列给出真走了这一跳的地图场景专项。
"""
import argparse, json, re
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'
TESTS = HERE.parent / '01_Godot工程/tests'
TRIG = {0: '确定键', 1: '玩家接触', 2: '事件接触', 3: '自动', 4: '并行'}
CMP = ['==', '>=', '<=', '>', '<', '!=']


def load(p):
    return json.loads(Path(p).read_text())


class Names:
    def __init__(self):
        sysj = load(GEN / 'db/System.json')
        self.sw = sysj.get('switches', [])
        self.var = sysj.get('variables', [])
        self.items = {i['id']: i['name'] for i in load(GEN / 'db/Items.json') if i}
        self.actors = {i['id']: i['name'] for i in load(GEN / 'db/Actors.json') if i}
        self.maps = {m['id']: m['name'] for m in load(GEN / 'db/MapInfos.json') if m}

    def s(self, i):
        n = self.sw[i] if 0 <= i < len(self.sw) else ''
        return 'S%d%s' % (i, '「%s」' % n if n else '')

    def v(self, i):
        n = self.var[i] if 0 <= i < len(self.var) else ''
        return 'V%d%s' % (i, '「%s」' % n if n else '')


def page_conds(c, N):
    out = []
    if c.get('switch1Valid'):
        out.append(N.s(c['switch1Id']) + ' 开')
    if c.get('switch2Valid'):
        out.append(N.s(c['switch2Id']) + ' 开')
    if c.get('variableValid'):
        out.append('%s >= %s' % (N.v(c['variableId']), c['variableValue']))
    if c.get('selfSwitchValid'):
        out.append('独立开关 %s' % c['selfSwitchCh'])
    if c.get('itemValid'):
        out.append('持有物品 %d「%s」' % (c['itemId'], N.items.get(c['itemId'], '')))
    if c.get('actorValid'):
        out.append('队里有角色 %d「%s」' % (c['actorId'], N.actors.get(c['actorId'], '')))
    return out


def branch_text(p, N):
    t = p[0]
    if t == 0:
        return '%s %s' % (N.s(p[1]), '开' if p[2] == 0 else '关')
    if t == 1:
        rhs = str(p[3]) if p[2] == 0 else N.v(p[3])
        return '%s %s %s' % (N.v(p[1]), CMP[p[4]] if p[4] < len(CMP) else '?', rhs)
    if t == 2:
        return '独立开关 %s %s' % (p[1], '开' if p[2] == 0 else '关')
    if t == 4:
        sub = ['在队', '名字', '职业', '学会技能', '装备武器', '装备防具', '状态'][p[2]] if p[2] < 7 else '?'
        return '角色 %d「%s」%s %s' % (p[1], N.actors.get(p[1], ''), sub, p[3] if len(p) > 3 else '')
    if t == 7:
        return '金钱 %s %s' % (['>=', '<=', '<'][p[2]] if p[2] < 3 else '?', p[1])
    if t == 8:
        return '持有物品 %d「%s」' % (p[1], N.items.get(p[1], ''))
    if t in (9, 10):
        return '持有%s %d' % ('武器' if t == 9 else '防具', p[1])
    if t == 99:
        return '（前面已代入常量，静态%s）' % ('成立' if p[1] else '不成立')
    if t == 12:
        return '脚本 `%s`' % str(p[1]).replace('|', '／')[:90]
    return '分歧类型 %d %s' % (t, p[1:3])


SCRIPT_TRANSFER = re.compile(r'reserveTransfer\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)')


def scan_list(lst, N):
    """逐条走指令表，返回 [(dest_map, x, y, [条件], kind)]；dest_map 为 None 时是变量指定。"""
    out = []
    stack = []  # (indent, 文本, 原始条件)
    last_branch = {}  # indent -> 111 文本（给 411 else 取反）
    choices = {}  # indent -> 选项文字列表
    calls = []
    wrote_v, wrote_s = set(), set()  # 本表前面改过的变量／开关（条件分歧读它们时预设无效）
    known_v = {}  # 本表前面代入了常量的变量
    for cmd in lst:
        code, ind, p = cmd['code'], cmd['indent'], cmd['parameters']
        while stack and stack[-1][0] >= ind:
            stack.pop()
        if code == 111:
            txt = branch_text(p, N)
            if p[0] == 1 and p[2] == 0 and p[1] in known_v:
                kv, k = known_v[p[1]], p[3]
                p = [99, [kv == k, kv >= k, kv <= k, kv > k, kv < k, kv != k][p[4]]]  # 静态：真／假
            dirty = (p[0] == 1 and (p[1] in wrote_v or (p[2] == 1 and p[3] in wrote_v))) or (p[0] == 0 and p[1] in wrote_s)
            last_branch[ind] = (txt, p, dirty)
            stack.append((ind, txt, {'k': 'branch', 'p': p, 'neg': False, 'dirty': dirty}))
        elif code == 411:
            t, bp, dirty = last_branch.get(ind, ('?', None, False))
            stack.append((ind, '否：' + t, {'k': 'branch', 'p': bp, 'neg': True, 'dirty': dirty}))
        elif code == 102:
            choices[ind] = p[0]
        elif code == 402:
            stack.append((ind, '选「%s」' % p[1], {'k': 'choice', 'i': p[0], 'n': len(choices.get(ind, []))}))
        elif code == 403:
            stack.append((ind, '选「取消」', {'k': 'choice', 'i': -1}))
        elif code == 117:
            calls.append(p[0])
        elif code == 122:
            for v in range(p[0], p[1] + 1):
                if p[2] == 0 and p[3] == 0:
                    known_v[v] = p[4]  # 代入常量：分歧可静态判定
                    wrote_v.discard(v)
                else:
                    known_v.pop(v, None)
                    wrote_v.add(v)
        elif code == 121:
            wrote_s.update(range(p[0], p[1] + 1))
        elif code == 201:
            conds = [t for _, t, _r in stack]
            raw = [r for _, _t, r in stack]
            if p[0] == 0:
                out.append((p[1], p[2], p[3], conds, '移动', raw))
            else:
                out.append((None, '%s' % N.v(p[1]), N.v(p[2]), conds, '移动（变量指定）', raw))
        elif code in (355, 655):
            for m in SCRIPT_TRANSFER.finditer(str(p[0])):
                out.append((int(m.group(1)), int(m.group(2)), int(m.group(3)), [t for _, t, _r in stack], '脚本移动', [r for _, _t, r in stack]))
    return out, calls


INV = {0: 5, 1: 4, 2: 3, 3: 2, 4: 1, 5: 0}  # 取反后的比较


def solve(r):
    """把页条件＋分歧链解成一份开局状态；解不出返回 None。"""
    rec = {'switches': {}, 'vars': {}, 'items': {}, 'self': {}, 'actors': [], 'gold': 0, 'answers': []}
    c = r['page_raw']

    def setv(k, d, v):
        if k in d and d[k] != v:
            return False
        d[k] = v
        return True

    if c.get('switch1Valid') and not setv(str(c['switch1Id']), rec['switches'], True):
        return None
    if c.get('switch2Valid') and not setv(str(c['switch2Id']), rec['switches'], True):
        return None
    if c.get('variableValid'):
        rec['vars'][str(c['variableId'])] = c['variableValue']
    if c.get('selfSwitchValid'):
        rec['self'][c['selfSwitchCh']] = True
    if c.get('itemValid'):
        rec['items'][str(c['itemId'])] = 1
    if c.get('actorValid'):
        rec['actors'].append(c['actorId'])
    for b in r['raw']:
        if b['k'] == 'choice':
            if b['i'] < 0:
                return None
            rec['answers'].append(b['i'])
            continue
        p, neg = b['p'], b['neg']
        if p is None or b.get('dirty'):
            return None
        t = p[0]
        if t == 0:
            if not setv(str(p[1]), rec['switches'], (p[2] == 0) != neg):
                return None
        elif t == 2:
            if not setv(p[1], rec['self'], (p[2] == 0) != neg):
                return None
        elif t == 1:
            if p[2] != 0:
                return None
            op = INV[p[4]] if neg else p[4]
            k = p[3]
            want = {0: k, 1: k, 2: k, 3: k + 1, 4: k - 1, 5: k + 1}[op]
            cur = rec['vars'].get(str(p[1]))
            if cur is not None:
                okv = [cur == k, cur >= k, cur <= k, cur > k, cur < k, cur != k][op]
                if not okv:
                    if c.get('variableValid') and str(c['variableId']) == str(p[1]) and want >= c['variableValue']:
                        rec['vars'][str(p[1])] = want
                    else:
                        return None
            else:
                rec['vars'][str(p[1])] = want
        elif t == 7:
            if neg or p[2] != 0:
                return None
            rec['gold'] = max(rec['gold'], p[1])
        elif t == 8:
            if neg:
                if str(p[1]) in rec['items']:
                    return None
                rec['items'][str(p[1])] = 0
            else:
                rec['items'][str(p[1])] = max(1, rec['items'].get(str(p[1]), 0))
        elif t == 99:
            if p[1] == neg:
                return None
        else:
            return None
    return rec


def test_index():
    """每个测试文件：点名的地图集合、_wait_map 等到的地图集合。"""
    idx = {}
    num = r'(\d{1,3})'
    for f in sorted(TESTS.glob('xiyou_*.gd')):
        txt = f.read_text(errors='ignore')
        consts = {k: int(v) for k, v in re.findall(r'const\s+(\w+)\s*(?::=|:\s*int\s*=|=)\s*(\d{1,3})\b', txt)}
        waits = {int(x) for x in re.findall(r'_wait_map\(\s*' + num + r'\b', txt)}
        waits |= {consts[k] for k in re.findall(r'_wait_map\(\s*(\w+)\s*[,)]', txt) if k in consts}
        starts = {int(x) for x in re.findall(r'(?:_start|_goto|_enter)\(\s*' + num + r'\b', txt)}
        starts |= {int(x) for x in re.findall(r'map_id\s*=\s*' + num + r'\b', txt)}
        starts |= {consts[k] for k in re.findall(r'(?:_start|_goto)\(\s*(\w+)\s*,', txt) if k in consts}
        if waits or starts:
            idx[f.stem] = (starts | waits, waits)
    return idx


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--md')
    ap.add_argument('--json')
    ap.add_argument('--gaps-only', action='store_true')
    ap.add_argument('--cases', help='给每个「还没有专项真走到」的目标图挑一条可解的入口，写成表驱动用例 JSON')
    ap.add_argument('--skip', default='', help='挑用例时跳过的来源（逗号分隔，如 m12e28p1）')
    a = ap.parse_args()
    N = Names()
    rows = []
    ce_calls = defaultdict(list)  # ce id -> [来源]
    for f in sorted((GEN / 'maps').glob('Map*.json')):
        mid = int(f.stem[3:])
        m = load(f)
        for e in m['events']:
            if not e:
                continue
            for pi, pg in enumerate(e['pages']):
                tr, calls = scan_list(pg['list'], N)
                src = 'm%de%dp%d' % (mid, e['id'], pi)
                for c in calls:
                    ce_calls[c].append(src)
                pc = page_conds(pg['conditions'], N)
                for d, x, y, conds, kind, raw in tr:
                    rows.append(dict(src_map=mid, src=src, ev_name=e['name'], pos=[e['x'], e['y']], trigger=TRIG.get(pg['trigger'], pg['trigger']),
                                     dest=d, xy=[x, y], page_conds=pc, branch=conds, kind=kind, raw=raw, page_raw=pg['conditions'],
                                     ev=e['id'], page=pi, trig=pg['trigger']))
    ces = load(GEN / 'db/CommonEvents.json')
    for ce in ces:
        if not ce:
            continue
        tr, calls = scan_list(ce['list'], N)
        for c in calls:
            ce_calls[c].append('ce%d' % ce['id'])
        pc = []
        if ce.get('trigger') in (1, 2):
            pc = ['%s触发：%s 开' % ('自动' if ce['trigger'] == 1 else '并行', N.s(ce['switchId']))]
        for d, x, y, conds, kind, raw in tr:
            rows.append(dict(src_map=None, src='ce%d' % ce['id'], ev_name=ce['name'], pos=None, trigger='公共事件', dest=d, xy=[x, y],
                             page_conds=pc, branch=conds, kind=kind))
    for r in rows:
        if r['src'].startswith('ce'):
            r['callers'] = ce_calls.get(int(r['src'][2:]), [])[:8]
    tidx = test_index()
    chain = TESTS / 'fixtures/unlock_chain_cases.json'
    chain_ids = {c['id'] for c in load(chain)['cases']} if chain.exists() else set()

    def covered(r):
        if r['dest'] is None:
            return []
        if r['src'] in chain_ids:
            return ['xiyou_unlock_chain']
        srcs = {r['src_map']} if r['src_map'] else {int(re.match(r'm(\d+)', c).group(1)) for c in r.get('callers', []) if c.startswith('m')}
        return sorted(t for t, (mentions, waits) in tidx.items() if r['dest'] in waits and (srcs & mentions or not srcs))

    for r in rows:
        r['tests'] = covered(r)
        r['gated'] = bool(r['page_conds'] or r['branch'])
    # 汇总到「来源图 → 目标图」
    pairs = defaultdict(list)
    for r in rows:
        key = (r['src_map'] if r['src_map'] else r['src'], r['dest'])
        pairs[key].append(r)
    gated = [r for r in rows if r['gated'] and r['dest'] is not None]
    gaps = [r for r in gated if not r['tests']]
    in_slice = set(load(HERE / 'xiyou_slice.json')['maps'])
    lines = ['# 传送／解锁链表（自动生成，`03_转换工具/解锁链表.py`）', '',
             '场所移动共 %d 处（地图事件页 %d、公共事件 %d），来源→目标对 %d；带条件的 %d 处，其中 %d 处没有地图场景专项真走过（`_wait_map(目标)` 且点名来源图）。' % (
                 len(rows), sum(1 for r in rows if r['src_map']), sum(1 for r in rows if not r['src_map']), len(pairs), len(gated), len(gaps)), '',
             '「重制在哪实现」：全部由地图事件解释器按原版页条件／条件分歧执行（`modes/xiyou/map`），逐页结果有 `xiyou_event_compare` 对照；本表的「测试」列只认真在地图场景里走过这一跳的专项。', '',
             '## 按目标图汇总', '', '| 目标图 | 名称 | 入口数 | 带条件 | 有专项真走 | 专项 |', '| ---: | --- | ---: | ---: | ---: | --- |']
    by_dest = defaultdict(list)
    for r in rows:
        if r['dest'] is not None:
            by_dest[r['dest']].append(r)
    for d in sorted(by_dest):
        rs = by_dest[d]
        ts = sorted({t for r in rs for t in r['tests']})
        lines.append('| %d | %s%s | %d | %d | %d | %s |' % (d, N.maps.get(d, ''), '' if d in in_slice else '（不在切片）', len(rs), sum(r['gated'] for r in rs),
                                                         sum(1 for r in rs if r['tests']), '、'.join(ts[:3]) + ('…' if len(ts) > 3 else '') or '无'))
    lines += ['', '## 逐条（%s）' % ('只列带条件且无专项的' if a.gaps_only else '带条件的'), '',
              '| 来源 | 事件 | 触发 | → 目标 (x,y) | 原版条件（页条件；分歧链） | 专项 |', '| --- | --- | --- | --- | --- | --- |']
    for r in (gaps if a.gaps_only else gated):
        dest = '%d「%s」(%s,%s)' % (r['dest'], N.maps.get(r['dest'], ''), r['xy'][0], r['xy'][1])
        cond = '；'.join(r['page_conds']) + ('｜' if r['page_conds'] and r['branch'] else '') + ' → '.join(r['branch'])
        src = r['src'] + ('（调用者 %s）' % '、'.join(r['callers'][:3]) if r.get('callers') else '')
        lines.append('| %s | %s | %s | %s | %s | %s |' % (src, str(r['ev_name']).replace('|', '／'), r['trigger'], dest, cond.replace('|', '／') or '—',
                                                    '、'.join(r['tests'][:2]) or '**无**'))
    if a.cases:
        skip = set(x for x in a.skip.split(',') if x)
        out = []
        for d in sorted(by_dest):
            rs = by_dest[d]
            if any(t != 'xiyou_unlock_chain' for r in rs for t in r['tests']):
                continue  # 重新生成时不把本专项自己算作已覆盖
            cand = []
            for r in rs:
                if not r['src_map'] or r['src_map'] not in in_slice or r['src'] in skip or r['src_map'] == d:
                    continue
                rec = solve(r)
                if rec is None:
                    continue
                cand.append((r['trig'] not in (0, 1, 2), len(r['raw']) + len(r['page_conds']), r['src'], r, rec))
            if not cand:
                continue
            cand.sort(key=lambda t: t[:3])
            _, _, _, r, rec = cand[0]
            out.append(dict(id=r['src'], src_map=r['src_map'], ev=r['ev'], page=r['page'], pos=r['pos'], dest=d, xy=r['xy'],
                            cond='；'.join(r['page_conds'] + r['branch']), **rec))
        Path(a.cases).write_text(json.dumps({'note': '解锁链表.py --cases 生成，勿手改；跳过的入口写在 skip', 'skip': sorted(skip), 'cases': out},
                                            ensure_ascii=False, indent=1) + '\n')
        print('用例 %d（目标图未被专项真走到且可解）' % len(out))
    md = '\n'.join(lines) + '\n'
    if a.md:
        Path(a.md).write_text(md)
    if a.json:
        Path(a.json).write_text(json.dumps(rows, ensure_ascii=False, indent=1))
    print('\n'.join(lines[:3]))


main()
