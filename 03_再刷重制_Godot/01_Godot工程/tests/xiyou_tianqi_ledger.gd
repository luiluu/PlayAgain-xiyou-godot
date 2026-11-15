extends Node
## 伤害加成总账·期一（XTianqiLedger，damage_ledger.json；设计仓《天启篇_伤害加成总账_v0.4》第八节期一细则）：
## 一、逐号清单：15 个专属模块钩子在「普攻／没改写的技能／派生」下实际产出的乘操作全打出来（LEDGER_DUMP 行，交付单附表照它），
##     每一条都要在总账里登记得上（来源、字段、状态合规）。
## 二、MODULE_CAP：卡开着就默认拦（普攻、没改写、派生都拦），白名单才放；MODULE_CAP_ALL 关回到只拦改写过的技能；卡关着原样。
## 三、守卫：没登记的来源、字段不对、已归池、豁免到期都记违规；登记合规的不记；西游档不进守卫；GUARD 关不记。
## 四、不改数：天启篇档总账三个开关全开、全关，各模块角色普攻／技能的伤害逐项相等；西游档伤害详情、被动缓存和 main 一样（不带新键）。
## 五、来源分桶：天启篇档被动缓存带 bySource，各桶相加＝原合计；BUCKETS 关不带。
## 六、五池明细：天启篇伤害详情带 pools／residual，和那一行的乘区值对得上；DETAIL 关不带。
## 七、原版状态确认阶段乘：数据里每个有确认阶段效果的状态都在 state_confirm_ids 里（新状态出现就失败）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const MODULE_ACTORS := {"module.raven": 167, "module.number_boost": 168, "module.mira": 168, "module.sukuna": 172, "module.yomi_jingliu": 169,
	"module.toji": 171, "module.toji_incoming": 171, "module.garou": 173, "module.yunshang": 174, "module.black_flash": 172,
	"module.xuan_cast": 177, "module.xuan_incoming": 177, "module.xuan_damage": 177, "module.tusu": 176, "module.liuying": 179}
const MODULE_FILES := {167: "raven", 168: "mira", 169: "yomi_jingliu", 170: "yomi_jingliu", 171: "toji", 172: "sukuna", 173: "garou", 174: "yunshang",
	176: "tusu", 177: "xuan_battle", 179: "liuying"}
var results: Array = []
var kit: Kit
var dump: Array = []


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


func _state(extra: Array, tianqi := true, difficulty := "jianxian") -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, difficulty, lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup + extra:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_ledger")
	seed(20261115)
	XTianqiLedger.reload()
	_registry_shape()
	_dump_and_cap()
	_guard()
	_numbers_same()
	_buckets()
	_pools()
	_state_confirm()
	XTianqiSkills.CARDS = false
	XTianqiSkills.MODULE_CAP_ALL = true
	XTianqiLedger.GUARD = true
	XTianqiLedger.BUCKETS = true
	XTianqiLedger.DETAIL = true
	XTianqiLedger.QUIET = false
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 表本身 ----
func _registry_shape() -> void:
	var d := XTianqiLedger.data()
	_check("ledger_loaded", not d.is_empty() and XTianqiLedger.phase() == 1)
	var bad := []
	for r in d.get("rows", []):
		var st := str(r.get("status", ""))
		if not st in ["pooled", "exempt", "allowed"] or (st == "exempt" and int(r.get("expires", 0)) <= 1):
			bad.append(r.id)
	_check("ledger_rows_valid", bad.is_empty(), bad)
	_check("module_whitelist_empty_at_p1", (d.get("module_whitelist", []) as Array).is_empty())
	# 期一登记：七印、宝珠共鸣、种族豁免·期二；15 个专属模块钩子豁免·期四
	var p2 := ["qiyin", "orb_resonance", "race"].all(func(k): return XTianqiLedger.row(k).get("status") == "exempt" and int(XTianqiLedger.row(k).get("expires")) == 2)
	_check("p1_exempt_phase2", p2)
	var p4 := XActorDamageHooks.MODULE_TAGS.all(func(k): return XTianqiLedger.row(k).get("status") == "exempt" and int(XTianqiLedger.row(k).get("expires")) == 4)
	_check("p1_modules_exempt_phase4", p4 and XActorDamageHooks.MODULE_TAGS.size() == 15)
	# 来源名都有一行（tags、注册表模块）
	var missing := []
	for t in XActorDamageHooks.MODULE_TAGS + ["qiyin", "affix_skill", "module.tianqi_modules"] + XTianqiLedger.MODULE_SOURCE.values().filter(func(v): return v != "alienation"):
		if XTianqiLedger.row(t).is_empty():
			missing.append(t)
	_check("sources_have_rows", missing.is_empty(), missing)
	# 注册表里每个写单独相乘字段的模块都认得出来源
	var unknown := []
	for entry in XModuleRegistry.standard().manifest():
		for h in entry.get("hooks", []):
			if (h.get("writes", []) as Array).any(func(f): return XTianqiLedger.MUL_FIELDS.has(f)) and str(entry.id) != "actor-modules" and not XTianqiLedger.MODULE_SOURCE.has(str(entry.id)):
				unknown.append(entry.id)
	_check("registry_modules_mapped", unknown.is_empty(), unknown)


