#!/usr/bin/env python3
"""T549：天启篇装备自带技能（漏项扫描 C 类）分批改写生成。默认只检查，--write 写进 skill_rework.json。

口径（与 T445 通用书生成同一套样板，书上主动 ≤ 角色本体 0.8 倍；T541 3549／3624 先例）：
- 装备给的伤害主动招（特性 43、ShareLearnSkill、套装给技能）一律按「爆发」档：单体／随机多段合计 3、全体每个目标 2，
  冷却 max(3, 原冷却)；物理耗 TP 35，魔法耗最大魔法 10%（全体 15%）。去固定底数、熟练度连乘、条件连段（drop_if）、
  末段打全体的参数（clear_effect_args）、命中回血回蓝命令、旧强制施放公共事件（效果 44）。
- 段数保留：每段系数＝合计÷段数，向下取整到整数百分比（附则 E），所以合计可能比 3 略低、不会超。
- 原版的伤害波动（variance）照留，种子对照才有真方差（T541 核第 10 条）。
- 控制状态附加几率封 25%（同 T445）。
- 替换普攻（Replace Attack）与武器触发（Weapon Unleash）这两条通道不在本生成器里：1 号普攻仍是物攻×4、
  改写表普攻 1.0，口径未定（协调 11-26 定 C：另卡查清再改），见 MANUAL 与漏项扫描豁免登记。
"""

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent / '01_Godot工程' / 'modes' / 'xiyou'
DATA = ROOT / 'tianqi_data'
DB = ROOT / 'generated' / 'db'
TAG = 'T549'

# 批 1：高危伤害主动（特性 43／ShareLearnSkill）＋套装给的伤害主动（天启篇实际生效的档）
BATCH1_DAMAGE = [
    345, 615, 662, 670, 810, 812, 1274, 1836, 2639, 2797, 3175, 3179, 3180, 3509, 3510, 3512, 3526,
    3529, 3557, 3564, 3571, 3604, 3605, 3625, 3626, 3647, 3648, 3650, 3913, 3926, 3927, 3928, 3929,
    4709, 4712, 4715, 4718, 4719, 6243,
    # 套装给技能（第 6 通道）里天启篇生效的伤害主动
    485, 1687, 1688, 1888, 1911, 2790, 3574,
]
# 保留的公共事件（不是额外伤害）：一掷千金 46 扣 1500 金币、不够钱自损——原版玩法，不涉及伤害系数
KEEP_EVENTS = {345: {46}}
# 两个属性都算（次属性系数不低于主属性一半）时用双属性；只写主属性的用单属性
STAT_OVERRIDE = {
    810: ('atk', 'agi'), 3625: ('atk', 'agi'), 4715: ('atk', 'mat'), 4719: ('atk', 'mat'),
    4709: ('atk', 'mat'), 2790: ('atk', 'mat'),
    3913: ('mhp',), 3926: ('mhp',), 3927: ('mhp',), 3928: ('mhp',), 3929: ('mhp',),
    # 固定伤害的几招：按技能类型取主属性
    345: ('atk',), 1274: ('mat',), 1911: ('mat',),
    # 物理技能类型、公式吃魔攻的
    3526: ('mat',), 3604: ('mat',), 3605: ('mat',), 4712: ('mat',),
    # 魔法技能类型、公式吃物攻的（鲸吞天下系列）
    3529: ('atk',), 3557: ('atk',), 3564: ('atk',), 3571: ('atk',),
}
# 生命上限按标准线折成攻击的 25 倍（XTianqiSkills.hit_weight 的 hp_mult），权重写 4%＝等效攻击 1
STAT_WEIGHT = {'mhp': 0.04}
STAT_NAME = {'atk': '物理攻击', 'mat': '魔法攻击', 'agi': '敏捷', 'mhp': '最大生命'}

