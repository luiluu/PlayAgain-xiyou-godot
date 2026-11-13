extends Node
## 像素柔边（XGraphics.crisp_on、XBattlerSprite 身体材质的 crisp；设计见 00_设计/画质设置.md）：
## - 默认开：最近邻的战斗图（敌人、角色）身体材质 crisp＝true，过滤方式不变（仍最近邻）；
## - 设置里关、或回退开关 XGraphics.CRISP＝false、或整组 XGraphics.ENABLED＝false：crisp＝false；
## - 平滑采样的归一角色（缩小的 168 等）不开 crisp；
## - 子页多一行「像素柔边」，右开左关；回退开关关掉时不列。
## 带 -- --out=<目录> 在真窗口里跑时另存开、关两张对比图（建议 --resolution 1920x1080，即 1.5 倍）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

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
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _crisp(sp: XBattlerSprite) -> bool:
	return sp.sprite.material is ShaderMaterial and (sp.sprite.material as ShaderMaterial).get_shader_parameter("crisp") == true


func _make(b: XBattler, pos: Vector2) -> XBattlerSprite:
	var s := XBattlerSprite.new()
	add_child(s)
	s.setup(b, 1.0)
	s.position = pos
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_crisp_scale")
	XPlatform.force_mobile = false
	var back := ColorRect.new()
	back.color = Color("#3a4a5c")
	back.size = Vector2(1280, 720)
	add_child(back)
	var label := Label.new()
	label.theme = XUI.theme()
	label.text = "像素柔边对比：文字应保持锐利"
	label.position = Vector2(40, 30)
	add_child(label)
	XState.current = XState.new_game(3, 1, [8, 9, 10])

	check("default_on", XGraphics.settings()["crisp"] == true and XGraphics.crisp_on())
	var sprites: Array = []
	var x := 160.0
	for id in [1, 6, 21]:
		sprites.append(_make(XEnemy.new().setup(id, 1), Vector2(x, 460)))
		x += 260.0
	var actor: XActor = XState.current.battle_members()[0]
	if actor != null:
		sprites.append(_make(actor, Vector2(1000, 460)))
	await frames(3)
	for i in sprites.size():
		var sp: XBattlerSprite = sprites[i]
		if sp.sprite is Sprite2D:
			check("crisp_on_%d" % i, _crisp(sp))
			check("filter_kept_%d" % i, sp.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
				and (sp.sprite as Sprite2D).texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE)
	# 身体材质常在、blend 没设过时，anim_blend 仍给透明色（不是 null）
	check("anim_blend_default", sprites.all(func(sp): return sp.anim_blend() == Color(0, 0, 0, 0)))
	await shot("crisp_on")

	# 设置里关
	XGraphics.set_value("crisp", false)
	check("setting_off", not XGraphics.crisp_on())
	for sp in sprites:
		sp._apply_smooth()
	await frames(2)
	check("crisp_off_all", sprites.all(func(sp): return not _crisp(sp)))
	await shot("crisp_off")
	# 关着时新建的图也不开
	var plain := _make(XEnemy.new().setup(1, 1), Vector2(-500, -500))
	await frames(1)
	check("off_new_sprite", not _crisp(plain))
	plain.queue_free()
	XGraphics.set_value("crisp", true)

	# 回退开关
	XGraphics.CRISP = false
	check("switch_off", not XGraphics.crisp_on())
	check("switch_off_no_row", not XGraphicsOptionsScene.rows().any(func(r): return r[0] == "crisp"))
	XGraphics.CRISP = true
	XGraphics.ENABLED = false
	check("group_off", not XGraphics.crisp_on())
	XGraphics.ENABLED = true
	check("back_on", XGraphics.crisp_on())

	# 子页：像素柔边在第一行，右开左关
	var page := XGraphicsOptionsScene.new()
	add_child(page)
	await frames(2)
	check("page_first_row", page.keys()[0] == "crisp" and page.status_text(0) == "开", page.keys())
	page.side(false)
	check("page_left_off", not XGraphics.settings()["crisp"] and page.status_text(0) == "关")
	page.side(true)
	check("page_right_on", XGraphics.settings()["crisp"])
	page.queue_free()

	XPlatform.force_mobile = null
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
