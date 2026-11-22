extends Node
## 战中「本场规则」条专项（T386 / K1b；设计稿 T254_战中规则条.md，文字照小A 文字审定稿 T387）。
## 核：
##   一、四骑士（本体四线、生存战、骑士之影）规则齐全，与战斗日志逐条对上（死期点名、终末、兵临、配方、疫病、混子之盾、骑士队长）；
##   二、四线异化（每线全部种类）＋线规则（交锋、口粮、荒年、病弱）；
##   三、七印七条规则（里副本）＋七印书卷：名字、O1 图标号、读数（寂静双数回合沉默中、星坠倒数、限时已用、献祭哪方）；
##   四、只读：collect 前后战斗随机数流 draws 不变、规则条打开期间回合结果不变；
##   五、XTianqiBattleRules.ENABLED=false：collect 为空、XSkinRuleStrip.make 不建；西游档同样为空、不建；新界面关不建；
##   六、折叠态排版：16:9、20:9、130% 字号下不压 B 印盘（y ≥ 142）、不过血弧限宽、详卡下沿 ≤ 618；溢出 +N。
## 反例：把 XTianqiHorsemen.battle_rules 的死期点名去掉、或把 make() 的开关判断去掉，本专项会挂（见交付单「反向验证」）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(line := "war", floor_no := 32) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor_no)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	for id in lineup:
		var a := s.actor(id)
		a.add_param(0, 2.0e9)
		a.add_param(3, 10000.0)
		a.add_param(5, 10000.0)
		a.recover_all()
	XTianqiQiyin.set_current("")
	return s


func _guard_all(lg: XBattleLogic) -> Dictionary:
	var c := {}
	for a in lg.actors:
		c[a] = [XDB.rec("Skills", 2), null]
	return c


func _by_id(rules: Array) -> Dictionary:
	var out := {}
	for r in rules:
		out[str(r.id)] = r
	return out


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return l is Dictionary and str(l.get("type", "")) == "battle_text").map(func(l): return str(l.text))


func _any(texts: Array, frag: String) -> bool:
	return texts.any(func(t): return str(t).contains(frag))


## 只读：collect 不动随机数流
func _collect_pure(lg: XBattleLogic) -> Array:
	var d0 := int(lg._rule().draws)
	var rules := XTianqiBattleRules.collect(lg)
	_check("pure_draws_%d" % results.size(), int(lg._rule().draws) == d0, [d0, int(lg._rule().draws)])
	return rules


func _fields_ok(rules: Array) -> bool:
	for r in rules:
		for k in ["id", "source", "name", "summary", "tone", "priority", "counter", "icon", "countdown", "value", "max_value", "badge", "detail_extra"]:
			if not r.has(k):
				return false
		if str(r.name) == "" or str(r.summary) == "" or not str(r.tone) in ["warn", "buff", "line", "gold"]:
			return false
		if str(r.summary).contains("几率") or str(r.counter).contains("蓝") or str(r.counter).contains(" -") or str(r.counter).begins_with("-"):
			return false
	return true


func _run() -> void:
	TestEnv.isolate("xiyou_tianqi_battle_rules")
	XMessageBox.auto = true
	seed(20261122)
	_horsemen()
	_aliens()
	_qiyin()
	_switches()
	_layout()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、四骑士 ----

func _knight(line: String, mode := "body") -> XBattleLogic:
	var s := _state(line)
	XTianqiHorsemen.prepare(line, s, mode)
	var lg := XBattleLogic.new()
	lg.setup(0, s)
	return lg


