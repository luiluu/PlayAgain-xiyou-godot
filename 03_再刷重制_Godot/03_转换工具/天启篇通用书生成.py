#!/usr/bin/env python3
"""按 T444 定稿样板生成通用书第二批。默认检查，--write 更新运行表。"""

import argparse
from collections import Counter, defaultdict
import json
from math import prod
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent.parent / '01_Godot工程' / 'modes' / 'xiyou'
DATA = ROOT / 'tianqi_data'
DB = ROOT / 'generated' / 'db'
GROUP = 'remaining_books'
STAT_NAMES = ('最大生命', '最大魔法', '物理攻击', '物理防御', '魔法攻击', '魔法防御', '敏捷', '幸运')
XPARAM_NAMES = ('命中率', '物理闪避率', '暴击率', '被暴击率', '魔法闪避率', '反射率',
                '反击率', '生命回复率', '魔法回复率', 'TP 回复率')
TAG = re.compile(r'<([A-Za-z][\w ]*?)(?:\s*:\s*([^<>\n]+))?>')
START_STATE_PREFIX = r'Start(?:AE|WT|Rom(?:Act|Eme)?)?PushState'
START_STATE = rf'{START_STATE_PREFIX}\d+'
MASTERY = r'Custom (?:Damage|EXP) Mastery Formula|Mastery Effect'
STATES = re.compile(rf'(?:{START_STATE_PREFIX}|RecPushState|Push(?:sub)?State)(\d+)$', re.I)
REPLACE_ATTACK = re.compile(r'<(?:Replace Attack|Attack Replace):\s*(\d+)\s*>', re.I)
CHANGE_TO = re.compile(r'<ChangeTo\[(\d+)\]:')
OLD_TOOLTIP = r'<pos=APs text=(?:TP恢复\+\d+|\\c\[10\]注意:初次学完此技能)[^>]*>'
PCT = re.compile(r'([+-]?\d+(?:\.\d+)?)\s*%?$')
NON_BOOK_TAGS = {'quality', 'ici', 'Hide in Battle', 'DamageElements', 'Replace Attack', 'Attack Replace'}
# 可独立生效且已由状态系统处理的控制、元素异常；其它高危触发改成该书自身的加法池。
STATUS_FAMILY = {
    **dict.fromkeys((5, 6, 7, 8, 9, 10, 741, 742), 'control'),
    **dict.fromkeys(range(17, 22), 'burn'),
    **dict.fromkeys((12, 13, 14, 15, 16, 81, 521), 'physical'),
    **dict.fromkeys((22, 23, 24, 25, 26, 241, 523), 'ice'),
}
REPLACEMENTS = {
    2821: [('passivePBST6', '10%')],
    3671: [('SkillPass2848', '8%'), ('SkillPass3669', '8%'), ('SkillPass3673', '8%')],
    4655: [('SkillTypesDvupB', '8%')],
    4689: [('SkillPass3677', '12%'), ('SkillPass3681', '12%')],
    6141: [('CodexParamRate', '0:10')],
    6149: [('passiveCrHarmRi', '12'), ('passiveHarmRi', '5')],
}
# 原账本的稳定状态入池案例，保留合法装配限制和演出；进③仍由总账逐本截断。
STATE_ONLY = {1038, 978, 991}
# 由 XTianqiLedger.NO_PILL_PASSIVES 管理，旧视图必须保留原来的开战状态。
PILL_PASSIVES = {5974, 5975, 5976, 5977}
SPECIAL_ACTIVE = {124, 282, 642}
ACTIVE_KEEP_EVENTS = {5544, 5545}
RANKED_SERIES = (5091, 5095, 6128, 6150, 6163)
UTILITY = {1821: '解除中毒', 2824: '为全队施加光明护盾', 5544: '解除敌方护盾',
           5545: '转换敌方免疫', 6507: '激励全队并恢复资源', 6609: '为自身充能'}


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def event_teaching(cid, events, skills, visited):
    if cid in visited or not 0 < cid < len(events) or not events[cid]:
        return set()
    visited.add(cid)
    commands = events[cid]['list']
    recruits = {c['parameters'][0] for c in commands
                if c['code'] == 129 and c['parameters'][1] == 0}
    taught, declared = set(), set()
    for cmd in commands:
        code, p = cmd['code'], cmd['parameters']
        if code == 318 and len(p) > 3 and p[2] == 0 and not (p[0] == 0 and p[1] in recruits):
            taught.add(p[3])
        elif code == 117:
            taught.update(event_teaching(p[0], events, skills, visited))
        elif code in (355, 655) and p:
            taught.update(map(int, re.findall(r'\blearnSkill\((\d+)\)', p[0])))
            declared.update(map(int, re.findall(r'\bvar\s+k\w*\s*=\s*(\d+)\s*;', p[0])))
    if taught:
        # 精通公共事件的首星可能只在 k1 中声明。排除仅用于遗忘旧技能的 i 等变量。
        taught.update(sid for sid in declared if 0 < sid < len(skills)
                      and skills[sid] and skills[sid]['stypeId'] == 4)
    return taught


