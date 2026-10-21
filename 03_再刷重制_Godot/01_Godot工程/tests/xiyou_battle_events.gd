extends Node
## 战斗内事件（XBattleEventRunner，共用核心 MVEventCore）：逐项对照 mv_oracle battle_event_probe（oracle/battle_events.json）。
## 165 海拉的幻影：T1～3 变量 112 与完全回复、T4 的 101 停住规则（等待中不重入、不推进）、确认后 334→336（174→175）、
##   T4 起按新形态出招 4023、span 1 页不重复、旧 token 无效；
## 334 完全回复（含死亡、隐藏成员与状态 77 的上限缓存）；336 变身（有/无待行动）；
## 824 神劫使：变量 1178＝5 只有 0 号可见，＝6 时 335 依次出现 1～5、333 加状态只对可见成员、出现者首次行动在 T3；
##   受伤／死亡的隐藏成员出现后资源与状态不变。
## 不比：TP（Godot 开战 TP 随机）、伤害；CodexBossDifficulty 霸体 2651（重制版尚无 Boss 霸体系统，比较状态时去掉）。
## 另按冻结源代码（无参照数据）：makeUniqueNames 按 originalName（神话带前缀）计数；强制行动的 smoothTarget 不选隐藏成员；
##   画面上隐藏成员 335 出现、倒下的成员 334 复活都 16 帧淡入（Sprite_Enemy.startAppear）。
var results := []
const BOSS_GUARD := 2651


class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass


## 原版参照在开战生成后将 Math.random 固定为 0.5；仅替换夹具的本场 rule，不能靠全局 seed 控制它。
## 原生随机流／实际抽样消费另由 xiyou_random_streams 验证；这里逐项复现 oracle 的事件与技能结果。
class OracleRule:
	extends XRandomStream

	func next_float(_reason: String, _event_key := "") -> float:
		return 0.5

	func next_int_inclusive(lo: int, hi: int, _reason: String, _event_key := "") -> int:
		return lo + floori((hi - lo + 1) * 0.5)

	func next_index_mod(n: int, _reason: String, _event_key := "") -> int:
		return floori(n * 0.5)


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func setup(troop: int, vars := {}) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	seed(7)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026101900000165"
	for k in vars:
		s.set_variable(int(k), vars[k])
	var logic := XBattleLogic.new()
	logic.level_roll = 0.99  # 参照：敌群生成时 Math.random=0.99
	logic.setup(troop, s)
	logic.random.rule = OracleRule.new()
	logic.random.rule.domain = "rule"
	return logic


## 参照给测试队伍的 HP 加了 999999999 撑过回合；这里每次行动后把队伍补满（只比事件规则，不比伤害）
func heal(logic: XBattleLogic) -> void:
	for a in logic.actors:
		a.remove_state(1)
		a.hp = a.mhp


func key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % int((b as XActor).data().id) if b is XActor else "e%d" % logic.enemies.find(b)


func states_of(list: Array) -> Array:
	return list.map(func(x): return int(x)).filter(func(x): return x != BOSS_GUARD)


## 照参照快照设敌人（HP/MP/TP/状态/buff/隐藏）
func put(e: XEnemy, w: Dictionary) -> void:
	e.hidden = bool(w.hidden)
	e.hp = float(w.hp)
	e.mp = float(w.mp)
	e.tp = float(w.tp)
	e.state_ids.clear()
	e.state_turns.clear()
	for id in w.states:
		e.state_ids.append(int(id))
	for k in w.stateTurns:
		e.state_turns[int(k)] = int(w.stateTurns[k])
	for i in range(8):
		e.buffs[i] = int(w.buffs[i])
		e.buff_turns[i] = int(w.buffTurns[i])
	e.refresh_passive()
	# krz 能力值缓存按参照夹具同步：快照 snap() 读过全部八项（格子按当前状态全暖），夹具最后一步（addBuff／addState）留下 need_refresh。
	# 334.hidden 参照在战斗外，起作用的是同周期的 paramRate 缓存（状态 77 的 ×0.8 留到 334 之后的 refresh）；这里用战斗内的格子表达同一结果。
	e.param_mark_dirty()
	e.param_refresh()
	for i in range(8):
		e.param(i)
	e.param_mark_dirty()


