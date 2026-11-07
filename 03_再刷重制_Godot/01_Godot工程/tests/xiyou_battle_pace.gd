extends Node
## 战斗节奏对照（Kyo 11-06 实机：原版动作稍快）：正式版读数 tests/fixtures/battle_pace_oracle.json
## （ui_reference battle_pace_ref.cjs：战斗夹具 4 人、敌群 2，角色都普通攻击敌人 1，记每次 startAction／endAction 的帧与 OTB 速度）。
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

## 原版夹具（mac-preload-shim battle_ref）把 Math.random 固定成 0.5（「稳定 OTB 同速顺序」）：重制的规则流同样每次给 0.5，
## 按 MV 的 floor(n×0.5) 映射（randomInt／取序号），同速、随机速度、伤害浮动都跟原版取同一个值
class HalfStream extends XRandomStream:
	var reasons := {}
	func _note(reason: String) -> void:
		draws += 1
		reasons[reason] = int(reasons.get(reason, 0)) + 1
	func next_float(reason: String, _event_key := "") -> float:
		_note(reason)
		return 0.5
	func next_uint(reason: String, _event_key := "") -> int:
		_note(reason)
		return 2147483648
	func next_index_mod(n: int, reason: String, _event_key := "") -> int:
		_note(reason)
		return floori(n * 0.5) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, _event_key := "") -> int:
		_note(reason)
		return lo + floori((hi - lo + 1) * 0.5)

const ORACLE := "res://tests/fixtures/battle_pace_oracle.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


