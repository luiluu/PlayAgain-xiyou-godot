extends Node
## T620 量数探针（只量不改；不是回归测试，不进检查.sh）：真地图 → 主菜单 → 物品页，反复用伙伴号角（已有该队友，回地图跑事件再回物品页），
## 每次回来后在物品列表翻页 PAGES 次（每次＝_page＋_refresh＋下一帧），记耗时，以及节点数、对象数、孤儿节点、地图 ui 子节点数。
## 跑法：复制进 01_Godot工程/tests/，临时建一个挂它的 .tscn（不入库），
##   godot --headless --audio-driver Dummy --path . res://tests/<临时>.tscn -- [--uses=30] [--pages=10] [--distinct 每次招新人] [--stick 推住摇杆翻页] [--set=res://…gd:开关=false]
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var uses := 30
var pages := 10
var distinct := false
var stick := false
var tc: XTouchControls
var horns: Array = []
var map: XMapScene


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--uses="): uses = int(arg.substr(7))
		elif arg.begins_with("--pages="): pages = int(arg.substr(8))
		elif arg == "--distinct": distinct = true
		elif arg == "--stick": stick = true
	_switch_args()
	_run.call_deferred()


func _switch_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--set="):
			continue
		var spec := arg.substr(6)
		var path := spec.get_slice(":", 0) + ":" + spec.get_slice(":", 1)
		var rest := spec.substr(path.length() + 1)
		var name := rest.get_slice("=", 0)
		var val := rest.get_slice("=", 1) == "true"
		var sc = load(path)
		sc.set(name, val)
		print("SWITCH %s.%s -> %s" % [path.get_file(), name, str(sc.get(name))])


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children(true):
		c += _count(k)
	return c


func _paths(n: Node, out := {}) -> Dictionary:
	out[str(n.get_path())] = n.get_class() + ("[" + str(n.get_script().resource_path.get_file()) + "]" if n.get_script() != null else "")
	for k in n.get_children(true):
		_paths(k, out)
	return out


func _page_of() -> XItemScene:
	for m in map.ui.get_children():
		if m is XMenu and not m.is_queued_for_deletion():
			for p in m.get_children():
				if p is XItemScene and not p.is_queued_for_deletion() and p._mode == "list":
					return p
	return null


func _run() -> void:
	XPetCapture.clock = func(): return {"day": 1, "hour": 12, "minute": 15}
	XMessageBox.auto = true
	TestEnv.isolate("t620_probe")
	print("TESTMODE ", XTestMode.enabled())
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.add_actor(11)
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.direction = 8
	s._gain_raw(10, uses + 5)
	if distinct:
		for rec in XDB.table("Items"):
			if rec is Dictionary and XBabyAllActors.is_horn(rec) and horns.size() < uses + 2:
				var aid := XBabyAllActors.horn_actor(rec)
				if aid > 0 and not s.party.has(aid):
					horns.append(int(rec.id))
					s._gain_raw(int(rec.id), 1)
	# 背包多放些东西，翻页有得翻
	var n := 0
	for rec in XDB.table("Items"):
		if rec is Dictionary and str(rec.get("name", "")) != "" and int(rec.get("id", 0)) != 10 and n < 120:
			s._gain_raw(int(rec.id), 1)
			n += 1
	var segment := XGuide.segment_of(XZhenqi.progress_floor(s))
	if not segment.is_empty():
		XGuide.seen(s, "seg:" + str(segment.key), true)
	map = XMapScene.new()
	add_child(map)
	for i in 600:
		if map.player != null and map.map_id == 4 and not map.busy:
			break
		await frames(1)
	await frames(2)
	map.open_menu()
	var menu: XMenu
	for i in 300:
		var menus := map.ui.get_children().filter(func(x): return x is XMenu)
		if not menus.is_empty():
			menu = menus[0]
			break
		await frames(1)
	menu._cmd_index = 0
	menu._ok()
	await frames(2)
	var page: XItemScene = menu.get_children().filter(func(x): return x is XItemScene)[0]
	page._cat = 0
	page._mode = "list"
	page._refresh()
	if stick:
		tc = XTouchControls.new()
		get_tree().root.add_child(tc)
		await frames(2)
	var base_nodes := _count(get_tree().root)
	var base_paths := _paths(get_tree().root)
	var base_obj := Performance.get_monitor(Performance.OBJECT_COUNT)
	for u in uses + 1:
		# 翻页量数
		var tot := 0.0
		var mx := 0.0
		var optot := 0.0
		for k in pages:
			var d := 1 if k % 2 == 0 else -1
			var t := Time.get_ticks_usec()
			page._page(d)
			page._refresh()
			var op := (Time.get_ticks_usec() - t) / 1000.0
			var t2 := Time.get_ticks_usec()
			await frames(1)
			var fr := (Time.get_ticks_usec() - t2) / 1000.0
			tot += op + fr
			optot += op
			mx = maxf(mx, op + fr)
		if stick:
			await _stick_hold(u, page)
		var idle := 0.0
		for k in 5:
			var t3 := Time.get_ticks_usec()
			await frames(1)
			idle += (Time.get_ticks_usec() - t3) / 1000.0
		print("MEM %d static=%.1fMB tex=%.1fMB vmem=%.1fMB" % [u, OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		print("USE %d op_mean=%.2f page_mean=%.2f page_max=%.2f idle=%.2f nodes=%d(+%d) objs=%d(+%d) orphans=%d ui_children=%d menu_children=%d page_children=%d" % [
			u, optot / pages, tot / pages, mx, idle / 5.0, _count(get_tree().root), _count(get_tree().root) - base_nodes,
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT) - base_obj,
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), map.ui.get_child_count(),
			page.get_parent().get_child_count(), page.get_child_count()])
		if u == 0 or u == uses:
			_breakdown(page)
		if u == uses:
			var now := _paths(get_tree().root)
			var hist := {}
			for k in now:
				hist[now[k]] = int(hist.get(now[k], 0)) + 1
			for k in base_paths:
				hist[base_paths[k]] = int(hist.get(base_paths[k], 0)) - 1
			for k in hist.keys():
				if hist[k] == 0:
					hist.erase(k)
			for k in hist:
				print("NEW ", hist[k], " ", k)
			break
		# 用号角
		page._cat = 0
		page._mode = "list"
		var hid := 10 if not distinct else int(horns[u % horns.size()])
		page._index = page.entries().find_custom(func(e): return int(e.rec.id) == hid)
		if page._index < 0:
			print("NO_HORN")
			break
		page._refresh()
		page._ok()
		page._ok()
		if page._mode == "actor":
			page._actor = 0
			page._ok()
		var back: XItemScene = null
		for i in 900:
			back = _page_of()
			if back != null and back != page:
				break
			back = null
			await frames(1)
		if back == null:
			print("NOT_RETURNED to_map=", page.to_map)
			break
		page = back
		await frames(2)
		if distinct and u % 5 == 0:
			print("PARTY ", XState.current.party.size(), " actors=", XState.current.actors.size() if "actors" in XState.current else -1)
	for w in 4:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 5000:
			await frames(1)
		var tl := get_tree().root.get_node_or_null("XToast")
		print("WAIT %ds toasts=%d" % [(w + 1) * 5, tl.stack.get_child_count() if tl else -1])
	print("DONE")
	get_tree().quit(0)


