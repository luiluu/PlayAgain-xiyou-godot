#!/usr/bin/env python3
"""T080（T012-a 期四暗装填表）生成脚本：照《基础数值重构 v0.3》第四、五节生成 base_line.json、gear_base.json，并打出回验和清单。
只读游戏数据（generated/db 要有，用 新建工作树.sh --补齐 取）和设计仓库的《全角色技能重构 v0.2》；写 tianqi_data/base_line.json、gear_base.json。
  python3 03_转换工具/天启篇期四填表生成.py [--设计仓库 ~/Documents/xiyou-design-docs] [--写表]      不加 --写表只打印
  python3 03_转换工具/天启篇期四填表生成.py --清单            打印件数表／超上限技能清单（交付单附件用）
  python3 03_转换工具/天启篇期四填表生成.py --写属性换算 [--属性清单]   T228：只换 abs_rescale.json 的 <G_ShuXing> 行；清单打成 markdown
"""
import argparse
import collections
import json
import re
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
XIYOU = HERE.parent / '01_Godot工程' / 'modes' / 'xiyou'
DATA = XIYOU / 'tianqi_data'
DB = XIYOU / 'generated' / 'db'

STATS = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk']
LINE = {'A0': 20, 'A1': 20, 'hp_mult': 25, 'mp_mult': 25}
ROLES = {
    '输出': {'hp': 0.9, 'def': 0.9, 'dmg_in_cards': 1.2},
    '均衡': {'hp': 1.0, 'def': 1.0, 'dmg_in_cards': 1.0},
    '坦克': {'hp': 1.2, 'def': 1.2, 'dmg_in_cards': 0.8},
    '辅助': {'hp': 1.0, 'def': 1.0, 'dmg_in_cards': 0.8},
}
SPEED = {'快': 1.2, '中': 1.0, '慢': 0.8}
# 速度档：卡里明写的才填（1 狗逍遥「低敏后手」→慢；45 东方教主「敏捷 ×120%，出手最快」→快）；没写的填中
SPEED_OF = {1: '慢', 45: '快'}
# T081（P3）：卡上没写「X型」、标题行关键字也认不出的几人，按标题行职业重判（理由写在第二格，生成时进 role_notes）
ROLE_REJUDGE = {
    6: ('输出', '吕布：标题「物理斗士（TP 流，靠重放）」，斗士是输出职业，卡里没有坦克、辅助功能'),
    8: ('均衡', '修：四小强，招牌技之外多一个治疗和复活，正是均衡的「一项小功能」，不到辅助'),
    15: ('输出', '张飞：标题「物理斗士（暴击、破胆减益）」，破胆是附带减益，主职是出伤'),
    21: ('输出', '玛莎：标题「风系法师（一招风旋术，击杀叠层）」，只有出伤职责'),
    22: ('输出', '维利：标题「拳击手（拳套，暴击）」，只有出伤职责'),
}
# 部位系数（稿第五节第 2 条表）
SLOTS = {
    '武器': {'etype': 1, 'atk': 1.2},
    '副手': {'etype': 2, 'atk': 0.5, 'hp': 0.3, 'def': 0.3},
    '头部': {'etype': 3, 'hp': 0.5, 'def': 0.5},
    '盔甲': {'etype': 4, 'hp': 1.0, 'def': 0.9},
    '护手': {'etype': 6, 'atk': 0.3, 'hp': 0.2, 'def': 0.3},
    '腰带': {'etype': 8, 'hp': 0.5, 'def': 0.3},
    '裤子': {'etype': 5, 'hp': 0.5, 'def': 0.5},
    '鞋子': {'etype': 7, 'hp': 0.3, 'agi': 0.3},
    '项链': {'etype': 9, 'atk': 0.3, 'hp': 0.2, 'luk': 0.3},
    '戒指': {'etype': 10, 'atk': 0.5, 'hp': 0.1},
}
GRADES = {'putong': 0.6, 'youxiu': 0.8, 'jingliang': 1.0, 'shishi': 1.2, 'chuanshuo': 1.5, 'buxiu': 1.8, 'shenhua': 2.0}
GRADE_NAMES = ['普通', '优秀', '精良', '史诗', '传说', '不朽', '神话']


def jload(p):
    return json.loads(Path(p).read_text(encoding='utf-8'))


def tiers(rework):
    t = rework['tiers']
    return set(t['超强者']), set(t['强者']), set(t['不开放'])


