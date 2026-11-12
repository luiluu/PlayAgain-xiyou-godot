extends Node
## 天启篇七首之龙流程与七印演出专项（XTianqiQiyinDragonRun、XTianqiQiyinShow、qiyin_dragon_run.json、qiyin_show.json）。
## 一、数据：数字避开 4、借的敌群／敌人在、七印颜色齐。
## 二、龙隙：里副本 Boss 打赢后判定、演出、当场问；存着、祭坛菜单进；原版档、开关关掉不判。
## 三、战斗：借普拉顿换名、本档最大生命、每回合 3 次行动；开场揭白印、断首揭下一道、段底锁伤害、灰印缓期（到点倒下、断首解除）、第六首揭默印。
## 四、奖励：自选印真印套装件进印库（红光）、龙血、首杀多招一人（只一次）；输了龙隙合上。
## 五、龙血：每人最多 3 瓶，全属性 +3%／瓶；原版档不加。
## 六、演出：掉落、揭开、神器、龙隙都记一条；真的场景节点上跑一遍不报错。
## 数字避开 4（Kyo 11-11）：用例里的敌群号、敌人号照实写。

class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	var battles: Array = []
	var results: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, lines: Array, options: Array, _cancel: int) -> int:
		said.append_array(lines)
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, _x: int, _y: int, _d: int, _fade := 0) -> void:
		XState.current.map_id = id
	func start_battle(troop: int, can_escape: bool, can_lose: bool, _random := false) -> int:
		battles.append({"troop": troop, "escape": can_escape, "lose": can_lose,
			"dragon": XTianqiQiyinDragonRun.pending().duplicate(true), "rule": XTianqiQiyinRule.pending().duplicate(true)})
		XTianqiQiyinRule._pending = {}
		XTianqiQiyinDragonRun._pending = {}
		return int(results.pop_front()) if not results.is_empty() else 0


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(floor := 36, difficulty := "jianxian") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, difficulty, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor)
	XState.current = s
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = XRandomStream.create("0123012301230123", "qiyin")
	XTianqiQiyinDragonRun.rng_override = XRandomStream.create("3210321032103210", "qiyin_dragon")
	XTianqiQiyinShow.played = []
	return s


func _has(host: FakeHost, text: String) -> bool:
	return host.said.any(func(t): return str(t).contains(text))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XSave.dir_override = "user://test_xiyou_tianqi_qiyin_dragon_run"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	DirAccess.remove_absolute(XSave.dir_override.path_join("global.json"))
	_data()
	await _rift()
	await _rift_in_dungeon()
	_fight()
	await _reward()
	await _blood()
	await _show_live()
	_plain()
	XTianqiQiyin.rng_override = null
	XTianqiQiyinDragonRun.rng_override = null
	DirAccess.remove_absolute(XGlobalVars.path())
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、数据 ----

func _data() -> void:
	XTianqiQiyinDragonRun.reload()
	XTianqiQiyinShow.reload()
	_check("nice_numbers_run", XTianqiQiyinDragonRun.nice_number_violations().is_empty(), XTianqiQiyinDragonRun.nice_number_violations())
	_check("nice_numbers_show", XTianqiQiyinShow.nice_number_violations().is_empty(), XTianqiQiyinShow.nice_number_violations())
	var f := XTianqiQiyinDragonRun.fight_info()
	var troop := XDB.rec("Troops", int(f.troop))
	_check("troop_exists", not troop.is_empty() and troop.members.any(func(m): return int(m.enemyId) == int(f.shell_enemy)), troop)
	_check("shell_is_platon", str(XDB.rec("Enemies", int(f.shell_enemy)).get("name", "")).contains("普拉顿"))
	_check("show_seals_match", XTianqiQiyinShow.seal_order() == XTianqiQiyin.seal_keys(), [XTianqiQiyinShow.seal_order(), XTianqiQiyin.seal_keys()])
	_check("reveal_order_is_seals", XTianqiQiyinDragon.fight_data("jianxian").reveal_order == XTianqiQiyin.seal_keys())
	for k in ["set", "weapon", "true_seal", "artifact", "reveal", "rift"]:
		var se := str(XTianqiQiyinShow.data().get(k, {}).get("se", ""))
		_check("se_%s" % k, se != "" and XDB.audio_path("se", se) != "", se)
	_check("scenes_have_rows", ["rift_open", "rift_ask", "rift_stored", "enter", "lost", "win", "pick_seal", "blood_head", "blood_done"]
		.all(func(k): return XTianqiQiyinDragonRun.data().scenes.get(k, []).size() > 0))


