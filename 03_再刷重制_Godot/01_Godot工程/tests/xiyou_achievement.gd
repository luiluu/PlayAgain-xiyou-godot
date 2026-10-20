extends Node
## 成就（XAchievement ← Star_AchievementSystem／Star_AchievementShowPic）：与 mv_oracle achievement_probe（generated/oracle/achievements.json）比对
## 定义表、GetAcReward 的全局／本局记录与弹窗、得到物品自动达成（O-076 的两处偏离按登记单独核对）、kyo专属、弹窗位置、
## 成就界面的窗口、各类列表、计数与操作；另测事件脚本翻译、存读档与配置写盘（测试用临时目录，不碰真实存档）。

const ORACLE := "res://modes/xiyou/generated/oracle/achievements.json"
const DIR := "user://test_xiyou_achievement"
const TIME := "2026年1月2日 3:4:5"

var results := []
var oracle := {}
var opened := 0
## 截图目录（-- --out=<目录>，非 headless 运行时与原版参照 achievement_01～03 对照）
var out_dir := ""


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


## 解释器的 host
func toast(_text: String) -> void:
	pass

func refresh_events() -> void:
	pass

func open_achievements() -> void:
	opened += 1

func character(_id, _from):
	return null


func run_list(list: Array) -> MVInterpreter:
	var interp := MVInterpreter.new(self, 0, 0, list)
	await interp.run()
	return interp


func _reset_config() -> void:
	XConfig.achievements().clear()


func _cfg() -> Dictionary:
	return XConfig.achievements().duplicate()


## 参照的 config／party：键为字符串
static func _same_dict(mv, gd: Dictionary) -> bool:
	if mv == null:
		return gd.is_empty()
	if (mv as Dictionary).size() != gd.size():
		return false
	for k in mv:
		if not gd.has(str(k)) or str(gd[str(k)]) != str(mv[k]):
			return false
	return true


func _popups() -> Array:
	var out := XAchievement.shown.duplicate()
	XAchievement.shown.clear()
	return out


func _ids(d: Dictionary) -> Array:
	var out := d.keys().filter(func(k): return not str(k).ends_with("Time")).map(func(k): return int(k))
	out.sort()
	return out


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	XSave.dir_override = DIR
	XConfig.path_override = ""
	XAchievement.time_override = TIME
	var f := FileAccess.open(ORACLE, FileAccess.READ)
	if f == null:
		print("FAIL missing oracle ", ORACLE)
		get_tree().quit(1)
		return
	oracle = JSON.parse_string(f.get_as_text())
	await _defs()
	await _steps()
	_gains()
	_kyo()
	await _popup_layout()
	await _ui()
	await _script_and_save()
	XAchievement.time_override = ""
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _defs() -> void:
	check("types", XAchievement.types() == oracle.types, XAchievement.types())
	var mv: Array = oracle.defs
	check("def_count", XAchievement.ids().size() == mv.size(), [XAchievement.ids().size(), mv.size()])
	var bad := []
	for d in mv:
		var g := XAchievement.def(int(d.id))
		for k in ["name", "type", "trigger", "eval", "evalText", "show"]:
			if str(g.get(k)) != str(d[k]):
				bad.append([d.id, k, g.get(k), d[k]])
		if int(g.get("icon", -1)) != int(d.icon):
			bad.append([d.id, "icon"])
		for k in ["items", "weapons", "armors"]:
			if g.get(k, []) != Array(d[k]).map(func(v): return int(v)).filter(func(v): return v > 0):
				bad.append([d.id, k])
	check("defs_match", bad.is_empty(), bad)
	check("no_rewards_in_v028", mv.all(func(d): return Array(d.items + d.weapons + d.armors).all(func(v): return int(v) == 0) and str(d.eval) == ""))
	var lists := XAchievement.item_lists().map(func(l): return {"acId": l.acId, "items": l.items})
	var mv_lists: Array = oracle.itemLists.map(func(l): return {"acId": int(l.acId), "items": Array(l.items).map(func(v): return int(v))})
	check("item_lists", lists == mv_lists, lists)
	check("no_gear_lists", oracle.weaponLists.is_empty() and oracle.armorLists.is_empty())


