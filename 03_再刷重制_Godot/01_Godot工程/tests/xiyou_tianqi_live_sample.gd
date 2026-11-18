extends Node
## T185 期四 live 状态样板（damage_ledger.json state_confirm_class.sample，XTianqiLedger.POOL_LIVE，默认关）：
## 一、表：10 条（技能 5、装备 5），都在 live 类里；pool 的 add 是整数、等于原版 ×k 的 k−1（百分数），cap 只认 secret／nine；每条有理由、改前改后。
## 二、默认关：开关关着时样板不起作用，伤害、确认阶段和原版现状一样；守卫照旧按 live 豁免。
## 三、开着：装备来源（838 落炎之语 ×1.3）打敌人 ③ ＋30%、确认阶段那一步不乘；治疗、打自己人照旧 ×1.3；
##     秘籍格来源（2441 我祖我宗 ×1.8）进③封到每本 ＋8%；停用（2300 天顶剑 ×2）不乘也不进池；九线合计封顶收住 2302 紫炎混沌 ＋900%。
## 四、守卫：开着时归池、停用的那一步带标记，audit_confirm 不再当确认阶段乘去认；关着照旧认成 live 豁免。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state() -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_live_sample")
	seed(20261118)
	XTianqiLedger.reload()
	XTianqiLedger._live_sample = {}
	_table()
	_runtime()
	XTianqiLedger.POOL_LIVE = false
	XTianqiLedger.CAP_NINE = true
	XTianqiLedger.QUIET = false
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _mul_k(sid: int) -> float:
	for e in XDB.rec("States", sid).get("effects", []):
		if XTianqiLedger._live_effect(e):
			return float(e.k)
	return 0.0


# ---- 一、表 ----
func _table() -> void:
	var cls: Dictionary = XTianqiLedger.data().get("state_confirm_class", {})
	var sample: Array = cls.get("sample", [])
	var live := {}
	for g in cls.get("live", {}):
		for e in cls.live[g]:
			live[int(e.id)] = g
	var by_src := {"skill": 0, "gear": 0}
	var bad := []
	for e in sample:
		var sid := int(e.id)
		by_src[str(e.src)] = int(by_src.get(str(e.src), 0)) + 1
		var k := _mul_k(sid)
		var ok: bool = live.has(sid) and k > 1.0 and str(e.get("reason", "")).length() >= 4 and str(e.get("before", "")) != "" and str(e.get("after", "")) != "" and str(e.get("source", "")) != ""
		ok = ok and live[sid] in (["skill", "skill_gear"] if str(e.src) == "skill" else ["gear", "skill_gear"])
		match str(e.get("action", "")):
			"pool":
				ok = ok and typeof(e.add) == TYPE_FLOAT and float(e.add) == floorf(float(e.add)) and int(e.add) == int(roundf((k - 1.0) * 100.0)) and str(e.get("cap", "")) in ["secret", "nine"]
			"stop":
				ok = ok and int(e.get("add", 0)) == 0
			_:
				ok = false
		if not ok:
			bad.append(sid)
	_check("sample_shape", sample.size() == 10 and by_src.skill == 5 and by_src.gear == 5 and bad.is_empty(), [sample.size(), by_src, bad])
	_check("sample_has_stop_and_pool", sample.any(func(e): return e.action == "stop" and e.src == "skill") and sample.any(func(e): return e.action == "stop" and e.src == "gear") \
		and sample.filter(func(e): return e.action == "pool").size() >= 6)
	_check("default_off", XTianqiLedger.POOL_LIVE == false and XTianqiLedger.switch_on("POOL_LIVE") == false)


func _fresh(a: XActor, ids: Array) -> void:
	for sid in [838, 2441, 2300, 2302]:
		a.remove_state(sid)
	for sid in ids:
		a.add_state(int(sid))
	a.effect_snapshot_valid = false
	a.effect_lists = {}


