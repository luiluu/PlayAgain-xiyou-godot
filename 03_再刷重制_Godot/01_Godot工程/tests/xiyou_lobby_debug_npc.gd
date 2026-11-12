extends Node
## 大厅全图鉴 NPC（事件 55）与测试模式 99 级 NPC（事件 69）：XLobbyDebugNpc（玩家 v0.01.01 反馈，Kyo 11-12）。
## - 55 放回大厅，只做怪物图鉴全部登记（不给成就、称号）；BOOK_NPC／BOOK_ONLY 回退。
## - 69 放进地图，开关 2501 跟测试模式对齐（只在变了时写）；TEST_GATE 回退。
const DIR := "user://test_lobby_debug_npc"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _codes(list: Array) -> Array:
	return list.map(func(c): return int(c.code))


func _run() -> void:
	_book()
	_gate()
	XTestMode.unlock_override = ""
	XTestMode.state_override = ""
	XTestMode._on_loaded_from = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _book() -> void:
	check("keep_book", XLobbyDebugNpc.keep_event(4, 55) and XLobbyDebugNpc.keep_event(4, 69)
		and not XLobbyDebugNpc.keep_event(5, 55) and not XLobbyDebugNpc.keep_event(4, 54))
	var map := XDB.map(4)
	var list: Array = map.events[55].pages[0].list
	var text := JSON.stringify(list)
	check("book_only_enemybook", int(list[0].code) == 356 and str(list[0].parameters[0]) == "EnemyBook complete"
		and _codes(list) == [356, 101, 401, 0] and str(list[2].parameters[0]) == "图鉴获取完毕", _codes(list))
	check("book_no_achievement_title", not text.contains("GetAcReward") and not text.contains("DesignationN"))
	# 回退：BOOK_ONLY = false 照原版整页
	var raw = XDB.load_json("maps/Map004.json")
	XLobbyDebugNpc.BOOK_ONLY = false
	XLobbyDebugNpc.patch_map(4, raw)
	XLobbyDebugNpc.BOOK_ONLY = true
	check("book_rollback_full", JSON.stringify(raw.events[55].pages[0].list).contains("GetAcReward"))
	XLobbyDebugNpc.BOOK_NPC = false
	check("book_rollback_hidden", not XLobbyDebugNpc.keep_event(4, 55) and XLobbyDebugNpc.keep_event(4, 69))
	XLobbyDebugNpc.BOOK_NPC = true
	# 那条插件指令只登记怪物图鉴
	var s := XState.new_game_blank()
	check("book_starts_empty", not XEnemyBook.registered(s, 1))
	XEnemyBook.plugin_command(s, PackedStringArray(["EnemyBook", "complete"]))
	check("book_complete_registers", XEnemyBook.registered(s, 1) and XEnemyBook.registered(s, XDB.table("Enemies").size() - 1))


func _gate() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in ["unlock", "state"]:
		DirAccess.remove_absolute(DIR.path_join(f))
	XTestMode.unlock_override = DIR.path_join("unlock")
	XTestMode.state_override = DIR.path_join("state")
	XTestMode._on_loaded_from = "<unloaded>"
	var s := XState.new_game_blank()
	s.set_switch(2501, true)  # 旧档或别处开着：没测试模式要关掉
	check("gate_off_without_test_mode", XLobbyDebugNpc.sync(s) and not s.switch(2501))
	check("gate_no_rewrite", not XLobbyDebugNpc.sync(s))
	for f in [["unlock", ""], ["state", "1"]]:
		var h := FileAccess.open(DIR.path_join(f[0]), FileAccess.WRITE)
		h.store_string(f[1])
		h.close()
	XTestMode._on_loaded_from = "<unloaded>"
	check("gate_on_with_test_mode", XTestMode.enabled() and XLobbyDebugNpc.sync(s) and s.switch(2501))
	XLobbyDebugNpc.TEST_GATE = false
	s.set_switch(2501, false)
	check("gate_rollback", not XLobbyDebugNpc.sync(s) and not s.switch(2501) and not XLobbyDebugNpc.keep_event(4, 69))
	XLobbyDebugNpc.TEST_GATE = true
	# 事件 69 的显示页：开关开时第 1 页（!smallbirds），关时第 0 页空页
	var ev: Dictionary = XDB.map(4).events[69]
	check("gate_page_condition", bool(ev.pages[1].conditions.switch1Valid) and int(ev.pages[1].conditions.switch1Id) == 2501
		and str(ev.pages[0].image.characterName) == "", ev.pages[1].conditions)
	for f in ["unlock", "state"]:
		DirAccess.remove_absolute(DIR.path_join(f))
