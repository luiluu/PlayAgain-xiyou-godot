extends Node
## 异化工坊期二（配置异化与穿戴限制）：按正式 alien_config_probe.cjs 的记录逐项比对——alienation.json 的模板与云裳名单；
## 队员的原生主动技能、可借技能、生命兼容；吞器供体的借出效果；20 种词条 × 4 名队员的就绪判定；可绑定队友；
## configure／clearConfiguration 20 例（返回、存下的配置、之后的就绪、详情行）；工坊配置页 6 条路线每一步的节点树（含下拉框选项与当前值）；
## 换装备（未就绪、就绪、第二件、同槽替换、待选中）与商店出售可否选。另查挂机自动卖出／一键出售跳过异化装备（O-待定）。
## 吞器供体的装备 ID：原版是独立装备编号，这里是实例 ID，比对时按供体顺序换算。

var results := []
var out_dir := ""
const ORACLE := "res://modes/xiyou/generated/oracle/alien_config.json"
const PARTY := [1, 8, 9, 10]
var o: Dictionary
var donor_ids := {}   # 原版供体编号 → 实例 ID


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


## 窗口模式加 -- --out=<目录> 存配置页截图
func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


static func norm(v):
	if v is int or v is float:
		return float(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	return v


## 两份节点树第一处不同
static func first_diff(a, b) -> Array:
	if not (a is Array and b is Array):
		return [a, b]
	for i in range(maxi(a.size(), b.size())):
		var x = a[i] if i < a.size() else null
		var y = b[i] if i < b.size() else null
		if norm(x) != norm(y):
			return [i, x, y]
	return []


func _state() -> XState:
	var s := XState.new_game_blank()
	s.items = {}
	s.gear = []
	for id in PARTY:
		s.add_actor(id)
		var a := s.actor(id)
		for n in a.equips.size():
			a.equips[n] = null
		for sk in o.export.learn[str(id)]:
			a.learn_skill(int(sk))
		a.refresh_passive()
	s.gear = []
	XAlienation.force_roll = 0.5
	# 参照探针 Math.random 固定 0.5：装备的随机前后缀、品质、浮动也固定（新局装备随机流每次换种子，原来偶尔抽出前后缀／别的品质）
	XGear.force_roll = 0.5
	return s


func _make(s: XState, kind: String, base: int, origin: String, affix: String) -> Dictionary:
	var i: Dictionary = XAlienation.create(s, kind, base, origin, affix).ok
	s.gear.append(i)
	return i


func _plain(s: XState, id: int) -> Dictionary:
	var inst := XGear.create("weapon", id, s)
	s.register_gear(inst)
	s.gear.append(inst)
	return inst


func _base_of(k: String) -> Array:
	return {"blessing": ["w", 1523], "pest": ["a", 1013]}.get(k, ["w", 1044])


## 存下的配置里供体编号换成原版编号再比
func _cfg(c: Dictionary) -> Dictionary:
	var out := c.duplicate(true)
	if out.has("donorId"):
		for k in donor_ids:
			if donor_ids[k] == str(out.donorId):
				out.donorId = int(k)
	return out


func _run() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("oracle_loaded", raw is Dictionary, ORACLE):
		_finish()
		return
	o = raw
	_data()
	_judgements()
	for p in o.pages:
		await _flow(p)
	_equip()
	_sell_filters()
	_finish()


func _data() -> void:
	var c := XAlienation.config()
	check("templates", norm(c.templates) == norm(o.export.templates))
	check("yunshang_lists", norm(c.transferDebuffs) == norm(o.export.transferDebuffs) and norm(c.shareBuffs) == norm(o.export.shareBuffs))


func _judgements() -> void:
	var s := _state()
	var donors := [1, 6, 7].map(func(id): return _plain(s, id))
	for id in PARTY:
		var a := s.actor(id)
		var want: Dictionary = o.actors[str(id)]
		var got := {"originalActive": XAlienation.original_active(a).map(func(sk): return int(sk.id)),
			"borrowable": XAlienation.native_skills(a).filter(func(sk): return a.skill_ids.has(int(sk.id)) and XAlienation.borrowable(sk)).map(func(sk): return int(sk.id)),
			"lifeCompatible": XAlienation.life_compatible(a)}
		check("actor_%d" % id, norm(got) == norm(want), [got, want])
	for n in donors.size():
		var g := XAlienation.effect_ghost(donors[n])
		var want = o.ghosts[n].ghost
		check("ghost_%d" % n, norm({"traits": g.traits, "note": g.note} if not g.is_empty() else null) == norm(want), [g, want])
	var items := {}
	for f in XAlienation.config().affixes:
		var b := _base_of(str(f.key))
		items[str(f.key)] = _make(s, b[0], b[1], "boss", str(f.key))
	for k in items:
		var got := PARTY.map(func(id): return XAlienation.ready(s, s.actor(id), items[k]))
		check("ready_" + k, got == o.ready[k], [got, o.ready[k]])
		check("needs_" + k, XAlienation.needs_configuration(items[k]) == o.needs[k])
	for k in o.binding:
		var got := PARTY.map(func(id): return XAlienation.binding_options(s, s.actor(id), k).map(func(a): return a.actor_id))
		check("binding_" + k, norm(got) == norm(o.binding[k]), [got, o.binding[k]])
	# configure：照参照的顺序在同一批装备上做
	for c in o.configure:
		match str(c.name):
			"reserved":
				var got := {"reserved": donors.map(func(d): return XAlienation.reserved(s, d)), "canOperate": donors.map(func(d): return XAlienation.can_operate(s, d)),
					"bound": donors.map(func(d): return XAlienation.bound(s, d))}
				check("configure_reserved", got.reserved == c.reserved and got.canOperate == c.canOperate and got.bound == c.bound, [got, c])
			"clear":
				var r := XAlienation.clear_configuration(s, items.swallow)
				check("configure_clear", r.has("ok") and items.swallow.alien.config.is_empty() and donors.map(func(d): return XAlienation.reserved(s, d)) == c.reserved)
			_:
				var conf: Dictionary = c.config.duplicate(true)
				if conf.has("donorId"):
					var idx := -1
					if str(c.name) == "swallow-ok":
						donor_ids[str(int(conf.donorId))] = str(donors[0].instanceId)
					conf.donorId = donor_ids.get(str(int(conf.donorId)), "xg:99999")
				var i: Dictionary = items[str(c.affix)]
				var r := XAlienation.configure(s, i, conf)
				var got := {"result": {"ok": true} if r.has("ok") else {"thrown": r.error}, "saved": _cfg(i.alien.config),
					"ready": PARTY.map(func(id): return XAlienation.ready(s, s.actor(id), i)), "details": XAlienation.details(s, i)}
				var want := {"result": c.result, "saved": c.saved, "ready": c.ready, "details": c.details}
				check("configure_" + str(c.name), norm(got) == norm(want), [got, want])


func _flow(p: Dictionary) -> void:
	var name := str(p.name)
	var s := _state()
	donor_ids = {}
	if name == "swallow":
		for id in [1, 6]:
			_plain(s, id)
	for m in p.made:
		_make(s, str(m.kind), int(m.base), "boss", str(m.affix)).params = m.params.duplicate()
	var page := XAlienWorkshop.new()
	add_child(page)
	await frames()
	var bad := []
	if norm(XAlienWorkshop.flatten(page.tree)) != norm(p.screens[0]):
		bad.append([0, first_diff(XAlienWorkshop.flatten(page.tree), p.screens[0])])
	var screen := 0
	for step in p.steps:
		screen += 1
		if not bad.is_empty():
			break
		var st := str(step)
		var ok := true
		if st.begins_with("sel:"):
			var spec := st.substr(4)
			ok = page.choose_option(spec.get_slice("#", 0), int(spec.get_slice("#", 1)))
		else:
			ok = page.click(st)
		if not ok:
			bad.append([screen, "missing " + st])
			break
		await frames(1)
		if screen == 1:
			await shot("alien_config_" + name)
		if norm(XAlienWorkshop.flatten(page.tree)) != norm(p.screens[screen]):
			bad.append([screen, first_diff(XAlienWorkshop.flatten(page.tree), p.screens[screen])])
	check("pages_" + name, bad.is_empty(), bad)
	var configs := XAlienation.owned(s).filter(func(e): return not XAlienation.mark(e).is_empty()).map(func(i): return {"name": i.name, "config": i.alien.config})
	# 供体编号：按供体在背包里的先后对上原版
	var plain_ids := XAlienation.owned(s).filter(func(e): return XAlienation.mark(e).is_empty()).map(func(e): return str(e.instanceId))
	for c in configs:
		if c.config.has("donorId"):
			c.config.donorId = plain_ids.find(str(c.config.donorId))
	for c in p.configs:
		if c.config.has("donorId"):
			c.config.donorId = 0 if not p.configs.is_empty() else -1
	check("configs_" + name, norm(configs) == norm(p.configs), [configs, p.configs])
	page.queue_free()
	await frames()


func _equip() -> void:
	var s := _state()
	s.actor_max_level = 99
	var rows := {}
	for r in o.equip:
		rows[str(r.step)] = r
	var a := s.actor(int(rows.actor.actorId))
	for id in PARTY:
		s.actor(id).change_level(40)
	var eb := int(rows.base.base)
	var mim := _make(s, "w", eb, "boss", "mimic")
	var inv := _make(s, "w", eb, "boss", "inversebone")
	var pr := _make(s, "w", eb, "boss", "prayer")
	var slot := 0
	var can := func(i): return {"canEquip": a.can_equip(i) and XAlienation.can_wear(s, a, i), "ready": XAlienation.ready(s, a, i)}
	var got := {}
	got["not-ready"] = can.call(mim)
	got["not-ready"].change = XEquipment.change(s, a, slot, mim) and is_same(a.equips[slot], mim)
	XAlienation.configure(s, mim, {"actorId": a.actor_id, "replace": int(XAlienation.original_active(a)[0].id)})
	got["configured"] = can.call(mim)
	got["configured"].change = XEquipment.change(s, a, slot, mim) and is_same(a.equips[slot], mim)
	var ab := int(rows.second.armor)
	var arm := _make(s, "a", ab, "boss", "hollow")
	var aslot := int(rows.second.slot)
	got["second"] = can.call(arm)
	got["second"].change = XEquipment.change(s, a, aslot, arm) and is_same(a.equips[aslot], arm)
	got["swap-in-same-slot"] = can.call(inv)
	got["swap-in-same-slot"].change = XEquipment.change(s, a, slot, inv) and is_same(a.equips[slot], inv)
	s.gain_item(XAlienation.stone_id(), 1)
	XAlienation.reroll(s, pr)
	got["pending"] = {"change": XEquipment.change(s, a, slot, pr) and is_same(a.equips[slot], pr)}
	got["pending"].unequip = XEquipment.change(s, a, slot, null) and a.equips[slot] == null
	XAlienation.resolve(s, false)
	got["after-resolve"] = {"unequip": XEquipment.change(s, a, slot, null) and a.equips[slot] == null}
	for k in got:
		var want := {}
		for f in rows[k]:
			if not (f in ["step", "affix", "armor", "slot"]):
				want[f] = rows[k][f]
		check("equip_" + k, norm(got[k]) == norm(want), [got[k], want])
	var plain := _plain(s, 1)
	check("sell_enabled", XItemMarks.can_sell(inv) == bool(rows.sell.alien) and XItemMarks.can_sell(plain) == bool(rows.sell.plain), [XItemMarks.can_sell(inv), XItemMarks.can_sell(plain)])


## 挂机自动卖出（原版挡了）与一键出售（原版没挡，O-待定）都跳过异化装备
func _sell_filters() -> void:
	var s := _state()
	var alien := _make(s, "w", 1044, "boss", "void")
	var q := int(str(alien.get("meta", {}).get("quality", "0")).strip_edges())
	var plain := XGear.create("weapon", 1044, s)
	s.register_gear(plain)
	s.gear.append(plain)
	var list := XItemMarks.sellable_gear(s, [q])
	check("sellable_skips_alien", not list.any(func(e): return is_same(e, alien)) and list.any(func(e): return is_same(e, plain)), [q, list.size()])


func _finish() -> void:
	XAlienation.force_roll = -1.0
	XGear.force_roll = -1.0
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
