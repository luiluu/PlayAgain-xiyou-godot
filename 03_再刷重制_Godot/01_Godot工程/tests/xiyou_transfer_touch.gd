extends Node
## 安卓地图传送（Kyo 11-13 转玩家反馈 v0.01.07「一点传送就卡了」，Kyo「验证一下是否真的能传送」）：
## 全程用触屏事件（ScreenTouch，开着鼠标模拟，和安卓一样）：点 HUD「地图传送」开页 → 点地图名选中 → 再点进掉落页
## → 再点一次地图名开确认（原版只认 F 键，O-380 XMapTransferScene.TAP_TRANSFER）→ 点「确定」→ 真的到了目标地图。
## 另测：掉落页点别的地图名回列表并选中、提示行写「再点地图名传送」、点提示行也能传、未解锁蜂鸣不开确认、回退开关下点不出确认。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func tap(at: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = get_viewport().get_final_transform() * at
	e.pressed = true
	Input.parse_input_event(e)
	await frames(3)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(10)


func idle(map: XMapScene) -> void:
	for i in 900:
		if map.transfer_page == null and not map.busy:
			return
		await get_tree().process_frame


func row(pg: XMapTransferScene, i: int) -> Vector2:
	return Vector2(90, XMVWindow.PADDING + (i - pg.top) * XMapTransferScene.LH + XMapTransferScene.LH / 2)


func open_page(map: XMapScene) -> XMapTransferScene:
	await tap(map.map_hud.transfer_button.get_global_rect().get_center())
	for i in 300:
		if map.transfer_page != null and map.transfer_page.is_node_ready():
			break
		await get_tree().process_frame
	await frames(4)
	return map.transfer_page


func _run() -> void:
	TestEnv.isolate("xiyou_transfer_touch")
	XMessageBox.auto = true
	XPlatform.force_mobile = true
	var emu := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	s.flags.SaveGameId = 1
	var map := XMapScene.new()
	add_child(map)
	await frames(10)
	await idle(map)
	var pg := await open_page(map)
	check("touch_opens_page", pg != null and get_tree().root.find_children("*", "XMapTransferScene", true, false).size() == 1)
	# 一层（列表第 2 行）还没去过：未解锁，点了蜂鸣、不开确认
	await tap(row(pg, 1))
	await tap(row(pg, 1))
	check("tap_enters_drops", pg.mode == "drops" and pg.index == 1, [pg.mode, pg.index])
	check("touch_hint", pg._transfer_hint() == "再点地图名传送")
	await tap(row(pg, 1))
	check("locked_tap_no_confirm", pg.mode == "drops" and not pg.confirm_win.visible)
	# 掉落页点别的地图名：回列表并选中它
	await tap(row(pg, 3))
	check("drops_tap_other_back_to_list", pg.mode == "list" and pg.index == 3, [pg.mode, pg.index])
	# 回退开关：原版点不出确认（只有 F 键）
	s.unlocked_maps[5] = true
	await tap(row(pg, 1))
	await tap(row(pg, 1))
	XMapTransferScene.TAP_TRANSFER = false
	await tap(row(pg, 1))
	check("rollback_no_tap_transfer", pg.mode == "drops" and not pg.confirm_win.visible and pg._transfer_hint() == "F传送", pg.mode)
	XMapTransferScene.TAP_TRANSFER = true
	# 点底部提示行＝按 F
	await tap(Vector2(XMapTransferScene.INFO_RECT.position.x + 200, XMapTransferScene.INFO_RECT.end.y - XMVWindow.PADDING - XMapTransferScene.LH / 2))
	check("tap_prompt_opens_confirm", pg.mode == "confirm" and pg.confirm_win.visible, pg.mode)
	# 确认框点「取消」回掉落页，再点地图名重新开确认、点「确定」真的传过去
	var cy := XMapTransferScene.CONFIRM_RECT.position.y + XMVWindow.PADDING + XMapTransferScene.LH + 12
	await tap(Vector2(640, cy + XMapTransferScene.LH * 1.5))
	await tap(Vector2(640, cy + XMapTransferScene.LH * 1.5))
	check("confirm_cancel_back", pg.mode == "drops" and not pg.confirm_win.visible, pg.mode)
	await tap(row(pg, 1))
	check("tap_name_opens_confirm", pg.mode == "confirm" and pg.confirm_index == 0, [pg.mode, pg.confirm_index])
	await tap(Vector2(640, cy + XMapTransferScene.LH / 2))
	await idle(map)
	check("touch_transfer_arrives", s.map_id == 5 and map.map_id == 5 and Vector2i(s.x, s.y) == Vector2i(11, 13) and map.transfer_page == null and not map.busy,
		[s.map_id, s.x, s.y, map.transfer_page, map.busy])
	check("one_page_only", get_tree().root.find_children("*", "XMapTransferScene", true, false).is_empty())
	# 回大厅再传一次：甜蜜之家（列表第 1 行）
	await frames(10)
	pg = await open_page(map)
	await tap(row(pg, 0))
	await tap(row(pg, 0))
	await tap(row(pg, 0))
	await tap(Vector2(640, cy + XMapTransferScene.LH / 2))
	await idle(map)
	check("touch_transfer_back_to_hub", s.map_id == 4 and map.transfer_page == null and not map.busy, [s.map_id, map.busy])
	Input.emulate_mouse_from_touch = emu
	XPlatform.force_mobile = null
	var passed := results.filter(func(r): return r["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
