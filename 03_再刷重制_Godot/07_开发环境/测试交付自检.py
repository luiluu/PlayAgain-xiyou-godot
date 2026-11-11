#!/usr/bin/env python3
"""交付自检.py、待合.py 的回归；Git 操作只在临时资料库里做。"""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


pre = load('precheck_tool', HERE / '交付自检.py')
board = load('board_tool', HERE / '待合.py')
merge = pre.merge
SHEET = '# 交付：%s\n\n- 车道／工作者：D 工具／哪吒（cc）\n- 状态：%s\n\n## 变更记录草稿\n\n## 2026-11-11 【cc·哪吒·未经审查】功能（' + merge.VERSION_MARKER + '）\n\n- 夹具\n'
OPT = 'O-' + '待定'


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xiyou_precheck_fixture_')
        self.root = Path(self.tmp.name) / 'main'
        self.root.mkdir()
        self.old_env = {k: os.environ.get(k) for k in ['GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL',
                                                        'GIT_AUTHOR_DATE', 'GIT_COMMITTER_DATE']}
        for kind in ['AUTHOR', 'COMMITTER']:
            os.environ['GIT_' + kind + '_NAME'] = 'fixture'
            os.environ['GIT_' + kind + '_EMAIL'] = 'fixture@example.invalid'
        self.clock = 1_800_000_000
        self.g('init', '-b', 'main')
        self.put('00_项目管理/交付/README.md', '# 交付单\n')
        self.put(str(merge.OPT_REGISTRY), '# 优化登记\n\n| 编号 | 项目 | 位置 | 原版 | 重制 | 理由 | 恢复方法 | 状态 |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n')
        self.put(str(merge.PROJECT / 'modes/a.gd'), 'extends Node\n\nfunc one():\n\tpass\n')
        self.put(str(merge.PROJECT / 'modes/b.gd'), 'extends Node\n\n\nfunc keep():\n\tpass\n\n\nfunc tail():\n\tpass\n')
        self.commit('base')

    def tearDown(self):
        for key, value in self.old_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        self.tmp.cleanup()

    def g(self, *args, cwd=None):
        return subprocess.run(['git', '-C', str(cwd or self.root), *args], capture_output=True, text=True, check=True).stdout.strip()

    def put(self, path, text, cwd=None):
        p = (cwd or self.root) / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def commit(self, message, cwd=None, at=None):
        """提交全部改动；at 给了就把提交时间定在那一秒（看板按分支头的提交时间算等了多久）。"""
        self.clock += 60
        when = '%d +0000' % (at or self.clock)
        os.environ['GIT_AUTHOR_DATE'] = os.environ['GIT_COMMITTER_DATE'] = when
        self.g('add', '-A', cwd=cwd)
        self.g('commit', '-q', '-m', message, cwd=cwd)

    def lane(self, branch, files=None, status='可合并', sheet=None, extra='', at=None, name=None):
        """建一条车道工作树：files＝{相对路径: 内容}，交付单默认按分支名。返回工作树路径。"""
        wt = Path(self.tmp.name) / (name or branch.replace('/', '_'))
        self.g('worktree', 'add', '-q', '-b', branch, str(wt), 'main')
        for rel, text in (files or {str(merge.PROJECT / ('modes/new_%s.gd' % branch.split('/')[-1].replace('-', '_'))): 'extends Node\n'}).items():
            self.put(rel, text, cwd=wt)
        if sheet is not False:
            self.put('00_项目管理/交付/%s.md' % (sheet or branch.replace('/', '_')), SHEET % (branch, status) + extra, cwd=wt)
        self.commit('lane ' + branch, cwd=wt, at=at)
        return wt

    def snapshot(self):
        """本库的引用、对象数、各工作树状态：只读工具跑完必须一模一样。"""
        trees = [w['path'] for w in merge.worktrees(self.root)]
        return (self.g('for-each-ref'), self.g('count-objects', '-v'), [self.g('status', '--porcelain', cwd=t) for t in trees],
                [self.g('rev-parse', 'HEAD', cwd=t) for t in trees])


