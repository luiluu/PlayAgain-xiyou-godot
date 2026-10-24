extends Node
## 更衣（XChangeClothes／XChangeClothesScene）：对照冻结 v0.28 浏览器参照 tests/fixtures/change_clothes_oracle.json
## （ui_reference/review_system_pages.js 的 change_clothes：内存新局 1/8/9/10，仓库 [13]，解锁表先放 -9/-12/-20；
## 依次更换、优秀档、确定、未解锁行与确定、修 确定替换、名单取消、神话档确定、牛头人酋长 确定替换、典藏档、回底部还原）：
## 12 个截图状态的全部窗口文字（坐标与宽差 ≤ POS_TOL，字号、对齐、颜色相等）、窗口矩形、三处光标、名单条目与滚动、
## 解锁表、提示、玩家替换形象、状态窗精灵（图、行、格宽、位置、放大）。这一段照原版分档（FIX_TABS=false）。
## 再测：O-093 分档（神话列神话角色、典藏列换装表）与空表确定蜂鸣、解锁表写盘与读回、存读档（旧档没有为空）、
## 替换形象只换玩家、衣橱管理员 Map4 EV17 两页脚本（第 0 页解锁换装表全部 95 项并打开界面）、别处的解锁写法不重复加。

const FIXTURE := "res://tests/fixtures/change_clothes_oracle.json"
const DIR := "user://test_xiyou_change_clothes"
## 「形象展示」的横坐标由字宽推出（Godot 字体与浏览器差零点几像素）
const POS_TOL := 1.0
## 每个状态之后等的物理帧（参照每步 settle 约 24 帧以上；状态窗每 20 帧检查一次）
const SETTLE := 30

var results := []
var out_dir := ""


## 只记 drawText 的画布：拿窗口的 painter 画一遍，收集文字
class RecCanvas extends XMVCanvas:
	var texts := []
	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, _lh := XUI.LINE_HEIGHT, _alpha := 1.0, _zoom := 1.0, _pivot := Vector2.ZERO, _outline := OUTLINE) -> void:
		if s != "":
			texts.append([s, x, y, max_w, align, float(size), color.to_html(false)])
	func character(_n: String, _i: int, _x: float, _y: float, _h := 0.0, _alpha := 1.0) -> void:
		pass
	func cursor(_r: Rect2, _active := true) -> void:
		pass


class FakeHost extends Node:
	var opened := 0
	func open_change_clothes() -> void:
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


static func want_form(texts: Array) -> Array:
	return _sorted(texts.map(func(t): return [str(t[0]), float(t[1]), float(t[2]), float(t[3]), str(t[4]), float(t[5]), Color(str(t[6])).to_html(false)]))


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
	s.actor(13)
	s.saved_actors.assign([13])
	XState.current = s
	var lite := XConfig.clothes_unlocked()
	lite.clear()
	lite.append_array([-9, -12, -20])
	return s