def parse_cards(doc: Path):
    """技能重构 v0.2 每张角色卡：标题行里的编号、职责（卡里「X型」那句优先，没有就看标题行关键字）。"""
    lines = doc.read_text(encoding='utf-8').split('\n')
    heads = [i for i, l in enumerate(lines) if l.startswith('### ') and '｜' in l] + [len(lines)]
    cards = {}
    for a, b in zip(heads, heads[1:]):
        h = lines[a]
        if '轮回者' in h:  # 11 轮回者·里德是轮回后才开放的另一张卡；11 号本体按「8～11 四小强」那张（T081）
            continue
        m = re.match(r'### ([\d、～,]+)', h)
        if not m:
            continue
        ids = []
        for part in m.group(1).split('、'):
            if '～' in part:
                x, y = part.split('～')
                ids += list(range(int(x), int(y) + 1))
            elif part:
                ids.append(int(part))
        parts = h.split('｜')
        desc = parts[2] if len(parts) > 2 else ''
        role = src = None
        for l in lines[a + 1:b]:
            mm = re.match(r'^[\-\s]*(输出|均衡|坦克|辅助)型', l)
            if mm:
                role, src = mm.group(1), '卡内「%s型」' % mm.group(1)
                break
        if role is None:
            pos = {}
            for r, kws in (('坦克', ['坦克', '偏坦']), ('辅助', ['辅助', '治疗']), ('输出', ['输出', '爆发', '刺客'])):
                p = [desc.find(k) for k in kws if k in desc]
                if p:
                    pos[r] = min(p)
            if pos:
                role = min(pos, key=pos.get)
                src = '标题行关键字'
        for i in ids:
            if i in cards and cards[i]['role'] and not role:
                continue
            cards[i] = {'role': role, 'src': src, 'title': h[4:]}
    return cards


def build_actors(doc: Path):
    rework = jload(DATA / 'skill_rework.json')
    sup, strong, hidden = tiers(rework)
    names = {x['id']: x['name'] for x in jload(DB / 'Actors.json') if x and x.get('name')}
    roster = sorted(set(i for i in names if i not in hidden) | {180})
    cards = parse_cards(doc)
    actors, unclear = {}, []
    for i in roster:
        c = cards.get(i, {})
        role = c.get('role')
        if i in ROLE_REJUDGE:
            role = ROLE_REJUDGE[i][0]
        elif not role:
            role = '均衡'
            unclear.append(i)
        actors[str(i)] = {'name': names.get(i, '五条悟'), 'role': role, 'speed': SPEED_OF.get(i, '中'), 'tweak': {}}
    return actors, unclear, rework


# ---- 回验（稿第四节第 4 条）----
W = {'mhp': 25.0, 'mmp': 25.0}


def role_mult(actor, stat):
    r = ROLES[actor['role']]
    if stat == 'mhp':
        return LINE['hp_mult'] * r['hp'] * actor['tweak'].get('mhp', 1.0)
    if stat == 'mmp':
        return LINE['mp_mult'] * actor['tweak'].get('mmp', 1.0)
    if stat in ('def', 'mdf'):
        return r['def'] * actor['tweak'].get(stat, 1.0)
    if stat == 'agi':
        return SPEED[actor['speed']] * actor['tweak'].get('agi', 1.0)
    return actor['tweak'].get(stat, 1.0)


def backtest(actors, rework):
    """每个角色每个带伤害的技能：Σ(权重×本体属性)÷标准线攻击 对 卡面系数的偏差。返回 [(技能号, 角色号, 偏差)]。"""
    out = []
    for sid, v in rework['skills'].items():
        d = v.get('damage')
        if not d or 'actor' not in v or 'max_of' in d:
            continue
        ac = actors.get(str(v['actor']))
        if not ac:
            continue
        st = d.get('stats', {'atk': 1})
        nom = sum(w * W.get(k, 1.0) for k, w in st.items())
        # mhp／mmp 的 role_mult 已含 25 倍，所以直接比 w*role_mult 与 w*W
        new = sum(w * role_mult(ac, k) for k, w in st.items())
        out.append((sid, v['actor'], new / nom - 1))
    return out


# ---- 装备 ----
def gear_items():
    """有等级需求和品质标记的装备（部位 1～10）：(类型, 部位名, 等级需求, 品质档 0～6, 名字)。"""
    uq = jload(DB / 'UnifiedQuality.json')
    grades = uq['itemGrades']
    slot_of = {v['etype']: k for k, v in SLOTS.items()}
    out = []
    for fname in ('Weapons.json', 'Armors.json'):
        for x in jload(DB / fname):
            if not x or x['etypeId'] not in slot_of or str(x['name']).startswith('---'):
                continue
            m = x.get('meta', {})
            if not str(m.get('req_level', '')).strip().isdigit() or 'quality' not in m:
                continue
            q = str(m['quality']).strip()
            g = grades[int(q)] if q.lstrip('-').isdigit() and 0 <= int(q) < len(grades) else (6 if q.isdigit() and int(q) >= 12 else 0)
            out.append((fname[0], slot_of[x['etypeId']], int(str(m['req_level']).strip()), g, x['name']))
    return out


