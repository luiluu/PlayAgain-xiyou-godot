extends Node
## 【cc·T406】守层者那场血量按层单列整数百分比（XGuardianRework.hp_pct，balance_table.guardian_phase4.hp_pct；协调 11-23 定 A）：
## 一、表：33 层是 1～100 的整数；没写的层（32）取 100。
## 二、天启篇 33 层守层者那场（敌群 469）：生命上限 ＝ 关开关时 × pct%（取整误差 ≤1）；残血变身 930 后上限仍是关开关时变身后 × pct%。
## 三、32 层那场（468）开关开关一样；心魔目标血量 xinmo_hp(33)、七印读的 hp_base(33) 开关开关一样。
## 四、回退 HP_PCT=false：表里写了也是 100，血量回到原样。
## 五、西游档：469 那场开关开关逐值一样。

const TROOP33 := 469
const TROOP32 := 468
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	seed(20261123)
	var tab: Dictionary = XTianqiBalance.data().get("guardian_phase4", {}).get("hp_pct", {})
	var pct = tab.get("33")
	var is_int: bool = (pct is int or pct is float) and float(pct) == floorf(float(pct))   # JSON 读进来是浮点，看有没有小数
	_check("table_33_int", is_int and int(pct) >= 1 and int(pct) <= 100, pct)
	var p := int(pct) if is_int else 100
	_tianqi("jianxian", 33)
	_check("pct_33", XGuardianRework.hp_pct(33) == p)
	_check("pct_32_default", XGuardianRework.hp_pct(32) == 100)
	# 二、33 层守层者那场
	var on33 := _mhp(TROOP33, 33, "jianxian", true)
	var off33 := _mhp(TROOP33, 33, "jianxian", false)
	_check("guardian33_scaled", on33.size() == 1 and off33.size() == 1 and absf(on33[0] - off33[0] * p / 100.0) <= 1.0, [on33, off33, p])
	_check("guardian33_not_noop", p == 100 or on33[0] < off33[0], [on33, off33])
	var tf_on := _mhp_after_transform(true)
	var tf_off := _mhp_after_transform(false)
	_check("transform930_scaled", tf_on[1] == 930 and tf_off[1] == 930 and absf(tf_on[0] - tf_off[0] * p / 100.0) <= 1.0, [tf_on, tf_off])
	# 三、别的层、心魔、七印
	_check("guardian32_same", _mhp(TROOP32, 32, "jianxian", true) == _mhp(TROOP32, 32, "jianxian", false))
	_tianqi("jianxian", 33)
	var xs_on := XGuardianRework.xinmo_hp(33, 537, XState.current)
	var hb_on := XGuardianRework.hp_base(33)
	XGuardianRework.HP_PCT = false
	var xs_off := XGuardianRework.xinmo_hp(33, 537, XState.current)
	var hb_off := XGuardianRework.hp_base(33)
	XGuardianRework.HP_PCT = true
	_check("xinmo_same", xs_on == xs_off, [xs_on, xs_off])
	_check("qiyin_hp_base_same", hb_on == hb_off, [hb_on, hb_off])
	# 四、回退
	XGuardianRework.HP_PCT = false
	_check("rollback_pct", XGuardianRework.hp_pct(33) == 100)
	XGuardianRework.HP_PCT = true
	# 五、西游档（原版敌人血量开局带随机浮动、开关开关都会变，不比整场血量；比这名守层者的血量倍率和 hp_pct）
	var x_on := _xiyou_rate(true)
	var x_off := _xiyou_rate(false)
	_check("xiyou_pct_100", x_on[1] == 100 and x_off[1] == 100, [x_on, x_off])
	_check("xiyou_rate_same", x_on[0] == x_off[0] and not XTianqi.active(XState.current), [x_on, x_off])
	_finish()


## 开一场 troop，返回各敌人生命上限；on＝HP_PCT 开关
func _mhp(troop: int, f: int, key: String, on: bool) -> Array:
	XGuardianRework.HP_PCT = on
	_tianqi(key, f)
	var logic := XBattleLogic.new()
	logic.setup(troop, XState.current)
	XGuardianRework.HP_PCT = true
	return logic.enemies.map(func(e): return float(e.mhp))


## 33 层守层者变身 930 之后的 [生命上限, 敌人号]
func _mhp_after_transform(on: bool) -> Array:
	XGuardianRework.HP_PCT = on
	_tianqi("jianxian", 33)
	var logic := XBattleLogic.new()
	logic.setup(TROOP33, XState.current)
	logic.enemy_transform(0, 930)
	XGuardianRework.HP_PCT = true
	var e: XEnemy = logic.enemies[0]
	return [float(e.mhp), int(e.enemy_id)]


## 西游档 469 那场：[守层者血量倍率 _rates[0]（XGuardianRework.setup 改的就是它）, hp_pct(33)]
func _xiyou_rate(on: bool) -> Array:
	XGuardianRework.HP_PCT = on
	var s := XState.new_game(XTianqi.legacy_of("jianxian"), 1, [2, 8, 9])
	s.set_variable(20, 33)
	XState.current = s
	var logic := XBattleLogic.new()
	logic.setup(TROOP33, s)
	var out := [float(logic.enemies[0]._rates[0]) if not logic.enemies.is_empty() else -1.0, XGuardianRework.hp_pct(33)]
	XGuardianRework.HP_PCT = true
	return out


func _tianqi(key: String, f: int) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, f)
	XState.current = s
	return s


func _finish() -> void:
	XGuardianRework.HP_PCT = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
