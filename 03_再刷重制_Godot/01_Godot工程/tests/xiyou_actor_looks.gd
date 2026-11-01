extends Node
## 【cc·悟空·未经审查】专属角色的战斗外观（原版 Mx_SuperSV 状态换图、Codex_MiraRavenMultiFrame、installNativeSukunaRuntime／
## installNativeGarouRuntime／Codex_Raven 的外观部分；重制 XAppearance.battler_key／for_look／profile、XSukuna.full_look、XGarou 星空外观）：
## - sukuna.*：进阶 3 时取外观键就把 2643 塞进状态（不记回合），键带 |st:2643，18 种动作都是 Codex_Sukuna_QFull、速度照角色（没写＝0）；
##   退回进阶 2 去掉 2643；多帧时藏武器。
## - garou.*：形态 0 的状态 2644 → Codex_Garou_QHuman（角色 <SVspeed:12>）；形态 6 → 2650 Codex_Garou_QCosmic，战斗图与头像换 Garou_Cosmic。
## - raven.*：平时 Raven_Normal_SV；神话中 Raven_Mythic_SV＋|form:RavenMythic，UserSV_RavenMythic（待机借 0 号 4 帧、受伤 4 号 1 帧）、藏影子、速度 10。
## - mira.*：平时 UserSV_MiraHuman（待机 1 号自己 1 帧）；进阶 3、学了 10161、带 2592 → UserSV_MiraDragon。
## - cat.*：小猫剑圣 CatSwordSaint_v3（1 号 1 帧、别的 3 帧、速度 12）。
## - card.*：开着换装卡时键只有 |card，不按状态换图。
## - order.*：带 <sv:> 的状态按传入次序（键里 ID 从大到小），某动作缺图就退到下一个。
## - profile.*：渡鸦侧视图缩放 min(72/60, 129/51)=1.2、可见底边中点落在脚底；ID < 167 照旧 0.75；没有档的照 inferProfile 量。
## 逐帧图要在切片里（xiyou_slice.json extraSvFolders 与状态备注的 <sv:>），同步后才有。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	XAppearance.overrides = {}
	_sukuna()
	_garou()
	_raven()
	_mira()
	_cat()
	_order()
	_profile()
	XAppearance.overrides = null
	XState.current = null
	finish()


func _game() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	return s


## 某动作第 i 帧的图名（文件夹名或侧视图名）
static func _src(look: XAppearance, m: String, i := 0) -> String:
	var f := look.frame(m, i)
	var tex = f.get("tex")
	return str(tex.resource_path).get_file().get_basename() if tex else ""


func _all_from(look: XAppearance, folder: String) -> bool:
	for m in XAppearance.MOTIONS:
		if not _src(look, m).begins_with(folder):
			return false
	return true


func _sukuna() -> void:
	var s := _game()
	s.actor_advance[XSukuna.ACTOR] = 3
	var a := s.actor(XSukuna.ACTOR)
	a.change_level_mv(55)
	XSukuna.sync(a)
	check("sukuna.stage", XSukuna.stage(a) == 3, XSukuna.stage(a))
	var key := XAppearance.battler_key(a)
	check("sukuna.state", a.state_ids.has(2643) and not a.state_turns.has(2643), a.state_ids)
	check("sukuna.key", key == "Codex_Sukuna_SV|st:2643", key)
	var look := XAppearance.for_battler(a)
	check("sukuna.frames", _all_from(look, "Codex_Sukuna_QFull") and look.frame_count("swing") == 3 and look.frame_count("wait") == 1,
		[_src(look, "walk"), _src(look, "wait"), look.frame_count("swing")])
	check("sukuna.speed", look.wait_of("walk") == 0, look.wait_of("walk"))
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp.start_weapon(1)
	check("sukuna.weapon_hidden", sp.weapon != null and not sp.weapon.visible)
	# QFull 档 [64, 64, 8, 6, 47, 62]：缩放 min(72/56, 129/39)
	check("sukuna.scale", is_equal_approx(sp.body_scale, 72.0 / 56.0), sp.body_scale)
	sp.queue_free()
	s.actor_advance[XSukuna.ACTOR] = 2
	a.forget_skill(10245)
	XAppearance.battler_key(a)
	check("sukuna.erase", XSukuna.stage(a) < 3 and not a.state_ids.has(2643), [XSukuna.stage(a), a.state_ids])


func _garou() -> void:
	var s := _game()
	var a := s.actor(XGarou.ACTOR)
	check("garou.human_state", a.state_ids.has(2644), a.state_ids)
	var look := XAppearance.for_battler(a)
	check("garou.human_key", XAppearance.battler_key(a) == "Garou_Human|st:2644", XAppearance.battler_key(a))
	check("garou.human_frames", _all_from(look, "Codex_Garou_QHuman") and look.wait_of("walk") == 12, [_src(look, "walk"), look.wait_of("walk")])
	s.actor_advance[XGarou.ACTOR] = 6
	a.change_level_mv(60)
	XGarou.sync(a)
	check("garou.cosmic_state", a.state_ids.has(2650) and not a.state_ids.has(2644), a.state_ids)
	check("garou.cosmic_images", a.data().battlerName == "Garou_Cosmic" and a.data().faceName == "Garou_Cosmic" and int(a.data().faceIndex) == 0,
		[a.data().battlerName, a.data().faceName])
	look = XAppearance.for_battler(a)
	check("garou.cosmic_frames", _all_from(look, "Codex_Garou_QCosmic"), _src(look, "walk"))
	s.actor_advance[XGarou.ACTOR] = 5
	XGarou.sync(a)
	check("garou.back_human", a.data().battlerName == "Garou_Human" and a.data().faceName == "Garou_Human", a.data().battlerName)


