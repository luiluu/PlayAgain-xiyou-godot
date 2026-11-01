extends Node
## 【cc·白龙_11·未经审查】云裳界面一期：战斗指令窗（installNativeYunshangRuntime.js 第 508～538 行）。真战斗画面（敌群 2、地图 5），
## 队伍云裳 55 级进阶 2、1 号、8 号、9 号（都加 1e12 生命，云裳敏捷最高先动），用按键驱动：
## - 指令窗：云裳本人的技能栏（魔法、战技、其他）与各天衣的指令名、能不能选，照参照 p6.cmd*（yunshang_probe 调原版 makeCommandList）；
## - 收袖切换（名字变「收袖：开启」）、放行（队列加回存的行动、再灰显）、赠行选人（窗 760 宽居中，取消回指令窗、选定免费赠 2 次）、
##   裁身（没醒选一项、醒着选两项，第二次去掉选过的）、七曜元素（选定写进设置、本回合灰显）；
## - 敕衣点神选没穿天衣的人：蜂鸣、留在选人；
## - 换锦：先选自己的减益，选敌人后再选它的增益（取消回选敌），行动后两边互换；收针：先选觉醒者，用掉的是选的那位。
const FIXTURE := "res://tests/fixtures/yunshang_oracle.json"
var checks := 0
var failures: Array = []
var ref := {}


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)
	await frames(2)


func _run() -> void:
	XMessageBox.auto = true
	XSave.dir_override = "user://test_xiyou_yunshang_ui"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in data.cases:
		ref[str(c.id)] = c
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	s.switches[2494] = true  # 超强角色可出战
	s.actor_advance[XYunshang.ACTOR] = 2
	s.party.clear()
	s.battle_slots.clear()
	for id in [XYunshang.ACTOR, 1, 8, 9]:
		s.actor(id).change_level_mv(55)  # 七曜流霞要 55 级才穿得上
		s.add_actor(id)
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var a := s.actor(XYunshang.ACTOR)
	a.add_param(6, 1e6)
	a.recover_all()
	var b := XBattleScene.new()
	b.setup(2, false, false, XDB.map(5))
	add_child(b)
	for e in b.logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	await frames(30)
	check("cloud_first", b._active == a and b.cmd_win != null, null if b._active == null else b._active.actor_id)
	if b._active == a:
		for k in b.logic.actors:
			XYunshang.data(k).wake_until = 0  # 神纹自鸣开局随机唤醒的，先都睡下
		await skill_types(b, a)
		await sleeve(b, s, a)
		await release(b, s, a)
		await gift(b, s, a)
		await cut(b, s, a)
		await element(b, s, a)
		await wake_reject(b, s, a)
		await exchange(b, s, a)
		await gather(b, s, a)
	b.queue_free()
	await frames(3)
	finish()


func wear(s: XState, a: XActor, k: int) -> void:
	if k < 0:
		XEquipment.change(s, a, a.equip_slots().find(4), null)
	else:
		s.gain_gear("armor", XYunshang.ROBE_FIRST + k, 1)
		XEquipment.change(s, a, a.equip_slots().find(4), s.gear[s.gear.size() - 1])


## 重画指令窗（同 xiyou_battle_ui 的 _picked "back"）
func redraw(b: XBattleScene) -> void:
	b._picked.emit("back")
	await frames(5)


func texts(b: XBattleScene) -> Array:
	return [] if b.cmd_win == null else b.cmd_win.entries.map(func(e): return [str(e.text), bool(e.get("enabled", true))])


func want_rows(rows: Array) -> Array:
	return rows.map(func(r): return [str(r[0]), bool(r[2])])


## 选指令窗里 key 那一项并确定
func command(b: XBattleScene, key: String) -> bool:
	var i: int = -1 if b.cmd_win == null else b.cmd_win.entries.find_custom(func(e): return str(e.key) == key)
	if i < 0:
		return false
	b.cmd_win.select(i)
	await press("ui_accept")
	await frames(3)
	return true


func yun_rows(b: XBattleScene) -> Array:
	return [] if b.yun_win == null else b.yun_win.entries.map(func(e): return str(e.text))


## 云裳本人（没穿天衣）：攻击、魔法、战技、其他、防御、物品、逃跑（不能逃灰显），参照 p6.cmd5 第 0 步 cloud
func skill_types(b: XBattleScene, a: XActor) -> void:
	await redraw(b)
	check("cmd.cloud", texts(b) == want_rows(ref["p6.cmd5"].observed.steps[0].cloud), [texts(b), ref["p6.cmd5"].observed.steps[0].cloud])


## 天衣指令照参照最后一行（名字与能不能选）
func yun_entry(b: XBattleScene, id: String, step: int) -> bool:
	var w: Array = ref[id].observed.steps[step].ally
	var got := texts(b)
	return not got.is_empty() and got[got.size() - 1] == [str(w[w.size() - 1][0]), bool(w[w.size() - 1][2])]


