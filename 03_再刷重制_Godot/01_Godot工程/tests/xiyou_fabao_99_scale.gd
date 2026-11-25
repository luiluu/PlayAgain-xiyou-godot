extends Node
## 【小A·未经审查】T468＋T476 西游档法宝 99 级总数值对齐原版 888 级＋老存档 >99 级折算与楼层上限专项（O-662）：
## 1) 仅西游档（not XTianqi.active 且 LEVEL_99 开）生效，无存档／天启篇零改动，独立开关 SCALE_99_TO_888 可秒级回退；
## 2) 1 / 50 / 99 级线性折算，99 级精确对齐原版 888 级总值（全库 222 件法宝、含负成长紫电与武器法宝麒麟对剑）；
## 3) T476 读档迁移：老存档 >99 级（331→37 / 888→99 / 1000→99 封顶）写回折算等级、加迁移标记只折一次（重复读档不再折），≤99 级不动；
## 4) T476 楼层上限：折算后与 ≤99 级超本层上限的按上限生效、存档保留折算值，层数上限提高后自动恢复、不丢等级；
## 5) 三法宝 60 级进化翻倍（XThreeGrowth）、织神天梭（XYunshang）、装备/角色战力（XPower）与 XActor.param_plus 全部一致无重复放大；
## 6) 说明卡（XHelpCard.content / detail_rows）去掉「旧档超上限」「高于满级按原等级加成计」等旧行，按折算后／本层生效等级正常显示。
var passed := 0
var total := 0


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


func _plain_rows(rows: Array) -> Array:
	return rows.map(func(r): return XHelpCard.plain(str(r[0])).replace("\\lock[1]", ""))


func _run() -> void:
	var was_l99 := XMagicWeapon.LEVEL_99
	var was_floor := XMagicWeapon.FLOOR_CAP
	var was_scale := XMagicWeapon.SCALE_99_TO_888
	var was_p4 := XTianqiBase.PHASE4
	var was_fbt := XTianqiGear.FABAO_TABLE
	var was_pw := XPower.SHOW_POWER_UI

	XMagicWeapon.LEVEL_99 = true
	XMagicWeapon.FLOOR_CAP = true
	XMagicWeapon.SCALE_99_TO_888 = true

	_test_db_all_222()
	_test_levels_and_old_save()
	_test_three_growth()
	_test_yunshang_and_power()
	_test_caps_and_feed_unchanged()
	_test_help_cards()
	_test_rollback_and_isolation()

	XMagicWeapon.LEVEL_99 = was_l99
	XMagicWeapon.FLOOR_CAP = was_floor
	XMagicWeapon.SCALE_99_TO_888 = was_scale
	XTianqiBase.PHASE4 = was_p4
	XTianqiGear.FABAO_TABLE = was_fbt
	XPower.SHOW_POWER_UI = was_pw
	XPower.clear_cache()
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


## 1) 全库 222 件法宝（3 武器 + 219 防具）：原上限均 888，西游档 99 级精确等于 888 × 原始每级成长
func _test_db_all_222() -> void:
	_make_xiyou(30)
	var count := 0
	var max_ok := 0
	var exact99_ok := 0
	for pair in [["weapon", "Weapons"], ["armor", "Armors"]]:
		var kind: String = pair[0]
		var table: Array = XDB.table(pair[1])
		for rec in table:
			if not (rec is Dictionary) or not XMagicWeapon.is_magic(rec):
				continue
			count += 1
			if is_equal_approx(XMagicWeapon.raw_max_level(rec), 888.0):
				max_ok += 1
			var inst := XGear.template(kind, int(rec.id))
			inst["level"] = 99
			var per := XActor.magic_per_level(inst)
			var all_match := true
			for i in range(8):
				if not is_equal_approx(XActor.magic_param(inst, i), 888.0 * float(per[i])):
					all_match = false
					break
			if all_match:
				exact99_ok += 1
	check("db.count_222", count == 222, count)
	check("db.all_raw_max_888", max_ok == count, [max_ok, count])
	check("db.all_99_exact_888", exact99_ok == count, [exact99_ok, count])


