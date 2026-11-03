#!/usr/bin/env python3
"""选测.py 与 检查.sh --affected 的回归：所有 Git 写入都在一次性临时资料库里。

检查.sh 用真实脚本，被它调用的 Godot、各工具回归与守卫都换成只记一行名字的替身，核对选了什么、跑了什么；
不加 --affected 时全部照跑（默认行为不变）。"""
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

# 合并工具 --cloud 收尾不需重传产物时给 检查.sh 设 CHECK_CLOUD_NO_UPLOAD=1，会漏进这里的子进程与 cloud_env，用例按默认环境跑

os.environ.pop('CHECK_CLOUD_NO_UPLOAD', None)
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
    def test_list_prints_scene_names_one_per_line(self):
        """tools35：--list 供车道手写选测前对照：标准输出只有场景名（不带 .tscn），理由走标准错误。"""
        import contextlib, io
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# changed\n')
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = sel.main([self.base, '--root', str(self.root), '--list'])
        self.assertEqual(rc, 0)
        names = out.getvalue().split()
        self.assertIn('xiyou_battle', names)
        self.assertTrue(all(not n.endswith('.tscn') for n in names))
        self.assertIn('== 选测', err.getvalue())

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

    def test_fixture_only_used_by_tool_runs_tools_not_full(self):
        # 2026-10-26 本批：tests/fixtures/state_js_translation.json 只被 07_开发环境/测试状态js翻译.py 读，原来整轮
        self.put(ENV / '测试工具夹具.py', "F = 'tests/fixtures/tool_only.json'\n")
        self.put(TESTS / 'fixtures/tool_only.json', '{}\n')
        self.commit('tool fixture')
        self.base = self.g('rev-parse', 'HEAD')
        self.put(TESTS / 'fixtures/tool_only.json', '{"a": 1}\n')
        s = self.pick()
        self.assertFalse(s['full'])
        self.assertEqual((s['scenes'], s['checks']), ([], ['guards', 'tools']))
        self.put(TESTS / 'fixtures/orphan.json', '{}\n')  # 谁也不用：仍整轮
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

    def test_xstate_field_and_save_key_only_runs_save_tests(self):
        # 人人引用 XState：只加字段＋存读档键时只跑存档类专项＋事件对照，改别的行照旧按引用（game 组）
        body = ('class_name XState\nvar gold := 0\n\nfunc to_dict() -> Dictionary:\n\treturn {"gold": gold,\n'
                '\t\t"items": 1}\n\nstatic func from_dict(d: Dictionary) -> XState:\n\tvar s := XState.new()\n'
                '\ts.gold = int(d.gold)\n\treturn s\n')
        self.put(CORE / 'xstate.gd', body)
        self.scene('xiyou_save_page', 'XState.new()')
        self.scene('xiyou_difficulty_inherit_load', 'load')
        self.scene('xiyou_flow', 'XState.new()')
        self.commit('xstate')
        self.base = self.g('rev-parse', 'HEAD')
        self.put(CORE / 'xstate.gd', body.replace('var gold := 0\n', 'var gold := 0\n## 新字段\nvar pets := {}\n')
                 .replace('\t\t"items": 1}', '\t\t"items": 1, "pets": pets}')
                 .replace('\ts.gold = int(d.gold)\n', '\ts.gold = int(d.gold)\n\ts.pets = d.get("pets", {})\n'))
        s = self.pick()
        self.assertEqual(s['scenes'], ['xiyou_difficulty_inherit_load.tscn', 'xiyou_event_compare.tscn', 'xiyou_save_page.tscn'])
        self.assertFalse(s['full'])
        self.put(CORE / 'xstate.gd', body.replace('\treturn s\n', '\ts.gold += 1\n\treturn s\n'))
        s = self.pick()
        self.assertIn('xiyou_flow.tscn', s['scenes'])
        self.assertIn('按 game', s['reasons'][0][1])

    def test_xstate_actor_row_save_lines_stay_in_save_tests(self):
        # 角色行里加存档键（a[str(id)]["k"] = …）、XFoo.to_save／from_save 一行也算存读档写法（哪吒_41，来自 bajie-ui-gaps1 的可优化）
        body = ('class_name XState\nfunc to_dict() -> Dictionary:\n\tfor id in actors:\n\t\tvar x2 = actors[id]\n\t\ta[str(id)] = {}\n'
                '\treturn a\n\nstatic func from_dict(d: Dictionary) -> XState:\n\tvar s := XState.new()\n\tfor row in d.actors:\n\t\tvar x2 = XActor.new()\n'
                '\treturn s\n')
        self.put(CORE / 'xstate.gd', body)
        self.scene('xiyou_save_page', 'XState.new()')
        self.scene('xiyou_flow', 'XState.new()')
        self.commit('xstate')
        self.base = self.g('rev-parse', 'HEAD')
        new_body = (body.replace('\t\ta[str(id)] = {}\n', '\t\ta[str(id)] = {}\n\t\t# 技能熟练度\n'
                                 '\t\tif not x2.mastery_levels.is_empty() or not x2.mastery_uses.is_empty():\n'
                                 '\t\t\tvar m := XSkillMastery.to_save(x2)\n\t\t\ta[str(id)]["masteryLevels"] = m[0]\n')
                    .replace('\t\tvar x2 = XActor.new()\n', '\t\tvar x2 = XActor.new()\n\t\tXSkillMastery.from_save(x2, row.get("masteryLevels", {}), row.get("masteryUses", {}))\n'))
        self.put(CORE / 'xstate.gd', new_body)
        s = self.pick()
        self.assertFalse(s['full'])
        self.assertNotIn('xiyou_flow.tscn', s['scenes'])
        self.assertIn('xiyou_save_page.tscn', s['scenes'])
        # 同一位置塞进别的逻辑（赋值之外的 if／调用）仍退回 game 组
        self.put(CORE / 'xstate.gd', body.replace('\t\ta[str(id)] = {}\n', '\t\ta[str(id)] = {}\n\t\tif x2.hp > 0:\n\t\t\tx2.hp = 0\n'))
        self.assertIn('xiyou_flow.tscn', self.pick()['scenes'])

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
        # 改函数体（不是只加字段／注释，否则走 xstate_fields 细分）
        self.put(PROJECT / 'modes/xiyou/core/xstate.gd', 'class_name XState\nfunc f():\n\tpass\n')
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

    def test_head_option_reads_tests_at_head(self):
        # 回放：head 里新增的测试场景要能找到（工作区还没有它），不能因为找不到用它的测试判整轮
        self.scene('xiyou_new', 'XLonely.new()')
        self.commit('new test')
        head = self.g('rev-parse', 'HEAD')
        self.g('checkout', '-q', self.base)
        s = self.pick(head=head)
        self.assertFalse(s['full'])
        self.assertEqual(s['scenes'], ['xiyou_new.tscn'])

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
        sections, merge_base = sel.load_options()
        self.assertTrue(sections['enabled'] and merge_base)
        self.assertEqual(sections['file'], str(TOOLS / 'xiyou_slice.json'))


SLICE = TOOLS / 'xiyou_slice.json'
RULES = ['xiyou_rules.tscn', 'xiyou_rules_d1b.tscn', 'xiyou_rules_d2.tscn']


