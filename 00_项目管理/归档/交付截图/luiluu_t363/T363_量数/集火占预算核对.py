#!/usr/bin/env python3
"""T363 验收 3：照新表，每层每队集火招期望出伤（每回合，按表里倍率）÷ 每回合总预算 D，只看放过这招的队：中位、最大、超一半的队数。
用法：python3 集火占预算核对.py <balance_table.json> <量数 json>…"""
import json, sys, statistics as st
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parents[5] / '03_再刷重制_Godot' / '07_开发环境'))
T = __import__('守层者三表')
tab = json.load(open(sys.argv[1]))['guardian_phase4']
by = T.merge_rows(T.load_rows(sys.argv[2:]))
print('层 | 集火招 | 放过的队/普通队 | 占预算 中位 | 最大 | 超一半队数')
for f in sorted(by):
    fz = tab.get('focus', {}).get(str(f))
    if not fz:
        continue
    k0 = float(tab['atk_scale'][str(f)])
    xs = []
    ts = T.normal_teams(by[f])
    for t in ts:
        v = T._skills(t, f).get(str(fz['skill']), {})
        if float(v.get('dmg', 0)) > 0 and float(t.get('partyHp', 0)) > 0:
            # 量数时那招按 atkScale（=当时表里 atk_scale）口径折回；照新表打 ＝ dmg × 新集火倍率 ÷ 当时 atkScale
            xs.append(float(v['dmg']) * float(fz['scale']) / float(t.get('atkScale', k0)) / T._need(t, 8))
    if xs:
        print('%d | %d%s | %d/%d | %.2f | %.2f | %d' % (f, fz['skill'], '·单体' if fz.get('single') else '', len(xs), len(ts), st.median(xs), max(xs), sum(x > 0.5 for x in xs)))
