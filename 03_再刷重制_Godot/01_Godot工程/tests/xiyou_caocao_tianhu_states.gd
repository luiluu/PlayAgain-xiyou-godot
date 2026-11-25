extends Node
## 【小A·未经审查】T491 西游档曹操霸道真气（State 106）Regenerate 与天虎令气伤（State 1341）Apply／React 原版 v0.62.12 对拍专项：
## 1) State 106 Regenerate 原版公式：damage = stacks * (origin.atk + origin.mat) * origin.level * (1 + level(armor 3640))；
##    stacks = _stackingPoison || 1；动画 130、扣血走护盾与死亡结算、弹字清结果；来源非角色时无效果；
## 2) State 1341 Apply 原版公式：_stateCounter[1341] = clamp((cur || 0) + 1, 0, 10000)，移除时清零；
## 3) State 1341 React 原版公式：固定种子先抽 1 次 RNG；value > 0 且 isSkill() 时
##    dmm = max(0, origin.atk * 2 + origin.mhp)，
##    ddd = ceil(target.elementRate(1) * origin.mdr * dmm * (1 + d * 0.25) / 2)（d == 0 时去掉 (1 + d*0.25)），
##    若 origin.skillMasteryLevel(7485) >= 1 再加 ceil(ddd * (mastery + level(armor 3550)))，
##    直接 target.gainHp(-ddd) + startDamagePopup()，主伤害 value 保持不变；
## 4) 法宝等级统一走 T490 共用读口（XEquipmentView.first_armor_level -> XMagicWeapon.combat_level，99 级等价 888，受楼层上限压制）；
## 5) 仅西游档（not XTianqi.active）生效，天启篇零改动、无存档上下文零改动，独立开关 XStateEffects.PORT_CAOCAO_TIANHU 可秒级回退。
var passed := 0
var total := 0


class FixedActor extends XActor:
	var fixed_params := {}
	var fixed_cri := -1.0
	var fixed_mdr := -1.0
	var fixed_lv := -1

	func param(i: int) -> float:
		var k: String = ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"][i]
		return float(fixed_params[k]) if fixed_params.has(k) else super(i)

	func xparam(i: int) -> float:
		return fixed_cri if i == 2 and fixed_cri >= 0.0 else super(i)

	func sparam(i: int) -> float:
		return fixed_mdr if i == 7 and fixed_mdr >= 0.0 else super(i)

	func _level() -> int:
		return fixed_lv if fixed_lv >= 0 else super()


class FixedEnemy extends XEnemy:
	var fixed_mhp := -1.0
	var fixed_elem := {}

	func param(i: int) -> float:
		return fixed_mhp if i == 0 and fixed_mhp >= 0.0 else super(i)

	func element_rate(e: int) -> float:
		return float(fixed_elem[e]) if fixed_elem.has(e) else super(e)


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _ready() -> void:
	_run.call_deferred()


func _make_xiyou(floor_no := 30) -> XState:
	var s := XState.new_game_blank()
	s.set_variable(20, floor_no)
	XState.current = s
	return s


func _make_tianqi(floor_no := 30) -> XState:
	var s := XState.new_game_blank()
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [1]}
	s.set_variable(20, floor_no)
	XState.current = s
	return s


func _equip_fabao(actor: XActor, armor_id: int, lv: int) -> Dictionary:
	var item := XGear.template("armor", armor_id)
	item["level"] = float(lv)
	var slots := actor.equip_slots()
	var idx := slots.find(int(item.get("etypeId", 0)))
	if idx < 0:
		actor.equips = [item]
	else:
		if actor.equips.size() < slots.size():
			actor.equips.resize(slots.size())
		actor.equips[idx] = item
	return item


func _make_caocao(lv_fabao := 99) -> FixedActor:
	var a := FixedActor.new()
	a.setup(38)
	a.fixed_params = {"mhp": 50000.0, "mmp": 2000.0, "atk": 500.0, "def": 100.0, "mat": 300.0, "mdf": 100.0, "agi": 100.0, "luk": 100.0}
	a.fixed_lv = 60
	if lv_fabao > 0:
		_equip_fabao(a, 3640, lv_fabao)
	else:
		a.equips = []
	return a


