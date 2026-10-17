extends Node
## 进度审查 25%（八戒）抽查：冻结 v0.28 正式引擎实测的
## ①三元伤害公式（Game_Action.evalDamageFormula，目标 HP 10% 与满血两支；角色 1 十级 atk/mat 固定为参照值）
## ②元素吸收（YEP_ElementCore：敌人备注 <Element Absorb>，角色加状态 1371 圣光普照／1392 五雷正法后的 elementRate）。
## ③命中（Game_Action.itemHit／itemEva，YEP_HitAccuracy＋installDamageElementRuntime 链；角色 1 一级对高闪避敌人，敌人普攻角色 1）。
## 参照采集脚本在 04_验证/本地结果/20261017_八戒进度审查25/spot_probe.cjs。
var results := []

class Stub:
	var atk := 0.0
	var mat := 0.0
	var hp := 0.0
	var mhp := 0.0

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/element_ternary_oracle.json"))
	check("frozen_reference", d is Dictionary and d.get("releaseVersion") == "v0.28" and d.ternary.size() == 10 and d.element.size() == 6 and d.get("hit", []).size() == 16)
	for row in d.ternary:
		var sk := XDB.rec("Skills", int(row.skill))
		var a := Stub.new()
		a.atk = float(row.atk)
		a.mat = float(row.mat)
		var b := Stub.new()
		b.hp = float(row.hp)
		b.mhp = float(row.mhp)
		var e := Expression.new()
		var ok: bool = sk.damage.get("formulaGd") is String and e.parse(str(sk.damage.formulaGd), ["a", "b", "v"]) == OK
		var v = e.execute([a, b, []], null, false) if ok else null
		check("ternary_%d_%s" % [int(row.skill), str(row.ratio)], v != null and is_equal_approx(float(v), float(row.base)), [sk.damage.get("formulaGd"), v, row.base])
	for row in d.element:
		var who := str(row.who)
		var b: XBattler
		if who.begins_with("enemy"):
			b = XEnemy.new().setup(int(who.trim_prefix("enemy")), int(d.difficulty), 100.0)
		else:
			var actor := XActor.new().setup(1)
			actor.change_level(10)
			actor.add_state(int(who.get_slice("state", 1)))
			actor.refresh_passive()
			b = actor
		var mine := []
		for el in range(1, 10):
			mine.append(snappedf(b.element_rate(el), 0.000001))
		var same := true
		for i in range(9):
			same = same and is_equal_approx(float(mine[i]), float(row.rates[i]))
		check("element_" + who, same, [mine, row.rates])
	var s := XState.new_game(3, 1, [8])
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var hero := s.actor(1)
	for row in d.hit:
		var foe := XEnemy.new().setup(int(row.enemy), int(d.difficulty), 100.0)
		var sk := XDB.rec("Skills", int(row.skill))
		var u: XBattler = hero if row.user == "actor1" else foe
		var t: XBattler = foe if row.user == "actor1" else hero
		var h := logic.item_hit(u, sk, t)
		var ev := logic.item_eva(u, sk, t)
		check("hit_%s_%d_%d" % [row.user, int(row.enemy), int(row.skill)], is_equal_approx(snappedf(h, 0.000001), float(row.hit)) and is_equal_approx(ev, float(row.eva)), [h, ev, row])
	logic.end_battle()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