## 2) 1 / 50 / 99 级折算＋T476 老存档 >99 级（331/888/1000）读档折算、迁移标记防重折、楼层上限生效与升层恢复
func _test_levels_and_old_save() -> void:
	var s := _make_xiyou(30)
	# 普通法宝：123 诛仙剑（全属性每级 +18）
	var zhuxian := XGear.template("armor", 123)
	var expected := {
		1: roundf(1.0 * 888.0 / 99.0 * 18.0),
		12: roundf(12.0 * 888.0 / 99.0 * 18.0),
		24: roundf(24.0 * 888.0 / 99.0 * 18.0),
		37: roundf(37.0 * 888.0 / 99.0 * 18.0),
		50: roundf(50.0 * 888.0 / 99.0 * 18.0),
		99: 888.0 * 18.0,
	}
	for lv in [1, 12, 24, 37, 50, 99]:
		zhuxian["level"] = lv
		var got := XActor.magic_param(zhuxian, 2)
		check("zhuxian.lv%d" % lv, is_equal_approx(got, expected[lv]), [lv, got, expected[lv]])
	# 1..99 级单调递增
	var mono := true
	var prev := -1.0
	for lv in range(1, 100):
		zhuxian["level"] = lv
		var cur := XActor.magic_param(zhuxian, 0)
		if cur < prev:
			mono = false
			break
		prev = cur
	check("zhuxian.monotonic_1_99", mono)

	# 折算公式核对：888→99、331→37、1000→99 封顶、100→11
	check("convert.formula",
		XMagicWeapon.convert_old_level(888.0) == 99
		and XMagicWeapon.convert_old_level(331.0) == 37
		and XMagicWeapon.convert_old_level(1000.0) == 99
		and XMagicWeapon.convert_old_level(100.0) == 11,
		[XMagicWeapon.convert_old_level(888.0), XMagicWeapon.convert_old_level(331.0), XMagicWeapon.convert_old_level(1000.0), XMagicWeapon.convert_old_level(100.0)])

	# T476 读档迁移（低楼层 1 层，上限 12）：331→37（穿戴）、888→99（背包）、1000→99（仓库）、99→99（背包）、50→50（穿戴在队友）
	var old_s := _make_xiyou(1)
	var a1 := old_s.actor(1)
	old_s.add_actor(2)
	var a2 := old_s.actor(2)
	var slot1 := a1.equip_slots().find(13)
	var slot2 := a2.equip_slots().find(13)
	var eq_331 := XGear.template("armor", 123)
	eq_331["level"] = 331.0
	eq_331["exp"] = 250000.0
	a1.equips[slot1] = eq_331
	var eq_50 := XGear.template("armor", 123)
	eq_50["level"] = 50.0
	eq_50["exp"] = 123.0
	a2.equips[slot2] = eq_50
	var bag_888 := XGear.template("armor", 123)
	bag_888["level"] = 888.0
	bag_888["exp"] = 999999.0
	old_s.register_gear(bag_888)
	old_s.gear.append(bag_888)
	var bag_99 := XGear.template("armor", 123)
	bag_99["level"] = 99.0
	bag_99["exp"] = 456.0
	old_s.register_gear(bag_99)
	old_s.gear.append(bag_99)
	var wh_1000 := XGear.template("armor", 123)
	wh_1000["level"] = 1000.0
	wh_1000["exp"] = 888888.0
	old_s.register_gear(wh_1000)
	old_s.warehouses["仓库"] = {"title": "仓库", "maxCapacity": 99, "currentCapacity": 1, "rule": null, "lootBonus": true,
		"items": {"item": [], "weapon": [], "armor": [wh_1000], "keyItem": []}, "qtty": {"item": {}, "weapon": {}, "armor": {}, "keyItem": {}}}
	var raw_old: Dictionary = JSON.parse_string(JSON.stringify(old_s.to_dict()))
	var loaded := XState.from_dict(raw_old)
	XState.current = loaded
	var ld_331: Dictionary = loaded.actor(1).equips[slot1]
	var ld_50: Dictionary = loaded.actor(2).equips[slot2]
	var ld_888: Dictionary = loaded.gear[0]
	var ld_99: Dictionary = loaded.gear[1]
	var ld_1000: Dictionary = loaded.warehouses["仓库"].items.armor[0]
	check("migrate.levels_written_back",
		int(XMagicWeapon.level_of(ld_331)) == 37
		and int(XMagicWeapon.level_of(ld_888)) == 99
		and int(XMagicWeapon.level_of(ld_1000)) == 99
		and int(XMagicWeapon.level_of(ld_99)) == 99
		and int(XMagicWeapon.level_of(ld_50)) == 50,
		[XMagicWeapon.level_of(ld_331), XMagicWeapon.level_of(ld_888), XMagicWeapon.level_of(ld_1000), XMagicWeapon.level_of(ld_99), XMagicWeapon.level_of(ld_50)])
	check("migrate.exp_sanitized_and_le99_kept",
		is_equal_approx(XMagicWeapon.exp_of(ld_331), 0.0)
		and is_equal_approx(XMagicWeapon.exp_of(ld_888), 0.0)
		and is_equal_approx(XMagicWeapon.exp_of(ld_1000), 0.0)
		and is_equal_approx(XMagicWeapon.exp_of(ld_99), 456.0)
		and is_equal_approx(XMagicWeapon.exp_of(ld_50), 123.0),
		[XMagicWeapon.exp_of(ld_331), XMagicWeapon.exp_of(ld_99), XMagicWeapon.exp_of(ld_50)])
	check("migrate.flag_set", bool(loaded.flags.get(XMagicWeapon.OLD_LEVEL_MIGRATE_MARK, false)), loaded.flags)

	# 1 层上限 12：全部超上限的法宝按 12 级生效，存档保留折算值（37/99/50）不丢等级
	var base_atk := float(ld_331.params[2])
	var naked1 := XEquipment.clone(loaded.actor(1))
	naked1.equips[slot1] = null
	naked1.refresh_passive()
	var delta_f1 := loaded.actor(1).param_plus(2) - naked1.param_plus(2)
	check("floor1.effective_capped_at_12",
		int(XMagicWeapon.effective_level(ld_331)) == 12
		and int(XMagicWeapon.effective_level(ld_888)) == 12
		and int(XMagicWeapon.effective_level(ld_1000)) == 12
		and int(XMagicWeapon.effective_level(ld_99)) == 12
		and int(XMagicWeapon.effective_level(ld_50)) == 12
		and is_equal_approx(XActor.magic_param(ld_331, 2), expected[12])
		and is_equal_approx(delta_f1, base_atk + expected[12]),
		[XMagicWeapon.effective_level(ld_331), XActor.magic_param(ld_331, 2), delta_f1, base_atk + expected[12]])

	# 低楼层存盘再重复读档：存档保留 37/99/50（不砍成 12），且不再重复折算
	var saved_f1: Dictionary = JSON.parse_string(JSON.stringify(loaded.to_dict()))
	var reload2 := XState.from_dict(saved_f1)
	XState.current = reload2
	var r2_331: Dictionary = reload2.actor(1).equips[slot1]
	var r2_50: Dictionary = reload2.actor(2).equips[slot2]
	var r2_888: Dictionary = reload2.gear[0]
	var r2_99: Dictionary = reload2.gear[1]
	var r2_1000: Dictionary = reload2.warehouses["仓库"].items.armor[0]
	check("repeat_load.keeps_converted_levels",
		int(XMagicWeapon.level_of(r2_331)) == 37
		and int(XMagicWeapon.level_of(r2_888)) == 99
		and int(XMagicWeapon.level_of(r2_1000)) == 99
		and int(XMagicWeapon.level_of(r2_99)) == 99
		and int(XMagicWeapon.level_of(r2_50)) == 50
		and int(XMagicWeapon.effective_level(r2_331)) == 12,
		[XMagicWeapon.level_of(r2_331), XMagicWeapon.effective_level(r2_331)])
	# 验证迁移标记确实阻止重复折算：已有标记的档即使手动塞入 200 级再读档，也不会触发二次迁移
	var probe_200 := XGear.template("armor", 123)
	probe_200["level"] = 200.0
	reload2.register_gear(probe_200)
	reload2.gear.append(probe_200)
	var reload3 := XState.from_dict(JSON.parse_string(JSON.stringify(reload2.to_dict())))
	XState.current = reload3
	check("repeat_load.marker_prevents_second_pass",
		int(XMagicWeapon.level_of(reload3.gear[2])) == 200,
		XMagicWeapon.level_of(reload3.gear[2]))
	# 仅含 ≤99 级法宝的干净西游档读档不改写任何字段、不写入迁移标记（与 save_roundtrip 逐字节一致）
	var clean_s := _make_xiyou(10)
	var clean_fb := XGear.template("armor", 123)
	clean_fb["level"] = 37.0
	clean_s.register_gear(clean_fb)
	clean_s.gear.append(clean_fb)
	var clean_before := JSON.stringify(clean_s.to_dict())
	var clean_after := XState.from_dict(JSON.parse_string(clean_before))
	check("clean_save.no_flag_and_exact_roundtrip",
		not clean_after.flags.has(XMagicWeapon.OLD_LEVEL_MIGRATE_MARK)
		and JSON.parse_string(clean_before) == JSON.parse_string(JSON.stringify(clean_after.to_dict())),
		clean_after.flags)
	XState.current = reload3

	# 升层自动恢复（不丢等级）：5 层上限 24 → 10 层上限 39（37 恢复）→ 20 层上限 69（50 恢复）→ 30 层上限 99（99 恢复）
	var r3_331: Dictionary = reload3.actor(1).equips[slot1]
	var r3_50: Dictionary = reload3.actor(2).equips[slot2]
	var r3_888: Dictionary = reload3.gear[0]
	reload3.set_variable(20, 5)
	var naked_r3 := XEquipment.clone(reload3.actor(1))
	naked_r3.equips[slot1] = null
	naked_r3.refresh_passive()
	check("floor_recover.floor5_cap24",
		int(XMagicWeapon.effective_level(r3_331)) == 24
		and is_equal_approx(XActor.magic_param(r3_331, 2), expected[24])
		and is_equal_approx(reload3.actor(1).param_plus(2) - naked_r3.param_plus(2), base_atk + expected[24]),
		[XMagicWeapon.effective_level(r3_331), XActor.magic_param(r3_331, 2)])
	reload3.set_variable(20, 10)
	check("floor_recover.floor10_lv37_restored",
		int(XMagicWeapon.effective_level(r3_331)) == 37
		and is_equal_approx(XActor.magic_param(r3_331, 2), expected[37])
		and is_equal_approx(reload3.actor(1).param_plus(2) - naked_r3.param_plus(2), base_atk + expected[37])
		and int(XMagicWeapon.effective_level(r3_50)) == 39,
		[XMagicWeapon.effective_level(r3_331), XMagicWeapon.effective_level(r3_50)])
	reload3.set_variable(20, 20)
	check("floor_recover.floor20_lv50_restored",
		int(XMagicWeapon.effective_level(r3_50)) == 50
		and is_equal_approx(XActor.magic_param(r3_50, 2), expected[50])
		and int(XMagicWeapon.effective_level(r3_888)) == 69,
		[XMagicWeapon.effective_level(r3_50), XMagicWeapon.effective_level(r3_888)])
	reload3.set_variable(20, 30)
	check("floor_recover.floor30_lv99_restored",
		int(XMagicWeapon.effective_level(r3_888)) == 99
		and is_equal_approx(XActor.magic_param(r3_888, 2), expected[99]),
		[XMagicWeapon.effective_level(r3_888), XActor.magic_param(r3_888, 2)])

	# 升级特性（Equip LevelUp Trait）与按等级学技能（Learn Skill）同样受生效等级限制
	var skill_fabao := XGear.template("armor", 123)
	skill_fabao["base"] = 999999  # 数据库无此号时 _base 退回实例本身，便于测试备注解析
	skill_fabao["id"] = 999999
	skill_fabao["level"] = 37.0
	skill_fabao["note"] = str(skill_fabao.note) + "\n<Magic Weapon Learn Skill 10: 25, 99>\n<Equip LevelUp Trait Armor: 1>"
	XMagicWeapon._learn_cache.clear()
	XMagicWeapon._trait_cache.clear()
	reload3.set_variable(20, 1)
	var sk_f1 := XMagicWeapon.item_skills(skill_fabao)
	var tr_f1 := XMagicWeapon.trait_objects([skill_fabao]).size()
	reload3.set_variable(20, 10)
	var sk_f10 := XMagicWeapon.item_skills(skill_fabao)
	var tr_f10 := XMagicWeapon.trait_objects([skill_fabao]).size()
	XMagicWeapon._learn_cache.clear()
	XMagicWeapon._trait_cache.clear()
	check("floor_cap.item_skills_and_traits",
		not sk_f1.has(10) and sk_f10.has(10) and tr_f1 == 12 and tr_f10 == 37,
		[sk_f1, sk_f10, tr_f1, tr_f10])

	# XSave.save / XSave.load_slot 落盘往返：旧档 331 级落盘后第一次读档折算 37 并打标记，再存再读保持 37
	var was_save_dir := XSave.dir_override
	var was_wh_path := XStarWarehouse.path_override
	var tmp_dir := OS.get_user_data_dir().path_join("test_xiyou_fabao_99_scale_save")
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	XSave.dir_override = tmp_dir
	var disk_s := _make_xiyou(1)
	var disk_zx := XGear.template("armor", 123)
	disk_zx["level"] = 331.0
	disk_s.register_gear(disk_zx)
	disk_s.gear.append(disk_zx)
	XSave.save(1)
	check("disk.load1_migrates",
		XSave.load_slot(1)
		and int(XMagicWeapon.level_of(XState.current.gear[0])) == 37
		and int(XMagicWeapon.effective_level(XState.current.gear[0])) == 12
		and bool(XState.current.flags.get(XMagicWeapon.OLD_LEVEL_MIGRATE_MARK, false)),
		[XMagicWeapon.level_of(XState.current.gear[0]), XMagicWeapon.effective_level(XState.current.gear[0])])
	XSave.save(1)
	check("disk.load2_idempotent",
		XSave.load_slot(1)
		and int(XMagicWeapon.level_of(XState.current.gear[0])) == 37
		and int(XMagicWeapon.effective_level(XState.current.gear[0])) == 12,
		[XMagicWeapon.level_of(XState.current.gear[0]), XMagicWeapon.effective_level(XState.current.gear[0])])
	# 跨存档星级仓库取出老 >99 级法宝到已迁移西游档：取出即折算 331→37
	var wh_file := tmp_dir.path_join("star_warehouse.json")
	XStarWarehouse.path_override = wh_file
	if FileAccess.file_exists(XStarWarehouse.path()):
		DirAccess.remove_absolute(XStarWarehouse.path())
	XStarWarehouse._loaded_path = ""
	XStarWarehouse.ensure_loaded()
	var wh_src := _make_xiyou(1)
	var wh_old := XGear.template("armor", 123)
	wh_old["level"] = 331.0
	wh_src.register_gear(wh_old)
	wh_src.gear.append(wh_old)
	XStarWarehouse.deposit_gear(wh_src, wh_old)
	XSave.load_slot(1)
	var pulled_ok := XStarWarehouse.withdraw_gear(XState.current, XStarWarehouse.gear()[0])
	var pulled_item: Dictionary = XState.current.gear[XState.current.gear.size() - 1]
	check("star_warehouse.withdraw_migrates",
		pulled_ok and int(XMagicWeapon.level_of(pulled_item)) == 37 and int(XMagicWeapon.effective_level(pulled_item)) == 12,
		[pulled_ok, XMagicWeapon.level_of(pulled_item), XMagicWeapon.effective_level(pulled_item)])
	XSave.remove(1)
	if FileAccess.file_exists(XStarWarehouse.path()):
		DirAccess.remove_absolute(XStarWarehouse.path())
	XStarWarehouse._loaded_path = ""
	XStarWarehouse.path_override = was_wh_path
	XSave.dir_override = was_save_dir
	XState.current = reload3

	# 负成长法宝：3672 紫电（agi -35/级）
	reload3.set_variable(20, 30)
	var zidian := XGear.template("armor", 3672)
	zidian["level"] = 1
	check("zidian.lv1_neg", is_equal_approx(XActor.magic_param(zidian, 6), roundf(1.0 * 888.0 / 99.0 * -35.0)), XActor.magic_param(zidian, 6))
	zidian["level"] = 99
	check("zidian.lv99_exact", is_equal_approx(XActor.magic_param(zidian, 6), 888.0 * -35.0), XActor.magic_param(zidian, 6))
	reload3.set_variable(20, 1)
	check("zidian.floor1_cap12", is_equal_approx(XActor.magic_param(zidian, 6), roundf(12.0 * 888.0 / 99.0 * -35.0)), XActor.magic_param(zidian, 6))

	# 武器法宝：73 麒麟对剑（mhp +100, mmp +100, mat +50）
	reload3.set_variable(20, 30)
	var kirin := XGear.template("weapon", 73)
	kirin["level"] = 99
	check("kirin.lv99_exact",
		is_equal_approx(XActor.magic_param(kirin, 0), 88800.0)
		and is_equal_approx(XActor.magic_param(kirin, 1), 88800.0)
		and is_equal_approx(XActor.magic_param(kirin, 4), 44400.0)
		and is_equal_approx(XActor.magic_param(kirin, 2), 0.0),
		[XActor.magic_param(kirin, 0), XActor.magic_param(kirin, 1), XActor.magic_param(kirin, 4), XActor.magic_param(kirin, 2)])
	# 数据库原件武器模板不查错表
	var kirin_db := XDB.rec("Weapons", 73)
	check("kirin.db_template_per", is_equal_approx(float(XActor.magic_per_level(kirin_db)[4]), 50.0), XActor.magic_per_level(kirin_db))


