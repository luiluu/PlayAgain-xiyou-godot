extends Node
## 疫病越拖越重上限专项（T380／K4，D4「以游戏为准」）：瘟疫骑士的「疫病」让我方八项属性开局 −10%、每回合再 −5%，上限实装值 −33%（horsemen.json plague.down_cap）。
## 钉住：配置里三个数；实打开局 0.10；逐回合 0.15、0.20、0.25、0.30、0.33；到顶后再多打回合也停在 0.33；顶上的真实攻击确实只比无疫病低 33%（再叠病弱 6%）。
## 反例：把 down_cap 改成 0.40 或去掉 minf，本专项会挂（见交付单「反向验证」）。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


## 天启篇存档、5 个弱者，每人加厚生命和防御（骑士一击会打倒 1 级角色），好连打十几回合
func _logic() -> XBattleLogic:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := w.slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		var a := s.actor(id)
		a.add_param(0, 2.0e9)
		a.add_param(3, 10000.0)
		a.add_param(5, 10000.0)
		a.recover_all()
	XTianqiHorsemen.prepare("plague", s)
	var lg := XBattleLogic.new()
	lg.setup(0, s)
	return lg


func _guard_all(lg: XBattleLogic) -> Dictionary:
	var c := {}
	for a in lg.actors:
		c[a] = [XDB.rec("Skills", 2), null]
	return c


func _run() -> void:
	XMessageBox.auto = true
	seed(20261122)
	# 一、配置：开局 0.10、每回合 0.05、上限 0.33（不是稿 v0.10 写的 0.40）
	var p: Dictionary = XTianqiHorsemen.knight("plague").plague
	_check("cfg_start", _near(float(p.down_start), 0.10), p.down_start)
	_check("cfg_per", _near(float(p.down_per), 0.05), p.down_per)
	_check("cfg_cap", _near(float(p.down_cap), 0.33), p.down_cap)
	# 二、实打
	var lg := _logic()
	var f := XTianqiHorsemen.fight(lg)
	var a: XActor = lg.actors[0]
	_check("start_marked", bool(XTianqiHorsemen.mark_of(lg, a).get("plague", false)))
	_check("start_down", _near(float(f.plague_down), 0.10), f.plague_down)
	var seen: Array = []
	for i in range(14):
		lg.run_turn(_guard_all(lg))
		seen.append(snappedf(float(f.plague_down), 0.0001))
	var want := [0.15, 0.20, 0.25, 0.30, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33]
	_check("turn_curve", seen == want, seen)
	_check("never_above_cap", seen.all(func(v): return v <= 0.33 + 1e-9), seen)
	_check("stops_at_cap", _near(float(f.plague_down), 0.33) and seen[5] == seen[13], f.plague_down)
	# 三、顶上的真实攻击：疫病 −33%，再叠病弱（疫病＋嘲讽两个减益）−6%
	var m: Dictionary = XTianqiHorsemen.mark_of(lg, a)
	var atk_cap := a.atk
	m.erase("plague")
	a.param_mark_dirty()
	var atk_free := a.atk
	m.plague = true
	a.param_mark_dirty()
	_check("atk_at_cap", absf(atk_cap - roundf(atk_free * 0.67 * 0.94)) <= 2.0, [atk_free, atk_cap])
	_check("atk_not_at_old_40", absf(atk_cap - roundf(atk_free * 0.60 * 0.94)) > 2.0, [atk_free, atk_cap])
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
