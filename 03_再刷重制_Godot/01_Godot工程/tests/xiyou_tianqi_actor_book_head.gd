extends Node
## 【cc·T554·未经审查】天启篇人物图鉴牌头（Kyo 11-27：小铃兰立绘出圈、「矢」、属性与角色属性混淆、武器防具排版；事项 84 只改天启篇）。
## - 全员扫：天启篇目录里每位有名角色、侧视图三格，立绘看得见的部分都在法阵外接方框里（XSkinBookPage.sprite_place）；
##   本来就放得下的（64 格原生图、有档案的新角色）位置大小一点不变，只有放不下的才缩。
## - 牌头三行：角色属性（元素色）／武器／防具，掌握去重（小铃兰两个法杖）、一类全会写「全部」、类型名不拆字；
##   原版「属性」（人物属性）天启篇不画。
## - 西游档不变：actor_info 与改前一致（开关全关时的结果），立绘不缩；开关关＝天启篇也回改前。
## 带 -- --out=<目录> 且有窗口时截图：小铃兰、宿傩、1 号、奈叶 改前／改后，1280×720。
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
		print("FAIL ", name, " ", JSON.stringify(detail).left(1200))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String, sz := Vector2i(1280, 720)) -> void:
	if not windowed():
		return
	var win := get_window()
	var old := win.size
	win.size = sz
	await frames(12)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	win.size = old
	await frames(4)


func _state(tianqi := true) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	if tianqi:
		s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	XState.current = s
	return s


func _switches(on: bool) -> void:
	XSkinBookPage.FIT_SPRITE = on
	XSkinBookPage.HEAD_ROWS = on


func _run() -> void:
	TestEnv.isolate("xiyou_tianqi_actor_book_head")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	_scan()
	_head()
	_xiyou_same()
	await _shots()
	_switches(true)
	XUiSkin.motion_override = -1
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 全员扫：放得下的不动，放不下的缩进来
func _scan() -> void:
	_state(true)
	_switches(true)
	var cc := Vector2(200, 200)
	var r := XSkinBookPage.CIRCLE_R
	var box := Rect2(cc - Vector2(r, r), Vector2(r, r) * 2.0).grow(0.5)
	var bad := []
	var moved_fit_ok := []
	var fitted := []
	var no_pixels := []
	var n := 0
	for id in XActorBook.index_ids():
		if int(id) <= 0:
			continue
		var spec := XActorBook.sprite_spec(int(id))
		var p := str(spec.get("path", ""))
		if p == "":
			continue
		var tex: Texture2D = load(p)
		if tex == null:
			continue
		n += 1
		# 正式跑读得到像素（不透明外接框）；无头读不到时退回整格。两种都要在圈里
		var used := XSkinBookPage.opaque_rect_of(Image.load_from_file(ProjectSettings.globalize_path(p)), spec)
		if not used.has_area():
			no_pixels.append(id)
		for pattern in 3:
			XSkinBookPage.FIT_SPRITE = true
			var pl := XSkinBookPage.sprite_place(int(id), spec, Vector2(tex.get_size()), pattern, cc, r, used)
			var pl_frame := XSkinBookPage.sprite_place(int(id), spec, Vector2(tex.get_size()), pattern, cc, r)
			XSkinBookPage.FIT_SPRITE = false
			var old := XSkinBookPage.sprite_place(int(id), spec, Vector2(tex.get_size()), pattern, cc, r, used)
			if not box.encloses(pl.vis) or not box.encloses(pl_frame.vis):
				bad.append([id, XActorBook.actor_name(int(id)), pattern, pl.vis, pl_frame.vis])
			if bool(pl.fit):
				if pattern == 0:
					fitted.append([id, XActorBook.actor_name(int(id))])
			elif pl.draw != old.draw:
				moved_fit_ok.append([id, pattern])
	XSkinBookPage.FIT_SPRITE = true
	print("T554 立绘扫描：%d 位，缩过的 %s" % [n, JSON.stringify(fitted)])
	check("scan.count", n >= 150, n)
	check("scan.pixels_read", no_pixels.is_empty(), no_pixels)
	check("scan.all_inside_circle", bad.is_empty(), bad)
	check("scan.fit_untouched_unchanged", moved_fit_ok.is_empty(), moved_fit_ok)
	check("scan.suzuran_fitted", fitted.any(func(f): return int(f[0]) == 127), fitted)
	check("scan.actor1_not_fitted", not fitted.any(func(f): return int(f[0]) == 1), fitted)
	# 小铃兰缩完不至于太小（按不透明外接框缩，不按整格）：看得见的高至少占法阵直径一半
	var sp := XActorBook.sprite_spec(127)
	var t127: Texture2D = load(str(sp.path))
	var u127 := XSkinBookPage.opaque_rect_of(Image.load_from_file(ProjectSettings.globalize_path(str(sp.path))), sp)
	var pl127 := XSkinBookPage.sprite_place(127, sp, Vector2(t127.get_size()), 0, cc, r, u127)
	check("scan.suzuran_size", pl127.vis.size.y >= r and pl127.vis.size.y <= r * 2.0, pl127.vis)


