#!/usr/bin/env python3
"""启封数值对账·外部来源倒查（T521）：从结算函数倒查所有往属性／伤害加数的来源，按大类进跨来源表。只读游戏数据与代码。

主脚本 启封数值对账.py 调 section(D, M) 把本节接在报告后面；T520 的总表要行时调 rows(D, M)。
单独跑：python3 03_再刷重制_Godot/07_开发环境/启封数值对账_来源.py [--json 文件]   只打印本节（--json 另写全部明细）

口径：
  倒查起点 ＝ core/actor.gd 的 param_base／param_plus／param_rate／param 包装链／xparam／sparam，
             core/damage.gd _calculate 的五池（①normalAdd ②elementAdd ③finalAdd ④criticalAdd ⑤tianqi）与池外乘数，
             core/tianqi_ledger.gd 的九线封顶（apply_nine_cap、param_cap）。代码位置按函数签名现搜行号，改了代码会跟着走。
  拿得到   ＝ 物件在全部敌人掉落表（含 <Enemy Drops>）、地图事件／公共事件的增减物品、商店里出现过，且那张图（MapInfos 往上找）
             名字带 N 层、N 在 1～30；只在公共事件里给、找不到楼层的写「公共事件给，楼层不明」。没核事件有意删除名单与开关条件。
  上限／常见值 ＝ 同一来源同档能拿到的最大值／有这项的物件中位数；百分数都写成「+N%」的 N。
"""
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
TQ = X / 'tianqi_data'
FLOOR_MAX = 30  # 启封：1～30 层（31 层起归七印祭坛，见 core/tianqi_drop.gd 头注释）

# 大类（和协调 11-25 定的第一层分类同名；T521 新增的在后面）
CATS = ['角色白板', '被动心法', '技能', '装备底子', '固定词条', '随机词条', '套装', '宝石宝珠', '符石', '技能书秘籍', '法宝', '真气',
        '称号传承光耀', '临时增益光环', '元素', '养成（新发现）', '天启篇规则（新发现）', '遗物净印（新发现）', '角色专属模块（新发现）', '宠物（新发现）', '种族（新发现）']


def load(p):
    with open(p, encoding='utf-8') as f:
        return json.load(f)


def med(v):
    v = [x for x in v if x is not None]
    return statistics.median(v) if v else None


def n(x):
    if x is None:
        return '—'
    if isinstance(x, str):
        return x
    if float(x).is_integer():
        return f'{int(x):,}'
    return f'{x:.2f}'.rstrip('0').rstrip('.')


# ---------------- 代码位置 ----------------
_src_cache = {}


def loc(rel, needle):
    """modes/xiyou 下的文件里搜函数签名，返回 core/x.gd:行号（找不到写 ?）"""
    p = X / rel
    if p not in _src_cache:
        try:
            _src_cache[p] = p.read_text(encoding='utf-8').split('\n')
        except OSError:
            _src_cache[p] = []
    for i, line in enumerate(_src_cache[p], 1):
        if needle in line:
            return f'{rel}:{i}'
    return f'{rel}:?'


# 倒查清单：结算处 → 这一处读的来源（模块.函数）→ 位置。每条 (结算处, 来源说明, 文件, 搜索串, 大类)
TRACE = [
    # 能力值：param_base
    ('能力值 param_base', '职业曲线／天启篇标准线＋职责模板', 'core/actor.gd', 'func param_base_direct(', '角色白板'),
    ('能力值 param_base', '被动 passivePBST／passivePBSTEX（按基础值 % 或定值）', 'core/actor.gd', 'func param_base(i', '被动心法'),
    ('能力值 param_base', '修炼 XTraining.param_bonus → 天启篇 XTianqiMoney.training_bonus', 'core/tianqi_money.gd', 'static func training_bonus', '养成（新发现）'),
    ('能力值 param_base', '专属角色模块 paramBase（镜流星魂）', 'core/actor.gd', 'return XActorModules.param_base', '角色专属模块（新发现）'),
    # 能力值：param_plus
    ('能力值 param_plus', '永久加值 XParamPlus（丹药、事件 317）', 'core/param_plus.gd', 'static func bonus', '养成（新发现）'),
    ('能力值 param_plus', '原版套装 paramPlus（XEquipSuits）', 'core/equip_suits.gd', 'static func value', '套装'),
    ('能力值 param_plus', '装备八项（天启篇读表 XTianqiGear.param_of）＋passiveWPNM／ARMM 放大', 'core/tianqi_gear.gd', 'static func param_of', '装备底子'),
    ('能力值 param_plus', '符石镶嵌固定加值（随装备等级的换算比放大＝光耀度）', 'core/tianqi_gear.gd', 'static func flat_ratio', '符石'),
    ('能力值 param_plus', '法宝成长 magic_param（天启篇读表 fabao_param：半件同级装备）', 'core/tianqi_gear.gd', 'static func fabao_param', '法宝'),
    ('能力值 param_plus', '<Custom Parameters> custom_param（冠军戒指等）', 'core/actor.gd', 'func custom_param(', '装备底子'),
    ('能力值 param_plus', '种族灵族武器 ×q/2（XRaceBattle.param_plus）', 'core/race_battle.gd', 'static func param_plus', '种族（新发现）'),
    ('能力值 param_plus', '心钢累计生命（XHeartsteel.param_plus）', 'core/heartsteel.gd', 'static func param_plus', '角色专属模块（新发现）'),
    # 能力值：param_rate
    ('能力值 param_rate', '特性 21（装备、状态、宝珠镶进的、技能）＝traits_pi，加算', 'core/battler.gd', 'func param_rate(i', '临时增益光环'),
    ('能力值 param_rate', '职业属性倍率天启篇不算（class_rate_strip）', 'core/tianqi_base.gd', 'static func class_rate_strip', '角色白板'),
    ('能力值 param_rate', '原版套装 paramRate（另乘）', 'core/equip_suits.gd', 'static func value', '套装'),
    ('能力值 param_rate', '九线属性封顶 +30%（符文之语、成长装、宝珠特性 21、原版套装）', 'core/tianqi_ledger.gd', 'static func param_cap', '宝石宝珠'),
    ('能力值 param_rate', '通用书／权能书 <CodexParamRate>（号卷不算）', 'core/power_books.gd', 'static func param_rate_bonus', '技能书秘籍'),
    ('能力值 param_rate', '七印殉印 2 件最大生命%', 'core/tianqi_qiyin_effects.gd', 'static func param_rate', '套装'),
    ('能力值 param_rate', '七首之龙龙血全属性%', 'core/tianqi_qiyin_dragon_run.gd', 'static func param_rate', '养成（新发现）'),
    ('能力值 param_rate', '天启篇词条属性%（含新异化「临终」）', 'core/tianqi_affix_battle.gd', 'static func param_rate', '随机词条'),
    ('能力值 param_rate', '击杀成长（关羽、张飞、齐格鲁德…）', 'core/tianqi_skills.gd', 'static func param_rate(a, i', '养成（新发现）'),
    ('能力值 param_rate', '烙印皮薄（物防魔防 −）', 'core/tianqi_brand.gd', 'static func def_rate', '养成（新发现）'),
    ('能力值 param_rate', '境底＋境支属性%', 'core/tianqi_brand_realm.gd', 'static func param_rate', '养成（新发现）'),
    ('能力值 param_rate', '专属角色模块 paramRate（饿狼形态）', 'core/actor_modules.gd', 'static func param_rate', '角色专属模块（新发现）'),
    ('能力值 param_rate', '强化／弱化 buffs ×(1＋0.25×层)', 'core/battler.gd', 'func param_buff_rate', '临时增益光环'),
    ('能力值 param_rate', '天道诅咒敏捷 −20% 改读档位表（traits_pi）', 'core/tianqi_no_diff_passive.gd', 'static func traits_pi', '天启篇规则（新发现）'),
    # 能力值：param 包装链
    ('能力值 param 包装', '淬元丹（天启篇不读计数）', 'core/percent_pills.gd', 'static func param', '养成（新发现）'),
    ('能力值 param 包装', '专属模块（米拉、黄泉、甚尔、宿傩、饿狼）', 'core/actor_modules.gd', 'static func param(', '角色专属模块（新发现）'),
    ('能力值 param 包装', '心钢、狂妄（成长装备）、小猫剑圣、云裳', 'core/actor.gd', 'func param_before_alien', '角色专属模块（新发现）'),
    ('能力值 param 包装', '天启篇坐骑敏捷%（XTianqiGear.param）', 'core/tianqi_gear.gd', 'static func param(', '装备底子'),
    ('能力值 param 包装', '无限成长平加（渡鸦、奈叶、流萤）', 'core/tianqi_growth.gd', 'static func param_flat', '养成（新发现）'),
    ('能力值 param 包装', '四骑士减益（疫病、病弱、识破、破产、碎甲）', 'core/tianqi_horsemen.gd', 'static func actor_param', '天启篇规则（新发现）'),
    ('能力值 param 包装', '骑士遗物：卷子资历全属性、混子之盾双防', 'core/tianqi_rewards.gd', 'static func actor_param', '遗物净印（新发现）'),
    ('能力值 param 包装', '饥荒／疫病线异化减益', 'core/tianqi_famine_alien.gd', 'static func actor_param', '天启篇规则（新发现）'),
    ('能力值 param 包装', '流萤、异化逆骨、谷雨、璇、屠苏', 'core/actor.gd', 'func _param_now(', '角色专属模块（新发现）'),
    ('能力值 param 包装', '种族祝福 ×(1＋q)（平加那截退掉）', 'core/race_battle.gd', 'static func param(', '种族（新发现）'),
    # xparam／sparam
    ('xparam（暴击率等）', '被动 passiveXPBST／EX', 'core/actor.gd', 'func _xparam_now(', '被动心法'),
    ('xparam（暴击率等）', '天道诅咒暴击率 +50 改读表', 'core/tianqi_no_diff_passive.gd', 'static func xparam_add', '天启篇规则（新发现）'),
    ('xparam（暴击率等）', '原版套装 xparamPlus／Rate', 'core/equip_suits.gd', 'static func value', '套装'),
    ('xparam（暴击率等）', '天启篇词条 命中、闪避、暴击、回复（含光环）', 'core/tianqi_affix_battle.gd', 'static func xparam', '随机词条'),
    ('xparam（暴击率等）', '战宠 push8～14 加进 traitsSum', 'core/pets.gd', 'static func war_xparam_plus', '宠物（新发现）'),
    ('sparam（承伤等）', '被动 passiveSPBST、套装 sparam、弱者挑战 10357', 'core/actor.gd', 'func _sparam_now(', '被动心法'),
    # 出手次数
    ('出手次数', '连击／再动：九线停用、道法连击分神停用、词条连击再动', 'core/actor.gd', 'func attack_times_add(', '真气'),
    ('出手次数', '回合预算：每人每回合最多多 1 次', 'core/tianqi_ledger.gd', 'static func take_extra', '天启篇规则（新发现）'),
    # 伤害
    ('伤害 ①技能池', 'SkETypeHarmRi（武器类型）＋skillTypeDvup＋SkillPass rate', 'core/damage.gd', 'var normal_add := 0.0', '被动心法'),
    ('伤害 ②元素池', '元素增幅 elementAmplify（装备、宝珠、状态、角色）＋passiveELUP', 'core/damage.gd', 'static func own_bonus', '元素'),
    ('伤害 ③加成池', 'passiveHarmRi（被动缓存 globalHarmRi）', 'core/damage.gd', 'var final_add := float(cache.get("globalHarmRi"', '被动心法'),
    ('伤害 ③加成池', '宝珠共鸣 ＋g（orb-sets 钩子）', 'core/module_registry.gd', 'static func _orb_sets', '宝石宝珠'),
    ('伤害 ③加成池', '种族祝福 ＋q（race-blessings 钩子）', 'core/damage.gd', 'facts.race.pooled = true', '种族（新发现）'),
    ('伤害 ③加成池', '对某族敌人 <EnemyRaceBo>', 'core/damage.gd', 'static func _race_factors', '被动心法'),
    ('伤害 ③加成池', '原版套装状态确认阶段 ×k → ＋(k−1)', 'core/tianqi_ledger.gd', 'static func suit_confirm_add', '套装'),
    ('伤害 ③加成池', '状态确认阶段 ×k 归池（POOL_LIVE，七印条件增伤等）', 'core/tianqi_ledger.gd', 'static func live_confirm_add', '临时增益光环'),
    ('伤害 ③加成池', '九线封顶（秘籍格每本 8%、其余九线 ①15 ②30 ③35）', 'core/tianqi_ledger.gd', 'static func apply_nine_cap', '技能书秘籍'),
    ('伤害 ④暴击', '暴击底 1.5＋critical_multiplier_bonus＋critHarmRi', 'core/damage.gd', 'static func critical_multiplier_bonus', '被动心法'),
    ('伤害 ④暴击', '元素效果遮蔽锋芒（暴击多出部分 −33%）', 'core/tianqi_element_effects.gd', 'static func crit_mult', '元素'),
    ('伤害 ⑤天启篇', '档位出伤×我方伤害×弱者协力×助力位光环×天平酒×K注视（含烙印、境支换伤）', 'core/tianqi_combat.gd', 'static func dealt_parts', '天启篇规则（新发现）'),
    ('伤害 池外', '熟练度 masteryDamage（天启篇每级 +3%、10 级）乘 basis', 'core/skill_mastery.gd', 'static func damage(item', '养成（新发现）'),
    ('伤害 池外', '真气 growthMultiplier（天启篇恒 1）', 'core/zhenqi.gd', 'static func damage_mult', '真气'),
    ('伤害 池外', '原版独立乘区 SelfPhysRate／SelfElemRate（天启篇不读）', 'core/damage.gd', 'static func _self_rates', '被动心法'),
    ('伤害 池外', '浸湿 −11%、烙印破防 ×1.3（受方）', 'core/damage.gd', 'XTianqiElementEffects.out_mult(a)', '元素'),
    ('伤害 池外', '守层者一刀切抗性', 'core/damage.gd', 'XGuardianRework.resistance(b', '元素'),
]


