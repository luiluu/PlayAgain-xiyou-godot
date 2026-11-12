extends Node
## 天启篇七印祭坛美术接入专项（XTianqiQiyinArt，content/tianqi/qiyin/，2026-11-12 定稿 26 项）。
## 一、素材：首领图、徽记、神器大图、龙隙、头像框、法阵、图标都在，尺寸对；七印徽记、神器大图、龙隙被 XTianqiQiyinShow.art 取到。
## 二、图标：套装 42、武器 12、「不立文字」叠层 12、神器 5 各有图；XUI.icon_texture 分流到这里；做出来的装备带新图标号；开关关掉借底子。
## 三、首领：殉印、默印里副本 Boss 换新图（去掉借来敌人的侧视图），小怪不换；七首之龙换新图。
## 六、外观（XTianqiQiyinLook）：六件都揭到过才解锁、跨存档记在配置；戴上后战斗脚下有法阵、倒下熄、摘了就没；开关关掉一概不出。
## 七、骑士遗物、徽记：遗物完整／残缺各用自己的图标，徽记大图在。
## 四、精灵：七首之龙七个头叠在躯干上，断几首藏几个头（按揭印顺序）；守默者单数回合（不寂静）换燃起那张；开关关掉都不换。

var results: Array = []
const DIR := "res://content/tianqi/qiyin/"


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(floor := 36, difficulty := "jianxian") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, difficulty, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor)
	XState.current = s
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = XRandomStream.create("0123012301230123", "qiyin")
	XTianqiQiyinDragonRun.rng_override = XRandomStream.create("3210321032103210", "qiyin_dragon")
	return s


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XSave.dir_override = "user://test_xiyou_tianqi_qiyin_art"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	DirAccess.remove_absolute(XConfig.path_override)  # 七印外观的解锁记在配置里，每次从空的起
	_files()
	_icons()
	_bosses()
	await _sprites()
	await _show()
	await _look()
	_relics()
	XTianqiQiyin.rng_override = null
	XTianqiQiyinDragonRun.rng_override = null
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _size(path: String) -> Vector2:
	var t := load(path) as Texture2D
	return t.get_size() if t != null else Vector2.ZERO


# ---- 一、素材 ----

func _files() -> void:
	var seals: Array = XTianqiQiyinArt.SEALS
	_check("seal_keys_match_show", seals == XTianqiQiyinShow.seal_order(), XTianqiQiyinShow.seal_order())
	_check("dragon_body", _size(DIR + "battlers/Tianqi_Qiyin_Dragon.png") == Vector2(512, 464))
	var bad := []
	for k in seals:
		if _size(DIR + "battlers/Tianqi_Qiyin_Dragon_%s.png" % k) != Vector2(512, 464):
			bad.append("head_" + k)
		if _size(DIR + "seals/%s.png" % k) != Vector2(256, 256):
			bad.append("seal_" + k)
		if _size(DIR + "frames/%s.png" % k) != Vector2(128, 128):
			bad.append("frame_" + k)
		if _size(DIR + "circles/%s.png" % k) != Vector2(512, 512):
			bad.append("circle_" + k)
		if XTianqiQiyinShow.art("seal", k) == null:
			bad.append("show_seal_" + k)
	_check("seven_seal_files", bad.is_empty(), bad)
	for n in ["WhiteSoul", "Silent", "Silent_lit"]:
		_check("boss_" + n, _size(DIR + "battlers/Tianqi_Qiyin_%s.png" % n) == Vector2(256, 232))
	var arts := []
	for a in XTianqiQiyinGear.data().artifacts:
		if XTianqiQiyinShow.art("artifact", str(a.key)) == null or _size(DIR + "artifacts/%s.png" % a.key) != Vector2(512, 512):
			arts.append(a.key)
	_check("artifact_pictures", arts.is_empty(), arts)
	_check("rift_picture", XTianqiQiyinShow.art("rift") != null and _size(DIR + "rift.png") == Vector2(1280, 720))
	var small := []
	for f in ["item_seal_key", "item_shards", "item_page", "item_dragon_blood", "item_sealed", "rule_no_cure", "rule_silence",
			"effect_plague", "effect_dragon_blood", "relic_war", "relic_war_broken", "badge_plague"]:
		if _size(DIR + "icons/%s.png" % f) != Vector2(32, 32):
			small.append(f)
	_check("other_icons", small.is_empty(), small)
	# 图名走 XDB：新画的认、别的名字不认
	_check("img_path_battler", XDB.img_path("sv_enemies", "Tianqi_Qiyin_Silent").ends_with("Tianqi_Qiyin_Silent.png"))
	_check("img_path_unknown", XDB.img_path("sv_enemies", "Tianqi_Qiyin_Nope") == "" and XTianqiQiyinArt.battler_path("Other") == "")


