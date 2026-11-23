extends Node
## 效果型公共事件脚本对照（八戒 2026-10-27）：mv_oracle/common_script_probe.cjs（generated/oracle/common_scripts.json）的每一例，
## 以同样的前提（选中角色与已学技能、变量、开关、物品、所在格、藏宝图预掷池与已挖宝点、更衣解锁表、随机数）在 MVInterpreter 上跑同一公共事件，
## 逐项比较提示／场景、关心的变量与物品数、选中角色的技能、队伍、预约公共事件、预掷池用量、已挖宝点、更衣解锁。
## 覆盖：遗忘技能类（CE637～648、1378～1380、83）、藏宝图（CE117、174～189、1381～1384）、超强者招募（CE2501～2526）、CE367。
## 宿主用事件对照的记录替身（tests/xiyou_event_compare.gd 的 EventHost）。

const ORACLE := "res://modes/xiyou/generated/oracle/common_scripts.json"
const EC := preload("res://tests/xiyou_event_compare.gd")
const PARTY := [1, 8, 9, 10]

var results: Array = []


class GiftHost extends EC.EventHost:
	func erase_event(id: int) -> void:
		XState.current.erased_events.append(id)


func _ready() -> void:
	# 参照是原版文字：原版文字错的加载时修正（XTextFix，cc/text-fix-b）比对时整组关掉；修正本身由 tests/xiyou_text_fix 核
	XTextFix.set_all(false)
	XCanglong.original_data()  # 按原版比：漩涡二阶段、苍龙重做与解放（优化登记三条）关掉，新行为由 xiyou_rift2_canglong 核
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	GameApp.fast_headless_frames()
	XSave.dir_override = "user://test_xiyou_common_scripts"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	_check("oracle_loaded", oracle is Dictionary and oracle.get("cases", []).size() > 150)
	if not oracle is Dictionary:
		_finish()
		return
	_check("oracle_no_errors", oracle.cases.all(func(c): return c.errors.is_empty()), oracle.cases.filter(func(c): return not c.errors.is_empty()).map(func(c): return c.id))
	var host = EC.EventHost.new()
	add_child(host)
	var kinds := {}
	for c in oracle.cases:
		if not c.errors.is_empty():
			continue
		var got := await _case(c.setup, host)
		var want: Dictionary = c.observed
		var diffs := []
		for k in want:
			if JSON.stringify(_norm(want[k])) != JSON.stringify(_norm(got.get(k))):
				diffs.append([k, want[k], got.get(k)])
		var kind := str(c.id).get_slice(".", 0)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		_check(str(c.id), diffs.is_empty(), diffs)
	print("COMMON_SCRIPTS ", JSON.stringify(kinds))
	XConfig.clothes_unlocked().clear()
	await _crow_blueprints(host)
	await _chentang_gift()
	_finish()


func _crow_blueprints(host: EC.EventHost) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	for pair in [[1761, 710, 198, "五眼乌鸦", "六眼乌鸦"], [1762, 711, 199, "七眼乌鸦", "九眼乌鸦"]]:
		var recipe := XCrafting.recipe(pair[2])
		var product := XCrafting.item_of(recipe.result)
		_check("crow.name." + pair[3], str(product.name).ends_with(pair[3]) and XDB.rec("Items", pair[0]).name == "配方:" + pair[3])
		host.trace.clear()
		var ce := XDB.rec("CommonEvents", pair[1])
		await MVInterpreter.new(host, s.map_id, 0, ce.list).run()
		_check("crow.learn." + pair[3], XCrafting.known(s, recipe) and host.trace.any(
			func(e): return e.t == "toast" and str(e.text).contains(pair[3]) and not str(e.text).contains(pair[4])), host.trace)
		XDB.CROW_BLUEPRINT_NAMES = false
		_check("crow.rollback." + pair[3], XDB.rec("Items", pair[0]).name == "配方:" + pair[4] and XDB.rec("CommonEvents", pair[1]).name == pair[4])
		XDB.CROW_BLUEPRINT_NAMES = true
		s.flags.tianqi = {"rules": 1}
		_check("crow.tianqi." + pair[3], XDB.rec("Items", pair[0]).name == "配方:" + pair[4] and XDB.rec("CommonEvents", pair[1]).name == pair[4])
		s.flags.erase("tianqi")


