extends Node
## 种族祝福菜单（XRace＋XRaceMenu＋XChoiceWindow）：按正式 race_menu_probe.cjs 的记录逐项比对——新局初值、setDefault／change／upgrade
## 的返回与之后的数据、旧技能推断、开关推断开局默认、暂存箱领取，以及 9 条点选路线的各页说明与选项、提示、结束时的队员数据／开关／背包。
## 生命与法力不比（种族的能力值倍率在战斗规则期二接入，原版换族后最大生命会变）。另查主菜单入口与事件脚本 openMenu／setDefault。

var results := []
var opened_rank := []
const ORACLE := "res://modes/xiyou/generated/oracle/race_menu.json"
const PARTY := [1, 8, 9]


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


static func norm(v):
	if v is int or v is float:
		return float(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	return v


func cfg() -> Dictionary:
	return XRace.config()


func _state() -> XState:
	var s := XState.new_game_blank()
	s.items = {}
	for id in PARTY:
		s.add_actor(id)
	return s


func _bag(s: XState) -> Dictionary:
	var bag := {}
	for k in s.items:
		if int(s.items[k]) > 0:
			bag[str(k)] = float(s.items[k])
	return bag


## 与探针 after() 同口径（不含生命、法力）
func _after(s: XState) -> Dictionary:
	var ms := []
	for a in s.members():
		var d := XRace.data(s, a)
		ms.append({"id": float(a.actor_id), "race": norm(d), "raceSkills": norm(a.skill_ids.filter(func(id): return not XRace.skill_info(id).is_empty())), "label": XRace.label(s, a)})
	var sw := [281, 282, 283, 284, 285, 286, 287].map(func(id): return s.switch(id))
	var dr := XRace.default_race(s)
	return {"members": ms, "switches": sw, "default": null if dr < 0 else float(dr), "bag": _bag(s)}


func _probe_after(p: Dictionary) -> Dictionary:
	var ms := []
	for m in p.members:
		ms.append({"id": float(m.id), "race": norm(m.race), "raceSkills": norm(m.raceSkills), "label": m.label})
	return {"members": ms, "switches": p.switches, "default": null if p.default == null else float(p.default), "bag": norm(p.bag)}


func _strip_race_skills(a: XActor, extra: Array) -> void:
	var kept: Array[int] = []
	for id in a.skill_ids:
		if XRace.skill_info(id).is_empty():
			kept.append(id)
	for id in extra:
		kept.append(int(id))
	a.skill_ids = kept


func _run() -> void:
	var o = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("oracle_loaded", o is Dictionary, ORACLE):
		_finish()
		return
	_fresh(o.fresh)
	_calls(o.calls)
	_migrate(o.migrate)
	_inbox(o.inbox)
	for p in o.pages:
		await _flow(p)
	_menu_entry()
	await _script()
	_finish()


func _fresh(f: Dictionary) -> void:
	var s := _state()
	check("fresh", _after(s) == _probe_after(f), [_after(s), _probe_after(f)])


func _calls(rows: Array) -> void:
	var s := _state()
	var m := s.members()
	var a: XActor = m[0]
	var b: XActor = m[1]
	var toast0 := XToast.shown.size()
	var got := {}
	got["change-before-default"] = XRace.change(s, a, 3)
	got["change-before-default@"] = _after(s)
	got["setDefault-9"] = XRace.set_default(s, 9)
	got["setDefault-2"] = XRace.set_default(s, 2)
	got["setDefault-2@"] = _after(s)
	got["setDefault-2#"] = XToast.shown.slice(toast0)
	got["change-same"] = XRace.change(s, b, 2)
	got["change-free"] = XRace.change(s, b, 4)
	got["change-free@"] = _after(s)
	got["change-no-water"] = XRace.change(s, b, 5)
	s.gain_item(int(cfg().water), 2)
	got["change-water"] = XRace.change(s, b, 5)
	got["change-water@"] = _after(s)
	got["upgrade-rank3"] = XRace.upgrade(s, b, 3)
	got["upgrade-no-stone"] = XRace.upgrade(s, b, 2)
	s.gain_item(int(cfg().stones[0]), 1)
	s.gain_item(int(cfg().stones[1]), 1)
	got["upgrade-2"] = XRace.upgrade(s, b, 2)
	got["upgrade-2@"] = _after(s)
	got["upgrade-3"] = XRace.upgrade(s, b, 3)
	got["upgrade-3@"] = _after(s)
	got["upgrade-8"] = XRace.upgrade(s, b, 8)
	got["change-not-member"] = XRace.change(s, s.actor(2), 1)
	for r in rows:
		var k := str(r.step)
		check("call_" + k, norm(got.get(k)) == norm(r.result), [got.get(k), r.result])
		if r.has("members"):
			check("call_" + k + "_after", got.get(k + "@") == _probe_after(r), [got.get(k + "@"), _probe_after(r)])
		if r.has("toasts"):
			check("call_" + k + "_toasts", got.get(k + "#") == r.toasts, [got.get(k + "#"), r.toasts])


func _migrate(rows: Array) -> void:
	for r in rows:
		var s := _state()
		if str(r.name) == "switch-283":
			s.set_switch(283, true)
			XRace.migrate(s)
			check("migrate_switch-283", float(XRace.default_race(s)) == float(r.default), XRace.default_race(s))
			continue
		var a: XActor = s.members()[0]
		XRace.state(s).actors.erase(str(a.actor_id))
		_strip_race_skills(a, r.skills)
		XRace.state(s).default = -1
		XRace.migrate(s)
		check("migrate_" + str(r.name), _after(s) == _probe_after(r), [_after(s), _probe_after(r)])


func _inbox(rows: Array) -> void:
	var s := _state()
	s.race_supply = {"counts": {}, "first": {}, "inbox": {str(int(cfg().stones[2])): 3, str(int(cfg().stones[0])): 2}}
	s.gain_item(int(cfg().stones[2]), 9998)
	XRace.claim_inbox(s)
	check("inbox", _after(s) == _probe_after(rows[0]) and norm(s.race_supply) == norm(rows[0].supply), [_after(s), s.race_supply, rows[0].supply])


func _prep(name: String, s: XState) -> void:
	var a: XActor = s.members()[0]
	match name:
		"change-water":
			XRace.set_default(s, 0)
			XRace.data(s, a).free = false
		"change-water-ok":
			XRace.set_default(s, 0)
			XRace.data(s, a).free = false
			s.gain_item(int(cfg().water), 1)
		"upgrade":
			XRace.set_default(s, 5)
			s.gain_item(int(cfg().stones[0]), 1)
		"rank3":
			XRace.set_default(s, 6)
			s.gain_item(int(cfg().stones[1]), 1)
		"legacy-multi":
			XRace.set_default(s, 1)
			XRace.state(s).actors.erase(str(a.actor_id))
			_strip_race_skills(a, [3210, 3657])
		"inbox":
			XRace.set_default(s, 3)
			s.race_supply = {"counts": {}, "first": {}, "inbox": {str(int(cfg().stones[0])): 2}}


func _flow(p: Dictionary) -> void:
	var name := str(p.name)
	var s := _state()
	_prep(name, s)
	var toast0 := XToast.shown.size()
	var menu := XRaceMenu.new()
	if p.options is Dictionary:
		menu.rank = int(p.options.rank)
	var closed := [false]
	menu.closed.connect(func(): closed[0] = true)
	add_child(menu)
	await frames()
	var missing := ""
	for step in p.steps:
		var st := str(step)
		if st == "<":
			menu.choice.cancel()
			continue
		var i := int(st.substr(1)) if st.begins_with("@") else menu.choice.rows.find_custom(func(r): return str(r.label) == st)
		if i < 0 or i >= menu.choice.rows.size():
			missing = st
			break
		menu.choice.index = i
		menu.choice.ok()
	var want: Array = p.screens.filter(func(x): return not x.has("popped"))
	var popped: bool = p.screens.any(func(x): return x.has("popped"))
	var bad := []
	for i in range(maxi(want.size(), menu.log.size())):
		var g = menu.log[i] if i < menu.log.size() else null
		var w = want[i] if i < want.size() else null
		if norm(g) != norm(w):
			bad.append([i, g, w])
			break
	check("pages_" + name, missing == "" and bad.is_empty(), [missing, bad])
	check("closed_" + name, closed[0] == popped)
	check("toasts_" + name, XToast.shown.slice(toast0) == p.toasts, [XToast.shown.slice(toast0), p.toasts])
	check("after_" + name, _after(s) == _probe_after(p), [_after(s), _probe_after(p)])
	menu.queue_free()
	await frames()


func _menu_entry() -> void:
	var cmd: Array = XMenu.COMMANDS.filter(func(c): return c[1] == "race")
	check("menu_race_enabled", cmd.size() == 1 and cmd[0][2] == true)


## 测试宿主：事件脚本打开种族祝福时记下目标阶
func open_race_menu(rank := 0) -> void:
	opened_rank.append(rank)


func toast(_text: String) -> void:
	pass


func _script() -> void:
	var s := _state()
	var left: Array = await MVScript.run("CodexRaces.openMenu();", MVInterpreter.new(self, 4, 22, []))
	left += await MVScript.run("CodexRaces.openMenu({rank:3});", MVInterpreter.new(self, 0, 0, []))
	left += await MVScript.run("CodexRaces.setDefault(4);", MVInterpreter.new(self, 0, 0, []))
	check("script_open", left.is_empty() and opened_rank == [0, 3], [left, opened_rank])
	check("script_default", XRace.default_race(s) == 4 and s.switch(286) and not s.switch(285)
		and s.members().all(func(a): return int(XRace.data(s, a).race) == 4))


func _finish() -> void:
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