func _terminal(a, e) -> float:
	return float(XDamage.calculate(XDB.rec("Skills", 1), a, e, {"critical": false, "variance": false}).breakdown.row.terminal)


## 确认阶段（对敌人、伤害 100）跑完的值
func _confirm(a, target, dtype := 1, value := 100.0) -> float:
	var item: Dictionary = XDB.rec("Skills", 1).merged({"damage": {"type": dtype}}, true)
	return XStateEffects.run("confirm", a, {"attacker": a, "defender": target, "item": item, "value": value, "execute": false})


# ---- 二～四、运行期 ----
func _runtime() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	var mate := s.actor(int(s.battle_slots[1]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	XTianqiLedger.CAP_NINE = false  # 先看归池本身（③ ＋30%），封顶单测
	# 二、默认关
	_fresh(a, [838])
	XTianqiLedger.POOL_LIVE = false
	var t_off := _terminal(a, e)
	var c_off := _confirm(a, e)
	_check("off_untouched", XTianqiLedger.live_sample_effects(a).is_empty() and absf(c_off - 130.0) <= 1.0 and is_equal_approx(float(XTianqiLedger.live_confirm_add(a, e, 1).add), 0.0), [c_off])
	# 三、开着：装备来源
	XTianqiLedger.POOL_LIVE = true
	var t_on := _terminal(a, e)
	var c_on := _confirm(a, e)
	var heal := _confirm(a, e, 3, -100.0)
	var self_hit := _confirm(a, mate)
	_check("gear_pooled", is_equal_approx(t_on, t_off + 0.3) and absf(c_on - 100.0) <= 0.01 and heal <= -129.0 and self_hit >= 129.0, [t_off, t_on, c_on, heal, self_hit])
	XTianqiLedger.POOL_LIVE = false
	_check("gear_rollback", is_equal_approx(_terminal(a, e), t_off) and absf(_confirm(a, e) - 130.0) <= 1.0)
	XTianqiLedger.POOL_LIVE = true
	# 秘籍格来源：＋80% 封到每本 ＋8%
	_fresh(a, [2441])
	var per := XTianqiBase.secret_slot(XTianqiLedger.nine_cap("secret_slot"))
	var sec: Dictionary = XTianqiLedger.live_confirm_add(a, e, 1)
	_check("secret_capped", is_equal_approx(float(sec.add), per) and is_equal_approx(float(sec.nine), 0.0) and absf(_confirm(a, e) - 100.0) <= 0.01, [sec, per])
	# 停用：不乘、不进池
	_fresh(a, [2300])
	var stop: Dictionary = XTianqiLedger.live_confirm_add(a, e, 1)
	_check("stop_no_pool", is_equal_approx(float(stop.add), 0.0) and absf(_confirm(a, e) - 100.0) <= 0.01 and _confirm(a, mate) >= 199.0, [stop])
	# 九线合计封顶收住 ＋900%
	_fresh(a, [2302])
	var raw := _terminal(a, e)
	XTianqiLedger.CAP_NINE = true
	var capped := _terminal(a, e)
	_check("nine_cap_bites", raw >= 9.9 and capped <= raw - 8.0, [raw, capped])
	# 四、守卫
	_fresh(a, [838, 2300])
	XTianqiLedger.QUIET = true
	var ctx := {"defender": e, "item": XDB.rec("Skills", 1)}
	var rows: Array = XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false))
	var got_on := XTianqiLedger.audit_confirm(a, rows, ctx).filter(func(r): return int(r.state) in [838, 2300])
	XTianqiLedger.POOL_LIVE = false
	var rows_off: Array = XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false))
	var got_off := XTianqiLedger.audit_confirm(a, rows_off, ctx).filter(func(r): return int(r.state) in [838, 2300])
	_check("guard_marks", got_on.is_empty() and got_off.size() == 2 and got_off.all(func(r): return r.ok and r.source == "state_confirm"), [got_on, got_off])
	_fresh(a, [])
