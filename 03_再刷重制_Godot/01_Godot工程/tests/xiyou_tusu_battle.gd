extends Node
## 【cc·白龙_14·未经审查】176 屠苏第三期 XTusu：照参照 tusu_battle_probe（tests/fixtures/tusu_battle_oracle.json）逐步比。
## 新局开 2494、招屠苏（送止戈环），队伍 [1, 8, 176, 10]，按例设等级；打 3 号敌群（敌人生命加 1e9），规则流全取 0.5，推进到第一回合。
## 每步比：返回值、命中，屠苏的本场数据、上次武相、绑定数据、带 Codex 标签的状态、生命魔法与四维、攻击技能号、一组专属技能的
## 能用／付得起／面板 MP，三位队友的状态、魔法、双防与七个武装技能，各键的 payer、各武相能否维持，宿主，出战成员。
## 「能用」对 MV canUse（meetsSkillConditions 含付费），比 XBattleLogic.can_use；「付得起」比噬主包装或 MP／TP 够不够。
const FIXTURE := "res://tests/fixtures/tusu_battle_oracle.json"
const TUSU := 176
const PARTY := [1, 8, 176, 10]
const TUSU_KEYS := ["return", "menu.forge", "body.phys", "body.mag", "body.guard", "yiwu.sword", "yiwu.bow", "yiwu.shield", "yiwu.book", "yiwu.hammer",
	"huawu.sword", "huawu.bow", "huawu.shield", "huawu.book", "huawu.hammer", "support.jianqi", "support.suoding", "support.jintang", "support.heming", "support.zhenhun"]
const ARM_KEYS := ["arm.zhanfeng", "arm.hengsao", "arm.dianshe", "arm.guanri", "arm.huzhen", "arm.chiling", "arm.zhenji"]
const PAY_KEYS := ARM_KEYS + ["support.jianqi", "support.suoding", "support.jintang", "support.heming", "support.zhenhun"]
## 参照里已经记了、重制还没做完的例（四期剩余，做完删掉这一行再比）
const PENDING := {}
var checks := 0
var failures: Array = []
var logic: XBattleLogic


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 25:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))


## 同参照 Math.random 0.5；整数照 Math.randomInt 取中点（直接返回 2147483648 时伤害浮动会乱跳，见 xiyou_raven_battle）
class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * 0.5) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * 0.5)


## 屠苏还没进切片（A 车道），重制里她的能力值与原版对不上（30 级魔攻、5／60 级各项）：这里把六项能力值钉成参照开局记的值，
## 只比本期的逻辑（费用按最大 MP、基准按物攻魔攻、补底按双防）。进切片后去掉这个类再比一次。
class TusuActor extends XActor:
	var fixed: Array = []
	func param(i: int) -> float:
		return float(fixed[i]) if i < fixed.size() else super.param(i)


func _key(b) -> Variant:
	if b == null:
		return null
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _battle(levels: Dictionary, start: Dictionary) -> XBattleLogic:
	var s := XState.new_game(2, 1, [8, 10])
	XState.current = s
	var t := TusuActor.new()
	t.setup(TUSU)
	var ts: Dictionary = start.tusu
	t.fixed = [ts.hp, ts.mmp, ts.atk, ts.def, ts.mat, ts.mdf]
	s.actors[TUSU] = t
	s.actor_max_level = 99
	s.switches[2494] = true
	XTusuXuan.recruit(s, TUSU)
	s.party.clear()
	s.battle_slots.clear()
	for id in PARTY:
		s.add_actor(id)
	for id in levels:
		s.actor(int(id)).change_level_mv(int(levels[id]))
	for id in PARTY:
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var l := XBattleLogic.new()
	l.elite_roll = 99.0
	l.level_roll = 0.99
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	l.setup(3, s, rand)
	for e in l.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	l.start_turn()
	for b in l.actors + l.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return l


func _who(x):
	if x is String and x.begins_with("e"):
		return logic.enemies[int(x.substr(1))]
	return logic.state.actor(int(x))


func _states(a) -> Array:
	var out := (a.state_ids as Array).filter(func(id): return RegEx.create_from_string("<Codex(?:Tusu|Bind):").search(str(XDB.rec("States", int(id)).get("note", ""))) != null)
	out.sort()
	return out


func _row(a, key: String) -> Array:
	var s := XDB.rec("Skills", XTusu.skill_id(key))
	var c := logic.skill_cost(a, s)
	var tp = XTusu.can_pay(a, s, float(c.tp))
	return [logic.can_use(a, s) and logic.can_move(a), bool(tp) if tp != null else (a.mp >= float(c.mp) and a.tp >= float(c.tp)), int(c.mp)]


