extends Node
## 【cc·T307·未经审查】新界面卡 O：版型二名单页通用件（XSkinRosterPage）＋进阶、修炼场、技能遗忘三页（T254 3.10～3.12）。
## - 开关：天启篇＋新皮肤才建新页；XSkinRosterPage.ENABLED＝false、西游存档都回旧页（三页的 skin 都是 null）。
## - 进阶：T254 3.10 对应表逐行断言（旧页用 RecCanvas 把状态窗画一遍收字，逐项核新页取得到）；按键流程（名单确定→焦点落到主按钮＝旧底部、
##   条件不够提示照旧、够了统一确认弹窗、确定后进阶完成）；云裳（要求里「天衣 n / N」、两行小字进右牌、中间换天衣列表＋面包屑，新旧两条路走完结果一样）；
##   五条悟（试炼一行 ✓／✗、只缺试炼时主按钮「挑战试炼」、确认弹窗标题＝旧确认窗字）。
## - 修炼场：T254 3.11 对应表（名单、每行的数与 XTraining.line 同一份、修满了变灰、右牌「现值 → 练完 ▲差」与真练完一致、八项收起／Y 展开、
##   目录确定直接进列表、列表确定就修、取消回目录）。
## - 技能遗忘：T254 3.12 对应表（每行名字＋记着／已遗忘、确定翻转不退出、按住连续翻、Q／E 翻页、主按钮字跟着变、空列表）。
## 带 -- --out=<目录> 且有窗口时截图：每页 16:9（800×450）＋20:9（1000×450）真尺寸（断言图就是这个尺寸）、各状态、字体 130%、旧画法对照。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const AdvT = preload("res://tests/xiyou_actor_advanced.gd")

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String, sz := Vector2i(800, 450)) -> void:
	if not windowed():
		return
	XSkinNoticeLane.reset()
	_clear_popups(get_tree().root)
	var win := get_window()
	var old := win.size
	win.size = sz
	await frames(12)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("size_" + name, img.get_size() == sz, [img.get_size(), sz])
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	win.size = old
	await frames(4)


func _clear_popups(n: Node) -> void:
	for c in n.get_children():
		if c is XToast or c is XAchievementPopup:
			c.queue_free()
		else:
			_clear_popups(c)


func shots(name: String) -> void:
	if not windowed():
		return
	await shot(name + "_16x9", Vector2i(800, 450))
	await shot(name + "_20x9", Vector2i(1000, 450))


func act(page: Node, action: String, echo := false) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	if echo:   # InputEventAction 没有 echo；按住连发用键盘事件
		var k := InputEventKey.new()
		k.keycode = KEY_ENTER
		k.physical_keycode = KEY_ENTER
		k.pressed = true
		k.echo = true
		page._unhandled_input(k)
		return
	page._unhandled_input(e)


