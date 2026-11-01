extends Node
## 智能战斗AI（XSmartAI）对照正式版 Codex_SmartBattleAI：generated/oracle/smart_ai.json 由 mv_oracle/smart_ai_probe.cjs 生成
## （普通难度、出战 1/8/9/10、10 级、开局被动与开战状态、药 1/2/137；切片敌群 × 满状态/队友低血/队友阵亡/没蓝/敌人残血）。
## 比较：每个角色选中的技能/药与目标、前 6 名候选的分数，以及 safeDamage 估算；另比 YEP 行动序列段数（转换器 yepEffects）。
## 异化投影估值（O-121 XSmartAI.o_projection）只写 Godot 侧断言（alien_projection）：开时是优化；关时照原版混读，断言按原版源码的结果写（探针不带异化）。
## 分 parts 份（xiyou_smart_ai 管第 0 份，_b～_p 各管一份）：伤害行按序号轮流；选择用例按「同敌群同场面的 4 个角色」整组轮流
## （用例按 敌群×场面×角色 1/8/9/10 排，原来四份逐条轮流时每份正好是一个角色，角色 10 那份满负载 600 秒被杀。tools30 改整组轮流；
## 每份约 120 CPU 秒时负载 10～15 下 130～165 秒，满负载要再翻倍，所以分 16 份，每份约 60 CPU 秒）。
## 来源指纹、行动序列、自动战斗分派与边界伤害只在第 0 份比，断言总数与拆分前相同
@export var part := 0
@export var parts := 16
const CASE_GROUP := 4  # 每个敌群×场面的角色数（探针出战 1/8/9/10）
## 共用布置（tools31）：原来每条伤害行、每个选择用例都重新开局布置（setup 约 43 毫秒，两万多次）。同一敌群×场面连着的几条共用一次布置；
## 每次复用前比一遍「战斗指纹」（双方 HP／MP／TP、状态与回合、增减益、冷却、护盾、各项能力、学会的技能、物品与变量开关、随机流快照、回合数），
## 跟刚布置完时不一样就说明上一条改了状态：丢掉重新布置，记进 drift，最后 share_setup_isolated 判失败并列出是哪组、哪些字段。
## 回退：环境变量 XIYOU_SMART_AI_SHARE=0（或 SHARE_SETUP = false）回到逐条开局；两边断言一样多。
static var SHARE_SETUP := OS.get_environment("XIYOU_SMART_AI_SHARE") != "0"
var _shared_key := ""
var _shared_logic: XBattleLogic
var _shared_print := ""
var drift: Array = []
var setups := 0

var results := []
var mismatches := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		mismatches.append({"name": name, "detail": detail})


func close(a: float, b: float, rel := 1e-4) -> bool:
	return absf(a - b) <= maxf(1.0, absf(b) * rel)


## 取一份布置：共用时同一敌群×场面连着复用（见 SHARE_SETUP），否则逐条开局
func logic_for(ref: Dictionary, troop: int, scene: String) -> XBattleLogic:
	if not SHARE_SETUP:
		return setup(ref, troop, scene)
	var key := "%d:%s" % [troop, scene]
	if key == _shared_key:
		var now := fingerprint(_shared_logic)
		if now == _shared_print:
			return _shared_logic
		if drift.size() < 20:
			drift.append({"key": key, "fields": _diff_fields(_shared_print, now)})
	_shared_key = key
	_shared_logic = setup(ref, troop, scene)
	_shared_print = fingerprint(_shared_logic)
	return _shared_logic


static func _battler_print(b: XBattler) -> Dictionary:
	var params := []
	for i in range(8):
		params.append(b.param(i))
	var out := {"hp": b.hp, "mp": b.mp, "tp": b.tp, "states": b.state_ids.duplicate(), "stateTurns": b.state_turns.duplicate(true),
		"stateData": b.state_data.duplicate(true), "stateOrigins": b.state_origins.duplicate(true), "buffs": b.buffs.duplicate(),
		"buffTurns": b.buff_turns.duplicate(), "guarding": b.guarding, "lastTarget": b.last_target_index, "cooldowns": b.cooldowns.duplicate(true),
		"warmups": b.warmups.duplicate(true), "shield": b.shield, "zq": [b.zq_guard, b.zq_pojia_rate], "immortal": b.immortal,
		"params": params, "xparams": [b.hit, b.eva, b.cri, b.cev, b.mev, b.mrf, b.cnt, b.hrg, b.mrg, b.trg, b.tgr, b.grd, b.rec, b.pha, b.mcr],
		"lifecycle": b.lifecycle_context.keys()}
	if b is XActor:
		out.skills = (b as XActor).skill_ids.duplicate()
	return out