func _compare(ref: Dictionary, name: String, page: XChangeClothesScene) -> void:
	var w: Dictionary = ref.shots[name].windows
	var st: Dictionary = ref.shots[name].state
	var s := XState.current
	var bad := []
	var parts := {"Window_ChangeClothesC": page.cat_win, "Window_ChangeClothesIndex": page.list_win,
		"Window_ChangeClothesStatus": page.status_win, "Window_ChangeClothesConfirm": page.bottom_win}
	for k in parts:
		var d := diff(record(parts[k]), want_form(w[k].texts))
		if d != "":
			bad.append("%s %s" % [k, d])
		var c: Control = parts[k]
		if [c.position.x, c.position.y, c.size.x, c.size.y] != w[k].rect.map(func(v): return float(v)):
			bad.append("%s 矩形 %s" % [k, [c.position.x, c.position.y, c.size.x, c.size.y]])
	if page.category != int(st.category.index) or (page.mode == "category") != bool(st.category.active):
		bad.append("分类光标 %d %s" % [page.category, page.mode])
	if page.index != int(st.list.index) or (page.mode == "list") != bool(st.list.active) or page.top != int(st.list.top):
		bad.append("名单光标 %d %d %s" % [page.index, page.top, page.mode])
	if page.bottom != int(st.bottom.index) or (page.mode == "bottom") != bool(st.bottom.active):
		bad.append("底部光标 %d %s" % [page.bottom, page.mode])
	if page.rows() != int(st.list.maxPageRows):
		bad.append("可见行 %d" % page.rows())
	var ids := page.data.map(func(e): return int(e.id))
	if ids != ints(st.list.ids):
		bad.append("名单 %s" % JSON.stringify(ids))
	if ints(XConfig.clothes_unlocked()) != ints(st.lite):
		bad.append("解锁表 %s" % JSON.stringify(XConfig.clothes_unlocked()))
	if XToast.shown != Array(st.toasts):
		bad.append("提示 %s" % JSON.stringify(XToast.shown))
	var leader := s.leader().data()
	var img := XChangeClothes.player_image(s, str(leader.characterName), int(leader.characterIndex))
	if img != [str(st.player.characterName), int(st.player.characterIndex)] or s.player_costume.is_empty() != (st.player.get("setName") == null):
		bad.append("玩家形象 %s %s" % [JSON.stringify(img), JSON.stringify(s.player_costume)])
	# 状态窗精灵：图、行（frame y）、格宽高、位置与放大；格的横坐标随帧变（0→1→2）
	var sp: Dictionary = st.sprite
	var spr := page.sprite
	var has_tex := spr.texture != null and spr.visible
	if has_tex != (sp.bitmap != null):
		bad.append("精灵有无 %s" % has_tex)
	elif has_tex:
		var path := str(sp.bitmap).get_file().get_basename()
		var r := spr.region_rect
		var want_col0 := float(sp.frame[0]) - fmod(float(sp.frame[0]) / float(sp.frame[2]), 3.0) * float(sp.frame[2])
		var got_col0 := r.position.x - fmod(r.position.x / r.size.x, 3.0) * r.size.x
		if path != str(page.status_entry.characterName) or [r.position.y, r.size.x, r.size.y] != [float(sp.frame[1]), float(sp.frame[2]), float(sp.frame[3])] \
				or got_col0 != want_col0 or [spr.texture.get_width(), spr.texture.get_height()] != ints(sp.bitmapSize):
			bad.append("精灵 %s %s" % [path, r])
		if spr.position.distance_to(Vector2(float(sp.x), float(sp.y))) > 0.01 or spr.scale != Vector2(2, 2):
			bad.append("精灵位置 %s %s" % [spr.position, spr.scale])
	check(name, bad.is_empty(), bad)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("shots", {}).has("cc_0"), FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	XChangeClothes.FIX_TABS = false
	await _flow(ref)
	await _empty_list()
	XChangeClothes.FIX_TABS = true
	_tabs()
	_config()
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
	_setup()
	XToast.shown.clear()
	var page := XChangeClothesScene.new()
	add_child(page)
	await shot("cc_0")
	_compare(ref, "cc_0", page)
	page.ok()
	await shot("cc_1_change")
	_compare(ref, "cc_1_change", page)
	page._select_category(1)
	await shot("cc_2_cat1")
	_compare(ref, "cc_2_cat1", page)
	page.ok()
	await shot("cc_3_cat1_ok")
	_compare(ref, "cc_3_cat1_ok", page)
	page._select(3)
	await shot("cc_4_locked")
	_compare(ref, "cc_4_locked", page)
	page.ok()
	await shot("cc_5_locked_ok")
	_compare(ref, "cc_5_locked_ok", page)
	page._select(0)
	await frames(SETTLE)
	page.ok()
	await shot("cc_6_apply")
	_compare(ref, "cc_6_apply", page)
	page.cancel()
	await shot("cc_7_list_cancel")
	_compare(ref, "cc_7_list_cancel", page)
	page._select_category(6)
	await frames(SETTLE)
	page.ok()
	await shot("cc_8_myth")
	_compare(ref, "cc_8_myth", page)
	page._select(3)
	await frames(SETTLE)
	page.ok()
	await shot("cc_9_myth_apply")
	_compare(ref, "cc_9_myth_apply", page)
	page.cancel()
	await frames(SETTLE)
	page._select_category(7)
	await shot("cc_10_dian")
	_compare(ref, "cc_10_dian", page)
	page.cancel()
	await frames(SETTLE)
	page.bottom = 1
	page.ok()
	await shot("cc_11_restore")
	_compare(ref, "cc_11_restore", page)
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.cancel()
	check("bottom_cancel_closes", closed[0])
	page.queue_free()
	await frames()


## 原版分档的典藏是空表：确定后名单光标落在第 1 行（无条目），再确定原版报错；重制蜂鸣、形象不变
func _empty_list() -> void:
	var s := _setup()
	var page := XChangeClothesScene.new()
	add_child(page)
	await frames()
	page.ok()
	page._select_category(7)
	page.ok()
	var before := s.player_costume.duplicate()
	page.ok()
	check("empty_list_buzzer", page.mode == "list" and page.data.is_empty() and XSound.system_log.back() == 3 and s.player_costume == before,
		[page.mode, page.data.size(), XSound.system_log.slice(-2)])
	page.queue_free()
	await frames()


