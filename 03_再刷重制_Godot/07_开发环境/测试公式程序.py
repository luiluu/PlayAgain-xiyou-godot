#!/usr/bin/env python3
"""Compiler boundaries and the checked-in native-JS oracle language fixtures."""
import json
import copy
from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / '03_转换工具'
sys.path.insert(0, str(TOOLS))
from formula_program import compile_formula
from formula_effect_contract import CASE_IDS, validate_formula_effects, verify_formula_equipment, verify_formula_actions
from oracle_additions import compare_file


class FormulaCompilerTests(unittest.TestCase):
    def test_language_fixture_programs_do_not_drift(self):
        fixtures = json.loads((TOOLS / 'mv_oracle/shared/formula_language_cases.json').read_text())
        self.assertGreaterEqual(len(fixtures), 12)
        for row in fixtures:
            with self.subTest(row=row['id']):
                program = compile_formula(row['formula'], 0, row['custom'], 'LanguageFixture')
                self.assertEqual(program['status'], 'pure', program)
                self.assertEqual(program, row['program'])

    def test_if_statement_completion_value(self):
        """断天休 4450 的写法：if(...) {表达式} else {表达式} 作整条公式，完成值是所选分支的值。"""
        both = 'if(v[369] > 6) {(7125 + a.atk * 56)*(1+user.skillMasteryLevel(item.id))} else {(1125 + a.atk * 8)*(1+user.skillMasteryLevel(item.id))}'
        self.assertEqual(compile_formula(both, 4450)['status'], 'pure')
        self.assertEqual(compile_formula('if(a.atk > 1) {a.atk * 2} else if(a.def > 1) {a.def} else {1}', 1)['status'], 'pure')
        # 有一条路径没有表达式收尾（缺 else、块尾是声明）时完成值可能为空，仍拒收
        self.assertEqual(compile_formula('if(a.atk > 1) {a.atk * 2}', 1)['status'], 'unsupported')
        self.assertEqual(compile_formula('if(a.atk > 1) {a.atk * 2} else {var x = 1;}', 1)['status'], 'unsupported')

    def test_effect_fixtures_and_equipment_query_bounds(self):
        path = TOOLS.parent / '01_Godot工程/tests/fixtures/formula_effect_programs.json'
        for key, row in json.loads(path.read_text()).items():
            source = row['program']['source']
            self.assertEqual(row['program'], compile_formula(row['formula'], source['id'], source['custom'], source['table']))
        prefix = ('var baseEquipId=3640; let currentEquip=null; var equips=user.equips().filter((equip)=>!!equip && DataManager.isArmor(equip) && equip.baseItemId===baseEquipId); '
                  'if(equips.length>0)currentEquip=equips[0]; var mw=!!currentEquip?user.getEquipItemObject(currentEquip):null; var level=!!mw?mw.level():0; ')
        program = compile_formula(prefix + 'value=level+user.atk;', custom=True)
        self.assertEqual(program['status'], 'pure', program)
        self.assertIn('read.equipment_instance_level', program['capabilities'])
        for text in [prefix + 'value=mw;', prefix.replace('isArmor', 'isWeapon')+'value=level;',
                     prefix.replace('3640', '03640')+'value=level;', prefix.replace('equips[0]', 'equips[1]')+'value=level;',
                     prefix.replace('=>!!equip', '=>evil() && !!equip')+'value=level;']:
            self.assertEqual(compile_formula(text, custom=True)['status'], 'unsupported')

    def test_plan12_all_native_custom_blocks_and_branch_boundaries(self):
        """Actual frozen blocks, not a synthetic prefix standing in for coverage."""
        import hashlib
        reference = json.loads((TOOLS.parent / '01_Godot工程/tests/fixtures/formula_rest_oracle.json').read_text())
        expected = {857, 858, 1051, 1054, 1055, 1060, 1068, 2192, 2194, 2195,
                    2391, 2494, 4013, 4938, 4939, 4940, 4941, 5309, 5437, 5445,
                    5906, 5919, 7485, 7486, 7487, 7508, 8087, 10116, 10117, 10118, 10121}
        self.assertEqual({r['id'] for r in reference['inventory']}, expected)
        self.assertEqual(len(reference['inventory']), 31)
        for row in reference['inventory']:
            with self.subTest(skill=row['id']):
                self.assertEqual(hashlib.sha256(row['formula'].encode()).hexdigest(), row['sha256'])
                program = compile_formula(row['formula'], row['id'], custom=True)
                self.assertEqual(program['status'], 'effectful' if row['id'] in {857, 858, 4013} else 'pure', program)
        cases = reference['cases']
        expected_cases = set()
        for row in reference['inventory']:
            equipment = 'getEquipItemObject' in row['formula']
            branch = 'user.atk > target.atk' in row['formula']
            expected_cases.update(f"s{row['id']}.{mode}.{relation}"
                                  for mode in (('none', 'first', 'zero', 'nonmagic') if equipment else ('none',))
                                  for relation in ((-1, 0, 1) if branch else (0,)))
        self.assertEqual(len(expected_cases), 135)
        self.assertEqual({r['id'] for r in cases}, expected_cases)
        self.assertEqual(len(cases), len({r['id'] for r in cases}))
        self.assertEqual({r['setup']['skill'] for r in cases}, expected)
        for row in cases:
            self.assertFalse(row['errors'], row['id'])
            self.assertFalse(row['observed']['diagnostics'], row['id'])
        for sid in (2192, 2194, 2195, 2494):
            rows = [r for r in cases if r['setup']['skill'] == sid]
            self.assertEqual({(r['setup']['mode'], r['setup']['relation']) for r in rows},
                             {(mode, relation) for mode in ('none', 'first', 'zero', 'nonmagic') for relation in (-1, 0, 1)})

    def test_unknown_and_host_access_rejected_as_whole_program(self):
        for source in ['eval(1)', 'a.constructor()', 'a.hp=1; 0', 'v[0]=2;0', 'Math.unknown(2)',
                       'while(true){}',
                       'a[1]', 'new Object()', 'a.get(1)', 'Math.random(2)',
                       'function f(){}', 'a.hp; process.exit(0)', 'var a=2;value=1',
                       'let x=1;value=x', 'const x=1;value=x', '010', '-2**2', 'var true=1;5',
                       'a.states()===b.states()?99:1', '١+2', '1\u0085+2', '010.5', '00e1',
                       'var sign=-1;100', 'var arguments;5', 'var enum=1;5', 'var super=1;5',
                       'a.param(1.9)', 'a.param(true)', 'a.param(null)', '++2', '--2', '++v[1]', '--a.hp']:
            with self.subTest(source=source):
                p = compile_formula(source, custom=True)
                self.assertEqual(p['status'], 'unsupported', p)
                self.assertFalse(p['steps'])
                self.assertIn('line', p['diagnostic'])

    def test_effects_require_explicit_write_capability(self):
        p = compile_formula('var x=b.hp; b.gainHp(-3); if(x>2)b.gainMp(-1); value=b.hp;', custom=True)
        self.assertEqual(p['status'], 'effectful')
        self.assertTrue({'write.hp', 'write.mp'} <= set(p['capabilities']))
        for source in ['b.gainHp()', 'b.gainMp(1,2)', 'b.addShield()', 'b.addShield(1,2);value=0;', 'b.setHp(1);value=0;']:
            self.assertEqual(compile_formula(source, custom=True)['status'], 'unsupported')
        # ShieldSystem：addShield 要显式写能力，a.shield 只读
        p = compile_formula('b.addShield(Math.floor(a.mhp*0.2+a.shield)); 0')
        self.assertEqual((p['status'], p['capabilities']), ('effectful', ['read.battler', 'write.shield']))
        self.assertEqual(p['steps'][0]['value']['op'], 'shield')

    def test_production_random_ownership_guard(self):
        core = TOOLS.parent / '01_Godot工程/modes/xiyou'
        for name in ('battle/battle_logic.gd', 'battle/action_sequence.gd', 'core/damage.gd',
                     'core/gear.gd', 'core/gear_upgrade.gd', 'core/resource_context.gd', 'core/battler.gd'):
            source = (core / name).read_text()
            import re
            self.assertFalse(re.search(r'(?<![.\w])rand(?:f|i)(?:_range)?\s*\(', source), name)
        self.assertFalse((core / 'core/custom_damage.gd').exists())

    def test_source_identity_and_bounds(self):
        p = compile_formula('a.hp+1', 7)
        self.assertNotEqual(p['source']['sha256'], compile_formula('a.hp+2', 7)['source']['sha256'])
        self.assertEqual(p['source']['id'], 7)
        for source in ['(' * 100 + '1' + ')' * 100, '1+' * 5000 + '1', 'a' * 20000]:
            self.assertEqual(compile_formula(source)['status'], 'unsupported')