func key(page: Node, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	page._unhandled_input(e)


func _tianqi(s: XState) -> XState:
	s.flags["tianqi"] = {"rules": 1}
	XState.current = s
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_o")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	await _gates()
	await _advance()
	await _advance_gojo()
	await _advance_yunshang()
	await _training()
	await _forget()
	await _font_and_old()
	XSkinRosterPage.ENABLED = true
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _adv_state() -> XState:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.gold = 0
	XToast.shown.clear()
	return _tianqi(s)


func _forget_page(a: XActor) -> XForgetSkillScene:
	var p := XForgetSkillScene.new().setup(a)
	add_child(p)
	return p


# ---- 开关 ----
func _gates() -> void:
	var built := []
	for tq in [false, true]:
		for enabled in [true, false]:
			var s := XState.new_game_blank()
			for id in [1, 8, 9, 10]:
				s.add_actor(id)
			XState.current = s
			if tq:
				_tianqi(s)
			XSkinRosterPage.ENABLED = enabled
			var a := XActorAdvancedScene.new()
			var t := XTrainingScene.new()
			var f := XForgetSkillScene.new().setup(s.members()[0])
			for p in [a, t, f]:
				add_child(p)
			await frames()
			built.append([tq, enabled, a.skin != null, t.skin != null, f.skin != null,
				a.status_win.visible, t.status_win.visible, f.win.visible])
			for p in [a, t, f]:
				p.queue_free()
			await frames()
	XSkinRosterPage.ENABLED = true
	check("gates", built == [[false, true, false, false, false, true, true, true], [false, false, false, false, false, true, true, true],
		[true, true, true, true, true, false, false, false], [true, false, false, false, false, true, true, true]], built)


# ---- 进阶 ----

## 旧状态窗画一遍收字（RecCanvas 只记 text）
func _old_status_texts(s: XState, actor_idx: int) -> Array:
	XSkinRosterPage.ENABLED = false
	var old := XActorAdvancedScene.new()
	add_child(old)
	await frames()
	old._select(actor_idx)
	var rec = AdvT.RecCanvas.new()
	rec.size = old.status_win.canvas.size
	old._paint_status(rec)
	var out: Array = rec.texts.map(func(t): return str(t[0]))
	rec.free()
	old.queue_free()
	await frames()
	XSkinRosterPage.ENABLED = true
	return out


static func card_texts(d: Dictionary) -> Array:
	var out := [str(d.get("title", "")), str(d.get("subtitle", ""))]
	for sec in d.get("sections", []):
		out.append(str(sec.get("title", "")))
		for ln in sec.get("lines", []):
			out.append(str(ln.get("left", "")))
			out.append(str(ln.get("right", "")))
		for r in sec.get("rows", []):
			out.append(str(r.get("text", "")))
		for c in sec.get("cells", []):
			out.append("%s %s" % [c[0], c[1]])
	for b in d.get("buttons", []):
		out.append(str(b.get("text", "")))
	return out


static func any_has(arr: Array, sub: String) -> bool:
	return arr.any(func(t): return str(t).contains(sub))


func _advance() -> void:
	var s := _adv_state()
	s.actor_advance[9] = 4   # 9 号到顶
	var olds := []
	for i in 4:
		olds.append(await _old_status_texts(s, i))
	var page := XActorAdvancedScene.new()
	add_child(page)
	await frames()
	check("adv_skin_built", page.skin != null and not page.list_win.visible and not page.bottom_win.visible and not page.gold_win.visible)
	var sk := page.skin
	# 名单：队伍全体名字（旧）→ 头像、名字、Lv、行尾「进阶 n / N」／「已到顶」
	var names_ok := sk.roster.items.size() == page.members.size()
	var right_ok := true
	for i in page.members.size():
		var m: XActor = page.members[i]
		var it: Dictionary = sk.roster.items[i]
		names_ok = names_ok and str(it.text) == m.display_name() and str(it.sub) == "Lv %d" % m.level and it.icon is Texture2D
		var want := "已到顶" if XAdvance.row(s, m.actor_id) == null else "进阶 %d / %d" % [XAdvance.rank(s, m.actor_id), XAdvance.max_text(s, m.actor_id)]
		right_ok = right_ok and str(it.right2) == want
	check("adv_roster_names", names_ok, sk.roster.items.map(func(x): return [x.text, x.sub]))
	check("adv_roster_rank", right_ok, sk.roster.items.map(func(x): return x.right2))
	check("adv_roster_top_gray", str(sk.roster.items[2].right2) == "已到顶" and sk.roster.items[2].right2_color == XUiSkin.TEXT_3)
	check("adv_no_tp_or_bars", not sk.roster.items[0].has("_hp"))   # 5AB-6：菜单名单不显示 TP（本页名单也不画量条）
	# 旧状态窗每一项（名字、等级、进阶次数、最大进阶次数、八项、需求物品与 xN、等级需求、金钱、进化技能／已满）新页都取得到
	for i in 4:
		page._select(i)
		await frames()
		var a: XActor = page.members[i]
		var cd := page.skin_center_data()
		var card := page.skin_card()
		var ct := card_texts(card)
		var old: Array = olds[i]
		var tag := "adv%d_" % i
		check(tag + "name", old.has(a.display_name()) and cd.name == a.display_name() and card.title == a.display_name())
		check(tag + "level", old.has("等级:%d" % a.level) and int(cd.level) == a.level)
		check(tag + "rank", old.has("进阶次数:%d" % XAdvance.rank(s, a.actor_id)) and int(cd.rank) == XAdvance.rank(s, a.actor_id))
		check(tag + "max", old.has("最大进阶次数:%d" % XAdvance.max_text(s, a.actor_id)) and int(cd.max) == XAdvance.max_text(s, a.actor_id))
		var pv := []
		for k in 8:
			pv.append(roundi(a.param(k)))
		check(tag + "params", cd.params == pv and pv.all(func(v): return old.has(str(v))), [cd.params, pv])
		check(tag + "battler", str(cd.battler) == str(a.data().get("battlerName", "")))
		var r = XAdvance.row(s, a.actor_id)
		if r == null:
			check(tag + "full", old.has("已达最大进阶次数") and ct.has("已达最大进阶次数") and bool(card.buttons[0].disabled) and cd.learn == null, ct)
			continue
		var item_ok := true
		for p in r.items:
			var nm := str(XDB.rec("Items", int(p[0])).get("name", ""))
			item_ok = item_ok and old.has(nm) and old.has("x%d" % int(p[1])) and any_has(ct, nm) and any_has(ct, "/ %s" % XMenu._group(int(p[1])))
		check(tag + "items", item_ok, [r.items, ct])
		check(tag + "need_level", old.has("等级:%d" % int(r.level)) and ct.has("Lv %d / %d" % [a.level, int(r.level)]), ct)
		check(tag + "gold", any_has(old, str(int(r.gold))) and any_has(ct, XMenu._group(int(r.gold))), [old, ct])
		var learn_ok: bool = cd.learn == ints(r.learn)
		for id in r.learn:
			learn_ok = learn_ok and old.has(str(XDB.rec("Skills", int(id)).get("name", "")))
		check(tag + "learn", learn_ok, [cd.learn, r.learn])
		var lack := XAdvance.missing(s, a)
		check(tag + "lack_always_shown", lack.is_empty() or ct.has("还差：" + "、".join(lack)), [lack, ct])
		check(tag + "button", str(card.buttons[0].text) == "进阶" and bool(card.buttons[0].disabled) == not lack.is_empty())
		check(tag + "checks_marks", (card.sections[0].lines as Array).all(func(ln): return str(ln.left).begins_with("✓ ") or str(ln.left).begins_with("✗ ")))
	await shots("adv_lacking")
	# 按键：名单确定 → 焦点到主按钮（旧底部窗）；条件不够 → 提示照旧、回名单
	page._select(0)
	await frames()
	act(page, "ui_accept")
	await frames()
	check("adv_bottom_focus_card", page.mode == "bottom" and sk.focus == "card" and sk.card.button_index == 0, [page.mode, sk.focus])
	await shots("adv_bottom")
	act(page, "ui_accept")
	await frames()
	var a0: XActor = page.members[0]
	var lack0 := XAdvance.missing(s, a0)
	check("adv_fail_toast", page.mode == "list" and XToast.shown.has(XAdvance.fail_text(lack0)) and sk.focus == "roster", [XToast.shown, page.mode])
	# 补齐 → 统一确认弹窗 → 确定 → 进阶
	var r0 = XAdvance.row(s, a0.actor_id)
	for p in r0.items:
		s.gain_item(int(p[0]), int(p[1]))
	a0.change_level(maxi(a0.level, int(r0.level)))
	s.gold = int(r0.gold) + 5
	page._refresh()
	await frames()
	check("adv_ready_button", not bool(page.skin_card().buttons[0].disabled) and not any_has(card_texts(page.skin_card()), "还差："))
	await shots("adv_ready")
	act(page, "ui_accept")
	act(page, "ui_accept")
	await frames()
	check("adv_confirm_dialog", page.mode == "confirm" and sk.dialog != null and sk.dialog.title == XActorAdvancedScene.CONFIRM_TEXT and sk.dialog.body.begins_with("消耗："), [page.mode, sk.dialog.title if sk.dialog else null])
	await shots("adv_confirm")
	var before := XAdvance.rank(s, a0.actor_id)
	act(page, "ui_accept")
	await frames()
	check("adv_done", XAdvance.rank(s, a0.actor_id) == before + 1 and XToast.shown.has(XAdvance.DONE_TEXT) and page.mode == "list" and sk.dialog == null, [XAdvance.rank(s, a0.actor_id), XToast.shown])
	# 弹窗取消（右键／取消键）回名单
	page._select(1)
	var r1 = XAdvance.row(s, page.members[1].actor_id)
	for p in r1.items:
		s.gain_item(int(p[0]), int(p[1]))
	page.members[1].change_level(maxi(page.members[1].level, int(r1.level)))
	s.gold = int(r1.gold)
	page.ok()
	page.ok()
	await frames()
	act(page, "ui_cancel")
	await frames()
	check("adv_confirm_cancel", page.mode == "list" and sk.dialog == null and XAdvance.rank(s, page.members[1].actor_id) == 0)
	# 触屏：主按钮（名单上点＝先到底部再按）
	sk.card_button.emit(0)
	await frames()
	check("adv_touch_button_confirm", page.mode == "confirm" and sk.dialog != null)
	act(page, "ui_cancel")
	await frames()
	# 已满：确定蜂鸣、不动
	page._select(2)
	page.ok()
	check("adv_full_stays", page.mode == "list")
	# 满：一屏放不下（20 人）
	for id in range(11, 31):
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	page.members = s.members()
	page._refresh()
	await frames()
	check("adv_roster_scroll", sk.roster.scrollable(), sk.roster.items.size())
	page._select(page.members.size() - 1)
	await frames()
	await shots("adv_full_roster")
	page.queue_free()
	await frames()


static func ints(a) -> Array:
	return Array(a).map(func(v): return int(v))


func _advance_gojo() -> void:
	const GOJO := 180
	var w := XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2]]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	XState.current = s
	for id in lineup + [GOJO]:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 132
	var a: XActor = s.actor(GOJO)
	if not s.party.has(GOJO):   # 天启篇满员时 add_actor 不加：直接排进队伍（本专项只看进阶页）
		s.party.append(GOJO)
	a.change_level(25)
	s.gold = 120000
	if not check("gojo_skin_on", XUiSkin.on(), XState.current.flags.get("tianqi")):
		return
	var page := XActorAdvancedScene.new()
	add_child(page)
	await frames()
	page._select(page.members.find(a))
	await frames()
	var card := page.skin_card()
	var ct := card_texts(card)
	var trial := "✗ 试炼：%s（未通过）" % XTianqiGojoTrial.trial_name(1)
	check("gojo_trial_line", ct.has(trial), ct)
	check("gojo_button_trial", str(card.buttons[0].text) == "挑战试炼" and not bool(card.buttons[0].disabled), card.buttons)
	await shots("adv_gojo")
	page.ok()
	page.ok()
	await frames()
	check("gojo_confirm", page.mode == "confirm" and page.skin.dialog != null and page.skin.dialog.title == "挑战试炼「%s」" % XTianqiGojoTrial.trial_name(1), page.confirm_text)
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.ok()
	check("gojo_request", closed[0] and XTianqiGojoTrial.has_request() and XAdvance.rank(s, GOJO) == 0)
	XTianqiGojoTrial.request(0)
	page.queue_free()
	await frames()
	# 试炼通过后：✓
	s.flags.tianqi[XTianqiGojoTrial.PASSED_KEY] = [1]
	var p2 := XActorAdvancedScene.new()
	add_child(p2)
	await frames()
	p2._select(p2.members.find(a))
	var ct2 := card_texts(p2.skin_card())
	check("gojo_trial_passed", ct2.has("✓ 试炼：%s（已通过）" % XTianqiGojoTrial.trial_name(1)) and str(p2.skin_card().buttons[0].text) == "进阶", ct2)
	# 天衣铺里打开（不开试炼）：主按钮回「进阶」并变灰
	s.flags.tianqi[XTianqiGojoTrial.PASSED_KEY] = []
	p2.allow_trial = false
	p2._refresh()
	var c3 := p2.skin_card()
	check("gojo_no_trial_in_shop", str(c3.buttons[0].text) == "进阶" and bool(c3.buttons[0].disabled), c3.buttons)
	p2.queue_free()
	await frames()


