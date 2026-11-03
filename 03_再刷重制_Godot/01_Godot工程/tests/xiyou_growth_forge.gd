extends Node
## 【cc·八戒·未经审查】成长装备期二 XGrowthForge：照参照 growth_forge_probe（tests/fixtures/growth_forge_oracle.json）逐例比。
## 锻造锤、解锁、能否锻造与配方三项、锻造前后的实例与穿着角色；另加锻造后存档往返、界面（选原件、确认、弹窗）走一遍。
## 与原版不同、不比的：原版 resetKnownRecipes（只在建队伍时调）重制没有，unlock.flow 的 reset／reset2 两步不比；
## 「拥有原件却没解锁」原版只能人为造出（can.*.locked），重制查配方时会补解锁，改比补解锁后的结果。提示（toaster）没接，不比。
const FIXTURE := "res://tests/fixtures/growth_forge_oracle.json"
const SKILLS := [10227, 10228]
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(_kind: String, _reason: String, _event_key: String):
		draws += 1
		return value


class RewardLogic extends RefCounted:
	var state: XState
	var troop_id := 0
	var stream := FixedStream.new()
	func _rule() -> XRandomStream:
		return stream


func _same(got, want) -> bool:
	if want is float or want is int:
		return (got is float or got is int) and absf(float(got) - float(want)) < 1e-6
	if want is Array:
		if not (got is Array) or got.size() != want.size():
			return false
		for i in want.size():
			if not _same(got[i], want[i]):
				return false
		return true
	if want is Dictionary:
		if not (got is Dictionary):
			return false
		for k in want:
			if not got.has(k) or not _same(got[k], want[k]):
				return false
		return true
	return typeof(got) == typeof(want) and got == want


func _cmp(tag: String, got, want) -> void:
	if want is Dictionary and got is Dictionary:
		for k in want:
			check(tag + "." + k, got.has(k) and _same(got[k], want[k]), [got.get(k), want[k]])
	else:
		check(tag, _same(got, want), [got, want])


func _new_state() -> XState:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	XHeartsteel.in_battle = false
	XGrowthForge.forge_source = {}
	return s


func _bag(s: XState, base: int) -> Array:
	return s.gear.filter(func(e): return str(e.kind) == "armor" and int(e.base) == base)


## 入包一件，返回这件（重制自己掷词条；锻造例的特性照参照另设）
func _gear(s: XState, base: int, fields := {}) -> Dictionary:
	s.gain_gear("armor", base, 1)
	var it: Dictionary = _bag(s, base).back()
	for k in fields:
		it[k] = fields[k]
	return it


func _equip(s: XState, a: XActor, it: Dictionary) -> void:
	XEquipment.change(s, a, a.equip_slots().find(int(it.etypeId)), it)
	a.refresh_passive()
	a.param_mark_dirty()


func _flags(s: XState) -> Dictionary:
	var unlocked := [bool(s.crafting.get("codexLeviathanUnlocked", false)), bool(s.crafting.get("codexAtaraxiaUnlocked", false))]
	return {"unlocked": unlocked, "recipes": [XCrafting.known(s, XCrafting.recipe(457)), XCrafting.known(s, XCrafting.recipe(458))]}


func _raw_flags(s: XState) -> Dictionary:
	var k: Dictionary = XCrafting._data(s).known
	return {"unlocked": [bool(s.crafting.get("codexLeviathanUnlocked", false)), bool(s.crafting.get("codexAtaraxiaUnlocked", false))],
		"recipes": [bool(k.get("457", false)), bool(k.get("458", false))]}


func _snap(it: Dictionary) -> Dictionary:
	var meta: Array = (it.get("meta", {}) as Dictionary).keys().filter(func(k): return str(k).begins_with("Codex"))
	meta.sort()
	var note := str(it.note)
	var pos: Array = RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\][^>]*?size=").search_all(note).map(func(m): return m.get_string())
	var traits: Array = (it.traits as Array).map(func(t): return [int(t.code), int(t.dataId), float(t.value)])
	var out := {"base": int(it.base), "orig": int(it.base), "traits": traits, "name": it.name, "baseName": it.get("baseName", ""), "icon": int(it.iconIndex), "description": it.description,
		"params": it.params, "metaKeys": meta, "tags": ["<CodexHeartsteel>", "<CodexLeviathan>", "<CodexHubris>", "<CodexAtaraxia>"].filter(func(t): return note.contains(t)), "pos": pos}
	for k in [["stacks", XHeartsteel.STACKS], ["hp", XHeartsteel.LEGACY_HP], ["fame", XHubris.FAME]]:
		if it.has(k[1]):
			out[k[0]] = it[k[1]]
	return out