## 牌头三行的数据
func _head() -> void:
	_state(true)
	_switches(true)
	var i127 := XSkinBookPage.actor_info(127)
	check("head.on_tianqi", bool(i127.head_rows), i127.get("head_rows"))
	var w: Array = i127.weapons
	var uniq := []
	for x in w:
		if not uniq.has(x):
			uniq.append(x)
	check("head.weapons_dedup", w == uniq and w.count("法杖") == 1, w)
	var rows := XSkinBookPage.head_rows(i127)
	check("head.rows_labels", rows.map(func(r): return str(r[0])) == [XTianqiNature.LABEL, "武器", "防具"], rows.map(func(r): return r[0]))
	check("head.suzuran_weapons_all", bool(i127.weapons_all) and str(rows[1][1][0][0]) == XSkinBookPage.T_ALL, rows[1])
	# 角色属性上元素色（小铃兰火焰）
	var nat := XTianqiNature.natures_of_actor_id(127)
	var np: Array = rows[0][1]
	check("head.nature_colored", not nat.is_empty() and np.size() == nat.size()
		and range(nat.size()).all(func(k): return np[k][1] == Color(XHelpCard.ELEMENT_COLORS[int(nat[k])]) and str(np[k][0]).begins_with(XTianqiElements.element_name(int(nat[k])))),
		[nat, np])
	# 宿傩没体质：「无」灰字；武器两种照列
	var i172 := XSkinBookPage.actor_info(172)
	var r172 := XSkinBookPage.head_rows(i172)
	if XTianqiNature.natures_of_actor_id(172).is_empty():
		check("head.sukuna_nature_none", r172[0][1].size() == 1 and str(r172[0][1][0][0]) == "无" and r172[0][1][0][1] == XUiSkin.TEXT_3, r172[0])
	check("head.sukuna_weapons_listed", not bool(i172.weapons_all) and r172[1][1].size() == (i172.weapons as Array).size(), r172[1])
	# 「矢」：类型表 13 号，只有 4541 一件；HIDE_ARMOR_TYPES 默认不藏
	var sys_at: Array = XDB.system().get("armorTypes", [])
	check("head.arrow_type_13", sys_at.size() > 13 and str(sys_at[13]) == "矢", sys_at)
	XSkinBookPage.HIDE_ARMOR_TYPES = [13]
	var hid := XSkinBookPage.actor_info(172)
	check("head.arrow_hidden_when_set", not (hid.armors as Array).has("矢") and bool(hid.armors_all), hid.armors)
	XSkinBookPage.HIDE_ARMOR_TYPES = []
	# 不拆字：每一段都是整个类型名（＋顿号），排行时段不跨行
	var f := XUiSkin.font("body")
	var r127 := XSkinBookPage.head_rows(i127)   # 小铃兰防具 12 种（不会矢）照列
	check("head.suzuran_armors_listed", not bool(i127.armors_all) and not (i127.armors as Array).has("矢"), i127.armors)
	var lines := XSkinBookPage.token_lines(r127[2][1], f, XUiSkin.FS_AUX, 220.0)
	var flat := []
	for ln in lines:
		var lw := 0.0
		for t in ln:
			flat.append(str(t[0]))
			lw += f.get_string_size(str(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		check("head.line_fits.%d" % flat.size(), lw <= 220.5 or ln.size() == 1, [lw, ln])
	check("head.tokens_whole", "".join(flat) == "、".join(i127.armors), ["".join(flat)])
	check("head.multi_lines", lines.size() >= 2, lines.size())
	# 开关关＝天启篇回改前
	_switches(false)
	var off := XSkinBookPage.actor_info(127)
	check("head.switch_off_old", not bool(off.head_rows) and (off.weapons as Array).count("法杖") == 2, off.weapons)
	_switches(true)


## 西游档：actor_info 与开关全关时逐项相等；立绘不缩
func _xiyou_same() -> void:
	_state(false)
	var diffs := []
	for id in [1, 8, 108, 127, 167, 172]:
		_switches(true)
		var on := XSkinBookPage.actor_info(id)
		_switches(false)
		var off := XSkinBookPage.actor_info(id)
		_switches(true)
		for k in off:
			if str(off[k]) != str(on.get(k)):
				diffs.append([id, k])
		check("xiyou.head_off.%d" % id, not bool(on.get("head_rows", false)) and (on.get("nature_parts", []) as Array).is_empty())
		var sp := XActorBook.sprite_spec(id)
		if str(sp.get("path", "")) != "":
			var tex: Texture2D = load(str(sp.path))
			var pl := XSkinBookPage.sprite_place(id, sp, Vector2(tex.get_size()), 0, Vector2(200, 200), XSkinBookPage.CIRCLE_R)
			check("xiyou.sprite_not_fitted.%d" % id, not bool(pl.fit))
	check("xiyou.info_unchanged", diffs.is_empty(), diffs)


## 改前／改后截图（要窗口）
func _shots() -> void:
	if not windowed():
		return
	_state(true)
	for phase in ["before", "after"]:
		_switches(phase == "after")
		var a := XActorBook.new()
		add_child(a)
		await frames(3)
		for id in [127, 172, 1, 108]:
			var slot := XActorBook.index_ids().find(id)
			if slot < 0:
				continue
			a.select(slot)
			await frames(2)
			await shot("t554_%s_%d_16x9" % [phase, id])
		a.queue_free()
		await frames(2)
	_switches(true)
