#!/usr/bin/env python3
"""YEP_X_ExtDoT 备注解析（xiyou_export.parse_ext_dot）对照 mv_oracle/dot_probe 的原版解析。

- 有 .sandbox/dot.json（探针产物）时：46 个真实状态逐个比对（有没有公式、动画、波动、元素、再生/伤害方向），
  合成备注 40 条比对动画与方向；没有就只跑自洽检查。
- tests/fixtures/ext_dot_syn.json（重制专项 xiyou_dot 用的合成状态记录）必须和转换器当前输出一致；
  `python3 测试ext_dot.py --write` 重新生成。
"""
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '03_转换工具'))
import xiyou_export as X

ORACLE = ROOT / '03_转换工具/mv_oracle/.sandbox/dot.json'
STATES = ROOT / '01_Godot工程/modes/xiyou/generated/db/States.json'
FIXTURE = ROOT / '01_Godot工程/tests/fixtures/ext_dot_syn.json'


def oracle_cases():
    if not ORACLE.exists():
        return {}
    return {c['id']: c['observed'] for c in json.load(open(ORACLE))['cases']}


def syn_records(syn):
    out = {}
    for i, (name, note) in enumerate(sorted(syn.items())):
        out[name] = {'note': note, 'dot': X.parse_ext_dot(note, 9000 + i)}
    return out


def last_healing(formula):
    found = re.findall(r'healing = (true|false)', formula or '')
    return found[-1] == 'true' if found else None


class ExtDotTests(unittest.TestCase):
    def test_defaults_match_plugin(self):
        oracle = oracle_cases().get('fixture')
        if not oracle:
            self.skipTest('没有 dot.json')
        d = oracle['defaults']
        self.assertEqual((X.EDOT_REGEN_ANI, X.EDOT_DOT_ANI, X.EDOT_VARIANCE, X.EDOT_ELEMENT), (d['regenAni'], d['dotAni'], d['variance'], d['element']))

    def test_real_states(self):
        oracle = oracle_cases().get('fixture')
        if not oracle or not STATES.exists():
            self.skipTest('没有 dot.json 或产物 States.json')
        table = json.load(open(STATES))
        X.EDOT_UNRESOLVED.clear()
        seen = 0
        for row in oracle['states']:
            sid = row['id']
            dot = X.parse_ext_dot(table[sid]['note'], sid)
            self.assertEqual(bool(row['formula']), dot is not None, sid)
            if not row['formula']:
                continue
            seen += 1
            self.assertEqual(dot['animation'], row['ani'], sid)
            self.assertEqual(dot['healing'], last_healing(row['formula']), sid)
            self.assertNotEqual(dot['kind'], 'unresolved', sid)
            if 'variance = ' not in row['formula']:
                self.assertEqual(dot['variance'], row['variance'], sid)
            if 'element = ' not in row['formula']:
                self.assertEqual(dot['element'], row['element'], sid)
        self.assertEqual(seen, 41)
        self.assertEqual(X.EDOT_UNRESOLVED, [])
        # 其余状态都没有公式（含备注写成「<DoT Formula:300>」少一个空格的 828、829、834、933）
        listed = {row['id'] for row in oracle['states']}
        for st in table:
            if st and st['id'] not in listed:
                self.assertIsNone(X.parse_ext_dot(st['note'], st['id']), st['id'])

    def test_syn_notes(self):
        oracle = oracle_cases()
        fix = oracle.get('fixture')
        if not fix:
            self.skipTest('没有 dot.json')
        records = syn_records(fix['syn'])
        for name, row in records.items():
            seen = oracle[f'syn.{name}']['enemy.0.5']
            dot = row['dot']
            self.assertEqual(dot is not None, bool(seen['formula']), name)
            if dot is None:
                continue
            self.assertEqual(dot['animation'], seen['ani'], name)
            self.assertEqual(dot['healing'], last_healing(seen['formula']), name)

    def test_fixture_fresh(self):
        saved = json.load(open(FIXTURE))
        oracle = oracle_cases().get('fixture')
        notes = oracle['syn'] if oracle else {k: v['note'] for k, v in saved.items()}
        self.assertEqual(syn_records(notes), saved, '合成状态夹具过期：python3 07_开发环境/测试ext_dot.py --write')

    def test_unresolved_reported(self):
        X.EDOT_UNRESOLVED.clear()
        dot = X.parse_ext_dot('<Custom DoT Formula>\nfor (var i = 0; i < 3; i++) { value += 1; }\n</Custom DoT Formula>', 777)
        self.assertEqual(dot['kind'], 'unresolved')
        self.assertEqual(X.EDOT_UNRESOLVED, [777])
        X.EDOT_UNRESOLVED.clear()

    def test_tag_edge_cases(self):
        p = lambda note: X.parse_ext_dot(note, 1)
        self.assertIsNone(p('<DoT Formula:300>'))  # 冒号后少一个空格，原版认不出
        self.assertIsNone(p('<DoT Variance: 50%>'))
        self.assertEqual(p('<dot formula: 300>')['animation'], 59)
        self.assertEqual(p('<Regenerate Formula: 5>')['animation'], 46)
        self.assertEqual(p('<Damage Over Time Formula: 5>')['healing'], False)
        self.assertEqual(p('<Regen Formula: 200>\n<DoT Formula: 300>')['healing'], False)  # 后写的覆盖，动画沿用先写的默认
        self.assertEqual(p('<Regen Formula: 200>\n<DoT Formula: 300>')['animation'], 46)
        self.assertEqual(p('<DoT Formula: 300>\n<DoT Variance: 50％>')['variance'], 50)
        self.assertEqual(p('<Custom DoT Formula>\nvalue = 300;\n</Custom DoT Formula>')['animation'], 0)  # 自定义块不补默认动画


if __name__ == '__main__':
    if '--write' in sys.argv:
        oracle = oracle_cases().get('fixture')
        if not oracle:
            sys.exit('需要先跑 mv_oracle/dot_probe.cjs 得到 .sandbox/dot.json')
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        json.dump(syn_records(oracle['syn']), open(FIXTURE, 'w'), ensure_ascii=False, indent=1, sort_keys=True)
        print('wrote', FIXTURE)
    else:
        unittest.main()
