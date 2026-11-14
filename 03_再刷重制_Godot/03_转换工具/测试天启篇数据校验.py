#!/usr/bin/env python3
"""天启篇数据校验.py 的回归：七印祭坛四张表的检查和跨表引用；第三批六张表（reforge、alien_gear、abyss_shelves、qiyin_equip、qiyin_show、qiyin_dragon_run）。

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
BATCH3 = ('reforge.json', 'alien_gear.json', 'abyss_shelves.json', 'qiyin_equip.json', 'qiyin_show.json', 'qiyin_dragon_run.json')
REFS3 = ('affix_table.json', 'rewards.json', 'qiyin_gear.json')  # 第三批跨表要读的参照表


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
        for f in BATCH3:
            self.assertIn('%s 规则自检：通过' % f, buf.getvalue())

    def test_quality_keys_parsed_from_gd(self):
        q = chk.quality_keys()
        self.assertEqual(len(q), 7)
        self.assertIn('buxiu', q)

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


def _set(path, value):
    """返回一个改坏函数：按路径（键或下标）把那一处改成 value；value 是 DEL 就删掉。"""
    def f(t):
        for k in path[:-1]:
            t = t[k]
        if value is DEL:
            del t[path[-1]]
        else:
            t[path[-1]] = value
    return f


DEL = object()


def _seq(*fns):
    def f(t):
        for fn in fns:
            fn(t)
    return f


# (表, 改坏法, 输出里应有的字)。每条规则一个反例；表名不带 .json；'ref:xxx' 表示改的是参照表 xxx。
BATCH3_CASES = [
    # reforge.json
    ('reforge', _set(['costs', 1], 3400), '设计数值不带 4：/costs/1=3400'),
    ('reforge', _set(['costs'], []), 'costs 是非空列表'),
    ('reforge', _set(['costs', 0], -1), 'costs 都是非负整数'),
    ('reforge', _set(['costs', 0], 1.5), 'costs 都是非负整数'),
    ('reforge', _set(['costs', 3], 2000), 'costs 随阶不降'),
    ('reforge', _set(['costs'], [1000, 3000, 6000, 10000, 20000]), 'costs 档数不超过 affix_table 的阶数'),
    ('reforge', _set(['allow_rare'], 'no'), 'allow_rare 是布尔'),
    # alien_gear.json
    ('alien_gear', _set(['levels', 'shigu', 'energy'], 4), '设计数值不带 4：/levels/shigu/energy=4'),
    ('alien_gear', _set(['levels', 'shigu', 'rate'], 8), '异化几率在 0～1：shigu'),
    ('alien_gear', _set(['levels', 'qinran', 'energy'], 0), '分解能量是正整数：qinran'),
    ('alien_gear', _set(['levels', 'qinran', 'refund'], -1), '净化退还是非负整数：qinran'),
    ('alien_gear', _set(['levels', 'huaxing', 'refund'], 4 + 2), '净化退还不超过分解能量：huaxing'),
    ('alien_gear', _set(['levels', 'zhongyan', 'name'], ''), '级名非空：zhongyan'),
    ('alien_gear', _set(['levels', 'qinran'], 3), '异化级是字典：qinran'),
    ('alien_gear', _set(['level_order', 3], 'qinran'), 'level_order 不重复'),
    ('alien_gear', lambda t: t['level_order'].append('bogus'), 'level_order 都在 levels 里'),
    ('alien_gear', lambda t: t['level_order'].pop(), 'levels 都排进 level_order'),
    ('alien_gear', _set(['levels', 'huaxing', 'rate'], 0.01), '异化几率随级不降'),
    ('alien_gear', _set(['levels', 'zhongyan', 'energy'], 3), '分解能量随级不降'),
    ('alien_gear', _set(['late_only', 'min_level'], 'bogus'), 'late_only.min_level 在 levels 里'),
    ('alien_gear', _set(['costs', 'reroll'], -1), '工坊花费是非负整数：reroll'),
    ('alien_gear', lambda t: t['effects'].__setitem__('bogus', {'x': 1}), 'effects 的词条在 new_affixes 里：bogus'),
    ('alien_gear', _set(['effects', 'again', 'taken'], -5), 'effects 数值都是非负数：again.taken'),
    ('alien_gear', lambda t: t['effects']['dying']['atk_rate'].pop(), 'effects 分级数组 4 个（同 level_order）：dying.atk_rate'),
    ('alien_gear', _set(['effects', 'venom', 'chance', 3], 150), 'effects 百分比在 0～100：venom.chance'),
    ('alien_gear', _set(['effects', 'again', 'every', 0], 0), 'effects 至少 1：again.every'),
    ('alien_gear', lambda t: t['late_only']['keys'].append('bogus'), 'late_only.keys 在 rewards.json 的 finale.lines 里'),
    ('alien_gear', lambda t: t['new_affixes'].__setitem__('bogus', {}), 'new_affixes 在 rewards.json 的 finale.lines 里'),
    ('ref:rewards', lambda t: t['finale']['lines']['war'].remove('again'), 'new_affixes 在 rewards.json 的 finale.lines 里'),
    # abyss_shelves.json
    ('abyss_shelves', _set(['treasure', 'cost'], 14), '设计数值不带 4：/treasure/cost=14'),
    ('abyss_shelves', _set(['treasure', 'cost'], -10), 'treasure.cost 是非负整数'),
    ('abyss_shelves', _set(['collection', 'rare_cost'], 30), 'collection 稀有价不低于原价'),
    ('abyss_shelves', _set(['treasure', 'layer'], 'epic'), 'treasure.layer 在 affix_table 的 layers 里'),
    ('abyss_shelves', _set(['collection', 'min_tier'], 0), 'collection.min_tier 是正整数'),
    ('abyss_shelves', _set(['collection', 'min_tier'], 9), 'collection.min_tier 在 affix_table 的 tiers 里'),
    ('abyss_shelves', _set(['collection', 'min_quality'], 'shenqi'), 'collection.min_quality 在 QUALITY_KEYS 里'),
    ('abyss_shelves', _set(['treasure'], 'x'), '货架是字典：treasure'),
    # qiyin_equip.json
    ('qiyin_equip', _set(['armor', 'parts', 'head', 'params', 3], 94), '设计数值不带 4：/armor/parts/head/params/3=94'),
    ('qiyin_equip', _set(['quality_legacy'], -1), 'quality_legacy 是非负整数'),
    ('qiyin_equip', _set(['armor', 'atype'], 0), 'armor.atype 是正整数'),
    ('qiyin_equip', _set(['armor', 'any_class'], 1), 'armor.any_class 是布尔'),
    ('qiyin_equip', _set(['weapons', 'bow', 'base_id'], DEL), 'base_id 是正整数：weapons.bow'),
    ('qiyin_equip', lambda t: t['armor']['parts']['feet']['params'].pop(), 'params 是 8 个非负数：armor.parts.feet'),
    ('qiyin_equip', _set(['weapons', 'axe', 'params', 2], -350), 'params 是 8 个非负数：weapons.axe'),
    ('qiyin_equip', _set(['artifact', 'base_id'], '4537'), 'artifact.base_id 是正整数'),
    ('qiyin_equip', lambda t: t['armor']['parts'].__setitem__('tail', t['armor']['parts']['feet']), '部位键只有 head、body、hands、waist、legs、feet：armor.parts 里有 tail'),
    ('qiyin_equip', _set(['names', 'cost'], 3), 'names 是字符串：cost'),
    ('qiyin_equip', _set(['armor', 'parts', 'waist'], DEL), 'qiyin_gear 的部位都有底子'),
    ('ref:qiyin_gear', lambda t: t['parts'].pop(), 'armor.parts 的部位在 qiyin_gear 的 parts 里'),
    ('qiyin_equip', _set(['weapons', 'book'], DEL), 'qiyin_gear 的武器类型都有底子'),
    ('qiyin_equip', lambda t: t['weapons'].__setitem__('whip', t['weapons']['bow']), 'weapons 的类型在 qiyin_gear 的 weapon_types 里'),
    # qiyin_show.json
    ('qiyin_show', _set(['set', 'hold'], 0.4), '设计数值不带 4：/set/hold=0.4'),
    ('qiyin_show', _set(['seals', 'mo'], DEL), 'seals 七印齐全'),
    ('qiyin_show', lambda t: t['seals'].__setitem__('qing', t['seals']['bai']), '印键只有 bai、hong、hei、hui、xun、zhen、mo：seals 里有 qing'),
    ('qiyin_show', _set(['seals', 'hong', 'color'], 'red'), 'hong.color 是 #RRGGBB'),
    ('qiyin_show', _set(['seals', 'hei', 'glyph'], ''), 'hei.glyph 非空'),
    ('qiyin_show', _set(['true_glow'], '#E026'), 'true_glow 是 #RRGGBB'),
    ('qiyin_show', _set(['reveal', 'se'], 5), 'reveal.se 是字符串'),
    ('qiyin_show', _set(['rift', 'fade_out'], -1), 'rift.fade_out 秒数非负'),
    ('qiyin_show', _set(['weapon', 'dim'], 1.5), 'weapon.dim 在 0～1'),
    ('qiyin_show', _set(['true_seal', 'frames'], 0), 'true_seal.frames 是正整数'),
    ('qiyin_show', _set(['art', 'rift'], 'content/rift.png'), 'art.rift 是 res:// 路径'),
    ('ref:qiyin_gear', lambda t: t['seals'].append({'key': 'qing'}), 'qiyin_gear 的印都有演出'),
    # qiyin_dragon_run.json
    ('qiyin_dragon_run', _set(['fight', 'rate', 2], 0.4), '设计数值不带 4：/fight/rate/2=0.4'),
    ('qiyin_dragon_run', _set(['fight', 'troop'], 0), 'fight.troop 是正整数'),
    ('qiyin_dragon_run', _set(['fight', 'shell_enemy'], '238'), 'fight.shell_enemy 是正整数'),
    ('qiyin_dragon_run', _set(['fight', 'extra_actions'], -1), 'fight.extra_actions 是非负整数'),
    ('qiyin_dragon_run', lambda t: t['fight']['rate'].pop(), 'fight.rate 是 8 个正数'),
    ('qiyin_dragon_run', _set(['fight', 'tone', 3], -5), 'fight.tone 是四个数'),
    ('qiyin_dragon_run', _set(['fight', 'name'], ''), 'fight.name 非空'),
    ('qiyin_dragon_run', _set(['fight', 'segment_lock'], 'true'), 'fight.segment_lock 是布尔'),
    ('qiyin_dragon_run', _set(['scenes', 'win'], [['', '七首之龙倒下了。', '多一列']]), 'scenes.win 是 [说话人, 台词] 的列表'),
    ('qiyin_dragon_run', _set(['logs', 'cut'], ''), 'logs.cut 是非空字符串'),
]

# 表自己的 nice_number_exempt 认：加进豁免就不报
BATCH3_EXEMPT = [
    ('qiyin_equip', _set(['quality_legacy'], 14), None),
    ('qiyin_show', _set(['true_seal', 'power'], 4), None),
    ('qiyin_dragon_run', _set(['fight', 'troop'], 241), None),
    ('qiyin_dragon_run', _seq(lambda t: t['nice_number_exempt'].append('rate'), _set(['fight', 'rate', 0], 0.4)), None),
]


class Batch3Fixture(unittest.TestCase):
    """临时目录里放第三批六张表和参照表的真表副本，各用例改坏一处。"""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='tianqi_check3_'))
        chk.DATA_DIR = self.tmp

    def tearDown(self):
        chk.DATA_DIR = REAL_DIR
        shutil.rmtree(self.tmp, ignore_errors=True)

    def copy_all(self):
        return {f: json.loads((REAL_DIR / f).read_text(encoding='utf-8')) for f in BATCH3 + REFS3}

    def write(self, tables):
        for f, t in tables.items():
            (self.tmp / f).write_text(json.dumps(t, ensure_ascii=False), encoding='utf-8')

    def run_all(self):
        """跑第三批六个检查，返回 (都通过, 打印内容)。"""
        buf = io.StringIO()
        ok = True
        with contextlib.redirect_stdout(buf):
            for name, fn in chk.CHECKS:
                if name + '.json' in BATCH3:
                    ok = fn(None) and ok
        return ok, buf.getvalue()

    def test_copy_passes(self):
        self.write(self.copy_all())
        ok, out = self.run_all()
        self.assertTrue(ok, out)
        self.assertEqual(out.count('规则自检：通过'), len(BATCH3), out)

    def test_missing_tables_skip(self):
        ok, out = self.run_all()
        self.assertTrue(ok, out)
        self.assertEqual(out.count('跳过'), len(BATCH3), out)

    def test_missing_ref_tables_skip_cross_checks(self):
        t = self.copy_all()
        t['qiyin_equip.json']['weapons'].pop('book')
        t['alien_gear.json']['late_only']['keys'].append('bogus')
        t['abyss_shelves.json']['treasure']['layer'] = 'epic'
        self.write({f: v for f, v in t.items() if f not in REFS3})
        ok, out = self.run_all()
        self.assertTrue(ok, out)

    def test_unknown_keys_ok(self):
        t = self.copy_all()
        for f in BATCH3:
            t[f]['future_field'] = {'whatever': 'x', 'rate': 9, 'cost': -1}
        t['alien_gear.json']['levels']['qinran']['future'] = 'x'
        t['qiyin_show.json']['seals']['bai']['future'] = -1
        t['qiyin_dragon_run.json']['fight']['future'] = [-1]
        self.write(t)
        ok, out = self.run_all()
        self.assertTrue(ok, out)

    def test_broken_json_fails(self):
        self.write(self.copy_all())
        (self.tmp / 'reforge.json').write_text('{', encoding='utf-8')
        ok, out = self.run_all()
        self.assertFalse(ok)
        self.assertIn('能读表并跑完全部检查', out)

    def test_each_rule_has_counterexample(self):
        for i, (name, mutate, needle) in enumerate(BATCH3_CASES):
            with self.subTest(i=i, table=name, needle=needle):
                t = self.copy_all()
                key = (name[4:] if name.startswith('ref:') else name) + '.json'
                mutate(t[key])
                self.write(t)
                ok, out = self.run_all()
                self.assertFalse(ok, out)
                self.assertIn(needle, out)

    def test_own_exempt_respected(self):
        for i, (name, mutate, _) in enumerate(BATCH3_EXEMPT):
            with self.subTest(i=i, table=name):
                t = self.copy_all()
                mutate(t[name + '.json'])
                self.write(t)
                ok, out = self.run_all()
                self.assertTrue(ok, out)

    def test_exempt_not_borrowed(self):
        # 豁免只认本表的：reforge 没豁免 base_id
        t = self.copy_all()
        t['reforge.json']['base_id'] = 4533
        self.write(t)
        ok, out = self.run_all()
        self.assertFalse(ok, out)
        self.assertIn('/base_id=4533', out)


class SkillReworkGrowth(unittest.TestCase):
    """tiers.growth 成长型名单非空（XTianqiWeakClear 失败即关闭靠它，gpt 复核 P2）。"""

    def _table(self):
        return json.loads((REAL_DIR / 'skill_rework.json').read_text(encoding='utf-8'))

    def test_real_ok(self):
        self.assertFalse([b for b in chk.skill_rework_rules(self._table()) if 'growth' in b])

    def test_missing(self):
        t = self._table()
        del t['tiers']['growth']
        self.assertTrue(any('growth' in b for b in chk.skill_rework_rules(t)))

    def test_empty(self):
        t = self._table()
        t['tiers']['growth'] = {}
        self.assertTrue(any('growth' in b for b in chk.skill_rework_rules(t)))


if __name__ == '__main__':
    unittest.main()
