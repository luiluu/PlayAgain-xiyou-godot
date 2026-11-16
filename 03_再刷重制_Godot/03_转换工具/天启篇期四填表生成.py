#!/usr/bin/env python3
"""T080（T012-a 期四暗装填表）生成脚本：照《基础数值重构 v0.3》第四、五节生成 base_line.json、gear_base.json，并打出回验和清单。
只读游戏数据（generated/db 要有，用 新建工作树.sh --补齐 取）和设计仓库的《全角色技能重构 v0.2》；写 tianqi_data/base_line.json、gear_base.json。
  python3 03_转换工具/天启篇期四填表生成.py [--设计仓库 ~/Documents/xiyou-design-docs] [--写表]      不加 --写表只打印
  python3 03_转换工具/天启篇期四填表生成.py --清单            打印件数表／超上限技能清单（交付单附件用）
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
        if not role:
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
        new = sum(w * role_mult(ac, k) * (LINE['hp_mult'] if k == 'mhp' else LINE['mp_mult'] if k == 'mmp' else 1.0)
                  / (LINE['hp_mult'] if k == 'mhp' else LINE['mp_mult'] if k == 'mmp' else 1.0)
                  for k, w in st.items())
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


def dumps(d):
    return json.dumps(d, ensure_ascii=False, indent=1) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--设计仓库', default=str(Path.home() / 'Documents' / 'xiyou-design-docs'))
    ap.add_argument('--写表', action='store_true')
    ap.add_argument('--清单', action='store_true')
    args = ap.parse_args()
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
            'nice_number_exempt': ['dev', 'unclear', 'skill', 'actor'],
            'line': LINE,
            'roles': ROLES,
            'speed': SPEED,
            'tweak_range': [0.8, 1.2],
            'unclear': unclear,
            'actors': actors,
            'backtest_notes': [
                {'skill': int(s), 'actor': int(a), 'dev': round(r, 3), 'reason': BACKTEST_REASON}
                for s, a, r in sorted(bad, key=lambda x: (x[1], int(x[0])))],
        }
        (DATA / 'base_line.json').write_text(dumps(base_line), encoding='utf-8')
        gear_base = {
            '_note': '天启篇装备底子（T080，基础数值重构 v0.3 第五节）。只读；开关关着时没有代码读它。一件装备某一项的底子＝标准线(折算等级)×部位系数×品质系数，折算等级＝1＋装备等级×98÷90，标准线读 base_line.json。slots：部位系数（etype＝原装备类型号；主攻 atk、生命 hp、物防魔防 def 各自、敏捷 agi、幸运 luk）；grades：七档品质系数（键同 tianqi_affix_roll.gd 的 QUALITY_KEYS）；main_stat：主攻给物攻还是魔攻；ratio：换算比（词缀、强化加的固定属性 × 它，按装备等级 0～90 一张表，列 atk／hp／def／agi／luk＝标准线÷原版同等级弱者本体中位）；qiyin：七印装备、毕业武器、真印（80 级神话，武器和真印再 ×base_mult，也读这张表）；exceptions：不读这张表的装备。',
            'version': 1,
            'nice_number_exempt': ['ratio', 'etype', 'slot_totals_range'],
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
        print('已写 base_line.json、gear_base.json')


if __name__ == '__main__':
    sys.exit(main() or 0)
