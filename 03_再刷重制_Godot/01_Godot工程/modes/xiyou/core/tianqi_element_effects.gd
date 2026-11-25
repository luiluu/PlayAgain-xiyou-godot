class_name XTianqiElementEffects
extends RefCounted
## 【cc／小A·天启篇·未经审查】天启篇元素独特效果（设计稿《天启篇_元素独特效果_v0.3》§3.1～3.6、4.2～4.4、5.1、5.3、5.5；T480 B 卡我方打敌 ＋ T485 B2 卡敌打我方）。
## 只对天启篇存档生效（XTianqiElements.on：XTianqi.active＋发行守卫），开关 XTianqiElements.EFFECTS；西游档、开关关着时每个入口都直接返回、不取随机数。
##
## 事件契约（§3.1）：BattleLogic.apply 每段结算后 note_hit 只记账不掷；一次行动（execute 一次、反击一次各开一帧）收尾时
## 对每个（实际扣血对象, 胜出元素）只掷一次，基数＝该行动对该目标该系合格段 hp_loss 合计。没有帧的零散段（直接调 apply）在 act 收尾按出手者各掷。
## 合格段：胜出元素是基础十系、hp_loss > 0、未闪避未落空、跨边（我方打敌或敌打我方，不认自伤／友伤）；持续伤害跳数、空蚀不经 apply 记账，天然不算。
## 敌打我方（§4.4、§5.3）共用同一套帧、段记录、状态与 _try_apply：我方受者走「硬免疫 → 体质免疫 → 状态有效度 → 停手类六维韧性（只乘一次）」；
## 敌方统一用 enemy_effect_rules.base_chance（11%，首领不加成）并受施效预算（普通一次最多 1 停手、精英／化形另每场对同角最多 2 停手、首领每行动最多 1 效果／麻痹换感电／不冻我方／首领一侧圣护每场 3 次）。
## 高等三系本轮不扩到敌打我方（D285③）：敌人高等三系打我方只走受击者原属性倍率，不触发吞没／无序／空蚀、不掷十系效果。
##
## 停手（§3.6）：麻痹、冰冻是 restriction 0 的标记状态，只跳过下一个本可执行的行动位（act 里 take_skip），一次只吃一位；
## 吃位后目标要自己完成 5 次行动才可再被元素停手（stop_need）；旧控（restriction ≥ 4）挂上时 stop_need 至少 1、待生效标记直接移除。
## 随机（§5.5）：从本场种子派生的效果子流 elem_effects，不动战斗主流；挂状态的持续回合也用子流掷。

const META := "_tianqi_elem_fx"

## 新建状态号段（表外，XDB.rec 认）：图标、BuffType 照抄原版同类，不引用原版状态号（§2.2 末）
const ST_BURN := 10940
const ST_SLOW := 10941
const ST_FREEZE := 10942
const ST_SHATTER := 10943
const ST_PARALYZE := 10944
const ST_PARASITE := 10945
const ST_SOAK := 10946
const ST_GUST := 10947
const ST_ARCANE := 10948
const ST_HOLY := 10949
const ST_VEIL := 10950
const ST_SHOCK := 10951
const STATE_IDS := [ST_BURN, ST_SLOW, ST_FREEZE, ST_SHATTER, ST_PARALYZE, ST_PARASITE, ST_SOAK, ST_GUST, ST_ARCANE, ST_HOLY, ST_VEIL, ST_SHOCK]
const STOP_STATES := [ST_PARALYZE, ST_FREEZE]
const KEY_STATE := {"burn": ST_BURN, "slow": ST_SLOW, "freeze": ST_FREEZE, "shatter": ST_SHATTER, "paralyze": ST_PARALYZE, "parasite": ST_PARASITE,
	"soak": ST_SOAK, "gust": ST_GUST, "arcane": ST_ARCANE, "holy": ST_HOLY, "veil": ST_VEIL, "shock": ST_SHOCK}

## 状态记录规格：[名字, 图标, BuffType, 特性模板, 说明草稿（待小A 审；{v} 换成表里的百分数）, 自动解除时机, 数值读 element_effects 哪一系（"" 不读）, 读 boss 段]
## 特性模板里的 value 是占位：state_rec 按 elements_table.json 的 element_effects.<系>.value 生成（R2 P2-1：C 卡改表即生效）
const SPECS := {
	ST_BURN: ["灼烧", 1072, "灼伤", [], "回合结束受到火焰持续伤害", 2, "", false],
	ST_SLOW: ["迟缓", 420, "减益", [{"code": 21, "dataId": 6, "mode": "rate"}], "敏捷 −{v}%", 2, "3", false],
	ST_FREEZE: ["冰冻", 0, "冰冻", [], "跳过下一次行动", 0, "", false],
	ST_SHATTER: ["碎甲", 706, "破甲", [{"code": 21, "dataId": 3, "mode": "rate"}], "物理防御 −{v}%", 2, "4", false],
	ST_PARALYZE: ["麻痹", 1029, "麻痹", [], "跳过下一次行动", 0, "", false],
	ST_PARASITE: ["寄生", 1072, "减益", [], "回合结束受自然伤害，为施加方血量最低者回等量血", 2, "", false],
	ST_SOAK: ["浸湿", 0, "减益", [], "造成伤害 −{v}%", 2, "14", false],
	ST_GUST: ["乱流", 921, "减益", [{"code": 22, "dataId": 0, "mode": "minus"}, {"code": 22, "dataId": 1, "mode": "minus"}], "命中 −{v}%，闪避 −{v}%", 2, "15", false],
	ST_ARCANE: ["魔蚀", 706, "破甲", [{"code": 21, "dataId": 5, "mode": "rate"}], "魔法防御 −{v}%", 2, "7", false],
	ST_HOLY: ["圣护", 0, "增益", [], "抵挡下一次可净化的负面状态，不挡伤害（1次）", 2, "", false],
	ST_VEIL: ["遮蔽锋芒", 921, "减益", [], "暴击多出的伤害 −{v}%", 2, "9", false],
	ST_SHOCK: ["感电", 1029, "减益", [], "受到的伤害 +{v}%（与弱点暴露、破绽取高）", 2, "5", true],
}

