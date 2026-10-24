extends Node
## 超强者出战限制（installBossDifficultyRuntime 的 D.enforceParty）：逐步对照冻结 v0.28 参照 tests/fixtures/super_deploy_oracle.json
## （mv_oracle/super_deploy_probe.cjs：三霄清出与补替补、替补不够、开关与混沌难度、加入已持有的超强者、MyGO／镜流（强者）不受限、读档）。
## - <场景>.<步>：每步比出战栏（取出战成员之前）、队伍顺序、出战成员、是否放行、名单每人能否编入（canDeploy／actorIsEnabled／
##   isCurrentItemEnabled 三项在重制都是 XItemMarks.can_deploy）、本步弹出的提示（XToast.shown）。
## - page.*：整队页开页先清并提示；名单里超强者确定蜂鸣、出战栏不变；普通角色照常编入。
const FIXTURE := "res://tests/fixtures/super_deploy_oracle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _ready() -> void:
	XConfig.path_override = ""
	_run.call_deferred()


func _ints(a: Array) -> Array:
	return a.map(func(v): return int(v))


func _set_party(s: XState, actors: Array, battle: Array) -> void:
	# 同参照：直接写字段，不经包装
	s.party.assign(_ints(actors))
	var slots := _ints(battle)
	while slots.size() < XState.MAX_BATTLE_MEMBERS:
		slots.append(0)
	s.battle_slots = slots
	for id in s.party:
		s.actor(id)


## 同参照宿主 newGame：初始难度（Vitsuno 初始 2）、队伍 1／8／9／10
func _fresh() -> XState:
	var s := XState.new_game_blank()
	for sw in XItemMarks.SUPER_SWITCHES:
		s.set_switch(sw, false)
	s.party.clear()
	s.battle_slots = []
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	XItemMarks._deploy_notice = null
	XState.current = s
	return s


func _do(s: XState, st: Dictionary) -> XState:
	match str(st.do):
		"party":
			_set_party(s, st.actors, st.battle)
		"members":
			s.battle_members()
		"flush":
			XItemMarks.flush_deploy_notice(s)
		"rearrange":
			s.rearrange_actors()
		"add":
			s.add_actor(int(st.id))
		"remove":
			s.remove_actor(int(st.id))
		"init":
			s.init_battle_slots()
		"switch":
			s.set_switch(int(st.id), bool(st.on))
		"difficulty":
			s.difficulty = int(st.id)
		"partyStart":
			XItemMarks.deploy_start(s)
		"load":
			_set_party(s, st.actors, st.battle)
			var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
			XState.current = loaded
			loaded.battle_members()
			XItemMarks.flush_deploy_notice(loaded)  # 读档后回地图＝Scene_Map.start
			return loaded
	return s


func _row(s: XState, toasts: Array) -> Dictionary:
	var slots := _ints(s.battle_slots)
	var party := _ints(Array(s.party))
	var list := {}
	for id in party:
		var ok := XItemMarks.can_deploy(s, id)
		list[str(id)] = [ok, ok, ok]
	return {"slots": slots, "actors": party, "members": s.battle_members().map(func(a): return a.actor_id),
		"enabled": XItemMarks.super_enabled(s), "list": list, "toasts": toasts}


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("fixture", ref is Dictionary and ref.cases.size() == 6)
	for c in ref.cases:
		check("%s.errors" % c.id, c.errors.is_empty(), c.errors)
		var s := _fresh()
		for i in c.observed.rows.size():
			var want: Dictionary = c.observed.rows[i]
			var before := XToast.shown.size()
			s = _do(s, c.setup.steps[i])
			var got := _row(s, XToast.shown.slice(before))
			var exp := {"slots": _ints(want.slots), "actors": _ints(want.actors), "members": _ints(want.members), "enabled": want.enabled,
				"list": want.list, "toasts": want.toasts}
			check("%s.%d.%s" % [c.id, i, want.do], JSON.stringify(got) == JSON.stringify(exp), {"got": got, "want": exp})
	await _page()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _page() -> void:
	var s := _fresh()
	_set_party(s, [1, 100, 101, 8, 9], [100, 1, 101, 0, 8])
	var before := XToast.shown.size()
	var page := XPartyScene.new()
	add_child(page)
	await get_tree().process_frame
	check("page.start_enforced", _ints(s.battle_slots) == [9, 1, 0, 0, 8] and XToast.shown.slice(before) == [XItemMarks.DEPLOY_NOTICE],
		[s.battle_slots, XToast.shown.slice(before)])
	# 整队 → 第 0 格 → 名单选三霄 100（名单：0、出战 9 1 8、其余按编号 100 101、0）
	page.ok()
	page.ok()
	page.list_index = page.list_data().find(100)
	XSound.system_log.clear()
	page.ok()
	check("page.super_buzzer", XSound.system_log == [3] and _ints(s.battle_slots) == [9, 1, 0, 0, 8] and page.mode == "list",
		[XSound.system_log, s.battle_slots, page.mode])
	page.list_index = page.list_data().find(1)
	XSound.system_log.clear()
	page.ok()
	check("page.normal_ok", XSound.system_log == [1, 4] and _ints(s.battle_slots) == [1, 9, 0, 0, 8] and page.mode == "slot",
		[XSound.system_log, s.battle_slots, page.mode])
	page.queue_free()
