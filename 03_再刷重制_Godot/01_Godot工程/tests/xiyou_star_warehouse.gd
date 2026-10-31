extends Node
## 星级仓库（XStarWarehouse／XStarWarehouseScene ← Star_Warehouse 通用仓库）：
## ①画面：对照冻结 v0.28 浏览器参照 tests/fixtures/star_warehouse_oracle.json（ui_reference/review_system_pages.js 的 star_warehouse）
##   九个截图状态的两个窗口文字（坐标与宽差 ≤ POS_TOL，字号、对齐、颜色相等）、窗口矩形、分类与列表光标、说明卡有无、仓库／背包／宠物数据；
## ②存取：对照 mv_oracle star_warehouse_probe（generated/oracle/star_warehouse.json）逐步比列表、背包、宠物、仓库与声音、提示——
##   三个优化开关切到原版（o_block_bound、o_alien_reset、o_save_now 关）时与原版一致；默认开时反向验证各自的差别；
## ③跨档：取出重编号不撞号（Q1）、写盘与重读、损坏文件、o_save_now 关时随 XConfig 写盘；PH 仓库存供体（o_reserved_no_dup 两态）；
## ④黄金大厅 Map041 EV1「存放／取出」的脚本打开画面。全部用临时存档目录，不碰真实存档。

const FIXTURE := "res://tests/fixtures/star_warehouse_oracle.json"
const ORACLE := "res://modes/xiyou/generated/oracle/star_warehouse.json"
const DIR := "user://test_xiyou_star_warehouse"
const POS_TOL := 1.0
const SHOTS := ["sw_0_save_open", "sw_1_save_equip", "sw_2_save_one", "sw_3_save_pet", "sw_3b_save_pet_one",
	"sw_4_load_open", "sw_5_load_equip", "sw_6_load_pet", "sw_7_load_empty"]

var results := []
var out_dir := ""


class RecCanvas extends XMVCanvas:
	var texts := []
	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, _lh := XUI.LINE_HEIGHT, _alpha := 1.0, _zoom := 1.0, _pivot := Vector2.ZERO, _outline := OUTLINE) -> void:
		if s != "":
			texts.append([s, x, y, max_w, align, float(size), color.to_html(false)])
	func character(_n: String, _i: int, _x: float, _y: float, _h := 0.0, _alpha := 1.0) -> void:
		pass
	func icon(_index: int, _x: float, _y: float, _alpha := 1.0, _size := 32.0) -> void:
		pass
	func gauge(_x: float, _y: float, _w: float, _r: float, _c1: Color, _c2: Color, _lh := XUI.LINE_HEIGHT) -> void:
		pass
	func cursor(_r: Rect2, _active := true) -> void:
		pass


class FakeHost extends Node:
	var opened := []
	func open_star_warehouse(save_mode: bool) -> void:
		opened.append(save_mode)
		await get_tree().process_frame
	func refresh_events() -> void:
		pass
	func toast(_t: String) -> void:
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


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


static func record(win: XMVWindow) -> Array:
	var c := RecCanvas.new()
	c.size = win.canvas.size
	win.canvas.painter.call(c)
	var out: Array = c.texts
	c.free()
	return _sorted(out)


static func want_form(texts: Array) -> Array:
	return _sorted(texts.map(func(t): return [str(t[0]), float(t[1]), float(t[2]), float(t[3]), str(t[4]), float(t[5]), _color(str(t[6])).to_html(false)]))


## 参照颜色有 #rrggbb 与 rgba(r,g,b,a) 两种写法
static func _color(c: String) -> Color:
	if c.begins_with("rgba("):
		var v := c.trim_prefix("rgba(").trim_suffix(")").split(",")
		return Color8(int(v[0]), int(v[1]), int(v[2]))
	return Color(c)


