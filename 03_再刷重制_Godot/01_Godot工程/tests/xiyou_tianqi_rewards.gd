extends Node
## 天启篇奖励专项（XTianqiRewards、tianqi_data/rewards.json）。
## 一、数据：数字避开 4、四条线齐、终焉词条每线 4 条、底子装备存在。
## 二、奖励装备：净印三档、遗物完整／半强度；属性、特性、词缀清空；神器栏收遗物；读档后标记还在。
## 三、发奖流程：天外裂（第一件净印、撑过的额外奖励只发一次）、使徒、35 层影子、36 层骑士（遗物、徽记、核）、再挑战只给核、鸿钧。
## 四、战斗效果：存粮（饥饿消耗／回复）、止戈（火花）、清心（病弱）、长明（死期，终焉无效）；
##    钥匙串（暴击、追加普攻）、雷火弹（受伤、轰炸）、卷子（回复、资历）、混子之盾（双防、出伤、嘲讽）。
## 五、原版档、换过线、开关关掉：不发、不生效。
## 数字避开 4（Kyo 11-11）：用例里的种子、层号照实写。

class FakeHost extends RefCounted:
	var answers: Array = []
	var said: Array = []
	var moves: Array = []
	var battles: Array = []
	var results: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, x: int, y: int, d: int, _fade := 0) -> void:
		moves.append([id, x, y, d])
		XState.current.map_id = id
	func start_battle(troop: int, _can_escape: bool, _can_lose: bool, _random := false) -> int:
		battles.append({"troop": troop, "knight": XTianqiHorsemen.pending(), "mode": XTianqiHorsemen._pending_mode})
		XTianqiFamineAlien._pending = ""
		XTianqiWarAlien._pending = ""
		XTianqiHorsemen._pending = ""
		XTianqiHorsemen._pending_mode = "body"
		XTianqiSummit._pending = ""
		return int(results.pop_front()) if not results.is_empty() else 0


const CONFIG := "user://xiyou_tianqi_rewards_config.json"
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(line := "famine", tough := 0.0) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, 6)
	XState.current = s
	if tough > 0.0:
		for id in lineup:
			var a := s.actor(id)
			a.add_param(0, tough)
			a.add_param(3, 10000.0)
			a.add_param(5, 10000.0)
			a.recover_all()
	if line != "":
		s.flags.tianqi["line"] = line
	return s


func _done(s: XState, line: String) -> void:
	XTianqiLine.progress(line, s)["stage"] = XTianqiLine.stage_done(line)


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return l is Dictionary and l.get("type", "") == "battle_text").map(func(l): return str(l.text))


func _wear(s: XState, a: XActor, item: Dictionary) -> bool:
	s.register_gear(item)
	s.gear.append(item)
	var slot := a.equip_slots().find(int(item.etypeId))
	return slot >= 0 and XEquipment.change(s, a, slot, item)


func _rewards_in(s: XState) -> Array:
	return s.gear.filter(func(e): return not XTianqiRewards.tag(e).is_empty())


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	_data()
	_items()
	await _rift()
	await _apostle()
	await _summit()
	_seal_effects()
	_relic_effects()
	await _plain()
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、数据 ----

func _data() -> void:
	XTianqiRewards.reload()
	var d := XTianqiRewards.data()
	_check("draft", d.get("draft") == true)
	_check("nice_numbers", XTianqiRewards.nice_number_violations().is_empty(), XTianqiRewards.nice_number_violations())
	for line in XTianqiRewards.LINES:
		_check("seal_three_" + line, (XTianqiRewards.seal_info(line).get("values", []) as Array).size() == 3)
		_check("relic_two_" + line, not XTianqiRewards.relic_params(line, false).is_empty() and not XTianqiRewards.relic_params(line, true).is_empty())
		var keys: Array = d.finale.lines.get(line, [])
		_check("finale_four_" + line, keys.size() == 4 and keys.all(func(k): return d.finale.names.has(k)), keys)
	# 原词条键对得上 alienation.json（★ 新词条除外）
	var news := ["dying", "again", "thrift", "venom"]
	var olds := []
	for line in XTianqiRewards.LINES:
		olds.append_array((d.finale.lines[line] as Array).filter(func(k): return not news.has(k)))
	_check("finale_old_keys", olds.size() == 12 and olds.all(func(k): return not XAlienation.affix(str(k)).is_empty()), olds)
	_check("seal_base_necklace", int(XDB.rec("Armors", int(d.seal.base)).get("etypeId", 0)) == int(d.seal.etype) and int(d.seal.etype) == 9)
	_check("relic_base_artifact", int(XDB.rec("Armors", int(d.relic.base)).get("etypeId", 0)) == XTianqiGear.ARTIFACT)
	_check("survival_item", not XDB.rec("Items", int(d.survival.items[0].item)).is_empty())
	# 设计稿的数
	_check("seal_values", XTianqiRewards.seal_value("death", 3) == 33.0 and XTianqiRewards.seal_value("famine", 1) == 10.0
		and XTianqiRewards.seal_value("plague", 3) == 1.0)
	_check("relic_texts", XTianqiRewards.relic_text("plague", false).contains("33%") and XTianqiRewards.relic_text("war", true).contains("8%"),
		[XTianqiRewards.relic_text("plague", false), XTianqiRewards.relic_text("war", true)])


