extends Node
## 【cc·天启篇】T126 战斗站位撑开（XBattleLayout）＋小怪糖果粉血条（XSkinEnemyHp）＋触屏指令环跟角色（XUiSkin.TOUCH_RING_FIXED，D171）专项。
## 内存新游戏，不写存档；新皮肤强开、触屏强开（touch_override）。
## 核：首领战首领站首领点、放大且不超封顶；小怪战敌群收在左半场、我方在右半场且离敌人够远；我方 4 人／2 人都不压右上队伍栏；
## 原版竖排不撑开；ENABLED＝false 回到原版坐标与大小；触屏指令环跟着当前行动的角色（不在右下角），TOUCH_RING_FIXED＝true 回到右下；
## 小怪血条：条宽、条顶取值，开着时画面上脚下那一行是糖果粉（窗口模式取像素），首领不画；ENABLED＝false 回到原版小血条。
## 窗口模式加 -- --out=<目录> 出 800×450 截图（首领战、4 只小怪、8 只怨念之魂、3 只小怪＋2 人，都带指令环）。

var results := []
var out_dir := ""

const BOSS_TROOP := 4      # 【守层者】里德（一名成员）
const MOB4_TROOP := 25     # 训狼哥布林＋森林狼 ×3
const MOB8_TROOP := 357    # 怨念之魂 ×8
const MOB3_TROOP := 2      # 嘤嘤怪 ×3


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func _shot(name: String) -> Image:
	if not _windowed():
		return null
	await _frames(10)
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	_check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	return img


func _run() -> void:
	if _windowed():
		get_window().size = Vector2i(800, 450)
		await _frames(5)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.touch_override = 1
	XSave.dir_override = "user://test_xiyou_battle_layout"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_party_formation(XPartyFormation.ROWS)
	XEnemy.force_roll = 100.0
	_unit()
	await _boss()
	await _mob4()
	await _mob8()
	await _mob3_two()
	await _column()
	await _off()
	await _ring_fixed_back()
	XBattleLayout.ENABLED = true
	XSkinEnemyHp.ENABLED = true
	XUiSkin.TOUCH_RING_FIXED = false
	XConfig.set_party_formation(XPartyFormation.ROWS)
	_finish()


func _battle(troop: int, party: Array) -> XBattleScene:
	seed(20261117)
	var s := XState.new_game(3, 1, party)
	for a in s.members():
		a.change_level(99)  # 等到我方指令，别开场就被小怪打光
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261117)
	var b := XBattleScene.new()
	b.setup(troop, true, false, {})
	add_child(b)
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("command_shown_%d_%d" % [troop, party.size()], ok)
	await _secs(0.6)
	return b


func _close(b: XBattleScene) -> void:
	b.bgm.stop()
	b.queue_free()
	await _frames(3)


func _unit() -> void:
	XBattleLayout.ENABLED = true
	# 敌人放大：小图放到倍数为止、中图放到封顶为止、大图不缩
	_check("factor_small", is_equal_approx(XBattleLayout.enemy_factor(60.0, false), 1.8))
	_check("factor_cap", is_equal_approx(XBattleLayout.enemy_factor(150.0, false), 170.0 / 150.0))
	_check("factor_big_no_shrink", is_equal_approx(XBattleLayout.enemy_factor(224.0, false), 1.0))
	_check("factor_solo", is_equal_approx(XBattleLayout.enemy_factor(64.0, true), 2.2))
	# 本来就散的敌群不再拉、收在敌群矩形里
	var fit := XBattleLayout.enemy_fit([Vector2(94, 300), Vector2(740, 500)])
	_check("fit_wide_no_stretch", fit.k.x == 1.0 and fit.k.y < 1.5, fit)
	var tight := XBattleLayout.enemy_fit([Vector2(200, 330), Vector2(330, 450)])
	_check("fit_tight_spread", tight.k == Vector2(1.5, 1.5), tight)
	_check("enemy_home_solo", XBattleLayout.enemy_home(Vector2(408, 484), {}, true) == XBattleLayout.BOSS.solo)
	XBattleLayout.ENABLED = false
	_check("off_identity", XBattleLayout.enemy_home(Vector2(408, 484), fit, true) == Vector2(408, 484)
		and XBattleLayout.actor_home(Vector2(669, 280), false) == Vector2(669, 280)
		and XBattleLayout.actor_mul(false) == 1.0 and XBattleLayout.enemy_factor(60.0, false) == 1.0)
	XBattleLayout.ENABLED = true
	# 小怪血条尺寸
	_check("bar_width_clamp", XSkinEnemyHp.bar_width(40.0) == XSkinEnemyHp.W_MIN and XSkinEnemyHp.bar_width(400.0) == XSkinEnemyHp.W_MAX
		and XSkinEnemyHp.bar_width(150.0) == 90.0)
	_check("bar_top_feet", XSkinEnemyHp.STYLE == XSkinEnemyHp.Style.FEET and XSkinEnemyHp.bar_top(100.0) == XSkinEnemyHp.FEET_Y)


