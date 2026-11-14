extends Node
## 天启篇难度挂钩修补（XTianqiTrim 等，审查线开工单甲、乙两组）：
## 一、牢妲菜单只剩挑战守层者；二、强者名单读天启篇档位表；三、难度名显示五档档名（副本带副本档）；四、修行页不显示高阶词条概率；
## 五、必出的神话／混沌神话行也跳过；六、洪荒奖励、洪荒女皇店取消，仙道模式并进人族首领；
## 七、副本档系数；八、路线系数（真气、流萤残核、星爆书、抽奖被动上限）；九、原版档不受影响、各开关回退。

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	_laoda()
	_roster()
	_names()
	_affix_rate()
	_high_rows()
	_honghuang()
	_dungeon()
	_routes()
	_original()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _tianqi_state(diff := "jiusi") -> XState:
	var s := XState.new_game_blank()
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": diff, "lineup": []}
	XState.current = s
	return s


func _plain_state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	return s


func _near(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) < eps


func _laoda() -> void:
	var s := _tianqi_state()
	_check("laoda_intercepts", XTianqiTrim.intercepts(s, 4, 62) and not XTianqiTrim.intercepts(s, 4, 61) and not XTianqiTrim.intercepts(s, 5, 62))
	var labels := XTianqiTrim.laoda_options(s).map(func(o): return str(o[0]))
	_check("laoda_menu", labels == ["挑战30层守层者", "挑战31层守层者", "挑战32层守层者", "挑战33层守层者", "兑换商店", "离开"], labels)
	var all := " ".join(labels)
	_check("laoda_no_difficulty_items", not all.contains("debuff") and not all.contains("怪物难度"), labels)
	var acts := XTianqiTrim.laoda_options(s).map(func(o): return o[1])
	_check("laoda_guard_troops", acts.slice(0, 4).map(func(a): return int(a[1])) == [466, 467, 468, 469], acts)
	_check("laoda_original_untouched", not XTianqiTrim.intercepts(_plain_state(), 4, 62))
	XTianqiTrim.LAODA = false
	_check("laoda_switch_off", not XTianqiTrim.intercepts(_tianqi_state(), 4, 62))
	XTianqiTrim.LAODA = true


func _roster() -> void:
	var s := _tianqi_state()
	var sup := XTianqiTrim.roster("super", s)
	_check("roster_super_ids", sup.get("ids") == XTianqiSkills.ids(XTier.SUPER) and not (sup.ids as Array).is_empty(), sup.get("ids"))
	var notes := " ".join(sup.get("notes", []))
	_check("roster_super_notes", notes.contains("+150%") and notes.contains("寻常 0") and notes.contains("九死 1") and notes.contains("证道 3")
		and not notes.contains("洪荒"), notes)
	var st := XTianqiTrim.roster("strong", s)
	_check("roster_strong", st.get("ids") == XTianqiSkills.ids(XTier.STRONG) and " ".join(st.notes).contains("+50%"), st)
	_check("roster_original_empty", XTianqiTrim.roster("super", _plain_state()).is_empty())


func _names() -> void:
	var s := _tianqi_state("jiusi")
	_check("name_tier", XTianqiTrim.difficulty_name(s) == "九死", XTianqiTrim.difficulty_name(s))
	s.set_variable(XDungeon.VAR_INSIDE, 1)
	s.set_variable(XDungeon.VAR_TIER, 4)
	_check("name_in_dungeon", XTianqiTrim.difficulty_name(s) == "九死·王者", XTianqiTrim.difficulty_name(s))
	s.set_variable(XDungeon.VAR_INSIDE, 0)
	var n := XDifficultyNotice.new()
	n.difficulty = 3
	n.remaining = 100
	n.paint()
	_check("notice_text", n.text == "当前难度：九死", n.text)
	XState.current = _plain_state()
	n.paint()
	_check("notice_original", n.text == "当前难度：普通", n.text)
	n.free()
	_check("name_original_empty", XTianqiTrim.difficulty_name(_plain_state()) == "")


func _affix_rate() -> void:
	_check("affix_rate_hidden", XAffixRate.detail_rows(_tianqi_state()).is_empty())
	_check("affix_rate_original", not XAffixRate.detail_rows(_plain_state()).is_empty())


