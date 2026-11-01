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
## - 命中：绽放、终结、治疗 itemHit 恒 1、itemEva 与 itemCri 恒 0（installNativeGuyuRuntime 315，三个包装都在外层；
##   西游的闪避公式是 0、这三个技能原表不暴击，平常本来就是 0，包装让别的来源也加不上）。
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
## 第二期 B（参照 guyu_battle_probe 的 sub／root／shield／transfer／ai 例）：
## - 行动事件栈 G.events：startAction 开一个；不是当前行动的 apply（反击、绽放）与不在行动里的扣血（回合末毒、事件）各开临时的
##   （isolated，不 eligible）。学了众生之劫（25 级）开事件时记下活着的其余出战队员 protected。
## - 代命 protect（addState 死亡的包装，重制 XBattler.add_state 首行）：当前事件有谷雨、受保护、不在内部操作／付费中、没有抗死、
##   不是不死：生命改 1、不加死亡，事件记 pendingDeath（期间谷雨不算活跃）；事件结束 G.end 时谷雨归根（forced）。
## - 归根 root：学了骨生花（25 级）才有；付储备一半（我即万物之春不付）、死亡计数、收束花期；forced 时谷雨生命 0、强加死亡；
##   rootUntil＝round＋1。谷雨自己倒下（addState 死亡之后、不在内部操作）也归根（不 forced）。
##   归根中：isAlive 假、isDead 真、canMove 假，不能回血、setHp 抬不起、去不掉死亡、recoverAll 无效（重制 is_dead、gain、
##   set_resource、remove_state、recover_all 各一行）。
## - 再生 regenerate：endRound 时归根到期且有别的队员活着、finishBattle 时（不是输）有幸存者：去死亡、生命回满；
##   60 级戴着百谷生、本场第一次再生时归春：谷雨与储备比最低的活着队友各得 floor(不含储备的最大生命×18%) 储备。
##   OTB 复活插队交给重制 end_turn 的 _sync_orders（恢复行动的只补进下个回合）。
## - 花荫 shield：储备 30%（不足 1 不能用），付一次，每个活着、没归根的出战队员各得 min(值, 不含储备的最大生命)，
##   进护盾账本（installSourceShieldLedgerRuntime，来源 guyu.shield：不衰减、击穿不减半、不吃护盾加成，同源取较高）两回合；
##   账本在最外层先吸收（executeHpDamage／gainHp／setHp），自然回合末撤销到期的。先许一枝开 20 级起：被花荫挡下一次后
##   下次绽放 ×1.1（60 级 ×1.2，installThreeGrowthRelicRuntime 的 onAbsorb），每次新花荫重置。重制只做谷雨这一个来源的账本。
## - 转移 transfer：给出／收回，比例 50%（10 级起可选 25／50／75%，战斗界面的选择窗写 transfer_mode／transfer_ratio，
##   行动结束 end_action 设回给出 50%：原版写在这次的 Game_Action 上，没写的行动按 give／CFG.transfer.ratio），接收者储备不超上限；
##   10 级起从谷雨给出时受赠者待绽（当前花期里就是本次，否则下一次花期），待绽绽放付 35%（60 级我即万物之春 50%）。
## - 受伤压力：executeHpDamage 包装记本回合我方受到的生命伤害（账本吸收之后），endRound 换成占全队最大生命的比例。
## - 自动战斗 autoAction（makeAutoBattleActions 包装，重制 auto_battle_action 首行，压过挂机与智能 AI）：最低血＜35% 治疗；
##   受伤（＜70% 且无花荫）≥2 人或上回合压力≥20%、且没人有花荫：花荫；花期中储备比≥80% 或花期最后一回合：终结；
##   不在花期且有人储备≥上限一半：花期打生命最多的敌人；否则治疗。储备比的上限对谷雨也按 referenceCap。
## 战斗界面（参照 guyu_ui_probe；画面在 battle_scene／side_status／battler_sprite／guyu_transfer_window）：
## - 状态字 statusText（侧栏名字行）：谷雨在队的战斗中每人「储」＋shortNumber(储备)，归根加「 归根N」（N＝归根到期回合−当前回合，
##   不小于 0），待绽加「 待绽」，谷雨本人另加「 花期N」（剩几回合，含本回合）或「 生长」。shortNumber：亿／万一位小数，以下取整。
## - 护盾合计 totalShield：其他来源的护盾（b.shield）＋花荫账本（重制账本不并进 b.shield，所以相加；原版账本就是 b.shield）。
## - 转移说明 transferText 与 transferPreview 的原因：请选择存活的出战队友／当前装备不支持此转移方式／供给者生命储备不足／接收者储备已满。
## - 动作 G.visuals.motions：治疗 spell、花期 chant、转移 item、花荫 guard、终结 skill（归根中、内部行动不换）。
## 未移植：isValid 包装（重制的角色行动不看 isValid）。

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
## 行动事件栈 G.events：{user（弱引用）, eligible, executed, guyu（开事件时谷雨活跃）, protected、heights（角色 id → 开始时的最大生命）, pending}
static var _events: Array = []
## 刚结束的行动事件（afterAction 用）
static var _last := {}
## 每人的战斗内状态（角色 id → {root_until, bud, bud_flower, spring_boost, spring_hit_used, spring_action, shield, shield_until}）
static var rows := {}
## G.internal／G.unprotected 计数；本回合受伤、上回合压力；归春用过；finishBattle 中
static var internal := 0
static var unprotected := 0
static var round_taken := 0.0
static var last_round_pressure := 0.0
static var spring_return_done := false
static var ending := false
## 转移的模式与比例（原版转移窗口选；重制没有窗口，固定给出 50%）
static var transfer_mode := "give"
static var transfer_ratio := 0.5
## 本次行动的花荫值（_guyuShieldValue）、行动序号（花荫重置先许一枝开的 springShieldAction）
static var _shield_value := 0.0
static var _action_serial := 0
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
	if not unlocked(a, k) or rooted(a):
		return false
	match k:
		"open":
			return not (flower_until >= round or round < open_at)
		"finish":
			return blooming() and reserve(a) >= 1.0
		"shield":
			return shield_value(a) >= 1.0
		"transfer":
			return transfer_ratios(a).any(func(r): return can_transfer(a, "give", r) or can_transfer(a, "back", r))
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
	var h: Dictionary = current().get("heights", {})
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


