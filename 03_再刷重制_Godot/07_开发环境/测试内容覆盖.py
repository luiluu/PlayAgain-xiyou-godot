#!/usr/bin/env python3
"""内容覆盖检查（03_转换工具/内容覆盖检查.py）的回归：缺素材、无效引用、未翻译、出切片、未对照与基线比较。"""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('coverage_tool', HERE.parent / '03_转换工具/内容覆盖检查.py')
cov = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cov)

INTERP = '''
func _execute(c):
	match c.code:
		101:
			pass
		117, 201:
			pass
		301:
			pass

func _plugin_command(line):
	match args[0]:
		"Difficulty":
			pass
		"ProhibitHangUp", "EnableHangUp":
			pass

func other():
	pass
'''


# 战斗事件解释器（共用核心＋battle_event_runner）：认 333，不认地图宿主指令 201
BATTLE = '''
func _execute(c):
	match c.code:
		101:
			pass
		117:
			pass

func _execute_env(c):
	match int(c.code):
		333:
			pass
'''


def cmd(code, *params):
    return {'code': code, 'parameters': list(params)}


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xiyou_coverage_fixture_')
        g = self.gen = Path(self.tmp.name) / 'generated'
        for d in ['maps', 'db', 'oracle', 'img/characters', 'img/faces', 'img/sv_enemies', 'img/tilesets']:
            (g / d).mkdir(parents=True)
        (g / 'img/characters/hero.png').write_bytes(b'x')
        (g / 'img/faces/hero.png').write_bytes(b'x')
        (g / 'img/sv_enemies/slime.png').write_bytes(b'x')
        db = {'CommonEvents': [None, {'id': 1, 'list': [cmd(101, 'nobody', 0, 0, 2), cmd(0)]}],
              'Troops': [None, {'id': 1, 'members': [{'enemyId': 1}]}],
              'Enemies': [None, {'id': 1, 'battlerName': 'slime'}],
              'Tilesets': [None, {'id': 1, 'tilesetNames': ['']}]}
        for name, rows in db.items():
            (g / 'db' / (name + '.json')).write_text(json.dumps(rows))
        page = {'image': {'characterName': 'hero'}, 'moveRoute': {'list': []},
                'list': [cmd(101, 'hero', 0, 0, 2), cmd(117, 1), cmd(117, 9), cmd(301, 0, 1), cmd(223, [0, 0, 0, 0], 60, True),
                         cmd(201, 0, 99, 1, 1, 2, 0), cmd(356, 'Difficulty SetID 2'), cmd(356, 'ShopInventory Group A'), cmd(108, '注释'), cmd(0)]}
        (g / 'maps/Map001.json').write_text(json.dumps({'tilesetId': 1, 'encounterList': [], 'events': [None, {'id': 1, 'pages': [page]}, {'id': 2, 'pages': [{'image': {'characterName': ''}, 'moveRoute': {'list': []}, 'list': [cmd(0)]}]}]}))
        (g / 'oracle/events.json').write_text(json.dumps({'cases': [{'id': 'm1e1p0'}]}))
        self.baseline = Path(self.tmp.name) / 'baseline.json'

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, *args):
        out = io.StringIO()
        interp = Path(self.tmp.name) / 'mv_interpreter.gd'
        interp.write_text(INTERP)
        battle = Path(self.tmp.name) / 'battle_event_runner.gd'
        battle.write_text(BATTLE)
        with mock.patch.object(cov, 'BASELINE', self.baseline), mock.patch.object(cov, 'REPORT', Path(self.tmp.name) / 'report.json'), \
             mock.patch.object(cov, 'INTERP_FILES', [interp]), mock.patch.object(cov, 'BATTLE_FILES', [battle]), contextlib.redirect_stdout(out):
            rc = cov.main(['--generated', str(self.gen), *args])
        return rc, out.getvalue()

    def report(self):
        return json.loads((Path(self.tmp.name) / 'report.json').read_text())

    def test_finds_each_kind(self):
        self.run_tool()
        issues = self.report()['issues']
        self.assertIn('无效引用|Map001/EV001/p1|公共事件 9', issues)
        self.assertIn('未翻译|Map001/EV001/p1|指令 223', issues)
        self.assertIn('未翻译|Map001/EV001/p1|插件指令 ShopInventory', issues)
        self.assertIn('缺素材|CE0001|img/faces/nobody', issues)          # 调到的公共事件也查
        self.assertFalse(any('Difficulty' in i or '指令 108' in i or '指令 117' in i for i in issues))
        pages = {p['page']: p for p in self.report()['pages']}
        self.assertEqual(pages['Map001/EV001/p1']['status'], '缺依赖')
        self.assertIn('出切片：传送到 Map099', pages['Map001/EV001/p1']['notes'])
        self.assertIn('未对照：事件对照里没有这一页', pages['CE0001']['notes'])
        self.assertIn('空页：页里没有指令，无需对照', pages['Map001/EV002/p1']['notes'])   # 空页不算未对照

    def test_battle_commands_only_in_battle_context(self):
        # 内容覆盖误报（悟空 pending1）：只经战斗技能 code44 调到的公共事件按战斗事件解释器的指令表查；
        # 地图可达（地图页 117、菜单也能用的技能）的仍按地图解释器查，战斗里也不认地图宿主指令
        ce = self.gen / 'db/CommonEvents.json'
        rows = json.loads(ce.read_text())
        rows += [{'id': 2, 'list': [cmd(333, 0, 0, 1), cmd(117, 6), cmd(0)]}, {'id': 3, 'list': [cmd(333, 0, 0, 1), cmd(0)]},
                 {'id': 4, 'list': [cmd(333, 0, 0, 1), cmd(0)]}, {'id': 5, 'list': [cmd(201, 0, 1, 1, 1, 2, 0), cmd(0)]},
                 {'id': 6, 'list': [cmd(333, 0, 0, 1), cmd(0)]}]
        ce.write_text(json.dumps(rows))
        skill = lambda i, occ, c: {'id': i, 'occasion': occ, 'effects': [{'code': 44, 'dataId': c}]}
        (self.gen / 'db/Skills.json').write_text(json.dumps([None, skill(1, 1, 2), skill(2, 0, 3), skill(3, 1, 5)]))
        (self.gen / 'manifest.json').write_text(json.dumps({'slice': {'commonEvents': [2, 3, 5]}}))
        m = json.loads((self.gen / 'maps/Map001.json').read_text())
        m['events'][1]['pages'][0]['list'].insert(0, cmd(117, 4))
        (self.gen / 'maps/Map001.json').write_text(json.dumps(m))
        self.run_tool()
        issues = self.report()['issues']
        self.assertFalse(any(i.startswith('未翻译|CE0002|') or i.startswith('未翻译|CE0006|') for i in issues), issues)  # 战斗专用，含其 117 子事件
        self.assertIn('未翻译|CE0003|指令 333', issues)   # 场合「随时」：菜单里用时在地图上跑
        self.assertIn('未翻译|CE0004|指令 333', issues)   # 地图页调用
        self.assertIn('未翻译|CE0005|指令 201', issues)   # 战斗里不认地图宿主指令

    def test_baseline_gates_new_issues(self):
        self.assertEqual(self.run_tool('--check')[0], 1)
        self.assertEqual(self.run_tool('--update-baseline')[0], 0)
        self.assertEqual(self.run_tool('--check')[0], 0)
        (self.gen / 'img/sv_enemies/slime.png').unlink()                   # 新缺一张敌人图
        rc, out = self.run_tool('--check')
        self.assertEqual(rc, 1)
        self.assertIn('img/sv_enemies/slime', out)


if __name__ == '__main__':
    result = unittest.main(exit=False, verbosity=1).result
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    sys.exit(0 if result.wasSuccessful() else 1)