# ---- 一、二：逐号清单＋MODULE_CAP ----
func _module_skills(actor_id: int) -> Array:
	var f := FileAccess.open("res://modes/xiyou/core/%s.gd" % MODULE_FILES.get(actor_id, "raven"), FileAccess.READ)
	var ids := {}
	for m in RegEx.create_from_string("\\b(10\\d{3})\\b").search_all(f.get_as_text()):
		var id := int(m.get_string(1))
		var rec := XDB.rec("Skills", id)
		if not rec.is_empty() and int(rec.get("damage", {}).get("type", 0)) in [1, 5]:
			ids[id] = true
	return ids.keys()


## 情形：普攻（1）、防御（2）、没改写（不在 skill_rework.json）、改写过（对照）；派生＝真打时不是这一下所选的招（模块内部再打一下、借普攻号的追加段）
func _scenario(id: int, derived := false) -> String:
	if derived:
		return "派生"
	if id in [1, 2]:
		return "普攻" if id == 1 else "防御"
	return "改写" if XTianqiSkills.has(id) else "没改写"


## 记一条原始操作：进清单、核登记、核卡开着时的收口
func _note_ops(tag: String, item: Dictionary, a: XActor, raw: Array, scen: String, cards: bool, acc: Dictionary) -> void:
	var id := int(item.get("id", 0))
	XTianqiSkills.MODULE_CAP_ALL = true
	var capped := XTianqiSkills.module_ops(item, a, raw, tag) if cards else []
	XTianqiSkills.MODULE_CAP_ALL = false
	var old := XTianqiSkills.module_ops(item, a, raw, tag) if cards else []
	XTianqiSkills.MODULE_CAP_ALL = true
	for o in raw:
		var mul := XTianqiLedger.is_mul(o)
		var boost := _boost(o)
		if not mul and not boost:
			continue
		var key := "%s|%s|%d|%s|%s|%s" % [tag, scen, id, o.field, o.op, str(snappedf(float(o.value), 0.0001))]
		if not acc.seen.has(key):
			acc.seen[key] = true
			dump.append(key)
			print("LEDGER_DUMP|" + key + "|" + ("乘" if mul else "加") + ("|卡开" if cards else ""))
		if mul and XTianqiLedger.check(tag, str(o.field)) != "":
			acc.unregistered.append(key)
		if cards and boost:
			if capped.any(func(c): return c.field == o.field and c.op == o.op and is_equal_approx(float(c.value), float(o.value))):
				acc.leaked_all.append(key)
			# 旧口径只拦改写过的技能：没改写的（含普攻、派生）旧口径会漏，这就是期一要堵的口子
			if not XTianqiSkills.has(id) and not old.any(func(c): return c.field == o.field and c.op == o.op and is_equal_approx(float(c.value), float(o.value))):
				acc.old_not_leaking.append(key)


