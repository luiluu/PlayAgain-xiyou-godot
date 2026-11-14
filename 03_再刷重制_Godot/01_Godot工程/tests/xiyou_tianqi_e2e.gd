extends Node
## 天启篇「标题 → 大厅」贯通（95% 阶段审查 P3-2）：从版本选择页起，只用真实输入事件（InputEventKey 按下＋松开、InputEventScreenTouch）
## 一路走进 Map001 之后的方桌大厅，不直接调 entry.gd 的 _tq_* 函数。和 xiyou_tianqi_opening 的分工：那边直接建局测规则细节，这边测按键链路。
## 一、键盘主线：版本选择 → 启动动画（按键跳过）→ 声明屏（按键跳过）→ 标题「新的游戏」→ 存档位 3 → 九死 → 重抽一次 → 确认
##     → 大厅：对话按确定翻、道号用键盘打字回车 → 能走动。断言阵容是重抽后那组、道号、规则版本、难度、存档位、存档文件。
## 六、回标题不重播：主菜单「游戏结束 → 回到标题」，标题直接出来，没有启动动画和声明屏。
## 四、读回：「旧的回忆」读 3 号档 → 回大厅，道号／阵容／难度／规则版本还在；主菜单「整队」真按键换人：
##     第二个超强者放不进上场格（蜂鸣、出战栏不变）、能放进助力位、普通角色照常换上场。
## 三、取消与覆盖：选已有存档的 3 号 → 覆盖确认页按「换一格」回选格 → 再选 3 号「覆盖它」→ 难度 → 阵容；
##     每一页按取消键（Esc）退回上一页，一直退回标题。
## 二、触屏主线：全部用点按（对话点一下翻页、道号框点一下后打字、点「确定」），选炼狱覆盖 3 号 → 进大厅；
##     旧档被新档替换（存档里难度、道号都换了）。
## 五、开关回退：XTianqi.ENABLED = false 时同样按「新的游戏」进的是原版 Map001，局里没有 flags.tianqi；
##     开关改回 true 后「旧的回忆」读 3 号档仍按天启篇规则（规则版本、难度、超强者上限）。
## 标题菜单项写成一处 TITLE_ITEM（原版标题与新标题 PR #29 的顺序都是 新的游戏 0、旧的回忆 1）；新标题合并后读 _tq_title._items，不用改。
## 要转换产物（地图、事件）。存档与设置写到 user://test_xiyou_tianqi_e2e，结束删掉；不读本机设置文件。

const DIR := "user://test_xiyou_tianqi_e2e"
const SLOT := 3
const DAO_KEY := "键盘道号"
const DAO_TOUCH := "触屏道号"
const ENTRY_MENU := "res://scenes/entry_menu.tscn"
## 标题菜单项：键 → 原版标题 _commands 的下标（新标题按 _items 的 key 找）
const TITLE_ITEM := {"new_game": 0, "load": 1}
## 天启篇开局三页（选存档位、难度、阵容）按取消键退回上一页。现状 entry.gd 的 _unhandled_input 只管标题图片指令，
## 窗口页不认取消键（安卓返回键经 XPlatform 也发 ui_cancel，同样不动），交付单「发现的问题」已报；修好后改成 true，测试就改测取消键退回。
const ESC_BACK := false
## 每按一下键后等几帧（按下与松开之间另等 2 帧）
const STEP := 4

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok, "detail": detail})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _scene() -> Node:
	return get_tree().current_scene


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(cond: Callable, timeout := 6000) -> bool:
	for i in range(timeout):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


# ---- 真实输入 ----

func _key(code: Key, unicode := 0, hold := 2) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(hold)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	r.unicode = 0
	Input.parse_input_event(r)
	await _frames(STEP)


func _type(text: String) -> void:
	for ch in text:
		await _key(KEY_NONE, ch.unicode_at(0))


