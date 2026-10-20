#!/usr/bin/env python3
"""缓存携带、未命中诊断与手动种子隔离；仅使用临时夹具，不读玩家存档。"""
import json
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1] / '03_转换工具'
sys.path.insert(0, str(TOOLS))
from incremental_sync import ProbeCache, carry_cache


class PortableCacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.app = self.root / 'app'
        self.app.mkdir()
        (self.app / 'source.js').write_text('frozen source')
        self.probes = [([name + '_probe.cjs'], [name + '.json']) for name in ('plain', 'slice', 'converted')]
        for name in ('donor', 'lane'):
            tools, gen = self.paths(name)
            oracle = tools / 'mv_oracle'
            for p in (oracle / 'node_modules', gen / 'db', gen / 'maps', gen / 'oracle'):
                p.mkdir(parents=True)
            (oracle / 'node_modules/runtime.js').write_text('runtime')
            (oracle / 'host.cjs').write_text('// helper')
            (oracle / 'plain_probe.cjs').write_text('// no generated inputs')
            (oracle / 'converted_probe.cjs').write_text('// XIYOU_GENERATED')
            (oracle / 'slice_probe.cjs').write_text("const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\nuse(SLICE.actors);")
            (tools / 'xiyou_slice.json').write_text('{"actors":[1,8]}')
            for p in ('db/Skills.json', 'maps/Map001.json', 'manifest.json', 'slice.json'):
                (gen / p).write_text('{}')
            for _, outputs in self.probes:
                (gen / 'oracle' / outputs[0]).write_text('{"cases":[]}')
        box = self.box('donor')
        for name in ('save/test.rpgsave', 'macport/state.json'):
            p = box / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('fixture seed')

    def tearDown(self):
        self.tmp.cleanup()

    def paths(self, name):
        return self.root / name / 'tools', self.root / name / 'generated'

    def box(self, name):
        return self.paths(name)[0] / 'mv_oracle/.sandbox'

    def cache(self, name='donor', force=False):
        return ProbeCache(self.paths(name)[0], self.app, self.paths(name)[1], force)

    def prime(self):
        c = self.cache()
        for command, outputs in self.probes:
            c.record(command, outputs, c.key(command))
        c.commit()

    def misses(self, name='donor'):
        c = self.cache(name)
        for command, outputs in self.probes:
            c.plan(command, outputs, c.key(command))
        return c.misses

    def test_carry_across_different_absolute_paths_hits_every_probe(self):
        self.prime()
        self.assertEqual(set(carry_cache(self.box('donor'), self.box('lane'))),
                         {'save', 'macport', 'incremental-cache.json'})
        self.assertTrue(all(not why for why in self.misses('lane').values()))

    def test_carried_cache_still_checks_each_output_sha(self):
        self.prime()
        carry_cache(self.box('donor'), self.box('lane'))
        (self.paths('lane')[1] / 'oracle/plain.json').write_text('{"changed":true}')
        self.assertEqual(self.misses('lane')['plain_probe.cjs'], [{'kind': 'output-sha', 'names': ['plain.json']}])

    def test_carry_preserves_lane_seed_and_does_not_claim_hit(self):
        self.prime()
        p = self.box('lane') / 'save/test.rpgsave'
        p.parent.mkdir(parents=True)
        p.write_text('intentional lane seed')
        carry_cache(self.box('donor'), self.box('lane'))
        self.assertEqual(p.read_text(), 'intentional lane seed')
        self.assertIn({'kind': 'common-input', 'field': 'seedFiles'}, self.misses('lane')['plain_probe.cjs'])

    def test_carry_does_not_replace_existing_cache(self):
        self.prime()
        p = self.box('lane') / 'incremental-cache.json'
        p.parent.mkdir(parents=True)
        p.write_text('lane checkpoint')
        carry_cache(self.box('donor'), self.box('lane'))
        self.assertEqual(p.read_text(), 'lane checkpoint')

    def test_carry_rejects_seed_symlink_before_copying(self):
        (self.box('donor') / 'save/link').symlink_to(self.app / 'source.js')
        with self.assertRaisesRegex(RuntimeError, '符号链接'):
            carry_cache(self.box('donor'), self.box('lane'))
        self.assertFalse(self.box('lane').exists())

    def test_missing_and_corrupt_cache_have_distinct_reasons(self):
        self.assertEqual(self.misses()['plain_probe.cjs'], [{'kind': 'cache-missing'}])
        p = self.box('donor') / 'incremental-cache.json'
        p.write_text('not json')
        self.assertEqual(self.misses()['plain_probe.cjs'], [{'kind': 'cache-invalid'}])

    def test_common_changes_are_named(self):
        for relative, field in [('app/source.js', 'source'), ('donor/tools/mv_oracle/host.cjs', 'helpers'),
                                ('donor/tools/mv_oracle/node_modules/runtime.js', 'runtime'),
                                ('donor/tools/mv_oracle/.sandbox/save/test.rpgsave', 'seedFiles')]:
            self.prime()
            with (self.root / relative).open('a') as f:
                f.write('changed')
            self.assertIn({'kind': 'common-input', 'field': field}, self.misses()['plain_probe.cjs'])

    def test_environment_reason_names_only_the_changed_variable(self):
        self.prime()
        with mock.patch.dict(os.environ, {'LANG': 'fixture.changed'}):
            self.assertIn({'kind': 'common-input', 'field': 'environment', 'names': ['LANG']},
                          self.misses()['plain_probe.cjs'])

    def test_slice_field_and_probe_dependency_are_named(self):
        self.prime()
        (self.paths('donor')[0] / 'xiyou_slice.json').write_text('{"actors":[1,8,9]}')
        self.assertIn({'kind': 'sliceFields', 'names': ['actors']}, self.misses()['slice_probe.cjs'])
        self.prime()
        (self.paths('donor')[0] / 'mv_oracle/plain_probe.cjs').write_text('// changed probe')
        self.assertIn({'kind': 'dependencies', 'names': ['mv_oracle/plain_probe.cjs']}, self.misses()['plain_probe.cjs'])

    def test_converted_reason_names_the_changed_file(self):
        self.prime()
        (self.paths('donor')[1] / 'db/Skills.json').write_text('[1]')
        self.assertIn({'kind': 'converted', 'names': ['db/Skills.json']}, self.misses()['converted_probe.cjs'])

    def test_full_is_explained_and_cannot_hit(self):
        self.prime()
        c = self.cache(force=True)
        cmd, outs = self.probes[0]
        self.assertIsNone(c.plan(cmd, outs, c.key(cmd)))
        self.assertEqual(c.misses[cmd[0]], [{'kind': 'forced-full'}])

    def test_output_read_failure_remains_a_miss(self):
        self.prime()
        c = self.cache()
        cmd, outs = self.probes[0]
        key = c.key(cmd)
        original = Path.read_bytes
        def unreadable(path):
            if path.resolve() == (self.paths('donor')[1] / 'oracle/plain.json').resolve():
                raise PermissionError('fixture unreadable')
            return original(path)
        with mock.patch.object(Path, 'read_bytes', unreadable):
            self.assertIsNone(c.plan(cmd, outs, key))
        reason = c.misses[cmd[0]][0]
        self.assertEqual(reason['kind'], 'output-sha')
        self.assertEqual(reason['unavailable'], [{'name': 'plain.json', 'error': 'PermissionError'}])

    def test_report_and_log_retain_miss_reasons_and_hits_are_clean(self):
        spec = importlib.util.spec_from_file_location('speedup_sync_report_test', TOOLS / '同步正式西游.py')
        sync = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(sync)
        oracle = self.paths('donor')[0] / 'mv_oracle'
        (oracle / 'plain_probe.cjs').write_text("require('fs').writeFileSync('.sandbox/plain.json', '{\"cases\":[]}');")
        with mock.patch.multiple(sync, PROBES=self.probes[:1], ORACLE_DIR=oracle, SANDBOX=oracle / '.sandbox'), \
             mock.patch.dict(os.environ, XIYOU_GENERATED=str(self.paths('donor')[1])):
            log, cache = io.StringIO(), self.cache()
            result = sync.run_probes(log, cache)
            self.assertEqual(result['missReasons'], {'plain_probe.cjs': [{'kind': 'cache-missing'}]})
            event = next(line.removeprefix('CACHE_MISS ') for line in log.getvalue().splitlines() if line.startswith('CACHE_MISS '))
            self.assertEqual(json.loads(event)['reasons'], result['missReasons']['plain_probe.cjs'])
            cache.commit()
            log = io.StringIO()
            result = sync.run_probes(log, self.cache())
            self.assertEqual(result['reused'], ['plain_probe.cjs'])
            self.assertEqual(result['missReasons'], {})
            self.assertNotIn('CACHE_MISS', log.getvalue())


class ManualSandboxTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name) / '.sandbox'
        for name in ('save/test.rpgsave', 'macport/save/config.rpgsave'):
            p = self.base / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('initial seed')

    def tearDown(self):
        self.tmp.cleanup()

    def run_node(self, body, check=True):
        script = 'const fs=require("fs"),path=require("path");const {manualSandbox}=require(' + json.dumps(str(TOOLS / 'mv_oracle/manual_sandbox.cjs')) + ');const base=process.argv[1];' + body
        return subprocess.run(['node', '-e', script, str(self.base)], capture_output=True, text=True, check=check)

    def test_manual_writes_leave_common_seed_unchanged(self):
        r = self.run_node('const box=manualSandbox(base);fs.writeFileSync(path.join(box,"save/test.rpgsave"),"runtime write");console.log(JSON.stringify({box,same:box===manualSandbox(base)}));')
        data = json.loads(r.stdout)
        self.assertTrue(data['same'])
        self.assertEqual((self.base / 'save/test.rpgsave').read_text(), 'initial seed')
        self.assertEqual((Path(data['box']) / 'save/test.rpgsave').read_text(), 'runtime write')

    def test_new_process_uses_a_new_copy(self):
        code = 'const box=manualSandbox(base);console.log(JSON.stringify(box));'
        a, b = [json.loads(self.run_node(code).stdout) for _ in range(2)]
        self.assertNotEqual(a, b)
        self.assertEqual((Path(b) / 'macport/save/config.rpgsave').read_text(), 'initial seed')

    def test_guard_still_blocks_common_seed_writes(self):
        guard = json.dumps(str(TOOLS / 'mv_oracle/fs_guard.cjs'))
        code = 'const box=manualSandbox(base);require(' + guard + ').installGuard(path.join(base,"fake-app"),box,[base]);let blocked=false;try{fs.writeFileSync(path.join(base,"save/test.rpgsave"),"bad");}catch(e){blocked=true;}fs.writeFileSync(path.join(box,"save/test.rpgsave"),"ok");console.log(JSON.stringify({blocked}));'
        self.assertTrue(json.loads(self.run_node(code).stdout)['blocked'])
        self.assertEqual((self.base / 'save/test.rpgsave').read_text(), 'initial seed')

    def test_seed_and_manual_directory_symlinks_are_rejected(self):
        outside = self.base.parent / 'outside'
        outside.mkdir()
        (self.base / 'save/link').symlink_to(outside)
        self.assertNotEqual(self.run_node('manualSandbox(base);', check=False).returncode, 0)
        (self.base / 'save/link').unlink()
        (self.base / 'manual').symlink_to(outside)
        self.assertNotEqual(self.run_node('manualSandbox(base);', check=False).returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
