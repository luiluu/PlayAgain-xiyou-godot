extends Node
## 角色仓库（XActorWarehouse／XActorWarehouseScene）：对照冻结 v0.28 浏览器参照 tests/fixtures/actor_warehouse_oracle.json
## （ui_reference/review_system_pages.js 的 actor_warehouse：内存新局 1/8/9/10 加 11、12，仓库 [13,143]；
## 依次存入 8（出战中）、存入最后一行 12、取出 13、停用 143 确定）：七个截图状态的全部窗口文字（坐标与宽差 ≤ POS_TOL，
## 字号、对齐、颜色相等）、窗口矩形、指令与名单光标、名字半透明（停用角色）、队伍／出战栏／仓库／名单数据；
## 再测：空行确定蜂鸣不动（O-091）、只剩 1 人不能存、停用角色不能存、仓库滤掉已在队伍的、存读档（旧档没有为空）、
## 出战宠物技能也给仓库里的角色、仓库管理员 Map4 EV8「角色仓库」的脚本打开界面。

const FIXTURE := "res://tests/fixtures/actor_warehouse_oracle.json"
## 名单里 Lv 值、HP/MP 值的横坐标由字宽推出（Godot 字体与浏览器差零点几像素）
const POS_TOL := 1.0
const SHOTS := ["aw_0", "aw_1_save_list", "aw_2_save_battle", "aw_3_save_last", "aw_4_load_list", "aw_5_load_one", "aw_6_disabled"]

var results := []
var out_dir := ""


## 只记 drawText 的画布：拿窗口的 painter 画一遍，收集文字与透明度
class RecCanvas extends XMVCanvas:
	var texts := []
	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, _lh := XUI.LINE_HEIGHT, alpha := 1.0, _zoom := 1.0, _pivot := Vector2.ZERO, _outline := OUTLINE) -> void:
		if s != "":
			texts.append([s, x, y, max_w, align, float(size), color.to_html(false), alpha])
	func character(_n: String, _i: int, _x: float, _y: float, _h := 0.0, _alpha := 1.0) -> void:
		pass
	func gauge(_x: float, _y: float, _w: float, _r: float, _c1: Color, _c2: Color, _lh := XUI.LINE_HEIGHT) -> void:
		pass
	func cursor(_r: Rect2, _active := true) -> void:
		pass


class FakeHost extends Node:
	var opened := 0
	func open_actor_warehouse() -> void:
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
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
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
	for id in [1, 8, 9, 10, 11, 12]:
		s.add_actor(id)
	s.actor(13)
	s.actor(143)
	s.saved_actors.assign([13, 143])
	XState.current = s
	return s


func _compare(ref: Dictionary, name: String, page: XActorWarehouseScene) -> void:
	var w: Dictionary = ref.shots[name].windows
	var st: Dictionary = ref.shots[name].state
	var s := XState.current
	var bad := []
	var parts := {"Window_ActSavePercent": page.title_win, "Star_Window_ActorWarehouse": page.cmd_win, "Star_Window_PartyList": page.list_win}
	var list_texts := []
	for k in parts:
		var got := record(parts[k])
		if k == "Star_Window_PartyList":
			list_texts = got
		var d := diff(got, want_form(w[k].texts))
		if d != "":
			bad.append("%s %s" % [k, d])
		var c: Control = parts[k]
		if [c.position.x, c.position.y, c.size.x, c.size.y] != w[k].rect.map(func(v): return float(v)):
			bad.append("%s 矩形 %s" % [k, [c.position.x, c.position.y, c.size.x, c.size.y]])
	if page.cmd != int(st.category.index):
		bad.append("指令光标 %d" % page.cmd)
	if page.index != int(st.list.index) or (page.mode == "list") != bool(st.list.active):
		bad.append("名单光标 %d %s" % [page.index, page.mode])
	# 名字半透明：名单每行名字（x=36）的 alpha 与原版 actorIsEnabled 一致
	var names := list_texts.filter(func(t): return float(t[1]) == 36.0)
	var dims := names.map(func(t): return float(t[7]) >= 1.0)
	if dims != Array(st.list.opacity):
		bad.append("半透明 %s" % JSON.stringify(dims))
	s._ensure_slots()
	var got_state := [ints(s.party), ints(s.battle_slots), ints(s.saved_actors), s.battle_members().map(func(a): return a.actor_id), ints(page.data)]
	var want_state := [ints(st.actors), ints(st.battleMembers), ints(st.saveactors), ints(st.battle), ints(st.list.data)]
	if got_state != want_state:
		bad.append("数据 %s 应为 %s" % [JSON.stringify(got_state), JSON.stringify(want_state)])
	check(name, bad.is_empty(), bad)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("shots", {}).has("aw_0"), FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	await _flow(ref)
	_rules()
	_save()
	_pets()
	await _interpreter()
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _flow(ref: Dictionary) -> void:
	var s := _setup()
	check("setup_slots", ints(s.battle_slots) == [1, 8, 9, 10, 11], s.battle_slots)
	var page := XActorWarehouseScene.new()
	add_child(page)
	await frames()
	await shot("aw_0")
	_compare(ref, "aw_0", page)
	page.ok()
	await shot("aw_1_save_list")
	_compare(ref, "aw_1_save_list", page)
	page._select(1)
	page.ok()
	await shot("aw_2_save_battle")
	_compare(ref, "aw_2_save_battle", page)
	page._select(page.data.size() - 1)
	page.ok()
	await shot("aw_3_save_last")
	_compare(ref, "aw_3_save_last", page)
	# O-091：光标在空行时确定，蜂鸣、什么都不变
	var before := [ints(s.party), ints(s.saved_actors), ints(s.battle_slots)]
	page.ok()
	check("empty_row_buzzer", XSound.system_log.back() == 3 and [ints(s.party), ints(s.saved_actors), ints(s.battle_slots)] == before,
		[XSound.system_log.slice(-2), s.party, s.saved_actors])
	page.cancel()
	check("cancel_to_command", page.mode == "command" and page.index == -1)
	page._move_cmd(1, true)
	page.ok()
	await shot("aw_4_load_list")
	_compare(ref, "aw_4_load_list", page)
	page._select(0)
	page.ok()
	await shot("aw_5_load_one")
	_compare(ref, "aw_5_load_one", page)
	page._select(page.data.find(143))
	page.ok()
	check("disabled_buzzer", XSound.system_log.back() == 3, XSound.system_log.slice(-2))
	await shot("aw_6_disabled")
	_compare(ref, "aw_6_disabled", page)
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.cancel()
	check("list_cancel_keeps_open", not closed[0] and page.mode == "command")
	page.cancel()
	check("command_cancel_closes", closed[0])
	page.queue_free()
	await frames()