static func _sorted(a: Array) -> Array:
	a.sort_custom(func(x, y): return [x[2], x[1], str(x[0])] < [y[2], y[1], str(y[0])])
	return a


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		for k in w.size():
			var bad: bool = str(g[k]) != w[k] if w[k] is String else absf(float(g[k]) - float(w[k])) > POS_TOL
			if bad:
				return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


## 清空临时目录里的仓库文件，内存也重读
func _fresh_store() -> void:
	XSave.dir_override = DIR
	XStarWarehouse.path_override = ""
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in ["star_warehouse.json", "star_warehouse.json.tmp"]:
		DirAccess.remove_absolute(DIR.path_join(f))
	XStarWarehouse._loaded_path = "<unloaded>"
	XStarWarehouse.o_save_now = true
	XStarWarehouse.o_alien_reset = true
	XStarWarehouse.o_block_bound = true


func _pet(enemy: int) -> Dictionary:
	return {"enemy": enemy, "elite": false, "letter": "", "push": [0, 0, 0, 0, 0, 0, 0, 0], "skills": [], "lv_skills": {}, "exp": 0, "ls": 0, "ls_max": 1}


func _gain(s: XState, kind: String, base: int) -> Dictionary:
	s.gain_gear(kind, base, 1)
	return s.gear.back()


## 画面参照的摆法：背包武器本体 2、52、3，防具本体 2；宠物 1／2／3，第 2 只出战
func _setup_ui() -> XState:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	XState.current = s
	for b in [2, 52, 3]:
		_gain(s, "weapon", b)
	_gain(s, "armor", 2)
	s.pets = {"list": [_pet(1), _pet(2), _pet(3)], "war": 1, "team_a": 0}
	return s


func _compare(ref: Dictionary, name: String, page: XStarWarehouseScene) -> void:
	var w: Dictionary = ref.shots[name].windows
	var st: Dictionary = ref.shots[name].state
	var bad := []
	var parts := {"Window_StarItemCategory": page.cat_win, "Window_StarItemList": page.list_win}
	for k in parts:
		var d := diff(record(parts[k]), want_form(w[k].texts))
		if d != "":
			bad.append("%s %s" % [k, d])
		var c: Control = parts[k]
		if [c.position.x, c.position.y, c.size.x, c.size.y] != w[k].rect.map(func(v): return float(v)):
			bad.append("%s 矩形 %s" % [k, [c.position.x, c.position.y, c.size.x, c.size.y]])
	if page.category != int(st.category.index) or (page.mode == "category") != bool(st.category.active):
		bad.append("分类 %d %s" % [page.category, page.mode])
	if page.index != int(st.list.index) or (page.mode == "list") != bool(st.list.active):
		bad.append("列表光标 %d %s" % [page.index, page.mode])
	if page.help_card.visible != bool(st.helpCard):
		bad.append("说明卡 %s" % page.help_card.visible)
	var s := XState.current
	var got := [XStarWarehouse.gear().map(func(e): return int(e.base)), XStarWarehouse.pets().map(func(p): return int(p.enemy)),
		XPets.list(s).map(func(p): return [int(p.enemy), XPets.pet_name(s, p)])]
	var want := [st.GetEq.map(func(e): return int(e[1])), st.GetPet.map(func(p): return int(p[0])), st.pets.map(func(p): return [int(p[0]), str(p[1])])]
	if got != want:
		bad.append("数据 %s 应为 %s" % [JSON.stringify(got), JSON.stringify(want)])
	check(name, bad.is_empty(), bad)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var probe = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("fixture_loaded", ref is Dictionary and ref.get("shots", {}).has("sw_0_save_open") and probe is Dictionary, [FIXTURE, ORACLE]):
		get_tree().quit.call_deferred(1)
		return
	await _flow(ref)
	_probe(probe, false)
	_probe(probe, true)
	_renumber(int(probe.swallowBase))
	_store()
	_ph_donor(int(probe.swallowBase))
	await _interpreter()
	_fresh_store()
	XSave.dir_override = ""
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _flow(ref: Dictionary) -> void:
	_fresh_store()
	var s := _setup_ui()
	var page := XStarWarehouseScene.new()
	add_child(page)
	await frames()
	await shot("sw_0_save_open")
	_compare(ref, "sw_0_save_open", page)
	XSound.system_log.clear()
	page.ok()
	await shot("sw_1_save_equip")
	_compare(ref, "sw_1_save_equip", page)
	page.ok()
	await shot("sw_2_save_one")
	_compare(ref, "sw_2_save_one", page)
	check("sounds_ok_only", XSound.system_log == [1, 1], XSound.system_log)
	page.cancel()
	page._move(1, 0, true)
	page.ok()
	await shot("sw_3_save_pet")
	_compare(ref, "sw_3_save_pet", page)
	page.ok()
	await shot("sw_3b_save_pet_one")
	_compare(ref, "sw_3b_save_pet_one", page)
	# 出战宠物（现在在第 1 格）确定：只有确定音，什么都不变
	XSound.system_log.clear()
	var before := XPets.list(s).size()
	page.ok()
	check("war_pet_ok_only", XSound.system_log == [1] and XPets.list(s).size() == before and XStarWarehouse.pets().size() == 1, XSound.system_log)
	page.cancel()
	page.cancel()
	check("closed", page.mode == "category")
	page.queue_free()
	var load := XStarWarehouseScene.new()
	load.save_mode = false
	add_child(load)
	await frames()
	await shot("sw_4_load_open")
	_compare(ref, "sw_4_load_open", load)
	load.ok()
	await shot("sw_5_load_equip")
	_compare(ref, "sw_5_load_equip", load)
	load.cancel()
	load._move(1, 0, true)
	load.ok()
	await shot("sw_6_load_pet")
	_compare(ref, "sw_6_load_pet", load)
	XSound.system_log.clear()
	load.ok()
	load.ok()
	await shot("sw_7_load_empty")
	_compare(ref, "sw_7_load_empty", load)
	check("empty_ok_only", XSound.system_log == [1, 1], XSound.system_log)
	load.queue_free()
	await frames()