# 非伤害的四招：手工定
BATCH1_MANUAL = {
    306: {'name': '痛饮', 'kind': '功能', 'heal': {'mmp_pct': 0.1}, 'cooldown': 3,
          'header': {'冷却时间': '3回合'},
          'desc': ['效果：恢复自身 10% 最大魔法', '冷却：3回合'],
          '_note': 'T549 装备招批 1：原固定回 1500 魔法、无冷却 → 最大魔法 10%（附则 E），冷却 3'},
    499: {'name': '先祖之魂', 'kind': '复活', 'heal': {'mhp_pct': 0.3},
          'effects': [{'code': 11, 'dataId': 0, 'value1': 0.3, 'value2': 0}],
          'desc': ['效果：复活一名友方并恢复 30% 最大生命', '冷却：10回合'],
          '_note': 'T549 装备招批 1：原复活回固定 2000 生命 → 30%（技能重构 v0.2 §一.3 复活标准），冷却照原 10'},
    861: {'name': '风语者祝福', 'kind': '治疗', 'heal': {'mhp_pct': 0.12}, 'mp_pct': 10,
          'desc': ['效果：恢复一名友方 12% 最大生命，并施加风之祝福（自然伤害 +20%，3回合）', '消耗：最大魔法10%'],
          '_note': 'T549 装备招批 1：原 1000＋魔攻×6 → 单体治疗 12%（同 T445 通用书单体治疗），耗蓝 300 → 最大魔法 10%'},
    6240: {'name': '龙马复活术', 'kind': '复活', 'heal': {'mhp_pct': 0.3}, 'mp_pct': 30, 'cooldown': 3,
           'effects': [{'code': 11, 'dataId': 0, 'value1': 0.3, 'value2': 0},
                       {'code': 12, 'dataId': 0, 'value1': 0.3, 'value2': 0}],
           'desc': ['效果：复活一名友方并恢复 30% 最大生命和 30% 最大魔法', '消耗：最大魔法30%', '冷却：3回合'],
           '_note': 'T549 装备招批 1：原复活回满生命魔法、无冷却 → 30%＋冷却 3、耗最大魔法 30%（技能重构 v0.2 §一.3、§一.7 复活标准）'},
}
# 状态：捆仙绳的破阵（闪避、暴击、暴击闪避、魔法闪避 −30%～−50%）→ 减益标准 10%
BATCH1_STATES = {
    412: {'name': '破阵——捆仙绳',
          'traits': [{'code': 22, 'dataId': 1, 'value': -0.1}, {'code': 22, 'dataId': 2, 'value': -0.1},
                     {'code': 22, 'dataId': 3, 'value': -0.1}, {'code': 22, 'dataId': 4, 'value': -0.1}],
          'state_note': '闪避率、暴击率、暴击闪避率、魔法闪避率 −10%',
          '_note': 'T549：原暴击 −50%、闪避三项 −30% → 减益标准 10%（技能重构 v0.2 §一.3）'},
}
# 995 汲血斩（Kyo 11-26 事项 80「留：效果恢复，回血按天启篇换成百分比（约 7%）」）：
# 系数 0.5 不动（协调 11-26：替换普攻口径另卡定，995/1968 先不回改），只改序列与卡面
SKILL_995_PATCH = {
    'seq': [{'op': 'replace_cmd', 'match': 'Hp +500', 'to': 'Hp +7%'}],
    'desc': ['效果：两段物理伤害，每段命中后回复自身 7% 最大生命',
             '效果：同时装备血月三件套（血月之铠、血月之盔、血月之靴）时额外释放一次（再两段）',
             '伤害：每段 物理攻击×50%，2 段合计×100%（血月三件套 4 段合计×200%）'],
}


def load(p):
    return json.loads(p.read_text(encoding='utf-8'))


def seq_edit(cmds, ops):
    """XTianqiSkills._seq_edit 的 drop_if／clear_effect_args／drop_cmd 子集（大小写口径同 GDScript）。"""
    out = [list(c) for c in cmds]
    for op in ops:
        kind = op['op']
        if kind == 'drop_if':
            res, i, mt = [], 0, op.get('match', '')
            while i < len(out):
                name = str(out[i][0])
                if name.startswith('if ') and (mt == '' or mt in name):
                    depth, i = 1, i + 1
                    while i < len(out) and depth > 0:
                        n2 = str(out[i][0])
                        if n2.startswith('if '):
                            depth += 1
                        elif n2 == 'end':
                            depth -= 1
                        i += 1
                    continue
                res.append(out[i])
                i += 1
            out = res
        elif kind == 'clear_effect_args':
            for c in out:
                if c[0] == 'action effect':
                    c[1] = []
        elif kind == 'drop_cmd':
            out = [c for c in out if c[0] != op['match']]
    return out


