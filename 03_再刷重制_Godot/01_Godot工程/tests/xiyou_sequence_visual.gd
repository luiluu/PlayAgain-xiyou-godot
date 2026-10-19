extends Node
## YEP 行动序列画面逐帧对照（标准级）：正式版读数 tests/fixtures/action_sequence_oracle.json（ui_reference __seqRef.suite()，
## 战斗夹具 4 人、敌群 2）。同一角色出同一招，比对每条指令开始执行的帧、镜头层位置与缩放、窗口层隐藏、日志行数，
## 以及战斗者的不透明度、浮空/跳跃高度、动作。敌人生命加大到打不死（同参照夹具）。另验 Battle Camera 关时镜头不动。
## 只看画面，不写存档。
class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

const ORACLE := "res://tests/fixtures/action_sequence_oracle.json"
## 画面快照用的正式版读数（__seqRef.suite(列表, 'action_sequence_hp_oracle')）：s131 多段攻击敌人 HP 逐帧、s104 反击致死
const HP_ORACLE := "res://tests/fixtures/action_sequence_hp_oracle.json"
## 窗口模式加 -- --out=<目录>：在这些帧截图（镜头拉近、跳跃最高、透明度最低）
const SHOTS := {"s65": [49, 70, 100], "s104": [42]}
var results := []
var out_dir := ""
var _pending_shot := ""


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
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
	var hp_oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HP_ORACLE))
	await _counter_death(scene, hp_oracle.traces.s104_counter_death)
	await _multi_hit_gauge(scene, hp_oracle.traces.s131)
	await _attack_mirror()
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
		if out_dir != "" and DisplayServer.get_name() != "headless" and SHOTS.get(key, []).has(got.frames.size() - 1):
			_pending_shot = "%s_f%d" % [key, got.frames.size() - 1]
	# 行动记录 → 演出（同 XBattleScene._play 的序列分支）
	var i := logs.find(logs.filter(func(l): return l.type == "seq_phase")[0])
	var j := logs.find(logs.filter(func(l): return l.type == "seq_end")[0])
	var player := XSequencePlayer.create(scene, logs[i - 1], logs.slice(i, j + 1))
	player.on_frame = hook
	var shooter := func():
		while not player.done:
			if _pending_shot != "":
				var name := _pending_shot
				_pending_shot = ""
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
			await get_tree().process_frame
	if out_dir != "":
		shooter.call()
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


# ---- 画面快照（日志写入时记下的值，表现层只读日志） ----
## 测试专用反击状态（同 xiyou_combat）：一条 xparam 6 特性，追加到 States 表末尾
func _counter_state() -> int:
	var t: Array = XDB.table("States")
	var id := t.size()
	t.append({"id": id, "name": "测试反击", "traits": [{"code": 22, "dataId": 6, "value": 1.0}],
		"note": "", "meta": {}, "iconIndex": 0, "restriction": 0, "autoRemovalTiming": 0, "removeAtBattleEnd": true})
	return id


## 跑一招并逐帧记录：返回 {logs, cmds, jump（行动者跳跃高度）, hp（目标在画面上的 HP 读数）}
func _play_once(scene: XBattleScene, user: XActor, skill_id: int, target: XBattler) -> Dictionary:
	for sp in scene.sprites.values():
		sp.set_motion("walk")
		sp.position = sp.home
	scene.camera = XBattleCamera.new()
	scene.camera.sprites = scene.sprites
	var logs := scene.logic.execute(user, XDB.rec("Skills", skill_id), target, true)
	var i := logs.find(logs.filter(func(l): return l.type == "seq_phase")[0])
	var j := logs.find(logs.filter(func(l): return l.type == "seq_end")[0])
	var got := {"logs": logs, "jump": [], "hp": [], "disp": []}
	var player := XSequencePlayer.create(scene, logs[i - 1], logs.slice(i, j + 1))
	scene.show_views(logs[i - 1].views)
	player.on_frame = func(_p):
		got.jump.append(snappedf(scene.sprites[user].jump_height(), 0.001))
		got.hp.append(float(scene.view(target).hp))
		if scene.gauges.has(target):
			got.disp.append(float(scene.gauges[target].disp))
	await player.play()
	scene.clear_views()
	got.cmds = player.cmds
	return got


## 反击致死（正式版读数 action_sequence_hp_oracle.json 的 s104_counter_death：行动者 1 HP、全体敌人反击率 1）：
## MV 在指令执行时读 spriteCanMove，反击到 ACTION EFFECT 的 invokeAction 才发生，之前的跳跃照常；之后 DEATH BREAK 中断本段。
## 逐帧比指令时间与行动者跳跃高度；结算（倒下、反击记录）照旧。
func _counter_death(scene: XBattleScene, t: Dictionary) -> void:
	var logic := scene.logic
	var user: XActor = logic.actors.filter(func(a): return a.actor_id == int(t.actor))[0]
	var foe: XBattler = logic.enemies[1]
	for b in logic.actors + logic.enemies:
		b.recover_all()
	var cnt := _counter_state()
	foe.add_state(cnt)
	user.hp = 1.0
	var got := await _play_once(scene, user, int(t.skill), foe)
	foe.remove_state(cnt)
	var want_cmds: Array = t.cmds.map(func(c): return [int(c[0]), str(c[1]).to_upper()])
	check("counter_death_cmds", got.cmds == want_cmds, {"godot": got.cmds, "mv": want_cmds})
	var key := "a%d" % user.actor_id
	var want_jump: Array = t.sprites[key].map(func(r): return snappedf(float(r[2]), 0.001))
	var bad := []
	for f in range(mini(want_jump.size(), got.jump.size())):
		if absf(got.jump[f] - want_jump[f]) > 0.002:
			bad.append([f, got.jump[f], want_jump[f]])
	check("counter_death_jump", bad.is_empty() and got.jump.size() == want_jump.size() and want_jump.max() > 0.0,
		{"bad": bad.slice(0, 6), "size": [got.jump.size(), want_jump.size()]})
	check("counter_death_settled", user.is_dead() and got.logs.any(func(l): return l.type == "counter" and l.user == foe),
		[user.hp, got.logs.map(func(l): return l.type)])


