#!/usr/bin/env python3
"""T402 统计：22 层真打（量数.sh 的输出）按 T392 band 口径汇总，打印 Markdown。
口径（D257，派单量数口径）：普通阵容＝team 不是「奶妈队」（奶妈队单列不进表）；两条存档链（r6、t298）合起来看；
强队＝普通阵容里每回合掉血（dmg）前四分之一（同 T392 对比表生成.py summ）；band＝本档目标回合±2（寻常 6、艰险 8）；
均回合只算强队赢了、且回合 >3 的场；≤3 回合结束的场（赢或输）单列「秒杀」，不进均值；逐种子列强队每场（赢/输＋回合）。
用法（仓库根）：python3 00_项目管理/归档/交付截图/luiluu_t402/T402_量数/统计.py"""
import json, statistics as st
from pathlib import Path
HERE = Path(__file__).resolve().parent
TURNS = {'xunchang': 6, 'jianxian': 8}
NAMES = {'xunchang': '寻常', 'jianxian': '艰险'}
FAST = 3


def load(tag, d):
    per = []
    for c in ('r6', 't298'):
        p = HERE / ('%s_%s_%s.json' % (tag, d, c))
        if not p.exists():
            continue
        for r in json.load(open(p))['rows']:
            if int(r['floor']) == 22:
                for x in r.get('per', []):
                    per.append(dict(x, chain=c))
    return per


def seed_of(p):
    return int(p['rng']) // 100000


def summ(per, d):
    nm = [p for p in per if p.get('team') != '奶妈队']
    hl = [p for p in per if p.get('team') == '奶妈队']
    top = sorted(nm, key=lambda p: -float(p.get('dmg', 0)))[:max(1, len(nm) // 4)]
    fast = [p for p in top if int(p['turns']) <= FAST]
    tw = [p['turns'] for p in top if p.get('won') and int(p['turns']) > FAST]
    lo, hi = TURNS[d] - 2, TURNS[d] + 2
    avg = st.mean(tw) if tw else None
    return {'nm': nm, 'hl': hl, 'top': top, 'fast': fast, 'avg': avg,
            'band': '－' if avg is None else ('✓' if lo <= avg <= hi else '✗'), 'lo': lo, 'hi': hi}


def cell(p):
    return '%s%d' % ('赢' if p.get('won') else '输', int(p['turns']))


def main():
    print('| 难度 | 毒 | 强队胜 | 强队均回合（>3） | band | 秒杀场（≤3） | 普通胜/队 | 普通赢均回合 | 奶妈队 |')
    print('|---|---|---|---|---|---|---|---|---|')
    out = {}
    for d in TURNS:
        for tag, lab in (('off', '关（T080 65%／58%）'), ('on', '开（15%／13%）')):
            per = load(tag, d)
            if not per:
                continue
            s = summ(per, d)
            out[(d, tag)] = s
            nw = [p for p in s['nm'] if p.get('won')]
            print('| %s %d±2 | %s | %d/%d | %s | %s | %s | %d/%d | %s | %d/%d |' % (
                NAMES[d], TURNS[d], lab, len([p for p in s['top'] if p.get('won')]), len(s['top']),
                '－' if s['avg'] is None else '%.1f' % s['avg'], s['band'],
                '、'.join('%s %s 种%d %s' % (p['chain'], p['team'], seed_of(p), cell(p)) for p in s['fast']) or '无',
                len(nw), len(s['nm']), ('%.1f' % st.mean([p['turns'] for p in nw])) if nw else '－',
                len([p for p in s['hl'] if p.get('won')]), len(s['hl'])))
    print()
    print('### 逐种子（强队＝两链合看的前四分之一；格子是 链·队：赢/输＋回合）')
    print()
    for (d, tag), s in out.items():
        print('**%s · 毒%s**' % (NAMES[d], '开' if tag == 'on' else '关'))
        print()
        print('| 种子 | 强队各场 | 强队胜 | 强队赢均回合（>3） | 全部普通队各场 |')
        print('|---|---|---|---|---|')
        for sd in sorted({seed_of(p) for p in s['nm']}):
            tp = [p for p in s['top'] if seed_of(p) == sd]
            tw = [p['turns'] for p in tp if p.get('won') and int(p['turns']) > FAST]
            al = [p for p in s['nm'] if seed_of(p) == sd]
            print('| %d | %s | %d/%d | %s | %s |' % (sd, '、'.join('%s·%s %s' % (p['chain'], p['team'], cell(p)) for p in tp) or '无',
                  len([p for p in tp if p.get('won')]), len(tp), ('%.1f' % st.mean(tw)) if tw else '－',
                  '、'.join('%s·%s %s' % (p['chain'], p['team'], cell(p)) for p in al)))
        print()


if __name__ == '__main__':
    main()