func _make_tianhu(lv_fabao := 99, mastery := 5, mdr := 0.77, cri := 0.35) -> FixedActor:
	var a := FixedActor.new()
	a.setup(104)
	a.fixed_params = {"mhp": 20000.0, "mmp": 2000.0, "atk": 400.0, "def": 100.0, "mat": 100.0, "mdf": 100.0, "agi": 100.0, "luk": 100.0}
	a.fixed_mdr = mdr
	a.fixed_cri = cri
	a.fixed_lv = 60
	a.mastery_levels[7485] = mastery
	if lv_fabao > 0:
		_equip_fabao(a, 3550, lv_fabao)
	else:
		a.equips = []
	return a


func _make_enemy(mhp := 1e12, era1 := 1.33) -> FixedEnemy:
	var e := FixedEnemy.new()
	e.setup(XDB.rec("Troops", 2).members[0].enemyId, 3, 100.0)
	e.fixed_mhp = mhp
	e.fixed_elem = {1: era1}
	e.hp = mhp
	e.shield = 0.0
	return e


func _run() -> void:
	var was_port := XStateEffects.PORT_CAOCAO_TIANHU
	var was_l99 := XMagicWeapon.LEVEL_99
	var was_floor := XMagicWeapon.FLOOR_CAP
	var was_scale := XMagicWeapon.SCALE_99_TO_888
	var was_force := XEnemy.force_roll

	XStateEffects.PORT_CAOCAO_TIANHU = true
	XMagicWeapon.LEVEL_99 = true
	XMagicWeapon.FLOOR_CAP = true
	XMagicWeapon.SCALE_99_TO_888 = true
	XEnemy.force_roll = 100.0
	XStateEffects.clear_diagnostics()

	_test_caocao_106_oracle()
	_test_caocao_106_battle_turn_end()
	_test_tianhu_1341_apply_and_react_oracle()
	_test_tianhu_1341_battle_apply()
	_test_isolation_and_rollback()

	XStateEffects.PORT_CAOCAO_TIANHU = was_port
	XMagicWeapon.LEVEL_99 = was_l99
	XMagicWeapon.FLOOR_CAP = was_floor
	XMagicWeapon.SCALE_99_TO_888 = was_scale
	XEnemy.force_roll = was_force
	XStateEffects.clear_diagnostics()
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"test": "xiyou_caocao_tianhu_states", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _test_caocao_106_oracle() -> void:
	var s := _make_xiyou(30)
	var st := XDB.rec("States", 106)
	var caocao := _make_caocao(99)
	var e := _make_enemy(1e12, 1.0)
	XImportedBalance.set_acting(caocao)
	e.add_state(106)
	XImportedBalance.set_acting(null)
	check("s106.apply_sets_stack_1", float(e.state_data.get("_stackingPoison", 0.0)) == 1.0, e.state_data)

	# 样本 1a：固定面板 atk=500, mat=300, level=60, 暗涌 99 级（T490 等价 888）, stacks=3
	# 原版 v0.62.12 公式：3 * (500 + 300) * 60 * (1 + 888) = 128,016,000
	e.state_data["_stackingPoison"] = 3.0
	e.hp = 1e12
	var logs := []
	var ctx := {"random": XRandomStream.create(XRandomStream.hex64(491), "battle"), "emit": func(row): logs.append(row)}
	XStateEffects.run_one("regenerate", e, st, ctx)
	check("s106.oracle_lv99_as_888_s3", is_equal_approx(1e12 - e.hp, 128016000.0), 1e12 - e.hp)
	check("s106.oracle_s3_anim_popup", logs.size() == 1 and int(logs[0].get("animation", 0)) == 130
		and is_equal_approx(float(logs[0].get("hp", 0.0)), 128016000.0) and int(logs[0].get("state", 0)) == 106, logs)
	check("s106.oracle_s3_keeps_stacks", float(e.state_data.get("_stackingPoison", 0.0)) == 3.0, e.state_data)

	# 样本 1b：stacks=0 -> || 1 并写回；1 * 800 * 60 * 889 = 42,672,000
	e.state_data["_stackingPoison"] = 0.0
	e.hp = 1e12
	logs.clear()
	XStateEffects.run_one("regenerate", e, st, ctx)
	check("s106.oracle_s0_defaults_to_1", is_equal_approx(1e12 - e.hp, 42672000.0)
		and float(e.state_data.get("_stackingPoison", 0.0)) == 1.0, [1e12 - e.hp, e.state_data])

	# 样本 1c：带护盾 1,000,000 吸收击穿减半 -> (42,672,000 - 1,000,000) / 2 = 20,836,000（原版实测数）
	e.state_data["_stackingPoison"] = 1.0
	e.hp = 1e12
	e.shield = 1000000.0
	logs.clear()
	XStateEffects.run_one("regenerate", e, st, ctx)
	check("s106.oracle_shield_absorb", is_equal_approx(1e12 - e.hp, 20836000.0) and e.shield == 0.0, [1e12 - e.hp, e.shield])

	# 样本 1d：1 层楼层上限压实际等级为 12 再折算（12 * 888 / 99），升 30 层自动恢复 888
	s.set_variable(20, 1)
	e.state_data["_stackingPoison"] = 1.0
	e.hp = 1e12
	XStateEffects.run_one("regenerate", e, st, ctx)
	var want_f1 := 1.0 * (500.0 + 300.0) * 60.0 * (1.0 + 12.0 * 888.0 / 99.0)
	var dark_list := caocao.equip_list().filter(func(eq): return int(eq.get("base", eq.get("id", 0))) == 3640)
	check("s106.floor_cap_1", is_equal_approx(1e12 - e.hp, want_f1) and dark_list.size() == 1 and float(dark_list[0].level) == 99.0, [1e12 - e.hp, want_f1])
	s.set_variable(20, 30)

	# 样本 1e：关 T490 折算开关回到 99 级原读口 -> 1 * 800 * 60 * (1 + 99) = 4,800,000
	XMagicWeapon.SCALE_99_TO_888 = false
	e.hp = 1e12
	XStateEffects.run_one("regenerate", e, st, ctx)
	check("s106.t490_scale_off_99", is_equal_approx(1e12 - e.hp, 4800000.0), 1e12 - e.hp)
	XMagicWeapon.SCALE_99_TO_888 = true

	# 样本 1f：未装备暗涌（level = 0），stacks = 2 -> 2 * 800 * 60 * 1 = 96,000（原版实测数）
	var bare := _make_caocao(0)
	var e_bare := _make_enemy(1e12, 1.0)
	XImportedBalance.set_acting(bare)
	e_bare.add_state(106)
	XImportedBalance.set_acting(null)
	e_bare.state_data["_stackingPoison"] = 2.0
	e_bare.hp = 1e12
	XStateEffects.run_one("regenerate", e_bare, st, ctx)
	check("s106.oracle_no_armor_s2", is_equal_approx(1e12 - e_bare.hp, 96000.0), 1e12 - e_bare.hp)

	# 样本 1g：致死击杀（hp = 100）-> hp == 0 且挂死亡状态 1
	e_bare.state_data["_stackingPoison"] = 1.0
	e_bare.hp = 100.0
	XStateEffects.run_one("regenerate", e_bare, st, ctx)
	check("s106.oracle_lethal", e_bare.hp == 0.0 and e_bare.is_dead(), [e_bare.hp, e_bare.state_ids])

	# 样本 1h：来源为敌人（非 XActor），原版 origin.equips() 抛 TypeError 无效果（不改 _stackingPoison、不扣血）
	var e_self := _make_enemy(1e12, 1.0)
	XImportedBalance.set_acting(e_self)
	e_self.add_state(106)
	XImportedBalance.set_acting(null)
	e_self.state_data.erase("_stackingPoison")
	e_self.hp = 1e12
	logs.clear()
	XStateEffects.run_one("regenerate", e_self, st, ctx)
	check("s106.oracle_enemy_origin_noop", e_self.hp == 1e12 and not e_self.state_data.has("_stackingPoison") and logs.is_empty(),
		[e_self.hp, e_self.state_data, logs])

	# 样本 1i：预览模式（execute = false）零副作用、不报未翻译
	var e_prev := _make_enemy(1e12, 1.0)
	XImportedBalance.set_acting(caocao)
	e_prev.add_state(106)
	XImportedBalance.set_acting(null)
	e_prev.state_data.erase("_stackingPoison")
	e_prev.hp = 1e12
	var untrans := []
	XStateEffects.run_one("regenerate", e_prev, st, {"execute": false, "untranslated": untrans})
	check("s106.preview_pure", e_prev.hp == 1e12 and not e_prev.state_data.has("_stackingPoison") and untrans.is_empty(),
		[e_prev.hp, e_prev.state_data, untrans])


