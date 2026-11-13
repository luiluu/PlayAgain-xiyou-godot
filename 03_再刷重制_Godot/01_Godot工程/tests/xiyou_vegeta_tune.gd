extends Node
## 贝吉特优化调整（XVegetaTune，v0.01.08）专项：
## 一、读表改原件：吃瘪之力 2561 受伤倍率、自我终伤 2777 每层倍率、公共事件 1722 层数封顶、合体赛亚人 2565（乙档）、技能说明。
## 二、按真实状态效果程序结算：吃瘪之力承伤、自我极意功按层数的终伤、合体赛亚人终伤／暴击。
## 三、自我极意功层数每场战斗开局清零（XBattleLogic.setup）。
## 四、别的状态、技能不动；ENABLED＝false 回原版。
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _reload() -> void:
	for n in ["Skills", "States", "CommonEvents"]:
		XDB._tables.erase(n)


func _run() -> void:
	XMessageBox.auto = true
	_check("defaults", XVegetaTune.ENABLED and XVegetaTune.TIER == "甲")
	var orig := _snapshot(false, "甲")
	var a := _snapshot(true, "甲")
	var b := _snapshot(true, "乙")
	_check("orig_chibie", is_equal_approx(orig.chibie, 10.0), orig.chibie)
	_check("orig_ego20", is_equal_approx(orig.ego20, 100.0 + ceilf(100.0 * 30.0)), orig.ego20)
	_check("orig_ego_cap", orig.cap == 20)
	_check("orig_fusion", is_equal_approx(orig.fusion, 288.0) and is_equal_approx(orig.fusion_crit, 288.0 + ceilf(288.0 * 1.88)), [orig.fusion, orig.fusion_crit])
	_check("jia_chibie", is_equal_approx(a.chibie, 50.0), a.chibie)
	_check("jia_ego10", is_equal_approx(a.ego10, 100.0 + 500.0), a.ego10)
	_check("jia_ego_cap", a.cap == 10)
	_check("jia_fusion_same", a.fusion == orig.fusion and a.fusion_crit == orig.fusion_crit)
	_check("jia_desc", a.desc_chibie.contains("减少50%受到的伤害") and a.desc_ego.contains("增加50%终伤，最多叠加10次") and a.desc_fusion == orig.desc_fusion, [a.desc_chibie, a.desc_ego])
	_check("jia_meta_desc", str(a.meta_chibie).contains("减少50%受到的伤害") and not str(a.meta_chibie).contains("90%"))
	_check("yi_chibie", is_equal_approx(b.chibie, 70.0), b.chibie)
	_check("yi_ego10", is_equal_approx(b.ego10, 100.0 + 300.0), b.ego10)
	_check("yi_fusion", is_equal_approx(b.fusion, 200.0) and is_equal_approx(b.fusion_crit, 200.0 + 100.0), [b.fusion, b.fusion_crit])
	_check("yi_desc", b.desc_fusion.contains("最终伤害+100%，暴击时再+50%") and b.desc_ego.contains("增加30%终伤") and b.desc_chibie.contains("减少30%"))
	_check("others_untouched", a.others == orig.others and b.others == orig.others)
	_reset_per_battle()
	XVegetaTune.ENABLED = true
	XVegetaTune.TIER = "甲"
	_reload()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 按某档读表，算各效果的结果
func _snapshot(on: bool, tier: String) -> Dictionary:
	XVegetaTune.ENABLED = on
	XVegetaTune.TIER = tier
	_reload()
	var s := XState.new_game(3, 1, [])
	XState.current = s
	var v := s.actor(1)
	var e := XEnemy.new().setup(1, 3, 100.0)
	var out := {}
	out.chibie = _run_state("react", v, 2561, 100.0, {"attacker": e, "defender": v})
	s.set_variable(1543, 10)
	out.ego10 = _run_state("confirm", v, 2777, 100.0, {"attacker": v, "defender": e})
	s.set_variable(1543, 20)
	out.ego20 = _run_state("confirm", v, 2777, 100.0, {"attacker": v, "defender": e})
	out.fusion = _run_state("confirm", v, 2565, 100.0, {"attacker": v, "defender": e})
	out.fusion_crit = _run_state("confirm", v, 2565, 100.0, {"attacker": v, "defender": e, "critical": true})
	out.cap = -1
	for l in XDB.table("CommonEvents")[1722].list:
		if int(l.code) == 111 and int(l.parameters[1]) == 1543:
			out.cap = int(l.parameters[3])
	out.desc_chibie = str(XDB.rec("Skills", 9942).note)
	out.meta_chibie = XDB.rec("Skills", 9942).get("meta", {})
	out.desc_ego = str(XDB.rec("Skills", 10568).note)
	out.desc_fusion = str(XDB.rec("Skills", 9940).note)
	var others := []
	for id in [2560, 2562, 2566, 2567, 2770, 2775, 2776, 1421]:
		others.append(JSON.stringify(XDB.rec("States", id)))
	for id in [9941, 9943, 9944, 9945, 10567, 101]:
		others.append(JSON.stringify(XDB.rec("Skills", id)))
	others.append(JSON.stringify(XDB.table("CommonEvents")[1721]))
	out.others = others
	return out


func _run_state(phase: String, holder, id: int, value: float, ctx: Dictionary) -> float:
	var c := ctx.duplicate()
	c.execute = false
	c.value = value
	c.item = {"damage": {"type": 1}, "hitType": 1}
	return XStateEffects.run_one(phase, holder, XDB.rec("States", id), c)


## 每场开局清零：setup 时 1543 归零；关掉开关不清
func _reset_per_battle() -> void:
	for on in [true, false]:
		XVegetaTune.ENABLED = on
		var s := XState.new_game(3, 1, [])
		XState.current = s
		s.set_variable(1543, 20)
		var lg := XBattleLogic.new()
		lg.setup(2, s)
		_check("reset_%s" % ("on" if on else "off"), int(s.variable(1543)) == (0 if on else 20), s.variable(1543))
		lg.end_battle(0)
