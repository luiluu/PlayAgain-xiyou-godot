extends Node
## v0.01 玩家反馈（Kyo 11-12 转群截图）：
## - 绪绪（Map4 EV56，行走图 1xuxu 只画了左上一格、本页 pattern 0）停着时一直是第 0 帧，不会换到空白的第 1 帧（MVCharacter.original_pattern）；
## - 8 号当铺入口（Map132 EV7，确定键、角色下方、无图、只有场所移动）：踩上即进（XMapScene.STEP_ON_DOORS），关掉回原版不进；
##   原版点地走到目的地停下时也进（Game_Player.triggerTouchActionD1，MVPlayer.MV_TOUCH_D1）；普通 NPC 不算门；
## - 商店列表缓存（XShop.DATA_CACHE）：一次按键＋重画里买入表、出售表各只现算一次；成交后照样现算（买到的东西进出售表）；
##   关掉时一次按键现算多次（打印两边次数与用时）；
## - 说明卡元素表只读一次（XHelpCard.ELEMENT_DATA_CACHE）：商店每移一行原先 40～100 ms 都花在重读 1 MB 的元素表；
## - 神话敌人画面 1 倍（XBattleScene.ELITE_SCALE，原版 1.8 倍被 YEP 呼吸更新当帧改回）；
## - 画面平滑（XScreenScale）：v0.01.06 起各平台默认关、老配置没亲手选过的 true 不认（回退 TOUCH_DEFAULT_ON＝dev497 触屏默认开），设置改了立刻切根窗口缩放方式，开关关掉恒为 canvas_items；
##   viewport 缩放时屏幕→画面的换算按 keep 比例算（安全区用）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func open_map(id: int, x: int, y: int) -> XMapScene:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = id
	s.x = x
	s.y = y
	XState.current = s
	var map := XMapScene.new()
	add_child(map)
	for i in 3000:
		await frames(1)
		if map.player != null and not map.busy and map.map_id == id:
			break
	await frames(2)
	return map


func close(map: XMapScene) -> void:
	map.queue_free()
	await frames(3)


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


func _run() -> void:
	TestEnv.isolate("xiyou_feedback_v001")
	XMessageBox.auto = true
	print("STEP pattern")
	await _pattern()
	print("STEP doors")
	await _doors()
	_elite()
	print("STEP shop")
	await _shop()
	print("STEP screen")
	await _screen()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _pattern() -> void:
	var map := await open_map(4, 6, 15)
	var xu := _event(map, 56)
	if not check("xuxu_present", xu != null and xu.character_name == "1xuxu"):
		await close(map)
		return
	check("xuxu_original_pattern", xu.original_pattern == 0 and xu.origin_pattern() == 0, [xu.original_pattern, xu.pattern])
	await frames(60)
	check("xuxu_stays_frame0", xu.pattern == 0, xu.pattern)
	# 帧被改走（如转身动画）后，停下照原版回到本页的 0 帧，不是 1
	xu.pattern = 1
	for i in 30:
		xu._update_animation()
	check("xuxu_resets_to_frame0", xu.pattern == 0, xu.pattern)
	# 玩家没有本页帧：照旧回停步帧 1
	check("player_stand_1", map.player.origin_pattern() == 1, map.player.origin_pattern())
	check("npc_not_door", not xu.is_plain_door())
	await close(map)


## 站到门格上（等同一步走上去：_on_player_step），看会不会换到 8 号当铺 Map204
func _step_on(on: bool) -> int:
	XMapScene.STEP_ON_DOORS = on
	var map := await open_map(132, 15, 9)
	var door := _event(map, 7)
	check("door_detected.%s" % on, door != null and door.is_plain_door(), door.page if door != null else null)
	map.player.locate(15, 8)
	map._on_player_step()
	for i in 600:
		await frames(1)
		if map.map_id == 204 and not map.busy:
			break
	var got := map.map_id
	await close(map)
	XMapScene.STEP_ON_DOORS = true
	return got


