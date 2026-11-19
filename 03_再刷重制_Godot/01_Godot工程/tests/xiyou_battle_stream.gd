extends Node
## 【cc·T225·未经审查】多段技能逐段结算（XBattleStream，O-待定）：开招那一帧只算到第一段之前，画面演到哪段才结算哪段。
## 玩家反馈拳一「认真连续拳」开招卡（T224 量：开招一帧约 88ms，16 段一次算完）。
## 每个用例开／关逐段结算各打一场（同一随机种子、同一指令），比：
## - 结果相同：这次行动演完后敌我 HP／MP／TP／状态，整次行动的记录（类型、伤害、命中、暴击、目标、追加、反击、倒下、日志行）逐条相同；
## - 开着时：记录前缀从没对不上（mismatches 0），画面拿到的就是 act 的全部记录，停的次数＝根序列实际跑的 ACTION EFFECT 条数；
## - 开招那一帧（指令定下→开始演出）的耗时：TIMING 用例三次取中，多段招开着时不到关着的一半，打印量数。
## 用例：拳一（163）认真连续拳打嘤嘤怪×3（中途打死：剩下的段换目标／落空）与 80 苏醒的黝石巨人（单个首领、没有开场事件，打不死，段数打满）；
## 各专属模块角色（饿狼、宿傩、渡鸦、黄泉、镜流、甚尔、屠苏、璇、谷雨、云裳、米拉、奈叶、小猫、流萤、至尊宝）用职业里段数最多的招；
## 天启篇（饿狼、拳一、宿傩；五条悟在夹具里没过试炼、出手被挡，没放进来）；技能动画开关、战斗速度两档。
## 夹具：单人出战 99 级（拳一 70 级），加最大生命与敏捷（扛得住首领、先出手），超强者开关打开；规则流按种子（两边同种子）。

class P extends XBattleScene:
	var cmd_skill := 0
	var t_cmd := 0
	var act_usec := -1
	var done := false
	var parked := false
	var sig := []
	var logs_ref := []
	var stream_stats := {}
	func _command(u: XBattler):
		if u is XActor and not done and act_usec < 0:
			t_cmd = Time.get_ticks_usec()
			var foes := logic.alive(logic.enemies)
			return [XDB.rec("Skills", cmd_skill), foes[foes.size() - 1] if not foes.is_empty() else null]
		if u is XEnemy and not done:
			return await super._command(u)
		parked = true
		await get_tree().create_timer(100).timeout
		return [null, null]
	func _play(logs: Array) -> void:
		if act_usec >= 0 or t_cmd == 0 or not logs.any(func(l): return l.type == "action"):
			await super._play(logs)
			return
		act_usec = Time.get_ticks_usec() - t_cmd
		var st = _stream
		await super._play(logs)
		if st != null:
			st.finish()
			stream_stats = {"gates": st.gates, "mismatches": st.mismatches, "pulls": st.pulls, "max_pull": st.max_pull_usec,
				"start": st.start_usec, "pull_ms": st.pull_usecs.map(func(x): return x / 1000), "same": is_same(st.out, logs) and st.out.size() == logs.size()}
		for b in logic.actors + logic.enemies:
			sig.append([b.hp, b.mp, b.tp, b.state_ids.duplicate()])
		logs_ref = logs
		done = true


## [角色, 技能（0＝职业里 ACTION EFFECT 最多的招）, 敌群, 天启篇, 计时（三次取中）, 必须出现的记录类型（可选：collapse＝中途打死、counter＝反击）]；
## 253 巨型雪猿反击率 15%，劲夫怒拳·乱打（物理多段；拳一的招必中、不被反击）里出反击（反击记录与它那一段同批到）；按场景分组（单场景控制在几分钟内）
const GROUPS := {
	"a": [[163, 9939, 2, false, false, "collapse"], [163, 9939, 80, false, true], [163, 9938, 80, false, true], [50, 1340, 253, false, false, "counter"]],
	"b": [[163, 1098, 80, false, true], [163, 9926, 80, false, true], [163, 9934, 80, false, false], [163, 2058, 80, false, false]],
	"c": [[173, 0, 80, false, false], [172, 0, 80, false, false], [167, 0, 80, false, false], [169, 0, 80, false, false],
		[170, 0, 80, false, false], [171, 0, 80, false, false], [176, 0, 80, false, false], [177, 0, 80, false, false]],
	"d": [[175, 0, 80, false, false], [174, 0, 80, false, false], [168, 0, 80, false, false], [108, 0, 80, false, false],
		[178, 0, 80, false, false], [179, 0, 80, false, false], [36, 0, 80, false, false]],
	"e": [[173, 0, 80, true, false], [163, 9939, 2, true, false], [172, 0, 80, true, false], [163, 9939, 80, true, true], [163, 9938, 80, true, true]],
}
## 场景（xiyou_battle_stream、_b…_e）里设
@export var group := "a"
const RUNS := 3

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


