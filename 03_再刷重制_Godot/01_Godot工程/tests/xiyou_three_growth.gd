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
			continue  # 重制的实例不改特性（原表就是这三条）；原版重复的那一例见 _case
		if k == "params" and w.get("rates", []).size() != 3:
			# O-137：原版刚招募、没改过等级的实例倍率特性重复（生命 ×1.6、物防 ×1.4），重制不重现；这一例只比其余六项
			check(name + ".params_dup", g.params[0] < w.params[0] and g.params[3] < w.params[3] and g.params.slice(1, 3) == w.params.slice(1, 3)
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
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			seen += 1
			_case(c)
	check("covers_all", seen == 9, seen)
	_local()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_three_growth", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
