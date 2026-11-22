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
        self._ce = K.CONTAINER_EMPTY
        K.CONTAINER_EMPTY = ('[]', '{}', 'null')  # 夹具里 label（String）被西游调用，别的用例不关心 T149 的空串检查

    def tearDown(self):
        K.OVERRIDES = self._over
        K.CONTAINER_EMPTY = self._ce
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

    def test_inner_class_types_become_variant(self):
        # cc 11-15 update-whatsnew：XTianqiTable 的 `var chip: _Chip` 照抄进空壳、内部类 _Chip 没了，发行包整片编译失败
        (self.root / 'modes/xiyou/core/tianqi_bar.gd').write_text(
            'class_name XTianqiBar\nextends Node2D\nvar chip: _Chip = null\nvar chips: Array[_Chip] = []\n'
            'func make(a: _Chip) -> _Chip:\n\treturn a\n\nclass _Chip:\n\tvar x := 1\n', encoding='utf-8')
        stubs, _, _ = K.build_all(self.root)
        s = stubs[Path('modes/xiyou/core/tianqi_bar.gd')]
        self.assertNotIn('_Chip', s)
        self.assertIn('var chip: Variant = null', s)
        self.assertIn('var chips: Array[Variant]', s)
        self.assertIn('func make(a: Variant) -> Variant:', s)

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

    def test_map_element_id_stub_passes_element_through(self):
        # T310：真脚本首句 `if deck_on(s) and e == 1: return 0`，规则 2 照抄成恒 return 0，发行包招式属性号全被抹成 0。
        # 特例 "e" 原样返回；去掉特例时空壳必须变回恒 0（反向验证，证明这条测试真能抓到）
        import json
        import tempfile
        rel = Path('modes/xiyou/core/tianqi_elements.gd')
        real = self._over  # setUp 把 OVERRIDES 换成了空文件，这里要用真特例
        K.OVERRIDES = real
        stubs, _, _ = K.build_all()
        self.assertRegex(stubs[rel], r'func map_element_id\(e: int, s = null\) -> int:\n\treturn e\n')
        over = json.loads(real.read_text(encoding='utf-8'))
        self.assertEqual(over.get('XTianqiElements.map_element_id'), 'e')
        with tempfile.TemporaryDirectory() as td:
            over.pop('XTianqiElements.map_element_id')
            alt = Path(td) / 'over.json'
            alt.write_text(json.dumps(over, ensure_ascii=False), encoding='utf-8')
            K.OVERRIDES = alt
            try:
                bad, _, _ = K.build_all()
            finally:
                K.OVERRIDES = real
        self.assertRegex(bad[rel], r'func map_element_id\(e: int, s = null\) -> int:\n\treturn 0\n')

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
            P.NO_STUB_SMOKE = True  # 夹具里没有真工程，别起 Godot（T150 的冒烟另有 SmokeBattleTests）
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
                        mod.CONTAINER_EMPTY = K.CONTAINER_EMPTY
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

    def test_patch_entry_runs_smoke_before_export(self):
        """T150：补丁入口导出前跑开战冒烟，失败抛 Fail、不导出（源码次序）。"""
        src = (HERE / '发布补丁.py').read_text(encoding='utf-8')
        body = src[src.index('def export_patch('):src.index('REAL_SCRIPTS = False')]
        self.assertIn('smoke_battle(', body)
        self.assertLess(body.index('smoke_battle('), body.index('_export_presets('))
        self.assertIn('NO_STUB_SMOKE', body)


    # K6（T381）：dev.664～845 新增的 56 个脚本逐个复核过。下面三组钉住结论，以后谁改了归类（改名、换前缀、去掉门）这里先红。
    K6_STUBBED = (  # 只在天启篇：类名带 XTianqi 前缀，换空壳
        'modes/xiyou/battle/tianqi_enemy_ai.gd', 'modes/xiyou/battle/tianqi_sear_bar.gd',
        'modes/xiyou/battle/tianqi_swap_view.gd', 'modes/xiyou/battle/tianqi_weak_badges.gd',
        'modes/xiyou/core/tianqi_base.gd', 'modes/xiyou/core/tianqi_brand.gd', 'modes/xiyou/core/tianqi_gem_power.gd',
        'modes/xiyou/core/tianqi_growth.gd', 'modes/xiyou/core/tianqi_guardian_gift.gd', 'modes/xiyou/core/tianqi_hall.gd',
        'modes/xiyou/core/tianqi_hall_text.gd', 'modes/xiyou/core/tianqi_six_dim.gd', 'modes/xiyou/core/tianqi_weak_b2.gd',
        'modes/xiyou/core/xinmo_traits.gd',  # 文件名不带 tianqi，靠类名 XTianqiXinmoTraits 进名单
        'modes/xiyou/ui/tianqi/tianqi_hall_intro.gd', 'modes/xiyou/ui/tianqi_start_page.gd',
    )
    K6_SHARED = (  # 西游档也走的真脚本：带进包
        'modes/xiyou/battle/battle_eval.gd',      # 我方 XSmartAI 估值内核（西游自动战斗）
        'modes/xiyou/battle/battle_stream.gd',    # 多段逐段结算 O-609（所有战斗）
        'modes/xiyou/core/main_thread.gd',        # 交接线程的界面入口保险（所有战斗）
        'modes/xiyou/core/xconfig_transfer.gd',   # 设置导入导出（玩家建议，西游档可用）
        'modes/xiyou/ui/config_transfer_options.gd',
    )
    K6_SKIN_GATED = (  # 新界面专用：自己的 on() 挂在 XUiSkin.on() 上，发行包里恒关
        'modes/xiyou/battle/battle_layout.gd', 'modes/xiyou/battle/party_fold.gd', 'modes/xiyou/battle/turn_marker.gd',
        'modes/xiyou/ui/skin/skin_enemy_hp.gd', 'modes/xiyou/ui/skin/skin_damage_popup.gd',
        'modes/xiyou/ui/skin/skin_battle_motion.gd', 'modes/xiyou/ui/skin/skin_dialogue_fade.gd',
    )

    def test_k6_dev664_845_classification(self):
        done = {str(p) for p in K.targets().values()}
        for rel in self.K6_STUBBED:
            self.assertIn(rel, done, rel + ' 只在天启篇，应换空壳')
        for rel in self.K6_SHARED + self.K6_SKIN_GATED:
            self.assertNotIn(rel, done, rel + ' 西游代码要用真脚本')
            self.assertTrue((K.PROJECT / rel).exists(), rel)
        for rel in self.K6_SKIN_GATED:
            self.assertIn('XUiSkin.on()', (K.PROJECT / rel).read_text(encoding='utf-8'), rel + ' 没挂新界面门')

    def test_k6_new_ui_gate_closed_in_release(self):
        # 新界面那批真脚本（skin_*、站位、队伍栏…）进包的前提：XUiSkin.on() 在发行包里恒 false。
        # 命令行强开在发行时不认；最后一道 XTianqiLine.open_for 换空壳后恒 false。
        src = (K.PROJECT / 'modes/xiyou/ui/skin/ui_skin.gd').read_text(encoding='utf-8')
        self.assertRegex(src, r'static func parse_cli\(args: PackedStringArray, release: bool\) -> int:\n\tif release:\n\t\treturn -1')
        self.assertIn('return XTianqiLine.open_for(XState.current) and XConfig.ui_skin_new()', src)
        self.assertRegex(src, r'(?m)^static var FORCE := false')
        old_ov = K.OVERRIDES
        K.OVERRIDES = HERE / '发行空壳特例.json'
        try:
            stubs, _missing, _how = K.build_all(K.PROJECT)
        finally:
            K.OVERRIDES = old_ov
        line = next(v for k, v in stubs.items() if str(k).endswith('modes/xiyou/core/tianqi_line.gd'))
        self.assertRegex(line, r'static func open_for\([^)]*\) -> bool:\n\treturn false')

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

    def test_empty_container_return_needs_override_or_allow(self):
        # T149：被西游代码调用、空壳按类型返回 []／{}／""／null 的函数（T104 effective_params、T148 create_gear 就这样漏的）：
        # check 要求写特例或进「已确认空值安全」；没人调用的不管；返回数字／布尔的不归这条
        (self.root / 'modes/xiyou/core/tianqi_foo.gd').write_text(
            TQ + '\nstatic func rows_of(a) -> Array:\n\treturn [a]\n\nstatic func unused(a) -> Dictionary:\n\treturn {"a": a}\n', encoding='utf-8')
        (self.root / 'modes/xiyou/core/user.gd').write_text(XIYOU + '\tvar r := XTianqiFoo.rows_of(1)\n', encoding='utf-8')
        _, missing, how = K.build_all(self.root)
        self.assertEqual(K.EMPTY_RET, {'XTianqiFoo.rows_of'})
        errs = K.check_errors(missing, how)
        self.assertEqual(len(errs), 1)
        self.assertIn('XTianqiFoo.rows_of', errs[0])
        self.assertNotIn('unused', errs[0])
        K.OVERRIDES.write_text('{"已确认空值安全": {"XTianqiFoo.rows_of": "调用处在开关守卫内"}}', encoding='utf-8')
        _, missing, how = K.build_all(self.root)
        self.assertEqual(K.check_errors(missing, how), [])
        K.OVERRIDES.write_text('{"XTianqiFoo.rows_of": "[a]"}', encoding='utf-8')
        stubs, missing, how = K.build_all(self.root)
        self.assertEqual(K.EMPTY_RET, set())
        self.assertEqual(K.check_errors(missing, how), [])

    def test_tianqi_strings_scan_and_scrub(self):
        # T385：不换空壳的脚本里写着天启篇玩法名的字符串：没登记 check 报错；登记后发行克隆换成只剩格式符的占位，别的字不动
        f = self.root / 'modes/xiyou/core/mix.gd'
        f.write_text('extends RefCounted\n'
                     '# "烙印" 注释里的不算\n'
                     'func f(a, b):\n'
                     '\tvar t := "\\\\C[6]%s 的烙印加深至「%s」！" % [a, b]  # 行尾注释 "号卷" 不算\n'
                     '\tvar u := \'封卷完成：\' + "心魔" + "重铸"\n'
                     '\treturn "西游的字 %d%%" % 3\n', encoding='utf-8')
        hits = K.tianqi_string_hits(self.root)
        self.assertEqual([(i, l) for i, l in hits['modes/xiyou/core/mix.gd']],
                         [(4, '"\\\\C[6]%s 的烙印加深至「%s」！"'), (5, "'封卷完成：'")])  # 心魔、单独的重铸不算
        self.assertNotIn('modes/xiyou/core/tianqi_foo.gd', hits)  # 换空壳的脚本不归这里管
        self.assertEqual(len(K.string_errors(hits)), 1)
        old = dict(K.MIXED_STR)
        K.MIXED_STR.clear()
        K.MIXED_STR['modes/xiyou/core/mix.gd'] = (2, '测试')
        try:
            self.assertEqual(K.string_errors(hits), [])
            self.assertEqual(K.is_stub_tree(self.root)[-1], 'modes/xiyou/core/mix.gd（还带天启篇玩法名字符串）')
            self.assertEqual(K.scrub_strings(self.root), 2)
            out = f.read_text(encoding='utf-8')
            self.assertIn('\tvar t := "%s%s" % [a, b]  # 行尾注释 "号卷" 不算\n', out)
            self.assertIn("\tvar u := '' + \"心魔\" + \"重铸\"\n", out)
            self.assertIn('# "烙印" 注释里的不算', out)
            self.assertIn('"西游的字 %d%%"', out)
            self.assertNotIn('mix.gd', ' '.join(K.is_stub_tree(self.root)))
            K.MIXED_STR['modes/xiyou/core/mix.gd'] = (1, '测试')  # 条数变多也报错
            self.assertEqual(len(K.string_errors(hits)), 1)
        finally:
            K.MIXED_STR.clear()
            K.MIXED_STR.update(old)

    def test_t388_new_words_unregistered_tree_and_lexer(self):
        # T388（T385 核 P2-1/P2-2/P3-1）：新词命中；未登记文件也让 is_stub_tree 报错；r"..." 与偶数反斜杠
        for w in ('侵染、蚀骨', '本线异化图鉴', '确认取核', '战商', '装备环纹'):
            self.assertTrue(K.TIANQI_WORDS.search(f'x{w}y'), w)
        self.assertFalse(K.TIANQI_WORDS.search('取核'))  # 单独「取核」在 DANGER_RE 里，不收
        f = self.root / 'modes/xiyou/core/mix2.gd'
        f.write_text('extends RefCounted\n'
                     'func f():\n'
                     '\tvar a := r"战商\\n"\n'
                     '\tvar b := "路径\\\\"  # 战商 注释\n'
                     '\treturn "确认取核 %s" % a\n', encoding='utf-8')
        hits = K.tianqi_string_hits(self.root)['modes/xiyou/core/mix2.gd']
        self.assertEqual([i for i, _ in hits], [3, 5])  # 第 4 行偶数反斜杠后引号收尾，注释不算
        self.assertEqual(hits[0][1], 'r"战商\\n"')
        self.assertIn('modes/xiyou/core/mix2.gd（还带天启篇玩法名字符串）', K.is_stub_tree(self.root))  # 没登记也检出
        new, _ = K._str_scan(f.read_text(encoding='utf-8'), fix=True)
        self.assertIn('var a := r""', new)
        self.assertEqual(K._strip_comment('x "a\\\\" # c'), 'x "a\\\\" ')

    def test_real_project_tianqi_strings_registered(self):
        # 真工程：命中的混合脚本都登记了、条数不超；PRIMARY_RE 样式正则里的「重铸」不算（换掉西游档按钮会全变主色）
        hits = K.tianqi_string_hits()
        self.assertEqual(K.string_errors(hits), [])
        self.assertTrue(all(n == len(hits.get(r, [])) for r, (n, _) in K.MIXED_STR.items()), '登记条数和实际对不上')
        self.assertFalse(any('刻上|重铸' in l for _, l in hits['modes/xiyou/ui/alien_workshop.gd']))

    def test_real_project_empty_returns_all_reviewed(self):
        # 真工程：每个按空容器返回的成员都已登记理由，且登记的都还在用（防名单烂）
        K.OVERRIDES = self._over
        K.CONTAINER_EMPTY = self._ce
        K.build_all()
        allow = K.load_allow_empty()
        self.assertEqual(sorted(K.EMPTY_RET - set(allow)), [])
        self.assertEqual(sorted(set(allow) - K.EMPTY_RET), [])

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


