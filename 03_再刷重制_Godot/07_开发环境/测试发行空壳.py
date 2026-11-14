#!/usr/bin/env python3
"""发行空壳.py 的回归：假工程里一个天启篇脚本、一个西游脚本，看空壳留了西游用到的成员、函数体取对了值。"""
import contextlib
import importlib.util
import io
from pathlib import Path
import re
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

    def test_stub_tag_compiled_marker(self):
        # 注释导出时会去掉，空壳要带一个字符串常量标记，发行内容审计才认得出包里的空壳（11-14）
        stubs, _, _ = K.build_all(self.root)
        s = stubs[Path('modes/xiyou/core/tianqi_foo.gd')]
        self.assertIn(K.STUB_TAG_LINE, s)
        # 只有 MARK 没有标记的不算换好
        (self.root / 'modes/xiyou/core/tianqi_foo.gd').write_text(s.replace(K.STUB_TAG_LINE, ''), encoding='utf-8')
        self.assertEqual(K.is_stub_tree(self.root), ['modes/xiyou/core/tianqi_foo.gd'])

    def test_extra_list_without_prefix(self):
        # 类名不带天启篇前缀的专属脚本（如 XGojo）靠 EXTRA 名单换空壳（11-14 release-stub-gojo）
        (self.root / 'modes/xiyou/core/hero.gd').write_text(
            'class_name XHeroOnly\nextends RefCounted\n## 只在天启篇：设计说明\nconst ACTOR := 180\n'
            'static func hidden(id: int) -> bool:\n\treturn id == ACTOR\n', encoding='utf-8')
        (self.root / 'modes/xiyou/core/user2.gd').write_text('extends Node\nfunc f():\n\tprint(XHeroOnly.ACTOR, XHeroOnly.hidden(1))\n', encoding='utf-8')
        self.assertNotIn('XHeroOnly', K.targets(self.root))
        sus = K.suspects(self.root)
        self.assertEqual([p for p, _ in sus], ['modes/xiyou/core/hero.gd'])
        _, missing, how = K.build_all(self.root)
        self.assertTrue(any('hero.gd' in e for e in K.check_errors(missing, how, sus)))
        old = set(K.EXTRA)
        K.EXTRA.add('XHeroOnly')
        try:
            self.assertIn('XHeroOnly', K.targets(self.root))
            self.assertEqual(K.suspects(self.root), [])
            stubs, missing, _ = K.build_all(self.root)
            self.assertEqual(missing, [])
            s = stubs[Path('modes/xiyou/core/hero.gd')]
            self.assertNotIn('设计说明', s)
            self.assertIn('const ACTOR := 180', s)
        finally:
            K.EXTRA.clear()
            K.EXTRA.update(old)

    def test_suspect_signals(self):
        core = self.root / 'modes/xiyou/core'
        (core / 'gojo_extra.gd').write_text('extends RefCounted\n', encoding='utf-8')                       # 文件名
        (core / 'a.gd').write_text('extends RefCounted\n## 天启篇专属的东西\nvar x := 1\n', encoding='utf-8')  # 头注释
        (core / 'b.gd').write_text('extends RefCounted\nconst P := "res://modes/xiyou/tianqi_data/x.json"\n', encoding='utf-8')  # 没发行的路径
        (core / 'c.gd').write_text('extends RefCounted\n## 西游的\nfunc f():\n\tpass  # 只在天启篇（函数里的注释不算）\n'
                                   '\t# "res://content/gojo/x.png" 注释里的路径不算\n', encoding='utf-8')
        got = dict(K.suspects(self.root))
        self.assertEqual(sorted(got), ['modes/xiyou/core/a.gd', 'modes/xiyou/core/b.gd', 'modes/xiyou/core/gojo_extra.gd'])
        self.assertIn('tianqi_data', got['modes/xiyou/core/b.gd'])

    def test_passthrough_needs_override(self):
        # 真脚本「不开就原样返回参数 c」、空壳按类型给 {} 会吞掉消耗表（11-14 XTianqiTrumpet.cost 就这样漏过）：要写特例
        (self.root / 'modes/xiyou/core/tianqi_foo.gd').write_text(
            TQ + '\nstatic func cost(a, skill: Dictionary, c: Dictionary) -> Dictionary:\n\treturn {"mp": 0} if a else c\n', encoding='utf-8')
        (self.root / 'modes/xiyou/core/user.gd').write_text(XIYOU + '\tvar c := XTianqiFoo.cost(null, {}, {"mp": 3})\n', encoding='utf-8')
        _, missing, how = K.build_all(self.root)
        self.assertEqual(how['XTianqiFoo.cost'], '按类型空值')
        errs = K.check_errors(missing, how)
        self.assertEqual(len(errs), 1)
        self.assertIn('XTianqiFoo.cost', errs[0])
        K.OVERRIDES.write_text('{"XTianqiFoo.cost": "c"}', encoding='utf-8')
        stubs, missing, how = K.build_all(self.root)
        self.assertEqual(K.check_errors(missing, how), [])
        self.assertIn('-> Dictionary:\n\treturn c', stubs[Path('modes/xiyou/core/tianqi_foo.gd')])

    def test_real_project_covers_tianqi_only_scripts(self):
        # 真工程：五条悟、守层者重算换空壳；没有没归类的天启篇专属脚本（检查.sh 的 发行空壳.py check 也查这条）
        tg = K.targets()
        self.assertEqual(str(tg['XGojo']), 'modes/xiyou/core/gojo.gd')
        self.assertIn('XGuardianRework', tg)
        self.assertNotIn('XTianqiTitle', tg)
        self.assertEqual(K.suspects(), [])
        hand = (K.HAND / 'XRiftAlien.gd').read_text(encoding='utf-8')
        self.assertIn(K.STUB_TAG_LINE, hand)

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

    def test_real_project_sect_stub(self):
        real_proj = HERE.parent / '01_Godot工程'
        old_ov = K.OVERRIDES
        K.OVERRIDES = HERE / '发行空壳特例.json'
        try:
            stubs, missing, how = K.build_all(real_proj)
            self.assertEqual(K.check_errors(missing, how), [])
            sect_stub = next(v for k, v in stubs.items() if str(k).endswith('modes/xiyou/core/tianqi_sect.gd'))
            self.assertIn('static func intercepts(_s, _map_id: int, _event_id: int) -> bool:\n\treturn false', sect_stub)
            self.assertIn('static func page_override(s, map_id: int, event_id: int, pages: Array) -> Dictionary:\n\treturn {}', sect_stub)
        finally:
            K.OVERRIDES = old_ov

    def test_intercept_and_takeover_stubs_return_falsy_or_empty(self):
        # 通用护栏：全部生成的空壳里，凡「拦截／接管类」函数必须返回 false 或空／pass（防再出现 XTianqiSect.intercepts 照搬 return true）
        exact = {
            'intercepts', 'handles', 'overrides',
            'hides', 'silenced', 'forced_state', 'redirect', 'infinity_block', 'reforge_locked',
            'hide_affix_rate', 'skips_row', 'skips_rate',
            'no_encounter', 'no_rewards', 'no_crit', 'no_regen',
        }
        pat = re.compile(r'^(intercept\w*|handle\w*|override\w*|\w+_override|run_\w+|blocks_\w+|\w+_blocked|hide_\w+|skips_\w+)$')
        falsy_bodies = {'pass', 'return false', 'return null', 'return []', 'return {}', 'return ""', 'return 0', 'return 0.0'}
        sentinels = {'XTianqiGojoTrial.run_request': 'return -1'}  # -1 表示无试炼请求
        over_saved = K.OVERRIDES
        K.OVERRIDES = self._over
        try:
            stubs, missing, how = K.build_all(K.PROJECT)
            tg = K.targets(K.PROJECT)
        finally:
            K.OVERRIDES = over_saved
        self.assertEqual(missing, [])
        checked = set()
        for k in sorted(how):
            cls, fn = k.split('.', 1)
            if fn not in exact and not pat.match(fn):
                continue
            checked.add(k)
            lines = stubs[tg[cls]].splitlines()
            body = []
            for i, ln in enumerate(lines):
                if re.match(rf'^(?:static\s+)?func\s+{re.escape(fn)}\s*\(', ln):
                    for sub in lines[i + 1:]:
                        if not sub.strip() or not sub[:1].isspace():  # 函数体止于空行或顶格行（特例成员 static var 可能紧跟其后）
                            break
                        body.append(sub.strip())
                    break
            self.assertTrue(body, f'{k} 未找到空壳函数体')
            allowed = falsy_bodies | ({sentinels[k]} if k in sentinels else set())
            self.assertIn(' ; '.join(body), allowed, f'{k} 属于拦截/接管类，空壳返回值必须为 false/空，实际为: {body}')
        for expected in ('XTianqiSect.intercepts', 'XTianqiSect.page_override', 'XTianqiSummit.intercepts',
                         'XTianqiSummit.run_event', 'XTianqiMoney.intercepts', 'XTianqiQiyin.intercepts', 'XTianqiTrim.intercepts'):
            self.assertIn(expected, checked)

    def test_copied_return_true_requires_allowlist_and_warns(self):
        # 规则 2 照搬出 return true 时：check 打印警告列表，且不在 发行空壳特例.json「已确认放行」名单里就失败
        (self.root / 'modes/xiyou/core/tianqi_foo.gd').write_text(
            TQ + '\nstatic func intercepts(x) -> bool:\n\tif not ENABLED and x == null:\n\t\treturn true\n\treturn false\n',
            encoding='utf-8')
        (self.root / 'modes/xiyou/core/user.gd').write_text(
            XIYOU + '\tif XTianqiFoo.intercepts(null):\n\t\tpass\n', encoding='utf-8')
        _, missing, how = K.build_all(self.root)
        self.assertIn('XTianqiFoo.intercepts', K.COPIED_TRUE)
        errs = K.check_errors(missing, how)
        self.assertEqual(len(errs), 1)
        self.assertIn('XTianqiFoo.intercepts', errs[0])
        self.assertIn('已确认放行', errs[0])

        old_proj = K.PROJECT
        K.PROJECT = self.root
        try:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = K.main(['check'])
            self.assertEqual(rc, 1)
            self.assertIn('警告：以下函数由规则 2 照搬出 return true', buf.getvalue())
            self.assertIn('XTianqiFoo.intercepts', buf.getvalue())

            K.OVERRIDES.write_text('{"已确认放行": {"XTianqiFoo.intercepts": "测试放行"}}', encoding='utf-8')
            buf2 = io.StringIO()
            with contextlib.redirect_stdout(buf2):
                rc2 = K.main(['check'])
            self.assertEqual(rc2, 0)
            self.assertIn('警告：以下函数由规则 2 照搬出 return true', buf2.getvalue())
            self.assertIn('XTianqiFoo.intercepts', buf2.getvalue())
        finally:
            K.PROJECT = old_proj


if __name__ == '__main__':
    unittest.main()