func _test_caocao_106_battle_turn_end() -> void:
	var s := XState.new_game(3, 38, [])
	s.set_variable(20, 30)
	XState.current = s
	var caocao: XActor = s.members()[0]
	_equip_fabao(caocao, 3640, 99)
	caocao.refresh_passive()
	caocao.recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var foe: XEnemy = logic.enemies[0]
	XImportedBalance.set_acting(caocao)
	foe.add_state(106)
	XImportedBalance.set_acting(null)
	foe.param_refresh()
	var want_dmg := 1.0 * (caocao.atk + caocao.mat) * float(caocao.level) * (1.0 + 888.0)
	logic.start_turn()
	var logs := logic.end_turn()
	var regen_rows := logs.filter(func(l): return l.get("type") == "regen" and l.get("target") == foe and int(l.get("state", 0)) == 106)
	var collapse_rows := logs.filter(func(l): return l.get("type") == "collapse" and l.get("target") == foe)
	check("s106.battle_end_turn_regen", regen_rows.size() == 1 and int(regen_rows[0].get("animation", 0)) == 130
		and is_equal_approx(float(regen_rows[0].get("hp", 0.0)), want_dmg), [regen_rows, want_dmg])
	check("s106.battle_end_turn_lethal_collapse", foe.is_dead() and collapse_rows.size() == 1, [foe.hp, foe.state_ids, collapse_rows])