## p 是画面（1280×720）坐标；触屏事件要窗口坐标（headless 窗口只有 64×64，按根窗口的拉伸变换换算）
func _tap(p: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = get_tree().root.get_final_transform() * p
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(2)
	var r := t.duplicate() as InputEventScreenTouch
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(STEP)


func _tap_node(c: Control) -> void:
	if c == null:
		return
	await _tap(c.get_global_rect().get_center())


## 用方向键把焦点挪到 target（按钮页：选存档位、难度、阵容）
func _focus_to(target: Control) -> bool:
	if target == null:
		return false
	await _frames(2)  # 新页的 grab_focus 是 call_deferred
	for i in 40:
		var cur := get_viewport().gui_get_focus_owner()
		if cur == target:
			return true
		if cur == null:
			await _key(KEY_DOWN)
			continue
		var d := target.get_global_rect().get_center() - cur.get_global_rect().get_center()
		if absf(d.y) > 4.0:
			await _key(KEY_DOWN if d.y > 0 else KEY_UP)
		else:
			await _key(KEY_RIGHT if d.x > 0 else KEY_LEFT)
	return get_viewport().gui_get_focus_owner() == target


func _press_focused(target: Control) -> bool:
	if not await _focus_to(target):
		return false
	await _key(KEY_ENTER)
	return true


# ---- 页面 ----

func _entry() -> Node:
	var s = _scene()
	return s if s != null and s.has_method("_tq_slot") else null


func _title_ready() -> bool:
	var e = _entry()
	return e != null and e.is_title_page() and e.get_node_or_null("XIntroAnim") == null and e.get_node_or_null("XWarningScreen") == null


## 新标题（PR #29 的 XTianqiTitle）在就用它，不在就用原版图片指令
func _title_obj():
	var e = _entry()
	return e.get("_tq_title") if e != null and e.get("_tq_title") != null else null


func _title_node(key: String) -> Control:
	var t = _title_obj()
	if t != null:
		for it in t._items:
			if str(it.key) == key:
				return it.node
		return null
	return _entry()._commands[TITLE_ITEM[key]].node


func _title_sel_node() -> Control:
	var t = _title_obj()
	return t._items[t._sel].node if t != null else _entry()._commands[_entry()._sel].node


func _title_key(key: String) -> bool:
	var target := _title_node(key)
	for i in 8:
		if _title_sel_node() == target:
			break
		await _key(KEY_DOWN)
	if _title_sel_node() != target:
		return false
	await _key(KEY_ENTER)
	return true


func _btn(name: String) -> Control:
	var e = _entry()
	return e.find_child(name, true, false) if e != null else null


## 当前窗口页上文字为 text 的按钮（「返回」「覆盖它」「换一格」）
func _btn_text(text: String) -> Button:
	var e = _entry()
	if e == null or e.column == null:
		return null
	for b in e.column.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func _page_title() -> String:
	var e = _entry()
	if e == null or e.column == null or e.column.get_child_count() == 0:
		return ""
	var l = e.column.get_child(0)
	return l.text if l is Label else ""


func _lineup_shown() -> Array:
	var ok := _btn("TianqiConfirm")
	if ok == null:
		return []
	for c in ok.get_signal_connection_list("pressed"):
		var args: Array = (c.callable as Callable).get_bound_arguments()
		if args.size() == 3:
			return Array(args[2])
	return []


func _map() -> XMapScene:
	return _scene() as XMapScene


func _map_idle(map_id: int) -> bool:
	var m := _map()
	return m != null and m.map_id == map_id and m.player != null and not m.busy and not m.scene_page_open()


func _prompt() -> XTextPrompt:
	var m := _map()
	if m == null:
		return null
	for p in m._scene_pages:
		if is_instance_valid(p) and p is XTextPrompt and not p.is_queued_for_deletion():
			return p
	return null


## 大厅开局：对话按确定（或点一下）翻页，道号框打字后回车（或点「确定」）；等首次到达存档（EV020）与漩涡过场（EV076）放完能操作
func _drive_hub(touch: bool, dao: String) -> bool:
	var typed := false
	for i in 4000:
		var m := _map()
		var s := XState.current
		if m != null and s != null and _map_idle(XTianqi.HALL_MAP) and s.self_switch(4, 20, "A") and s.self_switch(4, 76, "A"):
			_check("%s.prompt_seen" % ("touch" if touch else "key"), typed)
			return true
		var p := _prompt()
		if p != null and not typed:
			typed = true
			await _frames(2)
			if touch:
				await _tap_node(p.edit)
			await _type(dao)
			if touch:
				var ok: Button = null
				for b in p.find_children("*", "Button", true, false):
					if b.text == "确定":
						ok = b
				await _tap_node(ok)
			else:
				await _key(KEY_ENTER)
			continue
		if m != null and m.busy and p == null:
			if touch:
				await _tap(Vector2(640, 600))
			else:
				await _key(KEY_ENTER)
			continue
		await get_tree().process_frame
	return false


## 地图上等到能操作：中途冒出的对话（大厅里随阵容触发的自动事件）按确定翻掉，和玩家一样
func _settle(frames := 1500) -> bool:
	for i in frames:
		var m := _map()
		if m == null:
			return false
		if not m.busy and not m.scene_page_open() and not m.message.is_busy():
			return true
		if m.message.is_busy() and i % 6 == 0:
			if i == 0:
				print("NOTE 大厅对话：", JSON.stringify(m.message._msg).left(200))
			await _key(KEY_ENTER)
			continue
		await get_tree().process_frame
	return false


## 主菜单（Esc）里移到指令 sym 并确定
func _menu_cmd(sym: String) -> bool:
	var menu: XMenu = null
	for attempt in 5:
		if not await _settle():
			return false
		await _key(KEY_ESCAPE)
		for i in 120:
			for n in _map().ui.get_children():
				if n is XMenu:
					menu = n
			if menu != null:
				break
			await get_tree().process_frame
		if menu != null:
			break
	if menu == null:
		return false
	await _frames(STEP)
	for i in XMenu.COMMANDS.size() + 1:
		if str(XMenu.COMMANDS[menu._cmd_index][1]) == sym:
			await _key(KEY_ENTER)
			return true
		await _key(KEY_DOWN)
	return false


func _to_title_via_menu() -> bool:
	if not await _menu_cmd("gameEnd"):
		return false
	await _frames(STEP)
	await _key(KEY_ENTER)  # 回到标题
	return await _wait(func(): return _entry() != null and _entry().is_title_page(), 600)


## 「旧的回忆」读 slot 号档
func _load_slot(slot: int) -> bool:
	if not await _title_key("load"):
		return false
	var page: XSaveScene = null
	await _wait(func(): return _entry() != null and _entry().find_child("LoadPage", true, false) != null, 120)
	page = _entry().find_child("LoadPage", true, false) as XSaveScene
	if page == null:
		return false
	await _frames(STEP)
	for i in XSave.SLOTS:
		if page.slot() == slot:
			break
		await _key(KEY_DOWN)
	if page.slot() != slot:
		return false
	await _key(KEY_ENTER)  # 选格 → 操作窗「读取」
	await _key(KEY_ENTER)  # 读取 → 确认
	await _key(KEY_ENTER)  # 是
	if not await _wait(func(): return _map() != null and _map().map_id == XTianqi.HALL_MAP and _map().player != null, 3000):
		return false
	return await _settle()


func _saved_flags(slot: int) -> Dictionary:
	var saved = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(slot)))
	return saved if saved is Dictionary else {}