class FormulaReferenceGuardTests(unittest.TestCase):
    def fixture(self):
        slots = dict(hpAffected=False, hpDamage=0, mpDamage=0, tpDamage=0, success=False,
                     missed=False, evaded=False, critical=False, addedStates=[], removedStates=[])
        snap = dict(resources=[1, 1, 1], caps=[10, 10, 10], states=[], stateTurns={},
                    buffs=[0]*8, buffTurns=[0]*8, alive=True, dead=False, immortal=False, result=slots)
        identity = {'releaseVersion': 'v0.28', 'inputs': {'a': 'sha'}, 'runtimeInputs': {'js': 'sha'}}
        rows = []
        for key in CASE_IDS:
            count = 3 if key.startswith('eval.') else 4 if key.startswith('apply.') else 0
            journal = [dict(receiver='b', resource=('hp', 'mp', 'tp', 'hp')[i], requestedDelta=-1,
                            actualDelta=-1, before=copy.deepcopy(snap), after=copy.deepcopy(snap)) for i in range(count)]
            observed = dict(value=0, before=dict(a=copy.deepcopy(snap), b=copy.deepcopy(snap)),
                            after=dict(a=copy.deepcopy(snap), b=copy.deepcopy(snap)), journal=journal,
                            randomDraws=0, diagnostics=[], popup=[], formulaSHA256='a'*64)
            if key in ('language.before_write_error', 'language.after_write_error'):
                observed['diagnostics'] = [{'label': 'DAMAGE FORMULA ERROR', 'message': 'formula-read-fixture'}]
            rows.append(dict(id=key, setup={}, observed=observed, errors=[]))
        return dict(schemaVersion=1, hostScope='ordered-resource-reference-only', sourceIdentity=identity, cases=rows), identity

    def test_complete_source_only_contract(self):
        data, manifest = self.fixture()
        self.assertEqual(len(CASE_IDS), 112)
        self.assertFalse(validate_formula_effects(data, manifest))

    def test_equipment_and_reaction_reference_use_observation_map(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            identity = {'releaseVersion': 'v0.28', 'runtimeInputs': {}, 'inputs': {}}
            manifest = copy.deepcopy(identity)
            rows = []
            for sid in range(1, 25):
                for mode in ('none', 'wrong_kind', 'zero', 'high', 'first', 'different_base', 'nonmagic'):
                    for edge in (False, True):
                        rows.append(dict(id=f's{sid}.{mode}.{str(edge).lower()}', setup={'skill': sid}, errors=[], observed=dict(value=0, valueKind='finite', firstLevel=0, randomDraws=0, formulaSHA256='a'*64)))
            file = directory / 'formula_equipment.json'
            data = dict(sourceIdentity=identity, cases=rows)
            file.write_text(json.dumps(data))
            self.assertFalse(verify_formula_equipment(directory, manifest))
            rows[0]['errors'] = ['unexpected']
            file.write_text(json.dumps(data))
            self.assertTrue(verify_formula_equipment(directory, manifest))
            fixture, _ = self.fixture()
            snapshot = fixture['cases'][0]['observed']['after']['b']
            actions = [dict(id=f'{mode}.{values}', errors=[], observed={'after': {'b': snapshot}}) for mode in ('repeat', 'reflect', 'counter') for values in ('10000_220_123', '450_1_1')]
            file = directory / 'formula_actions.json'
            data = dict(sourceIdentity=identity, cases=actions)
            file.write_text(json.dumps(data))
            self.assertFalse(verify_formula_actions(directory, manifest))
            actions.pop()
            file.write_text(json.dumps(data))
            self.assertTrue(verify_formula_actions(directory, manifest))

    def test_missing_or_duplicate_source_case_and_incomplete_journal_rejected(self):
        original, manifest = self.fixture()
        for kind in ('missing', 'duplicate', 'journal', 'source_error', 'snapshot', 'identity'):
            data = copy.deepcopy(original)
            row = next(x for x in data['cases'] if x['id'].startswith('eval.'))
            if kind == 'missing': data['cases'].pop()
            if kind == 'duplicate': data['cases'].append(copy.deepcopy(row))
            if kind == 'journal': row['observed']['journal'].pop()
            if kind == 'source_error': row['errors'] = ['unexpected']
            if kind == 'snapshot': del row['observed']['after']['b']['caps']
            if kind == 'identity': data['sourceIdentity']['runtimeInputs'] = {'js': 'changed'}
            self.assertTrue(validate_formula_effects(data, manifest), kind)

    def test_enemy_context_additions_preserve_existing_measurements(self):
        row = dict(a={}, b={}, v={}, s={})
        old = dict(contexts={'full': row}, cases=[dict(id='s1', observed=1, errors=[])])
        new = copy.deepcopy(old)
        new['contexts']['enemy_actor.full'] = row
        new['cases'].append(dict(id='s1.enemy_actor.full', observed=2, errors=[]))
        additions, bad = compare_file('formula_programs.json', old, new)
        self.assertEqual(len(additions), 2)
        self.assertFalse(bad)
        new['contexts']['full']['v']['1'] = 3
        self.assertTrue(compare_file('formula_programs.json', old, new)[1])


if __name__ == '__main__':
    unittest.main()
