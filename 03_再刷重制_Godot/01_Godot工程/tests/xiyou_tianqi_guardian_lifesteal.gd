extends Node
## 【cc·T392】守层者高倍吸血按天启篇难度封顶（XGuardianRework.steal_cap，Kyo 11-22 事项26）：
## 一、天启篇 19 层炎龙队长放「厄运剥夺」3805：一次吸回 ＝ 打出伤害 × 本档 pct%（五档各验一次，照表）。
## 二、表里没列的招（同样带吸血）照原样；我方角色吸血照原样。
## 三、回退 LIFESTEAL_CAP=false：照原样（XLifeSteal.amount × heal_scale）。
## 四、西游档同一场同一招：照原版 10000%，跟没有本功能逐值一样。

const TROOP := 333   # 19 层守层者那场
const SKILL := 3805
const DMG := 1000.0
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	seed(20261122)
	var item: Dictionary = XDB.rec("Skills", SKILL)
	_check("skill_has_lifesteal", float(item.get("lifeSteal", {}).get("hpRate", 0.0)) >= 100.0, item.get("lifeSteal"))
	var pct: Dictionary = XTianqiBalance.data().get("guardian_phase4", {}).get("lifesteal_cap", {}).get("pct", {})
	_check("table_five_tiers", pct.size() == 5 and XTianqiBalance.difficulty_keys().all(func(k): return pct.has(k) and int(pct[k]) == float(pct[k])), pct)
	# 一、五档各一次
	for key in XTianqiBalance.difficulty_keys():
		var st := _tianqi(key)
		var r := _gain(st, item)
		var hm := XTianqiBase.enemy_hp_mult(st)  # T501 R2 小A 核 P2-1：封顶跟守层者血量同缩（开着 0.4）
		_check("cap_" + key, r.size() == 2 and is_equal_approx(r[0], floorf(DMG * int(pct.get(key, 0)) / 100.0 * hm)) and r[0] < r[1] and is_equal_approx(hm, 0.4), [r, hm])
	# 二、没列的招、我方角色
	var other := item.duplicate(true)
	other["id"] = 999991
	var ro := _gain(_tianqi("jianxian"), other)
	_check("other_skill_uncapped", ro.size() == 2 and is_equal_approx(ro[0], ro[1]) and ro[0] > DMG, ro)
	var s := _tianqi("jianxian")
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var a: XBattler = logic.actors[0]
	_check("actor_uncapped", is_equal_approx(XGuardianRework.steal_cap(a, item, DMG, 5000.0), 5000.0))
	# 三、回退
	XGuardianRework.LIFESTEAL_CAP = false
	var rb := _gain(_tianqi("jianxian"), item)
	XGuardianRework.LIFESTEAL_CAP = true
	_check("rollback", rb.size() == 2 and is_equal_approx(rb[0], rb[1]) and rb[0] > DMG, rb)
	# 四、西游档
	var xs := _xiyou()
	var rx := _gain(xs, item)
	_check("xiyou_original", rx.size() == 2 and is_equal_approx(rx[0], rx[1]) and is_equal_approx(rx[1], floorf(DMG * float(item.lifeSteal.hpRate))), rx)
	XGuardianRework.LIFESTEAL_CAP = false
	var rx0 := _gain(_xiyou(), item)
	XGuardianRework.LIFESTEAL_CAP = true
	_check("xiyou_same_as_off", rx.size() == 2 and rx0.size() == 2 and rx[0] == rx0[0], [rx, rx0])
	_finish()


## 守层者对第一名角色打出 DMG 后吸回多少：[实际回血, 不封顶时应回]
func _gain(s: XState, item: Dictionary) -> Array:
	XState.current = s
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var g: XEnemy = null
	for e in logic.enemies:
		if XGuardianRework.guardian_floor(e) == 19:
			g = e
	if g == null:
		return []
	var t: XBattler = logic.actors[0]
	g.hp = 1.0
	var before := g.hp
	logic._action_resources = logic._new_lifecycle_resources()
	logic._life_steal(g, DMG, item, t)
	logic._action_resources.publish()
	logic._action_resources = null
	var raw := floorf(XLifeSteal.amount(g, item, DMG / XTianqiNoX6.dealt_scale(g, t)) * XTianqiNoX6.heal_scale(g))
	return [g.hp - before, minf(raw, g.mhp - before)]


func _tianqi(key: String) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, 19)
	XState.current = s
	return s


func _xiyou() -> XState:
	var s := XState.new_game(XTianqi.legacy_of("jianxian"), 1, [2, 8, 9])
	s.set_variable(20, 19)
	XState.current = s
	return s


func _finish() -> void:
	XGuardianRework.LIFESTEAL_CAP = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
