"""Temporary fixtures only: cache invalidation, failed output protection, and owned task lifecycle."""
import contextlib
import copy
import importlib.util
import io
import json
import os
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

    def test_helper_runtime_source_and_converter_invalidate_all(self):
        for path in [self.oracle / 'host.cjs', self.oracle / 'node_modules/runtime.js',
                     self.app / 'source.js', self.tools / 'xiyou_export.py']:
            self.prime()
            path.write_text('// changed ' + path.name)
            self.assertEqual(self.hits(), [False] * 3)

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

    def test_reused_output_is_not_replaced_from_old_sandbox(self):
        self.prime()
        (self.oracle / '.sandbox/a.json').write_text('{"stale":true}')
        c = self.cache()
        with mock.patch.object(sync, 'PROBES', self.probes), mock.patch.object(sync.subprocess, 'run', side_effect=AssertionError('must skip')):
            result = sync.run_probes(io.StringIO(), c)
        self.assertEqual(result['executed'], [])
        self.assertEqual(len(result['reused']), 3)
        self.assertIn('ok', (self.gen / 'oracle/a.json').read_text())


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

    def test_abandoned_runner_is_marked_stuck(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'abandoned.log'
            log.write_text('started\n')
            Path(str(log) + '.status.json').write_text(json.dumps({'runId': 'x', 'status': 'running', 'pid': 1073741824, 'exitCode': None}))
            w = subprocess.run([str(HERE / '等待任务.sh'), str(log)], capture_output=True, timeout=5)
            self.assertEqual(w.returncode, 124, w.stdout + w.stderr)
            self.assertEqual(json.loads(Path(str(log) + '.status.json').read_text())['status'], 'stuck')

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
