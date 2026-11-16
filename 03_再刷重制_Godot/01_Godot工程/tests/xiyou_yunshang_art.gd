extends Node
## D164 云裳原生像素图：完整动作、1:1归一、最近邻及真实战斗截图。
var failed := 0
var total := 0
func check(label: String, ok: bool) -> void:
	total += 1
	if not ok:
		failed += 1
		print("FAIL ", label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var s := XState.new_game_blank()
	XState.current = s
	var a := s.actor(174)
	var look := XAppearance.for_battler(a)
	for m in XAppearance.MOTIONS:
		for i in 3:
			var f := look.frame(m, i)
			check(m + str(i) + ".new_texture", str(f.tex.resource_path).ends_with("/u2/Yunshang_SV_u2.png"))
			check(m + str(i) + ".cell", f.rect.size == Vector2(64,64))
			var p := XAppearance.profile(f,m)
			check(m + str(i) + ".native_scale", is_equal_approx(p.scale,1.0))
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a,0.75)
	sp._process(0.0)
	check("body.native_scale", is_equal_approx(sp.body_scale,1.0))
	check("body.explicit_nearest", (sp.sprite as Sprite2D).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	check("body.integer_offset", sp.sprite.offset == sp.sprite.offset.round())
	check("book.new_texture", XActorBook.sprite_path(174).ends_with("/u2/Yunshang_SV_u2.png"))
	check("book.nearest", not XActorBook.native_smooth(174, XActorBook.sprite_spec(174)))
	sp.queue_free()
	check("walk.path", XDB.img_path("characters", "$Yunshang").ends_with("/u2/$Yunshang_u2.png"))
	check("face.path", XDB.img_path("faces", "Yunshang").ends_with("/Yunshang_Face_u1.png"))
	XYunshang.ART = false
	var old := XAppearance.for_battler(a).frame("wait",0)
	check("rollback.old_texture", str(old.tex.resource_path).contains("/sv/yunshang/"))
	check("rollback.old_scale", XAppearance.profile(old,"wait").scale < 1.0)
	XYunshang.ART = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out=") and DisplayServer.get_name() != "headless":
			await capture(arg.substr(6))
	print("TEST_RESULT="+JSON.stringify({"passed":total-failed,"total":total}))
	get_tree().quit(1 if failed else 0)
func capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	XMessageBox.auto = true
	var s := XState.new_game_blank()
	XState.current = s
	# Cached actor table already contains Gojo; fixture skips campaign/recruit gates.
	XGojo.ENABLED = false
	XGojo.unlock_override = 1
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [174,168,180]:
		s.actor(id).change_level_mv(55)
		# fixture bypasses recruitment gates; no real saves touched.
		s.actor(id).recover_all()
	s.party = [174,168,180]
	s.battle_slots = [174,168,180]
	var battle := XBattleScene.new()
	battle.setup(1,true,false,XDB.map(5))
	add_child(battle)
	for i in 90:await get_tree().process_frame
	var evidence := []
	for a in battle.sprites:
		if a is XActor:
			var sp: XBattlerSprite = battle.sprites[a]
			var body := sp.sprite as Sprite2D
			evidence.append({"actor":a.actor_id,"scale":sp.body_scale,"filter":body.texture_filter,"path":body.texture.resource_path})
	check("battle.three_actors", evidence.size() == 3)
	var file := FileAccess.open(dir.path_join("render_evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	file.close()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("battle_phone.png"))
	battle.queue_free()
