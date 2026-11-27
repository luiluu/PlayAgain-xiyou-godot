extends Node
const Kit := preload("res://tests/lib/tq_save_kit.gd")
## 原版文字错的加载时修正（XTextFix，乙类文字审 xa_text-audit-b）专项：
## 一、六个开关默认开；覆盖表每条都套上（warnings 为空）。
## 二、每条统一规则抽样：零宽、名字框、成对标点、词典、繁简；规则不碰的（notetag、公式、梗）保持原样。
## 三、逐条覆盖抽样；原文对不上的条目不套用、记进 warnings。
## 四、开关全关回原版：读出的表与 generated 原文件逐字相同。
## 五、「超级Boos」改成「超级Boss」后（西游档；天启篇档再改【霸主】见 _d126），真气突破的首领判定（XZhenqi.is_boss_enemy）照旧认。
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _rec(table: String, id: int) -> Dictionary:
	return XDB.table(table)[id]


func _cmd(map_id: int, ev: int, page: int, cmd: int):
	return XDB.map(map_id).events[ev].pages[page].list[cmd].parameters[0]


func _pos_texts(note: String) -> Array:
	var re := RegEx.create_from_string("<pos=\\S+\\s+text=([\\s\\S]*?)\\s+size=")
	return re.search_all(note).map(func(m): return m.get_string(1))


