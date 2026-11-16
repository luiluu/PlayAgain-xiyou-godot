extends Node
## 伤害加成总账·期三补（设计仓《天启篇_伤害加成总账_v0.4》第五节第 2 条表下「九线来源停用」、附表「没核实的」特性 34／61／passiveAPLUS）：
## 一、特性 34（攻击次数＋）、61（追加行动）：没有天启篇标记的装备、原版套装状态、宝珠特性上的不算；天启篇装备、技能挂的状态照算。
## 二、<passiveAPLUS>：秘籍格的书教的被动不算，别的（种族科技这类）照算。
## 三、道法「连击」「分神」天启篇不生效。
## 四、小猫剑圣 native_repeats 读的 AgainUse（符文之语再释放）按同样来源停。
## 五、秘籍格剔除误收：超越极限 1240～1244、诸葛孔明专属被动 2498（招募事件给的）不占格；精通、小药丸照旧占。
## 六、预算接线：云裳放行传 in_action；白起杀气攒满再动（full_again）过 take_extra。
## 每样都验：开关 NINE_OFF 关回期三现状、西游档照旧。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


class FakeLogic extends Node:
	var actors: Array = []
	var enemies: Array = []
	var current_order: Array = []
	var _acted: Dictionary = {}
	var turn := 1
	func _float(_reason: String) -> float:
		return 0.0


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(tianqi := true) -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_nine_off")
	seed(20261116)
	XTianqiLedger.reload()
	_traits()
	_aplus_daofa()
	_cat_again()
	_secret()
	_budget_sites()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _put(a: XActor, kind: String, id: int) -> Dictionary:
	var eq := XActor.make_equip(kind, id)
	var at := a.equip_slots().find(int(eq.etypeId))
	a.equips[at] = eq
	a.read_touch()
	return eq


func _times(a: XActor, on := true) -> float:
	XTianqiLedger.NINE_OFF = on
	a.read_touch()
	var v := a.attack_times_add()
	XTianqiLedger.NINE_OFF = true
	return v


func _plus(a: XActor, on := true) -> Array:
	XTianqiLedger.NINE_OFF = on
	a.read_touch()
	var v := a.action_plus_set()
	XTianqiLedger.NINE_OFF = true
	return v


# ---- 一、特性 34／61 ----
func _traits() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	var t0 := _times(a)
	var p0 := _plus(a).size()
	# 原版武器 6 指虎（攻击次数 +1）
	var knuckle := _put(a, "weapon", 6)
	_check("t34_equip_off", _times(a) == t0 and _times(a, false) == t0 + 1.0, [t0, _times(a), _times(a, false)])
	# 同一件挂上天启篇标记：照算
	knuckle["tq_reward"] = true
	_check("t34_tianqi_gear_kept", _times(a) == t0 + 1.0, _times(a))
	# 天启篇装备上镶的宝珠特性（_codexOrb）：宝珠是九线，停
	(knuckle.traits as Array).append({"code": 34, "dataId": 0, "value": 1, "_codexOrb": "nine_test:1"})
	_check("t34_orb_off", _times(a) == t0 + 1.0 and _times(a, false) == t0 + 2.0, [_times(a), _times(a, false)])
	(knuckle.traits as Array).pop_back()
	knuckle.erase("tq_reward")
	# 技能挂上的状态（1402 振奋，攻击次数 +1）：不是九线，照算
	a.add_state(1402)
	_check("t34_state_kept", _times(a) == t0 + 1.0, _times(a))
	a.remove_state(1402)
	# 原版防具 3876 推进器（追加行动 20%）
	_put(a, "armor", 3876)
	var on := _plus(a)
	var off := _plus(a, false)
	_check("t61_equip_off", on.size() == p0 and off.size() == p0 + 1 and off.has(0.2), [on, off])
	# 原版套装给的状态：停
	var suit_ok := _suit_state_case(a, t0)
	_check("t34_suit_state_off", suit_ok[0], suit_ok[1])
	# 小A 核 P1：角色本体号和套装状态同号——赤狐（角色 97，自带追加行动 100%）穿套装 55 狂风护手（1 件给状态 97），本体那份不能被当成套装状态停掉
	XTianqi._joining = true
	s.add_actor(97)
	XTianqi._joining = false
	var fox := s.actor(97)
	_put(fox, "armor", 1558)
	var fox_suit := XEquipSuits.ids(fox, "states").has(97)
	var fox_bucket := XTianqiLedger.bucket_of(fox.data(), fox)
	var fox_plus := _plus(fox)
	_check("suit_same_id_actor_kept", fox_suit and fox_bucket == "actor" and fox_plus.has(1.0) and fox_plus.size() == _plus(fox, false).size(), [fox_suit, fox_bucket, fox_plus, _plus(fox, false)])
	# 西游档：照旧
	var x := _state(false)
	var xa := x.actor(int(x.battle_slots[0]))
	var xt0 := xa.attack_times_add()
	var xp0 := xa.action_plus_set().size()
	_put(xa, "weapon", 6)
	_put(xa, "armor", 3876)
	_check("t34_t61_xiyou_same", xa.attack_times_add() == xt0 + 1.0 and xa.action_plus_set().size() == xp0 + 1, [xt0, xa.attack_times_add(), xp0, xa.action_plus_set()])