func _steps() -> void:
	_reset_config()
	_popups()
	var s := XState.new_game_blank()
	var expect := {}
	for st in oracle.steps:
		expect[st.label] = st
	var got := func(label: String) -> void:
		var e: Dictionary = expect[label]
		var ok := _same_dict(e.config, _cfg()) and _same_dict(e.party, XState.current.achievements) and _popups() == Array(e.popups).map(func(v): return int(v))
		check("step_" + label, ok, [_cfg(), XState.current.achievements])
	got.call("new_game")
	XAchievement.reward(2, s)
	got.call("reward_2")
	XAchievement.reward(2, s)
	got.call("reward_2_again")
	s = XState.new_game_blank()
	got.call("new_game_2")
	XAchievement.reward(2, s)
	got.call("reward_2_new_game")
	XAchievement.reward(51, s)
	XAchievement.reward(84, s)
	got.call("reward_51_84")
	XAchievement.reward(3, s)
	XAchievement.reward(4, s)
	got.call("reward_3_4")
	# 时间只在全局第一次记：改掉系统时间再达成（新存档）不变
	XAchievement.time_override = "2027年5月6日 7:8:9"
	s = XState.new_game_blank()
	XAchievement.reward(2, s)
	check("time_kept", XAchievement.global_time(2) == TIME, XAchievement.global_time(2))
	XAchievement.time_override = TIME
	_popups()
	await get_tree().process_frame


## 得到物品自动达成：+1 与参照相同，只是 O-076 BEFORE_REDIRECT 让魂灯 184～187 另记改记前的 108～111；
## −1（失去）原版也触发，O-076 GAIN_ONLY 改为不触发
func _gains() -> void:
	var bad := []
	var by_item := {}
	for l in XAchievement.item_lists():
		for it in l.items:
			by_item[int(it)] = int(l.acId)
	for g in oracle.gains:
		_reset_config()
		_popups()
		var s := XState.new_game_blank()
		s.gain_item(int(g.id), int(g.amount))
		var want: Array = Array(g.config).map(func(v): return int(v))
		if int(g.amount) <= 0 and XAchievement.GAIN_ONLY:
			want = []
		elif XAchievement.BEFORE_REDIRECT and int(g.id) in [184, 185, 186, 187] and not want.has(by_item[int(g.id)]):
			want.append(by_item[int(g.id)])
		want.sort()
		var pops := _popups()
		pops.sort()
		var bag_ok := true
		for k in g.bag:
			if s.item_count(int(k)) != int(g.bag[k]):
				bag_ok = false
		if _ids(_cfg()) != want or _ids(s.achievements) != want or pops != want or not bag_ok:
			bad.append([g.id, g.amount, _ids(_cfg()), want, pops])
	check("gains_match_with_o076", bad.is_empty(), bad)
	# 回退开关：逐条与参照原样一致的部分（+1 且不是魂灯）照抄参照
	check("gains_positive_identical", oracle.gains.filter(func(g): return int(g.amount) > 0 and not int(g.id) in [184, 185, 186, 187]).size() > 60)
	# 全局已有、本局没有：得到物品不补记
	_reset_config()
	XConfig.achievements()["105"] = true
	var s2 := XState.new_game_blank()
	s2.gain_item(325, 1)
	var e: Dictionary = oracle.gainConfigOnly
	check("gain_config_only", _same_dict(e.config, _cfg()) and _same_dict(e.party, s2.achievements) and _popups().is_empty(), [_cfg(), s2.achievements])


