extends Node
## 【cc·白龙·未经审查】星爆气流斩三本被动书（XStarburstBooks）：与 mv_oracle/starburst_books_probe.cjs 的新源 v0.62.12 参照
## （tests/fixtures/starburst_books_oracle.json）逐例比。
## - rate.*：六条路线的不朽存在概率；
## - victory.*：真气本场守层者 8／13／18（试炼、缩放、同层两场、没有真气战斗）与 152 号地图不朽存在（随机数 0.5／0.01／0.02／0.04）：
##   三本书数量、送过的层、提示文字（XToast.shown）；重制直接调 grant 里的挂点 on_victory（参照走真实 endBattle(0)）；
## - mapstart.*：变量 20 为 1／9／19、旧档已送过 8 层时的补发。
const FIXTURE := "res://tests/fixtures/starburst_books_oracle.json"
const BOOKS := [1121, 1141, 1161]
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


class FixedStream extends XRandomStream:
	var value := 0.5

	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else int(value * 4294967296.0)


func _fresh(switches: Array) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	for id in switches:
		s.set_switch(int(id), true)
	XToast.shown.clear()
	return s


func _logic(s: XState, random: float) -> XBattleLogic:
	var rand := XBattleRandom.create("0000000000001121")
	var stream := FixedStream.new()
	stream.value = random
	rand.rule = stream
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	return logic


func _view(s: XState) -> Dictionary:
	var given := {}
	var d = s.flags.get(XStarburstBooks.FLAG, {})
	for k in d:
		given[str(k)] = int(d[k])
	return {"counts": BOOKS.map(func(id): return s.item_count(id)), "given": given, "toasts": XToast.shown.duplicate()}


func _want(o: Dictionary) -> Dictionary:
	var given := {}
	for k in o.given:
		given[str(k)] = int(o.given[k])
	return {"counts": o.counts.map(func(v): return int(v)), "given": given, "toasts": o.toasts.map(func(v): return str(v))}


func _compare(id: String, got: Dictionary, want: Dictionary) -> void:
	for k in want:
		check(id + "." + k, got[k] == want[k], [got[k], want[k]])


func _victory(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var s := _fresh(setup.get("switches", []))
	if setup.has("map"):
		s.map_id = int(setup.map)
	var immortal := str(c.id).begins_with("victory.immortal")
	var battles: Array = setup.get("battles", [null])
	for b in battles:
		var logic := _logic(s, float(setup.get("random", 0.5)))
		XZhenqi.battle = {}
		if b is Dictionary:
			XZhenqi.battle = {"trial": b.get("trial", {}), "scaled": {"ref": {"floor": 8}} if bool(b.get("scaled", false)) else {}, "guardianFloor": int(b.get("guardianFloor", 0))}
		XStarburstBooks.IMMORTAL_CLEAR_TEST = 1 if immortal else 0
		XStarburstBooks.on_victory(logic)
		XStarburstBooks.IMMORTAL_CLEAR_TEST = -1
		XZhenqi.battle = {}
	_compare(c.id, _view(s), _want(c.observed))


func _mapstart(c: Dictionary) -> void:
	var s := _fresh([])
	s.set_variable(20, float(c.setup.v20))
	var had := {}
	for k in c.setup.given:
		had[str(k)] = int(c.setup.given[k])
	s.flags[XStarburstBooks.FLAG] = had
	check(c.id + ".passed", XZhenqi.progress_floor(s) == int(c.observed.passed), [XZhenqi.progress_floor(s), c.observed.passed])
	XStarburstBooks.map_start(s)
	_compare(c.id, _view(s), _want(c.observed))


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				var gifts := {}
				for k in c.observed.gifts:
					gifts[int(k)] = int(c.observed.gifts[k])
				check("module", gifts == XStarburstBooks.GIFTS and int(c.observed.immortalMap) == XStarburstBooks.IMMORTAL_MAP \
					and int(c.observed.immortalBook) == XStarburstBooks.IMMORTAL_BOOK)
			"rate":
				var s := _fresh(c.setup.switches)
				check(c.id + ".coef", int(XZhenqi.route(s).coef) == int(c.observed.coef), [XZhenqi.route(s).coef, c.observed.coef])
				check(c.id + ".rate", absf(XStarburstBooks.immortal_rate(s) - float(c.observed.rate)) < 1e-12, [XStarburstBooks.immortal_rate(s), c.observed.rate])
			"victory":
				_victory(c)
			"mapstart":
				_mapstart(c)
	check("covers_all", seen.keys().size() == 4, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_starburst_books", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
