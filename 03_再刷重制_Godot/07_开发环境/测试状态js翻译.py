#!/usr/bin/env python3
"""状态效果 js 再翻译（云端车道）的整块边界：只认原版测过的完整形状，改一个记号就退回 js。"""
import json
import re
from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / '03_转换工具'
sys.path.insert(0, str(TOOLS))
from xiyou_export import parse_state_effects, EFFECT_RE

FIXTURES = TOOLS.parent / '01_Godot工程/tests/fixtures/state_js_translation.json'
# 原文本身报错（读装备等级的 106／732、变量名拼成 damag 的 551）：不翻译
POISON_JS = {106, 551, 732}


def block(note, phase):
    return next(m.group(2) for m in EFFECT_RE.finditer(note) if m.group(1).lower() == phase)


def one(tag, code):
    return parse_state_effects('<Custom %s Effect>%s</Custom %s Effect>' % (tag, code, tag))[0]


class PoisonTranslationTests(unittest.TestCase):
    rows = json.loads(FIXTURES.read_text())['poison']

    def test_inventory(self):
        self.assertEqual(len(self.rows), 18)
        for row in self.rows:
            with self.subTest(state=row['state']):
                ops = {e['phase']: e for e in parse_state_effects(row['note'])}
                self.assertEqual(ops['apply']['op'], 'poison_stack')
                self.assertEqual(ops['apply']['mode'], 'add')
                self.assertEqual(ops['remove'], {'phase': 'remove', 'op': 'poison_stack', 'mode': 'reset'})
                want = 'js' if row['state'] in POISON_JS else 'poison_tick'
                self.assertEqual(ops['regenerate']['op'], want)
                if want == 'poison_tick':
                    program = ops['regenerate']['program']
                    self.assertEqual(program['status'], 'pure')
                    self.assertEqual(program['capabilities'], ['read.battler'])

    def test_apply_remove_boundaries(self):
        body = block(self.rows[0]['note'], 'apply')
        for code in [body + ' user.gainMp(-1);', body.replace('|| 0', '|| 1'), body.replace('+= 1', '+= user.atk'),
                     body.replace('target._stackingPoison +=', 'user._stackingPoison +='), body.replace('+= 1', '-= 1')]:
            with self.subTest(code=code[-80:]):
                self.assertEqual(one('Apply', code)['op'], 'js')
        self.assertEqual(one('Remove', 'target._stackingPoison = 1;')['op'], 'js')
        self.assertEqual(one('Remove', 'user._stackingPoison = 0;')['op'], 'js')
        self.assertEqual(one('Turn End', 'target._stackingPoison = 0;')['op'], 'js')
        self.assertEqual(one('Apply', block(self.rows[0]['note'], 'remove'))['op'], 'js')

    def test_regenerate_boundaries(self):
        for row in self.rows:
            if row['state'] in POISON_JS:
                continue
            body = block(row['note'], 'regenerate')
            for code in [body + ' user.gainMp(-1);', 'evil();' + body,
                         body.replace('target.gainHp(-damage)', 'target.gainHp(damage)'),
                         body.replace('origin.', 'target.', 1),
                         body.replace('var damage =', 'var damage = Math.random() +'),
                         body.replace('target.isDead()', 'target.isAlive()'),
                         body.replace('|| 1', '|| 2'),
                         # 同一行接 var：原版是语法错误（靠换行补分号）
                         re.sub(r'(var stacks = target\._stackingPoison)[ \t]*\r?\n(?:[ \t]*//[^\n]*\n)*', r'\1 ', body)]:
                with self.subTest(state=row['state'], code=code[-90:]):
                    self.assertEqual(one('Regenerate', code)['op'], 'js')
            self.assertEqual(one('Turn End', body)['op'], 'js')


if __name__ == '__main__':
    unittest.main()