## 战斗指纹：复用前与刚布置完时逐项比（见 SHARE_SETUP）
static func fingerprint(logic: XBattleLogic) -> String:
	var s := logic.state
	return JSON.stringify({"actors": logic.actors.map(_battler_print), "enemies": logic.enemies.map(_battler_print), "turn": logic.turn,
		"random": logic.random.snapshot() if logic.random != null else null, "items": s.items, "variables": s.variables, "switches": s.switches})


static func _diff_fields(a: String, b: String) -> Array:
	var x = JSON.parse_string(a)
	var y = JSON.parse_string(b)
	var out := []
	for side in ["actors", "enemies"]:
		for i in range(mini(x[side].size(), y[side].size())):
			for k in x[side][i]:
				if x[side][i][k] != y[side][i].get(k):
					out.append("%s[%d].%s" % [side, i, k])
	for k in ["turn", "random", "items", "variables", "switches"]:
		if x[k] != y[k]:
			out.append(k)
	return out


var T := {}
func tick(k: String, t0: int) -> void:
	T[k] = T.get(k, 0) + Time.get_ticks_usec() - t0
func setup(ref: Dictionary, troop: int, scene: String) -> XBattleLogic:
	var _t0 := Time.get_ticks_usec()
	var r := setup_inner(ref, troop, scene)
	tick("setup", _t0)
	return r
