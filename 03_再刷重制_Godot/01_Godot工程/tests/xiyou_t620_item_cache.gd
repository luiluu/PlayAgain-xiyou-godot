extends Node
## T620（O-待定，XItemScene.CACHE_ITEM_ENTRIES）：物品页物品类列表记住后，得到／用掉物品、数量变、置顶、锁定、换存档之后
## 都与关掉缓存重算的结果逐项相同；没变时直接取同一份；回退（false）每次重算。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var results := []


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _ready() -> void:
	TestEnv.isolate("xiyou_t620_item_cache")
	var s := XState.new_game_blank()
	XState.current = s
	var ids := []
	for rec in XDB.table("Items"):
		if rec is Dictionary and str(rec.get("name", "")) != "" and ids.size() < 150:
			ids.append(int(rec.id))
			s._gain_raw(int(rec.id), 1 + ids.size() % 3)
	var page := XItemScene.new()
	add_child(page)
	for cat in [0, 1, 4]:
		page._cat = cat
		var sym: String = XShop.CATEGORIES[cat][1]
		check("hit_same_array_" + sym, is_same(page.entries(), page.entries()))
		check("fresh_matches_" + sym, _same(page))
	page._cat = 0
	var first := int(page.entries()[0].rec.id)
	var steps := {
		"gain_new": func(): s._gain_raw(int(ids[0]) if s.item_count(int(ids[0])) == 0 else _absent(s), 2),
		"count_change": func(): s._gain_raw(first, 5),
		"lose_to_zero": func(): s._gain_raw(first, -s.item_count(first)),
		"toggle_top": func(): XItemMarks.toggle_top(s, page.entries()[3].rec),
		"toggle_lock": func(): XItemMarks.toggle_lock(s, page.entries()[5].rec),
		"untoggle_top": func(): XItemMarks.toggle_top(s, XDB.rec("Items", int(s.flags.TopItem[0]))),
	}
	for name in steps:
		var before: Array = page.entries()
		var snap := _dump(before)
		steps[name].call()
		var after: Array = page.entries()
		check(name + "_rebuilt", not is_same(before, after) and _dump(after) != snap, [snap.size(), after.size()])
		check(name + "_matches_fresh", _same(page))
	var top_name := str(page.entries()[0].rec.name)
	check("lock_mark_shown", page.entries().any(func(e): return str(e.rec.name).ends_with(XItemMarks.LOCK)), top_name)
	# 换存档：同样的物品也要重算（键里有存档）
	var before2: Array = page.entries()
	var s2 := XState.new_game_blank()
	for id in s.items:
		s2._gain_raw(int(id), s.item_count(int(id)))
	XState.current = s2
	check("new_state_rebuilt", not is_same(before2, page.entries()))
	check("new_state_matches_fresh", _same(page))
	# 回退：每次重算
	XItemScene.CACHE_ITEM_ENTRIES = false
	check("rollback_no_cache", not is_same(page.entries(), page.entries()))
	XItemScene.CACHE_ITEM_ENTRIES = true
	# O-030 回退（直接改数据库名字）时不缓存
	XItemMarks.LIST_ONLY_NAMES = false
	check("list_only_names_off_no_cache", not is_same(page.entries(), page.entries()))
	XItemMarks.LIST_ONLY_NAMES = true
	page.queue_free()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _absent(s: XState) -> int:
	for rec in XDB.table("Items"):
		if rec is Dictionary and str(rec.get("name", "")) != "" and int(rec.get("itypeId", 1)) == 1 and s.item_count(int(rec.id)) == 0:
			return int(rec.id)
	return 1


func _dump(list: Array) -> Array:
	return list.map(func(e): return [int(e.rec.id), str(e.rec.name), int(e.get("count", -1))])


func _same(page: XItemScene) -> bool:
	var a := _dump(page.entries())
	XItemScene.CACHE_ITEM_ENTRIES = false
	var b := _dump(page.entries())
	XItemScene.CACHE_ITEM_ENTRIES = true
	if a != b:
		print("DIFF ", a.size(), " ", b.size())
	return a == b and not a.is_empty()
