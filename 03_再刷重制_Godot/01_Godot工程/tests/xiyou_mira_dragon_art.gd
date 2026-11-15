extends Node
## 【cc·未经审查】米拉黑龙无剑 21 张＋头顶召剑层接入（content/mira/，开关 XMira.DRAGON_ART；XDB.img_path、XMiraSwordFx）：
## - path.*：黑龙 18 动作的每一帧都读 content/mira/img/sv_actors/sv/UserSV_MiraDragon/，不读同步出的带剑旧图；21 张文件齐。
## - art.*：每张 340×280、可见框在 [61,58,260,217] 内、脚底 217、alpha 只有 0／255；站姿归一档不变。
## - human.*：人形外观（Codex_Mira_SV_u2）不受 DRAGON_ART 影响。
## - fx.*：召剑层时间线（出现 3×100ms → 悬停 3×140ms 循环 → 消散 3＋clear ×100ms）、层中心＝脚底＋[-40,-200]×身体缩放、
##   SKILLS 默认只有 10151 黑日焚界（Kyo 11-15 定，D34）、别的技能不召、名单空时不召、名单里的技能号才召并在行动结束消散、人形或开关关时不召。
## - rollback.*：XMira.DRAGON_ART = false 回原版带剑图（同步出的 UserSV_MiraDragon），不建召剑层；人形开关 XMira.ART 另算。
## 窗口模式加 -- --out=<目录> 时另存黑龙待机／攻击 7 号／施法 10 号／召剑悬停合成与原版并排的截图。
var results := []
const OWN := "res://content/mira/img/sv_actors/sv/UserSV_MiraDragon/"
const FRAMES := {0: 4, 1: 1, 3: 1, 4: 1, 5: 1, 7: 4, 10: 4, 13: 1, 14: 1, 15: 1, 16: 1, 17: 1}
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	XAppearance.overrides = {}
	XMira.ART = true
	XMira.DRAGON_ART = true
	check("fx.default_only_10151", XMiraSwordFx.SKILLS == [10151], XMiraSwordFx.SKILLS)
	_paths()
	_art()
	_human()
	_fx_timeline()
	_fx_layer()
	_rollback()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await _capture_shots()
	XMira.ART = true
	XMira.DRAGON_ART = true
	XMiraSwordFx.SKILLS = [10151]
	XAppearance.overrides = null
	XState.current = null
	finish()


func _game() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	return s


func _mira(rank := 0, dragon := false) -> XActor:
	var s := _game()
	s.actor_advance[XMira.ACTOR] = rank
	var a := s.actor(XMira.ACTOR)
	a.change_level_mv(55)
	if dragon:
		a.learn_skill(10161)
		a.state_ids.append(XMira.DRAGON)
	return a


static func _path_of(look: XAppearance, m: String, i := 0) -> String:
	var tex = look.frame(m, i).get("tex")
	return str(tex.resource_path) if tex else ""


static func _bbox(tex: Texture2D) -> Array:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var l := 9999
	var top := 9999
	var r := -1
	var btm := -1
	var odd := 0
	for y in img.get_height():
		for x in img.get_width():
			var a8 := img.get_pixel(x, y).a8
			if a8 != 0 and a8 != 255:
				odd += 1
			if a8 > 0:
				l = mini(l, x)
				top = mini(top, y)
				r = maxi(r, x + 1)
				btm = maxi(btm, y + 1)
	return [l, top, r, btm, odd]


func _paths() -> void:
	var missing := []
	for m in FRAMES:
		for f in FRAMES[m]:
			var name := "UserSV_MiraDragon%d_%d" % [m, f]
			if XDB.img_path("sv_actors", "sv/UserSV_MiraDragon/" + name) != OWN + name + ".png":
				missing.append(name)
	check("path.21_files", missing.is_empty() and FRAMES.values().reduce(func(a, b): return a + b) == 21, missing)
	var a := _mira(3, true)
	check("path.key", XAppearance.battler_key(a) == "BlackDragon_Mira_SV|form:MiraDragon", XAppearance.battler_key(a))
	var look := XAppearance.for_battler(a)
	var bad := []
	for m in XAppearance.MOTIONS:
		for i in look.frame_count(m):
			var p := _path_of(look, m, i)
			if not p.begins_with(OWN):
				bad.append([m, i, p])
	check("path.all_motions_new", bad.is_empty(), bad)
	check("path.profile_same", XAppearance.profile_of("UserSV_MiraDragon") == [340, 280, 61, 58, 260, 217], XAppearance.profile_of("UserSV_MiraDragon"))


