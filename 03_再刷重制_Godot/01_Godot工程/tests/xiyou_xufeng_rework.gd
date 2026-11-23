extends Node
## 【小A·未经审查】T440 西游档徐凤年（152）数值重做专项（XXufeng，D272，Kyo 11-23 定案）：
## 1) 重做生效：9985/9987~9994/9997/9998、表外状态 19501、西游档 2539 副本、法宝 143、绣冬 76、春雷 129 数值与卡面文字 100% 一致；
## 2) 全部原版机制保留（大黄庭、大帝转世、剑一～剑八、剑九、九阶基因锁、天下第一、剑气滚龙壁·封印、真·剑九、紫炎 2301、公共状态 2525 不串 9984/10512）；
## 3) REWORK = false 与 XCanglong.original_data() 彻底还原原版数据与缓存；
## 4) 天启篇徐凤年（T411）零影响证明；
## 5) 西游档五回合木桩（Troop 70，熟练 32，全暴击，5 种子）：50/70（主口径）/75/80 级全部稳落 1.15～1.25× 狂刀，且 9998 不随目标血量膨胀。
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


func _run() -> void:
	var was_rel_cl := XImportedBalance.RELEASE_CANGLONG
	var was_rel_xf := XImportedBalance.RELEASE_XUFENG
	var was_cl := XCanglong.REWORK
	var was_xf := XXufeng.REWORK
	var was_p4 := XTianqiBase.PHASE4
	XMessageBox.auto = true
	XImportedBalance.RELEASE_CANGLONG = true
	XImportedBalance.RELEASE_XUFENG = true
	XCanglong.REWORK = true
	XCanglong.clear_cache()
	XXufeng.REWORK = true
	XXufeng.clear_cache()

	_check_rework_data_and_text()
	_check_revert_and_original_data()
	_check_tianqi_untouched()
	_check_dummy_tiers()

	XImportedBalance.RELEASE_CANGLONG = was_rel_cl
	XImportedBalance.RELEASE_XUFENG = was_rel_xf
	XCanglong.REWORK = was_cl
	XCanglong.clear_cache()
	XXufeng.REWORK = was_xf
	XXufeng.clear_cache()
	XTianqiBase.PHASE4 = was_p4
	XStateEffects.force_critical = false
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _make_xiyou_state(lv: int) -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261123)
	s.set_switch(2494, true)
	XState.current = s
	s.add_actor(152)
	for i in 5:
		s.set_battle_slot(i, 152 if i == 0 else 0)
	var a: XActor = s.actor(152)
	a.change_level(lv)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


