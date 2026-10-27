extends Node
## 叠毒等 Regenerate 脚本致死的倒下表现（XBattleLogic.turn_end_battler 的 emit）：对照 oracle/state_js.json poison.tick 的致死行
## （原版 regenerateStateEffects：弹字后脚本 performCollapse，BSC 包装再调一次）——每条致死行在重制里是 regen 记录紧跟一条
## collapse（同一次倒下只记一条），不致死不记。再跑一场真实回合结束：三只敌人叠毒倒下，画面演倒下，胜利与奖励不受影响。
var passed := 0
var total := 0

class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))

func frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func battle(others := [8]) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, others)
	for a in s.members():
		a.refresh_passive()
		a.recover_all()
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	return l

func poisoned(l: XBattleLogic, holder: XBattler, origin, sid: int) -> void:
	XImportedBalance.set_acting(origin)
	holder.add_state(sid)
	XImportedBalance.set_acting(null)

static func shape(logs: Array, holder: XBattler) -> Array:
	return logs.filter(func(x): return x.get("target") == holder and x.type in ["regen", "collapse"]).map(func(x): return x.type)

func _rows() -> void:
	var ref: Dictionary = XDB.load_json("oracle/state_js.json")
	var tick: Dictionary = ref.cases.filter(func(c): return c.id == "poison.tick")[0]
	var lethal: Array = tick.observed.rows.filter(func(r): return bool(r[9]))
	var count := 0
	for row in lethal:
		var sid := int(row[0])
		if not XDB.rec("States", sid).get("effects", []).any(func(e): return str(e.get("op")) == "poison_tick"):
			continue
		check("native.%d.%s.collapses" % [sid, row[1]], not row[12].is_empty() and row[10][0][1], row)
		var l := battle()
		l.actors[0].add_param(6, 100.0)  # 角色 1 敏捷为 0 时 488／505（按来源敏捷）不扣血；原版参照的来源能力值档位也都大于 0
		l.actors[0].param_refresh()
		var holder: XBattler = l.enemies[0] if row[1] == "enemy" else l.actors[0]
		var other: XBattler = l.actors[0] if row[1] == "enemy" else l.enemies[0]
		poisoned(l, holder, other if row[2] == "other" else null, sid)
		holder.hp = 1.0  # 原版 5 血配固定来源档位；这里来源用真实能力值（894 只扣 2.8），1 血保证致死
		var logs := []
		l.turn_end_battler(holder, logs)
		var tag := "%d.%s.%s" % [sid, row[1], row[2]]
		check(tag + ".dead", holder.is_dead(), holder.hp)
		check(tag + ".popup_then_collapse", shape(logs, holder) == ["regen", "collapse"], shape(logs, holder))
		count += 1
	check("rows", count > 0, count)
	# 不致死：只有弹字
	var l := battle()
	var e: XBattler = l.enemies[0]
	poisoned(l, e, l.actors[0], 460)
	var logs := []
	l.turn_end_battler(e, logs)
	check("non_lethal.no_collapse", e.is_alive() and shape(logs, e) == ["regen"], shape(logs, e))
	# 已倒下的持有者（Regenerate 外层不看存活）不再记倒下
	e.hp = 0.0
	e.refresh_resources()
	logs = []
	l.turn_end_battler(e, logs)
	check("already_dead.no_collapse", not logs.any(func(x): return x.type == "collapse"), shape(logs, e))

func _scene() -> void:
	XConfig.set_battle_speed(4)
	XEnemy.force_roll = 100.0
	XState.new_game(3, 1, [8, 9, 10])
	var live := QuietBattle.new()
	live.setup(2, true, false, {})
	add_child(live)
	await frames()
	var l: XBattleLogic = live.logic
	var alive_enemies: Array = l.enemies.filter(func(x): return x.is_alive())
	for x in alive_enemies:
		poisoned(l, x, l.actors[0], 460)
		x.hp = 5.0
	l.start_turn()
	var logs := l.end_turn()
	for x in alive_enemies:
		check("turn_end.%d.collapse_once" % l.enemies.find(x), shape(logs, x) == ["regen", "collapse"], shape(logs, x))
	check("turn_end.won", l.is_won())
	var got := l.rewards()
	await live._play(logs)
	await frames(40)
	for x in alive_enemies:
		check("scene.%d.collapsed" % l.enemies.find(x), not live.sprites[x].appeared)
	# 对照：同一敌群直接置 0 血倒下，奖励（经验、金钱）相同——倒下记录不重复计死亡
	var twin := battle([8, 9, 10])
	for x in twin.enemies:
		if x.is_alive():
			x.hp = 0.0
			x.refresh_resources()
	twin.resolve_collapses()
	var want := twin.rewards()
	check("rewards_same", float(got.get("exp", -1)) == float(want.get("exp", -2)) and float(got.get("gold", -1)) == float(want.get("gold", -2)), [got, want])
	live.logic.end_battle()
	live.queue_free()

func _run() -> void:
	_rows()
	await _scene()
	print("TEST_RESULT=" + JSON.stringify({"total": total, "passed": passed}))
	get_tree().quit(0 if passed == total else 1)