func _cloud(level: int) -> XState:
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	s.switches[2494] = true
	s.map_id = 4
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10, XYunshang.ACTOR]:
		s.add_actor(id)
	s.actor(XYunshang.ACTOR).change_level_mv(level)
	s.gain_item(2530, 60)
	for k in 4:
		s.gain_gear("armor", XYunshang.ROBE_FIRST + k, 1)
	return _tianqi(s)


func _advance_yunshang() -> void:
	var finals := []
	for skin_on in [false, true]:
		XSkinRosterPage.ENABLED = skin_on
		var s := _cloud(35)
		XToast.shown.clear()
		var a := s.actor(XYunshang.ACTOR)
		var page := XActorAdvancedScene.new()
		add_child(page)
		await frames()
		page._select(page.members.find(a))
		await frames()
		if skin_on:
			var ct := card_texts(page.skin_card())
			check("yun_req_robes", ct.has("✓ 天衣") and ct.has("4 / 3") and ct.has("背包天衣×3（确认时选择）") and ct.has("已装备的天衣须先卸下"), ct)
		page.ok()
		page.ok()
		await frames()
		check("yun_pick_mode_%s" % skin_on, page.mode == "yun")
		if skin_on:
			check("yun_center_list", page.yun_win == null and page.skin.list.visible and page.skin.list.items.size() == 4 and page.skin.list_title == "选择进阶所需天衣 0/3"
				and page._yun_crumb.visible and page._yun_crumb.parts == ["进阶", "选天衣"], [page.skin.list.items.size(), page.skin.list_title])
			var labels: Array = page.skin.list.items.map(func(x): return x.text)
			check("yun_labels_same", labels == page.yun_rows.slice(1).map(func(r): return r.text), labels)
			await shots("adv_yun_pick")
			act(page, "ui_down")
			act(page, "ui_accept")
			await frames()
			check("yun_pick1", page.skin.list_title == "选择进阶所需天衣 1/3" and page.skin.list.items.size() == 3)
			act(page, "ui_accept")
			act(page, "ui_accept")
			await frames()
		else:
			for k in 3:
				page.yun_win.chosen.emit(2 if k == 0 else 1)   # 第 0 行是「选择进阶所需天衣 n/N」
				await frames()
		check("yun_confirm_%s" % skin_on, page.mode == "confirm" and page.confirm_text == "消耗3件天衣，确认进阶", [page.mode, page.confirm_text])
		if skin_on:
			check("yun_dialog", page.skin.dialog != null and page.skin.dialog.title == "消耗3件天衣，确认进阶")
		page.ok()
		await frames()
		finals.append([XYunshang.stage(a), s.item_count(2530), XYunshangOrders.owned(s).map(func(e): return int(e.base)), XToast.shown.duplicate()])
		XToast.shown.clear()
		page.queue_free()
		await frames()
	XSkinRosterPage.ENABLED = true
	check("yun_same_result", finals[0] == finals[1] and int(finals[0][0]) == 1, finals)
	# 取消选天衣：回名单、选的作废
	var s2 := _cloud(35)
	var p2 := XActorAdvancedScene.new()
	add_child(p2)
	await frames()
	p2._select(p2.members.find(s2.actor(XYunshang.ACTOR)))
	p2.ok()
	p2.ok()
	act(p2, "ui_accept")
	act(p2, "ui_cancel")
	await frames()
	check("yun_cancel", p2.mode == "list" and p2.yun_selection == null and p2._yun_chosen.is_empty() and not p2.skin.list.visible)
	p2.queue_free()
	await frames()


