#!/usr/bin/env python3
"""发行空壳.py 的回归：假工程里一个天启篇脚本、一个西游脚本，看空壳留了西游用到的成员、函数体取对了值。"""
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('发行空壳', HERE / '发行空壳.py')
K = importlib.util.module_from_spec(spec)
spec.loader.exec_module(K)

TQ = '''class_name XTianqiFoo
extends RefCounted
## 设计说明：不该进包
const NAME := "秘密的名字"
const KEY := "foo_key"
const ROWS := [
	{"a": 1},
]
static var ENABLED := true
static var _hidden := 3
var rows: Array = []


static func gain(b, amount: float) -> float:
	if amount <= 0.0 or not ENABLED:
		return amount
	return amount * 1.5


static func regen(logic, dh: float, dm: float) -> Array:
	var x := 1
	if not ENABLED:
		return [dh, dm]
	return [dh * 2, dm]


static func is_on(s) -> bool: return ENABLED and s != null


static func label(i) -> String:
	return "秘密·" + str(i)


static func hook(logic) -> void:
	print("秘密")


static func unused() -> int:
	return 7
'''

XIYOU = '''extends Node
func _ready():
	var v := XTianqiFoo.gain(null, 3.0)
	var r := XTianqiFoo.regen(null, 1.0, 2.0)
	if XTianqiFoo.is_on(null) and XTianqiFoo.ENABLED:
		print(XTianqiFoo.label(1), XTianqiFoo.NAME, XTianqiFoo.KEY, XTianqiFoo.ROWS)
	XTianqiFoo.hook(null)  # XTianqiFoo.unused 只在注释里
'''