## 原版套装 9「勇士」2 件给状态 41（攻击次数 +1）：两件身上的装备挂上套装号 9
func _suit_state_case(a: XActor, t0: float) -> Array:
	var keep := a.equips.duplicate()
	var off0 := _times(a, false)
	var pieces := []
	for id in [4184, 4185, 4186, 4187]:
		if pieces.size() >= 2:
			break
		var eq := XActor.make_equip("armor", id)
		var at := a.equip_slots().find(int(eq.etypeId))
		if at < 0 or pieces.any(func(p): return int(p[0]) == at):
			continue
		var eqd: Dictionary = eq.get("equipment", {}).duplicate(true)
		eqd["suits"] = [9]
		eq["equipment"] = eqd
		pieces.append([at, eq])
	var base_on := 0.0
	var base_off := 0.0
	for p in pieces:  # 先穿上不带套装号的同一批，量基线（这几件本身没有 34）
		var plain: Dictionary = (p[1] as Dictionary).duplicate(true)
		plain.equipment.suits = []
		a.equips[int(p[0])] = plain
	base_on = _times(a)
	base_off = _times(a, false)
	for p in pieces:
		a.equips[int(p[0])] = p[1]
	a.read_touch()
	var has := XEquipSuits.ids(a, "states").has(41)
	var on := _times(a)
	var off := _times(a, false)
	a.equips = keep
	a.read_touch()
	return [pieces.size() == 2 and has and on == base_on and off == base_off + 1.0, [pieces.size(), has, t0, off0, base_on, base_off, on, off]]


# ---- 二、passiveAPLUS；三、道法 ----
func _aplus_daofa() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[1]))
	var p0 := _plus(a).size()
	# 秘境抽奖·再动 Lv1（书教，5%）：停
	_check("aplus_book_is_secret", XTianqiLedger.is_secret_skill(10425, 5))
	a.learn_skill(10425)
	var on := _plus(a)
	var off := _plus(a, false)
	_check("aplus_book_off", on.size() == p0 and off.size() == p0 + 1 and off.has(0.05), [on, off])
	# 哥布林科技 1 级（5%，不是书）：照算
	a.learn_skill(4566)
	_check("aplus_other_kept", not XTianqiLedger.is_secret_skill(4566, 4) and _plus(a).size() == p0 + 1 and _plus(a, false).size() == p0 + 2, [_plus(a), _plus(a, false)])
	# 道法连击、分神
	var keep: Dictionary = a.zhenqi
	var t0 := _times(a)
	var t0_off := _times(a, false)  # 开局自带的原版装备可能带攻击次数，关开关时另有一份
	var n0 := _plus(a).size()
	var n0_off := _plus(a, false).size()
	a.zhenqi = {"realm": 5, "daofa": {"lianji": 1, "fenshen": 1}}
	_check("daofa_off", _times(a) == t0 and _plus(a).size() == n0 and _times(a, false) == t0_off + 1.0 and _plus(a, false).size() == n0_off + 1 and _plus(a, false).has(1.0), [t0, t0_off, _times(a), _times(a, false), _plus(a, false)])
	a.zhenqi = keep
	# 西游档：书的再动和道法照算
	var x := _state(false)
	var xa := x.actor(int(x.battle_slots[1]))
	var xp0 := xa.action_plus_set().size()
	xa.learn_skill(10425)
	var xt0 := xa.attack_times_add()
	var xkeep: Dictionary = xa.zhenqi
	xa.zhenqi = {"realm": 5, "daofa": {"lianji": 1, "fenshen": 1}}
	xa.read_touch()
	_check("aplus_daofa_xiyou_same", xa.action_plus_set().size() == xp0 + 2 and xa.attack_times_add() == xt0 + 1.0, [xp0, xa.action_plus_set(), xt0, xa.attack_times_add()])
	xa.zhenqi = xkeep