# ---- 修炼场 ----
func _training() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	_tianqi(s)
	s.gold = 10000000
	s.set_variable(20, 15)   # 最高到达 15 层：天启篇修炼开到 5 级
	var page := XTrainingScene.new()
	add_child(page)
	await frames()
	var sk := page.skin
	check("tr_skin_built", sk != null and not page.list_win.visible and not page.index_win.visible and not page.gold_win.visible)
	check("tr_roster", sk.roster.items.map(func(x): return x.text) == s.members().map(func(m): return m.display_name()))
	var listed := XTraining.listed()
	var a := page.current()
	var lines := XTraining.lines(s, a.actor_id)
	# 每行的数取自 XTraining 同一份表：名字、等级、下一级费用（或等级已满）都在旧行文里
	var row_ok := sk.list.items.size() == listed.size()
	for i in listed.size():
		var it: Dictionary = sk.list.items[i]
		var e: Dictionary = listed[i]
		var lv := XTraining.level(s, a.actor_id, int(e.id))
		var ln := str(lines[i])
		row_ok = row_ok and ln.begins_with(str(it.text)) and ln.contains("%d/%d" % [lv, int(e.max)]) and str(it.right2) == "第 %d 级" % lv
		if lv < int(e.max) and not str(it.right).begins_with("本层"):
			row_ok = row_ok and ln.contains(str(it.right))
	check("tr_rows_from_lines", row_ok, [sk.list.items.map(func(x): return [x.text, x.right2, x.get("right", "")]), lines])
	check("tr_eight_folded", not any_has(card_texts(page.skin_card()), "八项能力"))
	await shots("tr_roster")
	# 目录确定直接进列表（没有底部「修炼」窗）
	act(page, "ui_accept")
	await frames()
	check("tr_into_list", page.mode == "list" and page.row == 0 and sk.focus == "list" and sk.list.active)
	act(page, "ui_down")
	await frames()
	check("tr_list_move", page.row == 1 and sk.list.index == 1)
	# 右牌「现值 → 练完 ▲差」＝真练完的值
	var e1: Dictionary = listed[1]
	var pv := XTrainingScene.preview(s, a, e1)
	var ct := card_texts(page.skin_card())
	check("tr_change_line", pv.size() == 2 and ct.has("%s → %s ▲%d" % [XMenu._group(pv[0]), XMenu._group(pv[1]), pv[1] - pv[0]]), [pv, ct])
	await shots("tr_list")
	var gold0 := s.gold
	act(page, "ui_accept")
	await frames()
	var lv1 := XTraining.level(s, a.actor_id, int(e1.id))
	check("tr_train", lv1 == 1 and XToast.shown.has("强化成功"), [lv1, XToast.shown])
	check("tr_preview_matches", int(a.param(int(e1.param))) == int(pv[1]) and s.gold < gold0, [a.param(int(e1.param)), pv])
	check("tr_stays_in_list", page.mode == "list" and page.row == 1)
	# Y 展开八项、再按收起；条也能点
	key(page, KEY_Y)
	await frames()
	var ct2 := card_texts(page.skin_card())
	var all8 := true
	for k in 8:
		all8 = all8 and ct2.has("%s %s" % [XTrainingScene.ATTR[k], XMenu._group(int(a.param(k)))])
	check("tr_y_expand", page.skin_open and all8 and sk.strip_open, ct2)
	await shots("tr_expanded")
	sk.toggle_strip()
	await frames()
	check("tr_strip_collapse", not page.skin_open and not sk.strip_open)
	# 取消回目录；再取消关闭
	act(page, "ui_cancel")
	await frames()
	check("tr_cancel_to_roster", page.mode == "index" and sk.focus == "roster" and page.skin_row == 1)
	# 本层没开到：行尾写「本层开到 N 级」（橙）
	s.set_variable(20, 1)
	page._refresh()
	await frames()
	check("tr_not_open_row", str(sk.list.items[2].right) == "本层开到 0 级" and sk.list.items[2].right_color == XUiSkin.DOWN, sk.list.items[2])
	s.set_variable(20, 99)
	# 修满了：变灰写「修满了」
	for k in 20:
		XTraining.confirm(s, a.actor_id, int(listed[0].id))
	page._refresh()
	await frames()
	var it0: Dictionary = sk.list.items[0]
	var full0 := XTraining.level(s, a.actor_id, int(listed[0].id)) >= int(listed[0].max)
	check("tr_full_row", not full0 or (str(it0.right) == "修满了" and bool(it0.get("disabled", false))), it0)
	if full0:
		page.skin_row = 0
		page._refresh()
		await frames()
		check("tr_full_card", any_has(card_texts(page.skin_card()), "修满了") and bool(page.skin_card().buttons[0].disabled))
		await shots("tr_full")
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	act(page, "ui_cancel")
	check("tr_close", closed[0])
	page.queue_free()
	await frames()
	# 西游表（非天启篇金钱重构）：同一套行文
	var old_on := XTianqiMoney.TRAINING
	XTianqiMoney.TRAINING = false
	var s2 := XState.new_game(3, 1, [8, 9, 10])
	_tianqi(s2)
	s2.gold = 100000000
	var p2 := XTrainingScene.new()
	add_child(p2)
	await frames()
	var a2 := p2.current()
	var lines2 := XTraining.lines(s2, a2.actor_id)
	var ok2 := p2.skin.list.items.size() == lines2.size()
	for i in lines2.size():
		var it: Dictionary = p2.skin.list.items[i]
		ok2 = ok2 and str(lines2[i]).begins_with(str(it.text)) and (str(it.get("right", "")) == "修满了" or str(lines2[i]).contains(str(it.right)))
	check("tr_classic_rows", ok2, [p2.skin.list.items.map(func(x): return [x.text, x.get("right", "")]), lines2])
	var pv2 := XTrainingScene.preview(s2, a2, XTraining.listed()[0])
	var e0: Dictionary = XTraining.listed()[0]
	s2.training[str(a2.actor_id)] = {str(int(e0.id)): 1}   # 西游表首项一级 5 亿，钱给不起：直接写等级核预览
	check("tr_classic_preview", pv2.size() == 2 and int(a2.param(int(e0.param))) == int(pv2[1]) and int(pv2[1]) - int(pv2[0]) == int(e0.value), [pv2, a2.param(int(e0.param))])
	s2.training.erase(str(a2.actor_id))
	XTianqiMoney.TRAINING = old_on
	p2.queue_free()
	await frames()