## 原版探针的摆法：背包普通武器（2）、PushDct（52）、防具（2）、锁定（3）、供体（2）、吞器异化（swallowBase），宠物 1／2／3 第 2 只出战
func _setup_probe(swallow_base: int) -> Dictionary:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	XState.current = s
	var roles := {}
	roles.plain = _gain(s, "weapon", 2)
	roles.push = _gain(s, "weapon", 52)
	roles.armor = _gain(s, "armor", 2)
	roles.locked = _gain(s, "weapon", 3)
	roles.locked.name = str(roles.locked.name) + "[锁定]"
	roles.donor = _gain(s, "weapon", 2)
	var r := XAlienation.create(s, "w", swallow_base, "boss", "swallow")
	roles.alien = r.get("ok", {})
	s.gear.append(roles.alien)
	XAlienation.mark(roles.alien).config = {"actorId": 1, "donorId": str(roles.donor.instanceId)}
	s.pets = {"list": [_pet(1), _pet(2), _pet(3)], "war": 1, "team_a": 0}
	return roles


func _role(roles: Dictionary, e: Dictionary) -> String:
	for k in roles:
		if is_same(roles[k], e):
			return k
	return "?"


## 原版一步的读数换成可比的形：列表与仓库按角色名，宠物按敌人 ID
func _want(step: Dictionary) -> Dictionary:
	var gear_list := func(a): return a.map(func(e): return str(e.role))
	var pet_list := func(a): return a.map(func(p): return int(p.enemy))
	return {"list": gear_list.call(step.list) if str(step.category) == "equip" else pet_list.call(step.list),
		"weapons": gear_list.call(step.bag.weapons), "armors": gear_list.call(step.bag.armors), "pets": pet_list.call(step.pets),
		"war": int(step.war.enemy) if step.war is Dictionary else -1, "GetEq": gear_list.call(step.GetEq), "GetPet": pet_list.call(step.GetPet),
		"index": int(step.index), "toasts": step.toasts, "sounds": step.sounds.map(func(x): return {"playOk": 1, "playCancel": 2, "playBuzzer": 3, "playEquip": 4}.get(x, -1))}


