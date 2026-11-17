extends Node
## 【cc·冠军庆典乙·未经审查】大厅庆典（XFestLobby）＋庆典使者贺礼＋报名处＋全部文案（XFestText）：
## - 活动内外显隐：进行中＝叠加层、使者、报名处、奖杯、换 BGM；收尾期＝只剩使者；活动前、结束后＝什么都没有；
## - 开关关掉无痕：XFest.ENABLED／XFestLobby.ENABLED 关掉，地图事件表、通行、BGM 与没有活动时逐项相同，不建任何节点；
## - 贺礼每个存档只领一次（庆典币、精魂、物品都只加一次，第二次对话出菜单）；
## - 奖杯两格挡路、全在异化圈外；报名处在冠军之路没接上时放占位对话、接上后调它的 enter；
## - 画面特效关掉不放彩带烟花；
## - 文案：真名只在贺词一处、不出现选手／官方／赛事字眼、没有西游词；四支战队、六个称号、四条成就都齐。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const TIMEOUT_FRAMES := 3000

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)
	return ok


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## 开大厅。today 是「今天」（XFest.TODAY_OVERRIDE）；先清地图缓存让补丁按当天重做
func open_lobby(today: String, x := 14, y := 24, reload := true, tianqi := false, baby := false) -> XMapScene:
	XFest.TODAY_OVERRIDE = today
	if reload:
		XFestLobby.reload_map()
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(206, -3000)
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}   # 天启篇存档（XTianqi.active）
	if baby:
		s.set_switch(2496, true)
	s.map_id = 4
	s.x = x
	s.y = y
	var map := XMapScene.new()
	add_child(map)
	for i in TIMEOUT_FRAMES:
		await frames(1)
		if map.player != null and not map.busy and map.map_id == 4:
			break
	await frames(2)
	return map


func close(map: XMapScene) -> void:
	map.queue_free()
	await frames(2)


