#!/usr/bin/env python3
"""T081：把 skill_rework.json 里 rules.single_hit_cap_pending 的待拆技能按单段上限拆段（合计不变、系数避开 4）。

做法：技能行 seq 末尾加 {"op": "split_effects", "n": N}（XTianqiSkills._seq_edit 把每一段原地拆成 N 段），
damage.coef 除以 N，说明改成「N段伤害／每段」；每次命中都给的 tpGain 用 fields 同比例分掉。
10731 后颈斩底号 8119 本来 8 段，只改 keep_effects 的 n（纯数据）；3631 万剑归一*灭 序列本来就是 3 段，只改系数和说明。
可重跑：已经拆过的（pending 里没有了）跳过。
"""
import json
import sys
from pathlib import Path

P = Path(__file__).resolve().parent.parent / '01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json'

# 技能号: (N, 新系数, 新说明, 额外改动)
PLAN = {
    '3632': (3, 3.6, ['效果：3段伤害；30%概率变成破或灭（只换特效）', '伤害：每段 物理攻击×3.6；自己敏捷低于目标时 +30%'], {}),
    '3633': (3, 3.6, ['效果：3段伤害', '伤害：每段 物理攻击×3.6；自己敏捷低于目标时 +30%'], {}),
    '4748': (3, 3.6, ['效果：3段伤害；30%概率变成破或灭（只换特效），10%概率变成破魂', '伤害：每段 物理攻击×3.6；自己敏捷低于目标时 +30%'], {}),
    '4750': (3, 3.6, ['效果：3段伤害；30%概率变成破或灭（只换特效），10%概率变成诛心', '伤害：每段 物理攻击×3.6；自己敏捷低于目标时 +30%'], {}),
    '4751': (3, 3.6, ['效果：3段伤害，无视目标30%双防', '伤害：每段 物理攻击×3.6；自己敏捷低于目标时 +30%'], {}),
    '4749': (2, 8.1, ['效果：2段伤害', '伤害：每段 物理攻击×8.1；自己敏捷低于目标时 +30%'], {}),
    '3631': (0, 3.6, ['效果：3段伤害', '伤害：每段 物理攻击×3.6；自己敏捷低于目标时 +30%'], {}),
    '3645': (2, 1.0, ['效果：每段分2次打出', '伤害：每次 物理攻击×1.8＋敏捷×1.8'], {'tpGain': 3}),
    '4812': (2, 1.3, ['效果：心法邪练的寒锋（伤害 +30%）；每段分2次打出', '伤害：每次 物理攻击×1.8＋敏捷×1.8'], {'tpGain': 3}),
    '4411': (2, 3.0, ['效果：每段分2次打出', '伤害：每次 物理攻击×3.0'], {'tpGain': 4}),
    '4815': (2, 3.9, ['效果：心法邪练的英勇打击（伤害 +30%）；每段分2次打出', '伤害：每次 物理攻击×3.0'], {'tpGain': 4}),
    '1060': (3, 3.6, ['效果：必中；每段分3次打出；为自己增加一个圣光护盾，能够抵挡一次除神圣属性以外的任何伤害，持续3回合', '效果：回复30 TP', '伤害：每次 物理攻击×3.6'], {'tpGain': 10}),
    '1212': (2, 5.25, ['效果：2段伤害；放完失去一半魔法；之后对全体再造成一次伤害（1.8）', '伤害：每段 魔法攻击×3.9～6.6随机'], {}),
    '2058': (2, 3.0, ['效果：2段伤害；必中；目标每有一种诅咒 +10%（最多 +30%）', '伤害：每段 魔法攻击×3.0', '消耗：最大魔法10%'], {}),
    '10721': (2, 3.6, ['效果：2段伤害；黑暗属性，必中（30级学会）', '伤害：每段 魔法攻击×3.6；缠意每层 +5%', '消耗：最大魔法10%'], {}),
    '10752': (3, 3.6, ['效果：3段伤害；耗光TP（50级学会）', '伤害：每段（物理攻击×0.5＋敏捷×0.5）×3.6'], {}),
    '10731': (-3, 3.6, ['效果：3段伤害；专砍要害；目标生命低于30%时必定暴击并无视物防30%（50级学会）', '伤害：每段 物理攻击×3.6'], {}),
    '6036': (3, 3.6, ['效果：3段伤害；这一击无视目标20%防御', '伤害：每段（物理攻击×0.5＋魔法攻击×0.5）×3.6'], {}),
    '10006': (2, 3.6, ['效果：2段伤害；火焰属性；魔力满时 +50%（按当前魔力比例）；放完耗光魔力，趴下1回合', '伤害：每段 魔法攻击×3.6'], {}),
    '10007': (2, 3.0, ['效果：2段伤害；吃最高的元素加成；魔力满时 +50%；放完耗光魔力，趴下2回合', '伤害：每个敌人每段 魔法攻击×3.0'], {}),
    '10008': (3, 3.6, ['效果：3段伤害；吃最高的元素加成；魔力满时 +50%；放完耗光魔力，趴下1回合', '伤害：每段 魔法攻击×3.6'], {}),
    '10615': (3, 3.6, ['效果：3段伤害', '伤害：每段 (物理攻击＋生命上限×0.7%)×3.6'], {}),
    '10125': (2, 3.6, ['效果：2段伤害；按目标已损生命最多再 +50%', '伤害：每段 魔法攻击×3.6'], {}),
}


def main() -> int:
    text = P.read_text(encoding='utf-8')
    data = json.loads(text)
    pending = data['rules'].get('single_hit_cap_pending', {})
    lines = text.split('\n')
    done = []
    for sid, (n, coef, desc, fields) in PLAN.items():
        if sid not in pending:
            continue
        row = data['skills'][sid]
        old = row['damage']['coef']
        seq = row.get('seq', [])
        if n > 0:
            assert abs(old - coef * n) < 1e-6, (sid, old, coef, n)
            seq = seq + [{'op': 'split_effects', 'n': n}]
        elif n < 0:  # 只改 keep_effects 的段数
            seq = [dict(o, n=-n) if o.get('op') == 'keep_effects' else o for o in seq]
            assert abs(old - coef * -n) < 1e-6
        if seq:
            row['seq'] = seq
        row['damage']['coef'] = coef
        row['desc'] = desc
        if fields:
            row.setdefault('fields', {}).update(fields)
        pref = '  "%s": ' % sid
        idx = [i for i, l in enumerate(lines) if l.startswith(pref)]
        assert len(idx) == 1, sid
        comma = ',' if lines[idx[0]].endswith(',') else ''
        lines[idx[0]] = pref + json.dumps(row, ensure_ascii=False) + comma
        done.append(sid)
    text = '\n'.join(lines)
    # 拆好的从待拆名单里删（名单在 rules 那一行里）
    data2 = json.loads(text)
    for sid in done:
        data2['rules']['single_hit_cap_pending'].pop(sid, None)
    rl = [i for i, l in enumerate(lines) if l.startswith(' "rules": ')]
    assert len(rl) == 1
    comma = ',' if lines[rl[0]].endswith(',') else ''
    lines[rl[0]] = ' "rules": ' + json.dumps(data2['rules'], ensure_ascii=False) + comma
    P.write_text('\n'.join(lines), encoding='utf-8')
    print('拆了 %d 行：%s' % (len(done), '、'.join(done)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
