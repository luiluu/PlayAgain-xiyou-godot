extends Node
## 宝珠镶嵌界面（物品页）与正式版运行时读数（tests/fixtures/orb_ui_oracle.json，ui_reference 浏览器采集）比对：
## 武器 3 孔（一孔已镶）、副手 2 空孔、神武 1 孔已镶、防具 0 孔、防具 2 孔都镶——操作菜单各行文字／可选／孔号、
## 信息窗「镶嵌物」标题与孔行的位置和文字、每个孔的宝珠列表（行、可选性、取下行、列表矩形）、取消回原行，
## 以及在不可选行确定（蜂鸣、留在列表）、镶嵌后回到操作菜单原行与背包数量。

var results := []
var out_dir := ""
const FIXTURE := "res://tests/fixtures/orb_ui_oracle.json"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


## 窗口模式加 -- --out=<目录>：保存与正式截图同场景的画面
func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _state(fx: Dictionary) -> Array:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.items = {}
	s.gear.clear()
	var refs := {}
	for e in fx.equips:
		var g := XGear.create(str(e.kind), int(e.base))
		s.register_gear(g)
		g.augmentSlots = []
		g.augmentSlotEnable = []
		g.augmentSlotItems = []
		for i in range(int(e.slots)):
			g.augmentSlots.append(str(e.type))
			g.augmentSlotEnable.append(true)
			g.augmentSlotItems.append("none")
		for f in e.fill:
			s.gain_item(int(f[1]), 1)
			XOrbs.apply(g, XDB.rec("Items", int(f[1])), int(f[0]), s)
		s.gear.append(g)
		refs[e.key] = g
	for id in [2947, 2949, 2952, 3018, 2997, 3000, 3012, 56, 441, 2000]:
		s.gain_item(id, 1)
		s.mark_seen(XDB.rec("Items", id))   # 记录画布不接 NEW 角标的贴图绘制
	return [s, refs]


## 打开物品页，选中这件装备进操作菜单
func _open(page: XItemScene, eq: Dictionary) -> void:
	page._cat = XShop.CATEGORIES.map(func(c): return c[1]).find(str(eq.kind))
	page._mode = "category"
	page._ok()
	page._index = page.entries().find_custom(func(x): return is_same(x.rec, eq))
	page._ok()


## 文字绘制按行合并（y → 首字 x、拼接文字、末字颜色），对照正式 drawText 记录
static func lines(log: Array) -> Array:
	var by := {}
	for x in log:
		if x[0] != "text":
			continue
		var y := int(roundf(x[3]))
		if not by.has(y):
			by[y] = []
		by[y].append(x)
	var keys := by.keys()
	keys.sort()
	var out := []
	for y in keys:
		var g: Array = by[y]
		g.sort_custom(func(a, b): return a[2] < b[2])
		out.append([y, snappedf(g[0][2], 0.01), "".join(g.map(func(t): return t[1])), g.back()[7]])
	return out


