extends Node
## 璇第三期星契自律与 60 级列星（归宿、星幕、法宝首次回光额外净化；XXuanBattle 内部施放、救援、列星、棱光跟打、分光、同调、璃壁、并轨 1／2 级、先照预支、同轨、回合末释放、自动战斗）
## 对原版参照 tests/fixtures/xuan_auto_oracle.json（mv_oracle/xuan_auto_probe.cjs）：每步后比星契、璇的生命魔法冷却与本场数据、队友生命护盾状态、
## 敌人生命与双防减益、这一步的 executeHpDamage 数值与台词。队伍 [177, 1, 8, 2]，3 号敌群（生命加 1e9），随机固定 0.5。
const FIXTURE := "res://tests/fixtures/xuan_auto_oracle.json"
const XUAN := 177
const PARTY := [177, 1, 8, 2]
var _party: Array = PARTY
var checks := 0
var failures: Array = []
var logic: XBattleLogic


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


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 40:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(700))


func _key(b) -> Variant:
	if b == null:
		return null
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _battle(o: Dictionary) -> XBattleLogic:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	s.actor_max_level = 99
	_party = (o.party as Array).map(func(v): return int(v)) if o.has("party") else PARTY
	for id in _party:
		s.add_actor(id)
	var a: XActor = s.actor(XUAN)
	a.change_level(int(o.get("level", 60)))
	s.actor_advance[XUAN] = int(o.get("stage", 3))
	var chart := XTusuXuan.chart(s)
	for m in o.get("marks", {}):
		chart.level[m] = int(o.marks[m])
		chart.slots[XTusuXuan.SLOT_OF[m]] = m
	if o.has("partner"):
		chart.partner = int(o.partner)
	if o.has("roster"):
		chart.roster = o.roster.map(func(v): return int(v))
	if o.has("element"):
		chart.element = int(o.element)
	XTusuXuan.sync_marks(s, a)
	if o.has("relic"):
		var slot := a.equip_slots().find(int(XDB.rec("Armors", XTusuXuan.RELICS[XUAN]).get("etypeId", 0)))
		a.equips[slot] = {}
		if bool(o.relic):
			s.gain_gear("armor", int(XTusuXuan.RELICS[XUAN]), 1)
			a.equips[slot] = s.gear.pop_back()
	XXuanChart.set_control(s, a, "manual" if bool(o.get("manual", false)) else "auto")
	for id in _party:
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var l := XBattleLogic.new()
	var rand := XBattleRandom.create("0000000000000177")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	l.setup(3, s, rand)
	for e in l.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		p[2] += float(o.get("enemyAtk", 0))
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


func _shield(b) -> Array:
	var out := []
	for r in XShieldLedger.rows(b):
		if str(r.source).begins_with("xuan."):
			out.append([str(r.source), roundi(float(r.amount)), int(r.until)])
	out.sort_custom(func(x, y): return x[0] < y[0])
	return out


func _pick(b, ids: Array) -> Array:
	var out := (b.state_ids as Array).filter(func(id): return ids.has(int(id))).map(func(id): return int(id))
	out.sort()
	return out


