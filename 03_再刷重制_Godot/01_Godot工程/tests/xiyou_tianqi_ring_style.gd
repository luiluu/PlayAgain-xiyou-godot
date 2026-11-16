extends Node
## 天启篇环纹（XTianqiRingStyle，数据 modes/xiyou/tianqi_data/ring_styles.json；装备环样式设计 v0.2.1 卡 1）专项：7.5 节逐行——
## 规则表（七印 4／5 件、换一件掉回、微亮三条、七印盖过微亮、旧线净印、遗物完整／残缺、七印神器全队一件、毕业武器、刻印、双持、白名单、开关）；
## 槽位映射（副手那颗亮、不是神器那颗；178 哈基米不出错）；不压字（环心圆距、球框、小点 × 键鼠 100％／触屏 100％／130％ × 常规／哈基米）；
## 层序（_orb_ci 在 _label_ci 之前、都在 ring_top 之前）；位置没动；不变卡（挪光标不重算）；动效档；设置项「装备环纹」（旧配置默认开）；贴图不出正红。
## 带 -- --out=<目录> 且有窗口时另出截图（每套 × 16:9、4:3、20:9 触屏 130％），并测环区正红像素（和默认环比，新增 0）、栏位名对比度。
## 带 -- --off-shot=<文件> 只出一张「ENABLED 关」的装备页截图（逐像素对照用，见交付单）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SIZES := [[Vector2i(1280, 720), "16x9"], [Vector2i(960, 720), "4x3"], [Vector2i(1600, 720), "20x9"]]

var results := []
var out_dir := ""
var off_shot := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--off-shot="):
			off_shot = arg.substr(11)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return DisplayServer.get_name() != "headless"


func _run() -> void:
	TestEnv.isolate("xiyou_tianqi_ring_style")
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin.touch_override = 0
	if off_shot != "":
		await _off_shot_only()
	else:
		_rules()
		_textures()
		_intro_kinds()
		await _page()
		await _no_overlap()
		await _motion()
		_settings()
		if out_dir != "" and windowed():
			await _shots()
	XTianqiRingStyle.ENABLED = true
	XTianqiRingStyle.GLINT = true
	XUiSkin.touch_override = -1
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(line := "war") -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian", "line": line}
	s.map_id = 1
	s.set_variable(20, 32)
	return s


