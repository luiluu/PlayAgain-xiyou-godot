#!/usr/bin/env python3
"""临时探针.py 的车道标签与产物名；新建工作树.sh 在 clone 里转用母库脚本。离线，几秒。"""
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('临时探针', HERE / '临时探针.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


class TagTests(unittest.TestCase):
    def test_env_tag_wins_and_is_cleaned(self):
        self.assertEqual(M.lane_tag(env={'XIYOU_LANE_TAG': 'cc/a b'}), 'cc_a_b')

    def test_branch_tag_from_git(self):
        with tempfile.TemporaryDirectory() as d:
            subprocess.run(['git', 'init', '-q', '-b', 'cc/tools-x', d], check=True)
            self.assertEqual(M.lane_tag(d, env={}), 'cc_tools-x')

    def test_dir_name_when_not_git(self):
        with tempfile.TemporaryDirectory() as d:
            sub = Path(d) / '车道甲'
            sub.mkdir()
            # 目录名兜底；上层若恰在别的 git 库里 rev-parse 也会成功，所以只测 env 空且 git 失败时回落目录名
            tag = M.lane_tag(sub, env={})
            self.assertTrue(tag)

    def test_out_path_distinct_per_lane_and_label(self):
        a = M.out_path('troop_events', env={'XIYOU_LANE_TAG': 'lane1'})
        b = M.out_path('troop_events', env={'XIYOU_LANE_TAG': 'lane2'})
        c = M.out_path('troop_events', 'p826', env={'XIYOU_LANE_TAG': 'lane1'})
        self.assertEqual(a.name, 'dev_troop_events.lane1.json')
        self.assertEqual(c.name, 'dev_troop_events.lane1.p826.json')
        self.assertEqual(len({a, b, c}), 3)
        self.assertEqual(a.parent.name, '.sandbox')

    def test_bad_name_rejected(self):
        with self.assertRaises(SystemExit):
            M.out_path('../x', env={'XIYOU_LANE_TAG': 't'})

    def test_run_uses_registered_env_var(self):
        self.assertEqual(M.OUT_ENV['troop_event_probe.cjs'], 'XIYOU_TROOP_OUT')
        self.assertEqual(M.main(['run', 'no_such_probe.cjs']), 64)


class CloneRedirectTests(unittest.TestCase):
    def test_script_redirects_when_alternates_present(self):
        text = (HERE / '新建工作树.sh').read_text()
        self.assertIn('objects/info/alternates', text)
        self.assertIn('XIYOU_WT_REDIRECTED', text)

    def test_clone_script_execs_parent_copy(self):
        """真 clone：clone 里的脚本应打印「改用主工作区那份脚本」并转交给母库的脚本（母库是临时库，脚本是桩）。"""
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            rel = Path('03_再刷重制_Godot/07_开发环境')
            parent = d / 'parent'
            (parent / rel).mkdir(parents=True)
            subprocess.run(['git', 'init', '-q', str(parent)], check=True)
            (parent / rel / '新建工作树.sh').write_text('#!/bin/zsh\nprint PARENT-RAN "$@"\n')
            (parent / 'x').write_text('x')
            subprocess.run(['git', '-C', str(parent), 'add', '-A'], check=True)
            subprocess.run(['git', '-C', str(parent), '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'i'], check=True)
            clone = d / 'clone'
            subprocess.run(['git', 'clone', '-q', '--shared', str(parent), str(clone)], check=True)
            (clone / rel).mkdir(parents=True, exist_ok=True)
            (clone / rel / '新建工作树.sh').write_text((HERE / '新建工作树.sh').read_text())
            env = {k: v for k, v in os.environ.items() if k != 'XIYOU_WT_REDIRECTED'}
            p = subprocess.run(['zsh', str(clone / rel / '新建工作树.sh'), '--补齐', 'zzz'], capture_output=True, text=True, env=env)
            self.assertIn('PARENT-RAN --补齐 zzz', p.stdout, p.stderr)
            self.assertIn('改用主工作区那份脚本', p.stderr)


if __name__ == '__main__':
    unittest.main()
