extends Node
## 【ag·未经审查】米拉人形新美术接入（content/mira/img/，开关 XMira.ART；XDB.img_path、XAppearance.sv_form／for_look／PROFILES、XActorBook.sprite_spec）：
## - path.*：行走 $BlackDragon_Mira／$Codex_Mira_Walk_Final、人形战斗 Codex_Mira_SV_u2／BlackDragon_Mira_SV 都读 content/mira/，不读同步出的旧图。
## - walk.*：行走图 144×192，四方向（行）× 三帧（列）每格 48×48 都有画面，可见高 47、脚底在第 47 行（0-based，与原版同高）。
## - human.*：人形战斗外观键为 BlackDragon_Mira_SV|form:MiraHuman_u2，18 种动作全部读 Codex_Mira_SV_u2.png（64×64 格）。
## - idle.*：定妆待机帧（wait 第 1 帧）可见高 58、脚底第 61 行，与归一档一致；缩放 72/58、最近邻（不平滑）。
## - dragon.*：黑龙形态（进阶 3、学 10161、带 2592）不受开关影响，仍走 UserSV_MiraDragon 多帧与旧归一档。
## - book.*：图鉴立绘开着走 Codex_Mira_SV_u2（单帧按档缩放），关掉回到 UserSV_MiraHuman1_0 多帧。
## - map.*：地图行走角色（MVCharacter）开着取 $Codex_Mira_Walk_Final.png，关掉回到 $BlackDragon_Mira.png。
## - rollback.*：XMira.ART = false 回到原版行走图、UserSV_MiraHuman 多帧战斗图与旧图鉴；重新打开恢复新图。
## 窗口模式加 -- --out=<目录> 时另存战斗待机、地图行走、图鉴的原始对比帧。
var results := []
const OWN := "res://content/mira/img/"
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
	_paths()
	_walk()
	_battle()
	_idle()
	_dragon()
	_book()
	_map_walk()
	_rollback()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await _capture_shots()
	XMira.ART = true
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


func _paths() -> void:
	var want_walk := OWN + "characters/$Codex_Mira_Walk_Final.png"
	var want_sv := OWN + "sv_actors/Codex_Mira_SV_u2.png"
	check("path.walk", XDB.img_path("characters", "$BlackDragon_Mira") == want_walk
		and XDB.img_path("characters", "$Codex_Mira_Walk_Final") == want_walk,
		XDB.img_path("characters", "$BlackDragon_Mira"))
	check("path.sv", XDB.img_path("sv_actors", "Codex_Mira_SV_u2") == want_sv
		and XDB.img_path("sv_actors", "BlackDragon_Mira_SV") == want_sv,
		[XDB.img_path("sv_actors", "Codex_Mira_SV_u2"), XDB.img_path("sv_actors", "BlackDragon_Mira_SV")])


func _walk() -> void:
	var t := load(XDB.img_path("characters", "$BlackDragon_Mira")) as Texture2D
	check("walk.size", t != null and t.get_size() == Vector2(144, 192), t.get_size() if t else null)
	if t == null:
		return
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	var empty := []
	var bad_foot := []
	var bad_height := []
	for row in 4:
		for col in 3:
			var box := _bbox(t, Rect2(col * 48, row * 48, 48, 48))
			if box[2] <= box[0]:
				empty.append([row, col])
			else:
				if box[3] != 48:
					bad_foot.append([row, col, box[1], box[3]])
				if box[3] - box[1] != 47:
					bad_height.append([row, col, box[1], box[3]])
	check("walk.4x3_frames", empty.is_empty(), empty)
	check("walk.foot_row_47", bad_foot.is_empty(), bad_foot)
	check("walk.height_47", bad_height.is_empty(), bad_height)


func _battle() -> void:
	var a := _mira(0, false)
	check("human.key", XAppearance.battler_key(a) == "BlackDragon_Mira_SV|form:MiraHuman_u2", XAppearance.battler_key(a))
	var look := XAppearance.for_battler(a)
	var bad := []
	for m in XAppearance.MOTIONS:
		var f := look.frame(m, 0)
		var r: Rect2 = f.get("rect", Rect2())
		if _path_of(look, m) != OWN + "sv_actors/Codex_Mira_SV_u2.png" or r.size != Vector2(64, 64):
			bad.append([m, _path_of(look, m), r])
	check("human.motions_64x64", bad.is_empty(), bad)


## 不透明外接框（不透明度 >= 12，同 inferProfile）
static func _bbox(tex: Texture2D, rect: Rect2) -> Array:
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


