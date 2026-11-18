extends Node
## 期四 live 状态归池或停用（T185 样板 → T187 铺开；damage_ledger.json state_confirm_class.pool，XTianqiLedger.POOL_LIVE，D203）：
## 一、表：pool 表每条 add 是整数、等于原版 ×k 的 k−1（百分数）；cap 只认 secret（带 book）／nine／none；每条有理由、改前改后。
##     重分类：卡已覆盖、装备卡、删除栏位（含护符连带）、洪荒来源挪进 never（开关 CARDS／GEAR_SLOTS／NO_HONGHUANG），713 走套装行，
##     缩小类单列 reduce（都是 ×k<1）；live 只剩程序／脚本类（固定 ×k 的一个不剩）。
## 二、默认关（期四总开关开着就开）：关着时不起作用，伤害、确认阶段和原版现状一样。
## 三、开着：装备来源（838 落炎之语 ×1.3）打敌人 ③ ＋30%、确认阶段那一步不乘；治疗、打自己人照旧 ×1.3；
##     秘籍格来源（2441 我祖我宗 ×1.8）封到每本 ＋8%；同一本书书上已有③增伤时合并封，不各吃 ＋8%（T185 P3-1）；
##     value_steps（2771 超赛1 加 150%）照样归池；停用（2300 天顶剑 ×2）不乘也不进池；九线合计封顶收住 2302 紫炎混沌 ＋900%。
## 四、守卫：开着时那一步带标记不再认；关着认成 state_confirm_pool 回退中不报。reload 清归池表缓存（T185 P3-2）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state() -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_live_sample")
	seed(20261118)
	XTianqiLedger.reload_table()
	_table()
	_runtime()
	XTianqiLedger.POOL_LIVE = false
	XTianqiBase.PHASE4 = false
	XTianqiLedger.CAP_NINE = true
	XTianqiLedger.QUIET = false
	XTianqiLedger.reload_table()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 固定 ×k（mul 的 k；只有加成段的 value_steps 折成连乘）
func _fixed_k(sid: int) -> float:
	for e in XDB.rec("States", sid).get("effects", []):
		if XTianqiLedger._live_effect(e):
			if str(e.op) == "mul":
				return float(e.k)
			var k := 1.0
			for g in e.groups:
				for step in g.steps:
					if not bool(step.get("criticalOnly", false)):
						k *= 1.0 + float(step.k)
			return k
	return 0.0