func _art() -> void:
	var bad := []
	for m in FRAMES:
		for f in FRAMES[m]:
			var t := load(OWN + "UserSV_MiraDragon%d_%d.png" % [m, f]) as Texture2D
			if t == null or t.get_size() != Vector2(340, 280):
				bad.append([m, f, "size"])
				continue
			var b := _bbox(t)
			if b[0] < 61 or b[1] < 58 or b[2] > 260 or b[3] != 217 or b[4] != 0:
				bad.append([m, f, b])
	check("art.340x280_box_foot217_binary_alpha", bad.is_empty(), bad)


func _human() -> void:
	var want := "res://content/mira/img/sv_actors/Codex_Mira_SV_u2.png"
	for on in [true, false]:
		XMira.DRAGON_ART = on
		var a := _mira(0, false)
		check("human.key_%s" % on, XAppearance.battler_key(a) == "BlackDragon_Mira_SV|form:MiraHuman_u2", XAppearance.battler_key(a))
		check("human.path_%s" % on, _path_of(XAppearance.for_battler(a), "wait") == want, _path_of(XAppearance.for_battler(a), "wait"))
		check("human.walk_%s" % on, XDB.img_path("characters", "$BlackDragon_Mira") == "res://content/mira/img/characters/$Codex_Mira_Walk_Final.png")
	XMira.DRAGON_ART = true


func _fx_timeline() -> void:
	var seq := [0, 99, 100, 250, 299].map(func(ms): return XMiraSwordFx.frame_name("appear", ms))
	seq.append_array([0, 139, 140, 280, 419, 420].map(func(ms): return XMiraSwordFx.frame_name("hover", ms)))
	check("fx.timeline_appear_hover", seq == ["appear_0", "appear_0", "appear_1", "appear_2", "appear_2", "hover_0", "hover_0", "hover_1", "hover_2", "hover_2", "hover_0"], seq)
	check("fx.timeline_disappear", [0, 100, 200, 300, 999].map(func(m): return XMiraSwordFx.frame_name("disappear", m)) == ["disappear_0", "disappear_1", "disappear_2", "clear", "clear"])
	var bad := []
	for n in XMiraSwordFx.APPEAR + XMiraSwordFx.HOVER + XMiraSwordFx.DISAPPEAR:
		var t := load(XMiraSwordFx.DIR + n + ".png") as Texture2D
		if t == null or t.get_size() != Vector2(128, 128):
			bad.append(n)
	check("fx.textures_128", bad.is_empty(), bad)
	check("fx.offset", XMiraSwordFx.OFFSET == Vector2(-40, -200) and XMiraSwordFx.center_for(0.5) == Vector2(-20, -100))


func _dragon_sprite() -> XBattlerSprite:
	var a := _mira(3, true)
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp._process(0.0)
	return sp


