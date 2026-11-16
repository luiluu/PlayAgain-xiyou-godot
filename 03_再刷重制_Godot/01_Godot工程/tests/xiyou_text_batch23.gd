extends Node
## 文字批 2／3（T027，文风指南 #8～#28）专项：玩家可见文字的残留断言。只管字，不碰逻辑。
## 一、大厅放贷人老钱／小钱不再地痞腔；36 层越阶台词无「该打」「天道」。
## 二、伤害总池统一叫「伤害」：天平、七印、戒指、向导等不再出现「出伤／终伤／最终伤害」。
## 三、首领：文字修正规则把玩家文字里的 Boss／BOSS／boss 改「首领」，【超级Boss】等特殊怪前缀与按名认档不受影响（D126 改名只在天启篇档套用，见 xiyou_text_fix）。
## 四、界面：主菜单「回到标题」、金额溢出「极多」、存档确认句、天平标题与麦说明、再挑战说明、号卷限制行。
## 五、地图 Map004：人族首领无「天道」、改版向导无「KYO改版」「13位伙伴」；Actors 半角标点已修。
## 六、元素转换书说明口径一致；仙法招式名已换。
## 七（批 3，skill_rework.json）：技能／装备说明无半角冒号残留、无「暂未实装」、无「最终伤害／终伤／出伤」、已并入一句话、正负号前有空格；名字与键不动。
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _all_text(o) -> String:
	return JSON.stringify(o)