func setup_inner(ref: Dictionary, troop: int, scene: String) -> XBattleLogic:
	setups += 1
	XEnemy.force_roll = 100.0
	var party: Array = ref.party
	var s := XState.new_game(int(ref.difficulty), int(party[0]), party.slice(1))
	s.items = {}
	for k in ref.items:
		s.items[int(k)] = int(ref.items[k])
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	logic.turn = 1
	for a in logic.actors:
		for sk in [6168, 5980, 5548] + ([2571, 2786] if int(a.data().id) in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(sk)
		a.change_level(int(ref.level))
		a.refresh_passive()
		a.recover_all()
		for st in [995, 1691, 1631]:
			a.add_state(st)
		a.refresh_passive()
		a.tp = 0.0  # 探针没有经过开战 initTp
	match scene:
		"ally_low":
			var a := s.actor(9)
			a.hp = maxf(1.0, floorf(a.mhp * 0.2))
		"ally_dead":
			s.actor(9).add_state(1)
		"no_mp":
			for a in logic.actors:
				a.mp = 0.0
		"foes_low":
			for e in logic.enemies:
				e.hp = maxf(1.0, floorf(e.mhp * 0.1))
	return logic


func target_index(logic: XBattleLogic, t) -> int:
	if t == null:
		return -1
	var i := logic.enemies.find(t)
	return i if i >= 0 else logic.actors.find(t)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/smart_ai.json"))
	if not ref is Dictionary:
		check("oracle_present", false, "先运行 mv_oracle/smart_ai_probe.cjs")
		return finish()
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + "manifest.json"))
	var lead := part == 0
	if lead:
		check("source_identity", ref.sourceIdentity.get("releaseVersion") == manifest.releaseVersion
			and ref.sourceIdentity.get("runtimeInputs") == manifest.runtimeInputs, [ref.sourceIdentity.get("releaseVersion"), manifest.releaseVersion])
	for row in (ref.sequence if lead else []):
		check("seq.%d" % int(row.skill), int(XDB.rec("Skills", int(row.skill)).get("yepEffects", 0)) == int(row.hits), [row.skill, row.hits])
	var t_dmg := Time.get_ticks_usec()
	for i in range(part, ref.damage.size(), parts):
		var row: Dictionary = ref.damage[i]
		var logic := logic_for(ref, int(row.troop), "full")
		var a: XActor = logic.state.actor(int(row.actor))
		var ai := XSmartAI.new(logic, a)
		var v := ai.safe_damage(a, logic.enemies[int(row.target)], XDB.rec("Skills", int(row.skill)))
		check("safe.t%d.a%d.s%d.e%d" % [int(row.troop), int(row.actor), int(row.skill), int(row.target)], close(v, float(row.safe)), {"godot": v, "mv": row.safe})
		var e: XBattler = logic.enemies[int(row.target)]
		var cri := clampf(a.cri * (1.0 - e.cev), 0.0, 1.0) if bool(XDB.rec("Skills", int(row.skill)).damage.critical) else 0.0
		var sk := XDB.rec("Skills", int(row.skill))
		check("hit.t%d.a%d.s%d.e%d" % [int(row.troop), int(row.actor), int(row.skill), int(row.target)],
			absf(logic.item_hit(a, sk, e) - float(row.hit)) < 1e-4 and absf(logic.item_eva(a, sk, e) - float(row.eva)) < 1e-4,
			{"godot": [logic.item_hit(a, sk, e), logic.item_eva(a, sk, e)], "mv": [row.hit, row.eva]})
		check("cri.t%d.a%d.s%d.e%d" % [int(row.troop), int(row.actor), int(row.skill), int(row.target)], absf(cri - float(row.cri)) < 1e-4, {"godot": cri, "mv": row.cri, "a.cri": a.cri, "e.cev": e.cev})
	tick("damage_loop", t_dmg)
	var t_case := Time.get_ticks_usec()
	for i in range(ref.cases.size()):
		if (i / CASE_GROUP) % parts != part:
			continue
		var c: Dictionary = ref.cases[i]
		var tag: String = "case.t%d.%s.a%d" % [int(c.troop), c.scene, int(c.actor)]
		if c.get("skipped", false):
			continue
		var logic := logic_for(ref, int(c.troop), c.scene)
		var a: XActor = logic.state.actor(int(c.actor))
		var _tc := Time.get_ticks_usec()
		var r := XSmartAI.choose(logic, a)
		tick("choose", _tc)
		var mine = {"id": int(r.skill.id), "item": XSmartAI.is_item(r.skill), "target": target_index(logic, r.target)} if r.has("skill") else null
		var theirs = {"id": int(c.chosen.id), "item": bool(c.chosen.item), "target": int(c.chosen.target)} if c.chosen else null
		check(tag + ".choice", mine == theirs, {"godot": mine, "mv": theirs, "godot_rank": r.get("candidates", []).map(func(x): return [x.id, x.item, x.score]), "mv_rank": c.candidates})
		for cand in c.candidates:
			var m = r.candidates.filter(func(x): return x.id == int(cand.id) and x.item == bool(cand.item))
			check(tag + ".score.%s%d" % ["i" if cand.item else "s", int(cand.id)], not m.is_empty() and close(float(m[0].score), float(cand.score), 2e-3),
				{"godot": m[0].score if not m.is_empty() else null, "mv": cand.score})
	tick("case_loop", t_case)
	if not lead:
		return finish()
	routing(ref)
	alien_projection(ref)
	var edge_logic := setup(ref, int(ref.cases[0].troop), "full")
	var edge_actor := edge_logic.state.actor(1)
	var edge_ai := XSmartAI.new(edge_logic, edge_actor)
	for row in ref.get("edgeDamage", []):
		var rec := XDB.rec("Skills", 160).duplicate(true)
		rec.damage.type = int(row.type)
		rec.damage.formula = row.formula
		rec.damage.formulaProgram = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/formula_effect_programs.json"))["ai.edge_damage_" + str(int(row.type))].program
		rec.damage.formulaGd = "a.atk * randf()" if int(row.type) == 1 else "a.mat * 2"
		seed(20261014)
		var first := randf()
		seed(20261014)
		var rule_before := JSON.stringify(edge_logic.random.snapshot())
		var value := edge_ai.safe_damage(edge_actor, edge_logic.enemies[0], rec)
		check("edge_damage_%d" % int(row.type), close(value, float(row.value)), [value, row.value])
		check("preview_preserves_rng_%d" % int(row.type), randf() == first)
		# dev.099 起实战抽本场规则流：预览也不能动它
		check("preview_preserves_rule_%d" % int(row.type), JSON.stringify(edge_logic.random.snapshot()) == rule_before)
	finish()


## 自动战斗的分派（auto_battle_action）与设置项
func routing(ref: Dictionary) -> void:
	XSave.dir_override = "user://test_xiyou_smart_ai"
	XConfig.path_override = XSave.dir().path_join("options.json")
	check("smart_default_on", XConfig.smart_ai())
	var logic := setup(ref, 2, "full")
	var a: XActor = logic.state.actor(1)
	check("auto_uses_smart", int(logic.auto_battle_action(a)[0].id) == 160)
	XConfig.set_smart_ai(false)
	check("auto_off_attacks", int(logic.auto_battle_action(a)[0].id) == XBattleLogic.ATTACK_SKILL)
	XConfig.set_smart_ai(true)
	logic.state.hang_up["ActSkill"] = {a.display_name() + "001": XBattleLogic.GUARD_SKILL}
	check("schedule_first", int(logic.auto_battle_action(a)[0].id) == XBattleLogic.GUARD_SKILL)
	var opt := XOptionsScene.new()
	add_child(opt)
	var i := opt.symbols().find("codexSmartAI")
	check("option_row", i >= 0 and opt.status_text(i) == "ON")
	opt.index = i
	opt.ok()
	check("option_toggle", not XConfig.smart_ai() and opt.status_text(i) == "OFF")
	opt._side(true)
	check("option_right_on", XConfig.smart_ai())
	opt.queue_free()


