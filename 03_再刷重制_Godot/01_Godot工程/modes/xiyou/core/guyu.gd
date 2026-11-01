class_name XGuyu
extends RefCounted
## 175 谷雨（正式 js/codex/runtime/installNativeGuyuRuntime.js，W.Guyu v0.3.1）第一期：战斗外能定下来的部分。
## 原版按备注标签现找角色 <GuyuActor>、技能 <GuyuSkill:键>、法宝 <GuyuRelic>、号角 <GuyuHorn>、进阶石 <GuyuStone>；
## 冻结源里分别是 175、10288～10299、7912、2943、2944，重制写死（同其余专属角色）。
## - 阶位 stage＝进阶次数夹 0～5（XAdvance.rank）。unlocked(a,键)：等级 ≥ skillLevels[键]，「我即万物之春」spring 另要 5 阶。
## - 技能同步 syncSkills（setup／levelUp／changeLevel 包装、进阶 onConfirmOk、startBattle、读档 extractSaveContents）：
##   unlock 表的键（不含绽放 bloom）到了就学、没到就忘；技能有变就重算被动缓存。
## - 技能表 skills 包装：谷雨的「先许一枝开」relic 只在 10 级起（hasSpring）列出，绽放 bloom 永不列出，其余按 unlocked。
## - MP 消耗 skillMpCost 包装：五个主动技（治疗 6%、花期 5%、转移 2%、花荫 3%、终结 8%）收 ceil(最大MP×比例×mcr)，
##   再按通用减耗（installSkillCostRuntime.applyConsumeReduce：floor(×(1−max(减耗, 下限)/100))）。
## - 技能条件 meetsSkillConditions 包装：五个主动技别人不能用；谷雨要已解锁、没归根；花期要不在花期且过了冷却回合；
##   终结要在花期里且自己有储备；花荫要储备的 30% 至少 1；转移要能给出或收回。第一期没有战斗内储备与花期（恒 0／未开），
##   所以终结、花荫、转移一律不能用，花期与治疗照常。
## - 公式 evalDamageFormula 包装：谷雨的「泽苍生」heal ＝ −(目标最大生命×治疗比例)，治疗比例 curve(.25,.30,.35,.40；1/20/40/60 级)
##   ×Π(1＋被动 passiveHEUP%)；治疗被动已算在比例里，结算时不再乘（applyPassiveHealRate 包装）。
##   绽放、终结 ＝ max(0, 威力−(结算里 0，否则 魔防×0.5))，威力是战斗内字段（第二期），第一期 0。
## - 命中：绽放、终结、治疗 itemHit 恒 1（闪避、暴击原表就是 0）。
## - 招募 G.recruit（公共事件 9012 的 try { if (!Guyu.recruit()) 还号角 }）：已在队返回 false；没送过百谷生（$gameSystem._guyuRelicGranted）
##   时背包里有就拿、没有就生成，装进它装备类型（13）的槽；入队；同步技能；一条右上角提示。
## - CodexBinding.curve（installNativeBindingChargeRuntime）：按等级在各档之间线性插值。
## 第二期 A（战斗内，参照 guyu_battle_probe）：
## - 生命周期：BattleManager.setup 包装 reset＋activeBattle；startTurn 包装 G.round＝turnCount＋1，跑完原 startTurn 再设回 turnCount
##   （重制 start_turn 首尾两行）；endTurn 包装（原 endTurn 之后）endRound：花期到期收束；endBattle 包装（原 endBattle 之前）finishBattle：
##   reset、全队生命夹到不含储备的上限，胜利（0）再 rollStone。
## - 生命储备 row(b).e（重制按角色 id 记）：param 包装给战斗中的角色 param(0) 加储备（baseMhp 走计数器不加）；
##   上限 cap：谷雨本人无上限，其余 floor((curve(1,1.25,1.5,1.75)＋0.15×谷雨阶位)×不含储备的最大生命)；addE 超出记浪费；
##   pay 付储备（学了我即万物之春不付）后生命夹到新上限。
## - gainHp 包装（重制 XResourceContext.gain 外层）：回血时谷雨活跃、受益者是出战角色且之前活着：储备 ＋floor(回血量)
##   （传进原 gainHp 的量，不是实际回了多少，满血也全记）；来源是谷雨的直接治疗（Game_Action.apply 包装记的 G.healing：
##   isHpRecover 或带效果 11）先 floor，学了生未央（45 级）且不在花期再 ＋floor(×0.2)。
## - 行动事件：startAction 包装 G.begin（学了众生之劫时记各出战队员此刻的最大生命 heights，治疗公式用它），endAction 包装
##   原 endAction 之后 afterAction：本次行动的技能（不是物品、防御、绽放本身，不是花期、花荫、终结）真的执行过、出手者活着就 G.bloom。
## - Game_Action.apply 包装 doSpecial：花期 open（目标活着、不在花期、过了冷却：花期序号＋1、花期到 round＋1、种子＝目标）；
##   终结 finish（花期中且储备 ≥1：威力＝全部储备×curve(33,50；40/60 级)，付全部、收束花期）；没生效时整次不结算。
##   收束 closeFlower：花期 −1、种子清空、冷却到 round＋2。
## - 绽放 G.bloom：先校种子（死了换第一个活着的敌人，不在花期也照校），谷雨活跃、出手者是活着的出战队员、在花期里：
##   付 floor(储备×25%)（不足 1 不放），威力＝付出×curve(5,6,7,8)，用技能 10299 直接 apply 种子（不反射、不反击、不掩护），
##   伤害按谷雨算（makeDamageValue 期间 subject＝谷雨，重制 _damage_value 换攻击者），不会心。
## - 胜利 rollStone：谷雨在队、还差进阶、背包里谷种金缮石少于差额、Math.randomInt(50)==0 给 1 个。
## 未移植（第二期 B）：代命与归根再生、花荫护盾、转移（含待绽、先许一枝开强化）、谷雨自动战斗固定判断 autoAction、
## 回合受伤压力；技能条件里花荫、转移仍恒不能用（重制还没有效果，免得能用却白付 MP）。战斗界面储备条与转移窗口、立绘与动作（画面）。

