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



# T191 R1（小A 核查 P2-1）：心法邪练的英勇打击，系数里已含 +30%
MANUAL_LINES['4814'] = '伤害：物理攻击×4（已含心法 +30%）；滑稽值每点 +1%，最多 +20%'
MANUAL_LINES['4815'] = '伤害：每次 物理攻击×4（已含心法 +30%）'
MANUAL_LINES['4816'] = '伤害：物理攻击×1（已含心法 +30%）'

# T191 R1（小A 核查 P2-2、P3-1）：非「伤害：」行（效果行）里引用的系数、条件倍率，以及几处卡面润色。
# 技能号 -> {旧整行: 新整行}；旧行对不上就报错（防止原卡改了这里还按旧的换）。
LINE_FIX = {
    '543': {'效果：在场的刘备、关羽、张飞各出一击（每人 物理攻击×3.0，三人齐出合计 ×9.0）': '效果：在场的刘备、关羽、张飞各出一击（每人 物理攻击×3，三人齐出合计 ×9）'},
    '4524': {'效果：关羽释放青龙乱舞后追加一次超强版（3.0），每回合1次': '效果：关羽释放青龙乱舞后追加一次超强版（五段，每段 物理攻击×60%），每回合1次'},
    '1798': {'效果：青龙乱舞后30%追加一次（3.6），每回合1次': '效果：青龙乱舞后30%追加一次（五段，每段 物理攻击×72%），每回合1次'},
    '5134': {'效果：放技能后追加兽魂之力（自然伤害1.0，随机：双防 −10%、受治疗 −30%、双攻 −10%、敏捷 −10%，2回合）': '效果：放技能后追加兽魂之力（自然伤害 魔法攻击×1，随机：双防 −10%、受治疗 −30%、双攻 −10%、敏捷 −10%，2回合）'},
    '5139': {'效果：兽魂之力后30%追加苍龙之力（3.0）': '效果：兽魂之力后30%追加苍龙之力（四段，合计 魔法攻击×3）'},
    '692': {'效果：佛陀真身（暴击率 +15%，普通攻击变为如来神掌（3.0），持续3回合）': '效果：佛陀真身（暴击率 +15%，普通攻击变为如来神掌（魔法攻击×3），持续3回合）'},
    '10646': {'效果：黑闪后觉醒3回合：直接术式伤害×1.2，黑闪概率 +15%': '效果：黑闪后觉醒3回合：直接术式伤害 +20%，黑闪概率 +15%'},
    '4723': {'效果：万剑归一有10%概率变成万剑归一*破魂（系数×1.5）': '效果：万剑归一有10%概率变成万剑归一*破魂（两段 物理攻击×8，原招三段×4）'},
    '4900': {'效果：领悟如来神脚（全体3.0，一半吃魔法上限，不随塔层数涨）': '效果：领悟如来神脚（全体两段，每段 魔法攻击×75%＋魔法上限×3%，不随塔层数涨）'},
    '4902': {'效果：真爱霸气变为无悔霸气：不再随机，固定全体3.6': '效果：真爱霸气变为无悔霸气：不再随机，固定全体 物理攻击×4'},
    '6915': {'效果：「六式-岚脚」替换为「六式-指枪」（单体 物理攻击×5.0），不再随机变招': '效果：「六式-岚脚」替换为「六式-指枪」（单体 物理攻击×6），不再随机变招'},
    '6916': {'效果：六式-岚脚换成六式-铁块，放完接正直拳骨（全体1.5）': '效果：六式-岚脚换成六式-铁块，放完接正直拳骨（全体两段，每段 物理攻击×75%）'},
    '5423': {'效果：战神强踢后30%追加一次「爆踢」（物理攻击×3.6，三段）': '效果：战神强踢后30%追加一次「爆踢」（三段，每段 物理攻击×1）'},
    '6912': {'效果：战神强踢变为大招：消耗100 TP，六段合计物理攻击×10.8，必定追加爆踢': '效果：战神强踢变为大招：消耗100 TP，六段，每段 物理攻击×2（合计×12），必定追加爆踢'},
    '6920': {'效果：封禁术后30%追加「断魂幽冥斩」（六段神圣，合计魔法攻击×1.2）': '效果：封禁术后30%追加「断魂幽冥斩」（六段神圣，每段 魔法攻击×20%）'},
    '1066': {'效果：独特技能每次出手给目标叠一层霸道真气（最多6层），回合结束每层造成物理攻击×0.1的真实伤害': '效果：独特技能每次出手给目标叠一层霸道真气（最多6层），回合结束每层造成物理攻击×10%的真实伤害'},
    '3709': {'效果：凌空三式后追加一次全体凌空三式（每个敌人1.8）': '效果：凌空三式后追加一次全体凌空三式（每个敌人三段，每段 物理攻击×60%）'},
    '5444': {'效果：湮灭后追加「毁灭烈焰」（全体1.5，凋零、腐朽）': '效果：湮灭后追加「毁灭烈焰」（全体三段，每段 魔法攻击×50%，凋零、腐朽）'},
    '1204': {'效果：巨剑术连放三剑（1.8／2.5／3.0）': '效果：巨剑术连放三剑（物理攻击×2／3／3）'},
    '1212': {'效果：2段伤害；放完失去一半魔法；之后对全体再造成一次伤害（1.8）': '效果：2段伤害；放完失去一半魔法；之后对全体再造成一次伤害（魔法攻击×2）'},
    '5131': {'效果：「炎帝」只耗一半魔法，波动范围8.0～13': '效果：「炎帝」只耗一半魔法（两段合计 魔法攻击×10，浮动25%）'},
    '5133': {'效果：「炎帝」打倒目标时，额外释放一次「烈焰元气弹」（全体3.0）': '效果：「炎帝」打倒目标时，额外释放一次「烈焰元气弹」（全体三段，每段 魔法攻击×1）'},
    '1340': {'效果：九段；目标有怒拳时引爆印记，伤害提到9.0': '效果：九段；目标有怒拳时引爆印记，伤害提到合计 物理攻击×9'},
    '2004': {'效果：九段；之后30%追加大威天龙*佛怒（全体3.0）': '效果：九段；之后30%追加大威天龙*佛怒（全体九段，每段 魔法攻击×33%）'},
    '5476': {'效果：大威天龙*普渡后30%追加大威天龙*佛怒（全体3.0）': '效果：大威天龙*普渡后30%追加大威天龙*佛怒（全体九段，每段 魔法攻击×33%）'},
    '6013': {'效果：三段；之后对全体再炸一次（1.8）': '效果：三段；之后对全体再炸一次（物理攻击×90%＋魔法攻击×90%）'},
    '5311': {'效果：每放三个独有技能，追加一次幽光拔刀斩（3.6，必中）': '效果：每放三个独有技能，追加一次幽光拔刀斩（物理攻击×4，必中）'},
    '5109': {'效果：学会主动大招「剑破万光」（全体6.0，必中，消耗100 TP）': '效果：学会主动大招「剑破万光」（全体 物理攻击×6，必中，消耗100 TP）'},
    '2192': {'效果：大力出奇迹(物攻高于目标时伤害×1.2)；回复10 TP': '效果：大力出奇迹(物攻高于目标时伤害 +20%)；回复10 TP'},
    '5526': {'效果：六段攻击；目标有天弃之雾时伤害×1.2': '效果：六段攻击；目标有天弃之雾时伤害 +20%'},
    '2342': {'效果：随机三箭，必中；敏捷高于目标时伤害×1.2': '效果：随机三箭，必中；敏捷高于目标时伤害 +20%'},
    '2348': {'效果：必中；敏捷高于目标时伤害×1.2': '效果：必中；敏捷高于目标时伤害 +20%'},
    '5473': {'效果：多重射击变为狩神三箭，必定命中，敏捷高于目标时伤害×1.2': '效果：多重射击变为狩神三箭，必定命中，敏捷高于目标时伤害 +20%'},
    '5161': {'效果：诸葛每回合第一次放五行之术后，追加一次当前属性的「知天意」（三段，合计魔法攻击×1.2）': '效果：诸葛每回合第一次放五行之术后，追加一次当前属性的「知天意」（三段，每段 魔法攻击×40%）'},
    '6908': {'效果：七星闪变为「怒佛七绝」：固定七段共7.2，一半按生命上限算，不赌星数，不触发闪流月明': '效果：七星闪变为「怒佛七绝」：固定七段，每段 物理攻击×51%＋生命上限×1%，不赌星数，不触发闪流月明'},
    '3496': {'效果：两段伤害；上一层骨毒（每层每回合 幸运×0.5，3回合，最多3层）': '效果：两段伤害；上一层骨毒（每层每回合 幸运×50%，3回合，最多3层）'},
    '3493': {'效果：两段伤害；上一层骨毒（每层每回合 幸运×0.5，3回合，最多3层）': '效果：两段伤害；上一层骨毒（每层每回合 幸运×50%，3回合，最多3层）'},
    '4450': {'效果：杀气满6点时耗6点，变成大招（×1.67，合计12.0）；否则耗3点': '效果：杀气满6点时耗6点，变成大招（伤害 +67%）；否则耗3点'},
    '5692': {'效果：选凰霞风暴（爆发全体3.6，耗20%魔法）或厄临星爆（耗光魔法，最多10.8）': '效果：选凰霞风暴（全体 魔法攻击×2＋魔法上限×7%，耗20%魔法）或厄临星爆（耗光魔法，按耗掉的魔法比例出伤）'},
    '6023': {'效果：火痕（每回合受到物理攻击×0.6的火焰伤害，2回合）': '效果：火痕（每回合受到物理攻击×60%的火焰伤害，2回合）'},
    '6270': {'效果：黑暗属性全体五段，随机倍率；对生命低于30%的目标取上限（×1.5）': '效果：黑暗属性全体五段，随机倍率；对生命低于30%的目标取浮动上限（+50%）'},
    '3502': {'效果：四段伤害；每层骨毒伤害 +1.2并引爆（三层时合计7.2）': '效果：四段伤害；每层骨毒伤害 +33%并引爆（三层时翻倍）'},
    '3511': {'效果：四段伤害；每层骨毒伤害 +1.2并引爆（三层时合计7.2）': '效果：四段伤害；每层骨毒伤害 +33%并引爆（三层时翻倍）'},
    '3663': {'效果：四段伤害；每层骨毒伤害 +1.2并引爆（三层时合计7.2）': '效果：四段伤害；每层骨毒伤害 +33%并引爆（三层时翻倍）'},
    '3664': {'效果：四段伤害；每层骨毒伤害 +1.2并引爆（三层时合计7.2）': '效果：四段伤害；每层骨毒伤害 +33%并引爆（三层时翻倍）'},
    '10020': {'效果：目标生命低于25%时×1.5': '效果：目标生命低于25%时伤害 +50%'},
    '10132': {'效果：残响3层后下一招追加本次伤害50%（神话形态下为1.5倍）': '效果：残响3层后下一招追加本次伤害50%（神话形态下为150%）'},
    # P3-1：取整后已是准数，去掉「约」；裂焱去重复
    '4753': {'伤害：每段约 物理攻击×2（六段合计×12）；自己敏捷低于目标时 +30%': '伤害：每段 物理攻击×2（六段合计×12）；自己敏捷低于目标时 +30%'},
    '2704': {'伤害：每段约 魔法攻击×42%': '伤害：每段 魔法攻击×42%'},
    '2709': {'伤害：每段约 魔法攻击×42%': '伤害：每段 魔法攻击×42%'},
    '1216': {'效果：必中；灼烧；学了玩火后再放一次（0～200%浮动）': '效果：必中；灼烧；学了玩火后再放一次'},
    # P3-1：镜流同组卡面都写出生命上限那一项（数据里一直有）
    '10188': {'伤害：每段 物理攻击×2（三段合计6）': '伤害：每段 物理攻击×2＋生命上限×4%（三段）'},
    '10189': {'伤害：每段 物理攻击×2（合计4）': '伤害：每段 物理攻击×2＋生命上限×3%（两段）'},
    '10190': {'伤害：每段 物理攻击×1（五段合计5）': '伤害：每段 物理攻击×1＋生命上限×2%（五段）'},
    '10191': {'伤害：每段 物理攻击×2（合计4）': '伤害：每段 物理攻击×2＋生命上限×3%（两段）'},
    '10193': {'伤害：每个敌人 物理攻击×6': '伤害：每个敌人 物理攻击×6＋生命上限×11%'},
}

