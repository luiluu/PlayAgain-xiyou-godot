extends Node
## 【cc·T130】天启篇期四开卡前（基础数值重构 v0.4 第七节第 5、6 条，第十节 T012-b 第 6、7 条；T105 并入）：
## 一、15 个专属模块钩子的收口矩阵：每个钩子 ×「普攻、没改写的技能、派生」三种情形 ×「总开关关、开且在白名单、开且不在白名单」三种状态，
##     增伤乘区关着原样、开着默认拦、白名单才放；无视防御夹到 0.7（开着）。
## 二、运行期夹具：总开关开着（卡跟着开），模块角色学满模块技能，直接调＋真打，把每个钩子实际产出的增伤操作全打出来（P4MOD_BOOST 行，交付单附表照它），
##     每一条都要在 damage_ledger.json phase4.module_review 里有初审结论；结论是留的，phase4.module_whitelist 里要有对应行，反过来也一样。
## 三、模块派生 7 行（phase4.derived_module）：真打量「每回合最多几次、每次是原招的几成」（P4DERIVED 行），口子 take_module_derived：
##     关着恒真、不记数；开着只认 enforced 的行、每回合到 per_turn 就拦；登记成 enforced 的行 per_turn×ratio 不超过 1.0。
##     T137：basis per_target＝比例按每个敌人算（镜流、流萤：卡上写的群体系数）；own_action＝璇棱光是她自己那次出手（附身中她只防御）；
##     璇按触发它的宿主那次行动量（take_module_derived 的 trigger）；屠苏分段卡开着不加伤、不登记。夹具钉了本场随机数（量到的数不再每跑一次都漂）。
## 四、开卡前的口子：白起 full_again 过回合预算（总开关开着）；卡改写的 8 把专属武器攻击次数 +1 不被九线停用误停、关着照旧停；
##     段数来源只剩词条「连击」、红印「多段连击」、卡改写专属武器三类；D175（Kyo 11-17）：每一件来源最多 +2，合计不封顶。
## 五（T137）：黑闪天启篇（甚尔爆伤 +30%、觉醒 2 回合；五条悟 +30% 待拍板；宿傩不加）；屠苏卡开着不分摊、分段不加伤；
##     镜流 10190 没别的活敌不扣派生；璇棱光口子在 _cast 查完之后、按 own_action 口径（附身中她自己只防御）。
## 读的表：tianqi_data/damage_ledger.json（phase4）、skill_rework.json（gear、actors.80 charge）、affix_table.json、qiyin_gear.json。

const MODULE_ACTORS := {"module.raven": 167, "module.number_boost": 168, "module.mira": 168, "module.sukuna": 172, "module.yomi_jingliu": 169,
	"module.toji": 171, "module.toji_incoming": 171, "module.garou": 173, "module.yunshang": 174, "module.black_flash": 172,
	"module.xuan_cast": 177, "module.xuan_incoming": 177, "module.xuan_damage": 177, "module.tusu": 176, "module.liuying": 179}
const MODULE_FILES := {167: "raven", 168: "mira", 169: "yomi_jingliu", 170: "yomi_jingliu", 171: "toji", 172: "sukuna", 173: "garou", 174: "yunshang",
	176: "tusu", 177: "xuan_battle", 179: "liuying"}
## 派生情形用的技能号：模块内部再打一下的那一招（甚尔武器库游云、饿狼神杀瞬击），其余借普攻号
const DERIVED_SKILL := {171: 10220, 173: 10258}
const DERIVED_SOURCES := ["module.toji.armory", "module.garou.follow", "module.xuan.follow_up", "module.jingliu.segment", "module.yunshang.derived",
	"module.liuying.segment", "module.tusu.segments"]
const EXCLUSIVE := [2005, 2006, 2007, 1529, 1546, 1694, 1696, 4003]
const TROOP := 77  # 四个同级小怪（扩散、分光要有别的敌人）

var results: Array = []
var boosts := {}  # "tag|field" → {skills, values, scens}
var trace_rows: Array = []
var measured := {}  # 派生来源 → 夹具量到的 {max_turn, mean, coef}


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XTianqi.JOIN_GIFTS = false  # T398：夹具要不带入队赠品的光身角色（赠品装备另有专项 xiyou_tianqi_join_gifts）
	XMessageBox.auto = true
	seed(20261117)
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XTianqiLedger.reload_table()
	XGojo.unlock_override = 0
	_check("default_on", XTianqiBase.PHASE4 and not XTianqiSkills.CARDS and XTianqiLedger.TRACE == null, [XTianqiBase.PHASE4, XTianqiSkills.CARDS])  # T220 翻开关
	# T220（T012-c）：期四总开关、熟练度默认开了；本专项是总开关关着时写的（原版量级、K 按 1、治疗 ×5、CARDS 单独隔离卡），照原条件拨回关跑
	XTianqiBase.PHASE4 = false
	XTianqiSkills.MASTERY = false
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	_cap_matrix()
	_fixture_direct()
	_fixture_battles()
	_review_table()
	_derived_rows()
	_derived_gate()
	_full_again()
	_exclusive_weapons()
	_hit_sources()
	_black_flash_tq()
	_tusu_tq()
	_jingliu_no_other()
	_xuan_gate()
	_suit_524()
	XTianqiBase.PHASE4 = false
	XTianqiSkills.CARDS = false
	XTianqiLedger.TRACE = null
	XActorDamageHooks.RECORD = null
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(extra: Array, difficulty := "jiusi") -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, difficulty, lineup)
	XTianqi.take_pending()
	for id in lineup + extra:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _module_skills(actor_id: int) -> Array:
	var f := FileAccess.open("res://modes/xiyou/core/%s.gd" % MODULE_FILES.get(actor_id, "raven"), FileAccess.READ)
	var ids := {}
	for m in RegEx.create_from_string("\\b(10\\d{3})\\b").search_all(f.get_as_text()):
		var id := int(m.get_string(1))
		var rec := XDB.rec("Skills", id)
		if not rec.is_empty() and int(rec.get("damage", {}).get("type", 0)) in [1, 5]:
			ids[id] = true
	if actor_id in [176, 177]:
		for id in XTusuXuan.keys(actor_id):
			var rec := XDB.rec("Skills", int(id))
			if not rec.is_empty() and int(rec.get("damage", {}).get("type", 0)) in [1, 5]:
				ids[int(id)] = true
	var out := ids.keys()
	out.sort()
	return out


