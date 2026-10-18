#!/usr/bin/env python3
"""对照工具防假通过回归；只用临时内存数据，不是游戏实现通过的证明。"""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '03_转换工具'))
from common_oracle_contract import compare_reports, case_map, verify_reports, identity_issues
from battle_event_contract import CASE_IDS, validate_battle_events, verify_battle_events


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

    def test_identity_changes_fail(self):
        manifest = {'releaseVersion': 'v0.28', 'runtimeInputs': {'js/main.js': 'runtime-sha'}, 'inputs': {'data/Items.json': 'data-sha', 'package.json': 'version-sha'}}
        self.assertFalse(identity_issues('test', manifest, manifest))
        for key, value in [('releaseVersion', 'v0.29'), ('runtimeInputs', {}), ('inputs', {})]:
            wrong = copy.deepcopy(manifest); wrong[key] = value
            self.assertTrue(identity_issues('test', wrong, manifest))

    def test_non_object_root_fails(self):
        with self.assertRaises(ValueError): case_map([])


class BattleEventContractTests(unittest.TestCase):
    """只验证参照传输/完整性；数值与时机由真实 MV 探针的断言验证。"""

    def setUp(self):
        self.manifest = {'releaseVersion': 'v0.28', 'runtimeInputs': {'js/main.js': 'runtime-sha'},
                         'inputs': {'data/Troops.json': 'troop-sha', 'package.json': 'version-sha'}}
        self.ref = {'schemaVersion': 1, 'hostScope': 'headless-rule-timing',
                    'sourceIdentity': copy.deepcopy(self.manifest),
                    'scan': {'troops': [{'id': i + 1, 'pages': [{}] * (2 if i < 12 else 1)}
                                         for i in range(35)],
                             'maps': [], 'commonEvents': [], 'commonEventCallers': [], 'unresolvedBattles': []},
                    'cases': [{'id': case_id, 'errors': [], 'observed': {'turn': 4}}
                              for case_id in sorted(CASE_IDS)]}
        next(c for c in self.ref['cases'] if c['id'] == 'scan.inventory')['observed'] = {'troops': 35, 'pages': 47}

    def test_complete_transport_contract(self):
        self.assertEqual(len(self.ref['cases']), 8)
        self.assertFalse(validate_battle_events(self.ref, self.manifest))

    def test_missing_extra_duplicate_and_nonfinite_measurements_fail(self):
        for mutation in ['missing', 'extra', 'duplicate', 'nonfinite']:
            with self.subTest(mutation=mutation):
                data = copy.deepcopy(self.ref)
                if mutation == 'missing':
                    data['cases'].pop()
                elif mutation == 'extra':
                    data['cases'].append({'id': 'unregistered', 'errors': [], 'observed': {}})
                elif mutation == 'duplicate':
                    data['cases'].append(copy.deepcopy(data['cases'][0]))
                else:
                    data['cases'][0]['observed']['turn'] = float('nan')
                self.assertTrue(validate_battle_events(data, self.manifest))

    def test_failed_or_unreported_measurements_fail(self):
        for value in [['source exception'], None]:
            data = copy.deepcopy(self.ref)
            if value is None:
                del data['cases'][0]['errors']
            else:
                data['cases'][0]['errors'] = value
            self.assertTrue(validate_battle_events(data, self.manifest))

    def test_inventory_not_replaceable_by_an_empty_scan(self):
        for alteration in ['missing', 'empty', 'duplicate']:
            data = copy.deepcopy(self.ref)
            if alteration == 'missing':
                del data['scan']
            elif alteration == 'empty':
                data['scan']['troops'] = []
            else:
                data['scan']['troops'][0]['id'] = data['scan']['troops'][1]['id']
            self.assertTrue(validate_battle_events(data, self.manifest))

    def test_changed_source_or_host_contract_fails(self):
        for key, value in [('releaseVersion', 'v0.29'), ('runtimeInputs', {}), ('inputs', {})]:
            data = copy.deepcopy(self.ref)
            data['sourceIdentity'][key] = value
            self.assertTrue(validate_battle_events(data, self.manifest))
        for key, value in [('schemaVersion', True), ('hostScope', 'gameplay-implemented')]:
            data = copy.deepcopy(self.ref)
            data[key] = value
            self.assertTrue(validate_battle_events(data, self.manifest))

    def test_absent_corrupt_and_wrong_root_fail_at_file_entry(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            self.assertTrue(verify_battle_events(directory, self.manifest))
            file = directory / 'battle_events.json'
            for body in ['{broken', '[]', '{"cases":[]}']:
                file.write_text(body)
                self.assertTrue(verify_battle_events(directory, self.manifest))
            file.write_text(json.dumps(self.ref))
            self.assertFalse(verify_battle_events(directory, self.manifest))


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner().run(suite)
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