# ---- 主体 ----

func _run() -> void:
	XSave.dir_override = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	XConfig.path_override = DIR.path_join("options.json")
	for slot in range(1, XSave.SLOTS + 1):
		DirAccess.remove_absolute(XSave.path(slot))
	XMessageBox.auto = false
	Engine.time_scale = 4.0
	var splash_env := OS.get_environment("XIYOU_SPLASH")
	OS.set_environment("XIYOU_SPLASH", "1")  # headless 默认不放开场；这里要真的放、真的按键跳过
	XSplashScreen.shown = false
	var lineup := await _keyboard_main()
	OS.set_environment("XIYOU_SPLASH", splash_env)
	if lineup.is_empty():
		_finish()
		return
	await _no_replay()
	await _load_back(lineup)
	await _cancel_and_overwrite()
	await _touch_main()
	await _revert()
	_finish()


func _finish() -> void:
	for slot in range(1, XSave.SLOTS + 1):
		DirAccess.remove_absolute(XSave.path(slot))
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(DIR)
	XTianqi.ENABLED = true
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 一、键盘主线；返回进大厅时的阵容（没走通返回空）
func _keyboard_main() -> Array:
	get_tree().change_scene_to_file(ENTRY_MENU)
	var menu_ok := await _wait(func(): return _scene() != null and _scene().scene_file_path == ENTRY_MENU \
		and get_viewport().gui_get_focus_owner() != null, 300)
	_check("key.entry_menu_focus", menu_ok and get_viewport().gui_get_focus_owner().name == "XiyouEntry",
		get_viewport().gui_get_focus_owner().name if menu_ok else null)
	await _key(KEY_ENTER)
	var intro_ok := await _wait(func(): return _entry() != null and _entry().get_node_or_null("XIntroAnim") != null, 300)
	_check("key.intro_plays", intro_ok and XIntroAnim.available(), XIntroAnim.available())
	if intro_ok:
		await _frames(10)
		await _key(KEY_SPACE)
		_check("key.intro_skipped", await _wait(func(): return _entry().get_node_or_null("XIntroAnim") == null \
			and _entry().get_node_or_null("XWarningScreen") != null, 300))
	# 声明屏开头 MIN_SKIP 帧防连按，之后按一下就淡出
	var w := _entry().get_node_or_null("XWarningScreen") as XWarningScreen
	if w != null:
		var wr: WeakRef = weakref(w)
		await _wait(func(): return wr.get_ref() == null or wr.get_ref()._hint.visible, 600)
		var frame_at_skip: int = w.state().frame if is_instance_valid(w) else -1
		await _key(KEY_SPACE)
		var gone := await _wait(func(): return wr.get_ref() == null or wr.get_ref().is_queued_for_deletion(), 600)
		_check("key.warning_skipped", gone and frame_at_skip < XWarningScreen.FADE + XWarningScreen.HOLD, frame_at_skip)
	_check("key.title", await _wait(_title_ready, 600))
	_check("key.title_new_game", await _title_key("new_game"))
	# 选存档位
	await _wait(func(): return _btn("TianqiSlot%d" % SLOT) != null, 60)
	_check("key.slot_page", _btn("TianqiSlot%d" % SLOT) != null, _page_title())
	_check("key.slot_pick", await _press_focused(_btn("TianqiSlot%d" % SLOT)))
	# 空格直接到难度页
	await _wait(func(): return _btn("TianqiDifficulty_jiusi") != null, 60)
	_check("key.difficulty_page", _btn("TianqiDifficulty_jiusi") != null, _page_title())
	_check("key.difficulty_pick", await _press_focused(_btn("TianqiDifficulty_jiusi")))
	await _wait(func(): return _btn("TianqiReroll") != null, 60)
	var first := _lineup_shown()
	_check("key.lineup_page", first.size() == XTianqi.LINEUP_SIZE and XTianqi.lineup_ok("jiusi", first), first)
	var lineup := first
	for i in 5:  # 重抽：五人全同的概率极小，换不了就再抽
		await _press_focused(_btn("TianqiReroll"))
		await _frames(2)
		lineup = _lineup_shown()
		if lineup != first:
			break
	_check("key.reroll", lineup != first and XTianqi.lineup_ok("jiusi", lineup), [first, lineup])
	_check("key.confirm", await _press_focused(_btn("TianqiConfirm")))
	var in_map := await _wait(func(): return _map() != null and _map().map_id == XTianqi.HALL_MAP, 600)
	_check("key.hall_map", in_map, _scene().scene_file_path if _scene() else null)
	if not in_map:
		return []
	var hub := await _drive_hub(false, DAO_KEY)
	_check("key.hub_ready", hub)
	if not hub:
		return []
	var s := XState.current
	_check("key.party_is_rerolled", Array(s.party) == lineup, [s.party, lineup])
	_check("key.dao_hao", s.actor_name == DAO_KEY, s.actor_name)
	_check("key.rules", XTianqi.active(s) and int(s.flags.tianqi.rules) == XTianqi.RULES_VERSION and str(s.flags.tianqi.difficulty) == "jiusi"
		and Array(s.flags.tianqi.lineup) == lineup, s.flags.get("tianqi"))
	_check("key.slot", s.fixed_save_slot() == SLOT and XSave.exists(SLOT), [s.fixed_save_slot(), XSave.exists(SLOT)])
	var saved := _saved_flags(SLOT)
	var f = saved.get("flags", {})
	_check("key.saved", f is Dictionary and f.get("tianqi") is Dictionary and str(f.tianqi.difficulty) == "jiusi"
		and Array(f.tianqi.lineup).map(func(v): return int(v)) == lineup, f.get("tianqi") if f is Dictionary else saved.keys())
	# 能走动：点一下方向键走一格，再走回来（按太久会走到大厅南边的触发点）
	var moved := false
	var pl: MVPlayer = _map().player
	var back := {KEY_DOWN: KEY_UP, KEY_UP: KEY_DOWN, KEY_LEFT: KEY_RIGHT, KEY_RIGHT: KEY_LEFT}
	for code in [KEY_UP, KEY_LEFT, KEY_RIGHT, KEY_DOWN]:
		var at := pl.grid
		await _key(code, 0, 3)
		await _wait(func(): return not _map().player.is_moving(), 120)
		if pl.grid != at:
			moved = true
			await _key(back[code], 0, 3)
			await _wait(func(): return not _map().player.is_moving(), 120)
			break
	_check("key.walk", moved, pl.grid)
	return lineup


