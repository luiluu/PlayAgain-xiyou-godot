extends Node
## 【cc·悟空·未经审查】v0.62 神话／混沌神话词条概率随难度浮动（XAffixRate、XGear.choose_affix），与 mv_oracle/affix_rate_probe.cjs 的
## 新源参照（tests/fixtures/affix_rate_oracle.json，v0.62.12 installAffixDifficultyRateRuntime）逐例比：
## - route.*：路线开关 → route／factor／label，修行·详细页末尾那段（XAffixRate.detail_rows，并且 XGuide.detail_rows 末尾就是它）；
## - curse.*：洪荒按诅咒倍率的倍率、标签数字、rate(1)／rate(20)；
## - choose.*：7 件装备的词条行在 7 条路线、21 个预掷随机数下选出的词条与用掉的随机数个数、lineTier、行内概率；
## - 开关 ENABLED 关掉：灭世也照原掷法（等于天灾 M＝1 的参照），修行页不加这段。
const FIXTURE := "res://tests/fixtures/affix_rate_oracle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _state(switches: Array) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	for id in switches:
		s.set_switch(int(id), true)
	return s


func _table(kind: String, id: int) -> String:
	var meta: Dictionary = XDB.rec(kind, id).get("meta", {})
	if meta.has("prefixSuffixUseArmorDatabase"):
		return "Armors"
	if meta.has("prefixSuffixUseWeaponDatabase"):
		return "Weapons"
	return kind


func _choose_rows(s: XState, choices: Array, table: String, rolls: Array) -> Array:
	var out := []
	for v in rolls:
		var x := [float(v)]
		for i in 19:
			x.append(0.5)
		s.rom.x = x
		s.rom.xn = 0
		var xs := []
		xs.resize(20)
		xs.fill(0)
		s.rom.xs = xs
		s.rom.xsn = 0
		var id := XGear.choose_affix(choices, table, s)
		out.append([id, int(s.rom.xn)])
	return out


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var calamity := {}
	var choose_n := 0
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var o: Dictionary = c.observed
		if c.id.begins_with("route."):
			var s := _state(c.setup.switches)
			var r := XAffixRate.route(s)
			check(c.id + ".route", (r.get("key") if not r.is_empty() else null) == o.route, [r.get("key"), o.route])
			check(c.id + ".factor", absf(XAffixRate.factor(s) - float(o.factor)) < 1e-12, [XAffixRate.factor(s), o.factor])
			check(c.id + ".label", XAffixRate.label(s) == str(o.label), [XAffixRate.label(s), o.label])
			check(c.id + ".curse", absf(XAffixRate.curse(s) - float(o.curse)) < 1e-12, [XAffixRate.curse(s), o.curse])
			var tail := XAffixRate.detail_rows(s)
			check(c.id + ".detail", o.tail != null and JSON.stringify(tail) == JSON.stringify(o.tail), [tail, o.tail])
			var full := XGuide.detail_rows(s, s.actor(1))
			check(c.id + ".detail_end", JSON.stringify(full.slice(full.size() - tail.size())) == JSON.stringify(tail))
		elif c.id.begins_with("curse."):
			var f := XAffixRate.factor_of(XAffixRate.ROUTES[0], float(c.setup.curse))
			check(c.id + ".factor", absf(f - float(o.factor)) < 1e-12, [f, o.factor])
			check(c.id + ".label", "洪荒 ×" + XAffixRate._round2(f) == str(o.label), [XAffixRate._round2(f), o.label])
			check(c.id + ".rate", absf(minf(50.0, f) - float(o.rate1)) < 1e-12 and absf(minf(50.0, 20.0 * f) - float(o.rate20)) < 1e-9, [f, o.rate1, o.rate20])
		elif c.id.begins_with("choose."):
			choose_n += 1
			var s := _state(c.setup.switches)
			var kind := str(c.setup.table)
			var table := _table(kind, int(c.setup.id))
			var choices: Array = XDB.rec(kind, int(c.setup.id)).get("equipment", {}).get("affixes", [])[int(c.setup.row)].choices
			check(c.id + ".chances", choices.map(func(x): return int(x.chance)) == o.chances.map(func(x): return int(x)), [choices.map(func(x): return x.chance), o.chances])
			check(c.id + ".tier", XAffixRate.line_tier(choices, table) == int(o.tier), [XAffixRate.line_tier(choices, table), o.tier])
			var rolls: Array = o.rows.map(func(x): return float(x.roll))
			var want: Array = o.rows.map(func(x): return [int(x.id), int(x.used)])
			var got := _choose_rows(s, choices, table, rolls)
			check(c.id + ".rows", got == want, [got, want])
			if c.id.begins_with("choose.calamity."):
				calamity[c.id.trim_prefix("choose.calamity.")] = want
			if c.id.begins_with("choose.doom."):
				calamity["doom:" + c.id.trim_prefix("choose.doom.")] = [s, choices, table, rolls]
	check("choose_cases", choose_n == 49, choose_n)
	XAffixRate.ENABLED = false
	for k in calamity.keys().filter(func(k): return str(k).begins_with("doom:")):
		var key := str(k).trim_prefix("doom:")
		var a: Array = calamity[k]
		var s: XState = a[0]
		XState.current = s
		check("switch_off." + key, _choose_rows(s, a[1], a[2], a[3]) == calamity.get(key), key)
	check("switch_off.detail", XAffixRate.detail_rows(_state([2487])).is_empty())
	XAffixRate.ENABLED = true
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_affix_rate", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