static func _boost(o: Dictionary) -> bool:
	var f := str(o.get("field", ""))
	var k := str(o.get("op", ""))
	return (k == "mul" and f in ["finalMultiplier", "skillMultiplier", "settlementMultiplier"] and float(o.get("value", 1.0)) > 1.0) \
		or (k == "add" and f in ["finalAdd", "normalAdd", "elementAdd", "criticalAdd"] and float(o.get("value", 0.0)) > 0.0)


func _p4() -> Dictionary:
	return XTianqiBase.ledger_phase4()


# ---- 一、收口矩阵 ----
func _cap_matrix() -> void:
	var s := _state(MODULE_ACTORS.values())
	var ops := [{"op": "mul", "field": "finalMultiplier", "value": 1.5}, {"op": "add", "field": "finalAdd", "value": 0.3},
		{"op": "mul", "field": "physicalDefenseRate", "value": 0.5}, {"op": "mul", "field": "incomingMultiplier", "value": 0.8}]
	var wl: Array = _p4().get("module_whitelist", [])
	var saved := wl.duplicate(true)
	wl.clear()  # 矩阵按「表里没有」量；表里实际放了什么在第二节对
	for tag in XActorDamageHooks.MODULE_TAGS:
		var aid := int(MODULE_ACTORS[tag])
		var a := s.actor(aid)
		var plain := _module_skills(aid).filter(func(id): XTianqiSkills.CARDS = true; var h := XTianqiSkills.has(int(id)); XTianqiSkills.CARDS = false; return not h)
		var scen := {"普攻": 1, "没改写": int(plain[0]) if not plain.is_empty() else 3, "派生": int(DERIVED_SKILL.get(aid, 1))}
		for sc in scen:
			var item := XDB.rec("Skills", int(scen[sc]))
			XTianqiBase.PHASE4 = false
			var off := XTianqiSkills.module_ops(item, a, ops.duplicate(true), tag)
			XTianqiBase.PHASE4 = true
			var on_block := XTianqiSkills.module_ops(item, a, ops.duplicate(true), tag)
			wl.append({"module": tag, "skill": int(scen[sc]), "field": "finalMultiplier", "reason": "矩阵"})
			var on_wl := XTianqiSkills.module_ops(item, a, ops.duplicate(true), tag)
			var other := XTianqiSkills.module_ops(item, a, ops.duplicate(true), "module.raven" if tag != "module.raven" else "module.toji")
			wl.clear()
			XTianqiBase.PHASE4 = false
			var ok_off: bool = off == ops
			var ok_block: bool = on_block.size() == 2 and on_block[0].field == "physicalDefenseRate" and is_equal_approx(float(on_block[0].value), 0.7) and on_block[1].field == "incomingMultiplier"
			var ok_wl: bool = on_wl.size() == 3 and on_wl[0].field == "finalMultiplier" and other.size() == 2
			_check("cap.%s.%s" % [tag, sc], ok_off and ok_block and ok_wl, {"skill": scen[sc], "off": ok_off, "block": on_block, "wl": on_wl})
	wl.append_array(saved)
	XTianqiBase.PHASE4 = false


# ---- 二、运行期夹具：直接调 ----
func _note(tag: String, scen: String, id: int, raw: Array) -> void:
	for o in raw:
		if not _boost(o):
			continue
		var k := "%s|%s" % [tag, o.field]
		var row: Dictionary = boosts.get(k, {"skills": {}, "values": {}, "scens": {}})
		row.skills[id] = true
		row.values[snappedf(float(o.value), 0.0001)] = true
		row.scens[scen] = true
		boosts[k] = row


func _fixture_direct() -> void:
	var actors := [167, 168, 169, 170, 171, 172, 173, 174, 176, 177, 179]
	XTianqiBase.PHASE4 = true
	var s := _state(actors)
	var b := XEnemy.new().setup(1, 3, 100.0)
	for aid in actors:
		var a := s.actor(int(aid))
		a.change_level(99)
		var ids := [1] + _module_skills(aid)
		for id in ids:
			if int(id) > 2:
				a.learn_skill(int(id))
		for id in ids:
			var item := XDB.rec("Skills", int(id))
			var parts := XActorDamageHooks.module_parts(item, a, b)
			var scen := "普攻" if int(id) == 1 else ("改写" if XTianqiSkills.has(int(id)) else "没改写")
			for i in XActorDamageHooks.MODULE_TAGS.size():
				_note(XActorDamageHooks.MODULE_TAGS[i], scen, int(id), parts[i])
	XTianqiBase.PHASE4 = false


# ---- 二、三：真打（派生只有打起来才有）----
func _usable(logic, u) -> Array:
	var out := []
	for id in [1] + _module_skills(int(u.actor_id)):
		var sk := XDB.rec("Skills", int(id))
		if not sk.is_empty() and u.skill_ids.has(int(id)) or int(id) == 1:
			if logic.can_use(u, sk):
				out.append(sk)
	return out


