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
## 【cc·白龙·未经审查】tusu5 补齐：武相支援（屠苏自用、内部施放、持武者行动触发、回合末释放、上下限与成长加成）、锁定与和鸣的消费、挫势、
## 止戈环 60 级与五兵淬纹（installThreeGrowthRelicRuntime 的屠苏部分：分段、横扫多目标、锻痕、护阵首伤护盾、挫势减伤、开刃·书护持）、开刃三相、
## 自动战斗与智能 AI 估算、战斗日志台词、器谱开刃逻辑。
## 还没做（画面）：指令窗（武相支援一栏、易武子菜单、「待命」改名、持武者指令去重）、器谱菜单、支援目标选择的取消返回。
## 原版锁定、和鸣、护阵倍率另被超强者路线压制往 1 收（O-050 不移植），参照里关掉。
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

## 屠苏的本场数据（战斗内）：trigger 支援随主成长读的持武者伤害、growth 本场成长加成用掉的回合（growthSupportRound）
static var _d := {}


static func _fresh() -> Dictionary:
	return {"weapon": null, "reserve": null, "pending": null, "host_actions": 0, "supported": {}, "trigger": 0.0, "growth": 0}
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
	_locks.erase(h)
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
		"on_bind": _on_bind, "on_unbind": _on_unbind, "on_round_start": _on_round_start, "on_round_end": _round_end_release,
		"on_clear": _on_clear})


## CFG.lines、CFG.names：战斗日志里的台词（BattleManager._logWindow addText）
const LINES := {"devour": "屠苏：「魔力不够了——借你的。」", "devourFail": "屠苏：「你也撑不住了……先放开我。」", "fallen": "屠苏：「……起来。我还没认可你呢。」",
	"huawu": "屠苏：「握稳。我不喜欢掉在地上。」", "reserve": "下回合武相：%s", "ret": "屠苏：「换个人。别误会，不是你不好。」", "support": "屠苏：「这一下，我自己来。」",
	"yiwu_book": "屠苏：「书。字念对，别念错。」", "yiwu_bow": "屠苏：「弓。看准了再松手。」", "yiwu_hammer": "屠苏：「锤。砸它的势，不必砸它的命。」",
	"yiwu_shield": "屠苏：「盾。站到我后面。」", "yiwu_sword": "屠苏：「剑。放开了砍。」"}
const NAMES := {"sword": "剑", "bow": "弓", "shield": "盾", "book": "书", "hammer": "锤"}


## 日志一行（画面 _log_add），跟内部施放的命中一起交回战斗记录；回合开始换武相那句在下一次取走时一起出
static func _line(key: String, arg := "") -> void:
	var text: String = LINES[key]
	_logs.append({"type": "battle_text", "text": text % arg if arg != "" else text})


static func _on_bind(owner, h, reason, _previous) -> void:
	var logic = _logic()
	if _d.is_empty():
		_d = _fresh()
	var w = _d.pending if _d.pending != null else (_d.weapon if _d.weapon != null else _last(logic.state))
	if w == null:
		w = "sword"
	_d.pending = null
	_d.weapon = w
	logic.state.flags[LAST_FLAG] = w
	_set_reserve(logic, owner, null)
	_set_hold(logic, h, w)
	if reason != "opening":
		_line("huawu")


static func _on_unbind(owner, h, reason) -> void:
	var logic = _logic()
	_clear_host_states(logic, h)
	if data(owner) != null:
		_set_reserve(logic, owner, null)
	if reason == "death-host":
		_line("fallen")
	elif reason == "return":
		_line("ret")
	# 原版另给 W.CodexTusuDevour.unbind／paid 计数，但正式版没有定义 CodexTusuDevour，计数从不生效，不移植


static func _on_round_start(owner, _n) -> void:
	var logic = _logic()
	var d = data(owner)
	if d == null:
		return
	if d.reserve != null and d.reserve != d.weapon:
		d.weapon = d.reserve
		logic.state.flags[LAST_FLAG] = d.weapon
		_set_hold(logic, holder(owner), d.weapon)
		_line("yiwu_" + str(d.weapon))
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
## 止戈环支援加成 CFG.relicBonus.support＝1（乘了也不变，不写）；支援上下限在 XDamage.finish 里（support_after）
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
	if a is XEnemy and _cuoshi.has(a):
		ops.append({"op": "mul", "field": "finalMultiplier", "value": float(_cuoshi[a].rate)})  # 挫势：敌人出手 ×rate（到期由回合末删）
	if b is XActor and state_id("huzhen") > 0 and b.state_ids.has(state_id("huzhen")):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": huzhen_rate(tusu())})
	return ops + _three60_ops(item, a, b)


