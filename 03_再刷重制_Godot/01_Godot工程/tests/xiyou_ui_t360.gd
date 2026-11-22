extends Node
## T360 专项：属性分色（D250 属性名统一次要色、只数值着色、冒号统一＋冒号后空格、攻击/暴击避开警示橙红）、
## 战技不能用的原因（F-16：物品分场合／库存、七印分万籁俱寂／寂静／限时）、副标题省略号（F-10）、
## 说明卡浮层（F-11：XHelpCard 按节画的 XSkinCard 标浮层）、DETAIL_V1=false 真回退。
var results := []


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	XSave.dir_override = "user://test_xiyou_ui_t360"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	XUiSkin.FORCE = true
	XUiSkin.DETAIL_V1 = true
	_stats_on()
	_stats_off()
	_reason_basic()
	_reason_logic()
	_float_card()
	XUiSkin.DETAIL_V1 = true
	XTianqiQiyin.rng_override = null
	var passed := 0
	for x in results:
		if x.passed:
			passed += 1
		else:
			printerr("FAIL ", x.name, " ", x.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _join(sp: Array) -> String:
	var t := ""
	for s in sp:
		t += str(s[0])
	return t


## 色相差（环形，0～0.5）
func _hue_d(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d)


## 「避开」：饱和度比警示色低一大截（≥0.25），或色相差够远（>0.04）——两条都看，不是 s<0.4 就算
func _avoid(a: Color, warn: Color) -> bool:
	return a.s < 0.4 and (warn.s - a.s >= 0.25 or _hue_d(a, warn) > 0.04)


func _stats_on() -> void:
	XUiSkin.DETAIL_V1 = true
	var base := Color("a8aaaf")
	var r := XSkinTemplatePage.with_stat_spans({"text": "攻击:+12", "color": base})
	_check("stat_colon_unified", str(r.text) == "攻击：+12", r.text)
	var sp: Array = r.spans
	_check("stat_name_text2", sp.size() == 3 and sp[0][1] == XUiSkin.TEXT_2 and sp[1][1] == XUiSkin.TEXT_2, sp)
	_check("stat_value_colored", sp.size() == 3 and sp[2][1] == XSkinTemplatePage.stat_color("攻击") and str(sp[2][0]) == "+12", sp)
	_check("stat_spans_join_text", _join(sp) == r.text, _join(sp))
	# 行本色是亮白、淡金（幸运）时属性名也统一次要色（核报告 P1-4）
	for c in [XUiSkin.TEXT, XUiSkin.GOLD_LIGHT]:
		var rl := XSkinTemplatePage.with_stat_spans({"text": "幸运：+8", "color": c})
		_check("stat_name_text2_from_%s" % c.to_html(false), rl.spans[0][1] == XUiSkin.TEXT_2 and rl.spans[2][1] != XUiSkin.TEXT_2, rl.spans)
	# 冒号后带空格（核报告 P2-1）
	var rs := XSkinTemplatePage.with_stat_spans({"text": "最大生命值: 379  攻击：　+12", "color": base})
	_check("stat_colon_space", str(rs.text) == "最大生命值：379  攻击：+12", rs.text)
	_check("stat_colon_space_value", rs.get("spans", []).any(func(s): return str(s[0]) == "379" and s[1] == XSkinTemplatePage.stat_color("生命")), rs.get("spans"))
	var r2 := XSkinTemplatePage.with_stat_spans({"text": "暴击+5%  生命：100", "color": base})
	_check("stat_no_colon_form", str(r2.spans[0][0]) == "暴击" and r2.spans[0][1] == XUiSkin.TEXT_2 and str(r2.spans[1][0]) == "+5%", r2.spans)
	var unk := {"text": "说明这是一句话", "color": base}
	_check("stat_unknown_untouched", XSkinTemplatePage.with_stat_spans(unk) == unk)
	var hit_rate := XSkinTemplatePage.with_stat_spans({"text": "命中率+5%", "color": XUiSkin.TEXT})
	_check("stat_uncolored_name_text2", hit_rate.spans[0][1] == XUiSkin.TEXT_2 and hit_rate.spans[1][1] == XUiSkin.TEXT, hit_rate.get("spans"))
	var atk: Color = XSkinTemplatePage.stat_color("攻击")
	var cri: Color = XSkinTemplatePage.stat_color("暴击")
	_check("stat_attack_avoid_down", _avoid(atk, XUiSkin.DOWN), [atk.s, XUiSkin.DOWN.s, _hue_d(atk, XUiSkin.DOWN)])
	_check("stat_crit_avoid_sel", _avoid(cri, XUiSkin.SEL_LINE), [cri.s, XUiSkin.SEL_LINE.s, _hue_d(cri, XUiSkin.SEL_LINE)])
	var all_low := true
	for pair in XSkinTemplatePage.STAT_COLORS:
		all_low = all_low and (pair[1] as Color).s < 0.4
	_check("stat_desaturated_all", all_low)
	var f := XUiSkin.font("body")
	var fit := XSkinList.fit_text(f, "白印 · 七印套装 · 真印 · 神话（神话特效很长很长很长很长很长很长）", 120.0, 15, 15)
	_check("subtitle_ellipsis", str(fit[0]).ends_with("…"), fit[0])


## DETAIL_V1=false：属性整段旧色、文字不改、兜底原因照旧
func _stats_off() -> void:
	XUiSkin.DETAIL_V1 = false
	var base := Color("a8aaaf")
	var r := XSkinTemplatePage.with_stat_spans({"text": "攻击:+12  最大生命值: 379", "color": base})
	_check("off_text_unchanged", str(r.text) == "攻击:+12  最大生命值: 379", r.text)
	_check("off_whole_chunk_old_color", str(r.spans[0][0]) == "攻击:+12" and r.spans[0][1] == Color("ff9b5e"), r.spans)
	_check("off_stat_color_old", XSkinTemplatePage.stat_color("生命") == Color("7fd67a"))
	_check("off_reason_legacy", XSkinBattle.reason(null, null, {}, false) == "现在不能用")
	XUiSkin.DETAIL_V1 = true


func _reason_basic() -> void:
	_check("reason_fallback_new", XSkinBattle.reason(null, null, {}, false) == "当前条件不满足")
	for t in [XSkinBattle.T_REASON_SILENCED, XSkinBattle.T_REASON_SILENCE_USED, XSkinBattle.T_REASON_QIYIN_SILENT, XSkinBattle.T_REASON_QIYIN_EXAM,
			XSkinBattle.T_REASON_WTYPE, XSkinBattle.T_REASON_ITEM_OCCASION, XSkinBattle.T_REASON_ITEM_EMPTY, XSkinBattle.T_REASON_FALLBACK]:
		_check("reason_short_%s" % t, t.length() <= 14 and not t.contains("！") and not t.ends_with("。"), t.length())
	var f := XUiSkin.font("body")
	var w := f.get_string_size(XSkinBattle.T_REASON_QIYIN_SILENT, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(XUiSkin.FS_AUX)).x
	_check("reason_fits_298", w <= 298.0, w)


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _wear_mo(a: XActor, n: int) -> void:
	a.keep_unequippable = true
	var parts := ["head", "body", "hands", "waist", "legs", "feet"]
	for i in n:
		var inst := XGear.create("armor", 1, XState.current)
		if inst.is_empty():
			inst = {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3}
		XTianqiQiyinEffects.mark(inst, {"kind": "set", "seal": "mo", "part": parts[i], "true_seal": false})
		a.equips.append(inst)
	a.param_mark_dirty()
	a.param_refresh()


## 真战斗：物品按场合／库存分开报；万籁俱寂用完报次数、没穿满不报七印规则；七印寂静／限时各报各的
func _reason_logic() -> void:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, 36)
	XState.current = s
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	var lg := XBattleLogic.new()
	lg.setup(33, s)
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	# 物品
	var menu_only := {"id": 1, "occasion": 2, "itypeId": 1}
	s.items[1] = 3
	_check("item_menu_only_blocked", not lg.can_use(a, menu_only))
	_check("item_menu_only_reason", XSkinBattle.reason(lg, a, menu_only, true) == "战斗中无法使用", XSkinBattle.reason(lg, a, menu_only, true))
	var gone := {"id": 1, "occasion": 0, "itypeId": 1}
	s.items.erase(1)
	_check("item_empty_reason", XSkinBattle.reason(lg, a, gone, true) == "物品已用完", XSkinBattle.reason(lg, a, gone, true))
	# 万籁俱寂
	_wear_mo(a, 5)
	XTianqiQiyinEffects.start(lg)
	var sil := XDB.rec("Skills", int(XTianqiQiyinEffects.TUNE.silence_skill_id))
	_check("silence_usable_first", lg.can_use(a, sil))
	XTianqiQiyinEffects._unit(lg, a).silence_used = 99
	_check("silence_used_up", XSkinBattle.qiyin_reason(lg, a, sil) == "本场次数已用完", XSkinBattle.qiyin_reason(lg, a, sil))
	_check("silence_not_worn_fallback", XSkinBattle.qiyin_reason(lg, b, sil) == "当前条件不满足", XSkinBattle.qiyin_reason(lg, b, sil))
	_check("silence_not_rule_text", not XSkinBattle.qiyin_reason(lg, a, sil).contains("七印"))
	# 七印祭坛规则：寂静／限时
	var sk := {"id": 99999, "occasion": 0}
	_check("qiyin_none", XSkinBattle.qiyin_reason(lg, b, sk) == "", XSkinBattle.qiyin_reason(lg, b, sk))
	lg.set_meta(XTianqiQiyinRule.META, {"rule": "", "silent": true, "skills_used": 0, "queue": [], "side_bonus": ""})
	_check("qiyin_silent", XSkinBattle.qiyin_reason(lg, b, sk) == "寂静回合，无法使用技能", XSkinBattle.qiyin_reason(lg, b, sk))
	lg.set_meta(XTianqiQiyinRule.META, {"rule": "exam", "silent": false, "skills_used": 99, "queue": [], "side_bonus": ""})
	_check("qiyin_exam", XSkinBattle.qiyin_reason(lg, b, sk) == "本回合技能次数已满", XSkinBattle.qiyin_reason(lg, b, sk))
	lg.remove_meta(XTianqiQiyinRule.META)
	lg.end_battle(0)


## F-11：XHelpCard 按节画时那张 XSkinCard 标成浮层（画 S3 实底）；常规 XSkinCard 不标
func _float_card() -> void:
	var plain := XSkinCard.new()
	_check("card_default_not_float", not plain.floating_s3)
	plain.free()
	var src := FileAccess.get_file_as_string("res://modes/xiyou/ui/help_card.gd")
	_check("help_card_sets_float", src.contains("skin_card.floating_s3 = true"))
	_check("float_s3_tex", XSkinConfirm.s3_panel_tex() != null)