## 六、回标题不重播启动动画与声明屏
func _no_replay() -> void:
	_check("replay.to_title", await _to_title_via_menu())
	var seen := false
	for i in 30:
		var e = _entry()
		if e != null and (e.get_node_or_null("XIntroAnim") != null or e.get_node_or_null("XWarningScreen") != null):
			seen = true
		await get_tree().process_frame
	_check("replay.no_intro", not seen and _title_ready())


## 四、读回＋真实整队
func _load_back(lineup: Array) -> void:
	_check("load.loaded", await _load_slot(SLOT))
	var s := XState.current
	_check("load.state", s.actor_name == DAO_KEY and Array(s.party) == lineup and XTianqi.active(s) and str(s.flags.tianqi.difficulty) == "jiusi"
		and XTianqi.super_cap(s) == 1 and s.fixed_save_slot() == SLOT, [s.actor_name, s.party, s.flags.get("tianqi")])
	# 准备：队里两名超强者（A 在上场格，B 不在出战栏）。招募走通关抽角色，测试直接写进队伍（同 xiyou_tianqi_opening 的 _rules）
	var sup: Array = XTier.ids(XTier.SUPER).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var in_party := sup.filter(func(id): return s.party.has(id))
	var a: int = in_party[0] if not in_party.is_empty() else sup[0]
	var b: int = sup.filter(func(id): return id != a)[0]
	for id in [a, b]:
		if not s.party.has(id):
			s.party.append(id)
			s.actor(id)
	var others := Array(s.party).filter(func(id): return id != a and id != b)
	s.battle_slots = [a, others[0], others[1], others[2], others[3] if others.size() > 3 else 0]
	if not await _menu_cmd("formation"):
		_check("deploy.open", false)
		return
	var page: XPartyScene = null
	await _wait(func(): return _find_party() != null, 120)
	page = _find_party()
	if not _check("deploy.open", page != null):
		return
	await _frames(STEP)
	await _key(KEY_ENTER)  # 整队 → 出战栏第 0 格
	await _key(KEY_RIGHT)  # 第 1 格（上场格）
	await _key(KEY_ENTER)  # → 名单
	await _list_to(page, b)
	var before := s.battle_slots.duplicate()
	XSound.system_log.clear()
	await _key(KEY_ENTER)
	_check("deploy.super_cap_blocks", XSound.system_log.has(3) and s.battle_slots == before and page.mode == "list",
		[XSound.system_log, s.battle_slots, page.mode])
	await _key(KEY_ESCAPE)  # 回出战栏
	for i in 3:
		await _key(KEY_RIGHT)  # 第 4 格（助力位）
	_check("deploy.helper_slot_selected", page.slot_index == XTianqi.HELPER_SLOT, page.slot_index)
	await _key(KEY_ENTER)
	await _list_to(page, b)
	var helper_before: int = int(s.battle_slots[XTianqi.HELPER_SLOT])
	await _key(KEY_ENTER)
	_check("deploy.super_to_helper", int(s.battle_slots[XTianqi.HELPER_SLOT]) == b, s.battle_slots)
	# 普通换人：把刚被换下的人换回第 1 格
	if helper_before > 0:
		for i in 3:
			await _key(KEY_LEFT)
		await _key(KEY_ENTER)
		await _list_to(page, helper_before)
		await _key(KEY_ENTER)
		_check("deploy.normal_swap", int(s.battle_slots[1]) == helper_before, s.battle_slots)
	var fighters := s.battle_slots.slice(0, XTianqi.FIGHTERS).filter(func(id): return XTier.is_super(int(id)))
	_check("deploy.cap_holds", fighters.size() <= XTianqi.super_cap(s), s.battle_slots)
	await _key(KEY_ESCAPE)  # 出战栏 → 指令
	await _key(KEY_ESCAPE)  # 指令取消＝完成，回主菜单
	await _frames(STEP)
	await _key(KEY_ESCAPE)  # 关主菜单
	_check("deploy.closed", await _wait(func(): return _map_idle(XTianqi.HALL_MAP), 300))


