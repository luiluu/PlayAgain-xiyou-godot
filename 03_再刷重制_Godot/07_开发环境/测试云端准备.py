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
        shutil.copy2(HERE / '推送重试.py', env_dir)
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

    def commit_msg(self, name, msg, subdir=None):
        path = self.repo / (subdir or '') / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(name)
        self.git('add', str(path.relative_to(self.repo))); self.git('commit', '-q', '-m', msg)
        return self.git('rev-parse', 'HEAD')

    def test_local_verified_base_chain(self):
        """tools58：带「验证: 选测」尾注、且基准链接得到云端通过提交的收尾提交可当选测基准；链断了、XIYOU_CI_BASE=cloud 退回云端。"""
        mod = self.load_tool()
        c1 = self.sha
        self.publish('affected', sha=c1)
        a = self.commit('a')                                           # 未验的改动
        x1 = self.commit_msg('x1.md', '收尾 1\n\n验证: 选测（基准 %s，当天全量前算选测已验）' % c1[:9], subdir='00_项目管理')
        docs = self.commit_msg('板.md', '交接板', subdir='00_项目管理')    # 只改文档的提交不断链
        x2 = self.commit_msg('x2.md', '收尾 2\n\n验证: 选测（基准 %s，当天全量前算选测已验）' % docs[:9], subdir='00_项目管理')
        broken = self.commit_msg('x3.md', '收尾 3\n\n验证: 选测（基准 %s，当天全量前算选测已验）' % a[:9], subdir='00_项目管理')  # 基准 a 没验过：断链
        self.commit('tip')
        self.git('push', '-q', 'origin', 'HEAD:refs/heads/main')
        url, bare = str(self.remote), mod.cache_repo()
        os.environ.pop('XIYOU_CI_BASE', None)
        self.assertEqual(mod.local_verified_base(url, bare), x2)
        self.assertEqual(mod.verified_base_info(url, bare), (x2, '本机已验的合并'))
        self.assertNotEqual(mod.local_verified_base(url, bare), broken)
        os.environ['XIYOU_CI_BASE'] = 'cloud'
        try:
            self.assertIsNone(mod.local_verified_base(url, bare))
            self.assertEqual(mod.verified_base_info(url, bare), (c1, '上次云端通过的祖先'))
        finally:
            os.environ.pop('XIYOU_CI_BASE')

    def test_local_verified_base_prefers_newer_cloud_result(self):
        mod = self.load_tool()
        c1 = self.sha
        self.publish('affected', sha=c1)
        self.commit_msg('x1.md', '收尾\n\n验证: 选测（基准 %s，x）' % c1[:9], subdir='00_项目管理')
        c3 = self.commit('c3')
        self.commit('tip')
        self.publish('affected', sha=c3)
        os.environ.pop('XIYOU_CI_BASE', None)
        self.assertEqual(mod.verified_base_info(str(self.remote), mod.cache_repo()), (c3, '上次云端通过的祖先'))

    def test_snapshot_parent_makes_push_incremental(self):
        """tools58：快照提交挂在远端当前快照上，只改小文件时推送的包很小；无父提交（XIYOU_CI_PARENT=0）则整份重传。"""
        mod = self.load_tool()
        gen = Path(self.temp.name) / 'gen'
        gen.mkdir()
        (gen / 'big.bin').write_bytes(os.urandom(3_000_000))
        (gen / 'small.json').write_text('1')
        bare, url, ref = mod.cache_repo(), str(self.remote), mod.GEN_PREFIX + 'main'

        def snap(parent):
            tree, _ = mod.snapshot(gen, bare)
            args = ['commit-tree', tree] + (['-p', parent[0]] if parent[0] else [])
            c = mod.git(*args, git_dir=bare, env=mod.BOT, input='snap\n\n%s\n' % json.dumps({'depth': parent[1]}))
            return c

        def pack_size(commit, remote_tip):
            return len(subprocess.run(['git', '--git-dir', str(bare), 'pack-objects', '--revs', '--thin', '--stdout'], capture_output=True,
                                      input=('%s\n^%s\n' % (commit, remote_tip)).encode()).stdout)
        os.environ.pop('XIYOU_CI_PARENT', None)
        first = snap(mod.snapshot_parent(bare, {}, ref))
        self.assertEqual(mod.snapshot_parent(bare, {}, ref), (None, 0))
        mod.git('push', '-q', '--force', url, '%s:%s' % (first, ref), git_dir=bare)
        remote_has = {ref: first}
        (gen / 'small.json').write_text('2')
        self.assertEqual(mod.snapshot_parent(bare, remote_has, 'refs/ci/generated/new-branch'), (first, 1))   # 新分支接 main
        second = snap(mod.snapshot_parent(bare, remote_has, ref))
        self.assertEqual(mod.git('rev-parse', second + '^', git_dir=bare), first)
        self.assertLess(pack_size(second, first), 20_000)
        os.environ['XIYOU_CI_PARENT'] = '0'
        try:
            self.assertEqual(mod.snapshot_parent(bare, remote_has, ref), (None, 0))
            orphan = snap(mod.snapshot_parent(bare, remote_has, ref))
        finally:
            os.environ.pop('XIYOU_CI_PARENT')
        self.assertGreater(pack_size(orphan, first), 2_000_000)
        remote_has = {ref: mod.git('commit-tree', mod.git('rev-parse', first + '^{tree}', git_dir=bare), '-p', first, git_dir=bare, env=mod.BOT,
                                   input='x\n\n{"depth": %d}\n' % (mod.PARENT_MAX - 1))}
        self.assertEqual(mod.snapshot_parent(bare, remote_has, ref), (None, 0))                       # 链满了重起
        self.assertEqual(mod.snapshot_parent(bare, {ref: '1' * 40}, ref), (None, 0))                    # 本地没有远端那个提交

    def test_scenes_result_does_not_verify_a_commit(self):
        """tools60（审查 37 P2-2）：refs/ci/results/<提交>/scenes 只是重跑了几个场景，两个基准函数都不能把它当已验证。"""
        mod = self.load_tool()
        c1 = self.sha
        self.publish('affected', sha=c1)
        a = self.commit('a')
        self.commit('tip')
        self.git('push', '-q', 'origin', 'HEAD:refs/heads/main')
        self.publish('scenes', sha=a)
        url, bare = str(self.remote), mod.cache_repo()
        os.environ.pop('XIYOU_CI_BASE', None)
        self.assertEqual(mod.cloud_passed_base(url, bare), c1)
        self.assertEqual(mod.local_verified_base(url, bare), c1)
        self.assertEqual(mod.verified_base_info(url, bare)[0], c1)
        self.publish('full', sha=a)                                   # full 才算
        self.assertEqual(mod.cloud_passed_base(url, bare), a)

    def test_finish_commit_with_hand_patched_code_falls_back_to_merge_commit(self):
        """tools60（审查 37 P2-3）：收尾提交相对合并提交带了代码（如手补 power.gd）就不当基准，退回合并提交；只改版本／登记／文档照旧认。"""
        mod = self.load_tool()
        c1 = self.sha
        self.publish('affected', sha=c1)
        merge = self.commit_msg('m1', '合并 cc/x')
        patched = self.commit_msg('power.gd', '合并 cc/x（dev.1）收尾\n\n验证: 选测（基准 %s，x）' % c1[:9], subdir='03_再刷重制_Godot/01_Godot工程/modes/xiyou/core')
        self.commit('tip')
        self.git('push', '-q', 'origin', 'HEAD:refs/heads/main')
        url, bare = str(self.remote), mod.cache_repo()
        os.environ.pop('XIYOU_CI_BASE', None)
        self.assertEqual(mod.local_verified_base(url, bare), merge)
        self.assertNotEqual(mod.local_verified_base(url, bare), patched)
        # 只改登记／文档的收尾提交照旧认
        merge2 = self.commit_msg('m2', '合并 cc/y')
        clean = self.commit_msg('变更记录.md', '合并 cc/y（dev.2）收尾\n\n验证: 选测（基准 %s，x）' % merge[:9], subdir='00_项目管理')
        self.commit('tip2')
        self.assertEqual(mod.local_verified_base(url, bare), merge)    # 基准 merge 本身只靠软回退，不接得上云端通过：clean 的链断
        self.assertTrue(mod.release_only(['00_项目管理/变更记录.md', '03_再刷重制_Godot/开发编号.json', 'a.gd.uid']))
        self.assertFalse(mod.release_only(['03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/power.gd']))

    def test_plan_selection_ignores_untracked_files(self):
        """tools60（审查 37 P2-1）：云端 plan 恢复的 .ci-timings 是未跟踪文件，选测必须带 head 只算已提交差异，并忽略该目录。"""
        text = (HERE / '云端选测.py').read_text(encoding='utf-8')
        self.assertIn('selector.select(ROOT, base, head=sha)', text)
        ignore = (HERE.parent.parent / '.gitignore').read_text(encoding='utf-8')
        self.assertIn('.ci-timings/', ignore)

    def load_tool(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('cloud', self.tool)
        mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        return mod

    def test_generated_push_carries_network_tuning_and_can_roll_back(self):
        """tools56：产物快照（约 1.1 GB）推送带 postBuffer／HTTP/1.1／慢速上限；XIYOU_CI_PUSH_TUNING=0 回到 git 默认。"""
        mod = self.load_tool()
        calls = []
        mod.git = lambda *a, **k: calls.append(a)
        os.environ.pop('XIYOU_CI_PUSH_TUNING', None)
        mod.push_generated('url', 'bare', 'abc', 'refs/ci/generated/main')
        args = list(calls[-1])
        self.assertLess(args.index('-c'), args.index('push'))
        for want in ('http.postBuffer=2147483648', 'http.version=HTTP/1.1', 'http.lowSpeedLimit=1000', 'http.lowSpeedTime=600'):
            self.assertIn(want, args)
        self.assertIn('abc:refs/ci/generated/main', args)
        os.environ['XIYOU_CI_PUSH_TUNING'] = '0'
        try:
            mod.push_generated('url', 'bare', 'abc', 'refs/ci/generated/main')
        finally:
            os.environ.pop('XIYOU_CI_PUSH_TUNING')
        self.assertEqual(calls[-1][0], 'push')
        self.assertNotIn('-c', calls[-1])

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

    def test_billing_block_is_named_not_quota_or_code(self):
        """10-31 run 41251532841：plan 任务在、结论 failure、没有步骤，注解是付款失败／花费上限。认成账单问题，退出码 5。"""
        note = "X The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings"
        self.gh.write_text('#!/bin/sh\ncase "$2" in list) echo \'[{"databaseId":7,"status":"completed","conclusion":"failure"}]\';;\n'
                           ' view) if [ "$4" = --json ]; then echo \'{"jobs":[{"name":"plan","conclusion":"failure","steps":[]}]}\'; '
                           'else printf "ANNOTATIONS\\n%%s\\nplan: .github#1\\n" "%s"; fi;;\n download) exit 1;;\nesac\n' % note.replace('"', '\\"'))
        self.gh.chmod(0o755)
        r = self.wait(timeout=60)
        self.assertEqual(r.returncode, 5, r.stdout + r.stderr)
        self.assertIn('账单问题，不是代码问题', r.stdout)
        self.assertIn('spending limit', r.stdout)
        self.assertIn('Billing & plans', r.stdout)

    def test_billing_note_on_report_only_still_uses_shard_results(self):
        """只有 report 被账单挡、各片都跑完：照旧本机算结果，不报账单失败。"""
        self.stub_gh_with_artifacts()
        script = self.gh.read_text().replace(" view) echo '{\"jobs\":[]}';;", " view) echo 'X recent account payments have failed';;")
        self.assertIn('payments have failed', script)
        self.gh.write_text(script)
        r = self.wait(timeout=60)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('由本机用云端各片的结果工件算出', r.stdout)

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
