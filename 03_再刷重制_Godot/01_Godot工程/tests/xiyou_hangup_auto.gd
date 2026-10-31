extends Node
## 正式引擎 oracle/hang_up.json 对照 + 子页往返/存读档/实际战后调用/安全恢复回归。
var results := []
var out_dir := ""

class FixedActor extends XActor:
	func param(i: int) -> float:
		return 1000.0 if i < 2 else 100.0
	func sparam(_i: int) -> float:
		return 1.0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func fixture(fixed := false) -> XState:
	var s := XState.new_game(3, 8, [10, 9])
	if fixed:
		for id in s.party:
			s.actors[id] = FixedActor.new().setup(id)
	return s

func page(kind: String, s: XState) -> XHangUpSubPage:
	XState.current = s
	var p := XHangUpSubPage.new().setup(kind, s.actor(8) if kind in ["counts", "order"] else null)
	add_child(p)
	return p

func rules(ref: Dictionary) -> void:
	for row in ref.stars:
		var rec := {"name": "测试装备", "meta": {"quality": str(int(row.quality))}}
		if row.kind in ["weapon", "armor"]:
			rec.kind = row.kind
		check("stars_%s_%d" % [row.kind, int(row.quality)], XQuality.stars(rec) == row.stars and XQuality.label(rec, row.kind) == row.label)
		check("list_name_%s_%d" % [row.kind, int(row.quality)], XQuality.list_name(rec) == str(row.stars) + "测试装备")
	for row in ref.recovery:
		var s := fixture(true)
		for i in s.party.size():
			var a := s.actor(s.party[i])
			a.hp = row.hp[i]
			a.mp = row.mp[i]
			if a.hp == 0:
				a.add_state(1)
		for id in row.items:
			s.items[int(id)] = int(row.items[id])
		s.hang_up.RecoveryHMP = {"HpV": row.hpV, "MpV": row.mpV,
			"GetHpArrItems": row.hpIds.map(func(id): return [true, int(id), "ZL"]),
			"GetMpArrItems": row.mpIds.map(func(id): return [true, int(id)])}
		var logic := XBattleLogic.new()
		logic.state = s
		XHangUpAuto.after_battle_recovery(s, logic)
		check("recovery_hp_" + row.name, s.battle_members().map(func(a): return a.hp) == row.after.hp, [s.battle_members().map(func(a): return a.hp), row.after.hp])
		check("recovery_mp_" + row.name, s.battle_members().map(func(a): return a.mp) == row.after.mp)
		check("recovery_items_" + row.name, row.items.keys().all(func(id): return s.item_count(int(id)) == int(row.after.items.get(id, 0))), s.items)
	# 不消耗且恢复量为 0 的药品，必须终止；阵亡角色不消耗回蓝药（O-021）。
	var s := fixture(true)
	var zero: Dictionary = XDB.rec("Items", 1).duplicate(true)
	zero.consumable = false
	zero.effects = [{"code": 11, "dataId": 0, "value1": 0, "value2": 0}]
	var saved: Dictionary = XDB.rec("Items", 1).duplicate(true)
	XDB.table("Items")[1] = zero
	s.actor(8).hp = 100
	s.items[1] = 1
	s.actor(10).add_state(1)
	s.actor(10).mp = 100
	s.items[2] = 10
	s.hang_up.RecoveryHMP = {"HpV": 50, "MpV": 50, "GetHpArrItems": [[true, 1, "ZL"]], "GetMpArrItems": [[true, 2]]}
	var logic := XBattleLogic.new()
	logic.state = s
	XHangUpAuto.after_battle_recovery(s, logic)
	check("recovery_no_progress_stops", s.actor(8).hp == 100 and s.item_count(1) == 1)
	check("dead_no_mp_potions", s.actor(10).mp == 100 and s.item_count(2) == 10)
	XDB.table("Items")[1] = saved
	# 卖出频率、旧档分组、锁定/已装备/无品质都不能误卖。
	s = fixture()
	s.gear.clear()
	s.gold = 0
	s.hang_up.SellWeapon = {"SellQuality": 2}
	XHangUpAuto.toggle_grade(s, 6)
	for q in [12, 14, 15, 13]:
		s.gear.append({"name": "装备%d" % q, "kind": "weapon", "meta": {"quality": str(q)}, "price": 101})
	s.gear.append({"name": "[锁定]装备", "kind": "armor", "meta": {"quality": "12"}, "price": 100})
	s.gear.append({"name": "无品质", "kind": "armor", "meta": {}, "price": 100})
	var equipped: Array = s.actor(8).equips.duplicate(true)
	XHangUpAuto.better_frequency = 0
	check("sell_waits", XHangUpAuto.after_battle_sell(s) == -1 and s.gear.size() == 6)
	check("sell_groups_and_locked", XHangUpAuto.after_battle_sell(s) == 3 and s.gold == 150 and s.gear.size() == 3 and s.actor(8).equips == equipped)
	s.hang_up.SellWeapon.SellQuality = 0
	check("sell_zero_disables", XHangUpAuto.after_battle_sell(s) == -1)
	XHangUpAuto.on_start(s)
	check("sell_start_resets", XHangUpAuto.better_frequency == 0)
	# 自定义出售金币字段同原版 doSell，不按 price 重算。
	s.hang_up.SellWeapon = {"SellQuality": 1, "quality12": true}
	s.gear = [{"name": "自定卖价", "meta": {"quality": "12"}, "price": 100, "sellPrice": 7}]
	var gold_before := s.gold
	check("sell_explicit_price", XHangUpAuto.after_battle_sell(s) == 1 and s.gold == gold_before + 7)

