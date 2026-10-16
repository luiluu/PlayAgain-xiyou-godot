#!/usr/bin/env python3
"""对照工具防假通过回归；只用临时内存数据，不是游戏实现通过的证明。"""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '03_转换工具'))
from common_oracle_contract import compare_reports, case_map, verify_reports


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.ref = {'cases': [{'id': 'a', 'observed': {'trace': [5, 0], 'busy': True, 'cost': 2.5}, 'errors': []},
                              {'id': 'b', 'observed': {'skills': [1, 2]}, 'errors': []}]}
        self.actual = copy.deepcopy(self.ref)

    def test_exact_and_numeric_json_types(self):
        self.actual['cases'][0]['observed']['trace'][0] = 5.0
        self.assertTrue(compare_reports(self.ref, self.actual)['passed'])

    def test_boolean_is_not_integer(self):
        self.actual['cases'][0]['observed']['busy'] = 1
        self.assertFalse(compare_reports(self.ref, self.actual)['passed'])

    def test_nested_mutation_fails(self):
        self.actual['cases'][0]['observed']['trace'][1] = 1
        self.assertFalse(compare_reports(self.ref, self.actual)['passed'])

    def test_missing_case_fails(self):
        self.actual['cases'].pop()
        self.assertFalse(compare_reports(self.ref, self.actual)['passed'])

    def test_extra_case_fails(self):
        self.actual['cases'].append({'id': 'extra', 'observed': {}})
        self.assertFalse(compare_reports(self.ref, self.actual)['passed'])

    def test_duplicate_case_fails(self):
        self.actual['cases'].append(self.actual['cases'][0])
        with self.assertRaises(ValueError): case_map(self.actual)

    def test_nonfinite_fails(self):
        for value in [float('nan'), float('inf'), -float('inf')]:
            self.actual['cases'][0]['observed']['cost'] = value
            with self.assertRaises(ValueError): compare_reports(self.ref, self.actual)

    def test_errors_fail(self):
        self.actual['cases'][0]['errors'] = ['error']
        with self.assertRaises(ValueError): compare_reports(self.ref, self.actual)

    def test_missing_measurement_fails(self):
        del self.actual['cases'][0]['observed']
        with self.assertRaises(ValueError): case_map(self.actual)

    def test_float_absolute_tolerance(self):
        self.actual['cases'][0]['observed']['cost'] += 0.0000005
        self.assertTrue(compare_reports(self.ref, self.actual)['passed'])
        self.actual['cases'][0]['observed']['cost'] += 0.00001
        self.assertFalse(compare_reports(self.ref, self.actual)['passed'])

    def test_large_number_difference_not_hidden_by_relative_tolerance(self):
        self.ref['cases'][0]['observed']['cost'] = 10**15
        self.actual['cases'][0]['observed']['cost'] = 10**15 + 1
        self.assertFalse(compare_reports(self.ref, self.actual)['passed'])

    def test_partial_is_explicit(self):
        self.actual['cases'].pop()
        result = compare_reports(self.ref, self.actual, ['a'])
        self.assertTrue(result['passed']); self.assertTrue(result['partial'])
        with self.assertRaises(ValueError): compare_reports(self.ref, self.actual, ['absent'])

    def test_missing_reports_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(len(verify_reports(Path(directory), {})), 3)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner().run(suite)
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