class SliceFixture(Fixture):
    def setUp(self):
        super().setUp()
        self.slice = {'说明': 'x', 'maps': [1, 2], 'keepEvents': {'1': '*'}, 'troops': [5], 'actors': [1], 'extraImages': ['system/a']}
        self.put(SLICE, json.dumps(self.slice, indent=2) + '\n')
        self.scene('xiyou_lobby_shops', 'var k = XMapScene.slice().get("keepEvents", {})')
        self.scene('xiyou_panels', 'panels')
        self.commit('slice')
        self.base = self.g('rev-parse', 'HEAD')

    def edit(self, **changes):
        self.put(SLICE, json.dumps({**self.slice, **changes}, indent=2) + '\n')


class SliceSectionTests(SliceFixture):
    """xiyou_slice.json 按顶层键细分（用户 2026-10-26）。"""

    def test_maps_only_runs_event_compare_and_floors(self):
        self.edit(maps=[1, 2, 69], keepEvents={'1': '*', '69': '*'})
        s = self.pick()
        self.assertFalse(s['full'])
        self.assertEqual(s['scenes'], ['xiyou_event_compare.tscn', 'xiyou_floor_a.tscn', 'xiyou_lobby_shops.tscn'])
        self.assertEqual(s['checks'], ['content', 'guards', 'tools'])
        self.assertIn('keepEvents、maps', s['reasons'][0][1])

    def test_troops_only_runs_rules(self):
        self.edit(troops=[5, 6])
        s = self.pick()
        self.assertEqual(s['scenes'], ['xiyou_event_compare.tscn'] + RULES)
        self.assertEqual(s['checks'], ['content', 'guards', 'same_source', 'tools'])

    def test_maps_and_troops_take_the_union(self):
        self.edit(maps=[1, 2, 69], troops=[5, 6])
        s = self.pick()
        self.assertEqual(s['scenes'], ['xiyou_event_compare.tscn', 'xiyou_floor_a.tscn'] + RULES)
        self.assertEqual(s['checks'], ['content', 'guards', 'same_source', 'tools'])
        self.assertEqual(len(s['reasons']), 2)

    def test_images_only_runs_ui(self):
        self.edit(extraImages=['system/a', 'system/b'])
        s = self.pick()
        self.assertEqual(s['scenes'], ['ui_smoke.tscn', 'xiyou_event_compare.tscn', 'xiyou_panels.tscn'])
        self.assertEqual(s['checks'], ['guards', 'tools'])

    def test_sv_folders_is_asset_key_not_converter(self):
        """tools37：extraSvFolders（导出时拷的 SV 战斗图文件夹）原来不在键表里，一改就退回整组 converter（rules 全部段）；现归图像组。"""
        self.edit(extraSvFolders=['UserSV_A'])
        s = self.pick()
        self.assertEqual(s['scenes'], ['ui_smoke.tscn', 'xiyou_event_compare.tscn', 'xiyou_panels.tscn'])
        self.assertFalse(set(RULES) & set(s['scenes']))

    def test_bad_json_and_unknown_key_fall_back_to_converter(self):
        self.put(SLICE, '{"maps": [1, 2, 69],\n')
        s = self.pick()
        self.assertTrue(set(RULES) <= set(s['scenes']))
        self.assertIn('新版 JSON 解析失败', s['reasons'][0][1])
        self.edit(newKey=1)
        s = self.pick()
        self.assertTrue(set(RULES) <= set(s['scenes']))
        self.assertIn('未知键 newKey', s['reasons'][0][1])
        (self.root / SLICE).unlink()
        self.assertIn('切片文件被删除', self.pick()['reasons'][0][1])

    def test_format_only_selects_nothing(self):
        self.put(SLICE, json.dumps(self.slice) + '\n')
        s = self.pick()
        self.assertEqual((s['full'], s['scenes'], s['checks']), (False, [], []))

    def test_switch_off_restores_whole_converter(self):
        table = json.loads((HERE / '选测对照.json').read_text())
        table['sliceSections']['enabled'] = False
        off = self.root / 'off.json'
        off.write_text(json.dumps(table))
        self.edit(maps=[1, 2, 69])
        s = sel.select(self.root, self.base, table=off)
        self.assertTrue(set(RULES) <= set(s['scenes']))
        self.assertEqual(s['reasons'][0][1], 'converter')

    def test_head_replay(self):
        self.edit(maps=[1, 2, 69])
        self.commit('maps')
        s = self.pick(head=self.g('rev-parse', 'HEAD'))
        self.assertEqual(s['scenes'], ['xiyou_event_compare.tscn', 'xiyou_floor_a.tscn'])