## 多段攻击（正式版读数 s131：敌人 HP 逐帧）：每一下 ACTION EFFECT 当帧画面上的敌人 HP 换成该下结算后的值（日志 views），
## 不是最终值。正式版目标第 4 下倒下（夹具敌人没加大生命），Godot 目标打不死，比前 4 段换值的帧；数值另与日志逐段核对。
## 血条显示值（YEP_X_VisualHpGauge）：换值当帧开始滑落，每帧 ceil(差/Gauge Duration)，正式版同帧读数同此规则。
func _multi_hit_gauge(scene: XBattleScene, t: Dictionary) -> void:
	var logic := scene.logic
	var user: XActor = logic.actors.filter(func(a): return a.actor_id == int(t.actor))[0]
	var foe: XBattler = logic.enemies[1]
	for b in logic.actors + logic.enemies:
		b.recover_all()
	var start := foe.hp
	var got := await _play_once(scene, user, int(t.skill), foe)
	var hits: Array = got.logs.filter(func(l): return l.type == "hit" and l.target == foe and not (l.missed or l.evaded))
	var want := [start]
	var hp := start
	for h in hits:
		hp = clampf(hp - float(h.hp), 0.0, foe.mhp)
		want.append(hp)
	var seen := []
	var steps := []
	for f in range(got.hp.size()):
		if seen.is_empty() or seen.back() != got.hp[f]:
			if not seen.is_empty():
				steps.append(f)
			seen.append(got.hp[f])
	check("multi_hit_gauge_values", hits.size() >= 2 and seen == want and is_equal_approx(want.back(), foe.hp), {"seen": seen, "want": want})
	var mv: Array = t.hp["e1"]
	var mv_steps := []
	for f in range(1, mv.size()):
		if mv[f][0] != mv[f - 1][0]:
			mv_steps.append(f)
	check("multi_hit_gauge_frames", mv_steps.size() >= 2 and steps.slice(0, mv_steps.size()) == mv_steps, {"godot": steps, "mv": mv_steps})
	var last: int = mv_steps.back() if not mv_steps.is_empty() else 0
	var want_cmds: Array = t.cmds.map(func(c): return [int(c[0]), str(c[1]).to_upper()]).filter(func(c): return c[0] <= last)
	check("multi_hit_cmds_until_last_mv_hit", got.cmds.filter(func(c): return c[0] <= last) == want_cmds, {"godot": got.cmds, "mv": want_cmds})
	# 正式版：实际 HP 换值当帧显示值就开始滑落（_displayedValue 比上一帧少 ceil(差/30)）
	var mv_ok := mv_steps.all(func(f): return mv[f][1] == maxf(mv[f - 1][1] - ceilf(absf(mv[f - 1][1] - mv[f][0]) / 30.0), mv[f][0]))
	var g_ok := steps.size() >= 2 and steps.all(func(f): return got.disp[f] == maxf(got.disp[f - 1] - ceilf(absf(got.disp[f - 1] - got.hp[f]) / 30.0), got.hp[f]))
	check("multi_hit_gauge_drain", mv_ok and g_ok and got.disp.back() < start, {"mv": mv_ok, "godot": g_ok})
	check("multi_hit_gauge_live_after", is_equal_approx(float(scene.view(foe).hp), foe.hp))


## 冻结 YEP_X_ActSeqPack2.actionAttackAnimation：第二参数 MIRROR 必须传到动画。
## 用已开放敌群20／32的真实技能178／167生成日志，同时检查未传MIRROR的普通动画。
func _attack_mirror() -> void:
	XConfig.set_flag("CombatSkillAnimation", true)
	for row in [[20, 178], [32, 167]]:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState._become_current(s)
		var scene := QuietBattle.new()
		scene.setup(row[0], true, false, {})
		add_child(scene)
		await get_tree().physics_frame
		var user: XEnemy = scene.logic.enemies[0]
		var skill := XDB.rec("Skills", row[1])
		var logs := scene.logic.execute(user, skill, scene.logic.actors[0], true)
		var commands := logs.filter(func(e): return e.type == "seq" and e.name == "ATTACK ANIMATION")
		check("s%d_attack_command" % row[1], not commands.is_empty(), logs)
		if not commands.is_empty():
			var player := XSequencePlayer.create(scene, {"user": user, "skill": skill}, [])
			player._exec(commands[0])
			check("s%d_attack_mirror" % row[1], not player.anims.is_empty() and player.anims.all(func(a): return a.scale.x < 0.0))
			player.anims.clear()
			var plain: Dictionary = commands[0].duplicate()
			plain.args = [commands[0].args[0]]
			player._exec(plain)
			check("s%d_attack_plain" % row[1], not player.anims.is_empty() and player.anims.all(func(a): return a.scale.x > 0.0))
		scene.queue_free()
		await get_tree().process_frame