static var _recs: Dictionary = {}
## 当前战斗（add_state 钩子没有 logic 参数时用）；start 设、finish 清。只存弱引用：不能替战斗对象续命（T181 swap_hold 靠战斗对象释放来放开）
static var _logic_ref: WeakRef = null


static func _cur():
	return _logic_ref.get_ref() if _logic_ref != null else null


# ---- 状态记录（XDB.rec 表外号段） ----

static func has_state(id: int) -> bool:
	return SPECS.has(id)


static func state_rec(id: int) -> Dictionary:
	if not SPECS.has(id):
		return {}
	if not _recs.has(id):
		var sp: Array = SPECS[id]
		var v := spec_value(id)
		var traits := []
		for tr in sp[3]:
			var val := (1.0 - v) if str(tr.mode) == "rate" else -v
			traits.append({"code": int(tr.code), "dataId": int(tr.dataId), "value": val})
		var desc := str(sp[4]).replace("{v}", "%d" % roundi(v * 100.0))
		var note := "<BuffType:%s>\n<StateNote>\n%s\n</StateNote>" % [sp[2], desc]
		_recs[id] = {"id": id, "name": sp[0], "iconIndex": int(sp[1]), "note": note, "traits": traits,
			"restriction": 0, "autoRemovalTiming": int(sp[5]), "minTurns": 1, "maxTurns": 1, "priority": 60,
			"removeAtBattleEnd": true, "removeByDamage": false, "removeByRestriction": false, "removeByWalking": false,
			"chanceByDamage": 100, "stepsToRemove": 100, "motion": 0, "overlay": 0, "messageType": 1,
			"message1": "", "message2": "", "message3": "", "message4": "", "effects": [],
			"meta": {"BuffType": sp[2], "StateNote": true, "/StateNote": true, "TianqiElemEffect": true}}
	return _recs[id]


## 状态数值（比例，如 0.22）：读 element_effects.<系>.value（感电读麻痹的 boss.value）；表缺时 0
static func spec_value(id: int) -> float:
	if not SPECS.has(id) or str(SPECS[id][6]) == "":
		return 0.0
	var sp := _spec(int(SPECS[id][6]))
	if bool(SPECS[id][7]):
		sp = sp.get("boss", {})
	return float(sp.get("value", 0.0))


## XTianqiElements.reload_table 时调：状态记录按新表重建
static func clear_cache() -> void:
	_recs = {}


# ---- 开关与数据 ----

static func data() -> Dictionary:
	return XTianqiElements.data()


static func on(logic) -> bool:
	return XTianqiElements.EFFECTS and logic != null and XTianqiElements.on(logic.state) and data().has("element_effects")


static func _fx(logic) -> Dictionary:
	if logic == null or not logic.has_meta(META):
		return {}
	return logic.get_meta(META)


static func _rules() -> Dictionary:
	return data().get("effect_rules", {})


static func _enemy_rules() -> Dictionary:
	return data().get("enemy_effect_rules", {})


static func _spec(elem: int) -> Dictionary:
	return data().get("element_effects", {}).get(str(elem), {})


static func is_base(elem: int) -> bool:
	return XTianqiElements.BASE_ELEMENTS.has(elem)


## 人数档几率（§5.1）：effect_tier_of 定档，effect_tiers 给几率
static func tier_chance(elem: int) -> float:
	var tier := str(data().get("effect_tier_of", {}).get(str(elem), "mid"))
	return float(data().get("effect_tiers", {}).get(tier, {}).get("chance", 0.15))


# ---- 战斗生命周期 ----

static func start(logic) -> void:
	if logic == null:
		return
	if logic.has_meta(META):
		logic.remove_meta(META)
	if not on(logic):
		_logic_ref = null  # 西游档／开关关：add_state 钩子不再指向上一场天启篇战斗
		return
	logic._rule()  # 只确保本场随机对象建好（不取数）
	var rnd = logic.random
	var base_seed := ""
	if rnd is XBattleRandom:
		base_seed = rnd.pin_seed if rnd.pinned() else rnd.master_seed
	if base_seed == "":
		base_seed = XRandomStream.hex64(XState._fresh_seed())
	var seed_hex := XRandomStream.derive(base_seed, "elem_effects")
	logic.set_meta(META, {"seed": seed_hex, "stream": XRandomStream.create(seed_hex, "elem_effects"),
		"frames": [], "loose": [], "units": {}, "logs": [], "stats": {}, "holy_boss": 0})
	_logic_ref = weakref(logic)