## 3) 三法宝 60 级进化（谷雨 7912、屠苏 4047、璇 4048）：进化前 18/36、进化后 36/72，99 级精确对齐 888 级，无重复放大、不污染 paramPlusPerLevel
func _test_three_growth() -> void:
	for row in [
		[175, 7912, 0, 1],  # 谷雨 百谷生：mhp(0) 额外项, mmp(1) 常规项
		[176, 4047, 2, 0],  # 屠苏 止戈环：atk(2) 额外项, mhp(0) 常规项
		[177, 4048, 3, 2],  # 璇 璇玑星盘：def(3) 额外项, atk(2) 常规项
	]:
		var aid: int = row[0]
		var fid: int = row[1]
		var hi_i: int = row[2]
		var lo_i: int = row[3]
		var s := _make_xiyou(30)
		s.actor_max_level = 99
		var a := s.actor(aid)
		a.change_level_mv(50)
		var relic := XGear.template("armor", fid)
		relic["level"] = 99
		check("three.%d.pre60_lv99" % fid,
			is_equal_approx(XActor.magic_param(relic, hi_i), 888.0 * 36.0)
			and is_equal_approx(XActor.magic_param(relic, lo_i), 888.0 * 18.0),
			[XActor.magic_param(relic, hi_i), XActor.magic_param(relic, lo_i)])
		check("three.%d.pre60_raw_per_clean" % fid,
			int(relic.paramPlusPerLevel[hi_i]) == 36 and int(relic.paramPlusPerLevel[lo_i]) == 18,
			relic.paramPlusPerLevel)
		# 进化到 60 级：成长翻倍，99 级精确等于 888 × 72 / 888 × 36
		a.change_level_mv(60)
		check("three.%d.post60_lv99" % fid,
			is_equal_approx(XActor.magic_param(relic, hi_i), 888.0 * 72.0)
			and is_equal_approx(XActor.magic_param(relic, lo_i), 888.0 * 36.0),
			[XActor.magic_param(relic, hi_i), XActor.magic_param(relic, lo_i)])
		check("three.%d.post60_raw_per_clean" % fid,
			int(relic.paramPlusPerLevel[hi_i]) == 72 and int(relic.paramPlusPerLevel[lo_i]) == 36,
			relic.paramPlusPerLevel)
		# 老存档 331 级进化后读档折算为 37 级：进化状态（_codex60Evolved、翻倍成长）保持，且低楼层 1 层按 12 级生效、30 层恢复 37 级
		s.set_variable(20, 1)
		relic["level"] = 331.0
		a.equips[a.equip_slots().find(13)] = relic
		var re_three := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
		XState.current = re_three
		var re_relic: Dictionary = re_three.actor(aid).equips[re_three.actor(aid).equip_slots().find(13)]
		check("three.%d.old331_evolved_kept_and_floor1" % fid,
			int(XMagicWeapon.level_of(re_relic)) == 37
			and int(XMagicWeapon.effective_level(re_relic)) == 12
			and bool(re_relic.get("_codex60Evolved", false))
			and XThreeGrowth.is_evolved(re_relic)
			and is_equal_approx(XActor.magic_param(re_relic, hi_i), roundf(12.0 * 888.0 / 99.0 * 72.0))
			and is_equal_approx(XActor.magic_param(re_relic, lo_i), roundf(12.0 * 888.0 / 99.0 * 36.0)),
			[XMagicWeapon.level_of(re_relic), XMagicWeapon.effective_level(re_relic), re_relic.get("_codex60Evolved"), XActor.magic_param(re_relic, hi_i)])
		re_three.set_variable(20, 30)
		check("three.%d.old331_evolved_recover37" % fid,
			int(XMagicWeapon.effective_level(re_relic)) == 37
			and is_equal_approx(XActor.magic_param(re_relic, hi_i), roundf(37.0 * 888.0 / 99.0 * 72.0))
			and is_equal_approx(XActor.magic_param(re_relic, lo_i), roundf(37.0 * 888.0 / 99.0 * 36.0)),
			[XMagicWeapon.effective_level(re_relic), XActor.magic_param(re_relic, hi_i), XActor.magic_param(re_relic, lo_i)])


