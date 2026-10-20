extends Node
## 法宝每级成长（XActor.magic_param，CP_MagicWeapon paramPlus）与 mv_oracle magic_weapon_probe（generated/oracle/magic_weapon.json）逐行比对：
## 八重樱 92 入队自带赤染樱（法宝 1／7／40 级），及别的角色装上法宝（各项成长不同、无专属、头部法宝）后改等级时的
## 每级成长、paramPlus 与能力值。装备实例的能力值与特性照参照重建，随机浮动不在这里比。

const ORACLE := "res://modes/xiyou/generated/oracle/magic_weapon.json"
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
	return e


static func _floats(list: Array) -> Array:
	return list.map(func(v): return float(v))


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("magic_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 5, ORACLE):
		_finish()
		return
	var levels := []
	for c in data.cases:
		var st := XState.new_game_blank()
		var a := st.actor(int(c.actor))
		st.gear.clear()
		a.change_level_mv(int(data.level))
		for r in c.rows:
			var slot := int(r.slot)
			# 照参照把整套装备（含入队自带的件）套上
			for i in range(a.equips.size()):
				var o = r.equips[i] if i < r.equips.size() else null
				a.equips[i] = _rebuild(o) if o is Dictionary else null
			var want: Dictionary = r.equips[slot]
			if r.setLevel != null:
				a.equips[slot].level = float(r.setLevel)
			a.refresh_passive()
			var tag := "%s_%s" % [c.name, r.label]
			var item: Dictionary = a.equips[slot]
			check(tag + "_level", float(XEquipmentView.level(item)) == float(want.level), [XEquipmentView.level(item), want.level])
			var growth := range(8).map(func(i): return XActor.magic_param(item, i) / maxf(1.0, float(XEquipmentView.level(item))))
			check(tag + "_per_level", growth == _floats(want.perLevel), [growth, want.perLevel])
			var plus := range(8).map(func(i): return a.param_plus(i))
			check(tag + "_param_plus", plus == _floats(r.paramPlus), [plus, r.paramPlus])
			var params := range(8).map(func(i): return a.param(i))
			check(tag + "_params", params == _floats(r.params), [params, r.params])
			levels.append(float(want.level))
	# 覆盖面：Init Level 与改过的等级都有，且有一行是八重樱自带的赤染樱
	check("covers_levels", levels.has(1.0) and levels.any(func(v): return v > 1.0), levels)
	check("covers_yae", data.cases.any(func(c): return int(c.actor) == 92 and c.rows.any(func(r): return int(r.equips[int(r.slot)].base) == 4518)), null)
	_finish()


func _finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
