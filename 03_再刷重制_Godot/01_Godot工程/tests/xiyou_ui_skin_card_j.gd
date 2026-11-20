extends Node
## 【cc·T292·未经审查】新界面卡 J：存读档 XSkinSavePage、整队 XSkinPartyPage、角色仓库 XSkinActorWarehousePage。
## - 门控：天启篇建新页；各页回退开关、西游存档、XUiSkin.ENABLED＝false 都不建；标题「旧的回忆」按 use_skin（entry.gd 传）。
## - 存读档：T254 3.2 对应表逐行（列表行、右牌各项、三枚按钮能不能点）；确定＝默认那枚、← / → 换、X＝删除走统一确认弹窗（橙边、停在「取消」）；
##   读取灰边停在「读取」；覆盖橙边；空格直接存；存档写盘结果与旧页逐字节一致（同一份状态、同一秒，旧页存一格、新页存另一格，比文件字节）。
## - 整队：3.3 对应表（出战位五格、名单每人、右牌）；进页就在出战位；确定选人、首行「空出这一格」、X 还原、取消完成（全空时拦住）。
## - 角色仓库：3.4 对应表（页签人数、名单行、右牌「存入后」「取出后」）；Q／E 换页签、确定存取、存取末尾一行后光标夹回、只剩一人提示、取消离开。
## 带 -- --out=<目录> 且有窗口时截图：每页 800×450＋1000×450（断言真尺寸）、各状态、字体 130%、旧画法对照。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


## 真尺寸截图：窗口设成 sz，截出来的图必须正好 sz（不缩放）
func shot(name: String, sz := Vector2i(800, 450)) -> void:
	if not windowed():
		return
	var win := get_window()
	var old := win.size
	win.size = sz
	await frames(12)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_size_" + name, img.get_size() == sz, [img.get_size(), sz])
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	win.size = old
	await frames(4)


func shots(name: String) -> void:
	if not windowed():
		return
	await shot(name + "_16x9", Vector2i(800, 450))
	await shot(name + "_20x9", Vector2i(1000, 450))


