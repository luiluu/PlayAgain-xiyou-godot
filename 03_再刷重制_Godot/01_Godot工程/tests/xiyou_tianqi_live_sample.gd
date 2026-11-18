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
## 五、T200：live 清零——T187 留下的 32 个逐个给去向（never 12、归池 1、program 类 19；R1：1703／1707 有敌群 831 来源，进 program 类 enemy）；program 类各条有 kind 和理由、没有一个是固定 ×k；
##     38 缝合（程序写法的固定 ×1.05）按 as 换写归池：打敌人 ③ ＋5% 算九线、确认阶段不乘；打自己人和关着时一样；守卫不报；关着照原版。
## 六、T205：program 类里的增伤 8 个挪进 pool（开关 POOL_LIVE_PROBE）：probe 5 个出手时空跑得 k（2731 按目标状态数、1421 按变量、
##     1834 只剩自己活着、2583 k<1 那一下照乘缩小）；crit 2 个非暴击段进③、暴击段进④（1522 ③＋50% ④＋50%，2556 ④＋150%）；
##     1666 as 换写 ③＋100%；打敌人确认阶段不放大、打自己人照旧；关开关回到原样、守卫当回退中不报。

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
	var row: Dictionary = XTianqiLedger.live_table().get(sid, {})
	for e in row.get("as", XDB.rec("States", sid).get("effects", [])):
		if XTianqiLedger._live_effect(e, row) and str(e.op) != "value_program" and str(e.op) != "value_query":
			if str(e.op) == "mul":
				return float(e.k)
			var k := 1.0
			for g in e.groups:
				for step in g.steps:
					if not bool(step.get("criticalOnly", false)):
						k *= 1.0 + float(step.k)
			return k
	return 0.0


## 暴击专属段加的百分数（value_steps criticalOnly 那一段的 k）
func _crit_pct(sid: int) -> int:
	var pct := 0
	for e in XDB.rec("States", sid).get("effects", []):
		if str(e.get("phase", "")) == "confirm" and str(e.get("op", "")) == "value_steps":
			for g in e.groups:
				for step in g.steps:
					if bool(step.get("criticalOnly", false)):
						pct += int(roundf(float(step.k) * 100.0))
	return pct