# ---- 二、图标 ----

func _icons() -> void:
	var missing := []
	var n := 0
	for s in XTianqiQiyinArt.SEALS:
		for p in XTianqiQiyinArt.PARTS:
			var i := XTianqiQiyinArt.set_icon(s, p)
			n += 1
			if XUI.icon_texture(i) == null or XUI.icon_texture(i).get_size() != Vector2(32, 32):
				missing.append([s, p])
	for t in XTianqiQiyinGear.data().weapon_types:
		for ov in [false, true]:
			var i := XTianqiQiyinArt.weapon_icon(str(t.key), ov)
			n += 1
			if XUI.icon_texture(i) == null:
				missing.append([t.key, ov])
	for a in XTianqiQiyinGear.data().artifacts:
		n += 1
		if XUI.icon_texture(XTianqiQiyinArt.artifact_icon(str(a.key))) == null:
			missing.append(a.key)
	_check("icons_all", missing.is_empty() and n == 42 + 24 + 5, [n, missing])
	var ids := {}
	for s in XTianqiQiyinArt.SEALS:
		for p in XTianqiQiyinArt.PARTS:
			ids[XTianqiQiyinArt.set_icon(s, p)] = true
	_check("icons_distinct", ids.size() == 42 and not ids.has(0))
	_check("icon_unknown", XTianqiQiyinArt.set_icon("nope", "head") == 0 and XTianqiQiyinArt.icon_files(XTianqiQiyinArt.ICON_BASE + 99).is_empty())
	# 叠层：「不立文字」的图不是那类武器的原图
	var plain := XUI.icon_texture(XTianqiQiyinArt.weapon_icon("sword")).atlas.get_image()
	var over := XUI.icon_texture(XTianqiQiyinArt.weapon_icon("sword", true)).atlas.get_image()
	var diff := 0
	for y in 32:
		for x in 32:
			if plain.get_pixel(x, y) != over.get_pixel(x, y):
				diff += 1
	_check("overlay_differs", plain.get_size() == over.get_size() and diff > 20, diff)
	# 大图标（物品状态页 128）走通用最近邻放大
	_check("large_icon", XItemStatusPainter.large_icon(XTianqiQiyinArt.set_icon("mo", "feet")) != null)
	# 不是装备的小图：道具、规则、效果、遗物、徽记都有号、有图；规则号按 qiyin_altar.json 七印的 rule 名取得到
	var small_bad := []
	for start in XTianqiQiyinArt.SMALL:
		for f in XTianqiQiyinArt.SMALL[start]:
			var i := XTianqiQiyinArt.small_icon(str(f))
			if i == 0 or XUI.icon_texture(i) == null:
				small_bad.append(f)
	for k in XTianqiQiyinArt.SEALS:
		if XTianqiQiyinArt.small_icon("rule_" + str(XTianqiQiyin.seal_info(k).rule)) == 0:
			small_bad.append("rule_of_" + k)
	_check("small_icons", small_bad.is_empty(), small_bad)
	_check("small_fixed_numbers", XTianqiQiyinArt.small_icon("item_seal_key") == XTianqiQiyinArt.KEY_ICON and XTianqiQiyinArt.small_icon("item_shards") == XTianqiQiyinArt.SHARDS_ICON
		and XTianqiQiyinArt.small_icon("item_dragon_blood") == XTianqiQiyinArt.BLOOD_ICON and XTianqiQiyinArt.small_icon("item_sealed") == XTianqiQiyinArt.SEALED_ICON)
	# 祭坛文字里的图标号就是这几个
	var head := str(XTianqiQiyin.data().scenes.head[0][1])
	_check("altar_text_icons", head.contains("\\I[%d]" % XTianqiQiyinArt.KEY_ICON) and head.contains("\\I[%d]" % XTianqiQiyinArt.SHARDS_ICON)
		and str(XTianqiQiyinDragonRun.data().scenes.blood_get[0][1]).contains("\\I[%d]" % XTianqiQiyinArt.BLOOD_ICON), head)
	# 徽记暗态：去色压暗、透明照留
	var seal := XTianqiQiyinShow.art("seal", "hong")
	var dim := XTianqiQiyinArt.dim(seal).get_image()
	var c := dim.get_pixel(128, 128)
	_check("seal_dim_gray", is_equal_approx(c.r, c.g) and is_equal_approx(c.g, c.b) and dim.get_pixel(0, 0).a == seal.get_image().get_pixel(0, 0).a, c)
	# 做出来的装备
	var rng := XRandomStream.create("1111222233335555", "qiyin_art")
	var piece := XTianqiQiyinEquip.make({"kind": "set", "seal": "hong", "part": "hands", "true_seal": false, "grades": []}, "jianxian", rng)
	_check("make_set_icon", int(piece.get("iconIndex", 0)) == XTianqiQiyinArt.set_icon("hong", "hands"), piece.get("iconIndex"))
	var wpn := XTianqiQiyinEquip.make({"kind": "weapon", "seal": "hong", "wtype": "sword", "true_seal": false, "grades": []}, "jianxian", rng)
	var wt := XTianqiQiyinEquip.weapon_type(str(wpn.get("qiyin", {}).get("wtype", "sword")))
	_check("make_weapon_icon", not wpn.is_empty() and XTianqiQiyinArt.is_icon(int(wpn.iconIndex)), wpn.get("iconIndex"))
	var mo := XTianqiQiyinEquip.make({"kind": "weapon", "seal": "mo", "wtype": "katana", "true_seal": false, "grades": []}, "jianxian", rng)
	var mo_files := XTianqiQiyinArt.icon_files(int(mo.get("iconIndex", 0)))
	_check("make_buliwenzi_overlay", mo_files.size() == 2 and str(mo_files[1]) == "weapon_overlay_16", [mo.get("name"), mo_files, wt])
	var art := XTianqiQiyinEquip.make({"kind": "artifact", "key": "scales"}, "jianxian", rng)
	_check("make_artifact_icon", int(art.get("iconIndex", 0)) == XTianqiQiyinArt.artifact_icon("scales"), art.get("iconIndex"))
	XTianqiQiyinArt.ENABLED = false
	var old := XTianqiQiyinEquip.make({"kind": "set", "seal": "hong", "part": "hands", "true_seal": false, "grades": []}, "jianxian", rng)
	_check("off_borrowed_icon", not old.is_empty() and not XTianqiQiyinArt.is_icon(int(old.get("iconIndex", 0))), old.get("iconIndex"))
	XTianqiQiyinArt.ENABLED = true


