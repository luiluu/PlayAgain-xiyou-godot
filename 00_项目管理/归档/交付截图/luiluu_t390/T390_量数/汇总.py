#!/usr/bin/env python3
"""T390 汇总：把 brand_calib --out 的 json（r6、t298 两链）按层合并，打 Markdown 表。
用法：python3 汇总.py <组名>…（读同目录 <组名>_r6.json、<组名>_t298.json）；python3 汇总.py --cmp 组=标签 …（并列）"""
import json, sys, statistics as st
from pathlib import Path
HERE = Path(__file__).resolve().parent
def load(g):
    by = {}
    for c in ['r6', 't298']:
        p = HERE / f'{g}_{c}.json'
        if not p.exists(): continue
        for r in json.load(open(p))['rows']:
            by.setdefault(int(r['floor']), {'carved': r.get('carved_value'), 'fights': []})['fights'].extend(r['fights'])
    return by
def avg(x): return st.mean(x) if x else None
def f2(x, n=2): return '－' if x is None else f'{x:.{n}f}'
def role8(fs, role, src, uncapped=False):
    out = []
    for r in fs:
        cnt = int(r['roles'].get(role, 0))
        if cnt <= 0 or (uncapped and r['capped']): continue
        out.append(float(r['fits'].get(role, {}).get(src, 0)) * 8.0 / max(1.0, float(r['turns'])) / cnt)
    return avg(out), len(out)
def row(fl, b):
    fs = b['fights']; n = len(fs); w = [r for r in fs if r['won']]
    so, no = role8(fs, '输出', 'self'); ro, _ = role8(fs, '输出', 'sear'); rt, nt = role8(fs, '坦克', 'sear'); rs, ns = role8(fs, '辅助', 'sear')
    team8 = avg([sum(int(r['fits'].get(k, {}).get('self', 0)) for k in ['输出', '坦克', '辅助']) * 8.0 / max(1.0, r['turns']) for r in fs])
    return {'fl': fl, 'carved': b['carved'], 'n': n, 'w': len(w), 'tw': avg([r['turns'] for r in w]), 'ta': avg([r['turns'] for r in fs]),
            'downs': avg([r['downs'] for r in fs]), 'harm': sum(1 for r in fs if int(r['harm']) > 0), 'capped': sum(1 for r in fs if r['capped']),
            'so': so, 'no': no, 'ro': ro, 'rt': rt, 'nt': nt, 'rs': rs, 'ns': ns, 'team8': team8,
            'kinds': {k: sum(int(r['kinds'].get(k, 0)) for r in fs) for k in sorted({k for r in fs for k in r['kinds']})}}
def table(g):
    by = load(g)
    print(f'\n#### {g}\n')
    print('| 层 | 输出烙印% | 胜/场 | 胜场回合 | 平均回合 | 倒下人次 | 封顶场 | 伤人场 | 折8回合 输出自己疯 | 输出被打疯 | 坦克被打疯（场） | 辅助被打疯（场） | 全队自己疯 | 花样 |')
    print('|' + '---|' * 14)
    rows = []
    for fl in sorted(by):
        x = row(fl, by[fl]); rows.append(x)
        print(f"| {fl} | {f2(x['carved'],0)} | {x['w']}/{x['n']} | {f2(x['tw'],1)} | {f2(x['ta'],1)} | {f2(x['downs'])} | {x['capped']} | {x['harm']} | {f2(x['so'])} | {f2(x['ro'])} | {f2(x['rt'])}（{x['nt']}） | {f2(x['rs'])}（{x['ns']}） | {f2(x['team8'])} | {json.dumps(x['kinds'], ensure_ascii=False)} |")
    return rows


def compare(groups, labels=None):
    """并列：每组 胜/场（胜场回合）·平均回合·倒下人次"""
    labels = labels or groups
    data = [load(g) for g in groups]
    fls = sorted(set().union(*[d.keys() for d in data]))
    print('\n| 层 | ' + ' | '.join(labels) + ' |')
    print('|' + '---|' * (len(groups) + 1))
    for fl in fls:
        cells = []
        for d in data:
            if fl not in d: cells.append('－'); continue
            x = row(fl, d[fl])
            cells.append(f"{x['w']}/{x['n']}（{f2(x['tw'],1)}）·均{f2(x['ta'],1)}·倒{f2(x['downs'],1)}")
        print(f'| {fl} | ' + ' | '.join(cells) + ' |')


if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == '--cmp':   # --cmp 组1=标签1 组2=标签2 …
        compare([x.split('=')[0] for x in a[1:]], [x.split('=', 1)[-1] for x in a[1:]])
    else:
        for g in a: table(g)
