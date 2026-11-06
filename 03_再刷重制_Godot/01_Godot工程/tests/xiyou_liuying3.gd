extends Node
## 【cc·悟空·未经审查】179 流萤第三期：萨姆残核掉落（XLiuying.core_rate／core_rate_for／core_map_ok／core_drops）。
## - rate.*：路线（未选／地狱／灭世／洪荒，洪荒诅咒倍率 1）× 地图（深渊 37、备注放行 93、普通 1）× 敌人（标记 584、带下限 647、无标记 1）的概率，
##   与 mv_oracle/liuying3_probe.cjs 的新源参照（tests/fixtures/liuying3_oracle.json）逐条比；
## - drops：倒下的标记敌人各掷一次（奖励流取 0.01 中、0.99 不中），活着、没标记、普通地图不掷；开关 CORE_DROP 关掉不掉。
const FIXTURE := "res://tests/fixtures/liuying3_oracle.json"
var results := []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _state(switches: Array, map_id: int) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	for id in switches:
		s.set_switch(int(id), true)
	s.map_id = map_id
	return s


func _drops(map_id: int, value: float, kill: bool) -> int:
	var s := _state([], map_id)
	var rand := XBattleRandom.create("0000000000001793")
	var fs := FixedStream.new()
	fs.value = value
	rand.reward = fs
	var logic := XBattleLogic.new()
	logic.setup(470, s, rand)
	if kill:
		for e in logic.enemies:
			e.hp = 0.0
			e.add_new_state(1)
	var tagged := logic.enemies.filter(func(e): return str(e.data().get("note", "")).contains("CodexLiuyingCoreDrop") and not e.hidden).size()
	var n := XLiuying.core_drops(logic).size()
	return n if tagged > 0 else -1


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		var o: Dictionary = c.observed
		var s := _state(c.setup.switches, 1)
		check(c.id + ".base", absf(XLiuying.core_rate(s) - float(o.base)) < 1e-12, [XLiuying.core_rate(s), o.base])
		for r in o.rows:
			s.map_id = int(r.map)
			var got := [XLiuying.core_map_ok(s), XLiuying.core_rate_for(s, str(XDB.rec("Enemies", int(r.enemy)).get("note", "")))]
			check("%s.%d.%d" % [c.id, int(r.map), int(r.enemy)], got[0] == bool(r.ok) and absf(got[1] - float(r.rate)) < 1e-12, [got, r])
	var hit := _drops(37, 0.01, true)
	check("drops.hit", hit > 0, hit)
	check("drops.miss", _drops(37, 0.99, true) == 0)
	check("drops.alive", _drops(37, 0.01, false) == 0)
	check("drops.plain_map", _drops(1, 0.01, true) == 0)
	XLiuying.CORE_DROP = false
	check("drops.switch_off", _drops(37, 0.01, true) == 0)
	XLiuying.CORE_DROP = true
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_liuying3", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
