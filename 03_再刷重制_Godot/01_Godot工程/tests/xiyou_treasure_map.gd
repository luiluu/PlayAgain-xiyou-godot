extends Node
## 【cc·Pro·未经审查】藏宝图挖宝 XTreasureMap.run 的分支（cc pro-test-gaps 2026-11-14）。
## xiyou_common_scripts 用原版参照跑了公共事件 117、174～189 的整条流程，xiyou_treasure_batch 测批量使用；这里直接调 run，
## 用假宝点表（换掉 XTreasureMap._spots，物品／防具／武器／公共事件取数据库里真的编号）逐条核 core/treasure_map.gd 文件头写的
## 原版 Star_RomGetItems 规则：
## - 预掷池：长度不是 20 或已用次数 gn > 15 才重掷（gn = 15 不重掷），重掷后 20 个都在 1～9999、gn 归零；
## - 站在第一个没挖过的宝点上才挖（「挖宝成功」），否则只提示当前与目标位置，不扣图、不动 gn；只看这一个宝点；
## - 发奖：v % 80 <20 物品、<40 防具、<60 武器、其余预约公共事件，候选取第 v % 长度 个；先扣一张图，候选为空时还回来并提示
##   「获取X失败: 请重新使用」；无论成败 gn + 1、宝点记为挖过；
## - a～b 全挖过：整段清掉，同一次调用接着从 a 找；
## - 新源 v0.29 路径（V029_SPECS）：不看站位、不提示「挖宝成功」、四类候选都不空的宝点才算、扣的是这张图；背包没有这张图什么也不做；
##   公共事件对不上时按首尾找，同首尾后写的覆盖（1～10 落到 342／189）。

var results := []
var skipped := []

const TICKET := 212  # 特级藏宝图（V029_SPECS 第一行，公共事件 117，宝点 1～10）


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 数据库表里前 n 个有名字的编号
func _ids(table: String, n: int, skip := []) -> Array:
	var out := []
	var t = XDB.table(table)
	for r in t:
		if r is Dictionary and str(r.get("name", "")).strip_edges() != "" and not skip.has(int(r.id)):
			out.append(int(r.id))
			if out.size() == n:
				break
	return out


func _name(table: String, id: int) -> String:
	return str(XDB.rec(table, id).get("name", ""))


func _spot(id: int, map: int, x: int, y: int, item: Array, armor: Array, weapon: Array, common: Array) -> Dictionary:
	return {"id": id, "map": map, "x": x, "y": y, "item": item, "armor": armor, "weapon": weapon, "common": common, "ticket": TICKET}


func _pool(first: int) -> Array:
	var g := [first]
	for i in range(1, XTreasureMap.LENGTH):
		g.append(1000 + i)
	return g