class FloorNarrowTests(SliceFixture):
    """切片 maps／keepEvents 改动时楼层专项按图号收窄（哪吒_3，2026-10-26）。"""
    def setUp(self):
        super().setUp()
        self.scene('xiyou_floor_reach069', '## 通天之上（Map069）\nconst MAP := 69\n')
        self.scene('xiyou_floor_gate', 'func t():\n\tvar s := _start(4, 1, 1)\n\tawait _wait_map(88)\n')
        self.scene('xiyou_floor_goto', '_goto(31, 9, 9, 2, 18, Vector2i(9, 12))')
        self.scene('xiyou_floor_run', '## 楼层表从内容数据推出（Map004 大厅）')
        self.scene('xiyou_map186', '## Map186\n')
        self.scene('xiyou_flow', 'flow')
        self.commit('floors')
        self.base = self.g('rev-parse', 'HEAD')

    def test_added_map_picks_only_its_floor(self):
        self.edit(maps=[1, 2, 69])
        self.assertEqual(self.pick()['scenes'], ['xiyou_event_compare.tscn', 'xiyou_floor_a.tscn', 'xiyou_floor_reach069.tscn',
                                                 'xiyou_floor_run.tscn', 'xiyou_flow.tscn'])

    def test_code_refs_and_keep_events_edit(self):
        self.edit(keepEvents={'1': '*', '88': [3]})
        self.assertIn('xiyou_floor_gate.tscn', self.pick()['scenes'])
        self.edit(maps=[1, 2, 18])
        s = self.pick()['scenes']
        self.assertIn('xiyou_floor_goto.tscn', s)
        self.assertNotIn('xiyou_floor_gate.tscn', s)

    def test_map_without_floor_test_picks_no_specific_floor(self):
        self.edit(maps=[1, 2, 300])
        s = self.pick()
        self.assertEqual(s['scenes'], ['xiyou_event_compare.tscn', 'xiyou_floor_a.tscn', 'xiyou_floor_run.tscn', 'xiyou_flow.tscn'])
        self.assertIn('按图号 300 收窄', s['reasons'][0][1])

    def test_removed_map_counts(self):
        self.put(SLICE, json.dumps({**self.slice, 'maps': [1, 2, 186]}, indent=2) + '\n')
        self.commit('add 186')
        self.base = self.g('rev-parse', 'HEAD')
        self.edit(maps=[1, 2])
        self.assertIn('xiyou_map186.tscn', self.pick()['scenes'])

    def test_unparsed_structure_does_not_narrow(self):
        self.edit(maps=[1, 2, 'x'])
        self.assertIn('xiyou_map186.tscn', self.pick()['scenes'])

    def test_switch_off_restores_all_floors(self):
        table = json.loads((HERE / '选测对照.json').read_text())
        table['sliceSections']['narrowFloorsByMap']['enabled'] = False
        off = self.root / 'off.json'
        off.write_text(json.dumps(table))
        self.edit(maps=[1, 2, 69])
        s = sel.select(self.root, self.base, table=off)
        self.assertTrue({'xiyou_floor_gate.tscn', 'xiyou_floor_goto.tscn', 'xiyou_map186.tscn'} <= set(s['scenes']))
        self.assertNotIn('收窄', s['reasons'][0][1])

    def test_floor_with_unrecognized_map_refs_is_kept(self):
        """沙僧第八期 F1／P2：认出一张图就当集合完整、按交集删场景，漏了 MAPS 表里的出口图（unknown160 漏 32）、
        HUB 常量（floor30_seeker 漏 4）。脚本里出现改动图号的整数字面量就保留；preload 的 tests/ 脚本一并看（tools24）。"""
        self.scene('xiyou_floor_unknown160', '## 未知之地（Map160）\nconst MAPS := {"exits": [[1, 32], [2, 33]]}\n'
                   'func t(dest):\n\tawait _wait_map(dest[1])\n')
        self.scene('xiyou_floor30_seeker', 'const HUB := 4\nfunc t():\n\t_start(55, 1, 1)\n\tawait _wait_map(HUB)\n')
        self.scene('xiyou_floor_helped', 'const R := preload("res://tests/xiyou_helper_x.gd")\nfunc t():\n\t_start(56, 1, 1)\n')
        self.put(TESTS / 'xiyou_helper_x.gd', 'extends Node\nfunc go():\n\tawait _wait_map(77)\n')
        self.commit('f1 fixtures')
        self.base = self.g('rev-parse', 'HEAD')
        for maps, scene in [([1, 2, 32], 'xiyou_floor_unknown160.tscn'), ([1, 2, 4], 'xiyou_floor30_seeker.tscn'),
                            ([1, 2, 77], 'xiyou_floor_helped.tscn')]:
            self.edit(maps=maps)
            s = self.pick()['scenes']
            self.assertIn(scene, s, maps)
            self.assertNotIn('xiyou_floor_reach069.tscn', s)                       # 仍能收窄：69 号没改
        self.edit(maps=[1, 2, 160])
        self.assertNotIn('xiyou_floor30_seeker.tscn', self.pick()['scenes'])

    def test_literal_guard_switch_off_restores_old_rule(self):
        self.scene('xiyou_floor30_seeker', 'const HUB := 4\nfunc t():\n\t_start(55, 1, 1)\n\tawait _wait_map(HUB)\n')
        self.commit('seeker')
        self.base = self.g('rev-parse', 'HEAD')
        table = json.loads((HERE / '选测对照.json').read_text())
        table['sliceSections']['narrowFloorsByMap']['anyLiteral'] = False
        off = self.root / 'off.json'
        off.write_text(json.dumps(table))
        self.edit(maps=[1, 2, 4])
        self.assertNotIn('xiyou_floor30_seeker.tscn', sel.select(self.root, self.base, table=off)['scenes'])
        self.assertIn('xiyou_floor30_seeker.tscn', self.pick()['scenes'])

    def test_real_f1_counterexamples_are_kept(self):
        tests = sel.Tests(HERE.parent.parent)
        self.assertTrue(tests.mentions('xiyou_floor_unknown160.tscn', {32}))
        self.assertTrue(tests.mentions('xiyou_floor30_seeker.tscn', {4}))

    def test_real_tests_reference_their_maps(self):
        tests = sel.Tests(HERE.parent.parent)
        self.assertEqual(tests.map_ids('xiyou_floor_reach069.tscn') >= {69, 71, 88, 89, 91, 112}, True)
        self.assertEqual(tests.map_ids('xiyou_map186_b.tscn') >= {186}, True)


class MergeBaseTests(Fixture):
    """车道 --affected main 而 main 已前进：只算本分支自己的改动。"""
    def test_lane_ignores_main_progress_unless_switched_off(self):
        self.g('switch', '-q', '-c', 'lane')
        self.put(Path('00_项目管理/交接板.md'), '# lane\n')
        self.commit('lane docs')
        self.g('switch', '-q', 'main')
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# main moved\n')
        self.commit('main battle')
        self.g('switch', '-q', 'lane')
        s = sel.select(self.root, 'main')
        self.assertEqual(s['files'], ['00_项目管理/交接板.md'])
        self.assertIn('分叉点', s['base'])
        table = json.loads((HERE / '选测对照.json').read_text())
        table['mergeBase'] = False
        off = self.root / 'off.json'
        off.write_text(json.dumps(table))
        s = sel.select(self.root, 'main', table=off)
        self.assertIn(str(CORE / 'battler.gd'), s['files'])
        self.assertEqual(sel.select(self.root, self.base)['base'], self.base)  # 基准是祖先：照旧

    def test_stale_lane_gets_merge_main_notice_only_when_main_moved_gd(self):
        """tools53：分叉点之后 main 改过 .gd 才提示先合 main；只改文档或基准是祖先时不提示。"""
        self.g('switch', '-q', '-c', 'lane')
        self.put(Path('00_项目管理/交接板.md'), '# lane\n')
        self.commit('lane docs')
        self.g('switch', '-q', 'main')
        self.put(Path('00_项目管理/变更记录.md'), '# log\n')
        self.commit('main docs')
        self.g('switch', '-q', 'lane')
        self.assertEqual(sel.select(self.root, 'main')['notice'], '')
        self.g('switch', '-q', 'main')
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# main moved\n')
        self.commit('main battle')
        self.g('switch', '-q', 'lane')
        s = sel.select(self.root, 'main')
        self.assertIn('git merge main', s['notice'])
        out = io.StringIO()
        sel.report(s, out)
        self.assertIn('先 git merge main 再选测', out.getvalue())
        self.g('merge', '-q', 'main', '-m', 'merge main')
        self.assertEqual(sel.select(self.root, 'main')['notice'], '')


class HookLineTests(Fixture):
    """tools54：核心文件里只加「调用专属模块」的钩子行时，只选冒烟场景＋引用这些模块的测试；改了别的逻辑、开关关掉、认不出就退回按文件整组。"""

    def setUp(self):
        super().setUp()
        self.put(CORE / 'hooked.gd', 'class_name XHooked\n')
        self.scene('xiyou_hooked', 'XHooked.go()')
        self.scene('xiyou_big', 'XBattler.new()')
        self.scene('xiyou_determinism', 'XBattler.new()')
        self.put(CORE / 'battler.gd', 'class_name XBattler\nfunc f(d):\n\tvar a = 1\n\treturn a\n')
        self.commit('hook fixture')
        self.base = self.g('rev-parse', 'HEAD')

    def edit(self, extra):
        self.put(CORE / 'battler.gd', 'class_name XBattler\nfunc f(d):\n\tvar a = 1\n' + extra + '\treturn a\n')
        self.commit('lane')

    def scenes(self, hooks='1'):
        with mock.patch.dict(os.environ, {'XIYOU_HOOKS': hooks}):
            return {x[:-5] for x in self.pick()['scenes']}

    def test_hook_only_narrows_to_smoke_and_module_users(self):
        self.edit('\tXHooked.go()  # 钩子\n')
        new, old = self.scenes('1'), self.scenes('0')
        self.assertIn('xiyou_big', old)
        self.assertNotIn('xiyou_big', new)
        self.assertTrue({'xiyou_hooked', 'xiyou_determinism', 'xiyou_battle', 'xiyou_event_compare'} <= new)
        reasons = ' '.join(r[1] for r in self.pick()['reasons'])
        self.assertIn('只加钩子调用：XHooked', reasons)

    def test_glue_lines_allowed_next_to_a_hook_call(self):
        self.edit('\tif XHooked.has(d):\n\t\treturn {}\n')
        self.assertNotIn('xiyou_big', self.scenes('1'))

    def test_real_logic_change_falls_back(self):
        self.edit('\tXHooked.go()\n\tvar hp = 1 + 2\n')
        self.assertIn('xiyou_big', self.scenes('1'))

    def test_hook_free_hunk_falls_back(self):
        self.edit('\tXHooked.go()\n')
        self.put(CORE / 'battler.gd', 'class_name XBattler\nfunc f(d):\n\tvar a = 1\n\tXHooked.go()\n\treturn a\nfunc g():\n\tvar hp = 3\n')
        self.commit('lane2')
        self.assertIn('xiyou_big', self.scenes('1'))

    def test_core_infrastructure_module_is_not_a_hook(self):
        self.edit('\tXDB.table("Skills")\n')
        self.assertIn('xiyou_big', self.scenes('1'))

    def test_switch_off_restores_file_level_selection(self):
        self.edit('\tXHooked.go()\n')
        self.assertIn('xiyou_big', self.scenes('0'))
        self.assertNotIn('xiyou_hooked', self.scenes('0'))