# ---- 二、龙隙 ----

func _rift() -> void:
	var s := _state()
	var host := FakeHost.new()
	# 暗保底：连空 30 次后必出
	XTianqiQiyinDragonRun.state(s)["misses"] = XTianqiQiyinDragon.pity_after()
	var ap: bool = await XTianqiQiyinDragonRun.after_boss(host, s)
	_check("rift_pity_appears", ap and str(XTianqiQiyinDragonRun.state(s).rift) == "offered", XTianqiQiyinDragonRun.state(s))
	_check("rift_show_played", XTianqiQiyinShow.played.any(func(r): return r.kind == "rift"))
	_check("rift_said", _has(host, "七道印的光一起灭"))
	# 已有龙隙时不再判
	var m0 := int(XTianqiQiyinDragonRun.state(s).misses)
	_check("rift_no_double", not await XTianqiQiyinDragonRun.after_boss(host, s) and int(XTianqiQiyinDragonRun.state(s).misses) == m0)
	# 当场问：先存着
	host.answers = [1]
	var r: int = await XTianqiQiyinDragonRun.offer(host, s, true)
	_check("rift_store", r == 2 and str(XTianqiQiyinDragonRun.state(s).rift) == "stored" and host.battles.is_empty(), r)
	_check("rift_ask_options", host.asked.back().size() == 2 and str(host.asked.back()[1]).contains("先存着"))
	var opts := XTianqiQiyin.altar_options(s)
	_check("altar_menu_dragon", opts.any(func(o): return o.id == "dragon") and opts.back().id == "leave", opts)
	# 祭坛菜单进存着的龙隙：输了合上
	var h2 := FakeHost.new()
	h2.results = [2]
	await XTianqiQiyinDragonRun.run_option(h2, s, "dragon")
	_check("rift_fight_troop", h2.battles.size() == 1 and int(h2.battles[0].troop) == 221 and not h2.battles[0].escape and h2.battles[0].lose, h2.battles)
	_check("rift_fight_prepared", str(h2.battles[0].dragon.get("difficulty", "")) == "jianxian", h2.battles)
	_check("rift_lost_closes", str(XTianqiQiyinDragonRun.state(s).rift) == "none" and _has(h2, "龙隙合上"))
	_check("altar_menu_after_lost", not XTianqiQiyin.altar_options(s).any(func(o): return o.id == "dragon"))
	_check("rift_no_key_needed", true)
	# 开关关掉：不判、菜单不出
	XTianqiQiyinDragonRun.ENABLED = false
	XTianqiQiyinDragonRun.state(s)["misses"] = 99
	_check("disabled_no_rift", not await XTianqiQiyinDragonRun.after_boss(host, s) and XTianqiQiyinDragonRun.altar_options(s).is_empty())
	XTianqiQiyinDragonRun.ENABLED = true