func _snap() -> Dictionary:
	var t: XActor = _who(TUSU)
	var d = XTusu.data(t)
	var bd = XBinding.data(t)
	var h = XBinding.host(t)
	var skills := {}
	for k in TUSU_KEYS:
		skills[k] = _row(t, k)
	var out := {"round": XBinding.current_round(), "tusu": {"data": null if d == null else {"weapon": d.weapon, "reserve": d.reserve, "pending": d.pending,
		"hostActions": int(d.host_actions),
		"trigger": float(d.trigger), "growth": int(d.growth)}, "last": logic.state.flags.get(XTusu.LAST_FLAG), "bind": null if bd == null else {"charges": int(bd.charges),
		"hostId": int(bd.host_id), "returnedRound": int(bd.returned_round)}, "states": _states(t), "hp": t.hp, "mp": t.mp, "mmp": t.mmp, "atk": t.atk,
		"mat": t.mat, "def": t.def, "mdf": t.mdf, "attack": t.attack_skill_id(), "canMove": logic.can_move(t), "skills": skills,
		"guard": logic.can_use(t, XDB.rec("Skills", 2)) and logic.can_move(t), "atk1": logic.can_use(t, XDB.rec("Skills", 1)) and logic.can_move(t)}, "party": {}}
	for id in [1, 8, 10]:
		var a: XActor = _who(id)
		var arm := {}
		for k in ARM_KEYS:
			arm[k] = _row(a, k)
		out.party["a%d" % id] = {"states": _states(a), "hp": a.hp, "mp": a.mp, "mmp": a.mmp, "def": a.def, "mdf": a.mdf, "shield": XShieldLedger.amount(a), "arm": arm}
	var payer := {}
	for k in PAY_KEYS:
		var p := XTusu.payer(k)
		payer[k] = null if p == "" else p
	out.payer = payer
	var keep := {}
	for w in XTusu.WEAPONS:
		keep[w] = XTusu.can_maintain(w)
	out.maintain = keep
	out.host = _key(h)
	out.members = logic.actors.map(func(b): return _key(b))
	var locks := {}
	for id in [1, 8, 10]:
		if XTusu.lock_target(_who(id)) != null:
			locks["a%d" % id] = _key(XTusu.lock_target(_who(id)))
	out.locks = locks
	var cd := {}
	for k in ["support.jianqi", "support.suoding", "support.jintang", "support.heming", "support.zhenhun"]:
		cd[k] = maxi(0, t.cooldown_left(XTusu.skill_id(k)))
	out.cooldown = cd
	var e0: XBattler = logic.enemies[0]
	var c = XTusu.cuoshi_of(e0)
	var es := (e0.state_ids as Array).filter(func(id): return int(id) == XTusu.STUN_STATE or RegEx.create_from_string("<CodexTusu:").search(str(XDB.rec("States", int(id)).get("note", ""))) != null)
	es.sort()
	out.e0 = {"cuoshi": null if c == null else {"rate": c.rate, "stack": c.stack, "until": c.until}, "states": es}
	return out


func _hits(logs: Array) -> Array:
	var out := []
	for l in logs:
		if l is Dictionary and l.get("type") == "hit" and not bool(l.get("unused", false)) and not bool(l.missed) and not bool(l.evaded) \
				and int(l.skill.get("damage", {}).get("type", 0)) in [1, 3, 5]:
			out.append(["hp", _key(l.user), _key(l.target), float(l.get("state_value", l.hp))])  # 参照记 executeHpDamage 收到的值（护盾吸收之前）
	return out


func _set_hp(a, v: float) -> void:
	var rc := logic._operation_resources(a)
	rc.set_resource(a, "hp", v)
	logic._finish_lifecycle_operation(rc, a)


## 参照的 JSON 数字都是 float：整数值转 int 再比
func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	return v