static func _gear(mark: Dictionary, extra := {}) -> Dictionary:
	var e := {"id": 1, "name": "测试件", "kind": "armor", "atypeId": 1, "wtypeId": 0, "iconIndex": 97, "etypeId": 1, "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "note": ""}
	if not mark.is_empty():
		e["qiyin"] = mark
	e.merge(extra, true)
	return e


static func _set_piece(seal: String) -> Dictionary:
	return _gear({"kind": "set", "seal": seal, "part": "x", "true_seal": false})


static func _clear(a: XActor) -> void:
	for i in a.equips.size():
		a.equips[i] = {}


## 防具 6 格（装备类型 3～8 ＝ 槽位 2～7）
const ARMOR := [2, 3, 4, 5, 6, 7]
const NECK := 8
const ART := 16


func _rules() -> void:
	var s := _state("war")
	var a := s.actor(int(s.party[0]))
	var b := s.actor(int(s.party[1]))
	var c := s.actor(int(s.party[2]))
	var R := XTianqiRingStyle
	_clear(a)
	for k in 4:
		a.equips[ARMOR[k]] = _set_piece("hei")
	var r := R.resolve(a)
	check("rule_set4_no_band", r.band == "" and (r.dots as Dictionary).size() == 4, r)
	check("rule_set4_dots_tint", (r.dots as Dictionary).values().all(func(col): return col == R.seal_tint("hei")), r.dots)
	a.equips[ARMOR[4]] = _set_piece("hei")
	r = R.resolve(a)
	check("rule_set5_band", r.band == "seal_hei" and (r.dots as Dictionary).size() == 5, r)
	check("rule_set5_caption", R.caption_suffix(r) == " · 黑印", R.caption_suffix(r))
	a.equips[ARMOR[4]] = _set_piece("bai")
	r = R.resolve(a)
	check("rule_swap_one_back", r.band == "" and (r.dots as Dictionary).size() == 4 and not (r.dots as Dictionary).has(ARMOR[4]), r)
	# 混穿 3＋3：各球各亮各的色
	_clear(a)
	for k in 6:
		a.equips[ARMOR[k]] = _set_piece("hei" if k < 3 else "mo")
	r = R.resolve(a)
	check("rule_mixed_3_3_dots", r.band == "" and r.dots[ARMOR[0]] == R.seal_tint("hei") and r.dots[ARMOR[5]] == R.seal_tint("mo"), r.dots)
	# 微亮：本线第三档净印
	_clear(a)
	a.equips[NECK] = XTianqiRewards.make_item("seal", "war", 3)
	r = R.resolve(a)
	check("rule_glint_jingyin3", r.band == "glint" and R.caption_suffix(r) == "", r)
	a.equips[NECK] = XTianqiRewards.make_item("seal", "war", 2)
	check("rule_glint_jingyin2_no", R.resolve(a).band == "")
	a.equips[NECK] = XTianqiRewards.make_item("seal", "death", 3)   # 旧线净印（本档走战争）
	check("rule_glint_old_line_no", R.resolve(a).band == "")
	# 微亮另两条：没接恒假；接上就命中
	_clear(a)
	check("rule_glint_hooks_default_false", R.resolve(a).band == "")
	R.orig_set_full_hook = func(_x): return true
	check("rule_glint_orig_set", R.resolve(a).band == "glint")
	R.orig_set_full_hook = Callable()
	R.runeword_hook = func(_x): return true
	check("rule_glint_runeword", R.resolve(a).band == "glint")
	R.GLINT = false
	check("rule_glint_switch_off", R.resolve(a).band == "")
	R.GLINT = true
	# 七印满套盖过微亮
	for k in 5:
		a.equips[ARMOR[k]] = _set_piece("mo")
	check("rule_seal_over_glint", R.resolve(a).band == "seal_mo")
	R.runeword_hook = Callable()
	# 遗物：完整／残缺
	_clear(a)
	a.equips[ART] = XTianqiRewards.make_item("relic", "death", 1, false)
	r = R.resolve(a)
	check("rule_relic_full", r.center == "relic_death" and float(r.center_dim) == 1.0 and r.center_note == "", r)
	a.equips[ART] = XTianqiRewards.make_item("relic", "death", 1, true)
	r = R.resolve(a)
	check("rule_relic_half", r.center == "relic_death" and is_equal_approx(float(r.center_dim), 0.6) and r.center_note == "（残）", r)
	check("rule_relic_caption", R.caption_suffix(r) == " · 死亡遗物（残）", R.caption_suffix(r))
	for k in 5:
		a.equips[ARMOR[k]] = _set_piece("hei")
	check("rule_caption_both", "身上 6 件" + R.caption_suffix(R.resolve(a)) == "身上 6 件 · 黑印 · 死亡遗物（残）", R.caption_suffix(R.resolve(a)))
	# 七印神器：全队只第一个戴的亮
	_clear(a)
	_clear(b)
	_clear(c)
	var akey := str((XTianqiQiyinGear.artifacts()[0] as Dictionary).key)
	var art := func(): return _gear({"kind": "artifact", "key": akey}, {"etypeId": 17})
	a.equips[ART] = art.call()
	r = R.resolve(a)
	check("rule_artifact_solo_no_party", r.center == "qiyin_artifact" and R.caption_suffix(r) == " · 七印神器", r)
	check("rule_artifact_solo_party", R.resolve(a, [a, b]).center == "qiyin_artifact")
	b.equips[ART] = art.call()
	var ra := R.resolve(a, [a, b])
	var rb := R.resolve(b, [a, b])
	check("rule_artifact_two_first_only", ra.center == "qiyin_artifact" and rb.center == "" and rb.center_note == "（未生效）" \
		and R.caption_suffix(rb) == " · 七印神器（未生效）", [ra, rb])
	check("rule_artifact_reorder", R.resolve(b, [b, a]).center == "qiyin_artifact" and R.resolve(a, [b, a]).center == "")
	check("rule_artifact_backup_off", R.resolve(c, [a, b]).center == "")
	c.equips[ART] = art.call()
	check("rule_artifact_backup_inactive", R.resolve(c, [a, b]).center == "" and R.resolve(c, [a, b]).center_note == "（未生效）")
	# 白名单 8 件成长／纪念神器：不改环心
	_clear(a)
	var wl_ok := true
	for id in XTianqiGear.ARTIFACTS:
		var t := XGear.template("armor", int(id))
		if t.is_empty():
			continue
		a.equips[ART] = t
		if R.resolve(a, [a]).center != "" or R.resolve(a, [a]).center_note != "":
			wl_ok = false
	check("rule_whitelist_no_center", wl_ok)
	# 毕业武器：只亮自己那颗；刻印专属武器亮球框；双持两把不同印各自染色
	_clear(a)
	var wk_hei := str((XTianqiQiyinGear.weapons_of_seal("hei")[0] as Dictionary).key)
	var wk_bai := str((XTianqiQiyinGear.weapons_of_seal("bai")[0] as Dictionary).key)
	a.equips[0] = _gear({"kind": "weapon", "seal": "hei", "key": wk_hei, "true_seal": false})
	r = R.resolve(a)
	check("rule_weapon_one_orb", (r.orbs as Dictionary).keys() == [0] and r.orbs[0].tint == R.seal_tint("hei") and r.band == "" and r.center == "", r)
	a.equips[0] = _gear({"kind": "engrave", "key": wk_bai})
	r = R.resolve(a)
	check("rule_engrave_orb", (r.orbs as Dictionary).keys() == [0] and r.orbs[0].tint == R.seal_tint("bai"), r)
	a.equips[0] = _gear({"kind": "weapon", "seal": "hei", "key": wk_hei, "true_seal": false})
	a.equips[1] = _gear({"kind": "weapon", "seal": "bai", "key": wk_bai, "true_seal": false})
	r = R.resolve(a)
	check("rule_dual_two_tints", (r.orbs as Dictionary).size() == 2 and r.orbs[0].tint == R.seal_tint("hei") and r.orbs[1].tint == R.seal_tint("bai"), r)
	# 备注挂球框
	_clear(a)
	a.equips[9] = _gear({}, {"note": "<ring_style:orb_seal:zhen>"})
	r = R.resolve(a)
	check("rule_item_tag_orb", (r.orbs as Dictionary).has(9) and r.orbs[9].tint == R.seal_tint("zhen"), r)
	check("rule_note_tag_parse", R.note_tag({"note": "x<ring_style:orb_seal>y"}) == ["orb_seal", ""] and R.note_tag({"note": "无"}).is_empty())
	# 开关：ENABLED 关、设置关、非天启篇 → 空
	for k in 5:
		a.equips[ARMOR[k]] = _set_piece("hei")
	check("rule_on_baseline", R.resolve(a).band == "seal_hei")
	R.ENABLED = false
	var off := R.resolve(a)
	check("rule_enabled_off_empty", off.band == "" and (off.orbs as Dictionary).is_empty() and (off.dots as Dictionary).is_empty() and off.sig == "", off)
	R.ENABLED = true
	XConfig.set_flag(R.SETTING, false)
	check("rule_setting_off_empty", R.resolve(a).band == "" and (R.resolve(a).dots as Dictionary).is_empty())
	XConfig.set_flag(R.SETTING, true)
	var xs := XState.new_game(3, 1, [8, 9, 10])
	var xa := xs.actor(int(xs.party[0]))
	for k in 5:
		xa.equips[ARMOR[k]] = _set_piece("hei")
	check("rule_not_tianqi_empty", R.resolve(xa, [], xs).band == "")
	XState.current = s
	# 指纹
	check("rule_sig_changes", R.resolve(a).sig != R.resolve(b).sig and R.resolve(a).sig == R.resolve(a).sig)


func _textures() -> void:
	var R := XTianqiRingStyle
	R.reload()
	var reds := {}
	for key in (R.data().styles as Dictionary):
		var st := R.style(key)
		var art: Dictionary = st.get("art", {})
		for k in art:
			if k == "band" or k == "frame":
				var t := R.texture(str(art[k]), {"band": "band", "frame": "orb" if st.layer == "orb" else "center"}[k])
				if st.layer == "orb":
					for seal in (R.data().seal_tints as Dictionary):
						reds[key + ":" + seal] = R.red_pixels(t, R.seal_tint(seal))
				else:
					reds[key + ":" + k] = R.red_pixels(t)
			elif k == "circle":
				var ct := R.texture(str(art.circle), "circle")
				var tint := Color.html(str(art.get("circle_tint", "#ffffff")))
				reds[key + ":circle"] = R.red_pixels(ct, tint) if ct != null else -1
	check("tex_no_red", reds.values().all(func(n): return n == 0), reds)
	check("tex_hong_circle_tinted", reds.get("seal_hong:circle") == 0 and R.red_pixels(R.texture("res://content/tianqi/qiyin/circles/hong.png", "circle")) > 0,
		"hong.png 原图该有正红、染色后没有")
	var band := R.placeholder("band")
	var center := R.placeholder("center")
	var orb := R.placeholder("orb")
	check("tex_placeholder_sizes", band.get_size() == Vector2(288, 288) and center.get_size() == Vector2(96, 96) and orb.get_size() == Vector2(56, 56))
	check("tex_seal_tints_7", (R.data().seal_tints as Dictionary).size() == 7 and XTianqiQiyinGear.seal_keys().all(func(k): return (R.data().seal_tints as Dictionary).has(k)))
	# 占位图尺寸规矩：环心框 33～38、尖到 46 且在 12 点 ±15° 内；球框身 ≤ 24、斜角饰 ≤ 28
	var ci := center.get_image()
	var co := orb.get_image()
	var c_ok := true
	for y in 96:
		for x in 96:
			if ci.get_pixel(x, y).a > 0.0:
				var p := Vector2(x + 0.5, y + 0.5) - Vector2(48, 48)
				var d := p.length()
				if d < 33.0 or d > 46.0 or (d > 38.0 and absf(rad_to_deg(p.angle()) + 90.0) > 15.0):
					c_ok = false
	var o_ok := true
	for y in 56:
		for x in 56:
			if co.get_pixel(x, y).a > 0.0:
				var p := Vector2(x + 0.5, y + 0.5) - Vector2(28, 28)
				if p.length() > 28.0 or (p.length() > 24.0 and absf(absf(p.x) - absf(p.y)) > 1.5):
					o_ok = false
	check("tex_center_bounds", c_ok)
	check("tex_orb_bounds", o_ok)


func _intro_kinds() -> void:
	var R := XTianqiRingStyle
	var none := R.empty_result()
	var seal := R.empty_result()
	seal.band = "seal_hei"
	var glint := R.empty_result()
	glint.band = "glint"
	var relic := R.empty_result()
	relic.center = "relic_death"
	var half := relic.duplicate()
	half.center_dim = 0.6
	var orb := R.empty_result()
	orb.orbs = {0: {"style": "orb_seal", "tint": Color.WHITE}}
	check("intro_seal_burn", R.intro_kind(none, seal) == "burn")
	check("intro_glint_fade", R.intro_kind(none, glint) == "fade" and R.intro_kind(glint, none) == "fade")
	check("intro_off_fade", R.intro_kind(seal, none) == "fade")
	check("intro_glint_to_seal_burn", R.intro_kind(glint, seal) == "burn")
	check("intro_relic_burn_half_fade", R.intro_kind(none, relic) == "burn" and R.intro_kind(none, half) == "fade")
	check("intro_orb_only_none", R.intro_kind(none, orb) == "")


# ---- 装备页 ----

func _build_equip(cat := false) -> XEquipScene:
	var s := _state("war")
	if cat:
		s.party.erase(XCat.ACTOR)
		s.party.insert(0, XCat.ACTOR)
	var page := XEquipScene.new()
	add_child(page)
	await frames(4)
	return page


func _bump(page: XEquipScene) -> void:
	page._cand_rev += 1
	page._refresh()
	await frames(2)


func _page() -> void:
	XSkinEquipPage.LAYOUT = 3
	var page := await _build_equip()
	var sk: XSkinEquipPage = page.skin
	var ring := sk.ring
	var a := page.actor()
	check("page_branched", XSkinEquipPage.branched() and ring.items.size() == 13)
	var pos0 := []
	for i in ring.items.size():
		pos0.append(ring.item_pos(i))
	var r0 := ring.orb_radius
	check("page_default_plain", ring.style_art.is_empty() and ring.orb_frames.is_empty() and ring.labels_on == "parent" and ring.style == XSkinEquipPage.base_style())
	# 副手穿毕业武器：亮的是副手那颗（items[i].key == 1），不是神器那颗（第 1 项）
	_clear(a)
	var wk := str((XTianqiQiyinGear.weapons_of_seal("hei")[0] as Dictionary).key)
	a.equips[1] = _gear({"kind": "weapon", "seal": "hei", "key": wk, "true_seal": false})
	await _bump(page)
	var lit: Array = ring.orb_frames.keys()
	check("page_slot_map_offhand", lit.size() == 1 and int(ring.items[int(lit[0])].key) == 1 and int(lit[0]) != 1, [lit, ring.items.map(func(it): return it.key)])
	check("page_slot_map_not_artifact", int(ring.items[1].key) != 1, ring.items[1].key)
	check("page_layers_on", ring.ring_layers() and ring.labels_on == "label_ci")
	# 层序：_orb_ci → _label_ci → _art_ci，都在子控件 ring_top 之前；没设 draw_index
	check("page_layer_order", ring.layer_order == ["band_ci(behind)", "parent", "orb_ci", "label_ci", "art_ci", "children"] and ring_top_after(ring, sk))
	# 套装 5 件＋遗物：环身、环心、说明
	for k in 5:
		a.equips[ARMOR[k]] = _set_piece("hei")
	a.equips[ART] = XTianqiRewards.make_item("relic", "death", 1, false)
	await _bump(page)
	check("page_band_art", ring.style_art.get("band") is Texture2D and ring.style_art.get("circle") is Texture2D and ring.orb_dots.size() == 5)
	check("page_caption", sk.caption() == "身上 7 件 · 黑印 · 死亡遗物", sk.caption())
	var cf := sk.center_frame()
	var cr := sk.center_frame_rect(cf) if cf != null else Rect2()
	check("page_center_frame", cf != null and cr.size == Vector2(96, 96) and cr.position == cr.position.round() \
		and cr.get_center().distance_to(ring.center()) <= 0.71, [cr, ring.center()])
	# 位置没动
	var same := true
	for i in ring.items.size():
		if ring.item_pos(i) != pos0[i]:
			same = false
	check("page_positions_same", same and ring.orb_radius == r0)
	# 挪光标不重算
	var calls := XTianqiRingStyle.resolve_calls
	var t0 := Time.get_ticks_usec()
	for k in 13:
		page._unhandled_input(_key("ui_down"))
	var styled_us := (Time.get_ticks_usec() - t0) / 13.0
	check("page_cursor_no_resolve", XTianqiRingStyle.resolve_calls == calls, XTianqiRingStyle.resolve_calls - calls)
	# 换出战顺序：重算
	var s := XState.current
	s._ensure_slots()
	var bs := s.battle_slots.duplicate()
	var tmp = bs[0]
	bs[0] = bs[1]
	bs[1] = tmp
	s.battle_slots = bs
	page._refresh()
	check("page_order_resolves", XTianqiRingStyle.resolve_calls == calls + 1, XTianqiRingStyle.resolve_calls - calls)
	# 亲手换装才演：同一人同一顺序下换上第 5 件 → 演 burn；换人不演
	XUiSkin.motion_override = XUiSkin.Motion.SIMPLE
	a.equips[ARMOR[4]] = {}
	await _bump(page)
	a.equips[ARMOR[4]] = _set_piece("hei")
	await _bump(page)
	check("page_intro_on_equip", ring.intro_kind == "burn" and ring.intro_t < 1.0, [ring.intro_kind, ring.intro_t])
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	# 开关关：环回默认，名字回父层
	XTianqiRingStyle.ENABLED = false
	await _bump(page)
	check("page_enabled_off_plain", ring.style_art.is_empty() and ring.orb_frames.is_empty() and ring.orb_dots.is_empty() and ring.labels_on == "parent" \
		and ring.style == XSkinEquipPage.base_style() and sk.center_frame() == null and sk.caption() == "身上 7 件", sk.caption())
	var t1 := Time.get_ticks_usec()
	for k in 13:
		page._unhandled_input(_key("ui_down"))
	var plain_us := (Time.get_ticks_usec() - t1) / 13.0
	# 挪光标耗时增量（同一页、同一人、开关开／关各挪 13 格取平均）；无头下抖动大，门放宽到 0.5 毫秒，实测数写进交付单
	print("RING_SYNC_US styled=%.1f plain=%.1f" % [styled_us, plain_us])
	check("page_cursor_cost", styled_us - plain_us <= 500.0, [styled_us, plain_us])
	XTianqiRingStyle.ENABLED = true
	page.queue_free()
	await frames(3)
	# 178 哈基米（没有副手）：武器那颗亮，不出错
	var cp := await _build_equip(true)
	var ca := cp.actor()
	check("cat_first", ca.actor_id == XCat.ACTOR, ca.actor_id)
	ca.equips[0] = _gear({"kind": "weapon", "seal": "hei", "key": wk, "true_seal": false})
	await _bump(cp)
	var cl: Array = cp.skin.ring.orb_frames.keys()
	check("cat_weapon_orb", cl.size() == 1 and int(cp.skin.ring.items[int(cl[0])].key) == 0, cl)
	cp.queue_free()
	await frames(3)


## ring_top 是环的子控件：子控件画在环的子画布项之后（它是 _init 之后才 add_child 的）
func ring_top_after(ring: XSkinRingNav, sk: XSkinEquipPage) -> bool:
	return sk.ring_top.get_parent() == ring and sk.ring_top.z_index == 0 and sk.ring_top.get_index() == 0


# ---- 不压字（7.5 v0.2.1 口径） ----

func _no_overlap() -> void:
	var cases := [["key100", 0, 100], ["touch100", 1, 100], ["f130", 1, 130]]
	for cat in [false, true]:
		for cs in cases:
			XUiSkin.touch_override = cs[1]
			XFontScale.set_value("global", cs[2])
			var page := await _build_equip(cat)
			var ring: XSkinRingNav = page.skin.ring
			var tag := "%s_%s" % ["cat" if cat else "std", cs[0]]
			var bad := []
			for sel in range(-1, ring.items.size()):
				ring.index = maxi(sel, 0)
				ring._scales.clear()
				if sel < 0:   # 全部未选中：选中号挪到范围外
					ring.index = ring.items.size() + 5
				var labels := []
				for i in ring.items.size():
					labels.append(ring.label_layout(i).rect)
				var c := ring.center()
				for i in labels.size():
					var rc: Rect2 = labels[i]
					# ① 环心框按圆判：名框到环心最近距离 > 38；名框不碰 12 点 ±15° 扇形（38～46）
					if _rect_dist(rc, c) <= 38.0:
						bad.append(["center", sel, i, _rect_dist(rc, c)])
					if _rect_hits_sector(rc, c, 38.0, 46.0, -90.0, 15.0):
						bad.append(["tip", sel, i])
				for j in ring.items.size():
					var k := ring.item_scale(j)
					var p := ring.item_pos(j)
					# ② 球框：圆 24k＋四个 45° 斜角饰到 28k，不碰别的栏位名
					for i in labels.size():
						if i == j:
							continue
						if _rect_dist(labels[i], p) <= 24.0 * k or _diag_hits(labels[i], p, 24.0 * k, 28.0 * k):
							bad.append(["frame", sel, j, i])
					# 正上方武器那颗：框身圆到本名框 > 0
					if int(ring.items[j].key) == 0 and _rect_dist(labels[j], p) <= 24.0 * k:
						bad.append(["weapon_own", sel, j, _rect_dist(labels[j], p)])
				# ③ 小点（防具 6 颗）：不碰任何名框、连线、别的球
				for j in ring.items.size():
					if not ARMOR.has(int(ring.items[j].key)):
						continue
					var dr := ring.dot_rect(j)
					for i in labels.size():
						if dr.intersects(labels[i]):
							bad.append(["dot_label", sel, j, i])
					for o in ring.items.size():
						if o != j and _rect_dist(dr, ring.item_pos(o)) <= ring.orb_radius * ring.item_scale(o):
							bad.append(["dot_orb", sel, j, o])
					for path in ring.links:
						for q in ring.link_route(path):
							if _rect_dist(dr, c + q) <= 2.3 + 1.5:
								bad.append(["dot_link", sel, j])
								break
			check("nooverlap_" + tag, bad.is_empty(), bad.slice(0, 8))
			page.queue_free()
			await frames(3)
	XUiSkin.touch_override = 0
	XFontScale.set_value("global", 100)


static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p)


