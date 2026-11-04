#!/usr/bin/env python3
"""插件备注覆盖.py 的回归：标签抽取（单元）＋已知例（真实冻结数据）。

已知例（悟空 gaps5／gaps6 查实）：
  DoT Formula／Regen Formula（YEP_X_ExtDoT，重制没实现）必须是「没读」；
  Custom Target Eval（custom1b 做了）、Item n Cost（做了）、SC自动解除（gaps6 做了）必须是「已读」；
  Custom React Effect（转换器用通用正则 EFFECT_RE 读，名字匹配不到）必须靠「通用正则命中」判成「已读」。
"""
import importlib.util
from pathlib import Path
import sys
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('plugin_cov', HERE / '插件备注覆盖.py')
cov = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cov)


class TagExtraction(unittest.TestCase):
    def tags(self, code):
        return set(cov.extract_code_tags(code))

    def test_alternation_expands(self):
        t = self.tags("line.match(/<(?:REGEN|REGENERATE) FORMULA:[ ](.*)>/i)")
        self.assertIn('regenformula', t)
        self.assertIn('regenerateformula', t)

    def test_capture_group_becomes_placeholder(self):
        t = self.tags("line.match(/<ITEM[ ](\\d+)[ ]COST:[ ](\\d+)>/i)")
        self.assertIn('item#cost', t)

    def test_closing_tag_same_name(self):
        t = self.tags("line.match(/<\\/CUSTOM ITEM[ ](\\d+)[ ]COST>/i)")
        self.assertIn('customitem#cost', t)

    def test_comparison_is_not_a_tag(self):
        self.assertEqual(self.tags("for (var i=0; i<notedata.length; i++) { if (a < b) {} }"), set())

    def test_html_noise_dropped(self):
        self.assertEqual(self.tags("var s = '<br>' + \"<div>\";"), set())

    def test_meta_keys(self):
        k = cov.extract_meta_keys("var a = obj.meta.BuffType; var b = obj.meta['SC触发开关解除'];")
        self.assertIn('bufftype', k)
        self.assertIn('sc触发开关解除', k)

    def test_doc_tags_placeholders(self):
        d = cov.extract_doc_tags(["/*:\n * <Item x Cost: y>\n * <SC自动解除:(状态ID)>\n */"])
        self.assertIn('item#cost', d)
        self.assertIn('sc自动解除', d)

    def test_norm(self):
        self.assertEqual(cov.norm_plain('DoT  Formula'), cov.norm_plain('dot_formula'))
        self.assertEqual(cov.norm_plain('Item 12 Cost'), 'item#cost')


@unittest.skipUnless((cov.FROZEN / 'js/plugins.js').exists(), '没有冻结正式源（云端精简环境）')
class KnownCases(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        rows = cov.build_report(use_generated=False)
        cls.list = rows
        cls.rows = {r['key']: r for r in rows}

    def verdict(self, key):
        self.assertIn(key, self.rows, f'抽取没找到标签 {key}')
        return self.rows[key]

    def test_known_unread(self):
        # 弱者挑战（installWeakChallengeRuntime）整套没做、也没人决定不做：scan2 2026-11-04 留下的唯一真缺；做完把它挪进豁免或改成已读，再换一个例子
        r = self.verdict('codexweaknewgame')
        self.assertGreater(r['data_count'], 0)
        self.assertEqual(r['verdict'], '没读', r['why'])

    def test_exempt_entries_valid(self):
        exempt = cov.load_exemptions()
        self.assertGreater(len(exempt), 10)
        for k, v in exempt.items():
            self.assertIn(k, self.rows, f'豁免键 {k} 不在插件标签／命令里（拼错或插件改名）')
            self.assertTrue(v.get('reason') and v.get('evidence'), f'{k} 缺 reason／evidence')
            self.assertIn(self.rows[k]['verdict'], ('已核', '已读'), f'{k} 豁免后应是已核（或代码里已读到）：{self.rows[k]["verdict"]}')

    def test_exempt_shows_as_checked(self):
        r = self.verdict('skillkillgoon')
        self.assertEqual(r['verdict'], '已核', r['why'])
        self.assertIn('永不成立', r['why'])

    def test_known_read(self):
        for k in ('customtargeteval', 'item#cost', 'sc自动解除', 'dotformula', 'regenformula'):
            r = self.verdict(k)
            self.assertGreater(r['data_count'], 0, k)
            self.assertEqual(r['verdict'], '已读', f'{k}: {r["verdict"]} {r["why"]}')

    def test_generic_regex_read(self):
        r = self.verdict('customreacteffect')
        self.assertGreater(r['data_count'], 0)
        self.assertEqual(r['verdict'], '已读', r['why'])

    def test_unread_sorted_first(self):
        first_used = [r for r in self.list if r['data_count'] > 0]
        verdicts = [r['verdict'] for r in first_used]
        self.assertEqual(verdicts, sorted(verdicts, key=lambda v: {'没读': 0, '拿不准': 1, '已核': 2, '已读': 2}[v]))


if __name__ == '__main__':
    unittest.main(verbosity=1)
