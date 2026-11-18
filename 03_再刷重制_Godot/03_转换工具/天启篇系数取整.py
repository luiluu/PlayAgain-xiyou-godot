#!/usr/bin/env python3
"""T191（D200 A，Kyo 11-18）：天启篇技能卡剩下的小数系数全表取整，写进 skill_rework.json 的 tune.D200 覆盖层。

口径（项目经理cc 11-18 回复，按 A）：
- 每个属性项的有效系数 e＝coef×权重×无条件 always 倍率（不带 need_skill 的 always，比如「第六期复核段数」×0.8）；
  带 need_skill 的 always（学会某招后 ×1/3 这类拿段数换的）和各种条件加成不算系数，不动。
- 攻击类属性（物攻、魔攻、双防、敏捷、幸运、取高）：e≥1 就近取整、.5 进位（不再避开 4，D205）；e<1 写整数百分比（0.45→45%）。
- 生命上限、魔法上限：整数百分比（同 T175 生命上限×1% 写法），.5 进位，最少 1%。
- 写法：只有一个属性项（或 max_of）时 coef 放取整后的数、权重 1（生命、魔法写 0.01，coef 是百分数）；
  好几个属性项时 coef 1、各权重写取整后的数。无条件 always 并进系数后从 conds 里去掉。
- 已经在 tune.D189 里改过的技能按覆盖后的值算，已是整数的不进 D200。
- 卡面 desc：伤害行里的「×旧数」「旧数%」「合计旧数」按映射换；换不干净的留给 MANUAL 手写。

用法：python3 天启篇系数取整.py [--write] [--report 路径.md]
不带 --write 只打印统计。可重跑：每次从原卡（＋D189）重新算，整段覆盖 tune.D200。
"""
import copy
import json
import re
import sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

P = Path(__file__).resolve().parent.parent / '01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json'
sys.path.insert(0, str(Path(__file__).resolve().parent))
import importlib.util

_spec = importlib.util.spec_from_file_location('tq_check', Path(__file__).resolve().parent / '天启篇数据校验.py')
tq_check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tq_check)

PCT_STATS = ('mhp', 'mmp')
STAT_NAMES = {'atk': ('物理攻击', '物攻'), 'mat': ('魔法攻击', '魔攻'), 'def': ('物理防御', '物防', '防御'),
              'mdf': ('魔法防御', '魔防'), 'agi': ('敏捷',), 'luk': ('幸运',),
              'mhp': ('生命上限', '最大生命'), 'mmp': ('魔法上限', '最大魔法')}

# 手写的卡面（自动换不干净的）：技能号 -> 新 desc 整份
MANUAL = {
    '86': ['效果：当敌人生命值低于25%时造成双倍伤害', '伤害：物理攻击×4（斩杀时×8）'],
    '189': ['伤害：每个敌人每段 物理攻击、敏捷、幸运各×7%（三段）'],
    '190': ['伤害：每个敌人每段 物理攻击、敏捷、幸运各×13%（三段）'],
    '195': ['效果：随机两个敌人，各三段', '伤害：每个敌人每段 物理攻击、敏捷各×30%（三段）'],
    '401': ['效果：三段（随被动解锁增至五段，总伤害不变），回复 30 TP；附加恶拳', '伤害：合计 物理攻击×3'],
    '402': ['效果：六段（随被动解锁增至九段，总伤害不变）；附加恶拳', '伤害：合计 物理攻击×6'],
    '5421': ['效果：随机三个敌人，各四段', '伤害：每个目标每段 物理攻击×90%（四段）；带恶拳 +30%，带怒拳再 +30%'],
    '1200': ['效果：学了除魔天地间后连放三剑', '伤害：物理攻击×2，第二剑×3，第三剑×3（合计8）'],
    '1226': ['效果：速斩（敏捷高于目标时攻击3次，否则2次）', '伤害：两段 物理攻击×2；三段时每段伤害 −20%'],
    '2121': ['效果：速斩（敏捷高于目标时攻击3次，否则2次）；积攒幽光', '伤害：两段 物理攻击×2；三段时每段伤害 −20%'],
    '10216': ['伤害：物理攻击×2（分五段）'],
    '2613': ['效果：有凝神时打三段并消耗凝神', '伤害：物理攻击×3（凝神时三段，合计×5）'],
}
for _k in ('5706', '5708', '5709'):
    MANUAL[_k] = ['效果：耗光魔法，按耗掉的魔法比例出伤（最多按 90% 算）', '伤害：(魔法攻击×6＋魔法上限×24%)×耗掉的魔法比例']