## BattleManager.endAction 包装（原 endAction 之前，屠苏两层里的外层）：锁定、和鸣启动即消费（没打中或被免疫也不退回）。
## 贯日的锁定在支援「锁定」移植后补（四期剩余）
static func end_action(logic, u, skill) -> Array:
	if not skill is Dictionary or u == null:
		_act = {}
		return []
	var key := key_of(skill)
	var heming := state_id("heming")
	# 止戈环（最外层）：开刃·书的护持法术用过和鸣就消费
	if float(_act.get("book_heming", 0.0)) > 0.0 and heming > 0 and u.state_ids.has(heming):
		_set_state(logic, u, heming, false)
	# 锁定、和鸣：启动即消费（没打中或被免疫也不退回）；开刃·弓贯日击杀锁定目标时锁定下一个最危险的敌人
	if key == "arm.guanri" and _locks.has(u):
		var target = _locks[u]
		var killed: bool = target != null and target.is_dead()
		_locks.erase(u)
		_set_state(logic, u, state_id("lock"), false)
		if killed and has_kairen("bow"):
			var nxt = danger_enemy(logic)
			if nxt != null:
				_locks[u] = nxt
				logic._state_add(u, state_id("lock"))
	if key == "arm.chiling" and heming > 0 and u.state_ids.has(heming):
		u.remove_state(heming)
	# 持武者的主动行动（不是内部施放）：记这次对敌人的伤害作支援随主成长的读数；剑相物理伤害、锤相对敌行动后放支援
	var t = tusu()
	if t != null and XBinding.is_bound(t) and not _act.has("internal") and is_same(u, holder(t)) and u.is_alive():
		var w = weapon(t)
		_d.supported = _d.get("supported", {})
		_d.trigger = float(_act.get("dealt", 0.0))
		var dtype := int(skill.get("damage", {}).get("type", 0))
		if w == "sword" and int(skill.get("hitType", 0)) == 1 and dtype in [1, 5] and XSmartAI.for_opponent(skill):
			round_support(logic, t, "jianqi", false)
		if w == "hammer" and XSmartAI.for_opponent(skill):
			round_support(logic, t, "zhenhun", false)
	# 屠苏自己的支援：生效了，本回合不再给成长加成
	if manual_support(u, skill) != "" and data(u) != null and bool(_act.get("successful", false)):
		_d.growth = XBinding.current_round()
	_sword_targets.clear()  # 横扫的目标表记在行动上，行动结束就没了
	_action_no += 1
	_act = {}
	return take_logs()


## 持武者的锁定目标（host._codexTusuLock.target）：支援「锁定」给，贯日结束时消费
static var _locks := {}


static func lock_target(h):
	return _locks.get(h)


# ---- 挫势（installNativeTusuRuntime applyCuoshi、endTurn 包装） ----
const STUN_STATE := 29
## 敌人身上的挫势（e._codexTusuCuoshi）：{base, stack, until, rate}
static var _cuoshi := {}


static func cuoshi_of(e):
	return _cuoshi.get(e)


static func _hyper(e) -> bool:
	return e is XEnemy and e.boss_difficulty_boss and e.boss_hyper_armor


static func _resist(e, id: int) -> bool:
	return e.traits_set(XBattler.TRAIT_STATE_RESIST).has(id)


## 震击、镇魂命中活着的敌人：同源不叠加，刷新取较低倍率与较晚到期；开刃·锤后最多 2 层（倍率按层数连乘）。
## 霸体 Boss：倍率 0.85～0.70、多挂一回合、挂 cuoshi2、不试眩晕；其余 0.90～0.80，再按状态接受率试一次眩晕（29）
static func apply_cuoshi(logic, e) -> bool:
	var hyper := _hyper(e)
	var lv := int(tusu().level) if tusu() != null else 1
	var r := XBinding.current_round()
	var rate := XGuyu.curve(lv, [0.85, 0.70], [20, 60]) if hyper else XGuyu.curve(lv, [0.90, 0.80], [20, 60])
	var until := r + (2 if hyper else 1)
	var sid := state_id("cuoshi2" if hyper else "cuoshi")
	if sid <= 0 or _resist(e, sid):
		return false
	var c = _cuoshi.get(e)
	var max_stack := 2 if has_kairen("hammer") else 1
	if c != null and int(c.until) >= r:
		c.base = minf(float(c.base), rate)
		c.stack = mini(max_stack, int(c.stack) + 1)
		c.until = maxi(int(c.until), until)
	else:
		c = {"base": rate, "stack": 1, "until": until}
		_cuoshi[e] = c
	c.rate = pow(float(c.base), int(c.stack))
	for k in ["cuoshi", "cuoshi2"]:
		_set_state(logic, e, state_id(k), false)
	logic._state_add(e, sid)
	if not hyper and logic._float("tusu_stun") < logic.state_rate(e, STUN_STATE) and not _resist(e, STUN_STATE):
		logic._state_add(e, STUN_STATE)
	return true


## endTurn 包装（原 endTurn 之后）：挫势按自然回合到期
static func end_turn(logic) -> void:
	var r := XBinding.current_round()
	for e in logic.enemies:
		var c = _cuoshi.get(e)
		if c != null and int(c.until) <= r:
			_cuoshi.erase(e)
			for k in ["cuoshi", "cuoshi2"]:
				_set_state(logic, e, state_id(k), false)


