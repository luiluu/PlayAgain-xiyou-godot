extends Node
## T570：天启篇几条防御状态的削弱要进结算（不是只改备注）。单角色木桩：直接跑运行时状态记录的效果阶段（XStateEffects.run_one），
## 量单次效果数值；复活几率用固定种子抽 N 次。设计值见私密设计仓 天启篇_全角色技能重构_v0.2：
##   2562 护体罡气（165 真气护体）：30% 受伤由魔法值代替
##   2560 绯红之夜（163 普通闪躲）：免疫一次即死或致命伤
##   2554 不死之躯（159 不灭之躯）：复活回 30%（每场一次）
##   1099 预感的庇护、1178 拼命守护：死后 30% 复活（回 30%，每场一次）
##   2561 吃瘪之力（164 吃瘪之力）：受到伤害 −10%（Kyo 11-27 事项 73：天启篇改成设计稿 −10%，西游档不动）
## 西游档：同一批状态的记录与原表一致、实战照旧（9.9%、三次、回满、两次掷骰、吃瘪之力照贝吉特调整 −50%）。
const Kit := preload("res://tests/lib/tq_save_kit.gd")
const N := 20000
const MHP := 100000.0

var results: Array = []
var measured := {}


class Dummy:
	extends XBattler
	func param(i: int) -> float:
		return [MHP, 100000.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0][i]


## 复活掷骰（state_effect／revive）按给定值出，别的照种子 1 的真随机数；记下掷了几次
class ReviveStream extends XRandomStream:
	var revive_values: Array = []
	var revive_draws := 0
	func next_float(reason: String, event_key := "") -> float:
		if reason == "state_effect" and event_key == "revive":
			revive_draws += 1
			return float(revive_values.pop_front()) if not revive_values.is_empty() else 0.99
		return super.next_float(reason, event_key)


class StreamLogic extends XBattleLogic:
	var rs: XRandomStream
	func _rule() -> XRandomStream:
		return rs


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _dummy(hp: float, mp := 100000.0) -> Dummy:
	var b := Dummy.new()
	b.hp = hp
	b.mp = mp
	return b


func _ctx(t: XBattler, value: float, random: XRandomStream = null) -> Dictionary:
	return {"attacker": t, "defender": t, "target": t, "item": {"id": 1, "damage": {"type": 1, "elementId": 0}}, "value": value,
		"execute": true, "resources": XResourceContext.new(), "record": {}, "random": random}


## 护体罡气：满蓝挨 1000 点，返回 [实际受伤, 扣蓝]
func _qi(st: Dictionary) -> Array:
	var b := _dummy(MHP)
	b.state_ids.append(2562)
	var got := XStateEffects.run_one("react", b, st, _ctx(b, 1000.0))
	return [got, 100000.0 - b.mp]


## 绯红之夜：开战一次，然后连续倒下 5 次，数被救回几次
func _crimson(st: Dictionary) -> int:
	var b := _dummy(MHP)
	b.state_ids.append(2560)
	XStateEffects.run_one("battle", b, st, _ctx(b, 0.0))
	var saved := 0
	for i in 5:
		b.hp = 0.0
		XStateEffects.run_one("deselect", b, st, _ctx(b, 0.0))
		if b.hp > 0.0:
			saved += 1
	return saved


## 不死之躯：倒下一次，返回 [复活后生命, 状态还在不在]
func _undying(st: Dictionary) -> Array:
	var b := _dummy(0.0)
	b.state_ids.append_array([1, 2554])
	XStateEffects.run_one("respond", b, st, _ctx(b, 0.0))
	return [b.hp, b.state_ids.has(2554)]


## 自动复活：每次一个新木桩被打倒，抽 N 次，返回 [复活几率, 一次复活回的生命, 每次倒下平均抽几次]
func _revive(id: int, st: Dictionary) -> Array:
	var rs := XRandomStream.create("0000000000000001", "rule")
	var ok := 0
	var heal := -1.0
	for i in N:
		var b := _dummy(0.0)
		b.state_ids.append(id)
		XStateEffects.run_one("deselect", b, st, _ctx(b, 0.0, rs))
		if b.hp > 0.0:
			ok += 1
			heal = b.hp
	return [float(ok) / N, heal]


