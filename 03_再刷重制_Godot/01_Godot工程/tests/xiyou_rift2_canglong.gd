extends Node
## 【cc·未经审查】时空漩涡二阶段（XRift.STAGE2）、苍龙破晓重做（XCanglong.REWORK）、解放 146（XImportedBalance.RELEASE_CANGLONG）。
## 三个开关各开、关一组；关掉后数据回到原版（与转换产物逐项相同）。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _ev(id: int):
	var evs: Array = XDB.map(4).events
	return evs[id] if id < evs.size() else null


func _run() -> void:
	XConfig.path_override = "user://test_rift2_canglong_options.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	_rift()
	_whisper()
	_canglong_data()
	_canglong_formula()
	_release()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _rift() -> void:
	XRift.STAGE2 = true
	XRift.clear_cache()
	var v = _ev(75)
	check("stage", XRift.stage() == 2)
	check("drop_cell", XRift.canglong_drop_cell() == Vector2i(14, 21))
	check("vortex.img", str(v.pages[0].image.characterName) == "!Codex_Rift_Stage2", v.pages[0].image)
	var route: Array = v.pages[0].moveRoute.list
	check("vortex.route_img", route.filter(func(c): return int(c.code) == 41).all(func(c): return str(c.parameters[0]) == "!Codex_Rift_Stage2"))
	check("vortex.faster", route.filter(func(c): return int(c.code) == 15).all(func(c): return int(c.parameters[0]) == 3) and route.any(func(c): return int(c.code) == 15))
	check("vortex.text", v.pages[0].list.any(func(c): return int(c.code) == 401 and str(c.parameters[0]) == XRift.INVESTIGATE_TEXT))
	check("img.content", XDB.img_path("characters", "!Codex_Rift_Stage2") == "res://content/rift/!Codex_Rift_Stage2.png" and ResourceLoader.exists("res://content/rift/!Codex_Rift_Stage2.png"))
	check("img.generated_first", XDB.img_path("characters", "!Codex_Rift_Stage1").begins_with(XDB.BASE))
	var tex: Texture2D = load(XDB.img_path("characters", "!Codex_Rift_Stage2"))
	check("img.size", tex != null and tex.get_size() == Vector2(1344, 576))
	for id in [201, 202]:
		var b = _ev(id)
		check("block.%d" % id, b is Dictionary and int(b.y) == 19 and int(b.x) == (13 if id == 201 else 15) and int(b.pages[0].priorityType) == 1 and str(b.pages[0].image.characterName) == "", b)
		check("block.%d.bounce" % id, b is Dictionary and b.pages[0].list.any(func(c): return int(c.code) == 205))
	var r2 = _ev(203)
	check("rift2.pages", r2 is Dictionary and r2.pages.size() == 3 and int(r2.pages[0].trigger) == 4 and int(r2.pages[1].trigger) == 3 and str(r2.pages[1].conditions.selfSwitchCh) == "B" and str(r2.pages[2].conditions.selfSwitchCh) == "A")
	var body: Array = r2.pages[1].list
	check("rift2.mark_first", str(body[0].parameters[0]) == "CodexWhisper.mark('rift2');")
	check("rift2.lines", body.any(func(c): return int(c.code) == 401 and str(c.parameters[0]).contains("刷了很久")) and body.any(func(c): return int(c.code) == 401 and str(c.parameters[0]).contains("苍龙破晓")))
	check("rift2.self_a_last", int(body[body.size() - 2].code) == 123)
	var jump: Array = body.filter(func(c): return int(c.code) == 205)[0].parameters[1].list
	check("rift2.jump_to_drop", jump.any(func(c): return int(c.code) == 14 and Vector2i(int(c.parameters[0]), int(c.parameters[1])) == XRift.DROP - XRift.CELL))
	check("rift2.actor_img", jump.any(func(c): return int(c.code) == 41 and str(c.parameters[0]) == str(XDB.rec("Actors", 146).characterName)))
	check("canglong_ev", _ev(204) is Dictionary and bool(_ev(204).pages[0].through) and str(_ev(204).pages[0].image.characterName) == "")
	check("keep", XRift.keep_event(4, 201) and XRift.keep_event(4, 204) and not XRift.keep_event(4, 205) and not XRift.keep_event(5, 201))
	# 关
	XRift.STAGE2 = false
	XRift.clear_cache()
	check("off.stage", XRift.stage() == 1)
	check("off.img", str(_ev(75).pages[0].image.characterName) == "!Codex_Rift_Stage1")
	check("off.no_new", (XDB.map(4).events as Array).size() == 78 and not XRift.keep_event(4, 201))
	XLobbyDebugNpc.BOOK_ONLY = false  # 大厅全图鉴 NPC 也改 Map004（Kyo 11-12），比原图时一起关
	XRift.clear_cache()
	check("off.same_as_source", JSON.stringify(XDB.map(4)) == JSON.stringify(XDB.load_json("maps/Map004.json")))
	XLobbyDebugNpc.BOOK_ONLY = true
	XRift.STAGE2 = true
	XRift.clear_cache()


