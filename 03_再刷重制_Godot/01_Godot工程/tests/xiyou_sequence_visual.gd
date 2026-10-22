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
## 动画随敌人浮空／跳跃抬高的正式版读数（__seqRef.suite(列表, 'action_sequence_float_oracle')，开技能动画）：
## s414 投掷（动画 1 播着时浮空 2000%：动画跟着抬高，浮空每帧多走一步）、s463 升龙拳（动画 302 播着时跳跃 500%）、
## s161（角色自己浮空时身上放动画 129：角色同样抬高、浮空变快）、s414 关动画
const FLOAT_ORACLE := "res://tests/fixtures/action_sequence_float_oracle.json"
## 普通攻击动画（双持）的正式版读数（ui_reference __atkAniRef.suite()）
const ATK_ORACLE := "res://tests/fixtures/attack_animation_oracle.json"
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
		await _trace(scene, s, key, oracle.traces[key])
	var float_oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLOAT_ORACLE))
	for key in float_oracle.traces:
		await _trace(scene, s, key, float_oracle.traces[key])
	var hp_oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HP_ORACLE))
	await _counter_death(scene, hp_oracle.traces.s104_counter_death)
	await _multi_hit_gauge(scene, hp_oracle.traces.s131)
	await _attack_mirror()
	await _attack_dual()
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
	if key == "s161":
		# Native UI fixture fixes Math.random at 0.5, so the 3% state never fires.
		# It adds three log methods when triggered; keep that fixture input explicit.
		check("s161_fixed_no_status", logs.filter(func(l): return l.type == "hit").all(func(l): return l.added.is_empty() and l.removed.is_empty()))
	var got := {"cmds": [], "frames": [], "sprites": {}, "anims": []}
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
		# 动画相对目标的位置（还在 _delay 里、没定过位置的不收：正式版停在 0,0）
		var row := []
		for a in scene.fx.get_children():
			if a is MVAnimation and a.target is XBattlerSprite and a.duration < a.anim.frames.size() * a.rate + 1:
				var ts: XBattlerSprite = a.target
				row.append([_key(ts.battler, scene), snappedf(a.position.x - ts.position.x, 0.001), snappedf(a.position.y - ts.position.y, 0.001)])
		got.anims.append(row)
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
	# 动画相对目标的位置逐帧（新读数才有）：头上／中心的动画随敌人浮空、跳跃抬高
	if t.has("anims"):
		var bad_anim := []
		for f in range(n):
			# 同一帧几只动画的先后不比（正式版按精灵建立先后排在战场子节点里）
			var w: Array = t.anims[f].duplicate()
			var g: Array = got.anims[f].duplicate() if f < got.anims.size() else []
			w.sort_custom(func(x, y): return str(x[0]) < str(y[0]))
			g.sort_custom(func(x, y): return str(x[0]) < str(y[0]))
			var same := w.size() == g.size()
			for ai in range(mini(w.size(), g.size())):
				same = same and str(w[ai][0]) == g[ai][0] and absf(float(w[ai][1]) - g[ai][1]) < 0.01 and absf(float(w[ai][2]) - g[ai][2]) < 0.01
			if not same:
				bad_anim.append([f, g, w])
		var lifted: bool = t.anims.any(func(r): return r.any(func(a): return str(a[0]).begins_with("e") and float(a[2]) < -200.0))
		check("%s_anim_follow" % key, bad_anim.is_empty() and (lifted or not key.begins_with("s414_anim")), bad_anim.slice(0, 6))


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


## 冻结 YEP_BattleEngineCore.js:5617 showActorAtkAniMirror 与 MV showActorAttackAnimation：双持角色两把武器的动画都放，
## MIRROR 路径武器 1 镜像＋武器 2 不镜像，普通路径武器 1＋武器 2 镜像；单武器、空手、敌人只放一个。
## 对照正式版读数：每个目标上新建的动画 [目标序号, 动画, 镜像, _delay]（同一目标内按动画号排序比）。
func _attack_dual() -> void:
	XConfig.set_flag("CombatSkillAnimation", true)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATK_ORACLE))
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState._become_current(s)
	var scene := QuietBattle.new()
	scene.setup(2, true, false, {})
	add_child(scene)
	await get_tree().physics_frame
	var actor: XActor = scene.logic.actors[0]
	var foes: Array = scene.logic.enemies.slice(0, 2)
	var rows := func(anims: Array) -> Array:
		var out := []
		for a in anims:
			var i := foes.map(func(f): return scene.sprites[f]).find(a.target)
			out.append([i, int(a.anim.id), 1 if a.scale.x < 0.0 else 0, a.wait])
		out.sort()
		return out
	for key in ["dual", "single", "bare", "enemy"]:
		var want: Dictionary = oracle.cases[key]
		var user: XBattler = foes[0]
		if key != "enemy":
			user = actor
			for i in range(actor.equips.size()):
				actor.equips[i] = null
			for i in range(want.weapons.size()):
				actor.equips[i] = XGear.template("weapon", int(want.weapons[i]))
		check("atk_%s_ids" % key, scene._attack_animation_ids(user) == want.ids.map(func(v): return int(v)), [scene._attack_animation_ids(user), want.ids])
		for path in ["plain", "mirror"]:
			var player := XSequencePlayer.create(scene, {"user": user, "skill": XDB.rec("Skills", 1)}, [])
			player._attack_animation(foes, path == "mirror")
			var expect: Array = want[path].map(func(r): return r.map(func(v): return int(v)))
			expect.sort()
			var got: Array = rows.call(player.anims)
			check("atk_%s_%s" % [key, path], got == expect, {"godot": got, "mv": expect})
			for a in player.anims:
				if is_instance_valid(a):
					a.queue_free()
	scene.queue_free()
	await get_tree().process_frame
