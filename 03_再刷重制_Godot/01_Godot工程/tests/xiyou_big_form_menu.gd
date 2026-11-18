extends "res://tests/xiyou_battle_actor_size.gd"
## 【cc·天启篇】T208：大型变身（米拉黑龙、渡鸦神话，BIG_FORM_H＝200）行动时指令环（连同「某某的行动」）与战技／物品列表让开身体（XBattleScene.make_room_for_big）。
## 核：① 167／168 行动时指令环、列表都不压其身体可见框，不出屏、不压行动顺序条；外侧压到队友时改放画面下方中间；
##     只有两人（外侧放得下）时走外侧：环在身体左边、上下不动，不压队友；
##   ② 普通大小角色（狗逍遥、里德）指令环、列表位置与开关关（BIG_MAKE_ROOM＝false）逐像素一样；开关关时龙身确实被压（断言咬得住）；
##   ③ 头顶宝石：指令环开着淡出、关掉淡入（原逻辑）；T197 小A P2-2：set_target(null) 等淡出的 HIDE_DELAY 里不淡入、消息窗开着当作挡住，
##     两个开关关掉时确实会淡入（咬得住）。
## 窗口模式加 -- --out=<目录> 出首领战米拉黑龙、渡鸦神话行动时各一张 1280×720 原尺寸截图（另出列表展开各一张）。
## 用法：Godot --audio-driver Dummy --path . res://tests/xiyou_big_form_menu.tscn [-- --out=<目录>]

const BIG := [167, 168]


func _run() -> void:
	if _windowed():
		get_window().size = Vector2i(1280, 720)
		await _frames(5)
		DirAccess.make_dir_recursive_absolute(out_dir)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.touch_override = 0
	XSave.dir_override = "user://test_xiyou_big_form_menu"
	XConfig.path_override = ProjectSettings.globalize_path(XSave.dir().path_join("options.json"))
	XConfig._loaded_path = "<unloaded>"
	XConfig.set_party_formation(XPartyFormation.ROWS)
	XEnemy.force_roll = 100.0
	var keep_s: float = XBattleLayout.ACTOR_SIZE
	XBattleLayout.ACTOR_SIZE = 1.6
	_check("big_form_h_200", is_equal_approx(XBattleLayout.BIG_FORM_H, 200.0), XBattleLayout.BIG_FORM_H)
	for troop in [BOSS_TROOP, MOB_TROOP]:
		await _four(troop)
	await _two()
	await _touch()
	XBattleLayout.ACTOR_SIZE = keep_s
	_finish()


func _prep(s: XState) -> void:
	s.switches[2494] = true
	s.actor_advance[XRaven.ACTOR] = 5  # 渡鸦满进阶：技能按真实解锁门槛学全（setupRaven），战技列表是真实技能表（P2-1）
	XRaven.sync(s.actor(XRaven.ACTOR))
	s.raven["myth"] = 3
	s.actor_advance[XMira.ACTOR] = 3
	var m := s.actor(XMira.ACTOR)
	m.learn_skill(10161)
	m.state_ids.append(XMira.DRAGON)


func _big_battle(troop: int, party: Array) -> XBattleScene:
	var b := await _battle(troop, party, _prep)
	for a in b.logic.actors:
		if a.actor_id == XMira.ACTOR:
			var mira: XBattlerSprite = b.sprites[a]
			b.logic._state_add(a, XMira.DRAGON)
			await _until(func(): return str(mira._look_key).contains("MiraDragon"), 60)
	await _frames(5)
	return b


func _actor(b: XBattleScene, id: int) -> XActor:
	for a in b.logic.actors:
		if a.actor_id == id:
			return a
	return null


## 关掉现有窗口，给 a 新建指令环并按真实战斗的摆法放好
func _ring_for(b: XBattleScene, a: XActor) -> XSkinBattleRing:
	b._close_windows()
	var w = XSkinBattle.command(b.ui, b._command_entries(a), b.CMD_W, a)
	b.cmd_win = w
	b._place_near_actor(w, a)
	return w as XSkinBattleRing


## 给 a 开真实的技能列表并按真实战斗摆法放好：照指令环上的技能类指令（同 _command_for 的 stype 过滤，含屠苏包装），
## 取技能最多的那一类，标题＝指令名（不填假技能；协调预筛 P2-1）
func _list_for(b: XBattleScene, a: XActor) -> XSkinBattleSkillList:
	b._close_windows()
	var best := []
	var title := ""
	for o in b._command_entries(a):
		var k := str(o.get("key", ""))
		if not k.begins_with("stype:"):
			continue
		var st := int(k.substr(6))
		var es: Array = b.logic.battle_skills(a).filter(func(x): return XTusu.battle_listed(a, x, st))
		if es.size() > best.size():
			best = es
			title = str(o.text)
	var rows := best.map(func(e): return b._list_entry(a, e, false))
	rows = XSkinBattle.decorate_all(b.logic, a, best, rows, false)
	var w = XSkinBattle.list(b.ui, rows, b.LIST_W, false, a, title)
	b.list_win = w
	b._place_near_actor(w, a, Vector2(16, 16))
	notes.append({"list_for": a.actor_id, "title": title, "n": best.size(), "names": best.map(func(e): return str(e.get("name", "")))})
	return w as XSkinBattleSkillList


