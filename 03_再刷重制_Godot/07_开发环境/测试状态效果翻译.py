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
    def test_battle_tp_complete_measured_phase_tokens_only(self):
        wrap = lambda p, code: f'<Custom {p} Effect>{code}</Custom {p} Effect>'
        for amount in [200, 50]:
            body = f'user.gainTp({amount});'
            self.assertEqual(parse_state_effects(wrap('Battle', body)), [{'phase': 'battle', 'op': 'gain_resource', 'recipient': 'user', 'resource': 'tp', 'amount': amount, 'requires': ['resources']}])
            # Main's later measured gain grammar legitimately covers complete multi-step blocks.
            for code in [body + ';', body.replace('user', 'target'), body.replace(str(amount), 'user.atk'), body + 'evil();']:
                self.assertEqual(parse_state_effects(wrap('Battle', code))[0]['op'], 'js')
            for phase in ['Confirm', 'Turn Start']:
                self.assertEqual(parse_state_effects(wrap(phase, body))[0]['op'], 'js')
            for phase, code, resources in [('Battle', body + body, ['tp', 'tp']),
                                            ('Battle', body + 'user.gainHp(1);', ['tp', 'hp']),
                                            ('Battle', body.replace(str(amount), str(amount + 1)), ['tp']),
                                            ('Apply', body, ['tp'])]:
                effect = parse_state_effects(wrap(phase, code))[0]
                self.assertEqual(effect['op'], 'gain_steps')
                self.assertEqual([step['resource'] for step in effect['steps']], resources)
                self.assertTrue(all(step['program']['status'] == 'pure' for step in effect['steps']))
        # These two Apply blocks now have explicit event313/menu hosts and native operation fixtures.
        for amount in [25, 75]:
            effect = parse_state_effects(wrap('Apply', f'user.gainTp({amount});'))[0]
            self.assertEqual(effect['op'], 'gain_steps')
            self.assertEqual(len(effect['steps']), 1)
            self.assertEqual(effect['steps'][0]['resource'], 'tp')
            self.assertEqual(effect['steps'][0]['program']['steps'][-1]['value'], {'op': 'literal', 'pos': 8, 'value': amount})

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
        # 2544／2545（首把武器＋普攻）后来由 hook.weapon 量过、改写进 MEASURED_EFFECT_SOURCES，不再是 js（newsrc6 补正这条过期断言）
        for row in fixtures['query_pending']:
            self.assertEqual(next(e for e in parse_state_effects(row['note']) if e['phase'] == 'confirm')['op'], 'effect_program')


    def test_newsrc6_states(self):
        """v0.62.12 新增 15 个状态：Effect 块全部译成结构化效果（Custom Passive Condition 不是 Effect 块，这几个状态也不是被动）。"""
        rows = json.loads(FIXTURES.read_text())['newsrc6']
        self.assertEqual(len(rows), 15)
        want = {2720: ['effect_program', 'effect_program'], 2721: ['effect_program'], 2723: ['effect_program'], 2724: ['effect_program'],
                2747: ['effect_program'], 2748: ['effect_program'], 2750: ['effect_program'], 2751: ['effect_program'],
                2771: ['costume_image', 'costume_form_remove', 'value_steps'], 2772: ['costume_image', 'costume_form_remove', 'value_steps'],
                2773: ['costume_image', 'costume_form_remove', 'value_steps'], 2774: ['costume_image', 'costume_restore', 'value_steps'],
                2775: ['effect_program'], 2776: ['effect_program'], 2777: ['effect_program']}
        for row in rows:
            with self.subTest(state=row['state']):
                effects = parse_state_effects(row['note'])
                self.assertEqual([e['op'] for e in effects], want[row['state']])
                if row['state'] in (2771, 2772, 2773):
                    self.assertEqual(effects[1]['own'], row['state'])
                if row['state'] == 2774:
                    self.assertEqual(effects[1].get('addState'), 1)
        # 2777 靠换行补分号：改成一行就是语法错误，不能照翻
        note = next(r['note'] for r in rows if r['state'] == 2777)
        body = note.split('<Custom Confirm Effect>')[1].split('</Custom Confirm Effect>')[0]
        self.assertEqual(parse_state_effects('<Custom Confirm Effect>' + ' '.join(body.split()) + '</Custom Confirm Effect>')[0]['op'], 'js')
        # 换装 Remove 认自己的编号：把 2771 的块套在别的形态编号上就不认
        note = next(r['note'] for r in rows if r['state'] == 2771)
        self.assertEqual(parse_state_effects(note.replace('forms[2771]', 'forms[2770]'))[1]['op'], 'js')


if __name__ == '__main__':
    unittest.main()
