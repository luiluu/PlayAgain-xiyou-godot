#!/usr/bin/env python3
"""天启篇数据表校验（只用标准库，云端没有 Godot 和转换产物也能跑）。

  python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py [--params <设计仓库>/重制设定/数值测算/参数.json]

每张表一个检查函数，登记在 CHECKS 里；表文件不在就跳过那一张（打印「跳过」）。
- affix_text.json（词条的玩家文字）：和 tests/xiyou_tianqi_affix_text 同一套；数值从 affix_table.json 取，
  查表算法借 天启篇词条表校验.py 的 AffixTable。
- balance_table.json（档位与五档难度）：
  A 组：和设计仓库的测算 参数.json 逐项对照。不给 --params 时跳过（游戏仓库公开，检查.sh 里没有设计仓库）。
  B 组：规则自检，和 tests/xiyou_tianqi_balance 同一套（难度键与 core/tianqi.gd 的 DIFFICULTIES 用正则对照）。
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
            row[k] = int(re.search(r'"%s":\s*(-?\d+)' % k, line).group(1))
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
            check('%s 同开局：%s' % (k, x['key']), r.get(k) == x[k], '表 %s，tianqi.gd %s' % (r.get(k), x[k]))
        pool_want = [WEAK, STRONG] + ([SUPER] if x['super_cap'] > 0 else [])
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
        ('终伤四阶上品', x.line('final_damage', 4, 'fine'), '上品·终伤 +12%'),
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
    raw = json.dumps(text, ensure_ascii=False)
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


# 每张表一个检查函数：(名字, 函数(args) -> 是否通过)。词条表那张单加 affix_table 时往这里登记。
CHECKS = [
    ('balance_table', lambda args: check_balance_table(args.params)),
    ('affix_text', lambda args: check_affix_text(args.affix_text)),
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
