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
import math
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GODOT = HERE.parent
REPO = GODOT.parent
X = GODOT / '01_Godot工程/modes/xiyou'
DB = X / 'generated/db'
MAPS = X / 'generated/maps'
TQ = X / 'tianqi_data'
MEAS = HERE / '六维打分_实测数据.json'
REPORT = HERE / '启封数值对账报告.md'

TUNE_ORDER = ('D189', 'D200', 'D198', 'D208', 'D209', 'D287')
REALM_IDS = {5707, 5714, 5777, 5778, 8083, 9976, 9982, 10018}  # XTianqiBase.REALM_IDS（期四已拦）
DIFF_KEYS = ['xunchang', 'jianxian', 'jiusi', 'lianyu', 'zhengdao']
DIFF_TURNS = {'xunchang': 6, 'jianxian': 8, 'jiusi': 10, 'lianyu': 12, 'zhengdao': 15}

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
        self.ST = load(DB / 'States.json')
        self.PL = load(DB / 'Plugins.json')
        self.ACTORS = load(DB / 'Actors.json')
        self.CE = load(DB / 'CommonEvents.json')
        self.gb = load(TQ / 'gear_base.json')
        self.gt = load(TQ / 'gear_table.json')
        self.ea = load(TQ / 'gear_elem_amp.json')
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
        # 技能卡／状态卡／装备卡＋各轮调参（按 TUNE_ORDER 逐层盖上，同 XTianqiBase.TUNE_* 全开；口径 2／20）
        self.cards = {k: dict(v) for k, v in self.rw.get('skills', {}).items() if isinstance(v, dict)}
        self.rw_states = {k: dict(v) for k, v in self.rw.get('states', {}).items() if isinstance(v, dict)}
        self.rw_gear = {k: dict(v) for k, v in self.rw.get('gear', {}).items() if isinstance(v, dict)}
        tunes = self.rw.get('tune', {})
        order = list(TUNE_ORDER) + [k for k in tunes if k not in TUNE_ORDER]
        for tk in order:
            tv = tunes.get(tk)
            if not isinstance(tv, dict):
                continue
            for sec, dst in (('skills', self.cards), ('states', self.rw_states), ('gear', self.rw_gear)):
                for sid, patch in (tv.get(sec) or {}).items():
                    if isinstance(patch, dict):
                        dst.setdefault(sid, {}).update({k: v for k, v in patch.items() if not k.startswith('_')})
        self.efabao = {int(row['id']): row for row in self.gt.get('element_fabaos', {}).get('items', []) if isinstance(row, dict) and row.get('id')}
        mog = self.PL.get('MOG_BossHP', {})
        self.boss_ids = {int(mog.get(f'boss-{i}', 0)) for i in range(1, 570)} - {0}
        self.meas = load(MEAS)
        self.slots = {int(v['etype']): v for v in self.gb['slots'].values()}

    def rec(self, kind, i):
        t = self.W if kind == 2 else self.A
        return t[i] if 0 <= i < len(t) and t[i] else {}

    def effective_state(self, sid):
        """天启篇改写后的状态（口径 2／20：叠加 skill_rework.states 与 general_books.states，含 traits 覆盖与 note_edit）"""
        i = int(sid)
        base = self.ST[i] if 0 <= i < len(self.ST) and self.ST[i] else {}
        sp = self.rw_states.get(str(i)) or self.gbk.get('states', {}).get(str(i))
        if not sp:
            return base
        out = dict(base)
        if 'name' in sp:
            out['name'] = sp['name']
        out['note'] = note_edit(base.get('note', ''), sp)
        if 'traits' in sp and isinstance(sp['traits'], list):
            out['traits'] = list(sp['traits'])
        else:
            tr = list(base.get('traits', []))
            for cd in sp.get('traits_remove', []) or []:
                tr = [t for t in tr if not (t.get('code') == cd[0] and (len(cd) < 2 or t.get('dataId') == cd[1]))]
            tr += sp.get('traits_set', []) or []
            out['traits'] = tr
        return out

    def warehouse_rate(self):
        """天启篇开局统一借普通难度 3（DCultyL3=true → Star_Warehouse DCL3=2.0）"""
        sw = self.PL.get('Star_Warehouse', {})
        try:
            return float(sw.get('DCL3', '2.0'))
        except (TypeError, ValueError):
            return 2.0

    def vitsuno_rates(self, legacy=3):
        vd = self.PL.get('Vitsuno_Difficulty', {})
        s = str(vd.get(f'{legacy} : Param Rate', ''))
        if not s:
            return [1.0] * 8
        return [float(x) for x in s.split(',')]

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
    """装备池（口径 10）：通用池 ＋ 招牌／低档稀有掉落池（不再把招牌掉落排在装备池外）"""
    keys, best = drop_pool(D)
    rare_below = D.dt['generic'].get('rare_below', 0.003)
    cut_g = D.dt['generic'].get('table_cut_grade', 2)
    out, sig_pool, skipped = [], [], defaultdict(int)
    for kind, i in keys:
        r = D.rec(kind, i)
        if not r or not r.get('name'):
            skipped['无名'] += 1
            continue
        et = r.get('etypeId', 1 if kind == 2 else 0)
        if kind == 3 and (et not in ORDER or et == 17):
            skipped['删除栏位／神器栏'] += 1
            continue
        g = D.grade(r)
        is_excl = bool(REQ_ACT.search(r.get('note', '')))
        is_rare = g <= cut_g and best[(kind, i)] < rare_below
        if is_excl:
            sig_pool.append((kind, i, r, '专属招牌掉落'))
            skipped['专属（归招牌掉落池）'] += 1
            continue
        if is_rare:
            sig_pool.append((kind, i, r, '低档稀有（照原表掉）'))
            skipped['低档稀有（归招牌掉落池）'] += 1
            continue
        out.append((kind, i, r))
        if g > cut_g:
            sig_pool.append((kind, i, r, '高档招牌掉落'))
    return out, skipped, sig_pool


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
    pool, skipped, sig_pool = gear_pool(D)
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
    return pool, skipped, sig_pool, base_g, aff_g, dist, noformula, unreach, aff_count, lv_cap


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
    """技能强度（口径 7）：输出峰值按「档位 × 输出评级」分组；没量到峰值的人单列名单与原因"""
    ms = D.meas['actors']
    tier_of = actor_tiers(D)
    sc = D.sd['scale']
    groups = {'输出峰值': defaultdict(list), '生存（撑过回合）': defaultdict(list), '速度（面板敏捷）': defaultdict(list), '六维总分': defaultdict(list)}
    missing_peak = []
    for aid, a in D.sd['actors'].items():
        t = tier_of.get(aid)
        if not t:
            continue
        nm = f"{a.get('name', aid)}（{aid}）"
        m = ms.get(aid, {})
        out_grade = a.get('output', '?')
        groups['六维总分'][t].append((nm, float(sum(sc[a[d]] for d in D.sd['dims'] if d in a)), ''.join(a.get(d, '?') + ' ' for d in D.sd['dims']).strip()))
        if m.get('peak'):
            groups['输出峰值'][f'{t}·输出{out_grade}'].append((nm, float(m['peak']), f"招 {m.get('skill')}，{m.get('segs')} 段"))
        else:
            why = []
            if m.get('disabled'):
                why.append('启封停用（disabled）')
            if m.get('no_damage_row'):
                why.append('探针无出伤行（no_damage_row）')
            if not why:
                why.append('六维实测数据缺少 peak')
            missing_peak.append({'号': aid, '名': a.get('name', aid), '档位': t, '输出评级': out_grade, '原因': '；'.join(why)})
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
    not_open = []
    for aid in D.rw_tiers.get('不开放', []):
        rec = D.ACTORS[aid] if isinstance(aid, int) and 0 <= aid < len(D.ACTORS) and D.ACTORS[aid] else {}
        not_open.append({'号': str(aid), '名': rec.get('name', str(aid)), '原因': 'skill_rework.tiers 不开放'})
    return groups, tier_of, missing_peak, not_open


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


HONGJUN_SCALE = 0.0000109  # 同 core/guardian_rework.gd HONGJUN_SCALE
GUARD_TROOPS = {1: 4, 2: 5, 3: 8, 4: 22, 5: 28, 6: 39, 7: 52, 8: 53, 9: 67, 10: 69, 11: 109, 12: 110, 13: 111, 14: 118, 15: 138,
                16: 172, 17: 173, 18: 174, 19: 333, 20: 456, 21: 457, 22: 458, 23: 459, 24: 460, 25: 461, 26: 462, 27: 463, 28: 464, 29: 465,
                30: 466, 31: 467, 32: 468, 33: 469}  # 同 core/guardian_rework.gd TROOPS
ELITE_NAME_RE = re.compile(r'【(?:稀有|精英|前所未见|亘古未有|亘古未见|首领|霸主)】')
ENEMY_CATS = ('首领', '精英', '小怪')
HIT_TYPE_CN = {0: '必中', 1: '物理', 2: '魔法'}


def _gd_round(x):
    return float(math.floor(x + 0.5) if x >= 0 else math.ceil(x - 0.5))


def _enemy_param_rate(e, i):
    """特性 21（code 21）同 XBattler.traits_pi：1 + Σ(v - 1)"""
    r = 1.0
    for t in e.get('traits', []):
        if t.get('code') == 21 and t.get('dataId') == i:
            r += float(t.get('value', 1.0)) - 1.0
    return r


def _elite_hp_mult(D, e):
    """EliteEnemy 神话能力倍率（默认 3.5，NoElite 不会变）"""
    if 'NoElite' in str(e.get('note', '')):
        return None
    meta = e.get('meta', {}).get('elite')
    if meta is not None:
        parts = str(meta).split(',')
        if len(parts) > 1 and parts[1].strip():
            try:
                return float(parts[1])
            except ValueError:
                pass
    try:
        return float(D.PL.get('EliteEnemy', {}).get('EliteEnemyAdditionParamBase', '3.5'))
    except (TypeError, ValueError):
        return 3.5


def _enemy_cat(src, name):
    """同 core/tianqi_seg_alien.gd 口径分三类：首领（守层者那场／鸿钧）、精英（稀有／前所未见／亘古未有等）、小怪（无前缀／罕见／十分罕见）"""
    if src in ('守层者那场', '鸿钧（合成）'):
        return '首领'
    if ELITE_NAME_RE.search(name or ''):
        return '精英'
    return '小怪'


def _calc_enemy_hp_real(p0, pr0, rate0, warehouse, hp_pct_all):
    """按 XEnemy.param_now(0) → _param_raw(0) → XTianqiBase.scale_enemy_mhp 逐阶取整（口径 13／25）"""
    v_now = _gd_round(max(1.0, p0 * pr0 * rate0))
    v_raw = _gd_round(v_now * warehouse)
    if hp_pct_all == 100:
        return int(max(1, v_raw))
    return int(max(1, math.floor(v_raw * hp_pct_all / 100.0)))