def hits_per_target(sk, ops):
    seq = sk.get('yepSeq') or {}
    n = 0
    for ph in ('target', 'whole'):
        for c in seq_edit(seq.get(ph, []), ops):
            if str(c[0]).strip().lower() == 'action effect':
                n += 1
    return max(1, n)


def stats_of(sk):
    sid = sk['id']
    if sid in STAT_OVERRIDE:
        return STAT_OVERRIDE[sid]
    f = sk['damage']['formula']
    has_atk = re.search(r'\ba\.atk\b', f) is not None
    has_mat = re.search(r'\ba\.mat\b', f) is not None
    if has_atk and has_mat:
        return ('atk', 'mat')
    if has_mat:
        return ('mat',)
    if has_atk:
        return ('atk',)
    return ('atk',) if sk['stypeId'] in (0, 1) else ('mat',)


def damage_row(sk, elements, states):
    sid, scope = sk['id'], sk['scope']
    area = scope in (2, 8, 10)
    rand = scope - 2 if 3 <= scope <= 6 else 1
    old_cd = int(str(sk['meta'].get('Cooldown', '0')).strip() or 0)
    stats = stats_of(sk)
    physical = 'atk' in stats or (stats == ('mhp',)) or ('agi' in stats)
    if stats == ('atk', 'mat'):
        physical = sk['stypeId'] in (0, 1)
    total = 2 if area else 3
    ops = [{'op': 'drop_if'}, {'op': 'clear_effect_args'}]
    seq = sk.get('yepSeq') or {}
    gains = sorted({c[0] for ph in ('target', 'whole') for c in seq.get(ph, [])
                    if re.match(r'(?i)(?:hp|mp|tp)\s*[+-]', c[0])})
    ops += [{'op': 'drop_cmd', 'match': g} for g in gains]
    per_target = hits_per_target(sk, ops) * max(1, int(sk.get('repeats', 1)))
    hits = per_target * rand
    # 每段每个属性的整数百分比（附则 E），向下取整防超档
    per_stat_pct = (total * 100) // (hits * len(stats))
    split = 1
    while per_stat_pct > 100 and per_stat_pct % 100:  # 校验：系数是整数或 <1 的整数百分比；超 1 又不是整数就原地拆段（T081 split_effects）
        split += 1
        per_stat_pct = (total * 100) // (hits * split * len(stats))
    if split > 1:
        ops = ops + [{'op': 'split_effects', 'n': split}]
        per_target *= split
        hits *= split
    if per_stat_pct < 1:
        raise SystemExit(f'{sid} 段数 {hits} 太多，系数不到 1%')
    w = {k: STAT_WEIGHT.get(k, 1) for k in stats}
    row = {'name': sk['name'], 'kind': '爆发全体' if area else ('爆发随机' if rand > 1 else '爆发'),
           'damage': {'stats': w, 'coef': per_stat_pct / 100}}
    if physical:
        row['tp'] = 35
        row['mp'] = 0
    else:
        row['tp'] = 0
        row['mp_pct'] = 15 if area else 10
    cd = max(3, old_cd)
    row['cooldown'] = cd
    row['seq'] = ops
    eff_rm = [[44, e['dataId']] for e in sk['effects']
              if e['code'] == 44 and e['dataId'] not in KEEP_EVENTS.get(sid, set())]
    if eff_rm:
        row['effects_remove'] = eff_rm
    caps = []
    for e in sk['effects']:
        if e['code'] == 21 and e['dataId'] and e['value1'] > 0.25:
            st = states[e['dataId']]
            if st and st.get('restriction', 0) >= 2:
                caps.append({'code': 21, 'dataId': e['dataId'], 'value1': 0.25})
    if caps:
        row['effects'] = caps
    header = {}
    if '<pos=APs text=冷却时间:' in sk['note']:
        header['冷却时间'] = f'{cd}回合'
    if header:
        row['header'] = header
    elem = elements[sk['damage']['elementId']] if 0 < sk['damage']['elementId'] < len(elements) else ''
    if sk['damage']['elementId'] == -1:
        elem = ''
    if rand > 1:
        target = f'随机攻击敌人 {rand} 次（每次 {per_target} 段），共 '
    else:
        target = '对全体敌人造成' if area else '对单个敌人造成'
    seg = f'{hits} 段' if hits > 1 else '一段'
    if area and per_target > 1:
        target, seg = '对全体敌人各造成', f'{per_target} 段'
    elem_txt = f'{elem}伤害' if elem and elem != '物理' else ('物理伤害' if physical else '魔法伤害')
    names = '、'.join(STAT_NAME[k] for k in stats)
    each = f'{names}{"各" if len(stats) > 1 else ""}×{per_stat_pct}%'
    if stats == ('mhp',):
        each = f'最大生命×{per_stat_pct * 4 / 100:g}%'
    if (per_target if area else hits) > 1:
        n = per_target if area else hits
        tot = f'{per_stat_pct * n * 4 / 100:g}%' if stats == ('mhp',) else f'{per_stat_pct * n * len(stats)}%'
        dmg_line = f'伤害：每段 {each}，{n} 段合计×{tot}'
    else:
        dmg_line = f'伤害：{each}'
    if stats == ('mhp',):
        dmg_line += '（生命按标准线折算，合计相当于物理攻击×%d%%）' % (per_stat_pct * hits)
    row['desc'] = [f'效果：{target}{seg}{elem_txt}', dmg_line]
    row['desc'].append('消耗：TP 35' if physical else f'消耗：最大魔法{row["mp_pct"]}%')
    row['desc'].append(f'冷却：{cd}回合')
    row['_note'] = (f'{TAG} 装备招批 1（漏项扫描 C 类）：原 {sk["damage"]["formula"][:60]}'
                    f' → 爆发档合计 {total}（{hits} 段×{per_stat_pct}%×{len(stats)} 属性），去固定底数／熟练度／条件连段')
    return row, hits


