class_name XTusu
extends RefCounted
## 【cc·白龙_14·未经审查】176 屠苏第三期（正式 js/codex/runtime/installNativeTusuRuntime.js，W.CodexTusu 0.4.1）：五相武具的战斗内骨架。
## - 武具数据（a._codexTusu，战斗内）：weapon 当前武相、reserve 预约（下个自然回合换）、pending 化武选的武相、host_actions 持武者本回合行动次数；
##   上次武相 _codexTusuLast 记在角色上、跨战斗（重制存 s.flags）。
## - 绑定登记（种类 tusu，manual：不转充能，屠苏用自己的行动）：onBind 定武相（pending→当前→上次→剑），宿主加持武状态、清预约；
##   onUnbind 清宿主的持武／锁定／和鸣状态与预约；onRoundStart 有预约就换武相、清支援记录、记持武者行动次数，维持不了（屠苏与持武者
##   都付不起当前武相任何一招）就噬主失败回人形（unbind 'devour'）；onClear 清本场数据。止戈环第一回合兵势 +0（CFG.relicBonus.firstCharge 0，不做）。
## - 指令（Game_Action.apply 包装）：归形 unbind 'return'；易武 预约武相（加「下回合」状态）；化武 能当宿主就记 pending 并绑定 'huawu'。
## - 技能条件（meetsSkillConditions 包装；bindGrowth 的归形判断在最外层，见 XTusuXuan.meets）：战斗中易武要绑定且不是当前／预约的武相；
##   化武要没绑定；支援要绑定、是当前武相那招、持武者活着（和鸣另要持武者没有和鸣）；绑定中别的技能只有防御；
##   武装技能要持武者拿着对应武相（战斗中）；器谱战斗外。
## - 「攻击」：战斗中绑定时恒为归形 10301（attackSkillId 包装）。
## - 噬主（skillMpCost／canPaySkillCost／paySkillCost 包装）：武装技能（持武者用）与绑定中的支援（屠苏用）先由屠苏付自己的
##   最大 MP 比例（ownCost），付不起由持武者付 比例×3 按持武者最大 MP（devourCost）；都付不起不能用。持武者的面板 MP：屠苏付得起 0，
##   否则噬主费用。屠苏自己的专属技能面板都是 ownCost。书相：持武者的魔法技能（hitType 2、不是武装技能）MP ×0.7。
## - 盾相（param 包装，谷雨储备之外、种族之内）：持盾的宿主双防不低于屠苏的双防。
## - 属性基准 base：书相取屠苏魔攻，其余取屠苏物攻；公式 damage(a, b, 键)：武装技能＝基准×系数，其余＝屠苏物攻（body_mag 魔攻）×系数。
##   公式接转换器 MODULE_FORMULAS 是 A 车道的事，这里只给函数。
## - 战斗结束、读档：清全队的持武／锁定／和鸣状态与本场数据。
## 不做（四期）：支援的施放与效果（剑气、锁定、金汤、和鸣、镇魂、内部施放 cast、持武者行动触发）、统一伤害钩子（武装基准代入、分摊、锁定、和鸣、
## 支援上下限、挫势、护阵）、自动战斗与智能 AI、开刃与器谱、战斗日志里的台词（画面）、指令窗（画面）。
## 参照：mv_oracle/tusu_battle_probe.cjs（tests/fixtures/tusu_battle_oracle.json），测试 tests/xiyou_tusu_battle.gd。

const ACTOR := 176
const RETURN_SKILL := 10301
const WEAPONS := ["sword", "bow", "shield", "book", "hammer"]
const SUPPORT_OF := {"sword": "jianqi", "bow": "suoding", "shield": "jintang", "book": "heming", "hammer": "zhenhun"}
const ARM_OF := {"sword": ["arm.zhanfeng", "arm.hengsao"], "bow": ["arm.dianshe", "arm.guanri"], "shield": ["arm.huzhen"], "book": ["arm.chiling"], "hammer": ["arm.zhenji"]}
const ARM_WEAPON := {"chiling": "book", "dianshe": "bow", "guanri": "bow", "hengsao": "sword", "zhanfeng": "sword", "zhenji": "hammer"}
const MAGIC_KEYS := ["body_mag"]
const MP_RATE := {"arm.chiling": 0.06, "arm.dianshe": 0.05, "arm.guanri": 0.1, "arm.hengsao": 0.1, "arm.huzhen": 0.1, "arm.zhanfeng": 0.05, "arm.zhenji": 0.1,
	"body.guard": 0.1, "body.mag": 0.06, "body.phys": 0.05, "support.heming": 0.06, "support.jianqi": 0.06, "support.jintang": 0.12, "support.suoding": 0.06, "support.zhenhun": 0.1}