func _battle(aid: int, rounds := 12) -> Dictionary:
	XTianqiBase.PHASE4 = true
	var s := _state([] if aid in [169, 170, 176, 177, 179] else [aid])
	XTianqi._joining = true  # 专属法宝给技能类型：照各模块自己的入队（装专属物）
	if aid in [176, 177]:
		XTusuXuan.recruit(s, aid)
	elif aid in [169, 170]:
		XYomiJingliu.recruit(s, aid)
	elif aid == 179:
		XLiuying.recruit(s)
	XTianqi._joining = false
	s.actor_advance[aid] = 6  # 进阶满（甚尔武器库、镜流进阶行等要进阶过）
	var slots := s.battle_slots.duplicate()
	slots[0] = aid
	s.battle_slots = slots
	var a := s.actor(aid)
	a.change_level(99)
	for id in _module_skills(aid):
		a.learn_skill(int(id))
	for id in [10211, 10266, 10267, 10268]:  # 甚尔武器库、饿狼进化／解析／追击被动（学了才开）
		if XDB.rec("Skills", id).size() > 0 and not a.skill_ids.has(id) and (aid == 171 and id == 10211 or aid == 173 and id >= 10266):
			a.learn_skill(id)
	_fit_weapon(a)
	if aid == 176:
		var relic := XGear.template("armor", int(XTusu.RELIC))
		if not relic.is_empty():
			a.equips[maxi(0, int(XDB.rec("Armors", int(XTusu.RELIC)).get("etypeId", 5)) - 1)] = relic
	a.recover_all()
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s, XBattleRandom.create(XRandomStream.hex64(20261117 * 7 + aid)))  # T137：钉住本场随机数（原来每跑一次都不同，量到的数会漂，饿狼合计偶尔过 1.0）
	for e in logic.enemies:
		e._rates[0] *= 1000
		e.recover_all()
	logic.auto = true
	if aid in [176, 177]:
		var host = logic.actors.filter(func(x): return x != a)[0]
		XBinding.bind(a, host)
		if aid == 177 and not XXuanBattle.data.is_empty():
			XXuanBattle.data.auto = true
	var picks := {}
	var own_turns := []
	XTianqiLedger.TRACE = []
	XActorDamageHooks.RECORD = []
	var main := {"dmg": 0.0, "acts": 0}
	var pick := 0
	var bind_host = logic.actors.filter(func(x): return x != a)[0] if aid == 177 else null
	if bind_host != null:
		bind_host.change_level(99)  # 和璇同级（「是原招的几成」按宿主那下算，宿主太弱比例没意义）
		_fit_weapon(bind_host)
		bind_host.add_param(0, 1e9)  # 宿主是弱者，一回合就被打死、解附身（death-host）；夹具只量棱光，给宿主堆血
		bind_host.refresh_passive()
		bind_host.recover_all()
	for _round in rounds:
		if bind_host != null:
			a.mp = a.mmp
			a.tp = a.max_tp()
		if bind_host != null and not XBinding.is_bound(a) and a.is_alive() and bind_host.is_alive():
			XBinding.bind(a, bind_host)  # T137：璇附身着才有棱光（宿主主动攻击后），解了就重新附身
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		while count < 80:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			if u == a and bind_host == null:  # 璇附身时照她自己的自动（夹具硬选招会把附身解掉，棱光就没了）
				a.mp = a.mmp
				a.tp = a.max_tp()
				var pool := _usable(logic, a)
				if not pool.is_empty():
					cmd = [pool[pick % pool.size()], null]
					pick += 1
				picks[int(cmd[0].id)] = int(picks.get(int(cmd[0].id), 0)) + 1
			XActorDamageHooks.RECORD_ACT = {"subject": u, "skill": int(cmd[0].id) if cmd[0] != null else -1}
			var n0: int = (XTianqiLedger.TRACE as Array).size()
			var hp0 := XTianqiLedger._foe_hp(logic)
			if bind_host != null and XBinding.data(a) != null:
				XBinding.data(a).charges = maxi(int(XBinding.data(a).charges), 3)  # 棱光要 2 点星契（_can_spend；只有一次行动的璇平时攒不到），夹具每次行动前补满只量比例
			var own_bound := bind_host != null and u == a and XBinding.is_bound(a)
			logic.act(u, cmd[0], cmd[1])
			if own_bound:  # T137 own_action 口径的前提：附身中的璇自己那一回合只能防御、不出伤害（星契就是她这次行动换的）
				own_turns.append({"skill": int(cmd[0].id) if cmd[0] != null else -1, "drop": hp0 - XTianqiLedger._foe_hp(logic)})
			if u is XActor:
				var drop := hp0 - XTianqiLedger._foe_hp(logic)
				for i in range(n0, (XTianqiLedger.TRACE as Array).size()):
					var r: Dictionary = XTianqiLedger.TRACE[i]
					if int(r.actor) == aid and float(r.hp1) >= 0.0 and str(r.source) != "module.tusu.segments" and not _nested(XTianqiLedger.TRACE, n0, i):
						drop -= float(r.hp0) - float(r.hp1)
				drop = maxf(drop, 0.0)
				for i in range(n0, (XTianqiLedger.TRACE as Array).size()):
					var r: Dictionary = XTianqiLedger.TRACE[i]
					# 触发它的那次行动的主伤害（「是原招的几成」的分母）：本人行动里触发的按本人；替别人出手的（璇棱光，T137）按 trigger 那人这次行动
					if u == a and int(r.get("trigger", 0)) == 0 or int(r.get("trigger", 0)) == int(u.actor_id) and u != a:
						r["act_main"] = drop
				if u == a:
					main.dmg = float(main.dmg) + drop
					main.acts = int(main.acts) + 1
		logic.end_turn()
		for e in logic.enemies:
			if e.is_alive():
				e.hp = e.mhp
		if logic.is_over():
			break
	print("P4BATTLE|%d|上场%s|出招%s|派生%d" % [aid, str(logic.actors.map(func(x): return x.actor_id)), JSON.stringify(picks), (XTianqiLedger.TRACE as Array).size()])
	var tr: Array = XTianqiLedger.TRACE
	var rec: Array = XActorDamageHooks.RECORD
	XTianqiLedger.TRACE = null
	XActorDamageHooks.RECORD = null
	XActorDamageHooks.RECORD_ACT = {}
	for r in rec:
		if bool(r.derived):
			_note(str(r.tag), "派生", int(r.skill), r.ops)
		elif int(r.skill) == 1:
			_note(str(r.tag), "普攻", int(r.skill), r.ops)
		else:
			_note(str(r.tag), "改写" if XTianqiSkills.has(int(r.skill)) else "没改写", int(r.skill), r.ops)
	XTianqiBase.PHASE4 = false
	return {"actor": aid, "trace": tr, "main": main, "own_turns": own_turns}


