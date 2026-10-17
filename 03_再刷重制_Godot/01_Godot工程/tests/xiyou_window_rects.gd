extends Node
## 各页窗口矩形对照（进度审查 25%）：九个页面（设置、装备、状态、存档、物品、技能、地图传送、挂机设置、商店）
## 打开后可见的 XMVWindow 矩形，与正式 v0.28 浏览器读数（tests/fixtures/window_rects_oracle.json）逐个对上，
## 两边都不能多出可见窗口。标准级界面验收的回归：改布局时这里先报。

var results := []
const FIXTURE := "res://tests/fixtures/window_rects_oracle.json"


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


static func _visible_rects(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is XMVWindow and (c as XMVWindow).is_visible_in_tree():
			var w: XMVWindow = c
			out.append([snappedf(w.global_position.x, 0.01), w.global_position.y, roundf(w.size.x), w.size.y])
		_visible_rects(c, out)


func _page(label: String, node: Node, want: Array) -> void:
	add_child(node)
	for i in range(6):
		await get_tree().process_frame
	var got := []
	_visible_rects(node, got)
	var left := got.duplicate()
	var missing := []
	for w in want:
		var r := [snappedf(float(w[1]), 0.01), float(w[2]), float(w[3]), float(w[4])]
		var hit := -1
		for i in range(left.size()):
			if absf(left[i][0] - r[0]) < 0.5 and left[i][1] == r[1] and left[i][2] == r[2] and left[i][3] == r[3]:
				hit = i
				break
		if hit < 0:
			missing.append([w[0]] + r)
		else:
			left.remove_at(hit)
	check(label, missing.is_empty() and left.is_empty(), {"missing": missing, "extra": left})
	node.queue_free()
	await get_tree().process_frame


func _run() -> void:
	var pages: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)).pages
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	await _page("options", XOptionsScene.new(), pages.options)
	await _page("equip", XEquipScene.new(), pages.equip)
	await _page("status", XStatusPage.new(), pages.status)
	await _page("save", XSaveScene.new(), pages.save)
	await _page("item", XItemScene.new(), pages.item)
	await _page("skill", XSkillScene.new(), pages.skill)
	await _page("transfer", XMapTransferScene.new(), pages.transfer)
	await _page("hangup", XHangUpOptionsScene.new(), pages.hangup)
	var shop := XShop.new()
	shop.setup([[0, 7, 0, 0], [0, 8, 0, 0], [1, 1, 0, 0], [2, 1, 0, 0]], false)
	await _page("shop", shop, pages.shop)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"test": "xiyou_window_rects", "passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