static func _rect_hits_sector(r: Rect2, c: Vector2, r0: float, r1: float, deg: float, half: float) -> bool:
	for k in 31:
		var a := deg_to_rad(deg - half + 2.0 * half * k / 30.0)
		for rr in range(int(r0), int(r1) + 1):
			if r.has_point(c + Vector2.from_angle(a) * rr):
				return true
	return false


static func _diag_hits(r: Rect2, p: Vector2, r0: float, r1: float) -> bool:
	for a in [45.0, 135.0, 225.0, 315.0]:
		for t in 9:
			if r.has_point(p + Vector2.from_angle(deg_to_rad(a)) * lerpf(r0, r1, t / 8.0)):
				return true
	return false


# ---- 动效档 ----

func _motion() -> void:
	var rn := XSkinRingNav.new()
	rn.items = [{"name": "甲"}, {"name": "乙"}]
	XUiSkin.motion_override = XUiSkin.Motion.SIMPLE
	rn.play_intro("burn")
	var sp := rn._spin
	rn.advance(0.3)
	check("motion_simple_intro_plays", rn.intro_t > 0.4 and rn.intro_t < 0.6 and rn._spin == sp and rn.ring_motion_level() == 1, rn.intro_t)
	rn.advance(0.4)
	check("motion_simple_intro_done", rn.intro_t == 1.0)
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	rn.play_intro("fade")
	rn.advance(0.15)
	check("motion_full_fade_half", rn.intro_alpha() > 0.4 and rn.intro_alpha() < 0.6 and rn._spin > sp, rn.intro_alpha())
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	rn.play_intro("burn")
	check("motion_off_one_frame", rn.intro_t == 1.0 and rn.ring_motion_level() == 0)
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XConfig.set_flag("codexScreenFx", false)
	rn.play_intro("burn")
	check("motion_fx_off_one_frame", rn.intro_t == 1.0 and rn.ring_motion_level() == 0)
	XConfig.set_flag("codexScreenFx", true)
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	rn.free()


