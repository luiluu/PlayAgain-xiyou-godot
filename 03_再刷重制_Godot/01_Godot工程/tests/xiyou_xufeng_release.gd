extends Node
## 【cc·未经审查】T411 解放徐凤年 152（XImportedBalance.RELEASE_XUFENG）、号角 359 上架门槛（XUFENG_HORN_GATE，看过 T412 的 rift3 过场）、
## 天启篇候选池暂不放（XUFENG_TIANQI）、改版向导 Map004 EV071 停用名单删掉已解放的苍龙破晓与徐凤年。各开、关一组。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _guide_line() -> String:
	XDB._tables.erase("map:4")
	for p in XDB.map(4).events[71].pages:
		for c in p.list:
			if int(c.code) == 401 and str(c.parameters[0]).contains("已停用，不能招募"):
				return str(c.parameters[0])
	return ""


func _run() -> void:
	XConfig.path_override = "user://test_xufeng_release_options.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	XFestLobby.ENABLED = false
	XImportedBalance.RELEASE_CANGLONG = true
	XImportedBalance.RELEASE_XUFENG = true
	check("rel.not_disabled", not XImportedBalance.is_disabled_actor(152) and not XImportedBalance.is_hidden_actor(152))
	check("rel.others_still", XImportedBalance.is_disabled_actor(141) and XImportedBalance.is_hidden_actor(157))
	check("rel.horn", not XImportedBalance.horn_id_disabled(359) and XImportedBalance.horn_id_disabled(255))
	check("rel.horn_item", not XImportedBalance.is_disabled_horn(XDB.rec("Items", 359)))
	check("rel.lists_unchanged", XImportedBalance.DISABLED_ACTORS.has(152) and XImportedBalance.HIDDEN_ACTORS.has(152) and XImportedBalance.DISABLED_HORNS.has(359))
	# 号角上架门槛：没看过 rift3 → 新档买不到，看过就上架；已有号角／已在仓库／已在队伍的老档照旧上架
	var rows := [[0, 359, 0, 0], [0, 274, 0, 0], [0, 255, 0, 0]]
	var s := XState.new_game_blank()
	XState.current = s
	check("gate.not_seen", not XImportedBalance.xufeng_gate_met())
	var g := XItemMarks.shop_goods(rows, 132)
	check("gate.new_save", not g.any(func(x): return x[1] == 359) and not g.any(func(x): return x[1] == 255), g)
	XConfig.whisper_mark("rift2")
	g = XItemMarks.shop_goods(rows, 132)
	check("gate.rift2_not_enough", not g.any(func(x): return x[1] == 359) and g.any(func(x): return x[1] == 274), g)
	XConfig.whisper_mark("rift3")  # T412 三阶过场记的键
	g = XItemMarks.shop_goods(rows, 132)
	check("gate.rift3", XImportedBalance.xufeng_gate_met() and g.any(func(x): return x[1] == 359) and not g.any(func(x): return x[1] == 255), g)
	# T411 P2-1：三阶开关 XRift.STAGE3 关掉时，即使看过 rift3 也不上架
	XRift.STAGE3 = false
	check("gate.stage3_off", not XImportedBalance.xufeng_gate_met() and not XItemMarks.shop_goods(rows, 132).any(func(x): return x[1] == 359))
	XRift.STAGE3 = true
	(XConfig._values.codexWhisperSeen as Array).erase("rift3")
	s.items[359] = 1
	check("gate.owner", XItemMarks.shop_goods(rows, 132).any(func(x): return x[1] == 359))
	XState.current = XState.new_game_blank()
	XState.current.saved_actors.append(152)
	check("gate.stored", XItemMarks.shop_goods(rows, 132).any(func(x): return x[1] == 359))
	XState.current = XState.new_game_blank()
	XState.current.party.append(152)
	check("gate.in_party", XItemMarks.shop_goods(rows, 132).any(func(x): return x[1] == 359))
	XState.current = XState.new_game_blank()
	XImportedBalance.XUFENG_HORN_GATE = false
	check("gate.off", XItemMarks.shop_goods(rows, 132).any(func(x): return x[1] == 359))
	XImportedBalance.XUFENG_HORN_GATE = true
	# 入队：超强者门槛照旧（同苍龙，开关 2494）
	s = XState.current
	s.party.assign([1])
	s.add_actor(152)
	check("join.super_gate", not s.party.has(152), s.party)
	s.set_switch(2494, true)
	s.add_actor(152)
	check("join.ok", s.party.has(152), s.party)
	check("book", XActorBook.index_ids().has(152))
	check("baby", not XBabyAllActors.excluded(152) and XBabyAllActors.excluded(141))
	check("migrate.keeps", not XImportedBalance.migrate_party(s) and s.party.has(152))
	# 天启篇候选池：T411 技能卡接线量数过线后默认打开（进超强者池）；关掉可回退
	check("tianqi.pool_on", not XTianqi._disabled(152) and not XTianqi._disabled(122))
	XImportedBalance.XUFENG_TIANQI = false
	check("tianqi.pool_blocked", XTianqi._disabled(152))
	XImportedBalance.XUFENG_TIANQI = true
	# 改版向导那句：两人都解放 → 两个名字都不在；各自关掉各自回来
	var line := _guide_line()
	check("guide.both", line.contains("花橙、落芸、胡桃") and not line.contains("苍龙破晓") and not line.contains("徐凤年"), line)
	XImportedBalance.RELEASE_CANGLONG = false
	line = _guide_line()
	check("guide.canglong_off", line.contains("落芸、苍龙破晓、胡桃") and not line.contains("徐凤年"), line)
	XImportedBalance.RELEASE_XUFENG = false
	line = _guide_line()
	check("guide.both_off", line.contains("落芸、苍龙破晓、徐凤年、胡桃"), line)
	# 开关关：回原版
	check("off.disabled", XImportedBalance.is_disabled_actor(152) and XImportedBalance.is_hidden_actor(152) and XImportedBalance.horn_id_disabled(359))
	check("off.shop", not XItemMarks.shop_goods([[0, 359, 0, 0]], 0).any(func(x): return x[1] == 359))
	check("off.book", not XActorBook.index_ids().has(152))
	XImportedBalance.RELEASE_CANGLONG = true
	XImportedBalance.RELEASE_XUFENG = true
	XCanglong.original_data()
	check("original_data.off", not XImportedBalance.RELEASE_XUFENG)
	XImportedBalance.RELEASE_XUFENG = true
	XDB._tables.erase("map:4")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