func _whisper() -> void:
	# rift1 在这一次进图里记下：rift2 条件里的虚拟键为真（本次不播），换一次图后为假
	XRift.CHAIN_AFTER_RIFT1 = false
	XRift.on_map_setup(4)
	check("visit.before", not XConfig.whisper_seen(XRift.THIS_VISIT_KEY))
	XConfig.whisper_mark("rift1")
	check("visit.same", XConfig.whisper_seen(XRift.THIS_VISIT_KEY))
	# 默认（玩家反馈 v0.01）：rift1 放完同一次进大厅就接着播 rift2，虚拟键恒为假
	XRift.CHAIN_AFTER_RIFT1 = true
	check("visit.chain_same", not XConfig.whisper_seen(XRift.THIS_VISIT_KEY))
	XRift.CHAIN_AFTER_RIFT1 = false
	check("visit.not_saved", not XConfig.whisper_seen("rift2") and not (XConfig._values.codexWhisperSeen as Array).has(XRift.THIS_VISIT_KEY))
	XRift.on_map_setup(132)
	XRift.on_map_setup(4)
	check("visit.next", not XConfig.whisper_seen(XRift.THIS_VISIT_KEY))
	XRift.CHAIN_AFTER_RIFT1 = true


func _canglong_data() -> void:
	XCanglong.REWORK = true
	XCanglong.clear_cache()
	var learn: Array = XDB.rec("Classes", 144).learnings.map(func(l): return [int(l.level), int(l.skillId)])
	check("learn", learn.has([10, 10093]) and learn.has([20, 10094]) and learn.has([30, 10095]) and learn.has([50, 10092]) and learn.has([60, 10096]) and not learn.has([2, 10092]), learn)
	check("learn.passives", learn.has([2, 10089]) and learn.has([33, 10090]) and learn.has([50, 10091]))
	for id in XCanglong.SKILLS:
		var s := XDB.rec("Skills", id)
		check("module.%d" % id, str(s.damage.formulaProgram.get("module", "")) == "canglong" and str(s.damage.formula).contains("a.level*a.level*0.02"), s.damage.formula)
		check("text.%d" % id, str(s.note).contains("真龙之力 size=18") and not str(s.note).contains("麒麟除魔值"))
		check("ai_safe.%d" % id, XSmartAI.formula_safe(str(s.damage.formula)))
		check("no4.%d" % id, not str(XCanglong.RATE[id]).contains("4"))
	check("yuxi.no_wtype", int(XDB.rec("Skills", 10093).requiredWtypeId1) == 0)
	check("zhudao.cd", str(XDB.rec("Skills", 10096).meta.get("Cooldown", "")).strip_edges() == "3" and str(XDB.rec("Skills", 10096).note).contains("<Cooldown: 3>") and str(XDB.rec("Skills", 10096).note).contains("冷却时间:3回合"))
	check("zhumie.cd_kept", str(XDB.rec("Skills", 10092).meta.get("Cooldown", "")).strip_edges() == "3")
	var p := str(XDB.rec("Skills", 10089).note)
	check("passive.text", not p.contains("\\v[1497]") and p.contains("真龙之力＝1+等级×等级×2%"), p)
	check("shangxie", str(XDB.rec("Armors", 137).note).contains("专属:苍龙破晓") and not str(XDB.rec("Armors", 137).note).contains("云无迹"))
	# 习得：9 级没有玉玺，10 级有；49 级没有诛灭，50 级有
	XState.current = XState.new_game_blank()
	var a := XActor.new().setup(146)
	a.change_level(9)
	check("lv9", not a.skill_ids.has(10093) and not a.skill_ids.has(10092), a.skill_ids)
	a.change_level(10)
	check("lv10", a.skill_ids.has(10093))
	a.change_level(49)
	check("lv49", a.skill_ids.has(10095) and not a.skill_ids.has(10092))
	a.change_level(60)
	check("lv60", a.skill_ids.has(10092) and a.skill_ids.has(10096))
	# 关：回原版
	XCanglong.REWORK = false
	XCanglong.clear_cache()
	XVegetaTune.original_data()  # 参照是原版：贝吉特优化调整也改 Skills，一并关掉，新行为由 xiyou_vegeta_tune 核
	for t in ["Skills", "Classes", "Armors"]:
		check("off.%s" % t, JSON.stringify(XDB.table(t)) == JSON.stringify(_source(t)))
	XVegetaTune.ENABLED = true
	XDB._tables.erase("Skills")
	XCanglong.REWORK = true
	XCanglong.clear_cache()


