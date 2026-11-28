extends Node
## T584 角色加状态后生命不夹上限（XBattler.TQ_ADD_CLAMP，O-689）回归专项。
## 来源：虚拟玩家 climb（T533 R2，种子 1）报「生命高于上限 角色 162 [22690, 9062]」。根因：原版 _Fix_StackOverflow 在 addState
## 期间吞掉 Game_Battler.refresh，诛仙 162 舍身剑·燃血 10458 收尾给自己挂 2720（生命上限×0.01）时生命不夹。
## 1) 天启篇开关开：直接加 2720、真放 10458，两条路之后生命都不高于上限；2720 到期仍扣满血倒下（原效果不变）；
## 2) 天启篇开关关：照原版生命高于上限（证明专项能咬住）；
## 3) 西游档：开关开／关两支生命、上限逐项相等，且都照原版高于上限（西游档零改动）。
## 4) R1（小o P2-1）：天启篇 162 穿百厄成锦（天衣 1）醒着，满血吃 77 黝石重踏（生命上限×0.8）——收录后当场去掉，
##    开关开／关生命都应保持满血（修前开关开会按临时上限扣 20%）。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


## 新开一局（tianqi 时挂天启篇规则），把 162 拉进队伍、开一场 Troop 2，返回 [logic, 162 的战斗者]
func _setup(tianqi: bool) -> Array:
	XEnemy.force_roll = 100.0
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "lianyu", [8, 162])   # 炼狱：可上 2 个超强者
		XTianqi.take_pending()
		XState.current = s
		for id in [8, 162]:
			s.actor(id)
		s.party.assign([8, 162])
		s.battle_slots.assign([8, 162, 0, 0, 0])
	else:
		s = XState.new_game(1, 8, [])
		s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)   # 西游档超强者入队开关
		s.add_actor(162)
	s.random_master = XRandomStream.hex64(584)
	s.actor(162).change_level(25)
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var found: Array = logic.actors.filter(func(x): return x.actor_id == 162)
	return [logic, found[0] if not found.is_empty() else null]


## way＝"add"：满血直接加 2720；"skill"：满血真放 10458（forcing，打 1 号敌人）
func _case(tianqi: bool, sw: bool, way: String) -> Dictionary:
	XBattler.TQ_ADD_CLAMP = sw
	var pair := _setup(tianqi)
	var logic: XBattleLogic = pair[0]
	var a: XBattler = pair[1]
	if a == null:
		return {"ok": false}
	a.hp = a.mhp
	a.mp = a.mmp
	var full := a.hp
	if way == "add":
		a.add_state(2720)
	else:
		logic.execute(a, XDB.rec("Skills", 10458), logic.enemies[0], true)
	var out := {"ok": true, "full": full, "hp": a.hp, "mhp": a.mhp, "mp": a.mp, "mmp": a.mmp, "has2720": a.state_ids.has(2720)}
	if tianqi and sw and way == "add":
		a.remove_state_auto(2720)   # 自然消失：gainHp(-mhp)，上限回来了照样扣满血
		out["dead_after_leave"] = a.is_dead()
	return out


## R1：162 穿百厄成锦并醒着，满血加 77（transfer_debuffs 里唯一降生命上限的减益，×0.8）
func _case_robe(sw: bool) -> Dictionary:
	XBattler.TQ_ADD_CLAMP = sw
	var s := XTianqi.start_new_game(3, "lianyu", [8, 162])
	XTianqi.take_pending()
	XState.current = s
	for id in [8, 162]:
		s.actor(id)
	s.party.assign([8, 162])
	s.battle_slots.assign([8, 162, 0, 0, 0])
	s.random_master = XRandomStream.hex64(584)
	var actor := s.actor(162)
	actor.change_level(55)   # 天衣要 55 级才能穿
	s.gain_gear("armor", XYunshang.ROBE_FIRST + 1, 1)
	var worn := XEquipment.change(s, actor, actor.equip_slots().find(4), s.gear[s.gear.size() - 1])
	XEnemy.force_roll = 100.0
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var found: Array = logic.actors.filter(func(x): return x.actor_id == 162)
	if found.is_empty():
		return {"ok": false, "why": "no162"}
	var a: XBattler = found[0]
	if XYunshang.key(a) != 1 or XYunshang.battle == 0:
		return {"ok": false, "why": "robe", "worn": worn, "key": XYunshang.key(a), "battle": XYunshang.battle}
	XYunshang.data(a).wake_until = XYunshang.round + 1   # 醒着：收录后当场去掉
	a.hp = a.mhp
	a.mp = a.mmp
	var full := a.hp
	var full_m := a.mhp
	a.add_state(77)
	var cap: Array = XYunshang.data(a).captured
	return {"ok": true, "full": full, "full_mhp": full_m, "hp": a.hp, "mhp": a.mhp, "has77": a.state_ids.has(77),
		"captured": cap.map(func(x): return [int(x.id), bool(x.cleaned)])}


func _run() -> void:
	var was := XBattler.TQ_ADD_CLAMP
	for way in ["add", "skill"]:
		var on := _case(true, true, way)
		check("tq.on.%s.ready" % way, on.ok and on.has2720, on)
		check("tq.on.%s.hp_le_mhp" % way, on.ok and on.hp <= on.mhp and on.hp > 0.0, on)
		check("tq.on.%s.mp_le_mmp" % way, on.ok and on.mp <= on.mmp, on)
		if way == "add":
			check("tq.on.add.leave_still_kills", on.ok and bool(on.get("dead_after_leave", false)), on)
		var off := _case(true, false, way)
		check("tq.off.%s.original_over" % way, off.ok and off.has2720 and off.hp > off.mhp, off)
		var xon := _case(false, true, way)
		var xoff := _case(false, false, way)
		print("T584|%s tq_on=%s tq_off=%s xiyou_on=%s" % [way, on, off, xon])
		check("xiyou.%s.ready" % way, xon.ok and xon.has2720 and xoff.ok, [xon, xoff])
		check("xiyou.%s.on_equals_off" % way, xon == xoff, [xon, xoff])
		check("xiyou.%s.original_over" % way, xon.ok and xon.hp > xon.mhp, xon)
	var r_on := _case_robe(true)
	var r_off := _case_robe(false)
	print("T584|robe on=%s off=%s" % [r_on, r_off])
	check("robe.ready", r_on.ok and r_off.ok and not r_on.has77 and r_on.captured == [[77, true]], [r_on, r_off])
	check("robe.on.full_hp_kept", r_on.ok and r_on.hp == r_on.full and r_on.mhp == r_on.full_mhp, r_on)
	check("robe.off.full_hp_kept", r_off.ok and r_off.hp == r_off.full and r_off.mhp == r_off.full_mhp, r_off)   # 两次开局天衣实例不同，上限不逐项比
	XBattler.TQ_ADD_CLAMP = was
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit.call_deferred(0)