func sleeve(b: XBattleScene, s: XState, a: XActor) -> void:
	wear(s, a, 5)
	await redraw(b)
	check("sleeve.off", yun_entry(b, "p6.cmd5", 0), texts(b))
	await command(b, "yunSleeve")
	check("sleeve.on", yun_entry(b, "p6.cmd5", 1) and bool(XYunshang.sleeve.get(a, false)) and b.cmd_win != null and b.cmd_win.active, texts(b))
	await command(b, "yunSleeve")
	check("sleeve.toggle_back", not bool(XYunshang.sleeve.get(a, false)), texts(b))


func release(b: XBattleScene, s: XState, a: XActor) -> void:
	wear(s, a, 9)
	await redraw(b)
	check("release.empty", yun_entry(b, "p6.cmd9", 0), texts(b))
	XYunshang.data(a).stored = 1
	await redraw(b)
	check("release.ready", yun_entry(b, "p6.cmd9", 1), texts(b))
	var before := b.logic.current_order.count(a)
	await command(b, "yunRelease")
	check("release.used", yun_entry(b, "p6.cmd9", 2) and b.logic.current_order.count(a) == before + 1 and int(XYunshang.data(a).stored) == 0,
		[texts(b), b.logic.current_order.count(a), before])


func gift(b: XBattleScene, s: XState, a: XActor) -> void:
	wear(s, a, 11)
	XYunshang.wake(b.logic, a)
	await redraw(b)
	check("gift.ready", yun_entry(b, "p6.cmd11", 0), texts(b))
	await command(b, "yunGift")
	var w := b.yun_win
	var names: Array = b.logic.actors.filter(func(t): return t != a).map(func(t): return t.display_name())
	check("gift.window", w != null and yun_rows(b) == names and not b.cmd_win.active, yun_rows(b))
	if w != null:
		check("gift.rect", [w.position - b._origin, w.size] == [Vector2(260, 292), Vector2(760, 136)], [w.position - b._origin, w.size])
	await press("ui_cancel")
	await frames(3)
	check("gift.cancel", b.yun_win == null and b.cmd_win != null and b.cmd_win.active and int(XYunshang.data(a).free_gift_round) != XYunshang.round)
	await command(b, "yunGift")
	await press("ui_accept")  # 第一位（1 号）
	await frames(3)
	var one := b.logic.state.actor(1)
	check("gift.given", yun_entry(b, "p6.cmd11", 1) and int(XYunshang.gift_received.get(one, 0)) == 2 and b.logic.current_order.count(one) >= 2,
		[texts(b), XYunshang.gift_received.get(one, 0)])
	XYunshang.data(a).wake_until = 0


func cut(b: XBattleScene, s: XState, a: XActor) -> void:
	wear(s, a, 8)
	await redraw(b)
	check("cut.ready", yun_entry(b, "p6.cmd8", 0), texts(b))
	var names: Array = XDB.system().terms.params
	await command(b, "yunCut")
	check("cut.rows", yun_rows(b) == [2, 4, 3, 5, 6, 7].map(func(i): return str(names[i])), yun_rows(b))
	await press("ui_down")
	await press("ui_accept")  # 魔攻
	await frames(3)
	var d := XYunshang.data(a)
	check("cut.one", yun_entry(b, "p6.cmd8", 1) and d.cut_choices == [4] and b.yun_win == null, [texts(b), d.cut_choices])
	# 觉醒：选两项，第二次的列表去掉第一次选的
	d.cut_round = -1
	XYunshang.wake(b.logic, a)
	await redraw(b)
	await command(b, "yunCut")
	await press("ui_accept")  # 物攻
	await frames(3)
	check("cut.second_rows", yun_rows(b) == [4, 3, 5, 6, 7].map(func(i): return str(names[i])), yun_rows(b))
	await press("ui_accept")  # 魔攻
	await frames(3)
	check("cut.two", d.cut_choices == [2, 4] and int(d.cut_round) == XYunshang.round, d.cut_choices)
	d.wake_until = 0


func element(b: XBattleScene, s: XState, a: XActor) -> void:
	wear(s, a, 14)
	await redraw(b)
	check("element.ready", yun_entry(b, "p6.cmd14", 0), texts(b))
	var names: Array = XDB.system().elements
	await command(b, "yunElement")
	check("element.rows", yun_rows(b) == [2, 3, 4].map(func(i): return str(names[i])), yun_rows(b))
	await press("ui_down")
	await press("ui_accept")
	await frames(3)
	check("element.chosen", yun_entry(b, "p6.cmd14", 1) and int(XYunshang.setting(a).element) == 3, [texts(b), XYunshang.setting(a).element])


