extends Node
## 系统页成对截图（八戒_63）：与 03_转换工具/ui_reference/review_system_pages.js 的原版重放取同一状态，存 <名>.png 与窗口矩形 <名>.json。
## 制作／宠物菜单／异化工坊的同态截图由各自专项（--out）产出；这里补它们没有截图点的状态：
## 制作类别页、法宝等级字三处（商店买入、装备槽、物品详情）、宠物底部指令、喂养、合成、种族祝福 default-first 路线前五页。
## 无 --out（或 headless）时只走状态断言，不写文件。

const CRAFT := "res://tests/fixtures/crafting_oracle.json"
const PETS := "res://tests/fixtures/pet_oracle.json"
const SYNTH := "res://tests/fixtures/pet_synth_oracle.json"

var results := []
var out_dir := ""


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


static func rect(w: Control) -> Array:
	return [w.position.x, w.position.y, w.size.x, w.size.y]


## 截图与读数：wins 为 {名: 窗口}，记矩形、可见与开合
func shot(name: String, wins: Dictionary, extra := {}) -> void:
	# 窗口开合在 _physics_process 里每帧 ±32：按物理帧等开合走完
	for i in 20:
		await get_tree().physics_frame
	await frames(2)
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	var data := {"shot": name, "windows": {}, "extra": extra}
	for k in wins:
		var w: Control = wins[k]
		data.windows[k] = {"rect": rect(w), "visible": w.is_visible_in_tree(),
			"openness": w.openness if "openness" in w else null}
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	var f := FileAccess.open(out_dir.path_join(name + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))


func _run() -> void:
	# 设置用内存默认值（不读本机开发档的 options.json，免得「战力显示」等开关跟着开发者的设置变）
	XSave.dir_override = "user://test_system_evidence"
	XConfig._loaded_path = "<unloaded>"
	check("power_line_default_on", XPower.enabled())
	# 截图模式统一不读开发档设置（XConfig.screenshot_mode：带 --out= 时 path 为空，即使没设 dir_override）
	if out_dir != "":
		var keep := XSave.dir_override
		XSave.dir_override = ""
		check("screenshot_mode_memory_config", XConfig.screenshot_mode() and XConfig.path() == "", XConfig.path())
		XSave.dir_override = keep
	await _crafting()
	await _magic_level()
	await _race()
	await _pets()
	await _pet_synth()
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 上一页留下的提示条与成就弹窗不带进下一页的截图
func _clear_overlays(n: Node = null) -> void:
	if n == null:
		n = get_tree().root
	for c in n.get_children():
		if c is XToast or c is XAchievementPopup:
			c.queue_free()
		else:
			_clear_overlays(c)


func _party(ids: Array) -> XState:
	_clear_overlays()
	var s := XState.new_game_blank()
	s.party.clear()
	for id in ids:
		s.add_actor(int(id))
	XState.current = s
	return s


## 制作类别页：与 xiyou_crafting 同一 setup
func _crafting() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(CRAFT))
	var s := _party(ref.setup.party)
	for id in ref.setup.learn:
		XCrafting.learn(s, int(id))
	s.gold = int(ref.setup.gold)
	s.crafting.exp = ref.setup.craftExp.map(func(x): return int(x))
	var page := XCraftingScene.new()
	add_child(page)
	await frames()
	check("craft_category_mode", page.mode == "category" and page.index == -1)
	await shot("craft_0_category", {"help": page.help_win, "cat": page.cat_win, "list": page.list_win, "detail": page.detail_win,
		"confirm": page.confirm_win, "gold": page.gold_win, "gauge": page.gauge_win})
	page.queue_free()
	await frames()


## 法宝等级字：与 xiyou_magic_level 同一夹具，取整页
func _magic_level() -> void:
	var s := _party([1, 8, 9, 10])
	var shop := XShop.new()
	shop.setup([[2, 13, 0, 0], [1, 73, 0, 0], [2, 52, 0, 0]], false)
	add_child(shop)
	await frames()
	shop._mode = "buy"
	shop._buy_index = 0
	shop._refresh()
	check("magic_shop_mode", shop._mode == "buy")
	await shot("magic_shop_buy", {"cmd": shop.cmd_win, "info": shop.info_win, "list": shop.list_win, "status": shop.status_win, "gold": shop.gold_win})
	shop.queue_free()
	await frames()
	var a := s.actor(1)
	XPower.clear_cache()
	var bare: float = XPower.actor(a, true).total
	var inst := XGear.create("armor", 13, s)
	s.register_gear(inst)
	a.equips[12] = inst
	var eq := XEquipScene.new()
	add_child(eq)
	await frames()
	eq._ok()
	eq._slot = 12
	eq._refresh()
	check("magic_equip_slot", eq._mode == "slot" and eq._slot_item() == inst, [eq._mode])
	XPower.clear_cache()
	await shot("magic_equip_slot", {"cmd": eq.cmd_win, "status": eq.status_win, "list": eq.list_win, "lower": eq.lower_win},
		{"power": {"bare": bare, "equipped": XPower.actor(a, true).total, "equipment": XPower.equipment(inst).total},
			"armor": {"upgradeSlots": inst.get("upgradeSlots"), "augmentSlots": inst.get("augmentSlots")}})
	eq.queue_free()
	await frames()
	a.equips[12] = {}
	s.gear.append(inst)
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._cat = 3
	page._refresh()
	page._ok()
	var names: Array = page.entries().map(func(e): return str(e.rec.get("name", "")))
	page._index = maxi(0, names.find("大罗剑胎"))
	page._refresh()
	check("magic_item_info", page._mode == "list" and str(page._current().get("name", "")) == "大罗剑胎", [page._mode, names])
	await shot("magic_item_info", {"cat": page.cat_win, "status": page.status_win, "list": page.list_win, "info": page.info_win})
	page.queue_free()
	await frames()