func _rules() -> void:
	# 只剩 1 人：不存，提示
	var s := XState.new_game_blank()
	s.add_actor(1)
	XState.current = s
	check("last_actor_kept", XActorWarehouse.deposit(s, 0) == "last" and ints(s.party) == [1] and s.saved_actors.is_empty())
	# 停用角色在队伍里也存不进（isCurrentItemEnabled）
	s.add_actor(8)
	s.party.append(143)
	check("disabled_not_deposited", XActorWarehouse.deposit(s, 2) == "disabled" and s.party.has(143))
	# 存入候补（不在出战栏）：出战栏不重建
	s = _setup()
	s.add_actor(2)
	var slots := ints(s.battle_slots)
	check("deposit_reserve", XActorWarehouse.deposit(s, s.party.find(2)) == "ok" and ints(s.battle_slots) == slots and s.saved_actors.back() == 2)
	# 取出：追加到队伍末尾，不进出战栏
	check("withdraw_appends", XActorWarehouse.withdraw(s, 0) == "ok" and s.party.back() == 13 and not s.battle_slots.has(13))
	# 仓库里已经在队伍的编号（例如事件又加入了队伍）列表时滤掉
	s.saved_actors.append(1)
	check("stored_filters_party", not XActorWarehouse.list(s, false).has(1) and not s.saved_actors.has(1))
	# 出战栏前 4 格全空时取出：第 1 格放队伍第 1 人
	s = XState.new_game_blank()
	s.add_actor(1)
	s.battle_slots = [0, 0, 0, 0, 0]
	s.saved_actors.assign([8])
	XState.current = s
	check("empty_slots_fix", XActorWarehouse.withdraw(s, 0) == "ok" and int(s.battle_slots[0]) == 1, s.battle_slots)


func _save() -> void:
	var s := _setup()
	XActorWarehouse.deposit(s, 1)
	s.actor(8).change_level(7)
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2 := XState.from_dict(d)
	check("save_roundtrip", ints(s2.saved_actors) == [13, 143, 8] and s2.actor(8).level == 7 and not s2.party.has(8), [s2.saved_actors])
	d.erase("saveactors")
	check("old_save_empty", XState.from_dict(d).saved_actors.is_empty())


## Star_PetSystem：出战宠物的技能也学给 _saveactors，休息时一并忘掉
func _pets() -> void:
	var s := _setup()
	var skill := 2
	for id in range(2, 200):
		var r := XDB.rec("Skills", id)
		if not r.is_empty() and not XPets.team_a_skill(id) and not s.actor(13).skill_ids.has(id) and not s.actor(1).skill_ids.has(id):
			skill = id
			break
	s.pets = {"list": [{"skills": [skill], "push": [0, 0, 0, 0, 0, 0, 0, 0]}], "war": -1, "team_a": 0}
	XPets.go_to_war(s, 0)
	var learned := s.actor(13).skill_ids.has(skill) and s.actor(1).skill_ids.has(skill)
	XPets.rest(s, 0)
	check("pet_skills_stored_actors", learned and not s.actor(13).skill_ids.has(skill), [skill, learned])


## 仓库管理员 Map4 EV8 第 1 页「角色仓库」分支的脚本：SceneManager.push(Star_Scene_ActorWarehouse); → 打开一次
func _interpreter() -> void:
	var ev: Dictionary = {}
	for e in XDB.map(4).events:
		if e is Dictionary and int(e.get("id", 0)) == 8:
			ev = e
	if not check("map4_ev8_present", not ev.is_empty()):
		return
	var cmds: Array = []
	for p in ev.pages:
		cmds += p.list.filter(func(c): return int(c.code) == 355 and str(c.parameters[0]).contains("Star_Scene_ActorWarehouse"))
	check("ev8_script_both_pages", cmds.size() == 2, cmds.size())
	cmds = [{"code": 355, "indent": 0, "parameters": cmds[0].parameters}, {"code": 0, "indent": 0, "parameters": []}]
	_setup()
	var h := FakeHost.new()
	add_child(h)
	var it := MVInterpreter.new(h, 4, 8, cmds)
	await it.run()
	check("ev8_opens", h.opened == 1 and it.skipped.is_empty(), [h.opened, it.skipped])
	h.queue_free()
	await frames()