# ---------------- 第二期：战斗内 ----------------

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


## active()：战斗中、谷雨出战且活着、没归根、没有代命待死
static func active() -> XActor:
	var g := _guyu()
	if not active_battle or g == null or g.hp <= 0.0 or not g.is_alive():
		return null
	for e in _events:
		if bool(e.guyu) and bool(e.pending):
			return null
	return g


static func blooming() -> bool:
	return flower_until >= round and active() != null


## G.reserve
static func reserve(b) -> float:
	return float(reserves.get(b.actor_id, 0.0)) if active_battle and b is XActor else 0.0


static func _row(b) -> Dictionary:
	var id: int = b.actor_id
	if not rows.has(id):
		rows[id] = {"root_until": -1, "bud": false, "bud_flower": 0, "spring_boost": false, "spring_hit_used": false, "spring_action": 0,
			"shield": 0.0, "shield_until": 0}
	return rows[id]


## G.isRooted
static func rooted(b) -> bool:
	return active_battle and b is XActor and rows.has(b.actor_id) and int(rows[b.actor_id].root_until) >= 0


## G.hasBud：待绽且是本次或之后的花期
static func has_bud(b) -> bool:
	if not active_battle or not b is XActor or not rows.has(b.actor_id):
		return false
	var r: Dictionary = rows[b.actor_id]
	return bool(r.bud) and int(r.bud_flower) >= flower_serial