## 4) 云裳织神天梭 7935 与 XPower.equipment / XPower.actor 一致性（含开关切换缓存不串味）
func _test_yunshang_and_power() -> void:
	var s := _make_xiyou(30)
	var shuttle := XGear.template("armor", XYunshang.RELIC)
	var base_mat := float(shuttle.params[4])
	var base_mhp := float(shuttle.params[0])
	shuttle["level"] = 99
	var rp99 := XYunshang.relic_params(shuttle)
	check("yunshang.lv99",
		is_equal_approx(float(rp99[4]), base_mat + 888.0 * 51.0)
		and is_equal_approx(float(rp99[0]), base_mhp + 888.0 * 18.0),
		[rp99[4], rp99[0]])
	shuttle["level"] = 37
	s.set_variable(20, 1)
	var rp37_f1 := XYunshang.relic_params(shuttle)
	check("yunshang.lv37_floor1_cap12", is_equal_approx(float(rp37_f1[4]), base_mat + roundf(12.0 * 888.0 / 99.0 * 51.0)), rp37_f1[4])
	s.set_variable(20, 30)
	var rp37_f30 := XYunshang.relic_params(shuttle)
	check("yunshang.lv37_floor30_recover", is_equal_approx(float(rp37_f30[4]), base_mat + roundf(37.0 * 888.0 / 99.0 * 51.0)), rp37_f30[4])

	# XPower.equipment：99 级在折算开时与关折算 888 级评分完全一致，低楼层按上限计、升层不串缓存
	XConfig.path_override = "user://test_xiyou_fabao_99_scale/options.json"
	XConfig.set_flag("codexPowerEnabled", true)
	XPower.clear_cache()
	var sword := XGear.template("armor", 123)
	sword["level"] = 99
	XMagicWeapon.SCALE_99_TO_888 = true
	var p99_scaled := float(XPower.equipment(sword).total)
	XMagicWeapon.SCALE_99_TO_888 = false
	var p99_unscaled := float(XPower.equipment(sword).total)
	sword["level"] = 888
	var p888_orig := float(XPower.equipment(sword).total)
	XMagicWeapon.SCALE_99_TO_888 = true
	sword["level"] = 37
	s.set_variable(20, 1)
	var p37_f1 := XPower.equipment(sword)
	s.set_variable(20, 10)
	var p37_f10 := XPower.equipment(sword)
	check("power.lv99_equals_orig888", is_equal_approx(p99_scaled, p888_orig) and p99_scaled > p99_unscaled,
		[p99_scaled, p888_orig, p99_unscaled])
	check("power.floor_cap_and_cache",
		int(p37_f1.level) == 12 and int(p37_f10.level) == 37 and float(p37_f10.total) > float(p37_f1.total),
		[p37_f1.level, p37_f1.total, p37_f10.level, p37_f10.total])
	XConfig.path_override = ""


