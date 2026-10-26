extends Node
## 角色进阶（XAdvance／XActorAdvancedScene）：对照冻结 v0.28 浏览器参照 tests/fixtures/actor_advanced_oracle.json
## （ui_reference/review_system_pages.js 的 actor_advanced：内存新局 1/8/9/10，金币 0；依次第 2 行、第 1 行确定、条件不足、
## 补齐物品与金币再确定、确认窗、取消、再走一遍、进阶完成、角色 9 次数设 4、已满确定）：
## 11 个截图状态的全部窗口文字（坐标与宽差 ≤ POS_TOL，字号、对齐、颜色相等）、窗口矩形、三处光标与活动、提示、金钱、
## 进阶次数、学会的技能、需求物品数量、队伍四人 8 项能力值（进阶后由被动技能 1240 加成）、状态窗精灵（图、行、格宽、位置、放大）。
## 这一段照原版（O-094 两个开关关掉）。再测：O-094 列缺项与已满蜂鸣、进阶表导出（经济合并 184～187→188）、
## 等级不足、遗忘技能、存读档（旧档没有为 0）、奉神老妪 Map132 EV6「进阶」分支打开界面。

const FIXTURE := "res://tests/fixtures/actor_advanced_oracle.json"
const DIR := "user://test_xiyou_actor_advanced"
## 「xN」与能力值的横坐标由字宽推出（Godot 字体与浏览器差零点几像素）
const POS_TOL := 1.0
## 每个状态之后等的物理帧（参照每步 settle 约 24 帧以上）
const SETTLE := 30

var results := []
var out_dir := ""


## 只记 drawText 的画布：拿窗口的 painter 画一遍，收集文字
class RecCanvas extends XMVCanvas:
	var texts := []
	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, _lh := XUI.LINE_HEIGHT, _alpha := 1.0, _zoom := 1.0, _pivot := Vector2.ZERO, _outline := OUTLINE) -> void:
		if s != "":
			texts.append([s, x, y, max_w, align, float(size), color.to_html(false)])
	func icon(_i: int, _x: float, _y: float, _alpha := 1.0, _size := 32.0) -> void:
		pass
	func cursor(_r: Rect2, _active := true) -> void:
		pass


class FakeHost extends Node:
	var opened := 0
	func open_actor_advanced() -> void:
		opened += 1
		await get_tree().process_frame
	func refresh_events() -> void:
		pass
	func character(_id: int, _event_id: int):
		return null


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	XSave.dir_override = DIR
	XConfig.path_override = ""
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().physics_frame


func shot(name: String) -> void:
	await frames(SETTLE)
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


static func record(win: XMVWindow) -> Array:
	var c := RecCanvas.new()
	c.size = win.canvas.size
	win.canvas.painter.call(c)
	var out: Array = c.texts
	c.free()
	return _sorted(out)


## 参照颜色有 #rrggbb 与 rgba(r,g,b,a) 两种写法
static func _color(t: String) -> String:
	return XQuality.parse_rgba(t).to_html(false) if t.begins_with("rgba") else Color(t).to_html(false)


## 行首空格（底部「进阶」前 44 个）按原版空格宽折成横坐标，同界面的画法
static func want_form(texts: Array) -> Array:
	return _sorted(texts.map(func(t):
		var word := str(t[0]).strip_edges(true, false)
		var pad := (str(t[0]).length() - word.length()) * XTrainingScene.SPACE_W
		return [word, float(t[1]) + pad, float(t[2]), float(t[3]) - pad, str(t[4]), float(t[5]), _color(str(t[6]))]))


static func _sorted(a: Array) -> Array:
	a.sort_custom(func(x, y): return [x[2], x[1], str(x[0])] < [y[2], y[1], str(y[0])])
	return a


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		for k in w.size():
			var bad: bool = str(g[k]) != w[k] if w[k] is String else absf(float(g[k]) - float(w[k])) > POS_TOL
			if bad:
				return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


static func ints(a) -> Array:
	return Array(a).map(func(v): return int(v))


func _setup() -> XState:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.gold = 0
	XState.current = s
	XToast.shown.clear()
	return s


