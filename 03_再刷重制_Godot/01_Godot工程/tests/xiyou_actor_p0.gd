extends Node
## 角色模板 P0／P1：普通角色 11～131 与导入角色 141／142 的招募路径与基础战斗基线（能力曲线／伤害由 xiyou_rules 逐项对照 slice 参照）。
## 本测试补三件事：①招募——原版「召唤…」公共事件真的能让该角色入队、占出战栏；②初始装备与已学技能与 mv_oracle
## 参照行一致；③每个声明可用的角色在参照里都有独立行（等级采样 35／65／99 与伤害行），没有就不算可用。
## 完整养成（技能树、进阶、羁绊）不在 P0 范围：本测试不验也不声明。

## 公共事件 → 角色（由 db/CommonEvents 里的 129 指令得出；斯盖＝召唤苍龙骑士，克莱德＝召唤祭祀，克洛什＝召唤绿色游侠，雪清寒＝召唤雪山）
const RECRUIT := {13: 11, 23: 12, 20: 13, 21: 14, 22: 15, 19: 16, 24: 17, 25: 18}
## 第二批（角色 19～40，同样由 129 指令得出；摇光的公共事件就叫「摇光」，涅斐莉的是 1208）
const RECRUIT_2 := {26: 19, 27: 20, 29: 21, 30: 22, 31: 23, 32: 24, 33: 25, 69: 26, 70: 27, 71: 28, 86: 29, 87: 30, 90: 31, 1208: 32, 97: 33, 125: 34, 131: 35, 139: 36, 138: 37, 133: 38, 140: 39, 141: 40}
## 第三批（角色 41～60，同样由 129 指令得出；孙悟空 52 是「小明邀请函」）
const RECRUIT_3 := {153: 41, 154: 42, 155: 43, 156: 44, 157: 45, 258: 46, 158: 47, 159: 48, 160: 49, 162: 50, 257: 51, 698: 52, 259: 53, 260: 54, 261: 55, 263: 56, 264: 57, 265: 58, 321: 59, 322: 60}
## 第四批（角色 61～80，同样由 129 指令得出；阿语用 399，374「召唤阿玉」是另一入口）
const RECRUIT_4 := {323: 61, 326: 62, 329: 63, 333: 64, 380: 65, 327: 66, 337: 67, 332: 68, 341: 69, 338: 70, 342: 71, 399: 72, 405: 73, 389: 74, 394: 75, 530: 76, 685: 77, 529: 78, 832: 79, 818: 80}
## 第五批（角色 81～100，同样由 129 指令得出，每人一个「召唤…」入口；八重樱 92 自带法宝赤染樱，法宝每级成长已做 dev.111）
const RECRUIT_5 := {1082: 81, 1096: 82, 869: 83, 1334: 84, 1502: 85, 1603: 86, 1611: 87, 1609: 88, 1623: 89, 1509: 90, 1511: 91, 1515: 92, 1539: 93, 1212: 94, 1535: 95, 1652: 96, 1536: 97, 1537: 98, 1557: 99, 1650: 100}
## 第六批（角色 101～131，除 108 奈叶〔独立击杀归属模块〕与空位 116／125／126；同样由 129 指令得出）
const RECRUIT_6 := {1651: 101, 1649: 102, 1538: 103, 1405: 104, 1534: 105, 1575: 106, 1665: 107, 1667: 109, 1655: 115, 1653: 117, 1660: 118, 1661: 119, 1658: 120, 1659: 121, 1668: 122, 1669: 123, 1654: 124, 1657: 127, 1656: 128, 1662: 129, 1663: 130, 1664: 131}
## 第七批：导入角色 141 女儿国王、142 天海麒麟星（CE2501／2502「招募_…」的 129 指令）。两人造成的伤害结算 ×0.01 由
## XImportedBalance 在结算处缩放（xiyou_imported_balance 对照；163 琦玉为 ×0.001，其技能必中／免反击反射由 XQiyu 管，xiyou_qiyu 对照）；参照伤害行是 makeDamageValue，原版模块不缩放这一层，与 Godot 的 XDamage.calculate 一致
const RECRUIT_7 := {2501: 141, 2502: 142, 2506: 146, 2507: 147, 2508: 148, 2509: 149, 2510: 150, 2511: 151, 2512: 152, 2513: 153, 2514: 154, 2515: 155, 2516: 156, 2518: 158, 2519: 159, 2521: 161, 2522: 162, 2523: 163, 2524: 164, 2525: 165, 2526: 166}
## 第八批：专属模块角色。178 哈基米的公共事件 9017 不是 129 指令，是脚本 CodexCat.recruit()（XCat.recruit：入队并装上法宝 7999 与练习剑 2，xiyou_cat 对照）
## 173 饿狼的公共事件 9009 是 try { if (!CodexGarou.recruit()) 还号角 } 脚本（XGarou.recruit：入队并装上法宝 7904）
## 169 黄泉 9004（CodexYomi.recruit()：入队并装上赤雨双缨 4578）、171 甚尔 9006（CodexToji.recruit()：入队并装上藏兵咒灵 4580）；170 镜流 9005（CodexJingliu.recruit()：月魄剑匣 4579）
## 167 渡鸦 9002（CodexRaven.recruit()：入队、给冥河断罪镰 4001 进背包）、168 米拉 9003（CodexMira.recruit()：入队并装上黑龙心鳞 4577）
## 174 云裳 9010（CodexYunshang.recruit()：入队、本档第一次给织神天梭 7935 进背包）
const RECRUIT_8 := {9017: 178, 9009: 173, 9002: 167, 9003: 168, 9007: 172, 9004: 169, 9006: 171, 9005: 170, 9010: 174}
## 猫猫 110～114 不走公共事件：Map004 事件 57 一次给齐五只（129 指令），参照行／装备／技能照验，招募路径另在地图事件里
const CATS := [110, 111, 112, 113, 114]
const REGRESSION := [1, 8, 9, 10]
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_actor_p0"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/slice_d2.json"))
	if not d is Dictionary:
		_check("oracle_present", false)
		return _finish()
	# ③ 参照行齐全
	for id in REGRESSION + RECRUIT.values() + RECRUIT_2.values() + RECRUIT_3.values() + RECRUIT_4.values() + RECRUIT_5.values() + RECRUIT_6.values() + RECRUIT_7.values() + RECRUIT_8.values() + CATS:
		var row = d.actors.get(str(id))
		_check("oracle_row_%d" % id, row != null and row.has("lv1") and row.has("lv10Battle") and row.get("levelSamples", {}).size() == 3, id)
		var dmg = d.damage.filter(func(r): return r.get("actor") != null and int(r.actor) == id)
		_check("oracle_damage_%d" % id, dmg.size() > 0 and dmg.all(func(r): return not r.has("error")), [id, dmg.size()])
	# ② 初始装备与技能
	for id in REGRESSION + RECRUIT.values() + RECRUIT_2.values() + RECRUIT_3.values() + RECRUIT_4.values() + RECRUIT_5.values() + RECRUIT_6.values() + RECRUIT_7.values() + RECRUIT_8.values() + CATS:
		var row: Dictionary = d.actors[str(id)]
		var a := XActor.new().setup(id)
		var mv_equips = row.equips.filter(func(e): return e != null).map(func(e): return int(e.base))
		var my_equips = a.equips.filter(func(e): return e != null and not e.is_empty()).map(func(e): return int(e.base))
		_check("equips_%d" % id, my_equips == mv_equips, [my_equips, mv_equips])
		var my_skills = a.skills().map(func(s): return int(s.id))
		my_skills.sort()
		var mv_skills = row.skills.map(func(s): return int(s))
		var missing = mv_skills.filter(func(s): return not my_skills.has(s) and not _is_boot_passive(d, s))
		_check("skills_%d" % id, missing.is_empty(), missing)
	# ④ 升级后被动：追加行动几率（passiveAPLUS）与伤害属性覆盖（DamageElements），参照 actor_passive.json（进度审查 35% 补）
	_passive_levels()
	# ① 招募路径
	var s := XState.new_game(3, 1, [8, 10, 9])
	# 超强者（96、100 等）在地狱以下招不进来（installBossDifficultyRuntime，见 xiyou_super_acquire）：招募路径先开挑战开关 2494
	s.set_switch(2494, true)
	s.map_id = 4
	s.x = 14
	s.y = 23
	var map := XMapScene.new()
	add_child(map)
	for i in 4:
		await get_tree().process_frame
	var all_recruit := RECRUIT.duplicate()
	all_recruit.merge(RECRUIT_2)
	all_recruit.merge(RECRUIT_3)
	all_recruit.merge(RECRUIT_4)
	all_recruit.merge(RECRUIT_5)
	all_recruit.merge(RECRUIT_6)
	all_recruit.merge(RECRUIT_7)
	all_recruit.merge(RECRUIT_8)
	for ce in all_recruit:
		var id: int = all_recruit[ce]
		_check("not_in_party_before_%d" % id, not s.party.has(id))
		var waited := 0
		while map.busy and waited < 600:  # 上一个公共事件的尾声（提示、刷新）可能还占着地图
			await get_tree().process_frame
			waited += 1
		await map.run_common_event(ce)
		for i in 3:
			await get_tree().process_frame
		_check("recruit_%d" % id, s.party.has(id), [ce, s.party])
		var want_class: int = RECRUIT_CLASS_CHANGE.get(id, int(XDB.rec("Actors", id).classId))
		_check("recruit_actor_%d" % id, s.actor(id).actor_id == id and s.actor(id).class_id == want_class, [id, s.actor(id).class_id, want_class])
	_check("regression_party_kept", [1, 8, 9, 10].all(func(i): return s.party.has(i)), s.party)
	_check("battle_slots_five", s.battle_slots.size() == 5, s.battle_slots)
	_finish()