func _run() -> void:
	XMessageBox.auto = true
	_check("defaults", XTextFix.STRIP_ZW and XTextFix.NAMEBOX and XTextFix.PAIRS and XTextFix.DICT and XTextFix.TRAD and XTextFix.OVERRIDES)
	XTextFix.set_all(true)
	XTextFix.warnings.clear()
	# 读一遍覆盖表涉及的全部表与地图，覆盖表每条都应套上
	for key in XTextFix.overrides():
		if str(key).begins_with("Map"):
			XDB.map(int(str(key).substr(3)))
		else:
			XDB.table(key)
	_check("overrides_all_applied", XTextFix.warnings.is_empty(), XTextFix.warnings)
	_check("overrides_count", XTextFix.overrides().values().reduce(func(a, b): return a + b.size(), 0) >= 70)

	# 二、统一规则
	_check("zw_state_name", _rec("States", 1157).name == "即兴碎拨", _rec("States", 1157).name)
	_check("zw_item_quote", _pos_texts(_rec("Items", 1642).note).has("\\c[1]效果:使用后学会被动技能 ‘时之主宰’"), _pos_texts(_rec("Items", 1642).note))
	var ce1441 := JSON.stringify(_rec("CommonEvents", 1441).list)
	_check("zw_ce1441", not ce1441.contains("﻿") and ce1441.contains("再动+5，再释放+100%"))
	_check("namebox_lead", str(_cmd(8, 7, 0, 1)).begins_with("\\n<副本协会主席>"), _cmd(8, 7, 0, 1))
	_check("guide_currency_unit", str(_cmd(4, 73, 0, 8)).contains("\\c[4]精魂\\c[0]：阿卡拉") and str(_cmd(4, 73, 0, 24)).contains("炼器师（精魂）") and not str(_cmd(4, 73, 0, 8)).contains("金币"), [_cmd(4, 73, 0, 8), _cmd(4, 73, 0, 24)])
	_check("namebox_slash", str(_cmd(4, 36, 0, 175)) == "\\n<天才灵魂>此塔是我开，此塔是我栽，要想从这过留下买路财~！", _cmd(4, 36, 0, 175))
	_check("namebox_cesc", str(_cmd(71, 22, 0, 5)).contains("\\c[4]蛊雕") and not str(_cmd(71, 22, 0, 5)).contains("\\c\\["))
	_check("namebox_lone_n", str(_cmd(121, 1, 4, 35)) == "是否前往孽镜深渊？", _cmd(121, 1, 4, 35))
	_check("namebox_override", str(_cmd(144, 2, 1, 5)) == "\\n<太上老君藏身处>" and str(_cmd(4, 7, 1, 21)).begins_with("\\n<大工匠>\\c[4]"))
	_check("namebox_shows_name", XText.to_bb(str(_cmd(217, 11, 0, 1))).name == "作坊小妹", XText.to_bb(str(_cmd(217, 11, 0, 1))))
	var wordwrap := 0
	for ev in XDB.map(4).events:
		if ev is Dictionary:
			for p in ev.pages:
				for c in p.list:
					if int(c.code) == 401 and str(c.parameters[0]).begins_with("<WordWrap>"):
						wordwrap += 1
					if int(c.code) == 401 and str(c.parameters[0]).begins_with("\\n<WordWrap>"):
						wordwrap -= 1000
	_check("namebox_skip_wordwrap", wordwrap >= 0, wordwrap)
	_check("pairs_quotes", _pos_texts(_rec("Items", 2231).note).has("\\c[1]效果:使用后学会被动技能 ‘玄天功·入门’") and _pos_texts(_rec("Weapons", 1641).note)[0].contains("“凌波舞”"))
	_check("pairs_brackets", _rec("Enemies", 858).name == "【超级Boss】龙之祖（天龙）" and _pos_texts(_rec("Weapons", 1708).note).any(func(t): return t.begins_with("\\c[1]特效:逆伤（") and t.ends_with("持续3回合）")))
	_check("pairs_unbalanced_left", _pos_texts(_rec("Skills", 10111).note).any(func(t): return t.contains("三教极元分（天，地，人）")))
	_check("dict_terms", _rec("Skills", 7765).name == "终极奥术伤" and _rec("EquipSuits", 164).name == "奥术璀璨" and _rec("States", 297).name == "奥术导能", [_rec("Skills", 7765).name])
	_check("dict_joke_kept", str(_rec("Skills", 8036).description).contains("奥术还是奥数"))
	_check("dict_map", str(_cmd(3, 7, 0, 3)).contains("挑战符文") or JSON.stringify(XDB.map(3).events[7]).contains("初级副本挑战符文"))
	_check("dict_regex_x18", _pos_texts(_rec("Skills", 373).note).has("\\c[1]基础伤害：3550+己·物理攻击x18；防御按攻防比例结算"))
	_check("dict_dedupe", _pos_texts(_rec("Items", 1726).note).has("\\c[1]效果:食用后最大生命+10"), _pos_texts(_rec("Items", 1726).note))
	_check("trad", _rec("MapInfos", 206).name == "宫殿" and _rec("Enemies", 676).name == "【蛮荒大妖】竹箧")
	var raw_skills = XDB.parse_file(XDB.BASE + "db/Skills.json")
	var s373: Dictionary = _rec("Skills", 373)
	_check("note_tags_kept", Array(s373.note.split("\n")).filter(func(l): return not l.begins_with("<pos=")) == Array(raw_skills[373].note.split("\n")).filter(func(l): return not l.begins_with("<pos=")))
	_check("formula_kept", JSON.stringify(s373.damage) == JSON.stringify(raw_skills[373].damage) and JSON.stringify(s373.get("meta")) == JSON.stringify(raw_skills[373].get("meta")))
	_check("pos_line_shape", _rec("Skills", 373).note.count("<pos=") == raw_skills[373].note.count("<pos=") and _rec("Skills", 373).note.count(" size=") == raw_skills[373].note.count(" size="))

	# 三、逐条覆盖
	_check("ov_pet_swap", str(_rec("Skills", 1481).description).ends_with("一种增强型宠物技能，只会给指定角色共享该技能") and str(_rec("Skills", 1488).description).ends_with("一种共享型宠物技能，所有友方都会得到加成"))
	_check("ov_line_removed", not _rec("Weapons", 68).note.contains("特效:???") and _rec("Weapons", 68).note.count("<pos=") == raw_count("Weapons", 68) - 1,
		[_rec("Weapons", 68).note.count("<pos="), raw_count("Weapons", 68)])
	_check("ov_map186", JSON.stringify(XDB.map(186).events[27]).count("兽人元帅\\\\c[0]，咬牙切齿") == 3)
	_check("ov_565_current_mp", _pos_texts(_rec("Skills", 565).note).has("\\c[1]基础伤害：（5000+己·魔法攻击x30）*（1+当前蓝量/（最大蓝量*0.002））；防御按攻防比例结算"), _pos_texts(_rec("Skills", 565).note))
	_check("ov_1615_kept", _rec("Armors", 1615).name == "奇拉美魔皮护手" and _rec("Armors", 1615).note.contains("奇拉美之力"))
	var probe := [null, {"id": 1, "name": "甲乙"}]
	var before := XTextFix.warnings.size()
	XTextFix._apply_override({"at": "Probe:1/name", "from": "丙", "to": "丁", "ref": "test"}, probe, "Probe")
	_check("ov_mismatch_warns", XTextFix.warnings.size() == before + 1 and probe[1].name == "甲乙")
	XTextFix._apply_override({"at": "Probe:1/name", "from": "甲", "to": "丁", "count": 2, "ref": "test"}, probe, "Probe")
	_check("ov_count_mismatch", XTextFix.warnings.size() == before + 2 and probe[1].name == "甲乙")
	XTextFix.warnings.resize(before)

	# 修正结果走解析缓存：读两次（第二次命中缓存）都与现算的一致
	var fresh = XDB.load_json("db/Items.json")
	XTextFix.patch_table("Items", fresh)
	XDB._tables.erase("Items")
	var first := JSON.stringify(XDB.table("Items"))
	XDB._tables.erase("Items")
	_check("cache_roundtrip", first == JSON.stringify(fresh) and JSON.stringify(XDB.table("Items")) == first)

	# 五、名字改了首领判定照旧
	_check("boss_name_rule", _rec("Enemies", 850).name == "【超级Boss】瑞丁" and XZhenqi.is_boss_enemy(XEnemy.new().setup(850, 1, 100.0)))
	_d126()
	_d294()
	_t562_r2()

	# 六、逐个开关单独关掉，只回退那一类（其余照旧修）
	XTextFix.set_all(true)
	XTextFix.STRIP_ZW = false
	XTextFix.clear_cache()
	_check("off_zw_only", _rec("States", 1157).name == "即兴碎拨\ufeff" and _rec("Skills", 7765).name == "终极奥术伤")
	XTextFix.set_all(true)
	XTextFix.NAMEBOX = false
	XTextFix.clear_cache()
	_check("off_namebox_only", str(_cmd(8, 7, 0, 1)).begins_with("<副本协会主席>") and str(_cmd(4, 36, 0, 175)).begins_with("/n<天才灵魂>此塔是我开，此塔"))
	XTextFix.set_all(true)
	XTextFix.PAIRS = false
	XTextFix.clear_cache()
	_check("off_pairs_only", _rec("Enemies", 858).name == "【超级Boss】龙之祖(天龙）")
	XTextFix.set_all(true)
	XTextFix.DICT = false
	XTextFix.clear_cache()
	_check("off_dict_only", _rec("Skills", 7765).name == "终级奥数伤" and _rec("MapInfos", 206).name == "宫殿")
	XTextFix.set_all(true)
	XTextFix.TRAD = false
	XTextFix.clear_cache()
	_check("off_trad_only", _rec("MapInfos", 206).name == "宮殿" and _rec("Skills", 7765).name == "终极奥术伤")
	XTextFix.set_all(true)
	XTextFix.OVERRIDES = false
	XTextFix.clear_cache()
	_check("off_overrides_only", str(_rec("Skills", 1481).description).ends_with("一种共享型宠物技能，所有友方都会得到加成") and _rec("States", 1157).name == "即兴碎拨")

	# 四、全关回原版
	XTextFix.set_all(false)
	_check("off_enemies_raw", JSON.stringify(XDB.table("Enemies")) == JSON.stringify(XDB.parse_file(XDB.BASE + "db/Enemies.json")))
	_check("off_skill_raw", JSON.stringify(_rec("Skills", 7765)) == JSON.stringify(XDB.parse_file(XDB.BASE + "db/Skills.json")[7765]))
	_check("off_map_raw", JSON.stringify(XDB.map(71)) == JSON.stringify(XDB.parse_file(XDB.BASE + "maps/Map071.json")))
	_check("off_name", _rec("Enemies", 850).name == "【超级Boos】瑞丁" and XZhenqi.is_boss_enemy(XEnemy.new().setup(850, 1, 100.0)))
	XTextFix.set_all(true)

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func raw_count(table: String, id: int) -> int:
	return str(XDB.parse_file(XDB.BASE + "db/%s.json" % table)[id].note).count("<pos=")