# ---- 三、首领 ----

func _boss_fight(s: XState, seal: String) -> XBattleLogic:
	var troops: Array = XTianqiQiyin.seal_info(seal).troops
	XTianqiQiyinRule.prepare(seal, true, {})
	var lg := XBattleLogic.new()
	lg.setup(int(troops[troops.size() - 1]), s)
	return lg


func _boss_of(lg: XBattleLogic, seal: String) -> XEnemy:
	var id := int(XTianqiQiyin.seal_info(seal).boss.enemy)
	for e in lg.enemies:
		if int(e.enemy_id) == id:
			return e
	return null


func _bosses() -> void:
	var s := _state()
	for pair in [["xun", "Tianqi_Qiyin_WhiteSoul"], ["mo", "Tianqi_Qiyin_Silent"]]:
		var lg := _boss_fight(s, str(pair[0]))
		var e := _boss_of(lg, str(pair[0]))
		_check("boss_%s_battler" % pair[0], e != null and str(e.data().battlerName) == str(pair[1]) and not e.data().get("meta", {}).has("Sideview Battler"),
			e.data().get("battlerName") if e != null else null)
		var look := XAppearance.for_battler(e) if e != null else null
		_check("boss_%s_look" % pair[0], look != null and look.kind == "single" and look.cell == Vector2(256, 232), look.cell if look else null)
		if pair[0] == "xun":
			_check("boss_xun_no_shadow", look != null and look.hide_shadow)
		var others := lg.enemies.filter(func(x): return x != e and str(x.data().get("battlerName", "")).begins_with("Tianqi_Qiyin_"))
		_check("boss_%s_minions_kept" % pair[0], others.is_empty())
	# 别的印的 Boss 照旧借图
	var lg2 := _boss_fight(s, "bai")
	var b2 := _boss_of(lg2, "bai")
	_check("boss_bai_borrowed", b2 != null and not str(b2.data().get("battlerName", "")).begins_with("Tianqi_Qiyin_"))
	XTianqiQiyinArt.ENABLED = false
	var lg3 := _boss_fight(s, "xun")
	var b3 := _boss_of(lg3, "xun")
	_check("off_boss_borrowed", b3 != null and not str(b3.data().get("battlerName", "")).begins_with("Tianqi_Qiyin_"))
	XTianqiQiyinArt.ENABLED = true
	XTianqiQiyinDragonRun.prepare("jianxian")
	var dl := XBattleLogic.new()
	dl.setup(int(XTianqiQiyinDragonRun.fight_info().troop), s)
	var d := XTianqiQiyinDragonRun.dragon(dl)
	_check("dragon_battler", d != null and str(d.data().battlerName) == XTianqiQiyinArt.DRAGON and d.data().meta.is_empty())


