#!/usr/bin/env python3
"""提交守卫（装提交守卫.sh＋git-hooks/main-guard.sh）：只用一次性临时资料库，不碰真实 hooks。"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xiyou_guard_')
        self.addCleanup(self.tmp.cleanup)
        self.main = Path(self.tmp.name).resolve() / 'main'
        env = self.main / '03_再刷重制_Godot/07_开发环境'
        (env / 'git-hooks').mkdir(parents=True)
        shutil.copy2(HERE / '装提交守卫.sh', env)
        shutil.copy2(HERE / 'git-hooks/main-guard.sh', env / 'git-hooks')
        self.installer = env / '装提交守卫.sh'
        self.env = {k: v for k, v in os.environ.items() if k not in ('XIYOU_MAIN_COMMIT', 'XIYOU_LANE_MERGE')}
        self.env.update(GIT_AUTHOR_NAME='f', GIT_AUTHOR_EMAIL='f@x.invalid', GIT_COMMITTER_NAME='f', GIT_COMMITTER_EMAIL='f@x.invalid')
        self.git('init', '-q', '-b', 'main')
        self.git('add', '.')
        self.git('commit', '-q', '-m', 'base')                     # 守卫装之前：能提交
        self.lane = Path(self.tmp.name).resolve() / 'lane'
        self.git('worktree', 'add', '-q', '-b', 'claude/task', str(self.lane))
        self.install()

    def git(self, *args, cwd=None, extra=None):
        return subprocess.run(['git', *args], cwd=cwd or self.main, capture_output=True, text=True, env=dict(self.env, **(extra or {})))

    def install(self, *args):
        return subprocess.run(['zsh', str(self.installer), *args], capture_output=True, text=True, env=self.env)

    def commit(self, cwd, extra=None, name='f.txt'):
        (cwd / name).write_text('x\n' + str(len(list(cwd.iterdir()))))
        self.git('add', name, cwd=cwd)
        return self.git('commit', '-q', '-m', 'change', cwd=cwd, extra=extra)

    def test_main_checkout_on_main_is_refused_without_variable(self):
        r = self.commit(self.main)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('这是主工作区 main', r.stderr)
        self.assertEqual(self.git('log', '--oneline').stdout.count('\n'), 1)

    def test_variable_lets_main_commit_through(self):
        self.assertEqual(self.commit(self.main, {'XIYOU_MAIN_COMMIT': '1'}).returncode, 0)
        self.assertEqual(self.git('log', '--oneline').stdout.count('\n'), 2)

    def test_lane_worktree_is_not_affected(self):
        r = self.commit(self.lane)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_main_checkout_on_another_branch_is_not_affected(self):
        self.git('switch', '-q', '-c', 'scratch')
        r = self.commit(self.main)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_lane_branch_named_main_elsewhere_is_not_affected(self):
        # 车道工作树里即使分支叫 main（不可能同时存在，改名后模拟）也只看工作树根
        self.git('switch', '-q', '-c', 'other')
        self.git('worktree', 'remove', '--force', str(self.lane))
        self.git('worktree', 'add', '-q', '-b', 'main2', str(self.lane))
        self.assertEqual(self.commit(self.lane).returncode, 0)

    def test_merge_commit_in_main_is_guarded_too(self):
        self.commit(self.lane)
        (self.main / 'g.txt').write_text('g')
        self.git('add', 'g.txt'); self.git('commit', '-q', '-m', 'main side', extra={'XIYOU_MAIN_COMMIT': '1'})
        r = self.git('merge', '--no-ff', '-m', 'merge', 'claude/task')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('这是主工作区 main', r.stderr)
        self.git('merge', '--abort')
        r = self.git('merge', '--no-ff', '-m', 'merge', 'claude/task', extra={'XIYOU_MAIN_COMMIT': '1'})
        self.assertEqual(r.returncode, 0, r.stderr)

    def merging(self, task='bajie-blackflash', phase='prepared'):
        # 与 合并车道.py save() 同格式（indent=2）
        state = self.main / '.git/lane-merge/state.json'
        state.parent.mkdir(exist_ok=True)
        state.write_text(json.dumps(dict(task=task, branch='cc/' + task, phase=phase, head='x'), ensure_ascii=False, indent=2) + '\n')
        return state

    def test_merge_in_progress_refuses_manual_main_commit_even_with_variable(self):
        self.merging()
        r = self.commit(self.main, {'XIYOU_MAIN_COMMIT': '1'})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('有合并在进行（任务 bajie-blackflash，阶段 待收尾（prepared））', r.stderr)
        self.assertIn('--also', r.stderr)
        self.assertIn('--accept-doc-edits', r.stderr)
        self.assertIn('--abort', r.stderr)
        self.assertEqual(self.git('log', '--oneline').stdout.count('\n'), 1)
        r = self.commit(self.main)                                        # 没带变量：同样先报合并在进行
        self.assertIn('有合并在进行', r.stderr)

    def test_merge_in_progress_lets_merge_tool_commit_through(self):
        self.merging(phase='committed')
        r = self.commit(self.main, {'XIYOU_MAIN_COMMIT': '1', 'XIYOU_LANE_MERGE': '1'})
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_merge_in_progress_guards_merge_commit_and_reports_unknown_phase(self):
        self.commit(self.lane)
        self.merging(task='wukong-hp-cost', phase='synced')
        r = self.git('merge', '--no-ff', '-m', 'merge', 'claude/task', extra={'XIYOU_MAIN_COMMIT': '1'})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('任务 wukong-hp-cost，阶段 准备中（synced）', r.stderr)
        self.git('merge', '--abort')
        (self.main / '.git/lane-merge/state.json').write_text('{}')
        r = self.commit(self.main, {'XIYOU_MAIN_COMMIT': '1'})
        self.assertIn('任务 未知，阶段 未知', r.stderr)

    def test_merge_in_progress_does_not_touch_lanes_or_other_branches(self):
        self.merging()
        self.assertEqual(self.commit(self.lane).returncode, 0)
        self.git('switch', '-q', '-c', 'scratch')
        self.assertEqual(self.commit(self.main).returncode, 0)

    def test_finished_merge_restores_normal_rule(self):
        self.merging().unlink()
        self.assertEqual(self.commit(self.main, {'XIYOU_MAIN_COMMIT': '1'}).returncode, 0)

    def new_worktree(self, *args):
        script = self.main / '03_再刷重制_Godot/07_开发环境/新建工作树.sh'
        if not script.exists():
            shutil.copy2(HERE / '新建工作树.sh', script)
        return subprocess.run(['zsh', str(script), '--补齐', str(self.lane), *args], capture_output=True, text=True, env=self.env)

    def lane_branch(self):
        return self.git('symbolic-ref', '--short', 'HEAD', cwd=self.lane).stdout.strip()

    def test_fill_in_switches_app_worktree_to_assigned_branch_first(self):
        # app 给的工作树在别的分支上：--branch/--from 先切出派单分支再补齐（临时库没有引擎和产物，补齐本身在后面失败）
        (self.main / 'm.txt').write_text('m')
        self.git('add', 'm.txt'); self.git('commit', '-q', '-m', 'main moved', extra={'XIYOU_MAIN_COMMIT': '1'})
        (self.lane / 'scratch.log').write_text('untracked stays')
        r = self.new_worktree('--branch', 'cc/nezha-x', '--from', 'main')
        self.assertIn('切出 cc/nezha-x', r.stdout, r.stderr)
        self.assertEqual(self.lane_branch(), 'cc/nezha-x')
        self.assertEqual(self.git('rev-parse', 'HEAD', cwd=self.lane).stdout, self.git('rev-parse', 'main').stdout)
        self.assertEqual(self.git('show-ref', '--verify', '--quiet', 'refs/heads/claude/task').returncode, 0)   # 原分支不删
        self.assertTrue((self.lane / 'scratch.log').exists())
        self.assertIn('原分支 claude/task 没有自己的提交', r.stdout)                         # app 起的空分支：只提示可删
        self.assertEqual(self.git('show-ref', '--verify', '--quiet', 'refs/heads/claude/task').returncode, 0)
        self.git('switch', '-q', 'claude/task', cwd=self.lane)
        self.new_worktree('--branch', 'cc/nezha-y')                                        # --from 缺省为 main
        self.assertEqual(self.git('rev-parse', 'HEAD', cwd=self.lane).stdout, self.git('rev-parse', 'main').stdout)

    def test_fill_in_branch_switch_refuses_unsafe_cases(self):
        r = self.new_worktree('--from', 'main')
        self.assertEqual(r.returncode, 64)
        self.assertIn('--from 要和 --branch 一起给', r.stderr)
        r = self.new_worktree('--branch', 'cc/z', '--from', 'no-such-ref')
        self.assertIn('--from 找不到', r.stderr)
        r = self.new_worktree('--branch', 'claude/task')
        self.assertIn('已存在', r.stderr)
        self.assertEqual(self.commit(self.lane).returncode, 0)
        r = self.new_worktree('--branch', 'cc/has-work')                                    # 原分支有自己的提交：不提示删
        self.assertIn('切出 cc/has-work', r.stdout)
        self.assertNotIn('用不着可删', r.stdout)
        self.git('switch', '-q', 'claude/task', cwd=self.lane)
        (self.lane / 'f.txt').write_text('dirty')
        r = self.new_worktree('--branch', 'cc/z')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('有未提交的已跟踪改动', r.stderr)
        self.assertEqual(self.lane_branch(), 'claude/task')
        self.assertNotEqual(self.git('show-ref', '--verify', '--quiet', 'refs/heads/cc/z').returncode, 0)

    def test_installer_is_idempotent_checks_and_keeps_foreign_hooks(self):
        self.assertEqual(self.install('--check').returncode, 0)
        out = self.install().stdout
        self.assertNotIn('已装提交守卫', out)                                # 没变就不重装
        hook = self.main / '.git/hooks/pre-commit'
        hook.write_text('#!/bin/sh\necho mine\n')
        r = self.install()
        self.assertEqual(r.returncode, 2)
        self.assertIn('已有别的 hook', r.stderr)
        self.assertEqual(hook.read_text(), '#!/bin/sh\necho mine\n')
        hook.unlink()
        self.assertEqual(self.install('--check').returncode, 1)
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(self.install('--check').returncode, 0)

    def test_installed_from_a_lane_worktree_goes_to_the_shared_hooks(self):
        shutil.rmtree(self.main / '.git/hooks')
        env = self.lane / '03_再刷重制_Godot/07_开发环境'
        r = subprocess.run(['zsh', str(env / '装提交守卫.sh')], capture_output=True, text=True, env=self.env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.main / '.git/hooks/pre-commit').is_file())

    def test_new_worktree_script_installs_guard_and_merge_tool_sets_variable(self):
        self.assertIn('"$MAIN/$GODOT_SUB/07_开发环境/装提交守卫.sh"', (HERE / '新建工作树.sh').read_text(encoding='utf-8'))  # 装主工作区那份
        text = (HERE / '合并车道.py').read_text(encoding='utf-8')
        self.assertEqual(text.count('env=MAIN_COMMIT_ENV'), 3)           # 合并、冲突后提交、收尾提交
        self.assertIn("XIYOU_MAIN_COMMIT='1', XIYOU_LANE_MERGE='1'", text)  # 合并进行中守卫只认后者


if __name__ == '__main__':
    unittest.main()
