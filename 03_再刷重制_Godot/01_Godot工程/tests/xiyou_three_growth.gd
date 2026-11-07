extends Node
## 三法宝成长（XThreeGrowth：百谷生 7912 在谷雨 60 级进化，每级成长翻倍、改名、改说明，进化后不退）：与 mv_oracle/three_growth_probe.cjs 的
## 冻结 v0.28 参照（generated/oracle/three_growth.json）逐例比八项能力、法宝名、说明、每级成长、进化标记。
## 另有本地断言（反向）：别的法宝不归这里管、没有谷雨时不进化。
const ORACLE := "oracle/three_growth.json"
const DIFFICULTY := 2
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 同参照 setup()：新局、开 2494、招募谷雨（装上百谷生）
func _setup() -> Array:
	var s := XState.new_game(DIFFICULTY, 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	XGuyu._notified_relic = false
	XGuyu.recruit(s)
	var a := s.actor(XGuyu.ACTOR)
	var slot := (a.equips as Array).find_custom(func(e): return e is Dictionary and not e.is_empty() and int(e.get("base", 0)) == XGuyu.RELIC)
	return [a, slot]


func _snap(a: XActor, slot: int) -> Dictionary:
	a.refresh_passive()
	a.param_mark_dirty()
	var params := []
	for i in 8:
		params.append(a.param(i))
	var e: Dictionary = a.equips[slot]
	return {"level": a.level, "params": params, "name": str(e.get("name", "")), "description": str(e.get("description", "")),
		"perLevel": e.get("paramPlusPerLevel", []), "evolved": bool(e.get("_codex60Evolved", false)), "relicLevel": e.get("level", null)}


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	return v


func _same(name: String, got: Dictionary, want: Dictionary) -> void:
	var g: Dictionary = _norm(got)
	var w: Dictionary = _norm(want)
	for k in w:
		if k == "rates":
			continue  # 实例特性不改（原表就是这三条）；原版重复的两条在 O-137 关着时由 XThreeGrowth.recruit_dup_objects 另给
		if k == "params" and w.get("rates", []).size() != 3 and XThreeGrowth.FIX_RECRUIT_DUP:
			# O-137 开（默认）：原版刚招募、没改过等级的实例倍率特性重复（生命 ×1.6、物防 ×1.4），修好后生命、物防低于原版，其余六项相同
			check(name + ".params_dup_fixed", g.params[0] < w.params[0] and g.params[3] < w.params[3] and g.params.slice(1, 3) == w.params.slice(1, 3)
				and g.params.slice(4) == w.params.slice(4), [g.params, w.params])
			continue
		check(name + "." + k, g.get(k) == w[k], [g.get(k), w[k]])


func _case(c: Dictionary) -> void:
	var r := _setup()
	var a: XActor = r[0]
	var slot: int = r[1]
	if not check(c.id + ".slot", slot >= 0, slot):
		return
	if c.id == "relic.down":
		a.change_level_mv(60)
		a.equips[slot]["level"] = 5
		_same(c.id + ".at60", _snap(a, slot), c.observed.at60)
		a.change_level_mv(50)
		_same(c.id + ".at50", _snap(a, slot), c.observed.at50)
		return
	a.change_level_mv(int(c.setup.level))
	a.equips[slot]["level"] = int(c.setup.relicLevel)
	_same(c.id, _snap(a, slot), c.observed)


## 反向：别的法宝不归这里管；没有谷雨的存档里不进化
func _local() -> void:
	check("reverse.other_relic", XThreeGrowth.sync_item({"kind": "armor", "base": 4518, "name": "赤染樱"}).is_empty())
	var prior := XState.current
	XState.current = XState.new_game(DIFFICULTY, 1, [8])
	var e := {"kind": "armor", "base": XGuyu.RELIC, "name": "百谷生"}
	var per := XThreeGrowth.sync_item(e)
	check("reverse.no_owner", per[0] == 36 and per[1] == 18 and str(e.name) == "百谷生" and not e.has("_codex60Evolved"), [per, e])
	XState.current = prior


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := 0
	XThreeGrowth.FIX_RECRUIT_DUP = false  # O-137 关：逐例和原版比（含招募后倍率重复的 relic.lv1.r1）
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			seen += 1
			_case(c)
	check("covers_all", seen == 9, seen)
	XThreeGrowth.FIX_RECRUIT_DUP = true  # O-137 开（默认）：招募后不重复
	for c in ref.cases:
		if str(c.id) == "relic.lv1.r1":
			c.id = "fixed.relic.lv1.r1"
			_case(c)
	_local()
	_mark_save_roundtrip()
	finish()


## 审查 51 P3-1：O-137 开着时招募不写 _o137Dup，存档往返后也没有；关着时照写、往返后还在
func _mark_save_roundtrip() -> void:
	for fix in [true, false]:
		XThreeGrowth.FIX_RECRUIT_DUP = fix
		var r := _setup()
		var a: XActor = r[0]
		var slot := int(r[1])
		var tag := "mark.%s" % ("on" if fix else "off")
		check(tag + ".slot", slot >= 0, slot)
		if slot < 0:
			continue
		check(tag + ".written", (a.equips[slot] as Dictionary).has(XThreeGrowth.RECRUIT_DUP_KEY) == (not fix), a.equips[slot].keys())
		check(tag + ".save", XSave.save(3))
		check(tag + ".load", XSave.load_slot(3))
		var b := XState.current.actor(XGuyu.ACTOR)
		var e = b.equips[slot]
		check(tag + ".roundtrip", e is Dictionary and e.has(XThreeGrowth.RECRUIT_DUP_KEY) == (not fix), e.keys() if e is Dictionary else e)
	XThreeGrowth.FIX_RECRUIT_DUP = true


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_three_growth", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