## 招募事件里用 321 改了职业的角色（原版参照见 fixtures/actor_change_oracle.json 的 recruit 组）：玛莎 CE29 16→21
const RECRUIT_CLASS_CHANGE := {21: 21}


## oracle 技能列表含开局被动（passives／starterPassives）；它们由 xiyou_rules 的 _make_actor 灌入，这里不重复
func _is_boot_passive(d: Dictionary, skill: int) -> bool:
	return d.passives.map(func(v): return int(v)).has(skill) or d.starterPassives.map(func(v): return int(v)).has(skill)


func _finish() -> void:
	var passed := results.filter(func(r): return r["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## actor_passive_probe：每个切片角色依次升到 1／10／35／65／99 级，已学技能、action_plus_set、被动缓存的 damageElement 逐项同参照
func _passive_levels() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/actor_passive.json"))
	if not ref is Dictionary:
		_check("actor_passive_present", false)
		return
	_check("actor_passive_cases", ref.cases.size() >= 200, ref.cases.size())
	var made := {}
	for c in ref.cases:
		var id := int(c.setup.actor)
		var lv := int(c.setup.level)
		var tag := "passive_%d_lv%d" % [id, lv]
		if not c.errors.is_empty():
			_check(tag + ".source_clean", false, c.errors)
			continue
		if not made.has(id):
			made[id] = XActor.new().setup(id)
		var a: XActor = made[id]
		a.change_level(lv)
		var mine = a.skills().map(func(s): return int(s.id))
		mine.sort()
		_check(tag + ".skills", mine == c.observed.skills.map(func(v): return int(v)), [mine, c.observed.skills])
		var aps := a.action_plus_set()
		var want: Array = c.observed.actionPlus
		var same := aps.size() == want.size()
		for i in mini(aps.size(), want.size()):
			same = same and absf(float(aps[i]) - float(want[i])) < 1e-6
		_check(tag + ".actionPlus", same, [aps, want])
		_check(tag + ".damageElement", int(a.passive_cache().get("damageElement", 0)) == int(c.observed.damageElement),
			[a.passive_cache().get("damageElement", 0), c.observed.damageElement])
