extends Node
## 角色外观接口（XAppearance）：默认照正式版（MV 侧视图格子＝图宽÷9×图高÷6、循环 0,1,2,1、敌人单图、行走图 3×4），
## appearances.json 覆盖（grid / frames / scene / characters）能被战斗图、行动条头像与行走图用上，缺的动作按 FALLBACK 退。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	XAppearance.overrides = {}
	_defaults()
	_grid()
	_frames()
	await _scene()
	_super_sv()
	_walk()
	XAppearance.overrides = null
	finish()


func _defaults() -> void:
	var a := XAppearance.for_image("sv_actors/gxysv2")
	check("mv.cell", a.cell == Vector2(64, 64), a.cell)
	check("mv.loop_pingpong", a.frame_count("walk") == 4 and a.frame("walk", 3).rect == Rect2(64, 0, 64, 64), a.frame("walk", 3))
	check("mv.non_loop", a.frame_count("swing") == 3 and not a.is_loop("swing"))
	# 动作 7（swing）在第 2 列组、第 1 行：cx = 3 + p，cy = 1
	check("mv.swing_rect", a.frame("swing", 2).rect == Rect2(5 * 64, 64, 64, 64), a.frame("swing", 2).rect)
	check("mv.dead_rect", a.frame("dead", 0).rect == Rect2(6 * 64, 5 * 64, 64, 64), a.frame("dead", 0).rect)
	check("mv.portrait", a.portrait_rect == Rect2(0, 0, 64, 64))
	# 1152×768 的侧视图：一格 128（MV 按图宽÷9，原来 Godot 写死 64 会只截到四分之一）
	var big := XAppearance.for_image("sv_actors/DaoMen")
	check("mv.big_cell", big.cell == Vector2(128, 128) and big.frame("wait", 1).rect == Rect2(128, 128, 128, 128), big.cell)
	var tall := XAppearance.for_image("sv_actors/Enemy_Centaur1")
	check("mv.non_square_cell", tall.cell == Vector2(64, 67), tall.cell)
	var e := XAppearance.for_image("sv_enemies/0-MOD1")
	check("single.not_animated", not e.animated() and e.frame_count("swing") == 1 and not e.portrait_rect.has_area())
	# 战斗图：角色 1 默认外观与旧行为一致（cell 64、光标高 64、脚底原点）
	var s := XState.new_game(3, 1, [])
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(s.actor(1), 0.75)
	sp.set_motion("swing")
	var body := sp.sprite as Sprite2D
	check("sprite.mv_frame", body.region_rect == Rect2(3 * 64, 64, 64, 64) and body.offset.y == -32.0, [body.region_rect, body.offset])
	check("sprite.size", is_equal_approx(sp.width(), 48.0) and (sp.cursor == null or is_equal_approx(sp.cursor.position.y, -64.0)))
	for i in range(3 * XBattlerSprite.MOTION_SPEED):
		sp._physics_process(0.0)
	check("sprite.non_loop_returns_idle", sp.motion == "walk", sp.motion)
	sp.queue_free()


func _grid() -> void:
	XAppearance.overrides = {"battlers": {"sv_actors/gxysv2": {"kind": "grid", "cell": [32, 48],
		"wait": 2, "scale": 2.0, "hideShadow": true,
		"motions": {"walk": {"row": 1, "col": 2, "frames": 6}, "skill": {"row": 3, "frames": 5, "loop": false, "wait": 4}}}}}
	var a := XAppearance.for_image("sv_actors/gxysv2")
	check("grid.default_image", a.frame("walk", 0).tex != null)
	check("grid.cell", a.cell == Vector2(32, 48) and a.kind == "frames" and a.sideview)
	check("grid.walk", a.frame_count("walk") == 6 and a.frame("walk", 5).rect == Rect2(7 * 32, 48, 32, 48), a.frame("walk", 5).rect)
	check("grid.fallback_swing_to_skill", a.resolve("swing") == "skill" and a.resolve("thrust") == "skill" and a.resolve("guard") == "walk",
		[a.resolve("swing"), a.resolve("guard")])
	check("grid.wait", a.wait_of("walk") == 2 and a.wait_of("swing") == 4)
	var s := XState.new_game(3, 1, [])
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(s.actor(1), 0.75)
	check("grid.scale_shadow", is_equal_approx(sp.body_scale, 1.5) and sp.shadow == null, sp.body_scale)
	sp.set_motion("swing")
	for i in range(4 * 4):
		sp._physics_process(0.0)
	check("grid.plays_skill_frames", sp._frame == 4 and (sp.sprite as Sprite2D).region_rect == Rect2(4 * 32, 3 * 48, 32, 48),
		[sp._frame, (sp.sprite as Sprite2D).region_rect])
	for i in range(4):
		sp._physics_process(0.0)
	check("grid.non_loop_end_idle", sp.motion == "walk")
	sp.queue_free()
	XAppearance.overrides = {}


