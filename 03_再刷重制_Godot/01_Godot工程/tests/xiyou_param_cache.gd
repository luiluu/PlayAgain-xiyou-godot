extends Node
## krz_state_re 能力值／状态缓存的时序，逐例对照 mv_oracle/param_cache_probe.cjs（generated/oracle/param_cache.json）的 actor_cache.*：
## 角色 1 在敌群 2 的战斗里加／去带 22（xparam）、23（sparam）号特性的状态、换带 22 号特性的防具，读当场、回合事件后与下次 refresh 后的
## xparam 0～9、sparam 0～9、参数 0～7。原版战斗中角色的 param／xparam／sparam 与 states() 都缓存到下次「先标脏、后 refresh」，
## 重制角色每次现算——当场读数的差异是已知项（KNOWN，计数、打印、不算失败），其余行必须一致。只读，不改规则文件。
const ORACLE := "oracle/param_cache.json"
## 原版当场仍旧、重制已新的行：<例>/<行 tag>
const KNOWN := ["add_x/now", "remove_x/now", "add_s/now", "add_x_turnStart/now", "add_x_turnStart/onTurnStart",
	"add_x_turnEnd/now", "add_x_gainHp/now", "equip_x/now", "add_x_cold/now_cold"]
var results := []
var known_hits := []


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648

	## 参照里 Math.random 恒为 0.5：整数取法是 floor(0.5×n)＝n÷2，不是原始 uint 2^31 对 n 取模（同 xiyou_alien_affix）
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return n / 2 if n > 0 else 0

	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return lo + (hi - lo + 1) / 2


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _norm(v):
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float or v is int:
		return snappedf(float(v), 1e-6)
	return v


func _read(a: XActor, tag: String) -> Dictionary:
	return {"tag": tag, "x": range(10).map(func(i): return a.xparam(i)), "s": range(10).map(func(i): return a.sparam(i)),
		"p": range(8).map(func(i): return a.param(i))}


func _case(c: Dictionary) -> void:
	var k := str(c.id).trim_prefix("actor_cache.")
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	XState.current = s
	var a := s.actor(1)
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(2, s, rand)
	var xs := int(st.xState)
	if k == "remove_x":
		logic._state_add(a, xs)
		logic._refresh_battler(a)
	var rows := []
	if k != "add_x_cold":
		rows.append(_read(a, "warm"))
	else:
		logic._refresh_battler(a)
	match k:
		"add_x", "add_x_cold":
			logic._state_add(a, xs)
			rows.append(_read(a, "now" if k == "add_x" else "now_cold"))
		"remove_x":
			logic._state_remove(a, xs)
			rows.append(_read(a, "now"))
		"add_s":
			logic._state_add(a, int(st.sState))
			rows.append(_read(a, "now"))
		"add_x_turnStart":
			logic._state_add(a, xs)
			rows.append(_read(a, "now"))
			a.param_mark_dirty()  # 单个 Game_Battler.onTurnStart：krz 只标脏（Game_Unit 的 refresh 在外层，原版探针没调）
			rows.append(_read(a, "onTurnStart"))
		"add_x_turnEnd":
			logic._state_add(a, xs)
			rows.append(_read(a, "now"))
			logic.turn_end_battler(a, [])
			rows.append(_read(a, "onTurnEnd"))
		"add_x_gainHp":
			logic._state_add(a, xs)
			rows.append(_read(a, "now"))
			logic.sequence_gain(a, "HP", -1.0)
			rows.append(_read(a, "gainHp"))
		"equip_x":
			var arm := XGear.template("armor", int(st.armor))
			a.equips[a.equip_slots().find(int(arm.etypeId))] = arm
			a.param_mark_dirty()  # krz changeEquip 标脏（原方法内部 refresh 在前）
			rows.append(_read(a, "now"))
	logic._refresh_battler(a)
	rows.append(_read(a, "after_refresh"))
	var ref: Array = c.observed.rows
	if not check(k + ".rows", rows.size() == ref.size(), [rows.map(func(r): return r.tag), ref.map(func(r): return r.tag)]):
		return
	for i in rows.size():
		var tag := str(ref[i].tag)
		check(k + "." + tag + ".tag", rows[i].tag == tag)
		var same := true
		var diff := {}
		for key in ["x", "s", "p"]:
			if _norm(rows[i][key]) != _norm(ref[i][key]):
				same = false
				diff[key] = [rows[i][key], ref[i][key]]
		if KNOWN.has(k + "/" + tag):
			if not same:
				known_hits.append(k + "/" + tag)
				print("KNOWN ", k, "/", tag, " 重制／原版 ", JSON.stringify(diff).left(400))
			continue
		check(k + "." + tag, same, diff)


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		get_tree().quit.call_deferred(1)
		return
	var n := 0
	for c in ref.cases:
		if not str(c.id).begins_with("actor_cache."):
			continue
		n += 1
		if check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			_case(c)
	check("actor_cache_cases", n == 8, n)
	print("KNOWN_DIFFS=", known_hits.size(), " ", JSON.stringify(known_hits))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"total": results.size(), "passed": passed}))
	get_tree().quit(0 if passed == results.size() else 1)
