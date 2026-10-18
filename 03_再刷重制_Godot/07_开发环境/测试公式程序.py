#!/usr/bin/env python3
"""Compiler boundaries and the checked-in native-JS oracle language fixtures."""
import json
from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / '03_转换工具'
sys.path.insert(0, str(TOOLS))
from formula_program import compile_formula


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
                       'a.param(1.9)', 'a.param(true)', 'a.param(null)']:
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


if __name__ == '__main__':
    unittest.main()
