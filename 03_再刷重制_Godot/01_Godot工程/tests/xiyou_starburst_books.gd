extends Node
## 【cc·白龙·未经审查】星爆气流斩三本被动书（XStarburstBooks）：与 mv_oracle/starburst_books_probe.cjs 的新源 v0.62.12 参照
## （tests/fixtures/starburst_books_oracle.json）逐例比。
## - rate.*：六条路线的不朽存在概率；
## - victory.*：真气本场守层者 8／13／18（试炼、缩放、同层两场、没有真气战斗）与 152 号地图不朽存在（随机数 0.5／0.01／0.02／0.04）：
##   三本书数量、送过的层、提示文字（XToast.shown）；重制直接调 grant 里的挂点 on_victory（参照走真实 endBattle(0)）；
## - mapstart.*：变量 20 为 1／9／19、旧档已送过 8 层时的补发。
## - T469：18 层替身守层者胜利、独立回退、旧档补发、试炼／缩放与天启篇隔离。
const FIXTURE := "res://tests/fixtures/starburst_books_oracle.json"
const BOOKS := [1121, 1141, 1161]
const GUARDIAN_18 := 174
const STAND_IN_17 := 752
const STAND_IN_18 := 753
const UNITED_STAND_IN_18 := 803
const GIFT_18 := 1161
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


func _logic(s: XState, random: float, troop: int = 3) -> XBattleLogic:
	var rand := XBattleRandom.create("0000000000001121")
	var stream := FixedStream.new()
	stream.value = random
	rand.rule = stream
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(troop, s, rand)
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


func _stand_in_victory() -> void:
	var genuine := _fresh([])
	XStarburstBooks.on_victory(_logic(genuine, 0.5, GUARDIAN_18))
	check("stand_in.genuine_18", genuine.item_count(GIFT_18) == 1)

	for sect in XZhenqi.STAND_IN_SECT_SWITCHES:
		var troop := UNITED_STAND_IN_18 if sect == 2307 else STAND_IN_18
		var s := _fresh([sect])
		XStarburstBooks.on_victory(_logic(s, 0.5, troop))
		check("stand_in.victory.%d" % sect, XZhenqi.battle.guardianFloor == 0 and XZhenqi.battle.standInFloor == 18 \
				and s.item_count(GIFT_18) == 1 and s.flags.get(XStarburstBooks.FLAG) == {"18": 1})
		XStarburstBooks.on_victory(_logic(s, 0.5, troop))
		XStarburstBooks.on_victory(_logic(s, 0.5, GUARDIAN_18))
		check("stand_in.once.%d" % sect, s.item_count(GIFT_18) == 1 and XToast.shown.size() == 1)

	var other_floor := _fresh([2302])
	XStarburstBooks.on_victory(_logic(other_floor, 0.5, STAND_IN_17))
	check("stand_in.other_floor", not other_floor.flags.has(XStarburstBooks.FLAG))


func _stand_in_backfill() -> void:
	var old := _fresh([2307])
	old.flags[XStarburstBooks.FLAG] = {"8": 1}
	old.set_variable(20, 18)
	XStarburstBooks.map_start(old)
	check("stand_in.backfill_below_18", old.item_count(GIFT_18) == 0)
	old.set_variable(20, 19)
	var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())))
	XState.current = loaded
	check("stand_in.old_save_without_firsts", XZhenqi.data(loaded.actor(8)).firsts.is_empty())
	XStarburstBooks.map_start(loaded)
	check("stand_in.backfill_18", loaded.item_count(GIFT_18) == 1 and _view(loaded).given == {"8": 1, "18": 1})
	var reloaded := XState.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	XState.current = reloaded
	XStarburstBooks.map_start(reloaded)
	XStarburstBooks.on_victory(_logic(reloaded, 0.5, UNITED_STAND_IN_18))
	check("stand_in.backfill_once_after_reload", reloaded.item_count(GIFT_18) == 1 and XToast.shown.size() == 1)


func _stand_in_rollback() -> void:
	XStarburstBooks.STAND_IN_GIFTS = false
	var s := _fresh([2302])
	XStarburstBooks.on_victory(_logic(s, 0.5, STAND_IN_18))
	check("stand_in.gifts_off", XZhenqi.battle.standInFloor == 18 and s.item_count(GIFT_18) == 0 and not s.flags.has(XStarburstBooks.FLAG))
	XStarburstBooks.on_victory(_logic(s, 0.5, GUARDIAN_18))
	check("stand_in.gifts_off_genuine", s.item_count(GIFT_18) == 1)
	var old := _fresh([2302])
	old.set_variable(20, 19)
	XStarburstBooks.map_start(old)
	check("stand_in.gifts_off_original_backfill", old.item_count(GIFT_18) == 1)
	XStarburstBooks.STAND_IN_GIFTS = true

	var firsts := XZhenqi.STAND_IN_FIRSTS
	XZhenqi.STAND_IN_FIRSTS = false
	s = _fresh([2302])
	XStarburstBooks.on_victory(_logic(s, 0.5, STAND_IN_18))
	check("stand_in.firsts_off_gifts_on", XZhenqi.battle.standInFloor == 0 and s.item_count(GIFT_18) == 1)
	XZhenqi.STAND_IN_FIRSTS = firsts


func _stand_in_exclusions() -> void:
	for kind in ["trial", "scaled"]:
		var s := _fresh([2302])
		var logic := _logic(s, 0.5, STAND_IN_18)
		XZhenqi.battle[kind] = {"ref": {"floor": 18}}
		XStarburstBooks.on_victory(logic)
		check("stand_in.excludes_" + kind, not s.flags.has(XStarburstBooks.FLAG))

	var tianqi := _fresh([2307])
	tianqi.flags["tianqi"] = {"rules": 1}
	var fight := _logic(tianqi, 0.5, UNITED_STAND_IN_18)
	XStarburstBooks.on_victory(fight)
	check("stand_in.tianqi_victory", XZhenqi.battle.standInFloor == 0 and not tianqi.flags.has(XStarburstBooks.FLAG))
	tianqi.set_variable(20, 19)
	XStarburstBooks.map_start(tianqi)
	check("stand_in.tianqi_original_backfill", tianqi.item_count(GIFT_18) == 1)
	XZhenqi.battle = {}


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
	_stand_in_victory()
	_stand_in_backfill()
	_stand_in_rollback()
	_stand_in_exclusions()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_starburst_books", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