const ACTOR := 175
const RELIC := 7912
const STONE := 2944
const SKILL := {"heal": 10288, "open": 10289, "transfer": 10290, "shield": 10291, "finish": 10292, "echo": 10293, "substitute": 10294,
	"root": 10295, "growth": 10296, "spring": 10297, "relic": 10298, "bloom": 10299}
## CFG.unlock 的键（值是阶位门槛，只有 spring 为 5，别的 0；判断用的是 unlocked）
const UNLOCK := ["heal", "open", "echo", "substitute", "root", "transfer", "relic", "shield", "finish", "growth", "spring"]
const SKILL_LEVELS := {"heal": 1, "echo": 1, "transfer": 5, "open": 10, "shield": 15, "substitute": 25, "root": 25, "finish": 35,
	"growth": 45, "spring": 60, "relic": 10}
const MP_RATE := {"heal": 0.06, "open": 0.05, "transfer": 0.02, "shield": 0.03, "finish": 0.08}
const ACTIVE := ["heal", "open", "transfer", "shield", "finish"]
const RECRUIT_TEXT := "谷雨加入队伍，已装备百谷生。"
const RECRUIT_TEXT_PLAIN := "谷雨加入队伍。"
## G._notifiedRelic：本次运行里已提示过送法宝（不存档）
static var _notified_relic := false
const BLOOM := 10299
const CAP_CURVE := [1.0, 1.25, 1.5, 1.75]
const BLOOM_RATIO := 0.25
const GROWTH_RATIO := 0.2
const STONE_ONE_IN := 50
const STONE_TEXT := "获得了 %s！"
## 战斗内状态（G.reset 清）：activeBattle、花期到哪回合、开花冷却到哪回合、当前回合、花期序号、种子（敌群序号，-1＝没有）
static var active_battle := false
static var flower_until := -1
static var open_at := 0
static var round := 0
static var flower_serial := 0
static var seed := -1
## 生命储备 row(b).e：角色 id → 储备
static var reserves := {}
## G.totals 的生成、浪费、付出、绽放次数
static var totals := {}
## 本场战斗（弱引用：静态量拿着战斗对象，没走 end_battle 的测试退出时会崩）
static var _logic_ref: WeakRef = null
## 当前行动事件 {user（弱引用）, executed, heights（角色 id → 开始时的最大生命）}；空＝没有
static var _event := {}
## G.healing：本次 Game_Action.apply 的 {guyu: 出手者是谷雨, direct: isHpRecover 或带效果 11}
static var healing := {}
## action._guyuSpecialDone／_guyuPower（每次 startAction 清）；绽放的威力与 calcOwner
static var _special_done := false
static var _finish_power := 0.0
static var _bloom_power := 0.0
static var calc_owner: XActor = null
## baseMhp：这些角色 id 的 param(0) 暂时不加储备
static var _base := {}


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func key(item: Dictionary) -> String:
	var id := int(item.get("id", 0))
	if not item.has("stypeId"):
		return ""
	for k in SKILL:
		if SKILL[k] == id:
			return k
	return ""