func _kyo() -> void:
	_reset_config()
	var s := XState.new_game_blank()
	XAchievement.reward(143, s)
	var k: Dictionary = oracle.kyo
	check("kyo_defined", k.registered and XAchievement.def(143).name == k.def.name and int(XAchievement.def(143).icon) == int(k.def.icon))
	check("kyo_locked_without_test_mode", not k.codexTestMode and _same_dict(k.config, _cfg()) and _same_dict(k.party, s.achievements) and _popups().is_empty())


func _popup_layout() -> void:
	for p in XAchievementPopup._stack:
		if is_instance_valid(p):
			p.queue_free()
	XAchievementPopup._stack.clear()
	await get_tree().process_frame
	_reset_config()
	var s := XState.new_game_blank()
	for id in [2]:
		XAchievement.reward(id, s)
	s = XState.new_game_blank()
	for id in [2, 51, 84, 3, 4]:
		XAchievement.reward(id, s)
	var mv: Array = oracle.popupLayout
	var gd: Array = XAchievementPopup._stack.map(func(p): return [p.item.id, p.position.x, p.position.y, p.size.x, p.size.y])
	var want: Array = mv.map(func(p): return [int(p.id), float(p.x), float(p.y), float(p.width), float(p.height)])
	check("popup_layout", gd == want, [gd, want])
	var st: Dictionary = oracle.popupSettings
	check("popup_settings", int(XAchievementPopup._stack[0].wait_frames) == int(st.popupWait) * 60 and XAchievementPopup.settings().get("Popup Message") == st.popupMessage
		and XAchievementPopup.settings().get("Popup Sound") == st.popupSound and int(st.popupWidth) == XAchievementPopup.WIDTH)
	# 淡入 30 帧、停 300 帧、淡出 30 帧后移除
	var first: XAchievementPopup = XAchievementPopup._stack[0]
	first.frame = XAchievementPopup.IN_FRAMES + first.wait_frames + XAchievementPopup.OUT_FRAMES
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("popup_removed_after_tween", not XAchievementPopup._stack.has(first))
	for p in XAchievementPopup._stack:
		p.queue_free()
	XAchievementPopup._stack.clear()
	_popups()