func _test_tianhu_1341_apply_and_react_oracle() -> void:
	var s := _make_xiyou(30)
	var st := XDB.rec("States", 1341)
	var sk7485 := XDB.rec("Skills", 7485)
	var item1 := XDB.rec("Items", 1)
	var tianhu := _make_tianhu(99, 5, 0.77, 0.35)
	var e := _make_enemy(1e12, 1.33)

	# Apply：首次 +1；重复施加不重复跑 Apply（_Fix_StackOverflow）；remove 清计数；上限 10000 夹紧
	XImportedBalance.set_acting(tianhu)
	e.add_state(1341)
	var c1 := float(e.state_data.get("_stateCounter", {}).get("1341", -1.0))
	e.add_state(1341)
	var c2 := float(e.state_data.get("_stateCounter", {}).get("1341", -1.0))
	XImportedBalance.set_acting(null)
	check("s1341.apply_counter_1_and_reapply_keeps_1", c1 == 1.0 and c2 == 1.0, [c1, c2])

	# 样本 2a：固定种子 hex64(491)，技能 7485，value=1000，d=1，mastery=5，烽舞 99 级（T490 等价 888）
	# 原版 v0.62.12 公式：
	#   dmm = 400*2 + 20000 = 20800
	#   ddd0 = ceil(1.33 * 0.77 * 20800 * (1 + 1*0.25) / 2) = ceil(13313.768) = 13314
	#   ddmg = ceil(13314 * (5 + 888)) = 11,889,402
	#   ddd = 13314 + 11,889,402 = 11,902,716（原版实测数）
	e.hp = 1e12
	var rc := XResourceContext.new()
	var rng := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc.random = rng
	var ret1 := XStateEffects.run_one("react", e, st, {
		"attacker": tianhu, "defender": e, "item": sk7485, "value": 1000.0, "resources": rc, "random": rng, "execute": true
	})
	var pop1: Array = rc.started_popups.get(e, [])
	check("s1341.oracle_lv99_as_888_m5_d1", ret1 == 1000.0 and is_equal_approx(1e12 - e.hp, 11902716.0) and rng.draws == 1,
		[ret1, 1e12 - e.hp, rng.draws])
	check("s1341.oracle_popup_recorded", pop1.size() == 1 and bool(pop1[0].hpAffected)
		and is_equal_approx(float(pop1[0].hpDamage), 11902716.0), pop1)

	# 样本 2b：d=3，mastery=5，烽舞 99->888，护盾 500,000
	# ddd0 = ceil(1.33 * 0.77 * 20800 * 1.75 / 2) = ceil(18638.62) = 18639
	# ddd = 18639 + 18639 * 893 = 16,663,266；护盾吸收后 (16,663,266 - 500,000) / 2 = 8,081,633（原版实测数）
	e.state_data["_stateCounter"]["1341"] = 3.0
	e.hp = 1e12
	e.shield = 500000.0
	var rc2 := XResourceContext.new()
	var rng2 := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc2.random = rng2
	var ret2 := XStateEffects.run_one("react", e, st, {
		"attacker": tianhu, "defender": e, "item": sk7485, "value": 1000.0, "resources": rc2, "random": rng2, "execute": true
	})
	check("s1341.oracle_shield_m5_d3", ret2 == 1000.0 and is_equal_approx(1e12 - e.hp, 8081633.0) and e.shield == 0.0 and rng2.draws == 1,
		[ret2, 1e12 - e.hp, e.shield, rng2.draws])

	# 样本 2c：mastery=0, d=3 -> 不进法宝/熟练度倍增，ddd = 18,639（原版实测数）
	tianhu.mastery_levels[7485] = 0
	e.hp = 1e12
	var rc3 := XResourceContext.new()
	var rng3 := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc3.random = rng3
	XStateEffects.run_one("react", e, st, {
		"attacker": tianhu, "defender": e, "item": sk7485, "value": 1000.0, "resources": rc3, "random": rng3, "execute": true
	})
	check("s1341.oracle_m0_d3", is_equal_approx(1e12 - e.hp, 18639.0) and rng3.draws == 1, [1e12 - e.hp, rng3.draws])

	# 样本 2d：d=0, mastery=2, 无烽舞（level=0）, era=1.25, mdr=0.8 -> ddd0=10400, ddmg=20800, ddd=31,200（原版实测数）
	var bare := _make_tianhu(0, 2, 0.8, 0.5)
	var e2 := _make_enemy(1e12, 1.25)
	XImportedBalance.set_acting(bare)
	e2.add_state(1341)
	XImportedBalance.set_acting(null)
	e2.state_data["_stateCounter"]["1341"] = 0.0
	e2.hp = 1e12
	var rc4 := XResourceContext.new()
	var rng4 := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc4.random = rng4
	XStateEffects.run_one("react", e2, st, {
		"attacker": bare, "defender": e2, "item": sk7485, "value": 1000.0, "resources": rc4, "random": rng4, "execute": true
	})
	check("s1341.oracle_m2_no_armor_d0", is_equal_approx(1e12 - e2.hp, 31200.0) and rng4.draws == 1, [1e12 - e2.hp, rng4.draws])

	# 样本 2e：楼层上限（1 层上限 12 级 -> 折算 12*888/99），升 30 层恢复 888
	tianhu.mastery_levels[7485] = 5
	e.state_data["_stateCounter"]["1341"] = 1.0
	s.set_variable(20, 1)
	e.hp = 1e12
	var rc5 := XResourceContext.new()
	var rng5 := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc5.random = rng5
	XStateEffects.run_one("react", e, st, {
		"attacker": tianhu, "defender": e, "item": sk7485, "value": 1000.0, "resources": rc5, "random": rng5, "execute": true
	})
	var want_1341_f1 := 13314.0 + float(ceil(13314.0 * (5.0 + 12.0 * 888.0 / 99.0)))
	var fire_list := tianhu.equip_list().filter(func(eq): return int(eq.get("base", eq.get("id", 0))) == 3550)
	check("s1341.floor_cap_1", is_equal_approx(1e12 - e.hp, want_1341_f1) and fire_list.size() == 1 and float(fire_list[0].level) == 99.0, [1e12 - e.hp, want_1341_f1])
	s.set_variable(20, 30)

	# 样本 2f：使用物品（isSkill() == false）-> 不扣血、不弹字，仍抽 1 次 RNG
	e.hp = 1e12
	var rc6 := XResourceContext.new()
	var rng6 := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc6.random = rng6
	var ret_item := XStateEffects.run_one("react", e, st, {
		"attacker": tianhu, "defender": e, "item": item1, "value": 1000.0, "resources": rc6, "random": rng6, "execute": true
	})
	check("s1341.oracle_item_no_dmg_1_draw", ret_item == 1000.0 and e.hp == 1e12 and rng6.draws == 1 and rc6.started_popups.is_empty(),
		[ret_item, e.hp, rng6.draws, rc6.started_popups])

	# 样本 2g：value == 0 -> 不扣血、不弹字，仍抽 1 次 RNG
	e.hp = 1e12
	var rc7 := XResourceContext.new()
	var rng7 := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc7.random = rng7
	var ret_zero := XStateEffects.run_one("react", e, st, {
		"attacker": tianhu, "defender": e, "item": sk7485, "value": 0.0, "resources": rc7, "random": rng7, "execute": true
	})
	check("s1341.oracle_val0_no_dmg_1_draw", ret_zero == 0.0 and e.hp == 1e12 and rng7.draws == 1 and rc7.started_popups.is_empty(),
		[ret_zero, e.hp, rng7.draws, rc7.started_popups])

	# 样本 2h：预览模式（execute = false）-> 不扣血、不抽 RNG、不报未翻译
	e.hp = 1e12
	var rng8 := XRandomStream.create(XRandomStream.hex64(491), "battle")
	var untrans := []
	var ret_prev := XStateEffects.run_one("react", e, st, {
		"attacker": tianhu, "defender": e, "item": sk7485, "value": 1000.0, "random": rng8, "execute": false, "untranslated": untrans
	})
	check("s1341.preview_pure", ret_prev == 1000.0 and e.hp == 1e12 and rng8.draws == 0 and untrans.is_empty(),
		[ret_prev, e.hp, rng8.draws, untrans])

	# 样本 2i：removeState 清计数，且 10000 上限夹紧
	e.remove_state(1341)
	var after_remove: bool = not e.state_data.get("_stateCounter", {}).has("1341")
	e.state_data["_stateCounter"] = {"1341": 10000.0}
	XImportedBalance.set_acting(tianhu)
	e.add_state(1341)
	XImportedBalance.set_acting(null)
	check("s1341.remove_clears_and_clamp_10000", after_remove and float(e.state_data["_stateCounter"]["1341"]) == 10000.0,
		[after_remove, e.state_data])


