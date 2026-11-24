extends Node
## T466 替身守层者首通（XZhenqi.STAND_IN_GUARDIANS／STAND_IN_FIRSTS，O-待定）：
## 表与 13～30 层地图守层者事件教派页（2302／2303／2307）的敌群一致、不并进 GUARDIANS；替身打赢记首通＋每胜、与正牌同口径；
## 回退开关关掉回到只给 Boss 奖励；读档补发（backfill_stand_in）按进度层补 party 全员当前路线首通、只一次；天启篇不认、不补。

var results := []
const GUARD_EVENTS := {64: 1, 30: 8, 32: 1, 33: 3, 45: 1, 46: 1, 47: 13, 116: 1, 117: 1, 119: 13, 118: 3, 120: 1, 147: 1, 155: 1, 182: 1, 145: 1, 144: 1, 146: 1}
const PRIMORDIAL := 2483


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _fresh(sect_switch: int) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.set_switch(PRIMORDIAL, true)
	if sect_switch > 0:
		s.set_switch(sect_switch, true)
	XZhenqi.toasts.clear()
	return s


func _win(s: XState, troop: int) -> Dictionary:
	var before := {}
	for a in s.members():
		before[a.actor_id] = int(XZhenqi.data(a).qi)
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	var b := XZhenqi.battle.duplicate()
	XZhenqi.on_victory(s, logic.actors, logic.enemies)
	var gains := {}
	for a in logic.actors:
		gains[a.actor_id] = int(a.zhenqi.qi) - int(before.get(a.actor_id, 0))
	return {"battle": b, "gains": gains, "actors": logic.actors.map(func(a): return a.actor_id)}


func _table_matches_maps() -> void:
	var seen := {}
	for m in GUARD_EVENTS:
		var ev := {}
		for e in XDB.map(int(m)).get("events", []):
			if e is Dictionary and int(e.get("id", 0)) == int(GUARD_EVENTS[m]):
				ev = e
		var floor_no := 0
		for p in ev.get("pages", []):
			var c: Dictionary = p.get("conditions", {})
			var sw := int(c.get("switch1Id", 0)) if bool(c.get("switch1Valid", false)) else 0
			for cmd in p.get("list", []):
				if int(cmd.get("code", 0)) == 301 and int(cmd.parameters[0]) == 0:
					var t := int(cmd.parameters[1])
					if sw == 0:
						floor_no = int(XZhenqi.GUARDIANS.get(t, 0))
					elif XZhenqi.STAND_IN_SECT_SWITCHES.has(sw):
						seen[t] = floor_no
					break
		check("map_%d_has_guardian" % m, floor_no >= 13 and floor_no <= 30, floor_no)
	check("table_equals_map_pages", JSON.stringify(_sorted(seen)) == JSON.stringify(_sorted(XZhenqi.STAND_IN_GUARDIANS)), [seen, XZhenqi.STAND_IN_GUARDIANS])
	var overlap := XZhenqi.STAND_IN_GUARDIANS.keys().filter(func(t): return XZhenqi.GUARDIANS.has(t))
	check("not_in_guardians", overlap.is_empty(), overlap)
	check("guardians_unchanged", XZhenqi.GUARDIANS.size() == 34 and XZhenqi.guardian_troop_of_floor(13) == 111 and XZhenqi.guardian_troop_of_floor(30) == 466)


func _sorted(d: Dictionary) -> Array:
	var out := []
	var keys := d.keys()
	keys.sort()
	for k in keys:
		out.append([int(k), int(d[k])])
	return out


func _live() -> void:
	# 轮回归来 798（13 层）：首通 10×13×13＋每胜 3×13×13
	var s := _fresh(2307)
	var r := _win(s, 798)
	check("lunhui_floor", int(r.battle.standInFloor) == 13 and int(r.battle.guardianFloor) == 0 and int(r.battle.floor) == 13, r.battle)
	var ok: bool = not r.actors.is_empty()
	for id in r.gains:
		ok = ok and int(r.gains[id]) == 2197 and s.actor(id).zhenqi.firsts.has("primordial:13")
	check("lunhui_first_gain", ok, r.gains)
	check("live_marks_save", bool(s.flags.get(XZhenqi.STAND_IN_MARK, false)))
	var r2 := _win(s, 798)
	check("lunhui_repeat_gain", r2.gains.values().all(func(g): return int(g) == 507), r2.gains)
	# 天道使者 761（26 层，两种替身共用）
	var s2 := _fresh(2302)
	var r3 := _win(s2, 761)
	check("tiandao_26", int(r3.battle.standInFloor) == 26 and r3.gains.values().all(func(g): return int(g) == 10 * 26 * 13 + 3 * 26 * 13), [r3.battle, r3.gains])
	# 攻击引路人 765（30 层）
	var s3 := _fresh(2303)
	var r4 := _win(s3, 765)
	check("yinlu_30", int(r4.battle.standInFloor) == 30 and r4.gains.values().all(func(g): return int(g) == 13 * 13 * 30), [r4.battle, r4.gains])
	# 正牌守层者照旧
	var s4 := _fresh(0)
	var r5 := _win(s4, 111)
	check("genuine_unchanged", int(r5.battle.guardianFloor) == 13 and int(r5.battle.standInFloor) == 0 and r5.gains.values().all(func(g): return int(g) == 2197), [r5.battle, r5.gains])
	check("genuine_no_mark", not s4.flags.has(XZhenqi.STAND_IN_MARK))


