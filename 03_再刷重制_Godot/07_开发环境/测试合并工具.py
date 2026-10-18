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
    extra = load('incremental_workflow_tests', HERE / '测试增量同步.py')
    suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(extra))
    result = unittest.TextTestRunner().run(suite)
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