def _build_enemy_for_diff(D, diff, floors):
    """单档难度下，按真实代码路径（guardian_rework.gd:367-416）算 1～34 层，分首领／精英／小怪三类建曲线与跳幅（口径 6／13／24／25）"""
    turns = DIFF_TURNS[diff]
    dif = next(d for d in D.bt['difficulties'] if d['key'] == diff)['scaling']
    g4 = D.bt['guardian_phase4']
    hp_pct_all = int(D.bt['combat_rules']['enemy_hp_pct'])
    ref = D.E[D.gp['ref_enemy']]['params']
    vr = D.vitsuno_rates(3)  # 天启篇统一借普通难度 3
    wh = D.warehouse_rate()  # 天启篇开局 DCultyL3 → Star_Warehouse DCL3=2.0
    hp_unit = 1.0 / 6.0      # XTianqiNoX6 去 ×6
    r0_init = vr[0] * float(dif['enemy_hp']) * hp_unit

    rows = defaultdict(list)
    curves_by_cat = {c: [] for c in ENEMY_CATS}
    single_digit_mobs = []

    for f in range(1, 34):
        g_members = D.T[GUARD_TROOPS[f]].get('members', [])
        old_total = sum(float(D.E[m['enemyId']]['params'][0]) for m in g_members)
        hb = float(g4['hp_base'].get(str(f), 0))
        hpp = int(g4.get('hp_pct', {}).get(str(f), 100))
        atk_s = float(g4['atk_scale'].get(str(f), 1.0))

        # 守层者那场（guardian_rework.gd:367-374）：先算各成员 mhp_raw 求 total，再乘 k = hb*turns/total*hpp/100
        g_mhp_raw_total = 0.0
        for m in g_members:
            ge = D.E[m['enemyId']]
            gp0 = float(ge['params'][0])
            gpr0 = _enemy_param_rate(ge, 0)
            g_mhp_raw_total += _gd_round(_gd_round(max(1.0, gp0 * gpr0 * r0_init)) * wh)
        k_guard = (hb * turns / g_mhp_raw_total * hpp / 100.0) if g_mhp_raw_total > 0 else 0.0
        # 楼层敌群 _world（guardian_rework.gd:402-416）：k_world = hb*turns / (old_total * r0_init)，r0_new = r0_init * k_world = hb*turns/old_total
        r0_world = (hb * turns / old_total) if old_total > 0 else 0.0

        by_cat_f = {c: [] for c in ENEMY_CATS}
        for eid, src in floors[f].items():
            e = D.E[eid]
            if not e or not e.get('name'):
                continue
            p = list(e['params'])
            pr0 = _enemy_param_rate(e, 0)
            cat = _enemy_cat(src, e['name'])
            if src == '守层者那场':
                hp = _calc_enemy_hp_real(float(p[0]), pr0, r0_init * k_guard, wh, hp_pct_all)
                myth_hp = None
                path_note = 'setup(D248实测表)'
            else:
                # 严格走 _world：e._rates[0] 从 r0_init（含难度倍率与去×6）经 _scale_hp 变为 r0_world，再经 param_now round → warehouse(×2) round → scale_enemy_mhp(×40% floor)
                hp = _calc_enemy_hp_real(float(p[0]), pr0, r0_world, wh, hp_pct_all)
                em = _elite_hp_mult(D, e)
                myth_hp = _calc_enemy_hp_real(math.floor(float(p[0]) * em), pr0, r0_world, wh, hp_pct_all) if em else None
                path_note = '_world实路径'
                if hp < 10:
                    path_note = '_world实路径核实个位数(old_total为原版守层者天量血)'
                    single_digit_mobs.append({'层': f, '号': eid, '名': e['name'], '类': cat, '原血': p[0], '实算血': hp, '神话血': myth_hp})
            dfn, mdf = float(p[3]), float(p[5])
            if src == '守层者那场' and str(f) in D.gp['floors']:
                ov = D.gp['floors'][str(f)]
                dfn = _gd_round(ref[3] * ov.get('def', 100) / 100.0) if 'def' in ov else dfn
                mdf = _gd_round(ref[5] * ov.get('mdf', 100) / 100.0) if 'mdf' in ov else mdf
            out = max(p[2], p[4]) * atk_s * float(dif['enemy_atk'])
            r = {'层': f, '号': eid, '名': e['name'], '来源': src, '类': cat, '生命': hp, '神话生命': myth_hp,
                 '出伤指数': out, '物攻': p[2], '魔攻': p[4], '物防': dfn, '魔防': mdf, '敏捷': p[6], '路径': path_note}
            rows[f].append(r)
            by_cat_f[cat].append(r)
        for cat in ENEMY_CATS:
            fl = by_cat_f[cat]
            if fl:
                curves_by_cat[cat].append({
                    '层': f, '类': cat, '只数': len(fl),
                    **{k2: (int(round(med([x[k2] for x in fl]))) if k2 == '生命' else med([x[k2] for x in fl]))
                       for k2 in ['生命', '出伤指数', '物防', '魔防', '敏捷']},
                    'hp_base': hb, 'atk_scale': atk_s,
                })

    # 34 层鸿钧（归首领）
    hj = load(TQ / 'summit.json').get('hongjun', {})
    if hj:
        p = [a * b for a, b in zip(D.E[hj['enemy']]['params'], hj['rate'])]
        hb = float(g4['hp_base'].get('34', 0))
        ov = D.gp['floors'].get('34', {})
        hp34 = int(max(1, math.floor(_gd_round(hb * turns) * hp_pct_all / 100.0)))
        r = {'层': 34, '号': hj['enemy'], '名': hj['name'], '来源': '鸿钧（合成）', '类': '首领', '生命': hp34, '神话生命': None,
             '出伤指数': max(p[2], p[4]) * HONGJUN_SCALE * float(dif['enemy_atk']), '物攻': p[2], '魔攻': p[4],
             '物防': _gd_round(ref[3] * ov.get('def', 100) / 100.0) if 'def' in ov else p[3],
             '魔防': _gd_round(ref[5] * ov.get('mdf', 100) / 100.0) if 'mdf' in ov else p[5], '敏捷': p[6], '路径': 'setup(D248实测表)'}
        rows[34].append(r)
        curves_by_cat['首领'].append({'层': 34, '类': '首领', '只数': 1, **{k2: r[k2] for k2 in ['生命', '出伤指数', '物防', '魔防', '敏捷']},
                                      'hp_base': hb, 'atk_scale': HONGJUN_SCALE})

    jumps_by_cat = {}
    for cat in ENEMY_CATS:
        js = []
        cv = curves_by_cat[cat]
        for a, b in zip(cv, cv[1:]):
            for k in ['生命', '出伤指数', '物防', '魔防', '敏捷']:
                if a[k] and b[k]:
                    q = b[k] / a[k]
                    if q > HI or q < LO:
                        js.append((a['层'], b['层'], cat, k, a[k], b[k], q))
        jumps_by_cat[cat] = js
    return rows, curves_by_cat, jumps_by_cat, single_digit_mobs, turns


def sec_enemy_hit_types(D, floors):
    """口径 18：1～34 层敌人伤害招按命中类型（物理、魔法、必中）统计占比，按层分"""
    hj = load(TQ / 'summit.json').get('hongjun', {})
    per_floor = []
    tot = {0: 0, 1: 0, 2: 0}
    for f in range(1, 35):
        eids = list(floors[f].keys()) if f <= 33 else ([hj['enemy']] if hj else [])
        sids = set()
        for eid in eids:
            e = D.E[eid] if 0 <= eid < len(D.E) and D.E[eid] else {}
            for act in e.get('actions', []) or []:
                sid = int(act.get('skillId', 0))
                if sid > 0:
                    sids.add(sid)
        cnt = {0: 0, 1: 0, 2: 0}
        for sid in sids:
            sk = D.S[sid] if 0 <= sid < len(D.S) and D.S[sid] else None
            if not sk:
                continue
            dt = int(sk.get('damage', {}).get('type', 0))
            if dt in (1, 5):  # HP 伤害／HP 吸取
                ht = int(sk.get('hitType', 0))
                if ht in cnt:
                    cnt[ht] += 1
                    tot[ht] += 1
        n_all = sum(cnt.values())
        per_floor.append({
            '层': f, '伤害招数': n_all,
            '物理': cnt[1], '魔法': cnt[2], '必中': cnt[0],
            '物理%': round(cnt[1] / n_all * 100, 1) if n_all else 0.0,
            '魔法%': round(cnt[2] / n_all * 100, 1) if n_all else 0.0,
            '必中%': round(cnt[0] / n_all * 100, 1) if n_all else 0.0,
        })
    n_tot = sum(tot.values())
    summary = {
        '伤害招人次(去重按层)': n_tot,
        '物理': tot[1], '魔法': tot[2], '必中': tot[0],
        '物理%': round(tot[1] / n_tot * 100, 1) if n_tot else 0.0,
        '魔法%': round(tot[2] / n_tot * 100, 1) if n_tot else 0.0,
        '必中%': round(tot[0] / n_tot * 100, 1) if n_tot else 0.0,
    }
    return per_floor, summary


def sec_enemy(D, diff):
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

    # 五档难度全算（口径 24：首领／精英／小怪 × 五档）
    all_diffs = {}
    for dk in DIFF_KEYS:
        all_diffs[dk] = _build_enemy_for_diff(D, dk, floors)
    rows, curves_by_cat, jumps_by_cat, single_digit_mobs, turns = all_diffs[diff]
    jumps_5diff = {dk: all_diffs[dk][2] for dk in DIFF_KEYS}
    hit_floors, hit_summary = sec_enemy_hit_types(D, floors)

    knights = []
    for key, kn in D.hm['knights'].items():
        knights.append({'名': kn['name'], '生命': kn.get('hp'), '攻击': kn.get('atk'), '魔攻': kn.get('mat'), '防御': kn.get('def')})
    sh = D.hm.get('shadow', {})
    return rows, curves_by_cat, jumps_by_cat, jumps_5diff, single_digit_mobs, hit_floors, hit_summary, knights, sh, maps_used, turns


# ---------------- 角色白板属性 ----------------
LEVELS = [1, 30, 60, 99]


def actor_mult(D, aid, stat):
    """同 XTianqiBase.actor_mult：职责×速度档×个人微调（TUNE_D189 开）"""
    row = D.bl['actors'].get(str(aid), {})
    if not row:
        return 1.0
    role = D.bl['roles'].get(row.get('role', '均衡'), {})
    m = 1.0
    if stat == 'mhp':
        m = role.get('hp', 1.0)
    elif stat in ('def', 'mdf'):
        m = role.get('def', 1.0)
    elif stat == 'agi':
        m = D.bl['speed'].get(row.get('speed', '中'), 1.0)
    tw = row.get('tweak', {}).get(stat, 1.0)
    tw = D.bl.get('tune', {}).get('D189', {}).get('actors', {}).get(str(aid), {}).get('tweak', {}).get(stat, tw)
    return m * tw


def sec_white(D):
    """每人 8 项在 1/30/60/99 级的本体（XTianqiBase.param_base＝floor(标准线(等级)×actor_mult)）；按档位分组比 99 级"""
    tier_of = actor_tiers(D)
    rows, groups = [], defaultdict(list)
    for aid, t in tier_of.items():
        if str(aid) not in D.bl['actors']:
            continue
        row = D.bl['actors'][str(aid)]
        r = {'号': aid, '名': row.get('name', aid), '档位': t, '职责': row.get('role'), '速度': row.get('speed')}
        for st in STATS:
            r[st] = {lv: int(D.line(lv, st) * actor_mult(D, aid, st)) for lv in LEVELS}
            groups[f'{t}·{SN[st]}'].append((f"{r['名']}（{aid}·{r['职责']}/{r['速度']}）", float(r[st][99]), ''))
        rows.append(r)
    return rows, groups


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


def stat_weight(dmg):
    """卡上属性权重折成「攻击当量」：生命、魔法按标准线 ×25（同 skill_rework.rules.single_hit_cap_note 口径），其余 ×1"""
    w = sum(float(v) * (25 if k in ('mhp', 'mmp') else 1) for k, v in (dmg.get('stats') or {}).items())
    return w if w > 0 else 1.0


