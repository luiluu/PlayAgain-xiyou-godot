#!/usr/bin/env python3
"""发行预设排除检查.py（T458）：通配命中、目录命中、不命中、资源（png）命中不报；空壳／KEEP／class_name／被引用都算要进包；
dev.887 的坏预设报出 tianqi_hall_intro.gd。不跑 Godot，几秒。"""
import importlib.util
import tempfile
import types
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('发行预设排除检查', HERE / '发行预设排除检查.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


def presets(rule: str) -> str:
    base = 'builds/*, tests/*, *test_mode_unlock*'
    out = []
    for i, n in enumerate(('macOS 验收', 'macOS 发行', 'Windows 发行', '安卓 发行')):
        filt = base if '验收' in n else f'{base}, {rule}'
        out += [f'[preset.{i}]', '', f'name="{n}"', 'export_filter="all_resources"', f'exclude_filter="{filt}"', '',
                f'[preset.{i}.options]', '', 'exclude_filter="bogus/*"', '']
    return '\n'.join(out)


class FakeStub:
    KEEP = {'XTianqiTitle'}

    def __init__(self, tg):
        self.tg = tg

    def targets(self, root):
        return {c: Path(p) for c, p in self.tg.items()}


class Tree:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.put('project.godot', 'run/main_scene="res://scenes/entry.tscn"\n[autoload]\nGameApp="*res://core/game_app.gd"\n')
        self.put('scenes/entry.tscn', '[ext_resource type="Script" path="res://scenes/entry.gd" id="1"]\n')
        self.put('scenes/entry.gd', 'extends Node\nconst P := preload("res://modes/xiyou/ui/helper.gd")\n')
        self.put('core/game_app.gd', 'extends Node\n')
        self.put('modes/xiyou/ui/helper.gd', 'extends RefCounted\n')
        self.put('modes/xiyou/ui/tianqi/tianqi_hall_intro.gd', 'class_name XTianqiHallIntro\nextends Control\n')
        self.put('modes/xiyou/ui/tianqi/01_badge.png', 'png')
        self.put('modes/xiyou/ui/tianqi_title.gd', 'class_name XTianqiTitle\nextends Control\n')
        self.put('modes/xiyou/core/plain.gd', 'class_name XPlain\nextends RefCounted\n')
        self.put('modes/xiyou/core/loose.gd', 'extends RefCounted\n')  # 没 class_name、没人引用：不要求进包
        self.put('tests/xiyou_foo.gd', 'class_name XFooTest\nextends Node\nconst T := preload("res://modes/xiyou/core/loose.gd")\n')
        self.stub = FakeStub({'XTianqiHallIntro': 'modes/xiyou/ui/tianqi/tianqi_hall_intro.gd'})

    def put(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding='utf-8')

    def check(self, rule):
        return M.check(presets(rule), self.root, self.stub)


class MatchTests(unittest.TestCase):
    def test_glob_rules(self):
        self.assertEqual(M.matching_rule('modes/a/b.gd', ['x/*', 'modes/*']), 'modes/*')         # 目录
        self.assertEqual(M.matching_rule('core/test_mode_unlock.gd', ['*test_mode_unlock*']), '*test_mode_unlock*')  # 通配跨目录
        self.assertEqual(M.matching_rule('core/a.gd', ['res://core/?.gd']), 'res://core/?.gd')  # 带 res://、? 一个字符
        self.assertEqual(M.matching_rule('Core/A.GD', ['core/a.gd']), 'core/a.gd')               # 不分大小写
        self.assertIsNone(M.matching_rule('core/a.gd', ['core/a.gdx', 'cor/*', 'core/?.json']))
        self.assertIsNone(M.matching_rule('core/a.gd', ['core/[a].gd']))                         # 方括号照字面

    def test_parse_presets_skips_options(self):
        p = M.parse_presets(presets('content/tianqi/*'))
        self.assertEqual(set(p), {'macOS 验收', 'macOS 发行', 'Windows 发行', '安卓 发行'})
        self.assertIn('content/tianqi/*', p['安卓 发行'])
        self.assertNotIn('bogus/*', p['macOS 发行'])


class CheckTests(unittest.TestCase):
    def setUp(self):
        self.t = Tree()

    def tearDown(self):
        self.t.tmp.cleanup()

    def files(self, probs):
        return sorted({p.split('｜')[0] for p in probs})

    def test_dir_rule_hits_stub(self):
        probs, n = self.t.check('modes/xiyou/ui/tianqi/*')
        self.assertEqual(self.files(probs), ['modes/xiyou/ui/tianqi/tianqi_hall_intro.gd'])
        self.assertEqual(len(probs), 3)  # 三个发行预设各一条，验收预设不算
        self.assertTrue(all('空壳 XTianqiHallIntro' in p and '命中 modes/xiyou/ui/tianqi/*' in p for p in probs))

    def test_wildcard_hits_keep_and_class_name(self):
        probs, _ = self.t.check('*tianqi_title*, *plain*')
        self.assertEqual(self.files(probs), ['modes/xiyou/core/plain.gd', 'modes/xiyou/ui/tianqi_title.gd'])
        self.assertTrue(any('KEEP XTianqiTitle' in p for p in probs))
        self.assertTrue(any('class_name XPlain' in p for p in probs))

    def test_referenced_scripts_and_autoload(self):
        probs, _ = self.t.check('*helper.gd, core/*, scenes/entry.tscn')
        got = {p.split('｜')[0]: p.rsplit('｜', 1)[1] for p in probs}
        self.assertEqual(got['modes/xiyou/ui/helper.gd'], '被引用：scenes/entry.gd')
        self.assertTrue(got['core/game_app.gd'].startswith('project.godot'))
        self.assertIn('scenes/entry.tscn', got)

    def test_no_hit(self):
        probs, n = self.t.check('content/tianqi/*, modes/xiyou/tianqi_data/*')
        self.assertEqual(probs, [])
        self.assertGreaterEqual(n, 6)

    def test_png_and_loose_and_tests_not_reported(self):
        probs, _ = self.t.check('*.png, modes/xiyou/core/loose.gd')
        self.assertEqual(probs, [])  # 徽章 png 被排除是对的；loose.gd 只被 tests/ 引用
        need = M.must_ship(self.t.root, self.t.stub)
        self.assertNotIn('tests/xiyou_foo.gd', need)
        self.assertNotIn('modes/xiyou/ui/tianqi/01_badge.png', need)

    def test_missing_release_preset(self):
        with self.assertRaises(ValueError):
            M.check('[preset.0]\nname="macOS 发行"\nexclude_filter=""\n', self.t.root, self.t.stub)


class RealProjectTests(unittest.TestCase):
    def test_dev887_presets_report_hall_intro(self):
        """dev.887（ad238e50e）的坏预设：必须报出 tianqi_hall_intro.gd；该提交不在本地（浅克隆）就跳过。"""
        import subprocess
        if subprocess.run(['git', 'cat-file', '-e', 'ad238e50e^{commit}'], cwd=HERE, capture_output=True).returncode:
            self.skipTest('本地没有 ad238e50e')
        with tempfile.TemporaryDirectory() as tmp:
            root = M.extract_rev('ad238e50e', Path(tmp))
            probs, _ = M.check((root / 'export_presets.cfg').read_text(encoding='utf-8'), root)
        self.assertEqual(sorted({p.split('｜')[0] for p in probs}), ['modes/xiyou/ui/tianqi/tianqi_hall_intro.gd'])

    def test_cli_exit_codes(self):
        with tempfile.TemporaryDirectory() as tmp:
            t = Tree()
            try:
                (t.root / 'export_presets.cfg').write_text(presets('modes/xiyou/ui/tianqi/*'), encoding='utf-8')
                orig = M._stub_mod
                M._stub_mod = lambda: t.stub
                try:
                    self.assertEqual(M.main(['--root', str(t.root)]), 1)
                    (t.root / 'export_presets.cfg').write_text(presets('*.png'), encoding='utf-8')
                    self.assertEqual(M.main(['--root', str(t.root)]), 0)
                    self.assertEqual(M.main(['--presets', str(Path(tmp) / 'nope.cfg')]), 2)
                finally:
                    M._stub_mod = orig
            finally:
                t.tmp.cleanup()


if __name__ == '__main__':
    unittest.main()
