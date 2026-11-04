#!/usr/bin/env python3
"""未翻译块清单.py 的回归：族归类、加状态路径的识别，以及几个已知例子（用生成数据；没有生成数据时跳过那几项）。"""
import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('unlisted_blocks', HERE / '未翻译块清单.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class FamilyTests(unittest.TestCase):
    def test_families(self):
        fam = mod.family
        self.assertEqual(fam({'phase': 'apply', 'source': 'user.setBattlerImage("x"); user.refresh();'}), '换装')
        self.assertEqual(fam({'phase': 'react', 'source': 'var e=this.getItemElements(); target.removeState(stateId);'}), '护盾')
        self.assertEqual(fam({'phase': 'remove', 'source': 'user._bubbleWrapCooldown = 3;'}), '护盾')
        self.assertEqual(fam({'phase': 'deselect', 'source': 'target.gainHp(10); target.startDamagePopup();'}), '复活')
        self.assertEqual(fam({'phase': 'regenerate', 'source': 'target.gainHp(-5);'}), 'regenerate')
        self.assertEqual(fam({'phase': 'react', 'source': 'user.reserveCommonEvent(5);'}), 'reserveCommonEvent')
        self.assertEqual(fam({'phase': 'confirm', 'source': 'if (this.isHpEffect()) value += 1;'}), '伤害 react／confirm')
        self.assertEqual(fam({'phase': 'turn_start', 'source': 'user.addState(3);'}), '回合／行动钩子')
        self.assertEqual(fam({'phase': 'apply', 'source': 'user._tp = 1;'}), '改属性／变量')
        self.assertEqual(fam({'phase': 'apply', 'source': 'foo();'}), '其它')


class PathTests(unittest.TestCase):
    def test_push_state_tags(self):
        for note, want in (('<StartPushState1840: 100%>', 1840), ('<PushState0105: 50%>', 105), ('<StartAEPushState0172: 100%>', 172),
                           ('<PushsubState0153: 50%>', 153), ('<RecPushState0133: 100%>', 133)):
            self.assertEqual(mod.PUSH_RE.findall(note), [str(want)], note)

    def test_passive_ids(self):
        self.assertEqual(mod.passive_ids('<Passive State: 1, 3 to 5>'), [1, 3, 4, 5])
        self.assertEqual(mod.passive_ids('<Passive State: 暴击触发>'), [])

    def test_graph_chain_and_tier(self):
        g = mod.Graph()
        g.add_record({'effects': [{'code': 21, 'dataId': 7}], 'note': ''}, mod.SLICE, '技能 1')
        g.add_record({'effects': [{'code': 21, 'dataId': 8}], 'note': ''}, mod.ALL, '道具 2')
        g.add_record({'note': '<PushState0009: 100%>'}, mod.ALL, '武器 3')
        g.add_commands([{'code': 313, 'parameters': [0, 1, 0, 10]}, {'code': 313, 'parameters': [0, 1, 1, 11]},
                        {'code': 355, 'parameters': ['a.addState(12);']}, {'code': 655, 'parameters': ['a.addState(x);']}], mod.SLICE, '公共事件 4')
        self.assertEqual(mod.reach(g, 7), (mod.SLICE, ['技能 1']))
        self.assertEqual(mod.reach(g, 8)[0], mod.ALL)
        self.assertEqual(mod.reach(g, 9)[0], mod.ALL)
        self.assertEqual(mod.reach(g, 10)[0], mod.SLICE)
        self.assertEqual(mod.reach(g, 11)[0], mod.NONE)  # 313 移除不算加
        self.assertEqual(mod.reach(g, 12)[0], mod.SLICE)
        self.assertEqual(sum(g.unresolved.values()), 1)  # addState(x) 未解析


@unittest.skipUnless((mod.GENERATED / 'manifest.json').exists(), '没有生成数据')
class KnownBlocksTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        db, manifest, maps = mod.load(mod.GENERATED)
        g, _ = mod.build_graph(db, manifest, maps)
        cls.db = db
        cls.rows = mod.blocks(db, g)

    def one(self, state, phase=None):
        got = [r for r in self.rows if r['state'] == state and (phase is None or r['phase'] == phase)]
        self.assertTrue(got, state)
        return got[0]

    # 规则期每翻一族块数就变，这里不写死总数，也不拿快要翻掉的族举例（八戒 rules3）
    def test_inventory(self):
        count = sum(e.get('op') == 'js' for st in self.db['States'] if st for e in st.get('effects', []))
        self.assertEqual(len(self.rows), count)

    def test_known_families(self):
        self.assertEqual(self.one(1060, 'react')['family'], '伤害 react／confirm')
        self.assertEqual(self.one(1306, 'turn_start')['family'], 'reserveCommonEvent')
        self.assertEqual(sum(r['family'] == '换装' for r in self.rows), 142)

    def test_known_reach(self):
        self.assertEqual(self.one(1060, 'react')['tier'], '切片可达')       # 技能 5571
        self.assertEqual(self.one(1840)['tier'], '切片可达')               # 技能 6042 的 StartPushState1840（rules1b 粗查漏了这类备注）
        self.assertEqual(self.one(377, 'react')['tier'], '不可达')          # 反伤物理：数据里查不到谁加


if __name__ == '__main__':
    unittest.main()
