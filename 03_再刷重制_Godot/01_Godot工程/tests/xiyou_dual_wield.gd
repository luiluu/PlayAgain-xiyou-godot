extends Node
## 双持装备槽（XActor.equip_slots／init_equips，XEquipment.change／clear／optimize／fits）与 mv_oracle dual_wield_probe
## （generated/oracle/dual_wield.json）逐步比对：刘备（13，专属剑 2005 带特性 55）与曼德斯（26，职业双持）
## 每步的槽位类型、装备、背包、装备页候选（前 3 格）、能力值、weapons()[0]／[1] 的攻击动画；另比初始装备表与入队时的装备。
## 装备实例的能力值与特性照参照重建，随机浮动不在这里比。

const ORACLE := "res://modes/xiyou/generated/oracle/dual_wield.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 12:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


## 参照里的实例属性（params、traits）套到 Godot 装备上
static func _rebuild(o: Dictionary) -> Dictionary:
	var e := XGear.template(str(o.kind), int(o.base))
	e.params = (o.params as Array).duplicate()
	e.traits = (o.traits as Array).duplicate(true)
	return e


static func _brief(e) -> Variant:
	return [str(e.kind), int(e.base)] if e is Dictionary and not e.is_empty() else null


static func _sorted(list: Array) -> Array:
	var out := list.duplicate()
	out.sort()
	return out


## Game_Actor.attackAnimationId1／2（同 battle_scene._attack_animation_ids）
static func _attack_ids(a: XActor) -> Array:
	var weapons := a.equip_list().filter(func(e): return e.kind == "weapon")
	if weapons.is_empty():
		return [1, 0]
	return [int(weapons[0].animationId), int(weapons[1].animationId) if weapons.size() > 1 else 0]


func _compare(tag: String, st: XState, a: XActor, want: Dictionary) -> void:
	a.refresh_passive()
	check(tag + "_slots", a.equip_slots().map(func(v): return int(v)) == want.slots.map(func(v): return int(v)) and a.is_dual_wield() == bool(want.dual) and a.slot_type() == int(want.slotType),
		[a.equip_slots(), a.is_dual_wield(), want.slots, want.dual])
	var names := []
	for t in a.equip_slots():
		names.append(str(XDB.system().equipTypes[int(t)]))
	check(tag + "_slot_names", names == want.slotNames, [names, want.slotNames])
	var got_equips := a.equips.map(_brief)
	var want_equips: Array = want.equips.map(func(e): return [str(e.kind), int(e.base)] if e is Dictionary else null)
	check(tag + "_equips", got_equips == want_equips, [got_equips, want_equips])
	var bag := _sorted(st.gear.map(func(e): return str(e.kind) + str(int(e.base))))
	var want_bag := _sorted(want.bag.map(func(e): return str(e.kind) + str(int(e.base))))
	check(tag + "_bag", bag == want_bag, [bag, want_bag])
	for slot in range(want.candidates.size()):
		var got := _sorted(st.gear.filter(func(e): return XEquipment.fits(a, slot, e)).map(func(e): return int(e.base)))
		var w := _sorted(want.candidates[slot].map(func(v): return int(v)))
		check(tag + "_candidates_%d" % slot, got == w, [got, w])
	var params := []
	for i in range(8):
		params.append(a.param(i))
	check(tag + "_params", params == want.params.map(func(v): return float(v)), [params, want.params])
	var xp_ok := true
	for i in range(10):
		xp_ok = xp_ok and absf(a.xparam(i) - float(want.xparams[i])) < 1e-9
	check(tag + "_xparams", xp_ok, [range(10).map(func(i): return a.xparam(i)), want.xparams])
	var weapons := a.equip_list().filter(func(e): return e.kind == "weapon").map(func(e): return int(e.base))
	var anim := _attack_ids(a)
	check(tag + "_weapons", weapons == want.weapons.map(func(v): return int(v)) and anim == [int(want.attackAnimationId1), int(want.attackAnimationId2)],
		[weapons, anim, want.weapons, want.attackAnimationId1, want.attackAnimationId2])


