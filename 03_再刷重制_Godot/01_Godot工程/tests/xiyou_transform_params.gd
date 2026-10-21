extends Node
## 336 变身能力值缓存（krz_state_re 的 _ParamCache2／need_refresh_param）：逐项对照 battle_event_probe 的
## command336.param-cache-466（oracle/battle_events.json）。敌群 466 的敌人 534 开战后变 538：
## 九种预热组合（只有变身前读过的格子留旧值，冷格首读取新值）、连续变身、22 个刷新边界（状态／buff／gain／回合）、
## 真实 336→334、336→333→334。每步比原始格子（有效与否、缓存值）、dirty 与读到的 2～7 号参数；观察用的读数只在参照也读的位置。
## 操作对应：refresh＝refresh_resources；setHp／setMp＝改值后 refresh；addBuff／addDebuff／removeBuff＝sequence_buff；
## onTurnEnd＝turn_end_battler；onTurnStart 单独只标 dirty（start_turn 里紧接的 Game_Unit refresh 不在此例）；
## recoverAll＝enemy_recover_all（334）；333＝_change_enemy_state；gain*＝XResourceContext。
const IDS := [2, 3, 4, 5, 6, 7]
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func battle() -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026102100000466"
	var logic := XBattleLogic.new()
	logic.level_roll = 0.99
	logic.setup(466, s)
	return logic


## 参照 cacheRaw 的缓存部分：dirtyParams[i]＝0 的格子有效，有效格比缓存值
func raw(e: XEnemy) -> Dictionary:
	return {"dirty": e.param_dirty, "cells": e.param_cells.duplicate()}


func same_raw(name: String, e: XEnemy, want: Dictionary) -> void:
	var got := raw(e)
	var ok: bool = got.dirty == bool(want.needRefresh) and got.cells.size() == 8
	if ok:
		for i in range(8):
			var valid := int(want.dirtyParams[i]) == 0
			if (got.cells[i] != null) != valid or (valid and float(got.cells[i]) != float(want.cache[i])):
				ok = false
	check(name, ok, [got, want])


func read(e: XEnemy) -> Array:
	return IDS.map(func(i): return e.param(i))


func same_read(name: String, e: XEnemy, want: Dictionary) -> void:
	same_raw(name + ".raw", e, want.before)
	var got := read(e)
	check(name + ".params", got == Array(want.params).map(func(x): return float(x)), [got, want.params])


func op(logic: XBattleLogic, e: XEnemy, id: String) -> void:
	var ctx := XResourceContext.new()
	match id:
		"refresh":
			e.refresh_resources()
		"setHp":
			e.hp -= 1.0
			e.refresh_resources()
		"setMp":
			e.mp -= 1.0
			e.refresh_resources()
		"addState4":
			e.add_state(4)
		"removeState4":
			e.remove_state(4)
		"clearStates", "clearStates.state77":
			e.clear_states()
		"recoverAll", "recoverAll.state77":
			logic.enemy_recover_all(0)
		"addBuff2":
			logic.sequence_buff(e, 2, true, true, 3)
		"addDebuff2":
			logic.sequence_buff(e, 2, true, false, 3)
		"removeBuff2":
			logic.sequence_buff(e, 2, false, true, 0)
		"onTurnStart":
			e.param_mark_dirty()
		"onTurnEnd":
			logic.turn_end_battler(e, [])
		"dirtyRefresh":
			e.param_mark_dirty()
			e.refresh_resources()
		"gainHp-1":
			ctx.gain(e, "hp", -1.0)
		"gainMp-1":
			ctx.gain(e, "mp", -1.0)
		"gainTp1":
			ctx.gain(e, "tp", 1.0)
		"gainSilentTp1":
			ctx.silent_gain(e, "tp", 1.0)
		"gainHp0":
			ctx.gain(e, "hp", 0.0)
		"gainMp0":
			ctx.gain(e, "mp", 0.0)
		"gainTp0":
			ctx.gain(e, "tp", 0.0)
		_:
			check("op_known." + id, false)


