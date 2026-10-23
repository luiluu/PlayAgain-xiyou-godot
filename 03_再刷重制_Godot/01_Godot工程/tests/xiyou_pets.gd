extends Node
## 宠物菜单（XPets／XPetScene）：对照冻结 v0.28 浏览器参照 tests/fixtures/pet_oracle.json
## （新局 1/8/9/10，按原版 GetingPet 造的敌人 1、288、10 三只宠物，第 2 只经验 500）：
## 窗口几何、目录、三只的状态窗逐条绘制（文字、字号、颜色，坐标与宽差 ≤ POS_TOL）、底部指令、技能列表与说明卡位置、共享角色窗；
## 出战（全队学会宠物技能、<TeamA> 只给共享角色、目录带「[出战]」、前 8 项加成取值）、休息（技能撤回）、放生；
## GetingPet 的结构（14 项加成范围、技能、等级技能）、等级表、存读档、主菜单入口（公共事件 169）与解释器路径。

const FIXTURE := "res://tests/fixtures/pet_oracle.json"
const POS_TOL := 0.05

var results := []


class FakeHost extends Node:
	var opened := 0
	func open_pets() -> void:
		opened += 1
		await get_tree().process_frame
	func refresh_events() -> void:
		pass


var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


static func _col(t: String) -> String:
	return (XQuality.parse_rgba(t) if t.begins_with("rgba") else Color(t)).to_html(false)


static func want_form(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "i":
			out.append([int(o[1]), float(o[2]), float(o[3])])
		else:
			# 参照颜色是 EnemyNameColorByDifficulty 改色前的（新局难度 2）
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), float(o[6]), XEnemy.name_color(str(o[1]), 2, Color(_col(str(o[7])))).to_html(false)])
	out.sort_custom(func(a, b): return str(a) < str(b))
	return out


static func got_form(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "i":
			out.append([int(o[1]), float(o[2]), float(o[3])])
		else:
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), float(o[7]), (o[8] as Color).to_html(false)])
	out.sort_custom(func(a, b): return str(a) < str(b))
	return out


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		var bad := g.size() != w.size()
		if not bad:
			for k in w.size():
				if w[k] is String:
					bad = bad or str(g[k]) != w[k]
				else:
					bad = bad or absf(float(g[k]) - float(w[k])) > POS_TOL
		if bad:
			return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


## 参照里的宠物 → XPets 的存档形
static func pet_from(p: Dictionary) -> Dictionary:
	var lv := {}
	for k in p.lvSkills:
		lv[str(k)] = int(p.lvSkills[k])
	return {"enemy": int(p.id), "elite": bool(p.elite), "letter": "", "push": p.paramPush.map(func(v): return float(str(v))),
		"skills": p.skills.map(func(v): return int(v)), "lv_skills": lv, "exp": int(p.exp), "ls": int(p.ls[0]), "ls_max": int(p.ls[1])}