func _compare(ref: Dictionary, name: String, page: XActorAdvancedScene) -> void:
	var w: Dictionary = ref.shots[name].windows
	var ex: Dictionary = ref.shots[name].extra
	var s := XState.current
	var bad := []
	var parts := {"Window_ActorAdvancedIndex": page.list_win, "Window_ActorAdvancedStatus": page.status_win,
		"Window_ActorAdvancedGold": page.gold_win, "Window_AAdvBottomConfirm": page.bottom_win, "Window_SaveConfirm": page.confirm_win}
	for k in parts:
		var c: Control = parts[k]
		var open := int(w[k].openness) > 0
		if c.visible != open:
			bad.append("%s 开合 %s" % [k, c.visible])
		if not open:
			continue
		var d := diff(record(parts[k]), want_form(w[k].texts))
		if d != "":
			bad.append("%s %s" % [k, d])
		var r: Array = w[k].rect.map(func(v): return float(v))
		if Vector2(c.position.x, c.position.y).distance_to(Vector2(r[0], r[1])) > 0.01 or Vector2(c.size.x, c.size.y) != Vector2(r[2], r[3]):
			bad.append("%s 矩形 %s" % [k, [c.position.x, c.position.y, c.size.x, c.size.y]])
	if page.index != int(ex.index.index) or (page.mode == "list") != bool(ex.index.active):
		bad.append("名单光标 %d %s" % [page.index, page.mode])
	if page.bottom != int(ex.bottom.index) or (page.mode == "bottom") != bool(ex.bottom.active):
		bad.append("底部光标 %d %s" % [page.bottom, page.mode])
	if page.confirm_win.visible and (page.confirm_index != int(ex.confirm.index) or (page.mode == "confirm") != bool(ex.confirm.active)):
		bad.append("确认光标 %d %s" % [page.confirm_index, page.mode])
	if XToast.shown != Array(ex.toasts):
		bad.append("提示 %s" % JSON.stringify(XToast.shown))
	if s.gold != int(ex.gold) or s.item_count(188) != int(ex.item188) or s.item_count(180) != int(ex.item180):
		bad.append("金钱物品 %d %d %d" % [s.gold, s.item_count(188), s.item_count(180)])
	if s.actor(1).skill_ids.has(1240) != bool(ex.actor1.has1240):
		bad.append("技能 %s" % JSON.stringify(s.actor(1).skill_ids))
	for i in ex.members.size():
		var m: Dictionary = ex.members[i]
		var a := s.actor(int(m.id))
		var params := range(8).map(func(p): return roundi(a.param(p)))
		if params != ints(m.params):
			bad.append("能力 %d %s" % [a.actor_id, JSON.stringify(params)])
		if XAdvance.rank(s, a.actor_id) != int(m.get("num", 0)):
			bad.append("次数 %d %d" % [a.actor_id, XAdvance.rank(s, a.actor_id)])
	# 状态窗精灵：图、行（frame y）、格宽高、位置与放大；格的横坐标随帧变（0,1,2,1）
	var sp: Dictionary = ex.sprite
	var spr := page.sprite
	var path := str(sp.bitmap).get_file().get_basename()
	var reg := spr.region_rect
	if spr.texture == null or not spr.visible or path != str(page.shown_actor.data().battlerName) \
			or [reg.position.y, reg.size.x, reg.size.y] != [float(sp.frame[1]), float(sp.frame[2]), float(sp.frame[3])] \
			or [spr.texture.get_width(), spr.texture.get_height()] != ints(sp.bitmapSize):
		bad.append("精灵 %s %s" % [path, reg])
	if spr.position.distance_to(Vector2(float(sp.x), float(sp.y))) > 0.01 or spr.scale != Vector2(float(sp.scale[0]), float(sp.scale[1])):
		bad.append("精灵位置 %s %s" % [spr.position, spr.scale])
	check(name, bad.is_empty(), bad)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("shots", {}).has("adv_0"), FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	XAdvance.SHOW_MISSING = false
	XAdvance.MAX_BUZZER = false
	await _flow(ref)
	XAdvance.SHOW_MISSING = true
	XAdvance.MAX_BUZZER = true
	await _optimized()
	_rows()
	_rules()
	_save()
	await _interpreter()
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	var toast := get_tree().root.get_node_or_null("XToast")
	if toast:
		toast.queue_free()
	await get_tree().create_timer(0.3, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _flow(ref: Dictionary) -> void:
	var s := _setup()
	var page := XActorAdvancedScene.new()
	add_child(page)
	await shot("adv_0")
	_compare(ref, "adv_0", page)
	page._select(1)
	await shot("adv_1_row1")
	_compare(ref, "adv_1_row1", page)
	page._select(0)
	await frames(SETTLE)
	page.ok()
	await shot("adv_2_bottom")
	_compare(ref, "adv_2_bottom", page)
	page.ok()
	await shot("adv_3_fail")
	_compare(ref, "adv_3_fail", page)
	var r = XAdvance.row(s, 1)
	for p in r.items:
		s.gain_item(int(p[0]), int(p[1]))
	s.gold = int(r.gold)
	page._draw_status()
	await frames(SETTLE)
	page.ok()
	await shot("adv_4_ready")
	_compare(ref, "adv_4_ready", page)
	page.ok()
	await shot("adv_5_confirm")
	_compare(ref, "adv_5_confirm", page)
	page.cancel()
	await shot("adv_6_cancel")
	_compare(ref, "adv_6_cancel", page)
	page.ok()
	await frames(SETTLE)
	page.ok()
	await shot("adv_7_confirm2")
	_compare(ref, "adv_7_confirm2", page)
	page.ok()
	await shot("adv_8_done")
	_compare(ref, "adv_8_done", page)
	s.actor_advance[9] = 4
	page._select(2)
	await shot("adv_9_max")
	_compare(ref, "adv_9_max", page)
	page.ok()
	await shot("adv_10_max_ok")
	_compare(ref, "adv_10_max_ok", page)
	check("max_ok_sound_original", XSound.system_log.back() == 1, XSound.system_log.slice(-2))
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.cancel()
	check("list_cancel_closes", closed[0])
	page.queue_free()
	await frames()


## O-094：条件不足列出缺项；已满确定蜂鸣；确认窗「否」回名单
func _optimized() -> void:
	var s := _setup()
	s.gain_item(188, 1)
	var page := XActorAdvancedScene.new()
	add_child(page)
	await frames()
	page.ok()
	page.ok()
	check("fail_lists_missing", XToast.shown == ["进阶条件未达成：精魂不足"] and page.mode == "list", XToast.shown)
	s.gold = 100000
	page.ok()
	page.ok()
	page._move(1, false)
	page.ok()
	check("confirm_no_back", page.mode == "list" and not page.confirm_win.visible and XAdvance.rank(s, 1) == 0 and s.gold == 100000)
	s.actor_advance[1] = 4
	page._draw_status()
	page.ok()
	check("max_buzzer", page.mode == "list" and XSound.system_log.back() == 3, XSound.system_log.slice(-2))
	page.queue_free()
	await frames()


## 进阶表：462 行＋渡鸦开机补的 5 行（finishRavenDatabaseCompatibility，表尾 473～477）＝467；经济合并后不再有 184～187；角色 1 各阶需求
func _rows() -> void:
	var rs := XAdvance.rows()
	check("rows_count", rs.size() == 467, rs.size())
	check("rows_no_old_currency", not rs.any(func(r): return r.items.any(func(p): return p[0] >= 184 and p[0] <= 187)))
	var a1 := rs.filter(func(r): return int(r.actor) == 1)
	check("actor1_rows", a1.size() == 4 and a1.slice(0, 3).map(func(r): return [r.num, r.max, r.gold, r.items, r.learn]) == [
		[0, 4, 100000, [[188, 1]], [1240]], [1, 4, 500000, [[188, 2], [180, 15]], [1241]],
		[2, 4, 100000, [[188, 3], [180, 30]], [1242, 1233]]], a1.map(func(r): return [r.num, r.gold, r.items]))
	check("js_literal", str(XAdvance._list("[1244,5846,]")) == str([1244.0, 5846.0]) and str(XAdvance._list("[[2793,1]],[[180,1]]")) == str([[180.0, 1.0]]) and XAdvance._list("[]") == [] and XAdvance._list("") == [])
	check("merge_costs", XAdvance._merge_costs([[184, 1], [180, 2], [186, 3]]) == [[188, 4], [180, 2]] and XAdvance._merge_costs([[5, 1]]) == [[5, 1]])


## 规则：等级不足、遗忘技能、没有下一阶
func _rules() -> void:
	var s := _setup()
	var lv = null
	for r in XAdvance.rows():
		if int(r.level) > 1 and int(r.num) == 0 and not XDB.rec("Actors", int(r.actor)).is_empty():
			lv = r
			break
	if check("level_row_found", lv != null):
		var a := s.actor(int(lv.actor))
		var lack := XAdvance.missing(s, a)
		check("level_missing", lack.size() >= 1 and str(lack[0]) == "等级%d/%d" % [a.level, int(lv.level)], lack)
	var fr = null
	for r in XAdvance.rows():
		if not r.forget.is_empty() and not XDB.rec("Actors", int(r.actor)).is_empty():
			fr = r
			break
	if check("forget_row_found", fr != null):
		var a := s.actor(int(fr.actor))
		s.actor_advance[a.actor_id] = int(fr.num)
		for id in fr.forget:
			a.learn_skill(int(id))
		check("advance_forgets", XAdvance.advance(s, a) and not fr.forget.any(func(id): return a.skill_ids.has(int(id))) \
			and fr.learn.all(func(id): return a.skill_ids.has(int(id))) and XAdvance.rank(s, a.actor_id) == int(fr.num) + 1, a.skill_ids)
	s.actor_advance[1] = 4
	check("no_row_at_max", XAdvance.row(s, 1) == null and XAdvance.max_text(s, 1) == 4 and not XAdvance.advance(s, s.actor(1)) and XAdvance.missing(s, s.actor(1)) == ["已满"])


## 进阶次数随局内存档；旧档没有为 0；坏值丢掉
func _save() -> void:
	var s := _setup()
	s.actor_advance[1] = 2
	s.actor_advance[9] = 1
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	check("save_key", d.get("actorAdvance") == {"1": 2.0, "9": 1.0} or d.get("actorAdvance") == {"1": 2, "9": 1}, d.get("actorAdvance"))
	var s2 := XState.from_dict(d)
	check("save_roundtrip", XAdvance.rank(s2, 1) == 2 and XAdvance.rank(s2, 9) == 1 and XAdvance.rank(s2, 8) == 0, s2.actor_advance)
	d.erase("actorAdvance")
	check("old_save_zero", XState.from_dict(d).actor_advance.is_empty())
	check("from_save_junk", XAdvance.from_save({"x": 1, "3": "a", "4": -1, "5": 3}) == {5: 3})


## 奉神老妪 Map132 EV6：选「进阶」打开界面
func _interpreter() -> void:
	var ev: Dictionary = {}
	for e in XDB.map(132).events:
		if e is Dictionary and int(e.get("id", 0)) == 6:
			ev = e
	if not check("map132_ev6_present", not ev.is_empty()):
		return
	var h := FakeHost.new()
	add_child(h)
	_setup()
	var it := MVInterpreter.new(h, 132, 6, _branch(ev.pages[0].list))
	await it.run()
	check("ev6_opens", h.opened == 1 and it.skipped.is_empty(), [h.opened, it.skipped.slice(0, 3)])
	h.queue_free()
	await frames()


## 「进阶」分支（402 选项 0 之下）的指令，前后补成独立列表
func _branch(list: Array) -> Array:
	var out := []
	var inside := false
	for c in list:
		if int(c.code) == 402:
			inside = int(c.parameters[0]) == 0
			continue
		if inside and int(c.indent) >= 1:
			out.append({"code": c.code, "indent": int(c.indent) - 1, "parameters": c.parameters})
	out.append({"code": 0, "indent": 0, "parameters": []})
	return out