def skill_sources(db_dir, skills, events):
    direct, event_items = defaultdict(set), defaultdict(set)
    items = load(db_dir / 'Items.json')
    for item in filter(None, items):
        for effect in item.get('effects', []):
            code, target = effect['code'], effect['dataId']
            if code == 43:
                direct[target].add(item['id'])
            elif code == 44:
                event_items[target].add(item['id'])
    by_event = {cid: ids for cid in event_items
                if (ids := event_teaching(cid, events, skills, set()))}
    via_ce = {sid for ids in by_event.values() for sid in ids}
    return set(direct), via_ce, len({iid for event in by_event for iid in event_items[event]})


def active_row(sk, states, replacement=False):
    sid, stype, scope, kind = (sk[k] for k in ('id', 'stypeId', 'scope', 'damage'))
    kind = kind['type']
    physical = stype in (0, 1) and not (sk['mpCost'] and not sk['tpCost']
                                    and re.search(r'\b[au][\w]*\.mat\b', sk['damage']['formula'])
                                    and not re.search(r'\b[au][\w]*\.atk\b', sk['damage']['formula']))
    quality = int(sk['meta'].get('quality', 1))
    old_cd = int(sk['meta'].get('Cooldown', 0))
    area = scope in (2, 8, 10)
    random_hits = scope - 2 if 3 <= scope <= 6 else 1
    hit_commands = [cmd[0] for phase in ('target', 'whole') for cmd in sk['yepSeq'].get(phase, [])]
    high = quality >= 4 or old_cd >= 3 or sid in SPECIAL_ACTIVE
    mastery = sk['damage']['formula'].count('skillMasteryLevel') > 1 or sid == 282
    if physical:
        template = 'A2' if random_hits > 1 else 'A3' if high else 'A4' if not sk['tpCost'] else 'A1'
    else:
        template = ('B4' if high else 'B2') if area else 'B3' if mastery or high else 'B1'
    coefficient = (3 if high else 2) if not area else (2 if high else 1)
    coefficient_pct = 0
    if random_hits > 1:
        # 向下取整到整数百分比，防止舍入后总倍率跨档。
        coefficient_pct = (200 if physical else coefficient * 100) // random_hits
    row = {'group': GROUP, 'template': template, 'name': sk['name'],
           'tp': (15 if template == 'A2' else 35 if template == 'A3' else 10) if physical else 0,
           'mp': 0, 'repeats': 1}
    if not physical and not replacement:
        row['mp_pct'] = (15 if high else 8) if area else (10 if high else 5)
    if high and template != 'A2':
        row['cooldown'] = max(3, old_cd)
    elif old_cd:
        row['cooldown'] = old_cd
    if replacement:
        row['tp'] = 0
        row.pop('cooldown', None)
    # 旧书的顶栏有独立的消耗／冷却文案，须和运行时数值一起刷新。
    header = {}
    if '<pos=APs text=冷却时间:' in sk['note']:
        header['冷却时间'] = f'{row["cooldown"]} 回合' if row.get('cooldown') else '无'
    if '<pos=APs text=TP消耗:' in sk['note']:
        header['TP消耗'] = str(row['tp'])
    if scope == 2 and '<pos=APs text=对象:' in sk['note']:
        header['对象'] = '全体敌人'
    if header:
        row['header'] = header
    obsolete = rf'{OLD_TOOLTIP}|<pos=APs text=效果:[^>]*>'
    if re.search(obsolete, sk['note']):
        row['note_sub'] = [[obsolete, '']]
    row['note_remove'] = [rf'(?i:TP COST|passiveAPLUS|AgainUse\w+|SkillPass\d+|{START_STATE}|RecPushState\d+|{MASTERY})']
    if kind in (1, 2, 5, 6):
        stat = 'atk' if physical else 'mat'
        if stype == 2 and sk['tpCost'] and re.search(r'\b[au][\w]*\.atk\b', sk['damage']['formula']):
            stat = 'atk'
        row['damage'] = {'stats': {stat: 1}}
        if coefficient_pct and coefficient_pct % 100:
            row['damage']['coef_pct'] = coefficient_pct
        else:
            row['damage']['coef'] = coefficient_pct // 100 if coefficient_pct else coefficient
        if sid == 124:
            row['damage']['conds'] = [{'if': 'target_states', 'per': 0.2, 'cap': 0.2}]
        stat_name = '物理攻击' if stat == 'atk' else '魔法攻击'
        shown = f'{row["damage"]["coef"]} 倍' if 'coef' in row['damage'] else f'{coefficient_pct}%'
        amount = f'{stat_name}的 {shown} 伤害' if shown.endswith('%') else f'{stat_name}的 {shown}伤害'
        if random_hits > 1:
            desc = f'随机攻击 {random_hits} 次，每段造成{amount}'
        else:
            desc = f'{"对全体敌人" if scope == 2 else ""}造成{amount}'
        if sid == 124:
            desc += '。目标带有减益时，伤害提高 20%'
        row['desc'] = [f'效果：{desc}']
    elif kind == 3:
        heal = 8 if area else 12
        row['heal'] = {'mhp_pct': heal / 100}
        row['desc'] = [f'效果：恢复目标 {heal}% 最大生命']
    else:
        row['desc'] = [f'效果：{UTILITY[sid]}']

    # 移走伤害书旧强制施放公共事件。纯辅助两项保留其原生功能入口。
    removed = [[44, e['dataId']] for e in sk['effects'] if e['code'] == 44 and sid not in ACTIVE_KEEP_EVENTS]
    if removed:
        row['effects_remove'] = removed
    # 去旧条件连段、额外固定资源与状态命令，保留本招动画与正式 effects。
    row['seq'] = [{'op': 'drop_if'}, {'op': 'clear_effect_args'}, {'op': 'keep_effects', 'n': 1}]
    row['seq'].extend({'op': 'drop_cmd', 'match': cmd} for cmd in sorted(set(hit_commands))
                      if re.match(r'(?:hp|mp|tp)\s*[+-]|(?:add|remove) state\b', cmd, re.I))
    setup_states = {cmd[0] for cmd in sk['yepSeq'].get('setup', [])
                    if re.match(r'(?:add|remove) state\b', cmd[0], re.I)}
    if setup_states:
        row['setup_seq'] = [{'op': 'drop_cmd', 'match': cmd} for cmd in sorted(setup_states)]
    effects = []
    for effect in sk['effects']:
        if effect['code'] == 21 and effect['dataId'] and effect['value1'] > 0.25:
            state = states[effect['dataId']]
            if scope in (1, 2, 3, 4, 5, 6) and state.get('restriction', 0) >= 2:
                effects.append({'code': 21, 'dataId': effect['dataId'], 'value1': 0.25})
    if effects:
        row['effects'] = effects
    if sid == 449:
        row['effects_add'] = [{'code': 21, 'dataId': 29, 'value1': 0.15, 'value2': 0}]
        row['desc'][0] += '，有 15% 概率使目标眩晕 1 回合'
    return row


