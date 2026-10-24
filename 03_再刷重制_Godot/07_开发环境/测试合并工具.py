#!/usr/bin/env python3
"""新增用例/进度/合并工作流回归；Git 操作仅在临时资料库中进行。"""
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent / '03_转换工具'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


additions = load('oracle_additions', TOOLS / 'oracle_additions.py')
progress = load('progress_tool', HERE / '进度账.py')
merge = load('merge_tool', HERE / '合并车道.py')
sys.path.insert(0, str(TOOLS))
sync = load('sync_tool', TOOLS / '同步正式西游.py')


class AdditionTests(unittest.TestCase):
    def setUp(self):
        self.old = {'sourceIdentity': {'version': 1}, 'cases': [{'id': 'a', 'delta': {'source': 'rule1'}}]}
        self.new = copy.deepcopy(self.old)
        self.new['sourceIdentity'] = {'version': 2}
        self.new['cases'].append({'id': 'b', 'delta': {}})

    def test_additions_by_key(self):
        extra, bad = additions.compare_file('events.json', self.old, self.new)
        self.assertEqual(len(extra), 1); self.assertFalse(bad)

    def test_reordering_is_unchanged(self):
        self.new['cases'].reverse()
        self.assertFalse(additions.compare_file('events.json', self.old, self.new)[1])

    def test_changed_case_is_rejected(self):
        self.new['cases'][0]['delta']['source'] = 'rule2'
        self.assertTrue(additions.compare_file('events.json', self.old, self.new)[1])

    def test_deleted_case_is_rejected(self):
        self.new['cases'].pop(0)
        self.assertTrue(additions.compare_file('events.json', self.old, self.new)[1])

    def test_same_key_changed_or_extra_is_rejected(self):
        self.new['cases'].append({'id': 'a', 'delta': {}})
        self.assertTrue(additions.compare_file('events.json', self.old, self.new)[1])

    def test_duplicate_old_rows_cannot_be_lost(self):
        self.old['cases'].append(copy.deepcopy(self.old['cases'][0]))
        self.assertTrue(additions.compare_file('events.json', self.old, self.new)[1])

    def test_new_errors_are_rejected(self):
        for field, value in [('errors', ['bad']), ('error', 'bad'), ('finished', False)]:
            self.new['cases'][-1] = {'id': 'b', field: value}
            self.assertTrue(additions.compare_file('events.json', self.old, self.new)[1])

    def test_unknown_collection_is_rejected(self):
        self.assertTrue(additions.compare_file('unknown.json', self.old, self.new)[1])

    def test_missing_keys_are_rejected(self):
        self.new['cases'][-1] = {'delta': {}}
        self.assertTrue(additions.compare_file('events.json', self.old, self.new)[1])

    def test_file_removal_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            old, new = Path(folder) / 'old', Path(folder) / 'new'
            old.mkdir(); new.mkdir()
            (old / 'events.json').write_text(json.dumps(self.old))
            self.assertFalse(additions.compare_directories(old, new)['onlyAdditions'])
            self.assertIn('events.json', additions.compare_directories(old, new)['problems'])

    def test_new_reference_from_known_probe(self):
        with tempfile.TemporaryDirectory() as folder:
            old, new = Path(folder) / 'old', Path(folder) / 'new'
            old.mkdir(); new.mkdir()
            (new / 'dungeon.json').write_text(json.dumps({'sourceIdentity': {}, 'cases': [{'id': 1}, {'id': 2}]}))
            result = additions.compare_directories(old, new, {'dungeon.json'})
            self.assertTrue(result['onlyAdditions'])
            self.assertEqual(result['additions']['dungeon.json'][0]['count'], 2)
            # 不在探针产物登记里的新文件、带错误的新参照仍须人工核查
            self.assertFalse(additions.compare_directories(old, new)['onlyAdditions'])
            (new / 'dungeon.json').write_text(json.dumps({'cases': [{'id': 1, 'error': 'boom'}]}))
            self.assertIn('dungeon.json', additions.compare_directories(old, new, {'dungeon.json'})['problems'])

    def test_dungeon_cases_by_id(self):
        old = {'schemaVersion': 1, 'setup': {}, 'cases': [{'id': 'd2.leave', 'steps': [1]}]}
        new = copy.deepcopy(old); new['cases'].append({'id': 'd9.leave', 'steps': [2]})
        self.assertEqual(len(additions.compare_file('dungeon.json', old, new)[0]), 1)
        new['cases'][0]['steps'] = [3]
        self.assertTrue(additions.compare_file('dungeon.json', old, new)[1])

    def test_battle_event_reference_additions_preserve_existing_measurements(self):
        old = {'schemaVersion': 1, 'scan': {'troops': [165, 824]},
               'cases': [{'id': 'transform.pending', 'errors': [],
                          'observed': {'messageBusy': True, 'hp': 123}}]}
        new = copy.deepcopy(old)
        new['cases'].append({'id': 'appear.hidden', 'errors': [], 'observed': {'hidden': False}})
        added, problems = additions.compare_file('battle_events.json', old, new)
        self.assertEqual(len(added), 1)
        self.assertFalse(problems)
        new['cases'][0]['observed']['hp'] = 124
        self.assertTrue(additions.compare_file('battle_events.json', old, new)[1])
        new = copy.deepcopy(old)
        new['cases'].clear()
        self.assertTrue(additions.compare_file('battle_events.json', old, new)[1])

    def test_map_additions_and_changes(self):
        new = {'width': 1, 'height': 1, 'passable': ['f']}
        self.assertFalse(additions.compare_file('maps.json', {'1': {'passable': [1]}}, {'1': {'passable': [1]}, '2': new})[1])
        self.assertTrue(additions.compare_file('maps.json', {'1': {'passable': [1]}}, {'1': {'passable': [0]}, '2': new})[1])
        self.assertTrue(additions.compare_file('maps.json', {}, {'2': {}})[1])

    def test_source_guard(self):
        old = {'releaseVersion': 'v0.28', 'runtimeInputs': {'x': '1'}, 'inputs': {'a': '1'}}
        new = dict(old, inputs={'a': '1', 'b': '2'})
        self.assertTrue(additions.source_preserved(old, new))
        for field, value in [('inputs', {'a': '2'}), ('runtimeInputs', {'x': '2'}), ('releaseVersion', 'v0.29')]:
            self.assertFalse(additions.source_preserved(old, dict(new, **{field: value})))

    def test_mixed_actor_and_enemy_damage(self):
        a = {'damage': [{'troop': 1, 'actor': 1, 'skill': 1, 'value': 10},
                        {'troop': 1, 'enemy': 2, 'target': 9, 'skill': 1, 'value': 2}], 'enemies': {'1': []}}
        b = copy.deepcopy(a)
        b['damage'].append({'troop': 2, 'enemy': 2, 'target': 9, 'skill': 1, 'value': 3})
        self.assertFalse(additions.compare_file('slice_d3.json', a, b)[1])


