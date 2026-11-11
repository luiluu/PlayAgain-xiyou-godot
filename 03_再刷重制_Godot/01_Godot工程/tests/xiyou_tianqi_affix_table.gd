extends Node
## 天启篇词条总表（XTianqiAffixTable＋tianqi_data/affix_table.json，来源：天启篇词条重构设计稿 v0.3）。
## 只验数据和查表，不进战斗：和 03_转换工具/天启篇词条表校验.py 验同一套内容。
## 一、条数 12／18／12／9、键不重复；二、一排数值严格递增、长度对层、连击固定 +1；
## 三、底线（一阶极 < 四阶普通，特效以上一阶不出）；四、相邻阶衔接；五、不出现数字 4（豁免键在表里）；
## 六、难度表合计 1、寻常无传说、难度键和 XTianqi.DIFFICULTIES 一致；七、栏位分组与候选；八、抽查设计稿数值。
## 不需要转换产物。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _num(x) -> String:
	return String.num(float(x), 6) if (x is float or x is int) else str(x)


func _numbers(node, exempt: Array, path: String, out: Array) -> void:
	if node is Dictionary:
		for k in node:
			if not (str(k) in exempt):
				_numbers(node[k], exempt, path + "." + str(k), out)
	elif node is Array:
		for i in node.size():
			_numbers(node[i], exempt, "%s[%d]" % [path, i], out)
	elif node is float or node is int:
		out.append([path, node])


func _row(key: String, tier := 4) -> Array:
	return T.GRADES.map(func(g): return T.value(key, tier, g))


const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")