static func stage(a) -> int:
	return clampi(XAdvance.rank(XState.current, ACTOR), 0, 5) if own(a) and XState.current != null else 0


static func unlocked(a, k: String) -> bool:
	return a != null and int(a.level) >= int(SKILL_LEVELS.get(k, 1)) and (k != "spring" or stage(a) >= 5)


## CodexBinding.curve(a, values, levels)：等级 ≤ 第一档取首值，各档之间线性插值，过末档取末值
static func curve(level: int, values: Array, levels := [1, 20, 40, 60]) -> float:
	var lv := maxi(1, level)
	if lv <= int(levels[0]):
		return float(values[0])
	for i in range(1, levels.size()):
		if lv <= int(levels[i]):
			return float(values[i - 1]) + (float(values[i]) - float(values[i - 1])) * (lv - int(levels[i - 1])) / float(int(levels[i]) - int(levels[i - 1]))
	return float(values[values.size() - 1])


## hasSpring：10 级起（成长被动「先许一枝开」，不需要装备法宝）
static func has_spring(a) -> bool:
	return own(a) and int(a.level) >= 10


## syncSkills：unlock 表到了就学、没到就忘（绽放不学）；有变就重算被动缓存
static func sync(a) -> void:
	if not own(a):
		return
	var before: Array = a.skill_ids.duplicate()
	for k in UNLOCK:
		var id: int = SKILL[k]
		if unlocked(a, k):
			if not a.skill_ids.has(id):
				a.learn_skill(id)
		elif a.skill_ids.has(id):
			a.forget_skill(id)
	if before != a.skill_ids:
		a.refresh_passive()


## 读档 extractSaveContents 包装：同步谷雨的技能
static func after_load(s: XState) -> void:
	if s.actors.has(ACTOR):
		sync(s.actor(ACTOR))


## skills 包装：relic 10 级起才列、bloom 不列、其余按解锁
static func skill_ids(a, ids: Array[int]) -> Array[int]:
	if not own(a):
		return ids
	var out: Array[int] = []
	for id in ids:
		var k := key(XDB.rec("Skills", id))
		if k == "relic":
			if has_spring(a):
				out.append(id)
		elif k == "bloom":
			continue
		elif k == "" or not UNLOCK.has(k) or unlocked(a, k):
			out.append(id)
	return out


## skillMpCost 包装：谷雨的五个主动技按最大 MP 比例收费，返回 -1 表示不归这里管
static func mp_cost(a, skill: Dictionary, mcr: float, reduce: float) -> int:
	var k := key(skill)
	if not own(a) or not MP_RATE.has(k):
		return -1
	var g := ceili(float(a.mmp) * float(MP_RATE[k]) * mcr)
	return floori(g * (1.0 - maxf(reduce, XBattleLogic.PERCENT_FLOOR) / 100.0))


## meetsSkillConditions 包装：false 就不能用（其余条件照常由原链判）
static func meets(a, skill: Dictionary) -> bool:
	var k := key(skill)
	if not ACTIVE.has(k):
		return true
	if not own(a):
		return false
	if not unlocked(a, k):
		return false
	match k:
		"open":
			return not (flower_until >= round or round < open_at)
		"finish":
			return blooming() and reserve(a) >= 1.0
		"shield", "transfer":
			return false  # 第二期 B（原版：花荫要储备 30% 至少 1，转移要能给出或收回）
	return true