func _source(t: String):
	var raw = XDB.load_json("db/%s.json" % t)
	# 原表在 XDB.table 里还有别的补丁（真气、成长装备说明），一并打上再比
	if t == "Skills":
		XZhenqi.patch_rewards(raw)
		XGojo.patch_skills(raw)  # 天启篇五条悟的新技能
	if t == "Classes":
		XGojo.patch_classes(raw)
	if t == "Armors":
		for id in [XHeartsteel.ARMOR, XHeartsteel.LEVIATHAN, XHubris.ARMOR, XHubris.ATARAXIA]:
			if id < raw.size() and raw[id] is Dictionary:
				XGrowthHelp.describe(raw[id])
		XGojo.patch_armors(raw)  # 天启篇五条悟专属法宝「眼罩」
	return raw


func _canglong_formula() -> void:
	XState.current = XState.new_game_blank()
	var a := XActor.new().setup(146)
	a.change_level(70)
	a.tp = 100.0
	var b := XActor.new().setup(1)
	var z := 1.0 + 70 * 70 * 0.02
	check("dragon70", is_equal_approx(XCanglong.dragon_power(70), 99.0) and is_equal_approx(z, 99.0))
	check("dragon99", is_equal_approx(XCanglong.dragon_power(99), 197.02))
	var want := {
		10093: (a.atk + a.mat) * (1 + a.skillMasteryLevel(10093)) * 5000 * z,
		10094: (a.atk + a.mat) * (1 + a.skillMasteryLevel(10094)) * 5000 * z,
		10095: (a.atk + a.mat + a.luk) * (1 + a.skillMasteryLevel(10095)) * 3200 * z,
		10092: (a.mmp + a.mhp + a.atk + a.mat + a.def + a.mdf + a.agi + a.luk) * 85000 * z,
		10096: (a.atk + a.mat + a.luk) * 100.0 * 1000 * z,
	}
	for id in want:
		var item := XDB.rec("Skills", id)
		var got := XDamage.eval_formula(item, a, b, [])
		check("eval.%d" % id, is_equal_approx(got, float(want[id])) and got > 0, [got, want[id]])
	# 招式之间的顺序（低等级习得的单次不高于高等级的）取决于属性分布，按数值表的木桩条件（熟练 32、法宝 888）在原版引擎上复核，见交付单
	check("not_canglong_skill", XCanglong.formula(a, XDB.rec("Skills", 1)) == 0.0)


func _release() -> void:
	XImportedBalance.RELEASE_CANGLONG = true
	check("rel.not_disabled", not XImportedBalance.is_disabled_actor(146) and not XImportedBalance.is_hidden_actor(146))
	check("rel.others_still", XImportedBalance.is_disabled_actor(141) and XImportedBalance.is_hidden_actor(141))
	check("rel.horn", not XImportedBalance.horn_id_disabled(274) and XImportedBalance.horn_id_disabled(255))
	check("rel.horn_item", not XImportedBalance.is_disabled_horn(XDB.rec("Items", 274)))
	var goods := XItemMarks.shop_goods([[0, 274, 0, 0], [0, 255, 0, 0]], 0)
	check("rel.shop", goods.any(func(g): return g[1] == 274) and not goods.any(func(g): return g[1] == 255), goods)
	var s := XState.new_game_blank()
	XState.current = s
	s.party.assign([1])
	s.add_actor(146)
	check("rel.super_gate", not s.party.has(146), s.party)  # 超强者门槛照旧：地狱以下不能入队
	s.set_switch(2494, true)
	s.add_actor(146)
	check("rel.join", s.party.has(146), s.party)
	check("rel.book", XActorBook.index_ids().has(146))
	check("rel.baby", not XBabyAllActors.excluded(146) and XBabyAllActors.excluded(141))
	XImportedBalance.RELEASE_CANGLONG = false
	check("off.disabled", XImportedBalance.is_disabled_actor(146) and XImportedBalance.is_hidden_actor(146) and XImportedBalance.horn_id_disabled(274))
	check("off.shop", not XItemMarks.shop_goods([[0, 274, 0, 0]], 0).any(func(g): return g[1] == 274))
	check("off.book", not XActorBook.index_ids().has(146))
	XImportedBalance.RELEASE_CANGLONG = true
