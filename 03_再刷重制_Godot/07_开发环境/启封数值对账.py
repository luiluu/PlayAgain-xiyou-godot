#!/usr/bin/env python3
"""启封数值总对账（T520）：角色技能／装备底子／固定词条／随机词条／怪物各层／装备等级分布，按档找离群。只读游戏数据。

用法（仓库任意处）：
  python3 03_再刷重制_Godot/07_开发环境/启封数值对账.py                    只打印摘要
  python3 .../启封数值对账.py --write                                     重写报告 07_开发环境/启封数值对账报告.md
  python3 .../启封数值对账.py --json <文件>                                另把全部明细（每档中位数、每条离群）写成 JSON
  --diff 难度键（缺省 jianxian 艰险）：怪物生命按这一档的目标回合算

依赖：工程里有 generated/db、generated/maps（没有先 新建工作树.sh --补齐）。
离群口径：同一档内，值 > 中位数×2 或 < 中位数×0.5；档内不足 3 条的不判，只列。
各节口径（照搬游戏代码，改了代码要同步改这里；行号见报告「口径」节）：
  装备池     ＝ XTianqiGear.drop_pool（全部敌人掉落表里出现过的武器、防具，含 <Enemy Drops>）
               ∩ _reroll_ok（有名字、不是 <req_actors> 专属、防具在 13 栏且不是神器栏）− 低档稀有（XTianqiDrop.rare_gear）
               ＝ XTianqiDrop.pool 的通用池；七印装备、法宝、坐骑、神器另列
  分档       ＝ 等级段（req_level 每 10 级一段，同 gear_table.drop_reroll.level_band）× 七档品质（UnifiedQuality.itemGrades）
  装备底子   ＝ XTianqiGear.new_base：标准线(1＋等级×98÷90)×部位系数×品质系数（主攻按原版物攻魔攻高的给、一样高各半；副属性 sub_stat）
               ；不读表的（没 req_level 或没品质）照原版 params。比较值＝八项各除以本等级标准线后相加（「标准线份数」）
  固定词条   ＝ 原版必出词缀行（同一行几率合计 ≥100；整行都是混沌／神话档的天启篇跳过，XTianqiAffixRoll.skips_row）
               每行按 ids 取均值；八项固定值×换算比(等级, 夹到 80)÷本等级标准线 相加；特性条目另数
  随机词条   ＝ affix_table.json：每条词条四阶×三成色的值（XTianqiAffixTable.value 同算法）；同层同单位同阶同成色内比
  技能强度   ＝ 六维打分_实测数据.json（六维打分.py 的输入：输出 peak、生存挨打、面板敏捷）＋ six_dim.json actors 字母；按档位（弱者／强者／超强者）分档
  怪物       ＝ 1～33 层：守层者那场（XGuardianRework.TROOPS）＋本层名字直接带「N层」地图的遇敌表；
               生命＝原生命×hp_base(层)×目标回合÷本层守层者那场原总血×hp_pct÷100×enemy_hp_pct÷100（_world／_scale_hp／scale_enemy_mhp）
               出伤指数＝max(物攻,魔攻)×atk_scale(层)×难度敌人攻击；双防 31～33 层守层者按 guardian_params 重锚；其余照原数据
               35／36 层骑士读 horsemen.json（艰险）
"""
import argparse
import json
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GODOT = HERE.parent
X = GODOT / '01_Godot工程/modes/xiyou'
DB = X / 'generated/db'
MAPS = X / 'generated/maps'
TQ = X / 'tianqi_data'
MEAS = HERE / '六维打分_实测数据.json'
REPORT = HERE / '启封数值对账报告.md'

STATS = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk']
SN = {'mhp': '生命', 'mmp': '魔法', 'atk': '物攻', 'def': '物防', 'mat': '魔攻', 'mdf': '魔防', 'agi': '敏捷', 'luk': '幸运'}
SLOT_COLS = ['hp', '', 'atk', 'def', 'atk', 'def', 'agi', 'luk']
RATIO_COLS = ['hp', 'hp', 'atk', 'def', 'atk', 'def', 'agi', 'luk']
QKEYS = ['putong', 'youxiu', 'jingliang', 'shishi', 'chuanshuo', 'buxiu', 'shenhua']
GN = ['普通', '优秀', '精良', '史诗', '传说', '不朽', '神话']
ORDER = [1, 2, 3, 4, 6, 8, 5, 7, 9, 10, 13, 16, 17]
ETN = {1: '武器', 2: '副手', 3: '头部', 4: '盔甲', 5: '裤子', 6: '护手', 7: '鞋子', 8: '腰带', 9: '项链', 10: '戒指', 13: '法宝', 16: '坐骑', 17: '神器'}
CAP_LEVEL = 80
HI, LO = 2.0, 0.5


def load(p):
    with open(p, encoding='utf-8') as f:
        return json.load(f)


def med(v):
    return statistics.median(v) if v else 0.0


def fmt(x, nd=2):
    if x is None:
        return '—'
    if isinstance(x, (int,)) or (isinstance(x, float) and x.is_integer() and abs(x) >= 100):
        return f'{int(x):,}'
    if abs(x) >= 1000:
        return f'{x:,.0f}'
    return f'{x:.{nd}f}'.rstrip('0').rstrip('.') if '.' in f'{x:.{nd}f}' else f'{x:.{nd}f}'


# ---------------- 数据 ----------------
class Data:
    def __init__(self):
        self.W = load(DB / 'Weapons.json')
        self.A = load(DB / 'Armors.json')
        self.E = load(DB / 'Enemies.json')
        self.T = load(DB / 'Troops.json')
        self.MI = load(DB / 'MapInfos.json')
        self.UQ = load(DB / 'UnifiedQuality.json')
        self.gb = load(TQ / 'gear_base.json')
        self.bl = load(TQ / 'base_line.json')
        self.bt = load(TQ / 'balance_table.json')
        self.dt = load(TQ / 'drop_table.json')
        self.at = load(TQ / 'affix_table.json')
        self.gp = load(TQ / 'guardian_params.json')
        self.hm = load(TQ / 'horsemen.json')
        self.sd = load(TQ / 'six_dim.json')
        self.rw = load(TQ / 'skill_rework.json')
        self.rw_tiers = self.rw['tiers']
        self.S = load(DB / 'Skills.json')
        self.I = load(DB / 'Items.json')
        self.gbk = load(TQ / 'general_books.json')
        self.sbk = load(TQ / 'secret_books.json')
        self.brand = load(TQ / 'brand.json')
        self.st = load(TQ / 'suit_template.json')
        self.orbs = load(DB / 'CodexOrbs.json')
        self.races = load(DB / 'CodexRaces.json')
        self.ledger = load(TQ / 'damage_ledger.json')
        # 技能卡＋各轮调参（tune.*.skills 逐层盖上，同 XTianqiBase.TUNE_* 全开）
        self.cards = {k: dict(v) for k, v in self.rw['skills'].items()}
        for tk, tv in self.rw.get('tune', {}).items():
            for sid, patch in (tv.get('skills') or {}).items():
                if isinstance(patch, dict):
                    self.cards.setdefault(sid, {}).update({k: v for k, v in patch.items() if not k.startswith('_')})
        self.meas = load(MEAS)
        self.slots = {int(v['etype']): v for v in self.gb['slots'].values()}

    def rec(self, kind, i):
        t = self.W if kind == 2 else self.A
        return t[i] if 0 <= i < len(t) and t[i] else {}

    # 标准线（XTianqiBase.line）
    def line(self, conv, stat):
        l = self.bl['line']
        v = l['A0'] + l['A1'] * conv
        if stat == 'mhp':
            v *= l['hp_mult']
        elif stat == 'mmp':
            v *= l['mp_mult']
        return v

    def legacy_q(self, r):
        q = str(r.get('meta', {}).get('quality', '')).strip()
        try:
            return max(0, int(q))
        except ValueError:
            return 1

    def grade(self, r):
        q = self.legacy_q(r)
        g = self.UQ['itemGrades']
        return int(g[q]) if q < len(g) else (6 if q >= 12 else 0)

    def req(self, r, kind):
        t = str(r.get('meta', {}).get('req_level', '')).strip()
        if re.fullmatch(r'-?\d+', t):
            return int(t)
        ov = self.gb.get('level_override', {}).get('direct', {})
        k = '%s:%d' % ('weapon' if kind == 2 else 'armor', r.get('id', 0))
        return int(ov[k]) if k in ov else None


# ---------------- 装备池 ----------------
EXTRA_RE = re.compile(r'(?is)<Enemy Drops>(.*?)</Enemy Drops>')
EXTRA_LINE = re.compile(r'(?i)(Item|Weapon|Armor)\s+(\d+):\s*([\d.]+)%')
REQ_ACT = re.compile(r'(?i)<req_actors\s*:')