# ---- 四、精灵 ----

func _sprite(e: XEnemy) -> XBattlerSprite:
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(e, 1.0)
	XTianqiQiyinArt.update_sprite(sp)
	return sp


func _heads(sp: XBattlerSprite) -> Array:
	var on := []
	for k in XTianqiQiyinArt.SEALS:
		var h := sp.sprite.get_node_or_null("qiyin_head_" + k) as Sprite2D
		if h != null and h.visible:
			on.append(k)
	return on


func _sprites() -> void:
	var s := _state()
	XTianqiQiyinDragonRun.prepare("jianxian")
	var lg := XBattleLogic.new()
	lg.setup(int(XTianqiQiyinDragonRun.fight_info().troop), s)
	var e := XTianqiQiyinDragonRun.dragon(lg)
	var sp := _sprite(e)
	_check("dragon_seven_heads", _heads(sp) == XTianqiQiyinArt.SEALS, _heads(sp))
	_check("dragon_head_aligned", (sp.sprite.get_node("qiyin_head_bai") as Sprite2D).offset == (sp.sprite as Sprite2D).offset)
	var floors: Array = XTianqiQiyinDragonRun.fight(lg).floors
	e.hp = float(floors[1])
	XTianqiQiyinDragonRun.end_action(lg)
	XTianqiQiyinArt.update_sprite(sp)
	var order: Array = XTianqiQiyinDragonRun.fight(lg).order
	_check("dragon_two_cut", _heads(sp) == XTianqiQiyinArt.SEALS.filter(func(k): return not order.slice(0, 2).has(k)), [_heads(sp), order])
	await get_tree().process_frame  # _process 自己也会调
	_check("dragon_process_ok", _heads(sp).size() == 5)
	sp.queue_free()
	# 守默者：寂静回合平时，不寂静回合燃起
	var ml := _boss_fight(s, "mo")
	var m := _boss_of(ml, "mo")
	var ms := _sprite(m)
	var lit := XDB.img_path("sv_enemies", "Tianqi_Qiyin_Silent_lit")
	var normal := XDB.img_path("sv_enemies", "Tianqi_Qiyin_Silent")
	ml.turn = 1
	XTianqiQiyinRule.start_turn(ml)
	XTianqiQiyinArt.update_sprite(ms)
	_check("silent_odd_lit", (ms.sprite as Sprite2D).texture.resource_path == lit, (ms.sprite as Sprite2D).texture.resource_path)
	ml.turn = 2
	XTianqiQiyinRule.start_turn(ml)
	XTianqiQiyinArt.update_sprite(ms)
	_check("silent_even_normal", (ms.sprite as Sprite2D).texture.resource_path == normal, (ms.sprite as Sprite2D).texture.resource_path)
	ms.queue_free()


# ---- 五、演出（XTianqiQiyinShow 用上图时的两处修补） ----

func _show() -> void:
	# 取过的图留着（_draw 里现取的贴图画完就被释放，画成白块）
	_check("show_art_kept", XTianqiQiyinShow.art("seal", "zhen") == XTianqiQiyinShow.art("seal", "zhen"))
	# 套装件掉落：中间那枚印是本印（原来漏设，画成白圆）
	var host := Node.new()
	add_child(host)
	XTianqiQiyinShow.drop(host, {"kind": "set", "seal": "zhen", "part": "head", "true_seal": false})
	await get_tree().process_frame
	var seal := ""
	for c in host.get_children():
		if c is CanvasLayer and c.get_child_count() > 0:
			seal = str(c.get_child(0).seal)
	_check("show_drop_seal", seal == "zhen", seal)
	host.queue_free()


# ---- 六、外观 ----

