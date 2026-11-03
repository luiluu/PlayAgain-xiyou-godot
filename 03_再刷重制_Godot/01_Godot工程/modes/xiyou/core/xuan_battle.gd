class_name XXuanBattle
extends RefCounted
## 【cc·悟空·未经审查】璇的战斗效果第一期（正式 js/codex/runtime/installNativeXuanRuntime.js）：不靠绑定就成立的部分。
## 本场数据（fresh）、净化口径（isCleanseState）、MP 费用（按璇 MP 上限百分比）、技能条件、回光净化、定星、璃壁护盾、棱光减益、蚀辉、结束清标记。
## 余辉不做：原版包在 Game_Battler.gainHp 上，而回光只打角色，角色的 gainHp 是 Game_Actor 自有方法，这层跑不到，实测溢出不转护盾（见交付单「需要用户决定」）。
## 第二期：绑定种类登记、寄星／转移／回身、星纹标记、默契结算、附身期间不掉血、移光、留辉、共宿（伤害、双防、并轨 3 级）、列星（星影、目标扩展、到期）、
## 星盾流转定轨（10 级）与接力（20 级，installThreeGrowthRelicRuntime）、护盾挡下计护主（mv_oracle/xuan_bind_probe.cjs → tests/xiyou_xuan_bind）。
## 先照手动先制（Game_Action.speed +100000）没接：OTB 下 action.speed 怎么用还没量；璇玑星盘首回合星契 firstCharge 是 0，不做；60 级列星法宝特效在第三期。
## 星纹标记原版的 removeState 补回不做：包在 Game_Battler 上，角色走 Game_Actor 自有方法，实测移除后不补回。
## 星契自律（内部施放、同轨、先照预支、分光、同调）在第三期，盘点见交付单 cc_wukong-xuan2。
## 参照 mv_oracle/xuan_battle_probe.cjs → tests/fixtures/xuan_battle_oracle.json（tests/xiyou_xuan_battle）。