# T191 R1（小A 核查 P1-1）：五条悟茈按对数取的系数表（gojo.gd 读 gojo_pairs），同样就近取整 .5 进位
GOJO_PAIRS_DESC = {
    '10640': ('伤害：每个敌人 魔法攻击×1.8／3.6／6.0（按1～3对）', '伤害：每个敌人 魔法攻击×{0}／{1}／{2}（按1～3对）'),
    '10641': ('伤害：魔法攻击×3.6／7.2／10.8（按1～3对）', '伤害：魔法攻击×{0}／{1}／{2}（按1～3对）'),
}

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
    by_row = {r[0]: i for i, r in enumerate(rows)}

    def put_desc(sid, row, desc, note):
        e = d200.setdefault(sid, {'_note': note})
        e['desc'] = desc
        if sid in by_row:
            r = rows[by_row[sid]]
            rows[by_row[sid]] = r[:5] + (desc, r[6])
        else:
            by_row[sid] = len(rows)
            rows.append((sid, row.get('actor', ''), row.get('name', ''), [], row.get('desc', []), desc, []))

    for sid, row in merged['skills'].items():
        pairs = row.get('gojo_pairs')
        if isinstance(pairs, list) and any(not int_like(float(x)) for x in pairs):
            newp = [half_up(float(x)) for x in pairs]
            e = d200.setdefault(sid, {})
            e['_note'] = 'T191 取整：gojo_pairs %s → %s' % (pairs, newp)
            e['gojo_pairs'] = newp
            old_line, tpl = GOJO_PAIRS_DESC[sid]
            desc = list(d200[sid].get('desc', row.get('desc', [])))
            assert old_line in desc, (sid, desc)
            desc[desc.index(old_line)] = tpl.format(*newp)
            put_desc(sid, row, desc, e['_note'])
    for sid, fixes in LINE_FIX.items():
        row = merged['skills'][sid]
        desc = list(d200.get(sid, {}).get('desc', row.get('desc', [])))
        for old_line, new_line in fixes.items():
            assert old_line in desc, (sid, old_line, desc)
            desc[desc.index(old_line)] = new_line
        put_desc(sid, row, desc, 'T191 只换卡面（效果行引用的系数、条件倍率跟着取整后的写法）')
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
        show = lambda st, e: (num(round(e * 100, 2)) + '%') if st in PCT_STATS or e < 1 else num(round(e, 4))
        name = lambda st: '取高' if st == 'max_of' else st
        coef_rows = sorted([r for r in rows if r[3]], key=lambda r: (int(r[1] or 0), int(r[0])))
        big = [r for r in coef_rows if any(st not in PCT_STATS and e >= 1 and abs(ne / e - 1) > 0.2 for st, e, ne, _ in r[3])]
        pct_big = [r for r in coef_rows if any((st in PCT_STATS or e < 1) and e > 0 and abs(ne / e - 1) > 0.2 for st, e, ne, _ in r[3])]
        out = ['# T191 附录：系数取整改前改后（tune.D200，生成：03_转换工具/天启篇系数取整.py --report）', '',
               '口径：每项有效系数＝coef×权重×无条件 always；≥1 就近取整 .5 进位；<1 和生命、魔法写整数百分比（最少 1%）。'
               '「变化」按每项有效系数算（条件倍率、段数不变）。', '',
               '## 一、≥1 取整后变化超过 ±20%% 的招（%d 条，给 T192 复量参考）' % len(big), '',
               '| 技能 | 角色 | 名字 | 改前 | 改后 | 变化 |', '|---|---|---|---|---|---|']
        def line(r):
            sid, actor, nm, terms = r[0], r[1], r[2], r[3]
            return '| %s | %s | %s | %s | %s | %s |' % (
                sid, actor, nm.replace('|', '／'),
                '；'.join('%s×%s' % (name(st), show(st, e)) for st, e, _, _ in terms),
                '；'.join('%s×%s' % (name(st), sh) for st, _, _, sh in terms),
                '；'.join(('%+d%%' % round((ne / e - 1) * 100)) if e else '—' for st, e, ne, _ in terms))
        out += [line(r) for r in big]
        out += ['', '## 二、百分比项取整后变化超过 ±20%% 的（%d 条；多是生命上限 0.3%% 这类最少取 1%%）' % len(pct_big), '',
                '| 技能 | 角色 | 名字 | 改前 | 改后 | 变化 |', '|---|---|---|---|---|---|']
        out += [line(r) for r in pct_big]
        out += ['', '## 三、全部改系数的招（%d 条）' % len(coef_rows), '', '| 技能 | 角色 | 名字 | 改前 | 改后 | 变化 |', '|---|---|---|---|---|---|']
        out += [line(r) for r in coef_rows]
        out += ['', '## 四、卡面改前改后（%d 条技能；含只换卡面的 %d 条）' % (len(rows), len([r for r in rows if not r[3]])), '']
        for sid, actor, nm, terms, old, new, left in sorted(rows, key=lambda r: (int(r[1] or 0), int(r[0]))):
            for a, b in zip(old, new):
                if a != b:
                    out.append('- %s %s：%s → %s' % (sid, nm, a, b))
            if len(old) != len(new):
                out.append('- %s %s：%s → %s' % (sid, nm, '／'.join(old), '／'.join(new)))
        rp.write_text('\n'.join(out) + '\n', encoding='utf-8')
        print('报告', rp, '±20%%：%d，百分比±20%%：%d' % (len(big), len(pct_big)))

if __name__ == '__main__':
    main(sys.argv[1:])