# ---- 一、表 ----
func _table() -> void:
	var cls: Dictionary = XTianqiLedger.data().get("state_confirm_class", {})
	var pool: Array = cls.get("pool", [])
	var bad := []
	for e in pool:
		var sid := int(e.id)
		var k := _fixed_k(sid)
		var probe := bool(e.get("probe", false))
		var ok: bool = (k > 1.0 or probe or e.has("crit")) and str(e.get("reason", "")).length() >= 4 and str(e.get("before", "")) != "" and str(e.get("after", "")) != "" and str(e.get("source", "")) != ""
		match str(e.get("action", "")):
			"pool":
				if probe:  # T205：k 出手时算，表里不写 add
					ok = ok and not e.has("add") and str(e.get("switch", "")) == "POOL_LIVE_PROBE" and str(e.get("cap", "")) == "none"
				else:
					ok = ok and float(e.add) == floorf(float(e.add)) and int(e.add) == int(roundf((k - 1.0) * 100.0)) and str(e.get("cap", "")) in ["secret", "nine", "none"]
				if e.has("crit"):  # T205：暴击专属段的 k（百分数整数）
					ok = ok and float(e.crit) == floorf(float(e.crit)) and int(e.crit) == _crit_pct(int(e.id))
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
	_check("live_only_dynamic", fixed_left.is_empty() and XTianqiLedger.confirm_source(1062) == "state_confirm_program" and XTianqiLedger.confirm_source(838) == "state_confirm_pool", fixed_left)
	# 五、T200：live 清零；program 类各有 kind、理由，没有固定 ×k；新挪 never 的有代表
	var prog: Array = cls.get("program", [])
	var bad_prog := []
	for e in prog:
		if not str(e.get("kind", "")) in ["inert", "extra", "dynamic", "crit", "enemy"] or str(e.get("reason", "")).length() < 10 or _fixed_k(int(e.id)) > 0.0 \
				or XTianqiLedger.confirm_source(int(e.id)) != "state_confirm_program":
			bad_prog.append(e.id)
	var live_n := 0
	for g in cls.get("live", {}):
		live_n += (cls.live[g] as Array).size()
	_check("t200_live_cleared", live_n == 0 and prog.size() == 11 and bad_prog.is_empty() and XTianqiLedger.row("state_confirm_program").get("status") == "allowed"
		and XTianqiLedger.check("state_confirm_program", "confirm") == "", [live_n, prog.size(), bad_prog])
	_check("t200_never", never.get(543) == "NO_SOURCE" and never.get(1424) == "NO_SOURCE" and never.get(2522) == "NO_SOURCE" and never.get(1259) == "NO_HONGHUANG"
		and never.get(2803) == "CARDS" and XTianqiLedger.confirm_source(1259) == "state_confirm_never"
		and not never.has(1703) and not never.has(1707) and prog.filter(func(e): return int(e.id) in [1703, 1707] and str(e.kind) == "enemy").size() == 2, never)
	# 六、T205：8 个增伤都在 pool、都挂 POOL_LIVE_PROBE、program 里不剩
	var t205 := [1421, 1422, 2583, 2731, 1834, 1666, 1522, 2556]
	var miss := t205.filter(func(id): return str(XTianqiLedger.live_table().get(id, {}).get("switch", "")) != "POOL_LIVE_PROBE" \
		or XTianqiLedger.confirm_source(id) != "state_confirm_pool" or prog.any(func(e): return int(e.id) == id))
	_check("t205_table", miss.is_empty() and XTianqiLedger.POOL_LIVE_PROBE and XTianqiLedger.switch_on("POOL_LIVE_PROBE"), miss)
	var r38: Dictionary = XTianqiLedger.live_table().get(38, {})
	_check("t200_38_as", is_equal_approx(_fixed_k(38), 1.05) and int(r38.get("add", 0)) == 5 and str(r38.get("cap", "")) == "nine" and (r38.get("as", []) as Array).size() == 2, r38)
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
	for sid in [838, 2441, 2300, 2302, 2771, 38, 1421, 1422, 2583, 2731, 1834, 1666, 1522, 2556]:
		a.remove_state(sid)
	for sid in ids:
		a.add_state(int(sid))
	a.effect_snapshot_valid = false
	a.effect_lists = {}


func _terminal(a, e) -> float:
	return float(XDamage.calculate(XDB.rec("Skills", 1), a, e, {"critical": false, "variance": false}).breakdown.row.terminal)


## 确认阶段（对敌人、伤害 100）跑完的值
func _confirm(a, target, dtype := 1, value := 100.0, extra := {}) -> float:
	var item: Dictionary = XDB.rec("Skills", 1).merged({"damage": {"type": dtype}}, true)
	var ctx := {"attacker": a, "defender": target, "item": item, "value": value, "execute": false}
	ctx.merge(extra, true)
	return XStateEffects.run("confirm", a, ctx)


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
	# 五、T200：38 缝合（程序写法的固定 ×1.05）按 as 换写归池
	XTianqiLedger.POOL_LIVE = false
	_fresh(a, [38])
	var s_off := _confirm(a, e)
	var s_mate_off := _confirm(a, mate)  # 打自己人另有难度合成行 ×6，只比开关前后一样
	XTianqiLedger.POOL_LIVE = true
	var sew: Dictionary = XTianqiLedger.live_confirm_add(a, e, 1)
	var s_on := _confirm(a, e)
	var s_mate := _confirm(a, mate)
	var rows38: Array = XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false))
	var g38 := XTianqiLedger.audit_confirm(a, rows38, ctx).filter(func(r): return int(r.state) == 38)
	var st38: Array = rows38.filter(func(r): return int(r.get("id", 0)) == 38)
	var kept_anim: bool = st38.size() == 1 and (st38[0].effects as Array).any(func(x): return str(x.get("op", "")) == "effect_program" and bool(x.get(XTianqiLedger.LIVE_POOLED, false)))
	_check("t200_38_runtime", absf(s_off - 105.0) <= 0.01 and is_equal_approx(float(sew.add), 0.05) and is_equal_approx(float(sew.nine), 0.05)
		and absf(s_on - 100.0) <= 0.01 and absf(s_mate - s_mate_off) <= 0.01 and s_mate_off >= 105.0 and g38.is_empty() and kept_anim, [s_off, sew, s_on, s_mate, s_mate_off, g38])
	_t205(a, mate, e, ctx)
	_fresh(a, [])