const XUAN := 177
const MP_RATE := {"huiguang": 0.06, "lengguang": 0.05, "libi": 0.08, "liexing": 0.15}
const LIBI_MAT := 300.0
const LIBI_HP := 2.0
const LIBI_TURNS := 2
const LENGGUANG_DEBUFF_TURNS := 2
const SHIHUI_EVERY := [0, 3, 2, 1]
## 蚀辉驱散增益的顺序（物防、魔防、物攻、魔攻、敏捷、幸运）
const SHIHUI_ORDER := [3, 5, 2, 4, 6, 7]
const WEIGHT_VALUES := [0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
const WEIGHT_LEVELS := [1, 10, 20, 30, 40, 50, 60]
const NO_CLEANSE := "无法解除|不可驱散|不能解除|Cannot Remove"
const SOFT_TYPES := "<BuffType:\\s*(?:减益|控制|诅咒|中毒|毒|麻痹|眩晕|混乱|睡眠|魅惑|愤怒|封印|减速|流血)"

## 本场数据（a._codexXuan，不进存档）：只有一个璇，空字典＝不在战斗里
static var data := {}
## <CodexXuan: 键> 的状态编号
static var _states := {}
## 战斗日志台词（CFG.lines），由 battle_logic 取走
static var _logs := []
const TACIT_STAY := 10
const TACIT_PROTECT := 5
const TACIT_ASSIST := 5
const TACIT_PER_ROUND := 20
const TACIT_KEEP := 0.5
const TACIT_ROSTER_KEEP := 0.75
const GONGSU_DMG := [[0.10, 0.30], [10, 60]]
const GONGSU_DEF := [[0.15, 0.30], [20, 60]]
const YIGUANG_RATE := [0.0, 0.5, 0.75, 1.0]
const LIEXING_TURNS := 2
static var _param_guard := false
const LINES := {"transfer": "璇：「我去另一边，有事叫我。」"}


static func take_logs() -> Array:
	var out := _logs
	_logs = []
	return out


static func _line(key: String) -> void:
	_logs.append({"type": "battle_text", "text": str(LINES[key])})


## registerBinding
static func register_kind() -> void:
	if XBinding.kinds.has("xuan"):
		return
	XBinding.register("xuan", {
		"is_owner": func(a): return is_xuan(a),
		"manual": func(_a): return not auto_enabled(),
		"form_state": state_id("possess"), "empty_state": XTusu.state_id("empty"), "blocks_hp_loss": true,
		"on_bind": _on_bind, "on_unbind": _on_unbind, "on_round_start": _on_round_start, "on_round_end": _round_end_release, "on_round_close": _on_round_close,
		"on_clear": func(_a): data = {}})


static func _d() -> Dictionary:
	if data.is_empty():
		data = _fresh()
	return data


static func _on_bind(owner, target, _reason, previous) -> void:
	var logic = XBinding._logic()
	var d := _d()
	_mark_host(logic, target, true)
	# 开战默认绑定（原因 opening 的名册起始默契）原版算了但不绑，走不到
	var s: XState = logic.state
	var keep: float = TACIT_ROSTER_KEEP if _is_roster(s, target) or (previous != null and _is_roster(s, previous)) else TACIT_KEEP
	d.tacit = floori(int(d.tacit) * keep)
	d.record.transferRound = XBinding.current_round()
	if previous != null:
		_transfer_effects(logic, owner, previous, target)
	_line("transfer")
	d.tonggui = int(d.tacit) >= 100
	_sync_counters(logic, owner)
	owner.refresh_passive()
	target.refresh_passive()
	if previous != null and int(owner.level) >= 20:
		_relay(logic, owner, previous, target)


static func _on_unbind(owner, target, reason) -> void:
	var logic = XBinding._logic()
	if target != null:
		_mark_host(logic, target, false)
		target.refresh_passive()
	if str(reason) != "transfer" and not data.is_empty():
		data.tonggui = false
		_sync_counters(logic, owner)


static func _on_round_start(owner, n) -> void:
	var logic = XBinding._logic()
	var d := _d()
	if int(d.debt) > 0 and int(n) > 0:
		var pay := mini(int(d.debt), XBinding.charges(owner))
		d.debt = int(d.debt) - pay
		XBinding.spend(owner, pay)
	var h = XBinding.host(owner)
	d.used = {}
	d.record = {"round": XBinding.current_round(), "stayed": int(h.actor_id) if h != null else 0}
	_sync_counters(logic, owner)


## settleTacit
static func _on_round_close(owner) -> void:
	var logic = XBinding._logic()
	if data.is_empty():
		return
	var r: Dictionary = data.record
	var h = XBinding.host(owner)
	var gain := 0
	if h != null and int(r.get("stayed", 0)) == int(h.actor_id) and int(r.get("transferRound", -1)) != XBinding.current_round():
		gain += TACIT_STAY
	var acted: bool = bool(r.get("protect", false)) or bool(r.get("assist", false))
	if bool(r.get("protect", false)):
		gain += TACIT_PROTECT
	if bool(r.get("assist", false)):
		gain += TACIT_ASSIST
	var extra := floori(XGuyu.curve(int(owner.level), [1, 3], [20, 60])) if acted and int(owner.level) >= 20 else 0
	data.tacit = mini(100, int(data.tacit) + mini(TACIT_PER_ROUND, gain) + extra)
	data.tonggui = int(data.tacit) >= 100 and XBinding.is_bound(owner)
	_sync_counters(logic, owner)
	# 列星到期
	if int(data.liexingUntil) >= 0 and XBinding.current_round() >= int(data.liexingUntil):
		for id in data.shadows:
			var x: XActor = logic.state.actor(int(id))
			if x != null and x.state_ids.has(state_id("shadow")):
				logic._state_remove(x, state_id("shadow"))
		data.shadows = []
		data.liexingUntil = -1
		if owner.state_ids.has(state_id("liexing")):
			logic._state_remove(owner, state_id("liexing"))


static func _is_roster(s: XState, t) -> bool:
	var c := XTusuXuan.chart(s)
	return t != null and (c.roster as Array).slice(0, XXuanChart.stage(s)).has(int(t.actor_id))


static func _mark_host(logic, target, on: bool) -> void:
	var id := state_id("hostmark")
	if on and not target.state_ids.has(id):
		logic._state_add(target, id)
	elif not on and target.state_ids.has(id):
		logic._state_remove(target, id)


## syncCounters：同轨、先照债务的显示状态
static func _sync_counters(logic, a) -> void:
	if data.is_empty():
		return
	for p in [["tonggui", bool(data.tonggui)], ["debt", int(data.debt) > 0]]:
		var id := state_id(str(p[0]))
		if bool(p[1]) and not a.state_ids.has(id):
			logic._state_add(a, id)
		elif not bool(p[1]) and a.state_ids.has(id):
			logic._state_remove(a, id)


## Game_Action.apply 包装：寄星、转移、回身不走普通结算
static func apply_command(_logic_node, u, skill: Dictionary, t) -> Dictionary:
	if not is_xuan(u):
		return {}
	var key := key_of(skill)
	if not key in ["jixing", "jixing.possess", "return"]:
		return {}
	t.runtime_result = XResourceContext.empty_result()
	if key == "return":
		XBinding.unbind(u, "return")
	elif XBinding.can_host(u, t) and t != XBinding.host(u):
		if key == "jixing":
			XBinding.bind(u, t, "jixing")
		elif not auto_enabled() or XBinding.spend(u, 1):
			_d().used.jixing = true
			XBinding.bind(u, t, "transfer")
	return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false, "success": true,
		"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}


## 指令窗「回身」（Window_ActorCommand.makeCommandList 包装）
static func command_entries(logic, a) -> Array:
	if not is_xuan(a) or not XBinding.is_bound(a):
		return []
	return [{"text": "回身", "key": "xuanReturn", "enabled": logic.can_use(a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, "return")))}]


## Window_BattleActor.isCurrentItemEnabled 包装：寄星只能选合法宿主
static func filter_pick(a, skill: Dictionary, pool: Array) -> Array:
	if not is_xuan(a) or not key_of(skill) in ["jixing", "jixing.possess"]:
		return pool
	return pool.filter(func(t): return XBinding.can_host(a, t) and t != XBinding.host(a))


