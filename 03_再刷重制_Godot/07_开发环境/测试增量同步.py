"""Temporary fixtures only: cache invalidation, failed output protection, and owned task lifecycle."""
import contextlib
import copy
import importlib.util
import io
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent / '03_转换工具'
sys.path.insert(0, str(TOOLS))
from incremental_sync import ProbeCache
import oracle_additions


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


sync = load('incremental_sync_runner_tests', TOOLS / '同步正式西游.py')


class AcceptedBaselineTests(unittest.TestCase):
    """真实 Node／ProbeCache 和同步入口；只把转换、来源核验及导入换成临时夹具。"""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xiyou_accepted_baseline_')
        self.root = Path(self.tmp.name).resolve() / 'main'
        self.tools, self.app = self.root / 'tools', self.root / 'app'
        self.gen = self.root / 'generated'
        self.oracle = self.tools / 'mv_oracle'
        for path in (self.oracle / '.sandbox', self.app, self.gen / 'oracle'):
            path.mkdir(parents=True)
        self.manifest = {'releaseVersion': 'v0.28', 'inputs': {'data/A.json': 'a'},
                         'runtimeInputs': {'js/a.js': 'r'}}
        self.original = {'cases': [{'id': 'stable', 'value': 1}]}
        (self.gen / 'manifest.json').write_text(json.dumps(self.manifest))
        (self.gen / 'slice.json').write_text('{}')
        (self.gen / 'oracle/events.json').write_text(json.dumps(self.original))
        (self.app / 'package.json').write_text('{"releaseVersion":"v0.28"}')
        (self.tools / 'xiyou_slice.json').write_text('{}')
        self.count = self.root / 'executions.txt'
        (self.oracle / 'baseline_probe.cjs').write_text(
            "const fs = require('fs');\n"
            "fs.appendFileSync(%s, 'run\\n');\n" % json.dumps(str(self.count)) +
            "fs.copyFileSync(process.env.XIYOU_APP + '/payload.json', '.sandbox/events.json');\n")
        self.set_payload({'cases': [{'id': 'stable', 'value': 2}]})
        self.verify = True
        self.import_error = None

    def tearDown(self):
        self.tmp.cleanup()

    def set_payload(self, data):
        (self.app / 'payload.json').write_text(json.dumps(data))

    def run_sync(self, *extra, do_import=False, cache_error=False, lane=None):
        real_run = subprocess.run

        def external(command, **kwargs):
            if command[0] == 'git':
                return subprocess.CompletedProcess(command, 0, 'same\nsame\n', '')
            if command[0] == 'cp':
                return subprocess.CompletedProcess(command, 1, '', '')
            if any(str(value).endswith('验证西游来源.py') for value in command):
                return subprocess.CompletedProcess(command, 0 if self.verify else 1, 'fixture source', '')
            return real_run(command, **kwargs)

        def export(*args):
            (self.gen / 'manifest.json').write_text(json.dumps(self.manifest))

        def clone(*args):
            return (lane, {'outputsDigest': sync.outputs_digest(lane)}), None

        argv = ['sync', '--app', str(self.app), '--generated', str(self.gen), '--no-register', *extra]
        if not do_import:
            argv.append('--no-import')
        output = io.StringIO()
        with contextlib.ExitStack() as stack:
            stack.enter_context(mock.patch.multiple(sync, ROOT=self.root, HERE=self.tools, ORACLE_DIR=self.oracle,
                                SANDBOX=self.oracle / '.sandbox', PROBES=[(['baseline_probe.cjs'], ['events.json'])],
                                run=export, tools_digest=lambda *args: 'fixture'))
            stack.enter_context(mock.patch.object(sync.subprocess, 'run', side_effect=external))
            stack.enter_context(mock.patch.object(sync, 'godot_import', side_effect=self.import_error))
            stack.enter_context(mock.patch.object(sys, 'argv', argv))
            stack.enter_context(mock.patch.dict(os.environ))
            stack.enter_context(contextlib.redirect_stdout(output))
            if cache_error:
                stack.enter_context(mock.patch.object(ProbeCache, 'commit', side_effect=RuntimeError('fixture changed input')))
            if lane is not None:
                stack.enter_context(mock.patch.object(sync, 'clone_from_worktree', side_effect=clone))
            result = sync.main()
        if result == 3:
            return result, None
        short = json.loads(output.getvalue().strip().splitlines()[-1])
        report = json.loads((self.root / short['backup'] / '同步报告.json').read_text())
        return result, report

    def test_rejection_survives_cache_hits_pruning_and_full(self):
        for index in range(5):
            result, report = self.run_sync('--accept-additions')
            self.assertEqual(result, 2)
            self.assertIn('events.json', report['measurementChanges'])
            self.assertEqual(report['probes']['reused'], ['baseline_probe.cjs'] if index else [])
        result, report = self.run_sync('--full')
        self.assertEqual(result, 2)
        self.assertEqual(report['probes']['executed'], ['baseline_probe.cjs'])
        self.assertEqual(len(self.count.read_text().splitlines()), 2)
        backups = self.root / '03_再刷重制_Godot/04_验证/本地结果/自动同步'
        self.assertEqual(len(list(backups.iterdir())), 3)

    def test_additions_require_acceptance_and_then_become_the_new_baseline(self):
        added = {'cases': self.original['cases'] + [{'id': 'new', 'value': 3}]}
        self.set_payload(added)
        for _ in range(2):
            self.assertEqual(self.run_sync()[0], 2)
        self.assertEqual(self.run_sync('--accept-additions')[0], 0)
        self.assertEqual(self.run_sync()[0], 0)
        added['cases'][1]['value'] = 4
        self.set_payload(added)
        self.assertEqual(self.run_sync('--accept-additions')[0], 2)

    def test_withdrawn_change_is_successful_but_later_change_is_still_rejected(self):
        self.assertEqual(self.run_sync()[0], 2)
        self.set_payload(self.original)
        self.assertEqual(self.run_sync()[0], 0)
        self.set_payload({'cases': [{'id': 'stable', 'value': 3}]})
        self.assertEqual(self.run_sync()[0], 2)

    def test_source_manifest_is_retained_across_rejections(self):
        self.set_payload({'cases': self.original['cases'] + [{'id': 'new', 'value': 3}]})
        self.manifest['runtimeInputs']['js/a.js'] = 'changed'
        for extra in [(), (), ('--full',)]:
            result, report = self.run_sync('--accept-additions', *extra)
            self.assertEqual(result, 2)
            self.assertFalse(report['sameExistingSource'])
        self.manifest['runtimeInputs']['js/a.js'] = 'r'
        self.assertEqual(self.run_sync('--accept-additions')[0], 0)

    def test_failed_source_import_or_cache_cannot_accept_the_next_baseline(self):
        for failure in ['source', 'import', 'cache']:
            with self.subTest(failure=failure):
                self.set_payload({'cases': self.original['cases'] + [{'id': failure, 'value': 3}]})
                self.verify = failure != 'source'
                self.import_error = RuntimeError('fixture import') if failure == 'import' else None
                self.assertEqual(self.run_sync('--accept-additions', do_import=True,
                                               cache_error=failure == 'cache')[0], 2)
                self.verify, self.import_error = True, None
                # A successful retry without the acceptance flag must still reject the addition.
                self.assertEqual(self.run_sync()[0], 2)
                self.set_payload(self.original)
                self.assertEqual(self.run_sync()[0], 0)

    def test_clone_cannot_erase_an_unaccepted_baseline(self):
        lane = self.root.parent / 'lane'
        import shutil
        shutil.copytree(self.gen, lane)
        (lane / 'oracle/events.json').write_text((self.app / 'payload.json').read_text())
        for _ in range(2):
            result, report = self.run_sync('--from-worktree', str(lane), lane=lane)
            self.assertEqual(result, 2)
            self.assertIn('events.json', report['measurementChanges'])
        # A normal forced run must also retain the target's accepted baseline after cloning.
        self.assertEqual(self.run_sync('--full')[0], 2)

    def test_failed_clone_preflight_does_not_create_a_baseline_or_change_outputs(self):
        before = sync.outputs_digest(self.gen)
        self.assertEqual(self.run_sync('--from-worktree', str(self.root.parent / 'missing'))[0], 3)
        self.assertEqual(sync.outputs_digest(self.gen), before)
        self.assertFalse((self.root / '03_再刷重制_Godot/04_验证/本地结果/同步基线').exists())

    def test_partial_snapshot_is_not_published_and_corruption_fails_closed(self):
        with mock.patch.object(sync.shutil, 'copytree', side_effect=OSError('fixture interrupted copy')):
            with self.assertRaises(OSError):
                self.run_sync()
        parent = self.root / '03_再刷重制_Godot/04_验证/本地结果/同步基线'
        self.assertEqual(list(parent.iterdir()), [])
        result, report = self.run_sync()
        self.assertEqual(result, 2)
        baseline = self.root / report['comparisonBaseline']
        (baseline / 'manifest.json').write_text('invalid')
        with self.assertRaisesRegex(RuntimeError, '基线损坏'):
            self.run_sync('--accept-additions')
        self.assertTrue(baseline.exists())

    def test_failed_stamp_write_cannot_advance_the_baseline(self):
        self.set_payload({'cases': self.original['cases'] + [{'id': 'new', 'value': 3}]})
        with mock.patch.object(sync, 'write_stamp', side_effect=OSError('fixture stamp write failed')):
            with self.assertRaises(OSError):
                self.run_sync('--accept-additions')
        self.assertEqual(self.run_sync()[0], 2)
        self.assertEqual(self.run_sync('--accept-additions')[0], 0)


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        r = Path(self.tmp.name)
        self.tools, self.app, self.gen = r / 'tools', r / 'app', r / 'gen'
        self.oracle = self.tools / 'mv_oracle'
        for p in (self.oracle / '.sandbox', self.oracle / 'node_modules', self.gen / 'oracle', self.gen / 'maps', self.app):
            p.mkdir(parents=True)
        (self.app / 'source.js').write_text('source')
        (self.tools / 'xiyou_slice.json').write_text('{}')
        (self.oracle / 'a_probe.cjs').write_text("// ../xiyou_slice.json")
        (self.oracle / 'b_probe.cjs').write_text('// independent')
        (self.oracle / 'event_probe.cjs').write_text('// XIYOU_GENERATED')
        (self.oracle / 'host.cjs').write_text('// helper')
        (self.oracle / 'node_modules/runtime.js').write_text('// runtime')
        (self.gen / 'manifest.json').write_text('{}')
        (self.gen / 'slice.json').write_text('{}')
        (self.gen / 'maps/map.json').write_text('{}')
        for name in ('a', 'b', 'event'):
            (self.gen / 'oracle' / (name + '.json')).write_text('{"cases":[{"id":"ok"}]}')
        self.probes = [([name + '_probe.cjs'], [name + '.json']) for name in ('a', 'b', 'event')]

    def tearDown(self):
        self.tmp.cleanup()

    def cache(self, force=False):
        return ProbeCache(self.tools, self.app, self.gen, force)

    def prime(self):
        c = self.cache()
        for cmd, outs in self.probes:
            c.record(cmd, outs, c.key(cmd))
        c.commit()

    def hits(self):
        c = self.cache()
        return [c.hit(cmd, outs, c.key(cmd)) for cmd, outs in self.probes]

    def test_no_change_skips_all_and_full_skips_none(self):
        self.prime()
        self.assertEqual(self.hits(), [True] * 3)
        c = self.cache(True)
        self.assertFalse(any(c.hit(cmd, outs, c.key(cmd)) for cmd, outs in self.probes))

    def test_slice_only_invalidates_consumers(self):
        self.prime()
        (self.tools / 'xiyou_slice.json').write_text('{"actors":[1,8]}')
        self.assertEqual(self.hits(), [False, True, True])

    def test_converter_output_invalidates_event_after_conversion(self):
        self.prime()
        (self.gen / 'maps/map.json').write_text('{"events":[1]}')
        self.assertEqual(self.hits(), [True, True, False])

    def test_probe_change_is_local_even_with_same_mtime(self):
        self.prime()
        p = self.oracle / 'b_probe.cjs'
        old = p.stat()
        p.write_text('// changed')
        os.utime(p, ns=(old.st_atime_ns, old.st_mtime_ns))
        self.assertEqual(self.hits(), [True, False, True])

    def test_helper_runtime_and_source_invalidate_all(self):
        for path in [self.oracle / 'host.cjs', self.oracle / 'node_modules/runtime.js', self.app / 'source.js']:
            self.prime()
            path.write_text('// changed ' + path.name)
            self.assertEqual(self.hits(), [False] * 3)

    def test_converter_code_only_matters_through_converted_output(self):
        # 探针不执行 Python：转换器改了但产物没变时不失效；产物变了由 converted 键让读产物的探针重跑
        self.prime()
        (self.tools / 'xiyou_export.py').write_text('# changed converter')
        self.assertEqual(self.hits(), [True] * 3)
        (self.gen / 'db').mkdir(exist_ok=True)
        (self.gen / 'db/Skills.json').write_text('[]')
        self.assertEqual(self.hits(), [True, True, False])

    def test_slice_fields_only_invalidate_probes_reading_them(self):
        decl = "const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\n"
        (self.oracle / 'a_probe.cjs').write_text(decl + 'for (const id of SLICE.actors) {}')
        (self.tools / 'xiyou_slice.json').write_text('{"actors":[1],"troops":[1],"maxLevel":30}')
        self.prime()
        (self.tools / 'xiyou_slice.json').write_text('{"actors":[1],"troops":[1,2],"maxLevel":35}')
        self.assertEqual(self.hits(), [True, True, True])
        (self.tools / 'xiyou_slice.json').write_text('{"actors":[1,8],"troops":[1,2],"maxLevel":35}')
        self.assertEqual(self.hits(), [False, True, True])
        # 认不出的用法（整份传出去）退回整份切片
        for text in [decl + 'use(SLICE);', decl + 'SLICE[name];', '// ../xiyou_slice.json']:
            self.assertIsNone(sys.modules['incremental_sync'].slice_fields([text]), text)

    def test_event_units_follow_converted_maps_and_common_events(self):
        (self.oracle / 'event_probe.cjs').write_text(
            "const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\n"
            "for (const id of SLICE.maps) {} // XIYOU_GENERATED")
        (self.tools / 'xiyou_slice.json').write_text('{"maps":[1,2]}')
        for i in (1, 2, 3):
            (self.gen / 'maps' / ('Map%03d.json' % i)).write_text('{"events":[%d]}' % i)
        (self.gen / 'manifest.json').write_text('{"slice":{"commonEvents":[7]}}')
        cmd, outs = self.probes[2]
        c = self.cache()
        c.record(cmd, outs, c.key(cmd), c.units(cmd))
        c.commit()
        c = self.cache()
        self.assertEqual(c.plan(cmd, outs, c.key(cmd), c.units(cmd)), [])
        (self.gen / 'maps/Map002.json').write_text('{"events":[22]}')
        (self.gen / 'maps/Map003.json').write_text('{"events":[33]}')     # 不在切片里，不算
        c = self.cache()
        self.assertEqual(c.plan(cmd, outs, c.key(cmd), c.units(cmd)), ['m2'])
        (self.tools / 'xiyou_slice.json').write_text('{"maps":[1,2,3]}')
        (self.gen / 'manifest.json').write_text('{"slice":{"commonEvents":[7,8]}}')
        c = self.cache()
        self.assertEqual(c.plan(cmd, outs, c.key(cmd), c.units(cmd)), ['m2', 'm3', 'ce8'])
        self.assertIsNone(self.cache(True).plan(cmd, outs, c.key(cmd), c.units(cmd)))

    def test_transitive_probe_dependency_invalidates_the_reader(self):
        (self.oracle / 'a_probe.cjs').write_text("require('./b_probe.cjs')")
        self.prime()
        (self.oracle / 'b_probe.cjs').write_text('// changed dependency')
        self.assertEqual(self.hits(), [False, False, True])

    def test_modified_or_missing_output_cannot_hit(self):
        self.prime()
        (self.gen / 'oracle/a.json').write_text('{}')
        (self.gen / 'oracle/b.json').unlink()
        self.assertEqual(self.hits(), [False, False, True])

    def test_corrupt_cache_is_a_miss(self):
        self.prime()
        self.cache().path.write_text('[]')
        self.assertEqual(self.hits(), [False] * 3)

    def test_inputs_changed_during_run_cannot_publish_cache(self):
        c = self.cache()
        cmd, outs = self.probes[0]
        c.record(cmd, outs, c.key(cmd))
        (self.oracle / 'a_probe.cjs').write_text('// changed midway')
        with self.assertRaises(RuntimeError):
            c.commit()
        self.assertFalse(c.path.exists())

    def test_failed_or_missing_probe_does_not_reuse_stale_output(self):
        self.prime()
        (self.oracle / '.sandbox/a.json').write_text('{"old":true}')
        for text in [None, '{"cases":[{"error":"failed sampling"}]}']:
            c = self.cache(True)
            def fake(*args, **kwargs):
                if text is not None:
                    (self.oracle / '.sandbox/a.json').write_text(text)
                return subprocess.CompletedProcess(args, 0, '', '')
            with mock.patch.multiple(sync, PROBES=[self.probes[0]], ORACLE_DIR=self.oracle, SANDBOX=self.oracle / '.sandbox'), \
                 mock.patch.object(sync.subprocess, 'run', fake), mock.patch.dict(os.environ, XIYOU_GENERATED=str(self.gen)):
                with self.assertRaises(RuntimeError):
                    sync.run_probes(io.StringIO(), c)
            self.assertNotIn('a_probe.cjs', json.loads(c.path.read_text())['probes'])
            self.assertIn('ok', (self.gen / 'oracle/a.json').read_text())

    def test_failed_forced_run_cannot_reuse_last_success(self):
        self.prime()
        c = self.cache(True)
        with mock.patch.multiple(sync, PROBES=[self.probes[0]], ORACLE_DIR=self.oracle, SANDBOX=self.oracle / '.sandbox'), \
             mock.patch.object(sync.subprocess, 'run', return_value=subprocess.CompletedProcess([], 7, '', 'failure')), \
             mock.patch.dict(os.environ, XIYOU_GENERATED=str(self.gen)):
            with self.assertRaises(RuntimeError):
                sync.run_probes(io.StringIO(), c)
        self.assertEqual(self.hits(), [False, True, True])

    def test_existing_baseline_failure_cannot_be_extended_or_changed(self):
        known = '{"cases":[{"id":"known","error":"old failure","finished":false}]}'
        (self.gen / 'oracle/a.json').write_text(known)
        for text, accepted in [(known, True), (known.replace('old failure', 'new failure'), False)]:
            def fake(*args, **kwargs):
                (self.oracle / '.sandbox/a.json').write_text(text)
                return subprocess.CompletedProcess(args, 0, '', '')
            with mock.patch.multiple(sync, PROBES=[self.probes[0]], ORACLE_DIR=self.oracle, SANDBOX=self.oracle / '.sandbox'), \
                 mock.patch.object(sync.subprocess, 'run', fake), mock.patch.dict(os.environ, XIYOU_GENERATED=str(self.gen)):
                if accepted:
                    self.assertEqual(sync.run_probes(io.StringIO())['executed'], ['a_probe.cjs'])
                else:
                    with self.assertRaises(RuntimeError):
                        sync.run_probes(io.StringIO())

    def test_healthy_event_change_with_frozen_failures_reaches_measurement_report(self):
        old = {'cases': [{'id': 'known', 'errors': ['old failure'], 'finished': False},
                         {'id': 'healthy', 'frames': 1, 'errors': []}]}
        new = copy.deepcopy(old)
        new['cases'][1]['frames'] = 2
        (self.gen / 'oracle/events.json').write_text(json.dumps(old))
        def fake(*args, **kwargs):
            (self.oracle / '.sandbox/events.json').write_text(json.dumps(new))
            return subprocess.CompletedProcess(args, 0, '', '')
        with mock.patch.multiple(sync, PROBES=[(['event_probe.cjs'], ['events.json'])],
                                 ORACLE_DIR=self.oracle, SANDBOX=self.oracle / '.sandbox'), \
             mock.patch.object(sync.subprocess, 'run', fake), \
             mock.patch.dict(os.environ, XIYOU_GENERATED=str(self.gen)):
            result = sync.run_probes(io.StringIO())
        self.assertEqual(result['executed'], ['event_probe.cjs'])
        self.assertEqual(json.loads((self.gen / 'oracle/events.json').read_text()), new)
        # Allow the reporting stage to see the change, but never auto-accept it.
        self.assertTrue(oracle_additions.compare_file('events.json', old, new)[1])

    def test_failure_guard_ignores_healthy_rows_but_rejects_new_changed_or_duplicate_failure(self):
        old = {'cases': [{'id': 'known', 'errors': ['old'], 'observed': {'frames': 1}},
                         {'id': 'healthy', 'errors': []}], 'errors': []}
        for kind in ['healthy_change', 'fixed', 'changed', 'new', 'duplicate', 'root']:
            new = copy.deepcopy(old)
            if kind == 'healthy_change': new['cases'][1]['observed'] = {'frames': 2}
            if kind == 'fixed': new['cases'][0]['errors'] = []
            if kind == 'changed': new['cases'][0]['observed']['frames'] = 2
            if kind == 'new': new['cases'][1]['errors'] = ['new']
            if kind == 'duplicate': new['cases'].append(copy.deepcopy(new['cases'][0]))
            if kind == 'root': new['errors'] = ['new host failure']
            self.assertEqual(oracle_additions.retained_errors_unchanged('events.json', old, new),
                             kind in ['healthy_change', 'fixed'], kind)

    def test_reused_output_is_not_replaced_from_old_sandbox(self):
        self.prime()
        (self.oracle / '.sandbox/a.json').write_text('{"stale":true}')
        c = self.cache()
        with mock.patch.object(sync, 'PROBES', self.probes), mock.patch.object(sync.subprocess, 'run', side_effect=AssertionError('must skip')):
            result = sync.run_probes(io.StringIO(), c)
        self.assertEqual(result['executed'], [])
        self.assertEqual(len(result['reused']), 3)
        self.assertIn('ok', (self.gen / 'oracle/a.json').read_text())