def plan():
    skills = load(DB / 'Skills.json')
    states = load(DB / 'States.json')
    elements = load(DB / 'System.json')['elements']
    rows, hits = {}, {}
    for sid in BATCH1_DAMAGE:
        sk = skills[sid]
        assert sk['damage']['type'] in (1, 2, 5, 6), sid
        rows[str(sid)], hits[sid] = damage_row(sk, elements, states)
    for sid, row in BATCH1_MANUAL.items():
        rows[str(sid)] = dict(row)
    for sid in BATCH2_ATTACK:
        sk = skills[sid]
        assert sk['damage']['type'] in (1, 2, 5, 6), sid
        rows[str(sid)], hits[sid] = attack_row(sk, elements)
    rows['4442'] = dict(BATCH2_HEAL_4442)
    return rows, hits


# ---- 批 2：替换普攻（Replace Attack）104 招＋武器触发（Weapon Unleash）13 招 ----
# Kyo 11-26 事项 82 定甲：天启篇我方普攻照稿＝物攻×1；替换普攻统一普攻 1.0 模板，招牌最高 1.5；995／1968 保持 1.0（T541 已改，不动）。
# 武器触发（普攻时 X% 换成这招）同属普攻位，按同一模板。招牌＝原版品质 8（传说装备的专属普攻），其余 1.0。
BATCH2_ATTACK = [
    12, 179, 288, 293, 299, 300, 301, 308, 344, 370, 444, 445, 491, 492, 493, 494, 554, 570, 572, 587, 616, 617,
    635, 636, 637, 639, 640, 647, 658, 682, 767, 768, 769, 770, 788, 811, 813, 834, 851, 860, 869, 871, 884, 885,
    886, 890, 891, 938, 944, 992, 1003, 1004, 1007, 1023, 1024, 1050, 1273, 1278, 1279, 1353, 1690, 1866, 1871,
    1872, 1946, 1969, 1970, 2252, 2284, 2440, 2442, 2443, 2602, 2635, 2636, 2815, 2816, 3181, 3188, 3189, 3190,
    3191, 3547, 3548, 3573, 3575, 3649, 3651, 3887, 3888, 3889, 3890, 4369, 4437, 4441, 4444, 4708, 4716, 4722,
    5420, 6015, 6016, 6017, 6018,
    # 武器触发
    127, 258, 259, 294, 295, 296, 309, 495, 496, 497, 638, 2802, 2806,
]
BATCH2_HEAL_4442 = {
    'name': '悦耳', 'kind': '普攻', 'heal': {'mhp_pct': 0.1}, 'mp': 0, 'tp': 0,
    'desc': ['效果：普通攻击变为治疗一名友方，恢复 10% 最大生命并附加「悦耳」'],
    '_note': f'{TAG} 装备招批 2：优雅提琴的替换普攻是单体治疗，原 800＋魔攻×2 → 最大生命 10%（普攻位，低于技能单体治疗 30% 的标准）'}