func _rollback() -> void:
	XZhenqi.STAND_IN_FIRSTS = false
	var s := _fresh(2307)
	s.set_variable(20, 14)  # 大厅里打：Boss 奖励按修行进度层（13）
	var r := _win(s, 798)
	check("off_floor_zero", int(r.battle.standInFloor) == 0, r.battle)
	check("off_boss_reward_only", r.gains.values().all(func(g): return int(g) == XZhenqi.boss_reward(13, 13)) and s.actor(1).zhenqi.firsts.is_empty(), r.gains)
	check("off_no_mark", not s.flags.has(XZhenqi.STAND_IN_MARK))
	var s2 := _fresh(2307)
	s2.set_variable(20, 31)
	check("off_no_backfill", XZhenqi.backfill_stand_in(s2).is_empty() and not s2.flags.has(XZhenqi.STAND_IN_MARK))
	XZhenqi.STAND_IN_FIRSTS = true


func _backfill() -> void:
	var s := _fresh(2307)
	s.set_variable(20, 21)  # 进度层 20：补 13～20
	s.actor(8).zhenqi = XZhenqi.from_save({"qi": 100, "firsts": {"primordial:13": 1}})
	var per := 0
	for f in range(13, 21):
		per += 10 * f * 13
	var before := {}
	for a in s.members():
		before[a.actor_id] = int(XZhenqi.data(a).qi)
	XZhenqi._pending_notice.clear()
	var out := XZhenqi.backfill_stand_in(s)
	check("backfill_party_size", out.size() == s.party.size() and s.party.size() == 4, [out, s.party])
	check("backfill_amount", int(out.get(1, 0)) == per and int(out.get(8, 0)) == per - 1690, [out, per])
	check("backfill_qi_added", int(s.actor(1).zhenqi.qi) == before[1] + per and int(s.actor(8).zhenqi.qi) == 100 + per - 1690)
	check("backfill_firsts", s.actor(9).zhenqi.firsts.has("primordial:20") and not s.actor(9).zhenqi.firsts.has("primordial:21") and not s.actor(9).zhenqi.firsts.has("primordial:12"))
	check("backfill_mark", bool(s.flags.get(XZhenqi.STAND_IN_MARK, false)))
	check("backfill_notice", XZhenqi._pending_notice.size() == 1 and str(XZhenqi._pending_notice[0]).contains("第13～20层"), XZhenqi._pending_notice)
	check("backfill_once", XZhenqi.backfill_stand_in(s).is_empty() and int(s.actor(1).zhenqi.qi) == before[1] + per)
	# 存读档后不再补
	var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("backfill_once_after_reload", XZhenqi.backfill_stand_in(s2).is_empty())
	# 上限 30 层
	var s3 := _fresh(2302)
	s3.set_variable(20, 34)
	var o3 := XZhenqi.backfill_stand_in(s3)
	check("backfill_cap_30", int(o3.get(1, 0)) == 130 * 387 and s3.actor(1).zhenqi.firsts.has("primordial:30") and not s3.actor(1).zhenqi.firsts.has("primordial:31"), o3)
	# 没过 13 层：不补、不打标记；求道者雕像档：不补
	var s4 := _fresh(2307)
	s4.set_variable(20, 13)
	check("backfill_below_13", XZhenqi.backfill_stand_in(s4).is_empty() and not s4.flags.has(XZhenqi.STAND_IN_MARK))
	var s5 := _fresh(0)
	s5.set_variable(20, 31)
	check("backfill_qiudao_none", XZhenqi.backfill_stand_in(s5).is_empty() and not s5.flags.has(XZhenqi.STAND_IN_MARK))
	# 普通路线系数 1
	var s6 := XState.new_game(3, 1, [8, 9, 10])
	s6.set_switch(2303, true)
	s6.set_variable(20, 14)
	check("backfill_normal_route", int(XZhenqi.backfill_stand_in(s6).get(1, 0)) == 130 and s6.actor(1).zhenqi.firsts.has("normal:13"))


func _tianqi() -> void:
	var s := _fresh(2307)
	s.flags["tianqi"] = {"rules": 1}
	s.set_variable(20, 31)
	check("tianqi_no_backfill", XZhenqi.backfill_stand_in(s).is_empty() and not s.flags.has(XZhenqi.STAND_IN_MARK))
	XZhenqi.battle_setup(s, 798)
	check("tianqi_no_stand_in", int(XZhenqi.battle.standInFloor) == 0 and not s.flags.has(XZhenqi.STAND_IN_MARK), XZhenqi.battle)
	XZhenqi.battle = {}


func _run() -> void:
	_table_matches_maps()
	_live()
	_rollback()
	_backfill()
	_tianqi()
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_zhenqi_standin", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)