## 接在 run_dungeon 里：Boss 打赢 → 判龙隙（演出在结算之前）→ 结算 → 当场问
func _rift_in_dungeon() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	XTianqiQiyinDragonRun.state(s)["misses"] = XTianqiQiyinDragon.pity_after()
	var host := FakeHost.new()
	host.answers = [1, 1]  # 结算「先收着」，龙隙「先存着」
	var r: int = await XTianqiQiyin.run_dungeon(host, s, "bai", false, {})
	_check("dungeon_rift_win", r == 0 and host.battles.size() == 3, [r, host.battles.size()])
	var order: Array = XTianqiQiyinShow.played.map(func(x): return x.kind)
	_check("dungeon_rift_before_drop", order.size() >= 2 and order[0] == "rift" and order.slice(1).has("drop"), order)
	_check("dungeon_rift_stored", str(XTianqiQiyinDragonRun.state(s).rift) == "stored")
	var i_rift := host.said.find(host.said.filter(func(t): return str(t).contains("七道印"))[0])
	var i_drop := host.said.find("\\n<>掉落：") if host.said.has("\\n<>掉落：") else host.said.find(host.said.filter(func(t): return str(t).contains("掉落"))[0])
	_check("dungeon_rift_said_before_drop", i_rift >= 0 and i_drop > i_rift, [i_rift, i_drop])
	# 不出龙隙的时候（固定种子掷不中）流程和原来一样
	var s2 := _state(32)
	XTianqiQiyin.sync(s2)
	XTianqiQiyinDragonRun.rng_override = null
	var h2 := FakeHost.new()
	h2.answers = [1]
	await XTianqiQiyin.run_dungeon(h2, s2, "bai", false, {})
	_check("dungeon_no_rift_default_seed", str(XTianqiQiyinDragonRun.state(s2).rift) == "none" and int(XTianqiQiyinDragonRun.state(s2).misses) == 1
		and not XTianqiQiyinShow.played.any(func(x): return x.kind == "rift"), XTianqiQiyinDragonRun.state(s2))


# ---- 三、战斗 ----

func _dragon_fight(s: XState, diff := "jianxian") -> XBattleLogic:
	XTianqiQiyinDragonRun.prepare(diff)
	var lg := XBattleLogic.new()
	lg.setup(int(XTianqiQiyinDragonRun.fight_info().troop), s)
	return lg