## evalDamageFormula 包装：有值就用它代替公式（治疗为负）；null＝不归这里管
static func formula(item: Dictionary, a, b, calculating: bool):
	var k := key(item)
	if k == "heal" and own(a):
		return -height(b) * heal_ratio(a)
	if k == "bloom" or (k == "finish" and own(a)):
		return maxf(0.0, (_bloom_power if k == "bloom" else _finish_power) - (0.0 if calculating else float(b.mdf) * 0.5))
	return null


## 治疗公式的 h：本次行动开始时记下的最大生命（含储备；只在学了众生之劫时记），没有就取现在的
static func height(b) -> float:
	var h: Dictionary = _event.get("heights", {})
	return float(h[b.actor_id]) if b is XActor and h.has(b.actor_id) else float(b.mhp)


## healRatio：curve(.25,.30,.35,.40)×Π(1＋passiveHEUP%)
static func heal_ratio(a) -> float:
	var p := curve(int(a.level), [0.25, 0.30, 0.35, 0.40])
	for v in a.passive_values("passiveHEUP"):
		p *= 1.0 + float(v) * 0.01
	return p


## applyPassiveHealRate 包装：谷雨自己的治疗不再乘治疗被动
static func skip_heal_rate(item: Dictionary, a) -> bool:
	return key(item) == "heal" and own(a)


## itemHit 包装：绽放、终结、治疗必中
static func sure(item: Dictionary) -> bool:
	return key(item) in ["bloom", "finish", "heal"]


## G.recruit()：入队了返回提示行，已在队返回空
static func recruit(s: XState) -> String:
	if s.party.has(ACTOR):
		return ""
	var a := s.actor(ACTOR)
	if not bool(s.flags.get("guyu_relic_granted", false)):
		var slot := a.equip_slots().find(int(XDB.rec("Armors", RELIC).get("etypeId", 0)))
		if slot < 0:
			push_error("[xiyou] 百谷生装备槽不可用")
			return ""
		var idx := s.gear.find_custom(func(e): return e.kind == "armor" and int(e.base) == RELIC)  # getMatchingBaseItem
		if idx < 0:
			s.gain_gear("armor", RELIC, 1)
			idx = s.gear.size() - 1
		var item: Dictionary = s.gear[idx]
		s.gear.remove_at(idx)
		var worn = a.equips[slot]
		if worn is Dictionary and not worn.is_empty():
			s.gear.append(worn)
		a.equips[slot] = item
		a.refresh_passive()  # changeEquip 刷新特性与被动
		s.flags["guyu_relic_granted"] = true
	s.add_actor(ACTOR)
	sync(a)
	var text := RECRUIT_TEXT if bool(s.flags.get("guyu_relic_granted", false)) and not _notified_relic else RECRUIT_TEXT_PLAIN
	_notified_relic = true
	return text


# ---------------- 第二期 A：战斗内 ----------------

static func _logic():
	return _logic_ref.get_ref() if _logic_ref != null else null


static func _members() -> Array:
	var logic = _logic()
	return logic.actors if logic != null else []


## guyu()：出战队员里的谷雨
static func _guyu() -> XActor:
	for b in _members():
		if own(b):
			return b
	return null


## active()：战斗中、谷雨出战且活着（归根、代命待死第二期 B）
static func active() -> XActor:
	var g := _guyu()
	return g if active_battle and g != null and g.hp > 0.0 and g.is_alive() else null


static func blooming() -> bool:
	return flower_until >= round and active() != null


## G.reserve
static func reserve(b) -> float:
	return float(reserves.get(b.actor_id, 0.0)) if active_battle and b is XActor else 0.0


## baseMhp：不含储备的生命上限
static func base_mhp(b) -> float:
	var id: int = b.actor_id
	var depth := int(_base.get(id, 0))
	_base[id] = depth + 1
	var v: float = b.mhp
	if depth > 0:
		_base[id] = depth
	else:
		_base.erase(id)
	return v


## cap：谷雨本人无上限；其余 floor((curve(1,1.25,1.5,1.75)＋0.15×谷雨阶位)×baseMhp)
static func cap(b) -> float:
	if own(b):
		return INF
	var g := _guyu()
	if g == null:
		return 0.0
	return floorf((curve(int(g.level), CAP_CURVE) + 0.15 * stage(g)) * base_mhp(b))