func _raven() -> void:
	var s := _game()
	var a := s.actor(XRaven.ACTOR)
	check("raven.normal", XAppearance.battler_key(a) == "Raven_Normal_SV", XAppearance.battler_key(a))
	s.raven["myth"] = 3
	var key := XAppearance.battler_key(a)
	check("raven.myth_key", key == "Raven_Mythic_SV|form:RavenMythic", key)
	check("raven.menu_name", XCostumes.battler_name(s, a, false) == "Raven_Normal_SV")
	var look := XAppearance.for_battler(a)
	check("raven.myth_frames", _all_from(look, "UserSV_RavenMythic") and _src(look, "wait") == "UserSV_RavenMythic0_0"
		and look.frame_count("wait") == 4 and _src(look, "damage") == "UserSV_RavenMythic4_0" and _src(look, "thrust", 3) == "UserSV_RavenMythic7_3",
		[_src(look, "wait"), _src(look, "damage"), _src(look, "thrust", 3)])
	check("raven.myth_shadow_speed", look.hide_shadow and look.wait_of("walk") == 10)
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp._process(0.0)
	check("raven.float", sp._float_px <= -12.5 and sp._float_px >= -15.5 and sp.height() > 72.0, [sp._float_px, sp.height()])
	sp.queue_free()
	s.raven["myth"] = 0


func _mira() -> void:
	var s := _game()
	var a := s.actor(XMira.ACTOR)
	var look := XAppearance.for_battler(a)
	check("mira.human", XAppearance.battler_key(a) == "BlackDragon_Mira_SV|form:MiraHuman" and _all_from(look, "UserSV_MiraHuman")
		and _src(look, "wait") == "UserSV_MiraHuman1_0" and _src(look, "walk") == "UserSV_MiraHuman0_0", [XAppearance.battler_key(a), _src(look, "wait")])
	s.actor_advance[XMira.ACTOR] = 3
	a.learn_skill(10161)
	a.state_ids.append(XMira.DRAGON)
	look = XAppearance.for_battler(a)
	check("mira.dragon", XAppearance.battler_key(a) == "BlackDragon_Mira_SV|form:MiraDragon" and _all_from(look, "UserSV_MiraDragon"), XAppearance.battler_key(a))
	# 开着换装卡：卡图那层在最外面，不变身、不按状态换图
	var card: Dictionary = XCostumes.registry().values()[0]
	a.learn_skill(int(card.skill))
	a.state_ids.append(int(card.state))
	check("card.key", XAppearance.battler_key(a) == str(card.image) + "|card", XAppearance.battler_key(a))


func _cat() -> void:
	var s := _game()
	var a := s.actor(178)
	var look := XAppearance.for_battler(a)
	check("cat.frames", _all_from(look, "CatSwordSaint_v3") and look.frame_count("wait") == 1 and look.frame_count("swing") == 3 and look.wait_of("swing") == 12,
		[_src(look, "walk"), look.frame_count("wait")])


func _order() -> void:
	var cosmic: Dictionary = XDB.rec("States", 2650).meta
	var full: Dictionary = XDB.rec("States", 2643).meta
	var a := XAppearance.for_image("sv_actors/Codex_Sukuna_SV", {}, [cosmic, full])
	check("order.first", _all_from(a, "Codex_Garou_QCosmic"), _src(a, "walk"))
	var missing := {"sv": "不存在", "SVzs0": "3"}
	var b := XAppearance.for_image("sv_actors/Codex_Sukuna_SV", {}, [missing, full])
	check("order.fallback", _src(b, "walk") == "Codex_Sukuna_QFull0_0", _src(b, "walk"))
	var c := XAppearance.for_image("sv_actors/Codex_Sukuna_SV", {}, [missing])
	check("order.sheet", _src(c, "walk") == "Codex_Sukuna_SV" and c.frame("walk", 0).rect.has_area(), _src(c, "walk"))


func _profile() -> void:
	var s := _game()
	var r := XBattlerSprite.new()
	add_child(r)
	r.setup(s.actor(XRaven.ACTOR), 0.75)
	var body := r.sprite as Sprite2D
	# Raven_Normal_SV [64, 64, 9, 4, 60, 64]：缩放 min(72/60, 129/51)=1.2；可见中线 34.5、底边 64 → 偏移 (32−34.5, 32−64)
	check("profile.raven_scale", is_equal_approx(r.body_scale, 1.2) and is_equal_approx(r.width(), 51 * 1.2) and is_equal_approx(r.height(), 72.0),
		[r.body_scale, r.width(), r.height()])
	check("profile.raven_anchor", body.offset.is_equal_approx(Vector2(-2.5, -32.0)), body.offset)
	r.queue_free()
	var old := XBattlerSprite.new()
	add_child(old)
	old.setup(s.actor(1), 0.75)
	check("profile.legacy", is_equal_approx(old.body_scale, 0.75) and (old.sprite as Sprite2D).offset == Vector2(0, -32), old.body_scale)
	old.queue_free()
	# inferProfile：侧视图量第 2 列第 1 行那格；透明度 < 12 的不算
	var img := Image.create(90, 60, false, Image.FORMAT_RGBA8)
	for y in range(3, 10):
		for x in range(12, 16):
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	img.set_pixel(19, 0, Color(1, 1, 1, 11.0 / 255.0))
	img.set_pixel(2, 2, Color(1, 1, 1, 1))
	var got := XAppearance._infer(ImageTexture.create_from_image(img), false)
	check("profile.infer_sheet", got == [10, 10, 2, 3, 6, 10], got)
	check("profile.infer_empty", XAppearance._infer(ImageTexture.create_from_image(Image.create(90, 60, false, Image.FORMAT_RGBA8)), false).is_empty())


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
