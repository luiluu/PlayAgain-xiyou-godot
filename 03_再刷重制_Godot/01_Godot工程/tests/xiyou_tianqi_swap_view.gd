extends Node
## T182（T086-c；设计仓库《天启篇_发作真换人 v0.2》第三节第 2～4 条、第七节 battle_scene 一行、第十节 T086-c）：发作真换人的画面。
## 一、指令：能换照旧一项；助力位锁着时「换人」变灰带原因（还剩几回合）；锁过了恢复；模块角色不列。
## 二、助力位锁定行：谁被锁、还剩几回合；锁过了收起；结算前还原后不再报。
## 三、真战斗画面：发作强制换人演出（淡出淡入、日志一句、不弹对话框）；锁定行、指令原因条摆在画面里；自动换回演出。
## 四、真战斗画面打赢：_victory 先还原换回图再调结算——被发作换下去的人照在场拿满法宝经验。
## 五、T181 P3-1：实跑守层者 grant()：被发作换下去的主力烙印照在场 1 份、助力位半份，法宝经验照在场算。
## 六、T181 P3-2：战斗对象没了（没走收口），swap_hold 不再让出战栏清理停着；下一场开战照样清扫还原。

var results: Array = []


class FixStream extends XRandomStream:
	var floats := {}
	var mods := {}
	var default_float := 0.99
	func next_float(reason: String, _event_key := "") -> float:
		draws += 1
		return float(floats.get(reason, default_float))
	func next_uint(_reason: String, _event_key := "") -> int:
		draws += 1
		return 0
	func next_index_mod(n: int, reason: String, _event_key := "") -> int:
		draws += 1
		return clampi(int(mods.get(reason, 0)), 0, maxi(0, n - 1))
	func next_int_inclusive(lo: int, _hi: int, _reason: String, _event_key := "") -> int:
		draws += 1
		return lo


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


## 回退开关用字面量赋值（回退开关覆盖.py 只认字面量）
func _real(on: bool) -> void:
	if on:
		XTianqiBrand.REAL_SWAP = true
	else:
		XTianqiBrand.REAL_SWAP = false


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and id != XGojo.ACTOR)


func _state(diff := "jianxian", lineup: Array = []) -> XState:
	if lineup.is_empty():
		lineup = _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		var a := s.actor(id)
		a.add_param(0, 20000000.0)
		a.recover_all()
	return s


func _setb(a: XActor, brand: int) -> void:
	XZhenqi.data(a)
	var r := 0
	while r < XTianqiBrand.last_realm() and XTianqiBrand.node_of(r) <= brand:
		r += 1
	a.zhenqi["brand"] = brand
	a.zhenqi["brand_realm"] = r
	a.zhenqi["brand_carved"] = 1


func _rig(lg: XBattleLogic) -> void:
	var fs := FixStream.new()
	fs.domain = "rule"
	fs.floats["brand_fit"] = 0.0
	lg.random.rule = fs
	XTianqiBrand.fight(lg)["ripe"] = false  # 生的：第六种在
	lg.turn = 2


func _logic(s: XState, troop := 1) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	_rig(lg)
	return lg


## a 抽到第六种（换人）并当场按发作走完这次行动（act 末尾对调）；返回日志
func _force_swap(lg: XBattleLogic, a: XActor) -> Array:
	_setb(a, 10000)
	(lg.random.rule as FixStream).mods["brand_fit_kind"] = XTianqiBrand.fit_kinds(lg, a).find("swap")
	XTianqiBrand._start_fit(lg, XTianqiBrand._fc(lg), a, "self")
	var cmd := lg.brand_forced(a)
	return lg.act(a, cmd[0], cmd[1])


func _slots(s: XState) -> Array:
	return s.battle_slots.map(func(v): return int(v))


func _swap_opt(opts: Array) -> Dictionary:
	for o in opts:
		if str(o.get("key", "")) == "tianqiSwap":
			return o
	return {}