## G.shield：账本里 guyu.shield 的量
static func shield_of(b) -> float:
	return float(rows[b.actor_id].shield) if active_battle and b is XActor and rows.has(b.actor_id) else 0.0


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


## referenceCap：floor((curve(1,1.25,1.5,1.75)＋0.15×谷雨阶位)×baseMhp)（自动战斗对谷雨本人也用它）
static func reference_cap(b) -> float:
	var g := _guyu()
	if g == null:
		return 0.0
	return floorf((curve(int(g.level), CAP_CURVE) + 0.15 * stage(g)) * base_mhp(b))


## cap：谷雨本人无上限
static func cap(b) -> float:
	return INF if own(b) else reference_cap(b)


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
	for id in rows:
		rows[id].bud = false
		rows[id].bud_flower = 0


static func reset() -> void:
	active_battle = false
	round = 0
	flower_until = -1
	flower_serial = 0
	open_at = 0
	seed = -1
	reserves.clear()
	rows.clear()
	_events.clear()
	_last = {}
	healing = {}
	internal = 0
	unprotected = 0
	round_taken = 0.0
	last_round_pressure = 0.0
	spring_return_done = false
	_special_done = false
	_finish_power = 0.0
	_bloom_power = 0.0
	_shield_value = 0.0
	calc_owner = null
	_base.clear()
	test_relic = false
	transfer_mode = "give"
	transfer_ratio = 0.5
	visuals = []
	_logic_ref = null


## BattleManager.setup 包装（原 setup 之前）；护盾账本 startBattle 时清空（同在 reset 里）
static func setup(logic) -> void:
	reset()
	active_battle = true
	totals = {"generated": 0.0, "wasted": 0.0, "spent": 0.0, "blooms": 0.0, "deaths": 0.0, "regenerations": 0.0, "shielded": 0.0, "transferred": 0.0}
	_logic_ref = weakref(logic)


## startTurn 包装：首行 round＝turnCount＋1，末行 round＝turnCount
static func start_turn(turn: int) -> void:
	round = turn


## endTurn 包装（原 endTurn 之后）endRound：受伤压力、花期到期收束、归根到期且有队友活着就再生；护盾账本的回合末撤销到期来源
static func end_round() -> void:
	if not active_battle:
		return
	var members := _members()
	var pool := 0.0
	for b in members:
		pool += maxf(1.0, b.mhp)
	last_round_pressure = round_taken / maxf(1.0, pool)
	round_taken = 0.0
	var others_alive := members.any(func(b): return not own(b) and b.is_alive() and b.hp > 0.0)
	var r := maxi(1, round)
	for id in rows:
		if float(rows[id].shield) > 0.0 and int(rows[id].shield_until) <= r:
			rows[id].shield = 0.0
	if flower_until >= 0 and flower_until <= round:
		close_flower()
	var g := _guyu()
	if g != null and rooted(g) and int(_row(g).root_until) <= round and others_alive:
		regenerate(g)


## endBattle 包装（原 endBattle 之前）finishBattle：不是输且有幸存者时先再生归根的谷雨；清状态、全队生命夹到不含储备的上限；胜利掉进阶石
static func end_battle(logic, result: int) -> void:
	var g := _guyu()
	var survivor := _members().any(func(b): return b != g and b.is_alive() and b.hp > 0.0)
	ending = true
	if result != 2 and g != null and rooted(g) and survivor:
		regenerate(g)
	ending = false
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


# ---- 行动事件、代命、归根 ----

static func current() -> Dictionary:
	return _events.back() if not _events.is_empty() else {}


## G.begin：学了众生之劫时记活着的其余队员（protected）与各人此刻的最大生命（heights）
static func _new_event(u, eligible: bool) -> Dictionary:
	var g := active()
	var e := {"user": weakref(u) if u != null else null, "eligible": eligible, "executed": false, "guyu": g != null, "protected": {},
		"heights": {}, "pending": false}
	if g != null and unlocked(g, "substitute"):
		for b in _members():
			if b != g and b.hp > 0.0 and b.is_alive():
				e.protected[b.actor_id] = true
			e.heights[b.actor_id] = b.mhp
	return e