def sec_skillcoef(D):
    """逐招（口径 8）：普通冷却＝系数×段数÷(冷却＋1)；冷却 ≥99 是一场一次，不按 ÷100 算，单独归入「档位·一场一次」比单次施放总倍率"""
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
        coef = float(dmg['coef']) * stat_weight(dmg)
        if coef <= 0:
            continue
        n, how = segs_of(D, sid, c)
        cd = int(c.get('cooldown', 0) or 0)
        once = cd >= 99
        per = coef * n if once else (coef * n / (cd + 1 if cd > 0 else 1))
        kind = c.get('kind') or '?'
        tgt = '全体' if '全体' in kind else ('随机' if '随机' in kind else '单体')
        stats = '+'.join(f'{k}×{v:g}' for k, v in dmg.get('stats', {}).items())
        cost = ('MP%d%%' % c['mp_pct']) if c.get('mp_pct') else (('TP%d' % c['tp']) if c.get('tp') else (('MP%d' % c['mp']) if c.get('mp') else ''))
        aname = D.sd['actors'][aid].get('name', aid)
        rows.append({'招': f"{c.get('name', sid)}（{sid}）", '角色': f'{aname}（{aid}）', '档位': t, '类别': kind, '目标': tgt, '系数': coef,
                     '段数': n, '段数来源': how, '冷却': '一场一次' if once else cd, '一场一次': once, '消耗': cost, '属性': stats,
                     '条件最高': cond_max(dmg), '每回合期望': per})
    for sid, c in D.gbk['skills'].items():
        dmg = c.get('damage')
        if not isinstance(dmg, dict) or 'coef' not in dmg:
            continue
        coef = float(dmg['coef']) * stat_weight(dmg)
        n = int(c.get('repeats', 0) or 0) or segs_of(D, sid, c)[0]
        cd = int(c.get('cooldown', 0) or 0)
        once = cd >= 99
        rows.append({'招': f"{c.get('name', sid)}（{sid}）", '角色': '通用书', '档位': '通用书', '类别': '书·主动', '目标': '—', '系数': coef,
                     '段数': n, '段数来源': '书', '冷却': '一场一次' if once else cd, '一场一次': once, '消耗': '',
                     '属性': '+'.join(f'{k}×{v:g}' for k, v in dmg.get('stats', {}).items()),
                     '条件最高': cond_max(dmg), '每回合期望': coef * n if once else coef * n / (cd + 1 if cd > 0 else 1)})
    groups = defaultdict(list)
    for r in rows:
        if r['一场一次']:
            gkey = f"{r['档位']}·一场一次"
            algo = f"一场一次（不按÷100）：折算系数{r['系数']:.3g}×{r['段数']}段（{r['段数来源']}，按8回合折 {r['每回合期望'] / 8:.2f}/回）；{r['属性']}"
        else:
            gkey = f"{r['档位']}·{r['类别']}"
            algo = f"折算系数{r['系数']:.3g}×{r['段数']}段（{r['段数来源']}）÷{r['冷却'] + 1 if r['冷却'] else 1}回合；{r['属性']}"
        groups[gkey].append((f"{r['招']}·{r['角色']}", r['每回合期望'], algo))
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
# 属性键 → (乘区, 叠法)；口径照 core/power.gd _notes 与 damage_ledger.json pools／nine_caps（口径 9：相乘属性份额按对数倍率算）
ATTR = {
    '③伤害加成%': ('③ 伤害加成池', '池内相加，池间相乘'),
    '①技能伤%': ('① 技能池', '池内相加，池间相乘'),
    '②元素伤%(单系)': ('② 元素池（每系）', '池内相加，池间相乘'),
    '④暴伤%': ('④ 暴击（暴伤）', '池内相加；九线 phase4 封 +30%'),
    '④暴击率%': ('④ 暴击（暴击率）', '概率相加'),
    '攻击%': ('能力值倍率（物攻／魔攻取大）', '跨来源相乘（特性21内加算）；份额按对数倍率算'),
    '生命%': ('能力值倍率（生命）', '跨来源相乘（特性21内加算）；份额按对数倍率算'),
    '穿透%': ('靶（机制：百分比穿透）', '相加'),
    '再行动%': ('回合预算（每人每回合最多多 1 次）', '取概率'),
    '承伤%': ('承伤（全伤减伤，特性 23 物理／魔法承伤）', '各减伤线连乘；份额按对数倍率算'),
    '元素抗性%(单系)': ('元素抗性（单系）', '各抗性线连乘；份额按对数倍率算'),
}
MUL_ATTRS = {'攻击%', '生命%', '承伤%', '元素抗性%(单系)'}
TAG_RE = re.compile(r'<\s*(passiveHarmRi|passiveCrHarmRi|passiveELUP(\d+)|SkETypeHarmRi(\d+)|SkillPass(\d+)|passiveAPLUS|DepassiveHarmRe(\d+)|SkillCriPush(?:All|Mf|Zj))\s*:\s*([+-]?\d+(?:\.\d+)?)\s*(%?)\s*>', re.I)
EA_RE = re.compile(r'<\s*Element Amplify (\d+)\s*:\s*([+-]?[\d.]+)%\s*>', re.I)
PB_RE = re.compile(r'<\s*passivePBST([0-7])\s*:\s*([+-]?\d+(?:\.\d+)?)(%?)\s*>', re.I)
XPB_RE = re.compile(r'<\s*passiveXPBST([0-9])\s*:\s*([+-]?\d+(?:\.\d+)?)%?\s*>', re.I)
ELEM_AMP_STRIP_RE = re.compile(r'(?i)<\s*Element\s+Amplify\s+[^:>]+:\s*[+-]?\d+(?:\.\d+)?[%％]\s*>\r?\n?')


def _share_weight(attr, val):
    """口径 9：相乘属性用对数倍率 |ln(1 + v/100)| 算份额，避免线性相加虚报占比"""
    if attr in MUL_ATTRS:
        return abs(math.log(max(1e-6, 1.0 + float(val) / 100.0)))
    return abs(float(val))


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
    """装备有效标签与特性（口径 2／3／20：叠加系别法宝改写、T451 元素增幅重调、skill_rework.gear 含 tune）"""
    gid = int(r.get('id', 0))
    note = r.get('note', '') or ''
    traits = list(r.get('traits', []))
    # 1) 系别法宝改写（gear_table.element_fabaos：剥旧标签与旧特性，仅留本系 +10%）
    if kind == 3 and gid in D.efabao:
        ef = D.gt.get('element_fabaos', {})
        sp = D.efabao[gid]
        strip_tags = ef.get('strip_note_tags', ['Element Amplify \\d+', 'DepassiveHarmRe\\d+', 'passiveCrHarmRi', 'passiveHarmRi'])
        strip_re = re.compile(r'(?i)<(?:' + '|'.join(strip_tags) + r')(?::[^>]*)?>\r?\n?')
        note = strip_re.sub('', note)
        strip_codes = set(ef.get('strip_trait_codes', [11, 21, 22, 34, 61]))
        traits = [t for t in traits if t.get('code') not in strip_codes]
        elem = int(sp.get('element', 0))
        pct = int(sp.get('bonus_pct', ef.get('bonus_pct', 10)))
        if elem:
            note += f'\n<Element Amplify {elem}: +{pct}%>'
    # 2) T451 装备元素增幅重调（gear_elem_amp.json）
    ea_sec = 'weapons' if kind == 2 else 'armors'
    ea_sp = D.ea.get(ea_sec, {}).get(str(gid))
    if isinstance(ea_sp, dict) and ea_sp.get('amp'):
        note = ELEM_AMP_STRIP_RE.sub('', note)
        for ek, ev in ea_sp['amp'].items():
            note += f'\n<Element Amplify {ek}: +{int(ev)}%>'
    # 3) skill_rework.gear（含 tune 叠层）
    key = '%s:%d' % ('weapon' if kind == 2 else 'armor', gid)
    g = D.rw_gear.get(key, {})
    if g:
        note = note_edit(note, g)
        for cd in g.get('traits_remove', []) or []:
            traits = [t for t in traits if not (t.get('code') == cd[0] and (len(cd) < 2 or t.get('dataId') == cd[1]))]
        traits += g.get('traits_set', []) or []
    return scan(note, traits)


GONGFA_SUFFIX_RE = re.compile(
    r'(?:（[^）]*）|\([^)]*\)|[-·\s]*(?:IV|III|II|I|V|蓝|红|神)|[一二三四五六七八九十\d]+[层重式阶级]|大?圆满)+$'
)


def _skill_replace_uf(D):
    """口径 1：扫 CommonEvents 与地图事件里的 318 遗忘＋学习配对与脚本 forgetSkill，构建同功法替换链并查集"""
    parent = {}

    def find(x):
        while parent.get(x, x) != x:
            parent[x] = parent.get(parent[x], parent[x])
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    def scan_cmds(cmds):
        for i, c in enumerate(cmds):
            code, p = c.get('code'), c.get('parameters', [])
            if code == 318 and len(p) >= 4 and p[2] == 1:
                aid, old_s = p[1], int(p[3])
                for j in range(max(0, i - 10), min(len(cmds), i + 11)):
                    c2 = cmds[j]
                    p2 = c2.get('parameters', [])
                    if c2.get('code') == 318 and len(p2) >= 4 and p2[2] == 0 and p2[1] == aid:
                        union(old_s, int(p2[3]))

    for ce in D.CE:
        if ce:
            scan_cmds(ce.get('list', []))
    for mp in MAPS.glob('Map*.json'):
        try:
            d = load(mp)
        except OSError:
            continue
        for ev in d.get('events') or []:
            for pg in (ev or {}).get('pages') or []:
                scan_cmds(pg.get('list') or [])
    return find, union


def _gongfa_key(c, sid):
    nm = str(c.get('name') or sid).strip()
    if c.get('kind') == '进阶':
        return '进阶::' + GONGFA_SUFFIX_RE.sub('', nm).strip()
    base = GONGFA_SUFFIX_RE.sub('', nm).strip()
    return base or nm


def _affix_legal_slots(D, a):
    """口径 5／15：按栏位标签（进攻 4 栏、防守 8 栏、通用 10 栏、光环 2 栏）算该词条合法栏位数"""
    layer = a.get('layer', 'base')
    tag = a.get('tag', 'gen')
    gmap = {g['key']: g for g in D.at.get('slot_groups', [])}
    n = 0
    for sl in D.at.get('slots', []):
        sg = gmap.get(sl.get('group'), {})
        if layer not in sg.get('layers', []):
            continue
        if layer == 'aura':
            if sl.get('aura'):
                n += 1
        elif tag in sg.get('tags', []):
            n += 1
    return max(1, n)