func _run() -> void:
	var items := _ids("Items", 3, [TICKET])
	var armors := _ids("Armors", 2)
	var weapons := _ids("Weapons", 3)
	var commons := _ids("CommonEvents", 2)
	var maps := _ids("MapInfos", 2)
	if not check("data_present", items.size() == 3 and armors.size() == 2 and weapons.size() == 3 and commons.size() == 2 and maps.size() == 2):
		return finish()
	var m1: int = maps[0]
	var m2: int = maps[1]
	var saved_spots: Array = XTreasureMap._spots
	XTreasureMap._spots = [null,
		_spot(1, m1, 5, 6, items, armors, weapons, commons),
		_spot(2, m2, 7, 8, items, armors, weapons, commons),
		_spot(3, m1, 9, 9, [], [], [], [])]
	var s := XState.new_game_blank()
	XState.current = s
	s.gain_item(TICKET, 5)

	# ---- 不站在宝点上：只提示，不扣图 ----
	s.map_id = m2
	s.x = 1
	s.y = 2
	s.rom.g = _pool(5)
	s.rom.gn = 0
	s.rom.m = []
	var r := XTreasureMap.run(s, 1, 3)
	check("away_toasts", r.toasts == ["%s 坐标:1,2" % _name("MapInfos", m2), "目标位置:%s 5,6" % _name("MapInfos", m1)] and int(r.reserve) == 0, r)
	check("away_no_change", s.item_count(TICKET) == 5 and int(s.rom.gn) == 0 and (s.rom.m as Array).is_empty(), [s.item_count(TICKET), s.rom])

	# ---- 站在宝点 1：v=5 → 物品 items[5 % 3] ----
	s.map_id = m1
	s.x = 5
	s.y = 6
	var want_item: int = items[5 % 3]
	var had := s.item_count(want_item)
	r = XTreasureMap.run(s, 1, 3)
	check("dig_item_toasts", r.toasts == ["挖宝成功", "获得物品:" + _name("Items", want_item)], r.toasts)
	check("dig_item_gain", s.item_count(want_item) == had + 1 and s.item_count(TICKET) == 4, [s.item_count(want_item), s.item_count(TICKET)])
	check("dig_item_record", int(s.rom.gn) == 1 and s.rom.m == [1], s.rom)

	# ---- 宝点 1 挖过：目标换成宝点 2（只看这一个，不往后挖） ----
	r = XTreasureMap.run(s, 1, 3)
	check("next_spot_target", r.toasts.size() == 2 and str(r.toasts[1]) == "目标位置:%s 7,8" % _name("MapInfos", m2) and int(s.rom.gn) == 1, r.toasts)

	# ---- 宝点 2：v=25 → 防具 armors[25 % 2] ----
	s.map_id = m2
	s.x = 7
	s.y = 8
	s.rom.g[1] = 25
	var want_armor: int = armors[25 % 2]
	var armor_had := s.gear_count("armor", want_armor)
	r = XTreasureMap.run(s, 1, 3)
	check("dig_armor", r.toasts == ["挖宝成功", "获得防具:" + _name("Armors", want_armor)] and s.gear_count("armor", want_armor) == armor_had + 1
		and s.item_count(TICKET) == 3 and int(s.rom.gn) == 2 and s.rom.m == [1, 2], [r.toasts, s.rom])

	# ---- 宝点 3 候选全空：v=45 → 武器失败，图还回来，gn 照样 +1、记为挖过 ----
	s.map_id = m1
	s.x = 9
	s.y = 9
	s.rom.g[2] = 45
	r = XTreasureMap.run(s, 1, 3)
	check("dig_empty_refund", r.toasts == ["挖宝成功", "获取武器失败: 请重新使用"] and s.item_count(TICKET) == 3 and int(s.rom.gn) == 3
		and s.rom.m == [1, 2, 3], [r.toasts, s.item_count(TICKET), s.rom])
	for pair in [[5, "获取物品失败: 请重新使用"], [25, "获取防具失败: 请重新使用"], [65, "触发事件失败: 请重新使用"]]:
		s.rom.m = [1, 2]
		s.rom.g[int(s.rom.gn)] = int(pair[0])
		var gn0 := int(s.rom.gn)
		r = XTreasureMap.run(s, 1, 3)
		check("dig_empty_refund_%d" % int(pair[0]), r.toasts == ["挖宝成功", pair[1]] and s.item_count(TICKET) == 3 and int(r.reserve) == 0
			and int(s.rom.gn) == gn0 + 1, [r, s.item_count(TICKET)])

	# ---- 全挖过：清掉整段，同一次调用从宝点 1 找（站在 3 上，所以只提示宝点 1） ----
	s.rom.m = [1, 2, 3]
	var gn_before := int(s.rom.gn)
	r = XTreasureMap.run(s, 1, 3)
	check("cycle_reset", (s.rom.m as Array).is_empty() and r.toasts.size() == 2 and str(r.toasts[1]) == "目标位置:%s 5,6" % _name("MapInfos", m1)
		and int(s.rom.gn) == gn_before and s.item_count(TICKET) == 3, [s.rom.m, r.toasts])
	# 段外挖过的不受影响
	s.rom.m = [1, 2, 3, 7]
	XTreasureMap.run(s, 1, 3)
	check("cycle_reset_keeps_outside", s.rom.m == [7], s.rom.m)

	# ---- 武器、公共事件 ----
	s.rom.m = []
	s.map_id = m1
	s.x = 5
	s.y = 6
	s.rom.g = _pool(45)
	s.rom.gn = 0
	var want_weapon: int = weapons[45 % 3]
	var weapon_had := s.gear_count("weapon", want_weapon)
	r = XTreasureMap.run(s, 1, 3)
	check("dig_weapon", r.toasts == ["挖宝成功", "获得武器:" + _name("Weapons", want_weapon)] and s.gear_count("weapon", want_weapon) == weapon_had + 1, r.toasts)
	s.rom.m = []
	s.rom.g = _pool(79)
	s.rom.gn = 0
	var tickets := s.item_count(TICKET)
	r = XTreasureMap.run(s, 1, 3)
	var want_ce: int = commons[79 % 2]
	check("dig_common_reserve", r.toasts == ["挖宝成功", "触发事件:" + _name("CommonEvents", want_ce)] and int(r.reserve) == want_ce
		and s.item_count(TICKET) == tickets - 1, r)

	# ---- 预掷池 ----
	var custom := _pool(5)
	s.rom.m = [1]
	s.rom.g = custom.duplicate()
	s.rom.gn = XTreasureMap.REFRESH
	XTreasureMap.run(s, 1, 3)
	check("pool_kept_at_15", s.rom.g == custom and int(s.rom.gn) == XTreasureMap.REFRESH, s.rom)
	s.rom.gn = XTreasureMap.REFRESH + 1
	XTreasureMap.run(s, 1, 3)
	var g: Array = s.rom.g
	check("pool_reroll_over_15", int(s.rom.gn) == 0 and g.size() == XTreasureMap.LENGTH and g != custom and g.all(func(v): return int(v) >= 1 and int(v) <= 9999), s.rom)
	s.rom.g = [1, 2, 3]
	s.rom.gn = 0
	XTreasureMap.run(s, 1, 3)
	check("pool_reroll_bad_length", (s.rom.g as Array).size() == XTreasureMap.LENGTH and int(s.rom.gn) == 0, s.rom)

	# ---- 新源 v0.29 路径 ----
	if XTreasureMap.v029():
		_v029(s, items, armors, weapons, commons, m1)
	else:
		check("v029_runtime_absent_native", XTreasureMap.run(s, 1, 10, 117).toasts.size() > 0)
	XTreasureMap._spots = saved_spots
	finish()