FAKE_SMART_AI = r"""const fs = require('fs'), path = require('path');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const UNITS = process.env.XIYOU_PROBE_UNITS ? new Set(JSON.parse(process.env.XIYOU_PROBE_UNITS)) : null;
const out = {head: SLICE.troops[0], cases: [], damage: [], sequence: [1.5e-7, 1e21, 0.1 + 0.2]};
for (const troop of SLICE.troops.filter(t => !UNITS || UNITS.has(String(t)))) {
  out.cases.push({troop, v: troop / 3, name: '敌群' + troop});
  if (troop % 2) out.damage.push({troop, hit: 1 - troop / 7});
}
fs.appendFileSync(path.join(__dirname, '.sandbox/ran.log'), JSON.stringify(UNITS ? [...UNITS] : 'all') + '\n');
fs.writeFileSync(path.join(__dirname, '.sandbox/smart_ai.json'), JSON.stringify(out, null, 1));
"""


class ShardTests(unittest.TestCase):
    """真 node 跑假探针：分片增量产物与强制全量逐字节一致，只跑新增单元。"""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        r = Path(self.tmp.name)
        self.tools, self.app, self.gen = r / 'tools', r / 'app', r / 'gen'
        self.oracle = self.tools / 'mv_oracle'
        for p in (self.oracle / '.sandbox', self.gen / 'oracle', self.gen / 'maps', self.app):
            p.mkdir(parents=True)
        (self.app / 'source.js').write_text('source')
        (self.gen / 'manifest.json').write_text('{}')
        (self.oracle / 'smart_ai_probe.cjs').write_text(FAKE_SMART_AI)
        self.probes = [(['smart_ai_probe.cjs'], ['smart_ai.json'])]

    def tearDown(self):
        self.tmp.cleanup()

    def sync(self, troops, force=False):
        (self.tools / 'xiyou_slice.json').write_text(json.dumps({'troops': troops}))
        c = ProbeCache(self.tools, self.app, self.gen, force)
        with mock.patch.multiple(sync, PROBES=self.probes, ORACLE_DIR=self.oracle, SANDBOX=self.oracle / '.sandbox'), \
             mock.patch.dict(os.environ, XIYOU_GENERATED=str(self.gen)), contextlib.redirect_stdout(io.StringIO()):
            result = sync.run_probes(io.StringIO(), c)
        c.commit()
        ran = (self.oracle / '.sandbox/ran.log').read_text().splitlines() if (self.oracle / '.sandbox/ran.log').exists() else []
        return result, ran[-1] if ran else None, (self.gen / 'oracle/smart_ai.json').read_bytes()

    def full_bytes(self, troops):
        # 另起一份工具目录直接全量跑同一个探针，作对照
        tools = Path(tempfile.mkdtemp(dir=self.tmp.name)) / 'tools'
        (tools / 'mv_oracle/.sandbox').mkdir(parents=True)
        (tools / 'mv_oracle/smart_ai_probe.cjs').write_text(FAKE_SMART_AI)
        (tools / 'xiyou_slice.json').write_text(json.dumps({'troops': troops}))
        subprocess.run(['node', 'smart_ai_probe.cjs'], cwd=tools / 'mv_oracle', check=True)
        return (tools / 'mv_oracle/.sandbox/smart_ai.json').read_bytes()

    def test_added_removed_reordered_and_first_changed_units(self):
        _, ran, _ = self.sync([1, 2, 3], force=True)
        self.assertEqual(ran, '"all"')
        for troops, expect_ran, partial in [
                ([1, 2, 3, 4, 5], '["4","5"]', ['4', '5']),   # 加楼层：只跑新敌群
                ([1, 2, 3, 4, 5], None, None),                # 无改动：整体复用
                ([1, 3, 5], None, []),                        # 只删：不跑探针，只合并
                ([1, 5, 3], None, []),                        # 只换顺序
                ([1, 5, 3, 2], '["2"]', ['2'])]:              # 删掉的再加回来也要重跑
            runs = (self.oracle / '.sandbox/ran.log').read_text().count('\n')
            result, ran, merged = self.sync(troops)
            self.assertEqual(merged, self.full_bytes(troops), troops)
            if expect_ran is None:
                self.assertEqual((self.oracle / '.sandbox/ran.log').read_text().count('\n'), runs, troops)
            else:
                self.assertEqual(ran, expect_ran, troops)
            if partial is None:
                self.assertEqual(result['reused'], ['smart_ai_probe.cjs'], troops)
            else:
                self.assertEqual(result['partial'], {'smart_ai_probe.cjs': partial}, troops)
        # 第一项另有整体用途：变了就整体重跑
        result, ran, merged = self.sync([9, 1, 5, 3, 2])
        self.assertEqual(ran, '"all"')
        self.assertEqual(result['executed'], ['smart_ai_probe.cjs'])
        self.assertEqual(merged, self.full_bytes([9, 1, 5, 3, 2]))

    def test_tampered_previous_output_forces_full_run(self):
        self.sync([1, 2], force=True)
        (self.gen / 'oracle/smart_ai.json').write_text('{"cases":[]}')
        result, ran, merged = self.sync([1, 2, 3])
        self.assertEqual(ran, '"all"')
        self.assertEqual(merged, self.full_bytes([1, 2, 3]))