func _fixture_battles() -> void:
	for aid in [167, 168, 169, 170, 171, 172, 173, 174, 176, 177, 179]:
		var r := _battle(aid, 30 if aid in [170, 171, 177] else 12)  # T137：触发少的（镜流追加段、甚尔武器库、璇棱光）多打几回合
		trace_rows.append(r)
	# 每个来源：触发次数、每回合每人最多几次、每次是原招的几成（派生伤害 ÷ 本人一次行动的主伤害）、每回合合计
	var by := {}
	for r in trace_rows:
		var avg := float(r.main.dmg) / maxf(1.0, float(r.main.acts))
		var per_turn := {}
		var coef_turn := {}
		for i in (r.trace as Array).size():
			var t: Dictionary = r.trace[i]
			if _nested(r.trace, 0, i):
				continue  # 派生里套的派生（甚尔武器库里的溅射、云裳子行动）算进外层那一次
			var src := str(t.source)
			var row: Dictionary = by.get(src, {"n": 0, "denied": 0, "max_turn": 0, "ratios": [], "coef": 0.0, "actors": {}})
			row.n = int(row.n) + 1
			if not bool(t.ok):
				row.denied = int(row.denied) + 1
			var key := "%d|%d" % [int(t.turn), int(t.actor)]
			var pt: Dictionary = per_turn.get(src, {})
			pt[key] = int(pt.get(key, 0)) + 1
			per_turn[src] = pt
			var base := float(t.get("act_main", -1.0))
			if base <= 0.0:
				base = avg  # 不在本人行动里触发的（饿狼反击、云裳守势反击）：按本人一次行动的平均主伤害
			if float(t.hp1) >= 0.0 and base > 0.0:
				var d := float(t.hp0) - float(t.hp1)
				if src == "module.tusu.segments":
					d *= 0.2 / 1.2  # 分段打的是整招 ×1.2，多出来的是 0.2（T137 起卡开着不分段加伤、不走口子，量不到）
				if _per_target(src):
					d /= maxf(1.0, float(t.get("targets", 1)))  # T137 basis per_target：每个敌人多吃几成
				(row.ratios as Array).append(d / base)
				var ct: Dictionary = coef_turn.get(src, {})
				ct[key] = float(ct.get(key, 0.0)) + d / base
				coef_turn[src] = ct
			row.actors[int(t.actor)] = true
			by[src] = row
		for src in per_turn:
			var pt: Dictionary = per_turn[src]
			for k in pt:
				by[src].max_turn = maxi(int(by[src].max_turn), int(pt[k]))
			for k in coef_turn.get(src, {}):
				by[src].coef = maxf(float(by[src].coef), float(coef_turn[src][k]))
	for src in DERIVED_SOURCES:
		var row: Dictionary = by.get(src, {})
		var ratios: Array = row.get("ratios", [])
		var mean := 0.0
		var top := 0.0
		for x in ratios:
			mean += float(x)
			top = maxf(top, float(x))
		mean = mean / ratios.size() if not ratios.is_empty() else 0.0
		print("P4DERIVED|%s|触发%d|拦%d|每回合最多%d次|每次平均%.3f|每次最高%.3f|每回合合计最高%.3f" % [src, int(row.get("n", 0)), int(row.get("denied", 0)),
			int(row.get("max_turn", 0)), mean, top, float(row.get("coef", 0.0))])
		measured[src] = {"max_turn": int(row.get("max_turn", 0)), "mean": mean, "coef": float(row.get("coef", 0.0))}
	# 璇 own_action 口径（T137，协调 11-17）：附身中她自己那一回合只防御、不出伤害，棱光（花星契＝她本回合的行动）就是她唯一的输出
	var xr: Array = trace_rows.filter(func(r): return int(r.actor) == 177)
	var own: Array = xr[0].own_turns if not xr.is_empty() else []
	_check("xuan_bound_turn_guard_only", not own.is_empty() and own.all(func(t): return int(t.skill) == XBattleLogic.GUARD_SKILL and float(t.drop) <= 0.0), own)
	# 棱光每一次真打出了伤害（口子在 _cast 查完星契、冷却之后才问，不会白扣次数）
	var lg: Array = (xr[0].trace as Array).filter(func(t): return str(t.source) == "module.xuan.follow_up" and int(t.trigger) != 177) if not xr.is_empty() else []  # 跟攻（触发者是宿主）；同轨、回合末那两条（T082 补的门控，触发者记璇自己）先问口子再判，另有断言
	# T082：同轨协同先用掉本回合次数时跟攻被拦（ok 假、不掉血），放出来的每次都真打出伤害
	_check("xuan_gate_after_cast", lg.any(func(t): return bool(t.ok)) and lg.all(func(t): return float(t.hp0) > float(t.hp1) if bool(t.ok) else float(t.hp0) == float(t.hp1)), lg.size())
	_check("fixture_battle_traced", trace_rows.any(func(r): return not (r.trace as Array).is_empty()), trace_rows.map(func(r): return [r.actor, (r.trace as Array).size(), r.main]))
	var seen_sources := by.keys()
	print("P4DERIVED_SEEN=" + JSON.stringify(seen_sources))
	_check("fixture_sources_known", seen_sources.all(func(k): return DERIVED_SOURCES.has(k)), seen_sources)
	# 登记成强制执行的行：真打里没有一回合超过 per_turn（口子真的拦住了）
	var over := []
	for r in _p4().get("derived_module", []):
		if not bool(r.get("enforced", false)):
			continue
		var ok_turn := {}
		for row in trace_rows:
			for t in row.trace:
				if str(t.source) == str(r.id) and bool(t.ok):
					var key := "%d|%d" % [int(t.turn), int(t.actor)]
					ok_turn[key] = int(ok_turn.get(key, 0)) + 1
		for k in ok_turn:
			if int(ok_turn[k]) > int(r.per_turn):
				over.append([r.id, k, ok_turn[k]])
		# 强制执行的行：夹具这一轮量到的每回合合计不超过 1.0（own_action 的不按宿主比：棱光就是璇自己那次出手，T137）
		if str(r.get("basis", "")) != "own_action" and float(measured.get(str(r.id), {}).get("coef", 0.0)) > 1.0:
			over.append([r.id, "coef", measured[str(r.id)].coef])
	_check("fixture_enforced_within", over.is_empty(), over)


## 表里 basis 是 per_target 的行（T137：卡上写成「其他敌人各吃几成」的群体扩散），比例按每个敌人算
func _per_target(src: String) -> bool:
	for r in _p4().get("derived_module", []):
		if str(r.get("id", "")) == src:
			return str(r.get("basis", "")) == "per_target"
	return false


