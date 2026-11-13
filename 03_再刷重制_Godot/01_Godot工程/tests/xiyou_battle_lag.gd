extends Node
## 【cc·未经审查】战斗卡顿（Kyo 11-13 v0.01.07 反馈：每个角色行动完卡约 0.5 秒、退出战斗卡、伤害高了卡）：
## - XBattleScene.VIEW_LITE：敌人血条、名字淡入淡出、Boss 血条每帧只读血量、上限、倒没倒，不再每帧整份 view_of；
##   三项与 view_of 一样，演出中照旧读快照，关掉回到 view()；
## - XMenu.BIG_INT_TEXT：超过 int 范围的数字照原值写，不再溢出成 9223372036854775807；
## - XZhenqi.WEAPON_TYPES_CACHE：胜利结算的本命兵武器类型留一份（与现算相同、给副本），技能备注先按字面筛（结果同逐条正则）。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_lag"
	XConfig.path_override = XSave.dir().path_join("options.json")
	await _view_lite()
	_int_text()
	_weapon_types()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _view_lite() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var scene := XBattleScene.new()
	scene.setup(2, true, false, {})
	add_child(scene)
	await get_tree().physics_frame
	var e: XEnemy = scene.logic.enemies[0]
	e.hp = floorf(e.mhp / 3.0)
	var full := scene.logic.view_of(e)
	var lite := scene.view_lite(e)
	check("lite_matches_view_of", lite.hp == full.hp and lite.mhp == full.mhp and lite.dead == full.dead and lite.size() == 3, [lite, full.hp, full.mhp, full.dead])
	e.hp = 0.0
	e.refresh_resources()
	check("lite_dead_live", bool(scene.view_lite(e).dead) == e.is_dead() and bool(scene.logic.view_of(e).dead) == e.is_dead(), scene.view_lite(e))
	# 演出中读快照（结算后的值），不读实时
	scene.show_views({e: {"hp": 7.0, "mhp": 9.0, "dead": false, "cell_rows": []}})
	check("lite_uses_shown", scene.view_lite(e).hp == 7.0 and not scene.view_lite(e).dead)
	scene.clear_views()
	# 回退：每次整份 view_of
	XBattleScene.VIEW_LITE = false
	check("lite_rollback_full_view", scene.view_lite(e).has("cell_rows"))
	XBattleScene.VIEW_LITE = true
	check("lite_on_no_full_view", not scene.view_lite(e).has("cell_rows"))
	scene.queue_free()
	await get_tree().physics_frame


func _int_text() -> void:
	check("int_small_same", XMenu.int_text(123456.0) == str(int(123456.0)) and XMenu.int_text(-42.0) == "-42")
	check("int_big_exact", XMenu.int_text(1e22) == "10000000000000000000000", XMenu.int_text(1e22))
	check("int_big_negative", XMenu.int_text(-1e30).begins_with("-1000000000000000") and not XMenu.int_text(-1e30).contains("922337"), XMenu.int_text(-1e30))
	check("group_big", XMenu._group(1e22) == "10,000,000,000,000,000,000,000", XMenu._group(1e22))
	check("group_small_same", XMenu._group(1234567.0) == "1,234,567")
	check("popup_heal_big", not XDamagePopup.format_number(-1e30).contains("922337"), XDamagePopup.format_number(-1e30))
	check("boss_number_big", not XBossHpBar.format_number(1e40).contains("922337"), XBossHpBar.format_number(1e40))
	XMenu.BIG_INT_TEXT = false
	check("int_rollback_old", XMenu.int_text(1e22) == str(int(1e22)))
	XMenu.BIG_INT_TEXT = true


func _weapon_types() -> void:
	XZhenqi.WEAPON_TYPES_CACHE = false
	XZhenqi._skills = {}
	var plain := XZhenqi.weapon_types()
	var plain_skills := XZhenqi._skills.duplicate()
	XZhenqi.WEAPON_TYPES_CACHE = true
	XZhenqi._skills = {}
	var cached := XZhenqi.weapon_types()
	check("skill_key_filter_same", XZhenqi._skills == plain_skills and plain_skills.size() > 1, [XZhenqi._skills.size(), plain_skills.size()])
	check("weapon_types_same", cached == plain and not plain.is_empty(), [cached, plain])
	cached.append(999)
	check("weapon_types_copy", XZhenqi.weapon_types() == plain)
	var t := Time.get_ticks_usec()
	for i in 20:
		XZhenqi.weapon_types()
	var on := Time.get_ticks_usec() - t
	XZhenqi.WEAPON_TYPES_CACHE = false
	t = Time.get_ticks_usec()
	for i in 20:
		XZhenqi.weapon_types()
	var off := Time.get_ticks_usec() - t
	XZhenqi.WEAPON_TYPES_CACHE = true
	print("PERF weapon_types x20 cache_us=", on, " plain_us=", off)