## startAction 包装：清本次行动的特效标记，开行动事件（前一次没收尾的丢掉）
static func begin(u) -> void:
	_special_done = false
	_finish_power = 0.0
	_shield_value = 0.0
	_action_serial += 1
	_events.clear()
	if active_battle:
		_events.append(_new_event(u, true))


## G.end：代命成立就归根
static func _end(e: Dictionary) -> void:
	var i := _events.rfind(e)
	if i < 0:
		return
	_events.remove_at(i)
	if bool(e.pending) and bool(e.guyu):
		var g := _guyu()
		if g != null:
			root(g, true)


## endAction 包装（原 endAction 之前）：结束行动事件；afterAction 在原 endAction 之后
static func end_action() -> void:
	transfer_mode = "give"
	transfer_ratio = 0.5
	_last = current()
	if not _last.is_empty():
		_end(_last)


## isolated：不在行动里的扣血包一个临时事件（代命同样生效）
static func isolated_begin() -> Dictionary:
	if not active_battle or not _events.is_empty() or internal > 0 or unprotected > 0:
		return {}
	var e := _new_event(null, false)
	_events.append(e)
	return e


static func isolated_end(e: Dictionary) -> void:
	if not e.is_empty():
		_end(e)


## protect（addState 死亡的包装，最先）：代命——生命改 1、不加死亡
static func protect(b) -> bool:
	if not b is XActor or not active_battle:
		return false
	var e := current()
	if e.is_empty() or not bool(e.guyu) or not e.protected.has(b.actor_id) or internal > 0 or unprotected > 0:
		return false
	if b.traits_set(XBattler.TRAIT_STATE_RESIST).has(1) or b.immortal:  # 原有死亡免疫与 YEP 不死优先
		return false
	e.pending = true
	b.hp = 1.0
	return true


## addState 包装（原 addState 之后）：谷雨自己倒下就归根
static func after_add_state(b, id: int) -> void:
	if id == 1 and active_battle and own(b) and internal == 0 and b.state_ids.has(1):
		root(b, false)


## root：付储备一半、收束花期、到下回合归根；forced 时强加死亡
static func root(g, forced: bool) -> void:
	var r := _row(g)
	if not unlocked(g, "root") or int(r.root_until) >= 0:
		return
	var q := floorf(reserve(g) * 0.5)
	var s := 0.0 if unlocked(g, "spring") else q
	if s > 0.0:
		reserves[g.actor_id] = reserve(g) - s
		_total("spent", s)
	_total("deaths", 1.0)
	close_flower()
	if forced:
		internal += 1
		g.hp = 0.0
		g.immortal = false
		g.add_state(1)
		g.hp = 0.0
		if not g.state_ids.has(1):  # 死亡免疫不能取消已经成立的代命
			g.state_ids.append(1)
		r.root_until = round + 1
		internal -= 1
	r.root_until = round + 1
	visuals.append({"type": "guyu_visual", "target": g, "kind": "root"})  # queueVisual(g, 'root')


## queueVisual：归根的画面反馈（金边瓷片与枯叶，只属于精灵，不进存档）；行动末与回合末由 XBattleLogic 取走放进记录
static var visuals: Array = []


static func take_visuals() -> Array:
	var out := visuals
	visuals = []
	return out


## hasRelic：10 级起戴着百谷生（或测试开关 G.setTestRelic，reset 清）
static var test_relic := false
static func has_relic(b) -> bool:
	return own(b) and int(b.level) >= 10 and (test_relic or b.equips.any(func(e): return e is Dictionary and not e.is_empty() and str(e.get("kind", "")) == "armor" and int(e.get("base", e.get("id", 0))) == RELIC))