func _measure(tag: String) -> Dictionary:
	var m := {}
	m["2562"] = _qi(XDB.rec("States", 2562))
	m["2560"] = _crimson(XDB.rec("States", 2560))
	m["2554"] = _undying(XDB.rec("States", 2554))
	m["1099"] = _revive(1099, XDB.rec("States", 1099))
	m["1178"] = _revive(1178, XDB.rec("States", 1178))
	var b := _dummy(MHP)
	b.state_ids.append(2561)
	m["2561"] = XStateEffects.run_one("react", b, XDB.rec("States", 2561), _ctx(b, 1000.0))
	print("T570_MEASURE ", tag, " ", JSON.stringify(m))
	return m


## ---- R1：实战（XBattleLogic.execute）----
var CRIMSON_VAR := 0  # 绯红之夜次数所在变量：取 2560 Battle 阶段 set_variable 的号（新源 1597）
const TWO_HIT_TROOP := 788  # 敌群里的敌人放原有两段技能 694（马神*半人马奔腾）
const TWO_HIT_SKILL := 694


func _logic(lineup: Array, values := []) -> Array:
	var s := XTianqi.start_new_game(3, "lianyu", lineup)  # 拳一是超强者：炼狱档能上阵
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.init_battle_slots()
	s.map_id = 4
	XState.current = s
	s.set_variable(CRIMSON_VAR, 0.0)
	var L := StreamLogic.new()
	var rs := ReviveStream.new()
	rs.domain = "rule"
	rs._rng.seed = 1
	rs.revive_values = values.duplicate()
	L.rs = rs
	L.elite_roll = 100.0
	L.setup(TWO_HIT_TROOP, s)
	var a: XBattler = null
	for m in L.actors:
		if int(m.actor_id) == int(lineup[0]):
			a = m
	for e in L.enemies:
		e.hp = e.mhp
	return [s, L, a, rs]


## 敌人普攻打到 a 为止（闪避／落空就再打，最多 20 次）；返回真打中了没有
func _lethal(L: XBattleLogic, a: XBattler, skill := 1) -> bool:
	for i in 20:
		a.hp = 1.0
		var logs: Array = L.execute(L.enemies[0], XDB.rec("Skills", skill), a)
		var hit := logs.filter(func(l): return str(l.get("type", "")) == "hit" and l.get("target") == a and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)))
		if not hit.is_empty():
			return true
	return false


func _cast(L: XBattleLogic, a: XBattler) -> void:
	a.mp = a.mmp
	a.tp = 100
	L.execute(a, XDB.rec("Skills", 9936), a)