def drop_pool(D):
    seen, best = {}, defaultdict(float)
    for e in D.E:
        if not e:
            continue
        for d in e.get('dropItems', []):
            if d.get('kind') in (2, 3) and d.get('denominator', 0) > 0:
                k = (d['kind'], d['dataId'])
                seen[k] = True
                best[k] = max(best[k], 1.0 / d['denominator'])
        m = EXTRA_RE.search(e.get('note', ''))
        if m:
            for ln in m.group(1).split('\n'):
                lm = EXTRA_LINE.search(ln)
                if lm:
                    kind = {'item': 1, 'weapon': 2, 'armor': 3}[lm.group(1).lower()]
                    if kind in (2, 3):
                        k = (kind, int(lm.group(2)))
                        seen[k] = True
                        best[k] = max(best[k], float(lm.group(3)) / 100)
    return sorted(seen), best


def reroll_ok(kind, r):
    if not r or not r.get('name'):
        return False
    if REQ_ACT.search(r.get('note', '')):
        return False
    if kind == 2:
        return True
    et = r.get('etypeId', 0)
    return et in ORDER and et != 17


def gear_pool(D):
    keys, best = drop_pool(D)
    rare_below = D.dt['generic'].get('rare_below', 0.003)
    out, skipped = [], defaultdict(int)
    for kind, i in keys:
        r = D.rec(kind, i)
        if not reroll_ok(kind, r):
            skipped['专属／删除栏位／无名'] += 1
            continue
        g = D.grade(r)
        if g <= 2 and best[(kind, i)] < rare_below:
            skipped['低档稀有（照原表掉，不进通用池）'] += 1
            continue
        out.append((kind, i, r))
    return out, skipped


def applies(D, kind, r):
    et = r.get('etypeId', 1 if kind == 2 else 0)
    if kind == 2:
        et = r.get('etypeId', 1)
    if et not in D.slots or et in D.gb['exceptions']['etypes']:
        return False
    return D.req(r, kind) is not None and 'quality' in r.get('meta', {})


def new_base(D, kind, r, lv):
    lv = max(0, min(90, lv))
    conv = 1 + lv * 98 / 90
    grade = D.gb['grades'][QKEYS[max(0, min(6, D.grade(r)))]]
    slot = D.slots.get(r.get('etypeId', 0), {})
    p = r.get('params', [0] * 8)
    atk, mat = p[2], p[4]
    share = [1, 1, 1 if atk > mat else (0.5 if atk == mat else 0), 1, 1 if mat > atk else (0.5 if atk == mat else 0), 1, 1, 1]
    sub = D.gb['sub_stat']['ratio']
    kmain = max(slot.get(c, 0) for c in ['atk', 'hp', 'def', 'agi', 'luk'])
    out = []
    for i in range(8):
        col = SLOT_COLS[i]
        k = slot.get(col, 0) if col else 0
        v = D.line(conv, STATS[i]) * k * grade * share[i]
        if v == 0 and sub > 0 and p[i] != 0:
            v = D.line(conv, STATS[i]) * kmain * grade * sub * (1 if p[i] > 0 else -1)
        out.append(v)
    return out


def ratio(D, lv, i):
    lv = max(0, min(CAP_LEVEL, lv))
    return D.gb['ratio'].get(str(lv), {}).get(RATIO_COLS[i], 1.0)


def shares(D, vals, lv):
    conv = 1 + max(0, min(90, lv)) * 98 / 90
    return sum(v / D.line(conv, STATS[i]) for i, v in enumerate(vals))


def fixed_affix(D, kind, r, lv):
    """必出行：[(折算份数均值, 特性条目数均值, 行说明)]"""
    tab = D.W if kind == 2 else D.A
    rows = []
    for row in r.get('equipment', {}).get('affixes', []):
        ch = row.get('choices', [])
        if sum(int(c.get('chance', 0)) for c in ch) < 100:
            continue
        ids = [n for c in ch for n in c.get('ids', []) if 0 <= n < len(tab) and tab[n] and tab[n].get('name')]
        if not ids:
            continue
        if all(D.legacy_q(tab[n]) >= 14 for n in ids):
            continue  # 整行混沌／神话：天启篇跳过
        vals, trs, names = [], [], []
        for n in ids:
            a = tab[n]
            ap = a.get('params', [0] * 8)
            vals.append(shares(D, [ap[i] * ratio(D, lv, i) for i in range(8)], lv))
            trs.append(len(a.get('traits', [])))
            names.append(a.get('name', ''))
        rows.append((statistics.mean(vals), statistics.mean(trs), '/'.join(sorted(set(names)))[:24]))
    return rows