func _horsemen() -> void:
	# 死亡·勇者本体：跑回合，死期点名的日志 ↔ 规则条「本回合末」＋点名；终末、骑士队长、神圣剑
	var lg := _knight("death")
	var ids := _by_id(_collect_pure(lg))
	_check("death_has_doom", ids.has("horsemen:death:doom") and ids.has("horsemen:death:holy_sword"), ids.keys())
	_check("death_fields", _fields_ok(ids.values()))
	_check("death_source", XTianqiBattleRules.source_label(lg).begins_with("骑士战"), XTianqiBattleRules.source_label(lg))
	var doom_matched := 0
	var sword_seen := false
	var f := XTianqiHorsemen.fight(lg)
	for i in range(12):
		lg.start_turn()
		var texts := _texts(lg.take_turn_start_logs())
		var rules := _by_id(_collect_pure(lg))
		for t in texts:
			if t.begins_with("死期：") and t.contains("会在本回合结束时死去"):
				var who: String = t.trim_prefix("死期：").split("会在")[0]
				var d: Dictionary = rules.get("horsemen:death:doom", {})
				if str(d.get("counter", "")) == "本回合末" and str(d.get("detail_extra", "")).contains(who) and str(d.tone) == "warn":
					doom_matched += 1
			if t.contains("的剑指向了"):
				var target: String = t.split("的剑指向了")[1].split("（")[0]
				var hs: Dictionary = rules.get("horsemen:death:holy_sword", {})
				sword_seen = str(hs.get("detail_extra", "")) == "剑锋指向：" + target and str(hs.counter).begins_with("下回合")
		# 不跑完整回合（不让人死），回合末结算只清死期标记
		for a in lg.actors:
			XTianqiHorsemen._mark(f, a).erase("doom")
	_check("death_doom_log_match", doom_matched >= 2, doom_matched)
	_check("death_sword_log_match", sword_seen)
	# 第 3 阶段：终末叠层的日志 ↔ 3 / 5 进度槽；变身骑士队长 ↔ 禁逃跑
	f.knight.hp = f.knight.mhp * 0.2
	lg.start_turn()
	var t2 := _texts(lg.take_turn_start_logs())
	var r2 := _by_id(_collect_pure(lg))
	_check("death_captain_log", _any(t2, "变身骑士队长") and str(r2.get("horsemen:death:captain", {}).get("counter", "")) == "禁逃跑", [t2, r2.keys()])
	_check("death_finale_appears", r2.has("horsemen:death:finale") and str(r2["horsemen:death:finale"].counter) == "0 / 5" and float(r2["horsemen:death:finale"].max_value) == 5.0)
	var et := _texts(lg.end_turn())
	var r3 := _by_id(_collect_pure(lg))
	_check("death_finale_log_match", _any(et, "终末 1／5") and str(r3["horsemen:death:finale"].counter) == "1 / 5", [et, r3.get("horsemen:death:finale", {}).get("counter")])
	lg.end_battle(2)
	# 战争·莉co：开场兵临日志 ↔ 兵临条、配方条
	lg = _knight("war")
	var logs := _texts(lg.take_turn_start_logs())
	ids = _by_id(_collect_pure(lg))
	_check("war_reinforce_log_match", _any(logs, "兵临：援军到了") and str(ids.get("horsemen:war:reinforce", {}).get("detail_extra", "")).begins_with("在场援军：3 / 5"), [logs, ids.get("horsemen:war:reinforce", {}).get("detail_extra")])
	_check("war_reinforce", ids.has("horsemen:war:reinforce") and str(ids["horsemen:war:reinforce"].detail_extra).begins_with("在场援军："), ids.keys())
	_check("war_layer", ids.has("horsemen:war:layer") and str(ids["horsemen:war:layer"].summary).contains("连珠爆竹"))
	_check("war_fields", _fields_ok(ids.values()))
	var wf := XTianqiHorsemen.fight(lg)
	wf.knight.hp = wf.knight.mhp * 0.6
	lg.start_turn()
	var wt := _texts(lg.take_turn_start_logs())
	var wr := _by_id(_collect_pure(lg))
	var layer_log := wt.filter(func(t): return t.contains("火药配方第"))
	_check("war_layer_log_match", not layer_log.is_empty() and str(wr["horsemen:war:layer"].counter) == "%d 层" % int(wf.layer) and str(layer_log[-1]).contains("第 %d 层" % int(wf.layer)), [layer_log, wr["horsemen:war:layer"].counter])
	lg.end_battle(2)
	# 饥荒：绝粮、资历、结党
	lg = _knight("famine")
	ids = _by_id(_collect_pure(lg))
	_check("famine_rules", ids.has("horsemen:famine:starve") and ids.has("horsemen:famine:seniority") and ids.has("horsemen:famine:devour")
		and str(ids["horsemen:famine:starve"].counter) == "禁回 MP／TP", ids.keys())
	lg.end_battle(2)
	# 瘟疫：开场「瘟疫笼罩」日志 ↔ 疫病条（−10%，真减号）；1 阶段嘲讽；二阶段「混子之盾出现了」↔ 盾条
	lg = _knight("plague")
	logs = _texts(lg.take_turn_start_logs())
	ids = _by_id(_collect_pure(lg))
	_check("plague_log_match", _any(logs, "瘟疫笼罩了战场") and str(ids.get("horsemen:plague:plague", {}).get("counter", "")) == "−10%", [logs, ids.get("horsemen:plague:plague", {}).get("counter")])
	_check("plague_taunt_p1", str(ids.get("horsemen:plague:shield", {}).get("counter", "")) == "嘲讽中")
	_check("plague_defiance", ids.has("horsemen:plague:defiance") and str(ids["horsemen:plague:defiance"].counter) == "最高 0 / 6")
	var pf := XTianqiHorsemen.fight(lg)
	pf.knight.hp = pf.knight.mhp * 0.5
	lg.start_turn()
	var pt := _texts(lg.take_turn_start_logs())
	ids = _by_id(_collect_pure(lg))
	_check("plague_shield_log_match", _any(pt, "混子之盾出现了") and str(ids["horsemen:plague:shield"].name) == "混子之盾" and float(ids["horsemen:plague:shield"].max_value) > 0.0, [pt, ids["horsemen:plague:shield"]])
	pf.broken_turn = int(lg.turn)
	ids = _by_id(_collect_pure(lg))
	_check("plague_shield_broken", str(ids["horsemen:plague:shield"].name) == "盾碎" and str(ids["horsemen:plague:shield"].tone) == "buff")
	lg.end_battle(2)
	# 生存战（战争）：生存战条＋火花
	lg = _knight("war", "survival")
	ids = _by_id(_collect_pure(lg))
	_check("survival_rules", ids.has("horsemen:survival:turns") and ids.has("horsemen:war:survival_sparks") and not ids.has("horsemen:war:layer"), ids.keys())
	_check("survival_source", XTianqiBattleRules.source_label(lg) == "骑士战 · 生存战")
	lg.end_battle(2)
	# 骑士之影（死亡）：死之终焉、没有回合开始的死期
	lg = _knight("death", "shadow")
	ids = _by_id(_collect_pure(lg))
	_check("shadow_rules", ids.has("horsemen:death:shadow_no_revive") and not ids.has("horsemen:death:doom"), ids.keys())
	_check("shadow_source", XTianqiBattleRules.source_label(lg) == "骑士战 · 骑士之影")
	lg.end_battle(2)