## 5) 等级上限（99＋楼层上限）与吃装备／禁经验丹机制不变
func _test_caps_and_feed_unchanged() -> void:
	var s := _make_xiyou(1)
	var a := s.actor(1)
	var item := XGear.template("armor", 123)
	a.equips[a.equip_slots().find(13)] = item
	check("cap.floor1_is_12", int(XMagicWeapon.max_level(item)) == 12, XMagicWeapon.max_level(item))
	# 经验丹仍禁用（NO_PILLS）
	XMagicWeapon.plugin_command(s, PackedStringArray(["MagicWeaponAllGainExp", "1000000"]))
	check("feed.no_pills_unchanged", int(XMagicWeapon.level_of(item)) == 1, XMagicWeapon.level_of(item))
	# 吃装备仍正常升到本层上限 12 级
	var fodders := []
	for _k in range(6):
		var fodder := XGear.template("weapon", 1)
		s.register_gear(fodder)
		s.gear.append(fodder)
		fodders.append(fodder)
	var res := XFabaoFeed.feed(s, item, fodders, a, false)
	check("feed.eat_gear_works", int(res.used) == 6 and int(XMagicWeapon.level_of(item)) >= 2 and int(XMagicWeapon.level_of(item)) <= 12, res)
	s.set_variable(20, 30)
	check("cap.floor30_is_99", int(XMagicWeapon.max_level(item)) == 99, XMagicWeapon.max_level(item))