func _setup(ref: Dictionary) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.pets.list = ref.pets.map(func(p): return pet_from(p))
	return s


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.pets.size() == 3):
		get_tree().quit.call_deferred(1)
		return
	var s := _setup(ref)
	check("levels", s.pets.list.map(func(p): return XPets.level(p)) == ref.pets.map(func(p): return int(p.lv)), s.pets.list.map(func(p): return XPets.level(p)))
	check("names", s.pets.list.map(func(p): return XPets.pet_name(s, p)) == ref.pets.map(func(p): return str(p.name)), s.pets.list.map(func(p): return XPets.pet_name(s, p)))
	var page := XPetScene.new()
	add_child(page)
	await frames()
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	var geo: Dictionary = ref.geo
	var near := func(a: Array, b: Array) -> bool:
		for i in 4:
			if absf(float(a[i]) - float(b[i])) > 0.7:
				return false
		return true
	check("geometry", near.call(rect.call(page.index_win), geo.index) and near.call(rect.call(page.status_win), geo.status)
		and near.call(rect.call(page.skill_win), geo.skill) and near.call(rect.call(page.bottom_win), geo.bottom) and near.call(rect.call(page.team_win), geo.team),
		[rect.call(page.index_win), rect.call(page.bottom_win), rect.call(page.team_win)])
	var bad := []
	for i in 3:
		var d := diff(got_form(XPetScene.status_ops(s, s.pets.list[i])), want_form(ref.status[str(i)]))
		if d != "":
			bad.append("%d %s" % [i, d])
	check("oracle_status", bad.is_empty(), bad)
	var idx := []
	for i in 3:
		idx.append(XPetScene._t(XPets.pet_name(s, s.pets.list[i]).replace(XPetScene.MUTANT, ""), 6, i * 36.0, 386))
	var d := diff(got_form(idx), want_form(ref.index))
	check("oracle_index", d == "", d)
	var bottom := []
	for i in XPetScene.BOTTOM_ROWS:
		bottom.append(XPetScene._t(XPetScene.COMMANDS[i][0], 6, i * 36.0, 387))
	d = diff(got_form(bottom), want_form(ref.bottom))
	check("oracle_bottom", d == "", d)
	check("bottom_commands", XPetScene.COMMANDS.map(func(c): return c[0]) == ["出战", "休息", "放生", "修改共享角色", "查看技能", "合成", "喂养"])
	var team := []
	var names := page.team_names()
	for i in names.size():
		team.append(XPetScene._t(names[i], 6, i * 36.0, 814))
	d = diff(got_form(team), want_form(ref.team))
	check("oracle_team", d == "", d)
	# 操作：选第 2 只，查看技能
	page.select(1)
	await frames(10)
	await shot("pet_0")
	page.ok()
	check("bottom_open", page.mode == "bottom" and page.cmd == 0)
	page.cmd = 4
	page.ok()
	await frames(12)
	await shot("pet_1_skills")
	var ids := XPetScene.skill_ids(page.current())
	var want_names: Array = ref.skill.filter(func(o): return o[0] == "t").map(func(o): return str(o[1]))
	var got_names := ids.slice(0, want_names.size()).map(func(i): return str(XDB.rec("Skills", i).name))
	check("skill_list", page.mode == "skills" and got_names == want_names
		and page.help_card.visible and page.help_card.position == Vector2(float(ref.help[0]), float(ref.help[1])), [ids, want_names, page.help_card.position])
	page.cancel()
	check("skill_cancel", page.mode == "bottom" and not page.help_card.visible)
	page.cancel()
	# 出战
	page.ok()
	page.cmd = 0
	page.ok()
	var aw: Dictionary = ref.afterWar
	var pet_skills: Array = s.pets.list[1].skills
	var got_members := s.members().map(func(a): return [a.actor_id, pet_skills.filter(func(id): return a.skill_ids.has(id))])
	var want_members: Array = aw.members.map(func(m): return [int(m.id), m.skills.map(func(x): return int(x))])
	var same := true
	for i in want_members.size():
		var g: Array = got_members[i][1].duplicate()
		var w: Array = want_members[i][1].duplicate()
		g.sort()
		w.sort()
		same = same and int(got_members[i][0]) == int(want_members[i][0]) and g == w
	check("war_skills", same and XPets.war_index(s) == int(aw.gtwar) and page.mode == "index", [got_members, want_members])
	check("war_team_a", aw.teamA.all(func(id): return XPets.team_a_skill(int(id))))
	check("war_param_plus", range(8).map(func(i): return XPets.war_param_plus(s, i)) == aw.members[0].plus.map(func(x): return float(x)))
	idx = []
	for i in 3:
		idx.append(XPetScene._t(XPets.pet_name(s, s.pets.list[i]).replace(XPetScene.MUTANT, ""), 6, i * 36.0, 386))
	d = diff(got_form(idx), want_form(aw.index))
	check("war_index_name", d == "", d)
	check("war_again", not XPets.go_to_war(s, 1))
	# 休息
	var rested := XPets.rest(s, 1)
	var cleared := s.members().all(func(a): return pet_skills.all(func(id): return not a.skill_ids.has(id)))
	check("rest", rested and XPets.war_index(s) == -1 and cleared and not XPets.rest(s, 1))
	# 放生第 3 只
	page.select(2)
	page.ok()
	page.cmd = 2
	page.ok()
	check("release", XPets.list(s).size() == int(ref.afterRelease.count) and page.index == int(ref.afterRelease.sel) and page.mode == "index")
	page.cancel()
	await frames()
	# 共享角色：换到 2 号后，出战宠物的 TeamA 技能给第 2 位
	XPets.go_to_war(s, 1)
	XPets.set_team_a(s, 1)
	var team_skills: Array = pet_skills.filter(func(id): return XPets.team_a_skill(int(id)))
	var second := s.actor(int(s.battle_slots[1] if not s.battle_slots.is_empty() else s.party[1]))
	var moved := team_skills.all(func(id): return second.skill_ids.has(id) and not s.actor(1).skill_ids.has(id))
	check("team_a_switch", not team_skills.is_empty() and moved, [team_skills, second.actor_id])
	XPets.rest(s, 1)
	_identity_names(s, ref)
	_create_and_save(s)
	await _entry()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 两只属性相同的宠物仍是不同个体，出战标签只跟随原版 GTWar 对象身份。