## D126（Kyo 11-16）：【超级Boss】→【霸主】、【DOTABOSS】→【远古首领】、天道使者→见证使者、天道币→晨星币
## 只在天启篇存档套用（rules.json tianqi_dict），西游档 1:1 原貌；换档（sync_mode）清缓存重读。
func _d126() -> void:
	var supers := [850, 858, 859, 860, 868, 869, 870, 938, 960, 961]
	var tq_state := Kit.new_game("jiusi")  # 天启篇档（Kit 内 XState.current 与 sync_mode 都到位）
	_check("d126_tq_mode_on", XTextFix.tq_on())
	var bad := []
	for id in supers:
		var n := str(_rec("Enemies", id).name)
		if not n.begins_with("【霸主】") or not XZhenqi.is_boss_enemy(XEnemy.new().setup(id, 1, 100.0)):
			bad.append([id, n])
	_check("d126_super_enemies", bad.is_empty(), bad)
	var troops := []
	for id in [739, 830, 831]:
		if not str(_rec("Troops", id).name).begins_with("【霸主】"):
			troops.append(id)
	_check("d126_super_troops", troops.is_empty(), troops)
	_check("d126_dota", _rec("Enemies", 2027).name == "【远古首领】ROSHAN" and _rec("Troops", 2029).name == "【远古首领】肉山宝宝", [_rec("Enemies", 2027).name, _rec("Troops", 2029).name])
	# 【霸主】单独也认首领；旧前缀照旧认；【远古首领】（原 DOTABOSS）照旧不认
	var probe := XEnemy.new().setup(850, 1, 100.0)
	var ok := true
	for pre in ["霸主", "超级Boos", "超级Boss"]:
		probe.horseman = {"rec": {"id": 999999, "name": "【%s】测试" % pre, "note": ""}}
		ok = ok and XZhenqi.is_boss_enemy(probe)
	probe.horseman = {"rec": {"id": 999999, "name": "【远古首领】测试", "note": ""}}
	# 原【DOTABOSS】本来不按名认首领（对照参照），改名后行为不变
	_check("d126_prefix_regex", ok and not XZhenqi.is_boss_enemy(probe) and not XZhenqi.is_boss_enemy(XEnemy.new().setup(2027, 1, 100.0)))
	_check("d126_names", _rec("Enemies", 871).name == "见证使者" and _rec("Items", 2451).name == "晨星币", [_rec("Enemies", 871).name, _rec("Items", 2451).name])
	# 18 层讨债台词不改：XTianqiSect.rewrite_message 按「天道使者」原文认它
	_check("d126_map046_line_kept", _map046_has("<天道使者>嘿嘿，你居然打过了深渊骑士"))
	# 天启篇开关：XTextFix.DICT 关了词典（含天启篇词典）一起回原貌
	XTextFix.DICT = false
	XTextFix.clear_cache()
	_check("d126_dict_off", _rec("Enemies", 871).name == "天道使者", _rec("Enemies", 871).name)
	XTextFix.DICT = true
	XTextFix.clear_cache()
	# 换成西游档：同一进程内切档清缓存，名字回原貌（天道使者／天道币／【超级Boss】／【DOTABOSS】），Map046 同样原貌
	var plain := XState.new_game_blank()
	XState.current = plain
	XTextFix.sync_mode()
	_check("d126_plain_mode_off", not XTextFix.tq_on())
	var raw_bad := []
	for id in supers:
		if not str(_rec("Enemies", id).name).begins_with("【超级Boss】"):
			raw_bad.append([id, _rec("Enemies", id).name])
	_check("d126_plain_super_kept", raw_bad.is_empty(), raw_bad)
	_check("d126_plain_names", _rec("Enemies", 871).name == "天道使者" and _rec("Items", 2451).name == "天道币" and _rec("Enemies", 2027).name == "【DOTABOSS】ROSHAN" and _rec("Troops", 747).name == "天道使者", [_rec("Enemies", 871).name, _rec("Items", 2451).name])
	_check("d126_plain_map046", _map046_has("<天道使者>嘿嘿，你居然打过了深渊骑士"))
	_check("d126_plain_boss_rule", XZhenqi.is_boss_enemy(XEnemy.new().setup(850, 1, 100.0)))
	# 磁盘缓存按模式位隔离：回天启篇再读，仍是天启篇口径（不被西游档缓存污染）
	XState.current = tq_state
	XTextFix.sync_mode()
	_check("d126_switch_back", _rec("Enemies", 871).name == "见证使者" and _rec("Enemies", 850).name.begins_with("【霸主】"))
	var heaven: Array = XTestMode.RESOURCES.filter(func(r): return r[0] == "heaven")[0]
	_check("d126_test_mode_label", XTestMode.resource_name(tq_state, heaven) == "晨星币" and XTestMode.resource_name(plain, heaven) == "天道币")
	XState.current = plain
	XTextFix.sync_mode()
	_check("d126_switch_again", _rec("Enemies", 871).name == "天道使者")