# ---- 设置项 ----

func _settings() -> void:
	var p := XConfig.path_override
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	XConfig._loaded_path = "<unloaded>"
	check("setting_default_on_no_file", XConfig.flag("codexRingStyle"))
	for pair in [[{"bgmVolume": 40}, true], [{"codexRingStyle": false}, false], [{"codexRingStyle": "abc"}, true], [{"codexRingStyle": 0}, true]]:
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[0]))
		f.close()
		XConfig._loaded_path = "<unloaded>"
		check("setting_load_" + JSON.stringify(pair[0]), XConfig.flag("codexRingStyle") == pair[1], XConfig.flag("codexRingStyle"))
	XConfig.set_flag("codexRingStyle", true)
	check("setting_saved", XConfig.flag("codexRingStyle"))
	_state("war")
	var opt := XOptionsScene.new()
	opt._build_list()
	var syms: Array = opt._list.map(func(o): return str(o[1]))
	check("setting_row_after_motion", syms.has("codexRingStyle") and syms.find("codexRingStyle") == syms.find("codexUiMotion") + 1, syms)
	check("setting_row_onoff", opt.status_text(syms.find("codexRingStyle")) == "ON", opt.status_text(syms.find("codexRingStyle")))
	XUiSkin.FORCE = false
	var keep := XState.current
	XState.current = XState.new_game(3, 1, [8, 9, 10])   # 西游存档：新皮肤不可选，这一行不列
	opt._build_list()
	check("setting_row_hidden_xiyou", not opt._list.any(func(o): return str(o[1]) == "codexRingStyle"))
	XState.current = keep
	XUiSkin.FORCE = true
	opt.free()