## 开刃：器谱选的武相（a._codexTusuKairen，存 s.flags），只算进阶阶数以内的（最多三相）
const KAIREN_FLAG := "_codexTusuKairen"
static func kairen(s: XState = null) -> Array:
	if s == null:
		s = XState.current
	return (s.flags.get(KAIREN_FLAG, []) as Array) if s != null else []


static func has_kairen(w: String) -> bool:
	var t = tusu()
	if t == null:
		return false
	var k := kairen()
	var stage := clampi(XAdvance.rank(XState.current, ACTOR), 0, 3)
	return k.has(w) and k.find(w) < stage


# ---- 止戈环 60 级与五兵淬纹（installThreeGrowthRelicRuntime 的 three60-effects 伤害钩子、apply／makeDamageValue／executeHpDamage／
# applyItemUserEffect 包装；都读屠苏的等级，屠苏不出战也读） ----
const RELIC := 4047
## T.TEMPER：五兵淬纹（屠苏成长被动，不需要装备法宝）10／20／30／40 级起 ×1.1，60 级 ×1.2；剑气纵横一直 ×1.1
const TEMPER := {"support.jianqi": 10, "arm.hengsao": 20, "arm.dianshe": 20, "arm.guanri": 20, "support.jintang": 30, "arm.chiling": 30, "arm.zhenji": 40, "support.zhenhun": 40}
const SEGMENTS := {"arm.dianshe": 2, "arm.guanri": 3, "arm.chiling": 2}
## 本次分段（action._codex60Segment）：{count, index, remainder}
static var _segment = null
## 横扫本次打到的目标（action._codex60SwordTargets），endAction 清
static var _sword_targets := []
## 剑气留在敌人身上的锻痕（target._codex60Forged.until）、挫势目标的下一次直接伤害减（enemy._codex60Crushed.until）
static var _forged := {}
static var _crushed := {}
## 护阵首次敌方伤害（t._codex60Guard）：{targets, action}；action 记第几次行动（原版比 Game_Action 对象，每次行动一个）
static var _guard = null
static var _action_no := 0


static func owner_actor():
	var s := XState.current
	return s.actors.get(ACTOR) if s != null else null


static func relic_on(t) -> bool:
	if t == null:
		return false
	for e in t.equips:
		if e is Dictionary and str(e.get("kind", "armor")) == "armor" and int(e.get("base", e.get("id", 0))) == RELIC:
			return true
	return false


static func temper_rate(t, k: String) -> float:
	var lv := int(t.level) if t != null else 1
	if not TEMPER.has(k) or lv < int(TEMPER[k]):
		return 1.0
	return 1.1 if lv < 60 or k == "support.jianqi" else 1.2


static func _evolved(t) -> bool:
	return t != null and int(t.level) >= 60 and relic_on(t)


## R.segments：60 级戴止戈环时点射 2 段、贯日 3 段、敕令 2 段
static func segments(skill: Dictionary) -> int:
	return int(SEGMENTS.get(key_of(skill), 1)) if _evolved(owner_actor()) else 1


## Game_Action.apply 包装（最外层）：一次行动分段打同一目标，目标倒下就停
static func apply_segments(logic, u, skill: Dictionary, t) -> Array:
	var n := segments(skill)
	var out := []
	_segment = {"count": n, "index": 0, "remainder": 0.0}
	for i in n:
		if not t.is_alive():
			break
		_segment.index = i
		out.append(logic.apply(u, skill, t))
	_segment = null
	return out


## makeDamageValue 包装：每段 ×1.2/段数向下取整，余数攒到最后一段
static func segment_value(value: float) -> float:
	if _segment == null:
		return value
	var exact := value * 1.2 / int(_segment.count)
	var part := floorf(exact)
	_segment.remainder = float(_segment.remainder) + exact - part
	if int(_segment.index) == int(_segment.count) - 1:
		part += floorf(float(_segment.remainder) + 1e-8)
	return part


## direct(action)：敌人用伤害类型 1／5、对敌方的行动
static func _direct(a, item: Dictionary) -> bool:
	return a is XEnemy and int(item.get("damage", {}).get("type", 0)) in [1, 5] and XSmartAI.for_opponent(item)


static func _three60_ops(item: Dictionary, a, b) -> Array:
	var ops := []
	var t = owner_actor()
	var k := key_of(item)
	var r := XBinding.current_round()
	if k != "" and t != null:
		var rate := temper_rate(t, k)
		if SEGMENTS.has(k) and _evolved(t) and _segment != null:
			rate = 1.0
		if rate != 1.0:
			ops.append({"op": "mul", "field": "finalMultiplier", "value": rate})
		if k == "arm.hengsao":
			if not _sword_targets.has(b):
				_sword_targets.append(b)
			if _sword_targets.find(b) > 0:
				ops.append({"op": "mul", "field": "finalMultiplier", "value": XGuyu.curve(int(t.level), [1, 1.2], [20, 60])})
		if (k == "arm.zhanfeng" or k == "arm.hengsao") and int(_forged.get(b, -1)) >= r:
			ops.append({"op": "mul", "field": "finalMultiplier", "value": 1.1})
	if _direct(a, item) and int(_crushed.get(a, -1)) >= r:
		ops.append({"op": "mul", "field": "finalMultiplier", "value": 0.9})
	return ops


