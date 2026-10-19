extends Node
## 角色模板 P0／P1：普通角色 11～40 的招募路径与基础战斗基线（能力曲线／伤害由 xiyou_rules 逐项对照 slice 参照）。
## 本测试补三件事：①招募——原版「召唤…」公共事件真的能让该角色入队、占出战栏；②初始装备与已学技能与 mv_oracle
## 参照行一致；③每个声明可用的角色在参照里都有独立行（等级采样 35／65／99 与伤害行），没有就不算可用。
## 完整养成（技能树、进阶、羁绊）不在 P0 范围：本测试不验也不声明。

## 公共事件 → 角色（由 db/CommonEvents 里的 129 指令得出；斯盖＝召唤苍龙骑士，克莱德＝召唤祭祀，克洛什＝召唤绿色游侠，雪清寒＝召唤雪山）
const RECRUIT := {13: 11, 23: 12, 20: 13, 21: 14, 22: 15, 19: 16, 24: 17, 25: 18}
## 第二批（角色 19～40，同样由 129 指令得出；摇光的公共事件就叫「摇光」，涅斐莉的是 1208）
const RECRUIT_2 := {26: 19, 27: 20, 29: 21, 30: 22, 31: 23, 32: 24, 33: 25, 69: 26, 70: 27, 71: 28, 86: 29, 87: 30, 90: 31, 1208: 32, 97: 33, 125: 34, 131: 35, 139: 36, 138: 37, 133: 38, 140: 39, 141: 40}
const REGRESSION := [1, 8, 9, 10]
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_actor_p0"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/slice_d2.json"))
	if not d is Dictionary:
		_check("oracle_present", false)
		return _finish()
	# ③ 参照行齐全
	for id in REGRESSION + RECRUIT.values() + RECRUIT_2.values():
		var row = d.actors.get(str(id))
		_check("oracle_row_%d" % id, row != null and row.has("lv1") and row.has("lv10Battle") and row.get("levelSamples", {}).size() == 3, id)
		var dmg = d.damage.filter(func(r): return r.get("actor") != null and int(r.actor) == id)
		_check("oracle_damage_%d" % id, dmg.size() > 0 and dmg.all(func(r): return not r.has("error")), [id, dmg.size()])
	# ② 初始装备与技能
	for id in REGRESSION + RECRUIT.values() + RECRUIT_2.values():
		var row: Dictionary = d.actors[str(id)]
		var a := XActor.new().setup(id)
		var mv_equips = row.equips.filter(func(e): return e != null).map(func(e): return int(e.base))
		var my_equips = a.equips.filter(func(e): return e != null and not e.is_empty()).map(func(e): return int(e.base))
		_check("equips_%d" % id, my_equips == mv_equips, [my_equips, mv_equips])
		var my_skills = a.skills().map(func(s): return int(s.id))
		my_skills.sort()
		var mv_skills = row.skills.map(func(s): return int(s))
		var missing = mv_skills.filter(func(s): return not my_skills.has(s) and not _is_boot_passive(d, s))
		_check("skills_%d" % id, missing.is_empty(), missing)
	# ① 招募路径
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	var map := XMapScene.new()
	add_child(map)
	for i in 4:
		await get_tree().process_frame
	var all_recruit := RECRUIT.duplicate()
	all_recruit.merge(RECRUIT_2)
	for ce in all_recruit:
		var id: int = all_recruit[ce]
		_check("not_in_party_before_%d" % id, not s.party.has(id))
		var waited := 0
		while map.busy and waited < 600:  # 上一个公共事件的尾声（提示、刷新）可能还占着地图
			await get_tree().process_frame
			waited += 1
		await map.run_common_event(ce)
		for i in 3:
			await get_tree().process_frame
		_check("recruit_%d" % id, s.party.has(id), [ce, s.party])
		_check("recruit_actor_%d" % id, s.actor(id).actor_id == id and s.actor(id).class_id == int(XDB.rec("Actors", id).classId), id)
	_check("regression_party_kept", [1, 8, 9, 10].all(func(i): return s.party.has(i)), s.party)
	_check("battle_slots_five", s.battle_slots.size() == 5, s.battle_slots)
	_finish()


## oracle 技能列表含开局被动（passives／starterPassives）；它们由 xiyou_rules 的 _make_actor 灌入，这里不重复
func _is_boot_passive(d: Dictionary, skill: int) -> bool:
	return d.passives.map(func(v): return int(v)).has(skill) or d.starterPassives.map(func(v): return int(v)).has(skill)


func _finish() -> void:
	var passed := results.filter(func(r): return r["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