## 6) 说明卡与右侧详情显示与实算一致、无旧静态误导行、不改写原件
func _test_help_cards() -> void:
	var s := _make_xiyou(1)  # 1 层上限 12
	# a) 诛仙剑 Lv.1（floor cap 12）
	var zx := XGear.template("armor", 123)
	zx["level"] = 1
	var orig_note := str(zx.note)
	var zx_rows := _plain_rows(XHelpCard.content(zx))
	var zx_join := "\n".join(PackedStringArray(zx_rows))
	var expect_lv1 := int(XActor.magic_param(zx, 0))
	check("card.zhuxian_lv1_match",
		zx_join.contains("加成：法宝当前（Lv.1/本层上限12）累计 全属性+%d" % expect_lv1)
		and zx_join.contains("满级（99级）累计 全属性+15984")
		and not zx_join.contains("加成：法宝满级")
		and not zx_join.contains("法宝每级增加18全属性"),
		zx_rows)
	check("card.zhuxian_note_untouched", str(zx.note) == orig_note)

	# a2) 等级高于本层上限（如 1 层上限 12，折算后 Lv.37 或旧有 Lv.50）：按本层上限生效显示，保留原折算等级，无旧档超上限字样
	zx["level"] = 37
	var expect_lv12 := int(XActor.magic_param(zx, 0))
	var zx37_f1 := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.zhuxian_lv37_floor1_capped",
		zx37_f1.contains("加成：法宝当前（Lv.12/本层上限12，保留37级）累计 全属性+%d" % expect_lv12)
		and not zx37_f1.contains("旧档超上限")
		and not zx37_f1.contains("高于满级"),
		zx37_f1)
	s.set_variable(20, 10)  # 10 层上限 39：37 级自动恢复正常显示
	var expect_lv37 := int(XActor.magic_param(zx, 0))
	var zx37_f10 := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.zhuxian_lv37_floor10_restored",
		zx37_f10.contains("加成：法宝当前（Lv.37/本层上限39）累计 全属性+%d" % expect_lv37)
		and not zx37_f10.contains("保留37级"),
		zx37_f10)

	# b) 诛仙剑 Lv.99（30 层上限 99）与 1 层被限制后无「旧档超上限」
	s.set_variable(20, 1)
	zx["level"] = 99
	var zx99_f1 := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.zhuxian_lv99_floor1_capped",
		zx99_f1.contains("加成：法宝当前（Lv.12/本层上限12，保留99级）累计 全属性+%d" % expect_lv12)
		and not zx99_f1.contains("旧档超上限")
		and not zx99_f1.contains("高于满级"),
		zx99_f1)
	s.set_variable(20, 30)
	var zx99_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.zhuxian_lv99_match",
		zx99_join.contains("加成：法宝满级（Lv.99/99）累计 全属性+15984")
		and not zx99_join.contains("法宝当前")
		and not zx99_join.contains("旧档超上限")
		and not zx99_join.contains("高于满级"),
		zx99_join)
	# detail_rows 也一致
	var zx99_detail := "\n".join(PackedStringArray(_plain_rows(XHelpCard.detail_rows(zx, 380.0))))
	check("card.detail_rows_match", zx99_detail.contains("加成：法宝满级（Lv.99/99）累计 全属性+15984"), zx99_detail)

	# c2) 4563 雷符（张楚岚专属）：原备注「最大生命+500」对应 <mhp Param +500 per Level>，实算行准确体现 888×500=444000
	var leifu := XGear.template("armor", 4563)
	leifu["level"] = 99
	var lf_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(leifu))))
	check("card.leifu4563_scaled_mhp",
		lf_join.contains("加成：法宝满级（Lv.99/99）累计 生命+444000；其余全属性+17760")
		and not lf_join.contains("法宝每级增加20全属性"),
		lf_join)

	# d) 武器法宝 73 麒麟对剑：保留人物等级成长行，替换旧法宝每级行
	var kr := XGear.template("weapon", 73)
	kr["level"] = 99
	var kr_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(kr))))
	check("card.kirin_keeps_actor_growth",
		kr_join.contains("麒麟（可如法宝一样升级）")
		and kr_join.contains("随人物等级提升")
		and kr_join.contains("生命/魔法+88800；魔攻+44400")
		and not kr_join.contains("每级+50魔攻"),
		kr_join)

	# e) 三法宝百谷生 7912：未进化带「60级进化后加成翻倍」，进化后按翻倍总值显示且不重复提示，数据库原件不动
	s.actor_max_level = 99
	s.actor(175).change_level_mv(50)
	var bgs_db := XDB.rec("Armors", 7912)
	var bgs_pre := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(bgs_db))))
	check("card.three_growth_pre60_evo_hint",
		bgs_pre.contains("满级（99级）累计")
		and bgs_pre.contains("31968")
		and bgs_pre.contains("15984")
		and bgs_pre.contains("（60级进化后加成翻倍）")
		and not bgs_pre.contains("法宝每级："),
		bgs_pre)
	s.actor(175).change_level_mv(60)
	var bgs_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(bgs_db))))
	check("card.three_growth_evolved",
		bgs_join.contains("满级（99级）累计")
		and bgs_join.contains("63936")
		and bgs_join.contains("31968")
		and not bgs_join.contains("60级进化后加成翻倍")
		and not bgs_join.contains("法宝每级："),
		bgs_join)
	check("card.three_growth_db_untouched", str(bgs_db.name) == "百谷生")

	# f) 织神天梭 7935：顶部八项与实算一致，旧每级成长行已替换；无「旧档超上限」，低楼层按本层上限显示并保留折算值
	var ys := XGear.template("armor", XYunshang.RELIC)
	ys["level"] = 99
	var ys_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(ys))))
	check("card.yunshang_match",
		ys_join.contains("当前等级：99 / 99")
		and ys_join.contains("魔攻/敏捷+45288；其余全属性+15984")
		and not ys_join.contains("每级成长：")
		and not ys_join.contains("旧档超上限"),
		ys_join)
	s.set_variable(20, 1)
	ys["level"] = 37
	var ys37_f1 := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(ys))))
	check("card.yunshang_lv37_floor1",
		ys37_f1.contains("当前等级：12 / 12（保留37级）")
		and ys37_f1.contains("Lv.12/本层上限12，保留37级")
		and not ys37_f1.contains("旧档超上限")
		and not ys37_f1.contains("高于满级"),
		ys37_f1)
	s.set_variable(20, 30)

	# g) 饿狼破限之心 7904：等级上限 99，旧每级成长行已替换；无「旧档超上限」，低楼层按本层上限显示
	var gr := XGear.template("armor", 7904)
	gr["level"] = 50
	var gr_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(gr))))
	check("card.garou_match",
		gr_join.contains("等级上限：99")
		and gr_join.contains("当前等级：50 / 99；经验：")
		and gr_join.contains("满级（99级）累计")
		and not gr_join.contains("每级成长：")
		and not gr_join.contains("旧档超上限"),
		gr_join)
	s.set_variable(20, 1)
	gr["level"] = 37
	var gr37_f1 := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(gr))))
	check("card.garou_lv37_floor1",
		gr37_f1.contains("当前等级：12 / 12（保留37级）；经验：")
		and not gr37_f1.contains("旧档超上限")
		and not gr37_f1.contains("高于满级"),
		gr37_f1)
	s.set_variable(20, 30)