## 给 a 穿一件法宝：先试「超级赛亚人」（防具 125），穿不上就在防具表里找一件他穿得上的法宝
## （穿不上的结算途中会被 release_unequippable 卸掉，法宝经验就对不上了）
func _wear_fabao(a: XActor) -> Dictionary:
	var item := XGear.template("armor", 125)
	if not a.can_equip(item):
		var arm = XDB.table("Armors")
		for r in (arm if arm is Array else []):
			if r is Dictionary and not r.is_empty() and str(r.get("name", "")) != "":
				var t := XGear.template("armor", int(r.id))
				if XMagicWeapon.is_magic(t) and a.can_equip(t) and a.equip_slots().has(int(t.etypeId)):
					item = t
					break
	var slot := a.equip_slots().find(int(item.etypeId))
	a.equips[slot] = item
	a.refresh_passive()
	return item


## 法宝「不在场经验比例」临时归零（插件参数 0.5、敌群只给 1 点时在场、不在场都取整成 1，分不出来）；返回旧值，结算完放回
func _bench_rate_zero() -> Array:
	var p: Dictionary = XDB.plugin(XMagicWeapon.PARAMS)
	var old = p.get("Exp Rate Not Battler", null)
	p["Exp Rate Not Battler"] = 0
	return [p, old]


func _bench_rate_back(prm: Array) -> void:
	if prm[1] == null:
		prm[0].erase("Exp Rate Not Battler")
	else:
		prm[0]["Exp Rate Not Battler"] = prm[1]


func _troop_fabao_exp(lg: XBattleLogic) -> float:
	var total := 0.0
	for e in lg.enemies:
		total += XMagicWeapon.enemy_exp(e.data())
	return total


func _run() -> void:
	XMessageBox.auto = true
	seed(20261118)
	XTianqiBrand.ENABLED = true
	_real(true)
	_commands()
	_would_gaps()
	_hold_p3_2()
	_grant_ledger()
	await _scene()
	await _scene_victory()
	await _scene_old_skin()
	_real(false)
	XTianqiBrand.ENABLED = false
	XZhenqi.battle = {}
	if not results.any(func(r): return r.name == "victory_reached_end"):
		_check("victory_reached_end", false)
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 一、二：指令变灰带原因、锁定行文字（逻辑层数据，不起画面）
func _commands() -> void:
	var s := _state()
	var lg := _logic(s)
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	var h := s.helper()
	var e0 := XTianqiSwapView.command_entry(lg, b)
	_check("cmd_normal", e0 == {"text": XTianqiSwapView.TEXT_SWAP_CMD, "key": "tianqiSwap"}, e0)
	_check("hud_none_before", XTianqiSwapView.hud_text(lg) == "" and XTianqiSwapView.lock_left(lg) == 0)
	_force_swap(lg, a)
	_check("swapped", lg.actors[0] == h and s.helper() == a)
	var e2 := XTianqiSwapView.command_entry(lg, b)
	_check("cmd_locked_gray", not e2.is_empty() and e2.get("enabled", true) == false and str(e2.key) == "tianqiSwap", e2)
	_check("cmd_locked_reason_t2", str(e2.get("reason", "")) == XTianqiSwapView.TEXT_LOCK_REASON % [a.display_name(), 2], e2)
	_check("cmd_locked_for_new", XTianqiSwapView.command_entry(lg, h).get("enabled", true) == false)
	_check("hud_t2", XTianqiSwapView.lock_left(lg) == 2 and XTianqiSwapView.hud_text(lg) == XTianqiSwapView.TEXT_LOCK_HUD % [a.display_name(), 2], XTianqiSwapView.hud_text(lg))
	lg.turn = 3
	_check("cmd_locked_reason_t3", str(XTianqiSwapView.command_entry(lg, b).get("reason", "")) == XTianqiSwapView.TEXT_LOCK_REASON % [a.display_name(), 1])
	_check("hud_t3", XTianqiSwapView.lock_left(lg) == 1 and XTianqiSwapView.hud_text(lg).contains("1"), XTianqiSwapView.hud_text(lg))
	lg.turn = 4
	var e4 := XTianqiSwapView.command_entry(lg, b)
	_check("cmd_open_t4", e4.get("enabled", true) == true and not e4.has("reason") and not e4.is_empty(), e4)
	_check("hud_none_t4", XTianqiSwapView.hud_text(lg) == "" and XTianqiSwapView.locked_actor(lg) == null)
	# 倒下的人：平常就没有「换人」，锁着也不列
	lg.turn = 2
	b.hp = 0.0
	_check("cmd_dead_none", XTianqiSwapView.command_entry(lg, b).is_empty())
	b.hp = 1000.0
	# 锁着、结算前还原后助力位换了人：锁定行不再报
	lg.tianqi_restore()
	_check("hud_none_after_restore", XTianqiSwapView.hud_text(lg) == "", XTianqiSwapView.hud_text(lg))
	lg.end_battle()
	# 开关关着：不会有锁，指令和 T181 前一样
	_real(false)
	s = _state()
	lg = _logic(s)
	_check("off_cmd_same", XTianqiSwapView.command_entry(lg, lg.actors[1]) == ({"text": "换人", "key": "tianqiSwap"} if lg.can_tianqi_swap(lg.actors[1]) else {}))
	lg.end_battle()
	_real(true)
	# 记录分类与句子
	_check("kind_of", XTianqiSwapView.kind_of({"forced": true}) == "forced" and XTianqiSwapView.kind_of({"auto": true}) == "auto" and XTianqiSwapView.kind_of({}) == "manual")


