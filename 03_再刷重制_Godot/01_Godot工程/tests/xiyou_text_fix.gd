extends Node
## 原版文字错的加载时修正（XTextFix，乙类文字审 xa_text-audit-b）专项：
## 一、六个开关默认开；覆盖表每条都套上（warnings 为空）。
## 二、每条统一规则抽样：零宽、名字框、成对标点、词典、繁简；规则不碰的（notetag、公式、梗）保持原样。
## 三、逐条覆盖抽样；原文对不上的条目不套用、记进 warnings。
## 四、开关全关回原版：读出的表与 generated 原文件逐字相同。
## 五、「超级Boos」改成「超级Boss」后，真气突破的首领判定（XZhenqi.is_boss_enemy）照旧认。
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
