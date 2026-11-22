#!/usr/bin/env python3
"""守层者三张表（T162，基础数值重构 v0.3 第九节第 2 条第 5 步）：把 baseline_dps 的 --both 量数换算成 balance_table.guardian_phase4 三张表。

用法：
  python3 守层者三表.py build --in <both.json> [--in <both2.json> …] [--write]   不带 --write 只打印、不改文件
  python3 守层者三表.py selftest                                                    自检（临时目录，不碰真表）
输入：`baseline_dps.tscn -- --both --out=<json> [--atk-table=…]` 的输出（rows：floor、atkScale、dmg、enemyDmg、hit、partyHp）。多个文件按层合并，后面的盖前面的。
换算（口径同 XGuardianRework 头注释，法宝与积分重构 v0.3）：
- hp_base[层]   ＝ 基准队每回合打出的伤害（有 dmgRaw 用 dmgRaw：日志原始伤害、每次出手前补满，T239；没有用 dmg；取 3 位有效数字的整数）。34 层鸿钧没有守层者敌群，输入里有 34 层行才填，缺就不写（游戏里缺项按 0 取，不该缺：写表前报告列出）。
- atk_scale[层] ＝ 当前倍率 × (partyHp ÷ 6.4) ÷ enemyDmg（守层者每回合打掉基准队合计生命的 1/6.4，不治疗约 8 回合团灭）；1～4 层原版几乎不打人，不放大（取 1）；
                  系数按 3 位有效数字保留（它是敌人出伤的内部倍率，不是玩家看的系数，不受附则 E 整数约束）。
- resist[层]    ＝ 19～33 层，单下伤害中位数 hit 的 30%（整数，取 3 位有效数字）。
第 6 轮口径（--v6，D248 Kyo 11-21 定甲′；输入要带 teams 明细，即 baseline_dps --lineups／--rng-seeds／--add-healer 的输出）：
- 只用普通阵容（team 不是「奶妈队」）；每层先取各队中位。
- hp_base   ＝ 各层 dmgRaw 中位的平滑线：对数下 5 层滑动平均，再取逐层累计最大（不降），去单队噪声。
- atk_scale／focus（默认 --focus-mode c，协调 11-21 定 C）：5～33 层；1～4 层取 1、不设集火。
              每回合总出伤 D ＝ 我方每回合 治疗＋吸血＋回合末回复＋护盾 ＋ 合计生命÷目标回合（续航口径）。
              集火招 F ＝ 守层者单体招（scope 1、3，伤害类型 1、5）里一次出手打掉目标最大生命比例（useRatio）各队中位最高的那招；
              focus[层] ＝ {skill: F, scale: 当前倍率 × share ÷ useRatio_F}（share 默认 0.40）；
              atk_scale ＝ 当前倍率 ×（D − F 每回合打我方 × focus.scale÷当前倍率）÷（守层者每回合打我方 − F 那份），即剩下的预算按原比例摊给其余各下；
              剩下不够（≤0）时 atk_scale 取当前倍率的 10%，报告里标出。没有单体招的层不设集火、atk_scale 按 D 定。各队算完取中位。
- 对照口径（不写表）：add＝加法（--focus-mode add）：当前倍率 ×（我方每回合 治疗＋吸血＋回合末回复＋护盾 ＋ 合计生命÷目标回合
              ＋ share×单人平均最大生命）÷ 守层者每回合打我方；share 默认 0.40（--share），即每回合另加一下打掉一人 40% 的集火。
              --focus-mode max：取「续航口径（不含集火项）」与「当前倍率 × share ÷ 守层者单下占一人最大生命比例中位」两者大的。
- resist    ＝ 19～33 层，我方普攻单下伤害中位（atkHit，每个目标一条）的 30%。
T363 迭代（Kyo 11-21 事项17「全按推荐」）：
- hp_base 默认 --hp-mode top：每层单独取普通阵容各队 dmgRaw 的 90 分位（强队）×（目标回合−2）÷目标回合，即强队约（目标回合−2）回合打死；
              不再跨层平滑、不再逐层累计最大（7、19 层就是被邻层抬高血量才全灭）。--hp-mode smooth 回到第 6 轮做法。
- 多个 --in 同一层的 teams 合在一起（两条存档链一起构表；原来后一个文件整层盖掉前一个，T239 核 P2-4）。
- 集火招封顶：期望出伤占预算的比例只在放过这招的队里取中位（没放的队按 0 计会把中位拉低、绕过一半封顶，T239 核 P2-5）。
- 守层者每回合打我方优先取 enemyDmgBase（集火招按表里倍率多打的折回统一倍率，量数照新表打时用）。
- 12、15、25 层（SINGLE）没有单体伤害招：指定一招在守层者手里改打一人（表里 "single": 1，游戏 XGuardianRework.single_action）；
              量数里那招已是单体（scope 1）就照实测；还是多体（老量数）就按一次出手的目标数 n（全体＝队伍人数、随机 k 个＝k）把每回合打我方、一次占比都 ÷n 估单体。
- 真打校准（--duel-calib <真打 json>…，T363 第 2 步）：量数的 dmgRaw 是每下前补满、不算守层者回血闪避与同场异化（19 层号令官），
              真打实际掉血可能只有它的一半，也可能更多。按真打（baseline_dps --duel 的输出，表是当时写进去的那份）重定 hp_base：
              每队实效每回合伤害＝输了的队取真打每回合掉血、赢了的队取 当时血量÷赢的回合数；hp_base＝各层普通阵容实效的 90 分位 ×（目标回合−2）÷目标回合。
              atk_scale、focus、resist 仍按量数。
空表（rows 为空）：什么都不写，退出码 0，打印「没有数」。写入时只动 balance_table.json 里 guardian_phase4 这一键（文本层面替换，其余字节不动）。"""
import argparse
import json
import math
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TABLE = HERE.parent / '01_Godot工程' / 'modes' / 'xiyou' / 'tianqi_data' / 'balance_table.json'
KEY = 'guardian_phase4'
FLOORS = range(1, 35)
RESIST_FLOORS = range(19, 34)
PARTY_HP_DIV = 6.4
RESIST_SHARE = 0.3
HP_QUANTILE = 0.9   # T363：hp_base 取各队 dmgRaw 的这个分位（强队）
SINGLE = {12: 661, 15: 827, 25: 3563}   # T363（Kyo 11-21 事项17 问2）：奥术波动（3 随机）、如来神掌（2 随机）、仙宫寒气（3 随机）改打一人