static func _pet_from(p: Dictionary) -> Dictionary:
	var lv := {}
	for k in p.lvSkills:
		lv[str(k)] = int(p.lvSkills[k])
	return {"enemy": int(p.id), "elite": bool(p.elite), "letter": "", "push": p.paramPush.map(func(v): return float(str(v))),
		"skills": p.skills.map(func(v): return int(v)), "lv_skills": lv, "exp": int(p.exp), "ls": int(p.ls[0]), "ls_max": int(p.ls[1])}


func _pet_wins(page: XPetScene) -> Dictionary:
	return {"index": page.index_win, "status": page.status_win, "skill": page.skill_win, "bottom": page.bottom_win,
		"team": page.team_win, "feed": page.feed_win, "syn": page.syn_win, "help": page.help_card}


## 宠物底部指令（xiyou_pets 截了目录与技能，这里补底部指令打开）
func _pets() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(PETS))
	var s := _party([1, 8, 9, 10])
	s.pets.list = ref.pets.map(func(p): return _pet_from(p))
	var page := XPetScene.new()
	add_child(page)
	await frames()
	page.select(1)
	page.ok()
	check("pet_bottom_mode", page.mode == "bottom")
	await shot("pet_bottom", _pet_wins(page))
	page.queue_free()
	await frames()


## 喂养（第 3 只）、合成（第 1 只）：与 xiyou_pet_synth 同一 setup
func _pet_synth() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(SYNTH))
	var s := _party([1, 8, 9, 10])
	s.pets.list = ref.pets.map(func(p): return _pet_from(p))
	s.gain_item(426, 3)
	s.gain_item(428, 1)
	var page := XPetScene.new()
	add_child(page)
	await frames()
	page.select(2)
	page.ok()
	for i in 6:
		page._move(1, false)
	page.ok()
	check("pet_feed_mode", page.mode == "feed" and page.cmd == 6 and page.cmd_top == 1, [page.mode, page.cmd, page.cmd_top])
	await shot("pet_feed", _pet_wins(page))
	check("pet_feed_status_clip", page.status_cover == 540.0, page.status_cover)
	page.cancel()
	await frames()
	page.cancel()
	await frames()
	page.select(0)
	page.ok()
	for i in 5:
		page._move(1, false)
	page.ok()
	check("pet_synth_mode", page.mode == "syn" and page.cmd == 5, [page.mode, page.cmd])
	await shot("pet_synth", _pet_wins(page))
	check("pet_synth_status_clip", page.status_cover == 584.0, page.status_cover)
	page.cancel()
	for i in 20:
		await get_tree().physics_frame
	await frames(2)
	check("pet_closed_status_unclipped", page.status_cover == 720.0 and page.mode == "bottom", [page.status_cover, page.mode])
	page.queue_free()
	await frames()


## 种族祝福 default-first 路线：默认页 → 选人族的确认页 → 队员页 → 角色页 → 换族页（队伍 1/8/9、清空背包，同 race_menu 探针）
func _race() -> void:
	var s := _party([1, 8, 9])
	s.items = {}
	var menu := XRaceMenu.new()
	add_child(menu)
	await frames()
	var wins := func() -> Dictionary: return {"choice": menu.choice.win}
	var info := func() -> Dictionary: return {"rows": menu.choice.rows.map(func(r): return [str(r.label), r.get("enabled", true) != false]), "info": menu.choice.info}
	await shot("race_1_default", wins.call(), info.call())
	for step in [["人族", "race_2_confirm"], ["确定开局默认", "race_3_members"], ["@0", "race_4_actor"], ["调整种族", "race_5_change"]]:
		var label: String = step[0]
		var i := int(label.substr(1)) if label.begins_with("@") else menu.choice.rows.find_custom(func(r): return str(r.label) == label)
		if not check("race_row_" + label, i >= 0, menu.choice.rows.map(func(r): return r.label)):
			break
		menu.choice.index = i
		menu.choice.ok()
		await shot(step[1], wins.call(), info.call())
	menu.queue_free()
	await frames()
