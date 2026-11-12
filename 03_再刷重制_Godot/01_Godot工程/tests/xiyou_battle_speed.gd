extends Node
## 【cc·未经审查】安卓战斗提速（Kyo 11-12：进战斗、选技能、放技能、逃跑都卡）。四项优化各带回退开关，这里核「开和关结果一样」：
## - O-待定-1 说明卡的元素数据读已载入的表（XHelpCard.ELEMENT_DATA_CACHE）：一批技能、装备的说明卡内容开关两态逐行相同；
## - O-待定-2 角色只读窗口缓存（XActor.READ_MEMO）：同一种子的同一场自动战斗，开关两态的整份日志（含每条命中的画面快照）、
##   随机流、收场资源逐项相同；READ_VERIFY 打开时每次命中都重算比对，一次不一致都不许有；窗口用完都关上；
##   窗口里的已知写入（加状态、学技能、改 HP）当场作废；影子克隆不带走缓存；
## - O-待定-3 伤害钩子的技能记录拷贝缓存（XModuleRegistry.ITEM_COPY_CACHE）：拷贝与原来逐项相同、只读，记录改了就重拷；
## - O-待定-4 战斗场景贴图留存（XAppearance.KEEP）：同一路径取到同一份、有上限、关掉回到每次 load()。
## 末尾打印各段耗时（PERF 行，只看不判；云端机器抖动大）。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail).left(600))


func _plain(v, logic: XBattleLogic):
	if v is XBattler:
		return logic.stable_id(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(_plain(k, logic))] = _plain(v[k], logic)
		return out
	if v is Array:
		return v.map(func(x): return _plain(x, logic))
	if v is Object:
		return "<%s>" % v.get_class()
	if v is Callable:
		return "<callable>"
	return v


func _switches(on: bool) -> void:
	XActor.READ_MEMO = on
	XModuleRegistry.ITEM_COPY_CACHE = on
	XHelpCard.ELEMENT_DATA_CACHE = on
	XAppearance.KEEP = on


func _new_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.random_master = XRandomStream.hex64(20261112)
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(60)
		a.refresh_passive()
		a.recover_all()
	return s


## 一场三回合的自动战斗：返回日志摘要与各段耗时（微秒）
func _battle(troop: int) -> Dictionary:
	var s := _new_state()
	var logic := XBattleLogic.new()
	var t0 := Time.get_ticks_usec()
	logic.setup(troop, s)
	var out := {"setup": Time.get_ticks_usec() - t0, "act": 0, "decide": 0, "acts": 0}
	for e in logic.enemies:
		e._rates[0] *= 1000
		e.recover_all()
	t0 = Time.get_ticks_usec()
	var first_views = _plain(logic.views(), logic)
	out.views = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var usable := logic.actors.map(func(a): return logic.usable_skills(a).map(func(sk): return int(sk.id)))
	out.usable = Time.get_ticks_usec() - t0
	logic.auto = true
	var journal := [first_views, usable]
	for round_index in 3:
		logic.start_turn()
		journal.append(_plain(logic.take_turn_start_logs(), logic))
		var count := 0
		while count < 50:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			t0 = Time.get_ticks_usec()
			var cmd := logic.decide(u)
			var t1 := Time.get_ticks_usec()
			var logs := logic.act(u, cmd[0], cmd[1])
			out.decide += t1 - t0
			out.act += Time.get_ticks_usec() - t1
			out.acts += 1
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logs, logic), _plain(logic.move_flags(), logic)])
		journal.append(_plain(logic.end_turn(), logic))
		if logic.is_over():
			break
	journal.append([logic.random.snapshot(), logic.actors.map(func(a): return [a.hp, a.mp, a.tp, a.state_ids.duplicate()]),
		logic.enemies.map(func(e): return [e.hp, e.mp, e.tp, e.state_ids.duplicate()])])
	out.sig = JSON.stringify(journal).sha256_text()
	out.size = JSON.stringify(journal).length()
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_speed"
	XConfig.path_override = XSave.dir().path_join("options.json")
	_help_card()
	_item_copy()
	_kept()
	_window_rules()
	_battles()
	_switches(true)
	XActor.READ_VERIFY = false
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _help_objects() -> Array:
	var objs := []
	for id in [1, 2, 104, 160, 857, 3635, 3641, 10171]:
		objs.append(XDB.rec("Skills", id))
	for id in [1, 56, 732]:
		objs.append(XGear.template("weapon", id))
	for id in [1, 300, 4375]:
		objs.append(XGear.template("armor", id))
	for id in [1, 7, 30]:
		objs.append(XDB.rec("Items", id))
	return objs.filter(func(o): return not o.is_empty())