func _doors() -> void:
	check("step_on_enters", await _step_on(true) == 204)
	check("step_on_off_stays", await _step_on(false) == 132)
	# 原版点地：点门格、走到停下（目的地＝脚下）时进门；关掉 D1 不进
	for d1 in [true, false]:
		XMapScene.STEP_ON_DOORS = false
		MVPlayer.MV_TOUCH_D1 = d1
		var map := await open_map(132, 15, 9)
		map.player.locate(15, 8)
		map.player.touch_target = Vector2i(15, 8)
		map.player.update_character()
		for i in 600:
			await frames(1)
			if map.map_id == 204 and not map.busy:
				break
		check("touch_d1.%s" % d1, (map.map_id == 204) == d1, map.map_id)
		await close(map)
	MVPlayer.MV_TOUCH_D1 = true
	XMapScene.STEP_ON_DOORS = true


## 一次按键（下移）＋本帧重画：返回 [现算次数, 微秒]
func _shop_press(sh: XShop) -> Array:
	sh.data_builds = 0
	var t0 := Time.get_ticks_usec()
	sh._move(1, true)
	sh._refresh()
	await frames(2)   # 重画在帧末（无头时 frame_post_draw 不一定发，这里只等帧）
	return [sh.data_builds, Time.get_ticks_usec() - t0]


func _shop() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gain_gold(5000000)
	# 背包塞满：道具 600 种、武器防具各 300 件（出售表要整背包筛）
	var n := 0
	for rec in XDB.table("Items"):
		if rec is Dictionary and str(rec.get("name", "")) != "" and n < 600:
			s.gain_item(int(rec.id), 3)
			n += 1
	var goods := []
	var k := 0
	for rec in XDB.table("Items"):
		if rec is Dictionary and str(rec.get("name", "")) != "" and int(rec.get("price", 0)) > 0 and k < 40:
			goods.append([0, int(rec.id), 0, 0])
			k += 1
	var res := {}
	for on in [true, false]:
		XShop.DATA_CACHE = on
		var sh := XShop.new()
		sh.setup(goods, false)
		add_child(sh)
		await frames(2)
		sh._cmd = 0
		sh._ok()   # 进买入
		await frames(2)
		var a := await _shop_press(sh)
		var b := await _shop_press(sh)
		res[on] = [a[0] + b[0], a[1] + b[1]]
		if on:
			# 买一件：成交后出售表照样现算，买到的东西在里面（不吃旧缓存）
			var id := int(sh._buy_data()[sh._buy_index].gid)
			var before := s.item_count(id)
			sh._ok()   # 数量窗
			sh._ok()   # 成交
			check("shop_bought", s.item_count(id) == before + 1, [before, s.item_count(id)])
			sh._mode = "sell"
			sh._cat = 0
			sh._refresh()
			var sold: Array = sh._sell_data().filter(func(e): return int(e.rec.get("id", 0)) == id)
			check("shop_sell_fresh", not sold.is_empty() and int(sold[0].count) == before + 1, sold.map(func(e): return e.count))
		sh.queue_free()
		await frames(2)
	XShop.DATA_CACHE = true
	print("SHOP_PRESS cache_on builds=%d %dus / cache_off builds=%d %dus (两次按键)" % [res[true][0], res[true][1], res[false][0], res[false][1]])
	check("shop_cache_builds", res[true][0] <= 2 and res[false][0] > res[true][0], res)
	XShop.DATA_CACHE = true
	# 说明卡元素表（约 1 MB）走 XDB.table 缓存，不再每张卡重读；关掉回到每次读
	check("help_element_cached", is_same(XHelpCard._element_data(), XDB.table("CodexDamageElements")))
	var t0 := Time.get_ticks_usec()
	var card := XHelpCard.new()
	add_child(card)
	for g in goods:
		card.show_for(XDB.rec("Items", int(g[1])))
	var per := (Time.get_ticks_usec() - t0) / goods.size()
	XHelpCard.ELEMENT_DATA_CACHE = false
	check("help_element_off", not is_same(XHelpCard._element_data(), XDB.table("CodexDamageElements")))
	XHelpCard.ELEMENT_DATA_CACHE = true
	card.queue_free()
	print("HELP_CARD show_for %dus/件" % per)