## regenerate：去死亡、生命回满；60 级戴着百谷生、本场第一次时归春
static func regenerate(g) -> void:
	var r := _row(g)
	internal += 1
	r.root_until = -1
	g.remove_state(1)
	g.hp = g.mhp
	internal -= 1
	_total("regenerations", 1.0)
	if has_relic(g) and int(g.level) >= 60 and not spring_return_done:
		spring_return_done = true
		var q := floorf(base_mhp(g) * 0.18)
		add_e(g, q)
		var best = null
		for b in _members():
			if b != g and b.is_alive() and not rooted(b) and (best == null or reserve(b) / maxf(1.0, cap(b)) < reserve(best) / maxf(1.0, cap(best))):
				best = b
		if best != null:
			add_e(best, q)


# ---- Game_Action.apply 包装、花期、转移、花荫、终结 ----

## Game_Action.apply 包装（异化之外、种族之内）：G.healing、doSpecial，花期／转移／花荫／终结没生效就整次不结算；行动执行标记
static func apply(logic, u, skill: Dictionary, t) -> Dictionary:
	var k := key(skill)
	var prev := healing
	healing = {"guyu": own(u), "direct": int(skill.get("damage", {}).get("type", 0)) == 3 or skill.get("effects", []).any(func(x): return int(x.code) == 11)}
	var e := current()
	var mine: bool = not e.is_empty() and e.user != null and e.user.get_ref() == u
	var temp := {}
	if active_battle and not mine:  # isolated(a, run)：不是当前行动的 apply（反击、绽放等）另开一个事件
		temp = _new_event(null, false)
		_events.append(temp)
	_special(logic, u, k, t)
	if own(u) and k in ["open", "transfer", "shield", "finish"] and not _special_done:
		healing = prev
		isolated_end(temp)
		return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
			"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}
	if not current().is_empty():
		current().executed = true
	var r: Dictionary = logic._apply_core(u, skill, t)
	if k in ["open", "transfer", "shield"] and _special_done and r.has("result"):
		r.result.success = true  # makeSuccess
	healing = prev
	isolated_end(temp)
	return r


## doSpecial
static func _special(logic, u, k: String, t) -> void:
	if not own(u) or active() == null or not UNLOCK.has(k) or not unlocked(u, k):
		return
	if k == "open" and not _special_done:
		if not t.is_alive() or flower_until >= round or round < open_at:
			return
		_special_done = true
		flower_serial += 1
		flower_until = round + 1
		seed = logic.enemies.find(t)
	elif k == "transfer" and not _special_done:
		var p := transfer_preview(u, t, transfer_mode, transfer_ratio)
		if not bool(p.valid):
			return
		_special_done = true
		reserves[p.from.actor_id] = reserve(p.from) - float(p.amount)
		reserves[p.to.actor_id] = reserve(p.to) + float(p.amount)
		for x in [p.from, p.to]:
			x.hp = minf(x.hp, x.mhp)
		_total("transferred", float(p.amount))
		if has_spring(u) and p.from == u:
			var bud := _row(p.to)
			bud.bud = true
			bud.bud_flower = flower_serial + (0 if blooming() else 1)
	elif k == "shield":
		if not _members().has(t) or not t.is_alive() or rooted(t):
			return
		if not _special_done:
			_shield_value = shield_value(u)
			if _shield_value < 1.0:
				return
			_special_done = true
			pay(u, _shield_value)
		var v := minf(_shield_value, floorf(base_mhp(t)))
		_grant_shield(t, v)
		var r := _row(t)
		if int(r.spring_action) != _action_serial:
			r.spring_action = _action_serial
			r.spring_boost = false
			r.spring_hit_used = false
		_total("shielded", v)
	elif k == "finish" and not _special_done:
		if not blooming() or reserve(u) < 1.0:
			return
		_special_done = true
		var q := reserve(u)
		_finish_power = q * curve(int(u.level), [33, 50], [40, 60])
		pay(u, q)
		close_flower()