func _test_tianhu_1341_battle_apply() -> void:
	var s := _make_xiyou(30)
	var tianhu: XActor = s.actor(104)
	s.party = [104]
	s.battle_slots = [104, 0, 0, 0]
	_equip_fabao(tianhu, 3550, 99)
	tianhu.mastery_levels[7485] = 2
	tianhu.refresh_passive()
	tianhu.recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var foe: XEnemy = logic.enemies[0]
	foe.hp = foe.mhp
	XImportedBalance.set_acting(tianhu)
	foe.add_state(1341)
	XImportedBalance.set_acting(null)
	foe.param_refresh()
	var dmm := maxf(0.0, tianhu.atk * 2.0 + tianhu.mhp)
	var ddd0 := float(ceil(foe.element_rate(1) * tianhu.mdr * dmm * 1.25 / 2.0))
	var want_qishang := ddd0 + float(ceil(ddd0 * (2.0 + 888.0)))
	var sk := XDB.rec("Skills", 7485)
	var r := logic.apply(tianhu, sk, foe)
	var started: Array = r.get("started_popups", [])
	var qishang_pop := started.any(func(row): return bool(row.get("hpAffected", false)) and is_equal_approx(float(row.get("hpDamage", 0.0)), want_qishang))
	check("s1341.battle_apply_popup_and_kill", not r.missed and not r.evaded and qishang_pop and foe.is_dead() and bool(r.died),
		{"want": want_qishang, "started": started, "hp": foe.hp, "died": r.died})