## 与参照快照比：身份、隐藏、活着、HP/MP、状态、buff；名字可选
func same(e: XEnemy, w: Dictionary, with_name := false, with_tp := false) -> bool:
	return e.enemy_id == int(w.enemyId) and e.hidden == bool(w.hidden) and e.is_alive() == bool(w.alive) \
		and is_equal_approx(e.hp, float(w.hp)) and is_equal_approx(e.mp, float(w.mp)) \
		and is_equal_approx(e.mhp, float(w.mhp)) and states_of(e.state_ids) == states_of(w.states) \
		and Array(e.buffs) == Array(w.buffs).map(func(x): return int(x)) \
		and (not with_name or e.display_name() == str(w.name)) and (not with_tp or is_equal_approx(e.tp, float(w.tp)))


func reading(e: XEnemy) -> Dictionary:
	return {"id": e.enemy_id, "hidden": e.hidden, "alive": e.is_alive(), "hp": e.hp, "mhp": e.mhp, "mp": e.mp, "tp": e.tp,
		"states": e.state_ids, "buffs": e.buffs, "name": e.display_name()}


## 只跑一段指令（同一页游标），消息直接确认
func run_list(logic: XBattleLogic, list: Array) -> Array:
	var r := XBattleEventRunner.new(logic, list)
	while true:
		var x := r.advance()
		if x.kind == "message":
			r.waiting_frame().resume(null)
		elif x.kind == "done":
			break
	return r.take_logs()


## 单条指令的前后快照对照（troop 内全体成员）
func command_case(name: String, troop: int, observed: Dictionary, command: Dictionary, with_tp := true) -> void:
	var logic := setup(troop)
	logic.turn = int(observed.before.turn)
	for i in range(observed.before.enemies.size()):
		put(logic.enemies[i], observed.before.enemies[i])
	run_list(logic, [command])
	for i in range(observed.after.enemies.size()):
		var w: Dictionary = observed.after.enemies[i]
		check("%s.e%d" % [name, i], same(logic.enemies[i], w, false, with_tp), [reading(logic.enemies[i]), w])