def sec_cross(D, pool, sig_pool, tier_of):
    src = {}   # 来源 → {属性: (上限, 常见值, 上限是谁, 说明)}

    def put(name, attr, top, common, who, how=''):
        src.setdefault(name, {})[attr] = (top, common, who, how)

    # 1. 角色（口径 1）：同一功法／心法各层版本（替换链＋去阶后缀同名）只取同时生效的最高一层，不把各层累加；并排除 REALM_IDS
    uf_find, uf_union = _skill_replace_uf(D)
    by_actor_cards = defaultdict(list)
    for sid, c in D.cards.items():
        aid = str(c.get('actor', ''))
        if aid not in tier_of or int(sid) in REALM_IDS:
            continue
        by_actor_cards[aid].append((int(sid), c))
    per_actor = defaultdict(lambda: defaultdict(float))
    for aid, clist in by_actor_cards.items():
        # 按同名／去阶后缀归并同一功法的各层
        name_rep = {}
        for sid, c in clist:
            gk = _gongfa_key(c, sid)
            if gk in name_rep:
                uf_union(sid, name_rep[gk])
            else:
                name_rep[gk] = sid
        # 每组（同一功法）内按属性取最高一层；不同功法再相加
        grp_best = defaultdict(lambda: defaultdict(float))
        for sid, c in clist:
            root = uf_find(sid)
            for k, v in scan(card_note(D, sid)).items():
                if v > grp_best[root][k]:
                    grp_best[root][k] = v
        for root, attrs_ in grp_best.items():
            for k, v in attrs_.items():
                if k in ('②元素伤%(单系)', '①技能伤%', '攻击%'):
                    per_actor[aid][k] = max(per_actor[aid][k], v)
                else:
                    per_actor[aid][k] += v
    for attr in ATTR:
        vals = [(v[attr], aid) for aid, v in per_actor.items() if v.get(attr)]
        if vals:
            top = max(vals)
            put('角色技能／被动／心法（角色桶，不封顶）', attr, top[0], med([x for x, _ in vals]),
                f"{D.sd['actors'][top[1]].get('name')}（{top[1]}·{tier_of[top[1]]}）", f'{len(vals)} 人有（同功法取单层最高）')

    # 2. 装备本体（口径 2／10／20：通用掉落池 ＋ 招牌／低档稀有掉落池，套 T451 元素增幅重调与 skill_rework.gear）
    by_slot = defaultdict(lambda: defaultdict(list))
    lv_cap = max(x[1] for x in D.dt['generic']['level_by_floor'])
    top_g = D.dt['generic']['top_grade']
    seen_gear = set()
    sig_included = 0
    for kind, i, r in pool:
        lv = D.req(r, kind)
        if lv is None or lv > lv_cap or D.grade(r) > top_g:
            continue
        seen_gear.add((kind, i))
        et = r.get('etypeId', 1)
        for k, v in gear_eff(D, kind, r).items():
            by_slot[k][et].append((v, r['name']))
    for kind, i, r, tag in sig_pool:
        if (kind, i) in seen_gear:
            continue
        lv = D.req(r, kind)
        if lv is not None and lv > lv_cap:
            continue
        seen_gear.add((kind, i))
        sig_included += 1
        et = r.get('etypeId', 1)
        for k, v in gear_eff(D, kind, r).items():
            by_slot[k][et].append((v, f"{r['name']}〔{tag}〕"))
    body = {}
    for attr, slots in by_slot.items():
        one = max(max(x) for x in slots.values())
        body[attr] = sum(max(x)[0] for x in slots.values())
        put('装备本体（单件最高）', attr, one[0], med([v for x in slots.values() for v, _ in x]), one[1],
            f'{sum(len(x) for x in slots.values())} 件有（含招牌池 {sig_included} 件）')
        put('装备本体（整身：各栏单件最高相加）', attr, body[attr], None, f'{len(slots)} 栏', '九线封顶前（已套 T451＋改写）')

    # 3. 随机词条（口径 5／15：按栏位标签 攻4／防8／通10、每件特效≤2、同件不重名、不朽神话 3 格算全身上限）
    pool_attr = {'final_damage': '③伤害加成%', 'skill_damage': '①技能伤%', 'element_damage': '②元素伤%(单系)', 'crit_multiplier': '④暴伤%',
                 'damage_taken': '承伤%'}
    q_slots = {q['key']: q['slots'] for q in D.at.get('qualities', [])}
    sp_max = next((l.get('per_item_max') for l in D.at.get('layers', []) if l['key'] == 'special'), 2)
    for a in D.at['affixes']:
        attr = '元素抗性%(单系)' if a.get('key') == 'element_resist' else pool_attr.get(a.get('pool'))
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
        v = float(v) * (-1 if attr in ('承伤%', '元素抗性%(单系)') and v > 0 else 1)
        stack = a.get('stack', 'sum')
        n_leg = _affix_legal_slots(D, a)
        if stack == 'sum':
            whole = v * n_leg
        elif stack == 'multiply':
            whole = -((1.0 - (1.0 - abs(v) / 100.0) ** n_leg) * 100.0) if v < 0 else (((1.0 + v / 100.0) ** n_leg - 1.0) * 100.0)
        else:
            whole = v
        cur_w = src.get('随机词条（整身：按栏位标签上限）', {}).get(attr)
        if not cur_w or abs(whole) > abs(cur_w[0]):
            put('随机词条（单条，四阶·极）', attr, v, affix_val(D, a, 2, 0), f"{a['name']}（{a['key']}·{a['layer']}）", a.get('unit', ''))
            put('随机词条（整身：按栏位标签上限）', attr, whole, None, f"{a['name']}（{a.get('tag', 'gen')} {n_leg} 栏·{stack}）",
                f'同件不重名、特效每件≤{sp_max}、不朽/神话 {q_slots.get("buxiu", 3)} 格')

    # 4. 套装模板（口径 19：读 suit_template.json，并报两套同穿可达合计）
    tv = D.st['values']
    top_suit = max(v[-1] for v in tv.values())
    two_piece = tv['2'][-1]
    two_suit_52 = top_suit + two_piece  # 5件＋2件（7栏，常见毕业混穿）
    kmap = {'final_damage': '③伤害加成%', 'element_damage': '②元素伤%(单系)', 'mhp': '生命%', 'damage_reduction': '承伤%'}
    for k, kd in D.st['kinds'].items():
        attr = kmap.get(kd.get('affix'))
        if attr:
            v1 = -top_suit if attr == '承伤%' else top_suit
            v2 = -((1.0 - (1.0 - top_suit / 100.0) * (1.0 - two_piece / 100.0)) * 100.0) if attr == '承伤%' else two_suit_52
            put('套装模板（单套 5 件·四阶）', attr, v1, two_piece, kd['name'], f"suit_template.json（已归类 {len(D.st.get('suits', {}))} 套）")
            put('套装模板（两套同穿 5＋2·四阶）', attr, round(v2, 2), v1, kd['name'], 'XTianqiSuits.CAP=2；两套5+2可达合计（5+5无重叠栏位更高）')

    # 5. 宝珠（口径 4：属性% 按九线 param_cap +30% 封顶后算，未封理论值注明）
    caps = D.ledger['nine_caps']
    param_cap_pct = caps['param'] * 100
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
                    put('宝珠（同类 3 颗）', '②元素伤%(单系)', v * 3, None, fam['name'], '「全身同类只算最高 3 颗」；进九线 ② 封 +30%')
        for m in re.finditer(r'\b(ATK|MAT|MHP|CRI)\s*:\s*\+?([\d.]+)%', note):
            attr = {'ATK': '攻击%', 'MAT': '攻击%', 'MHP': '生命%', 'CRI': '④暴击率%'}[m.group(1)]
            v = float(m.group(2))
            raw3 = v * 3
            eff3 = min(raw3, param_cap_pct) if attr in ('攻击%', '生命%') else raw3
            cur = src.get('宝珠（单颗归真）', {}).get(attr)
            if not cur or v > cur[0]:
                put('宝珠（单颗归真）', attr, v, None, it.get('name', ''), '')
                note_cap = f'九线属性已封 +{param_cap_pct:g}%（未封 {raw3:g}%）' if attr in ('攻击%', '生命%') else 'xparam 不受 param_cap'
                put('宝珠（同类 3 颗）', attr, eff3, None, fam['name'], note_cap)

    # 6. 种族祝福（口径 22：按族、按属性分行，不虚报攻击 +20%）
    q_max = max(D.races['rates']) * 100
    q_med = D.races['rates'][2] * 100
    put('种族·神／魔／灵／妖（伤害③）', '③伤害加成%', q_max, q_med, '七阶（蛮族反攻 +1.5q=30%）', 'damage_ledger：＋q 进③')
    put('种族·魔族（暴伤④）', '④暴伤%', q_max / 2.0, q_med / 2.0, '魔族七阶', '暴击倍率 +q/2 进④')
    put('种族·蛮族（生命%）', '生命%', q_max, q_med, '蛮族七阶', '仅蛮族最大生命 ×(1+q)，其余族不加生命%')
    put('种族·人族（攻击%／八项）', '攻击%', 3.0, 3.0, '人族（固定×1.03）', '仅人族八项 ×1.03；无任何族给双攻 +20%')

    # 7. 秘籍格、通用书（每本；口径 2：读 general_books 改写后的技能）
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
        put('通用书（每本）', k, t[0], med([v for v, _ in vals]), t[1], f'{len(vals)} 本有（已套 general_books 改写）')

    # 8. 法宝（口径 3：套 12 把系别法宝改写，含表外 8101/8102）
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
                    fb[k].append((v, D.efabao.get(r['id'], {}).get('name') or r['name']))
    for fid, sp in D.efabao.items():
        if fid >= len(D.A) or not D.A[fid]:  # 表外水/风系别法宝 8101/8102
            tpl = D.rec(3, int(sp.get('template', 0)))
            if tpl:
                vrec = dict(tpl)
                vrec['id'] = fid
                vrec['name'] = sp.get('name', str(fid))
                for k, v in gear_eff(D, 3, vrec).items():
                    fb[k].append((v, vrec['name']))
    for k, vals in fb.items():
        t = max(vals)
        put('法宝（单件，备注标签）', k, t[0], med([v for v, _ in vals]), t[1], f'{len(vals)} 件有（已套 12 把系别法宝改写）')

    # 9. 天启篇自己的：档位⑤、烙印、境、常驻规则
    tiers = D.bt['tiers']
    put('档位池⑤（超强者）', '⑤档位', tiers['超强者']['damage_dealt'] * 100, tiers['强者']['damage_dealt'] * 100, '超强者', '⑤ 单独一池；强者 +50、弱者 0；弱者协力每人 +3')
    put('烙印（配满）', '烙印', D.brand['power']['max_bonus'] * 100, None, '烙印 100', '单独相乘、每人各自')
    hp_real = sum(b['params'].get('mhp', 0) for b in D.brand['realm']['base'])
    put('境底（七境累加）', '生命%', hp_real, None, '守一～逆命', 'brand.json realm.base')
    tr = D.brand.get('trade', {}).get('branches', [])
    if tr:
        put('境支·换伤（四支全选）', '③伤害加成%', sum(b['damage'] for b in tr) * 100, None, '锋骨／化刃／劫火／开印', '并入 K 口子（dealt_mult，单独乘）')
    put('天启篇常驻规则', '④暴击率%', D.bt['combat_rules']['crit_add'] * 100, None, 'combat_rules.crit_add', '全员')

    # 口径 3：九线爆伤封顶 phase4.nine_crit_dmg_cap 实际开着（+30%）
    nine = {
        '③伤害加成%': caps['bonus'] * 100,
        '①技能伤%': caps['skill'] * 100,
        '②元素伤%(单系)': caps['element'] * 100,
        '攻击%': caps['param'] * 100,
        '生命%': caps['param'] * 100,
    }
    p4_crit = D.ledger.get('phase4', {}).get('nine_crit_dmg_cap')
    if isinstance(p4_crit, (int, float)) and p4_crit >= 0:
        nine['④暴伤%'] = p4_crit * 100
    return src, nine, body, per_actor


def cross_judge(src, nine):
    """每个属性：各来源上限、份额（相乘属性按对数倍率算，口径 9）；压过装备＝单来源上限 > 其余来源上限合计，或 > 装备整身（九线封顶后）"""
    attrs = sorted({a for s in src.values() for a in s}, key=lambda a: list(ATTR).index(a) if a in ATTR else 99)
    table, flags = {}, []
    gear_srcs = ('装备底子（整身，75 级）', '装备本体（整身：各栏单件最高相加）', '随机词条（整身：按栏位标签上限）',
                 '套装模板（两套同穿 5＋2·四阶）', '宝珠（同类 3 颗）')
    skip_sum = ('装备本体（单件最高）', '随机词条（单条，四阶·极）', '宝珠（单颗归真）', '套装模板（单套 5 件·四阶）')
    for a in attrs:
        rows = [(n, s[a]) for n, s in src.items() if a in s]
        gear_raw = sum(abs(s[a][0]) for n, s in src.items() if a in s and n in gear_srcs)
        gear = min(gear_raw, nine[a]) if a in nine and gear_raw else gear_raw
        tot_w = sum(_share_weight(a, v[0]) for n, v in rows if n not in skip_sum)
        tot_lin = sum(abs(v[0]) for n, v in rows if n not in skip_sum)
        out = []
        for n, v in rows:
            top = abs(v[0])
            w = _share_weight(a, v[0])
            share = w / tot_w if tot_w and n not in skip_sum else None
            others = tot_lin - top if n not in skip_sum else None
            others_w = tot_w - w if n not in skip_sum else None
            mark = []
            if n not in gear_srcs and n not in skip_sum:
                if others_w is not None and w > others_w and len(rows) > 1:
                    mark.append('超过其余合计')
                if gear and top > gear:
                    mark.append('压过装备')
            out.append((n, v, share, mark))
            if mark:
                flags.append({'属性': a, '来源': n, '上限': v[0], '谁': v[2], '装备整身': gear, '装备整身未封': gear_raw, '其余合计': others, '标记': '、'.join(mark)})
        table[a] = (out, gear, gear_raw)
    return table, flags


