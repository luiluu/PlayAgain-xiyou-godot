extends Node
## 【小A·未经审查】T468 西游档法宝 99 级总数值对齐原版 888 级专项（O-662，XMagicWeapon.SCALE_99_TO_888）：
## 1) 仅西游档（not XTianqi.active 且 LEVEL_99 开）生效，无存档／天启篇零改动，独立开关 SCALE_99_TO_888 可秒级回退；
## 2) 1 / 50 / 99 级线性折算，99 级精确对齐原版 888 级总值（全库 222 件法宝、含负成长紫电与武器法宝麒麟对剑）；
## 3) 老存档 >99 级（331 / 888 / 1000 级）防爆封顶且不降级，存档往返保持等级；
## 4) 三法宝 60 级进化翻倍（XThreeGrowth）、织神天梭（XYunshang）、装备/角色战力（XPower）与 XActor.param_plus 全部一致无重复放大；
## 5) 说明卡（XHelpCard.content / detail_rows）在西游档与实算一致、隐藏旧静态误导行、不改写装备备注与数据库原件。
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


## 2) 1 / 50 / 99 / 331 / 888 / 1000 级与老存档防爆、负成长、武器法宝、存档往返
func _test_levels_and_old_save() -> void:
	var s := _make_xiyou(30)
	# 普通法宝：123 诛仙剑（全属性每级 +18）
	var zhuxian := XGear.template("armor", 123)
	var expected := {
		1: roundf(1.0 * 888.0 / 99.0 * 18.0),
		50: roundf(50.0 * 888.0 / 99.0 * 18.0),
		99: 888.0 * 18.0,
		331: 888.0 * 18.0,
		888: 888.0 * 18.0,
		1000: 1000.0 * 18.0,
	}
	for lv in [1, 50, 99, 331, 888, 1000]:
		zhuxian["level"] = lv
		var got := XActor.magic_param(zhuxian, 2)
		check("zhuxian.lv%d" % lv, is_equal_approx(got, expected[lv]), [lv, got, expected[lv]])
		# 不超过原版上限（≤888 级）且不低于原等级属性
		if lv <= 888:
			check("zhuxian.lv%d.bounds" % lv, got >= float(lv) * 18.0 and got <= 888.0 * 18.0, [lv, got])
		else:
			check("zhuxian.lv%d.extreme_no_explode" % lv, is_equal_approx(got, float(lv) * 18.0), [lv, got])
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

	# 老存档 331 级穿在角色身上：不降级、属性不爆表、存档往返保持 331 级
	var a := s.actor(1)
	zhuxian["level"] = 331
	var slot := a.equip_slots().find(13)
	a.equips[slot] = zhuxian
	a.refresh_passive()
	var base_atk := float(zhuxian.params[2])
	var naked := XEquipment.clone(a)
	naked.equips[slot] = null
	naked.refresh_passive()
	var delta_atk := a.param_plus(2) - naked.param_plus(2)
	check("old_save_331.actor_param_plus", is_equal_approx(delta_atk, base_atk + 888.0 * 18.0), [delta_atk, base_atk + 888.0 * 18.0])
	check("old_save_331.level_not_downgraded", int(XMagicWeapon.level_of(zhuxian)) == 331, XMagicWeapon.level_of(zhuxian))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var reloaded := XState.from_dict(saved)
	XState.current = reloaded
	var re_item: Dictionary = reloaded.actor(1).equips[slot]
	check("old_save_331.roundtrip", int(XMagicWeapon.level_of(re_item)) == 331 and is_equal_approx(XActor.magic_param(re_item, 2), 888.0 * 18.0),
		[XMagicWeapon.level_of(re_item), XActor.magic_param(re_item, 2)])

	# 负成长法宝：3672 紫电（agi -35/级）
	var zidian := XGear.template("armor", 3672)
	zidian["level"] = 1
	check("zidian.lv1_neg", is_equal_approx(XActor.magic_param(zidian, 6), roundf(1.0 * 888.0 / 99.0 * -35.0)), XActor.magic_param(zidian, 6))
	zidian["level"] = 99
	check("zidian.lv99_exact", is_equal_approx(XActor.magic_param(zidian, 6), 888.0 * -35.0), XActor.magic_param(zidian, 6))
	zidian["level"] = 331
	check("zidian.lv331_cap", is_equal_approx(XActor.magic_param(zidian, 6), 888.0 * -35.0), XActor.magic_param(zidian, 6))

	# 武器法宝：73 麒麟对剑（mhp +100, mmp +100, mat +50）
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
		# 老存档 331 级进化后防爆封顶在 888 × 72 / 888 × 36
		relic["level"] = 331
		check("three.%d.post60_lv331_cap" % fid,
			is_equal_approx(XActor.magic_param(relic, hi_i), 888.0 * 72.0)
			and is_equal_approx(XActor.magic_param(relic, lo_i), 888.0 * 36.0),
			[XActor.magic_param(relic, hi_i), XActor.magic_param(relic, lo_i)])


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
	shuttle["level"] = 331
	var rp331 := XYunshang.relic_params(shuttle)
	check("yunshang.lv331_cap", is_equal_approx(float(rp331[4]), base_mat + 888.0 * 51.0), rp331[4])

	# XPower.equipment：99 级在折算开时与关折算 888 级评分完全一致，切换开关缓存不串味
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
	sword["level"] = 331
	var p331_scaled := float(XPower.equipment(sword).total)
	check("power.lv99_equals_orig888", is_equal_approx(p99_scaled, p888_orig) and p99_scaled > p99_unscaled,
		[p99_scaled, p888_orig, p99_unscaled])
	check("power.lv331_capped_at_888", is_equal_approx(p331_scaled, p888_orig), [p331_scaled, p888_orig])
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

	# a2) 旧档等级高于本层上限但未满 99（如 1 层 Lv.50）
	zx["level"] = 50
	var zx50_f1 := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.zhuxian_lv50_over_floor_cap",
		zx50_f1.contains("加成：法宝当前（Lv.50/99，本层上限12）累计 全属性+%d" % int(XActor.magic_param(zx, 0))),
		zx50_f1)

	# b) 诛仙剑 Lv.99（30 层上限 99）
	s.set_variable(20, 30)
	zx["level"] = 99
	var zx99_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.zhuxian_lv99_match",
		zx99_join.contains("加成：法宝满级（Lv.99/99）累计 全属性+15984")
		and not zx99_join.contains("法宝当前"),
		zx99_join)
	# detail_rows 也一致
	var zx99_detail := "\n".join(PackedStringArray(_plain_rows(XHelpCard.detail_rows(zx, 380.0))))
	check("card.detail_rows_match", zx99_detail.contains("加成：法宝满级（Lv.99/99）累计 全属性+15984"), zx99_detail)

	# c) 老存档 331 级与 1000 级
	zx["level"] = 331
	var zx331_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.old331_note",
		zx331_join.contains("加成：法宝当前（旧档Lv.331，超出现行上限，按99级满级加成计）累计 全属性+15984"),
		zx331_join)
	zx["level"] = 1000
	var zx1000_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(zx))))
	check("card.old1000_note",
		zx1000_join.contains("加成：法宝当前（旧档Lv.1000，高于满级，按原等级加成计）累计 全属性+18000"),
		zx1000_join)

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

	# f) 织神天梭 7935：顶部八项与实算一致，旧每级成长行已替换；旧档 331 级带超上限提示
	var ys := XGear.template("armor", XYunshang.RELIC)
	ys["level"] = 99
	var ys_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(ys))))
	check("card.yunshang_match",
		ys_join.contains("魔攻/敏捷+45288；其余全属性+15984")
		and not ys_join.contains("每级成长："),
		ys_join)
	ys["level"] = 331
	var ys331_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(ys))))
	check("card.yunshang_old331_hint",
		ys331_join.contains("当前等级：331 / 99（旧档超上限）")
		and ys331_join.contains("旧档Lv.331，超出现行上限，按99级满级加成计"),
		ys331_join)

	# g) 饿狼破限之心 7904：等级上限 99，旧每级成长行已替换；旧档 331 级带超上限提示
	var gr := XGear.template("armor", 7904)
	gr["level"] = 50
	var gr_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(gr))))
	check("card.garou_match",
		gr_join.contains("等级上限：99")
		and gr_join.contains("当前等级：50 / 99；经验：")
		and gr_join.contains("满级（99级）累计")
		and not gr_join.contains("每级成长："),
		gr_join)
	gr["level"] = 331
	var gr331_join := "\n".join(PackedStringArray(_plain_rows(XHelpCard.content(gr))))
	check("card.garou_old331_hint",
		gr331_join.contains("当前等级：331 / 99（旧档超上限）；经验："),
		gr331_join)


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

	# d) 天启篇零改动（无论 FABAO_TABLE 开还是关，都不受 SCALE_99_TO_888 影响）
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