## 界面：全局有 1、2（无时间）、22（本局无）、51，本局有 1、51
func _ui() -> void:
	_reset_config()
	var s := XState.new_game_blank()
	XAchievement.reward(1, s)
	XAchievement.reward(22, s)
	XAchievement.reward(51, s)
	s.achievements["22"] = false
	XConfig.achievements()["2"] = true
	_popups()
	for id in ["1", "22", "51"]:
		XConfig.achievements()[id + "Time"] = TIME
	var page := XAchievementScene.new()
	add_child(page)
	await get_tree().process_frame
	await shot("achievement_01_challenge")
	if out_dir != "":
		page.select_type(1)
		page.ok()
		for i in range(7):
			page._move(1, false)
		await shot("achievement_02_event_list")
		XAchievement.reward(60, s)
		for i in range(90):
			await get_tree().physics_frame
		await shot("achievement_03_popup")
		for k in ["60", "60Time"]:
			XConfig.achievements().erase(k)
		s.achievements.erase("60")
		page.cancel()
		page.select_type(0)
	var u: Dictionary = oracle.ui
	var rect := func(w: XMVWindow, r: Dictionary) -> bool:
		return w.position == Vector2(r.x, r.y) and w.size == Vector2(r.width, r.height) and w.padding == float(r.padding)
	check("ui_rects", rect.call(page.type_win, u.typeWindow) and rect.call(page.list_win, u.indexWindow) and rect.call(page.count_win, u.countWindow))
	check("ui_line_heights", XAchievementScene.TYPE_LH == float(u.typeWindow.lineHeight) and XAchievementScene.LIST_LH == float(u.indexWindow.lineHeight)
		and XAchievementScene.PAGE_ROWS == floori((float(u.indexWindow.height) - 2 * float(u.indexWindow.padding)) / float(u.indexWindow.lineHeight)))
	check("ui_initial", page.type_index == int(u.typeIndex) and page.index == int(u.indexIndex) and page.mode == "type")
	check("ui_count", "%d/%d" % XAchievement.count(s) == str(u.count[0].t), XAchievement.count(s))
	check("ui_type_items", Array(u.typeItems).map(func(c): return c.t) == XAchievement.types() and Array(u.typeItems).all(func(c): return int(c.x) == 6 and int(c.w) == 280))
	var bad := []
	for i in range(u.pages.size()):
		page.select_type(i)
		var mvp: Dictionary = u.pages[i]
		if page.list != Array(mvp.ids).map(func(v): return int(v)):
			bad.append([mvp.type, page.list])
	check("ui_pages", bad.is_empty(), bad)
	# 逐项绘制的位置：参照挑战页第一项（已得、带时间）、第二项（已得、无时间）、第三项（未得）
	var calls: Array = u.pages[0].calls
	var at := func(t: String) -> Dictionary:
		for c in calls:
			if str(c.get("t", "")) == t:
				return c
		return {}
	var name1: Dictionary = at.call("神魔之塔挑战:一层通关")
	var got1: Dictionary = at.call("已获得")
	var time1: Dictionary = at.call("完成于" + TIME)
	var icon1: Dictionary = calls[0]
	var locked: Array = calls.filter(func(c): return str(c.get("t", "")) == "未获得")
	check("ui_item_layout", int(name1.x) == 6 + int(XAchievementScene.LIST_LH) and int(got1.x) == 12 and int(got1.y) == 2 * int(XAchievementScene.ROW)
		and int(time1.x) == 12 and int(time1.y) == int(XAchievementScene.ROW) and int(time1.w) == 920 and int(time1.size) == 14 and time1.align == "right"
		and icon1.f == "icon" and int(icon1.scale) == 2 and int(icon1.x) == 6 and locked.size() > 0 and int(locked[0].x) == 6 and int(locked[0].y) == 2 * int(XAchievementScene.LIST_LH))
	# 无时间的 2 号：画「已获得」不画「完成于」
	var name2 := calls.filter(func(c): return str(c.get("t", "")) == "神魔之塔挑战:二层通关")
	check("ui_item_without_time", name2.size() == 1 and calls.filter(func(c): return str(c.get("t", "")).begins_with("完成于")).size() == 1)
	# 确定进入列表、取消回到类型
	page.select_type(1)
	page.ok()
	var ao: Dictionary = u.afterOk
	check("ui_after_ok", page.mode == "list" and page.index == int(ao.index) and page.list == Array(ao.ids).map(func(v): return int(v)))
	page.cancel()
	var ac: Dictionary = u.afterCancel
	check("ui_after_cancel", page.mode == "type" and page.index == int(ac.index) and page.type_index == int(ac.typeIndex))
	# 空类型（节日）进入也有光标；翻页与滚动
	page.select_type(XAchievement.types().find("节日"))
	page.ok()
	check("ui_empty_type", page.list.is_empty() and page.index == 0)
	page.cancel()
	page.select_type(1)
	page.ok()
	page._page(1)
	check("ui_page_down", page.index == 6 and page.top == 6, [page.index, page.top])
	for i in range(40):
		page._move(1, false)
	check("ui_scroll_end", page.index == page.list.size() - 1 and page.top == page.list.size() - XAchievementScene.PAGE_ROWS)
	page._move(1, true)
	check("ui_wrap", page.index == 0 and page.top == 0)
	page.cancel()
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.cancel()
	check("ui_close", closed[0])
	page.queue_free()


