extends Node
## T146：首领属性加成 1＋20%×N 的 N（上阵超强者人数）天启篇按天启篇档位表，原版档照 super_strong_ids。
## 四人两表对照：云裳 174 原版超强者（<CodexSuperStrong>）、天启篇强者；徐凤年 152、拳一 163、流萤 179 两边都是超强者。
## 助力位不计（battle_members 只给出战栏）；XTianqiSkills.TIERS 关掉回原版名单。

const FOUR := [174, 152, 163, 179]
const XY_SUPER := {174: true, 152: true, 163: true, 179: true}
const TQ_SUPER := {174: false, 152: true, 163: true, 179: true}

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _state(tianqi: bool) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	else:
		s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)
	for id in [1, 8, 9, 10] + FOUR:  # 夹具直接进队（天启篇入队只走开局阵容／大厅招募，这里只量人数）
		s.actor(id)
		if not s.party.has(id):
			s.party.append(id)
	s.difficulty = 3
	return s


func _slots(s: XState, ids: Array) -> void:
	s.init_battle_slots()
	for i in s.battle_slots.size():
		s.battle_slots[i] = int(ids[i]) if i < ids.size() else 0


func _boss() -> int:
	for id in range(1, 3000):
		if XEnemy.boss_id(id):
			return id
	return 0


func _run() -> void:
	var table := {}
	for id in FOUR:
		table[id] = [XItemMarks.is_super_strong(id), XTianqiSkills.is_super(id, true)]
	print("T146_TABLE=", JSON.stringify(table))
	check("table", FOUR.all(func(id): return table[id][0] == XY_SUPER[id] and table[id][1] == TQ_SUPER[id]), table)

	var xy := _state(false)
	var tq := _state(true)
	var xy_m: Array = FOUR.map(func(id): return xy.actor(id))
	var tq_m: Array = FOUR.map(func(id): return tq.actor(id))
	check("xiyou_count", XEnemy.deployed_strong_count(xy_m, xy) == 4, XEnemy.deployed_strong_count(xy_m, xy))
	check("tianqi_count", XEnemy.deployed_strong_count(tq_m, tq) == 3, XEnemy.deployed_strong_count(tq_m, tq))
	for id in FOUR:
		check("xiyou_%d" % id, XEnemy.deployed_strong_count([xy.actor(id)], xy) == int(XY_SUPER[id]))
		check("tianqi_%d" % id, XEnemy.deployed_strong_count([tq.actor(id)], tq) == int(TQ_SUPER[id]))
	XTianqiSkills.TIERS = false
	check("tiers_off_rollback", XEnemy.deployed_strong_count(tq_m, tq) == 4, XEnemy.deployed_strong_count(tq_m, tq))
	XTianqiSkills.TIERS = true

	# 首领 setup 缺省取当前存档出战栏：证道（助力位能放超强者）174 在出战栏、152 在助力位 → 0 人
	var boss := _boss()
	check("boss_found", boss > 0)
	tq.flags.tianqi["difficulty"] = "zhengdao"
	_slots(tq, [174, 1, 8, 9, 152])
	var front: Array = tq.battle_members().map(func(a): return a.actor_id)
	var helper := tq.helper()
	XState.current = tq
	var e := XEnemy.new().setup(boss, tq.difficulty, 100.0)
	check("tianqi_boss_174_front_helper_excluded", e.boss_strong_count == 0 and is_equal_approx(e.boss_attribute_rate(), 1.0) and front.has(174) and not front.has(152),
		[e.boss_strong_count, front, helper.actor_id if helper != null else 0])
	check("tianqi_helper_kept_152", helper != null and helper.actor_id == 152, helper.actor_id if helper != null else 0)
	# 炼狱（上限 2）：174＋152＋163 上场 → 天启篇只数 152、163（旧代码按原版名单会数成 3）
	tq.flags.tianqi["difficulty"] = "lianyu"
	_slots(tq, [174, 152, 163, 1])
	e = XEnemy.new().setup(boss, tq.difficulty, 100.0)
	check("tianqi_boss_three_on_field", e.boss_strong_count == 2 and is_equal_approx(e.boss_attribute_rate(), 1.4), [e.boss_strong_count, tq.battle_members().map(func(a): return a.actor_id)])
	_slots(xy, [174, 152, 163, 179])
	XState.current = xy
	e = XEnemy.new().setup(boss, xy.difficulty, 100.0)
	check("xiyou_boss_four", e.boss_strong_count == 4 and is_equal_approx(e.boss_attribute_rate(), 1.8), [e.boss_strong_count, xy.battle_members().map(func(a): return a.actor_id)])
	XState.current = null

	# T147：自动战斗／智能 AI 的超强者判定（XTusu.super_strong）与号卷分档（XPowerBooks.actor_class）同口径
	XState.current = tq
	check("t147_tusu_tianqi_174_not_super", not XTusu.super_strong(tq.actor(174)) and XTusu.super_strong(tq.actor(152)))
	check("t147_books_tianqi_174_not_super", XPowerBooks.actor_class(tq.actor(174)) != "超强者")
	XTianqiSkills.TIERS = false
	check("t147_tusu_tiers_off_rollback", XTusu.super_strong(tq.actor(174)))
	XTianqiSkills.TIERS = true
	XState.current = xy
	check("t147_tusu_xiyou_174_super", XTusu.super_strong(xy.actor(174)))
	check("t147_books_xiyou_174_super", XPowerBooks.actor_class(xy.actor(174)) == "超强者")
	XState.current = null

	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