func _runtime() -> void:
	for e in XDB.rec("States", 2560).get("effects", []):
		if str(e.get("phase", "")) == "battle" and str(e.get("op", "")) == "set_variable":
			CRIMSON_VAR = int(e.id)
	_check("rt.crimson_var_found", CRIMSON_VAR > 0, CRIMSON_VAR)
	# P1-1：普通闪躲首次施放就给一次保护；用掉后同场再施放再给一次
	var r := _logic([163])
	var L: XBattleLogic = r[1]
	var a: XBattler = r[2]
	_check("rt.actor_163_in_battle", a != null, [XState.current.party, XState.current.battle_slots, L.actors.map(func(m): return m.actor_id)])
	if a == null:
		return
	_cast(L, a)
	var v1 := XState.current.variable(CRIMSON_VAR)
	_check("rt.crimson_first_cast_grants", a.state_ids.has(2560) and v1 == 1.0, [a.state_ids.has(2560), v1])
	var hit1 := _lethal(L, a)
	_check("rt.crimson_first_cast_saves", hit1 and a.hp == 1.0 and not a.is_dead() and XState.current.variable(CRIMSON_VAR) == 0.0,
		[hit1, a.hp, a.is_dead(), XState.current.variable(CRIMSON_VAR)])
	var hit2 := _lethal(L, a)
	_check("rt.crimson_used_up_dies", hit2 and a.is_dead(), [hit2, a.hp])
	# 同场续施：先救回来再施放
	a.remove_state(1)
	a.hp = a.mhp
	_cast(L, a)
	_check("rt.crimson_recast_grants", a.state_ids.has(2560) and XState.current.variable(CRIMSON_VAR) == 1.0, XState.current.variable(CRIMSON_VAR))
	var hit3 := _lethal(L, a)
	_check("rt.crimson_recast_saves", hit3 and a.hp == 1.0 and not a.is_dead(), [hit3, a.hp])
	L.end_battle()
	# 回退：施放不补发，首次施放后致命伤照常阵亡
	XTianqiSkills.CAST_GRANT = false
	r = _logic([163])
	L = r[1]
	a = r[2]
	_cast(L, a)
	var hit4 := _lethal(L, a)
	_check("rollback.crimson_cast_no_grant", XState.current.variable(CRIMSON_VAR) == 0.0 and hit4 and a.is_dead(), [XState.current.variable(CRIMSON_VAR), hit4, a.hp])
	L.end_battle()
	XTianqiSkills.CAST_GRANT = true

	# P1-2：两段敌技打到 0 血，首段掷 0.5 没中，第二段不再掷（给的 0.2 用不上）
	for id in [1099, 1178]:
		r = _logic([163], [0.5, 0.2])
		L = r[1]
		a = r[2]
		var rs: ReviveStream = r[3]
		a.add_state(id)
		var hit := _lethal(L, a, TWO_HIT_SKILL)
		_check("rt.%d_two_hit_one_roll" % id, hit and rs.revive_draws == 1 and a.is_dead(), [hit, rs.revive_draws, a.hp, a.is_dead()])
		# 重新有了生命再归零：照规则再掷（这次给 0.2，中；用单段普攻，免得 694 第二段把刚救回的再打倒）
		a.remove_state(1)
		a.hp = a.mhp
		if not a.state_ids.has(id):
			a.add_state(id)
		rs.revive_values = [0.2]
		rs.revive_draws = 0
		hit = _lethal(L, a)
		_check("rt.%d_new_fall_rolls_again" % id, hit and rs.revive_draws == 1 and not a.is_dead() and a.hp > 0.0, [hit, rs.revive_draws, a.hp])
		L.end_battle()
	# 回退（两次掷骰）：同一序列第二段还会再掷
	XTianqiSkills.REVIVE_SINGLE_ROLL = false
	XTianqiSkills._state_recs = {}
	r = _logic([163], [0.5, 0.2, 0.5, 0.2])
	L = r[1]
	a = r[2]
	a.add_state(1099)
	_lethal(L, a, TWO_HIT_SKILL)
	_check("rollback.revive_two_hit_rolls_more", (r[3] as ReviveStream).revive_draws > 1, (r[3] as ReviveStream).revive_draws)
	L.end_battle()
	XTianqiSkills.REVIVE_SINGLE_ROLL = true
	XTianqiSkills._state_recs = {}