func _find_party() -> XPartyScene:
	if _map() == null:
		return null
	var stack: Array = [_map().ui]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is XPartyScene:
			return n
		stack.append_array(n.get_children())
	return null


func _list_to(page: XPartyScene, id: int) -> void:
	for i in page.list_data().size() + 1:
		if int(page.list_data()[page.list_index]) == id:
			return
		await _key(KEY_DOWN)


## 三、取消与覆盖确认；每页按 Esc 退回上一页
func _cancel_and_overwrite() -> void:
	_check("cancel.to_title", await _to_title_via_menu())
	_check("cancel.new_game", await _title_key("new_game"))
	await _wait(func(): return _btn("TianqiSlot%d" % SLOT) != null, 60)
	await _press_focused(_btn("TianqiSlot%d" % SLOT))
	_check("cancel.overwrite_page", _btn_text("覆盖它") != null and _btn_text("换一格") != null, _page_title())
	await _press_focused(_btn_text("换一格"))
	_check("cancel.back_to_slots", _btn("TianqiSlot%d" % SLOT) != null, _page_title())
	await _press_focused(_btn("TianqiSlot%d" % SLOT))
	await _press_focused(_btn_text("覆盖它"))
	_check("cancel.overwrite_to_difficulty", _btn("TianqiDifficulty_jiusi") != null, _page_title())
	await _press_focused(_btn("TianqiDifficulty_jiusi"))
	_check("cancel.lineup_page", _btn("TianqiReroll") != null, _page_title())
	# 逐页按取消键：阵容 → 难度 → 选格 → 标题。ESC_BACK＝false 时（现状）取消键不动、改按「返回」按钮走，见常量说明
	for step in [["lineup_to_difficulty", "TianqiReroll", "TianqiDifficulty_jiusi"],
			["difficulty_to_slots", "TianqiDifficulty_jiusi", "TianqiSlot%d" % SLOT], ["slots_to_title", "TianqiSlot%d" % SLOT, ""]]:
		var title_before := _page_title()
		await _key(KEY_ESCAPE)
		var went_back: bool = _title_ready() if step[2] == "" else _btn(step[2]) != null
		if ESC_BACK:
			_check("cancel.esc_" + step[0], went_back, _page_title())
		else:
			_check("cancel.esc_" + step[0] + "_stays", not went_back and _btn(step[1]) != null and _page_title() == title_before, _page_title())
			await _press_focused(_btn_text("返回"))
			await _wait(_title_ready, 30)  # 不把 await 放进三元式（会被静默跳过）
			var back_ok: bool = _title_ready() if step[2] == "" else _btn(step[2]) != null
			_check("cancel.back_" + step[0], back_ok, _page_title())
	_check("cancel.old_save_kept", str(_saved_flags(SLOT).get("flags", {}).get("tianqi", {}).get("difficulty", "")) == "jiusi")


