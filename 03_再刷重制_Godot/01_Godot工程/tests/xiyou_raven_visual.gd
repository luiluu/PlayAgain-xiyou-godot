extends Node
## 【cc·ravenfx·未经审查】渡鸦表现余项与 mv_oracle/raven_visual_probe.cjs 的冻结 v0.28 参照（generated/oracle/raven_visual.json）逐例比：
## ① 战斗动作替换（XBattlerSprite.raven_motion）：167 普通 damage→evade、dying→wait，神话形态不换（raven6 改探针按实机装载次序重量），168、1 号不换；
## ② 地图步行帧停留（MVCharacter.animation_wait）：玩家（取队长）、第 1／2 个跟随者、普通角色，移动速度 1～6。
## 最后验两个回退开关：RAVEN_MOTION_REMAP=false、RAVEN_WALK_SLOW=false 时全部照通用值。
const ORACLE := "oracle/raven_visual.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not check("oracle", d is Dictionary and d.cases.size() >= 7 and d.cases.all(func(c): return c.errors.is_empty()), ORACLE):
		finish()
		return
	for c in d.cases:
		if str(c.id).begins_with("motion."):
			_motion(c, true)
		else:
			_walk(c, true)
	XBattlerSprite.RAVEN_MOTION_REMAP = false
	MVCharacter.RAVEN_WALK_SLOW = false
	for c in d.cases:
		if str(c.id).begins_with("motion."):
			_motion(c, false)
		else:
			_walk(c, false)
	XBattlerSprite.RAVEN_MOTION_REMAP = true
	MVCharacter.RAVEN_WALK_SLOW = true
	_myth_alpha()
	XState.current = null
	finish()


func _motion(c: Dictionary, on: bool) -> void:
	var s := XState.new_game(2, 1, [8])
	XState.current = s
	if c.setup.get("myth", false):
		s.raven["myth"] = 3
	var sp := XBattlerSprite.new()
	sp.battler = s.actor(int(c.setup.actor))
	var got := {}
	var want := {}
	for m in c.observed.motions:
		got[m] = sp.raven_motion(str(m))
		want[m] = str(c.observed.motions[m]) if on else str(m)
	sp.free()
	check(("" if on else "rollback.") + str(c.id), got == want, [got, want])


func _walk(c: Dictionary, on: bool) -> void:
	var s := XState.new_game(2, 1, [8])
	XState.current = s
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in c.setup.party:
		s.add_actor(int(id))
	var members := s.battle_members().map(func(b): return b.actor_id)
	check(str(c.id) + ".members", members == (c.observed.members as Array).map(func(v): return int(v)), [members, c.observed.members])
	var player := MVPlayer.new()
	var f1 := MVFollower.new()
	f1.member_index = 1
	var f2 := MVFollower.new()
	f2.member_index = 2
	var ev := MVCharacter.new()
	for r in c.observed.rows:
		for ch in [player, f1, f2, ev]:
			ch.move_speed = int(r.speed)
		var base := (9 - int(r.speed)) * 3
		var got := [player.animation_wait(), f1.animation_wait(), f2.animation_wait(), ev.animation_wait()]
		var want := [int(r.player), int(r.follower1), int(r.follower2), int(r.character)] if on else [base, base, base, base]
		check("%s%s.speed%d" % ["" if on else "rollback.", c.id, int(r.speed)], got == want, [got, want])
	for ch in [player, f1, f2, ev]:
		ch.free()


## ravenfx2：神话形态阵亡主图透明度 0.35（sprite_real 量具 raven_myth：myth_dead alpha 0.35，其余 1；普通形态阵亡 1）
func _myth_alpha() -> void:
	for on in [true, false]:
		XBattlerSprite.RAVEN_MYTH_DEAD_ALPHA = on
		for myth in [true, false]:
			var s := XState.new_game(2, 1, [8])
			XState.current = s
			s.switches[2494] = true
			s.add_actor(167)
			s.raven["myth"] = 3 if myth else 0
			var a := s.actor(167)
			var sp := XBattlerSprite.new()
			add_child(sp)
			sp.setup(a, 1.0)
			sp._process(1.0 / 60.0)
			var alive := sp.sprite.modulate.a
			a.add_new_state(1)
			sp._process(1.0 / 60.0)
			var dead := sp.sprite.modulate.a
			a.remove_state(1)
			a.hp = a.mhp
			sp._process(1.0 / 60.0)
			var back := sp.sprite.modulate.a
			var want := [1.0, 0.35 if myth and on else 1.0, 1.0]
			var got := [snappedf(alive, 0.001), snappedf(dead, 0.001), snappedf(back, 0.001)]
			check("myth_alpha.%s.%s" % ["on" if on else "rollback", "myth" if myth else "normal"], range(3).all(func(i): return absf(got[i] - want[i]) < 0.001) and (sp._look_key.contains("RavenMythic") == myth), [got, want, sp._look_key])
			sp.queue_free()
	XBattlerSprite.RAVEN_MYTH_DEAD_ALPHA = true


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
