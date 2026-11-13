extends Node
## 【cc·未经审查】宿傩新美术接入（Kyo 2026-11-13 审过，content/sukuna/img/，开关 XSukuna.ART；XDB.img_path、XAppearance.profile_of）：
## - path.*：行走 $Codex_Sukuna_Walk、常态战斗 Codex_Sukuna_SV、完全体 52 张逐帧都读 content/sukuna/，不读同步出的旧图。
## - walk.*：行走图 144×192，四方向（行）× 三帧（列）每格 48×48 都有画面。
## - normal.* ／ full.*：进阶 2 时 18 种动作都取常态战斗图；进阶 3 时 18 种动作都取完全体逐帧（待机 1 张、其余 3 张），52 张都能读。
## - switch.*：进阶 3 ↔ 2 来回切，外观键与取图跟着换。
## - idle.*：两态待机那张实测可见高都是 58、脚底都在第 61 行，与归一档一致；两态缩放相同（72／58），站在同一脚底线上。
## - rollback.*：ART＝false 回到同步出的旧图与旧档。
var results := []
const OWN := "res://content/sukuna/img/"


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	XAppearance.overrides = {}
	XSukuna.ART = true
	_paths()
	_walk()
	_battle()
	_idle()
	_rollback()
	XSukuna.ART = true
	XAppearance.overrides = null
	XState.current = null
	finish()


func _game() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	return s


func _actor(rank: int) -> XActor:
	var s := _game()
	s.actor_advance[XSukuna.ACTOR] = rank
	var a := s.actor(XSukuna.ACTOR)
	a.change_level_mv(55)
	XSukuna.sync(a)
	return a


static func _path_of(look: XAppearance, m: String, i := 0) -> String:
	var tex = look.frame(m, i).get("tex")
	return str(tex.resource_path) if tex else ""


func _paths() -> void:
	check("path.walk", XDB.img_path("characters", "$Codex_Sukuna_Walk") == OWN + "characters/$Codex_Sukuna_Walk.png",
		XDB.img_path("characters", "$Codex_Sukuna_Walk"))
	check("path.sv", XDB.img_path("sv_actors", "Codex_Sukuna_SV") == OWN + "sv_actors/Codex_Sukuna_SV.png", XDB.img_path("sv_actors", "Codex_Sukuna_SV"))
	var ok := 0
	var bad := []
	for m in 18:
		for f in (1 if m == 1 else 3):
			var n := "Codex_Sukuna_QFull%d_%d" % [m, f]
			var p := XDB.img_path("sv_actors/sv/Codex_Sukuna_QFull", n)
			var t := load(p) as Texture2D if p.begins_with(OWN) else null
			if t != null and t.get_size() == Vector2(64, 64):
				ok += 1
			else:
				bad.append(n)
	check("path.full_52", ok == 52, bad)


func _walk() -> void:
	var t := load(XDB.img_path("characters", "$Codex_Sukuna_Walk")) as Texture2D
	check("walk.size", t != null and t.get_size() == Vector2(144, 192), t.get_size() if t else null)
	if t == null:
		return
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	var empty := []
	for row in 4:
		for col in 3:
			var any := false
			for y in 48:
				for x in 48:
					if img.get_pixel(col * 48 + x, row * 48 + y).a8 >= 12:
						any = true
						break
				if any:
					break
			if not any:
				empty.append([row, col])
	check("walk.4x3_frames", empty.is_empty(), empty)