static func is_xuan(a) -> bool:
	return a is XActor and int(a.actor_id) == XUAN


static func key_of(skill: Dictionary) -> String:
	var o := XTusuXuan.owner_of(int(skill.get("id", 0)))
	return str(o[1]) if int(o[0]) == XUAN else ""


static func state_id(key: String) -> int:
	if _states.is_empty():
		var re := RegEx.create_from_string("<CodexXuan:\\s*([^>]+)>")
		for st in XDB.table("States"):
			if st is Dictionary:
				var m := re.search(str(st.get("note", "")))
				if m:
					_states[m.get_string(1).strip_edges()] = int(st.id)
	return int(_states.get(key, 0))


## fresh
static func _fresh() -> Dictionary:
	return {"tacit": 0, "tonggui": false, "debt": 0, "xianzhaoRound": -99, "liexingUntil": -1, "shadows": [], "record": {}, "dingxing": {}, "shihuiRound": -99, "used": {}, "auto": false}


## startBattle 包装：出战的璇建本场数据，记下这一场的星契自律
static func start_battle(logic) -> void:
	data = {}
	for a in logic.actors:
		if is_xuan(a):
			data = _fresh()
			data.auto = XXuanChart.auto_qualified(logic.state, a) and XXuanChart.control(logic.state) == "auto"


## endBattle 包装：全队去掉星纹、星影、定星标记（eraseState）
static func end_battle(s: XState) -> void:
	data = {}
	for id in s.party:
		var a: XActor = s.actor(int(id))
		for key in ["hostmark", "shadow", "dingxing"]:
			var st := state_id(key)
			if a.state_ids.has(st):
				a.state_ids.erase(st)
				a.state_turns.erase(st)
				a.refresh_passive()


## X.autoEnabled（战斗中）
static func auto_enabled() -> bool:
	return not data.is_empty() and bool(data.auto)


## X.isCleanseState
static func is_cleanse_state(st: Dictionary, hard: bool) -> bool:
	if st.is_empty() or int(st.id) == 1:
		return false
	var note := str(st.get("note", ""))
	if RegEx.create_from_string("(?i)" + NO_CLEANSE).search(note):
		return false
	if int(st.get("restriction", 0)) > 0:
		return true
	return not hard and RegEx.create_from_string(SOFT_TYPES).search(note) != null


## cleansable(t)[0]：第一个可净化的硬控制，没有返回 0
static func first_cleansable(t: XBattler) -> int:
	for st in t.states():
		if is_cleanse_state(st, true):
			return int(st.id)
	return 0


## X.weight
static func weight(a) -> float:
	return XGuyu.curve(int(a.level), WEIGHT_VALUES, WEIGHT_LEVELS)


## X.shieldAmount
static func shield_amount(a, t) -> float:
	return maxf((LIBI_MAT * float(a.mat) + LIBI_HP * float(a.mhp)) * weight(a), XGuyu.curve(int(a.level), [0.15, 0.35], [1, 60]) * float(t.mhp))


## skillMpCost 包装
static func mp_cost(a, skill: Dictionary, native: int) -> int:
	var key := key_of(skill)
	if key != "" and is_xuan(a) and MP_RATE.has(key):
		return XTusu.percent_cost(a, skill, float(MP_RATE[key]))
	return native


## meetsSkillConditions 包装（bindGrowth 的解锁与回身在 XTusuXuan.meets）
static func meets(a, skill: Dictionary) -> bool:
	var key := key_of(skill)
	if key == "menu.starchart":
		return not XBinding.in_battle()
	if not is_xuan(a) or not XBinding.in_battle():
		return true
	var bound := XBinding.is_bound(a)
	if bound and auto_enabled() and int(skill.id) != XBattleLogic.GUARD_SKILL and not key in ["jixing.possess", "return"]:
		return false
	match key:
		"jixing.possess":
			return bound and (not auto_enabled() or XBinding.charges(a) >= 1) and not data.get("used", {}).has("jixing")
		"jixing":
			return not bound
		"liexing":
			return bound and not auto_enabled()
	return true


## applyItemUserEffect 包装（原效果之后）：回光净化、璃壁护盾、棱光减益与蚀辉
static func user_effect(logic, u, skill: Dictionary, t: XBattler) -> void:
	if not is_xuan(u):
		return
	match key_of(skill):
		"huiguang":
			var bad := first_cleansable(t)
			if bad > 0:
				logic._state_remove(t, bad)
				if XXuanChart.mark_level(logic.state, u, "dingxing") >= 1:
					_grant_dingxing(logic, u, t)
			if not data.is_empty():
				data.record.protect = true
			_tonggui_strike(logic, u)  # 同轨：回光内置一次棱光式协同
		"libi":
			XShieldLedger.grant(t, "xuan.libi", shield_amount(u, t), LIBI_TURNS, XUAN)
			_tonggui_strike(logic, u)
		"liexing":
			_liexing(logic, u)
			_tonggui_strike(logic, u)
		"lengguang":
			if t is XEnemy and t.is_alive():
				logic.sequence_buff(t, 3, true, false, LENGGUANG_DEBUFF_TURNS)
				logic.sequence_buff(t, 5, true, false, LENGGUANG_DEBUFF_TURNS)
				_shihui(logic, u, t)
				if not data.is_empty():
					data.record.assist = true


