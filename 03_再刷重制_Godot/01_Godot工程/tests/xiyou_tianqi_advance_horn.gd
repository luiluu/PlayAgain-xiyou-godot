extends Node
## T399：天启篇进阶表去掉伙伴号角（Kyo 11-22）。蜘蛛精（78 十三娘）新档能进第一阶；其余材料不变；西游档原样。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _horn_count(items: Array) -> int:
	return items.filter(func(p): return XDB.rec("Items", int(p[0])).get("name", "").begins_with("伙伴号角")).size()


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_advance_horn")
	var raw := {}
	for r in XAdvance.rows():
		if int(r.actor) == 78:
			raw[int(r.num)] = r
	_check("raw_has_horn", _horn_count(raw[0].items) == 1, raw[0].items)
	# 西游档：照原版，号角还在、缺号角
	var plain := XState.new_game(3, 1, [8, 9, 10])
	XState.current = plain
	plain.add_actor(78)
	var pa: XActor = plain.actor(78)
	pa.level = 999
	plain.gold = 100000000
	var pr = XAdvance.row(plain, 78)
	_check("plain_row_same", pr.items == raw[0].items and int(pr.gold) == int(raw[0].gold), pr)
	_check("plain_missing_horn", XAdvance.missing(plain, pa).any(func(t): return str(t).begins_with("伙伴号角")), XAdvance.missing(plain, pa))
	# 天启篇档
	var lineup := [1, 2, 3, 4, 5]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	XTianqi._joining = true
	s.add_actor(78)
	XTianqi._joining = false
	XState.current = s
	var a: XActor = s.actor(78)
	a.level = 999
	s.gold = 100000000
	var r0 = XAdvance.row(s, 78)
	_check("tq_no_horn", _horn_count(r0.items) == 0, r0.items)
	_check("tq_other_items_kept", r0.items.size() == raw[0].items.size() - 1, r0.items)
	_check("tq_can_advance", XAdvance.missing(s, a).is_empty(), XAdvance.missing(s, a))
	_check("tq_advance_ok", XAdvance.advance(s, a) and XAdvance.rank(s, 78) == 1, XAdvance.rank(s, 78))
	# 后几阶：号角项没了，不朽碎片照旧
	var r2 = XAdvance.row(s, 78)
	_check("tq_tier2", r2 != null and _horn_count(r2.items) == 0 and r2.items.size() == raw[1].items.size() - 1, r2)
	# 全表：天启篇没有任何一行含号角
	var left := 0
	for r in XAdvance.rows():
		s.actor_advance[int(r.actor)] = int(r.num)
		var rr = XAdvance.row(s, int(r.actor))
		if rr != null:
			left += _horn_count(rr.items)
	_check("tq_all_rows_no_horn", left == 0, left)
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