class SmokeBattleTests(unittest.TestCase):
    """T150：空壳树开战冒烟 smoke_battle。用假 godot（shell 脚本）模拟：通过、断言失败、SCRIPT ERROR 卡住不退出、没有结果行。"""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.tree = self.dir / 'tree'
        self.tree.mkdir()

    def tearDown(self):
        self._tmp.cleanup()

    def _godot(self, body: str) -> Path:
        g = self.dir / 'godot.sh'
        g.write_text('#!/bin/sh\n' + body + '\n', encoding='utf-8')
        g.chmod(0o755)
        return g

    def test_pass(self):
        g = self._godot('echo \'TEST_RESULT={"passed":9,"total":9}\'')
        self.assertEqual(K.smoke_battle(self.tree, g), [])

    def test_failed_assert(self):
        g = self._godot('echo \'TEST_RESULT={"passed":8,"total":9}\'; exit 1')
        probs = K.smoke_battle(self.tree, g, scenes=('xiyou_battle',))
        self.assertEqual(len(probs), 1)
        self.assertIn('8/9', probs[0])

    def test_script_error_hang_is_killed_fast(self):
        # 真实现象：空壳返回 null → SCRIPT ERROR 后 headless Godot 不退出。要在超时前就拦下
        g = self._godot("echo \"SCRIPT ERROR: Invalid call. Nonexistent function 'snapshot' in base 'Nil'.\"; sleep 60")
        t = __import__('time').time()
        probs = K.smoke_battle(self.tree, g, scenes=('xiyou_battle',), timeout=50)
        self.assertLess(__import__('time').time() - t, 20)
        self.assertEqual(len(probs), 1)
        self.assertIn('脚本错误', probs[0])
        self.assertIn('snapshot', probs[0])

    def test_no_result_line(self):
        g = self._godot('echo hello; exit 0')
        probs = K.smoke_battle(self.tree, g, scenes=('xiyou_battle',))
        self.assertIn('没有 TEST_RESULT', probs[0])

    def test_timeout_and_log_written(self):
        g = self._godot('echo working; sleep 60')
        logs = self.dir / 'logs'
        probs = K.smoke_battle(self.tree, g, logs, scenes=('xiyou_battle',), timeout=2)
        self.assertIn('超过 2 秒', probs[0])
        self.assertIn('working', (logs / '空壳冒烟_xiyou_battle.log').read_text(encoding='utf-8'))

    def test_runs_both_scenes_by_default(self):
        self.assertEqual(K.SMOKE_SCENES, ('xiyou_battle', 'xiyou_battle_ui'))
        g = self._godot('echo "$@" > "$(dirname "$0")/args_$$"; echo \'TEST_RESULT={"passed":1,"total":1}\'')
        self.assertEqual(K.smoke_battle(self.tree, g), [])
        args = ' '.join(f.read_text() for f in self.dir.glob('args_*'))
        self.assertIn('xiyou_battle.tscn', args)
        self.assertIn('xiyou_battle_ui.tscn', args)
        self.assertIn('--audio-driver Dummy', args)


if __name__ == '__main__':
    unittest.main()