## 二、触屏主线：点完全程，炼狱覆盖 3 号档
func _touch_main() -> void:
	if not _title_ready():
		await _wait(_title_ready, 120)
	await _tap_node(_title_node("new_game"))
	var slot_btn := _btn("TianqiSlot%d" % SLOT)
	if not _check("touch.slot_page", slot_btn != null, _page_title()):
		return
	await _tap_node(slot_btn)
	var over := _btn_text("覆盖它")
	_check("touch.overwrite_page", over != null, _page_title())
	if over != null:
		await _tap_node(over)
	var diff := _btn("TianqiDifficulty_lianyu")
	if not _check("touch.difficulty_page", diff != null, _page_title()):
		return
	await _tap_node(diff)
	var first := _lineup_shown()
	_check("touch.lineup_page", XTianqi.lineup_ok("lianyu", first), first)
	var lineup := first
	for i in 5:
		await _tap_node(_btn("TianqiReroll"))
		lineup = _lineup_shown()
		if lineup != first:
			break
	_check("touch.reroll", lineup != first and XTianqi.lineup_ok("lianyu", lineup), [first, lineup])
	await _tap_node(_btn("TianqiConfirm"))
	var in_map := await _wait(func(): return _map() != null and _map().map_id == XTianqi.HALL_MAP, 600)
	if not _check("touch.hall_map", in_map):
		return
	_check("touch.hub_ready", await _drive_hub(true, DAO_TOUCH))
	var s := XState.current
	_check("touch.state", Array(s.party) == lineup and s.actor_name == DAO_TOUCH and str(s.flags.tianqi.difficulty) == "lianyu"
		and s.fixed_save_slot() == SLOT, [s.party, lineup, s.actor_name, s.flags.get("tianqi")])
	var f = _saved_flags(SLOT).get("flags", {})
	_check("touch.old_save_replaced", f is Dictionary and str(f.get("tianqi", {}).get("difficulty", "")) == "lianyu"
		and Array(f.tianqi.lineup).map(func(v): return int(v)) == lineup, f.get("tianqi") if f is Dictionary else null)


