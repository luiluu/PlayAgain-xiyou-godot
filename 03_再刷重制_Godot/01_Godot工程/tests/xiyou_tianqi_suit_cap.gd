extends Node
## 天启篇套装同台上限（XTianqiSuits，T513 养成线二期 2A；设计仓《原版养成线重做方案 v0.3》第三节第 3 条）：
## 一、原版 3 件套＋原版 2 件套＋七印 2 件：取 3 件那套和七印（同件数七印优先），2 件原版套退；说明卡标「未生效」。
## 二、七印 5 件＋七印 3 件＋原版 3 件套：两套七印生效，原版退（31 层后自然让位）；七印 live_set_counts 留两印。
## 三、原版三套＋七印三印同时穿：只剩两套，被挤掉的七印效果（gear_effects 的 set:）也没了。
## 四、单件套不占名额、照旧生效。
## 五、开关关、西游档：全部生效（回到 T513 之前）。
## 返修（小A 核 T513）：同件数原版套装号大的优先（NEWER_FIRST，关掉回号小）；混合 1／多件套（101）的 1 件档不占名额、被挤只退多件档；
## 排序按生效件数（2 件套穿 3 件按 2）；不认识的印不进名额；掉率来源、殉印生命跟着退；真实装备页说明牌（XEquipScene＋新皮肤）和详情页的提示行。
## 套装件直接造实例（{equipment: {suits: [号]}}），七印件用 mark()；套装号从 EquipSuits 表按「最高一档件数」现挑。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(tianqi := true) -> XState:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


## 表里第一套「最高一档正好 top 件、最低一档 low 件」的套装号（跳过 skip 里的）
func _suit(top: int, low: int, skip: Array = []) -> int:
	var defs: Array = XDB.table("EquipSuits")
	for i in range(1, defs.size()):
		if defs[i] == null or skip.has(i) or defs[i].bonuses.is_empty():
			continue
		var hi := 0
		var lo := 999
		for b in defs[i].bonuses:
			hi = maxi(hi, int(b.requirePieces))
			lo = mini(lo, int(b.requirePieces))
		if hi == top and lo == low:
			return i
	return 0