# 同名再释放：卡面和本体一样
MANUAL['1804'] = ['伤害：合计 物理攻击×3']
MANUAL['1805'] = ['伤害：合计 物理攻击×6']
# 心法邪练（+30%）的变体：卡面直接写含 30% 的数
for _k in ('4808', '4809', '4810'):
    MANUAL[_k] = None  # 下面按原卡第一行拼
MANUAL_LINES = {
    '3636': '伤害：魔法攻击×2',
    '3646': '伤害：每段 物理攻击、敏捷各×60%（三段）',
    '4813': '伤害：每段 物理攻击、敏捷各×78%（三段，已含心法 +30%）',
    '4808': '伤害：物理攻击×2＋双防各×1（已含心法 +30%）；滑稽值每点 +1%，最多 +20%',
    '4809': '伤害：物理攻击×2＋双防各×1（已含心法 +30%）',
    '4810': '伤害：物理攻击×2＋双防各×1（已含心法 +30%）',
    '4811': '伤害：物理攻击、敏捷各×2（已含心法 +30%）；滑稽值每点 +1%，最多 +20%',
    '4812': '伤害：每次 物理攻击、敏捷各×2（已含心法 +30%）',
    '188': '伤害：每个敌人 物理攻击、敏捷、幸运各×40%',
    '3589': '伤害：每段 物理攻击×2，浮动67%（六段）',
    '1212': '伤害：每段 魔法攻击×5，浮动25%',
    '1348': '伤害：每段 物理攻击×28%（已按半伤算）',
    '10148': '伤害：物理攻击×4＋物防×72%',
    '10149': '伤害：每个敌人 魔法攻击×2＋魔防×36%',
    '10150': '伤害：每个敌人 物理攻击×4＋物防×72%',
    '10151': '伤害：每个敌人 物理攻击、魔法攻击各×5（已含准备 +50%）',
    '1216': '伤害：魔法攻击×4，第二下×0～8（浮动100%）',
}
for _k in ('4808', '4809', '4810'):
    del MANUAL[_k]



def half_up(x: float) -> int:
    return int(Decimal(repr(x)).quantize(Decimal('1'), rounding=ROUND_HALF_UP))


def is_plain_always(c: dict) -> bool:
    return c.get('if') == 'always' and not any(k not in ('if', 'mult', '_fix', '_note') for k in c)


def int_like(v, scale=1):
    return abs(v * scale - round(v * scale)) < 1e-6


def round_term(st: str, e: float):
    """返回 (新有效系数, 显示文字)。离整数不到 0.015 的（三分之一写成 0.33 带出来的 0.99、2.01）算整数。"""
    if st not in PCT_STATS and e > 0.5 and abs(e - round(e)) < 0.015:
        e = float(round(e))
    if st in PCT_STATS:
        p = max(1, half_up(e * 100))
        return p / 100, '%d%%' % p
    if e >= 1 - 1e-9:
        n = half_up(e)
        return float(n), str(n)
    p = max(1, half_up(e * 100))
    return p / 100, '%d%%' % p


def num(x: float) -> str:
    return tq_check.num_text(round(x, 6))


def needs_work(dm: dict) -> bool:
    m = dm.get('coef', 0)
    for c in dm.get('conds', []):
        if is_plain_always(c):
            return True
    stats = dm.get('stats', {'atk': 1}) if 'stats' in dm else {'atk': 1}
    for st, w in stats.items():
        e = m * w
        if not (int_like(e, 100) if st in PCT_STATS else (e >= 1 and int_like(e))):
            return True  # 攻击类小于 1 的卡面要改写成百分比，也进
    if dm.get('max_of') and not (m >= 1 and int_like(m)):
        return True
    return False


