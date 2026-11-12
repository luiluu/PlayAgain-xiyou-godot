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
- war_line.json、famine_line.json（各线关卡流程与异化，XTianqiLine）：只有 B 组，数字避开 4（层号、地图号、敌群号、坐标豁免）、预设和台词齐全、开场步骤用到的台词／地图／坐标／预设都在表里。
- summit.json（31～36 层重做）：只有 B 组，数字避开 4（层号、地图号、敌群号、坐标等豁免）、34～36 层齐全、台词齐全。
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


# 每张表一个检查函数：(名字, 函数(args) -> 是否通过)。词条表那张单加 affix_table 时往这里登记。
CHECKS = [
    ('balance_table', lambda args: check_balance_table(args.params)),
    ('horsemen', lambda args: check_horsemen(args.params)),
    ('war_line', check_war_line),
    ('famine_line', lambda _args: check_line('famine')),
    ('summit', check_summit),
    ('gear_table', check_gear_table),
]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description='天启篇数据表校验')
    ap.add_argument('--params', help='设计仓库的 重制设定/数值测算/参数.json；不给就跳过和参数的对照')
    args = ap.parse_args(argv)
    ok = True
    for name, fn in CHECKS:
        ok = fn(args) and ok
    print('天启篇数据校验：' + ('全部通过' if ok else '有不通过'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