func _help_card() -> void:
	XState.current = _new_state()
	var objs := _help_objects()
	check("help_objects", objs.size() >= 10, objs.size())
	var took := {}
	var rows := {}
	for on in [false, true]:
		XHelpCard.ELEMENT_DATA_CACHE = on
		var t0 := Time.get_ticks_usec()
		rows[on] = objs.map(func(o): return XHelpCard.content(o))
		took[on] = Time.get_ticks_usec() - t0
	check("help_same_rows", JSON.stringify(rows[false]) == JSON.stringify(rows[true]))
	check("help_has_element_rows", JSON.stringify(rows[true]).contains("伤害属性"))
	# 反例：两条路读的是同一份内容（表被别处改了才会不同）
	XHelpCard.ELEMENT_DATA_CACHE = false
	var fresh := XHelpCard._element_data()
	XHelpCard.ELEMENT_DATA_CACHE = true
	check("help_same_data", fresh == XHelpCard._element_data() and not fresh.is_empty())
	print("PERF 说明卡 %d 张：重读文件 %.1f ms，读已载入的表 %.1f ms" % [objs.size(), took[false] / 1000.0, took[true] / 1000.0])


func _item_copy() -> void:
	var item := XDB.rec("Skills", 104)
	var context := {"item": item, "subject": {"kind": "actor", "id": 1, "states": [3, 5]}, "options": {"critical": true}, "facts": {"orbMultiplier": 1.0}}
	XModuleRegistry.ITEM_COPY_CACHE = false
	var plain = XModuleRegistry._context_copy(context)
	XModuleRegistry.ITEM_COPY_CACHE = true
	XModuleRegistry._item_copies.clear()
	var first = XModuleRegistry._context_copy(context)
	var second = XModuleRegistry._context_copy(context)
	check("copy_same_as_plain", plain == first and plain == second and plain == XModuleRegistry.value_copy(context))
	check("copy_item_shared_frozen", is_same(first.item, second.item) and first.item.is_read_only() and not is_same(first.item, item))
	check("copy_rest_not_shared", not is_same(first.subject, second.subject) and not is_same(first.subject, context.subject))
	# 记录改了：不能拿旧拷贝
	var changed := item.duplicate(true)
	changed.name = "改过的名字"
	var third = XModuleRegistry._context_copy({"item": changed})
	check("copy_refreshes_on_change", str(third.item.name) == "改过的名字" and third == XModuleRegistry.value_copy({"item": changed}))
	# 带不是纯值的东西：照原来返回 null
	check("copy_rejects_objects", XModuleRegistry._context_copy({"item": {"id": 1, "node": self}}) == null and XModuleRegistry.value_copy({"item": {"id": 1, "node": self}}) == null)
	XModuleRegistry._item_copies.clear()


func _kept() -> void:
	var p := XDB.img_path("system", "Shadow2")
	check("kept_path", p != "")
	XAppearance._kept.clear()
	XAppearance._kept_order.clear()
	var a := XAppearance.kept_load(p)
	check("kept_same", a != null and is_same(a, XAppearance.kept_load(p)) and XAppearance._kept.has(p))
	for i in XAppearance.KEEP_MAX + 3:
		XAppearance._kept["fake%d" % i] = null
		XAppearance._kept_order.append("fake%d" % i)
	XAppearance.kept_load(XDB.img_path("system", "Combo_A"))
	check("kept_capped", XAppearance._kept_order.size() == XAppearance.KEEP_MAX and not XAppearance._kept.has(p), XAppearance._kept_order.size())
	XAppearance._kept.clear()
	XAppearance._kept_order.clear()
	XAppearance.KEEP = false
	check("kept_rollback", XAppearance.kept_load(p) != null and XAppearance._kept.is_empty())
	XAppearance.KEEP = true
	check("kept_empty_path", XAppearance.kept_load("") == null)


