extends Node
## T590 说明卡公式显示专项（XSkillHelpFix，只改显示）：
## 一、随机倍率：全技能表里公式带 Math.random 的招，说明卡写出的区间＝从公式反算的 M～M+N−1（不是照着修正表抄）。
## 二、消耗：按角色出卡时＝实扣链 skill_cost（难度被动让消耗变高）；没角色时用固定值；定值消耗行不再和表值打架。
## 三、开关关掉回原版说明；公式、数据库记录不被改。
## 四、天启篇：消耗跟改写后的实扣链；没改写的随机招照样写区间。
## 五、战斗入口（XHelpCard.show_for）：本场的消耗加费（饥荒线枯竭者）算进说明卡，和技能列表、实扣一致。

const TestEnv = preload("res://tests/xiyou_test_env.gd")
## 原版说明本来就写对的（不进修正表）
const ALREADY_RIGHT := [5601, 5636, 6039, 10035, 10558]
const ZZB := 36
const STAFF := 3589
var results: Array = []


func _ready() -> void:
	TestEnv.isolate("xiyou_skill_help_fix")
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _card(obj: Dictionary, who = null) -> String:
	XHelpCard.cost_actor = who
	var rows := XHelpCard.content(obj, "skill")
	XHelpCard.cost_actor = null
	return XHelpCard.plain("\n".join(rows.map(func(r): return str(r[0]))))


func _lines(card: String, key: String) -> Array:
	var out := []
	for m in RegEx.create_from_string(key + "[：:]\\s*(\\d+)\\s*(?:MP|TP)").search_all(card):
		out.append(int(m.get_string(1)))
	return out


func _run() -> void:
	var s := XState.new()
	XState.current = s
	s.add_actor(ZZB)
	_ranges()
	_costs(s)
	_tianqi()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _ranges() -> void:
	var rx := RegEx.create_from_string("(1\\+)?Math\\.floor\\(Math\\.random\\(\\)\\*(\\d+)\\)(?:\\+(\\d+))?")
	var found := []
	var bad := []
	var table: Array = XDB.table("Skills")
	for id in range(1, table.size()):
		if table[id] == null:
			continue
		var rec := XDB.rec("Skills", id)
		var formula := str(rec.get("damage", {}).get("formula", ""))
		var ms := rx.search_all(formula)
		if ms.is_empty() or int(rec.damage.type) == 0:
			continue
		found.append(id)
		var before := str(rec.note)
		var card := _card(rec)
		for m in ms:
			var n := int(m.get_string(2))
			var lo := int(m.get_string(3)) + (1 if m.get_string(1) != "" else 0)
			var hi := lo + n - 1
			# 修正过的写「a～b」；原版本来就对的写「a~b」「a-b」「a倍-b倍」
			var want := "(?<!\\d)%d(?:～|~|-|倍-)%d(?!\\d)" % [lo, hi]
			if RegEx.create_from_string(want).search(card) == null:
				bad.append([id, rec.name, lo, hi, card])
		if str(rec.note) != before or str(rec.damage.formula) != formula:
			bad.append([id, "记录被改了"])
		if card.contains("?") or card.contains("未知"):
			bad.append([id, "还有问号", card])
	_check("random_all_shown", bad.is_empty(), bad.slice(0, 5))
	var expect: Array = XSkillHelpFix.RANGES.keys() + ALREADY_RIGHT
	expect.sort()
	_check("random_list_complete", found == expect and found.size() == 62, [found.size(), found.filter(func(i): return not expect.has(i)), expect.filter(func(i): return not found.has(i))])
	var stale := []
	for id in XSkillHelpFix.RANGES:
		for p in XSkillHelpFix.RANGES[id]:
			if not str(XDB.rec("Skills", id).note).contains(str(p[0])):
				stale.append([id, p[0]])
	_check("table_matches_notes", stale.is_empty(), stale)
	_check("staff_text", _card(XDB.rec("Skills", STAFF)).contains("(10000+物攻*125) ×50～249 随机"), _card(XDB.rec("Skills", STAFF)))
	XSkillHelpFix.RANGE_FIX = false
	_check("range_switch_off", _card(XDB.rec("Skills", STAFF)).contains("* ?"))
	XSkillHelpFix.RANGE_FIX = true
	var other := _card(XDB.rec("Skills", 6270))
	_check("note_6270_one_rule", other.contains("目标生命值不高于上限的30%时，公式中的120000改为1200000，伤害×0～99 随机。其余情况伤害×0～19 随机") and other.contains("[120000+") and str(XDB.rec("Skills", 6270).damage.formula).contains("(1200000+") and str(XDB.rec("Skills", 6270).damage.formula).contains(": (120000+") and not other.contains("倍率*5"), other)
	for pair in [[3517, "×10～49 随机"], [5588, "×0～19 随机"], [5592, "×0～299 随机"], [9926, "×0～9 随机"]]:
		var c := _card(XDB.rec("Skills", pair[0]))
		_check("wording_%d" % pair[0], c.contains(pair[1]) and not c.contains("随机数") and not c.contains("随机倍率"), c)
	_check("hidden_formula_kept", _card(XDB.rec("Skills", 10530)).contains("伤害：?"), _card(XDB.rec("Skills", 10530)))