# ---- 二、奖励装备 ----

func _items() -> void:
	var s := _state("famine")
	var seal := XTianqiRewards.make_item("seal", "famine", 2)
	_check("seal_name", str(seal.name) == "净印·存粮（二）", seal.name)
	_check("seal_clean", (seal.params as Array).all(func(v): return float(v) == 0.0) and (seal.traits as Array).is_empty()
		and str(seal.note) == "" and (seal.affixIds as Array).is_empty() and int(seal.etypeId) == 9, [seal.params, seal.traits])
	_check("seal_desc", str(seal.description).contains("15%"), seal.description)
	var relic := XTianqiRewards.make_item("relic", "plague", 0, true)
	_check("relic_half_name", str(relic.name) == "混子之盾（碎）（残）" and XTianqiRewards.is_relic(relic), relic.name)
	_check("relic_allowed", XTianqiGear.allows(relic) and not XTianqiGear.allows(XGear.template("armor", 4537)))
	var a: XActor = s.members()[0]
	_check("relic_wear", _wear(s, a, relic) and a.equip_list().has(relic))
	_check("seal_wear", _wear(s, a, seal) and a.equip_list().has(seal))
	var back := XState.from_dict(s.to_dict())
	var ba: XActor = back.members()[0]
	var tags := ba.equip_list().map(func(e): return XTianqiRewards.tag(e)).filter(func(t): return not t.is_empty())
	_check("saved_tags", tags.size() == 2 and tags.any(func(t): return t.kind == "relic" and t.half == true and t.line == "plague"), tags)


# ---- 三、发奖流程 ----

func _rift() -> void:
	var s := _state("famine")
	var host := FakeHost.new()
	s.gold = 0
	var stone := s.item_count(2873)
	await XTianqiRewards.after_rift(host, s, "famine", true)
	var got := _rewards_in(s)
	_check("rift_seal", got.size() == 1 and int(XTianqiRewards.tag(got[0]).tier) == 1 and str(XTianqiRewards.tag(got[0]).line) == "famine")
	_check("rift_survival", s.gold == 5000 and s.item_count(2873) == stone + 3, [s.gold, s.item_count(2873)])
	_check("rift_said", host.said.any(func(t): return str(t).contains("净印·存粮")) and host.said.any(func(t): return str(t).contains("天外裂")))
	await XTianqiRewards.after_rift(host, s, "famine", true)
	_check("rift_once", _rewards_in(s).size() == 1 and s.gold == 5000)
	# 输了：只给净印
	var l := _state("war")
	l.gold = 0
	await XTianqiRewards.after_rift(FakeHost.new(), l, "war", false)
	_check("rift_lost_seal_only", _rewards_in(l).size() == 1 and l.gold == 0)
	# 走整套开场：天外裂打完就有净印
	var w := _state("war", 20000000.0)
	var h2 := FakeHost.new()
	h2.results = [0, 0, 0]
	await XTianqiLine.run_due(h2, w, "war")
	_check("opening_flow_seal", XTianqiLine.opening_done("war", w) and _rewards_in(w).size() == 1, [XTianqiLine.stage("war", w), _rewards_in(w).size()])