# ---------------- 拿得到：物件来源索引（口径 10：跑事件页条件与分支条件） ----------------
class Where:
    """(kind, id) → [(途径, 楼层, 条件标记)]；kind 1 物品 2 武器 3 防具"""

    def __init__(self, D):
        self.D = D
        mi = D.MI
        self.floor_of_map = {}
        for m in mi:
            if not m:
                continue
            f, cur, seen = 0, m, set()
            while cur and cur['id'] not in seen:
                seen.add(cur['id'])
                f = _floor_name(cur.get('name', ''))
                if f:
                    break
                pid = cur.get('parentId', 0)
                cur = mi[pid] if 0 < pid < len(mi) else None
            self.floor_of_map[m['id']] = f
        self.hits = defaultdict(list)
        troop_maps = defaultdict(set)
        for mp in (X / 'generated/maps').glob('Map*.json'):
            try:
                mid = int(mp.stem[3:])
                d = load(mp)
            except (ValueError, OSError):
                continue
            fl = self.floor_of_map.get(mid, 0)
            for enc in d.get('encounterList', []) or []:
                troop_maps[enc.get('troopId')].add(fl)
            for ev in d.get('events', []) or []:
                for pg in (ev or {}).get('pages', []) or []:
                    pcond = self._page_cond(pg.get('conditions', {}))
                    self._scan_list(pg.get('list', []), f'地图{mid}', fl, troop_maps, pcond)
        for ce in load(DB / 'CommonEvents.json'):
            if ce:
                self._scan_list(ce.get('list', []), f'公共事件{ce["id"]}', None, troop_maps, '公共事件')
        for t in D.T:
            for pg in (t or {}).get('pages', []) or []:
                self._scan_list(pg.get('list', []), f'敌群{t["id"]}', None, troop_maps, '敌群条件')
        enemy_floors = defaultdict(set)
        for t in D.T:
            if t:
                for mem in t.get('members', []):
                    enemy_floors[mem.get('enemyId')] |= troop_maps.get(t['id'], set())
        # 天启篇改写：tianqi_trim.gd NO_SALE 不上架（删掉商店命中）；人族首领 EV054 货架改读 secret_books.json ev54_shop；代码直接给的（饿狼遗物、成长神器掉落）
        trim = (X / 'core/tianqi_trim.gd').read_text(encoding='utf-8')
        m = re.search(r'const NO_SALE := (\[.*?\]\])', trim)
        self.no_sale = {(a + 1, b) for a, b in json.loads(m.group(1))} if m else set()
        for k in self.no_sale:
            self.hits[k] = [h for h in self.hits.get(k, []) if '商店' not in h[0]] + [('天启篇不上架（tianqi_trim NO_SALE）', -1, '屏蔽')]
        for tab in D.sbk.get('ev54_shop', {}).get('tabs', {}).values():
            for g in tab.get('goods', []):
                self.hits[(g[0] + 1, g[1])].append(('天启篇人族首领货架「%s」' % tab.get('label', ''), int(tab.get('min_floor', 1) or 1), ''))
        garou = (X / 'core/garou.gd').read_text(encoding='utf-8')
        m = re.search(r'const RELICS := \[([\d, ]+)\]', garou)
        for st, gid in enumerate(int(x) for x in (m.group(1).split(',') if m else [])):
            self.hits[(3, gid)].append(('代码给：饿狼 173 第 %d 形态遗物（core/garou.gd gain_gear）' % (st + 1), 0, '角色形态'))
        # 成长神器代码掉落（心之钢 7900／狂妄 7902：Map152 不朽来源 10%；魔冠 7940：Map162 不朽未知战斗 3%）
        f152 = self.floor_of_map.get(152, 13)
        f162 = self.floor_of_map.get(162, 19)
        self.hits[(3, 7900)].append(('代码掉：Map152 不朽来源敌群 454/455（10%，core/heartsteel.gd）', f152, '不朽来源条件'))
        self.hits[(3, 7902)].append(('代码掉：Map152 不朽来源敌群 454/455（10%，core/hubris.gd）', f152, '不朽来源条件'))
        self.hits[(3, 7940)].append(('代码掉：Map162 不朽未知战斗敌群 539~542（3%，core/demon_crown.gd）', f162, '不朽未知条件'))
        er = re.compile(r'(?i)(Item|Weapon|Armor)\s+(\d+)\s*:')
        for e in D.E:
            if not e:
                continue
            fls = enemy_floors.get(e['id']) or {None}
            got = [(d.get('kind'), d.get('dataId')) for d in e.get('dropItems', []) if d.get('kind')]
            for blk in re.findall(r'(?is)<Enemy Drops>(.*?)</Enemy Drops>', e.get('note', '')):
                got += [({'item': 1, 'weapon': 2, 'armor': 3}[m.group(1).lower()], int(m.group(2))) for m in er.finditer(blk)]
            for k, i in got:
                for fl in fls:
                    self.hits[(k, i)].append((f'敌人{e["id"]}掉落', fl, ''))

    @staticmethod
    def _page_cond(cond):
        if not isinstance(cond, dict):
            return ''
        parts = []
        if cond.get('switch1Valid'):
            parts.append(f"SW{cond.get('switch1Id')}")
        if cond.get('switch2Valid'):
            parts.append(f"SW{cond.get('switch2Id')}")
        if cond.get('variableValid'):
            parts.append(f"V{cond.get('variableId')}>={cond.get('variableValue')}")
        if cond.get('selfSwitchValid'):
            parts.append(f"自开关{cond.get('selfSwitchCh')}")
        if cond.get('itemValid'):
            parts.append(f"需物品{cond.get('itemId')}")
        if cond.get('actorValid'):
            parts.append(f"需角色{cond.get('actorId')}")
        return '页条件(' + ','.join(parts) + ')' if parts else ''

    def _scan_list(self, lst, where, fl, troop_maps, base_cond=''):
        branch_stack = []  # [(indent, cond_desc)]
        for c in lst:
            code, p, ind = c.get('code'), c.get('parameters', []), int(c.get('indent', 0))
            while branch_stack and ind <= branch_stack[-1][0]:
                branch_stack.pop()
            if code == 111 and p:
                k = p[0]
                desc = f'分支SW{p[1]}' if k == 0 and len(p) > 1 else (f'分支V{p[1]}' if k == 1 and len(p) > 1 else (f'分支脚本' if k == 12 else f'分支({k})'))
                branch_stack.append((ind, desc))
                continue
            cond = '+'.join([x for x in [base_cond] + [b[1] for b in branch_stack] if x])
            if code in (126, 127, 128) and len(p) >= 2 and p[1] == 0:
                self.hits[(code - 125, p[0])].append((where + '给', fl, cond))
            elif code in (302, 605) and len(p) >= 2:
                self.hits[(p[0] + 1, p[1])].append((where + '商店', fl, cond))
            elif code == 301 and len(p) >= 2 and p[0] == 0 and fl is not None:
                troop_maps[p[1]].add(fl)

    def verdict(self, kind, i):
        hs = self.hits.get((kind, i), [])
        if not hs:
            return '否（全库没有掉落／事件／商店来源）', []
        code = [(w, f, c) for w, f, c in hs if w.startswith('代码给') or w.startswith('代码掉')]
        if code:
            w, f, c = code[0]
            if f and 1 <= f <= FLOOR_MAX:
                return f'是（{f} 层起，带条件：{c}；{w}）', hs
            return f'是（{w}；看角色养成进度，楼层没核）', hs
        hs_live = [h for h in hs if h[1] != -1]
        if not hs_live:
            return '否（天启篇不上架，tianqi_trim NO_SALE）', hs
        hs = hs_live
        inside_free = sorted({f for _, f, c in hs if f and 1 <= f <= FLOOR_MAX and not c})
        inside_cond = sorted({(f, c) for _, f, c in hs if f and 1 <= f <= FLOOR_MAX and c})
        if inside_free:
            return f'是（无条件，{inside_free[0]} 层起）', hs
        if inside_cond:
            f0, c0 = inside_cond[0]
            return f'是（带事件条件，{f0} 层起：{c0[:24]}）', hs
        if any(w.startswith('地图4') for w, _, _ in hs):
            return '拿不准（方桌大厅事件／商店；天启篇大厅有清理与货架滤链，没逐件核）', hs
        if any(f is None for _, f, _ in hs):
            return '拿不准（公共事件或敌群事件给，楼层不明）', hs
        fls = sorted({f for _, f, _ in hs if f})
        if fls:
            return f'否（只在 {fls[0]} 层，启封 1～{FLOOR_MAX} 层外）', hs
        return '拿不准（所在图找不到楼层）', hs