## O-093：神话档列神话角色（actorGrade 6），典藏档列换装表
func _tabs() -> void:
	var myth := XChangeClothes.list(6)
	var dian := XChangeClothes.list(7)
	check("fix_myth_actors", myth.size() == 64 and myth.all(func(d): return int(d.id) > 0 and XChangeClothes.actor_grade(d) == 6), myth.size())
	check("fix_dian_entries", dian.size() == 95 and int(dian[0].id) == -9 and int(dian.back().id) == -117, dian.size())
	check("grades_unchanged", XChangeClothes.list(1).map(func(d): return int(d.id)) == [8, 9, 10, 11, 16, 21, 22])
	check("entry_fields", XChangeClothes.entries()[3] == {"id": -12, "name": "牛头人酋长", "characterName": "Monster", "characterIndex": 3, "GetFs": "形象卡片"},
		XChangeClothes.entries()[3])


## 解锁表在全局配置：解锁即写盘，换路径读回；打开界面补队伍与仓库的角色
func _config() -> void:
	var path := DIR.path_join("options.json")
	DirAccess.make_dir_recursive_absolute(DIR)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	XConfig.path_override = path
	XConfig.ensure_loaded()
	check("config_default_empty", XConfig.clothes_unlocked().is_empty())
	XChangeClothes.unlock(-34)
	XChangeClothes.unlock(-34)
	var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	check("config_written", data is Dictionary and ints(data.get("ChangeClothesLite", [])) == [-34], data)
	var s := XState.new_game_blank()
	for id in [1, 8]:
		s.add_actor(id)
	s.saved_actors.assign([13])
	XChangeClothes.on_open(s)
	XConfig.path_override = DIR.path_join("other.json")
	XConfig.ensure_loaded()
	check("config_other_empty", XConfig.clothes_unlocked().is_empty())
	XConfig.path_override = path
	XConfig.ensure_loaded()
	check("config_reloaded", ints(XConfig.clothes_unlocked()) == [-34, 1, 8, 13], XConfig.clothes_unlocked())
	XConfig.path_override = ""
	XConfig.ensure_loaded()


## 替换形象随局内存档；旧档没有为空；只换玩家（跟随用各自角色的行走图）
func _save() -> void:
	var s := _setup()
	XConfig.clothes_unlocked().append(-12)
	check("apply_unlocked", XChangeClothes.apply(s, XChangeClothes.entries()[3]))
	check("apply_locked", not XChangeClothes.apply(s, XChangeClothes.entries()[1]) and s.player_costume.characterName == "Monster")
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2 := XState.from_dict(d)
	check("save_roundtrip", s2.player_costume == {"characterName": "Monster", "characterIndex": 3}, s2.player_costume)
	check("player_image", XChangeClothes.player_image(s2, "PF_3", 6) == ["Monster", 3] and XChangeClothes.player_image(XState.new_game_blank(), "PF_3", 6) == ["PF_3", 6])
	d.erase("playerCostume")
	check("old_save_empty", XState.from_dict(d).player_costume.is_empty())
	XChangeClothes.restore(s2)
	check("restore", s2.player_costume.is_empty() and XChangeClothes.player_image(s2, "PF_3", 6) == ["PF_3", 6])


## 衣橱管理员 Map4 EV17：第 0 页「查看衣橱」解锁换装表全部 95 项再打开界面；第 1 页（备份）按开关逐项解锁
func _interpreter() -> void:
	var ev: Dictionary = {}
	for e in XDB.map(4).events:
		if e is Dictionary and int(e.get("id", 0)) == 17:
			ev = e
	if not check("map4_ev17_present", not ev.is_empty()):
		return
	var h := FakeHost.new()
	add_child(h)
	_setup()
	XConfig.clothes_unlocked().clear()
	var it := MVInterpreter.new(h, 4, 17, _branch(ev.pages[0].list))
	await it.run()
	var want := XChangeClothes.entries().map(func(e): return int(e.id))
	var got := ints(XConfig.clothes_unlocked())
	got.sort()
	want.sort()
	check("ev17_p0_unlocks_all", got == want and h.opened == 1 and it.skipped.is_empty(), [got.size(), h.opened, it.skipped.slice(0, 3)])
	# 第 1 页：只开了开关 296（→ −10）
	XConfig.clothes_unlocked().clear()
	XState.current.switches[296] = true
	it = MVInterpreter.new(h, 4, 17, _branch(ev.pages[1].list))
	await it.run()
	check("ev17_p1_by_switch", ints(XConfig.clothes_unlocked()) == [-10] and h.opened == 2 and it.skipped.is_empty(), [XConfig.clothes_unlocked(), it.skipped.slice(0, 3)])
	h.queue_free()
	await frames()


## 「查看衣橱」分支（402 选项 0 之下）的指令，前后补成独立列表
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
