extends Node
## 天启篇教派连带内容·包壬（XTianqiSect.REN）：通关抽到的新角色入队时同步到上场队员平均等级，不超过本层等级上限。
## 一、1～5 层第一次抽（5 层通关、队伍全 1 级）正常，等级 1；二、20 层附近抽一个人（实跑完整链 run_draw→take_draw）：
##    等级＝上场平均（四舍五入）、不超上限、经验同步；三、上限比平均低时夹到上限；四、开关关回原样（初始等级）；五、西游档不受影响（add_actor 不同步）。

class FakeHost extends RefCounted:
	var answers: Array = []
	func show_text(_f: String, _i: int, _lines: Array) -> void:
		pass
	func show_text_with_choices(_f: String, _i: int, _lines: Array, _options: Array, _cancel: int) -> int:
		return int(answers.pop_front()) if not answers.is_empty() else 0

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and not [95, 173].has(id))


func _state(lineup: Array, levels: Array) -> XState:
	var s := XTianqi.start_new_game(3, "jiusi", lineup)
	XTianqi.take_pending()
	for id in lineup:
		s.add_actor(int(id))
	for i in lineup.size():
		s.actor(int(lineup[i])).change_level(int(levels[i]))
	s.map_id = 4
	XState.current = s
	return s


## 完整链：run_draw 里选「候选第一位」入队
func _draw(s: XState) -> int:
	var host := FakeHost.new()
	host.answers = [0]
	var o := XTianqi.draw_offer(s)
	var id := int(o[0])
	await XTianqi.run_draw(host, s)
	return id


func _run() -> void:
	XMessageBox.auto = true
	XSave.dir_override = "user://test_xiyou_tianqi_sect_ren"
	seed(20261114)
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[4]]

	# 一、第一次抽（5 层通关，全 1 级）
	var s := _state(lineup, [1, 1, 1, 1, 1])
	s.set_variable(20, 6)
	var id := await _draw(s)
	_check("first_draw_in", s.party.has(id) and XTianqi.draws_used(s) >= 1)
	_check("first_draw_lv1", s.actor(id)._level() == 1, s.actor(id)._level())

	# 二、20 层附近：上场 4 人＋助力位，平均 (40+41+42+43+43)/5 = 41.8 → 42
	s = _state(lineup, [40, 41, 42, 43, 43])
	s.actor_max_level = 60
	s.set_variable(20, 21)
	var pre := [s.actor(w[0])._level(), s.actor(w[4])._level()]
	id = await _draw(s)
	var a := s.actor(id)
	_check("avg_sync", a._level() == 42, [a._level(), pre])
	_check("exp_synced", a.exp_total == a.exp_for_level(42), [a.exp_total, a.exp_for_level(42)])
	_check("not_over_cap", a._level() <= s.max_level())

	# 三、上限低于平均：夹到上限
	s = _state(lineup, [50, 50, 50, 50, 50])
	s.actor_max_level = 45
	s.set_variable(20, 21)
	id = await _draw(s)
	_check("cap_clamp", s.actor(id)._level() <= 45, s.actor(id)._level())

	# 四、开关关：回到入队时的初始等级
	XTianqiSect.REN = false
	s = _state(lineup, [40, 41, 42, 43, 43])
	s.actor_max_level = 60
	s.set_variable(20, 21)
	id = await _draw(s)
	_check("switch_off", s.actor(id)._level() == int(s.actor(id).data().initialLevel), s.actor(id)._level())
	XTianqiSect.REN = true

	# 五、西游档：add_actor 不同步（ren_sync 不是天启篇存档不动）
	var p := XState.new_game_blank()
	XState.current = p
	p.add_actor(w[5])
	var lv0: int = p.actor(w[5])._level()
	_check("plain_no_sync", XTianqiSect.ren_sync(p, w[5], 30) == 0 and p.actor(w[5])._level() == lv0, lv0)

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