func _battle() -> void:
	var a := _actor(2)
	check("normal.key", XAppearance.battler_key(a) == "Codex_Sukuna_SV", XAppearance.battler_key(a))
	var look := XAppearance.for_battler(a)
	var bad := []
	for m in XAppearance.MOTIONS:
		if _path_of(look, m) != OWN + "sv_actors/Codex_Sukuna_SV.png":
			bad.append([m, _path_of(look, m)])
	check("normal.motions", bad.is_empty(), bad)
	# 进阶 3：完全体
	XState.current.actor_advance[XSukuna.ACTOR] = 3
	XSukuna.sync(a)
	check("switch.to_full", XAppearance.battler_key(a) == "Codex_Sukuna_SV|st:2643", XAppearance.battler_key(a))
	look = XAppearance.for_battler(a)
	bad = []
	var seen := {}
	for m in XAppearance.MOTIONS:
		var n := look.frame_count(m)
		if n != (1 if m == "wait" else 3):
			bad.append([m, n])
		for i in n:
			var p := _path_of(look, m, i)
			if not p.begins_with(OWN + "sv_actors/sv/Codex_Sukuna_QFull/"):
				bad.append([m, i, p])
			seen[p] = true
	check("full.motions", bad.is_empty(), bad)
	check("full.frames_read", seen.size() == 52, seen.size())
	# 退回进阶 2：常态
	XState.current.actor_advance[XSukuna.ACTOR] = 2
	a.forget_skill(10245)
	check("switch.to_normal", XAppearance.battler_key(a) == "Codex_Sukuna_SV" and not a.state_ids.has(2643), XAppearance.battler_key(a))
	look = XAppearance.for_battler(a)
	check("switch.normal_image", _path_of(look, "wait") == OWN + "sv_actors/Codex_Sukuna_SV.png", _path_of(look, "wait"))


## 待机那张的不透明外接框（不透明度 ≥ 12，同 inferProfile）
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


func _idle_of(rank: int, tag: String) -> Dictionary:
	var a := _actor(rank)
	var look := XAppearance.for_battler(a)
	var f := look.frame("wait", 0)
	var box := _bbox(f.tex, f.get("rect", Rect2()))
	var prof := XAppearance.profile(f, "wait")
	check("idle.%s_height" % tag, box[3] - box[1] == 58, box)
	check("idle.%s_foot" % tag, box[3] == 61, box)
	check("idle.%s_profile" % tag, not prof.is_empty() and prof.bounds.size.y == 58.0 and prof.bounds.end.y == 61.0, prof)
	return prof


func _idle() -> void:
	var n := _idle_of(2, "normal")
	var q := _idle_of(3, "full")
	check("idle.same_scale", not n.is_empty() and not q.is_empty() and is_equal_approx(n.scale, q.scale) and is_equal_approx(n.scale, 72.0 / 58.0),
		[n.get("scale"), q.get("scale")])
	# 战斗精灵：两态的身体缩放一致
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(_actor(2), 0.75)
	var s_normal := sp.body_scale
	sp.queue_free()
	sp = XBattlerSprite.new()
	add_child(sp)
	sp.setup(_actor(3), 0.75)
	var s_full := sp.body_scale
	sp.queue_free()
	check("idle.sprite_scale", is_equal_approx(s_normal, s_full) and is_equal_approx(s_full, 72.0 / 58.0), [s_normal, s_full])


func _rollback() -> void:
	XSukuna.ART = false
	check("rollback.sv", not XDB.img_path("sv_actors", "Codex_Sukuna_SV").begins_with(OWN), XDB.img_path("sv_actors", "Codex_Sukuna_SV"))
	check("rollback.walk", not XDB.img_path("characters", "$Codex_Sukuna_Walk").begins_with(OWN), XDB.img_path("characters", "$Codex_Sukuna_Walk"))
	check("rollback.profile", XAppearance.profile_of("Codex_Sukuna_QFull") == [64, 64, 8, 6, 47, 62]
		and XAppearance.profile_of("Codex_Sukuna_SV") == [64, 64, 14, 5, 48, 63], XAppearance.profile_of("Codex_Sukuna_QFull"))
	XSukuna.ART = true
	check("rollback.on_again", XAppearance.profile_of("Codex_Sukuna_QFull") == [64, 64, 11, 3, 52, 61])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