static func finish(logic) -> void:
	if logic != null and logic.has_meta(META):
		logic.remove_meta(META)
	if is_same(_cur(), logic):
		_logic_ref = null


## 回合末（XTianqiElements.end_turn，状态已按回合递减）：把到期的效果记进冷却
static func end_turn(logic) -> void:
	var fx := _fx(logic)
	if fx.is_empty():
		return
	for b in fx.units:
		_sync_unit(logic, b)


## 本场子流种子与逐效果计数（C 卡量数、回放记录用）
static func seed_of(logic) -> String:
	return str(_fx(logic).get("seed", ""))


static func stats(logic) -> Dictionary:
	return _fx(logic).get("stats", {})


static func _stat(fx: Dictionary, elem: int, what: String) -> void:
	var k := str(elem)
	if not fx.stats.has(k):
		fx.stats[k] = {"eligible": 0, "immune": 0, "blocked": 0, "rolled": 0, "applied": 0}
	fx.stats[k][what] = int(fx.stats[k].get(what, 0)) + 1


# ---- 单位记账 ----

static func _unit(fx: Dictionary, b) -> Dictionary:
	if not fx.units.has(b):
		fx.units[b] = {"active": {}, "until": {}, "stop_need": 0, "slow_n": 0, "frozen": 0, "dot": {}, "skips": 0, "done": 0, "stops_on": {}}
	return fx.units[b]


## 效果状态还挂没挂：挂过但现在不在了（到期、净化、被旧状态顶掉）就从这一刻起算冷却
static func _sync_unit(logic, b) -> void:
	var fx := _fx(logic)
	var u := _unit(fx, b)
	var turn := int(logic.turn)
	for key in u.active.keys():
		var sid := int(u.active[key])
		if not b.state_ids.has(sid):
			u.active.erase(key)
			u.dot.erase(key)
			var cd := int(_rules().get("boss_cooldown", 2)) if effect_boss(logic, b) else int(_rules().get("cooldown", 1))
			u.until[key] = turn + cd


static func _ready_for(logic, b, key: String) -> bool:
	_sync_unit(logic, b)
	var u := _unit(_fx(logic), b)
	if u.active.has(key):
		return false  # 持续中不重挂、不刷新
	return int(logic.turn) > int(u.until.get(key, -999))


# ---- 身份 ----

## §4.3 统一首领谓词：is_boss_enemy ∪ 终焉级异化；非首领的化形不算首领，按精英处理
static func effect_boss(logic, t) -> bool:
	if not (t is XEnemy):
		return false
	if XTianqiElements.is_boss_enemy(t):
		return true
	if logic != null:
		for row in XTianqiAlienGear.alien_units(logic):
			if is_same(row.get("enemy"), t) and str(row.get("level", "")) == "zhongyan":
				return true
	return false


## §5.3 精英／化形谓词（非首领）：神话／精英标记、化形级异化、敌人名含【精英】、六维表 class == "elite"
static func effect_elite(logic, t) -> bool:
	if not (t is XEnemy) or effect_boss(logic, t):
		return false
	var e := t as XEnemy
	if e.elite:
		return true
	if logic != null:
		for row in XTianqiAlienGear.alien_units(logic):
			if is_same(row.get("enemy"), e) and str(row.get("level", "")) == "huaxing":
				return true
	if str(e.data().get("name", "")).contains("【精英】"):
		return true
	return str(XTianqiSixDim.data().get("enemies", {}).get(str(e.enemy_id), {}).get("class", "")) == "elite"


## 双向（T480 我方打敌 ＋ T485 B2 敌打我方）：只认敌我跨边，不认自伤／友伤
static func _side_ok(src, t) -> bool:
	return (src is XActor and t is XEnemy) or (src is XEnemy and t is XActor)


static func _same_side(a, b) -> bool:
	return (a is XActor and b is XActor) or (a is XEnemy and b is XEnemy)


# ---- 行动帧（§3.1） ----

static func frame_begin(logic, src) -> bool:
	var fx := _fx(logic)
	if fx.is_empty() or src == null:
		return false
	fx.frames.append({"src": src, "segs": [], "holy_allies": []})
	return true


static func frame_end(logic, src) -> Array:
	var fx := _fx(logic)
	if fx.is_empty() or fx.frames.is_empty():
		return []
	# T480 复核 P3-4：先结算再弹栈，免得敌人反击结算给持盾我方挂元素减益时 shield_blocks 误读外层我方帧主漏挡
	var f: Dictionary = fx.frames.back()
	var logs := _settle(logic, f)
	fx.frames.pop_back()
	logs.append_array(_take_logs(fx))
	return logs


static func _frame_for(fx: Dictionary, src) -> Dictionary:
	for i in range(fx.frames.size() - 1, -1, -1):
		if is_same(fx.frames[i].src, src):
			return fx.frames[i]
	for f in fx.loose:
		if is_same(f.src, src):
			return f
	var nf := {"src": src, "segs": [], "holy_allies": []}
	fx.loose.append(nf)
	return nf


