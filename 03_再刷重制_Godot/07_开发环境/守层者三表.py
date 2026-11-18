#!/usr/bin/env python3
"""守层者三张表（T162，基础数值重构 v0.3 第九节第 2 条第 5 步）：把 baseline_dps 的 --both 量数换算成 balance_table.guardian_phase4 三张表。

用法：
  python3 守层者三表.py build --in <both.json> [--in <both2.json> …] [--write]   不带 --write 只打印、不改文件
  python3 守层者三表.py selftest                                                    自检（临时目录，不碰真表）
输入：`baseline_dps.tscn -- --both --out=<json> [--atk-table=…]` 的输出（rows：floor、atkScale、dmg、enemyDmg、hit、partyHp）。多个文件按层合并，后面的盖前面的。
换算（口径同 XGuardianRework 头注释，法宝与积分重构 v0.3）：
- hp_base[层]   ＝ 基准队每回合打出的伤害 dmg（取 3 位有效数字的整数）。34 层鸿钧没有守层者敌群，输入里有 34 层行才填，缺就不写（游戏里缺项按 0 取，不该缺：写表前报告列出）。
- atk_scale[层] ＝ 当前倍率 × (partyHp ÷ 6.4) ÷ enemyDmg（守层者每回合打掉基准队合计生命的 1/6.4，不治疗约 8 回合团灭）；1～4 层原版几乎不打人，不放大（取 1）；
                  系数按 3 位有效数字保留（它是敌人出伤的内部倍率，不是玩家看的系数，不受附则 E 整数约束）。
- resist[层]    ＝ 19～33 层，单下伤害中位数 hit 的 30%（整数，取 3 位有效数字）。
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
        if float(r.get('dmg', 0)) > 0:
            hp[str(f)] = int(sig3(float(r['dmg'])))
        if f <= 4:
            atk[str(f)] = 1
        elif float(r.get('enemyDmg', 0)) > 0 and float(r.get('partyHp', 0)) > 0:
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
    tables = build(load_rows(args.inputs))
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
    print('selftest 通过')
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('build')
    b.add_argument('--in', dest='inputs', action='append', required=True)
    b.add_argument('--write', action='store_true')
    sub.add_parser('selftest')
    args = ap.parse_args(argv)
    return cmd_build(args) if args.cmd == 'build' else selftest()


if __name__ == '__main__':
    sys.exit(main())