## 参照记的是装上的实例；Godot 侧按槽套上同样的属性
func _adopt_equips(a: XActor, want: Dictionary) -> void:
	for i in range(a.equips.size()):
		var o = want.equips[i] if i < want.equips.size() else null
		if a.equips[i] is Dictionary and o is Dictionary and int(a.equips[i].base) == int(o.base):
			a.equips[i] = _rebuild(o)
	a.refresh_passive()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("dual_oracle_loaded", data is Dictionary and data.get("flows", []).size() == 2, ORACLE):
		_finish()
		return
	for f in data.flows:
		var st := XState.new_game_blank()
		var a := st.actor(int(f.actor))
		a.change_level_mv(int(data.level))
		_adopt_equips(a, f.initial)
		a.recover_all()
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
				_:
					var c: Dictionary = s.change
					var item = null
					if int(c.base) > 0:
						var idx := st.gear.find_custom(func(e): return str(e.kind) == str(c.kind) and int(e.base) == int(c.base))
						item = st.gear[idx] if idx >= 0 else null
					var ok := XEquipment.change(st, a, int(c.slot), item)
					check("%s_%d_change" % [f.name, i], ok == bool(c.ok), [s.label, ok])
			_compare("%s_%d_%s" % [f.name, i, str(s.label).replace(" ", "_")], st, a, s)
	for k in range(data.inits.size()):
		var c: Dictionary = data.inits[k]
		var st := XState.new_game_blank()
		var a := st.actor(int(c.actor))
		st.gear.clear()
		a.change_level_mv(int(data.level))
		a.init_equips(c.ids)
		_adopt_equips(a, c)
		_compare("init_%d_%d" % [k, int(c.actor)], st, a, c)
	for c in data.setups:
		var st := XState.new_game_blank()
		var a := st.actor(int(c.actor))
		st.gear.clear()
		a.change_level_mv(int(data.level))
		_adopt_equips(a, c)
		_compare("setup_%d" % int(c.actor), st, a, c)
	# 覆盖面：真的经过双持变化（装上 2005 变双持、换下变回副手）与副手位第二把武器
	var steps := []
	for f in data.flows:
		steps.append_array(f.steps)
	check("covers_toggle", steps.any(func(s): return s.dual) and steps.any(func(s): return not s.dual), null)
	check("covers_second_weapon", steps.any(func(s): return s.weapons.size() == 2 and int(s.attackAnimationId2) > 0), null)
	await _equip_page()
	_finish()


## 装备页（XEquipScene）：装上 2005 后第 2 格名字从「副手」变「武器」、候选只剩武器；换下 2005 后副手位的武器退回背包
func _equip_page() -> void:
	var st := XState.new_game_blank()
	var keep := XState.current
	XState.current = st
	st.party = [13]
	var a := st.actor(13)
	a.change_level_mv(20)
	for o in [["weapon", 2005], ["weapon", 2], ["armor", 70]]:
		st.gear.append(XGear.template(o[0], o[1]))
	var eq := XEquipScene.new()
	add_child(eq)
	await get_tree().process_frame
	check("page_offhand_name", eq.slot_name(1) == "副手" and eq.slot_name(0) == "武器", [eq.slot_name(0), eq.slot_name(1)])
	eq._ok()    # 装备 → 选槽
	await _pick(eq, 0, 2005)
	check("page_dual_after_2005", int(a.equips[0].base) == 2005 and a.is_dual_wield() and eq.slot_name(1) == "武器", [eq.slot_name(1), _brief(a.equips[0])])
	eq._slot = 1
	eq._refresh()
	eq._ok()
	var cands := eq.candidates().map(func(r): return _brief(r.rec))
	check("page_weapon_candidates", cands == [["weapon", 2], ["weapon", 2], null], cands)
	eq._cancel()
	await _pick(eq, 1, 2)
	check("page_second_weapon", _brief(a.equips[1]) == ["weapon", 2] and _attack_ids(a)[1] == int(XDB.rec("Weapons", 2).animationId), [_brief(a.equips[1]), _attack_ids(a)])
	await _pick(eq, 0, 2)
	check("page_back_to_offhand", not a.is_dual_wield() and a.equips[1] == null and eq.slot_name(1) == "副手"
		and st.gear.filter(func(e): return int(e.base) == 2005 or (int(e.base) == 2 and e.kind == "weapon")).size() == 2, [_brief(a.equips[0]), _brief(a.equips[1])])
	eq.queue_free()
	await get_tree().process_frame
	XState.current = keep


## 选槽 slot、在候选里选基础编号 base 的第一件并确定
func _pick(eq: XEquipScene, slot: int, base: int) -> void:
	eq._slot = slot
	eq._refresh()
	eq._ok()
	var idx := eq.candidates().find_custom(func(r): return not (r.rec as Dictionary).is_empty() and int(r.rec.base) == base)
	eq._item_index = idx
	eq._ok()
	await get_tree().process_frame


func _finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
