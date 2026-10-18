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
from formula_effect_contract import CASE_IDS, validate_formula_effects
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

    def test_unknown_and_host_access_rejected_as_whole_program(self):
        for source in ['eval(1)', 'a.constructor()', 'a.hp=1; 0', 'v[0]=2;0', 'Math.unknown(2)',
                       'a.gainHp(-3);0', 'value=2; b.gainMp(-1);', 'while(true){}',
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
