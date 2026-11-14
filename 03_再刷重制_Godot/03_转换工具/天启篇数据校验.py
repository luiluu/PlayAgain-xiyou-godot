#!/usr/bin/env python3
"""天启篇数据表校验（只用标准库，云端没有 Godot 和转换产物也能跑）。

  python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py [--params <设计仓库>/重制设定/数值测算/参数.json]

每张表一个检查函数，登记在 CHECKS 里；表文件不在就跳过那一张（打印「跳过」）。
- balance_table.json（档位与五档难度）：
  A 组：和设计仓库的测算 参数.json 逐项对照。不给 --params 时跳过（游戏仓库公开，检查.sh 里没有设计仓库）。
  B 组：规则自检，和 tests/xiyou_tianqi_balance 同一套（难度键与 core/tianqi.gd 的 DIFFICULTIES 用正则对照）。
- horsemen.json（天启四骑士）：
  A 组：和 参数.json「骑士」一节逐项对照（生命、攻防、行动、系数、计量、终焉、骑士血量倍率）；不给 --params 时跳过。
  B 组：规则自检（数字避开 4，豁免键另列；五档骑士血量倍率齐全）。
- war_line.json、famine_line.json、plague_line.json、death_line.json（各线关卡流程与异化，XTianqiLine）：只有 B 组，数字避开 4（层号、地图号、敌群号、坐标豁免）、预设和台词齐全、开场步骤用到的台词／地图／坐标／预设都在表里。
- summit.json（31～36 层重做）：只有 B 组，数字避开 4（层号、地图号、敌群号、坐标等豁免）、34～36 层齐全、台词齐全。
- seg_alien.json（按段异化，四线共用）：只有 B 组，数字避开 4、1～36 层段表连续不重叠、级名和难度键齐全、几率在 0～100。
- qiyin_gear.json、qiyin_drop.json、qiyin_dragon.json、qiyin_altar.json（七印祭坛）：只有 B 组，数字避开 4（各表 nice_number_exempt 豁免）、印键只有七个、部位键只有六个、几率在 0～1、权重非负且不全为 0；qiyin_gear 另查类型号在 core/tianqi_gear.gd 的 ORDER 里、七套各 6 件、毕业武器 13 把、神器 5 件；跨表查另三张引用的套装、武器、神器、印、部位都在 qiyin_gear 里。只查表里现有的字段，不认识的键不报错。
- skill_rework.json（全角色技能重构）：只有 B 组，数字避开 4（nice_number_exempt 豁免）、超强者 17（含五条悟）／强者 52 不重叠、技能行系数大于 0、治疗比例与追加几率在 0～1。
- reforge.json、alien_gear.json、abyss_shelves.json、qiyin_equip.json、qiyin_show.json、qiyin_dragon_run.json（重铸、异化装备、深渊商人货架、七印装备底子、七印演出、七首之龙流程）：只有 B 组，只查代码读的字段，数字避开 4（各表 nice_number_exempt 豁免）、类型和范围（几率 0～1、百分比 0～100、花费非负、随阶／随级不降、颜色 #RRGGBB、能力值 8 项）；跨表查货架的层和阶在 affix_table、品质在 tianqi_affix_roll.gd 的 QUALITY_KEYS、异化词条在 rewards.json 的 finale.lines、七印装备的部位和武器类型与 qiyin_gear 对得上、演出的印齐七个；参照表不在就跳过那一项。
有不一致就逐条打印「项、游戏数据、参数.json」，退出码 1；全过退出码 0。
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
ROSTER_KEYS = {'pool': '候选池', 'super_cap': '超强者上限', 'min_weak': '至少弱者'}
TIER_KEYS = {'damage_dealt': '出伤', 'damage_taken': '承伤', 'secret_cap': '秘籍上限'}
NICE_EXEMPT_ALLOWED = {'version', 'secret_cap', 'super_cap', 'min_weak'}


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


def nice_violations(v, path, exempt, out):
    if isinstance(v, dict):
        for k, x in v.items():
            if k not in exempt:
                nice_violations(x, path + '/' + k, exempt, out)
    elif isinstance(v, list):
        for i, x in enumerate(v):
            nice_violations(x, '%s/%d' % (path, i), exempt, out)
    elif isinstance(v, (int, float)) and not isinstance(v, bool):
        s = num_text(v)
        if '4' in s:
            out.append('%s=%s' % (path, s))


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
    # 6. 数值好看
    exempt = table.get('nice_number_exempt', [])
    check('豁免键只放个数类', set(exempt) <= NICE_EXEMPT_ALLOWED, exempt)
    out = []
    nice_violations(table, '', set(exempt), out)
    check('设计数值不含 4', not out, '，'.join(out))
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
    out = []
    nice_violations(table, '', set(table.get('nice_number_exempt', [])), out)
    if out:
        bad.append('数字带 4：' + '，'.join(out))
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
    out = []
    nice_violations(table, '', set(table.get('nice_number_exempt', [])), out)
    if out:
        bad.append('数字带 4：' + '，'.join(out))
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
    out = []
    nice_violations(table, '', set(table.get('nice_number_exempt', [])), out)
    if out:
        bad.append('数字带 4：' + '，'.join(out))
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
    out = []
    nice_violations(table, '', set(table.get('nice_number_exempt', [])), out)
    if out:
        bad.append('数字带 4：' + '，'.join(out))
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
    fours = []
    nice_violations(table, '', {'version'}, fours)
    check('设计数值不带 4', not fours, '、'.join(fours))
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
    bad_fill, too_long, digit4, minus = [], [], [], []
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
                        if '4' in s:
                            digit4.append('%s：%s' % (tag, s))
                        if re.search(r'-\d', s):
                            minus.append('%s：%s' % (tag, s))
                    if han_count(bd) > AFFIX_LINE_MAX_HAN:
                        too_long.append('%s（%d 字）：%s' % (tag, han_count(bd), bd))
        for tier in range(1, 5):
            if t.value(k, tier, 'normal') is None:
                check('不能出的阶返回空：%s/%d' % (k, tier), x.line(k, tier, 'normal') == '' and x.detail(k, tier, 'normal') == '')
    check('模板都填得上（不剩花括号、没有 null／nan）', not bad_fill, '；'.join(bad_fill[:5]))
    check('填好的文字不含数字 4', not digit4, '；'.join(digit4[:5]))
    check('负号用全角「−」', not minus, '；'.join(minus[:5]))
    check('词条行不超过 %d 个汉字' % AFFIX_LINE_MAX_HAN, not too_long, '；'.join(too_long[:5]))
    # 3. 抽查（设计稿 v0.3 与 Kyo 11-11 01:21 整数版）
    spot = [
        ('物攻四阶极', x.line('atk', 4, 'perfect'), '极·物攻 +8%'),
        ('终伤四阶上品', x.line('final_damage', 4, 'fine'), '上品·伤害加成 +12%'),
        ('再动四阶极', x.line('reaction', 4, 'perfect'), '极·〔稀有〕每回合有 20% 几率多行动一次'),
        ('全能光环四阶极', x.line('aura_versatile', 4, 'perfect'), '极·全队·八项属性 +6%'),
        ('连击', x.line('combo', 4, 'perfect'), '〔稀有〕攻击次数 +1'),
        ('暴怒四阶普通', x.line('aura_fury', 4, 'normal'), '全队·暴击率 +3%，爆伤 +6%'),
        ('火焰增伤四阶极', x.line('element_damage', 4, 'perfect', {'element': 'fire'}), '极·火焰伤害 +22%'),
        ('避敌四阶普通', x.line('target_rate', 4, 'normal', {'variant': 'avoid'}), '避敌：被选为目标的几率 −10%'),
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
    # 4. 文字表本身不含数字 4
    raw = json.dumps({k: v for k, v in text.items() if k != 'dev'}, ensure_ascii=False)  # dev 是合并时盖的开发编号，不是设计数
    check('文字表本身不含数字 4', '4' not in raw, re.findall(r'.{0,8}4.{0,8}', raw)[:3])
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
    fours = []
    nice_violations(table, '', set(table.get('nice_number_exempt', [])), fours)
    check('设计数值不带 4', not fours, '、'.join(fours))
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
    """四张表共用：数字避开 4（表自己的 nice_number_exempt 豁免）、几率在 0～1、权重非负且不全为 0。"""
    bad = []
    fours = []
    nice_violations({k: v for k, v in table.items() if k not in ('_note', 'dev')}, '',
                    set(table.get('nice_number_exempt', [])), fours)
    if fours:
        bad.append('设计数值不带 4：' + '、'.join(fours))
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

SKILL_EXEMPT_EXTRA = {'effects_remove', 'rate_with'}


def skill_rework_rules(table: dict) -> list:
    """数字避开 4（豁免键另列）、档位名单人数和不重叠、技能行的系数／比例／几率范围。"""
    bad = []
    exempt = set(table.get('nice_number_exempt', [])) | SKILL_EXEMPT_EXTRA
    for sec in ('rules', 'skills', 'states', 'actors'):
        nice_violations(table.get(sec, {}), sec, exempt, bad)
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
    return bad


def check_skill_rework(_args) -> bool:
    path = DATA_DIR / 'skill_rework.json'
    if not path.is_file():
        print('跳过：没有 skill_rework.json')
        return True
    try:
        bad = skill_rework_rules(json.loads(path.read_text(encoding='utf-8')))
    except Exception as e:
        bad = ['能读表并跑完全部检查：%s: %s' % (type(e).__name__, e)]
    return _report('skill_rework.json', '规则自检', bad)


def elements_table_rules(table: dict) -> list:
    bad = []
    exempt = set(table.get('nice_number_exempt', []))
    nice_violations(table, 'elements_table', exempt, bad)
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


def _fours(table: dict, extra=()) -> list:
    """数字避开 4：表自己的 nice_number_exempt 豁免（加上 extra）；_note、dev 不查。"""
    out = []
    nice_violations({k: v for k, v in table.items() if k not in ('_note', 'dev')}, '',
                    set(table.get('nice_number_exempt', [])) | set(extra), out)
    return ['设计数值不带 4：' + '、'.join(out)] if out else []


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
    bad += _fours(table)
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
    bad += _fours(table)
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
    bad += _fours(table)
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
    bad += _fours(table)
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
    bad += _fours(table)
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
    bad += _fours(table)
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