func _actor(a: XActor) -> Dictionary:
	return {"mhp": a.mhp, "atk": a.atk, "def": a.def, "mdf": a.mdf, "skills": a.skills().map(func(x): return int(x.id)).filter(func(id): return id in SKILLS)}


func _case_core(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := _new_state()
	s.map_id = int(st.map)
	s.unknown_origin = int(st.origin) if st.origin != null else null
	s.variables[107] = int(st.v107)
	var l := RewardLogic.new()
	l.state = s
	l.troop_id = int(st.troop)
	l.stream.value = float(st.r)
	XGrowthForge.start_battle()
	var got := XGrowthForge.award_core(l, int(st.result))
	var again := XGrowthForge.award_core(l, int(st.result))
	_cmp(c.id, {"origin": XGrowthForge.unknown_core_origin(s), "got": got, "again": again, "draws": l.stream.draws, "hammers": s.item_count(XGrowthForge.HAMMER)},
		{"origin": o.origin, "got": o.got, "again": o.again, "draws": o.draws, "hammers": o.hammers})


func _case_unlock_flow(c: Dictionary) -> void:
	var want := {}
	for step in c.observed.steps:
		want[str(step[0])] = step
	var s := _new_state()
	_cmp(c.id + ".new", _flags(s), want.new[1])
	s.gain_item(XGrowthForge.HAMMER, 3)
	_cmp(c.id + ".hammer", _flags(s), want.hammer[1])
	_gear(s, 7900)
	_cmp(c.id + ".heart", _flags(s), want.heart[1])
	_gear(s, 7900)
	_cmp(c.id + ".heart2", _flags(s), want.heart2[1])
	_gear(s, 7902)
	_cmp(c.id + ".hubris", _flags(s), want.hubris[1])
	for e in s.gear.filter(func(e): return XHeartsteel.is_gear(e) or XHubris.is_gear(e)):
		s.lose_gear(e)
	_cmp(c.id + ".lost", _flags(s), want.lost[1])
	check(c.id + ".lost.count", _bag(s, 7900).size() + _bag(s, 7902).size() == int(want.lost[2]))
	XCrafting.learn(s, 457, false)
	XCrafting.learn(s, 458, false)
	_cmp(c.id + ".forget", _flags(s), want.forget[1])


func _case_unlock_master(c: Dictionary) -> void:
	var s := _new_state()
	_gear(s, int(c.setup.base))
	_cmp(c.id, _flags(s), c.observed.flags)


## 旧档：有实例没标记；读档后重制在查配方时补上（原版在读档／建配方时）
func _case_unlock_load(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_state()
	var it := _gear(s, int(c.setup.base))
	if str(c.setup.where) == "worn":
		_equip(s, s.actor(1), it)
	s.crafting.erase("codexLeviathanUnlocked")
	s.crafting.erase("codexAtaraxiaUnlocked")
	XCrafting.learn(s, 457, false)
	XCrafting.learn(s, 458, false)
	_cmp(c.id + ".before", _raw_flags(s), o.before)
	var r := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = r
	var known := [XCrafting.known(r, XCrafting.recipe(457)), XCrafting.known(r, XCrafting.recipe(458))]
	_cmp(c.id + ".afterLoad", _raw_flags(r), o.afterLoad)
	check(c.id + ".known", _same(known, o.afterLoad.recipes), known)


func _case_can(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var kind := int(c.setup.kind)
	var cond := str(c.setup.cond)
	var id := 457 if kind == 0 else 458
	var base := 7900 if kind == 0 else 7902
	var s := _new_state()
	s.gain_item(XGrowthForge.FRAGMENT, 199 if cond == "frag199" else 200)
	s.gain_item(XGrowthForge.HAMMER, 4 if cond == "hammer4" else 5)
	var src = {} if cond == "none" else _gear(s, base + 1 if cond == "master" else base)
	if cond == "stranger":
		src = (src as Dictionary).duplicate(true)
	if cond == "worn":
		_equip(s, s.actor(1), src)
	if cond == "locked":
		s.crafting.erase(XGrowthForge.KINDS[id].flag)
		XCrafting.learn(s, id, false)
	if cond == "battle":
		XHeartsteel.in_battle = true
	var r := XCrafting.recipe(id)
	var got := {"can": XGrowthForge.can_forge(s, id, src), "sources": XGrowthForge.forge_sources(s, id).size(), "material": XCrafting.material_count(s, r.materials[0], r),
		"hasMaterials": XCrafting.has_materials(s, r), "craftable": XCrafting.craftable(s, r), "amount": XCrafting.amount_craftable(s, r), "known": XCrafting.known(s, r)}
	XHeartsteel.in_battle = false
	if cond == "locked":
		# 重制补解锁：结果同 ok 例
		_cmp(c.id + ".lazy", got, {"can": true, "sources": 1, "material": 1, "hasMaterials": true, "craftable": true, "amount": 1, "known": true})
		check(c.id + ".oracle_locked", not bool(o.can) and not bool(o.known), o)
		return
	_cmp(c.id, got, o)


func _case_forge(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var kind := int(c.setup.kind)
	var id := 457 if kind == 0 else 458
	var base := 7900 if kind == 0 else 7902
	var s := _new_state()
	var a := s.actor(1)
	s.gain_item(XGrowthForge.FRAGMENT, 230)
	s.gain_item(XGrowthForge.HAMMER, 7)
	var src := _gear(s, base, {XHeartsteel.STACKS: 350, XHeartsteel.LEGACY_HP: 7} if kind == 0 else {XHubris.FAME: 420})
	var other := _gear(s, base)
	# 词条两边掷法不同（参照随机数恒 0.5，掷到一条不改名、只加特性的），属性与特性照参照设
	src.params = (o.before.params as Array).map(func(v): return float(v))
	src.traits = (o.before.traits as Array).map(func(t): return {"code": int(t[0]), "dataId": int(t[1]), "value": float(t[2])})
	if str(c.setup.where) == "worn":
		_equip(s, a, src)
	_cmp(c.id + ".before", _snap(src), o.before)
	_cmp(c.id + ".actorBefore", _actor(a), o.actorBefore)
	var keep := JSON.stringify(src)
	_cmp(c.id + ".view", _snap(XGrowthForge.preview(id, src)), o.view)
	check(c.id + ".unchanged", JSON.stringify(src) == keep)
	_cmp(c.id + ".detail", XGrowthForge.detail_lines(id, src), o.detail)
	_cmp(c.id + ".help", [XGrowthForge.help_text(id, src, true, false), XGrowthForge.help_text(id, src, true, true), XGrowthForge.help_text(id, src, false, false),
		XGrowthForge.help_text(id, null, false, false)], o.help)
	_cmp(c.id + ".emptyDetail", XGrowthForge.detail_lines(id, null), o.emptyDetail)
	XGrowthForge.forge_source = src
	var out := XCrafting.craft(s, XCrafting.recipe(id))
	check(c.id + ".same", is_same(out, src) == bool(o.same))
	_cmp(c.id + ".after", _snap(src), o.after)
	_cmp(c.id + ".materials", [s.item_count(XGrowthForge.FRAGMENT), s.item_count(XGrowthForge.HAMMER)], o.materials)
	_cmp(c.id + ".counts", [_bag(s, base).size(), _bag(s, base + 1).size()], o.counts)
	check(c.id + ".otherBase", int(other.base) == int(o.otherBase))
	_cmp(c.id + ".actor", _actor(a), o.actor)
	var r := XCrafting.recipe(id)
	_cmp(c.id + ".tail", {"canAgain": XGrowthForge.can_forge(s, id, src), "canOther": XGrowthForge.can_forge(s, id, other), "craftableAfter": XCrafting.craftable(s, r),
		"materialAfter": XCrafting.material_count(s, r.materials[0], r)}, {"canAgain": o.canAgain, "canOther": o.canOther, "craftableAfter": o.craftableAfter, "materialAfter": o.materialAfter})


func _case_refuse(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_state()
	s.gain_item(XGrowthForge.FRAGMENT, 200)
	s.gain_item(XGrowthForge.HAMMER, 4)
	var src := _gear(s, 7900)
	XGrowthForge.forge_source = src
	var out := XCrafting.craft(s, XCrafting.recipe(457))
	_cmp(c.id, {"out": out.is_empty(), "base": int(src.base), "materials": [s.item_count(XGrowthForge.FRAGMENT), s.item_count(XGrowthForge.HAMMER)]}, o)


## 锻造后存档往返：杰作实例、层数、解锁都在
func _case_save() -> void:
	var s := _new_state()
	s.gain_item(XGrowthForge.FRAGMENT, 200)
	s.gain_item(XGrowthForge.HAMMER, 5)
	var src := _gear(s, 7900, {XHeartsteel.STACKS: 350})
	_equip(s, s.actor(1), src)
	XGrowthForge.forge_source = src
	XCrafting.craft(s, XCrafting.recipe(457))
	var mhp := s.actor(1).mhp
	var r := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = r
	var g := XHeartsteel.gear(r.actor(1))
	check("save.forged", XHeartsteel.is_leviathan(g) and XHeartsteel.stacks(g) == 350 and str(g.name) == "杰作利维坦" and absf(r.actor(1).mhp - mhp) < 1e-6, [g.get("name"), r.actor(1).mhp, mhp])
	check("save.unlocked", bool(r.crafting.get("codexLeviathanUnlocked", false)) and XCrafting.known(r, XCrafting.recipe(457)))


## 界面：打造类别里有杰作利维坦，确定先选原件，选好进确认，确认后同一件变成杰作并弹成功窗；取消选原件回列表
func _case_ui() -> void:
	var s := _new_state()
	s.gain_item(XGrowthForge.FRAGMENT, 200)
	s.gain_item(XGrowthForge.HAMMER, 5)
	var src := _gear(s, 7900, {XHeartsteel.STACKS: 120})
	var scene := XCraftingScene.new()
	add_child(scene)
	scene.select_category(XCrafting.CATEGORIES.find("打造"))
	scene.ok()
	var i := scene.list.find_custom(func(r): return int(r.id) == 457)
	check("ui.listed", i >= 0, scene.list.size())
	if i < 0:
		scene.queue_free()
		return
	scene.index = i
	scene.ok()
	check("ui.pick", scene.mode == "pick" and scene.picks.size() == 1 and is_same(scene.picks[0], src), [scene.mode, scene.picks.size()])
	check("ui.help", scene.forge_shown() == src and XGrowthForge.help_text(457, src, true, false).begins_with("选择: 心之钢"))
	check("ui.row", XCraftingScene.pick_row_ops(s, 457, src, 0).size() == 3 and str(XCraftingScene.pick_row_ops(s, 457, src, 0)[2][1]).contains("心钢层数:120 · 背包"))
	check("ui.detail", XCraftingScene.forge_detail_ops(457, src).size() == 5)
	# Shift：详情窗位置开原件说明卡（字号 ≤14），提示换成「返回升级预览」；取消先收卡、留在选原件
	scene.toggle_source()
	var card_rows: Array = scene.source_card.rows
	check("ui.source_card", scene.source_shown and scene.source_card.visible and not scene.detail_win.visible
		and scene.source_card.position == XCraftingScene.DETAIL_RECT.position and str(card_rows[0][0]).contains("心之钢")
		and card_rows.all(func(r): return int(r[1]) <= 14) and card_rows.any(func(r): return str(r[0]).contains("心钢层数120")),
		[scene.source_shown, scene.source_card.visible, card_rows.map(func(r): return [r[0], r[1]]).slice(0, 8)])
	check("ui.source_help", XGrowthForge.help_text(457, src, true, scene.source_shown).ends_with("按 Shift 返回升级预览"))
	scene.cancel()
	check("ui.source_cancel", scene.mode == "pick" and not scene.source_shown and not scene.source_card.visible and scene.detail_win.visible, scene.mode)
	scene.toggle_source()
	scene.toggle_source()
	check("ui.source_toggle", not scene.source_card.visible and scene.detail_win.visible)
	scene.cancel()
	check("ui.pick_cancel", scene.mode == "list" and XGrowthForge.forge_source.is_empty() and int(src.base) == 7900, scene.mode)
	scene.ok()
	scene.ok()
	check("ui.confirm", scene.mode == "confirm" and is_same(XGrowthForge.forge_source, src), scene.mode)
	scene.ok()
	check("ui.forged", scene.mode == "popup" and int(src.base) == 7901 and scene.popup_text.contains("杰作利维坦") and XGrowthForge.forge_source.is_empty(), [scene.mode, src.base, scene.popup_text])
	check("ui.spent", s.item_count(XGrowthForge.FRAGMENT) == 0 and s.item_count(XGrowthForge.HAMMER) == 0)
	scene.ok()
	check("ui.back", scene.mode == "list" and not XCrafting.craftable(s, XCrafting.recipe(457)), scene.mode)
	scene.queue_free()


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in data.cases:
		check(c.id + ".oracle", (c.errors as Array).is_empty(), c.errors)
		var id := str(c.id)
		if id.begins_with("core."):
			_case_core(c)
		elif id == "unlock.flow":
			_case_unlock_flow(c)
		elif id.begins_with("unlock.master."):
			_case_unlock_master(c)
		elif id.begins_with("unlock.load."):
			_case_unlock_load(c)
		elif id.begins_with("can."):
			_case_can(c)
		elif id == "forge.refuse":
			_case_refuse(c)
		elif id.begins_with("forge."):
			_case_forge(c)
		else:
			check(id + ".unhandled", false)
	_case_save()
	_case_ui()
	XHeartsteel.in_battle = false
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_growth_forge", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