static func effect_count(rec: Dictionary) -> int:
	var n := 0
	var seq = rec.get("yepSeq")
	if not seq is Dictionary:
		return 0
	for ph in seq.values():
		for e in ph:
			if str(e[0]).to_upper() == "ACTION EFFECT":
				n += 1
	return n


## 职业里打敌人、段数最多的招
static func pick_skill(actor_id: int) -> int:
	var cls := XDB.rec("Classes", int(XDB.rec("Actors", actor_id).get("classId", 0)))
	var best := 0
	var most := -1
	for l in cls.get("learnings", []):
		var rec := XDB.rec("Skills", int(l.skillId))
		if not int(rec.get("scope", 0)) in [1, 2, 3, 4, 5, 6]:
			continue
		var n := effect_count(rec)
		if n > most:
			most = n
			best = int(rec.id)
	return best


func _battle(c: Array, skill: int, on: bool, seed: int) -> Dictionary:
	XBattleStream.PER_SEGMENT = on
	var actor_id: int = c[0]
	var s: XState
	if c[3]:
		s = XTianqi.start_new_game(3, "lianyu", [actor_id])  # 炼狱：一场能上 2 个超强者
		XTianqi.take_pending()
		XTianqi._joining = true
		s.add_actor(actor_id)
		XTianqi._joining = false
		if not s.party.has(actor_id):
			s.party.append(actor_id)  # 五条悟要过试炼才入队，夹具直接放
		s._ensure_slots()
		if not s.battle_slots.has(actor_id):
			s.set_battle_slot(0, actor_id)
	else:
		s = XState.new_game(3, 1, [])
		s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)  # 超强者开放
		s.add_actor(actor_id)
		if actor_id != 1:
			s.remove_actor(1)
	XState.current = s
	s.random_master = XRandomStream.hex64(seed)
	for a in s.battle_members():
		a.learn_skill(skill)
		a.change_level_mv(70 if actor_id == 163 else 99)
		a.add_param(0, 500000)  # 夹具：扛得住首领、先出手（只为走到指令窗，两边一样）
		a.add_param(6, 99999)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
		a.tp = 100
	var scene := P.new()
	scene.cmd_skill = skill
	scene.setup(int(c[2]), true, false, {})
	for e in scene.logic.enemies:
		e.tp = 0  # 天启篇开场 TP 不走种子（关对关两场也不同），夹具定死
	for a in scene.logic.actors:
		a.tp = 100
	add_child(scene)
	var t0 := Engine.get_physics_frames()
	while not scene.done and Engine.get_physics_frames() - t0 < 3000:
		await get_tree().physics_frame
	# 等它停在下一个指令窗（或打完）再拆，免得演出中途拆场
	while scene.done and not scene.parked and not scene.logic.is_over() and Engine.get_physics_frames() - t0 < 6000:
		await get_tree().physics_frame
	var out := {"done": scene.done, "act": scene.act_usec, "sig": scene.sig, "digest": digest(scene.logs_ref), "stats": scene.stream_stats,
		"members": s.battle_members().size()}
	scene.queue_free()
	await get_tree().physics_frame
	XBattleStream.PER_SEGMENT = true
	return out


## 记录的可比部分：每条的类型＋各个基本类型的字段（伤害、命中、暴击…），战斗者记成名字，技能记编号，画面快照不比
static func digest(logs: Array) -> Array:
	var out := []
	for l in logs:
		var row := []
		var keys: Array = l.keys()
		keys.sort()
		for k in keys:
			if str(k) in ["views", "moves"]:
				continue
			row.append([str(k), _val(l[k])])
		out.append(row)
	return out


