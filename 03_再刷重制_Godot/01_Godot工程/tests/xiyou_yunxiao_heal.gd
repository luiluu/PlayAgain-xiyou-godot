extends Node
## T506（选项 B）西游档修复：智能战斗 AI 统一放行「治疗＋安全追击 CE」同类技能并计入 339 追击收益
## （开关 XSmartAI.o_xiyou_heal_ce，默认开，仅西游档生效，避开原版探针角色 1／8／9／10，天启篇零改动）专项：
## 〇、默认值与开关回退：默认开；关掉开关退回原版（全部同类技能 legal=false）；
## 一、云霄（100）全生命周期：
##     - 9 级未学 5572 边界：5567 合法但追击加分为 0；
##     - 39／40 级实战日志：选放 5567 黄庭甘露 → 队友得 1063＋1027、血回满，CE 1219 追击 5572 九曲黄河阵·生门，敌受伤并挂 1062；
##     - 50 级实战日志：优先选放 5571 黄庭圣经 → 队友得 1058＋1060（护盾）＋1027，CE 1219 追击 5572，敌受伤并挂 1062；
##     - 50 级续回合（满血满 buff 且敌已有 1062）自然切回 5572 不空奶；队友掉血切回治疗＋追击；
##     - v[1491]==0 边界仍因 1062 减益追击分压过 5574；
## 二、全部其余 14 名同类「治疗＋安全追击 CE」角色逐一验证：
##     修前（开关关）legal=false，修后（开关开）legal=true，并各跑至少一场整回合自动战斗（run_turn）日志证明会放且会接追击：
##     - 84 小毒（5541 小毒的战歌 → CE 1335 → 5540 DEBUFF之斩）
##     - 117 绯红蔷薇（5781 蔷薇领域 → CE 1220 → 5540 DEBUFF之斩）
##     - 96 朵莉亚（8152 逐浪 / 8155 天籁 → CE 1222 → 8151 欢歌·再释放＋8153 逐浪·再释放）
##     - 13 刘备（73 PUA → CE 43 → 320 PUA）
##     - 7 茉蕾（108 次级治疗术 → CE 987 → 16 克莱德 4552 毒奶术）
##     - 16 克莱德（4550 次级治疗术 → CE 987 → 4552 毒奶术）
##     - 31 露茜（623 治愈之歌 → CE 91 → 16 克莱德 4552 毒奶术；另验 5150 30% 概率权重）
##     - 40 小白龙（1118 生命之水 → CE 137 → 1123 生命之水）
##     - 44 碧池（1170 回春术 → CE 143 → 1172 回春术）
##     - 77 玉兔精（3759 萝萝大方 → CE 1371 → 3767 → CE 678 → 3872 萝卜核弹，两级链式追击）
##     - 81 申公豹（4828 口若悬河 → CE 1083 → 4833 口含先天~!）
##     - 61 町甄（5525 瑞克五代 → CE 1309 → 5526 芝士雪豹；另验 5527／5528 放行）
##     - 98 金狐（7072 月光之舞 → CE 2367 → 97 赤狐 7062 妖狐之舞）
##     - 97 赤狐（7059 妖狐之舞 → CE 2368 → 98 金狐 7073 月光之舞）
## 三、严格隔离：探针角色 1／8／9／10（含 8 修 3638）完全不受影响；复活技仍归 o_revive_ce；非治疗／危险 CE 仍拦；
## 四、天启篇零改动：天启篇存档开关开关选招、分数、候选列表逐项一致，关 o_tianqi_smart_ai 也不入西游分支。
const BIG_HP := 1e9
var results := []


