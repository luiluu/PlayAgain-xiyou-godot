extends Node
## YEP_X_VisualStateFX 状态循环动画守卫（bailong-visual1）。参照 oracle/vsfx.json（mv_oracle/vsfx_probe.cjs 量冻结正式源）：
## 全游戏只有状态 1297「刻印环身盾」带 <State Animation: 900>（动画 900「光环(中间呼吸)」60 帧，无闪光无音效）。
## 规则：号取 states() 顺序第一个；号变才换；播完同一帧接着播；去状态立刻清；不透明度跟战斗者；角色敌人都放。
class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_vsfx"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	var ref = XDB.load_json("oracle/vsfx.json")
	check("oracle_present", ref is Dictionary and ref.has("cases"))
	if not (ref is Dictionary and ref.has("cases")):
		return _finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	var census: Dictionary = cases.census.observed
	# 全库：只有状态 1297 带动画 900，动画能播（MV 格式、60 帧、无节点）
	var ours := []
	for s in XDB.table("States"):
		if s is Dictionary and (s.get("meta", {}).has("State Animation") or s.get("meta", {}).has("State Ani")):
			ours.append(int(s.id))
	check("census.states", ours == [1297] and census.states.size() == 1 and int(census.states[0].ani) == 900, [ours, census.states])
	var anim := XDB.rec("Animations", 900)
	check("census.anim900", MVAnimation.usable(anim) and anim.frames.size() == 60 and anim.timings.is_empty() and int(anim.get("position", 1)) == 1, anim.get("frames", []).size())
	check("census.params", census.params.actorAni == true and census.params.enemyAni == true and census.params.screen == false and census.params.sound == false, census.params)
	# 号的规则
	var e := XEnemy.new().setup(1, 1)
	check("id.none", XVisualStateFx.animation_id(e) == 0)
	e.state_ids.append(1297)
	check("id.1297", XVisualStateFx.animation_id(e) == 900, XVisualStateFx.animation_id(e))
	var st := XDB.rec("States", 2)
	var old_meta = st.get("meta", {}).duplicate()
	st["meta"] = old_meta.duplicate()
	st.meta["State Animation"] = " 7"
	e.state_ids.assign([2, 1297])
	check("id.first_wins", XVisualStateFx.animation_id(e) == 7, XVisualStateFx.animation_id(e))
	e.state_ids.assign([1297, 2])
	check("id.first_wins_rev", XVisualStateFx.animation_id(e) == 900, XVisualStateFx.animation_id(e))
	st["meta"] = old_meta
	# 战斗画面
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = XRandomStream.hex64(20261104)
	var scene := QuietBattle.new()
	scene.setup(2, true, false, {})
	add_child(scene)
	await get_tree().physics_frame
	var a: XActor = scene.logic.actors[0]
	var en: XEnemy = scene.logic.enemies[0]
	for _i in 3:
		await get_tree().physics_frame
	check("scene.none_before", not scene._state_anims.has(a) or scene._state_anims[a].node == null)
	a.add_state(1297)
	en.state_ids.append(1297)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for who in [a, en]:
		var tag := "actor" if who == a else "enemy"
		var cur: Dictionary = scene._state_anims.get(who, {})
		var node = cur.get("node")
		check("scene.%s.playing" % tag, node != null and is_instance_valid(node) and int(node.anim.id) == 900 and int(cur.id) == 900, cur)
		if node == null or not is_instance_valid(node):
			continue
		# 位置＝目标中心（position 1：帧高一半）
		var sp: XBattlerSprite = scene.sprites[who]
		var want_y: float = sp.position.y - sp.height() / sp.body_scale / 2.0 - sp.anim_lift()
		check("scene.%s.center" % tag, absf(node.position.y - want_y) < 1.5 and absf(node.position.x - sp.position.x) < 1.5, [node.position, sp.position, want_y])
		# 循环：跑过一整轮（60 帧 × rate + 1）后仍在播，且回到过起点（duration 重置）
		var full: int = node.anim.frames.size() * node.rate + 1
		var resets := 0
		var last: int = node.duration
		for _i in full * 2 + 10:
			await get_tree().physics_frame
			if not is_instance_valid(node) or scene._state_anims[who].node != node:
				break
			if node.duration > last:
				resets += 1
			last = node.duration
		check("scene.%s.loops" % tag, is_instance_valid(node) and scene._state_anims[who].node == node and resets >= 1 and node.playing(), [resets, full])
		# 不透明度跟战斗者
		sp.seq_opacity = 102.0
		await get_tree().physics_frame
		check("scene.%s.opacity" % tag, absf(node.modulate.a - 0.4) < 0.01, node.modulate.a)
		sp.seq_opacity = 255.0
	# 去状态：立刻清掉
	a.state_ids.erase(1297)
	en.state_ids.erase(1297)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for who in [a, en]:
		var cur: Dictionary = scene._state_anims.get(who, {})
		check("scene.%s.cleared" % ("actor" if who == a else "enemy"), int(cur.get("id", -1)) == 0 and cur.get("node") == null, cur)
	_finish()


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