## BattleLogic.apply 末尾：只记账不掷（§3.1 段记录）
static func note_hit(logic, u, skill: Dictionary, t, r: Dictionary) -> void:
	var fx := _fx(logic)
	if fx.is_empty() or u == null or t == null:
		return
	if bool(r.get("missed", false)) or bool(r.get("evaded", false)) or bool(r.get("unused", false)):
		return
	if bool(r.get("reflected", false)) or bool(logic.get("_reflecting")):
		return  # 反射回出手者自己的结算（R2 P1-2）：既不是合格伤害段（§3.1 只认 origin skill），也不走神圣己方入口
	var dtype := int(skill.get("damage", {}).get("type", 0))
	var hit_t = r.get("hit_target", t)
	var row: Dictionary = r.get("best_row", {})
	if dtype in [1, 5] and not row.is_empty() and _side_ok(u, hit_t):
		var hp_loss := float(r.get("hp_loss", 0.0))
		var e := int(row.get("element", 0))
		_frame_for(fx, u).segs.append({"hit_target": hit_t, "settled_element": e, "element_kind": str(row.get("tianqiKind", "")),
			"hp_loss": hp_loss, "origin": "skill"})
		return
	# 神圣对己方用（§3.5 己方目标入口，敌我镜像）：非伤害技能（不是道具）算神圣己方技、目标是自己人、结算了（活着）
	if dtype in [1, 5]:
		return  # 伤害技打到自己人（混乱、反射已在上面拦）不走己方入口
	if (u is XActor or u is XEnemy) and _same_side(u, t) and not XBattleLogic.is_item(skill) and t.is_alive() and holy_ally_skill(skill, u):
		var f := _frame_for(fx, u)
		if not (f.holy_allies as Array).has(t):
			f.holy_allies.append(t)


## 哪些己方技算神圣（R2 P1-1 丙案 ＋ T485 B2 敌方镜像）：真实库里己方目标技没有一个带神圣元素（全是治疗 10／无属性 0），所以不看技能元素——
## 转换书、转属只管攻击，碰不到这里。口径＝elements_table.holy_ally：
##   exclude 排除名单 → 不算（先于其它两条）；skills 白名单（非神圣体质角色／敌人的圣光类技能）→ 算；
##   by_nature 为真时：敌方施放者看自身自然体质（enemy_nature.json）含神圣；我方看技能卡归属角色自然体质（actor_nature.json）含神圣。
static func holy_ally_skill(skill: Dictionary, u = null) -> bool:
	var id := int(skill.get("id", 0))
	var cfg: Dictionary = data().get("holy_ally", {})
	if _int_list(cfg.get("exclude", [])).has(id):
		return false
	if _int_list(cfg.get("skills", [])).has(id):
		return true
	if not bool(cfg.get("by_nature", true)):
		return false
	if u is XEnemy:
		return XTianqiNature.of(u).has(8)
	var card: Dictionary = XTianqiSkills.data().get("skills", {}).get(str(id), {})
	if not card.has("actor"):
		return false
	var row: Dictionary = XTianqiNature.actor_table().get("actors", {}).get(str(int(card.actor)), {})
	return _int_list(row.get("natures", [])).has(8)


static func _int_list(a) -> Array:
	var out := []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out


## act 收尾：零散段（没开帧的 apply、反击外的直接结算）按出手者各掷；记「完成的行动」（§3.6）
static func act_end(logic, u, completed: bool) -> Array:
	var fx := _fx(logic)
	if fx.is_empty():
		return []
	var logs := []
	while not fx.loose.is_empty():
		logs.append_array(_settle(logic, fx.loose.pop_front()))
	if completed and u != null:
		var un := _unit(fx, u)
		un.done = int(un.done) + 1
		un.stop_need = maxi(0, int(un.stop_need) - 1)
	logs.append_array(_take_logs(fx))
	return logs


## 测试与工具用：把零散段立刻掷掉（不计完成行动）
static func flush(logic) -> Array:
	return act_end(logic, null, false)


static func _take_logs(fx: Dictionary) -> Array:
	var out: Array = fx.logs
	fx.logs = []
	return out


static func _say(fx: Dictionary, text: String) -> void:
	fx.logs.append({"type": "battle_text", "text": text})


## 一帧收尾：按（实际扣血对象, 胜出元素）首次出现的顺序各掷一次；神圣整帧最多一次
static func _settle(logic, f: Dictionary) -> Array:
	var fx := _fx(logic)
	var src = f.src
	var order := []
	var base := {}
	var holy_hit := false
	for s in f.segs:
		var e := int(s.settled_element)
		if not is_base(e) or float(s.hp_loss) <= 0.0 or str(s.origin) != "skill":
			continue
		if e == 8:
			holy_hit = true
			continue
		var t = s.hit_target
		var key := [t, e]
		var found := -1
		for i in order.size():
			if is_same(order[i][0], t) and int(order[i][1]) == e:
				found = i
				break
		if found < 0:
			order.append(key)
			found = order.size() - 1
		base[found] = float(base.get(found, 0.0)) + float(s.hp_loss)
	var budget := {"applied": 0, "stops": 0}
	for i in order.size():
		var t = order[i][0]
		if is_instance_valid(t) and t.is_alive():
			_try_apply(logic, src, t, int(order[i][1]), float(base.get(i, 0.0)), budget)
	var allies: Array = f.holy_allies
	if (holy_hit or not allies.is_empty()) and is_instance_valid(src) and src.is_alive():
		_try_holy(logic, src, allies, holy_hit, budget)
	return _take_logs(fx)


# ---- 判定与施加 ----