# ---- 二：白名单初审表 ----
func _review_table() -> void:
	var keys := boosts.keys()
	keys.sort()
	for k in keys:
		var row: Dictionary = boosts[k]
		var sk: Array = row.skills.keys()
		sk.sort()
		var vals: Array = row.values.keys()
		vals.sort()
		print("P4MOD_BOOST|%s|%s|技能%s|值%s" % [k, ",".join(row.scens.keys()), JSON.stringify(sk), JSON.stringify(vals)])
	_check("fixture_boosts_found", not boosts.is_empty(), boosts.size())
	var review: Array = _p4().get("module_review", [])
	var missing := []
	for k in keys:
		var parts := str(k).split("|")
		if not review.any(func(r): return str(r.get("module", "")) == parts[0] and str(r.get("field", "")) == parts[1] and str(r.get("reason", "")) != "" and r.has("keep")):
			missing.append(k)
	_check("review_covers_fixture", missing.is_empty(), missing)
	var no_row: Array = XActorDamageHooks.MODULE_TAGS.filter(func(t): return not review.any(func(r): return str(r.get("module", "")) == t))
	_check("review_every_hook", no_row.is_empty(), no_row)
	# 留的才进白名单，白名单里每一行都有留的初审
	var wl: Array = _p4().get("module_whitelist", [])
	var keep_rows := review.filter(func(r): return bool(r.get("keep", false)))
	var wl_bad := wl.filter(func(w): return not keep_rows.any(func(r): return str(r.module) == str(w.get("module")) and str(r.field) == str(w.get("field"))) or str(w.get("reason", "")) == "")
	var keep_bad := keep_rows.filter(func(r): return not wl.any(func(w): return str(w.get("module")) == str(r.module) and str(w.get("field")) == str(r.field)))
	_check("whitelist_matches_review", wl_bad.is_empty() and keep_bad.is_empty(), [wl_bad, keep_bad])
	# 旧键 module_whitelist 不动（期一期三的守卫照它）
	_check("old_whitelist_untouched", (XTianqiLedger.data().get("module_whitelist", []) as Array).is_empty())
	# 开着才读新白名单：表里有的一行，关着（卡单开）拦、开着放。T137：新白名单空着时临时塞一行试（原来空表就跳过，这条断言等于没有）
	var probe_wl: Array = XTianqiBase.ledger_phase4().get("module_whitelist", [])
	var injected := probe_wl.is_empty()
	if injected:
		probe_wl.append({"module": "module.raven", "skill": 10122, "field": "finalMultiplier", "reason": "T137 专项临时行"})
	if true:
		var w: Dictionary = probe_wl[0]
		var s := _state([int(MODULE_ACTORS.get(str(w.module), 167))])
		var a := s.actor(int(MODULE_ACTORS.get(str(w.module), 167)))
		var op := [{"op": "mul" if str(w.field).ends_with("Multiplier") else "add", "field": str(w.field), "value": 1.5}]
		var item := XDB.rec("Skills", int(w.get("skill", 0)) if int(w.get("skill", 0)) > 0 else 1)
		XTianqiSkills.CARDS = true
		var cards_only := XTianqiSkills.module_ops(item, a, op.duplicate(true), str(w.module))
		XTianqiSkills.CARDS = false
		XTianqiBase.PHASE4 = true
		var on := XTianqiSkills.module_ops(item, a, op.duplicate(true), str(w.module))
		XTianqiBase.PHASE4 = false
		if injected:
			probe_wl.clear()
		_check("whitelist_phase4_only", cards_only.is_empty() and on.size() == 1, [w, cards_only, on, injected])


# ---- 三：派生 7 行的登记 ----
func _derived_rows() -> void:
	var rows: Array = _p4().get("derived_module", [])
	_check("derived_rows_seven", rows.size() == 7 and DERIVED_SOURCES.all(func(k): return rows.any(func(r): return str(r.get("id")) == k)), rows.map(func(r): return r.get("id")))
	var bad := []
	for r in rows:
		var filled: bool = r.get("per_turn") != null and r.get("ratio") != null
		if bool(r.get("enforced", false)):
			if not filled or float(r.per_turn) * float(r.ratio) > 1.0 + 1e-9:
				bad.append([r.id, "enforced 但没填或合计超过 1.0"])
		elif str(r.get("note", "")).contains("留空"):
			bad.append([r.id, "还是留空"])
		if not bool(r.get("enforced", false)) and not str(r.get("note", "")).contains("不登记，理由"):
			bad.append([r.id, "不登记要写理由"])
		if r.has("basis") and not str(r.basis) in ["per_target", "own_action"]:
			bad.append([r.id, "basis 只认 per_target、own_action", r.basis])
	_check("derived_rows_filled", bad.is_empty(), bad)
	# T137：4 行（镜流、流萤、璇、屠苏）有结论：前三行登记强制执行，屠苏卡开着不是派生、写理由不登记
	var want := {"module.jingliu.segment": ["per_target", true], "module.liuying.segment": ["per_target", true], "module.xuan.follow_up": ["own_action", true], "module.tusu.segments": ["", false]}
	var got := {}
	for r in rows:
		if want.has(str(r.id)):
			got[str(r.id)] = [str(r.get("basis", "")), bool(r.get("enforced", false))]
	_check("derived_four_settled", got == want, got)


func _derived_gate() -> void:
	var s := _state([171])
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var u = logic.actors[0]
	var rows: Array = _p4().derived_module
	var saved := rows.duplicate(true)
	rows.clear()
	rows.append({"id": "module.toji.armory", "per_turn": 1, "ratio": 0.5, "enforced": true})
	rows.append({"id": "module.garou.follow", "per_turn": 1, "ratio": 0.5, "enforced": false})
	XTianqiBase.PHASE4 = false
	var off := [XTianqiLedger.take_module_derived(logic, u, "module.toji.armory"), XTianqiLedger.take_module_derived(logic, u, "module.toji.armory")]
	var off_clean: bool = not logic.has_meta(XTianqiLedger.BUDGET_META) or (logic.get_meta(XTianqiLedger.BUDGET_META).derived as Dictionary).is_empty()
	XTianqiBase.PHASE4 = true
	var on := [XTianqiLedger.take_module_derived(logic, u, "module.toji.armory"), XTianqiLedger.take_module_derived(logic, u, "module.toji.armory")]
	var loose := [XTianqiLedger.take_module_derived(logic, u, "module.garou.follow"), XTianqiLedger.take_module_derived(logic, u, "module.garou.follow")]
	logic.turn += 1
	var next := XTianqiLedger.take_module_derived(logic, u, "module.toji.armory")
	XTianqiBase.PHASE4 = false
	rows.clear()
	rows.append_array(saved)
	_check("gate_off_always", off == [true, true] and off_clean, [off, off_clean])
	_check("gate_on_enforced", on == [true, false] and next, [on, next])
	_check("gate_on_not_enforced", loose == [true, true], loose)


