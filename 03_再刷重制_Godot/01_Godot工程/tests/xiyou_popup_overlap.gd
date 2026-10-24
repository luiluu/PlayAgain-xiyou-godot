extends "res://tests/xiyou_battle_ui.gd"
## 隔离画面夹具：真实101消息窗与真实_popup同帧重叠，不修改游戏层级/寿命。
## 另对照原版普通伤害／回复叠加的纵向锚点（fixtures/popup_anchor_oracle.json）。


func _run() -> void:
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026101300000001"
	s.map_id = 5
	s.x = 10
	s.y = 10
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	if not ok:
		_finish()
		return
	var map: XMapScene = get_tree().current_scene
	XMessageBox.auto = false
	map._set_busy(true)
	var battle_go := func(): await map.start_battle(2, true, false)
	battle_go.call()
	ok = await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("command_shown", ok)
	if not ok:
		_finish()
		return
	var b: XBattleScene = _battle(map)
	b.cmd_win.active = false
	b.cmd_win.hide()
	var msg := {"face": "", "index": 0, "background": 0, "position": 1, "lines": ["天空中的圣雷积攒到了极限"]}
	var message_go := func(): await b.message.run(msg)
	message_go.call()
	ok = await _until(func(): return b.message.win.openness == 255 and b.message.win.pause)
	_check("message_ready", ok)
	var mr := Rect2(b.message.global_position + b.message.win.position, b.message.win.size)
	_check("formal_message_rect", mr == Rect2(0, 274, 1280, 172), [mr.position, mr.size])
	await _shot("popup_baseline")
	b._popup(b.logic.enemies[0], 9876.0, false)
	var p: XDamagePopup = b._popups[b.logic.enemies[0]][-1]
	# 保留真实生成位置与真实5帧轨迹，只停此弹数的物理更新以获得同帧控制图。
	p.set_physics_process(false)
	for i in range(10):
		p._update()
	p.queue_redraw()
	var width := p._font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.FONT_SIZE).x + p.BUFFER
	var pr := Rect2(p.global_position + Vector2(p._x - width * 0.5, p._y - p.FONT_SIZE * p.anchor_y()), Vector2(width, p.FONT_SIZE))
	_check("popup_alive_and_overlaps", p._duration == 80 and pr.intersects(mr), [p._duration, pr.position, pr.size])
	_check("production_popup_layer", p.z_index == XBattleScene.POPUP_Z and p.z_index > 5 and p.z_index < b.message.z_index, [p.z_index, b.message.z_index])
	await _shot("popup_overlap")
	var red_covered := _red_pixels(pr.intersection(mr))
	b.message.hide()
	await _shot("popup_window_hidden")
	b.message.show()
	# 故意恢复修复前z20，仅作负控截图；截图后恢复，不作为游戏行为。
	p.z_index = 20
	await _shot("popup_z20_negative_control")
	var red_z20 := _red_pixels(pr.intersection(mr))
	if red_covered >= 0:
		_check("rendered_window_covers_popup", red_z20 > red_covered + 20, [red_covered, red_z20])
	p.z_index = XBattleScene.POPUP_Z
	if out_dir != "":
		var f := FileAccess.open(out_dir.path_join("popup_overlap.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"message": [mr.position.x, mr.position.y, mr.size.x, mr.size.y], "popup": [pr.position.x, pr.position.y, pr.size.x, pr.size.y], "duration": p._duration, "z": [p.z_index, b.message.z_index], "text": p.text, "redCoveredAndZ20": [red_covered, red_z20]}, "  "))
	p.queue_free()
	_check_anchor_oracle(b)
	for pl in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		pl.stop()
	await get_tree().create_timer(0.5, true, false, true).timeout
	_finish()


func _red_pixels(rect: Rect2) -> int:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return -1
	var img := get_viewport().get_texture().get_image()
	var count := 0
	for y in range(int(rect.position.y), int(ceilf(rect.end.y))):
		for x in range(int(rect.position.x), int(ceilf(rect.end.x))):
			var c := img.get_pixel(x, y)
			if c.r8 > 180 and c.r > c.g * 1.4 and c.r > c.b * 1.4:
				count += 1
	return count


## 真实 _popup 依次弹出原版七种组合（敌人 0／角色 0），逐个比纵向锚点；单个普通伤害再比 5 帧后的顶边（原版 302）
func _check_anchor_oracle(b: XBattleScene) -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/popup_anchor_oracle.json"))
	var targets := {"enemy": b.logic.enemies[0], "actor": b.logic.actors[0]}
	var bad := []
	for key in oracle.cases:
		var t: XBattler = targets[key.split("_")[0]]
		b._popups[t] = []
		var made := []
		for row in oracle.cases[key]:
			b._popup(t, float(row.value), false)
			var q: XDamagePopup = b._popups[t][-1]
			q.set_physics_process(false)
			made.append(q)
		for i in made.size():
			var want: float = oracle.cases[key][i].anchor[1]
			if made[i].anchor_y() != want:
				bad.append([key, i, made[i].anchor_y(), want])
		if key == "enemy_damage":
			var q: XDamagePopup = made[0]
			for i in range(oracle.after_frames * 2):
				q._update()
			var top: float = q.global_position.y + q._y - q.FONT_SIZE * q.anchor_y()
			_check("popup_anchor_damage_top", absf(top - float(oracle.cases[key][0].bounds[1])) < 0.5, [top, oracle.cases[key][0].bounds])
		for q in made:
			q.queue_free()
		b._popups[t] = []
	_check("popup_anchor_oracle", oracle.errors.is_empty() and oracle.cases.size() == 14 and bad.is_empty(), bad)