def ratio_table():
    """换算比（稿第五节第 6 条）：标准线(折算等级) ÷ 原版同等级弱者本体中位，按装备等级 0～90 一张表。"""
    actors = jload(DB / 'Actors.json')
    classes = {x['id']: x for x in jload(DB / 'Classes.json') if x}
    rework = jload(DATA / 'skill_rework.json')
    _, _, _ = tiers(rework)
    sup, strong, hidden = tiers(rework)
    weak = [a for a in actors if a and a.get('name') and a['id'] not in (sup | strong | hidden)]

    def body(lv):
        o = {k: [] for k in ('atk', 'hp', 'def', 'agi', 'luk')}
        for a in weak:
            p = classes[a['classId']]['params']
            o['atk'].append(max(p[2][lv], p[4][lv]))
            o['hp'].append(p[0][lv])
            o['def'].append((p[3][lv] + p[5][lv]) / 2)
            o['agi'].append(p[6][lv])
            o['luk'].append(p[7][lv])
        return {k: statistics.median(v) for k, v in o.items()}

    table = {}
    for el in range(0, 91):
        conv = 1 + el * 98 / 90
        lv = max(1, min(99, int(round(conv))))
        line = LINE['A0'] + LINE['A1'] * conv
        b = body(lv)
        table[str(el)] = {
            'atk': round(line / b['atk'], 2), 'hp': round(line * LINE['hp_mult'] / b['hp'], 2),
            'def': round(line / b['def'], 2), 'agi': round(line / b['agi'], 2), 'luk': round(line / b['luk'], 2)}
    return table


BACKTEST_REASON = '坦克职责：伤害 ×0.8 已折在卡的系数里，本体生命、物防魔防 ×1.2；这个技能吃的正是这一项，两样相乘净 ×0.96（卡里写「吃生命和双防」的坦克，招式靠防御打、不比均衡低），不改模板也不改权重，留给核查判断是否要微调；（偏差来自职责系数，不是填错）'


# ---- abs_rescale.json（稿第七节第 4 条）：只扫「能机器扫的」几类，扫不到的写进 unscanned，T012-b 开工接着扫 ----
def weak_body81():
    actors = jload(DB / 'Actors.json')
    classes = {x['id']: x for x in jload(DB / 'Classes.json') if x}
    rework = jload(DATA / 'skill_rework.json')
    sup, strong, hidden = tiers(rework)
    weak = [a for a in actors if a and a.get('name') and a['id'] not in (sup | strong | hidden)]
    return {'mhp': statistics.median(classes[a['classId']]['params'][0][81] for a in weak),
            'mmp': statistics.median(classes[a['classId']]['params'][1][81] for a in weak),
            'main': statistics.median(max(classes[a['classId']]['params'][2][81], classes[a['classId']]['params'][4][81]) for a in weak)}


def literal_only(prog):
    """状态持续伤害程序只是一个字面常数时返回它，否则 None。"""
    try:
        steps = prog['steps']
        if len(steps) == 1 and steps[0]['value']['op'] == 'literal':
            return float(steps[0]['value']['value'])
    except Exception:
        pass
    return None


def capped(key, v, b):
    pct = round(v / b[key] * 100, 1)
    if pct > 100:
        return {'pct_of': key, 'pct': 100, 'over100': pct}  # 原数比弱者 81 级本体还大：先封 100%，原折算值留在 over100，T012-b 看要不要保留
    return {'pct_of': key, 'pct': pct}