class RecLogic extends XBattleLogic:
	var acts: Array = []
	var forced: Array = []

	func act(u: XBattler, skill, target) -> Array:
		var logs := super(u, skill, target)
		acts.append({
			"actor_id": u.actor_id if u is XActor else -1,
			"name": u.display_name() if u is XActor else str(u.data().get("name", "")),
			"id": int(skill.get("id", 0)) if skill is Dictionary else 0,
			"skill_name": str(skill.get("name", "")) if skill is Dictionary else "",
		})
		return logs

	func _forced_run(u: XBattler, skill: Dictionary, target: XBattler, first_subject: XBattler) -> Array:
		forced.append({
			"actor_id": u.actor_id if u is XActor else -1,
			"id": int(skill.get("id", 0)),
			"skill_name": str(skill.get("name", "")),
		})
		return super(u, skill, target, first_subject)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261125)
	XSave.dir_override = "user://test_xiyou_yunxiao_heal"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig._loaded_path = ""
	XConfig.ensure_loaded()
	XConfig.set_smart_ai(true)

	_yunxiao_suite()
	_all_peer_healers_suite()
	_isolation_and_safety()
	_tianqi_zero_change()

	XSmartAI.o_xiyou_heal_ce = true
	XSmartAI.o_tianqi_smart_ai = true

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _setup_xiyou(lv: int, party: Array, logic: XBattleLogic = null, var1491 := 1) -> XBattleLogic:
	var s := XState.new_game(2, int(party[0]), [])
	s.set_switch(int(XItemMarks.SUPER_SWITCHES[0]), true)
	for id in party:
		if not s.party.has(int(id)):
			s.add_actor(int(id))
	s.items = {}
	s.set_variable(1491, var1491)
	XState.current = s
	if logic == null:
		logic = XBattleLogic.new()
	logic.setup(2, s, XBattleRandom.create("0000000000000506"))
	logic.turn = 1
	for a in logic.actors:
		a.change_level(lv)
		a.refresh_passive()
		a.recover_all()
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	return logic


func _actor(logic: XBattleLogic, id: int) -> XActor:
	for a in logic.actors:
		if int(a.actor_id) == id:
			return a
	return null


func _pick(logic: XBattleLogic, a: XActor) -> Dictionary:
	var r := XSmartAI.choose(logic, a)
	return {
		"id": int(r.get("skill", {}).get("id", 0)),
		"score": float(r.get("score", 0.0)),
		"rank": r.get("candidates", []).map(func(c): return [int(c.id), float(c.score)]),
	}


# ---- 一、云霄专项（默认值、开关回退、9/39/40/50 级实战日志、续回合、v1491==0 边界）----
func _yunxiao_suite() -> void:
	_check("default.enabled", XSmartAI.o_xiyou_heal_ce == true)
	for lv in [39, 40, 50]:
		var logic := _setup_xiyou(lv, [100, 1, 2, 3])
		var yx := _actor(logic, 100)
		var ai_on := XSmartAI.new(logic, yx)
		_check("yx.on.lv%d.legal_5567" % lv, ai_on.legal(XDB.rec("Skills", 5567), false))
		if lv >= 50:
			_check("yx.on.lv%d.legal_5571" % lv, ai_on.legal(XDB.rec("Skills", 5571), false))
		var p_on := _pick(logic, yx)
		var want_id := 5571 if lv >= 50 else 5567
		_check("yx.on.lv%d.picks_%d" % [lv, want_id], p_on.id == want_id, p_on)

		XSmartAI.o_xiyou_heal_ce = false
		var ai_off := XSmartAI.new(logic, yx)
		_check("yx.off.lv%d.block_5567" % lv, not ai_off.legal(XDB.rec("Skills", 5567), false))
		if lv >= 50:
			_check("yx.off.lv%d.block_5571" % lv, not ai_off.legal(XDB.rec("Skills", 5571), false))
		var p_off := _pick(logic, yx)
		_check("yx.off.lv%d.fallback_5574" % lv, p_off.id == 5574, p_off)
		XSmartAI.o_xiyou_heal_ce = true

	# 9 级未学 5572 边界
	var l9 := _setup_xiyou(9, [100, 1, 2, 3])
	var yx9 := _actor(l9, 100)
	_check("yx.lv9.no_5572", not yx9.skills().any(func(k): return int(k.id) == 5572))
	var ai9 := XSmartAI.new(l9, yx9)
	_check("yx.lv9.legal_5567", ai9.legal(XDB.rec("Skills", 5567), false))
	var ctx9 := {"friends": l9.actors, "foes": l9.alive(l9.enemies), "urgent": false, "longFight": true, "damageScale": 1000.0}
	_check("yx.lv9.follow_bonus_zero", ai9._xiyou_heal_ce_bonus(XDB.rec("Skills", 5567), false, ctx9, XDB.rec("Skills", 5567)) == 0.0)

	# 39 / 40 / 50 级实战日志
	_yunxiao_real_turn(39, 5567, [1027, 1063], false)
	_yunxiao_real_turn(40, 5567, [1027, 1063], false)
	_yunxiao_real_turn(50, 5571, [1027, 1058, 1060], true)

	# 50 级续回合（满血满 buff 切回 5572，队友受伤切回治疗+追击）
	var l50 := _setup_xiyou(50, [100, 1, 2, 3])
	var yx50 := _actor(l50, 100)
	for a in l50.actors:
		a.add_state(1058)
		a.add_state(1060)
		a.add_state(1063)
		a.tp = a.max_tp()
	for e in l50.enemies:
		e.add_state(1062)
	var p_full := _pick(l50, yx50)
	_check("yx.lv50.full_buff_picks_5572", p_full.id == 5572, p_full)
	_actor(l50, 1).hp = floorf(_actor(l50, 1).mhp * 0.3)
	var p_hurt := _pick(l50, yx50)
	_check("yx.lv50.hurt_picks_heal_ce", p_hurt.id in [5567, 5571], p_hurt)

	# v[1491]==0 边界
	for lv in [39, 40, 50]:
		var lz := _setup_xiyou(lv, [100, 1, 2, 3], null, 0)
		var pz := _pick(lz, _actor(lz, 100))
		var want := 5571 if lv >= 50 else 5567
		_check("yx.var1491_zero.lv%d.picks_%d" % [lv, want], pz.id == want, pz)