func _run() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	if check("fixture_loaded", fx is Dictionary and fx.cases.size() == 5, FIXTURE):
		var made := _state(fx)
		var s: XState = made[0]
		var refs: Dictionary = made[1]
		var page := XItemScene.new()
		add_child(page)
		await frames()
		for key in fx.cases:
			_case(page, s, refs[key], key, fx.cases[key])
		if out_dir != "":
			s.items.keys().map(func(id): return s.seen.erase("i:%d" % int(id)))
			_open(page, refs.w3)
			page._act = 3
			page._refresh()
			await shot("orb_action_weapon3")
			page._ok()
			page._refresh()
			await shot("orb_list_weapon_slot1_filled")
			page._cancel()
			page._cancel()
			page._cancel()
		page.queue_free()
		await frames()
		await _ok_flow(fx)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _case(page: XItemScene, s: XState, eq: Dictionary, key: String, want: Dictionary) -> void:
	_open(page, eq)
	page._act = 0
	page._refresh()
	var sym := {"ToLockEq": "lock"}
	var acts: Array = page._actions.map(func(a): return [a.text, a.symbol, a.enabled, a.get("ext")])
	var exp: Array = want.actions.map(func(a): return [a[0], sym.get(a[1], a[1]), a[2], null if a[3] == null else int(a[3])])
	check("actions_" + key, page._mode == "action" and acts == exp, [acts, exp])
	check("action_rect_" + key, page.list_win.position == Vector2(want.actionRect[0], want.actionRect[1]) and page.list_win.size == Vector2(want.actionRect[2], want.actionRect[3]))
	# 信息窗：名字之后的「插槽可用」行只比位置（数字随升级插槽浮动），镶嵌物标题与孔行逐项比
	var rc := RecCanvas.new()
	rc.size = page.info_win.canvas.size
	XItemScene.paint_info(rc, eq)
	var got := lines(rc.log)
	rc.free()
	var colors := {"#84aaff": XUI.SYSTEM, "#808080": XUI.text_color(7), "#ffffff": XUI.TEXT}
	var bad := []
	var wi: Array = want.info.slice(2)
	var gi: Array = got.filter(func(l): return l[0] >= 72)
	if gi.size() != wi.size():
		bad.append(["rows", gi, wi])
	else:
		for i in range(wi.size()):
			var w: Array = wi[i]
			var g: Array = gi[i]
			if g[0] != int(w[0]) or absf(g[1] - float(w[1])) > 0.5 or g[2] != str(w[2]) or (colors.has(w[3]) and not g[3].is_equal_approx(colors[w[3]])):
				bad.append([g, w])
	check("info_" + key, bad.is_empty(), bad)
	# 每个孔的宝珠列表
	for ext in want.lists:
		var lw: Dictionary = want.lists[ext]
		page._act = page._actions.find_custom(func(a): return a.get("ext") == int(ext))
		page._ok()
		var rows: Array = page.augments().map(func(r): return [null if r.rec.is_empty() else float(r.rec.id), r.enabled])
		var help_ok := page.help_card.visible == bool(lw.help)
		check("list_%s_%s" % [key, ext], page._mode == "augment" and rows == lw.rows and page._aug_index == int(lw.index) and help_ok,
			[page._mode, rows, lw.rows, page.help_card.visible, lw.help])
		if lw.removeText != null:
			var rc2 := RecCanvas.new()
			rc2.size = page.list_win.canvas.size
			page._paint_list(rc2)
			var first: Array = lines(rc2.log)[0]
			var icon: Array = rc2.log.filter(func(x): return x[0] == "icon")[0]
			rc2.free()
			check("remove_row_%s_%s" % [key, ext], first[2] == str(lw.removeText.text) and absf(first[1] - float(lw.removeText.x)) < 0.5 and icon[1] == 1348 and icon[3] == 0.0 + 2.0, [first, icon])
		page._cancel()
		check("back_%s_%s" % [key, ext], page._mode == "action" and page._act == int(lw.backIndex), [page._mode, page._act])
	page._cancel()
	page._cancel()


func _ok_flow(fx: Dictionary) -> void:
	var made := _state(fx)
	var s: XState = made[0]
	var w3: Dictionary = made[1].w3
	var page := XItemScene.new()
	add_child(page)
	await frames()
	_open(page, w3)
	page._act = 2
	page._ok()
	var want: Dictionary = fx.ok_flow
	page._aug_index = page.augments().find_custom(func(r): return not r.rec.is_empty() and int(r.rec.id) == 2947)
	var buzz := XSound.system_log.size()
	page._ok()
	check("disabled_ok_buzz", page._mode == "augment" and XSound.system_log.slice(buzz) == [3], [page._mode, XSound.system_log.slice(buzz)])
	page._aug_index = page.augments().find_custom(func(r): return not r.rec.is_empty() and int(r.rec.id) == 2952)
	page._ok()
	var acts: Array = page._actions.map(func(a): return a.text)
	check("install_back_to_action", page._mode == "action" and page._act == int(want.after.actionIndex) and acts == want.after.actions, [page._mode, page._act, acts])
	check("install_state", s.item_count(2952) == int(want.after.fire) and w3.augmentSlotItems == want.after.slots, [s.item_count(2952), w3.augmentSlotItems])
	page.queue_free()
	await frames()


class RecCanvas extends XMVCanvas:
	var log := []

	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
		log.append(["text", s, x, y, max_w, align, size, color])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		log.append(["icon", index, x, y])

	func cursor(r: Rect2, active := true) -> void:
		log.append(["cursor", r])
