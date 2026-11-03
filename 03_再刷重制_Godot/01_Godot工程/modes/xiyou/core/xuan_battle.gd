class_name XXuanBattle
extends RefCounted
## 【cc·悟空·未经审查】璇的战斗效果第一期（正式 js/codex/runtime/installNativeXuanRuntime.js）：不靠绑定就成立的部分。
## 本场数据（fresh）、净化口径（isCleanseState）、MP 费用（按璇 MP 上限百分比）、技能条件、回光净化、定星、璃壁护盾、棱光减益、蚀辉、结束清标记。
## 余辉不做：原版包在 Game_Battler.gainHp 上，而回光只打角色，角色的 gainHp 是 Game_Actor 自有方法，这层跑不到，实测溢出不转护盾（见交付单「需要用户决定」）。
## 第二期：绑定种类登记、寄星／转移／回身、星纹标记、默契结算、附身期间不掉血（mv_oracle/xuan_bind_probe.cjs → tests/xiyou_xuan_bind）。
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
const LINES := {"dingxing": "定星挡住了控制。", "transfer": "璇：「我去另一边，有事叫我。」"}


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
		"on_bind": _on_bind, "on_unbind": _on_unbind, "on_round_start": _on_round_start, "on_round_close": _on_round_close,
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
	_line("transfer")
	d.tonggui = int(d.tacit) >= 100
	_sync_counters(logic, owner)
	owner.refresh_passive()
	target.refresh_passive()


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
		"libi":
			XShieldLedger.grant(t, "xuan.libi", shield_amount(u, t), LIBI_TURNS, XUAN)
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
static func blocks_state(t: XBattler, id: int) -> bool:
	if data.is_empty() or not t is XActor or t.state_ids.has(id) or not XBinding.in_battle():
		return false
	var guard = data.dingxing.get(int(t.actor_id))
	if guard == null or not is_cleanse_state(XDB.rec("States", id), true) or int(guard.until) < XBinding.current_round():
		return false
	data.dingxing.erase(int(t.actor_id))
	var mark := state_id("dingxing")
	if t.state_ids.has(mark):
		t.remove_state(mark)
	_line("dingxing")
	return true