func _yunxiao_real_turn(lv: int, want_heal: int, want_ally_states: Array, want_shield: bool) -> void:
	var logic: RecLogic = _setup_xiyou(lv, [100, 1, 2, 3], RecLogic.new())
	logic.run_events()
	var yx := _actor(logic, 100)
	var ally := _actor(logic, 1)
	ally.hp = floorf(ally.mhp * 0.4)
	var hp_before_ally: float = ally.hp
	var enemy_hp_before: float = logic.enemies[0].hp
	logic.auto = true
	logic.message_responder = func(msg): return msg.get("default", null)
	logic.turn = 0
	logic.run_turn({})

	var yx_acts := logic.acts.filter(func(x): return int(x.actor_id) == 100)
	var yx_forced := logic.forced.filter(func(x): return int(x.actor_id) == 100)
	var enemy_dmg: float = enemy_hp_before - logic.enemies[0].hp
	var ally_custom_shield: float = float(ally.state_data.get("_Shield", 0.0))
	print("BATTLE_LOG actor=100(云霄) lv=%d acts=%s forced=%s ally_hp=%.0f->%.0f ally_states=%s ally_shield=%.0f enemy_dmg=%.0f enemy_states=%s" % [
		lv, JSON.stringify(yx_acts), JSON.stringify(yx_forced), hp_before_ally, ally.hp,
		str(ally.state_ids), ally_custom_shield, enemy_dmg, str(logic.enemies[0].state_ids),
	])
	_check("yx.battle.lv%d.cast_%d" % [lv, want_heal], yx_acts.any(func(x): return int(x.id) == want_heal), yx_acts)
	_check("yx.battle.lv%d.forced_5572" % lv, yx_forced.any(func(x): return int(x.id) == 5572), yx_forced)
	_check("yx.battle.lv%d.ally_healed" % lv, ally.hp > hp_before_ally, [hp_before_ally, ally.hp])
	for st in want_ally_states:
		_check("yx.battle.lv%d.ally_state_%d" % [lv, st], ally.is_state_affected(st), ally.state_ids)
	if want_shield:
		_check("yx.battle.lv%d.ally_shield" % lv, ally_custom_shield > 0.0, ally_custom_shield)
	_check("yx.battle.lv%d.enemy_damaged" % lv, enemy_dmg > 0.0, enemy_dmg)
	_check("yx.battle.lv%d.enemy_state_1062" % lv, logic.enemies[0].is_state_affected(1062), logic.enemies[0].state_ids)
	_check("yx.battle.lv%d.no_waiting" % lv, not logic.is_event_waiting() and logic._runner == null and logic._check.is_empty())
	_check("yx.battle.lv%d.no_ce1219_skip" % lv, logic.common_event_skipped.filter(func(x): return str(x).contains("公共事件1219")).is_empty(), logic.common_event_skipped)
	_check("yx.battle.lv%d.yx_alive" % lv, yx.is_alive())