def sig3(x: float) -> float:
    if x == 0 or not math.isfinite(x):
        return 0.0
    return round(x, 2 - int(math.floor(math.log10(abs(x)))))


def build(rows: list) -> dict:
    by = {}
    for r in rows:
        by[int(r['floor'])] = r
    hp, atk, resist = {}, {}, {}
    for f in FLOORS:
        r = by.get(f)
        if r is None:
            continue
        raw = float(r.get('dmgRaw') or 0)   # T239：有日志原始伤害（不被剩余血量截断）且＞0 就用它；--no-raw 的输出没有 dmgRaw，退回 dmg（核 P2-2）
        d = raw if raw > 0 else float(r.get('dmg', 0))
        if d > 0:
            hp[str(f)] = int(sig3(d))
        if f <= 4:
            atk[str(f)] = 1
        elif f <= 33 and float(r.get('enemyDmg', 0)) > 0 and float(r.get('partyHp', 0)) > 0:
            atk[str(f)] = sig3(float(r.get('atkScale', 1.0)) * (float(r['partyHp']) / PARTY_HP_DIV) / float(r['enemyDmg']))
        if f in RESIST_FLOORS and float(r.get('hit', 0)) > 0:
            resist[str(f)] = int(sig3(float(r['hit']) * RESIST_SHARE))
    out = {}
    if hp:
        out['hp_base'] = hp
    if atk:
        out['atk_scale'] = atk
    if resist:
        out['resist'] = resist
    return out


