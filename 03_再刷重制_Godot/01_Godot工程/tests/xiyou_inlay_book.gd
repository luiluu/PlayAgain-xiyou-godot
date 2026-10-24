extends Node
## 装备镶嵌图鉴（XInlayBook）：对照冻结 v0.28 浏览器参照 tests/fixtures/inlay_book_oracle.json
## （ui_reference/review_system_pages.js 的 inlay_book：内存新局、StarEIBook GetAll 后打开 Scene_EquipInlayBook）：
## 窗口矩形、武器 117／防具 115 项目录、每一项状态窗的全部 drawText／drawIcon（文字、字号、对齐、颜色逐条相等，坐标与宽差 ≤ POS_TOL），
## 四个截图状态的类型窗／目录窗文字与光标；再走一遍操作（开场类型窗、确定列目录并选第 1 项、滚动、取消清空、换防具、关闭），
## 以及魂灯商人 Map4 EV40 p1／p3 的两条指令（StarEIBook GetAll、SceneManager.push）都认得并打开图鉴。

const FIXTURE := "res://tests/fixtures/inlay_book_oracle.json"
## 类型名逐个右移 textWidth(名字＋两个空格)，Godot 与浏览器的小数字宽每个差约 0.01，八个类型累计到 0.05～0.1
const POS_TOL := 0.15

var results := []
var out_dir := ""


class FakeHost extends Node:
	var opened := 0
	func open_inlay_book() -> void:
		opened += 1
		await get_tree().process_frame
	func refresh_events() -> void:
		pass
	func character(_id: int, _event_id: int):
		return null


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


## 截图（与原版 inlay_0～inlay_3 同态）
func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


static func _color(text: String) -> String:
	return (XQuality.parse_rgba(text) if text.begins_with("rgba") else Color(text)).to_html(false)


## 参照 → 比较形：文字 [文字,x,y,宽,对齐,字号,颜色hex]、图标 [图标号,x,y]
static func want_form(texts: Array, icons: Array) -> Array:
	var out := []
	for t in texts:
		out.append([str(t[0]), float(t[1]), float(t[2]), float(t[3]), str(t[4]), float(t[5]), _color(str(t[6]))])
	for i in icons:
		out.append([int(i[0]), float(i[1]), float(i[2])])
	return _sorted(out)


static func got_form(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "i":
			out.append([int(o[1]), float(o[2]), float(o[3])])
		else:
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[6]), float(o[7]), (o[8] as Color).to_html(false)])
	return _sorted(out)


static func _sorted(a: Array) -> Array:
	a.sort_custom(func(x, y): return [x[2], x[1], str(x[0])] < [y[2], y[1], str(y[0])] if x.size() == y.size() else x.size() < y.size())
	return a


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		var bad := g.size() != w.size()
		if not bad:
			for k in w.size():
				if w[k] is String:
					bad = bad or str(g[k]) != w[k]
				else:
					bad = bad or absf(float(g[k]) - float(w[k])) > POS_TOL
		if bad:
			return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


## 目录窗／类型窗的一屏文字（与参照 texts 同形）
static func row_texts(names: Array, top: int) -> Array:
	var out := []
	for i in range(top, mini(top + XInlayBook.ROWS, names.size())):
		out.append(XInlayBook._t(str(names[i]), 6, (i - top) * 36.0, XInlayBook.ROW_W))
	return out


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("status", {}).has("weapon"), FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	XState.current = XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		XState.current.add_actor(id)
	_oracle(ref)
	await _flow(ref)
	await _interpreter()
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _oracle(ref: Dictionary) -> void:
	var lists := XInlayBook.recipes()
	for k in 2:
		var key: String = ["weapon", "armor"][k]
		var got: Array = lists[k].map(func(r): return [int(r.id), str(r.name)])
		var want: Array = ref.lists[key].map(func(x): return [int(x[0]), str(x[1])])
		check("list_" + key, got == want, [got.size(), want.size(), got.slice(0, 3), want.slice(0, 3)])
		var bad := []
		for i in mini(lists[k].size(), ref.status[key].size()):
			var st: Dictionary = ref.status[key][i]
			var d := diff(got_form(XInlayBook.status_ops(lists[k][i], k)), want_form(st.texts, st.icons))
			if d != "":
				bad.append("%s#%d(配方%d) %s" % [key, i, int(st.id), d])
		check("status_" + key, bad.is_empty() and ref.status[key].size() == lists[k].size(), {"count": bad.size(), "first": bad.slice(0, 5)})


func _win_texts(ref: Dictionary, shot_name: String, type: String) -> Array:
	var w: Dictionary = ref.shots[shot_name][type]
	return want_form(w.texts, [])