func _costs(s: XState) -> void:
	var a: XActor = s.actor(ZZB)
	var logic := XBattleLogic.new()
	var staff := XDB.rec("Skills", STAFF)
	_check("base_cost", _lines(_card(staff, a), "消耗") == [30], _card(staff, a))
	_check("no_actor_cost", _lines(_card(staff), "消耗") == [30])
	for passive in [2896, 2878, 2875]:  # 轮回模式难度被动：ConsumeReduceAll -100%、-15%、-25%（Kyo 截图的 72TP）
		a.learn_skill(passive)
	a.refresh_passive()
	var real := int(logic.skill_cost(a, staff).tp)
	_check("difficulty_raises_cost", real == 72, real)
	_check("card_follows_actor", _lines(_card(staff, a), "消耗") == [real], _card(staff, a))
	_check("record_untouched", int(staff.tpCost) == 30 and int(XDB.rec("Skills", STAFF).tpCost) == 30)
	XSkillHelpFix.COST_FIX = false
	_check("cost_switch_off", _lines(_card(staff, a), "消耗") == [30], _card(staff, a))
	XSkillHelpFix.COST_FIX = true
	# 定值消耗行写错的五个
	var c9944 := _card(XDB.rec("Skills", 9944))
	_check("note_tp_cost_wins", _lines(c9944, "消耗") == [200], c9944)
	for id in [2802, 2806, 3887, 3897]:
		var c := _card(XDB.rec("Skills", id))
		_check("free_shows_zero_%d" % id, _lines(c, "消耗") == [0] and not c.contains("TP消耗：50"), c)
	# 按最大魔法比例的招：按角色算出定值
	var mp := XDB.rec("Skills", 10020)
	var want := int(logic.skill_cost(a, mp).mp)
	_check("percent_mp_actor", _lines(_card(mp, a), "消耗").has(want) and not _lines(_card(mp, a), "消耗").has(5000), [want, _card(mp, a)])
	_check("percent_mp_no_actor_kept", _card(mp).contains("5000MP"), _card(mp))
	# 夹在介绍文字里的定值消耗：清掉，只留实扣的消耗行
	var sword := XDB.rec("Skills", 9998)
	var cs := _card(sword, a)
	var cost9998: Dictionary = logic.skill_cost(a, sword)
	_check("note_9998_no_stale_cost", not cs.contains("消耗15") and cs.contains("老剑神李淳罡的绝学") and _lines(cs, "消耗") == [int(cost9998.mp), int(cost9998.tp)] and int(cost9998.tp) == 24 and int(cost9998.mp) == 1200, [cost9998, cs])
	var gone := XSkillHelpFix.STALE_COST.keys().filter(func(i): return RegEx.create_from_string(str(XSkillHelpFix.STALE_COST[i][0])).search(str(XDB.rec("Skills", i).note)) == null)
	gone.append_array(XSkillHelpFix.STALE_LINES.keys().filter(func(i): return RegEx.create_from_string(str(XSkillHelpFix.STALE_LINES[i])).search(str(XDB.rec("Skills", i).note)) == null))
	_check("stale_cost_table_matches", gone.is_empty(), gone.map(func(i): return [i, XDB.rec("Skills", i).note]))
	var c10462 := _card(XDB.rec("Skills", 10462), a)
	_check("note_10462_no_stale_cost", not c10462.contains("150怒气") and not _card(XDB.rec("Skills", 10458), a).contains("75怒气"), c10462)
	_check_10458(a, logic)
	_check_10462(a, logic)
	# 全表扫一遍：按角色出卡时，凡是写成定值的消耗都等于实扣
	var bad := []
	var table: Array = XDB.table("Skills")
	for id in range(1, table.size()):
		if table[id] == null or XCharacterHelp.target(table[id]):
			continue
		var rec := XDB.rec("Skills", id)
		if int(rec.get("tpCost", 0)) <= 0 and int(rec.get("mpCost", 0)) <= 0:
			continue
		var card := _card(rec, a)
		var cost: Dictionary = logic.skill_cost(a, rec)
		for kind in ["MP", "TP"]:
			for m in RegEx.create_from_string("(?m)(?:^|\\s)(?:消耗[：:]\\s*(\\d+)%s|%s消耗[：:]\\s*(\\d+))(?![\\d%%％])" % [kind, kind]).search_all(card):
				var shown := int(m.get_string(1) if m.get_string(1) != "" else m.get_string(2))
				if shown != int(cost[kind.to_lower()]):
					bad.append([id, rec.name, kind, shown, int(cost[kind.to_lower()])])
	# 运行时记录里自己要收费的招：介绍文字里不许再夹别的定值消耗（「消耗10tp」「消耗：75怒气」这类）
	var loose := []
	for id in range(1, table.size()):
		if table[id] == null or XCharacterHelp.target(table[id]):
			continue
		var rec := XDB.rec("Skills", id)
		if int(rec.get("tpCost", 0)) <= 0 and int(rec.get("mpCost", 0)) <= 0:
			continue
		var card := _card(rec, a)
		var cost: Dictionary = logic.skill_cost(a, rec)
		for m in RegEx.create_from_string("(?i)(?:消耗|耗费|耗)[：:]?\\s*(\\d+)\\s*(?:点)?(tp|mp|怒气|能量|魔法)").search_all(card):
			var v := int(m.get_string(1))
			if v != int(cost.tp if m.get_string(2).to_lower() in ["tp", "怒气", "能量"] else cost.mp):
				loose.append([id, rec.name, m.get_string(0), cost])
	_check("no_loose_cost_text", loose.is_empty(), loose)
	_check("all_static_costs_match", bad.is_empty(), bad.slice(0, 8))


