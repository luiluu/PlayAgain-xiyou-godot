extends Node
## 多段技能伤害弹数逐帧对照（Kyo 11-06 实机：多段伤害数字叠在一起）：正式版读数 tests/fixtures/popup_multi_oracle.json
## （ui_reference __seqRef.suite(列表, 'popup_multi_oracle')，战斗夹具 4 人、敌群 2，伤害数字开）。
## 同一角色出同一招，逐帧比每个战斗者身上存活的弹数 [_duration, x, y]（按创建先后），即各段数字出现的帧和已经飘到的位置。
## 只看画面，不写存档。
class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

const ORACLE := "res://tests/fixtures/popup_multi_oracle.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_popup_multi"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	for anim in XDB.table("Animations"):
		if anim is Dictionary:
			for tm in anim.get("timings", []):
				tm.erase("se")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	seed(20261018)
	XConfig.set_flag("CombatDamageShow", true)
	XConfig.set_flag("CombatSkillAnimation", false)
	XConfig.set_flag("battleCamera", true)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = XRandomStream.hex64(20261018)
	var scene := QuietBattle.new()
	scene.setup(2, true, false, {})
	add_child(scene)
	await get_tree().physics_frame
	for e in scene.logic.enemies:
		var p: Array = (e as XEnemy).data().params.duplicate()
		p[0] = float(p[0]) + 1000000.0
		(e as XEnemy).zq_ref = {"p": p, "k": 1}
		e.hp = e.mhp
	for key in oracle.traces:
		await _trace(scene, key, oracle.traces[key])
	scene.queue_free()
	for sp in XSound._players:
		if is_instance_valid(sp):
			sp.stop()
	await get_tree().create_timer(0.5, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _key(b: XBattler, scene: XBattleScene) -> String:
	return "a%d" % (b as XActor).actor_id if b is XActor else "e%d" % scene.logic.enemies.find(b)


## 本招新建的弹数（正式版首帧里还有上一招的残留；残留的 _duration 在本招开始前就已小于满值）
static func _own(rows: Array) -> Array:
	var born := {}
	var out := []
	for f in range(rows.size()):
		var keep := []
		for p in rows[f]:
			if int(p[0]) >= 88 or born.has([f - 1, int(p[0]) + 2, snappedf(float(p[1]), 0.1)]):
				keep.append([int(p[0]), snappedf(float(p[1]), 0.1), snappedf(float(p[2]), 0.1)])
		for p in keep:
			born[[f, p[0], p[1]]] = true
		out.append(keep)
	return out


func _trace(scene: XBattleScene, key: String, t: Dictionary) -> void:
	XConfig.set_battle_speed(int(t.speed))
	var logic := scene.logic
	var user: XActor = logic.actors.filter(func(a): return a.actor_id == int(t.actor))[0]
	for b in logic.actors + logic.enemies:
		b.recover_all()
	for sp in scene.sprites.values():
		sp.set_motion("walk")
		sp.position = sp.home
	for b in scene._popups.keys():
		for p in scene._popups[b]:
			if is_instance_valid(p):
				p.queue_free()
	scene._popups.clear()
	await get_tree().physics_frame
	scene.camera = XBattleCamera.new()
	scene.camera.sprites = scene.sprites
	var logs := logic.execute(user, XDB.rec("Skills", int(t.skill)), logic.enemies[1], true)
	var got := {}
	for k in t.pops:
		got[k] = []
	var hook := func(_p: XSequencePlayer):
		for b in scene.sprites:
			var k := _key(b, scene)
			if got.has(k):
				var row := []
				for p in scene._popups.get(b, []):
					if is_instance_valid(p) and not p.is_queued_for_deletion():
						row.append([p._duration, p._x, p._y])
				got[k].append(row)
	var i := logs.find(logs.filter(func(l): return l.type == "seq_phase")[0])
	var j := logs.find(logs.filter(func(l): return l.type == "seq_end")[0])
	var player := XSequencePlayer.create(scene, logs[i - 1], logs.slice(i, j + 1))
	player.on_frame = hook
	scene.show_views(logs[i - 1].views)
	await player.play()
	scene.clear_views()
	var effects: Array = player.cmds.filter(func(c): return c[1] == "ACTION EFFECT").map(func(c): return int(c[0]))
	check("%s_effect_frames" % key, effects == t.cmds.map(func(c): return int(c[0])), [effects, t.cmds])
	var bad := []
	for k in t.pops:
		var w := _own(t.pops[k])
		var g := _own(got[k])
		for f in range(mini(w.size(), g.size())):
			if w[f] != g[f]:
				bad.append([k, f, g[f], w[f]])
	check("%s_popups" % key, bad.is_empty(), bad.slice(0, 4))