func _apostle() -> void:
	var s := _state("famine")
	_done(s, "famine")
	var host := FakeHost.new()
	var troop := int(XTianqiLine.alien_preset("famine", "apostle20").troop)
	await XTianqiLine.before_battle(host, s, troop)
	XTianqiFamineAlien._pending = ""
	await XTianqiRewards.after_map_battle(host, s, troop, 0)
	var got := _rewards_in(s)
	_check("apostle20_seal", got.size() == 1 and int(XTianqiRewards.tag(got[0]).tier) == 3, got.map(func(e): return e.name))
	# 输了不给、下一场普通战斗不误发
	await XTianqiLine.before_battle(host, s, int(XTianqiLine.alien_preset("famine", "apostle10").troop))
	XTianqiFamineAlien._pending = ""
	await XTianqiRewards.after_map_battle(host, s, 0, 2)
	await XTianqiRewards.after_map_battle(host, s, 11, 0)
	_check("apostle_lost_none", _rewards_in(s).size() == 1)
	# 同一使徒只发一次
	await XTianqiLine.before_battle(host, s, troop)
	XTianqiFamineAlien._pending = ""
	await XTianqiRewards.after_map_battle(host, s, troop, 0)
	_check("apostle_once", _rewards_in(s).size() == 1)


func _summit() -> void:
	var s := _state("famine", 20000000.0)
	_done(s, "famine")
	var host := FakeHost.new()
	host.results = [0]
	var r := await XTianqiLine.run_shadow(host, s, "famine")
	var got := _rewards_in(s)
	_check("shadow_half_relic", r == 0 and got.size() == 1 and XTianqiRewards.tag(got[0]).half == true, got.map(func(e): return e.name))
	_check("shadow_core", XTianqiRewards.cores(s).size() == 1 and XTianqiRewards.data().finale.lines.famine.has(XTianqiRewards.cores(s)[0].affix)
		and XTianqiRewards.cores(s)[0].level == "zhongyan")
	# 36 层：完整遗物、徽记、核
	host.results = [0]
	r = await XTianqiLine.run_final(host, s, "famine")
	got = _rewards_in(s)
	_check("final_full_relic", r == 0 and got.size() == 2 and got.any(func(e): return XTianqiRewards.tag(e).half == false))
	_check("final_badge", XTianqiRewards.badges().has("famine") and host.said.any(func(t): return str(t).contains("饥荒骑士徽记")), XTianqiRewards.badges())
	_check("final_core", XTianqiRewards.cores(s).size() == 2)
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(XConfig.path_override))
	_check("badge_written", cfg is Dictionary and (cfg.get("codexTianqiBadges", []) as Array).has("famine"))
	# 输了什么都不给
	host.results = [2]
	await XTianqiLine.run_final(host, s, "famine")
	_check("final_lost_nothing", _rewards_in(s).size() == 2 and XTianqiRewards.cores(s).size() == 2)
	# 再挑战（终焉试炼）：36、35 层只给核，不再给遗物
	s.set_variable(20, 37)
	XTianqiSummit.progress(s)["cleared"] = true
	XTianqiFamineLine.progress(s)["cleared"] = true
	var opts := XTianqiSummit.rechallenge_options(s)
	if opts.has(36) and opts.has(35):
		host.answers = [opts.find(36)]
		host.results = [0]
		await XTianqiSummit.run_rechallenge(host, s)
		host.answers = [opts.find(35)]
		host.results = [0]
		await XTianqiSummit.run_rechallenge(host, s)
	_check("rechallenge_cores_only", opts.has(36) and opts.has(35) and _rewards_in(s).size() == 2 and XTianqiRewards.cores(s).size() == 4
		and XTianqiRewards.cores(s)[2].from == "rechallenge36" and XTianqiRewards.cores(s)[3].from == "rechallenge35", [opts, XTianqiRewards.cores(s)])
	# 鸿钧
	await XTianqiRewards.after_hongjun(host, s, 0)
	_check("hongjun_core", XTianqiRewards.cores(s).size() == 5 and XTianqiRewards.cores(s)[4].from == "34")
	var back := XState.from_dict(s.to_dict())
	_check("cores_saved", XTianqiRewards.cores(back).size() == 5 and XTianqiRewards.got(back, "relic_famine_full"))


# ---- 四、战斗效果 ----