func _got(page: XStarWarehouseScene, roles: Dictionary, toasts: Array) -> Dictionary:
	var s := XState.current
	# other：新局自带的异化装备（查 uid 不撞用），原版参照里没有
	var names := func(a): return a.map(func(e): return _role(roles, e)).filter(func(r): return r != "other")
	return {"list": names.call(page.data) if page._symbol() == "equip" else page.data.map(func(p): return int(p.enemy)),
		"weapons": names.call(XItemScene.bag_gear("weapon")), "armors": names.call(XItemScene.bag_gear("armor")),
		"pets": XPets.list(s).map(func(p): return int(p.enemy)), "war": int(XPets.war_pet(s).get("enemy", -1)),
		"GetEq": names.call(XStarWarehouse.gear()), "GetPet": XStarWarehouse.pets().map(func(p): return int(p.enemy)),
		"index": page.index, "toasts": toasts, "sounds": XSound.system_log.duplicate()}


## 存取逐步对原版。optimized＝false：三个开关照原版，结果应与参照完全相同；true：默认开，只有供体一步与异化配置不同
func _probe(probe: Dictionary, optimized: bool) -> void:
	_fresh_store()
	XStarWarehouse.o_block_bound = optimized
	XStarWarehouse.o_alien_reset = optimized
	XStarWarehouse.o_save_now = optimized
	var roles := _setup_probe(int(probe.swallowBase))
	var s0 := XState.current
	var tag := "probe_%s_" % ("opt" if optimized else "orig")
	var page := XStarWarehouseScene.new()
	add_child(page)
	var cur := {"page": page}  # lambda 按值捕获局部变量，换画面时经字典取
	var steps := {}
	for st in probe.steps:
		steps[str(st.label)] = st
	var step := func(label: String, act: Callable) -> void:
		XSound.system_log.clear()
		var shown := XToast.shown.size()
		act.call()
		var got := _got(cur.page, roles, XToast.shown.slice(shown))
		var want := _want(steps[label])
		if optimized:
			# O-127：供体挡下（提示「不可存放」、留在背包），其余与原版相同：两边都去掉供体再比
			for k in ["list", "weapons", "GetEq"]:
				if got[k] is Array and want[k] is Array:
					got[k] = got[k].filter(func(r): return str(r) != "donor")
					want[k] = want[k].filter(func(r): return str(r) != "donor")
			got.erase("index")  # 供体留在列表里，之后的光标序号差一格
			want.erase("index")
			if label == "deposit_donor":
				want.toasts = ["不可存放"]
		check(tag + label, got == want, {"got": got, "want": want})
	var at := func(role: String) -> int: return cur.page.data.find_custom(func(e): return _role(roles, e) == role)
	check(tag + "open", page.mode == "category" and page.category == 0 and page.data.map(func(e): return _role(roles, e)) == steps.save_open.list.map(func(e): return str(e.role)))
	step.call("save_equip_list", func(): page.ok())
	for k in ["plain", "push", "locked", "donor", "alien"]:
		step.call("deposit_" + k, func():
			page._select(at.call(k))
			page.ok())
	var alien: Dictionary = roles.alien
	check(tag + "alien_config", XAlienation.mark(alien).config == ({} if optimized else {"actorId": 1, "donorId": str(roles.donor.instanceId)}), XAlienation.mark(alien).config)
	check(tag + "donor_kept", s0.gear.has(roles.donor) == optimized)
	check(tag + "written_now", FileAccess.file_exists(XStarWarehouse.path()) == optimized)
	page.cancel()
	page._move(1, 0, true)
	step.call("save_pet_list", func(): page.ok())
	step.call("deposit_war_pet", func():
		page._select(1)
		page.ok())
	step.call("deposit_pet0", func():
		page._select(0)
		page.ok())
	step.call("deposit_pet_rest", func():
		page._select(1)
		page.ok())
	page.queue_free()
	# 换局：仓库留在内存（与文件）里；新局背包先放一件本体 2 武器
	var uid_before := str(XAlienation.mark(alien).uid)
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	XState.current = s
	roles.fresh = _gain(s, "weapon", 2)
	var other: Dictionary = XAlienation.create(s, "w", int(probe.swallowBase), "boss", "swallow").get("ok", {})
	s.gear.append(other)
	roles.other = other
	var load := XStarWarehouseScene.new()
	load.save_mode = false
	add_child(load)
	cur.page = load
	step.call("load_equip_list", func(): load.ok())
	step.call("withdraw_plain", func():
		load._select(at.call("plain"))
		load.ok())
	step.call("withdraw_alien", func():
		load._select(at.call("alien"))
		load.ok())
	var ids := s.gear.map(func(e): return str(e.instanceId))
	check(tag + "renumbered_unique", ids.size() == ids.duplicate().filter(func(x): return ids.count(x) == 1).size(), ids)
	var uid_after := str(XAlienation.mark(alien).uid)
	check(tag + "alien_uid", (uid_after != uid_before and uid_after != str(XAlienation.mark(other).uid)) if optimized else uid_after == uid_before, [uid_before, uid_after, XAlienation.mark(other).uid])
	s.gear.erase(other)
	load.cancel()
	load._move(1, 0, true)
	step.call("load_pet_list", func(): load.ok())
	step.call("withdraw_pet0", func():
		load._select(0)
		load.ok())
	step.call("withdraw_pet_last", func():
		load._select(0)
		load.ok())
	step.call("withdraw_empty", func():
		load._select(0)
		load.ok())
	load.queue_free()
	if not optimized:
		check(tag + "flush_on_config_write", not FileAccess.file_exists(XStarWarehouse.path()) and XConfig._write() and FileAccess.file_exists(XStarWarehouse.path()))


