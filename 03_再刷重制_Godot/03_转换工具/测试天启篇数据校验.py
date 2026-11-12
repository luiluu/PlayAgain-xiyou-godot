#!/usr/bin/env python3
"""天启篇数据校验.py 的回归：七印祭坛四张表的检查和跨表引用。

  python3 03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py

正例：对工程里的真表跑一遍全过（main 退出码 0）。
反例：每条新规则一个夹具：把真表抄进临时目录、改坏一处，把脚本的 DATA_DIR（和 TIANQI_GEAR_GD）指过去，确认能报出来。
"""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('tianqi_check', HERE / '天启篇数据校验.py')
chk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(chk)

REAL_DIR = chk.DATA_DIR
REAL_GD = chk.TIANQI_GEAR_GD
NAMES = ('gear', 'drop', 'dragon', 'altar')


def run(fn, *a):
    """跑检查函数，返回 (是否通过, 打印内容)。"""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        ok = fn(*a)
    return ok, buf.getvalue()


class RealTables(unittest.TestCase):
    def test_real_tables_pass(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = chk.main([])
        self.assertEqual(code, 0, buf.getvalue())
        for n in NAMES:
            self.assertIn('qiyin_%s.json 规则自检：通过' % n, buf.getvalue())
        self.assertIn('跨表引用：通过', buf.getvalue())

    def test_order_parsed_from_gd(self):
        order = chk.tianqi_gear_order()
        self.assertIn(17, order)
        self.assertIn(3, order)


class QiyinFixture(unittest.TestCase):
    """临时目录里放四张真表的副本，各用例改坏一处。"""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='qiyin_check_'))
        self.t = {n: json.loads((REAL_DIR / ('qiyin_%s.json' % n)).read_text(encoding='utf-8')) for n in NAMES}
        chk.DATA_DIR = self.tmp
        chk.TIANQI_GEAR_GD = REAL_GD

    def tearDown(self):
        chk.DATA_DIR = REAL_DIR
        chk.TIANQI_GEAR_GD = REAL_GD
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, skip=()):
        for n, t in self.t.items():
            if n not in skip:
                (self.tmp / ('qiyin_%s.json' % n)).write_text(json.dumps(t, ensure_ascii=False), encoding='utf-8')

    def fails(self, name, needle, skip=()):
        """name 是表名或 'refs'；断言检查不过且输出里有 needle。"""
        self.write(skip)
        if name == 'refs':
            ok, out = run(chk.check_qiyin_refs, None)
        else:
            ok, out = run(chk.check_qiyin, name)
        self.assertFalse(ok, out)
        self.assertIn(needle, out)
        return out

    def passes(self, name):
        self.write()
        ok, out = run(chk.check_qiyin_refs, None) if name == 'refs' else run(chk.check_qiyin, name)
        self.assertTrue(ok, out)

    # 夹具本身没坏
    def test_copy_passes(self):
        for n in NAMES:
            self.passes(n)
        self.passes('refs')

    # 表不在就跳过、算通过
    def test_missing_table_skips(self):
        for n in NAMES:
            ok, out = run(chk.check_qiyin, n)
            self.assertTrue(ok)
            self.assertIn('跳过', out)
        ok, out = run(chk.check_qiyin_refs, None)
        self.assertTrue(ok)
        self.assertIn('跳过', out)

    # 不认识的键不报错
    def test_unknown_keys_ok(self):
        for n, t in self.t.items():
            t['future_field'] = {'whatever': 'x', 'seal': 'qing', 'part': 'tail'}
        self.t['gear']['sets']['bai']['new_thing'] = True
        self.t['drop']['boss_set']['new_param'] = 'x'
        for n in NAMES:
            self.passes(n)
        self.passes('refs')

    # ---- 数字避开 4，各表 nice_number_exempt 豁免 ----
    def test_four_gear(self):
        self.t['gear']['set_rule']['level'] = 84
        self.fails('gear', '设计数值不带 4')

    def test_four_drop(self):
        self.t['drop']['boss_set']['pity_misses'] = 24
        self.fails('drop', '/boss_set/pity_misses=24')

    def test_four_dragon(self):
        self.t['dragon']['fight']['max_hp_jianxian'] = 2400000
        self.fails('dragon', '设计数值不带 4')

    def test_four_altar(self):
        self.t['altar']['keys']['first_open'] = 4
        self.fails('altar', '/keys/first_open=4')

    def test_four_exempt_by_own_table(self):
        self.t['altar']['keys']['first_open'] = 4
        self.t['altar']['nice_number_exempt'].append('first_open')
        self.passes('altar')
        # 别的表的豁免不算：drop 没豁免 order
        self.t['drop']['restless']['order'] = 4
        self.fails('drop', '/restless/order=4')

    # ---- 印键只有七个 ----
    def test_seal_key_gear(self):
        self.t['gear']['weapons'][0]['seal'] = 'qing'
        self.fails('gear', 'weapons.seal 里有 qing')

    def test_seal_key_drop(self):
        self.t['drop']['floor_first_kill']['31'] = ['bai', 'qing']
        self.fails('drop', 'floor_first_kill.31 里有 qing')

    def test_seal_key_dragon(self):
        self.t['dragon']['fight']['reveal_order'][6] = 'qing'
        self.fails('dragon', 'fight.reveal_order 里有 qing')

    def test_seal_key_altar(self):
        self.t['altar']['unlock']['mo']['after_seals'].append('qing')
        self.fails('altar', 'unlock.mo.after_seals 里有 qing')

    # ---- 部位键只有六个 ----
    def test_part_key_gear(self):
        self.t['gear']['sets']['hong']['pieces'][0]['part'] = 'tail'
        self.fails('gear', 'sets.hong.pieces 里有 tail')

    def test_part_key_drop(self):
        self.t['drop']['parts'].append('tail')
        self.fails('drop', '部位键只有')

    def test_part_key_dragon(self):
        self.t['dragon']['reward']['set_parts'][0] = 'neck'
        self.fails('dragon', 'reward.set_parts 里有 neck')

    def test_part_key_altar(self):
        self.t['altar']['names']['parts']['tail'] = '尾巴'
        self.fails('altar', 'names.parts 里有 tail')

    # ---- 几率在 0～1 ----
    def test_chance_drop_by_difficulty(self):
        self.t['drop']['boss_weapon']['chance']['zhengdao'] = 1.5
        self.fails('drop', '几率在 0～1：/boss_weapon/chance')

    def test_chance_dragon_negative(self):
        self.t['dragon']['reward']['weapon_chance'] = -0.1
        self.fails('dragon', '几率在 0～1：/reward/weapon_chance')

    def test_chance_altar_percent_written(self):
        self.t['altar']['keys']['refund_chance'] = 33
        self.fails('altar', '几率在 0～1：/keys/refund_chance')

    # ---- 权重非负且不全为 0 ----
    def test_weights_negative(self):
        self.t['gear']['grade_weights']['fine'] = -1
        self.fails('gear', '权重非负：/grade_weights')

    def test_weights_all_zero(self):
        self.t['drop']['grades']['weights'] = {'putong': 0, 'shangpin': 0, 'ji': 0}
        self.fails('drop', '权重不全为 0：/grades/weights')

    def test_single_weight_negative(self):
        self.t['drop']['boss_set']['owned_part_weight'] = -0.5
        self.fails('drop', '权重非负：/boss_set/owned_part_weight')

    # ---- qiyin_gear：类型号对 ORDER、件数 ----
    def test_part_etype_not_in_order(self):
        for p in self.t['gear']['parts']:
            if p['key'] == 'head':
                p['etype'] = 11
        self.fails('gear', '部位类型号在 tianqi_gear.gd 的 ORDER 里：head')

    def test_piece_etype_differs_from_part(self):
        self.t['gear']['sets']['bai']['pieces'][0]['etype'] = 9
        self.fails('gear', '套装件类型号同部位：bai head')

    def test_order_read_from_gd(self):
        gd = self.tmp / 'tianqi_gear.gd'
        gd.write_text('const ORDER := [1, 2, 3, 4, 6, 8, 5, 7, 9, 10, 13, 16]\n', encoding='utf-8')
        chk.TIANQI_GEAR_GD = gd
        self.fails('gear', '神器类型号在 ORDER 里')

    def test_seven_sets(self):
        del self.t['gear']['sets']['mo']
        self.fails('gear', '套装七套')

    def test_six_pieces(self):
        self.t['gear']['sets']['hui']['pieces'].pop()
        self.fails('gear', '套装 hui 有 6 件')

    def test_thirteen_weapons(self):
        self.t['gear']['weapons'].pop()
        self.fails('gear', '毕业武器 13 把')

    def test_five_artifacts(self):
        a = copy.deepcopy(self.t['gear']['artifacts'][0])
        a['key'] = 'extra'
        self.t['gear']['artifacts'].append(a)
        self.fails('gear', '神器 5 件')

    # ---- 跨表引用 ----
    def test_ref_set_missing(self):
        del self.t['gear']['sets']['zhen']
        self.fails('refs', 'qiyin_drop.json 的套装在 qiyin_gear 的 sets 里')

    def test_ref_seal_missing(self):
        self.t['gear']['seals'] = [s for s in self.t['gear']['seals'] if s['key'] != 'mo']
        out = self.fails('refs', 'qiyin_altar.json 的印在 qiyin_gear 的 seals 里')
        self.assertIn('qiyin_dragon.json 的印', out)

    def test_ref_part_missing(self):
        self.t['gear']['parts'] = [p for p in self.t['gear']['parts'] if p['key'] != 'feet']
        out = self.fails('refs', 'qiyin_drop.json 的部位在 qiyin_gear 的 parts 里')
        self.assertIn('qiyin_dragon.json 的部位', out)
        self.assertIn('qiyin_altar.json 的部位', out)

    def test_ref_artifact_drop(self):
        self.t['drop']['artifact']['keys'].append('nope')
        self.fails('refs', 'qiyin_drop.json 的神器在 qiyin_gear 的 artifacts 里')

    def test_ref_artifact_dragon(self):
        self.t['dragon']['reward']['artifacts'][0] = 'nope'
        self.fails('refs', 'qiyin_dragon.json 的神器在 qiyin_gear 的 artifacts 里')

    def test_ref_weapon_class_unknown(self):
        self.t['drop']['weapon_classes']['bai'].append('鞭')
        self.fails('refs', 'qiyin_drop.json 的武器类型在 qiyin_gear 的 weapon_types 里')

    def test_ref_weapon_class_vs_school(self):
        self.t['drop']['weapon_classes']['bai'] = ['剑', '斧']
        self.fails('refs', 'qiyin_drop.json 的武器类型同 qiyin_gear 的流派')

    def test_ref_skips_missing_other_tables(self):
        self.t['drop']['artifact']['keys'].append('nope')
        self.write(skip=('drop',))
        ok, out = run(chk.check_qiyin_refs, None)
        self.assertTrue(ok, out)


if __name__ == '__main__':
    unittest.main()
