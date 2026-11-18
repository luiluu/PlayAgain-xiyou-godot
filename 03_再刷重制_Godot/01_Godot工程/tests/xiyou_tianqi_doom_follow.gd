extends Node
## T180（发作真换人 v0.2 第三节第 5 条、第十节 T086-b；D201 第 2 件）：死期挂在人身上，不挂在格子上。
## 一、四骑士死期：被挂的人换到助力位，回合末照样到点死、日志照报、本场不能复活（XTianqiHorsemen.DOOM_FOLLOW）。
## 二、宣判者死期：走倒下入口 logic._die（XTianqiDeathAlien.DIE_ENTRY）；收尸人扫 5 个人（死在助力位照喂）。
## 三、35 层影子「不能复活」认 5 个人。
## 四、允许失败的战斗打输复活扫 5 个人（XTianqiHorsemen.lose_revive）。
## 五、画面守卫：真战斗画面里手动换下挂着宣判者死期的人，回合末倒下演出不取图、不报错（XBattleScene._offstage_target）。
## 六、七首之龙灰印缓期：换到助力位照样到点倒下，打输复活清查扫得到。
## 各开关关掉回到只认场上 4 格。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 回退开关用字面量赋值（回退开关覆盖.py 只认字面量）
func _follow(on: bool) -> void:
	if on:
		XTianqiHorsemen.DOOM_FOLLOW = true
	else:
		XTianqiHorsemen.DOOM_FOLLOW = false


func _entry(on: bool) -> void:
	if on:
		XTianqiDeathAlien.DIE_ENTRY = true
	else:
		XTianqiDeathAlien.DIE_ENTRY = false


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return l.type == "battle_text").map(func(l): return str(l.text))


func _state(line := "death") -> XState:
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
	for id in lineup:
		var a := s.actor(id)
		a.add_param(0, 20000000.0)
		a.add_param(3, 10000.0)
		a.add_param(5, 10000.0)
		a.recover_all()
	s.flags.tianqi["line"] = line
	return s


func _run() -> void:
	XMessageBox.auto = true
	seed(20261118)
	_horsemen(true)
	_horsemen(false)
	_verdict(true)
	_verdict(false)
	_die_entry_onfield(true)
	_die_entry_onfield(false)
	_reaper(true)
	_reaper(false)
	_shadow(true)
	_shadow(false)
	_lose_revive(true)
	_lose_revive(false)
	_dragon_reprieve(true)
	_dragon_reprieve(false)
	await _scene_guard()
	XTianqiHorsemen.DOOM_FOLLOW = true
	XTianqiDeathAlien.DIE_ENTRY = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 一、四骑士死期（死亡线生存战）：挂上死期后换下去