STAT_KEYS = ('atk', 'mat', 'agi', 'luk', 'def', 'mdf')
STAT_NAME.update({'luk': '幸运', 'def': '物理防御', 'mdf': '魔法防御'})


def attack_stats(sk):
    """主属性取公式里系数最大的那项；次属性系数不低于主属性一半才一起算（各占一份）。只吃生命的按生命折算。"""
    f = sk['damage']['formula']
    w = {}
    for k in STAT_KEYS:
        for m in re.finditer(rf'a\.{k}\s*\*\s*\(?\s*([\d.]+)|([\d.]+)\s*\*\s*a\.{k}\b', f):
            w[k] = max(w.get(k, 0.0), float(m.group(1) or m.group(2)))
        if k not in w and re.search(rf'\ba\.{k}\b', f):
            w[k] = 1.0
    if not w:
        if re.search(r'\ba\.mhp\b', f):
            return ('mhp',)
        return ('atk',) if sk['stypeId'] in (0, 1) else ('mat',)
    top = max(w.values())
    order = sorted(w, key=lambda k: (-w[k], STAT_KEYS.index(k)))
    return tuple(k for k in order if w[k] * 2 >= top)[:2]  # 最多两项（主＋次），多属性平均吃的取系数最高的两项


def attack_row(sk, elements):
    sid, scope = sk['id'], sk['scope']
    area = scope in (2, 8, 10)
    rand = scope - 2 if 3 <= scope <= 6 else 1
    sig = int(str(sk['meta'].get('quality', '0')).strip() or 0) >= 8
    total = 150 if sig else 100
    if area:
        total //= 2   # 全体按常规表「全体是单体一半」
    stats = attack_stats(sk)
    ops = [{'op': 'drop_if'}, {'op': 'clear_effect_args'}]
    seq = sk.get('yepSeq') or {}
    gains = sorted({c[0] for ph in ('target', 'whole') for c in seq.get(ph, [])
                    if re.match(r'(?i)(?:hp|mp|tp)\s*[+-]', c[0])})
    ops += [{'op': 'drop_cmd', 'match': g} for g in gains]
    per_target = hits_per_target(sk, ops) * max(1, int(sk.get('repeats', 1)))
    hits = per_target * rand
    per = total // (hits * len(stats))
    split = 1
    while per > 100 or (per >= 100 and per % 100):
        split += 1
        per = total // (hits * split * len(stats))
    if per < 1:
        raise SystemExit(f'{sid} 段数 {hits} 太多，系数不到 1%')
    if split > 1:
        ops.append({'op': 'split_effects', 'n': split})
        per_target *= split
        hits *= split
    w = {k: STAT_WEIGHT.get(k, 1) for k in stats}
    row = {'name': sk['name'] or f'替换普攻{sid}', 'kind': '普攻', 'tp': 0, 'mp': 0,
           'damage': {'stats': w, 'coef': per / 100}, 'seq': ops}
    if re.search(r'(?i)<\s*Cooldown\s*:', sk['note']):
        row['note_remove'] = ['Cooldown']
    if '<pos=APs text=冷却时间:' in sk['note']:
        row['header'] = {'冷却时间': '无'}
    eff_rm = [[44, e['dataId']] for e in sk['effects'] if e['code'] == 44]
    if eff_rm:
        row['effects_remove'] = eff_rm
    eid = sk['damage']['elementId']
    elem = elements[eid] if 0 < eid < len(elements) else ''
    elem_txt = f'{elem}伤害' if elem and elem != '物理' else ('物理伤害' if eid in (-1, 0, 1) else '伤害')
    if stats == ('mhp',):
        each = f'最大生命×{per * 4 / 100:g}%'
    else:
        each = f'{"、".join(STAT_NAME[k] for k in stats)}{"各" if len(stats) > 1 else ""}×{per}%'
    n = per_target if area else hits
    if rand > 1:
        head = f'效果：普通攻击变为随机攻击敌人 {rand} 次（每次 {per_target} 段）的{elem_txt}'
    elif area:
        head = f'效果：普通攻击变为对全体敌人各 {per_target} 段的{elem_txt}' if per_target > 1 else f'效果：普通攻击变为对全体敌人的{elem_txt}'
    else:
        head = f'效果：普通攻击变为 {hits} 段{elem_txt}' if hits > 1 else f'效果：普通攻击变为{elem_txt}'
    tot = f'{per * n * len(stats) * (4 if stats == ("mhp",) else 1) / (100 if stats == ("mhp",) else 1):g}%'
    dmg = f'伤害：每段 {each}，{n} 段合计×{tot}' if n > 1 else f'伤害：{each}'
    row['desc'] = [head, dmg]
    row['_note'] = (f'{TAG} 装备招批 2（替换普攻，Kyo 事项 82 甲）：原 {sk["damage"]["formula"][:60]}'
                    f' → 普攻{"招牌 1.5" if sig else " 1.0"}{"（全体减半）" if area else ""}，{hits} 段×{per}%×{len(stats)} 属性，去固定底数／熟练度／条件连段／耗蓝冷却')
    return row, hits