func _check_rework_data_and_text() -> void:
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)

	# 1) 9985 大黄庭 & 9986 大帝转世（保留）
	var sk9985 := XDB.rec("Skills", 9985)
	check("9985.data_text", str(sk9985.meta.get("passivePBST2", "")) == "100%"
		and str(sk9985.note).contains("<passivePBST2:100%>")
		and str(sk9985.note).contains("物理攻击增加100%"), sk9985.meta)
	var sk9986 := XDB.rec("Skills", 9986)
	check("9986.kept", str(sk9986.meta.get("passiveIRUP", "")).strip_edges() == "300")

	# 2) 9987～9994 剑一～剑八：保留全部 StartPushState、均匀调低物理/寒冰伤、穿抗与固定伤、卡面吻合
	var el_sum := 0
	var de_sum := 0
	for sid in range(9987, 9995):
		var sk := XDB.rec("Skills", sid)
		var cfg: Array = XXufeng.SWORDS[sid]
		var st_key := "StartPushState%d" % (2530 + (sid - 9987))
		var note := str(sk.note)
		el_sum += int(cfg[0])
		de_sum += int(cfg[1])
		check("sword.%d" % sid,
			sk.meta.has(st_key)
			and str(sk.meta.get("passiveELUP01", "")).strip_edges() == "%d%%" % cfg[0]
			and str(sk.meta.get("passiveELUP03", "")).strip_edges() == "%d%%" % cfg[0]
			and str(sk.meta.get("DepassiveHarmRe01", "")).strip_edges() == "%d%%" % cfg[1]
			and str(sk.meta.get("DepassiveHarmRe03", "")).strip_edges() == "%d%%" % cfg[1]
			and str(sk.damage.formula) == str(cfg[2])
			and note.contains("伤害:%d " % cfg[2])
			and note.contains("物理/寒冰伤害+%d%% 无视敌人物理/寒冰抗性+%d%%" % [cfg[0], cfg[1]]),
			[sid, sk.damage.formula, sk.meta.get("passiveELUP01"), sk.meta.get("DepassiveHarmRe01")])
	check("swords.sum", el_sum == 100 and de_sum == 30, [el_sum, de_sum])

	# 3) 9995 剑九 & 9996 九阶基因锁机制保留
	var sk9995 := XDB.rec("Skills", 9995)
	var sk9996 := XDB.rec("Skills", 9996)
	check("9995.kept", int(sk9995.stypeId) == 4 and int(sk9995.occasion) == 2 and sk9995.meta.has("StartPushState2538"))
	check("9996.kept", str(sk9996.meta.get("passiveSPBST9", "")).strip_edges() == "-100%")

	# 4) 9997 天下第一：西游档挂表外 19501，2525 原件与 9984/10512 不受影响，卡面文字吻合
	var sk9997 := XDB.rec("Skills", 9997)
	var n9997 := str(sk9997.note)
	check("9997.repoint_19501", sk9997.meta.has("StartPushState19501") and not sk9997.meta.has("StartPushState2525"), sk9997.meta.keys())
	check("9997.data_text",
		str(sk9997.meta.get("passiveHarmRi", "")) == "1"
		and str(sk9997.meta.get("passiveCrHarmRi", "")) == "1"
		and str(sk9997.meta.get("passiveELUP01", "")) == "1%"
		and str(sk9997.meta.get("DepassiveHarmRe01", "")).strip_edges() == "10%"
		and str(sk9997.meta.get("passivePBST2", "")) == "1%"
		and str(sk9997.meta.get("passiveAPLUS", "")) == "1%"
		and n9997.contains("你有1%的几率再次行动")
		and (n9997.contains("爆伤+1%，终伤+1%") or n9997.contains("爆伤+1%，伤害+1%"))
		and n9997.contains("所有伤害+1%")
		and n9997.contains("暴击率+50%") and n9997.contains("命中率+50%")
		and n9997.contains("所有属性+1%")
		and n9997.contains("最大魔法值+10000 +50%")
		and n9997.contains("最大生命值+20000 +50%")
		and n9997.contains("无视敌人所有抵抗10%"),
		n9997)
	var st19501 := XDB.rec("States", XXufeng.ST_TIANXIA)
	var st2525 := XDB.rec("States", 2525)
	check("st19501_and_2525_intact",
		int(st19501.get("id", 0)) == XXufeng.ST_TIANXIA
		and is_equal_approx(float(st19501.effects[0].groups[0].steps[0].k), 0.01)
		and is_equal_approx(float(st19501.effects[0].groups[0].steps[1].k), 0.01)
		and is_equal_approx(float(st2525.effects[0].groups[0].steps[0].k), 0.7)
		and XDB.rec("Skills", 9984).meta.has("StartPushState2525")
		and XDB.rec("Skills", 10512).meta.has("StartPushState2525"),
		[st19501.get("id"), st2525.effects[0].groups[0].steps[0].k])

	# 5) 9998 剑气滚龙壁·封印 & State 2539 真·剑九（西游档 rec 返回 2.0，table 原件保留 5.0）
	var sk9998 := XDB.rec("Skills", 9998)
	var n9998 := str(sk9998.note)
	check("9998.formula_text",
		str(sk9998.damage.formula) == "(666666+a.atk*209000)*(1+user.skillMasteryLevel(item.id))"
		and not str(sk9998.damage.formula).contains("b.hp")
		and XSmartAI.formula_safe(str(sk9998.damage.formula))
		and sk9998.meta.has("StartPushState2539")
		and int(sk9998.yepEffects) == 5
		and n9998.contains("[666666+己·攻击力*209000]*[1+技能等级]")
		and n9998.contains("消耗10tp"),
		[sk9998.damage.formula, n9998])
	var st2539_xy := XDB.rec("States", 2539)
	var st2539_tbl: Dictionary = XDB.table("States")[2539]
	check("st2539.xy_and_table",
		is_equal_approx(float(st2539_xy.effects[0].groups[0].steps[0].k), 2.0)
		and is_equal_approx(float(st2539_tbl.effects[0].groups[0].steps[0].k), 5.0),
		[st2539_xy.effects[0].groups[0].steps[0].k, st2539_tbl.effects[0].groups[0].steps[0].k])
	# 9998 伤害不受目标血量膨胀影响
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	var foe: XEnemy = logic.enemies[0]
	foe.param_refresh()
	foe.recover_all()
	var dmg_big := XDamage.eval_formula(sk9998, a, foe, [])
	foe.hp = 1000.0
	var dmg_small := XDamage.eval_formula(sk9998, a, foe, [])
	check("9998.no_bhp_scaling", dmg_big > 0.0 and is_equal_approx(dmg_big, dmg_small), [dmg_big, dmg_small])
	# 80 级开战挂 19501 + 2539 + 2530..2538，不挂 2525
	check("battle.states_80", a.is_state_affected(XXufeng.ST_TIANXIA) and a.is_state_affected(2539)
		and a.is_state_affected(2530) and a.is_state_affected(2538) and not a.is_state_affected(2525), a.state_ids)
	logic.end_battle(0)

	# 6) 专属装备：Armor 143、Weapon 76 绣冬、Armor 129 春雷
	var a143 := XDB.rec("Armors", 143)
	var n143 := str(a143.note)
	check("armor143.data_text",
		(a143.traits as Array).size() == 11
		and n143.contains("<atk Param +12 per Level>")
		and n143.contains("<mmp Param +30 per Level>")
		and n143.contains("魔法*200%")
		and n143.contains("法宝每级增加12全属性魔法额外+18")
		and n143.contains("暴击率+100% 再动+1"),
		n143)
	var w76 := XDB.rec("Weapons", 76)
	var n76 := str(w76.note)
	check("weapon76.data_text",
		w76.meta.has("StartPushState2301")
		and str(w76.meta.get("passiveHarmRi", "")) == "125"
		and str(w76.meta.get("passiveCrHarmRi", "")) == "125"
		and str(w76.meta.get("Element Amplify 1", "")).strip_edges() == "+195%"
		and is_equal_approx(float(w76.customParams.params[2].level), 6.0)
		and n76.contains("造成所有伤害结果*350%")
		and n76.contains("混沌伤+195%")
		and n76.contains("攻击力能力值*150%，爆伤与伤害+125%")
		and n76.contains("每级+6)"),
		n76)
	var a129 := XDB.rec("Armors", 129)
	var n129 := str(a129.note)
	var a129_aplus := (a129.traits as Array).filter(func(tr): return int(tr.code) == 61).size()
	check("armor129.data_text",
		a129_aplus == 1
		and a129.meta.has("StartPushState2301")
		and str(a129.meta.get("passiveHarmRi", "")) == "125"
		and str(a129.meta.get("Element Amplify 1", "")).strip_edges() == "+195%"
		and n129.contains("等级需求:75 ")
		and n129.contains("再动+1 ")
		and n129.contains("混沌伤+195%")
		and n129.contains("攻击力能力值*150%，爆伤与伤害+125%"),
		n129)


