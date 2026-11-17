extends Node
## 【cc·T157·未经审查】敌群事件里的强制行动快放（XBattleScene.FORCED_FAST，O-568）。
## 玩家反馈开战卡：776「【传承者】炎龙守护者」第 2 页开场连放三招（339 霸者领域／回归／放逐），技能动画关着时原版也要逐帧演约 3 秒
## （ui_reference 同夹具量：OFF 档 startAction→第三次 endAction 187 帧、三倍档 163 帧），画面上只有招式名和数字。
## 夹具同 ui_reference：出战 1/8/9/10、99 级、学夹具技能，规则流恒 0.5（同原版 Math.random=0.5），敌群 776。
## - 技能动画关：快放后三招总帧数不到逐帧的一半；回退 FORCED_FAST = false 回到逐帧，且两种走法结算结果（敌我 HP／MP／TP／状态）相同；
## - 技能动画开：不快放（同逐帧）；
## - 不是敌群事件里的行动（_troop_event_play 为假）不快放。
class P extends XBattleScene:
	var log := []
	var t0 := 0
	var done := false
	var sig := []
	func _command(u: XBattler):
		if u is XActor and not done:
			log.append([Engine.get_physics_frames() - t0, "input"])
			for b in logic.actors + logic.enemies:
				sig.append([b.hp, b.mp, b.tp, b.state_ids.duplicate()])
			done = true
		await get_tree().create_timer(100).timeout
		return [null, null]
	func _play(logs: Array) -> void:
		var acts := logs.filter(func(l): return l.type == "action")
		if acts.is_empty():
			await super._play(logs)
			return
		log.append([Engine.get_physics_frames() - t0, "start", acts.size()])
		await super._play(logs)
		log.append([Engine.get_physics_frames() - t0, "end"])

class HalfStream extends XRandomStream:
	func next_float(_reason: String, _event_key := "") -> float:
		return 0.5
	func next_uint(_reason: String, _event_key := "") -> int:
		return 2147483648
	func next_index_mod(n: int, _reason: String, _event_key := "") -> int:
		return floori(n * 0.5) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, _reason: String, _event_key := "") -> int:
		return lo + floori((hi - lo + 1) * 0.5)

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


## 开一场 776，跑到第一个角色指令窗；返回 {span: 敌群事件强制行动的帧数, acts, sig}
func _battle(speed: int, anim: bool) -> Dictionary:
	XConfig.set_battle_speed(speed)
	XConfig.set_flag("CombatSkillAnimation", anim)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.random_master = XRandomStream.hex64(20261117)
	for a in s.members():
		for id in [6168, 5980, 5548] + ([2571, 2786] if a.actor_id in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(id)
		a.change_level_mv(99)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	var scene := P.new()
	scene.t0 = Engine.get_physics_frames()
	scene.setup(776, true, false, {})
	var half := HalfStream.new()
	half.domain = "rule"
	scene.logic.random.rule = half
	add_child(scene)
	while not scene.done and Engine.get_physics_frames() - scene.t0 < 3000:
		await get_tree().physics_frame
	var out := {"span": -1, "acts": 0, "sig": scene.sig, "log": scene.log}
	for k in scene.log.size():
		var r: Array = scene.log[k]
		if r[1] == "start" and k + 1 < scene.log.size() and scene.log[k + 1][1] == "end":
			out.span = int(scene.log[k + 1][0]) - int(r[0])
			out.acts = int(r[2])
			break
	scene.queue_free()
	await get_tree().physics_frame
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_forced_fast"
	XConfig.path_override = XSave.dir().path_join("options.json")
	for speed in [4, 2]:
		XBattleScene.FORCED_FAST = false
		var slow: Dictionary = await _battle(speed, false)
		XBattleScene.FORCED_FAST = true
		var fast: Dictionary = await _battle(speed, false)
		print("FORCED_FAST speed=%d slow=%d fast=%d" % [speed, slow.span, fast.span])
		check("three_forced_%d" % speed, slow.acts == 3 and fast.acts == 3, [slow.log, fast.log])
		check("slow_like_original_%d" % speed, slow.span >= 140, slow.span)
		check("fast_under_half_%d" % speed, fast.span > 0 and fast.span * 2 < slow.span, [slow.span, fast.span])
		check("same_result_%d" % speed, not slow.sig.is_empty() and slow.sig == fast.sig, [slow.sig, fast.sig])
	XBattleScene.FORCED_FAST = false
	var anim_slow: Dictionary = await _battle(4, true)
	XBattleScene.FORCED_FAST = true
	var anim_fast: Dictionary = await _battle(4, true)
	check("anim_on_not_fast", anim_slow.span > 0 and anim_slow.span == anim_fast.span, [anim_slow.span, anim_fast.span])
	# 不在敌群事件里：不快放
	var bare := XBattleScene.new()
	XConfig.set_flag("CombatSkillAnimation", false)
	check("normal_action_not_fast", bare._seq_turbo() == 1)
	bare._troop_event_play = true
	check("troop_event_fast", bare._seq_turbo() == XBattleScene.FORCED_FAST_STEPS)
	XBattleScene.FORCED_FAST = false
	check("rollback_off", bare._seq_turbo() == 1)
	XBattleScene.FORCED_FAST = true
	bare.free()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