func _snap() -> Dictionary:
	var a: XActor = _who(XUAN)
	var h = XBinding.host(a)
	var d := XXuanBattle.data
	var bd = XBinding.data(a)
	var cd := ["huiguang", "libi", "lengguang", "liexing"].map(func(k): return a.cooldown_left(XTusuXuan.skill_id(XUAN, k)))
	var party := {}
	for id in _party.slice(1):
		var x: XActor = _who(id)
		party["a%d" % id] = {"hp": x.hp, "shield": _shield(x), "states": _pick(x, [10, 35, XXuanBattle.state_id("shadow"), XXuanBattle.state_id("hostmark"), XXuanBattle.state_id("dingxing")]),
			"home": d.get("home", {}).get(x), "mist": d.get("mist", {}).get(x)}
	var enemies := {}
	for e in logic.enemies:
		enemies[_key(e)] = {"hp": e.hp, "buffs": [e.buffs[3], e.buffs[5]]}
	var used: Array = d.get("used", {}).keys() if not d.is_empty() else []
	used.sort()
	return {"round": XBinding.current_round(), "host": ("a%d" % h.actor_id) if h != null else null, "charges": int(bd.charges) if bd != null else null,
		"auto": XXuanBattle.auto_enabled(),
		"xuan": {"hp": a.hp, "mp": a.mp, "shield": _shield(a), "cd": cd,
			"states": _pick(a, [XXuanBattle.state_id("possess"), XXuanBattle.state_id("tonggui"), XXuanBattle.state_id("debt"), XXuanBattle.state_id("liexing"), 10]),
			"data": null if d.is_empty() else {"tacit": d.tacit, "tonggui": d.tonggui, "debt": d.debt, "xianzhaoRound": d.xianzhaoRound, "liexingUntil": d.liexingUntil,
				"shadows": (d.shadows as Array).map(func(v): return int(v)), "used": used, "homeUsed": d.homeUsed, "relicHealUsed": d.relicHealUsed, "relicWallUsed": d.relicWallUsed},
			"relic": XXuanBattle.relic_on(a)},
		"party": party, "enemies": enemies}


func _hits(logs: Array) -> Array:
	var out := []
	for l in logs:
		if l is Dictionary and l.get("type") == "hit" and not bool(l.get("unused", false)) and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)) \
				and int(l.skill.get("damage", {}).get("type", 0)) in [1, 3, 5]:
			out.append(["hp", _key(l.user), _key(l.target), roundi(float(l.get("state_value", l.hp)))])
	return out


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


func _set_hp(a, v: float) -> void:
	var rc := logic._operation_resources(a)
	rc.set_resource(a, "hp", v)
	logic._finish_lifecycle_operation(rc, a)


func _step(st: Array) -> Array:
	var op: String = st[0]
	var ret = null
	var logs := []
	match op:
		"use":
			logs = logic.act(_who(st[1]), XDB.rec("Skills", XTusuXuan.skill_id(XUAN, str(st[2]))), _who(st[3]))
		"act":
			var u: XActor = _who(st[1])
			u.mp = u.mmp
			logs = logic.act(u, XDB.rec("Skills", int(st[2])), _who(st[3]))
		"hit":
			logs = logic.act(_who(st[1]), XDB.rec("Skills", int(st[2])), _who(st[3]))
		"turn":
			logs = logic.end_turn()
			logic.start_turn()
		"hp":
			var u: XActor = _who(st[1])
			_set_hp(u, maxf(1.0, floorf(u.mhp * float(st[2]))))
		"state":
			logic._state_add(_who(st[1]), int(st[2]))
		"gain":
			XBinding.gain(_who(st[1]), int(st[2]))
		"spend":
			XBinding.spend(_who(st[1]), int(st[2]))
		"tacit":
			XXuanBattle.data.tacit = int(st[1])
			XXuanBattle.data.tonggui = int(st[1]) >= 100 and XBinding.is_bound(_who(XUAN))
		"auto":
			var r: Array = logic.auto_battle_action(_who(st[1]))
			var sk: Dictionary = r[0] if r[0] != null else {}
			var k := XXuanBattle.key_of(sk)
			ret = {"skill": k if k != "" else int(sk.get("id", 0)), "target": logic.state.battle_members().find(r[1]) if r[1] != null else -1}
		"libi":
			XShieldLedger.revoke(_who(st[1]), "xuan.libi")
			XShieldLedger.grant(_who(st[1]), "xuan.libi", float(st[2]), 2, XUAN, {"noBonus": true})
		"skip":  # 敌人没有行动；角色不能行动（行动窗给普攻，也不能当成棱光的攻击）
			var u = _who(st[1])
			logs = logic.act(u, u.attack_skill() if u is XActor else null, null)
		"invalid":
			var u = _who(st[1])
			u.mp = 0.0
			logs = logic.act(u, XDB.rec("Skills", int(st[2])), _who(st[3]))
		"force":
			var i: int = logic.enemies.find(_who(st[1]))
			logs = logic._force_action([0, i, int(st[2]), logic.state.battle_members().find(_who(st[3]))], null)
		"learn":
			_who(st[1]).learn_skill(int(st[2]))
		"lv":
			_who(st[1]).change_level(int(st[2]))
		"tuse":
			var u: XActor = _who(st[1])
			u.mp = u.mmp
			logs = logic.act(u, XDB.rec("Skills", XTusu.skill_id(str(st[2]))), _who(st[3]))
		"end":
			logic.end_battle(0)
	return [ret, logs]


