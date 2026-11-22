extends Node
## T395 天启篇奖碑必掉（XTianqiDrop.MEDAL_SURE）：
## 一、35 种奖碑＝Items.json 名字以「奖碑」开头的全部；面板概率 1，别的道具照旧原表 × 0.2。
## 二、实打 1 层守层者里德（部队 4）：天启篇新档首场必得 9 号「奖碑：里德」，换 20 个种子都一样。
## 三、59 行奖碑掉落（守层者 35 行＋求道者等 24 行）的招牌键在荒年这类减掉率（p＜1）下也照给；非奖碑不受影响。
## 四、开关关掉回到原表 × 0.2。
## 五、西游档零变化：开关开关两种下，里德的掉落行、掉落结果完全一样，且没有 sig。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_medal_sure")
	_list()
	_reed_battle()
	_all_rows()
	_switch()
	_xiyou_unchanged()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _medal_rows() -> Array:
	var out := []
	var en: Array = XDB.table("Enemies")
	for e in en:
		if not e is Dictionary:
			continue
		for d in e.get("dropItems", []):
			if int(d.kind) == 1 and XTianqiDrop.MEDALS.has(int(d.dataId)):
				out.append([int(e.id), int(d.dataId), float(d.denominator), str(e.name)])
	return out


func _list() -> void:
	var names := []
	for it in XDB.table("Items"):
		if it is Dictionary and str(it.get("name", "")).begins_with("奖碑"):
			names.append(int(it.id))
	names.sort()
	var want: Array = XTianqiDrop.MEDALS.duplicate()
	want.sort()
	_check("medals_are_all_named", names == want and want.size() == 35, [names.size(), want.size()])
	_check("medal_base_one", is_equal_approx(XTianqiDrop.signature_base(1, 9, 1.0), 1.0) and is_equal_approx(XTianqiDrop.signature_base(1, 1556, 1.0), 1.0),
		XTianqiDrop.signature_base(1, 9, 1.0))
	_check("other_item_unchanged", is_equal_approx(XTianqiDrop.signature_base(1, 1060, 1.0), 0.2) and is_equal_approx(XTianqiDrop.signature_base(1, 403, 1.0), 0.2),
		[XTianqiDrop.signature_base(1, 1060, 1.0), XTianqiDrop.signature_base(1, 403, 1.0)])
	_check("medal_not_full_row_unchanged", is_equal_approx(XTianqiDrop.signature_base(1, 9, 0.1), 0.02), XTianqiDrop.signature_base(1, 9, 0.1))
	var rows := _medal_rows()
	var guardians := rows.filter(func(r): return str(r[3]).contains("守层者"))
	_check("medal_rows_59_all_sure", rows.size() == 59 and guardians.size() == 35 and rows.all(func(r): return float(r[2]) == 1.0), [rows.size(), guardians.size()])


func _reed_battle() -> void:
	var got := []
	var rows_ok := true
	for i in 20:
		var s := Kit.new_game("xunchang", "war", 1000 + i)
		s.map_id = 5
		var before := s.item_count(9)
		var lg := XBattleLogic.new()
		lg.setup(4, s)
		if i == 0:
			_check("troop4_is_reed", lg.enemies.size() > 0 and lg.enemies[0].enemy_id == 6, lg.enemies.map(func(e): return e.enemy_id))
		var row9 := lg.drop_chances(lg.enemies[0]).filter(func(r): return int(r.kind) == 1 and int(r.id) == 9)
		rows_ok = rows_ok and row9.size() == 1 and row9[0].has("sig") and is_equal_approx(float(row9[0].chance), 1.0)
		for e in lg.enemies:
			e.hp = 0
		var rw: Dictionary = lg.rewards()
		var has9 := (rw.drops as Array).any(func(d): return int(d.kind) == 1 and int(d.id) == 9)
		lg.grant(rw)
		got.append([has9, s.item_count(9) - before])
		lg.end_battle(0)
	_check("reed_row_chance_one", rows_ok)
	_check("reed_first_kill_always_medal", got.all(func(g): return g[0] and g[1] == 1), got)


func _all_rows() -> void:
	var s := Kit.new_game("xunchang")
	var bad := []
	for r in _medal_rows():
		var key := "%d:1:%d" % [r[0], r[1]]
		if not XTianqiDrop.roll_signature(s, key, 0.2 * 0.67):  # 荒年 ×0.67 也照给
			bad.append(key)
	_check("all_medal_rows_sure_under_lean_year", bad.is_empty(), bad)
	var misses := 0
	for n in 30:
		if not XTianqiDrop.roll_signature(s, "6:1:1060", 0.2):
			misses += 1
	_check("non_medal_still_rolls", misses > 0, misses)
	_check("non_drop_key_not_forced", not XTianqiDrop._sure_medal_key("7:1:9") and XTianqiDrop._sure_medal_key("6:1:9") and not XTianqiDrop._sure_medal_key("6:2:9"))


func _switch() -> void:
	XTianqiDrop.MEDAL_SURE = false
	_check("switch_off_base", is_equal_approx(XTianqiDrop.signature_base(1, 9, 1.0), 0.2), XTianqiDrop.signature_base(1, 9, 1.0))
	_check("switch_off_key", not XTianqiDrop._sure_medal_key("6:1:9"))
	var s := Kit.new_game("xunchang")
	s.map_id = 5
	var lg := XBattleLogic.new()
	lg.setup(4, s)
	var row9 := lg.drop_chances(lg.enemies[0]).filter(func(r): return int(r.kind) == 1 and int(r.id) == 9)
	_check("switch_off_row_back", row9.size() == 1 and float(row9[0].chance) < 0.5, row9)
	lg.end_battle(1)
	XTianqiDrop.MEDAL_SURE = true


func _xiyou_rows(on: bool) -> Array:
	XTianqiDrop.MEDAL_SURE = on
	var old := XState.new_game_blank()
	XState.current = old
	old.map_id = 5
	var lg := XBattleLogic.new()
	lg.setup(4, old)
	var rows := lg.drop_chances(lg.enemies[0])
	for e in lg.enemies:
		e.hp = 0
	var drops: Array = lg.rewards().drops
	lg.end_battle(1)
	XTianqiDrop.MEDAL_SURE = true
	return [rows, drops]


func _xiyou_unchanged() -> void:
	var a := _xiyou_rows(true)
	var b := _xiyou_rows(false)
	_check("xiyou_no_sig", (a[0] as Array).all(func(r): return not r.has("sig")), a[0])
	_check("xiyou_rows_same", JSON.stringify(a[0]) == JSON.stringify(b[0]), [a[0], b[0]])
	var row9 := (a[0] as Array).filter(func(r): return int(r.kind) == 1 and int(r.id) == 9)
	_check("xiyou_reed_medal_twenty_pct", row9.size() == 1 and float(row9[0].chance) < 0.5, row9)
