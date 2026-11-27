extends Node
## 【cc·T534】老承伤率对必中招生效（预算稿 v0.16 九.20 甲，D290；附表一「新·承伤率含必中」6 情形＋数例）：
## 1. 普通必中（hitType 0、没传 mode、非真伤）：我方承伤率＝min(1, max(物承, 魔承))；数例 0.8/0.8→0.8、0.8/1.0→1.0、1.3(/0.8)→1.0、弱者挑战两项 ×0.5→0.5
## 2. 结算带了物理／魔法参数（options.mode）：照旧只取物承／魔承（物理、魔法命中的招本来就各取各的）
## 3. 真伤：恒 1
## 4. 身上已有词条减伤（incomingMultiplier，T530 词条减伤／守套都走这一格）：照乘，不受影响
## 5. 带易伤：有一个 >1 就按 1，易伤不带到必中；承伤穿透对必中按 0
## 6. 绕过结算的持续伤害：不经 XDamage._calculate，本卡不碰（只断言必中分支只在 _calc_incoming 里）
## 另：敌人挨必中不变；开关 CERTAIN_INCOMING 关＝回退；西游档零改动；正式结算 calculate 的 breakdown.row.incoming 跟着变

var results: Array = []


class PActor extends XActor:
	var pd := 1.0
	var md := 1.0
	func sparam(i: int) -> float:
		return pd if i == 6 else (md if i == 7 else super.sparam(i))


class PEnemy extends XEnemy:
	var pd := 1.0
	var md := 1.0
	func sparam(i: int) -> float:
		return pd if i == 6 else (md if i == 7 else super.sparam(i))


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a, b: float, eps := 1e-6) -> bool:
	return a != null and absf(float(a) - b) <= eps


func _state(tianqi := true) -> XState:
	var w: Array = XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _frame(mult := 1.0, ppierce := 0.0, mpierce := 0.0) -> Dictionary:
	return {"incomingMultiplier": mult, "physicalIncomingPierce": ppierce, "magicalIncomingPierce": mpierce}


func _item(hit_type: int) -> Dictionary:
	return {"id": 99534, "scope": 1, "hitType": hit_type, "mpCost": 0, "tpCost": 0,
		"damage": {"type": 1, "elementId": -1, "critical": false, "variance": 0, "formula": "100"}, "effects": [], "note": ""}


func _row_incoming(item: Dictionary, a: XBattler, b: XBattler, extra := {}) -> float:
	var opt := {"critical": false, "variance": false, "rawValue": 10000.0}
	opt.merge(extra, true)
	var r := XDamage.calculate(item, a, b, opt)
	return float(r.get("breakdown", {}).get("row", {}).get("incoming", NAN))


func _p(id: int, pd: float, md: float) -> PActor:
	var p := PActor.new()
	p.setup(id)
	p.pd = pd
	p.md = md
	return p


## 必中分支的直接值（certain=true、非物理非魔法、普通伤害）
func _ci(b: XBattler, f := {}) -> float:
	return XDamage._calc_incoming(b, false, false, "normal", f if not f.is_empty() else _frame(), true)


