extends Node
## O-待定（battle_logic.gd XBattleLogic.START_CLEAR_RESULT）：不走动连着开战，上一场结束时去掉的开战状态这一场照样挂上。
## 原版 onBattleEnd 先 clearResult 再 removeBattleStates，移除记录留到地图上走一步才清，isStateAddable 拒绝「本次移除过」的状态，
## 隔一场漏挂一次（v0.01.07 玩家贝吉特木桩：神魔压制×10% 隔场漏挂，伤害 762 对 7.61 万）。
## 这里用狼魂 1420（<StartPushState0157: 100%>，状态 157 战斗结束移除）：默认每场都挂上；回退 false 时第二场挂不上、走一步后又挂上。
const SKILL := 1420
const STATE := 157
const TROOP := 70
var checks := 0
var failed := []


func check(label: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failed.append(label)
		print("FAIL ", label, " ", detail)


func _ready() -> void:
	_run.call_deferred()


func _battle(s: XState) -> bool:
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var a: XBattler = null
	for b in logic.actors:
		if b is XActor and b.actor_id == s.members()[0].actor_id:
			a = b
	var on := a != null and a.is_state_affected(STATE)
	logic.end_battle(2)
	return on


func _fresh() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.members()[0].learn_skill(SKILL)
	return s


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_start_clear_result"
	XConfig.path_override = XSave.dir().path_join("options.json")
	check("data.tag", _fresh().members()[0].battle_start_state_tags().any(func(t): return int(t[1]) == STATE and float(t[2]) >= 100.0))
	# 默认（修好）：连着打三场，每场都挂上
	XBattleLogic.START_CLEAR_RESULT = true
	var s := _fresh()
	var got := []
	for i in 3:
		got.append(_battle(s))
	check("fixed.every_battle", got == [true, true, true], got)
	check("fixed.removed_after_battle", not s.members()[0].is_state_affected(STATE))
	# 回退：原版第二场挂不上，走一步（onPlayerWalk 清 _result）后再挂上
	XBattleLogic.START_CLEAR_RESULT = false
	s = _fresh()
	var first := _battle(s)
	var second := _battle(s)
	XMapScene.on_player_walk(s)
	var after_walk := _battle(s)
	check("rollback.original_alternates", first and not second and after_walk, [first, second, after_walk])
	XBattleLogic.START_CLEAR_RESULT = true
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failed.size(), "total": checks}))
	get_tree().quit(0 if failed.is_empty() else 1)