func _script_and_save() -> void:
	_reset_config()
	var s := XState.new_game_blank()
	var it := await run_list([{"code": 355, "indent": 0, "parameters": ["Star.AchievementSystem.GetAcReward(51)"]}, {"code": 0, "indent": 0, "parameters": []}])
	check("script_get_ac_reward", it.skipped.is_empty() and XAchievement.party_has(s, 51) and XAchievement.global_has(51))
	# O-076 FLOOR12_FIX：十二层守层者（Map023 事件 1、Map065 事件 2）给 12，其他地方的 13 不变
	var code := [{"code": 355, "indent": 0, "parameters": ["Star.AchievementSystem.GetAcReward(13)"]}, {"code": 0, "indent": 0, "parameters": []}]
	for at in [[23, 1, 12], [65, 2, 12], [29, 1, 13]]:
		_reset_config()
		var s3 := XState.new_game_blank()
		await MVInterpreter.new(self, at[0], at[1], code).run()
		check("floor12_fix_%d" % at[0], XAchievement.party_has(s3, at[2]) and _ids(s3.achievements) == [at[2]], s3.achievements)
	XState.current = s
	it = await run_list(XDB.rec("CommonEvents", 431).list)
	check("script_ce431_opens_book", it.skipped.is_empty() and opened == 1)
	# 宝箱等事件（公共事件＋已转换地图）里调用的成就全都有定义
	var missing := []
	var lists: Array = [XDB.table("CommonEvents")]
	var maps := DirAccess.get_files_at("res://modes/xiyou/generated/maps")
	for name in maps:
		if name.ends_with(".json") and name.begins_with("Map"):
			lists.append([XDB.map(int(name.trim_prefix("Map").trim_suffix(".json")))])
	var re := RegEx.create_from_string("GetAcReward\\((\\d+)\\)")
	var calls := 0
	for src in lists:
		for m in re.search_all(JSON.stringify(src)):
			calls += 1
			if XAchievement.def(int(m.get_string(1))).is_empty():
				missing.append(int(m.get_string(1)))
	check("event_ids_defined", calls > 40 and missing.is_empty(), [calls, missing])
	# 事件里出现过的每一种成就脚本写法都认得（不进 skipped）
	var texts := {}
	var walk := func(v, f: Callable) -> void:
		if v is Dictionary:
			if int(v.get("code", 0)) in [355, 655] and str(v.get("parameters", [""])[0]).contains("Achievement"):
				texts[str(v.parameters[0])] = true
			for k in v:
				f.call(v[k], f)
		elif v is Array:
			for x in v:
				f.call(x, f)
	walk.call(lists, walk)
	var unknown := []
	_reset_config()
	XState.new_game_blank()
	for t in texts:
		var left: Array = await MVScript.run(str(t), MVInterpreter.new(self, 0, 0, []))
		if not left.is_empty():
			unknown.append(t)
	check("event_scripts_recognized", texts.size() > 100 and unknown.is_empty(), [texts.size(), unknown])
	opened = 1
	_popups()
	# 存读档：本局记录随存档，全局记录不随
	check("save", XSave.save(2))
	var s2 := XState.new_game_blank()
	check("new_game_party_empty", s2.achievements.is_empty() and XAchievement.global_has(51))
	check("load_keeps_party", XSave.load_slot(2) and XAchievement.party_has(XState.current, 51))
	# 配置写盘（O-076 SAVE_NOW）：达成即写，换路径重新读回
	var path := DIR.path_join("options.json")
	XConfig.path_override = path
	XConfig.ensure_loaded()
	XAchievement.reward(60, XState.new_game_blank())
	var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	check("config_written", data is Dictionary and data.get("SAchievementS", {}).get("60") == true and data.SAchievementS.get("60Time") == TIME, data)
	XConfig.path_override = DIR.path_join("other.json")
	XConfig.ensure_loaded()
	check("config_other_empty", not XAchievement.global_has(60))
	XConfig.path_override = path
	XConfig.ensure_loaded()
	check("config_reloaded", XAchievement.global_has(60) and XAchievement.global_time(60) == TIME)
	XConfig.path_override = ""
	_popups()