func _chentang_gift() -> void:
	var host := GiftHost.new()
	add_child(host)
	var m := XDB.map(169)
	var commands: Array = m.events[9].pages[0].list
	for spec in [
		{"name": "gift", "water": 1, "pick": 0, "result": true},
		{"name": "missing_water", "water": 0, "pick": 0, "result": false},
		{"name": "look", "water": 1, "pick": 2, "result": false},
		{"name": "boss_defeated", "water": 1, "pick": 0, "result": false},
		{"name": "rollback", "water": 1, "pick": 0, "result": false},
		{"name": "tianqi", "water": 1, "pick": 0, "result": false},
	]:
		var s := XState.new_game_blank()
		XState.current = s
		s.map_id = 169
		s.x = 11
		s.y = 21
		s.gain_item(912, spec.water)
		s.set_switch(247, spec.name == "boss_defeated")
		if spec.name == "tianqi":
			s.flags.tianqi = {"rules": 1}
		MVInterpreter.CHENTANG_GIFT_TRANSFER = spec.name != "rollback"
		host.trace.clear()
		host.answers = [spec.pick]
		await MVInterpreter.new(host, 169, 9, commands).run()
		var moves := host.trace.filter(func(e): return e.t == "transfer")
		var sent: bool = spec.result
		_check("chentang." + spec.name, moves.size() == int(sent) and s.map_id == 169 \
			and (Vector2i(s.x, s.y) == Vector2i(m.events[1].x, m.events[1].y + 1) and s.direction == 8 if sent else Vector2i(s.x, s.y) == Vector2i(11, 21)), host.trace)
		if sent:
			_check("chentang.gift_preserved", s.item_count(912) == 0 and s.erased_events.has(9) and s.variable(246) == 4 and s.variable(364) == 1)
	MVInterpreter.CHENTANG_GIFT_TRANSFER = true
	host.queue_free()


static func _norm(v):
	if v == null:
		return null
	# 挖宝提示（XTreasureMap）文字审批 18 把「获得物品:」「目标位置:」等的半角冒号改全角：两边都换成全角再比
	return JSON.parse_string(RegEx.create_from_string("(获得物品|获得防具|获得武器|触发事件|目标位置|坐标|失败): ?").sub(JSON.stringify(v), "$1：", true))


func _case(spec: Dictionary, host) -> Dictionary:
	var s := XState.new_game_blank()
	s.difficulty = int(spec.get("difficulty", 3))
	for id in PARTY:
		s.add_actor(id)
	s.map_id = 4
	s.x = 0  # 参照新局玩家在大厅 (0,0)
	s.y = 0
	XState.current = s
	XDungeon.battle = {}
	var lite := XConfig.clothes_unlocked()
	lite.clear()
	for id in spec.get("clothes", []):
		lite.append(int(id))
	if spec.has("target"):
		var a := s.actor(int(spec.target))
		for id in spec.get("learn", []):
			a.learn_skill(int(id))
		s.item_target_actor_id = int(spec.target)
	for k in spec.get("vars", {}):
		s.set_variable(int(k), float(spec.vars[k]))
	for k in spec.get("gainItems", {}):
		s.gain_item(int(k), int(spec.gainItems[k]))
	for k in spec.get("gainWeapons", {}):
		s.gain_gear("weapon", int(k), int(spec.gainWeapons[k]))
	for k in spec.get("gainArmors", {}):
		s.gain_gear("armor", int(k), int(spec.gainArmors[k]))
	for id in spec.get("switches", []):
		s.set_switch(int(id), true)
	# 预先入队的角色与等级（参照开关之后 addActor＋changeLevel）；参照的 sync（并入备注超强者）重制总是生效，不用做
	for pair in spec.get("actors", []):
		s.add_actor(int(pair[0]))
		if int(pair[1]) > 0:
			s.actor(int(pair[0])).change_level_mv(int(pair[1]))
	if spec.has("at"):
		s.map_id = int(spec.at[0])
		s.x = int(spec.at[1])
		s.y = int(spec.at[2])
	if spec.has("rom"):
		s.rom.g = spec.rom.map(func(v): return int(v))
		s.rom.gn = int(spec.get("romNum", 0))
	if spec.has("dug"):
		s.rom.m = spec.dug.map(func(v): return int(v))
	host.trace = []
	host.seen = {}
	MVInterpreter.fixed_random = float(spec.get("random", 0.5))
	MVInterpreter.max_steps = 20000
	MVInterpreter.steps = 0
	MVInterpreter.aborted = false
	var interp := MVInterpreter.new(host, s.map_id, 0, XDB.rec("CommonEvents", int(spec.common)).get("list", []).duplicate(true))
	await interp.run()
	var watch: Dictionary = spec.get("watch", {})
	var a: XActor = s.actor(int(spec.target)) if spec.has("target") else null
	return {
		"trace": host.trace.map(_trace_row),
		"variables": watch.get("vars", []).map(func(id): return s.variable(int(id))),
		"items": watch.get("items", []).map(func(id): return s.item_count(int(id))),
		"weapons": watch.get("weapons", []).map(func(id): return s.gear_count("weapon", int(id))),
		"armors": watch.get("armors", []).map(func(id): return s.gear_count("armor", int(id))),
		"skills": watch.get("skills", []).filter(func(id): return a != null and a.skill_ids.has(int(id))),
		"party": s.party.duplicate(),
		"reserved": s.peek_common_event(),
		"romGetNum": int(s.rom.get("gn", 0)),
		"dug": _sorted(s.rom.get("m", [])),
		"clothes": watch.get("clothes", []).filter(func(id): return XChangeClothes.unlocked(int(id))),
	}


## 文字只比行与选项（探针不记脸图）
static func _trace_row(e: Dictionary) -> Dictionary:
	if str(e.t) != "msg":
		return e.duplicate(true)
	var out := {"t": "msg", "lines": e.lines.duplicate()}
	if e.has("choices"):
		out.choices = e.choices.duplicate()
		out.pick = e.pick
	return out


static func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


func _finish() -> void:
	MVInterpreter.fixed_random = -1.0
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
