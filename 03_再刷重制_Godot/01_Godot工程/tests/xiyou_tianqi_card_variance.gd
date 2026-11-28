extends Node
## T590 改写过的招的说明卡浮动写法专项（XTianqiCardVariance，只改显示）：
## 一、卡上写的「浮动±N%」都等于生效记录的浮动；浮动大于 20% 的招都写了幅度。
## 二、措辞只剩「浮动±N%」和「×a～b 随机」两种写法。
## 三、开关关掉、非改写存档时说明照旧；数据库记录不被改。

const TestEnv = preload("res://tests/xiyou_test_env.gd")
var results: Array = []


func _ready() -> void:
	TestEnv.isolate("xiyou_tianqi_card_variance")
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _card(obj: Dictionary) -> String:
	var rows := XHelpCard.content(obj, "skill")
	return XHelpCard.plain("\n".join(rows.map(func(r): return str(r[0]))))


func _plain_card(obj: Dictionary) -> String:
	XTianqiCardVariance.VARIANCE_FIX = false
	var out := _card(obj)
	XTianqiCardVariance.VARIANCE_FIX = true
	return out


## 改写稿残留的原版费用句：10462 整行没有，10458 换成状态的说法；开关关掉照旧
func _old_cost_lines() -> void:
	var c10458 := _card(XDB.rec("Skills", 10458))
	_check("tq_10458_state_text", c10458.contains("施放后生命上限降至原来的1%，持续2回合") and not c10458.contains("怒气") and not c10458.contains("99.99") and str(XDB.rec("Skills", 10458).note).contains("Add State 2720: user"), c10458)
	var rec := XDB.rec("Skills", 10462)
	var c10462 := _card(rec)
	_check("tq_10462_no_mp_text", int(rec.mpCost) == 0 and not str(rec.note).contains("<MP Cost") and not c10462.contains("怒气") and not c10462.contains("最大魔法") and not c10462.contains("释放需求") and c10462.contains("100TP"), c10462)
	XTianqiCardVariance.OLD_COST_FIX = false
	_check("tq_old_cost_switch_off", _card(rec).contains("最大魔法"), _card(rec))
	XTianqiCardVariance.OLD_COST_FIX = true


func _run() -> void:
	var s := XState.new()
	XState.current = s
	var rec597 := XDB.rec("Skills", 597)
	_check("other_saves_untouched", _card(rec597) == _plain_card(rec597))
	var t: XState = XTianqi.start_new_game(3, "jianxian", [1, 2, 3, 4, 5])
	XTianqi.take_pending()
	XState.current = t
	XTianqiSkills.reload_table()
	_check("cards_on", XTianqiSkills.cards_on())
	var written := RegEx.create_from_string(XTianqiCardVariance.WRITTEN)
	var had := RegEx.create_from_string(XTianqiCardVariance.WRITTEN + "|%(?:之间)?浮动")
	var wrong := []
	var odd := []
	var added := []
	var reworded := []
	for key in XTianqiSkills.data().get("skills", {}):
		var rec := XDB.rec("Skills", int(key))
		if rec.is_empty():
			continue
		var before := str(rec.note)
		var card := _card(rec)
		var plain := _plain_card(rec)
		if card != plain:
			(added if had.search(plain) == null and written.search(card) != null else reworded).append(int(key))
		var n := int(rec.damage.variance)
		if int(rec.damage.type) != 0:
			for m in written.search_all(card):
				if n > 0 and (int(m.get_string(1)) != n or m.get_string(0) != "浮动±%d%%" % n):
					wrong.append([key, n, m.get_string(0)])
			if n > XTianqiCardVariance.VARIANCE_QUIET and written.search(card) == null:
				wrong.append([key, n, "没写幅度", card])
		if RegEx.create_from_string("浮动\\s*\\d+\\s*%|%(?:之间)?浮动|[\\d.]随机|大幅随机浮动|伤害随机浮动").search(card) != null:
			odd.append([key, card])
		if str(rec.note) != before:
			wrong.append([key, "记录被改了"])
	added.sort()
	reworded.sort()
	print("TQ_VARIANCE_ADDED=", added.size(), " ", added)
	print("TQ_VARIANCE_REWORDED=", reworded.size(), " ", reworded)
	_check("amount_matches_record", wrong.is_empty(), wrong.slice(0, 8))
	_check("one_wording", odd.is_empty(), odd.slice(0, 8))
	_check("added_32", added.size() == 32, [added.size(), added])
	_check("heal_word", _card(XDB.rec("Skills", 680)).contains("治疗浮动±40%"), _card(XDB.rec("Skills", 680)))
	_check("written_reworded", _card(XDB.rec("Skills", 3517)).contains("浮动±39%"), _card(XDB.rec("Skills", 3517)))
	_check("range_percent_reworded", _card(XDB.rec("Skills", 1216)).contains("（浮动±100%）") and _card(XDB.rec("Skills", 1217)).contains("伤害浮动±100%"), [_card(XDB.rec("Skills", 1216)), _card(XDB.rec("Skills", 1217))])
	_check("stale_vague_line_removed", not _card(XDB.rec("Skills", 6867)).contains("随机浮动") and _card(XDB.rec("Skills", 6867)).contains("浮动±76%"), _card(XDB.rec("Skills", 6867)))
	_check("random_spacing", XTianqiCardVariance._words("物理攻击×0.6～3.0随机（平均1.8）") == "物理攻击×0.6～3.0 随机（平均1.8）")
	_old_cost_lines()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