func _map046_has(needle: String) -> bool:
	for c in XDB.map(46).events[1].pages[0].list:
		if int(c.code) == 401 and str(c.parameters[0]).contains(needle):
			return true
	return false


func _d294() -> void:
	var raw: Array = XDB.load_json("db/Actors.json")
	var names: Dictionary = XTextFix.actor_names().get("names", {})
	var original := {}
	var before := _d294_other_texts()
	for id in names:
		if int(id) != XGojo.ACTOR:
			original[id] = XActorBook.actor_name(int(id))
	var legacy := XState.current
	var tq := Kit.new_game("jiusi")
	var bad := []
	for id in names:
		var aid := int(id)
		var expected := str(names[id])
		if str(_rec("Actors", aid).name) != expected or XActorBook.actor_name(aid) != expected or str(XSkinBookPage.actor_info(aid).name) != expected:
			bad.append(id)
	_check("d294_tq_table_and_both_actor_books", names.size() == 57 and bad.is_empty(), bad)
	_check("d294_approved_examples", XActorBook.actor_name(85) == "粉红妖精" and XActorBook.actor_name(127) == "我们的光" and XActorBook.actor_name(180) == "5t5")
	var a := tq.actor(91)
	a.set_looks({"name": "宇智波鼬"})
	_check("d294_old_save_name_view", a.display_name() == "一打七" and a.looks.name == "宇智波鼬")
	a.set_looks({"name": "自订名字"})
	_check("d294_custom_name", a.display_name() == "自订名字")
	_check("d294_class_talent_horn", _rec("Classes", 167).name == "路痴刀客" and str(XDB.system().skillTypes[10]) == "银发小魔导被动"
		and XSkinSkillPage.glyph_of(XDB.system().skillTypes[10]) == "专" and _rec("Items", 2931).name == "伙伴号角：路痴刀客")
	_check("d294_skills_materials_and_relic", XDB.rec("Skills", 2618).name == "觉醒:熊猫酒仙"
		and XDB.rec("Skills", 10737).name == "剑*狂千年·一线" and _rec("Items", 2935).name == "爹咪进阶石" and str(_rec("Armors", 4578).note).contains("专属:路痴刀客"))
	_check("d294_costume_entry", _rec("Skills", 6820).name == "变身——闪光剑姬" and _d294_clothes(-75) == "我们的光")
	var ryoma := XTextFix.actor_name(57, "龙马") + "复活术"
	var w2003 := str(_rec("Weapons", 2003).note)
	_check("d294_unique_tag_follows_effect_line", w2003.contains("“%s”" % ryoma) and w2003.contains("<KyoUnique: %s>" % ryoma)
		and _rec("Skills", 6240).name == ryoma, w2003.right(80))
	var vegeta := XTextFix.actor_name(164, "贝吉特")
	_check("d294_vegeta_forms_no_double_prefix", [10563, 10564, 10565, 10566].map(func(i): return str(XDB.rec("Skills", i).name))
		== [vegeta, vegeta + "2", vegeta + "3", vegeta + "蓝"], [10563, 10564, 10565, 10566].map(func(i): return str(XDB.rec("Skills", i).name)))
	_check("d294_kotori_form_toasts", str(_rec("CommonEvents", 1710).list[0].parameters[0]).contains(XTextFix.actor_name(159, "") + "切换炮形态")
		and str(_rec("CommonEvents", 1711).list[0].parameters[0]).contains(XTextFix.actor_name(159, "") + "切换斧形态"))
	_check("d294_event_exact_positions", str(_cmd(4, 71, 0, 109)[2]) == "路痴刀客"
		and str(_rec("CommonEvents", 1511).list[9].parameters[1]) == "一打七")
	_check("d294_homographs_and_independent_skins", _d294_other_texts() == before, _d294_other_texts())
	XState._become_current(legacy)
	bad.clear()
	for id in original:
		var aid := int(id)
		if XActorBook.actor_name(aid) != original[id] or str(raw[aid].name) != original[id]:
			bad.append(id)
	_check("d294_legacy_keeps_56_source_actor_names", original.size() == 56 and bad.is_empty() and XGojo.hidden(XGojo.ACTOR), bad)
	_check("d294_legacy_class_skill_wardrobe", XDB.system().skillTypes[10] == "伊莉雅被动" and _rec("Classes", 167).name == "黄泉"
		and _rec("Skills", 6820).name == "变身——亚丝娜" and _d294_clothes(-75) == "铃兰")
	_check("d294_legacy_unique_tag_and_toast", str(_rec("Weapons", 2003).note).contains("<KyoUnique: 龙马复活术>")
		and str(_rec("CommonEvents", 1710).list[0].parameters[0]).contains("'琴里切换炮形态"))
	XState._become_current(tq)
	_check("d294_switch_back", XActorBook.actor_name(169) == "路痴刀客" and XDB.system().skillTypes[10] == "银发小魔导被动")
	XState._become_current(legacy)