## 全库必出（几率合计 ≥100）且整行神话／混沌神话的行
func _high_rows() -> void:
	var s := _tianqi_state()
	var rows := 0
	var items := {}
	var luoyun := false
	var all_skipped := true
	var kept_off := true
	for table in ["Weapons", "Armors"]:
		var list = XDB.table(table)
		if not list is Array:
			continue
		for rec in list:
			if not rec is Dictionary:
				continue
			for row in rec.get("equipment", {}).get("affixes", []):
				var total := 0
				for c in row.get("choices", []):
					total += int(c.get("chance", 0))
				if total < 100 or XAffixRate.line_tier(row.get("choices", []), table) <= 0:
					continue
				rows += 1
				items["%s:%d" % [table, int(rec.id)]] = true
				if str(rec.get("name", "")).contains("落芸"):
					luoyun = true
				if not XTianqiAffixRoll.skips_row(row, s, table):
					all_skipped = false
				XTianqiAffixRoll.SKIP_HIGH_ROWS = false
				if XTianqiAffixRoll.skips_row(row, s, table):
					kept_off = false
				XTianqiAffixRoll.SKIP_HIGH_ROWS = true
	_check("high_rows_count", rows == 18 and items.size() == 7 and luoyun, [rows, items.keys()])
	_check("high_rows_skipped", all_skipped)
	_check("high_rows_switch_off", kept_off)
	# 落芸之力造出来不带混沌神话行（天启篇存档、开关开着）
	var plain_rows_kept := true
	for k in items:
		var parts: PackedStringArray = str(k).split(":")
		var rec := XDB.rec(parts[0], int(parts[1]))
		for row in rec.get("equipment", {}).get("affixes", []):
			var total := 0
			for c in row.get("choices", []):
				total += int(c.get("chance", 0))
			if total >= 100 and XAffixRate.line_tier(row.get("choices", []), parts[0]) == 0 and XTianqiAffixRoll.skips_row(row, s, parts[0]):
				plain_rows_kept = false
	_check("plain_fixed_rows_kept", plain_rows_kept)
	var made := XGear.create("weapon" if str(items.keys()[0]).begins_with("Weapons") else "armor", int(str(items.keys()[0]).split(":")[1]), s)
	var high := false
	for a in made.get("affixIds", []):
		if XAffixRate._quality(XDB.rec(str(a.table), int(a.id))) >= 14:
			high = true
	_check("made_without_high_affix", not made.is_empty() and not high, made.get("affixIds"))


func _honghuang() -> void:
	var s := _tianqi_state()
	_check("honghuang_off", XTianqiTrim.no_honghuang(s) and not XTianqiTrim.no_honghuang(_plain_state()))
	XState.current = s
	_check("hall_events_hidden", [65, 66, 68].all(func(e): return XTianqiTrim.hides(4, e)) and not XTianqiTrim.hides(4, 54) and not XTianqiTrim.hides(5, 65))
	var ev := MVEvent.new()
	ev.map_id = 4
	ev.event_id = 65
	ev.data = {"pages": [{"conditions": {}}]}
	_check("hall_event_no_page", ev._find_page() == -1, ev._find_page())
	ev.free()
	XState.current = _plain_state()
	_check("hall_events_original", not XTianqiTrim.hides(4, 65))
	var empress := [[2, 4543, 0, 0, false], [2, 4555, 0, 0], [2, 5198, 0, 0, false], [2, 5199, 0, 0], [0, 2234, 0, 0, false], [0, 1991, 0, 0]]
	var left := XTianqiTrim.shop_goods(s, 4, 65, empress).map(func(g): return int(g[1]))
	_check("shop_no_sale", left == [4543, 5198, 2234], left)
	var divine := [[2, 4279, 0, 0, false], [2, 4540, 0, 0]]
	var page := XTianqiTrim.shop_goods(s, 4, 54, divine).map(func(g): return [int(g[0]), int(g[1])])
	_check("shop_xiandao_added", page == [[2, 4279], [2, 4540], [2, 5198]], page)
	_check("shop_xiandao_only_divine_page", XTianqiTrim.shop_goods(s, 4, 54, [[0, 2232, 0, 0, false]]).size() == 1)
	_check("shop_original", XTianqiTrim.shop_goods(_plain_state(), 4, 65, empress).size() == empress.size())
	XTianqiTrim.NO_HONGHUANG = false
	_check("honghuang_switch_off", not XTianqiTrim.no_honghuang(s) and XTianqiTrim.shop_goods(s, 4, 54, divine).size() == 2)
	XTianqiTrim.NO_HONGHUANG = true