def apply(sr, rows):
    out = json.loads(json.dumps(sr))
    for k, v in rows.items():
        if k in out['skills'] and not str(out['skills'][k].get('_note', '')).startswith(TAG):
            raise SystemExit(f'skills/{k} 已在改写表里、不是本单写的，不覆盖')
        out['skills'][k] = v
    for k, v in BATCH1_STATES.items():
        out['states'][str(k)] = v
    s995 = out['skills']['995']
    s995['seq'] = SKILL_995_PATCH['seq']
    s995['desc'] = SKILL_995_PATCH['desc']
    for k, lines in DESC_PATCH.items():
        out['skills'][k]['desc'] = lines
    for k, v in BATCH1_GEAR.items():
        if k in out['gear'] and not str(out['gear'][k].get('_note', '')).startswith(TAG):
            raise SystemExit(f'gear/{k} 已在改写表里、不是本单写的，不覆盖')
        out['gear'][k] = v
    return out


def _skill_pass(gear_name, sid, old, new, card_re, card_to):
    return {'name': gear_name,
            'note_sub': [[rf'<SkillPass0*{sid}:\s*{old}%>', f'<SkillPass{sid}: {new}%>'], [card_re, card_to]],
            '_note': f'{TAG}：本装备给的技能已按爆发档重标，专属技能增伤 +{old}% 压到 +{new}%（同 weapon:1687 绝世好剑先例），卡面同步'}


# T541 核 P2-2 卡面不说假话＋本批专属技能增伤（SkillPass）封顶
BATCH1_GEAR = {
    'armor:3663': _skill_pass('墨锐', 2639, 130, 5, r'湮灭黑洞伤害\+130%', '湮灭黑洞伤害+5%'),
    'armor:3722': _skill_pass('进化:墨锐', 2639, 260, 10, r'湮灭黑洞伤害\+260%', '湮灭黑洞伤害+10%'),
    'armor:3741': _skill_pass('超进化:墨锐', 2639, 360, 15, r'湮灭黑洞伤害\+360%', '湮灭黑洞伤害+15%'),
    'armor:4253': _skill_pass('究极进化:墨锐', 2639, 720, 20, r'湮灭黑洞伤害\+720%', '湮灭黑洞伤害+20%'),
}
# 已在 gear_elem_amp.json（T451）里的装备不能再进 skill_rework.gear（校验：两表不重叠）：在它的 subs 里追加（整条备注逐字替换，
# 能力值与 SkillPass 由 XTianqiGear.stat_list → elem_amp_view 重读备注生效）
ELEM_AMP_SUBS = {
    ('weapons', '1371'): [['蒂阿兹之石(普通攻击变为极寒之触，伤害提高65%并且随机攻击2次)',
                           '蒂阿兹之石(普通攻击变为极寒之触：一段寒冰伤害，附冰冷V与冰封血脉)']],  # T541 核 P2-2
    ('weapons', '1609'): [['<SkillPass3647: 500%>', '<SkillPass3647: 20%>'], ['汲血连环斩伤害+500%', '汲血连环斩伤害+20%']],
    ('armors', '3774'): [['<SkillPass3624: 325%>', '<SkillPass3624: 20%>'], ['三眼神光伤害+350%', '三眼神光伤害+20%']],
    ('armors', '3775'): [['<SkillPass3625: 325%>', '<SkillPass3625: 20%>'], ['斩天拔剑术伤害+325%', '斩天拔剑术伤害+20%']],
    ('armors', '3776'): [['<SkillPass3626: 325%>', '<SkillPass3626: 20%>'], ['荒芜剑诀伤害+325%', '荒芜剑诀伤害+20%']],
}


