extends Node
## 事件「更改名字／职业／角色图像／称号」（320／321／322／324，MVEventCore）对照冻结 v0.28 参照
## tests/fixtures/actor_change_oracle.json（mv_oracle/actor_change_probe.cjs）：
## 招募公共事件 29／125／153／1209／1575 后的名字、称号、职业、等级、经验、图像与 mhp；绿司机戴帽、脱帽（689／690）；
## 大厅「更改形象」460～463 把改乱的图像改回；狗逍遥 10 级来回换职业（保留与不保留经验）。
## 增减 HP／MP／TP（311／312／326）与公共事件 46 一掷千金、624 快捷回血。
## 另有不靠参照的：存档往返、地图上 322 后队首行走图跟着换、\N[n] 用改过的名字、数据库记录不被改动。

const FIXTURE := "res://tests/fixtures/actor_change_oracle.json"
const FIELDS := ["name", "nickname", "classId", "level", "exp", "characterName", "characterIndex", "faceName", "faceIndex", "battlerName", "mhp"]
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _case(data: Dictionary, id: String) -> Dictionary:
	for c in data.cases:
		if c.id == id:
			return c.observed if c.observed is Dictionary else {}
	return {}


func _state() -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	s.battle_slots = []
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	return s


static func _look(a: XActor) -> Dictionary:
	var d := a.data()
	return {"name": a.display_name(), "nickname": a.nickname, "classId": float(a.class_id), "level": float(a.level), "exp": float(a.exp_total),
		"characterName": str(d.characterName), "characterIndex": float(d.characterIndex), "faceName": str(d.faceName),
		"faceIndex": float(d.faceIndex), "battlerName": str(d.battlerName), "mhp": float(roundf(a.mhp))}


static func _want(r: Dictionary) -> Dictionary:
	var out := {}
	for k in FIELDS:
		out[k] = float(r[k]) if r[k] is float or r[k] is int else str(r[k])
	return out


func _run_list(list: Array) -> void:
	var frame := MVEventCore.new()
	frame.list = list
	for i in range(50):
		var r := frame.advance()
		if r.kind == "done":
			break
		if r.kind == "message":
			frame.waiting_frame().resume(0)


func _ce(id: int) -> void:
	_run_list([{"code": 117, "indent": 0, "parameters": [id]}])


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	if not check("oracle_loaded", data is Dictionary and data.get("cases", []).size() == 5 and data.cases.all(func(c): return c.errors.is_empty()), FIXTURE):
		_finish()
		return
	_recruit(_case(data, "recruit"))
	_hat(_case(data, "hat"))
	_reset(_case(data, "reset"))
	_change_class(_case(data, "changeClass"))
	_resources(_case(data, "resources"))
	_synthetic()
	_finish()


## ① 招募公共事件：改名、改称号、改职业（玛莎 16→21，mhp 跟着变）、改图像
func _recruit(o: Dictionary) -> void:
	var s := _state()
	for r in o.rows:
		var a := s.actor(int(r.after.actor))
		check("recruit_%d_before" % int(r.event), _look(a) == _want(r.before), [_look(a), r.before])
		_ce(int(r.event))
		check("recruit_%d_after" % int(r.event), _look(a) == _want(r.after), [_look(a), r.after])
		check("recruit_%d_party" % int(r.event), Array(s.party).map(func(v): return float(v)) == r.party, [s.party, r.party])


## ② 戴帽子／脱帽子：技能与三项图像来回换
func _hat(o: Dictionary) -> void:
	var s := _state()
	var a := s.actor(2)
	for r in o.rows:
		if str(r.step) != "init":
			_ce(int(r.step))
		var skills := a.skill_ids.filter(func(id): return id >= 3790 and id <= 3793).map(func(v): return float(v))
		check("hat_%s" % str(r.step), _look(a) == _want(r.look) and skills == r.skills, [_look(a), r.look, skills, r.skills])


## ③ 先把 1～4 号改乱，再跑 460～463：1～93 号都是数据库（或事件写的）图像
func _reset(o: Dictionary) -> void:
	var s := _state()
	_run_list([1, 2, 3, 4].map(func(id): return {"code": 322, "indent": 0, "parameters": [id, "Actor1", 3, "Actor1", 3, "Actor1_4"]}))
	var mixed := [1, 2, 3, 4].map(func(id): return _look(s.actor(id)))
	check("reset_mixed", mixed == o.mixed.map(func(r): return _want(r)), [mixed, o.mixed])
	for id in [460, 461, 462, 463]:
		_ce(id)
	var bad := []
	for r in o.rows:
		if int(r.actor) == 93 and MVEventCore.ACTOR_IMAGE_FIX.has("463:93"):
			continue
		var got := _look(s.actor(int(r.actor)))
		if got != _want(r):
			bad.append([got, r])
	check("reset_rows", bad.is_empty() and o.rows.size() >= 80, [o.rows.size(), bad.slice(0, 3)])
	# 原版 93 号被写成天虎令的图像；O-100 改写给 104 号：93 号保持数据库，104 号是天虎令自己的图像
	var r93: Dictionary = o.rows.filter(func(r): return int(r.actor) == 93)[0]
	var db93 := XDB.rec("Actors", 93)
	var t := _look(s.actor(104))
	check("reset_fix_93_104", str(r93.characterName) == "tianhuling-c" and _look(s.actor(93)).characterName == str(db93.characterName)
		and t.characterName == "tianhuling-c" and t.faceName == "face" and t.battlerName == "tianhuling-s", [r93, _look(s.actor(93)), t])


