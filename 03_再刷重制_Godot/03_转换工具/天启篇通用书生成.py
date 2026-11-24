#!/usr/bin/env python3
"""按 T444 定稿样板生成通用书第二批。默认检查，--write 更新运行表。"""

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent.parent / '01_Godot工程' / 'modes' / 'xiyou'
DATA = ROOT / 'tianqi_data'
DB = ROOT / 'generated' / 'db'
GROUP = 'remaining_books'
STAT_NAMES = ('最大生命', '最大魔法', '物理攻击', '物理防御', '魔法攻击', '魔法防御', '敏捷', '幸运')
ELEMENT_NAMES = ('', '物理', '火焰', '寒冰', '大地', '雷电', '自然', '奥术', '神圣', '黑暗')
XPARAM_NAMES = ('命中率', '物理闪避率', '暴击率', '被暴击率', '魔法闪避率', '反射率',
                '反击率', '生命回复率', '魔法回复率', 'TP 回复率')
TAG = re.compile(r'<([A-Za-z][\w ]*?)(?:\s*:\s*([^<>\n]+))?>')
STATES = re.compile(r'(?:Start(?:AE|WT)?Push|RecPush|Push(?:sub)?)State(\d+)$', re.I)
PCT = re.compile(r'([+-]?\d+(?:\.\d+)?)\s*%?$')
NON_BOOK_TAGS = {'quality', 'ici', 'Hide in Battle', 'DamageElements', 'Replace Attack'}
# 可独立生效且已由状态系统处理的控制、元素异常；其它高危触发改成该书自身的加法池。
STATUS_FAMILY = {
    **dict.fromkeys((5, 6, 7, 8, 9, 10, 17, 18, 19, 20, 21, 742), 'control'),
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
SPECIAL_ACTIVE = {124, 282, 642}
UTILITY = {1821: '解除中毒', 2824: '为全队施加光明护盾', 5544: '解除敌方护盾',
           5545: '转换敌方免疫', 6507: '激励全队并恢复资源', 6609: '为自身充能'}


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def skill_sources(db_dir, skills):
    direct, event_items = defaultdict(set), defaultdict(set)
    items = load(db_dir / 'Items.json')
    for item in filter(None, items):
        for effect in item.get('effects', []):
            code, target = effect['code'], effect['dataId']
            if code == 43:
                direct[target].add(item['id'])
            elif code == 44:
                event_items[target].add(item['id'])
    events = load(db_dir / 'CommonEvents.json')
    by_event = {}
    for cid in sorted(event_items):
        if not 0 < cid < len(events) or not events[cid]:
            continue
        commands = events[cid]['list']
        recruits = {c['parameters'][0] for c in commands
                    if c['code'] == 129 and c['parameters'][1] == 0}
        taught, declared = set(), set()
        for cmd in commands:
            code, p = cmd['code'], cmd['parameters']
            if code == 318 and len(p) > 3 and p[2] == 0 and not (p[0] == 0 and p[1] in recruits):
                taught.add(p[3])
            elif code in (355, 655) and p:
                taught.update(map(int, re.findall(r'\blearnSkill\((\d+)\)', p[0])))
                declared.update(map(int, re.findall(r'\bvar\s+k\w*\s*=\s*(\d+)\s*;', p[0])))
        if taught:
            # 精通公共事件的首星可能只在 k1 中声明。排除仅用于遗忘旧技能的 i 等变量。
            by_event[cid] = taught | {sid for sid in declared if 0 < sid < len(skills)
                                      and skills[sid] and skills[sid]['stypeId'] == 4}
    via_ce = {sid for ids in by_event.values() for sid in ids}
    return set(direct), via_ce, len({iid for event in by_event for iid in event_items[event]})


def active_row(sk, states):
    sid, stype, scope, kind = (sk[k] for k in ('id', 'stypeId', 'scope', 'damage'))
    kind = kind['type']
    physical = stype == 1 and not (sk['mpCost'] and not sk['tpCost']
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
    if not physical:
        row['mp_pct'] = (15 if high else 8) if area else (10 if high else 5)
    if high and template != 'A2':
        row['cooldown'] = max(3, old_cd)
    elif old_cd:
        row['cooldown'] = old_cd
    row['note_remove'] = [r'(?i:TP COST|passiveAPLUS|AgainUse\w+|SkillPass\d+)']
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
        desc = f'每段{stat_name}的 {shown}，随机攻击 {random_hits} 次' if random_hits > 1 else f'造成{stat_name}的 {shown}伤害'
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
    removed = [[44, e['dataId']] for e in sk['effects'] if e['code'] == 44 and sid not in (5544, 5545)]
    if removed:
        row['effects_remove'] = removed
    # 去旧条件连段、额外固定资源与状态命令，保留本招动画与正式 effects。
    row['seq'] = [{'op': 'drop_if'}, {'op': 'clear_effect_args'}, {'op': 'keep_effects', 'n': 1}]
    row['seq'].extend({'op': 'drop_cmd', 'match': cmd} for cmd in sorted(set(hit_commands))
                      if re.match(r'(?:hp|mp|tp)\s*[+-]|(?:add|remove) state\b', cmd, re.I))
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


def passive_row(sk, ce_skills):
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
    output, removed = {}, []
    labels = {}
    stats = {}

    def add(key, value, label, unit='%'):
        output[key] = str(value) + unit
        labels[label] = f'{value:+d}%'

    for key, raw in tags:
        if key.startswith(('passiveEARM', 'passiveEWPN')) or key == 'SkillCertainHitss':
            continue
        m = STATES.fullmatch(key)
        if m:
            state = int(m[1])
            if state in STATE_ONLY:
                continue
            effect = STATUS_FAMILY.get(state)
            if effect == 'control' and key == 'PushState':
                removed.append(re.escape(key))
                output[key] = f'{min(10, max(0, int(float(raw.rstrip("%")))))}%'
                continue
            if effect in ('physical', 'ice'):
                ix = 1 if effect == 'physical' else 3
                add(f'passiveELUP{ix:02}', 8, f'{ELEMENT_NAMES[ix]}伤害')
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
            add(key, (8 if has_crit else generic) * sign, '最终伤害', '')
        elif key == 'passiveCrHarmRi':
            add(key, (8, 10, 12)[rank] * sign, '暴击伤害', '')
        elif key.startswith(('passiveELUP', 'Element Amplify')):
            ix = int(re.search(r'\d+$', key)[0])
            add(key, (8 if sid == 3687 else element) * sign, f'{ELEMENT_NAMES[ix]}伤害' if ix < len(ELEMENT_NAMES) else '属性伤害')
        elif key.startswith('SkillTypesDvup'):
            add(key, (10 if sid == 2666 else generic) * sign, f'{key[-1]} 类技能伤害')
        elif key.startswith(('SkillPass', 'SkETypeHarmRi')):
            pct = (8, 12, 15)[rank] if stars else (12 if sid == 3687 else generic)
            add(key, pct * sign, '对应技能伤害' if key.startswith('SkillPass') else '对应武器的技能伤害')
        elif key.startswith('passiveXPBST'):
            ix = int(key.removeprefix('passiveXPBST'))
            pct = min(8, attr) * sign
            add(key, pct, XPARAM_NAMES[ix])
            if ix == 3:
                labels[XPARAM_NAMES[ix]] = f'{-pct:+d}%'
        elif key in ('passiveIRUP', 'passiveGRUP'):
            output[key] = str(attr)
            labels['物品获取' if key == 'passiveIRUP' else '金钱获取'] = '提高'
        elif key in ('passivePREE', 'passiveASUP', 'ConsumeReduceAll'):
            output[key] = f'{attr}%' if key == 'ConsumeReduceAll' else str(attr)
            labels[{'passivePREE': '先攻概率', 'passiveASUP': '防偷袭概率',
                    'ConsumeReduceAll': '资源消耗'}[key]] = f'{"−" if key == "ConsumeReduceAll" else "+"}{attr}%'
        elif key == 'passiveEXTTP':
            output[key] = str(min(20, max(5, int(val))))
            labels['TP 上限'] = f'+{output[key]}'
        elif key.startswith('passiveSPBST'):
            output[key] = f'{attr}%'
            labels['资源获取'] = f'+{attr}%'

    for key, value in REPLACEMENTS.get(sid, ()):
        if key == 'CodexParamRate':
            ix, amt = map(int, value.split(':'))
            stats[ix] = amt
        elif key == 'passiveHarmRi':
            add(key, int(value), '最终伤害', '')
        elif key == 'passiveCrHarmRi':
            add(key, int(value), '暴击伤害', '')
        elif key == 'passivePBST6':
            stats[6] = int(value.rstrip('%'))
        elif key.startswith('SkillPass'):
            add(key, int(value.rstrip('%')), '对应技能伤害')
        elif key.startswith('SkillTypesDvup'):
            add(key, int(value.rstrip('%')), f'{key[-1]} 类技能伤害')
    # 只有重标后仍有独立机制但没伤害标签的书，保留功能。纯再动／固定值行换成同档可用属性。
    neutral_mechanic = ('Replace Attack' in sk['meta'] or bool(sk['effects'])
                        or any(k.startswith(('passiveEARM', 'passiveEWPN')) or k == 'SkillCertainHitss' for k, _ in tags))
    if not output and not stats and sid not in (2822, 6139, 6159) and not neutral_mechanic:
        add('passiveHarmRi', 5 if rank == 0 else 8, '最终伤害', '')
    if stats:
        output['CodexParamRate'] = ','.join(f'{ix}:{stats[ix]}' for ix in sorted(stats))
        for ix in sorted(stats):
            labels[STAT_NAMES[ix]] = f'{stats[ix]:+d}%'
    if sid in (2822, 6139, 6159):
        labels['最终伤害'] = '+15%' if sid == 2822 else '+10%'
    if any(key.startswith('PushState') and raw != '0%' for key, raw in output.items()):
        labels['命中后附加异常'] = '有概率'
    row = {'group': GROUP, 'template': template, 'name': name}
    if removed:
        row['note_remove'] = sorted(set(removed))
    if output:
        row['note_add'] = '\n' + '\n'.join(f'<{key}:{value}>' for key, value in output.items())
    if labels:
        desc = '，'.join(f'{label} {amount}' for label, amount in labels.items())
        if sid == 2822:
            desc += '。头盔、护甲、裤子及鞋子无法发挥效果'
        row['desc'] = [f'效果：{desc}']
    return row


def plan(table, db_dir=DB, data_dir=DATA):
    skills, states = (load(db_dir / f'{name}.json') for name in ('Skills', 'States'))
    direct, ce, ce_count = skill_sources(db_dir, skills)
    role = load(data_dir / 'skill_rework.json')['skills']
    secret = load(data_dir / 'secret_books.json')
    split = secret['seal_exempt']
    costume = range(split['costume_range'][0], split['costume_range'][1] + 1)
    conversion = set(secret['conversion_items'].values()) - {secret['conversion_items']['_note']}
    prior = {sid for sid, row in table['skills'].items() if row.get('group') != GROUP}
    exemptions, generated = {}, {}
    # 两本水果书替换普攻，替换出来的伤害也走同一模板。
    dependencies = {3930, 3931}
    for sid in sorted(direct | ce | dependencies):
        key = str(sid)
        if key in prior:
            continue
        if not 0 < sid < len(skills) or not skills[sid] or not skills[sid]['name'].strip():
            exemptions[key] = '数据库没有可学技能'
            continue
        sk = skills[sid]
        stype = sk['stypeId']
        if key in role:
            exemptions[key] = '角色技能重构表接管'
        elif stype == 6:
            exemptions[key] = 'T443 功法表接管'
        elif sid in conversion:
            exemptions[key] = '元素转换规则接管，无附加伤害'
        elif sid in costume:
            exemptions[key] = '独立时装系统，按秘籍格既有豁免'
        elif sid in split['bloodlines'] or sid in split['not_book'] or 'CodexPower' in sk['meta']:
            exemptions[key] = '血脉、进阶或权能另表接管'
        elif stype in (1, 2):
            generated[key] = active_row(sk, states)
        elif stype == 4:
            generated[key] = passive_row(sk, ce)
        else:
            raise ValueError(f'未归类的书教技能 {sid}（类别 {stype}）')
    stats = {'direct_skills': len(direct), 'ce_items': ce_count, 'ce_skills': len(ce),
             'templates': dict(sorted(Counter(row['template'] for row in generated.values()).items()))}
    return generated, exemptions, stats


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
