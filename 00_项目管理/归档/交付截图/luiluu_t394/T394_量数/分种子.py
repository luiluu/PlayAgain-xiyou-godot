#!/usr/bin/env python3
"""（T394 拷来：读本目录的 s4fix_all，修轰炸后 31～33 层复量，口径同 T390 s4raw_all）T390 返修（小A 核 P1-1、P2-1）：按种子分开、剔除 ≤3 回合就结束的场，重算输出自己疯／被打疯折 8 回合。
生：count×8÷turns（第 1 回合不掷，同原口径）；熟另列「按有效掷骰回合折」＝count×(8−3)÷max(1,turns−3)（前 3 回合不掷）。
用法：python3 分种子.py <组>…（读 <组>_r6.json、<组>_t298.json）"""
import json, sys, statistics as st
from pathlib import Path
H = Path(__file__).resolve().parent
def fights(g):
    by = {}
    for c in ['r6', 't298']:
        p = H / f'{g}_{c}.json'
        if not p.exists(): continue
        for r in json.load(open(p))['rows']:
            by.setdefault(int(r['floor']), []).extend(r['fights'])
    return by
def m(a): return f'{st.mean(a):.2f}' if a else '－'
for g in sys.argv[1:]:
    ripe = 'ripe' in g
    print(f'\n#### {g}（剔除 ≤3 回合的场；s1／s2＝种子）\n')
    print('| 层 | 种子 | 留下场/全部 | 平均回合 | 输出自己疯/8 | 输出被打疯/8 | 全队自己疯/8 | 全队自己疯（有效掷骰折）/8 |')
    print('|---|---|---|---|---|---|---|---|')
    for fl, fs in sorted(fights(g).items()):
        for s in ('1', '2'):
            a = [x for x in fs if str(x['rep']).startswith(s)]
            k = [x for x in a if x['turns'] > 3]
            def per(x, src): 
                n = x['roles'].get('输出', 0)
                return float(x['fits'].get('输出', {}).get(src, 0)) * 8 / x['turns'] / n if n else None
            so = [v for v in (per(x, 'self') for x in k) if v is not None]
            ro = [v for v in (per(x, 'sear') for x in k) if v is not None]
            team = lambda x: sum(int(x['fits'].get(r, {}).get('self', 0)) for r in ['输出', '坦克', '辅助'])
            t8 = [team(x) * 8 / x['turns'] for x in k]
            te = [team(x) * 5 / max(1, x['turns'] - 3) for x in k] if ripe else []
            print(f"| {fl} | s{s} | {len(k)}/{len(a)} | {m([x['turns'] for x in k])} | {m(so)} | {m(ro)} | {m(t8)} | {m(te) if ripe else '－'} |")