def band(lv):
    return (lv // 10) * 10 if lv is not None else -1


def band_name(b):
    return '无等级' if b < 0 else f'{b}～{b + 9}'


# ---------------- 离群 ----------------
def outliers(groups, label, unit=''):
    """groups: {档名: [(名字, 值, 额外)]} → (每档中位表, 离群列表)"""
    meds, outs, small = {}, [], []
    for g, rows in groups.items():
        vals = [v for _, v, _ in rows if v is not None]
        m = med(vals)
        meds[g] = (len(vals), m, min(vals) if vals else None, max(vals) if vals else None)
        if len(vals) < 3:
            small.append(g)
            continue
        for name, v, ex in rows:
            if v is None:
                continue
            if m == 0:
                if v != 0:
                    outs.append({'类': label, '名': name, '档': g, '值': v, '中位数': 0, '倍数': None, '备注': '中位为 0；' + ex})
                continue
            k = v / m
            if k > HI or k < LO:
                outs.append({'类': label, '名': name, '档': g, '值': v, '中位数': m, '倍数': k, '备注': ex})
    return meds, outs, small


def sev(o):
    k = o['倍数']
    if k is None:
        return 0
    if k <= 0:
        return 99
    return max(k, 1 / k)


# ---------------- 各节 ----------------
def sec_gear(D):
    pool, skipped = gear_pool(D)
    lv_cap = max(r[1] for r in D.dt['generic']['level_by_floor'])
    top = D.dt['generic']['top_grade']
    base_g, aff_g, dist = defaultdict(list), defaultdict(list), defaultdict(int)
    noformula, unreach = [], []
    aff_count = defaultdict(lambda: [0, 0])
    for kind, i, r in pool:
        lv = D.req(r, kind)
        g = D.grade(r)
        et = r.get('etypeId', 1)
        b = band(lv)
        dist[(b, g)] += 1
        nm = f"{r['name']}（{'武' if kind == 2 else '防'}{i}·{ETN.get(et, et)}）"
        if lv is None or lv > lv_cap or g > top:
            unreach.append(nm)
        key = f'{band_name(b)}·{GN[g]}'
        if applies(D, kind, r):
            vals = new_base(D, kind, r, lv)
            v = shares(D, vals, lv)
            base_g[key + '·' + ETN.get(et, str(et))].append((nm, v, ''))
        else:
            p = r.get('params', [0] * 8)
            lvv = lv if lv is not None else 0
            v = shares(D, p, lvv)
            noformula.append((nm, key, v, p))
        rows = fixed_affix(D, kind, r, lv if lv is not None else 0)
        fv = sum(x[0] for x in rows)
        ft = sum(x[1] for x in rows)
        aff_count[key][0] += 1
        if rows:
            aff_count[key][1] += 1
        aff_g[key].append((nm, fv, f"{len(rows)} 行必出、特性约 {ft:.1f} 条：" + '；'.join(x[2] for x in rows)))
    return pool, skipped, base_g, aff_g, dist, noformula, unreach, aff_count, lv_cap


def affix_val(D, a, tier, gi):
    ts = next((l['tier_start'] for l in D.at['layers'] if l['key'] == a['layer']), 0)
    vals = a.get('values', [])
    if a.get('fixed'):
        return vals[0] if vals else None
    if ts <= 0 or tier < ts:
        return None
    i = tier - ts + gi
    return vals[i] if i < len(vals) else None


def sec_affix(D):
    groups = defaultdict(list)
    steps = []
    for a in D.at['affixes']:
        unit = a.get('unit', '')
        for tier in range(1, 5):
            for gi, gn in enumerate(['普通', '上品', '极']):
                v = affix_val(D, a, tier, gi)
                if v is None:
                    continue
                groups[f"{a['layer']}·{unit}·{tier}阶·{gn}"].append((f"{a['name']}（{a['key']}）", float(v), a.get('effect', '')))
        # 阶间跳幅（普通成色）
        seq = [affix_val(D, a, t, 0) for t in range(1, 5)]
        seq = [s for s in seq if s is not None]
        for x, y in zip(seq, seq[1:]):
            if x and y and (y / x > HI or y / x < LO):
                steps.append((f"{a['name']}（{a['key']}）", a['layer'], unit, seq))
                break
    return groups, steps


CLS_CN = {'super': '超强者', 'strong': '强者', 'weak': '弱者'}


def actor_tiers(D):
    """角色号 → 档位（six_dim.json actors 的 class；停用角色不在表里）"""
    return {aid: CLS_CN.get(a.get('class'), a.get('class')) for aid, a in D.sd['actors'].items()}


def sec_skill(D):
    ms = D.meas['actors']
    tier_of = actor_tiers(D)
    sc = D.sd['scale']
    groups = {'输出峰值': defaultdict(list), '生存（撑过回合）': defaultdict(list), '速度（面板敏捷）': defaultdict(list), '六维总分': defaultdict(list)}
    for aid, a in D.sd['actors'].items():
        t = tier_of.get(aid)
        if not t:
            continue
        nm = f"{a.get('name', aid)}（{aid}）"
        m = ms.get(aid, {})
        groups['六维总分'][t].append((nm, float(sum(sc[a[d]] for d in D.sd['dims'] if d in a)), ''.join(a.get(d, '?') + ' ' for d in D.sd['dims']).strip()))
        if m.get('peak'):
            groups['输出峰值'][t].append((nm, float(m['peak']), f"招 {m.get('skill')}，{m.get('segs')} 段"))
        sv = m.get('surv', {})
        turns = sv.get('turns') if isinstance(sv, dict) else None
        if turns is None and isinstance(sv, dict):
            for k in ('turns_med', 'med', 'survived'):
                if k in sv:
                    turns = sv[k]
                    break
        if turns is not None:
            groups['生存（撑过回合）'][t].append((nm, float(turns), ''))
        st = m.get('stat', {})
        if st.get('agi'):
            groups['速度（面板敏捷）'][t].append((nm, float(st['agi']), ''))
    return groups, tier_of


def map_floor_direct(name):
    CN = '一二三四五六七八九十'
    m = re.search(r'(\d+)\s*层', name)
    if m:
        return int(m.group(1))
    m = re.search(r'([一二三四五六七八九十]+)层', name)
    if not m:
        return 0
    s = m.group(1)
    if s == '十':
        return 10
    if '十' in s:
        a, b = s.split('十')
        return (CN.index(a) + 1 if a else 1) * 10 + (CN.index(b) + 1 if b else 0)
    return CN.index(s) + 1


GUARD_TROOPS = {1: 4, 2: 5, 3: 8, 4: 22, 5: 28, 6: 39, 7: 52, 8: 53, 9: 67, 10: 69, 11: 109, 12: 110, 13: 111, 14: 118, 15: 138,
                16: 172, 17: 173, 18: 174, 19: 333, 20: 456, 21: 457, 22: 458, 23: 459, 24: 460, 25: 461, 26: 462, 27: 463, 28: 464, 29: 465,
                30: 466, 31: 467, 32: 468, 33: 469}  # 同 core/guardian_rework.gd TROOPS


def sec_enemy(D, diff):
    turns = {'xunchang': 6, 'jianxian': 8, 'jiusi': 10, 'lianyu': 12, 'zhengdao': 15}[diff]
    dif = next(d for d in D.bt['difficulties'] if d['key'] == diff)['scaling']
    g4 = D.bt['guardian_phase4']
    hp_pct_all = D.bt['combat_rules']['enemy_hp_pct']
    ref = D.E[D.gp['ref_enemy']]['params']
    floors = defaultdict(dict)  # f → {enemyId: 来源}
    maps_used = defaultdict(list)
    for m in D.MI:
        if not m:
            continue
        f = map_floor_direct(m.get('name', ''))
        if not 1 <= f <= 33:
            continue
        p = MAPS / ('Map%03d.json' % m['id'])
        if not p.exists():
            continue
        enc = load(p).get('encounterList', [])
        if enc:
            maps_used[f].append(m['name'])
        for x in enc:
            tr = D.T[x['troopId']] if x['troopId'] < len(D.T) else None
            for mem in (tr or {}).get('members', []):
                floors[f].setdefault(mem['enemyId'], '遇敌')
    for f, t in GUARD_TROOPS.items():
        for mem in D.T[t].get('members', []):
            floors[f][mem['enemyId']] = '守层者那场'
    rows = defaultdict(list)
    curve = []
    for f in range(1, 34):
        old_total = sum(D.E[m['enemyId']]['params'][0] for m in D.T[GUARD_TROOPS[f]]['members'])
        hb = float(g4['hp_base'].get(str(f), 0))
        hpp = int(g4.get('hp_pct', {}).get(str(f), 100))
        k = hb * turns / old_total if old_total else 0
        atk_s = float(g4['atk_scale'].get(str(f), 1.0))
        fl = []
        for eid, src in floors[f].items():
            e = D.E[eid]
            if not e or not e.get('name'):
                continue
            p = list(e['params'])
            hp = p[0] * k * (hpp / 100 if src == '守层者那场' else 1) * hp_pct_all / 100
            dfn, mdf = p[3], p[5]
            if src == '守层者那场' and str(f) in D.gp['floors']:
                ov = D.gp['floors'][str(f)]
                dfn = ref[3] * ov.get('def', 100) / 100 if 'def' in ov else dfn
                mdf = ref[5] * ov.get('mdf', 100) / 100 if 'mdf' in ov else mdf
            out = max(p[2], p[4]) * atk_s * dif['enemy_atk']
            r = {'层': f, '号': eid, '名': e['name'], '来源': src, '生命': hp, '出伤指数': out, '物攻': p[2], '魔攻': p[4], '物防': dfn, '魔防': mdf, '敏捷': p[6]}
            fl.append(r)
            rows[f].append(r)
        if fl:
            curve.append({'层': f, '只数': len(fl), **{k2: med([x[k2] for x in fl]) for k2 in ['生命', '出伤指数', '物防', '魔防', '敏捷']},
                          'hp_base': hb, 'atk_scale': atk_s})
    knights = []
    for key, kn in D.hm['knights'].items():
        knights.append({'名': kn['name'], '生命': kn.get('hp'), '攻击': kn.get('atk'), '魔攻': kn.get('mat'), '防御': kn.get('def')})
    sh = D.hm.get('shadow', {})
    return rows, curve, knights, sh, maps_used, turns


# ---------------- 逐招技能系数 ----------------
CN_NUM = {'一': 1, '两': 2, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10}


def cn_int(s):
    if s.isdigit():
        return int(s)
    if s in CN_NUM:
        return CN_NUM[s]
    if s.startswith('十'):
        return 10 + CN_NUM.get(s[1:], 0)
    if '十' in s:
        a, b = s.split('十')
        return CN_NUM.get(a, 1) * 10 + CN_NUM.get(b, 0)
    return None


SEG_RE = re.compile(r'([0-9一两二三四五六七八九十]+)\s*段')
RAND_RE = re.compile(r'随机([0-9一两二三四五六七八九十]+)\s*(?:个|名)')


def segs_of(D, sid, c):
    desc = ' '.join(c.get('desc', []))
    for rx in (SEG_RE, RAND_RE):
        m = rx.search(desc)
        if m:
            n = cn_int(m.group(1))
            if n:
                return n, '说明'
    for o in c.get('seq') or []:
        if isinstance(o, dict) and o.get('op') == 'split_effects':
            return int(o.get('n', 1)), '拆段'
    i = int(sid)
    r = D.S[i] if i < len(D.S) and D.S[i] else {}
    rep = int(r.get('repeats', 1) or 1)
    sc = int(r.get('scope', 1) or 1)
    rnd = sc - 2 if 3 <= sc <= 6 else 1
    return max(1, rep * rnd), '原版'


def cond_max(dmg):
    m = 1.0
    for c in dmg.get('conds', []) or []:
        v = c.get('mult')
        if isinstance(v, (int, float)) and v > 1:
            m *= v
    return m


def sec_skillcoef(D):
    """逐招：系数×段数÷每几回合一次（冷却＋1，没冷却按 1）＝每回合期望倍率（单目标口径）"""
    tier_of = actor_tiers(D)
    rows = []
    for sid, c in D.cards.items():
        dmg = c.get('damage')
        if not isinstance(dmg, dict) or 'coef' not in dmg or not c.get('actor'):
            continue
        aid = str(c['actor'])
        t = tier_of.get(aid)
        if not t:
            continue
        coef = float(dmg['coef'])
        if coef <= 0:
            continue
        n, how = segs_of(D, sid, c)
        cd = int(c.get('cooldown', 0) or 0)
        per = coef * n / (cd + 1 if cd > 0 else 1)
        kind = c.get('kind') or '?'
        tgt = '全体' if '全体' in kind else ('随机' if '随机' in kind else '单体')
        stats = '+'.join(f'{k}×{v:g}' for k, v in dmg.get('stats', {}).items())
        cost = ('MP%d%%' % c['mp_pct']) if c.get('mp_pct') else (('TP%d' % c['tp']) if c.get('tp') else (('MP%d' % c['mp']) if c.get('mp') else ''))
        aname = D.sd['actors'][aid].get('name', aid)
        rows.append({'招': f"{c.get('name', sid)}（{sid}）", '角色': f'{aname}（{aid}）', '档位': t, '类别': kind, '目标': tgt, '系数': coef,
                     '段数': n, '段数来源': how, '冷却': cd, '消耗': cost, '属性': stats, '条件最高': cond_max(dmg), '每回合期望': per})
    for sid, c in D.gbk['skills'].items():
        dmg = c.get('damage')
        if not isinstance(dmg, dict) or 'coef' not in dmg:
            continue
        coef = float(dmg['coef'])
        n = int(c.get('repeats', 0) or 0) or segs_of(D, sid, c)[0]
        cd = int(c.get('cooldown', 0) or 0)
        rows.append({'招': f"{c.get('name', sid)}（{sid}）", '角色': '通用书', '档位': '通用书', '类别': '书·主动', '目标': '—', '系数': coef,
                     '段数': n, '段数来源': '书', '冷却': cd, '消耗': '', '属性': '+'.join(f'{k}×{v:g}' for k, v in dmg.get('stats', {}).items()),
                     '条件最高': cond_max(dmg), '每回合期望': coef * n / (cd + 1 if cd > 0 else 1)})
    groups = defaultdict(list)
    for r in rows:
        groups[f"{r['档位']}·{r['类别']}"].append((f"{r['招']}·{r['角色']}", r['每回合期望'], f"系数{r['系数']:g}×{r['段数']}段（{r['段数来源']}）÷{r['冷却'] + 1 if r['冷却'] else 1}回合；{r['属性']}"))
    return rows, groups



# ---------------- 技能全系数（招里所有数值，按同类字段分组） ----------------
SKIP_KEYS = {'actor', 'dataId', 'code', 'state', 'states', 'skills', 'need_skill', 'from', 'element', 'elements', 'self_states', 'kill_grow',
             'header', 'desc', 'name', 'kind', 'note_remove', 'note_add', 'note_sub', 'effects_remove', 'variants', 'id', 'skill', 'n_id', 'icon'}
EFF_NAME = {11: '回复生命', 12: '回复魔法', 13: '回复TP', 21: '加状态几率', 22: '解状态', 31: '加强化', 32: '加弱化', 44: '公共事件'}


def leaves(x, path=''):
    if isinstance(x, dict):
        code = x.get('code')
        for k, v in x.items():
            if k in SKIP_KEYS or k.startswith('_'):
                continue
            seg = k
            if code is not None and k.startswith('value'):
                seg = f"{EFF_NAME.get(code, '效果%s' % code)}.{k}"
            elif k == 'if' or k == 'op':
                continue
            yield from leaves(v, f'{path}.{seg}' if path else seg)
        if 'if' in x and isinstance(x.get('if'), str):
            for k, v in x.items():
                if isinstance(v, (int, float)) and not isinstance(v, bool) and k not in ('mult',):
                    yield (f"{path}.条件[{x['if']}].{k}", float(v))
    elif isinstance(x, list):
        for v in x:
            yield from leaves(v, path)
    elif isinstance(x, (int, float)) and not isinstance(x, bool):
        yield (path, float(x))


def sec_allcoef(D):
    tier_of = actor_tiers(D)
    groups = defaultdict(list)
    n_fields = 0
    for sid, c in D.cards.items():
        aid = str(c.get('actor', ''))
        if aid not in tier_of:
            continue
        nm = f"{c.get('name', sid)}（{sid}）·{D.sd['actors'][aid].get('name', aid)}"
        for path, v in leaves({k: v for k, v in c.items() if k not in ('damage',)} | ({'damage': {k: v for k, v in c['damage'].items() if k != 'coef'}} if isinstance(c.get('damage'), dict) else {})):
            if v == 0 or '.条件[' in path and path.endswith('.mult'):
                continue
            groups[path].append((nm, v, tier_of[aid]))
            n_fields += 1
    for sid, st in D.rw.get('states', {}).items():
        for path, v in leaves({k: v for k, v in st.items() if k in ('turns', 'traits', 'hit_extra_pct', 'reflect', 'revive', 'dot_remove')}):
            if v == 0:
                continue
            groups['状态.' + path].append((f"{st.get('name', sid)}（状态{sid}）", v, '状态'))
            n_fields += 1
    return groups, n_fields


# ---------------- 跨来源同属性 ----------------
# 属性键 → (乘区, 叠法)；口径照 core/power.gd _notes 与 damage_ledger.json pools／nine_caps
ATTR = {
    '③伤害加成%': ('③ 伤害加成池', '池内相加，池间相乘'),
    '①技能伤%': ('① 技能池', '池内相加，池间相乘'),
    '②元素伤%(单系)': ('② 元素池（每系）', '池内相加，池间相乘'),
    '④暴伤%': ('④ 暴击（暴伤）', '池内相加'),
    '④暴击率%': ('④ 暴击（暴击率）', '概率相加'),
    '攻击%': ('能力值倍率（物攻／魔攻取大）', '特性 21 连乘；被动 PBST％ 相加（拿不准）'),
    '生命%': ('能力值倍率（生命）', '同上'),
    '穿透%': ('靶（机制：百分比穿透）', '相加'),
    '再行动%': ('回合预算（每人每回合最多多 1 次）', '取概率'),
    '承伤%': ('承伤（特性 23 物理／魔法承伤）', '连乘'),
}
TAG_RE = re.compile(r'<\s*(passiveHarmRi|passiveCrHarmRi|passiveELUP(\d+)|SkETypeHarmRi(\d+)|SkillPass(\d+)|passiveAPLUS|DepassiveHarmRe(\d+)|SkillCriPush(?:All|Mf|Zj))\s*:\s*([+-]?\d+(?:\.\d+)?)\s*(%?)\s*>', re.I)
EA_RE = re.compile(r'<\s*Element Amplify (\d+)\s*:\s*([+-]?[\d.]+)%\s*>', re.I)
PB_RE = re.compile(r'<\s*passivePBST([0-7])\s*:\s*([+-]?\d+(?:\.\d+)?)(%?)\s*>', re.I)
XPB_RE = re.compile(r'<\s*passiveXPBST([0-9])\s*:\s*([+-]?\d+(?:\.\d+)?)%?\s*>', re.I)


def note_edit(note, rec):
    for tag in rec.get('note_remove', []) or []:
        note = re.sub(r'<\s*(?:%s)\s*(?::[^>]*)?>' % tag, '', note)
    for pair in rec.get('note_sub', []) or []:
        try:
            note = re.sub('(?s)' + pair[0], pair[1].replace('$', '\\'), note)
        except re.error:
            pass
    return note + (rec.get('note_add', '') or '')


def scan(note, traits=()):
    """一个对象（技能／装备／书）给的各属性量（同一对象里相加；元素按系分开，最后取最高一系）"""
    out = defaultdict(float)
    elem = defaultdict(float)
    sp = defaultdict(float)
    for m in TAG_RE.finditer(note):
        key = m.group(1).lower()
        v = float(m.group(6))
        if key == 'passiveharmri':
            out['③伤害加成%'] += v
        elif key == 'passivecrharmri':
            out['④暴伤%'] += v
        elif key.startswith('passiveelup'):
            e = int(m.group(2))
            if e != 10:
                elem[e] += v
        elif key.startswith('sketypeharmri'):
            out['①技能伤%'] = max(out['①技能伤%'], v)
        elif key.startswith('skillpass'):
            sp[m.group(4)] += v
        elif key == 'passiveaplus':
            out['再行动%'] += v
        elif key.startswith('depassiveharmre') and m.group(7):
            out['穿透%'] = max(out['穿透%'], v)
        elif key.startswith('skillcripush'):
            out['④暴击率%'] += v
    for m in EA_RE.finditer(note):
        if int(m.group(1)) != 10:
            elem[int(m.group(1))] += float(m.group(2))
    for m in PB_RE.finditer(note):
        if m.group(3):
            i = int(m.group(1))
            if i in (2, 4):
                out['攻击%'] = max(out['攻击%'], float(m.group(2)))
            elif i == 0:
                out['生命%'] += float(m.group(2))
    for m in XPB_RE.finditer(note):
        if m.group(1) == '2':
            out['④暴击率%'] += float(m.group(2))
    for t in traits:
        c, d, v = t.get('code'), t.get('dataId'), float(t.get('value', 0))
        if c == 21 and d in (2, 4):
            out['攻击%'] = max(out['攻击%'], (v - 1) * 100)
        elif c == 21 and d == 0:
            out['生命%'] += (v - 1) * 100
        elif c == 22 and d == 2:
            out['④暴击率%'] += v * 100
        elif c == 23 and d == 6:
            out['承伤%'] += (v - 1) * 100
    if sp:
        out['①技能伤%'] = max(out['①技能伤%'], max(sp.values()))
    if elem:
        out['②元素伤%(单系)'] = max(elem.values())
    return {k: v for k, v in out.items() if v}


def card_note(D, sid):
    i = int(sid)
    r = D.S[i] if i < len(D.S) and D.S[i] else {}
    c = D.cards.get(str(sid), {})
    return note_edit(r.get('note', ''), c)


def gear_eff(D, kind, r):
    key = '%s:%d' % ('weapon' if kind == 2 else 'armor', r.get('id', 0))
    g = D.rw.get('gear', {}).get(key, {})
    note = note_edit(r.get('note', ''), g)
    traits = list(r.get('traits', []))
    for cd in g.get('traits_remove', []) or []:
        traits = [t for t in traits if not (t.get('code') == cd[0] and (len(cd) < 2 or t.get('dataId') == cd[1]))]
    traits += g.get('traits_set', []) or []
    return scan(note, traits)


def sec_cross(D, pool, tier_of):
    src = {}   # 来源 → {属性: (上限, 常见值, 上限是谁, 说明)}

    def put(name, attr, top, common, who, how=''):
        src.setdefault(name, {})[attr] = (top, common, who, how)

    # 1. 角色：每人卡里全部技能（含被动、心法）的标签相加 → 每属性取最强那人；常见值＝有这项的人的中位数
    per_actor = defaultdict(lambda: defaultdict(float))
    for sid, c in D.cards.items():
        aid = str(c.get('actor', ''))
        if aid not in tier_of:
            continue
        for k, v in scan(card_note(D, sid)).items():
            per_actor[aid][k] = max(per_actor[aid][k], v) if k in ('②元素伤%(单系)', '①技能伤%', '攻击%') else per_actor[aid][k] + v
    for attr in ATTR:
        vals = [(v[attr], aid) for aid, v in per_actor.items() if v.get(attr)]
        if vals:
            top = max(vals)
            put('角色技能／被动／心法（角色桶，不封顶）', attr, top[0], med([x for x, _ in vals]),
                f"{D.sd['actors'][top[1]].get('name')}（{top[1]}·{tier_of[top[1]]}）", f'{len(vals)} 人有')
    # 2. 装备本体（原版备注＋特性，卡改写过的按卡）：单件最高、整身＝各栏位单件最高相加
    by_slot = defaultdict(lambda: defaultdict(list))
    lv_cap = max(x[1] for x in D.dt['generic']['level_by_floor'])
    top_g = D.dt['generic']['top_grade']
    for kind, i, r in pool:
        lv = D.req(r, kind)
        if lv is None or lv > lv_cap or D.grade(r) > top_g:
            continue  # 启封 1～30 层通用掉落掉不出的不算
        et = r.get('etypeId', 1)
        for k, v in gear_eff(D, kind, r).items():
            by_slot[k][et].append((v, r['name']))
    body = {}
    for attr, slots in by_slot.items():
        one = max(max(x) for x in slots.values())
        body[attr] = sum(max(x)[0] for x in slots.values())
        put('装备本体（单件最高）', attr, one[0], med([v for x in slots.values() for v, _ in x]), one[1], f'{sum(len(x) for x in slots.values())} 件有')
        put('装备本体（整身：各栏单件最高相加）', attr, body[attr], None, f'{len(slots)} 栏', '九线封顶前')
    # 3. 随机词条（affix_table，四阶·极）
    pool_attr = {'final_damage': '③伤害加成%', 'skill_damage': '①技能伤%', 'element_damage': '②元素伤%(单系)', 'crit_multiplier': '④暴伤%',
                 'damage_taken': '承伤%'}
    n_slots = {'base': 10, 'special': 10, 'legendary': 10}
    for a in D.at['affixes']:
        attr = pool_attr.get(a.get('pool'))
        if a.get('pool') == 'stat' and a.get('stat') in ('atk', 'mat'):
            attr = '攻击%'
        elif a.get('pool') == 'stat' and a.get('stat') == 'mhp':
            attr = '生命%'
        elif a.get('pool') == 'xparam' and a.get('stat') == 'cri':
            attr = '④暴击率%'
        if not attr:
            continue
        v = affix_val(D, a, 4, 2) or affix_val(D, a, 4, 0)
        if v is None:
            continue
        v = float(v) * (-1 if attr == '承伤%' and v > 0 else 1)
        stack = a.get('stack', 'sum')
        whole = v * n_slots.get(a['layer'], 1) if stack == 'sum' else v
        cur = src.get('随机词条（单条，四阶·极）', {}).get(attr)
        if not cur or abs(v) > abs(cur[0]):
            put('随机词条（单条，四阶·极）', attr, v, affix_val(D, a, 2, 0), f"{a['name']}（{a['key']}·{a['layer']}）", a.get('unit', ''))
            put('随机词条（整身：同条每件一条×10 件）', attr, whole, None, f"{a['name']}（{stack}）", '按 sum 叠法、10 件都掷到同一条的理论上限')
    # 4. 套装模板（最高件数档、四阶）
    tv = D.st['values']
    top_suit = max(v[-1] for v in tv.values())
    kmap = {'final_damage': '③伤害加成%', 'element_damage': '②元素伤%(单系)', 'mhp': '生命%', 'damage_reduction': '承伤%'}
    for k, kd in D.st['kinds'].items():
        attr = kmap.get(kd.get('affix'))
        if attr:
            put('套装模板（5 件档·四阶）', attr, -top_suit if attr == '承伤%' else top_suit, tv['2'][-1], kd['name'], 'suit_template.json')
    # 5. 宝珠（最高阶「归真」，全身同类最高算 3 颗）
    for fam in D.orbs['families']:
        oid = fam['ids'][-1]
        it = D.I[oid] if oid < len(D.I) and D.I[oid] else {}
        note = it.get('note', '')
        for m in re.finditer(r'Element Amplify (\d+):\s*\+?([\d.]+)%', note):
            if int(m.group(1)) != 10:
                cur = src.get('宝珠（单颗归真）', {}).get('②元素伤%(单系)')
                v = float(m.group(2))
                if not cur or v > cur[0]:
                    put('宝珠（单颗归真）', '②元素伤%(单系)', v, None, it.get('name', ''), '')
                    put('宝珠（同类 3 颗）', '②元素伤%(单系)', v * 3, None, fam['name'], '「全身同类只算最高 3 颗」')
        for m in re.finditer(r'\b(ATK|MAT|MHP|CRI)\s*:\s*\+?([\d.]+)%', note):
            attr = {'ATK': '攻击%', 'MAT': '攻击%', 'MHP': '生命%', 'CRI': '④暴击率%'}[m.group(1)]
            v = float(m.group(2))
            cur = src.get('宝珠（单颗归真）', {}).get(attr)
            if not cur or v > cur[0]:
                put('宝珠（单颗归真）', attr, v, None, it.get('name', ''), '')
                put('宝珠（同类 3 颗）', attr, v * 3, None, fam['name'], '')
    # 6. 种族祝福（最高阶）
    put('种族祝福（最高阶）', '③伤害加成%', max(D.races['rates']) * 100, D.races['rates'][2] * 100, '七阶', 'damage_ledger：＋q 进③')
    # 7. 秘籍格、通用书（每本）
    sb = [s for s in D.sbk['skills'].values() if not s.get('banned')]
    if sb:
        top = max(sb, key=lambda s: s.get('damage_pct', 0))
        put('秘籍功法（每本）', '③伤害加成%', top['damage_pct'], med([s['damage_pct'] for s in sb if s.get('damage_pct')]), top['name'], 'D274 单本 5～15%；格数 弱6／强4／超3＋难度')
    gb = defaultdict(list)
    for sid, c in D.gbk['skills'].items():
        i = int(sid)
        r = D.S[i] if i < len(D.S) and D.S[i] else {}
        for k, v in scan(note_edit(r.get('note', ''), c)).items():
            gb[k].append((v, c.get('name', sid)))
    for k, vals in gb.items():
        t = max(vals)
        put('通用书（每本）', k, t[0], med([v for v, _ in vals]), t[1], f'{len(vals)} 本有')
    # 8. 法宝（通用＋专属，备注标签）
    fb = defaultdict(list)
    affix_ids = set()
    for tab in (D.W, D.A):
        for r in tab:
            for row in (r or {}).get('equipment', {}).get('affixes', []):
                for c in row.get('choices', []):
                    affix_ids.update(c.get('ids', []))
    for kind, tab in ((2, D.W), (3, D.A)):
        for r in tab:
            if r and r.get('id') not in affix_ids and r.get('etypeId') == 13 and r.get('name') and 'Magic Weapon' in r.get('note', ''):
                for k, v in gear_eff(D, kind, r).items():
                    fb[k].append((v, r['name']))
    for k, vals in fb.items():
        t = max(vals)
        put('法宝（单件，备注标签）', k, t[0], med([v for v, _ in vals]), t[1], f'{len(vals)} 件有')
    # 9. 天启篇自己的：档位⑤、烙印、境、常驻规则
    tiers = D.bt['tiers']
    put('档位池⑤（超强者）', '⑤档位', tiers['超强者']['damage_dealt'] * 100, tiers['强者']['damage_dealt'] * 100, '超强者', '⑤ 单独一池；强者 +50、弱者 0；弱者协力每人 +3')
    put('烙印（配满）', '烙印', D.brand['power']['max_bonus'] * 100, None, '烙印 100', '单独相乘、每人各自')
    hp_real = sum(b['params'].get('mhp', 0) for b in D.brand['realm']['base'])
    put('境底（七境累加）', '生命%', hp_real, None, '守一～逆命', 'brand.json realm.base')
    tr = D.brand.get('trade', {}).get('branches', [])
    if tr:
        put('境支·换伤（四支全选）', '③伤害加成%', sum(b['damage'] for b in tr) * 100, None, '锋骨／化刃／劫火／开印', '乘区拿不准（trade.damage）')
    put('天启篇常驻规则', '④暴击率%', D.bt['combat_rules']['crit_add'] * 100, None, 'combat_rules.crit_add', '全员')
    caps = D.ledger['nine_caps']
    nine = {'③伤害加成%': caps['bonus'] * 100, '①技能伤%': caps['skill'] * 100, '②元素伤%(单系)': caps['element'] * 100, '攻击%': caps['param'] * 100, '生命%': caps['param'] * 100}
    return src, nine, body, per_actor


def cross_judge(src, nine):
    """每个属性：各来源上限、份额；压过装备＝单来源上限 > 其余来源上限合计，或 > 装备整身（九线封顶后）"""
    attrs = sorted({a for s in src.values() for a in s}, key=lambda a: list(ATTR).index(a) if a in ATTR else 99)
    table, flags = {}, []
    gear_srcs = ('装备本体（整身：各栏单件最高相加）', '随机词条（整身：同条每件一条×10 件）', '套装模板（5 件档·四阶）', '宝珠（同类 3 颗）')
    skip_sum = ('装备本体（单件最高）', '随机词条（单条，四阶·极）', '宝珠（单颗归真）')
    for a in attrs:
        rows = [(n, s[a]) for n, s in src.items() if a in s]
        gear_raw = sum(abs(s[a][0]) for n, s in src.items() if a in s and n in gear_srcs)
        gear = min(gear_raw, nine[a]) if a in nine and gear_raw else gear_raw
        tot = sum(abs(v[0]) for n, v in rows if n not in skip_sum)
        out = []
        for n, v in rows:
            top = abs(v[0])
            share = top / tot if tot and n not in skip_sum else None
            others = tot - top if n not in skip_sum else None
            mark = []
            if n not in gear_srcs and n not in skip_sum:
                if others is not None and top > others and len(rows) > 1:
                    mark.append('超过其余合计')
                if gear and top > gear:
                    mark.append('压过装备')
            out.append((n, v, share, mark))
            if mark:
                flags.append({'属性': a, '来源': n, '上限': v[0], '谁': v[2], '装备整身': gear, '装备整身未封': gear_raw, '其余合计': others, '标记': '、'.join(mark)})
        table[a] = (out, gear, gear_raw)
    return table, flags


def sec_cross_extra(D, src, nine):
    return cross_judge(src, nine)


# ---------------- 报告 ----------------
def build(D, diff):
    L = []
    allouts = []
    # 装备
    pool, skipped, base_g, aff_g, dist, noformula, unreach, aff_count, lv_cap = sec_gear(D)
    bm, bo, bs = outliers(base_g, '装备底子')
    am, ao, as_ = outliers(aff_g, '固定词条')
    # 随机词条
    rg, steps = sec_affix(D)
    rm, ro, rs = outliers(rg, '随机词条')
    # 技能
    sg, tier_of = sec_skill(D)
    skill_res = {k: outliers(v, '技能·' + k) for k, v in sg.items()}
    # 怪物
    erows, curve, knights, shadow, maps_used, turns = sec_enemy(D, diff)
    egroups = {k: {f'{f}层': [(f"{r['名']}（{r['号']}·{r['来源']}）", r[k], '') for r in rs_] for f, rs_ in erows.items()} for k in ['生命', '出伤指数', '物防', '魔防', '敏捷']}
    eres = {k: outliers(v, '怪物·' + k) for k, v in egroups.items()}

    # 逐招系数、跨来源
    kr, kg = sec_skillcoef(D)
    km, ko, ks = outliers(kg, '技能系数')
    src, nine, body, per_actor = sec_cross(D, pool, actor_tiers(D))
    ctab, cflags = sec_cross_extra(D, src, nine)
    allouts += ko
    cg, n_fields = sec_allcoef(D)
    cgg = {k: [(n, v, t) for n, v, t in rows_] for k, rows_ in cg.items()}
    cm, co, cs = outliers(cgg, '技能全系数')
    for o in bo + ao + ro:
        allouts.append(o)
    for k, (_, o, _) in skill_res.items():
        allouts += o
    for k, (_, o, _) in eres.items():
        allouts += o
    # 层间跳幅（怪物中位数相邻层 >2 或 <0.5）
    jumps = []
    for a, b in zip(curve, curve[1:]):
        for k in ['生命', '出伤指数', '物防', '魔防', '敏捷']:
            if a[k] and b[k]:
                q = b[k] / a[k]
                if q > HI or q < LO:
                    jumps.append((a['层'], b['层'], k, a[k], b[k], q))

    ranked = sorted([o for o in allouts if o['倍数'] is not None], key=sev, reverse=True)
    zero_med = [o for o in allouts if o['倍数'] is None]

    L.append('# 启封数值总对账报告（T520）')
    L.append('')
    L.append(f'由 `03_再刷重制_Godot/07_开发环境/启封数值对账.py --write` 生成，只读游戏数据。离群＝同档内 >中位数×{HI:g} 或 <中位数×{LO:g}；档内不足 3 条不判。怪物生命按「{dict(xunchang="寻常", jianxian="艰险", jiusi="九死", lianyu="炼狱", zhengdao="证道")[diff]}」目标回合 {turns} 算。本报告只摆数和倍数，不判断是不是有意为之。')
    L.append('')
    L.append('## 一、结论')
    L.append('')
    L.append('### 跨来源同属性：单一来源压过装备／超过其余来源合计（放最前）')
    L.append('')
    L.append('「装备整身」＝装备本体整身＋随机词条整身＋套装模板＋宝珠 3 颗的上限相加，再按九线封顶（damage_ledger nine_caps：①15%、②每系30%、③35%、属性30%）夹；「其余合计」＝同属性其它来源上限相加（单件／单条那几行不算进合计）。只同一属性内比，属性之间不比；乘区见第二节表 0。')
    L.append('')
    L.append('| 属性（乘区） | 来源 | 上限 | 谁 | 装备整身（封顶后／未封） | 其余合计 | 标记 |')
    L.append('|---|---|---|---|---|---|---|')
    for f in sorted(cflags, key=lambda f: -abs(f['上限']) / max(1e-9, f['装备整身'] or 1)):
        L.append(f"| {f['属性']}（{ATTR.get(f['属性'], ('',))[0]}） | {f['来源']} | {fmt(f['上限'])} | {f['谁']} | {fmt(f['装备整身'])}／{fmt(f['装备整身未封'])} | {fmt(f['其余合计'])} | {f['标记']} |")
    L.append('')
    L.append(f'- 离群条目合计 {len(allouts)} 条（装备底子 {len(bo)}、固定词条 {len(ao)}、随机词条 {len(ro)}、技能 {sum(len(v[1]) for v in skill_res.values())}、怪物 {sum(len(v[1]) for v in eres.values())}）；其中「档中位为 0、本条不为 0」{len(zero_med)} 条单列在第三节。')
    L.append(f'- 装备底子：读新表的装备按公式生成，同档同部位内份数一致（{len(bo)} 条离群）；不读表、照原版八项的 {len(noformula)} 件单列（第三节）。')
    L.append(f'- 固定词条：通用池 {len(pool)} 件里有原版必出词缀行的 {sum(v[1] for v in aff_count.values())} 件；它们按换算比放大后不受品质档约束，离群 {len(ao)} 条。')
    L.append(f'- 随机词条：{len(D.at["affixes"])} 条词条；同层同单位同阶同成色内离群 {len(ro)} 条；阶与阶之间普通成色跳幅超 ×{HI:g} 的 {len(steps)} 条。')
    L.append(f'- 怪物：1～33 层中位数相邻层跳幅超 ×{HI:g} 或低于 ×{LO:g} 的 {len(jumps)} 处；层内离群 {sum(len(v[1]) for v in eres.values())} 条。')
    L.append(f'- 装备等级：通用池里等级需求 > {lv_cap}（启封 1～30 层通用掉落挑装备的最高等级）或品质 > {GN[D.dt["generic"]["top_grade"]]} 的 {len(unreach)} 件在 1～30 层通用掉落里掉不出。')
    L.append('')
    L.append('### 离群前 20（按偏离倍数，跨类）')
    L.append('')
    L.append('| # | 类 | 名 | 档 | 值 | 档中位数 | 倍数 |')
    L.append('|---|---|---|---|---|---|---|')
    for n, o in enumerate(ranked[:20], 1):
        L.append(f"| {n} | {o['类']} | {o['名']} | {o['档']} | {fmt(o['值'])} | {fmt(o['中位数'])} | ×{fmt(o['倍数'])} |")
    L.append('')
    L.append('### 不平滑处（曲线跳幅）')
    L.append('')
    if jumps:
        L.append('| 层→层 | 项 | 前层中位 | 后层中位 | 倍数 |')
        L.append('|---|---|---|---|---|')
        for a, b, k, x, y, q in jumps:
            L.append(f'| {a}→{b} | {k} | {fmt(x)} | {fmt(y)} | ×{fmt(q)} |')
    else:
        L.append('（怪物各项中位数相邻层没有超出 ×0.5～×2 的跳幅）')
    if steps:
        L.append('')
        L.append('随机词条阶间跳幅（普通成色，一阶→四阶）：' + '；'.join(f'{n}〔{"/".join(fmt(float(x)) for x in s)}〕' for n, _, _, s in steps[:12]) + ('…' if len(steps) > 12 else ''))
    L.append('')

    # 二、分表
    L.append('## 二、分表')
    L.append('')
    L.append('### 0. 跨来源同属性总表（每来源上限／常见值／份额）')
    L.append('')
    L.append('份额＝本来源上限 ÷ 同属性各来源上限合计（「单件／单条／单颗」行只作参照，不进合计、不算份额）。百分数一律是「＋N%」加进所在乘区；⑤档位、烙印各自单独一池／单独相乘，不和③比大小。')
    L.append('')
    L.append('| 属性 | 乘区／叠法 | 来源 | 上限 | 常见值 | 谁 | 份额 | 说明 |')
    L.append('|---|---|---|---|---|---|---|---|')
    for a, (rows_, gear, gear_raw) in ctab.items():
        pz = ATTR.get(a, (a, '单独'))
        for n, v, share, mark in sorted(rows_, key=lambda x: -abs(x[1][0])):
            L.append(f"| {a} | {pz[0]}；{pz[1]} | {n} | {fmt(v[0])} | {fmt(v[1])} | {v[2]} | {'—' if share is None else f'{share * 100:.0f}%'} | {v[3]}{('；' + '、'.join(mark)) if mark else ''} |")
    L.append('')
    L.append('### 0b. 逐招伤害系数（每回合期望倍率＝系数×段数÷每几回合一次；单目标口径）')
    L.append('')
    L.append('| 档位·类别 | 招数 | 中位 | 最小 | 最大 |')
    L.append('|---|---|---|---|---|')
    for g in sorted(km):
        n, m, lo, hi = km[g]
        if n >= 3:
            L.append(f'| {g} | {n} | {fmt(m)} | {fmt(lo)} | {fmt(hi)} |')
    L.append('')
    L.append('逐招离群（前 30，按倍数）：')
    L.append('')
    L.append('| 招·角色 | 档位·类别 | 每回合期望 | 组中位 | 倍数 | 算法 |')
    L.append('|---|---|---|---|---|---|')
    for o in sorted(ko, key=sev, reverse=True)[:30]:
        L.append(f"| {o['名']} | {o['档']} | {fmt(o['值'])} | {fmt(o['中位数'])} | ×{fmt(o['倍数'])} | {o['备注']} |")
    L.append(f'\n（逐招共 {len(kr)} 条、离群 {len(ko)} 条；全表 --json。）')
    L.append('')
    L.append(f'### 0c. 技能全系数（卡里全部数值字段 {n_fields} 个，按字段路径分 {len(cm)} 组；离群 {len(co)} 条）')
    L.append('')
    L.append('字段路径照 skill_rework.json：heal.mhp_pct 治疗、shield.pct 护盾、cooldown 冷却、mp_pct／tp 消耗、seq.n 拆段、follow.rate 追加几率、damage.conds.* 条件（cap 封顶、per 每层、mult 倍率）、状态.turns 持续回合、状态.traits.* 状态特性值。同组内比，不分档位；备注列是档位。')
    L.append('')
    L.append('| 字段 | 条数 | 中位 | 最小 | 最大 |')
    L.append('|---|---|---|---|---|')
    for g in sorted(cm, key=lambda g: -cm[g][0])[:25]:
        n, m, lo, hi = cm[g]
        L.append(f'| {g} | {n} | {fmt(m)} | {fmt(lo)} | {fmt(hi)} |')
    L.append('')
    L.append('| 招／状态 | 字段 | 值 | 组中位 | 倍数 | 档位 |')
    L.append('|---|---|---|---|---|---|')
    for o in sorted(co, key=sev, reverse=True)[:30]:
        L.append(f"| {o['名']} | {o['档']} | {fmt(o['值'])} | {fmt(o['中位数'])} | ×{fmt(o['倍数'])} | {o['备注']} |")
    L.append('')
    L.append('### 1. 装备对应等级分布（通用池件数，等级段 × 品质）')
    L.append('')
    bands = sorted({b for b, _ in dist})
    L.append('| 等级段 | ' + ' | '.join(GN) + ' | 合计 |')
    L.append('|---' * (len(GN) + 2) + '|')
    for b in bands:
        row = [dist.get((b, g), 0) for g in range(7)]
        L.append(f'| {band_name(b)} | ' + ' | '.join(str(x) if x else '·' for x in row) + f' | {sum(row)} |')
    L.append('')
    lbf = D.dt['generic']['level_by_floor']
    L.append('通用掉落按层挑装备的等级上限（drop_table.generic.level_by_floor，层间线性插值）：' + '、'.join(f'{f} 层 {lv}' for f, lv in lbf) + f'；窗口向下 {D.dt["generic"]["level_window"]} 级。')
    L.append('不进通用池的：' + '；'.join(f'{k} {v} 件' for k, v in skipped.items()) + '。')
    L.append('')

    L.append('### 2. 装备基础属性（读新表的，按等级段·品质·部位的「标准线份数」中位）')
    L.append('')
    L.append('份数＝八项各除以本件等级的标准线后相加（同部位同品质理论上为常数：部位系数和×品质系数＋副属性）。只列有离群或件数 ≥5 的档。')
    L.append('')
    L.append('| 档 | 件数 | 中位 | 最小 | 最大 |')
    L.append('|---|---|---|---|---|')
    shown = 0
    for g in sorted(bm, key=lambda x: (x.split('·')[0], x)):
        n, m, lo, hi = bm[g]
        if n >= 5 and shown < 25:
            L.append(f'| {g} | {n} | {fmt(m)} | {fmt(lo)} | {fmt(hi)} |')
            shown += 1
    L.append(f'\n（共 {len(bm)} 档，表里只放前 {shown} 个件数 ≥5 的档；全表用 --json 导出。）')
    L.append('')

    L.append('### 3. 固定词条（原版必出词缀行，换算后的标准线份数，按等级段·品质）')
    L.append('')
    L.append('| 档 | 件数 | 带必出行的件数 | 中位 | 最大 |')
    L.append('|---|---|---|---|---|')
    for g in sorted(am, key=lambda x: x):
        n, m, lo, hi = am[g]
        L.append(f'| {g} | {n} | {aff_count[g][1]} | {fmt(m)} | {fmt(hi)} |')
    L.append('')

    L.append('### 4. 随机词条取值（affix_table，层·单位·阶·成色内）')
    L.append('')
    L.append('| 档 | 条数 | 中位 | 最小 | 最大 | 离群 |')
    L.append('|---|---|---|---|---|---|')
    ro_by = defaultdict(list)
    for o in ro:
        ro_by[o['档']].append(o)
    for g in sorted(rm):
        n, m, lo, hi = rm[g]
        if g.endswith('普通') or ro_by.get(g):
            L.append(f"| {g} | {n} | {fmt(m)} | {fmt(lo)} | {fmt(hi)} | {'、'.join(o['名'].split('（')[0] + '×' + fmt(o['倍数']) for o in ro_by.get(g, [])[:6])} |")
    L.append('\n（只列普通成色和有离群的档；上品、极与普通同一排数后移一格。）')
    L.append('')

    L.append('### 5. 角色技能强度（六维打分口径，按档位）')
    L.append('')
    L.append('| 项 | 档位 | 人数 | 中位 | 最小 | 最大 |')
    L.append('|---|---|---|---|---|---|')
    for k, (m_, o_, s_) in skill_res.items():
        for t in ['弱者', '强者', '超强者']:
            if t in m_:
                n, m, lo, hi = m_[t]
                L.append(f'| {k} | {t} | {n} | {fmt(m)} | {fmt(lo)} | {fmt(hi)} |')
    L.append('')
    so = [o for _, o, _ in skill_res.values() for o in o]
    if so:
        L.append('技能离群明细：')
        L.append('')
        L.append('| 项 | 名 | 档位 | 值 | 中位 | 倍数 |')
        L.append('|---|---|---|---|---|---|')
        for o in sorted(so, key=sev, reverse=True)[:30]:
            L.append(f"| {o['类'][3:]} | {o['名']} | {o['档']} | {fmt(o['值'])} | {fmt(o['中位数'])} | ×{fmt(o['倍数'])} |")
        L.append('')

    L.append(f'### 6. 怪物各层属性（中位数；生命按{turns}回合口径、已乘全局 {D.bt["combat_rules"]["enemy_hp_pct"]}%）')
    L.append('')
    L.append('| 层 | 只数 | 生命 | 出伤指数 | 物防 | 魔防 | 敏捷 | hp_base | atk_scale |')
    L.append('|---|---|---|---|---|---|---|---|---|')
    for c in curve:
        L.append(f"| {c['层']} | {c['只数']} | {fmt(c['生命'])} | {fmt(c['出伤指数'])} | {fmt(c['物防'])} | {fmt(c['魔防'])} | {fmt(c['敏捷'])} | {fmt(c['hp_base'])} | {fmt(c['atk_scale'], 4)} |")
    L.append('')
    L.append('35／36 层（horsemen.json，艰险基准）：' + '；'.join(f"{k['名']} 生命 {fmt(k['生命'])}、攻击 {fmt(k['攻击'])}、防御 {fmt(k['防御'])}" for k in knights) + f"；35 层影子生命 {fmt(shadow.get('hp'))}。34 层鸿钧借鸿蒙老祖合成记录，本脚本没算。")
    L.append('')
    eo = sorted([o for _, o, _ in eres.values() for o in o], key=sev, reverse=True)
    if eo:
        L.append('怪物层内离群明细（前 30）：')
        L.append('')
        L.append('| 项 | 名 | 层 | 值 | 层中位 | 倍数 |')
        L.append('|---|---|---|---|---|---|')
        for o in eo[:30]:
            L.append(f"| {o['类'][3:]} | {o['名']} | {o['档']} | {fmt(o['值'])} | {fmt(o['中位数'])} | ×{fmt(o['倍数'])} |")
        L.append(f'\n（共 {len(eo)} 条，全量用 --json。）')
    L.append('')

    # 三、单列
    L.append('## 三、单列（不进倍数排行的）')
    L.append('')
    L.append(f'**不读新表、照原版八项的通用池装备（{len(noformula)} 件）**：' + '；'.join(f'{n}〔{k}，份数 {fmt(v)}〕' for n, k, v, _ in noformula[:20]) + ('…' if len(noformula) > 20 else ''))
    L.append('')
    zm = defaultdict(list)
    for o in zero_med:
        zm[o['类']].append(o)
    for k, v in zm.items():
        v = sorted(v, key=lambda o: -abs(o['值']))
        L.append(f'**{k}：档中位为 0、本条不为 0（{len(v)} 条，按值大到小前 12）**：' + '；'.join(f"{o['名']}〔{o['档']}，{fmt(o['值'])}；{o['备注'][6:40]}〕" for o in v[:12]))
        L.append('')
    if unreach:
        L.append(f'**1～30 层通用掉落掉不出的通用池装备（{len(unreach)} 件，等级 > {lv_cap}、无等级或品质超上限）**：' + '、'.join(unreach[:25]) + ('…' if len(unreach) > 25 else ''))
        L.append('')
    smalls = bs + as_ + rs + [s for _, _, s_ in skill_res.values() for s in s_] + [s for _, _, s_ in eres.values() for s in s_]
    L.append(f'档内不足 3 条、没判离群的档 {len(smalls)} 个（--json 里有明细）。')
    L.append('')

    # 四、口径与拿不准
    L.append('## 四、口径与拿不准')
    L.append('')
    L.append('口径（照游戏代码复算，不跑 Godot）：')
    L.append('- 装备池＝`modes/xiyou/core/tianqi_gear.gd` drop_pool＋_reroll_ok，`core/tianqi_drop.gd` pool 去低档稀有；底子＝`tianqi_gear.gd` new_base；换算比 ratio 夹到 80 级（CAP_80）。')
    L.append('- 固定词条＝原版必出行（`core/tianqi_affix_roll.gd` skips_row 的反面），每行 ids 取均值；只算八项固定值，特性（命中、暴击、连击等）只数条数。')
    L.append('- 随机词条＝`core/tianqi_affix_table.gd` value 的算法；单位不同（percent／flat／turns…）的分开比。')
    L.append('- 技能＝`07_开发环境/六维打分_实测数据.json`（peak＝k_calibrate 含烙印整次施放峰值；生存＝--survive 挨打回合；速度用面板敏捷）＋`tianqi_data/six_dim.json` actors 字母分；档位读 `skill_rework.json` tiers。')
    L.append('- 怪物＝`core/guardian_rework.gd` TROOPS、_world、_scale_hp、atk_scale；`balance_table.json` guardian_phase4、combat_rules.enemy_hp_pct；31～33 层守层者双防 `guardian_params.json`。')
    L.append('')
    L.append('拿不准：')
    L.append('- 技能没有装备那样的 req_level，这里按档位（弱者／强者／超强者）分档，不是按等级；peak 只量了每人最高一招的一次施放，不代表整套循环。')
    L.append('- 装备底子同档内只因部位不同而不同（武器 1.2 份、盔甲 2.8 份…），所以分档细到部位；跨部位的比较没做。')
    L.append('- 固定词条只换算了八项，百分比特性、技能触发类效果没折成数，「中位为 0」的档里只要有必出行就会单列。')
    L.append('- 怪物「出伤指数」＝max(物攻,魔攻)×atk_scale×难度攻击，只是相对量，不含技能系数、集火招（focus）、伤害抵抗；守层者以外的敌人生命按本层守层者同比缩（_world），所以遇敌小怪和守层者同口径。')
    L.append('- 怪物楼层只认名字直接带「N层」的地图（' + '、'.join(f'{f}:{"/".join(n[:8] for n in v)}' for f, v in sorted(maps_used.items()) if len(v) > 1) + ' 等多图层都算进去了）；伐木场、黑金村、深渊、肝帝之地、天外天等挂在某层下面的子地图没算。科维努斯镇（7 层）按名字算进去了，它在启封里开不开没核。')
    L.append('- 28～33 层没有随机遇敌，只有守层者那场；七印里副本、七首之龙、心魔、鸿钧不在本表。')
    L.append('- 通用池按全部敌人掉落表算（同游戏），不是只看启封里出现的敌人。')
    L.append('- 跨来源表的「法宝」行扫的是全部带 Magic Weapon 的法宝栏物件（去掉被当词缀引用的），启封里哪些拿得到没核；法宝备注标签是否归九线封顶没核（ledger 只写「人族首领法宝」归 equip 桶）。')
    L.append('- 跨来源表的装备本体只算启封 1～30 层通用掉落掉得出的（等级 ≤75、品质 ≤不朽）；招牌掉落、商店、事件给的装备没单算。')
    L.append('- 跨来源表来源是按已知名单扫的（角色卡、装备、随机词条、套装模板、宝珠、种族、秘籍、通用书、法宝、档位、烙印、境、常驻规则），还没从结算函数倒查（见回执「没做」）。')
    L.append('- 技能全系数：damage.stats 权重、条件里的变量号／技能号（of、var、ids）也是数字字段，照样分组，看时跳过即可。')
    L.append('')
    detail = {'装备底子': {'档': bm, '离群': bo}, '固定词条': {'档': am, '离群': ao}, '随机词条': {'档': rm, '离群': ro, '阶间跳幅': steps},
              '技能': {k: {'档': v[0], '离群': v[1]} for k, v in skill_res.items()}, '怪物': {'曲线': curve, '离群': {k: v[1] for k, v in eres.items()}, '跳幅': jumps, '明细': erows},
              '不读表装备': noformula, '掉不出': unreach, '等级分布': {f'{band_name(b)}·{GN[g]}': n for (b, g), n in dist.items()}}
    return '\n'.join(L) + '\n', detail, allouts


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--json')
    ap.add_argument('--diff', default='jianxian', choices=['xunchang', 'jianxian', 'jiusi', 'lianyu', 'zhengdao'])
    a = ap.parse_args()
    if not DB.exists():
        sys.exit('没有 generated/db，先 新建工作树.sh --补齐')
    D = Data()
    md, detail, allouts = build(D, a.diff)
    md += __import__('启封数值对账_来源').section(D, sys.modules[__name__])  # T521 外部来源倒查（独立模块，见 启封数值对账_来源.py）
    if a.write:
        REPORT.write_text(md, encoding='utf-8')
        print('写了', REPORT.relative_to(GODOT.parent))
    if a.json:
        Path(a.json).write_text(json.dumps(detail, ensure_ascii=False, indent=1, default=str), encoding='utf-8')
        print('写了', a.json)
    print(md.split('### 离群前 20')[0])
    print('报告行数', md.count('\n'))


if __name__ == '__main__':
    main()
