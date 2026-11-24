extends Node
## 【小A·未经审查】T440 西游档徐凤年（152）数值重做专项（XXufeng，D272，Kyo 11-23 定案＋R1 返修）：
## 1) 重做生效：9985/9987~9994/9997/9998、表外状态 19501、西游档 2539 副本、法宝 143、绣冬 76、春雷 129 数值与卡面文字 100% 一致；
## 2) 全部原版机制保留（大黄庭、大帝转世、剑一～剑八、剑九、九阶基因锁、天下第一、剑气滚龙壁·封印、真·剑九、紫炎 2301、公共状态 2525 不串 9984/10512）；
## 3) REWORK = false 与 XCanglong.original_data() 彻底还原原版数据与缓存；
## 4) P1-1 回归：共享原表 XDB.table 不被修改；同进程西游档↔天启篇切换零串味，天启篇徐凤年属性/成长/记录与 REWORK=false 逐项相等，19501 天启篇不可读；
## 5) P1-2 回归：既有装备实例（76/129/143，含穿戴/背包/仓库/随机属性/强化/词缀/法宝等级经验）经 XSaveSlim.as_reloaded + XState.from_dict 双向切换 REWORK 同步且实打伤害对齐；
## 6) P2-1 回归：西游档五回合木桩（Troop 70，熟练 32，全暴击，5 种子）：50/70（主口径）/75(全套绣冬+春雷)/80(全套绣冬+春雷+天下第一) 全档稳落 1.15～1.25× 狂刀，单穿绣冬约 0.70～0.85×。
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
	_check_tianqi_untouched_and_switch()
	_check_save_reload_gear_sync()
	_check_r2_migrations()
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


func _make_tianqi_state(lv: int) -> XState:
	XTianqiBase.PHASE4 = true
	XTianqiSkills.reload_table()
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), 152, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [152]}
	s.random_master = XRandomStream.hex64(20261123)
	s.actor_max_level = lv
	XState.current = s
	if not s.party.has(152):
		XTianqi._joining = true
		s.add_actor(152)
		XTianqi._joining = false
	var a: XActor = s.actor(152)
	a.change_level_mv(lv)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


func _equip_in_slot(a: XActor, item: Dictionary) -> void:
	for i in a.equip_slots().size():
		if int(a.equip_slots()[i]) == int(item.etypeId):
			a.equips[i] = item
			return


