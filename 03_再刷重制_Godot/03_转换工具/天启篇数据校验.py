#!/usr/bin/env python3
"""天启篇数据表校验（只用标准库，云端没有 Godot 和转换产物也能跑）。

  python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py [--params <设计仓库>/重制设定/数值测算/参数.json]

每张表一个检查函数，登记在 CHECKS 里；表文件不在就跳过那一张（打印「跳过」）。
- balance_table.json（档位与五档难度）：
  A 组：和设计仓库的测算 参数.json 逐项对照。不给 --params 时跳过（游戏仓库公开，检查.sh 里没有设计仓库）。
  B 组：规则自检，和 tests/xiyou_tianqi_balance 同一套（难度键与 core/tianqi.gd 的 DIFFICULTIES 用正则对照）。
- horsemen.json（天启四骑士）：
  A 组：和 参数.json「骑士」一节逐项对照（生命、攻防、行动、系数、计量、终焉、骑士血量倍率）；不给 --params 时跳过。
  B 组：规则自检（五档骑士血量倍率齐全）。
- war_line.json、famine_line.json、plague_line.json、death_line.json（各线关卡流程与异化，XTianqiLine）：只有 B 组，预设和台词齐全、开场步骤用到的台词／地图／坐标／预设都在表里。
- summit.json（31～36 层重做）：只有 B 组，34～36 层齐全、台词齐全。
- seg_alien.json（按段异化，四线共用）：只有 B 组，1～36 层段表连续不重叠、级名和难度键齐全、几率在 0～100。
- qiyin_gear.json、qiyin_drop.json、qiyin_dragon.json、qiyin_altar.json（七印祭坛）：只有 B 组，印键只有七个、部位键只有六个、几率在 0～1、权重非负且不全为 0；qiyin_gear 另查类型号在 core/tianqi_gear.gd 的 ORDER 里、七套各 6 件、毕业武器 13 把、神器 5 件；跨表查另三张引用的套装、武器、神器、印、部位都在 qiyin_gear 里。只查表里现有的字段，不认识的键不报错。
- skill_rework.json（全角色技能重构）：forced_copy_pending（T255 登记：技能号→原因）、forced_copy_unreachable（T261：副本分支天启篇走不到，技能号→原因）；卡里技能的效果 44 调公共事件强制放副本、副本没进卡的，要 effects_remove 或副本进卡或登记；只有 B 组，超强者 17（含五条悟）／强者 52 不重叠、技能行系数大于 0、覆盖层全开后系数和属性权重不得有小数（整数或整数百分比，T191）、治疗比例与追加几率在 0～1；状态行 battle_end 是布尔（T263）；技能行 self_states_on_hit 只能是 true 且要带 self_states（T264）；技能行 cast_pick、seg_elements_of、伤害条件 stat_floor 的格式（T268）。
- reforge.json、alien_gear.json、abyss_shelves.json、qiyin_equip.json、qiyin_show.json、qiyin_dragon_run.json（重铸、异化装备、深渊商人货架、七印装备底子、七印演出、七首之龙流程）：只有 B 组，只查代码读的字段，类型和范围（几率 0～1、百分比 0～100、花费非负、随阶／随级不降、颜色 #RRGGBB、能力值 8 项）；跨表查货架的层和阶在 affix_table、品质在 tianqi_affix_roll.gd 的 QUALITY_KEYS、异化词条在 rewards.json 的 finale.lines、七印装备的部位和武器类型与 qiyin_gear 对得上、演出的印齐七个；参照表不在就跳过那一项。
- brand.json（烙印，T073-a）：只有 B 组，节点递增且末项 100、配满加成不超过 0.5、不刻印封顶是节点之一且正好是 uncarved_max_realm 那境、换伤支四条且伤害＝承伤、常驻六条发作六种齐且 over 照节点、熟的花样名单是六种的子集且不含抽自己／六亲不认／换人、灼痕各级递增、首通加起来不超过 100 且每 5 层末等于节点、折法＝满了才算、带 _range 的数落在范围里。稿定的数带 4。
- guardian_params.json（守层者能力值重锚，T237／T245）：只有 B 组，ref_enemy 是正整数、stats 八项对 0～7、floors 只有 31～34 层、qiyin 行（可没有）和每层只写 stats 里的项（下划线开头的注释键除外）、取值是正整数百分比（附则 E）。
- growth.json（渡鸦、奈叶、流萤无限成长，T256）：只有 B 组，全表整数（附则 E）、层价分段从 1 层起连续且份数不降、翻倍倍数 ≥2、拐点在分段里、Q6 判定四项范围、三人行齐全且角色号对、一份是正整数、平加只认能力编号 0～7 且渡鸦只加魔攻、奈叶只加生命魔法、流萤不走平加。
- six_dim.json（天启篇六维，T275）：只有 B 组，八档刻度、全整数（附则 E）、韧性抗控表 −10～+10 随档不降、R1～R3（SSS 唯一极化、SS 其余五维至少 2 项 ≤C、S 稀有度）逐份过，R4 分档总分只报告不拦（T280）、普通怪模板 8～10 个、样板角色号在 base_line.json、骑士键同 horsemen.json。\n有不一致就逐条打印「项、游戏数据、参数.json」，退出码 1；全过退出码 0。
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
DATA_DIR = PROJECT / 'modes' / 'xiyou' / 'tianqi_data'
TIANQI_GD = PROJECT / 'modes' / 'xiyou' / 'core' / 'tianqi.gd'

EPS = 1e-9
WEAK, STRONG, SUPER = '弱者', '强者', '超强者'  # 同 core/tier.gd 的 XTier 常量
FIELD_SIZE = 4  # 同一场上场人数，同 XTianqiBalance.FIELD_SIZE
# 难度一行里 scaling 的键 → 参数.json「难度」的键
SCALING_KEYS = {'enemy_hp': '敌人血量', 'enemy_atk': '敌人攻击', 'party_damage': '我方伤害', 'quality_offset': '品质偏移'}
ROSTER_KEYS = {'pool': '候选池', 'super_cap': '超强者上限', 'min_weak': '至少弱者', 'helper_super': '助力位放超强者'}
TIER_KEYS = {'damage_dealt': '出伤', 'damage_taken': '承伤', 'secret_cap': '秘籍上限'}


def num_text(x) -> str:
    """和 XTianqiBalance._num_text 一样：整数不带小数点，其余去掉尾零。"""
    x = float(x)
    if x == int(x):
        return str(int(x))
    return ('%.6f' % x).rstrip('0').rstrip('.')


def same(a, b) -> bool:
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return abs(float(a) - float(b)) < EPS
    return a == b


def tianqi_difficulties(path: Path = TIANQI_GD) -> list:
    """从 core/tianqi.gd 的 DIFFICULTIES 取 key、name、super_cap、min_weak（只读）。"""
    text = path.read_text(encoding='utf-8')
    m = re.search(r'const DIFFICULTIES := \[(.*?)\n\]', text, re.S)
    if not m:
        raise ValueError('tianqi.gd 里找不到 DIFFICULTIES')
    out = []
    for line in m.group(1).splitlines():
        if '"key"' not in line:
            continue
        row = {}
        for k in ('key', 'name'):
            row[k] = re.search(r'"%s":\s*"([^"]*)"' % k, line).group(1)
        for k in ('super_cap', 'min_weak'):
            # 第三批起 tianqi.gd 不再写这两项（difficulty() 并自本表，单一来源）；没写就不对照
            m2 = re.search(r'"%s":\s*(-?\d+)' % k, line)
            row[k] = int(m2.group(1)) if m2 else None
        out.append(row)
    return out


# ---- balance_table.json ----

def tier_mult(table, tier, key):
    return 1.0 + float(table['tiers'][tier][key])


def assist(table, weak_count, key):
    n = max(0, min(weak_count, FIELD_SIZE))
    return n * float(table['weak_assist'][key])


def team(table, tiers, kind):
    """全队相对出伤（kind='damage'）或承伤（'taken'）：Σ(1＋档位) ×(1＋上场弱者数×协力)。"""
    tk, ak = ('damage_dealt', 'damage_dealt_per') if kind == 'damage' else ('damage_taken', 'damage_taken_per')
    return sum(tier_mult(table, t, tk) for t in tiers) * (1.0 + assist(table, tiers.count(WEAK), ak))


def balance_rules(table: dict, tianqi: list) -> list:
    """B 组规则自检，返回失败说明列表。"""
    bad = []

    def check(name, ok, detail=''):
        if not ok:
            bad.append('%s：%s' % (name, detail))

    # 1. 齐全、与 tianqi.gd 一致
    for h in ('version', 'source', 'dev'):
        check('表头 ' + h, str(table.get(h, '')) != '')
    tiers = table.get('tiers', {})
    check('档位只有三个', sorted(tiers) == sorted([WEAK, STRONG, SUPER]), list(tiers))
    for t in (WEAK, STRONG, SUPER):
        check('档位齐全：' + t, all(k in tiers.get(t, {}) for k in TIER_KEYS), tiers.get(t))
    if bad:
        return bad
    diffs = table.get('difficulties', [])
    keys = [d.get('key') for d in diffs]
    want = [d['key'] for d in tianqi]
    check('难度键与顺序同 tianqi.gd', keys == want, '表 %s，tianqi.gd %s' % (keys, want))
    by_key = {d.get('key'): d for d in diffs}
    for x in tianqi:
        d = by_key.get(x['key'])
        if d is None:
            continue
        r = d.get('roster', {})
        check('难度名同开局：' + x['key'], d.get('name') == x['name'], '%s / %s' % (d.get('name'), x['name']))
        for k in ('super_cap', 'min_weak'):
            if x[k] is not None:
                check('%s 同开局：%s' % (k, x['key']), r.get(k) == x[k], '表 %s，tianqi.gd %s' % (r.get(k), x[k]))
        cap = x['super_cap'] if x['super_cap'] is not None else r.get('super_cap', 0)
        pool_want = [WEAK, STRONG] + ([SUPER] if cap > 0 else [])
        check('候选池同开局规则：' + x['key'], r.get('pool') == pool_want, '表 %s，应为 %s' % (r.get('pool'), pool_want))
        for k in SCALING_KEYS:
            check('难度有 %s：%s' % (k, x['key']), isinstance(d.get('scaling', {}).get(k), (int, float)))
    if bad:
        return bad
    # 2. 档位单调
    w, s, u = (tier_mult(table, t, 'damage_dealt') for t in (WEAK, STRONG, SUPER))
    check('出伤 弱 < 强 < 超强', w < s < u, (w, s, u))
    tw, ts, tu = (tier_mult(table, t, 'damage_taken') for t in (WEAK, STRONG, SUPER))
    check('承伤 弱 ≥ 强 ≥ 超强', tw >= ts >= tu, (tw, ts, tu))
    cw, cs, cu = (tiers[t]['secret_cap'] for t in (WEAK, STRONG, SUPER))
    check('秘籍上限 弱 ≥ 强 ≥ 超强', cw >= cs >= cu, (cw, cs, cu))
    # 3. 档位盖过本体 ±20%（测算报告第一节同名两项）
    check('档位盖过本体浮动（强者对弱者）', 0.8 * s >= 1.2 * w - EPS, '0.8×%.3f < 1.2×%.3f' % (s, w))
    check('档位盖过本体浮动（超强者对强者）', 0.8 * u > 1.2 * s + EPS, '0.8×%.3f ≤ 1.2×%.3f' % (u, s))
    # 4. 协力不让弱者多的队更强（强者、超强者各换一遍）
    check('协力给出伤、减承伤', assist(table, 1, 'damage_dealt_per') > 0 and assist(table, 1, 'damage_taken_per') < 0)
    aura = float(table.get('assist_slot', {}).get('team_damage_dealt', 0))
    check('助力位光环在 0～1 之间', 0 < aura < 1, aura)
    for other in (STRONG, SUPER):
        for weak in range(FIELD_SIZE, 0, -1):
            more = [WEAK] * weak + [other] * (FIELD_SIZE - weak)
            less = [WEAK] * (weak - 1) + [other] * (FIELD_SIZE - weak + 1)
            dm, dl = team(table, more, 'damage'), team(table, less, 'damage')
            check('协力：%d弱 出伤低于 %d弱（换%s）' % (weak, weak - 1, other), dm < dl - EPS, '%.4f ≥ %.4f' % (dm, dl))
            tm, tl = team(table, more, 'taken'), team(table, less, 'taken')
            check('协力：%d弱 承伤高于 %d弱（换%s）' % (weak, weak - 1, other), tm > tl + EPS, '%.4f ≤ %.4f' % (tm, tl))
    # 5. 难度单调、低难度没有超强者
    for a, b in zip(diffs, diffs[1:]):
        for k in ('enemy_hp', 'enemy_atk'):
            va, vb = a['scaling'][k], b['scaling'][k]
            check('%s 不降：%s→%s' % (k, a['key'], b['key']), vb >= va, '%s → %s' % (va, vb))
    for k in ('xunchang', 'jianxian'):
        r = by_key.get(k, {}).get('roster', {})
        check('低难度候选池没有超强者：' + k, SUPER not in r.get('pool', []) and r.get('super_cap') == 0, r)
    return bad


def balance_vs_params(table: dict, params: dict) -> list:
    """A 组：逐项对照 参数.json，返回 (项, 游戏数据, 参数.json) 列表。"""
    diff = []

    def cmp(item, game, ref):
        if not same(game, ref):
            diff.append((item, game, ref))

    for t in (WEAK, STRONG, SUPER):
        for k, pk in TIER_KEYS.items():
            cmp('档位/%s/%s' % (t, pk), table['tiers'].get(t, {}).get(k), params['档位'].get(t, {}).get(pk))
    wa, pa = table['weak_assist'], params['弱者协力']
    cmp('弱者协力/每人出伤', wa.get('damage_dealt_per'), pa.get('每人出伤'))
    cmp('弱者协力/每人承伤', wa.get('damage_taken_per'), pa.get('每人承伤'))
    cmp('助力位/光环全队出伤', table['assist_slot'].get('team_damage_dealt'), params['助力位'].get('光环全队出伤'))
    pd = params['难度']
    names = [d.get('name') for d in table['difficulties']]
    cmp('难度/顺序', names, pd.get('顺序'))
    for d in table['difficulties']:
        ref = pd.get(d.get('name'), {})
        for k, pk in SCALING_KEYS.items():
            cmp('难度/%s/%s' % (d.get('name'), pk), d.get('scaling', {}).get(k), ref.get(pk))
        for k, pk in ROSTER_KEYS.items():
            cmp('难度/%s/%s' % (d.get('name'), pk), d.get('roster', {}).get(k), ref.get(pk))
    return diff


def check_balance_table(params_path) -> bool:
    path = DATA_DIR / 'balance_table.json'
    if not path.is_file():
        print('跳过：没有 %s' % path.name)
        return True
    table = json.loads(path.read_text(encoding='utf-8'))
    ok = True
    bad = balance_rules(table, tianqi_difficulties())
    if bad:
        ok = False
        print('balance_table.json 规则自检 %d 项不过：' % len(bad))
        for b in bad:
            print('  ' + b)
    else:
        print('balance_table.json 规则自检：通过')
    if params_path is None:
        print('balance_table.json 对照参数：跳过：没有参数.json')
        return ok
    params = json.loads(Path(params_path).read_text(encoding='utf-8'))
    diff = balance_vs_params(table, params)
    if diff:
        ok = False
        print('balance_table.json 和 参数.json 有 %d 项不一致（项、游戏数据、参数.json）：' % len(diff))
        for item, game, ref in diff:
            print('  %s：%s ≠ %s' % (item, json.dumps(game, ensure_ascii=False), json.dumps(ref, ensure_ascii=False)))
    else:
        print('balance_table.json 对照参数：通过（%s）' % params_path)
    return ok


# ---- horsemen.json（天启四骑士） ----

LINE_NAMES = {'death': '死亡', 'war': '战争', 'famine': '饥荒', 'plague': '瘟疫'}
DIFF_NAMES = {'xunchang': '寻常', 'jianxian': '艰险', 'jiusi': '九死', 'lianyu': '炼狱', 'zhengdao': '证道'}
# (骑士, 游戏表里的路径, 参数.json 里的键)
HORSEMEN_FIELDS = [
    ('death', 'hp', '生命'), ('death', 'atk', '攻击'), ('death', 'def', '防御'), ('death', 'mdf', '魔防'),
    ('death', 'actions', '每回合行动'), ('death', 'gems/red', '红宝石'), ('death', 'gems/blue', '蓝宝石'), ('death', 'gems/holy', '圣水'),
    ('death', 'follow_coef', '普攻系数'), ('death', 'holy_sword/every', '神圣剑间隔'), ('death', 'captain', '骑士队长'),
    ('death', 'finale/full', '终末满层'), ('death', 'finale/coef', '终末大招系数'),
    ('war', 'hp', '生命'), ('war', 'mat', '魔攻'), ('war', 'def', '防御'), ('war', 'actions', '每回合行动'), ('war', 'max_extra', '再动上限'),
    ('war', 'reinforce/every', '援军间隔'), ('war', 'reinforce/per_wave', '援军每波'), ('war', 'reinforce/max_adds', '援军上限'),
    ('war', 'sparks/rally', '号令'), ('war', 'crit', '暴击率'), ('war', 'crit_mult', '爆伤倍率'),
    ('war', 'crackle/coef', '三响每段'), ('war', 'crackle/bonus_hits', '连珠三响加段'), ('war', 'wave/coef', '焰浪每段'),
    ('war', 'wave/bonus_hits', '连珠焰浪加段'), ('war', 'wave/spark_chance', '焰浪三倍几率'), ('war', 'wave/burn', '灼烧'),
    ('war', 'wave/kindle_hits', '添柴加段'), ('war', 'kindle/cooldown', '添柴冷却'), ('war', 'bomb/coef', '雷火弹每段'),
    ('war', 'bomb/fire_hits', '雷火弹火段'), ('war', 'bomb/cooldown', '雷火弹冷却'), ('war', 'bomb/shrapnel_hits', '碎甲加段'),
    ('war', 'bomb/resist_down', '碎甲'), ('war', 'bomb/turns', '碎甲回合'), ('war', 'bomb/special', '莉co特调'),
    ('war', 'bomb/fire_up', '雷火弹火伤'), ('war', 'bomb/fire_cap', '雷火弹火伤上限'), ('war', 'fireworks/coef', '漫天烟火每段'),
    ('war', 'fireworks/hits', '漫天烟火段数'), ('war', 'fireworks/bonus_hits', '满天星火加段'), ('war', 'fireworks/fuse', '引信已燃'),
    ('war', 'fireworks/cooldown', '漫天烟火冷却'), ('war', 'sparks/barrage_per', '炮火连天每动'),
    ('famine', 'hp', '生命'), ('famine', 'mat', '魔攻'), ('famine', 'def', '防御'), ('famine', 'actions', '每回合行动'),
    ('famine', 'start_adds', '开场小怪'), ('famine', 'devour', '结党吞噬'), ('famine', 'devour_up', '结党增伤'),
    ('famine', 'seniority/per', '资历每层倍率'), ('famine', 'seniority/lines', '资历线'), ('famine', 'sea/coef', '题海系数'),
    ('famine', 'landing/coef', '上岸系数'), ('famine', 'bankrupt/every', '破产一剑间隔'), ('famine', 'bankrupt/coef', '破产一剑系数'),
    ('famine', 'sword_rain/every', '百亿仙剑间隔'), ('famine', 'sword_rain/hits', '百亿仙剑段数'), ('famine', 'sword_rain/coef', '百亿仙剑每段'),
    ('famine', 'sword_rain/all_up', '百亿仙剑全属性'),
    ('plague', 'hp', '生命'), ('plague', 'atk', '攻击'), ('plague', 'def', '防御'), ('plague', 'actions', '每回合行动'),
    ('plague', 'self_atk_down', '自我修养降攻'), ('plague', 'self_reduce', '自我修养减伤'), ('plague', 'taunt_reduce', '不服削伤'),
    ('plague', 'bash/coef', '盾击系数'), ('plague', 'plague/down_start', '疫病开局降属性'), ('plague', 'plague/down_per', '疫病每回合降属性'),
    ('plague', 'plague/down_cap', '疫病降属性上限'), ('plague', 'plague/dot', '疫病每回合掉血'), ('plague', 'plague/confuse', '疫病混乱几率'),
    ('plague', 'frail/per', '病弱每个减益'), ('plague', 'frail/cap', '病弱上限'), ('plague', 'defiance/per_add', '不服每回合'),
    ('plague', 'defiance/full', '不服满层'), ('plague', 'shield/break', '破盾累计'),
]


def _path(d, path):
    for k in path.split('/'):
        if not isinstance(d, dict):
            return None
        d = d.get(k)
    return d


def horsemen_vs_params(table: dict, params: dict) -> list:
    diff = []
    pk = params.get('骑士', {})

    def cmp(item, game, ref):
        if not same(game, ref):
            diff.append((item, game, ref))

    for line, path, key in HORSEMEN_FIELDS:
        cmp('%s/%s' % (LINE_NAMES[line], key), _path(table['knights'].get(line, {}), path), pk.get(LINE_NAMES[line], {}).get(key))
    for k, name in DIFF_NAMES.items():
        cmp('骑士血量倍率/' + name, table.get('hp_rate', {}).get(k), pk.get('血量难度倍率', {}).get(name))
    cmp('阶段门槛', table.get('phase_hp'), pk.get('阶段门槛'))
    cmp('死亡/死期间隔', [_path(table['knights']['death'], 'doom/interval'), _path(table['knights']['death'], 'doom/phase_interval')],
        pk.get('死亡', {}).get('死期间隔'))
    cmp('瘟疫/三阶段破盾倍数', round(_path(table['knights']['plague'], 'shield/break3') / _path(table['knights']['plague'], 'shield/break'), 1),
        pk.get('瘟疫', {}).get('三阶段破盾倍数'))
    for k, name in DIFF_NAMES.items():
        ref = pk.get('瘟疫', {}).get('各档生命', {}).get(name)
        if ref is not None:
            cmp('瘟疫/各档生命/' + name, table['knights']['plague'].get('hp_override', {}).get(k), ref)
    return diff


def horsemen_rules(table: dict) -> list:
    bad = []
    if set(table.get('hp_rate', {})) != set(DIFF_NAMES):
        bad.append('骑士血量倍率不是五档齐全：%s' % sorted(table.get('hp_rate', {})))
    if set(table.get('knights', {})) != set(LINE_NAMES):
        bad.append('四骑士不齐：%s' % sorted(table.get('knights', {})))
    return bad


def check_horsemen(params_path) -> bool:
    path = DATA_DIR / 'horsemen.json'
    if not path.is_file():
        print('跳过：没有 %s' % path.name)
        return True
    table = json.loads(path.read_text(encoding='utf-8'))
    ok = True
    bad = horsemen_rules(table)
    if bad:
        ok = False
        print('horsemen.json 规则自检 %d 项不过：' % len(bad))
        for b in bad:
            print('  ' + b)
    else:
        print('horsemen.json 规则自检：通过')
    if params_path is None:
        print('horsemen.json 对照参数：跳过：没有参数.json')
        return ok
    diff = horsemen_vs_params(table, json.loads(Path(params_path).read_text(encoding='utf-8')))
    if diff:
        ok = False
        print('horsemen.json 和 参数.json 有 %d 项不一致（项、游戏数据、参数.json）：' % len(diff))
        for item, game, ref in diff:
            print('  %s：%s ≠ %s' % (item, json.dumps(game, ensure_ascii=False), json.dumps(ref, ensure_ascii=False)))
    else:
        print('horsemen.json 对照参数：通过（%s）' % params_path)
    return ok


# ---- war_line.json（战争线） ----

WAR_PRESETS = ['omen', 'spread', 'apostle10', 'apostle20', 'apostle30']
WAR_SCENES = ['choose', 'omen_before', 'omen_arrive', 'omen_win', 'spread_before', 'spread_win', 'lose_retry', 'rift_before',
              'rift_survived', 'rift_lost', 'rift_after', 'rift_home', 'apostle10', 'apostle20', 'apostle30', 'echo15', 'rumor25',
              'shadow_before', 'final_before', 'final_win', 'final_lost']


def war_line_rules(table: dict) -> list:
    bad = []
    miss = [k for k in WAR_PRESETS if k not in table.get('presets', {})]
    if miss:
        bad.append('缺异化预设：%s' % miss)
    miss = [k for k in WAR_SCENES if not table.get('scenes', {}).get(k)]
    if miss:
        bad.append('缺台词：%s' % miss)
    return bad


def line_rules(table: dict) -> list:
    """四线共用（XTianqiLine）：开场每节的步骤只用 say／go／fight，用到的台词、地图、坐标、预设都在表里。"""
    bad = war_line_rules(table)
    scenes = table.get('scenes', {})
    for i, steps in enumerate(table.get('opening', [])):
        for st in steps:
            if st[0] == 'say' and not scenes.get(st[1]):
                bad.append('开场第 %d 节缺台词：%s' % (i + 1, st[1]))
            elif st[0] == 'go' and (st[1] not in table.get('maps', {}) or st[2] not in table.get('pos', {})):
                bad.append('开场第 %d 节缺地图或坐标：%s' % (i + 1, st[1:]))
            elif st[0] == 'fight' and st[1] not in table.get('presets', {}):
                bad.append('开场第 %d 节缺预设：%s' % (i + 1, st[1]))
            elif st[0] not in ('say', 'go', 'fight'):
                bad.append('开场第 %d 节不认识的步骤：%s' % (i + 1, st[0]))
    for beat, m in table.get('beats', {}).items():
        if m not in table.get('maps', {}) or not scenes.get(beat):
            bad.append('楼层节点缺地图或台词：%s' % beat)
    for k in ('hall', 'tianwai'):
        if k not in table.get('maps', {}) or k not in table.get('pos', {}):
            bad.append('缺地图或坐标：%s' % k)
    return bad


def check_line(name: str) -> bool:
    path = DATA_DIR / ('%s_line.json' % name)
    if not path.is_file():
        print('跳过：没有 %s' % path.name)
        return True
    bad = line_rules(json.loads(path.read_text(encoding='utf-8')))
    for b in bad:
        print('  ' + b)
    print('%s 规则自检：' % path.name + ('通过' if not bad else '%d 项不过' % len(bad)))
    return not bad


def check_war_line(_args) -> bool:
    return check_line('war')


# ---- summit.json（31～36 层重做） ----

SUMMIT_SCENES = ['door', 'door_top', 'arrive34', 'arrive35', 'arrive36', 'ask', 'hongjun_before', 'hongjun_win', 'hongjun_lost',
                 'shadow_win', 'lost', 'not_ready', 'honghuang_ask', 'honghuang_done', 'honghuang_skip', 'rechallenge_head']


def summit_rules(table: dict) -> list:
    bad = []
    top, low = int(table.get('top', 0)), int(table.get('from', 0))
    miss = [n for n in range(low, top + 1) if str(n) not in table.get('floors', {})]
    if not low or top < low or miss:
        bad.append('层不齐：from=%s top=%s 缺 %s' % (low, top, miss))
    for n, f in table.get('floors', {}).items():
        if f.get('boss') not in ('hongjun', 'shadow', 'final') or len(f.get('pos', [])) != 3 or len(f.get('tone', [])) != 4:
            bad.append('%s 层数据不全：%s' % (n, f))
    if len(table.get('hongjun', {}).get('rate', [])) != 8:
        bad.append('鸿钧 rate 要 8 项')
    miss = [k for k in SUMMIT_SCENES if not table.get('scenes', {}).get(k)]
    if miss:
        bad.append('缺台词：%s' % miss)
    return bad


def check_summit(_args) -> bool:
    path = DATA_DIR / 'summit.json'
    if not path.is_file():
        print('跳过：没有 %s' % path.name)
        return True
    bad = summit_rules(json.loads(path.read_text(encoding='utf-8')))
    for b in bad:
        print('  ' + b)
    print('summit.json 规则自检：' + ('通过' if not bad else '%d 项不过' % len(bad)))
    return not bad


# ---- seg_alien.json（按段异化） ----

SEG_CLASSES = ['rare', 'very_rare', 'guardian', 'abyss']
SEG_DIFFS = ['xunchang', 'jianxian', 'jiusi', 'lianyu', 'zhengdao']


def seg_alien_rules(table: dict) -> list:
    bad = []
    tiers = table.get('tiers', [])
    want = 1
    for seg in table.get('segments', []):
        if int(seg.get('from', 0)) != want:
            bad.append('段表不连续：%s 从 %s 起，应从 %d 起' % (seg.get('name'), seg.get('from'), want))
        want = int(seg.get('to', 0)) + 1
        for cls in SEG_CLASSES:
            row = seg.get(cls)
            if row is None:
                continue
            if row.get('tier') not in tiers or (row.get('up') and row.get('up') not in tiers):
                bad.append('%s %s 级名不对' % (seg.get('name'), cls))
            for k in ('rate', 'up_rate'):
                if not 0 <= float(row.get(k, 0)) <= 100:
                    bad.append('%s %s %s 不在 0～100' % (seg.get('name'), cls, k))
    if want - 1 != int(table.get('floor_max', 0)):
        bad.append('段表到 %d 层，floor_max 是 %s' % (want - 1, table.get('floor_max')))
    miss = [d for d in SEG_DIFFS if d not in table.get('difficulty', {})]
    if miss:
        bad.append('缺难度：%s' % miss)
    return bad


def check_seg_alien(_args) -> bool:
    path = DATA_DIR / 'seg_alien.json'
    if not path.is_file():
        print('跳过：没有 %s' % path.name)
        return True
    bad = seg_alien_rules(json.loads(path.read_text(encoding='utf-8')))
    for b in bad:
        print('  ' + b)
    print('seg_alien.json 规则自检：' + ('通过' if not bad else '%d 项不过' % len(bad)))
    return not bad


# ---- gear_table.json（装备栏第二批：坐骑、神器上限、掉落重抽；占位数，draft）----

MOUNT_GRADES = ['普通', '优秀', '精良', '史诗', '传说', '不朽', '神话']  # 同 core/quality.gd 的七档顺序
GEAR_CAP_KEYS = ('heartsteel_stage', 'hubris_stage', 'crown_bonus_pct')


def gear_rules(table: dict) -> list:
    """装备表规则自检（与 tests/xiyou_tianqi_gear2 的 table_* 同一套），返回失败说明列表。"""
    bad = []

    def check(name, ok, detail=''):
        if not ok:
            bad.append('%s：%s' % (name, detail))

    for h in ('version', 'source'):
        check('表头 ' + h, str(table.get(h, '')) != '')
    check('标 draft', table.get('draft') is True, table.get('draft'))
    m = table.get('mount', {})
    check('坐骑七档', m.get('grades') == MOUNT_GRADES, m.get('grades'))
    for k in ('agi_pct', 'preempt_pct'):
        v = m.get(k, [])
        check('坐骑 %s 七个数' % k, isinstance(v, list) and len(v) == 7, v)
        if isinstance(v, list) and len(v) == 7:
            check('坐骑 %s 随品质不降' % k, all(v[i] <= v[i + 1] for i in range(6)), v)
            check('坐骑 %s 都是正数' % k, all(isinstance(x, (int, float)) and x > 0 for x in v), v)
    cap = m.get('preempt_cap_pct')
    check('先制总上限在 0～100', isinstance(cap, (int, float)) and 0 < cap <= 100, cap)
    pre = m.get('preempt_pct', [])
    if isinstance(cap, (int, float)) and isinstance(pre, list) and pre:
        check('单件先制不超过总上限', max(pre) <= cap, [max(pre), cap])
    c = table.get('artifact_cap', {})
    for k in GEAR_CAP_KEYS:
        check('神器上限 %s 是正整数' % k, isinstance(c.get(k), int) and c.get(k) > 0, c.get(k))
    band = table.get('drop_reroll', {}).get('level_band')
    check('重抽等级段是正整数', isinstance(band, int) and band > 0, band)
    return bad


def check_gear_table(_args) -> bool:
    path = DATA_DIR / 'gear_table.json'
    if not path.is_file():
        print('跳过：没有 %s' % path.name)
        return True
    bad = gear_rules(json.loads(path.read_text(encoding='utf-8')))
    if bad:
        print('gear_table.json 规则自检 %d 项不过：' % len(bad))
        for b in bad:
            print('  ' + b)
        return False
    print('gear_table.json 规则自检：通过')
    return True


# ---- affix_text.json（词条的玩家文字，和 tests/xiyou_tianqi_affix_text 验同一套） ----

QUALITY_GD = PROJECT / 'modes' / 'xiyou' / 'core' / 'quality.gd'
AFFIX_LINE_MAX_HAN = 16  # 词条行（不算成色、稀有标记）最多几个汉字，不算数字和符号
PLACEHOLDER_RE = re.compile(r'\{[a-z0-9_]*\}')


def _affix_table_module():
    """词条总表的查表算法在 天启篇词条表校验.py（AffixTable），中文文件名用 importlib 载。"""
    import importlib.util
    spec = importlib.util.spec_from_file_location('tianqi_affix_table_check', HERE / '天启篇词条表校验.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class AffixText:
    """和 XTianqiAffixText 同样的填法（改一边要改另一边）。"""

    def __init__(self, text: dict, table):
        self.d = text
        self.t = table  # 天启篇词条表校验.AffixTable
        self.entries = {e['key']: e for e in text.get('affixes', [])}

    def _fills(self, key, tier, grade, extra):
        v = self.t.value(key, tier, grade)
        if v is None or key not in self.entries:
            return None
        a = self.t.affixes[key]
        d = self.d
        names = d.get('tier_names', [])
        f = {'v': num_text(v), 'tier': names[tier - 1] if tier - 1 < len(names) else '',
             'elements': d.get('element_join', '、').join(e['name'] for e in self.t.d.get('elements', []))}
        v2 = self.t.secondary_value(key, tier, grade)
        if v2 is not None:
            f['v2'] = num_text(v2)
        el = {e['key']: e['name'] for e in self.t.d.get('elements', [])}.get(extra.get('element', ''), '')
        f['element'] = el or d.get('element_any', '')
        variants = a.get('variants', [])
        if variants:
            f['variants'] = '、'.join(x['name'] for x in variants)
            f['variant'] = a.get('name', '')
            f['sign'] = d.get('variant_any_sign', '')
            for x in variants:
                if x['key'] == extra.get('variant', ''):
                    f['variant'] = x['name']
                    f['sign'] = d.get('variant_signs', {}).get(x.get('direction', ''), '')
        for k in ('cap_total', 'cap_per_hit_mhp'):
            if k in a:
                f['cap'] = num_text(a[k])
        if 'rate' in a.get('condition', {}):
            f['rate'] = num_text(a['condition']['rate'])
        if 'turns' in a:
            f['turns'] = num_text(a['turns'])
        return f

    @staticmethod
    def _fill(template, f):
        out = template
        for k, v in f.items():
            out = out.replace('{%s}' % k, str(v))
        return out

    def body(self, key, tier, grade, extra=None):
        f = self._fills(key, tier, grade, extra or {})
        if f is None:
            return ''
        prefix = self.d.get('aura_prefix', '') if self.t.affixes[key]['layer'] == 'aura' else ''
        return prefix + self._fill(self.entries[key].get('line', ''), f)

    def marks(self, key, tier, grade):
        f = self._fills(key, tier, grade, {})
        if f is None:
            return []
        a = self.t.affixes[key]
        out = []
        g = self.d.get('grades', {}).get(grade, {})
        if not a.get('fixed') and g.get('mark', ''):
            out.append({'text': self._fill(g['mark'], f), 'color': g.get('color')})
        if a.get('rare'):
            r = self.d.get('rare', {})
            out.append({'text': r.get('mark', ''), 'color': r.get('color')})
        return out

    def line(self, key, tier, grade, extra=None):
        b = self.body(key, tier, grade, extra)
        return ''.join(m['text'] for m in self.marks(key, tier, grade)) + b if b else ''

    def detail(self, key, tier, grade, extra=None):
        f = self._fills(key, tier, grade, extra or {})
        if f is None:
            return ''
        d, a = self.d, self.t.affixes[key]
        hf = dict(f, layer=d.get('layers', {}).get(a['layer'], {}).get('name', ''),
                  grade=d.get('grades', {}).get(grade, {}).get('name', ''))
        head = d.get('detail_header_fixed' if a.get('fixed') else 'detail_header', '')
        lines = [self._fill(head, hf), self._fill(self.entries[key].get('detail', ''), f)]
        if a.get('rare'):
            lines.append(d.get('rare', {}).get('detail', ''))
        st = d.get('stack_text', {}).get(a.get('stack', ''), '')
        if st:
            lines.append(st)
        return '\n'.join(lines)

    def extras(self, key):
        """这条词条要试的变体：不传一种，元素九系、引敌／避敌各一种。"""
        a = self.t.affixes[key]
        out = [{}]
        if a.get('random_element'):
            out += [{'element': e['key']} for e in self.t.d.get('elements', [])]
        out += [{'variant': x['key']} for x in a.get('variants', [])]
        return out


def han_count(s: str) -> int:
    return sum(1 for c in s if '一' <= c <= '鿿')


def ici_color_ids(path: Path = QUALITY_GD) -> set:
    m = re.search(r'const ICI_COLORS := \{(.*?)\}', path.read_text(encoding='utf-8'), re.S)
    return {int(x) for x in re.findall(r'(\d+):', m.group(1))} if m else set()


def affix_text_rules(text: dict, table_data: dict, ici: set) -> list:
    """返回失败说明列表（和 Godot 专项同一套检查）。"""
    bad = []

    def check(name, ok, detail=''):
        if not ok:
            bad.append('%s：%s' % (name, detail))

    mod = _affix_table_module()
    t = mod.AffixTable(table_data)
    x = AffixText(text, t)
    grades = list(mod.GRADES)
    # 1. 表头与键一一对应
    for h in ('version', 'source', 'dev'):
        check('表头 ' + h, str(text.get(h, '')) != '')
    keys = [e.get('key') for e in text.get('affixes', [])]
    want = [a['key'] for a in table_data['affixes']]
    check('文字条数 51', len(keys) == 51, len(keys))
    check('文字键不重复', len(set(keys)) == len(keys), sorted(k for k in set(keys) if keys.count(k) > 1))
    check('文字键和词条总表一一对应', set(keys) == set(want),
          '缺 %s，多 %s' % (sorted(set(want) - set(keys)), sorted(set(keys) - set(want))))
    for e in text.get('affixes', []):
        check('有词条行和说明：' + str(e.get('key')), str(e.get('line', '')) != '' and str(e.get('detail', '')) != '')
    check('四层都有名字和颜色', all(text.get('layers', {}).get(l['key'], {}).get('name') for l in table_data['layers']))
    check('三种成色都有', sorted(text.get('grades', {})) == sorted(grades), list(text.get('grades', {})))
    check('普通不标，上品和极各有标记', text['grades']['normal'].get('mark') == ''
          and text['grades']['fine'].get('mark') and text['grades']['perfect'].get('mark'))
    check('稀有有标记', bool(text.get('rare', {}).get('mark')))
    check('光环前缀含「全队」', '全队' in text.get('aura_prefix', ''), text.get('aura_prefix'))
    colors = [v.get('color') for v in text.get('layers', {}).values()]
    colors += [v.get(k) for v in text.get('grades', {}).values() for k in ('color', 'line_color') if v.get(k) is not None]
    colors.append(text.get('rare', {}).get('color'))
    check('颜色键都是 XQuality.ICI_COLORS 里现成的编号', all(c in ici for c in colors), [c for c in colors if c not in ici])
    for k in ('stack', ):
        miss = sorted({a[k] for a in table_data['affixes']} - set(text.get('stack_text', {})))
        check('每种叠法都有说明', not miss, miss)
    # 2. 全部词条 × 能出的阶 × 三种成色 × 变体：填得上
    bad_fill, too_long, minus = [], [], []
    for a in table_data['affixes']:
        k = a['key']
        for tier in range(1, 5):
            for g in grades:
                if t.value(k, tier, g) is None:
                    continue
                for ex in x.extras(k):
                    ln, dt, bd = x.line(k, tier, g, ex), x.detail(k, tier, g, ex), x.body(k, tier, g, ex)
                    tag = '%s/%d/%s/%s' % (k, tier, g, ex or '-')
                    for s in (ln, dt):
                        if s == '' or '{' in s or '}' in s or 'null' in s.lower() or 'nan' in s.lower() or 'none' in s.lower():
                            bad_fill.append('%s：%s' % (tag, s))
                        if re.search(r'-\d', s):
                            minus.append('%s：%s' % (tag, s))
                    if han_count(bd) > AFFIX_LINE_MAX_HAN:
                        too_long.append('%s（%d 字）：%s' % (tag, han_count(bd), bd))
        for tier in range(1, 5):
            if t.value(k, tier, 'normal') is None:
                check('不能出的阶返回空：%s/%d' % (k, tier), x.line(k, tier, 'normal') == '' and x.detail(k, tier, 'normal') == '')
    check('模板都填得上（不剩花括号、没有 null／nan）', not bad_fill, '；'.join(bad_fill[:5]))
    check('负号用全角「−」', not minus, '；'.join(minus[:5]))
    check('词条行不超过 %d 个汉字' % AFFIX_LINE_MAX_HAN, not too_long, '；'.join(too_long[:5]))
    # 3. 抽查（设计稿 v0.3 与 Kyo 11-11 01:21 整数版）
    spot = [
        ('物攻四阶极', x.line('atk', 4, 'perfect'), '极·物攻 +8%'),
        ('终伤四阶上品', x.line('final_damage', 4, 'fine'), '上品·伤害加成 +12%'),
        ('再动四阶极', x.line('reaction', 4, 'perfect'), '极·〔稀有〕每回合有 20% 概率多行动一次'),
        ('全能光环四阶极', x.line('aura_versatile', 4, 'perfect'), '极·全队·八项属性 +6%'),
        ('连击', x.line('combo', 4, 'perfect'), '〔稀有〕攻击次数 +1'),
        ('暴怒四阶普通', x.line('aura_fury', 4, 'normal'), '全队·暴击率 +3%，爆伤 +6%'),
        ('火焰增伤四阶极', x.line('element_damage', 4, 'perfect', {'element': 'fire'}), '极·火焰伤害 +22%'),
        ('避敌四阶普通', x.line('target_rate', 4, 'normal', {'variant': 'avoid'}), '避敌：被选为目标的概率 −10%'),
        ('物攻一阶普通', x.line('atk', 1, 'normal'), '物攻 +1%'),
    ]
    for name, got, exp in spot:
        check('抽查 ' + name, got == exp, '%s ≠ %s' % (got, exp))
    check('技能消耗写出 −50% 上限', '−50%' in x.detail('skill_cost', 4, 'perfect'), x.detail('skill_cost', 4, 'perfect'))
    check('吸血写出单次不超过最大生命 10%', '不超过自己最大生命的 10%' in x.detail('lifesteal', 4, 'perfect'))
    check('破绽写出持续 2 回合、同一目标只有一层', '持续 2 回合' in x.detail('expose', 4, 'normal') and '只有一层' in x.detail('expose', 4, 'normal'))
    check('光环说明写出同名全队只生效最高', '同名光环全队只生效数值最高的一条' in x.detail('aura_guard', 2, 'normal'))
    check('元素说明写全九系', all(e['name'] in x.detail('element_resist', 3, 'fine') for e in table_data['elements']))
    check('连击说明不写阶和成色', (x.detail('combo', 4, 'perfect').splitlines() or [''])[0] == '传说词条', x.detail('combo', 4, 'perfect'))
    return bad


def check_affix_text(text_path=None) -> bool:
    path = Path(text_path) if text_path else DATA_DIR / 'affix_text.json'
    table_path = DATA_DIR / 'affix_table.json'
    if not path.is_file() or not table_path.is_file():
        print('跳过：没有 %s 或 %s' % (path.name, table_path.name))
        return True
    try:
        bad = affix_text_rules(json.loads(path.read_text(encoding='utf-8')),
                               json.loads(table_path.read_text(encoding='utf-8')), ici_color_ids())
    except Exception as e:  # 缺键、格式坏也算失败
        bad = ['能读表并跑完全部检查：%s: %s' % (type(e).__name__, e)]
    if bad:
        print('affix_text.json 检查 %d 项不过：' % len(bad))
        for b in bad:
            print('  ' + b)
        return False
    print('affix_text.json 检查：通过')
    return True


# ---- rewards.json（天启篇奖励：净印、遗物、终焉词条；测试参数，draft）----

REWARD_LINES = ('death', 'war', 'famine', 'plague')


def rewards_rules(table: dict) -> list:
    """奖励表规则自检（与 tests/xiyou_tianqi_rewards 的 _data 同一套），返回失败说明列表。"""
    bad = []

    def check(name, ok, detail=''):
        if not ok:
            bad.append('%s：%s' % (name, detail))

    for h in ('version', 'source'):
        check('表头 ' + h, str(table.get(h, '')) != '')
    check('标 draft', table.get('draft') is True, table.get('draft'))
    seal = table.get('seal', {})
    check('净印是项链（类型 9）', seal.get('etype') == 9, seal.get('etype'))
    check('净印档名三个', len(seal.get('tier_names', [])) == 3, seal.get('tier_names'))
    check('净印来源档在 1～3', all(isinstance(v, int) and 1 <= v <= 3 for v in seal.get('sources', {}).values()), seal.get('sources'))
    relic = table.get('relic', {})
    check('遗物放神器栏（类型 17）', relic.get('etype') == 17, relic.get('etype'))
    fin = table.get('finale', {})
    keys = []
    for line in REWARD_LINES:
        v = seal.get('lines', {}).get(line, {}).get('values', [])
        check('净印三档 ' + line, isinstance(v, list) and len(v) == 3, v)
        r = relic.get('lines', {}).get(line, {})
        check('遗物完整版和半强度 ' + line, isinstance(r.get('full'), dict) and isinstance(r.get('half'), dict)
              and set(r.get('full', {})) == set(r.get('half', {})), r)
        f = fin.get('lines', {}).get(line, [])
        check('终焉词条每线 4 条 ' + line, isinstance(f, list) and len(f) == 4, f)
        keys.extend(f)
    check('终焉词条不重复', len(keys) == len(set(keys)), keys)
    check('终焉词条都有名字', all(k in fin.get('names', {}) for k in keys), [k for k in keys if k not in fin.get('names', {})])
    return bad


def check_rewards(_args) -> bool:
    path = DATA_DIR / 'rewards.json'
    if not path.is_file():
        print('跳过：没有 %s' % path.name)
        return True
    bad = rewards_rules(json.loads(path.read_text(encoding='utf-8')))
    if bad:
        print('rewards.json 规则自检 %d 项不过：' % len(bad))
        for b in bad:
            print('  ' + b)
        return False
    print('rewards.json 规则自检：通过')
    return True


# ---- 七印祭坛四张表：qiyin_gear／qiyin_drop／qiyin_dragon／qiyin_altar（只读草稿，另两条车道还在加字段）----
# 只查表里现有的字段：缺了就不查，不认识的键不报错。

TIANQI_GEAR_GD = PROJECT / 'modes' / 'xiyou' / 'core' / 'tianqi_gear.gd'
QIYIN_SEALS = ('bai', 'hong', 'hei', 'hui', 'xun', 'zhen', 'mo')
QIYIN_PARTS = ('head', 'body', 'hands', 'waist', 'legs', 'feet')
QIYIN_SET_PIECES = 6
QIYIN_WEAPONS = 13
QIYIN_ARTIFACTS = 5


def tianqi_gear_order(path: Path = None) -> list:
    """从 core/tianqi_gear.gd 的 ORDER 取天启篇装备栏的类型号（只读）。"""
    text = Path(path or TIANQI_GEAR_GD).read_text(encoding='utf-8')
    m = re.search(r'const ORDER\s*:?=\s*\[([^\]]*)\]', text)
    if not m:
        raise ValueError('tianqi_gear.gd 里找不到 ORDER')
    return [int(x) for x in re.findall(r'-?\d+', m.group(1))]


def _is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _walk(v, path=''):
    """逐个给出 (路径, 键, 值)，跳过 _note。"""
    if isinstance(v, dict):
        for k, x in v.items():
            if k == '_note':
                continue
            p = path + '/' + str(k)
            yield p, k, x
            yield from _walk(x, p)
    elif isinstance(v, list):
        for i, x in enumerate(v):
            p = '%s/%d' % (path, i)
            yield p, None, x
            yield from _walk(x, p)


def _is_chance_key(k) -> bool:
    return isinstance(k, str) and (k == 'chance' or k.endswith('_chance'))


def qiyin_common_rules(table: dict) -> list:
    """四张表共用：几率在 0～1、权重非负且不全为 0（D205 起不再查数字避开 4）。"""
    bad = []
    for p, k, v in _walk(table):
        if _is_chance_key(k):
            vals = list(v.values()) if isinstance(v, dict) else [v]
            for x in vals:
                if not (_is_num(x) and 0 <= x <= 1):
                    bad.append('几率在 0～1：%s=%s' % (p, v))
                    break
        if isinstance(k, str) and (k == 'weights' or k.endswith('_weights')) and isinstance(v, dict):
            nums = [x for x in v.values() if _is_num(x)]
            if any(x < 0 for x in nums) or len(nums) != len(v):
                bad.append('权重非负：%s=%s' % (p, v))
            elif not any(x > 0 for x in nums):
                bad.append('权重不全为 0：%s=%s' % (p, v))
        if isinstance(k, str) and k.endswith('_weight') and _is_num(v) and v < 0:
            bad.append('权重非负：%s=%s' % (p, v))
    return bad


def _seal_refs(table: dict, name: str) -> list:
    """表里引用印键的地方：[(说明, 键)]。只看已知字段。"""
    out = []

    def add(where, keys):
        if isinstance(keys, (list, tuple)):
            out.extend((where, k) for k in keys)
        elif isinstance(keys, dict):
            out.extend((where, k) for k in keys if k != '_note')
        elif keys is not None:
            out.append((where, keys))

    if name == 'gear':
        add('seals', [s.get('key') for s in table.get('seals', []) if isinstance(s, dict)])
        add('sets', table.get('sets'))
        add('schools', table.get('schools'))
        add('weapons.seal', [w.get('seal') for w in table.get('weapons', []) if isinstance(w, dict) and 'seal' in w])
    elif name == 'drop':
        add('seals', table.get('seals'))
        add('weapon_classes', table.get('weapon_classes'))
        for fl, ks in table.get('floor_first_kill', {}).items():
            if fl != '_note':
                add('floor_first_kill.' + fl, ks)
    elif name == 'dragon':
        add('seals', table.get('seals'))
        fight = table.get('fight', {})
        add('fight.reveal_order', fight.get('reveal_order'))
        add('fight.grey_reprieve.seal', fight.get('grey_reprieve', {}).get('seal'))
    elif name == 'altar':
        add('seals', table.get('seals'))
        unlock = table.get('unlock', {})
        add('unlock', unlock)
        for k, u in unlock.items():
            if isinstance(u, dict):
                add('unlock.%s.after_seals' % k, u.get('after_seals'))
    return out


def _part_refs(table: dict, name: str) -> list:
    out = []
    if name == 'gear':
        out += [('parts', p.get('key')) for p in table.get('parts', []) if isinstance(p, dict)]
        for sk, s in table.get('sets', {}).items():
            if isinstance(s, dict):
                out += [('sets.%s.pieces' % sk, p.get('part')) for p in s.get('pieces', []) if isinstance(p, dict) and 'part' in p]
    elif name == 'drop':
        out += [('parts', k) for k in table.get('parts', [])]
    elif name == 'dragon':
        out += [('reward.set_parts', k) for k in table.get('reward', {}).get('set_parts', [])]
    elif name == 'altar':
        out += [('names.parts', k) for k in table.get('names', {}).get('parts', {})]
    return out


def qiyin_key_rules(table: dict, name: str) -> list:
    """印键只有七个、部位键只有六个。"""
    bad = []
    for where, k in _seal_refs(table, name):
        if k not in QIYIN_SEALS:
            bad.append('印键只有 %s：%s 里有 %s' % ('、'.join(QIYIN_SEALS), where, k))
    for where, k in _part_refs(table, name):
        if k not in QIYIN_PARTS:
            bad.append('部位键只有 %s：%s 里有 %s' % ('、'.join(QIYIN_PARTS), where, k))
    return bad


def qiyin_gear_rules(table: dict, order: list) -> list:
    """qiyin_gear.json：共用规则＋键＋类型号对 ORDER＋七套各 6 件、毕业武器 13 把、神器 5 件。"""
    bad = qiyin_common_rules(table) + qiyin_key_rules(table, 'gear')

    def check(n, ok, detail=''):
        if not ok:
            bad.append('%s：%s' % (n, detail))

    part_etype = {p.get('key'): p.get('etype') for p in table.get('parts', []) if isinstance(p, dict)}
    for k, e in part_etype.items():
        if e is not None:
            check('部位类型号在 tianqi_gear.gd 的 ORDER 里：' + str(k), e in order, '%s 不在 %s' % (e, order))
    if 'sets' in table:
        sets = table['sets']
        check('套装七套', sorted(sets) == sorted(QIYIN_SEALS), sorted(sets))
        for sk, s in sets.items():
            pieces = s.get('pieces', []) if isinstance(s, dict) else []
            check('套装 %s 有 %d 件' % (sk, QIYIN_SET_PIECES), len(pieces) == QIYIN_SET_PIECES, len(pieces))
            parts = [p.get('part') for p in pieces if isinstance(p, dict)]
            check('套装 %s 部位不重复' % sk, len(parts) == len(set(parts)), parts)
            for p in pieces:
                if not isinstance(p, dict) or 'etype' not in p:
                    continue
                check('套装件类型号在 ORDER 里：%s %s' % (sk, p.get('part')), p['etype'] in order, '%s 不在 %s' % (p['etype'], order))
                want = part_etype.get(p.get('part'))
                if want is not None:
                    check('套装件类型号同部位：%s %s' % (sk, p.get('part')), p['etype'] == want, '%s / 部位 %s' % (p['etype'], want))
    art_etype = table.get('artifact_rule', {}).get('etype')
    if art_etype is not None:
        check('神器类型号在 ORDER 里', art_etype in order, '%s 不在 %s' % (art_etype, order))
    if 'weapons' in table:
        ws = table['weapons']
        check('毕业武器 %d 把' % QIYIN_WEAPONS, len(ws) == QIYIN_WEAPONS, len(ws))
        keys = [w.get('key') for w in ws if isinstance(w, dict)]
        check('毕业武器键不重复', len(keys) == len(set(keys)), keys)
        types = {t.get('key') for t in table.get('weapon_types', []) if isinstance(t, dict)}
        if types:
            for w in ws:
                if isinstance(w, dict) and w.get('type') is not None:
                    check('毕业武器类型在 weapon_types 里：%s' % w.get('key'), w['type'] in types, w['type'])
            for sk, sc in table.get('schools', {}).items():
                if isinstance(sc, dict) and isinstance(sc.get('types'), list):
                    miss = [t for t in sc['types'] if t not in types]
                    check('流派武器类型在 weapon_types 里：' + sk, not miss, miss)
    if 'artifacts' in table:
        arts = table['artifacts']
        check('神器 %d 件' % QIYIN_ARTIFACTS, len(arts) == QIYIN_ARTIFACTS, len(arts))
        keys = [a.get('key') for a in arts if isinstance(a, dict)]
        check('神器键不重复', len(keys) == len(set(keys)), keys)
    return bad


def qiyin_refs(gear: dict, others: dict) -> list:
    """跨表：qiyin_drop／qiyin_dragon／qiyin_altar 引用的套装、武器、神器、印、部位都要在 qiyin_gear 里有。"""
    bad = []
    seals = {s.get('key') for s in gear.get('seals', []) if isinstance(s, dict)}
    sets = set(gear.get('sets', {}))
    parts = {p.get('key') for p in gear.get('parts', []) if isinstance(p, dict)}
    arts = {a.get('key') for a in gear.get('artifacts', []) if isinstance(a, dict)}
    wtypes = {t.get('name'): t.get('key') for t in gear.get('weapon_types', []) if isinstance(t, dict)}
    schools = gear.get('schools', {})
    for name, t in others.items():
        fname = 'qiyin_%s.json' % name
        for where, k in _seal_refs(t, name):
            if 'seals' in gear and k not in seals:
                bad.append('%s 的印在 qiyin_gear 的 seals 里：%s 里有 %s' % (fname, where, k))
            if 'sets' in gear and k not in sets:
                bad.append('%s 的套装在 qiyin_gear 的 sets 里：%s 里有 %s' % (fname, where, k))
        if 'parts' in gear:
            for where, k in _part_refs(t, name):
                if k not in parts:
                    bad.append('%s 的部位在 qiyin_gear 的 parts 里：%s 里有 %s' % (fname, where, k))
        art_refs = []
        if name == 'drop':
            art_refs = [('artifact.keys', k) for k in t.get('artifact', {}).get('keys', [])]
        elif name == 'dragon':
            art_refs = [('reward.artifacts', k) for k in t.get('reward', {}).get('artifacts', [])]
        if 'artifacts' in gear:
            for where, k in art_refs:
                if k not in arts:
                    bad.append('%s 的神器在 qiyin_gear 的 artifacts 里：%s 里有 %s' % (fname, where, k))
        if name == 'drop' and wtypes:
            for sk, cls in t.get('weapon_classes', {}).items():
                if sk == '_note' or not isinstance(cls, list):
                    continue
                miss = [c for c in cls if c not in wtypes]
                if miss:
                    bad.append('%s 的武器类型在 qiyin_gear 的 weapon_types 里：weapon_classes.%s 里有 %s' % (fname, sk, miss))
                want = schools.get(sk, {}).get('types') if isinstance(schools.get(sk), dict) else None
                if isinstance(want, list) and not miss and sorted(wtypes[c] for c in cls) != sorted(want):
                    bad.append('%s 的武器类型同 qiyin_gear 的流派：weapon_classes.%s=%s，schools.%s.types=%s' % (fname, sk, cls, sk, want))
    return bad


def _qiyin_load(name: str):
    path = DATA_DIR / ('qiyin_%s.json' % name)
    return json.loads(path.read_text(encoding='utf-8')) if path.is_file() else None


def _report(fname: str, what: str, bad: list) -> bool:
    if bad:
        print('%s %s %d 项不过：' % (fname, what, len(bad)))
        for b in bad:
            print('  ' + b)
        return False
    print('%s %s：通过' % (fname, what))
    return True


def check_qiyin(name: str) -> bool:
    fname = 'qiyin_%s.json' % name
    if not (DATA_DIR / fname).is_file():
        print('跳过：没有 %s' % fname)
        return True
    try:
        t = _qiyin_load(name)
        if name == 'gear':
            bad = qiyin_gear_rules(t, tianqi_gear_order())
        else:
            bad = qiyin_common_rules(t) + qiyin_key_rules(t, name)
    except Exception as e:  # 缺键、格式坏也算失败
        bad = ['能读表并跑完全部检查：%s: %s' % (type(e).__name__, e)]
    return _report(fname, '规则自检', bad)


def check_qiyin_refs(_args) -> bool:
    if not (DATA_DIR / 'qiyin_gear.json').is_file():
        print('跳过：没有 qiyin_gear.json（七印跨表引用）')
        return True
    try:
        gear = _qiyin_load('gear')
        others = {n: t for n in ('drop', 'dragon', 'altar') for t in [_qiyin_load(n)] if t is not None}
        bad = qiyin_refs(gear, others)
    except Exception as e:
        bad = ['能读表并跑完全部检查：%s: %s' % (type(e).__name__, e)]
    return _report('七印四张表', '跨表引用', bad)


# ---- skill_rework.json（全角色技能重构，XTianqiSkills） ----

def skill_rework_rules(table: dict) -> list:
    """档位名单人数和不重叠、技能行的系数／比例／几率范围（D205 起不再查数字避开 4）。"""
    bad = []
    tiers = table.get('tiers', {})
    sup, strong, hidden = (set(tiers.get(k, [])) for k in (SUPER, STRONG, '不开放'))
    if len(sup) != 17:
        bad.append('超强者名单 %d 人（应 17：18 人里轮回者·里德另做；五条悟 180 在名单里，没解锁最强之名时游戏里当他不开放）' % len(sup))
    if len(strong) != 52:
        bad.append('强者名单 %d 人（应 52）' % len(strong))
    growth = tiers.get('growth')
    if not isinstance(growth, dict) or not any(str(k).isdigit() for k in growth):
        bad.append('tiers.growth 成长型角色名单要非空（全弱者通关资格靠它排除三笠、饿狼，空了 XTianqiWeakClear 一律不授予）')
    for a, b, name in ((sup, strong, '超强者∩强者'), (sup, hidden, '超强者∩不开放'), (strong, hidden, '强者∩不开放')):
        if a & b:
            bad.append('%s 重叠：%s' % (name, sorted(a & b)))
    for sid, row in table.get('skills', {}).items():
        if not str(sid).isdigit():
            continue
        d = row.get('damage')
        if d is not None and not float(d.get('coef', 0)) > 0:
            bad.append('skills/%s 伤害系数要大于 0' % sid)
        h = row.get('heal')
        if h is not None and not all(0 <= float(v) <= 1 for v in h.values()):
            bad.append('skills/%s 治疗比例要在 0～1' % sid)
        if 'mp_pct' in row and not 0 < float(row['mp_pct']) <= 100:
            bad.append('skills/%s 魔法比例要在 0～100' % sid)
        for f in row.get('follow', []):
            rates = [f.get('rate', 0)] + list(f.get('rate_with', {}).values())
            if not all(0 <= float(r) <= 1 for r in rates):
                bad.append('skills/%s 追加几率要在 0～1' % sid)
        if 'desc' in row and not isinstance(row['desc'], list):
            bad.append('skills/%s desc 要是列表' % sid)
        if row.get('self_states_on_hit') is not None and (row['self_states_on_hit'] is not True or not row.get('self_states')):
            bad.append('skills/%s self_states_on_hit（强制放的技能命中时自挂状态，T264）要是 true 且带 self_states' % sid)
        cp = row.get('cast_pick')
        if cp is not None:
            pk = cp.get('pick') if isinstance(cp, dict) else None
            if not (isinstance(cp, dict) and isinstance(cp.get('rate', 100), int) and 0 < cp.get('rate', 100) <= 100
                    and isinstance(pk, list) and pk
                    and all(isinstance(x, dict) and len(x) == 1 and next(iter(x)) in ('foe', 'self') and isinstance(next(iter(x.values())), int) for x in pk)):
                bad.append('skills/%s cast_pick（每次施放掷一次、挑一项挂，T268）要 {rate 1～100 整数, pick [{foe|self: 状态号}…] 非空}' % sid)
        se = row.get('seg_elements_of')
        if se is not None and not (isinstance(se, list) and se and all(isinstance(x, int) and x > 0 for x in se)):
            bad.append('skills/%s seg_elements_of（逐段借技能属性，T268）要是非空的技能号列表' % sid)
        for c in (d or {}).get('conds', []):
            if c.get('if') == 'stat_floor':
                ints = [c.get(k) for k in ('from', 'full', 'to', 'hits')]
                if not (c.get('stat') in ('mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk') and all(isinstance(v, int) for v in ints)
                        and c['full'] > c['from'] >= 0 and c['to'] > 0 and c['hits'] >= 1):
                    bad.append('skills/%s stat_floor（副属性抬下限，T268）要 stat 是八项之一、from／full／to／hits 整数且 full>from、to>0、hits≥1' % sid)
    for sid, row in table.get('states', {}).items():
        if isinstance(row, dict) and 'battle_end' in row and not isinstance(row['battle_end'], bool):
            bad.append('states/%s battle_end（战斗结束移除，T263）要是 true／false' % sid)
    return bad


TUNE_KEYS = ('D189', 'D200', 'D198', 'D208', 'D209')  # 同 XTianqiSkills.data()：按这个顺序叠（T192 加 D198；T204 加 D208、D209）


def tune_merge(base: dict, patch: dict) -> dict:
    """同 XTianqiSkills.tune_merge：字典逐层合并，其余整段换；_ 开头的说明键不进。"""
    import copy
    out = copy.deepcopy(base)
    for k, v in patch.items():
        if str(k).startswith('_'):
            continue
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = tune_merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def apply_skill_tune(table: dict) -> dict:
    """游戏里开着 XTianqiBase.TUNE_D189 时读到的表：tune.<键>.skills／actors 覆盖到原卡上（T163）。"""
    import copy
    out = copy.deepcopy(table)
    for key in TUNE_KEYS:
        tune = table.get('tune', {}).get(key, {})
        for sec in ('skills', 'actors', 'gear'):  # gear：T209＋D213 改百谷生卡面
            for k, v in tune.get(sec, {}).items():
                if str(k).startswith('_'):
                    continue
                cur = out.setdefault(sec, {}).get(k)
                out[sec][k] = tune_merge(cur if isinstance(cur, dict) else {}, v)
    return out


def _int_like(v, scale=1) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool) and abs(v * scale - round(v * scale)) < 1e-9


def _int_or_pct(v) -> bool:
    """整数，或小于 1 的整数百分比（0.45＝45%）。"""
    return _int_like(v) or (0 < v < 1 and _int_like(v, 100))


def _plain_always(c: dict) -> bool:
    return c.get('if') == 'always' and not any(k not in ('if', 'mult', '_fix', '_note') for k in c)


# 卡面伤害行允许留小数的技能：数不是我们定的系数（剑心多一段 +0.5 是 cat.gd 里的代码常数；棱光星影加段 +1.2 是 xuan_battle.gd 的「每个星影 20%×系数」，T175 已列）
DESC_DECIMAL_EXEMPT = {'10437', '10438', '10439', '10337'}


def coef_integer_rules(table: dict) -> list:
    """T175／T191（附则 E，Kyo D137②、11-18「系数不要小数」，D200 A 全表取整）：覆盖层全开（D189＋D200）后游戏读到的每一行伤害——
    系数写整数或小于 1 的整数百分比；属性权重写整数或整数百分比（生命上限×1% 写 0.01）；每项有效系数 coef×权重 也只能是整数或 1%～99% 的整数百分比；
    无条件的 always 倍率要并进系数；五条悟茈的 gojo_pairs 也要整数；卡面伤害行不带小数（代码常数的几招豁免）。"""
    bad = []
    merged = apply_skill_tune(table)
    for sid, row in merged.get('skills', {}).items():
        if not str(sid).isdigit() or not isinstance(row, dict):
            continue
        d = row.get('damage')
        if isinstance(d, dict):
            coef = float(d.get('coef', 0))
            if 'coef' in d and not _int_or_pct(coef):
                bad.append('系数不得有小数：skills/%s/damage/coef=%s' % (sid, num_text(d['coef'])))
            for st, w in d.get('stats', {}).items():
                if not _int_or_pct(float(w)):
                    bad.append('属性权重要整数或整数百分比：skills/%s/damage/stats/%s=%s' % (sid, st, num_text(w)))
                    continue
                e = coef * float(w)
                if _int_or_pct(coef) and e and not (_int_like(e) or (0.01 - 1e-9 <= e < 1 and _int_like(e, 100))):
                    bad.append('有效系数（系数×权重）要整数或不低于 1%% 的整数百分比：skills/%s/damage %s=%s' % (sid, st, num_text(round(e, 6))))
            for c in d.get('conds', []):
                if _plain_always(c):
                    bad.append('无条件倍率要并进系数：skills/%s/damage/conds always×%s' % (sid, num_text(c.get('mult', 1))))
        pairs = row.get('gojo_pairs')
        if isinstance(pairs, list):
            for i, x in enumerate(pairs):
                if not _int_like(float(x)):
                    bad.append('系数不得有小数：skills/%s/gojo_pairs/%d=%s' % (sid, i, num_text(x)))
        if sid not in DESC_DECIMAL_EXEMPT:
            for line in row.get('desc', []):
                if str(line).startswith('伤害') and re.search(r'\d\.\d', str(line)):
                    bad.append('卡面伤害行带小数：skills/%s「%s」' % (sid, line))
    return bad


def _with_tune(rules):
    """原卡、覆盖后各查一遍（开关两边都是游戏会读到的表），覆盖后的失败前面标「tune 覆盖后」。"""
    def run(table):
        bad = list(rules(table))
        if table.get('tune'):
            bad += ['tune 覆盖后：' + b for b in rules(apply_skill_tune(table)) if b not in bad]
        return bad
    return run


DB_DIR = PROJECT / 'modes' / 'xiyou' / 'generated' / 'db'


def _forced_targets(ce: dict, cid: int, seen=None) -> set:
    """公共事件 cid（含嵌套 117 调用）里强制行动（339）放的技能号。"""
    seen = seen if seen is not None else set()
    if cid in seen or cid not in ce:
        return set()
    seen.add(cid)
    out = set()
    for c in ce[cid]['list']:
        if c['code'] == 339:
            out.add(int(c['parameters'][2]))
        elif c['code'] == 117:
            out |= _forced_targets(ce, int(c['parameters'][0]), seen)
    return out


def forced_copy_gaps(table: dict, skills: dict, ce: dict) -> dict:
    """T255：卡里技能有效果 44→公共事件→强制放副本技能，副本不在卡里、又没 effects_remove 去掉 → {技能号: [(公共事件, 副本)]}。"""
    cards = {**table.get('skills', {}), **table.get('new_skills', {})}
    gaps = {}
    for sid, row in cards.items():
        if not str(sid).isdigit() or int(sid) not in skills:
            continue
        removed = {(int(e[0]), int(e[1])) for e in row.get('effects_remove', [])}
        for e in skills[int(sid)].get('effects', []):
            if e['code'] != 44 or (44, e['dataId']) in removed:
                continue
            for t in sorted(_forced_targets(ce, e['dataId'])):
                if str(t) not in cards:
                    gaps.setdefault(str(sid), []).append((e['dataId'], t))
    return gaps


def forced_copy_rules(table: dict, db_dir: Path = None) -> list:
    """T255：副本技能没进卡的强制追击要么 effects_remove 去掉、要么副本进卡；还没定的登记在 forced_copy_pending（技能号→原因），登记了却已不是缺口的要删。"""
    db_dir = db_dir or DB_DIR
    if not (db_dir / 'Skills.json').is_file() or not (db_dir / 'CommonEvents.json').is_file():
        return []
    skills = {x['id']: x for x in json.loads((db_dir / 'Skills.json').read_text(encoding='utf-8')) if x}
    ce = {x['id']: x for x in json.loads((db_dir / 'CommonEvents.json').read_text(encoding='utf-8')) if x}
    pending = table.get('forced_copy_pending', {})
    dead = table.get('forced_copy_unreachable', {})
    bad = []
    if not isinstance(pending, dict) or not isinstance(dead, dict):
        return ['forced_copy_pending／forced_copy_unreachable 要是 {技能号: 原因}']
    gaps = forced_copy_gaps(table, skills, ce)
    for sid, why in dead.items():  # T261：副本分支在天启篇走不到（缺的前置拿不到），写明原因就放行；变成走得到、或已不是缺口要删
        if sid not in gaps:
            bad.append('forced_copy_unreachable.%s 已经不是缺口，删掉登记' % sid)
        elif not isinstance(why, str) or not why.strip():
            bad.append('forced_copy_unreachable.%s 要写原因（为什么天启篇走不到）' % sid)
    for sid, rows in gaps.items():
        if sid in dead:
            continue
        if sid not in pending:
            bad.append('技能 %s 的效果 44 调公共事件强制放副本 %s，副本没进卡：在卡上加 effects_remove [44, 公共事件号]，或让副本进卡，或先登记 forced_copy_pending' % (sid, sorted({r[1] for r in rows})))
    for sid, why in pending.items():
        if sid not in gaps or sid in dead:
            bad.append('forced_copy_pending.%s 已经不是缺口，删掉登记' % sid)
        elif not isinstance(why, str) or not why.strip():
            bad.append('forced_copy_pending.%s 要写原因' % sid)
    return bad


def check_skill_rework(_args) -> bool:
    path = DATA_DIR / 'skill_rework.json'
    if not path.is_file():
        print('跳过：没有 skill_rework.json')
        return True
    try:
        table = json.loads(path.read_text(encoding='utf-8'))
        bad = _with_tune(skill_rework_rules)(table) + coef_integer_rules(table) + forced_copy_rules(table)
    except Exception as e:
        bad = ['能读表并跑完全部检查：%s: %s' % (type(e).__name__, e)]
    return _report('skill_rework.json', '规则自检', bad)


def elements_table_rules(table: dict) -> list:
    bad = []
    base = table.get('base_elements', [])
    higher = table.get('higher_elements', [])
    if sorted(base) != [2, 3, 4, 5, 6, 7, 8, 9, 14, 15]:
        bad.append('base_elements 应为 10 个基础属性 [2..9, 14, 15]：%s' % (base,))
    if sorted(higher) != [11, 12, 13]:
        bad.append('higher_elements 应为 [11, 12, 13]：%s' % (higher,))
    rules = table.get('deck_rules', {})
    n_base = len(base)
    if int(rules.get('total_floors', 0)) != 33:
        bad.append('total_floors 应为 33')
    if int(rules.get('per_element_weak', 0)) * n_base != int(rules.get('double_floors', 0)) * 2 + int(rules.get('single_floors', 0)):
        bad.append('弱点总量与双单层分布不匹配')
    if int(rules.get('per_element_resist', 0)) * n_base != int(rules.get('double_floors', 0)) * 2 + int(rules.get('single_floors', 0)):
        bad.append('抗性总量与双单层分布不匹配')
    if int(rules.get('immune_min_floor', 0)) != 6:
        bad.append('immune_min_floor 应为 6（1~5 层无免疫）')
    return bad


def check_elements_table(_args) -> bool:
    path = DATA_DIR / 'elements_table.json'
    if not path.is_file():
        print('跳过：没有 elements_table.json')
        return True
    try:
        bad = elements_table_rules(json.loads(path.read_text(encoding='utf-8')))
    except Exception as e:
        bad = ['能读表并跑完全部检查：%s: %s' % (type(e).__name__, e)]
    return _report('elements_table.json', '规则自检', bad)


# ---- 第三批：reforge／alien_gear／abyss_shelves／qiyin_equip／qiyin_show／qiyin_dragon_run（cc/pro-tianqi-datacheck3）----
# 只查代码真读的字段（读表的模块写在各函数说明里）；字段缺了不查，不认识的键不报错。
# 跨表引用的那张表不在就跳过那一项（例如没有 qiyin_gear.json 就不查部位、武器类型对不对得上）。

TIANQI_AFFIX_ROLL_GD = PROJECT / 'modes' / 'xiyou' / 'core' / 'tianqi_affix_roll.gd'
HEX_COLOR_RE = re.compile(r'^#[0-9A-Fa-f]{6}$')
RM_PARAMS = 8  # RPG Maker 八项能力值


def quality_keys(path: Path = None) -> list:
    """从 core/tianqi_affix_roll.gd 的 QUALITY_KEYS 取七档品质键（只读）。"""
    text = Path(path or TIANQI_AFFIX_ROLL_GD).read_text(encoding='utf-8')
    m = re.search(r'const QUALITY_KEYS\s*:?=\s*\[([^\]]*)\]', text)
    if not m:
        raise ValueError('tianqi_affix_roll.gd 里找不到 QUALITY_KEYS')
    return re.findall(r'"([^"]*)"', m.group(1))


def _load_opt(fname: str):
    path = DATA_DIR / fname
    return json.loads(path.read_text(encoding='utf-8')) if path.is_file() else None


def _is_int(v) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def _checker():
    bad = []

    def check(name, ok, detail=''):
        if not ok:
            bad.append('%s：%s' % (name, detail))
    return bad, check


def _run_table(fname: str, rules) -> bool:
    """表不在就跳过；读坏、缺键也算失败。rules(table) 返回失败说明列表。"""
    if not (DATA_DIR / fname).is_file():
        print('跳过：没有 %s' % fname)
        return True
    try:
        bad = rules(json.loads((DATA_DIR / fname).read_text(encoding='utf-8')))
    except Exception as e:
        bad = ['能读表并跑完全部检查：%s: %s' % (type(e).__name__, e)]
    return _report(fname, '规则自检', bad)


def affix_tier_ids(affix: dict) -> list:
    return [t.get('tier') for t in affix.get('tiers', []) if isinstance(t, dict)]


def affix_layer_keys(affix: dict) -> list:
    return [l.get('key') for l in affix.get('layers', []) if isinstance(l, dict)]


# reforge.json：XTianqiReforge（costs 按词条的阶取、超出取最后一档；allow_perfect、allow_rare 开关）

def reforge_rules(table: dict, affix: dict = None) -> list:
    bad, check = _checker()
    if 'costs' in table:
        c = table['costs']
        check('costs 是非空列表', isinstance(c, list) and c, c)
        if isinstance(c, list) and c:
            check('costs 都是非负整数', all(_is_int(x) and x >= 0 for x in c), c)
            if all(_is_int(x) for x in c):
                check('costs 随阶不降', all(c[i] <= c[i + 1] for i in range(len(c) - 1)), c)
            if affix is not None and affix_tier_ids(affix):
                n = len(affix_tier_ids(affix))
                check('costs 档数不超过 affix_table 的阶数 %d' % n, len(c) <= n, len(c))
    for k in ('allow_perfect', 'allow_rare'):
        if k in table:
            check('%s 是布尔' % k, isinstance(table[k], bool), table[k])
    return bad


def check_reforge(_args) -> bool:
    return _run_table('reforge.json', lambda t: reforge_rules(t, _load_opt('affix_table.json')))


# alien_gear.json：XTianqiAlienGear（levels、level_order、late_only、costs、new_affixes）、XTianqiAlienAffix（effects）

ALIEN_PCT_FIELDS = {('thrift', 'cost'), ('thrift', 'heal'), ('venom', 'chance'), ('again', 'taken')}


def alien_gear_rules(table: dict, rewards: dict = None) -> list:
    bad, check = _checker()
    levels = {k: v for k, v in table.get('levels', {}).items() if k != '_note'}
    for k, lv in levels.items():
        if not isinstance(lv, dict):
            check('异化级是字典：' + k, False, lv)
            continue
        if 'rate' in lv:
            check('异化几率在 0～1：' + k, _is_num(lv['rate']) and 0 <= lv['rate'] <= 1, lv['rate'])
        if 'energy' in lv:
            check('分解能量是正整数：' + k, _is_int(lv['energy']) and lv['energy'] > 0, lv['energy'])
        if 'refund' in lv:
            check('净化退还是非负整数：' + k, _is_int(lv['refund']) and lv['refund'] >= 0, lv['refund'])
            if _is_int(lv.get('energy')) and _is_int(lv['refund']):
                check('净化退还不超过分解能量：' + k, lv['refund'] <= lv['energy'], [lv['refund'], lv['energy']])
        if 'name' in lv:
            check('级名非空：' + k, isinstance(lv['name'], str) and lv['name'] != '', lv['name'])
    order = table.get('level_order')
    if order is not None and levels:
        check('level_order 不重复', len(order) == len(set(order)), order)
        check('level_order 都在 levels 里', all(k in levels for k in order), [k for k in order if k not in levels])
        check('levels 都排进 level_order', all(k in order for k in levels), [k for k in levels if k not in order])
        rates = [levels[k].get('rate') for k in order if k in levels and isinstance(levels[k], dict)]
        if all(_is_num(r) for r in rates):
            check('异化几率随级不降', all(rates[i] <= rates[i + 1] for i in range(len(rates) - 1)), rates)
        en = [levels[k].get('energy') for k in order if k in levels and isinstance(levels[k], dict)]
        if all(_is_int(e) for e in en):
            check('分解能量随级不降', all(en[i] <= en[i + 1] for i in range(len(en) - 1)), en)
    late = table.get('late_only', {})
    if 'min_level' in late and levels:
        check('late_only.min_level 在 levels 里', late['min_level'] in levels, late['min_level'])
    for k, v in table.get('costs', {}).items():
        if k != '_note':
            check('工坊花费是非负整数：' + k, _is_int(v) and v >= 0, v)
    new = {k for k in table.get('new_affixes', {}) if k != '_note'}
    n_lv = len(order) if isinstance(order, list) else 0
    for key, fx in table.get('effects', {}).items():
        if key == '_note':
            continue
        if new:
            check('effects 的词条在 new_affixes 里：' + key, key in new, key)
        if not isinstance(fx, dict):
            continue
        for f, v in fx.items():
            vals = v if isinstance(v, list) else [v]
            check('effects 数值都是非负数：%s.%s' % (key, f), vals and all(_is_num(x) and x >= 0 for x in vals), v)
            if isinstance(v, list) and n_lv:
                check('effects 分级数组 %d 个（同 level_order）：%s.%s' % (n_lv, key, f), len(v) == n_lv, len(v))
            if (key, f) in ALIEN_PCT_FIELDS and all(_is_num(x) for x in vals):
                check('effects 百分比在 0～100：%s.%s' % (key, f), all(0 <= x <= 100 for x in vals), v)
            if (key, f) in (('again', 'every'), ('dying', 'per_battle')) and all(_is_num(x) for x in vals):
                check('effects 至少 1：%s.%s' % (key, f), all(x >= 1 for x in vals), v)
    # 跨表：词条键要在 rewards.json 的 finale.lines 里（XTianqiAlienGear.line_keys 从那里取）
    lines = (rewards or {}).get('finale', {}).get('lines', {})
    known = {k for ks in lines.values() if isinstance(ks, list) for k in ks}
    if known:
        miss = [k for k in late.get('keys', []) if k not in known]
        check('late_only.keys 在 rewards.json 的 finale.lines 里', not miss, miss)
        miss = sorted(k for k in new if k not in known)
        check('new_affixes 在 rewards.json 的 finale.lines 里', not miss, miss)
    return bad


def check_alien_gear(_args) -> bool:
    return _run_table('alien_gear.json', lambda t: alien_gear_rules(t, _load_opt('rewards.json')))


# abyss_shelves.json：XTianqiMerchant（treasure／collection 两档：cost、rare_cost、layer、min_tier、min_quality）

ABYSS_SHELVES = ('treasure', 'collection')


def abyss_shelves_rules(table: dict, affix: dict = None, qualities: list = None) -> list:
    bad, check = _checker()
    layers = affix_layer_keys(affix) if affix else []
    tiers = affix_tier_ids(affix) if affix else []
    for k in ABYSS_SHELVES:
        sh = table.get(k)
        if sh is None:
            continue
        if not isinstance(sh, dict):
            check('货架是字典：' + k, False, sh)
            continue
        for c in ('cost', 'rare_cost'):
            if c in sh:
                check('%s.%s 是非负整数' % (k, c), _is_int(sh[c]) and sh[c] >= 0, sh[c])
        if _is_int(sh.get('cost')) and _is_int(sh.get('rare_cost')):
            check('%s 稀有价不低于原价' % k, sh['rare_cost'] >= sh['cost'], [sh['cost'], sh['rare_cost']])
        if 'layer' in sh and layers:
            check('%s.layer 在 affix_table 的 layers 里' % k, sh['layer'] in layers, '%s 不在 %s' % (sh['layer'], layers))
        if 'min_tier' in sh:
            check('%s.min_tier 是正整数' % k, _is_int(sh['min_tier']) and sh['min_tier'] > 0, sh['min_tier'])
            if tiers:
                check('%s.min_tier 在 affix_table 的 tiers 里' % k, sh['min_tier'] in tiers, '%s 不在 %s' % (sh['min_tier'], tiers))
        if 'min_quality' in sh and qualities:
            check('%s.min_quality 在 QUALITY_KEYS 里' % k, sh['min_quality'] in qualities, '%s 不在 %s' % (sh['min_quality'], qualities))
    return bad


def check_abyss_shelves(_args) -> bool:
    return _run_table('abyss_shelves.json',
                      lambda t: abyss_shelves_rules(t, _load_opt('affix_table.json'), quality_keys()))


# qiyin_equip.json：XTianqiQiyinEquip（armor.parts[部位].base_id／params、armor.atype、weapons[武器类型键]、artifact.base_id、quality_legacy、names）

def _params_ok(p) -> bool:
    return isinstance(p, list) and len(p) == RM_PARAMS and all(_is_num(x) and x >= 0 for x in p)


def qiyin_equip_rules(table: dict, gear: dict = None) -> list:
    bad, check = _checker()
    if 'quality_legacy' in table:
        check('quality_legacy 是非负整数', _is_int(table['quality_legacy']) and table['quality_legacy'] >= 0, table['quality_legacy'])
    armor = table.get('armor', {})
    if 'atype' in armor:
        check('armor.atype 是正整数', _is_int(armor['atype']) and armor['atype'] > 0, armor['atype'])
    if 'any_class' in armor:
        check('armor.any_class 是布尔', isinstance(armor['any_class'], bool), armor['any_class'])
    parts = {k: v for k, v in armor.get('parts', {}).items() if k != '_note'}
    rows = [('armor.parts.' + k, v) for k, v in parts.items()]
    weapons = {k: v for k, v in table.get('weapons', {}).items() if k != '_note'}
    rows += [('weapons.' + k, v) for k, v in weapons.items()]
    for where, row in rows:
        if not isinstance(row, dict):
            check('底子是字典：' + where, False, row)
            continue
        check('base_id 是正整数：' + where, _is_int(row.get('base_id')) and row['base_id'] > 0, row.get('base_id'))
        check('params 是 %d 个非负数：%s' % (RM_PARAMS, where), _params_ok(row.get('params')), row.get('params'))
    art = table.get('artifact')
    if isinstance(art, dict) and 'base_id' in art:
        check('artifact.base_id 是正整数', _is_int(art['base_id']) and art['base_id'] > 0, art['base_id'])
    for k in parts:
        check('部位键只有 %s：armor.parts 里有 %s' % ('、'.join(QIYIN_PARTS), k), k in QIYIN_PARTS)
    for k, v in table.get('names', {}).items():
        if k != '_note':
            check('names 是字符串：' + k, isinstance(v, str), v)
    # 跨表：qiyin_gear 的六个部位、各武器类型都要有底子（_make_set／_make_weapon 找不到就做不出来）
    if gear:
        if 'parts' in gear and 'parts' in armor:
            gp = [p.get('key') for p in gear['parts'] if isinstance(p, dict)]
            check('qiyin_gear 的部位都有底子', all(k in parts for k in gp), [k for k in gp if k not in parts])
            check('armor.parts 的部位在 qiyin_gear 的 parts 里', all(k in gp for k in parts), [k for k in parts if k not in gp])
        if 'weapon_types' in gear and 'weapons' in table:
            wt = [t.get('key') for t in gear['weapon_types'] if isinstance(t, dict)]
            check('qiyin_gear 的武器类型都有底子', all(k in weapons for k in wt), [k for k in wt if k not in weapons])
            check('weapons 的类型在 qiyin_gear 的 weapon_types 里', all(k in wt for k in weapons), [k for k in weapons if k not in wt])
    return bad


def check_qiyin_equip(_args) -> bool:
    return _run_table('qiyin_equip.json', lambda t: qiyin_equip_rules(t, _qiyin_load('gear')))


# qiyin_show.json：XTianqiQiyinShow（seals[印].glyph／color／accent、true_glow、各段 se／hold／dim／power…、art 路径）

SHOW_SECTIONS = ('set', 'weapon', 'true_seal', 'artifact', 'reveal', 'rift', 'dragon_cut')
SHOW_SECONDS = ('hold', 'flash', 'fade_out', 'step')
SHOW_SHAKE = ('power', 'speed', 'frames')


def qiyin_show_rules(table: dict, gear: dict = None) -> list:
    bad, check = _checker()
    seals = {k: v for k, v in table.get('seals', {}).items() if k != '_note'}
    if 'seals' in table:
        check('seals 七印齐全', sorted(seals) == sorted(QIYIN_SEALS), sorted(seals))
    for k, s in seals.items():
        if k not in QIYIN_SEALS:
            check('印键只有 %s：seals 里有 %s' % ('、'.join(QIYIN_SEALS), k), False)
        if not isinstance(s, dict):
            continue
        for c in ('color', 'accent'):
            if c in s:
                check('%s.%s 是 #RRGGBB' % (k, c), isinstance(s[c], str) and HEX_COLOR_RE.match(s[c]), s[c])
        if 'glyph' in s:
            check('%s.glyph 非空' % k, isinstance(s['glyph'], str) and s['glyph'] != '', s['glyph'])
    if 'true_glow' in table:
        check('true_glow 是 #RRGGBB', isinstance(table['true_glow'], str) and HEX_COLOR_RE.match(table['true_glow']), table['true_glow'])
    for sec in SHOW_SECTIONS:
        d = table.get(sec)
        if not isinstance(d, dict):
            continue
        for k in ('se', 'light_se'):
            if k in d:
                check('%s.%s 是字符串' % (sec, k), isinstance(d[k], str), d[k])
        for k in SHOW_SECONDS:
            if k in d:
                check('%s.%s 秒数非负' % (sec, k), _is_num(d[k]) and d[k] >= 0, d[k])
        if 'dim' in d:
            check('%s.dim 在 0～1' % sec, _is_num(d['dim']) and 0 <= d['dim'] <= 1, d['dim'])
        for k in SHOW_SHAKE:
            if k in d:
                check('%s.%s 是正整数' % (sec, k), _is_int(d[k]) and d[k] > 0, d[k])
    for k, v in table.get('art', {}).items():
        if k != '_note':
            check('art.%s 是 res:// 路径' % k, isinstance(v, str) and v.startswith('res://'), v)
    if gear and 'seals' in gear and seals:
        gs = {s.get('key') for s in gear['seals'] if isinstance(s, dict)}
        miss = sorted(gs - set(seals))
        check('qiyin_gear 的印都有演出', not miss, miss)
    return bad


def check_qiyin_show(_args) -> bool:
    return _run_table('qiyin_show.json', lambda t: qiyin_show_rules(t, _qiyin_load('gear')))


# qiyin_dragon_run.json：XTianqiQiyinDragonRun（fight.troop／shell_enemy／rate／extra_actions／tone／name／battler、scenes、logs）

def qiyin_dragon_run_rules(table: dict) -> list:
    bad, check = _checker()
    f = table.get('fight', {})
    for k in ('troop', 'shell_enemy'):
        if k in f:
            check('fight.%s 是正整数' % k, _is_int(f[k]) and f[k] > 0, f[k])
    if 'extra_actions' in f:
        check('fight.extra_actions 是非负整数', _is_int(f['extra_actions']) and f['extra_actions'] >= 0, f['extra_actions'])
    if 'rate' in f:
        r = f['rate']
        check('fight.rate 是 %d 个正数' % RM_PARAMS,
              isinstance(r, list) and len(r) == RM_PARAMS and all(_is_num(x) and x > 0 for x in r), r)
    if 'tone' in f:
        t = f['tone']
        ok = isinstance(t, list) and len(t) == 4 and all(_is_num(x) for x in t)
        check('fight.tone 是四个数（红绿蓝 -255～255、灰 0～255）',
              ok and all(-255 <= x <= 255 for x in t[:3]) and 0 <= t[3] <= 255, t)
    for k in ('name', 'battler'):
        if k in f:
            check('fight.%s 非空' % k, isinstance(f[k], str) and f[k] != '', f[k])
    for k in ('open_reveal', 'segment_lock'):
        if k in f:
            check('fight.%s 是布尔' % k, isinstance(f[k], bool), f[k])
    for k, rows in table.get('scenes', {}).items():
        if k == '_note':
            continue
        ok = isinstance(rows, list) and rows and all(
            isinstance(r, list) and len(r) == 2 and all(isinstance(x, str) for x in r) for r in rows)
        check('scenes.%s 是 [说话人, 台词] 的列表' % k, ok, rows)
    for k, v in table.get('logs', {}).items():
        if k != '_note':
            check('logs.%s 是非空字符串' % k, isinstance(v, str) and v != '', v)
    return bad


def check_qiyin_dragon_run(_args) -> bool:
    return _run_table('qiyin_dragon_run.json', qiyin_dragon_run_rules)


# ---- T080 期四暗装填表（基础数值重构 v0.3）：base_line.json、gear_base.json、damage_ledger.json 的 phase4、balance_table 的两个新键、技能卡单段上限 ----

ROLE_NAMES = ('输出', '均衡', '坦克', '辅助')
SPEED_NAMES = ('快', '中', '慢')
LINE_HP, LINE_MP = 25.0, 25.0  # 标准线的生命、魔法倍数（base_line.json line 里的值，校验时再核对）


def cond_max(c: dict) -> float:
    """一条伤害条件「成立到最大」时的倍率（只减不加的不算：<1 当 1；自耗类 self_mp_frac 取它的 cap，它本身就是最大倍率）。"""
    i = c.get('if')
    if i == 'self_mp_frac':
        return min(1.0, float(c.get('cap', 1.0)))
    if 'steps' in c:
        m = max(float(x[1]) for x in c['steps'])
    elif 'mult' in c:
        m = float(c['mult'])
    elif 'cap' in c:
        cap = float(c['cap'])
        for v in c.get('cap_with', {}).values():
            cap = max(cap, float(v))
        m = 1.0 + cap
    else:
        m = 1.0
    return max(1.0, m)


def skill_weight(d: dict) -> float:
    """技能伤害里属性权重的合计，折到标准角色：生命、魔法上限按标准线是攻击的 25 倍；max_of 再加 1。"""
    w = 0.0
    for k, v in d.get('stats', {'atk': 1}).items():
        w += float(v) * (LINE_HP if k == 'mhp' else LINE_MP if k == 'mmp' else 1.0)
    if 'max_of' in d:
        w += 1.0
    return w


def tier_of(rework: dict, actor) -> str:
    t = rework.get('tiers', {})
    a = int(actor)
    if a in [int(x) for x in t.get(SUPER, [])]:
        return SUPER
    if a in [int(x) for x in t.get(STRONG, [])]:
        return STRONG
    if a in [int(x) for x in t.get('不开放', [])]:
        return '不开放'
    return WEAK


def single_hit_effective(rework: dict, sid: str, row: dict) -> float:
    """单段有效系数 ＝ 卡上的系数 × Σ属性权重 × 这一段能同时成立的全部条件倍率（技能自己的 conds＋角色行里点到这个技能的 conds）÷ cap_hits（T192）。"""
    d = row['damage']
    m = 1.0
    for c in d.get('conds', []):
        m *= cond_max(c)
    a = row.get('actor')
    if a is not None:
        for c in rework.get('actors', {}).get(str(a), {}).get('conds', []):
            if 'skills' in c and int(sid) not in [int(x) for x in c['skills']]:
                continue
            m *= cond_max(c)
    return float(d.get('coef', 0)) * skill_weight(d) * m / cap_hits(d)


def cap_hits(d: dict) -> float:
    """T192：卡上系数是「N 段合计」、由模块代码按段分的技能写 damage.cap_hits（段数），单段按合计÷段数算（同 XTianqiSkills.cap_hits）。"""
    return max(1.0, float(d.get('cap_hits', 1)))


def single_hit_cap_rules(rework: dict) -> list:
    bad = []
    rules = rework.get('rules', {})
    cap = rules.get('single_hit_cap')
    if cap != {WEAK: 8, STRONG: 11, SUPER: 11}:
        bad.append('rules.single_hit_cap 要是 {弱者 8、强者 11、超强者 11}（D137，整数），现在 %s' % cap)
        return bad
    pending = rules.get('single_hit_cap_pending', {})
    over = []
    for sid, row in rework.get('skills', {}).items():
        if not str(sid).isdigit() or 'damage' not in row or row.get('actor') is None:
            continue
        tier = tier_of(rework, row['actor'])
        if tier not in cap:
            continue
        eff = single_hit_effective(rework, sid, row)
        if eff > cap[tier] + 1e-6:
            over.append((sid, row['name'], tier, eff))
    for sid, name, tier, eff in over:
        if sid not in pending:
            bad.append('skills/%s %s（%s）单段有效系数 %.2f 超过上限 %s，要拆段（合计不变），或登记进 rules.single_hit_cap_pending 写理由' % (sid, name, tier, eff, cap[tier]))
    for sid in pending:
        if sid not in [o[0] for o in over]:
            bad.append('rules.single_hit_cap_pending 里的 %s 已经不超上限，把它从待拆名单里删掉' % sid)
    return bad


def backtest_rules(base: dict, rework: dict) -> list:
    """回验（基础数值重构 v0.3 第四节第 4 条）：Σ(权重×本体属性)÷标准线攻击 对卡面系数，偏差超 ±10% 的必须在 backtest_notes 里有理由。"""
    bad = []
    line = base.get('line', {})
    hp_mult, mp_mult = float(line.get('hp_mult', LINE_HP)), float(line.get('mp_mult', LINE_MP))
    noted = {(int(n['skill']), int(n['actor'])) for n in base.get('backtest_notes', [])}
    seen = set()
    for sid, row in rework.get('skills', {}).items():
        d = row.get('damage')
        if not d or row.get('actor') is None or 'max_of' in d or not str(sid).isdigit():
            continue
        ac = base.get('actors', {}).get(str(row['actor']))
        if not ac:
            continue
        r = base['roles'][ac['role']]
        tw = {k: (v if isinstance(v, (int, float)) else float(v.get('mult', 1.0))) for k, v in ac.get('tweak', {}).items()}
        mult = {'mhp': hp_mult * r['hp'] * tw.get('mhp', 1.0), 'mmp': mp_mult * tw.get('mmp', 1.0),
                'def': r['def'] * tw.get('def', 1.0), 'mdf': r['def'] * tw.get('mdf', 1.0),
                'agi': base['speed'][ac['speed']] * tw.get('agi', 1.0)}
        nom = new = 0.0
        for k, w in d.get('stats', {'atk': 1}).items():
            nom += float(w) * (hp_mult if k == 'mhp' else mp_mult if k == 'mmp' else 1.0)
            new += float(w) * mult.get(k, tw.get(k, 1.0))
        dev = new / nom - 1.0
        if abs(dev) > 0.1 + 1e-9:
            seen.add((int(sid), int(row['actor'])))
            if (int(sid), int(row['actor'])) not in noted:
                bad.append('回验：技能 %s %s（%s）偏差 %+.1f%%，超过 ±10%%，要改微调或权重，或在 backtest_notes 写理由' % (sid, row['name'], ac['name'], dev * 100))
    for k in sorted(noted - seen):
        bad.append('backtest_notes 里的 技能 %s／角色 %s 回验已经不超 ±10%%，删掉这条理由' % k)
    return bad


def base_line_rules(table: dict, rework: dict = None) -> list:
    bad = []
    line = table.get('line', {})
    for k in ('A0', 'A1', 'hp_mult', 'mp_mult'):
        if not isinstance(line.get(k), (int, float)) or line[k] <= 0:
            bad.append('line.%s 要是正数' % k)
    if (line.get('hp_mult'), line.get('mp_mult')) != (LINE_HP, LINE_MP):
        bad.append('line.hp_mult／mp_mult 起点都是 25（技能卡的权重按这个折的），现在 %s／%s' % (line.get('hp_mult'), line.get('mp_mult')))
    roles = table.get('roles', {})
    if set(roles) != set(ROLE_NAMES):
        bad.append('roles 要正好是 %s' % '、'.join(ROLE_NAMES))
    speed = table.get('speed', {})
    if set(speed) != set(SPEED_NAMES):
        bad.append('speed 要正好是 %s' % '、'.join(SPEED_NAMES))
    for k, v in list(roles.items()):
        for f in ('hp', 'def'):
            if not 0.8 <= float(v.get(f, 0)) <= 1.2:
                bad.append('roles.%s.%s 要在 0.8～1.2（职责浮动 ±20%%）' % (k, f))
    for k, v in speed.items():
        if not 0.8 <= float(v) <= 1.2:
            bad.append('speed.%s 要在 0.8～1.2' % k)
    lo, hi = table.get('tweak_range', [0.8, 1.2])
    actors = table.get('actors', {})
    for aid, a in actors.items():
        if not str(aid).isdigit():
            bad.append('actors 键要是角色号：%s' % aid)
            continue
        if a.get('role') not in ROLE_NAMES:
            bad.append('actors/%s 职责要是 %s' % (aid, '／'.join(ROLE_NAMES)))
        if a.get('speed') not in SPEED_NAMES:
            bad.append('actors/%s 速度档要是 %s' % (aid, '／'.join(SPEED_NAMES)))
        for stat, tw in a.get('tweak', {}).items():
            if stat not in ('mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'):
                bad.append('actors/%s 微调的项不认识：%s' % (aid, stat))
            if not isinstance(tw, dict) or not lo <= float(tw.get('mult', 0)) <= hi or not tw.get('reason'):
                bad.append('actors/%s 微调 %s 要写成 {mult: 0.8～1.2, reason: 理由}' % (aid, stat))
    for u in table.get('unclear', []):
        if str(u) not in actors:
            bad.append('unclear 里的 %s 不在 actors 里' % u)
    if rework is not None:
        t = rework.get('tiers', {})
        for tier in (SUPER, STRONG):
            for i in t.get(tier, []):
                if str(i) not in actors:
                    bad.append('%s名单里的 %s 没有在 base_line.actors 里填三格' % (tier, i))
        for i in t.get('不开放', []):
            if str(i) in actors:
                bad.append('不开放的角色 %s 不填 base_line.actors' % i)
        bad += backtest_rules(table, rework)
    return bad


def apply_base_tune(table: dict) -> tuple:
    """游戏里开着 XTianqiBase.TUNE_D189 时读到的本体成长：tune.<键>.actors.<id>.tweak 逐项代替 actors.<id>.tweak（XTianqiBase.actor_mult）。
    返回 (合并后的表, 覆盖层自己的问题)。覆盖层的值游戏按数读，合并时折成 {mult, reason} 好让 base_line_rules 照常查范围（T163 甲核 P3-2）。"""
    import copy
    out = copy.deepcopy(table)
    bad = []
    stats = ('mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk')
    for key in TUNE_KEYS:
        for aid, row in table.get('tune', {}).get(key, {}).get('actors', {}).items():
            if str(aid).startswith('_'):
                continue
            if str(aid) not in out.get('actors', {}):
                bad.append('tune.%s.actors/%s 不在 actors 里' % (key, aid))
                continue
            tw = out['actors'][str(aid)].setdefault('tweak', {})
            for st, v in row.get('tweak', {}).items():
                if st not in stats or isinstance(v, bool) or not isinstance(v, (int, float)):
                    bad.append('tune.%s.actors/%s 微调要写成 属性: 数（游戏按数读）：%s=%r' % (key, aid, st, v))
                    continue
                tw[st] = {'mult': float(v), 'reason': row.get('_note') or 'tune.%s' % key}
    return out, bad


def check_base_line(_args) -> bool:
    if not (DATA_DIR / 'base_line.json').is_file():
        print('跳过：没有 base_line.json')
        return True
    rework = _load_opt('skill_rework.json')
    tuned = apply_skill_tune(rework) if rework else None

    def rules(t):
        bad = base_line_rules(t, rework)
        if not t.get('tune') and not (rework or {}).get('tune'):
            return bad
        tb, tune_bad = apply_base_tune(t)
        tuned_bad = base_line_rules(tb, tuned if tuned is not None else rework)
        # T191：回验理由只要覆盖前或覆盖后有一边用得上就留（取整改了权重比例，偏差只在覆盖后超 ±10%）；两边都用不上才报多余
        stale = 'backtest_notes 里的'
        both = {b for b in bad if b.startswith(stale)} & {b for b in tuned_bad if b.startswith(stale)}
        bad = [b for b in bad if not b.startswith(stale) or b in both]
        tuned_bad = [b for b in tuned_bad if not b.startswith(stale) or b in both]
        return bad + ['tune 覆盖后：' + b for b in tune_bad + tuned_bad if b not in bad]
    return _run_table('base_line.json', rules)


def gear_base_rules(table: dict, base: dict = None) -> list:
    bad = []
    slots = table.get('slots', {})
    if len(slots) != 10:
        bad.append('slots 要 10 个部位（武器、副手、头部、盔甲、护手、腰带、裤子、鞋子、项链、戒指），现在 %d 个' % len(slots))
    etypes = [v.get('etype') for v in slots.values()]
    if sorted(etypes) != list(range(1, 11)):
        bad.append('slots 的 etype 要正好是 1～10 各一个：%s' % etypes)
    tot = {k: 0.0 for k in ('atk', 'hp', 'def', 'agi', 'luk')}
    for name, v in slots.items():
        for k in tot:
            tot[k] += float(v.get(k, 0))
        for k in v:
            if k not in tot and k != 'etype':
                bad.append('slots/%s 不认识的项 %s' % (name, k))
    for k, (lo, hi) in table.get('slot_totals_range', {}).items():
        if not lo - 1e-9 <= tot.get(k, 0) <= hi + 1e-9:
            bad.append('全身合计 %s ＝ %.2f，不在 %s～%s' % (k, tot.get(k, 0), lo, hi))
    keys = ['putong', 'youxiu', 'jingliang', 'shishi', 'chuanshuo', 'buxiu', 'shenhua']
    try:
        keys = quality_keys()
    except Exception:
        pass
    g = table.get('grades', {})
    if list(g) != keys:
        bad.append('grades 的键要同 tianqi_affix_roll.gd 的 QUALITY_KEYS：%s' % keys)
    else:
        vals = [float(g[k]) for k in keys]
        step = float(table.get('grade_step_min', 0.2))
        for a, b in zip(vals, vals[1:]):
            if b - a < step - 1e-9:
                bad.append('品质系数相邻两档至少差 %s：%s' % (step, vals))
                break
        if vals[-1] > vals[0] * float(table.get('grade_max_over_min', 3.5)) + 1e-9:
            bad.append('神话不超过普通的 %s 倍：%s' % (table.get('grade_max_over_min', 3.5), vals))
    ratio = table.get('ratio', {})
    if sorted(int(k) for k in ratio) != list(range(0, 91)):
        bad.append('ratio 要有装备等级 0～90 各一行')
    prev = None
    for k in sorted(ratio, key=int):
        row = ratio[k]
        if set(row) != {'atk', 'hp', 'def', 'agi', 'luk'} or not all(float(v) > 0 for v in row.values()):
            bad.append('ratio/%s 要有 atk、hp、def、agi、luk 五个正数' % k)
        elif int(k) >= 20 and not all(3.0 <= float(v) <= 8.0 for v in row.values()):
            bad.append('ratio/%s 超出常理范围 3～8（原版弱者本体约是标准线的六分之一）：%s' % (k, row))
    q = table.get('qiyin', {})
    if q.get('level') != 80 or q.get('first_kill_level') != 75 or q.get('grade') != 'shenhua' or q.get('weapon_and_true_seal_mult') != 1.1:
        bad.append('qiyin 要写 80 级神话、首杀 75 级、武器和真印 ×1.1（qiyin_gear.json 的规则）：%s' % q)
    return bad


def check_gear_base(_args) -> bool:
    return _run_table('gear_base.json', gear_base_rules)


def ledger_phase4_rules(table: dict, balance: dict = None) -> list:
    bad = []
    p4 = table.get('phase4')
    if not isinstance(p4, dict):
        return ['damage_ledger.json 要有 phase4 小节']
    now = {r['id']: r for r in table.get('derived', [])}
    rows = p4.get('derived_qiyin', [])
    if [r['id'] for r in rows] != [i for i in now if i.startswith('qiyin.')]:
        bad.append('phase4.derived_qiyin 要正好是 derived 里的七印 4 行（同序）')
    for r in rows:
        cur = now.get(r['id'])
        if cur is not None and any(r.get(k) != cur.get(k) for k in ('per_turn', 'ratio', 'enforced')):
            bad.append('phase4.derived_qiyin/%s 要照 derived 现值，一个不改（D16）' % r['id'])
    mods = [r['id'] for r in p4.get('derived_module', [])]
    if mods != [i for i in now if i.startswith('module.')]:
        bad.append('phase4.derived_module 要正好是 derived 里的模块 7 行（同序）：%s' % mods)
    if p4.get('nine_crit_dmg_cap') != 0.3:
        bad.append('phase4.nine_crit_dmg_cap 要是 0.3（九线爆伤合计封顶 +30%）')
    if p4.get('secret_slot') != 0.08:
        bad.append('phase4.secret_slot 要是 0.08（秘籍每格 +8%，不改）')
    if p4.get('brand', {}).get('id') != 'brand':
        bad.append('phase4.brand 要登记烙印一行')
    return bad


def check_ledger_phase4(_args) -> bool:
    return _run_table('damage_ledger.json', ledger_phase4_rules)


def combat_rules_phase4_rules(table: dict) -> list:
    bad = []
    cr = table.get('combat_rules', {})
    k = cr.get('base_damage')
    if not isinstance(k, (int, float)) or not 0.05 <= float(k) <= 1.0:
        bad.append('combat_rules.base_damage（K）要在 0.05～1（暗装期先填 1，标定后 0.07～0.17）：%s' % k)
    u = cr.get('boss_hp_temp_unit')
    if not isinstance(u, dict) or set(u) != {'crit', 'no_crit'}:
        bad.append('combat_rules.boss_hp_temp_unit 要是 {crit, no_crit} 两个数')
    else:
        for kk, v in u.items():
            # T241（D222 丙）：U 改整数百分比，先填 100＝不打折，标定后约 20～30
            if not isinstance(v, int) or isinstance(v, bool) or not 10 <= v <= 100:
                bad.append('combat_rules.boss_hp_temp_unit.%s 要是 10～100 的整数百分比（先填 100，标定后约 20～30）：%s' % (kk, v))
    return bad


def check_combat_rules_phase4(_args) -> bool:
    return _run_table('balance_table.json', combat_rules_phase4_rules)


def check_single_hit_cap(_args) -> bool:
    return _run_table('skill_rework.json', _with_tune(single_hit_cap_rules))


def abs_rescale_rules(table: dict) -> list:
    bad = []
    for i, e in enumerate(table.get('entries', [])):
        if not all(k in e for k in ('kind', 'id', 'name', 'orig', 'new')):
            bad.append('entries/%d 要有 kind、id、name、orig、new' % i)
            continue
        n = e['new']
        if e['kind'] == 'state_shuxing':  # T228：持有者自身 8 项的整数百分比；计数器状态 mode＝raw 保留原数
            if not isinstance(n, dict) or n.get('pct_of') != 'self':
                bad.append('entries/%d（state_shuxing %s）new.pct_of 要是 self：%s' % (i, e['id'], n))
            elif n.get('mode') == 'raw':
                if not n.get('reason'):
                    bad.append('entries/%d（state_shuxing %s）mode＝raw 要写 reason' % (i, e['id']))
            elif not (isinstance(n.get('pct'), list) and len(n['pct']) == 8
                      and all(isinstance(x, int) and not isinstance(x, bool) for x in n['pct'])):
                bad.append('entries/%d（state_shuxing %s）new.pct 要是 8 个整数：%s' % (i, e['id'], n.get('pct')))
            elif n.get('note_pct') is not None and not (n['note_pct'] is True and n['pct'] == e.get('orig')):
                bad.append('entries/%d（state_shuxing %s）new.note_pct（T242，备注本来就是百分比）只能是 true，且 pct 要等于 orig：%s' % (i, e['id'], n))
            continue
        if e['kind'] in ('skill_fixed_heal', 'skill_fixed_drain'):  # T243：结构化；固定底数 base 换成对象上限的整数 %（附则 E），没底数的 mode＝raw
            tag = 'entries/%d（%s %s）' % (i, e['kind'], e['id'])
            isint = lambda x: isinstance(x, int) and not isinstance(x, bool)
            if not isinstance(n, dict):
                bad.append(tag + 'new 要是结构化的 {pct_of, pct, base} 或 {mode: raw, reason}：%s' % (n,))
            elif n.get('mode') == 'raw':
                if not n.get('reason'):
                    bad.append(tag + 'mode＝raw 要写 reason')
            elif not (isint(n.get('pct')) and 1 <= n['pct'] <= 100 and n.get('pct_of') in ('mhp', 'mmp')
                      and isinstance(n.get('base'), (int, float)) and not isinstance(n.get('base'), bool) and n['base'] > 0
                      and ('over100' not in n or (isint(n['over100']) and n['over100'] > 100))
                      and isinstance(e['orig'], str) and e['orig']):
                bad.append(tag + 'new 要是 pct_of mhp／mmp、pct 1～100 的整数、base 正数、over100（有的话）大于 100 的整数，orig 是完整原公式：%s' % (n,))
            continue
        # T246：其余几类也全部结构化：药品、常数持续伤害 {pct_of, pct}（整数，附则 E）；公式型持续伤害另带 base、sha256；
        # 护盾（state_shield、note_shieldeffect）、吸血（note_dbhplsteal）、重复的 note_regen_formula 只能 mode＝raw
        tag = 'entries/%d（%s %s）' % (i, e['kind'], e['id'])
        isint = lambda x: isinstance(x, int) and not isinstance(x, bool)
        if not isinstance(n, dict):
            bad.append(tag + 'new 要是结构化的 {pct_of, pct} 或 {mode: raw, reason}，不能是文字说明：%s' % (n,))
            continue
        if n.get('mode') == 'raw':
            if not n.get('reason'):
                bad.append(tag + 'mode＝raw 要写 reason')
            continue
        if e['kind'] in ('state_shield', 'note_shieldeffect', 'note_dbhplsteal', 'note_regen_formula'):
            bad.append(tag + '护盾／吸血倍率、重复列出的回复公式只能 mode＝raw（没有代码按 pct 读它）：%s' % (n,))
            continue
        if not (isint(n.get('pct')) and 1 <= n['pct'] <= 100 and n.get('pct_of') in ('mhp', 'mmp')
                and ('over100' not in n or (isint(n['over100']) and n['over100'] > 100))):
            bad.append(tag + 'new 要是 pct_of mhp／mmp、pct 1～100 的整数（附则 E）、over100（有的话）大于 100 的整数：%s' % (n,))
        elif 'base' in n:
            if e['kind'] != 'state_dot' or n['pct_of'] != 'mhp':
                bad.append(tag + '带 base 的只认公式型 state_dot（按持有者生命上限）：%s' % (n,))
            elif not (isinstance(n['base'], (int, float)) and not isinstance(n['base'], bool) and n['base'] > 0
                      and isinstance(n.get('sha256'), str) and len(n['sha256']) == 64 and isinstance(e['orig'], str) and e['orig']):
                bad.append(tag + '公式型要有正数 base、64 位 sha256（程序指纹，运行时对不上照原式）、orig 是公式原文：%s' % (n,))
        elif not isinstance(e['orig'], (int, float)) or isinstance(e['orig'], bool):
            bad.append(tag + '整条换算的 orig 要是原数：%r' % (e['orig'],))
    un = table.get('unscanned')
    if not (isinstance(un, list) and un and all(isinstance(x, str) and x for x in un)):
        bad.append('unscanned 要列出还没扫的范围（horsemen.json 没盘，不能清空）')
    elif any('Custom Regenerate' in x for x in un):
        bad.append('unscanned 不该再列 Custom Regenerate Effect（T249 已盘进 groups.custom_regen）')
    bad += abs_groups_rules(table.get('groups', {}))
    return bad


# T249：groups 里敌人技能底数、属性门槛、脚本型回复三组定口径，都不接线；口径写在 new（mode、reason）
THRESHOLD_MODES = ('card', 'card_off', 'raw')


def abs_groups_rules(groups: dict) -> list:
    bad = []
    raw_ok = lambda n: isinstance(n, dict) and n.get('mode') == 'raw' and isinstance(n.get('reason'), str) and n['reason']
    g = groups.get('enemy_skill_fixed_base')
    if not isinstance(g, dict) or not raw_ok(g.get('new')):
        bad.append('groups.enemy_skill_fixed_base 要有 new {mode: raw, reason}（T249：期四敌人攻击魔攻没换，底数占比不变，不接线）')
    elif 'new_rule' in g:
        bad.append('groups.enemy_skill_fixed_base 不该再有 new_rule（T249 已定 raw，没有代码按它换）')
    elif not all(isinstance(r, list) and len(r) == 4 and isinstance(r[0], int) for r in g.get('rows', [])) or not g.get('rows'):
        bad.append('groups.enemy_skill_fixed_base.rows 要是 [技能号, 名字, 底数, 占比] 四格')
    t = groups.get('abs_threshold_in_notes', {})
    for r in t.get('rows', []) if isinstance(t, dict) else []:
        n = r.get('new')
        tag = 'groups.abs_threshold_in_notes/%s ' % r.get('id')
        if not (isinstance(n, dict) and n.get('mode') in THRESHOLD_MODES and isinstance(n.get('reason'), str) and n['reason']):
            bad.append(tag + 'new 要是 {mode: card／card_off／raw, reason}：%s' % (n,))
        elif (n['mode'] == 'card') != bool(r.get('in_card')):
            bad.append(tag + 'mode＝card 只给 in_card＝true 的行（卡里 drop_if 去掉门槛段），反过来也一样：%s' % (n,))
    c = groups.get('custom_regen')
    if not isinstance(c, dict) or not raw_ok(c.get('new')):
        bad.append('groups.custom_regen 要有 new {mode: raw, reason}（T249：脚本型回复随施法者属性走，不接线）')
    else:
        rows = c.get('rows', [])
        ids = [r.get('id') for r in rows if isinstance(r, dict)]
        if not rows or len(ids) != len(rows) or len(set(ids)) != len(ids) or not all(isinstance(i, int) for i in ids):
            bad.append('groups.custom_regen.rows 要是 {id, name, uses} 且 id 不重复')
        for r in rows:
            u = r.get('uses') if isinstance(r, dict) else None
            if not isinstance(u, list) or not all(isinstance(x, str) for x in u):
                bad.append('groups.custom_regen/%s uses 要是属性名列表' % (r.get('id') if isinstance(r, dict) else r))
    return bad


def check_abs_rescale(_args) -> bool:
    return _run_table('abs_rescale.json', abs_rescale_rules)


# brand.json：烙印（T073-a，稿《天启篇_烙印 v0.5》第十节第 1 条）。现在没有代码读它；稿定的数带 4（0.4、40、4%）
BRAND_FITS = ['发呆', '哑火', '抽自己', '破防', '六亲不认', '换人']
BRAND_COSTS = ['bird', 'thin', 'weak_heal', 'no_group', 'burn', 'one_life']
BRAND_SEAR_LEVELS = ['没异化', '侵染', '蚀骨', '化形', '终焉']
BRAND_RIPE_FORBID = ('抽自己', '六亲不认', '换人')


def _brand_ranges(node, path, bad):
    """任何 X 旁边有 X_range 的，X 要落在范围里（范围里的数就是稿第十节第 2 条的参数范围）。"""
    if isinstance(node, dict):
        for k, v in node.items():
            r = node.get(k + '_range')
            if isinstance(v, (int, float)) and not isinstance(v, bool) and isinstance(r, list) and len(r) == 2:
                if not r[0] - EPS <= v <= r[1] + EPS:
                    bad.append('%s/%s=%s 不在范围 %s 里' % (path, k, num_text(v), r))
            _brand_ranges(v, path + '/' + k, bad)
    elif isinstance(node, list):
        for i, x in enumerate(node):
            _brand_ranges(x, '%s/%d' % (path, i), bad)


def brand_rules(table: dict, balance: dict = None) -> list:
    bad = []
    num = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool)
    try:
        nodes, realms = table['nodes']['caps'], table['nodes']['realms']
        power, costs, fits = table['power'], table['costs'], table['fits']
        ripe, sear, gain = table['ripe'], table['sear'], table['gain']
        boss, trade, aggro = table['boss'], table['trade'], table['aggro']
    except (KeyError, TypeError) as e:
        return ['brand.json 缺段：%s（要有 power、nodes、aggro、costs、fits、ripe、sear、gain、boss、trade）' % e]
    # 节点
    if len(realms) != 7 or len(nodes) != 7:
        bad.append('nodes 要正好七境七个节点')
    if not all(num(n) for n in nodes) or any(b <= a for a, b in zip(nodes, nodes[1:])):
        bad.append('nodes.caps 要严格递增：%s' % nodes)
    if nodes and nodes[-1] != 100:
        bad.append('nodes.caps 末项要是 100：%s' % nodes[-1:])
    if not num(power.get('max_bonus')) or power['max_bonus'] > 0.5 + EPS:
        bad.append('power.max_bonus 不超过 0.5（D147）：%s' % power.get('max_bonus'))
    # 不刻印
    ucap, urealm = gain.get('uncarved_cap'), gain.get('uncarved_max_realm')
    if ucap not in nodes:
        bad.append('gain.uncarved_cap 要是节点之一：%s' % ucap)
    elif not _is_int(urealm) or not 0 <= urealm < len(nodes) or nodes[urealm] != ucap:
        bad.append('gain.uncarved_cap 要正好是 uncarved_max_realm 那一境的节点：%s／%s' % (ucap, urealm))
    # 换伤支
    br = trade.get('branches', [])
    if len(br) != 4:
        bad.append('trade.branches 要正好四条：%d' % len(br))
    for b in br:
        if b.get('damage') != b.get('taken'):
            bad.append('trade/%s 伤害和承伤要相等：%s／%s' % (b.get('key'), b.get('damage'), b.get('taken')))
        if b.get('realm') not in realms:
            bad.append('trade/%s 的境不在七境里：%s' % (b.get('key'), b.get('realm')))
    # 常驻六条、发作六种：齐，且 over 照节点（第 i 条在 caps[i] 之后）
    ck = [c.get('key') for c in costs.get('list', [])]
    if ck != BRAND_COSTS:
        bad.append('costs.list 要是常驻六条（%s）：%s' % ('、'.join(BRAND_COSTS), ck))
    fn = [f.get('name') for f in fits.get('list', [])]
    if fn != BRAND_FITS:
        bad.append('fits.list 要是发作六种（%s）：%s' % ('、'.join(BRAND_FITS), fn))
    for what, rows in (('costs', costs.get('list', [])), ('fits', fits.get('list', []))):
        if [r.get('over') for r in rows] != nodes[:6]:
            bad.append('%s.list 各条的 over 要等于前六个节点 %s：%s' % (what, nodes[:6], [r.get('over') for r in rows]))
        if [r.get('realm') for r in rows if 'realm' in r] and [r['realm'] for r in rows] != realms[1:]:
            bad.append('%s.list 各条的境要是不染到逆命' % what)
    thin = next((c for c in costs.get('list', []) if c.get('key') == 'thin'), None)
    if thin and num(thin.get('step')) and thin['step'] > 0:
        want = (100 - thin['over']) / thin['step'] * thin.get('per_step', 0)
        if abs(want - thin.get('at_full', -1)) > 1e-6:
            bad.append('皮薄 100%% 时要降 (100−over)÷step×per_step ＝ %s：%s' % (num_text(want), thin.get('at_full')))
    ol = costs.get('one_life', {})
    one = next((c for c in costs.get('list', []) if c.get('key') == 'one_life'), {})
    if ol.get('no_revive_over') != one.get('over') or not num(ol.get('revive_once_over')) or ol['revive_once_over'] >= one.get('over', 0):
        bad.append('一条命：no_revive_over 要等于它的 over，前一档 revive_once_over 要更早：%s／%s' % (ol, one.get('over')))
    # 熟
    rf = ripe.get('fits', [])
    if not rf or not set(rf) <= set(BRAND_FITS):
        bad.append('ripe.fits 要是六种花样的子集且不空：%s' % rf)
    if set(rf) & set(BRAND_RIPE_FORBID):
        bad.append('ripe.fits 不含抽自己、六亲不认、换人：%s' % sorted(set(rf) & set(BRAND_RIPE_FORBID)))
    # 灼痕
    ph = sear.get('per_hit', {})
    vals = [ph.get(k) for k in BRAND_SEAR_LEVELS]
    if set(ph) != set(BRAND_SEAR_LEVELS) or not all(num(v) for v in vals) or any(b <= a for a, b in zip(vals, vals[1:])):
        bad.append('sear.per_hit 要有 %s 五级且逐级递增：%s' % ('、'.join(BRAND_SEAR_LEVELS), ph))
    st = sear.get('settle', {})
    if st.get('折法') != '满了才算':
        bad.append('sear.settle.折法 要是「满了才算」（D143 ①）：%s' % st.get('折法'))
    if not _is_int(st.get('max_per_fight')) or st['max_per_fight'] < 1:
        bad.append('sear.settle.max_per_fight 要是正整数：%s' % st.get('max_per_fight'))
    # 首通
    fc = gain.get('first_clear', {})
    per_floor = {}
    for sg in fc.get('segments', []):
        for f in range(sg['from'], sg['to'] + 1):
            per_floor[f] = sg['each']
    for f, v in fc.get('floors', {}).items():
        per_floor[int(f)] = v
    total, running = 0, {}
    for f in sorted(per_floor):
        total += per_floor[f]
        running[f] = total
    if total > 100:
        bad.append('首通给的数加起来不超过 100：%s' % total)
    for i, f in enumerate(range(5, 31, 5)):
        if running.get(f) != nodes[i]:
            bad.append('第 %d 层末首通累计要正好等于节点 %s：%s' % (f, nodes[i], running.get(f)))
    for f, v in gain.get('layer_line', {}).items():
        if running.get(int(f)) != v:
            bad.append('layer_line/%s 要等于首通累计 %s：%s' % (f, running.get(int(f)), v))
    # 难度系数的键照 balance_table
    if balance:
        keys = [d.get('key') for d in balance.get('difficulties', [])]
        if keys and list(gain.get('replay', {}).get('difficulty', {})) != keys:
            bad.append('gain.replay.difficulty 的键要和 balance_table 难度同序：%s' % keys)
    # 首领判定
    ids = boss.get('exclude_enemy_ids', [])
    if not ids or not all(_is_int(i) for i in ids):
        bad.append('boss.exclude_enemy_ids 要是敌人编号整数、不空：%s' % ids)
    if not boss.get('prefixes') or len(set(boss['prefixes'])) != len(boss['prefixes']):
        bad.append('boss.prefixes 不空、不重复')
    if boss.get('special') != ['心魔', '五条悟试炼', '神兵试炼']:
        bad.append('boss.special 要是心魔、五条悟试炼、神兵试炼：%s' % boss.get('special'))
    if not (num(aggro.get('outsider_base')) and num(aggro.get('bird_mult')) and aggro['bird_mult'] >= 1):
        bad.append('aggro 外人项、出头鸟项要是数且出头鸟 ≥ 1')
    _brand_ranges(table, '', bad)
    return bad


# ---- guardian_params.json（守层者能力值重锚，T237；七印里副本 qiyin 行 T245） ----

GP_STATS = {'mhp': 0, 'mmp': 1, 'atk': 2, 'def': 3, 'mat': 4, 'mdf': 5, 'agi': 6, 'luk': 7}


def _gp_row(name: str, row, stats: dict) -> list:
    bad = []
    if not isinstance(row, dict):
        return ['%s 不是对象' % name]
    for k, v in row.items():
        if str(k).startswith('_'):
            continue
        if k not in stats:
            bad.append('%s 的 %s 不在 stats 里' % (name, k))
        elif k == 'mhp':
            bad.append('%s 写了 mhp（rescale_params 只换 1～7 项，血量走 HP_BASE，写了不生效）' % name)
        if isinstance(v, bool) or not isinstance(v, (int, float)) or float(v) != int(v) or int(v) <= 0:
            bad.append('%s 的 %s＝%r 不是正整数百分比' % (name, k, v))
    return bad


def guardian_params_rules(table: dict) -> list:
    bad = []
    ref = table.get('ref_enemy')
    if isinstance(ref, bool) or not isinstance(ref, int) or ref <= 0:
        bad.append('ref_enemy＝%r 不是正整数' % (ref,))
    stats = table.get('stats', {})
    if stats != GP_STATS:
        bad.append('stats 不是八项 0～7：%r' % (stats,))
    floors = table.get('floors', {})
    if not isinstance(floors, dict):
        bad.append('floors 不是对象')
        floors = {}
    for f, row in floors.items():
        if f not in ('31', '32', '33', '34'):
            bad.append('floors 有 %s 层（只认 31～34，代码 rescale_params 只看这四层）' % f)
        bad += _gp_row('%s 层' % f, row, GP_STATS)
    if 'qiyin' in table:
        bad += _gp_row('qiyin', table['qiyin'], GP_STATS)
    return bad


def check_guardian_params(_args) -> bool:
    return _run_table('guardian_params.json', guardian_params_rules)


# ---- growth.json（渡鸦、奈叶、流萤无限成长，T256） ----

GROWTH_ACTORS = {'raven': 167, 'nanoha': 108, 'liuying': 179}


def _growth_ints(node, path, bad):
    """附则 E：表里的数一律整数（下划线开头的注释键、字符串除外）。"""
    if isinstance(node, dict):
        for k, v in node.items():
            if not str(k).startswith('_'):
                _growth_ints(v, '%s.%s' % (path, k) if path else str(k), bad)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            _growth_ints(v, '%s[%d]' % (path, i), bad)
    elif isinstance(node, float):
        bad.append('%s＝%r 不是整数（附则 E）' % (path, node))


def _pos_int(v, allow_zero=False) -> bool:
    return _is_int(v) and (v >= 0 if allow_zero else v > 0)


def growth_rules(table: dict) -> list:
    bad = []
    _growth_ints(table, '', bad)
    price = table.get('price', {})
    segs = price.get('segments', [])
    if not isinstance(segs, list) or not segs:
        bad.append('price.segments 是空的')
        segs = []
    nxt, last = 1, 0
    for i, sg in enumerate(segs):
        f, t, sh = sg.get('from'), sg.get('to'), sg.get('shares')
        if not (_pos_int(f) and _pos_int(t) and _pos_int(sh)):
            bad.append('price.segments[%d] 的 from／to／shares 不是正整数：%r' % (i, sg))
            continue
        if f != nxt or t < f:
            bad.append('price.segments[%d] 不连续：从 %d 层起，应从 %d 层起、到不早于起' % (i, f, nxt))
        if sh < last:
            bad.append('price.segments[%d] 每层份数 %d 比上一段 %d 少（层价只升不降）' % (i, sh, last))
        nxt, last = t + 1, sh
    if not (_is_int(price.get('grow')) and price.get('grow') >= 2):
        bad.append('price.grow＝%r 不是 ≥2 的整数' % (price.get('grow'),))
    if not (_pos_int(price.get('turn')) and price.get('turn') < nxt):
        bad.append('price.turn＝%r 不在分段写明的层里（1～%d）' % (price.get('turn'), nxt - 1))
    if not (_is_int(price.get('max_layer')) and price.get('max_layer') >= nxt):
        bad.append('price.max_layer＝%r 比分段末层还小' % (price.get('max_layer'),))
    fr = table.get('floor_rule', {})
    if not _pos_int(fr.get('window'), True):
        bad.append('floor_rule.window＝%r 不是非负整数' % (fr.get('window'),))
    if not (_pos_int(fr.get('abyss_cap')) and fr.get('abyss_cap') <= 36):
        bad.append('floor_rule.abyss_cap＝%r 不在 1～36' % (fr.get('abyss_cap'),))
    if not (isinstance(fr.get('abyss_prefix'), str) and fr.get('abyss_prefix')):
        bad.append('floor_rule.abyss_prefix 不是非空字符串')
    if not (_pos_int(fr.get('king_tier')) and fr.get('king_tier') <= 4):
        bad.append('floor_rule.king_tier＝%r 不在 1～4（XDungeon.VAR_TIER 的档）' % (fr.get('king_tier'),))
    acts = table.get('actors', {})
    for key, aid in GROWTH_ACTORS.items():
        r = acts.get(key)
        if not isinstance(r, dict):
            bad.append('actors 缺 %s' % key)
            continue
        if r.get('actor') != aid:
            bad.append('actors.%s.actor＝%r，应是 %d' % (key, r.get('actor'), aid))
        if not _pos_int(r.get('base'), True):
            bad.append('actors.%s.base＝%r 不是非负整数' % (key, r.get('base')))
        if not _pos_int(r.get('share')):
            bad.append('actors.%s.share＝%r 不是正整数（一份）' % (key, r.get('share')))
        flat = r.get('flat', {})
        if not isinstance(flat, dict):
            bad.append('actors.%s.flat 不是对象' % key)
            flat = {}
        for k, v in flat.items():
            if str(k) not in ('0', '1', '2', '3', '4', '5', '6', '7'):
                bad.append('actors.%s.flat 的键 %s 不是能力编号 0～7' % (key, k))
            if not _pos_int(v):
                bad.append('actors.%s.flat.%s＝%r 不是正整数' % (key, k, v))
    rv, nh, ly = acts.get('raven', {}), acts.get('nanoha', {}), acts.get('liuying', {})
    if isinstance(rv, dict):
        if not _pos_int(rv.get('need_skill')):
            bad.append('actors.raven.need_skill 不是正整数（至尊鸦皇 10136）')
        if set(rv.get('flat', {}).keys()) != {'4'}:
            bad.append('actors.raven.flat 只该有 4（魔法攻击）：%r' % (rv.get('flat'),))
    if isinstance(nh, dict) and set(nh.get('flat', {}).keys()) != {'0', '1'}:
        bad.append('actors.nanoha.flat 只该有 0、1（最大生命、最大魔法）：%r' % (nh.get('flat'),))
    if isinstance(ly, dict):
        if ly.get('flat'):
            bad.append('actors.liuying 不走平加，不该有 flat（稿 3.5 末条）')
        for k in ('ember', 'ember_cap', 'dmg_step'):
            if not _pos_int(ly.get(k)):
                bad.append('actors.liuying.%s＝%r 不是正整数' % (k, ly.get(k)))
        if not _pos_int(ly.get('dmg_pct'), True):
            bad.append('actors.liuying.dmg_pct＝%r 不是非负整数' % (ly.get('dmg_pct'),))
    return bad


def check_growth(_args) -> bool:
    return _run_table('growth.json', growth_rules)


def check_brand(_args) -> bool:
    bal = DATA_DIR / 'balance_table.json'
    balance = json.loads(bal.read_text(encoding='utf-8')) if bal.is_file() else None
    return _run_table('brand.json', lambda t: brand_rules(t, balance))


# ---- six_dim.json（天启篇六维，T275；设定稿 天启篇_角色六维_v0.3定稿 第一节 R1～R4） ----

SIX_LETTERS = ['E', 'D', 'C', 'B', 'A', 'S', 'SS', 'SSS']
SIX_DIMS = ['output', 'survive', 'speed', 'wit', 'resolve', 'support']
SIX_CLASSES = ['minion', 'weak', 'strong', 'super', 'elite', 'knight']
SIX_BUDGETS = {'minion': (10, 18), 'weak': (13, 22), 'strong': (18, 25), 'super': (20, 26), 'elite': (18, 25), 'knight': (20, 26)}


def six_dim_row_rules(name: str, row: dict, cls: str) -> list:
    """一份六维（六个字母）过 R1～R4。"""
    bad = []
    if cls not in SIX_BUDGETS:
        return ['%s：class 要是 %s 之一：%r' % (name, SIX_CLASSES, cls)]
    if sorted(k for k in row if k in SIX_DIMS) != sorted(SIX_DIMS):
        return ['%s：六维要齐全（%s）' % (name, SIX_DIMS)]
    sc = {}
    for k in SIX_DIMS:
        if row[k] not in SIX_LETTERS:
            return ['%s：%s 的档位 %r 不在 %s' % (name, k, row[k], SIX_LETTERS)]
        sc[k] = SIX_LETTERS.index(row[k]) + 1
    total = sum(sc.values())
    n_sss = sum(1 for v in sc.values() if v == 8)
    n_ss = sum(1 for v in sc.values() if v == 7)
    n_s = sum(1 for v in sc.values() if v == 6)
    # R4 分档总分：T280 起只报告不拦（见 six_dim_r4_report），Kyo 11-19 说超强者／强者／弱者总分给得不合理，等他看完分布再定预算
    if n_sss > 1:
        bad.append('%s：R1 SSS 至多 1 个，现在 %d 个' % (name, n_sss))
    if n_sss + n_ss > 1:
        bad.append('%s：R2 SS 与 SSS 合计至多 1 个，现在 %d 个' % (name, n_sss + n_ss))
    if n_sss == 1:
        rest = [v for v in sc.values() if v != 8]
        if any(v >= 6 for v in rest):
            bad.append('%s：R1 有 SSS 时其余五维不许 S／SS／SSS' % name)
        if sum(1 for v in rest if v == 5) > 1:
            bad.append('%s：R1 有 SSS 时其余五维最多 1 项 A' % name)
        if sum(1 for v in rest if v <= 3) < 3:
            bad.append('%s：R1 有 SSS 时其余五维至少 3 项 ≤C' % name)
        if not any(v <= 2 for v in rest):
            bad.append('%s：R1 有 SSS 时其余五维至少 1 项 ≤D' % name)
        if total > 22:
            bad.append('%s：R1 有 SSS 时总分要 ≤22，现在 %d' % (name, total))
    elif n_ss == 1:
        rest = [v for v in sc.values() if v != 7]
        if sum(1 for v in rest if v == 6) > 1:
            bad.append('%s：R2 有 SS 时其余五维 S 至多 1 项' % name)
        # T280（Kyo 11-19「SS 的代价有点高：至少两个 C 及以下就行，不用 D」）：其余五维至少 2 项 ≤C
        if sum(1 for v in rest if v <= 3) < 2:
            bad.append('%s：R2 SS 无明显短板（其余五维要至少 2 项 ≤C）' % name)
    else:
        cap = 1 if cls in ('minion', 'weak') else 2
        if n_s > cap:
            bad.append('%s：R3 %s 档 S 至多 %d 项，现在 %d 项' % (name, cls, cap, n_s))
    return bad


def _six_ints(node, path, bad):
    """附则 E：表里不许有小数（下划线开头的注释键除外）。"""
    if isinstance(node, dict):
        for k, v in node.items():
            if not str(k).startswith('_'):
                _six_ints(v, path + '/' + str(k), bad)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            _six_ints(v, '%s[%d]' % (path, i), bad)
    elif isinstance(node, float):
        bad.append('%s 是小数 %r（附则 E：全整数）' % (path, node))


def six_dim_rules(table: dict, base: dict = None, horsemen: dict = None) -> list:
    bad = []
    _six_ints(table, '', bad)
    if table.get('scale') != {l: i + 1 for i, l in enumerate(SIX_LETTERS)}:
        bad.append('scale 要正好是 E～SSS＝1～8')
    if table.get('dims') != SIX_DIMS:
        bad.append('dims 要是 %s' % SIX_DIMS)
    for key in ('resist_pct', 'ai_tier'):
        if list(table.get(key, {})) != SIX_LETTERS:
            bad.append('%s 要有 E～SSS 八档（按序）' % key)
    rp = table.get('resist_pct', {})
    if rp.get('C') != 0 or any(not -10 <= v <= 10 for v in rp.values() if isinstance(v, int)):
        bad.append('resist_pct：C 要是 0、全在 −10～10')
    if any(a > b for a, b in zip(list(rp.values()), list(rp.values())[1:])):
        bad.append('resist_pct 要随档位不降')
    for k, v in table.get('ai_weights', {}).items():
        if list(v) != SIX_LETTERS:
            bad.append('ai_weights/%s 要有 E～SSS 八档（按序）' % k)
    if {k: list(v) for k, v in table.get('budgets', {}).items()} != {k: list(v) for k, v in SIX_BUDGETS.items()}:
        bad.append('budgets 要同设定稿 R4：%s' % SIX_BUDGETS)
    tpl = table.get('templates', {})
    if not 8 <= len(tpl) <= 10:
        bad.append('templates 要 8～10 个，现在 %d 个' % len(tpl))
    for k, v in tpl.items():
        bad += six_dim_row_rules('templates/%s' % k, v, v.get('class'))
    for k, v in table.get('knights', {}).items():
        bad += six_dim_row_rules('knights/%s' % k, v, v.get('class'))
        if v.get('class') != 'knight':
            bad.append('knights/%s class 要是 knight' % k)
    for k, v in table.get('actors', {}).items():
        bad += six_dim_row_rules('actors/%s' % k, v, v.get('class'))
        if v.get('class') not in ('weak', 'strong', 'super'):
            bad.append('actors/%s class 要是 weak／strong／super' % k)
        if base is not None and k not in base.get('actors', {}):
            bad.append('actors/%s 不在 base_line.json 的 actors 里' % k)
    for k, v in table.get('enemies', {}).items():
        if v.get('template') not in tpl:
            bad.append('enemies/%s 的 template %r 不在 templates 里' % (k, v.get('template')))
    if horsemen is not None:
        if sorted(table.get('knights', {})) != sorted(horsemen.get('knights', {})):
            bad.append('knights 的键要同 horsemen.json：%s' % sorted(horsemen.get('knights', {})))
    return bad


def six_dim_r4_report(table: dict) -> list:
    """R4 分档总分（只报告不拦，T280）：每档人数、总分最小／中位／最大／均值、超出预算的人数。"""
    groups = {}
    for part, key_cls in (('templates', None), ('knights', None), ('actors', None)):
        for k, v in table.get(part, {}).items():
            cls = v.get('class')
            if cls in SIX_BUDGETS and all(d in v and v[d] in SIX_LETTERS for d in SIX_DIMS):
                groups.setdefault(cls, []).append((part + '/' + k, sum(SIX_LETTERS.index(v[d]) + 1 for d in SIX_DIMS)))
    lines = []
    for cls in SIX_CLASSES:
        rows = groups.get(cls)
        if not rows:
            continue
        tot = sorted(x[1] for x in rows)
        lo, hi = SIX_BUDGETS[cls]
        out = [n for n, s in rows if not lo <= s <= hi]
        mid = tot[len(tot) // 2] if len(tot) % 2 else (tot[len(tot) // 2 - 1] + tot[len(tot) // 2]) // 2
        lines.append('R4 报告 %s：%d 份，总分 %d～%d（中位 %d，均值 %d），预算 %d～%d，超出预算 %d 份'
                     % (cls, len(rows), tot[0], tot[-1], mid, sum(tot) // len(tot), lo, hi, len(out)))
    return lines


def check_six_dim(_args) -> bool:
    ok = _run_table('six_dim.json', lambda t: six_dim_rules(t, _load_opt('base_line.json'), _load_opt('horsemen.json')))
    if (DATA_DIR / 'six_dim.json').is_file():
        try:
            for line in six_dim_r4_report(json.loads((DATA_DIR / 'six_dim.json').read_text(encoding='utf-8'))):
                print('  ' + line)
        except Exception as e:  # 报告读不出来不拦，只提示
            print('  R4 报告读不出来：%s: %s' % (type(e).__name__, e))
    return ok


# 每张表一个检查函数：(名字, 函数(args) -> 是否通过)。词条表那张单加 affix_table 时往这里登记。
CHECKS = [
    ('balance_table', lambda args: check_balance_table(args.params)),
    ('horsemen', lambda args: check_horsemen(args.params)),
    ('war_line', check_war_line),
    ('famine_line', lambda _args: check_line('famine')),
    ('plague_line', lambda _args: check_line('plague')),
    ('death_line', lambda _args: check_line('death')),
    ('summit', check_summit),
    ('seg_alien', check_seg_alien),
    ('gear_table', check_gear_table),
    ('affix_text', lambda args: check_affix_text(args.affix_text)),
    ('rewards', check_rewards),
    ('qiyin_gear', lambda _args: check_qiyin('gear')),
    ('qiyin_drop', lambda _args: check_qiyin('drop')),
    ('qiyin_dragon', lambda _args: check_qiyin('dragon')),
    ('qiyin_altar', lambda _args: check_qiyin('altar')),
    ('qiyin_refs', check_qiyin_refs),
    ('skill_rework', check_skill_rework),
    ('elements_table', check_elements_table),
    ('reforge', check_reforge),
    ('alien_gear', check_alien_gear),
    ('abyss_shelves', check_abyss_shelves),
    ('qiyin_equip', check_qiyin_equip),
    ('qiyin_show', check_qiyin_show),
    ('qiyin_dragon_run', check_qiyin_dragon_run),
    ('base_line', check_base_line),
    ('gear_base', check_gear_base),
    ('ledger_phase4', check_ledger_phase4),
    ('combat_rules_phase4', check_combat_rules_phase4),
    ('single_hit_cap', check_single_hit_cap),
    ('abs_rescale', check_abs_rescale),
    ('brand', check_brand),
    ('guardian_params', check_guardian_params),
    ('growth', check_growth),
    ('six_dim', check_six_dim),
]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description='天启篇数据表校验')
    ap.add_argument('--params', help='设计仓库的 重制设定/数值测算/参数.json；不给就跳过和参数的对照')
    ap.add_argument('--affix-text', help='换一份 affix_text.json 检查（反向验证用）；不给就查工程里那份')
    args = ap.parse_args(argv)
    ok = True
    for name, fn in CHECKS:
        ok = fn(args) and ok
    print('天启篇数据校验：' + ('全部通过' if ok else '有不通过'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
