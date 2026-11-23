extends Node
## T395 天启篇奖碑必掉（XTianqiDrop.MEDAL_SURE）：
## 一、35 种奖碑＝Items.json 名字以「奖碑」开头的全部；面板概率 1，别的道具照旧原表 × 0.2。
## 二、实打 1 层守层者里德（部队 4）：天启篇新档首场必得 9 号「奖碑：里德」，换 20 个种子都一样。
## 三、59 行奖碑掉落（守层者 35 行＋求道者等 24 行）的招牌键在荒年这类减掉率（p＜1）下也照给；非奖碑不受影响。
## 四、开关关掉回到原表 × 0.2。
## 六、补（Kyo 11-22）：乌尔奇奥拉（2025，能反复打）身上的镇元大仙奖碑照原表 × 0.2（掉落行、图鉴都是）；
##   天道信物 1958（天道使者 747）、典藏版日志 1961（求道者 766）、究极进化花仙子配方 1001（萨麦尔格 833）首场必掉。
## 五、西游档零变化：开关开关两种下，里德的掉落行逐字节一样，且没有 sig（掉落结果每次空档种子不同，只跑通不比）。

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
	_exclude_and_extra()
	_shrine_famine()
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
		if int(r[0]) in XTianqiDrop.SURE_EXCLUDE_ENEMIES:
			continue
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


func _first_fight(troop: int, item: int, seed_: int) -> Array:
	var s := Kit.new_game("xunchang", "war", seed_)
	s.map_id = 5
	var before := s.item_count(item)
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	var row := []
	for e in lg.enemies:
		row.append_array(lg.drop_chances(e).filter(func(r): return int(r.kind) == 1 and int(r.id) == item))
		e.hp = 0
	var rw: Dictionary = lg.rewards()
	lg.grant(rw)
	lg.end_battle(0)
	return [row.map(func(r): return float(r.chance)), s.item_count(item) - before]


func _exclude_and_extra() -> void:
	# 乌尔奇奥拉：面板、招牌键、实战掉落行都不是必掉
	_check("ulquiorra_base_original", is_equal_approx(XTianqiDrop.signature_base(1, 1551, 1.0, 2025), 0.2) and is_equal_approx(XTianqiDrop.signature_base(1, 1551, 1.0, 532), 1.0),
		[XTianqiDrop.signature_base(1, 1551, 1.0, 2025), XTianqiDrop.signature_base(1, 1551, 1.0, 532)])
	_check("ulquiorra_key_not_sure", not XTianqiDrop._sure_medal_key("2025:1:1551") and XTianqiDrop._sure_medal_key("532:1:1551"))
	var u := _first_fight(2027, 1551, 2000)
	_check("ulquiorra_row_not_sure", (u[0] as Array).size() == 1 and float(u[0][0]) < 0.5, u)
	var s := Kit.new_game("xunchang")
	var book := XMapTransfer.drops(s, XDB.rec("Enemies", 2025)).filter(func(r): return int(r.kind) == 1 and int(r.id) == 1551)
	var book_g := XMapTransfer.drops(s, XDB.rec("Enemies", 532)).filter(func(r): return int(r.kind) == 1 and int(r.id) == 1551)
	# 图鉴：里德的奖碑显示 100%（小A 核 P3-3：加成为负时 map_transfer 也直接给 100，负加成没造出来，只测正常档）
	var book_reed := XMapTransfer.drops(s, XDB.rec("Enemies", 6)).filter(func(r): return int(r.kind) == 1 and int(r.id) == 9)
	_check("book_medal_100", book_reed.size() == 1 and is_equal_approx(float(book_reed[0].rate), 100.0), book_reed)
	_check("ulquiorra_book_not_100", book.size() == 1 and float(book[0].rate) < 50.0 and book_g.size() == 1 and is_equal_approx(float(book_g[0].rate), 100.0), [book, book_g])
	# 八样一次性道具（1958／1961／1001＋724～728）：首场必掉（各换 10 个种子）
	for spec in [[747, 1958], [766, 1961], [833, 1001], [407, 724], [408, 725], [409, 726], [410, 727], [411, 728]]:
		var got := []
		for i in 10:
			got.append(_first_fight(spec[0], spec[1], 3000 + i))
		_check("extra_first_kill_%d" % spec[1], got.all(func(g): return (g[0] as Array).size() >= 1 and (g[0] as Array).all(func(c): return is_equal_approx(c, 1.0)) and int(g[1]) >= 1), got)
	_check("extra_switch_off", (func():
		XTianqiDrop.MEDAL_SURE = false
		var v := XTianqiDrop.signature_base(1, 1958, 1.0)
		XTianqiDrop.MEDAL_SURE = true
		return is_equal_approx(v, 0.2)).call())
	# T401：混沌避难所五件祭祀物 724～728（敌人 459～463）开关关掉回原 × 0.2，图鉴显示 100%
	for k in 5:
		var it := 724 + k
		var off: float = (func() -> float:
			XTianqiDrop.MEDAL_SURE = false
			var v: float = XTianqiDrop.signature_base(1, it, 1.0, 459 + k)
			XTianqiDrop.MEDAL_SURE = true
			return v).call()
		_check("shrine_switch_off_%d" % it, is_equal_approx(off, 0.2), off)
		var bk := XMapTransfer.drops(s, XDB.rec("Enemies", 459 + k)).filter(func(r): return int(r.kind) == 1 and int(r.id) == it)
		_check("shrine_book_100_%d" % it, bk.size() == 1 and is_equal_approx(float(bk[0].rate), 100.0), bk)


## T401 返修（小A 核 P1-1／P2-1）：荒年这类减掉率（p＜1）下，724～728（<Enemy Drops> 100%）招牌键命中必掉、roll_signature 照给
func _shrine_famine() -> void:
	var s := Kit.new_game("xunchang", "war", 4100)
	for k in 5:
		var key := "%d:1:%d" % [459 + k, 724 + k]
		_check("shrine_key_sure_%d" % (724 + k), XTianqiDrop._sure_medal_key(key), key)
		_check("shrine_famine_roll_%d" % (724 + k), XTianqiDrop.roll_signature(s, key, 0.67) and XTianqiDrop.roll_signature(s, key, 0.3), key)
	# 非必掉的 <Enemy Drops> 小概率行（铁马 831 的 1001 配方 0.1%）不算
	_check("extra_low_rate_not_sure", not XTianqiDrop._sure_medal_key("831:1:1001"))
	# 已有的三样与奖碑在荒年下同样命中（dropItems 路径）
	for spec in [[871, 1958], [892, 1961], [983, 1001], [6, 9]]:
		_check("famine_sure_%d" % spec[1], XTianqiDrop._sure_medal_key("%d:1:%d" % spec), spec)