class DraftTests(unittest.TestCase):
    """交付单的变更记录草稿只取草稿节；交接板等节标题带后缀时也不能贴进变更记录。"""

    def test_suffixed_sections_end_draft_and_later_draft_kept(self):
        sheet = ('# 交付\n- 状态：**可合并**；待核查\n\n## 变更记录草稿\n\n## 2026-10-18 【Codex·沙僧】甲\n\n- a\n\n'
                 '## 2026-10-18 【Codex·沙僧】乙\n\n- b\n\n## 交接板（由唐僧在main并入）\n\n- 板\n\n'
                 '## 用户定案的追加变更记录草稿\n\n## 2026-10-18 【Codex·沙僧】丙\n\n- c\n\n'
                 '## 进度账\n\n- 账\n\n## 本分支提交\n\n- x\n')
        body = merge.draft(sheet)
        self.assertEqual([line for line in body.splitlines() if line.startswith('## ')],
                         ['## 2026-10-18 【Codex·沙僧】甲', '## 2026-10-18 【Codex·沙僧】乙', '## 2026-10-18 【Codex·沙僧】丙'])
        self.assertNotIn('板', body)
        self.assertNotIn('账', body)

    def test_unmarked_or_empty_draft_rejected(self):
        with self.assertRaises(RuntimeError):
            merge.draft('- 状态：进行中\n\n## 变更记录草稿\n\n## 日期 【Claude】x\n')
        with self.assertRaises(RuntimeError):
            merge.draft('- 状态：可合并\n\n## 变更记录草稿\n\n## 交接板\n- y\n')


    def test_placeholder_only_as_whole_line(self):
        ok = '- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude】x\n\n- 修了草稿里出现「待写」二字被拒的问题\n'
        self.assertIn('待写', merge.draft(ok))
        self.assertTrue(merge.draft('状态：**可合并**（八戒）\n\n## 变更记录草稿\n\n## 日期 【Claude】x\n\n- y\n'))
        for line in ['待写', '（待写）', '- 待写']:
            with self.assertRaises(RuntimeError):
                merge.draft('- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude】x\n\n' + line + '\n')

    def test_relink_from_delivery_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / '00_项目管理/规则').mkdir(parents=True)
            (root / '00_项目管理/规则/甲.md').write_text('x')
            (root / 'A.md').write_text('x')
            body = '[甲](../规则/甲.md#节) [乙](规则/甲.md) [根](../../A.md) [外](https://e.x) [缺](../无.md)'
            self.assertEqual(merge.relink(body, root), '[甲](规则/甲.md#节) [乙](规则/甲.md) [根](../A.md) [外](https://e.x) [缺](../无.md)')

    def test_relink_ambiguous_target_follows_delivery_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for rel in ['00_项目管理/交付/README.md', '00_项目管理/README.md', 'README.md',
                        '00_项目管理/交付/附件/甲.md', '00_项目管理/附件/甲.md']:
                (root / rel).parent.mkdir(parents=True, exist_ok=True)
                (root / rel).write_text(rel)
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                out = merge.relink('[a](../README.md) [b](README.md) [c](附件/甲.md#x) [d](../../README.md)', root)
            # ../README.md 按交付目录是 00_项目管理/README.md；README.md 是交付 README；附件/甲.md 是交付目录下那份
            self.assertEqual(out, '[a](README.md) [b](交付/README.md) [c](交付/附件/甲.md#x) [d](../README.md)')
            self.assertEqual(err.getvalue().count('提示'), 3)
            # 两种口径指同一文件时不提示、结果不变
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                self.assertEqual(merge.relink('[e](../../00_项目管理/README.md)', root), '[e](README.md)')
            self.assertEqual(err.getvalue(), '')


