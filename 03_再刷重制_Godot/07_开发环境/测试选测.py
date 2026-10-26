#!/usr/bin/env python3
"""选测.py 与 检查.sh --affected 的回归：所有 Git 写入都在一次性临时资料库里。

检查.sh 用真实脚本，被它调用的 Godot、各工具回归与守卫都换成只记一行名字的替身，核对选了什么、跑了什么；
不加 --affected 时全部照跑（默认行为不变）。"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('selector', HERE / '选测.py')
sel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sel)

SUB = Path('03_再刷重制_Godot')
PROJECT = SUB / '01_Godot工程'
TESTS = PROJECT / 'tests'
ENV = SUB / '07_开发环境'
TOOLS = SUB / '03_转换工具'
CORE = PROJECT / 'modes/xiyou/core'
UI = PROJECT / 'modes/xiyou/ui'


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xiyou_select_fixture_')
        self.root = Path(self.tmp.name).resolve()
        self.env = {**os.environ, 'GIT_AUTHOR_NAME': 'fixture', 'GIT_AUTHOR_EMAIL': 'f@example.invalid',
                    'GIT_COMMITTER_NAME': 'fixture', 'GIT_COMMITTER_EMAIL': 'f@example.invalid'}
        self.g('init', '-b', 'main')
        self.put(CORE / 'orbs.gd', 'class_name XOrbs\n')
        self.put(CORE / 'battler.gd', 'class_name XBattler\n')
        self.put(CORE / 'lonely.gd', 'class_name XLonely\n')
        self.put(UI / 'shop.gd', 'class_name XShopScene\n')
        self.put(UI / 'nobody.gd', 'class_name XNobody\n')
        self.put(PROJECT / 'modes/xiyou/map/interp.gd', 'class_name XInterp\n')
        self.put(PROJECT / 'project.godot', 'config/name="x"\nconfig/version="dev.001"\n')
        self.put(PROJECT / 'content/build_info.json', '{\n  "developmentVersion": "dev.001",\n  "kind": "slice"\n}\n')
        self.put(TOOLS / 'mv_oracle/orb_probe.cjs', '// probe\n')
        self.put(TOOLS / 'xiyou_slice.json', '{}\n')
        for name, body in {'xiyou_orbs': 'XOrbs.new() # orb_probe.cjs', 'xiyou_shop': 'XShopScene.new()',
                           'xiyou_event_compare': 'compare', 'ui_smoke': 'smoke', 'xiyou_floor_a': 'XInterp',
                           'xiyou_battle': 'XBattler.new()\nconst F = "res://tests/fixtures/battle_oracle.json"',
                           'xiyou_rules': 'XBattler'}.items():
            self.scene(name, body)
        for part in ['d1b', 'd2']:
            self.put(TESTS / ('xiyou_rules_%s.tscn' % part), '[ext_resource path="res://tests/xiyou_rules.gd" id="1"]\n')
        self.put(TESTS / 'helper.gd', 'class_name THelper\n')
        self.put(TESTS / 'xiyou_shop.gd', 'const H = preload("res://tests/helper.gd")\nXShopScene.new()\n')
        self.put(TESTS / 'fixtures/battle_oracle.json', '{}\n')
        self.put(Path('00_项目管理/交接板.md'), '# board\n')
        self.commit('base')
        self.base = self.g('rev-parse', 'HEAD')

    def tearDown(self):
        self.tmp.cleanup()

    def g(self, *args):
        return subprocess.run(['git', '-C', str(self.root), *args], capture_output=True, text=True, check=True,
                              env=self.env).stdout.strip()

    def put(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def scene(self, name, body):
        self.put(TESTS / (name + '.gd'), 'extends Node\n' + body + '\n')
        self.put(TESTS / (name + '.tscn'), '[ext_resource path="res://tests/%s.gd" id="1"]\n' % name)

    def commit(self, msg):
        self.g('add', '-A'); self.g('commit', '-q', '-m', msg)

    def pick(self, head=None):
        return sel.select(self.root, self.base, head=head)


class SelectTests(Fixture):
    def test_docs_only(self):
        self.put(Path('00_项目管理/交接板.md'), '# board 2\n')
        self.put(SUB / '00_设计/新文档.md', 'new\n')  # 未跟踪也算改动
        s = self.pick()
        self.assertFalse(s['full'])
        self.assertEqual((s['scenes'], s['checks']), ([], []))
        self.assertEqual(len(s['files']), 2)

    def test_ui_uses_class_refs_and_event_compare(self):
        self.put(UI / 'shop.gd', 'class_name XShopScene\n# changed\n')
        self.put(UI / 'shop.gd.uid', 'uid://x\n')
        s = self.pick()
        self.assertEqual(s['scenes'], ['xiyou_event_compare.tscn', 'xiyou_shop.tscn'])
        self.assertEqual(s['checks'], ['guards'])
        self.assertEqual(len(s['reasons']), 1)  # .uid 跟源文件同组，不重复列

    def test_ui_without_refs_falls_back_to_smoke(self):
        self.put(UI / 'nobody.gd', 'class_name XNobody\n# changed\n')
        self.assertEqual(self.pick()['scenes'], ['ui_smoke.tscn', 'xiyou_event_compare.tscn'])

    def test_battle_core_runs_all_rules_parts(self):
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# changed\n')
        s = self.pick()
        self.assertEqual(s['scenes'], ['xiyou_battle.tscn', 'xiyou_event_compare.tscn', 'xiyou_rules.tscn',
                                       'xiyou_rules_d1b.tscn', 'xiyou_rules_d2.tscn'])
        self.assertEqual(s['checks'], ['content', 'guards', 'same_source'])

    def test_probe_and_slice_add_tools_and_probe_users(self):
        self.put(TOOLS / 'mv_oracle/orb_probe.cjs', '// probe 2\n')
        s = self.pick()
        self.assertIn('xiyou_orbs.tscn', s['scenes'])
        self.assertIn('xiyou_rules_d2.tscn', s['scenes'])
        self.assertEqual(s['checks'], ['content', 'guards', 'same_source', 'tools'])

    def test_map_runs_floors(self):
        self.put(PROJECT / 'modes/xiyou/map/interp.gd', 'class_name XInterp\n# 2\n')
        self.assertEqual(self.pick()['scenes'], ['xiyou_event_compare.tscn', 'xiyou_floor_a.tscn'])

    def test_other_core_module_runs_users(self):
        self.put(CORE / 'orbs.gd', 'class_name XOrbs\n# 2\n')
        self.assertEqual(self.pick()['scenes'], ['xiyou_event_compare.tscn', 'xiyou_orbs.tscn'])

    def test_changed_test_runs_itself_and_helper_runs_its_users(self):
        self.put(TESTS / 'xiyou_orbs.gd', 'extends Node\nXOrbs # 2\n')
        self.assertEqual(self.pick()['scenes'], ['xiyou_orbs.tscn'])
        self.g('checkout', '--', '.')
        self.put(TESTS / 'helper.gd', 'class_name THelper\n# 2\n')
        self.assertEqual(self.pick()['scenes'], ['xiyou_shop.tscn'])
        self.g('checkout', '--', '.')
        self.put(TESTS / 'xiyou_rules.gd', 'extends Node\nXBattler # 2\n')
        self.assertEqual(self.pick()['scenes'], ['xiyou_rules.tscn', 'xiyou_rules_d1b.tscn', 'xiyou_rules_d2.tscn'])

    def test_fixture_runs_its_users_and_orphan_fixture_is_full(self):
        self.put(TESTS / 'fixtures/battle_oracle.json', '{"a": 1}\n')
        self.assertEqual(self.pick()['scenes'], ['xiyou_battle.tscn'])
        self.put(TESTS / 'fixtures/orphan.json', '{}\n')
        self.assertTrue(self.pick()['full'])

    def test_deleted_test_and_fixture_need_nothing(self):
        for rel in ['xiyou_orbs.gd', 'xiyou_orbs.tscn']:
            (self.root / TESTS / rel).unlink()
        s = self.pick()
        self.assertFalse(s['full'])
        self.assertEqual(s['scenes'], [])
        (self.root / TESTS / 'fixtures/battle_oracle.json').unlink()
        self.assertEqual(self.pick()['scenes'], ['xiyou_battle.tscn'])  # 还有测试引用它：照跑（会暴露缺夹具）

    def test_version_bump_is_registry_but_other_project_edit_is_full(self):
        self.put(PROJECT / 'project.godot', 'config/name="x"\nconfig/version="dev.002"\n')
        self.put(PROJECT / 'content/build_info.json', '{\n  "developmentVersion": "dev.002",\n  "kind": "slice"\n}\n')
        s = self.pick()
        self.assertFalse(s['full'])
        self.assertEqual(s['scenes'], [])
        self.put(PROJECT / 'project.godot', 'config/name="y"\nconfig/version="dev.002"\n')
        self.assertTrue(self.pick()['full'])

    def test_selecting_every_scene_becomes_full(self):
        self.put(PROJECT / 'modes/xiyou/core/xstate.gd', 'class_name XState\n')
        self.commit('xstate')
        self.base = self.g('rev-parse', 'HEAD')
        for name in sel.Tests(self.root).scenes:
            p = self.root / TESTS / name.replace('.tscn', '.gd')
            if p.exists():
                p.write_text(p.read_text() + 'XState\n')
        self.commit('everyone uses XState')
        self.base = self.g('rev-parse', 'HEAD')
        self.put(PROJECT / 'modes/xiyou/core/xstate.gd', 'class_name XState\n# 2\n')
        self.assertTrue(self.pick()['full'])

    def test_unknown_path_is_full(self):
        self.put(PROJECT / 'icon.svg', '<svg/>\n')
        self.assertTrue(self.pick()['full'])

    def test_mode_data_runs_tests_and_loader_users(self):
        self.put(PROJECT / 'modes/xiyou/alienation.json', '{}\n')
        self.put(PROJECT / 'modes/xiyou/recipes.json', '{}\n')
        self.put(PROJECT / 'modes/xiyou/lonely.json', '{}\n')
        self.put(CORE / 'crafting.gd', 'class_name XCrafting\nvar d = XDB.load_json("recipes.json")\n')
        self.put(PROJECT / 'modes/xiyou/generated/stale.gd', 'class_name XStale\nvar d = "lonely.json"\n')
        self.scene('xiyou_alien_config', 'const F := "alienation.json"')
        self.scene('xiyou_craft', 'XCrafting.new()')
        self.scene('xiyou_stale', 'XStale.new()')
        self.commit('mode data')
        self.base = self.g('rev-parse', 'HEAD')
        self.put(PROJECT / 'modes/xiyou/alienation.json', '{"a": 1}\n')
        s = self.pick()
        self.assertEqual((s['full'], s['scenes'], s['checks']),
                         (False, ['xiyou_alien_config.tscn', 'xiyou_event_compare.tscn'], ['guards']))
        self.g('checkout', '--', '.')
        self.put(PROJECT / 'modes/xiyou/recipes.json', '{"a": 1}\n')  # 测试只引用加载它的 XCrafting
        self.assertEqual(self.pick()['scenes'], ['xiyou_craft.tscn', 'xiyou_event_compare.tscn'])
        self.g('checkout', '--', '.')
        self.put(PROJECT / 'modes/xiyou/lonely.json', '{"a": 1}\n')  # 只有 generated 下的脚本提到它：不算，整轮
        self.assertTrue(self.pick()['full'])
        self.g('checkout', '--', '.')
        self.commit('noop') if self.g('status', '--porcelain') else None
        self.put(PROJECT / 'modes/xiyou/recipes.json', '{"b": 1}\n')
        self.commit('recipes')
        self.assertEqual(self.pick(head=self.g('rev-parse', 'HEAD'))['scenes'], ['xiyou_craft.tscn', 'xiyou_event_compare.tscn'])

    def test_deleted_module_reads_class_name_from_base(self):
        (self.root / CORE / 'orbs.gd').unlink()
        self.assertIn('xiyou_orbs.tscn', self.pick()['scenes'])

    def test_head_option_ignores_worktree(self):
        self.put(CORE / 'orbs.gd', 'class_name XOrbs\n# 2\n')
        self.commit('orbs')
        head = self.g('rev-parse', 'HEAD')
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# uncommitted\n')
        s = self.pick(head=head)
        self.assertEqual(s['files'], [str(CORE / 'orbs.gd')])

    def test_bad_base_and_bad_table(self):
        with self.assertRaises(RuntimeError):
            sel.select(self.root, 'no-such-commit')
        bad = self.root / 'bad.json'
        bad.write_text(json.dumps({'groups': {'docs': {}}, 'rules': [{'match': '*.md', 'group': 'docs'}]}))
        with self.assertRaises(ValueError):
            sel.select(self.root, self.base, table=bad)
        bad.write_text(json.dumps({'groups': {'x': {'checks': ['nope']}}, 'rules': [{'match': '*', 'group': 'x'}]}))
        with self.assertRaises(ValueError):
            sel.select(self.root, self.base, table=bad)

    def test_real_table_is_valid(self):
        groups, rules = sel.load_table()
        self.assertEqual(rules[-1]['group'], 'full')
        self.assertEqual(sel.classify('03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/damage.gd', rules), 'battle')
        self.assertEqual(sel.classify('03_再刷重制_Godot/04_验证/测量接受/x.json', rules), 'converter')
        self.assertEqual(sel.classify('02_内容与素材/x.png', rules), 'full')


STUB_CHECKS = ['测试工作树清理.py', '测试导出过滤.py', '测试共性验收.py', '测试合并工具.py', '测试公式程序.py', '测试转换器写入.py',
               '测试记录工具.py', '测试云端准备.py', '测试内容覆盖.py', '测试角色同步提速.py', '测试事件探针分段.py', '测试状态js翻译.py', '测试选测.py', '变更记录分卷.py', '待核查.py']


class CheckerTests(Fixture):
    """真实 检查.sh＋替身：每个被调用的脚本往 calls 里记一行名字。"""
    def setUp(self):
        super().setUp()
        self.calls = self.root / 'calls'
        env = self.root / ENV
        env.mkdir(parents=True, exist_ok=True)
        for name in ['检查.sh', '选测.py', '选测对照.json']:
            shutil.copy2(HERE / name, env / name)
        record = 'import sys, pathlib\nwith open(%r, "a") as f: f.write(pathlib.Path(sys.argv[0]).name + " " + " ".join(sys.argv[1:]) + "\\n")\n' % str(self.calls)
        for name in STUB_CHECKS + ['并行测试.py']:
            self.put(ENV / name, record)
        # 占槽.py 替身：直接跑 -- 后面的命令（真的占槽要用真的 并行测试.py）
        self.put(ENV / '占槽.py', 'import subprocess, sys\nsys.exit(subprocess.run(sys.argv[sys.argv.index("--") + 1:]).returncode)\n')
        for rel in ['共性参照验收.py', '内容覆盖检查.py', '验证西游来源.py', 'ui_reference/guard_check.py']:
            self.put(TOOLS / rel, record)
        self.put(TOOLS / 'mv_oracle/guard_check.cjs', 'require("fs").appendFileSync(%r, "guard_check.cjs\\n")\n' % str(self.calls))
        self.put(TOOLS / 'mv_oracle/boot_check.cjs', 'require("fs").appendFileSync(%r, "boot_check.cjs\\n");'
                 'console.log(JSON.stringify({db: true, modulesFailed: [], errors: []}))\n' % str(self.calls))
        (self.root / TOOLS / 'mv_oracle/node_modules').mkdir()
        godot = self.root / 'fake_godot'
        godot.write_text('#!/bin/zsh\necho godot >> %s\n' % self.calls); godot.chmod(0o755)
        self.godot = godot
        self.put(SUB / '开发编号.json', json.dumps({'current': 'dev.001'}))
        self.put(Path('00_项目管理/当前状态.json'), json.dumps({'godot': {'developmentVersion': 'dev.001'}}))
        self.put(Path('00_项目管理/来源登记.json'), json.dumps({'sources': [{'id': 'new_godot_remake', 'developmentVersion': 'dev.001'}]}))
        self.commit('checker fixture')
        self.base = self.g('rev-parse', 'HEAD')

    def check(self, *args):
        env = dict(self.env, XIYOU_LONG_TASK_MANAGED='1', GODOT=str(self.godot))
        p = subprocess.run(['zsh', str(self.root / ENV / '检查.sh'), *args], capture_output=True, text=True, env=env)
        ran = self.calls.read_text().splitlines() if self.calls.exists() else []
        self.calls.unlink(missing_ok=True)
        return p.returncode, p.stdout + p.stderr, ran

    def names(self, ran):
        return sorted({line.split()[0] for line in ran})

    def test_default_runs_everything(self):
        rc, out, ran = self.check('--oracle')
        self.assertEqual(rc, 0, out)
        self.assertIn('全部通过', out)
        self.assertEqual(self.names(ran), sorted(set(STUB_CHECKS + ['并行测试.py', 'godot', '共性参照验收.py', '内容覆盖检查.py',
                                                                   '验证西游来源.py', 'guard_check.py', 'guard_check.cjs', 'boot_check.cjs'])))
        self.assertEqual(next(l for l in ran if l.startswith('并行测试.py')).split()[1:], [str(self.godot), str(self.root / PROJECT)])

    def test_docs_only_skips_godot_and_tools(self):
        self.put(Path('00_项目管理/交接板.md'), '# board 2\n')
        rc, out, ran = self.check('--oracle', '--affected', self.base)
        self.assertEqual(rc, 0, out)
        self.assertIn('== 选测', out)
        self.assertIn('跳过导入与测试', out)
        self.assertIn('选测全部通过', out)
        self.assertEqual(self.names(ran), ['boot_check.cjs', '变更记录分卷.py', '待核查.py'])

    def test_ui_change_runs_selected_scenes_only(self):
        self.put(UI / 'shop.gd', 'class_name XShopScene\n# 2\n')
        rc, out, ran = self.check('--affected', self.base)
        self.assertEqual(rc, 0, out)
        runner = next(l for l in ran if l.startswith('并行测试.py')).split()
        self.assertEqual(runner[3:], ['xiyou_event_compare.tscn', 'xiyou_shop.tscn'])
        self.assertIn('guard_check.cjs', self.names(ran))
        self.assertNotIn('测试合并工具.py', self.names(ran))

    def test_battle_without_oracle_warns_same_source(self):
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# 2\n')
        rc, out, ran = self.check('--affected', self.base)
        self.assertEqual(rc, 0, out)
        self.assertIn('没加 --oracle', out)
        self.assertIn('内容覆盖检查.py', self.names(ran))
        self.assertNotIn('验证西游来源.py', self.names(ran))
        rc, out, ran = self.check('--oracle', '--affected', self.base)
        self.assertIn('验证西游来源.py', self.names(ran))

    def test_unknown_change_is_full(self):
        # 没有测试与加载者的手写数据：整轮，且它带出的事件对照不能把整轮缩成只跑选中的场景
        self.put(PROJECT / 'modes/xiyou/recipes.json', '{}\n')
        rc, out, ran = self.check('--affected', self.base)
        self.assertEqual(rc, 0, out)
        self.assertIn('整轮', out)
        self.assertIn('测试合并工具.py', self.names(ran))
        self.assertEqual(len(next(l for l in ran if l.startswith('并行测试.py')).split()), 3)
        self.assertIn('全部通过', out)

    def test_rules_filter_env_is_refused(self):
        self.env['RULES_ONLY_TROOPS'] = '833'
        rc, out, ran = self.check()
        self.assertEqual(rc, 2)
        self.assertEqual(ran, [])

    def test_bad_arguments(self):
        self.assertEqual(self.check('--affected')[0], 2)
        rc, out, ran = self.check('--affected', 'no-such-commit')
        self.assertEqual(rc, 2)
        self.assertEqual(ran, [])


if __name__ == '__main__':
    result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
