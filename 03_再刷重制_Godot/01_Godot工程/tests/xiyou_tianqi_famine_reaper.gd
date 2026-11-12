extends Node
## 天启篇饥荒线「荒年」与余粮、终焉掠夺者扣金钱（精魄）、终焉收尸人吸收技能（cc/tianqi-famine-reaper）。
## 数字避开 4。

const CONFIG := "user://xiyou_tianqi_famine_reaper_config.json"
const TROOP3 := 2   # 嘤嘤怪×3
var results: Array = []


class FakeHost extends RefCounted:
	var said: Array = []
	var answers: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1


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


func _fight(s: XState, line: String, rows: Array) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(TROOP3, s)
	var list := []
	for r in rows:
		list.append({"enemy": lg.enemies[int(r[0])], "tier": str(r[1]), "kind": str(r[2])})
	XTianqiLine.alien_apply(line, lg, s, list)
	return lg


func _kill(b) -> void:
	b.hp = 0.0
	b.add_state(1)


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	_gold()
	_lean_year()
	await _quiz()
	_reaper()
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


# ---- 精魄（金钱） ----

func _gold() -> void:
	var s := _state("famine")
	s.gold = 10000
	var lg := _fight(s, "famine", [[0, "zhongyan", "plunder"]])
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	a.mp = 50.0
	XTianqiFamineAlien.hp_damage(lg, e, a, 10.0)
	_check("plunder_gold", s.gold == 9900, s.gold)
	for i in 30:
		XTianqiFamineAlien.hp_damage(lg, e, a, 10.0)
	_check("plunder_cap", s.gold == 9000, s.gold)
	_kill(e)
	XTianqiFamineAlien.take_logs(lg)
	_check("plunder_refund", s.gold == 10000, s.gold)
	lg.end_battle(1)
	var s2 := _state("famine")
	s2.gold = 10000
	var l2 := _fight(s2, "famine", [[0, "huaxing", "plunder"]])
	XTianqiFamineAlien.hp_damage(l2, l2.enemies[0], l2.actors[0], 10.0)
	_check("plunder_huaxing_no_gold", s2.gold == 10000)
	l2.end_battle(1)


# ---- 荒年、余粮 ----

func _lean_year() -> void:
	var s := _state("famine")
	var plain_lg := XBattleLogic.new()
	plain_lg.setup(TROOP3, s)
	var base: Array = plain_lg.drop_chances(plain_lg.enemies[0])
	plain_lg.end_battle(1)
	var lg := _fight(s, "famine", [[0, "shigu", "lean"]])
	var cut: Array = lg.drop_chances(lg.enemies[0])
	_check("lean_drop", not base.is_empty() and is_equal_approx(float(cut[0].chance), float(base[0].chance) * 0.67), [base, cut])
	# 余粮：必掉（测试把几率调成 1）
	var ly: Dictionary = XTianqiFamineAlien.data().lean_year
	var old: Array = ly.grain_chance.duplicate()
	ly.grain_chance = [1.0, 1.0, 1.0, 1.0]
	_kill(lg.enemies[0])
	var n := XTianqiFamineAlien.grant_grain(lg)
	ly.grain_chance = old
	_check("grain_drop", n == 1 and XTianqiFamineAlien.grain(s) == 1 and lg.victory_texts.any(func(t): return str(t).contains("余粮")), [n, XTianqiFamineAlien.grain(s)])
	lg.end_battle(0)
	# 口粮先扣余粮
	var l2 := _fight(s, "famine", [[0, "shigu", "exhaust"]])
	var a: XActor = l2.actors[0]
	a.mp = a.mmp
	var mp0 := a.mp
	XTianqiFamineAlien.after_pay(l2, a, XDB.rec("Skills", 10), {"mp": 0, "tp": 0})
	_check("ration_grain", XTianqiFamineAlien.grain(s) == 0 and a.mp == mp0, [XTianqiFamineAlien.grain(s), mp0, a.mp])
	XTianqiFamineAlien.after_pay(l2, a, XDB.rec("Skills", 10), {"mp": 0, "tp": 0})
	_check("ration_mp_after", a.mp < mp0 or l2.skill_hp_cost(a, XDB.rec("Skills", 10)) > 0, [mp0, a.mp])
	l2.end_battle(1)


func _quiz() -> void:
	var s := _state("famine")
	var h := FakeHost.new()
	var qs: Array = XTianqiFamineLine.data().get("quiz", {}).get("questions", [])
	h.answers = [0] + qs.map(func(q): return int(q.answer))
	await XTianqiFamineLine.after_beat(h, s, "rumor25")
	_check("quiz_grain", XTianqiFamineAlien.grain(s) == qs.size() and qs.size() > 0, [XTianqiFamineAlien.grain(s), qs.size()])


# ---- 收尸人 ----

func _reaper() -> void:
	var s := _state("death")
	var lg := _fight(s, "death", [[0, "zhongyan", "reaper"]])
	var e: XEnemy = lg.enemies[0]
	var dead: XActor = null
	for a in lg.actors:
		if not XAlienation.original_active(a).filter(func(sk): return int(sk.get("damage", {}).get("type", 0)) in [1, 5]).is_empty():
			dead = a
			break
	_check("reaper_has_victim", dead != null)
	if dead == null:
		return
	_kill(dead)
	XTianqiDeathAlien.after_action(lg, lg.actors[0] if lg.actors[0] != dead else lg.actors[1])
	var absorbed: Array = XTianqiDeathAlien.fight(lg).absorbed.get(e, [])
	_check("reaper_absorbed", absorbed.size() == 1 and XAlienation.original_active(dead).any(func(sk): return int(sk.id) == int(absorbed[0])), absorbed)
	var used := 0
	for i in 30:
		var d := XTianqiDeathAlien.decide_absorbed(lg, e)
		if not d.is_empty() and int(d[0].id) == int(absorbed[0]):
			used += 1
	_check("reaper_uses_sometimes", used > 0 and used < 30, used)
	lg.end_battle(1)
	# 化形收尸人不吸
	var s2 := _state("death")
	var l2 := _fight(s2, "death", [[0, "huaxing", "reaper"]])
	_kill(l2.actors[0])
	XTianqiDeathAlien.after_action(l2, l2.actors[1])
	_check("reaper_huaxing_none", XTianqiDeathAlien.fight(l2).absorbed.is_empty())
	l2.end_battle(1)