def _floor_name(name):
    m = re.search(r'(\d+)\s*层', name)
    if m:
        return int(m.group(1))
    m = re.search(r'([一二三四五六七八九十]+)层', name)
    if not m:
        return 0
    CN = '一二三四五六七八九十'
    s = m.group(1)
    if s == '十':
        return 10
    if '十' in s:
        a, b = s.split('十')
        return (CN.index(a) + 1 if a else 1) * 10 + (CN.index(b) + 1 if b else 0)
    return CN.index(s[-1]) + 1 if len(s) == 1 else 0


# ---------------- 各大类 ----------------
def _gear_tags(M, D, kind, r):
    f = getattr(M, 'gear_eff', None)
    return f(D, kind, r) if f else {}


def build(D, M):
    L = load
    W = Where(D)
    rows = []
    detail = defaultdict(list)

    def put(cat, src, attr, pool, top, common, who, reach, where, note='', status='有效'):
        rows.append({'大类': cat, '来源': src, '属性': attr, '乘区': pool, '上限': top, '常见值': common, '谁': who,
                     '拿得到': reach, '生效态': status, '位置': where, '说明': note})

    caps = D.ledger['nine_caps']
    p4_crit = D.ledger.get('phase4', {}).get('nine_crit_dmg_cap', 0.3)
    pct = lambda v: round(v * 100, 2)
    param_cap_pct = pct(caps['param'])

    # --- 宝石宝珠（口径 4：属性% 按九线 param_cap +30% 封顶后算）---
    orbs = D.orbs
    tm = orbs['tierMultiplier']
    for fam in orbs['families']:
        oid = fam['ids'][-1]
        it = D.I[oid] if oid < len(D.I) and D.I[oid] else {}
        for line in fam['lines']:
            key, base, label = line
            v_top = base * tm[-1]
            detail['宝石宝珠'].append({'族': fam['name'], '项': label, '每颗凝砂': base, '每颗归真': v_top, '同族最多颗': orbs['familyCap'], '归真物品': it.get('name')})
    best = defaultdict(lambda: (0, ''))
    for d in detail['宝石宝珠']:
        lab = d['项']
        if d['每颗归真'] > best[lab][0]:
            best[lab] = (d['每颗归真'], d['族'])
    bag = sorted({W.verdict(1, b['itemId'])[0] for b in orbs['bands']})
    reach_orb = '是（代码掉：副本首领胜利 %s%% 掉神秘珠，按楼层段，`%s`；数据表里神秘珠%s）' % (
        n(orbs['dropRate'] * 100), loc('core/dungeon.gd', 'XOrbs.drop_boss_pearl'), '／'.join(bag))
    seen_attr = set()
    for lab, (v, fam) in sorted(best.items(), key=lambda x: -x[1][0]):
        attr = '②元素伤%(单系)' if lab.endswith('伤害') else lab + '%'
        if attr in seen_attr:
            continue
        seen_attr.add(attr)
        is_param = lab in ('物理攻击', '魔法攻击', '最大生命', '物理防御', '魔法防御', '敏捷', '最大法力')
        raw_top = v * orbs['familyCap']
        eff_top = min(raw_top, param_cap_pct) if is_param else raw_top
        pool = '② 元素池（每系）' if lab.endswith('伤害') else ('能力值倍率（九线 param 已封 ＋%s%%）' % n(param_cap_pct) if is_param else 'xparam')
        cap_note = f'九线属性已封 +{n(param_cap_pct)}%（未封 {n(raw_top)}%）' if is_param else f'每颗归真＝凝砂×{tm[-1]}；同族只算最高 {orbs["familyCap"]} 颗；九线封顶'
        put('宝石宝珠', f'宝珠（归真×{orbs["familyCap"]} 颗）', attr, pool, eff_top, v, fam,
            f'{reach_orb}；归真只在 {orbs["bands"][-2]["from"]} 层起的段（权重 {orbs["bands"][-2]["weights"][-1]}／{orbs["bands"][-1]["weights"][-1]}）',
            loc('core/orbs.gd', 'static func general_set'), cap_note, status='有效')
    g3 = orbs['general']['three']
    put('宝石宝珠', '宝珠共鸣（同套 3 族、最高阶）', '③伤害加成%', '③ 伤害加成池', g3[-1], orbs['general']['two'][-1], '三族共鸣', '同上',
        loc('core/module_registry.gd', 'static func _orb_sets'), '九线 ③ 合计封 +%s%%' % n(pct(caps['bonus'])), status='有效')
    sk = orbs['sockets']
    detail['宝石宝珠'].append({'孔数权重': sk})

    # --- 符石／晶石／神文（口径 12／14／16：按实际入口报属性定值、武器元素伤、命中；孔数 0～12 分布；等级×换算比）---
    pl = load(DB / 'Plugins.json').get('YEP_X_ItemUpgradeSlots', {})
    slots_def, slots_max = int(pl.get('Default Slots', 6)), int(pl.get('MAX Slots', 12))
    slots_var = int(pl.get('Slot Variance', 6))
    slots_min = max(0, slots_def - slots_var)
    stat_i = {'MaxHP': 0, 'MaxMP': 1, 'Atk': 2, 'Def': 3, 'Mat': 4, 'Mdf': 5, 'Agi': 6, 'Luk': 7}
    ratio = getattr(M, 'ratio', None)
    rune_ids = [i for i, it in enumerate(D.I) if it and str(it.get('name', '')).startswith('符石:')]
    crystal_ids = [i for i, it in enumerate(D.I) if it and str(it.get('name', '')).startswith('晶石:')]
    divine_ids = [i for i, it in enumerate(D.I) if it and str(it.get('name', '')).startswith('神文:')]
    up = defaultdict(list)
    up_elem_crys, up_elem_div, up_hit = [], [], []
    for i, it in enumerate(D.I):
        if not it:
            continue
        note = it.get('note', '') or ''
        if '<Upgrade' not in note:
            continue
        nm = str(it.get('name', ''))
        for blk_kind in ('Weapon', 'Armor'):
            m = re.search(r'(?is)<Upgrade %s Effect>(.*?)</Upgrade %s Effect>' % (blk_kind, blk_kind), note)
            if not m:
                continue
            blk = m.group(1)
            for k, v in re.findall(r'\b(MaxHP|MaxMP|Atk|Def|Mat|Mdf|Agi|Luk)\s*:\s*\+?(\d+)', blk):
                if nm.startswith(('符石:', '晶石:', '神文:')):
                    up[(blk_kind, k)].append((int(v), nm, i))
            for em in re.finditer(r'Element Amplify (\d+)\s*:\s*\+?([\d.]+)%', blk, re.I):
                if int(em.group(1)) != 10:
                    if nm.startswith('晶石:'):
                        up_elem_crys.append((float(em.group(2)), nm, i))
                    elif nm.startswith('神文:'):
                        up_elem_div.append((float(em.group(2)), nm, i))
            for hm in re.finditer(r'\bHit\s*:\s*\+?([\d.]+)%?', blk, re.I):
                up_hit.append((float(hm.group(1)), nm, blk_kind, i))
    for (bk, k), vals in sorted(up.items()):
        top = max(vals)
        idx = stat_i.get(k)
        r30 = ratio(D, 30, idx) if (ratio and idx is not None) else None
        r60 = ratio(D, 60, idx) if (ratio and idx is not None) else None
        r80 = ratio(D, 80, idx) if (ratio and idx is not None) else None
        full = top[0] * r80 if r80 else None
        conv = 1 + 80 * 98 / 90
        line = D.line(conv, getattr(M, 'STATS', ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'])[idx]) if idx is not None else None
        detail['符石'].append({
            '镶在': bk, '项': k, '每颗最高': top[0], '物品': top[1],
            '30级×换算比': round(top[0] * r30, 1) if r30 else None,
            '60级×换算比': round(top[0] * r60, 1) if r60 else None,
            '80级×换算比': round(full, 1) if full else None,
            f'{slots_def}孔/12孔合计(80级)': f'{n(full * slots_def)}／{n(full * slots_max)}' if full else '—',
            f'{slots_def}孔占80级标准线': round(full * slots_def / line, 3) if (full and line) else None,
        })
    best_atk = max([d for d in detail['符石'] if d['项'] in ('Atk', 'Mat') and d['镶在'] == 'Weapon'], key=lambda d: d['80级×换算比'] or 0, default=None)
    if best_atk:
        per80 = best_atk['80级×换算比'] or 0
        per30 = best_atk['30级×换算比'] or 0
        per60 = best_atk['60级×换算比'] or 0
        put('符石', f'强化·属性定值（武器，{slots_min}～{slots_max} 孔分布；默认 {slots_def} 孔）', '攻击（定值）', '能力值 param_plus（定值×等级换算比）',
            per80 * slots_max, per80 * slots_def, best_atk['物品'],
            W.verdict(1, rune_ids[0])[0] if rune_ids else '—', loc('core/tianqi_gem_power.gd', 'static func power_of'),
            f'孔数 {slots_min}～{slots_max}（默认 {slots_def}±{slots_var}）；单颗随等级×换算比：30级 {n(per30)}／60级 {n(per60)}／80级 {n(per80)}；6孔 {n(per80 * slots_def)}／12孔 {n(per80 * slots_max)}',
            status='有效')
    if up_elem_crys:
        tc = max(up_elem_crys)
        put('符石', f'强化·晶石武器元素伤（{slots_min}～{slots_max} 孔；默认 {slots_def} 孔）', '②元素伤%(单系)', '② 元素池（九线封 +%s%%）' % n(pct(caps['element'])),
            tc[0] * slots_max, tc[0] * slots_def, tc[1],
            W.verdict(1, tc[2])[0], loc('core/tianqi_gear.gd', 'static func upgrade_fixed'),
            f'单颗 +{n(tc[0])}%（另双攻+15）；0/6/12 孔＝0%／+{n(tc[0] * slots_def)}%／+{n(tc[0] * slots_max)}%', status='有效')
    if up_elem_div:
        td = max(up_elem_div)
        put('符石', f'强化·神文武器元素伤（{slots_min}～{slots_max} 孔；默认 {slots_def} 孔）', '②元素伤%(单系)', '② 元素池（九线封 +%s%%）' % n(pct(caps['element'])),
            td[0] * slots_max, td[0] * slots_def, td[1],
            W.verdict(1, td[2])[0], loc('core/tianqi_gear.gd', 'static func upgrade_fixed'),
            f'单颗 +{n(td[0])}%（防具六项+3）；0/6/12 孔＝0%／+{n(td[0] * slots_def)}%／+{n(td[0] * slots_max)}%', status='有效')
    if up_hit:
        th = max(up_hit)
        put('符石', f'强化·命中入口（{slots_min}～{slots_max} 孔；默认 {slots_def} 孔）', '命中%', 'xparam（命中）',
            th[0] * slots_max, th[0] * slots_def, f'{th[1]}（{th[2]}）',
            W.verdict(1, th[3])[0], loc('core/tianqi_gear.gd', 'static func upgrade_fixed'),
            f'{len(up_hit)} 条强化材料带命中；单颗 +{n(th[0])}%', status='有效')
    else:
        put('符石', '强化·命中入口（符石／晶石／神文）', '命中%', 'xparam（命中）', 0, 0, '全表 0 条带 Hit', '—',
            loc('core/tianqi_gear.gd', 'static func upgrade_fixed'), '已核 Items.json 强化块，无直接加 Hit 条目', status='不生效')
    # 符文之语（Runewords.json → 成品武器／防具）
    rw = [r for r in load(DB / 'Runewords.json') if r]
    rwb = defaultdict(list)
    for r in rw:
        for kind, key in ((2, 'weapon'), (3, 'armor')):
            gid = r.get(key) or 0
            if gid:
                rec = D.rec(kind, gid)
                for a, v in _gear_tags(M, D, kind, rec).items():
                    rwb[a].append((v, r['name'], kind, gid))
    for a, vals in rwb.items():
        t = max(vals)
        put('符石', '符文之语（单件）', a, '九线 runeword 桶', t[0], med([v for v, *_ in vals]), t[1],
            f'按配方镶齐对应符石（共 {len(rw)} 个配方）；符石{W.verdict(1, rune_ids[0])[0] if rune_ids else "—"}', loc('core/tianqi_ledger.gd', 'static func bucket_of'),
            f'{len(vals)} 个配方有；进九线封顶（①15/②30/③35/④{n(pct(p4_crit))}/属性30）', status='有效')
        detail['符文之语'] += [{'属性': a, '值': v, '配方': nm} for v, nm, *_ in sorted(vals, reverse=True)[:10]]

    # --- 套装（口径 19：已归类按 suit_template.json 报＋两套同穿合计；口径 23：未归类原版 xparamPlus 一律按百分点读，不乘 100）---
    st_suits = {int(k): v for k, v in D.st.get('suits', {}).items()}
    tv = D.st['values']
    top_s = max(v[-1] for v in tv.values())
    two_s = tv['2'][-1]
    put('套装', f'模板套装（已归类 {len(st_suits)} 套，5 件／两套 5＋2 四阶）', '③／②／生命%／承伤%', '词条池（九线内；CAP=2 套）',
        top_s + two_s, top_s, 'suit_template.json', '是（归类套按部件最低阶读表）', loc('core/tianqi_suits.gd', 'static func template_table'),
        f'单套 2/3/5 件四阶={two_s}/{tv["3"][-1]}/{top_s}%；两套同穿 5+2 可达 {top_s + two_s}%（守类减伤 -15%/-19.25%；回复单套封 5%、掉率封 10%）', status='有效')
    es = [s for s in load(DB / 'EquipSuits.json') if s]
    srate = defaultdict(list)
    for s in es:
        is_tpl = int(s['id']) in st_suits
        for b in s.get('bonuses', []):
            if is_tpl and int(b.get('requirePieces', 0)) >= 2:
                continue  # 已归类进模板表的多件档不再按原版重复统计（口径 19）
            for i, v in enumerate(b.get('paramRate', [])):
                if v != 1.0:
                    srate[('属性%', i)].append(((v - 1) * 100, s['name'], b.get('requirePieces')))
            for i, v in enumerate(b.get('xparamPlus', [])):
                if v:
                    # 口径 23：原版套装命中／闪避／暴击等 xparamPlus 一律按百分点直读，不按数值大小乘 100（魔暴龙 3 → +3%）
                    srate[('xparam+', i)].append((float(v), s['name'], b.get('requirePieces')))
            br = b.get('bResultRate', [1, 1, 1])
            if br and br[0] != 1.0:
                srate[('结果率', 0)].append(((br[0] - 1) * 100, s['name'], b.get('requirePieces')))
    PN = ['生命', '魔法', '物攻', '物防', '魔攻', '魔防', '敏捷', '幸运']
    XN = ['命中', '闪避', '暴击', '暴闪', '魔闪', '魔反', '反击', '生命再生', '魔法再生', 'TP再生']
    for (k, i), vals in sorted(srate.items()):
        t = max(vals)
        nm = (PN[i] + '%') if k == '属性%' else (XN[i] + '+(百分点)' if k == 'xparam+' else '掉落／结果率%')
        put('套装', '未归类原版套装（EquipSuits 单档，归 2C）', nm, '能力值倍率（另乘，九线 param 封顶）' if k == '属性%' else 'xparam／结算', t[0], med([v for v, *_ in vals]),
            f'{t[1]}（{t[2]} 件）', '随套装部件；部件拿得到与否见 --json', loc('core/equip_suits.gd', 'static func value'),
            f'{len(vals)} 档有（已跳过 {len(st_suits)} 套模板套多件档）', status='有效')
    # 七印套装
    qg = L(TQ / 'qiyin_gear.json')
    for key, s in qg['sets'].items():
        for b in s.get('bonuses', []):
            for fx in b.get('effects', []):
                detail['七印套装'].append({'套': s['name'], '件': b['count'], 'code': fx.get('code'), '值': fx.get('value'), '上限': fx.get('max'), '说明': fx.get('text')})
    pct_fx = [d for d in detail['七印套装'] if d['code'] and d['code'].endswith('_pct') and isinstance(d['值'], (int, float))]
    if pct_fx:
        t = max(pct_fx, key=lambda d: (d['上限'] or d['值']))
        put('套装', '七印套装（单条，%d 套）' % len(qg['sets']), '条件增伤%', '③（POOL_LIVE 归池，cap 视 pool 表）', t['上限'] or t['值'], med([d['值'] for d in pct_fx]),
            f"{t['套']}（{t['件']} 件）", f"否（七印祭坛 {qg['set_rule'].get('first_kill_floors', ['31'])[0]} 层起，启封 1～{FLOOR_MAX} 层外）",
            loc('core/tianqi_qiyin_effects.gd', 'static func param_rate'), '全部条目见 --json「七印套装」', status='有效')

    # --- 技能书秘籍：通用书 CodexParamRate（口径 2：先套 general_books 改写）、秘籍格、号卷 ---
    rate_re = re.compile(r'(?i)<CodexParamRate:\s*([^>]+)>')
    pr = defaultdict(list)
    for sid, sp in D.gbk['skills'].items():
        i = int(sid)
        r = D.S[i] if i < len(D.S) and D.S[i] else {}
        eff_note = M.note_edit(r.get('note', ''), sp)
        m = rate_re.search(eff_note)
        if m:
            for ent in m.group(1).split(','):
                a = ent.split(':')
                if len(a) >= 2:
                    try:
                        pr[int(float(a[0]))].append((float(a[1]), sp.get('name', sid)))
                    except ValueError:
                        pass
    for i, vals in sorted(pr.items()):
        t = max(vals)
        put('技能书秘籍', '通用书 <CodexParamRate>（每本，改写后）', PN[i] + '%', '能力值倍率（param_rate 另乘，不进九线）', t[0], med([v for v, _ in vals]), t[1], '拿不准（通用书来源没逐本核）',
            loc('core/power_books.gd', 'static func param_rate_bonus'), f'{len(vals)} 本', status='有效')
    slots = {k: v.get('secret_cap') for k, v in D.bt['tiers'].items()}
    put('技能书秘籍', '秘籍格（每本各池封顶）', '①②③④ 各池', '九线（秘籍单列）', pct(caps['secret_slot']), None, '每本', '是（格数 弱6／强4／超3＋难度加格）',
        loc('core/tianqi_ledger.gd', 'static func secret_slots'), '格数 %s；整格合计上限＝格数×%s%%' % (slots, n(pct(caps['secret_slot']))), status='有效')
    tr = L(TQ / 'trumpet.json')
    for s in tr['scrolls']:
        nums = [int(x) for x in re.findall(r'([+−-]\d+)%', s['sweet'].replace('−', '-'))]
        if nums:
            put('技能书秘籍', '号卷（%s）' % s['name'], s['sweet'], '条件增伤（另算，号卷格 3／2／1）', max(nums), None, s['name'],
                '只在 %s 掉（打副本不朽存在）' % '、'.join(tr['drop']['difficulties']), loc('core/power_books.gd', 'XTianqiTrumpet.skips_rate'), '代价：' + s['bitter'], status='有效')
    put('技能书秘籍', '七号齐鸣（七卷齐）', '③首回合伤害%', '条件增伤', tr['chorus']['first_turn_damage'], None, '七卷学齐', '同号卷', loc('core/power_books.gd', 'XTianqiTrumpet.skips_rate'), '', status='有效')

    # --- 法宝（口径 3：已套 12 把系别法宝改写，含表外 8101/8102）---
    affix_ids = set()
    for tab in (D.W, D.A):
        for r in tab:
            for row in (r or {}).get('equipment', {}).get('affixes', []):
                for c in row.get('choices', []):
                    affix_ids.update(c.get('ids', []))
    fb = []
    for kind, tab in ((2, D.W), (3, D.A)):
        for r in tab:
            if r and r.get('id') not in affix_ids and r.get('etypeId') == 13 and r.get('name') and 'Magic Weapon' in r.get('note', ''):
                tg = _gear_tags(M, D, kind, r)
                if tg:
                    rv, hs = W.verdict(kind, r['id'])
                    rview = dict(r)
                    if kind == 3 and r['id'] in D.efabao and D.efabao[r['id']].get('name'):
                        rview['name'] = D.efabao[r['id']]['name']
                    fb.append((kind, rview, tg, rv, hs))
    for fid, sp in D.efabao.items():
        if fid >= len(D.A) or not D.A[fid]:
            tpl = D.rec(3, int(sp.get('template', 0)))
            if tpl:
                vrec = dict(tpl)
                vrec['id'] = fid
                vrec['name'] = sp.get('name', str(fid))
                tg = _gear_tags(M, D, 3, vrec)
                if tg:
                    rv, hs = W.verdict(3, fid)
                    fb.append((3, vrec, tg, rv, hs))
    fb_attr = defaultdict(list)
    for kind, r, tg, rv, hs in fb:
        for a, v in tg.items():
            fb_attr[a].append((v, r['name'], rv, kind, r['id']))
    for a, vals in fb_attr.items():
        vals.sort(key=lambda x: -x[0])
        t = vals[0]
        ok = [x for x in vals if x[2].startswith('是')]
        put('法宝', '法宝（单件，改写后备注标签）', a, '按标签进对应池；归 equip 桶受九线封顶', t[0], med([v for v, *_ in vals]), t[1], t[2],
            loc('core/actor.gd', 'static func magic_param'),
            f'{len(vals)} 件有（已套 12 把系别法宝改写）；启封拿得到的最高：%s' % (f'{n(ok[0][0])}（{ok[0][1]}）' if ok else '无'), status='有效')
    detail['法宝'] = [{'法宝': r['name'], '种类': '武' if kind == 2 else '防', '编号': r['id'], '标签': tg, '拿得到': rv,
                     '来源': sorted({w for w, *_ in hs})[:6]} for kind, r, tg, rv, hs in sorted(fb, key=lambda x: -max(abs(v) for v in x[2].values()))]

    # --- 真气（口径 12：标「不生效」）---
    put('真气', '真气 growthMultiplier', '池外乘数', '独立乘（西游档）', 0, None, '—', '天启篇不生效（XTianqi.active 时恒 1）', loc('core/zhenqi.gd', 'static func damage_mult'), '', status='不生效')
    put('真气', '道法连击／分神', '出手次数', '回合预算', 0, None, '—', '天启篇不生效（NINE_OFF）', loc('core/actor.gd', 'func attack_times_add('), 'zhenqi 仍列在 NINE_BUCKETS（③封顶桶）', status='不生效')

    # --- 称号传承（口径 14：光耀度不单列成来源，移至 5.5 说明）---
    put('称号传承光耀', '称号（Star_Designation）', '—', '无', 0, None, '—', '不加属性（只有名字、图标、颜色）', loc('core/designation.gd', 'class_name XDesignation'), '', status='不生效')
    sect = [v for v in D.gbk['skills'].values() if '传承' in str(v.get('_note', '')) + str(v.get('name', ''))]
    put('称号传承光耀', '门派传承（通用书里的传承技）', '技能系数', '技能本身（T520 技能节）', len(sect), None, f'{len(sect)} 招', '拿不准（门派线没核）',
        loc('core/tianqi_sect.gd', 'class_name'), '传承＝通用书的门派技能，按技能系数算，不另加属性', status='待实测')

    # --- 临时增益光环（口径 2／20：状态读天启篇改写后的数据 D.effective_state，消除 2721 +900% 误报）---
    put('临时增益光环', '强化 buff（MV 两层）', '属性%', '能力值 param_buff_rate', 50, 25, '2 层', '是', loc('core/battler.gd', 'func param_buff_rate'), '', status='有效')
    ally_states = set()
    for s in D.S:
        if s and s.get('scope') in (7, 8, 9, 10, 11):
            for e in s.get('effects', []):
                if e.get('code') == 21 and e.get('dataId'):
                    ally_states.add(int(e['dataId']))
    for sid, c in D.cards.items():
        for st_id in (c.get('self_states') or []):
            if isinstance(st_id, int) and st_id > 0:
                ally_states.add(st_id)
    sbest = defaultdict(list)
    for sid in ally_states:
        st = D.effective_state(sid)
        if not st:
            continue
        for t in st.get('traits', []):
            if t.get('code') == 21 and t.get('dataId') in (0, 2, 4) and t.get('value', 1) > 1:
                sbest[PN[t['dataId']] + '%'].append(((t['value'] - 1) * 100, f"{st.get('name', sid)}({sid})"))
        for m in re.finditer(r'(?i)<passiveHarmRi\s*:\s*([+-]?[\d.]+)%?>', st.get('note', '')):
            sbest['③伤害加成%'].append((float(m.group(1)), f"{st.get('name', sid)}({sid})"))
    for a, vals in sbest.items():
        t = max(vals)
        put('临时增益光环', '我方技能挂的状态（单个，启封改写后）', a, '特性 21 加算／③', t[0], med([v for v, _ in vals]), t[1], '随技能', loc('core/battler.gd', 'func param_rate(i'),
            f'{len(vals)} 个状态（已套 skill_rework.states＋general_books.states，状态 2721 已改 +50%）', status='有效')
    put('临时增益光环', '助力位光环', '⑤伤害%', '⑤ 天启篇（独立乘）', pct(D.bt['assist_slot']['team_damage_dealt']), None, '有助力位', '是', loc('core/tianqi_combat.gd', 'static func dealt_parts'), '', status='有效')
    put('临时增益光环', '弱者协力（每名上场弱者）', '⑤伤害%', '⑤ 天启篇（独立乘）', pct(D.bt['weak_assist']['damage_dealt_per']) * 4, pct(D.bt['weak_assist']['damage_dealt_per']), '4 名弱者', '是',
        loc('core/tianqi_combat.gd', 'static func dealt_parts'), '承伤每人 %s%%' % n(pct(D.bt['weak_assist']['damage_taken_per'])), status='有效')
    mt = L(TQ / 'money_table.json')
    put('临时增益光环', '天平「酒」（大厅买，管当前层）', '⑤伤害%', '⑤ 天启篇（独立乘）', pct(mt['scale']['wine']), None, '酒', '是', loc('core/tianqi_money.gd', 'static func scale_dealt_mult'),
        '「油」承伤 −%s%%' % n(pct(mt['scale']['oil'])), status='有效')

    # --- 元素 ---
    ea = L(TQ / 'gear_elem_amp.json')
    for side in ('weapon_tiers', 'armor_tiers'):
        tiers = ea[side]
        in80 = [v for v in tiers.values() if v['level'][0] <= 80]
        t = max(in80, key=lambda v: v['range'][1])
        put('元素', '装备元素增幅（%s，单件，T451 重调）' % ('武器' if side == 'weapon_tiers' else '防具'), '②元素伤%(单系)', '② 元素池（每系）', t['range'][1], sum(t['range']) / 2,
            f"{t['level'][0]}～{t['level'][1]} 级", '随装备', loc('core/tianqi_ledger.gd', 'static func passive_buckets'), '九线 ② 合计封 +%s%%' % n(pct(caps['element'])), status='有效')
    put('元素', '虚空～风（11～15）借火～暗最低一系', '②元素伤%', '② 元素池', None, None, '规则', '是', loc('core/damage.gd', 'static func element_bonus'), '取 max(自身, 2～9 最低)', status='有效')

    # --- 养成（新发现）---
    tr_ = mt['training']
    put('养成（新发现）', '修炼（八项各 %d 级，全队）' % tr_['levels'], '白板属性%', 'param_base（定值＝本体基础×%）', pct(tr_['pct_per_level']) * tr_['levels'], None, '满级',
        f"是（每 {tr_['floors_per_level']} 层开 1 级，30 层开满 10 级）", loc('core/tianqi_money.gd', 'static func training_bonus'), '', status='有效')
    rb = D.brand['realm']['base']
    hp = sum(b['params'].get('mhp', 0) for b in rb)
    put('养成（新发现）', '境底（七境累加）', '生命%', 'param_rate（境线内相加，另乘）', hp, None, '逆命', '拿不准（境的开放层没核）', loc('core/tianqi_brand_realm.gd', 'static func param_rate'),
        '另有物防、魔防、魔法、敏捷各 +5（各一境）', status='有效')
    put('养成（新发现）', '境支（每境一条）', '属性%', '同上', D.brand['realm'].get('branch_pct', 3), None, '每条', '同上', loc('core/tianqi_brand_realm.gd', 'static func param_rate'), '', status='有效')
    put('养成（新发现）', '烙印配满', '⑤伤害（K 口子）', '⑤ 天启篇（独立乘）', pct(D.brand['power']['max_bonus']), None, '烙印 100', '是', loc('core/tianqi_base.gd', 'static func k_actor_mult'),
        '皮薄：物防魔防最多 −' + n(pct(D.brand['costs'].get('thin', {}).get('at_full', 0.25))) + '%', status='有效')
    qd = L(TQ / 'qiyin_dragon.json').get('dragon_blood', {})
    put('养成（新发现）', '七首之龙龙血', '全属性%', 'param_rate（另乘）', pct(qd.get('per_bottle', 0.03)) * qd.get('max_per_actor', 3), pct(qd.get('per_bottle', 0.03)),
        f"{qd.get('max_per_actor', 3)} 瓶", '否（七印祭坛，31 层起）', loc('core/tianqi_qiyin_dragon_run.gd', 'static func param_rate'), '', status='有效')
    for aid, a in D.rw.get('actors', {}).items():
        g = a.get('grow') if isinstance(a, dict) else None
        if isinstance(g, dict):
            cap = max([g.get('cap', 0)] + list((g.get('cap_with') or {}).values()))
            ps = g.get('params', [g.get('param')])
            put('养成（新发现）', '击杀成长', '/'.join(PN[p] for p in ps if p is not None) + '%', 'param_rate（另乘）', pct(cap), None, f"{D.sd['actors'].get(aid, {}).get('name', aid)}（{aid}）",
                '是（要学 %s）' % g.get('need_skill', '—'), loc('core/tianqi_skills.gd', 'static func param_rate(a, i'), f"每次 +{n(pct(g.get('per', 0)))}%", status='有效')
    rr = D.rw.get('rules', {})
    put('养成（新发现）', '技能熟练度（天启篇）', '伤害%', '池外（乘 basis，不进五池、不封顶）', pct(rr.get('mastery_per_level', 0.03)) * rr.get('mastery_cap', 10), None,
        f"{rr.get('mastery_cap', 10)} 级", '是', loc('core/tianqi_skills.gd', 'static func mastery_damage'), '', status='有效')
    gr = L(TQ / 'growth.json')
    for k, a in gr.get('actors', {}).items():
        put('养成（新发现）', '无限成长（%s）' % k, '平加 ' + '/'.join(PN[int(x)] for x in (a.get('flat') or {})), '能力值定值（夹值前，不吃百分比）', None, None, k,
            '是（层数无上限）', loc('core/tianqi_growth.gd', 'static func param_flat'), '每层 %s；层价见 growth.json price' % json.dumps(a.get('flat'), ensure_ascii=False), status='有效')
    put('养成（新发现）', '丹药永久加值／淬元丹／万灵增元丹被动', '属性', '—', 0, None, '—', '天启篇下架（NO_PILLS）、计数不读、被动不生效', loc('core/tianqi_ledger.gd', 'static func pill_delisted'),
        '旧档已吃的一品～四品丹照算（mv_param_plus 分不出来源）', status='不生效')

    # --- 成长神器三族（口径 21：按「现网占位上限」和「存档层数」各报一次，并标启封拿不拿得到）---
    ac = D.gt.get('artifact_cap', {})
    hs_cap = int(ac.get('heartsteel_stage', 10))
    hb_cap = int(ac.get('hubris_stage', 10))
    cr_cap = float(ac.get('crown_bonus_pct', 300))
    r_hs = W.verdict(3, 7900)[0]
    r_hb = W.verdict(3, 7902)[0]
    r_cr = W.verdict(3, 7940)[0]
    put('遗物净印（新发现）', f'成长神器·心之钢／利维坦（现网占位上限 {hs_cap} 阶）', '生命%', 'param 包装（另乘）',
        10 * hs_cap + 10, 10 * hs_cap, f'利维坦 +{(10 * hs_cap + 10)}%／心钢 +{10 * hs_cap}%', r_hs,
        loc('core/tianqi_gear.gd', 'static func heart_stage'), f'artifact_cap.heartsteel_stage={hs_cap}；回合末另回 3%/5% 生命', status='有效')
    put('遗物净印（新发现）', '成长神器·心之钢／利维坦（按存档层数）', '生命%', 'param 包装（另乘，不截层数）',
        None, None, 'n=⌊(√(1+8k/100)-1)/2⌋', r_hs,
        loc('core/heartsteel.gd', 'static func stage_of'), '无硬顶（5500层=10阶；另旧档 _codexHeartsteelHp 平加生命）；实测可达性待核', status='待实测')
    put('遗物净印（新发现）', f'成长神器·狂妄／无我（现网占位上限 {hb_cap} 阶）', '物攻%（扬名）', 'param 包装（另乘）＋物防穿透 18%/27%',
        10 * hb_cap + 20, 10 * hb_cap + 10, f'无我 +{10 * hb_cap + 20}%／狂妄 +{10 * hb_cap + 10}%', r_hb,
        loc('core/tianqi_gear.gd', 'static func hubris_stage'), f'artifact_cap.hubris_stage={hb_cap}；穿透 18%/27% 进公式与钩子', status='有效')
    put('遗物净印（新发现）', '成长神器·狂妄／无我（按存档盛名层数）', '物攻%（扬名）', 'param 包装（另乘，不截盛名）',
        None, None, 'n=⌊(√(1+8k/100)-1)/2⌋', r_hb,
        loc('core/hubris.gd', 'static func rate_for'), '无硬顶；实测可达性与扬名权重待核', status='待实测')
    put('遗物净印（新发现）', f'成长神器·魔冠"头顶"（现网占位上限 +{n(cr_cap)}%）', '八项全属性%', '特性 21（九线 hubris 桶，param_cap 封 +30%）',
        min(cr_cap, param_cap_pct), None, f'封后 +{n(min(cr_cap, param_cap_pct))}%（占位 +{n(cr_cap)}%）', r_cr,
        loc('core/tianqi_gear.gd', 'static func crown_bonus'), f'artifact_cap.crown_bonus_pct={n(cr_cap)}；进九线 param_cap', status='有效')
    put('遗物净印（新发现）', '成长神器·魔冠"头顶"（按存档账本层数）', '八项全属性%', '独立账本 crown_progress_v1.json',
        1000, None, '账本上限 +1000%', r_cr,
        loc('core/demon_crown.gd', 'static func bonus'), 'b=0~1000，胜利 +1-b/1000、死亡减半；启封走占位上限与九线 param_cap', status='待实测')

    # --- 天启篇规则 ---
    cr = D.bt['combat_rules']
    put('天启篇规则（新发现）', '注视 K（全员）', '⑤伤害倍率', '⑤ 天启篇（独立乘）', cr.get('base_damage'), None, '全员', '是', loc('core/tianqi_base.gd', 'static func k_base'), '敌人生命另 ×%s%%' % cr.get('enemy_hp_pct'), status='有效')
    put('天启篇规则（新发现）', '常驻暴击率', '④暴击率%', '暴击率', pct(cr['crit_add']), None, '全员', '是', loc('core/tianqi_no_diff_passive.gd', 'static func xparam_add'), '', status='有效')
    put('天启篇规则（新发现）', '战斗中敏捷', '敏捷%', 'param_rate（traits_pi 加算）', pct(cr['agi_rate']), None, '全员', '是', loc('core/tianqi_no_diff_passive.gd', 'static func traits_pi'), '', status='有效')
    for k, v in D.bt['tiers'].items():
        put('天启篇规则（新发现）', '档位⑤', '⑤伤害%', '⑤ 天启篇（独立乘）', pct(v['damage_dealt']), None, k, '是', loc('core/tianqi_combat.gd', 'static func dealt_parts'), '承伤 %s%%' % n(pct(v['damage_taken'])), status='有效')

    # --- 遗物净印（口径 12：逐类标生效态）---
    rl = L(TQ / 'rewards.json')['relic']['lines']
    fam = rl['famine']['full']
    put('遗物净印（新发现）', '骑士遗物「%s」' % rl['famine']['name'], '全属性%', 'param 包装（乘）', fam['stat_pct'] * (fam['max_stacks'] // fam['stack_step']), fam['stat_pct'],
        '满层', '否（35／36 层骑士给；启封 1～%d 层外）' % FLOOR_MAX, loc('core/tianqi_rewards.gd', 'static func actor_param'), '代价：受到回复 −%s%%' % fam['heal_taken_pct'], status='有效（35/36层）')
    pl_ = rl['plague']['full']
    put('遗物净印（新发现）', '骑士遗物「%s」' % rl['plague']['name'], '双防%', 'param 包装（乘）', pl_['def_pct'], None, '完整版', '同上', loc('core/tianqi_rewards.gd', 'static func actor_param'),
        '代价：造成伤害 −%s%%' % pl_['dmg_dealt_pct'], status='有效（35/36层）')
    put('遗物净印（新发现）', '净印装备（四线）', '机制几率', '不加属性', None, None, '—', '是（开场、10／20／30 层使徒）', loc('core/tianqi_rewards.gd', 'static func actor_param'), '只改各线机制，不加属性与伤害', status='有效')

    # --- 角色专属模块、宠物（口径 12：标生效态）、种族（口径 22：按族按属性分行）---
    put('角色专属模块（新发现）', '米拉、黄泉、甚尔、宿傩、饿狼、云裳、流萤、谷雨、璇、屠苏、小猫剑圣', '各自', 'param 包装链各层', None, None, '各角色', '随角色',
        loc('core/actor.gd', 'func param_before_alien'), '属角色桶，由 T520 角色节按人量（六维 peak）；本节只列位置', status='有效（整场待实测）')
    put('宠物（新发现）', '战宠 push8～14', 'xparam（命中～TP再生）', 'traitsSum 加算', None, None, '出战宠物', '拿不准（宠物线天启篇没开关，照原版生效；数值没量）',
        loc('core/pets.gd', 'static func war_xparam_plus'), '', status='待实测')
    # 口径 22：种族按族、按属性逐行报（照 core/race_battle.gd），不合成一个「属性%」
    qmax, qmed = pct(max(D.races['rates'])), pct(D.races['rates'][2])
    put('种族（新发现）', '种族·人族（race 2）', '八项全属性%', 'param 最外层（固定 ×1.03）', 3, 3, '人族（不随阶涨）', '是',
        loc('core/race_battle.gd', 'static func param('), '另九九六再动几率 q/2（七阶 10%，走回合预算）', status='有效')
    put('种族（新发现）', '种族·蛮族（race 6）', '最大生命%', 'param 最外层（×(1+q)）', qmax, qmed, '蛮族七阶', '是',
        loc('core/race_battle.gd', 'static func param('), '另反攻目标终伤 +1.5q（七阶 +30%，进③）', status='有效')
    put('种族（新发现）', '种族·鬼族（race 4）', '最大魔法%', 'param 最外层（×(1+q)）', qmax, qmed, '鬼族七阶', '是',
        loc('core/race_battle.gd', 'static func param('), '另技能 MP/TP 消耗 ×(1−q/2)（七阶 −10%）', status='有效')
    put('种族（新发现）', '种族·灵族（race 5）', '武器本体八项定值%', 'param_plus（定值＝武器本体×q/2）', qmax / 2.0, qmed / 2.0, '灵族七阶', '是',
        loc('core/race_battle.gd', 'static func param_plus'), '匹配兵器技能终伤 +q（进③）；非面板属性倍率%', status='有效')
    put('种族（新发现）', '种族·神族（race 1）', '③魔法伤害%／首招无视魔防', '③ 伤害加成池（＋q）', qmax, qmed, '神族七阶', '是',
        loc('core/damage.gd', 'facts.race.pooled = true'), '不加能力值%；本回合首次魔法无视 q/2 魔防', status='有效')
    put('种族（新发现）', '种族·魔族（race 3）', '③物理伤害%／④暴伤%', '③（＋q）／④（＋q/2）', qmax, qmed, '魔族七阶', '是',
        loc('core/damage.gd', 'facts.race.pooled = true'), '不加能力值%；物理 +q 进③、暴击倍率 +q/2（七阶 +10%）进④', status='有效')
    put('种族（新发现）', '种族·妖族（race 0）', '③猎物伤害%／降防减伤', '③（＋q/2，残血＋q）', qmax, qmed, '妖族七阶', '是',
        loc('core/damage.gd', 'facts.race.pooled = true'), '不加能力值%；对猎物双防与固定减伤 ×(1−q)', status='有效')

    return rows, detail


def flags(rows, D):
    """第一层标记：单来源上限比本池九线封顶高（含 phase4 ④暴伤 +30%，口径 3）、或是独立乘／池外不封顶的；只摆事实"""
    caps = D.ledger['nine_caps']
    cap_of = {'③伤害加成%': caps['bonus'] * 100, '①技能伤%': caps['skill'] * 100, '②元素伤%(单系)': caps['element'] * 100}
    p4_crit = D.ledger.get('phase4', {}).get('nine_crit_dmg_cap')
    if isinstance(p4_crit, (int, float)) and p4_crit >= 0:
        cap_of['④暴伤%'] = p4_crit * 100
    out = []
    for r in rows:
        top = r['上限'] if isinstance(r['上限'], (int, float)) else None
        c = cap_of.get(r['属性'])
        if top is not None and c is not None and top > c:
            out.append((r, f'单来源 {n(top)} > 九线 {r["属性"][:1]} 封顶 {n(c)}'))
        elif top and ('池外' in r['乘区'] or '另乘' in r['乘区'] or '独立乘' in r['乘区']) and top >= 20:
            out.append((r, f'{n(top)}，{r["乘区"]}'))
    return out


SPREAD = 3  # 类内上限÷中位超过它就展开（协调 11-25 补）


def _reach_ok(r):
    v = str(r['拿得到'])
    return v.startswith('是') or v in ('随技能', '随装备') or '；符石是' in v


def cat_summary(rows):
    out = {}
    by = defaultdict(list)
    for r in rows:
        by[r['大类']].append(r)
    for c, rs in by.items():
        nums = [r for r in rs if isinstance(r['上限'], (int, float)) and r['上限'] > 0]
        top = max(nums, key=lambda r: r['上限']) if nums else None
        m = med([r['上限'] for r in nums])
        ok = [r for r in nums if _reach_ok(r)]
        states = sorted({r.get('生效态', '有效') for r in rs})
        out[c] = {'rows': rs, 'top': top, 'med': m, 'ratio': (top['上限'] / m) if (top and m) else None,
                  'reach_top': max(ok, key=lambda r: r['上限']) if ok else None, 'states': '／'.join(states)}
    return out


def rows_for(D, M):
    return build(D, M)[0]


def section(D, M):
    rows, detail = build(D, M)
    p4_crit = D.ledger.get('phase4', {}).get('nine_crit_dmg_cap', 0.3)
    ac = D.gt.get('artifact_cap', {})
    hs_cap, hb_cap, cr_cap = int(ac.get('heartsteel_stage', 10)), int(ac.get('hubris_stage', 10)), float(ac.get('crown_bonus_pct', 300))
    L = ['', '## 五、外部来源倒查（T521／T535 修口径）', '',
         '由 `07_开发环境/启封数值对账_来源.py` 生成，接在 T520 报告后面。从结算函数倒查：能力值（`core/actor.gd`）、伤害五池（`core/damage.gd`）、九线封顶（`core/tianqi_ledger.gd`，含 `phase4.nine_crit_dmg_cap`＝+%s%%）。已改读天启篇改写后数据（状态／装备／通用书／12 把系别法宝／套装模板）。' % n(round(p4_crit * 100, 2)),
         f'「拿得到」口径（口径 10）：扫描敌人掉落、地图／公共事件、商店与代码掉落，**并检查事件页条件与分支条件**，区分「无条件」与「带事件条件」；代码位置是 `modes/xiyou/` 下相对路径。', '']
    L += ['### 5.1 倒查清单（结算处 → 读到的来源）', '', '| 结算处 | 来源 | 位置 | 归大类 |', '|---|---|---|---|']
    for where, what, f, needle, cat in TRACE:
        L.append(f'| {where} | {what} | `{loc(f, needle)}` | {cat} |')
    order = {c: i for i, c in enumerate(CATS)}
    fl = flags(rows, D)
    flagged_rows = {id(r): why for r, why in fl}
    summ = cat_summary(rows)
    L += ['', '### 5.2 第一层：按大类汇总（外部来源）', '',
          f'每类一行：上限＝类内单来源最大值，中位＝类内各行上限的中位，比值＝上限÷中位（> {SPREAD} 自动展开）。生效态逐类标「有效／不生效／待实测」（口径 12）。', '',
          '| 大类 | 行数 | 生效态 | 上限（来源·属性） | 中位 | 上限÷中位 | 启封拿得到的最高 | 展开 |', '|---|---|---|---|---|---|---|---|']
    expand = []
    for c in sorted(summ, key=lambda c: order.get(c, 99)):
        x = summ[c]
        why = []
        if any(id(r) in flagged_rows for r in x['rows']):
            why.append('有行超封顶／池外')
        if x['ratio'] is not None and x['ratio'] > SPREAD:
            why.append(f'比值 > {SPREAD}')
        if why:
            expand.append(c)
        t = x['top']
        L.append(f"| {c} | {len(x['rows'])} | {x['states']} | {n(t['上限']) if t else '—'}（{t['来源'] + '·' + t['属性'] if t else '—'}） | {n(x['med'])} | {n(x['ratio'])} | "
                 f"{(n(x['reach_top']['上限']) + '（' + x['reach_top']['来源'] + '·' + x['reach_top']['属性'] + '）') if x['reach_top'] else '—'} | {'、'.join(why) or '—'} |")
    L += ['', '### 5.3 第二层：展开的大类逐行', '']
    for c in sorted(expand, key=lambda c: order.get(c, 99)):
        L += [f'**{c}**', '', '| 来源 | 属性 | 乘区 | 上限 | 常见值 | 谁 | 生效态 | 启封拿得到 | 标记 | 位置 |', '|---|---|---|---|---|---|---|---|---|---|']
        for r in summ[c]['rows']:
            L.append(f"| {r['来源']} | {r['属性']} | {r['乘区']} | {n(r['上限'])} | {n(r['常见值'])} | {r['谁']} | {r.get('生效态', '有效')} | {r['拿得到']} | {flagged_rows.get(id(r), '')} | `{r['位置']}` |")
        L.append('')
    nx = [c for c in summ if c not in expand]
    L += ['没展开的：' + ('、'.join(sorted(nx, key=lambda c: order.get(c, 99))) or '无') + '（明细见 --json「行」）。', '']
    L += ['', '### 5.4 第二层：法宝逐件（已套 12 把系别法宝改写，按最大标签值排，前 15；全量进 --json）', '', '| 法宝 | 编号 | 标签 | 启封拿得到 | 来源（前几条） |', '|---|---|---|---|---|']
    for d in detail['法宝'][:15]:
        tg = '，'.join(f'{k} {n(v)}' for k, v in d['标签'].items())
        L.append(f"| {d['法宝']} | {d['种类']}{d['编号']} | {tg} | {d['拿得到']} | {'；'.join(d['来源']) or '—'} |")
    ok = [d for d in detail['法宝'] if d['拿得到'].startswith('是')]
    L += ['', f"带标签的法宝 {len(detail['法宝'])} 件，启封拿得到 {len(ok)} 件、拿不准 {sum(1 for d in detail['法宝'] if d['拿得到'].startswith('拿不准'))} 件、拿不到 {sum(1 for d in detail['法宝'] if d['拿得到'].startswith('否'))} 件。", '']
    L += ['### 5.5 不生效／不加数的（列出来免得再查）', '',
          '- 真气：伤害 growthMultiplier 天启篇恒 1（`%s`）；道法连击、分神天启篇停（NINE_OFF）。' % loc('core/zhenqi.gd', 'static func damage_mult'),
          '- 称号：只有名字、图标、颜色，不加属性（`%s`）。' % loc('core/designation.gd', 'class_name XDesignation'),
          '- 光耀度（口径 14，不单列成来源）：不另加数，只是符石／宝石定值随装备等级的换算比显示，80 级＝100%%（`%s`）。' % loc('core/tianqi_gem_power.gd', 'static func power_of'),
          '- 丹药：天启篇下架；淬元丹计数不读；万灵增元丹被动 5974～5977 不生效（`%s`）。' % loc('core/tianqi_ledger.gd', 'static func pill_delisted'),
          '- 职业属性倍率：天启篇不算（`%s`）。' % loc('core/tianqi_base.gd', 'static func class_rate_strip'),
          '- 原版独立乘区 SelfPhysRate／SelfElemRate：天启篇不读（`%s`）。' % loc('core/damage.gd', 'static func _self_rates'), '']
    L += ['### 5.6 拿不准', '',
          '- 「拿得到」已扫描事件页条件与分支条件并标出「带事件条件」，但未在运行时模拟全部开关组合与方桌大厅货架滤链；方桌大厅与公共事件来源仍标「拿不准」。',
          '- 强化孔数按 YEP_X_ItemUpgradeSlots 报 0～12 孔（默认 6±6）；实际掉落各装备孔数分布未逐件跑存档统计。',
          '- 法宝、符文之语已按启封改写表（skill_rework.gear＋12 把系别法宝＋T451 元素增幅）解析；九线封顶含 phase4 ④暴伤 +30%（已开）。',
          f'- 成长神器三族（心之钢／狂妄／魔冠）按现网占位上限（{hs_cap}阶／{hb_cap}阶／{n(cr_cap)}%）与存档层数双口径报，1～30 层深渊实际进出条件与扬名权重待实测。',
          '- 境的开放层、门派线、宠物天启篇数值未实测，均标「待实测」。', '']
    return '\n'.join(L) + '\n'


def detail_json(D, M):
    rows, detail = build(D, M)
    summ = {c: {k: v for k, v in x.items() if k != 'rows'} for c, x in cat_summary(rows).items()}
    return {'行': rows, '大类汇总': summ, '明细': detail, '倒查清单': [{'结算处': w, '来源': s, '位置': loc(f, nd), '大类': c} for w, s, f, nd, c in TRACE]}


def main():
    import argparse
    sys.path.insert(0, str(HERE))
    import importlib
    M = importlib.import_module('启封数值对账')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--json')
    a = ap.parse_args()
    D = M.Data()
    print(section(D, M))
    if a.json:
        Path(a.json).write_text(json.dumps(detail_json(D, M), ensure_ascii=False, indent=1, default=str), encoding='utf-8')
        print('写了', a.json)


if __name__ == '__main__':
    main()
