#!/usr/bin/env python3
"""T363 对比表：第 6 轮（T239，C 口径）对 T363 迭代，真打 2 存档链×4 队×2 种子＋奶妈队。
用法：python3 对比表生成.py <新表 balance_table.json> <新真打 r6.json> <新真打 t298.json> [<新量数 r6> <新量数 t298>]，打印 Markdown。"""
import json, sys, statistics as st
from pathlib import Path
HERE = Path(__file__).resolve().parent
OLD = HERE.parent.parent / 'luiluu_t239' / 'T239_量数'
TURNS = 8


def duel(paths):
    by = {}
    for p in paths:
        for r in json.load(open(p))['rows']:
            by.setdefault(int(r['floor']), []).extend(r.get('per', []))
    return by


def summ(per):
    nm = [p for p in per if p.get('team') != '奶妈队']
    hl = [p for p in per if p.get('team') == '奶妈队']
    w = [p for p in nm if p.get('won')]
    top = sorted(nm, key=lambda p: -float(p.get('dmg', 0)))[:max(1, len(nm) // 4)]   # 每回合打得最多的四分之一＝强队
    tw = [p['turns'] for p in top if p.get('won')]
    return {'n': len(nm), 'w': len(w), 'avg': st.mean([p['turns'] for p in nm]) if nm else 0, 'wavg': st.mean([p['turns'] for p in w]) if w else None,
            'wmin': min([p['turns'] for p in w]) if w else None, 'top': '%d/%d 均%s' % (len(tw), len(top), ('%.1f' % st.mean(tw)) if tw else '－'),
            'h': '%d/%d' % (len([p for p in hl if p.get('won')]), len(hl)) if hl else '－'}


def fmt(x):
    if x is None:
        return '－'
    if isinstance(x, dict):
        return '%s·%.3g%s' % (x['skill'], x['scale'], '·单体' if x.get('single') else '')
    x = float(x)
    return ('%.1f万' % (x / 1e4)) if x >= 1e5 else ('%.3g' % x)


def main(a):
    newt = json.load(open(a[0]))['guardian_phase4']
    oldt = json.loads(__import__('subprocess').run(['git', 'show', 'f10fc5c6f:03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/balance_table.json'],
                                                  capture_output=True, text=True, check=True, cwd=HERE).stdout)['guardian_phase4']
    o = duel([OLD / 'r6轮_d_C_r6.json', OLD / 'r6轮_d_C_t298.json'])
    n = duel(a[1:3])
    print('| 层 | 血/回合 第6轮 | **血/回合 T363** | 出伤 第6轮 | **出伤 T363** | 集火 第6轮 | **集火 T363** | 抵抗 第6轮 | **抵抗 T363** | 普通 胜/队 第6轮 | **普通 胜/队 T363** | 赢的均回合（最快） 第6轮 | **赢的均回合（最快） T363** | 强队¼ 胜·均回合 第6轮 | **强队¼ T363** | 奶妈队 第6轮 | **奶妈队 T363** |')
    print('|' + '---|' * 17)
    for f in range(1, 35):
        k = str(f)
        so, sn = summ(o.get(f, [])), summ(n.get(f, []))
        wr = lambda s: '－' if s['wavg'] is None else '%.1f（%d）' % (s['wavg'], s['wmin'])
        print('| %d | %s | **%s** | %s | **%s** | %s | **%s** | %s | **%s** | %d/%d 均%.1f | **%d/%d 均%.1f** | %s | **%s** | %s | **%s** | %s | **%s** |' % (
            f, fmt(oldt['hp_base'].get(k)), fmt(newt['hp_base'].get(k)), fmt(oldt['atk_scale'].get(k)), fmt(newt['atk_scale'].get(k)),
            fmt(oldt.get('focus', {}).get(k)), fmt(newt.get('focus', {}).get(k)), fmt(oldt.get('resist', {}).get(k)), fmt(newt.get('resist', {}).get(k)),
            so['w'], so['n'], so['avg'], sn['w'], sn['n'], sn['avg'], wr(so), wr(sn), so['top'], sn['top'], so['h'], sn['h']))


if __name__ == '__main__':
    main(sys.argv[1:])