## 10458：卡上写的是状态效果（2720：生命上限×0.01、2 回合），不是扣生命
func _check_10458(a: XActor, logic: XBattleLogic) -> void:
	var rec := XDB.rec("Skills", 10458)
	var state := XDB.rec("States", 2720)
	var mhp_rate := (state.traits as Array).filter(func(t): return int(t.code) == 21 and int(t.dataId) == 0).map(func(t): return float(t.value))
	_check("state_2720_matches_text", str(rec.note).contains("Add State 2720: user") and mhp_rate == [0.01] and int(state.minTurns) == 2 and int(state.maxTurns) == 2, [mhp_rate, state.minTurns, state.maxTurns])
	_check("hp_not_charged_10458", XBattleLogic.skill_hp_cost(a, rec) == 0)
	for who in [a, null]:
		var c := _card(rec, who)
		_check("note_10458_state_%s" % ("actor" if who != null else "plain"), c.contains("施放后生命上限降至原来的1%，持续2回合") and not c.contains("99.99") and not c.contains("另耗") and c.contains("3段伤害"), c)


## 10462：旧「释放需求」行不再出；没角色时写清另加 15%，有角色时只看消耗栏
func _check_10462(a: XActor, logic: XBattleLogic) -> void:
	var rec := XDB.rec("Skills", 10462)
	var cost: Dictionary = logic.skill_cost(a, rec)
	var with := _card(rec, a)
	_check("note_10462_actor", not with.contains("释放需求") and not with.contains("最大魔法的15%") and _lines(with, "消耗") == [int(cost.mp), int(cost.tp)] and with.contains("四段伤害"), [cost, with])
	var without := _card(rec)
	_check("note_10462_plain", not without.contains("释放需求") and without.contains("基础魔法消耗另加最大魔法的15%") and _lines(without, "消耗") == [9999, 150], without)
	XSkillHelpFix.COST_FIX = false
	_check("note_10462_switch_off", _card(rec).contains("释放需求") and _card(XDB.rec("Skills", 10458)).contains("最大生命的99.99%"), _card(rec))
	XSkillHelpFix.COST_FIX = true


