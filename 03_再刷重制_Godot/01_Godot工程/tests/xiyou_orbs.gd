extends Node
## 宝珠镶嵌规则（XOrbs）与 mv_oracle orb_probe.cjs 的正式读数（generated/oracle/orbs.json）逐项比对：
## 孔数哈希（6 个种子 × 武器/防具 × 64 个实例编号）、孔类型、获得即排孔、可镶列表与可选性、镶嵌／替换／取下后的
## 装备属性、特性（含「类:阶」标记）、元素增幅、meta、背包数量与提示，角色身上同类上限后的特性、能力倍率与套装。
## 另测存读档保留孔与种子。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


const ORACLE := "res://modes/xiyou/generated/oracle/orbs.json"


## 比较用的规范形式：数取 6 位有效小数，特性按 [code, dataId, value, 标记]
static func norm(v):
	if v is float or v is int:
		return snappedf(float(v), 0.000001)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	return v

static func traits_of(list: Array) -> Array:
	return list.map(func(t): return [int(t.code), int(t.dataId), snappedf(float(t.value), 0.000001), str(t.get("_codexOrb", ""))])


## 用参照装备快照覆盖 Godot 实例的相关字段（两边词缀/浮动不必相同，比较的是镶嵌带来的变化）
static func from_snap(kind: String, base: int, snap: Dictionary) -> Dictionary:
	var e := XGear.template(kind, base)
	e.params = snap.params.map(func(v): return float(v))
	e.traits = snap.traits.duplicate(true)
	var yep: Dictionary = e.get("yep", {}).duplicate(true)
	yep.elementAmplify = snap.elementAmplify.duplicate()
	e.yep = yep
	e.meta = snap.meta.duplicate()
	e.price = int(snap.price)
	e.augmentSlots = snap.augmentSlots.duplicate()
	e.augmentSlotEnable = snap.augmentSlotEnable.duplicate()
	e.augmentSlotItems = snap.augmentSlotItems.duplicate()
	return e


static func eq_view(e: Dictionary) -> Dictionary:
	return {"params": norm(e.params), "traits": traits_of(e.traits), "amp": norm(e.get("yep", {}).get("elementAmplify", {})),
		"items": e.augmentSlotItems, "meta": norm(e.meta), "price": int(e.price)}

static func snap_view(s: Dictionary) -> Dictionary:
	return {"params": norm(s.params), "traits": traits_of(s.traits), "amp": norm(s.elementAmplify),
		"items": s.augmentSlotItems, "meta": norm(s.meta), "price": int(s.price)}


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("oracle_loaded", data is Dictionary and data.get("install", []).size() >= 15, ORACLE):
		_hash(data)
		_types(data)
		_lists(data)
		_install(data)
		_actor(data)
	_save_roundtrip()
	_detach_rate_after_save()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _hash(data: Dictionary) -> void:
	var cfg := XOrbs.config()
	check("config_sockets", norm(cfg.sockets) == norm(data.config.sockets) and int(cfg.familyCap) == int(data.config.familyCap))
	var bad := []
	var n := 0
	for row in data.socket:
		var tpl := XGear.template(str(row.kind), 1)
		for i in range(row.ids.size()):
			n += 1
			var got := XOrbs.socket_count_for(int(row.seed), XOrbs.is_weapon_socket(tpl), str(row.kind) == "weapon", int(row.ids[i]))
			if got != int(row.counts[i]):
				bad.append([row.seed, row.kind, row.ids[i], got, row.counts[i]])
	check("socket_count_hash", bad.is_empty() and n >= 700, [n, bad.slice(0, 5)])
	bad = []
	for l in data.layout:
		var e := XGear.template(str(l.kind), int(l.base))
		e.instanceId = "xg:%d" % int(l.id)
		XOrbs.layout(e, int(l.seed))
		if e.augmentSlots != l.augmentSlots or e.augmentSlotEnable != l.augmentSlotEnable or e.augmentSlotItems != l.augmentSlotItems:
			bad.append([l, e.augmentSlots])
	check("layout_on_gain", bad.is_empty() and data.layout.size() >= 20, bad.slice(0, 3))


func _types(data: Dictionary) -> void:
	var bad := []
	for t in data.types:
		var got := XOrbs.socket_type(XGear.template(str(t.kind), int(t.base)))
		if got != str(t.type):
			bad.append([t, got])
	check("socket_type", bad.is_empty() and data.types.size() >= 19, bad)


