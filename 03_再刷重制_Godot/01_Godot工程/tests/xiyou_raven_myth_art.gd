extends Node
## 【ag·未经审查】渡鸦神话形态新美术接入（content/raven/img/sv_actors/sv/UserSV_RavenMythic/，开关 XRaven.ART；XDB.img_path、XAppearance.PROFILES／profile_of）：
## - path.*：20 张 UserSV_RavenMythic 逐帧图都从 content/raven/ 读取，不读同步出的原版图，且尺寸 340×280、二值透明、可见框在 [61,58,259,217] 内、脚底 217。
## - myth.*：渡鸦神话形态外观键为 Raven_Mythic_SV|form:RavenMythic，18 种动作按原版 Cfdz/SVzs 映射取齐 20 张新图、藏影子、速度 10。
## - idle.*：0_0 站姿帧可见框 [66,58,255,217]（高 159、脚底 217），缩放 72/159 与黑龙 UserSV_MiraDragon 对齐，浮空与藏武器保持原样。
## - normal.*：普通形态 Raven_Normal_SV 不受影响。
## - rollback.*：XRaven.ART = false 回到同步出的原版 UserSV_RavenMythic（380×280）与旧归一档 [380,280,84,55,268,211]；重新打开恢复新图。
## 窗口模式加 -- --out=<目录> 时另存战斗神话形态待机、攻击的原始对比帧。
var results := []
const OWN := "res://content/raven/img/sv_actors/sv/UserSV_RavenMythic/"
const EXPECTED := {
	"walk": [0, 4], "wait": [0, 4], "chant": [0, 4], "guard": [3, 1], "damage": [4, 1], "evade": [5, 1],
	"thrust": [7, 4], "swing": [7, 4], "missile": [7, 4], "skill": [10, 4], "spell": [10, 4], "item": [10, 4],
	"escape": [0, 4], "victory": [13, 1], "dying": [14, 1], "abnormal": [15, 1], "sleep": [16, 1], "dead": [17, 1],
}
var out_dir := ""
## 临时预览，合并前可去掉：仅测试截图用的渡鸦神话与米拉黑龙战斗图临时缩放倍数（默认 1.0，不影响正式游戏逻辑）
static var PREVIEW_MYTH_SCALE := 1.0
var size_out_dir := ""


func _ready() -> void:
	var env_scale := OS.get_environment("XIYOU_PREVIEW_SCALE").strip_edges()
	if env_scale != "" and env_scale.is_valid_float():
		PREVIEW_MYTH_SCALE = float(env_scale)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--size-out="):
			size_out_dir = arg.substr(11)
		elif arg.begins_with("--preview-scale="):
			PREVIEW_MYTH_SCALE = float(arg.substr(16))
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	XAppearance.overrides = {}
	XRaven.ART = true
	_paths_and_frames()
	_myth_battle()
	_idle_and_scale()
	_normal_unchanged()
	_rollback()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await _capture_shots()
	if size_out_dir != "" and DisplayServer.get_name() != "headless":
		await _capture_size_preview()
	XRaven.ART = true
	XAppearance.overrides = null
	XState.current = null
	finish()


func _game() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	return s


func _raven_myth() -> XActor:
	var s := _game()
	s.actor_advance[XRaven.ACTOR] = 5
	var a := s.actor(XRaven.ACTOR)
	a.change_level_mv(60)
	s.raven["myth"] = 3
	return a


static func _path_of(look: XAppearance, m: String, i := 0) -> String:
	var tex = look.frame(m, i).get("tex")
	return str(tex.resource_path) if tex else ""


## 不透明外接框（不透明度 >= 12，同 inferProfile）
static func _bbox(tex: Texture2D, rect := Rect2()) -> Array:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	if not rect.has_area():
		rect = Rect2(Vector2.ZERO, tex.get_size())
	var l := 9999
	var top := 9999
	var r := -1
	var btm := -1
	for y in int(rect.size.y):
		for x in int(rect.size.x):
			if img.get_pixel(int(rect.position.x) + x, int(rect.position.y) + y).a8 >= 12:
				l = mini(l, x)
				top = mini(top, y)
				r = maxi(r, x + 1)
				btm = maxi(btm, y + 1)
	return [l, top, r, btm]


static func _has_only_binary_alpha(tex: Texture2D) -> bool:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a8
			if a != 0 and a != 255:
				return false
	return true