## O-121 o_projection：逆祷者的攻击按治疗友方估值、祸祝 7100（对自己附加幻日虹）按对敌诅咒估值；关时照原版混读
func alien_projection(ref: Dictionary) -> void:
	var blessing := XDB.rec("Skills", 7100)
	var saved := [blessing.stypeId, blessing.mpCost, blessing.tpCost]
	blessing.stypeId = 0  # 让 1 号角色用得上（技能类型、费用与估值无关）
	blessing.mpCost = 0
	blessing.tpCost = 0
	for on in [true, false]:
		XSmartAI.o_projection = on
		var tag := "alien.%s." % ("on" if on else "off")
		for affix in ["prayer", "blessing"]:
			var logic := setup(ref, 2, "ally_low")
			logic.state.items = {}
			var a: XActor = logic.state.actor(1)
			if affix == "blessing":
				a.learn_skill(7100)
			XAlienBattle._logic_ref = weakref(logic)
			XAlienBattle._store(logic).party = {a: {"affix": affix, "item": {}, "config": {}, "observed": [], "selected": 0}}
			var _tc := Time.get_ticks_usec()
		var r := XSmartAI.choose(logic, a)
		tick("choose", _tc)
			var rank: Array = r.candidates.map(func(x): return [x.id, x.score, x.target.display_name() if x.target else null])
			if affix == "prayer":
				var att: Array = r.candidates.filter(func(x): return x.id == XBattleLogic.ATTACK_SKILL and not x.item)
				if on:  # 攻击投影成治愈：给生命 20% 的 9 号治疗，分数够高就选它
					check(tag + "prayer.choice", int(r.skill.id) == XBattleLogic.ATTACK_SKILL and r.target == logic.state.actor(9), rank)
					var t: XActor = logic.state.actor(9)
					var proj := XAlienBattle.project(a, a.attack_skill())
					var ai := XSmartAI.new(logic, a)  # 估算与借来的治疗技能（攻击无 MP 费用→治愈 8）同口径：safeDamage 不含实战的被动治疗加成
					var est := ai.healing_amount(t, proj, false, false)
					var healer := ai.healing_amount(t, XAlienBattle.prayer_healer(logic, a, proj), false, false)
					check(tag + "prayer.heal_estimate", est > 0.0 and est == healer and int(XAlienBattle.prayer_healer(logic, a, proj).id) == 8, [est, healer])
				else:  # 照原版：方向读投影（友方单体）、估值读原攻击（伤害类型 1，治疗量 0）→ 0 分；全 0 分退回普攻，
					# setTarget(HP 最低的敌人序号)，投影成友方单体后落到同序号的队友
					var foes := logic.alive(logic.enemies)
					var low: XBattler = foes.reduce(func(x, y): return y if y.hp < x.hp else x)
					var i := logic.enemies.find(low)
					var want: XBattler = logic.actors[i] if i < logic.actors.size() and logic.actors[i].is_alive() else logic.alive(logic.actors)[0]
					check(tag + "prayer.attack_zero_friend", not att.is_empty() and att[0].target is XActor and att[0].score == 0.0, rank)
					check(tag + "prayer.fallback_same_index", int(r.skill.id) == XBattleLogic.ATTACK_SKILL and r.target == want, [rank, i, r.target.display_name() if r.target else null])
			else:
				var bl: Array = r.candidates.filter(func(x): return x.id == 7100 and not x.item)
				if on:  # 祸祝：对敌单体，附加诅咒
					check(tag + "blessing.foe", not bl.is_empty() and bl[0].target is XEnemy and bl[0].score > 0.0, rank)
				else:  # 照原版：方向读投影（敌方单体）、估值读原技能（附加增益幻日虹，对敌不加分）→ 0 分
					check(tag + "blessing.foe_zero", not bl.is_empty() and bl[0].target is XEnemy and bl[0].score == 0.0, rank)
			XAlienBattle._logic_ref = null
	XSmartAI.o_projection = true
	blessing.stypeId = saved[0]
	blessing.mpCost = saved[1]
	blessing.tpCost = saved[2]


func finish() -> void:
	check("share_setup_isolated", drift.is_empty(), drift)
	print("TIMES ", JSON.stringify(T))
	print("SETUPS %d（共用布置%s）" % [setups, "开" if SHARE_SETUP else "关"])
	var passed := results.filter(func(r): return r.passed).size()
	for m in mismatches.slice(0, 40):
		print("MISMATCH ", m.name, " ", JSON.stringify(m.detail).left(700))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