## 六、T205：程序类增伤运行期归池
func _add(a, b, critical := false, item := XDB.rec("Skills", 1)) -> Dictionary:
	return XTianqiLedger.live_confirm_add(a, b, 1, item, critical)


func _t205(a, mate, e, ctx: Dictionary) -> void:
	XTianqiLedger.POOL_LIVE = true
	XTianqiLedger.QUIET = true
	# 2731 虚无：×(1＋目标状态数×1%)
	_fresh(a, [2731])
	for sid in [4, 5, 6]:
		e.add_state(sid)
	var n: int = e.states().size()
	var x := _add(a, e)
	var c_on := _confirm(a, e)
	var g := XTianqiLedger.audit_confirm(a, XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false)), ctx).filter(func(r): return int(r.state) == 2731)
	XTianqiLedger.POOL_LIVE_PROBE = false
	var x_off := _add(a, e)
	var c_off := _confirm(a, e)
	var g_off := XTianqiLedger.audit_confirm(a, XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false)), ctx).filter(func(r): return int(r.state) == 2731)
	XTianqiLedger.POOL_LIVE_PROBE = true
	_check("t205_2731_probe", n >= 3 and is_equal_approx(float(x.add), n / 100.0) and absf(c_on - 100.0) <= 0.01 and g.is_empty()
		and is_equal_approx(float(x_off.add), 0.0) and absf(c_off - (100.0 + n)) <= 0.01 and g_off.size() == 1 and g_off[0].ok, [n, x, c_on, x_off, c_off, g, g_off])
	# 1421 欧皇之证：×min(1＋变量1181×0.01%, 1.1)
	_fresh(a, [1421])
	XState.current.set_variable(1181, 500)
	var x1 := _add(a, e)
	XState.current.set_variable(1181, 5000)
	var x2 := _add(a, e)
	_check("t205_1421_var", is_equal_approx(float(x1.add), 0.05) and is_equal_approx(float(x2.add), 0.1) and absf(_confirm(a, e) - 100.0) <= 0.01, [x1, x2])
	XState.current.set_variable(1181, 0)
	# 1834 孤世独行：只剩自己活着时 ×1.5（value_query）
	_fresh(a, [1834])
	var keep_units := XStateEffects.battle_units
	XStateEffects.battle_units = {"actors": [a], "enemies": [e]}
	var solo := _add(a, e)
	var solo_c := _confirm(a, e, 1, 100.0, {"party_members": [a]})
	XTianqiLedger.POOL_LIVE_PROBE = false
	var solo_off := _confirm(a, e, 1, 100.0, {"party_members": [a]})
	XTianqiLedger.POOL_LIVE_PROBE = true
	XStateEffects.battle_units = {"actors": [a, mate], "enemies": [e]}
	var duo := _add(a, e)
	XStateEffects.battle_units = keep_units
	_check("t205_1834_query", is_equal_approx(float(solo.add), 0.5) and absf(solo_c - 100.0) <= 0.01 and absf(solo_off - 150.0) <= 0.01 and is_equal_approx(float(duo.add), 0.0), [solo, solo_c, solo_off, duo])
	# 2583 雷道之威：k<1（目标最大 HP 不到角色 10 倍）不进池、照乘缩小
	_fresh(a, [2583])
	var k2583: float = minf(e.mhp / a.mhp * 0.1, 1.3)
	var phys: Dictionary = XDB.rec("Skills", 1).merged({"hitType": 1, "damage": {"type": 1}}, true)  # 只认物理 HP 伤害（技能 1 是魔法）
	var x3 := _add(a, e, false, phys)
	var c3 := _confirm(a, e, 1, 100.0, {"item": phys})
	XTianqiLedger.POOL_LIVE_PROBE = false
	var c3_off := _confirm(a, e, 1, 100.0, {"item": phys})
	XTianqiLedger.POOL_LIVE_PROBE = true
	_check("t205_2583_keep_down", k2583 < 1.0 and is_equal_approx(float(x3.add), 0.0) and absf(c3 - c3_off) <= 0.01 and c3 < 100.0, [k2583, x3, c3, c3_off])
	# 1666 半步真仙：as 换写 ③＋100%，自删那段原程序留着（打标记）
	_fresh(a, [1666])
	var x4 := _add(a, e)
	var rows4: Array = XTianqiLedger.live_confirm_rows(a, a.effect_states("confirm", false)).filter(func(r): return int(r.get("id", 0)) == 1666)
	var kept: bool = rows4.size() == 1 and (rows4[0].effects as Array).any(func(z): return str(z.get("op", "")) == "effect_program" and bool(z.get(XTianqiLedger.LIVE_POOLED, false)))
	_check("t205_1666_as", is_equal_approx(float(x4.add), 1.0) and absf(_confirm(a, e) - 100.0) <= 0.01 and _confirm(a, mate) >= 199.0 and kept, [x4])
	# 1522 神秘成圣：③＋50%、④＋50%；2556 胡桃：④＋150%。暴击／非暴击各一下
	_fresh(a, [1522])
	var x5 := _add(a, e)
	var crit_on := _crit(a, e, true)
	var plain_on := _crit(a, e, false)
	var cc_on := _confirm(a, e, 1, 100.0, {"critical": true})
	XTianqiLedger.POOL_LIVE_PROBE = false
	var crit_off := _crit(a, e, true)
	var cc_off := _confirm(a, e, 1, 100.0, {"critical": true})
	XTianqiLedger.POOL_LIVE_PROBE = true
	_check("t205_1522_crit", is_equal_approx(float(x5.add), 0.5) and is_equal_approx(float(x5.crit), 0.5) and is_equal_approx(crit_on - crit_off, 0.5)
		and is_equal_approx(plain_on, 1.0) and absf(cc_on - 100.0) <= 0.01 and absf(cc_off - 225.0) <= 0.01, [x5, crit_on, crit_off, plain_on, cc_on, cc_off])
	_fresh(a, [2556])
	var x6 := _add(a, e)
	var crit6 := _crit(a, e, true)
	XTianqiLedger.POOL_LIVE_PROBE = false
	var crit6_off := _crit(a, e, true)
	var c6_off := _confirm(a, e, 1, 100.0, {"critical": true})
	XTianqiLedger.POOL_LIVE_PROBE = true
	_check("t205_2556_crit", is_equal_approx(float(x6.add), 0.0) and is_equal_approx(float(x6.crit), 1.5) and is_equal_approx(crit6 - crit6_off, 1.5)
		and absf(_confirm(a, e, 1, 100.0, {"critical": true}) - 100.0) <= 0.01 and absf(c6_off - 250.0) <= 0.01 and absf(_confirm(a, e) - 100.0) <= 0.01, [x6, crit6, crit6_off, c6_off])
	XTianqiLedger.POOL_LIVE = false
	_fresh(a, [])


## 这一下的暴击倍率（breakdown.row.critical）
func _crit(a, e, critical: bool) -> float:
	return float(XDamage.calculate(XDB.rec("Skills", 1), a, e, {"critical": critical, "variance": false}).breakdown.row.critical)
