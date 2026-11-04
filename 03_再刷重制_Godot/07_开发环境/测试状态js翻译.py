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


class Batch2TranslationTests(unittest.TestCase):
    """第二批：开战／回合开始加状态、暴击后加状态、开战／胜利／附加时回复、开战设变量、原版语法错误块。"""
    rows = json.loads(FIXTURES.read_text())['batch2']

    def ops(self):
        out = {}
        for row in self.rows:
            for e in parse_state_effects(row['note']):
                if e['op'] in ('add_state', 'gain_steps', 'gain_resource', 'set_variable', 'syntax_error'):
                    out.setdefault(e['op'], []).append((row['state'], e))
        return out

    def test_inventory(self):
        ops = self.ops()
        self.assertEqual({k: len(v) for k, v in ops.items()},
                         {'add_state': 23, 'gain_steps': 8, 'gain_resource': 3, 'set_variable': 4, 'syntax_error': 9})
        self.assertEqual(sorted(s for s, _ in ops['gain_steps']), [79, 630, 734, 735, 736, 917, 1334, 1336])
        self.assertEqual(sorted((s, e['resource'], e['amount'], e['requires']) for s, e in ops['gain_resource']),
                         [(607, 'tp', 200, ['resources']), (609, 'tp', 200, ['resources']), (857, 'tp', 50, ['resources'])])
        self.assertEqual(sorted((s, e['id']) for s, e in ops['set_variable']), [(1351, 1176), (1683, 1683), (1733, 966), (2560, 1597)])
        self.assertEqual(sorted(s for s, _ in ops['syntax_error']), [1070, 1351, 1352, 1635, 1636, 1669, 1671, 1747, 2045])
        for s, e in ops['add_state']:
            self.assertEqual(e.get('criticalOnly', False), e['phase'] == 'establish', s)
        for s, e in ops['gain_steps']:
            for step in e['steps']:
                self.assertEqual(step['program']['status'], 'pure')
                self.assertLessEqual(set(step['program']['capabilities']), {'read.battler'})

    def test_add_state_boundaries(self):
        self.assertEqual(one('Battle', 'user.addState(12);'), {'phase': 'battle', 'op': 'add_state', 'who': 'user', 'id': 12})
        self.assertEqual(one('Turn Start', 'user.addState(12)')['op'], 'add_state')
        for tag, code in [('Turn End', 'user.addState(12);'), ('Battle', 'target.addState(12);'), ('Battle', 'user.addState(12, 3);'),
                          ('Battle', 'user.addState(12); user.addState(13);'), ('Battle', 'user.removeState(12);'),
                          ('Battle', 'user.addState(v[12]);'), ('Victory', 'user.addState(12);')]:
            with self.subTest(code=code):
                self.assertEqual(one(tag, code)['op'], 'js')

    def test_critical_boundaries(self):
        ok = 'if (target.result().critical) { var param = 500; var turns = 3; user.addState(param, turns); }'
        self.assertEqual(one('Establish', ok), {'phase': 'establish', 'op': 'add_state', 'who': 'user', 'id': 500, 'criticalOnly': True})
        self.assertEqual(one('Establish', ok.replace('user.', 'target.'))['who'], 'target')
        for code in [ok.replace('critical', 'missed'), ok.replace('target.result', 'user.result'), ok.replace('param, turns', 'param'),
                     ok.replace('var turns = 3; ', ''), ok + ' user.gainHp(1);', ok.replace('if (', 'if (!')]:
            with self.subTest(code=code):
                self.assertEqual(one('Establish', code)['op'], 'js')
        self.assertEqual(one('Respond', ok)['op'], 'js')

    def test_set_variable_and_gain_boundaries(self):
        self.assertEqual(one('Battle', '$gameVariables.setValue(5, 2);'), {'phase': 'battle', 'op': 'set_variable', 'id': 5, 'value': 2})
        for tag, code in [('Turn Start', '$gameVariables.setValue(5, 2);'), ('Battle', '$gameVariables.setValue(5, user.atk);'),
                          ('Battle', '$gameVariables.setValue(5, -2);'), ('Battle', '$gameSwitches.setValue(5, true);')]:
            with self.subTest(code=code):
                self.assertEqual(one(tag, code)['op'], 'js')
        self.assertEqual(one('Battle', 'user.gainTp(200);'), {'phase': 'battle', 'op': 'gain_resource', 'recipient': 'user', 'resource': 'tp', 'amount': 200, 'requires': ['resources']})
        self.assertEqual(one('Battle', 'user.gainTp(201);')['steps'][0]['resource'], 'tp')
        self.assertEqual(len(one('Victory', 'var rate = 0.2; var value = Math.ceil(user.mhp * rate); user.gainHp(value);')['steps']), 1)
        for tag, code in [('Turn End', 'user.gainTp(200);'), ('Battle', 'target.gainHp(5);'), ('Battle', 'user.gainHp(user.atk);'),
                          ('Battle', 'user.gainHp(Math.random());'), ('Battle', 'user.gainHp(v[3]);'), ('Battle', 'user.gainTp(200); evil();'),
                          ('Battle', 'user.setHp(5);'), ('Battle', 'var x = user.mhp; target.gainHp(x);')]:
            with self.subTest(code=code):
                self.assertEqual(one(tag, code)['op'], 'js')

    def test_syntax_error_exact(self):
        for row in self.rows:
            for m in EFFECT_RE.finditer(row['note']):
                if parse_state_effects(m.group(0))[0]['op'] != 'syntax_error':
                    continue
                with self.subTest(state=row['state']):
                    tag = m.group(1)
                    # 任何改动（哪怕补一个空格以外的字符）都不再按测过的报错块认
                    self.assertEqual(one(tag, m.group(2) + ';')['op'], 'js')