func _run() -> void:
	XMessageBox.auto = true
	var kit := Kit.new("xiyou_tianqi_t570")
	XTianqiSkills.reload_table()
	XStateEffects.observer = Callable()

	# ---- 天启篇 ----
	var s := XTianqi.start_new_game(3, "jianxian", [1])
	XTianqi.take_pending()
	XState.current = s
	var tq := _measure("tianqi")
	_check("tq.2562_30pct_mp", tq["2562"] == [700.0, 300.0], tq["2562"])
	_check("tq.2560_once", tq["2560"] == 1, tq["2560"])
	_check("tq.2554_30pct_once", tq["2554"] == [floorf(MHP * 0.3), false], tq["2554"])
	for id in ["1099", "1178"]:
		var r: Array = tq[id]
		_check("tq.%s_rate_30pct" % id, absf(float(r[0]) - 0.3) < 0.015, r)
		_check("tq.%s_heal_30pct" % id, float(r[1]) == floorf(MHP * 0.3), r)
	_check("tq.2561_minus10pct", tq["2561"] == 900.0, tq["2561"])
	_check("tq.2561_skill_desc", XTianqiSkills.data().skills["9942"].desc == ["效果：受到的伤害 −10%"], XTianqiSkills.data().skills["9942"].desc)
	# 备注里不再留没生效的脚本改写（note_sub），免得读备注的人以为改到了
	for id in [2562, 2560, 2554, 2561]:
		_check("tq.%d_no_dead_note_sub" % id, not XTianqiSkills.data().states[str(id)].has("note_sub"), id)

	# 首领状态窗：表里显式标「异常」的 39 个都进 Debuff 页签（T566 复核遗留：原来按 kind_of 有 22 个进了 Buff）
	var abnormal: Array = XTianqiSkills.data().states.keys().filter(func(k): return str(XTianqiSkills.data().states[k].get("state_kind", "")) == "异常").map(func(k): return int(k))
	_check("boss.abnormal_count_39", abnormal.size() == 39, abnormal.size())
	var was_buff := abnormal.filter(func(id): return XBossStatus.kind_of(XDB.rec("States", id)) == "Buff")
	print("T570_BOSS_WAS_BUFF ", was_buff.size(), " ", JSON.stringify(was_buff))
	var not_debuff := []
	for id in abnormal:
		var b := _dummy(MHP)
		b.state_ids.append(id)
		var hit := XBossStatus.entries(b).filter(func(r): return r.id is int and r.id == id)
		if hit.is_empty() or str(hit[0].kind) != "Debuff":
			not_debuff.append([id, hit.map(func(r): return r.kind)])
	_check("boss.abnormal_in_debuff_tab", not_debuff.is_empty(), not_debuff)
	XBossStatus.PANEL_TIANQI_KIND = false
	var back := abnormal.filter(func(id): return XBossStatus.panel_kind(XDB.rec("States", id)) == "Buff")
	_check("rollback.boss_kind_rule", back == was_buff, [back.size(), was_buff.size()])
	XBossStatus.PANEL_TIANQI_KIND = true
	# 结算读的 kind_of 不改（驱散、异化等）
	_check("boss.kind_of_unchanged", was_buff.size() > 0, was_buff.size())

	# 回退开关：关掉回到 T570 之前（9.9%、三次、回满、两次掷骰约 51%）
	XTianqiSkills.REVIVE_SINGLE_ROLL = false
	XTianqiSkills.EFFECT_NUMS = false
	XTianqiSkills._state_recs = {}
	var off := _measure("tianqi_rollback")
	_check("rollback.old_values", off["2562"] == [901.0, 99.0] and off["2560"] == 3 and off["2554"] == [MHP, false]
		and absf(float(off["1099"][0]) - (1.0 - 0.7 * 0.7)) < 0.015 and off["2561"] == 500.0, off)
	XTianqiSkills.REVIVE_SINGLE_ROLL = true
	XTianqiSkills.EFFECT_NUMS = true
	XTianqiSkills._state_recs = {}

	_runtime()

	# ---- 西游档：照旧 ----
	var xy := XState.new_game(3, 1, [8])
	XState.current = xy
	var table: Array = XDB.table("States")
	var same := [2562, 2560, 2554, 2561, 1099, 1178].filter(func(id): return XDB.rec("States", id) == table[id])
	_check("xy.records_untouched", same.size() == 6, same)
	var xy_diff := abnormal.filter(func(id): return id < table.size() and XBossStatus.panel_kind(XDB.rec("States", id)) != XBossStatus.kind_of(table[id]))
	_check("xy.boss_kind_rule_unchanged", xy_diff.is_empty(), xy_diff)
	var x := _measure("xiyou")
	_check("xy.2562_9.9pct", x["2562"] == [901.0, 99.0], x["2562"])
	_check("xy.2560_three", x["2560"] == 3, x["2560"])
	_check("xy.2554_full", x["2554"] == [MHP, false], x["2554"])
	_check("xy.1099_two_rolls", absf(float(x["1099"][0]) - (1.0 - 0.6 * 0.6)) < 0.015, x["1099"])
	_check("xy.2561_vegeta_half", x["2561"] == float(floori(1000.0 * float(XVegetaTune.cfg().get("chibie", 0.1)))) and x["2561"] == 500.0, x["2561"])
	_check("xy.1178_two_rolls", absf(float(x["1178"][0]) - (1.0 - 0.65 * 0.65)) < 0.015, x["1178"])

	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
