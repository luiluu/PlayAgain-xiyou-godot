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
import time
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

    def test_top_level_note_field_can_be_explicitly_accepted(self):
        """交接板工具坑：探针顶层非用例字段改了，接受单原来放不行（没有可接受的变化候选）。
        纯说明文字（hostScope／scope）已不算改变（见 test_top_level_note_text_is_not_a_measurement），这里用别的标量。"""
        old = {'schemaVersion': 1, 'plainState': 3, 'cases': [{'id': 'a', 'v': 1}]}
        new = dict(old, plainState=4)
        with tempfile.TemporaryDirectory() as folder:
            a, b = Path(folder) / 'old', Path(folder) / 'new'
            a.mkdir(); b.mkdir()
            (a / 'attack_query.json').write_text(json.dumps(old)); (b / 'attack_query.json').write_text(json.dumps(new))
            check = additions.compare_directories(a, b)
            cand = additions.change_candidates(check)
            self.assertEqual([(c['collection'], c['key'], c['fields']) for c in cand], [('顶层', 'plainState', ['*'])])
            entry = dict(cand[0], reason='状态号改了', source='x')
            self.assertFalse(additions.apply_acceptances(check, [entry])['problems'])
            # 列表字段（未登记稳定键的整组用例）仍不出候选
            (b / 'attack_query.json').write_text(json.dumps(dict(old, extra=[1])))
            (a / 'attack_query.json').write_text(json.dumps(dict(old, extra=[2])))
            self.assertFalse(additions.change_candidates(additions.compare_directories(a, b)))

    def test_top_level_note_text_is_not_a_measurement(self):
        """10-29 两次：每期加词条 hostScope 说明都改写，同步按既有用例改变拒收、要手写接受单。"""
        old = {'schemaVersion': 1, 'hostScope': '异化词条期一', 'scope': '十个号角', 'cases': [{'id': 'a', 'v': 1}]}
        new = dict(old, hostScope='异化词条期一、期二', scope='十个号角＋木桩')
        self.assertEqual(additions.compare_file('alien_affix.json', old, new), ([], []))
        # 说明字段换了类型、被删掉，或旁边的真实测量变了，仍照常报
        for bad in [dict(new, hostScope={'x': 1}), {k: v for k, v in new.items() if k != 'hostScope'},
                    dict(new, cases=[{'id': 'a', 'v': 2}]), dict(new, schemaVersion=2)]:
            self.assertTrue(additions.compare_file('alien_affix.json', old, bad)[1], bad)

    def test_acceptance_already_in_baseline_is_only_noted(self):
        old = {'schemaVersion': 1, 'cases': [{'id': 'a', 'v': 1}, {'id': 'b', 'v': 1}]}
        new = {'schemaVersion': 1, 'cases': [{'id': 'a', 'v': 2}, {'id': 'b', 'v': 1}]}
        check = {'problems': {}, 'changes': {}}
        entry = {'file': 'events.json', 'collection': 'cases', 'key': '[["id","a"]]', 'fields': ['v'],
                 'oldDigest': additions.digest(old['cases'][0]), 'newDigest': additions.digest(new['cases'][0]), 'reason': '口径修正'}
        key = next(iter(additions.groups(new['cases'], ('id',))))
        entry['key'] = [k for k in additions.groups(new['cases'], ('id',)) if '"a"' in k][0]
        self.assertEqual(additions.current_digest('events.json', new, 'cases', entry['key']), entry['newDigest'])
        cur = lambda e: additions.current_digest('events.json', new, e['collection'], e['key'])
        r = additions.apply_acceptances(check, [entry], cur)
        self.assertEqual((len(r['alreadyInBaseline']), r['unused']), (1, []))
        # 现值对不上（真实不同）、不给 current：仍是 unused
        self.assertEqual(len(additions.apply_acceptances(check, [dict(entry, newDigest='0' * 16)], cur)['unused']), 1)
        self.assertEqual(len(additions.apply_acceptances(check, [entry])['unused']), 1)
        # 顶层与角色键也能取到现值
        self.assertEqual(additions.current_digest('x.json', {'note': 3}, additions.TOP_LEVEL, 'note'), additions.digest(3))
        self.assertEqual(additions.current_digest('slice_d1.json', {'actors': {'1': {'hp': 2}}}, 'actors', '1'),
                         additions.digest({'hp': 2}))

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
        body = '\n\n## 待总装并入变更记录的核查条目\n\n## 日期 【Codex·沙僧】x\n\n- y\n'
        self.assertTrue(merge.draft('- 核查／沙僧（Codex）；状态：可合并（问题批保留待核）。' + body))
        for head in ['- 核查／沙僧（Codex）；状态：WIP，勿合并。', '- 上期写过状态：可合并']:
            with self.assertRaises(RuntimeError):
                merge.draft(head + body)


    def test_problem_only_sheet_gets_minimal_entry(self):
        sheet = ('# 交付：codex/review-x\n\n- 核查／沙僧（Codex）；状态：可合并（仅问题交付）。\n\n## 接续前现场记录\n\n- 现场\n\n'
                 '## 本期问题交总装\n\n- P2 撤图误接受，见[报告](../核查报告_x.md)\n\n## 文档选测\n\n- 退出 0\n')
        with contextlib.redirect_stderr(io.StringIO()):
            body = merge.draft(sheet)
        self.assertRegex(body.splitlines()[0], r'^## \d{4}-\d\d-\d\d 【Codex·沙僧】codex/review-x（仅交问题，不销账）$')
        self.assertIn('P2 撤图误接受', body)
        self.assertNotIn('现场', body)
        self.assertNotIn('退出 0', body)
        # 既无草稿也无问题节：报错说清要补哪一节；草稿节在但为空仍拒（不退回问题节）
        with self.assertRaisesRegex(RuntimeError, '变更记录草稿.*问题'):
            merge.draft('# 交付：codex/y\n- 状态：可合并\n\n## 文档选测\n\n- z\n')
        with self.assertRaisesRegex(RuntimeError, '为空'):
            merge.draft('- 状态：可合并\n\n## 变更记录草稿\n\n## 本期问题\n\n- p\n')

    def test_mentions_whole_branch_name_only(self):
        self.assertTrue(merge.mentions('| A | 分支 claude/wukong-x（从 main 切） |', 'claude/wukong-x'))
        self.assertTrue(merge.mentions('停在 `claude/wukong-x`', 'claude/wukong-x'))
        for text in ['分支 claude/wukong-x1（从 x 末端切）', 'claude/wukong-x-2b', 'claude/wukong-x/sub', 'claude/wukong-x.bak']:
            self.assertFalse(merge.mentions(text, 'claude/wukong-x'), text)

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
        self.godot.write_text('#!/bin/zsh\nzmodload zsh/datetime\nn=${@[-1]:t}\n[[ $n == --version ]] && { echo 4.x; exit 0; }\n'
                              'print -r -- $n >> %(t)s/runs\n'
                              'if [[ -n ${SPIN:-} ]]; then i=0; while (( i++ < 400000 )); do :; done; fi\n'
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

    def test_names_file_and_wide_prefix_hint(self):
        names = self.tmp / 'names.txt'
        names.write_text('# 选测清单\na.tscn\n\nc  # 尾注释\n')
        p, runs = self.run_tests('--names-file', str(names))
        self.assertEqual(p.returncode, 0, p.stdout)
        self.assertEqual(sorted(runs), ['a.tscn', 'c.tscn'])
        self.assertNotIn('前缀', p.stdout)
        p, runs = self.run_tests('', XIYOU_PREFIX_HINT='2')  # 空前缀匹配全部 3 个
        self.assertIn('前缀  匹配 3 个场景', p.stdout)

    def test_new_class_name_triggers_one_import(self):
        # 八戒 10-29：车道新加带 class_name 的脚本后直接跑并行测试，新类名不在导入缓存里、解析不到
        (self.tmp / 'proj/new_thing.gd').write_text('extends Node\nclass_name NewThing\n')
        p, runs = self.run_tests('a')
        self.assertEqual(runs, ['--import', 'a.tscn'], p.stdout)
        self.assertIn('NewThing', p.stdout)
        (self.tmp / 'proj/.godot').mkdir()
        (self.tmp / 'proj/.godot/global_script_class_cache.cfg').write_text('list=[{\n"class": &"NewThing",\n}]\n')
        p, runs = self.run_tests('a')
        self.assertEqual(runs, ['a.tscn'], p.stdout)

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

    def test_default_log_dir_keeps_failure_detail_and_quiet(self):
        """八戒期二、期三：没给 --log-dir 时失败明细只在屏幕上 8 行，管道给 tail 看不全。"""
        p, _ = self.run_tests('--full', FAIL_C='1')
        self.assertEqual(p.returncode, 1, p.stdout)
        logs = sorted((self.tmp.resolve() / '04_验证/本地结果/并行测试').iterdir())
        self.assertEqual(len(logs), 1)
        self.assertIn('  · 日志：' + str(logs[0]), p.stdout)
        self.assertIn('完整输出：' + str(logs[0] / 'c.rerun1.log'), p.stdout)  # 单独重跑仍失败：指向最后一次
        self.assertIn(self.BAD, (logs[0] / 'c.log').read_text())
        self.assertNotIn('\r', p.stdout)
        p, _ = self.run_tests('--full', '--quiet', FAIL_C='1')
        self.assertNotIn('✓', p.stdout)
        self.assertIn('✗ c.tscn', p.stdout)
        self.assertIn('有失败', p.stdout)
        p, _ = self.run_tests('--full', '--quiet')
        self.assertEqual(p.returncode, 0, p.stdout)
        self.assertIn('3 个场景，全部通过', p.stdout)

    def test_quiet_still_heartbeats_for_long_task_watchdog(self):
        # 八戒 dev.206：长任务里加 --quiet 整段没输出，被一小时无输出看门狗杀掉；--quiet 只省通过行，心跳照打
        p, _ = self.run_tests('--full', '--quiet', jobs=3, BUSY='1', XIYOU_TEST_HEARTBEAT='0.1', CHECK_GLOBAL_JOBS='1')
        self.assertEqual(p.returncode, 0, p.stdout)
        self.assertIn('进行中：完成', p.stdout)
        self.assertNotIn('✓', p.stdout)

    def test_timings_record_child_user_cpu(self):
        # 八戒 dev.206：test_timings.json 只有墙钟，负载高时分不清场景慢还是机器满；每次尝试另记子进程 user／sys CPU
        logs = self.tmp / 'logs'
        p, _ = self.run_tests('--full', '--log-dir', str(logs), FLAKY_B='1', SPIN='1')
        self.assertEqual(p.returncode, 0, p.stdout)
        rows = {r['name']: r for r in json.loads((logs / 'test_timings.json').read_text())['scenes']}
        for r in rows.values():
            self.assertEqual(r['userCpuSeconds'], r['attempts'][0]['userCpuSeconds'])
            for t in r['attempts']:
                # 假 Godot 固定空转 40 万次（约 0.35 秒 CPU）；原按墙钟转 0.3 秒，机器满时分不到 0.1 秒 CPU 而偶发（哪吒_10）
                self.assertGreater(t['userCpuSeconds'], 0.1, r)
                self.assertGreaterEqual(t['sysCpuSeconds'], 0)
        self.assertEqual(len(rows['b.tscn']['attempts']), 2)

    def test_run_with_rusage_timeout_keeps_partial_output(self):
        par = load('par_rusage', HERE / '并行测试.py')
        rc, out, cpu = par.run_with_rusage(['sh', '-c', 'echo early; echo err >&2; sleep 30'], dict(os.environ), 0.5)
        self.assertEqual(rc, 142)
        self.assertIn('early', out)
        self.assertIn('err', out)
        self.assertGreaterEqual(cpu['user'], 0)
        rc, out, _ = par.run_with_rusage(['sh', '-c', 'echo hi; exit 3'], dict(os.environ), 10)
        self.assertEqual((rc, out), (3, 'hi\n'))

    def test_failure_summary_is_last_and_written_for_checker(self):
        """哪吒_7 t4 第 1 项：长任务日志里失败明细夹在几百行进度中间，收尾单列失败场景与日志路径，并交给 检查.sh 汇总。"""
        summary = self.tmp / 'failed.tsv'
        p, _ = self.run_tests('--full', FAIL_C='1', CHECK_FAILED_FILE=str(summary))
        self.assertEqual(p.returncode, 1, p.stdout)
        log = sorted((self.tmp.resolve() / '04_验证/本地结果/并行测试').iterdir())[-1] / 'c.rerun1.log'
        tail = p.stdout.rstrip('\n').splitlines()[-2:]
        self.assertEqual(tail, ['  ✗ 失败场景 1 个：', '      c.tscn → ' + str(log)], p.stdout)
        self.assertEqual(summary.read_text(), 'c.tscn\t%s\n' % log)
        self.assertEqual(json.loads((log.parent / 'test_timings.json').read_text())['failed'], ['c.tscn'])
        p, _ = self.run_tests('--full', CHECK_FAILED_FILE=str(summary))
        self.assertEqual(p.returncode, 0, p.stdout)
        self.assertEqual(summary.read_text(), '')  # 通过时清空，免得 检查.sh 读到上一轮的
        self.assertNotIn('失败场景', p.stdout)

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

    def test_selected_scenes_reuse_with_flag_and_merge_into_whole(self):
        # 选测（检查.sh --affected 传 --reuse）：同指纹下沿用上次通过的；选测结果并进同一指纹的记录，之后整轮只补跑没跑过的
        p, runs = self.run_tests('--reuse', 'a', 'c', jobs=1, FAIL_C='1')
        self.assertEqual((p.returncode, sorted(runs)), (1, ['a.tscn', 'c.tscn']), p.stdout)
        p, runs = self.run_tests('--reuse', 'a', 'c', jobs=1)
        self.assertEqual((p.returncode, runs), (0, ['c.tscn']), p.stdout)
        self.assertIn('✓ a.tscn {"passed":1,"total":1}（沿用）', p.stdout)
        p, runs = self.run_tests(jobs=1)  # 整轮：a、c 沿用，只补跑 b
        self.assertEqual((p.returncode, runs), (0, ['b.tscn']), p.stdout)
        p, runs = self.run_tests('--reuse', 'b', jobs=1)
        self.assertEqual(runs, [])
        _, runs = self.run_tests('--reuse', '--full', 'b', jobs=1)
        self.assertEqual(runs, ['b.tscn'])
        (self.tmp / 'proj/data.json').write_text('{}')  # 指纹变了：选测也全跑
        _, runs = self.run_tests('--reuse', 'a', 'b', jobs=1)
        self.assertEqual(sorted(runs), ['a.tscn', 'b.tscn'])

    def test_rules_only_filter_bypasses_reuse_ledger(self):
        # 沙僧第四期 T1：RULES_ONLY_* 过滤时 xiyou_rules 非 part0 只记 1 项成功，指纹又不含过滤值；
        # 过滤运行既不能沿用普通记录，也不能把结果写进去，清掉环境后的普通沿用要整轮重跑
        p, runs = self.run_tests(jobs=1, RULES_ONLY_TROOPS='833')
        self.assertEqual((p.returncode, len(runs)), (0, 3), p.stdout)
        self.assertIn('不读写沿用记录', p.stdout)
        self.assertFalse(list((self.state / 'results').glob('*.json')) if (self.state / 'results').exists() else [])
        p, runs = self.run_tests('--reuse', 'a', jobs=1, RULES_ONLY_ACTORS='5')
        self.assertEqual(runs, ['a.tscn'])
        p, runs = self.run_tests(jobs=1)  # 清环境：没有可沿用的过滤结果，整轮
        self.assertEqual((p.returncode, len(runs)), (0, 3), p.stdout)
        self.assertNotIn('沿用', p.stdout)
        p, runs = self.run_tests(jobs=1, RULES_ONLY_TROOPS='833')  # 有普通记录时过滤运行也不沿用
        self.assertEqual(len(runs), 3)
        p, runs = self.run_tests(jobs=1)  # 普通记录未被过滤运行改写，照常沿用
        self.assertEqual(runs, [])

    def test_whitespace_only_rules_filter_never_writes_reuse_ledger(self):
        # 沙僧第五期 C2：只给空白（制表符等）时原来被 .strip() 当作没过滤，xiyou_rules 却解析成编号 0、非 part0 只报 1 项，
        # 结果写进普通沿用账，清环境后仍沿用。原始值非空一律当过滤：不读不写沿用账
        for key in ('RULES_ONLY_TROOPS', 'RULES_ONLY_ACTORS'):
            for blank in ('\t', ' ', '\n', ' \t\n'):
                shutil.rmtree(self.state, ignore_errors=True)
                p, runs = self.run_tests(jobs=1, **{key: blank})
                self.assertEqual((p.returncode, len(runs)), (0, 3), p.stdout)
                self.assertIn('不读写沿用记录', p.stdout)
                self.assertFalse(list((self.state / 'results').glob('*.json')) if (self.state / 'results').exists() else [], repr(blank))
                p, runs = self.run_tests(jobs=1)  # 清环境：整轮实跑
                self.assertEqual(len(runs), 3, repr(blank))
        p, runs = self.run_tests(jobs=1, RULES_ONLY_TROOPS='')  # 空串＝没设，照常沿用
        self.assertEqual(runs, [])

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



class SlotWeightTests(unittest.TestCase):
    """共用槽按权重占（吃内存的探针多占几槽）、多槽进程不被单槽进程饿死、排队心跳、同步与占槽.py 都走这个池。"""
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.state = Path(self.tmpdir.name)
        self.par = load('par_slots', HERE / '并行测试.py')

    def tearDown(self):
        self.tmpdir.cleanup()

    def hold(self, weight, limit, until, out, name):
        """在子线程里占 weight 槽，记下占到的槽号，直到 until 事件被置位。"""
        import threading
        def body():
            with self.par.global_slot(self.state, limit, weight) as got:
                out[name] = got
                until.wait(10)
        t = threading.Thread(target=body, daemon=True)
        t.start()
        return t

    def wait_for(self, cond, seconds=5):
        import time
        t0 = time.monotonic()
        while not cond() and time.monotonic() - t0 < seconds:
            time.sleep(0.05)
        return cond()

    HOG = """import importlib.util, sys, threading, time
spec = importlib.util.spec_from_file_location('p', sys.argv[1]); p = importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
state, limit, seconds = __import__('pathlib').Path(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4])
mode = sys.argv[5]
if mode == 'hog':  # 批测：limit 个线程，放掉马上重抢
    end = time.monotonic() + seconds
    stop = state / 'hog_stop'   # 需要时由测试喊停：不靠固定时长，机器忙时进程起得慢也不会提前放槽
    held = threading.Barrier(limit, action=lambda: (state / 'hog_ready').touch())  # 全部槽都占上才放来者
    def worker():
        first = True
        while time.monotonic() < end and not stop.exists():
            with p.global_slot(state, limit):
                if first:
                    held.wait(); first = False
                time.sleep(0.2)
    ts = [threading.Thread(target=worker) for _ in range(limit)]
    [t.start() for t in ts]; [t.join() for t in ts]
    print('HOG_DONE', flush=True)
else:  # 别的工作树来要一个槽
    t0 = time.monotonic()
    with p.global_slot(state, limit):
        print('GOT %.2f' % (time.monotonic() - t0), flush=True)
"""

    def contend(self, queue):
        """主工作区批测占满上限时，另一个进程要一个槽要等多久（秒）。"""
        script = self.state / 'hog.py'
        script.write_text(self.HOG)
        env = dict(os.environ, XIYOU_SLOT_QUEUE='1' if queue else '0')
        args = [sys.executable, str(script), str(HERE / '并行测试.py'), str(self.state), '2']
        (self.state / 'hog_ready').unlink(missing_ok=True)
        hog = subprocess.Popen(args + ['4', 'hog'], env=env, stdout=subprocess.DEVNULL)
        try:
            self.assertTrue(self.wait_for(lambda: (self.state / 'hog_ready').exists(), 30))  # 负载高时 hog 起得慢：等它真占满
            got = subprocess.run(args + ['0', 'one'], env=env, capture_output=True, text=True, timeout=30).stdout
        finally:
            hog.wait(30)
        return float(got.split()[1])

    def test_queue_lets_other_process_in_while_batch_hogs_slots(self):
        """10-28 哪吒、八戒实测：批测把共用上限占满时别的工作树排 1～1.5 小时。旧行为下来者要等批测整个跑完，排队后一轮就拿到。"""
        # 旧行为（不排队）只打印作对照、不断言：放槽与重抢之间谁先到是竞速，负载约 23 时来者 1.5 秒就抢到过（哪吒_7 t4 第 4 项，
        # 哪吒_6 交付时负载约 16 下 171/172 就是这一项）。排队后的上限是确定的：前面没有别的等候者，下一轮放槽就归它
        old = self.contend(queue=False)
        new = self.contend(queue=True)
        print('  不排队 %.2f 秒，排队 %.2f 秒' % (old, new), file=sys.stderr)
        self.assertLess(new, 1.5)
        self.assertFalse(list((self.state / 'slots/queue').iterdir()))  # 排队文件都收走了

    PRIO = """import importlib.util, sys, time
spec = importlib.util.spec_from_file_location('p', sys.argv[1]); p = importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
state, limit, weight, hold = __import__('pathlib').Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), float(sys.argv[5])
(state / ('start_' + sys.argv[6])).touch()
with p.global_slot(state, limit, weight, priority=p.slot_priority('.')):
    print('GOT %f' % time.time(), flush=True)
    time.sleep(hold)
"""

    def test_main_worktree_waiter_goes_before_earlier_lane_waiters(self):
        """10-29～30：总装合并选测「等槽 4，在跑 无」排 40 分钟～1 小时多。车道批测占满上限、另一车道先排着时，
        后来的总装请求（XIYOU_SLOT_PRIORITY=1）先拿到槽；车道批测已在跑的不打断，放槽后不再重抢。"""
        script = self.state / 'hog.py'
        script.write_text(self.HOG)
        prio = self.state / 'prio.py'
        prio.write_text(self.PRIO)
        lane = dict(os.environ, XIYOU_SLOT_PRIORITY='0')
        main = dict(os.environ, XIYOU_SLOT_PRIORITY='1')
        par = str(HERE / '并行测试.py')
        (self.state / 'hog_stop').unlink(missing_ok=True)
        hog = subprocess.Popen([sys.executable, str(script), par, str(self.state), '1', '600', 'hog'], env=lane, stdout=subprocess.DEVNULL)
        try:
            self.assertTrue(self.wait_for(lambda: (self.state / 'hog_ready').exists(), 30))
            other = subprocess.Popen([sys.executable, str(prio), par, str(self.state), '1', '1', '0.5', 'lane'], env=lane,
                                     stdout=subprocess.PIPE, text=True)
            # 等车道等候者真登记进排队目录，再让总装来（不靠固定时间）
            self.assertTrue(self.wait_for(lambda: any((self.state / 'slots/queue').glob('*_%d_*' % other.pid)), 30))
            boss = subprocess.Popen([sys.executable, str(prio), par, str(self.state), '1', '1', '0', 'main'], env=main,
                                    stdout=subprocess.PIPE, text=True)
            # 总装等候者真登记了优先级，批测才放槽（不靠固定时间：机器忙时进程起得慢）
            self.assertTrue(self.wait_for(lambda: boss.poll() is not None or any((self.state / 'slots/priority').glob('*_%d_*' % boss.pid)), 60))  # 空档里直接拿到的不用登记
            t0 = __import__('time').time()
            (self.state / 'hog_stop').touch()
            got_main = float(boss.communicate(timeout=60)[0].split()[1])
            got_lane = float(other.communicate(timeout=60)[0].split()[1])
        finally:
            (self.state / 'hog_stop').touch()
            hog.wait(60)
        self.assertLess(got_main, got_lane, '总装请求应排在先来的车道等候者前面')  # 上限 1：同一时刻只有一个能拿，先后由槽决定，不是两个时间戳的竞速
        self.assertLess(got_main - t0, 10)  # 批测放槽后总装先拿到（上限只防永远等；先后次序由上一条断言保证）
        self.assertFalse(list((self.state / 'slots/priority').iterdir()))

    def test_lane_single_yields_to_live_priority_waiter_even_with_free_slots(self):
        # 不靠竞速：有活着的总装等候者时，车道单槽即使有空槽也让；等候者走了马上能占
        import threading, time as _t
        pdir = self.state / 'slots/priority'
        pdir.mkdir(parents=True)
        boss = pdir / ('%d_%d_1' % (_t.time_ns(), os.getppid()))
        boss.touch()
        got, release = {}, threading.Event()
        t = self.hold(1, 2, release, got, 'lane')
        self.assertFalse(self.wait_for(lambda: 'lane' in got, 1))
        self.assertFalse(self.locked('0.lock') or self.locked('1.lock'))
        boss.unlink()
        self.assertTrue(self.wait_for(lambda: 'lane' in got, 30))
        release.set(); t.join(30)

    def test_lane_heavy_waits_for_priority_waiter_before_gathering(self):
        # 车道多槽进程攒槽时会挡住全部单槽（含总装），所以有总装在排就先不拿 heavy.lock
        import threading, time as _t
        pdir = self.state / 'slots/priority'
        pdir.mkdir(parents=True)
        boss = pdir / ('%d_%d_1' % (_t.time_ns(), os.getppid()))  # 活着的进程登记的优先等候者
        boss.touch()
        got, release = {}, threading.Event()
        h = self.hold(2, 2, release, got, 'heavy')
        self.assertFalse(self.wait_for(lambda: 'heavy' in got, 1))
        self.assertFalse(self.locked('heavy.lock'))
        boss.unlink()
        self.assertTrue(self.wait_for(lambda: 'heavy' in got, 30))
        release.set(); h.join(30)

    def test_slot_priority_main_worktree_and_env(self):
        repo = self.state / 'repo'
        subprocess.run(['git', 'init', '-q', str(repo)], check=True)
        subprocess.run(['git', '-C', str(repo), '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q', '--allow-empty', '-m', 'x'], check=True)
        subprocess.run(['git', '-C', str(repo), 'worktree', 'add', '-q', str(self.state / 'wt')], check=True)
        with mock.patch.dict(os.environ, {'XIYOU_SLOT_PRIORITY': ''}):
            self.assertTrue(self.par.slot_priority(str(repo)))
            self.assertFalse(self.par.slot_priority(str(self.state / 'wt')))
        with mock.patch.dict(os.environ, {'XIYOU_SLOT_PRIORITY': '0'}):
            self.assertFalse(self.par.slot_priority(str(repo)))
        with mock.patch.dict(os.environ, {'XIYOU_SLOT_PRIORITY': '1'}):
            self.assertTrue(self.par.slot_priority(str(self.state / 'wt')))

    def test_stale_queue_ticket_is_ignored_and_removed(self):
        import time as _t
        q = self.state / 'slots/queue'
        q.mkdir(parents=True)
        dead = q / ('%d_%d_1' % (_t.time_ns() - 10**9, 999999))  # 不存在的 pid
        dead.touch()
        old = q / ('%d_%d_1' % (_t.time_ns() - 10**9, os.getppid()))  # 活着的 pid，但很久没刷新
        old.touch(); os.utime(old, (_t.time() - 120, _t.time() - 120))
        t0 = _t.monotonic()
        with self.par.global_slot(self.state, 2):
            pass
        self.assertLess(_t.monotonic() - t0, 0.4)
        self.assertFalse(dead.exists() or old.exists())

    def test_weight_takes_several_slots_and_others_queue(self):
        import threading
        got, release_a, release_b = {}, threading.Event(), threading.Event()
        a = self.hold(2, 3, release_a, got, 'a')
        self.assertTrue(self.wait_for(lambda: 'a' in got))
        self.assertEqual(len(got['a']), 2)
        b = self.hold(1, 3, release_b, got, 'b')
        self.assertTrue(self.wait_for(lambda: 'b' in got))  # 第三槽还空着
        c = self.hold(2, 3, threading.Event(), got, 'c')
        self.assertFalse(self.wait_for(lambda: 'c' in got, 1))  # 只剩 0 槽，两槽的要等
        release_a.set(); a.join(5)
        self.assertTrue(self.wait_for(lambda: 'c' in got))
        self.assertEqual(len(set(got['c']) | {got['b']}), 3)
        release_b.set(); b.join(5)

    def locked(self, name):
        """另开一个文件描述去试锁：被别人占着返回 True（flock 按打开的文件描述算，同进程不同线程也互斥）。"""
        import fcntl
        with open(self.state / 'slots' / name, 'a') as f:
            try:
                fcntl.flock(f, fcntl.LOCK_SH | fcntl.LOCK_NB)
            except OSError:
                return True
            fcntl.flock(f, fcntl.LOCK_UN)
            return False

    def test_heavy_waiter_keeps_partial_slots_so_singles_cannot_starve_it(self):
        # 不靠时间：每一步都等到能观察到的锁状态再往下走（负载高时只是等得久，不会判错）
        import threading
        got, ra = {}, threading.Event()
        a = self.hold(1, 2, ra, got, 'a')
        self.assertTrue(self.wait_for(lambda: 'a' in got, 30))
        rh = threading.Event()
        h = self.hold(2, 2, rh, got, 'heavy')
        # 多槽进程攒到了另一槽、独占着 heavy.lock，两个槽都被占
        self.assertTrue(self.wait_for(lambda: self.locked('heavy.lock') and self.locked('0.lock') and self.locked('1.lock'), 30))
        self.assertNotIn('heavy', got)
        rs = threading.Event()
        s = self.hold(1, 2, rs, got, 'single')
        ra.set(); a.join(30)
        # a 放出的槽只能归多槽进程：单槽的在 heavy.lock 独占期间让路
        self.assertTrue(self.wait_for(lambda: 'heavy' in got, 30))
        self.assertEqual(sorted(got['heavy']), [0, 1])
        self.assertNotIn('single', got)  # 两槽都在多槽进程手里，单槽的不可能占到
        rh.set(); h.join(30)
        self.assertTrue(self.wait_for(lambda: 'single' in got, 30))
        rs.set(); s.join(30)

    def test_single_waits_while_heavy_is_gathering(self):
        # 有多槽进程在攒槽（heavy.lock 独占）时，即使有空槽单槽的也让路；独占一放就能占到
        import fcntl, threading
        (self.state / 'slots').mkdir(exist_ok=True)
        gate = open(self.state / 'slots/heavy.lock', 'a')
        fcntl.flock(gate, fcntl.LOCK_EX)
        got, release = {}, threading.Event()
        t = self.hold(1, 2, release, got, 'single')
        self.assertFalse(self.wait_for(lambda: 'single' in got, 1))
        self.assertFalse(self.locked('0.lock') or self.locked('1.lock'))
        fcntl.flock(gate, fcntl.LOCK_UN); gate.close()
        self.assertTrue(self.wait_for(lambda: 'single' in got, 30))
        release.set(); t.join(30)

    def test_weight_above_limit_is_capped_and_waiting_reports_progress(self):
        import threading
        got, release = {}, threading.Event()
        a = self.hold(9, 2, release, got, 'a')
        self.assertTrue(self.wait_for(lambda: 'a' in got))
        self.assertEqual(sorted(got['a']), [0, 1])
        beats = []
        def late():
            with self.par.global_slot(self.state, 2, 1, beats.append, 0.2):
                pass
        t = threading.Thread(target=late, daemon=True); t.start()
        self.assertTrue(self.wait_for(lambda: len(beats) >= 2))
        release.set(); a.join(5); t.join(5)
        self.assertFalse(t.is_alive())

    def test_sync_heavy_probe_weight_and_waiting_heartbeat(self):
        seen = []
        real = sync.runner().global_slot

        def spy(sdir, limit, weight=1, on_wait=None, interval=60.0, priority=False):
            seen.append(weight)
            if on_wait:
                on_wait(61.0)
            return real(self.state, limit, weight)
        out = io.StringIO()
        with mock.patch.object(sync.runner(), 'global_slot', spy), mock.patch.object(sync.subprocess, 'run') as run, \
                contextlib.redirect_stdout(out):
            run.return_value = subprocess.CompletedProcess([], 0, '', '')
            sync.run_node(['event_probe.cjs'], {})
            sync.run_node(['cat_probe.cjs'], {})
            with mock.patch.dict(os.environ, XIYOU_PROBE_WEIGHTS='{"cat_probe.cjs": 2}'):
                sync.run_node(['cat_probe.cjs'], {})
        self.assertEqual(seen, [3, 1, 2])
        self.assertIn('等槽：event_probe.cjs 已等 61 秒（占 3 槽', out.getvalue())

    def test_godot_import_in_sync_takes_a_slot(self):
        labels = []
        @contextlib.contextmanager
        def spy(label, weight=1):
            labels.append(label)
            yield
        with mock.patch.object(sync, 'heavy_slot', spy), mock.patch.object(sync.subprocess, 'run') as run, \
                mock.patch.object(sync, 'GODOT', Path(sys.executable)), mock.patch.object(sync, 'PROJECT', self.state):
            run.return_value = subprocess.CompletedProcess([], 0, '', '')
            sync.godot_import()
        self.assertEqual(labels, ['godot --import'])

    def test_slot_cli_runs_command_and_sends_heartbeat_to_notice_fd(self):
        import threading
        env = dict(os.environ, XIYOU_TEST_STATE_DIR=str(self.state), CHECK_GLOBAL_JOBS='1', XIYOU_SLOT_HEARTBEAT='0.2')
        cli = [sys.executable, str(HERE / '占槽.py')]
        self.assertEqual(subprocess.run(cli + ['--', 'sh', '-c', 'exit 7'], env=env).returncode, 7)
        self.assertEqual(subprocess.run(cli + ['--weight', '2'], env=env, capture_output=True).returncode, 64)
        got, release = {}, threading.Event()
        with mock.patch.dict(os.environ, env):
            a = self.hold(1, 1, release, got, 'a')
            self.assertTrue(self.wait_for(lambda: 'a' in got))
            p = subprocess.Popen(['zsh', '-c', 'out=$("$@" 3>&2 2>&1); print -r -- "OUT:$out"', '_', *cli,
                                  '--label', 'godot --import', '--notice-fd', '3', '--', 'echo', 'done'],
                                 env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            # 等到真打出等槽心跳再放槽（原来固定等 0.8 秒，负载约 27 时子进程还没起来就放了，6 轮错 2 轮，哪吒_7 t4）
            lines, beat = [], threading.Event()
            def drain():
                for line in p.stderr:
                    lines.append(line)
                    if '等槽' in line:
                        beat.set()
            reader = threading.Thread(target=drain, daemon=True); reader.start()
            beat.wait(30)
            release.set(); a.join(5)
            out = p.stdout.read(); p.wait(10); reader.join(10)
        self.assertEqual(out.strip(), 'OUT:done')  # 心跳不混进捕获的命令输出
        self.assertIn('等槽：godot --import', ''.join(lines))



class AcceptanceDraftTests(unittest.TestCase):
    """生成接受单.py：按同步报告 changeCandidates 生成草稿、追加不重复、理由来源与空理由提示。"""
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.tmp = Path(self.tmpdir.name)
        self.gen = load('acceptance_draft', TOOLS / '生成接受单.py')
        row = {'collection': 'damage', 'key': '[["troop",854]]', 'fields': ['value'], 'oldDigest': 'a' * 16, 'newDigest': 'b' * 16}
        self.report = self.tmp / 'r/同步报告.json'
        self.report.parent.mkdir()
        self.report.write_text(json.dumps({'changeCandidates': [dict(row, file='slice_d1.json'), dict(row, file='slice_d2.json')]}))

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_draft_matches_loader_once_reason_filled(self):
        out = self.tmp / 'accept.json'
        r = self.gen.build(self.report, out, '')
        self.assertEqual((r['added'], r['total'], r['needReason']), (2, 2, 2))
        with self.assertRaises(ValueError):
            additions.load_acceptances([out])  # 空理由的草稿不能直接用
        r = self.gen.build(self.report, self.tmp / 'ok.json', '探针修正后取满血目标')
        entries, _ = additions.load_acceptances([self.tmp / 'ok.json'])
        self.assertEqual([e['file'] for e in entries], ['slice_d1.json', 'slice_d2.json'])
        self.assertEqual(r['needReason'], 0)

    def test_append_skips_existing_and_only_filters(self):
        out = self.tmp / 'accept.json'
        self.gen.build(self.report, out, '第一轮理由', {'slice_d1.json'})
        r = self.gen.build(self.report, out, '第二轮理由')
        data = json.loads(out.read_text())
        self.assertEqual((r['added'], r['total']), (1, 2))
        self.assertEqual([e['reason'] for e in data['accept']], ['第一轮理由', '第二轮理由'])
        with self.assertRaises(ValueError):
            self.gen.build(self.report, self.tmp / 'x.json', 'r', {'events.json'})

    def test_reason_from_delivery_sheet_and_latest_report(self):
        sheet = self.tmp / 'sheet.md'
        sheet.write_text('# 交付\n- 状态：可合并\n\n## 变更记录草稿\n\n## 2026 【Claude】标题\n\n- 修正探针取样口径\n\n## 交接板\n- x\n')
        self.assertEqual(self.gen.reason_from_sheet(sheet), '修正探针取样口径')
        sheet.write_text('# 交付\n## 预期测量变化\n\n- 854/947/5557 由 0 变 468\n\n## 交接板\n')
        self.assertEqual(self.gen.reason_from_sheet(sheet), '854/947/5557 由 0 变 468')
        old = self.tmp / 'b/20261001_000000/同步报告.json'
        old.parent.mkdir(parents=True); old.write_text(json.dumps({'changeCandidates': [{'file': 'x'}]}))
        new = self.tmp / 'b/20261002_000000/同步报告.json'
        new.parent.mkdir(parents=True); new.write_text(json.dumps({'changeCandidates': []}))
        self.assertEqual(self.gen.latest_report(self.tmp / 'b'), old)  # 最新一份没有变化就往前找


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

    def test_comparison_rules_do_not_change_tools_digest(self):
        """oracle_additions.py 只管接不接受测量变化：改它不让车道同步指纹失效；改转换器照旧失效。"""
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            tools = root / sync.TOOLS_REL
            tools.mkdir(parents=True)
            for name in ['oracle_additions.py', 'xiyou_export.py']:
                (tools / name).write_text('# v1\n')
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
            before = sync.tools_digest(root)
            (tools / 'oracle_additions.py').write_text('# v2 比较规则改了\n')
            self.assertEqual(sync.tools_digest(root), before)
            (tools / 'xiyou_export.py').write_text('# v2\n')
            self.assertNotEqual(sync.tools_digest(root), before)

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
        # 本批另一条还没合的车道（batch_fixture 的 lane2）仍留在「正在进行」：清理时据此认出它是登记过的车道工作树
        self.put(str(merge.BOARD), '# board\n## 正在进行\n%s\n## 待交叉核查\n| claude/task | Codex |\n## end\n' % getattr(self, 'keep_rows', ''))

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

    def test_review_trailer_is_pending_review_and_none_for_review_thread(self):
        """Kyo 10-30 停用 Codex 核查：Claude 执行默认写 `核查: 待审查`；审查线程自己的分支（claude/review-*，或交付单执行者
        是「Claude（审查）」）写 `核查: 无`，不进待核查清单。"""
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertIn('核查: 待审查', self.g('log', '-1', '--format=%B', 'HEAD'))
        self.assertNotIn('待Codex', self.g('log', '-1', '--format=%B', 'HEAD'))
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertIn('核查: 待审查', self.g('log', '-1', '--format=%B', 'HEAD'))

    def test_review_status_ignores_body_mention_of_reviewer(self):
        """唐僧 10-30：交付单正文里引用「执行者：Claude（审查）」不能让本条变成 核查: 无，只认头部执行者行。"""
        sheet = self.wt / self.receipt
        sheet.write_text(sheet.read_text().replace('# delivery\n', '# delivery\n- 执行者：Claude（哪吒）\n') + '\n- 正文引用：执行者：Claude（审查）\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'body mention', cwd=self.wt)
        state = {'branch': 'claude/task', 'target': 'claude/task', 'delivery': str(self.receipt)}
        self.assertEqual(merge.review_status(self.root, state), '待审查')

    def test_optimization_placeholder_only_in_lane_added_lines_and_never_in_registers(self):
        """唐僧 10-30（白龙期一）：车道分支带着交接板里的占位字样，被整片换成 O-122。换号只认交付单与车道自己新增的行；
        交接板、归档、变更记录永远不扫；车道改过的文档里原有的占位行（main 上的说明）不动。"""
        tok = 'O-' + '待定'
        self.realistic_checker()
        doc = merge.SUB / '00_设计/界面风格.md'
        self.put(str(doc), '# 风格\n说明里提到 %s 这个写法\n' % tok)
        self.put(str(merge.BOARD), '# board\n## 正在进行\n| claude/task | 预分配 %s |\n## 待交叉核查\n\n## end\n' % tok)
        self.g('add', '.'); self.g('commit', '-m', 'main has placeholder words')
        self.g('merge', 'main', cwd=self.wt)
        (self.wt / doc).write_text('# 风格\n说明里提到 %s 这个写法\n车道新增 %s\n' % (tok, tok))
        board = self.wt / merge.BOARD
        board.write_text(board.read_text() + '车道也动了交接板 %s\n' % tok)
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'lane edits', cwd=self.wt)
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertEqual((self.root / doc).read_text(), '# 风格\n说明里提到 %s 这个写法\n车道新增 O-001\n' % tok)
        self.assertEqual((self.root / merge.BOARD).read_text().count(tok), 2)       # 交接板两处都原样
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)

    def registry(self, rows):
        head = '# 优化登记\n\n## 登记表\n\n| 编号 | 项目 | 原版问题 | 重制做法 | 理由 | 回退 | 提出 | 状态 |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n'
        self.put(str(merge.OPT_REGISTRY), head + rows + '\n')
        self.g('add', '.'); self.g('commit', '-m', 'registry')
        self.g('merge', 'main', cwd=self.wt)

    def sheet_with(self, extra):
        sheet = self.wt / self.receipt
        sheet.write_text(sheet.read_text() + extra)
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'sheet', cwd=self.wt)

    def test_optimization_draft_rows_are_appended_to_registry_with_new_numbers(self):
        """唐僧总装 五 10-31：本批 O-122／O-123 的草稿表行都是总装手补的。准备阶段把草稿表行（换好号）追加到登记末行之后。"""
        tok = 'O-' + '待定'
        self.realistic_checker()
        self.registry('| O-001 | 旧项 | a | b | c | d | e | f |\n| O-118 | 最后一项 | a | b | c | d | e | f |')
        row = lambda n, name: '| %s | %s | 问题 | 做法 | 理由 | 回退 | 车道 | 待用户决定 |' % (n, name)
        self.sheet_with('\n## 优化登记草稿\n\n| 编号 | 项目 | 原版问题 | 重制做法 | 理由 | 回退 | 提出 | 状态 |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n'
                        + row(tok + '-1', '甲项') + '\n' + row(tok + '-2', '乙项') + '\n\n说明里提到 %s-1\n' % tok)
        self.assertEqual(self.call(), 0, self.last_output)
        reg = (self.root / merge.OPT_REGISTRY).read_text().split('\n')
        i = next(k for k, x in enumerate(reg) if x.startswith('| O-118'))
        self.assertEqual(reg[i + 1], row('O-119', '甲项'))
        self.assertEqual(reg[i + 2], row('O-120', '乙项'))
        self.assertNotIn(tok, '\n'.join(reg))
        self.assertIn('请在交接板「需要用户决定」加一行：- O-119 甲项', self.last_output)
        self.assertIn('O-120 乙项', self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)      # 登记文件的改动随收尾一并提交，不算预期外改动
        self.assertFalse(merge.dirty(self.root))

    def test_optimization_token_without_draft_table_is_refused(self):
        tok = 'O-' + '待定'
        self.realistic_checker()
        self.registry('| O-118 | 最后一项 | a | b | c | d | e | f |')
        self.sheet_with('\n- 新优化 %s（XFoo.fix）\n' % tok)
        self.assertEqual(self.call(), 1)
        self.assertIn('优化登记草稿', self.last_output)
        self.sheet_with('\n优化登记草稿：无\n')                            # 确无新优化：声明后放行
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertNotIn(tok, (self.root / merge.OPT_REGISTRY).read_text())

    def test_optimization_placeholder_in_tool_source_is_not_numbered(self):
        """唐僧 10-30：合并车道.py 自己注释里的占位被换成 O-122；工具源码（07_开发环境、03_转换工具）里的不换号，文档照换。"""
        tok = 'O-' + '待定'
        self.realistic_checker()
        tool = merge.ENV / '说明.py'
        doc = merge.SUB / '00_设计/界面风格.md'
        for r, text in [(tool, '# 占位写法 %s-1\n' % tok), (doc, '# 风格\n%s\n' % tok)]:
            (self.wt / r).parent.mkdir(parents=True, exist_ok=True)
            (self.wt / r).write_text(text)
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'placeholders', cwd=self.wt)
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertEqual((self.root / tool).read_text(), '# 占位写法 %s-1\n' % tok)
        self.assertEqual((self.root / doc).read_text(), '# 风格\nO-001\n')
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)

    def cc_lane(self, task, extra=''):
        wt = Path(self.tmp.name) / ('lane_' + task)
        self.g('worktree', 'add', '-b', 'cc/' + task, str(wt))
        receipt = wt / ('00_项目管理/交付/cc_%s.md' % task)
        receipt.parent.mkdir(parents=True, exist_ok=True)
        receipt.write_text('# delivery\n- 状态：可合并\n' + extra + '\n## 变更记录草稿\n\n## 日期 【cc】新写法（' + merge.VERSION_MARKER + '）\n\n- cc change\n\n## 交接板\n- fixture\n')
        (wt / (task + '.md')).write_text('cc lane\n')
        self.g('add', '.', cwd=wt); self.g('commit', '-m', 'cc feature', cwd=wt)
        return wt

    def test_cc_prefix_lane_merges_with_cc_trailer_and_old_executor_flag(self):
        """Kyo 10-31 把 claude 改叫 cc：cc/<任务> 分支、cc_<任务>.md 交付单、尾注「执行者: cc（唐僧）」；旧的 --executor Claude 等价。"""
        wt = self.cc_lane('ccjob')
        self.put(str(merge.BOARD), '# board\n## 正在进行\n\n## 待交叉核查\n| cc/ccjob |\n## end\n')
        self.g('add', '.'); self.g('commit', '-m', 'board lists cc lane')
        self.assertEqual(self.call_task('ccjob', '--executor', 'Claude'), 0, self.last_output)
        body = self.g('log', '-1', '--format=%B')
        self.assertIn('执行者: cc（唐僧）', body)
        self.assertIn('核查: 待审查', body)
        self.assertTrue(self.g('log', '-1', '--format=%s').startswith('合并 cc/ccjob'))
        self.assertIn('【cc】新写法', (self.root / merge.LOG).read_text())
        self.assertEqual(self.call_task('ccjob', '--finish'), 0, self.last_output)   # 缺省 cc，与上面的 Claude 等价，不报「接续执行者不同」
        self.assertFalse(wt.exists())

    def test_cc_review_branch_and_sheet_executor_write_no_review_needed(self):
        state = {'branch': 'cc/review-3', 'target': 'cc/review-3', 'delivery': 'x.md'}
        self.assertEqual(merge.review_status(self.root, state), '无')
        state = {'branch': 'cc/task', 'target': 'claude/task', 'delivery': str(self.receipt)}
        sheet = self.wt / self.receipt
        sheet.write_text(sheet.read_text().replace('# delivery\n', '# delivery\n- 执行者：cc（审查）\n'))
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'cc review sheet', cwd=self.wt)
        self.assertEqual(merge.review_status(self.root, state), '无')

    def test_review_status_for_review_thread(self):
        state = {'branch': 'claude/review-9', 'target': 'claude/task', 'delivery': str(self.receipt)}
        self.assertEqual(merge.review_status(self.root, state), '无')
        state['branch'] = 'claude/task'
        self.assertEqual(merge.review_status(self.root, state), '待审查')
        sheet = self.wt / self.receipt
        sheet.write_text(sheet.read_text().replace('# delivery\n', '# delivery\n- 执行者：Claude（审查）\n'))
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'review sheet', cwd=self.wt)
        self.assertEqual(merge.review_status(self.root, state), '无')

    def test_optimization_placeholder_gets_next_numbers(self):
        """唐僧 10-30：总装手换 O-119／O-120 漏了一处注释；合并工具按已登记最大 O-NNN 顺延换号，同一占位换同一号，
        代码注释、文档、交付单草稿都换，带 -1／-2 的是不同的号。"""
        tok = 'O-' + '待定'
        self.realistic_checker()
        self.put(str(merge.BOARD), '# board\n## 正在进行\n\n- **O-118 旧项**\n## 待交叉核查\n\n## end\n')
        self.g('add', '.'); self.g('commit', '-m', 'register has O-118')
        self.g('merge', 'main', cwd=self.wt)
        rel = merge.SUB / '00_设计/界面风格.md'
        gd = merge.PROJECT / 'modes/注释.gd'
        for r, text in [(rel, '# 风格\n%s-1 与 %s-2；再提 %s-1。\n' % (tok, tok, tok)), (gd, '# %s-2：说明\n# 也见 %s\n' % (tok, tok))]:
            (self.wt / r).parent.mkdir(parents=True, exist_ok=True)
            (self.wt / r).write_text(text)
        sheet = self.wt / self.receipt
        sheet.write_text(sheet.read_text().replace('- fixture change', '- fixture change %s-1' % tok) + '\n优化登记草稿：无\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'lane docs with placeholders', cwd=self.wt)
        self.assertEqual(self.call(), 0, self.last_output)
        doc = (self.root / rel).read_text()
        self.assertEqual(doc, '# 风格\nO-119 与 O-120；再提 O-119。\n')
        code = (self.root / gd).read_text()
        self.assertIn('# O-120：说明', code)
        self.assertIn('# 也见 O-121', code)       # 不带序号的是第三个不同占位
        self.assertNotIn(tok, doc + code)
        log = (self.root / merge.LOG).read_text()
        self.assertIn('fixture change O-119', log)
        self.assertNotIn(tok, log)

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

    def test_stale_fork_does_not_count_main_files(self):
        # 车道只改文档，期间合过 main；main 早先自己加了接受单和游戏代码。交叉合并时 merge-base 取到旧基点也不能算进本期
        old = self.g('rev-parse', 'HEAD')
        self.g('reset', '--hard', old, cwd=self.wt)
        (self.wt / self.receipt).parent.mkdir(parents=True, exist_ok=True)
        (self.wt / self.receipt).write_text('# delivery\n- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude】文档\n\n- doc only\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'doc', cwd=self.wt)
        spec = merge.ACCEPT / 'claude_other.json'
        self.put(str(spec), '{"schema": 1, "accept": []}')
        self.put(str(merge.PROJECT / 'modes/main.gd'), '# main\n')
        # 10-30 八戒 alien-equip：别的车道的交付单（带编号占位）车道合 main 时带进来，之后 main 归并删掉了
        other = '00_项目管理/交付/claude_other.md'
        self.put(other, '# 交付\n- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude】x（' + merge.VERSION_MARKER + '）\n\n- y\n')
        self.g('add', '.'); self.g('commit', '-m', 'main moves on')
        self.g('merge', 'main', cwd=self.wt)
        self.g('rm', '-q', other); self.g('commit', '-m', 'other merged')
        real = merge.git

        def stale(root, *args):
            return old if args[0] == 'merge-base' and len(args) == 3 else real(root, *args)
        with mock.patch.object(merge, 'git', side_effect=stale):
            state = merge.plan(self.root, 'task')
        self.assertEqual((state['gameplay'], state['acceptChanges'], state['refresh']), (False, [], False))
        self.assertEqual((state['versionPaths'], state['extraDeliveries']), ([], []))

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

    def test_accept_doc_edits_only_management_markdown(self):
        # 总装收尾前手修 00_项目管理/ 下的文档：默认拒；--accept-doc-edits 一并暂存；别处文件、交付单、非 .md 仍拒
        self.put('00_项目管理/阶段审查.md', 'old\n')
        self.g('add', '.'); self.g('commit', '-m', 'review doc')
        self.g('merge', 'main', cwd=self.wt)
        self.assertEqual(self.call(), 0)
        self.register(); self.put('00_项目管理/阶段审查.md', 'fixed link\n')
        self.assertEqual(self.call('--finish'), 1)
        self.assertIn('阶段审查.md', self.last_output)
        self.assertIn('--accept-doc-edits', self.last_output)
        for path in ['00_项目管理/x.json', '00_项目管理/交付/claude_other.md', 'README.md']:
            self.put(path, 'x\n')
            self.assertEqual(self.call('--finish', '--accept-doc-edits'), 1, path)
            self.assertIn(path, self.last_output)
            (self.root / path).unlink()
        self.assertFalse(self.g('diff', '--cached', '--name-only'))
        self.assertEqual(self.call('--finish', '--accept-doc-edits'), 0, self.last_output)
        self.assertIn('00_项目管理/阶段审查.md', self.g('-c', 'core.quotePath=false', 'show', '--name-only', '--format=', 'HEAD'))
        self.assertFalse(self.g('status', '--porcelain'))

    def test_lock_is_not_removed_by_second_runner(self):
        lock = self.root / '.git/lane-merge/running.lock'
        lock.parent.mkdir(); lock.write_text('first runner')
        self.assertEqual(self.call(), 1)
        self.assertEqual(lock.read_text(), 'first runner')

    def test_stale_lock_from_dead_runner_is_discarded(self):
        # 哪吒_7 t4 第 2 项：重启打断 --finish（143）留下锁，下一次 [Errno 17] 退出，只能人工删
        lock = self.root / '.git/lane-merge/running.lock'
        lock.parent.mkdir()
        dead = subprocess.Popen(['true']); dead.wait()
        lock.write_text(json.dumps({'pid': dead.pid, 'startedAt': 'Mon Jan  1 00:00:00 2001'}))
        self.assertEqual(self.call('--dry-run'), 0, self.last_output)  # dry-run 不拿锁：先确认夹具
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertIn('作废', self.last_output)
        self.assertFalse(lock.exists())
        # pid 还在但启动时间对不上（pid 被复用）：同样作废
        self.assertEqual(self.call('--abort'), 0, self.last_output)
        lock.write_text(json.dumps({'pid': os.getpid(), 'startedAt': 'Mon Jan  1 00:00:00 2001'}))
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertIn('作废', self.last_output)

    def test_live_lock_still_refuses(self):
        lock = self.root / '.git/lane-merge/running.lock'
        lock.parent.mkdir()
        lock.write_text(json.dumps({'pid': os.getpid(), 'startedAt': merge.process_start(os.getpid())}))
        before = lock.read_text()
        self.assertEqual(self.call(), 1)
        self.assertIn('另一个合并正在运行', self.last_output)
        self.assertIn('pid %d' % os.getpid(), self.last_output)
        self.assertEqual(lock.read_text(), before)

    def test_empty_lock_older_than_boot_is_discarded(self):
        # 10-28 现场是空锁（写 pid 前的旧版）：早于本次开机的作废；开机后留下的认不出持有者，照旧拒绝
        lock = self.root / '.git/lane-merge/running.lock'
        lock.parent.mkdir(); lock.write_text('')
        os.utime(lock, (time.time() - 10 * 86400,) * 2)
        with mock.patch.object(merge, 'boot_time', return_value=time.time() - 3600):
            with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(merge.main(['task', '--root', str(self.root)]), 0)
        self.assertIn('作废', out.getvalue())
        lock.write_text('')
        with mock.patch.object(merge, 'boot_time', return_value=time.time() - 3600):
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as err:
                self.assertEqual(merge.main(['task', '--root', str(self.root)]), 1)
        self.assertIn('认不出持有者', err.getvalue())
        self.assertTrue(lock.exists())

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
        self.keep_rows = '| D | `lane2` |'
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
        self.assertIn('执行者: cc（唐僧）', self.g('log', '-1', '--skip=0', '--format=%B', 'HEAD^{commit}'))
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertEqual((self.root / merge.PROJECT / 'modes/测试.gd').read_text(), '# resolved\n')

    def test_staged_conflict_markers_block_merge_commit(self):
        gd = merge.PROJECT / 'modes/测试.gd'
        self.put(str(gd), '# main version\n')
        self.g('add', '.'); self.g('commit', '-m', 'conflicting main update')
        self.assertEqual(self.call(), 1)
        self.g('add', str(gd))  # 带着 <<<<<<< 直接暂存（10-28 唐僧踩到的现场）
        base = self.g('rev-parse', 'HEAD')
        self.assertEqual(self.call(), 1)
        self.assertIn('冲突标记', self.last_output)
        self.assertIn(str(gd), self.last_output)
        self.assertEqual(self.g('rev-parse', 'HEAD'), base)  # 没有提交合并
        # 自己 git commit 了带标记的合并：同样拒绝往下走
        self.g('commit', '--no-edit')
        self.assertEqual(self.call(), 1)
        self.assertIn('合并提交里有冲突标记', self.last_output)
        self.put(str(gd), '# resolved\n')
        self.g('commit', '-a', '--amend', '--no-edit')
        self.assertEqual(self.call(), 0, self.last_output)

    def test_auto_merged_duplicate_func_stops_before_sync(self):
        """10-28：lane 与 main 各在 item_marks.gd 不挨着的位置加同名 func，git 自动合并不报冲突，工程整个 Parse Error。"""
        rel = merge.PROJECT / 'modes/marks.gd'
        body = 'extends RefCounted\n\nstatic func a() -> int:\n\treturn 1\n' + ''.join('\n# 段 %d\n' % i for i in range(12)) + '\nstatic func z() -> int:\n\treturn 2\n'
        self.put(str(rel), body); self.g('add', '.'); self.g('commit', '-m', 'marks')
        self.g('merge', 'main', cwd=self.wt)
        dup = '\nstatic func is_super_strong(id: int) -> bool:\n\treturn id > 0\n'
        (self.wt / rel).write_text(body.replace('\n# 段 2\n', '\n# 段 2\n' + dup))
        self.g('commit', '-am', 'lane adds is_super_strong', cwd=self.wt)
        self.put(str(rel), body + dup); self.g('commit', '-am', 'main adds is_super_strong')
        self.assertEqual(self.call(), 1, self.last_output)
        self.assertIn('解析检查不通过', self.last_output)
        self.assertIn(str(rel) + '：func is_super_strong 重复定义', self.last_output)
        self.assertFalse((self.root / '.git/MERGE_HEAD').exists())  # 自动合并已提交，没报冲突
        state = json.loads((self.root / '.git/lane-merge/state.json').read_text())
        self.assertEqual(state['phase'], 'planned')  # 还没同步、没编号
        self.put(str(rel), body.replace('\n# 段 2\n', '\n# 段 2\n' + dup))
        self.g('commit', '-a', '--amend', '--no-edit')
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)

    def test_parse_check_reads_godot_log_and_skip_flag(self):
        # 假 godot：--import 不出声；--script 时打一条 autoload 的假错误（不算）和一条真错误
        self.put(str(merge.PROJECT / 'project.godot'), 'config/version="dev.001"\n[autoload]\nGameApp="*res://core/app.gd"\n\n[display]\n')
        godot = self.root / merge.ENV / 'godot'
        godot.write_text('#!/bin/zsh\n[[ "$*" == *--import* ]] && exit 0\n'
                         'print "SCRIPT ERROR: Compile Error: Identifier not found: GameApp"\nprint "          at: GDScript::reload (res://entry.gd:3)"\n'
                         'print "SCRIPT ERROR: Compile Error: Failed to compile depended scripts."\nprint "          at: GDScript::reload (res://x.gd:0)"\n'
                         '[[ -n $BAD ]] && { print "SCRIPT ERROR: Parse Error: Expected end of statement."; print "          at: GDScript::reload (res://modes/broken.gd:7)"; }\n'
                         'print PARSE_CHECK_DONE\n')
        godot.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'godot fixture'); self.g('merge', 'main', cwd=self.wt)
        os.environ['BAD'] = '1'
        try:
            self.assertEqual(self.call(), 1, self.last_output)
            self.assertIn('res://modes/broken.gd：Parse Error: Expected end of statement.', self.last_output)
            self.assertNotIn('GameApp', self.last_output)
            self.assertNotIn('depended', self.last_output)
            self.assertEqual(self.call('--no-parse-check'), 0, self.last_output)
        finally:
            os.environ.pop('BAD')

    def test_parse_check_flags_import_and_load_process_failures(self):
        # 沙僧第十七期 P3：导入阶段退出码非零并打印 ERROR:、加载阶段正常打印完成标志，原来返回零问题
        self.put(str(merge.PROJECT / 'project.godot'), 'config/version="dev.001"\n[autoload]\nGameApp="*res://core/app.gd"\n\n[display]\n')
        godot = self.root / merge.ENV / 'godot'
        godot.write_text('#!/bin/zsh\n[[ "$*" == *--import* ]] && { [[ -n $IMPORT_FAIL ]] && { print "ERROR: Failed to import res://x.png"; exit 1; }; exit 0; }\n'
                         'print PARSE_CHECK_DONE\n[[ -n $LOAD_RC ]] && exit $LOAD_RC\nexit 0\n')
        godot.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'godot fixture'); self.g('merge', 'main', cwd=self.wt)
        for env, expect in [({'IMPORT_FAIL': '1'}, 'godot --import 报错'), ({'LOAD_RC': '3'}, '退出码 3')]:
            with self.subTest(env=env):
                os.environ.update(env)
                try:
                    self.assertEqual(self.call(), 1, self.last_output)
                    self.assertIn(expect, self.last_output)
                finally:
                    for k in env:
                        os.environ.pop(k)
        self.assertEqual(self.call(), 0, self.last_output)  # 健康的假 godot 照常通过

    def test_active_cwds_unknown_when_lsof_unavailable_keeps_worktree(self):
        # 沙僧第十六期 P2：lsof 缺失／超时／失败时原来返回空、清理放行；现在无法确认就保守不删
        wt = self.wt
        for how in ['missing', 'timeout', 'failed']:
            with self.subTest(how=how):
                if how == 'missing':
                    side = FileNotFoundError('lsof')
                elif how == 'timeout':
                    side = subprocess.TimeoutExpired('lsof', 60)
                else:
                    side = None
                real = subprocess.run
                def fake(cmd, *a, **k):
                    if cmd[0] == 'lsof':
                        if side is not None:
                            raise side
                        return subprocess.CompletedProcess(cmd, 1, '', 'boom')
                    return real(cmd, *a, **k)
                with mock.patch.object(merge.subprocess, 'run', fake):
                    self.assertIsNone(merge.active_cwds(wt))
                    reason = merge.lane_protected(self.root, {'worktree': str(wt), 'branch': 'claude/task', 'base': 'HEAD'})
                self.assertIn('无法确认有无活动会话', reason)

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

    def test_old_sheet_already_merged_is_not_extra_delivery(self):
        # 哪吒_7 t4 第 3 项（八戒 attack-query2）：期二从期一交付点切出、又合过 main，与 main 有两个合并基点（交叉合并），
        # merge-base 取到旧的那个，diff 带出期一交付单；期一已随上一批并入并删除，不该再算附带交付单
        lane2 = Path(self.tmp.name) / 'lane2'
        self.g('worktree', 'add', '-b', 'claude/task2', str(lane2), 'claude/task')
        self.put('other.md', 'main moves\n'); self.g('add', '.'); self.g('commit', '-m', 'main moves')
        self.g('merge', '-m', 'merge main', 'main', cwd=lane2)
        sheet2 = lane2 / '00_项目管理/交付/claude_task2.md'
        sheet2.write_text('# 期二\n- 状态：可合并\n\n## 变更记录草稿\n\n## 日期 【Claude】期二\n\n- phase 2\n')
        self.g('add', '.', cwd=lane2); self.g('commit', '-m', 'phase 2 sheet', cwd=lane2)
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertFalse((self.root / self.receipt).exists())
        bases = self.g('merge-base', '--all', 'main', 'claude/task2').split()
        self.assertEqual(len(bases), 2)  # 夹具确实是交叉合并
        state = merge.plan(self.root, 'task2')
        self.assertEqual(state['delivery'], '00_项目管理/交付/claude_task2.md')
        self.assertEqual(state['extraDeliveries'], [])
        # 车道改过的旧交付单（内容与 main 删前不同）照样不算附带交付单，但要提示
        (lane2 / self.receipt).write_text((lane2 / self.receipt).read_text() + '- 期二补记\n')
        self.g('add', '.', cwd=lane2); self.g('commit', '-m', 'touch old sheet', cwd=lane2)
        with contextlib.redirect_stderr(io.StringIO()) as err:
            state = merge.plan(self.root, 'task2')
        self.assertEqual(state['extraDeliveries'], [])
        self.assertIn(str(self.receipt), err.getvalue())
        self.assertIn('已在 main 删除', err.getvalue())

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
        calls, real = [], subprocess.run

        def fake(cmd, **kw):
            if cmd[0] == 'git':
                return real(cmd, **kw)
            calls.append(list(map(str, cmd)))
            return subprocess.CompletedProcess(cmd, 0)
        state = merge.plan(self.root, 'task')
        self.assertEqual(state['worktree'], '')
        self.assertTrue(state['refresh'])
        state_file = Path(self.tmp.name) / 'state.json'
        with mock.patch.object(merge.subprocess, 'run', side_effect=fake), \
                mock.patch.object(merge, 'replace_versions', side_effect=RuntimeError('stop')):
            with self.assertRaises(RuntimeError):
                merge.prepare(self.root, dict(state, phase='merged', head=self.g('rev-parse', 'HEAD')), state_file, 'Claude')
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

    def test_active_session_or_lock_keeps_clean_delivery_worktree(self):
        # 哪吒 T2：另一账号会话停在干净的交付工作树里（悟空_62 的 wukong-reach109 曾被误清）：有进程以它为当前目录、
        # 或 git worktree lock 锁住时只提示不删
        for case in ['process', 'lock']:
            with self.subTest(case=case):
                self.tearDown(); self.setUp()
                self.assertEqual(self.call(), 0, self.last_output)
                proc = subprocess.Popen(['sleep', '60'], cwd=self.wt) if case == 'process' else None
                if case == 'lock':
                    self.g('worktree', 'lock', '--reason', 'fixture', str(self.wt))
                try:
                    self.register()
                    self.assertEqual(self.call('--finish'), 0, self.last_output)
                finally:
                    if proc:
                        proc.kill(); proc.wait()
                self.assertTrue(self.wt.exists())
                self.assertIn('claude/task', self.branches())
                self.assertIn('活动会话' if case == 'process' else 'worktree lock', self.last_output)
                self.assertIn('只提示不删', self.last_output)

    def test_board_row_marked_keep_is_not_removed_but_missing_row_is(self):
        # 交接板「正在进行」那行写了「不要删」才留；没提到该工作树／分支不再是保留理由（哪吒_10，磁盘告急，合并后随手删）
        for row in ['', '| 核查 | claude/task（清理时不要删此目录） |']:
            with self.subTest(row=row):
                self.tearDown(); self.setUp()
                self.put(str(merge.BOARD), '# board\n## 正在进行\n' + row + '\n## 待交叉核查\n\n## end\n')
                self.g('add', '.'); self.g('commit', '-m', 'board without lane row')
                self.assertEqual(self.call(), 0, self.last_output)
                self.register()
                self.assertEqual(self.call('--finish'), 0, self.last_output)
                self.assertEqual(self.wt.exists(), bool(row), self.last_output)
                if row:
                    self.assertIn('不要删', self.last_output)
                else:
                    self.assertNotIn('claude/task', self.branches())

    def test_untracked_evidence_merges_by_ref_and_keeps_worktree(self):
        # 沙僧 state-effects-2b：只有核查范围／本地结果下的未跟踪证据时按分支引用合并，工作树与证据都留着
        evidence = [self.wt / '00_项目管理/核查范围/原版/证据.json', self.wt / merge.SUB / '04_验证/本地结果/x.log']
        for f in evidence:
            f.parent.mkdir(parents=True, exist_ok=True); f.write_text('keep')
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertIn('未跟踪证据', self.last_output)
        self.assertFalse((self.root / self.receipt).exists())
        self.assertIn('fixture change', (self.root / merge.LOG).read_text())
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertTrue(all(f.read_text() == 'keep' for f in evidence))
        self.assertIn('claude/task', self.branches())
        self.tearDown(); self.setUp()
        for f in evidence + [self.wt / '00_项目管理/别处.md']:   # 证据目录外还有未跟踪文件：照旧拒收
            f.parent.mkdir(parents=True, exist_ok=True); f.write_text('keep')
        self.assertEqual(self.call(), 1)
        self.assertIn('不干净', self.last_output)

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

    def test_finish_cloud_passes_flag_and_no_upload_when_no_refresh(self):
        """--finish --affected --cloud：检查.sh 多收 --cloud；本批没带切片／参照刷新时 CHECK_CLOUD_NO_UPLOAD=1。--cloud 不配 --affected。"""
        bare = self.github()
        log = Path(self.tmp.name) / 'check_args'
        checker = self.root / merge.ENV / '检查.sh'
        checker.write_text('#!/bin/zsh\necho "$* upload_skip=${CHECK_CLOUD_NO_UPLOAD:-0}" >> %s\n' % log); checker.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'args checker')
        self.g('merge', 'main', cwd=self.wt)
        base = self.g('rev-parse', 'main')
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--cloud'), 1)
        self.assertIn('--cloud 只和 --affected', self.last_output)
        self.assertEqual(self.call('--finish', '--affected', '--cloud'), 0, self.last_output)
        self.assertEqual(log.read_text().split(), ['--oracle', '--affected', base, '--cloud', 'upload_skip=1'])
        self.assertFalse(self.wt.exists())
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))

    def test_finish_cloud_failure_keeps_lane_and_does_not_push(self):
        """云端判失败（检查.sh 非零，覆盖通过以外的失败、超时、不可用）：保留现场，不提交收尾、不清理、不推送。"""
        bare = self.github()
        checker = self.root / merge.ENV / '检查.sh'
        checker.write_text('#!/bin/zsh\nexit 1\n'); checker.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'failing checker')
        self.g('merge', 'main', cwd=self.wt)
        pushed = self.g('rev-parse', 'main', cwd=bare)
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertNotEqual(self.call('--finish', '--affected', '--cloud'), 0)
        self.assertTrue(self.wt.exists())
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), pushed)

    def test_cloud_env_uploads_only_when_a_lane_refreshed_reference_or_slice(self):
        self.assertEqual(merge.cloud_env({'refresh': False}, {})['CHECK_CLOUD_NO_UPLOAD'], '1')
        self.assertNotEqual(merge.cloud_env({'refresh': False}, {'refresh': True}).get('CHECK_CLOUD_NO_UPLOAD'), '1')

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

    def close(self, *args, **env):
        result = subprocess.run([sys.executable, str(HERE / '合并车道.py'), '--root', str(self.root), '--close-batch', *args],
                                capture_output=True, text=True, env=dict(os.environ, **env))
        self.last_output = result.stdout + result.stderr
        return result.returncode

    def batch_two(self):
        wt2, checks = self.batch_fixture()
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.assertEqual(self.call_task('task2'), 0, self.last_output)
        self.register_both()
        self.assertEqual(self.call_task('task2', '--finish', '--batch'), 0, self.last_output)
        return wt2, checks

    def test_close_batch_checks_once_cleans_and_pushes(self):
        bare = self.github()
        self.assertEqual(self.close(), 1)  # 没有攒着的批
        base = self.g('rev-parse', 'main')
        wt2, checks = self.batch_two()
        self.assertFalse(checks.exists())
        self.assertEqual(self.close('--batch'), 1)
        self.assertEqual(self.close(), 0, self.last_output)
        self.assertEqual(checks.read_text().split(), ['run'])
        self.assertFalse(self.wt.exists()); self.assertFalse(wt2.exists())
        self.assertFalse((self.root / '.git/lane-merge/batch.json').exists())
        self.assertIn('本批 2 条收口', self.last_output)
        self.assertEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))
        self.assertEqual(self.close(), 1)  # 已收口
        self.assertTrue(base)

    def test_close_batch_failure_keeps_everything_and_reports(self):
        bare = self.github()
        wt2, checks = self.batch_two()
        self.assertEqual(self.close(CHECK_RC='1'), 1)
        self.assertIn('各条车道带进来的改动', self.last_output)
        self.assertTrue(self.wt.exists()); self.assertTrue(wt2.exists())
        self.assertTrue((self.root / '.git/lane-merge/batch.json').exists())
        self.assertNotEqual(self.g('rev-parse', 'main', cwd=bare), self.g('rev-parse', 'main'))
        self.assertEqual(self.close(), 0, self.last_output)  # 修好后重跑同一命令
        self.assertFalse(wt2.exists())

    def test_close_batch_affected_uses_first_base_and_refuses_dirty_or_open_merge(self):
        log = Path(self.tmp.name) / 'check_args'
        wt2, _ = self.batch_fixture()
        checker = self.root / merge.ENV / '检查.sh'
        checker.write_text('#!/bin/zsh\necho "$*" >> %s\n' % log); checker.chmod(0o755)
        self.g('add', '.'); self.g('commit', '-m', 'args checker')
        base = self.g('rev-parse', 'main')
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish', '--batch'), 0, self.last_output)
        self.assertEqual(self.call_task('task2'), 0, self.last_output)  # 第二条还在合并中
        self.assertEqual(self.close(), 1)
        self.assertIn('还有一条车道在合并中', self.last_output)
        self.register_both()
        self.assertEqual(self.call_task('task2', '--finish', '--batch'), 0, self.last_output)
        self.put('stray', 'x')
        self.assertEqual(self.close(), 1)
        (self.root / 'stray').unlink()
        self.assertEqual(self.close('--affected'), 0, self.last_output)
        self.assertEqual(log.read_text().split(), ['--oracle', '--affected', base])

    def fake_sync(self):
        """main 上放一个假同步：记下参数；没带 --accept-changes 时按「测量有改变」退出 2。"""
        record = Path(self.tmp.name) / 'sync_args'
        self.put(str(merge.TOOLS / '同步正式西游.py'),
                 'import sys\nopen(%r, "a").write(" ".join(sys.argv[1:]) + "\\n")\n'
                 'sys.exit(0 if "--accept-changes" in sys.argv else 2)\n' % str(record))
        self.g('add', '.'); self.g('commit', '-m', 'fake sync')
        self.g('merge', 'main', cwd=self.wt)
        slice_ = self.wt / merge.TOOLS / 'xiyou_slice.json'
        slice_.write_text('{"troops": [1]}\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'slice', cwd=self.wt)
        return record

    def test_sync_rejection_prints_draft_command_then_accept_changes_resumes(self):
        record = self.fake_sync()
        self.assertEqual(self.call(), 1)
        self.assertIn('生成接受单.py --out ' + str(merge.ACCEPT / 'claude_task.json'), self.last_output)
        self.assertIn('--accept-changes', self.last_output)
        sheet = self.root / merge.ACCEPT / 'claude_task.json'
        self.assertEqual(self.call('--accept-changes', str(sheet)), 1)  # 还没写接受单
        self.put(str(merge.ACCEPT / 'claude_task.json'), '{"schema": 1, "accept": []}\n')
        self.assertEqual(self.call('--finish', '--accept-changes', str(sheet)), 1)
        self.assertEqual(self.call('--accept-changes', str(self.root / 'elsewhere.json')), 1)
        self.assertEqual(self.call('--accept-changes', str(sheet)), 0, self.last_output)
        last = record.read_text().splitlines()[-1].split()
        self.assertEqual(last[last.index('--accept-changes') + 1], str(merge.ACCEPT / 'claude_task.json'))
        state = json.loads((self.root / '.git/lane-merge/state.json').read_text())
        self.assertEqual(state['phase'], 'prepared')
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertIn(str(merge.ACCEPT / 'claude_task.json'), self.g('-c', 'core.quotepath=false', 'show', '--name-only', '--format=', 'HEAD'))
        self.assertEqual(self.call('--accept-changes', str(sheet)), 1)  # 已收尾：没有准备中的合并也不新开

    def test_single_abort_restores_main_generated_and_baseline(self):
        """10-27 ce-fix2：单条合并手动 reset 撤出后，同步写出的 common_scripts.json 留在产物里，下一次同步拿它当基线被拒。"""
        gen, results = merge.GENERATED, merge.SUB / '04_验证/本地结果'
        self.put('.gitignore', str(gen) + '/\n' + str(results) + '/\n')
        self.put(str(gen / 'manifest.json'), '{"v": "before"}\n')
        self.put(str(gen / 'oracle/a.json'), '{"a": 1}\n')
        # 假同步按真同步的顺序：建基线（不存在时取当前产物）→ 备份产物 → 写新产物；第二个参数让它拒收（退出码 2）
        self.put(str(merge.TOOLS / '同步正式西游.py'), '''import datetime, hashlib, shutil, sys
from pathlib import Path
root = Path.cwd(); gen = root / %r; res = root / %r
base = res / '同步基线' / hashlib.sha256(str(gen.resolve()).encode()).hexdigest()
if not base.exists():
    shutil.copytree(gen / 'oracle', base / 'oracle'); shutil.copy2(gen / 'manifest.json', base / 'manifest.json')
bk = res / '自动同步' / (datetime.datetime.now().strftime('%%Y%%m%%d_%%H%%M%%S_%%f') + '_v-v')  # 同真同步：time.strftime 不认 %%f，同一秒两次会撞名
shutil.copytree(gen / 'oracle', bk / 'oracle'); shutil.copy2(gen / 'manifest.json', bk / 'manifest.json')
(gen / 'oracle/common_scripts.json').write_text('{}'); (gen / 'manifest.json').write_text('{"v": "lane"}')
(gen / 'sync_stamp.json').write_text('{}')
sys.exit(0)
''' % (str(gen), str(results)))
        self.g('add', '.'); self.g('commit', '-m', 'fake sync')
        self.g('merge', 'main', cwd=self.wt)
        (self.wt / merge.TOOLS / 'xiyou_slice.json').write_text('{"troops": [1]}\n')
        self.g('add', '.', cwd=self.wt); self.g('commit', '-m', 'slice', cwd=self.wt)
        before = self.g('rev-parse', 'HEAD')
        self.assertEqual(self.call('--abort'), 1)  # 没有准备中的合并
        self.assertEqual(self.call(), 0, self.last_output)
        self.assertTrue((self.root / gen / 'oracle/common_scripts.json').exists())
        self.assertNotEqual(self.g('rev-parse', 'HEAD'), before)
        self.assertTrue(list((self.root / results / '同步基线').iterdir()))
        self.assertEqual(self.call('--abort'), 0, self.last_output)
        self.assertEqual(self.g('rev-parse', 'HEAD'), before)
        self.assertFalse(merge.dirty(self.root))
        self.assertFalse((self.root / '.git/lane-merge/state.json').exists())
        self.assertFalse((self.root / gen / 'oracle/common_scripts.json').exists())
        self.assertFalse((self.root / gen / 'sync_stamp.json').exists())
        self.assertEqual((self.root / gen / 'manifest.json').read_text(), '{"v": "before"}\n')
        self.assertFalse(list((self.root / results / '同步基线').iterdir()))
        self.assertTrue(self.wt.exists())
        self.assertTrue(self.g('for-each-ref', 'refs/lane-merge/'))
        # 车道修好后重新交付：照常合并，基线按还原后的产物重建
        self.assertEqual(self.call(), 0, self.last_output)
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)

    def test_undo_sync_uses_pinned_snapshot_not_rotated_backups(self):
        """沙僧第七期 T1：同一合并多轮同步后滚动备份只剩三份，首轮前的备份被轮换；撤回须还原到首轮同步前（固定快照），
        同步前没有的项（如 maps）同步新建了也要删；快照丢了就拒绝声称还原、保留现场。"""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            gen = root / merge.GENERATED
            (gen / 'oracle').mkdir(parents=True)
            (gen / 'oracle/a.json').write_text('state0')
            (gen / 'manifest.json').write_text('state0')
            state = {'syncSince': '20260101_000000', 'task': 'x'}
            state['preSync'] = merge.pin_generated(root, root / 'lane/pre-sync/x')
            self.assertEqual(state['preSync']['absent'], ['db', 'maps', 'slice.json'])
            # 四轮同步：每轮改产物、新建 maps，滚动备份只剩后三份（内容都不是 state0）
            bk = root / merge.SYNC_BACKUPS
            for i in range(1, 5):
                (gen / 'oracle/a.json').write_text('state%d' % i)
                (gen / 'manifest.json').write_text('state%d' % i)
                (gen / 'maps').mkdir(exist_ok=True)
                (gen / 'maps/m.json').write_text('new')
                if i > 1:
                    (bk / ('20260101_00000%d_v' % i)).mkdir(parents=True, exist_ok=True)
                    (bk / ('20260101_00000%d_v' % i) / 'manifest.json').write_text('state%d' % (i - 1))
                    (bk / ('20260101_00000%d_v' % i) / 'oracle').mkdir()
            note = merge.undo_sync(root, state)
            self.assertEqual((gen / 'oracle/a.json').read_text(), 'state0', note)
            self.assertEqual((gen / 'manifest.json').read_text(), 'state0')
            self.assertFalse((gen / 'maps').exists(), note)
            # 快照丢了：不动现场，也不声称已还原
            state['preSync'] = merge.pin_generated(root, root / 'lane/pre-sync/x')
            (gen / 'oracle/a.json').write_text('later')
            merge.drop_pin(state)
            note = merge.undo_sync(root, state)
            self.assertEqual((gen / 'oracle/a.json').read_text(), 'later')
            self.assertIn('无法确定原状态', note)

    def test_single_abort_during_conflict(self):
        self.put(str(merge.PROJECT / 'modes/测试.gd'), '# main version\n')
        self.g('add', '.'); self.g('commit', '-m', 'conflicting main update')
        before = self.g('rev-parse', 'HEAD')
        self.assertEqual(self.call(), 1)
        self.assertEqual(self.call('--abort'), 0, self.last_output)
        self.assertEqual(self.g('rev-parse', 'HEAD'), before)
        self.assertFalse((self.root / '.git/MERGE_HEAD').exists())
        self.assertFalse(merge.dirty(self.root))
        self.assertIn('本次合并还没同步过', self.last_output)

    def test_finish_accepts_amended_merge_and_explains_extra_commit(self):
        self.assertEqual(self.call(), 0, self.last_output)
        merged = self.g('rev-parse', 'HEAD')
        gd = self.root / merge.PROJECT / 'modes/测试.gd'
        gd.write_text('# fixed by tangseng\n')
        self.g('add', str(gd)); self.g('commit', '--amend', '--no-edit')
        self.register()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertIn('合并提交已修正', self.last_output)
        self.assertEqual(gd.read_text(), '# fixed by tangseng\n')
        self.assertNotEqual(self.g('rev-parse', 'HEAD^'), merged)

    def test_finish_extra_commit_hint_and_untracked_exclude_hint(self):
        (self.root / 'notice.tmp').write_text('x')
        self.assertEqual(self.call(), 1)
        self.assertIn('.git/info/exclude', self.last_output)
        self.assertIn('notice.tmp', self.last_output)
        (self.root / '.git/info').mkdir(exist_ok=True)
        with open(self.root / '.git/info/exclude', 'a') as f:
            f.write('notice.tmp\n')
        self.assertEqual(self.call(), 0, self.last_output)
        self.put('extra.md', 'x\n'); self.g('add', 'extra.md'); self.g('commit', '-m', 'separate fix')
        self.register()
        self.assertEqual(self.call('--finish'), 1)
        self.assertIn('--also', self.last_output)
        self.assertIn('git reset --soft', self.last_output)
        self.assertIn('separate fix', self.last_output)  # 点名多出的是哪个提交

    def test_uid_of_lane_new_script_is_committed(self):
        # 车道新加 modes/测试.gd 但漏交 .uid：main 上导入生成后收尾自动带入；别的未跟踪 .uid 仍拦
        self.assertEqual(self.call(), 0)
        self.register()
        uid = merge.PROJECT / 'modes/测试.gd.uid'
        self.put(str(uid), 'uid://fixture\n')
        self.put(str(merge.PROJECT / 'modes/别的.gd.uid'), 'uid://other\n')
        self.assertEqual(self.call('--finish'), 1)
        self.assertIn('别的.gd.uid', self.last_output)
        (self.root / merge.PROJECT / 'modes/别的.gd.uid').unlink()
        self.assertEqual(self.call('--finish'), 0, self.last_output)
        self.assertIn(str(uid), self.g('-c', 'core.quotepath=false', 'show', '--name-only', '--format=', 'HEAD'))

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
    if sys.argv[1:]:  # 只跑名字含任一参数的用例（类名或方法名片段），调试单项用；TEST_RESULT 只算选中的
        def flat(s):
            for t in s:
                yield from (flat(t) if isinstance(t, unittest.TestSuite) else [t])
        suite = unittest.TestSuite(t for t in flat(suite) if any(a in t.id() for a in sys.argv[1:]))
    result = unittest.TextTestRunner().run(suite)
    passed = result.testsRun - len(result.failures) - len(result.errors)
    # 收尾单列失败用例（哪吒_7 t4 第 4 项：负载下 171/172 那一项没抓到名字）：每项一行，不被进度点覆盖
    for case, _ in result.failures + result.errors:
        print('FAILED_CASE=' + case.id())
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