## executeHpDamage 包装（屠苏、护盾账本之外）：护阵首次敌方伤害给命中的护阵队友护盾（屠苏双防和 ×18，1 回合）；返回打之前目标有没有挫势
static func hp_before(u, t, value: float, item: Dictionary) -> bool:
	var o = owner_actor()
	if value > 0.0 and _direct(u, item) and _evolved(o) and t is XActor and state_id("huzhen") > 0 and t.state_ids.has(state_id("huzhen")) and _guard != null:
		if _guard.action == null:
			_guard.action = _action_no
		if int(_guard.action) == _action_no and not _guard.targets.has(t):
			_guard.targets.append(t)
			XShieldLedger.grant(t, "tusu.fiveguard", (o.def + o.mdf) * 18.0, 1, ACTOR, {"noBonus": true, "noDecay": true})
	var c = _cuoshi.get(t)
	return c != null and int(c.until) >= XBinding.current_round()


static func hp_after(u, t, value: float, item: Dictionary, was_cuoshi: bool) -> void:
	if value <= 0.0:
		return
	var k := key_of(item)
	if not _act.has("internal") and t is XEnemy:
		_act.dealt = float(_act.get("dealt", 0.0)) + value  # 持武者主动行动的直接伤害（屠苏 executeHpDamage 包装）
	if k == "support.jianqi" or k == "support.zhenhun":
		_act.successful = true
	var o = owner_actor()
	if k == "arm.zhanfeng" or k == "arm.hengsao":
		_forged.erase(t)
	if _direct(u, item):
		_crushed.erase(u)
	if _evolved(o) and k == "support.jianqi":
		_forged[t] = XBinding.current_round()
	if _evolved(o) and was_cuoshi and (k == "arm.zhenji" or k == "support.zhenhun"):
		_crushed[t] = XBinding.current_round() + 1


## applyItemUserEffect 包装（命中后）：护阵给目标挂护阵（60 级另记首次敌方伤害）；震击、镇魂给活着的敌人挂挫势
static func user_effect(logic, u, skill: Dictionary, t) -> void:
	var key := key_of(skill)
	if key == "support.suoding" and _act.get("lock_target") != null:
		_locks[t] = _act.lock_target
		logic._state_add(t, state_id("lock"))
	if key == "support.heming":
		logic._state_add(t, state_id("heming"))
	if key == "support.jintang":
		var o = u if is_tusu(u) else tusu()
		var amount := shield_amount(o, t) * temper_rate(o, "support.jintang") * float(_act.get("support_bonus", 1.0)) * shield_support_rate(o)
		var before := XShieldLedger.amount(t, "tusu.jintang")
		XShieldLedger.grant(t, "tusu.jintang", amount, JINTANG_TURNS, ACTOR)
		if XShieldLedger.amount(t, "tusu.jintang") > before:
			_act.successful = true
	if key == "body.guard" and is_tusu(u):
		XShieldLedger.grant(t, "tusu.body", shield_amount(u, t) * BODY_GUARD_RATE, BODY_GUARD_TURNS, ACTOR)
	if key == "arm.huzhen":
		logic._state_add(t, state_id("huzhen"))
		if owner_actor() != null and _guard == null:
			_guard = {"targets": [], "action": null}
	if (key == "arm.zhenji" or key == "support.zhenhun") and t is XEnemy and t.is_alive():
		apply_cuoshi(logic, t)
	if key == "support.jianqi" and has_kairen("sword") and t is XEnemy and t.is_alive():
		logic.sequence_buff(t, 3, true, false, KAIREN_SWORD_DEBUFF_TURNS)  # 开刃·剑：物防减益 2 回合（直接挂，不掷）


static func _clear_marks() -> void:
	_locks.clear()
	_act = {}
	_logs.clear()
	_cuoshi.clear()
	_forged.clear()
	_crushed.clear()
	_sword_targets.clear()
	_segment = null
	_guard = null


# ---- 武相支援（installNativeTusuRuntime：屠苏自己用的主动支援、内部施放 B.cast、持武者行动触发、回合末释放） ----
const SUPPORT_RATE_R := 0.5
const SUPPORT_RATE_M := 2.7
const JINTANG_HP := 5.0
const JINTANG_DEF := 30.0
const JINTANG_TURNS := 2
const BODY_GUARD_RATE := 0.5
const BODY_GUARD_TURNS := 2
const KAIREN_SWORD_DEBUFF_TURNS := 2
const SHIELD_BELOW := 0.5
## 当前行动（原版记在 Game_Action 上的 _codexInternal、_codexTusuDealt、_codexTusuLockTarget、_codexTusuSupportBonus、
## _codexTusuResultSuccessful、_codex60BookHemingRate）；内部施放另开一份，放完还原
static var _act := {}
## 内部施放的结果（命中记录），由 start_action／end_action／回合末交回战斗记录
static var _logs := []