## 蚀辉：每 3／2／1 回合驱散一项增益
static func _shihui(logic, u, t: XBattler) -> void:
	var lv := XXuanChart.mark_level(logic.state, u, "shihui")
	if lv <= 0 or XBinding.current_round() - int(data.shihuiRound) < int(SHIHUI_EVERY[lv]):
		return
	for pid in SHIHUI_ORDER:
		if t.buffs[pid] > 0:
			logic.sequence_buff(t, pid, false, true, 0)
			data.shihuiRound = XBinding.current_round()
			return


## 定星：2 级起（列星期间 1 级也行），下一个完整回合内挡一次硬控制
static func _grant_dingxing(logic, u, t: XBattler) -> void:
	var lv := XXuanChart.mark_level(logic.state, u, "dingxing")
	if data.is_empty() or (lv < 2 and XBinding.current_round() > int(data.liexingUntil)):
		return
	data.dingxing[int(t.actor_id)] = {"until": XBinding.current_round() + 1, "numeric": lv >= 3}
	logic._state_add(t, state_id("dingxing"))


## addState 包装（真正生效的是 installThreeGrowthRelicRuntime 包在 Game_Actor 上那层）：定星挡一次还没有的可净化硬控制。挡下返回真。
## 包在最外层，抗性挡下的硬控也先消耗定星（审查 33 P3-3）；璇要在出战成员里；挡下时不写台词：外层那层直接 return，
## 写台词的 Game_Battler 那层走不到（xuan_battle_probe dingxing.effect_line／benched，审查 33 P3-4）。
## 绕开资源上下文直接加状态、又可能给角色加硬控的路径（事件更改状态 sequence_add_state、技能附加被抗性挡下、异化囚厄接收）都先问这里。
static func blocks_state(t: XBattler, id: int) -> bool:
	if data.is_empty() or not t is XActor or t.state_ids.has(id) or not XBinding.in_battle() or xuan() == null:
		return false
	var guard = data.dingxing.get(int(t.actor_id))
	if guard == null or not is_cleanse_state(XDB.rec("States", id), true) or int(guard.until) < XBinding.current_round():
		return false
	data.dingxing.erase(int(t.actor_id))
	var mark := state_id("dingxing")
	if t.state_ids.has(mark):
		t.remove_state(mark)
	return true


## 出战的璇（xuan()）
static func xuan():
	for a in XBinding.members():
		if is_xuan(a):
			return a
	return null


static func _live(b) -> bool:
	return b != null and b.is_alive() and b.hp > 0.0


## beneficiaries：主宿主＋列星期间的星影；并轨副宿主另给
static func beneficiaries(a) -> Dictionary:
	var h = XBinding.host(a)
	var list := [h] if _live(h) else []
	var logic = XBinding._logic()
	var members := XBinding.members()
	if not data.is_empty() and XBinding.current_round() <= int(data.liexingUntil):
		for id in data.shadows:
			var t = logic.state.actor(int(id))
			if _live(t) and not XBinding.untargetable(t) and members.has(t) and not list.has(t):
				list.append(t)
	var pid := int(XXuanChart.chart(logic.state).get("partner", 0))
	var partner = logic.state.actor(pid) if pid > 0 else null
	return {"list": list, "partner": partner if partner != null and partner != h and _live(partner) and members.has(partner) else null}


static func in_cover(a, t) -> bool:
	return (beneficiaries(a).list as Array).has(t)


static func _gongsu(a) -> bool:
	return a != null and a.skill_ids.has(XTusuXuan.skill_id(XUAN, "gongsu")) and XTusuXuan.unlocked(XUAN, a, "gongsu")


## X.gongsuDamageRate／gongsuDefenseRate
static func gongsu_damage_rate(a) -> float:
	return XGuyu.curve(int(a.level), GONGSU_DMG[0], GONGSU_DMG[1]) if _gongsu(a) else 0.0


static func gongsu_defense_rate(a) -> float:
	return XGuyu.curve(int(a.level), GONGSU_DEF[0], GONGSU_DEF[1]) if _gongsu(a) else 0.0


static func gongsu_value(a, i: int) -> float:
	return floorf(gongsu_defense_rate(a) * float(a.def if i == 3 else a.mdf))


## Game_Actor.param 包装：附身时宿主（含星影）、并轨 3 级副宿主、留辉的旧宿主拿璇双防的一份，同源取较高值
static func param(a, i: int, v: float) -> float:
	if (i != 3 and i != 5) or _param_guard or not a is XActor or is_xuan(a) or not XBinding.in_battle():
		return v
	var x = xuan()
	if x == null or not x.skill_ids.has(XTusuXuan.skill_id(XUAN, "gongsu")):
		return v
	_param_guard = true
	var bonus := 0.0
	if XBinding.is_bound(x) and in_cover(x, a):
		bonus = gongsu_value(x, i)
	var part := 0.0
	var glow := 0.0
	if not data.is_empty():
		var s: XState = XBinding._logic().state
		if int(XXuanChart.chart(s).get("partner", 0)) == int(a.actor_id) and XXuanChart.mark_level(s, x, "binggui") >= 3:
			part = gongsu_value(x, i)
		var g: Dictionary = data.get("afterglow", {}).get(int(a.actor_id), {})
		if not g.is_empty() and int(g.until) >= XBinding.current_round():
			glow = float(g.def if i == 3 else g.mdf)
	_param_guard = false
	return v + maxf(bonus, maxf(part, glow))


