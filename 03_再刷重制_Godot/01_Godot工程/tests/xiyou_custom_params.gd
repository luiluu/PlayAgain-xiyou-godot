extends Node
## 装备 <Custom Parameters>（XActor.custom_param，YEP_EquipCore evalParamPlus）与 mv_oracle custom_params_probe
## （generated/oracle/custom_params.json）逐行比对：每种写法一件，单独装在切片角色身上，1／20／60 级，读变量的再设两组变量，
## 比该件的 evalParamPlus、角色 paramPlus 与能力值。原版未设的变量是 NaN（参照写 null），Godot 按 0：这几项只查 Godot 是有限数。
## 另查转换器把冻结数据里全部带标签的装备都解析成功（没有 unsupported）。

const ORACLE := "res://modes/xiyou/generated/oracle/custom_params.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 12:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


static func _rebuild(o: Dictionary) -> Dictionary:
	var e := XGear.template(str(o.kind), int(o.base))
	e.params = (o.params as Array).duplicate()
	e.traits = (o.traits as Array).duplicate(true)
	if o.get("level") != null:
		e.level = float(o.level)
	return e


## 参照为 null（NaN）的项只要求 Godot 是有限数；其余逐项相等
func _same(got: Array, want: Array) -> bool:
	for i in range(8):
		if want[i] == null:
			if is_nan(float(got[i])) or is_inf(float(got[i])):
				return false
		elif float(got[i]) != float(want[i]):
			return false
	return true


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("custom_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 8, ORACLE):
		_finish()
		return
	var prior := XState.current
	var aliases := {}
	for c in data.cases:
		var st := XState.new_game_blank()
		XState.current = st
		st.actor_max_level = int(data.maxLevel)
		var a := st.actor(int(c.actor))
		st.gear.clear()
		for r in c.rows:
			for i in range(a.equips.size()):
				var o = r.equips[i] if i < r.equips.size() else null
				a.equips[i] = _rebuild(o) if o is Dictionary else null
			if r.vars is Dictionary:
				for vid in r.vars:
					if r.vars[vid] == null:
						st.variables.erase(int(vid))
					else:
						st.set_variable(int(vid), float(r.vars[vid]))
			a.change_level_mv(int(r.level))
			a.refresh_passive()
			var tag := "%s_%s" % [c.name, r.label]
			check(tag + "_level", a.level == int(r.level), [a.level, r.level])
			var item: Dictionary = a.equips[int(r.slot)]
			var ev := range(8).map(func(i): return a.custom_param(item, i))
			check(tag + "_eval", _same(ev, r.evalPlus), [ev, r.evalPlus])
			var plus := range(8).map(func(i): return a.param_plus(i))
			check(tag + "_param_plus", _same(plus, r.paramPlus), [plus, r.paramPlus])
			var params := range(8).map(func(i): return a.param(i))
			check(tag + "_params", _same(params, r.params), [params, r.params])
		for m in RegEx.create_from_string("(\\w+)\\s*=").search_all(str(c.code)):
			aliases[m.get_string(1)] = true
		for vid in st.variables.keys():
			st.variables.erase(vid)
	XState.current = prior
	# 覆盖面：出现过的别名都量到、tp 被忽略、有读变量的
	check("covers_aliases", ["maxhp", "maxmp", "mhp", "mmp", "atk", "mat", "def", "mdf", "agi", "luk", "tp"].all(func(k): return aliases.has(k)), aliases.keys())
	check("covers_vars", data.cases.any(func(c): return c.rows.any(func(r): return r.vars is Dictionary and r.vars.values().all(func(v): return v != null))), null)
	# 转换器：冻结数据里带标签的全部解析成功
	var parsed := 0
	var bad := []
	for table in ["Weapons", "Armors"]:
		for rec in XDB.table(table):
			if rec is Dictionary and rec.has("customParams"):
				if rec.customParams.has("params"):
					parsed += 1
				else:
					bad.append([table, rec.id])
	check("converter_all_parsed", parsed == 224 and bad.is_empty(), [parsed, bad])
	_finish()


func _finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