func _run() -> void:
	XSave.dir_override = "user://test_xiyou_hangup_auto"
	var ref_data = XDB.load_json("oracle/hang_up.json")
	if not ref_data is Dictionary:
		print('TEST_RESULT={"passed":0,"total":1,"error":"run hang_up_probe first"}')
		get_tree().quit(1)
		return
	var ref: Dictionary = ref_data
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("source_identity", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs and ref.sourceIdentity.releaseVersion == manifest.releaseVersion)
	rules(ref)
	_rollback_rules()
	var s := fixture()
	s.items = {1: 9, 2: 8, 137: 7}
	for kind in ["actors_count", "counts", "medication", "sell", "hp", "mp"]:
		var p := page(kind, s)
		await frames()
		var r: Array = ref.windows[kind].rect
		check("rect_" + kind, p.win.position == Vector2(r[0], r[1]) and p.win.size == Vector2(r[2], r[3]))
		check("rows_" + kind, p.rows() == ref.windows[kind].rows, [p.rows(), ref.windows[kind].rows])
		check("opacity_" + kind, p.win.opacity == int(ref.windows[kind].opacity))
		await shot(kind)
		if kind == "counts":
			for value in ref.counts:
				p.ok()
				check("count_cycle_%d" % results.size(), int(p.rows()[0][1]) == int(value))
			p.side(false)
			check("count_left", int(p.rows()[0][1]) == 0)
		elif kind == "medication":
			s.hang_up.RecoveryHMP.HpV = 100
			p.select(2)
			p.ok()
			check("rate_cycles_to_ten", int(s.hang_up.RecoveryHMP.HpV) == 10)
		elif kind == "sell":
			s.hang_up.SellWeapon.quality12 = true
			check("sell_partial_matches_oracle", p.rows() == ref.sell.partial.rows)
			p.select(7)
			p.ok()
			check("sell_partial_toggles_off", p.rows() == ref.sell.off.rows)
			p.ok()
			check("sell_all_toggles_on", p.rows() == ref.sell.on.rows)
			s.hang_up.SellWeapon.SellQuality = 11
			p.select(0)
			p.ok()
			check("sell_frequency_wraps", int(s.hang_up.SellWeapon.SellQuality) == 0)
		elif kind == "hp":
			p.ok()
			check("potion_switch_rebuilds", s.hang_up.RecoveryHMP.GetHpArrItems[0] == [true, 1, "ZL"])
		p.queue_free()
		await frames()
	s.hang_up.ActSkills = {"修1": 2, "修2": 1}
	s.hang_up.ActTemp = {}
	var p := page("order", s)
	await frames()
	check("order_initial", p.rows() == ref.windows.order.rows)
	for row in ref.order:
		p.select(int(row.index))
		p.ok()
		check("order_move_%d" % results.size(), same(p._order.order, row.values), [p._order.order, row.values])
		check("order_final_table_%d" % results.size(), same(s.hang_up.ActSkill, row.table), [s.hang_up.ActSkill, row.table])
	await shot("order")
	var logic := XBattleLogic.new()
	logic.state = s
	for turn in 3:
		var sk := XHangUpAuto.scheduled_skill(s, logic, s.actor(8), turn + 1)
		check("scheduled_round_%d" % turn, not sk.is_empty() and int(sk.id) == int(s.hang_up.ActSkill["修" + XHangUpAuto.three(turn + 1)]))
	check("schedule_missing_uses_auto", XHangUpAuto.scheduled_skill(s, logic, s.actor(8), 30).is_empty())
	var saved: XState = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("order_survives_save", XHangUpAuto.order_list(saved, saved.actor(8), XHangUpAuto.bet_skills(logic, saved.actor(8))).order == p._order.order)
	XState.current = s
	# 次数减少立即清旧表（O-023）。
	XHangUpAuto.change_count(s, s.actor(8), XDB.rec("Skills", 1), false)
	check("count_reduce_no_stale_round", not s.hang_up.ActSkill.has("修005") and s.hang_up.ActSkill.size() == 4)
	s.hang_up.ActSkill["修001"] = 3638
	s.actor(8).mp = 0
	check("schedule_unaffordable_uses_auto", XHangUpAuto.scheduled_skill(s, logic, s.actor(8), 1).is_empty())
	s.actor(8).recover_all()
	# 多于12行的重复技能列表可滚动到末项，返回后排列仍在。
	s.hang_up.ActSkills = {"修1": 20, "修2": 0, "修7": 0, "修3638": 0}
	s.hang_up.ActTemp = {}
	var long := XHangUpAuto.order_list(s, s.actor(8), XHangUpAuto.bet_skills(logic, s.actor(8)))
	check("order_repeats_twenty", long.skills.size() == 20 and long.order.size() == 20)
	p.queue_free()
	await frames()
	# 挂机页→四个子页→返回；选人页再进技能页。
	var parent := XHangUpOptionsScene.new()
	add_child(parent)
	await frames()
	for i in [8, 9, 10, 11]:
		parent.select(i)
		parent.ok()
		await frames()
		check("subpage_open_%d" % i, parent._page != null and not parent.title_win.visible)
		if i in [8, 9]:
			parent._page.ok()
			await frames()
			check("actor_skill_child_%d" % i, parent._page._child != null)
			parent._page._child.cancel()
			await frames()
		parent._page.cancel()
		await frames()
		check("subpage_back_%d" % i, parent._page == null and parent.title_win.visible)
	parent.queue_free()
	await frames()
	# 空药品页安全自动退出。
	s.items.clear()
	p = XHangUpSubPage.new().setup("hp")
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	add_child(p)
	await frames()
	check("empty_potions_returns", closed[0])
	p.queue_free()
	await frames()
	# 实际地图战斗退出接线：挂机逃跑也计场数，先恢复再出售。
	s = fixture(true)
	s.map_id = 5
	s.x = 11
	s.y = 13
	s.items = {1: 5, 2: 5}
	s.actor(8).hp = 100
	s.actor(8).mp = 100
	s.hang_up.RecoveryHMP = {"HpV": 50, "MpV": 50, "GetHpArrItems": [[true, 1, "ZL"]], "GetMpArrItems": [[true, 2]]}
	s.hang_up.SellWeapon = {"SellQuality": 1, "quality1": true}
	var gear := XGear.template("weapon", 2).duplicate(true)
	gear.meta.quality = "1"
	gear.name = "战后出售测试"
	gear.price = 100
	s.gear = [gear]
	XMessageBox.auto = true
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	map.encounter_count = 9999
	XHangUp.ready_start(s, true, Vector2i(s.x, s.y))
	XHangUp.settings(s).CommonEscape = true
	var gold_before := s.gold
	var outcome: int = await map.start_battle(2, true, true)
	check("map_battle_recovery_connected", outcome == 1 and s.actor(8).hp == 1000 and s.actor(8).mp == 1000)
	check("map_battle_sell_connected", s.gear.is_empty() and s.gold == gold_before + 50)
	map.hang_overlay.refresh()
	check("panel_remaining_potions", map.hang_overlay._lines.potions == ["治疗药水(小) 剩余: 3"])
	check("panel_partial_grade", map.hang_overlay._lines.grades == ["普通（部分）"])
	await shot("overlay")
	XHangUp.stop(s)
	map.hang_overlay.refresh()
	check("panel_clears_on_stop", map.hang_overlay._lines.is_empty())
	# O-022 回退（CLEAR_SUMMARY = false）：原版 drawHMPU 只清 (120,0,120,28)，状态变了旧文字还在；停止挂机后上一段摘要仍留着叠画
	XHangUpOverlay.CLEAR_SUMMARY = false
	XHangUp.ready_start(s, true, Vector2i(s.x, s.y))
	map.hang_overlay.refresh()
	var shown: Dictionary = map.hang_overlay._lines.duplicate(true)
	XHangUp.stop(s)
	map.hang_overlay.refresh()
	check("panel_keeps_old_text_original", not shown.is_empty() and map.hang_overlay._lines.is_empty()
		and not map.hang_overlay._summary_history.is_empty() and same(map.hang_overlay._summary_history[-1], shown), map.hang_overlay._summary_history)
	XHangUpOverlay.CLEAR_SUMMARY = true
	map.queue_free()
	await frames()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 回退支（规则层，不开画面）：