class CounterTranslationTests(unittest.TestCase):
    """第三批：YEP 状态计数 _stateCounter（附加时取变量、1763 开战取 MP）。"""
    rows = json.loads(FIXTURES.read_text())['counter']

    def test_inventory(self):
        ops = [(row['state'], e) for row in self.rows for e in parse_state_effects(row['note']) if e['op'].startswith('counter')]
        init = sorted(s for s, e in ops if e['op'] == 'counter_init')
        self.assertEqual(init, [1775, 1781, 1782, 1783, 1784, 1785, 1786] + list(range(1792, 1808)))
        for s, e in ops:
            self.assertEqual(e['state'], s)  # 每块都只写自己的计数
        self.assertEqual([s for s, e in ops if e['op'] == 'counter_set'], [1763])

    def test_boundaries(self):
        ok = 'user._stateCounter[5] = user._stateCounter[5] || $gameVariables.value(9);'
        self.assertEqual(one('Apply', ok), {'phase': 'apply', 'op': 'counter_init', 'state': 5, 'variable': 9})
        for tag, code in [('Remove', ok), ('Apply', ok.replace('[5] ||', '[6] ||')), ('Apply', ok.replace('||', '&&')),
                          ('Apply', ok.replace('user.', 'target.')), ('Apply', ok + ' user.refresh();'),
                          ('Apply', ok.replace('$gameVariables.value(9)', '9'))]:
            with self.subTest(code=code):
                self.assertEqual(one(tag, code)['op'], 'js')
        battle = 'user._stateCounter[7] = user._stateCounter[7] || 0; user._stateCounter[7] = Math.floor(user.mp * 0.3);'
        self.assertEqual(one('Battle', battle)['op'], 'counter_set')
        for tag, code in [('Apply', battle), ('Battle', battle.replace('user.mp', 'user.atk')), ('Battle', battle.replace('Math.floor', 'Math.round')),
                          ('Battle', battle.replace('[7] = Math', '[8] = Math'))]:
            with self.subTest(code=code):
                self.assertEqual(one(tag, code)['op'], 'js')


class ShieldTranslationTests(unittest.TestCase):
    """rules2 护盾一族：整段 token 比对，只有元素号与动画号可变；改一个记号就退回 js。"""
    body = ('if (this.isHpEffect() && value > 0) { var elements = this.getItemElements(); var lightningElementId = 8; '
            'if (!elements.contains(lightningElementId)) { value = 0; } target.startAnimation(204); target.removeState(stateId); }')

    def test_exact(self):
        self.assertEqual(one('React', self.body), {'phase': 'react', 'op': 'value_query', 'query': 'element_contains', 'element': 8,
                                                   'present': False, 'remove_self': True, 'animation': 204})
        self.assertEqual(one('React', '// 注释\n' + self.body.replace('8;', '10;').replace('204', '241'))['animation'], 241)
        self.assertEqual(one('Remove', 'user._bubbleWrapCooldown = 3;'), {'phase': 'remove', 'op': 'noop', 'reason': 'bubble_wrap_cooldown_unread'})

    def test_boundaries(self):
        b = self.body
        for tag, code in [('Confirm', b), ('React', b.replace('!elements', 'elements')), ('React', b.replace('removeState(stateId)', 'removeState(105)')),
                          ('React', b.replace('value = 0', 'value = 1')), ('React', b.replace('= 8;', '= 0;')), ('React', b.replace('= 8;', '= v;')),
                          ('React', b.replace('target.startAnimation', 'user.startAnimation')), ('React', b + ' user.gainHp(1);'),
                          ('React', b.replace(' target.startAnimation(204);', '')), ('React', b.replace('value > 0', 'value >= 0'))]:
            with self.subTest(tag=tag, code=code[-80:]):
                self.assertEqual(one(tag, code)['op'], 'js')
        for tag, code in [('Apply', 'user._bubbleWrapCooldown = 3;'), ('Remove', 'user._bubbleWrapCooldown = 2;'),
                          ('Remove', 'target._bubbleWrapCooldown = 3;'), ('Remove', 'user._bubbleWrapCooldown = 3; user.gainHp(1);')]:
            with self.subTest(tag=tag, code=code):
                self.assertEqual(one(tag, code)['op'], 'js')


