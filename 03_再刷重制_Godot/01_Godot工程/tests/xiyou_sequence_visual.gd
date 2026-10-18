extends Node
## YEP 行动序列画面逐帧对照（标准级）：正式版读数 tests/fixtures/action_sequence_oracle.json（ui_reference __seqRef.suite()，
## 战斗夹具 4 人、敌群 2）。同一角色出同一招，比对每条指令开始执行的帧、镜头层位置与缩放、窗口层隐藏、日志行数，
## 以及战斗者的不透明度、浮空/跳跃高度、动作。敌人生命加大到打不死（同参照夹具）。另验 Battle Camera 关时镜头不动。
## 只看画面，不写存档。
class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

const ORACLE := "res://tests/fixtures/action_sequence_oracle.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_sequence_visual"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	for anim in XDB.table("Animations"):
		if anim is Dictionary:
			for tm in anim.get("timings", []):
				tm.erase("se")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	seed(20261018)
	XConfig.set_battle_speed(4)
	var s := XState.new_game(3, 1, [8, 9, 10])
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
		await _trace(scene, s, key, oracle.traces[key])
	XConfig.set_flag("battleCamera", true)
	XConfig.set_flag("CombatSkillAnimation", false)
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


func _trace(scene: XBattleScene, s: XState, key: String, t: Dictionary) -> void:
	XConfig.set_flag("battleCamera", bool(t.camera))
	XConfig.set_flag("CombatSkillAnimation", bool(t.animation))
	var logic := scene.logic
	var user: XActor = logic.actors.filter(func(a): return a.actor_id == int(t.actor))[0]
	for b in logic.actors + logic.enemies:
		b.recover_all()
	for sp in scene.sprites.values():
		sp.set_motion("walk")
		sp.position = sp.home
	scene.camera = XBattleCamera.new()
	scene.camera.sprites = scene.sprites
	var skill := XDB.rec("Skills", int(t.skill))
	var logs := logic.execute(user, skill, logic.enemies[1], true)
	var got := {"cmds": [], "frames": [], "sprites": {}}
	for k in t.sprites:
		got.sprites[k] = []
	var hook := func(p: XSequencePlayer):
		var c := scene.camera
		var hud := 0 if scene.ui.visible else 1
		got.frames.append([c.screen_offset().x, c.screen_offset().y, snappedf(c.scale, 0.001), snappedf(c.x, 0.001), snappedf(c.y, 0.001), hud, p.lines])
		for b in scene.sprites:
			var k := _key(b, scene)
			if got.sprites.has(k):
				var sp: XBattlerSprite = scene.sprites[b]
				got.sprites[k].append([snappedf(sp.seq_opacity, 0.001), snappedf(sp.float_height, 0.001), snappedf(sp.jump_height(), 0.001), sp.motion])
	# 行动记录 → 演出（同 XBattleScene._play 的序列分支）
	var i := logs.find(logs.filter(func(l): return l.type == "seq_phase")[0])
	var j := logs.find(logs.filter(func(l): return l.type == "seq_end")[0])
	var player := XSequencePlayer.create(scene, logs[i - 1], logs.slice(i, j + 1))
	player.on_frame = hook
	await player.play()
	got.cmds = player.cmds
	# 指令时间线
	var want_cmds: Array = t.cmds.map(func(c): return [int(c[0]), str(c[1]).to_upper()])
	check("%s_cmds" % key, got.cmds == want_cmds, {"godot": got.cmds, "mv": want_cmds})
	check("%s_length" % key, got.frames.size() == t.frames.size(), [got.frames.size(), t.frames.size()])
	var n: int = mini(got.frames.size(), t.frames.size())
	var bad := []
	for f in range(n):
		var w: Array = t.frames[f]
		var g: Array = got.frames[f]
		# 镜头：只比用到镜头的招与关镜头的那一招（其余招开场时正式版还带着上一招镜头复位的尾巴）
		var camera_ok: bool = (key == "s65_nocam" and g[0] == float(w[0]) and g[1] == float(w[1]) and g[2] == float(w[2])) \
			or not (key.begins_with("s65") or key == "s104") or (key != "s65_nocam" and g[0] == float(w[0]) and g[1] == float(w[1]) and absf(g[2] - float(w[2])) < 0.002 \
			and absf(g[3] - float(w[3])) < 0.01 and absf(g[4] - float(w[4])) < 0.01)
		if not camera_ok or g[5] != int(w[5]) or g[6] != int(w[6]):
			bad.append([f, g, w])
		for k in t.sprites:
			var ws: Array = t.sprites[k][f]
			var gs: Array = got.sprites[k][f]
			# 动作：只比角色（敌人单图没有动作）；不透明度、浮空、跳跃逐帧
			if absf(gs[0] - float(ws[0])) > 0.01 or absf(gs[1] - float(ws[1])) > 0.002 or absf(gs[2] - float(ws[2])) > 0.002 \
					or (k.begins_with("a") and gs[3] != str(ws[3])):
				bad.append([f, k, gs, ws])
	check("%s_frames" % key, bad.is_empty(), bad.slice(0, 6))
