extends Node
## 工具（不是专项）：T513 套装同台上限在真实装备页（XEquipScene＋天启篇新皮肤 XSkinEquipPage）说明牌上的「本套未生效」截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t513_suit_shots.tscn -- --out=<目录>
## 两张：orig＝冰冷 3 件＋黑印 3 件＋云压 2 件，选云压戒指（原版套被挤）；seal＝白印 3 件＋统帅 3 件＋黑印 2 件，选黑印件（七印被挤）。
## 夹具：黑印 2 件放在项链、戒指格（六个防具格已被前两套占满；keep_unequippable 不让卸）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _armor(id: int, s: XState) -> Dictionary:
	return XGear.create("armor", id, s)


func _seal(seal: String, part: String, s: XState) -> Dictionary:
	var it := XTianqiQiyinEquip.make({"kind": "set", "seal": seal, "part": part, "true_seal": false, "grades": ["shangpin", "putong", "putong"]}, "jianxian", XRandomStream.create("5135135135135135", "t513"))
	return it


## etype → 这名角色的槽位序号
func _slot_of(a: XActor, etype: int, skip: Array = []) -> int:
	var sl: Array = a.equip_slots()
	for i in sl.size():
		if int(sl[i]) == etype and not skip.has(i):
			return i
	return -1


func _put(a: XActor, etype: int, inst: Dictionary, used: Array) -> int:
	var i := _slot_of(a, etype, used)
	a.equips[i] = inst
	used.append(i)
	return i


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t513_suit_shots")
	XSplashScreen.shown = true
	var lineup := _ids().slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var a: XActor = s.members()[0]
	a.keep_unequippable = true
	var cases := {
		"orig": [[3, _armor(4164, s)], [4, _armor(4165, s)], [7, _armor(4166, s)], [6, _seal("hei", "hands", s)], [8, _seal("hei", "waist", s)], [5, _seal("hei", "legs", s)], [9, _armor(4231, s)], [10, _armor(4232, s)]],
		"seal": [[3, _seal("bai", "head", s)], [6, _seal("bai", "hands", s)], [8, _seal("bai", "waist", s)], [4, _armor(1055, s)], [5, _armor(1056, s)], [7, _armor(1057, s)], [9, _seal("hei", "head", s)], [10, _seal("hei", "body", s)]],
	}
	for name in cases:
		for i in a.equips.size():
			if i > 0:
				a.equips[i] = {}
		var used := [0]
		var pick := -1
		for row in cases[name]:
			pick = _put(a, int(row[0]), row[1], used)
		a.param_mark_dirty()
		a.param_refresh()
		print("NOTE ", name, " ", XTianqiSuits.note(a, a.equips[pick]), " live=", XTianqiSuits.live(a))
		var page := XEquipScene.new()
		add_child(page)
		await _frames(5)
		page._slot = pick
		page._refresh()
		await _frames(10)
		await _shot("t513_equip_" + name)
		page.queue_free()
		await _frames(5)
	get_tree().quit()