func _fight() -> void:
	var s := _state()
	var lg := _dragon_fight(s)
	var e := XTianqiQiyinDragonRun.dragon(lg)
	var fd := XTianqiQiyinDragon.fight_data("jianxian")
	_check("fight_active", XTianqiQiyinDragonRun.active(lg) and XTianqiQiyinRule.active(lg) and e != null and XTianqiQiyinDragonRun.pending().is_empty())
	_check("fight_name", e.display_name().contains("七首之龙"), e.display_name())
	_check("fight_max_hp", absf(e.mhp - float(fd.max_hp)) <= 2.0 and is_equal_approx(e.hp, e.mhp), [e.mhp, fd.max_hp])
	_check("fight_three_actions", e.action_plus_set().filter(func(v): return v >= 1.0).size() >= 2, e.action_plus_set())
	_check("fight_no_drop", e.data().dropItems.is_empty() and int(e.data().exp) == 0)
	_check("fight_no_borrowed_tags", not str(e.data().note).contains("<hp") and not str(e.data().note).contains("Capture") and e.data().meta.is_empty())
	_check("fight_no_seg_alien", e.added_params.is_empty() and not e.has_meta("tianqi_prefix") and e.alien.is_empty(), [e.added_params, e.display_name()])
	_check("fight_open_reveal_bai", XTianqiQiyinRule.rule_of(lg) == "no_cure" and str(XTianqiQiyinRule.fight(lg).seal) == "bai")
	_check("fight_open_logs", lg.turn_start_logs.any(func(l): return l is Dictionary and str(l.get("text", "")).contains("七首之龙")), lg.turn_start_logs.size())
	var floors: Array = XTianqiQiyinDragonRun.fight(lg).floors
	_check("fight_seven_floors", floors.size() == 7 and is_zero_approx(float(floors[6])) and float(floors[0]) < e.mhp, floors)
	# 段底锁：一下打穿也只到本段底
	var a: XBattler = lg.actors[0]
	var big := XTianqiQiyinDragonRun.hp_damage(lg, e, e.mhp)
	_check("lock_to_floor", is_equal_approx(big, e.hp - float(floors[0])), [big, e.hp, floors[0]])
	_check("lock_not_actors", is_equal_approx(XTianqiQiyinDragonRun.hp_damage(lg, a, 1000.0), 1000.0))
	# 断第一首：揭红印
	e.hp = float(floors[0])
	var logs := XTianqiQiyinDragonRun.end_action(lg)
	_check("cut1_hong", XTianqiQiyinRule.rule_of(lg) == "war_cry" and int(XTianqiQiyinDragonRun.fight(lg).cut) == 1, XTianqiQiyinRule.rule_of(lg))
	_check("cut1_logs", logs.any(func(l): return str(l.text).contains("第 1 首断了")) and logs.any(func(l): return str(l.text).contains("杀声")), logs)
	# 一下连断两首（星坠等不走伤害的扣血）：揭到灰印，挂缓期
	e.hp = float(floors[2])
	XTianqiQiyinDragonRun.end_action(lg)
	var f := XTianqiQiyinDragonRun.fight(lg)
	_check("cut3_hui", XTianqiQiyinRule.rule_of(lg) == "magic_tower" and int(f.cut) == 3, [XTianqiQiyinRule.rule_of(lg), f.cut])
	_check("reprieve_on", not f.reprieve.is_empty() and f.reprieve.actor is XActor and int(f.reprieve.due) == int(lg.turn) + 2, f.reprieve)
	var doomed: XBattler = f.reprieve.actor
	lg.start_turn()
	_check("reprieve_wait", doomed.is_alive())
	lg.start_turn()
	_check("reprieve_fall", doomed.is_dead() and f.reprieve.is_empty())
	# 再来一次：断首前解除
	lg.end_battle(0)
	var lg2 := _dragon_fight(s)
	var e2 := XTianqiQiyinDragonRun.dragon(lg2)
	var fl2: Array = XTianqiQiyinDragonRun.fight(lg2).floors
	e2.hp = float(fl2[2])
	XTianqiQiyinDragonRun.end_action(lg2)
	var who: XBattler = XTianqiQiyinDragonRun.fight(lg2).reprieve.actor
	e2.hp = float(fl2[3])
	var l2 := XTianqiQiyinDragonRun.end_action(lg2)
	_check("reprieve_cleared_by_cut", XTianqiQiyinDragonRun.fight(lg2).reprieve.is_empty() and l2.any(func(l): return str(l.text).contains("缓期解除"))
		and XTianqiQiyinRule.rule_of(lg2) == "sacrifice")
	lg2.start_turn()
	lg2.start_turn()
	_check("reprieve_cleared_alive", who.is_alive())
	# 第六首：默印（寂静），最后一段没有锁
	e2.hp = float(fl2[5])
	XTianqiQiyinDragonRun.end_action(lg2)
	_check("cut6_mo", XTianqiQiyinRule.rule_of(lg2) == "silence" and int(XTianqiQiyinDragonRun.fight(lg2).cut) == 6)
	_check("last_segment_unlocked", is_equal_approx(XTianqiQiyinDragonRun.hp_damage(lg2, e2, e2.hp * 3.0), e2.hp * 3.0))
	lg2.end_battle(0)
	_check("rule_cleared_end", not XTianqiQiyinRule.active(lg2))
	# 字面口径（open_reveal 关）：开场没有规则，第一首断掉揭白印
	var fi := XTianqiQiyinDragonRun.fight_info()
	fi.open_reveal = false
	var lg3 := _dragon_fight(s)
	_check("literal_no_open_rule", XTianqiQiyinRule.rule_of(lg3) == "")
	XTianqiQiyinDragonRun.dragon(lg3).hp = float(XTianqiQiyinDragonRun.fight(lg3).floors[0])
	XTianqiQiyinDragonRun.end_action(lg3)
	_check("literal_cut1_bai", XTianqiQiyinRule.rule_of(lg3) == "no_cure")
	fi.open_reveal = true
	lg3.end_battle(0)
	# 难度：炼狱的生命按敌人血量倍率
	var sl := _state(36, "lianyu")
	var lg4 := _dragon_fight(sl, "lianyu")
	_check("lianyu_hp", absf(XTianqiQiyinDragonRun.dragon(lg4).mhp - float(XTianqiQiyinDragon.max_hp("lianyu"))) <= 2.0, XTianqiQiyinDragonRun.dragon(lg4).mhp)
	lg4.end_battle(0)
	# 没 prepare 的普拉顿照旧
	var pl := XBattleLogic.new()
	pl.setup(int(fi.troop), s)
	_check("plain_platon", not XTianqiQiyinDragonRun.active(pl) and not pl.enemies[0].display_name().contains("七首"))
	pl.end_battle(0)


# ---- 四、奖励 ----

