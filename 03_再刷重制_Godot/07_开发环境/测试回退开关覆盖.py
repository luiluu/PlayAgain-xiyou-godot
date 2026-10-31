#!/usr/bin/env python3
"""回退开关覆盖.py：登记表解析、声明定位、测试里找回退赋值、豁免清单与 检查.sh 接线。夹具只用临时目录；最后一组读真实工程（只读）。"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
TOOL = HERE / '回退开关覆盖.py'
import importlib.util
spec = importlib.util.spec_from_file_location('rollback', TOOL)
rb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rb)

HEAD = '| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n'


def row(oid, restore, status='待用户决定'):
    return '| %s | 位置 | 原版 | 优化 | 理由 | %s | cc | %s |\n' % (oid, restore, status)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='xiyou_rollback_')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / rb.PROJECT
        self.allow = self.root / 'allow.json'

    def put(self, rel, text):
        p = self.project / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding='utf-8')

    def register(self, *rows):
        p = self.root / rb.REGISTER
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text('# 优化登记\n\n' + HEAD + ''.join(rows), encoding='utf-8')

    def run_tool(self, *args, env=None):
        r = subprocess.run([sys.executable, str(TOOL), '--root', str(self.root), '--allow', str(self.allow), *args],
                           capture_output=True, text=True, env=dict(os.environ, **(env or {})))
        return r.returncode, r.stdout + r.stderr

    def by_key(self):
        return {s['key']: s for s in rb.scan(self.root)['switches']}


class ParseTests(unittest.TestCase):
    def test_restore_column_forms(self):
        self.assertEqual(rb.parse_switches('`XPetCapture.FLEE_ALIVE_ONLY = false`'), [('XPetCapture', 'FLEE_ALIVE_ONLY', 'false')])
        self.assertEqual(rb.parse_switches('`POISON_HELP_NEAR := false`（照原版）'), [(None, 'POISON_HELP_NEAR', 'false')])
        self.assertEqual(rb.parse_switches('`XHelpCard.MIN_FONT` 设 0'), [('XHelpCard', 'MIN_FONT', '0')])
        self.assertEqual(rb.parse_switches('`MVInterpreter.TRANSFER_FIX` 设 `{}`；再 --update-baseline'), [('MVInterpreter', 'TRANSFER_FIX', '{}')])
        self.assertEqual(rb.parse_switches('`XAlienWorkshop.list_indent_quirk = true`（第 2 个起右推 7）'), [('XAlienWorkshop', 'list_indent_quirk', 'true')])
        self.assertEqual(rb.parse_switches('`XAchievement.GAIN_ONLY`、`BEFORE_REDIRECT`、`SAVE_NOW` 分别设 false'),
                         [('XAchievement', 'GAIN_ONLY', 'false'), ('XAchievement', 'BEFORE_REDIRECT', 'false'), ('XAchievement', 'SAVE_NOW', 'false')])
        self.assertEqual(rb.parse_switches('①`MVInterpreter.seal_check_fix` 设 `{}`；②`MVInterpreter.removed_gate_fix` 设 `{}`'),
                         [('MVInterpreter', 'seal_check_fix', '{}'), ('MVInterpreter', 'removed_gate_fix', '{}')])
        self.assertEqual(rb.parse_switches('`XGear._pool_next` 越界分支改为返回 NAN'), [])
        self.assertEqual(rb.parse_switches('无开关：回退就是退出游戏'), [])


class ScanTests(Fixture):
    def test_coverage_literal_dynamic_and_gap(self):
        self.put('core/pets.gd', 'class_name XPets\nstatic var BOOK_FIX := true\nstatic var CLAMP := true\nstatic var EXACT := true\n')
        self.put('ui/card.gd', 'class_name XCard\nconst NEAR := true\n')
        self.put('tests/a.gd', 'func t():\n\tXPets.BOOK_FIX = false\n\tif XPets.CLAMP == false: pass\n\t# XPets.CLAMP = false\n'
                               '\tfor on in [true, false]:\n\t\tXPets.EXACT = on\n')
        self.register(row('O-001', '`XPets.BOOK_FIX = false`'), row('O-002', '`XPets.CLAMP` 设 false'),
                      row('O-003', '`XPets.EXACT = false`'), row('O-004', '`XCard.NEAR` 设 false'))
        got = self.by_key()
        self.assertEqual(got['O-001 XPets.BOOK_FIX']['status'], '覆盖')
        self.assertEqual(got['O-001 XPets.BOOK_FIX']['where'], ['tests/a.gd:2'])
        self.assertEqual(got['O-002 XPets.CLAMP']['status'], '缺口')  # 比较与注释不算
        self.assertEqual(got['O-003 XPets.EXACT']['status'], '人工确认')
        self.assertEqual((got['O-004 XCard.NEAR']['status'], got['O-004 XCard.NEAR']['kind']), ('缺口', 'const'))
        rc, out = self.run_tool()
        self.assertEqual(rc, 0, out)  # 默认只警告
        self.assertIn('缺口 O-002 XPets.CLAMP = false', out)
        self.assertIn('O-004 XCard.NEAR = false（ui/card.gd；const，测试改不了', out)
        self.assertIn('人工确认 O-003 XPets.EXACT', out)
        self.assertEqual(self.run_tool('--strict')[0], 1)

    def test_set_call_and_value_must_match_rollback(self):
        self.put('core/m.gd', 'class_name XMap\nstatic var FIX := {"a": 1}\nstatic var FONT := 16\n')
        self.put('tests/b.gd', 'func t():\n\tXMap.set("FIX", {})\n\tXMap.FONT = 16\n\tXMap.FONT = 160\n')
        self.register(row('O-010', '`XMap.FIX` 设 `{}`'), row('O-011', '`XMap.FONT` 设 0'))
        got = self.by_key()
        self.assertEqual(got['O-010 XMap.FIX']['status'], '覆盖')
        self.assertEqual(got['O-011 XMap.FONT']['status'], '缺口')  # 设成别的字面量不算回退

    def test_status_filter(self):
        self.put('core/m.gd', 'class_name XMap\nstatic var A := true\n')
        self.register(row('O-020', '`XMap.A = false`', '已撤销：改照原版'), row('O-021', '`XMap.A = false`', '暂缓（用户）'),
                      row('O-022', '`XMap.A = false`', '恢复原版'), row('O-023', '`XMap.A = false`', '保留（用户 2026-10-18）'),
                      row('O-024', '`XMap.A = false`', '待用户确认'), row('O-025', '`XMap.A = false`', '建议，等用户定（默认照原版）'))
        self.assertEqual(sorted(s['id'] for s in rb.scan(self.root)['switches']), ['O-023', 'O-024'])

    def test_unparsed_rows_listed_not_guessed(self):
        self.put('core/a.gd', 'class_name XA\nstatic var DUP := true\nconst MIN_ORIG := -9\n')
        self.put('core/b.gd', 'class_name XB\nstatic var DUP := true\n')
        p = self.root / rb.REGISTER
        self.register(row('O-030', '`DUP = false`'), row('O-031', '`XA.MISSING = false`'),
                      row('O-032', '`XA.TABLE` 删一条'), row('O-033', '下限回到 `MIN_ORIG`'))
        p.write_text(p.read_text() + '| O-034 | 少列 | x |\n', encoding='utf-8')
        res = rb.scan(self.root)
        why = {u['id']: u['why'] for u in res['unparsed']}
        self.assertIn('2 处声明', why['O-030'])
        self.assertIn('找不到 XA.MISSING', why['O-031'])
        self.assertIn('TABLE', why['O-032'])
        self.assertIn('MIN_ORIG', why['O-033'])
        self.assertIn('列数', why['O-034'])
        self.assertEqual(res['switches'], [])
        rc, out = self.run_tool('--strict')
        self.assertEqual(rc, 0, out)  # 解析不了只列出，不算缺口
        self.assertIn('解析不了 O-032', out)

    def test_class_qualifier_picks_declaring_file(self):
        self.put('core/a.gd', 'class_name XA\nstatic var FLAG := true\n')
        self.put('core/b.gd', 'class_name XB\nconst FLAG := true\n')
        self.register(row('O-040', '`XA.FLAG = false`'))
        s = self.by_key()['O-040 XA.FLAG']
        self.assertEqual((s['file'], s['kind']), ('core/a.gd', 'static var'))

    def test_allowlist_suppresses_and_reports_stale(self):
        self.put('core/m.gd', 'class_name XMap\nstatic var A := true\nstatic var B := true\n')
        self.put('tests/t.gd', 'func t():\n\tXMap.B = false\n')
        self.register(row('O-050', '`XMap.A = false`'), row('O-051', '`XMap.B = false`'), row('O-052', '`XMap.TABLE` 删一条'))
        self.allow.write_text(json.dumps({'known': {'O-050 XMap.A': '待派', 'O-051 XMap.B': '旧缺口', 'O-052': '删条目'}}))
        rc, out = self.run_tool('--strict')
        self.assertEqual(rc, 0, out)
        self.assertNotIn('⚠', out)
        self.assertNotIn('? 解析不了', out)
        self.assertIn('解析不了 1 行', out)
        self.assertIn('O-051 XMap.B 已有测试设回退值，可从 回退开关豁免.json 删掉', out)
        self.assertIn('缺口（豁免） O-050 XMap.A', self.run_tool('--all')[1])

    def test_switch_off(self):
        self.register(row('O-060', '`XMap.A = false`'))  # 工程都没有：关掉时不该去读
        self.allow.write_text(json.dumps({'enabled': False, 'known': {}}))
        rc, out = self.run_tool('--strict')
        self.assertEqual(rc, 0, out)
        self.assertIn('已关', out)
        self.allow.write_text(json.dumps({'known': {}}))
        rc, out = self.run_tool('--strict', env={'XIYOU_ROLLBACK_CHECK': '0'})
        self.assertEqual(rc, 0, out)
        self.assertIn('已关', out)


class RealProjectTests(unittest.TestCase):
    """真实工程只读：能跑通、G3 那 5 个回退支认得出（缺口或已覆盖）。"""

    def test_real_register_has_no_unlisted_gap(self):
        r = subprocess.run([sys.executable, str(TOOL), '--json'], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        res = json.loads(r.stdout)
        # 新缺口只在 检查.sh 里警告，这里不挡（总装七：先只警告不挡）；只核真实登记能解析、G3 那 5 个认得出
        self.assertGreater(len(res['switches']), 50)
        gaps = {s['id'] for s in res['switches'] if s['status'] == '缺口'}
        for oid in ['O-101', 'O-102', 'O-103', 'O-107', 'O-117']:
            if oid in gaps:
                continue
            # 车道补上回退支测试后这里会变成「覆盖」，那时也要从豁免里删
            self.assertTrue(any(s['id'] == oid and s['status'] == '覆盖' for s in res['switches']), oid)

    def test_check_sh_wiring(self):
        text = (HERE / '检查.sh').read_text(encoding='utf-8')
        self.assertIn('回退开关覆盖.py" || true', text)  # 只警告，不挡
        self.assertIn('测试回退开关覆盖.py', text)


if __name__ == '__main__':
    unittest.main(verbosity=1)