## 伤害钩子 xuan-host-offense：主宿主与星影的直接伤害 ×(1＋共宿伤害率)，只对 HP 伤害、吸收，normal／true
static func damage_ops(item: Dictionary, a) -> Array:
	if not XBinding.in_battle() or not a is XActor or is_xuan(a) or not int(item.get("damage", {}).get("type", 0)) in [1, 5]:
		return []
	if not str(XRaceBattle._damage_spec(item).get("kind", "normal")) in ["normal", "true"]:
		return []
	var x = xuan()
	if not _live(x) or not _gongsu(x) or not in_cover(x, a):
		return []
	return [{"op": "mul", "field": "finalMultiplier", "value": 1.0 + gongsu_damage_rate(x)}]


## 移光：换宿主迁移旧宿主身上璇护盾的 50%／75%／100%；留辉：旧宿主保留共宿增益 1／2／3 回合
static func _transfer_effects(logic, a, previous, target) -> void:
	var s: XState = logic.state
	var lv := XXuanChart.mark_level(s, a, "yiguang")
	if lv > 0:
		var moved := 0.0
		for src in ["xuan.libi", "xuan.yuhui"]:
			var v := XShieldLedger.amount(previous, src)
			if v > 0.0:
				var m := floorf(v * float(YIGUANG_RATE[lv]))
				XShieldLedger.revoke(previous, src)
				if v - m > 0.0:
					XShieldLedger.grant(previous, src, v - m, 1, XUAN)
				moved += m
		if moved > 0.0:
			XShieldLedger.grant(target, "xuan.libi", moved, 1, XUAN)
	var keep := XXuanChart.mark_level(s, a, "liuhui")
	data.afterglow = {}
	if keep > 0 and _live(previous):
		data.afterglow[int(previous.actor_id)] = {"until": XBinding.current_round() + keep - 1, "def": gongsu_value(a, 3), "mdf": gongsu_value(a, 5)}


## 星盾流转·接力（installThreeGrowthRelicRuntime 包 onBind，20 级）：旧宿主的璇护盾 20%（60 级 30%）给血量比例最低的另一名队友
static func _relay(logic, a, previous, target) -> void:
	var pool := XBinding.members().filter(func(t): return t != previous and t != target and t != a and t.is_alive() and not XBinding.untargetable(t))
	if pool.is_empty():
		return
	var order: Array = logic.actors
	pool.sort_custom(func(x, y): return x.hp_rate() < y.hp_rate() if x.hp_rate() != y.hp_rate() else order.find(x) < order.find(y))
	var recipient = pool[0]
	var rnd := XBinding.current_round()
	for r in XShieldLedger.rows(previous):
		if not str(r.source).begins_with("xuan."):
			continue
		var move := floorf(float(r.amount) * (0.3 if int(a.level) >= 60 else 0.2))
		if move <= 0.0:
			continue
		var turns := maxi(1, int(r.until) - rnd + 1)
		var remainder := float(r.amount) - move
		XShieldLedger.revoke(previous, r.source)
		if remainder > 0.0:
			XShieldLedger.grant(previous, r.source, remainder, turns, XUAN, {"noBonus": true, "noDecay": r.noDecay})
		var src := "xuan.relay.%s.until-%d" % [r.source, int(r.until)]
		var existing := XShieldLedger.amount(recipient, src)
		XShieldLedger.revoke(recipient, src)
		XShieldLedger.grant(recipient, src, existing + move, turns, XUAN, {"noBonus": true, "noDecay": r.noDecay})


## CodexShieldLedger.onAbsorb：璇的护盾真挡下伤害计护主一次；星盾流转·定轨（10 级）：璃壁被打破时给一次定星
static func on_absorb(b, list: Array) -> void:
	if data.is_empty():
		return
	if list.any(func(r): return str(r.source).begins_with("xuan.")):
		data.record.protect = true
	var x = xuan()
	if x == null or int(x.level) < 10 or not b is XActor or not XBinding.enemy_acting() or not _direct:  # direct(BattleManager._action)：敌方、伤害类型 1／5、对敌（审查第 34 期 P3-1）
		return
	if not list.any(func(r): return r.source == "xuan.libi" and float(r.lastAbsorbed) > 0.0 and float(r.amount) <= 0.0):
		return
	var broke: Dictionary = data.get("breakRound", {})
	if int(broke.get(int(b.actor_id), -1)) == XBinding.current_round():
		return
	broke[int(b.actor_id)] = XBinding.current_round()
	data.breakRound = broke
	data.dingxing[int(b.actor_id)] = {"until": XBinding.current_round() + 1, "numeric": false}
	XBinding._logic()._state_add(b, state_id("dingxing"))


