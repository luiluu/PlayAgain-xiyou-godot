extends Node
## 【cc·悟空·未经审查】角色说明卡动态行（chars-gaps2），参照 mv_oracle/character_help_dyn_probe.cjs（v0.62.12）：
## - listCosts：技能页／战斗里（XHelpCard.list_costs，show_for 按卡所在场景设）说明卡不列消耗行；
## - dyn2：云裳 174（目标、段数、成长倍率、爆伤终伤）、镜流 170（已解锁星魂、寒川映月上限）、宿傩 10242 斩击强化。
## 角色照参照记下的等级、技能表（10122～10299）、进阶次数摆；只比去色后以「成长／目标／段数／消耗」开头的行。
## 两边都去掉并排的「；伤害属性：…」段：参照直接调 characterHelpView（伤害属性行来自备注），重制走 content（伤害属性行由元素包装插，字号不同不并排），
## 这一处是量法不同，伤害属性行的并排由 xiyou_help_card 走真卡路径管。
const FIXTURE := "res://tests/fixtures/character_help_dyn_oracle.json"
const PICK := "^(?:成长|目标|段数|消耗|基础(?:MP|TP)?消耗|MP消耗|TP消耗)"
var total := 0
var passed := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _pick(item: Dictionary) -> Array:
	XHelpCard.LAYOUT_V043 = false  # 参照量的是 characterHelpView，v0.43 排版之前
	var rows := XHelpCard.content(item)
	XHelpCard.LAYOUT_V043 = true
	var re := RegEx.create_from_string(PICK)
	return _norm(rows.map(func(r): return XHelpCard.plain(str(r[0]))).filter(func(t): return re.search(t) != null))


static func _norm(list: Array) -> Array:
	var re := RegEx.create_from_string("；伤害属性：[^；]*")
	return list.map(func(t): return re.sub(str(t), "", true))


func _setup(c: Dictionary) -> XState:
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var o: Dictionary = c.observed
	var id := int(c.setup.actor)
	if o.get("skills") == null or c.setup.get("unrecruited", false):
		s.actors.erase(id)  # 预览替身／没招募（chars-gaps3：原版新局已建好全部角色，卡用初始角色）
		return s
	var a := s.actor(id)
	a.change_level_mv(int(o.level))
	s.actor_advance[id] = int(o.rank)
	var want: Array = o.skills.map(func(v): return int(v))
	for sid in a.skill_ids.duplicate():
		if sid >= 10122 and sid <= 10299 and not want.has(sid):
			a.forget_skill(sid)
	for sid in want:
		a.learn_skill(sid)
	a.refresh_passive()
	a.recover_all()
	if c.setup.has("emp"):
		XSukuna._temp[a] = {"emp": int(c.setup.emp), "domain": 1 if c.setup.domain else 0}
		if c.setup.awake:
			a.state_ids.append(XSukuna.AWAKE)
		if c.setup.domain:
			a.state_ids.append(XSukuna.DOMAIN)
	return s


func _ready() -> void:
	XConfig.path_override = "user://xiyou_character_help_dyn_none.json"  # 不读本机设置
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("cases", ref.cases.size() == 28, ref.cases.size())
	for c in ref.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		var s := _setup(c)
		var a = s.actors.get(int(c.setup.actor))
		if a != null:
			check(c.id + ".level", int(a.level) == int(c.observed.level), [a.level, c.observed.level])
		if c.setup.get("unrecruited", false):  # 不入档的初始角色：等级、专属技能表同原版新局，且不写进 actors
			var g = XCharacterHelp.actor(XDB.rec("Skills", int(c.observed.rows.keys()[0])))
			var own := []
			if g != null:
				own = g.skill_ids.filter(func(v): return v >= 10122 and v <= 10299)
				own.sort()
			check(c.id + ".ghost", g != null and int(g.level) == int(c.observed.level) and JSON.stringify(own) == JSON.stringify(c.observed.skills.map(func(v): return int(v))), [g.level if g != null else null, own, c.observed.skills])
			check(c.id + ".not_saved", not s.actors.has(int(c.setup.actor)))
		XHelpCard.list_costs = bool(c.setup.get("listCosts", false))
		XCharacterHelp.UNRECRUITED_AS_NEW_GAME = not c.setup.get("preview", false)  # 替身预览只在开关关掉时走得到
		for sid in c.observed.rows:
			var got := _pick(XDB.rec("Skills", int(sid)))
			check(c.id + "." + sid, JSON.stringify(got) == JSON.stringify(_norm(c.observed.rows[sid])), [got, c.observed.rows[sid]])
		XHelpCard.list_costs = false
		XSukuna._temp.clear()
		XCharacterHelp.UNRECRUITED_AS_NEW_GAME = true
	# show_for 按卡所在场景定 listCosts：祖先是技能页或战斗画面为真，别处（装备页等）为假，出完卡还原
	for pair in [[XSkillScene.new(), true], [XBattleScene.new(), true], [Control.new(), false]]:
		var host: Node = pair[0]
		var card := XHelpCard.new()
		var mid := Control.new()
		host.add_child(mid)
		mid.add_child(card)
		check("scene." + host.get_class() + str(pair[1]), card._list_costs_scene() == pair[1])
		host.free()
	var s2 := XState.new_game_blank()
	XState.current = s2
	var card2 := XHelpCard.new()
	var sk := XSkillScene.new()
	sk.add_child(card2)
	var a167 := s2.actor(167)
	a167.change_level_mv(10)
	card2.show_for(XDB.rec("Skills", 10122))
	var texts: Array = card2.rows.map(func(r): return XHelpCard.plain(str(r[0])))
	check("show_for.skill_scene_hides_cost", not texts.any(func(t): return str(t).contains("消耗：")), texts)
	check("show_for.reset", XHelpCard.list_costs == false)
	sk.free()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