# ---- 二、四线异化 ----

func _alien_fight(line: String, kinds: Array, tier := "huaxing") -> XBattleLogic:
	var s := _state(line)
	var lg := XBattleLogic.new()
	lg.setup(187, s)
	var list := []
	var foes := lg.enemies.filter(func(e): return not e.hidden)
	for i in kinds.size():
		list.append({"enemy": foes[i % foes.size()], "tier": tier, "kind": kinds[i]})
	XTianqiLine.alien_apply(line, lg, s, list)
	return lg


func _aliens() -> void:
	var want := {"war": ["alien:war:clash"], "famine": ["alien:famine:ration", "alien:famine:lean_year"], "plague": ["alien:plague:frail"], "death": []}
	var mods := {"war": XTianqiWarAlien, "famine": XTianqiFamineAlien, "plague": XTianqiPlagueAlien, "death": XTianqiDeathAlien}
	for line in ["war", "famine", "plague", "death"]:
		var kinds: Array = XTianqiLine.alien_kinds(line)
		# 敌群可能不够每种一只：每种单独开一场
		var all_ok := true
		var miss := []
		for k in kinds:
			var lg := _alien_fight(line, [k])
			if not mods[line].active(lg):
				all_ok = false
				miss.append([k, "inactive"])
				continue
			var ids := _by_id(_collect_pure(lg))
			var key := "alien:%s:%s" % [line, k]
			if not ids.has(key) or str(ids[key].badge) != "化形":
				all_ok = false
				miss.append([k, ids.keys()])
			for w in want[line]:
				if not ids.has(w):
					all_ok = false
					miss.append([w, ids.keys()])
			if not _fields_ok(ids.values()):
				all_ok = false
				miss.append([k, "fields"])
			if XTianqiBattleRules.source_label(lg) != "异化 · " + str(XTianqiBattleRules.LINE_NAMES[line]):
				all_ok = false
				miss.append([k, XTianqiBattleRules.source_label(lg)])
			lg.end_battle(2)
		_check("alien_%s_kinds" % line, all_ok and not kinds.is_empty(), miss)
	# 死亡·丧钟：日志「丧钟还剩 N 回合」↔ 读数；终焉角标
	var dl := _alien_fight("death", ["knell"], "zhongyan")
	var texts := _texts(dl.take_turn_start_logs() + XTianqiDeathAlien.take_logs(dl))
	var ids := _by_id(_collect_pure(dl))
	var n := int(XTianqiDeathAlien.kind_info("knell").count[3])
	_check("death_knell_log_match", _any(texts, "丧钟还剩 %d 回合" % n) and str(ids["alien:death:knell"].counter) == XTianqiBattleRules.countdown_text(n)
		and str(ids["alien:death:knell"].badge) == "终焉", [texts, ids["alien:death:knell"].counter])
	dl.end_battle(2)
	# 替身次数用尽：条目移除
	var db := _alien_fight("death", ["double"], "huaxing")
	for e in XTianqiDeathAlien.fight(db).units:
		XTianqiDeathAlien.fight(db).units[e]["used"] = 99
	_check("double_used_up_removed", not _by_id(_collect_pure(db)).has("alien:death:double"))
	db.end_battle(2)
	# 终焉传染者：句子不出「全部 个」
	var ct := _alien_fight("plague", ["contagion"], "zhongyan")
	var cs := str(_by_id(_collect_pure(ct))["alien:plague:contagion"].summary)
	_check("contagion_finale_text", cs.begins_with("每回合末将身上全部减益传染给队友。"), cs)
	ct.end_battle(2)
	# 战争·交锋：第 3 回合起伤害 +10%
	var wl := _alien_fight("war", ["berserk"])
	_check("war_clash_before", str(_by_id(_collect_pure(wl))["alien:war:clash"].counter) == "第 3 回合起")
	wl.turn = 4
	_check("war_clash_after", str(_by_id(_collect_pure(wl))["alien:war:clash"].counter) == "伤害 +20%", _by_id(_collect_pure(wl))["alien:war:clash"].counter)
	wl.end_battle(2)