# ---------------- 大类（第一层总表的行组；T521 外部来源也归进这些类） ----------------
# Kyo 11-25「先分类再细看」：来源大类固定这一串，T521 往 src 里加来源时名字写成「大类｜细项」即可归类；认不出的进「新发现」
CATS = ['角色白板', '被动心法', '技能', '装备底子', '固定词条', '随机词条', '套装', '宝石宝珠', '符石', '技能书秘籍', '法宝', '真气',
        '称号传承光耀', '临时增益光环', '元素', '天启篇规则（档位／烙印／境／种族／常驻）', '新发现']
CAT_PREFIX = [('角色白板', '角色白板'), ('角色技能', '被动心法'), ('装备底子', '装备底子'), ('装备本体', '固定词条'), ('随机词条', '随机词条'),
              ('套装', '套装'), ('宝珠', '宝石宝珠'), ('宝石', '宝石宝珠'), ('符石', '符石'), ('符文', '符石'), ('秘籍', '技能书秘籍'), ('通用书', '技能书秘籍'),
              ('法宝', '法宝'), ('真气', '真气'), ('种族', '天启篇规则（档位／烙印／境／种族／常驻）'), ('档位', '天启篇规则（档位／烙印／境／种族／常驻）'),
              ('烙印', '天启篇规则（档位／烙印／境／种族／常驻）'), ('境', '天启篇规则（档位／烙印／境／种族／常驻）'), ('天启篇常驻', '天启篇规则（档位／烙印／境／种族／常驻）')]
EXPAND_RATE = 0.10
DIFF_CN = dict(xunchang='寻常', jianxian='艰险', jiusi='九死', lianyu='炼狱', zhengdao='证道')


def cat_of(name):
    if '｜' in name:
        c = name.split('｜', 1)[0]
        return c if c in CATS else '新发现'
    for pre, c in CAT_PREFIX:
        if name.startswith(pre):
            return c
    return '新发现'


SINGLE_ROWS = ('（单件', '（单条', '（单颗', '（单套')


def cat_table(ctab):
    """属性 → [「大类：上限／常见值（份额）标记」…]；相乘属性按对数倍率算份额（口径 9），同一大类多行取上限最大"""
    out = {}
    for attr, (rows_, gear, gear_raw) in ctab.items():
        best = {}
        for nm, v, share, mark in rows_:
            if any(x in nm for x in SINGLE_ROWS):
                continue
            c = cat_of(nm)
            if c not in best or abs(v[0]) > abs(best[c][0][0]):
                best[c] = (v, mark)
        tot_w = sum(_share_weight(attr, v[0]) for v, _ in best.values())
        cells = []
        for c, (v, mark) in sorted(best.items(), key=lambda kv: -_share_weight(attr, kv[1][0][0])):
            w = _share_weight(attr, v[0])
            others = [_share_weight(attr, x[0][0]) for k, x in best.items() if k != c]
            tag = '⬆' if mark else ('⬇' if others and w < 0.5 * med(others) else '')
            cells.append(f"{c}：{fmt(v[0])}／{fmt(v[1])}（{w / tot_w * 100:.0f}%）{tag}" if tot_w else f'{c}：{fmt(v[0])}')
        out[attr] = cells
    return out


# ---------------- 口径 11：改写表漏项检查（复用 T524 03_转换工具/天启篇漏项扫描.py） ----------------
def sec_leak_scan(D):
    tool_dir = str(GODOT / '03_转换工具')
    if tool_dir not in sys.path:
        sys.path.insert(0, tool_dir)
    try:
        import 天启篇漏项扫描 as LS
        rw_eff = LS.load_effective_skill_rework()
        skills = {i: r for i, r in enumerate(D.S) if r}
        weapons = {i: r for i, r in enumerate(D.W) if r}
        armors = {i: r for i, r in enumerate(D.A) if r}
        states = {i: r for i, r in enumerate(D.ST) if r}
        items = {i: r for i, r in enumerate(D.I) if r}
        ces = {i: r for i, r in enumerate(D.CE) if r}
        troops = {i: r for i, r in enumerate(D.T) if r}
        maps = LS.load_maps()
        res_a = LS.scan_class_a(rw_eff, D.gbk, skills, weapons, armors, states, 50.0)
        res_b = LS.scan_class_b(rw_eff, D.gbk, skills, items, weapons, armors, states, ces, troops, maps)
        unexempt_a = [r for r in res_a.get('residuals', []) if not r.get('exempt') and r.get('category') == 'residual']
        return {
            'ok': True,
            'A_总残留': len(res_a.get('residuals', [])),
            'A_未豁免': len(unexempt_a),
            'A_双标签冲突': len(res_a.get('duplicates', [])),
            'A_未豁免前10': unexempt_a[:10],
            'A_双标签前10': res_a.get('duplicates', [])[:10],
            'B_可达未改写组': res_b.get('group_count', 0),
            'B_可达高危组': res_b.get('high_risk_groups', 0),
            'B_人工核对': res_b.get('manual_count', 0),
            'B_人工高危': res_b.get('manual_high_risk', 0),
            'B_动态CE调用': len(res_b.get('dynamic_ce_calls') or []),
            'B_已证实删掉': res_b.get('dropped_count', 0),
        }
    except Exception as exc:
        return {'ok': False, 'error': str(exc)}


# ---------------- 口径 17：已知事实对照（锚点覆盖与缺口显式列出） ----------------
D209_SUPER_RANK = [
    '渡鸦', '米拉', '拳一', '饿狼', '宿傩', '奈叶', '五条悟', '徐凤年', '南宫恨·狂刀',
    '黄泉', '伊莉雅', '镜流', '屠苏', '黑崎一护', '钟离', '流萤', '伏黑甚尔', '轮回者·里德',
]


def sec_known_facts(D, missing_peak, not_open):
    ms = D.meas['actors']
    tier_of = actor_tiers(D)
    by_name = {a.get('name', ''): (aid, a) for aid, a in D.sd['actors'].items()}
    rows = []
    gaps = []
    # 1. D209 名次榜 18 人覆盖核对
    d209_ok, d209_miss = [], []
    for nm in D209_SUPER_RANK:
        hit = by_name.get(nm)
        if not hit:
            # 模糊匹配（如 轮回者·里德 vs 里德）
            cand = [k for k in by_name if nm in k or k in nm]
            d209_miss.append(f"{nm}（不在 six_dim 名单；相近名：{','.join(cand) or '无'}）")
            gaps.append(f"D209 锚点「{nm}」不在 six_dim.json 超强者名单，无法直接核对峰值")
        else:
            aid, a = hit
            m = ms.get(aid, {})
            if m.get('peak'):
                d209_ok.append((nm, aid, tier_of.get(aid), float(m['peak'])))
            else:
                d209_miss.append(f"{nm}（{aid}，无 peak：{'停用' if m.get('disabled') else '探针无出伤行'}）")
                gaps.append(f"D209 锚点「{nm}（{aid}）」在 six_dim 里但无实测 peak")
    rows.append({'锚点': 'D209 超强者名次榜（18 人）', '状态': f'覆盖 {len(d209_ok)}/18，缺 {len(d209_miss)}',
                 '说明': '缺失：' + ('；'.join(d209_miss) if d209_miss else '无')})

    # 2. D148 三档峰值与 D287 3.5× 硬线
    tier_peaks = defaultdict(list)
    for aid, a in D.sd['actors'].items():
        t = tier_of.get(aid)
        pk = ms.get(aid, {}).get('peak')
        if t and pk:
            tier_peaks[t].append((float(pk), a.get('name', aid), aid))
    parts = []
    for t in ('超强者', '强者', '弱者'):
        ps = tier_peaks.get(t, [])
        if ps:
            hi = max(ps)
            parts.append(f'{t} 最高 {fmt(hi[0])}（{hi[1]}）／中位 {fmt(med([x[0] for x in ps]))}')
    ratio_sw = (med([x[0] for x in tier_peaks['超强者']]) / med([x[0] for x in tier_peaks['弱者']])) if tier_peaks['超强者'] and tier_peaks['弱者'] else None
    ratio_sw_top = (max(tier_peaks['超强者'])[0] / max(tier_peaks['弱者'])[0]) if tier_peaks['超强者'] and tier_peaks['弱者'] else None
    rows.append({'锚点': 'D148 三档峰值／D287 超÷弱 ≤3.5×', '状态': f"最高比 ×{fmt(ratio_sw_top)}／中位比 ×{fmt(ratio_sw)}",
                 '说明': '；'.join(parts) + '（注：弱者中位含辅助拉低，D287 3.5× 硬线应看养满输出手，交 N04 复量）'})

    # 3. 未量到角色名单
    rows.append({'锚点': '未量到 peak 角色（six_dim 内）', '状态': f'{len(missing_peak)} 人单列',
                 '说明': '；'.join(f"{x['名']}({x['号']}·{x['档位']}:{x['原因']})" for x in missing_peak) or '无'})
    rows.append({'锚点': '启封不开放角色（tiers.不开放）', '状态': f'{len(not_open)} 人',
                 '说明': '、'.join(f"{x['名']}({x['号']})" for x in not_open) or '无'})

    # 4. 整场战斗级已知事实（显式写进覆盖缺口）
    rows.append({'锚点': '「洪荒只有非天、五河能通」（原版西游档整场结论）', '状态': '覆盖缺口（静态横截面量不到）',
                 '说明': '属西游档整场多回合战斗结论，本脚本只量单招／单件／单来源横截面；启封锚点改用 D209／D148'})
    gaps.append('整场战斗级结论（如「洪荒只有非天、五河能通」）超出静态横截面脚本覆盖范围，需由战斗脚手架实跑核验')
    return rows, gaps