def transform(dm: dict):
    """返回 (新 damage, 项列表[(属性, 旧 e, 新 e, 显示)])。"""
    plain = 1.0
    keep = []
    for c in dm.get('conds', []):
        if is_plain_always(c):
            plain *= float(c['mult'])
        else:
            keep.append(c)
    coef = float(dm.get('coef', 0)) * plain
    stats = dict(dm.get('stats', {'atk': 1})) if 'stats' in dm else {'atk': 1}
    terms = []
    new = {k: v for k, v in dm.items() if k not in ('stats', 'coef', 'conds')}
    if keep or 'conds' in dm:
        new['conds'] = keep
    # 三分之一、三分之二写成 0.33／0.67／0.3333 的，按准数算
    items = [(st, (round(w * 3) / 3 if st not in PCT_STATS and abs(w * 3 - round(w * 3)) < 0.02 else w)) for st, w in stats.items()]
    if dm.get('max_of'):
        items.append(('max_of', 1.0))
    if len(items) == 1:
        st, w = items[0]
        e = coef * w
        ne, shown = round_term(st, e)
        terms.append((st, e, ne, shown))
        if st == 'max_of':
            new['stats'] = {}
            new['coef'] = ne
        elif st in PCT_STATS:
            new['stats'] = {st: 0.01}
            new['coef'] = int(round(ne * 100))
        else:
            new['stats'] = {st: 1}
            new['coef'] = int(ne) if ne >= 1 else ne
    else:
        # 多项：coef 1，各权重写取整后的数；max_of 那项照公式只能乘 coef，没有这种行（核过：max_of 行 stats 都是空的）
        assert not dm.get('max_of'), dm
        ns = {}
        for st, w in items:
            e = coef * w
            ne, shown = round_term(st, e)
            terms.append((st, e, ne, shown))
            ns[st] = int(ne) if (ne >= 1 and st not in PCT_STATS) else ne
        new['stats'] = ns
        new['coef'] = 1
    return new, terms


NUM = r'(\d+(?:\.\d+)?)'


def close(a: float, b: float) -> bool:
    return abs(a - b) <= max(0.006, abs(b) * 0.003)


def rewrite_desc(desc: list, terms: list, old_dm: dict, MANUAL_LINE=None):
    """换伤害行里的数。返回 (新 desc, 还剩小数的行)。"""
    out = []
    left = []
    olds = [(e, ne, shown, st) for st, e, ne, shown in terms]

    def sub_one(line):
        # 随机区间的合计括号（合计约 a～b）由「浮动」说明代替，去掉；留下其中的「N段」
        line = re.sub(r'[（(][^（）()]*～[^（）()]*[）)]', lambda mo: (lambda s: '（%s）' % s.group(0) if s else '')(re.search(r'[一二三四五六七八九十\d]+段', mo.group(0))) if ('合计' in mo.group(0) or '约' in mo.group(0)) else mo.group(0), line)
        # 「合计X」「相当于X」：X≈旧 e×n（n 段）→ 新 e×n
        def total(mo):
            x = float(mo.group(2))
            for e, ne, shown, st in olds:
                if e <= 0:
                    continue
                n = x / e
                if abs(n - round(n)) < 0.02 and round(n) >= 1:
                    t = ne * round(n)
                    if st in PCT_STATS:
                        return mo.group(1) + '%s' % num(t * 100)
                    return mo.group(1) + (num(t) if t >= 1 else '%s%%' % num(t * 100))
            return mo.group(0)
        line = re.sub(r'(合计约?|相当于)' + NUM, total, line)

        # 「×X」「X%」：X≈某项旧值
        def times(mo):
            x = float(mo.group(1))
            for e, ne, shown, st in olds:
                if st not in PCT_STATS and close(x, e):
                    return '×' + shown
            return mo.group(0)
        line = re.sub(r'×' + NUM + r'(?![\d%])', times, line)

        # 单项、卡面写的是几段合计（×X，X≈旧 e×n）：换成新 e×n
        if len(olds) == 1 and olds[0][3] not in PCT_STATS:
            e, ne, shown, st = olds[0]

            def times_n(mo):
                x = float(mo.group(1))
                n = x / e if e else 0
                if not close(x, e) and 2 <= round(n) <= 12 and abs(n - round(n)) < 0.01:
                    t = ne * round(n)
                    if t >= 1 and abs(t - round(t)) < 0.05:
                        t = float(round(t))  # 67%×3＝2.01 写 2
                    return '×' + (num(t) if t >= 1 and int_like(t) else '%s%%' % num(t * 100))
                return mo.group(0)
            line = re.sub(r'×' + NUM + r'(?![\d%])', times_n, line)

        def pct(mo):
            x = float(mo.group(1)) / 100
            for e, ne, shown, st in olds:
                if st in PCT_STATS and close(x, e):
                    return shown
            return mo.group(0)
        line = re.sub(NUM + r'%', pct, line)
        return line

    for line in desc:
        if line.startswith('伤害') and MANUAL_LINE is not None:
            out.append(MANUAL_LINE)
            continue
        if line.startswith('伤害'):
            nl = sub_one(line)
            if DECIMAL.search(nl):
                nl = regen(line, terms, old_dm) or nl
            nl = re.sub(r'(?<![\d.])(\d+)\.0(?![\d%])', r'\1', nl)
            out.append(nl)
            if DECIMAL.search(nl):
                left.append(nl)
        else:
            out.append(line)
    return out, left