## 回退开关用字面量赋值
func _skin(on: bool) -> void:
	if on:
		XUiSkin.ENABLED = true
	else:
		XUiSkin.ENABLED = false


func _super_lineup(n_front_super: int) -> Array:
	var sup := XTianqiSkills.ids(XTier.SUPER, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and id != XGojo.ACTOR)
	var weak := _ids(XTier.WEAK).filter(func(id): return not XTianqiSkills.is_super(id, true))
	var out := []
	for i in 4:
		out.append(sup[i] if i < n_front_super else weak[i])
	out.append(weak[4])
	return out


## T182 核查 P3-2：锁着时只在「撇开锁定平常有换人」时列变灰项——助力位倒下不列；九死场上超强者（助力位非超强者，D57 拦）不列，锁过后也没有
func _would_gaps() -> void:
	var s := _state()
	var lg := _logic(s)
	var b: XActor = lg.actors[1]
	_force_swap(lg, lg.actors[0])
	var h := s.helper()
	_check("gap_locked_gray_alive", XTianqiSwapView.command_entry(lg, b).get("enabled", true) == false)
	h.hp = 0.0
	_check("gap_helper_dead_none", XTianqiSwapView.command_entry(lg, b).is_empty(), XTianqiSwapView.command_entry(lg, b))
	lg.end_battle()
	s = _state("jiusi", _super_lineup(1))
	lg = _logic(s)
	var sup: XActor = lg.actors[0]
	var w: XActor = lg.actors[2]
	_check("gap_super_fixture", XTianqiSkills.is_super(sup.actor_id, true) and not XTianqi.helper_super_ok(s) and not lg.can_tianqi_swap(sup))
	_force_swap(lg, lg.actors[1])
	_check("gap_super_swapped", XTianqiBrand.swap_locked(lg) and not XTianqiSkills.is_super(s.helper().actor_id, true))
	_check("gap_super_none_locked", XTianqiSwapView.command_entry(lg, sup).is_empty(), XTianqiSwapView.command_entry(lg, sup))
	_check("gap_weak_gray_locked", XTianqiSwapView.command_entry(lg, w).get("enabled", true) == false)
	lg.turn = 4
	_check("gap_super_none_open", XTianqiSwapView.command_entry(lg, sup).is_empty() and not XTianqiSwapView.command_entry(lg, w).is_empty())
	lg.end_battle()


