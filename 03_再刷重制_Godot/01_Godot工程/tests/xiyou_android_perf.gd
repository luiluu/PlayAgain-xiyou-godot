extends Node
## 安卓卡顿（Kyo 11-12 v0.01 实机：战斗放技能卡、商店买东西卡）：
## - 带闪烁光标的窗口（XMVCanvas.blink）不再每帧整块重画：光标画在背后一层，每帧只重画那层（O-待定-1，回退 BLINK_FULL_REDRAW）；
## - 动画图、音效按路径留住最近用过的（O-待定-2，回退 MVAnimation.RES_CACHE）；
## - 商店说明卡同一件商品不重排（O-待定-3，回退 XShop.HELP_SAME_SKIP）。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	await _canvas()
	_res_cache()
	await _shop()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


class Counter extends RefCounted:
	var paints := 0
	var layer := 0


func _blink_canvas(full: bool) -> Counter:
	XMVCanvas.BLINK_FULL_REDRAW = full
	var n := Counter.new()
	var c := XMVCanvas.new()
	c.size = Vector2(300, 200)
	c.blink = true
	c.painter = func(cv: XMVCanvas):
		n.paints += 1
		cv.cursor(Rect2(0, 0, 300, 36))
		cv.text("测试", 6, 0, 200)
	c._cursor_layer.draw.connect(func(): n.layer += 1)
	add_child(c)
	await frames(2)
	n.paints = 0
	n.layer = 0
	await frames(30)
	c.queue_free()
	await frames(1)
	return n


func _canvas() -> void:
	var on := await _blink_canvas(false)
	check("blink_no_full_redraw", on.paints == 0 and on.layer >= 25, [on.paints, on.layer])
	var c := XMVCanvas.new()
	c.blink = true
	c.size = Vector2(300, 200)
	c.painter = func(cv: XMVCanvas): cv.cursor(Rect2(0, 36, 300, 36))
	add_child(c)
	await frames(2)
	check("blink_cursor_on_layer", c._blink_cursors == [Rect2(0, 36, 300, 36)] and c._cursor_layer.show_behind_parent)
	c.blink = false
	c.queue_redraw()
	await frames(2)
	check("still_cursor_drawn_inline", c._blink_cursors.is_empty())
	c.queue_free()
	# 回退：每帧整块重画
	var off := await _blink_canvas(true)
	check("blink_rollback_full_redraw", off.paints >= 25, [off.paints, off.layer])
	XMVCanvas.BLINK_FULL_REDRAW = false


func _res_cache() -> void:
	var p := XDB.img_path("animations", str(_any_anim_sheet()))
	if p == "":
		check("anim_sheet_found", false)
		return
	MVAnimation._res_cache.clear()
	MVAnimation._res_order.clear()
	var a := MVAnimation.cached_load(p)
	var b := MVAnimation.cached_load(p)
	check("res_cache_keeps", a != null and is_same(a, b) and MVAnimation._res_cache.has(p))
	for i in MVAnimation.RES_CACHE_MAX + 3:
		MVAnimation._res_cache["fake%d" % i] = null
		MVAnimation._res_order.append("fake%d" % i)
	MVAnimation.cached_load(XDB.img_path("animations", str(_any_anim_sheet(1))))
	check("res_cache_capped", MVAnimation._res_order.size() == MVAnimation.RES_CACHE_MAX and not MVAnimation._res_cache.has(p), MVAnimation._res_order.size())
	MVAnimation._res_cache.clear()
	MVAnimation._res_order.clear()
	MVAnimation.RES_CACHE = false
	var c := MVAnimation.cached_load(p)
	check("res_cache_rollback", c != null and MVAnimation._res_cache.is_empty())
	MVAnimation.RES_CACHE = true


## 动画表里第 k 个有图的动画图名
func _any_anim_sheet(k := 0) -> String:
	var seen := 0
	for id in range(1, 400):
		var a := XDB.rec("Animations", id)
		var n := str(a.get("animation1Name", ""))
		if n != "" and XDB.img_path("animations", n) != "":
			if seen == k:
				return n
			seen += 1
	return ""


func _shop() -> void:
	XState.current = XState.new_game(3, 1, [8, 9, 10])
	XState.current.gain_gold(50000)
	var sh := XShop.new()
	sh.setup([[0, 732, 0, 0], [1, 1, 0, 0], [2, 4375, 0, 0]], false)
	add_child(sh)
	await frames(2)
	sh._cmd = 0
	sh._ok()
	await frames(1)
	var first: Array = sh.help_card.rows
	sh._refresh()
	check("help_same_item_not_relaid", sh.help_card.visible and is_same(sh.help_card.rows, first) and not first.is_empty())
	sh._move(1, true)
	sh._refresh()
	check("help_new_item_relaid", not is_same(sh.help_card.rows, first))
	XShop.HELP_SAME_SKIP = false
	var second: Array = sh.help_card.rows
	sh._refresh()
	check("help_rollback_relays", not is_same(sh.help_card.rows, second))
	XShop.HELP_SAME_SKIP = true
	sh._cancel()
	check("help_hidden_on_command", not sh.help_card.visible)
	sh.queue_free()
	await frames(1)
