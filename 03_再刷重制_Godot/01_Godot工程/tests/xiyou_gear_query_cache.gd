extends Node
## 核查 dev.055：两个名字不同、备注/说明/能力完全相同的装备不能共享检索记录。
## 冻结 v0.28 的 CodexEquipmentQuery.record/matches 对 Armors 10/11 实测：[false,true]。
var results := []
func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))
func _ready() -> void:
	var a := XGear.template("armor", 10)
	var b := XGear.template("armor", 11)
	check("same_attributes_different_names", a.note == b.note and a.description == b.description and a.params == b.params and a.name != b.name)
	for reverse in [false, true]:
		XGearQuery._cache.clear()
		var items := [b, a] if reverse else [a, b]
		for item in items:
			XGearQuery.record(item)
		var f := XGearQuery.defaults()
		f.query = "学徒短靴"
		var got := [XGearQuery.matches(a, f), XGearQuery.matches(b, f)]
		check("independent_search_" + str(reverse), got == [false, true], got)
		f.query = "皮革裤衩子"
		got = [XGearQuery.matches(a, f), XGearQuery.matches(b, f)]
		check("independent_reverse_query_" + str(reverse), got == [true, false], got)
	_presort_and_page_cache()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


## O-待定（物品页护甲卡）：排序键（PRESORT_KEYS）与逐次 compare 的顺序逐件相同；物品页武器／护甲列表缓存（CACHE_GEAR_ENTRIES）
## 在增减装备、就地改装备、换装后都和关掉缓存重算的结果逐件相同
func _presort_and_page_cache() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	var rolls := [0.05, 0.5, 0.95, 0.999]
	var n := 0
	for id in range(1, 160):
		for kind in ["armor", "weapon"]:
			var r := XDB.rec("Armors" if kind == "armor" else "Weapons", id)
			if r.is_empty() or str(r.get("name", "")) == "":
				continue
			XGear.force_roll = rolls[n % rolls.size()]
			s.gain_gear(kind, id, 1 + n % 2)
			n += 1
	XGear.force_roll = -1.0
	var entries := s.gear.map(func(e): return {"rec": e})
	var term := ""
	for e in s.gear:
		for row in XGearQuery.record(e).rows:
			if row.number != null:
				term = row.key
				break
		if term != "":
			break
	var bad := []
	for sort in XGearQuery.SORTS:
		var f := XGearQuery.default_view()
		f.sort = sort
		f.sortTerm = term
		XGearQuery.PRESORT_KEYS = true
		var fast := XGearQuery.filter_entries(entries, f)
		XGearQuery.PRESORT_KEYS = false
		var slow := XGearQuery.filter_entries(entries, f)
		XGearQuery.PRESORT_KEYS = true
		if fast.size() != slow.size() or not range(fast.size()).all(func(i): return is_same(fast[i], slow[i])):
			bad.append(sort)
	check("presort_same_order", bad.is_empty() and entries.size() > 200 and term != "", [bad, entries.size(), term])
	XGearQuery._cache.clear()
	XGearQuery.PRESORT_KEYS = false
	var old_rec := XGearQuery.record(s.gear[0])
	XGearQuery._cache.clear()
	XGearQuery.PRESORT_KEYS = true
	check("presort_record_same", XGearQuery.record(s.gear[0]) == old_rec and XGearQuery.record(s.gear[0]) == old_rec)
	var page := XItemScene.new()
	add_child(page)
	page._cat = 3
	var same := func() -> bool:
		var a: Array = page.entries()
		var hit := is_same(a, page.entries())
		XItemScene.CACHE_GEAR_ENTRIES = false
		var b: Array = page.entries()
		XItemScene.CACHE_GEAR_ENTRIES = true
		return hit and a.size() == b.size() and range(a.size()).all(func(i): return is_same(a[i].rec, b[i].rec) and a[i].get("carry") == b[i].get("carry") and a[i].get("owner") == b[i].get("owner"))
	check("page_cache_initial", same.call())
	var armors := s.gear.filter(func(e): return e.kind == "armor")
	s.gear.erase(armors[0])
	check("page_cache_after_remove", same.call())
	var first: Dictionary = page.entries()[0].rec
	first.params[0] = int(first.params[0]) - 999999  # 就地改：按品质排时同档内顺序可能变，至少要重算
	var before_key: Array = page._gear_key.duplicate()
	page.entries()
	check("page_cache_after_inplace", page._gear_key != before_key and same.call())
	var act := s.actor(s.party[0])
	XEquipment.change(s, act, act.equips.size() - 1, null)
	var cands := s.gear.filter(func(e): return XEquipment.fits(act, 1, e))
	if not cands.is_empty():
		XEquipment.change(s, act, 1, cands[0])
	check("page_cache_after_equip", same.call())
	page.queue_free()
