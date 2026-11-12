extends Node
## 天启篇新异化词条战斗效果专项（XTianqiAlienAffix；四线异化 v0.8 第 4.2 节，数在 alien_gear.json 的 effects）。
## 临终（致命一击留一口气、本回合攻击 +50%、回合结束必死、每场一次）、再动（第 3 回合多动一次、受伤 +25%）、
## 节俭（消耗 −33%、受到的回复 −33%）、带毒（打中附毒、自己开战和回合末续毒）；原版档、开关关掉、没穿的人都不生效。
## 数字避开 4（Kyo 11-11）。

const CONFIG := "user://xiyou_tianqi_alien_affix_config.json"
const TROOP := 1   # 嘤嘤怪
const POISON := XTianqiAlienAffix.POISON
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state() -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	return s


## 给上场第一人穿一件带 affix 的天启篇异化装备（草帽，头部）
func _wear(s: XState, line: String, affix: String) -> XActor:
	var item: Dictionary = XTianqiAlienGear.create(s, "armor", 52, line, "huaxing", affix).ok
	s.gear.append(item)
	var a: XActor = s.battle_members()[0]
	var slot := a.equip_slots().find(int(item.etypeId))
	XEquipment.change(s, a, slot, item)
	return a


func _logic(s: XState) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(TROOP, s)
	return lg


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	XTianqiAlienGear.reload()
	_check("nice_numbers", XTianqiAlienGear.nice_number_violations().is_empty(), XTianqiAlienGear.nice_number_violations())
	_dying()
	_again()
	_thrift()
	_venom()
	_off()
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 打一下：经过临终的挂钩后扣血（护盾先吸）
func _hit(lg: XBattleLogic, e, a: XActor, value: float) -> void:
	var v := XTianqiAlienAffix.hp_damage(lg, e, a, value)
	var sh := minf(a.shield, v)
	a.shield -= sh
	a.hp = maxf(0.0, a.hp - (v - sh))
	if a.hp <= 0.0:
		a.add_state(1)


func _dying() -> void:
	var s := _state()
	var a := _wear(s, "death", "dying")
	var lg := _logic(s)
	_check("dying_key", XTianqiAlienAffix.key_of(a) == "dying")
	var e: XEnemy = lg.enemies[0]
	var atk0 := a.param(2)
	_check("dying_not_lethal_unchanged", XTianqiAlienAffix.hp_damage(lg, e, a, 1.0) == 1.0)
	_hit(lg, e, a, a.hp + a.shield + 1000.0)
	_check("dying_survive", a.is_alive() and a.hp == 1.0, [a.hp, a.is_alive()])
	_check("dying_atk", is_equal_approx(XTianqiAlienAffix.param_rate(a, 2), 1.5) and is_equal_approx(XTianqiAlienAffix.param_rate(a, 4), 1.5) and a.param(2) > atk0, [atk0, a.param(2)])
	var logs := XTianqiAlienAffix.take_logs(lg)
	_check("dying_log", logs.any(func(l): return str(l.text).contains("临终")), logs)
	_hit(lg, e, a, 5000.0)
	_check("dying_same_turn", a.is_alive(), a.hp)
	lg.end_turn()
	_check("dying_end_turn_dead", a.is_dead() and a.state_ids.has(1), [a.hp, a.state_ids])
	_check("dying_atk_back", not XTianqiAlienAffix.dying_now(a) and a.param(2) <= atk0 * 1.01, [atk0, a.param(2)])
	# 每场一次：复活后再挨一下致命的就倒
	a.remove_state(1)
	a.hp = 100.0
	lg.turn += 1
	_hit(lg, e, a, 5000.0)
	_check("dying_once", a.hp <= 0.0, a.hp)
	lg.end_battle(1)
	# 没穿的人不受影响
	var s2 := _state()
	var lg2 := _logic(s2)
	var b: XActor = lg2.actors[0]
	_check("dying_none", XTianqiAlienAffix.hp_damage(lg2, lg2.enemies[0], b, b.hp + 1000.0) == b.hp + 1000.0)
	lg2.end_battle(1)