static func shield_value(g) -> float:
	return floorf(reserve(g) * 0.3)


## CodexShieldLedger.grant(target, 'guyu.shield', v, 2, …, {noDecay, noHalve, noBonus})：同源取较高、期限到 round()＋1
static func _grant_shield(t, v: float) -> void:
	var value := floorf(maxf(0.0, v))
	if value <= 0.0:
		return
	var r := _row(t)
	var until := maxi(1, round) + 1
	if float(r.shield) > 0.0:
		r.shield = maxf(float(r.shield), value)
		r.shield_until = maxi(int(r.shield_until), until)
	else:
		r.shield = value
		r.shield_until = until


## 账本吸收（executeHpDamage／gainHp／setHp 的最外层）：返回剩下的伤害；谷雨付费中（unprotected）不吸收。
## 挡下过就 springShieldHit（先许一枝开 20 级起：下次绽放强化，一次花荫一次）
static func ledger_absorb(b, damage: float) -> float:
	if not active_battle or damage <= 0.0 or not b is XActor or not rows.has(b.actor_id) or unprotected > 0:
		return damage
	var r: Dictionary = rows[b.actor_id]
	if float(r.shield) <= 0.0:
		return damage
	var take := minf(float(r.shield), damage)
	r.shield = float(r.shield) - take
	if take > 0.0:
		var g := active()
		if g != null and has_spring(g) and int(g.level) >= 20 and not bool(r.spring_hit_used):
			r.spring_hit_used = true
			r.spring_boost = true
	return damage - take


## executeHpDamage：账本先吸收，再记本回合我方受到的伤害（受伤压力）
static func hp_damage(t, value: float) -> float:
	value = ledger_absorb(t, value)
	if active_battle and value > 0.0 and t is XActor:
		round_taken += value
	return value


static func transfer_ratios(b) -> Array:
	return [0.25, 0.5, 0.75] if has_spring(b) else [0.5]


## G.transferPreview（reason：不合法的原因，转移选目标时的说明卡写它）
static func transfer_preview(b, t, mode := "give", ratio := 0.5) -> Dictionary:
	var out := {"valid": false, "amount": 0.0, "reason": "请选择存活的出战队友"}
	if not active_battle or b == null or b != active() or not unlocked(b, "transfer") or t == null or t == b or not _members().has(t) \
			or not t is XActor or not t.is_alive() or rooted(t):
		return out
	if not mode in ["give", "back"] or not transfer_ratios(b).has(ratio):
		out.reason = "当前装备不支持此转移方式"
		return out
	out.from = t if mode == "back" else b
	out.to = b if out.from == t else t
	var want := floorf(reserve(out.from) * ratio)
	var room := maxf(0.0, cap(out.to) - reserve(out.to))
	out.amount = minf(want, room)
	out.capped = want > room
	out.valid = float(out.amount) >= 1.0
	out.ratio = ratio
	out.mode = mode
	out.reason = "" if out.valid else ("供给者生命储备不足" if want < 1.0 else "接收者储备已满")
	return out


## G.transferText：转移选目标时说明卡的文字（不合法时是原因）
static func transfer_text(b, t, mode := "give", ratio := 0.5) -> String:
	var p := transfer_preview(b, t, mode, ratio)
	if not bool(p.valid):
		return str(p.reason)
	return ("还春" if p.mode == "back" else "赠春") + " " + str(roundi(float(p.ratio) * 100.0)) + "%：" + p.from.display_name() + " → " + p.to.display_name() \
		+ "，储备 " + short_number(float(p.amount)) + ("（受接收上限限制）" if bool(p.capped) else "") + "。\n转移不回复HP" \
		+ ("；赋予一次待绽。" if has_spring(b) and p.mode == "give" else "。")


## shortNumber：亿／万一位小数（toFixed(1)），以下取整
static func short_number(n: float) -> String:
	if n >= 100000000.0:
		return "%.1f亿" % (n / 100000000.0)
	if n >= 10000.0:
		return "%.1f万" % (n / 10000.0)
	return str(int(floorf(n)))