func _breakdown(page: XItemScene) -> void:
	var parts := {}
	for k in 20:
		page._page(1 if k % 2 == 0 else -1)
		var t := Time.get_ticks_usec()
		page.entries()
		parts["entries"] = float(parts.get("entries", 0.0)) + (Time.get_ticks_usec() - t) / 1000.0
		for w in ["cat_win", "status_win", "list_win", "info_win", "actor_win", "bulk_win", "treasure_win"]:
			t = Time.get_ticks_usec()
			page.get(w).refresh()
			parts[w] = float(parts.get(w, 0.0)) + (Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		page._update_help()
		parts["help"] = float(parts.get("help", 0.0)) + (Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		page._sync_gear()
		parts["gear"] = float(parts.get("gear", 0.0)) + (Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		page._refresh()
		parts["whole"] = float(parts.get("whole", 0.0)) + (Time.get_ticks_usec() - t) / 1000.0
	var line := "BREAK"
	for k in parts:
		line += " %s=%.2f" % [k, parts[k] / 20.0]
	print(line)


func _handlers(n: Node) -> int:
	var c := 1 if (n.is_processing_input() or n.is_processing_unhandled_input() or n.is_processing_unhandled_key_input() or n.is_processing_shortcut_input()) else 0
	for k in n.get_children(true):
		c += _handlers(k)
	return c


## 推住摇杆往右：36 帧后每 24 帧翻一页；量推住期间每帧耗时（含输入分发、刷新）
func _stick_hold(u: int, page: XItemScene) -> void:
	var sent0 := tc.pages_sent
	var top0 := page._top
	var times := []
	tc._stick_offset = Vector2(tc.stick_radius, 0)
	tc._set_dir("ui_right")
	for k in 36 + 24 * pages:
		var t := Time.get_ticks_usec()
		await get_tree().physics_frame
		times.append((Time.get_ticks_usec() - t) / 1000.0)
	tc._set_dir("")
	tc._stick_offset = Vector2.ZERO
	await frames(3)
	var mx := 0.0
	var sum := 0.0
	for x in times:
		sum += x
		mx = maxf(mx, x)
	print("STICK %d frame_mean=%.2f frame_max=%.2f pages_sent=%d top=%d->%d handlers=%d conns=%d" % [u, sum / times.size(), mx, tc.pages_sent - sent0, top0, page._top, _handlers(get_tree().root), _conns()])


## 视口、场景树、触屏层、Input 单例上所有信号的连接数
func _conns() -> int:
	var c := 0
	for o in [get_tree().root, get_tree(), tc, Input]:
		for sig in o.get_signal_list():
			c += o.get_signal_connection_list(sig.name).size()
	return c