func _run() -> void:
	var ref = XDB.load_json("oracle/battle_events.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	var cases := {}
	for c in ref.cases:
		cases[c.id] = c
		check(str(c.id) + ".oracle_clean", c.errors.is_empty(), c.errors)
	command_case("334.revive", 165, cases["command334.revive-and-recover"].observed, {"code": 334, "indent": 0, "parameters": [-1]})
	command_case("334.hidden", 824, cases["command334.living-and-hidden"].observed, {"code": 334, "indent": 0, "parameters": [-1]})
	command_case("336.no_action", 165, cases["command336.no-queued-action"].observed, {"code": 336, "indent": 0, "parameters": [0, 175]})
	command_case("336.rebuild", 165, cases["command336.rebuild-queued-action"].observed, {"code": 336, "indent": 0, "parameters": [0, 175]})
	_rebuild_action(cases["command336.rebuild-queued-action"].observed)
	_troop165(cases["troop165.real-turns1-4"].observed)
	_troop824(cases["troop824.variable1178-5-hidden"].observed, 5)
	_troop824(cases["troop824.variable1178-6-appear"].observed, 6)
	_unit_checks()
	_name_checks()
	_smooth_target_checks()
	await _scene_checks()
	finish()


## Game_Troop.makeUniqueNames 按 originalName 计数，EliteEnemy 的 originalName 带「【神话】」：
## 敌群 2（嘤嘤怪 ×3）一只神话、两只普通时，神话的只有一只不加字母，普通的两只是Ａ、Ｂ
func _name_checks() -> void:
	var logic := setup(2)
	logic.enemies[0].elite = true
	for e in logic.enemies:
		e.letter = ""
	logic._letters.clear()
	logic._names_count.clear()
	logic.make_unique_names()
	var base := str(logic.enemies[0].data().name)
	var names: Array = logic.enemies.map(func(e): return e.display_name())
	check("names.elite_mixed", names == [XEnemy.elite_title() + base, base + "Ａ", base + "Ｂ"], names)


## Game_Unit.smoothTarget：强制行动的序号不是活着的成员（含没出现的隐藏成员）时取第一个活着的；没有活着的就不选
func _smooth_target_checks() -> void:
	var logic := setup(824, {1178: 5})
	var attack := XDB.rec("Skills", 1)
	var t1 := logic._forced_target(logic.actors[0], attack, 1)
	check("smooth.hidden_index", t1 == logic.enemies[0], key(t1, logic) if t1 != null else null)
	logic.enemies[0].hp = 0
	logic.enemies[0].refresh_resources()
	var t0 := logic._forced_target(logic.actors[0], attack, 0)
	check("smooth.no_alive", t0 == null, key(t0, logic) if t0 != null else null)


## 画面：隐藏成员不画、335 出现后 16 帧淡入；倒下（淡出）的成员 334 复活后同样淡入（Sprite_Enemy.setupEffect／startAppear）
func _scene_checks() -> void:
	XSave.dir_override = "user://test_xiyou_battle_events"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(1178, 5)
	var scene := QuietBattle.new()
	scene.setup(824, true, false, {})
	add_child(scene)
	await get_tree().physics_frame
	var e0: XEnemy = scene.logic.enemies[0]
	var e1: XEnemy = scene.logic.enemies[1]
	check("scene.hidden_not_drawn", not scene.sprites[e1].visible and not scene.sprites[e1].appeared and scene.sprites[e0].appeared)
	for l in scene.logic.enemy_appear(1):
		scene._apply_enemy_change(l)
	var start_a: float = scene.sprites[e1].sprite.modulate.a
	await _wait_opaque(scene.sprites[e1])
	check("scene.appear_fades_in", scene.sprites[e1].visible and scene.sprites[e1].appeared and start_a < 0.1
		and scene.sprites[e1].sprite.modulate == Color.WHITE, [start_a, scene.sprites[e1].sprite.modulate])
	# 神劫使 934 不免疫死亡：HP 0 即加死亡状态，倒下淡出后 334 才是真复活
	e0.hp = 0
	e0.refresh_resources()
	var died := e0.is_dead() and e0.state_ids.has(1)
	await scene.sprites[e0].collapse()
	var faded: float = scene.sprites[e0].sprite.modulate.a
	for l in scene.logic.enemy_recover_all(0):
		scene._apply_enemy_change(l)
	await _wait_opaque(scene.sprites[e0])
	check("scene.revive_fades_in", died and faded < 0.1 and e0.is_alive() and scene.sprites[e0].appeared
		and scene.sprites[e0].sprite.modulate == Color.WHITE, [died, faded, e0.is_alive(), scene.sprites[e0].sprite.modulate])
	scene.queue_free()
	for sp in XSound._players:
		if is_instance_valid(sp):
			sp.stop()
	await get_tree().create_timer(0.5, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())


## 等淡入播完：按帧轮询，最多 120 帧（无画面时刚显示的图首帧可能很长，固定等一段真实时间会在补间开跑前就超时）
func _wait_opaque(sp: XBattlerSprite) -> void:
	for i in range(120):
		if sp.sprite.modulate == Color.WHITE:
			return
		await get_tree().process_frame


## 336 之后轮到时按新形态选招（参照：原待行动 1 重做成 175 的 4023）
func _rebuild_action(o: Dictionary) -> void:
	var logic := setup(165)
	logic.turn = 4
	put(logic.enemies[0], o.before.enemies[0])
	run_list(logic, [{"code": 336, "indent": 0, "parameters": [0, 175]}])
	var want := int(o.after.enemies[0].actions[0].skill)
	# 本场规则输入同 oracle 固定 0.5：变身后应重新选到 4023。
	var got: Dictionary = logic.decide(logic.enemies[0])[0]
	var forms := func(id: int) -> Array:
		return XDB.rec("Enemies", id).get("actions", []).map(func(a): return int(a.skillId))
	check("336.rebuild.skill", int(got.get("id", 0)) == want and forms.call(175).has(want), [got.get("id"), want, forms.call(175), forms.call(174)])


## 一个回合，同 XBattleLogic.run_turn，另在回合首位取出后记下行动顺序
func turn_with_orders(logic: XBattleLogic, cmds: Dictionary) -> Dictionary:
	var logs := logic.run_events() if logic.turn == 0 else []
	logic.start_turn()
	var first := true
	var orders := {}
	while true:
		var u := logic.next_subject()
		if first:
			orders = {"subject": key(u, logic) if u != null else "", "current": logic.current_order.map(func(b): return key(b, logic)),
				"next": logic.next_order.map(func(b): return key(b, logic))}
		logs.append_array(logic.run_events(u if first else null))
		first = false
		if u == null or logic.is_won() or logic.is_lost():
			break
		var cmd: Array = [null, null] if logic.cleared_action(u) else (cmds[u] if u is XActor and cmds.has(u) else logic.decide(u))
		logs.append_array(logic.act(u, cmd[0], cmd[1]))
		heal(logic)
	if not logic.is_won() and not logic.is_lost():
		logs.append_array(logic.end_turn())
		logs.append_array(logic.run_events(null, true))
	orders.logs = logs
	return orders


func guard_all(logic: XBattleLogic) -> Dictionary:
	var cmds := {}
	for a in logic.actors:
		cmds[a] = [XDB.rec("Skills", 2), null]
	return cmds


func _troop165(o: Dictionary) -> void:
	var logic := setup(165)
	var e0: XEnemy = logic.enemies[0]
	var msgs := []
	var during := []
	logic.message_responder = func(msg: Dictionary):
		msgs.append({"turn": logic.turn, "msg": msg})
		# 消息未关闭：规则停在 101 之后、334/336 之前；该页 flag 已提交；再检查不重入、不推进
		during.append({"id": e0.enemy_id, "flag": logic._event_flags.has(3), "again": logic.troop_events().size(),
			"waiting": logic.is_event_waiting(), "turn": logic.turn})
		return null
	var acts := {}
	for t in range(1, 6):
		var r := turn_with_orders(logic, guard_all(logic))
		acts[t] = []
		for l in r.logs:
			if l.type == "action" and l.user == e0:
				acts[t].append(int(l.skill.id))
		# 参照 turns[t+1] 是下一回合开始（首位取出后、事件前）的读数，即本回合结束后的状态
		if t + 1 < o.turns.size():
			var w: Dictionary = o.turns[t + 1]
			check("165.t%d.var112" % t, int(logic.state.variable(112)) == int(w.variable112), [logic.state.variable(112), w.variable112])
			check("165.t%d.enemy" % t, same(e0, w.enemies[0]), [reading(e0), w.enemies[0]])
		if logic.is_won() or logic.is_lost():
			break
	var want_msg: Dictionary = o.messages[0].opened
	check("165.message_once", msgs.size() == 1 and int(msgs[0].turn) == int(want_msg.turn), msgs)
	if msgs.size() == 1:
		var m: Dictionary = msgs[0].msg
		check("165.message_text", m.lines == want_msg.texts and str(m.face) == str(want_msg.message.faceName) and int(m.index) == int(want_msg.message.faceIndex)
			and int(m.background) == int(want_msg.message.background) and int(m.position) == int(want_msg.message.positionType), [m, want_msg.message, want_msg.texts])
		check("165.message_holds", during[0].id == int(want_msg.enemies[0].enemyId) and during[0].flag and during[0].again == 0 and during[0].waiting,
			[during, want_msg.enemies[0].enemyId])
	# 行动：T1～3 用 879，T4 变身后按 175 出招 4023（参照 actions）
	for a in o.actions:
		if a.subject == "e0" and acts.has(int(a.turn)):
			# 固定本场 oracle 输入，逐回合比较真实技能；保留最终资源断言。
			var ok: bool = acts[int(a.turn)].has(int(a.actions[0].skill))
			check("165.t%d.e0_skill" % int(a.turn), ok, [acts[int(a.turn)], a])
	check("165.final", same(e0, o.final.enemies[0]), [reading(e0), o.final.enemies[0]])
	logic.message_responder = Callable()  # 闭包引用 logic，清掉免得循环引用


func _troop824(o: Dictionary, v: int) -> void:
	var name := "824.v%d" % v
	var logic := setup(824, {1178: v})
	check(name + ".slots", logic.enemies.size() == o.before.enemies.size(), logic.enemies.size())
	for i in range(o.before.enemies.size()):
		check("%s.before.e%d" % [name, i], logic.enemies[i].hidden == bool(o.before.enemies[i].hidden), [i, logic.enemies[i].hidden])
	var acted := {}
	for t in range(1, 4):
		var r := turn_with_orders(logic, guard_all(logic))
		var w: Dictionary = o.turns[t]
		# 敌方在本回合（首位取出后）当前／下个顺序中的成员：参照的己方顺序受速度随机影响，只比敌方
		var foes := func(l: Array) -> Array:
			return l.filter(func(k): return str(k).begins_with("e"))
		var cur: Array = foes.call(([r.subject] if str(r.subject).begins_with("e") else []) + r.current)
		var want_cur: Array = foes.call(([w.subject] if w.subject != null and str(w.subject).begins_with("e") else []) + Array(w.currentOrder))
		cur.sort()
		want_cur.sort()
		check("%s.t%d.current_foes" % [name, t], cur == want_cur, [r, w.subject, w.currentOrder])
		for l in r.logs:
			if l.type == "action" and l.user is XEnemy:
				acted[key(l.user, logic)] = acted.get(key(l.user, logic), t)
		if t == 1:
			# 第 1 回合事件之后：出现的成员与 333 加状态（隐藏成员加不上）
			var after_t1: Dictionary = o.commands.filter(func(c): return int(c.code) == 333 and int(c.before.turn) == 1)[0].after
			for i in range(after_t1.enemies.size()):
				check("%s.t1_333.e%d" % [name, i], logic.enemies[i].hidden == bool(after_t1.enemies[i].hidden)
					and logic.enemies[i].state_ids.has(3) == Array(after_t1.enemies[i].states).has(3.0)
					and logic.enemies[i].display_name() == str(after_t1.enemies[i].name), [i, reading(logic.enemies[i]), after_t1.enemies[i]])
	# 敌方首次行动回合
	var want := {}
	for a in o.actions:
		if str(a.subject).begins_with("e") and not want.has(a.subject):
			want[a.subject] = int(a.turn)
	check(name + ".first_actions", acted == want, [acted, want])
	for i in range(o.after.enemies.size()):
		check("%s.after.e%d" % [name, i], logic.enemies[i].hidden == bool(o.after.enemies[i].hidden) and logic.enemies[i].display_name() == str(o.after.enemies[i].name),
			[reading(logic.enemies[i]), o.after.enemies[i]])
	if o.has("reappearBefore"):
		for pair in [["reappear", o.reappearBefore, o.reappearAfter], ["dead_appear", o.deadAppearBefore, o.deadAppearAfter]]:
			for i in range(pair[1].enemies.size()):
				put(logic.enemies[i], pair[1].enemies[i])
			run_list(logic, [{"code": 335, "indent": 0, "parameters": [1]}])
			check("%s.%s" % [name, pair[0]], same(logic.enemies[1], pair[2].enemies[1], true, true), [reading(logic.enemies[1]), pair[2].enemies[1]])


## 游标细项（不依赖参照）：旧 token、退出战斗清游标、隐藏成员不算胜负与奖励
func _unit_checks() -> void:
	var logic := setup(165)
	logic.turn = 4
	logic._event_flags.clear()
	var logs := logic.troop_events()
	check("cursor.waiting", logic.is_event_waiting() and not logs.is_empty() and logs[-1].type == "message", logs.map(func(l): return l.type))
	var w := logic.event_waiting()
	check("cursor.stale_token", logic.resume_event(int(w.token) + 1).is_empty() and logic.is_event_waiting())
	check("cursor.no_reentry", logic.troop_events().is_empty() and logic.enemies[0].enemy_id == 174)
	logic.resume_event(int(w.token))
	check("cursor.resumed", not logic.is_event_waiting() and logic.enemies[0].enemy_id == 175, reading(logic.enemies[0]))
	check("cursor.dup_confirm", logic.resume_event(int(w.token)).is_empty())
	logic.turn = 4
	logic._event_flags.clear()
	logic.enemies[0].enemy_id = 174
	logic.troop_events()
	logic.end_battle()
	check("cursor.cleared_on_end", not logic.is_event_waiting())
	var l824 := setup(824, {1178: 5})
	for i in range(1, l824.enemies.size()):
		check("hidden.not_alive_not_dead.e%d" % i, not l824.enemies[i].is_alive() and not l824.enemies[i].is_dead())
	l824.enemies[0].hp = 0
	l824.enemies[0].refresh_resources()
	check("hidden.won_without_hidden", l824.is_won())
	# deadMembers：没出现的成员不给经验；全部出现并倒下时经验按 6 只算
	var exp_one: int = l824.rewards().exp
	for e in l824.enemies:
		e.hidden = false
		e.hp = 0
	var exp_all: int = l824.rewards().exp
	check("hidden.rewards_skip", l824.enemies[0].exp_reward() == 0 or exp_all > exp_one, [exp_one, exp_all])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