class PrecheckTests(Fixture):
    def check(self, branch, **kw):
        return pre.check(self.root, branch, **kw)

    def test_clean_fast_lane_passes_and_touches_nothing(self):
        wt = self.lane('cc/task')
        before = self.snapshot()
        r = pre.check(wt, 'cc/task')
        self.assertEqual(r['problems'], [])
        self.assertEqual((r['status'], r['slow'], r['gameplay'], r['task']), ('ready', False, True, 'task'))
        self.assertEqual(r['delivery'], '00_项目管理/交付/cc_task.md')
        self.assertEqual(self.snapshot(), before)

    def test_cli_exit_codes_and_json(self):
        wt = self.lane('cc/task')
        script = str(HERE / '交付自检.py')
        ok = subprocess.run([sys.executable, script, '--root', str(wt), '--json'], capture_output=True, text=True)
        self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
        self.assertEqual(json.loads(ok.stdout)['branch'], 'cc/task')
        self.put('stray.txt', 'x', cwd=wt)
        bad = subprocess.run([sys.executable, script, '--root', str(wt)], capture_output=True, text=True)
        self.assertEqual(bad.returncode, 1, bad.stdout + bad.stderr)
        self.assertIn('未提交或未跟踪', bad.stdout)
        on_main = subprocess.run([sys.executable, script, '--root', str(self.root)], capture_output=True, text=True)
        self.assertEqual(on_main.returncode, 2)

    def test_sheet_not_marked_ready(self):
        self.lane('cc/task', status='进行中')
        r = self.check('cc/task')
        self.assertEqual(r['status'], 'wip')
        self.assertTrue(any('尚未标为可合并' in p for p in r['problems']))

    def test_missing_sheet(self):
        self.lane('cc/task', sheet=False)
        r = self.check('cc/task')
        self.assertEqual(r['status'], 'nosheet')
        self.assertTrue(any('缺少交付单' in p for p in r['problems']))

    def test_empty_draft_section(self):
        wt = self.lane('cc/task')
        self.put('00_项目管理/交付/cc_task.md', '# 交付：cc/task\n\n- 状态：可合并\n\n## 变更记录草稿\n\n（待写）\n', cwd=wt)
        self.commit('empty draft', cwd=wt)
        r = self.check('cc/task')
        self.assertEqual(r['status'], 'draft')
        self.assertTrue(any('待写' in p for p in r['problems']))

    def test_opt_draft_written_as_list_is_caught(self):
        # 11-10 天启篇开局那次：优化登记草稿写成列表，合并时才被拦
        self.lane('cc/task', extra='\n## 优化登记草稿\n\n- %s 某开关（默认开）\n' % OPT)
        r = self.check('cc/task')
        self.assertTrue(any('是列表不是表格' in p for p in r['problems']), r['problems'])

    def test_opt_placeholder_without_draft_table(self):
        self.lane('cc/task', extra='\n## 说明\n\n- 新开关登记为 %s\n' % OPT)
        r = self.check('cc/task')
        self.assertTrue(any('没有「## 优化登记草稿」表行' in p for p in r['problems']), r['problems'])

    def test_conflict_with_main_is_reported(self):
        rel = str(merge.PROJECT / 'modes/a.gd')
        self.lane('cc/task', files={rel: 'extends Node\n\nfunc one():\n\treturn 1\n'})
        self.put(rel, 'extends Node\n\nfunc one():\n\treturn 2\n')
        self.commit('main edits same line')
        before = self.snapshot()
        r = self.check('cc/task')
        self.assertEqual(r['conflicts'], [rel])
        self.assertTrue(any('有冲突' in p and 'git merge main' in p for p in r['problems']))
        self.assertEqual(self.snapshot(), before)

    def test_duplicate_func_after_clean_auto_merge(self):
        # 10-28：车道与 main 各加一个同名函数，位置不挨着，git 自动合并不报冲突，工程整个 Parse Error
        rel = str(merge.PROJECT / 'modes/b.gd')
        self.lane('cc/task', files={rel: 'extends Node\n\n\nfunc dup():\n\tpass\n\n\nfunc keep():\n\tpass\n\n\nfunc tail():\n\tpass\n'})
        self.put(rel, 'extends Node\n\n\nfunc keep():\n\tpass\n\n\nfunc tail():\n\tpass\n\n\nfunc dup():\n\tpass\n')
        self.commit('main adds dup at the end')
        r = self.check('cc/task')
        self.assertEqual(r['conflicts'], [])
        self.assertTrue(any('func dup 重复定义' in p for p in r['problems']), r['problems'])

    def test_sheet_edited_after_it_was_merged_and_deleted_on_main(self):
        # 实测（11-11 Mac 主仓库）：上一期合并后车道在旧交付单上补写备注，main 已把它归并删除，试合并报 modify/delete
        wt = self.lane('cc/task')
        self.g('merge', '-q', '--no-ff', 'cc/task', '-m', 'merge')
        self.g('rm', '-q', '00_项目管理/交付/cc_task.md')
        self.commit('fold sheet')
        with (wt / '00_项目管理/交付/cc_task.md').open('a') as f:
            f.write('\n- 合并后补记\n')
        self.commit('note after merge', cwd=wt)
        r = self.check('cc/task')
        self.assertEqual(r['conflicts'], ['00_项目管理/交付/cc_task.md'])
        self.assertTrue(any('已随上一期归并删除' in p and '重写交付单' in p for p in r['problems']), r['problems'])

    def test_main_advanced_without_conflict_is_only_a_hint(self):
        self.lane('cc/task')
        self.put('另一处.md', 'x\n')
        self.commit('main moves on')
        r = self.check('cc/task')
        self.assertEqual(r['problems'], [])
        self.assertTrue(any('验收只做一轮' in h for h in r['hints']))

    def test_slow_lane_is_classified(self):
        rel = str(merge.TOOLS / 'mv_oracle/x_probe.cjs')
        self.lane('cc/task', files={rel: '// probe\n'})
        r = self.check('cc/task')
        self.assertTrue(r['slow'])
        self.assertEqual(r['slowWhy'], ['mv_oracle/x_probe.cjs'])
        self.assertFalse(r['gameplay'])
        self.assertIn('慢车道', pre.lane_class(r))

    def test_slow_lane_on_machine_without_products_is_a_hint(self):
        wt = self.lane('cc/task', files={str(merge.TOOLS / 'mv_oracle/x_probe.cjs'): '// probe\n'})
        r = pre.check(wt, 'cc/task')
        self.assertEqual(r['problems'], [])
        self.assertTrue(any('没有转换产物' in h for h in r['hints']))

    def test_slow_lane_without_sync_stamp_is_a_problem(self):
        wt = self.lane('cc/task', files={str(merge.TOOLS / 'mv_oracle/x_probe.cjs'): '// probe\n', '.gitignore': '/' + str(pre.GENERATED) + '/\n'})
        (wt / pre.GENERATED).mkdir(parents=True)
        (wt / pre.GENERATED / 'db.json').write_text('{}')
        r = pre.check(wt, 'cc/task')
        self.assertTrue(any('没有同步指纹' in p for p in r['problems']), r['problems'])

    def test_pending_acceptance_needs_sheet_covering_every_change(self):
        # merge18：main 同步拒收，接受单先是没有、后来 15 处变化只带了 1 条
        tools = str(merge.TOOLS)
        sync = ('import hashlib\nfrom pathlib import Path\n\n\ndef tools_digest(root=None):\n    return "same"\n')
        wt = self.lane('cc/task', files={tools + '/mv_oracle/x_probe.cjs': '// probe\n', tools + '/同步正式西游.py': sync,
                                         '.gitignore': '/' + str(pre.GENERATED) + '/\n/' + str(merge.SUB / '04_验证/本地结果') + '/\n'})
        (wt / pre.GENERATED).mkdir(parents=True)
        (wt / pre.GENERATED / 'sync_stamp.json').write_text(json.dumps({'toolsDigest': 'same', 'pendingAcceptance': True}))
        report = wt / merge.SUB / '04_验证/本地结果/自动同步/20261110_010101/同步报告.json'
        report.parent.mkdir(parents=True)
        cands = [{'file': 'events.json', 'collection': 'cases', 'key': [['id', 'm4e71p0']]},
                 {'file': 'event_states.json', 'collection': 'cases', 'key': [['id', 'm30e8p0#i7']]}]
        report.write_text(json.dumps({'changeCandidates': cands}, ensure_ascii=False))
        r = pre.check(wt, 'cc/task')
        self.assertTrue(any('没有接受单' in p for p in r['problems']), r['problems'])
        accept = str(merge.ACCEPT / 'cc_task.json')
        self.put(accept, json.dumps({'schema': 1, 'accept': [dict(cands[0], reason='hboot 修复预期')]}, ensure_ascii=False), cwd=wt)
        self.commit('one entry', cwd=wt)
        r = pre.check(wt, 'cc/task')
        self.assertTrue(any('接受单少 1 条' in p for p in r['problems']), r['problems'])
        self.put(accept, json.dumps({'schema': 1, 'accept': [dict(c, reason='预期变化') for c in cands]}, ensure_ascii=False), cwd=wt)
        self.commit('all entries', cwd=wt)
        self.assertEqual(pre.check(wt, 'cc/task')['problems'], [])
        # 同步之后又改了转换工具：指纹失效
        (wt / pre.GENERATED / 'sync_stamp.json').write_text(json.dumps({'toolsDigest': 'older'}))
        self.assertTrue(any('指纹失效' in p for p in pre.check(wt, 'cc/task')['problems']))

    def test_dirty_worktree_and_evidence_dirs(self):
        wt = self.lane('cc/task')
        self.put(str(merge.SUB / '04_验证/本地结果/并行测试/x.log'), 'log', cwd=wt)
        self.assertEqual(pre.check(wt, 'cc/task')['problems'], [])           # 本地输出目录下的未跟踪文件不拦
        self.put('草稿.txt', 'x', cwd=wt)
        r = pre.check(wt, 'cc/task')
        self.assertTrue(any('未提交或未跟踪' in p for p in r['problems']), r['problems'])
        # 从别的工作树按分支名查时不看那棵树的现场
        self.assertEqual(pre.check(self.root, 'cc/task')['problems'], [])

    def test_random_branch_name_with_single_sheet(self):
        self.lane('cc/gifted-keller-3427f6', sheet='cc_rules-x')
        r = self.check('cc/gifted-keller-3427f6')
        self.assertEqual((r['task'], r['problems']), ('rules-x', []))
        self.assertEqual(r['delivery'], '00_项目管理/交付/cc_rules-x.md')

    def test_already_merged_branch(self):
        self.lane('cc/task')
        self.g('merge', '-q', '--no-ff', 'cc/task', '-m', 'merge')
        r = self.check('cc/task')
        self.assertEqual((r['status'], r['problems']), ('merged', []))
        out = io.StringIO()
        pre.render(r, out)
        self.assertIn('没有要合并的', out.getvalue())

    def test_remote_only_branch_and_shallow_source(self):
        # 云端线程的分支只在远端；云端容器是浅克隆，git clone --shared 在那里会丢远端分支的对象
        self.put('第二个提交.md', 'x\n')
        self.commit('second')
        self.lane('cc/task')
        bare = Path(self.tmp.name) / 'remote.git'
        self.g('clone', '-q', '--bare', str(self.root), str(bare))
        clone = Path(self.tmp.name) / 'cloud'
        subprocess.run(['git', 'clone', '-q', '--depth', '2', '--no-single-branch', 'file://' + str(bare), str(clone)], check=True, capture_output=True)
        self.assertEqual(self.g('rev-parse', '--is-shallow-repository', cwd=clone), 'true')
        r = pre.check(clone, 'origin/cc/task')
        self.assertEqual((r['branch'], r['problems']), ('cc/task', []))

    def test_pick_main_prefers_the_newest(self):
        bare = Path(self.tmp.name) / 'remote.git'
        self.g('clone', '-q', '--bare', str(self.root), str(bare))
        clone = Path(self.tmp.name) / 'clone'
        subprocess.run(['git', 'clone', '-q', str(bare), str(clone)], check=True, capture_output=True)
        self.assertEqual(pre.pick_main(clone)[0], 'main')
        self.put('新.md', 'x\n')
        self.commit('main moves on')
        self.g('push', '-q', str(bare), 'main')
        self.g('fetch', '-q', 'origin', cwd=clone)
        ref, sha = pre.pick_main(clone)                      # 本地 main 落后，远端的新
        self.assertEqual((ref, sha), ('origin/main', self.g('rev-parse', 'main')))
        self.assertEqual(pre.pick_main(clone, 'main')[1], self.g('rev-parse', 'main', cwd=clone))
        with self.assertRaises(RuntimeError):
            pre.pick_main(clone, 'no-such-ref')


