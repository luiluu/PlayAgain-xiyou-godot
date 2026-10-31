extends Node
## 难度继承找替代角色（审查第 4 期 P3）：角色 1 不在队时，XState._difficulty_profile 在 <167 的队员里找第一个带难度技能的，
## 原版 $gameActors._data 按角色号从小到大遍历，重制也要按角色号（不是按建对象先后）。
## 先建 12 再建 5、都带难度技能（5561、5547）、去掉角色 1：来源应是 5，档位技能只含 5547。
var results := []


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := XState.new_game(3, 1, [])
	XState.current = s
	var managed := XState.difficulty_managed_skills()
	check("skills_managed", managed.has(5547) and managed.has(5561), [managed.has(5547), managed.has(5561)])
	s.add_actor(12)
	s.add_actor(5)
	s.actors.erase(1)
	check("order_built_12_then_5", s.actors.keys().find(12) < s.actors.keys().find(5), s.actors.keys())
	s.actor(5).learn_skill(5547)
	s.actor(12).learn_skill(5561)
	var skills: Array = s._difficulty_profile().get("skills", [])
	check("source_is_lowest_id", skills.has(5547) and not skills.has(5561), skills)
	# 只有角色 12 带技能时来源仍是 12
	s.actor(5).forget_skill(5547)
	skills = s._difficulty_profile().get("skills", [])
	check("source_falls_to_12", skills.has(5561) and not skills.has(5547), skills)
	# ≥167 的新增角色不当来源
	s.add_actor(167)
	s.actor(167).learn_skill(5548)
	s.actor(12).forget_skill(5561)
	skills = s._difficulty_profile().get("skills", [])
	check("new_actor_not_source", not skills.has(5548), skills)
	print("TEST_RESULT=" + JSON.stringify({"passed": results.filter(func(r): return r.passed).size(), "total": results.size()}))
	get_tree().quit(0 if results.all(func(r): return r.passed) else 1)
