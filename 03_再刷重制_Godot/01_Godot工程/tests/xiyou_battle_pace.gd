extends Node
## 战斗节奏对照（Kyo 11-06 实机：原版动作稍快）：正式版读数 tests/fixtures/battle_pace_oracle.json
## （ui_reference 战斗夹具 4 人、敌群 2，角色都普通攻击敌人 1，记每次 startAction／endAction 的 Scene_Battle.update 帧）。
## 这里跑同一场战斗的主循环（OTB），角色指令直接给普通攻击，记每次行动演出开始、结束的物理帧，比每次行动的时长与行动之间的空档。
class PaceBattle extends XBattleScene:
	var log := []
	var t0 := 0
	func _command(u: XBattler):
		if u is XActor:
			return [XDB.rec("Skills", 1), logic.enemies[1]]
		return await super._command(u)
	func _play(logs: Array) -> void:
		var acts := logs.filter(func(l): return l.type == "action")
		if acts.is_empty():
			await super._play(logs)
			return
		var u: XBattler = acts[0].user
		var key := "a%d" % (u as XActor).actor_id if u is XActor else "e%d" % logic.enemies.find(u)
		log.append([Engine.get_physics_frames() - t0, "start", key])
		await super._play(logs)
		log.append([Engine.get_physics_frames() - t0, "end", key])

const ORACLE := "res://tests/fixtures/battle_pace_oracle.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_pace"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	seed(20261018)
	XConfig.set_battle_speed(int(oracle.speed))
	XConfig.set_flag("CombatSkillAnimation", bool(oracle.anim))
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = XRandomStream.hex64(20261018)
	var scene := PaceBattle.new()
	scene.t0 = Engine.get_physics_frames()
	scene.setup(2, true, false, {})
	add_child(scene)
	for e in scene.logic.enemies:
		var p: Array = (e as XEnemy).data().params.duplicate()
		p[0] = float(p[0]) + 1000000.0
		(e as XEnemy).zq_ref = {"p": p, "k": 1}
		e.hp = e.mhp
	var want: Array = oracle.log.filter(func(r): return r[1] != "firstInput")
	while scene.log.size() < want.size() and Engine.get_physics_frames() - scene.t0 < 4000:
		await get_tree().physics_frame
	print("PACE_GODOT=", JSON.stringify(scene.log))
	print("PACE_MV=", JSON.stringify(want))
	var bad := []
	for i in range(1, mini(want.size(), scene.log.size())):
		var w = [int(want[i][0]) - int(want[i - 1][0]), want[i][1], want[i][2]]
		var g = [int(scene.log[i][0]) - int(scene.log[i - 1][0]), scene.log[i][1], scene.log[i][2]]
		if w != g:
			bad.append([i, g, w])
	check("pace_steps", bad.is_empty(), bad.slice(0, 8))
	scene.queue_free()
	await get_tree().create_timer(0.5, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