const DEVOUR_RATE := 3.0
const BOOK_MP_RATE := 0.7
const SHIELD_FLOOR := 1.0
const LAST_FLAG := "_codexTusuLast"

## 屠苏的本场数据（战斗内）
static var _d := {}
static var _states := {}


## 状态按备注 <CodexTusu: 键>，充能耗尽 <CodexBind: empty>
static func state_id(k: String) -> int:
	if _states.is_empty():
		var re := RegEx.create_from_string("<Codex(Tusu|Bind):\\s*([^>]+)>")
		for st in XDB.table("States"):
			if st is Dictionary:
				var m := re.search(str(st.get("note", "")))
				if m:
					var key := m.get_string(2).strip_edges()
					if m.get_string(1) == "Bind":
						if key == "empty":
							_states["empty"] = int(st.id)
					else:
						_states[key] = int(st.id)
	return int(_states.get(k, 0))


static func skill_id(k: String) -> int:
	return XTusuXuan.skill_id(ACTOR, k)


static func key_of(skill: Dictionary) -> String:
	var o := XTusuXuan.owner_of(int(skill.get("id", 0)))
	return str(o[1]) if int(o[0]) == ACTOR else ""


static func is_tusu(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func _in_battle() -> bool:
	return XBinding.in_battle()


## tusu()：出战成员里的屠苏
static func tusu():
	for a in XBinding.members():
		if is_tusu(a):
			return a
	return null


static func data(a = null):
	return _d if not _d.is_empty() and (a == null or is_tusu(a)) else null


static func weapon(a = null):
	var d = data(a)
	return d.get("weapon") if d != null else null


static func holder(a):
	return XBinding.host(a)


static func weapon_of_host(h):
	var t = tusu()
	return weapon(t) if t != null and holder(t) == h else null


static func _set_state(logic, b, id: int, on: bool) -> void:
	if id <= 0 or b.is_state_affected(id) == on:
		return
	if on:
		logic._state_add(b, id)
	else:
		logic._state_remove(b, id)


static func _set_hold(logic, h, w) -> void:
	for x in WEAPONS:
		if x != w:
			_set_state(logic, h, state_id("hold." + x), false)
	if w != null:
		_set_state(logic, h, state_id("hold." + str(w)), true)
	h.param_mark_dirty()
	h.param_refresh()


static func _set_reserve(logic, a, w) -> void:
	var d = data(a)
	if d == null:
		return
	d.reserve = w
	for x in WEAPONS:
		_set_state(logic, a, state_id("reserve." + x), x == w and w != d.get("weapon"))


static func _clear_host_states(logic, h) -> void:
	if h == null:
		return
	for x in WEAPONS:
		_set_state(logic, h, state_id("hold." + x), false)
	for k in ["lock", "heming"]:
		_set_state(logic, h, state_id(k), false)
	h.param_mark_dirty()
	h.param_refresh()


static func _logic():
	return XBinding._logic()


static func _last(s: XState):
	return s.flags.get(LAST_FLAG) if s != null else null


# ---- 绑定登记 ----
static func register_kind() -> void:
	if XBinding.kinds.has("tusu"):
		return
	XBinding.register("tusu", {
		"is_owner": func(a): return is_tusu(a),
		"manual": func(_a): return true,
		"form_state": state_id("armed"), "empty_state": state_id("empty"),
		"on_bind": _on_bind, "on_unbind": _on_unbind, "on_round_start": _on_round_start, "on_clear": _on_clear})


static func _on_bind(owner, h, _reason, _previous) -> void:
	var logic = _logic()
	if _d.is_empty():
		_d = {"weapon": null, "reserve": null, "pending": null, "host_actions": 0, "supported": {}}
	var w = _d.pending if _d.pending != null else (_d.weapon if _d.weapon != null else _last(logic.state))
	if w == null:
		w = "sword"
	_d.pending = null
	_d.weapon = w
	logic.state.flags[LAST_FLAG] = w
	_set_reserve(logic, owner, null)
	_set_hold(logic, h, w)


static func _on_unbind(owner, h, _reason) -> void:
	var logic = _logic()
	_clear_host_states(logic, h)
	if data(owner) != null:
		_set_reserve(logic, owner, null)


static func _on_round_start(owner, _n) -> void:
	var logic = _logic()
	var d = data(owner)
	if d == null:
		return
	if d.reserve != null and d.reserve != d.weapon:
		d.weapon = d.reserve
		logic.state.flags[LAST_FLAG] = d.weapon
		_set_hold(logic, holder(owner), d.weapon)
	_set_reserve(logic, owner, null)
	d.supported = {}
	var h = holder(owner)
	d.host_actions = maxi(1, logic.current_order.count(h)) if h != null else 1
	if not can_maintain(d.weapon):
		devour_fail(owner)


static func _on_clear(_a) -> void:
	_d = {}


# ---- 属性基准与公式 ----
## T.base：只由屠苏提供（书相魔攻，其余物攻）
static func base(_h, w: String) -> float:
	var t = tusu()
	if t == null:
		return 0.0
	return t.mat if w == "book" else t.atk


## T.coefficient：原版自己那份（四舍五入、默认 4 档等级）被 bindGrowth 换掉了，实际是 M.coefficient（本体等级 7 档插值、向下取整）
static func coefficient(key: String) -> int:
	return XTusuXuan.coefficient(ACTOR, key)


## CodexTusu.damage(a, b, 键)
static func damage(a, _b, key: String) -> float:
	if ARM_WEAPON.has(key):
		return base(a, ARM_WEAPON[key]) * coefficient(key)
	var t = a if is_tusu(a) else tusu()
	if t == null:
		return 0.0
	return (t.mat if MAGIC_KEYS.has(key) else t.atk) * coefficient(key)


## 技能公式「CodexTusu.damage(a,b,'键')」（武装技能、支援、本体技能）：公式程序不认引号，这里直接算；不是这种公式返回 null
static var _formula_re: RegEx = null
static func formula(item: Dictionary, a, b):
	var f := str(item.get("damage", {}).get("formula", ""))
	if not f.begins_with("CodexTusu.damage("):
		return null
	if _formula_re == null:
		_formula_re = RegEx.create_from_string("^CodexTusu\\.damage\\(\\s*a\\s*,\\s*b\\s*,\\s*'(\\w+)'\\s*\\)$")
	var m := _formula_re.search(f.strip_edges())
	return damage(a, b, m.get_string(1)) if m != null else null


## Game_Action.apply／subject 包装（外层）：持武者用武装技能时，整个 apply 以屠苏为出手者（按屠苏的属性与加成结算；屠苏来源豁免异界制约，
## 屠苏不是导入角色，缩放本来就是 1）。apply 外面（付费、反击判定、行动次数）仍是持武者
static func apply_subject(u, skill: Dictionary):
	if u is XActor and not is_tusu(u) and key_of(skill).begins_with("arm."):
		var t = tusu()
		if t != null:
			return t
	return u


const ARM_ACTIONS := 2
## T.lockRate／hemingRate／huzhenRate：随屠苏等级（20～60 级插值）
static func lock_rate(t) -> float:
	return XGuyu.curve(int(t.level) if t != null else 1, [1.3, 1.5], [20, 60])


static func heming_rate(t) -> float:
	return XGuyu.curve(int(t.level) if t != null else 1, [1.2, 1.5], [20, 60])


static func huzhen_rate(t) -> float:
	return XGuyu.curve(int(t.level) if t != null else 1, [0.85, 0.70], [20, 60])


## 伤害钩子 tusu（CodexDamageHooks）：武装技能按武相定物理／魔法、威力按持武者本回合行动次数分摊（2 次为基准）、
## 贯日打锁定目标、敕令带和鸣；护阵中的角色受伤减免。a 是出手者（武装技能时已是屠苏，见 apply_subject）
## 不做（四期剩余）：支援上下限（res.after）、止戈环支援加成（CFG.relicBonus.support＝1，乘了也不变）、挫势（敌人 _codexTusuCuoshi，挫势还没移植）
static func damage_ops(item: Dictionary, a, b) -> Array:
	var ops := []
	var key := key_of(item)
	if key.begins_with("arm.") and ARM_WEAPON.has(key.substr(4)):
		ops.append({"op": "set", "field": "mode", "value": "magical" if ARM_WEAPON[key.substr(4)] == "book" else "physical"})
		var t = tusu()
		var td = data(t)
		if td != null and int(td.host_actions) > 0:
			ops.append({"op": "mul", "field": "finalMultiplier", "value": float(ARM_ACTIONS) / maxi(1, int(td.host_actions))})
		var wielder = a
		if is_tusu(a) and holder(a) != null:
			wielder = holder(a)
		if key == "arm.guanri" and wielder is XBattler and is_same(lock_target(wielder), b):
			ops.append({"op": "mul", "field": "finalMultiplier", "value": lock_rate(t)})
		if key == "arm.chiling" and wielder is XBattler and wielder.state_ids.has(state_id("heming")):
			ops.append({"op": "mul", "field": "finalMultiplier", "value": heming_rate(t)})
	if b is XActor and state_id("huzhen") > 0 and b.state_ids.has(state_id("huzhen")):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": huzhen_rate(tusu())})
	return ops


## BattleManager.endAction 包装（原 endAction 之前，屠苏两层里的外层）：锁定、和鸣启动即消费（没打中或被免疫也不退回）。
## 贯日的锁定在支援「锁定」移植后补（四期剩余）
static func end_action(u, skill) -> void:
	if not skill is Dictionary or u == null:
		return
	var key := key_of(skill)
	var heming := state_id("heming")
	if key == "arm.chiling" and heming > 0 and u.state_ids.has(heming):
		u.remove_state(heming)


## 持武者的锁定目标（host._codexTusuLock.target）；锁定由支援「锁定」给，四期剩余，现在恒为空
static func lock_target(_h):
	return null


# ---- 噬主 ----
## B.percentMpCost：MP 只按最大 MP 比例（基础 0），照常乘 mcr、减耗
static func percent_cost(a, skill: Dictionary, rate: float) -> int:
	if a == null or skill.is_empty():
		return 0
	var mp := floori(a.mmp * rate * a.mcr)
	return floori(mp * (1.0 - XBattleLogic.consume_reduce(a, skill) / 100.0))


static func own_cost(t, key: String) -> int:
	return percent_cost(t, XDB.rec("Skills", skill_id(key)), float(MP_RATE.get(key, 0.0)))


static func devour_cost(h, key: String) -> int:
	return percent_cost(h, XDB.rec("Skills", skill_id(key)), float(MP_RATE.get(key, 0.0)) * DEVOUR_RATE)


## T.payer：'tusu'／'host'／""
static func payer(key: String) -> String:
	var t = tusu()
	if t == null:
		return ""
	if t.mp >= own_cost(t, key):
		return "tusu"
	var h = holder(t) if XBinding.is_bound(t) else null
	if h != null and h.is_alive() and h.mp >= devour_cost(h, key):
		return "host"
	return ""


static func can_maintain(w, h = null) -> bool:
	var t = tusu()
	if t == null or w == null:
		return false
	if h == null:
		h = holder(t)
	for k in ARM_OF[w] + ["support." + SUPPORT_OF[w]]:
		if t.mp >= own_cost(t, k) or (h != null and h.is_alive() and h.mp >= devour_cost(h, k)):
			return true
	return false


static func devour_fail(t) -> bool:
	if t == null or not XBinding.is_bound(t):
		return false
	return XBinding.unbind(t, "devour")


static var _devour_paying := false


static func _devour_key(a, key: String) -> bool:
	if key == "" or not MP_RATE.has(key) or not _in_battle():
		return false
	if key.begins_with("arm."):
		return not is_tusu(a)
	return key.begins_with("support.") and is_tusu(a) and XBinding.is_bound(a)


## skillMpCost 包装（谷雨之外、种族之内）
static func mp_cost(a, skill: Dictionary, native: int) -> int:
	var key := key_of(skill)
	if _devour_key(a, key):
		if key.begins_with("arm."):
			return 0 if payer(key) == "tusu" else devour_cost(a, key)
		if _devour_paying:
			return 0
	if key != "" and MP_RATE.has(key) and is_tusu(a):
		return own_cost(a, key)
	if _in_battle() and weapon_of_host(a) == "book" and int(skill.get("hitType", 0)) == 2 and not key.begins_with("arm."):
		return floori(native * BOOK_MP_RATE)
	return native


## canPaySkillCost 包装：返回 null＝不管
static func can_pay(a, skill: Dictionary, tp_cost: float):
	var key := key_of(skill)
	if not a is XActor or not _devour_key(a, key):
		return null
	return payer(key) != "" and a.tp >= tp_cost


## paySkillCost 包装（外层，installNativeTusuRuntime 440～450 行）：返回 null＝不是噬主技能，不管；""＝都付不起（调用方在支付前已查），
## 整次不付；否则是付款方 "tusu"／"host"。原版包装里 old.apply 照走里层（异化缄默／饕餮、扣 MP／TP、HP 费用、熟练度记次），
## 只是期间 devourPaying 让支援的面板 MP 记 0；所以调用方拿到付款方后照常走里层支付，再调 pay_after 补扣另一人的魔法（审查第 24 期 P2-1）
static func pay_begin(a, skill: Dictionary) -> Variant:
	var key := key_of(skill)
	if not a is XActor or not _devour_key(a, key):
		return null
	var who := payer(key)
	_devour_paying = who == "host" and is_tusu(a)
	return who


## pay_begin 之后、里层付完：放下 devourPaying，屠苏代付武装技能扣屠苏、持武者代付支援扣持武者
static func pay_after(a, skill: Dictionary, who) -> void:
	_devour_paying = false
	if who == null or who == "":
		return
	var key := key_of(skill)
	var t = tusu()
	var h = holder(t) if t != null else null
	if who == "tusu" and not is_tusu(a):
		t.mp = t.mp - own_cost(t, key)
	if who == "host" and is_tusu(a) and h != null:
		h.mp = h.mp - devour_cost(h, key)


# ---- 技能条件与指令 ----
## supportSkill：绑定中当前武相的支援
static func support_skill(a) -> Dictionary:
	if not is_tusu(a) or not XBinding.is_bound(a) or weapon(a) == null:
		return {}
	return XDB.rec("Skills", skill_id("support." + str(SUPPORT_OF[weapon(a)])))


## meetsSkillConditions 包装（归形由 XTusuXuan.meets 的 bindGrowth 一层先判）
static func meets(a, skill: Dictionary) -> bool:
	var key := key_of(skill)
	if is_tusu(a) and _in_battle():
		var bound := XBinding.is_bound(a)
		if key == "return":
			return true  # 原版这里要 1 点充能，但 bindGrowth 的条件在最外层、归形先返回，这一层到不了（XTusuXuan.meets）
		if key.begins_with("yiwu."):
			var d = data(a)
			var cur = (d.reserve if d.reserve != null else d.weapon) if d != null else null
			return bound and key.substr(5) != cur
		if key.begins_with("huawu."):
			return not bound
		if key.begins_with("support."):
			var active := support_skill(a)
			var h = holder(a)
			return bound and not active.is_empty() and int(active.id) == int(skill.id) and h != null and h.is_alive() \
				and (key != "support.heming" or not h.is_state_affected(state_id("heming")))
		if bound and int(skill.get("id", 0)) != XBattleLogic.GUARD_SKILL:
			return false  # 武具态只有易武可用
	if key.begins_with("arm.") and _in_battle():
		var need = ARM_WEAPON.get(key.substr(4), "shield" if key == "arm.huzhen" else null)
		if need == null or weapon_of_host(a) != need:
			return false
	if key == "menu.forge":
		return not _in_battle()
	return true


## attackSkillId 包装：战斗中绑定时恒为归形
static func attack_id(a, native: int) -> int:
	return RETURN_SKILL if is_tusu(a) and _in_battle() and XBinding.is_bound(a) else native


## Game_Action.apply 包装：归形、易武、化武只做自己的事（makeSuccess）；返回 {} 表示不是这三个
static func apply_command(logic, u, skill: Dictionary, t) -> Dictionary:
	var key := key_of(skill)
	if not is_tusu(u) or not (key == "return" or key.begins_with("yiwu.") or key.begins_with("huawu.")):
		return {}
	t.runtime_result = XResourceContext.empty_result()
	if key == "return":
		XBinding.unbind(u, "return")
	elif key.begins_with("yiwu."):
		_set_reserve(logic, u, key.substr(5))
	elif XBinding.can_host(u, t):
		if _d.is_empty():
			_d = {"weapon": null, "reserve": null, "pending": null, "host_actions": 0, "supported": {}}
		_d.pending = key.substr(6)
		XBinding.bind(u, t, "huawu")
	return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false, "success": true,
		"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}


## 盾相双防补底（param 包装）
static var _param_guard := false


static func param(a, i: int, v: float) -> float:
	if (i == 3 or i == 5) and not _param_guard and _in_battle() and weapon_of_host(a) == "shield":
		var t = tusu()
		if t != null and t != a:
			_param_guard = true
			v = maxf(v, floorf(SHIELD_FLOOR * (t.def if i == 3 else t.mdf)))
			_param_guard = false
	return v


## endBattle（finally）、读档：清全队的持武／锁定／和鸣状态与本场数据
static func clear(s: XState, logic = null) -> void:
	_d = {}
	if s == null:
		return
	for a in s.members():
		for k in ["lock", "heming"] + WEAPONS.map(func(x): return "hold." + x):
			var id := state_id(k)
			if id > 0 and a.state_ids.has(id):
				if logic != null:
					logic._state_remove(a, id)
				else:
					a.state_ids.erase(id)
					a.state_turns.erase(id)