func prepare(logic: XBattleLogic, e: XEnemy, id: String) -> void:
	match id:
		"removeState4":
			e.add_state(4)
		"clearStates.state77", "recoverAll.state77":
			e.add_state(77)
		"removeBuff2":
			logic.sequence_buff(e, 2, true, true, 3)


func _run() -> void:
	var ref = XDB.load_json("oracle/battle_events.json")
	var c := {}
	for row in (ref.get("cases", []) if ref is Dictionary else []):
		if row.id == "command336.param-cache-466":
			c = row
	if c.is_empty():
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	check("oracle_clean", c.errors.is_empty(), c.errors)
	var o: Dictionary = c.observed
	var logic := battle()
	var e: XEnemy = logic.enemies[0]
	check("fixture", e.enemy_id == 534 and int(o.fixture.from) == 534 and int(o.fixture.to) == 538, [e.enemy_id, o.fixture])
	same_raw("initialized", e, o.initialized)
	for w in o.warm:
		var name := "warm.%s" % ("none" if w.warm.is_empty() else "-".join(w.warm.map(func(x): return str(int(x)))))
		logic = battle()
		e = logic.enemies[0]
		var warmed: Array = w.warm.map(func(i): return e.param(int(i)))
		check(name + ".warmed", warmed == Array(w.warmed).map(func(x): return float(x)), [warmed, w.warmed])
		same_raw(name + ".before", e, w.before)
		logic.enemy_transform(0, 538)
		same_read(name + ".after", e, w.after)
	logic = battle()
	e = logic.enemies[0]
	check("twice.old", read(e) == Array(o.twice.old).map(func(x): return float(x)))
	logic.enemy_transform(0, 538)
	same_read("twice.first", e, o.twice.first)
	logic.enemy_transform(0, 534)
	same_read("twice.second", e, o.twice.second)
	for b in o.boundaries:
		var name := "boundary." + str(b.id)
		logic = battle()
		e = logic.enemies[0]
		prepare(logic, e, str(b.id))
		e.refresh_resources()
		check(name + ".clean", not e.param_dirty)
		check(name + ".old", read(e) == Array(b.old).map(func(x): return float(x)), [read(e), b.old])
		logic.enemy_transform(0, 538)
		same_read(name + ".transformed", e, b.transformed)
		op(logic, e, str(b.id))
		same_read(name + ".after", e, b.after)
		e.refresh_resources()
		same_read(name + ".following", e, b.followingRefresh)
	for it in o.interpreter:
		var name := "interpreter." + str(it.id)
		logic = battle()
		e = logic.enemies[0]
		if int(it.state) != 0:
			e.add_state(int(it.state))
		e.refresh_resources()
		e.hp = floorf(e.hp / 3.0)
		e.refresh_resources()
		e.mp = 0.0
		e.refresh_resources()
		check(name + ".old", read(e) == Array(it.old).map(func(x): return float(x)), [read(e), it.old])
		same_raw(name + ".before", e, it.before)
		for step in str(it.id).split("-"):
			if step == "336":
				logic.enemy_transform(0, 538)
			elif step == "334":
				logic.enemy_recover_all(-1)
			elif step.begins_with("333add"):
				logic._change_enemy_state([0, 0, int(step.substr(6))])
			elif step.begins_with("333remove"):
				logic._change_enemy_state([0, 1, int(step.substr(9))])
		check(name + ".hp_old_cap", e.hp == float(it.before.cache[0]), [e.hp, it.before.cache[0]])
		same_read(name + ".after", e, it.after)
	# 预览／克隆隔离：克隆带走当时的格子，克隆上读冷格不暖原对象
	logic = battle()
	e = logic.enemies[0]
	var clone := XFormulaContext.clone_battler(e) as XEnemy
	check("clone.made", clone != null)
	if clone != null:
		clone.param(2)
		check("clone.isolated", e.param_cells[2] == null and clone.param_cells[2] != null, [e.param_cells, clone.param_cells])
	# 战斗结束退出缓存：之后每次重算
	logic.enemy_transform(0, 538)
	logic.end_battle()
	check("end_battle.uncached", not e.param_cache_on and e.param(2) == e.param_now(2))
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
