extends Node
## 【cc·rules-fix9·未经审查】条件分歧 111 类型 5（敌人）在地图上的取值，与 212／213 不勾等待时不先出待显示文字。
## 原版取值（mv_oracle/troop_condition_probe.cjs 实跑正式引擎，敌群 2）：
##   没打过仗：敌群为空，出现／状态全 false；
##   打赢（全死）：0 号「出现」false、「状态 1」true，1 号「出现」false，越界序号 false；
##   逃跑（活着，0 号带中毒 4，4 号战斗结束解除也仍在）：0、1 号「出现」true，0 号「状态 4」true、「状态 1」false；
##   战斗中隐藏的成员结束后出现（onBattleEnd → appear）：「出现」true。
## 读档后 $gameTroop 是新的空敌群（DataManager.createGameObjects），这里用 to_dict／from_dict 对应。
var passed := 0
var total := 0

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func ask(interp: MVInterpreter) -> Dictionary:
	return {"appear0": interp._condition([5, 0, 0]), "dead0": interp._condition([5, 0, 1, 1]), "appear1": interp._condition([5, 1, 0]),
		"state0_4": interp._condition([5, 0, 1, 4]), "dead5": interp._condition([5, 5, 1, 1])}

func battle(s: XState) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	return l

func _run() -> void:
	var s := XState.new_game(3, 1, [8, 10, 9])
	XState.current = s
	var interp := MVInterpreter.new(null, 4, 0, [])
	var fresh := ask(interp)
	check("fresh_all_false", fresh.values().all(func(v): return not v), fresh)
	check("fresh_no_skip", interp.skipped.is_empty(), interp.skipped)
	# 打赢：全部死亡
	var l := battle(s)
	check("troop2_three_members", l.enemies.size() == 3, l.enemies.size())
	for e in l.enemies:
		e.add_state(1)
	l.end_battle(-1)
	var won := ask(interp)
	check("won", won == {"appear0": false, "dead0": true, "appear1": false, "state0_4": false, "dead5": false}, won)
	# 逃跑：活着，0 号中毒（removeAtBattleEnd 也留在敌人身上）
	check("state4_remove_at_end", bool(XDB.rec("States", 4).get("removeAtBattleEnd", false)), XDB.rec("States", 4).get("name"))
	l = battle(s)
	l.enemies[0].add_state(4)
	l.end_battle(-1)
	var escaped := ask(interp)
	check("escaped", escaped == {"appear0": true, "dead0": false, "appear1": true, "state0_4": true, "dead5": false}, escaped)
	# 隐藏成员：结束后出现
	l = battle(s)
	l.enemies[1].hidden = true
	l.end_battle(-1)
	check("hidden_appears_after_end", interp._condition([5, 1, 0]), s.last_troop)
	check("battle_object_untouched", l.enemies[1].hidden, null)
	# 读档：不存档，敌群为空
	var loaded := XState.from_dict(s.to_dict())
	check("loaded_empty", loaded.last_troop.is_empty(), loaded.last_troop.size())
	XState.current = loaded
	var after_load := ask(interp)
	check("loaded_all_false", after_load.values().all(func(v): return not v), after_load)
	check("no_skip", interp.skipped.is_empty(), interp.skipped)
	# 212／213 不勾等待不先出文字，勾了才出（command212／213 setWaitMode）；225 照旧
	check("212_nowait", not MVEventCore._waits({"code": 212, "parameters": [-1, 741, false]}), null)
	check("212_wait", MVEventCore._waits({"code": 212, "parameters": [-1, 741, true]}), null)
	check("213_nowait", not MVEventCore._waits({"code": 213, "parameters": [-1, 1, false]}), null)
	check("213_wait", MVEventCore._waits({"code": 213, "parameters": [-1, 1, true]}), null)
	check("101_waits", MVEventCore._waits({"code": 101, "parameters": ["", 0, 0, 2]}), null)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