func _actor_box(b: XBattleScene) -> Rect2:
	var r := Rect2()
	for a in b.logic.actors:
		var sp: XBattlerSprite = b.sprites[a]
		var body := Rect2(sp.home - Vector2(sp.width() / 2.0, sp.height()), Vector2(sp.width(), sp.height()))
		r = body if r.size == Vector2.ZERO else r.merge(body)
	return r


## 我方：右半场、上排身体在队伍栏下面（队伍栏 x≥975 只到 y 250）、脚底不进行动条高度
func _check_actors(tag: String, b: XBattleScene, mul: float) -> void:
	var feet := b.logic.actors.map(func(a): return b.sprites[a].home)
	_check(tag + "_actor_mul", b.logic.actors.all(func(a): return is_equal_approx(b.sprites[a].layout_mul, mul)), mul)
	_check(tag + "_actor_right_half", feet.all(func(p): return p.x >= 780.0 and p.x <= 1040.0 and p.y >= 320.0 and p.y <= 605.0), feet)
	var pr := b.party_rect()
	var panel := Rect2(pr.position - b._origin, pr.size)
	var hit := b.logic.actors.filter(func(a):
		var sp: XBattlerSprite = b.sprites[a]
		var body := Rect2(sp.home - Vector2(sp.width() / 2.0, sp.height()), Vector2(sp.width(), sp.height())).grow(-6.0)
		return body.intersects(panel))
	_check(tag + "_actor_clear_party_panel", hit.is_empty(), [panel, hit.map(func(a): return b.sprites[a].home)])


## 指令环跟着当前行动的角色：环心在角色上方附近（不在右下角）、整环在画面内
func _check_ring(tag: String, b: XBattleScene) -> void:
	var ring := b.cmd_win as XSkinBattleRing
	_check(tag + "_ring_type", ring != null)
	if ring == null:
		return
	var a: XActor = b._active
	var c := ring.position - b._origin + ring.center
	var corner := Vector2(XBattleScene.BOX.x - ring.size.x - XSkinBattleRing.MARGIN, XBattleScene.BOX.y - ring.size.y - XSkinBattleRing.MARGIN)
	_check(tag + "_ring_not_corner", (ring.position - b._origin).distance_to(corner) > 4.0, [ring.position - b._origin, corner])
	if a != null:
		var want: Vector2 = b.sprites[a].position + XSkinBattleRing.OFFSET
		_check(tag + "_ring_follows_actor", absf(c.y - want.y) <= ring.size.y and absf(c.x - want.x) <= ring.size.x, [c, want])
	var r := Rect2(ring.position - b._origin, ring.size)
	_check(tag + "_ring_on_screen", r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= XBattleScene.BOX.x + 0.5 and r.end.y <= XBattleScene.BOX.y + 0.5, r)


## 截图里某敌人脚下血条那一行有糖果粉（窗口模式）
func _bar_pink(img: Image, b: XBattleScene, e: XEnemy) -> bool:
	var sp: XBattlerSprite = b.sprites[e]
	var scale := float(img.get_width()) / XBattleScene.BOX.x
	var y := (sp.position.y - 27.0 + XSkinEnemyHp.FEET_Y + XSkinEnemyHp.H / 2.0) * scale
	var w := XSkinEnemyHp.bar_width(sp.width())
	for k in range(-int(w * 0.4), int(w * 0.1)):
		for dy in [-1, 0, 1]:
			var px := img.get_pixel(clampi(int((sp.position.x + k) * scale), 0, img.get_width() - 1), clampi(int(y) + dy, 0, img.get_height() - 1))
			if px.r > 0.85 and px.g < 0.85 and px.b > 0.5 and px.r - px.g > 0.15:
				return true
	return false


func _boss() -> void:
	var b := await _battle(BOSS_TROOP, [8, 9, 10])
	var boss: XEnemy = b.logic.enemies[0]
	var sp: XBattlerSprite = b.sprites[boss]
	_check("boss_solo", b.layout_solo())
	_check("boss_home", sp.home == XBattleLayout.BOSS.solo, sp.home)
	_check("boss_scaled_capped", sp.layout_mul > 1.0 and sp.height() <= XBattleLayout.BOSS.solo_cap + 0.5, [sp.layout_mul, sp.height()])
	_check_actors("boss", b, XBattleLayout.BOSS.actor_mul)
	var gap := _actor_box(b).position.x - (sp.home.x + sp.width() / 2.0)
	_check("boss_gap", gap >= 300.0, gap)
	_check_ring("boss", b)
	var img := await _shot("T126_首领战_800x450")
	if img != null:
		_check("boss_no_minion_bar", not _bar_pink(img, b, boss))
	await _close(b)