func _piece(sid: int) -> Dictionary:
	return {"kind": "armor", "name": "测试套装件%d" % sid, "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3, "equipment": {"suits": [sid]}}


func _seal_piece(seal: String, part: String) -> Dictionary:
	var inst := {"kind": "armor", "name": "测试七印件", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3}
	XTianqiQiyinEffects.mark(inst, {"kind": "set", "seal": seal, "part": part, "true_seal": false})
	return inst


const PARTS := ["head", "body", "hands", "waist", "legs", "feet"]

## 穿上：suits {套装号: 件数}，seals {印: 件数}；装备格不够就往后加
func _wear(a: XActor, suits: Dictionary, seals: Dictionary) -> void:
	a.keep_unequippable = true
	var list := []
	for sid in suits:
		for i in int(suits[sid]):
			list.append(_piece(int(sid)))
	for seal in seals:
		for i in int(seals[seal]):
			list.append(_seal_piece(str(seal), PARTS[i % PARTS.size()]))
	for i in range(a.equips.size()):
		a.equips[i] = {}
	for i in range(list.size()):
		if i + 1 < a.equips.size():
			a.equips[i + 1] = list[i]
		else:
			a.equips.append(list[i])
	a.param_mark_dirty()
	a.param_refresh()


## 生效的原版套装号（按 XEquipSuits.active 的档反查）
func _live_suits(a: XActor) -> Array:
	var defs: Array = XDB.table("EquipSuits")
	var act := XEquipSuits.active(a)
	var out := []
	for sid in XEquipSuits.counts(a):
		for b in defs[int(sid)].bonuses:
			if act.any(func(x): return is_same(x, b)) and not out.has(int(sid)):
				out.append(int(sid))
	out.sort()
	return out


func _find(a: XActor, f: Callable) -> Dictionary:
	for e in a.equip_list():
		if f.call(e):
			return e
	return {}


## 表里第一套「有 1 件档、又有多件档」的混合套（101 哥布林脚趾）
func _mixed() -> int:
	var defs: Array = XDB.table("EquipSuits")
	for i in range(1, defs.size()):
		if defs[i] != null and not XTianqiSuits.single_piece(i) and XTianqiSuits._has_one(i) and XTianqiSuits._multi_low(i) >= 2:
			return i
	return 0


## 表里第一套没有 1 件档、带掉率（bResultPlus[2]）的套装，最高档不超过 5 件
func _drop_suit() -> int:
	var defs: Array = XDB.table("EquipSuits")
	for i in range(1, defs.size()):
		if defs[i] == null or XTianqiSuits._has_one(i) or XTianqiSuits._tiers(i).is_empty() or int(XTianqiSuits._tiers(i)[-1]) > 5:
			continue
		for b in defs[i].bonuses:
			var p: Array = b.get("bResultPlus", [])
			if p.size() > 2 and float(p[2]) != 0.0:
				return i
	return 0


## 真实装备页（XEquipScene，天启篇新皮肤）：选到被挤掉的件，说明牌第一节就是提示；选候选列表时不显示
func _page_card(a: XActor, piece: Dictionary) -> void:
	var page := XEquipScene.new()
	add_child(page)
	for i in 3:
		await get_tree().process_frame
	var sk = page.skin
	if not _check_ok("page_skin_built", sk != null):
		page.queue_free()
		return
	page._slot = a.equips.find(piece)
	page._refresh()
	await get_tree().process_frame
	var secs: Array = sk.card.sections
	_check("page_card_note", not secs.is_empty() and not (secs[0].get("rows", []) as Array).is_empty() and str(secs[0].rows[0].text) == XTianqiSuits.TEXT_CROWDED, secs.slice(0, 1))
	page.queue_free()
	await get_tree().process_frame


func _check_ok(name: String, ok: bool) -> bool:
	_check(name, ok)
	return ok


func _set_srcs(a: XActor) -> Array:
	var out := []
	for fx in XTianqiQiyinEffects.gear_effects(a):
		var src := str(fx.get("src", ""))
		if src.begins_with("set:"):
			var seal := src.get_slice(":", 1)
			if not out.has(seal):
				out.append(seal)
	out.sort()
	return out


func _run() -> void:
	XMessageBox.auto = true
	seed(20261125)
	XTianqiQiyinGear.reload_table()
	var s3 := _suit(3, 3)
	var s2 := _suit(2, 2)
	var s3b := _suit(3, 3, [s3])
	var s3c := _suit(3, 3, [s3, s3b])
	var s1 := _suit(1, 1)
	_check("fixture_suits", s3 > 0 and s2 > 0 and s3b > 0 and s3c > 0 and s1 > 0, [s3, s2, s3b, s3c, s1])
	_check("single_piece_flag", XTianqiSuits.single_piece(s1) and not XTianqiSuits.single_piece(s3))
	var seals: Array = XTianqiQiyinGear.seal_keys()
	_check("fixture_seals", seals.size() >= 3, seals)
	var h: String = seals[0]
	var m: String = seals[1]
	var g: String = seals[2]

	var s := _state()
	_check("tianqi_active", XTianqi.active(s) and XTianqiQiyinEffects.on())
	var a: XActor = s.actor(_ids()[0])

	# 一、原版 3＋原版 2＋七印 2
	_wear(a, {s3: 3, s2: 2}, {h: 2})
	_check("c1_suits", _live_suits(a) == [s3], _live_suits(a))
	_check("c1_seal_live", XTianqiQiyinEffects.live_set_counts(a).has(h), XTianqiQiyinEffects.live_set_counts(a))
	_check("c1_seal_fx", _set_srcs(a) == [h], _set_srcs(a))
	_check("c1_crowded_text", XTianqiSuits.crowded_out(a, s2) and not XTianqiSuits.crowded_out(a, s3))
	_check("c1_raw_counts_untouched", int(XEquipSuits.counts(a).get(s2, 0)) == 2 and int(XTianqiQiyinEffects.set_counts(a).get(h, 0)) == 2)

	# 二、七印 5＋七印 3＋原版 3：同 3 件七印优先，原版退
	_wear(a, {s3: 3}, {h: 5, m: 3})
	_check("c2_orig_out", _live_suits(a).is_empty(), _live_suits(a))
	var c2 := XTianqiQiyinEffects.live_set_counts(a)
	_check("c2_two_seals", c2.has(h) and c2.has(m) and c2.size() == 2, c2)
	_check("c2_crowded", XTianqiSuits.crowded_out(a, s3))

	# 三、原版三套 3 件＋七印三印各 2 件：取三套原版里号大的两套（件数 3 > 2；协调 11-25 定新套优先）
	_wear(a, {s3: 3, s3b: 3, s3c: 3}, {h: 2, m: 2, g: 2})
	var want := [s3, s3b, s3c]
	want.sort()
	_check("c3_two_orig_newer", _live_suits(a) == want.slice(1, 3), [_live_suits(a), want])
	XTianqiSuits.NEWER_FIRST = false
	_check("c3_older_when_off", _live_suits(a) == want.slice(0, 2), [_live_suits(a), want])
	XTianqiSuits.NEWER_FIRST = true
	_check("c3_no_seal_fx", _set_srcs(a).is_empty(), _set_srcs(a))
	_check("c3_seal_rank_tie", XTianqiSuits.live(a).seals.is_empty())

	# 四、单件套不占名额
	_wear(a, {s3: 3, s1: 1}, {h: 3})
	_check("c4_single_kept", _live_suits(a).has(s1) and _live_suits(a).has(s3), _live_suits(a))
	_check("c4_seal_kept", _set_srcs(a) == [h], _set_srcs(a))

	# 返修 P2-1④：2 件套穿 3 件按 2 算，与 2 件七印同件数时七印优先
	_wear(a, {s3: 3, s2: 3}, {h: 2})
	_check("overflow_capped", _live_suits(a) == [s3] and XTianqiSuits.live(a).seals == [h], XTianqiSuits.live(a))
	# 返修 P3-1：不认识的印不进名额
	_check("unknown_seal_skipped", XTianqiSuits.ranked({}, {"zzz": 3}).is_empty())
	# 返修 P2-2：混合套（1 件档＋多件档）
	var mx := _mixed()
	_check("fixture_mixed", mx > 0, mx)
	if mx > 0:
		var top := int(XTianqiSuits._tiers(mx)[-1])
		_wear(a, {s3: 3, s3b: 3, mx: 1}, {})
		_check("mixed_one_free", _live_suits(a).has(mx) and _live_suits(a).size() == 3, _live_suits(a))
		_wear(a, {mx: top}, {h: 5, m: 5})
		var mine: Array = XDB.table("EquipSuits")[mx].bonuses
		var tiers_on := XEquipSuits.active(a).filter(func(b): return mine.any(func(x): return is_same(x, b))).map(func(b): return int(b.requirePieces))
		_check("mixed_crowded_keeps_one", tiers_on == [1], tiers_on)
		_check("mixed_crowded_flag", XTianqiSuits.crowded_out(a, mx))
	# 返修 P3-4：掉率来源跟着退
	var ds := _drop_suit()
	if ds > 0:
		_wear(a, {ds: int(XTianqiSuits._tiers(ds)[-1])}, {h: 5, m: 5})
		var srcs := XTianqiDrop.sources_of(a).filter(func(x): return str(x.name) == "套装")
		_check("drop_source_gone", srcs.is_empty() and XTianqiSuits.crowded_out(a, ds), srcs)
		XTianqiSuits.ENABLED = false
		_check("drop_source_back_off", not XTianqiDrop.sources_of(a).filter(func(x): return str(x.name) == "套装").is_empty())
		XTianqiSuits.ENABLED = true
	# 殉印 2 件生命：挤掉就没了
	_wear(a, {s3: 3, s3b: 3}, {"xun": 2})
	_check("xun_hp_gone", XTianqiQiyinEffects.param_rate(a, 0) == 1.0 and XTianqiSuits.seal_crowded_out(a, "xun"))
	_wear(a, {s3: 3}, {"xun": 2})
	_check("xun_hp_live", XTianqiQiyinEffects.param_rate(a, 0) > 1.0)
	# 说明牌提示：原版件、七印件
	_wear(a, {s3: 3, s2: 2}, {h: 2})
	var crowded_piece := _find(a, func(e): return e.get("equipment", {}).get("suits", []).has(s2))
	var live_piece := _find(a, func(e): return e.get("equipment", {}).get("suits", []).has(s3))
	_check("note_orig", XTianqiSuits.note(a, crowded_piece) == XTianqiSuits.TEXT_CROWDED and XTianqiSuits.note(a, live_piece) == "")
	_wear(a, {s3: 3, s3b: 3}, {h: 2})
	var seal_piece := _find(a, func(e): return str(XTianqiQiyinEffects.mark_of(e).get("seal", "")) == h)
	_check("note_seal", XTianqiSuits.note(a, seal_piece) == XTianqiSuits.TEXT_CROWDED)
	var gd := XSkinGearDetail.new()
	gd.set_data(seal_piece, a, null, false)
	_check("detail_row", not gd._rows.is_empty() and str(gd._rows[0].text) == XTianqiSuits.TEXT_CROWDED, gd._rows.slice(0, 1))
	gd.set_data(seal_piece, a, null, true)
	_check("detail_row_not_in_compare", gd._rows.is_empty() or str(gd._rows[0].text) != XTianqiSuits.TEXT_CROWDED)
	gd.free()
	await _page_card(a, seal_piece)

	# 五、开关关：全部生效
	_wear(a, {s3: 3, s2: 2}, {h: 5, m: 3})
	_check("on_cap", _live_suits(a).is_empty())
	XTianqiSuits.ENABLED = false
	_check("off_all_suits", _live_suits(a) == ([s3, s2] if s3 < s2 else [s2, s3]), _live_suits(a))
	_check("off_all_seals", XTianqiQiyinEffects.live_set_counts(a).size() == 2)
	_check("off_no_crowded", not XTianqiSuits.crowded_out(a, s3))
	XTianqiSuits.ENABLED = true

	# 西游档：原版三套全生效
	var x := _state(false)
	_check("xiyou_inactive", not XTianqi.active(x))
	var b: XActor = x.actor(_ids()[0])
	_wear(b, {s3: 3, s3b: 3, s3c: 3}, {})
	_check("xiyou_all_suits", _live_suits(b) == want, _live_suits(b))
	_check("xiyou_live_empty", XTianqiSuits.live(b).is_empty())

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
