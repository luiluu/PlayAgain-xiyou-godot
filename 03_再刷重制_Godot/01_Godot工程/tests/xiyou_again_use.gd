extends Node
## 被动再释放／攻击次数（T046，O-547 XBattleLogic.AGAIN_USE）：dsPassiveSkill 的 Game_Action.numRepeats 包装接进西游档通用出手。
## 参照 mv_oracle/again_use_probe.cjs（夹具 tests/fixtures/again_use_oracle.json）：角色 1 摆好技能／状态／装备后，
## 普攻 1、战技 9、魔法 51、物品 1 在一串固定随机数下的 numRepeats。
## 一、逐例逐随机数比 passive_repeats(attack_repeats(...))；MV 本体 attack_repeats 照旧。
## 二、开关关掉：回到只有 MV 本体，参照里有差的例子对不上（缺口复现）。
## 三、天启篇不走这层（只有小猫剑圣读，九线照停）；小猫剑圣自己的剑技、敌人不加。
## 四、实战 execute 接上了：带 100% 再释放的角色用药水，效果打两次；开关关掉只打一次。

var results := []


class RollLogic extends XBattleLogic:
	var roll := 0.5
	func _float(_reason: String) -> float:
		return roll


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _run() -> void:
	XBattleLogic.AGAIN_USE = true  # 本专项测开着的行为，不依赖默认值（11-16 默认曾临时关，T088 开回；保留这行防默认再变）
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/again_use_oracle.json"))
	if not check("oracle_present", ref is Dictionary and ref.has("cases") and not ref.cases.is_empty()):
		return _finish()
	check("oracle_clean", ref.cases.all(func(c): return c.errors.is_empty()))
	_oracle(ref)
	_switch_off(ref)
	_not_touched()
	_execute()
	_finish()


func _actor(spec: Dictionary) -> XActor:
	var s := XState.new_game_blank()
	XState.current = s
	s.add_actor(int(spec.actor))
	var a := s.actor(int(spec.actor))
	for n in a.equips.size():
		a.equips[n] = null
	for id in spec.get("skills", []):
		a.learn_skill(int(id))
	for id in spec.get("states", []):
		a.add_state(int(id))
	for eq in spec.get("equips", []):
		var kind := "weapon" if str(eq[0]) == "w" else "armor"
		var item := XGear.create(kind, int(eq[1]), s)
		var slot := 0 if kind == "weapon" else a.equip_slots().find(int(item.etypeId))
		a.equips[slot] = item
	a.refresh_passive()
	return a


func _rec(act: Dictionary) -> Dictionary:
	return XDB.rec("Skills" if str(act.kind) == "skill" else "Items", int(act.id))


## 照参照逐例逐随机数量；返回对不上的条目
func _measure(ref: Dictionary, L: RollLogic, only_report := false) -> Array:
	var bad := []
	for c in ref.cases:
		var a := _actor(c.setup)
		var want_equips: Array = c.observed.equips.filter(func(x): return int(x) != 0).map(func(x): return int(x))
		var got_equips: Array = a.equips.filter(func(e): return e != null and not e.is_empty()).map(func(e): return int(e.base))
		if not only_report:
			check(str(c.id) + ".equips", got_equips == want_equips, [got_equips, want_equips])
			check(str(c.id) + ".states", a.states().map(func(x): return int(x.id)) == c.observed.states.map(func(x): return int(x)))
		for act in c.observed.actions:
			var item := _rec(act)
			var mv := XBattleLogic.attack_repeats(a, item, int(item.get("repeats", 1)))
			if not only_report:
				check("%s.%s%d.mv" % [c.id, act.kind, int(act.id)], mv == int(act.mvRepeats), [mv, act.mvRepeats])
			var got := []
			for r in ref.rolls:
				L.roll = float(r)
				got.append(L.passive_repeats(a, item, mv))
			var want: Array = act.numRepeats.map(func(x): return int(x))
			if got != want:
				bad.append({"case": c.id, "action": "%s%d" % [act.kind, int(act.id)], "got": got, "want": want})
	return bad


func _oracle(ref: Dictionary) -> void:
	var L := RollLogic.new()
	var bad := _measure(ref, L)
	check("oracle_numRepeats_all_match", bad.is_empty(), bad)
	# 参照里确实有多出来的段（atkk 恒 +1、几率掷中 +1、类型不对不加），不是全 1 的空比
	var extra := 0
	for c in ref.cases:
		for act in c.observed.actions:
			extra += act.numRepeats.filter(func(x): return int(x) > int(act.mvRepeats)).size()
	check("oracle_has_extra_segments", extra > 100, extra)


func _switch_off(ref: Dictionary) -> void:
	var L := RollLogic.new()
	XBattleLogic.AGAIN_USE = false
	var bad := _measure(ref, L, true)
	XBattleLogic.AGAIN_USE = true
	var cases := {}
	for b in bad:
		cases[b.case] = true
	# 关掉＝T046 之前：通用出手不读 atkk／AgainUse，除了 none 和类型不对的例子都对不上
	check("switch_off_reproduces_gap", cases.has("skill1817-atkk") and cases.has("state1384-all50") and cases.has("rune-armor3872-all25") and not cases.has("none"), cases.keys())


func _not_touched() -> void:
	var L := RollLogic.new()
	L.roll = 0.0
	var skill9 := XDB.rec("Skills", 9)
	# 天启篇：不走这层
	var a := _actor({"actor": 1, "states": [1384], "skills": [1817]})
	check("xiyou_rolls", L.passive_repeats(a, skill9, 1) == 3, L.passive_repeats(a, skill9, 1))
	XState.current.flags["tianqi"] = {"rules": 1}
	check("tianqi_untouched", XTianqi.active(XState.current) and L.passive_repeats(a, skill9, 1) == 1, L.passive_repeats(a, skill9, 1))
	XState.current.flags.erase("tianqi")
	# 小猫剑圣的四个剑技：原版 numRepeats 恒 1（次数在 XCat.native_repeats 按剑段算）
	var cat := _actor({"actor": XCat.ACTOR, "states": [1384]})
	var slash := XDB.rec("Skills", XCat.ACTIVE[0])
	check("cat_kit_untouched", XCat.casts(cat, slash) and L.passive_repeats(cat, slash, 1) == 1)
	check("cat_other_skill_rolls", L.passive_repeats(cat, skill9, 1) == 2)
	# 敌人：被动缓存没有 atkk／againUse
	var e := XEnemy.new().setup(1, 3)
	e.add_state(1384)
	check("enemy_untouched", L.passive_repeats(e, skill9, 1) == 1)


## 实战：药水（物品 1）在原版也吃 AgainUse／atkk；技能 7008「觉醒:刹那」<AgainUseAll: 100%> → 效果打两次
func _execute() -> void:
	var counts := {}
	for on in [true, false]:
		XBattleLogic.AGAIN_USE = on
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var a := s.actor(1)
		a.learn_skill(7008)
		a.refresh_passive()
		s.gain_item(1, 1)
		var logic := XBattleLogic.new()
		logic.elite_roll = 100.0
		logic.setup(2, s)
		a.hp = 1.0
		var logs := logic.execute(a, XDB.rec("Items", 1), a)
		counts[on] = logs.filter(func(l): return str(l.get("type", "")) == "hit" and l.get("target") == a).size()
		logic.end_battle()
	XBattleLogic.AGAIN_USE = true
	check("execute_wired", int(counts[true]) == 2 and int(counts[false]) == 1, counts)


func _finish() -> void:
	XBattleLogic.AGAIN_USE = true
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