func ev(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


func ids(map: XMapScene) -> Array:
	return map.events.map(func(e): return e.event_id)


func passability(map: XMapScene) -> Array:
	var out := []
	for y in map.lower.height:
		for x in map.lower.width:
			for d in [2, 4, 6, 8]:
				out.append(map.lower.is_passable(x, y, d))
	return out


## 站到事件正下方、面朝上按确认键，返回这次的对话记录
func talk(map: XMapScene, id: int, answers := []) -> Array:
	var e := ev(map, id)
	map.player.locate(e.grid.x, e.grid.y + 1)
	map.player.direction = 8
	XMessageBox.transcript.clear()
	XMessageBox.auto_answers = answers.duplicate()
	await map._on_action()
	await frames(2)
	return XMessageBox.transcript.duplicate()


func join(t: Array) -> String:
	return "\n".join(PackedStringArray(t.map(func(v): return str(v))))


## 把 XFestText 里所有字符串（含嵌套）摊平
func all_strings(v, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x in v:
			all_strings(x, out)
	elif v is Dictionary:
		for k in v:
			all_strings(v[k], out)


func _run() -> void:
	TestEnv.isolate("xiyou_fest_lobby")
	(XConfig._values.codexWhisperSeen as Array).erase("rift2")
	XRift.STAGE2 = false
	XRift.clear_cache()
	XLobbyCorruption.STAGE_OVERRIDE = 1   # 大厅异化层另测，这里一律不叠
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XFest.ENABLED = true
	XFestLobby.ENABLED = true
	XFestLobby.ROAD_CLASS = "NoSuchRoad"   # 不管 XFestRoad 合没合进来，默认按「没开放」测；开放的情形用 XFestRoadProbe
	var day1 := XFest.START
	var day_before := "2000-01-01"
	var grace_day := _plus(XFest.START, XFest.DAYS)         # 收尾期第一天
	var after_day := _plus(XFest.START, XFest.DAYS + XFest.GRACE_DAYS)   # 结束后第一天

	# ---- 基线：活动前（什么都没有）的大厅 ----
	var m0 := await open_lobby(day_before, 14, 8)
	await frames(20)
	await shot("fest_lobby_north_before.png")
	check("before.no_layer", m0.fest_fx == null and m0.get_children().all(func(n): return not n is XFestLobby))
	check("before.no_events", ids(m0).all(func(i): return i < XFestLobby.FIRST_EV), ids(m0))
	var base_tiles: Array = m0.map_data.data.duplicate()
	var base_pass := passability(m0)
	var base_ids := ids(m0)
	var base_bgm: String = str(m0.map_data.get("bgm", {}).get("name", ""))
	check("before.bgm_untouched", base_bgm == "TCLH-60", base_bgm)
	await close(m0)

	# ---- 活动进行中 ----
	var m1 := await open_lobby(day1)
	check("active.layer", m1.fest_fx != null and is_instance_valid(m1.fest_fx))
	check("active.events", ids(m1).has(78) and ids(m1).has(79) and ids(m1).has(80) and ids(m1).has(81), ids(m1))
	check("active.orig_events_kept", base_ids.all(func(i): return ids(m1).has(i)))
	check("active.bgm_changed", str(m1.map_data.get("bgm", {}).get("name", "")) == XFestLobby.BGM and XFestLobby.BGM != "TCLH-60")
	check("active.bgm_exists", XDB.audio_path("bgm", XFestLobby.BGM) != "", XFestLobby.BGM)
	check("active.art_textured", m1.fest_fx.banner_textured() and m1.fest_fx.trophy_textured())
	var expected_tiles := base_tiles.duplicate()
	for x in range(13, 16):
		for z in [1, 3]:
			expected_tiles[(z * 33 + 11) * 29 + x] = 0
	check("active.only_table_tiles_changed", m1.map_data.data == expected_tiles)
	check("active.trophy_center_on_original_npc", XFestLobby.TROPHY_FOOT == Vector2(14.5 * 48, 11 * 48))
	# 绕过奖杯下沿到两侧；13/15 列的行 12 是原有讨债人小弟，路线沿行 11 横穿。
	for step in [[13, 10, 2], [13, 11, 6], [14, 11, 6], [15, 11, 6], [16, 11, 2]]:
		m1.player.locate(step[0], step[1])
		check("active.route.%s" % str(step), m1.player.can_pass(step[2]))

	# 奖杯两格：被事件挡住（通行表不变，事件挡路），脚下能走到的人不能进
	m1.player.locate(14, 11)
	m1.player.direction = 8
	check("active.trophy_blocks_21", not m1.player.can_pass(8))
	m1.player.locate(15, 11)
	check("active.trophy_blocks_22", not m1.player.can_pass(8))
	check("active.table_floor_passable", m1.lower.is_passable(14, 11, 2))
	check("active.gold_npc_moved", ev(m1, 1).grid == Vector2i(17, 5))
	check("active.paimon_moved", Vector2i(m1.map_data.events[70].x, m1.map_data.events[70].y) == Vector2i(19, 6))
	check("active.banner_north_wall", XFestLobby.BANNER_POS == Vector2(264, 3 * 48))
	check("active.cells", ev(m1, 78).grid == XFestLobby.ENVOY_CELL and ev(m1, 79).grid == XFestLobby.ENROLL_CELL and ev(m1, 80).grid == Vector2i(14, 10) and ev(m1, 81).grid == Vector2i(15, 10))
	# 方案 2.1：使者、报名处、奖杯都在异化中心 (14,19) 的 6 格圈外
	for id in [78, 79, 80, 81]:
		var d := Vector2(ev(m1, id).grid - XLobbyCorruption.CENTER).length()
		check("active.outside_corruption_circle.%d" % id, d > XLobbyCorruption.RADIUS, d)
	# 彩带烟花
	await frames(60)
	check("active.confetti", m1.fest_fx.confetti_count() > 0, m1.fest_fx.confetti_count())
	m1.player.locate(14, 21)
	await frames(10)
	await shot("fest_lobby_south.png")
	m1.player.locate(11, 19)
	await frames(10)
	await shot("fest_lobby_trophy.png")
	m1.fest_fx._next_firework = 0.0
	await frames(100)
	check("active.fireworks_run", m1.fest_fx.spark_count() > 0, m1.fest_fx.spark_count())
	await shot("fest_lobby_firework.png")

	# 贺礼：只领一次
	var s: XState = XState.current
	var gold0 := s.gold
	var coins0 := XFest.coins(s)
	var item0 := s.item_count(1639) if s.has_method("item_count") else 0
	var t1 := await talk(m1, 78)
	var j1 := join(t1)
	check("envoy.first.congrats", j1.contains(XFest.CONGRATS), j1)
	check("envoy.first.coins", XFest.coins(s) == coins0 + int(XFestLobby.GIFT.coins), [XFest.coins(s), coins0])
	check("envoy.first.gold", s.gold == gold0 + int(XFestLobby.GIFT.gold), [s.gold, gold0])
	if s.has_method("item_count"):
		check("envoy.first.items", s.item_count(1639) == item0 + 10)   # v0.3.1 贺礼：肝帝积分抽奖券 ×10
	check("envoy.first.intro", j1.contains("冠军之路"))
	check("envoy.met_flag", bool(XFest.data(s).get("envoy_met", false)) and bool(XFest.data(s).get("envoy_gift", false)))
	await shot("fest_lobby_envoy.png")
	var gold1 := s.gold
	var coins1 := XFest.coins(s)
	var t2 := await talk(m1, 78, [0, 1, 4])   # 冠军之路是什么 → 四支战队 → 再见（菜单：冠军之路／战队／签到／兑换／再见）
	var j2 := join(t2)
	check("envoy.second.no_gift", s.gold == gold1 and XFest.coins(s) == coins1)
	check("envoy.second.menu", j2.contains("选择：" + XFestText.ENVOY_MENU_ROAD) and j2.contains(XFestText.ENVOY_ROAD_INFO_SOON[0][1].split("\n")[0]), j2)
	check("envoy.second.teams", XFestText.TEAMS.all(func(t): return j2.contains(t.name)), j2)
	check("envoy.second.not_congrats", not j2.contains(XFest.CONGRATS))
	# 存档往返：贺礼记录跟存档走，读回来仍然领过
	var snap := s.to_dict()
	var s2 := XState.from_dict(snap)
	check("envoy.gift_saved", bool(XFest.data(s2).get("envoy_gift", false)))
	# 旧档（没有活动数据）：当没领过
	var s3 := XState.new_game(3, 1, [8, 9, 10])
	check("envoy.old_save_empty", XFest.data(s3).is_empty() and XFest.coins(s3) == 0)
	XState.current = s   # new_game／from_dict 会换掉当前存档，换回来接着测
	# 扩展菜单项（第 2 天的签到、兑换）
	var hit := [false]
	XFestLobby.EXTRA_MENU = [{"label": "今日签到", "call": func(_i): hit[0] = true}]
	var t3 := await talk(m1, 78, [4, 5])
	check("envoy.extra_menu", hit[0] and join(t3).contains("今日签到"), join(t3))
	XFestLobby.EXTRA_MENU = []

	# 奖杯与报名处
	var tt := join(await talk(m1, 80))
	check("trophy.text", tt.contains("奖杯"), tt)
	# 冠军之路没开放（XFestRoad 不存在）：报名处只说「敬请期待」，没有选项、没有占位战斗；使者介绍改「即将开放」口径
	check("enroll.road_not_ready", not XFestLobby.road_ready())
	var e1 := join(await talk(m1, 79))
	check("enroll.soon", e1.contains("敬请期待") and e1.contains("即将开放") and not e1.contains("选择：") and not e1.contains(XFestText.ENROLL_GREET[0][1].split("\n")[0]), e1)
	var env_soon := join(await talk(m1, 78, [0, 4]))
	check("envoy.road_info_soon", env_soon.contains("即将开放") and not env_soon.contains("场间暂停"), env_soon)
	# 称号表：单独上线只列已拿到的，不显示拿不到的「???」
	var tbl_ids := func() -> Array: return XDesignation.table().map(func(d): return int(d.id))
	check("titles.hidden_when_locked", XFest.TITLES.all(func(t): return not tbl_ids.call().has(int(t.id))), tbl_ids.call())
	var cfg_designations := XConfig.designations()
	XDesignation.unlock(42)
	check("titles.unlocked_listed", tbl_ids.call().has(42) and not tbl_ids.call().has(41), tbl_ids.call())
	cfg_designations.erase("42")
	XConfig.save_designations()
	# 入口开放（用测试替身）：报名处走真入口，称号表全列，使者用原介绍
	XFestLobby.ROAD_CLASS = "XFestRoadProbe"
	check("road.ready", XFestLobby.road_ready())
	check("titles.all_when_road_ready", XFest.TITLES.all(func(t): return tbl_ids.call().has(int(t.id))), tbl_ids.call())
	var env_ready := join(await talk(m1, 78, [0, 4]))
	check("envoy.road_info_ready", env_ready.contains("场间暂停") and not env_ready.contains("即将开放"), env_ready)
	var e2 := join(await talk(m1, 79, [1, 2]))
	check("enroll.teams", XFestText.TEAMS.all(func(t): return e2.contains(t.name)), e2)
	var e3 := join(await talk(m1, 79, [2]))
	check("enroll.bye", e3.contains(XFestText.ENROLL_BYE[0][1]), e3)
	await talk(m1, 79, [0])
	check("enroll.goes_real_entry", XFestRoadProbe.entered == 1, XFestRoadProbe.entered)
	XFestRoadProbe.ENABLED = false
	check("road.disabled_not_ready", not XFestLobby.road_ready())
	var e4 := join(await talk(m1, 79))
	check("enroll.disabled_soon", e4.contains("敬请期待"), e4)
	XFestRoadProbe.ENABLED = true
	XFestLobby.ROAD_CLASS = "NoSuchRoad"

	# 报名处对话截图（真窗口：关掉自动应答，起对话后截）。无头不截：对话会卡在消息框，关图时协程没收尾，退出报资源泄漏（总装 11-15 云端选测）
	if out_dir != "" and DisplayServer.get_name() != "headless":
		var en := ev(m1, 79)
		m1.player.locate(en.grid.x, en.grid.y + 1)
		m1.player.direction = 8
		XMessageBox.auto = false
		m1._on_action()
		await frames(40)
		await shot("fest_lobby_enroll.png")
		XMessageBox.auto = true
	# 画面特效关掉：不放粒子
	XConfig.set_flag("codexScreenFx", false)
	check("fx_off.no_confetti", m1.fest_fx.confetti_count() == 0)
	XConfig.set_flag("codexScreenFx", true)
	await close(m1)

	# ---- 收尾期：只剩使者 ----
	var mg := await open_lobby(grace_day)
	check("grace.no_layer", mg.fest_fx == null)
	check("grace.only_envoy", ids(mg).has(78) and not ids(mg).has(79) and not ids(mg).has(80) and not ids(mg).has(81), ids(mg))
	check("grace.bgm_untouched", str(mg.map_data.get("bgm", {}).get("name", "")) == "TCLH-60")
	var tg := join(await talk(mg, 78, [1]))   # 收尾期留兑换店：兑换／再见
	check("grace.text", tg.contains(XFestText.ENVOY_GRACE[0][1].split("\n")[0]) and tg.contains("选择：") and not tg.contains(XFest.CONGRATS), tg)
	check("grace.menu_shop_only", XFestReward.menu(XState.current).map(func(m): return m.label) == [XFestText.SHOP_MENU], XFestReward.menu(XState.current))
	check("grace.original_npc_and_tiles", ev(mg, 1).grid == Vector2i(14, 10) and mg.map_data.events[70].x == 17 and mg.map_data.events[70].y == 5 and mg.map_data.data == base_tiles)
	check("grace.passability_same", passability(mg) == base_pass)
	await close(mg)

	# ---- 结束后：什么都没有，与活动前逐项相同 ----
	var me := await open_lobby(after_day)
	check("ended.no_layer_no_events", me.fest_fx == null and ids(me) == base_ids)
	check("ended.same_as_before", passability(me) == base_pass and str(me.map_data.get("bgm", {}).get("name", "")) == base_bgm)
	await close(me)

	# ---- 开关关掉无痕（日期在活动内）----
	for which in ["fest_enabled", "lobby_enabled"]:
		XFest.ENABLED = which != "fest_enabled"
		XFestLobby.ENABLED = which != "lobby_enabled"
		var mo := await open_lobby(day1)
		check("off.%s.no_layer" % which, mo.fest_fx == null and mo.get_children().all(func(n): return not n is XFestLobby))
		check("off.%s.events_identical" % which, ids(mo) == base_ids, ids(mo))
		check("off.%s.passability_bgm" % which, passability(mo) == base_pass and str(mo.map_data.get("bgm", {}).get("name", "")) == base_bgm)
		await close(mo)
	XFest.ENABLED = true
	XFestLobby.ENABLED = true

	# ---- 地图缓存：不手动清缓存，跨过活动起止日再进大厅也要跟着变（正式游戏没人调 reload_map）----
	var mc0 := await open_lobby(day_before)
	check("cache.before.none", mc0.fest_fx == null and ids(mc0) == base_ids)
	await close(mc0)
	var mc1 := await open_lobby(day1, 14, 24, false)
	check("cache.start_day.npcs_and_layer", mc1.fest_fx != null and ids(mc1).has(78) and ids(mc1).has(79) and str(mc1.map_data.get("bgm", {}).get("name", "")) == XFestLobby.BGM, ids(mc1))
	await close(mc1)
	var mcg := await open_lobby(grace_day, 14, 24, false)
	check("cache.grace.only_envoy", mcg.fest_fx == null and ids(mcg).has(78) and not ids(mcg).has(79), ids(mcg))
	await close(mcg)
	var mce := await open_lobby(after_day, 14, 24, false)
	check("cache.ended.clean", mce.fest_fx == null and ids(mce) == base_ids and str(mce.map_data.get("bgm", {}).get("name", "")) == base_bgm, ids(mce))
	await close(mce)

	# ---- T069：漩涡二阶段开着（正式默认）时 XRift 先把 Map004 事件表扩到 201～204，庆典补丁不能因为表长超过 78 就放弃 ----
	XRift.STAGE2 = true
	XRift.clear_cache()
	(XConfig._values.codexWhisperSeen as Array).append("rift2")   # 不让二阶段过场在这里开播（另有专项测）
	var mr := await open_lobby(day1, 7, 20)
	check("rift2_on.events_padded", (mr.map_data.get("events", []) as Array).size() > XRift.CANGLONG_EV, (mr.map_data.get("events", []) as Array).size())
	check("rift2_on.envoy_enroll_trophy", ids(mr).has(XFestLobby.ENVOY_EV) and ids(mr).has(XFestLobby.ENROLL_EV) and XFestLobby.TROPHY_EVS.all(func(i): return ids(mr).has(i)), ids(mr))
	check("rift2_on.rift_events_kept", ids(mr).has(XRift.RIFT2) and ids(mr).has(XRift.BLOCK_L), ids(mr))
	var mr_env := ev(mr, XFestLobby.ENVOY_EV)
	check("rift2_on.envoy_cell", mr_env != null and mr_env.grid == XFestLobby.ENVOY_CELL, mr_env.grid if mr_env != null else null)
	await frames(30)
	await shot("fest_lobby_rift2_xiyou.png")
	await close(mr)
	var mt := await open_lobby(day1, 7, 20, true, true)
	check("rift2_on.tianqi.save_is_tianqi", XTianqi.active(XState.current))
	check("rift2_on.tianqi.envoy_enroll_trophy", ids(mt).has(XFestLobby.ENVOY_EV) and ids(mt).has(XFestLobby.ENROLL_EV) and XFestLobby.TROPHY_EVS.all(func(i): return ids(mt).has(i)), ids(mt))
	await frames(30)
	await shot("fest_lobby_rift2_tianqi.png")
	await close(mt)
	(XConfig._values.codexWhisperSeen as Array).erase("rift2")
	XRift.STAGE2 = false
	XRift.clear_cache()
	XFestLobby.reload_map()

	# T071：正式默认异化设置、同一视角，西游／天启篇／宝宝难度各一张。
	XLobbyCorruption.STAGE_OVERRIDE = 0
	XRift.STAGE2 = true
	XRift.clear_cache()
	(XConfig._values.codexWhisperSeen as Array).append("rift2")
	for mode in ["xiyou", "tianqi", "baby"]:
		var view := await open_lobby(day1, 14, 8, true, mode == "tianqi", mode == "baby")
		await frames(200)
		check("layout.%s.gold" % mode, ev(view, 1).grid == Vector2i(17, 5))
		check("layout.%s.paimon" % mode, Vector2i(view.map_data.events[70].x, view.map_data.events[70].y) == Vector2i(19, 6))
		for x in range(13, 16):
			check("layout.%s.table_removed.%d" % [mode, x], view.map_data.data[(1 * 33 + 11) * 29 + x] == 0 and view.map_data.data[(3 * 33 + 11) * 29 + x] == 0)
		if mode == "baby":
			check("layout.baby.paimon_visible", ev(view, 70) != null and ev(view, 70).grid == Vector2i(19, 6))
		await shot("fest_lobby_default_%s.png" % mode)
		await close(view)
	XRift.STAGE2 = false
	XRift.clear_cache()
	XLobbyCorruption.STAGE_OVERRIDE = 1

	# ---- 文案 ----
	var strs: Array = []
	var consts: Dictionary = (load("res://modes/xiyou/core/fest_text.gd") as GDScript).get_script_constant_map()
	for k in consts:
		all_strings(consts[k], strs)
	var blob := "\n".join(PackedStringArray(strs))
	check("text.nonempty", strs.size() > 40, strs.size())
	# 真名只在贺词：BLG 只在 CONGRATS 那一处
	var blg := 0
	for st in strs:
		blg += st.count("BLG")
	check("text.real_name_only_congrats", blg >= 1 and XFest.CONGRATS.contains("BLG") and XFestText.BANNER == XFest.CONGRATS, blg)
	var no_blg := blob.replace(XFest.CONGRATS, "")
	check("text.no_other_real_name", not no_blg.contains("BLG"))
	check("text.congrats_exact", XFest.CONGRATS == "恭喜 BLG 夺得 2026 全球总决赛冠军")
	for w in ["英雄联盟", "S16", "Worlds", "官方", "授权", "合作", "Riot", "LCK", "LPL", "Faker", "Chovy", "Knight", "Bin", "Elk", "Xun", "Beichuan", "Viper", "Gen.G", "T1", "HLE", "DK", "召唤师杯"]:
		check("text.no_banned.%s" % w, not no_blg.contains(w), w)
	# 西游词（含游戏本名）
	for w in ["西游", "悟空", "孙悟空", "唐僧", "八戒", "沙僧", "取经", "如来", "观音", "玉帝", "天庭", "牛魔王", "龙王", "莲花洞", "火焰山", "水帘洞", "龙宫", "紧箍", "筋斗云", "蟠桃", "妖怪", "再刷"]:
		check("text.no_xiyou.%s" % w, not blob.contains(w), w)
	check("text.teams", XFestText.TEAMS.map(func(t): return t.name) == ["网吧队", "银河战舰队", "大魔王队", "内战幻神队"])
	check("text.team_intros", XFestText.TEAMS.all(func(t): return str(t.intro).length() > 15 and str(t.intro).length() < 90))
	check("text.enemy_name", XFestText.enemy_name(0, 0) == "网吧队·上单" and XFestText.enemy_name(3, 4) == "内战幻神队·辅助")
	check("text.roles", XFestText.ROLES == ["上单", "打野", "中单", "下路", "辅助"])
	check("text.titles", XFestText.TITLE_TEXTS.size() == XFest.TITLES.size() and XFest.TITLES.all(func(t): return XFestText.TITLE_TEXTS.has(int(t.id)) and XFestText.TITLE_TEXTS[int(t.id)].name == t.name))
	check("text.achievements", XFestText.ACHIEVEMENTS.size() == 4 and XFestText.ACHIEVEMENTS.map(func(a): return a.name) == ["我在现场", "冠军之路", "一穿四", "全勤观众"])
	check("text.easter", XFestText.EASTER_LINES.size() >= 6 and XFestText.BUBBLE_LINES.size() >= 4)
	check("text.easter_events_exist", XFestText.EASTER_LINES.keys().all(func(k): return base_ids.has(int(k))), XFestText.EASTER_LINES.keys())

	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


static func road_exists() -> bool:
	return ProjectSettings.get_global_class_list().any(func(c): return str(c.get("class", "")) == "XFestRoad")


static func _plus(date: String, days: int) -> String:
	var n := XFest.day_number(date) + days
	var d := Time.get_datetime_dict_from_unix_time(n * 86400 + 43200)
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