# ---- 一、表 ----
func _table() -> void:
	var cls: Dictionary = XTianqiLedger.data().get("state_confirm_class", {})
	var pool: Array = cls.get("pool", [])
	var bad := []
	for e in pool:
		var sid := int(e.id)
		var k := _fixed_k(sid)
		var ok: bool = k > 1.0 and str(e.get("reason", "")).length() >= 4 and str(e.get("before", "")) != "" and str(e.get("after", "")) != "" and str(e.get("source", "")) != ""
		match str(e.get("action", "")):
			"pool":
				ok = ok and float(e.add) == floorf(float(e.add)) and int(e.add) == int(roundf((k - 1.0) * 100.0)) and str(e.get("cap", "")) in ["secret", "nine", "none"]
				ok = ok and (str(e.cap) != "secret" or XTianqiLedger.is_secret_skill(int(e.get("book", 0)), int(XDB.rec("Skills", int(e.get("book", 0))).get("stypeId", 0))))
			"stop":
				ok = ok and int(e.get("add", 0)) == 0
			_:
				ok = false
		if not ok:
			bad.append(sid)
	_check("pool_shape", pool.size() >= 35 and bad.is_empty() and pool.any(func(e): return e.action == "stop") and pool.any(func(e): return str(e.get("cap")) == "secret"), [pool.size(), bad])
	# 重分类：never 新增三种开关、各有代表；713 走套装；缩小类都是 ×k<1；live 里不剩固定 ×k 的
	var never := {}
	for e in cls.get("never", []):
		never[int(e.id)] = str(e.switch)
	_check("reclass_never", never.get(1126) == "CARDS" and never.get(1087) == "CARDS" and never.get(1442) == "GEAR_SLOTS" and never.get(1624) == "GEAR_SLOTS"
		and never.get(1712) == "GEAR_SLOTS" and never.get(1261) == "NO_HONGHUANG" and never.get(2709) == "TRUMPET" and never.get(2679) == "NO_HONGHUANG"
		and never.get(2739) == "CARDS" and never.get(2761) == "CARDS" and never.get(1454) == "NO_SOURCE" and never.get(1722) == "NO_SOURCE", never)
	_check("reclass_suit_713", (cls.get("suit_pooled", {}).get("ids", []) as Array).has(713.0) and XTianqiLedger.confirm_source(713) == "state_confirm")
	var bad_reduce := (cls.get("reduce", []) as Array).filter(func(e):
		for x in XDB.rec("States", int(e.id)).get("effects", []):
			if str(x.get("phase", "")) == "confirm" and str(x.get("op", "")) == "mul" and float(x.k) >= 1.0:
				return true
		return false).map(func(e): return e.id)
	_check("reduce_all_shrink", bad_reduce.is_empty() and XTianqiLedger.confirm_source(1034) == "state_confirm_reduce" and XTianqiLedger.check("state_confirm_reduce", "confirm") == "", bad_reduce)
	var fixed_left := []
	for g in cls.get("live", {}):
		for e in cls.live[g]:
			if _fixed_k(int(e.id)) > 0.0:
				fixed_left.append(e.id)
	_check("live_only_dynamic", fixed_left.is_empty() and XTianqiLedger.confirm_source(1062) == "state_confirm" and XTianqiLedger.confirm_source(838) == "state_confirm_pool", fixed_left)
	_check("default_off", XTianqiLedger.POOL_LIVE == false and XTianqiLedger.switch_on("POOL_LIVE") == false)
	XTianqiBase.PHASE4 = true
	_check("phase4_turns_on", XTianqiLedger.switch_on("POOL_LIVE"))
	XTianqiBase.PHASE4 = false
	# T185 P3-2／T201：reload_table 清归池表缓存且不动开关（原名 reload() 在类外会调到 Script.reload()，开关回默认）
	XTianqiLedger.live_table()
	var probe_on := XTianqiLedger.POOL_QIYIN
	XTianqiLedger.POOL_QIYIN = not probe_on
	XTianqiLedger.reload_table()
	_check("reload_clears_cache", XTianqiLedger._live_table.is_empty() and XTianqiLedger.POOL_QIYIN != probe_on)
	XTianqiLedger.POOL_QIYIN = probe_on


func _fresh(a: XActor, ids: Array) -> void:
	for sid in [838, 2441, 2300, 2302, 2771]:
		a.remove_state(sid)
	for sid in ids:
		a.add_state(int(sid))
	a.effect_snapshot_valid = false
	a.effect_lists = {}


func _terminal(a, e) -> float:
	return float(XDamage.calculate(XDB.rec("Skills", 1), a, e, {"critical": false, "variance": false}).breakdown.row.terminal)


## 确认阶段（对敌人、伤害 100）跑完的值
func _confirm(a, target, dtype := 1, value := 100.0) -> float:
	var item: Dictionary = XDB.rec("Skills", 1).merged({"damage": {"type": dtype}}, true)
	return XStateEffects.run("confirm", a, {"attacker": a, "defender": target, "item": item, "value": value, "execute": false})