## - O-020 SAVE_ORDER = false：排列只在本次运行的全局表里，把最后一项往前挪后存读档、「重开游戏」（清全局表），再打开顺序页会重排成 1～N
## - O-023 CONSISTENT_ORDER = false：技能次数减少时不重建已排的顺序，回合表里最后那条（修00N）留着
## - O-021 SAFE_RECOVERY = false：阵亡角色也照吃回蓝药（对阵亡者无效），开着的回蓝药被吃光、法力不变
func _rollback_rules() -> void:
	var n_skills := {"修1": 2, "修2": 1}
	for save in [true, false]:
		if save:
			XHangUpAuto.SAVE_ORDER = true
		else:
			XHangUpAuto.SAVE_ORDER = false  # 回退值写成字面量，回退开关覆盖.py 才认得
		XHangUpAuto._order_temp = {}
		var st := fixture()
		st.hang_up.ActSkills = n_skills.duplicate()
		st.hang_up.ActTemp = {}
		var lg := XBattleLogic.new()
		lg.state = st
		var ol := XHangUpAuto.order_list(st, st.actor(8), XHangUpAuto.bet_skills(lg, st.actor(8)))
		XHangUpAuto.move_earlier(st, ol, ol.order.size() - 1)
		var moved: Array = ol.order.duplicate()
		var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
		XHangUpAuto._order_temp = {}  # 重开游戏：原版 ActSkilltemporary 是不存档的全局对象
		var lg2 := XBattleLogic.new()
		lg2.state = loaded
		var again := XHangUpAuto.order_list(loaded, loaded.actor(8), XHangUpAuto.bet_skills(lg2, loaded.actor(8)))
		var fresh := range(1, moved.size() + 1)
		if save:
			check("order_saved_after_restart", moved != fresh and again.order == moved, [moved, again.order])
		else:
			check("order_resets_after_restart_original", moved != fresh and again.order == fresh and (st.hang_up.ActTemp as Dictionary).is_empty(), [moved, again.order, st.hang_up.ActTemp])
	XHangUpAuto.SAVE_ORDER = true
	XHangUpAuto._order_temp = {}
	for consistent in [true, false]:
		if consistent:
			XHangUpAuto.CONSISTENT_ORDER = true
		else:
			XHangUpAuto.CONSISTENT_ORDER = false  # 回退值写成字面量，回退开关覆盖.py 才认得
		var st := fixture()
		st.hang_up.ActSkills = n_skills.duplicate()
		st.hang_up.ActTemp = {}
		var lg := XBattleLogic.new()
		lg.state = st
		XHangUpAuto.order_list(st, st.actor(8), XHangUpAuto.bet_skills(lg, st.actor(8)))
		var before: int = st.hang_up.ActSkill.size()
		XHangUpAuto.change_count(st, st.actor(8), XDB.rec("Skills", 1), false)
		if consistent:
			check("count_reduce_rebuilds", st.hang_up.ActSkill.size() == before - 1 and not st.hang_up.ActSkill.has("修" + XHangUpAuto.three(before)), [before, st.hang_up.ActSkill])
		else:
			check("count_reduce_stale_original", st.hang_up.ActSkill.size() == before and st.hang_up.ActSkill.has("修" + XHangUpAuto.three(before)), [before, st.hang_up.ActSkill])
	XHangUpAuto.CONSISTENT_ORDER = true
	XHangUpAuto.SAFE_RECOVERY = false
	var sr := fixture(true)
	sr.actor(10).add_state(1)
	sr.actor(10).mp = 100
	sr.items[2] = 10
	sr.hang_up.RecoveryHMP = {"HpV": 50, "MpV": 50, "GetHpArrItems": [], "GetMpArrItems": [[true, 2]]}
	var lr := XBattleLogic.new()
	lr.state = sr
	XHangUpAuto.after_battle_recovery(sr, lr)
	XHangUpAuto.SAFE_RECOVERY = true
	check("dead_eats_mp_potions_original", sr.actor(10).mp == 100 and sr.item_count(2) == 0, [sr.actor(10).mp, sr.item_count(2)])