class HookHistoryTests(unittest.TestCase):
    """tools54 回归例：用主线真实合并算新旧两种选法（不抽样）。新 ⊆ 旧 ∪ 冒烟场景；该合并专属的专项（各车道交付单里跑的）必须在新选法里；
    真改了核心逻辑的合并（296a571a honghuang2）新旧一样。提交不在（浅克隆）就跳过。"""
    ROOT = HERE.parent.parent
    CASES = [  # (合并, 必选的专项, 是否应变窄)
        ('b5f3a0ce', ['xiyou_xuan_battle', 'xiyou_xuan_chart', 'xiyou_xuan_bind', 'xiyou_binding'], True),
        ('c7b7f237', ['xiyou_heartsteel', 'xiyou_growth_forge', 'xiyou_growth_help'], True),
        ('effc9fa4', ['xiyou_xuan_battle', 'xiyou_xuan_chart'], True),
        ('296a571a', [], False),
    ]

    def both(self, merge):
        try:
            base = subprocess.run(['git', '-C', str(self.ROOT), 'rev-parse', '--verify', '-q', merge + '^1'],
                                  capture_output=True, text=True, check=True).stdout.strip()
        except subprocess.CalledProcessError:
            self.skipTest('提交 %s 不在本克隆里' % merge)
        out = {}
        for flag in ('0', '1'):
            with mock.patch.dict(os.environ, {'XIYOU_HOOKS': flag}):
                out[flag] = sel.select(self.ROOT, base, head=merge, sample=False)
        return out['0'], out['1']

    def test_history_cases(self):
        for merge, must, narrower in self.CASES:
            old, new = self.both(merge)
            with self.subTest(merge=merge):
                tests = sel.Tests(self.ROOT, merge)
                groups, _ = sel.load_table()
                smoke = {x for pat in groups['battle_hooks']['scenes'] for x in tests.glob(pat)}
                self.assertEqual(sorted(set(new['scenes']) - set(old['scenes']) - smoke), [])  # 新选法只会多出冒烟场景
                missing = [m for m in must if m + '.tscn' not in new['scenes']]
                self.assertEqual(missing, [])
                if narrower:
                    self.assertLess(len(new['scenes']), len(old['scenes']))
                else:
                    self.assertEqual(new['scenes'], old['scenes'])