func _fx_layer() -> void:
	var sp := _dragon_sprite()
	XMiraSwordFx.SKILLS = [10151]
	check("fx.default_wants_only_10151", XMiraSwordFx.wants(10151) and not XMiraSwordFx.wants(10150) and not XMiraSwordFx.wants(10152))
	XMiraSwordFx.SKILLS = []
	XMiraSwordFx.on_skill(sp, 10151)
	check("fx.empty_list_no_layer", XMiraSwordFx.layer_of(sp) == null)
	XMiraSwordFx.SKILLS = [10151]
	XMiraSwordFx.on_skill(sp, 10150)
	check("fx.not_listed_no_layer", XMiraSwordFx.layer_of(sp) == null)
	XMiraSwordFx.on_skill(sp, 10151)
	var l := XMiraSwordFx.layer_of(sp)
	check("fx.listed_layer_appears", l != null and l.state == "appear" and l.get_parent() == sp, l)
	if l != null:
		var want := XMiraSwordFx.OFFSET * sp.body_scale
		check("fx.center_anchor", l.position.is_equal_approx(want) and l.scale.is_equal_approx(Vector2(sp.body_scale, sp.body_scale)), [l.position, want])
		# 中心＝底锚＋[-40,-200]：龙体可见底边中点（脚底原点）到 128×128 层中心
		check("fx.separate_from_body", sp.sprite.get_parent() == sp and l != sp.sprite and (sp.sprite as Sprite2D).texture != null)
		l.advance(300.0)
		check("fx.to_hover", l.state == "hover", l.state)
		l.advance(1000.0)
		check("fx.hover_stays", l.state == "hover")
		XMiraSwordFx.vanish_all([sp])
		check("fx.vanish_state", l.state == "disappear")
		l.advance(400.0)
		check("fx.hidden_after", l.state == "hidden" and not (l._spr as Sprite2D).visible, l.state)
	# 人形不召
	var h := _mira(0, false)
	var hs := XBattlerSprite.new()
	add_child(hs)
	hs.setup(h, 0.75)
	XMiraSwordFx.on_skill(hs, 10151)
	check("fx.human_no_layer", XMiraSwordFx.layer_of(hs) == null)
	hs.queue_free()
	sp.queue_free()
	XMiraSwordFx.SKILLS = [10151]


func _rollback() -> void:
	XMira.DRAGON_ART = false
	var a := _mira(3, true)
	var look := XAppearance.for_battler(a)
	var bad := []
	for m in XAppearance.MOTIONS:
		var p := _path_of(look, m, 0)
		if p.begins_with("res://content/mira/") or not p.contains("/UserSV_MiraDragon/"):
			bad.append([m, p])
	check("rollback.dragon_original", bad.is_empty(), bad)
	check("rollback.human_unchanged", XMira.ART and XDB.img_path("sv_actors", "Codex_Mira_SV_u2").begins_with("res://content/mira/"))
	XMiraSwordFx.SKILLS = [10151]
	var sp := _dragon_sprite()
	XMiraSwordFx.on_skill(sp, 10151)
	check("rollback.no_layer", XMiraSwordFx.layer_of(sp) == null and not XMiraSwordFx.wants(10151))
	sp.queue_free()
	XMiraSwordFx.SKILLS = [10151]
	XMira.DRAGON_ART = true
	check("rollback.on_again", _path_of(XAppearance.for_battler(_mira(3, true)), "wait").begins_with(OWN))


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## 并排截图：左＝原版（DRAGON_ART 关），右＝新图；motion 的第 frame 帧；fx＝右边加召剑悬停
func _shot(name: String, motion: String, frame: int, fx: bool) -> void:
	var root := Node2D.new()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.24, 0.3)
	bg.size = Vector2(960, 720)
	root.add_child(bg)
	var sps := []
	for i in 2:
		XMira.DRAGON_ART = i == 1
		var sp := _dragon_sprite()
		sp.reparent(root)
		sp.scale = Vector2(4, 4)
		sp.position = Vector2(240 + i * 480, 560)
		sp.set_motion(motion)
		sp._frame = frame
		sp._apply()
		sps.append(sp)
		var lab := Label.new()
		lab.text = ("新（无剑" + ("＋召剑悬停" if fx else "") + "）") if i == 1 else "原版（带剑）"
		lab.position = Vector2(60 + i * 480, 20)
		lab.add_theme_font_size_override("font_size", 28)
		root.add_child(lab)
	XMira.DRAGON_ART = true
	if fx:
		XMiraSwordFx.SKILLS = [10151]
		XMiraSwordFx.on_skill(sps[1], 10151)
		var l := XMiraSwordFx.layer_of(sps[1])
		l.advance(300.0)
		l.advance(10.0)
		XMiraSwordFx.SKILLS = [10151]
	for sp in sps:
		sp.set_process(false)
		sp.set_physics_process(false)
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	root.queue_free()
	await _frames(2)


func _capture_shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _shot("dragon_idle", "wait", 0, false)
	await _shot("dragon_attack7_frame2", "thrust", 2, false)
	await _shot("dragon_spell10_frame2", "spell", 2, false)
	await _shot("dragon_sword_hover", "wait", 0, true)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