class ReviveTranslationTests(unittest.TestCase):
    """rules3 自动复活一族：条件与每一步整句比对；有一句不认识、条件改了就退回 js。"""
    body = 'if (target.hp <= 0 && Math.random() > 0.60 || target.isDead() && Math.random() > 0.60 ) { target.gainHp(target.mhp); target.gainMp(target.mmp); target.gainTp(target.tp); target.startDamagePopup(); target.clearResult(); }'

    def test_exact(self):
        got = one('Deselect', self.body)
        self.assertEqual(got['op'], 'revive')
        self.assertEqual(got['cond'], {'kind': 'down_each', 'above': 0.6})
        self.assertEqual([s['do'] for s in got['steps']], ['gain', 'gain', 'gain', 'popup', 'clear_result'])
        auto = one('Deselect', 'if (target.hp <= 0 || target.isDead()) { target.startAnimation(49); var rate = 0.50; var heal = Math.floor(target.mhp * rate); target.removeState(stateId); target.gainHp(heal); target.startDamagePopup(); target.clearResult(); }')
        self.assertEqual(auto['steps'][:3], [{'do': 'animation', 'id': 49}, {'do': 'remove_self'}, {'do': 'gain', 'resource': 'hp', 'param': 'mhp', 'rate': 0.5, 'round': 'floor'}])
        var = one('Deselect', 'if (target.hp <= 0 && $gameVariables.value(966) > 1) { target.gainHp(1); $gameVariables.setValue(966,$gameVariables.value(966)-1); }')
        self.assertEqual(var['cond'], {'kind': 'hp_zero_variable', 'variable': 966, 'above': 1})
        self.assertEqual(var['steps'][1], {'do': 'add_variable', 'id': 966, 'delta': -1})

    def test_boundaries(self):
        b = self.body
        for tag, code in [('Select', b), ('Deselect', b.replace('> 0.60 ||', '> 0.50 ||')), ('Deselect', b.replace('target.gainTp(target.tp)', 'target.gainTp(user.tp)')),
                          ('Deselect', b.replace('target.clearResult();', 'user.clearResult();')), ('Deselect', b.replace('target.clearResult();', 'target.clearResult(); BattleManager.queueForceAction(target, 7303, -2);')),
                          ('Deselect', 'if (target.hp <= 0 || target.isDead()) { $gameTemp.reserveCommonEvent(1515); }'),
                          ('Deselect', 'if (target.hp <= 0) { target.gainHp(1); }'),
                          ('Deselect', 'if (target.hp <= 0 && $gameVariables.value(966) > 1) { $gameVariables.setValue(966,$gameVariables.value(967)-1); }')]:
            with self.subTest(tag=tag, code=code[-70:]):
                self.assertEqual(one(tag, code)['op'], 'js')