def scan_more(b, card_skills):
    """第二批：把 unscanned 六类里能机器扫的扫完。返回 (entries, groups)。"""
    main = b['main']
    entries, groups = [], {}
    enemy_skills = set()
    for e in jload(DB / 'Enemies.json'):
        if e:
            for a in e.get('actions', []):
                enemy_skills.add(a.get('skillId'))
    base_re = re.compile(r'^\(*\s*(\d+(?:\.\d+)?)\s*\+')
    dmg_enemy, dmg_other, heal_rows, drain_rows = [], 0, [], []
    for x in jload(DB / 'Skills.json'):
        if not x or str(x['id']) in card_skills:
            continue
        d = x.get('damage') or {}
        f = d.get('formulaGd') or d.get('formula') or ''
        ty = d.get('type', 0)
        if ty == 0 or not f:
            continue
        m = base_re.match(f.strip())
        const = float(m.group(1)) if m else (float(f) if re.fullmatch(r'\d+(\.\d+)?', f.strip()) else None)
        enemy = x['id'] in enemy_skills
        if ty in (3, 4, 7, 8):
            heal_rows.append({'kind': 'skill_fixed_heal', 'id': x['id'], 'name': x['name'], 'enemy': enemy, 'orig': f[:60],
                              'new': ('固定底数 %g 换成对象生命上限的 %s%%（原数÷弱者 81 级生命）' % (const, round(min(100, const / b['mhp'] * 100), 1))) if const else '公式读对象生命或属性，T012-b 逐条看'})
        elif ty in (5, 6):
            drain_rows.append({'kind': 'skill_fixed_drain', 'id': x['id'], 'name': x['name'], 'enemy': enemy, 'orig': f[:60],
                               'new': '吸取量 %s：换成对象生命／魔法上限的百分比（T012-b 定）' % (f[:20])})
        elif const is not None and const >= 100:
            if enemy:
                dmg_enemy.append([x['id'], x['name'], const, round(const / main * 100, 1)])
            else:
                dmg_other += 1
    entries += heal_rows + drain_rows
    groups['enemy_skill_fixed_base'] = {
        '_note': '敌人用的、没进技能卡的原版技能，伤害公式的固定底数（如 100＋魔攻×10 里的 100）。列：技能号、名字、固定底数、占弱者 81 级主攻（267）的百分比；公式里「属性×系数」的部分随属性涨，不在这里，只有固定底数在新量级里会变轻。底数换成「标准线攻击的百分之几」（new_rule）。',
        'new_rule': '固定底数 → 标准线攻击(81级) × 占比%',
        'columns': ['skill', 'name', 'base', 'pct_of_weak_main81'],
        'rows': dmg_enemy,
    }
    groups['other_skill_fixed_base_count'] = {'_note': '没进卡、不是敌人用的原版技能里带固定底数 ≥100 的个数（多是旧角色技能，天启篇看不到或已被卡改写，不逐条列）', 'count': dmg_other}
    # 装备、状态带的固定回血／回复／护盾
    tags = []
    for f in ('Weapons', 'Armors', 'States'):
        for x in jload(DB / (f + '.json')):
            if not x:
                continue
            note = x.get('note', '')
            if f == 'States' and 'ShieldEffect' in note and False:
                pass
            for m in re.finditer(r'<(ShieldEffect|Regen Formula|DBHPLSteal)\s*:\s*([^<>]*)>', note):
                if f == 'States' and m.group(1) == 'ShieldEffect':
                    continue  # 状态护盾上面 state_shield 已列
                tags.append({'kind': 'note_' + m.group(1).replace(' ', '_').lower(), 'id': x['id'], 'name': x['name'], 'table': f, 'orig': m.group(2),
                             'new': '待 T012-b：数值改生命上限百分比；公式 a.mat*N 这类按属性的随属性涨，不用换'})
    entries += tags
    # 七印装备八项（qiyin_equip.json 的 params）：D137 已定读标准线，列出被取代的原数
    qe = jload(DATA / 'qiyin_equip.json')
    qrows = []
    def walk(v, path):
        if isinstance(v, dict):
            for k, x in v.items():
                if k == 'params' and isinstance(x, list) and len(x) == 8:
                    qrows.append({'path': path, 'params': x})
                else:
                    walk(x, path + '/' + str(k))
        elif isinstance(v, list):
            for i, x in enumerate(v):
                walk(x, '%s/%d' % (path, i))
    walk(qe, 'qiyin_equip')
    groups['qiyin_equip_params'] = {'_note': 'qiyin_equip.json 里写死的八项（神话 80 级同级参照）。D137 已定七印装备读 gear_base.json（80 级神话，武器和真印再 ×1.1），这些原数被取代，T012-b 接线时不再读 params；这里列出路径供对账。', 'rows': qrows}
    groups['alien_gear_rewards'] = {'_note': 'alien_gear.json、rewards.json 没有写死的八项（只有百分比：atk_rate、def_pct、dmg_dealt_pct、heal 等），不用换。净印、遗物的八项：没找到写死数据（遗物是 relic 类物品，走原版装备 params，随装备底子规则）。'}
    # 技能备注里按绝对属性门槛
    pat = re.compile(r'(?:user|a|b|target)\.(?:agi|atk|mat|def|mdf|luk|mhp|mmp|hp|mp)\s*(?:>=|<=|>|<)\s*\d{3,}')
    th = []
    for f in ('Skills', 'States', 'Weapons', 'Armors', 'Items'):
        for x in jload(DB / (f + '.json')):
            if x:
                m = sorted(set(pat.findall(json.dumps(x, ensure_ascii=False))))
                if m:
                    th.append({'table': f, 'id': x['id'], 'name': x['name'], 'in_card': f == 'Skills' and str(x['id']) in card_skills, 'conds': m})
    groups['abs_threshold_in_notes'] = {'_note': '原版技能备注里「属性超过某个绝对值」的门槛（user.agi>=1000 这类），换成「标准线的百分之几」；in_card＝true 的卡已改写，不用换。GDScript 里（core、battle）没有这类比较（已 grep）。', 'rows': th}
    return entries, groups


