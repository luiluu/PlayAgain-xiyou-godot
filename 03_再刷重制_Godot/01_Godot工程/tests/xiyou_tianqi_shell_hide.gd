extends Node
## T052：天启篇技能列表收起「已并入／已移除」空壳（XTianqiSkills.HIDE_SHELLS，回退开关）。
## 只隐藏菜单列表显示：天启篇角色卡开着时列表不列空壳；西游档不变；已学会的空壳 skill_ids 存读档后还在、记录照读（不动可用性）；关开关回到全列出。

const SHELL := 1770  # 觉醒:雷加尔（desc 只剩「已并入其他被动」）
const REAL := 1088  # 七彩祥云（desc 有真效果，不是空壳）
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(tianqi: bool) -> XState:
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", [1, 2, 3, 4, 5])
		XTianqi.take_pending()
	else:
		s = XState.new_game_blank()
	for id in [25, 36]:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
		if not s.party.has(id):
			s.party.append(id)
	s.map_id = 4
	XState.current = s
	return s


func _all_listed(page: XSkillScene, id: int) -> bool:
	for ti in page.types().size():
		page.type_index = ti
		if page.entries().any(func(x): return int(x.id) == id):
			return true
	return false


func _page(s: XState, actor_id: int) -> XSkillScene:
	var page := XSkillScene.new()
	page.actor_index = s.party.find(actor_id)
	add_child(page)
	_check("page_actor_%d" % actor_id, int(page.actor().actor_id) == actor_id, page.actor_index)
	return page


func _run() -> void:
	XMessageBox.auto = true
	XTianqiSkills.reload_table()
	_check("default_on", XTianqiSkills.HIDE_SHELLS)
	XTianqiSkills.CARDS = true
	# 天启篇档
	var s := _state(true)
	_check("is_shell", XTianqiSkills.is_shell(SHELL) and not XTianqiSkills.is_shell(REAL) and not XTianqiSkills.is_shell(101))
	var n := 0
	_check("tq_cards_on", XTianqiSkills.cards_on(s))
	for k in XTianqiSkills.data().get("skills", {}):
		if XTianqiSkills.is_shell(int(k)):
			n += 1
	# 上限＝实际数 271：T524（dev.934）前 247，T524 有意新增 24 个——裴钱武夫十境 4415～4424、练气十境 4426～4435（并入天赋无敌）、三笠 8143～8146（并入锻炼）
	_check("shell_count", n >= 240 and n <= 271, n)
	var a: XActor = s.actor(25)
	a.learn_skill(SHELL)
	_check("learned", a.skill_ids.has(SHELL))
	var page := _page(s, 25)
	_check("tq_listing_nonempty", _all_listed(page, 1088) or page.types().size() > 0, page.types())
	_check("tq_hidden", not _all_listed(page, SHELL))
	page.free()
	# 存读档后仍学会、记录照读
	var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = s2
	_check("saved_kept", s2.actor(25).skill_ids.has(SHELL) and not XDB.rec("Skills", SHELL).is_empty())
	XState.current = s
	# 回退开关：关了全列出
	XTianqiSkills.HIDE_SHELLS = false
	_check("off_not_shell", not XTianqiSkills.is_shell(SHELL))
	var p2 := _page(s, 25)
	_check("off_listed", _all_listed(p2, SHELL))
	p2.free()
	XTianqiSkills.HIDE_SHELLS = true
	# 西游档（非天启篇存档）：不收
	var w := _state(false)
	w.actor(25).learn_skill(SHELL)
	_check("xiyou_not_shell", not XTianqiSkills.is_shell(SHELL))
	var p3 := _page(w, 25)
	_check("xiyou_listed", _all_listed(p3, SHELL))
	p3.free()
	XTianqiSkills.CARDS = false
	XState.current = XState.new()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