## param 包装（异化之外、种族之内）：战斗中角色的最大生命加储备
static func param(a, i: int, v: float) -> float:
	if i != 0 or not active_battle or _base.has(a.actor_id):
		return v
	return v + float(reserves.get(a.actor_id, 0.0))


static func _total(k: String, v: float) -> void:
	totals[k] = float(totals.get(k, 0.0)) + v


## addE：超出上限的记浪费
static func add_e(b, v: float) -> float:
	var n := floorf(v)
	if n <= 0.0:
		return 0.0
	var e := reserve(b)
	var add := minf(n, maxf(0.0, cap(b) - e))
	_total("wasted", n - add)
	if add <= 0.0:
		return 0.0
	reserves[b.actor_id] = e + add
	b.hp = minf(b.hp, b.mhp)
	_total("generated", add)
	return add


## pay：学了我即万物之春不付；付了生命夹到新上限
static func pay(b, q: float) -> float:
	q = floorf(q)
	var g := active()
	var s := 0.0 if g != null and unlocked(g, "spring") else q
	if s > 0.0:
		reserves[b.actor_id] = maxf(0.0, reserve(b) - s)
		b.hp = minf(b.hp, b.mhp)
		_total("spent", s)
	return s


static func close_flower() -> void:
	flower_until = -1
	seed = -1
	open_at = round + 2


static func reset() -> void:
	active_battle = false
	round = 0
	flower_until = -1
	flower_serial = 0
	open_at = 0
	seed = -1
	reserves.clear()
	_event = {}
	healing = {}
	_special_done = false
	_finish_power = 0.0
	_bloom_power = 0.0
	calc_owner = null
	_base.clear()
	_logic_ref = null


## BattleManager.setup 包装（原 setup 之前）
static func setup(logic) -> void:
	reset()
	active_battle = true
	totals = {"generated": 0.0, "wasted": 0.0, "spent": 0.0, "blooms": 0.0}
	_logic_ref = weakref(logic)


## startTurn 包装：首行 round＝turnCount＋1，末行 round＝turnCount
static func start_turn(turn: int) -> void:
	round = turn


## endTurn 包装（原 endTurn 之后）endRound：花期到期收束（护盾到期、归根再生、受伤压力第二期 B）
static func end_round() -> void:
	if active_battle and flower_until >= 0 and flower_until <= round:
		close_flower()


## endBattle 包装（原 endBattle 之前）：finishBattle（归根再生第二期 B）——清状态、全队生命夹到不含储备的上限；胜利掉进阶石
static func end_battle(logic, result: int) -> void:
	var tracked := reserves.keys()
	reset()
	var s: XState = logic.state
	if s == null:
		return
	var all: Array = s.members()
	for id in tracked:
		if s.actors.has(id) and not all.has(s.actors[id]):
			all.append(s.actors[id])
	for b in all:
		b.hp = minf(b.hp, b.mhp)
	if result == 0:
		roll_stone(logic)


## G.rollStone：谷雨在队、还差进阶、背包里不够、Math.randomInt(50)==0
static func roll_stone(logic) -> bool:
	var s: XState = logic.state
	if not s.party.has(ACTOR):
		return false
	var need := 5 - clampi(XAdvance.rank(s, ACTOR), 0, 5)
	if need <= 0 or s.item_count(STONE) >= need or floori(logic._float("guyu_stone") * STONE_ONE_IN) != 0:
		return false
	s.gain_item(STONE, 1)
	XToast.show_text(STONE_TEXT % str(XDB.rec("Items", STONE).get("name", "")), false, "guyu")
	return true


## startAction 包装：清本次行动的特效标记，开行动事件（学了众生之劫才记 heights）
static func begin(u) -> void:
	_special_done = false
	_finish_power = 0.0
	if not active_battle:
		_event = {}
		return
	var heights := {}
	var g := active()
	if g != null and unlocked(g, "substitute"):
		for b in _members():
			heights[b.actor_id] = b.mhp
	_event = {"user": weakref(u), "executed": false, "heights": heights}


