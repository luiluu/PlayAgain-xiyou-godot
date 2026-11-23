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


class GuardianPhase4Rules(unittest.TestCase):
    def test_ok_and_absent(self):
        self.assertEqual(chk.guardian_phase4_rules(None), [])
        g = {'hp_base': {'1': 866, '34': 5960000}, 'atk_scale': {'5': 0.2}, 'resist': {'19': 29800}, 'focus': {'20': {'skill': 3560, 'scale': 1.5}}}
        self.assertEqual(chk.guardian_phase4_rules(g), [])

    def test_bad_focus(self):
        self.assertTrue(chk.guardian_phase4_rules({'focus': {'3': {'skill': 1, 'scale': 1.0}}}))
        self.assertTrue(chk.guardian_phase4_rules({'focus': {'20': {'skill': 0, 'scale': 1.0}}}))
        self.assertTrue(chk.guardian_phase4_rules({'focus': {'20': {'skill': 9, 'scale': -1}}}))
        self.assertTrue(chk.guardian_phase4_rules({'focus': {'20': {'skill': 9}}}))
        self.assertEqual(chk.guardian_phase4_rules({'focus': {'12': {'skill': 661, 'scale': 1.5, 'single': 1}}}), [])   # T363
        self.assertTrue(chk.guardian_phase4_rules({'focus': {'12': {'skill': 661, 'scale': 1.5, 'single': 2}}}))
        self.assertTrue(chk.guardian_phase4_rules({'focus': {'12': {'skill': 661, 'scale': 1.5, 'single': True}}}))
        ok = {'skills': [3805], 'pct': {'xunchang': 50, 'jianxian': 100, 'jiusi': 150, 'lianyu': 200, 'zhengdao': 300}}   # T392
        self.assertEqual(chk.guardian_phase4_rules({'lifesteal_cap': ok}), [])
        self.assertTrue(chk.guardian_phase4_rules({'lifesteal_cap': dict(ok, pct={'jianxian': 1.5})}))   # 不是整数
        self.assertTrue(chk.guardian_phase4_rules({'lifesteal_cap': dict(ok, pct={'hard': 100})}))   # 难度键不认识
        self.assertTrue(chk.guardian_phase4_rules({'lifesteal_cap': dict(ok, pct={'xunchang': 50, 'zhengdao': 300})}))   # 五档不齐（T392 核 P3-3）
        self.assertTrue(chk.guardian_phase4_rules({'lifesteal_cap': dict(ok, pct=dict(ok['pct'], hard=100))}))   # 多了不认识的键
        self.assertTrue(chk.guardian_phase4_rules({'lifesteal_cap': dict(ok, skills=[])}))
        self.assertTrue(chk.guardian_phase4_rules({'lifesteal_cap': dict(ok, extra=1)}))
        dp = {'_note': 'x', '22': {'177': 15, '91': 13}}   # T402
        self.assertEqual(chk.guardian_phase4_rules({'dot_pct': dp}), [])
        self.assertTrue(chk.guardian_phase4_rules({'dot_pct': {'22': {'177': 15.5}}}))   # 不是整数
        self.assertTrue(chk.guardian_phase4_rules({'dot_pct': {'22': {'177': 0}}}))
        self.assertTrue(chk.guardian_phase4_rules({'dot_pct': {'22': {'177': 101}}}))
        self.assertTrue(chk.guardian_phase4_rules({'dot_pct': {'35': {'177': 15}}}))   # 层号越界
        self.assertTrue(chk.guardian_phase4_rules({'dot_pct': {'22': {'x': 15}}}))
        self.assertTrue(chk.guardian_phase4_rules({'dot_pct': {'22': {}}}))

    def test_bad_tables(self):
        self.assertTrue(chk.guardian_phase4_rules({'hp_base': {'35': 1}}))
        self.assertTrue(chk.guardian_phase4_rules({'atk_scale': {'5': 0}}))
        self.assertTrue(chk.guardian_phase4_rules({'oops': {}}))


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

    # ---- D205（Kyo 11-18）：数值不用避开 4，带 4 的数照常通过 ----
    def test_four_allowed_d205(self):
        self.t['gear']['set_rule']['level'] = 84
        self.t['drop']['boss_set']['pity_misses'] = 24
        self.t['dragon']['fight']['max_hp_jianxian'] = 2400000
        self.t['altar']['keys']['first_open'] = 4
        for n in ('gear', 'drop', 'dragon', 'altar'):
            self.passes(n)

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
    ('reforge', _set(['costs'], []), 'costs 是非空列表'),
    ('reforge', _set(['costs', 0], -1), 'costs 都是非负整数'),
    ('reforge', _set(['costs', 0], 1.5), 'costs 都是非负整数'),
    ('reforge', _set(['costs', 3], 2000), 'costs 随阶不降'),
    ('reforge', _set(['costs'], [1000, 3000, 6000, 10000, 20000]), 'costs 档数不超过 affix_table 的阶数'),
    ('reforge', _set(['allow_rare'], 'no'), 'allow_rare 是布尔'),
    # alien_gear.json
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
    ('abyss_shelves', _set(['treasure', 'cost'], -10), 'treasure.cost 是非负整数'),
    ('abyss_shelves', _set(['collection', 'rare_cost'], 30), 'collection 稀有价不低于原价'),
    ('abyss_shelves', _set(['treasure', 'layer'], 'epic'), 'treasure.layer 在 affix_table 的 layers 里'),
    ('abyss_shelves', _set(['collection', 'min_tier'], 0), 'collection.min_tier 是正整数'),
    ('abyss_shelves', _set(['collection', 'min_tier'], 9), 'collection.min_tier 在 affix_table 的 tiers 里'),
    ('abyss_shelves', _set(['collection', 'min_quality'], 'shenqi'), 'collection.min_quality 在 QUALITY_KEYS 里'),
    ('abyss_shelves', _set(['treasure'], 'x'), '货架是字典：treasure'),
    # qiyin_equip.json
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