# ---- 四：白起 full_again ----
func _full_again() -> void:
	var ch: Dictionary = XTianqiSkills.data().actors["80"].charge
	var got := []
	for p4 in [false, true]:
		XTianqiBase.PHASE4 = p4
		var s := _state([80])
		var slots := s.battle_slots.duplicate()
		slots[0] = 80
		s.battle_slots = slots
		var logic := XBattleLogic.new()
		logic.setup(TROOP, s)
		var u := s.actor(80)
		u.learn_skill(int(ch.full_again))
		logic.start_turn()
		var q: int = logic.current_order.size()
		s.set_variable(int(ch["var"]), int(ch.cap) - 1)
		var gain_id := int((ch.gain as Dictionary).keys()[0])
		# 本回合已经多动过一次：预算用完，攒满也不再动
		XTianqiLedger.take_extra(logic, u, "test", true)
		XTianqiSkills._charge(logic, u, {"skill": XDB.rec("Skills", gain_id), "crit": false, "targets": []})
		got.append({"p4": p4, "cards": XTianqiSkills.cards_on(), "var": int(s.variable(int(ch["var"]))), "queued": logic.current_order.size() - q,
			"used": bool(u.get_meta("xtq_charge_again", false))})
	XTianqiBase.PHASE4 = false
	_check("full_again_budget_phase4", got[1].cards and got[1].var == int(ch.cap) and got[1].queued == 0 and got[1].used, got)


# ---- 四：专属武器攻击次数 ----
func _exclusive_weapons() -> void:
	var gear: Dictionary = XTianqiSkills.data().gear
	var listed := EXCLUSIVE.filter(func(id): return (gear.get("weapon:%d" % id, {}).get("traits_set", []) as Array).any(func(t): return int(t.code) == 34))
	_check("exclusive_list", listed.size() == EXCLUSIVE.size() and gear.keys().filter(func(k): return (gear[k].get("traits_set", []) as Array).any(func(t): return int(t.code) == 34)).size() == EXCLUSIVE.size(), listed)
	var s := _state([])
	var a := s.actor(int(s.party[0]))
	var out := {}
	for wid in [2005, 1529, 6]:  # 两把卡改写的专属武器、一把原版带攻击次数的普通武器（6 不在改写表）
		a.equips[0] = XGear.template("weapon", wid)
		_refresh(a)
		var row := []
		for p4 in [false, true]:
			XTianqiBase.PHASE4 = p4
			_refresh(a)
			row.append(XTianqiLedger.nine_attack_times(a))
		XTianqiBase.PHASE4 = false
		out[wid] = row
	_check("exclusive_kept_on", is_equal_approx(float(out[2005][1]), 1.0) and is_equal_approx(float(out[1529][1]), 1.0), out)
	_check("exclusive_stopped_off", is_equal_approx(float(out[2005][0]), 0.0) and is_equal_approx(float(out[1529][0]), 0.0), out)
	_check("plain_weapon_stopped", is_equal_approx(float(out[6][0]), 0.0) and is_equal_approx(float(out[6][1]), 0.0), out)


# ---- 四：段数来源 ----
func _hit_sources() -> void:
	# 词条「连击」：一人最多 +1（stack max_per_actor、只有一条）
	var combo := []
	var f := FileAccess.open("res://modes/xiyou/tianqi_data/affix_table.json", FileAccess.READ)
	var aff = JSON.parse_string(f.get_as_text())
	_walk(aff, func(d): if d is Dictionary and str(d.get("pool", "")) == "attack_times": combo.append(d))
	_check("source_affix_combo", combo.size() == 1 and str(combo[0].get("stack", "")) == "max_per_actor", combo.map(func(d): return d.get("key")))
	# 七印：只有红印「多段连击」的 extra_hits +1
	var hits := []
	f = FileAccess.open("res://modes/xiyou/tianqi_data/qiyin_gear.json", FileAccess.READ)
	var qg = JSON.parse_string(f.get_as_text())
	_walk(qg, func(d): if d is Dictionary and str(d.get("code", "")) == "extra_hits": hits.append(int(d.get("value", 0))))
	var qsum := 0
	for v in hits:
		qsum += v
	_check("source_qiyin_red_only", hits == [1], hits)
	# D175（Kyo 11-17 10:14「单件最高+2。上限不封顶。」）：每一件来源（每条词条、每个红印、每把专属武器）最多 +2，合计不设上限
	var piece_bad := []
	for d in combo:
		for v in d.get("values", []):
			if int(v) > 2:
				piece_bad.append(["affix", d.get("key"), v])
	for v in hits:
		if v > 2:
			piece_bad.append(["qiyin", v])
	var gear_rw: Dictionary = XTianqiSkills.data().gear
	for k in gear_rw:
		for t in gear_rw[k].get("traits_set", []):
			if int(t.code) == 34 and float(t.get("value", 0)) > 2.0:
				piece_bad.append(["gear", k, t.value])
	_check("source_piece_le2", piece_bad.is_empty() and not combo.is_empty() and not hits.is_empty(), piece_bad)
	# 九线来源停用后（天启篇、卡开着）：原版装备、真气连击都不加，剩下的就是这三类＋角色本体（本体的另列，交付单写）
	XTianqiBase.PHASE4 = true
	var s := _state([])
	var a := s.actor(int(s.party[0]))
	a.equips[0] = XGear.template("weapon", 6)
	_refresh(a)
	var plain := a.attack_times_add()
	a.equips[0] = XGear.template("weapon", 2005)
	_refresh(a)
	var excl := a.attack_times_add()
	XTianqiBase.PHASE4 = false
	_check("source_runtime", is_equal_approx(plain, 0.0) and is_equal_approx(excl, 1.0), [plain, excl])