## Game_Action.apply 包装（异化之外、种族之内）：G.healing、doSpecial，花期／转移／花荫／终结没生效就整次不结算；行动执行标记
static func apply(logic, u, skill: Dictionary, t) -> Dictionary:
	var k := key(skill)
	var prev := healing
	healing = {"guyu": own(u), "direct": int(skill.get("damage", {}).get("type", 0)) == 3 or skill.get("effects", []).any(func(x): return int(x.code) == 11)}
	_special(logic, u, k, t)
	if own(u) and k in ["open", "transfer", "shield", "finish"] and not _special_done:
		healing = prev
		return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
			"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}
	var mine: bool = not _event.is_empty() and _event.user.get_ref() == u
	if mine:
		_event.executed = true
	var r: Dictionary = logic._apply_core(u, skill, t)
	if k in ["open", "transfer", "shield"] and _special_done and r.has("result"):
		r.result.success = true  # makeSuccess
	healing = prev
	return r


## doSpecial（花期、终结；转移、花荫第二期 B）
static func _special(logic, u, k: String, t) -> void:
	if not own(u) or active() == null or not UNLOCK.has(k) or not unlocked(u, k) or _special_done:
		return
	if k == "open":
		if not t.is_alive() or flower_until >= round or round < open_at:
			return
		_special_done = true
		flower_serial += 1
		flower_until = round + 1
		seed = logic.enemies.find(t)
	elif k == "finish":
		if not blooming() or reserve(u) < 1.0:
			return
		_special_done = true
		var q := reserve(u)
		_finish_power = q * curve(int(u.level), [33, 50], [40, 60])
		pay(u, q)
		close_flower()


## gainHp 包装：直接治疗的回血量先取整
static func heal_value(amount: float) -> float:
	if amount > 0.0 and bool(healing.get("guyu", false)) and bool(healing.get("direct", false)):
		return floorf(amount)
	return amount


## gainHp 包装（原 gainHp 之后）：出战角色之前活着、谷雨活跃时回血记储备；谷雨的直接治疗在生未央下不在花期再加 20%
static func gained(b, amount: float, was_alive: bool) -> void:
	if not active_battle or amount <= 0.0 or not was_alive or not b is XActor or not _members().has(b):
		return
	var g := active()
	if g == null:
		return
	var n := floorf(amount)
	add_e(b, n)
	if bool(healing.get("guyu", false)) and bool(healing.get("direct", false)) and unlocked(g, "growth") and not blooming():
		add_e(b, floorf(n * GROWTH_RATIO))


## validSeed：种子活着就是它，否则换第一个活着的敌人（记下）
static func _valid_seed(logic) -> XBattler:
	if seed >= 0 and seed < logic.enemies.size() and logic.enemies[seed].is_alive():
		return logic.enemies[seed]
	var alive: Array = logic.alive(logic.enemies)
	seed = logic.enemies.find(alive[0]) if not alive.is_empty() else -1
	return alive[0] if not alive.is_empty() else null


## endAction 包装（原 endAction 之后）afterAction：本次行动的技能真的执行过、出手者活着就绽放
static func after_action(logic, u, skill) -> Array:
	var e := _event
	_event = {}
	if e.is_empty() or not bool(e.executed) or e.user.get_ref() != u or not u.is_alive() or not skill is Dictionary or skill.is_empty():
		return []
	if XBattleLogic.is_item(skill) or int(skill.id) == XBattleLogic.GUARD_SKILL or key(skill) in ["open", "shield", "finish", "bloom"]:
		return []
	return bloom(logic, u)


## G.bloom
static func bloom(logic, b) -> Array:
	var g := active()
	var target := _valid_seed(logic)
	if g == null or target == null or b == null or not _members().has(b) or not b.is_alive() or not blooming():
		return []
	var q := floorf(reserve(b) * BLOOM_RATIO)
	if q < 1.0:
		return []
	pay(b, q)
	_total("blooms", 1.0)
	_bloom_power = q * curve(int(g.level), [5, 6, 7, 8])
	calc_owner = g
	var r: Dictionary = logic.apply(b, XDB.rec("Skills", BLOOM), target)
	calc_owner = null
	_bloom_power = 0.0
	return [r]


## makeDamageValue 包装：绽放期间伤害按谷雨算
static func owner(u):
	return calc_owner if calc_owner != null else u