# ---- 技能遗忘 ----
func _forget() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	_tianqi(s)
	var a: XActor = s.members()[0]
	var ids := []
	for id in range(1, 600):
		var r := XDB.rec("Skills", id)
		if not r.is_empty() and str(r.get("name", "")) != "" and int(r.get("stypeId", 0)) in XForgetSkillScene.TYPES:
			ids.append(id)
		if ids.size() >= 16:
			break
	for id in ids:
		if not a.skill_ids.has(id):
			a.learn_skill(id)
	var page := _forget_page(a)
	await frames()
	var sk := page.skin
	check("fg_skin_built", sk != null and not page.win.visible and not sk.roster_panel.visible)
	var row_ok := sk.list.items.size() == page.rows.size()
	for i in page.rows.size():
		var it: Dictionary = sk.list.items[i]
		row_ok = row_ok and str(it.text) == str(XDB.rec("Skills", page.rows[i].id).get("name", "")) and str(it.right) == "记着"
	check("fg_rows", row_ok)
	check("fg_card_button", str(page.skin_card().buttons[0].text) == "遗忘" and any_has(card_texts(page.skin_card()), "遗忘了会怎样"))
	await shots("fg_normal")
	var id0 := int(page.rows[0].id)
	act(page, "ui_accept")
	await frames()
	check("fg_toggle", not a.skill_ids.has(id0) and str(sk.list.items[0].right) == "已遗忘" and sk.list.items[0].right_color == XUiSkin.DOWN and page.is_inside_tree())
	check("fg_card_recall", str(page.skin_card().buttons[0].text) == "记回来")
	await shots("fg_forgotten")
	act(page, "ui_accept", true)   # 按住连发＝再翻一次
	await frames()
	check("fg_hold_repeat", a.skill_ids.has(id0) and str(sk.list.items[0].right) == "记着")
	act(page, "ui_down")
	await frames()
	check("fg_move", page.index == 1 and sk.list.index == 1)
	key(page, KEY_E)
	await frames()
	check("fg_page", page.index > 1 and sk.list.index == page.index, [page.index, sk.list.index])
	await shots("fg_paged")
	sk.card_button.emit(0)
	await frames()
	check("fg_touch_button", str(sk.list.items[page.index].right) == "已遗忘")
	sk.card_button.emit(0)
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	act(page, "ui_cancel")
	check("fg_close", closed[0])
	page.queue_free()
	await frames()
	# 空列表
	var b: XActor = s.members()[1]
	for id in XForgetSkillScene.listed_skills(b):
		b.forget_skill(int(id))
	var pe := _forget_page(b)
	await frames()
	check("fg_empty", pe.skin.list.items.is_empty() and not pe.skin.card.visible and pe.skin.list.empty_text == XForgetSkillScene.T_EMPTY)
	await shots("fg_empty")
	pe.queue_free()
	await frames()