## Q1：两档各有 xg:1，取出后不撞号；待选重抽的异化装备挡下（O-127）
func _renumber(swallow_base: int) -> void:
	_fresh_store()
	var a := XState.new_game_blank()
	XState.current = a
	var w := _gain(a, "weapon", 2)
	check("q1_same_id_start", str(w.instanceId) == "xg:1" or str(w.instanceId).begins_with("xg:"), w.instanceId)
	var first_id := str(w.instanceId)
	check("q1_deposit", XStarWarehouse.deposit_gear(a, w) == "")
	var b := XState.new_game_blank()
	XState.current = b
	var mine := _gain(b, "weapon", 2)
	check("q1_collision_setup", str(mine.instanceId) == first_id, [mine.instanceId, first_id])
	XStarWarehouse.withdraw_gear(b, w)
	check("q1_renumbered", str(w.instanceId) != str(mine.instanceId) and b.gear.size() == 2, [w.instanceId, mine.instanceId])
	check("q1_query_both", XItemScene.bag_gear("weapon").size() == 2)
	# 待选重抽中的异化装备
	var al: Dictionary = XAlienation.create(b, "w", swallow_base, "boss").get("ok", {})
	if not al.is_empty():
		b.gear.append(al)
		XAlienation.ledger(b).pending = {"uid": XAlienation.mark(al).uid, "kind": "w", "id": str(al.instanceId), "old": "", "next": ""}
		check("pending_blocked", XStarWarehouse.deposit_gear(b, al) == "不可存放" and b.gear.has(al))
		XStarWarehouse.o_block_bound = false
		check("pending_orig_allowed", XStarWarehouse.deposit_gear(b, al) == "" and not b.gear.has(al))
		XStarWarehouse.o_block_bound = true
	else:
		check("pending_setup", false, swallow_base)