def passive_damage_factor(output, stats):
    """D274 单书保守上界：类型互斥，每招只取其专伤，双持至多两种武器。"""
    elements = defaultdict(int)
    skill_types, skills, weapons = [], [], []
    for key, raw in output.items():
        elem = re.fullmatch(r'(?:passiveELUP|Element Amplify\s*)(\d+)', key)
        if elem and int(elem[1]) != 10:  # 治疗独立结算
            elements[int(elem[1])] += max(0, int(raw.rstrip('%')))
        elif key.startswith('SkillTypesDvup'):
            skill_types.append(max(0, int(raw.rstrip('%'))))
        elif key.startswith('SkillPass'):
            skills.append(max(0, int(raw.rstrip('%'))))
        elif key.startswith('SkETypeHarmRi'):
            weapons.append(max(0, int(raw.rstrip('%'))))
    pools = (
        max(0, int(output.get('passiveHarmRi', '0'))),
        max(0, int(output.get('passiveCrHarmRi', '0'))),
        max(elements.values(), default=0),
        max(skill_types, default=0) + max(skills, default=0) + sum(sorted(weapons, reverse=True)[:2]),
        max(0, *(stats.get(ix, 0) for ix in (2, 4, 6, 7))),
    )
    # 整数定点连乘，超过 15% 就按比例分摊；不使用浮点取整来判断边界。
    return prod(100 + pct for pct in pools)