# ---- 二～四、运行期 ----
func _runtime() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	var mate := s.actor(int(s.battle_slots[1]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	XTianqiLedger.CAP_NINE = false  # 先看归池本身（③ ＋30%），封顶单测
	# 二、默认关
	_fresh(a, [838])
	XTianqiLedger.POOL_LIVE = false
	var t_off := _terminal(a, e)
	var c_off := _confirm(a, e)
	_check("off_untouched", XTianqiLedger.live_pool_effects(a).is_empty() and absf(c_off - 130.0) <= 1.0 and is_equal_approx(float(XTianqiLedger.live_confirm_add(a, e, 1).add), 0.0), [c_off])
	# 三、开着：装备来源
	XTianqiLedger.POOL_LIVE = true
	var t_on := _terminal(a, e)
	var c_on := _confirm(a, e)
	var heal := _confirm(a, e, 3, -100.0)
	var self_hit := _confirm(a, mate)
	_check("gear_pooled", is_equal_approx(t_on, t_off + 0.3) and absf(c_on - 100.0) <= 0.01 and heal <= -129.0 and self_hit >= 129.0, [t_off, t_on, c_on, heal, self_hit])
	XTianqiLedger.POOL_LIVE = false
	_check("gear_rollback", is_equal_approx(_terminal(a, e), t_off) and absf(_confirm(a, e) - 130.0) <= 1.0)
	XTianqiLedger.POOL_LIVE = true
	# 秘籍格来源：＋80% 封到每本 ＋8%
	_fresh(a, [2441])
	var per := XTianqiBase.secret_slot(XTianqiLedger.nine_cap("secret_slot"))
	var sec: Dictionary = XTianqiLedger.live_confirm_add(a, e, 1)
	_check("secret_capped", is_equal_approx(float(sec.add), per) and is_equal_approx(float(sec.nine), 0.0) and absf(_confirm(a, e) - 100.0) <= 0.01, [sec, per])
	# T185 P3-1：同一本书书上已有③ ＋5%，确认阶段又归池 ＋8%：合并封到 ＋8%，不各吃
	if XTianqiLedger.secret_slots(a) >= 1:
		var books := {"globalHarmRi": {"#7135": 0.05}, "critHarmRi": {}, "skillTypeDvup": {}, "SkETypeHarmRi": {}, "skillPass": {}, "passiveELUP": {}, "elementAmplify": {}}
		var by := {"globalHarmRi": {"secret": 0.05}, "critHarmRi": {}, "skillTypeDvup": {}, "SkETypeHarmRi": {}, "skillPass": {}, "passiveELUP": {}, "elementAmplify": {}, "books": books}
		var frame := {"normalAdd": 0.0, "finalAdd": 0.05 + float(sec.add), "criticalAdd": 0.0, "elementAdd": {}}
		XTianqiLedger.CAP_NINE = true
		XTianqiLedger.apply_nine_cap(XDB.rec("Skills", 1), a, frame, {"bySource": by}, {"live_books": sec.books})
		XTianqiLedger.CAP_NINE = false
		_check("secret_merged_cap", sec.books.has("#7135") and is_equal_approx(float(frame.finalAdd), per) and is_equal_approx(float(by.globalHarmRi.secret), 0.05) and is_equal_approx(float(books.globalHarmRi["#7135"]), 0.05), [frame, sec])
	else:
		_check("secret_merged_cap", false, "secret_slots 0")
	# value_steps：2771 超赛1 ＋150%（角色桶不封），确认阶段那一步不加
	_fresh(a, [2771])
	var vs: Dictionary = XTianqiLedger.live_confirm_add(a, e, 1)
	_check("value_steps_pooled", is_equal_approx(float(vs.add), 1.5) and absf(_confirm(a, e) - 100.0) <= 0.01 and _confirm(a, mate) >= 249.0, [vs, _confirm(a, e)])
	# 停用：不乘、不进池
	_fresh(a, [2300])
	var stop: Dictionary = XTianqiLedger.live_confirm_add(a, e, 1)
	_check("stop_no_pool", is_equal_approx(float(stop.add), 0.0) and absf(_confirm(a, e) - 100.0) <= 0.01 and _confirm(a, mate) >= 199.0, [stop])
	# 九线合计封顶收住 ＋900%
	_fresh(a, [2302])
	var raw := _terminal(a, e)
	XTianqiLedger.CAP_NINE = true
	var capped := _terminal(a, e)
	_check("nine_cap_bites", raw >= 9.9 and capped <= raw - 8.0, [raw, capped])
	# 四、守卫
	_fresh(a, [838, 2300])
	XTianqiLedger.QUIET = true
	var ctx := {"defender": e, "item": XDB.rec("Skills", 1)}
	var rows: Array = XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false))
	var got_on := XTianqiLedger.audit_confirm(a, rows, ctx).filter(func(r): return int(r.state) in [838, 2300])
	XTianqiLedger.POOL_LIVE = false
	var rows_off: Array = XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false))
	var got_off := XTianqiLedger.audit_confirm(a, rows_off, ctx).filter(func(r): return int(r.state) in [838, 2300])
	_check("guard_marks", got_on.is_empty() and got_off.size() == 2 and got_off.all(func(r): return r.ok and r.source == "state_confirm_pool"), [got_on, got_off])
	_fresh(a, [])