# ---- 二、全部 14 名其余同类「治疗＋安全追击 CE」角色逐一实战日志 ----
func _all_peer_healers_suite() -> void:
	# [aid, name, lv, party, want_skills(Array), want_forced(Array), hurt_mode, extra_armor, extra_skill]
	# hurt_mode: "ally"=队友残血, "self"=施放者残血(如 5525 瑞克五代/8152 逐浪), "all"=全队残血
	var peers := [
		[84,  "小毒",     50, [84, 1, 2, 3],   [5541],       [5540],       "ally", 0,    0],
		[117, "绯红蔷薇", 50, [117, 1, 2, 3],  [5781],       [5540],       "ally", 0,    0],
		[96,  "朵莉亚",   50, [96, 1, 2, 3],   [8152],       [8151, 8153], "all",  0,    0],
		[13,  "刘备",     50, [13, 1, 2, 3],   [73],         [320],        "ally", 0,    0],
		[7,   "茉蕾",     50, [7, 16, 2, 3],   [108],        [4552],       "all",  0,    0],
		[16,  "克莱德",   50, [16, 1, 2, 3],   [4550],       [4552],       "all",  0,    0],
		[31,  "露茜",     50, [31, 16, 2, 3],  [623],        [4552],       "all",  0,    0],
		[40,  "小白龙",   30, [40, 1, 2, 3],   [1118],       [1123],       "ally", 0,    0],
		[44,  "碧池",     30, [44, 1, 2, 3],   [1170],       [1172],       "ally", 0,    0],
		[77,  "玉兔精",   50, [77, 1, 2, 3],   [3759],       [3767, 3872], "all",  3636, 0],
		[81,  "申公豹",   50, [81, 1, 2, 3],   [4828],       [4833],       "all",  0,    0],
		[61,  "町甄",     50, [61, 1, 2, 3],   [5525],       [5526],       "self", 0,    0],
		[98,  "金狐",     50, [98, 97, 2, 3],  [7072],       [7062],       "all",  0,    0],
		[97,  "赤狐",     50, [97, 98, 2, 3],  [7059],       [7073],       "all",  0,    0],
	]
	for p in peers:
		var aid: int = p[0]
		var aname: String = p[1]
		var lv: int = p[2]
		var party: Array = p[3]
		var want_skills: Array = p[4]
		var want_forced: Array = p[5]
		var hurt_mode: String = p[6]
		var extra_armor: int = p[7]
		var extra_skill: int = p[8]

		var logic: RecLogic = _setup_xiyou(lv, party, RecLogic.new())
		logic.run_events()
		var me := _actor(logic, aid)
		if extra_armor > 0:
			var aitem := XDB.rec("Armors", extra_armor).duplicate(true)
			aitem["kind"] = "armor"
			aitem["base"] = extra_armor
			aitem["baseItemId"] = extra_armor
			var slot := maxi(0, int(aitem.get("etypeId", 1)) - 1)
			if slot < me.equips.size():
				me.equips[slot] = aitem
				me.refresh_passive()
				me.recover_all()
		if extra_skill > 0:
			me.learn_skill(extra_skill)
			me.refresh_passive()
		# 双生狐（97/98）互奶：给当前测试主角加临时敏捷确保先手出手，避免搭档抢先触发互奶后轮到主角时全队已满血
		if aid in [97, 98]:
			me.add_param(6, 50000.0)
			me.param_mark_dirty()
			me.param_refresh()
		# 给队友／自身按测试场景设残血，保证治疗需求成立且不会被小怪打死
		if hurt_mode == "self":
			me.hp = floorf(me.mhp * 0.2)
		elif hurt_mode == "ally":
			logic.actors[1].hp = floorf(logic.actors[1].mhp * 0.2)
		else:
			for a in logic.actors:
				a.hp = floorf(a.mhp * 0.25)

		# 1. 修前（开关关）必须全部被拦截，修后（开关开）必须全部放行
		for sid in want_skills:
			var rec := XDB.rec("Skills", int(sid))
			XSmartAI.o_xiyou_heal_ce = false
			var off_legal := XSmartAI.new(logic, me).legal(rec, false)
			XSmartAI.o_xiyou_heal_ce = true
			var on_legal := XSmartAI.new(logic, me).legal(rec, false)
			_check("peer.%d.off_block_%d" % [aid, sid], not off_legal, [aid, sid])
			_check("peer.%d.on_legal_%d" % [aid, sid], on_legal, [aid, sid, me.mp])

		# 2. 跑一整回合自动战斗（run_turn）并记录实战日志
		logic.auto = true
		logic.message_responder = func(msg): return msg.get("default", null)
		logic.turn = 0
		logic.run_turn({})

		var my_acts := logic.acts.filter(func(x): return int(x.actor_id) == aid)
		var forced_ids := logic.forced.map(func(x): return int(x.id))
		print("BATTLE_LOG actor=%d(%s) lv=%d acts=%s forced=%s" % [
			aid, aname, lv, JSON.stringify(my_acts), JSON.stringify(logic.forced)
		])
		var did_cast := my_acts.any(func(x): return int(x.id) in want_skills)
		_check("peer.%d.battle_cast" % aid, did_cast, my_acts)
		for fid in want_forced:
			_check("peer.%d.battle_forced_%d" % [aid, fid], int(fid) in forced_ids, logic.forced)
		_check("peer.%d.no_waiting" % aid, not logic.is_event_waiting() and logic._runner == null and logic._check.is_empty())

	# 额外单项校验：朵莉亚 8152(lv30) 与 8155 天籁(够 5000 MP)；露茜 5150 30% 概率分支；町甄 5527/5528 进化版放行与追击
	# 1) 朵莉亚 30 级（未学 8155 天籁）：必放 8152 逐浪并追击 8151+8153
	var d30: RecLogic = _setup_xiyou(30, [96, 1, 2, 3], RecLogic.new())
	d30.run_events()
	for a in d30.actors:
		a.hp = floorf(a.mhp * 0.3)
	d30.auto = true
	d30.message_responder = func(msg): return msg.get("default", null)
	d30.turn = 0
	d30.run_turn({})
	var d30_acts := d30.acts.filter(func(x): return int(x.actor_id) == 96)
	var d30_fids := d30.forced.map(func(x): return int(x.id))
	print("BATTLE_LOG actor=96(朵莉亚) lv=30 acts=%s forced=%s" % [JSON.stringify(d30_acts), JSON.stringify(d30.forced)])
	_check("peer.96.lv30.cast_8152", d30_acts.any(func(x): return int(x.id) == 8152), d30_acts)
	_check("peer.96.lv30.forced_8151_8153", 8151 in d30_fids and 8153 in d30_fids, d30.forced)

	# 1b) 朵莉亚 50 级补足 MP>=5000：8155 天籁修前拦、修后放行且计入 CE 1222(8151+8153) 追击分
	var d50 := _setup_xiyou(50, [96, 1, 2, 3])
	var dolia := _actor(d50, 96)
	dolia.add_param(1, 20000.0)
	dolia.param_mark_dirty()
	dolia.param_refresh()
	dolia.recover_all()
	XSmartAI.o_xiyou_heal_ce = false
	_check("peer.96.off_block_8155", not XSmartAI.new(d50, dolia).legal(XDB.rec("Skills", 8155), false))
	XSmartAI.o_xiyou_heal_ce = true
	var ai96 := XSmartAI.new(d50, dolia)
	_check("peer.96.on_legal_8155", ai96.legal(XDB.rec("Skills", 8155), false))
	var ctx96 := {"friends": d50.actors, "foes": d50.alive(d50.enemies), "urgent": false, "longFight": true, "damageScale": 1000.0}
	_check("peer.96.bonus_8155", ai96._xiyou_heal_ce_bonus(XDB.rec("Skills", 8155), false, ctx96, XDB.rec("Skills", 8155)) > 0.0)

	# 2) 露茜学 5150 雪沓流星：CE 91 的随机分支应精确产出 weight=0.30 的 5151
	var l31 := _setup_xiyou(50, [31, 1, 2, 3])
	var lucy := _actor(l31, 31)
	lucy.learn_skill(5150)
	var entries := XSmartAI.new(l31, lucy)._collect_ce_339(91, {}, 0)
	var e5151 := entries.filter(func(x): return int(x.skill_id) == 5151)
	_check("peer.31.ce91_prob_5151", e5151.size() == 1 and is_equal_approx(float(e5151[0].weight), 0.30), entries)

	# 3) 町甄 5527/5528 进化版同样修前拦、修后放行且 CE 1310/1311 解析出追击 5526
	var l61 := _setup_xiyou(50, [61, 1, 2, 3])
	var tz := _actor(l61, 61)
	for pair in [[5527, 1310], [5528, 1311]]:
		var sid: int = pair[0]
		var ceid: int = pair[1]
		tz.learn_skill(sid)
		XSmartAI.o_xiyou_heal_ce = false
		_check("peer.61.off_block_%d" % sid, not XSmartAI.new(l61, tz).legal(XDB.rec("Skills", sid), false))
		XSmartAI.o_xiyou_heal_ce = true
		var ai61 := XSmartAI.new(l61, tz)
		_check("peer.61.legal_%d" % sid, ai61.legal(XDB.rec("Skills", sid), false))
		var ce_entries := ai61._collect_ce_339(ceid, {}, 0)
		_check("peer.61.ce_collect_%d" % sid, ce_entries.any(func(x): return int(x.skill_id) == 5526), ce_entries)