# ---- 字体 130%、旧画法对照 ----
func _font_and_old() -> void:
	XFontScale.set_value("global", 130)
	var s := _adv_state()
	var page := XActorAdvancedScene.new()
	add_child(page)
	await frames()
	await shots("adv_font130")
	page.queue_free()
	var t := XTrainingScene.new()
	add_child(t)
	await frames()
	t.ok()
	t.skin_open = true
	t._refresh()
	await shots("tr_font130")
	t.queue_free()
	var f := _forget_page(s.members()[0])
	await frames()
	await shots("fg_font130")
	f.queue_free()
	XFontScale.set_value("global", 100)
	await frames()
	XSkinRosterPage.ENABLED = false
	page = XActorAdvancedScene.new()
	add_child(page)
	await frames()
	check("old_adv", page.skin == null and page.status_win.visible)
	await shot("adv_old_16x9")
	page.queue_free()
	t = XTrainingScene.new()
	add_child(t)
	await frames()
	check("old_tr", t.skin == null and t.list_win.visible)
	await shot("tr_old_16x9")
	t.queue_free()
	f = _forget_page(s.members()[0])
	await frames()
	check("old_fg", f.skin == null and f.win.visible)
	await shot("fg_old_16x9")
	f.queue_free()
	XSkinRosterPage.ENABLED = true
	await frames()
