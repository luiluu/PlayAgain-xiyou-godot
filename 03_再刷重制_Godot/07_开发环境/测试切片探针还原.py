#!/usr/bin/env python3
"""slice_probe 测量不改目标状态的回归（2026-10-25 哪吒）：在真实参照引擎里只跑难度 1 的敌群 157、158、854。

敌群 157 的敌人 160 技能 857「净化之雷」custom 公式有副作用，会把被测角色 9 的生命打到 0；探针没还原时，之后拿角色 9 当目标
的敌人行都在 0 血下算（reach4 敌人 947 技能 5557「b.hp*0.99」量出 0，Godot 满血算 467.775）。这里断言：
- 857 那行量完、角色 9 在下一个敌群仍是满血：158 的 4013、854 的 5557 都不是 0；
- 5557 的取整前值 = 角色 9 满血 × 0.99 × 元素与其余修正后的数，与只跑敌群 854 时完全相同（顺序无关）。
产物写到临时目录（XIYOU_SLICE_OUT），不碰同步用的 .sandbox/slice；手动运行的种子副本由 manual_sandbox 管理。
约 1～2 分钟（先建全部角色），不接进 检查.sh 的工具回归；改 slice_probe 测量口径时手动跑。
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ORACLE = Path(__file__).resolve().parents[1] / '03_转换工具/mv_oracle'


def probe(units):
    with tempfile.TemporaryDirectory(prefix='xiyou_slice_probe_') as out:
        env = dict(os.environ, XIYOU_SLICE_OUT=out, XIYOU_PROBE_UNITS=json.dumps(units))
        p = subprocess.run(['node', 'slice_probe.cjs', '1'], cwd=ORACLE, env=env, capture_output=True, text=True, timeout=900)
        if p.returncode:
            raise AssertionError('slice_probe 失败：' + (p.stdout + p.stderr)[-1500:])
        return json.loads((Path(out) / 'slice_d1.json').read_text())


def enemy_rows(data, troop):
    return {r['skill']: r for r in data['damage'] if r.get('troop') == troop and r.get('enemy') is not None}


class SliceProbeRestoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.together = probe(['157', '158', '854'])
        cls.alone = probe(['854'])

    def test_side_effect_formula_does_not_leak_into_later_rows(self):
        self.assertNotEqual(enemy_rows(self.together, 158)[4013]['value'], 0)
        self.assertNotEqual(enemy_rows(self.together, 854)[5557]['value'], 0)

    def test_rows_do_not_depend_on_which_troops_ran_before(self):
        self.assertEqual(enemy_rows(self.together, 854), enemy_rows(self.alone, 854))


if __name__ == '__main__':
    result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
    passed = result.testsRun - len(result.failures) - len(result.errors)
    print('TEST_RESULT=' + json.dumps({'passed': passed, 'total': result.testsRun}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