## ④ 10 级换职业：不保留经验降到 1 级，换回原职业取回原经验；保留经验时新职业取当前经验
func _change_class(o: Dictionary) -> void:
	var s := _state()
	var a := s.actor(1)
	a.change_level_mv(int(o.rows[0].level))
	for r in o.rows:
		if str(r.step) != "init":
			var parts := str(r.step).split("_")
			_run_list([{"code": 321, "indent": 0, "parameters": [1, int(parts[0]), parts[1] == "keep"]}])
		check("class_%s" % str(r.step), _look(a) == _want(r) and a.skill_ids.size() == int(r.skills), [_look(a), r, a.skill_ids.size()])


## ⑤ 311／312／326：不允许死亡最多扣到 1、允许时倒下、倒下后不加；变量操作数、全队；一掷千金、快捷回血
func _resources(o: Dictionary) -> void:
	var s := _state()
	s.actor(1).hp = 100.0
	s.actor(8).mp = 5.0
	s.actor(8).tp = 10.0
	var steps := {
		"hp_minus_nodeath": [{"code": 311, "indent": 0, "parameters": [0, 1, 1, 0, 3000, false]}],
		"mp_minus_floor": [{"code": 312, "indent": 0, "parameters": [0, 8, 1, 0, 50]}],
		"tp_plus": [{"code": 326, "indent": 0, "parameters": [0, 0, 0, 0, 20]}],
		"tp_over_cap": [{"code": 326, "indent": 0, "parameters": [0, 8, 0, 0, 500]}],
		"hp_minus_death": [{"code": 311, "indent": 0, "parameters": [0, 1, 1, 0, 3000, true]}],
		"hp_plus_dead": [{"code": 311, "indent": 0, "parameters": [0, 1, 0, 0, 500, false]}],
		"hp_var_all": [{"code": 122, "indent": 0, "parameters": [317, 317, 0, 0, 77]}, {"code": 311, "indent": 0, "parameters": [0, 0, 1, 1, 317, false]}],
		"mp_var_actor_var": [{"code": 122, "indent": 0, "parameters": [318, 318, 0, 0, 9]}, {"code": 312, "indent": 0, "parameters": [1, 318, 0, 1, 317]}],
	}
	for r in o.rows:
		var step := str(r.step)
		if steps.has(step):
			_run_list(steps[step])
		elif step == "ce46_poor":
			s.gold = 100
			_ce(46)
		elif step == "ce624":
			s.gain_item(793, 1)
			_ce(624)
		var got := s.members().map(func(a): return {"actor": float(a.actor_id), "hp": roundf(a.hp), "mp": roundf(a.mp), "tp": roundf(a.tp),
			"mhp": roundf(a.mhp), "mmp": roundf(a.mmp), "dead": a.is_dead()})
		check("res_%s" % step, got == r.actors and float(s.gold) == float(r.gold), [got, r.actors, s.gold, r.gold])


## 不靠参照：存档往返；数据库记录原样；\N[n]、地图队首行走图读改过的值；不存在的角色／职业不出错
func _synthetic() -> void:
	var s := _state()
	var a := s.actor(1)
	a.change_level_mv(5)
	_run_list([
		{"code": 320, "indent": 0, "parameters": [1, "新名字"]},
		{"code": 324, "indent": 0, "parameters": [1, "新称号"]},
		{"code": 321, "indent": 0, "parameters": [1, 2, false]},
		{"code": 322, "indent": 0, "parameters": [1, "Actor2", 4, "Actor2", 5, "Actor2_6"]},
		{"code": 320, "indent": 0, "parameters": [99999, "无"]},
		{"code": 321, "indent": 0, "parameters": [1, 99999, true]},
	])
	var before := _look(a)
	var db := XDB.rec("Actors", 1)
	check("db_untouched", str(db.name) == "狗逍遥" and str(db.faceName) != "Actor2", [db.name, db.faceName])
	check("synthetic_applied", before.name == "新名字" and before.nickname == "新称号" and before.classId == 2.0 and before.level == 1.0
		and before.faceIndex == 5.0, before)
	check("text_name", XText.plain("\\N[1]") == "新名字" and XMVText.convert_escapes("\\N[1]") == "新名字", [XText.plain("\\N[1]"), XMVText.convert_escapes("\\N[1]")])
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var b := back.actor(1)
	check("save_roundtrip", _look(b) == before and b.class_exp == a.class_exp and a.class_exp.keys() == [1], [_look(b), before, b.class_exp])
	XState._become_current(s)
	_run_list([{"code": 321, "indent": 0, "parameters": [1, 1, false]}])
	check("class_restore_after_load_source", a.level == 5, a.level)
	var plain := back.actor(8)
	check("plain_row_unchanged", not s.to_dict().actors["8"].has("looks") and not s.to_dict().actors["8"].has("classId"), s.to_dict().actors["8"].keys())
	check("plain_actor_data_is_db", is_same(plain.data(), XDB.rec("Actors", 8)))
	# 224 画面闪烁、352 打开存档画面交给地图宿主；闪烁强度每帧 ×(d−1)/d
	var map := XMapScene.new()
	map.flash_screen([255, 0, 0, 170], 30)
	var a0: float = map._flash.color.a
	map._update_flash()
	check("flash_decay", is_equal_approx(a0, 170.0 / 255.0) and is_equal_approx(map._flash.color.a, a0 * 29.0 / 30.0) and map._flash.duration == 29, [a0, map._flash])
	check("host_codes", MVInterpreter.HOST_CODES.has(224) and MVInterpreter.HOST_CODES.has(352) and map.has_method("open_save"))
	map.free()


func _finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