def build_abs():
    b = weak_body81()
    entries = []
    for x in jload(DB / 'Items.json'):
        if not x:
            continue
        for e in x.get('effects', []):
            if e['code'] in (11, 12) and e.get('value2', 0) != 0:
                key = 'mhp' if e['code'] == 11 else 'mmp'
                v = float(e['value2'])
                entries.append({'kind': 'item_fixed_heal', 'id': x['id'], 'name': x['name'], 'stat': key, 'orig': v,
                                'new': capped(key, v, b)})
    for x in jload(DB / 'States.json'):
        if not x:
            continue
        d = x.get('dot')
        if d:
            v = literal_only(d.get('program', {}))
            ent = {'kind': 'state_dot', 'id': x['id'], 'name': x['name'], 'healing': bool(d.get('healing'))}
            if v is not None:
                ent['orig'] = v
                ent['new'] = capped('mhp', v, b)
            else:
                ent['orig'] = '公式（读 a／b 属性）'
                ent['new'] = '待 T012-b 逐条看：公式里的固定底数要换成标准线百分比'
            entries.append(ent)
    for x in jload(DB / 'States.json'):
        if x and re.search(r'<Shield[^>]*>', x.get('note', '')):
            entries.append({'kind': 'state_shield', 'id': x['id'], 'name': x['name'], 'orig': re.search(r'<Shield[^>]*>', x['note']).group(0),
                            'new': '待 T012-b 看：护盾量改成生命上限的百分之几（卡标准 20%）'})
    more_entries, groups = scan_more(b, set(jload(DATA / 'skill_rework.json')['skills']))
    entries += more_entries
    entries += build_shuxing()  # T228
    return {
        '_note': 'T080：绝对值换比例清单（基础数值重构 v0.3 第七节第 4 条）。原数据一个字不动；总开关 XTianqiBase.PHASE4（T012-b）开着时结算处读这张表、关着读原数。pct＝换算后占对应项（pct_of：mhp 生命上限、mmp 魔法上限）的百分比，按「原数 ÷ 原版弱者 81 级本体中位」折：生命 %.0f、魔法 %.0f。T081 起只接了结构化的两类：药品固定回复（battle_logic._apply_effect）、常数状态持续伤害（ext_dot），其余几类 new 还是文字说明、未接。' % (b['mhp'], b['mmp']),
        'version': 1,
        'base': {'weak_mhp81': b['mhp'], 'weak_mmp81': b['mmp'], 'weak_main81': b['main'], 'shuxing_ref': SHUXING_REF},
        'entries': entries,
        'groups': dict(groups, state_shuxing={'_note': SHUXING_GROUP_NOTE}),
        'unscanned': ['公式型状态持续伤害（41 条里 %d 条是读属性的公式）和 Custom Regenerate Effect 脚本型回复（25 个状态）：底数要逐条拆脚本，没拆，只列号；七首之龙、骑士等 horsemen.json 里的绝对值不在本清单（D78 M5 标）' % sum(1 for e in entries if e['kind'] == 'state_dot' and not isinstance(e['new'], dict))],
    }


# ---- T228：状态备注 <G_ShuXing> 写死的八项加减（G_StateParam），换成「持有者自身该项的整数百分比」 ----
# 口径（协调 11-19 回 T228 问，选 A）：pct＝原数÷参考值×100，四舍五入成整数；原数不为 0 但取整成 0 的记 ±1（min1 列出）。
# 参考值＝T220 前（dev.743，8a4f9d4a4）基准队 81 级八项实测中位：4 弱者随机 8 队（27 人）、等级 81、法宝上限、精良装备，
# 开战前的 param（探针 00_项目管理/归档/交付截图/luiluu_t228/t228_ref_probe.gd.txt，拷回 tests/virtual_player/ 去掉 .txt 跑，--floor=36；HEAD 上 --phase4=off 量出同一组数）。
# 攻击、魔攻两项都用「主攻」中位 1854（每人攻击、魔攻取高的那项；协调 11-19 定甲）：27 人里物理 19、法系 8，各项直接取中位时
# 魔攻只有 489（物理系拉低）、攻击 1493（法系拉低），魔攻 −500 会变 −102%、法系直接清零。分开量：物理系攻击中位 1854、法系魔攻中位 1786。
# 其余六项照各自中位（幸运 282：−500 幸运变 −177%，跟原版 81 级一样扣到 0，不另处理）。
# 战斗里：持有者该项（基础＋加值）×比率×强化率 × pct% × 层数，见 core/battler.gd param_state、core/tianqi_base.gd shuxing_value。
SHUXING_REF = {'mhp': 10778, 'mmp': 4366, 'atk': 1854, 'def': 550, 'mat': 1854, 'mdf': 533, 'agi': 824, 'luk': 282}
SHUXING_NAMES = [(('MHP', 'MAXHP', 'MAX HP', 'HP'), 0), (('MMP', 'MAXMP', 'MAX MP', 'MP'), 1), (('ATK', 'ATTACK'), 2), (('DEF', 'DEFENSE'), 3),
                 (('MAT', 'MAGIC ATTACK', 'M.ATTACK', 'INT'), 4), (('MDF', 'MAGIC DEFENSE', 'M.DEFENSE', 'RES'), 5), (('AGI', 'AGILITY', 'SPD'), 6), (('LUK',), 7), (('ALL',), 8)]


def shuxing_params(note):
    """照 core/power.gd state_params：<G_ShuXing> … </G_ShuXing> 之间每行「名字 = ±数」，ALL 加到八项。返回 (八项, 有没有这个标签)。"""
    out, on, has = [0] * 8, False, False
    for line in note.split('\n'):
        if re.search(r'(?i)<G_ShuXing>', line):
            on = has = True
        elif re.search(r'(?i)</G_ShuXing>', line):
            on = False
        elif on:
            m = re.search(r'(.*)[ ]=[ ]([\+\-]\d+)', line)
            if m:
                nm = m.group(1).upper().strip()
                sid = next((i for names, i in SHUXING_NAMES if nm in names), -1)
                if sid == 8:
                    out = [v + int(m.group(2)) for v in out]
                elif sid >= 0:
                    out[sid] += int(m.group(2))
    return out, has