class BackupPruneTests(unittest.TestCase):
    def test_keeps_newest_three_named_backups_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            names = ['20261018_090000_v0.28-v0.28', '20261019_100000_v0.28-v0.28', '20261019_100000_123456_v0.28-v0.28',
                     '20261019_120000_v0.28-v0.28', '20261019_130000_000001_v0.28-v0.28']
            for n in names:
                (root / n).mkdir()
            (root / '说明').mkdir()
            (root / '20261017_000000_note.txt').write_text('file, not a backup dir')
            removed = sync.prune_backups(root)
            self.assertEqual(sorted(removed), names[:2])
            self.assertEqual(sorted(p.name for p in root.iterdir()),
                             sorted(names[2:] + ['说明', '20261017_000000_note.txt']))


class ActorSampleGuardTests(unittest.TestCase):
    def test_valid_samples_only_and_error_unknown_or_bad_level_rejected(self):
        old = {'actors': {'1': {'lv1': {'param': [100]}}}}
        row = {'param': [1] * 8, 'xparam': [0] * 10, 'sparam': [1] * 10,
               'elementRates': [1], 'level': 35, 'hp': 1, 'mhp': 1}
        samples = {str(level): dict(row, level=level) for level in (35, 65, 99)}
        for field, value, accepted in [('levelSamples', samples, True), ('levelSamples', {'35': {'error': 'failed'}}, False),
                                        ('unknown', samples, False), ('levelSamples', {}, False)]:
            new = copy.deepcopy(old)
            new['actors']['1'][field] = value
            extra, bad = oracle_additions.compare_file('slice_d2.json', old, new)
            self.assertEqual(bool(extra) and not bad, accepted, [extra, bad])
        samples['35']['level'] = 1
        self.assertFalse(oracle_additions.valid_level_samples(samples))


