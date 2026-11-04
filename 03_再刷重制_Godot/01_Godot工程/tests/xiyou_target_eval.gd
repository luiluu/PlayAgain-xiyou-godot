extends Node
## YEP_TargetCore <Custom Target Eval>（三种写法）与 YEP_X_SkillCostItems <Item n Cost: m>、冻结追击 CE1321。
## 对照 tests/fixtures/target_eval_oracle.json（mv_oracle/target_eval_probe.cjs，真 Game_Action.makeTargets，Math.random 按磁带给值）：
##  gt2（965，活着多于 2 个取 2）、gt3（1303，多于 3 个取 2）、回春术 1172，比目标（角色号／负的敌人序号）与随机取数次数（rule.draws）。
## 消耗物品：解析、付得起、扣物品、敌人不看、智能 AI 不选付不起的、菜单（Scene_Skill）酿酒术 2610。
## 冻结追击：6171 预约 CE1321，会 6175 才追放 6172（原版语义按代码读出，探针没量）。
const FIXTURE := "res://tests/fixtures/target_eval_oracle.json"
const PARTY := [1, 8, 9, 10, 11, 12, 13, 14]
var results := []
var ref: Dictionary


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _case(id: String) -> Dictionary:
	for c in ref.cases:
		if c.id == id:
			return c
	return {}


func _tape(t: int) -> XRandomStream:
	var vals := []
	for v in ref.tapes[t]:
		vals.append({"kind": "float", "value": float(v)})
	return XRandomStream.scripted(vals)


## 敌人第一只当行动者，我方 n 个角色（直接赋值，免得受队伍人数上限）
func _logic(n: int) -> XBattleLogic:
	var s := XState.new_game(3, 1, [])
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(3, s)
	var party: Array = []
	for id in PARTY.slice(0, n):
		var a := XActor.new().setup(int(id))
		a.recover_all()
		party.append(a)
	l.actors = party
	return l


func _tag(l: XBattleLogic, b) -> Variant:
	if b == null:
		return null
	if b is XActor:
		return b.actor_id
	return -1 - l.enemies.find(b)


func _roll(l: XBattleLogic, skill_id: int, t: int) -> Dictionary:
	l.random = XBattleRandom.create("0000000000000000")
	l.random.rule = _tape(t)
	var got := l.targets_for(l.enemies[0], XDB.rec("Skills", skill_id))
	return {"targets": got.map(func(b): return _tag(l, b)), "calls": l.random.rule.draws}