static func gems_of(data: Dictionary) -> Array:
	# 与探针 GEMS 相同：从列表读数里还原（weapon3-empty 的可镶列表＋防具＋非宝珠）
	return [2947, 2949, 2952, 3018, 2997, 3000, 3012, 56, 441, 2000, 2030, 3027, 1]


func _lists(data: Dictionary) -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.items = {}
	for id in gems_of(data):
		s.gain_item(id, 2)
	var force := func(e: Dictionary, type: String, n: int) -> void:
		e.augmentSlots = []
		e.augmentSlotEnable = []
		e.augmentSlotItems = []
		for i in range(n):
			e.augmentSlots.append(type)
			e.augmentSlotEnable.append(true)
			e.augmentSlotItems.append("none")
	var view := func(e: Dictionary, slot: int) -> Array:
		return XOrbs.list(e, slot, s).map(func(r): return {"id": null if r.rec.is_empty() else float(r.rec.id), "enabled": r.enabled})
	var by := {}
	for l in data.lists:
		by[l.label] = l
	var w := XGear.template("weapon", 1)
	force.call(w, XOrbs.WEAPON_TYPE, 3)
	check("list_weapon_empty", [0, 1, 2].map(func(i): return view.call(w, i)) == by["weapon3-empty"].slots, [0, 1, 2].map(func(i): return view.call(w, i)))
	check("list_apply_edge", XOrbs.apply(w, XDB.rec("Items", 2947), 0, s) == "")
	check("list_weapon_edge0", [0, 1, 2].map(func(i): return view.call(w, i)) == by["weapon3-edge0"].slots, [0, 1, 2].map(func(i): return view.call(w, i)))
	var counts := {}
	for k in by["weapon3-edge0"].counts:
		counts[k] = float(s.item_count(int(k)))
	check("list_counts", counts == by["weapon3-edge0"].counts, counts)
	w.augmentSlotEnable[2] = false
	check("list_disabled_slot", [view.call(w, 2)] == by["weapon3-slot2-disabled"].slots)
	var a := XGear.template("armor", 1)
	force.call(a, XOrbs.ARMOR_TYPE, 2)
	check("list_armor_empty", [0, 1].map(func(i): return view.call(a, i)) == by["armor2-empty"].slots, [0, 1].map(func(i): return view.call(a, i)))


func _install(data: Dictionary) -> void:
	for c in data.install:
		var name := "install_%s_%s" % [c.mode, "_".join(c.gems.map(func(g): return "x" if g == null else str(int(g))))]
		var s := XState.new_game(3, 1, [8, 9, 10])
		s.items = {}
		for id in gems_of(data) + c.gems.filter(func(g): return g != null):
			s.gain_item(int(id), 1)
		var e := from_snap(str(c.kind), int(c.base), c.before)
		var bad := []
		for st in c.steps:
			var gem := {} if st.gem == null else XDB.rec("Items", int(st.gem))
			var reason := XOrbs.apply(e, gem, 0, s)
			var counts := {}
			for k in st.counts:
				counts[k] = float(s.item_count(int(k)))
			var want := snap_view(st.after)
			var got := eq_view(e)
			if (reason == "") != bool(st.result) or (reason != "" and [reason] != st.toasts) or got != want or counts != st.counts:
				bad.append({"gem": st.gem, "reason": reason, "got": got, "want": want, "counts": [counts, st.counts]})
		if c.second != null:
			s.gain_item(int(c.gems[0]), 1)
			var reason := XOrbs.apply(e, XDB.rec("Items", int(c.gems[0])), 1, s)
			if (reason == "") != bool(c.second.result) or eq_view(e) != snap_view(c.second.after) or (reason != "" and [reason] != c.second.toasts):
				bad.append({"second": reason, "got": eq_view(e), "want": snap_view(c.second.after)})
		check(name, bad.is_empty(), bad)