## 六、T181 P3-2：战斗对象没了，swap_hold 放开；下一场开战清扫照样还原
func _hold_p3_2() -> void:
	var s := _state()
	var before := _slots(s)
	_hold_swap(s)  # 函数里的 logic 出了作用域就没了（没走收口）
	_check("p3_2_slots_moved", _slots(s) != before, _slots(s))
	_check("p3_2_hold_released", not XTianqiBrand.swap_hold(s))
	_check("p3_2_entry_left_for_sweep", XTianqiBrand._holds.any(func(x): return x.state.get_ref() == s))
	var lg2 := XBattleLogic.new()
	lg2.setup(1, s)
	_check("p3_2_sweep_restores", _slots(s) == before and not XTianqiBrand._holds.any(func(x): return x.state.get_ref() == s), _slots(s))
	lg2.end_battle()


func _hold_swap(s: XState) -> void:
	var lg := _logic(s)
	_force_swap(lg, lg.actors[0])
	_check("p3_2_hold_while_alive", XTianqiBrand.swap_hold(s))


## 五、T181 P3-1：守层者（6 层，敌群 39）首通，真发作换下主力后 grant：主力烙印照在场 1 份，助力位（被换上来后又还原回助力位的人）半份；
## 法宝经验：主力拿满（照在场），助力位照「不在场」比例
func _grant_ledger() -> void:
	var s := _state()
	s.set_variable(20, 30)  # 法宝等级上限跟楼层走，放宽免得封顶
	var lg := XBattleLogic.new()
	lg.setup(39, s)
	_check("p3_1_guardian6", str(XTianqiBrand.fight(lg).get("key", "")) == "guardian:6", XTianqiBrand.fight(lg).get("key", ""))
	_rig(lg)
	var a: XActor = lg.actors[0]
	var h := s.helper()
	var fa := _wear_fabao(a)
	var fh := _wear_fabao(h)
	_force_swap(lg, a)
	_check("p3_1_swapped", not lg.actors.has(a) and lg.actors.has(h))
	_setb(a, 1000)
	_setb(h, 1000)
	var ea := XMagicWeapon.exp_of(fa)
	var eh := XMagicWeapon.exp_of(fh)
	var prm := _bench_rate_zero()
	lg.grant({"gold": 0, "exp": 0, "drops": []})
	_bench_rate_back(prm)
	var da := XTianqiBrand.value(a) - 1000
	var dh := XTianqiBrand.value(h) - 1000
	var amt := XTianqiBrand.first_amount(6) * XTianqiBrand.scale()
	_check("p3_1_restored", lg.actors.has(a) and not lg.actors.has(h) and s.helper() == h)
	_check("p3_1_brand_main_full", da > 0 and absf(float(da) - amt) < 1.0, [da, amt])
	_check("p3_1_brand_helper_half", dh > 0 and absf(float(dh) - amt * 0.5) < 1.0, [dh, amt])
	var total := _troop_fabao_exp(lg)
	var rate := 0.0
	var ga := XMagicWeapon.exp_of(fa) - ea
	var gh := XMagicWeapon.exp_of(fh) - eh
	_check("p3_1_fabao_main_full", total > 0 and absf(ga - total) < 0.5, [ga, total])
	_check("p3_1_fabao_helper_bench", absf(gh - XPower.js_round(total * rate)) < 0.5, [gh, total, rate])
	print("INFO p3_1 brand main=%d helper=%d first_amount=%s fabao main=%s helper=%s total=%s rate=%s" % [da, dh, amt, ga, gh, total, rate])
	lg.end_battle()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _new_scene(troop := 1) -> XBattleScene:
	var scene := XBattleScene.new()
	scene.setup(troop, true, false, XDB.map(5))
	add_child(scene)
	await _frames(30)
	# 场景自己的主循环停在玩家输入上再动手（敌人先手时它会接着演敌人的行动，和这里换人的图打架）
	for i in 900:
		if scene.inputting:
			break
		await get_tree().physics_frame
	_check("scene_waiting_input_%d" % troop, scene.inputting)
	_rig(scene.logic)
	return scene