class ParallelTestRunnerTests(unittest.TestCase):
    """并行测试.py：偶发重跑、首次与重跑分别保留、慢的先跑、共用并发上限、工程未变时沿用上轮结果。"""
    OK, BAD = 'TEST_RESULT={"passed":1,"total":1}', 'TEST_RESULT={"passed":0,"total":1}'

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.tmp = Path(self.tmpdir.name)
        (self.tmp / 'proj/tests').mkdir(parents=True)
        for n in 'abc':
            (self.tmp / 'proj/tests' / (n + '.tscn')).touch()
        self.state = self.tmp / 'state'
        # 假 Godot：--version 照常回答；每次运行把场景名记进 runs；b 在 seen 不存在时失败一次；FAIL_C 时 c 失败；
        # BUSY 时用 mkdir 当互斥标记，检测同一时刻是否有两个测试在跑
        self.godot = self.tmp / 'godot'
        self.godot.write_text('#!/bin/zsh\nn=${@[-1]:t}\n[[ $n == --version ]] && { echo 4.x; exit 0; }\n'
                              'print -r -- $n >> %(t)s/runs\n'
                              'if [[ -n ${BUSY:-} ]]; then mkdir %(t)s/busy 2>/dev/null || touch %(t)s/overlap; sleep 0.3; rmdir %(t)s/busy 2>/dev/null; fi\n'
                              'if [[ $n == b.tscn && -n ${FLAKY_B:-} && ! -e %(t)s/seen ]]; then touch %(t)s/seen; echo \'%(bad)s\'; exit 1; fi\n'
                              'if [[ $n == c.tscn && -n ${FAIL_C:-} ]]; then echo \'%(bad)s\'; exit 1; fi\necho \'%(ok)s\'\n'
                              % {'t': self.tmp, 'bad': self.BAD, 'ok': self.OK})
        self.godot.chmod(0o755)

    def tearDown(self):
        self.tmpdir.cleanup()

    def run_tests(self, *args, jobs=2, **env):
        (self.tmp / 'runs').unlink(missing_ok=True)
        cmd = [sys.executable, str(HERE / '并行测试.py'), '--jobs', str(jobs), str(self.godot), str(self.tmp / 'proj'), *args]
        base = {k: v for k, v in os.environ.items() if k not in ('CHECK_FULL', 'CHECK_JOBS', 'CHECK_LOG_DIR')}
        env = dict(base, XIYOU_TEST_STATE_DIR=str(self.state), **{'CHECK_GLOBAL_JOBS': '4', **env})
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=env)
        runs = (self.tmp / 'runs').read_text().split() if (self.tmp / 'runs').exists() else []
        return p, runs

    def test_flaky_rerun_and_real_failure(self):
        p, _ = self.run_tests(FLAKY_B='1')
        self.assertEqual(p.returncode, 0, p.stdout)
        self.assertIn('⚠ b.tscn 并行时失败', p.stdout)
        self.assertIn('单独重跑通过', p.stdout)
        p, _ = self.run_tests('--full', FAIL_C='1')
        self.assertEqual(p.returncode, 1, p.stdout)
        self.assertIn('✗ c.tscn', p.stdout)

    def test_rerun_keeps_first_attempt_and_ledger(self):
        logs = self.tmp / 'logs'
        p, _ = self.run_tests('--log-dir', str(logs), FLAKY_B='1')
        self.assertEqual(p.returncode, 0, p.stdout)
        self.assertIn(self.BAD, (logs / 'b.log').read_text())
        self.assertIn(self.OK, (logs / 'b.rerun1.log').read_text())
        row = next(r for r in json.loads((logs / 'test_timings.json').read_text())['scenes'] if r['name'] == 'b.tscn')
        self.assertEqual([(x['rc'], x['passed']) for x in row['attempts']], [(1, False), (0, True)])
        self.assertTrue(row['passed'])
        ledger = [json.loads(l) for l in (self.state / 'flaky.jsonl').read_text().splitlines()]
        self.assertEqual([(r['scene'], len(r['attempts'])) for r in ledger], [('b.tscn', 2)])
        (self.tmp / 'seen').unlink()
        p, _ = self.run_tests('--full', FLAKY_B='1')
        self.assertIn('b.tscn 累计偶发 2 次', p.stdout)
        self.assertEqual(len((self.state / 'flaky.jsonl').read_text().splitlines()), 2)

    def test_slowest_first(self):
        self.state.mkdir()
        (self.state / 'timings.json').write_text(json.dumps({'a.tscn': 1, 'c.tscn': 100}))
        _, runs = self.run_tests(jobs=1)
        self.assertEqual(runs, ['b.tscn', 'c.tscn', 'a.tscn'])  # 没有记录的当作最慢

    def test_unchanged_project_reuses_passes_and_reruns_failures(self):
        p, runs = self.run_tests(jobs=1, FAIL_C='1')
        self.assertEqual((p.returncode, sorted(runs)), (1, ['a.tscn', 'b.tscn', 'c.tscn']))
        p, runs = self.run_tests(jobs=1)
        self.assertEqual((p.returncode, runs), (0, ['c.tscn']), p.stdout)
        self.assertIn('✓ a.tscn {"passed":1,"total":1}（沿用）', p.stdout)
        p, runs = self.run_tests(jobs=1)
        self.assertEqual((p.returncode, runs), (0, []), p.stdout)
        for args, env in [(('--full',), {}), ((), {'CHECK_FULL': '1'})]:
            _, runs = self.run_tests(*args, jobs=1, **env)
            self.assertEqual(sorted(runs), ['a.tscn', 'b.tscn', 'c.tscn'])
        _, runs = self.run_tests('a', 'b', jobs=1)  # 只跑指定场景时不沿用
        self.assertEqual(sorted(runs), ['a.tscn', 'b.tscn'])
        (self.tmp / 'proj/data.json').write_text('{}')  # 工程里任何文件变了都整轮
        _, runs = self.run_tests(jobs=1)
        self.assertEqual(sorted(runs), ['a.tscn', 'b.tscn', 'c.tscn'])
        (self.tmp / 'proj/data.json').write_text('{"x":1}')  # 同大小改内容也算变
        _, runs = self.run_tests(jobs=1)
        self.assertEqual(len(runs), 3)
        (self.tmp / 'proj/.godot').mkdir()
        (self.tmp / 'proj/.godot/cache').write_text('x')  # 导入缓存不算工程输入
        _, runs = self.run_tests(jobs=1)
        self.assertEqual(runs, [])
        (self.tmp / 'proj/tests/d.tscn').touch()  # 新场景：整轮
        _, runs = self.run_tests(jobs=1)
        self.assertEqual(len(runs), 4)
        for f in (self.state / 'results').glob('*.json'):
            f.write_text('坏')  # 记录读不了：整轮
        _, runs = self.run_tests(jobs=1)
        self.assertEqual(len(runs), 4)

    def test_corrupt_or_contradictory_cache_is_not_reused(self):
        # 沙僧 2026-10-21 P2 复现（review_phase2_cache_corruption.json）：passed=true 但 line 是失败计数仍被沿用、退出 0；
        # 合法 JSON 但结构是数组时 AttributeError。两种都应当作没有记录、整轮重跑并正常通过。
        p, runs = self.run_tests(jobs=1)
        self.assertEqual((p.returncode, len(runs)), (0, 3), p.stdout)
        [result] = list((self.state / 'results').glob('*.json'))
        data = json.loads(result.read_text())
        data['scenes']['a.tscn']['line'] = '{"passed":0,"total":999}'
        result.write_text(json.dumps(data))
        p, runs = self.run_tests(jobs=1)
        self.assertEqual((p.returncode, sorted(runs)), (0, ['a.tscn', 'b.tscn', 'c.tscn']), p.stdout)
        self.assertNotIn('沿用', p.stdout)
        self.assertNotIn('"total":999', p.stdout)
        for bad in ([], {'fingerprint': data['fingerprint'], 'scenes': []},
                    {'fingerprint': data['fingerprint'], 'scenes': dict(data['scenes'], **{'b.tscn': ['x']})},
                    {'fingerprint': data['fingerprint'], 'scenes': dict(data['scenes'], **{'b.tscn': {'passed': 1, 'line': '{"passed":1,"total":1}'}})}):
            result.write_text(json.dumps(bad))
            p, runs = self.run_tests(jobs=1)
            self.assertEqual((p.returncode, len(runs)), (0, 3), (bad, p.stdout, p.stderr))
            self.assertNotIn('Traceback', p.stderr)

    def test_heartbeat_while_waiting_and_running(self):
        # 排槽（共用上限 1、另一份占着）与长测试期间按间隔打印进度，免得长任务.py 无输出看门狗误判卡住
        p, _ = self.run_tests('--full', jobs=3, BUSY='1', XIYOU_TEST_HEARTBEAT='0.1', CHECK_GLOBAL_JOBS='1')
        self.assertEqual(p.returncode, 0, p.stdout)
        beats = [l for l in p.stdout.splitlines() if '进行中：完成' in l]
        self.assertTrue(beats, p.stdout)
        self.assertTrue(any('等槽' in l and '在跑' in l for l in beats))
        p, _ = self.run_tests('--full', jobs=3, BUSY='1', XIYOU_TEST_HEARTBEAT='0')
        self.assertNotIn('进行中：完成', p.stdout)

    def test_global_slot_limit_across_runners(self):
        cmd = [sys.executable, str(HERE / '并行测试.py'), '--jobs', '3', '--full', str(self.godot), str(self.tmp / 'proj')]
        base = {k: v for k, v in os.environ.items() if k not in ('CHECK_FULL', 'CHECK_JOBS', 'CHECK_LOG_DIR')}
        env = dict(base, XIYOU_TEST_STATE_DIR=str(self.state), CHECK_GLOBAL_JOBS='1', BUSY='1')
        procs = [subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, env=env) for _ in range(2)]
        outs = [pr.communicate(timeout=60)[0] for pr in procs]
        self.assertEqual([pr.returncode for pr in procs], [0, 0], outs)
        self.assertEqual(len((self.tmp / 'runs').read_text().split()), 6)
        self.assertFalse((self.tmp / 'overlap').exists(), '共用上限 1 时仍有两个测试同时运行')

    def test_sync_probes_share_global_slots(self):
        # 两个假同步（各 3 个线程跑 node 假探针）加一轮假测试同时跑：共用上限 1 时任何时刻只能有一个在跑
        oracle = self.tmp / 'oracle'
        oracle.mkdir()
        (oracle / 'busy.cjs').write_text(
            "const fs = require('fs'), d = process.argv[2];\n"
            "try { fs.mkdirSync(d + '/busy'); } catch (e) { fs.writeFileSync(d + '/overlap', ''); }\n"
            "fs.appendFileSync(d + '/probes', 'p\\n');\n"
            "const t = Date.now(); while (Date.now() - t < 300) {}\n"
            "try { fs.rmdirSync(d + '/busy'); } catch (e) {}\n")
        base = {k: v for k, v in os.environ.items() if k not in ('CHECK_FULL', 'CHECK_JOBS', 'CHECK_LOG_DIR')}
        env = dict(base, XIYOU_TEST_STATE_DIR=str(self.state), CHECK_GLOBAL_JOBS='1', BUSY='1')
        tests = subprocess.Popen([sys.executable, str(HERE / '并行测试.py'), '--jobs', '3', '--full', str(self.godot), str(self.tmp / 'proj')],
                                 stdout=subprocess.PIPE, text=True, env=env)
        import concurrent.futures
        with mock.patch.dict(os.environ, env), mock.patch.object(sync, 'ORACLE_DIR', oracle), \
                concurrent.futures.ThreadPoolExecutor(6) as pool:
            codes = list(pool.map(lambda _: sync.run_node(['busy.cjs', str(self.tmp)], dict(os.environ)).returncode, range(6)))
        out = tests.communicate(timeout=60)[0]
        self.assertEqual((codes, tests.returncode), ([0] * 6, 0), out)
        self.assertEqual(len((self.tmp / 'probes').read_text().split()), 6)
        self.assertEqual(len((self.tmp / 'runs').read_text().split()), 3)
        self.assertFalse((self.tmp / 'overlap').exists(), '共用上限 1 时同步探针与测试仍同时运行')


def ledger():
    return '''## 进度账

| 部分 | 权重 | 完成度 | 计入 | 依据 |
| --- | --- | --- | --- | --- |
| 甲 | 60 | 20% | 12 | fixture |
| 乙 | 40 | 80% | 32 | fixture |
| **合计** | 100 | | **44.0** | fixture |
'''


