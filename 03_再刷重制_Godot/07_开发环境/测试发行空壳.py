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


if __name__ == '__main__':
    unittest.main()