static func take_logs() -> Array:
	var out := _logs
	_logs = []
	return out


## manualSupport：屠苏自己（不是内部施放）用的支援，返回武相支援键（jianqi 等），否则空
static func manual_support(u, skill: Dictionary) -> String:
	var key := key_of(skill)
	return key.substr(8) if not _act.has("internal") and is_tusu(u) and key.begins_with("support.") else ""


static func unlocked(a, key: String) -> bool:
	return XTusuXuan.unlocked(ACTOR, a, key)


## T.weight／shieldAmount／supportBonus／shieldSupportRate
static func weight(a) -> float:
	return XGuyu.curve(int(a.level), [0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0], [1, 10, 20, 30, 40, 50, 60])


static func shield_amount(a, t) -> float:
	return maxf((JINTANG_HP * a.mhp + JINTANG_DEF * (a.def + a.mdf)) * weight(a), XGuyu.curve(int(a.level), [0.1, 0.3], [1, 60]) * t.mhp)


static func support_bonus(a, k: String) -> float:
	var d = data(a)
	if k in ["jianqi", "zhenhun", "jintang"] and int(a.level) >= 40 and (d == null or int(d.get("growth", 0)) != XBinding.current_round()):
		return XGuyu.curve(int(a.level), [1, 1.2], [40, 60])
	return 1.0


static func _boss_hyper_round(logic) -> bool:
	for e in logic.enemies:
		if e.is_alive() and _hyper(e):
			return true
	return false


static func shield_support_rate(a) -> float:
	var logic = _logic()
	return 1.2 if is_tusu(a) and has_kairen("shield") and logic != null and _boss_hyper_round(logic) else 1.0


## dangerEnemy：活着的敌人里 Boss 优先，再按物攻＋魔攻从高到低（同分保持原顺序）
static func danger_enemy(logic):
	var best = null
	for e in logic.enemies:
		if not e.is_alive():
			continue
		if best == null:
			best = e
			continue
		var bb := 1 if best.boss_difficulty_boss else 0
		var be := 1 if e.boss_difficulty_boss else 0
		if be > bb or (be == bb and e.atk + e.mat > best.atk + best.mat):
			best = e
	return best


## 支援的伤害上下限（统一伤害 res.after）：剑气、镇魂按自身基式，至少持武者这次伤害 ×0.5、至多自身 ×2.7，再乘成长加成；只在真结算时
static func support_after(item: Dictionary, a, value: float) -> float:
	var key := key_of(item)
	if key != "support.jianqi" and key != "support.zhenhun":
		return value
	var t = a if is_tusu(a) else tusu()
	var d = data(t)
	var trig := float(d.get("trigger", 0.0)) if d != null else 0.0
	return floorf(minf(maxf(value, trig * SUPPORT_RATE_R), value * SUPPORT_RATE_M) * float(_act.get("support_bonus", 1.0)))


## makeTargets 包装（屠苏自己的支援）：和鸣给持武者；锁定选的是敌人，实际给持武者；金汤滤掉形态中的本体。返回 null＝不管
static func targets(logic, a, skill: Dictionary, chosen):
	var key := manual_support(a, skill)
	if key == "":
		return null
	var sk := support_skill(a)
	var h = holder(a)
	if sk.is_empty() or int(sk.id) != int(skill.id) or h == null or not h.is_alive():
		return []
	if key == "heming":
		return [h]
	if key == "suoding":
		var e = chosen if chosen is XEnemy and chosen.is_alive() else (logic.alive(logic.enemies)[0] if not logic.alive(logic.enemies).is_empty() else null)  # smoothTarget
		if e == null:
			return []
		_act.lock_target = e
		return [h]
	if key == "jintang":
		return logic._targets_for(a, skill, chosen).filter(func(x): return not XBinding.untargetable(x))
	return null


## B.cast：内部施放，照常查冷却、付费（不插入行动序列），对每个活着的目标 apply 一次；返回实际作用的目标，失败返回空
static func cast(logic, owner, skill_id: int, list: Array, free: bool, setup: Dictionary) -> Array:
	var skill := XDB.rec("Skills", skill_id)
	if skill.is_empty() or not XBinding._live(owner):
		return []
	if not free:
		if owner.cooldown_left(skill_id) > 0:
			return []
		var can = can_pay(owner, skill, float(logic.skill_cost(owner, skill).tp))
		if can != null and not bool(can):
			return []
	var dead_scope := int(skill.get("scope", 0)) in [9, 10]
	list = list.filter(func(x): return x != null and (x.is_dead() if dead_scope else x.is_alive()))
	if list.is_empty():
		return []
	var prev := _act
	_act = {"internal": "tusu-support", "dealt": 0.0}
	_act.merge(setup, true)
	if not free:
		logic.pay_skill_cost(owner, skill)
	for x in list:
		_logs.append(logic.apply(owner, skill, x))
	setup.successful = bool(_act.get("successful", false))
	_act = prev
	_line("support")
	return list