# ---- 五（T137）：黑闪天启篇 ----
func _black_flash_tq() -> void:
	var s := _state([171, 172])
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var toji := s.actor(171)
	var suk := s.actor(172)
	var e = logic.enemies[0]
	var item := XDB.rec("Skills", 10216)
	var got := {}
	for cards in [false, true]:
		XTianqiSkills.CARDS = cards
		XBlackFlash.cast = {"actor": toji, "skill": 10216}
		XBlackFlash.hit = {"target": e, "boost": true, "increment": 1.0}
		var tq := XTianqiModules.damage_ops(item, toji, e).filter(func(o): return str(o.field) == "criticalAdd")
		var capped := XTianqiSkills.module_ops(item, toji, XBlackFlash.damage_ops(e), "module.black_flash")
		XBlackFlash.hit = {"target": e, "boost": false, "increment": 0.0}
		var miss := XBlackFlash.tq_ops(toji, e)
		XBlackFlash.cast = {"actor": suk, "skill": 10230}
		XBlackFlash.hit = {"target": e, "boost": true, "increment": 1.0}
		var suk_ops := XBlackFlash.tq_ops(suk, e)
		got[cards] = {"tq": tq, "capped": capped, "miss": miss, "sukuna": suk_ops}
	XTianqiSkills.CARDS = false
	XBlackFlash.cast = {}
	XBlackFlash.hit = {}
	# 关着：天启分支不出，原版连闪暴伤照旧 +1.0
	_check("bf_off_unchanged", (got[false].tq as Array).is_empty() and got[false].capped.size() == 1 and is_equal_approx(float(got[false].capped[0].value), 1.0), got[false])
	# 开着：原版 +1.0 被收口拦掉、天启篇甚尔 +0.3（只在黑闪那次）；宿傩不加爆伤（卡只给下一次斩击 +20%）
	_check("bf_on_toji_crit", (got[true].capped as Array).is_empty() and got[true].tq.size() == 1 and is_equal_approx(float(got[true].tq[0].value), 0.3) and (got[true].miss as Array).is_empty(), got[true])
	_check("bf_on_sukuna_none", (got[true].sukuna as Array).is_empty(), got[true].sukuna)
	# 五条悟：单独一个数（待 Kyo 拍板），推荐与甚尔一致
	_check("bf_gojo_crit_tunable", is_equal_approx(XBlackFlash.TQ_CRIT_GOJO, 0.3) and XBlackFlash.TQ_CRIT.get(XGojo.ACTOR) == null, XBlackFlash.TQ_CRIT_GOJO)
	# 觉醒回合：甚尔卡开着 2 回合、关着 3 回合；宿傩照旧 3
	toji.learn_skill(XBlackFlash.SKILL)
	suk.learn_skill(XBlackFlash.SKILL)
	var exp := {}
	for cards in [false, true]:
		XTianqiSkills.CARDS = cards
		for u in [toji, suk]:
			XBlackFlash._temp.erase(u)
			XBlackFlash.cast = {"actor": u, "skill": 10216 if u == toji else 10230, "success": true, "chain": 0, "focus": 0, "eligible": true, "damage": true}
			XBlackFlash.finish(logic, u, XDB.rec("Skills", 10216 if u == toji else 10230))
			exp["%s|%d" % [cards, int(u.actor_id)]] = int(XBlackFlash.temp(u).expires) - XBlackFlash.round
	XTianqiSkills.CARDS = false
	XBlackFlash.cast = {}
	_check("bf_awake_rounds", exp == {"false|171": 3, "false|172": 3, "true|171": 2, "true|172": 3}, exp)


# ---- 五（T137）：屠苏卡开着不分摊、分段不加伤 ----
func _tusu_tq() -> void:
	var s := _state([])
	XTianqi._joining = true
	XTusuXuan.recruit(s, 176)
	XTianqi._joining = false
	var slots := s.battle_slots.duplicate()
	slots[0] = 176
	s.battle_slots = slots
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var t := s.actor(176)
	var item := XDB.rec("Skills", XTusuXuan.skill_id(176, "arm.zhanfeng"))
	var e = logic.enemies[0]
	var td = XTusu.data(t)
	var got := {}
	if td != null:
		td.host_actions = 1
		for cards in [false, true]:
			XTianqiSkills.CARDS = cards
			got[cards] = {"share": XTusu.damage_ops(item, t, e).filter(func(o): return str(o.field) == "finalMultiplier").map(func(o): return o.value), "bonus": XTusu.segment_bonus()}
		XTianqiSkills.CARDS = false
	_check("tusu_share_off_only", td != null and got[false].share == [2.0] and (got[true].share as Array).is_empty(), [td != null, got])
	_check("tusu_segment_bonus", td != null and is_equal_approx(float(got[false].bonus), 1.2) and is_equal_approx(float(got[true].bonus), 1.0), got)


# ---- 五（T137）：镜流 10190 没有别的活敌：不扩散、不扣派生次数 ----
func _jingliu_no_other() -> void:
	var s := _state([])
	XTianqi._joining = true
	XYomiJingliu.recruit(s, 170)
	XTianqi._joining = false
	var slots := s.battle_slots.duplicate()
	slots[0] = 170
	s.battle_slots = slots
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var u := s.actor(170)
	var main = logic.enemies[0]
	for e in logic.enemies:
		if e != main:
			e.hp = 0
			e.add_state(1)
	XTianqiBase.PHASE4 = true
	logic.start_turn()
	XYomiJingliu._j_frame = {"user": u, "main": main, "had_gap": true, "hit": true}
	var logs := XYomiJingliu.j_finish(logic, u, XDB.rec("Skills", 10190))
	var b: Dictionary = logic.get_meta(XTianqiLedger.BUDGET_META) if logic.has_meta(XTianqiLedger.BUDGET_META) else {"derived": {}}
	XTianqiBase.PHASE4 = false
	var key := "%d|module.jingliu.segment" % int(u.actor_id)
	_check("jingliu_10190_no_other", logs.is_empty() and int((b.get("derived", {}) as Dictionary).get(key, 0)) == 0, [logs.size(), b.get("derived")])