func _play_swap(scene: XBattleScene, logs: Array) -> bool:
	var done := [false]
	var play := func():
		await scene._play(logs)
		for l in logs:
			if str(l.get("type", "")) == "tianqi_swap":
				await scene._tianqi_swap_view(l.out, l["in"], l)  # 同主循环
		done[0] = true
	play.call()
	for i in 900:
		if done[0]:
			break
		await get_tree().physics_frame
	return done[0]


func _log_has(scene: XBattleScene, text: String) -> bool:
	return scene._log_lines.any(func(x): return str(x.text) == text)


func _inside(scene: XBattleScene, c: Control) -> bool:
	var r := c.get_global_rect()
	var box := Rect2(scene._origin, XBattleScene.BOX)
	return box.encloses(r)


## 三、真战斗画面：强制换人、锁定行、指令原因、自动换回
func _scene() -> void:
	var s := _state()
	var scene: XBattleScene = await _new_scene()
	var lg: XBattleLogic = scene.logic
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	var h := s.helper()
	var old: XBattlerSprite = scene.sprites[a]
	var logs := _force_swap(lg, a)
	var ok := await _play_swap(scene, logs)
	_check("scene_forced_done", ok)
	_check("scene_forced_view", scene.sprites.has(h) and not scene.sprites.has(a) and (not is_instance_valid(old) or old.is_queued_for_deletion()))
	_check("scene_forced_alpha", scene.sprites.has(h) and is_equal_approx(scene.sprites[h].modulate.a, 1.0), scene.sprites[h].modulate.a if scene.sprites.has(h) else null)
	_check("scene_forced_line", _log_has(scene, XTianqiSwapView.TEXT_FORCED % [a.display_name(), h.display_name()]), scene._log_lines)
	_check("scene_forced_no_manual_line", not _log_has(scene, "%s退下，%s上场了！" % [a.display_name(), h.display_name()]))
	# 锁定行
	scene._refresh_status()
	var tag := scene.swap_lock_tag
	_check("scene_lock_tag", tag != null and XTianqiSwapView.tag_text(tag) == XTianqiSwapView.TEXT_LOCK_HUD % [a.display_name(), 2], XTianqiSwapView.tag_text(tag))
	_check("scene_lock_tag_inside", tag != null and _inside(scene, tag), tag.get_global_rect() if tag else null)
	# 指令：变灰带原因；光标停上去出原因条
	var opts := scene._command_entries(b)
	var so := _swap_opt(opts)
	_check("scene_cmd_gray", not so.is_empty() and so.get("enabled", true) == false and str(so.get("reason", "")).contains(a.display_name()), so)
	scene.cmd_win = XSkinBattle.command(scene.ui, opts, XBattleScene.CMD_W, b)
	scene._place_near_actor(scene.cmd_win, b)
	scene._cmd_reason(opts, opts.find(so))
	var rt := scene.cmd_reason_tag
	_check("scene_reason_tag", rt != null and XTianqiSwapView.tag_text(rt) == str(so.reason), XTianqiSwapView.tag_text(rt))
	_check("scene_reason_inside", rt != null and _inside(scene, rt), rt.get_global_rect() if rt else null)
	await _shot(scene, "swap_reason")
	scene._cmd_reason(opts, 0)
	_check("scene_reason_hidden_other", XTianqiSwapView.tag_text(rt) == "")
	scene._cmd_reason(opts, opts.find(so))
	scene._close_windows()
	_check("scene_reason_hidden_close", XTianqiSwapView.tag_text(rt) == "")
	# 锁过了：锁定行收起、自动换回演出
	lg.turn = 4
	scene._refresh_status()
	_check("scene_lock_tag_gone", not tag.visible)
	lg.auto = true
	var back := lg.brand_forced(h)
	_check("scene_auto_cmd", not back.is_empty())
	if not back.is_empty():
		var logs2 := lg.act(h, back[0], back[1])
		ok = await _play_swap(scene, logs2)
		_check("scene_auto_done", ok and scene.sprites.has(a) and not scene.sprites.has(h) and is_equal_approx(scene.sprites[a].modulate.a, 1.0))
		_check("scene_auto_line", _log_has(scene, XTianqiSwapView.TEXT_AUTO_BACK % [h.display_name(), a.display_name()]), scene._log_lines)
	lg.auto = false
	lg.end_battle(1)
	scene.queue_free()
	await _frames(3)


