extends Node
## 同种子同命令：规则直接执行／真实演出、掉落图标开关、快速战斗、time_scale 30 的逐击与最终奖励一致。
class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

var results := []

func _ready() -> void:
	_run.call_deferred()

func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _run() -> void:
	XSave.dir_override = "user://test_xiyou_determinism"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	Engine.physics_ticks_per_second = 600
	# 保证倒下时至少有一个图标，同时保留另一条随机掉落；只改本测试进程的数据库缓存。
	XDB.rec("Enemies", 1).dropItems = [{"kind": 1, "dataId": 1, "denominator": 1}, {"kind": 1, "dataId": 2, "denominator": 10}]
	for anim in XDB.table("Animations"):
		if anim is Dictionary:
			for tm in anim.get("timings", []):
				tm.erase("se")
	for trial_seed in [20261017, 19]:
		var base := await _replay(trial_seed, false, false, false, 1.0)
		for row in [[true, false, false, 1.0], [true, true, false, 1.0], [true, true, true, 1.0], [true, true, true, 30.0]]:
			var got := await _replay(trial_seed, row[0], row[1], row[2], row[3])
			check("seed%d_drop%s_fast%s_scale%s" % [trial_seed, row[1], row[2], row[3]], got == base, [base, got])
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	for sp in XSound._players:
		if is_instance_valid(sp):
			sp.stop()
			sp.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)

func _replay(trial_seed: int, visual: bool, drops: bool, fast: bool, scale: float) -> Dictionary:
	Engine.time_scale = scale
	seed(trial_seed)
	XConfig.set_flag("CombatSkillAnimation", visual)
	XConfig.set_flag("MOG_TrPopUpBattle_Key", drops)
	XConfig.set_battle_speed(1 if fast else 4)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.hang_up_active = fast
	s.hang_up_origin = Vector2i.ZERO
	XHangUp.settings(s).fastFt = fast
	var scene: QuietBattle
	var logic: XBattleLogic
	if visual:
		scene = QuietBattle.new()
		scene.setup(2, true, false, {})
		add_child(scene)
		logic = scene.logic
	else:
		logic = XBattleLogic.new()
		logic.setup(2, s)
	var skill := XDB.rec("Skills", 1).duplicate(true)
	skill.erase("yepSeq")
	skill.hitType = 0
	skill.damage.formulaGd = "100.0"
	skill.damage.variance = 20
	skill.effects = []
	skill.animationId = 1
	var hits := []
	for enemy in logic.enemies:
		enemy.hp = 1.0
		var logs := logic.act(s.actor(1), skill, enemy)
		for l in logs:
			if l.type == "hit":
				hits.append([l.hp, l.mp, l.critical, l.missed, l.evaded, l.added, l.removed])
		if visual:
			await scene._play(logs)
		else:
			logic.drops_of(enemy)
	var rewards := logic.rewards()
	logic.grant(rewards)
	logic.end_battle()
	var out := {"hits": hits, "rewards": rewards, "items": s.items.duplicate(true), "gold": s.gold,
		"actors": s.members().map(func(a): return [a.hp, a.mp, a.tp, a.exp_total, a.state_ids.duplicate(), a.zhenqi.duplicate(true)]), "nextRoll": randi()}
	if visual:
		scene.free()
	return out