## ready：解锁、冷却好了、付得起；冷却好了却谁都付不起就噬主失败回人形
static func _ready_support(owner, key: String) -> bool:
	var id := skill_id("support." + key)
	var skill := XDB.rec("Skills", id)
	if skill.is_empty() or not unlocked(owner, "support." + key) or owner.cooldown_left(id) > 0:
		return false
	var can = can_pay(owner, skill, 0.0)
	if can == null or bool(can):
		return true
	devour_fail(owner)
	return false


## support：屠苏放支援（非 free 要 1 点兵势，屠苏 manual，兵势平时恒 0）
static func support(logic, owner, key: String, list: Array, lock = null, free := false) -> bool:
	if list.is_empty() or not unlocked(owner, "support." + key):
		return false
	if not free and XBinding.charges(owner) < 1:
		return false
	if not free and not _ready_support(owner, key):
		return false
	if data(owner) == null:
		return false
	var setup := {"support_bonus": support_bonus(owner, key)}
	if lock != null:
		setup.lock_target = lock
	if cast(logic, owner, skill_id("support." + key), list, free, setup).is_empty():
		return false
	if not free:
		XBinding.spend(owner, 1)
	if bool(setup.get("successful", false)) and data(owner) != null:
		_d.growth = XBinding.current_round()
	return true


## roundSupport：按武相放支援（剑气打全体、镇魂打最危险的敌人、金汤给队友、和鸣给没有和鸣的持武者、锁定最危险的敌人）
static func round_support(logic, owner, key: String, free: bool) -> bool:
	var h = holder(owner)
	if h == null:
		return false
	match key:
		"jianqi":
			return support(logic, owner, "jianqi", logic.alive(logic.enemies), null, free)
		"zhenhun":
			var e = danger_enemy(logic)
			return e != null and support(logic, owner, "zhenhun", [e], null, free)
		"jintang":
			return support(logic, owner, "jintang", logic.actors.filter(func(x): return x.is_alive() and not (XBinding.untargetable(x) and x != h)), null, free)
		"heming":
			return not h.state_ids.has(state_id("heming")) and support(logic, owner, "heming", [h], null, free)
		"suoding":
			var e = danger_enemy(logic)
			return e != null and not _locks.has(h) and support(logic, owner, "suoding", [h], e, free)
	return false


## 回合末：还有兵势就按当前武相放一次支援（没有触发行动，按自身基式）
static func _round_end_release(owner) -> void:
	var w = weapon(owner)
	var logic = _logic()
	if w == null or logic == null or XBinding.charges(owner) < 1 or not XBinding.is_bound(owner):
		return
	if data(owner) != null:
		_d.trigger = 0.0
	round_support(logic, owner, SUPPORT_OF[w], false)


## startAction 包装（原 startAction 之前，由外到内）：
## 止戈环 bookProtection：持书且开刃·书的持武者用护持法术（治疗、复活、护盾、璃壁），没有和鸣先放和鸣，这次治疗／护盾 ×hemingRate；
## 持武者贯日前锁定目标、敕令前和鸣；敌人对我方的伤害行动前，盾相且全体攻击或有人半血以下就放金汤；屠苏自己的支援：读数清零、记成长加成
static func start_action(logic, u, skill: Dictionary, chosen) -> Array:
	_act = {"dealt": 0.0}
	var t = tusu()
	if t != null and XBinding.is_bound(t):
		if _book_protection(t, u, skill):
			if not u.state_ids.has(state_id("heming")):
				round_support(logic, t, "heming", false)
			if u.state_ids.has(state_id("heming")):
				_act.book_heming = heming_rate(t)
		var h = holder(t)
		var w = weapon(t)
		var key := key_of(skill)
		if is_same(u, h) and w == "bow" and key == "arm.guanri" and not _locks.has(h):
			if chosen is XEnemy and chosen.is_alive():
				support(logic, t, "suoding", [h], chosen)
		if is_same(u, h) and w == "book" and key == "arm.chiling" and not h.state_ids.has(state_id("heming")):
			support(logic, t, "heming", [h])
		if u is XEnemy and w == "shield" and XSmartAI.for_opponent(skill) and int(skill.get("damage", {}).get("type", 0)) in [1, 5]:
			var risky := XSmartAI.scope_of(skill) in [2, 8, 10]
			for x in logic.actors:
				if x.is_alive() and x.hp / maxf(1.0, x.mhp) <= SHIELD_BELOW:
					risky = true
			if risky:
				round_support(logic, t, "jintang", false)
	var mk := manual_support(u, skill)
	if mk != "" and data(u) != null:
		_d.trigger = 0.0
		_act.support_bonus = support_bonus(u, mk)
	return take_logs()


## 开刃·书的护持法术带和鸣：这次的治疗（executeHpDamage 负值）、护盾（addShield、账本 grant）×hemingRate（止戈环包装）
static func book_rate() -> float:
	return float(_act.get("book_heming", 1.0)) if _act.has("book_heming") else 1.0


static func book_heal(value: float) -> float:
	return floorf(value * book_rate()) if value < 0.0 and _act.has("book_heming") else value