func _reward() -> void:
	var s := _state()
	var p := XTianqiQiyin.progress(s)
	XTianqiQiyinDragonRun.state(s)["rift"] = "stored"
	var host := FakeHost.new()
	# 进 → 打赢 → 选殉印（第 5 个）→「先收着」→ 招募选第一位
	host.answers = [4, 1, 0]
	var party0 := s.party.size()
	await XTianqiQiyinDragonRun.run_option(host, s, "dragon")
	var d := XTianqiQiyinDragonRun.state(s)
	var set_items: Array = p.bag.filter(func(i): return str(i.kind) == "set")
	_check("reward_true_set", set_items.size() == 1 and str(set_items[0].seal) == "xun" and bool(set_items[0].true_seal)
		and set_items[0].grades.all(func(g): return str(g) == "ji") and not bool(set_items[0].revealed), p.bag)
	_check("reward_blood", int(d.blood_stock) == 1 and _has(host, "龙血 1 瓶"))
	_check("reward_rift_closed", str(d.rift) == "none" and bool(d.first_kill))
	_check("reward_show_drop", XTianqiQiyinShow.played.any(func(r): return r.kind == "drop" and r.seal == "xun" and r.true_seal))
	_check("reward_recruit_taken", s.party.size() == party0 + 1 and not d.has("recruit"), [party0, s.party.size()])
	_check("reward_pick_seal_menu", host.asked[0].size() == 7, host.asked[0])
	# 第二次赢：没有招募；当场揭
	d["rift"] = "stored"
	var h2 := FakeHost.new()
	h2.answers = [0, 0]
	var bag0: int = p.bag.size()
	await XTianqiQiyinDragonRun.run_option(h2, s, "dragon")
	_check("second_no_recruit", not XTianqiQiyinDragonRun.state(s).has("recruit") and not _has(h2, "龙的馈赠"))
	_check("second_revealed", p.bag.slice(bag0).all(func(i): return bool(i.revealed)) and _has(h2, "【真印】"), p.bag.slice(bag0))
	_check("second_reveal_show", XTianqiQiyinShow.played.any(func(r): return r.kind == "reveal" and r.true_seal))
	_check("second_blood", int(XTianqiQiyinDragonRun.state(s).blood_stock) == 2)
	# 武器和神器：直接喂必中的随机流看物品格式
	var s2 := _state()
	XTianqiQiyinDragonRun.state(s2)["rift"] = "fighting"
	XTianqiQiyinDragon.data().reward.weapon_chance = 1.0
	XTianqiQiyinDragon.data().reward.artifact_chance = 1.0
	var h3 := FakeHost.new()
	h3.answers = [0, 1]  # 选白印、先收着；招募不答＝稍后再选
	var got: Array = await XTianqiQiyinDragonRun.settle(h3, s2)
	XTianqiQiyinDragon.reload()
	var w: Array = got.filter(func(i): return str(i.kind) == "weapon")
	_check("reward_weapon_item", w.size() == 1 and bool(w[0].true_seal) and XTianqiQiyinDrop.weapon_classes(str(w[0].seal)).has(str(w[0].wtype)), got)
	_check("reward_artifact", XTianqiQiyin.progress(s2).artifacts.size() == 1 and XTianqiQiyinShow.played.any(func(r): return r.kind == "artifact"))
	_check("recruit_later", bool(XTianqiQiyinDragonRun.state(s2).get("recruit", false))
		and XTianqiQiyin.altar_options(s2).any(func(o): return o.id == "dragon_recruit"))
	# 稍后再选的候选不重抽
	var o1 := XTianqiQiyinDragonRun.recruit_offer(s2)
	_check("recruit_offer_kept", o1 == XTianqiQiyinDragonRun.recruit_offer(s2) and not o1.is_empty(), o1)
	_check("recruit_rule_floor30", XTianqiQiyinDragonRun.recruit_rule(s2) == XTianqi.draw_rule(s2, 5))
	var h4 := FakeHost.new()
	h4.answers = [0]
	var n0 := s2.party.size()
	await XTianqiQiyinDragonRun.run_option(h4, s2, "dragon_recruit")
	_check("recruit_from_altar", s2.party.size() == n0 + 1 and s2.party.has(int(o1[0])))


# ---- 五、龙血 ----