func _identity_names(s: XState, ref: Dictionary) -> void:
	var oracle = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pet_identity_oracle.json"))
	var pet: Dictionary = pet_from(ref.pets[0])
	pet.elite = false
	var twin := pet.duplicate(true)
	var old := s.pets
	s.pets = {"list": [pet, twin], "war": 0, "team_a": 0}
	var names := [XPets.pet_name(s, pet), XPets.pet_name(s, twin)]
	check("duplicate_pet_war_name", names == oracle.names, names)
	s.pets.war = 1
	names = [XPets.pet_name(s, pet), XPets.pet_name(s, twin)]
	check("duplicate_pet_war_name_switched", names == oracle.switchedNames, names)
	s.pets = old


func _create_and_save(s: XState) -> void:
	var p := XPets.create(288)
	# 第一项加成在备注 <PetPushAttr> 第一行「a-b」范围内
	var first: Array = XPets._block(XPets.notetags(str(XDB.rec("Enemies", 288).note)), "<PetPushAttr>", "</PetPushAttr>")
	var m := RegEx.create_from_string("(\\d+)-(\\d+)").search(str(first[0]))
	check("create_shape", p.push.size() == 14 and int(p.push[0]) >= int(m.get_string(1)) and int(p.push[0]) <= int(m.get_string(2)) and not p.skills.is_empty()
		and p.lv_skills.has("25") and int(p.ls_max) >= 1 and int(p.ls_max) <= 3 and XPets.level(p) == 1, p)
	check("exp_table", XPets.exp_for_level(1) == 0 and XPets.exp_for_level(7) <= 500 and XPets.exp_for_level(8) > 500)
	XPets.list(s).append(p)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("save_roundtrip", XPets.list(back).size() == XPets.list(s).size() and XPets.pet_name(back, XPets.list(back)[1]) == XPets.pet_name(s, XPets.list(s)[1])
		and float(XPets.list(back)[1].push[8]) == float(XPets.list(s)[1].push[8]))
	var blank := XState.new_game_blank().to_dict()
	blank.erase("pets")
	check("old_save_blank", XPets.list(XState.from_dict(blank)).is_empty())


func _entry() -> void:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	var menu := XMenu.new()
	add_child(menu)
	await frames()
	var i := menu.command_names().find("宠物")
	check("menu_enabled", i >= 0 and menu.command_enabled(i))
	menu._cmd_index = i
	menu._ok()
	check("menu_reserves_ce169", menu.event_state.peek_common_event() == 169, menu.event_state.peek_common_event())
	menu.event_state.clear_common_event()
	menu.queue_free()
	var h := FakeHost.new()
	add_child(h)
	var it := MVInterpreter.new(h, s.map_id, 0, XDB.rec("CommonEvents", 169).list)
	await it.run()
	check("ce169_opens_pets", h.opened == 1 and it.skipped.is_empty(), [h.opened, it.skipped])
	h.queue_free()
	await frames()