## 五、开关回退
func _revert() -> void:
	_check("revert.to_title", await _to_title_via_menu())
	XTianqi.ENABLED = false
	await _wait(_title_ready, 60)
	var before := XState.current
	var ok := await _title_key_press_only("new_game")
	ok = ok and await _wait(func(): return XState.current != before, 30)
	var s := XState.current
	_check("revert.original_opening", ok and s.map_id == 1 and not XTianqi.active(s) and not s.flags.has("tianqi") and not XTianqi.has_pending(),
		[ok, s.map_id, s.flags.get("tianqi")])
	# 同一帧切回标题，不真的跑原版 Map001 开局事件（同 xiyou_tianqi_opening 的 _revert）
	GameApp.enter_mode("xiyou")
	var up := InputEventKey.new()
	up.keycode = KEY_ENTER
	up.physical_keycode = KEY_ENTER
	Input.parse_input_event(up)  # 补上回车的松开
	XTianqi.ENABLED = true
	await _wait(_title_ready, 300)
	_check("revert.load_tianqi_save", await _load_slot(SLOT))
	var t := XState.current
	_check("revert.tianqi_rules_after_load", XTianqi.active(t) and str(t.flags.tianqi.difficulty) == "lianyu" and XTianqi.super_cap(t) == 2
		and t.actor_name == DAO_TOUCH, [t.flags.get("tianqi"), t.actor_name])


## 移到标题项后只发「按下」：原版开局在按下这一下就建局并切场景，测试看到新局的同一帧就切回标题（不跑原版 Map001 开局事件）
func _title_key_press_only(key: String) -> bool:
	var target := _title_node(key)
	for i in 8:
		if _title_sel_node() == target:
			break
		await _key(KEY_DOWN)
	if _title_sel_node() != target:
		return false
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.physical_keycode = KEY_ENTER
	e.pressed = true
	Input.parse_input_event(e)
	return true