## 手动先制：原版 OTB 下没效果（参照 speed_*：真实流程排序前行动是空白的，硬塞璃壁才排到最前）；O-154 手动璃壁把璇排到下个回合最前，回退开关关了不动
func _order_after_libi(o: Dictionary) -> Array:
	logic = _battle(o)
	_step(["use", XUAN, "jixing", 1])
	var a: XActor = _who(XUAN)
	logic.next_order.erase(a)
	logic.next_order.append(a)
	_step(["use", XUAN, "libi", 1])
	var order: Array = logic.next_order.map(func(b): return _key(b))
	logic.end_battle(0)
	return order


func _check_manual_first(ref: Dictionary) -> void:
	var speed := {}
	for c in ref.cases:
		if str(c.id).begins_with("speed_"):
			speed[c.id] = c.observed
	check("speed.dead", speed.speed_manual.afterNext == speed.speed_nomark.afterNext and speed.speed_manual.seenInMakeSpeed == [null], speed.speed_manual)
	check("speed.control", speed.speed_manual.forcedNext[0] == "a177" and speed.speed_nomark.forcedNext[0] != "a177", speed.speed_manual.forcedNext)
	var manual := {"manual": true, "marks": {"xianzhao": 1}}
	XXuanBattle.XIANZHAO_MANUAL_FIRST = false
	var off := _order_after_libi(manual)
	check("first.off", off.back() == "a177", off)
	XXuanBattle.XIANZHAO_MANUAL_FIRST = true
	var on := _order_after_libi(manual)
	check("first.on", on[0] == "a177", on)
	var nomark := _order_after_libi({"manual": true})
	check("first.nomark", nomark.back() == "a177", nomark)
	var auto := _order_after_libi({"marks": {"xianzhao": 1}})
	check("first.auto", auto.back() == "a177", auto)


func _ready() -> void:
	_go.call_deferred()


func _go() -> void:
	GameApp.fast_headless_frames()
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("oracle", ref.cases.size() == 41 and ref.cases.all(func(c): return (c.errors as Array).is_empty()), ref.cases.size())
	for c in ref.cases:
		if str(c.id).begins_with("speed_"):
			continue
		logic = _battle(c.setup)
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
			var lines := ((out[1] as Array) + XXuanBattle.take_logs()).filter(func(l): return l is Dictionary and l.get("type") == "battle_text").map(func(l): return str(l.text))
			check(tag + ".lines", lines == (want.lines as Array), [lines, want.lines])
			var got: Dictionary = _norm(_snap())
			var ws: Dictionary = _norm(want.snap)
			ws.xuan.cd = ws.xuan.cd.map(func(v): return maxi(0, int(v)))  # 原版冷却减到负数（YEP 不夹），重制不低于 0
			if str(st[0]) == "end":
				continue  # 参照直接调 endBattle 后仍在战斗里，只看清了本场数据
			for k in ws:
				if k == "xuan" or k == "party" or k == "enemies":
					for kk in ws[k]:
						check("%s.%s.%s" % [tag, k, kk], got[k].get(kk) == ws[k][kk], [got[k].get(kk), ws[k][kk]])
				else:
					check("%s.%s" % [tag, k], got.get(k) == ws[k], [got.get(k), ws[k]])
		if XBinding.in_battle():
			logic.end_battle(0)
	_check_manual_first(ref)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_xuan_auto", "passed": checks - failures.size(), "total": checks, "failures": failures.slice(0, 50)}))
	get_tree().quit(0 if failures.is_empty() else 1)