# ---- 三、七印 ----

func _qy(lg: XBattleLogic) -> Dictionary:
	var l := _collect_pure(lg).filter(func(r): return str(r.source) == "qiyin")
	return l[0] if l.size() == 1 else {}

func _qiyin() -> void:
	var s := _state("war", 36)
	var icons := []
	var names_ok := true
	for seal in XTianqiQiyinArt.SEALS:
		XTianqiQiyin.set_current(seal)
		XTianqiQiyinRule.prepare(seal, false, {})
		var lg := XBattleLogic.new()
		lg.setup(187, s)
		var info := XTianqiQiyin.seal_info(seal)
		var rules := _collect_pure(lg).filter(func(r): return str(r.source) == "qiyin")  # 31～36 层的里副本也可能按段异化，只看七印那条
		var logs := _texts(lg.take_turn_start_logs())
		if rules.size() != 1 or str(rules[0].name) != str(info.rule_name) or str(rules[0].summary) != str(info.rule_text) or not _any(logs, "【%s】" % str(info.rule_name)):
			names_ok = false
		icons.append(int(rules[0].icon) if rules.size() == 1 else -1)
		if seal == "mo":
			lg.start_turn()
			var r1: Dictionary = _qy(lg)
			lg.start_turn()
			var t2 := _texts(lg.take_turn_start_logs())
			var r2: Dictionary = _qy(lg)
			_check("silence_odd", str(r1.counter) == "下回合沉默" and int(r1.countdown) == 1, r1.counter)
			_check("silence_even_log_match", _any(t2, "寂静：") and str(r2.counter) == "沉默中" and str(r2.tone) == "warn", [t2, r2.counter])
			_check("silence_source", XTianqiBattleRules.source_label(lg) == "默印 · 里副本", XTianqiBattleRules.source_label(lg))
		if seal == "zhen":
			lg.start_turn()
			var z1: Dictionary = _qy(lg)
			lg.start_turn()
			var z2: Dictionary = _qy(lg)
			lg.start_turn()
			var zt := _texts(lg.take_turn_start_logs())
			var z3: Dictionary = _qy(lg)
			_check("star_fall_countdown", str(z1.counter) == "2 回合后" and str(z2.counter) == "下回合" and str(z3.counter) == "本回合已落" and _any(zt, "星坠："), [z1.counter, z2.counter, z3.counter, zt])
		if seal == "hei":
			XTianqiQiyinRule.fight(lg).skills_used = 4
			var e: Dictionary = _qy(lg)
			_check("exam_used", str(e.counter) == "已用 4 / 5" and str(e.tone) == "warn" and float(e.max_value) == 5.0, e.counter)
		if seal == "xun":
			lg.start_turn()
			var x: Dictionary = _qy(lg)
			var side := str(XTianqiQiyinRule.fight(lg).side_bonus)
			_check("sacrifice_side", (side == "actor" and str(x.counter) == "我方伤害 +10%") or (side == "enemy" and str(x.counter) == "敌方伤害 +10%"), [side, x.counter])
		lg.end_battle(2)
	_check("qiyin_names_texts", names_ok)
	_check("qiyin_icons", icons == [310500, 310501, 310502, 310503, 310504, 310505, 310506], icons)
	# 七印书卷：同一条规则、带「七印书卷」角标与作用对象
	XTianqiQiyin.set_current("")
	var sl := XBattleLogic.new()
	sl.setup(187, s)
	XTianqiQiyinEffects._store(sl).scroll_rule = "zhen"
	XTianqiQiyinRule.take_logs(sl)
	var br := _collect_pure(sl).filter(func(r): return str(r.source) == "qiyin")  # 同场可能还按段异化（随机），只看书卷那条
	_check("scroll_rule", br.size() == 1 and str(br[0].badge) == "七印书卷" and str(br[0].detail_extra).begins_with("作用对象：") and int(br[0].icon) == 310505, br)
	_check("scroll_source", XTianqiBattleRules.source_label(sl) == "七印书卷")
	sl.end_battle(2)