static func _immune(t, elem: int) -> bool:
	var imm: Dictionary = data().get("effect_immunity", {}).get(str(elem), {})
	var natures := XTianqiNature.of(t)
	for c in imm.get("constitution", []):
		if natures.has(int(c)):
			return true
	var races := XTianqiNature.races(t)
	for rc in imm.get("race", []):
		if races.has(int(rc)):
			return true
	return false


static func _boost(t, elem: int) -> float:
	var out := 1.0
	var natures := XTianqiNature.of(t)
	var bo: Dictionary = data().get("effect_immunity", {}).get(str(elem), {}).get("boost", {})
	for k in bo:
		if natures.has(int(k)):
			out = maxf(out, float(bo[k]))
	return out


## 硬免疫（装备、被动 TRAIT_STATE_RESIST）：查新状态与借图标的原版同类状态
static func _hard_resist_only(t, sid: int, borrow: int) -> bool:
	for id in [sid, borrow]:
		if id > 0 and t.traits_set(XBattler.TRAIT_STATE_RESIST).has(id):
			return true
	return false


## 敌人受者用：硬免疫／借用状态有效度 0（敌人身上对原版灼伤、麻痹的抗性照样算）
static func _hard_blocked(logic, t, sid: int, borrow: int) -> bool:
	if _hard_resist_only(t, sid, borrow):
		return true
	return borrow > 0 and logic.state_rate(t, borrow) <= 0.0


## §4.4 我方受者状态有效度：装备／被动 TRAIT_STATE_RATE × 天启篇异常抵抗词条（不含六维韧性，停手类在后面单独乘一次）
static func _actor_state_rate(t, sid: int, borrow: int) -> float:
	var rate: float = float(t.traits_pi(XBattler.TRAIT_STATE_RATE, sid))
	if borrow > 0:
		rate *= float(t.traits_pi(XBattler.TRAIT_STATE_RATE, borrow))
	var ar := XTianqiAffixBattle.state_rate(t, sid)
	if borrow > 0 and is_equal_approx(ar, 1.0):
		ar = XTianqiAffixBattle.state_rate(t, borrow)
	return rate * ar


## §5.3 敌方停手预算：普通怪／精英／化形每次行动最多给 1 个目标挂停手；精英／化形另每场对同一角色最多 2 次停手
static func _enemy_stop_ok(fx: Dictionary, src, src_elite: bool, t, budget: Dictionary) -> bool:
	if int(budget.get("stops", 0)) >= 1:
		return false
	if src_elite:
		var cap := int(_enemy_rules().get("elite_stun_per_battle", 2))
		if int(_unit(fx, src).stops_on.get(t, 0)) >= cap:
			return false
	return true


static func _old_stopped(t) -> bool:
	for s in t.states():
		if int(s.get("restriction", 0)) >= 4:
			return true
	return false


static func _has_buff_type(t, type: String) -> bool:
	for s in t.states():
		if STATE_IDS.has(int(s.get("id", 0))):
			continue
		if str(s.get("meta", {}).get("BuffType", "")).strip_edges() == type:
			return true
	return false


## 停手资格（§3.6）：没有旧停手、没有待生效标记、共用冷却走完
static func _stop_ok(logic, t) -> bool:
	if _old_stopped(t):
		_unit(_fx(logic), t).stop_need = maxi(int(_unit(_fx(logic), t).stop_need), 1)
		return false
	for sid in STOP_STATES:
		if t.state_ids.has(sid):
			return false
	return int(_unit(_fx(logic), t).stop_need) <= 0