## X.shadowLimit／shadowCandidates
static func shadow_limit(a) -> int:
	if not XTusuXuan.unlocked(XUAN, a, "liexing"):
		return 0
	var lv := int(a.level)
	return 99 if lv >= 60 else 3 if lv >= 50 else 2 if lv >= 40 else 1


static func shadow_candidates(logic, a) -> Array:
	var h = XBinding.host(a)
	var pid := int(XXuanChart.chart(logic.state).get("partner", 0))
	var order: Array = logic.actors
	var pool := XBinding.members().filter(func(t): return t != a and t != h and _live(t) and not XBinding.untargetable(t))
	pool.sort_custom(func(x, y):
		var px := int(x.actor_id) == pid
		var py := int(y.actor_id) == pid
		if px != py:
			return px
		if x.hp_rate() != y.hp_rate():
			return x.hp_rate() < y.hp_rate()
		return order.find(x) < order.find(y))
	return pool.slice(0, shadow_limit(a))


## 列星效果：星影期限、命主宿主净化一个硬控
static func _liexing(logic, u) -> void:
	if data.is_empty():
		return
	data.liexingUntil = XBinding.current_round() + LIEXING_TURNS - 1
	data.shadows = shadow_candidates(logic, u).map(func(t): return int(t.actor_id))
	for id in data.shadows:
		logic._state_add(logic.state.actor(int(id)), state_id("shadow"))
	logic._state_add(u, state_id("liexing"))
	var h = XBinding.host(u)
	if h != null and _is_roster(logic.state, h):
		var bad := first_cleansable(h)
		if bad > 0:
			logic._state_remove(h, bad)


## makeTargets 包装：列星期间回光、璃壁加上所有受益者；棱光每多一名受益者（主宿主外）再打一遍原目标
static func extend_targets(a, skill: Dictionary, list: Array) -> Array:
	if not is_xuan(a) or data.is_empty() or XBinding.current_round() > int(data.liexingUntil):
		return list
	var key := key_of(skill)
	var cover: Array = beneficiaries(a).list
	if key in ["huiguang", "libi"]:
		for t in cover:
			if not list.has(t):
				list.append(t)
	elif key == "lengguang":
		var original := list.duplicate()
		var h = XBinding.host(a)
		for t in cover:
			if t != h:
				list = list + original
	return list


# ---- 星契自律（第三期，installNativeXuanRuntime 146～245、396～409、480～500 行）：50 级第三阶在星谱选「自动」开战后附身时，
# 星契（绑定充能）由模块自己花：内部施放 cast（保留最后 1 点护主、先照预支）；敌人行动前璃壁；行动后救援回光、列星、宿主攻击后棱光
# （分光、同调）；同轨协同；回合末释放；自动战斗选行动。参照 mv_oracle/xuan_auto_probe.cjs → tests/xiyou_xuan_auto。----
const CAST_LINES := {"huiguang": "璇：「别撑了，先缓一口气。」", "libi": "璇：「低头。这一下我来。」", "lengguang": "璇：「往左。现在出手。」", "liexing": "璇：「都在。接上。」"}
const RESCUE_BELOW := 0.6
const XIANZHAO_EVERY := 3
const FENGUANG_TARGETS := [0, 2, 3, 4]
const AI_HEAL := 0.3
## 当前内部施放（原版记在 Game_Action 上：_codexInternal、_codexXuanSplit、_codexXuanElement、_codexXuanTonggui），施放完还原
static var _act := {}
## 主行动的同轨已打过（action._codexXuanTonggui，主行动每次 startAction 清）
static var _main_tonggui := false
## 本次主行动最后 apply 的敌人（action._codexXuanLastTarget，弱引用：静态变量不存战斗对象）
static var _last_target: WeakRef = null
## 当前主行动是敌方直接伤害行动（installThreeGrowthRelicRuntime direct：敌人、伤害类型 1／5、isForOpponent），定轨只认它
static var _direct := false


static func _key_skill(key: String) -> Dictionary:
	return XDB.rec("Skills", XTusuXuan.skill_id(XUAN, key))


## ready：解锁、学会、冷却好、付得起
static func _ready_skill(logic, a, key: String) -> bool:
	var s := _key_skill(key)
	if s.is_empty() or not XTusuXuan.unlocked(XUAN, a, key) or not a.skill_ids.has(int(s.id)) or a.cooldown_left(int(s.id)) > 0:
		return false
	return _can_pay(logic, a, s)


static func _can_pay(logic, a, s: Dictionary) -> bool:
	if not logic.can_pay_hp(a, s):
		return false
	var c: Dictionary = logic.skill_cost(a, s)
	return a.mp >= float(c.mp) and a.tp >= float(c.tp)


## canSpend：2 点以上随便花；只剩 1 点只给护主（keepLastCharge）
static func _can_spend(a, protect: bool) -> bool:
	var n := XBinding.charges(a)
	return n >= 2 or (n >= 1 and protect)