## 真打：模块角色五人一队，自动战斗几回合，钩子原始操作逐段记下（含派生）
func _battle_dump(group: Array, cards: bool, acc: Dictionary) -> void:
	var s := _state(group, true, "jiusi")  # 艰险不许超强者上场（super_cap 0），九死起许一个
	var slots := s.battle_slots.duplicate()
	slots[0] = int(group[0])  # 超强者一队只许一个（XItemMarks.enforce_party）：模块角色放第一格，其余照开局的弱者
	s.battle_slots = slots
	for aid in group:
		var a := s.actor(int(aid))
		a.change_level(99)
		for id in _module_skills(int(aid)):
			a.learn_skill(int(id))
		a.recover_all()
	XTianqiSkills.CARDS = cards
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	for e in logic.enemies:
		e._rates[0] *= 1000
		e.recover_all()
	logic.auto = true
	XActorDamageHooks.RECORD = []
	var acts := 0
	for _round in 8:
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		while count < 60:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			XActorDamageHooks.RECORD_ACT = {"subject": u, "skill": int(cmd[0].id) if cmd[0] != null else -1}
			if u is XActor:
				acts += 1
			logic.act(u, cmd[0], cmd[1])
		logic.end_turn()
		if logic.is_over():
			break
	var rec: Array = XActorDamageHooks.RECORD
	XActorDamageHooks.RECORD = null
	XActorDamageHooks.RECORD_ACT = {}
	acc.battle_rows += rec.size()
	var picks := {}
	for r in rec:
		var k := "%d:%d%s" % [int(r.actor), int(r.skill), "派" if r.derived else ""]
		picks[k] = int(picks.get(k, 0)) + 1
	print("LEDGER_BATTLE|%s|卡%s|上场%s|出手%d|%s" % [str(group), "开" if cards else "关", str(logic.actors.map(func(x): return x.actor_id)), acts, JSON.stringify(picks)])
	for r in rec:
		var a := s.actor(int(r.actor)) if int(r.actor) > 0 else null
		if a == null:
			continue
		_note_ops(str(r.tag), XDB.rec("Skills", int(r.skill)), a, r.ops, _scenario(int(r.skill), bool(r.derived)), cards, acc)
	XTianqiSkills.CARDS = false


func _dump_and_cap() -> void:
	var actors := [167, 168, 169, 170, 171, 172, 173, 174, 176, 177, 179]
	var s := _state(actors)
	var b := XEnemy.new().setup(1, 3, 100.0)
	var acc := {"seen": {}, "unregistered": [], "leaked_all": [], "old_not_leaking": [], "battle_rows": 0}
	# 直接调：每个模块角色学满模块里出现的技能，普攻、防御和这些技能各算一次（卡关、卡开）
	for aid in actors:
		var a := s.actor(int(aid))
		a.change_level(99)
		var ids := [1, 2] + _module_skills(aid)
		for id in ids:
			if int(id) > 2:
				a.learn_skill(int(id))
		for id in ids:
			var item := XDB.rec("Skills", int(id))
			for cards in [false, true]:
				XTianqiSkills.CARDS = cards
				var parts := XActorDamageHooks.module_parts(item, a, b)
				for i in XActorDamageHooks.MODULE_TAGS.size():
					_note_ops(XActorDamageHooks.MODULE_TAGS[i], item, a, parts[i], _scenario(int(id)), cards, acc)
	XTianqiSkills.CARDS = false
	# 真打：派生只有打起来才有
	for aid in actors:
		var group := [aid]
		for cards in [false, true]:
			_battle_dump(group, cards, acc)
	var unregistered: Array = acc.unregistered
	var leaked_all: Array = acc.leaked_all
	var leaked_old: Array = acc.old_not_leaking
	print("LEDGER_BATTLE_ROWS=%d" % int(acc.battle_rows))
	_check("battle_recorded", int(acc.battle_rows) > 20, acc.battle_rows)
	XTianqiSkills.CARDS = false
	print("LEDGER_DUMP_TOTAL=%d" % dump.size())
	_check("dump_nonempty", dump.size() >= 10, dump.size())
	var scens := {}
	for k in dump:
		scens[str(k).split("|")[1]] = true
	_check("dump_scenarios", ["普攻", "派生"].all(func(sc): return scens.has(sc)), scens.keys())
	_check("dump_all_registered", unregistered.is_empty(), unregistered)
	_check("cap_all_blocks_boosts", leaked_all.is_empty(), leaked_all)
	# 旧口径（MODULE_CAP_ALL 关）：普攻、没改写、派生上的增伤不拦（这就是期一要堵的漏口）
	_check("cap_old_leaks_unrewritten", leaked_old.is_empty(), leaked_old)
	# 卡关着：MODULE_CAP 原样（数值与 main 一致的前提）
	var rv := s.actor(167)
	var mods := [{"op": "mul", "field": "settlementMultiplier", "value": 4.25}, {"op": "add", "field": "finalAdd", "value": 1.5}]
	_check("cap_cards_off_untouched", XTianqiSkills.module_ops(XDB.rec("Skills", 1), rv, mods, "module.raven") == mods)
	XTianqiSkills.CARDS = true
	_check("cap_cards_on_attack_blocked", XTianqiSkills.module_ops(XDB.rec("Skills", 1), rv, mods, "module.raven").is_empty())
	XTianqiSkills.MODULE_CAP_ALL = false
	_check("cap_switch_off_attack_kept", XTianqiSkills.module_ops(XDB.rec("Skills", 1), rv, mods, "module.raven").size() == 2)
	XTianqiSkills.MODULE_CAP_ALL = true
	# 白名单：写进去才放（只放那个模块、那个技能、那个字段）
	var wl: Array = XTianqiLedger.data().module_whitelist
	wl.append({"module": "module.raven", "skill": 1, "field": "settlementMultiplier", "reason": "测试"})
	var w := XTianqiSkills.module_ops(XDB.rec("Skills", 1), rv, mods, "module.raven")
	var w2 := XTianqiSkills.module_ops(XDB.rec("Skills", 1), rv, mods, "module.toji")
	wl.clear()
	_check("cap_whitelist", w.size() == 1 and w[0].field == "settlementMultiplier" and w2.is_empty(), w)
	# 机制类照旧放行（伤害方式、承伤、无视防御夹到 0.7）
	var mech := [{"op": "set", "field": "mode", "value": "magical"}, {"op": "mul", "field": "incomingMultiplier", "value": 0.8}, {"op": "mul", "field": "magicalDefenseRate", "value": 0.1}]
	var m := XTianqiSkills.module_ops(XDB.rec("Skills", 1), rv, mech, "module.raven")
	_check("cap_mechanics_kept", m.size() == 3 and is_equal_approx(float(m[2].value), 0.7), m)
	XTianqiSkills.CARDS = false


