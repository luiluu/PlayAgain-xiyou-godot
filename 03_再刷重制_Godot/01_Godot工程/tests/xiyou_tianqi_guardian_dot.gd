extends Node
## 【cc·T402】22 层三眼娃毒伤按层单列比例（XGuardianRework.dot_pct，D257 Kyo 11-22）：
## 一、天启篇 22 层守层者本身挂的 猩红飞蛇之毒 177、出血 91：一跳 ＝ ⌊持有者生命上限 × 15%／13%⌋（照表；整轮回合末结算也是这个数±波动）。
## 二、别人挂同一状态照 T080 换算（65%／58%）：施加者是角色、持有者自己、19 层守层者；表里没列的状态照原样。
## 三、回退 DOT_PCT=false：照 T080 换算。
## 四、西游档：照原版常数 4500／4000，跟开关关逐值一样。

const TROOP := 458   # 22 层守层者那场
const TROOP19 := 333
const POISON := 177
const BLEED := 91
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	seed(20261123)
	var row: Dictionary = XTianqiBalance.data().get("guardian_phase4", {}).get("dot_pct", {}).get("22", {})
	_check("table_22", int(row.get(str(POISON), 0)) == 15 and int(row.get(str(BLEED), 0)) == 13, row)
	var orig := {POISON: 4500.0, BLEED: 4000.0}
	var old_pct := {POISON: 65, BLEED: 58}
	# 一、22 层守层者本身
	var s := _tianqi("jianxian")
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var g := _guardian(logic, 22)
	var t: XBattler = logic.actors[0]
	_check("guardian_found", g != null)
	if g == null:
		_finish()
		return
	for sid in [POISON, BLEED]:
		var t080 := XTianqiBase.dot_value(sid, orig[sid], t, {})
		_check("t080_%d" % sid, t080 == floorf(t.mhp * old_pct[sid] / 100.0), [t080, t.mhp])
		var v := XGuardianRework.dot_pct(sid, t080, g, t)
		_check("guardian_%d" % sid, v == floorf(t.mhp * int(row[str(sid)]) / 100.0), [v, t.mhp])
		# 整轮：回合末持续伤害结算（波动 20%）
		var hp := _tick(logic, t, g, sid)
		var want := floorf(t.mhp * int(row[str(sid)]) / 100.0)
		_check("tick_%d" % sid, hp >= floorf(want * 0.8) - 1.0 and hp <= ceilf(want * 1.2) + 1.0, [hp, want])
		# 二、别人挂：角色、自己、19 层守层者
		_check("actor_src_%d" % sid, XGuardianRework.dot_pct(sid, t080, logic.actors[1], t) == t080)
		_check("self_src_%d" % sid, XGuardianRework.dot_pct(sid, t080, t, t) == t080)
		var l19 := XBattleLogic.new()
		l19.setup(TROOP19, s)
		var g19 := _guardian(l19, 19)
		_check("floor19_src_%d" % sid, g19 != null and XGuardianRework.dot_pct(sid, t080, g19, t) == t080)
		# 三、回退
		XGuardianRework.DOT_PCT = false
		_check("rollback_%d" % sid, XGuardianRework.dot_pct(sid, t080, g, t) == t080)
		var hp0 := _tick(logic, t, g, sid)
		XGuardianRework.DOT_PCT = true
		_check("rollback_tick_%d" % sid, hp0 >= floorf(t080 * 0.8) - 1.0, [hp0, t080])
	_check("unlisted_state", XGuardianRework.dot_pct(84, 3000.0, g, t) == 3000.0)
	# 四、西游档
	var xs := _xiyou()
	var xl := XBattleLogic.new()
	xl.setup(TROOP, xs)
	var xg: XEnemy = xl.enemies[0] if not xl.enemies.is_empty() else null
	var xt: XBattler = xl.actors[0]
	for sid in [POISON, BLEED]:
		var v := XTianqiBase.dot_value(sid, orig[sid], xt, {})
		_check("xiyou_raw_%d" % sid, v == orig[sid] and XGuardianRework.dot_pct(sid, v, xg, xt) == orig[sid], v)
		var hx := _xiyou_tick(sid)
		XGuardianRework.DOT_PCT = false
		var hx0 := _xiyou_tick(sid)
		XGuardianRework.DOT_PCT = true
		_check("xiyou_same_as_off_%d" % sid, hx == hx0 and hx[0] >= minf(hx[1], floorf(orig[sid] * 0.8)), [hx, hx0])
	_finish()


func _guardian(logic: XBattleLogic, f: int) -> XEnemy:
	for e in logic.enemies:
		if XGuardianRework.guardian_floor(e) == f:
			return e
	return null


## 给 t 挂上 sid（施加者 src），跑一次回合末持续伤害，返回扣掉的血；跑完撤掉状态、回满
func _tick(logic: XBattleLogic, t: XBattler, src, sid: int) -> float:
	t.hp = t.mhp
	t.add_state(sid)
	if src != null:
		t.state_origins[sid] = weakref(src)
	seed(20261123)
	var before := t.hp
	var logs := []
	XExtDot.tick(logic, t, logs)
	var lost := before - t.hp
	t.remove_state(sid)
	t.hp = t.mhp
	return lost


## 西游档每次新开一场（低级角色一跳就倒，不能复用）：[扣掉的血, 生命上限]
func _xiyou_tick(sid: int) -> Array:
	var xl := XBattleLogic.new()
	xl.setup(TROOP, _xiyou())
	var xt: XBattler = xl.actors[0]
	var xg: XEnemy = xl.enemies[0] if not xl.enemies.is_empty() else null
	return [_tick(xl, xt, xg, sid), xt.mhp]


func _tianqi(key: String) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, 22)
	XState.current = s
	return s


func _xiyou() -> XState:
	var s := XState.new_game(XTianqi.legacy_of("jianxian"), 1, [2, 8, 9])
	s.set_variable(20, 22)
	XState.current = s
	return s


func _finish() -> void:
	XGuardianRework.DOT_PCT = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
