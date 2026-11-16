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

    def check(self, words=frozenset({'七首之龙', 'XTianqiFoo'}), dump_ver=None, prev=None, bi=None, extra_written=(), visible=None):
        return P.self_check(self.stage, set(words), dump_ver or DUMP_VER, CHANNEL, BI if bi is None else bi, self.counts,
                            prev or {}, self.written + list(extra_written), self.out,
                            [str(self.out / 'v0.02'), str(self.out / '当前')], visible=visible)

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
        self.run_inject('隐藏掉率', P.CHECKS[1])


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


class VisibleRateTests(unittest.TestCase):
    """X12（Kyo 11-16「放宽」，取代 X2 剥与 T008 严口径）：游戏文本里印给玩家看的掉率原样留；
    隐藏掉率（不在任何玩家可见文本里的）不进包——字段白名单挡内部表，自检②挡拼进来的句子。"""
    # 验收 1 点名的几处（v0.02 包取字原文；T008 时这些被剥成「有概率」）
    ITEMS = {
        '萨姆残核': '流萤专属进阶材料。一阶1个、二阶5个、三阶9个。第15、17、19、21、27层深渊「未知存在」有概率掉落：天灾3%、灭世5%、洪荒6%～18%（随诅咒提高），21、27层至少10%；不受掉落率加成影响。',
        '九秘:行字诀【强化版】': '获得：击败22层 月行天→剥皮教堂的「哥布林太上皇」劳勃掉落（每场5%，熟练度10/50次后×2/×3）',
        '炎黄后裔': '获得：击败26层 兜率宫→丹房的三清投影（任一）掉落（每场5%，熟练度10/50次后×2/×3）',
        '九阳淬体图': '获得：击败19层 天空圣殿→古龙祭坛的「古龙」普拉顿掉落（每场5%，熟练度10/50次后×2/×3）',
        '传承升华': '获得：击败28层 众分天→西天的恶·如来掉落（每场5%，熟练度10/50次后×2/×3）',
        '黑龙进阶石': '黑龙米拉三次进阶的共用道具。深渊合格掉落判定概率为1/30。',
        '甚尔进阶石': '用于伏黑甚尔进阶。由肝帝积分券的原有奖励流程独立判定获得，概率1/50。',
        '咒王进阶石': '用于宿傩的三次进阶。肝帝积分券奖励流程独立判定，概率1/50；足够完成剩余进阶后停止掉落。',
        '谷种金缮石': '来源：谷雨在队时战斗胜利，约1/50概率掉落（持有数满足剩余进阶时不再掉落）',
        '神秘珠·灵蕴': '未鉴定。\n通玄品质概率：15%\n蕴灵品质概率：60%\n凝砂品质概率：25%',
        '神秘珠·太初': '未鉴定。\n归真品质概率：65%\n化境品质概率：35%',
    }
    MUST = {'萨姆残核': ['天灾3%', '灭世5%', '洪荒6%～18%', '至少10%'], '九秘:行字诀【强化版】': ['每场5%'], '炎黄后裔': ['每场5%'],
            '九阳淬体图': ['每场5%'], '传承升华': ['每场5%'], '黑龙进阶石': ['1/30'], '甚尔进阶石': ['1/50'], '咒王进阶石': ['1/50'],
            '谷种金缮石': ['1/50'], '神秘珠·灵蕴': ['通玄品质概率：15%', '蕴灵品质概率：60%', '凝砂品质概率：25%'],
            '神秘珠·太初': ['归真品质概率：65%', '化境品质概率：35%']}
    DIALOG = ['\\n<改版向导>谷雨在队时，战斗胜利有1/50机会获得金缮石。',
              '\\n<改版向导>副本Boss（1/8）以及25张安慰奖券一抽，现在都抽秘境被动书。',
              '(开启后通过深渊位置存在有10%的概率可以触发肝帝积分赌局(可以拒绝))']
    # 隐藏掉率：只在数据库字段／备注／天启篇掉落表里，游戏文本没写
    HIDDEN = ['7.25%', '1/37', '0.33%']

    def dump(self):
        d = {'kinds': {k: [] for k in P.KINDS}}
        d['kinds']['Items'] = [{'id': i + 1, 'name': n, 'description': t, 'open': True, 'note': '<Drop Rate: 7.25%>',
                                'dropItems': [{'kind': 1, 'dataId': 9, 'denominator': 37}]} for i, (n, t) in enumerate(self.ITEMS.items())]
        d['kinds']['Enemies'] = [{'id': 1, 'name': '哥布林太上皇', 'note': '<Item Drop 9: 0.33%>',
                                  'dropItems': [{'kind': 1, 'dataId': 9, 'denominator': 37}], 'open': True}]
        return d

    def events(self, td):
        tree = Path(td) / 'tree'
        (tree / 'modes/xiyou/generated/maps').mkdir(parents=True)
        (tree / 'modes/xiyou/generated/db').mkdir(parents=True)
        lst = [{'code': 401, 'parameters': [t]} for t in self.DIALOG] + [{'code': 108, 'parameters': ['掉落概率7.25%（注释，不显示）']}]
        m = {'displayName': '方桌大厅', 'events': [None, {'id': 71, 'pages': [{'list': lst}]}]}
        (tree / 'modes/xiyou/generated/maps/Map004.json').write_text(json.dumps(m, ensure_ascii=False), encoding='utf-8')
        (tree / 'modes/xiyou/generated/db/CommonEvents.json').write_text('[null]', encoding='utf-8')
        return P.build_events(tree, {'kinds': {'Items': [], 'Weapons': [], 'Armors': []}})

    def build(self, td):
        P.VISIBLE.clear()
        t, _ = P.build_rows(self.dump())
        ev = self.events(td)
        p = Pkg(td)
        p.stage.joinpath('数据/Items.json').write_text(json.dumps(t['Items'], ensure_ascii=False), encoding='utf-8')
        p.stage.joinpath('数据/Enemies.json').write_text(json.dumps(t['Enemies'], ensure_ascii=False), encoding='utf-8')
        p.stage.joinpath('事件.jsonl').write_text('\n'.join(json.dumps(e, ensure_ascii=False) for e in ev) + '\n', encoding='utf-8')
        return p, t, ev

    def test_1_visible_rates_kept(self):
        with tempfile.TemporaryDirectory() as td:
            p, t, ev = self.build(td)
            got = {r['name']: r['description'] for r in t['Items']}
            for name, text in self.ITEMS.items():
                self.assertEqual(got[name], text, f'{name} 说明卡被改了字')
                for n in self.MUST[name]:
                    self.assertIn(n, got[name])
            body = ev[0]['text']
            for n in ('1/50机会', '副本Boss（1/8）', '有10%的概率'):
                self.assertIn(n, body)
            kept = P.rate_lines(p.stage)
            self.assertEqual(len([x for x in kept if x['where'] != '数据/Enemies.json']), 18)  # 说明卡 14 行＋对白 3 句＋事件标题 1（首句带 1/50）
            res = p.check(visible=P.VISIBLE)
            self.assertTrue(res[P.CHECKS[1]]['ok'], res[P.CHECKS[1]])

    def test_2_hidden_rates_not_in_pack(self):
        with tempfile.TemporaryDirectory() as td:
            p, t, ev = self.build(td)
            blob = '\n'.join(x.read_text(encoding='utf-8') for x in P.pkg_files(p.stage))
            for n in self.HIDDEN:
                self.assertNotIn(n, blob)  # 备注、dropItems、事件注释里的隐藏掉率都没进包
            for r in t['Items'] + t['Enemies']:
                self.assertFalse(set(r) & {'note', 'dropItems', 'meta'})
            self.assertNotIn('7.25', ev[0]['text'])

    def test_2_injected_hidden_rate_blocked(self):
        """包里任何掉率句没在玩家可见文本里出现过（手写 md、拼进来的数据）都拦。"""
        with tempfile.TemporaryDirectory() as td:
            p, t, ev = self.build(td)
            for where in ('Items', 'md', '事件'):
                q = Pkg(str(Path(td) / where))
                q.stage.joinpath('数据/Items.json').write_text(json.dumps(t['Items'], ensure_ascii=False), encoding='utf-8')
                if where == 'Items':
                    rows = q.rows('Items')
                    rows[1]['description'] += '\n另有隐藏表：首领每场掉落概率7.25%'
                    q.put('Items', rows)
                elif where == 'md':
                    q.stage.joinpath('常见问答.md').write_text('问：萨姆残核掉率？\n答：未知存在掉落概率1/37。\n', encoding='utf-8')
                else:
                    q.stage.joinpath('事件.jsonl').write_text(json.dumps(dict(EVENTS[0], text='首领有0.33%的概率掉落神器'), ensure_ascii=False) + '\n', encoding='utf-8')
                res = q.check(visible=P.VISIBLE)
                self.assertFalse(res[P.CHECKS[1]]['ok'], f'{where} 里的隐藏掉率没拦住')
                self.assertTrue(any('玩家文本里没有的掉率' in x for x in res[P.CHECKS[1]]['problems']))

    def test_2_no_visible_corpus_blocks_all(self):
        """没给可见文本（老调用、取字失败）就不放行任何掉率句：宁可不出包。"""
        with tempfile.TemporaryDirectory() as td:
            p = Pkg(td)
            rows = p.rows('Items')
            rows[0]['description'] = self.ITEMS['黑龙进阶石']
            p.put('Items', rows)
            self.assertFalse(p.check()[P.CHECKS[1]]['ok'])

    # 小A 第二道核 P1／P3 报的绕过句：都得认成掉率句，且不在可见文本里时②必拦
    BYPASS = ['深渊掉落，7.25%', '隐藏Boss掉率： 7.25%', '隐藏Boss掉落 7.25%', '答：概率为5%。', '秘境出货概率：1/30',
              '每场5%概率获取', '掉落提高7.25%', '首领掉落千分之五', '隐藏宝箱爆率 3‰', '神器掉率约3成']

    def test_rate_detector(self):
        for t in self.BYPASS:
            self.assertTrue(P.is_rate_line(t), t)
        for t in self.MUST:
            for ln in self.ITEMS[t].split('\n')[1:] or [self.ITEMS[t]]:
                self.assertTrue(P.is_rate_line(ln), ln)
        for t in ['效果：物品掉落率+5%', '特效：寻获财宝(物品掉落率+8%，精魂掉落率+18%)', '当前等级：1 / 888；经验：0',
                  '战斗胜利后获得经验+10%', '第15、17、19层深渊', '完成3成功挑战']:
            self.assertFalse(P.is_rate_line(t), t)

    def test_bypass_blocked(self):
        with tempfile.TemporaryDirectory() as td:
            p, t, ev = self.build(td)
            for i, line in enumerate(self.BYPASS):
                q = Pkg(str(Path(td) / f'b{i}'))
                q.stage.joinpath('常见问答.md').write_text(f'问：掉率？\n{line}\n', encoding='utf-8')
                res = q.check(visible=P.VISIBLE)
                self.assertFalse(res[P.CHECKS[1]]['ok'], f'「{line}」没拦住')

    def test_substring_tail_not_allowed(self):
        """可见长句的尾巴另起一行不能借子串放行；只有事件截断尾行可以是前缀。"""
        with tempfile.TemporaryDirectory() as td:
            p, t, ev = self.build(td)
            q = Pkg(str(Path(td) / 'tail'))
            q.stage.joinpath('常见问答.md').write_text('天灾3%、灭世5%、洪荒6%～18%（随诅咒提高），21、27层至少10%；不受掉落率加成影响。\n', encoding='utf-8')
            self.assertFalse(q.check(visible=P.VISIBLE)[P.CHECKS[1]]['ok'])
            # 事件 text 不到 3000 字时，最后一行是可见句前缀也不放行
            e = dict(EVENTS[0], text='你好\n改版向导：谷雨在队时，战斗胜利有1/50机会')
            q.stage.joinpath('事件.jsonl').write_text(json.dumps(e, ensure_ascii=False) + '\n', encoding='utf-8')
            q.stage.joinpath('常见问答.md').write_text('（待补）\n', encoding='utf-8')
            self.assertFalse(q.check(visible=P.VISIBLE)[P.CHECKS[1]]['ok'])
            # 截到 3000 字时，尾行是可见句前缀放行；不是前缀照拦
            e['text'] = '字' * (P.EVENT_CAP - 21) + '\n' + '改版向导：谷雨在队时，战斗胜利有1/50机会'[:20]
            self.assertEqual(len(e['text']), P.EVENT_CAP)
            q.stage.joinpath('事件.jsonl').write_text(json.dumps(e, ensure_ascii=False) + '\n', encoding='utf-8')
            self.assertTrue(q.check(visible=P.VISIBLE)[P.CHECKS[1]]['ok'], q.check(visible=P.VISIBLE)[P.CHECKS[1]])
            e['text'] = '字' * (P.EVENT_CAP - 21) + '\n' + '首领每场掉落概率7.25%隐藏表补齐二十字'[:20]
            q.stage.joinpath('事件.jsonl').write_text(json.dumps(e, ensure_ascii=False) + '\n', encoding='utf-8')
            self.assertFalse(q.check(visible=P.VISIBLE)[P.CHECKS[1]]['ok'])

    def test_unopened_not_cross_file(self):
        """未开放条目的说明只给它自己放行，不进跨文件白名单。"""
        with tempfile.TemporaryDirectory() as td:
            P.VISIBLE.clear()
            d = {'kinds': {k: [] for k in P.KINDS}}
            line = '异化掉落：深渊异化首领掉落概率1/40'
            d['kinds']['Items'] = [{'id': 1, 'name': '异化核', 'description': line, 'open': False},
                                   {'id': 2, 'name': '普通石', 'description': '说明', 'open': True}]
            t, _ = P.build_rows(d)
            self.assertNotIn(line, P.VISIBLE.lines)
            q = Pkg(td)
            q.put('Items', t['Items'])
            self.assertTrue(q.check(visible=P.VISIBLE)[P.CHECKS[1]]['ok'])  # 它自己那行放行
            rows = q.rows('Items')
            rows[1]['description'] = line  # 搬到已开放条目
            q.put('Items', rows)
            self.assertFalse(q.check(visible=P.VISIBLE)[P.CHECKS[1]]['ok'])
            q.put('Items', t['Items'])
            q.stage.joinpath('常见问答.md').write_text(line + '\n', encoding='utf-8')  # 搬到 md
            self.assertFalse(q.check(visible=P.VISIBLE)[P.CHECKS[1]]['ok'])

    def test_kept_counts_after_truncation(self):
        """原样留计数按截断后实际进包的行数。"""
        with tempfile.TemporaryDirectory() as td:
            q = Pkg(td)
            filler = '字' * (P.EVENT_CAP - 5)
            e = dict(EVENTS[0], text=(filler + '\n改版向导：独立20%掉落。')[:P.EVENT_CAP])
            q.stage.joinpath('事件.jsonl').write_text(json.dumps(e, ensure_ascii=False) + '\n', encoding='utf-8')
            self.assertEqual(P.rate_lines(q.stage), [])  # 截掉的那句不算

    def test_forbidden_word_escaped(self):
        """禁词用 \\uXXXX 转义写进 json 也拦。"""
        with tempfile.TemporaryDirectory() as td:
            q = Pkg(td)
            rows = q.rows('Items')
            rows[0]['description'] = '七首之龙'
            (q.stage / '数据/Items.json').write_text(json.dumps(rows, ensure_ascii=True), encoding='utf-8')
            self.assertNotIn('七首之龙', (q.stage / '数据/Items.json').read_text(encoding='utf-8'))
            self.assertFalse(q.check()[P.CHECKS[1]]['ok'])

    def test_inject_hidden(self):
        with tempfile.TemporaryDirectory() as td:
            p = Pkg(td)
            P.inject(p.stage, '隐藏掉率', set())
            res = p.check(visible=['说明', '效果：暴击率+10%'])
            self.assertFalse(res[P.CHECKS[1]]['ok'])


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
