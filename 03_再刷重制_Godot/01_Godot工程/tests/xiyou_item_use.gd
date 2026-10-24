extends Node
## 物品页「使用」：菜单可用（occasion 0／2）且效果含公共事件（44）的物品。
## 原版（冻结 v0.28，ui_reference ?item_list_ref=1 浏览器读数，八戒_58 2026-10-23）：
##   物品 4 指路灯（范围 0）不选人直接用，预约公共事件 10，不消耗（consumable 假）；
##   物品 1653 洪荒技能书随机抽奖（范围 11 使用者）选人后用，预约 1441，消耗 1；
##   物品 548 牛头人合剂（范围 7）选人，加状态并预约 367，消耗 1；物品 815 血脉·嘤嘤怪（范围 7）学会技能 2807 并预约 1510，消耗 1；
##   预约后 Scene_ItemBase.checkCommonEvent 回地图执行。
## 这里逐件扫全部这类物品（持有时「使用」可选），再按上面四件走一遍使用、预约、消耗与菜单关闭。

const ORACLE := [
	{"id": 4, "mode": "direct", "reserved": 10, "used": 0},
	{"id": 1653, "mode": "actor", "reserved": 1441, "used": 1},
	{"id": 548, "mode": "actor", "reserved": 367, "used": 1},
	{"id": 815, "mode": "actor", "reserved": 1510, "used": 1, "skill": 2807},
]

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _state() -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	return s


static func ce_items() -> Array:
	var out := []
	for x in XDB.table("Items"):
		if x is Dictionary and [0, 2].has(int(x.get("occasion", -1))) and x.get("effects", []).any(func(e): return int(e.code) == 44):
			out.append(x)
	return out


func _run() -> void:
	var s := _state()
	# 超强者伙伴号角在地狱以下「使用」灰（installBossDifficultyRuntime.meetsItemConditions，见 xiyou_super_acquire）；
	# 这里扫「持有时能不能用」要先放开超强者（挑战开关 2494），否则 45 件号角灰着
	s.set_switch(2494, true)
	var items := ce_items()
	check("ce_items_count", items.size() == 1029, items.size())
	var page := XItemScene.new()
	add_child(page)
	await frames()
	var bad := []
	for it in items:
		# 直接记持有数：旧版祝福进阶石等得到时会被换成别的物品（XState.gain_item 的改记），这里只看「持有时能不能用」
		s._gain_raw(int(it.id), 1)
		if not page._usable(it):
			bad.append(int(it.id))
	check("all_usable", bad.is_empty(), {"count": bad.size(), "first": bad.slice(0, 10)})
	page.queue_free()
	await frames()
	for o in ORACLE:
		await _use_one(o)
	await _menu_closes()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 物品页里选中这件，按「使用」（对队友的再选第 1 位确定）
func _use_one(o: Dictionary) -> void:
	var s := _state()
	var id := int(o.id)
	s.gain_item(id, 2)
	s.clear_common_event()
	var page := XItemScene.new()
	add_child(page)
	await frames()
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page._item = XDB.rec("Items", id)
	page._make_actions()
	page._mode = "action"
	page._act = 0
	check("use_enabled_%d" % id, bool(page._actions[0].enabled))
	page._ok()
	var mode := "actor" if page._mode == "actor" else "direct"
	if mode == "actor":
		page._actor = 0
		page._ok()
	var skill_ok := true
	if o.has("skill"):
		skill_ok = s.actor(1).skill_ids.has(int(o.skill))
	check("use_%d" % id, mode == str(o.mode) and s.peek_common_event() == int(o.reserved) and 2 - s.item_count(id) == int(o.used)
		and page.to_map and closed[0] and skill_ok, [mode, s.peek_common_event(), s.item_count(id), page.to_map, closed[0], skill_ok])
	page.queue_free()
	await frames()


## 从主菜单进物品页用了带公共事件的物品：菜单一起关掉，预约留给地图
func _menu_closes() -> void:
	var s := _state()
	s.gain_item(4, 1)
	s.clear_common_event()
	var menu := XMenu.new()
	add_child(menu)
	await frames()
	var closed := [false]
	menu.closed.connect(func(): closed[0] = true)
	menu._show_items()
	await frames()
	var page = menu.get_children().filter(func(n): return n is XItemScene)[0]
	page._item = XDB.rec("Items", 4)
	page._make_actions()
	page._mode = "action"
	page._act = 0
	page._ok()
	await frames()
	check("menu_closes_to_map", closed[0] and s.peek_common_event() == 10, [closed[0], s.peek_common_event()])
	menu.queue_free()
	await frames()