func _test_isolation_and_rollback() -> void:
	var st106 := XDB.rec("States", 106)
	var st1341 := XDB.rec("States", 1341)
	var sk7485 := XDB.rec("Skills", 7485)
	var caocao := _make_caocao(99)
	var tianhu := _make_tianhu(99, 5, 0.77, 0.35)

	# 1) 天启篇存档：零改动（106 regenerate、1341 apply、1341 react 全走原未移植分支）
	_make_tianqi(30)
	var e_tq := _make_enemy(1e12, 1.33)
	XImportedBalance.set_acting(caocao)
	e_tq.add_state(106)
	XImportedBalance.set_acting(tianhu)
	e_tq.add_state(1341)
	XImportedBalance.set_acting(null)
	check("tianqi.1341_apply_unchanged", not e_tq.state_data.get("_stateCounter", {}).has("1341"), e_tq.state_data)
	e_tq.state_data["_stackingPoison"] = 3.0
	e_tq.hp = 1e12
	var tq_logs := []
	XStateEffects.run_one("regenerate", e_tq, st106, {"emit": func(row): tq_logs.append(row)})
	check("tianqi.106_regen_unchanged", e_tq.hp == 1e12 and tq_logs.is_empty(), [e_tq.hp, tq_logs])
	var rc_tq := XResourceContext.new()
	var rng_tq := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc_tq.random = rng_tq
	var ret_tq := XStateEffects.run_one("react", e_tq, st1341, {
		"attacker": tianhu, "defender": e_tq, "item": sk7485, "value": 1000.0, "resources": rc_tq, "random": rng_tq, "execute": true
	})
	check("tianqi.1341_react_unchanged", ret_tq == 1000.0 and e_tq.hp == 1e12 and rng_tq.draws == 0 and rc_tq.started_popups.is_empty(),
		[ret_tq, e_tq.hp, rng_tq.draws, rc_tq.started_popups])

	# 2) 无存档上下文（XState.current == null）：零改动
	XState.current = null
	var e_nil := _make_enemy(1e12, 1.33)
	XImportedBalance.set_acting(tianhu)
	e_nil.add_state(1341)
	XImportedBalance.set_acting(null)
	check("no_save.1341_apply_unchanged", not e_nil.state_data.get("_stateCounter", {}).has("1341"), e_nil.state_data)
	e_nil.hp = 1e12
	var rc_nil := XResourceContext.new()
	var rng_nil := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc_nil.random = rng_nil
	XStateEffects.run_one("react", e_nil, st1341, {
		"attacker": tianhu, "defender": e_nil, "item": sk7485, "value": 1000.0, "resources": rc_nil, "random": rng_nil, "execute": true
	})
	check("no_save.1341_react_unchanged", e_nil.hp == 1e12 and rng_nil.draws == 0, [e_nil.hp, rng_nil.draws])

	# 3) 回退开关：西游档下 PORT_CAOCAO_TIANHU = false 完整回退到未移植现状
	_make_xiyou(30)
	XStateEffects.PORT_CAOCAO_TIANHU = false
	XStateEffects.clear_diagnostics()
	var e_rb := _make_enemy(1e12, 1.33)
	XImportedBalance.set_acting(caocao)
	e_rb.add_state(106)
	XImportedBalance.set_acting(tianhu)
	e_rb.add_state(1341)
	XImportedBalance.set_acting(null)
	check("rollback.1341_apply_off", not e_rb.state_data.get("_stateCounter", {}).has("1341"), e_rb.state_data)
	e_rb.state_data["_stackingPoison"] = 3.0
	e_rb.hp = 1e12
	XStateEffects.run_one("regenerate", e_rb, st106, {})
	check("rollback.106_regen_off", e_rb.hp == 1e12, e_rb.hp)
	var rc_rb := XResourceContext.new()
	var rng_rb := XRandomStream.create(XRandomStream.hex64(491), "battle")
	rc_rb.random = rng_rb
	XStateEffects.run_one("react", e_rb, st1341, {
		"attacker": tianhu, "defender": e_rb, "item": sk7485, "value": 1000.0, "resources": rc_rb, "random": rng_rb, "execute": true
	})
	check("rollback.1341_react_off", e_rb.hp == 1e12 and rng_rb.draws == 0 and rc_rb.started_popups.is_empty(),
		[e_rb.hp, rng_rb.draws, rc_rb.started_popups])
	check("rollback.diagnostics_restored", XStateEffects.diagnostics.any(func(d): return int(d.state) == 106 and d.phase == "regenerate")
		and XStateEffects.diagnostics.any(func(d): return int(d.state) == 1341 and d.phase == "apply")
		and XStateEffects.diagnostics.any(func(d): return int(d.state) == 1341 and d.phase == "react"), XStateEffects.diagnostics)
	XStateEffects.PORT_CAOCAO_TIANHU = true