func _run() -> void:
	T.reload()
	var d := T.data()
	_check("能读表", not d.is_empty())
	var aff: Array = d.get("affixes", [])
	_check("表头 source", str(d.get("source", "")) == "天启篇词条重构设计稿 v0.3", d.get("source"))

	# 一、条数与键
	for pair in [["base", 12], ["special", 18], ["legendary", 12], ["aura", 9]]:
		_check("条数 %s=%d" % pair, T.affixes(pair[0]).size() == pair[1], T.affixes(pair[0]).size())
	var seen := {}
	var dup := []
	for a in aff:
		if seen.has(a.key):
			dup.append(a.key)
		seen[a.key] = true
	_check("词条键不重复", dup.is_empty(), dup)

	# 二、一排数值
	var lens := {"base": 6, "special": 5, "legendary": 4, "aura": 5}
	var starts := {"base": 1, "special": 2, "legendary": 3, "aura": 2}
	for l in lens:
		_check("层 %s 一排 %d、从 %d 阶起" % [l, lens[l], starts[l]],
			int(T.layer(l).row_len) == lens[l] and int(T.layer(l).tier_start) == starts[l], T.layer(l))
	var bad_rows := []
	for a in aff:
		var v: Array = a.values
		if bool(a.get("fixed", false)):
			continue
		var inc := true
		for i in range(1, v.size()):
			inc = inc and float(v[i - 1]) < float(v[i])
		if not inc or v.size() != lens[a.layer]:
			bad_rows.append(a.key)
	_check("一排数值严格递增、长度对层", bad_rows.is_empty(), bad_rows)
	_check("连击固定 +1、三阶起、走攻击次数",
		_row("combo", 3) == [1.0, 1.0, 1.0] and _row("combo") == [1.0, 1.0, 1.0] and T.value("combo", 2, "perfect") == null
		and int(T.affix("combo").get("trait_code", 0)) == 34, T.affix("combo"))

	# 三、底线
	var floor_bad := []
	for a in aff:
		var k: String = a.key
		if T.tier_start(k) == 1:
			if not (float(T.value(k, 1, "perfect")) < float(T.value(k, 4, "normal"))):
				floor_bad.append(k)
		elif T.available(k, 1):
			floor_bad.append(k)
	_check("底线：一阶极 < 四阶普通，特效以上一阶不出", floor_bad.is_empty(), floor_bad)

	# 四、相邻阶
	var link_bad := []
	for a in aff:
		var k: String = a.key
		if bool(a.get("fixed", false)):
			continue
		for tr in range(T.tier_start(k), 4):
			if T.value(k, tr, "perfect") != T.value(k, tr + 1, "fine") or T.value(k, tr, "fine") != T.value(k, tr + 1, "normal"):
				link_bad.append([k, tr])
		for tr in range(T.tier_start(k), 5):
			for g in T.GRADES:
				if T.value(k, tr, g) == null:
					link_bad.append([k, tr, g])
	_check("相邻阶衔接、可出阶三种成色都有值", link_bad.is_empty(), link_bad)

	# 五、不出现数字 4
	var nums := []
	_numbers(d, d.get("digit_check_exempt", []), "", nums)
	var fours := nums.filter(func(p): return "4" in _num(p[1]))
	_check("不出现数字 4（共 %d 个数）" % nums.size(), fours.is_empty() and nums.size() > 300, fours)

	# 六、难度表
	var keys := XTianqi.DIFFICULTIES.map(func(x): return str(x.key))
	_check("难度键和 XTianqi.DIFFICULTIES 一致", d.layer_odds.keys() == keys, [d.layer_odds.keys(), keys])
	var sum_bad := []
	for k in keys:
		var o := T.layer_odds(k)
		if o.size() != 3 or absf(float(o.get("base", 0)) + float(o.get("special", 0)) + float(o.get("legendary", 0)) - 1.0) > 1e-9:
			sum_bad.append(k)
	_check("难度表每行三层合计 1", sum_bad.is_empty(), sum_bad)
	_check("寻常传说为 0", float(T.layer_odds("xunchang").get("legendary", -1)) == 0.0, T.layer_odds("xunchang"))

	# 七、栏位分组
	var groups := {"weapon": "bingqi", "offhand": "bingqi", "head": "fangju", "body": "fangju", "hands": "fangju",
		"waist": "fangju", "legs": "fangju", "feet": "fangju", "necklace": "shipin", "ring": "shipin",
		"artifact": "fabao", "mount": "zuoqi"}
	var gbad := []
	for s in groups:
		if T.slot_group(s) != groups[s]:
			gbad.append(s)
	_check("12 栏位分组", gbad.is_empty() and d.slots.size() == 12, gbad)
	for pair in [["bingqi", ["atk", "gen"]], ["fangju", ["def", "gen"]], ["shipin", ["atk", "def", "gen"]]]:
		for l in ["base", "special", "legendary"]:
			var got := T.candidates(l, pair[0])
			var want := T.affixes(l).filter(func(a): return str(a.tag) in pair[1]).map(func(a): return str(a.key))
			_check("%s %s 候选只出 %s" % [pair[0], l, "＋".join(pair[1])], got == want and not got.is_empty(), got)
	var atk_keys := ["atk", "mat", "hit", "cri", "crit_damage", "final_damage", "skill_damage", "element_damage", "lifesteal",
		"first_strike", "last_stand", "headhunter", "expose", "suppress", "combo"]
	var def_keys := ["mhp", "def", "mdf", "eva", "hrg", "damage_reduction", "element_resist", "state_resist", "heal_received",
		"opening_shield", "target_rate", "bulwark", "unyielding", "tenacity"]
	var non_aura := aff.filter(func(a): return str(a.layer) != "aura")
	_check("攻、守标签对设计稿第 4～6 节",
		non_aura.filter(func(a): return str(a.tag) == "atk").map(func(a): return str(a.key)) == atk_keys
		and non_aura.filter(func(a): return str(a.tag) == "def").map(func(a): return str(a.key)) == def_keys)
	_check("兵器、防具不出光环", T.candidates("aura", "bingqi").is_empty() and T.candidates("aura", "fangju").is_empty())
	_check("坐骑候选为空", ["base", "special", "legendary", "aura"].all(func(l): return T.candidates(l, "zuoqi").is_empty()))
	_check("法宝只有光环", ["base", "special", "legendary"].all(func(l): return T.candidates(l, "fabao").is_empty())
		and T.candidates("aura", "fabao").size() == 9)
	_check("只有项链和法宝带光环", groups.keys().filter(func(s): return T.slot_has_aura(s)) == ["necklace", "artifact"])
	_check("通用法宝按养成分阶", [0.0, 0.3, 0.34, 0.66, 0.67, 1.0].map(func(p): return T.artifact_tier(p)) == [2, 2, 3, 3, 4, 4])

	# 槽数、成色、四阶
	_check("槽数 0/1/1/2/2/3/3", ["putong", "youxiu", "jingliang", "shishi", "chuanshuo", "buxiu", "shenhua"].map(
		func(q): return T.slot_count(q)) == [0, 1, 1, 2, 2, 3, 3])
	_check("成色几率：极 3%、上品 10/20/30%", is_equal_approx(T.perfect_chance(), 0.03)
		and ["youxiu", "shishi", "buxiu"].map(func(q): return T.fine_chance(q)) == [0.1, 0.2, 0.3])
	_check("四阶分界 1/30/60/70", [1, 29, 30, 59, 60, 69, 70, 99].map(func(x): return T.tier_of_level(x)) == [1, 1, 2, 2, 3, 3, 4, 4])

	# 八、抽查设计稿
	_check("物攻四阶 5/6/8", _row("atk") == [5.0, 6.0, 8.0], _row("atk"))
	_check("终伤四阶 9/12/15", _row("final_damage") == [9.0, 12.0, 15.0], _row("final_damage"))
	_check("再动四阶 10/15/20", _row("reaction") == [10.0, 15.0, 20.0], _row("reaction"))
	_check("全能光环四阶 1.5/2/3", _row("aura_versatile") == [1.5, 2.0, 3.0], _row("aura_versatile"))
	_check("技能消耗全身上限 −50%", int(T.affix("skill_cost").get("cap_total", 0)) == 50, T.affix("skill_cost"))
	_check("稀有词条连击、再动权重 0.3", aff.filter(func(a): return bool(a.get("rare", false))).map(func(a): return str(a.key)) == ["combo", "reaction"]
		and is_equal_approx(float(T.affix("reaction").weight), 0.3) and is_equal_approx(float(T.affix("combo").weight), 0.3))
	_check("不能出的阶返回空", T.value("first_strike", 2, "perfect") == null and T.value("final_damage", 1, "normal") == null
		and T.value("nope", 4, "normal") == null and T.value("atk", 5, "normal") == null and T.value("atk", 4, "bad") == null)

	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
