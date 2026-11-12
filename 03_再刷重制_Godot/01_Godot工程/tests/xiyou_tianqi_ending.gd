extends Node
## 天启篇结局收尾专项（cc/tianqi-ending）：
## 一、异化图鉴本线页（XTianqiAlienCodex）：赢了点亮倒下的本线异化怪（跨存档配置）、没倒下／原版档不记、工坊页里显示。
## 二、36 层决战结局：第一次通关说「本档获得了「可轮回」」，再打不再说；读档界面线名后面标「可轮回」。
## 三、选线竖卡：跨存档通关过的线卡上「★ 已通关」。
## 数字避开 4。

const CONFIG := "user://xiyou_tianqi_ending_config.json"
const TROOP3 := 2   # 嘤嘤怪×3
var results: Array = []


class FakeHost extends RefCounted:
	var said: Array = []
	var results: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		return options.size() - 1
	func start_battle(_troop: int, _can_escape: bool, _can_lose: bool, _random := false) -> int:
		XTianqiHorsemen._pending = ""
		XTianqiHorsemen._pending_mode = "body"
		return int(results.pop_front()) if not results.is_empty() else 0


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(line: String) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	s.set_variable(20, 3)
	XState.current = s
	s.flags.tianqi["line"] = line
	XTianqiLine.progress(line, s)["stage"] = XTianqiLine.stage_done(line)
	return s


func _fight(s: XState, line: String, kind: String, tier: String, kill := true) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(TROOP3, s)
	var e: XEnemy = lg.enemies[0]
	XTianqiLine.alien_apply(line, lg, s, [{"enemy": e, "tier": tier, "kind": kind}])
	if kill:
		e.hp = 0.0
		e.add_state(1)
	return lg


func _reset_config() -> void:
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	XConfig._loaded_path = "<unloaded>"


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	_reset_config()
	_codex()
	await _codex_page()
	await _ending()
	await _cards()
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、异化图鉴 ----

func _codex() -> void:
	var s := _state("war")
	var kinds := XTianqiLine.alien_kinds("war")
	_check("codex_empty", XTianqiAlienCodex.progress("war") == [0, kinds.size() * 3 + kinds.size()])
	var lg := _fight(s, "war", "berserk", "shigu")
	lg.grant(lg.rewards())
	_check("codex_lit", XTianqiAlienCodex.seen("war", "berserk", "shigu") and not XTianqiAlienCodex.seen("war", "berserk", "qinran"))
	_check("codex_progress", XTianqiAlienCodex.progress("war")[0] == 1)
	_check("codex_saved", XConfig.tianqi_aliens().has("war:berserk:shigu"))
	lg.end_battle(0)
	# 跨存档：换一档还是亮的
	var s2 := _state("war")
	_check("codex_cross_save", XTianqiAlienCodex.seen("war", "berserk", "shigu") and s2 != s)
	# 没倒下不记
	var la := _fight(s2, "war", "fervor", "huaxing", false)
	la.grant(la.rewards())
	_check("codex_alive_none", not XTianqiAlienCodex.seen("war", "fervor", "huaxing"))
	la.end_battle(0)
	# 开关关掉不记
	XTianqiAlienCodex.ENABLED = false
	var lo := _fight(_state("war"), "war", "commander", "huaxing")
	lo.grant(lo.rewards())
	_check("codex_off", not XTianqiAlienCodex.seen("war", "commander", "huaxing"))
	lo.end_battle(0)
	XTianqiAlienCodex.ENABLED = true
	# 原版档不记
	var plain := XState.new_game(3, 1, [8, 9, 10])
	XState.current = plain
	_check("codex_plain", not XTianqiAlienCodex.on(plain) and XTianqiAlienCodex.record(XBattleLogic.new()) == [])
	var rows := XTianqiAlienCodex.rows("war")
	var berserk: Array = rows.filter(func(r): return r.kind == "berserk")
	_check("codex_rows", rows.size() == kinds.size() and berserk.size() == 1 and berserk[0].name == "战狂" and berserk[0].cells[1].seen and not berserk[0].cells[0].seen)


func _codex_page() -> void:
	var s := _state("war")
	XAlienWorkshop.selected = ""
	var page := XAlienWorkshop.new()
	add_child(page)
	await get_tree().process_frame
	var texts := XAlienWorkshop.flatten(page.tree).map(func(r): return str(r.get("text", "")))
	var total: int = int(XTianqiAlienCodex.progress("war")[1])
	_check("page_codex", texts.has("本线异化图鉴（1／%d）" % total) and texts.has("战狂：？？　蚀骨　？？　？？"), texts)
	page.queue_free()
	XState.current = s


# ---- 二、结局 ----

func _ending() -> void:
	var s := _state("war")
	var h := FakeHost.new()
	h.results = [0]
	var r: int = await XTianqiLine.run_final(h, s, "war")
	_check("final_win", r == 0 and bool(s.flags.tianqi.get("reincarnate", false)))
	_check("final_reincarnate_said", h.said.any(func(t): return str(t).contains("本档获得了「可轮回」") and str(t).contains("战争线·终")), h.said)
	_check("final_cc_easter_egg", h.said.any(func(t): return str(t).contains("未经姐姐复核")))
	var h2 := FakeHost.new()
	h2.results = [0]
	await XTianqiLine.run_final(h2, s, "war")
	_check("final_once", not h2.said.any(func(t): return str(t).contains("可轮回")), h2.said)
	# 读档界面：线名后面标可轮回
	var d := s.to_dict()
	_check("save_reincarnate", XSaveScene.can_reincarnate(d) and not XSaveScene.can_reincarnate(_state("war").to_dict()))
	_check("save_line", XSaveScene.save_line(d) == "war")


# ---- 三、选线竖卡 ----

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _cards() -> void:
	_state("war")
	XTianqiRewards.mark_badge("war")
	var c := XTianqiLineCards.new()
	c.lines = XTianqi.LINES
	c.playable = [true, true, true, true]
	add_child(c)
	await _frames(2)
	var war_i := XTianqi.LINES.find_custom(func(l): return l.key == "war")
	var other := 1 if war_i != 1 else 0
	_check("card_cleared", c._cards[war_i].done_tag != null and c._cards[war_i].done_tag.text.contains("已通关") and c._cards[other].done_tag == null)
	c.queue_free()
