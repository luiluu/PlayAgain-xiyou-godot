extends Node
## 大厅人族首领（Map004 EV054）与特殊物品购买（EV063）：用 mv_oracle/lobby_shop_probe.cjs 的冻结 v0.28 参照
## （generated/oracle/lobby_shops.json）逐条选项路径对照——四档（变量 20 ≥1／13／21／28）与 EV063 两页，
## 预设变量 1476、开关 2466／2467，比较选项文字、所选项、每次打开商店的商品（种类、ID、价格方式、价格）与待用限购组。
## 另核：两个事件放在大厅地图上（keepEvents），商品在数据库里都有记录。

const ORACLE := "res://modes/xiyou/generated/oracle/lobby_shops.json"
const PARTY := [1, 8, 10, 9]
var results := []


## 记录用宿主（同 xiyou_event_compare），选项按用例给定的下标回答，用完取最后一项
class LobbyHost:
	extends "res://tests/xiyou_event_compare.gd".EventHost
	var picks: Array = []

	func show_message(msg: Dictionary) -> int:
		if not msg.has("choices"):
			return 0
		var n: int = msg.choices.size()
		var pick: int = mini(int(picks.pop_front()), n - 1) if not picks.is_empty() else n - 1
		trace.append({"t": "choice", "choices": msg.choices, "pick": pick})
		return pick

	func open_shop(goods: Array, purchase_only: bool) -> void:
		var s := XState.current
		trace.append({"t": "shop", "goods": goods.map(func(g): return [int(g[0]), int(g[1]), int(g[2]), int(g[3])]),
			"inventory": s.shop_pending, "purchaseOnly": purchase_only})
		s.shop_pending = ""


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_lobby_shops"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	if not check("oracle_loaded", oracle is Dictionary and oracle.has("cases")):
		_finish()
		return
	var keep: Array = XMapScene.slice().get("keepEvents", {}).get("4", []).map(func(v): return int(v))
	check("kept_on_lobby", keep.has(54) and keep.has(63) and keep.has(65), keep)
	var host := LobbyHost.new()
	add_child(host)
	var states := {}
	for st in oracle.setup.states:
		states[str(st.id)] = st
	var shops := 0
	var goods_seen := {}
	for c in oracle.cases:
		var got := await _run_case(c, states[str(c.state)], host)
		check("case_" + str(c.id), JSON.stringify(_norm(got)) == JSON.stringify(_norm(c.trace)), {"want": c.trace, "got": got})
		for e in c.trace:
			if e.t == "shop":
				shops += 1
				for g in e.goods:
					goods_seen["%d:%d" % [int(g[0]), int(g[1])]] = g
	check("cases_ran", oracle.cases.size() >= 70 and shops >= 60, [oracle.cases.size(), shops])
	var missing := []
	for k in goods_seen:
		var g = goods_seen[k]
		if XDB.rec(XShopStock.TABLES[int(g[0])], int(g[1])).is_empty():
			missing.append(k)
	check("goods_in_db", missing.is_empty(), missing)
	_finish()


## JSON 读入的数都是浮点：整数值一律转 int 再比
static func _norm(v):
	if v is float and v == floorf(v):
		return int(v)
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _norm(v[k])
		return d
	return v


func _run_case(c: Dictionary, st: Dictionary, host: LobbyHost) -> Array:
	var s := XState.new_game_blank()
	s.difficulty = 3
	for id in PARTY:
		s.add_actor(id)
	s.map_id = 4
	XState.current = s
	for k in st.variables:
		s.set_variable(int(k), int(st.variables[k]))
	for sw in st.switches:
		s.set_switch(int(sw), true)
	host.trace = []
	host.picks = c.picks.duplicate()
	var list: Array = []
	for e in XDB.map(4).get("events", []):
		if e is Dictionary and int(e.id) == int(c.event):
			list = e.pages[int(c.page)].list.duplicate(true)
	MVInterpreter.fixed_random = 0.5
	var interp := MVInterpreter.new(host, 4, int(c.event), list)
	await interp.run()
	MVInterpreter.fixed_random = -1.0
	return host.trace


func _finish() -> void:
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