func _step(st: Array) -> Array:
	var op: String = st[0]
	var ret = null
	var logs := []
	match op:
		"use":
			var tgt = _who(st[3]) if st.size() > 3 and st[3] != null else null
			logs = logic.act(_who(st[1]), XDB.rec("Skills", XTusu.skill_id(str(st[2]))), tgt)
		"act":
			logs = logic.act(_who(st[1]), XDB.rec("Skills", int(st[2])), logic.enemies[int(st[3])])
		"turn":
			logs = logic.end_turn()
			logic.start_turn()
		"mp":
			var a: XActor = _who(st[1])
			a.mp = clampf(float(st[2]), 0.0, a.mmp)
		"pay":
			var a: XActor = _who(st[1])
			var s := XDB.rec("Skills", XTusu.skill_id(str(st[2])))
			a.action_mastery.clear()
			logic.pay_skill_cost(a, s)  # 与 execute 同一个付费：噬主包装＋里层（异化、扣费、HP 费用、熟练度记次）＋冷却
			ret = {"tusu": _who(TUSU).mp, "self": a.mp, "mastery": a.action_mastery.duplicate()}
		"arm":
			var a: XActor = _who(st[1])
			var s := XDB.rec("Skills", XTusu.skill_id(str(st[2])))
			logs = logic.act(a, s, logic.enemies[int(st[3])])
			ret = {"uses": XSkillMastery.uses(a, int(s.id))}
		"state":
			_who(st[1]).add_state(XTusu.state_id(str(st[2])))
		"hit":
			# 参照的 begin 直接 startAction，眩晕（震击挂上的）的敌人照样出手；重制的 act 会跳过不能行动的人，这里先拿掉眩晕再放回
			var e = _who(st[1])
			var stunned: bool = e.state_ids.has(XTusu.STUN_STATE)
			if stunned:
				e.state_ids.erase(XTusu.STUN_STATE)
			logs = logic.act(e, XDB.rec("Skills", int(st[2])), _who(st[3]))
			if stunned and not e.state_ids.has(XTusu.STUN_STATE):
				e.state_ids.append(XTusu.STUN_STATE)
		"sup":
			logs = logic.act(_who(st[1]), XDB.rec("Skills", XTusu.skill_id(str(st[2]))), logic.enemies[int(st[3])] if int(st[3]) >= 0 else null)
		"gain":
			XBinding.gain(_who(st[1]), int(st[2]))
		"sethp":
			_set_hp(_who(st[1]), float(st[2]))
		"kill":
			_set_hp(_who(st[1]), 0.0)
		"revive":
			var a: XActor = _who(st[1])
			a.remove_state(1)
			_set_hp(a, a.mhp)
		"cost":
			ret = {"mp": int(logic.skill_cost(_who(st[1]), XDB.rec("Skills", int(st[2]))).mp)}
		"formula":
			var a: XActor = _who(st[1])
			ret = {"damage": XTusu.damage(a, logic.enemies[0], str(st[2])), "sword": XTusu.base(a, "sword"), "book": XTusu.base(a, "book"),
				"coef": XTusu.coefficient(str(st[2]))}
		"end":
			logic.end_battle(0)
	return [ret, logs]


func _ready() -> void:
	_go.call_deferred()


func _go() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref.cases.size() == 9 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	for c in ref.cases:
		if PENDING.has(c.id):
			print("SKIP ", c.id, "：", PENDING[c.id])
			continue
		logic = _battle(c.setup.levels, c.observed[0].snap)
		var steps: Array = c.observed
		check(c.id + ".start", _norm(_snap()) == _norm(steps[0].snap), [_snap(), steps[0].snap])
		for i in range(1, steps.size()):
			var want: Dictionary = steps[i]
			var st: Array = want.step
			var tag := "%s.%d.%s" % [c.id, i, str(st[0])]
			var out: Array = _step(st)
			if want.ret != null or out[0] != null:
				check(tag + ".ret", _norm(out[0]) == _norm(want.ret), [out[0], want.ret])
			check(tag + ".hits", _norm(_hits(out[1])) == _norm(want.hits), [_hits(out[1]), want.hits])
			var got: Dictionary = _norm(_snap())
			var ws: Dictionary = _norm(want.snap)
			for k in ws.get("cooldown", {}):
				ws.cooldown[k] = maxi(0, int(ws.cooldown[k]))  # 原版冷却减到负数（YEP 不夹），重制剩余回合不低于 0
			if str(st[0]) == "end":
				# 参照的宿主战斗结束后 inBattle 还是真，技能条件、费用、payer 还按战斗中算；重制已经出了战斗。只比清理结果
				for x in [got, ws]:
					for k in ["round", "payer", "maintain", "host", "members", "cooldown"]:
						x.erase(k)
					for k in ["attack", "skills", "guard", "atk1", "canMove", "def", "mdf"]:
						x.tusu.erase(k)
					for id in x.party:
						# 参照直接调 endBattle，不走 onBattleEnd：护阵（战斗结束解除）留在身上；重制结束时照常删。护阵不比，持武等由屠苏自己清的照比
						x.party[id] = {"states": (x.party[id].states as Array).filter(func(sid): return int(sid) != XTusu.state_id("huzhen")), "hp": x.party[id].hp, "mp": x.party[id].mp}
					x.e0 = {"cuoshi": x.e0.cuoshi}  # 敌人的挫势、眩晕状态同理不比；挫势记录两边都清（XTusu.clear）
			for k in ws:
				if k == "tusu" or k == "party":
					for kk in ws[k]:
						check("%s.%s.%s" % [tag, k, kk], got[k].get(kk) == ws[k][kk], [got[k].get(kk), ws[k][kk]])
				else:
					check("%s.%s" % [tag, k], got.get(k) == ws[k], [got.get(k), ws[k]])
		if XBinding.in_battle():
			logic.end_battle(0)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_tusu_battle", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