## 技能栏里选技能并确定（同 xiyou_battle_ui._choose_skill）
func choose_skill(b: XBattleScene, a: XActor, id: int) -> bool:
	var sk := XDB.rec("Skills", id)
	if not await command(b, "stype:%d" % int(sk.stypeId)):
		return false
	var list := b.logic.battle_skills(a).filter(func(x): return int(x.stypeId) == int(sk.stypeId))
	var idx := list.find_custom(func(x): return int(x.id) == id)
	if b.list_win == null or idx < 0:
		return false
	b.list_win.select(idx)
	await press("ui_accept")
	await frames(5)
	return true


## 敕衣点神：选没穿天衣的 8 号确定——蜂鸣、还在选人；取消回列表、再取消回指令
func wake_reject(b: XBattleScene, s: XState, a: XActor) -> void:
	wear(s, a, 0)
	await redraw(b)
	var ok := await choose_skill(b, a, XYunshang.WAKE)
	check("wake.select", ok and b._target_mode == "ally", [ok, b._target_mode])
	var eight := b.logic.state.actor(8)
	b._select_target(eight)
	await press("ui_accept")
	await frames(3)
	check("wake.rejected", b._target_mode == "ally" and not XYunshang.awake(eight), b._target_mode)
	await press("ui_cancel")
	await frames(3)
	await press("ui_cancel")
	await frames(3)
	check("wake.back", b._target_mode == "" and b.cmd_win != null and b.cmd_win.active)


## 换锦（没醒）：自己有减益 5、1 号敌人有增益 55；先选「不选自身状态」以外的第一项，选敌、取消选状态回选敌，再选敌、选 55，行动后互换
func exchange(b: XBattleScene, s: XState, a: XActor) -> void:
	wear(s, a, 4)
	var foe: XEnemy = b.logic.alive(b.logic.enemies)[0]
	b.logic._state_add(a, 5)
	b.logic._state_add(foe, 55)
	await redraw(b)
	var ok := await choose_skill(b, a, XYunshang.EXCHANGE)
	var state_name := func(i): return str(XDB.rec("States", i).name)
	check("exchange.self_rows", ok and yun_rows(b) == ["不选自身状态", state_name.call(5)], yun_rows(b))
	await press("ui_down")
	await press("ui_accept")
	await frames(3)
	check("exchange.pick_enemy", b._target_mode == "enemy", b._target_mode)
	b._select_target(foe)
	await press("ui_accept")
	await frames(3)
	check("exchange.enemy_rows", yun_rows(b) == ["不选敌方状态", state_name.call(55)], yun_rows(b))
	await press("ui_cancel")
	await frames(3)
	check("exchange.back_to_enemy", b.yun_win == null and b._target_mode == "enemy", b._target_mode)
	b._select_target(foe)
	await press("ui_accept")
	await frames(3)
	await press("ui_down")
	await press("ui_accept")
	await until(func(): return b._active != a or b.cmd_win == null, 600)
	await until(func(): return b.cmd_win != null, 900)
	check("exchange.swapped", foe.state_ids.has(5) and not foe.state_ids.has(55) and a.state_ids.has(55) and not a.state_ids.has(5),
		[a.state_ids, foe.state_ids])


func until(cond: Callable, n: int) -> bool:
	for i in n:
		if cond.call():
			return true
		await frames(1)
	return false


## 轮到别人时一律防御，直到云裳再行动
func skip_to(b: XBattleScene, a: XActor) -> bool:
	for i in 40:
		if not await until(func(): return b.cmd_win != null, 900):
			return false
		if b._active == a:
			return true
		b._picked.emit("guard")
		await frames(3)
	return false


## 收针：云裳与 1 号都醒着，云裳剩的回合多（不选时默认收云裳）；选 1 号，行动后用掉的是 1 号
func gather(b: XBattleScene, s: XState, a: XActor) -> void:
	var back := await skip_to(b, a)
	check("gather.turn", back)
	if not back:
		return
	var one := b.logic.state.actor(1)
	wear(s, one, 9)
	XYunshang.wake(b.logic, one)
	XYunshang.wake(b.logic, a)
	XYunshang.data(a).wake_until = XYunshang.round + 3
	await redraw(b)
	var ok := await choose_skill(b, a, XYunshang.GATHER)
	check("gather.rows", ok and yun_rows(b) == [a.display_name(), one.display_name()], yun_rows(b))
	await press("ui_down")
	await press("ui_accept")
	await frames(3)
	check("gather.pick_enemy", b._target_mode == "enemy", b._target_mode)
	await press("ui_accept")
	await until(func(): return b._active != a or b.cmd_win == null, 600)
	check("gather.used_chosen", int(XYunshang.data(one).wake_until) == 0 and XYunshang.awake(a),
		[XYunshang.data(one).wake_until, XYunshang.data(a).wake_until])


func finish() -> void:
	XMessageBox.auto = false
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_yunshang_ui", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