def shuxing_pct(v, ref):
    if v == 0:
        return 0, False
    q = abs(v) / ref * 100
    pct = int(q + 0.5)
    low = pct == 0
    pct = max(1, pct)
    return (pct if v > 0 else -pct), low


def build_shuxing():
    rows = []
    for x in jload(DB / 'States.json'):
        if not x:
            continue
        orig, has = shuxing_params(x.get('note', ''))
        if not has:
            continue
        pct, low = [], []
        for i, k in enumerate(STATS):
            p, l = shuxing_pct(orig[i], SHUXING_REF[k])
            pct.append(p)
            if l:
                low.append(k)
        e = {'kind': 'state_shuxing', 'id': x['id'], 'name': x['name'], 'orig': orig, 'new': {'pct_of': 'self', 'pct': pct}}
        if low:
            e['min1'] = low
        rows.append(e)
    return rows


SHUXING_GROUP_NOTE = ('T228：状态备注 <G_ShuXing> 写死的八项加减（kind＝state_shuxing，orig、new.pct 都按 mhp,mmp,atk,def,mat,mdf,agi,luk 八格）。'
                      '期四开着且 XTianqiBase.ABS_SHUXING 开着时，战斗里每个状态加的是「持有者该项（基础＋加值）×比率×强化率 × pct% × 层数」，向零取整；关着照原数。'
                      'pct＝原数÷base.shuxing_ref 同项×100 四舍五入成整数，原数不为 0 但取整成 0 的记 ±1（min1 列出是哪几项）。'
                      'pct 可以直接改表；状态备注被天启篇改写、原数跟 orig 对不上时按参考值现算并警告一次。')


def write_shuxing(path):
    """只换 abs_rescale.json 里 state_shuxing 那几行和参考值，其余原样（--写表 会把整张表重生成）。"""
    d = jload(path)
    d['entries'] = [e for e in d['entries'] if e.get('kind') != 'state_shuxing'] + build_shuxing()
    d['base']['shuxing_ref'] = SHUXING_REF
    d['groups']['state_shuxing'] = {'_note': SHUXING_GROUP_NOTE}
    path.write_text(dumps(d), encoding='utf-8')
    return d


# 守层者敌群（同 tests/virtual_player/baseline_dps.gd GUARDIAN）
GUARDIAN_TROOPS = {4, 5, 8, 22, 28, 39, 52, 53, 67, 69, 109, 110, 111, 118, 138, 172, 173, 174, 333} | set(range(456, 470))


def shuxing_holders():
    """每个状态挂在谁身上（静态扫，尽量全）：返回 {状态号: set(标签)}。标签：我方、敌方、守层者，再加来源说明。"""
    skills = {x['id']: x for x in jload(DB / 'Skills.json') if x}
    items = {x['id']: x for x in jload(DB / 'Items.json') if x}
    enemies = {x['id']: x for x in jload(DB / 'Enemies.json') if x}
    troops = {x['id']: x for x in jload(DB / 'Troops.json') if x}
    ces = {x['id']: x for x in jload(DB / 'CommonEvents.json') if x}
    guardian_enemies = set()
    for t in GUARDIAN_TROOPS:
        for m in troops.get(t, {}).get('members', []):
            guardian_enemies.add(m['enemyId'])
    enemy_skill_users = collections.defaultdict(set)
    for e in enemies.values():
        for a in e.get('actions', []):
            enemy_skill_users[a.get('skillId')].add(e['id'])
    actor_skills = set()
    for c in jload(DB / 'Classes.json'):
        if c:
            actor_skills |= {l['skillId'] for l in c.get('learnings', [])}
    actor_skills |= {int(k) for k in jload(DATA / 'skill_rework.json')['skills']}
    out = collections.defaultdict(set)
    sid_re = re.compile(r'(?i)<(?:passive state|passive states)\s*:\s*([\d,\s\-]+)>')

    def add_ids(text, tag):
        for m in sid_re.finditer(text):
            for part in m.group(1).split(','):
                part = part.strip()
                if '-' in part:
                    a, b = part.split('-')
                    for i in range(int(a), int(b) + 1):
                        out[i].add(tag)
                elif part.isdigit():
                    out[int(part)].add(tag)
    # 技能、物品的「附加状态」效果：按使用者和范围判挂到哪边
    for tab, recs in (('技能', skills), ('物品', items)):
        for x in recs.values():
            for ef in x.get('effects', []):
                if ef.get('code') != 21 or not ef.get('dataId'):
                    continue
                sc = x.get('scope', 0)
                to_opp = 1 <= sc <= 6
                users = enemy_skill_users.get(x['id'], set()) if tab == '技能' else set()
                if users:
                    if to_opp:
                        out[ef['dataId']].add('我方')
                    else:
                        out[ef['dataId']].add('守层者' if users & guardian_enemies else '敌方')
                        if users - guardian_enemies:
                            out[ef['dataId']].add('敌方')
                if tab == '物品' or x['id'] in actor_skills:
                    out[ef['dataId']].add('敌方' if to_opp else '我方')
    # 被动状态：角色、职业、装备、技能备注里写的是我方；敌人备注里写的是敌方（守层者另记）
    for f in ('Actors', 'Classes', 'Weapons', 'Armors', 'Skills'):
        for x in jload(DB / (f + '.json')):
            if x:
                add_ids(x.get('note', ''), '我方')
    for e in enemies.values():
        add_ids(e.get('note', ''), '守层者' if e['id'] in guardian_enemies else '敌方')
        for st in [t for t in e.get('traits', []) if t.get('code') == 14]:
            pass

    def scan_list(lst, actor_tag, enemy_tag, ce_tag):
        called = []
        for c in lst:
            code, p = c.get('code'), c.get('parameters', [])
            if code == 313 and len(p) > 3 and p[2] == 0:
                out[p[3]].add(actor_tag)
            elif code == 333 and len(p) > 2 and p[1] == 0:
                out[p[2]].add(enemy_tag)
            elif code == 117 and p:
                called.append(p[0])
        return called
    seen_ce = set()

    def walk_ce(cid, actor_tag, enemy_tag):
        key = (cid, enemy_tag)
        if key in seen_ce or cid not in ces:
            return
        seen_ce.add(key)
        for c2 in scan_list(ces[cid].get('list', []), actor_tag, enemy_tag, None):
            walk_ce(c2, actor_tag, enemy_tag)
    for t in troops.values():
        etag = '守层者' if t['id'] in GUARDIAN_TROOPS else '敌方'
        for pg in t.get('pages', []):
            for cid in scan_list(pg.get('list', []), '我方', etag, None):
                walk_ce(cid, '我方', etag)
    for cid in list(ces):
        walk_ce(cid, '我方', '敌方')
    return out


