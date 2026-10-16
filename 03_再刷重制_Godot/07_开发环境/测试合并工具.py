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
    def simulate(self, accept=False, verify=True, changed_source=False):
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

    def test_merge_conflict_keeps_both_worktrees(self):
        self.put(str(merge.PROJECT / 'modes/测试.gd'), '# main version\n')
        self.g('add', '.'); self.g('commit', '-m', 'conflicting main update')
        self.assertEqual(self.call(), 1)
        self.assertTrue((self.root / '.git/MERGE_HEAD').exists())
        self.assertTrue(self.wt.exists())
        self.assertIn('<<<<<<<', (self.root / merge.PROJECT / 'modes/测试.gd').read_text())


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner().run(suite)
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