## borrow（先照）：没有星契时预支下一回合 1 点，每 3 回合一次、只许一笔债；1 级回光、2 级加璃壁、3 级加列星
static func _borrow(logic, a, key: String) -> bool:
	var lv := XXuanChart.mark_level(logic.state, a, "xianzhao")
	if lv <= 0 or int(data.debt) > 0 or XBinding.current_round() - int(data.xianzhaoRound) < XIANZHAO_EVERY:
		return false
	var allowed := ["huiguang"]
	if lv >= 2:
		allowed.append("libi")
	if lv >= 3:
		allowed.append("liexing")
	if not key in allowed:
		return false
	data.debt = 1
	data.xianzhaoRound = XBinding.current_round()
	XBinding.gain(a, 1)
	_sync_counters(logic, a)
	return true


## X.cast＋B.cast：内部施放（照常付费、进冷却，不插入行动序列），每个活着的目标 apply 一次，花 1 点星契
static func _cast(logic, a, key: String, targets: Array, setup: Dictionary, protect: bool) -> bool:
	if targets.is_empty() or not _live(a) or not auto_enabled() or not _ready_skill(logic, a, key):
		return false
	if not _can_spend(a, protect) and not (XBinding.charges(a) < 1 and protect and _borrow(logic, a, key)):
		return false
	if XBinding.charges(a) < 1:
		return false
	var skill := _key_skill(key)
	var dead_scope := int(skill.get("scope", 0)) in [9, 10]
	var list := targets.filter(func(x): return x != null and (x.is_dead() if dead_scope else x.is_alive()))
	if list.is_empty():
		return false
	var prev := _act
	_act = {"internal": "xuan"}
	_act.merge(setup, true)
	logic.pay_skill_cost(a, skill)
	for x in list:
		var at := _logs.size()
		_logs.insert(at, logic.apply(a, skill, x))  # 命中记录排在 apply 期间带出的同轨协同之前（原版 executeHpDamage 在 applyItemUserEffect 之前）
	_act = prev
	_logs.append({"type": "battle_text", "text": str(CAST_LINES[key])})
	XBinding.spend(a, 1)
	data.used[key] = true
	return true


static func _need_rescue(t) -> bool:
	return _live(t) and (t.hp / maxf(1.0, t.mhp) <= RESCUE_BELOW or first_cleansable(t) > 0)


## tryRescue：受益者里低血（≤60%）或被硬控的；没有时并轨 1 级救副宿主
static func _try_rescue(logic, a) -> bool:
	var cover := beneficiaries(a)
	var list: Array = (cover.list as Array).filter(func(t): return _need_rescue(t))
	if list.is_empty() and cover.partner != null and XXuanChart.mark_level(logic.state, a, "binggui") >= 1 and _need_rescue(cover.partner):
		list = [cover.partner]
	return not list.is_empty() and _cast(logic, a, "huiguang", list, {}, true)


## tryLiexing：附身、列星没在期内、有别的活着的队友（附身中的屠苏不算）
static func _try_liexing(logic, a) -> bool:
	var h = XBinding.host(a)
	if h == null or XBinding.current_round() <= int(data.liexingUntil):
		return false
	var others := XBinding.members().filter(func(t): return t != h and t != a and _live(t) and not (XTusu.is_tusu(t) and XBinding.is_bound(t)))
	if others.is_empty() or not _ready_skill(logic, a, "liexing"):
		return false
	return _cast(logic, a, "liexing", [a], {}, true)


## followUp：棱光打宿主这次攻击的最后一个敌人（倒了打第一个活着的）；分光：全体攻击时分给 2／3／4 名；同调：2 级跟攻击元素、1 级用星谱指定元素
static func _follow_up(logic, a, skill: Dictionary, target) -> bool:
	if target == null or not target.is_alive():
		var alive: Array = logic.alive(logic.enemies)
		target = alive[0] if not alive.is_empty() else null
	if target == null:
		return false
	var targets := [target]
	var lv := XXuanChart.mark_level(logic.state, a, "fenguang")
	if lv > 0 and XSmartAI.scope_of(skill) in [2, 8, 10]:
		targets = (logic.alive(logic.enemies) as Array).slice(0, FENGUANG_TARGETS[lv])
	var setup := {"split": targets.size()}
	var el := int(skill.get("damage", {}).get("elementId", 0))
	var td := XXuanChart.mark_level(logic.state, a, "tongdiao")
	var chosen := int(XXuanChart.chart(logic.state).get("element", 0))
	if td >= 2 and el > 0:
		setup.element = el
	elif td >= 1 and chosen > 0:
		setup.element = chosen
	return _cast(logic, a, "lengguang", targets, setup, false)


