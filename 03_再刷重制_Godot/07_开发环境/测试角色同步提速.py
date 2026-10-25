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
import time
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
        # 探针经 并行测试.py 的跨工作树共用槽排队：用本测试自己的状态目录与上限，不和机器上正在跑的同步、检查抢槽
        # （共用槽被占满时只能一个个跑，六难度共用并发池的峰值就量不到 2）
        slots = mock.patch.dict(os.environ, XIYOU_TEST_STATE_DIR=str(self.root / 'test_state'), CHECK_GLOBAL_JOBS='4')
        slots.start()
        self.addCleanup(slots.stop)
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

    def test_carry_rejects_link_inside_existing_target_seed_before_copying(self):
        self.prime()
        target = self.box('lane') / 'save'
        target.mkdir(parents=True)
        (target / 'link').symlink_to(self.app / 'source.js')
        with self.assertRaisesRegex(RuntimeError, '符号链接'):
            carry_cache(self.box('donor'), self.box('lane'))
        self.assertFalse((self.box('lane') / 'incremental-cache.json').exists())

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

    def test_unknown_generated_reader_disables_sharding_and_hashes_outputs(self):
        tools, gen = self.paths('donor')
        probe = tools / 'mv_oracle/slice_probe.cjs'
        probe.write_text("const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\n"
                         "use(SLICE.troops); use(process.env.XIYOU_GENERATED);\n")
        (tools / 'xiyou_slice.json').write_text('{"troops":[1,2]}')
        cmd, outs = self.probes[1]
        c = self.cache()
        self.assertIsNone(c.shard(cmd))
        self.assertIsNone(c.units(cmd))
        c.record(cmd, outs, c.key(cmd))
        c.commit()
        (gen / 'db/Skills.json').write_text('[{"changed":true}]')
        c = self.cache()
        self.assertIsNone(c.plan(cmd, outs, c.key(cmd)))
        self.assertIn({'kind': 'converted', 'names': ['db/Skills.json']}, c.misses[cmd[0]])

    def test_new_generated_read_in_helper_also_disables_sharding(self):
        tools, _ = self.paths('donor')
        (tools / 'mv_oracle/slice_probe.cjs').write_text(
            "const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\nuse(SLICE.troops);")
        self.assertIsNotNone(self.cache().shard(self.probes[1][0]))
        (tools / 'mv_oracle/host.cjs').write_text('use(process.env.XIYOU_GENERATED);')
        self.assertIsNone(self.cache().shard(self.probes[1][0]))

    def test_modified_audited_reader_falls_back_to_whole_generated_key(self):
        import hashlib
        import incremental_sync
        tools, gen = self.paths('donor')
        probe = tools / 'mv_oracle/event_probe.cjs'
        probe.write_text("const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\n"
                         "use(SLICE.maps); use(process.env.XIYOU_GENERATED);\n")
        cmd, outs = ['event_probe.cjs'], ['plain.json']
        with mock.patch.dict(incremental_sync.GENERATED_SHARD_AUDITS,
                             {'mv_oracle/event_probe.cjs': hashlib.sha256(probe.read_bytes()).hexdigest()}):
            self.assertIsNotNone(self.cache().shard(cmd))
            with probe.open('a') as f:
                f.write("use('new generated reader');")
            c = self.cache()
            self.assertIsNone(c.shard(cmd))
            key = c.key(cmd)
            (gen / 'db/Skills.json').write_text('[42]')
            self.assertNotEqual(self.cache().key(cmd), key)

    def test_read_surface_audit_survives_logic_edits_but_not_new_reads(self):
        import incremental_sync
        tools, _ = self.paths('donor')
        probe = tools / 'mv_oracle/event_probe.cjs'
        probe.write_text("const GEN = process.env.XIYOU_GENERATED;\n"
                         "const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));\n"
                         "for (const id of SLICE.maps) use(id);\n")
        cmd = ['event_probe.cjs']
        audit = 'reads:' + incremental_sync.read_surface(probe.read_text())[:16]
        with mock.patch.dict(incremental_sync.GENERATED_SHARD_AUDITS, {'mv_oracle/event_probe.cjs': audit}):
            self.assertIsNotNone(self.cache().shard(cmd))
            with probe.open('a') as f:
                f.write("w.eval('patch runtime');\nconst extra = 1 + 2;\n")  # 只改运行逻辑：仍可分片
            self.assertIsNotNone(self.cache().shard(cmd))
            with probe.open('a') as f:
                f.write("const db = fs.readFileSync(path.join(GEN, 'db/Items.json'));\n")  # 新读法：退回整轮并说明
            c = self.cache()
            self.assertIsNone(c.shard(cmd))
            self.assertEqual(c.shard_issues['event_probe.cjs']['file'], 'mv_oracle/event_probe.cjs')
        self.assertFalse(incremental_sync.audit_ok('reads:abc', b''))  # 前缀过短不算
        self.assertFalse(incremental_sync.audit_ok(None, b''))

    def test_real_event_probe_is_still_audited_for_map_sharding(self):
        # 改了 event_probe.cjs 的读法（读取面）时这里失败：核对它仍只读 maps 与 manifest.slice.commonEvents 后，
        # 把 incremental_sync.GENERATED_SHARD_AUDITS 改成 reads:<新读取面前 16 位>；否则每次加地图都会整轮重跑事件页
        import incremental_sync
        probe = TOOLS / 'mv_oracle/event_probe.cjs'
        expected = incremental_sync.GENERATED_SHARD_AUDITS['mv_oracle/event_probe.cjs']
        self.assertTrue(incremental_sync.audit_ok(expected, probe.read_bytes()),
                        '读取面变了：reads:' + incremental_sync.read_surface(probe.read_text())[:16])

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

    def test_six_difficulties_share_pool_isolate_seeds_and_merge_like_full(self):
        spec = importlib.util.spec_from_file_location('speedup_six_difficulty_test', TOOLS / '同步正式西游.py')
        sync = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(sync)
        tools, gen = self.paths('donor')
        oracle = tools / 'mv_oracle'
        (tools / 'oracle_shard_merge.cjs').write_bytes((TOOLS / 'oracle_shard_merge.cjs').read_bytes())
        (tools / 'xiyou_slice.json').write_text('{"troops":[1,2]}')
        (oracle / 'slice_probe.cjs').write_text(r'''const fs=require('fs'),path=require('path');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const box=process.env.XIYOU_ORACLE_SANDBOX, d=Number(process.argv[2]);
if (process.argv.length !== 3) throw Error('must be one difficulty per command');
if (fs.readFileSync(path.join(box,'save/test.rpgsave'),'utf8') !== 'fixture seed') throw Error('shared seed');
fs.writeFileSync(path.join(box,'save/test.rpgsave'),'difficulty '+d);
fs.appendFileSync('.sandbox/pool.jsonl', JSON.stringify({event:'start',d,box})+'\n');
const units=process.env.XIYOU_PROBE_UNITS ? new Set(JSON.parse(process.env.XIYOU_PROBE_UNITS)) : null;
const troops=SLICE.troops.filter(t=>!units||units.has(String(t)));
setTimeout(()=>{
const out={difficulty:d,enemies:{},damage:[]};
for (const t of troops) {out.enemies[t]=[{id:t}]; for(const a of [1,8]) out.damage.push({troop:t,actor:a,value:d*100+t*10+a});}
fs.mkdirSync('.sandbox/slice',{recursive:true});
fs.writeFileSync('.sandbox/slice/slice_d'+d+'.json',JSON.stringify(out,null,1));
fs.appendFileSync('.sandbox/pool.jsonl',JSON.stringify({event:'end',d,box})+'\n');
},1000);
''')
        commands = [(['slice_probe.cjs'] + [str(d) for d in range(1, 7)],
                     ['slice/slice_d%d.json' % d for d in range(1, 7)])]
        with mock.patch.multiple(sync, PROBES=commands, ORACLE_DIR=oracle, SANDBOX=oracle / '.sandbox', HERE=tools), \
             mock.patch.dict(os.environ, XIYOU_GENERATED=str(gen), SYNC_JOBS='2'):
            c = self.cache()
            report = sync.run_probes(io.StringIO(), c)
            c.commit()
            self.assertEqual(len(report['commands']), 6)
            events = [json.loads(line) for line in (oracle / '.sandbox/pool.jsonl').read_text().splitlines()]
            active, peak = set(), 0
            for event in events:
                if event['event'] == 'start':
                    active.add(event['d'])
                else:
                    active.remove(event['d'])
                peak = max(peak, len(active))
            self.assertEqual(peak, 2)
            self.assertEqual(len({e['box'] for e in events}), 6)
            self.assertEqual((oracle / '.sandbox/save/test.rpgsave').read_text(), 'fixture seed')
            (tools / 'xiyou_slice.json').write_text('{"troops":[2,3,1]}')
            report = sync.run_probes(io.StringIO(), self.cache())
            self.assertEqual(report['partial'], {'slice_probe.cjs': ['3']})
            incremental = {p.name: p.read_bytes() for p in (gen / 'oracle').glob('slice_d*.json')}
            sync.run_probes(io.StringIO(), None)
            full = {p.name: p.read_bytes() for p in (gen / 'oracle').glob('slice_d*.json')}
            self.assertEqual(incremental, full)
            probe = oracle / 'slice_probe.cjs'
            probe.write_text(probe.read_text().replace("if (process.argv.length", "if (d===3) throw Error('difficulty failed');\nif (process.argv.length"))
            with self.assertRaisesRegex(RuntimeError, '探针失败'):
                sync.run_probes(io.StringIO(), self.cache())
            self.assertEqual(full, {p.name: p.read_bytes() for p in (gen / 'oracle').glob('slice_d*.json')})
            self.assertNotIn('slice_probe.cjs', self.cache().entries)


class ActorInterleaveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    @staticmethod
    def order(actors, troops):
        result = ['a%d' % a for a in actors]
        for t in troops:
            result += ['t%d' % t] + ['t%d:a%d' % (t, a) for a in actors] + ['t%d:enemy' % t]
        return result

    @staticmethod
    def full(actors, troops, changed=()):
        data = {'difficulty': 3, 'actors': {str(a): {'name': 'actor%d' % a} for a in actors},
                'enemies': {str(t): [{'id': t}] for t in troops}, 'damage': []}
        for t in troops:
            for a in actors:
                # 两个同技能行必须原样保留，不能用 skill 当字典键去重。
                for sid in [1, 5, 5]:
                    data['damage'].append({'troop': t, 'actor': a, 'skill': sid,
                                           'value': t * 100 + a + (1000 if (t, a) in changed else 0)})
            data['damage'].append({'troop': t, 'enemy': t, 'target': 9, 'skill': 1, 'value': t})
        return data

    def merge(self, old, fresh, order, ran):
        for name, data in [('old', old), ('fresh', fresh)]:
            (self.root / (name + '.json')).write_text(json.dumps(data))
        spec = {'kind': 'slice-actors', 'order': order, 'ran': ran, 'files': [
            {'old': str(self.root / 'old.json'), 'fresh': str(self.root / 'fresh.json'),
             'out': str(self.root / 'out.json'), 'indent': 1}]}
        (self.root / 'merge.json').write_text(json.dumps(spec))
        return subprocess.run(['node', str(TOOLS / 'oracle_shard_merge.cjs'), str(self.root / 'merge.json')],
                              capture_output=True, text=True)

    def test_add_delete_reorder_and_changed_pair_match_full_bytes(self):
        old = self.full([1, 8], [2, 3])
        variants = [([1, 8, 9], [2, 3], ()), ([8], [2, 3], ()),
                    ([8, 1], [3, 2], ()), ([1, 8], [2, 3, 4], ()), ([1, 8], [2, 3], ((2, 8),))]
        for actors, troops, changed in variants:
            with self.subTest(actors=actors, troops=troops, changed=changed):
                fresh = self.full(actors, troops, changed)
                ran = ['a9'] if 9 in actors else []
                for t in troops:
                    if t == 4:
                        ran += ['t4', 't4:a1', 't4:a8', 't4:enemy']
                    elif 9 in actors:
                        ran += ['t%d:a9' % t]
                ran += ['t%d:a%d' % pair for pair in changed]
                # fresh 只含本次新量的字典／行，防止错误实现借全量 fresh 蒙混通过。
                part = dict(fresh, actors={a: v for a, v in fresh['actors'].items() if 'a' + a in ran},
                            enemies={t: v for t, v in fresh['enemies'].items() if 't' + t in ran},
                            damage=[r for r in fresh['damage'] if ('t%d:a%d' % (r['troop'], r['actor'])
                                    if 'actor' in r else 't%d:enemy' % r['troop']) in ran])
                result = self.merge(old, part, self.order(actors, troops), ran)
                self.assertEqual(result.returncode, 0, result.stderr)
                reference = subprocess.run(['node', '-e', 'process.stdout.write(JSON.stringify(JSON.parse(process.argv[1]),null,1))',
                                            json.dumps(fresh)], capture_output=True, check=True).stdout
                self.assertEqual((self.root / 'out.json').read_bytes(), reference)

    def test_unknown_enemy_target_missing_actor_and_wrong_order_are_rejected(self):
        old = self.full([1, 8], [2])
        order = self.order([1, 8], [2])
        fresh = self.full([1, 8], [2])
        fresh['damage'][-1]['target'] = 8
        self.assertNotEqual(self.merge(old, fresh, order, order).returncode, 0)
        fresh = self.full([1, 8], [2])
        del fresh['actors']['8']
        self.assertNotEqual(self.merge(old, fresh, order, order).returncode, 0)
        self.assertNotEqual(self.merge(old, old, order[::-1], []).returncode, 0)


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

    def test_sync_prunes_stale_manual_copies_only(self):
        """同步正式西游.prune_manual_copies：删 12 小时没动过的 probe-XXXXXX，留新的、别的名字与符号链接。"""
        spec = importlib.util.spec_from_file_location('speedup_manual_prune_test', TOOLS / '同步正式西游.py')
        sync = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(sync)
        box = Path(json.loads(self.run_node('console.log(JSON.stringify(manualSandbox(base)));').stdout))
        manual = self.base / 'manual'
        old, other, outside = manual / 'probe-OLD123', manual / 'keep-me', self.base.parent / 'outside'
        for d in (old, other, outside):
            (d / 'save').mkdir(parents=True)
            (d / 'save/test.rpgsave').write_text('x')
        (manual / 'probe-LNK456').symlink_to(outside)
        day_ago = time.time() - 24 * 3600
        for d in (old, other, outside):
            os.utime(d, (day_ago, day_ago))
        self.assertEqual(sync.prune_manual_copies(self.base), ['probe-OLD123'])
        self.assertFalse(old.exists())
        self.assertTrue(box.exists() and other.exists() and (outside / 'save/test.rpgsave').exists())
        self.assertEqual(sync.prune_manual_copies(self.base / 'missing'), [])

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