# D205（Kyo 11-18）：带 4 的数不再报（表头已无 nice_number_exempt 键）
BATCH3_WITH_FOUR = [
    ('qiyin_equip', _set(['quality_legacy'], 14), None),
    ('qiyin_show', _set(['true_seal', 'power'], 4), None),
    ('qiyin_dragon_run', _set(['fight', 'troop'], 241), None),
    ('qiyin_dragon_run', _set(['fight', 'rate', 0], 0.4), None),
    ('reforge', _set(['costs', 1], 3400), None),
    ('alien_gear', _set(['levels', 'shigu', 'energy'], 4), None),
    ('abyss_shelves', _set(['treasure', 'cost'], 14), None),
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

    def test_values_with_four_pass_d205(self):
        for i, (name, mutate, _) in enumerate(BATCH3_WITH_FOUR):
            with self.subTest(i=i, table=name):
                t = self.copy_all()
                mutate(t[name + '.json'])
                self.write(t)
                ok, out = self.run_all()
                self.assertTrue(ok, out)

    def test_no_four_check_d205(self):
        t = self.copy_all()
        t['reforge.json']['base_id'] = 4533
        self.write(t)
        ok, out = self.run_all()
        self.assertTrue(ok, out)
        self.assertNotIn('带 4', out)


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

    def test_self_states_on_hit(self):
        t = self._table()
        self.assertFalse([b for b in chk.skill_rework_rules(t) if 'self_states_on_hit' in b])
        t['skills']['6863']['self_states_on_hit'] = False
        self.assertTrue(any('self_states_on_hit' in b for b in chk.skill_rework_rules(t)))

    def test_fate_t268_fields(self):
        t = self._table()
        self.assertFalse([b for b in chk.skill_rework_rules(t) if 'T268' in b])
        t['skills']['6867']['cast_pick'] = {'rate': 10.5, 'pick': [{'foe': 18}]}
        self.assertTrue(any('cast_pick' in b for b in chk.skill_rework_rules(t)))
        t = self._table()
        t['skills']['6867']['cast_pick'] = {'rate': 100, 'pick': [{'enemy': 18}]}
        self.assertTrue(any('cast_pick' in b for b in chk.skill_rework_rules(t)))
        t = self._table()
        t['skills']['6875']['seg_elements_of'] = []
        self.assertTrue(any('seg_elements_of' in b for b in chk.skill_rework_rules(t)))
        t = self._table()
        t['skills']['6862']['damage']['conds'][0]['to'] = 3.5
        self.assertTrue(any('stat_floor' in b for b in chk.skill_rework_rules(t)))

    def test_battle_end_bool(self):
        t = self._table()
        self.assertFalse([b for b in chk.skill_rework_rules(t) if 'battle_end' in b])
        t['states']['1485']['battle_end'] = 1
        self.assertTrue(any('battle_end' in b for b in chk.skill_rework_rules(t)))


class XinmoTraitsRules(unittest.TestCase):
    """xinmo_traits.json（T318）：真表全过；改坏一处都要报错。"""

    def _t(self):
        return json.loads((REAL_DIR / 'xinmo_traits.json').read_text(encoding='utf-8'))

    def test_real_ok(self):
        self.assertEqual(chk.xinmo_traits_rules(self._t()), [])

    def test_mutations(self):
        def flt(t): t['traits']['1']['params']['bonus_dmg_pct'] = 112.5
        def out_rng(t): t['traits']['3']['params']['high_hp_heal_pct'] = 30
        def miss_seg(t): del t['traits']['6']
        def miss_key(t): del t['traits']['2']['params']['max_stacks']
        def bad_key(t): t['traits']['3']['key'] = 'jiliu'
        def tier(t): t['traits']['5']['params']['single_tier_pcts'] = [105, 120, 135]
        def tier_down(t): t['traits']['5']['params']['aoe_tier_pcts'] = [155, 140, 125, 110]
        def pid(t): t['traits']['1']['params']['debuff_params'] = [0, 2]
        def fmt(t): t['traits']['3']['texts']['wash'] = '【逆流】倒卷！%d 名'
        def word(t): t['traits']['6']['open'] = t['traits']['6']['open'] + '守住灵台'
        def no_desc(t): t['traits']['4']['desc'] = ''
        def rng_float(t): t['traits']['2']['ranges']['turns'] = [2, 3.5]
        def shed_fmt(t): t['traits']['2']['texts']['shed'] = '%s 稳住架势，震散了 1 层「骨裂」！'  # T319：层数改占位
        def steal_fmt(t): t['traits']['4']['texts']['steal'] = '心魔发动【盗形】，剥走 %s！'
        def charge_fmt(t): t['traits']['5']['texts']['charge'] = '心魔蓄起 %d 层「影势」！'
        def open_fmt(t): t['traits']['6']['open'] = '心魔特点【同堕】：均深 %d%%。'
        def open_extra(t): t['traits']['1']['open'] = t['traits']['1']['open'] + '%d'
        for fn in (flt, out_rng, miss_seg, miss_key, bad_key, tier, tier_down, pid, fmt, word, no_desc, rng_float,
                   shed_fmt, steal_fmt, charge_fmt, open_fmt, open_extra):
            with self.subTest(fn.__name__):
                t = self._t()
                fn(t)
                self.assertTrue(chk.xinmo_traits_rules(t), fn.__name__)


class BrandRules(unittest.TestCase):
    """brand.json（T073-a）：真表全过；每条规则改坏一处都要报错。"""

    def _t(self):
        return json.loads((REAL_DIR / 'brand.json').read_text(encoding='utf-8'))

    def test_real_ok(self):
        self.assertEqual(chk.brand_rules(self._t()), [])

    def test_mutations(self):
        def nodes(t): t['nodes']['caps'][3] = 35
        def last(t): t['nodes']['caps'][6] = 95
        def bonus(t): t['power']['max_bonus'] = 0.6
        def ucap(t): t['gain']['uncarved_cap'] = 45
        def urealm(t): t['gain']['uncarved_max_realm'] = 3
        def trade(t): t['trade']['branches'].pop()
        def trade_eq(t): t['trade']['branches'][0]['taken'] = 0.04
        def cost(t): t['costs']['list'].pop()
        def fit(t): t['fits']['list'][0]['name'] = '发愣'
        def ripe(t): t['ripe']['fits'].append('换人')
        def sear(t): t['sear']['per_hit']['蚀骨'] = 6
        def fold(t): t['sear']['settle']['折法'] = '按比例'
        def first(t): t['gain']['first_clear']['segments'][1]['each'] = 4
        def over(t): t['costs']['list'][2]['over'] = 41
        def rng(t): t['ripe']['chance_coef'] = 0.9
        def thin(t): t['costs']['list'][1]['at_full'] = 0.3
        for fn in (nodes, last, bonus, ucap, urealm, trade, trade_eq, cost, fit, ripe, sear, fold, first, over, rng, thin):
            with self.subTest(fn.__name__):
                t = self._t()
                fn(t)
                self.assertTrue(chk.brand_rules(t), fn.__name__)

    def test_check_reports_bad_file(self):
        with tempfile.TemporaryDirectory() as d:
            t = self._t()
            t['sear']['settle']['折法'] = '按比例'
            Path(d, 'brand.json').write_text(json.dumps(t, ensure_ascii=False), encoding='utf-8')
            old = chk.DATA_DIR
            chk.DATA_DIR = Path(d)
            try:
                ok, out = run(chk.check_brand, None)
            finally:
                chk.DATA_DIR = old
        self.assertFalse(ok, out)
        self.assertIn('折法', out)


class SkillTune(unittest.TestCase):
    """T163：skill_rework.json 的 tune.D189 覆盖层也要过规则（开关开着时游戏读的是覆盖后的表）。"""
    def table(self, coef):
        return {'skills': {'1': {'damage': {'coef': 3.0, 'stats': {'atk': 1}}, 'desc': ['a']}},
                'tune': {'D189': {'_note': 'x', 'skills': {'1': {'_note': 'y', 'damage': {'coef': coef}}}}}}

    def test_merge_keeps_other_keys(self):
        t = chk.apply_skill_tune(self.table(5.0))
        self.assertEqual(t['skills']['1']['damage'], {'coef': 5.0, 'stats': {'atk': 1}})
        self.assertNotIn('_note', t['skills']['1'])

    def test_tuned_four_caught(self):
        rules = chk._with_tune(lambda tb: ['%s=%s' % ('skills/1/damage/coef', chk.num_text(tb['skills']['1']['damage']['coef']))]
                               if '4' in chk.num_text(tb['skills']['1']['damage']['coef']) else [])
        self.assertEqual(rules(self.table(5.0)), [])
        self.assertEqual(rules(self.table(4.2)), ['tune 覆盖后：skills/1/damage/coef=4.2'])


class CoefInteger(unittest.TestCase):
    """T175／T191：覆盖层全开（D189＋D200）后游戏读到的系数一律整数或小于 1 的整数百分比（附则 E、D200 A）；权重同；
    无条件 always 要并进系数；卡面伤害行不带小数（代码常数的几招豁免）；本体成长覆盖层合并后照查范围（T163 甲核 P3-2）。"""
    def _t(self, dm, desc=('伤害：x',), tune=None):
        t = {'skills': {'1': {'damage': dm, 'desc': list(desc)}}}
        if tune:
            t['tune'] = tune
        return t

    def test_decimal_coef_caught(self):
        self.assertEqual(chk.coef_integer_rules(self._t({'coef': 2.6, 'stats': {'atk': 1}})),
                         ['系数不得有小数：skills/1/damage/coef=2.6'])

    def test_integer_and_percent_pass(self):
        for dm in ({'coef': 3, 'stats': {'atk': 1}}, {'coef': 0.45, 'stats': {'atk': 1}},
                   {'coef': 18, 'stats': {'mhp': 0.01}}, {'coef': 1, 'stats': {'atk': 2, 'agi': 0.6, 'mhp': 0.03}}):
            self.assertEqual(chk.coef_integer_rules(self._t(dm)), [], dm)

    def test_decimal_weight_caught(self):
        self.assertEqual(len(chk.coef_integer_rules(self._t({'coef': 1, 'stats': {'mhp': 0.002}}))), 1)
        self.assertEqual(len(chk.coef_integer_rules(self._t({'coef': 1, 'stats': {'atk': 1.5}}))), 1)

    def test_plain_always_caught_need_skill_kept(self):
        bad = chk.coef_integer_rules(self._t({'coef': 2, 'stats': {'atk': 1}, 'conds': [{'if': 'always', 'mult': 0.9}]}))
        self.assertEqual(len(bad), 1)
        self.assertIn('无条件倍率', bad[0])
        self.assertEqual(chk.coef_integer_rules(self._t({'coef': 2, 'stats': {'atk': 1}, 'conds': [{'if': 'always', 'need_skill': 5, 'mult': 0.3333}]})), [])

    def test_desc_decimal_caught_and_exempt(self):
        self.assertEqual(len(chk.coef_integer_rules(self._t({'coef': 2, 'stats': {'atk': 1}}, ['伤害：物理攻击×2.0']))), 1)
        self.assertEqual(chk.coef_integer_rules(self._t({'coef': 2, 'stats': {'atk': 1}}, ['效果：三段共5.0', '伤害：物理攻击×2'])), [])
        t = {'skills': {'10437': {'damage': {'coef': 1, 'stats': {'atk': 2}}, 'desc': ['伤害：剑心多一段（+0.5）']}}}
        self.assertEqual(chk.coef_integer_rules(t), [])

    def test_product_checked(self):
        # T191 R1（小A P2-3）：各自合规、乘起来出小数百分比或低于 1% 的也要拦
        self.assertEqual(len(chk.coef_integer_rules(self._t({'coef': 0.5, 'stats': {'atk': 0.15}}))), 1)
        self.assertEqual(len(chk.coef_integer_rules(self._t({'coef': 0.5, 'stats': {'mhp': 0.01}}))), 1)
        self.assertEqual(chk.coef_integer_rules(self._t({'coef': 12, 'stats': {'mat': 0.5, 'mmp': 0.02}})), [])

    def test_gojo_pairs_checked(self):
        # T191 R1（小A P1-1）：五条悟茈的对数系数表也要整数
        t = {'skills': {'1': {'gojo_pairs': [1.8, 3.6, 6.0], 'desc': ['伤害：魔法攻击×2']}}}
        self.assertEqual(len(chk.coef_integer_rules(t)), 2)
        t['skills']['1']['gojo_pairs'] = [2, 4, 6]
        self.assertEqual(chk.coef_integer_rules(t), [])

    def test_tune_layers_in_order(self):
        tune = {'D189': {'skills': {'1': {'damage': {'coef': 2.6}}}}, 'D200': {'skills': {'1': {'damage': {'coef': 3}}}}}
        self.assertEqual(chk.coef_integer_rules(self._t({'coef': 1.8, 'stats': {'atk': 1}}, tune=tune)), [])
        self.assertEqual(chk.apply_skill_tune(self._t({'coef': 1.8, 'stats': {'atk': 1}}, tune=tune))['skills']['1']['damage']['coef'], 3)

    def test_real_table(self):
        t = json.loads((REAL_DIR / 'skill_rework.json').read_text(encoding='utf-8'))
        self.assertEqual(chk.coef_integer_rules(t), [])
        merged = chk.apply_skill_tune(t)
        self.assertEqual(merged['skills']['10727']['damage']['coef'], 5)  # D199
        self.assertGreater(len(chk.coef_integer_rules({k: v for k, v in t.items() if k != 'tune'})), 500)  # 关掉覆盖层就是原卡的小数

    def test_base_tune_merged_and_ranged(self):
        base = {'actors': {'7': {'tweak': {}}}, 'tune': {'D189': {'actors': {'7': {'_note': 'n', 'tweak': {'atk': 1.3}}, '9': {'tweak': {'atk': 1}}}}}}
        tb, bad = chk.apply_base_tune(base)
        self.assertEqual(tb['actors']['7']['tweak']['atk'], {'mult': 1.3, 'reason': 'n'})
        self.assertEqual(bad, ['tune.D189.actors/9 不在 actors 里'])



class GuardianParams(unittest.TestCase):
    """guardian_params.json（T237／T245）：只认 31～34 层和 qiyin 行，取值是正整数百分比。"""

    def setUp(self):
        self.t = json.loads((chk.DATA_DIR / 'guardian_params.json').read_text(encoding='utf-8'))

    def test_real_passes(self):
        self.assertEqual(chk.guardian_params_rules(self.t), [])
        self.assertIn('qiyin', self.t)

    def test_decimal_fails(self):
        self.t['qiyin']['def'] = 12.5
        self.assertTrue(any('qiyin 的 def' in b for b in chk.guardian_params_rules(self.t)))

    def test_unknown_stat_fails(self):
        self.t['qiyin']['hit'] = 100
        self.assertTrue(any('hit 不在 stats' in b for b in chk.guardian_params_rules(self.t)))

    def test_floor_out_of_range(self):
        self.t['floors']['35'] = {'def': 130}
        self.assertTrue(any('35 层' in b for b in chk.guardian_params_rules(self.t)))

    def test_qiyin_optional(self):
        del self.t['qiyin']
        self.assertEqual(chk.guardian_params_rules(self.t), [])


class AbsRescaleT246(unittest.TestCase):
    """T246：abs_rescale.json 五类定口径后全部结构化；药品、持续伤害 pct 整数；guardian_params 不放行 mhp（T245 复核 P3）。"""
    def setUp(self):
        self.t = json.loads((REAL_DIR / 'abs_rescale.json').read_text(encoding='utf-8'))

    def row(self, kind, i):
        return next(e for e in self.t['entries'] if e['kind'] == kind and e['id'] == i)

    def test_real_passes(self):
        self.assertEqual(chk.abs_rescale_rules(self.t), [])

    def test_item_pct_decimal(self):
        self.row('item_fixed_heal', 1)['new']['pct'] = 7.2
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_dot_formula_sha(self):
        self.row('state_dot', 43)['new']['sha256'] = 'x'
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_shield_must_be_raw(self):
        self.row('state_shield', 1174)['new'] = {'pct_of': 'mhp', 'pct': 20}
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_text_new_rejected(self):
        self.row('note_dbhplsteal', 72)['new'] = '待定'
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_unscanned_not_empty(self):
        self.t['unscanned'] = []
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_guardian_qiyin_mhp(self):
        g = json.loads((REAL_DIR / 'guardian_params.json').read_text(encoding='utf-8'))
        g['qiyin']['mhp'] = 50
        self.assertTrue(chk.guardian_params_rules(g))


class AbsGroupsT249(unittest.TestCase):
    """T249：敌人技能底数、属性门槛、脚本型回复三组口径（mode、reason）。"""
    def setUp(self):
        self.t = json.loads((REAL_DIR / 'abs_rescale.json').read_text(encoding='utf-8'))
        self.g = self.t['groups']

    def th(self, i):
        return next(r for r in self.g['abs_threshold_in_notes']['rows'] if r['id'] == i)

    def test_real_passes(self):
        self.assertEqual(chk.abs_rescale_rules(self.t), [])

    def test_enemy_base_new_rule_back(self):
        self.g['enemy_skill_fixed_base']['new_rule'] = '固定底数 → 标准线攻击(81级) × 占比%'
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_enemy_base_needs_reason(self):
        self.g['enemy_skill_fixed_base']['new'] = {'mode': 'raw'}
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_threshold_card_only_in_card(self):
        self.th(10474)['new'] = {'mode': 'card', 'reason': 'x'}
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_threshold_bad_mode(self):
        self.th(7063)['new'] = {'mode': 'pct', 'reason': 'x'}
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_regen_must_be_raw(self):
        self.g['custom_regen']['new'] = {'pct_of': 'mhp', 'pct': 5}
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_regen_back_in_unscanned(self):
        self.t['unscanned'].append('Custom Regenerate Effect 脚本型回复（25 个状态）')
        self.assertTrue(chk.abs_rescale_rules(self.t))

    def test_regen_dup_id(self):
        self.g['custom_regen']['rows'].append(dict(self.g['custom_regen']['rows'][0]))
        self.assertTrue(chk.abs_rescale_rules(self.t))


class Growth(unittest.TestCase):
    """growth.json（T256）：全整数、层价分段连续、三人行齐全、平加只认对的能力项。"""

    def setUp(self):
        self.t = json.loads((chk.DATA_DIR / 'growth.json').read_text(encoding='utf-8'))

    def _bad(self, part):
        return any(part in b for b in chk.growth_rules(self.t))

    def test_real_passes(self):
        self.assertEqual(chk.growth_rules(self.t), [])

    def test_decimal_fails(self):
        self.t['actors']['nanoha']['flat']['1'] = 2000.5
        self.assertTrue(self._bad('附则 E'))

    def test_gap_in_segments(self):
        self.t['price']['segments'][1]['from'] = 14
        self.assertTrue(self._bad('不连续'))

    def test_price_down(self):
        self.t['price']['segments'][2]['shares'] = 1
        self.assertTrue(self._bad('层价只升不降'))

    def test_missing_actor(self):
        del self.t['actors']['liuying']
        self.assertTrue(self._bad('缺 liuying'))

    def test_raven_flat_only_mat(self):
        self.t['actors']['raven']['flat']['2'] = 100
        self.assertTrue(self._bad('raven.flat 只该有 4'))

    def test_liuying_no_flat(self):
        self.t['actors']['liuying']['flat'] = {'0': 500}
        self.assertTrue(self._bad('不走平加'))

    def test_share_zero(self):
        self.t['actors']['raven']['share'] = 0
        self.assertTrue(self._bad('一份'))

    def test_note_keys_ignored(self):
        self.t['actors']['raven']['_x'] = 1.5
        self.assertEqual(chk.growth_rules(self.t), [])

class ForcedCopyT255(unittest.TestCase):
    """T255：卡里技能效果 44→公共事件→强制放副本，副本没进卡：要 effects_remove、副本进卡或登记 forced_copy_pending。"""
    def setUp(self):
        self.t = json.loads((REAL_DIR / 'skill_rework.json').read_text(encoding='utf-8'))

    def test_real_passes(self):
        self.assertEqual(chk.forced_copy_rules(self.t), [])

    def test_unremoved_is_gap(self):
        self.t['skills']['502']['effects_remove'] = []
        self.assertTrue(any('502' in b for b in chk.forced_copy_rules(self.t)))

    def test_pending_registers_gap(self):
        self.t['skills']['502']['effects_remove'] = []
        self.t['forced_copy_pending']['502'] = '测试'
        self.assertEqual(chk.forced_copy_rules(self.t), [])

    def test_stale_pending(self):
        self.t['forced_copy_pending']['7057'] = '已去掉'
        self.assertTrue(any('7057' in b for b in chk.forced_copy_rules(self.t)))

    def test_pending_needs_reason(self):
        self.t['skills']['502']['effects_remove'] = []
        self.t['forced_copy_pending']['502'] = ' '
        self.assertTrue(any('502' in b for b in chk.forced_copy_rules(self.t)))

    def test_unreachable_needs_reason_and_gap(self):
        # 4507 玛莎风旋术：公共事件 945 只在学了 229 时放 4893，天启篇走不到，登在 forced_copy_unreachable 放行
        self.assertEqual(chk.forced_copy_rules(self.t), [])
        self.assertIn('4507', self.t['forced_copy_unreachable'])
        self.t['forced_copy_unreachable']['4507'] = ' '
        self.assertTrue(any('4507' in b for b in chk.forced_copy_rules(self.t)))
        del self.t['forced_copy_unreachable']['4507']
        self.assertTrue(any('4507' in b for b in chk.forced_copy_rules(self.t)))

    def test_unreachable_stale(self):
        self.t['forced_copy_unreachable']['502'] = '测试'
        self.assertTrue(any('502' in b for b in chk.forced_copy_rules(self.t)))

    def test_b1_copies_in_card(self):
        # T261：B 组一的副本都进卡（或 623 去强制），不再登记待定
        pend = self.t.get('forced_copy_pending', {})
        for sid in ('4374', '4380', '4383', '5497', '5848', '5852', '5853', '5928', '5935', '7313', '623'):
            self.assertNotIn(sid, pend)
        for sid in ('2836', '2837', '5837', '5838', '5494', '5930', '7314'):
            self.assertIn(sid, self.t['skills'])
        self.assertEqual(self.t['skills']['623']['effects_remove'], [[44, 91]])

    def test_b2_copy_eye_cards(self):
        # T262：西西卡拷贝之眼 15 个复制版进卡（原技能卡系数 ×0.8，并进系数取整数百分比），5888 不再登记待定；T261 遗留三条
        self.assertNotIn('5888', self.t.get('forced_copy_pending', {}))
        ids = ('5891', '5894', '5896', '5898', '5900', '5904', '5906', '5908', '5910', '5912', '5913', '5918', '5919', '5924', '5926')
        for sid in ids:
            c = self.t['skills'][sid]
            self.assertEqual(c['actor'], 88, sid)
            self.assertIn({'op': 'drop_if', 'match': 'includes(588'}, c['seq'], sid)  # 流派被动的额外段全去掉，只留原技能的段数
            self.assertFalse(any(x.get('if') == 'always' for x in c['damage'].get('conds', [])), sid)  # 无条件倍率已并进系数
        self.assertEqual(self.t['skills']['5494']['seq'][-1], {'op': 'keep_effects', 'n': 5})  # 瑞普：模式融合拆五段
        self.assertEqual(self.t['skills']['5494']['damage']['stats'], {'atk': 0.24})
        self.assertNotIn('妖精之羽', ''.join(self.t['skills']['624']['desc']))  # 623 无条件给羽，624 不再写
        self.assertIn('pos=APs text=效果', self.t['skills']['5838']['note_remove'])  # 去掉旧行「效果:两段伤害」

    def test_copy_in_card_ok(self):
        # 副本进卡就不算缺口（7057 的 2365 强制 7075：把 7075 登成卡、撤掉 effects_remove）
        self.t['skills']['7057']['effects_remove'] = []
        self.t['skills']['7075'] = {'actor': 98, 'name': '副本'}
        self.assertFalse(any("技能 7057" in b for b in chk.forced_copy_rules(self.t)))


class FateCopyT263(unittest.TestCase):
    """T263：命运编织者 6861→公共事件 1213 的七种命运副本（6862～6867、6875）都在卡里，6861 不再登记待定。"""
    def setUp(self):
        self.t = json.loads((REAL_DIR / 'skill_rework.json').read_text(encoding='utf-8'))

    def test_not_pending(self):
        self.assertNotIn('6861', self.t['forced_copy_pending'])
        self.assertFalse(any('6861' in b for b in chk.forced_copy_rules(self.t)))

    def test_ultimate_card_needed(self):
        del self.t['skills']['6875']
        self.assertTrue(any('技能 6861' in b and '6875' in b for b in chk.forced_copy_rules(self.t)))

class SixDim(unittest.TestCase):
    """T275：six_dim.json 的规则自检；三种违规（双 SSS、SS 无短板、小数）都能报错；R4 总分只报告（T280）。"""

    def setUp(self):
        self.t = json.loads((REAL_DIR / 'six_dim.json').read_text(encoding='utf-8'))
        self.base = json.loads((REAL_DIR / 'base_line.json').read_text(encoding='utf-8'))
        self.hm = json.loads((REAL_DIR / 'horsemen.json').read_text(encoding='utf-8'))

    def bad(self):
        return chk.six_dim_rules(self.t, self.base, self.hm)

    def test_real_pass(self):
        self.assertEqual(self.bad(), [])

    def test_double_sss(self):
        self.t['actors']['45'].update(output='E', survive='D', speed='SSS', wit='C', resolve='D', support='E')  # 不靠真表里 45 恰好是 SSS
        self.t['actors']['45']['output'] = 'SSS'
        self.assertTrue(any('R1 SSS 至多 1' in b for b in self.bad()))

    def test_ss_no_shortboard(self):
        self.t['actors']['180'].update(output='A', survive='A', speed='B', wit='SS', resolve='B', support='C')
        self.assertTrue(any('R2 SS 无明显短板' in b for b in self.bad()))

    def test_over_budget_report_only(self):
        # T280：R4 分档总分只报告不拦——总分爆表不进 bad，只在报告里多一份「超出预算」
        before = [l for l in chk.six_dim_r4_report(self.t) if 'weak' in l][0]
        self.t['actors']['60'].update(output='A', survive='A', speed='A', wit='A', resolve='A', support='A')
        self.assertFalse(any('R4' in b for b in self.bad()))
        after = [l for l in chk.six_dim_r4_report(self.t) if 'weak' in l][0]
        self.assertNotEqual(before, after)
        self.assertIn('R4 报告 weak', after)

    def test_ss_two_c_cost(self):
        # Kyo 11-19：SS 其余五维至少 2 项 ≤C 就行（不用 D）
        self.t['actors']['180'].update(output='S', survive='B', speed='C', wit='SS', resolve='C', support='B')
        self.assertFalse(any('R2' in b for b in self.bad()))
        self.t['actors']['180'].update(speed='B')
        self.assertTrue(any('R2 SS 无明显短板' in b for b in self.bad()))

    def test_decimal(self):
        self.t['ai_weights']['support_pct']['C'] = 100.5
        self.assertTrue(any('是小数' in b for b in self.bad()))

    def test_sss_with_s(self):
        self.t['actors']['45'].update(output='E', survive='D', speed='SSS', wit='C', resolve='D', support='E')  # 不靠真表里 45 恰好是 SSS
        self.t['actors']['45']['output'] = 'S'
        self.assertTrue(any('R1' in b for b in self.bad()))

    def test_s_cap(self):
        self.t['actors']['6'].update(output='S', survive='S')
        self.assertTrue(any('R3' in b for b in self.bad()))

    def test_unknown_actor_and_knight_key(self):
        self.t['actors']['99999'] = dict(self.t['actors']['6'])
        self.t['knights']['pest'] = self.t['knights'].pop('plague')
        b = self.bad()
        self.assertTrue(any('不在 base_line.json' in x for x in b))
        self.assertTrue(any('同 horsemen.json' in x for x in b))


class K5SixTables(unittest.TestCase):
    """T391（K5）：drop_table／gojo_trials／money_table／ring_styles／trumpet／weak_affix_table 六份表的规则；每份先正例再多条反例（形状、范围、引用）。"""

    def load(self, name):
        return json.loads((REAL_DIR / name).read_text(encoding='utf-8'))

    def has(self, bad, word):
        self.assertTrue(any(word in b for b in bad), '没报出「%s」：%r' % (word, bad))

    def test_real_pass_and_in_checks(self):
        names = [n for n, _ in chk.CHECKS]
        for n in ('drop_table', 'gojo_trials', 'money_table', 'ring_styles', 'trumpet', 'weak_affix_table'):
            self.assertIn(n, names)
        self.assertEqual(chk.drop_table_rules(self.load('drop_table.json')), [])
        self.assertEqual(chk.gojo_trials_rules(self.load('gojo_trials.json'), self.load('six_dim.json')), [])
        self.assertEqual(chk.money_table_rules(self.load('money_table.json')), [])
        self.assertEqual(chk.ring_styles_rules(self.load('ring_styles.json')), [])
        self.assertEqual(chk.trumpet_rules(self.load('trumpet.json')), [])
        self.assertEqual(chk.weak_affix_rules(self.load('weak_affix_table.json'), self.load('six_dim.json')), [])

    # ---- drop_table ----
    def test_drop_shape_and_range(self):
        t = self.load('drop_table.json')
        t['generic']['floors'] = [30, 1]
        self.has(chk.drop_table_rules(t), 'generic.floors')
        t = self.load('drop_table.json')
        t['generic']['quality_weights'] = [0, 0, 0, 0]
        self.has(chk.drop_table_rules(t), 'quality_weights')
        t = self.load('drop_table.json')
        t['generic']['smart_share'] = 1.5
        self.has(chk.drop_table_rules(t), 'smart_share')
        t = self.load('drop_table.json')
        t['generic']['level_by_floor'][2][0] = 3   # 层号倒退
        self.has(chk.drop_table_rules(t), 'level_by_floor 顺序')
        t = self.load('drop_table.json')
        t['dungeon_up']['by_tier'] = [1.0, 2.0, 1.6, 2.0]
        self.has(chk.drop_table_rules(t), 'dungeon_up.by_tier')
        t = self.load('drop_table.json')
        t['signature']['gear_range']['3'] = [0.2, 0.1]
        self.has(chk.drop_table_rules(t), 'signature.gear_range')
        t = self.load('drop_table.json')
        del t['guardian']
        self.has(chk.drop_table_rules(t), 'guardian.first')

    def test_drop_refs(self):
        t = self.load('drop_table.json')
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / 'Skills.json').write_text(json.dumps([None, {'id': 5547}, {'id': 5549}, {'id': 9000}]), encoding='utf-8')
            self.has(chk.drop_table_rules(t, Path(d)), 'bonus.ignore_skills')   # 5548 落在库里范围内的空洞
        t['bonus']['ignore_skills'] = [5547, 5547]
        self.has(chk.drop_table_rules(t), '不重复')

    # ---- gojo_trials ----
    def test_gojo(self):
        six = self.load('six_dim.json')
        t = self.load('gojo_trials.json')
        t['trials']['3'] = t['trials'].pop('2')   # 试炼号断档
        self.has(chk.gojo_trials_rules(t, six), 'trials 的键')
        t = self.load('gojo_trials.json')
        t['trials']['2']['key'] = t['trials']['1']['key']
        self.has(chk.gojo_trials_rules(t, six), 'key 不重复')
        t = self.load('gojo_trials.json')
        t['trials']['1']['ratio']['spear'] = 1.5
        self.has(chk.gojo_trials_rules(t, six), 'ratio')
        t = self.load('gojo_trials.json')
        t['trials']['2']['domain'].pop('turns')
        self.has(chk.gojo_trials_rules(t, six), 'domain')
        t = self.load('gojo_trials.json')
        t['tint'] = [0.5, 2, 0.5]
        t['trials']['1']['awaken_below'] = 1
        b = chk.gojo_trials_rules(t, six)
        self.has(b, 'tint')
        self.has(b, 'awaken_below')
        t = self.load('gojo_trials.json')
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / 'Troops.json').write_text(json.dumps([None, {'id': 1}, {'id': 99}]), encoding='utf-8')
            self.has(chk.gojo_trials_rules(t, six, Path(d)), 'troop')   # 30 在库里范围内缺失

    # ---- money_table ----
    def test_money(self):
        t = self.load('money_table.json')
        t['field_gold']['by_floor'].pop()
        self.has(chk.money_table_rules(t), 'field_gold.by_floor')
        t = self.load('money_table.json')
        del t['price_mult']['zhengdao']
        self.has(chk.money_table_rules(t), 'price_mult')
        t = self.load('money_table.json')
        t['price_mult']['jiusi'] = 0.1   # 比艰险还便宜
        self.has(chk.money_table_rules(t), 'price_mult 顺序')
        t = self.load('money_table.json')
        t['sell']['by_grade'] = [0.1, 0.2]
        self.has(chk.money_table_rules(t), 'sell.by_grade')
        t = self.load('money_table.json')
        t['advance']['gold'] = [100000, 100000, 600000, 1000000]
        self.has(chk.money_table_rules(t), 'advance.gold')
        t = self.load('money_table.json')
        t['training']['levels'] = 20   # 20×3 层超过 36
        self.has(chk.money_table_rules(t), 'training 开放层')
        t = self.load('money_table.json')
        t['scale']['oil'] = 5
        t['reforge']['tier_coef'] = [1, 2, 3]
        b = chk.money_table_rules(t)
        self.has(b, 'scale.oil')
        self.has(b, 'reforge.tier_coef')

    # ---- ring_styles ----
    def test_ring_styles(self):
        t = self.load('ring_styles.json')
        t['styles']['seal_bai']['layer'] = 'ring'
        self.has(chk.ring_styles_rules(t), 'seal_bai.layer')
        t = self.load('ring_styles.json')
        t['rules'][0]['style'] = 'seal_{seal}x'   # 展开后的样式不存在
        self.has(chk.ring_styles_rules(t), "不在 styles 里")
        t = self.load('ring_styles.json')
        t['rules'][1]['when'] = {'nonsense': True}
        self.has(chk.ring_styles_rules(t), 'when')
        t = self.load('ring_styles.json')
        t['styles']['seal_bai']['art']['band'] = 'no_such_band.png'
        self.has(chk.ring_styles_rules(t), 'art.band')
        t = self.load('ring_styles.json')
        t['styles']['seal_bai']['art']['circle'] = 'res://content/tianqi/qiyin/circles/none.png'
        self.has(chk.ring_styles_rules(t), 'art.circle')
        t = self.load('ring_styles.json')
        t['seal_tints'].pop('mo')
        t['styles']['seal_hong']['style']['knot'] = 'red'
        t['styles']['relic_war']['intro'] = 'boom'
        t['dots']['min_pieces'] = 0
        b = chk.ring_styles_rules(t)
        for w in ('seal_tints', 'style.knot', 'intro', 'min_pieces'):
            self.has(b, w)

    # ---- trumpet ----
    def test_trumpet(self):
        t = self.load('trumpet.json')
        t['scrolls'].pop()
        self.has(chk.trumpet_rules(t), '正好七卷')
        t = self.load('trumpet.json')
        t['scrolls'][1]['item'] = t['scrolls'][0]['item']
        self.has(chk.trumpet_rules(t), 'item 不重复')
        t = self.load('trumpet.json')
        t['scrolls'][2]['segment'] = 9
        self.has(chk.trumpet_rules(t), 'segment')
        t = self.load('trumpet.json')
        t['drop']['segments'][1][0] = 20   # 段间有缝
        self.has(chk.trumpet_rules(t), 'drop.segments')
        t = self.load('trumpet.json')
        t['drop']['difficulties'] = ['lianyu', 'hell']
        self.has(chk.trumpet_rules(t), 'drop.difficulties')
        t = self.load('trumpet.json')
        t['limit']['强者'] = 5   # 强者比弱者可学更多
        t['limit']['弱者'] = 3
        self.has(chk.trumpet_rules(t), 'limit 顺序')
        t = self.load('trumpet.json')
        t['scrolls'][0]['aoe'] = 20.5
        t['scrolls'][1]['low_rate'] = 0
        t['retired']['items'].append(t['scrolls'][0]['item'])
        b = chk.trumpet_rules(t)
        for w in ('aoe', 'low_rate', '不和七卷重号'):
            self.has(b, w)
        t = self.load('trumpet.json')
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / 'Items.json').write_text(json.dumps([None, {'id': 1654}, {'id': 1718}, {'id': 9999}]), encoding='utf-8')
            self.has(chk.trumpet_rules(t, Path(d)), 'scrolls[1].item')   # 1655 落在库里范围内的空洞

    # ---- weak_affix_table ----
    def test_weak_affix(self):
        six = self.load('six_dim.json')
        t = self.load('weak_affix_table.json')
        t['entries']['w21']['actor'] = 99999
        self.has(chk.weak_affix_rules(t, six), 'actor 在六维表')
        t = self.load('weak_affix_table.json')
        t['entries']['w17']['no'] = 18
        self.has(chk.weak_affix_rules(t, six), '.no')
        t = self.load('weak_affix_table.json')
        t['entries']['w21']['enabled'] = 'no'
        self.has(chk.weak_affix_rules(t, six), 'enabled')
        t = self.load('weak_affix_table.json')
        t['rules']['drop_rate'] = 1.5
        self.has(chk.weak_affix_rules(t, six), 'drop_rate')
        t = self.load('weak_affix_table.json')
        t['guidable_skills'].append(t['guidable_skills'][0])
        self.has(chk.weak_affix_rules(t, six), 'guidable_skills')
        t = self.load('weak_affix_table.json')
        t['entries']['w21']['proj']['4507']['oops'] = 1
        self.has(chk.weak_affix_rules(t, six), 'proj')
        t = self.load('weak_affix_table.json')
        t['entries']['w23']['thunder']['full_high'] = 9   # 高档满格比低档多
        t['entries']['w103']['mark']['cut_pct'] = 0
        t['entries']['w42']['invite'].pop('cast')
        b = chk.weak_affix_rules(t, six)
        for w in ('thunder 满格', 'cut_pct', 'invite.cast'):
            self.has(b, w)
        t = self.load('weak_affix_table.json')
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / 'Skills.json').write_text(json.dumps([None, {'id': 623}, {'id': 9000}]), encoding='utf-8')
            self.has(chk.weak_affix_rules(t, six, Path(d)), 'guidable_skills')   # 库里范围内缺的技能号

    def test_check_functions_skip_when_missing(self):
        # 表文件不在就跳过（云端没有转换产物同款）
        with tempfile.TemporaryDirectory() as d:
            old = chk.DATA_DIR
            chk.DATA_DIR = Path(d)
            try:
                for fn in (chk.check_drop_table, chk.check_gojo_trials, chk.check_money_table, chk.check_ring_styles, chk.check_trumpet, chk.check_weak_affix_table):
                    ok, out = run(fn, None)
                    self.assertTrue(ok)
                    self.assertIn('跳过', out)
            finally:
                chk.DATA_DIR = old

    def test_broken_file_fails(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / 'drop_table.json').write_text('{"generic": 3}', encoding='utf-8')
            old = chk.DATA_DIR
            chk.DATA_DIR = Path(d)
            try:
                ok, out = run(chk.check_drop_table, None)
            finally:
                chk.DATA_DIR = old
            self.assertFalse(ok)


if __name__ == '__main__':
    unittest.main()
