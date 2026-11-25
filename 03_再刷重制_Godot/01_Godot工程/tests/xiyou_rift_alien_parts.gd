extends Node
## T505 西游档异化三级附加件专项（XRiftAlienParts；素材 content/monsters/rift/，T504）。
## 一、样本怪（鱼人士兵、圣骑士·瑟伦、黝石巨人之影）待机首帧可见范围＝anchors 登记的样本范围，倍数 1，各件落在样本原位（与定稿板同位）。
## 二、层次：前件挂在身体下（身体开 clip_children），后件在战场里所有战斗者精灵之前；按级件数 1／3／5。
## 三、偏色：挂上时 parts_tier_glow 0.04／0.06／0.08；关开关、素材不齐时回原 tier_glow 并拆件。
## 四、天启篇存档不挂；倒下淡出后件跟着不见；换级重挂；精灵释放时后件一起清；镜像时后件跟着翻。
## 带窗口跑时（-- --out=<目录>）另出实战截图：多怪邻位三档、镜像翻面、受击、守层者与首领各三档。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func _shot(name: String) -> void:
	if not _windowed():
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	_check("shot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)


func _state() -> XState:
	seed(20261125)
	var s := XState.new_game(3, 1, [1, 2, 3])
	for a in s.members():
		a.change_level(99)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261125)
	XState.current = s
	return s


func _set_tier(e: XEnemy, tier: String) -> void:
	var look: Dictionary = e.get_meta(XRiftAlien.LOOK, {"pulse": false, "flash": false, "tier": ""})
	look = look.duplicate()
	look["tier"] = tier
	look["pulse"] = false
	look["flash"] = false
	e.set_meta(XRiftAlien.LOOK, look)


## tiers：敌人序号 → 级（其余敌人清掉异化级）
func _battle(troop: int, tiers: Dictionary) -> XBattleScene:
	_state()
	var b := XBattleScene.new()
	b.setup(troop, true, false, {})
	# 先撤掉开战随机掷出的异化，再按要的级走 XRiftAlien.apply（同实战：名字前缀、生命、偏色标记一起上）
	var f := XRiftAlien.fight(b.logic)
	f.get("units", {}).clear()
	for i in range(b.logic.enemies.size()):
		var e: XEnemy = b.logic.enemies[i]
		if e.has_meta("tianqi_prefix"):
			e.remove_meta("tianqi_prefix")
		_set_tier(e, "")
	var rows := []
	for i in tiers:
		rows.append({"enemy": b.logic.enemies[i], "tier": str(tiers[i]), "kind": "berserk", "class": "boss"})
	XRiftAlien.apply(b.logic, rows)
	add_child(b)
	await _frames(30 if _windowed() else 6)
	return b


func _close(b: XBattleScene) -> void:
	if b.bgm:
		b.bgm.stop()
	b.queue_free()
	await _frames(3)


func _parts(b: XBattleScene, i: int) -> XRiftAlienParts:
	var sp: XBattlerSprite = b.sprites[b.logic.enemies[i]]
	return sp.rift_parts if sp.rift_parts != null and is_instance_valid(sp.rift_parts) else null


func _run() -> void:
	TestEnv.isolate("xiyou_rift_alien_parts")
	XSplashScreen.shown = true
	XMessageBox.auto = true
	XRiftAlien.reload_table()
	XRiftAlienParts.reload()
	XRiftAlien.STAGE_OVERRIDE = 3
	_check("default_on", XRiftAlienParts.ENABLED)
	_data()
	await _reference(19, "finbone", "【精英】鱼人士兵")
	await _reference(111, "humanoid", "【守层者】圣骑士·瑟伦")
	await _reference(148, "rockshell", "【被封印者】黝石巨人之影")
	await _layers()
	await _glow_and_switch()
	await _tianqi()
	await _exit()
	if _windowed():
		await _shots()
	XRiftAlien.STAGE_OVERRIDE = 0
	XRiftAlienParts.ENABLED = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _data() -> void:
	var a := XRiftAlienParts.anchors()
	var p := XRiftAlienParts.profiles()
	_check("anchors_loaded", a.get("profiles", {}).size() == 3 and a.get("stack", {}).size() == 3)
	_check("profiles_loaded", p.get("by_enemy", {}).size() == 894 and p.get("review", []).size() == 404,
		[p.get("by_enemy", {}).size(), p.get("review", []).size()])
	var ok := true
	for prof in ["humanoid", "finbone", "rockshell"]:
		for t in ["qinran", "shigu", "huaxing"]:
			ok = ok and XRiftAlienParts.parts_ready(prof, t)
	_check("all_parts_ready", ok)
	_check("unknown_tier_not_ready", not XRiftAlienParts.parts_ready("humanoid", "zhongyan"))
	_check("profile_by_id", XRiftAlienParts.profile_of(XEnemy.new().setup(18, 3, 100.0)) == "finbone"
		and XRiftAlienParts.profile_of(XEnemy.new().setup(114, 3, 100.0)) == "humanoid"
		and XRiftAlienParts.profile_of(XEnemy.new().setup(149, 3, 100.0)) == "rockshell")
	var lk: Dictionary = XRiftAlien.data().get("look", {})
	_check("parts_glow_values", lk.get("parts_tier_glow", {}) == {"qinran": 0.04, "shigu": 0.06, "huaxing": 0.08}, lk.get("parts_tier_glow"))