func _paths_and_frames() -> void:
	var stems := {}
	for m in EXPECTED:
		var src: int = EXPECTED[m][0]
		var cnt: int = EXPECTED[m][1]
		for f in cnt:
			stems["UserSV_RavenMythic%d_%d" % [src, f]] = true
	check("path.count_20", stems.size() == 20, stems.size())
	var bad_path := []
	var bad_size := []
	var bad_box := []
	var bad_alpha := []
	for stem in stems:
		var p := XDB.img_path("sv_actors/sv/UserSV_RavenMythic", stem)
		if p != OWN + stem + ".png":
			bad_path.append([stem, p])
			continue
		var t := load(p) as Texture2D
		if t == null or t.get_size() != Vector2(340, 280):
			bad_size.append([stem, t.get_size() if t else null])
			continue
		var box := _bbox(t)
		if box[0] < 61 or box[1] < 58 or box[2] > 259 or box[3] != 217:
			bad_box.append([stem, box])
		if not _has_only_binary_alpha(t):
			bad_alpha.append(stem)
	check("path.all_20_from_content", bad_path.is_empty(), bad_path)
	check("frame.size_340x280", bad_size.is_empty(), bad_size)
	check("frame.bbox_and_foot_217", bad_box.is_empty(), bad_box)
	check("frame.binary_alpha", bad_alpha.is_empty(), bad_alpha)


func _myth_battle() -> void:
	var a := _raven_myth()
	check("myth.key", XAppearance.battler_key(a) == "Raven_Mythic_SV|form:RavenMythic", XAppearance.battler_key(a))
	var look := XAppearance.for_battler(a)
	var bad := []
	var seen := {}
	for m in XAppearance.MOTIONS:
		var spec: Array = EXPECTED[m]
		var want_src: int = spec[0]
		var want_cnt: int = spec[1]
		if look.frame_count(m) != want_cnt:
			bad.append([m, "count", look.frame_count(m), want_cnt])
			continue
		for i in want_cnt:
			var p := _path_of(look, m, i)
			var want_p := "%sUserSV_RavenMythic%d_%d.png" % [OWN, want_src, i]
			if p != want_p:
				bad.append([m, i, p, want_p])
			seen[p] = true
	check("myth.motions_18", bad.is_empty(), bad)
	check("myth.unique_20_frames", seen.size() == 20, seen.size())
	check("myth.shadow_speed", look.hide_shadow and look.wait_of("walk") == 10, [look.hide_shadow, look.wait_of("walk")])


func _idle_and_scale() -> void:
	var a := _raven_myth()
	var look := XAppearance.for_battler(a)
	var f := look.frame("wait", 0)
	var box := _bbox(f.tex, f.get("rect", Rect2()))
	var prof := XAppearance.profile(f, "wait")
	var dragon_prof: Array = XAppearance.profile_of("UserSV_MiraDragon")
	var dragon_scale := minf(XAppearance.PROFILE_H / float(dragon_prof[5] - dragon_prof[3]),
		XAppearance.PROFILE_W / float(dragon_prof[4] - dragon_prof[2]))
	check("idle.box_0_0", box == [66, 58, 255, 217], box)
	check("idle.height_159_foot_217", box[3] - box[1] == 159 and box[3] == 217, box)
	check("idle.profile_matches_dragon", not prof.is_empty() and prof.size == Vector2(340, 280)
		and prof.bounds == Rect2(66, 58, 189, 159) and prof.bounds.end.y == float(dragon_prof[5])
		and is_equal_approx(prof.scale, dragon_scale) and is_equal_approx(prof.scale, 72.0 / 159.0), prof)
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp._process(0.0)
	check("idle.sprite_scale_same_as_dragon", is_equal_approx(sp.body_scale, dragon_scale), [sp.body_scale, dragon_scale])
	check("idle.no_shadow_no_weapon", sp.shadow == null and (sp.weapon == null or not sp.weapon.visible))
	check("idle.float_px", sp._float_px <= -12.5 and sp._float_px >= -15.5, sp._float_px)
	sp.queue_free()


func _normal_unchanged() -> void:
	var s := _game()
	var a := s.actor(XRaven.ACTOR)
	check("normal.key", XAppearance.battler_key(a) == "Raven_Normal_SV", XAppearance.battler_key(a))
	var look := XAppearance.for_battler(a)
	var p := _path_of(look, "wait")
	check("normal.not_content", not p.begins_with(OWN) and p.ends_with("/sv_actors/Raven_Normal_SV.png"), p)


