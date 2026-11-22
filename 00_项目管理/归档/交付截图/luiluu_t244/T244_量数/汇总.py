"""T244：把 baseline_dps --snapshots --duel 的 4 弱真打 json 汇成每层表（markdown 打到标准输出）。
用法：python3 汇总.py <现行.json>[,<34层.json>] [<标签>=<json>[,<json>] ...]
只算上场 4 人全是弱者的场次（allWeak 为真；核 r1 P1-1：17～34 层存档原队带强者 128 张楚岚，剔出主表，表底单列）。
普通阵容对照直接读 T363 的 d3_r6.json／d3_t298.json（不含奶妈队），两条链分开列。"""
import json, sys, statistics, pathlib, collections

def load(spec):
    rows = {}
    for p in spec.split(','):
        for r in json.load(open(p))['rows']:
            rows[int(r['floor'])] = r
    return rows

def weak(per):
    return [x for x in per if x.get('allWeak', True)]

def mixed(per):
    return [x for x in per if not x.get('allWeak', True)]

def pct(r):
    return min(1.0, float(r['dmg']) * max(1, int(r['turns'])) / max(1.0, float(r['enemyHp'])))

def wan(v):
    v = float(v)
    return f"{v/1e4:.1f}万" if v >= 1e5 else f"{int(round(v))}"

def wn(per):
    return sum(1 for x in per if x['won']), len(per)

def first_below(rows):
    for f in sorted(rows):
        w, n = wn(weak(rows[f]['per']))
        if n and w * 2 < n:
            return f
    return None

here = pathlib.Path(__file__).resolve().parent
t363dir = here.parent.parent / 'luiluu_t363' / 'T363_量数'
chains = {}
for k in ('r6', 't298'):
    p = t363dir / f'd3_{k}.json'
    if p.exists():
        chains[k] = {int(r['floor']): [x for x in r['per'] if x.get('team') != '奶妈队'] for r in json.load(open(p))['rows']}

base = load(sys.argv[1])
extra = [(a.split('=', 1)[0], load(a.split('=', 1)[1])) for a in sys.argv[2:]]
hdr = ['层', '守层者血（新表）', '**纯 4 弱 胜/场 现行 +12%/−8%**', '赢的均回合', '输的场打掉（中位·最低）', '输法（团灭/僵局）', '普通 r6 链', '极弱 t298 链'] + [f'纯 4 弱 {k}' for k, _ in extra]
print('| ' + ' | '.join(hdr) + ' |')
print('|' + '---|' * len(hdr))
for f in sorted(base):
    r = base[f]; per = weak(r['per'])
    won = [x for x in per if x['won']]; lost = [x for x in per if not x['won']]
    wipe = sum(1 for x in lost if x['lost']); stale = len(lost) - wipe
    wt = f"{statistics.mean(x['turns'] for x in won):.1f}" if won else '－'
    ps = sorted(pct(x) for x in lost)
    lp = f"{statistics.median(ps)*100:.0f}%·{ps[0]*100:.0f}%" if lost else '－'
    cells = [str(f), wan(r['enemyHp']), f"**{len(won)}/{len(per)}**", wt, lp, f"{wipe}/{stale}" if lost else '－']
    for k in ('r6', 't298'):
        c = chains.get(k, {}).get(f)
        cells.append('%d/%d' % wn(c) if c else '没量')
    for _, rows in extra:
        e = rows.get(f)
        cells.append('%d/%d' % wn(weak(e['per'])) if e else '没量')
    print('| ' + ' | '.join(cells) + ' |')

def seg(rows, a, b):
    w = n = 0
    for f in rows:
        if a <= f <= b:
            x, y = wn(weak(rows[f]['per'])); w += x; n += y
    return w, n

def seg_chain(c, a, b):
    w = n = 0
    for f, per in c.items():
        if a <= f <= b:
            x, y = wn(per); w += x; n += y
    return w, n

print('\n## 分段合计（纯 4 弱 对 普通阵容两条链）\n')
print('| 段 | 纯 4 弱 现行 | 普通 r6 链 | 极弱 t298 链 |')
print('|---|---|---|---|')
for a, b in ((1, 34), (1, 25), (17, 34), (26, 34), (31, 34)):
    cells = ['%d～%d 层' % (a, b), '%d/%d' % seg(base, a, b)]
    for k in ('r6', 't298'):
        w, n = seg_chain(chains.get(k, {}), a, b)
        cells.append(f'{w}/{n}' if n else '没量')
    print('| ' + ' | '.join(cells) + ' |')

tw, tn = seg(base, 1, 34)
print('\n## 补偿四档（纯 4 弱）\n')
print('| 补偿 | 合计 | 比现行多赢 | 挽回现行败局的比例 | 胜率第一次低于一半的层 |')
print('|---|---|---|---|---|')
print(f'| 现行 +12%/−8% | {tw}/{tn} | － | － | {first_below(base)} |')
for k, rows in extra:
    w, n = seg(rows, min(rows), max(rows))
    if n == tn:
        print(f'| {k} | {w}/{n} | {w - tw:+d} | {w - tw}/{tn - tw}（{(w - tw) / (tn - tw) * 100:.0f}%） | {first_below(rows)} |')
    else:
        bw = bn = 0
        for f in rows:
            x, y = wn(weak(base[f]['per'])); bw += x; bn += y
        fl = '、'.join(str(f) for f in sorted(rows))
        print(f'| {k}（只量 {fl} 层） | {w}/{n} | 同几层现行 {bw}/{bn}，{w - bw:+d} | {w - bw}/{bn - bw}（{(w - bw) / max(1, bn - bw) * 100:.0f}%） | {first_below(rows)} |')

print('\n## 按抽到的段异化分（现行补偿，纯 4 弱）\n')
c = collections.Counter(); w = collections.Counter()
for f in base:
    for x in weak(base[f]['per']):
        k = x['alien'][0].split(':')[-1] if x.get('alien') else '无'
        c[k] += 1; w[k] += 1 if x['won'] else 0
print('| 段异化 | 纯 4 弱 胜/场 |')
print('|---|---|')
for k in sorted(c):
    print(f'| {k} | {w[k]}/{c[k]} |')
print(f'| 合计 | {sum(w.values())}/{sum(c.values())} |')

print('\n## 剔出主表的场次（上场有强者，allWeak=false）\n')
print('| 数据 | 场数 | 胜 | 层 | 阵容 |')
print('|---|---|---|---|---|')
for k, rows in [('现行', base)] + extra:
    ms = [(f, x) for f in rows for x in mixed(rows[f]['per'])]
    if ms:
        fl = sorted({f for f, _ in ms})
        print(f"| {k} | {len(ms)} | {sum(1 for _, x in ms if x['won'])} | {fl[0]}～{fl[-1]} | {sorted({tuple(x['party']) for _, x in ms})} |")