func _dungeon() -> void:
	var s := _tianqi_state("jiusi")
	var tower := XTianqiCombat.enemy_rates(3, s)
	s.set_variable(XDungeon.VAR_INSIDE, 1)
	var want := {1: 0.5, 2: 0.75, 3: 1.0, 4: 1.5}
	var ok := true
	var got := []
	for t in want:
		s.set_variable(XDungeon.VAR_TIER, t)
		var r := XTianqiCombat.enemy_rates(1, s)
		got.append([t, r[0], r[2], r[4], r[3]])
		ok = ok and _near(float(r[0]), float(tower[0]) * want[t]) and _near(float(r[2]), float(tower[2]) * want[t]) \
			and _near(float(r[4]), float(tower[4]) * want[t]) and _near(float(r[3]), float(tower[3]))
	_check("dungeon_tier_rates", ok, [tower, got])
	XTianqiCombat.DUNGEON_TIER = false
	_check("dungeon_tier_switch_off", XTianqiCombat.enemy_rates(1, s) == tower)
	XTianqiCombat.DUNGEON_TIER = true
	var draft := bool(XTianqiBalance.data().get("dungeon_tiers", {}).get("draft", false))
	_check("dungeon_tier_draft", draft)
	_check("balance_nice_numbers", XTianqiBalance.nice_number_violations().is_empty(), XTianqiBalance.nice_number_violations())


func _routes() -> void:
	var keys := ["xunchang", "jianxian", "jiusi", "lianyu", "zhengdao"]
	var coef := []
	var core := []
	var star := []
	var lottery := []
	var names := []
	for k in keys:
		var s := _tianqi_state(k)
		var r := XZhenqi.route(s)
		coef.append(int(r.coef))
		names.append(str(r.name))
		core.append(XLiuying.core_rate(s))
		star.append(XStarburstBooks.immortal_rate(s))
		var v9 := -1
		for c in XTianqi.opening_commands(1, k, [1]):
			if int(c.code) == 122 and int(c.parameters[0]) == 9:
				v9 = int(c.parameters[4]) if int(c.parameters[2]) == 0 else v9
		lottery.append(v9)
	_check("route_zhenqi_coef", coef == [1, 1, 2, 5, 13], coef)
	_check("route_names", names == ["寻常", "艰险", "九死", "炼狱", "证道"], names)
	_check("route_comp_key", XZhenqi.route(_tianqi_state("zhengdao")).key == "primordial" and XZhenqi.route(_tianqi_state("lianyu")).key == "calamity")
	_check("route_liuying", core.all(func(x): return x is float) and _near(core[0], 0.03) and _near(core[3], 0.03) and _near(core[4], 0.06), core)
	_check("route_starburst", _near(star[0], 1.0 / 66.0) and _near(star[3], 1.0 / 66.0) and _near(star[4], 1.0 / 33.0), star)
	_check("route_lottery_cap", lottery == [5, 5, 10, 17, 22], lottery)
	XTianqiTrim.ROUTE_TABLE = false
	var s2 := _tianqi_state("zhengdao")
	var off := [int(XZhenqi.route(s2).coef), XLiuying.core_rate(s2)]
	XTianqiTrim.ROUTE_TABLE = true
	_check("route_switch_off", off[0] == 1 and _near(off[1], 0.03), off)


func _original() -> void:
	var s := _plain_state()
	_check("original_route", XZhenqi.route(s).key == "normal" and str(XZhenqi.route(s).name) == "普通")
	s.set_switch(2483, true)
	_check("original_route_primordial", XZhenqi.route(s).key == "primordial" and _near(XStarburstBooks.immortal_rate(s), 1.0 / 33.0))