static func norm(v):
	if v is int or v is float:
		return float(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	return v


func _rows(id: String, l: XBattleLogic, skill_id: int, count: int) -> void:
	var c := _case(id)
	var rows: Array = c.observed.rows
	check(id + ".present", not c.is_empty() and c.errors.is_empty())
	for r in rows.slice(0, count):
		var got := _roll(l, skill_id, int(r.t))
		var want_targets: Array = (r.targets as Array).filter(func(x): return x != null)
		check("%s.t%d" % [id, int(r.t)], norm(got.targets) == norm(want_targets) and int(got.calls) == int(r.calls), {"got": got, "want": r})


func _run() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_present", ref is Dictionary and ref.has("cases")):
		return _finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	# 一、两种随机写法（人数 1～8、每条磁带）
	for pair in [["gt2", 965], ["gt3", 1303]]:
		for n in range(1, 9):
			_rows("%s.n%d" % [pair[0], n], _logic(n), pair[1], 99)
	# 写法解析：全库 46 个技能 36＋9＋1
	var more2 := 0
	var more3 := 0
	var wounded := 0
	for rec in XDB.table("Skills"):
		if rec is Dictionary:
			var te := XBattleLogic.target_eval(rec)
			if te.has("more"):
				if int(te.more) == 2:
					more2 += 1
				elif int(te.more) == 3:
					more3 += 1
			elif te.has("wounded"):
				wounded += 1
	check("parse_counts", more2 == 36 and more3 == 9 and wounded == 1, [more2, more3, wounded])
	# 二、倒下的不算；强制行动同样走 eval
	var l := _logic(4)
	l.actors[1].hp = 0.0
	_rows("gt2.dead_excluded", l, 965, 99)
	_rows("gt2.forcing", _logic(4), 1083, 99)
	# 三、回春术：友方是敌人，要 4 个
	for c in ref.cases:
		if not str(c.id).begins_with("heal.") or str(c.id) == "heal.none.run":
			continue
		var hl := _logic(1)
		while hl.enemies.size() < 4:
			var ne: XEnemy = XEnemy.new().setup(int(hl.enemies[0].enemy_id), 3, 100.0, hl._rule(), 0)
			hl.enemies.append(ne)
		hl.enemies = hl.enemies.slice(0, 4)
		for e in hl.enemies:
			e.recover_all()
		var hurt: Array = c.setup.hurt
		for k in hurt.size():
			var e: XEnemy = hl.enemies[int(hurt[k])]
			e.hp = e.mhp - float((k + 1) * 10)
		for r in c.observed.rows:
			var got := _roll(hl, 1172, int(r.t))
			var want_t: Array = (r.targets as Array).filter(func(x): return x != null)
			check("%s.t%d" % [c.id, int(r.t)], norm(got.targets) == norm(want_t) and int(got.calls) == int(r.calls), {"got": got, "want": r})
	var none := _case("heal.none.run")
	check("heal_none_run_ref", none.observed.threw == null and int(none.observed.mpPaid) == 200)
	# 混乱类（restriction 1～3）不在本期：参照里留着，只确认夹具还在
	check("confused_ref_kept", not _case("gt2.confused").is_empty())
	_cost()
	await _menu()
	_freeze()
	_finish()


# ---- 消耗物品 ----
func _cost() -> void:
	var parsed: Array = _case("cost.parsed").observed.rows
	for r in parsed:
		var want := (r.item as Array).map(func(x): return [int(x[0]), int(x[1])])
		var got := XBattleLogic.skill_item_costs(XDB.rec("Skills", int(r.id)))
		check("cost.parsed.%d" % int(r.id), norm(got) == norm(want), [got, want])
	check("cost.other_notes_none", (_case("cost.other_notes").observed.out as Array).is_empty())
	for id in [2610, 3761, 5765]:
		var c := _case("cost.pay.%d" % id)
		var item := int(c.setup.item)
		var need := int(c.setup.need)
		var l := _logic(1)
		var s := l.state
		var a := XActor.new().setup(1)
		a.learn_skill(id)
		a.recover_all()
		a.mp = a.mmp
		a.tp = 100.0
		l.actors = [a]
		var sk := XDB.rec("Skills", id)
		s.items[item] = need - 1
		check("cost.pay.%d.less" % id, l.can_pay_items(a, sk) == bool(c.observed.less) and not l.can_use(a, sk))
		s.items[item] = need
		check("cost.pay.%d.eq" % id, l.can_pay_items(a, sk) == bool(c.observed.eq))
		s.items[item] = need + 2
		l.pay_skill_cost(a, sk)
		check("cost.pay.%d.left" % id, s.item_count(item) == int(c.observed.left), s.item_count(item))
		# 敌人不看不扣
		var e: XBattler = l.enemies[0]
		s.items[item] = 0
		check("cost.pay.%d.foe" % id, l.can_pay_items(e, sk) == bool(c.observed.foe))
		l.pay_items(e, sk)
		check("cost.pay.%d.foe_nopay" % id, s.item_count(item) == 0)
	# 物品技能（itypeId）不收物品费
	var l2 := _logic(1)
	check("cost.items_skip", l2.can_pay_items(l2.actors[0], XDB.rec("Items", 1)))
	# 智能 AI：付不起的不选
	var l3 := _logic(1)
	var a3: XActor = l3.actors[0]
	a3.learn_skill(2610)
	a3.mp = a3.mmp
	l3.state.items[514] = 0
	var pick := XSmartAI.choose(l3, a3)
	var ids := (pick.get("candidates", []) as Array).map(func(c): return int(c.get("id", 0)))
	check("cost.ai_skips_unaffordable", pick.get("skill", {}).get("id", 0) != 2610 and not ids.has(2610), [pick.get("skill", {}).get("id", 0), ids])
	# 费用显示行（Window_SkillList.drawSkillItemCost：×数量、字号 20、物品图标）
	var rows := XBattleLogic.item_cost_rows(XDB.rec("Skills", 2610))
	check("cost.rows", rows.size() == 1 and rows[0].text == "×10" and int(rows[0].size) == 20 and int(rows[0].icon) == int(XDB.rec("Items", 514).get("iconIndex", 0)), rows)


# ---- 菜单（Scene_Skill）：酿酒术 2610 ----
func _menu() -> void:
	var s := XState.new_game(3, 1, [])
	XState.current = s
	var a := s.actor(1)
	a.learn_skill(2610)
	a.recover_all()
	a.mp = a.mmp
	var page := XSkillScene.new()
	page.actor_index = 0
	add_child(page)
	await get_tree().process_frame
	var sk := XDB.rec("Skills", 2610)
	s.items[514] = 9
	check("menu.unaffordable", not page.usable(sk))
	s.items[514] = 12
	check("menu.affordable", page.usable(sk))
	check("menu.costs_row", page._costs(a, sk).any(func(r): return str(r.text) == "×10"))
	page.type_index = page.types().find(int(sk.stypeId))
	page.index = page.entries().find_custom(func(k): return int(k.id) == 2610)
	page.mode = "list"
	check("menu.selected", page.current().get("id", 0) == 2610, page.current().get("id", 0))
	page.ok()
	check("menu.paid", s.item_count(514) == 2, s.item_count(514))
	page.queue_free()


# ---- 冻结追击 CE1321 ----
func _freeze() -> void:
	for learn in [true, false]:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var l := XBattleLogic.new()
		l.elite_roll = 100.0
		l.setup(2, s)
		var a := s.actor(1)
		a.learn_skill(6171)
		if learn:
			a.learn_skill(6175)
		else:
			a.forget_skill(6175)
		a.recover_all()
		a.mp = a.mmp
		a.refresh_passive()
		l.act(a, XDB.rec("Skills", 6171), l.enemies[0])
		var tag := "freeze.learn" if learn else "freeze.nolearn"
		check(tag + ".reserved", XBattleCommonEvent.reserved(l) == 1321, XBattleCommonEvent.reserved(l))
		var ev := l.run_events()
		var forced := ev.filter(func(x): return x.type == "action").map(func(x): return [x.user, int(x.skill.id)])
		var has_6172 := forced.any(func(x): return x[0] == a and x[1] == 6172)
		check(tag + ".forced", has_6172 == learn, forced.map(func(x): return x[1]))
		check(tag + ".no_pending", l.pending_force.is_empty())
	# 敌人放不追（公共事件照预约，但 6172 只给角色）
	var s2 := XState.new_game(3, 1, [])
	XState.current = s2
	var l2 := XBattleLogic.new()
	l2.elite_roll = 100.0
	l2.setup(2, s2)
	var e: XBattler = l2.enemies[0]
	e.mp = 9999.0
	l2.act(e, XDB.rec("Skills", 6171), s2.actor(1))
	var ev2 := l2.run_events()
	check("freeze.enemy_no_followup", not ev2.any(func(x): return x.type == "action" and int(x.skill.id) == 6172))
	check("freeze.enemy_no_pending", l2.pending_force.is_empty())


func _finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