## 窗口规则：只在窗口里留、窗口一关就丢；窗口里的写入当场作废；克隆不带走缓存
func _window_rules() -> void:
	XActor.READ_MEMO = true
	var s := _new_state()
	var a := s.actor(1)
	var before := a.mhp
	check("no_window_no_store", XActor._read_depth == 0 and XActor._memo_store.is_empty())
	XActor.read_begin()
	var in_window := a.mhp
	check("window_same_value", in_window == before)
	check("window_stores", XActor._memo_store.has(a) and XActor._memo_store[a].has("pa0:0") and XActor._memo_store[a].has("sk0"))
	# 学技能：缓存当场作废，技能表跟上
	var count := a.skills().size()
	var extra := 0
	for id in range(100, 400):
		var rec := XDB.rec("Skills", id)
		if not rec.is_empty() and not a.skill_ids.has(id) and int(rec.get("stypeId", 0)) > 0:
			extra = id
			break
	a.learn_skill(extra)
	check("window_learn_invalidates", a.skills().size() == count + 1 or not a.skill_ids.has(extra), [extra, count, a.skills().size()])
	# 加状态（带能力值特性的 2705 破甲·真气）：能力值跟上
	var def_before := a.def
	a.add_state(XZhenqi.POJIA_STATE)
	XActor.READ_MEMO = false
	var def_fresh := a.def
	XActor.READ_MEMO = true
	check("window_state_invalidates", a.def == def_fresh, [def_before, def_fresh, a.def])
	# 改 HP：带血量条件的被动跟着变，缓存不能留
	var gen := XActor._read_gen
	a.hp = 1.0
	check("window_hp_invalidates", XActor._read_gen != gen)
	# 影子克隆：不带走缓存（缓存不在角色字段里）
	a.mhp
	var clone := XFormulaContext.clone_battler(a)
	check("clone_has_no_memo", clone != null and not XActor._memo_store.has(clone) and not "_memo" in clone)
	XActor.read_end()
	check("window_closed_drops", XActor._read_depth == 0 and XActor._memo_store.is_empty())
	# 没关的窗口：行动开始时关掉并报错（这里只核关掉）
	XActor._read_depth = 2
	XActor._read_depth = 0
	XActor.read_reset()
	check("reset_keeps_closed", XActor._read_depth == 0)
	# 回退：关掉后窗口里也不留
	XActor.READ_MEMO = false
	XActor.read_begin()
	a.mhp
	check("rollback_no_store", XActor._memo_store.is_empty())
	XActor.read_end()
	XActor.READ_MEMO = true


func _battles() -> void:
	for troop in [2, 3]:
		_switches(false)
		var off := _battle(troop)
		_switches(true)
		var on := _battle(troop)
		check("battle_same:%d" % troop, off.sig == on.sig and int(off.acts) >= 4 and int(off.size) > 2000, [off.sig, on.sig, off.acts, off.size])
		check("battle_windows_closed:%d" % troop, XActor._read_depth == 0)
		# 每次命中都重算比对
		XActor.READ_VERIFY = true
		XActor.read_hits = 0
		XActor.read_mismatches.clear()
		var verified := _battle(troop)
		XActor.READ_VERIFY = false
		check("battle_verify:%d" % troop, XActor.read_mismatches.is_empty() and XActor.read_hits > 1000 and verified.sig == off.sig, [XActor.read_hits, XActor.read_mismatches.slice(0, 3)])
		# 单开一项也一样（各开关互不依赖）
		_switches(false)
		XActor.READ_MEMO = true
		check("battle_memo_only:%d" % troop, _battle(troop).sig == off.sig)
		_switches(false)
		XModuleRegistry.ITEM_COPY_CACHE = true
		check("battle_copy_only:%d" % troop, _battle(troop).sig == off.sig)
		# 耗时取三次里最小的
		var best := {}
		for pass_on in [false, true]:
			_switches(pass_on)
			for k in 3:
				var r := _battle(troop)
				for key in ["setup", "act", "decide", "views", "usable"]:
					var slot := "%s:%s" % [key, pass_on]
					best[slot] = mini(int(best.get(slot, 1 << 60)), int(r[key]))
		print("PERF 敌群 %d（%d 次行动）关→开：开战结算 %.1f→%.1f ms，行动结算合计 %.1f→%.1f ms，自动选招合计 %.1f→%.1f ms，全员快照 %.2f→%.2f ms，列可用技能 %.2f→%.2f ms" % [troop, off.acts,
			best["setup:false"] / 1000.0, best["setup:true"] / 1000.0, best["act:false"] / 1000.0, best["act:true"] / 1000.0,
			best["decide:false"] / 1000.0, best["decide:true"] / 1000.0, best["views:false"] / 1000.0, best["views:true"] / 1000.0,
			best["usable:false"] / 1000.0, best["usable:true"] / 1000.0])