## 样本怪化形：可见范围、倍数 1、每件位置＝一格左上＋offset_from_body_cell_px（定稿板复现）
func _reference(troop: int, prof: String, name: String) -> void:
	var b := await _battle(troop, {0: "huaxing"})
	var e: XEnemy = b.logic.enemies[0]
	var sp: XBattlerSprite = b.sprites[e]
	var n := _parts(b, 0)
	_check("ref_attached_" + prof, n != null and n.profile == prof and n.tier == "huaxing", [e.data().get("name"), n])
	if n == null:
		await _close(b)
		return
	var pr: Dictionary = XRiftAlienParts.anchors().profiles[prof]
	var body := sp.sprite as Sprite2D
	var f: Dictionary = sp.look.frame("walk", 0)
	var region: Rect2 = f.get("rect", Rect2())
	var cell := region.size if region.has_area() else Vector2(f.tex.get_size())
	var vis := XRiftAlienParts.visible_rect(f.tex, region, body.flip_h)
	var rv: Array = pr.reference_visible_rect_px
	_check("ref_visible_" + prof, vis == Rect2(rv[0], rv[1], rv[2] - rv[0], rv[3] - rv[1]) and cell == Vector2(pr.reference_cell_px[0], pr.reference_cell_px[1]),
		[name, vis, rv, cell])
	var tl := Vector2(-cell.x / 2.0, -cell.y)
	var bad := []
	var sprites := {}
	for c in n.front.get_children() + n.get_children():
		if c is Sprite2D:
			sprites[c.texture.resource_path.trim_prefix(XRiftAlienParts.DIR + prof + "/")] = c
	for part_name in pr.parts:
		var sp2: Sprite2D = sprites.get(part_name)
		var off: Array = pr.parts[part_name].offset_from_body_cell_px
		if sp2 == null or sp2.scale != Vector2.ONE or not sp2.position.is_equal_approx(tl + Vector2(off[0], off[1])):
			bad.append([part_name, sp2.position if sp2 else null, tl + Vector2(off[0], off[1])])
	_check("ref_positions_" + prof, bad.is_empty() and sprites.size() == 5, bad)
	await _close(b)


## 层次：前件在身体下且身体裁切，后件在战场所有战斗者精灵前；件数 1／3／5
func _layers() -> void:
	var b := await _battle(20, {0: "huaxing", 1: "shigu", 2: "qinran"})
	var counts := []
	for i in range(3):
		var n := _parts(b, i)
		counts.append([n.front.get_child_count(), n.get_child_count()] if n else null)
	_check("tier_part_counts", counts == [[3, 2], [2, 1], [1, 0]], counts)
	var n0 := _parts(b, 0)
	var sp0: XBattlerSprite = b.sprites[b.logic.enemies[0]]
	_check("front_under_body_clipped", n0 != null and n0.front.get_parent() == sp0.sprite and sp0.sprite.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW)
	var min_idx := 1 << 30
	for c in b.field.get_children():
		if c is XBattlerSprite:
			min_idx = mini(min_idx, c.get_index())
	var backs := []
	for i in range(2):
		var n := _parts(b, i)
		backs.append(n != null and n.get_parent() == b.field and n.get_index() < min_idx)
	_check("back_behind_all_battlers", backs == [true, true], backs)
	_check("qinran_no_back_node", _parts(b, 2) != null and not _parts(b, 2).is_inside_tree())
	# 后件跟身体：全局变换一致；镜像时一起翻
	await _frames(2)
	_check("back_follows_body", n0.global_transform.origin.is_equal_approx(sp0.sprite.global_transform.origin), [n0.global_position, sp0.sprite.global_position])
	sp0.set_mirror(true)
	await _frames(2)
	_check("back_follows_mirror", n0.global_transform.x.x < 0.0 and sp0.sprite.global_transform.x.x < 0.0, n0.global_transform)
	sp0.set_mirror(false)
	await _close(b)