# ---- 五（T137）：璇棱光口子在 _cast 查完之后（没星契不扣次数） ----
func _xuan_gate() -> void:
	var s := _state([])
	XTianqi._joining = true
	XTusuXuan.recruit(s, 177)
	XTianqi._joining = false
	var slots := s.battle_slots.duplicate()
	slots[0] = 177
	s.battle_slots = slots
	var a := s.actor(177)
	a.change_level(99)
	for id in _module_skills(177):
		a.learn_skill(int(id))
	a.recover_all()
	var logic := XBattleLogic.new()
	logic.setup(TROOP, s)
	var host = logic.actors.filter(func(x): return x != a)[0]
	XBinding.bind(a, host)
	if not XXuanBattle.data.is_empty():
		XXuanBattle.data.auto = true
	XTianqiBase.PHASE4 = true
	logic.start_turn()
	var atk := XDB.rec("Skills", 1)
	var counts := []
	for ch in [0, 3]:
		a.mp = a.mmp
		a.tp = a.max_tp()
		XBinding.data(a).charges = ch
		XTianqiLedger.TRACE = []
		XXuanBattle._follow_up(logic, a, atk, null, host)  # end_action 宿主主动攻击后走这里（真打的接线在夹具那场里，30 次）
		counts.append((XTianqiLedger.TRACE as Array).filter(func(t): return str(t.source) == "module.xuan.follow_up" and int(t.trigger) == int(host.actor_id)).size())  # 口子被问了几次（记数与否看表里 enforced）
		XTianqiLedger.TRACE = null
	# T082（T137 核 P2）：同轨协同、回合末放的棱光也走同一个口子；上面那次跟攻已用掉本回合 1 次，两条路都被拦（不再多打）
	var tg_prev = XXuanBattle.data.get("tonggui")
	XXuanBattle.data.tonggui = true
	XXuanBattle._main_tonggui = false
	XTianqiLedger.TRACE = []
	var foe_hp := 0.0
	for e in logic.alive(logic.enemies):
		foe_hp += float(e.hp)
	XXuanBattle._tonggui_strike(logic, a)
	var tg: Array = (XTianqiLedger.TRACE as Array).filter(func(t): return str(t.source) == "module.xuan.follow_up")
	var foe_hp2 := 0.0
	for e in logic.alive(logic.enemies):
		foe_hp2 += float(e.hp)
	XTianqiLedger.TRACE = null
	XXuanBattle.data.tonggui = tg_prev
	XXuanBattle.take_logs()
	XTianqiBase.PHASE4 = false
	_check("xuan_gate_no_charge_no_count", counts == [0, 1], counts)
	_check("xuan_tonggui_gated", tg.size() == 1 and not bool(tg[0].ok) and foe_hp2 == foe_hp, [tg, foe_hp, foe_hp2])
	# 回合末放的棱光：_cast 带 gate_trigger（源码钉住，回合末要 XBinding._logic() 真战斗现场，这里不搭）
	var src := FileAccess.get_file_as_string("res://modes/xiyou/core/xuan_battle.gd")
	_check("xuan_round_end_gated", src.contains("done = _cast(logic, owner, \"lengguang\", [alive[0]], {}, true, owner)"))


## T082（T137 核 P2）：原版套装 164 的技能 3609 开战挂 524「攻击次数 +1」：天启篇九线停用开着时不挂，关着（回退）照挂
func _suit_524() -> void:
	var s := _state([])
	var a: XActor = s.battle_members()[0]
	var need := 0
	var defs: Array = XDB.table("EquipSuits")
	for b in defs[164].bonuses:
		if (b.get("skills", []) as Array).any(func(x): return int(x) == 3609):
			need = int(b.requirePieces)
	var n := 0
	var slots := a.equip_slots()
	for i in slots.size():
		if n >= need:
			break
		var et := int(slots[i])
		if et == 1:
			continue
		for rec in XDB.table("Armors"):
			if rec is Dictionary and int(rec.get("etypeId", 0)) == et and str(rec.get("name", "")) != "":
				var e := XGear.template("armor", int(rec.id))
				if not a.can_equip(e):
					continue
				var eq: Dictionary = e.get("equipment", {})
				eq["suits"] = [164]
				e["equipment"] = eq
				a.equips[i] = e
				n += 1
				break
	_refresh(a)
	var has524 := func() -> bool:
		return a.battle_start_state_tags().any(func(t): return int(t[1]) == 524)
	var on_has: bool = has524.call()
	XTianqiLedger.NINE_OFF = false
	_refresh(a)
	var off_has: bool = has524.call()
	XTianqiLedger.NINE_OFF = true
	_refresh(a)
	_check("suit_524_setup", need > 0 and n >= need and XEquipSuits.ids(a, "skills").has(3609), [need, n, XEquipSuits.ids(a, "skills")])
	_check("suit_524_stopped", not on_has and off_has, [on_has, off_has])


## 模块技能要的武器类型（黄泉 11、镜流 2）：身上那把不对就换一把对的
## 第 i 条是不是套在 [from, i) 里某条还没收尾的派生里面（hp1 晚于它补上的那条）
static func _nested(trace: Array, from: int, i: int) -> bool:
	for j in range(from, i):
		if float(trace[j].hp1) >= 0.0 and float(trace[j].hp0) >= float(trace[i].hp0) and float(trace[j].hp1) <= float(trace[i].hp1) and str(trace[j].source) != str(trace[i].source):
			return true
	return false


func _fit_weapon(a) -> void:
	var need := 0
	var own: Array = _module_skills(int(a.actor_id))
	if int(a.actor_id) == 170:
		own = own.filter(func(id): return XYomiJingliu.jingliu_skill(int(id)))
	elif int(a.actor_id) == 169:
		own = own.filter(func(id): return XYomiJingliu.yomi_skill(int(id)))
	for id in own:
		var w := int(XDB.rec("Skills", int(id)).get("requiredWtypeId1", 0))
		if w > 0:
			need = w
			break
	if need <= 0:
		return
	var cur = a.equips[0]
	if cur is Dictionary and int(XDB.rec("Weapons", int(cur.get("base", cur.get("id", 0)))).get("wtypeId", 0)) == need:
		return
	for w in XDB.table("Weapons"):
		if w is Dictionary and int(w.get("wtypeId", 0)) == need:
			a.equips[0] = XGear.template("weapon", int(w.id))
			_refresh(a)
			return


func _refresh(a) -> void:
	a.param_mark_dirty()
	a.refresh_passive()


func _walk(v, fn: Callable) -> void:
	fn.call(v)
	if v is Dictionary:
		for k in v:
			_walk(v[k], fn)
	elif v is Array:
		for x in v:
			_walk(x, fn)