func _rollback() -> void:
	XRaven.ART = false
	var a := _raven_myth()
	var old_p := XDB.img_path("sv_actors/sv/UserSV_RavenMythic", "UserSV_RavenMythic0_0")
	check("rollback.path", not old_p.begins_with(OWN) and old_p.ends_with("/sv_actors/sv/UserSV_RavenMythic/UserSV_RavenMythic0_0.png"), old_p)
	check("rollback.profile", XAppearance.profile_of("UserSV_RavenMythic") == [380, 280, 84, 55, 268, 211],
		XAppearance.profile_of("UserSV_RavenMythic"))
	var look := XAppearance.for_battler(a)
	var f := look.frame("wait", 0)
	var tex := f.get("tex") as Texture2D
	check("rollback.old_380x280", tex != null and not str(tex.resource_path).begins_with(OWN) and tex.get_size() == Vector2(380, 280),
		[str(tex.resource_path) if tex else "", tex.get_size() if tex else null])
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp._process(0.0)
	check("rollback.old_scale", is_equal_approx(sp.body_scale, 72.0 / 156.0), sp.body_scale)
	sp.queue_free()
	XRaven.ART = true
	var a2 := _raven_myth()
	check("rollback.on_again", XAppearance.profile_of("UserSV_RavenMythic") == [340, 280, 66, 58, 255, 217]
		and _path_of(XAppearance.for_battler(a2), "wait") == OWN + "UserSV_RavenMythic0_0.png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save_shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _capture_shots() -> void:
	XMessageBox.auto = true
	for art_on in [false, true]:
		var tag := "new" if art_on else "old"
		XRaven.ART = art_on
		var s := XState.new_game_blank()
		XState.current = s
		s.actor_max_level = 99
		s.switches[2494] = true
		s.party.clear()
		s.battle_slots.clear()
		s.actor_advance[XRaven.ACTOR] = 5
		XRaven.recruit(s)
		var raven := s.actor(XRaven.ACTOR)
		raven.change_level_mv(60)
		raven.recover_all()
		s.raven["myth"] = 3
		var battle := XBattleScene.new()
		battle.setup(1, true, false, XDB.map(5))
		add_child(battle)
		await _frames(90)
		if battle.cmd_win != null:
			battle.cmd_win.visible = false
		var sp: XBattlerSprite = battle.sprites.get(raven)
		if sp != null:
			sp.seq_driven = true
			sp.set_motion("wait")
			sp._frame = 0
			sp._apply()
		await _save_shot("battle_idle_" + tag)
		if sp != null:
			sp.set_motion("swing")
			sp._frame = 1
			sp._apply()
		await _save_shot("battle_attack_" + tag)
		battle.queue_free()
		await _frames(2)
	_stitch_compare()


func _stitch_compare() -> void:
	# 按截图实际分辨率裁出渡鸦站位周边（左旧右新、上待机下攻击），另存待机、攻击与 2×2 总览对照图
	var idle_old := Image.load_from_file(out_dir.path_join("battle_idle_old.png"))
	var idle_new := Image.load_from_file(out_dir.path_join("battle_idle_new.png"))
	var atk_old := Image.load_from_file(out_dir.path_join("battle_attack_old.png"))
	var atk_new := Image.load_from_file(out_dir.path_join("battle_attack_new.png"))
	if idle_old == null or idle_new == null or atk_old == null or atk_new == null:
		return
	var sz := idle_old.get_size()
	var crop := Rect2i(roundi(sz.x * 0.54), roundi(sz.y * 0.34), roundi(sz.x * 0.20), roundi(sz.y * 0.24))
	var idle_cmp := Image.create(crop.size.x * 2, crop.size.y, false, Image.FORMAT_RGBA8)
	idle_cmp.blit_rect(idle_old, crop, Vector2i(0, 0))
	idle_cmp.blit_rect(idle_new, crop, Vector2i(crop.size.x, 0))
	idle_cmp.save_png(out_dir.path_join("battle_idle_compare.png"))
	var atk_cmp := Image.create(crop.size.x * 2, crop.size.y, false, Image.FORMAT_RGBA8)
	atk_cmp.blit_rect(atk_old, crop, Vector2i(0, 0))
	atk_cmp.blit_rect(atk_new, crop, Vector2i(crop.size.x, 0))
	atk_cmp.save_png(out_dir.path_join("battle_attack_compare.png"))
	var both := Image.create(crop.size.x * 2, crop.size.y * 2, false, Image.FORMAT_RGBA8)
	both.blit_rect(idle_cmp, Rect2i(0, 0, crop.size.x * 2, crop.size.y), Vector2i(0, 0))
	both.blit_rect(atk_cmp, Rect2i(0, 0, crop.size.x * 2, crop.size.y), Vector2i(0, crop.size.y))
	both.save_png(out_dir.path_join("battle_myth_compare.png"))


## 临时预览，合并前可去掉：在真实 4 人队＋BOSS 战里按 4 个倍数截取渡鸦神话与米拉黑龙实际战斗画面，并拼出 2×2 总览图
func _capture_size_preview() -> void:
	XMessageBox.auto = true
	XRaven.ART = true
	var prev_gojo_unlock := XGojo.unlock_override
	XGojo.unlock_override = 1
	var s := XState.new_game_blank()
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()

	s.actor_advance[XRaven.ACTOR] = 5
	s.actor_advance[XMira.ACTOR] = 3
	var lineup: Array[int] = [XRaven.ACTOR, XGojo.ACTOR, XMira.ACTOR, XSukuna.ACTOR]
	for id in lineup:
		var act := s.actor(id)
		act.change_level_mv(60)
		act.recover_all()
	s.actor(XMira.ACTOR).learn_skill(10161)
	s.party.assign(lineup)
	s.battle_slots.assign(lineup)

	var battle := XBattleScene.new()
	battle.force_auto = false
	battle.setup(693, true, false, XDB.map(5))
	s.raven["myth"] = 3
	var mira := s.actor(XMira.ACTOR)
	if not mira.state_ids.has(XMira.DRAGON):
		mira.state_ids.append(XMira.DRAGON)
	add_child(battle)
	await _frames(105)

	var raven := s.actor(XRaven.ACTOR)
	var gojo := s.actor(XGojo.ACTOR)
	var sukuna := s.actor(XSukuna.ACTOR)
	var sp_raven: XBattlerSprite = battle.sprites.get(raven)
	var sp_mira: XBattlerSprite = battle.sprites.get(mira)
	var party_sprites := [battle.sprites.get(raven), battle.sprites.get(gojo), battle.sprites.get(mira), battle.sprites.get(sukuna)]
	for sp in party_sprites:
		if sp != null:
			(sp as XBattlerSprite).position = (sp as XBattlerSprite).home
			(sp as XBattlerSprite).seq_driven = true
			(sp as XBattlerSprite).set_motion("wait")
			(sp as XBattlerSprite)._frame = 0
			(sp as XBattlerSprite)._apply()

	var prev_scale := PREVIEW_MYTH_SCALE
	var entries := [
		{"scale": 1.0, "tag": "1.0", "label": "×1.0"},
		{"scale": 1.2, "tag": "1.2", "label": "×1.2"},
		{"scale": 1.35, "tag": "1.35", "label": "×1.35"},
		{"scale": 1.5, "tag": "1.5", "label": "×1.5"},
	]
	for item in entries:
		PREVIEW_MYTH_SCALE = float(item.scale)
		for sp in [sp_raven, sp_mira]:
			if sp != null:
				sp.look.scale = PREVIEW_MYTH_SCALE
				sp._apply()
		for _f in 4:
			if battle.cmd_win != null:
				battle.cmd_win.visible = false
			for sp in party_sprites:
				if sp != null:
					(sp as XBattlerSprite).position = (sp as XBattlerSprite).home
			await get_tree().process_frame
		if battle.cmd_win != null:
			battle.cmd_win.visible = false
		for sp in party_sprites:
			if sp != null:
				(sp as XBattlerSprite).position = (sp as XBattlerSprite).home
		await RenderingServer.frame_post_draw
		print("SIZE_PREVIEW scale=%s actors=%d raven=%s(%.3f) mira=%s(%.3f)" % [
			item.tag,
			battle.logic.actors.size(),
			sp_raven._look_key if sp_raven != null else "null",
			sp_raven.body_scale if sp_raven != null else 0.0,
			sp_mira._look_key if sp_mira != null else "null",
			sp_mira.body_scale if sp_mira != null else 0.0,
		])
		get_viewport().get_texture().get_image().save_png(size_out_dir.path_join("battle_scale_%s.png" % item.tag))

	PREVIEW_MYTH_SCALE = prev_scale
	XGojo.unlock_override = prev_gojo_unlock
	battle.queue_free()
	await _frames(2)
	await _stitch_size_overview(entries)


func _stitch_size_overview(entries: Array) -> void:
	var imgs: Array[Image] = []
	for item in entries:
		var img := Image.load_from_file(size_out_dir.path_join("battle_scale_%s.png" % item.tag))
		if img == null:
			return
		imgs.append(img)
	var cell := Vector2i(1280, 720)
	var vp := SubViewport.new()
	vp.size = Vector2i(cell.x * 2, cell.y * 2)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)

	for i in range(4):
		var col := i % 2
		var row := i / 2
		var origin := Vector2(col * cell.x, row * cell.y)
		var resized := imgs[i].duplicate() as Image
		resized.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		var tex := ImageTexture.create_from_image(resized)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.position = origin
		tr.size = Vector2(cell)
		vp.add_child(tr)

		var badge := ColorRect.new()
		badge.position = origin + Vector2(16, 16)
		badge.size = Vector2(138, 52)
		badge.color = Color(0.05, 0.06, 0.10, 0.86)
		vp.add_child(badge)

		var lbl := Label.new()
		lbl.position = origin + Vector2(26, 20)
		lbl.size = Vector2(120, 44)
		lbl.text = entries[i].label
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.45, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl.add_theme_constant_override("outline_size", 4)
		vp.add_child(lbl)

	await _frames(3)
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(size_out_dir.path_join("battle_scale_overview_2x2.png"))
	vp.queue_free()
	await _frames(1)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