DECIMAL = re.compile(r'\d\.\d')
STAT_WORDS = sorted({w for v in STAT_NAMES.values() for w in v} | {'双防', '全属性', '最大生命', '最大魔法'}, key=len, reverse=True)
_STAT_RE = '|'.join(map(re.escape, STAT_WORDS))
# 公式段：从第一个属性名（或紧跟属性名的左括号）起，到公式字符断开为止
FORMULA = re.compile(r'[（(]?(?:%s)(?:%s|[×＋+、各平均取高合计（）()～÷\d.%%\s]|随机)*' % (_STAT_RE, _STAT_RE))
TAIL_PAREN = re.compile(r'[（(][^（）()]*(?:合计|平均|约|相当于|各占)[^（）()]*\d[^（）()]*[）)]')


def term_text(terms, old_dm):
    if len(terms) == 1 and terms[0][0] == 'max_of':
        names = [STAT_NAMES[k][0] for k in old_dm.get('max_of', [])]
        return '%s取高×%s' % ('、'.join(names), terms[0][3])
    shown = [t[3] for t in terms]
    names = [STAT_NAMES[t[0]][0] for t in terms]
    if len(terms) > 1 and len(set(shown)) == 1:
        if len(terms) == 8:
            return '全属性各×%s' % shown[0]
        return '%s各×%s' % ('、'.join(names), shown[0])
    return '＋'.join('%s×%s' % (n, s) for n, s in zip(names, shown))


def regen(line, terms, old_dm):
    """自动换不干净时：整段公式按取整后的项重写，带小数的合计／平均／约括号去掉；随机区间改成「浮动」写法交给 desc 里已有的浮动说明。"""
    if '合计' in line.split('：', 1)[1][:6] or '取高' in line and terms[0][0] != 'max_of':
        return None
    # 卡面上的数要能对上数据（每项旧有效系数，或单项时旧系数×整数段数）；对不上的不自动重写，留给手写
    nums = [float(x) for x in re.findall(r'\d+(?:\.\d+)?', line)]
    plain = float(old_dm.get('coef', 0))
    for c in old_dm.get('conds', []):
        if is_plain_always(c):
            plain *= float(c['mult'])
    each = all(st in PCT_STATS or any(close(x, e) for x in nums) for st, e, _, _ in terms)
    if not each and not (len(terms) > 1 and any(close(x, plain) for x in nums)):
        return None
    m = FORMULA.search(line)
    if not m:
        return None
    seg = m.group(0).rstrip()
    while seg and seg[-1] in '（(':
        seg = seg[:-1]
    # 公式段末尾的「（合计…）」括号不算公式
    seg = re.split(r'[（(](?=合计|平均|约)', seg)[0]
    tp = TAIL_PAREN.search(seg)
    if tp:
        seg = seg[:tp.start()]
    rest = line[m.start() + len(seg):]
    def keep_seg(mo):
        s = re.search(r'[一二三四五六七八九十\d]+段', mo.group(0))
        return '（%s）' % s.group(0) if s else ''
    rest = TAIL_PAREN.sub(keep_seg, rest)
    rest = re.sub(r'，?(?:约)?\d+(?:\.\d+)?～\d+(?:\.\d+)?', '', rest) if DECIMAL.search(rest) else rest
    head = line[:m.start()]
    return head + term_text(terms, old_dm) + rest