# ---- 截图（带窗口） ----

func _loadout(a: XActor, kind: String) -> void:
	_clear(a)
	var wk := str((XTianqiQiyinGear.weapons_of_seal("hei")[0] as Dictionary).key)
	match kind:
		"hei":
			for k in 5:
				a.equips[ARMOR[k]] = _set_piece("hei")
			a.equips[ARMOR[5]] = _set_piece("mo")
			a.equips[0] = _gear({"kind": "weapon", "seal": "hei", "key": wk, "true_seal": false})
		"mo":
			for k in 5:
				a.equips[ARMOR[k]] = _set_piece("mo")
		"death":
			a.equips[ART] = XTianqiRewards.make_item("relic", "death", 1, false)
			for k in 3:
				a.equips[ARMOR[k]] = _set_piece("hong")
		"death_half":
			a.equips[ART] = XTianqiRewards.make_item("relic", "death", 1, true)
		"glint":
			a.equips[NECK] = XTianqiRewards.make_item("seal", "war", 3)
		"hong":
			for k in 5:
				a.equips[ARMOR[k]] = _set_piece("hong")
		"xun":
			for k in 5:
				a.equips[ARMOR[k]] = _set_piece("xun")


func _shot_page(kind: String, sz: Array, touch: bool, downs: int) -> XEquipScene:
	get_window().size = sz[0]
	XUiSkin.touch_override = 1 if touch else 0
	XFontScale.set_value("global", 130 if touch else 100)
	await frames(4)
	var page := await _build_equip()
	_loadout(page.actor(), kind)
	await _bump(page)
	for k in downs:
		page._unhandled_input(_key("ui_down"))
	await frames(4)
	return page


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	for sz in SIZES:
		var touch: bool = sz[1] == "20x9"
		for kind in ["hei", "mo", "death", "death_half", "glint", "hong", "xun"]:
			if sz[1] != "16x9" and kind in ["hong", "xun"]:
				continue
			var page := await _shot_page(kind, sz, touch, 0)
			var img := await _grab()
			var name := "ring_%s_%s%s" % [kind, sz[1], "_触屏130" if touch else ""]
			check("shot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
			if sz[1] == "16x9":
				await _red_and_contrast(page, img, kind)
			page.queue_free()
			await frames(3)
	XUiSkin.touch_override = 0
	XFontScale.set_value("global", 100)
	get_window().size = SIZES[0][0]
	await frames(4)


## 正红：同一页、同一选中，环纹开的截图里环区新增的正红像素（默认环本来就有的红框、光弧不算）＝ 0；
## 字看得清：栏位名框里，名字隐去后的底色取 90 分位亮度，选中 ≥ 7、其余 ≥ 4.5（红印、殉印法阵各测一次）
func _red_and_contrast(page: XEquipScene, styled: Image, kind: String) -> void:
	var ring: XSkinRingNav = page.skin.ring
	var gr := ring.get_global_rect()
	XTianqiRingStyle.ENABLED = false
	await _bump(page)
	var plain := await _grab()
	XTianqiRingStyle.ENABLED = true
	await _bump(page)
	# 排除选中项红框（补画的那圈和原来那圈叠在一起，抗锯齿边会多几个像素过门）：选中球心 ±（r−4～r+4）的圆环
	var sp := gr.position + ring.item_pos(ring.index)
	var sr := ring.orb_radius * ring.item_scale(ring.index)
	var added := []
	for y in range(int(gr.position.y), int(gr.end.y)):
		for x in range(int(gr.position.x), int(gr.end.x)):
			if _red(styled.get_pixel(x, y)) and not _red(plain.get_pixel(x, y)):
				if absf(Vector2(x + 0.5, y + 0.5).distance_to(sp) - sr) <= 4.0:
					continue
				if Vector2(x + 0.5, y + 0.5).distance_to(gr.position + ring.center()) <= 33.0:   # 头像本身（有环心框时缩到 33，角色立绘里的红眼睛不算环纹）
					continue
				added.append(Vector2i(x, y))
	check("red_added_zero_" + kind, added.is_empty(), [added.size(), added.slice(0, 6)])
	# 底色：名字不画再截一张
	var bg := await _grab_hidden(page)
	var worst := []
	for i in ring.items.size():
		var lay := ring.label_layout(i)
		var rc: Rect2 = lay.rect
		rc.position += gr.position
		var lum := []
		for y in range(int(rc.position.y), int(rc.end.y)):
			for x in range(int(rc.position.x), int(rc.end.x)):
				lum.append(_lum(bg.get_pixel(x, y)))
		if lum.is_empty():
			continue
		lum.sort()
		var l90: float = lum[int(lum.size() * 0.9)]
		var txt := Color.WHITE if i == ring.index else XSkinArt.bg_text_2()
		var cr := (_lum(txt) + 0.05) / (l90 + 0.05)
		if cr < (7.0 if i == ring.index else 4.5):
			worst.append([i, snappedf(cr, 0.01)])
	check("contrast_" + kind, worst.is_empty(), worst)


func _grab_hidden(page: XEquipScene) -> Image:
	var ring: XSkinRingNav = page.skin.ring
	ring.hide_labels = true
	ring.queue_redraw()
	await frames(2)
	var img := await _grab()
	ring.hide_labels = false
	ring.queue_redraw()
	await frames(2)
	return img


static func _red(c: Color) -> bool:
	return c.r8 >= XTianqiRingStyle.RED_R and c.g8 <= XTianqiRingStyle.RED_G and c.b8 <= XTianqiRingStyle.RED_B


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## 逐像素对照用：ENABLED 关、16:9、穿黑印 5 件＋毕业武器＋死亡遗物，停在第 0 栏，存一张
func _off_shot_only() -> void:
	get_window().size = SIZES[0][0]
	await frames(4)
	XTianqiRingStyle.ENABLED = false
	var page := await _build_equip()
	_loadout(page.actor(), "hei")
	page._cand_rev += 1
	page._refresh()
	await frames(6)
	var img := await _grab()
	check("off_shot_saved", img.save_png(off_shot) == OK)
	page.queue_free()
	await frames(3)


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e