static func _try_apply(logic, src, t, elem: int, base_hp: float, budget := {}) -> void:
	var fx := _fx(logic)
	var spec := _spec(elem)
	if spec.is_empty() or elem == 8:
		return
	var enemy_src := src is XEnemy
	var actor_t := t is XActor
	var target_boss := effect_boss(logic, t)
	var src_boss := enemy_src and effect_boss(logic, src)
	var src_elite := enemy_src and effect_elite(logic, src)
	var boss_cap := int(_enemy_rules().get("boss_per_action_cap", 1))
	if src_boss and int(budget.get("applied", 0)) >= boss_cap:
		return  # §5.3 首领每个自己的行动最多挂 1 个新效果（全目标合计）
	var key := str(spec.get("key", ""))
	var sid := int(KEY_STATE.get(key, 0))
	var turns := int(spec.get("turns", 1))
	var value := float(spec.get("value", 0.0))
	if target_boss and spec.has("boss"):
		var bs: Dictionary = spec.boss
		if bs.has("key"):
			key = str(bs.key)
			sid = int(KEY_STATE.get(key, 0))
		turns = int(bs.get("turns", turns))
		value = float(bs.get("value", value))
	elif src_boss and actor_t and elem == 5 and bool(_enemy_rules().get("stun_soft_replace", true)) and spec.has("boss"):
		# §5.3 首领打我方：麻痹一律换软版「感电」（我方受伤 +11%，1 回合）
		var bs2: Dictionary = spec.boss
		if bs2.has("key"):
			key = str(bs2.key)
			sid = int(KEY_STATE.get(key, 0))
		turns = int(bs2.get("turns", turns))
		value = float(bs2.get("value", value))
	_stat(fx, elem, "eligible")
	if not _ready_for(logic, t, key):
		return
	# 冰：本场第 2 次迟缓（或浸湿中、水体质第一次）改冰冻；首领作受者只迟缓，首领打我方也不冻我方（§4.3、§5.3）
	var un := _unit(fx, t)
	var freeze := false
	if key == "slow" and not target_boss and not src_boss:
		var need := int(_rules().get("freeze_on_slow_count", 2))
		var soaked: bool = t.state_ids.has(ST_SOAK)
		freeze = int(un.frozen) < int(_rules().get("freeze_per_battle", 1)) and (int(un.slow_n) + 1 >= need or soaked or XTianqiNature.of(t).has(14))
		if freeze and (not _ready_for(logic, t, "freeze") or not _stop_ok(logic, t)):
			freeze = false
		if freeze and enemy_src and not _enemy_stop_ok(fx, src, src_elite, t, budget):
			freeze = false
		if freeze:
			key = "freeze"
			sid = ST_FREEZE
	var stop := key in ["paralyze", "freeze"]
	var borrow := 0 if key == "shock" else (int(spec.get("freeze", {}).get("borrow", 0)) if key == "freeze" else int(spec.get("borrow", 0)))  # 感电不借麻痹（不是控制）
	var eff_rate := 1.0
	if actor_t:
		# §4.4 我方判定顺序：硬免疫 → 体质免疫（4.2，不读种族）→ 状态有效度 → 停手类再乘一次六维韧性（×0.90～×1.10）
		if _hard_resist_only(t, sid, borrow):
			_stat(fx, elem, "blocked")
			return
		if _immune(t, elem):
			_stat(fx, elem, "immune")
			return
		eff_rate = _actor_state_rate(t, sid, borrow)
		if eff_rate <= 0.0:
			_stat(fx, elem, "blocked")
			return
	else:
		if _immune(t, elem):
			_stat(fx, elem, "immune")
			return
		if _hard_blocked(logic, t, sid, borrow):
			_stat(fx, elem, "blocked")
			return
	# §3.4 白名单归并：旧灼伤、旧麻痹挂着时新效果落空（不耗冷却；感电不是麻痹，不归并）
	if key != "shock":
		for bt in data().get("effect_merge", {}).get(str(elem), []):
			if _has_buff_type(t, str(bt)):
				_stat(fx, elem, "blocked")
				return
	if stop and not _stop_ok(logic, t):
		_stat(fx, elem, "blocked")
		return
	if stop and enemy_src and not _enemy_stop_ok(fx, src, src_elite, t, budget):
		_stat(fx, elem, "blocked")
		return
	var chance := float(_enemy_rules().get("base_chance", 0.11)) if enemy_src else tier_chance(elem)
	if not enemy_src and target_boss:
		chance *= float(_rules().get("boss_chance_rate", 0.5))
	if elem == 5:
		var rate := _boost(t, elem)
		if not target_boss and t.state_ids.has(ST_SOAK):
			rate = maxf(rate, 1.5)  # 水体质或浸湿：×1.5，两者都有也只 ×1.5
		chance *= rate
	if actor_t:
		chance *= eff_rate
		if stop:
			chance *= XTianqiSixDim.control_state_rate(t, sid, logic)  # §4.4 停手类再乘一次六维韧性（只乘一次）
	_stat(fx, elem, "rolled")
	if fx.stream.next_float("tianqi_elem_effect", "%d" % elem) >= chance:
		return
	if not _add(logic, src, t, sid, turns):
		_stat(fx, elem, "blocked")
		return
	_stat(fx, elem, "applied")
	un.active[key] = sid
	if enemy_src:
		budget["applied"] = int(budget.get("applied", 0)) + 1
		if stop:
			budget["stops"] = int(budget.get("stops", 0)) + 1
			if src_elite:
				var su := _unit(fx, src)
				su.stops_on[t] = int(su.stops_on.get(t, 0)) + 1
	if key == "slow":
		un.slow_n = int(un.slow_n) + 1
	if key == "freeze":
		un.frozen = int(un.frozen) + 1
		un.slow_n = int(un.slow_n) + 1  # 冰冻也算这一次迟缓
	if key in ["burn", "parasite"]:
		var cap := float(t.mhp) * float(_rules().get("dot_tick_cap", 0.05))
		var tick := floorf(base_hp * value)
		if key == "burn":
			tick = floorf(tick * _boost(t, elem))  # 自然体质受灼烧 ×1.5，仍受每跳上限
		un.dot[key] = {"tick": minf(tick, floorf(cap)), "src": src, "elem": elem}
	_say(fx, "%s 陷入了%s！" % [t.display_name(), str(SPECS[sid][0])])


## 用效果子流挂状态（持续回合不吃战斗主流），挂上后把回合数写成最终值（首领版不再减半，§4.3）
static func _add(logic, src, t, sid: int, turns: int) -> bool:
	var fx := _fx(logic)
	var res = logic._operation_resources(t)
	var prev = XImportedBalance.acting_battler()
	var prev_add = fx.get("_add_src", null)
	XImportedBalance.set_acting(src)
	fx["_add_src"] = src
	res.add_state(t, sid, {"random": fx.stream})
	logic._finish_lifecycle_operation(res, t)
	if prev_add == null:
		fx.erase("_add_src")
	else:
		fx["_add_src"] = prev_add
	XImportedBalance.set_acting(prev)
	if not t.state_ids.has(sid):
		return false
	t.state_turns[sid] = maxi(1, turns)
	return true


# ---- 神圣·圣护（§3.5，D285②＋补；敌我镜像，首领一侧每场最多 3 次） ----