## 偏色：挂件时 parts_tier_glow；关开关拆件回原 tier_glow；换级重挂
func _glow_and_switch() -> void:
	var b := await _battle(19, {0: "shigu"})
	var e: XEnemy = b.logic.enemies[0]
	var sp: XBattlerSprite = b.sprites[e]
	_check("glow_parts_shigu", is_equal_approx(XRiftAlien.tint(e, 0.0).a, 0.06) and e.has_meta(XRiftAlien.PARTS), XRiftAlien.tint(e, 0.0))
	_set_tier(e, "huaxing")
	await _frames(2)
	_check("retier_huaxing", _parts(b, 0) != null and _parts(b, 0).tier == "huaxing" and is_equal_approx(XRiftAlien.tint(e, 0.0).a, 0.08))
	_check("no_tier_no_parts", _parts(b, 1) == null and not b.logic.enemies[1].has_meta(XRiftAlien.PARTS))
	XRiftAlienParts.ENABLED = false
	await _frames(2)
	_check("off_detaches", _parts(b, 0) == null and not e.has_meta(XRiftAlien.PARTS)
		and sp.sprite.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED and sp.sprite.get_child_count() == 0)
	_check("off_glow_original", is_equal_approx(XRiftAlien.tint(e, 0.0).a, 0.5), XRiftAlien.tint(e, 0.0))
	var stray := b.field.get_children().filter(func(c): return c is XRiftAlienParts and not c.is_queued_for_deletion())
	_check("off_no_stray_back", stray.is_empty(), stray.size())
	XRiftAlienParts.ENABLED = true
	await _frames(2)
	_check("on_again_attaches", _parts(b, 0) != null)
	await _close(b)


## 天启篇存档：XRiftAlien.on 为假，一概不挂
func _tianqi() -> void:
	var b := await _battle(19, {0: "huaxing"})
	_check("xiyou_attached", _parts(b, 0) != null)
	var keep := XState.current
	var lineup := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 5)
	var tq := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	XState.current = tq
	await _frames(2)
	_check("tianqi_no_parts", _parts(b, 0) == null and XRiftAlienParts.want_tier(b.logic.enemies[0]) == "")
	XState.current = keep
	await _close(b)


## 退场：倒下淡出时后件跟着透明；战斗画面（精灵）释放后后件清掉
func _exit() -> void:
	var b := await _battle(20, {0: "huaxing"})
	var e: XEnemy = b.logic.enemies[0]
	var sp: XBattlerSprite = b.sprites[e]
	var n := _parts(b, 0)
	sp.collapse()
	await _frames(40)
	_check("collapse_back_hidden", n != null and is_instance_valid(n) and (not n.visible or n.modulate.a <= 0.01), [n.visible, n.modulate] if n else null)
	await _close(b)
	_check("free_clears_back", not is_instance_valid(n))


func _shots() -> void:
	# 实战一场最多一只异化（max_units 1）：异化怪站在普通邻怪中间
	var b := await _battle(20, {0: "huaxing"})
	await _frames(60)
	await _shot("01_邻位_首领捕猎者化形")
	await _close(b)
	b = await _battle(20, {1: "huaxing"})
	await _frames(60)
	await _shot("02_邻位_精英鱼人化形")
	var sp1: XBattlerSprite = b.sprites[b.logic.enemies[1]]
	sp1.flash(Color(1, 1, 1))
	sp1.set_motion("damage")
	await _frames(4)
	await _shot("03_受击_精英鱼人化形")
	await _frames(30)
	for sp in b.sprites.values():
		if sp.battler is XEnemy:
			sp.set_mirror(true)
	await _frames(4)
	await _shot("04_翻面_精英鱼人化形")
	await _close(b)
	for t in ["qinran", "shigu", "huaxing"]:
		b = await _battle(19, {1: t})
		await _frames(30)
		await _shot("05_精英鱼人邻位_" + t)
		await _close(b)
	for t in ["qinran", "shigu", "huaxing"]:
		b = await _battle(111, {0: t})
		await _frames(30)
		await _shot("06_守层者瑟伦_" + t)
		await _close(b)
	for t in ["qinran", "shigu", "huaxing"]:
		b = await _battle(148, {0: t})
		await _frames(30)
		await _shot("07_首领黝石巨人_" + t)
		await _close(b)
