extends Node
## 天启篇六维只读模块（XTianqiSixDim，T275）专项：
## 一、13 份样板读取准确（谷雨 175 待 Kyo 重定分，先不录、断言跳过）（字母、总分、韧性抗控、战商档）。
## 二、没录的角色／敌人回中性；敌人模板继承与单只覆盖。
## 三、西游档、ENABLED＝false 全返回中性；权重表读取。

var results: Array = []

const SIX := {
	"knights": {"death": "S SS E B A E", "war": "S C SS D D B", "famine": "A C B SS A E", "plague": "D C D S B SS"},
	"actors": {180: "S A B SS C E", 107: "D SS E B S B", 168: "A A B B B C", 45: "A D SSS C D E",
		174: "D D B A B S", 71: "B D D S A B", 6: "A C B D D E", 31: "E C C C B A", 60: "D B C E E D"},
}
const TOTALS := {"death": 24, "war": 24, "famine": 25, "plague": 24, 180: 26, 107: 24, 168: 25, 45: 21, 174: 23, 71: 23, 6: 17, 31: 19, 60: 13}
const RESIST := {"death": 5, "war": -5, "famine": 5, "plague": 2, 180: 0, 107: 7, 168: 2, 45: -5, 174: 2, 71: 5, 6: -5, 31: 2, 60: -10}


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _expect(six: Dictionary, spec: String) -> bool:
	var parts := spec.split(" ")
	for i in 6:
		if str(six[XTianqiSixDim.DIMS[i]]) != parts[i]:
			return false
	return true


func _tianqi_on() -> void:
	var s := XState.new()
	s.flags["tianqi"] = {"rules": 1}
	XState.current = s


func _run() -> void:
	XTianqiSixDim.ENABLED = true
	_tianqi_on()
	_check("active_on", XTianqiSixDim.active())
	for k in SIX.knights:
		var six := XTianqiSixDim.of_knight(k)
		_check("knight_" + k, _expect(six, SIX.knights[k]), six)
		_check("knight_total_" + k, XTianqiSixDim.total(six) == TOTALS[k], XTianqiSixDim.total(six))
		_check("knight_resist_" + k, XTianqiSixDim.resist_pct_of(six) == RESIST[k], XTianqiSixDim.resist_pct_of(six))
	for id in SIX.actors:
		var six := XTianqiSixDim.of_actor(id)
		_check("actor_%d" % id, _expect(six, SIX.actors[id]), six)
		_check("actor_total_%d" % id, XTianqiSixDim.total(six) == TOTALS[id], XTianqiSixDim.total(six))
		_check("actor_resist_%d" % id, XTianqiSixDim.resist_pct_of(six) == RESIST[id], XTianqiSixDim.resist_pct_of(six))
	var gojo := XTianqiSixDim.of_actor(180)
	_check("tier_gojo_5", XTianqiSixDim.ai_tier_of(gojo) == 5)
	_check("tier_plague_4", XTianqiSixDim.ai_tier_of(XTianqiSixDim.of_knight("plague")) == 4)
	_check("tier_war_2", XTianqiSixDim.ai_tier_of(XTianqiSixDim.of_knight("war")) == 2)
	var w := XTianqiSixDim.ai_weights_of(XTianqiSixDim.of_knight("plague"))
	_check("weights_plague", w.support_pct == 200 and w.summon_pct == 220 and w.aggro_pct == 85 and w.guard_hp_pct == 35 and w.repeat_pct == 110 and w.panic_pct == 0, w)
	_check("score_letters", XTianqiSixDim.score("E") == 1 and XTianqiSixDim.score("SSS") == 8 and XTianqiSixDim.score("B") == 4)
	# 没录的回中性
	var neu := XTianqiSixDim.neutral()
	_check("unknown_actor_neutral", XTianqiSixDim.of_actor(99999) == neu)
	_check("unknown_enemy_neutral", XTianqiSixDim.of_enemy(99999) == neu)
	_check("unknown_knight_neutral", XTianqiSixDim.of_knight("nope") == neu)
	_check("neutral_values", XTianqiSixDim.total(neu) == 18 and XTianqiSixDim.resist_pct_of(neu) == 0 and XTianqiSixDim.ai_tier_of(neu) == 3)
	_check("null_battler_neutral", XTianqiSixDim.of_battler(null) == neu)
	var nw := XTianqiSixDim.ai_weights_of(neu)
	_check("neutral_weights", nw.support_pct == 100 and nw.aggro_pct == 100 and nw.panic_pct == 0 and nw.guard_hp_pct == 35, nw)
	# 敌人模板继承与覆盖（临时塞数据，用完还原）
	var saved: Dictionary = XTianqiSixDim._data.duplicate(true)
	XTianqiSixDim._data.enemies = {"9001": {"template": "beast"}, "9002": {"template": "guard", "wit": "A"}, "9003": {"template": "gone"}}
	_check("enemy_template", _expect(XTianqiSixDim.of_enemy(9001), "C D C E D E"), XTianqiSixDim.of_enemy(9001))
	_check("enemy_override", _expect(XTianqiSixDim.of_enemy(9002), "C B D A B D"), XTianqiSixDim.of_enemy(9002))
	_check("enemy_bad_template_neutral", XTianqiSixDim.of_enemy(9003) == neu)
	XTianqiSixDim._data = saved
	# 开关关
	XTianqiSixDim.ENABLED = false
	_check("off_inactive", not XTianqiSixDim.active())
	_check("off_actor", XTianqiSixDim.of_actor(180) == neu and XTianqiSixDim.of_knight("death") == neu)
	_check("off_resist_tier", XTianqiSixDim.resist_pct_of(gojo) == 0 and XTianqiSixDim.control_resist_pct(null) == 0 and XTianqiSixDim.ai_tier_of(gojo) == 3)
	_check("off_weights", XTianqiSixDim.ai_weights_of(XTianqiSixDim.of_knight("plague")).support_pct == 100)
	XTianqiSixDim.ENABLED = true
	# 西游档
	XState.current = XState.new()
	_check("legacy_inactive", not XTianqiSixDim.active())
	_check("legacy_actor", XTianqiSixDim.of_actor(107) == neu and XTianqiSixDim.of_knight("war") == neu)
	_check("legacy_resist", XTianqiSixDim.resist_pct_of(XTianqiSixDim.of_actor(107)) == 0)
	XState.current = null
	_check("nostate_inactive", not XTianqiSixDim.active() and XTianqiSixDim.of_actor(107) == neu)

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
