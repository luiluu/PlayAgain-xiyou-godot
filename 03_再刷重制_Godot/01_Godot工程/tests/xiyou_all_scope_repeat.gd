extends Node
## 【cc·T178】全体技能多敌时同一敌人重复挨打（XActionSequence.FIX_ALL_SCOPE_REPEAT，O-待定）。
## 原版：范围「敌方全体」的技能 target 段对每个目标各跑一遍，段里的「action effect: enemies」又打全体，
## 三个敌人时 91 豪龙火之术（whole 1 段＋target 4 段）每人挨 1＋4×3＝13 段、一个敌人 5 段（mv_oracle 实跑，T178 交付单）。
## 修好后每人段数与敌人数无关。本专项：
## - 7472 单敌／三敌、开关开／关的每人段数（关＝原版 5／13，开＝5／5）；
## - 5850 乾坤倒置：IF 栈在目标之间不清，没学 5846 时第二个目标起整段不跑，原版三敌每人 2 段，修后也 2 段（不能变成 2／0／0）；学了 5846 原版 7／21，修后 7；
## - 全表：原版数据与天启篇卡（XTianqiSkills.build）里所有「全体范围＋target 段整组写法」的技能，开关开时一敌、三敌每人段数相同、且不多于开关关时；
##   清单打印在 LIST= 行（scaling＝原版三敌比一敌多挨，即受本缺陷影响）。
## 场景同 xiyou_action_sequence：普通难度、出战 1/8/9/10、10 级、敌群 222（三只 20 万血），单敌＝只留第一只。
var results := []
var _learn := []


func _ready() -> void:
	XCanglong.original_data()
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func setup(n_enemy: int) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9, 10])
	var logic := XBattleLogic.new()
	logic.setup(222, s)
	logic.turn = 1
	if n_enemy < logic.enemies.size():
		logic.enemies.resize(n_enemy)
	for a in logic.actors:
		a.change_level(10)
		a.refresh_passive()
		a.recover_all()
	return logic


## 一次施放：返回每个敌人挨的段数（按敌人序号）
func cast(rec: Dictionary, n_enemy: int) -> Array:
	var logic := setup(n_enemy)
	var u: XBattler = logic.state.actor(1)
	for k in _learn:
		(u as XActor).learn_skill(k)
	var seq := XActionSequence.create(logic, u, rec, logic.targets_for(u, rec, logic.enemies[0]))
	var counts := []
	counts.resize(logic.enemies.size())
	counts.fill(0)
	for l in seq.run():
		if l.get("type") == "hit" and not l.get("counter", false) and not l.get("reflected", false):
			var i := logic.enemies.find(l.target)
			if i >= 0:
				counts[i] += 1
	return counts


func both(rec: Dictionary, fix: bool) -> Array:
	XActionSequence.FIX_ALL_SCOPE_REPEAT = fix
	var r := [cast(rec, 1), cast(rec, 3)]
	XActionSequence.FIX_ALL_SCOPE_REPEAT = true
	return r


## 全体范围、target 段里有整组写法（enemies／actors 等，不是 target(s)）的 ACTION EFFECT
static func affected(rec: Dictionary) -> bool:
	if not XActionSequence.ALL_SCOPES.has(int(rec.get("scope", 0))) or not (rec.get("yepSeq") is Dictionary):
		return false
	for c in rec.yepSeq.get("target", []):
		if c is Array and c.size() > 1 and str(c[0]).to_upper() == "ACTION EFFECT" and not (c[1] as Array).is_empty():
			var a := str(c[1][0]).to_upper()
			if a != "" and a != "TARGET" and a != "TARGETS":
				return true
	return false


func _run() -> void:
	check("default_on", XActionSequence.FIX_ALL_SCOPE_REPEAT)
	# ---- 7472 豪龙火之术（原版数据）----
	var r7472 := XDB.rec("Skills", 7472)
	var off := both(r7472, false)
	var on := both(r7472, true)
	check("7472.off_1enemy_5", off[0] == [5], off)
	check("7472.off_3enemy_13_each", off[1] == [13, 13, 13], off)
	check("7472.on_1enemy_5", on[0] == [5], on)
	check("7472.on_3enemy_5_each", on[1] == [5, 5, 5], on)
	# ---- 5850 乾坤倒置（IF 栈跨目标）----
	var r5850 := XDB.rec("Skills", 5850)
	off = both(r5850, false)
	on = both(r5850, true)
	check("5850.off_2_each", off == [[2], [2, 2, 2]], off)
	check("5850.on_same_as_off", on == off, on)
	_learn = [5846]
	off = both(r5850, false)
	on = both(r5850, true)
	_learn = []
	check("5850.learned.off_7_21", off == [[7], [21, 21, 21]], off)
	check("5850.learned.on_7_each", on == [[7], [7, 7, 7]], on)
	# ---- 全表 ----
	var list := []
	var table: Array = XDB.table("Skills")
	var extra := []  # 天启篇表外新号（new_skills，按底号复制，同 XTianqiSkills.new_rec；不经 cards_on）
	for k in XTianqiSkills.data().get("new_skills", {}):
		var from := int(XTianqiSkills.data().new_skills[k].get("from", 0))
		if from > 0 and from < table.size() and table[from] is Dictionary:
			var c: Dictionary = table[from].duplicate(true)
			c.id = int(k)
			extra.append(c)
	for mode in ["base", "tianqi"]:
		for rec in (table if mode == "base" else table + extra):
			if not (rec is Dictionary):
				continue
			var id := int(rec.get("id", 0))
			var r: Dictionary = rec
			if mode == "tianqi":
				if not XTianqiSkills.has(id):
					continue
				r = XTianqiSkills.build(id, rec)
			if not affected(r):
				continue
			var o := both(r, false)
			var n := both(r, true)
			var row := {"mode": mode, "id": id, "name": str(r.get("name", "")), "scope": int(r.scope), "off": o, "on": n,
				"scaling": o[1].any(func(x): return x > o[0][0])}
			list.append(row)
			var per1: int = n[0][0]
			check("%s.%d.on_same" % [mode, id], n[1].all(func(x): return x == per1), row)
			check("%s.%d.on_not_more" % [mode, id], n[0] == o[0] and range(3).all(func(i): return n[1][i] <= o[1][i]), row)
	for row in list:
		print("LIST=", JSON.stringify(row))
	check("list_nonempty", list.filter(func(x): return x.scaling).size() >= 10, list.size())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