def apply_elem_amp(ea):
    out = json.loads(json.dumps(ea))
    for (sec, k), pairs in ELEM_AMP_SUBS.items():
        row = out[sec][k]
        subs = row.setdefault('subs', [])
        for p in pairs:
            if p not in subs:
                subs.append(p)
    return out


# T541 核 P3-4：卡面写「每段×%，N 段合计×%」
DESC_PATCH = {
    '3549': ['效果：六段物理伤害', '伤害：每段 物理攻击、敏捷各×25%，6 段合计×300%', '冷却：3回合'],
    '3624': ['效果：三段神圣伤害', '伤害：每段 魔法攻击×100%，3 段合计×300%', '消耗：最大魔法10%', '冷却：3回合'],
}


def patch_line(text, sec, key, value):
    """改写表是「顶层一节一行一条」的手排格式：只替换／追加这一条的那一行，别的行原样不动（diff 干净）。"""
    lines = text.split('\n')
    head = f' "{sec}": {{'
    start = lines.index(head)
    end = start + 1
    while lines[end] not in (' },', ' }'):
        end += 1
    row = f'  {json.dumps(key, ensure_ascii=False)}: {json.dumps(value, ensure_ascii=False)}'
    pre = f'  {json.dumps(key, ensure_ascii=False)}: '
    for i in range(start + 1, end):
        if lines[i].startswith(pre):
            lines[i] = row + (',' if lines[i].endswith(',') else '')
            return '\n'.join(lines)
    lines[end - 1] += ','
    lines.insert(end, row)
    return '\n'.join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--list', action='store_true', help='打印逐招段数与系数')
    a = ap.parse_args()
    path = DATA / 'skill_rework.json'
    sr = load(path)
    rows, hits = plan()
    new = apply(sr, rows)
    if a.list:
        for k, v in rows.items():
            print(k, v['name'], v['kind'], v.get('damage', v.get('heal')), 'cd', v.get('cooldown'), '|', ' / '.join(v['desc']))
    if new == sr and apply_elem_amp(load(DATA / 'gear_elem_amp.json')) == load(DATA / 'gear_elem_amp.json'):
        print(f'{TAG}：改写表已是最新（{len(rows)} 招）')
        return 0
    if not a.write:
        print(f'{TAG}：改写表与生成结果不一致（{len(rows)} 招），传 --write 更新')
        return 1
    text = path.read_text(encoding='utf-8')
    for sec in ('skills', 'states', 'gear'):
        for k, v in new[sec].items():
            if sr[sec].get(k) != v:
                text = patch_line(text, sec, k, v)
    assert json.loads(text) == new, '文本补丁结果与生成结果不一致'
    path.write_text(text, encoding='utf-8')
    ea_path = DATA / 'gear_elem_amp.json'
    ea = load(ea_path)
    ea_new = apply_elem_amp(ea)
    text = ea_path.read_text(encoding='utf-8')
    for sec in ('weapons', 'armors'):
        for k, v in ea_new[sec].items():
            if ea[sec].get(k) != v:
                text = patch_line(text, sec, k, v)
    assert json.loads(text) == ea_new
    ea_path.write_text(text, encoding='utf-8')
    print(f'{TAG}：已写入 {len(rows)} 招')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