func _horsemen(on: bool) -> void:
	_follow(on)
	var tag := "on" if on else "off"
	var s := _state()
	_check("horse_prepare_%s" % tag, XTianqiHorsemen.prepare("death", s, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var f := XTianqiHorsemen.fight(lg)
	var t: XActor = lg.actors[1]
	XTianqiHorsemen._mark(f, t).doom = true
	var h := lg.tianqi_swap(t)
	_check("horse_swapped_%s" % tag, h != null and not lg.actors.has(t) and s.helper() == t)
	_check("horse_people_%s" % tag, XTianqiHorsemen.doom_people(lg).has(t) == on and XTianqiHorsemen.doom_people(lg).size() == (5 if on else 4))
	var logs := XTianqiHorsemen.end_turn(lg)
	if on:
		_check("horse_helper_dies", t.is_dead(), [t.hp, t.state_ids])
		_check("horse_helper_log", _texts(logs).any(func(x): return x.contains("%s的死期到了" % t.display_name())), _texts(logs))
		_check("horse_helper_collapse", logs.any(func(l): return l.type == "collapse" and is_same(l.target, t)))
		_check("horse_helper_no_revive", XTianqiHorsemen.blocks_revive(t))
		t.remove_state(1)
		_check("horse_remove_state_blocked", t.is_dead())
		_check("horse_mark_cleared", not XTianqiHorsemen.mark_of(lg, t).get("doom", false))
		_check("horse_onfield_alive", lg.actors.all(func(a): return a.is_alive()))
	else:
		_check("horse_off_helper_alive", t.is_alive() and XTianqiHorsemen.mark_of(lg, t).get("doom", false))
	lg.end_battle(0)


## 二①、宣判者死期：被挂的人换到助力位，回合末照样死（走倒下入口，带阵亡状态）
func _verdict(on: bool) -> void:
	_follow(on)
	var tag := "on" if on else "off"
	var s := _state()
	_check("verdict_prepare_%s" % tag, XTianqiDeathAlien.prepare("omen", s))
	var lg := XBattleLogic.new()
	lg.setup(291, s)
	lg.turn = 5
	XTianqiDeathAlien.start_turn(lg)
	var f := XTianqiDeathAlien.fight(lg)
	_check("verdict_marked_%s" % tag, f.doom.size() == 1)
	var t = f.doom.keys()[0]
	_check("verdict_swap_%s" % tag, lg.tianqi_swap(t) != null and not lg.actors.has(t))
	var logs := XTianqiDeathAlien.end_turn(lg)
	# 宣判者死期本来就跟人走（f.doom 记的是人）：开关只管收尸、不能复活这些扫描
	_check("verdict_helper_dies_%s" % tag, t.is_dead() and t.state_ids.has(1) and f.doom.is_empty(), [t.hp, t.state_ids])
	_check("verdict_helper_log_%s" % tag, _texts(logs).any(func(x): return x.contains("死期：%s倒下了" % t.display_name())), _texts(logs))
	_check("verdict_scan_%s" % tag, f.dead.has(t) == on, f.dead.keys().map(func(a): return a.display_name()))
	lg.end_battle(0)


## 二②、倒下入口：场上被宣判者死期带走的人，开关开关结果一样（倒下、带阵亡状态、收尸登记、日志照报）
func _die_entry_onfield(on: bool) -> void:
	XTianqiHorsemen.DOOM_FOLLOW = true
	_entry(on)
	var tag := "on" if on else "off"
	var s := _state()
	XTianqiDeathAlien.prepare("omen", s)
	var lg := XBattleLogic.new()
	lg.setup(291, s)
	lg.turn = 5
	XTianqiDeathAlien.start_turn(lg)
	var f := XTianqiDeathAlien.fight(lg)
	var t = f.doom.keys()[0]
	var logs := XTianqiDeathAlien.end_turn(lg)
	_check("entry_onfield_dies_%s" % tag, t.is_dead() and t.state_ids.has(1) and is_zero_approx(t.hp) and f.dead.has(t), [t.hp, t.state_ids])
	_check("entry_onfield_collapse_%s" % tag, logs.any(func(l): return l.type == "collapse" and is_same(l.target, t)))
	_check("entry_onfield_text_%s" % tag, _texts(logs).any(func(x): return x.contains("死期：%s倒下了" % t.display_name())), _texts(logs))
	_check("entry_others_alive_%s" % tag, lg.actors.filter(func(a): return a != t).all(func(a): return a.is_alive()))
	lg.end_battle(0)
	XTianqiDeathAlien.DIE_ENTRY = true


## 二③、收尸人扫 5 个人：死在助力位的人照样喂（变强、回血）；关掉只扫场上
func _reaper(on: bool) -> void:
	_follow(on)
	var tag := "on" if on else "off"
	var s := _state()
	XTianqiDeathAlien.prepare("spread", s)
	var lg := XBattleLogic.new()
	lg.setup(294, s)
	var boss: XEnemy = lg.enemies[0]
	_check("reaper_kind_%s" % tag, str(XTianqiDeathAlien.unit(lg, boss).kind) == "reaper")
	var t: XActor = lg.actors[0]
	lg.tianqi_swap(t)
	boss.hp = boss.mhp * 0.5
	var atk0 := boss.atk
	t.hp = 0.0
	t.refresh_resources()
	lg._die(t)
	var logs := XTianqiDeathAlien.after_action(lg, lg.actors[1])
	var fed := boss.atk > atk0 and _texts(logs).any(func(x): return x.contains("收走了%s" % t.display_name()))
	_check("reaper_helper_fed_%s" % tag, fed == on, [atk0, boss.atk, _texts(logs)])
	lg.end_battle(0)


## 三、35 层影子：「死去的人本场不能复活」认 5 个人
func _shadow(on: bool) -> void:
	_follow(on)
	var tag := "on" if on else "off"
	var s := _state()
	XTianqiHorsemen.prepare("death", s, "shadow")
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var h := s.helper()
	_check("shadow_helper_off_field_%s" % tag, h != null and not lg.actors.has(h))
	_check("shadow_onfield_blocked_%s" % tag, XTianqiHorsemen.blocks_revive(lg.actors[0]))
	_check("shadow_helper_blocked_%s" % tag, XTianqiHorsemen.blocks_revive(h) == on)
	lg.end_battle(0)


## 四、允许失败的战斗打输复活：出战成员＋助力位都扶到 1 血；关掉助力位照旧躺着
func _lose_revive(on: bool) -> void:
	_follow(on)
	var tag := "on" if on else "off"
	var s := _state()
	var h := s.helper()
	var m: XActor = s.battle_members()[0]
	for a in [h, m]:
		a.hp = 0.0
		a.add_new_state(1)
		a.refresh_resources()
	_check("lose_fixture_%s" % tag, h.is_dead() and m.is_dead() and not s.battle_members().has(h))
	XTianqiHorsemen.lose_revive(s)
	_check("lose_member_revived_%s" % tag, m.is_alive() and is_equal_approx(m.hp, 1.0), [m.hp])
	_check("lose_helper_%s" % tag, h.is_alive() == on and (not on or is_equal_approx(h.hp, 1.0)), [h.hp, h.state_ids])


## 六、七首之龙灰印缓期：挂着缓期的人换到助力位，到点照样倒下；打输复活扫得到他
func _dragon_reprieve(on: bool) -> void:
	_follow(on)
	var tag := "on" if on else "off"
	var s := _state("war")
	s.set_variable(20, 36)
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = XRandomStream.create("0123012301230123", "qiyin")
	XTianqiQiyinDragonRun.rng_override = XRandomStream.create("3210321032103210", "qiyin_dragon")
	XTianqiQiyinDragonRun.prepare("jianxian")
	var lg := XBattleLogic.new()
	lg.setup(int(XTianqiQiyinDragonRun.fight_info().troop), s)
	_check("dragon_active_%s" % tag, XTianqiQiyinDragonRun.active(lg))
	var f := XTianqiQiyinDragonRun.fight(lg)
	var t: XActor = lg.actors[2]
	f.reprieve = {"actor": t, "due": int(lg.turn) + 1}
	_check("dragon_swap_%s" % tag, lg.tianqi_swap(t) != null and s.helper() == t)
	lg.turn = int(lg.turn) + 1
	XTianqiQiyinDragonRun.start_turn(lg)
	_check("dragon_helper_falls_%s" % tag, t.is_dead() and f.reprieve.is_empty(), [t.hp, t.state_ids])
	lg.end_battle(2)
	XTianqiHorsemen.lose_revive(s)
	_check("dragon_lose_revive_%s" % tag, t.is_alive() == on, [t.hp, t.state_ids])
	XTianqiQiyin.rng_override = null
	XTianqiQiyinDragonRun.rng_override = null


## 五、画面守卫：真战斗画面，手动换下挂着宣判者死期的人，回合末倒下记录指向没有图的人：只记日志、不演出、不报错
func _scene_guard() -> void:
	XTianqiHorsemen.DOOM_FOLLOW = true
	var s := _state()
	XTianqiDeathAlien.prepare("omen", s)
	var b := XBattleScene.new()
	b.setup(291, true, false, XDB.map(5))
	add_child(b)
	for i in 30:
		await get_tree().physics_frame
	var lg := b.logic
	lg.turn = 5
	XTianqiDeathAlien.start_turn(lg)
	var f := XTianqiDeathAlien.fight(lg)
	var t = f.doom.keys()[0]
	await b._tianqi_swap(t)
	_check("scene_swapped", not lg.actors.has(t) and not b.sprites.has(t))
	var logs := XTianqiDeathAlien.end_turn(lg)
	_check("scene_collapse_logged", logs.any(func(l): return l.type == "collapse" and is_same(l.target, t)))
	var done := [false]
	var play := func():
		await b._play(logs)
		done[0] = true
	play.call()
	for i in 600:
		if done[0]:
			break
		await get_tree().physics_frame
	_check("scene_play_finished", done[0])
	_check("scene_skipped_offstage", b.offstage_skipped == ["collapse"], b.offstage_skipped)
	_check("scene_helper_dead", t.is_dead())
	# 场上的人倒下照常演出（不被守卫跳过）
	var on_field: XActor = lg.actors[0]
	on_field.hp = 0.0
	on_field.refresh_resources()
	lg._die(on_field)
	b.offstage_skipped.clear()
	done[0] = false
	play = func():
		await b._play([{"type": "collapse", "target": on_field, "views": lg.views([on_field])}])
		done[0] = true
	play.call()
	for i in 600:
		if done[0]:
			break
		await get_tree().physics_frame
	_check("scene_onfield_played", done[0] and b.offstage_skipped.is_empty(), b.offstage_skipped)
	b.queue_free()
	for i in 3:
		await get_tree().physics_frame
