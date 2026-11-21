extends Node
## T346：半步真仙效果 1666 在一次行动的多段（5746 极致·灭魂雷 连续两次、天启篇改三段）里的总账换写。
## 现象（T121 段3 Neon 核查）：行动内确认阶段列表（XBattler.effect_lists／effect_snapshot）一次行动只建一次，
##   第 1 段打完 1666 从持有者自删（FIX_HALFSTEP_1666），列表里还留着它（KRZ 缓存原样）；
##   总账 live_confirm_rows 原来只认实时 a.states()，第 2 段起认不出 1666，不换写 →
##   原版确认程序 target.gainHp(-value) 照跑：敌人另扣一次等于本击伤害的血（二次扣血），守卫报 confirm#1666 未登记乘区（实为 pool 条目）。
## 修后：第 2 段起 1666 照样换写（③ 不再加、确认阶段打敌人不另扣血），守卫不报；
##   西游档（POOL_LIVE 关）不变：缓存里的 1666 照原版另扣血（KRZ 缓存行为，原版也这样）。
##   打自己人：第 2 段 as 的 mul ×2 不带跳过，照旧 ×2（＝原版另扣一次，扣血总量一样）。

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
	# 同 xiyou_tianqi_live_sample：总开关关着时的条件（原版量级），只单开 POOL_LIVE
	XTianqiBase.PHASE4 = false
	XTianqiSkills.MASTERY = false
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	kit = Kit.new("xiyou_tianqi_halfstep_multihit")
	seed(20261121)
	XTianqiLedger.reload_table()
	XTianqiLedger.QUIET = true
	_runtime()
	XTianqiLedger.POOL_LIVE = false
	XTianqiLedger.QUIET = false
	XTianqiLedger.reload_table()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 真实整次行动（XBattleLogic.execute，5746 连续两次）：挂不挂 1666，返回 {loss 敌人掉的血, hits [每段记的 hp], flags 守卫报 confirm#1666 的条数, held 打完还挂着没}
func _action(logic: XBattleLogic, u: XActor, e: XBattler, skill: Dictionary, halfstep: bool) -> Dictionary:
	u.remove_state(1666)
	if halfstep:
		u.add_state(1666)
	u.param_refresh()  # 行动开头：确认阶段列表冷着、这次行动里头一回读时建
	e.hp = e.mhp
	var before := float(e.hp)
	var v0 := XTianqiLedger.violations.size()
	var logs := logic.execute(u, skill, e, true)
	var hits := []
	for l in logs:
		if l is Dictionary and l.get("type") == "hit" and is_same(l.get("target"), e):
			hits.append(float(l.get("hp", 0.0)))
	var flags := XTianqiLedger.violations.slice(v0).filter(func(v): return str(v.get("field", "")) == "confirm#1666").size()
	return {"loss": before - float(e.hp), "hits": hits, "flags": flags, "held": u.is_state_affected(1666)}


func _runtime() -> void:
	var s := _state()
	var logic := XBattleLogic.new()
	logic.setup(70, s)  # 木桩Ⅰ：血多，多段打不死
	var u: XActor = logic.actors[0]
	var e: XBattler = logic.enemies[0]
	var skill: Dictionary = XDB.rec("Skills", 5746).duplicate(true)
	skill.damage.variance = 0  # 去掉浮动和暴击，段段同量
	skill.damage.critical = false
	_check("skill_5746_multihit", int(skill.get("repeats", 1)) >= 2, [skill.get("repeats")])
	XStateEffects.FIX_HALFSTEP_1666 = true

	# 一、天启篇（POOL_LIVE、POOL_LIVE_PROBE 开）
	XTianqiLedger.POOL_LIVE = true
	XTianqiLedger.POOL_LIVE_PROBE = true
	var base := _action(logic, u, e, skill, false)
	var hs := _action(logic, u, e, skill, true)
	var n: int = (base.hits as Array).size()
	var per: float = float(base.loss) / maxf(1.0, float(n))
	_check("tq_premise", n >= 2 and per > 0.0 and not bool(hs.held), [base, hs])
	# 只多吃一下：第 1 段 ③＋100%（这一段记的 hp 变大），第 2 段起同不挂时一样；除了各段记的 hp 之外，敌人不再另掉血（改前第 2 段起原版程序另扣一次＝二次扣血）
	var hb: Array = base.hits
	var hh: Array = hs.hits
	var hit_gain := 0.0
	for i in mini(hb.size(), hh.size()):
		hit_gain += float(hh[i]) - float(hb[i])
	var extra := float(hs.loss) - float(base.loss) - hit_gain
	_check("tq_first_hit_pooled", hh.size() == hb.size() and float(hh[0]) > float(hb[0]) * 1.3, [hb, hh])
	_check("tq_later_hits_plain", hh.size() == hb.size() and hh.slice(1) == hb.slice(1), [hb, hh])
	_check("tq_no_second_deduct", absf(extra) <= float(hb[0]) * 0.01, [extra, base.loss, hs.loss, hb, hh])
	_check("tq_no_unregistered_1666", int(hs.flags) == 0, [hs.flags])

	# 二、西游档（POOL_LIVE 关）照原版：不归池，不改（缓存怎么跑就怎么跑，这里只记录、跟改前一致）
	XTianqiLedger.POOL_LIVE = false
	var bx := _action(logic, u, e, skill, false)
	var hx := _action(logic, u, e, skill, true)
	print("XIYOU_HALFSTEP ", JSON.stringify({"base": bx.loss, "halfstep": hx.loss, "hits": hx.hits, "per": float(bx.loss) / maxf(1.0, float((bx.hits as Array).size()))}))
	results.append({"name": "xiyou_record", "passed": true, "detail": null})
	XTianqiLedger.POOL_LIVE = false
	u.remove_state(1666)
