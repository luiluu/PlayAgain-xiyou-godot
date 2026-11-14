extends Node
## 【cc·Pro·未经审查】符文之语挂起与结算 XRunewords.decide／can_grow（cc pro-test-gaps 2026-11-14）。
## xiyou_equipment 用原版参照核了每条配方做成后的属性（XRunewords.check），并核了单颗配方在 PENDING_V062 开／关时挂不挂起；
## 挂起之后怎么走没测。这里按 core/runewords.gd 的说明（v0.62.12 RW.match／canGrow／decide）逐步核：
## - 结尾匹配取最长；模板：武器看 wtypeId、防具看 atypeId>0 且 etypeId 在 armorSlots；
## - 做成的配方 A 是更长配方 B 的开头、剩余孔位够镶完 B：先挂起（runewordPending {id, start}，不结算）；
## - 接着沿 B 镶：仍挂起；镶完 B：结算 B、清挂起；
## - 下一颗没接上更长配方：结算挂起的 A；孔用完：直接结算 A；孔不够镶完 B：不挂起、直接结算 A；
## - 挂起后材料对不上任何配方：清掉挂起、不结算；O-308 关掉（PENDING_V062=false）：做成就结算；
## - check 真装备：挂起时不加属性、不改名；镶完 B 一次加上 B 的模板、只记一条符文之语（runewords=[B]）。
## A／B 从数据库 Runewords 表里现找（同一件防具都能用、B 以 A 开头且至少长 2 颗、中途不会被别的配方截走）。

var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _mats(r: Dictionary) -> Array:
	return (r.materials as Array).map(func(v): return int(v))


func _gear(kind: String, etype: int, wtype: int, slots: int) -> Dictionary:
	return {"kind": kind, "atypeId": 1, "etypeId": etype, "wtypeId": wtype, "upgradeSlots": slots}


## 找 [A, B, 装备]：B 以 A 开头、长至少 2 颗，同一件装备两条都有模板；A＋B 下一颗的结尾匹配不比 A 长
func _pair() -> Array:
	var table: Array = (XDB.table("Runewords") as Array).filter(func(r): return r is Dictionary and not (r.get("materials", []) as Array).is_empty())
	for a in table:
		for b in table:
			var ma := _mats(a)
			var mb := _mats(b)
			if mb.size() < ma.size() + 2 or mb.slice(0, ma.size()) != ma:
				continue
			for slot in a.get("armorSlots", []):
				var g := _gear("armor", int(slot), 0, mb.size() - ma.size())
				if XRunewords.template_id(a, g) == 0 or XRunewords.template_id(b, g) == 0:
					continue
				var mid := XRunewords.match_recipe(g, mb.slice(0, ma.size() + 1))
				if not mid.is_empty() and (mid.materials as Array).size() > ma.size():
					continue
				if XRunewords.match_recipe(g, ma).get("id") != a.id:
					continue
				return [a, b, g]
	return []