# ---------------- 口径 26：守层者 D273 四栏对账（静态规则＋仓内归档）与疑点核查 ----------------
def sec_guardian_d273(D):
    cr = D.bt.get('combat_rules', {})
    cap_pct = cr.get('boss_neg_hrg_cap_pct', 5)
    cap_states = cr.get('boss_neg_hrg_cap_extdot_states', [243, 261])
    four_cols = [
        ('行动里打的', '直伤＋判决等直接扣血（含目标生命比例招，进锚另标跟不跟开场血变）', '实际掉血 ÷ 结算时最大生命'),
        ('5% 预算内回合末掉血', f'守层者／首领负再生（净负写回）＋ 表内 extdot 状态 {cap_states}，每回合合计封 ≤{cap_pct}%', '实际掉血 ÷ 结算时最大生命（成长招 1.36× 时折开场血最高 6.8%，按结算最大生命 ≤5.00%）'),
        ('预算外回合末掉血', '非表内 extdot、元素效果灼烧／寄生（各每跳上限 5% 挂上时 mhp）、叠毒（state_regen）、疫（post_qiyin）', '实际掉血 ÷ 结算时最大生命'),
        ('首领回的血', '正再生（净正写回）＋ 技能回血招（不封顶）', '实际回血 ÷ 结算时最大生命'),
    ]

    # 解析仓内 T405 归档（D273 开态 cap_*.json；剔除 aborted 事件中止场）
    t405_dir = REPO / '00_项目管理/归档/交付截图/luiluu_t405/T405_量数'
    t405_rows = []
    if t405_dir.exists():
        for p in sorted(t405_dir.glob('cap_*.json')):
            try:
                d = load(p)
            except OSError:
                continue
            if not d.get('bossNegHrgCap'):
                continue
            for row in d.get('rows', []):
                per = [x for x in row.get('per', []) if not x.get('aborted')]
                aborted_n = len(row.get('per', [])) - len(per)
                if not per:
                    continue
                wins = [x for x in per if x.get('won')]
                win_turns = [x['turns'] for x in wins if x.get('turns') is not None]
                all_turns = [x['turns'] for x in per if x.get('turns') is not None]
                # 旧 T405 归档只有 dmg（行动直伤/回合）和 endTurnDmg（回合末合计/回合），尚未细拆预算内外与回血
                dmg_m = med([x.get('dmg', 0) for x in per])
                et_m = med([x.get('endTurnDmg', 0) for x in per])
                hp0 = float(row.get('enemyHp') or 0)
                t405_rows.append({
                    '文件': p.name, '难度': d.get('forceDifficulty'), '层': row.get('floor'),
                    '有效场': len(per), '剔除中止': aborted_n, '胜率%': round(len(wins) / len(per) * 100, 1),
                    '赢回合中位': med(win_turns) if win_turns else None, '全回合中位': med(all_turns) if all_turns else None,
                    '行动直伤/回': dmg_m, '回合末合计/回': et_m,
                    '回合末占开场血%': round(et_m / hp0 * 100, 2) if hp0 else None,
                    '四栏状态': 'T405 旧归档只含直伤/回合末两栏，四栏拆账见 T456 实测(22/29层)与待办 N15',
                })

    # 解析仓内 T501 归档（K=0.5 血40%，31～36 层，按模板×层，剔除 aborted）
    t501_dir = REPO / '00_项目管理/归档/交付截图/luiluu_t501/T501_量数/胜率_K0.5_血40'
    t501_rows = []
    if t501_dir.exists():
        for p in sorted(t501_dir.glob('[A-D]_*.json')):
            try:
                d = load(p)
            except OSError:
                continue
            for tkey, tval in (d.get('templates') or {}).items():
                for fl, fval in (tval.get('floors') or {}).items():
                    raw_cases = fval.get('cases', [])
                    cases = [x for x in raw_cases if not x.get('aborted')]
                    aborted_n = len(raw_cases) - len(cases)
                    if not cases:
                        continue
                    wins = [x for x in cases if x.get('won')]
                    wt = [x['turns'] for x in wins if x.get('turns') is not None]
                    t501_rows.append({
                        '模板': tkey, '难度': tval.get('difficulty'), '层': int(fl),
                        '胜': len(wins), '有效场': len(cases), '剔除中止': aborted_n,
                        '胜率%': round(len(wins) / len(cases) * 100, 1),
                        '赢回合中位': med(wt) if wt else None,
                    })

    # 后续已结疑点核查（防引用过时疑点）
    doubts = [
        ('T392 22／29 层血量偏厚疑点', '已查完（T405／T456）', '灼伤封顶至 5% 后 22／29 层未回调血量（29 层艰险强队 8.2→14.0 回合、22 层胜率 6/6→1/6）；T456 拆账证实 5.40%～5.46% 中 98%+ 来自成长招抬 mhp（1.12×/1.36×）分母差，按结算时 mhp ≤5.000%，叠毒 498 仅 0.008%。回调归 N01（T525）'),
        ('T524 止血三项（艾瑞塔／破限之心星空／维利）', '已合 main（dev.934）', '艾瑞塔旧标签、破限之心·星空 999、维利旧项已在 T524 修复，本报告按 main 最新数据重跑核验'),
        ('1～27 层除 22 层外实测、28～30 层出伤、30～33 层敏捷', '没核（待 T450）', '尚无仓内实测归档；28～30 出伤指数无实测、30～33 敏捷折算未核，标「没核」交怪物重标卡 T450'),
        ('D273 四栏逐状态／逐只实时拆账（含预算外灼烧／寄生／疫）', '部分已核（T456 仅 22/29 层），全层待 N15', '仓内 T405／T501 归档未含四栏细目，全层四栏记账工具归 N15 落地'),
    ]
    return {'cap_pct': cap_pct, 'cap_states': cap_states, 'four_cols': four_cols,
            't405': t405_rows, 't501': t501_rows, 'doubts': doubts}


def sec_cross_extra(D, src, nine):
    """并入固定值两项（75 级）：角色白板 vs 装备底子整身 vs 法宝底子，再判"""
    lv = max(x[1] for x in D.dt['generic']['level_by_floor'])
    conv = 1 + lv * 98 / 90
    grades = D.gb['grades']
    top_g = QKEYS[D.dt['generic']['top_grade']]
    tier_of = actor_tiers(D)
    for attr, st, col in (('攻击(固定值·75级)', 'atk', 'atk'), ('生命(固定值·75级)', 'mhp', 'hp')):
        vals = [(int(D.line(lv, st) * actor_mult(D, aid, st)), aid) for aid in tier_of if str(aid) in D.bl['actors']]
        top = max(vals)
        src.setdefault('角色白板（75 级本体）', {})[attr] = (top[0], med([v for v, _ in vals]), f"{D.bl['actors'][str(top[1])]['name']}（{top[1]}）", 'base_line 标准线×职责×速度×微调')
        ksum = sum(sl.get(col, 0) for et, sl in D.slots.items())
        src.setdefault('装备底子（整身，75 级）', {})[attr] = (D.line(conv, st) * ksum * grades[top_g], D.line(conv, st) * ksum * grades['jingliang'],
                                                       f'部位系数和 {ksum:g}×{GN[D.dt["generic"]["top_grade"]]} {grades[top_g]}', '常见值按精良 1.0')
        fb = D.gb['fabao']
        eq = min(99, 99) * fb['equip_level_at_full'] / fb['full_level']
        fconv = 1 + eq * 98 / 90
        share = fb['share'].get('hp' if st == 'mhp' else 'atk', 0)
        src.setdefault('法宝底子（满级）', {})[attr] = (D.line(fconv, st) * share * grades[top_g], D.line(fconv, st) * share * grades['jingliang'],
                                                 f'share {share}×品质', 'gear_base.fabao：满级＝半件 80 级装备')
    return cross_judge(src, nine)