func _run() -> void:
	var s := _state(true)
	var id := int(s.party[0]) if "party" in s and not s.party.is_empty() else int(XTier.ids(XTier.WEAK)[0])
	var e := XEnemy.new().setup(1, 3, 100.0)
	_check("setup", XTianqi.active(s) and XDamage.CERTAIN_INCOMING and _p(id, 1, 1).is_actor())
	# 1. 普通必中 + 数例
	for c in [[0.8, 0.8, 0.8], [0.8, 1.0, 1.0], [1.0, 0.8, 1.0], [0.6, 0.9, 0.9], [1.3, 1.0, 1.0], [1.3, 0.8, 1.0], [0.8, 1.3, 1.0], [1.3, 1.3, 1.0], [0.5, 0.5, 0.5], [0.0, 0.0, 0.0]]:
		var p := _p(id, c[0], c[1])
		_check("g1_certain_%s_%s" % [c[0], c[1]], _near(_ci(p), c[2]), {"got": _ci(p), "want": c[2]})
	# 弱者挑战：10357 持有者 sparam6/7 都 ×0.5（XWeakChallenge），对必中生效
	_check("g1_weak_x05", _near(_ci(_p(id, 0.5, 0.5)), 0.5))
	# 正式结算（敌人打我方，必中招）明细跟着变
	var p88 := _p(id, 0.8, 0.8)
	_check("g1_calc_row_08_08", _near(_row_incoming(_item(0), e, p88), 0.8), _row_incoming(_item(0), e, p88))
	var p810 := _p(id, 0.8, 1.0)
	_check("g1_calc_row_08_10", _near(_row_incoming(_item(0), e, p810), 1.0))
	# 2. 结算带了 mode 参数 / 物理魔法命中：照旧
	_check("g2_mode_physical_param", _near(_row_incoming(_item(0), e, _p(id, 0.7, 0.9), {"mode": "physical"}), 0.7))
	_check("g2_mode_magical_param", _near(_row_incoming(_item(0), e, _p(id, 0.7, 0.9), {"mode": "magical"}), 0.9))
	_check("g2_mode_mixed_param_unchanged", _near(_row_incoming(_item(0), e, _p(id, 0.7, 0.9), {"mode": "mixed"}), 1.0))
	_check("g2_physical_hit", _near(_row_incoming(_item(1), e, _p(id, 0.7, 0.9)), 0.7))
	_check("g2_magical_hit", _near(_row_incoming(_item(2), e, _p(id, 0.7, 0.9)), 0.9))
	# 3. 真伤
	_check("g3_true_damage", _near(XDamage._calc_incoming(_p(id, 0.5, 0.5), false, false, "true", _frame(), true), 1.0)
		and _near(_row_incoming(_item(0), e, _p(id, 0.5, 0.5), {"kind": "true"}), 1.0))
	# 4. 词条减伤（incomingMultiplier）照乘
	_check("g4_affix_mult", _near(_ci(_p(id, 0.8, 0.8), _frame(0.75)), 0.6) and _near(_ci(_p(id, 1.3, 1.3), _frame(0.75)), 0.75))
	# 5. 穿透对必中按 0
	_check("g5_pierce_zero", _near(_ci(_p(id, 0.8, 0.6), _frame(1.0, 0.5, 0.5)), 0.8))
	_check("g5_pierce_still_on_physical", _near(XDamage._calc_incoming(_p(id, 0.8, 0.6), true, false, "normal", _frame(1.0, 0.5, 0.5), false), 0.9))
	# 6. 持续伤害绕过结算：只有 _calculate 传 certain，别的入口不传＝默认 false＝旧行为
	_check("g6_default_certain_false", _near(XDamage._calc_incoming(_p(id, 0.8, 0.8), false, false, "normal", _frame()), 1.0))
	# 敌人挨必中不变
	var pe := PEnemy.new().setup(1, 3, 100.0)
	pe.pd = 0.5
	pe.md = 0.5
	_check("enemy_unchanged", _near(_ci(pe), 1.0) and _near(_row_incoming(_item(0), _p(id, 1, 1), pe), 1.0))
	# 开关关＝回退
	XDamage.CERTAIN_INCOMING = false
	var off := _row_incoming(_item(0), e, _p(id, 0.8, 0.8))
	XDamage.CERTAIN_INCOMING = true
	_check("switch_off_back_to_1", _near(off, 1.0), off)
	# 西游档零改动
	var sx := _state(false)
	_check("xiyou_unchanged", not XTianqi.active(sx) and _near(_ci(_p(id, 0.8, 0.8)), 1.0) and _near(_row_incoming(_item(0), e, _p(id, 0.8, 0.8)), 1.0))
	XState.current = s
	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL %s %s" % [r.name, JSON.stringify(r.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