## G.statusText：侧栏名字行右侧的状态字（战斗中、谷雨在队才有）
static func status_text(b) -> String:
	if not active_battle or _guyu() == null or not b is XActor:
		return ""
	var text := "储" + short_number(reserve(b))
	if rooted(b):
		text += " 归根" + str(maxi(0, int(rows[b.actor_id].root_until) - round))
	elif has_bud(b):
		text += " 待绽"
	elif own(b):
		text += " 花期" + str(flower_until - round + 1) if blooming() else " 生长"
	return text


## G.totalShield：生命条上画的护盾合计（其他来源 b.shield ＋ 花荫账本）
static func total_shield(b) -> float:
	return float(b.shield) + shield_of(b) if b is XActor else 0.0


## G.visuals.motions：五个主动技的动作（performAction 包装）
const MOTIONS := {"heal": "spell", "open": "chant", "transfer": "item", "shield": "guard", "finish": "skill"}


## performAction 包装：谷雨用主动技时换的动作；不换时空（内部行动 _guyuInternal 即绽放，归根中不换）
static func action_motion(a, skill: Dictionary) -> String:
	if not own(a) or rooted(a) or key(skill) == "bloom":
		return ""
	return str(MOTIONS.get(key(skill), ""))


static func can_transfer(b, mode: String, ratio: float) -> bool:
	return _members().any(func(t): return bool(transfer_preview(b, t, mode, ratio).valid))


## Window_GuyuTransfer.makeCommandList：每种比例「赠春（n%）」「还春（n%）」各一行，没有能转的目标时灰掉
static func transfer_commands(a) -> Array:
	var out := []
	for r in transfer_ratios(a):
		var pct := roundi(float(r) * 100.0)
		out.append({"text": "赠春（%d%%）" % pct, "enabled": can_transfer(a, "give", r), "mode": "give", "ratio": r})
		out.append({"text": "还春（%d%%）" % pct, "enabled": can_transfer(a, "back", r), "mode": "back", "ratio": r})
	return out


## 选择窗打开时的光标：默认比例（CFG.transfer.ratio 50%）的「赠春」；它灰着就第一个能选的，都灰着停在第一行
static func transfer_default_index(entries: Array) -> int:
	var i := entries.find_custom(func(e): return e.mode == "give" and is_equal_approx(float(e.ratio), 0.5))
	if i < 0 or not bool(entries[i].enabled):
		i = entries.find_custom(func(e): return bool(e.enabled))
	return maxi(0, i)


# ---- gainHp 包装 ----

## gainHp 包装：直接治疗的回血量先取整
static func heal_value(amount: float) -> float:
	if amount > 0.0 and bool(healing.get("guyu", false)) and bool(healing.get("direct", false)):
		return floorf(amount)
	return amount


## gainHp 包装（原 gainHp 之后）：出战角色之前活着、谷雨活跃时回血记储备；谷雨的直接治疗在生未央下不在花期再加 20%
static func gained(b, amount: float, was_alive: bool) -> void:
	if not active_battle or amount <= 0.0 or not was_alive or not b is XActor or not _members().has(b) or internal > 0:
		return
	var g := active()
	if g == null:
		return
	var n := floorf(amount)
	add_e(b, n)
	if bool(healing.get("guyu", false)) and bool(healing.get("direct", false)) and unlocked(g, "growth") and not blooming():
		add_e(b, floorf(n * GROWTH_RATIO))


# ---- 绽放 ----

## validSeed：种子活着就是它，否则换第一个活着的敌人（记下）
static func _valid_seed(logic) -> XBattler:
	if seed >= 0 and seed < logic.enemies.size() and logic.enemies[seed].is_alive():
		return logic.enemies[seed]
	var alive: Array = logic.alive(logic.enemies)
	seed = logic.enemies.find(alive[0]) if not alive.is_empty() else -1
	return alive[0] if not alive.is_empty() else null