func _mob4() -> void:
	var b := await _battle(MOB4_TROOP, [8, 9, 10])
	_check("mob4_not_solo", not b.layout_solo())
	var r: Rect2 = XBattleLayout.MOB.enemy_rect
	var homes := b.logic.enemies.map(func(e): return b.sprites[e].home)
	_check("mob4_enemy_rect", homes.all(func(p): return r.grow(1.0).has_point(p)), homes)
	_check("mob4_enemy_cap", b.logic.enemies.all(func(e): return b.sprites[e].layout_mul <= 1.0 + 1e-6 or b.sprites[e].height() <= XBattleLayout.MOB.enemy_cap + 0.5))
	_check_actors("mob4", b, XBattleLayout.MOB.actor_mul)
	var right := 0.0
	for e in b.logic.enemies:
		right = maxf(right, b.sprites[e].home.x + b.sprites[e].width() / 2.0)
	var gap := _actor_box(b).position.x - right
	_check("mob4_gap", gap >= 60.0, gap)
	_check_ring("mob4", b)
	# 第一只挨一刀：显示值拖在后面（橙色拖尾），随后追上
	var first: XEnemy = b.logic.enemies[0]
	first.hp = floorf(first.mhp * 0.55)
	b.update_gauges()
	_check("mob4_trail_lags", b.gauges[first].disp > first.hp, [b.gauges[first].disp, first.hp])
	var img := await _shot("T126_4只小怪_800x450")
	if img != null:
		_check("mob4_bar_pink", b.logic.enemies.all(func(e): return _bar_pink(img, b, e)))
	await _secs(0.8)
	_check("mob4_trail_caught_up", b.gauges[first].disp == first.hp, [b.gauges[first].disp, first.hp])
	await _close(b)


func _mob8() -> void:
	var b := await _battle(MOB8_TROOP, [8, 9, 10])
	var homes := b.logic.enemies.map(func(e): return b.sprites[e].home)
	_check("mob8_enemy_rect", homes.all(func(p): return (XBattleLayout.MOB.enemy_rect as Rect2).grow(1.0).has_point(p)), homes)
	_check("mob8_big_no_scale", b.logic.enemies.all(func(e): return is_equal_approx(b.sprites[e].layout_mul, 1.0)))
	_check_actors("mob8", b, XBattleLayout.MOB.actor_mul)
	_check_ring("mob8", b)
	await _shot("T126_8只怨念之魂_800x450")
	await _close(b)


func _mob3_two() -> void:
	var b := await _battle(MOB3_TROOP, [8])
	_check("two_actors", b.logic.actors.size() == 2)
	_check_actors("mob3_2p", b, XBattleLayout.MOB.actor_mul)
	_check_ring("mob3_2p", b)
	await _shot("T126_3只小怪_2人_800x450")
	await _close(b)


## 原版竖排：我方不撑开、不放大（敌人照样撑开）
func _column() -> void:
	XConfig.set_party_formation(XPartyFormation.COLUMN)
	var b := await _battle(MOB4_TROOP, [8, 9, 10])
	var want := XPartyFormation.points(XPartyFormation.COLUMN, b.logic.actors.size())
	var got := b.logic.actors.map(func(a): return b.sprites[a].home)
	_check("column_actor_unchanged", got == want, [got, want])
	_check("column_actor_mul_1", b.logic.actors.all(func(a): return b.sprites[a].layout_mul == 1.0))
	await _close(b)
	XConfig.set_party_formation(XPartyFormation.ROWS)


## 两个开关都关：原版坐标与大小、原版小血条
func _off() -> void:
	XBattleLayout.ENABLED = false
	XSkinEnemyHp.ENABLED = false
	var b := await _battle(MOB4_TROOP, [8, 9, 10])
	_check("off_enemy_src", b.logic.enemies.all(func(e): return b.sprites[e].home == b.enemy_src_home(e) and b.sprites[e].layout_mul == 1.0))
	var want := XPartyFormation.points(XPartyFormation.ROWS, b.logic.actors.size())
	_check("off_actor_src", b.logic.actors.map(func(a): return b.sprites[a].home) == want)
	_check("off_bar_off", not XSkinEnemyHp.on())
	await _close(b)
	b = await _battle(BOSS_TROOP, [8, 9, 10])
	_check("off_boss_src", b.sprites[b.logic.enemies[0]].home == b.enemy_src_home(b.logic.enemies[0]))
	await _close(b)
	XBattleLayout.ENABLED = true
	XSkinEnemyHp.ENABLED = true


## TOUCH_RING_FIXED＝true：触屏指令环回到右下角（D41）
func _ring_fixed_back() -> void:
	XUiSkin.TOUCH_RING_FIXED = true
	var b := await _battle(MOB4_TROOP, [8, 9, 10])
	var ring := b.cmd_win as XSkinBattleRing
	if ring != null:
		var corner := Vector2(XBattleScene.BOX.x - ring.size.x - XSkinBattleRing.MARGIN, XBattleScene.BOX.y - ring.size.y - XSkinBattleRing.MARGIN)
		_check("fixed_ring_corner", (ring.position - b._origin).distance_to(corner) <= 4.0 or (ring.position - b._origin).y == corner.y, [ring.position - b._origin, corner])
	else:
		_check("fixed_ring_type", false)
	await _close(b)
	XUiSkin.TOUCH_RING_FIXED = false


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin.touch_override = -1
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