func _blood() -> void:
	var s := _state()
	var d := XTianqiQiyinDragonRun.state(s)
	d["blood_stock"] = 5
	var id := int(s.party[0])
	var a := s.actor(id)
	var base := a.param(2)
	var host := FakeHost.new()
	host.answers = [0, 0, 0, 0]  # 给第一位喝四次（第四次喝满拒绝）
	_check("altar_menu_blood", XTianqiQiyin.altar_options(s).any(func(o): return o.id == "dragon_blood"))
	await XTianqiQiyinDragonRun.run_option(host, s, "dragon_blood")
	d = XTianqiQiyinDragonRun.state(s)
	_check("blood_three_max", int(d.blood.get(str(id), 0)) == 3 and int(d.blood_stock) == 2, d)
	_check("blood_full_said", _has(host, "已经喝满"))
	_check("blood_rate", is_equal_approx(XTianqiQiyinDragonRun.param_rate(a, 2), 1.09), XTianqiQiyinDragonRun.param_rate(a, 2))
	a.param_mark_dirty()
	_check("blood_param_up", a.param(2) > base, [base, a.param(2)])
	_check("blood_other_actor", is_equal_approx(XTianqiQiyinDragonRun.param_rate(s.actor(int(s.party[1])), 2), 1.0))
	XTianqiQiyinDragonRun.ENABLED = false
	_check("blood_disabled", is_equal_approx(XTianqiQiyinDragonRun.param_rate(a, 2), 1.0))
	XTianqiQiyinDragonRun.ENABLED = true


# ---- 六、演出在真的节点上 ----

class LiveHost extends Node:
	var flashes := 0
	var shakes := 0
	var ses: Array = []
	func flash_screen(_c: Array, _d: int) -> void:
		flashes += 1
	func shake_screen(_p: int, _s: int, _d: int) -> void:
		shakes += 1
	func play_se(a) -> void:
		ses.append(str(a.name))


func _show_live() -> void:
	_state()
	var h := LiveHost.new()
	add_child(h)
	await XTianqiQiyinShow.drop(h, {"kind": "set", "seal": "hong", "part": "head", "true_seal": true, "grades": ["ji", "ji", "ji"]})
	await XTianqiQiyinShow.drop(h, {"kind": "weapon", "seal": "hei", "wtype": "剑", "true_seal": false, "grades": ["putong", "putong", "putong"]})
	await XTianqiQiyinShow.artifact(h, "scales")
	await XTianqiQiyinShow.reveal(h, {"kind": "set", "seal": "mo", "part": "feet", "true_seal": false})
	await XTianqiQiyinShow.rift(h)
	_check("live_overlays_freed", h.get_children().all(func(c): return c.is_queued_for_deletion()) or h.get_child_count() == 0, h.get_child_count())
	_check("live_flash", h.flashes >= 3, h.flashes)
	_check("live_shake_true_and_rift", h.shakes >= 2, h.shakes)
	_check("live_se", h.ses.has("Saint3") and h.ses.has("Sword5") and h.ses.has("Thunder9") and h.ses.has("Break") and h.ses.has("Earth5"), h.ses)
	_check("live_played", XTianqiQiyinShow.played.size() == 5)
	XTianqiQiyinShow.ENABLED = false
	var n := h.ses.size()
	await XTianqiQiyinShow.drop(h, {"kind": "set", "seal": "bai", "part": "head", "true_seal": false})
	_check("show_disabled_silent", h.ses.size() == n)
	XTianqiQiyinShow.ENABLED = true
	h.queue_free()


# ---- 原版档 ----

func _plain() -> void:
	var s := _state()
	var plain := XState.new()
	XState.current = plain
	_check("plain_no_menu", XTianqiQiyinDragonRun.altar_options(plain).is_empty())
	XTianqiQiyinDragonRun.prepare("jianxian")
	var lg := XBattleLogic.new()
	lg.setup(int(XTianqiQiyinDragonRun.fight_info().troop), plain)
	_check("plain_no_dragon", not XTianqiQiyinDragonRun.active(lg) and not XTianqiQiyinRule.active(lg))
	_check("plain_param_rate", is_equal_approx(XTianqiQiyinDragonRun.param_rate(plain.actor(1), 0), 1.0))
	lg.end_battle(0)
	XState.current = s
