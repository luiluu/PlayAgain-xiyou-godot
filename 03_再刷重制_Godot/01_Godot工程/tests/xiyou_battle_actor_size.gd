extends Node
## 【cc·天启篇】T174 我方统一大小（XBattleLayout.ACTOR_SIZE）专项。内存新游戏，不写存档；新皮肤强开、触屏强开。
## 核：我方全员（旧式角色、167 号起的新角色）身体都是 ACTOR_SIZE 倍（×SvPngFd×外观 scale），小怪战与首领战一样；
## 同尺寸原图屏上一样大；不压右上队伍栏、前后排身体不重叠、头顶不出画面、指令环在画面里；
## 选择光标、状态图标、伤害数字按 height() 走（含新大小）；ACTOR_SIZE＝0 回到 T126（旧角色 1.425／1.2、新角色归一 ×1.9／×1.6）。
## D196 预留：倍数按图的格子大小算（128 格＝1 倍、64 格＝ACTOR_SIZE），假造 128 格图断言；流萤、奈叶、小铃兰（现有大格图）实战按 1 倍。
## 窗口模式加 -- --out=<目录> 出 1280×720 对照截图：现状（0）／A 版 1.6，敌群 37（小怪战）与 88（首领战），A、B 两组；另出胜利镜头一张。
## 用法：Godot --audio-driver Dummy --path . res://tests/xiyou_battle_actor_size.tscn [-- --out=<目录>]

var results := []
var out_dir := ""
var notes := []

const GROUPS := {"A": [1, 11, 175, 174], "B": [176, 177, 178, 180]}
const GROUP_NAMES := {"A": "狗逍遥 里德 谷雨 云裳", "B": "屠苏 璇 哈基米 五条悟"}
const MOB_TROOP := 37    # 英雄谷护卫×3＋【首领】首席法师（多名成员＝小怪战站位）
const BOSS_TROOP := 88   # 守护石巨人（一名成员＝首领战站位）
const SIZES := [0.0, 1.6]
const SIZE_NAMES := {0.0: "现状", 1.6: "A版1.6倍"}
const BIG_CELL := {179: 128, 108: 128, 127: 256}  # 现有大格侧视图：流萤、奈叶、小铃兰（格高）


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