static func _book_protection(t, u, skill: Dictionary) -> bool:
	if not (is_same(holder(t), u) and weapon(t) == "book" and has_kairen("book") and int(skill.get("hitType", 0)) == 2):
		return false
	if _act.has("internal") or not XSmartAI.scope_of(skill) in [7, 8, 9, 10, 11]:
		return false
	var f := str(skill.get("damage", {}).get("formula", ""))
	return int(skill.get("damage", {}).get("type", 0)) == 3 or skill.get("effects", []).any(func(e): return int(e.code) == 11) \
		or RegEx.create_from_string("(?:addShield|gainShield|ShieldLedger\\.grant)").search(f) != null or XTusuXuan.owner_of(int(skill.id)) == [177, "libi"]


# ---- 自动战斗与智能 AI（makeAutoBattleActions 包装、CodexAIEstimators） ----
const AI_HURT := 0.4


static func super_strong(a) -> bool:
	return a is XActor and XItemMarks.is_super_strong(int(a.actor_id))


## T.autoAction：武具态按规则易武（两人以上低于 40%、或下回合 Boss 霸体→盾；敌人 3 个以上→剑；只剩一个 Boss 且持剑→锤），
## 否则当前武相的支援有用就放，不然待命；人形时化武给默认宿主（上次武相维持得住）。返回 [技能, 目标]，空＝不管
static func auto_action(logic, a) -> Array:
	if not is_tusu(a) or not _in_battle():
		return []
	var allies: Array = logic.alive(logic.actors)
	var foes: Array = logic.alive(logic.enemies)
	if XBinding.is_bound(a):
		var d = data(a)
		var cur = d.reserve if d.reserve != null else d.weapon
		var nxt := int(logic.turn) + 1
		var want = null
		var hurt := allies.filter(func(x): return x.hp / maxf(1.0, x.mhp) < AI_HURT).size()
		var boss_next_hyper := foes.any(func(e): return e.boss_difficulty_boss) and nxt % 2 == 0
		if (hurt >= 2 or boss_next_hyper) and cur != "shield":
			want = "shield"
		elif foes.size() >= 3 and cur != "sword":
			want = "sword"
		elif foes.size() == 1 and foes[0].boss_difficulty_boss and cur == "sword":
			want = "hammer"
		if want != null:
			return [XDB.rec("Skills", skill_id("yiwu." + str(want))), null]
		var s := support_skill(a)
		var key := key_of(s) if not s.is_empty() else ""
		var h = holder(a)
		var target = danger_enemy(logic)
		var useful := not s.is_empty()
		if key == "support.suoding":
			useful = target != null and (not _locks.has(h) or not is_same(_locks[h], target))
		if key == "support.jintang":
			useful = allies.any(func(x): return not XBinding.untargetable(x) and XShieldLedger.amount(x, "tusu.jintang") < shield_amount(a, x) * temper_rate(a, key) * shield_support_rate(a) * support_bonus(a, "jintang"))
		if useful and logic.can_use(a, s):
			return [s, target if target != null and key in ["support.suoding", "support.zhenhun"] else null]
		return [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null]
	var host = XBinding.default_host(a)
	var w0 = _last(logic.state)
	if w0 == null:
		w0 = "sword"
	if host != null and can_maintain(w0, host):
		return [XDB.rec("Skills", skill_id("huawu." + str(w0))), host]
	return []


static func _preview(logic, u, skill: Dictionary, target) -> float:
	var sub = u
	if key_of(skill).begins_with("arm.") and tusu() != null:
		sub = tusu()
	var keep := _sword_targets.duplicate()
	var v := float(XDamage.calculate(skill, sub, target, {"preview": true, "critical": false, "vars": logic.vars()}).get("value", 0.0))
	_sword_targets = keep  # 预览的横扫目标表记在临时行动上，不留
	var hits: int = logic.alive(logic.enemies).size() if XSmartAI.scope_of(skill) in [2, 8, 10] else 1
	return v * hits * maxf(1.0, float(XBattleLogic.attack_repeats(u, skill, 1)))


## T.hostAuto：持武者（不是超强者）自动战斗选的对敌伤害技能，比不过某个武装技能（统一伤害预览 ×1.1）就换成它，打 Boss 优先、血最多的敌人
static func host_auto(logic, h, r: Array) -> Array:
	var t = tusu()
	if t == null or not is_same(holder(t), h) or super_strong(h) or r.is_empty() or not r[0] is Dictionary:
		return r
	var foes: Array = logic.alive(logic.enemies)
	if foes.is_empty():
		return r
	var item: Dictionary = r[0]
	if item.is_empty() or key_of(item) != "" or not XSmartAI.for_opponent(item) or not int(item.get("damage", {}).get("type", 0)) in [1, 5]:
		return r
	var focus = foes[0]
	for e in foes:
		var be := 1 if e.boss_difficulty_boss else 0
		var bf := 1 if focus.boss_difficulty_boss else 0
		if be > bf or (be == bf and e.hp > focus.hp):
			focus = e
	var best = null
	var best_value := _preview(logic, h, item, focus) * 1.1
	for s in h.skills():
		var k := key_of(s)
		if not k.begins_with("arm.") or not logic.can_use(h, s) or int(s.get("damage", {}).get("type", 0)) != 1:
			continue
		var v := _preview(logic, h, s, focus)
		if v > best_value:
			best = s
			best_value = v
	return [best, focus] if best != null else r


