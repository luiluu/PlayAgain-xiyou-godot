extends "res://tests/virtual_player/k_calibrate.gd"
## 【cc·T163】专属法宝摸底（不进检查.sh）：每件专属法宝（＋破攻／尊魔）99 级，在本人 81 级甲档身上，
## 量「穿着 − 摘掉」的最终生命／物攻／魔攻差，并拆成：底子八项、99×每级成长、升级特性（按级叠）、卡改写视图。
## godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/fabao_survey.tscn -- [--out=…]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--actors="):
			only = Array(a.substr(9).split(",")).map(func(x): return int(x))
	bare = true
	_survey.call_deferred()


func _survey() -> void:
	XMessageBox.auto = true
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	_own_fabao(0)
	var rows := []
	var tier_of := {}
	for t in [XTier.SUPER, XTier.STRONG, XTier.WEAK]:
		for id in XTianqiSkills.ids(t, true):
			tier_of[int(id)] = t
	for id in tier_of.keys():
		if not only.is_empty() and not only.has(int(id)):
			continue
		if XImportedBalance.is_disabled_actor(int(id)):
			continue
		var s := _state(int(id))
		var a := s.actor(int(id))
		var slot := -1
		for q in a.equips.size():
			if XMagicWeapon.is_magic(a.equips[q]):
				slot = q
		if slot < 0:
			continue
		var item: Dictionary = a.equips[slot]
		a.param_mark_dirty()
		var on := [a.param(0), a.param(2), a.param(4)]
		var view = XTianqiSkills.gear_view(item)
		var p: Array = item.get("params", [])
		var growth := [XActor.magic_param(item, 0), XActor.magic_param(item, 2), XActor.magic_param(item, 4)]
		var tr := XMagicWeapon.level_up_trait_object(item)
		var rates := []
		for t in (view.get("traits", []) if view is Dictionary else []):
			if int(t.get("code", 0)) == 21:
				rates.append(["self", int(t.dataId), float(t.value)])
		for t in tr.get("traits", []):
			rates.append(["lvx%d" % int(XMagicWeapon.level_of(item)), int(t.get("code", 0)), int(t.get("dataId", 0)), float(t.get("value", 0))])
		a.equips[slot] = {}
		a.param_mark_dirty()
		a.refresh_passive()
		var off := [a.param(0), a.param(2), a.param(4)]
		var row := {"actor": int(id), "tier": tier_of[int(id)], "fabao": int(item.id), "name": str(item.get("name", "")),
			"own": _own_fabao(int(id)) == int(item.id), "lv": XMagicWeapon.level_of(item),
			"base": [float(p[0]), float(p[2]), float(p[4])], "growth": growth, "traits": rates,
			"on": on, "off": off, "delta": [on[0] - off[0], on[1] - off[1], on[2] - off[2]],
			"note_skills": XMagicWeapon.item_skills(item)}
		rows.append(row)
		print("FB_ROW " + JSON.stringify(row))
	XTianqiBase.PHASE4 = false
	XTianqiSkills.MASTERY = false
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, " "))
	get_tree().quit.call_deferred(0)