class EffectBlockTranslationTests(unittest.TestCase):
    """rules4 伤害一族：整块白名单，改一个记号就退回 js；只写没人读字段的块译成 noop。"""
    popup = 'if (value > 0 && this.isHpEffect()) { target.gainHp(-value); target.startDamagePopup(); target.removeState(960); }'
    loop = ('var cishu = $gameVariables.value(1174); if(cishu >= 10){ cishu = 10} if (value > 0 && this.isMagical() || this.isPhysical()) { '
            'for(var i = 0;i <= cishu;i++){ var bonus = Math.random() * 0.4 - 0.2; value += Math.round(value * bonus); target.gainHp(-value); target.startDamagePopup(); target.clearResult(); } } '
            '$gameVariables.setValue(1174,0);')

    def test_exact(self):
        got = one('Establish', self.popup)
        self.assertEqual(got['op'], 'effect_program')
        self.assertEqual(got['program']['status'], 'effectful')
        self.assertEqual(one('Establish', self.loop)['op'], 'effect_program')
        shield = one('Apply', 'user._Shield = user._Shield || 0; user._Shield += user.mhp * 10;')
        self.assertEqual(shield['op'], 'effect_program')
        self.assertIn('f_a_Shield', shield['program']['locals'])
        self.assertEqual(one('Battle', 'user.jqsbt = 0;'), {'phase': 'battle', 'op': 'noop', 'reason': 'unread_field'})

    def test_boundaries(self):
        p = self.popup
        for tag, code in [('Confirm', p), ('Establish', p.replace('960', '961')), ('Establish', p.replace('value > 0', 'value >= 0')),
                          ('Establish', p.replace('target.gainHp', 'user.gainHp')), ('Establish', p.replace(' target.startDamagePopup();', '')),
                          ('Establish', self.loop.replace('<= cishu', '< cishu')), ('Turn End', 'user.jqsbt = 0;'),
                          ('Battle', 'user.jqsbt = 1;'), ('Apply', 'user._Shield = 5;')]:
            with self.subTest(tag=tag, code=code[-70:]):
                self.assertEqual(one(tag, code)['op'], 'js')


class HookBlockTranslationTests(unittest.TestCase):
    """rules5：原文整块比对后换成等价写法；改一句就退回 js。"""
    bond = 'if(target.hp<=0||target.isDead()){ var targets = user.friendsUnit().aliveMembers(); for(var a=0 ;a < targets.length ; a++){ var tar = targets[a]; tar.removeState(1451); } }'

    def test_exact(self):
        got = one('Respond', self.bond)
        self.assertEqual(got['op'], 'effect_program')
        self.assertEqual(one('Remove', 'target._isMarked = false;')['op'], 'noop')
        self.assertEqual(one('React', 'if (this.isDamageAffected()) { if (Math.random() < 0.5) { BattleManager.queueForceAction(user, 5577, target.index()); } }')['reason'], 'no_effect')

    def test_boundaries(self):
        for tag, code in [('Confirm', self.bond), ('Respond', self.bond.replace('1451', '1452')), ('Respond', self.bond.replace('user.friendsUnit', 'target.friendsUnit')),
                          ('Remove', 'target._isMarked = true;'), ('React', 'if (this.isDamageAffected()) { BattleManager.queueForceAction(user, 5577, target.index()); }')]:
            with self.subTest(tag=tag, code=code[-70:]):
                self.assertEqual(one(tag, code)['op'], 'js')


class RestBlockTranslationTests(unittest.TestCase):
    """rules6：换装模板只有图名可变；预约、必爆、金币、再生整块比对，改一句就退回 js。"""
    apply = "if (user.isActor()) { user._prevBattlerName = user._prevBattlerName || user._battlerName; var battlerName = 'abc'; user.setBattlerImage(battlerName); user.refresh(); }"
    remove = 'var battlerName = user._prevBattlerName; user.setBattlerImage(battlerName); user._priorityBattlerName = undefined; user._prevBattlerName = undefined; user.refresh();'

    def test_exact(self):
        self.assertEqual(one('Apply', self.apply), {'phase': 'apply', 'op': 'costume_image', 'image': 'abc'})
        self.assertEqual(one('Remove', self.remove), {'phase': 'remove', 'op': 'costume_restore'})
        self.assertEqual(one('React', 'if (value >= 0) { $gameTemp.reserveCommonEvent(1605) }')['op'], 'effect_program')
        self.assertEqual(one('Victory', '$gameParty.gainGold(-$gameVariables.value(980) * 100);')['op'], 'effect_program')

    def test_boundaries(self):
        for tag, code in [('Remove', self.apply), ('Apply', self.remove), ('Apply', self.apply.replace('user.isActor()', 'user.isEnemy()')),
                          ('Apply', self.apply + ' user.gainHp(1);'), ('Remove', self.remove.replace('_priorityBattlerName', '_other')),
                          ('React', 'if (value >= 0) { $gameTemp.reserveCommonEvent(1606) }'), ('Confirm', 'if (value >= 0) { $gameTemp.reserveCommonEvent(1605) }'),
                          ('Victory', '$gameParty.gainGold(-$gameVariables.value(981) * 100);')]:
            with self.subTest(tag=tag, code=code[-60:]):
                self.assertEqual(one(tag, code)['op'], 'js')


if __name__ == '__main__':
    unittest.main()