func _run() -> void:
	XTextFix.set_all(true)
	# 一
	var bing := ""
	for id in [38, 39]:
		bing += _all_text(XTianqiSect._bing_loan_meta(id))
	_check("loan_no_heihei", not bing.contains("嘿嘿") and not bing.contains("糊弄") and not bing.contains("有你好瞧"), bing)
	var hs := _all_text(XTianqiSummit.scene("honghuang_skip"))
	_check("summit_skip_cold", hs.contains("越阶而上") and not hs.contains("该打") and not hs.contains("天道"), hs)
	# 二
	var pool_files := ["res://modes/xiyou/tianqi_data/qiyin_altar.json", "res://modes/xiyou/tianqi_data/rewards.json", "res://modes/xiyou/tianqi_data/affix_table.json",
		"res://modes/xiyou/tianqi_data/qiyin_gear.json", "res://modes/xiyou/guide_atlas.json"]
	for f in pool_files:
		var t := FileAccess.get_file_as_string(f)
		var bad := ""
		for w in ["本场出伤", "全场出伤", "本回合出伤", "自己的出伤", "\"最终伤害 +%\""]:
			if t.contains(w):
				bad += w + " "
		_check("pool_word_" + f.get_file(), bad == "", bad)
	_check("money_scale_labels", XTianqiMoney._good_label(null, "wine", {"goods": []}).contains("全队伤害 +") and XTianqiMoney._good_label(null, "wheat", {"goods": []}).contains("生命与魔法")
		and XTianqiMoney._good_label(null, "oil", {"goods": []}).contains("承伤 −"), XTianqiMoney._good_label(null, "oil", {"goods": []}))
	# 三
	var left := []
	for tb in ["Items", "Weapons", "Armors", "Skills", "States", "Troops", "Enemies", "CommonEvents"]:
		var rx := RegEx.create_from_string("(?<!超级)(?<!DOTA)(?i:boss)")
		for r in XDB.table(tb):
			if r is Dictionary:
				for k in ["name", "description", "message1", "message2"]:
					if rx.search(str(r.get(k, ""))) != null:
						left.append("%s:%s.%s" % [tb, r.get("id"), k])
	_check("boss_none_left_in_db_text", left.is_empty(), left.slice(0, 8))
	_check("boss_prefix_kept", str(XDB.table("Enemies")[850].name).begins_with("【超级Boss】") and XZhenqi.is_boss_enemy(XEnemy.new().setup(850, 1, 100.0)), XDB.table("Enemies")[850].name)
	var pool_db := []
	var prx := RegEx.create_from_string("(?:最终伤害|终伤)[+＋\\-−]\\d")
	for tb in ["Items", "Skills", "Weapons", "Armors", "States"]:
		for r in XDB.table(tb):
			if r is Dictionary:
				for k in ["name", "description"]:
					if prx.search(str(r.get(k, ""))) != null:
						pool_db.append("%s:%s.%s" % [tb, r.get("id"), k])
	_check("pool_word_none_left_in_db_text", pool_db.is_empty(), pool_db.slice(0, 8))
	# 四
	_check("menu_cmd", XMenu.COMMANDS[XMenu.COMMANDS.size() - 1][0] == "返回标题", XMenu.COMMANDS[XMenu.COMMANDS.size() - 1])
	_check("gold_overlap_zh", XMenu.GOLD_OVERLAP_ZH == "极多" and XMenu.GOLD_OVERLAP == "A lotta")
	var sp := XSaveScene.new()
	add_child(sp)
	sp._phase = "action"
	sp.act = 0
	sp.mode = "load"
	_check("save_confirm_runtime", sp.confirm_text == "" or not sp.confirm_text.contains("此保存文件"), sp.confirm_text)
	sp._start_confirm("要读取这份存档吗？")
	_check("save_confirm_text", sp.confirm_text == "要读取这份存档吗？" and not FileAccess.get_file_as_string("res://modes/xiyou/ui/save_scene.gd").contains("此保存文件"), sp.confirm_text)
	sp.queue_free()
	_check("trumpet_limit", XTianqiTrumpet._limit_line().contains("每名角色") and XTianqiTrumpet._limit_line().contains("满了先用"), XTianqiTrumpet._limit_line())
	# 五
	var m4: Dictionary = XDB.map(4)
	var t54 := _all_text(m4.events[54])
	var t71 := _all_text(m4.events[71])
	_check("map4_ev54_no_daodao", not t54.contains("天道"), t54.substr(0, 200))
	_check("map4_ev71_no_kyo", not t71.contains("KYO改版") and not t71.contains("13位伙伴") and t71.contains("再刷一把·天启篇"))
	var ac: Array = XDB.table("Actors")
	_check("actors_punct", str(ac[147].profile).ends_with("一现狂千年！") and not str(ac[149].profile).contains(",") and str(ac[162].nickname) == "蜀山天下第一！" and not str(ac[162].profile).contains("!"),
		[ac[147].profile, ac[162].nickname])
	# 六
	var hz := FileAccess.get_file_as_string("res://modes/xiyou/core/tianqi_horsemen.gd")
	_check("no_xianfa_in_horsemen", not hz.contains("仙法"))
	var el := FileAccess.get_file_as_string("res://modes/xiyou/core/tianqi_elements.gd")
	_check("element_book_wording", not el.contains("所有攻击伤害转换") and not el.contains("效果:所有技能伤害转换"))
	# 七（批 3）
	var sr: Dictionary = XDB.parse_file("res://modes/xiyou/tianqi_data/skill_rework.json")
	var colon_left := []
	var dev_left := []
	var pool_left := []
	var merged_left := []
	var sign_left := []
	var sign := RegEx.create_from_string("[\\x{4e00}-\\x{9fff}）」][+-]\\d")
	var bar := RegEx.create_from_string("[\\x{4e00}-\\x{9fff}）」]:")
	for sec in ["skills", "gear"]:
		for k in sr[sec]:
			var rec: Dictionary = sr[sec][k]
			for line in rec.get("desc", []):
				var ls := str(line)
				if bar.search(ls) != null:
					colon_left.append("%s:%s %s" % [sec, k, ls])
				if ls.contains("暂未实装") or ls.contains("半成品"):
					dev_left.append("%s:%s %s" % [sec, k, ls])
				if ls.contains("最终伤害") or ls.contains("终伤") or ls.contains("出伤") or ls.contains("受到的所有伤害"):
					pool_left.append("%s:%s %s" % [sec, k, ls])
				if ls.contains("本技能无额外效果") or ls.contains("原效果已并入") or ls.contains("原增伤已并入"):
					merged_left.append("%s:%s %s" % [sec, k, ls])
				if sign.search(ls) != null:
					sign_left.append("%s:%s %s" % [sec, k, ls])
	_check("skill_rework_no_halfwidth_colon", colon_left.is_empty(), colon_left.slice(0, 5))
	_check("skill_rework_no_dev_marks", dev_left.is_empty(), dev_left.slice(0, 5))
	_check("skill_rework_pool_word", pool_left.is_empty(), pool_left.slice(0, 5))

	_check("skill_rework_merged_one_line", merged_left.is_empty(), merged_left.slice(0, 5))
	_check("skill_rework_sign_spaced", sign_left.is_empty(), sign_left.slice(0, 5))
	_check("skill_rework_hidden_kept", int(sr.skills["2534"].get("_hidden_desc", []).size()) == 1 and sr.skills["2534"].desc.is_empty(), sr.skills["2534"])
	_check("skill_rework_keys_untouched", sr.skills.has("1240") and sr.gear.has("armor:4520") and str(sr.gear["armor:4520"].name) == "命运骰子（半成品）")

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