## makeAutoBattleActions 包装（原选择之后）：屠苏按自己的规则，持武者比武装技能
static func auto(logic, a, r: Array) -> Array:
	if is_tusu(a) and _in_battle():
		var act := auto_action(logic, a)
		return act if not act.is_empty() else r
	return host_auto(logic, a, r) if _in_battle() else r


## CodexAIEstimators：武装、支援、本体技能按屠苏的公式估（原始公式值），超强者持武的武装技能估 0；不是屠苏的技能返回 null
static func ai_raw(a, b, item: Dictionary):
	var key := key_of(item)
	if key == "":
		return null
	if key.begins_with("arm.") and super_strong(a):
		return 0.0
	if key.begins_with("arm.") or key.begins_with("support.") or key.begins_with("body."):
		var k := key.split(".")[1]
		var v := damage(a, b, ("body_" + k) if key.begins_with("body.") else k)
		if key == "arm.guanri" and is_same(_locks.get(a), b):
			v *= lock_rate(tusu())
		if key == "arm.chiling" and a.state_ids.has(state_id("heming")):
			v *= heming_rate(tusu())
		return v
	return 0.0


# ---- 器谱：开刃（T.forgeRows／setKairen／syncKairenSkills；菜单画面没做） ----
const REFORGE_ITEM := 2530
const REFORGE_COUNT := 10
const FORGE_NAMES := {"forgeInfo": "每次进阶可开刃一相，最多三相；重新开刃消耗人道意志碎片×10", "forgePick": "第%d道铭文：选择开刃的武相",
	"forgeTitle": "器谱　开刃 %d/3", "kairen_sword": "开刃·剑", "kairen_bow": "开刃·弓", "kairen_shield": "开刃·盾", "kairen_book": "开刃·书", "kairen_hammer": "开刃·锤",
	"kairenDesc_sword": "剑气纵横附带群体破防", "kairenDesc_bow": "贯日击杀目标时返还锁定", "kairenDesc_shield": "霸体回合主动施放金汤时，护盾量额外提高20%",
	"kairenDesc_book": "和鸣增幅一次治疗或护盾法术；仍支付支援费用", "kairenDesc_hammer": "挫势可叠到2层"}


static func _stage(s: XState) -> int:
	return clampi(XAdvance.rank(s, ACTOR), 0, 3)


## 器谱各行：标题「器谱　开刃 n/3」，三道铭文（进阶到了才开放）
static func forge_rows(s: XState) -> Array:
	var k := kairen(s)
	var n := _stage(s)
	var rows := [{"label": FORGE_NAMES.forgeTitle % n, "enabled": false}]
	for i in 3:
		var w = k[i] if i < k.size() else null
		rows.append({"slot": i, "label": ("" if i < n else "（未开放）") + "第%d道铭文：" % (i + 1) + (FORGE_NAMES["kairen_" + str(w)] if w != null else "未开刃"), "enabled": i < n})
	return rows


## setKairen：第 slot 道铭文开刃 w（已开在别的铭文上的相不能再开）；换掉已开的相要人道意志碎片 ×10，不够返回提示，成功返回空
static func set_kairen(s: XState, slot: int, w: String) -> String:
	var k := kairen(s).duplicate()
	if slot >= _stage(s) or not WEAPONS.has(w):
		return "invalid"
	if k.has(w) and k.find(w) != slot:
		return "invalid"
	if slot < k.size() and k[slot] != null and k[slot] != w:
		if s.item_count(REFORGE_ITEM) < REFORGE_COUNT:
			return "重新开刃需要%s×%d" % [str(XDB.rec("Items", REFORGE_ITEM).get("name", "")), REFORGE_COUNT]
		s.gain_item(REFORGE_ITEM, -REFORGE_COUNT)
	while k.size() <= slot:
		k.append(null)
	k[slot] = w
	s.flags[KAIREN_FLAG] = k
	sync_kairen_skills(s)
	return ""


## syncKairenSkills：进阶阶数以内开了的相学「开刃·x」被动，其余忘掉（读档、开刃时同步）
static func sync_kairen_skills(s: XState) -> void:
	var a = s.actors.get(ACTOR) if s != null else null
	if a == null:
		return
	var k := kairen(s).slice(0, _stage(s))
	for w in WEAPONS:
		var id := skill_id("kairen." + w)
		if id <= 0:
			continue
		if k.has(w):
			a.learn_skill(id)
		else:
			a.forget_skill(id)


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
	_line("devourFail")
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
	if who == "host":
		_line("devour")


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
		_line("reserve", NAMES[key.substr(5)])
	elif XBinding.can_host(u, t):
		if _d.is_empty():
			_d = _fresh()
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
	_clear_marks()  # 敌人的挫势与止戈环标记（敌人身上的挫势、眩晕状态不删，同原版）
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
