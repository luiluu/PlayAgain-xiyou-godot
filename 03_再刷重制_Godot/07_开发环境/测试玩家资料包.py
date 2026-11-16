#!/usr/bin/env python3
"""玩家资料包.py 的专项（T008 期一，cc 2026-11-16）：不跑 Godot、不连网、不碰 DSH 出口，几秒跑完。

  python3 测试玩家资料包.py            全部
  python3 测试玩家资料包.py SelfCheckTests

覆盖：自检七项（C7）各一条正例一条反例；C5 定位（只认发行尖端、唯一、多个／没有就失败）；
public_id 规则（C2）；事件块（C3）不带坐标／开关／内部号；出口写前防篡改、原子切「当前」、留十版；
发布补丁.py --verify-online 之后的接线开关（F4）。跨零点两条在小小鱼那边，不在这里。
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


P = load('玩家资料包', '玩家资料包.py')

CHANNEL = {'schema': 1, 'latest': {'version': '0.481', 'code': 481, 'date': '2026-11-15', 'notes': ['修复：藏宝图不能直接使用']},
           'bases': {'477': {}}}
DUMP_VER = {'label': 'v0.02', 'of_patch': 'v0.02'}
BI = {'developmentVersion': 'dev.481', 'releaseVersion': '0.02', 'releaseBase': 481}


def tables():
    t = {k: [] for k in P.KINDS}
    for fname, kind in P.KINDS.items():
        t[fname] = [{'public_id': P.public_id(kind, f'{fname}甲'), 'name': f'{fname}甲', 'description': '说明',
                     'open_in_current_version': True},
                    {'public_id': P.public_id(kind, f'{fname}乙'), 'name': f'{fname}乙', 'description': '效果：暴击率+10%',
                     'open_in_current_version': True}]
    return t


EVENTS = [{'id': 'event:x', 'kind': 'event', 'title': '方桌大厅 · 你好', 'source': '事件.jsonl', 'text': '你好'}]
EVENTS[0]['id'] = '事件:0123456789ab'


def version(**kw):
    v = {'game': P.GAME, 'version': 'v0.02', 'patch': '481', 'release_base': '477', 'published_at': '2026-11-15 17:32',
         'major_content': False, 'tianqi_open': False, 'highlights': ['修复：藏宝图不能直接使用'], 'source_commit': 'abc'}
    v.update(kw)
    return v


class Pkg:
    """在临时目录里装一个合格的小包，返回 (出口, 待检目录, 写下的文件, 条数)。"""

    def __init__(self, td):
        self.out = Path(td) / 'out'
        self.stage = self.out / '.stage-v0.02'
        self.written = []
        self.counts = P.assemble(self.stage, tables(), EVENTS, version(), self.written)

    def check(self, words=frozenset({'七首之龙', 'XTianqiFoo'}), dump_ver=None, prev=None, bi=None, extra_written=()):
        return P.self_check(self.stage, set(words), dump_ver or DUMP_VER, CHANNEL, BI if bi is None else bi, self.counts,
                            prev or {}, self.written + list(extra_written), self.out,
                            [str(self.out / 'v0.02'), str(self.out / '当前')])

    def rows(self, fname):
        return json.loads((self.stage / '数据' / f'{fname}.json').read_text(encoding='utf-8'))

    def put(self, fname, rows):
        (self.stage / '数据' / f'{fname}.json').write_text(json.dumps(rows, ensure_ascii=False), encoding='utf-8')


class SelfCheckTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.p = Pkg(self.td.name)

    def tearDown(self):
        self.td.cleanup()

    def ok(self, res, k):
        self.assertTrue(res[k]['ok'], res[k])

    def bad(self, res, k):
        self.assertFalse(res[k]['ok'], f'{k} 该失败却过了')

    def test_all_pass(self):
        res = self.p.check()
        for k in P.CHECKS:
            self.ok(res, k)

    # ① 字段白名单
    def test_1_fields_extra_key(self):
        rows = self.p.rows('Skills')
        rows[0]['damage'] = {'formula': 'a.atk*4'}
        self.p.put('Skills', rows)
        self.bad(self.p.check(), P.CHECKS[0])

    def test_1_fields_missing_public_id(self):
        rows = self.p.rows('Items')
        del rows[1]['public_id']
        self.p.put('Items', rows)
        self.bad(self.p.check(), P.CHECKS[0])

    def test_1_version_fields(self):
        (self.p.stage / '版本.json').write_text(json.dumps(dict(version(), drop_rate=0.5)), encoding='utf-8')
        self.bad(self.p.check(), P.CHECKS[0])

    # ② 禁词
    def test_2_forbidden_word(self):
        rows = self.p.rows('Armors')
        rows[0]['description'] = '传说中的七首之龙'
        self.p.put('Armors', rows)
        res = self.p.check()
        self.bad(res, P.CHECKS[1])
        self.assertIn('七首之龙', res[P.CHECKS[1]]['problems'][0])

    def test_2_forbidden_in_md_and_case(self):
        (self.p.stage / '常见问答.md').write_text('# 问答\nxtianqifoo 是什么', encoding='utf-8')
        self.bad(self.p.check(), P.CHECKS[1])

    def test_2_contract_field_name_not_a_hit(self):
        self.ok(self.p.check(words={'tianqi'}), P.CHECKS[1])  # 版本.json 的 tianqi_open 是契约字段名

    # ③ 内部数字编号
    def test_3_numeric_id_key(self):
        rows = self.p.rows('Skills')
        rows[0]['id'] = 123
        self.p.put('Skills', rows)
        res = self.p.check()
        self.bad(res, P.CHECKS[2])

    def test_3_id_text(self):
        rows = self.p.rows('Weapons')
        rows[0]['description'] = '[武器] 铁剑（ID 12）'
        self.p.put('Weapons', rows)
        self.bad(self.p.check(), P.CHECKS[2])

    def test_3_block_id_text(self):
        (self.p.stage / '更新记录.md').write_text('见 数据:skill:10122', encoding='utf-8')
        self.bad(self.p.check(), P.CHECKS[2])

    # ④ 版本
    def test_4_label_mismatch(self):
        self.bad(self.p.check(dump_ver={'label': 'v0.01.11', 'of_patch': 'v0.02'}), P.CHECKS[3])

    def test_4_wrong_commit(self):
        self.bad(self.p.check(bi={'developmentVersion': 'dev.480'}), P.CHECKS[3])

    def test_4_version_json_not_from_game(self):
        (self.p.stage / '版本.json').write_text(json.dumps(version(version='v0.01.11'), ensure_ascii=False), encoding='utf-8')
        self.bad(self.p.check(), P.CHECKS[3])

    # ⑤ 条数
    def test_5_drop_more_than_tenth(self):
        self.bad(self.p.check(prev={'Skills': 3}), P.CHECKS[4])  # 2 < 3×0.9

    def test_5_small_drop_ok(self):
        self.ok(self.p.check(prev={'Skills': 2, 'Items': 2}), P.CHECKS[4])

    def test_5_empty_kind(self):
        self.p.counts['States'] = 0
        self.bad(self.p.check(), P.CHECKS[4])

    # ⑥ public_id 唯一
    def test_6_duplicate(self):
        rows = self.p.rows('States')
        rows[1]['public_id'] = rows[0]['public_id']
        self.p.put('States', rows)
        self.bad(self.p.check(), P.CHECKS[5])

    # ⑦ 写入路径
    def test_7_outside(self):
        self.bad(self.p.check(extra_written=[str(Path(self.td.name) / 'elsewhere.json')]), P.CHECKS[6])

    def test_7_dotdot(self):
        self.bad(self.p.check(extra_written=[str(self.p.out / '..' / '群' / 'x.json')]), P.CHECKS[6])


class InjectTests(unittest.TestCase):
    """验收证据 4 的三种反例：注入后自检必失败。"""

    def run_inject(self, what, key):
        with tempfile.TemporaryDirectory() as td:
            p = Pkg(td)
            P.inject(p.stage, what, {'七首之龙'})
            p.counts = P.recount(p.stage)
            res = p.check()
            self.assertFalse(res[key]['ok'], f'{what} 没被 {key} 拦住')

    def test_inject(self):
        self.run_inject('禁词', P.CHECKS[1])
        self.run_inject('数字id', P.CHECKS[2])
        self.run_inject('空目录', P.CHECKS[0])
        self.run_inject('空目录', P.CHECKS[4])


class RowTests(unittest.TestCase):
    def test_public_id_rule(self):
        import hashlib
        self.assertEqual(P.public_id('skill', '火球'), 'skill-' + hashlib.sha256('skill|火球'.encode()).hexdigest()[:10])

    def test_build_rows(self):
        dump = {'kinds': {k: [] for k in P.KINDS}}
        dump['kinds']['Skills'] = [{'id': 5, 'name': '火球', 'description': '伤害：x', 'open': True},
                                   {'id': 6, 'name': '火球', 'description': '二号', 'open': True},
                                   {'id': 7, 'name': '', 'description': '空名'},
                                   {'id': 8, 'name': '------', 'description': '分隔行'},
                                   {'id': 10, 'name': '------15层副本扩充', 'description': '编辑器分组标题'},
                                   {'id': 11, 'name': '测试物理100暴击', 'description': '开发测试'},
                                   {'id': 9, 'name': '火球', 'description': '三号', 'open': False}]
        dump['kinds']['Enemies'] = [{'id': 3, 'name': '测试:木桩-反击', 'open': True}]
        dump['kinds']['Weapons'] = [{'id': 1, 'name': '铁剑', 'description': '购买价格：100', 'price': 100, 'params': [0, 0, 5, 0, 0, 0, 0, 0], 'open': True},
                                    {'id': 2, 'name': '木剑', 'description': '普通的木剑', 'price': 50, 'params': [0] * 8, 'open': True}]
        t, ex = P.build_rows(dump)
        sk = t['Skills']
        self.assertEqual([r['public_id'] for r in sk], [P.public_id('skill', '火球'), P.public_id('skill', '火球') + '-2', P.public_id('skill', '火球') + '-3'])
        self.assertEqual(ex['Skills'], 4)
        self.assertFalse(sk[2]['open_in_current_version'])
        self.assertTrue(all('id' not in r for r in sk))
        self.assertEqual(t['Weapons'][0]['price'], 100)
        self.assertNotIn('price', t['Weapons'][1])  # 说明卡上没有价格行就不给
        self.assertEqual(t['Weapons'][0]['params'], [0, 0, 5, 0, 0, 0, 0, 0])
        self.assertEqual([r['name'] for r in t['Enemies']], ['测试:木桩-反击'])  # 敌人不按「测试」剥

    def test_plain(self):
        self.assertEqual(P._plain('\\n<滑稽商人>\\c[2]你好\\i[12]<WordWrap>'), '滑稽商人：你好')
        self.assertEqual(P._plain('长度：\\evalText<<$dataArmors.length+1>>件'), '长度：件')


class DropRateTests(unittest.TestCase):
    """X2（协调 11-16 定「剥」）：游戏原文里的掉落／产出几率留来源、去数字；战斗特效几率与掉落率加成效果（X3）照留。"""
    CASES = [
        ('流萤专属进阶材料。第15、17、19、21、27层深渊「未知存在」有概率掉落：天灾3%、灭世5%、洪荒6%～18%（随诅咒提高），21、27层至少10%；不受掉落率加成影响。',
         '流萤专属进阶材料。第15、17、19、21、27层深渊「未知存在」有概率掉落；不受掉落率加成影响。'),
        ('改版向导：第15、17、19、21、27层深渊「未知存在」的首领会掉落，概率随难度：天灾3%、灭世5%、洪荒6%～18%；21、27层至少10%。不受掉落率加成影响。',
         '改版向导：第15、17、19、21、27层深渊「未知存在」的首领会掉落，概率随难度；不受掉落率加成影响。'),
        ('(开启后通过深渊位置存在有10%的概率可以触发肝帝积分赌局(可以拒绝))', '(开启后通过深渊位置存在有概率可以触发肝帝积分赌局(可以拒绝))'),
        ('(开启后，每次完成赌场二阶段有1%的概率产出星神命途系列装备)', '(开启后，每次完成赌场二阶段有概率产出星神命途系列装备)'),
    ]
    KEEP = ['特效：渔人叉法(普通攻击50%的几率触发捕鱼穿刺)', '效果：物品掉落率+5%', 'S.A.O(物品掉落+50% 所有伤害增加30% 30%几率再次行动)',
            '效果：星神命途系列装备获得的概率+1%', '特效：存护(获得掩护效果，受到攻击的概率+1000%)']

    def test_redact(self):
        import re
        for before, after in self.CASES:
            got = P.redact_drop(before)
            self.assertEqual(got, after)
            self.assertIsNone(re.search(r'\d\s*%', got))
            self.assertEqual(P.redact_drop(got), got)

    def test_keep_effects(self):
        for t in self.KEEP:
            self.assertEqual(P.redact_drop(t), t)

    def test_self_check_catches(self):
        with tempfile.TemporaryDirectory() as td:
            p = Pkg(td)
            rows = p.rows('Items')
            rows[0]['description'] = self.CASES[0][0]
            p.put('Items', rows)
            self.assertFalse(p.check()[P.CHECKS[1]]['ok'])
            rows[0]['description'] = self.CASES[0][1] + '\n' + self.KEEP[0]
            p.put('Items', rows)
            self.assertTrue(p.check()[P.CHECKS[1]]['ok'])

    def test_build_rows_redacts(self):
        dump = {'kinds': {k: [] for k in P.KINDS}}
        dump['kinds']['Items'] = [{'id': 1, 'name': '萨姆残核', 'description': self.CASES[0][0], 'open': True}]
        t, _ = P.build_rows(dump)
        self.assertEqual(t['Items'][0]['description'], self.CASES[0][1])


class StrictDropRateTests(unittest.TestCase):
    """严口径（小A Carbon 第二道核 P1，项目经理cc 11-16 定）：物品／武器／防具说明与事件对白里，句子有来源词且带 N%、1/N、
    括号里的掉率就去数留来源。原文取自 v0.02 包里 Carbon 报的那几处；出包后不许再含对应数字。"""
    CASES = [  # (原文, 出包文, 出包后不许出现的数)
        ('获得：击败22层 月行天→剥皮教堂的「哥布林太上皇」劳勃掉落（每场5%，熟练度10/50次后×2/×3）',
         '获得：击败22层 月行天→剥皮教堂的「哥布林太上皇」劳勃掉落', ['5%', '10/50', '×2', '×3']),
        ('获得：击败28层 众分天→西天的恶·如来掉落（每场5%，熟练度10/50次后×2/×3）', '获得：击败28层 众分天→西天的恶·如来掉落', ['5%']),
        ('黑龙米拉三次进阶的共用道具。深渊合格掉落判定概率为1/30。', '黑龙米拉三次进阶的共用道具。深渊合格掉落有概率。', ['1/30']),
        ('用于伏黑甚尔进阶。由肝帝积分券的原有奖励流程独立判定获得，概率1/50。', '用于伏黑甚尔进阶。由肝帝积分券的原有奖励流程独立判定获得，有概率。', ['1/50']),
        ('用于宿傩的三次进阶。肝帝积分券奖励流程独立判定，概率1/50；足够完成剩余进阶后停止掉落。',
         '用于宿傩的三次进阶。肝帝积分券奖励流程独立判定，有概率；足够完成剩余进阶后停止掉落。', ['1/50']),
        ('来源：谷雨在队时战斗胜利，约1/50概率掉落（持有数满足剩余进阶时不再掉落）',
         '来源：谷雨在队时战斗胜利，有概率掉落（持有数满足剩余进阶时不再掉落）', ['1/50']),
        ('改版向导：谷雨在队时，战斗胜利有1/50机会获得金缮石。', '改版向导：谷雨在队时，战斗胜利有机会获得金缮石。', ['1/50']),
        ('改版向导：心之钢与狂妄各自独立有10%掉落机会；两件可在同次通关中获得。', '改版向导：心之钢与狂妄各自独立有掉落机会；两件可在同次通关中获得。', ['10%']),
        ('改版向导：锻造锤来自55级不朽深渊后续未知存在，独立20%掉落。装备品质概率与装备掉落概率是两回事。',
         '改版向导：锻造锤来自55级不朽深渊后续未知存在，独立掉落。装备品质概率与装备掉落概率是两回事。', ['20%']),
        ('改版向导：副本Boss每场胜利独立有10%机会掉一枚未鉴定神秘珠，不受掉率影响。', '改版向导：副本Boss每场胜利独立有机会掉一枚未鉴定神秘珠，不受掉率影响。', ['10%']),
        ('改版向导：副本Boss（1/8）以及25张安慰奖券一抽，现在都抽秘境被动书。', '改版向导：副本Boss以及25张安慰奖券一抽，现在都抽秘境被动书。', ['1/8']),
        ('蕴灵品质概率：15%', '蕴灵品质：有概率出现', ['15%']),
        ('归真品质概率：65%', '归真品质：有概率出现', ['65%']),
    ]
    # X3 机制效果：严口径也不动（物品／装备／事件里的加成写法与战斗特效）
    KEEP = ['镶嵌效果：超级幸运（物品掉落率+10%，精魂掉落率+10%）', '特效：寻获财宝(物品掉落率+8%，精魂掉落率+18%)',
            '特效：权势之运(物品掉落率提高30%)', '特效：造成任何伤害有10%概率获得\'闪电护盾\'效果',
            '可以消耗00肝帝积分，提升10%遇到肝帝积分赌局的概率，当前已提升%',
            '宝宝:无视敌人3000%爆闪，无视敌人300%抗性 精魂和爆率增加9999% 获得结算伤害*99999',
            '当前等级：1 / 888；经验：0', '糖尿病：有5%受到糖尿病debuff,全属性*50%,持续200步']
    # 技能、状态不走严口径（冰红茶 1/2、1/8，劫天运 60/20/20）
    SKILLS = ['效果：曼巴在队伍时，通关副本,深渊,未知1/2掉落冰红茶，1/8冰镇冰红茶',
              '效果：你使用劫运神镖杀死天道眷顾者后，能劫取它们的气运，60%的几率获取一颗“天运果·运势”，20%的几率获取一颗“天运果·魔能”']

    def test_strict(self):
        for before, after, gone in self.CASES:
            got = P.redact_text(before, strict=True)
            self.assertEqual(got, after)
            for n in gone:
                self.assertNotIn(n, got)
            self.assertEqual(P.redact_text(got, strict=True), got)

    def test_keep(self):
        for t in self.KEEP:
            self.assertEqual(P.redact_text(t, strict=True), t)

    def test_skills_states_untouched(self):
        dump = {'kinds': {k: [] for k in P.KINDS}}
        dump['kinds']['Skills'] = [{'id': 1, 'name': f'技能{i}', 'description': t, 'open': True} for i, t in enumerate(self.SKILLS)]
        dump['kinds']['Items'] = [{'id': 1, 'name': '黑龙进阶石', 'description': self.CASES[2][0], 'open': True}]
        t, _ = P.build_rows(dump)
        self.assertEqual([r['description'] for r in t['Skills']], self.SKILLS)
        self.assertEqual(t['Items'][0]['description'], self.CASES[2][1])

    def test_event_redacted_before_truncation(self):
        with tempfile.TemporaryDirectory() as td:
            tree = Path(td)
            (tree / 'modes/xiyou/generated/maps').mkdir(parents=True)
            (tree / 'modes/xiyou/generated/db').mkdir(parents=True)
            filler = [{'code': 401, 'parameters': [f'第{i}句' + '字' * 200]} for i in range(16)]
            tail = [{'code': 401, 'parameters': ['\\n<改版向导>锻造锤来自55级不朽深渊后续未知存在，独立20%掉落。']}]
            m = {'displayName': '方桌大厅', 'events': [None, {'id': 71, 'pages': [{'list': filler + tail}]}]}
            (tree / 'modes/xiyou/generated/maps/Map004.json').write_text(json.dumps(m, ensure_ascii=False), encoding='utf-8')
            (tree / 'modes/xiyou/generated/db/CommonEvents.json').write_text('[null]', encoding='utf-8')
            log = []
            P.REDACTED.clear()
            ev = P.build_events(tree, {'kinds': {'Items': [], 'Weapons': [], 'Armors': []}})
            self.assertNotIn('锻造锤', ev[0]['text'])  # 这句在 3000 字截断线后，包里本来就没有
            self.assertNotIn('20%', ev[0]['text'])
            self.assertTrue(any('独立掉落' in x['after'] for x in P.REDACTED))  # 截断线后的句子也剥过

    def test_self_check_strict_scope(self):
        with tempfile.TemporaryDirectory() as td:
            p = Pkg(td)
            rows = p.rows('Items')
            rows[0]['description'] = self.CASES[2][0]
            p.put('Items', rows)
            self.assertFalse(p.check()[P.CHECKS[1]]['ok'])
            rows[0]['description'] = self.CASES[2][1]
            p.put('Items', rows)
            sk = p.rows('Skills')
            sk[0]['description'] = self.SKILLS[0]
            p.put('Skills', sk)
            self.assertTrue(p.check()[P.CHECKS[1]]['ok'])  # 技能里的冰红茶 1/2 不算


class EventTests(unittest.TestCase):
    def test_events(self):
        with tempfile.TemporaryDirectory() as td:
            tree = Path(td)
            (tree / 'modes/xiyou/generated/maps').mkdir(parents=True)
            (tree / 'modes/xiyou/generated/db').mkdir(parents=True)
            m = {'displayName': '方桌大厅', 'events': [None, {'id': 1, 'x': 3, 'y': 4, 'pages': [{'list': [
                {'code': 121, 'parameters': [55, 55, 0]}, {'code': 122, 'parameters': [841, 841, 0, 0, 1]},
                {'code': 401, 'parameters': ['\\n<老头>欢迎']}, {'code': 126, 'parameters': [7, 0, 0, 1]},
                {'code': 126, 'parameters': [8, 1, 0, 1]}, {'code': 126, 'parameters': [9, 0, 0, 1]}]}]}]}
            (tree / 'modes/xiyou/generated/maps/Map004.json').write_text(json.dumps(m, ensure_ascii=False), encoding='utf-8')
            (tree / 'modes/xiyou/generated/db/CommonEvents.json').write_text('[null]', encoding='utf-8')
            dump = {'kinds': {'Items': [{'id': 7, 'name': '藏宝图', 'open': True}, {'id': 8, 'name': '扣掉的', 'open': True},
                                        {'id': 9, 'name': '异化石', 'open': False}], 'Weapons': [], 'Armors': []}}
            ev = P.build_events(tree, dump)
            self.assertEqual(len(ev), 1)
            e = ev[0]
            self.assertEqual(set(e), P.EVENT_FIELDS)
            self.assertEqual(e['title'], '方桌大厅 · 老头：欢迎')
            self.assertIn('[物品] 藏宝图', e['text'])
            self.assertNotIn('扣掉的', e['text'])   # 只写给的，不写扣的
            self.assertNotIn('异化石', e['text'])   # 发行里关着的不写
            self.assertNotIn('841', e['text'] + e['title'])
            import hashlib
            self.assertEqual(e['id'], '事件:' + hashlib.sha256('Map004.json:1'.encode()).hexdigest()[:12])  # 与 kb-index.cjs 同输入


def sh(*a, cwd):
    return subprocess.run(list(a), cwd=cwd, capture_output=True, text=True, check=True).stdout


class LocateTests(unittest.TestCase):
    """C5（小A 复核 P1）：只认发行分支／标签尖端，dev.<补丁号>＋releaseVersion 非空＋大版本一致；唯一，否则失败。"""

    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.r = Path(self.td.name)
        sh('git', 'init', '-q', '-b', 'main', cwd=self.r)
        sh('git', 'config', 'user.email', 't@t', cwd=self.r)
        sh('git', 'config', 'user.name', 't', cwd=self.r)

    def tearDown(self):
        self.td.cleanup()

    def commit(self, bi, msg):
        f = self.r / P.PROJECT_REL / 'content/build_info.json'
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(bi), encoding='utf-8')
        sh('git', 'add', '-A', cwd=self.r)
        sh('git', 'commit', '-qm', msg, cwd=self.r)
        return sh('git', 'rev-parse', 'HEAD', cwd=self.r).strip()

    def test_tip_only_and_unique(self):
        self.commit({'developmentVersion': 'dev.481', 'releaseVersion': '0.01'}, 'main 线旧开发提交')
        sh('git', 'checkout', '-qb', 'cc/v00200', cwd=self.r)
        self.commit({'developmentVersion': 'dev.481', 'releaseVersion': '0.02', 'releaseBase': 481}, '升版')
        tip = self.commit({'developmentVersion': 'dev.481', 'releaseVersion': '0.02', 'releaseBase': 481, 'x': 1}, '四条修复')
        sh('git', 'checkout', '-q', 'main', cwd=self.r)
        sh('git', 'branch', 'cc/vp-paths', cwd=self.r)  # 车道分支名像 cc/v*，不算发行
        loc = P.locate(481, '0.481', cwd=self.r)
        self.assertEqual(loc['commit'], tip)
        # 再打一个指向同一尖端的标签：仍是同一提交，不算多个
        sh('git', 'tag', 'release/v0.02', tip, cwd=self.r)
        self.assertEqual(P.locate(481, '0.481', cwd=self.r)['commit'], tip)

    def test_none_and_multiple_fail(self):
        self.commit({'developmentVersion': 'dev.480', 'releaseVersion': '0.01'}, 'a')
        sh('git', 'branch', 'release/v0.01', cwd=self.r)
        with self.assertRaises(P.Fail):
            P.locate(481, '0.481', cwd=self.r)
        sh('git', 'checkout', '-qb', 'cc/v00200', cwd=self.r)
        self.commit({'developmentVersion': 'dev.481', 'releaseVersion': '0.02'}, 'b')
        sh('git', 'checkout', '-qb', 'cc/v00201', cwd=self.r)
        self.commit({'developmentVersion': 'dev.481', 'releaseVersion': '0.02', 'y': 2}, 'c')
        with self.assertRaises(P.Fail):
            P.locate(481, '0.481', cwd=self.r)

    def test_release_version_required(self):
        sh('git', 'checkout', '-qb', 'cc/v00200', cwd=self.r)
        self.commit({'developmentVersion': 'dev.481'}, '没有发行名')
        with self.assertRaises(P.Fail):
            P.locate(481, '0.481', cwd=self.r)

    def test_major_prefix(self):
        sh('git', 'checkout', '-qb', 'cc/v10000', cwd=self.r)
        self.commit({'developmentVersion': 'dev.481', 'releaseVersion': '1.00'}, '大版本不一致')
        with self.assertRaises(P.Fail):
            P.locate(481, '0.481', cwd=self.r)


class OutputTests(unittest.TestCase):
    def test_switch_tamper_prune(self):
        with tempfile.TemporaryDirectory() as td:
            out = Path(td)
            for i in range(12):
                d = out / f'v0.0{i:02d}'
                d.mkdir()
                (d / 'a.txt').write_text(str(i))
                (d / '自检.json').write_text(json.dumps({'files': P.file_hashes(d)}))
                os.utime(d, (1000 + i, 1000 + i))
                P.switch_current(out, d.name)
            self.assertEqual(os.readlink(out / '当前'), 'v0.011')
            gone = P.prune_versions(out, 'v0.011')
            self.assertEqual(len(gone), 2)
            self.assertEqual(len([p for p in out.iterdir() if p.is_dir() and not p.is_symlink()]), P.KEEP_VERSIONS)
            prev, chk = P.previous(out)
            self.assertEqual(P.tamper_problems(prev, chk), [])
            (prev / 'a.txt').write_text('她改过')
            self.assertTrue(P.tamper_problems(prev, chk))
            (prev / 'a.txt').write_text('11')
            (prev / '多的.md').write_text('x')
            self.assertTrue(P.tamper_problems(prev, chk))


class PatchHookTests(unittest.TestCase):
    """F4：发布补丁.py --verify-online 通过后调 玩家资料包.py；开关可回退；线上不对不调。"""

    def setUp(self):
        self.bp = load('发布补丁_t', '发布补丁.py')

    def test_hook(self):
        calls = []
        with mock.patch.object(self.bp, 'verify_online', return_value=0), \
                mock.patch.object(self.bp, 'embedded_public_key', return_value='k'), \
                mock.patch.object(self.bp.subprocess, 'run', side_effect=lambda a, **k: calls.append(a) or subprocess.CompletedProcess(a, 0)):
            self.assertEqual(self.bp.main(['--verify-online']), 0)
            self.assertTrue(any('玩家资料包.py' in str(x) for c in calls for x in c), calls)
            calls.clear()
            self.assertEqual(self.bp.main(['--verify-online', '--no-player-pack']), 0)
            self.assertFalse(calls)
            self.bp.PLAYER_PACK_AFTER_VERIFY = False
            self.assertEqual(self.bp.main(['--verify-online']), 0)
            self.assertFalse(calls)
            self.bp.PLAYER_PACK_AFTER_VERIFY = True
        with mock.patch.object(self.bp, 'verify_online', return_value=1), \
                mock.patch.object(self.bp, 'embedded_public_key', return_value='k'), \
                mock.patch.object(self.bp.subprocess, 'run', side_effect=lambda a, **k: calls.append(a)):
            self.assertEqual(self.bp.main(['--verify-online']), 1)
            self.assertFalse(calls)

    def test_pack_failure_does_not_fail_verify(self):
        with mock.patch.object(self.bp, 'verify_online', return_value=0), \
                mock.patch.object(self.bp, 'embedded_public_key', return_value='k'), \
                mock.patch.object(self.bp.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
            self.assertEqual(self.bp.main(['--verify-online']), 0)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *sys.argv[1:]], verbosity=1)