def build(table: dict):
    merged = tq_check.apply_skill_tune({k: v for k, v in table.items() if k != 'tune'} | {'tune': {'D189': table.get('tune', {}).get('D189', {})}})
    d200 = {}
    rows = []
    for sid, row in merged['skills'].items():
        dm = row.get('damage')
        if not str(sid).isdigit() or not isinstance(dm, dict):
            continue
        if not needs_work(dm):
            # 系数已是整数、卡面写成 6.0 这类：只换卡面
            if not any(str(x).startswith('伤害') and DECIMAL.search(str(x)) for x in row.get('desc', [])):
                continue
            _, terms = transform(dm)
            if sid in MANUAL:
                desc, left = MANUAL[sid], []
            else:
                desc, left = rewrite_desc(row.get('desc', []), terms, dm, MANUAL_LINES.get(sid))
            if desc == row.get('desc', []):
                continue
            d200[sid] = {'_note': 'T191 只换卡面（系数原来就是整数）', 'desc': desc}
            rows.append((sid, row.get('actor', ''), row.get('name', ''), [], row.get('desc', []), desc, left))
            continue
        new, terms = transform(dm)
        if sid in MANUAL:
            desc, left = MANUAL[sid], []
        else:
            desc, left = rewrite_desc(row.get('desc', []), terms, dm, MANUAL_LINES.get(sid))
        before = '；'.join('%s %s' % (st, num(e)) for st, e, _, _ in terms)
        after = '；'.join('%s %s' % (st, shown) for st, _, _, shown in terms)
        entry = {'_note': 'T191 取整：%s → %s' % (before, after), 'damage': new}
        if desc != row.get('desc', []):
            entry['desc'] = desc
        d200[sid] = entry
        rows.append((sid, row.get('actor', ''), row.get('name', ''), terms, row.get('desc', []), desc, left))
    return d200, rows


def main(argv):
    table = json.loads(P.read_text(encoding='utf-8'))
    d200, rows = build(table)
    left = [r for r in rows if r[6]]
    big = [r for r in rows if any(st not in PCT_STATS and e >= 1 and abs(ne / e - 1) > 0.2 for st, e, ne, _ in r[3])]
    print('D200 共 %d 条；卡面还剩小数 %d 条；≥1 取整变化超过 ±20%% 的 %d 条' % (len(d200), len(left), len(big)))
    if '--left' in argv:
        for r in left:
            print(r[0], r[2], r[6])
    if '--write' in argv:
        note = ('T191（D200 A，Kyo 11-18）：原卡剩下的小数系数全表取整（≥1 就近取整、.5 进位；<1 和生命、魔法写整数百分比；'
                '无条件 always 并进系数）。XTianqiBase.TUNE_D200 开着时叠在 D189 之后；关掉后 XTianqiSkills.reload() 照取整前。'
                '生成：03_转换工具/天启篇系数取整.py；改前改后见交付单 T191 附录。')
        dump = lambda v: json.dumps(v, ensure_ascii=False)
        body = ',\n'.join('   %s: %s' % (dump(k), dump(v)) for k, v in d200.items())
        block = ' }, "D200": {\n  "_note": %s,\n  "skills": {\n%s\n  }\n }}\n}\n' % (dump(note), body)
        text = P.read_text(encoding='utf-8')
        cut = text.find(' }, "D200": {')
        if cut < 0:
            assert text.endswith('\n }}\n}\n'), '表尾格式变了，先看一眼'
            cut = len(text) - len(' }}\n}\n')
        text = text[:cut] + block
        json.loads(text)
        P.write_text(text, encoding='utf-8')
        print('已写', P)
    if '--report' in argv:
        rp = Path(argv[argv.index('--report') + 1])
        lines = ['| 技能 | 角色 | 名字 | 改前 | 改后 | 变化 |', '|---|---|---|---|---|---|']
        for sid, actor, name, terms, _, _, _ in sorted(rows, key=lambda r: (int(r[1] or 0), int(r[0]))):
            ch = []
            for st, e, ne, _ in terms:
                ch.append('%+d%%' % round((ne / e - 1) * 100) if e else '—')
            lines.append('| %s | %s | %s | %s | %s | %s |' % (
                sid, actor, name,
                '；'.join('%s×%s' % (st, num(e * 100) + '%' if st in PCT_STATS else num(e)) for st, e, _, _ in terms),
                '；'.join('%s×%s' % (st, shown) for st, _, _, shown in terms), '；'.join(ch)))
        rp.write_text('\n'.join(lines) + '\n', encoding='utf-8')
        print('报告', rp)


if __name__ == '__main__':
    main(sys.argv[1:])