func _check_rework_data_and_text() -> void:
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)

	# 0) 共享原表 XDB.table 不受任何就地改动（P1-1）
	var raw_w76: Dictionary = XDB.table("Weapons")[76]
	var raw_a129: Dictionary = XDB.table("Armors")[129]
	var raw_a143: Dictionary = XDB.table("Armors")[143]
	var raw_sk9987: Dictionary = XDB.table("Skills")[9987]
	var raw_sk9998: Dictionary = XDB.table("Skills")[9998]
	var raw_st2539: Dictionary = XDB.table("States")[2539]
	check("table_pure_original",
		is_equal_approx(float(raw_w76.customParams.params[2].level), 10.0)
		and str(raw_w76.meta.get("passiveHarmRi", "")) == "450"
		and str(raw_w76.note).contains("造成所有伤害结果*350%")
		and str(raw_a129.meta.get("passiveHarmRi", "")) == "450"
		and str(raw_a143.note).contains("<atk Param +15 per Level>")
		and str(raw_sk9987.damage.formula) == "5000000"
		and str(raw_sk9998.damage.formula).contains("b.hp*0.000015")
		and is_equal_approx(float(raw_st2539.effects[0].groups[0].steps[0].k), 5.0),
		[raw_w76.customParams.params[2].level, raw_sk9987.damage.formula])

	# 1) 9985 大黄庭 & 9986 大帝转世（保留）
	var sk9985 := XDB.rec("Skills", 9985)
	check("9985.data_text", str(sk9985.meta.get("passivePBST2", "")) == "100%"
		and str(sk9985.note).contains("<passivePBST2:100%>")
		and str(sk9985.note).contains("物理攻击增加100%"), sk9985.meta)
	var sk9986 := XDB.rec("Skills", 9986)
	check("9986.kept", str(sk9986.meta.get("passiveIRUP", "")).strip_edges() == "300")

	# 2) 9987～9994 剑一～剑八
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

	# 4) 9997 天下第一：西游档挂表外 19501，2525 原件与 9984/10512 不受影响
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

	# 5) 9998 剑气滚龙壁·封印 & State 2539 真·剑九
	var sk9998 := XDB.rec("Skills", 9998)
	var n9998 := str(sk9998.note)
	check("9998.formula_text",
		str(sk9998.damage.formula) == "(%d+a.atk*%d)*(1+user.skillMasteryLevel(item.id))" % [XXufeng.GUNLONG_BASE, XXufeng.GUNLONG_ATK_MUL]
		and not str(sk9998.damage.formula).contains("b.hp")
		and XSmartAI.formula_safe(str(sk9998.damage.formula))
		and sk9998.meta.has("StartPushState2539")
		and int(sk9998.yepEffects) == 5
		and n9998.contains("[%d+己·攻击力*%d]*[1+技能等级]" % [XXufeng.GUNLONG_BASE, XXufeng.GUNLONG_ATK_MUL])
		and n9998.contains("消耗10tp"),
		[sk9998.damage.formula, n9998])
	var st2539_xy := XDB.rec("States", 2539)
	check("st2539.xy_and_table",
		is_equal_approx(float(st2539_xy.effects[0].groups[0].steps[0].k), float(XXufeng.ST2539_RATE))
		and is_equal_approx(float(raw_st2539.effects[0].groups[0].steps[0].k), 5.0),
		[st2539_xy.effects[0].groups[0].steps[0].k, raw_st2539.effects[0].groups[0].steps[0].k])
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
	check("battle.states_80", a.is_state_affected(XXufeng.ST_TIANXIA) and a.is_state_affected(2539)
		and a.is_state_affected(2530) and a.is_state_affected(2538) and not a.is_state_affected(2525), a.state_ids)
	logic.end_battle(0)

	# 6) 专属装备：Armor 143、Weapon 76 绣冬、Armor 129 春雷（含文字审 P2-1 *249% 与 P3 统一措辞）
	var a143 := XDB.rec("Armors", 143)
	var n143 := str(a143.note)
	check("armor143.data_text",
		(a143.traits as Array).size() == 11
		and n143.contains("<atk Param +%d per Level>" % XXufeng.FABAO_GROW_ALL)
		and n143.contains("<mmp Param +%d per Level>" % (XXufeng.FABAO_GROW_ALL + XXufeng.FABAO_GROW_MMP_EXTRA))
		and n143.contains("魔法*%d%%" % XXufeng.FABAO_MMP_PCT)
		and n143.contains("法宝每级增加%d全属性魔法额外+%d" % [XXufeng.FABAO_GROW_ALL, XXufeng.FABAO_GROW_MMP_EXTRA])
		and n143.contains("暴击率+%d%% 再动+1" % XXufeng.FABAO_CRIT_PCT),
		n143)
	var w76 := XDB.rec("Weapons", 76)
	var n76 := str(w76.note)
	check("weapon76.data_text",
		w76.meta.has("StartPushState2301")
		and str(w76.meta.get("passiveHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and str(w76.meta.get("passiveCrHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and str(w76.meta.get("Element Amplify 1", "")).strip_edges() == "+%d%%" % XXufeng.XIUDONG_EL_AMP
		and is_equal_approx(float(w76.yep.elementAmplify["1"]), float(XXufeng.XIUDONG_EL_AMP) / 100.0)
		and is_equal_approx(float(w76.customParams.params[2].level), float(XXufeng.XIUDONG_GROW))
		and n76.contains("造成所有伤害结果*249%")
		and n76.contains("混沌伤+%d%%" % XXufeng.XIUDONG_EL_AMP)
		and n76.contains("攻击力能力值*%d%%，爆伤+%d%%，伤害+%d%%" % [XXufeng.XIUDONG_ATK_PCT, XXufeng.XIUDONG_HARM, XXufeng.XIUDONG_HARM])
		and n76.contains("每级+%d)" % XXufeng.XIUDONG_GROW),
		n76)
	var a129 := XDB.rec("Armors", 129)
	var n129 := str(a129.note)
	var a129_aplus := (a129.traits as Array).filter(func(tr): return int(tr.code) == 61).size()
	check("armor129.data_text",
		a129_aplus == 1
		and a129.meta.has("StartPushState2301")
		and str(a129.meta.get("passiveHarmRi", "")) == str(XXufeng.CHUNLEI_HARM)
		and str(a129.meta.get("passiveCrHarmRi", "")) == str(XXufeng.CHUNLEI_HARM)
		and str(a129.meta.get("Element Amplify 1", "")).strip_edges() == "+%d%%" % XXufeng.CHUNLEI_EL_AMP
		and is_equal_approx(float(a129.yep.elementAmplify["1"]), float(XXufeng.CHUNLEI_EL_AMP) / 100.0)
		and is_equal_approx(float(a129.customParams.params[2].level), float(XXufeng.CHUNLEI_ATK_GROW))
		and is_equal_approx(float(a129.customParams.params[0].level), 200.0)
		and is_equal_approx(float(a129.customParams.params[1].level), 150.0)
		and is_equal_approx(float(a129.customParams.params[6].level), 25.0)
		and n129.contains("等级需求:75 ")
		and n129.contains("造成所有伤害结果*249%")
		and n129.contains("再动+1 ")
		and n129.contains("混沌伤+%d%%" % XXufeng.CHUNLEI_EL_AMP)
		and n129.contains("攻击力能力值*%d%%，爆伤+%d%%，伤害+%d%%" % [XXufeng.CHUNLEI_ATK_PCT, XXufeng.CHUNLEI_HARM, XXufeng.CHUNLEI_HARM]),
		n129)
	# 装备检索面板（XGearQuery）：重做生效时绣冬/春雷基础特性均判定为「固定」，不会误判成「随机 / 附加」
	var q_w76: Dictionary = XGearQuery.record(XGear.template("weapon", 76))
	var q_a129: Dictionary = XGearQuery.record(XGear.template("armor", 129))
	check("gear_query.base_lines_fixed",
		not (q_w76.rows as Array).is_empty()
		and (q_w76.rows as Array).all(func(r): return str(r.source) == "固定")
		and not (q_a129.rows as Array).is_empty()
		and (q_a129.rows as Array).all(func(r): return str(r.source) == "固定"),
		[q_w76.rows, q_a129.rows])


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
		and is_equal_approx(float(XDB.rec("Weapons", 76).customParams.params[2].level), 10.0)
		and str(XDB.rec("Weapons", 76).note).contains("造成所有伤害结果*350%"))
	check("off.armor129_orig", str(XDB.rec("Armors", 129).meta.get("passiveHarmRi", "")) == "450"
		and is_equal_approx(float(XDB.rec("Armors", 129).customParams.params[2].level), 30.0))
	check("off.armor143_orig", str(XDB.rec("Armors", 143).note).contains("<atk Param +15 per Level>"))

	# XCanglong.original_data() 一并关闭 XXufeng
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	XCanglong.original_data()
	check("canglong_original_data_turns_off_xufeng", not XXufeng.REWORK)
	XImportedBalance.RELEASE_CANGLONG = true
	XImportedBalance.RELEASE_XUFENG = true
	XCanglong.REWORK = true
	XCanglong.clear_cache()
	XXufeng.REWORK = true
	XXufeng.clear_cache()


## P1-1 回归：先预热西游档全部缓存，再同进程直接切天启篇（不手动清缓存），验证天启篇属性／成长／记录与 REWORK=false 逐项相等，且再切回西游档仍生效
func _check_tianqi_untouched_and_switch() -> void:
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	# 先跑西游档，灌满 _rec_cache / _custom_param_cache / _magic_growth_cache
	var s_xy := _make_xiyou_state(80)
	var a_xy: XActor = s_xy.actor(152)
	var xy_w76: Dictionary = a_xy.make_equip("weapon", 76)
	var xy_a129: Dictionary = a_xy.make_equip("armor", 129)
	var xy_a143: Dictionary = a_xy.make_equip("armor", 143)
	xy_a143["level"] = 99
	_equip_in_slot(a_xy, xy_w76)
	_equip_in_slot(a_xy, xy_a129)
	_equip_in_slot(a_xy, xy_a143)
	a_xy.param_mark_dirty()
	a_xy.refresh_passive()
	var xy_cp76 := a_xy.custom_param(xy_w76, 2)
	var xy_cp129 := a_xy.custom_param(xy_a129, 2)
	var xy_mg143 := XActor.magic_param(xy_a143, 2)
	check("p1_1.xy_warmed",
		is_equal_approx(xy_cp76, 80.0 * float(XXufeng.XIUDONG_GROW))
		and is_equal_approx(xy_cp129, 80.0 * float(XXufeng.CHUNLEI_ATK_GROW))
		and is_equal_approx(xy_mg143, 99.0 * float(XXufeng.FABAO_GROW_ALL)),
		[xy_cp76, xy_cp129, xy_mg143])

	# 同进程不手动清缓存，直接切到天启篇（REWORK = true）
	var s_tq_on := _make_tianqi_state(81)
	var a_tq_on: XActor = s_tq_on.actor(152)
	var tq_w76_on: Dictionary = XGear.template("weapon", 76)
	var tq_a129_on: Dictionary = XGear.template("armor", 129)
	var tq_a143_on: Dictionary = XGear.template("armor", 143)
	tq_a143_on["level"] = 99
	_equip_in_slot(a_tq_on, tq_w76_on)
	_equip_in_slot(a_tq_on, tq_a129_on)
	_equip_in_slot(a_tq_on, tq_a143_on)
	a_tq_on.param_mark_dirty()
	a_tq_on.refresh_passive()
	var tq_params_on := []
	for i in 8:
		tq_params_on.append(a_tq_on.param(i))
	var tq_cp76_on := a_tq_on.custom_param(tq_w76_on, 2)
	var tq_cp129_on := a_tq_on.custom_param(tq_a129_on, 2)
	var tq_st19501_on := XDB.rec("States", XXufeng.ST_TIANXIA)
	var tq_sk9987_on := XDB.rec("Skills", 9987)
	var tq_sk9998_on := XDB.rec("Skills", 9998)
	var tq_sk9997_on := XDB.rec("Skills", 9997)
	var tq_sk9995_on := XDB.rec("Skills", 9995)
	var tq_st2530_on := XDB.rec("States", 2530)

	# 关 REWORK 重建天启篇作为基线，逐项比对
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_tq_off := _make_tianqi_state(81)
	var a_tq_off: XActor = s_tq_off.actor(152)
	var tq_w76_off: Dictionary = XGear.template("weapon", 76)
	var tq_a129_off: Dictionary = XGear.template("armor", 129)
	var tq_a143_off: Dictionary = XGear.template("armor", 143)
	tq_a143_off["level"] = 99
	_equip_in_slot(a_tq_off, tq_w76_off)
	_equip_in_slot(a_tq_off, tq_a129_off)
	_equip_in_slot(a_tq_off, tq_a143_off)
	a_tq_off.param_mark_dirty()
	a_tq_off.refresh_passive()
	var tq_params_off := []
	for i in 8:
		tq_params_off.append(a_tq_off.param(i))
	var tq_cp76_off := a_tq_off.custom_param(tq_w76_off, 2)
	var tq_cp129_off := a_tq_off.custom_param(tq_a129_off, 2)
	var tq_sk9987_off := XDB.rec("Skills", 9987)

	check("p1_1.tq_params_exact_match", tq_params_on == tq_params_off, [tq_params_on, tq_params_off])
	check("p1_1.tq_custom_growth_exact",
		is_equal_approx(tq_cp76_on, 810.0) and is_equal_approx(tq_cp76_on, tq_cp76_off)
		and is_equal_approx(tq_cp129_on, 2430.0) and is_equal_approx(tq_cp129_on, tq_cp129_off),
		[tq_cp76_on, tq_cp76_off, tq_cp129_on, tq_cp129_off])
	check("p1_1.tq_19501_unreadable", tq_st19501_on.is_empty(), tq_st19501_on)
	check("p1_1.tq_9987_formula_exact", str(tq_sk9987_on.damage.formula) == str(tq_sk9987_off.damage.formula)
		and str(tq_sk9987_on.damage.formula) == "5000000", [tq_sk9987_on.damage.formula, tq_sk9987_off.damage.formula])
	check("tq.9998_ok", int(tq_sk9998_on.tpCost) == 0 and int(tq_sk9998_on.yepEffects) == 5 and not tq_sk9998_on.meta.has("StartPushState2539"))
	check("tq.9997_no_2525_19501", not tq_sk9997_on.meta.has("StartPushState2525") and not tq_sk9997_on.meta.has("StartPushState19501")
		and str(tq_sk9997_on.meta.get("passiveXPBST2", "")).strip_edges() == "10%")
	check("tq.9995_active", int(tq_sk9995_on.stypeId) == 1 and int(tq_sk9995_on.yepEffects) == 8)
	check("tq.2530_hit_extra", not (tq_st2530_on.get("effects", []) as Array).is_empty())
	var g143_on: Dictionary = XTianqiSkills.gear_view(tq_a143_on)
	var g76_on: Dictionary = XTianqiSkills.gear_view(tq_w76_on)
	check("tq.gear_clean", (g143_on.traits as Array).is_empty()
		and (g76_on.traits as Array).filter(func(tr): return int(tr.code) in [21, 34]).is_empty()
		and not g76_on.meta.has("passiveHarmRi"))

	# 同进程再切回西游档（不手动清缓存），验证重做依然生效
	XXufeng.REWORK = true
	XState.current = s_xy
	a_xy.param_mark_dirty()
	check("p1_1.switch_back_xy",
		is_equal_approx(a_xy.custom_param(xy_w76, 2), 80.0 * float(XXufeng.XIUDONG_GROW))
		and not XDB.rec("States", XXufeng.ST_TIANXIA).is_empty(),
		a_xy.custom_param(xy_w76, 2))


## P1-2 回归：既有专属装备实例（穿戴／背包／仓库）经 XSaveSlim.as_reloaded + XState.from_dict 双向切换 REWORK
func _check_save_reload_gear_sync() -> void:
	# 1) 在 REWORK=false 下生成旧档（穿戴 76+129+143，含随机浮动 params、强化、法宝等级经验、词缀，另放背包 76 与仓库 129）
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_old := _make_xiyou_state(80)
	var a_old: XActor = s_old.actor(152)
	var w76: Dictionary = XGear.template("weapon", 76)
	w76.params[2] = 222.0
	w76["upgrades"] = ["upg_atk_plus"]
	w76["boostCount"] = 1
	w76["upgradeSlots"] = 4
	w76["instanceId"] = "xg:9001"
	# 模拟词缀追加的 trait 与 note（保留词缀验证）
	var affix_trait := {"code": 22, "dataId": 0, "value": 0.15}
	w76.traits.append(affix_trait.duplicate(true))
	w76.note = str(w76.note) + "\n<customAffixMark:keep_me>"
	w76.meta["customAffixMark"] = "keep_me"
	var a129: Dictionary = XGear.template("armor", 129)
	a129.params[2] = 77.0
	a129["instanceId"] = "xg:9002"
	var a143: Dictionary = XGear.template("armor", 143)
	a143["level"] = 99
	a143["exp"] = 12345
	a143["instanceId"] = "xg:9003"
	_equip_in_slot(a_old, w76)
	_equip_in_slot(a_old, a129)
	_equip_in_slot(a_old, a143)
	# 背包与仓库里各放一件旧装备
	var bag_w76: Dictionary = XGear.template("weapon", 76)
	bag_w76.params[2] = 188.0
	bag_w76["instanceId"] = "xg:9004"
	s_old.gear.append(bag_w76)
	var wh_a129: Dictionary = XGear.template("armor", 129)
	wh_a129.params[2] = 66.0
	wh_a129["instanceId"] = "xg:9005"
	s_old.warehouses["999"] = {"title": "test", "maxCapacity": 99, "currentCapacity": 1, "rule": null, "lootBonus": true, "items": {"item": [], "weapon": [], "armor": [wh_a129], "keyItem": []}, "qtty": {"item": {}, "weapon": {}, "armor": {}, "keyItem": {}}}
	a_old.param_mark_dirty()
	a_old.refresh_passive()
	for sid in a_old.skill_ids:
		a_old.mastery_levels[sid] = 32
	a_old.recover_all()
	var dmg_old := _single_hit_9998(s_old)
	var slim_old: Dictionary = XSaveSlim.as_reloaded(s_old.to_dict())

	# 2) 开 REWORK=true 读旧档（orig → rework）
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s_rw := XState.from_dict(slim_old)
	var a_rw: XActor = s_rw.actor(152)
	var rw_w76: Dictionary = a_rw.equips[0]
	var rw_a129: Dictionary = a_rw.equips[1]
	var rw_a143: Dictionary = {}
	for e in a_rw.raw_equip_list():
		if int(e.get("base", e.get("id", 0))) == 143:
			rw_a143 = e
			break
	var rw_bag_w76: Dictionary = s_rw.gear[0]
	var rw_wh_a129: Dictionary = s_rw.warehouses["999"].items.armor[0]
	var rw_129_aplus := (rw_a129.traits as Array).filter(func(tr): return int(tr.code) == 61).size()
	check("p1_2.old_to_rw.w76",
		str(rw_w76.meta.get("passiveHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and str(rw_w76.meta.get("passiveCrHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and str(rw_w76.note).contains("造成所有伤害结果*249%")
		and is_equal_approx(float(rw_w76.customParams.params[2].level), float(XXufeng.XIUDONG_GROW))
		and is_equal_approx(float(rw_w76.params[2]), 222.0)
		and rw_w76.get("upgrades", []) == ["upg_atk_plus"]
		and int(rw_w76.get("boostCount", 0)) == 1
		and str(rw_w76.note).contains("<customAffixMark:keep_me>")
		and str(rw_w76.meta.get("customAffixMark", "")) == "keep_me"
		and (rw_w76.traits as Array).size() == 5,
		[rw_w76.meta.get("passiveHarmRi"), rw_w76.params[2], rw_w76.traits.size()])
	check("p1_2.old_to_rw.a129_a143_bag_wh",
		str(rw_a129.meta.get("passiveHarmRi", "")) == str(XXufeng.CHUNLEI_HARM)
		and rw_129_aplus == 1
		and is_equal_approx(float(rw_a129.params[2]), 77.0)
		and str(rw_a143.note).contains("<atk Param +%d per Level>" % XXufeng.FABAO_GROW_ALL)
		and int(rw_a143.get("level", 0)) == 99 and int(rw_a143.get("exp", 0)) == 12345
		and str(rw_bag_w76.meta.get("passiveHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and is_equal_approx(float(rw_bag_w76.params[2]), 188.0)
		and str(rw_wh_a129.meta.get("passiveHarmRi", "")) == str(XXufeng.CHUNLEI_HARM)
		and is_equal_approx(float(rw_wh_a129.params[2]), 66.0),
		[rw_a129.meta.get("passiveHarmRi"), rw_129_aplus, rw_bag_w76.meta.get("passiveHarmRi"), rw_wh_a129.meta.get("passiveHarmRi")])
	var dmg_rw_reloaded := _single_hit_9998(s_rw)
	# 与重做状态下新建同条件实例的实打伤害一致
	var s_fresh := _make_xiyou_state(80)
	var a_fresh: XActor = s_fresh.actor(152)
	var f_w76: Dictionary = XGear.template("weapon", 76)
	f_w76.params[2] = 222.0
	f_w76.traits.append(affix_trait.duplicate(true))
	f_w76.note = str(f_w76.note) + "\n<customAffixMark:keep_me>"
	f_w76.meta["customAffixMark"] = "keep_me"
	var f_a129: Dictionary = XGear.template("armor", 129)
	f_a129.params[2] = 77.0
	var f_a143: Dictionary = XGear.template("armor", 143)
	f_a143["level"] = 99
	_equip_in_slot(a_fresh, f_w76)
	_equip_in_slot(a_fresh, f_a129)
	_equip_in_slot(a_fresh, f_a143)
	a_fresh.param_mark_dirty()
	a_fresh.refresh_passive()
	for sid in a_fresh.skill_ids:
		a_fresh.mastery_levels[sid] = 32
	a_fresh.recover_all()
	var dmg_rw_fresh := _single_hit_9998(s_fresh)
	check("p1_2.old_to_rw.combat_dmg",
		dmg_rw_reloaded > 0.0 and is_equal_approx(dmg_rw_reloaded, dmg_rw_fresh) and dmg_rw_reloaded < dmg_old * 0.5,
		[dmg_old, dmg_rw_reloaded, dmg_rw_fresh])

	# 3) 关 REWORK=false 读重做档（rework → orig）
	var slim_rw: Dictionary = XSaveSlim.as_reloaded(s_rw.to_dict())
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_back := XState.from_dict(slim_rw)
	var a_back: XActor = s_back.actor(152)
	var bk_w76: Dictionary = a_back.equips[0]
	var bk_a129: Dictionary = a_back.equips[1]
	var bk_a143: Dictionary = {}
	for e in a_back.raw_equip_list():
		if int(e.get("base", e.get("id", 0))) == 143:
			bk_a143 = e
			break
	var bk_bag_w76: Dictionary = s_back.gear[0]
	var bk_wh_a129: Dictionary = s_back.warehouses["999"].items.armor[0]
	var bk_129_aplus := (bk_a129.traits as Array).filter(func(tr): return int(tr.code) == 61).size()
	check("p1_2.rw_to_old.w76",
		str(bk_w76.meta.get("passiveHarmRi", "")) == "450"
		and str(bk_w76.meta.get("passiveCrHarmRi", "")) == "450"
		and str(bk_w76.note).contains("造成所有伤害结果*350%")
		and is_equal_approx(float(bk_w76.customParams.params[2].level), 10.0)
		and is_equal_approx(float(bk_w76.params[2]), 222.0)
		and bk_w76.get("upgrades", []) == ["upg_atk_plus"]
		and int(bk_w76.get("boostCount", 0)) == 1
		and str(bk_w76.note).contains("<customAffixMark:keep_me>")
		and str(bk_w76.meta.get("customAffixMark", "")) == "keep_me"
		and (bk_w76.traits as Array).size() == 5,
		[bk_w76.meta.get("passiveHarmRi"), bk_w76.params[2], bk_w76.traits.size()])
	check("p1_2.rw_to_old.a129_a143_bag_wh",
		str(bk_a129.meta.get("passiveHarmRi", "")) == "450"
		and bk_129_aplus == 2
		and is_equal_approx(float(bk_a129.params[2]), 77.0)
		and str(bk_a143.note).contains("<atk Param +15 per Level>")
		and int(bk_a143.get("level", 0)) == 99 and int(bk_a143.get("exp", 0)) == 12345
		and str(bk_bag_w76.meta.get("passiveHarmRi", "")) == "450"
		and str(bk_wh_a129.meta.get("passiveHarmRi", "")) == "450",
		[bk_a129.meta.get("passiveHarmRi"), bk_129_aplus, bk_bag_w76.meta.get("passiveHarmRi"), bk_wh_a129.meta.get("passiveHarmRi")])
	var dmg_back := _single_hit_9998(s_back)
	check("p1_2.rw_to_old.combat_dmg", dmg_back > 0.0 and is_equal_approx(dmg_back, dmg_old), [dmg_old, dmg_back])

	XXufeng.REWORK = true
	XXufeng.clear_cache()


## 构造与 R0（9da929fa4）完全一致的历史重做实例（150% 物攻、600% yep、125 终爆伤、195% 元素说明）
func _make_r0_weapon76() -> Dictionary:
	var raw: Dictionary = XDB.table("Weapons")[76].duplicate(true)
	raw.kind = "weapon"
	raw.base = 76.0
	raw["affixIds"] = []
	raw["upgradeSlots"] = 6
	raw["originalUpgradeSlots"] = 6
	raw["boostCount"] = 0
	raw["upgrades"] = []
	raw["baseName"] = str(raw.name)
	for tr in raw.traits:
		if int(tr.code) == 21 and int(tr.dataId) == 2:
			tr.value = 1.5
	for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
		XXufeng._replace_tag(raw, "Element Amplify %d" % el, " +195%")
	XXufeng._replace_tag(raw, "passiveHarmRi", "125")
	XXufeng._replace_tag(raw, "passiveCrHarmRi", "125")
	raw.customParams.params[2].level = 6.0
	raw.customParams.params[4].level = 6.0
	XXufeng._replace_note_meta(raw, "atk += user.level * 10; mat += user.level * 10;", "atk += user.level * 6; mat += user.level * 6;")
	XXufeng._replace_note_meta(raw, "物理 、雷电 阴阳 混沌伤+600%", "物理 、雷电 阴阳 混沌伤+195%")
	XXufeng._replace_note_meta(raw, "攻击力能力值*300%", "攻击力能力值*150%，爆伤与伤害+125%")
	XXufeng._replace_note_meta(raw, "每级+10)", "每级+6)")
	# R0 未改 yep.elementAmplify，仍为 6.0
	raw["instanceId"] = "xg:9101"
	return raw


func _make_r0_armor129() -> Dictionary:
	var raw: Dictionary = XDB.table("Armors")[129].duplicate(true)
	raw.kind = "armor"
	raw.base = 129.0
	raw["affixIds"] = []
	raw["upgradeSlots"] = 6
	raw["originalUpgradeSlots"] = 6
	raw["boostCount"] = 0
	raw["upgrades"] = []
	raw["baseName"] = str(raw.name)
	var aplus := 0
	var nt := []
	for tr in raw.traits:
		if int(tr.code) == 21 and int(tr.dataId) == 2:
			tr.value = 1.5
			nt.append(tr)
		elif int(tr.code) == 61 and int(tr.dataId) == 0:
			aplus += 1
			if aplus == 1:
				nt.append(tr)
		else:
			nt.append(tr)
	raw.traits = nt
	for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
		XXufeng._replace_tag(raw, "Element Amplify %d" % el, " +195%")
	XXufeng._replace_tag(raw, "passiveHarmRi", "125")
	XXufeng._replace_tag(raw, "passiveCrHarmRi", "125")
	XXufeng._replace_note_meta(raw, "等级需求:1 ", "等级需求:75 ")
	XXufeng._replace_note_meta(raw, "造成所有伤害结果*350%", "造成所有伤害结果*249%")
	XXufeng._replace_note_meta(raw, "物理 、雷电 阴阳 混沌伤+600%", "物理 、雷电 阴阳 混沌伤+195%")
	XXufeng._replace_note_meta(raw, "再动+2 ", "再动+1 ")
	XXufeng._replace_note_meta(raw, "攻击力能力值*300%", "攻击力能力值*150%，爆伤与伤害+125%")
	raw["instanceId"] = "xg:9102"
	return raw


## R2 专项回归：R0 双向迁移、星级仓库存取双向＋取出即穿、旧通用武器绣冬词缀迁移（P2-2）、符文之语合并元数据（P3-1）
func _check_r2_migrations() -> void:
	# 1) R0（9da929fa4）实例双向读档迁移（R0→R1 与 R0→原版）
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s_r0 := _make_xiyou_state(80)
	var a_r0: XActor = s_r0.actor(152)
	var r0_w76 := _make_r0_weapon76()
	r0_w76.params[2] = 199.0
	var r0_a129 := _make_r0_armor129()
	r0_a129.params[2] = 88.0
	_equip_in_slot(a_r0, r0_w76)
	_equip_in_slot(a_r0, r0_a129)
	var raw_r0: Dictionary = JSON.parse_string(JSON.stringify(XSaveSlim.as_reloaded(s_r0.to_dict())))

	# R0 → R1（REWORK=true）
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s_r0_on := XState.from_dict(raw_r0.duplicate(true))
	var w_on: Dictionary = s_r0_on.actor(152).equips[0]
	var c_on: Dictionary = s_r0_on.actor(152).equips[1]
	check("r2.r0_to_r1",
		is_equal_approx(float(w_on.traits[3].value), float(XXufeng.XIUDONG_ATK_PCT) / 100.0)
		and is_equal_approx(float(w_on.yep.elementAmplify["1"]), float(XXufeng.XIUDONG_EL_AMP) / 100.0)
		and str(w_on.meta.get("passiveHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and str(w_on.note).contains("造成所有伤害结果*249%")
		and is_equal_approx(float(w_on.customParams.params[2].level), float(XXufeng.XIUDONG_GROW))
		and is_equal_approx(float(w_on.params[2]), 199.0)
		and is_equal_approx(float(c_on.traits[0].value), float(XXufeng.CHUNLEI_ATK_PCT) / 100.0)
		and (c_on.traits as Array).filter(func(tr): return int(tr.code) == 61).size() == 1
		and is_equal_approx(float(c_on.yep.elementAmplify["1"]), float(XXufeng.CHUNLEI_EL_AMP) / 100.0)
		and str(c_on.meta.get("passiveHarmRi", "")) == str(XXufeng.CHUNLEI_HARM)
		and is_equal_approx(float(c_on.customParams.params[2].level), float(XXufeng.CHUNLEI_ATK_GROW))
		and is_equal_approx(float(c_on.params[2]), 88.0),
		[w_on.traits[3].value, w_on.yep.elementAmplify["1"], c_on.traits[0].value, c_on.yep.elementAmplify["1"]])

	# R0 → 原版（REWORK=false）
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_r0_off := XState.from_dict(raw_r0.duplicate(true))
	var w_off: Dictionary = s_r0_off.actor(152).equips[0]
	var c_off: Dictionary = s_r0_off.actor(152).equips[1]
	check("r2.r0_to_orig",
		is_equal_approx(float(w_off.traits[3].value), 3.0)
		and is_equal_approx(float(w_off.yep.elementAmplify["1"]), 6.0)
		and str(w_off.meta.get("passiveHarmRi", "")) == "450"
		and str(w_off.note).contains("造成所有伤害结果*350%")
		and is_equal_approx(float(w_off.customParams.params[2].level), 10.0)
		and is_equal_approx(float(w_off.params[2]), 199.0)
		and is_equal_approx(float(c_off.traits[0].value), 3.0)
		and (c_off.traits as Array).filter(func(tr): return int(tr.code) == 61).size() == 2
		and is_equal_approx(float(c_off.yep.elementAmplify["1"]), 6.0)
		and str(c_off.meta.get("passiveHarmRi", "")) == "450"
		and is_equal_approx(float(c_off.customParams.params[2].level), 30.0)
		and is_equal_approx(float(c_off.params[2]), 88.0),
		[w_off.traits[3].value, w_off.yep.elementAmplify["1"], c_off.traits[0].value, c_off.traits.size()])

	# 2) 星级仓库（XStarWarehouse）真存读盘＋双向存取＋取出即穿实打回归
	var wh_path := ProjectSettings.globalize_path("user://test_xufeng_r2_star_wh.json")
	var old_wh_override := XStarWarehouse.path_override
	var old_wh_txn := XStarWarehouse.o_withdraw_txn
	for p_rm in [wh_path, wh_path + ".before_slim.bak"]:
		if FileAccess.file_exists(p_rm):
			DirAccess.remove_absolute(p_rm)
	XStarWarehouse.path_override = wh_path
	XStarWarehouse.o_withdraw_txn = false
	XStarWarehouse._loaded_path = "<unloaded>"

	# 2a) 原版存进星级仓库 → 真读盘 → 开 REWORK 取出即穿（不重读档）
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_wh_orig := _make_xiyou_state(80)
	var wh_w_orig: Dictionary = XGear.template("weapon", 76)
	wh_w_orig.params[2] = 155.0
	s_wh_orig.register_gear(wh_w_orig)
	s_wh_orig.gear.append(wh_w_orig)
	var dep1 := XStarWarehouse.deposit_gear(s_wh_orig, wh_w_orig)
	# 强制从磁盘重新加载星级仓库
	XStarWarehouse._loaded_path = "<unloaded>"
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s_wh_rw := _make_xiyou_state(80)
	var wd1 := XStarWarehouse.withdraw_gear(s_wh_rw, XStarWarehouse.gear()[0])
	var got_rw: Dictionary = s_wh_rw.gear[0]
	var a_wh_rw: XActor = s_wh_rw.actor(152)
	_equip_in_slot(a_wh_rw, got_rw)
	a_wh_rw.param_mark_dirty()
	a_wh_rw.refresh_passive()
	for sid in a_wh_rw.skill_ids:
		a_wh_rw.mastery_levels[sid] = 32
	a_wh_rw.recover_all()
	var dmg_wh_rw := _single_hit_9998(s_wh_rw)
	# 同条件新建 R1 绣冬对照
	var s_wh_ref_rw := _make_xiyou_state(80)
	var ref_w_rw: Dictionary = XGear.template("weapon", 76)
	ref_w_rw.params[2] = 155.0
	_equip_in_slot(s_wh_ref_rw.actor(152), ref_w_rw)
	s_wh_ref_rw.actor(152).param_mark_dirty()
	s_wh_ref_rw.actor(152).refresh_passive()
	for sid in s_wh_ref_rw.actor(152).skill_ids:
		s_wh_ref_rw.actor(152).mastery_levels[sid] = 32
	s_wh_ref_rw.actor(152).recover_all()
	var dmg_ref_rw := _single_hit_9998(s_wh_ref_rw)
	check("r2.star_wh.orig_to_rw_equip_now",
		dep1 == "" and wd1
		and is_equal_approx(float(got_rw.traits[3].value), float(XXufeng.XIUDONG_ATK_PCT) / 100.0)
		and is_equal_approx(float(got_rw.yep.elementAmplify["1"]), float(XXufeng.XIUDONG_EL_AMP) / 100.0)
		and str(got_rw.meta.get("passiveHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and is_equal_approx(float(got_rw.params[2]), 155.0)
		and dmg_wh_rw > 0.0 and is_equal_approx(dmg_wh_rw, dmg_ref_rw),
		[dep1, wd1, got_rw.traits[3].value, got_rw.yep.elementAmplify["1"], dmg_wh_rw, dmg_ref_rw])

	# 2b) R1 存进星级仓库 → 真读盘 → 关 REWORK 取出即穿（不重读档）
	s_wh_rw.gear.clear()
	s_wh_rw.gear.append(got_rw)
	var dep2 := XStarWarehouse.deposit_gear(s_wh_rw, got_rw)
	XStarWarehouse._loaded_path = "<unloaded>"
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_wh_back := _make_xiyou_state(80)
	var wd2 := XStarWarehouse.withdraw_gear(s_wh_back, XStarWarehouse.gear()[0])
	var got_orig: Dictionary = s_wh_back.gear[0]
	var a_wh_back: XActor = s_wh_back.actor(152)
	_equip_in_slot(a_wh_back, got_orig)
	a_wh_back.param_mark_dirty()
	a_wh_back.refresh_passive()
	for sid in a_wh_back.skill_ids:
		a_wh_back.mastery_levels[sid] = 32
	a_wh_back.recover_all()
	var dmg_wh_orig := _single_hit_9998(s_wh_back)
	var s_wh_ref_orig := _make_xiyou_state(80)
	var ref_w_orig: Dictionary = XGear.template("weapon", 76)
	ref_w_orig.params[2] = 155.0
	_equip_in_slot(s_wh_ref_orig.actor(152), ref_w_orig)
	s_wh_ref_orig.actor(152).param_mark_dirty()
	s_wh_ref_orig.actor(152).refresh_passive()
	for sid in s_wh_ref_orig.actor(152).skill_ids:
		s_wh_ref_orig.actor(152).mastery_levels[sid] = 32
	s_wh_ref_orig.actor(152).recover_all()
	var dmg_ref_orig := _single_hit_9998(s_wh_ref_orig)
	check("r2.star_wh.rw_to_orig_equip_now",
		dep2 == "" and wd2
		and is_equal_approx(float(got_orig.traits[3].value), 3.0)
		and is_equal_approx(float(got_orig.yep.elementAmplify["1"]), 6.0)
		and str(got_orig.meta.get("passiveHarmRi", "")) == "450"
		and is_equal_approx(float(got_orig.params[2]), 155.0)
		and dmg_wh_orig > 0.0 and is_equal_approx(dmg_wh_orig, dmg_ref_orig),
		[dep2, wd2, got_orig.traits[3].value, got_orig.yep.elementAmplify["1"], dmg_wh_orig, dmg_ref_orig])

	# 2c) 存入方向：开 REWORK 存入一件旧原版绣冬，落盘前即已同步为 R1
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s_dep := _make_xiyou_state(80)
	s_dep.gear.append(got_orig)  # got_orig 目前是原版 300%/600%/450
	var dep3 := XStarWarehouse.deposit_gear(s_dep, got_orig)
	XStarWarehouse._loaded_path = "<unloaded>"
	var stored_after_dep: Dictionary = XStarWarehouse.gear()[0]
	check("r2.star_wh.deposit_syncs",
		dep3 == ""
		and is_equal_approx(float(stored_after_dep.traits[3].value), float(XXufeng.XIUDONG_ATK_PCT) / 100.0)
		and is_equal_approx(float(stored_after_dep.yep.elementAmplify["1"]), float(XXufeng.XIUDONG_EL_AMP) / 100.0)
		and str(stored_after_dep.meta.get("passiveHarmRi", "")) == str(XXufeng.XIUDONG_HARM),
		[dep3, stored_after_dep.traits[3].value, stored_after_dep.meta.get("passiveHarmRi")])

	XStarWarehouse.path_override = old_wh_override
	XStarWarehouse.o_withdraw_txn = old_wh_txn
	XStarWarehouse._loaded_path = "<unloaded>"
	for p_rm in [wh_path, wh_path + ".before_slim.bak"]:
		if FileAccess.file_exists(p_rm):
			DirAccess.remove_absolute(p_rm)

	# 3) P2-2：历史旧通用武器带原版绣冬 76 词缀，开 REWORK 且在西游档上下文读档时仍照常迁移清除
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_kd := XState.new_game_blank()
	s_kd.random_master = XRandomStream.hex64(20261124)
	s_kd.set_switch(2494, true)
	XState.current = s_kd
	s_kd.add_actor(122)
	var kd_w: Dictionary = XGear.template("weapon", 1)
	XGear.combine(kd_w, XDB.rec("Weapons", 76), "prefix")
	kd_w.affixIds.append({"table": "Weapons", "id": 76, "kind": "prefix"})
	XGear._apply_note_params(kd_w)
	kd_w["instanceId"] = "xg:9201"
	s_kd.actor(122).equips[0] = kd_w
	var raw_kd: Dictionary = JSON.parse_string(JSON.stringify(XSaveSlim.as_reloaded(s_kd.to_dict())))
	# 在已打开西游档且 REWORK=true 的上下文里读档
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	XState.current = _make_xiyou_state(80)
	var s_kd_loaded := XState.from_dict(raw_kd)
	var kd_w_after: Dictionary = s_kd_loaded.actor(122).equips[0]
	check("r2.p2_2.exclusive_affix_reverted",
		(XGear.last_affix_revert.get("skipped", []) as Array).is_empty()
		and kd_w_after.has("_affixRevert")
		and (kd_w_after.get("affixIds", []) as Array).is_empty()
		and not str(kd_w_after.name).begins_with("绣冬")
		and (kd_w_after.get("yep", {}).get("elementAmplify", {}) as Dictionary).is_empty()
		and not (kd_w_after.get("meta", {}) as Dictionary).has("passiveHarmRi"),
		[XGear.last_affix_revert, kd_w_after.name, kd_w_after.get("yep"), kd_w_after.get("affixIds")])

	# 4) P3-1：原版绣冬经真实强化形成符文之语（RW 3「致密」+50 passiveCrHarmRi → 500），双向读档保留增量（500 → 170 → 500）
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_rw_orig := _make_xiyou_state(80)
	var w_runeword: Dictionary = XGear.template("weapon", 76)
	s_rw_orig.register_gear(w_runeword)
	s_rw_orig.gear.append(w_runeword)
	for mid in [282, 280, 283]:
		s_rw_orig.gain_item(mid, 1)
		XGearUpgrade.apply(s_rw_orig, w_runeword, mid)
	var cr_orig_val := float(str(w_runeword.meta.get("passiveCrHarmRi", "0")).strip_edges())
	var raw_rw_orig: Dictionary = JSON.parse_string(JSON.stringify(XSaveSlim.as_reloaded(s_rw_orig.to_dict())))
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	var s_rw_reloaded := XState.from_dict(raw_rw_orig)
	var w_rw_after: Dictionary = s_rw_reloaded.gear[0]
	var cr_rw_val := float(str(w_rw_after.meta.get("passiveCrHarmRi", "0")).strip_edges())
	var raw_rw_back: Dictionary = JSON.parse_string(JSON.stringify(XSaveSlim.as_reloaded(s_rw_reloaded.to_dict())))
	XXufeng.REWORK = false
	XXufeng.clear_cache()
	var s_rw_back := XState.from_dict(raw_rw_back)
	var w_rw_back: Dictionary = s_rw_back.gear[0]
	var cr_back_val := float(str(w_rw_back.meta.get("passiveCrHarmRi", "0")).strip_edges())
	check("r2.p3_1.runeword_meta_preserved",
		w_runeword.get("runewords", []) == [3]
		and is_equal_approx(cr_orig_val, 500.0)
		and is_equal_approx(cr_rw_val, float(XXufeng.XIUDONG_HARM) + 50.0)
		and str(w_rw_after.meta.get("passiveHarmRi", "")) == str(XXufeng.XIUDONG_HARM)
		and is_equal_approx(cr_back_val, 500.0),
		[w_runeword.get("runewords"), cr_orig_val, cr_rw_val, cr_back_val, w_rw_after.meta.get("passiveCrHarmRi")])

	XXufeng.REWORK = true
	XXufeng.clear_cache()


func _single_hit_9998(s: XState) -> float:
	XState.current = s
	XStateEffects.force_critical = true
	var a: XActor = s.actor(152)
	var logic := XBattleLogic.new()
	var rng := XBattleRandom.create(XRandomStream.hex64(424242))
	logic.setup(70, s, rng)
	var foe: XEnemy = logic.enemies[0]
	foe.param_refresh()
	foe.recover_all()
	logic.start_turn()
	a.mp = a.mmp
	a.tp = 100.0
	var logs: Array = logic.act(a, XDB.rec("Skills", 9998), foe)
	var sum := 0.0
	for e in logs:
		if e is Dictionary and str(e.get("type", "")) == "hit" and is_same(e.get("target"), foe):
			sum += maxf(0.0, float(e.get("hp", 0.0)))
	logic.end_battle(0)
	XStateEffects.force_critical = false
	return sum


func _check_dummy_tiers() -> void:
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	XStateEffects.force_critical = true
	var seeds := [1, 2, 3, 4, 5]
	# 主口径 50 / 70(99) / 75(全套绣冬+春雷) / 80(全套绣冬+春雷+天下第一) 必须落 1.15～1.25×
	for row in [
		["lv50", 50, 99, 0, 0, 0, true],
		["lv70_main", 70, 99, 0, 0, 0, true],
		["lv70_888", 70, 888, 0, 0, 0, false],
		["lv75_single", 75, 99, 2019, 76, 0, false],
		["lv75_fullset", 75, 99, 2019, 76, 129, true],
		["lv80_single", 80, 99, 2019, 76, 0, false],
		["lv80_fullset", 80, 99, 2019, 76, 129, true],
	]:
		var tag: String = row[0]
		var lv: int = row[1]
		var art_lv: int = row[2]
		var kd_wpn: int = row[3]
		var xf_wpn: int = row[4]
		var xf_off: int = row[5]
		var must_pass: bool = row[6]
		var kd_list := _bench_seeds(122, 4575, kd_wpn, 0, lv, art_lv, 32, seeds)
		var xf_list := _bench_seeds(152, 143, xf_wpn, xf_off, lv, art_lv, 32, seeds)
		var kd_m := _mean(kd_list)
		var xf_m := _mean(xf_list)
		var ratio := xf_m / maxf(1e-9, kd_m)
		print("BENCH ", tag, " ", JSON.stringify({
			"kd_T": snappedf(kd_m, 0.01), "xf_T": snappedf(xf_m, 0.01),
			"ratio": snappedf(ratio, 0.0001),
			"kd_seeds": kd_list.map(func(v): return snappedf(v, 0.01)),
			"xf_seeds": xf_list.map(func(v): return snappedf(v, 0.01)),
		}))
		if must_pass:
			check("dummy.%s.ratio" % tag, ratio >= 1.15 and ratio <= 1.25,
				{"kd_T": snappedf(kd_m, 0.01), "xf_T": snappedf(xf_m, 0.01), "ratio": snappedf(ratio, 0.0001)})
		elif tag.ends_with("_single"):
			check("dummy.%s.option_b_range" % tag, ratio >= 0.70 and ratio <= 0.85,
				{"kd_T": snappedf(kd_m, 0.01), "xf_T": snappedf(xf_m, 0.01), "ratio": snappedf(ratio, 0.0001)})
	XStateEffects.force_critical = false


func _mean(arr: Array) -> float:
	var s := 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())


func _bench_seeds(aid: int, art_id: int, wpn_id: int, off_id: int, lv: int, art_lv: int, mastery: int, seeds: Array) -> Array:
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
			_equip_in_slot(a, art)
		if wpn_id > 0:
			a.equips[0] = a.make_equip("weapon", wpn_id)
		if off_id > 0:
			var off: Dictionary = a.make_equip("armor", off_id)
			_equip_in_slot(a, off)
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