def share_damage_budget(sid, output, stats):
    for first in RANKED_SERIES:
        if not first <= sid < first + 4:
            continue
        rank = sid - first
        if first in (5091, 5095):
            output['passiveHarmRi'] = str((4, 6, 8, 9)[rank])
            stats.update(dict.fromkeys(stats, (2, 3, 4, 5)[rank]))
        else:
            for key in output:
                if key.startswith('passiveELUP'):
                    output[key] = f'{(2, 3, 4, 4)[rank]}%'
                elif key.startswith('SkillPass'):
                    output[key] = f'{(2, 3, 4, 5)[rank]}%'
            output['passiveHarmRi'] = str((2, 3, 4, 5)[rank])
        break

    if passive_damage_factor(output, stats) <= 115 * 100**4:
        return
    keys = ('passiveHarmRi', 'passiveCrHarmRi', 'passiveELUP', 'Element Amplify',
            'SkillTypesDvup', 'SkillPass', 'SkETypeHarmRi')
    original = {k: v for k, v in output.items() if k.startswith(keys)
                and not re.fullmatch(r'(?:passiveELUP|Element Amplify\s*)0*10', k)}
    original_stats = {ix: pct for ix, pct in stats.items() if ix in (2, 4, 6, 7) and pct > 0}
    for scale in range(99, 0, -1):
        for key, raw in original.items():
            pct = int(raw.rstrip('%'))
            if pct > 0:
                output[key] = str(max(1, pct * scale // 100)) + ('%' if raw.endswith('%') else '')
        for ix, pct in original_stats.items():
            stats[ix] = max(1, pct * scale // 100)
        if passive_damage_factor(output, stats) <= 115 * 100**4:
            return
    raise ValueError(f'技能 {sid} 无法分摊到单书上限')


def passive_desc(output, stats, skills, states, system):
    labels, elements, types = [], {}, {}
    named_skills, weapons, procs = defaultdict(list), defaultdict(list), defaultdict(list)
    misc = {'passiveHarmRi': '最终伤害', 'passiveCrHarmRi': '暴击伤害',
            'passivePREE': '先攻概率', 'passiveASUP': '防偷袭概率',
            'ConsumeReduceAll': '资源消耗'}

    def rate(label, pct):
        return f'{label} {pct:+d}%'.replace('-', '−')

    for key, raw in output.items():
        pct = int(raw.rstrip('%'))
        if key in misc:
            labels.append(rate(misc[key], -pct if key == 'ConsumeReduceAll' else pct))
        elif key.startswith(('passiveELUP', 'Element Amplify')):
            ix = int(re.search(r'\d+$', key)[0])
            elements[ix] = elements.get(ix, 0) + pct
        elif key.startswith('SkillTypesDvup'):
            types[key[-1]] = pct
        elif key.startswith('SkillPass'):
            target = skills[int(key.removeprefix('SkillPass'))]
            if target and target['name'].strip():
                named_skills[pct].append(target['name'])
        elif key.startswith('SkETypeHarmRi'):
            weapon = system['weaponTypes'][int(key.removeprefix('SkETypeHarmRi'))]
            weapons[pct].append(weapon)
        elif key.startswith('passiveXPBST'):
            ix = int(key.removeprefix('passiveXPBST'))
            labels.append(rate(XPARAM_NAMES[ix], -pct if ix == 3 else pct))
        elif key == 'passiveIRUP':
            labels.append('物品掉率提高')
        elif key == 'passiveGRUP':
            labels.append('金钱获取提高')
        elif key == 'passiveEXTTP':
            labels.append(f'TP 上限 +{pct}')
        elif key.startswith('passiveSPBST'):
            labels.append(rate('资源获取', pct))
        elif key.startswith(('PushState', 'PushsubState')):
            ix = int(STATES.fullmatch(key)[1])
            state = '封技' if ix == 741 else states[ix]['name']
            procs[key.startswith('PushsubState'), pct].append(state)

    core = range(1, 10)
    if all(ix in elements for ix in core) and len({elements[ix] for ix in core}) == 1:
        labels.append(rate('全系伤害', elements[1]))
        for ix in core:
            del elements[ix]
    if 10 in elements:
        labels.append(rate('治疗效果', elements.pop(10)))
    element_names = defaultdict(list)
    for ix, pct in elements.items():
        element_names[pct].append(system['elements'][ix])
    for pct, names in element_names.items():
        labels.append(rate('、'.join(names) + '伤害', pct))

    if 'B' in types and types.get('C') == types['B']:
        pct = types.pop('B')
        del types['C']
        if types.get('A') == pct:
            del types['A']
            labels.append(rate('1～45 级及三阶技能伤害', pct))
        else:
            labels.append(rate('40～45 级及三阶技能伤害', pct))
    for key, pct in types.items():
        labels.append(rate({'A': '1～30 级', 'B': '40～45 级', 'C': '三阶'}[key] + '技能伤害', pct))
    for pct, names in named_skills.items():
        unique = list(dict.fromkeys(names))
        shown = '、'.join(f'「{name}」' for name in unique[:3])
        labels.append(rate(shown + ('等技能伤害' if len(unique) > 3 else '伤害'), pct))
    for pct, names in weapons.items():
        label = '装备任一武器类型' if set(names) == set(system['weaponTypes'][1:]) else f'装备{"、".join(names)}'
        labels.append(rate(f'{label}时的技能伤害', pct))
    for ix, pct in sorted(stats.items()):
        labels.append(rate(STAT_NAMES[ix], pct))
    for (self_target, pct), names in procs.items():
        shown = '、'.join(names)
        if names == [states[ix]['name'] for ix in range(17, 22)]:
            shown = '灼伤 I～V'
        target = '使自身附加' if self_target else '使目标附加'
        each = '各有' if len(names) > 1 else '有'
        labels.append(f'造成伤害时{each} {pct}% 概率{target}{shown}')
    return labels


def passive_row(sk, ce_skills, skills, states, system):
    sid, name = sk['id'], sk['name']
    quality = int(sk['meta'].get('quality', 1))
    # D1 超过三星仍按三星档的上限；原 CE 的遗忘与升星逻辑继续生效。
    stars = name.count('★') if 5189 <= sid <= 5308 else 0
    rank = min(2, stars - 1) if stars else (0 if quality < 4 else 1 if quality < 8 else 2)
    attr, element, generic = ((6, 8, 10)[rank], (8, 10, 12)[rank], (8, 10, 12)[rank])
    tags = [(k, v) for k, v in TAG.findall(sk['note']) if k not in NON_BOOK_TAGS]
    has_final = any(k == 'passiveHarmRi' for k, _ in tags)
    has_crit = any(k == 'passiveCrHarmRi' for k, _ in tags)
    template = ('D1' if stars else 'D2' if sid in ce_skills else 'C4' if any(k.startswith('SkillTypesDvup') for k, _ in tags)
                else 'C3' if has_final or has_crit else 'C2' if any(k.startswith('passiveELUP') for k, _ in tags) else 'C1')
    output, removed, stats, triggers = {}, [], {}, {}

    for key, raw in tags:
        if key.startswith(('passiveEARM', 'passiveEWPN')) or key == 'SkillCertainHitss':
            continue
        m = STATES.fullmatch(key)
        if m:
            state = int(m[1])
            if state in STATE_ONLY:
                continue
            effect = STATUS_FAMILY.get(state)
            if effect in ('control', 'burn') and key.lower().startswith(('pushstate', 'pushsubstate')):
                triggers[key] = max(1, int(float(raw.rstrip('%'))))
            elif effect in ('physical', 'ice'):
                ix = 1 if effect == 'physical' else 3
                output[f'passiveELUP{ix:02}'] = '8%'
            removed.append(re.escape(key))
            continue
        removed.append(re.escape(key))
        if key == 'CodexParamRate':
            for pair in raw.split(','):
                ix, amt = map(int, pair.split(':'))
                stats[ix] = (8 if sid == 488 else attr) if amt > 0 else -attr
            continue
        m = PCT.fullmatch(raw.strip())
        if not m:
            continue
        val = float(m[1])
        sign = -1 if val < 0 else 1
        if key.startswith('passivePBST'):
            ix = int(key.removeprefix('passivePBST'))
            stats[ix] = sign * (5 if sid == 3687 or has_final else attr)
        elif key == 'passiveHarmRi':
            output[key] = str((8 if has_crit else generic) * sign)
        elif key == 'passiveCrHarmRi':
            output[key] = str((8, 10, 12)[rank] * sign)
        elif key.startswith(('passiveELUP', 'Element Amplify')):
            output[key] = f'{(8 if sid == 3687 else element) * sign}%'
        elif key.startswith('SkillTypesDvup'):
            output[key] = f'{(10 if sid == 2666 else generic) * sign}%'
        elif key.startswith(('SkillPass', 'SkETypeHarmRi')):
            pct = (8, 12, 15)[rank] if stars else (12 if sid == 3687 else generic)
            output[key] = f'{pct * sign}%'
        elif key.startswith('passiveXPBST'):
            output[key] = f'{min(8, attr) * sign}%'
        elif key in ('passiveIRUP', 'passiveGRUP', 'passivePREE', 'passiveASUP'):
            output[key] = str(attr)
        elif key == 'passiveEXTTP':
            output[key] = str(min(20, max(5, int(val))))
        elif key == 'ConsumeReduceAll' or key.startswith('passiveSPBST'):
            output[key] = f'{attr}%'

    for key, value in REPLACEMENTS.get(sid, ()):
        if key == 'CodexParamRate':
            ix, amt = map(int, value.split(':'))
            stats[ix] = amt
        elif key == 'passivePBST6':
            stats[6] = int(value.rstrip('%'))
        else:
            output[key] = value
    # 多个状态各自独立掷骰，逐项整数概率分摊，单书合计至多 10%。
    for key, chance in triggers.items():
        output[key] = f'{min(chance, 10 // len(triggers))}%'
    attack = REPLACE_ATTACK.search(sk['note'])
    certain_hit = any(k == 'SkillCertainHitss' for k, _ in tags)
    neutral_mechanic = (attack or sk['effects'] or certain_hit
                        or any(k.startswith(('passiveEARM', 'passiveEWPN')) for k, _ in tags))
    if not output and not stats and sid not in (2822, 6139, 6159) and not neutral_mechanic:
        output['passiveHarmRi'] = '5' if rank == 0 else '8'
    share_damage_budget(sid, output, stats)
    labels = passive_desc(output, stats, skills, states, system)
    if stats:
        output['CodexParamRate'] = ','.join(f'{ix}:{stats[ix]}' for ix in sorted(stats))
    if sid in (2822, 6139, 6159):
        labels.append('最终伤害 +15%' if sid == 2822 else '最终伤害 +10%')
    if certain_hit:
        labels.append('所有攻击必定命中')
    if attack:
        labels.append(f'普通攻击替换为「{skills[int(attack[1])]["name"]}」')
    if sid == 6127:
        labels.append('可提升六灭秘本境界并领悟剑法')
    row = {'group': GROUP, 'template': template, 'name': name}
    if removed:
        row['note_remove'] = sorted(set(removed))
    if re.search(OLD_TOOLTIP, sk['note']):
        row['note_sub'] = [[OLD_TOOLTIP, '']]
    if output:
        row['note_add'] = '\n' + '\n'.join(f'<{key}:{value}>' for key, value in output.items())
    if labels:
        desc = '，'.join(labels)
        if sid == 2822:
            desc += '。头盔、护甲、裤子及鞋子无法发挥效果'
        row['desc'] = [f'效果：{desc}']
    return row


def plan(table, db_dir=DB, data_dir=DATA):
    skills, states, events, system = (load(db_dir / f'{name}.json')
                                      for name in ('Skills', 'States', 'CommonEvents', 'System'))
    direct, ce, ce_count = skill_sources(db_dir, skills, events)
    role = load(data_dir / 'skill_rework.json')['skills']
    secret = load(data_dir / 'secret_books.json')
    split = secret['seal_exempt']
    costume = range(split['costume_range'][0], split['costume_range'][1] + 1)
    conversion = set(secret['conversion_items'].values()) - {secret['conversion_items']['_note']}
    prior = {sid for sid, row in table['skills'].items() if row.get('group') != GROUP}
    exemptions, covered, generated = {}, set(), {}
    replacement, morphs, taught_by_skill, visited = set(), set(), set(), set()
    pending = (direct | ce | set(map(int, prior))).copy()
    while pending:
        sid = pending.pop()
        if sid in visited:
            continue
        visited.add(sid)
        key = str(sid)
        if not 0 < sid < len(skills) or not skills[sid] or not skills[sid]['name'].strip():
            exemptions[key] = '数据库没有可学技能'
            continue
        sk = skills[sid]
        stype = sk['stypeId']
        if key in prior:
            pass
        elif key in role:
            exemptions[key] = '角色技能重构表接管'
        elif stype == 6:
            exemptions[key] = 'T443 功法表接管'
        elif sid in conversion:
            exemptions[key] = '元素转换规则接管，无附加伤害'
        elif sid in costume:
            exemptions[key] = '独立时装系统，按秘籍格既有豁免'
        elif sid in PILL_PASSIVES:
            exemptions[key] = '万灵增元丹被动由总账开关接管'
        elif sid in split['bloodlines'] or sid in split['not_book'] or 'CodexPower' in sk['meta']:
            exemptions[key] = '血脉、进阶或权能另表接管'
        else:
            covered.add(sid)
        if key in exemptions:
            continue
        targets = set(map(int, REPLACE_ATTACK.findall(sk['note'])))
        replacement.update(targets)
        pending.update(targets - visited)
        if key not in prior and stype in (0, 1, 2):
            targets = set(map(int, CHANGE_TO.findall(sk['note'])))
            morphs.update(targets)
            pending.update(targets - visited)
        if key in prior or stype == 4 or sid in ACTIVE_KEEP_EVENTS:
            removed_events = table['skills'].get(key, {}).get('effects_remove', []) if key in prior else []
            for effect in sk['effects']:
                cid = effect['dataId']
                if effect['code'] == 44 and [44, cid] not in removed_events:
                    learned = event_teaching(cid, events, skills, set())
                    taught_by_skill.update(learned)
                    pending.update(learned - visited)

    for sid in sorted(covered):
        sk, key = skills[sid], str(sid)
        stype = sk['stypeId']
        if stype in (1, 2) or (stype == 0 and sid in replacement):
            generated[key] = active_row(sk, states, sid in replacement - direct - ce)
        elif stype == 4:
            generated[key] = passive_row(sk, ce | taught_by_skill, skills, states, system)
        else:
            raise ValueError(f'未归类的书教技能 {sid}（类别 {stype}）')
    stats = {'direct_skills': len(direct), 'ce_items': ce_count, 'ce_skills': len(ce),
             'replacement_skills': len(replacement), 'change_to_skills': len(morphs),
             'skill_ce_taught': len(taught_by_skill),
             'templates': dict(sorted(Counter(row['template'] for row in generated.values()).items()))}
    return generated, dict(sorted(exemptions.items(), key=lambda row: int(row[0]))), stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    path = DATA / 'general_books.json'
    table = load(path)
    rows, exemptions, stats = plan(table)
    print(json.dumps(stats, ensure_ascii=False))
    if args.write:
        table['groups'][GROUP] = list(map(int, rows))
        table['skills'] = {sid: row for sid, row in table['skills'].items() if row.get('group') != GROUP}
        table['skills'].update(rows)
        table['coverage_exemptions'] = exemptions
        path.write_text(json.dumps(table, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
        return 0
    actual = {k: v for k, v in table['skills'].items() if v.get('group') == GROUP}
    if rows != actual or list(map(int, rows)) != table['groups'].get(GROUP) or exemptions != table.get('coverage_exemptions'):
        print('通用书表和确定性生成结果不同，请检查改动或更新生成表。')
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
