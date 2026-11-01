extends Node
## 【cc·白龙_12·未经审查】米拉的深渊掉落（XMira.abyss_bonus，installNativeMiraRuntime.js 第 392～401 行 makeRewards 包装）：
## 照参照 mira_abyss_probe（tests/fixtures/mira_abyss_oracle.json）——地图 37、58（深渊）与 4（方桌大厅），战斗奖励随机数 0／0.0333／0.034／0.5，
## 比多出来的黑龙进阶石 2903 个数；经 rewards() 走一遍，再调一次 rewards() 不重掷；胜利结算后背包里有这颗。
const FIXTURE := "res://tests/fixtures/mira_abyss_oracle.json"
var checks := 0
var failures: Array = []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(400))


func _ready() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref.cases.size() == 12)
	for c in ref.cases:
		var s := XState.new_game_blank()
		s.map_id = int(c.setup.map)
		var rand := XBattleRandom.create("0000000000000168")
		var fixed := FixedStream.new()
		fixed.domain = "reward"
		fixed.value = float(c.setup.roll)
		rand.reward = fixed
		var logic := XBattleLogic.new()
		logic.setup(3, s, rand)
		var stones := func(): return (logic.rewards().drops as Array).filter(func(d): return int(d.kind) == 1 and int(d.id) == XMira.ABYSS_STONE).size()
		var n: int = stones.call()
		check(str(c.id), n == int(c.observed.stone), [n, c.observed])
		check(str(c.id) + ".once", stones.call() == n)
		check(str(c.id) + ".name", str(XDB.rec("MapInfos", s.map_id).get("name", "")) == str(c.observed.name))
		if n > 0:
			var before := s.item_count(XMira.ABYSS_STONE)
			logic.gain_drops(XMira.abyss_bonus(logic))
			check(str(c.id) + ".gain", s.item_count(XMira.ABYSS_STONE) == before + 1)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_mira_abyss", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