## 7) 开关回退与天启档隔离
func _test_rollback_and_isolation() -> void:
	# a) 关 SCALE_99_TO_888 回退到原版 99 级未放大
	_make_xiyou(30)
	var zx := XGear.template("armor", 123)
	zx["level"] = 99
	XMagicWeapon.SCALE_99_TO_888 = false
	check("rollback.scale_off_param", is_equal_approx(XActor.magic_param(zx, 2), 99.0 * 18.0), XActor.magic_param(zx, 2))
	var off_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("rollback.scale_off_card", off_join.contains("法宝每级增加18全属性") and not off_join.contains("法宝满级"), off_join)

	# b) 关 LEVEL_99 时即使 SCALE_99_TO_888 开也自动关闭折算
	XMagicWeapon.SCALE_99_TO_888 = true
	XMagicWeapon.LEVEL_99 = false
	check("rollback.level99_off_disables_scale",
		not XMagicWeapon.scale_active(zx) and is_equal_approx(XActor.magic_param(zx, 2), 99.0 * 18.0),
		XActor.magic_param(zx, 2))
	XMagicWeapon.LEVEL_99 = true

	# c) 无存档上下文不启用
	XState.current = null
	check("isolation.no_state", not XMagicWeapon.scale_active(zx) and is_equal_approx(XActor.magic_param(zx, 2), 99.0 * 18.0))

	# d) 天启篇零改动（无论 FABAO_TABLE 开还是关，都不受 SCALE_99_TO_888 影响，读档不迁移、不写标记）
	var tq_s := _make_tianqi(1)
	var tq_old := XGear.template("armor", 123)
	tq_old["level"] = 331.0
	tq_s.register_gear(tq_old)
	tq_s.gear.append(tq_old)
	var tq_loaded := XState.from_dict(JSON.parse_string(JSON.stringify(tq_s.to_dict())))
	XState.current = tq_loaded
	check("isolation.tianqi_no_migrate",
		int(XMagicWeapon.level_of(tq_loaded.gear[0])) == 331
		and int(XMagicWeapon.effective_level(tq_loaded.gear[0])) == 331
		and not tq_loaded.flags.has(XMagicWeapon.OLD_LEVEL_MIGRATE_MARK),
		[XMagicWeapon.level_of(tq_loaded.gear[0]), tq_loaded.flags])
	_make_tianqi(30)
	XTianqiBase.PHASE4 = true
	XTianqiGear.FABAO_TABLE = true
	XMagicWeapon.SCALE_99_TO_888 = true
	var tq_table_on := XActor.magic_param(zx, 2)
	var tq_card_on := _plain_rows(XHelpCard.content(zx))
	XMagicWeapon.SCALE_99_TO_888 = false
	var tq_table_off := XActor.magic_param(zx, 2)
	var tq_card_off := _plain_rows(XHelpCard.content(zx))
	check("isolation.tianqi_table_on", is_equal_approx(tq_table_on, tq_table_off) and tq_card_on == tq_card_off,
		[tq_table_on, tq_table_off])

	XTianqiGear.FABAO_TABLE = false
	XMagicWeapon.SCALE_99_TO_888 = true
	var tq_raw_on := XActor.magic_param(zx, 2)
	XMagicWeapon.SCALE_99_TO_888 = false
	var tq_raw_off := XActor.magic_param(zx, 2)
	check("isolation.tianqi_table_off",
		is_equal_approx(tq_raw_on, 99.0 * 18.0) and is_equal_approx(tq_raw_on, tq_raw_off),
		[tq_raw_on, tq_raw_off])
	XMagicWeapon.SCALE_99_TO_888 = true
