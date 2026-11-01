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
## 未移植（第二期起，全是战斗内）：生命储备（治疗溢出转储备、储备并进最大生命、上限）、花期与绽放、代命与归根再生、花荫护盾、
## 转移、终结、谷雨自动战斗固定判断 autoAction、胜利掉进阶石 rollStone、战斗界面储备条与转移窗口、立绘与动作。

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
## 战斗内字段（第二期）：花期到哪回合、开花冷却到哪回合、当前回合
static var flower_until := -1
static var open_at := 0
static var round := 0


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
		"finish", "shield", "transfer":
			return false  # 要战斗内储备／花期（第二期）；第一期恒没有
	return true


## evalDamageFormula 包装：有值就用它代替公式（治疗为负）；null＝不归这里管
static func formula(item: Dictionary, a, b, calculating: bool):
	var k := key(item)
	if k == "heal" and own(a):
		return -float(b.mhp) * heal_ratio(a)
	if k == "bloom" or (k == "finish" and own(a)):
		return maxf(0.0, 0.0 - (0.0 if calculating else float(b.mdf) * 0.5))  # 威力（_guyuPower）第二期
	return null


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
