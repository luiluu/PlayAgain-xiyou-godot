extends Node
## 行文点选窗（XChoiceWindow）的鼠标：点最后一行下方的留白不选中画面外的下一行，点行内照常选中／确定。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _click(w: XChoiceWindow, y: float) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = w.win.position + Vector2(40, y)
	w._gui_input(ev)


func _run() -> void:
	var w := XChoiceWindow.new()
	add_child(w)
	var rows := range(30).map(func(i): return {"label": "第%d行" % i})
	var picked := []
	w.open(rows, func(i): picked.append(i), func(): pass)
	await get_tree().process_frame
	var n := w.page_rows()
	var pad := XMVWindow.PADDING + w.info_height()
	check("long_list_scrolls", n < rows.size() and w.top == 0, [n, rows.size()])
	_click(w, pad + n * _lh() + 4.0)
	check("bottom_padding_no_select", w.index == 0 and w.top == 0, [w.index, w.top])
	_click(w, pad + (n - 1) * _lh() + 4.0)
	check("last_visible_row_selects", w.index == n - 1, w.index)
	w.queue_free()
	await get_tree().process_frame
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _lh() -> float:
	return XChoiceWindow.LH
