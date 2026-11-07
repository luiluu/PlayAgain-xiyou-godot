extends Node
## 双持专武只能装一把（XEquipment.dual_blocked／release_dual_exclusive，installDualExclusiveRuntime）与 mv_oracle dual_exclusive_probe
## （tests/fixtures/dual_exclusive_oracle.json，冻结参照）逐步比对：刘备（13，专武 2005～2007 都带双持）、紫霞（70，职业双持，专武 1548／1696）
## 每步的换装成败、双持、前两格装备、背包、前两格候选与可用与否（装备页变灰）；清空＋最强装备；旧档两把专武 refresh 后只留前一把。
## 另测装备页：被挡的专武变灰、确定不换；白晶晶 76 例外。

const ORACLE := "res://tests/fixtures/dual_exclusive_oracle.json"
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


static func _base(e) -> Variant:
	return int(e.base) if e is Dictionary and not e.is_empty() else null


func _compare(tag: String, st: XState, a: XActor, want: Dictionary) -> void:
	a.refresh_passive()
	check(tag + "_dual", a.is_dual_wield() == bool(want.dual), [a.is_dual_wield(), want.dual])
	var got := [_base(a.equips[0]), _base(a.equips[1])]
	var w: Array = (want.equips as Array).slice(0, 2).map(func(e): return int(e.base) if e is Dictionary else null)
	check(tag + "_equips", got == w, [got, w])
	var bag: Array = st.gear.map(func(e): return str(e.kind) + str(int(e.base)))
	bag.sort()
	check(tag + "_bag", bag == want.bag, [bag, want.bag])
	for slot in range(want.candidates.size()):
		var cands: Array = st.gear.filter(func(e): return XEquipment.fits(a, slot, e)) \
			.map(func(e): return [int(e.base), not XEquipment.dual_blocked(a, slot, e)])
		cands.sort()
		var wc: Array = want.candidates[slot].map(func(c): return [int(c.base), bool(c.enabled)])
		wc.sort()
		check(tag + "_candidates_%d" % slot, cands == wc, [cands, wc])


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("oracle_loaded", data is Dictionary and data.get("flows", []).size() == 2, ORACLE):
		_finish()
		return
	var keep := XState.current
	var blocked := 0
	XEquipment.FIX_DUAL_EXCLUSIVE_BEST = false  # 参照是原版：最强装备第二栏挑中专武被挡、留空
	for f in data.flows:
		var st := XState.new_game_blank()
		XState.current = st
		var a := st.actor(int(f.actor))
		a._lv = int(data.level)
		for i in range(a.equips.size()):
			a.equips[i] = null
		st.gear.clear()
		a.refresh_passive()
		for o in f.gains:
			st.gear.append(_rebuild(o))
		_compare("%s_initial" % f.name, st, a, f.initial)
		for i in range(f.steps.size()):
			var s: Dictionary = f.steps[i]
			match str(s.op):
				"clear":
					XEquipment.clear(st, a)
				"optimize":
					XEquipment.optimize(st, a)
				"force":
					# 旧档：绕过换装直接放进两个武器栏，再走 refresh 的 releaseUnequippableItems
					for k in range(2):
						var idx := st.gear.find_custom(func(e): return str(e.kind) == "weapon" and int(e.base) == int(s.bases[k]))
						a.equips[k] = st.gear[idx]
						st.gear.remove_at(idx)
						a.refresh_passive()
					a.release_to_party()
				_:
					var c: Dictionary = s.change
					var item = null
					if int(c.base) > 0:
						var idx := st.gear.find_custom(func(e): return str(e.kind) == str(c.kind) and int(e.base) == int(c.base))
						item = st.gear[idx] if idx >= 0 else null
					var ok := XEquipment.change(st, a, int(c.slot), item)
					if not bool(c.ok):
						blocked += 1
					check("%s_%d_change" % [f.name, i], ok == bool(c.ok), [s.label, ok])
			_compare("%s_%d_%s" % [f.name, i, str(s.label).replace(" ", "_")], st, a, s)
	XEquipment.FIX_DUAL_EXCLUSIVE_BEST = true
	_best_fixed()
	XState.current = keep
	check("covers_blocked", blocked >= 4, blocked)
	# 白晶晶例外；不是武器、没有 <req_actors> 的不算专武
	var bj := XState.new_game_blank().actor(76)
	check("exclusive_flags", XEquipment.is_exclusive(XGear.template("weapon", 1619)) and XEquipment.is_exclusive(XGear.template("weapon", 2005))
		and not XEquipment.is_exclusive(XGear.template("weapon", 2)) and not XEquipment.is_exclusive({}), null)
	check("exempt_76", XEquipment.release_dual_exclusive(bj).is_empty() and not XEquipment.dual_blocked(bj, 1, XGear.template("weapon", 1620)), null)
	await _equip_page()
	_finish()


## O-待定 修好后：最强装备第二栏跳过专武、挑下一件最好的（刘备 2007＋练习剑 2；紫霞 1696＋2）
func _best_fixed() -> void:
	for pair in [[13, [2005, 2006, 2007, 2], 2007], [70, [1548, 1696, 2], 1696]]:
		var st := XState.new_game_blank()
		XState.current = st
		var a := st.actor(int(pair[0]))
		a._lv = 80
		for i in range(a.equips.size()):
			a.equips[i] = null
		st.gear.clear()
		for b in pair[1]:
			st.gear.append(XGear.template("weapon", b))
		a.refresh_passive()
		XEquipment.optimize(st, a)
		check("best_fixed_%d" % int(pair[0]), _base(a.equips[0]) == int(pair[2]) and _base(a.equips[1]) == 2, [_base(a.equips[0]), _base(a.equips[1])])


## 装备页：刘备 0 格 2005，1 格选 2006 → 变灰、确定后不换；选普通剑 2 照常
func _equip_page() -> void:
	var st := XState.new_game_blank()
	var keep := XState.current
	XState.current = st
	st.party = [13]
	var a := st.actor(13)
	a._lv = 80
	for i in range(a.equips.size()):
		a.equips[i] = null
	st.gear.clear()
	for b in [2005, 2006, 2]:
		st.gear.append(XGear.template("weapon", b))
	a.refresh_passive()
	check("page_equip_2005", XEquipment.change(st, a, 0, st.gear[0]) and a.is_dual_wield(), _base(a.equips[0]))
	var eq := XEquipScene.new()
	add_child(eq)
	await get_tree().process_frame
	eq._ok()
	eq._slot = 1
	eq._refresh()
	eq._ok()
	var idx := eq.candidates().find_custom(func(r): return not (r.rec as Dictionary).is_empty() and int(r.rec.base) == 2006)
	check("page_lists_2006", idx >= 0 and XEquipment.dual_blocked(a, 1, eq.candidates()[idx].rec), idx)
	eq._item_index = idx
	eq._ok()
	await get_tree().process_frame
	check("page_2006_refused", a.equips[1] == null and eq._mode == "item", [_base(a.equips[1]), eq._mode])
	idx = eq.candidates().find_custom(func(r): return not (r.rec as Dictionary).is_empty() and int(r.rec.base) == 2)
	eq._item_index = idx
	eq._ok()
	await get_tree().process_frame
	check("page_plain_ok", _base(a.equips[1]) == 2 and eq._mode == "slot", [_base(a.equips[1]), eq._mode])
	eq.queue_free()
	await get_tree().process_frame
	XState.current = keep


func _finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