## endAction 包装（原 endAction 之后）afterAction：本次行动的技能真的执行过、出手者活着就绽放
static func after_action(logic, u, skill) -> Array:
	var e := _last
	_last = {}
	if e.is_empty() or not bool(e.eligible) or not bool(e.executed) or e.user == null or e.user.get_ref() != u or not u.is_alive() \
			or not skill is Dictionary or skill.is_empty():
		return []
	if XBattleLogic.is_item(skill) or int(skill.id) == XBattleLogic.GUARD_SKILL or key(skill) in ["open", "shield", "finish", "bloom"]:
		return []
	return bloom(logic, u)


## G.bloom：待绽付 35%（60 级我即万物之春 50%），否则 25%；先许一枝开 20 级起挡过一次花荫 ×1.1（60 级 ×1.2）
static func bloom(logic, b) -> Array:
	var g := active()
	var target := _valid_seed(logic)
	if g == null or target == null or b == null or not _members().has(b) or not b.is_alive() or not blooming():
		return []
	var r := _row(b)
	var bud := has_bud(b) and int(r.bud_flower) == flower_serial
	var q := floorf(reserve(b) * ((0.5 if has_spring(g) and int(g.level) >= 60 else 0.35) if bud else BLOOM_RATIO))
	if q < 1.0:
		return []
	pay(b, q)
	r.bud = false
	r.bud_flower = 0
	_total("blooms", 1.0)
	var boost := (1.2 if int(g.level) >= 60 else 1.1) if has_spring(g) and int(g.level) >= 20 and bool(r.spring_boost) else 1.0
	r.spring_boost = false
	_bloom_power = q * curve(int(g.level), [5, 6, 7, 8]) * boost
	calc_owner = g
	var out: Dictionary = logic.apply(b, XDB.rec("Skills", BLOOM), target)
	calc_owner = null
	_bloom_power = 0.0
	return [out]


## makeDamageValue 包装：绽放期间伤害按谷雨算
static func owner(u):
	return calc_owner if calc_owner != null else u


# ---- 自动战斗 ----

## G.autoAction（makeAutoBattleActions 包装）：返回 [技能, 目标]，没有就空
static func auto_action(logic, a) -> Array:
	if not own(a) or not active_battle or not logic.can_move(a):
		return []
	var team := _members().filter(func(b): return b.is_alive())
	var foes: Array = logic.alive(logic.enemies)
	if foes.is_empty():
		return []
	var can := func(k: String) -> bool: return logic.can_use(a, XDB.rec("Skills", SKILL[k]))
	var lowest = null
	for b in team:
		if lowest == null or b.hp / b.mhp < lowest.hp / lowest.mhp:
			lowest = b
	var hurt := team.filter(func(b): return b.hp / b.mhp < 0.7 and shield_of(b) <= 0.0).size()
	var ratio := reserve(a) / maxf(1.0, reference_cap(a))
	if lowest != null and lowest.hp / lowest.mhp < 0.35 and can.call("heal"):
		return [XDB.rec("Skills", SKILL.heal), null]
	if (hurt >= 2 or last_round_pressure >= 0.2) and can.call("shield") and not team.any(func(b): return shield_of(b) > 0.0):
		return [XDB.rec("Skills", SKILL.shield), null]
	if blooming() and can.call("finish") and (ratio >= 0.8 or flower_until == round):
		return [XDB.rec("Skills", SKILL.finish), null]
	if not blooming() and can.call("open") and team.any(func(b): return reserve(b) >= reference_cap(b) * 0.5):
		var boss = null
		for t in foes:
			if boss == null or t.hp > boss.hp:
				boss = t
		return [XDB.rec("Skills", SKILL.open), boss]
	if can.call("heal"):
		return [XDB.rec("Skills", SKILL.heal), null]
	return []