class ProgressTests(unittest.TestCase):
    def test_round_once(self):
        text = '## 进度账\n| 部分 | 权重 | 完成度 | 计入 |\n| --- | --- | --- | --- |\n'
        values = [(5, 92), (8, 58), (6, 31), (6, 63), (4, 60), (18, 4), (13, 3), (37, 10), (3, 5)]
        for i, (weight, completion) in enumerate(values):
            text += f'| row{i} | {weight} | {completion}% | 0 |\n'
        text += '| **合计** | 100 | | **22.3** |\n'
        result = progress.calculate(text)
        self.assertEqual(str(result['raw']), '22.24')
        self.assertEqual(str(result['rounded']), '22.2')

    def test_invalid_weights_rejected(self):
        with self.assertRaises(ValueError):
            progress.calculate(ledger().replace('| 乙 | 40', '| 乙 | 39'))

    def test_invalid_completion_rejected(self):
        with self.assertRaises(ValueError):
            progress.calculate(ledger().replace('20%', '120%'))

    def test_write_and_check(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / progress.LEDGER).parent.mkdir()
            (root / progress.LEDGER).write_text(ledger())
            (root / progress.STATE).write_text(json.dumps({'progress': {'percent': 43, 'asOf': 'dev.001'}}))
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(progress.main(['--root', folder, '--check']), 1)
                self.assertEqual(progress.main(['--root', folder, '--write', '--as-of', 'dev.002']), 0)
                self.assertEqual(progress.main(['--root', folder, '--check', '--as-of', 'dev.002']), 0)


class SyncRegistrationTests(unittest.TestCase):
    def simulate(self, accept=False, verify=True, changed_source=False, import_error=None):
        with tempfile.TemporaryDirectory(prefix='xiyou_sync_fixture_') as tmp:
            root = Path(tmp); gen = root / 'generated'; app = root / 'app'
            app.mkdir(); (app / 'package.json').write_text('{"releaseVersion":"v0.28"}')
            for name in ['oracle', 'db', 'maps']:
                (gen / name).mkdir(parents=True, exist_ok=True)
            manifest = {'releaseVersion': 'v0.28', 'inputs': {'data/A.json': 'a'},
                        'runtimeInputs': {'js/a.js': 'x'}, 'toolVersion': 14}
            (gen / 'manifest.json').write_text(json.dumps(manifest)); (gen / 'slice.json').write_text('{}')
            (gen / 'oracle/events.json').write_text(json.dumps({'cases': [{'id': 'a', 'trace': []}]}))
            docs = root / '00_项目管理'; docs.mkdir()
            source = docs / '来源登记.json'; state = docs / '当前状态.json'
            source.write_text(json.dumps({'sources': [{'id': 'legacy_xiyou_mod_kyo'}]}))
            state.write_text(json.dumps({'remakeSource': {}}))
            before = source.read_bytes()

            def export(*args):
                new_manifest = copy.deepcopy(manifest)
                new_manifest['inputs']['data/B.json'] = 'b'
                if changed_source:
                    new_manifest['runtimeInputs']['js/a.js'] = 'changed'
                (gen / 'manifest.json').write_text(json.dumps(new_manifest))
                (gen / 'oracle/events.json').write_text(json.dumps({'cases': [{'id': 'a', 'trace': []}, {'id': 'b', 'trace': []}]}))

            def external(args, **kwargs):
                if args[0] == 'git':
                    return subprocess.CompletedProcess(args, 0, '/fixture/.git\n/fixture/.git\n', '')
                return subprocess.CompletedProcess(args, 0 if verify else 1, '{"issues":[]}\n', '')

            argv = ['sync', '--app', str(app), '--generated', str(gen)] + (['--accept-additions'] if accept else [])
            with mock.patch.object(sync, 'ROOT', root), mock.patch.object(sync, 'PROBES', []), \
                 mock.patch.object(sync, 'run', export), mock.patch.object(sync.subprocess, 'run', external), \
                 mock.patch.object(sync, 'godot_import', side_effect=import_error), \
                 mock.patch.object(sys, 'argv', argv), mock.patch.dict(os.environ), contextlib.redirect_stdout(io.StringIO()):
                rc = sync.main()
            return rc, before != source.read_bytes(), json.loads(state.read_text())

    def test_flag_required_for_registration(self):
        self.assertEqual(self.simulate()[:2], (2, False))

    def test_accepts_and_updates_counts(self):
        rc, registered, state = self.simulate(accept=True)
        self.assertEqual((rc, registered), (0, True))
        self.assertEqual(state['remakeSource']['fingerprintedFiles'], 2)

    def test_failed_verification_never_registers(self):
        self.assertEqual(self.simulate(accept=True, verify=False)[:2], (2, False))

    def test_changed_runtime_never_auto_accepts(self):
        self.assertEqual(self.simulate(accept=True, changed_source=True)[:2], (2, False))

    def test_import_failure_never_registers(self):
        self.assertEqual(self.simulate(accept=True, import_error=RuntimeError('fixture import error'))[:2], (2, False))

    def test_import_error_with_zero_exit_is_rejected(self):
        with mock.patch.object(sync.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'SCRIPT ERROR: bad script\n', '')):
            with self.assertRaises(RuntimeError):
                sync.godot_import(io.StringIO())

    def test_import_nonzero_exit_is_rejected(self):
        with mock.patch.object(sync.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'bad import')):
            with self.assertRaises(RuntimeError):
                sync.godot_import(io.StringIO())