class T(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        r = Path(self.td.name)
        (r / 'modes/xiyou/core').mkdir(parents=True)
        (r / 'modes/xiyou/core/tianqi_foo.gd').write_text(TQ, encoding='utf-8')
        (r / 'modes/xiyou/core/user.gd').write_text(XIYOU, encoding='utf-8')
        self.root = r
        self._over = K.OVERRIDES
        K.OVERRIDES = r / 'none.json'

    def tearDown(self):
        K.OVERRIDES = self._over
        self.td.cleanup()

    def test_stub(self):
        stubs, missing, how = K.build_all(self.root)
        self.assertEqual(missing, [])
        s = stubs[Path('modes/xiyou/core/tianqi_foo.gd')]
        self.assertIn('class_name XTianqiFoo', s)
        self.assertIn(K.MARK, s)
        self.assertNotIn('秘密', s)                       # 中文文字、函数体都不进空壳
        self.assertNotIn('设计说明', s)
        self.assertNotIn('unused', s)                     # 西游没用到的成员不留
        self.assertNotIn('_hidden', s)
        self.assertIn('const KEY := "foo_key"', s)        # 英文键名照留（比对用）
        self.assertIn('const NAME := ""', s)
        self.assertIn('const ROWS := []', s)
        self.assertIn('static var ENABLED := true', s)
        self.assertIn('static func gain(b, amount: float) -> float:\n\treturn amount', s)
        self.assertIn('static func regen(logic, dh: float, dm: float) -> Array:\n\treturn [dh, dm]', s)
        self.assertIn('static func is_on(s) -> bool:\n\treturn false', s)   # 一行函数
        self.assertIn('static func label(i) -> String:\n\treturn ""', s)
        self.assertIn('static func hook(logic) -> void:\n\tpass', s)
        self.assertEqual(how['XTianqiFoo.gain'], '照搬关着时的返回')

    def test_override_and_tree_check(self):
        (self.root / 'none.json').write_text('{"XTianqiFoo.label": "str(i)", "XTianqiFoo.regen": "BODY:var a := [dh, dm]\\nreturn a"}', encoding='utf-8')
        stubs, _, how = K.build_all(self.root)
        s = stubs[Path('modes/xiyou/core/tianqi_foo.gd')]
        self.assertIn('static func label(i) -> String:\n\treturn str(i)', s)
        self.assertIn('\tvar a := [dh, dm]\n\treturn a', s)
        self.assertEqual(K.is_stub_tree(self.root), ['modes/xiyou/core/tianqi_foo.gd'])
        for p, src in stubs.items():
            (self.root / p).write_text(src, encoding='utf-8')
        self.assertEqual(K.is_stub_tree(self.root), [])

    def test_numeric_default_zero_rejected_in_make_tree_for_build_and_patch(self):
        # 构造一个返回 1.0 的天启篇倍率函数、无早退无特例，西游代码会调用它
        (self.root / 'modes/xiyou/core/tianqi_foo.gd').write_text(
            TQ + '\nstatic func bonus_mult() -> float:\n\treturn 1.0\n', encoding='utf-8')
        (self.root / 'modes/xiyou/core/user.gd').write_text(
            XIYOU + '\tvar m := XTianqiFoo.bonus_mult()\n', encoding='utf-8')
        old_proj = K.PROJECT
        K.PROJECT = self.root
        try:
            # 1) 无特例：check_errors 与 make_tree 失败
            _, missing, how = K.build_all(self.root)
            errs = K.check_errors(missing, how)
            self.assertEqual(len(errs), 1)
            self.assertIn('XTianqiFoo.bonus_mult', errs[0])
            with self.assertRaises(SystemExit) as cm:
                K.make_tree(self.root / 'out_direct')
            self.assertIn('XTianqiFoo.bonus_mult', str(cm.exception))
            self.assertFalse((self.root / 'out_direct').exists())

            # 整包入口（发行出包.stub_tree）与补丁入口（发布补丁.export_patch）各一个断言：无特例时阻断
            spec_b = importlib.util.spec_from_file_location('发行出包', HERE / '发行出包.py')
            B = importlib.util.module_from_spec(spec_b)
            spec_b.loader.exec_module(B)
            spec_p = importlib.util.spec_from_file_location('发布补丁', HERE / '发布补丁.py')
            P = importlib.util.module_from_spec(spec_p)
            spec_p.loader.exec_module(P)
            P._export_presets = lambda *a, **kw: None
            P._check_patch = lambda tmp, dry, shas: tmp / 'Windows.pck'

            import sys
            old_mod = sys.modules.get('发行空壳')
            old_load = importlib.util.module_from_spec

            def _load_patched(sp):
                m = old_load(sp)
                if sp and sp.name == '发行空壳':
                    orig_exec = sp.loader.exec_module
                    def _exec(mod):
                        orig_exec(mod)
                        mod.PROJECT = self.root
                        mod.OVERRIDES = K.OVERRIDES
                    sp.loader.exec_module = _exec
                return m

            importlib.util.module_from_spec = _load_patched
            try:
                with self.assertRaises(SystemExit) as cm_b:
                    B.stub_tree(self.root / 'pkg_out' / 'dev1_三平台发行')
                self.assertIn('XTianqiFoo.bonus_mult', str(cm_b.exception))
                with self.assertRaises(SystemExit) as cm_p:
                    P.export_patch(self.root / 'base.pck', self.root / 'patch_out', dry=False)
                self.assertIn('XTianqiFoo.bonus_mult', str(cm_p.exception))

                # 2) 补进特例后：make_tree、整包入口、补丁入口均通过
                K.OVERRIDES.write_text('{"XTianqiFoo.bonus_mult": "1.0"}', encoding='utf-8')
                t_direct = K.make_tree(self.root / 'out_ok')
                self.assertIn('static func bonus_mult() -> float:\n\treturn 1.0',
                              (t_direct / 'modes/xiyou/core/tianqi_foo.gd').read_text(encoding='utf-8'))
                t_build = B.stub_tree(self.root / 'pkg_out' / 'dev1_三平台发行')
                self.assertEqual(K.is_stub_tree(t_build), [])
                p_res = P.export_patch(self.root / 'base.pck', self.root / 'patch_out', dry=False)
                self.assertEqual(p_res.name, 'Windows.pck')
            finally:
                importlib.util.module_from_spec = old_load
                if old_mod is not None:
                    sys.modules['发行空壳'] = old_mod
        finally:
            K.PROJECT = old_proj


if __name__ == '__main__':
    unittest.main()