# ---- 四、小猫剑圣读的 AgainUse ----
func _cat_again() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[2]))
	var L := FakeLogic.new()
	var item := XDB.rec("Skills", 8)
	var n0 := XCat.native_repeats(L, a, item)
	_put(a, "armor", 3872)  # 符石「疾风骤雨」<AgainUseAll: 25%>，_float 恒 0 → 原来必 +1
	var on := XCat.native_repeats(L, a, item)
	XTianqiLedger.NINE_OFF = false
	var off := XCat.native_repeats(L, a, item)
	XTianqiLedger.NINE_OFF = true
	_check("cat_again_use_off", on == n0 and off == n0 + 1, [n0, on, off])
	L.free()


# ---- 五、秘籍格剔除误收 ----
func _secret() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[3]))
	var wrong := []
	for id in [1240, 1241, 1242, 1244, 2498]:
		var sk := XDB.rec("Skills", id)
		if XTianqiLedger.is_secret_skill(id, int(sk.get("stypeId", 0))) or XTianqiLedger.bucket_of(sk, a) == "secret":
			wrong.append(id)
	_check("secret_excludes_advance_and_recruit", wrong.is_empty(), wrong)
	# 小药丸本身教的（5091～5098）、精通系列、心法（固定角色的「学会技能」）照旧占格
	var keep := [5091, 5095, 5098, 5214, 5189, 4901, 4723, 6925]
	var lost := keep.filter(func(id): return not XTianqiLedger.is_secret_skill(id, int(XDB.rec("Skills", id).get("stypeId", 0))))
	_check("secret_keeps_books", lost.is_empty(), lost)


# ---- 六、预算接线 ----
func _budget_sites() -> void:
	var ys := FileAccess.get_file_as_string("res://modes/xiyou/core/yunshang.gd")
	var rel := ys.substr(ys.find("static func release("), 400)
	_check("yunshang_release_in_action", rel.contains("add_actions(logic, a, count, \"stored\", true)"), rel)
	_check("full_again_listed", (XTianqiLedger.data().get("turn_budget", {}).get("extra", []) as Array).any(func(r): return str(r).begins_with("card.full_again")))
	# 白起杀气 full_again：攒满那次行动之后再动一次过预算（CARDS 现关、实战不触发，这里直接调）
	var s := _state()
	XTianqi._joining = true
	s.add_actor(80)
	XTianqi._joining = false
	var u := s.actor(80)
	var ch: Dictionary = XTianqiSkills.data().get("actors", {}).get("80", {}).get("charge", {})
	u.learn_skill(int(ch.full_again))
	var gain_id := int(ch.gain.keys()[0])
	var f := {"skill": XDB.rec("Skills", gain_id), "crit": false, "targets": []}
	var L := FakeLogic.new()
	L.actors = [u]
	# 本回合只排了一次、已行动：攒满给再动 1 次
	L.turn = 1
	L._acted = {u: 1}
	L.current_order = []
	s.set_variable(int(ch["var"]), int(ch.cap) - 1)
	XTianqiSkills._charge(L, u, f)
	var got1 := L.current_order.count(u)
	# 掷出的再动已占预算（顺序里还排着一次）：攒满不再插
	u.remove_meta("xtq_charge_again")
	L.turn = 2
	L._acted = {u: 1}
	L.current_order = [u]
	s.set_variable(int(ch["var"]), int(ch.cap) - 1)
	XTianqiSkills._charge(L, u, f)
	var got2 := L.current_order.count(u)
	var used := bool(u.get_meta("xtq_charge_again", false))
	_check("full_again_budget", got1 == 1 and got2 == 1 and used, [got1, got2, used])
	u.remove_meta("xtq_charge_again")
	L.free()