func _idle() -> void:
	var a := _mira(0, false)
	var look := XAppearance.for_battler(a)
	# 实机默认待机播放 walk；归一档仍沿用定妆 wait 的 58px 基准。
	var f := look.frame("walk", 1)
	var box := _bbox(f.tex, f.get("rect", Rect2()))
	var prof := XAppearance.profile(f, "walk")
	check("idle.walk_height_57", box[3] - box[1] == 57, box)
	check("idle.foot_61", box[3] == 61, box)
	check("idle.profile", not prof.is_empty() and prof.bounds.size.y == 58.0 and prof.bounds.end.y == 61.0, prof)
	for i in range(3):
		var walk := look.frame("walk", i)
		var walk_box := _bbox(walk.tex, walk.get("rect", Rect2()))
		check("idle.walk_foot_61_" + str(i), walk_box[3] == 61, walk_box)
	var middle := look.frame("walk", 1)
	var image := (middle.tex as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var rect: Rect2 = middle.get("rect", Rect2())
	check("idle.walk_boot_gap_clear", image.get_pixel(int(rect.position.x) + 26, int(rect.position.y) + 57).a8 == 0)

	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp._process(0.0)
	var body := sp.sprite as Sprite2D
	var filt := body.texture_filter
	if filt == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		filt = sp.texture_filter
	check("idle.sprite_scale", is_equal_approx(sp.body_scale, 72.0 / 58.0), sp.body_scale)
	check("idle.nearest", filt == CanvasItem.TEXTURE_FILTER_NEAREST, filt)
	sp.queue_free()


func _dragon() -> void:
	var a := _mira(3, true)
	check("dragon.key", XAppearance.battler_key(a) == "BlackDragon_Mira_SV|form:MiraDragon", XAppearance.battler_key(a))
	var look := XAppearance.for_battler(a)
	var bad := []
	for m in XAppearance.MOTIONS:
		var p := _path_of(look, m)
		if not p.contains("/UserSV_MiraDragon/"):
			bad.append([m, p])
	check("dragon.motions_unchanged", bad.is_empty(), bad)
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp._process(0.0)
	check("dragon.height_72", absf(sp.height() - 72.0) < 1.5 and (sp.weapon == null or not sp.weapon.visible), sp.height())
	sp.queue_free()


func _book() -> void:
	XMira.ART = true
	var sp_new := XActorBook.sprite_spec(XMira.ACTOR)
	check("book.new", str(sp_new.get("path", "")) == OWN + "sv_actors/Codex_Mira_SV_u2.png"
		and str(sp_new.get("key", "")) == "Codex_Mira_SV_u2" and not bool(sp_new.get("multi", true)), sp_new)
	XMira.ART = false
	var sp_old := XActorBook.sprite_spec(XMira.ACTOR)
	check("book.old", str(sp_old.get("key", "")) == "UserSV_MiraHuman" and bool(sp_old.get("multi", false)), sp_old)
	XMira.ART = true


func _map_walk() -> void:
	var ch := MVCharacter.new()
	add_child(ch)
	XMira.ART = true
	ch.set_image("$BlackDragon_Mira", 0)
	var p_new := str(ch._tex.resource_path) if ch._tex else ""
	check("map.walk_new", p_new == OWN + "characters/$Codex_Mira_Walk_Final.png", p_new)
	XMira.ART = false
	ch.set_image("$BlackDragon_Mira", 0)
	var p_old := str(ch._tex.resource_path) if ch._tex else ""
	check("map.walk_old", p_old.ends_with("/characters/$BlackDragon_Mira.png"), p_old)
	ch.queue_free()
	XMira.ART = true


func _rollback() -> void:
	XMira.ART = false
	var a := _mira(0, false)
	check("rollback.walk", not XDB.img_path("characters", "$BlackDragon_Mira").begins_with(OWN), XDB.img_path("characters", "$BlackDragon_Mira"))
	check("rollback.sv", not XDB.img_path("sv_actors", "BlackDragon_Mira_SV").begins_with(OWN), XDB.img_path("sv_actors", "BlackDragon_Mira_SV"))
	check("rollback.key", XAppearance.battler_key(a) == "BlackDragon_Mira_SV|form:MiraHuman", XAppearance.battler_key(a))
	var look := XAppearance.for_battler(a)
	check("rollback.human_multi", _path_of(look, "wait").contains("/UserSV_MiraHuman/"), _path_of(look, "wait"))
	var d := _mira(3, true)
	check("rollback.dragon_still_works", XAppearance.battler_key(d) == "BlackDragon_Mira_SV|form:MiraDragon"
		and _path_of(XAppearance.for_battler(d), "wait").contains("/UserSV_MiraDragon/"))
	XMira.ART = true
	var a2 := _mira(0, false)
	check("rollback.on_again", XAppearance.battler_key(a2) == "BlackDragon_Mira_SV|form:MiraHuman_u2"
		and _path_of(XAppearance.for_battler(a2), "wait") == OWN + "sv_actors/Codex_Mira_SV_u2.png")


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _save_shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _capture_shots() -> void:
	XMessageBox.auto = true
	for art_on in [false, true]:
		var tag := "new" if art_on else "old"
		XMira.ART = art_on
		# 1) 战斗待机（人形）
		var s := XState.new_game_blank()
		XState.current = s
		s.actor_max_level = 99
		s.switches[2494] = true
		s.party.clear()
		s.battle_slots.clear()
		s.actor(XMira.ACTOR).change_level_mv(55)
		s.add_actor(XMira.ACTOR)
		s.actor(XMira.ACTOR).recover_all()
		var battle := XBattleScene.new()
		battle.setup(1, true, false, XDB.map(5))
		add_child(battle)
		await _frames(90)
		await _save_shot("battle_" + tag)
		battle.queue_free()
		await _frames(2)

		# 2) 地图行走（真实地图格 + MVCharacter）
		var map := XMapScene.new()
		XState.current = _game()
		XState.current.party = [XMira.ACTOR]
		XState.current.battle_slots = [XMira.ACTOR]
		XState.current.map_id = 4
		XState.current.x = 12
		XState.current.y = 12
		add_child(map)
		await _frames(15)
		await _save_shot("map_" + tag)
		map.queue_free()
		await _frames(2)

		# 3) 人物图鉴
		var book := XActorBook.new()
		XState.current = _game()
		add_child(book)
		await _frames(3)
		book.select(XActorBook.index_ids().find(XMira.ACTOR))
		await _save_shot("book_" + tag)
		book.queue_free()
		await _frames(2)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
