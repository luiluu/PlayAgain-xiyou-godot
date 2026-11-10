extends Node
## 【cc·悟空·未经审查】渡鸦 167／米拉 168 技能解锁（XSkillProgression，chars-gaps3）：同步之外直接 learn_skill 学到的未解锁专属技能，
## 照原版 installNativeSkillProgressionRuntime 的 skills／meetsSkillConditions 包装不列、不能用；开战（XBattleLogic.setup，
## 原 BattleManager.startBattle 包装）再同步一次，把它忘掉；别的角色学了也不管（unlocked 只管本人范围）。
var total := 0
var passed := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ids(a: XActor) -> Array:
	return a.skills().map(func(r): return int(r.id))


func _state(level: int, rank: int) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(2494, true)  # 挑战开关：超强角色能出战
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XRaven.ACTOR] = rank
	s.add_actor(XRaven.ACTOR)
	s.add_actor(1)
	var a := s.actor(XRaven.ACTOR)
	a.change_level_mv(level)
	XSkillProgression.sync(a)
	a.recover_all()
	return s


func _ready() -> void:
	XConfig.path_override = "user://xiyou_skill_progression_none.json"
	const LOCKED := 10123  # 冥羽连葬：20 级、1 阶解锁
	var s := _state(10, 0)
	var a := s.actor(XRaven.ACTOR)
	var sk := XDB.rec("Skills", LOCKED)
	check("synced.not_learned", not a.skill_ids.has(LOCKED), a.skill_ids)
	a.learn_skill(LOCKED)
	check("direct.learned", a.skill_ids.has(LOCKED))
	check("direct.not_listed", not _ids(a).has(LOCKED), _ids(a))
	check("direct.listed_unlocked", _ids(a).has(10122), _ids(a))
	var logic := XBattleLogic.new()
	logic.state = s
	check("direct.cannot_use", not logic.can_use(a, sk))
	# 别的角色学了不管
	var b := s.actor(1)
	b.learn_skill(LOCKED)
	check("other_actor.listed", _ids(b).has(LOCKED), _ids(b))
	b.forget_skill(LOCKED)
	# 开战再同步：忘掉；开关关掉时留着
	XSkillProgression.SYNC_ON_BATTLE_START = false
	var l0 := XBattleLogic.new()
	l0.setup(3, s, XBattleRandom.create("0000000000000167"))
	check("battle.switch_off_keeps", a.skill_ids.has(LOCKED))
	XSkillProgression.SYNC_ON_BATTLE_START = true
	var l1 := XBattleLogic.new()
	l1.setup(3, s, XBattleRandom.create("0000000000000167"))
	check("battle.sync_forgets", not a.skill_ids.has(LOCKED), a.skill_ids)
	# 解锁了：照常列、能用
	var s2 := _state(20, 1)
	var a2 := s2.actor(XRaven.ACTOR)
	var l2 := XBattleLogic.new()
	l2.state = s2
	check("unlocked.listed", _ids(a2).has(LOCKED), _ids(a2))
	check("unlocked.can_use", l2.can_use(a2, sk), [a2.mp, a2.tp])
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_skill_progression", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
