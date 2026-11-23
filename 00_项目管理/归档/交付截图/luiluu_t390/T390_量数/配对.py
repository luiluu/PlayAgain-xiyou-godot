#!/usr/bin/env python3
"""T390 配对比较：两组同一存档链、同队（team＋label）、同种子（rep）的场一一对上，只取两边都赢的场比回合；
另比倒下人次、胜场。用法：python3 配对.py <组A> <组B>（读 <组>_r6.json、<组>_t298.json，也认 b2_ 前缀）"""
import json, sys, statistics as st
from pathlib import Path
HERE = Path(__file__).resolve().parent
def load(g):
    by = {}
    for c in ['r6', 't298']:
        for pre in ['', 'b2_']:
            p = HERE / f'{pre}{g}_{c}.json'
            if not p.exists(): continue
            for r in json.load(open(p))['rows']:
                for x in r['fights']:
                    by[(c, int(r['floor']), str(x['team']), str(x.get('label', '')), int(x['rep']))] = x
    return by
A, B = load(sys.argv[1]), load(sys.argv[2])
print(f'| 层 | 配对场 | A 胜 | B 胜 | 两边都赢 | A/B 回合比（都赢的场，几何平均） | A 倒下 | B 倒下 |')
print('|---|---|---|---|---|---|---|---|')
fls = sorted({k[1] for k in A if k in B})
allr = []
for fl in fls:
    ks = [k for k in A if k in B and k[1] == fl]
    both = [k for k in ks if A[k]['won'] and B[k]['won']]
    rs = [A[k]['turns'] / B[k]['turns'] for k in both]
    allr += rs
    g = st.geometric_mean(rs) if rs else None
    print(f"| {fl} | {len(ks)} | {sum(A[k]['won'] for k in ks)} | {sum(B[k]['won'] for k in ks)} | {len(both)} | {'－' if g is None else f'{g:.2f}'} | {st.mean([A[k]['downs'] for k in ks]):.2f} | {st.mean([B[k]['downs'] for k in ks]):.2f} |")
if allr: print(f'\n全部都赢的场 {len(allr)} 场，回合比几何平均 {st.geometric_mean(allr):.3f}')