## 位置有效：不压身体、在画面里、不压行动顺序条
func _clear(tag: String, b: XBattleScene, w: Control, body: Rect2) -> void:
	var m := b.menu_rect(w)
	_check(tag + "_clear_body", not m.intersects(body), [m, body])
	_check(tag + "_on_screen", Rect2(Vector2.ZERO, XBattleScene.BOX).grow(0.5).encloses(m), m)
	_check(tag + "_clear_otb", not m.intersects(XSkinOTBBar.occupied_rect()), [m, XSkinOTBBar.occupied_rect()])


func _teammates_hit(b: XBattleScene, a: XActor, m: Rect2) -> Array:
	var out := []
	for o in b.logic.actors:
		if o != a and m.intersects(XBattleScene.body_rect(b.sprites[o]).grow(-6.0)):
			out.append(o.actor_id)
	return out


func _four(troop: int) -> void:
	var tname := "首领战" if troop == BOSS_TROOP else "小怪战"
	var b := await _big_battle(troop, [1, 11, 167, 168])
	b.party_fold.set_expanded(false, false)
	await _secs(0.6)
	for id in [1, 11, 167, 168]:
		var a := _actor(b, id)
		var tag := "%s_%d" % [tname, id]
		if a == null:
			_check(tag + "_present", false)
			continue
		var body := b.big_body_rect(a)
		_check(tag + "_big_detect", body.has_area() == (id in BIG), body)
		# 开关关：原摆法（普通角色的基准；大型变身的用来证明确实压身体）
		XBattleScene.BIG_MAKE_ROOM = false
		var old_ring := _ring_for(b, a)
		var old_pos := old_ring.position
		var old_m := b.menu_rect(old_ring)
		var old_list := _list_for(b, a)
		var old_list_pos := old_list.position
		var old_list_m := b.menu_rect(old_list)
		XBattleScene.BIG_MAKE_ROOM = true
		var ring := _ring_for(b, a)
		var m := b.menu_rect(ring)
		if id in BIG:
			_check(tag + "_old_hits_body", old_m.intersects(body) and old_list_m.intersects(body), [old_m, old_list_m, body])
			_clear(tag + "_ring", b, ring, b.big_body_rect(a))
			var outer := absf(m.end.x - (body.position.x - XBattleScene.BIG_ROOM_GAP)) <= 0.5
			# 外侧（右边贴身体左边）时不压队友、不压首领信息区；不然就是画面下方中间（底边贴画面底）
			if outer:
				_check(tag + "_ring_outer_no_teammate", _teammates_hit(b, a, m).is_empty(), _teammates_hit(b, a, m))
			else:
				_check(tag + "_ring_bottom", absf(m.end.y - (XBattleScene.BOX.y - XSkinBattleRing.MARGIN)) <= 0.5, m)
			notes.append({"troop": tname, "id": id, "ring": "外侧" if outer else "下方中间", "menu": [m.position, m.size], "body": [body.position, body.size]})
		else:
			_check(tag + "_ring_same", ring.position == old_pos, [ring.position, old_pos])
		var lw := _list_for(b, a)
		if id in BIG:
			_clear(tag + "_list", b, lw, b.big_body_rect(a))
			_check(tag + "_list_real", lw.entries.size() >= 1, lw.entries.size())
			var zone := b._boss_zone()
			_check(tag + "_list_clear_boss_info", not zone.has_area() or not b.menu_rect(lw).intersects(zone), [b.menu_rect(lw), zone])
			_check(tag + "_list_index_visible", lw.index >= lw.top and lw.index < lw.top + lw.rows, [lw.index, lw.top, lw.rows])
			# 放不下时减行数滚动（XSkinBattleSkillList.fit_rows）：选末项再缩到 300 高，行数变少、高度不超、选中行仍看得见
			if lw.rows >= 3:
				lw.select(lw.entries.size() - 1)
				var r0 := lw.rows
				var shrunk := lw.fit_rows(300.0)
				_check(tag + "_fit_rows", shrunk and lw.rows < r0 and lw.size.y <= 300.0 and lw.back.size == lw.size
					and lw.index >= lw.top and lw.index < lw.top + lw.rows, [r0, lw.rows, lw.size, lw.top, lw.index])
				_check(tag + "_fit_rows_noop", not lw.fit_rows(720.0))
		else:
			_check(tag + "_list_same", lw.position == old_list_pos, [lw.position, old_list_pos])
		if _windowed() and troop == BOSS_TROOP and id in BIG:
			b._close_windows()
			ring = _ring_for(b, a)
			b._set_active(a)
			await _secs(1.0)
			await _shot_plain("T208_首领战_%s行动_指令环" % ("渡鸦神话" if id == 167 else "米拉黑龙"))
			lw = _list_for(b, a)
			await _secs(0.8)
			await _shot_plain("T208_首领战_%s行动_战技列表" % ("渡鸦神话" if id == 167 else "米拉黑龙"))
	await _marker(b)
	await _close(b)