def shuxing_table():
    """交付单附表（markdown）：编号、名称、原值、换算后、挂在谁身上"""
    hold = shuxing_holders()
    lines = ['| 编号 | 名称 | 原值（非 0 项） | 换算后（持有者该项的 %） | 挂在谁身上 |', '|---|---|---|---|---|']
    nm = ['生命', '魔法', '攻击', '物防', '魔攻', '魔防', '敏捷', '幸运']
    for e in build_shuxing():
        o = '、'.join('%s%+d' % (nm[i], v) for i, v in enumerate(e['orig']) if v)
        n = '、'.join('%s%+d%%%s' % (nm[i], v, '＊' if STATS[i] in e.get('min1', []) else '') for i, v in enumerate(e['new']['pct']) if v)
        h = '、'.join(t for t in ('我方', '敌方', '守层者') if t in hold.get(e['id'], ())) or '没扫到（脚本／插件挂）'
        lines.append('| %d | %s | %s | %s | %s |' % (e['id'], e['name'].replace('|', '／'), o or '（空）', n or '（空）', h))
    return '\n'.join(lines)


def dumps(d):
    return json.dumps(d, ensure_ascii=False, indent=1) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--设计仓库', default=str(Path.home() / 'Documents' / 'xiyou-design-docs'))
    ap.add_argument('--写表', action='store_true')
    ap.add_argument('--清单', action='store_true')
    ap.add_argument('--写属性换算', action='store_true', help='T228：只换 abs_rescale.json 里 <G_ShuXing> 那几行（state_shuxing）和参考值，别的表不动')
    ap.add_argument('--属性清单', action='store_true', help='T228：打印 <G_ShuXing> 状态换算清单（markdown，交付单附表）')
    args = ap.parse_args()
    if args.写属性换算 or args.属性清单:
        if args.写属性换算:
            d = write_shuxing(DATA / 'abs_rescale.json')
            rows = [e for e in d['entries'] if e['kind'] == 'state_shuxing']
            print('已写 abs_rescale.json：state_shuxing %d 行，取整到 ±1 的 %d 行' % (len(rows), sum(1 for e in rows if e.get('min1'))))
        if args.属性清单:
            print(shuxing_table())
        return 0
    doc = Path(args.设计仓库) / '重制设定' / '天启篇_全角色技能重构_v0.2.md'
    actors, unclear, rework = build_actors(doc)
    dev = backtest(actors, rework)
    bad = [(s, a, r) for s, a, r in dev if abs(r) > 0.1 + 1e-9]
    print('角色 %d；职责 %s；卡上没写清、填均衡的 %d 人 %s' % (
        len(actors), dict(collections.Counter(v['role'] for v in actors.values())), len(unclear), unclear))
    print('回验：%d 个带伤害的技能，偏差非零 %d 个，超 ±10%% %d 个' % (len(dev), sum(1 for x in dev if abs(x[2]) > 1e-9), len(bad)))
    for s, a, r in sorted(bad, key=lambda x: (x[1], x[0])):
        print('  技能 %s %s（%s·%s）偏差 %+.1f%%' % (s, rework['skills'][s]['name'], actors[str(a)]['name'], actors[str(a)]['role'], r * 100))
    items = gear_items()
    print('有等级需求和品质标记的装备（部位 1～10）：%d 件' % len(items))
    if args.清单:
        bands = [(1, 9), (10, 19), (20, 29), (30, 39), (40, 49), (50, 59), (60, 69), (70, 79), (80, 100)]
        cnt = collections.Counter()
        for _, slot, lv, g, _ in items:
            for lo, hi in bands:
                if lo <= lv <= hi:
                    cnt[(lo, slot, g)] += 1
        for lo, hi in bands:
            print('\n等级 %d～%d' % (lo, hi))
            print('| 部位 | ' + ' | '.join(GRADE_NAMES) + ' |')
            for slot in SLOTS:
                print('| %s | ' % slot + ' | '.join(str(cnt.get((lo, slot, g), 0)) for g in range(7)) + ' |')
    if args.写表:
        base_line = {
            '_note': '天启篇角色本体标准线（T080，基础数值重构 v0.3 第四节）。只读；开关关着时没有代码读它。line：攻击类六项＝A0＋A1×等级，生命＝×hp_mult，魔法＝×mp_mult；roles：职责对生命、物防魔防的系数（dmg_in_cards 只是说明：伤害系数已经写在技能卡里，不再乘）；speed：只管敏捷；tweak：个人微调（项 → ×0.8～1.2，要写理由）；actors：每人职责、速度档（唯一来源是技能重构 v0.2 每张角色卡的「X型」句和标题行；卡上没写清的填均衡、中，id 列在 unclear）；backtest_notes：回验偏差超 ±10% 的逐条理由。',
            'version': 1,
            'line': LINE,
            'roles': ROLES,
            'speed': SPEED,
            'tweak_range': [0.8, 1.2],
            'unclear': unclear,
            'role_rejudged': {str(i): r for i, (_, r) in sorted(ROLE_REJUDGE.items())},
            'actors': actors,
            'backtest_notes': [
                {'skill': int(s), 'actor': int(a), 'dev': round(r, 3), 'reason': BACKTEST_REASON}
                for s, a, r in sorted(bad, key=lambda x: (x[1], int(x[0])))],
        }
        (DATA / 'base_line.json').write_text(dumps(base_line), encoding='utf-8')
        gear_base = {
            '_note': '天启篇装备底子（T080，基础数值重构 v0.3 第五节）。只读；开关关着时没有代码读它。一件装备某一项的底子＝标准线(折算等级)×部位系数×品质系数，折算等级＝1＋装备等级×98÷90，标准线读 base_line.json。slots：部位系数（etype＝原装备类型号；主攻 atk、生命 hp、物防魔防 def 各自、敏捷 agi、幸运 luk）；grades：七档品质系数（键同 tianqi_affix_roll.gd 的 QUALITY_KEYS）；main_stat：主攻给物攻还是魔攻；ratio：换算比（词缀、强化加的固定属性 × 它，按装备等级 0～90 一张表，列 atk／hp／def／agi／luk＝标准线÷原版同等级弱者本体中位）；qiyin：七印装备、毕业武器、真印（80 级神话，武器和真印再 ×base_mult，也读这张表）；exceptions：不读这张表的装备。',
            'version': 1,
            'slots': SLOTS,
            'slot_totals_range': {'atk': [2.5, 3.0], 'hp': [3.0, 4.0], 'def': [2.5, 3.0], 'agi': [0.3, 0.3], 'luk': [0.3, 0.3]},
            'grades': GRADES,
            'grade_step_min': 0.2,
            'grade_max_over_min': 3.5,
            'main_stat': {'rule': '看原版那件装备物攻、魔攻哪个高，高的那项给主攻；一样高各给一半', 'tie': 'split'},
            'level_map': {'conv_level': '1 + 装备等级 * 98 / 90', 'equip_level_range': [0, 90]},
            'qiyin': {'level': 80, 'first_kill_level': 75, 'grade': 'shenhua', 'weapon_and_true_seal_mult': 1.1},
            'exceptions': {
                'etypes': [13, 16, 17],
                'note': '法宝（13）成长满时相当于半件同级装备，坐骑（16）只管敏捷百分比和先手，神器栏（17）是独特物件，都不读这张表；神器白名单见 core/tianqi_gear.gd 的 ARTIFACTS。其余等级、品质不落在表里的装备要 T012-b 开工时核（见交付单清单 1）',
                'ids': [],
            },
            'ratio': ratio_table(),
        }
        (DATA / 'gear_base.json').write_text(dumps(gear_base), encoding='utf-8')
        (DATA / 'abs_rescale.json').write_text(dumps(build_abs()), encoding='utf-8')
        print('已写 base_line.json、gear_base.json、abs_rescale.json')


if __name__ == '__main__':
    sys.exit(main() or 0)