## T182 核查 P3-1：关新界面（旧 XSideStatus 面板右边伸出画面）锁定行夹回画面里
func _scene_old_skin() -> void:
	_skin(false)
	var s := _state()
	var scene: XBattleScene = await _new_scene()
	var lg: XBattleLogic = scene.logic
	var ok := await _play_swap(scene, _force_swap(lg, lg.actors[0]))
	scene._refresh_status()
	var tag := scene.swap_lock_tag
	_check("old_skin_swapped", ok and s.helper() != null and XTianqiBrand.swap_locked(lg))
	_check("old_skin_lock_inside", tag != null and tag.visible and _inside(scene, tag), [tag.get_global_rect() if tag else null, scene.party_rect()])
	await _shot(scene, "swap_lock_old_skin")
	lg.end_battle(1)
	scene.queue_free()
	await _frames(3)
	_skin(true)


## 截图（XIYOU_SHOT_DIR 设了才截；原尺寸）
func _shot(scene: XBattleScene, name: String) -> void:
	var dir := OS.get_environment("XIYOU_SHOT_DIR")
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


## 四、真战斗画面打赢：_victory 第一行还原、换回图，结算按还原后的在场名单发——被换下去的人法宝经验拿满
func _scene_victory() -> void:
	var s := _state()
	s.set_variable(20, 30)
	var scene: XBattleScene = await _new_scene(39)
	var lg: XBattleLogic = scene.logic
	var a: XActor = lg.actors[0]
	var h := s.helper()
	var fa := _wear_fabao(a)
	var fslot := a.equips.find(fa)
	_check("victory_fabao_wearable", a.can_equip(fa) and fslot >= 0, [fa.get("base"), fslot])
	var before := _slots(s)
	var ok := await _play_swap(scene, _force_swap(lg, a))
	_check("victory_swapped_first", ok and scene.sprites.has(h) and not scene.sprites.has(a))
	await _shot(scene, "swap_lock")
	var ea := XMagicWeapon.exp_of(fa)
	var total := _troop_fabao_exp(lg)
	for e in lg.enemies:
		e.hp = 0.0
	var done := [false]
	var prm := _bench_rate_zero()
	var run := func():
		await scene._victory()
		done[0] = true
	run.call()
	for i in 300:
		if lg._rewards_granted:
			break
		await get_tree().physics_frame
	_bench_rate_back(prm)
	_check("victory_granted", lg._rewards_granted)
	_check("victory_restored_view", scene.sprites.has(a) and not scene.sprites.has(h) and _slots(s) == before and lg.actors.has(a))
	var now = a.equips[fslot] if fslot >= 0 else null  # 装备格里的这一件（结算途中装备表会换成副本，不认旧引用）
	_check("victory_fabao_full", total > 0 and now is Dictionary and XMagicWeapon.is_magic(now) and absf(XMagicWeapon.exp_of(now) - ea - total) < 0.5, [XMagicWeapon.exp_of(now) - ea, total])
	_check("victory_lock_tag_gone", scene.swap_lock_tag == null or not scene.swap_lock_tag.visible)
	_check("victory_reached_end", true)  # 协程中途报错时 _run 照样往下走，这一条缺了总数就对不上
	scene.queue_free()
	await _frames(3)