## 只两人（狗逍遥前排、米拉黑龙）：外侧放得下 → 走外侧
func _two() -> void:
	var b := await _big_battle(BOSS_TROOP, [1, 168])
	var a := _actor(b, 168)
	XBattleScene.BIG_MAKE_ROOM = false
	var old_y := _ring_for(b, a).position.y
	XBattleScene.BIG_MAKE_ROOM = true
	var ring := _ring_for(b, a)
	var body := b.big_body_rect(a)
	var m := b.menu_rect(ring)
	_clear("two_168_ring", b, ring, body)
	var tm := _teammates_hit(b, a, m)
	var outer := absf(m.end.x - (body.position.x - XBattleScene.BIG_ROOM_GAP)) <= 0.5
	_check("two_168_outer", outer, [m, body, old_y, tm])
	_check("two_168_outer_no_teammate", tm.is_empty(), tm)
	notes.append({"troop": "首领战两人", "id": 168, "ring": "外侧" if outer else "下方中间", "menu": [m.position, m.size], "teammate_hit": tm})
	await _close(b)


## 触屏（指令环跟着角色＋让开 A／B 键组、队伍面板）也一样不压身体
func _touch() -> void:
	XUiSkin.touch_override = 1
	var b := await _big_battle(BOSS_TROOP, [1, 11, 167, 168])
	for id in BIG:
		var a := _actor(b, id)
		var ring := _ring_for(b, a)
		_clear("touch_%d_ring" % id, b, ring, b.big_body_rect(a))
	await _close(b)
	XUiSkin.touch_override = 0


## 头顶宝石：菜单开着淡出、关掉淡入（原逻辑不变）；P2-2 等淡出时不淡入、消息窗开着挡住
func _marker(b: XBattleScene) -> void:
	var tm := b.turn_marker
	_check("marker_present", tm != null)
	if tm == null:
		return
	var a := _actor(b, 168)
	_ring_for(b, a)
	b._set_active(a)
	await _secs(0.5)
	_check("marker_hidden_menu_open", tm.alpha <= 0.01 and tm.menu_open(), tm.alpha)
	b._close_windows()
	await _secs(0.5)
	_check("marker_fades_in_menu_closed", tm.alpha >= 0.99, tm.alpha)
	# P2-2：菜单开着（宝石 0）→ 关窗同时清当前行动者，HIDE_DELAY 里一直不淡入
	for hold in [true, false]:
		XTurnMarker.HOLD_WHILE_HIDING = hold
		_ring_for(b, a)
		b._set_active(a)
		await _secs(0.5)
		b._close_windows()
		b._set_active(null)
		var peak := 0.0
		var end := Time.get_ticks_msec() + int(XTurnMarker.HIDE_DELAY * 1000.0) + 300
		while Time.get_ticks_msec() < end:
			peak = maxf(peak, tm.alpha)
			await get_tree().process_frame
		if hold:
			_check("p22_no_fade_in_while_hiding", peak <= 0.01 and tm.shown_for == null, [peak, tm.shown_for])
		else:
			_check("p22_old_fades_in", peak > 0.05, peak)   # 开关关＝旧行为：会闪出来（断言咬得住）
	XTurnMarker.HOLD_WHILE_HIDING = true
	# 消息窗开着（逃跑失败那两行时 target 还是行动者）：当作挡住；开关关不挡
	b._set_active(a)
	await _secs(0.5)
	_check("marker_shown_before_msg", tm.alpha >= 0.99, tm.alpha)
	b.message._busy = true
	await _secs(0.4)
	_check("p22_hidden_on_message", tm.blocked() and tm.alpha <= 0.01, tm.alpha)
	XTurnMarker.HIDE_ON_MESSAGE = false
	_check("p22_message_switch_off", not tm.blocked())
	XTurnMarker.HIDE_ON_MESSAGE = true
	b.message._busy = false
	await _secs(0.4)
	_check("marker_back_after_message", tm.alpha >= 0.99, tm.alpha)


func _shot_plain(name: String) -> void:
	if not _windowed():
		return
	await _frames(6)
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	_check("shot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)


func _finish() -> void:
	XBattleScene.BIG_MAKE_ROOM = true
	XTurnMarker.HOLD_WHILE_HIDING = true
	XTurnMarker.HIDE_ON_MESSAGE = true
	for n in notes:
		print("NOTE ", JSON.stringify(n))
	super._finish()
