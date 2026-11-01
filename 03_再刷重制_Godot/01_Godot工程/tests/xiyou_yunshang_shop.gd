extends Node
## 【cc·白龙_11·未经审查】云裳天衣铺一期（XYunshangShop：首页与配置天衣神纹）：照参照 p7.shop（yunshang_probe 拿原版 Scene_Yunshang 逐页量的
## Window_YunChoices 说明行与各行），用按键走同一串操作——首页、选队员、空袖藏星选借用技能（中途取消不改）、九曲回针选针眼、
## 七曜流霞选元素、寸光留仙无需配置、选队员时取消、返回；每页比说明行、各行文字与能不能选，选完比设置。
## 一期没接的制作、领取、角色进阶照计划灰显（原版制作、进阶这里能选），只比文字。
## 再存档→清掉内存里的设置→读档：设置按天衣带回来（JSON 读回是浮点），读档后空袖藏星的借用技能照样出现在云裳的技能里。
const FIXTURE := "res://tests/fixtures/yunshang_oracle.json"
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)
	await frames(2)


func pick(i: int) -> void:
	for k in i:
		await press("ui_down")
	await press("ui_accept")
	await frames(2)


func page(shop: XYunshangShop):
	var w := shop.win
	if w == null or not is_instance_valid(w) or w.is_queued_for_deletion():
		return null
	return {"info": w.info.map(func(t): return str(t)), "rows": w.entries.map(func(e): return [str(e.text), bool(e.get("enabled", true))])}


## 比一页；首页前三行（制作、领取、进阶）一期灰显，只比文字
func same_page(tag: String, got, want) -> void:
	if want == null or got == null:
		check(tag + ".page", got == null and want == null, [got, want])
		return
	var wr: Array = (want.rows as Array).map(func(r): return [str(r[0]), bool(r[1])])
	if str(want.info[0] if not (want.info as Array).is_empty() else "").begins_with("天衣铺"):
		for i in 3:
			wr[i][1] = false
	check(tag + ".info", got.info == (want.info as Array).map(func(t): return str(t)), [got.info, want.info])
	check(tag + ".rows", got.rows == wr, [got.rows, wr])


func same_setting(tag: String, got: Dictionary, want: Dictionary) -> void:
	var g := {"borrow": (got.borrow as Array).map(func(b): return [int(b.owner), int(b.skill)]), "eye": int(got.eye),
		"elements": (got.elements as Array).map(func(e): return int(e)), "element": int(got.element)}
	var w := {"borrow": (want.borrow as Array).map(func(b): return [int(b.owner), int(b.skill)]), "eye": int(want.eye),
		"elements": (want.elements as Array).map(func(e): return int(e)), "element": int(want.element)}
	check(tag + ".setting", g == w, [g, w])


func wear(s: XState, a: XActor, k: int) -> void:
	s.gain_gear("armor", XYunshang.ROBE_FIRST + k, 1)
	XEquipment.change(s, a, a.equip_slots().find(4), s.gear[s.gear.size() - 1])


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_yunshang_shop"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var want := {}
	for c in ref.cases:
		if str(c.id) == "p7.shop":
			for st in c.observed.steps:
				want[str(st.tag)] = st
	check("oracle", want.size() == 15, want.keys())
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10, XYunshang.ACTOR]:
		s.add_actor(id)
	s.actor_advance[XYunshang.ACTOR] = 0
	var a := s.actor(XYunshang.ACTOR)
	a.change_level_mv(45)
	for id in [1, 8, 9]:
		s.actor(id).change_level_mv(55)
	var one := s.actor(1)
	var eight := s.actor(8)
	var nine := s.actor(9)
	wear(s, a, 6)
	wear(s, one, 7)
	wear(s, eight, 14)
	wear(s, nine, 9)
	var shop := XYunshangShop.new()
	add_child(shop)
	await frames(3)
	var at := func(tag: String) -> void: same_page(tag, page(shop), want[tag].page)
	at.call("home")
	await pick(3)
	at.call("actors")
	await pick(3)
	at.call("borrow0")
	await pick(0)
	at.call("borrow1")
	await press("ui_cancel")
	at.call("borrowCancel")
	same_setting("borrowCancel", XYunshang.setting(a), want.borrowCancel.setting)
	await pick(3)
	await pick(3)
	await pick(0)
	await pick(0)
	at.call("borrow2")
	await pick(1)
	at.call("borrowed")
	same_setting("borrowed", XYunshang.setting(a), want.borrowed.setting)
	await pick(3)
	await pick(0)
	at.call("eye")
	await pick(1)
	at.call("eyed")
	same_setting("eyed", XYunshang.setting(one), want.eyed.setting)
	await pick(3)
	await pick(1)
	at.call("element0")
	await pick(2)
	at.call("element1")
	await pick(0)
	await pick(0)
	at.call("elemented")
	same_setting("elemented", XYunshang.setting(eight), want.elemented.setting)
	XToast.shown.clear()
	await pick(3)
	await pick(2)
	at.call("plain")
	check("plain.toast", XToast.shown.has("这件天衣无需战前配置"), XToast.shown)
	same_setting("plain", XYunshang.setting(nine), want.plain.setting)
	await pick(3)
	await press("ui_cancel")
	at.call("actorsCancel")
	var closed := [false]
	shop.closed.connect(func(): closed[0] = true)
	await pick(4)
	check("back.closed", closed[0])
	shop.queue_free()
	await save_load(s)
	finish()


## 存档→清掉设置→读档：三件天衣的设置都回来；空袖藏星没醒取第一个借用技能（1 号的万剑诀），读档后照样在云裳的技能里
func save_load(s: XState) -> void:
	var before = JSON.parse_string(JSON.stringify(s.flags.get(XYunshang.SETTINGS_FLAG, {})))
	check("save", XSave.save(1))
	s.flags.erase(XYunshang.SETTINGS_FLAG)
	check("load", XSave.load_slot(1))
	var t := XState.current
	check("load.settings", JSON.stringify(t.flags.get(XYunshang.SETTINGS_FLAG, {})) == JSON.stringify(before), [t.flags.get(XYunshang.SETTINGS_FLAG), before])
	var a := t.actor(XYunshang.ACTOR)
	check("load.borrow_type", int(XYunshang.setting(a).borrow[0].skill) == 160 and XYunshang.key(a) == 6, XYunshang.setting(a))
	check("load.borrowed_skill", a.skills().any(func(sk): return int(sk.id) == 160), a.skills().map(func(sk): return int(sk.id)))
	check("load.eye", int(XYunshang.setting(t.actor(1)).eye) == 311, XYunshang.setting(t.actor(1)))


func finish() -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_yunshang_shop", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