## 照原版夹具开一场（学夹具技能、规则流恒 0.5、敌人加 100 万血），跑到记下 n 条起止
func _battle(n: int) -> PaceBattle:
	var s := XState.new_game(3, 1, [8, 9, 10])
	# 同原版夹具（mac-preload-shim fixture）：每人学天道诅咒 6168（敏捷 ×80%）、难度适应 5980、普通难度 5548，1 号另学 2571、2786
	for a in s.members():
		for id in [6168, 5980, 5548] + ([2571, 2786] if a.actor_id in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(id)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261018)
	var scene := PaceBattle.new()
	scene.t0 = Engine.get_physics_frames()
	scene.setup(2, true, false, {})
	var half := HalfStream.new()
	half.domain = "rule"
	scene.logic.random.rule = half
	add_child(scene)
	for e in scene.logic.enemies:
		var p: Array = (e as XEnemy).data().params.duplicate()
		p[0] = float(p[0]) + 1000000.0
		(e as XEnemy).zq_ref = {"p": p, "k": 1}
		e.param_mark_dirty()  # krz 能力值缓存：不标脏 mhp 还是旧值，敌人只有原来的血，第 2 回合 e1 被打倒（rules-pace1 查出）
		e.param_refresh()
		e.hp = e.mhp
	while scene.log.size() < n and Engine.get_physics_frames() - scene.t0 < 4000:
		await get_tree().physics_frame
	return scene


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_pace"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	seed(20261018)
	XConfig.set_battle_speed(int(oracle.speed))
	XConfig.set_flag("CombatSkillAnimation", bool(oracle.anim))
	var want: Array = oracle.log.filter(func(r): return r[1] != "firstInput")
	var scene: PaceBattle = await _battle(want.size())
	print("PACE_GODOT=", JSON.stringify(scene.log))
	# 行动先后（rules-pace1）：原版敏捷 a1 0、a8／a9 16、a10 24、敌人 20，速度 agi＋randomInt(5＋agi/4)＝2／20／29／25，
	# 三回合都是 a10、e0、e1、e2、a8、a9、a1；重制同一夹具逐次比行动者
	var key := func(b: XBattler) -> String:
		return ("a%d" % (b as XActor).actor_id) if b is XActor else ("e%d" % scene.logic.enemies.find(b))
	var speeds := []
	for b in scene.logic.actors + scene.logic.enemies:
		speeds.append([key.call(b), int(b.agi), int(scene.logic._speed.get(b, -1))])
	var want_speeds: Array = oracle.orders[0].speeds.map(func(r): return [str(r[0]), int(r[1]), int(r[2])])
	check("otb_speeds", speeds == want_speeds, [speeds, want_speeds])
	var order_g: Array = scene.log.filter(func(r): return r[1] == "start").map(func(r): return r[2])
	var order_w: Array = want.filter(func(r): return r[1] == "start").map(func(r): return r[2])
	check("action_order", order_g.slice(0, order_w.size()) == order_w, [order_g, order_w])
	print("PACE_MV=", JSON.stringify(want))
	# 每次行动演出的时长（startAction→endAction，角色普攻／敌人各自排序后逐个比，容差 1 帧：两边起止钩子的位置差一帧）；
	# 行动之间的空档照打印（PACE_DIFF），不断言
	var dur := func(log: Array, actor: bool) -> Array:
		var open := {}
		var out := []
		for r in log:
			if str(r[2]).begins_with("a") != actor:
				continue
			if r[1] == "start":
				open[r[2]] = int(r[0])
			elif r[1] == "end" and open.has(r[2]):
				out.append(int(r[0]) - int(open[r[2]]))
				open.erase(r[2])
		out.sort()
		return out
	for actor in [true, false]:
		# 原 battlefix2 夹具第 3 回合 a9 那次 111 帧是录制卡顿：重录三次都是 54（battle_pace_ref.cjs），夹具已换
		var w: Array = dur.call(want, actor)
		var g: Array = dur.call(scene.log, actor)
		var ok := w.size() > 0 and g.size() >= w.size()
		for i in range(mini(w.size(), g.size())):
			ok = ok and absi(int(w[i]) - int(g[i])) <= 1
		check("action_frames_%s" % ("actor" if actor else "enemy"), ok, [g, w])
	# 行动之间、回合交界的空帧（ui-pace2，XBattleScene.PACE_GAPS）：逐次比「行动序列第一条」之间的帧数。原版 startAction 之后
	# 角色隔 1 帧、敌人隔 2 帧才出第一条（battle_pace_ref 逐帧：DISPLAY ACTION），重制 act 当帧就出，所以原版起点各加这个偏移再比。
	# 改之前（不留空帧）敌人之间 55 对 56，回合交界也短
	var seq_starts := func(log: Array, mv: bool) -> Array:
		return log.filter(func(r): return r[1] == "start").map(func(r): return int(r[0]) + ((1 if str(r[2]).begins_with("a") else 2) if mv else 0))
	var cyc := func(v: Array) -> Array:
		var out := []
		for i in range(1, v.size()):
			out.append(int(v[i]) - int(v[i - 1]))
		return out
	var cw: Array = cyc.call(seq_starts.call(want, true))
	var cg: Array = cyc.call(seq_starts.call(scene.log, false)).slice(0, cw.size())
	check("pace_cycles", cg == cw, [cg, cw])
	var gaps := []
	for i in range(1, mini(want.size(), scene.log.size())):
		var w = [int(want[i][0]) - int(want[i - 1][0]), want[i][1], want[i][2]]
		var g = [int(scene.log[i][0]) - int(scene.log[i - 1][0]), scene.log[i][1], scene.log[i][2]]
		if w != g:
			gaps.append([i, g, w])
	print("PACE_DIFF=", JSON.stringify(gaps))
	scene.queue_free()
	await get_tree().physics_frame
	# 回退：PACE_GAPS = false 回到不留空帧，敌人之间 55
	XBattleScene.PACE_GAPS = false
	var raw: PaceBattle = await _battle(6)
	var rs: Array = cyc.call(seq_starts.call(raw.log, false))
	check("pace_gaps_off", rs.size() >= 2 and int(rs[1]) == 55, rs)
	XBattleScene.PACE_GAPS = true
	raw.queue_free()
	await get_tree().create_timer(0.5, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