func _seal_effects() -> void:
	# 存粮：枯竭者消耗 ×1.3 → 三档 ×1.24（减轻 20%）
	var s := _state("famine", 20000000.0)
	_check("prep_omen", XTianqiFamineAlien.prepare("omen", s))
	var lg := XBattleLogic.new()
	lg.setup(11, s)
	var a: XActor = lg.actors[0]
	_check("famine_base", _near(XTianqiFamineAlien.cost_mult(lg), 1.3))
	_wear(s, a, XTianqiRewards.make_item("seal", "famine", 3))
	_check("famine_cost", _near(XTianqiRewards.famine_cost_mult(a, 1.3), 1.24) and _near(XTianqiRewards.famine_cost_mult(lg.actors[1], 1.3), 1.3))
	_check("famine_heal", _near(XTianqiRewards.famine_heal_mult(a, 0.5), 0.6))
	var c := lg.skill_cost(a, {"id": 99999, "mpCost": 100, "tpCost": 0, "stypeId": 1, "note": "", "damage": {"type": 0}})
	_check("famine_cost_hooked", int(c.get("mp", 0)) in [124, 123], c)
	lg.end_battle(0)
	# 战争线存档里穿饥荒净印：不生效
	var w := _state("war")
	var wa: XActor = w.members()[0]
	_wear(w, wa, XTianqiRewards.make_item("seal", "famine", 3))
	_check("other_line_seal_off", XTianqiRewards.seal_tier(wa, "famine") == 0)
	# 止戈：三档 33%，100 次大约 67 点
	_wear(w, wa, XTianqiRewards.make_item("seal", "war", 3))
	var wl := XBattleLogic.new()
	wl.setup(11, w)
	var n := XTianqiRewards.spark_gain(wl, 100)
	_check("war_spark", n > 50 and n < 80, n)
	wl.end_battle(0)
	# 清心：病弱 3% → 1%
	var p := _state("plague")
	var pa: XActor = p.members()[0]
	_check("plague_frail_none", _near(XTianqiRewards.frail_per(pa, 0.03), 0.03))
	_wear(p, pa, XTianqiRewards.make_item("seal", "plague", 3))
	_check("plague_frail", _near(XTianqiRewards.frail_per(pa, 0.03), 0.01))
	# 长明：三档 33%；终焉无效
	var d := _state("death", 20000000.0)
	var dl := XBattleLogic.new()
	dl.setup(11, d)
	var da: XActor = dl.actors[0]
	_wear(d, da, XTianqiRewards.make_item("seal", "death", 3))
	var spared := 0
	for i in range(100):
		da.hp = da.mhp
		if XTianqiRewards.doom_spared(dl, da, false):
			spared += 1
	_check("death_spared", spared > 15 and spared < 50, spared)
	da.hp = 1000.0
	var finale_spared := false
	for i in range(30):
		finale_spared = finale_spared or XTianqiRewards.doom_spared(dl, da, true)
	_check("death_finale_immune", not finale_spared and _near(da.hp, 1000.0))
	dl.end_battle(0)


