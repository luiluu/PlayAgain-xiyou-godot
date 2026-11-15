extends Node
## 伤害加成总账·期一（XTianqiLedger，damage_ledger.json；设计仓《天启篇_伤害加成总账_v0.4》第八节期一细则）：
## 一、逐号清单：15 个专属模块钩子在「普攻／没改写的技能／派生」下实际产出的乘操作全打出来（LEDGER_DUMP 行，交付单附表照它），
##     每一条都要在总账里登记得上（来源、字段、状态合规）。
## 二、MODULE_CAP：卡开着就默认拦（普攻、没改写、派生都拦），白名单才放；MODULE_CAP_ALL 关回到只拦改写过的技能；卡关着原样。
## 三、守卫：没登记的来源、字段不对、已归池、豁免到期都记违规；登记合规的不记；西游档不进守卫；GUARD 关不记。
## 四、不改数：天启篇档总账三个开关全开、全关，各模块角色普攻／技能的伤害逐项相等；西游档伤害详情、被动缓存和 main 一样（不带新键）。
## 五、来源分桶：天启篇档被动缓存带 bySource，各桶相加＝原合计；BUCKETS 关不带。
## 六、五池明细：天启篇伤害详情带 pools／residual，和那一行的乘区值对得上；DETAIL 关不带。
## 七、原版状态确认阶段乘：数据里每个有确认阶段效果的状态都在 state_confirm_ids 里、效果指纹和期一快照一致（新状态、既有状态改了都失败）；
##     期二起运行期也逐个过 check（XTianqiLedger.audit_confirm），到期、没登记都报（期一核查 P2）。
## 八、期二「归池清场」（设计稿第五节第 1 条全表）：每一样归池后的算法、回退开关、守卫状态；西游档开关开关一样。
## 九、敌方链路分链验证（期一「需设计稿补记」1、2 条）：元素反射、状态 React 反伤、技能卡反弹、敌源按生命上限比例状态都不吃我方的池，开关开关一样。

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
	_p2_items()
	_enemy_chains()
	XTianqiLedger.set_all_p2(true)
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
	_check("ledger_loaded", not d.is_empty() and XTianqiLedger.phase() == 2)
	var bad := []
	for r in d.get("rows", []):
		var st := str(r.get("status", ""))
		if not st in ["pooled", "exempt", "allowed"] or (st == "exempt" and int(r.get("expires", 0)) <= 1):
			bad.append(r.id)
	_check("ledger_rows_valid", bad.is_empty(), bad)
	_check("module_whitelist_empty_at_p1", (d.get("module_whitelist", []) as Array).is_empty())
	# 期二：期一「豁免·期二到期」的七行全部改成已归池、各挂一个回退开关；套装确认阶段、万灵增元丹被动也是已归池；不再有期二到期的豁免
	var p2_rows := ["qiyin", "orb_resonance", "race", "affix_skill", "skill_pass", "enemy_race_bonus", "self_rate", "suit_confirm", "pill_passives"]
	var not_pooled := p2_rows.filter(func(k): return XTianqiLedger.row(k).get("status") != "pooled" or str(XTianqiLedger.row(k).get("switch", "")) == "")
	_check("p2_rows_pooled", not_pooled.is_empty(), not_pooled)
	var left := (d.get("rows", []) as Array).filter(func(r): return str(r.get("status")) == "exempt" and int(r.get("expires", 0)) <= 2).map(func(r): return r.id)
	_check("p2_no_exempt_left", left.is_empty(), left)
	_check("p2_new_rows", ["qiyin_derived", "combat_rules"].all(func(k): return XTianqiLedger.row(k).get("status") == "allowed"))
	var p4: bool = XActorDamageHooks.MODULE_TAGS.all(func(k): return XTianqiLedger.row(k).get("status") == "exempt" and int(XTianqiLedger.row(k).get("expires")) == 4) \
		and XTianqiLedger.row("state_confirm").get("status") == "exempt" and int(XTianqiLedger.row("state_confirm").get("expires")) == 4
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
		{"op": "mul", "field": "settlementMultiplier", "value": 1.5}, {"op": "mul", "field": "finalMultiplier", "value": 2.0}, {"op": "mul", "field": "incomingMultiplier", "value": 0.5},
		{"op": "mul", "field": "finalMultiplier", "value": 1.4}, {"op": "mul", "field": "finalMultiplier", "value": 0.5}]},
		{"module": "orb-sets", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.3}]},
		{"module": "new-module", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.1}, {"op": "mul", "field": "finalMultiplier", "value": 1.0}]}]
	var facts := {"actorModules": {"tags": ["module.raven", "weak_challenge", "module.toji", "new.source", "module.mira", "qiyin", "qiyin_derived"]}}
	XTianqiLedger.violations.clear()
	var found := XTianqiLedger.audit(item, a, trace, facts, {"skill_pass": 1.0, "race": 1.2, "independent": 1.0})
	var why := XTianqiLedger.violations.map(func(v): return "%s.%s:%s" % [v.source, v.field, v.reason])
	# 期二：七印、宝珠共鸣、对某族增伤已归池，再出现乘就失败
	_check("guard_flags", why == ["weak_challenge.finalMultiplier:pooled", "module.toji.settlementMultiplier:field_not_registered", "new.source.finalMultiplier:unregistered",
		"qiyin.finalMultiplier:pooled", "orb_resonance.finalMultiplier:pooled", "module:new-module.finalMultiplier:unregistered", "enemy_race_bonus.race:pooled"], why)
	_check("guard_ok_rows", found.filter(func(f): return f.ok).map(func(f): return f.source) == ["module.raven", "qiyin_derived"], found)
	# 回退开关关着的那一样：有意回退，守卫不报
	XTianqiLedger.POOL_ORB = false
	XTianqiLedger.POOL_QIYIN = false
	XTianqiLedger.violations.clear()
	XTianqiLedger.audit(item, a, [{"module": "orb-sets", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.3}]}, {"module": "actor-modules", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.2}]}],
		{"actorModules": {"tags": ["qiyin"]}}, {})
	_check("guard_switch_off_rollback_quiet", XTianqiLedger.violations.is_empty(), XTianqiLedger.violations)
	XTianqiLedger.POOL_ORB = true
	XTianqiLedger.POOL_QIYIN = true
	# 豁免到期：期数到了就判失败（专属模块期四到期）
	XTianqiLedger.data()["phase"] = 4
	XTianqiLedger.violations.clear()
	XTianqiLedger.audit(item, a, [{"module": "actor-modules", "ops": [{"op": "mul", "field": "finalMultiplier", "value": 1.1}]}], {"actorModules": {"tags": ["module.raven"]}}, {})
	_check("guard_exempt_expires", XTianqiLedger.violations.size() == 1 and XTianqiLedger.violations[0].reason == "exempt_expired", XTianqiLedger.violations)
	XTianqiLedger.data()["phase"] = 2
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
## 期一的四个开关（守卫、分桶、明细、MODULE_CAP_ALL）：卡关着时全开全关伤害逐项相等（期二归池开关另在第八节）
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
	# 期一核查 P3：原来漏了 170（镜流）；这里是 11 个模块角色、每人普攻＋前四个模块技能、暴击／不暴击（不是「全部技能」）
	var actors := [167, 168, 169, 170, 171, 172, 173, 174, 176, 177, 179]
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
	_check("tq_numbers_same", on == off and on.size() > 80, [on.size(), off.size()])
	# 西游档：期二全部归池开关开、关，同一批角色伤害逐项相等（归池只对天启篇存档）
	var xs := _state(actors, false)
	for aid in actors:
		xs.actor(int(aid)).change_level(60)
	XTianqiLedger.set_all_p2(true)
	var xon := _hits(xs, actors)
	XTianqiLedger.set_all_p2(false)
	var xoff := _hits(xs, actors)
	XTianqiLedger.set_all_p2(true)
	_check("xiyou_p2_switches_same", xon == xoff and xon.size() > 80, [xon.size(), xoff.size()])
	XState.current = s
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
	# 期一核查 P2：效果指纹（操作级）——既有状态号的确认阶段效果改了也认得出
	var fp: Dictionary = XTianqiLedger.data().get("state_confirm_fp", {})
	var changed := []
	var n := 0
	for st in XDB.table("States"):
		if st is Dictionary:
			var f := XTianqiLedger.confirm_fingerprint(st)
			if f != "":
				n += 1
				if str(fp.get(str(int(st.id)), "")) != f:
					changed.append(int(st.id))
	_check("state_confirm_fingerprints", changed.is_empty() and n == fp.size() and n > 150, [changed.slice(0, 10), n, fp.size()])
	var probe := {"id": 713, "effects": [{"phase": "confirm", "op": "mul", "cond": "nonzero", "k": 3.0, "round": "ceil"}]}
	_check("state_confirm_fp_bites", XTianqiLedger.confirm_fingerprint(probe) != str(fp.get("713", "")) and XTianqiLedger.confirm_fingerprint(XDB.rec("States", 713)) == str(fp.get("713", "")))
	# 运行期守卫：登记过的过 check（期二合规；期四到期就报），没登记的状态号当场报；套装那一步（带 skipTypes）、难度被动等价行不算
	var s := _state([])
	var a := s.actor(int(s.battle_slots[0]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	var ctx := {"defender": e, "item": XDB.rec("Skills", 1)}
	XTianqiLedger.QUIET = true
	XTianqiLedger.violations.clear()
	var rows := [XDB.rec("States", 713), {"id": 99999, "effects": [{"phase": "confirm", "op": "mul", "cond": "positive", "k": 1.5, "round": "ceil"}]},
		{"id": 1631, "name": XTianqiLedger.CONFIRM_SYNTH, "effects": [{"phase": "confirm", "op": "mul", "k": 1.5}]},
		{"id": 713, "effects": [{"phase": "confirm", "op": "mul", "k": 2.0, "skipTypes": [1]}]}]
	var got := XTianqiLedger.audit_confirm(a, rows, ctx)
	_check("confirm_runtime_p2", got.size() == 2 and got[0].ok and not got[1].ok and XTianqiLedger.violations.size() == 1 and XTianqiLedger.violations[0].reason == "unregistered", [got, XTianqiLedger.violations])
	XTianqiLedger.data()["phase"] = 4
	XTianqiLedger.violations.clear()
	XTianqiLedger.audit_confirm(a, [XDB.rec("States", 713)], ctx)
	_check("confirm_runtime_expires", XTianqiLedger.violations.size() == 1 and XTianqiLedger.violations[0].reason == "exempt_expired", XTianqiLedger.violations)
	XTianqiLedger.data()["phase"] = 2
	XTianqiLedger.violations.clear()
	XTianqiLedger.audit_confirm(a, [XDB.rec("States", 713)], {"defender": s.actor(int(s.battle_slots[1])), "item": XDB.rec("Skills", 1)})
	XTianqiLedger.audit_confirm(e, [{"id": 99999, "effects": [{"phase": "confirm", "op": "mul", "k": 9.0}]}], ctx)
	_check("confirm_runtime_scope", XTianqiLedger.violations.is_empty(), XTianqiLedger.violations)  # 只管我方打敌人
	XTianqiLedger.QUIET = false


# ---- 八、期二归池清场 ----
func _calc(a, b, item_id := 1, crit := false) -> Dictionary:
	return XDamage.calculate(XDB.rec("Skills", item_id), a, b, {"critical": crit, "variance": false})


func _with_note(rec: Dictionary, extra: String, f: Callable):
	var old := str(rec.get("note", ""))
	rec.note = old + "\n" + extra
	var out = f.call()
	rec.note = old
	return out


func _p2_items() -> void:
	var s := _state([])
	var a := s.actor(int(s.battle_slots[0]))
	a.change_level(40)
	a.refresh_passive()
	var e := XEnemy.new().setup(1, 3, 100.0)
	XTianqiLedger.violations.clear()
	# 1. 技能专属被动 skillPass.rate：进①（normalAdd），skillMultiplier 起点恒 1；只有它一条时数一样
	var saved: Dictionary = a._passive_cache
	a._passive_cache = saved.duplicate(true)
	a._passive_cache.skillPass = {1: {"rate": 0.5}}
	a._passive_cache.skillTypeDvup = {}
	var on := _calc(a, e)
	XTianqiLedger.POOL_SKILL_PASS = false
	var off := _calc(a, e)
	XTianqiLedger.POOL_SKILL_PASS = true
	a._passive_cache = saved
	_check("p2_skill_pass_pooled", is_equal_approx(float(on.breakdown.row.normal), 1.5) and is_equal_approx(float(on.breakdown.row.residual.skillMultiplier), 1.0) \
		and is_equal_approx(float(off.breakdown.row.residual.skillMultiplier), 1.5) and on.value == off.value, [on.breakdown.row.normal, off.breakdown.row.residual])
	# 2. 对某族敌人增伤 <EnemyRaceBo>：种族乘数恒 1，加进③
	var er := func(): return _with_note(e.data(), "<EnemyRace: 1>", func(): return _with_note(a.data(), "<EnemyRaceBo01: 30%>", func():
		var r := {"on": _calc(a, e)}
		XTianqiLedger.POOL_ENEMY_RACE = false
		r.off = _calc(a, e)
		XTianqiLedger.POOL_ENEMY_RACE = true
		return r))
	var r: Dictionary = er.call()
	var base := _calc(a, e)
	_check("p2_enemy_race_pooled", float(r.on.breakdown.row.race) == 1.0 and is_equal_approx(float(r.on.breakdown.row.terminal), float(base.breakdown.row.terminal) + 0.3) \
		and is_equal_approx(float(r.off.breakdown.row.race), 1.3), [r.on.breakdown.row.race, r.on.breakdown.row.terminal, base.breakdown.row.terminal, r.off.breakdown.row.race])
	# 3. 原版独立乘区 <SelfPhysRate>：天启篇不读
	# （天启篇元素牌组把物理 1 映射成 0，普攻这一下不算「物理」，所以直接核 _self_rates 和守卫看到的独立乘区）
	var sr: Dictionary = _with_note(a.data(), "<SelfPhysRate: 2>\n<SelfElemRate: 3>", func():
		var o := {"on": XDamage._self_rates(a), "hit": _calc(a, e).value}
		XTianqiLedger.NO_SELF_RATE = false
		o.off = XDamage._self_rates(a)
		XTianqiLedger.NO_SELF_RATE = true
		return o)
	_check("p2_self_rate_off", sr.on == [1.0, 1.0] and sr.off == [2.0, 3.0] and sr.hit == base.value, sr)
	# 4. 宝珠共鸣：天启篇写 finalAdd ＋g；回退／西游写 finalMultiplier ×(1＋g)
	var orb_on := XModuleRegistry._orb_sets({"facts": {"orbMultiplier": 1.3, "orbPooled": true}}, {})
	var orb_off := XModuleRegistry._orb_sets({"facts": {"orbMultiplier": 1.3}}, {})
	var trace_orb: Array = base.moduleTrace.filter(func(t): return str(t.module) == "orb-sets")
	_check("p2_orb_pooled", orb_on.ops[0].field == "finalAdd" and is_equal_approx(float(orb_on.ops[0].value), 0.3) and orb_off.ops[0].field == "finalMultiplier" \
		and not trace_orb.is_empty() and trace_orb[0].ops[0].field == "finalAdd", [orb_on, trace_orb])
	# 5. 种族祝福：出伤乘改 ＋q 进③；只对物理（魔族）的按伤害方式折（对口全额、混合一半、不对口 0）；爆伤、防御率照旧
	var mk := func(race: int, mode: String, pooled: bool, extra := {}):
		var f := {"race": race, "q": 0.2, "blood": true, "divine": false, "weapon": true, "hunter": true, "low": true, "counter": true, "pooled": pooled}
		f.merge(extra, true)
		return XRaceBattle.build({"facts": {"race": f}, "item": {"damage": {"type": 1}}}, {"kind": "normal", "mode": mode}).ops
	var sum_add := func(ops: Array, field: String) -> float:
		var v := 0.0
		for o in ops:
			if o.field == field and o.op == "add":
				v += float(o.value)
		return v
	var demon_p: Array = mk.call(3, "physical", true)
	var demon_m: Array = mk.call(3, "magical", true)
	var demon_x: Array = mk.call(3, "mixed", true)
	var demon_old: Array = mk.call(3, "physical", false)
	var no_mul := demon_p.all(func(o): return not XTianqiLedger.is_mul(o))
	_check("p2_race_demon", no_mul and is_equal_approx(sum_add.call(demon_p, "finalAdd"), 0.3) and is_equal_approx(sum_add.call(demon_m, "finalAdd"), 0.0) \
		and is_equal_approx(sum_add.call(demon_x, "finalAdd"), 0.15) and is_equal_approx(sum_add.call(demon_p, "criticalAdd"), 0.1) \
		and demon_old.filter(func(o): return o.field == "physicalDamageMultiplier").size() == 2, [demon_p, demon_x, demon_old])
	var hunter: Array = mk.call(1, "physical", true)
	_check("p2_race_hunter", is_equal_approx(sum_add.call(hunter, "finalAdd"), 0.2) and hunter.any(func(o): return o.field == "physicalDefenseRate") and hunter.all(func(o): return not XTianqiLedger.is_mul(o)), hunter)
	_check("p2_race_counter_weapon", is_equal_approx(sum_add.call(mk.call(6, "physical", true), "finalAdd"), 0.3) and is_equal_approx(sum_add.call(mk.call(5, "physical", true), "finalAdd"), 0.2))
	var god_m: Array = mk.call(0, "magical", true)
	_check("p2_race_god", is_equal_approx(sum_add.call(god_m, "finalAdd"), 0.2) and is_equal_approx(sum_add.call(mk.call(0, "physical", true), "finalAdd"), 0.0), god_m)
	# 6. 原版套装状态「结果 ×k」（红魔套装 3 件 → 铁头娃II 713 ×2）：打敌人 ＋1 进③、确认阶段那一步对敌人不乘；治疗、打自己人照旧 ×2
	var b := s.actor(int(s.battle_slots[1]))
	b.change_level(40)
	var slots := b.equip_slots()
	for id in [4184, 4185, 4186]:
		var eq := XActor.make_equip("armor", id)
		var at := slots.find(int(eq.etypeId))
		if at >= 0:
			b.equips[at] = eq
	b.read_touch()
	b.refresh_passive()
	b.effect_snapshot_valid = false  # 换装在战斗外；测试里当场换，清掉状态效果快照
	b.effect_lists = {}
	var has713 := b.states().any(func(st): return int(st.id) == 713)
	var hit := XDB.rec("Skills", 1)
	var res := XDamage.calculate(hit, b, e, {"critical": false, "variance": false})
	var fin_on := XDamage.finish(res, hit, b, e, false)
	XTianqiLedger.POOL_SUIT = false
	var res_off := XDamage.calculate(hit, b, e, {"critical": false, "variance": false})
	var fin_off := XDamage.finish(res_off, hit, b, e, false)
	XTianqiLedger.POOL_SUIT = true
	var heal := XStateEffects.run("confirm", b, {"attacker": b, "defender": e, "item": XDB.rec("Skills", 1).merged({"damage": {"type": 3}}, true), "value": -100.0, "execute": false})
	var self_hit := XStateEffects.run("confirm", b, {"attacker": b, "defender": a, "item": hit, "value": 100.0, "execute": false})
	_check("p2_suit_confirm", has713 and is_equal_approx(XTianqiLedger.suit_confirm_add(b, e, 1), 1.0) and is_equal_approx(float(res.breakdown.row.terminal), float(res_off.breakdown.row.terminal) + 1.0) \
		and fin_off > float(res_off.value) * 1.9 and absf(fin_on - float(res.value)) <= 1.0 and heal <= -200.0 and self_hit >= 200.0, [has713, res.breakdown.row.terminal, res_off.breakdown.row.terminal, res.value, fin_on, res_off.value, fin_off, heal, self_hit])
	# 7. 万灵增元丹类被动（5974～5977）：天启篇不挂开战状态；西游档照挂
	var p := s.actor(int(s.battle_slots[2]))
	p.learn_skill(5975)
	var tags_on := p.battle_start_state_tags().filter(func(t): return int(t[1]) == 1287)
	XTianqiLedger.NO_PILL_PASSIVES = false
	var tags_off := p.battle_start_state_tags().filter(func(t): return int(t[1]) == 1287)
	XTianqiLedger.NO_PILL_PASSIVES = true
	_check("p2_pill_passive_skipped", tags_on.is_empty() and tags_off.size() == 1, [tags_on, tags_off])
	# 8. 暴击 ＋50%、敏捷 ×0.8：读 combat_rules（改表就跟着变），关开关回到 legacy_passive，两处数一样
	var rules: Dictionary = XTianqiBalance.data().combat_rules
	var legacy: Dictionary = XTianqiBalance.data().legacy_passive
	_check("p2_combat_rules_same_numbers", float(rules.crit_add) == float(legacy.crit_add) and float(rules.agi_rate) == float(legacy.agi_rate) and float(rules.crit_add) == 0.5)
	rules.crit_add = 0.4
	var c_rules := XTianqiNoDiffPassive.xparam_add(a, XTianqiNoDiffPassive.CRIT)
	XTianqiLedger.COMBAT_RULES = false
	var c_legacy := XTianqiNoDiffPassive.xparam_add(a, XTianqiNoDiffPassive.CRIT)
	XTianqiLedger.COMBAT_RULES = true
	rules.crit_add = 0.5
	_check("p2_combat_rules_read", is_equal_approx(c_rules, 0.4) and is_equal_approx(c_legacy, 0.5), [c_rules, c_legacy])
	# 9. 七印：真打一下（守卫不报）在七印测试 xiyou_tianqi_qiyin_effects 里逐条核；这里核「归池后七印不再写单独相乘」的登记口径
	_check("p2_qiyin_row", XTianqiLedger.check("qiyin", "finalMultiplier") == "pooled" and XTianqiLedger.check("qiyin_derived", "finalMultiplier") == "")
	# 期二全部开着，上面真打的各下都没报违规
	_check("p2_real_hits_clean", XTianqiLedger.violations.is_empty(), XTianqiLedger.violations.slice(0, 5))


# ---- 九、敌方链路分链验证 ----
func _enemy_chains() -> void:
	var s := _state([])
	var a := s.actor(int(s.battle_slots[0]))
	var a2 := s.actor(int(s.battle_slots[1]))
	a.change_level(40)
	var e := XEnemy.new().setup(1, 3, 100.0)
	var hit := XDB.rec("Skills", 1)
	var both := func(f: Callable) -> Array:
		XTianqiLedger.set_all_p2(true)
		var x = f.call()
		XTianqiLedger.set_all_p2(false)
		var y = f.call()
		XTianqiLedger.set_all_p2(true)
		return [x, y]
	# (1) 元素反射／魔法反射：原版把这一招打回出手者自己——我方打我方，走我方的伤害帧（守卫照管）；七印、套装、对某族增伤只算打敌人，这里一条都不进
	var refl: Array = both.call(func(): return _calc(a, a2).value)
	XTianqiLedger.violations.clear()
	_calc(a, a2)
	_check("chain_element_reflect", refl[0] == refl[1] and XTianqiLedger.violations.is_empty() and XTianqiLedger.auditing(a), refl)
	# (2) 敌人状态 React 反伤（381 反伤属性）：数额从这一下我方伤害（已过五池、已去 ×6）来，是敌方出伤；同一个输入值，开关开关一样
	var react: Array = both.call(func():
		e.add_state(381)
		var hp0 := a.hp
		var v := XStateEffects.run("react", e, {"attacker": a, "defender": e, "item": hit, "value": 1000.0, "execute": false})
		e.remove_state(381)
		return [v, hp0 - a.hp])
	_check("chain_state_react", react[0] == react[1] and not XTianqiLedger.auditing(e), react)
	# (3) 技能卡状态反弹（XTianqiSkills._reflect）：我方按敌人这一下的伤害比例打回敌人；不过伤害帧、不吃我方池，开关开关一样（要不要进③待设计稿定）
	var cards := XTianqiSkills.CARDS
	XTianqiSkills.CARDS = true
	var card: Array = both.call(func():
		e.hp = e.mhp
		XTianqiSkills._reflect(e, a, {"hp": 500.0})
		return e.hp)
	XTianqiSkills.CARDS = cards
	_check("chain_card_reflect", card[0] == card[1], card)
	# (4) 敌源按生命上限比例状态（中毒 4：hrg −10%）：floor(mhp × hrg × rec)，不过伤害帧、不吃任何池、不跟去 ×6 缩
	a.add_state(4)
	var regen: Array = both.call(func(): return floorf(a.mhp * a.hrg * a.rec))
	a.remove_state(4)
	_check("chain_enemy_mhp_state", regen[0] == regen[1] and regen[0] < 0.0, regen)
	# 守卫只管我方出手（敌人打我方不进）
	_check("chain_guard_enemy_skipped", not XTianqiLedger.auditing(e))
