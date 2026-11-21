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
        ed = float(t.get('enemyDmg', 0))
        k0 = float(t.get('atkScale', 1.0))
        rec = sum(float(t.get(k, 0)) for k in ('heal', 'steal', 'regen', 'shield'))
        php = float(t.get('partyHp', 0))
        nm = max(1, len(t.get('mhp') or t.get('members') or [0, 0, 0, 0]))
        if ed > 0 and php > 0:
            sus.append(k0 * (rec + php / turns + (share * php / nm if mode == 'add' else 0.0)) / ed)
        if mode == 'max' and float(t.get('focus', 0)) > 0:
            foc.append(k0 * share / float(t['focus']))
    return {'dmg': _med([dmg(t) for t in ts]), 'sus': _med(sus), 'focus': _med(foc), 'atkHit': _med([float(t.get('atkHit', 0)) for t in ts if float(t.get('atkHit', 0)) > 0]),
            'rec': _med([sum(float(t.get(k, 0)) for k in ('heal', 'steal', 'regen', 'shield')) for t in ts]), 'n': len(ts)}


def focus_pick(r: dict) -> int:
    """各队 bySkill 里单体招（scope 1、3，类型 1、5）一次出手 useRatio 的中位，取最高那招；没有返回 0。"""
    per = {}
    for t in normal_teams(r):
        for sk, v in (t.get('bySkill') or {}).items():
            if int(v.get('scope', 0)) in (1, 3) and int(v.get('type', 0)) in (1, 5) and float(v.get('useRatio', 0)) > 0:
                per.setdefault(int(sk), []).append(float(v['useRatio']))
    if not per:
        return 0
    return max(per, key=lambda k: (_med(per[k]), len(per[k])))


def focus_stats(r: dict, turns: int, share: float) -> dict:
    """C 口径：返回 {skill, scale, atk, short}；skill 0＝本层没有单体招。"""
    ts = normal_teams(r)
    sk = focus_pick(r)
    ur = _med([float((t.get('bySkill') or {}).get(str(sk), {}).get('useRatio', 0)) for t in ts if str(sk) in (t.get('bySkill') or {})]) if sk else 0.0
    k0 = _med([float(t.get('atkScale', 1.0)) for t in ts])
    kf = k0 * share / ur if ur > 0 else 0.0
    atk, short = [], 0
    for t in ts:
        ed = float(t.get('enemyDmg', 0))
        php = float(t.get('partyHp', 0))
        if ed <= 0 or php <= 0:
            continue
        d = sum(float(t.get(k, 0)) for k in ('heal', 'steal', 'regen', 'shield')) + php / turns
        ef = float((t.get('bySkill') or {}).get(str(sk), {}).get('dmg', 0)) if sk else 0.0
        rest_need = d - (ef * kf / k0 if kf > 0 else 0.0)
        rest_have = ed - ef
        if rest_have <= 0 or rest_need <= 0:
            short += 1
            atk.append(k0 * 0.1)
        else:
            atk.append(float(t.get('atkScale', k0)) * rest_need / rest_have)
    return {'skill': sk, 'useRatio': ur, 'scale': kf, 'atk': _med(atk), 'short': short, 'k0': k0}


def build6(rows: list, turns: int = 8, share: float = 0.40, mode: str = 'c') -> dict:
    by = {int(r['floor']): r for r in rows}
    if mode == 'c':
        out = build6(rows, turns, 0.0, 'add')
        foc = {}
        for f in FLOORS:
            if 5 <= f <= 33 and f in by:
                fs = focus_stats(by[f], turns, share)
                if fs['atk'] > 0:
                    out.setdefault('atk_scale', {})[str(f)] = sig3(fs['atk'])
                if fs['skill'] > 0 and fs['scale'] > 0:
                    foc[str(f)] = {'skill': fs['skill'], 'scale': sig3(fs['scale'])}
        if foc:
            out['focus'] = foc
        return out
    st = {f: floor_stats(by[f], turns, share, mode) for f in FLOORS if f in by}
    hp, atk, resist = {}, {}, {}
    for f, v in smooth({f: s['dmg'] for f, s in st.items()}).items():
        hp[str(f)] = int(sig3(v))
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
    tables = build6(rows, args.turns, args.share, args.focus_mode) if args.v6 else build(rows)
    if args.v6 and rows:
        by = {int(r['floor']): r for r in rows}
        print('层 | 队数 | 每回合伤害中位 | 平滑 | 我方回复/回合 | 不含集火 | 加法 0.35/0.40/0.45/0.50 | 取大 0.40 | 普攻单下中位', file=sys.stderr)
        for f in sorted(by):
            s = floor_stats(by[f], args.turns, 0.0, 'add')
            fo = [floor_stats(by[f], args.turns, x, 'add')['sus'] for x in (0.35, 0.40, 0.45, 0.50)]
            mx = floor_stats(by[f], args.turns, 0.40, 'max')
            cs = [focus_stats(by[f], args.turns, x) for x in (0.35, 0.40, 0.45, 0.50)]
            print('%d | %d | %.0f | %s | %.0f | %.3g | %s | %.3g | %.0f | C 招 %d 单次占比 %.3g 集火倍率/其余倍率 %s 不够队数 %d' % (
                f, s['n'], s['dmg'], tables.get('hp_base', {}).get(str(f)), s['rec'], s['sus'], '/'.join('%.3g' % x for x in fo),
                max(mx['sus'], mx['focus']), s['atkHit'], cs[1]['skill'], cs[1]['useRatio'], ' '.join('%.3g/%.3g' % (c['scale'], c['atk']) for c in cs), cs[1]['short']), file=sys.stderr)
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
    # C：F＝单体招 7（每次打掉 10%），集火倍率 0.4/0.1＝4；F 每回合 20 → 新 80；其余 80 要摊 (150−80)＝70 → 0.875
    for r in rows6:
        for t in r['teams']:
            t['bySkill'] = {'7': {'scope': 1, 'type': 1, 'useRatio': 0.1, 'dmg': 20.0}, '8': {'scope': 8, 'type': 1, 'useRatio': 0.5, 'dmg': 80.0}}
    tc = build6(rows6, 8, 0.40)
    assert tc['focus']['5'] == {'skill': 7, 'scale': 4.0} and tc['atk_scale']['5'] == 0.875, tc
    assert t6['resist'] == {'20': 600}, t6   # 普攻单下中位 2000×0.3
    assert int(t6['hp_base']['6']) >= int(t6['hp_base']['5']) and int(t6['hp_base']['20']) >= int(t6['hp_base']['6']), t6   # 平滑后不降
    assert build6(rows6, 8, 0.10, 'max')['atk_scale']['5'] == 1.5
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
    sub.add_parser('selftest')
    args = ap.parse_args(argv)
    return cmd_build(args) if args.cmd == 'build' else selftest()


if __name__ == '__main__':
    sys.exit(main())
