"""T244：把 baseline_dps --snapshots --duel 的 4 弱真打 json 汇成一张每层表（markdown 打到标准输出）。
用法：python3 汇总.py <现行.json>[,<34层.json>] [<标签>=<json>[,<json>] ...]
第一个是现行补偿（+12%／−8%），其余按标签加一列胜率；同时读 T363 对比表里普通阵容的胜/队作对照。"""
import json, re, sys, statistics, pathlib

def load(spec):
    rows = {}
    for p in spec.split(','):
        for r in json.load(open(p))['rows']:
            rows[int(r['floor'])] = r
    return rows

def pct(r):
    tot = float(r['dmg']) * max(1, int(r['turns']))
    return min(1.0, tot / max(1.0, float(r['enemyHp'])))

def wan(v):
    v = float(v)
    return f"{v/1e4:.1f}万" if v >= 1e5 else f"{int(round(v))}"

here = pathlib.Path(__file__).resolve().parent
t363 = {}
md = here.parent.parent / 'luiluu_t363' / 'T363_量数' / '对比表.md'
if md.exists():
    for line in md.read_text().splitlines():
        c = [x.strip() for x in line.split('|')]
        if len(c) > 12 and c[1].isdigit():
            t363[int(c[1])] = c[11].replace('*', '')   # 普通 胜/队 T363

base = load(sys.argv[1])
extra = [(a.split('=', 1)[0], load(a.split('=', 1)[1])) for a in sys.argv[2:]]
hdr = ['层', '守层者血（新表）', '**4 弱 胜/队 现行 +12%/−8%**', '赢的均回合', '输的队打掉（中位·最低）', '输法（团灭/僵局）', '普通阵容 T363 胜/队'] + [f'4 弱 {k}' for k, _ in extra]
print('| ' + ' | '.join(hdr) + ' |')
print('|' + '---|' * len(hdr))
first_fail = None
for f in sorted(base):
    r = base[f]; per = r['per']
    won = [x for x in per if x['won']]
    lost = [x for x in per if not x['won']]
    wipe = sum(1 for x in lost if x['lost']); stale = len(lost) - wipe
    wt = f"{statistics.mean(x['turns'] for x in won):.1f}" if won else '－'
    if lost:
        ps = sorted(pct(x) for x in lost)
        lp = f"{statistics.median(ps)*100:.0f}%·{ps[0]*100:.0f}%"
    else:
        lp = '－'
    rate = len(won) / len(per)
    if first_fail is None and rate < 0.5:
        first_fail = f
    cells = [str(f), wan(r['enemyHp']), f"**{len(won)}/{len(per)}**", wt, lp, f"{wipe}/{stale}" if lost else '－', t363.get(f, '－')]
    for _, rows in extra:
        e = rows.get(f)
        cells.append(f"{sum(1 for x in e['per'] if x['won'])}/{len(e['per'])}" if e else '没量')
    print('| ' + ' | '.join(cells) + ' |')
tot_w = sum(sum(1 for x in base[f]['per'] if x['won']) for f in base); tot = sum(len(base[f]['per']) for f in base)
print(f"\n合计 {tot_w}/{tot}；胜率第一次低于一半的层：{first_fail}")
for k, rows in extra:
    w = sum(sum(1 for x in rows[f]['per'] if x['won']) for f in rows); n = sum(len(rows[f]['per']) for f in rows)
    ff = next((f for f in sorted(rows) if sum(1 for x in rows[f]['per'] if x['won']) * 2 < len(rows[f]['per'])), None)
    print(f"{k}：合计 {w}/{n}（量到 {min(rows)}～{max(rows)} 层）；胜率第一次低于一半的层：{ff}")