# ---------------- 报告 ----------------
def build(D, diff):
    L = []
    allouts = []
    # 装备（口径 10：含招牌掉落池）
    pool, skipped, sig_pool, base_g, aff_g, dist, noformula, unreach, aff_count, lv_cap = sec_gear(D)
    bm, bo, bs = outliers(base_g, '装备底子')
    am, ao, as_ = outliers(aff_g, '固定词条')
    # 随机词条
    rg, steps = sec_affix(D)
    rm, ro, rs = outliers(rg, '随机词条')
    # 技能（口径 7：按档位 × 输出评级；单列没量到的人）
    sg, tier_of, missing_peak, not_open = sec_skill(D)
    skill_res = {k: outliers(v, '技能·' + k) for k, v in sg.items()}
    # 怪物（口径 6／13／18／24／25：真实路径取整、首领/精英/小怪×五档分开、命中类型占比）
    erows, curves_by_cat, jumps_by_cat, jumps_5diff, single_digit_mobs, hit_floors, hit_summary, knights, shadow, maps_used, turns = sec_enemy(D, diff)
    # 类内离群按「层·类」分开判（不把首领与小怪混在一层判离群；守层者标 D248 实测表不计离群）
    egroups = {k: defaultdict(list) for k in ['生命', '出伤指数', '物防', '魔防', '敏捷']}
    for f, rs_ in erows.items():
        for r in rs_:
            if r['类'] == '首领':
                continue  # 口径 24：守层者另标「D248 实测表」，不计入离群数
            for k in egroups:
                egroups[k][f"{f}层·{r['类']}"].append((f"{r['名']}（{r['号']}·{r['来源']}）", float(r[k]), r['路径']))
    eres = {k: outliers(v, '怪物·' + k) for k, v in egroups.items()}
    # 跳幅：首领（D248 实测表）只当参考不计入离群，精英／小怪计入跳幅告警
    jumps_non_boss = jumps_by_cat['精英'] + jumps_by_cat['小怪']
    jumps_boss_ref = jumps_by_cat['首领']

    # 逐招系数（口径 8）、跨来源（口径 1～5／9／10／15／19／20／22）
    kr, kg = sec_skillcoef(D)
    km, ko, ks = outliers(kg, '技能系数')
    src, nine, body, per_actor = sec_cross(D, pool, sig_pool, actor_tiers(D))
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

    # 改写表漏项（口径 11）、已知事实对照（口径 17）、守层者 D273 四栏与疑点核查（口径 26）
    leaks = sec_leak_scan(D)
    known_rows, known_gaps = sec_known_facts(D, missing_peak, not_open)
    d273 = sec_guardian_d273(D)

    ranked = sorted([o for o in allouts if o['倍数'] is not None], key=sev, reverse=True)
    zero_med = [o for o in allouts if o['倍数'] is None]

    # ---- 白板 ----
    wrows, wg = sec_white(D)
    wm, wo, ws = outliers(wg, '角色白板')

    # ---- 类内一行汇总：每个大类的条数、离群数、离群率、跨来源标记 → 决定第二层展开谁 ----
    cross_by_cat = defaultdict(list)
    for f in cflags:
        cross_by_cat[cat_of(f['来源'])].append(f)
    so = [o for _, o, _ in skill_res.values() for o in o]
    eo = sorted([o for _, o, _ in eres.values() for o in o], key=sev, reverse=True)
    n_enemy_total = sum(len(rs_) for rs_ in erows.values())
    inner = [  # (大类, 比的单位, 条数, 离群列表, 额外问题数, 额外说明)
        ('角色白板', '档位·属性（99 级）', sum(v[0] for v in wm.values()), wo, 0, '本体＝标准线×职责×速度×微调，档位不影响白板'),
        ('被动心法', '跨来源（角色桶·同功法单层）', len(per_actor), [], 0, '见跨来源总表'),
        ('技能（六维强度）', '档位·输出评级', sum(v[0] for m_, _, _ in skill_res.values() for v in m_.values()), so, len(missing_peak), f'未量到 {len(missing_peak)} 人'),
        ('技能系数（逐招伤害）', '档位·类别（一场一次单列）', len(kr), ko, 0, '冷却≥99 按一场一次算'),
        ('技能全系数', '字段路径', n_fields, co, 0, '卡里全部数值字段'),
        ('装备底子', '等级段·品质·部位', sum(v[0] for v in bm.values()), bo, len(noformula), f'{len(noformula)} 件不读新表照原版'),
        ('固定词条', '等级段·品质（含招牌池）', len(pool), ao, 0, f'原版必出行 {sum(v[1] for v in aff_count.values())} 件；招牌池 {len(sig_pool)} 件'),
        ('随机词条', '层·单位·阶·成色', sum(v[0] for v in rm.values()), ro, len(steps), f'阶间跳幅超 ×{HI:g} {len(steps)} 条'),
        ('怪物', '层·类（精英／小怪；首领 D248 参考）', n_enemy_total, eo, len(jumps_non_boss),
         f'精英/小怪跳幅 {len(jumps_non_boss)} 处（首领 D248 参考 {len(jumps_boss_ref)} 处不计离群）'),
    ]
    expand = {}
    for cat, unit, n, outs, extra, note in inner:
        rate = len(outs) / n if n else 0
        flag = []
        if rate >= EXPAND_RATE:
            flag.append(f'离群率 {rate * 100:.0f}%')
        if extra:
            flag.append(note)
        if cross_by_cat.get(cat):
            flag.append('跨来源偏高')
        expand[cat] = (unit, n, outs, rate, flag, note)
    for cat in cross_by_cat:
        if cat not in expand:
            expand[cat] = ('跨来源', None, [], 0, ['跨来源偏高'], '见跨来源总表')

    L.append('# 启封数值总对账报告（T520／T535 修 26 处口径）')
    L.append('')
    L.append(f'由 `03_再刷重制_Godot/07_开发环境/启封数值对账.py --write` 生成，只读游戏数据；全量明细 `--json <文件>`。离群＝同档内 >中位数×{HI:g} 或 <中位数×{LO:g}（档内不足 3 条不判）。主表怪物生命按「{DIFF_CN[diff]}」目标回合 {turns} 算（另附五档×三类跳幅总表）。只摆数和倍数，不判断是不是有意为之。')
    L.append('')
    L.append('两层：第一层先按来源大类看整体（总表＋类内汇总＋已知事实对照＋改写表漏项），标出偏高偏低的大类；第二层只展开被标出的大类。没标出的大类只有一行汇总，明细在 --json。')
    L.append('')
    L.append('## 第一层·结论')
    L.append('')
    L.append('### 1. 跨来源总表（大类 × 属性，启封满级档）')
    L.append('')
    L.append('每格＝这一大类在这项属性上的上限／常见值，份额＝上限占同属性各大类合计（相乘属性「攻击%／生命%／承伤%」按对数倍率 `|ln(1+v/100)|` 算份额，不线性相加）。装备类已套天启篇改写（skill_rework.gear、T451 元素增幅重调、12 把系别法宝改写、含招牌掉落池），合计还要过九线封顶（①15%、②每系30%、③35%、④暴伤30%[phase4已开]、属性30%）；宝珠属性按已封 +30% 算；随机词条按合法栏位（攻4／防8／通10、同件不重名、特效每件≤2、不朽神话3格）算；角色被动同一功法只取最高一层；种族按族按属性分行。⬆＝单一大类上限压过装备整身（九线封顶后）或超过其余大类合计；⬇＝不到其余中位数一半。固定值按 75 级算。')
    L.append('')
    L.append('| 属性（乘区；叠法） | 大类：上限／常见值（份额）标记 |')
    L.append('|---|---|')
    for attr, cells in cat_table(ctab).items():
        pz = ATTR.get(attr, (attr, '单独'))
        L.append(f'| {attr}（{pz[0]}；{pz[1]}） | ' + '；'.join(cells) + ' |')
    L.append('')
    L.append('### 2. 偏高明细（单一来源压过装备／超过其余合计）')
    L.append('')
    L.append('| 属性 | 大类·来源 | 上限 | 谁 | 装备整身（封顶后／未封） | 其余合计 | 标记 |')
    L.append('|---|---|---|---|---|---|---|')
    for f in sorted(cflags, key=lambda f: -abs(f['上限']) / max(1e-9, f['装备整身'] or 1)):
        L.append(f"| {f['属性']} | {f['来源']} | {fmt(f['上限'])} | {f['谁']} | {fmt(f['装备整身'])}／{fmt(f['装备整身未封'])} | {fmt(f['其余合计'])} | {f['标记']} |")
    L.append('')
    L.append('### 3. 类内一行汇总（决定第二层展开谁）')
    L.append('')
    L.append(f'展开条件：离群率 ≥{EXPAND_RATE * 100:.0f}%、有跳幅／不读表／缺样这类结构问题、或跨来源偏高。')
    L.append('')
    L.append('| 大类 | 比的单位 | 条数 | 离群 | 离群率 | 标记 | 第二层 |')
    L.append('|---|---|---|---|---|---|---|')
    for cat, (unit, n, outs, rate, flag, note) in expand.items():
        L.append(f"| {cat} | {unit} | {'—' if n is None else n} | {len(outs)} | {rate * 100:.0f}% | {'、'.join(flag) or '—'} | {'展开' if flag else '不展开'} |")
    L.append('')
    L.append('### 4. 技能系数离群前 20（逐招每回合期望倍率；一场一次单列）')
    L.append('')
    L.append('每回合期望＝系数×属性权重（生命魔法折 ×25）×段数÷每几回合一次（冷却＋1）；冷却 ≥99 是一场一次，不除以 100，单独归入「档位·一场一次」比单次总倍率。')
    L.append('')
    L.append('| 招·角色 | 档位·类别 | 每回合期望/单次 | 组中位 | 倍数 | 算法 |')
    L.append('|---|---|---|---|---|---|')
    for o in sorted(ko, key=sev, reverse=True)[:20]:
        L.append(f"| {o['名']} | {o['档']} | {fmt(o['值'])} | {fmt(o['中位数'])} | ×{fmt(o['倍数'])} | {o['备注'][:65]} |")
    L.append('')
    L.append('### 5. 怪物跳层汇总（首领／精英／小怪 × 天启篇五档，1～34 层）')
    L.append('')
    L.append('按游戏真实路径复算并取整（`guardian_rework.gd:402-416` `_world` 含难度倍率、去 ×6、仓库倍率 ×2、敌人生命比例 40% 及逐阶取整）；**首领（守层者＋34层鸿钧）另标「D248 实测表」，跳幅只作参考、不计入离群数**；精英与小怪分开建曲线、不混成一个层中位数。')
    L.append('')
    L.append('| 难度（目标回合） | 首领·D248参考（1～27／全1～34） | 精英跳幅（1～27／全） | 小怪跳幅（1～27／全） | 精英＋小怪合计（1～27） |')
    L.append('|---|---|---|---|---|')
    for dk in DIFF_KEYS:
        jb = jumps_5diff[dk]['首领']
        je = jumps_5diff[dk]['精英']
        jm = jumps_5diff[dk]['小怪']
        jb27 = [j for j in jb if j[1] <= 27]
        je27 = [j for j in je if j[1] <= 27]
        jm27 = [j for j in jm if j[1] <= 27]
        L.append(f"| {DIFF_CN[dk]}（{DIFF_TURNS[dk]}回） | {len(jb27)}／{len(jb)} | {len(je27)}／{len(je)} | {len(jm27)}／{len(jm)} | {len(je27) + len(jm27)} |")
    L.append('')
    L.append(f'精英／小怪跳层前 20（{DIFF_CN[diff]}档，首领 D248 实测表单列于第二层参考）：')
    L.append('')
    L.append('| 类 | 层→层 | 项 | 前层中位 | 后层中位 | 倍数 |')
    L.append('|---|---|---|---|---|---|')
    for a_, b_, cat_, k, x, y, q in sorted(jumps_non_boss, key=lambda j: -max(j[6], 1 / j[6]))[:20]:
        L.append(f'| {cat_} | {a_}→{b_} | {k} | {fmt(x)} | {fmt(y)} | ×{fmt(q)} |')
    L.append('')
    L.append('### 6. 已知事实对照（口径 17：锚点覆盖与缺口）')
    L.append('')
    L.append('| 已知事实／锚点 | 覆盖状态 | 说明 |')
    L.append('|---|---|---|')
    for r in known_rows:
        L.append(f"| {r['锚点']} | {r['状态']} | {r['说明']} |")
    L.append('')
    L.append('### 7. 改写表漏项检查（口径 11，复用 T524 `03_转换工具/天启篇漏项扫描.py`）')
    L.append('')
    if leaks.get('ok'):
        L.append(f"- **A 类（改写后残留旧加成标签 ≥50%）**：总计 {leaks['A_总残留']} 处，其中**未豁免 {leaks['A_未豁免']} 处**，双标签冲突 **{leaks['A_双标签冲突']} 处**。")
        L.append(f"- **B 类（经公共事件学到的未改写技能）**：可达未改写组 **{leaks['B_可达未改写组']}**（高危 **{leaks['B_可达高危组']}**）、人工核对 **{leaks['B_人工核对']}**（高危 **{leaks['B_人工高危']}**）、动态 CE 调用 {leaks['B_动态CE调用']}、已证实删掉 {leaks['B_已证实删掉']}。")
        if leaks['A_未豁免前10']:
            L.append('')
            L.append('| 来源 | 节 | 编号 | 名 | 标签 | 值 | 分类 |')
            L.append('|---|---|---|---|---|---|---|')
            for r in leaks['A_未豁免前10']:
                L.append(f"| {r.get('source')} | {r.get('section')} | {r.get('id')} | {r.get('name')} | {r.get('tag')} | {r.get('value')} | {r.get('category')} |")
    else:
        L.append(f"漏项扫描未运行：{leaks.get('error')}")
    L.append('')

    # ---- 第二层 ----
    L.append('## 第二层·被标出大类的明细')
    L.append('')
    sec_no = 0
    for cat, (unit, n, outs, rate, flag, note) in expand.items():
        if not flag:
            continue
        sec_no += 1
        L.append(f'### {sec_no}. {cat}（{"、".join(flag)}）')
        L.append('')
        if cat == '技能（六维强度）':
            L.append(f'没量到峰值的角色（{len(missing_peak)} 人，不沉默省略）：' +
                     ('；'.join(f"{x['名']}（{x['号']}·{x['档位']}·输出{x['输出评级']}：{x['原因']}）" for x in missing_peak) or '无'))
            L.append('')
        if cat == '怪物':
            for ecat in ENEMY_CATS:
                cv = curves_by_cat[ecat]
                tag_ec = '（D248 实测表，跳幅只作参考不计离群）' if ecat == '首领' else '（`_world` 真实路径复算并取整）'
                L.append(f'**{ecat}曲线**{tag_ec}（{DIFF_CN[diff]}档，全局生命比例 {D.bt["combat_rules"]["enemy_hp_pct"]}%）：')
                L.append('')
                L.append('| 层 | 只数 | 生命(整) | 出伤指数 | 物防 | 魔防 | 敏捷 | hp_base | atk_scale |')
                L.append('|---|---|---|---|---|---|---|---|---|')
                for c in cv:
                    L.append(f"| {c['层']} | {c['只数']} | {fmt(c['生命'])} | {fmt(c['出伤指数'])} | {fmt(c['物防'])} | {fmt(c['魔防'])} | {fmt(c['敏捷'])} | {fmt(c['hp_base'])} | {fmt(c['atk_scale'], 4)} |")
                L.append('')
            L.append(f'经核 `_world` 实路径血量仍为个位数（<10）的遇敌怪共 **{len(single_digit_mobs)}** 只（根因：`guardian_rework.gd:402-416` 用本层原版守层者天量总血 `old_total` 同比缩，导致常态小怪在实机里确实为个位数，待 T450 小怪改锚）：' +
                     '；'.join(f"{x['层']}层 {x['名']}={x['实算血']}(神话{x['神话血']})" for x in single_digit_mobs[:15]) + ('…' if len(single_digit_mobs) > 15 else ''))
            L.append('')
            L.append('**首领（D248 实测表）相邻层跳幅参考**（不计入离群数）：' +
                     ('；'.join(f"{a_}→{b_} {k} {fmt(x)}→{fmt(y)}(×{fmt(q)})" for a_, b_, _, k, x, y, q in jumps_boss_ref) or '无'))
            L.append('')
            L.append(f"**敌人伤害招命中类型占比（口径 18，1～34 层汇总）**：共 {hit_summary['伤害招人次(去重按层)']} 招次——物理 {hit_summary['物理']}（{hit_summary['物理%']}%）、魔法 {hit_summary['魔法']}（{hit_summary['魔法%']}%）、**必中 {hit_summary['必中']}（{hit_summary['必中%']}%）**。")
            L.append('')
            L.append('| 层 | 伤害招 | 物理(%) | 魔法(%) | 必中(%) | 层 | 伤害招 | 物理(%) | 魔法(%) | 必中(%) |')
            L.append('|---|---|---|---|---|---|---|---|---|---|')
            half = (len(hit_floors) + 1) // 2
            for idx in range(half):
                a_r = hit_floors[idx]
                b_r = hit_floors[idx + half] if idx + half < len(hit_floors) else None
                left = f"| {a_r['层']} | {a_r['伤害招数']} | {a_r['物理']}({a_r['物理%']}%) | {a_r['魔法']}({a_r['魔法%']}%) | {a_r['必中']}({a_r['必中%']}%) "
                right = f"| {b_r['层']} | {b_r['伤害招数']} | {b_r['物理']}({b_r['物理%']}%) | {b_r['魔法']}({b_r['魔法%']}%) | {b_r['必中']}({b_r['必中%']}%) |" if b_r else '| — | — | — | — | — |'
                L.append(left + right)
            L.append('')
            L.append('35／36 层（horsemen.json，艰险基准）：' + '；'.join(f"{k['名']} 生命 {fmt(k['生命'])}、攻击 {fmt(k['攻击'])}、防御 {fmt(k['防御'])}" for k in knights) + f"；35 层影子生命 {fmt(shadow.get('hp'))}。")
            L.append('')
        if cat == '装备底子' and noformula:
            L.append(f'不读新表、照原版八项的通用池装备（{len(noformula)} 件）：' + '；'.join(f'{nm}〔{k}，份数 {fmt(v)}〕' for nm, k, v, _ in noformula))
            L.append('')
        if cat == '随机词条' and steps:
            L.append('阶间跳幅（普通成色，一阶→四阶）：' + '；'.join(f'{nm}〔{"/".join(fmt(float(x)) for x in sq)}〕' for nm, _, _, sq in steps))
            L.append('')
        if cross_by_cat.get(cat):
            L.append('跨来源偏高：' + '；'.join(f"{f['属性']} {f['来源']} {fmt(f['上限'])}（{f['谁']}，{f['标记']}）" for f in cross_by_cat[cat]))
            L.append('')
        if outs:
            L.append(f'类内离群前 20（共 {len(outs)} 条）：')
            L.append('')
            L.append('| 名 | 档 | 值 | 档中位 | 倍数 | 备注 |')
            L.append('|---|---|---|---|---|---|')
            for o in sorted(outs, key=sev, reverse=True)[:20]:
                L.append(f"| {o['名']} | {o['档']} | {fmt(o['值'])} | {fmt(o['中位数'])} | {'—' if o['倍数'] is None else '×' + fmt(o['倍数'])} | {str(o['备注'])[:60]} |")
            L.append('')
    if not sec_no:
        L.append('（没有被标出的大类）')
        L.append('')

    # ---- 口径 26：守层者 D273 四栏对账与疑点核查 ----
    L.append('## 第三层·守层者 D273 四栏对账与已结疑点核查（口径 26）')
    L.append('')
    L.append(f"守层者那一场对账必须在 **D273 开启**（`boss_neg_hrg_cap_pct = {d273['cap_pct']}%`，预算内 extdot 状态 `{d273['cap_states']}`）的规则下做；掉血分四栏，**占比分母一律用结算那一刻的最大生命**：")
    L.append('')
    L.append('| 四栏 | 归属来源 | 占比分母口径 |')
    L.append('|---|---|---|')
    for col_n, col_src, col_den in d273['four_cols']:
        L.append(f'| {col_n} | {col_src} | {col_den} |')
    L.append('')
    if d273['t405']:
        L.append('**仓内 T405 归档（D273 开态 `cap_*.json`，剔除事件中止场）**：')
        L.append('')
        L.append('| 文件 | 难度 | 层 | 有效场(剔除中止) | 胜率 | 赢回合中位 | 行动直伤/回 | 回合末合计/回（占开场血） | 四栏备注 |')
        L.append('|---|---|---|---|---|---|---|---|---|')
        for r in d273['t405']:
            L.append(f"| {r['文件']} | {r['难度']} | {r['层']} | {r['有效场']}({r['剔除中止']}) | {r['胜率%']}% | {fmt(r['赢回合中位'])} | {fmt(r['行动直伤/回'])} | {fmt(r['回合末合计/回'])}（{r['回合末占开场血%']}%） | {r['四栏状态']} |")
        L.append('')
    if d273['t501']:
        L.append('**仓内 T501 归档（K=0.5 血 40%，31～36 层按模板×层，剔除事件中止场）**：')
        L.append('')
        L.append('| 模板 | 难度 | 层 | 胜／有效场(剔除中止) | 胜率 | 赢回合中位 |')
        L.append('|---|---|---|---|---|---|')
        for r in sorted(d273['t501'], key=lambda x: (x['层'], x['模板'])):
            L.append(f"| {r['模板']} | {r['难度']} | {r['层']} | {r['胜']}／{r['有效场']}({r['剔除中止']}) | {r['胜率%']}% | {fmt(r['赢回合中位'])} |")
        L.append('')
    L.append('**后续已结疑点核查（防止引用已查清的旧卡疑点）**：')
    L.append('')
    L.append('| 疑点 | 当前状态 | 核查结论 |')
    L.append('|---|---|---|')
    for title, st_, desc_ in d273['doubts']:
        L.append(f'| {title} | {st_} | {desc_} |')
    L.append('')

    # ---- 附录 ----
    L.append('## 附录')
    L.append('')
    L.append('### A. 跨来源逐来源表（第一层总表的来源拆细）')
    L.append('')
    L.append('| 属性 | 大类 | 来源 | 上限 | 常见值 | 谁 | 份额 | 说明 |')
    L.append('|---|---|---|---|---|---|---|---|')
    for attr, (rows_, gear, gear_raw) in ctab.items():
        for nm, v, share, mark in sorted(rows_, key=lambda x: -abs(x[1][0])):
            L.append(f"| {attr} | {cat_of(nm)} | {nm} | {fmt(v[0])} | {fmt(v[1])} | {v[2]} | {'—' if share is None else f'{share * 100:.0f}%'} | {v[3]}{('；' + '、'.join(mark)) if mark else ''} |")
    L.append('')
    L.append('### B. 角色白板（每档位中位，1／30／60／99 级）')
    L.append('')
    L.append('| 档位 | 人数 | ' + ' | '.join(SN[st] for st in STATS) + ' |')
    L.append('|---|---|' + '---|' * len(STATS))
    for t in ['弱者', '强者', '超强者']:
        tr = [r for r in wrows if r['档位'] == t]
        for lv in LEVELS:
            L.append(f'| {t}·{lv}级 | {len(tr)} | ' + ' | '.join(fmt(med([r[st][lv] for r in tr])) for st in STATS) + ' |')
    L.append('')
    L.append('### C. 装备对应等级分布（通用池件数，等级段 × 品质）')
    L.append('')
    bands = sorted({bb for bb, _ in dist})
    L.append('| 等级段 | ' + ' | '.join(GN) + ' | 合计 |')
    L.append('|---' * (len(GN) + 2) + '|')
    for bb in bands:
        row = [dist.get((bb, g), 0) for g in range(7)]
        L.append(f'| {band_name(bb)} | ' + ' | '.join(str(x) if x else '·' for x in row) + f' | {sum(row)} |')
    L.append('')
    lbf = D.dt['generic']['level_by_floor']
    L.append('通用掉落按层挑装备的等级上限：' + '、'.join(f'{f} 层 {lv}' for f, lv in lbf) + f'；窗口向下 {D.dt["generic"]["level_window"]} 级。招牌／低档稀有掉落池共 {len(sig_pool)} 件（已并入跨来源装备池）。不进通用池：' + '；'.join(f'{k} {v} 件' for k, v in skipped.items()) + f'。掉不出（等级 >{lv_cap}、无等级或品质超上限）{len(unreach)} 件。')
    L.append('')
    smalls = bs + as_ + rs + ws + ks + cs + [x for _, _, s_ in skill_res.values() for x in s_] + [x for _, _, s_ in eres.values() for x in s_]
    L.append(f'档内不足 3 条、没判离群的档 {len(smalls)} 个；「档中位为 0、本条不为 0」{len(zero_med)} 条（都在 --json）。')
    L.append('')
    # 四、口径与拿不准
    L.append('### D. 口径与拿不准（已按 v0.16 26 条口径修订）')
    L.append('')
    L.append('口径（照游戏代码复算，不跑 Godot）：')
    L.append('- 装备池＝通用掉落池（`tianqi_gear.gd` drop_pool＋_reroll_ok）＋招牌／低档稀有掉落池（`tianqi_drop.gd`）；装备效果已叠加 `skill_rework.gear`（含 tune）、T451 `gear_elem_amp.json` 与 12 把系别法宝改写（`gear_table.json`）。')
    L.append('- 随机词条＝`affix_table.json` 按合法栏位标签（攻4／防8／通10、光环2）、同件不重名、特效每件 ≤2、不朽神话 3 格算全身上限。')
    L.append('- 角色自带加成＝按替换链与功法名归并，同一功法只取同时生效的最高一层；已排除 `REALM_IDS` 8 个原版境界被动。')
    L.append('- 九线封顶＝①15%、②每系30%、③35%、④暴伤30%（`damage_ledger.phase4.nine_crit_dmg_cap` 实际已开）、属性30%（宝珠属性按已封算）。相乘属性份额按对数倍率算。')
    L.append('- 技能＝`六维打分_实测数据.json` 按「档位 × 输出评级」分组，未量到角色与不开放角色单列；逐招冷却 ≥99 记「一场一次」单列不除 100。')
    L.append('- 怪物＝`core/guardian_rework.gd:367-416` 真实路径复算（含 Vitsuno 普通难度 3、去 ×6、Star_Warehouse DCL3 ×2、`enemy_hp_pct` 40% 及逐阶取整），首领（D248 实测表，跳幅只作参考不计离群）／精英／小怪三分列 × 天启篇五档；附 1～34 层伤害招命中类型占比与 D273 四栏归档核查。')
    L.append('')
    L.append('拿不准／没核：')
    L.append('- 1～27 层除 22 层外无实测归档、28～30 层出伤无实测、30～33 层敏捷折算未核，交怪物重标卡 T450。')
    L.append('- 怪物楼层只认名字直接带「N层」的地图（' + '、'.join(f'{f}:{"/".join(n[:8] for n in v)}' for f, v in sorted(maps_used.items()) if len(v) > 1) + '）；伐木场、黑金村、深渊、肝帝之地、天外天等子地图未并入楼层曲线。')
    L.append('- 角色 peak 只量每人最高一招单次施放，不代表整套循环与换伤／烙印分布（交 N04 复量）。')
    L.append('- D273 四栏逐状态／逐只实时拆账：仓内 T405／T501 归档尚未拆到预算外各子项与首领回血，全层拆账待 N15 工具落地。')
    L.append('')
    detail = {
        '角色白板': {'档': wm, '离群': wo, '明细': wrows},
        '逐招系数': {'档': km, '离群': ko, '明细': kr},
        '技能全系数': {'档': cm, '离群': co},
        '跨来源': {'来源': src, '标记': cflags, '九线封顶': nine},
        '大类汇总': {k: {'条数': v[1], '离群数': len(v[2]), '标记': v[4]} for k, v in expand.items()},
        '装备底子': {'档': bm, '离群': bo},
        '固定词条': {'档': am, '离群': ao},
        '随机词条': {'档': rm, '离群': ro, '阶间跳幅': steps},
        '技能': {k: {'档': v[0], '离群': v[1]} for k, v in skill_res.items()},
        '未量到角色': missing_peak,
        '不开放角色': not_open,
        '怪物': {
            '分曲线': curves_by_cat,
            '分跳幅': jumps_by_cat,
            '五档跳幅': jumps_5diff,
            '个位数核验': single_digit_mobs,
            '命中类型占比': {'按层': hit_floors, '汇总': hit_summary},
            '离群': {k: v[1] for k, v in eres.items()},
            '明细': erows,
        },
        '已知事实对照': {'对照': known_rows, '缺口': known_gaps},
        '改写表漏项': leaks,
        '守层者D273': d273,
        '不读表装备': noformula,
        '掉不出': unreach,
        '招牌掉落池数': len(sig_pool),
        '等级分布': {f'{band_name(b)}·{GN[g]}': n for (b, g), n in dist.items()},
    }
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
    print(md.split('## 第二层')[0])
    print('报告行数', md.count('\n'))


if __name__ == '__main__':
    main()