class BoardTests(Fixture):
    NOW = 1_800_100_000

    def board(self, **kw):
        return board.board(self.root, now=self.NOW, **kw)

    def test_order_fast_first_then_slow_by_delivery_time(self):
        self.lane('cc/slow', files={str(merge.TOOLS / 'mv_oracle/x_probe.cjs'): '// probe\n'}, at=self.NOW - 9 * 3600)
        self.lane('cc/fast-late', at=self.NOW - 600)
        self.lane('cc/fast-early', at=self.NOW - 5 * 3600)
        self.lane('cc/wip', status='进行中', at=self.NOW - 300)
        self.lane('cc/nosheet', sheet=False, at=self.NOW - 200)
        self.lane('cc/ancient-wip', status='进行中', at=self.NOW - 30 * 86400)
        self.lane('ci/cc/fast-early', sheet=False, at=self.NOW - 100)     # 云端测试的推送分支不是车道
        before = self.snapshot()
        b = self.board()
        self.assertEqual(self.snapshot(), before)
        self.assertEqual([x['branch'] for x in b['ready']], ['cc/fast-early', 'cc/fast-late', 'cc/slow'])
        self.assertEqual([x['slow'] for x in b['ready']], [False, False, True])
        self.assertEqual(b['blocked'], [])
        self.assertEqual([(x['branch'], x['status']) for x in b['pending']], [('cc/nosheet', 'nosheet'), ('cc/wip', 'wip')])
        self.assertEqual(b['hidden'], 1)
        self.assertEqual(b['ready'][0]['worker'], 'D 工具／哪吒（cc）')
        out = io.StringIO()
        board.render(b, out=out)
        text = out.getvalue()
        self.assertIn('快车道先合先推：合并车道.py --queue fast-early=cc/fast-early,fast-late=cc/fast-late --affected --cloud', text)
        self.assertIn('慢车道另起一批（队尾或夜里，合并要同步）：合并车道.py --queue slow=cc/slow', text)
        self.assertIn('| 1 | cc/fast-early | D 工具／哪吒（cc） | 5 小时 00 分 | 快 | 本地 | ⚠ 等过 4 小时 |', text)
        self.assertIn('另有 1 条更早的没交付分支没列', text)
        self.assertEqual([x['branch'] for x in self.board(show_all=True)['pending']], ['cc/nosheet', 'cc/wip', 'cc/ancient-wip'])

    def test_lanes_conflicting_with_each_other_later_one_goes_back(self):
        rel = str(merge.PROJECT / 'modes/a.gd')
        self.lane('cc/first', files={rel: 'extends Node\n\nfunc one():\n\treturn 1\n'}, at=self.NOW - 7200)
        self.lane('cc/second', files={rel: 'extends Node\n\nfunc one():\n\treturn 2\n'}, at=self.NOW - 3600)
        self.lane('cc/third', at=self.NOW - 1800)
        b = self.board()
        self.assertEqual([x['branch'] for x in b['ready']], ['cc/first', 'cc/third'])
        self.assertEqual([x['branch'] for x in b['blocked']], ['cc/second'])
        self.assertTrue(any('排在它前面的 cc/first 合进去之后有冲突' in p for p in b['blocked'][0]['problems']), b['blocked'][0]['problems'])
        out = io.StringIO()
        board.render(b, out=out)
        self.assertIn('## 退回车道', out.getvalue())
        self.assertIn('--queue first=cc/first,third=cc/third', out.getvalue())

    def test_failed_precheck_goes_to_blocked_with_reason(self):
        self.lane('cc/bad', extra='\n## 优化登记草稿\n\n- %s 某开关\n' % OPT, at=self.NOW - 3600)
        b = self.board()
        self.assertEqual(b['ready'], [])
        self.assertTrue(any('是列表不是表格' in p for p in b['blocked'][0]['problems']))

    def test_merged_lanes_and_old_deliveries(self):
        self.lane('cc/done', at=self.NOW - 3600)
        self.g('merge', '-q', '--no-ff', 'cc/done', '-m', 'merge')
        self.lane('cc/forgotten', at=self.NOW - 2 * 86400)             # 开场声明屏那种：交了两天没人合，必须列出来
        self.lane('cc/abandoned', at=self.NOW - 40 * 86400)
        b = self.board()
        self.assertEqual([x['branch'] for x in b['ready']], ['cc/forgotten'])
        self.assertEqual(b['old'], ['cc/abandoned'])
        out = io.StringIO()
        board.render(b, out=out)
        self.assertIn('| 1 | cc/forgotten | D 工具／哪吒（cc） | 2 天 | 快 | 本地 | ⚠ 等过 4 小时 |', out.getvalue())
        self.assertIn('交付超过 14 天还没合的 1 条没查', out.getvalue())
        self.assertEqual([x['branch'] for x in self.board(show_all=True)['ready']], ['cc/abandoned', 'cc/forgotten'])

    def test_remote_only_and_newer_remote(self):
        self.lane('cc/cloud', at=self.NOW - 3600)
        wt = self.lane('cc/both', at=self.NOW - 7200)
        bare = Path(self.tmp.name) / 'remote.git'
        self.g('clone', '-q', '--bare', str(self.root), str(bare))
        self.g('remote', 'add', 'github', str(bare))
        # 远端的 cc/both 比本地多一个提交；cc/cloud 本地删掉、只在远端
        other = Path(self.tmp.name) / 'other'
        subprocess.run(['git', 'clone', '-q', str(bare), str(other)], check=True, capture_output=True)
        self.g('checkout', '-q', 'cc/both', cwd=other)
        self.put('更多.md', 'x\n', cwd=other)
        self.commit('more', cwd=other, at=self.NOW - 1800)
        self.g('push', '-q', 'origin', 'cc/both', cwd=other)
        self.g('fetch', '-q', 'github')
        self.g('worktree', 'remove', '--force', str(Path(self.tmp.name) / 'cc_cloud'))
        self.g('branch', '-q', '-D', 'cc/cloud')
        b = self.board()
        rows = {x['branch']: x for x in b['ready']}
        self.assertEqual(sorted(rows), ['cc/both', 'cc/cloud'])
        self.assertEqual(rows['cc/cloud']['where'], 'github')
        self.assertEqual(rows['cc/both']['sha'], self.g('rev-parse', 'github/cc/both'))
        self.assertIn('github 的比 本地 的新', rows['cc/both']['note'])
        out = io.StringIO()
        board.render(b, out=out)
        self.assertIn('只在远端：先 git fetch github cc/cloud:cc/cloud', out.getvalue())
        self.assertTrue(wt.is_dir())

    def test_cli_check_flag_and_json(self):
        self.lane('cc/task')
        script = str(HERE / '待合.py')
        # 夹具的提交时间在 2027 年，真实时钟下「等了」不到阈值；阈值调成负数就算超时
        fresh = subprocess.run([sys.executable, script, '--root', str(self.root), '--check', '--stale-hours', '1000000'], capture_output=True, text=True)
        self.assertEqual(fresh.returncode, 0, fresh.stdout + fresh.stderr)
        stale = subprocess.run([sys.executable, script, '--root', str(self.root), '--check', '--stale-hours', '-1000000', '--json'],
                               capture_output=True, text=True)
        self.assertEqual(stale.returncode, 1, stale.stdout + stale.stderr)
        data = json.loads(stale.stdout)
        self.assertEqual([x['branch'] for x in data['ready']], ['cc/task'])
        self.assertNotIn('changed', data['ready'][0])

    def test_empty_board(self):
        out = io.StringIO()
        board.render(self.board(), out=out)
        self.assertIn('没有待合的车道', out.getvalue())


if __name__ == '__main__':
    names = [a for a in sys.argv[1:] if not a.startswith('-')]
    if names:
        suite = unittest.TestSuite()
        for name in names:
            suite.addTests(unittest.defaultTestLoader.loadTestsFromName(name, sys.modules[__name__]))
        raise SystemExit(0 if unittest.TextTestRunner(verbosity=1).run(suite).wasSuccessful() else 1)
    unittest.main()