func _run() -> void:
	if _windowed():
		get_window().size = Vector2i(1280, 720)
		await _frames(5)
		DirAccess.make_dir_recursive_absolute(out_dir)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.touch_override = 1
	XSave.dir_override = "user://test_xiyou_battle_actor_size"
	XConfig.path_override = ProjectSettings.globalize_path(XSave.dir().path_join("options.json"))
	XConfig._loaded_path = "<unloaded>"
	XConfig.set_party_formation(XPartyFormation.ROWS)
	XGojo.unlock_override = 1
	XEnemy.force_roll = 100.0
	var keep: float = XBattleLayout.ACTOR_SIZE
	_unit()
	for size in SIZES:
		XBattleLayout.ACTOR_SIZE = size
		for troop in [MOB_TROOP, BOSS_TROOP]:
			for g in GROUPS:
				await _one(troop, g, size)
	if _windowed():
		XBattleLayout.ACTOR_SIZE = 1.6
		await _victory_shot(1.6)
		var f := FileAccess.open(out_dir.path_join("t174_尺寸记录.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(notes, "  "))
		f.close()
	await _cell128_battle()
	await _big_forms()
	await _column()
	XBattleLayout.ACTOR_SIZE = keep
	_finish()


func _unit() -> void:
	XBattleLayout.ACTOR_SIZE = 1.6
	_check("size_same_mob_boss", XBattleLayout.actor_size(true) == 1.6 and XBattleLayout.actor_size(false) == 1.6)
	_check("mul_from_size", is_equal_approx(XBattleLayout.actor_mul(true), 1.6 / XBattleScene.ACTOR_SCALE)
		and is_equal_approx(XBattleLayout.actor_mul(false), 1.6 / XBattleScene.ACTOR_SCALE))
	XBattleLayout.ACTOR_SIZE = 0.0
	_check("off_back_to_t126", XBattleLayout.actor_size(false) == 0.0 and XBattleLayout.actor_mul(false) == XBattleLayout.MOB.actor_mul
		and XBattleLayout.actor_mul(true) == XBattleLayout.BOSS.actor_mul)
	XBattleLayout.ACTOR_SIZE = 1.6
	XUiSkin.FORCE = false
	_check("old_ui_no_size", XBattleLayout.actor_size(false) == 0.0 and XBattleLayout.actor_mul(false) == 1.0)
	XUiSkin.FORCE = true
	XBattleLayout.ENABLED = false
	_check("layout_off_no_size", XBattleLayout.actor_size(true) == 0.0)
	XBattleLayout.ENABLED = true
	# 胜利镜头：对准整队外框中心、装不下就少放大；开关关照原版
	var bodies := [Rect2(760, 200, 130, 130), Rect2(980, 470, 130, 130)]
	var vf := XBattleLayout.victory_focus(bodies, 2.0, false)
	var z: float = vf.get("scale", 0.0)
	var on_screen: Vector2 = XBattleScene.BOX / 2.0 - (vf.get("to", Vector2.ZERO) as Vector2) * z + Rect2(760, 200, 350, 400).get_center() * z
	_check("victory_focus_center", on_screen.distance_to(XBattleLayout.VICTORY_AREA.get_center()) < 0.5, [vf, on_screen])
	_check("victory_focus_fits", z >= 1.0 and z < 2.0 and z * 432.0 <= 720.0 + 0.01 and z * 382.0 <= 680.0 + 0.01, vf)
	XBattleLayout.VICTORY_FOCUS = false
	_check("victory_focus_off", XBattleLayout.victory_focus(bodies, 2.0, false).is_empty())
	XBattleLayout.VICTORY_FOCUS = true
	_unit_cell()


## D196：倍数按格子大小（图宽÷9、图高÷6）。假造一张 128 格（1152×768）、一张 64 格（576×384）侧视图
func _unit_cell() -> void:
	var looks := {}
	for c in [64, 128]:
		var img := Image.create(c * 9, c * 6, false, Image.FORMAT_RGBA8)
		var look := XAppearance.new()
		look._mv_sheet(ImageTexture.create_from_image(img))
		looks[c] = look
	_check("cell_from_sheet", looks[64].cell == Vector2(64, 64) and looks[128].cell == Vector2(128, 128), [looks[64].cell, looks[128].cell])
	_check("cell64_actor_size", XBattleLayout.sheet_size(1.6, looks[64]) == 1.6, XBattleLayout.sheet_size(1.6, looks[64]))
	_check("cell128_native", XBattleLayout.sheet_size(1.6, looks[128]) == 1.0, XBattleLayout.sheet_size(1.6, looks[128]))
	_check("cell_off_zero", XBattleLayout.sheet_size(0.0, looks[128]) == 0.0)
	var single := XAppearance.new()
	single._single(ImageTexture.create_from_image(Image.create(256, 256, false, Image.FORMAT_RGBA8)))
	_check("single_actor_size", XBattleLayout.sheet_size(1.6, single) == 1.6)
	var keep := XBattleLayout.NATIVE_CELL
	XBattleLayout.NATIVE_CELL = 100000.0
	_check("native_cell_rollback", XBattleLayout.sheet_size(1.6, looks[128]) == 1.6)
	XBattleLayout.NATIVE_CELL = keep


func _battle(troop: int, party: Array, prep := Callable()) -> XBattleScene:
	seed(20261118)
	var s := XState.new_game(9, int(party[0]), party.slice(1))  # 难度 9 才放超强者（谷雨、云裳…）入队，建完改回 3
	s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)
	s.difficulty = 3
	for id in party:  # 五条悟只在天启篇能入队：直接放进队伍和出战栏
		if not s.party.has(int(id)):
			s.actor(int(id))
			s.party.append(int(id))
	for i in range(party.size()):
		s.set_battle_slot(i, int(party[i]))
	for a in s.members():
		a.change_level(99)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	if prep.is_valid():
		prep.call(s)
	s.random_master = XRandomStream.hex64(20261118)
	var b := XBattleScene.new()
	b.setup(troop, true, false, {})
	add_child(b)
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("command_shown_%d_%s" % [troop, party], ok)
	await _secs(0.6)
	return b


func _close(b: XBattleScene) -> void:
	b.bgm.stop()
	b.queue_free()
	await _frames(3)


func _body(sp: XBattlerSprite) -> Rect2:
	return Rect2(sp.home - Vector2(sp.width() / 2.0, sp.height()), Vector2(sp.width(), sp.height()))


## 原图（站姿那帧）可见范围：归一档的 bounds，没有档的按一格
func _src_h(sp: XBattlerSprite) -> float:
	return sp.height() / sp.body_scale if sp.body_scale > 0.0 else 0.0


func _one(troop: int, g: String, size: float) -> void:
	var party: Array = GROUPS[g]
	var b := await _battle(troop, party)
	var solo := b.layout_solo()
	var tag := "%s_%d_%s" % [SIZE_NAMES[size], troop, g]
	_check(tag + "_solo", solo == (troop == BOSS_TROOP))
	_check(tag + "_all_on_field", b.logic.actors.size() == party.size() and b.logic.actors.all(func(a): return b.sprites[a].is_inside_tree()),
		b.logic.actors.map(func(a): return a.actor_id))
	var rows := []
	for a in b.logic.actors:
		var sp: XBattlerSprite = b.sprites[a]
		var extra := sp.look.scale * sp.fd
		rows.append({"id": a.actor_id, "name": a.display_name(), "body_scale": snappedf(sp.body_scale, 0.0001), "fd": sp.fd,
			"w": roundf(sp.width()), "h": roundf(sp.height()), "src_h": roundf(_src_h(sp)), "home": [sp.home.x, sp.home.y]})
		if size > 0.0:
			_check(tag + "_size_%d" % a.actor_id, is_equal_approx(sp.body_scale, size * extra), [sp.body_scale, size, extra])
		elif a.actor_id < 167:
			_check(tag + "_old_t126_%d" % a.actor_id, is_equal_approx(sp.body_scale, XBattleScene.ACTOR_SCALE * (XBattleLayout.BOSS.actor_mul if solo else XBattleLayout.MOB.actor_mul) * extra),
				sp.body_scale)
	notes.append({"size": size, "troop": troop, "group": g, "actors": rows})
	# 不压右上队伍栏
	var pr := b.party_rect()
	var panel := Rect2(pr.position - b._origin, pr.size)
	var hit := b.logic.actors.filter(func(a): return _body(b.sprites[a]).grow(-6.0).intersects(panel))
	_check(tag + "_clear_party_panel", hit.is_empty(), [panel, hit.map(func(a): return a.display_name())])
	# 前后排身体不重叠（按可见范围，四边各让 6 像素）
	var over := []
	for i in range(b.logic.actors.size()):
		for j in range(i + 1, b.logic.actors.size()):
			var ri := _body(b.sprites[b.logic.actors[i]]).grow(-6.0)
			var rj := _body(b.sprites[b.logic.actors[j]]).grow(-6.0)
			if ri.intersects(rj):
				over.append([b.logic.actors[i].display_name(), b.logic.actors[j].display_name()])
	_check(tag + "_no_overlap", over.is_empty(), over)
	_check(tag + "_on_screen", b.logic.actors.all(func(a):
		var r := _body(b.sprites[a])
		return r.position.y >= 0.0 and r.end.x <= XBattleScene.BOX.x and r.position.x >= 0.0), b.logic.actors.map(func(a): return _body(b.sprites[a])))
	# 我方与敌人拉开（身体不碰）
	var foe_right := 0.0
	for e in b.logic.enemies:
		if b.sprites[e].visible:
			foe_right = maxf(foe_right, b.sprites[e].home.x + b.sprites[e].width() / 2.0)
	var mine_left := 1280.0
	for a in b.logic.actors:
		mine_left = minf(mine_left, _body(b.sprites[a]).position.x)
	_check(tag + "_gap_to_enemy", mine_left - foe_right >= 40.0, [mine_left, foe_right])
	_check_ring(tag, b)
	if size > 0.0:
		# 同尺寸原图一样大：原图可见高相同的两人，屏上高也相同
		var by_src := {}
		for a in b.logic.actors:
			var sp: XBattlerSprite = b.sprites[a]
			var k := roundi(_src_h(sp) * sp.look.scale * sp.fd)
			by_src[k] = by_src.get(k, []) + [roundf(sp.height())]
		_check(tag + "_same_src_same_h", by_src.values().all(func(v): return v.min() == v.max()), by_src)
	# 伤害数字、状态图标按 height() 走：伤害数字落点在身体中部（我方是脚底原点＋原版偏移，敌人按高度抬）
	await _shot("T174_%s_%s组_%s" % [SIZE_NAMES[size], g, "首领战" if solo else "小怪战"], "%s · %s组（%s）· %s（敌群 %d）" % [
		SIZE_NAMES[size], g, GROUP_NAMES[g], "首领战" if solo else "小怪战", troop])
	await _close(b)


## 指令环在画面里、跟着当前行动的角色
func _check_ring(tag: String, b: XBattleScene) -> void:
	var ring := b.cmd_win as XSkinBattleRing
	if ring == null:
		_check(tag + "_ring_type", false)
		return
	var r := Rect2(ring.position - b._origin, ring.size)
	_check(tag + "_ring_on_screen", r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= XBattleScene.BOX.x + 0.5 and r.end.y <= XBattleScene.BOX.y + 0.5, r)
	var pr := b.party_rect()
	var panel := Rect2(pr.position - b._origin, pr.size)
	# 环的球不进队伍栏（只看环心一圈的外接框与队伍栏的交叠不超过一点点）
	var inter := r.intersection(panel)
	_check(tag + "_ring_clear_panel", inter.get_area() <= r.get_area() * 0.15, [r, panel])


## 胜利镜头（放大 2 倍、镜头点 700,460）：我方站位撑开后有没有被切掉，出图给 Kyo 看
func _victory_shot(size: float) -> void:
	var b := await _battle(MOB_TROOP, GROUPS.A)
	b._victory()  # 不 await：结算画面会一直等确定
	await _frames(2)
	var want := XBattleLayout.victory_focus(b.logic.actors.map(func(a): return _body(b.sprites[a])), 2.0, false)
	_check("victory_cam_%s" % size, b._camera.get("to") == want.get("to") and b._camera.get("scale") == want.get("scale"), [b._camera.get("to"), want])
	await _secs(5.5)
	await _shot("T174_%s_胜利镜头" % SIZE_NAMES[size], "%s · 胜利镜头（小怪战 A组）" % SIZE_NAMES[size])
	await _close(b)


## 大格旧图（流萤 128、奈叶 128、小铃兰 256）同狗逍遥一场：大格的 1 倍、归一档的可见身高落在约 100（80～130）；狗逍遥 1.6 倍；光标同高。
## 哈基米底图 128 格但画逐帧图，照 1.6（B 组的 size_178 核）
func _cell128_battle() -> void:
	XBattleLayout.ACTOR_SIZE = 1.6
	var b := await _battle(MOB_TROOP, [1] + BIG_CELL.keys())
	var gxy: XBattlerSprite = null
	for a in b.logic.actors:
		if a.actor_id == 1:
			gxy = b.sprites[a]
	_check("big_cell_on_field", gxy != null and b.logic.actors.size() == 1 + BIG_CELL.size(), b.logic.actors.map(func(a): return a.actor_id))
	if gxy == null:
		await _close(b)
		return
	_check("gxy_1_6", is_equal_approx(gxy.body_scale, 1.6 * gxy.look.scale * gxy.fd), gxy.body_scale)
	var rows := [{"id": 1, "h": roundf(gxy.height()), "body_scale": gxy.body_scale}]
	for a in b.logic.actors:
		if not BIG_CELL.has(a.actor_id):
			continue
		var sp: XBattlerSprite = b.sprites[a]
		var tag := "big_cell_%d" % a.actor_id
		_check(tag + "_cell", sp.look.cell.y == float(BIG_CELL[a.actor_id]), sp.look.cell)
		_check(tag + "_native_1x", is_equal_approx(sp.body_scale, 1.0 * sp.look.scale * sp.fd), [sp.body_scale, sp.look.scale, sp.fd])
		# 归一档（167 号起）的 height() 是可见身高；旧角色（奈叶、小铃兰）照原版按一格算，可见身高另量过（98／102），这里只核归一档
		if not sp._profile.is_empty():
			_check(tag + "_height_about_100", sp.height() >= 80.0 and sp.height() <= 130.0, sp.height())
		if sp.cursor and gxy.cursor:
			_check(tag + "_cursor_same", is_equal_approx(sp.cursor.position.y, gxy.cursor.position.y), [sp.cursor.position.y, gxy.cursor.position.y])
		rows.append({"id": a.actor_id, "h": roundf(sp.height()), "body_scale": sp.body_scale})
	notes.append({"size": 1.6, "troop": MOB_TROOP, "group": "大格旧图", "actors": rows})
	# swap_look 换到不同格子大小的图：流萤 128 格 → 萨姆态 64 格（Codex_Sam_SV）→ 换回
	for a in b.logic.actors:
		if a.actor_id != 179:
			continue
		var sp: XBattlerSprite = b.sprites[a]
		var own_key: String = sp._look_key
		sp.swap_look("Codex_Sam_SV")  # 不等帧：精灵每帧会按角色此刻的外观键换回来，这里直接核换装那一下
		_check("swap_to_cell64", sp.look.cell.y == 64.0 and is_equal_approx(sp.body_scale, 1.6 * sp.look.scale * sp.fd), [sp._look_key, sp.look.cell, sp.body_scale])
		sp.swap_look(own_key)
		_check("swap_back_cell128", sp.look.cell.y == 128.0 and is_equal_approx(sp.body_scale, 1.0 * sp.look.scale * sp.fd), [sp._look_key, sp.look.cell, sp.body_scale])
	await _close(b)


## 小A 核 P1-1／P2-1／P2-2：大画布逐帧形态（167 渡鸦神话 UserSV_RavenMythic 380×280、168 米拉黑龙 UserSV_MiraDragon 340×280）
## 统一大小时按归一缩放只缩不放：屏上身高约 115（≤130），不碰队伍栏、前后排不叠；缩到 <1 照旧平滑采样。
## 米拉开战是人形（≤130），战中 swap_look 换黑龙后再核；64↔128 格换装在 _cell128_battle 里核（流萤↔萨姆态）。
func _big_forms() -> void:
	XBattleLayout.ACTOR_SIZE = 1.6
	for troop in [MOB_TROOP, BOSS_TROOP]:
		var b := await _battle(troop, [1, 11, 167, 168], func(s: XState):
			s.switches[2494] = true
			s.raven["myth"] = 3
			s.actor_advance[XMira.ACTOR] = 3
			var m := s.actor(XMira.ACTOR)
			m.learn_skill(10161)
			m.state_ids.append(XMira.DRAGON))
		var tag := "big_form_%d" % troop
		var by := {}
		for a in b.logic.actors:
			by[a.actor_id] = b.sprites[a]
		# 开战时状态会重算，米拉照人形进场：战中加黑龙状态，精灵走 swap_look 换黑龙，换完再核
		if by.has(168):
			var mira: XBattlerSprite = by[168]
			_check(tag + "_mira_human_h", mira.height() >= 80.0 and mira.height() <= 130.0, [mira._look_key, mira.height(), mira.body_scale])
			b.logic._state_add(mira.battler, XMira.DRAGON)  # 变身：加 2592，精灵下一帧按新外观键 swap_look 换黑龙
			await _until(func(): return str(mira._look_key).contains("MiraDragon"), 60)
		_check(tag + "_keys", by.has(167) and by.has(168) and str(by[167]._look_key).contains("RavenMythic") and str(by[168]._look_key).contains("MiraDragon"),
			[by.get(167).get("_look_key") if by.has(167) else null, by.get(168).get("_look_key") if by.has(168) else null])
		var rows := []
		for id in by:
			var sp: XBattlerSprite = by[id]
			rows.append({"id": id, "key": sp._look_key, "w": roundf(sp.width()), "h": roundf(sp.height()), "body_scale": snappedf(sp.body_scale, 0.0001)})
			_check(tag + "_h_%d" % id, sp.height() >= 80.0 and sp.height() <= 130.0, [sp._look_key, sp.width(), sp.height(), sp.body_scale])
		for id in [167, 168]:
			if by.has(id):
				var sp: XBattlerSprite = by[id]
				_check(tag + "_shrink_%d" % id, sp.body_scale < 1.0 and is_equal_approx(sp.body_scale, 1.6 * float(sp._profile.get("scale", 0.0)) * sp.look.scale * sp.fd),
					[sp.body_scale, sp._profile.get("scale")])
				_check(tag + "_smooth_%d" % id, (sp.sprite as Sprite2D).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, (sp.sprite as Sprite2D).texture_filter)
		_check(tag + "_gxy_nearest", (by[1].sprite as Sprite2D).texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR)
		notes.append({"size": 1.6, "troop": troop, "group": "大画布逐帧形态", "actors": rows})
		_layout_checks(tag, b)
		await _close(b)


## 不压右上队伍栏、前后排身体不重叠（各让 6 像素）、不出画面
func _layout_checks(tag: String, b: XBattleScene) -> void:
	var pr := b.party_rect()
	var panel := Rect2(pr.position - b._origin, pr.size)
	var hit := b.logic.actors.filter(func(a): return _body(b.sprites[a]).grow(-6.0).intersects(panel))
	_check(tag + "_clear_party_panel", hit.is_empty(), [panel, hit.map(func(a): return [a.display_name(), _body(b.sprites[a])])])
	var over := []
	for i in range(b.logic.actors.size()):
		for j in range(i + 1, b.logic.actors.size()):
			var ri := _body(b.sprites[b.logic.actors[i]]).grow(-6.0)
			var rj := _body(b.sprites[b.logic.actors[j]]).grow(-6.0)
			if ri.intersects(rj):
				over.append([b.logic.actors[i].display_name(), b.logic.actors[j].display_name(), ri, rj])
	_check(tag + "_no_overlap", over.is_empty(), over)
	_check(tag + "_on_screen", b.logic.actors.all(func(a):
		var r := _body(b.sprites[a])
		return r.position.y >= 0.0 and r.end.x <= XBattleScene.BOX.x and r.position.x >= 0.0), b.logic.actors.map(func(a): return _body(b.sprites[a])))


## 原版竖排：我方不放大（同列间隔按 72 高留的）
func _column() -> void:
	XBattleLayout.ACTOR_SIZE = 1.6
	XConfig.set_party_formation(XPartyFormation.COLUMN)
	var b := await _battle(MOB_TROOP, GROUPS.A)
	_check("column_no_size", b.logic.actors.all(func(a): return b.sprites[a].fixed_scale == 0.0 and b.sprites[a].layout_mul == 1.0))
	await _close(b)
	XConfig.set_party_formation(XPartyFormation.ROWS)


func _shot(name: String, title: String) -> void:
	if not _windowed():
		return
	var layer := CanvasLayer.new()
	layer.layer = 120
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.position = Vector2(8, 8)
	var l := Label.new()
	l.theme = XUI.theme()
	l.text = title
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
	l.position = Vector2(18, 12)
	layer.add_child(bg)
	layer.add_child(l)
	add_child(layer)
	bg.size = Vector2(l.get_combined_minimum_size().x + 22, 42)
	await _frames(10)
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	_check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	layer.queue_free()


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin.touch_override = -1
	XEnemy.force_roll = -1.0
	XGojo.unlock_override = -1
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
