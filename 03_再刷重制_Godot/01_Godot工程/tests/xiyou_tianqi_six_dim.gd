extends Node
## 天启篇六维只读模块（XTianqiSixDim，T275）专项：
## 一、14 份读取准确（四骑士＋10 角色，含谷雨 175；T280 起角色六维是全员实测重算值）（字母、总分、韧性抗控、战商档）；全员表 156 人都在且字母合法。
## 二、没录的角色／敌人回中性；敌人模板继承与单只覆盖。
## 三、西游档、ENABLED＝false 全返回中性；权重表读取。

var results: Array = []

const SIX := {
	"knights": {"death": "S SS E B A E", "war": "S C SS D D B", "famine": "A C B SS A E", "plague": "D C D S B SS"},
	"actors": {180: "S A B SS C E", 107: "A S C A S A", 168: "S A A A C B", 45: "D D S D E E", 174: "D B S A B A",
		71: "E A B SS A C", 6: "D B C D E E", 31: "E A B C C SS", 60: "C E C E E E", 175: "S S C B B A"},
}
const TOTALS := {"death": 24, "war": 24, "famine": 25, "plague": 24, 180: 26, 107: 30, 168: 28, 45: 14, 174: 26, 71: 25, 6: 13, 31: 23, 60: 10, 175: 28}
const RESIST := {"death": 5, "war": -5, "famine": 5, "plague": 2, 180: 0, 107: 7, 168: 0, 45: -10, 174: 2, 71: 5, 6: -10, 31: 0, 60: -10, 175: 2}


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
	# T280：全员表 156 人都在、六维字母合法、谷雨已录（不再回中性）
	var rows: Dictionary = XTianqiSixDim.data().get("actors", {})
	var all_ok := rows.size() == 156
	for k in rows:
		for d in XTianqiSixDim.DIMS:
			all_ok = all_ok and XTianqiSixDim.LETTERS.has(rows[k].get(d, ""))
	_check("all_actors_valid", all_ok, rows.size())
	# T531：预算带 super 改 24～30、weak 下移 2 分至 11～20（改带子不改人）
	var bd: Dictionary = XTianqiSixDim.data().get("budgets", {})
	var band := func(k: String, lo: int, hi: int) -> bool:
		var a = bd.get(k, [])
		return a is Array and a.size() == 2 and int(a[0]) == lo and int(a[1]) == hi
	_check("budgets_t531", band.call("super", 24, 30) and band.call("weak", 11, 20) and band.call("strong", 18, 25) and band.call("minion", 10, 18) and band.call("elite", 18, 25) and band.call("knight", 20, 26), bd)
	_check("guyu_recorded", XTianqiSixDim.of_actor(175) != XTianqiSixDim.neutral())
	# T278（Kyo 11-19）：谷雨输出 S、生存至少 S（辅助降档待定，现仍 S）
	var guyu := XTianqiSixDim.of_actor(175)
	_check("guyu_output_s", guyu.output == "S")
	_check("guyu_survive_at_least_s", XTianqiSixDim.score(guyu.survive) >= XTianqiSixDim.score("S"), guyu.survive)
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