## 对己方用：给每个目标（D285 补：群体人人都给）；对敌方用：给施放者自己。一次行动最多掷一次
static func _try_holy(logic, src, allies: Array, holy_hit: bool, budget := {}) -> void:
	var fx := _fx(logic)
	var enemy_src := src is XEnemy
	var src_boss := enemy_src and effect_boss(logic, src)
	var boss_side := enemy_src and (src_boss or (logic.enemies as Array).any(func(e): return effect_boss(logic, e)))
	var boss_cap := int(_enemy_rules().get("boss_per_action_cap", 1))
	var holy_cap := int(_rules().get("holy_boss_per_battle", 3))
	if src_boss and int(budget.get("applied", 0)) >= boss_cap:
		return
	if boss_side and int(fx.holy_boss) >= holy_cap:
		return
	var recips := []
	for a in allies:
		if is_instance_valid(a) and a.is_alive() and not recips.has(a):
			recips.append(a)
	if holy_hit and not recips.has(src):
		recips.append(src)
	_stat(fx, 8, "eligible")
	var ready := recips.filter(func(b): return not b.state_ids.has(ST_HOLY) and _ready_for(logic, b, "holy"))
	if ready.is_empty():
		return
	_stat(fx, 8, "rolled")
	var chance := float(_enemy_rules().get("base_chance", 0.11)) if enemy_src else tier_chance(8)
	if fx.stream.next_float("tianqi_elem_effect", "8") >= chance:
		return
	var turns := int(_spec(8).get("turns", 2))
	for b in ready:
		if boss_side and int(fx.holy_boss) >= holy_cap:
			break
		if src_boss and int(budget.get("applied", 0)) >= boss_cap:
			break
		var gone := _dispel_one(logic, src, b)
		if _add(logic, src, b, ST_HOLY, turns):
			_unit(fx, b).active["holy"] = ST_HOLY
			_stat(fx, 8, "applied")
			if boss_side:
				fx.holy_boss = int(fx.holy_boss) + 1
			if enemy_src:
				budget["applied"] = int(budget.get("applied", 0)) + 1
			if gone != "":
				_say(fx, "%s 净化了%s并获得了%s！" % [b.display_name(), gone, str(SPECS[ST_HOLY][0])])
			else:
				_say(fx, "%s 获得了%s！" % [b.display_name(), str(SPECS[ST_HOLY][0])])
		elif gone != "":
			if boss_side:
				fx.holy_boss = int(fx.holy_boss) + 1
			_say(fx, "%s 净化了%s！" % [b.display_name(), gone])


static func removable_debuff(id: int) -> bool:
	if id == ST_HOLY or id == 1:
		return false
	if STATE_IDS.has(id):
		return true
	var rec := XDB.rec("States", id)
	if rec.is_empty() or XResourceContext.permanent(id):
		return false
	return XBossStatus.kind_of(rec) == "Debuff"


## 驱散 1 个可解除减益（按状态排序取第一个；保留瘟疫异化「净化可能失败」等原判定）；返回驱散掉的状态名，没驱散返回 ""
static func _dispel_one(logic, src, b) -> String:
	for s in b.states():
		var id := int(s.get("id", 0))
		if not removable_debuff(id):
			continue
		if XTianqiPlagueAlien.purge_blocked(logic, src, b, id):
			return ""
		logic._state_remove(b, id)
		if not b.state_ids.has(id):
			return str(s.get("name", ""))
	return ""


## XBattler.add_state 入口（_add_state 之前）：持圣护盾的单位挡下一次对方施加的可解除减益，盾碎
## 目标身上已有这个减益时，对方重施（续回合）照样挡（R2 P2-3①）；带 removeByRestriction 的减益在目标受限时本来就加不上，不耗盾（P2-3③）
static func shield_blocks(b, id: int) -> bool:
	if _logic_ref == null or not b.state_ids.has(ST_HOLY):
		return false
	var lg = _cur()
	if lg == null:
		return false
	if not removable_debuff(id) or b.traits_set(XBattler.TRAIT_STATE_RESIST).has(id):
		return false
	if bool(XDB.rec("States", id).get("removeByRestriction", false)) and b.is_restricted():
		return false
	var fx := _fx(lg)
	if fx.is_empty():
		return false
	# 出手者：先看 _add 显式传入的 src，再看最里层行动帧（反击单独开帧，帧主是反击者，R2 P2-2／P3-4），最后才看 acting_battler；
	# 不在反击里切 acting_battler，免得连带改反击挂上状态的来源（持续伤害归属）
	var add_src = fx.get("_add_src", null)
	var src = add_src if add_src != null else (fx.frames.back().src if not (fx.frames as Array).is_empty() else XImportedBalance.acting_battler())
	if src == null or _same_side(src, b):
		return false  # 没有出手者（脚本、阶段状态、剧情锁）或自己人上的：不挡
	b.remove_state(ST_HOLY)
	_sync_unit(lg, b)  # 盾碎当回合立刻起算圣护冷却（不依赖回合末才同步）
	_say(fx, "%s 的%s抵挡了%s！" % [b.display_name(), str(SPECS[ST_HOLY][0]), str(XDB.rec("States", id).get("name", ""))])
	return true