func _check_revert_and_original_data() -> void:
	var s := _make_xiyou_state(80)
	XState.current = s
	XXufeng.original_data()
	check("off.flag", not XXufeng.on())
	check("off.9998", str(XDB.rec("Skills", 9998).damage.formula).contains("b.hp*0.000015"))
	check("off.9985", str(XDB.rec("Skills", 9985).meta.get("passivePBST2", "")) == "150%")
	check("off.9997", XDB.rec("Skills", 9997).meta.has("StartPushState2525") and str(XDB.rec("Skills", 9997).meta.get("passiveHarmRi", "")) == "200")
	check("off.st19501_empty", XDB.rec("States", XXufeng.ST_TIANXIA).is_empty())
	check("off.st2539_orig", is_equal_approx(float(XDB.rec("States", 2539).effects[0].groups[0].steps[0].k), 5.0))
	check("off.weapon76_orig", str(XDB.rec("Weapons", 76).meta.get("passiveHarmRi", "")) == "450"
		and is_equal_approx(float(XDB.rec("Weapons", 76).customParams.params[2].level), 10.0))
	check("off.armor143_orig", str(XDB.rec("Armors", 143).note).contains("<atk Param +15 per Level>"))

	# XCanglong.original_data() 一并关闭 XXufeng
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	XCanglong.original_data()
	check("canglong_original_data_turns_off_xufeng", not XXufeng.REWORK)
	# 恢复
	XImportedBalance.RELEASE_CANGLONG = true
	XImportedBalance.RELEASE_XUFENG = true
	XCanglong.REWORK = true
	XCanglong.clear_cache()
	XXufeng.REWORK = true
	XXufeng.clear_cache()