static func _boost(o: Dictionary) -> bool:
	var f := str(o.get("field", ""))
	var k := str(o.get("op", ""))
	return (k == "mul" and f in ["finalMultiplier", "skillMultiplier", "settlementMultiplier"] and float(o.get("value", 1.0)) > 1.0) \
		or (k == "add" and f in ["finalAdd", "normalAdd", "elementAdd", "criticalAdd"] and float(o.get("value", 0.0)) > 0.0)


# ---- 三、守卫 ----
func _guard() -> void:
	var s := _state([])
	var a := s.actor(int(s.battle_slots[0]))
	XTianqiLedger.QUIET = true
	var item := XDB.rec("Skills", 1)
	var trace := [{"module": "actor-modules", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.2}, {"op": "mul", "field": "finalMultiplier", "value": 3.0},
		{"op": "mul", "field": "settlementMultiplier", "value": 1.5}, {"op": "mul", "field": "finalMultiplier", "value": 2.0}, {"op": "mul", "field": "incomingMultiplier", "value": 0.5}]},
		{"module": "orb-sets", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.3}]},
		{"module": "new-module", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.1}, {"op": "mul", "field": "finalMultiplier", "value": 1.0}]}]
	var facts := {"actorModules": {"tags": ["qiyin", "weak_challenge", "qiyin", "new.source", "module.mira"]}}
	XTianqiLedger.violations.clear()
	var found := XTianqiLedger.audit(item, a, trace, facts, {"skill_pass": 1.0, "race": 1.2, "independent": 1.0})
	var why := XTianqiLedger.violations.map(func(v): return "%s.%s:%s" % [v.source, v.field, v.reason])
	_check("guard_flags", why == ["weak_challenge.finalMultiplier:pooled", "qiyin.settlementMultiplier:field_not_registered", "new.source.finalMultiplier:unregistered", "module:new-module.finalMultiplier:unregistered"], why)
	_check("guard_ok_rows", found.filter(func(f): return f.ok).map(func(f): return f.source) == ["qiyin", "orb_resonance", "enemy_race_bonus"], found)
	# 豁免到期：期数到了就判失败
	XTianqiLedger.data()["phase"] = 2
	XTianqiLedger.violations.clear()
	XTianqiLedger.audit(item, a, [{"module": "orb-sets", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.3}]}], {}, {})
	_check("guard_exempt_expires", XTianqiLedger.violations.size() == 1 and XTianqiLedger.violations[0].reason == "exempt_expired", XTianqiLedger.violations)
	XTianqiLedger.data()["phase"] = 1
	# GUARD 关：不记
	XTianqiLedger.GUARD = false
	XTianqiLedger.violations.clear()
	XTianqiLedger.audit(item, a, trace, facts, {})
	_check("guard_switch_off", XTianqiLedger.violations.is_empty())
	XTianqiLedger.GUARD = true
	# 敌人出手不进守卫（总账只管我方加成）
	var e := XEnemy.new().setup(1, 3, 100.0)
	_check("guard_enemy_skipped", not XTianqiLedger.auditing(e) and XTianqiLedger.auditing(a))
	# 西游档：不进守卫
	var x := _state([167], false)
	_check("guard_xiyou_off", not XTianqiLedger.auditing(x.actor(167)))
	XTianqiLedger.QUIET = false
	# 真打一下：天启篇档里全部登记合规，不出违规
	XState.current = s
	XTianqiLedger.violations.clear()
	XDamage.calculate(XDB.rec("Skills", 1), a, XEnemy.new().setup(1, 3, 100.0), {"critical": false, "variance": false})
	_check("guard_real_hit_clean", XTianqiLedger.violations.is_empty(), XTianqiLedger.violations)