## T562 R2：跨档读档的称号、存档预览按自己的档位取名、唯一标签缓存换档失效、旧天启档原文装备实例
func _t562_r2() -> void:
	var legacy := XState.current
	var kit := Kit.new("xiyou_text_fix_t562")
	var raw_actors: Array = XDB.load_json("db/Actors.json")
	var orig_nick := str(raw_actors[79].nickname)
	var names: Dictionary = XTextFix.actor_names().get("names", {})
	var tq_nick := str(names["79"])
	var plain := XState.new_game_blank()
	plain.add_actor(85)
	plain.add_actor(79)
	_check("t562_plain_default_nick", plain.actor(79).nickname == orig_nick, plain.actor(79).nickname)
	kit.save(1)
	var tq := Kit.new_game("jiusi")
	tq.map_id = 4  # Kit 把图号设 0；存档预览要读地图名，给个真地图（方桌大厅），免得日志出 Map000 读取失败
	XTianqi._joining = true  # 同 Kit.new_game：天启篇入队走正式入队口
	tq.add_actor(79)
	tq.add_actor(85)
	XTianqi._joining = false
	_check("t562_tq_default_nick", tq.actor(79).nickname == tq_nick and tq_nick != orig_nick, [tq.actor(79).nickname, tq_nick])
	# P2-1：在天启档里看西游档预览、在西游档里看天启档预览，各按存档自己的档位取名
	var tq_party := tq.party.duplicate()
	tq.party.assign([85] + Array(tq_party).filter(func(i): return i != 85))
	kit.save(2)
	tq.party.assign(tq_party)
	var sum_plain := XSave.summary_dict(1)
	_check("t562_preview_plain_in_tq", XTextFix.tq_on() and sum_plain.leader_name == str(raw_actors[85].name) and XSave.summary(1).contains(str(raw_actors[85].name)), [sum_plain.leader_name, XSave.summary(1)])
	_check("t562_title_lineup_in_tq", XTextFix.actor_rec_name(85, true) == "粉红妖精" and XTextFix.actor_rec_name(85, false) == "爱莉"
		and XTextFix.actor_nickname_in(85, false, str(XDB.rec("Actors", 85).nickname)) == str(raw_actors[85].nickname))
	# P1-1：天启档里读西游档 → 称号是西游原文；再存不写显式称号；冷读仍是原文
	var back := kit.reload(1)
	_check("t562_load_plain_from_tq", back != null and not XTextFix.tq_on() and back.actor(79).nickname == orig_nick, back.actor(79).nickname if back else null)
	kit.save(1)
	_check("t562_save_no_explicit_nick", not kit.raw(1).actors["79"].has("nickname"), kit.raw(1).actors["79"].get("nickname"))
	XState._become_current(tq)
	back = kit.reload(1)
	_check("t562_cold_reload", back.actor(79).nickname == orig_nick and back.actor(85).nickname == str(raw_actors[85].nickname))
	var sum_tq := XSave.summary_dict(2)
	_check("t562_preview_tq_in_plain", not XTextFix.tq_on() and sum_tq.leader_name == "粉红妖精" and XSave.summary(2).contains("粉红妖精")
		and XTextFix.actor_rec_name(85, true) == "粉红妖精" and XTextFix.actor_nickname_in(85, true, str(raw_actors[85].nickname)) == "粉红妖精", [sum_tq.leader_name, XSave.summary(2)])
	# R3：读档不改存值（存什么读什么、再存原样写回），按档位换名只在显示层
	# 西游档显式称号＝天启默认（区分不了是刻意自订还是旧版写坏，保守保留）：热读、再存、换档冷读都原样
	kit.edit_raw(func(d): d.actors["79"]["nickname"] = tq_nick, 1)
	XState._become_current(tq)
	back = kit.reload(1)
	_check("t562r3_plain_other_default_read", back.actor(79).nickname == tq_nick and back.actor(79).display_nickname() == tq_nick, [back.actor(79).nickname, back.actor(79).display_nickname()])
	kit.save(1)
	_check("t562r3_plain_other_default_resave", str(kit.raw(1).actors["79"].get("nickname")) == tq_nick, kit.raw(1).actors["79"].get("nickname"))
	_t562_cold()
	back = kit.reload(1)
	_check("t562r3_plain_other_default_cold", not XTextFix.tq_on() and back.actor(79).nickname == tq_nick and back.actor(79).display_nickname() == tq_nick, back.actor(79).nickname)
	kit.edit_raw(func(d): d.actors["79"]["nickname"] = "自订称号", 1)
	back = kit.reload(1)
	kit.save(1)
	_check("t562_custom_nick_kept", back.actor(79).nickname == "自订称号" and str(kit.raw(1).actors["79"].get("nickname")) == "自订称号")
	# 反向：西游档里读没存称号的天启档 → 天启默认称号，再存也不写显式称号
	back = kit.reload(2)
	_check("t562_load_tq_from_plain", XTextFix.tq_on() and back.actor(79).nickname == tq_nick, back.actor(79).nickname)
	var tq_back := back
	# 天启档显式称号＝西游默认：存值照旧，天启篇显示整串换成新称号（事件 324 按原文设的与刻意自订区分不了，只换显示）
	XState._become_current(plain)
	kit.edit_raw(func(d): d.actors["79"]["nickname"] = orig_nick, 2)
	back = kit.reload(2)
	_check("t562r3_tq_other_default_read", back.actor(79).nickname == orig_nick and back.actor(79).display_nickname() == tq_nick, [back.actor(79).nickname, back.actor(79).display_nickname()])
	kit.save(2)
	_check("t562r3_tq_other_default_resave", str(kit.raw(2).actors["79"].get("nickname")) == orig_nick, kit.raw(2).actors["79"].get("nickname"))
	_t562_cold()
	back = kit.reload(2)
	_check("t562r3_tq_other_default_cold", XTextFix.tq_on() and back.actor(79).nickname == orig_nick and back.actor(79).display_nickname() == tq_nick, back.actor(79).nickname)
	# 天启档含原名的自订长称号：存值、显示都不替换
	var long_nick := orig_nick + "的旧友"
	kit.edit_raw(func(d): d.actors["79"]["nickname"] = long_nick, 2)
	_t562_cold()
	back = kit.reload(2)
	kit.save(2)
	_check("t562r3_tq_long_custom", back.actor(79).nickname == long_nick and back.actor(79).display_nickname() == long_nick
		and str(kit.raw(2).actors["79"].get("nickname")) == long_nick, [back.actor(79).nickname, back.actor(79).display_nickname()])
	# 存档里显式写了「等于本档默认」的称号：再存照写，不丢键
	kit.edit_raw(func(d): d.actors["79"]["nickname"] = tq_nick, 2)
	back = kit.reload(2)
	kit.save(2)
	_check("t562r3_explicit_default_key_kept", str(kit.raw(2).actors["79"].get("nickname")) == tq_nick, kit.raw(2).actors["79"].get("nickname"))
	kit.edit_raw(func(d): d.actors["79"].erase("nickname"), 2)
	back = kit.reload(2)
	kit.save(2)
	_check("t562_tq_save_no_explicit_nick", back.actor(79).nickname == tq_nick and not kit.raw(2).actors["79"].has("nickname"), kit.raw(2).actors["79"].get("nickname"))
	# P2-1 新版读档右牌：存档自己的档位取名，天启档里看西游档、西游档里看天启档、标题冷启动（没有当前档）都对
	var d_plain := kit.raw(1)
	var d_tq := kit.raw(2)
	var name85 := str(raw_actors[85].name)
	XState._become_current(back)
	var in_tq := [XSkinSavePage.party_name(d_plain, 85), XSkinSavePage.party_name(d_tq, 85)]
	XState._become_current(plain)
	var in_plain := [XSkinSavePage.party_name(d_plain, 85), XSkinSavePage.party_name(d_tq, 85)]
	var keep_cur := XState.current
	XState.current = null  # 标题冷启动：表可能还是上一档口径
	var at_title := [XSkinSavePage.party_name(d_plain, 85), XSkinSavePage.party_name(d_tq, 85)]
	XTextFix.clear_cache()
	var at_title_fresh := [XSkinSavePage.party_name(d_plain, 85), XSkinSavePage.party_name(d_tq, 85)]
	XState._become_current(keep_cur)
	var want := [name85, "粉红妖精"]
	_check("t562r3_skin_card_party_names", in_tq == want and in_plain == want and at_title == want and at_title_fresh == want, [in_tq, in_plain, at_title, at_title_fresh])
	back = tq_back
	# P2-2：先西游后天启、先天启后西游，2003 的唯一标签都跟着当前档
	var ryoma_tq := XTextFix.actor_name_in(57, true, "龙马") + "复活术"
	XState._become_current(plain)
	var p1 := _unique_line(XDB.rec("Weapons", 2003))
	XState._become_current(back)
	var t1 := _unique_line(XDB.rec("Weapons", 2003))
	XState._become_current(plain)
	var p2 := _unique_line(XDB.rec("Weapons", 2003))
	_check("t562_unique_cache_switch", p1.contains("龙马复活术") and t1.contains(ryoma_tq) and p2.contains("龙马复活术"), [p1, t1, p2])
	# P2-3：旧天启档带原文模板的 2003 实例，读回后卡面写新名、唯一标签在；词缀等实例字段不动
	XState._become_current(back)
	var inst: Dictionary = XDB.load_json("db/Weapons.json")[2003].duplicate(true)
	inst.erase("id")
	inst["kind"] = "weapon"
	inst["base"] = 2003
	inst["note"] = str(inst.note) + "\n<pos=APs text=测试词缀 size=18 color=normalcolor line=false align=0>"
	back.gear.append(inst)
	back.register_gear(inst)
	var back2 := kit.roundtrip(3)
	var found := {}
	for e in back2.gear:
		if int(e.get("base", 0)) == 2003 and str(e.get("note", "")).contains("测试词缀"):
			found = e
	var line := _unique_line(found)
	var all := _card_text(found)
	_check("t562_old_tq_gear_card", not found.is_empty() and line.contains(ryoma_tq) and not all.contains("龙马复活术") and all.contains("测试词缀")
		and str(found.note).contains("龙马复活术"), [line, all.right(120)])
	XState._become_current(plain)
	_check("t562_plain_gear_card_original", _card_text(found).contains("龙马复活术"))
	kit.teardown()
	XState._become_current(legacy)


## 模拟换进程冷读：清 XTextFix 缓存与当前档，下一次读档全部按目标存档重读表
func _t562_cold() -> void:
	XState.current = null
	XTextFix.end_load()
	XTextFix.clear_cache()
	XTextFix.sync_mode()


func _card_text(obj: Dictionary) -> String:
	return "\n".join(XHelpCard.content(obj).map(func(r): return str(r[0])))


func _unique_line(obj: Dictionary) -> String:
	for r in XHelpCard.content(obj):
		if str(r[0]).contains(XHelpCard.UNIQUE_MARK):
			return str(r[0])
	return ""


func _d294_clothes(id: int) -> String:
	for row in XChangeClothes.entries():
		if row.id == id:
			return str(row.name)
	return ""


func _d294_other_texts() -> Array:
	return [_rec("Skills", 7831).name, _rec("Skills", 7894).description, _rec("Armors", 7923).name,
		_rec("Skills", 6812).name, _rec("Skills", 6816).name, _rec("Skills", 6808).name, _d294_clothes(-101),
		_cmd(93, 3, 0, 1)]