# ---- 三、严格隔离（探针角色、复活技、非治疗／自残／危险 CE）----
func _isolation_and_safety() -> void:
	# 1. 原版探针角色 1/8/9/10：8 修的 3638 仍 legal=false，且开关开关选招与分数逐项一致
	var base_logic := _setup_xiyou(10, [1, 8, 9, 10])
	_actor(base_logic, 9).hp = floorf(_actor(base_logic, 9).mhp * 0.25)
	_check("iso.probe8.block_3638", not XSmartAI.new(base_logic, _actor(base_logic, 8)).legal(XDB.rec("Skills", 3638), false))
	for aid in [1, 8, 9, 10]:
		var a := _actor(base_logic, aid)
		XSmartAI.o_xiyou_heal_ce = true
		var on := _pick(base_logic, a)
		XSmartAI.o_xiyou_heal_ce = false
		var off := _pick(base_logic, a)
		XSmartAI.o_xiyou_heal_ce = true
		_check("iso.probe%d.identical" % aid, on.id == off.id and is_equal_approx(on.score, off.score) and str(on.rank) == str(off.rank), [on, off])

	# 2. 复活技仍归 o_revive_ce（默认关），不受 o_xiyou_heal_ce 影响
	var rev_logic := _setup_xiyou(50, [16, 117, 77, 81])
	var saved_rev := XSmartAI.o_revive_ce
	XSmartAI.o_revive_ce = false
	for pair in [[16, 4549], [117, 5782], [77, 3760], [81, 4829]]:
		var a := _actor(rev_logic, int(pair[0]))
		_check("iso.revive_blocked_%d" % int(pair[1]), not XSmartAI.new(rev_logic, a).legal(XDB.rec("Skills", int(pair[1])), false))
	XSmartAI.o_revive_ce = saved_rev

	# 3. 非治疗／自残／危险 CE 技能仍被拦（申公豹 4825/4826/4827、沙和尚 1112、南宫恨 6044、瑞普 5497、奈叶 5692）
	var non_heal := [
		[81, 4825], [81, 4826], [81, 4827],
		[39, 1112],
		[123, 6044],
		[56, 5497],
		[108, 5692],
	]
	for pair in non_heal:
		var aid: int = pair[0]
		var sid: int = pair[1]
		var l := _setup_xiyou(50, [aid, 1, 2, 3])
		var a := _actor(l, aid)
		_check("iso.non_heal_blocked_%d_%d" % [aid, sid], not XSmartAI.new(l, a).legal(XDB.rec("Skills", sid), false))