func _again() -> void:
	var s := _state()
	var a := _wear(s, "war", "again")
	var lg := _logic(s)
	var item := {"damage": {"type": 1, "elementId": 0}}
	var ops := XTianqiAffixBattle.damage_ops(item, lg.enemies[0], a)
	_check("again_taken", ops.any(func(o): return o.field == "incomingMultiplier" and is_equal_approx(float(o.value), 1.25)), ops)
	var by_turn := {}
	for t in [1, 2, 3, 6]:
		lg.turn = t
		var rates := []
		XTianqiAffixBattle.action_plus_set(a, rates)
		by_turn[t] = rates.has(1.0)
	_check("again_every_three", not by_turn[1] and not by_turn[2] and by_turn[3] and by_turn[6], by_turn)
	lg.turn = 3
	_check("again_action_times", lg.make_action_times(a) >= 2, lg.make_action_times(a))
	lg.end_battle(1)


func _thrift() -> void:
	var s := _state()
	var a := _wear(s, "famine", "thrift")
	var lg := _logic(s)
	var skill := XDB.rec("Skills", 10)
	var c := XTianqiAffixBattle.cost(a, skill, {"mp": 30, "tp": 30})
	_check("thrift_cost", int(c.mp) == 20 and int(c.tp) == 20, c)
	var ops := XTianqiAffixBattle.damage_ops({"damage": {"type": 3, "elementId": 0}}, a, a)
	_check("thrift_heal", ops.any(func(o): return o.field == "healingMultiplier" and is_equal_approx(float(o.value), 0.67)), ops)
	var other: XActor = lg.actors[1]
	_check("thrift_others", XTianqiAffixBattle.damage_ops({"damage": {"type": 3, "elementId": 0}}, a, other).filter(func(o): return o.field == "healingMultiplier").is_empty())
	lg.end_battle(1)


func _venom() -> void:
	var s := _state()
	var a := _wear(s, "plague", "venom")
	var lg := _logic(s)
	_check("venom_self_start", a.state_ids.has(POISON), a.state_ids)
	var e: XEnemy = lg.enemies[0]
	var skill := XDB.rec("Skills", 1)
	XTianqiAffixBattle.after_apply(lg, a, skill, e, {"hp": 10.0})
	_check("venom_hit", e.state_ids.has(POISON) or e.traits_set(XBattler.TRAIT_STATE_RESIST).has(POISON), e.state_ids)
	e.remove_state(POISON)
	XTianqiAffixBattle.after_apply(lg, a, skill, e, {"hp": 0.0, "missed": true})
	_check("venom_miss", not e.state_ids.has(POISON), e.state_ids)
	a.remove_state(POISON)
	XTianqiAlienAffix.end_turn(lg)
	_check("venom_self_renew", a.state_ids.has(POISON) or a.is_dead(), a.state_ids)
	lg.end_battle(1)


func _off() -> void:
	# 开关关掉
	XTianqiAlienAffix.ENABLED = false
	var s := _state()
	var a := _wear(s, "famine", "thrift")
	var lg := _logic(s)
	var c := XTianqiAffixBattle.cost(a, XDB.rec("Skills", 10), {"mp": 30, "tp": 30})
	_check("off_cost", int(c.mp) == 30, c)
	_check("off_details", XAlienation.details(s, a.equip_list().filter(func(e): return XTianqiAlienGear.is_tq(e))[0]).any(func(x): return str(x).begins_with("未生效")))
	lg.end_battle(1)
	XTianqiAlienAffix.ENABLED = true
	# 原版档：原版异化装备（原词条）照旧，新模块不建本场数据
	var plain := XState.new()
	plain.add_actor(1)
	XState.current = plain
	var lp := XBattleLogic.new()
	lp.setup(TROOP, plain)
	_check("plain_none", not lp.has_meta(XTianqiAlienAffix.META))
	lp.end_battle(1)