func _tianqi() -> void:
	var t: XState = XTianqi.start_new_game(3, "jianxian", [1, 2, 3, 4, 5])
	XTianqi.take_pending()
	XTianqi._joining = true
	t.add_actor(ZZB)
	XTianqi._joining = false
	XState.current = t
	XTianqiSkills.reload_table()
	_check("tq_cards_on", XTianqiSkills.cards_on())
	_check("tq_unreworked_random_fixed", _card(XDB.rec("Skills", 3907)).contains("×50～249 随机"), _card(XDB.rec("Skills", 3907)))
	var a: XActor = t.actor(ZZB)
	var staff := XDB.rec("Skills", STAFF)
	var real := int(XBattleLogic.new().skill_cost(a, staff).tp)
	_check("tq_cost_follows", int(staff.tpCost) == 100 and _lines(_card(staff, a), "消耗") == [real], [real, _card(staff, a)])
	_battle_cost(t, a)


## 枯竭者在场：真火连击经战斗里的说明卡入口出卡，写的数＝本场 skill_cost＝实扣
func _battle_cost(t: XState, a: XActor) -> void:
	var rec := XDB.rec("Skills", 1083)
	var outside := int(XBattleLogic.new().skill_cost(a, rec).tp)
	var scene := XBattleScene.new()
	t.flags.tianqi["line"] = "famine"
	var armed := XTianqiFamineAlien.prepare("omen", t)
	scene.logic.setup(11, t)
	var real := int(scene.logic.skill_cost(a, rec).tp)
	_check("battle_exhaust_raises", armed and XTianqiFamineAlien.hungry(scene.logic) and scene.logic.actors.has(a) and real > outside, [armed, outside, real])
	var card := XHelpCard.new()
	scene.add_child(card)
	XHelpCard.scene_actor = a
	card.show_for(rec)
	var text := XHelpCard.plain("\n".join(card.rows.map(func(r): return str(r[0]))))
	_check("battle_card_follows_fight", _lines(text, "消耗") == [real], [real, outside, text])
	_check("battle_card_statics_cleared", XHelpCard.cost_actor == null and XHelpCard.cost_logic == null)
	a.tp = a.max_tp()
	var before := a.tp
	scene.logic.pay_skill_cost(a, rec)
	_check("battle_paid_equals_card", int(before - a.tp) == real, [before, a.tp, real])
	XHelpCard.scene_actor = null
	scene.free()