## startAction 包装（原 startAction 之前，屠苏在外层）：敌人对我方的伤害行动打到受益者前璃壁（并轨 2 级：打到副宿主也给），每回合一次
static func start_action(logic, u, skill: Dictionary, chosen) -> Array:
	_last_target = null
	_main_tonggui = false
	_direct = u is XEnemy and not skill.is_empty() and XSmartAI.for_opponent(skill) and int(skill.get("damage", {}).get("type", 0)) in [1, 5]
	var a = xuan()
	if a == null or not auto_enabled() or not XBinding.is_bound(a) or not u is XEnemy or skill.is_empty() or not XSmartAI.for_opponent(skill):
		return []
	if not int(skill.get("damage", {}).get("type", 0)) in [1, 5]:
		return []
	var targets: Array = logic.targets_for(u, skill, chosen)  # 原版在这里多调一次 makeTargets（随机目标照样掷）
	var cover := beneficiaries(a)
	var hit: Array = (cover.list as Array).filter(func(t): return targets.has(t) and _live(t))
	if hit.is_empty() and cover.partner != null and XXuanChart.mark_level(logic.state, a, "binggui") >= 2 and targets.has(cover.partner):
		hit = [cover.partner]
	if hit.is_empty() or data.used.has("libi"):
		return []
	_cast(logic, a, "libi", hit, {}, true)
	return take_logs()


## endAction 包装（原 endAction 之前，屠苏在外层）：救援回光、列星、宿主（含星影）主动攻击后棱光
static func end_action(logic, u, skill) -> Array:
	_direct = false
	var a = xuan()
	if a == null or not auto_enabled() or not XBinding.is_bound(a) or not _live(a):
		return []
	_try_rescue(logic, a)
	_try_liexing(logic, a)
	if u is XActor and skill is Dictionary and not skill.is_empty() and XSmartAI.for_opponent(skill) \
			and int(skill.get("damage", {}).get("type", 0)) in [1, 5] and in_cover(a, u):
		_follow_up(logic, a, skill, _last_target.get_ref() if _last_target != null else null)
	return take_logs()


## Game_Action.apply 包装：主行动记下最后打到的敌人
static func note_target(t) -> void:
	if t is XEnemy and not _act.has("internal"):
		_last_target = weakref(t)


## tongguiStrike：同轨时回光、璃壁、列星带一次棱光式协同（每次行动一次，打第一个活着的敌人，不花费）
static func _tonggui_strike(logic, a) -> void:
	if not auto_enabled() or data.is_empty() or not bool(data.tonggui):
		return
	if _act.has("internal"):
		if _act.has("tonggui"):
			return
		_act.tonggui = true
	else:
		if _main_tonggui:
			return
		_main_tonggui = true
	var alive: Array = logic.alive(logic.enemies)
	if alive.is_empty():
		return
	var prev := _act
	_act = {"internal": "xuan-tonggui", "tonggui": true}
	_logs.append(logic.apply(a, _key_skill("lengguang"), alive[0]))
	_act = prev


## roundEndRelease（绑定 onRoundEnd）：剩下的星契按 受益者缺血或被控→回光、璇自己半血以下或被控→回光、棱光、给宿主璃壁 依次放到放不出
static func _round_end_release(owner) -> void:
	var logic = XBinding._logic()
	if not auto_enabled() or logic == null:
		return
	while XBinding.charges(owner) > 0:
		var hurt: Array = (beneficiaries(owner).list as Array).filter(func(t): return t.hp < t.mhp or first_cleansable(t) > 0)
		var done := not hurt.is_empty() and _cast(logic, owner, "huiguang", hurt, {}, true)
		if not done and (owner.hp < owner.mhp * 0.5 or first_cleansable(owner) > 0):
			done = _cast(logic, owner, "huiguang", [owner], {}, true)
		var alive: Array = logic.alive(logic.enemies)
		if not done and not alive.is_empty():
			done = _cast(logic, owner, "lengguang", [alive[0]], {}, true)
		var h = XBinding.host(owner)
		if not done and h != null:
			done = _cast(logic, owner, "libi", [h], {}, true)
		if not done:
			break


## 伤害钩子 xuan：内部施放的棱光按分光目标数分摊、同调换元素
static func cast_ops(item: Dictionary, a) -> Array:
	if not is_xuan(a) or key_of(item) != "lengguang" or not _act.has("internal"):
		return []
	var ops := []
	if int(_act.get("split", 1)) > 1:
		ops.append({"op": "mul", "field": "finalMultiplier", "value": 1.0 / float(_act.split)})
	if int(_act.get("element", 0)) > 0:
		ops.append({"op": "set", "field": "elements", "value": [int(_act.element)]})
	return ops


## X.autoAction（makeAutoBattleActions 包装，原选择之后）：附身时自律就防御（手动不管）；本体时先救 30% 以下的队友，再寄星（命主名册优先、否则默认宿主）
static func auto_action(logic, a, base: Array) -> Array:
	if not is_xuan(a) or not XBinding.in_battle():
		return base
	if XBinding.is_bound(a):
		return [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null] if auto_enabled() else base
	var heal := _key_skill("huiguang")
	for t in XBinding.members():
		if _live(t) and t.hp / t.mhp < AI_HEAL:
			if logic.can_use(a, heal):
				return [heal, t]
			break
	var s: XState = logic.state
	var pick = null
	for id in (XXuanChart.chart(s).roster as Array).slice(0, XXuanChart.stage(s)):
		var t = s.actor(int(id))
		if t != null and XBinding.can_host(a, t):
			pick = t
			break
	if pick == null:
		pick = XBinding.default_host(a)
	var jx := _key_skill("jixing")
	if pick != null and logic.can_use(a, jx):
		return [jx, pick]
	return base