func _frames() -> void:
	XAppearance.overrides = {"battlers": {"sv_enemies/0-MOD1": {"kind": "frames", "portrait": "sv_enemies/0-MOD2",
		"motions": {"walk": {"images": ["sv_enemies/0-MOD1", "sv_enemies/0-MOD2", "sv_enemies/缺图"]}}}}}
	var a := XAppearance.for_image("sv_enemies/0-MOD1")
	check("frames.skip_missing", a.frame_count("walk") == 2 and a.frame_count("dead") == 2 and a.animated())
	check("frames.cell_from_first", a.cell == (a.frame("walk", 0).tex as Texture2D).get_size())
	check("frames.portrait", a.portrait_tex != null and a.portrait_tex == a.frame("walk", 1).tex)
	XAppearance.overrides = {}


## 场景外观：根节点 Node2D 下放 AnimatedSprite2D（walk 循环、skill 一帧不循环），swing 退到 skill，播完回待机
func _scene() -> void:
	var tex: Texture2D = load(XDB.img_path("sv_enemies", "0-MOD1"))
	var frames := SpriteFrames.new()
	frames.add_frame("default", tex)
	frames.add_animation("walk")
	frames.add_frame("walk", tex)
	frames.add_animation("skill")
	frames.set_animation_loop("skill", false)
	frames.set_animation_speed("skill", 60.0)
	frames.add_frame("skill", tex)
	var root := Node2D.new()
	var anim := AnimatedSprite2D.new()
	anim.name = "Body"
	anim.sprite_frames = frames
	root.add_child(anim)
	anim.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	var path := "user://appearance_test_scene.tscn"
	ResourceSaver.save(packed, path)
	XAppearance.overrides = {"battlers": {"sv_actors/gxysv2": {"kind": "scene", "scene": path, "size": [80, 120]}}}
	var a := XAppearance.for_image("sv_actors/gxysv2")
	check("scene.loaded", a.kind == "scene" and a.scene != null and a.cell == Vector2(80, 120))
	var s := XState.new_game(3, 1, [])
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(s.actor(1), 1.0)
	var body := sp.sprite.get_node("Body") as AnimatedSprite2D
	check("scene.walk", body.animation == "walk" and body.is_playing(), body.animation)
	check("scene.size", is_equal_approx(sp.height(), 120.0) and (sp.cursor == null or is_equal_approx(sp.cursor.position.y, -120.0)))
	sp.set_motion("swing")
	check("scene.fallback", body.animation == "skill", body.animation)
	for i in range(10):
		await get_tree().process_frame
	check("scene.finished_to_idle", sp.motion == "walk" and body.animation == "walk", [sp.motion, body.animation])
	sp.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	XAppearance.overrides = {}


## Mx_SuperSV：图不在时保留原侧视图；YCyy 隐藏影子
func _super_sv() -> void:
	var a := XAppearance.for_image("sv_actors/gxysv2", {"sv": "不存在", "SVzs0": "8", "SVspeed": "12", "YCyy": "true", "Cfdz0": "[1,9]"})
	check("supersv.missing_keeps_sheet", a.frame_count("walk") == 4 and a.frame("walk", 0).rect == Rect2(0, 0, 64, 64) and a.hide_shadow)
	var b := XAppearance.for_image("sv_actors/gxysv2", {"sv": "../x", "SVzs0": "8"})
	check("supersv.rejects_path", b.frame_count("walk") == 4 and not b.hide_shadow)


func _walk() -> void:
	var tex: Texture2D = load(XDB.img_path("characters", "Actor2"))
	var w := XAppearance.walk("Actor2", 6, tex)
	var pw := tex.get_width() / 12.0
	var ph := tex.get_height() / 8.0
	check("walk.mv", w.cell == Vector2(pw, ph) and w.origin == Vector2(2 * 3 * pw, 4 * ph) and w.sequence == [0, 1, 2, 1] and w.stand == 1, w)
	XAppearance.overrides = {"characters": {"Actor2": {"frames": 6, "sequence": [0, 1, 2, 3, 4, 5], "stand": 0, "cell": [32, 40], "rows": {"8": 0, "2": 3}}}}
	w = XAppearance.walk("Actor2", 6, tex)
	check("walk.override", w.cell == Vector2(32, 40) and w.origin == Vector2.ZERO and w.sequence.size() == 6 and w.rows[8] == 0 and w.rows[2] == 3, w)
	var c := MVCharacter.new()
	add_child(c)
	c.set_image("Actor2", 6)
	c.pattern = 0
	c.step_anime = true
	for i in range(6 * (9 - c.move_speed) * 3):
		c._update_animation()
	check("walk.cycle_uses_sequence", c.pattern == 0, c.pattern)
	c.step_anime = false
	c.pattern = 3
	for i in range(8):
		c._update_animation()
	check("walk.stand_index", c.pattern == 0, c.pattern)
	c.queue_free()
	XAppearance.overrides = {}


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
