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

    def test_dot_regen_formula_unread(self):
        for k in ('dotformula', 'regenformula'):
            r = self.verdict(k)
            self.assertGreater(r['data_count'], 0)
            self.assertEqual(r['verdict'], '没读', f'{k}: {r["verdict"]}')

    def test_known_read(self):
        for k in ('customtargeteval', 'item#cost', 'sc自动解除'):
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
        self.assertEqual(verdicts, sorted(verdicts, key=lambda v: {'没读': 0, '拿不准': 1, '已读': 2}[v]))


if __name__ == '__main__':
    unittest.main(verbosity=1)