func _elite() -> void:
	check("elite_scale_1", is_equal_approx(XBattleScene.ELITE_SCALE, 1.0), XBattleScene.ELITE_SCALE)


func _screen() -> void:
	var root := get_tree().root
	var before := root.content_scale_mode
	# 没存过这一项（v0.01 老配置）：按平台默认。TestEnv 写过一次配置（会连默认值一起写进去），先删掉
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	# v0.01.06 起（O-369）：触屏、桌面没选过都默认关
	XPlatform.force_mobile = true
	XConfig._loaded_path = "<unloaded>"
	check("smooth_default_touch_off", not XConfig.flag(XScreenScale.KEY))
	XPlatform.force_mobile = false
	XConfig._loaded_path = "<unloaded>"
	check("smooth_default_desktop", not XConfig.flag(XScreenScale.KEY))
	# dev497～ 的老配置：触屏默认的 true 被连同别的设置写进文件、没有亲手选过的记号 → 不认，按默认关
	var f := FileAccess.open(XConfig.path_override, FileAccess.WRITE)
	f.store_string(JSON.stringify({XScreenScale.KEY: true, "alwaysDash": false}))
	f.close()
	XPlatform.force_mobile = true
	XConfig._loaded_path = "<unloaded>"
	check("smooth_old_true_ignored", not XConfig.flag(XScreenScale.KEY))
	check("smooth_old_other_kept", not XConfig.flag("alwaysDash"))
	# 回退 TOUCH_DEFAULT_ON = true：触屏默认开、老配置里的 true 照认（dev497 行为）
	XScreenScale.TOUCH_DEFAULT_ON = true
	XConfig._loaded_path = "<unloaded>"
	check("smooth_rollback_old_true_kept", XConfig.flag(XScreenScale.KEY))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	XConfig._loaded_path = "<unloaded>"
	check("smooth_rollback_default_touch", XConfig.flag(XScreenScale.KEY))
	XPlatform.force_mobile = false
	XConfig._loaded_path = "<unloaded>"
	check("smooth_rollback_default_desktop", not XConfig.flag(XScreenScale.KEY))
	XScreenScale.TOUCH_DEFAULT_ON = false
	XConfig._loaded_path = "<unloaded>"
	XConfig.set_flag(XScreenScale.KEY, true)
	check("smooth_on_viewport", root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, root.content_scale_mode)
	XConfig._loaded_path = "<unloaded>"
	check("smooth_saved", XConfig.flag(XScreenScale.KEY))
	# 亲手存过 true 后（带记号），触屏／桌面默认都不再覆盖它
	XPlatform.force_mobile = true
	XConfig._loaded_path = "<unloaded>"
	check("smooth_saved_kept", XConfig.flag(XScreenScale.KEY))
	check("smooth_chosen_mark", JSON.parse_string(FileAccess.get_file_as_string(XConfig.path_override)).get(XScreenScale.CHOSEN_KEY) == true)
	XPlatform.force_mobile = null
	XConfig.set_flag(XScreenScale.KEY, false)
	check("smooth_off_canvas", root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, root.content_scale_mode)
	XScreenScale.ENABLED = false
	check("smooth_disabled", XScreenScale.apply(true, get_tree()) == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	XScreenScale.ENABLED = true
	# viewport 缩放时：窗口 1920×1200（16:10）里 1280×720 放大 1.5 倍、上下各留 60 黑边
	var w := Window.new()
	w.visible = false
	w.size = Vector2i(1920, 1200)
	w.content_scale_size = Vector2i(1280, 720)
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	add_child(w)
	await frames(1)
	var t := XScreenScale.screen_to_view(w)
	var p := t * Vector2(960, 660)
	check("screen_to_view_center", p.distance_to(Vector2(640, 400)) < 0.5, [p, w.get_visible_rect().size])
	w.queue_free()
	root.content_scale_mode = before
	await frames(1)