func _run() -> void:
	var saved := XRunewords.PENDING_V062
	XRunewords.PENDING_V062 = true
	# 模板
	var any_w := {"weaponTypes": [3, 4], "armorSlots": [2], "weapon": 11, "armor": 22}
	check("template_weapon", XRunewords.template_id(any_w, _gear("weapon", 1, 4, 0)) == 11 and XRunewords.template_id(any_w, _gear("weapon", 1, 5, 0)) == 0)
	var arm := _gear("armor", 2, 0, 0)
	check("template_armor", XRunewords.template_id(any_w, arm) == 22 and XRunewords.template_id(any_w, _gear("armor", 3, 0, 0)) == 0)
	arm.atypeId = 0
	check("template_armor_needs_atype", XRunewords.template_id(any_w, arm) == 0)

	var p := _pair()
	if not check("pair_found", not p.is_empty()):
		return finish()
	var a: Dictionary = p[0]
	var b: Dictionary = p[1]
	var ma := _mats(a)
	var mb := _mats(b)
	var base: Dictionary = p[2]
	print("pair A=%d %s B=%d %s etype=%d" % [int(a.id), ma, int(b.id), mb, int(base.etypeId)])

	# 结尾匹配：前面多镶别的也认
	check("match_suffix", XRunewords.match_recipe(base, [1] + ma).get("id") == a.id)
	check("match_none", XRunewords.match_recipe(base, [1]).is_empty())

	# can_grow
	var left := mb.size() - ma.size()
	var g := base.duplicate(true)
	check("can_grow_yes", XRunewords.can_grow(g, ma, 0, ma.size()))
	g.upgradeSlots = left - 1
	check("can_grow_not_enough_slots", not XRunewords.can_grow(g, ma, 0, ma.size()))
	g.upgradeSlots = 0
	check("can_grow_no_slots", not XRunewords.can_grow(g, ma, 0, ma.size()))

	# 1. 做成 A、孔够镶完 B：挂起
	g = base.duplicate(true)
	check("pending_A", XRunewords.decide(g, ma).is_empty() and g.get("runewordPending") == {"id": int(a.id), "start": 0}, g.get("runewordPending"))
	# 2. 接着沿 B 镶一颗：仍挂起 A
	g.upgradeSlots = left - 1
	var step := mb.slice(0, ma.size() + 1)
	check("pending_continues", XRunewords.decide(g, step).is_empty() and g.get("runewordPending") == {"id": int(a.id), "start": 0}, g.get("runewordPending"))
	# 3. 镶完 B：结算 B、清挂起
	g.upgradeSlots = 0
	var done := XRunewords.decide(g, mb)
	check("settle_B", done.get("id") == b.id and not g.has("runewordPending"), [done.get("id"), g.get("runewordPending")])

	# 断开：A 后面接一颗不在任何更长配方里的
	g = base.duplicate(true)
	XRunewords.decide(g, ma)
	g.upgradeSlots = left - 1
	var stray := 1
	check("stray_precondition", not XRunewords.can_grow(g, ma + [stray], 0, ma.size()) and XRunewords.match_recipe(g, ma + [stray]).is_empty())
	var settled := XRunewords.decide(g, ma + [stray])
	check("break_settles_A", settled.get("id") == a.id and not g.has("runewordPending"), [settled.get("id"), g.get("runewordPending")])

	# 孔用完：直接结算 A
	g = base.duplicate(true)
	g.upgradeSlots = 0
	check("no_slots_settles_A", XRunewords.decide(g, ma).get("id") == a.id and not g.has("runewordPending"))
	# 孔不够镶完 B：不挂起
	g = base.duplicate(true)
	g.upgradeSlots = left - 1
	check("short_slots_settles_A", XRunewords.decide(g, ma).get("id") == a.id and not g.has("runewordPending"))

	# 挂起后材料整个对不上（比如挂起记录指向别处）：清掉、不结算
	g = base.duplicate(true)
	g.runewordPending = {"id": int(a.id), "start": 0}
	check("stale_pending_cleared", XRunewords.decide(g, [stray, stray]).is_empty() and not g.has("runewordPending"))
	g.runewordPending = {"id": -5, "start": 0}
	g.upgradeSlots = 0
	check("unknown_pending_id", XRunewords.decide(g, ma).get("id") == a.id and not g.has("runewordPending"))

	# O-308 关：做成就结算，不碰挂起
	XRunewords.PENDING_V062 = false
	g = base.duplicate(true)
	check("rollback_settles_now", XRunewords.decide(g, ma).get("id") == a.id and not g.has("runewordPending"))
	XRunewords.PENDING_V062 = true

	_real_gear(a, b, ma, mb, int(base.etypeId))
	XRunewords.PENDING_V062 = saved
	finish()


## 真装备走 check：挂起不加属性，镶完 B 一次加 B 的模板
func _real_gear(a: Dictionary, b: Dictionary, ma: Array, mb: Array, etype: int) -> void:
	var armor_id := 0
	for r in XDB.table("Armors"):
		if r is Dictionary and int(r.get("etypeId", 0)) == etype and int(r.get("atypeId", 0)) > 0 and str(r.get("name", "")) != "":
			armor_id = int(r.id)
			break
	if not check("real_armor_found", armor_id > 0):
		return
	XGear.force_roll = 0.5
	var e := XGear.create("armor", armor_id)
	XGear.force_roll = -1.0
	var params0: Array = (e.params as Array).duplicate()
	var name0 := str(e.name)
	e.upgradeSlots = mb.size() - ma.size()
	e.upgrades = ma.map(func(id): return {"item": int(id), "name": "", "cost": 1})
	XRunewords.check(e)
	check("real_pending_no_bonus", (e.get("runewords", []) as Array).is_empty() and e.has("runewordPending") and e.params == params0 and str(e.name) == name0,
		[e.get("runewords"), e.get("runewordPending"), e.name])
	e.upgradeSlots = 0
	e.upgrades = mb.map(func(id): return {"item": int(id), "name": "", "cost": 1})
	XRunewords.check(e)
	var tpl := XDB.rec("Armors", XRunewords.template_id(b, e))
	var want: Array = range(8).map(func(i): return float(params0[i]) + float(tpl.params[i]))
	check("real_settles_B_once", e.get("runewords", []) == [int(b.id)] and not e.has("runewordPending") and str(e.runewordName) == str(tpl.name)
		and (e.params as Array).map(func(v): return float(v)) == want, [e.get("runewords"), e.params, want])
	var again := JSON.stringify(e)
	XRunewords.check(e)
	check("real_check_idempotent", JSON.stringify(e) == again)


func finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