class SyncStampTests(unittest.TestCase):
    """提速提案 P3：同步写产物指纹；合并时按指纹直接用车道产物，不满足就退出码 3 且不动 main。"""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xiyou_stamp_fixture_')
        self.root = Path(self.tmp.name).resolve() / 'main'
        self.lane = Path(self.tmp.name).resolve() / 'lane'
        rel = Path('03_再刷重制_Godot/01_Godot工程/modes/xiyou/generated')
        self.gen, self.lane_gen = self.root / rel, self.lane / rel
        for gen, extra in [(self.gen, []), (self.lane_gen, [{'id': 'b', 'trace': []}])]:
            (gen / 'oracle').mkdir(parents=True); (gen / 'db').mkdir(); (gen / 'maps').mkdir()
            (gen / 'manifest.json').write_text(json.dumps({'releaseVersion': 'v0.28', 'inputs': {'a': '1'}, 'runtimeInputs': {'r': '1'}}))
            (gen / 'slice.json').write_text('{}')
            (gen / 'oracle/events.json').write_text(json.dumps({'cases': [{'id': 'a', 'trace': []}] + extra}))
        docs = self.root / '00_项目管理'; docs.mkdir()
        (docs / '来源登记.json').write_text(json.dumps({'sources': [{'id': 'legacy_xiyou_mod_kyo'}]}))
        (docs / '当前状态.json').write_text(json.dumps({'remakeSource': {}}))
        self.app = Path(self.tmp.name) / 'app'; self.app.mkdir()
        (self.app / 'package.json').write_text('{"releaseVersion":"v0.28"}')

    def tearDown(self):
        self.tmp.cleanup()

    def sync_main(self, *extra, tools=lambda root=None: 'same'):
        def external(args, **kwargs):
            if args[0] == 'git':
                return subprocess.CompletedProcess(args, 0, '', '')
            if args[0] == 'cp':
                return subprocess.CompletedProcess(args, 1, '', '')
            return subprocess.CompletedProcess(args, 0, '{"issues":[]}\n', '')
        argv = ['sync', '--app', str(self.app), '--generated', str(self.gen), '--accept-additions', '--no-import', *extra]
        with mock.patch.object(sync, 'ROOT', self.root), mock.patch.object(sync, 'run', lambda *a: None), \
             mock.patch.object(sync, 'PROBES', []), mock.patch.object(sync, 'tools_digest', tools), mock.patch.object(sync.subprocess, 'run', external), \
             mock.patch.object(sys, 'argv', argv), mock.patch.dict(os.environ), contextlib.redirect_stdout(io.StringIO()):
            return sync.main()

    def lane_stamp(self, tools='same'):
        stamp = {'toolsDigest': tools, 'outputsDigest': sync.outputs_digest(self.lane_gen)}
        (self.lane_gen / sync.STAMP).write_text(json.dumps(stamp))

    def test_full_sync_writes_stamp(self):
        self.assertEqual(self.sync_main(), 0)
        stamp = json.loads((self.gen / sync.STAMP).read_text())
        self.assertEqual(stamp['outputsDigest'], sync.outputs_digest(self.gen))

    def test_missing_or_mismatched_stamp_leaves_main_untouched(self):
        before = (self.gen / 'oracle/events.json').read_bytes()
        self.assertEqual(self.sync_main('--from-worktree', str(self.lane)), 3)        # 没有指纹
        self.lane_stamp(tools='other')
        self.assertEqual(self.sync_main('--from-worktree', str(self.lane)), 3)        # 转换工具不同
        self.lane_stamp()
        (self.lane_gen / 'slice.json').write_text('{"x":1}')
        self.assertEqual(self.sync_main('--from-worktree', str(self.lane)), 3)        # 同步后产物被改
        self.assertEqual((self.gen / 'oracle/events.json').read_bytes(), before)

    def test_matching_stamp_clones_and_registers(self):
        self.lane_stamp()
        self.assertEqual(self.sync_main('--from-worktree', str(self.lane)), 0)
        self.assertEqual(sync.outputs_digest(self.gen), sync.outputs_digest(self.lane_gen))
        state = json.loads((self.root / '00_项目管理/当前状态.json').read_text())
        self.assertIn('fingerprint', state['remakeSource'])

    def test_self_clone_leaves_all_outputs_untouched(self):
        before = sync.outputs_digest(self.gen)
        self.assertEqual(self.sync_main('--from-worktree', str(self.root)), 3)
        self.assertEqual(sync.outputs_digest(self.gen), before)

    def test_malformed_stamp_falls_back_without_writes(self):
        for text in ['{bad json', 'null', '[]']:
            (self.lane_gen / sync.STAMP).write_text(text)
            before = sync.outputs_digest(self.gen)
            self.assertEqual(self.sync_main('--from-worktree', str(self.lane)), 3)
            self.assertEqual(sync.outputs_digest(self.gen), before)


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xiyou_merge_fixture_')
        self.root = Path(self.tmp.name) / 'main'
        self.root.mkdir()
        self.old_env = {k: os.environ.get(k) for k in ['GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL']}
        for kind in ['AUTHOR', 'COMMITTER']:
            os.environ['GIT_' + kind + '_NAME'] = 'fixture'
            os.environ['GIT_' + kind + '_EMAIL'] = 'fixture@example.invalid'
        self.g('init', '-b', 'main')
        env = self.root / merge.ENV
        env.mkdir(parents=True)
        for name in ['开发编号.py', '进度账.py', '清理工作树.sh']:
            shutil.copy2(HERE / name, env / name)
        checker = env / '检查.sh'
        checker.write_text('#!/bin/zsh\nexit 0\n'); checker.chmod(0o755)
        self.put('00_项目管理/重制步骤清单.md', ledger())
        self.put('00_项目管理/当前状态.json', json.dumps({'godot': {'developmentVersion': 'dev.001'}, 'progress': {'percent': 44, 'asOf': 'dev.001'}}))
        self.put('00_项目管理/来源登记.json', json.dumps({'sources': [{'id': 'new_godot_remake', 'developmentVersion': 'dev.001'}]}))
        self.put(str(merge.SUB / '开发编号.json'), json.dumps({'current': 'dev.001', 'next': 'dev.002', 'sequence': 1, 'nextSequence': 2}))
        self.put(str(merge.PROJECT / 'project.godot'), 'config/version="dev.001"\n')
        self.put(str(merge.PROJECT / 'content/build_info.json'), json.dumps({'developmentVersion': 'dev.001'}))
        self.put(str(merge.BOARD), '# board\n## 正在进行\n| claude/task |\n## 待交叉核查\n\n## end\n')
        self.put(str(merge.LOG), '# log\n')
        self.g('add', '.'); self.g('commit', '-m', 'base')
        self.wt = Path(self.tmp.name) / 'lane'
        self.g('worktree', 'add', '-b', 'claude/task', str(self.wt))
        self.receipt = Path('00_项目管理/交付/claude_task.md')
        (self.wt / self.receipt).parent.mkdir(parents=True)
        (self.wt / self.receipt).write_text('# delivery\n- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude】功能（' + merge.VERSION_MARKER + '）\n\n- fixture change\n\n## 交接板\n- fixture\n')
        code = self.wt / merge.PROJECT / 'modes/测试.gd'
        code.parent.mkdir(parents=True); code.write_text('# fixture\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'feature', cwd=self.wt)

    def tearDown(self):
        for key, value in self.old_env.items():
            if value is None: os.environ.pop(key, None)
            else: os.environ[key] = value
        self.tmp.cleanup()

    def put(self, path, text):
        p = self.root / path; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(text)

    def g(self, *args, cwd=None):
        return subprocess.run(['git', '-C', str(cwd or self.root), *args], capture_output=True, text=True, check=True).stdout.strip()

    def call(self, *args):
        result = subprocess.run([sys.executable, str(HERE / '合并车道.py'), 'task', '--root', str(self.root), *args],
                                capture_output=True, text=True)
        self.last_output = result.stdout + result.stderr
        return result.returncode

    def register(self):
        self.put(str(merge.BOARD), '# board\n## 正在进行\n\n## 待交叉核查\n| claude/task | Codex |\n## end\n')

    def realistic_checker(self):
        # 模拟检查.sh 的真实入口：从 Git 索引取文件清单，再看工作区内容。
        # 原来的 exit 0 替身看不到“文件删了但索引仍跟踪”的交付单。
        checker = self.root / merge.ENV / '检查.sh'
        checker.write_text('#!' + sys.executable + '''
import subprocess
from pathlib import Path
files = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\\0')
marker = 'dev.' + '待定'
for name in filter(None, files):
    path = Path(name)
    if name.startswith('00_项目管理/交付/') and path.name != 'README.md':
        raise SystemExit('交付单未并入：' + name)
    if path.suffix == '.md' and path.is_file() and marker in path.read_text():
        raise SystemExit('编号占位未替换：' + name)
''')
        self.g('add', str(merge.ENV / '检查.sh')); self.g('commit', '-m', 'realistic checker')
        self.g('merge', 'main', cwd=self.wt)

    def lane_document(self):
        rel = merge.SUB / '00_设计/界面风格.md'
        p = self.wt / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text('# 界面风格\n' + merge.VERSION_MARKER + '：已完成；参见 ' + merge.VERSION_MARKER + '。\n')
        self.g('add', str(rel), cwd=self.wt); self.g('commit', '-m', 'lane document', cwd=self.wt)
        return rel

    def test_real_checker_sees_receipt_deletion(self):
        self.realistic_checker()
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertFalse(self.wt.exists())

    def test_version_replacement_in_lane_document(self):
        self.realistic_checker()
        rel = self.lane_document()
        self.assertEqual(self.call(), 0, self.last_output)
        text = (self.root / rel).read_text()
        self.assertNotIn(merge.VERSION_MARKER, text)
        self.assertEqual(text.count('dev.002'), 2)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertFalse(merge.dirty(self.root))

    def test_version_document_extra_edit_is_preserved_and_rejected(self):
        rel = self.lane_document()
        self.assertEqual(self.call(), 0, self.last_output)
        p = self.root / rel
        p.write_text(p.read_text() + 'unrelated edit\n')
        self.register()
        self.assertEqual(self.call('--finish'), 1, self.last_output)
        self.assertTrue(p.read_text().endswith('unrelated edit\n'))
        self.assertNotIn(str(rel), self.g('diff', '--cached', '--name-only').splitlines())
        self.assertTrue(self.wt.exists())

    def test_resume_version_replacement_after_plan_saved(self):
        rel = self.lane_document()
        original = (self.wt / rel).read_bytes()
        self.assertEqual(self.call(), 0, self.last_output)
        path = self.root / '.git/lane-merge/state.json'
        state = json.loads(path.read_text())
        state['phase'] = 'versioned'
        path.write_text(json.dumps(state))
        (self.root / rel).write_bytes(original)
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertEqual((self.root / rel).read_text().count('dev.002'), 2)
        self.assertEqual((self.root / merge.LOG).read_text().count('fixture change'), 1)
        self.assertEqual(json.loads((self.root / merge.SUB / '开发编号.json').read_text())['current'], 'dev.002')
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)

    def test_resume_version_replacement_never_overwrites_extra_edit(self):
        rel = self.lane_document()
        self.assertEqual(self.call(), 0, self.last_output)
        path = self.root / '.git/lane-merge/state.json'
        state = json.loads(path.read_text())
        state['phase'] = 'versioned'
        path.write_text(json.dumps(state))
        p = self.root / rel
        p.write_text(p.read_text() + 'keep this edit\n')
        self.assertEqual(self.call(), 1, self.last_output)
        self.assertTrue(p.read_text().endswith('keep this edit\n'))
        self.assertTrue(self.wt.exists())

    def test_lane_acceptance_sheet_is_passed_to_main_sync(self):
        spec = merge.ACCEPT / 'claude_task.json'
        (self.wt / spec).parent.mkdir(parents=True)
        (self.wt / spec).write_text('{"schema": 1, "accept": []}')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'acceptance', cwd=self.wt)
        state = merge.plan(self.root, 'task')
        self.assertEqual((state['acceptChanges'], state['refresh']), ([str(spec)], True))
        state.update(phase='merged', head=self.g('rev-parse', 'HEAD'))
        calls, real = [], subprocess.run

        def fake(cmd, **kw):
            if cmd[0] == 'git':
                return real(cmd, **kw)
            calls.append(cmd)
            return subprocess.CompletedProcess(cmd, 0)
        with mock.patch.object(merge.subprocess, 'run', side_effect=fake), \
             mock.patch.object(merge, 'save'), mock.patch.object(merge, 'replace_versions', side_effect=RuntimeError('stop')):
            with self.assertRaisesRegex(RuntimeError, 'stop'):
                merge.prepare(self.root, state, self.root / 'state.json', 'Claude')
        self.assertIn('--accept-changes', calls[0])
        self.assertEqual(calls[0][calls[0].index('--accept-changes') + 1], str(spec))

    def test_dry_run_is_read_only(self):
        head = self.g('rev-parse', 'HEAD')
        self.assertEqual(self.call('--dry-run'), 0)
        self.assertEqual(head, self.g('rev-parse', 'HEAD'))
        self.assertFalse((self.root / '.git/lane-merge').exists())

    def test_success_and_repeat_prepare(self):
        self.assertEqual(self.call(), 0)
        self.assertTrue(self.wt.exists())
        self.assertFalse((self.root / self.receipt).exists())
        self.assertEqual(self.call(), 0)
        self.assertEqual(json.loads((self.root / merge.SUB / '开发编号.json').read_text())['current'], 'dev.002')
        self.assertEqual((self.root / merge.LOG).read_text().count('fixture change'), 1)
        self.register()
        self.assertEqual(self.call('--finish'), 0)
        self.assertFalse(self.wt.exists())
        self.assertFalse(merge.dirty(self.root))

    def test_main_untracked_is_preserved(self):
        self.put('untracked', 'keep')
        self.assertEqual(self.call(), 1)
        self.assertEqual((self.root / 'untracked').read_text(), 'keep')
        self.assertTrue(self.wt.exists())

    def test_resume_after_receipt_removed_before_state_saved(self):
        self.assertEqual(self.call(), 0)
        path = self.root / '.git/lane-merge/state.json'
        state = json.loads(path.read_text())
        state['phase'] = 'versioned'
        path.write_text(json.dumps(state))
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertEqual((self.root / merge.LOG).read_text().count('fixture change'), 1)
        self.assertEqual(json.loads((self.root / merge.SUB / '开发编号.json').read_text())['current'], 'dev.002')
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)

    def test_missing_receipt_without_log_marker_stops(self):
        self.assertEqual(self.call(), 0)
        path = self.root / '.git/lane-merge/state.json'
        state = json.loads(path.read_text())
        state['phase'] = 'versioned'
        path.write_text(json.dumps(state))
        self.put(str(merge.LOG), '# missing draft\n')
        self.assertEqual(self.call(), 1)
        self.assertTrue(self.wt.exists())
        self.assertFalse(self.g('diff', '--cached', '--name-only'))

    def test_lane_dirty_is_preserved(self):
        (self.wt / 'untracked').write_text('keep')
        self.assertEqual(self.call(), 1)
        self.assertTrue((self.wt / 'untracked').exists())

    def test_manual_registration_required(self):
        self.assertEqual(self.call(), 0)
        self.assertEqual(self.call('--finish'), 1)
        self.assertTrue(self.wt.exists())

    def test_failed_check_keeps_worktree(self):
        self.put(str(merge.ENV / '检查.sh'), '#!/bin/zsh\nexit 1\n')
        self.g('add', '.'); self.g('commit', '-m', 'failing checker')
        self.g('merge', 'main', cwd=self.wt)
        self.assertEqual(self.call(), 0)
        self.register()
        self.assertEqual(self.call('--finish'), 1)
        self.assertTrue(self.wt.exists())
        self.assertTrue((self.root / '.git/lane-merge/state.json').exists())

    def test_unexpected_file_not_staged(self):
        self.assertEqual(self.call(), 0)
        self.register(); self.put('unrelated', 'keep')
        self.assertEqual(self.call('--finish'), 1)
        self.assertTrue(self.wt.exists())
        self.assertFalse(self.g('diff', '--cached', '--name-only'))

    def test_lock_is_not_removed_by_second_runner(self):
        lock = self.root / '.git/lane-merge/running.lock'
        lock.parent.mkdir(); lock.write_text('first runner')
        self.assertEqual(self.call(), 1)
        self.assertEqual(lock.read_text(), 'first runner')

    def test_other_lane_merge_does_not_require_redelivery(self):
        self.put('other_lane.md', 'independent main update')
        self.g('add', '.'); self.g('commit', '-m', 'other lane')
        self.assertTrue(merge.plan(self.root, 'task')['mainAdvancedAfterDelivery'])
        self.assertEqual(self.call(), 0)
        self.register()
        self.assertEqual(self.call('--finish'), 0)

    def github(self, url=None):
        # 临时裸库充当 GitHub；先放入合并前的 main。
        bare = Path(self.tmp.name) / 'github.git'
        if url is None:
            subprocess.run(['git', 'init', '--bare', '-b', 'main', str(bare)], capture_output=True, check=True)
            # push 返回后后台自动维护仍可能写裸库，与临时目录清理竞争；夹具不需要维护。
            self.g('config', 'receive.autoGC', 'false', cwd=bare)
            url = str(bare)
        self.g('remote', 'add', 'github', url)
        if url == str(bare):
            self.g('push', 'github', 'main')
        return bare

    def merge_and_finish(self):
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertFalse(self.wt.exists())
        self.assertFalse((self.root / '.git/lane-merge/state.json').exists())

    def test_finish_pushes_main_to_github(self):
        bare = self.github()
        self.merge_and_finish()
        self.assertIn('已推送 main', self.last_output)
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))

    def batch_fixture(self, check_rc=0):
        """第二条车道 task2，检查.sh 换成每跑一次记一行、按 check_rc 退出的替身。"""
        checks = Path(self.tmp.name) / 'checks'
        checker = self.root / merge.ENV / '检查.sh'
        checker.write_text('#!/bin/zsh\necho run >> %s\nexit ${CHECK_RC:-%d}\n' % (checks, check_rc)); checker.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'counting checker')
        wt2 = Path(self.tmp.name) / 'lane2'
        self.g('worktree', 'add', '-b', 'claude/task2', str(wt2))
        receipt = wt2 / '00_项目管理/交付/claude_task2.md'
        receipt.parent.mkdir(parents=True, exist_ok=True)
        receipt.write_text('# delivery\n- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude】第二条（' + merge.VERSION_MARKER + '）\n\n- second change\n\n## 交接板\n- fixture\n')
        (wt2 / 'docs2.md').write_text('second lane\n')
        self.g('add', '.', cwd=wt2); self.g('commit', '-m', 'feature 2', cwd=wt2)
        return wt2, checks

    def call_task(self, task, *args):
        result = subprocess.run([sys.executable, str(HERE / '合并车道.py'), task, '--root', str(self.root), *args],
                                capture_output=True, text=True)
        self.last_output = result.stdout + result.stderr
        return result.returncode

    def register_both(self):
        self.put(str(merge.BOARD), '# board\n## 正在进行\n\n## 待交叉核查\n| claude/task | claude/task2 | Codex |\n## end\n')

    def test_batch_merge_checks_once_then_cleans_and_pushes(self):
        bare = self.github()
        wt2, checks = self.batch_fixture()
        self.assertEqual(self.call('--batch'), 1)  # --batch 只配 --finish
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.assertFalse(checks.exists())
        self.assertTrue(self.wt.exists())
        self.assertNotEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))
        self.assertEqual(self.call('--finish', '--batch'), 1)  # 已收尾，没有准备中的合并
        self.assertEqual(self.call_task('task2'), 0, self.last_output)
        self.assertIn('本批已有 1 条收尾未检查（task）', self.last_output)
        self.register_both()
        self.assertEqual(self.call_task('task2', '--finish'), 0, self.last_output)
        self.assertEqual(checks.read_text().split(), ['run'])
        self.assertFalse(self.wt.exists())
        self.assertFalse(wt2.exists())
        self.assertFalse((self.root / '.git/lane-merge/batch.json').exists())
        self.assertIn('本批共 2 条', self.last_output)
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))
        log = self.g('log', '--format=%s', '-6')
        self.assertIn('合并 claude/task（dev.002）收尾', log)
        self.assertIn('合并 claude/task2（dev.002）收尾', log)

    def test_batch_final_check_failure_keeps_worktrees_and_does_not_push(self):
        bare = self.github()
        wt2, checks = self.batch_fixture(check_rc=1)
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.assertEqual(self.call_task('task2'), 0, self.last_output)
        self.register_both()
        before = self.g('rev-parse', 'main', cwd=bare)
        self.assertEqual(self.call_task('task2', '--finish'), 1, self.last_output)
        self.assertTrue(self.wt.exists() and wt2.exists())
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), before)
        self.assertTrue((self.root / '.git/lane-merge/batch.json').exists())
        os.environ['CHECK_RC'] = '0'
        try:
            self.assertEqual(self.call_task('task2', '--finish'), 0, self.last_output)  # 修好后重跑同一命令接续
        finally:
            os.environ.pop('CHECK_RC')
        self.assertFalse(self.wt.exists() or wt2.exists())
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))

    def test_batch_failure_lists_lanes_and_abort_restores_base(self):
        bare = self.github()
        wt2, _ = self.batch_fixture(check_rc=1)
        base, pushed = self.g('rev-parse', 'HEAD'), self.g('rev-parse', 'main', cwd=bare)
        self.assertEqual(self.call_task('x', '--abort-batch'), 1)  # 没有攒着的批
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.assertEqual(self.call_task('task2'), 0, self.last_output)
        self.register_both()
        self.assertEqual(self.call_task('task2', '--finish'), 1, self.last_output)
        self.assertIn('本批最后的检查未通过', self.last_output)
        self.assertRegex(self.last_output, r'- task（claude/task）合并提交 \w+，\d+ 个文件：.*测试\.gd')
        self.assertRegex(self.last_output, r'- task2（claude/task2）合并提交 \w+，\d+ 个文件：.*docs2\.md')
        failed_head = self.g('rev-parse', 'HEAD')
        args = [sys.executable, str(HERE / '合并车道.py'), '--root', str(self.root), '--abort-batch']
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.g('rev-parse', 'HEAD'), base)
        self.assertFalse(merge.dirty(self.root))
        refs = self.g('for-each-ref', '--format=%(refname) %(objectname)', 'refs/lane-merge/').splitlines()
        self.assertIn(failed_head, [r.split()[1] for r in refs if not r.split()[0].endswith('-wip')])
        self.assertTrue(any(r.split()[0].endswith('-wip') for r in refs))  # 未提交的登记改动也存了
        self.assertTrue(self.wt.exists() and wt2.exists())
        self.assertFalse((self.root / '.git/lane-merge/batch.json').exists())
        self.assertFalse((self.root / '.git/lane-merge/state.json').exists())
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), pushed)  # GitHub 始终没动
        # 撤出 task2，只把 task 重新合
        (self.root / merge.ENV / '检查.sh').write_text('#!/bin/zsh\nexit 0\n')
        self.g('commit', '-am', 'fixed checker')
        self.g('merge', 'main', cwd=self.wt)
        self.merge_and_finish()
        self.assertTrue(wt2.exists())

    def test_abort_refuses_pushed_batch(self):
        self.github()
        self.batch_fixture()
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.g('push', 'github', 'main')
        self.assertEqual(self.call_task('x', '--abort-batch'), 1)
        self.assertIn('已推送到 GitHub', self.last_output)

    def test_unreachable_github_only_warns(self):
        self.github(str(Path(self.tmp.name) / 'missing.git'))
        self.merge_and_finish()
        self.assertIn('警告：推送 github 失败', self.last_output)
        self.assertIn('收尾', self.g('log', '-1', '--format=%s'))

    def test_github_ahead_is_never_overwritten(self):
        bare = self.github()
        other = Path(self.tmp.name) / 'other'
        subprocess.run(['git', 'clone', '-q', str(bare), str(other)], check=True)
        (other / 'web.md').write_text('edited on GitHub\n')
        self.g('add', '.', cwd=other); self.g('commit', '-m', 'remote only change', cwd=other)
        self.g('push', 'origin', 'main', cwd=other)
        remote_head = self.g('rev-parse', 'main', cwd=bare)
        self.merge_and_finish()
        self.assertIn('remote only change', self.last_output)
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), remote_head)
        self.assertNotIn('remote only change', self.g('log', '--format=%s', 'main'))

    def test_merge_conflict_keeps_both_worktrees(self):
        self.put(str(merge.PROJECT / 'modes/测试.gd'), '# main version\n')
        self.g('add', '.'); self.g('commit', '-m', 'conflicting main update')
        self.assertEqual(self.call(), 1)
        self.assertTrue((self.root / '.git/MERGE_HEAD').exists())
        self.assertTrue(self.wt.exists())
        self.assertIn('<<<<<<<', (self.root / merge.PROJECT / 'modes/测试.gd').read_text())

    def test_conflict_resolved_then_rerun_commits_and_continues(self):
        self.put(str(merge.PROJECT / 'modes/测试.gd'), '# main version\n')
        self.g('add', '.'); self.g('commit', '-m', 'conflicting main update')
        self.assertEqual(self.call(), 1)
        self.assertIn('解决后 git add', self.last_output)
        self.assertEqual(self.call(), 1)
        self.assertIn('冲突尚未解决', self.last_output)
        self.put(str(merge.PROJECT / 'modes/测试.gd'), '# resolved\n')
        self.g('add', str(merge.PROJECT / 'modes/测试.gd'))
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertIn('执行者: Claude（唐僧）', self.g('log', '-1', '--skip=0', '--format=%B', 'HEAD^{commit}'))
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertEqual((self.root / merge.PROJECT / 'modes/测试.gd').read_text(), '# resolved\n')

    def test_abort_and_lane_redelivery_replans(self):
        self.put(str(merge.PROJECT / 'modes/测试.gd'), '# main version\n')
        self.g('add', '.'); self.g('commit', '-m', 'conflicting main update')
        self.assertEqual(self.call(), 1)
        self.g('merge', '--abort')
        # 车道合 main、自己解冲突后重新交付
        subprocess.run(['git', '-C', str(self.wt), 'merge', 'main'], capture_output=True)
        (self.wt / merge.PROJECT / 'modes/测试.gd').write_text('# lane resolved\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'merge main', cwd=self.wt)
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertEqual((self.root / merge.PROJECT / 'modes/测试.gd').read_text(), '# lane resolved\n')

    def test_second_delivery_sheet_merged_and_removed(self):
        second = Path('00_项目管理/交付/claude_task_接续.md')
        (self.wt / second).write_text('# 接续\n- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude·八戒】接续验收\n\n'
                                      '- 见[规则](../规则/甲.md)\n')
        (self.wt / '00_项目管理/规则').mkdir()
        (self.wt / '00_项目管理/规则/甲.md').write_text('rule\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'second sheet', cwd=self.wt)
        self.realistic_checker()
        self.merge_and_finish()
        log = (self.root / merge.LOG).read_text()
        self.assertIn('fixture change', log)
        self.assertIn('[规则](规则/甲.md)', log)
        self.assertFalse((self.root / second).exists())

    def branches(self):
        return self.g('branch', '--format=%(refname:short)').split()

    def test_lane_on_new_branch_skips_worktree_but_deletes_delivery_branch(self):
        # 车道交付后在同一工作树换新分支接着做（会话绑在路径上）：工作树保留，交付分支照删。
        self.assertEqual(self.call(), 0, self.last_output)
        self.g('switch', '-c', 'claude/task-2', cwd=self.wt)
        (self.wt / 'next.md').write_text('phase 2\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'phase 2', cwd=self.wt)
        (self.wt / 'wip.md').write_text('uncommitted\n')
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertIn('跳过清理', self.last_output)
        self.assertTrue((self.wt / 'wip.md').exists())
        self.assertEqual(self.g('branch', '--show-current', cwd=self.wt), 'claude/task-2')
        self.assertNotIn('claude/task', self.branches())
        self.assertIn('claude/task-2', self.branches())
        self.assertFalse((self.root / '.git/lane-merge/state.json').exists())
        self.assertIn('合并 claude/task（dev.002）收尾', self.g('log', '--format=%s', '-1'))

    def test_lane_switched_before_prepare_merges_branch_ref(self):
        # 交付后、总装准备前车道就换了新分支：按交付分支引用合并，不带进新分支的提交
        delivered = self.g('rev-parse', 'HEAD', cwd=self.wt)
        self.g('switch', '-c', 'claude/task-2', cwd=self.wt)
        (self.wt / 'next.md').write_text('phase 2\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'phase 2', cwd=self.wt)
        (self.wt / 'wip.md').write_text('uncommitted\n')
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertIn('按分支引用', self.last_output)
        self.assertEqual(self.g('rev-parse', 'HEAD^2'), delivered)
        self.assertFalse((self.root / 'next.md').exists())
        self.assertIn('fixture change', (self.root / merge.LOG).read_text())
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertTrue((self.wt / 'wip.md').exists())
        self.assertEqual(self.branches(), ['claude/task-2', 'main'])

    def test_branch_ref_lane_with_synced_slice_runs_full_sync(self):
        # 没有工作树可取同步产物指纹：直接跑完整同步，不传 --from-worktree
        slice_ = self.wt / merge.TOOLS / 'xiyou_slice.json'
        slice_.parent.mkdir(parents=True, exist_ok=True); slice_.write_text('{}\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'slice', cwd=self.wt)
        self.g('switch', '-c', 'claude/task-2', cwd=self.wt)
        calls = []
        orig = merge.run
        merge.run = lambda root, args: calls.append(list(map(str, args)))
        try:
            state = merge.plan(self.root, 'task')
            self.assertEqual(state['worktree'], '')
            self.assertTrue(state['refresh'])
            state_file = Path(self.tmp.name) / 'state.json'
            state['phase'] = 'merged'
            merge.prepare(self.root, dict(state, phase='merged', head=self.g('rev-parse', 'HEAD')), state_file, 'Claude')
        except RuntimeError:
            pass
        finally:
            merge.run = orig
        self.assertTrue(calls and calls[0][-1] == '--accept-additions', calls)
        self.assertFalse(any('--from-worktree' in c for c in calls))

    def test_lane_new_commit_or_dirty_on_same_branch_keeps_both(self):
        for case in ['commit', 'dirty']:
            with self.subTest(case=case):
                self.tearDown(); self.setUp()
                self.assertEqual(self.call(), 0, self.last_output)
                (self.wt / 'later.md').write_text('later\n')
                if case == 'commit':
                    self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'later', cwd=self.wt)
                self.register()
                self.assertEqual(self.call('--finish'), 0, self.last_output)
                self.assertTrue((self.wt / 'later.md').exists())
                self.assertIn('claude/task', self.branches())
                self.assertIn('仍是该工作树的当前分支', self.last_output)

    def test_lane_on_new_branch_without_commits_is_not_removed(self):
        # 新分支还没提交（HEAD 仍是交付提交、干净）：也不能删工作树和新分支。
        self.assertEqual(self.call(), 0, self.last_output)
        self.g('switch', '-c', 'claude/task-2', cwd=self.wt)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertTrue(self.wt.exists())
        self.assertEqual(self.branches(), ['claude/task-2', 'main'])

    def test_batch_cleans_finished_lane_and_skips_continuing_one(self):
        wt2, checks = self.batch_fixture()
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.g('switch', '-c', 'claude/task-2', cwd=self.wt)  # 第一条在批中途接着做
        self.assertEqual(self.call_task('task2'), 0, self.last_output)
        self.register_both()
        self.assertEqual(self.call_task('task2', '--finish'), 0, self.last_output)
        self.assertTrue(self.wt.exists())
        self.assertFalse(wt2.exists())
        self.assertEqual(self.branches(), ['claude/task-2', 'main'])
        self.assertFalse((self.root / '.git/lane-merge/batch.json').exists())

    def args_checker(self):
        """检查.sh 替身：把收到的参数记一行。"""
        log = Path(self.tmp.name) / 'check_args'
        checker = self.root / merge.ENV / '检查.sh'
        checker.write_text('#!/bin/zsh\necho "$*" >> %s\n' % log); checker.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'args checker')
        self.g('merge', 'main', cwd=self.wt)
        return log

    def test_finish_affected_uses_premerge_main_and_marks_commit(self):
        bare = self.github()
        log = self.args_checker()
        base = self.g('rev-parse', 'main')
        self.assertEqual(self.call('--affected'), 1)  # 只配 --finish
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch', '--affected'), 1)
        self.assertEqual(self.call('--finish', '--affected'), 0, self.last_output)
        self.assertEqual(log.read_text().split(), ['--oracle', '--affected', base])
        body = self.g('log', '-1', '--format=%B')
        self.assertIn('验证: 选测（基准 ' + base[:9], body)
        self.assertFalse(self.wt.exists())
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))

    def test_batch_final_affected_covers_whole_batch(self):
        wt2, _ = self.batch_fixture()
        log = Path(self.tmp.name) / 'check_args'
        checker = self.root / merge.ENV / '检查.sh'
        checker.write_text('#!/bin/zsh\necho "$*" >> %s\n' % log); checker.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'args checker')
        base = self.g('rev-parse', 'main')
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.assertEqual(self.call_task('task2'), 0, self.last_output)
        self.register_both()
        self.assertEqual(self.call_task('task2', '--finish', '--affected'), 0, self.last_output)
        self.assertEqual(log.read_text().split(), ['--oracle', '--affected', base])
        self.assertFalse(wt2.exists())
        self.assertFalse(self.wt.exists())

    def test_finish_without_affected_runs_full_check(self):
        log = self.args_checker()
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertEqual(log.read_text().split(), ['--oracle'])
        self.assertNotIn('验证:', self.g('log', '-1', '--format=%B'))

    def test_also_allows_extra_change_at_finish(self):
        self.assertEqual(self.call(), 0)
        self.register(); self.put('AGENTS.md', 'rule tweak during merge\n')
        self.assertEqual(self.call('--finish'), 1)
        self.assertEqual(self.call('--finish', '--also', 'AGENTS.md'), 0, self.last_output)
        self.assertIn('AGENTS.md', self.g('show', '--name-only', '--format=', 'HEAD'))


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    extra = load('incremental_workflow_tests', HERE / '测试增量同步.py')
    suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(extra))
    result = unittest.TextTestRunner().run(suite)
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