# ---- 五、开关、西游档 ----

func _switches() -> void:
	XUiSkin.FORCE = true
	var lg := _knight("death")
	var toggles := Control.new()
	var made := XSkinRuleStrip.make(lg, toggles, Vector2.ZERO)
	_check("make_on", made != null)
	if made != null:
		made.free()
	XTianqiBattleRules.ENABLED = false
	_check("off_collect_empty", XTianqiBattleRules.collect(lg).is_empty() and XTianqiBattleRules.source_label(lg) == "")
	_check("off_no_strip", XSkinRuleStrip.make(lg, toggles, Vector2.ZERO) == null)
	XTianqiBattleRules.ENABLED = true
	XUiSkin.FORCE = false
	var skin_off := not XUiSkin.on()
	_check("skin_off_no_strip", not skin_off or XSkinRuleStrip.make(lg, toggles, Vector2.ZERO) == null)
	XUiSkin.FORCE = true
	lg.end_battle(2)
	# 西游档：同一场敌群，规则空、不建
	var xs := XState.new_game(3, 8, [9])
	XState.current = xs
	XTianqiHorsemen.prepare("death", xs)
	XTianqiQiyinRule.prepare("mo", false, {})
	var xl := XBattleLogic.new()
	xl.setup(187, xs)
	_check("xiyou_collect_empty", XTianqiBattleRules.collect(xl).is_empty())
	_check("xiyou_no_strip", XSkinRuleStrip.make(xl, toggles, Vector2.ZERO) == null)
	xl.end_battle(2)
	toggles.free()


# ---- 六、排版 ----

func _strip(lg: XBattleLogic, org: Vector2, toggle_x: float, arc: bool) -> XSkinRuleStrip:
	var t := Control.new()
	t.position = Vector2(toggle_x, 60)
	t.size = Vector2(166, 74)
	add_child(t)
	var st := XSkinRuleStrip.make(lg, t, org)
	st.arc_source = func(): return arc
	t.add_child(st)   # 挂在 toggles 下，一起释放
	return st


func _drop(st: XSkinRuleStrip) -> void:
	if st != null and is_instance_valid(st):
		var t := st.get_parent()
		t.remove_child(st)
		st.free()
		t.free()