## XBattler.add_state 之后：旧停手挂上 → 停手计数至少 1、元素停手标记移除（不算吃位）；旧灼伤／旧麻痹挂上 → 顶掉新效果（§3.4、3.6）
static func after_add_state(b, id: int) -> void:
	if _logic_ref == null or STATE_IDS.has(id) or not b.state_ids.has(id):
		return
	var fx := _fx(_cur())
	if fx.is_empty():
		return
	var rec := XDB.rec("States", id)
	if int(rec.get("restriction", 0)) >= 4:
		var un := _unit(fx, b)
		un.stop_need = maxi(int(un.stop_need), 1)
		for sid in STOP_STATES:
			if b.state_ids.has(sid):
				b.remove_state(sid)
	var bt := str(rec.get("meta", {}).get("BuffType", "")).strip_edges()
	for e in data().get("effect_merge", {}):
		if (data().effect_merge[e] as Array).has(bt):
			var sp := _spec(int(e))
			var sid2 := int(KEY_STATE.get(str(sp.get("key", "")), 0))
			if sid2 > 0 and b.state_ids.has(sid2):
				b.remove_state(sid2)


# ---- 行动位（§3.6） ----

## 画面指令窗用：这一位会被元素停手跳过（不改状态）
static func pending_skip(logic, u) -> bool:
	if _fx(logic).is_empty() or u == null:
		return false
	return u.state_ids.has(ST_PARALYZE) or u.state_ids.has(ST_FREEZE)


## act 开头（can_move 判完后）：restricted＝已被旧控跳过（记停手计数）；否则有标记就吃掉这一位
static func take_skip(logic, u, restricted: bool) -> String:
	var fx := _fx(logic)
	if fx.is_empty() or u == null:
		return ""
	if restricted:
		var un0 := _unit(fx, u)
		un0.stop_need = maxi(int(un0.stop_need), 1)
		return ""
	for sid in STOP_STATES:
		if u.state_ids.has(sid):
			logic._state_remove(u, sid)
			if u.state_ids.has(sid):
				u.state_ids.erase(sid)
			var un := _unit(fx, u)
			un.stop_need = int(_rules().get("stun_shared_cooldown", 5))
			un.skips = int(un.skips) + 1
			_sync_unit(logic, u)
			return "%s 因%s跳过了本次行动！" % [u.display_name(), str(SPECS[sid][0])]
	return ""


## 失去的行动位与完成的行动（C 卡量 17% 判线用）
static func skip_count(logic, b) -> int:
	return int(_unit(_fx(logic), b).skips) if not _fx(logic).is_empty() else 0


# ---- 回合末持续伤害（灼烧、寄生） ----

## BattleLogic.turn_end_battler：状态递减之前，每跳 ≤ 受者生命上限 × 5%（施加时已封顶）；跳伤不经 apply，不再触发效果
static func tick_dot(logic, b, logs: Array) -> void:
	var fx := _fx(logic)
	if fx.is_empty() or not fx.units.has(b) or not b.is_alive():
		return
	var un: Dictionary = fx.units[b]
	for key in ["burn", "parasite"]:
		var sid := int(KEY_STATE[key])
		if not un.dot.has(key) or not b.state_ids.has(sid) or not b.is_alive():
			continue
		var d: Dictionary = un.dot[key]
		var n := float(d.get("tick", 0.0))
		if n <= 0.0:
			continue
		var before: float = b.hp
		var v: float = float(b.absorb_shield(n))
		b.hp = maxf(0.0, b.hp - v)
		b.refresh_resources()
		var lost: float = before - b.hp
		logs.append({"type": "regen", "target": b, "hp": lost, "views": logic.views([b])})
		if key == "parasite" and lost > 0.0:
			_parasite_heal(logic, d.get("src"), lost, logs)
		if b.is_dead():
			logic._die(b)
			logs.append({"type": "collapse", "target": b, "views": logic.views([b])})
			return


static func _parasite_heal(logic, src, amount: float, logs: Array) -> void:
	if src == null or not is_instance_valid(src):
		return
	var side: Array = logic.actors if src is XActor else logic.enemies
	var best = null
	var best_rate := INF
	for m in side:
		if m.is_alive() and float(m.mhp) > 0.0:
			var rt := float(m.hp) / float(m.mhp)
			if rt < best_rate:
				best_rate = rt
				best = m
	if best == null:
		return
	var before: float = best.hp
	best.hp = minf(float(best.mhp), best.hp + amount)
	best.refresh_resources()
	if best.hp > before:
		logs.append({"type": "regen", "target": best, "hp": before - best.hp, "views": logic.views([best])})


# ---- 伤害链上的三个效果（XDamage.calculate） ----

## 浸湿：出手方造成的伤害 −11%（首领版同）
static func out_mult(a) -> float:
	if a == null or not a.state_ids.has(ST_SOAK):
		return 1.0
	return 1.0 - spec_value(ST_SOAK)


## 遮蔽锋芒：暴击多出来的那部分 −33%
static func crit_mult(a, mult: float) -> float:
	if a == null or mult <= 1.0 or not a.state_ids.has(ST_VEIL):
		return mult
	return 1.0 + (mult - 1.0) * (1.0 - spec_value(ST_VEIL))


## 感电（首领版麻痹）：受伤 +11%，走弱点暴露那一格（与弱点暴露、破绽取高不叠）
static func has_shock(t) -> bool:
	return t != null and t.state_ids.has(ST_SHOCK)
