#!/usr/bin/env python3
"""在临时项目与模拟 Godot 中验证导入失败传播；不联网、不装依赖。"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


class CloudImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='xiyou_cloud_import_')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env_dir = self.root / '07_开发环境'
        self.env_dir.mkdir()
        self.script = self.env_dir / '云端准备.sh'
        shutil.copy2(HERE / self.script.name, self.script)
        (self.env_dir / '环境登记.json').write_text(json.dumps({'version': 'fixture'}))
        self.project = self.root / '01_Godot工程'
        generated = self.project / 'modes/xiyou/generated'
        generated.mkdir(parents=True)
        (generated / 'manifest.json').write_text('{}')
        self.cache = self.project / '.godot'
        (self.cache / 'imported').mkdir(parents=True)  # 已有半成品也不能跳过导入
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name, text in {'zsh': 'exit 0', 'nproc': 'echo 2',
                           'timeout': 'shift\nexec "$@"'}.items():
            self.executable(self.bin / name, text)
        godot = self.root / '.cache/xiyou-godot/fixture/Godot_vfixture-stable_linux.x86_64'
        godot.parent.mkdir(parents=True)
        self.executable(godot, '''
if [ "$2" = "--version" ]; then exit 0; fi
echo import >> "$FIXTURE_CALLS"
if [ "$FIXTURE_MODE" = "script_error" ]; then
  echo 'SCRIPT ERROR: fixture parse error'
  exit 0
fi
if [ "$FIXTURE_MODE" = "engine_error" ]; then
  echo 'ERROR: fixture import error'
  exit 0
fi
if [ "$FIXTURE_MODE" = "timeout" ]; then exit 124; fi
echo 'fixture import complete'
exit 0
''')

    @staticmethod
    def executable(path, text):
        path.write_text('#!/bin/sh\n' + text + '\n')
        path.chmod(0o755)

    def run_script(self, mode):
        env = dict(os.environ, HOME=str(self.root), PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                   FIXTURE_MODE=mode, FIXTURE_CALLS=str(self.root / 'calls'))
        return subprocess.run(['bash', str(self.script)], env=env, capture_output=True, text=True,
                              errors='backslashreplace')

    def test_timeout_is_failure_and_next_run_retries(self):
        failed = self.run_script('timeout')
        self.assertEqual(failed.returncode, 124, failed)
        self.assertNotIn('export GODOT=', failed.stdout)
        self.assertTrue((self.cache / 'cloud-import.log').is_file())
        success = self.run_script('ok')
        self.assertEqual(success.returncode, 0, success)
        self.assertIn('export GODOT=', success.stdout)
        self.assertEqual((self.root / 'calls').read_text().splitlines(), ['import', 'import'])

    def test_script_error_with_zero_exit_is_failure(self):
        failed = self.run_script('script_error')
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn('SCRIPT ERROR', failed.stderr)
        self.assertNotIn('export GODOT=', failed.stdout)

    def test_engine_error_with_zero_exit_is_failure(self):
        failed = self.run_script('engine_error')
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn('ERROR:', failed.stderr)
        self.assertNotIn('export GODOT=', failed.stdout)


class CloudWaitTests(unittest.TestCase):
    """云端选测.py wait：临时资料库＋本地裸库充当 GitHub，gh 用桩（XIYOU_GH）。"""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='xiyou_cloud_wait_')
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name).resolve()
        self.repo, self.remote = root / 'repo', root / 'remote.git'
        env_dir = self.repo / '03_再刷重制_Godot/07_开发环境'
        env_dir.mkdir(parents=True)
        shutil.copy2(HERE / '云端选测.py', env_dir)
        self.tool = env_dir / '云端选测.py'
        self.env = dict(os.environ, GIT_AUTHOR_NAME='f', GIT_AUTHOR_EMAIL='f@x.invalid', GIT_COMMITTER_NAME='f', GIT_COMMITTER_EMAIL='f@x.invalid')
        self.env.pop('GITHUB_ACTIONS', None)
        subprocess.run(['git', 'init', '-q', '--bare', str(self.remote)], check=True)
        self.git('init', '-q', '-b', 'main')
        self.git('remote', 'add', 'origin', str(self.remote))
        self.git('add', '.'); self.git('commit', '-q', '-m', 'base')
        self.sha = self.git('rev-parse', 'HEAD')
        self.gh = root / 'gh'

    def git(self, *args, stdin=None):
        return subprocess.run(['git', '-C', str(self.repo), *args], input=stdin, capture_output=True, text=True, check=True, env=self.env).stdout.strip()

    def publish(self, mode, passed=True, sha=None):
        blob = lambda text: self.git('hash-object', '-w', '--stdin', stdin=text)
        tree = self.git('mktree', stdin='100644 blob %s\tresult.json\n100644 blob %s\tsummary.md\n'
                        % (blob(json.dumps({'passed': passed})), blob('云端汇总 ' + mode)))
        commit = self.git('commit-tree', tree, '-m', 'r')
        self.git('push', '-q', 'origin', '%s:refs/ci/results/%s/%s' % (commit, sha or self.sha, mode))

    def stub_gh(self, statuses):
        self.gh.write_text('#!/bin/sh\necho \'%s\'\n' % json.dumps([{'status': s} for s in statuses])); self.gh.chmod(0o755)

    def wait(self, *args, timeout=6):
        env = dict(self.env, XIYOU_GH=str(self.gh))
        return subprocess.run([sys.executable, str(self.tool), 'wait', self.sha, '--interval', '1', '--timeout', str(timeout), *args],
                              capture_output=True, text=True, env=env)

    def test_full_result_satisfies_affected_wait(self):
        """选测扩成整轮时云端把结果写在 /full：等 affected 的（检查.sh）也要认。"""
        self.stub_gh(['in_progress'])
        self.publish('full')
        r = self.wait('--mode', 'affected')
        self.assertEqual((r.returncode, r.stdout.strip()), (0, '云端汇总 full'), r.stderr)

    def test_affected_result_and_failure(self):
        self.stub_gh(['in_progress'])
        self.publish('affected', passed=False)
        self.assertEqual(self.wait().returncode, 1)

    def test_full_wait_ignores_affected_result(self):
        self.stub_gh(['in_progress'])
        self.publish('affected')
        r = self.wait('--mode', 'full', timeout=2)
        self.assertEqual(r.returncode, 124, r.stdout)

    def test_timeout_when_run_still_going(self):
        self.stub_gh(['in_progress'])
        r = self.wait(timeout=2)
        self.assertEqual(r.returncode, 124)
        self.assertIn('还没有', r.stdout)

    def test_finished_run_without_result_fails_fast(self):
        self.stub_gh(['completed'])
        r = self.wait(timeout=60)
        self.assertEqual(r.returncode, 3, r.stdout)
        self.assertIn('云端运行已结束', r.stdout)

    def commit(self, name):
        (self.repo / name).write_text(name)
        self.git('add', name); self.git('commit', '-q', '-m', name)
        return self.git('rev-parse', 'HEAD')

    def test_verified_base_is_nearest_ancestor_with_passed_result(self):
        c1 = self.sha
        c2 = self.commit('b'); c3 = self.commit('c'); self.commit('d')
        self.git('push', '-q', 'origin', 'HEAD:refs/heads/main')
        self.publish('affected', sha=c1)
        self.publish('full', passed=False, sha=c3)        # 最近的一个没通过：跳过
        self.publish('affected', sha=c2)
        import importlib.util
        spec = importlib.util.spec_from_file_location('cloud', self.tool)
        mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        self.assertEqual(mod.verified_base(str(self.remote), mod.cache_repo()), c2)
        self.git('push', '-q', '--delete', 'origin', 'refs/ci/results/%s/affected' % c2)
        self.assertEqual(mod.verified_base(str(self.remote), mod.cache_repo()), c1)

    def test_run_pins_base_ref_and_pushes_branch(self):
        c1 = self.sha
        head = self.commit('b')
        self.publish('affected', sha=c1)
        r = subprocess.run([sys.executable, str(self.tool), 'run', '--no-upload', '--branch', 'x'], cwd=self.repo, capture_output=True, text=True, env=self.env)
        self.assertEqual(r.returncode, 0, r.stderr)
        refs = subprocess.run(['git', 'ls-remote', str(self.remote)], capture_output=True, text=True).stdout
        self.assertIn('%s\trefs/ci/base/%s' % (c1, head), refs)
        self.assertIn('%s\trefs/heads/ci/x' % head, refs)

    def test_blocked_run_without_jobs_says_quota(self):
        self.gh.write_text('#!/bin/sh\ncase "$2" in list) echo \'[{"databaseId":7,"status":"completed","conclusion":"failure"}]\';; view) echo \'{"jobs":[]}\';; esac\n')
        self.gh.chmod(0o755)
        r = self.wait(timeout=60)
        self.assertEqual(r.returncode, 4, r.stdout)
        self.assertIn('额度用完', r.stdout)

    def stub_gh_with_artifacts(self, shards_in_plan=(1, 2), shards_with_result=(1, 2), failed=(), plan_sha=None):
        """云端 report 任务没起来（运行失败、无 job），但 plan 与各片结果工件都在：gh run download 把它们写到 -D 目录。"""
        plan = {'sha': plan_sha or self.sha, 'branch': 'ci/x', 'mode': 'affected', 'base': 'b', 'scenes': ['a.tscn', 'b.tscn'],
                'shards': [{'shard': n, 'scenes': ['a.tscn']} for n in shards_in_plan]}
        files = {'plan/plan.json': json.dumps(plan)}
        for n in shards_with_result:
            files['result-shard-%d/shard-%d.json' % (n, n)] = json.dumps(
                {'shard': n, 'rc': 1 if n in failed else 0, 'wallSeconds': 60, 'scenes': ['a.tscn'], 'timings': {'a.tscn': 5},
                 'failed': ['a.tscn'] if n in failed else [], 'flaky': []})
        src = Path(self.temp.name) / 'artifacts'
        for rel, text in files.items():
            (src / rel).parent.mkdir(parents=True, exist_ok=True)
            (src / rel).write_text(text)
        self.gh.write_text('#!/bin/sh\ncase "$2" in\n list) echo \'[{"databaseId":9,"status":"completed","conclusion":"failure"}]\';;\n'
                           ' view) echo \'{"jobs":[]}\';;\n download) while [ $# -gt 0 ]; do [ "$1" = -D ] && d=$2; shift; done; cp -R %s/. "$d";;\nesac\n' % src)
        self.gh.chmod(0o755)

    def test_report_computed_locally_when_cloud_report_job_did_not_start(self):
        """今天 run 41167600311：13 片全过，report 任务被 spending limit 挡了没起来，wait 判「没有结果」，合并收尾因此失败。"""
        self.stub_gh_with_artifacts()
        r = self.wait(timeout=60)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('由本机用云端各片的结果工件算出', r.stdout)
        self.assertIn('云端选测通过', r.stdout)

    def test_local_report_failing_shard_fails(self):
        self.stub_gh_with_artifacts(failed=(2,))
        r = self.wait(timeout=60)
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn('失败场景', r.stdout)

    def test_incomplete_artifacts_are_not_a_result(self):
        self.stub_gh_with_artifacts(shards_with_result=(1,))                 # 缺第 2 片
        r = self.wait(timeout=60)
        self.assertEqual(r.returncode, 4, r.stdout)
        self.assertIn('额度用完', r.stdout)
        self.stub_gh_with_artifacts(plan_sha='0' * 40)                       # 工件属于别的提交
        self.assertEqual(self.wait(timeout=60).returncode, 4)

    def test_gh_unavailable_falls_back_to_timeout(self):
        self.gh.write_text('#!/bin/sh\nexit 1\n'); self.gh.chmod(0o755)
        self.assertEqual(self.wait(timeout=2).returncode, 124)


if __name__ == '__main__':
    unittest.main()
