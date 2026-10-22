#!/usr/bin/env python3
"""Native state-block coverage and strict whole-block translation boundaries."""
import json
from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / '03_转换工具'
sys.path.insert(0, str(TOOLS))
from xiyou_export import parse_state_effects, EFFECT_RE

FIXTURES = TOOLS.parent / '01_Godot工程/tests/fixtures/state_effects_translation.json'


class StateEffectTranslationTests(unittest.TestCase):
    def test_native_bonus_inventory(self):
        rows = json.loads(FIXTURES.read_text())['bonus']
        self.assertEqual(len(rows), 28)
        for row in rows:
            with self.subTest(state=row['state']):
                ops = [e for e in parse_state_effects(row['note']) if e['phase'] == 'confirm']
                self.assertEqual(len(ops), 1)
                self.assertEqual(ops[0]['op'], 'value_steps')

    def test_unknown_or_malformed_suffix_never_partly_translates(self):
        rows = json.loads(FIXTURES.read_text())['bonus']
        for row in rows:
            body = row['note'].split('<Custom Confirm Effect>')[1].split('</Custom Confirm Effect>')[0]
            for code in [body + ' user.gainMp(-1);', 'evil();' + body,
                         body.replace('value +=', 'val ue +='),
                         body.replace('Math.ceil', 'Math.ce il'),
                         body.replace('value *', 'value **')]:
                with self.subTest(state=row['state'], code=code[-100:]):
                    self.assertEqual(parse_state_effects('<Custom Confirm Effect>' + code + '</Custom Confirm Effect>')[0]['op'], 'js')

    def test_only_measured_shapes_and_phases_translate(self):
        body = 'if (this.isHpEffect() && value > 0) { var finalRate = 0.5; value += Math.ceil(value * finalRate); }'
        for code in [body.replace('> 0', '>= 0'), body.replace('this.isHpEffect()', 'this.isMpEffect()'),
                     body.replace('0.5', 'user.atk'), body.replace('finalRate', 'otherRate'),
                     body.replace('Math.ceil', 'Math.floor'), body + body]:
            self.assertEqual(parse_state_effects('<Custom Confirm Effect>' + code + '</Custom Confirm Effect>')[0]['op'], 'js')
        self.assertEqual(parse_state_effects('<Custom Apply Effect>' + body + '</Custom Apply Effect>')[0]['op'], 'js')

    def test_native_value_inventory(self):
        rows = json.loads(FIXTURES.read_text())['value']
        self.assertEqual(len(rows), 35)
        for row in rows:
            with self.subTest(state=row['state']):
                effect = next(e for e in parse_state_effects(row['note']) if e['phase'] == row['phase'])
                self.assertEqual(effect['op'], 'value_program')
                self.assertEqual(effect['program']['status'], 'pure')
                self.assertFalse(any(c.startswith('write.') for c in effect['program']['capabilities']))

    def test_native_value_whole_token_boundary(self):
        for row in json.loads(FIXTURES.read_text())['value']:
            body = next(m.group(2) for m in EFFECT_RE.finditer(row['note']) if m.group(1).lower() == row['phase'])
            tag = row['phase'].title()
            for code in [body + ' user.gainMp(-1);', 'evil();' + body, body + body,
                         body.replace('value', 'val ue'), body.replace('Math.', 'Ma th.') if 'Math.' in body else body + ';']:
                with self.subTest(state=row['state']):
                    self.assertEqual(parse_state_effects('<Custom ' + tag + ' Effect>' + code + '</Custom ' + tag + ' Effect>')[0]['op'], 'js')
            wrong = 'Confirm' if tag == 'React' else 'React'
            self.assertEqual(parse_state_effects('<Custom ' + wrong + ' Effect>' + body + '</Custom ' + wrong + ' Effect>')[0]['op'], 'js')

    def test_legacy_ops_remain_exact(self):
        fixtures = json.loads(FIXTURES.read_text())
        self.assertEqual(sum(len(r['effects']) for r in fixtures['legacy']), 127)
        # Native source notes are separately captured so this protects the old output contract.
        for row in fixtures['legacy']:
            with self.subTest(state=row['state']):
                got = [e for e in parse_state_effects(row['note']) if e['op'] in ('mul', 'user_param_damage')]
                self.assertEqual(got, row['effects'])

    def test_native_query_complete_blocks(self):
        fixtures = json.loads(FIXTURES.read_text())
        self.assertEqual(len(fixtures['query']), 4)
        for row in fixtures['query']:
            effect = next(e for e in parse_state_effects(row['note']) if e['phase'] == row['phase'])
            self.assertEqual(effect['op'], 'value_query')
            body = next(m.group(2) for m in EFFECT_RE.finditer(row['note']) if m.group(1).lower() == row['phase'])
            tag = row['phase'].title()
            for code in [body + ';', body + ' user.gainHp(1);', 'evil();' + body, body + body,
                         body.replace('value', 'val ue'), body.replace('1.5', '1.6') if '1.5' in body else body.replace('0.2', '0.3') if '0.2' in body else body.replace('1', '2')]:
                self.assertEqual(parse_state_effects('<Custom ' + tag + ' Effect>' + code + '</Custom ' + tag + ' Effect>')[0]['op'], 'js')
            wrong = 'Confirm' if tag == 'React' else 'React'
            self.assertEqual(parse_state_effects('<Custom ' + wrong + ' Effect>' + body + '</Custom ' + wrong + ' Effect>')[0]['op'], 'js')
        for row in fixtures['query_pending']:
            self.assertEqual(next(e for e in parse_state_effects(row['note']) if e['phase'] == 'confirm')['op'], 'js')


if __name__ == '__main__':
    unittest.main()