# ---- 四、天启篇零改动 ----
func _tianqi_zero_change() -> void:
	XTianqiSkills.reload_table()
	var s := XTianqi.start_new_game(3, "lianyu", [1, 100, 131])
	XTianqi.take_pending()
	for id in [1, 100, 131]:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in [1, 100, 131]:
		s.actor(id).change_level(60)
	s.battle_slots = [1, 100, 131, 0, 0]
	var logic := XBattleLogic.new()
	logic.setup(2, s, XBattleRandom.create("0000000000000506"))
	logic.turn = 1
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	var yx := _actor(logic, 100)
	_check("tianqi.active", XTianqi.active(s))
	_check("tianqi.has_yunxiao", yx != null)
	if yx == null:
		return
	_actor(logic, 1).hp = floorf(_actor(logic, 1).mhp * 0.4)
	XSmartAI.o_xiyou_heal_ce = true
	var on := _pick(logic, yx)
	XSmartAI.o_xiyou_heal_ce = false
	var off := _pick(logic, yx)
	XSmartAI.o_xiyou_heal_ce = true
	_check("tianqi.identical", on.id == off.id and is_equal_approx(on.score, off.score) and str(on.rank) == str(off.rank), [on, off])
	XSmartAI.o_tianqi_smart_ai = false
	var ai := XSmartAI.new(logic, yx)
	_check("tianqi.guard_blocks_xiyou_branch", not ai._xiyou_heal_ce_ok(XDB.rec("Skills", 5567), 1219))
	var ctx := {"friends": logic.actors, "foes": logic.alive(logic.enemies), "urgent": false, "longFight": true, "damageScale": 1000.0}
	_check("tianqi.guard_zero_bonus", ai._xiyou_heal_ce_bonus(XDB.rec("Skills", 5567), false, ctx, XDB.rec("Skills", 5567)) == 0.0)
	XSmartAI.o_tianqi_smart_ai = true