func _layout() -> void:
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var cases := [["16x9", Vector2.ZERO, 20.0], ["20x9", Vector2(160, 0), 56.0]]
	for big in [false, true]:
		XFontScale.set_value("global", 130 if big else 100)
		for c in cases:
			var tag := "%s%s" % [c[0], "_130" if big else ""]
			# 骑士战（多条）有血弧：双行，不压印盘、不过限宽
			var lg := _knight("death")
			XTianqiHorsemen.fight(lg).knight.hp = XTianqiHorsemen.fight(lg).knight.mhp * 0.2
			lg.start_turn()
			XTianqiHorsemen.fight(lg).captain = true
			var st := _strip(lg, c[1], c[2], true)
			st.refresh()
			var p := st.plan()
			var org: Vector2 = c[1]
			var ok: bool = not bool(p.hero) and p.chips.size() >= 1
			var bad := []
			for ch in p.chips:
				var r: Rect2 = ch.rect
				var row1: bool = r.position.y < org.y + 98.0
				var lim := org.x + (XSkinRuleStrip.ARC_LIMIT1 if row1 else XSkinRuleStrip.ARC_LIMIT2)
				if r.end.y > org.y + 142.0 or r.end.x > lim + 0.5 or r.position.x < c[2] + 166.0:
					bad.append([ch.id, r])
			if int(p.overflow) > 0 and (p.plus.end.x > org.x + XSkinRuleStrip.ARC_LIMIT2 + 0.5 or p.plus.end.y > org.y + 142.0):
				bad.append(["plus", p.plus])
			if p.head.end.y > org.y + 142.0 or p.head.position.y < org.y + 50.0:
				bad.append(["head", p.head])
			var row1: Array = p.chips.filter(func(ch): return ch.rect.position.y < org.y + 98.0)
			_check("row1_not_empty_" + tag, big or not row1.is_empty(), [p.chips.map(func(ch): return [ch.id, ch.rect])])
			_check("z_index_" + tag, st.z_index > XBattleScene.POPUP_Z and st.z_index < 10, st.z_index)
			_check("layout_knight_" + tag, ok and bad.is_empty() and int(p.overflow) + p.chips.size() == st.rules.size(), [bad, p.chips.size(), p.overflow, st.rules.size()])
			# 详卡：下沿 ≤ 618、贴左
			st.set_open(true)
			st._update_drawer_anim()
			var dr := st.drawer_rect()
			_check("drawer_" + tag, dr.end.y <= org.y + 618.0 + 0.5 and is_equal_approx(dr.position.x, c[2]) and is_equal_approx(dr.position.y, org.y + 142.0)
				and is_equal_approx(dr.size.x, 420.0 if big else 368.0), dr)
			# 不截断：每条说明的折行拼回去等于原文（小A T386 核 P1-2）
			var items: Array = st._layout_items(dr.size.x)
			var full := true
			for k in st.rules.size():
				if "".join(items[k].sum) != str(st.rules[k].summary).replace("\n", ""):
					full = false
			_check("no_truncate_" + tag, full)
			# 上层页开着：不吃 R、详卡收起
			var blocked := [true]
			st.input_blocked = func(): return blocked[0]
			var ev := InputEventKey.new()
			ev.keycode = KEY_R
			ev.pressed = true
			_check("blocked_no_toggle_" + tag, not st.try_toggle_input(ev))
			st._process(0.0)
			_check("blocked_closes_" + tag, not st.open)
			blocked[0] = false
			st.set_open(false)
			_drop(st)
			lg.end_battle(2)
			# 七印（1 条）：单条英雄态，竖直居中于圆钮
			var s := _state("war", 36)
			XTianqiQiyin.set_current("mo")
			XTianqiQiyinRule.prepare("mo", true, {})
			XTianqiSegAlien.ENABLED = false  # 里副本也会按段异化（随机），这里只看单条英雄态
			var ql := XBattleLogic.new()
			ql.setup(187, s)
			XTianqiSegAlien.ENABLED = true
			var qs := _strip(ql, c[1], c[2], false)
			qs.refresh()
			var qp := qs.plan()
			var hr: Rect2 = qp.chips[0].rect if not qp.chips.is_empty() else Rect2()
			_check("hero_" + tag, bool(qp.hero) and absf(hr.get_center().y - (org.y + 97.0)) <= 0.5 and hr.end.y < org.y + 142.0 and is_equal_approx(hr.position.x, c[2] + 166.0 + 16.0), hr)
			_drop(qs)
			XTianqiQiyin.set_current("")
			ql.end_battle(2)
	XFontScale.set_value("global", 100)
	# 只读：规则条开着跑两回合，与不开时的结果一致
	var hp_a := _turns_with_strip(true)
	var hp_b := _turns_with_strip(false)
	_check("strip_no_effect_on_battle", hp_a == hp_b, [hp_a, hp_b])
	XUiSkin.motion_override = -1
	XUiSkin.FORCE = false


func _turns_with_strip(with_strip: bool) -> Array:
	var lg := _knight("war")
	lg.random = XBattleRandom.create("0123012301230123")
	var st: XSkinRuleStrip = _strip(lg, Vector2.ZERO, 20.0, true) if with_strip else null
	for i in range(3):
		if st != null:
			st.refresh()
			st.plan()
		lg.run_turn(_guard_all(lg))
	var out := (lg.actors + lg.enemies).map(func(b): return snappedf(float(b.hp), 1.0))
	_drop(st)
	lg.end_battle(2)
	return out