# ---- 四、不改数 ----
func _set_all(on: bool) -> void:
	XTianqiLedger.GUARD = on
	XTianqiLedger.BUCKETS = on
	XTianqiLedger.DETAIL = on
	XTianqiSkills.MODULE_CAP_ALL = on


func _hits(s: XState, ids: Array) -> Array:
	var out := []
	var b := XEnemy.new().setup(1, 3, 100.0)
	for aid in ids:
		var a := s.actor(int(aid))
		a.refresh_passive()
		for sid in [1] + _module_skills(int(aid)).slice(0, 4):
			for crit in [false, true]:
				var res := XDamage.calculate(XDB.rec("Skills", int(sid)), a, b, {"critical": crit, "variance": false})
				out.append(XDamage.finish(res, XDB.rec("Skills", int(sid)), a, b, false))
	return out


func _numbers_same() -> void:
	var actors := [167, 168, 169, 171, 172, 173, 174, 176, 177, 179]
	var s := _state(actors)
	for aid in actors:
		s.actor(int(aid)).change_level(60)
	XTianqiLedger.violations.clear()
	_set_all(true)
	var on := _hits(s, actors)
	_check("tq_hits_no_violation", XTianqiLedger.violations.is_empty(), XTianqiLedger.violations.slice(0, 5))
	_set_all(false)
	var off := _hits(s, actors)
	_set_all(true)
	_check("tq_numbers_same", on == off and on.size() > 20, [on.size(), off.size()])
	# 西游档：伤害详情不带五池、被动缓存不带 bySource，模块钩子 facts 不带 tags
	var x := _state([167], false)
	var xa := x.actor(167)
	xa.refresh_passive()
	var res := XDamage.calculate(XDB.rec("Skills", 1), xa, XEnemy.new().setup(1, 3, 100.0), {"critical": false, "variance": false})
	_check("xiyou_no_pools", not res.breakdown.row.has("pools"), res.breakdown.row.keys())
	_check("xiyou_no_buckets", not xa.passive_cache().has("bySource"))
	_check("xiyou_capture_no_tags", not XActorDamageHooks.capture(XDB.rec("Skills", 1), xa, XEnemy.new().setup(1, 3, 100.0)).has("tags"))


# ---- 五、来源分桶 ----
func _sum(d: Dictionary) -> float:
	var v := 0.0
	for k in d:
		v += float(d[k])
	return v


