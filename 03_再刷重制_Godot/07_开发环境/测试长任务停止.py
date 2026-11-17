#!/usr/bin/env python3
"""T108 回归：两个工作树并发跑检查时，停一边不能伤到另一边。

复现（缩小版）：两个临时 git 工作树各用 长任务.py run 起一个假 检查.sh（带一个假 godot 孙进程），
另一边照 11-16 的习惯按名字 pkill——匹配串限定在本测试的临时目录里，不碰本机真实的检查——先起的那边也被杀，
且终态里记下「外来 SIGTERM」。修法：长任务.py stop／停止任务.sh 只停核实过身份的自己那一轮。
另测 守卫_按名杀进程.py 钩子的拦／放。只在临时目录和自建进程组里进行，收尾只杀自己起的进程组。"""
import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
TASK = HERE / '长任务.py'

FAKE_CHECK = '''#!/bin/zsh
# 假 检查.sh：起一个假 godot 孙进程，然后一直出声
"%s" -c 'import time; time.sleep(60)' --fake-godot &
while true; do print -r -- tick; sleep 0.2; done
'''


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TwoWorktreeTests(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory(prefix='t108_')
        self.tmp = Path(self.tmpdir.name).resolve()
        self.env = dict(os.environ, XIYOU_LONG_TASK_REGISTRY=str(self.tmp / 'registry'))
        self.env.pop('XIYOU_LONG_TASK_MANAGED', None)
        self.runners = []
        self.trees = {}
        for name in ('A', 'B'):
            tree = self.tmp / ('wt_' + name)
            tree.mkdir()
            subprocess.run(['git', 'init', '-q', str(tree)], check=True)
            check = tree / '检查.sh'
            check.write_text(FAKE_CHECK % sys.executable)
            check.chmod(0o755)
            self.trees[name] = tree

    def tearDown(self):
        for p in self.runners:   # 只收拾本测试起的包装器与它们的任务进程组
            for log in self.trees.values():
                try:
                    state = json.loads((log / 'check.log.status.json').read_text())
                    if state.get('childPGID'):
                        os.killpg(state['childPGID'], signal.SIGKILL)
                except (OSError, ValueError):
                    pass
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGKILL)
                p.wait(5)
        self.tmpdir.cleanup()

    def start(self, name):
        tree = self.trees[name]
        p = subprocess.Popen([sys.executable, str(TASK), 'run', str(tree / 'check.log'), '--', str(tree / '检查.sh'),
                              '--affected', 'main'], cwd=tree, env=self.env, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        self.runners.append(p)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            state = self.state(name)
            if state.get('childPGID') and (self.tmp / 'registry' / (state['runId'] + '.json')).exists():
                # 等假 godot 孙进程起来
                if len(self.group(name)) >= 2:
                    return p
            time.sleep(.05)
        self.fail('任务 %s 没起来' % name)

    def state(self, name):
        try:
            return json.loads((self.trees[name] / 'check.log.status.json').read_text())
        except (OSError, ValueError):
            return {}

    def group(self, name):
        group = self.state(name).get('childPGID')
        out = subprocess.run(['ps', '-axo', 'pid=,pgid=,stat='], capture_output=True, text=True).stdout
        return [l for l in out.splitlines() if group and l.split()[1] == str(group) and not l.split()[2].startswith('Z')]

    def wait_done(self, name, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.state(name).get('status') not in (None, 'running'):
                return self.state(name)
            time.sleep(.05)
        return self.state(name)

    def test_repro_name_based_pkill_kills_the_other_worktree_and_is_recorded(self):
        """复现 11-16：B 想重起自己的检查，按名字 pkill，A 也被杀（143），A 的终态记下外来 SIGTERM。"""
        a = self.start('A')
        self.start('B')
        # 照搬 `pkill -f "检查.sh --affected"` 的写法，只把匹配面限定在本测试临时目录
        subprocess.run(['pkill', '-f', '%s/wt_./检查.sh --affected' % self.tmp])
        state = self.wait_done('A')
        self.assertEqual((state.get('status'), state.get('exitCode')), ('failed', 143), '复现失败：A 没被按名字的 pkill 杀掉')
        self.assertIn('外来 SIGTERM', state.get('reason', ''), '外来 SIGTERM 没留痕，下次又只能猜是谁杀的')
        a.wait(10)
        self.assertEqual(self.group('A'), [], 'A 的假 godot 孙进程没被一起收掉')

    def test_stop_in_own_worktree_leaves_the_other_running(self):
        """修法：在 B 里跑 停止任务.sh（不给日志＝停本工作树的任务），A 照跑。"""
        self.start('A')
        self.start('B')
        p = subprocess.run([str(HERE / '停止任务.sh')], cwd=self.trees['B'], env=self.env, capture_output=True,
                           text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        b = self.wait_done('B')
        self.assertEqual((b.get('status'), b.get('reason')), ('failed', '已由 长任务.py stop 主动停止'))
        self.assertEqual(self.group('B'), [], 'B 的假 godot 孙进程没停掉')
        time.sleep(.5)
        self.assertEqual(self.state('A').get('status'), 'running', 'B 的 stop 伤到了 A')
        self.assertGreaterEqual(len(self.group('A')), 2)
        # 按日志停 A
        p = subprocess.run([sys.executable, str(TASK), 'stop', str(self.trees['A'] / 'check.log')], env=self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(self.wait_done('A').get('status'), 'failed')
        self.assertEqual(list((self.tmp / 'registry').glob('*.json')), [], '结束的任务没从登记里删掉')

    def test_list_only_shows_own_worktree(self):
        self.start('A')
        self.start('B')
        p = subprocess.run([sys.executable, str(TASK), 'list'], cwd=self.trees['A'], env=self.env,
                           capture_output=True, text=True, timeout=30)
        self.assertIn(str(self.trees['A'] / 'check.log'), p.stdout)
        self.assertNotIn(str(self.trees['B'] / 'check.log'), p.stdout)


class StopRefusesUnverifiedTests(unittest.TestCase):
    def test_stop_does_not_signal_when_identity_mismatch(self):
        task = load('long_task_t108', TASK)
        with tempfile.TemporaryDirectory() as d:
            victim = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'], start_new_session=True)
            try:
                log = Path(d) / 'x.log'
                fake = {'pid': victim.pid, 'pgid': victim.pid, 'startedAt': 'Thu Jan  1 00:00:00 1970'}
                (Path(d) / 'x.log.status.json').write_text(json.dumps(
                    {'runId': 'r', 'status': 'running', 'pid': victim.pid, 'wrapperIdentity': fake,
                     'childPGID': victim.pid, 'childIdentity': fake}))
                import contextlib, io
                with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(task.stop_task(log, grace=.3), 2)
                self.assertIsNone(victim.poll(), '身份对不上还发了信号')
            finally:
                victim.kill()
                victim.wait()


class NameKillGuardTests(unittest.TestCase):
    def setUp(self):
        self.guard = load('guard_t108', HERE / '守卫_按名杀进程.py')
        self.tree = HERE.parent.parent  # 本仓库工作树

    def test_blocks_the_three_commands_from_1116(self):
        for cmd in ('pkill -f 检查.sh; pkill -f 并行测试.py; sleep 3; pkill -f "Godot"',
                    'pkill -f "检查.sh --affected main"; pkill -f "并行测试.py"',
                    'cd x && pkill -f "检查.sh --affected" ; pkill -f "并行测试.py"',
                    'killall godot'):
            self.assertIsNotNone(self.guard.verdict(cmd, str(self.tree)), cmd)

    def test_allows_scoped_and_unrelated(self):
        name = Path(self.guard.worktree(str(self.tree))).name
        for cmd in ('pkill -f "godot.*--path.*%s"' % name, 'ps aux | grep godot', 'kill %d' % os.getpid(),
                    'python3 07_开发环境/长任务.py stop x.log', 'pkill -f my_http_server'):
            self.assertIsNone(self.guard.verdict(cmd, str(self.tree)), cmd)

    def test_hook_exit_codes(self):
        def run(payload):
            return subprocess.run([sys.executable, str(HERE / '守卫_按名杀进程.py')], input=json.dumps(payload),
                                  capture_output=True, text=True, timeout=30)
        p = run({'tool_name': 'Bash', 'cwd': str(self.tree), 'tool_input': {'command': 'pkill -f 检查.sh'}})
        self.assertEqual(p.returncode, 2)
        self.assertIn('停止任务.sh', p.stderr)
        self.assertEqual(run({'tool_name': 'Bash', 'cwd': str(self.tree), 'tool_input': {'command': 'ls'}}).returncode, 0)
        self.assertEqual(run({'tool_name': 'Read', 'tool_input': {}}).returncode, 0)


if __name__ == '__main__':
    unittest.main()