## 写盘、重读、损坏、路径跟随存档目录
func _store() -> void:
	_fresh_store()
	var s := XState.new_game_blank()
	XState.current = s
	s.pets = {"list": [_pet(5), _pet(6)], "war": 1, "team_a": 0}
	var w := _gain(s, "armor", 2)
	XStarWarehouse.deposit_gear(s, w)
	XStarWarehouse.deposit_pet(s, 0)
	check("war_index_shift", XPets.war_index(s) == 0 and int(XPets.war_pet(s).enemy) == 6, s.pets)
	XStarWarehouse._loaded_path = "<unloaded>"
	check("reload_from_file", XStarWarehouse.gear().size() == 1 and int(XStarWarehouse.gear()[0].base) == 2 and XStarWarehouse.pets().map(func(p): return int(p.enemy)) == [5])
	var t := XState.new_game_blank()
	XState.current = t
	check("withdraw_after_reload", XStarWarehouse.withdraw_gear(t, XStarWarehouse.gear()[0]) and t.gear.size() == 1 and XStarWarehouse.withdraw_pet(t, XStarWarehouse.pets()[0]) and XPets.list(t).size() == 1)
	XStarWarehouse._loaded_path = "<unloaded>"
	check("written_after_withdraw", XStarWarehouse.gear().is_empty() and XStarWarehouse.pets().is_empty())
	var f := FileAccess.open(XStarWarehouse.path(), FileAccess.WRITE)
	f.store_string("{坏")
	f.close()
	XStarWarehouse._loaded_path = "<unloaded>"
	check("corrupt_empty", XStarWarehouse.gear().is_empty() and XStarWarehouse.pets().is_empty())
	check("path_follows_save_dir", XStarWarehouse.path() == DIR.path_join("star_warehouse.json"), XStarWarehouse.path())
	# 出战宠物不收
	check("war_pet_refused", not XStarWarehouse.deposit_pet(t, XPets.war_index(t)) if XPets.war_index(t) >= 0 else true)


## C1：PH 仓库存放吞器供体
func _ph_donor(swallow_base: int) -> void:
	for orig in [false, true]:
		var s := XState.new_game_blank()
		for id in [1, 8, 9, 10]:
			s.add_actor(id)
		XState.current = s
		var donor := _gain(s, "weapon", 2)
		var al: Dictionary = XAlienation.create(s, "w", swallow_base, "boss", "swallow").get("ok", {})
		if al.is_empty():
			check("ph_donor_setup", false)
			return
		s.gear.append(al)
		XAlienation.mark(al).config = {"actorId": 1, "donorId": str(donor.instanceId)}
		XWarehouse.create(s, "<通用仓库>")
		XWarehouse.o_reserved_no_dup = not orig
		var ok := XWarehouse.deposit(s, "weapon", donor)
		var in_bag := s.gear.has(donor)
		var stored: int = XWarehouse.current(s).items.weapon.size()
		check("ph_donor_" + ("orig_dup" if orig else "moved"), ok and stored == 1 and in_bag == orig, [ok, stored, in_bag])
	XWarehouse.o_reserved_no_dup = true


## Map041 EV1「存放」「取出」两支的脚本（插件指令那一行照原版无操作）
func _interpreter() -> void:
	var host := FakeHost.new()
	add_child(host)
	var list := [{"code": 356, "indent": 0, "parameters": ["SceneManager.push(Scene_StarSaveWarehouse) "]},
		{"code": 355, "indent": 0, "parameters": ["SceneManager.push(Scene_StarSaveWarehouse) "]},
		{"code": 355, "indent": 0, "parameters": ["SceneManager.push(Scene_StarWarehouse)"]},
		{"code": 0, "indent": 0, "parameters": []}]
	XState.current = XState.new_game_blank()
	var interp := MVInterpreter.new(host, 0, 0, list)
	await interp.run()
	check("interpreter_opens", host.opened == [true, false], host.opened)
	host.queue_free()