func _buckets() -> void:
	var s := _state([])
	var bad := []
	var any := false
	for id in s.battle_slots:
		var a := s.actor(int(id))
		# 学几本带终伤、技能类型增伤的通用被动书，保证有东西可分
		for sk in XDB.table("Skills"):
			if sk is Dictionary and int(sk.get("stypeId", 0)) == 5 and str(sk.get("note", "")).contains("passiveHarmRi"):
				a.learn_skill(int(sk.id))
				break
		a.refresh_passive()
		var c := a.passive_cache()
		if not c.has("bySource"):
			bad.append([id, "missing"])
			continue
		var by: Dictionary = c.bySource
		var base: Dictionary = a._pm_base if not a._pm_base.is_empty() else c
		if not is_equal_approx(_sum(by.globalHarmRi), float(base.globalHarmRi)):
			bad.append([id, "globalHarmRi", by.globalHarmRi, base.globalHarmRi])
		if not is_equal_approx(_sum(by.critHarmRi), float(base.critHarmRi)):
			bad.append([id, "critHarmRi"])
		for t in base.skillTypeDvup:
			if not is_equal_approx(_sum(by.skillTypeDvup.get(str(t), {})), float(base.skillTypeDvup[t])):
				bad.append([id, "skillTypeDvup", t])
		if float(base.globalHarmRi) != 0.0:
			any = true
			if not by.globalHarmRi.has("secret"):
				bad.append([id, "secret_bucket", by.globalHarmRi])
		for e in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
			var amp := 0.0
			for o in a.states() + a.stat_equips() + [a.data(), a.class_data()]:
				amp += float(o.get("yep", {}).get("elementAmplify", {}).get(str(e), 0.0))
			if not is_equal_approx(_sum(by.elementAmplify.get(e, {})), amp):
				bad.append([id, "elementAmplify", e])
	_check("buckets_sum_to_total", bad.is_empty(), bad)
	_check("buckets_nonempty", any)
	# 装备分桶认天启篇标记
	_check("bucket_of_equip", XTianqiLedger.bucket_of({"kind": "weapon", "qiyin": {}}) == "tianqi" and XTianqiLedger.bucket_of({"kind": "armor"}) == "equip" \
		and XTianqiLedger.bucket_of({"kind": "armor", "runewords": [1]}) == "runeword")
	XTianqiLedger.BUCKETS = false
	var a0 := s.actor(int(s.battle_slots[0]))
	a0._pm_base = {}
	a0.refresh_passive()
	_check("buckets_switch_off", not a0.passive_cache().has("bySource"))
	XTianqiLedger.BUCKETS = true


# ---- 六、五池明细 ----
func _pools() -> void:
	var s := _state([])
	var a := s.actor(int(s.battle_slots[0]))
	var res := XDamage.calculate(XDB.rec("Skills", 1), a, XEnemy.new().setup(1, 3, 100.0), {"critical": true, "variance": false})
	var row: Dictionary = res.breakdown.row
	var p: Dictionary = row.get("pools", {})
	var ok := p.has_all(["skill", "element", "bonus", "crit", "tier"]) and is_equal_approx(float(p.skill), float(row.normal)) and is_equal_approx(float(p.crit), float(row.critical)) \
		and is_equal_approx(float(p.bonus) * float(row.residual.finalMultiplier), float(row.terminal)) \
		and is_equal_approx(float(p.element) * float(row.residual.elementMultiplier), float(row.bonus)) and float(p.tier) > 0.0
	_check("pools_detail", ok, row)
	XTianqiLedger.DETAIL = false
	var res2 := XDamage.calculate(XDB.rec("Skills", 1), a, XEnemy.new().setup(1, 3, 100.0), {"critical": true, "variance": false})
	_check("pools_switch_off", not res2.breakdown.row.has("pools") and res2.value == res.value)
	XTianqiLedger.DETAIL = true


# ---- 七、原版状态确认阶段乘 ----
func _state_confirm() -> void:
	var fresh := []
	for st in XDB.table("States"):
		if not st is Dictionary:
			continue
		if (st.get("effects", []) as Array).any(func(e): return str(e.get("phase", "")) == "confirm" and str(e.get("op", "")) != "noop") and not XTianqiLedger.state_confirm_registered(int(st.id)):
			fresh.append(int(st.id))
	_check("state_confirm_all_registered", fresh.is_empty(), fresh)