static func _val(v):
	if v is XBattler:
		return ("e:" if v is XEnemy else "a:") + str(v.display_name())
	if v is Dictionary:
		return "rec:%s" % str(v.get("id", "")) if v.has("id") else "dict:%d" % v.size()
	if v is Array:
		return v.map(func(x): return _val(x))
	if v is Object:
		return "obj"
	return v


static func effect_marks(d: Array) -> int:
	var n := 0
	for row in d:
		var t := ""
		var nm := ""
		for kv in row:
			if kv[0] == "type":
				t = str(kv[1])
			if kv[0] == "name":
				nm = str(kv[1])
		if t == "seq" and nm == "ACTION EFFECT":
			n += 1
	return n


static func first_diff(a: Array, b: Array):
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return [i, a[i], b[i]]
	return ["size", a.size(), b.size()]


static func _median(a: Array) -> int:
	var b := a.duplicate()
	b.sort()
	return int(b[b.size() / 2]) if not b.is_empty() else -1


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_stream"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var only := OS.get_environment("STREAM_CASE")  # 调试：只跑本组第几个用例
	var n := 0
	for c in GROUPS[group]:
		n += 1
		if only != "" and int(only) != n:
			continue
		var skill: int = c[1] if int(c[1]) > 0 else pick_skill(c[0])
		var timing: bool = c[4]
		# 计时用例：技能动画开、默认速度；其余轮流用动画关＋最快速度（自动战斗常用档），两种画面节奏都走到
		var anim: bool = timing or n % 2 == 0
		XConfig.set_flag("CombatSkillAnimation", anim)
		XConfig.set_battle_speed(2 if anim else 4)
		var off_t := []
		var on_t := []
		var on: Dictionary
		var off: Dictionary
		for k in (RUNS if timing else 1):
			off = await _battle(c, skill, false, 20261119 + k)
			on = await _battle(c, skill, true, 20261119 + k)
			off_t.append(off.act)
			on_t.append(on.act)
			var tag := "%d_%d_%d%s_%d" % [c[0], skill, c[2], "_tq" if c[3] else "", k]
			check("ran_" + tag, off.done and on.done and off.members == 1, [off.done, on.done, off.members])
			check("same_state_" + tag, not off.sig.is_empty() and off.sig == on.sig, [off.sig, on.sig])
			check("same_logs_" + tag, not off.digest.is_empty() and off.digest == on.digest, first_diff(off.digest, on.digest))
			check("stream_used_" + tag, on.stats.get("same", false) and int(on.stats.get("mismatches", -1)) == 0, on.stats)
			if c.size() > 5:
				check("has_%s_%s" % [c[5], tag], on.digest.any(func(row): return row.has(["type", c[5]])), c[5])
			check("gates_match_effects_" + tag, int(on.stats.get("gates", -1)) == effect_marks(on.digest), [on.stats, effect_marks(on.digest)])
		var row := {"actor": c[0], "skill": skill, "troop": c[2], "tianqi": c[3], "anim": anim, "off_ms": _median(off_t) / 1000.0, "on_ms": _median(on_t) / 1000.0,
			"gates": on.stats.get("gates", -1), "max_pull_ms": int(on.stats.get("max_pull", 0)) / 1000.0, "logs": on.digest.size(), "pulls_ms": on.stats.get("pull_ms", [])}
		print("STREAM ", JSON.stringify(row))
		if OS.get_environment("STREAM_DEBUG") == "1":
			print("DIGEST ", JSON.stringify(on.digest).left(1500))
		if timing and int(on.stats.get("gates", 0)) >= 8:
			check("start_cheaper_%d%s" % [skill, "_tq" if c[3] else ""], _median(on_t) * 2 < _median(off_t), [on_t, off_t])  # 多段招：开招那一帧不到关着的一半
	if group == "a":
		# 回退：关着时战斗画面不开 XBattleStream
		XBattleStream.PER_SEGMENT = false
		var r: Dictionary = await _battle(GROUPS.a[0], 9939, XBattleStream.PER_SEGMENT, 1)
		check("rollback_no_stream", r.done and r.stats.is_empty(), r.stats)
	XBattleStream.PER_SEGMENT = true
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