func _check_tianqi_untouched() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiSkills.reload_table()
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), 152, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [152]}
	s.random_master = XRandomStream.hex64(20261123)
	s.actor_max_level = 81
	XState.current = s
	if not s.party.has(152):
		XTianqi._joining = true
		s.add_actor(152)
		XTianqi._joining = false
	var a: XActor = s.actor(152)
	a.change_level_mv(81)
	a.param_mark_dirty()
	a.refresh_passive()

	var sk9998_on := XDB.rec("Skills", 9998)
	var sk9997_on := XDB.rec("Skills", 9997)
	var sk9995_on := XDB.rec("Skills", 9995)
	var st2530_on := XDB.rec("States", 2530)
	var g143_on: Dictionary = XTianqiSkills.gear_view(XGear.template("armor", 143))
	var g76_on: Dictionary = XTianqiSkills.gear_view(XGear.template("weapon", 76))
	check("tq.9998_ok", int(sk9998_on.tpCost) == 0 and int(sk9998_on.yepEffects) == 5 and not sk9998_on.meta.has("StartPushState2539"))
	check("tq.9997_no_2525_19501", not sk9997_on.meta.has("StartPushState2525") and not sk9997_on.meta.has("StartPushState19501")
		and str(sk9997_on.meta.get("passiveXPBST2", "")).strip_edges() == "10%")
	check("tq.9995_active", int(sk9995_on.stypeId) == 1 and int(sk9995_on.yepEffects) == 8)
	check("tq.2530_hit_extra", not (st2530_on.get("effects", []) as Array).is_empty())
	check("tq.gear_clean", (g143_on.traits as Array).is_empty()
		and (g76_on.traits as Array).filter(func(tr): return int(tr.code) in [21, 34]).is_empty()
		and not g76_on.meta.has("passiveHarmRi"))


func _check_dummy_tiers() -> void:
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	XStateEffects.force_critical = true
	var seeds := [1, 2, 3, 4, 5]
	for row in [
		["lv50", 50, 99, 0, 0],
		["lv70_main", 70, 99, 0, 0],
		["lv75_wpn", 75, 99, 2019, 76],
		["lv80_tianxia", 80, 99, 2019, 76],
	]:
		var tag: String = row[0]
		var lv: int = row[1]
		var art_lv: int = row[2]
		var kd_wpn: int = row[3]
		var xf_wpn: int = row[4]
		var kd_list := _bench_seeds(122, 4575, kd_wpn, lv, art_lv, 32, seeds)
		var xf_list := _bench_seeds(152, 143, xf_wpn, lv, art_lv, 32, seeds)
		var kd_m := _mean(kd_list)
		var xf_m := _mean(xf_list)
		var ratio := xf_m / maxf(1e-9, kd_m)
		check("dummy.%s.ratio" % tag, ratio >= 1.15 and ratio <= 1.25,
			{"kd_T": snappedf(kd_m, 0.01), "xf_T": snappedf(xf_m, 0.01), "ratio": snappedf(ratio, 0.0001)})
	XStateEffects.force_critical = false


func _mean(arr: Array) -> float:
	var s := 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())


func _bench_seeds(aid: int, art_id: int, wpn_id: int, lv: int, art_lv: int, mastery: int, seeds: Array) -> Array:
	var out := []
	for sd in seeds:
		var s := XState.new_game_blank()
		s.random_master = XRandomStream.hex64(1000003 + aid * 7919 + int(sd))
		s.set_switch(2494, true)
		XState.current = s
		s.add_actor(aid)
		for i in 5:
			s.set_battle_slot(i, aid if i == 0 else 0)
		var a: XActor = s.actor(aid)
		a.change_level(lv)
		if art_id > 0:
			var art: Dictionary = a.make_equip("armor", art_id)
			art["level"] = art_lv
			for i in a.equip_slots().size():
				if int(a.equip_slots()[i]) == int(art.etypeId):
					a.equips[i] = art
					break
		if wpn_id > 0:
			a.equips[0] = a.make_equip("weapon", wpn_id)
		a.param_mark_dirty()
		a.refresh_passive()
		for sid in a.skill_ids:
			a.mastery_levels[sid] = mastery
		a.recover_all()

		var logic := XBattleLogic.new()
		var rng := XBattleRandom.create(str(s.random_master))
		logic.setup(70, s, rng)
		var foe: XEnemy = logic.enemies[0]
		foe.param_refresh()
		foe.recover_all()

		var total_dmg := 0.0
		for _t in 5:
			logic.start_turn()
			var n_act := 1
			for p in a.action_plus_set():
				if rng.rule_now().next_float("action_plus") < float(p):
					n_act += 1
			for _k in n_act:
				if not logic.can_move(a):
					continue
				a.mp = a.mmp
				a.tp = 100.0
				var sk = null
				if aid == 122:
					for cand in [6039, 6028, 6026, 6025, 6024]:
						if a.skill_ids.has(cand) and logic.can_use(a, XDB.rec("Skills", cand)):
							sk = XDB.rec("Skills", cand)
							break
				else:
					var pick := XSmartAI.choose(logic, a)
					sk = pick.get("skill")
				if sk == null:
					continue
				var logs: Array = logic.act(a, sk, foe)
				for e in logs:
					if e is Dictionary and str(e.get("type", "")) == "hit" and is_same(e.get("target"), foe):
						total_dmg += maxf(0.0, float(e.get("hp", 0.0)))
				foe.hp = foe.mhp
			logic.end_turn()
		out.append(total_dmg / 1.0e12)
		logic.end_battle(0)
	return out