class TaskWatchTests(unittest.TestCase):
    def test_success_failure_and_stall_have_consistent_marker_exit_and_wait(self):
        with tempfile.TemporaryDirectory() as tmp:
            for script, expected, status in [('print("ok")', 0, 'done'), ('raise SystemExit(7)', 7, 'failed'),
                                              ('import time; time.sleep(10)', 124, 'stuck')]:
                log = Path(tmp) / (status + '.log')
                p = subprocess.run([sys.executable, str(HERE / '长任务.py'), 'run', str(log), '--idle-timeout', '0.3',
                                    '--', sys.executable, '-c', script], capture_output=True, timeout=10)
                self.assertEqual(p.returncode, expected, p.stdout + p.stderr)
                data = json.loads(Path(str(log) + '.status.json').read_text())
                self.assertEqual(data['status'], status)
                self.assertEqual(int(Path(str(log) + '.exit').read_text()), expected)
                w = subprocess.run([str(HERE / '等待任务.sh'), str(log)], capture_output=True, timeout=5)
                self.assertEqual(w.returncode, expected, w.stdout + w.stderr)

    def test_non_utf8_output_does_not_hide_valid_completion_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'binary.log'
            script = "import os; os.write(1, bytes([255, 254, 10]))"
            p = subprocess.run([sys.executable, str(HERE / '长任务.py'), 'run', str(log),
                                '--', sys.executable, '-c', script], capture_output=True, timeout=10)
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            self.assertIn(bytes([255, 254]), log.read_bytes())
            w = subprocess.run([str(HERE / '等待任务.sh'), str(log)], capture_output=True, timeout=5)
            self.assertEqual(w.returncode, 0, w.stdout + w.stderr)

    def test_orphan_holding_log_pipe_is_stopped_with_its_owned_group(self):
        with tempfile.TemporaryDirectory() as tmp:
            log, pidfile = Path(tmp) / 'orphan.log', Path(tmp) / 'child.pid'
            child = "import os,signal,time; from pathlib import Path; signal.signal(signal.SIGTERM,signal.SIG_IGN); Path(%r).write_text(str(os.getpid())); time.sleep(30)" % str(pidfile)
            parent = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',%r]); time.sleep(0.2)" % child
            try:
                p = subprocess.run([sys.executable, str(HERE / '长任务.py'), 'run', str(log), '--', sys.executable, '-c', parent],
                                   capture_output=True, timeout=10)
                self.assertEqual(p.returncode, 1)
                pid = int(pidfile.read_text())
                state = subprocess.run(['ps', '-o', 'stat=', '-p', str(pid)], capture_output=True, text=True).stdout.strip()
                self.assertTrue(not state or state.startswith('Z'), state)
            finally:
                if pidfile.exists():
                    try:
                        os.kill(int(pidfile.read_text()), signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_descendant_with_closed_stdout_is_not_reported_as_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            log, pidfile = Path(tmp) / 'quiet-child.log', Path(tmp) / 'child.pid'
            child = "import os,time; from pathlib import Path; Path(%r).write_text(str(os.getpid())); time.sleep(30)" % str(pidfile)
            parent = ("import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',%r], "
                      "stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); time.sleep(.2)") % child
            try:
                p = subprocess.run([sys.executable, str(HERE / '长任务.py'), 'run', str(log), '--', sys.executable, '-c', parent],
                                   capture_output=True, timeout=10)
                self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
                stat = subprocess.run(['ps', '-o', 'stat=', '-p', pidfile.read_text()], capture_output=True, text=True).stdout.strip()
                self.assertTrue(not stat or stat.startswith('Z'), stat)
            finally:
                if pidfile.exists():
                    try:
                        os.kill(int(pidfile.read_text()), signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_legacy_abandoned_runner_is_unconfirmed(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'abandoned.log'
            log.write_text('started\n')
            Path(str(log) + '.status.json').write_text(json.dumps({'runId': 'x', 'status': 'running', 'pid': 1073741824, 'exitCode': None}))
            w = subprocess.run([str(HERE / '等待任务.sh'), str(log)], capture_output=True, timeout=5)
            self.assertEqual(w.returncode, 2, w.stdout + w.stderr)
            self.assertEqual(json.loads(Path(str(log) + '.status.json').read_text())['status'], 'orphaned')
            self.assertFalse(Path(str(log) + '.exit').exists())
            self.assertNotIn('TASK_RESULT=', log.read_text())

    def test_killed_wrapper_cleans_child_before_publishing_stuck_even_with_reused_wrapper_pid(self):
        import time
        with tempfile.TemporaryDirectory() as tmp:
            log, pidfile, ticks = Path(tmp) / 'killed.log', Path(tmp) / 'child.pid', Path(tmp) / 'ticks'
            child = ("import os,time; from pathlib import Path; Path(%r).write_text(str(os.getpid())); "
                     "exec('while True:\\n Path(%r).write_text(str(time.monotonic())); time.sleep(.02)')") % (str(pidfile), str(ticks))
            # Construct the child script without an extra escaping layer.
            child = ("import os,time; from pathlib import Path; Path(%r).write_text(str(os.getpid()))\n"
                     "while True:\n Path(%r).write_text(str(time.monotonic())); time.sleep(.02)") % (str(pidfile), str(ticks))
            runner = subprocess.Popen([sys.executable, str(HERE / '长任务.py'), 'run', str(log), '--', sys.executable, '-c', child],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    try:
                        state = json.loads(Path(str(log) + '.status.json').read_text())
                        if state.get('childIdentity') and ticks.exists():
                            break
                    except (OSError, ValueError):
                        pass
                    time.sleep(.01)
                else:
                    self.fail('child identity was not published')
                runner.kill(); runner.wait()
                state['pid'] = os.getpid()  # Simulate a reused wrapper PID pointing to a live unrelated process.
                Path(str(log) + '.status.json').write_text(json.dumps(state))
                w = subprocess.run([str(HERE / '等待任务.sh'), str(log)], capture_output=True, timeout=10)
                self.assertEqual(w.returncode, 124, w.stdout + w.stderr)
                state = json.loads(Path(str(log) + '.status.json').read_text())
                self.assertEqual(state['status'], 'stuck')
                before = ticks.read_text(); time.sleep(.1)
                self.assertEqual(ticks.read_text(), before, 'child still mutates after terminal result')
                stat = subprocess.run(['ps', '-o', 'stat=', '-p', pidfile.read_text()], capture_output=True, text=True).stdout.strip()
                self.assertTrue(not stat or stat.startswith('Z'), stat)
            finally:
                if runner.poll() is None:
                    runner.kill(); runner.wait()
                if pidfile.exists():
                    try:
                        os.killpg(int(pidfile.read_text()), signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_reused_child_group_identity_is_not_signalled_or_marked_finished(self):
        watch = load('watch_identity_test', HERE / '长任务.py')
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'identity.log'; log.write_text('started\n')
            child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'], start_new_session=True)
            try:
                row = watch.identity(watch.process_table().get(child.pid))
                row['startedAt'] = 'different process start time'
                state = {'runId': 'x', 'status': 'running', 'pid': os.getpid(), 'exitCode': None,
                         'childPGID': child.pid, 'childIdentity': row}
                Path(str(log) + '.status.json').write_text(json.dumps(state))
                w = subprocess.run([str(HERE / '等待任务.sh'), str(log)], capture_output=True, timeout=5)
                self.assertEqual(w.returncode, 2, w.stdout + w.stderr)
                self.assertIsNone(child.poll(), 'unrelated process was signalled')
                state = json.loads(Path(str(log) + '.status.json').read_text())
                self.assertEqual(state['status'], 'orphaned')
                self.assertNotIn('finishedAt', state)
                self.assertFalse(Path(str(log) + '.exit').exists())
                self.assertNotIn('TASK_RESULT=', log.read_text())
                rerun = subprocess.run([sys.executable, str(HERE / '长任务.py'), 'run', str(log), '--',
                                        sys.executable, '-c', 'print(1)'], capture_output=True, timeout=5)
                self.assertEqual(rerun.returncode, 2)
                self.assertEqual(json.loads(Path(str(log) + '.status.json').read_text())['runId'], 'x')
            finally:
                child.kill(); child.wait()

    def test_mismatched_or_missing_completion_is_not_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'task.log'
            log.write_text('not a completion marker\n')
            Path(str(log) + '.exit').write_text('0')
            Path(str(log) + '.status.json').write_text('{"runId":"x","status":"done","exitCode":0}')
            w = subprocess.run([str(HERE / '等待任务.sh'), str(log)], capture_output=True, timeout=5)
            self.assertEqual(w.returncode, 2)


if __name__ == '__main__':
    unittest.main()