func _relic_effects() -> void:
	var s := _state("war", 20000000.0)
	var a: XActor = s.members()[0]
	var b: XActor = s.members()[1]
	var c: XActor = s.members()[2]
	var d: XActor = s.members()[3]
	_wear(s, a, XTianqiRewards.make_item("relic", "war", 0, false))
	_wear(s, b, XTianqiRewards.make_item("relic", "plague", 0, false))
	_wear(s, c, XTianqiRewards.make_item("relic", "famine", 0, false))
	_wear(s, d, XTianqiRewards.make_item("relic", "death", 0, false))
	var def0 := b.param(3)
	var lg := XBattleLogic.new()
	lg.setup(11, s)
	_check("relic_fight", not XTianqiRewards._fight(lg).is_empty())
	var e: XEnemy = lg.enemies[0]
	# 雷火弹：受伤 +15%
	_check("war_taken", _near(XTianqiRewards.hp_damage(lg, e, a, 1000.0), 1150.0))
	# 混子之盾：出伤 −22%、双防 +33%、第 1 回合嘲讽
	_check("plague_dealt", _near(XTianqiRewards.hp_damage(lg, b, e, 1000.0), 780.0))
	b.param_refresh()
	_check("plague_def", _near(XTianqiRewards.actor_param(b, 3, 1000.0), 1330.0) and _near(XTianqiRewards.actor_param(b, 2, 1000.0), 1000.0)
		and b.param(3) > def0 * 1.3, [def0, b.param(3)])
	lg.turn = 1
	_check("plague_taunt", XTianqiRewards.filter_targets(lg, e, [a, b, c]) == [b])
	lg.turn = 2
	_check("plague_taunt_ends", XTianqiRewards.filter_targets(lg, e, [a, b, c]).size() == 3)
	# 卷子：受到的回复 −33%；技能击倒攒资历，10 层全属性 +3%
	_check("famine_relic_heal", _near(XTianqiRewards.hp_damage(lg, e, c, -1000.0), -670.0), XTianqiRewards.hp_damage(lg, e, c, -1000.0))
	var sk := {"id": 99999, "damage": {"type": 1}}
	var atk0 := c.param(2)
	for i in range(10):
		e.hp = 10.0
		XTianqiRewards.hp_damage(lg, c, e, 100.0, sk)
	e.hp = e.mhp
	_check("famine_stacks", int(c.get_meta(XTianqiRewards.META).stacks) == 10)
	_check("famine_stat", _near(XTianqiRewards.actor_param(c, 2, 1000.0), 1030.0) and c.param(2) > atk0, [atk0, c.param(2)])
	e.hp = 10.0
	XTianqiRewards.hp_damage(lg, c, e, 100.0, c.attack_skill())
	e.hp = e.mhp
	_check("famine_attack_no_stack", int(c.get_meta(XTianqiRewards.META).stacks) == 10)
	# 钥匙串：暴击率归零；每回合第一次放技能追加普攻
	_check("death_crit", XTianqiRewards.cri_mult(d) == 0.0 and XTianqiRewards.cri_mult(a) == 1.0)
	lg.turn = 3
	var logs := XTianqiRewards.after_action(lg, d, XDB.rec("Skills", 3))
	_check("death_extra", logs.any(func(l): return l is Dictionary and l.get("type", "") == "hit") and _texts(logs).any(func(t): return t.contains("追加")), logs.size())
	logs = XTianqiRewards.after_action(lg, d, XDB.rec("Skills", 3))
	_check("death_extra_once", not logs.any(func(l): return l is Dictionary and l.get("type", "") == "hit"))
	logs = XTianqiRewards.after_action(lg, d, d.attack_skill())
	_check("death_attack_no_extra", logs.is_empty())
	# 雷火弹：第 10 次行动轰炸全体
	var hits := 0
	for i in range(10):
		logs = XTianqiRewards.after_action(lg, a, a.attack_skill())
		hits += logs.filter(func(l): return l is Dictionary and l.get("type", "") == "hit").size()
	var live := lg.enemies.filter(func(x): return not x.hidden).size()
	_check("war_bomb", hits >= 1 and hits <= live, [hits, live])
	lg.end_battle(0)
	_check("relic_fight_cleared", XTianqiRewards._fight(lg).is_empty() and not c.has_meta(XTianqiRewards.META))


# ---- 五、原版档、开关 ----

func _plain() -> void:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var p := XState.new_game_blank()
	for id in lineup:
		p.add_actor(int(id))
	XState.current = p
	await XTianqiRewards.after_rift(FakeHost.new(), p, "famine", true)
	_check("plain_no_grant", _rewards_in(p).is_empty() and XTianqiRewards.grant_core(p, "famine", "36").is_empty())
	var pa: XActor = p.members()[0]
	var relic := XTianqiRewards.make_item("relic", "death", 0, false)
	p.register_gear(relic)
	pa.equips[pa.equip_slots().find(17)] = relic
	_check("plain_no_effect", XTianqiRewards.cri_mult(pa) == 1.0)
	# 开关关掉：天启篇存档也不发、不生效
	var s := _state("death")
	var a: XActor = s.members()[0]
	_wear(s, a, XTianqiRewards.make_item("relic", "death", 0, false))
	XTianqiRewards.ENABLED = false
	_check("switch_off", XTianqiRewards.grant_seal(s, "death", "opening").is_empty() and XTianqiRewards.cri_mult(a) == 1.0)
	XTianqiRewards.ENABLED = true
	_check("switch_on_again", XTianqiRewards.cri_mult(a) == 0.0)