func _look() -> void:
	var s := _state()
	_check("look_none_yet", XTianqiQiyinLook.unlocked_list().is_empty() and XTianqiQiyinLook.altar_options(s).is_empty())
	for part in ["head", "body", "hands", "waist", "legs"]:
		XTianqiQiyinLook.note({"kind": "set", "seal": "hong", "part": part})
	XTianqiQiyinLook.note({"kind": "weapon", "seal": "hong", "wtype": "剑"})
	_check("look_five_locked", not XTianqiQiyinLook.unlocked("hong") and XTianqiQiyinLook.take_new().is_empty())
	# 第六件从印库揭开（走 XTianqiQiyin.reveal）
	var bag: Array = XTianqiQiyin.progress(s).bag
	bag.append({"kind": "set", "seal": "hong", "part": "feet", "true_seal": false, "grades": ["putong", "putong", "putong"], "revealed": false})
	XTianqiQiyin.reveal(s, bag.size() - 1)
	_check("look_six_unlocked", XTianqiQiyinLook.unlocked("hong") and XTianqiQiyinLook.take_new() == ["hong"], XConfig.tianqi_qiyin_parts())
	_check("look_saved_in_config", XConfig.tianqi_qiyin_parts().has("hong:feet"))
	XTianqiQiyinLook.note({"kind": "set", "seal": "hong", "part": "feet"})
	_check("look_unlock_once", XTianqiQiyinLook.take_new().is_empty())
	_check("look_altar_option", XTianqiQiyinLook.altar_options(s).size() == 1 and XTianqiQiyin.altar_options(s).any(func(o): return o.id == "look"))
	var a: XActor = s.battle_members()[0]
	_check("look_wear_locked_refused", not XTianqiQiyinLook.wear(s, a.actor_id, "bai") and XTianqiQiyinLook.worn(a, s) == "")
	_check("look_wear", XTianqiQiyinLook.wear(s, a.actor_id, "hong") and XTianqiQiyinLook.worn(a, s) == "hong")
	_check("look_frame_texture", XTianqiQiyinLook.frame_texture("hong") != null and XTianqiQiyinLook.circle_texture("hong") != null)
	# 新开一档：解锁还在（配置），佩戴是本档的
	var s2 := _state()
	_check("look_cross_save", XTianqiQiyinLook.unlocked("hong") and XTianqiQiyinLook.worn(s2.battle_members()[0], s2) == "")
	XState.current = s
	# 战斗法阵
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var b: XActor = null
	for x in lg.actors:
		if int(x.actor_id) == int(a.actor_id):
			b = x
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(b, 1.0)
	XTianqiQiyinLook.update_sprite(sp)
	var node := sp.get_node_or_null(XTianqiQiyinLook.NODE) as Node2D
	_check("circle_made", node != null and str(node.get_meta("seal")) == "hong" and node.get_index() == 0 and node.scale.y < 0.5)
	await get_tree().process_frame
	b.hp = 0
	b.add_state(1)
	XTianqiQiyinLook.update_sprite(sp)
	_check("circle_dead_off", node != null and is_zero_approx(node.modulate.a))
	XTianqiQiyinLook.wear(s, a.actor_id, "")
	XTianqiQiyinLook.update_sprite(sp)
	await get_tree().process_frame
	_check("circle_removed", sp.get_node_or_null(XTianqiQiyinLook.NODE) == null)
	sp.queue_free()
	XTianqiQiyinLook.wear(s, a.actor_id, "hong")
	XTianqiQiyinLook.ENABLED = false
	_check("look_off", XTianqiQiyinLook.worn(a, s) == "" and XTianqiQiyinLook.altar_options(s).is_empty())
	XTianqiQiyinLook.note({"kind": "set", "seal": "bai", "part": "head"})
	_check("look_off_no_note", not XConfig.tianqi_qiyin_parts().has("bai:head"))
	XTianqiQiyinLook.ENABLED = true
	# 开祭坛补记：本档印库里已经揭开的（功能上线前揭的）
	for part in ["head", "body", "hands", "waist", "legs", "feet"]:
		bag.append({"kind": "set", "seal": "mo", "part": part, "revealed": true})
	XTianqiQiyinLook.catch_up(s)
	_check("look_catch_up", XTianqiQiyinLook.unlocked("mo") and XTianqiQiyinLook.take_new() == ["mo"])


# ---- 七、骑士遗物、徽记 ----

func _relics() -> void:
	var full := XTianqiRewards.make_item("relic", "war", 0, false)
	var half := XTianqiRewards.make_item("relic", "war", 0, true)
	_check("relic_full_icon", int(full.get("iconIndex", 0)) == XTianqiQiyinArt.small_icon("relic_war"), full.get("iconIndex"))
	_check("relic_half_icon", int(half.get("iconIndex", 0)) == XTianqiQiyinArt.small_icon("relic_war_broken"), half.get("iconIndex"))
	var bad := []
	for line in ["death", "war", "famine", "plague"]:
		var t := XTianqiQiyinArt.badge_texture(line)
		if t == null or t.get_size() != Vector2(128, 128):
			bad.append(line)
	_check("badge_big", bad.is_empty(), bad)