func _v029(s: XState, items: Array, armors: Array, weapons: Array, commons: Array, m1: int) -> void:
	var full := _spot(1, m1, 5, 6, items, armors, weapons, commons)
	var partial := _spot(2, m1, 7, 8, items, [], weapons, commons)  # 少一类：不算
	var full3 := _spot(3, m1, 9, 9, items, armors, weapons, commons)
	XTreasureMap._spots = [null, full, partial, full3]
	s.items.erase(TICKET)
	s.rom.g = _pool(5)
	s.rom.gn = 0
	s.rom.m = []
	s.map_id = 0
	s.x = 0
	s.y = 0
	var r := XTreasureMap.run(s, 1, 10, 117)
	check("v029_no_ticket_noop", r.toasts.is_empty() and int(s.rom.gn) == 0 and (s.rom.m as Array).is_empty(), [r, s.rom])
	s.gain_item(TICKET, 2)
	var want_item: int = items[5 % 3]
	var had := s.item_count(want_item)
	r = XTreasureMap.run(s, 1, 10, 117)
	check("v029_digs_anywhere", r.toasts == ["获得物品:" + _name("Items", want_item)] and s.item_count(want_item) == had + 1
		and s.item_count(TICKET) == 1 and s.rom.m == [1] and int(s.rom.gn) == 1, [r.toasts, s.rom])
	r = XTreasureMap.run(s, 1, 10, 117)
	check("v029_skips_partial_spot", s.rom.m == [1, 3] and s.item_count(TICKET) == 0, [r.toasts, s.rom])
	s.gain_item(TICKET, 1)
	r = XTreasureMap.run(s, 1, 10, 117)
	check("v029_all_dug_restart_first", s.rom.m == [1] and s.item_count(TICKET) == 0 and r.toasts.size() == 1, [r.toasts, s.rom])
	# 公共事件 0：按首尾 1～10 找，后写的 342／189 覆盖 212／117
	var other := 342
	var item342 := XDB.rec("Items", other)
	if (item342.get("effects", []) as Array).any(func(e): return int(e.get("code", 0)) == 44 and int(e.get("dataId", 0)) == 189):
		s.gain_item(TICKET, 1)
		s.gain_item(other, 1)
		s.rom.m = []
		XTreasureMap.run(s, 1, 10, 0)
		check("v029_by_range_last_wins", s.item_count(other) == 0 and s.item_count(TICKET) == 1, [s.item_count(other), s.item_count(TICKET)])
	else:
		check("v029_item342_shape", false, item342.get("effects"))


func finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "skipped": skipped}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