func _actor(data: Dictionary) -> void:
	for c in data.actor:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var a := s.actor(1)
		a.equips = []
		for i in range(19):
			a.equips.append(null)
		for wv in c.worn:
			a.equips[int(wv.slot)] = from_snap(str(wv.kind), int(wv.base), wv.equip)
		var kept := traits_of(a.all_traits().filter(func(t): return t.has("_codexOrb")))
		var want_kept = c.kept.map(func(t): return [int(t.code), int(t.dataId), snappedf(float(t.value), 0.000001), str(t.orb)])
		check("cap_%s" % c.label, kept == want_kept, [kept, want_kept])
		var rate := range(8).map(func(i): return snappedf(a.param_rate(i), 0.000001))
		check("param_rate_%s" % c.label, rate == norm(c.paramRate), [rate, c.paramRate])
		var xp := range(10).map(func(i): return snappedf(a.xparam(i), 0.000001))
		check("xparam_%s" % c.label, xp == norm(c.xparam), [xp, c.xparam])
		var foe := XEnemy.new().setup(1, 3, 0.5)
		var terms := []
		for dmg in c.damage:
			var res := XDamage.calculate(XDB.rec("Skills", int(dmg.skill)), a, foe, {"critical": false, "variance": false})
			terms.append(snappedf(float(res.breakdown.row.get("terminal", -1.0)), 0.000001))
		check("damage_terminal_%s" % c.label, terms == c.damage.map(func(x): return snappedf(float(x.terminal), 0.000001)), [terms, c.damage])
		var sets = norm(XOrbs.active_sets(a.equips))
		check("sets_%s" % c.label, sets == norm(c.sets) and norm(XOrbs.general_set(a.equips)) == norm(c.general if c.general != null else {}), [sets, c.sets, c.general])


func _save_roundtrip() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.orb_seed = 655860619
	s.gain_gear("weapon", 1, 3)
	s.gain_gear("armor", 1, 2)
	check("gain_has_slots", s.gear.all(func(e): return e.has("augmentSlots") and e.augmentSlots.size() == XOrbs.socket_count(e, 655860619)))
	var w: Dictionary = s.gear.filter(func(e): return e.augmentSlots.size() > 0 and XOrbs.socket_type(e) == XOrbs.WEAPON_TYPE)[0]
	s.gain_item(2947, 1)
	check("rt_apply", XOrbs.apply(w, XDB.rec("Items", 2947), 0, s) == "" and s.item_count(2947) == 0)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var bw: Dictionary = back.gear[s.gear.find(w)]
	check("rt_seed", back.orb_seed == 655860619)
	check("rt_slots", bw.augmentSlots == w.augmentSlots and bw.augmentSlotItems == w.augmentSlotItems and traits_of(bw.traits) == traits_of(w.traits), [bw.augmentSlots, bw.augmentSlotItems])
	# 旧档（没有种子）按存档内容算出固定种子
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	d.erase("orbSeed")
	check("rt_legacy_seed", XState.from_dict(d.duplicate(true)).orb_seed == XState.from_dict(d.duplicate(true)).orb_seed)
	# 穿着时取下长生宝珠：HP 不超过新的上限（augmentRefreshParty → refresh）
	var a := back.actor(1)
	var arm := XGear.template("armor", 4)
	back.register_gear(arm)
	arm.augmentSlots = [XOrbs.ARMOR_TYPE]
	arm.augmentSlotEnable = [true]
	arm.augmentSlotItems = ["none"]
	back.gain_item(3006, 1)
	XOrbs.apply(arm, XDB.rec("Items", 3006), 0, back)
	a.equips[2] = arm
	a.hp = a.mhp
	var high := a.mhp
	XOrbs.apply(arm, {}, 0, back)
	check("rt_remove_clamps_hp", a.mhp < high and a.hp == a.mhp, [high, a.mhp, a.hp])
	# 取下：宝珠回背包，特性与增幅复原
	check("rt_remove", XOrbs.apply(bw, {}, 0, back) == "" and back.item_count(2947) == 1 and bw.augmentSlotItems[0] == "none" \
		and not bw.traits.any(func(t): return t.has("_codexOrb")))


## 存读档后取下：存档 JSON 把 0.36+1 写成 1.36，读回 1.3600000000000001，按 == 比对会删不掉，
## 每轮镶嵌／存读档／取下都多留一条 ×1.36（宝珠·长生·归真 3006、藏气·归真 3011）
func _detach_rate_after_save() -> void:
	var eq := {"traits": [], "params": [0, 0, 0, 0, 0, 0, 0, 0]}
	XOrbs._param_rate(eq, "MHP", 36.0, true, "11:5")
	eq = JSON.parse_string(JSON.stringify(eq))
	XOrbs._param_rate(eq, "MHP", 36.0, false, "11:5")
	check("detach_rate_after_save", eq.traits.is_empty(), eq.traits)