class SampleTests(Fixture):
    """tools43①：rules／smart_ai 每 4 段留 1 段，按提交号轮换；改了测试本身的段照跑；开关关掉回到全跑。"""
    def setUp(self):
        super().setUp()
        for part in ['d1c', 'd1d', 'd2b', 'd2c', 'd2d']:
            self.put(TESTS / ('xiyou_rules_%s.tscn' % part), '[ext_resource path="res://tests/xiyou_rules.gd" id="1"]\n')
        self.scene('xiyou_smart_ai', 'XBattler')
        for part in 'bcd':
            self.put(TESTS / ('xiyou_smart_ai_%s.tscn' % part), '[ext_resource path="res://tests/xiyou_smart_ai.gd" id="1"]\n')
        self.commit('eight rules parts, four smart_ai parts')
        self.base = self.g('rev-parse', 'HEAD')
        self.rules = ['xiyou_rules.tscn'] + ['xiyou_rules_%s.tscn' % p for p in ['d1b', 'd1c', 'd1d', 'd2', 'd2b', 'd2c', 'd2d']]
        self.ai = ['xiyou_smart_ai.tscn'] + ['xiyou_smart_ai_%s.tscn' % p for p in 'bcd']

    def test_battle_change_keeps_one_part_per_group(self):
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# changed\n')
        s = self.pick()
        self.assertFalse(s['full'])
        kept = [x for x in s['scenes'] if x in self.rules]
        self.assertEqual(len(kept), 2)
        self.assertEqual(sorted(self.rules.index(x) // 4 for x in kept), [0, 1])  # 每个难度一段
        self.assertEqual(len([x for x in s['scenes'] if x in self.ai]), 1)
        self.assertEqual(sum(len(d) for *_, d in s['sampled']), 9)
        self.assertIn('xiyou_battle.tscn', s['scenes'])                     # 不在族里的照选
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            sel.report(s, sys.stdout)
        self.assertIn('抽样', out.getvalue())
        self.assertIn('省 6 个', out.getvalue())

    def test_rotation_is_by_commit_and_covers_every_part(self):
        sample = sel.load_sample()
        seen = set()
        for seed in range(4):
            keep, _ = sel.apply_sample(self.rules, set(), self.rules, sample, seed)
            self.assertEqual(len(keep), 2)
            self.assertEqual(keep, sel.apply_sample(self.rules, set(), self.rules, sample, seed)[0])  # 同提交同结果
            seen.update(keep)
        self.assertEqual(seen, set(self.rules))
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# changed\n')
        self.assertEqual(self.pick()['scenes'], self.pick()['scenes'])

    def test_four_consecutive_merges_cover_each_group(self):
        """审查 27 P3-1：主线一次合并占「合并＋收尾」两个第一父提交，被测提交常差 2（数全部提交一组只轮两段）；
        种子只数合并提交，连续 4 次合并（测的是收尾提交）正好轮完每组 4 段。"""
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# changed\n')
        main_branch = self.g('rev-parse', '--abbrev-ref', 'HEAD')
        seen, seeds = set(), []
        for i in range(4):
            self.g('checkout', '-q', '-b', 'lane%d' % i)
            self.put(UI / 'nobody.gd', 'class_name XNobody\n# %d\n' % i)
            self.commit('lane %d' % i)
            self.g('checkout', '-q', main_branch)
            self.g('merge', '-q', '--no-ff', '-m', 'merge lane%d' % i, 'lane%d' % i)
            self.put(UI / 'nobody2.gd', 'class_name XNobody2\n# %d\n' % i)
            self.commit('closing %d' % i)                                   # 收尾提交：第一父上再多一个
            seeds.append(sel.sample_seed(self.root))
            seen.update(x for x in self.pick()['scenes'] if x in self.rules)
        self.assertEqual(seeds, list(range(seeds[0], seeds[0] + 4)))
        self.assertEqual(seen, set(self.rules))

    def test_changed_part_runs_and_represents_its_group(self):
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# changed\n')
        self.put(TESTS / 'xiyou_rules_d2c.tscn', '[ext_resource path="res://tests/xiyou_rules.gd" id="1"]\n# edited\n')
        kept = [x for x in self.pick()['scenes'] if x in self.rules]
        self.assertIn('xiyou_rules_d2c.tscn', kept)
        self.assertEqual(len(kept), 2)
        self.put(TESTS / 'xiyou_rules.gd', 'extends Node\nXBattler\n# helper edited\n')
        self.assertEqual([x for x in self.pick()['scenes'] if x in self.rules], self.rules)  # 改了共用脚本：全跑

    def test_switches_and_uneven_family(self):
        self.put(CORE / 'battler.gd', 'class_name XBattler\n# changed\n')
        os.environ['XIYOU_SAMPLE'] = '0'
        try:
            self.assertEqual([x for x in self.pick()['scenes'] if x in self.rules], self.rules)
        finally:
            del os.environ['XIYOU_SAMPLE']
        table = json.loads((HERE / '选测对照.json').read_text())
        table['sample']['enabled'] = False
        off = self.root / 'off.json'
        off.write_text(json.dumps(table))
        self.assertEqual([x for x in sel.select(self.root, self.base, off)['scenes'] if x in self.rules], self.rules)
        self.assertEqual([x for x in sel.select(self.root, self.base, sample=False)['scenes'] if x in self.rules], self.rules)
        (self.root / TESTS / 'xiyou_smart_ai_d.tscn').unlink()             # 3 段不是 4 的整数倍：这一族不抽
        self.assertEqual([x for x in self.pick()['scenes'] if x.startswith('xiyou_smart_ai')], self.ai[:3])

    def test_full_selection_is_not_sampled(self):
        self.put(PROJECT / 'mystery.txt', 'x\n')
        s = self.pick()
        self.assertTrue(s['full'])
        self.assertEqual(s['sampled'], [])


reuse_spec = importlib.util.spec_from_file_location('reuse', HERE / '沿用车道.py')
reuse = importlib.util.module_from_spec(reuse_spec)
reuse_spec.loader.exec_module(reuse)


class ReuseTests(SampleTests):
    """tools43②：车道测过的提交 → 现在工作区的差异没波及的场景沿用；差异整轮、改了产物来源时一个都不沿用。"""
    def lane(self):
        self.put(UI / 'nobody.gd', 'class_name XNobody\n# lane\n')
        self.commit('lane work')
        return self.g('rev-parse', 'HEAD')

    def test_untouched_scenes_reuse_lane_result(self):
        c = self.lane()
        self.put(UI / 'shop.gd', 'class_name XShopScene\n# main moved\n')  # 合并后主线带来的改动波及 shop
        want = ['xiyou_shop.tscn', 'xiyou_event_compare.tscn', 'xiyou_battle.tscn']
        keep, used, notes = reuse.plan(self.root, self.base, want, {c: ('本机', {'xiyou_shop.tscn', 'xiyou_battle.tscn'}, set())}, sel)
        self.assertEqual(keep, ['xiyou_shop.tscn', 'xiyou_event_compare.tscn'])  # shop 被波及，event_compare 车道没测
        self.assertEqual(used, {'xiyou_battle.tscn': (c, '本机', 'xiyou_battle.tscn')})
        self.assertIn('沿用 %s（本机）1 个：xiyou_battle' % c[:9], reuse.summarize(used))

    def test_generated_inputs_or_full_diff_reuse_nothing(self):
        c = self.lane()
        self.put(TOOLS / 'xiyou_slice.json', '{"troops": [1]}\n')
        keep, used, notes = reuse.plan(self.root, self.base, ['xiyou_battle.tscn'], {c: ('本机', {'xiyou_battle.tscn'}, set())}, sel)
        self.assertEqual((keep, used), (['xiyou_battle.tscn'], {}))
        self.assertIn('产物来源', notes[0])
        self.g('checkout', '--', str(TOOLS / 'xiyou_slice.json'))
        self.put(PROJECT / 'mystery.txt', 'x\n')
        keep, used, notes = reuse.plan(self.root, self.base, ['xiyou_battle.tscn'], {c: ('本机', {'xiyou_battle.tscn'}, set())}, sel)
        self.assertEqual(used, {})
        self.assertIn('整轮', notes[0])

    def test_sampled_part_reuses_other_part_of_same_group(self):
        c = self.lane()
        keep, used, _ = reuse.plan(self.root, self.base, ['xiyou_rules_d1c.tscn', 'xiyou_rules_d2.tscn'],
                                   {c: ('本机', {'xiyou_rules_d1b.tscn'}, set())}, sel)
        self.assertEqual(keep, ['xiyou_rules_d2.tscn'])                    # 第二组车道一段也没测
        self.assertEqual(used['xiyou_rules_d1c.tscn'][2], 'xiyou_rules_d1b.tscn')

    def test_touched_part_is_not_replaced_by_group_mate(self):
        """审查 26 P2-1：差异只改了 d1c 这一段的 .tscn，C 时 d1b、d1c 都通过；d1c 被波及，不能拿 d1b 的旧结果顶掉。"""
        c = self.lane()
        self.put(TESTS / 'xiyou_rules_d1c.tscn', '[ext_resource path="res://tests/xiyou_rules.gd" id="1"]\n# edited\n')
        keep, used, _ = reuse.plan(self.root, self.base, ['xiyou_rules_d1c.tscn'],
                                   {c: ('本机', {'xiyou_rules_d1b.tscn', 'xiyou_rules_d1c.tscn'}, set())}, sel)
        self.assertEqual((keep, used), (['xiyou_rules_d1c.tscn'], {}))
        old = self.g('rev-parse', 'HEAD~1')                                 # 更早的 C 也一样：被波及就不替补
        keep, used, _ = reuse.plan(self.root, self.base, ['xiyou_rules_d1c.tscn'],
                                   {c: ('本机', {'xiyou_rules_d1c.tscn'}, set()), old: ('本机', {'xiyou_rules_d1b.tscn'}, set())}, sel)
        self.assertEqual(keep, ['xiyou_rules_d1c.tscn'])

    def test_failed_part_is_not_replaced_by_group_mate(self):
        """审查 27 P2-1 复现一：C 上 d1b 通过、d1c 跑了但失败，之后没改 d1c：d1c 要照跑，不能拿 d1b 的通过顶。"""
        c = self.lane()
        keep, used, _ = reuse.plan(self.root, self.base, ['xiyou_rules_d1c.tscn'],
                                   {c: ('本机', {'xiyou_rules_d1b.tscn'}, {'xiyou_rules_d1c.tscn'})}, sel)
        self.assertEqual((keep, used), (['xiyou_rules_d1c.tscn'], {}))

    def test_newer_failure_beats_older_pass(self):
        """审查 27 P2-1 复现二：旧提交通过、新提交失败，中间只改了无关文件：以新提交的失败为准，照跑。"""
        old = self.lane()
        self.put(UI / 'nobody.gd', 'class_name XNobody\n# second\n')
        self.commit('second')
        new = self.g('rev-parse', 'HEAD')
        recs = {new: ('本机', set(), {'xiyou_battle.tscn'}), old: ('本机', {'xiyou_battle.tscn'}, set())}
        keep, used, _ = reuse.plan(self.root, self.base, ['xiyou_battle.tscn'], recs, sel)
        self.assertEqual((keep, used), (['xiyou_battle.tscn'], {}))
        recs = {new: ('本机', {'xiyou_battle.tscn'}, set()), old: ('本机', set(), {'xiyou_battle.tscn'})}  # 反过来：新的通过就沿用
        keep, used, _ = reuse.plan(self.root, self.base, ['xiyou_battle.tscn'], recs, sel)
        self.assertEqual((keep, used), ([], {'xiyou_battle.tscn': (new, '本机', 'xiyou_battle.tscn')}))

    def test_cloud_failure_beats_older_pass(self):
        """审查 29 P3-4：云端没通过的运行也进失败集（failed 名单；没有就整份 sceneNames），新失败压过旧通过。"""
        self.assertEqual(reuse.cloud_sets({'passed': True, 'sceneNames': ['a.tscn', 'b.tscn']}), ({'a.tscn', 'b.tscn'}, set()))
        self.assertEqual(reuse.cloud_sets({'passed': False, 'sceneNames': ['a.tscn', 'b.tscn'], 'failed': ['b.tscn']}), (set(), {'b.tscn'}))
        self.assertEqual(reuse.cloud_sets({'passed': False, 'sceneNames': ['a.tscn', 'b.tscn'], 'failed': []}), (set(), {'a.tscn', 'b.tscn'}))
        self.assertEqual(reuse.cloud_sets({'passed': False, 'sceneNames': ['a.tscn']}), (set(), {'a.tscn'}))
        self.assertIsNone(reuse.cloud_sets({'passed': False}))
        old = self.lane()
        self.put(UI / 'nobody.gd', 'class_name XNobody\n# second\n')
        self.commit('second')
        new = self.g('rev-parse', 'HEAD')
        s = reuse.cloud_sets({'passed': False, 'sceneNames': ['xiyou_battle.tscn'], 'failed': ['xiyou_battle.tscn']})
        recs = {new: ('云端', s[0], s[1]), old: ('云端', {'xiyou_battle.tscn'}, set())}
        keep, used, _ = reuse.plan(self.root, self.base, ['xiyou_battle.tscn'], recs, sel)
        self.assertEqual((keep, used), (['xiyou_battle.tscn'], {}))

    def test_local_records_need_same_environment(self):
        sdir = self.root / 'state'
        (sdir / 'commit_results').mkdir(parents=True)
        now = {'godot': '4.5', 'generated': 'g1', 'timeout': 600}
        rec = dict(now, scenes={'a.tscn': True, 'b.tscn': False}, time='t')
        (sdir / 'commit_results/c1.json').write_text(json.dumps(rec))
        (sdir / 'commit_results/c2.json').write_text(json.dumps(dict(rec, generated='g2')))
        (sdir / 'commit_results/c3.json').write_text('not json')
        got = reuse.local_records(sdir, ['c1', 'c2', 'c3', 'c4'], now)
        self.assertEqual(list(got), ['c1'])
        self.assertEqual((got['c1'][1], got['c1'][2]), ({'a.tscn'}, {'b.tscn'}))  # 失败的也带出（审查 27 P2-1）

    def test_cli_disabled_and_note_file(self):
        import contextlib, io
        c = self.lane()
        note = self.root / '.git' / reuse.NOTE
        note.write_text('stale\n')
        out = io.StringIO()
        os.environ['XIYOU_REUSE_LANE'] = '0'
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
                rc = reuse.main([self.base, '--root', str(self.root), '--godot', 'none', '--project', str(self.root / PROJECT),
                                 '--shell', 'xiyou_battle'])
        finally:
            del os.environ['XIYOU_REUSE_LANE']
        self.assertEqual(rc, 0)
        self.assertIn('REUSE_KEEP=(xiyou_battle.tscn)', out.getvalue())
        self.assertIn('REUSE_COUNT=0', out.getvalue())
        self.assertFalse(note.exists())                                      # 旧说明不留给收尾尾注


class CloudSkipTests(unittest.TestCase):
    """tools43②：云端计划读 Mac 推来的 refs/ci/skip/<提交>；没有、读坏都当空集合（照跑）。"""
    def test_skip_list(self):
        spec = importlib.util.spec_from_file_location('cloud', HERE / '云端选测.py')
        cloud = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cloud)
        blobs = {}
        cloud.ls_remote = lambda remote, *refs, git_dir=None: {r: 'x' for r in refs if r in blobs}
        cloud.git = lambda *a, **k: blobs.get(cloud.SKIP_PREFIX + 'abc', '') if a[0] == 'cat-file' else ''
        self.assertEqual(cloud.skip_list('abc'), set())
        blobs[cloud.SKIP_PREFIX + 'abc'] = '["a.tscn", "b.tscn", 3]'
        self.assertEqual(cloud.skip_list('abc'), {'a.tscn', 'b.tscn'})
        blobs[cloud.SKIP_PREFIX + 'abc'] = 'oops'
        self.assertEqual(cloud.skip_list('abc'), set())


runner_spec = importlib.util.spec_from_file_location('runner', HERE / '并行测试.py')
runner = importlib.util.module_from_spec(runner_spec)
runner_spec.loader.exec_module(runner)


class CommitRecordTests(Fixture):
    """tools43②：并行测试.py 只在工程目录干净时按提交记账，环境变了不混旧行。"""
    def test_records_only_clean_commits(self):
        godot = self.root / 'fake_godot'
        godot.write_text('#!/bin/sh\necho 4.5.fake\n'); godot.chmod(0o755)
        (self.root / '.gitignore').write_text('fake_godot\nstate/\n' + str(PROJECT / 'modes/xiyou/generated') + '/\n')
        gen = self.root / PROJECT / 'modes/xiyou/generated'
        gen.mkdir(parents=True)
        (gen / 'a.json').write_text('{}')
        self.commit('ignore')
        sdir = self.root / 'state'
        sdir.mkdir()
        project = str(self.root / PROJECT)
        sha = runner.record_commit_results(project, sdir, str(godot), {'x.tscn': True})
        self.assertEqual(sha, self.g('rev-parse', 'HEAD'))
        rec = json.loads((sdir / 'commit_results' / (sha + '.json')).read_text())
        self.assertEqual((rec['godot'], rec['scenes']), ('4.5.fake', {'x.tscn': True}))
        runner.record_commit_results(project, sdir, str(godot), {'y.tscn': False})
        self.assertEqual(json.loads((sdir / 'commit_results' / (sha + '.json')).read_text())['scenes'], {'x.tscn': True, 'y.tscn': False})
        (gen / 'a.json').write_text('{"changed": 1}')                     # 产物变了：旧行作废
        runner.record_commit_results(project, sdir, str(godot), {'z.tscn': True})
        self.assertEqual(json.loads((sdir / 'commit_results' / (sha + '.json')).read_text())['scenes'], {'z.tscn': True})
        self.put(UI / 'shop.gd', 'dirty\n')                                # 有未提交改动：不记
        self.assertEqual(runner.record_commit_results(project, sdir, str(godot), {'x.tscn': True}), '')
        self.g('checkout', '--', str(UI / 'shop.gd'))
        self.put(TESTS / 'new.gd', 'x\n')                                  # 未跟踪的新文件也算不干净
        self.assertEqual(runner.record_commit_results(project, sdir, str(godot), {'x.tscn': True}), '')


STUB_CHECKS = ['测试工作树清理.py', '测试导出过滤.py', '测试共性验收.py', '测试合并工具.py', '测试公式程序.py', '测试转换器写入.py',
               '测试记录工具.py', '测试云端准备.py', '测试内容覆盖.py', '测试角色同步提速.py', '测试事件探针分段.py', '测试状态js翻译.py', '测试参照批次.py', '测试提交守卫.py', '测试回退开关覆盖.py', '回退开关覆盖.py', '探针登记检查.py', '测试探针登记检查.py', '测试反向验证.py', '语法检查.py', '参照批次.py', '测试选测.py', '变更记录分卷.py', '待核查.py']


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
        # 沿用车道.py 替身（tools43）：记一行；FAKE_REUSE_DROP 里的场景当作沿用（不再跑），其余原样交回
        self.put(ENV / '沿用车道.py', record + 'import os\nnames = sys.argv[sys.argv.index("--shell") + 1:]\n'
                 'drop = set(os.environ.get("FAKE_REUSE_DROP", "").split())\n'
                 'print("REUSE_KEEP=(%s)" % " ".join(n for n in names if n not in drop))\n'
                 'print("REUSE_COUNT=%d" % len([n for n in names if n in drop]))\n')
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

    def check(self, *args, env=None):
        env = dict(self.env, XIYOU_LONG_TASK_MANAGED='1', GODOT=str(self.godot), **(env or {}))
        p = subprocess.run(['zsh', str(self.root / ENV / '检查.sh'), *args], capture_output=True, text=True, env=env)
        ran = self.calls.read_text().splitlines() if self.calls.exists() else []
        self.calls.unlink(missing_ok=True)
        return p.returncode, p.stdout + p.stderr, ran

    def names(self, ran):
        return sorted({line.split()[0] for line in ran})

    def cloud_check(self, run_rc=0, wait_rc=0, *args, no_upload=False):
        """XIYOU_CLOUD_SCRIPT 桩：记下参数；run／wait 的退出码由参数定，wait 退出前打印一行汇总。"""
        stub = self.root / 'cloud_stub.py'
        stub.write_text('import sys\nopen(%r, "a").write("cloud " + " ".join(sys.argv[1:]) + "\\n")\n'
                        'rc = {"run": %d, "wait": %d}[sys.argv[1]]\n'
                        'if sys.argv[1] == "wait": print("云端汇总：" + ("通过" if rc == 0 else "失败 xiyou_shop.tscn" if rc == 1 else "超时"))\n'
                        'sys.exit(rc)\n' % (str(self.calls), run_rc, wait_rc))
        self.put(UI / 'shop.gd', 'class_name XShopScene\n# cloud\n')
        self.env = dict(self.env, XIYOU_CLOUD_SCRIPT=str(stub), **({'CHECK_CLOUD_NO_UPLOAD': '1'} if no_upload else {}))
        return self.check('--affected', self.base, '--cloud', *args)

    def test_cloud_passes_and_skips_local_godot(self):
        rc, out, ran = self.cloud_check(no_upload=True)
        self.assertEqual(rc, 0, out)
        self.assertIn('云端选测通过', out)
        self.assertNotIn('godot', self.names(ran))
        self.assertNotIn('并行测试.py', self.names(ran))
        self.assertIn('guard_check.cjs', self.names(ran))                   # 非 Godot 检查仍在本机
        cloud = [l for l in ran if l.startswith('cloud')]
        self.assertEqual(cloud[0], 'cloud run --no-upload')
        self.assertRegex(cloud[1], r'^cloud wait [0-9a-f]{40} --mode affected --timeout 2700$')

    def test_cloud_uploads_unless_told_not_to(self):
        rc, out, ran = self.cloud_check()
        self.assertEqual(rc, 0, out)
        self.assertEqual([l for l in ran if l.startswith('cloud run')], ['cloud run'])

    def test_cloud_failure_lists_failure(self):
        rc, out, _ = self.cloud_check(wait_rc=1)
        self.assertEqual(rc, 1, out)
        self.assertIn('失败 xiyou_shop.tscn', out)
        self.assertIn('云端选测未通过', out)

    def test_cloud_timeout_is_an_error_not_a_local_fallback(self):
        rc, out, ran = self.cloud_check(wait_rc=124)
        self.assertEqual(rc, 1, out)
        self.assertIn('云端选测超时', out)
        self.assertIn('改用本机', out)
        self.assertNotIn('godot', self.names(ran))
        self.assertNotIn('并行测试.py', self.names(ran))

    def test_cloud_run_finished_without_result_is_an_error(self):
        rc, out, ran = self.cloud_check(wait_rc=3)
        self.assertEqual(rc, 1, out)
        self.assertIn('云端运行已结束但没有结果', out)
        self.assertNotIn('godot', self.names(ran))

    def test_cloud_quota_exhausted_falls_back_to_local(self):
        # tools29：云端一个任务都没启动（额度用完）不是代码问题，同一批场景改在本机跑，CHECK_JOBS 默认 3
        rc, out, ran = self.cloud_check(wait_rc=4)
        self.assertEqual(rc, 0, out)
        self.assertIn('额度用完', out)
        self.assertIn('改用本机跑', out)
        self.assertIn('CHECK_JOBS=3', out)
        self.assertIn('并行测试.py', self.names(ran))                          # 云端要跑的那批（这里选测扩成整轮）改在本机跑

    def test_cloud_billing_block_falls_back_and_says_not_code(self):
        rc, out, ran = self.cloud_check(wait_rc=5)
        self.assertEqual(rc, 0, out)
        self.assertIn('账单问题', out)
        self.assertIn('不是代码问题', out)
        self.assertIn('并行测试.py', self.names(ran))
        self.assertIn('godot', self.names(ran))                               # 本机照常先导入

    def test_cloud_fallback_switch_off_restores_error(self):
        self.env = dict(self.env, CHECK_CLOUD_FALLBACK='0')
        for code, words in [(4, '额度用完'), (5, '账单问题')]:
            rc, out, ran = self.cloud_check(wait_rc=code)
            self.assertEqual(rc, 1, out)
            self.assertIn(words, out)
            self.assertIn('去掉 --cloud', out)
            self.assertNotIn('并行测试.py', self.names(ran))

    def test_cloud_fallback_keeps_given_jobs(self):
        self.env = dict(self.env, CHECK_JOBS='2')
        rc, out, _ = self.cloud_check(wait_rc=5)
        self.assertEqual(rc, 0, out)
        self.assertIn('CHECK_JOBS=2', out)

    def test_cloud_unavailable_is_an_error_not_a_local_fallback(self):
        rc, out, ran = self.cloud_check(run_rc=1)
        self.assertEqual(rc, 1, out)
        self.assertIn('云端选测触发失败', out)
        self.assertNotIn('cloud wait', '\n'.join(ran))
        self.assertNotIn('并行测试.py', self.names(ran))

    def test_cloud_needs_affected_and_skips_when_no_scenes(self):
        rc, out, _ = self.check('--cloud')
        self.assertEqual(rc, 2, out)
        self.assertIn('--cloud 只和 --affected', out)
        self.put(Path('00_项目管理/交接板.md'), '# board 2\n')
        self.env = dict(self.env, XIYOU_CLOUD_SCRIPT=str(self.root / 'nope.py'))
        rc, out, ran = self.check('--affected', self.base, '--cloud')
        self.assertEqual(rc, 0, out)                                         # 没有 Godot 场景：不碰云端
        self.assertIn('跳过导入与测试', out)

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
        # 回退开关覆盖属文档与登记（读优化登记），只改文档也跑（tools26，不到 1 秒、只警告）；探针登记检查同样每次跑（tools31 守卫，不到 1 秒）
        self.assertEqual(self.names(ran), ['boot_check.cjs', '变更记录分卷.py', '回退开关覆盖.py', '待核查.py', '探针登记检查.py'])

    def test_ui_change_runs_selected_scenes_only(self):
        self.put(UI / 'shop.gd', 'class_name XShopScene\n# 2\n')
        rc, out, ran = self.check('--affected', self.base)
        self.assertEqual(rc, 0, out)
        runner = next(l for l in ran if l.startswith('并行测试.py')).split()
        self.assertEqual(runner[3:], ['--reuse', 'xiyou_event_compare.tscn', 'xiyou_shop.tscn'])  # 选测按指纹沿用
        self.assertIn('guard_check.cjs', self.names(ran))
        self.assertNotIn('测试合并工具.py', self.names(ran))

    def test_lane_reuse_drops_scenes_and_switch_off(self):
        """tools43②：沿用车道.py 说沿用的场景不交给 并行测试.py；XIYOU_REUSE_LANE=0 不调它、照跑。"""
        self.put(UI / 'shop.gd', 'class_name XShopScene\n# 2\n')
        rc, out, ran = self.check('--affected', self.base, env={'FAKE_REUSE_DROP': 'xiyou_shop.tscn'})
        self.assertEqual(rc, 0, out)
        self.assertIn('沿用车道.py', self.names(ran))
        runner = next(l for l in ran if l.startswith('并行测试.py')).split()
        self.assertEqual(runner[3:], ['--reuse', 'xiyou_event_compare.tscn'])
        rc, out, ran = self.check('--affected', self.base, env={'FAKE_REUSE_DROP': 'xiyou_shop.tscn xiyou_event_compare.tscn'})
        self.assertEqual(rc, 0, out)
        self.assertNotIn('并行测试.py', self.names(ran))                    # 全沿用：不导入、不跑
        self.assertIn('跳过导入与测试', out)
        rc, out, ran = self.check('--affected', self.base, env={'FAKE_REUSE_DROP': 'xiyou_shop.tscn', 'XIYOU_REUSE_LANE': '0'})
        self.assertNotIn('沿用车道.py', self.names(ran))
        runner = next(l for l in ran if l.startswith('并行测试.py')).split()
        self.assertEqual(runner[3:], ['--reuse', 'xiyou_event_compare.tscn', 'xiyou_shop.tscn'])
        rc, out, ran = self.check('--oracle')                               # 全量不调
        self.assertNotIn('沿用车道.py', self.names(ran))

    def test_lane_reuse_failure_runs_everything(self):
        self.put(ENV / '沿用车道.py', 'import sys\nsys.exit(3)\n')
        self.put(UI / 'shop.gd', 'class_name XShopScene\n# 2\n')
        rc, out, ran = self.check('--affected', self.base)
        self.assertEqual(rc, 0, out)
        self.assertIn('沿用车道结果判断失败', out)
        runner = next(l for l in ran if l.startswith('并行测试.py')).split()
        self.assertEqual(runner[3:], ['--reuse', 'xiyou_event_compare.tscn', 'xiyou_shop.tscn'])

    def test_cloud_gets_reused_scenes_as_skip(self):
        self.env = dict(self.env, FAKE_REUSE_DROP='xiyou_shop.tscn')
        with open(self.root / '.git/info/exclude', 'a') as f:                # 桩文件不算改动，免得选测整轮
            f.write('cloud_stub.py\ncalls\n')
        rc, out, ran = self.cloud_check(no_upload=True)
        self.assertIn('沿用车道.py', self.names(ran))
        self.assertEqual(rc, 0, out)
        self.assertEqual([l for l in ran if l.startswith('cloud run')], ['cloud run --no-upload --skip xiyou_shop.tscn'])

    def test_static_failure_stops_before_godot(self):
        # 文档与登记检查失败：默认在 Godot 测试前就退出；--keep-going 照旧全跑
        self.put(Path('00_项目管理/坏链接.md'), '[x](不存在.md)\n')
        rc, out, ran = self.check()
        self.assertEqual(rc, 1, out)
        self.assertIn('失效链接', out)
        self.assertIn('未运行 Godot 测试', out)
        self.assertNotIn('并行测试.py', self.names(ran))
        self.assertNotIn('godot', self.names(ran))
        rc, out, ran = self.check('--keep-going')
        self.assertEqual(rc, 1, out)
        self.assertIn('并行测试.py', self.names(ran))
        self.assertIn('有失败项', out)

    def test_failure_summary_lists_scenes_with_logs(self):
        # 哪吒_7 t4 第 1 项：长任务日志里失败项夹在几百行中间，收尾单列每个失败项，Godot 场景带日志路径
        self.put(ENV / '并行测试.py', 'import os, pathlib, sys\npathlib.Path(os.environ["CHECK_FAILED_FILE"]).write_text('
                 '"a.tscn\\t/logs/a.rerun1.log\\nb.tscn\\t/logs/b.log\\n")\nsys.exit(1)\n')
        self.put(ENV / '测试公式程序.py', 'import sys\nsys.exit(1)\n')
        rc, out, _ = self.check()
        self.assertEqual(rc, 1, out)
        summary = out[out.index('== 失败项汇总'):out.index('== Git')].splitlines()
        self.assertEqual(summary, ['== 失败项汇总（3 项）', '  ✗ Godot 场景 a.tscn  日志 /logs/a.rerun1.log',
                                   '  ✗ Godot 场景 b.tscn  日志 /logs/b.log', '  ✗ 公式编译边界失败'])
        self.put(ENV / '并行测试.py', 'import sys\nsys.exit(1)\n')  # 没写出场景（如导入就崩）：仍列一项
        rc, out, _ = self.check()
        self.assertIn('✗ Godot 测试（未写出失败场景', out)
        self.put(ENV / '并行测试.py', 'pass\n')
        self.put(ENV / '测试公式程序.py', 'pass\n')
        rc, out, _ = self.check()
        self.assertEqual(rc, 0, out)
        self.assertNotIn('失败项汇总', out)

    def test_syntax_error_skips_godot_tests(self):
        # tools28：Godot 段先跑 语法检查.py，有 Parse Error 就不排测试队列；CHECK_SYNTAX=0 回到直接跑测试
        self.put(ENV / '语法检查.py', 'import sys\nprint("  ✗ res://x.gd：Parse Error")\nsys.exit(1)\n')
        rc, out, ran = self.check()
        self.assertEqual(rc, 1, out)
        self.assertIn('语法检查不通过', out)
        self.assertIn('res://x.gd：Parse Error', out)
        self.assertNotIn('并行测试.py', self.names(ran))
        rc, out, ran = self.check(env={'CHECK_SYNTAX': '0'})
        self.assertNotIn('语法检查.py', self.names(ran))
        self.assertIn('并行测试.py', self.names(ran))

    def test_prose_brackets_are_not_links_but_real_breaks_are(self):
        # 唐僧_13 2026-10-26：表格正文「变身[萧萧](a)」被当成失效链接卡住合并；只放过 1～2 个字符、不含 / 与 . 的目标
        self.put(Path('00_项目管理/表格.md'), '| 变身[萧萧](a) | [甲](Ab) |\n')
        rc, out, _ = self.check('--affected', self.base)
        self.assertEqual(rc, 0, out)
        for bad in ['不存在', 'abc', 'a.md', './a', 'x/y']:
            self.put(Path('00_项目管理/表格.md'), '[甲](%s)\n' % bad)
            rc, out, _ = self.check('--affected', self.base)
            self.assertEqual(rc, 1, bad)
            self.assertIn('失效链接 00_项目管理/表格.md -> ' + bad, out)

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
    # 满载时偶发 1 项失败、单跑复现不了（哪吒_10）：失败时把用例名和末行原因单独打出，检查.sh 留日志当证据（tools22）
    for case, trace in result.failures + result.errors:
        lines = [x for x in trace.strip().splitlines() if x.strip()]
        print('FAILED_CASE=%s\t%s' % (case.id().rsplit('.', 2)[-2] + '.' + case.id().rsplit('.', 1)[-1], lines[-1][:240] if lines else ''))
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