func act(page: Node, action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	page._unhandled_input(e)


func key(page: Node, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	page._unhandled_input(e)


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	s.gold = 123456
	s.set_variable(20, 15)
	s.set_variable(206, 3)
	s.map_id = 4
	s.x = 10
	s.y = 10
	s.play_seconds = 3725.0
	return s


func _clear_saves() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			XSave.remove(i)


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_j")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	_clear_saves()
	await _save_gates()
	await _save_page()
	await _save_bytes()
	await _party_page()
	await _warehouse_page()
	await _font_and_old()
	_clear_saves()
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func open_save(mode: String, use_skin = null) -> XSaveScene:
	var p := XSaveScene.new()
	p.mode = mode
	p.use_skin = use_skin
	add_child(p)
	return p


# ---- 存读档 ----

func _save_gates() -> void:
	var s := _state()
	XSave.save(1)
	var p := open_save("save")
	await frames(2)
	check("save.gate.tianqi_builds", p.skin != null and not p.list_win.visible and not p.info_win.visible and not p.action_win.visible and not p.help_win.visible)
	p.queue_free()
	XSkinSavePage.ENABLED = false
	p = open_save("save")
	await frames(2)
	check("save.gate.rollback_old", p.skin == null and p.list_win.visible and p.info_win.visible)
	p.queue_free()
	XSkinSavePage.ENABLED = true
	s.flags.erase("tianqi")
	p = open_save("save")
	await frames(2)
	check("save.gate.xiyou_old", p.skin == null)
	p.queue_free()
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	XUiSkin.ENABLED = false
	p = open_save("save")
	await frames(2)
	check("save.gate.master_off_old", p.skin == null)
	p.queue_free()
	XUiSkin.ENABLED = true
	# 标题「旧的回忆」：还没有当前存档，按打开它的地方传的 use_skin
	XState.current = null
	p = open_save("load", true)
	await frames(2)
	check("save.gate.title_use_skin_true", p.skin != null and p.skin.group_key == "")
	check("save.gate.title_no_tabs", p.skin.tabs == null)
	await shots("save_from_title")
	p.queue_free()
	p = open_save("load", false)
	await frames(2)
	check("save.gate.title_use_skin_false_old", p.skin == null and p.list_win.visible)
	p.queue_free()
	# entry.gd「旧的回忆」传 use_skin＝天启篇新标题且新皮肤（O-467：重制版旧标题保持旧界面）
	var entry: Node = load("res://modes/xiyou/entry.gd").new()
	entry.call("_choose_save")
	var lp: XSaveScene = entry.find_child("LoadPage", true, false)
	check("save.gate.entry_passes_use_skin", lp != null and lp.use_skin == (XTianqiTitle.available() and XTianqiTitle.skin_on()), [lp.use_skin if lp != null else null])
	entry.free()
	XState.current = s
	XSave.remove(1)
	await frames(2)


func _save_page() -> void:
	var s := _state()
	s.actor(1).change_level(12)
	XSave.save(2)
	s.play_seconds = 99.0
	XSave.save(5)   # 最近存的一格
	var p := open_save("load")
	await frames(3)
	var sk := p.skin
	check("save.initial_recent", p.index == 4 and sk.list.index == 4, p.index)
	check("save.list_30", sk.list.items.size() == XSave.SLOTS)
	check("save.list_geometry", is_equal_approx(sk.layout.center.position.x, 40.0) and is_equal_approx(sk.layout.center.size.x, XSkinSavePage.LIST_W) and sk.row_height == 46,
		[sk.layout.center.position, sk.layout.center.size])
	var r2: Dictionary = sk.list.items[1]
	var d2 = p.data(2)
	check("save.row.valid", r2.text == "文件 2" and int(r2.icon) == int(p.plugin("Saved Icon", "0")) and r2.sub == XSkinSavePage.location(d2) and r2.sub != "" and r2.right == XSaveScene.playtime(3725.0), r2)
	var r1: Dictionary = sk.list.items[0]
	check("save.row.empty", r1.right == "空" and int(r1.icon) == int(p.plugin("Empty Icon", "0")) and r1.color == XUiSkin.TEXT_3, r1)
	# 右牌（最近存的那格）
	var info := sk.card_info()
	check("save.card.title_location", info.title == XSkinSavePage.location(p.data(5)) and info.recent, info.get("title"))
	check("save.card.subtitle", str(info.subtitle).contains(str(XDB.system().get("gameTitle", ""))) and str(info.subtitle).contains("文件 5"), info.subtitle)
	var party: Array = info.party
	check("save.card.party", party.size() == mini(5, s.party.size()) and party[0].name == str(XDB.rec("Actors", s.party[0]).get("name", "")) and str(party[0].lv).ends_with("12") and party[0].face != null, party.map(func(x): return [x.name, x.lv]))
	var data: Array = info.data
	var labels := data.map(func(x): return str(x[0]))
	check("save.card.data_six", data.size() == 6 and labels[0] == p.plugin("Save Count", "保存次数") and labels[1] == p.plugin("Playtime", "游戏时间") and str(data[2][1]) == "123,456"
		and str(data[3][1]) == "15" and str(data[4][1]) == "3" and str(data[5][1]) == XSaveScene.file_size(5) and str(data[1][1]) == XSaveScene.playtime(99.0), data)
	check("save.card.var_names", str(data[3][0]) == XSkinSavePage.var_name(20) and not str(data[3][0]).contains("<<"), data[3])
	check("save.card.save_count", int(str(data[0][1])) == int(p.data(5).get("saveCount", 0)))
	check("save.card.not_recent_other", (func(): p.index = 1; var i2 := sk.card_info(); p.index = 4; return not i2.recent).call())
	check("save.buttons_load_mode", sk.card.buttons.size() == 3 and not sk.card.buttons[0].disabled and sk.card.buttons[1].disabled and not sk.card.buttons[2].disabled and sk.card.button_index == 0,
		sk.card.buttons)
	await shots("save_load")
	# 空格
	act(p, "ui_up")
	act(p, "ui_up")
	act(p, "ui_up")
	act(p, "ui_up")
	check("save.move_to_empty", p.index == 0 and sk.card_info().get("empty", false), p.index)
	check("save.empty_buttons", sk.card.buttons[0].disabled and sk.card.buttons[2].disabled)
	act(p, "ui_accept")
	check("save.empty_load_buzz_stays", p._phase == "list" and p.skin.dialog == null)
	await shots("save_empty")
	# 读取：灰边、停在「读取」，取消回列表
	act(p, "ui_down")
	check("save.down_to_2", p.index == 1 and p.act == 0)
	act(p, "ui_accept")
	check("save.load_confirm", p._phase == "confirm" and sk.dialog != null and not sk.dialog.danger and sk.dialog.index == 0 and sk.dialog.buttons[0].text == "读取" and not str(sk.dialog.body).contains("没存"), [p._phase])
	await shots("save_load_confirm")
	act(p, "ui_cancel")
	check("save.load_confirm_cancel", p._phase == "list" and sk.dialog == null and XSave.exists(2))
	# X 删除：橙边、停在「取消」；确定＝取消；再来一次选删除
	key(p, KEY_X)
	check("save.x_delete_confirm", p._phase == "confirm" and sk.dialog.danger and sk.dialog.index == 1 and p.act == 2 and str(sk.dialog.body).contains("文件 2"), [p._phase, p.act])
	await shots("save_delete_confirm")
	act(p, "ui_accept")
	check("save.delete_default_cancel_keeps", XSave.exists(2) and p._phase == "list")
	key(p, KEY_X)
	act(p, "ui_left")
	check("save.dialog_left_to_delete", p.confirm_index == 0 and sk.dialog.index == 0)
	act(p, "ui_accept")
	check("save.delete_done", not XSave.exists(2) and p._phase == "list" and sk.list.items[1].right == "空")
	key(p, KEY_X)
	check("save.x_on_empty_buzz", p._phase == "list" and sk.dialog == null)
	# ← / → 只在能点的按钮间换（小A核 P2-2）：空格三枚都灰，不动
	act(p, "ui_right")
	check("save.right_skips_all_disabled", p.act == 0 and sk.card.button_index == 0)
	act(p, "ui_down")
	check("save.row_change_resets_default", p.act == 0)
	# 读取成功
	var loaded := [false]
	p.loaded.connect(func(): loaded[0] = true)
	p.index = 4
	p._refresh()
	# 读档模式有档的格：→ 跳过灰掉的「保存」直接到「删除」，← 回「读取」
	act(p, "ui_right")
	check("save.right_skips_disabled_save", p.act == 2 and sk.card.button_index == 2)
	act(p, "ui_left")
	check("save.left_back_to_load", p.act == 0)
	# 点灰掉的「保存」：蜂鸣、焦点框回「读取」（小A核 P3-1 同类）
	var bpos := sk.card.button_rect(1).get_center()
	var cev := InputEventMouseButton.new()
	cev.button_index = MOUSE_BUTTON_LEFT
	cev.pressed = true
	cev.position = bpos
	XSound.system_log.clear()
	sk.card.gui_input.emit(cev)
	sk.card._gui_input(cev)
	await frames(2)
	check("save.click_disabled_buzz_focus_back", XSound.system_log.has(3) and sk.card.button_index == 0 and p._phase == "list", [XSound.system_log, sk.card.button_index])
	act(p, "ui_accept")
	act(p, "ui_accept")
	check("save.load_done", loaded[0] and XSave.current_slot == 5)
	p.queue_free()
	await frames(2)
	# 存档校验失败的一格：行尾、右牌写「存档校验失败」，读取弹只有「知道了」的提示，确定回列表
	_state()
	XSave.save(8)
	var fw := FileAccess.open(XSave.path(8), FileAccess.WRITE)
	fw.store_string("坏掉的存档")
	fw.close()
	var fp := open_save("load")
	await frames(2)
	if check("save.seal_failed_made", fp.seal_failed(8), XSave.path(8)):
		fp.index = 7
		fp.act = 0
		fp._refresh()
		check("save.seal_failed_row_card", fp.skin.list.items[7].right == XSaveSeal.FAIL_TEXT and fp.skin.card_info().get("failed", false))
		act(fp, "ui_accept")
		check("save.seal_failed_notice", fp._phase == "notice" and fp.skin.dialog != null and fp.skin.dialog.buttons.size() == 1 and fp.skin.dialog.buttons[0].text == "知道了")
		await shots("save_seal_failed_notice")
		act(fp, "ui_accept")
		check("save.seal_failed_notice_back", fp._phase == "list" and fp.skin.dialog == null)
		# 校验失败格删除：实际改名留着（XSave.remove → quarantine），弹窗不写「无法找回」（小A核 P2-1）
		key(fp, KEY_X)
		check("save.seal_failed_delete_text", fp._phase == "confirm" and str(fp.skin.dialog.body).contains("改名保留") and not str(fp.skin.dialog.body).contains("无法找回"), fp.skin.dialog.body if fp.skin.dialog != null else null)
		act(fp, "ui_cancel")
	fp.queue_free()
	await frames(2)
	if XSave.exists(8):   # 存档模式覆盖校验失败格：同样写改名保留
		var fs := open_save("save")
		await frames(2)
		fs.index = 7
		fs.act = 1
		fs._refresh()
		act(fs, "ui_accept")
		check("save.seal_failed_overwrite_text", fs._phase == "confirm" and str(fs.skin.dialog.body).contains("改名保留") and not str(fs.skin.dialog.body).contains("无法找回"), fs.skin.dialog.body if fs.skin.dialog != null else null)
		act(fs, "ui_cancel")
		fs.queue_free()
	await frames(2)
	# 存档模式：默认「保存」，空格直接存，有档橙边覆盖确认
	_state()
	var sp := open_save("save")
	await frames(3)
	var ss := sp.skin
	sp.index = 6
	sp.act = ss.default_act()
	sp._refresh()
	check("save.save_mode_default", sp.act == 1 and ss.card.button_index == 1 and not ss.card.buttons[1].disabled)
	act(sp, "ui_accept")
	check("save.save_empty_direct", XSave.exists(7) and sp._phase == "list" and ss.dialog == null)
	act(sp, "ui_accept")
	check("save.overwrite_confirm", sp._phase == "confirm" and ss.dialog.danger and ss.dialog.index == 1 and ss.dialog.buttons[0].text == "覆盖")
	await shots("save_overwrite_confirm")
	ss.dialog.chosen.emit(0)
	check("save.overwrite_done", sp._phase == "list" and XSave.exists(7))
	# 游戏里（存档模式）读档：没存的进度会丢——橙边、光标停「取消」，确定＝取消、什么都不读
	var loaded2 := [false]
	sp.loaded.connect(func(): loaded2[0] = true)
	act(sp, "ui_left")
	check("save.save_mode_left_to_load", sp.act == 0 and not ss.card.buttons[0].disabled)
	act(sp, "ui_accept")
	check("save.save_mode_load_danger", sp._phase == "confirm" and ss.dialog.danger and ss.dialog.index == 1 and sp.confirm_index == 1 and str(ss.dialog.body).contains("当前未保存的进度会丢失，无法找回。") and str(ss.dialog.body).begins_with("读取后将回到文件 7"), [sp._phase, ss.dialog.body if ss.dialog != null else null])
	await shots("save_save_mode_load_confirm")
	act(sp, "ui_accept")
	check("save.save_mode_load_default_cancel", sp._phase == "list" and not loaded2[0])
	# 触屏：点右牌「删除」→ 弹窗；点弹窗「取消」
	ss._on_card_button(2)
	check("save.touch_delete_button", sp._phase == "confirm" and ss.dialog.danger)
	ss.dialog.chosen.emit(1)
	check("save.touch_cancel", sp._phase == "list" and XSave.exists(7))
	# 触屏：点别的行＝选中；点当前行＝当前按钮
	ss.list.select(7)
	check("save.touch_select_row", sp.index == 7)
	await shots("save_save_mode")
	check("save.hints", ss.hint_list.any(func(h): return h[0] == "X") == sp.action_enabled(2) and ss.hint_list[0][0] == "确定")
	sp.queue_free()
	await frames(2)


## 存档写盘结果与旧页逐字节一致：同一份状态、同一秒里旧页存第 10 格、新页存第 11 格。
## 封存关着（明文 .json）比两个文件的字节；封存开着（.ksv 每次写都不一样，旧页自己连存两次也不同）比解开后的存档文字字节。
func _save_bytes() -> void:
	for sealed in [false, true]:
		XSaveSeal.ENABLED = sealed
		var same := false
		var detail = null
		for attempt in 3:
			var s := _state()
			var base := s.save_count
			XSkinSavePage.ENABLED = false
			var old := open_save("save")
			await frames(1)
			XSkinSavePage.ENABLED = true
			var neu := open_save("save")
			await frames(1)
			var t0 := Time.get_datetime_string_from_system()
			old.index = 9
			old.ok()
			old.ok()   # 旧页：列表确定 → 操作窗停在「保存」→ 确定（空格直接存）
			s.save_count = base   # 两次保存次数一样
			neu.index = 10
			neu.act = 1
			act(neu, "ui_accept")
			var t1 := Time.get_datetime_string_from_system()
			old.queue_free()
			neu.queue_free()
			var pa := XSave.path(10)
			var pb := XSave.path(11)
			var a := FileAccess.get_file_as_bytes(pa) if not sealed else XSaveSeal.read_text(pa).to_utf8_buffer()
			var b := FileAccess.get_file_as_bytes(pb) if not sealed else XSaveSeal.read_text(pb).to_utf8_buffer()
			detail = [pa.get_extension(), a.size(), b.size()]
			XSave.remove(10)
			XSave.remove(11)
			if t0 != t1:
				continue   # 跨了一秒（savedAt 只到秒），重来
			same = a.size() > 100 and a == b
			break
		check("save.bytes_identical_old_vs_new_" + ("sealed_text" if sealed else "plain_file"), same, detail)
	XSaveSeal.ENABLED = true
	await frames(2)


# ---- 整队 ----

func _party_state() -> XState:
	var s := _state(false)   # 天启篇不许事件入队（XTianqi.join_allowed）：先按原版档加人，再标成天启篇
	var added := 0
	for r in XDB.table("Actors"):
		if added >= 4:
			break
		if r is Dictionary and str(r.get("name", "")) != "" and r.has("classId") and int(r.id) > 1 and not s.party.has(int(r.id)) \
				and XActorWarehouse.enabled(int(r.id)) and not XTianqiSkills.is_super(int(r.id), true) and not XItemMarks.is_super_strong(int(r.id)):
			s.add_actor(int(r.id))
			added += 1
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	for id in s.party.duplicate():   # 天启篇档位里的超强者拿掉（本专项不测超强者规则；超强者拦截由 xiyou_super_deploy 管）
		if id != s.party[0] and XItemMarks._super_in(s, id):
			s.party.erase(id)
	s.init_battle_slots()
	return s


func _party_page() -> void:
	var s := _party_state()
	XSkinPartyPage.ENABLED = false
	var old := XPartyScene.new()
	add_child(old)
	await frames(2)
	check("party.gate.rollback_old", old.skin == null and old.mode == "command" and old.cmd_win.visible)
	await shot("party_old_compare_16x9")   # 旧页只按 1280×720 摆，20:9 窗口是上下左右留边，不拍
	old.queue_free()
	XSkinPartyPage.ENABLED = true
	s.flags.erase("tianqi")
	old = XPartyScene.new()
	add_child(old)
	await frames(2)
	check("party.gate.xiyou_old", old.skin == null)
	old.queue_free()
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	s.init_battle_slots()
	var p := XPartyScene.new()
	var closed := [0]
	p.closed.connect(func(): closed[0] += 1)
	add_child(p)
	await frames(3)
	var sk := p.skin
	check("party.gate.tianqi_builds", sk != null and not p.cmd_win.visible and not p.slot_win.visible and not p.list_win.visible)
	check("party.enter_on_slots", p.mode == "slot" and p.slot_index == 0 and p.cmd_index == 0)
	# 出战位五格
	var ok_slots := true
	for i in 5:
		var si := sk.slot_info(i)
		var id := int(s.battle_slots[i])
		ok_slots = ok_slots and si.label == "第 %d 格" % (i + 1) and si.empty == (id <= 0)
		if id > 0:
			ok_slots = ok_slots and si.name == s.actor(id).display_name() and si.lv == "Lv %d" % s.actor(id).level and si.leader == XLeadActor.is_leader(s, id)
		ok_slots = ok_slots and si.helper == (i == XTianqi.HELPER_SLOT)
	check("party.slots_table", ok_slots, range(5).map(func(i): return sk.slot_info(i)))
	check("party.slot_geometry", sk.slot_row.position.y == XUiSkin.TOP and sk.slot_row.size.y == XSkinPartyPage.SLOT_H and sk.layout.center.position.y == XUiSkin.TOP + XSkinPartyPage.SLOT_H + XUiSkin.PANEL_GAP)
	# 名单：首行「空出这一格」，后面每人（旧 list_data 去掉末尾「离队」）
	var items: Array = sk.list.items
	check("party.roster_first_remove", items[0].text == "空出这一格" and items.size() == s.party.size() + 1, items.size())
	var ok_rows := true
	for k in s.party.size():
		var a := s.actor(int(p.list_data()[k + 1]))
		var it: Dictionary = items[k + 1]
		var at := s.battle_slots.find(a.actor_id)
		var want_tag := "" if at < 0 else ("助力" if at == XTianqi.HELPER_SLOT else "出战 %d" % (at + 1))
		ok_rows = ok_rows and it.text == a.display_name() and it.right == "Lv %d" % a.level and int(it._hp) == a.hp and int(it._mp) == a.mp and int(it._mhp) == a.mhp and int(it._mmp) == a.mmp \
			and (want_tag == "" or (it.tags as Array).has(want_tag)) and it.icon is Texture2D
	check("party.roster_rows", ok_rows)
	check("party.no_tp", not items[1].has("_tp") and not str(items[1]).contains("TP"))
	var ci := sk.card_info()
	check("party.card_slot_actor", int(ci.id) == int(s.battle_slots[0]) and str(ci.state) == "出战第 1 格" and ci.has("class") and int(ci.mhp) > 0 and str(ci.outcome).contains("第 1 格"), ci)
	await shots("party")
	# → 换格；确定进选人；选第 6 人（待命）放进第 2 格
	act(p, "ui_right")
	check("party.right_moves_slot", p.slot_index == 1)
	act(p, "ui_accept")
	check("party.ok_to_list", p.mode == "list" and sk.list.active)
	var bench := -1
	for k in range(1, p.list_data().size() - 1):
		if s.battle_slots.find(int(p.list_data()[k])) < 0 and XItemMarks.can_deploy(s, int(p.list_data()[k]), 1):
			bench = k
			break
	check("party.has_bench", bench > 0, [s.party, s.battle_slots, s.party.map(func(i): return XItemMarks._super_in(s, i)), XTianqi.super_cap(s), XTianqi.helper_super_ok(s), XTianqi.active(s), XTianqi.HELPER_RULES])
	p.list_index = bench
	p._refresh()
	var bench_id := int(p.list_data()[bench])
	var was := int(s.battle_slots[1])
	check("party.outcome_sentence", sk.outcome() == "%s放入第 2 格，%s回到待命。" % [s.actor(bench_id).display_name(), s.actor(was).display_name()], sk.outcome())
	check("party.button_text", sk.card.buttons[0].text == "放进第 2 格")
	await shots("party_pick")
	act(p, "ui_accept")
	check("party.placed", int(s.battle_slots[1]) == bench_id and p.mode == "slot", s.battle_slots)
	# 名单首末循环、Q／E 翻页（小A核 P1-1）：只在新页画的行里走（旧名单末尾那行「离队」不许落上去）
	act(p, "ui_accept")
	var n_rows := p.list_data().size() - 1
	p.list_index = 0
	p._refresh()
	act(p, "ui_up")
	check("party.up_wraps_to_last_actor", p.list_index == n_rows - 1 and sk.list.index == n_rows - 1 and int(p.list_data()[p.list_index]) > 0
		and sk.card.buttons[0].text.begins_with("放进"), [p.list_index, n_rows, sk.card.buttons[0].text])
	act(p, "ui_down")
	check("party.down_wraps_to_first", p.list_index == 0 and sk.list.index == 0)
	var vis := sk.list.visible_rows()
	key(p, KEY_E)
	check("party.e_pages_down", n_rows > vis and p.list_index == sk.list.index and p.list_index >= sk.list.top_row and sk.list.top_row > 0 and p.list_index < n_rows, [p.list_index, sk.list.top_row, vis, n_rows])
	key(p, KEY_Q)
	check("party.q_pages_up", sk.list.top_row == 0 and p.list_index < vis, [p.list_index, sk.list.top_row])
	p.list_index = n_rows - 1
	p._refresh()
	key(p, KEY_E)
	check("party.e_at_end_stays_on_actor", p.list_index == n_rows - 1)
	var last_id := int(p.list_data()[n_rows - 1])
	var cur_slot := int(s.battle_slots[p.slot_index])
	act(p, "ui_accept")
	check("party.last_row_places_actor", int(s.battle_slots[p.slot_index]) == last_id or (cur_slot > 0 and s.battle_slots.has(last_id)), [s.battle_slots, last_id])
	# 首行「空出这一格」
	act(p, "ui_accept")
	p.list_index = 0
	p._refresh()
	check("party.remove_outcome", sk.outcome().contains("回到待命") and sk.card.buttons[0].text == "空出第 2 格", sk.outcome())
	act(p, "ui_accept")
	check("party.removed", int(s.battle_slots[1]) == 0 or int(s.battle_slots[1]) != bench_id, s.battle_slots)
	await shots("party_empty_slot")
	# 取消（选人时）回出战位
	act(p, "ui_accept")
	act(p, "ui_cancel")
	check("party.cancel_list_to_slot", p.mode == "slot" and closed[0] == 0)
	# Q／E 和旁边换位
	var a0 := int(s.battle_slots[0])
	var a1 := int(s.battle_slots[1])
	p.slot_index = 0
	key(p, KEY_E)
	check("party.qe_swap", int(s.battle_slots[1]) == a0 and int(s.battle_slots[0]) == a1 and p.slot_index == 1, s.battle_slots)
	# X 还原
	key(p, KEY_X)
	check("party.x_revert", s.battle_slots == p._former, [s.battle_slots, p._former])
	# 取消＝完成：全空时拦住、留在本页
	var keep: Array = s.battle_slots.duplicate()
	s.battle_slots = [0, 0, 0, 0, 0]
	act(p, "ui_cancel")
	check("party.finish_blocked_empty", closed[0] == 0 and p.is_inside_tree())
	s.battle_slots = keep
	# 触屏：点第 3 格、点名单行、点右牌按钮
	sk._on_slot_gui(_click(sk.slot_rect(2).get_center()))
	check("party.touch_slot_select", p.slot_index == 2 and p.mode == "slot")
	sk._on_list_index(1)
	check("party.touch_row_enters_list", p.mode == "list" and p.list_index == 1)
	sk._on_slot_gui(_click(sk.slot_rect(0).get_center()))
	check("party.touch_slot_back", p.mode == "slot" and p.slot_index == 0)
	act(p, "ui_cancel")
	check("party.finish_closes", closed[0] == 1)
	p.queue_free()
	await frames(2)


func _click(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e


# ---- 角色仓库 ----

func _warehouse_page() -> void:
	var s := _party_state()
	var store: Array[int] = []
	for r in XDB.table("Actors"):
		if store.size() >= 2:
			break
		if r is Dictionary and str(r.get("name", "")) != "" and r.has("classId") and int(r.id) > 1 and not s.party.has(int(r.id)) and XActorWarehouse.enabled(int(r.id)):
			s.actor(int(r.id))
			store.append(int(r.id))
	s.saved_actors.assign(store)
	XSkinActorWarehousePage.ENABLED = false
	var old := XActorWarehouseScene.new()
	add_child(old)
	await frames(2)
	check("wh.gate.rollback_old", old.skin == null and old.cmd_win.visible)
	await shot("warehouse_old_compare_16x9")   # 旧页只按 1280×720 摆，20:9 窗口是上下左右留边，不拍
	old.queue_free()
	XSkinActorWarehousePage.ENABLED = true
	var p := XActorWarehouseScene.new()
	var closed := [0]
	p.closed.connect(func(): closed[0] += 1)
	add_child(p)
	await frames(3)
	var sk := p.skin
	check("wh.gate.tianqi_builds", sk != null and not p.cmd_win.visible and not p.list_win.visible and not p.title_win.visible)
	check("wh.title", sk.title == XActorWarehouseScene.TITLE)
	check("wh.enter_on_list", p.mode == "list" and p.cmd == 0)
	check("wh.tabs_counts", sk.inner_tabs.tabs == ["队伍 %d" % s.party.size(), "仓库 2"], sk.inner_tabs.tabs)
	var ok_rows := sk.list.items.size() == s.party.size()
	for k in s.party.size():
		var a := s.actor(s.party[k])
		ok_rows = ok_rows and sk.list.items[k].text == a.display_name() and sk.list.items[k].right == "Lv %d" % a.level and int(sk.list.items[k]._hp) == a.hp
	check("wh.rows_party", ok_rows)
	var cd := sk.card_data()
	check("wh.card_deposit", cd.title == s.actor(s.party[0]).display_name() and cd.buttons[0].text == "存入" and str(cd.sections).contains("存入后") and str(cd.sections).contains("队伍最少保留一位角色"), cd)
	check("wh.exp_note_deposit", str(cd.sections).contains(XSkinActorWarehousePage.T_EXP_DEPOSIT), cd)
	await shots("warehouse")
	# 确定＝存入，光标不动
	var first := s.party[0]
	act(p, "ui_accept")
	check("wh.deposit", not s.party.has(first) and s.saved_actors.has(first) and p.index == 0 and sk.inner_tabs.tabs[1] == "仓库 3")
	# E 换到仓库
	key(p, KEY_E)
	check("wh.e_to_store", p.cmd == 1 and sk.list.items.size() == 3 and sk.card_data().buttons[0].text == "取出" and str(sk.card_data().sections).contains("取出后"))
	check("wh.exp_note_withdraw", str(sk.card_data().sections).contains(XSkinActorWarehousePage.exp_note_withdraw(s)), sk.card_data())
	# 说明随 optExtraExp 实际值变：开＝照样拿满，关＝拿不到（改 System 数据后复原）
	var sysd := XDB.system()
	var old_opt = sysd.get("optExtraExp", false)
	sysd["optExtraExp"] = true
	check("wh.exp_note_opt_on", XSkinActorWarehousePage.exp_note_withdraw(s) == XSkinActorWarehousePage.T_EXP_WITHDRAW_ON)
	sysd["optExtraExp"] = false
	check("wh.exp_note_opt_off", XSkinActorWarehousePage.exp_note_withdraw(s).contains("不会获得"))
	sysd["optExtraExp"] = old_opt
	await shots("warehouse_store")
	act(p, "ui_accept")
	check("wh.withdraw", s.party.has(XActorWarehouse.list(s, true).back()) and sk.list.items.size() == 2)
	# 取走末尾一行（小A核 P1-2）：光标夹回剩下的最后一行，右牌、左块还在，再点那一行能接着取
	act(p, "ui_down")
	check("wh.on_last_row", p.index == 1)
	var keep_first := int(p.data[0])
	act(p, "ui_accept")
	check("wh.withdraw_last_clamps", p.index == 0 and sk.list.index == 0 and sk.card.visible and sk.current_id() == keep_first
		and sk.card.title == s.actor(keep_first).display_name(), [p.index, sk.card.visible])
	sk._on_list_click(0)
	check("wh.click_clamped_row_withdraws", sk.list.items.is_empty() and not sk.card.visible and s.party.has(keep_first))
	act(p, "ui_accept")
	check("wh.empty_accept_stays", p.mode == "list")
	await shots("warehouse_empty")
	# 队伍页签存走末尾一行：光标夹回新的最后一行（小A核 P1-2）
	key(p, KEY_Q)
	var last_i := p.data.size() - 1
	p._select(last_i)
	var last_actor := int(p.data[last_i])
	act(p, "ui_accept")
	check("wh.deposit_last_clamps", s.saved_actors.has(last_actor) and p.index == p.data.size() - 1 and sk.card.visible and sk.current_id() == int(p.data[p.index]), [p.index, p.data.size()])
	# 只剩 1 人：存不进去
	while s.party.size() > 1:
		XActorWarehouse.deposit(s, 0)
	p._reload()
	check("wh.last_card", sk.card_data()._disabled and str(sk.card_data().sections).contains("无法存入"))
	# 点灰掉的「存入」：蜂鸣、焦点框不留在灰按钮上（小A核 P3-1）
	var wev := InputEventMouseButton.new()
	wev.button_index = MOUSE_BUTTON_LEFT
	wev.pressed = true
	wev.position = sk.card.button_rect(0).get_center()
	XSound.system_log.clear()
	sk.card.gui_input.emit(wev)
	sk.card._gui_input(wev)
	await frames(2)
	check("wh.click_disabled_buzz_no_focus", XSound.system_log.has(3) and sk.card.button_index == -1, [XSound.system_log, sk.card.button_index])
	act(p, "ui_accept")
	check("wh.last_kept", s.party.size() == 1)
	act(p, "ui_cancel")
	check("wh.cancel_closes", closed[0] == 1)
	p.queue_free()
	await frames(2)


# ---- 字体 130%、旧画法对照 ----

func _font_and_old() -> void:
	_party_state()
	XSave.save(3)
	XFontScale.set_value("global", 130)
	check("font130.mult", XUiSkin.font_mult() >= 1.29)
	var p := open_save("save")
	await frames(3)
	p.index = 2
	p._refresh()
	await shots("save_font130")
	p.queue_free()
	var q := XPartyScene.new()
	add_child(q)
	await frames(3)
	await shots("party_font130")
	q.queue_free()
	var w := XActorWarehouseScene.new()
	add_child(w)
	await frames(3)
	await shots("warehouse_font130")
	w.queue_free()
	XFontScale.set_value("global", 100)
	await frames(2)
	XSkinSavePage.ENABLED = false
	p = open_save("save")
	await frames(3)
	p.index = 2
	p._refresh()
	check("old.save_page", p.skin == null and p.info_win.visible)
	await shot("save_old_compare_16x9")   # 旧页只按 1280×720 摆，20:9 窗口是上下左右留边，不拍
	p.queue_free()
	XSkinSavePage.ENABLED = true
	XSave.remove(3)
	await frames(2)
