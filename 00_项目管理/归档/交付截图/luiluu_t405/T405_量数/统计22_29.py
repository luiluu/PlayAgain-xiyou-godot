#!/usr/bin/env python3
"""T405 统计：22、29 层 D273（守层者／首领回合末负 HP 再生封顶 5%）前后真打，按 T392 band 口径汇总并打印 Markdown。
口径（D257／T405 派单）：
- 普通阵容＝team != '奶妈队'（奶妈队单列不进表）；r6、t298 两链合看（每层每档 24 场普通＋6 场奶妈）；
- 强队＝普通阵容每回合直伤（dmg）前四分之一（6 场）；band＝寻常 6±2、艰险 8±2；
- 强队均回合只算强队赢且 turns > 3 的场；≤3 回合场（赢或输）单列「秒杀」不进均值；
- 扣血占总血比＝强队赢场的直伤占总血比（dmg*turns/enemyHp）、回合末扣血占总血比（endTurnDmg*turns/enemyHp），逐种子列分布。
用法（仓库根）：python3 00_项目管理/归档/交付截图/luiluu_t405/T405_量数/统计22_29.py"""
import json
import statistics as st
from pathlib import Path

HERE = Path(__file__).resolve().parent
TURNS = {'xunchang': 6, 'jianxian': 8}
NAMES = {'xunchang': '寻常', 'jianxian': '艰险'}
MODES = [('off', '封顶前（-14%/回合）'), ('cap', '封顶后（D273 -5%）')]
FAST = 3


def load(mode, diff, floor):
    per = []
    for c in ('r6', 't298'):
        p = HERE / f'{mode}_{diff}_{c}.json'
        if not p.exists():
            continue
        for r in json.load(open(p))['rows']:
            if int(r['floor']) == floor:
                for x in r.get('per', []):
                    per.append(dict(x, chain=c))
    return per


def seed_of(p):
    return int(p['rng']) // 100000


def pct_direct(p):
    return float(p['dmg']) * int(p['turns']) / max(1.0, float(p['enemyHp'])) * 100.0


def pct_end(p):
    return float(p.get('endTurnDmg', 0.0)) * int(p['turns']) / max(1.0, float(p['enemyHp'])) * 100.0


def summ(per, diff):
    nm = [p for p in per if p.get('team') != '奶妈队']
    hl = [p for p in per if p.get('team') == '奶妈队']
    top = sorted(nm, key=lambda p: -float(p.get('dmg', 0.0)))[:max(1, len(nm) // 4)]
    fast = [p for p in top if int(p['turns']) <= FAST]
    wins_ok = [p for p in top if p.get('won') and int(p['turns']) > FAST]
    lo, hi = TURNS[diff] - 2, TURNS[diff] + 2
    avg = st.mean([p['turns'] for p in wins_ok]) if wins_ok else None
    dir_pct = st.mean([pct_direct(p) for p in wins_ok]) if wins_ok else None
    end_pct = st.mean([pct_end(p) for p in wins_ok]) if wins_ok else None
    return {
        'nm': nm, 'hl': hl, 'top': top, 'fast': fast, 'wins_ok': wins_ok,
        'avg': avg, 'dir_pct': dir_pct, 'end_pct': end_pct,
        'band': '－' if avg is None else ('✓' if lo <= avg <= hi else '✗'),
        'lo': lo, 'hi': hi,
    }


def cell(p):
    return '%s%d(直%.0f%%/末%.0f%%)' % ('赢' if p.get('won') else '输', int(p['turns']), pct_direct(p), pct_end(p))


def main():
    print('# T405 22、29 层 D273 负再生 5% 封顶前后 3 种子统计\n')
    print('| 层 | 难度 | 方案 | 强队胜 | 强队均回合（>3） | band | 直伤占总血 | 回合末占总血 | 秒杀场（≤3） | 普通胜/场 | 奶妈队 |')
    print('|---|---|---|---|---|---|---|---|---|---|---|')
    detail = []
    for fl in (22, 29):
        for diff in ('xunchang', 'jianxian'):
            for mode, lab in MODES:
                per = load(mode, diff, fl)
                if not per:
                    continue
                s = summ(per, diff)
                detail.append((fl, diff, mode, lab, s))
                nw = [p for p in s['nm'] if p.get('won')]
                fast_s = '、'.join('%s %s 种%d %s%d' % (p['chain'], p['team'], seed_of(p), '赢' if p.get('won') else '输', int(p['turns'])) for p in s['fast']) or '无'
                print('| %d | %s %d±2 | %s | %d/%d | %s | %s | %s | %s | %s | %d/%d | %d/%d |' % (
                    fl, NAMES[diff], TURNS[diff], lab,
                    len([p for p in s['top'] if p.get('won')]), len(s['top']),
                    '－' if s['avg'] is None else '%.1f' % s['avg'],
                    s['band'],
                    '－' if s['dir_pct'] is None else '%.1f%%' % s['dir_pct'],
                    '－' if s['end_pct'] is None else '%.1f%%' % s['end_pct'],
                    fast_s,
                    len(nw), len(s['nm']),
                    len([p for p in s['hl'] if p.get('won')]), len(s['hl']),
                ))
    print('\n## 逐种子分布（强队＝两链合看 dmg 前四分之一；括号内为 直伤占总血%/回合末占总血%）\n')
    for fl, diff, mode, lab, s in detail:
        print(f'### {fl} 层 · {NAMES[diff]} · {lab}\n')
        print('| 种子 | 强队各场 | 强队胜 | 强队均回合（>3） | 强队直伤/回合末占比 | 全部普通队各场 |')
        print('|---|---|---|---|---|---|')
        for sd in sorted({seed_of(p) for p in s['nm']}):
            tp = [p for p in s['top'] if seed_of(p) == sd]
            tw = [p for p in tp if p.get('won') and int(p['turns']) > FAST]
            al = [p for p in s['nm'] if seed_of(p) == sd]
            ratio_s = ('%.1f%% / %.1f%%' % (st.mean([pct_direct(p) for p in tw]), st.mean([pct_end(p) for p in tw]))) if tw else '－'
            print('| %d | %s | %d/%d | %s | %s | %s |' % (
                sd,
                '、'.join('%s·%s %s' % (p['chain'], p['team'], cell(p)) for p in tp) or '无',
                len([p for p in tp if p.get('won')]), len(tp),
                ('%.1f' % st.mean([p['turns'] for p in tw])) if tw else '－',
                ratio_s,
                '、'.join('%s·%s %s%d' % (p['chain'], p['team'], '赢' if p.get('won') else '输', int(p['turns'])) for p in al),
            ))
        print()


if __name__ == '__main__':
    main()
