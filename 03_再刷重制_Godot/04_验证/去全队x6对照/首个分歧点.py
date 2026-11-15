#!/usr/bin/env python3
"""去全队 ×6 开关对照：逐队找首个分歧点（cc/tianqi-no-x6 返修，co 补证要求）。
读同目录 duel_off.json（关）、duel_on_gh_off.json（开·O-2 关）、duel_on.json（开），输出 首个分歧点.md。
每队按行动逐条比：行动者、技能、目标不同＝「行动分歧」；我方各人血量差 >1＝「我方血量分歧」；
敌方各人血量 关 与 开×6 差超过 max(6, 1%)＝「敌方血量分歧」（取整误差内算相同）。"""
import json
from pathlib import Path
HERE = Path(__file__).resolve().parent
d = {k: json.load(open(HERE / f'duel_{k}.json')) for k in ('off', 'on_gh_off', 'on')}

def first_diff(ta, tb, k=6.0):
    for i, (x, y) in enumerate(zip(ta, tb)):
        if x[:4] != y[:4]:
            return i, '行动分歧', x[:4], y[:4]
        if any(abs(p - q) > 1 for p, q in zip(x[5], y[5])):
            return i, '我方血量分歧', x[5], y[5]
        for p, q in zip(x[4], y[4]):
            if abs(p - q * k) > max(6.0, 0.01 * max(p, 1)) and not (p <= 0 and q <= 0):
                return i, '敌方血量分歧', x[4], y[4]
    if len(ta) != len(tb):
        return min(len(ta), len(tb)), '行动数不同', len(ta), len(tb)
    return None

out = ['# 去全队 ×6：逐队首个分歧点', '', '关＝duel_off.json，比较对象见各节。行号＝该队第几次行动（从 0 起），回合＝第几回合（从 0 起）。', '']
for other in ('on_gh_off', 'on'):
    rows = []
    same = 0
    kinds = {}
    for fa, fb in zip(d['off']['rows'], d[other]['rows']):
        for ti, (ta, tb) in enumerate(zip(fa['teams'], fb['teams'])):
            r = first_diff(ta['trace'], tb['trace'])
            if r is None:
                same += 1
                continue
            i, kind, x, y = r
            kinds[kind] = kinds.get(kind, 0) + 1
            turn = ta['trace'][i][0] if i < len(ta['trace']) else '-'
            outc = f"{'胜' if ta['won'] else '败' if ta['lost'] else '平'}{ta['turns']}→{'胜' if tb['won'] else '败' if tb['lost'] else '平'}{tb['turns']}"
            rows.append(f"| {fa['floor']} | {ti} | {i} | {turn} | {kind} | `{json.dumps(x, ensure_ascii=False)[:90]}` | `{json.dumps(y, ensure_ascii=False)[:90]}` | {outc} |")
    total = sum(len(f['teams']) for f in d['off']['rows'])
    out += [f'## 关 vs {other}', '', f'逐条全同（含敌方血量按 ×6 对上）：{same}／{total}；有分歧 {total - same}：{kinds}', '',
            '| 层 | 队 | 行 | 回合 | 首个分歧 | 关 | 开 | 结果 关→开 |', '|---|---|---|---|---|---|---|---|'] + rows + ['']
(HERE / '首个分歧点.md').write_text('\n'.join(out), encoding='utf-8')
print('\n'.join(l for l in out if l.startswith('##') or l.startswith('逐条')))