func _flow(ref: Dictionary) -> void:
	var book := XInlayBook.new()
	add_child(book)
	await frames()
	var geo: Dictionary = ref.geo
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	check("geometry", rect.call(book.type_win) == geo.type.map(func(x): return float(x))
		and rect.call(book.index_win) == geo.index.map(func(x): return float(x))
		and rect.call(book.status_win) == geo.status.map(func(x): return float(x)) and int(geo.rows) == XInlayBook.ROWS,
		[rect.call(book.type_win), rect.call(book.index_win), rect.call(book.status_win)])
	var types := row_texts(XInlayBook.TYPES, 0)
	# inlay_0：类型窗激活、目录空、状态窗空
	await shot("inlay_0")
	var s0: Dictionary = ref.shots.inlay_0
	check("open_type", book.mode == "type" and book.type_index == int(s0.Window_EquipInlayBookTypeIndex.index)
		and book.index == int(s0.Window_EquipInlayBookIndex.index) and book.list.is_empty() and book._status_ops.is_empty()
		and diff(got_form(types), _win_texts(ref, "inlay_0", "Window_EquipInlayBookTypeIndex")) == "",
		[book.mode, book.index, book.list.size()])
	# inlay_1：确定 → 武器目录第 1 项
	book.ok()
	await shot("inlay_1_weapon")
	var st: Dictionary = ref.shots.inlay_1_weapon.Window_EquipInlayBookStatus
	var names: Array = book.list.map(func(r): return r.name)
	check("weapon_first", book.mode == "index" and book.index == 0 and book.top == 0
		and diff(got_form(row_texts(names, 0)), _win_texts(ref, "inlay_1_weapon", "Window_EquipInlayBookIndex")) == ""
		and diff(got_form(book._status_ops.filter(func(o): return o[0] == "t")), want_form(st.texts, [])) == "",
		diff(got_form(book._status_ops.filter(func(o): return o[0] == "t")), want_form(st.texts, [])))
	# inlay_2：第 20 项（滚到 top 4）
	for i in 19:
		book._move(1, true)
	await shot("inlay_2_weapon_20")
	st = ref.shots.inlay_2_weapon_20.Window_EquipInlayBookStatus
	check("weapon_20", book.index == int(ref.shots.inlay_2_weapon_20.Window_EquipInlayBookIndex.index) and book.top == 4
		and diff(got_form(row_texts(names, 4)), _win_texts(ref, "inlay_2_weapon_20", "Window_EquipInlayBookIndex")) == ""
		and diff(got_form(book._status_ops.filter(func(o): return o[0] == "t")), want_form(st.texts, [])) == "",
		[book.index, book.top])
	# 翻页：16 行一页
	book._page(1)
	check("page_down", book.top == 20 and book.index == 35, [book.top, book.index])
	book._page(-1)
	check("page_up", book.top == 4 and book.index == 19, [book.top, book.index])
	# 取消：目录、状态窗清空，回类型窗
	book.cancel()
	check("cancel_clears", book.mode == "type" and book.list.is_empty() and book.index == -1 and book._status_ops.is_empty())
	# inlay_3：换防具
	book._move(1, true)
	book.ok()
	await shot("inlay_3_armor")
	st = ref.shots.inlay_3_armor.Window_EquipInlayBookStatus
	names = book.list.map(func(r): return r.name)
	check("armor_first", book.type_index == 1 and book.index == 0
		and diff(got_form(row_texts(names, 0)), _win_texts(ref, "inlay_3_armor", "Window_EquipInlayBookIndex")) == ""
		and diff(got_form(book._status_ops.filter(func(o): return o[0] == "t")), want_form(st.texts, [])) == "")
	# 目录窗没有确定处理
	book.ok()
	check("index_ok_noop", book.mode == "index" and book.index == 0)
	var closed := [false]
	book.closed.connect(func(): closed[0] = true)
	book.cancel()
	check("cancel_to_type", not closed[0] and book.mode == "type" and book.type_index == 1)
	book.cancel()
	check("cancel_closes", closed[0])
	book.queue_free()
	await frames()


## 魂灯商人 Map4 EV40 p1／p3「查看图鉴」两条指令：都认得、打开图鉴一次
func _interpreter() -> void:
	var ev: Dictionary = {}
	for e in XDB.map(4).events:
		if e is Dictionary and int(e.get("id", 0)) == 40:
			ev = e
	if not check("map4_ev40_present", not ev.is_empty()):
		return
	for p in [1, 3]:
		var cmds: Array = ev.pages[p].list.filter(func(c): return int(c.code) in [355, 356] and (str(c.parameters[0]).contains("EIBook") or str(c.parameters[0]).contains("EquipInlayBook")))
		cmds = cmds.map(func(c): return {"code": int(c.code), "indent": 0, "parameters": c.parameters})
		cmds.append({"code": 0, "indent": 0, "parameters": []})
		var h := FakeHost.new()
		add_child(h)
		var it := MVInterpreter.new(h, 4, 40, cmds)
		await it.run()
		check("ev40_p%d_opens" % p, cmds.size() == 3 and h.opened == 1 and it.skipped.is_empty(), [cmds.size(), h.opened, it.skipped])
		h.queue_free()
	await frames()