def _med(xs):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return 0.0
    n = len(xs)
    return (xs[(n - 1) // 2] + xs[n // 2]) / 2.0


def _quant(xs, p):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return 0.0
    k = (len(xs) - 1) * p
    lo, hi = math.floor(k), math.ceil(k)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def _ed(t: dict) -> float:
    """守层者每回合打我方：有 enemyDmgBase（T363，集火招折回统一倍率）用它"""
    v = t.get('enemyDmgBase')
    return float(v) if v is not None else float(t.get('enemyDmg', 0))


def _skills(t: dict, f: int) -> dict:
    """这队守层者每招（T363：SINGLE 层的指定招还是多体时按单体估：每回合打我方、一次出手占比都 ÷ 目标数，scope 记 1）"""
    out = dict(t.get('bySkill') or {})
    sk = SINGLE.get(f)
    if sk and str(sk) in out:
        v = dict(out[str(sk)])
        n = {2: len(t.get('mhp') or [0, 0, 0, 0]), 3: 1, 4: 2, 5: 3, 6: 4}.get(int(v.get('scope', 0)), 0)
        if n > 0 and float(v.get('useRatio', 0)) > 0:   # 一次出手打 n 个目标（随机可重复、带连击照算）→ 改打一人约 1/n
            v.update({'dmg': float(v.get('dmg', 0)) / n, 'useRatio': float(v['useRatio']) / n, 'scope': 1, 'est': True})
        out[str(sk)] = v
    return out


def normal_teams(r: dict) -> list:
    teams = r.get('teams') or [r]
    return [t for t in teams if t.get('team') != '奶妈队']


def smooth(per_floor: dict, window: int = 5) -> dict:
    fs = sorted(f for f, v in per_floor.items() if v > 0)
    logs = {f: math.log(per_floor[f]) for f in fs}
    out, top = {}, 0.0
    for i, f in enumerate(fs):
        lo, hi = max(0, i - window // 2), min(len(fs), i + window // 2 + 1)
        v = math.exp(sum(logs[g] for g in fs[lo:hi]) / (hi - lo))
        top = max(top, v)
        out[f] = top
    return out


def floor_stats(r: dict, turns: int, share: float, mode: str = 'add') -> dict:
    ts = normal_teams(r)
    def dmg(t):
        raw = float(t.get('dmgRaw') or 0)
        return raw if raw > 0 else float(t.get('dmg', 0))
    sus, foc = [], []
    for t in ts:
        ed = _ed(t)
        k0 = float(t.get('atkScale', 1.0))
        rec = sum(float(t.get(k, 0)) for k in ('heal', 'steal', 'regen', 'shield'))
        php = float(t.get('partyHp', 0))
        nm = max(1, len(t.get('mhp') or t.get('members') or [0, 0, 0, 0]))
        if ed > 0 and php > 0:
            sus.append(k0 * (rec + php / turns + (share * php / nm if mode == 'add' else 0.0)) / ed)
        if mode == 'max' and float(t.get('focus', 0)) > 0:
            foc.append(k0 * share / float(t['focus']))
    return {'dmg': _med([dmg(t) for t in ts]), 'top': _quant([dmg(t) for t in ts], HP_QUANTILE), 'sus': _med(sus), 'focus': _med(foc), 'atkHit': _med([float(t.get('atkHit', 0)) for t in ts if float(t.get('atkHit', 0)) > 0]),
            'rec': _med([sum(float(t.get(k, 0)) for k in ('heal', 'steal', 'regen', 'shield')) for t in ts]), 'n': len(ts)}


FOCUS_CAP = 0.5   # 集火那招的期望出伤最多占每回合总预算的一半（「每回合一下」；那招一回合用好几次时压它的倍率）


def _need(t: dict, turns: int) -> float:
    return sum(float(t.get(k, 0)) for k in ('heal', 'steal', 'regen', 'shield')) + float(t.get('partyHp', 0)) / turns


def focus_pick(r: dict, turns: int = 8, share: float = 0.40) -> tuple:
    """单体招（scope 1、3，类型 1、5）按一次出手 useRatio 各队中位从高到低，取第一个「定到 share 后期望出伤 ≤ 预算 FOCUS_CAP」的；
    都超就取超得最少的、把倍率压到正好 FOCUS_CAP。返回 (技能号, useRatio 中位, 压倍率的系数≤1)；没有单体招 (0, 0, 1)。
    期望出伤占比只在放过这招的队里取中位（T363，核 P2-5）；SINGLE 层只认指定那招。"""
    ts = normal_teams(r)
    f = int(r.get('floor', 0))
    per = {}
    for t in ts:
        for sk, v in _skills(t, f).items():
            if f in SINGLE and int(sk) != SINGLE[f]:
                continue
            if int(v.get('scope', 0)) in (1, 3) and int(v.get('type', 0)) in (1, 5) and float(v.get('useRatio', 0)) > 0:
                per.setdefault(int(sk), []).append(float(v['useRatio']))
    best = None
    for sk in sorted(per, key=lambda k: (-_med(per[k]), -len(per[k]))):
        ur = _med(per[sk])
        fr = _med([float(_skills(t, f).get(str(sk), {}).get('dmg', 0)) * share / ur / _need(t, turns) for t in ts
                   if float(t.get('partyHp', 0)) > 0 and float(_skills(t, f).get(str(sk), {}).get('dmg', 0)) > 0])
        if fr <= FOCUS_CAP:
            return sk, ur, 1.0
        if best is None or fr < best[2]:
            best = (sk, ur, fr)
    if best is None:
        return 0, 0.0, 1.0
    return best[0], best[1], FOCUS_CAP / best[2]


def focus_stats(r: dict, turns: int, share: float) -> dict:
    """C 口径：返回 {skill, scale, atk, short, hitRatio（集火那下实际定到的比例）}；skill 0＝本层没有单体招。"""
    ts = normal_teams(r)
    sk, ur, cut = focus_pick(r, turns, share)
    k0 = _med([float(t.get('atkScale', 1.0)) for t in ts])
    kf = k0 * share / ur * cut if ur > 0 else 0.0
    atk, short = [], 0
    f = int(r.get('floor', 0))
    for t in ts:
        ed = _ed(t)
        php = float(t.get('partyHp', 0))
        if ed <= 0 or php <= 0:
            continue
        d = sum(float(t.get(k, 0)) for k in ('heal', 'steal', 'regen', 'shield')) + php / turns
        ef = float(_skills(t, f).get(str(sk), {}).get('dmg', 0)) if sk else 0.0
        rest_need = d - (ef * kf / k0 if kf > 0 else 0.0)
        rest_have = ed - ef
        if rest_have <= 0 or rest_need <= 0:
            short += 1
            atk.append(k0 * 0.1)
        else:
            atk.append(float(t.get('atkScale', k0)) * rest_need / rest_have)
    return {'skill': sk, 'useRatio': ur, 'scale': kf, 'atk': _med(atk), 'short': short, 'k0': k0, 'hitRatio': share * cut if sk else 0.0}


def merge_rows(rows: list) -> dict:
    """按层合并（T363，核 P2-4）：同一层多行（多个 --in）的 teams 接在一起，没有 teams 的行本身算一队；其余字段取第一行"""
    by = {}
    for r in rows:
        f = int(r['floor'])
        ts = list(r.get('teams') or [r])
        if f in by:
            by[f]['teams'] = by[f]['teams'] + ts
        else:
            by[f] = dict(r, teams=ts)
    return by


def build6(rows: list, turns: int = 8, share: float = 0.40, mode: str = 'c', hp_mode: str = 'top') -> dict:
    by = merge_rows(rows)
    rows = list(by.values())
    if mode == 'c':
        out = build6(rows, turns, 0.0, 'add', hp_mode)
        foc = {}
        for f in FLOORS:
            if 5 <= f <= 33 and f in by:
                fs = focus_stats(by[f], turns, share)
                if fs['atk'] > 0:
                    out.setdefault('atk_scale', {})[str(f)] = sig3(fs['atk'])
                if fs['skill'] > 0 and fs['scale'] > 0:
                    foc[str(f)] = {'skill': fs['skill'], 'scale': sig3(fs['scale'])}
                    if SINGLE.get(f) == fs['skill']:
                        foc[str(f)]['single'] = 1
        if foc:
            out['focus'] = foc
        return out
    st = {f: floor_stats(by[f], turns, share, mode) for f in FLOORS if f in by}
    hp, atk, resist = {}, {}, {}
    if hp_mode == 'smooth':
        for f, v in smooth({f: s['dmg'] for f, s in st.items()}).items():
            hp[str(f)] = int(sig3(v))
    else:   # T363：每层单独取强队（90 分位），强队约（目标回合−2）回合打死
        for f, s in st.items():
            if s['top'] > 0:
                hp[str(f)] = int(sig3(s['top'] * (turns - 2) / turns))
    for f, s in st.items():
        if f <= 4:
            atk[str(f)] = 1
        elif f <= 33 and max(s['sus'], s['focus']) > 0:
            atk[str(f)] = sig3(max(s['sus'], s['focus']))
        if f in RESIST_FLOORS and s['atkHit'] > 0:
            resist[str(f)] = int(sig3(s['atkHit'] * RESIST_SHARE))
    out = {}
    if hp:
        out['hp_base'] = hp
    if atk:
        out['atk_scale'] = atk
    if resist:
        out['resist'] = resist
    return out


def duel_calib(paths: list, turns: int = 8) -> dict:
    """T363：按真打重定 hp_base（见头注释）。返回 {层: 每回合血量}"""
    eff = {}
    for p in paths:
        for r in json.loads(Path(p).read_text(encoding='utf-8')).get('rows', []):
            f = int(r['floor'])
            for t in r.get('per', []):
                if t.get('team') == '奶妈队' or int(t.get('turns', 0)) <= 0:
                    continue
                e = float(t.get('enemyHp', r.get('enemyHp', 0))) / int(t['turns']) if t.get('won') else float(t.get('dmg', 0))
                if e > 0:
                    eff.setdefault(f, []).append(e)
    return {f: int(sig3(_quant(v, HP_QUANTILE) * (turns - 2) / turns)) for f, v in eff.items() if v}


def render(tables: dict) -> str:
    lines = []
    for name, t in tables.items():
        lines.append('  "%s": {%s}' % (name, ', '.join('"%s": %s' % (k, json.dumps(v)) for k, v in t.items())))
    return ' "%s": {\n%s\n }' % (KEY, ',\n'.join(lines))


def apply(text: str, tables: dict) -> str:
    """文本层面写 guardian_phase4：有就换，没有就加在顶层末尾；其余字节不动。"""
    m = re.search(r',?\n "%s": ' % KEY, text)
    if m:
        _, end = json.JSONDecoder().raw_decode(text, m.end())
        text = text[:m.start()] + text[end:]
    stripped = text.rstrip()
    assert stripped.endswith('}'), 'balance_table.json 末尾不是 }'
    body = stripped[:-1].rstrip()
    return body + ',\n' + render(tables) + '\n}' + text[len(stripped):]


def missing(tables: dict) -> list:
    out = []
    for f in FLOORS:
        if str(f) not in tables.get('hp_base', {}) or (f <= 33 and str(f) not in tables.get('atk_scale', {})):
            out.append(f)
    for f in RESIST_FLOORS:
        if str(f) not in tables.get('resist', {}):
            out.append(-f)
    return out


def load_rows(paths: list) -> list:
    rows = []
    for p in paths:
        d = json.loads(Path(p).read_text(encoding='utf-8'))
        rows.extend(d.get('rows', []))
    return rows


def cmd_build(args) -> int:
    rows = load_rows(args.inputs)
    tables = build6(rows, args.turns, args.share, args.focus_mode, args.hp_mode) if args.v6 else build(rows)
    if args.v6 and rows:
        by = merge_rows(rows)
        print('层 | 队数 | 每回合伤害中位 | 平滑 | 我方回复/回合 | 不含集火 | 加法 0.35/0.40/0.45/0.50 | 取大 0.40 | 普攻单下中位', file=sys.stderr)
        for f in sorted(by):
            s = floor_stats(by[f], args.turns, 0.0, 'add')
            fo = [floor_stats(by[f], args.turns, x, 'add')['sus'] for x in (0.35, 0.40, 0.45, 0.50)]
            mx = floor_stats(by[f], args.turns, 0.40, 'max')
            cs = [focus_stats(by[f], args.turns, x) for x in (0.35, 0.40, 0.45, 0.50)]
            print('%d | %d | %.0f | %s | %.0f | %.3g | %s | %.3g | %.0f | C 招 %d 单次占比 %.3g 集火倍率/其余倍率 %s 定到单下 %.2f 不够队数 %d' % (
                f, s['n'], s['dmg'], tables.get('hp_base', {}).get(str(f)), s['rec'], s['sus'], '/'.join('%.3g' % x for x in fo),
                max(mx['sus'], mx['focus']), s['atkHit'], cs[1]['skill'], cs[1]['useRatio'], ' '.join('%.3g/%.3g' % (c['scale'], c['atk']) for c in cs), cs[1]['hitRatio'], cs[1]['short']), file=sys.stderr)
    if args.v6 and args.duel_calib and tables:
        cal = duel_calib(args.duel_calib, args.turns)
        for f, v in sorted(cal.items()):
            print('真打校准 %d 层 hp_base %s → %d' % (f, tables.get('hp_base', {}).get(str(f)), v), file=sys.stderr)
            tables.setdefault('hp_base', {})[str(f)] = v
    if not tables:
        print('没有数（输入里没有可用的层），不写。')
        return 0
    print(render(tables))
    gaps = missing(tables)
    if gaps:
        print('缺：hp_base／atk_scale 缺层 %s；resist 缺层 %s' % ([g for g in gaps if g > 0], [-g for g in gaps if g < 0]), file=sys.stderr)
    if args.write:
        TABLE.write_text(apply(TABLE.read_text(encoding='utf-8'), tables), encoding='utf-8')
        json.loads(TABLE.read_text(encoding='utf-8'))
        print('已写入 %s' % TABLE)
    return 0


def selftest() -> int:
    base = '{\n "version": 1,\n "combat_rules": {"a": 1}\n}\n'
    rows = [{'floor': 2, 'dmg': 626123, 'atkScale': 1.0, 'enemyDmg': 10.0, 'partyHp': 100.0, 'hit': 5},
            {'floor': 20, 'dmg': 2251234, 'atkScale': 0.074, 'enemyDmg': 2000.0, 'partyHp': 64000.0, 'hit': 16000.0}]
    t = build(rows)
    assert t['hp_base'] == {'2': 626000, '20': 2250000}, t
    assert build([{'floor': 3, 'dmg': 5, 'dmgRaw': 123456}])['hp_base'] == {'3': 123000}
    assert build([{'floor': 3, 'dmg': 7000, 'dmgRaw': 0}])['hp_base'] == {'3': 7000}   # dmgRaw 为 0 退回 dmg
    assert build([{'floor': 3, 'dmg': 7000, 'dmgRaw': None}])['hp_base'] == {'3': 7000}
    assert t['atk_scale']['2'] == 1 and t['atk_scale']['20'] == sig3(0.074 * 10000 / 2000), t
    assert t['resist'] == {'20': 4800}, t
    assert build([]) == {}
    once = apply(base, t)
    j = json.loads(once)
    assert j[KEY]['hp_base']['20'] == 2250000 and j['combat_rules'] == {'a': 1}
    t2 = build([{'floor': 20, 'dmg': 3000000, 'atkScale': 1.0, 'enemyDmg': 1.0, 'partyHp': 6.4, 'hit': 1000}])
    twice = apply(once, t2)
    j2 = json.loads(twice)
    assert j2[KEY]['hp_base'] == {'20': 3000000} and twice.count(KEY) == 1, twice
    assert twice.startswith(base.rstrip()[:-2]), '前面的字节被改了'
    # 真表当前没有 guardian_phase4 也能加、加完能解析、再换一次只剩一份
    real = TABLE.read_text(encoding='utf-8')
    r1 = apply(real, t)
    assert json.loads(r1)[KEY]['resist'] == {'20': 4800}
    assert apply(r1, t2).count('"%s"' % KEY) == 1
    # 第 6 轮口径
    rows6 = [{'floor': f, 'teams': [
        {'team': '原队', 'dmgRaw': 1000.0 * f, 'atkScale': 1.0, 'enemyDmg': 100.0, 'partyHp': 800.0, 'heal': 50.0, 'steal': 0, 'regen': 0, 'shield': 0, 'focus': 0.1, 'atkHit': 1000.0},
        {'team': '随机1', 'dmgRaw': 3000.0 * f, 'atkScale': 1.0, 'enemyDmg': 100.0, 'partyHp': 800.0, 'heal': 50.0, 'focus': 0.1, 'atkHit': 3000.0},
        {'team': '奶妈队', 'dmgRaw': 1e9, 'atkScale': 1.0, 'enemyDmg': 1.0, 'partyHp': 1e9, 'heal': 1e9, 'focus': 1e-9, 'atkHit': 1e9}]} for f in (5, 6, 20)]
    t6 = build6(rows6, 8, 0.40, 'max')
    assert t6['atk_scale']['5'] == 4.0, t6   # 取大：集火 0.4/0.1＝4 ＞ 续航 (50＋100)/100＝1.5；奶妈队不进
    assert build6(rows6, 8, 0.40, 'add')['atk_scale']['5'] == 2.3   # 加法：(50＋100＋0.4×800/4)/100
    # C：F＝单体招 7（每次打掉 10%），集火倍率 0.4/0.1＝4；F 每回合 15 → 新 60（占预算 150 的 0.4 ≤ 0.5）；其余 85 要摊 90 → 1.06
    for r in rows6:
        for t in r['teams']:
            t['bySkill'] = {'7': {'scope': 1, 'type': 1, 'useRatio': 0.1, 'dmg': 15.0}, '8': {'scope': 8, 'type': 1, 'useRatio': 0.5, 'dmg': 85.0}}
    tc = build6(rows6, 8, 0.40)
    assert tc['focus']['5'] == {'skill': 7, 'scale': 4.0} and tc['atk_scale']['5'] == 1.06, tc
    for r in rows6:   # F 每回合 20 → 新 80 占 0.53 超一半：压到 0.5，集火倍率 4×0.5/0.533＝3.75
        for t in r['teams']:
            t['bySkill']['7']['dmg'] = 20.0
    assert build6(rows6, 8, 0.40)['focus']['5'] == {'skill': 7, 'scale': 3.75}
    assert t6['resist'] == {'20': 600}, t6   # 普攻单下中位 2000×0.3
    assert int(t6['hp_base']['6']) >= int(t6['hp_base']['5']) and int(t6['hp_base']['20']) >= int(t6['hp_base']['6']), t6   # 平滑后不降
    assert build6(rows6, 8, 0.10, 'max')['atk_scale']['5'] == 1.5
    assert build6(rows6, 8, 0.40, 'add', 'smooth')['hp_base']['5'] > 0
    # T363 hp top：每层各队 dmgRaw 90 分位 ×(8−2)/8；两队 5000、15000 → 14000×0.75＝10500
    assert build6(rows6, 8, 0.40)['hp_base']['5'] == 10500, build6(rows6, 8, 0.40)['hp_base']
    # T363 P2-4：同一层分在两个 --in 里，teams 合并而不是后者盖前者
    a = [{'floor': 9, 'teams': [dict(rows6[0]['teams'][0], dmgRaw=1000.0)]}]
    b = [{'floor': 9, 'teams': [dict(rows6[0]['teams'][0], dmgRaw=9000.0)]}]
    m = merge_rows(a + b)
    assert len(m[9]['teams']) == 2 and build6(a + b, 8, 0.40)['hp_base']['9'] == int(sig3((1000 + 0.9 * 8000) * 0.75)), m
    # T363 P2-5：没放集火招的队不按 0 计。三队里只一队放了，期望出伤占预算 0.8（定到 0.4/0.1 后 20→80，预算 100）→ 压到 0.5
    t0 = {'team': '原队', 'atkScale': 1.0, 'enemyDmg': 100.0, 'partyHp': 800.0, 'heal': 0.0}
    tz = [dict(t0, bySkill={'7': {'scope': 1, 'type': 1, 'useRatio': 0.1, 'dmg': 20.0}, '8': {'scope': 2, 'type': 1, 'useRatio': 0.5, 'dmg': 80.0}}),
          dict(t0, team='随机1', bySkill={'8': {'scope': 2, 'type': 1, 'useRatio': 0.5, 'dmg': 100.0}}),
          dict(t0, team='随机2', bySkill={'8': {'scope': 2, 'type': 1, 'useRatio': 0.5, 'dmg': 100.0}})]
    sk, ur, cut = focus_pick({'floor': 10, 'teams': tz})
    assert sk == 7 and abs(cut - 0.5 / 0.8) < 1e-9, (sk, ur, cut)
    # T363 SINGLE：12 层只认 661；老量数里还是 3 随机（scope 5，一次合计 0.3、一下 0.1）→ 按单体估，表里带 single
    t12 = dict(t0, bySkill={'661': {'scope': 5, 'type': 1, 'useRatio': 0.3, 'ratio': 0.02, 'dmg': 30.0}, '9': {'scope': 1, 'type': 1, 'useRatio': 0.5, 'dmg': 70.0}})
    tb = build6([{'floor': 12, 'teams': [t12]}], 8, 0.40)
    assert tb['focus']['12'] == {'skill': 661, 'scale': 4.0, 'single': 1}, tb   # 单体估 dmg 10、占比 0.1 → 40 ≤ 预算 100 的一半
    # 量数里已是单体（scope 1）照实测；enemyDmgBase 优先
    t12b = dict(t0, enemyDmg=500.0, enemyDmgBase=100.0, bySkill={'661': {'scope': 1, 'type': 1, 'useRatio': 0.1, 'ratio': 0.1, 'dmg': 10.0}, '9': {'scope': 1, 'type': 1, 'useRatio': 0.5, 'dmg': 90.0}})
    tb2 = build6([{'floor': 12, 'teams': [t12b]}], 8, 0.40)
    assert tb2['focus']['12']['skill'] == 661 and tb2['atk_scale']['12'] == sig3(60 / 90), tb2   # 其余预算 100−40＝60 摊给其余 90
    # T363 真打校准：输的队取每回合掉血，赢的队取 血量÷回合；奶妈队不算
    import os
    fd, tmp = tempfile.mkstemp(suffix='.json')
    os.close(fd)
    Path(tmp).write_text(json.dumps({'rows': [{'floor': 19, 'enemyHp': 800.0, 'per': [
        {'team': '原队', 'won': False, 'turns': 9, 'dmg': 50.0}, {'team': '随机1', 'won': True, 'turns': 4, 'dmg': 999.0},
        {'team': '奶妈队', 'won': True, 'turns': 1, 'dmg': 1e9}]}]}), encoding='utf-8')
    assert duel_calib([tmp]) == {19: int(sig3((50 + 0.9 * 150) * 0.75))}, duel_calib([tmp])
    os.unlink(tmp)
    print('selftest 通过')
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('build')
    b.add_argument('--in', dest='inputs', action='append', required=True)
    b.add_argument('--write', action='store_true')
    b.add_argument('--v6', action='store_true', help='第 6 轮口径（D248 甲′）')
    b.add_argument('--turns', type=int, default=8, help='目标回合（艰险 8）')
    b.add_argument('--share', type=float, default=0.40, help='集火：单下打中一人占其最大生命的比例')
    b.add_argument('--focus-mode', choices=['c', 'add', 'max'], default='c')
    b.add_argument('--duel-calib', action='append', default=[], help='T363：按真打 json 重定 hp_base（可多个）')
    b.add_argument('--hp-mode', choices=['top', 'smooth'], default='top', help='T363 top＝每层强队 90 分位×(回合−2)÷回合；smooth＝第 6 轮平滑')
    sub.add_parser('selftest')
    args = ap.parse_args(argv)
    return cmd_build(args) if args.cmd == 'build' else selftest()


if __name__ == '__main__':
    sys.exit(main())
