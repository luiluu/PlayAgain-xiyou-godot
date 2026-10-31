class_name XYomiJingliu
extends RefCounted
## 169 黄泉、170 镜流（正式 js/codex/runtime/installNativeYomiJingliuRuntime.js，W.CodexYomi／W.CodexJingliu，两人共用一个模块）。
## 第一期做共用框架与黄泉：招募、能力值／被动、公式、伤害钩子。镜流见文末「镜流第一期」。
## - 开机数据：本模块不在运行时改 $data*（只在 isDatabaseLoaded 里核对 169／170 数据在不在、预载图标），转换器无需复现。
## - 黄泉能力值：paramPlus 学了 10176 幸运＋888、10177 速度＋777、10182 攻击＋888（XActor._param_plus 挂点）；
##   param 进阶 2 次且学了 10186 攻击＋floor(幸运×1.88)；xparam 学了 10185 暴击＋9.99（见 CRIT_FIX）；actionPlusSet 学了 10175 多一个 1（必定再动一次）。
## - 公式 CodexYomi.damage(a,b,id)：Y_ROWS 按目标身上「负面状态」数 n 线性加：攻击×(r0＋r1n)＋速度×(r2＋r3n)＋幸运×(r4＋r5n)。
##   负面状态：2627 集真赤，或备注 <BuffType:破甲|损伤|毒|…> 的状态（不重复计）。
## - 伤害钩子 yomi-jingliu（CodexDamageHooks.push，黄泉 10171～10174；并进 XActorDamageHooks）：物理；物理受伤率与属性抗性穿透 penetration
##   （10178／10181／10184（进阶 1）／10186（进阶 2）各 0.22）；10179 普通伤害＋0.88；10180 雷属性＋0.77；10183 暴伤＋6.66；
##   10185 技能倍率 ×16.55（10174 为 ×1.33）；戴赤雨双缨 4578 且目标有集真赤（10174 除外）×1.77。
##   原版另包了 makeDamageValue／applyCritical／sparam(6)／calcElementRate 做同样的加成，但 installDamageElementRuntime（main.js 第 127 行，
##   装在本模块第 101 行之后）整个换掉 makeDamageValue 且不回调旧链，那几层包装实际不生效，伤害只走这条钩子，重制也只移植钩子。
## - 招募（公共事件 9004 的 CodexYomi.recruit()）：已在队返回 false；没戴专属法宝时背包有就拿、没有就生成，装进它装备类型的槽；入队；
##   右上角提示两条（$.toaster）。
## 第二期（战斗包装，参照 mv_oracle/yomi_battle_probe → tests/xiyou_yomi_battle）：
## - 必中 sure()：10171～10174 itemHit 1、itemEva 0（只这两项；反击、反射照常）。XBattleLogic.item_hit／item_eva 调。
## - 连击 begin_action()：numRepeats＝repeats(a)，取代原次数（含行动序列的重复目标）；XBattleLogic.execute 每次行动调一次，同时清本行动的「已施印」。
## - 残梦 dream()：meets()（meetsSkillConditions）10174 要≥9；pay()（paySkillCost，异化缄默付得起之后）10174 扣 9；战斗结束清零（end_battle）。
## - apply 包装（XBattleLogic._invoke，掩护之后、目标是活着的敌人）：before_apply 本行动第一次（10174 除外）给目标施集真赤 2627 与
##   Y_RANDOM_DEBUFFS 随机一个（Math.randomInt(6)，rule 流 "yomi_debuff"；10173 学了 10185 再施一次）；after_apply 命中且目标有负面状态
##   残梦＋1（10174 不加），10172／10173／10174 再对其余活着的敌人各结算一次，伤害钩子 skillMultiplier × SPREAD（spread_rate）。
## 未移植：隐藏呼吸技能分类、图标与品质色、旧档迁移。
## 镜流第一期（170，参照 mv_oracle/jingliu_probe → tests/xiyou_jingliu）：
## - 招募（公共事件 9005 的 CodexJingliu.recruit()）：同黄泉，装上月魄剑匣 4579。
## - 技能整理（setup 时 normalizeJingliuSkills）：10187～10196 按解锁等级学／忘，忘掉 10197～10199，进阶 ≥1 学 10200～10202、否则忘。
## - 星魂（学了命途：毁灭 10194 且到级）：paramBase 20 级、40 级各再加一份最大生命基础值，35 级再加一份攻击基础值（XActorModules.param_base）。
## - 公式 CodexJingliu.damage(a,b,id)：(攻击×r0＋最大生命×r1)×剑势均衡(0.85＋0.15×小/大，生命按 17463/136584 折算)×月魄(1＋0.06×(月魄−2.5)，
##   用付费之前的月魄)×印记(1＋霜痕 2628 0.1＋裂隙 2629 0.1)×守势（伤害计算中恒为 1，CodexDamage.isCalculating；计算外见 j_formula）。
## - 伤害钩子镜流部分：剑技物理；戴月魄剑匣时（技能类型 4 除外）普通伤害 +0.25；寒冰（元素 3）伤害：星魂 25 级寒冰 +1，
##   剑技里 10187／10189／10191 星魂 30 级 ×2、强化剑技 10188／10190／10192 星魂 45 级 ×2、10192 学了 10202 ×1.1。
##   原版 makeDamageValue 包装同黄泉，被 installDamageElementRuntime 换掉不生效，不移植。
## - 战斗：剑技必中不闪避；段数固定 {10187:1,10188:3,10189:2,10190:5,10191:2,10192:7,10193:1}；月魄（0～3，只在战斗内）开回合满 3、
##   强化剑技要 ≥1 才能用、付费时扣 1（先记付费前的值给公式），10187／10189／10191 命中或 10193 打到敌人后 +1
##   （25 级学了朔望盈满 10195 时前三个 +2），结束战斗清零；10187 命中给主目标霜痕、10189 命中给裂隙。
## 镜流第二期（参照 mv_oracle/jingliu2_probe → tests/xiyou_jingliu2）：
## - 施放准备（apply 包装、原 apply 之前，j_before）：强化剑技第一次打到活着的敌人时放血——其余活着的出战队友各扣 min(floor(最大生命×3%／5%／8%), 生命−1)
##   （gainHp），累计 _blood（开战清零），本次伤害 ×(1＋min(累计/(5×最大生命), 上限−1))，上限 1.25／1.5／1.8（10192 学了 10202 为 2.5）；记下主目标当时有没有霜痕／裂隙；
##   10192 时用掉昙华绽放（之前放过 10193），伤害钩子 ×1.0666。
## - 追加段（j_finish）：10188 主目标有霜痕再追一段并去霜痕；10190 主目标有裂隙时其余活着的敌人各追一段、主目标去裂隙；10192 全部活着的敌人各追一段、
##   主目标去裂隙。追加段直接 apply（不再走 apply 包装），公式用进阶行（学了 10200～10202 加成）。
## - 裂隙演化：10189 命中时目标记下「学没学 10201」；演化过且有裂隙时 Game_Enemy.param(3) floor(×0.89)、elementRate(3) +0.0111。
## - 追加行动：月魄从 <2 涨到 ≥2（每回合一次）、10192 真放了血且学了 10202（每回合一次），行动结束后插到本回合行动队首（本回合行动不到 5 次）。
## - 读档（XState.from_dict 末尾）：重新整理技能、放血累计清零。
## 镜流未移植：星魂说明行（界面）、技能图标、追加段的战斗日志显示（记录带 supplemental）。

## 优化登记（O 号待总装分配；原版缺陷）：10185 说明写「暴击率＋999%」，原版包的是 Game_BattlerBase.prototype.xparam，但 dsPassiveSkill
## 在插件加载时已把 Game_Actor.prototype.xparam 存成别名（_Game_Actor_xparam），角色的 xparam 走不到这层包装，加成实际不生效
## （slice_probe 65／99 级参照暴击仍是 0.55）。重制默认照说明生效；false 恢复原版（不加）。
static var CRIT_FIX := true
const YOMI := 169
const JINGLIU := 170
const Y_MARK := 2627
const Y_ARMOR := 4578
const J_ARMOR := 4579
const Y_ROWS := {10171: [50000, 5000, 5000, 500, 7000, 700], 10172: [70000, 7000, 7000, 700, 9000, 900],
	10173: [80000, 8000, 8000, 800, 10000, 1000], 10174: [230000, 23000, 23000, 2300, 35000, 3500]}
const J_FROST := 2628
const J_GAP := 2629
const J_ROWS := {10187: [99995, 1833.3], 10188: [166665, 3330], 10189: [183330, 3330], 10190: [333330, 5555],
	10191: [611110, 11110], 10192: [3333330, 33330], 10193: [833330, 11110]}
const J_REPEATS := {10187: 1, 10188: 3, 10189: 2, 10190: 5, 10191: 2, 10192: 7, 10193: 1}
const J_ENHANCED := [10188, 10190, 10192]
## 进阶行：基础 [攻击系数, 生命系数]，学了对应剑意再加
const J_ADVANCED := {10188: [[55555, 1111.1], 10200, [55555, 0]], 10190: [[99995, 1111.1], 10201, [83335, 2218.9]], 10192: [[888885, 11110], 10202, [222225, 0]]}
const J_UNLOCKS := {10187: 1, 10188: 10, 10189: 15, 10190: 20, 10191: 30, 10192: 40, 10193: 45, 10194: 20, 10195: 25, 10196: 1}
## recruit(actorId, armorId, name, artifactName)
const RECRUIT := {YOMI: [Y_ARMOR, "黄泉", "赤雨双缨"], JINGLIU: [J_ARMOR, "镜流", "月魄剑匣"]}
const Y_RANDOM_DEBUFFS := [22, 32, 37, 67, 75, 88]
const SPREAD := {10172: 0.33, 10173: 0.50, 10174: 0.66}
const DREAM_SKILL := 10174
## 残梦层数（原版 actor._codexYomiDream，战斗结束清零；重制只在战斗内用，不存档）：实例 ID → 层数
static var _dream := {}
## 本行动已施过集真赤（原版 action._codexYomiMarked）
static var _marked := false
## 扩散结算中的倍率（原版 action._codexYomiSpreadRate）；0 为不在扩散
static var spread_rate := 0.0
static var _negative_re := RegEx.create_from_string("<BuffType:(?:破甲|损伤|毒|灼伤|黑暗|诅咒|封印|沉默|冰冷|眩晕|减益|流血)>")


static func yomi(a) -> bool:
	return a is XActor and int(a.actor_id) == YOMI


static func yomi_skill(id: int) -> bool:
	return id >= 10171 and id <= 10174


static func jingliu(a) -> bool:
	return a is XActor and int(a.actor_id) == JINGLIU


static func jingliu_skill(id: int) -> bool:
	return id >= 10187 and id <= 10193


static func rank(a) -> int:
	return XAdvance.rank(XState.current, int(a.actor_id)) if a is XActor else 0


static func debuff_count(b) -> int:
	var seen := {}
	for id in b.state_ids:
		if id == Y_MARK or _negative_re.search(str(XDB.rec("States", id).get("note", ""))) != null:
			seen[id] = true
	return seen.size()


static func penetration(a) -> float:
	if not yomi(a):
		return 0.0
	var total := 0.0
	for id in [10178, 10181, 10184, 10186]:
		if not a.skill_ids.has(id) or (id == 10184 and rank(a) < 1) or (id == 10186 and rank(a) < 2):
			continue
		total += 0.22
	return total


## numRepeats：黄泉技能 (10174 为 6，其余 2)＋min(6, floor(幸运/6666))（第一期只给说明卡「段数」用）
static func repeats(a, id: int) -> int:
	return (6 if id == 10174 else 2) + mini(6, floori((a.luk if a != null else 0.0) / 6666.0))


static func param_plus(a, i: int, v: float) -> float:
	if not yomi(a):
		return v
	if i == 7 and a.skill_ids.has(10176):
		v += 888
	if i == 6 and a.skill_ids.has(10177):
		v += 777
	if i == 2 and a.skill_ids.has(10182):
		v += 888
	return v


static func param(a, i: int, v: float) -> float:
	if i == 2 and yomi(a) and rank(a) >= 2 and a.skill_ids.has(10186):
		return v + floorf(a.luk * 1.88)
	return v


static func xparam(a, i: int, v: float) -> float:
	return v + 9.99 if CRIT_FIX and i == 2 and yomi(a) and a.skill_ids.has(10185) else v


static func action_plus_set(a, rates: Array) -> void:
	if yomi(a) and a.skill_ids.has(10175):
		rates.append(1.0)


## CodexYomi.damage(a,b,id)：不是黄泉或不在表里为 0
static func formula(a, b, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if not yomi(a) or not Y_ROWS.has(id):
		return 0.0
	var r: Array = Y_ROWS[id]
	var n := debuff_count(b)
	return a.atk * (r[0] + r[1] * n) + a.agi * (r[2] + r[3] * n) + a.luk * (r[4] + r[5] * n)


## 伤害钩子 yomi-jingliu 的黄泉部分（镜流部分下一期）
static func damage_ops(item: Dictionary, a, b) -> Array:
	var id := int(item.get("id", 0))
	var ops := []
	if jingliu(a):
		return j_damage_ops(item, a)
	if not (yomi(a) and yomi_skill(id)):
		return ops
	var pen := penetration(a)
	ops.append({"op": "set", "field": "mode", "value": "physical"})
	ops.append({"op": "set", "field": "physicalIncomingPierce", "value": pen})
	ops.append({"op": "set", "field": "resistancePierce", "value": pen})
	if a.skill_ids.has(10179):
		ops.append({"op": "add", "field": "normalAdd", "value": 0.88})
	if a.skill_ids.has(10180):
		ops.append({"op": "add", "field": "elementAdd", "element": 5, "value": 0.77})
	if a.skill_ids.has(10183):
		ops.append({"op": "add", "field": "criticalAdd", "value": 6.66})
	if a.skill_ids.has(10185):
		ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.33 if id == 10174 else 16.55})
	if id != 10174 and a.has_base_equip("armor", Y_ARMOR) and b.state_ids.has(Y_MARK):
		ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.77})
	if spread_rate > 0.0:
		ops.append({"op": "mul", "field": "skillMultiplier", "value": spread_rate})
	return ops


# ---- 第二期：战斗包装 ----

static func _yomi_action(u, skill: Dictionary) -> bool:
	return yomi(u) and yomi_skill(int(skill.get("id", 0))) and not XBattleLogic.is_item(skill)


## itemHit 1／itemEva 0
static func sure(u, skill: Dictionary) -> bool:
	return _yomi_action(u, skill) or _j_action(u, skill)


## numRepeats 包装：黄泉技能换成 repeats()，否则原次数；同时开始新行动（清已施印）
static func begin_action(u, skill: Dictionary, base: int) -> int:
	_marked = false
	spread_rate = 0.0
	if _j_action(u, skill):
		return int(J_REPEATS[int(skill.id)])
	return repeats(u, int(skill.id)) if _yomi_action(u, skill) else base


static func dream(a) -> int:
	return clampi(int(_dream.get(a.get_instance_id(), 0)), 0, 9) if a != null else 0


static func set_dream(a, n: int) -> void:
	_dream[a.get_instance_id()] = n


## meetsSkillConditions：10174 残梦不满 9 不能用
static func meets(a, skill: Dictionary) -> bool:
	if _j_action(a, skill) and J_ENHANCED.has(int(skill.id)) and moon(a) < 1:
		return false  # 镜流强化剑技要月魄 ≥1
	return not (yomi(a) and int(skill.get("id", 0)) == DREAM_SKILL and not XBattleLogic.is_item(skill) and dream(a) < 9)


## paySkillCost：10174 扣 9 层
static func pay(a, skill: Dictionary) -> void:
	if yomi(a) and int(skill.get("id", 0)) == DREAM_SKILL and not XBattleLogic.is_item(skill):
		set_dream(a, maxi(0, dream(a) - 9))
	if _j_action(a, skill):
		_j_frame = {"user": a, "skill": skill, "moon_before": moon(a)}  # 镜流施放帧在付费时开（付费在定段数之前）
		if J_ENHANCED.has(int(skill.id)):
			_moon[a.get_instance_id()] = maxi(0, moon(a) - 1)


## BattleManager.endBattle：清残梦
static func end_battle() -> void:
	_dream.clear()
	_marked = false
	spread_rate = 0.0
	_moon.clear()
	_j_frame = {}
	_blood.clear()
	_bloom.clear()
	_moon_extra.clear()
	_blood_extra.clear()
	_queued = null


## Game_Action.apply 包装是否接管（扩散的补充结算不再进来）
static func wraps(u, skill: Dictionary, t) -> bool:
	return spread_rate == 0.0 and _yomi_action(u, skill) and t is XEnemy and t.is_alive()


static func _mark(logic, t) -> void:
	logic._state_add(t, Y_MARK)
	logic._state_add(t, Y_RANDOM_DEBUFFS[floori(logic._float("yomi_debuff") * Y_RANDOM_DEBUFFS.size())])


static func before_apply(logic, u, skill: Dictionary, t) -> void:
	var id := int(skill.id)
	if id != DREAM_SKILL and not _marked:
		_mark(logic, t)
		if id == 10173 and u.skill_ids.has(10185):
			_mark(logic, t)
		_marked = true


static func _charge(u, t, r: Dictionary) -> void:
	if not bool(r.get("missed", false)) and not bool(r.get("evaded", false)) and debuff_count(t) > 0:
		set_dream(u, mini(9, dream(u) + 1))


## 主目标结算之后：充残梦、扩散；返回扩散各次的结算记录（追加进行动日志）
static func after_apply(logic, u, skill: Dictionary, t, r: Dictionary) -> Array:
	var id := int(skill.id)
	if id != DREAM_SKILL:
		_charge(u, t, r)
	var out := []
	if not SPREAD.has(id):
		return out
	spread_rate = float(SPREAD[id])
	for other in logic.enemies.filter(func(e): return e.is_alive()):
		if other == t:
			continue
		var r2: Dictionary = logic.apply(u, skill, other)
		if id != DREAM_SKILL:
			_charge(u, other, r2)
		out.append(r2)
	spread_rate = 0.0
	return out


## recruit(actorId, armorId, name, artifactName)：已在队返回空数组；否则入队，返回要提示的两条文字
static func recruit(s: XState, actor_id: int) -> Array:
	if s.party.has(actor_id):
		return []
	var row: Array = RECRUIT[actor_id]
	var armor := int(row[0])
	var a := s.actor(actor_id)
	var slot := a.equip_slots().find(int(XDB.rec("Armors", armor).get("etypeId", 0)))
	if slot < 0:
		push_error("[xiyou] " + str(row[1]) + "法宝装备槽不可用")
		return []
	var worn = a.equips[slot]
	if not (worn is Dictionary and int(worn.get("base", 0)) == armor):
		var idx := s.gear.find_custom(func(e): return e.kind == "armor" and int(e.base) == armor)
		if idx < 0:
			s.gain_gear("armor", armor, 1)
			idx = s.gear.size() - 1
		var item: Dictionary = s.gear[idx]
		s.gear.remove_at(idx)
		if worn is Dictionary and not worn.is_empty():
			s.gear.append(worn)
		a.equips[slot] = item
		a.refresh_passive()  # changeEquip 刷新特性与被动
	s.add_actor(actor_id)
	return ["小伙伴 " + str(row[1]) + " 加入队伍", "获得并装备专属法宝：" + str(row[2])]


# ---- 镜流第一期 ----
## 月魄（原版 actor._codexJingliuMoon；开回合满 3、结束战斗清零，只在战斗内）：实例 ID → 层数
static var _moon := {}
## 本行动（原版记在 Game_Action 上，重制在 paySkillCost 时新开）：行动者、技能、付费前月魄 moon_before、主目标 main、命中 hit
static var _j_frame := {}
## 放血累计、昙华绽放、本回合用过的两种追加行动（原版角色字段，只在战斗内）：实例 ID → 值
static var _blood := {}
static var _bloom := {}
static var _moon_extra := {}
static var _blood_extra := {}
## 行动结束后要插队的镜流
static var _queued = null


static func _j_action(u, skill: Dictionary) -> bool:
	return jingliu(u) and jingliu_skill(int(skill.get("id", 0))) and not XBattleLogic.is_item(skill)


static func moon(a) -> int:
	return clampi(int(_moon.get(a.get_instance_id(), 0)), 0, 3) if a != null else 0


## soul(actor, level)：学了命途：毁灭 10194 且到级
static func soul(a, level: int) -> bool:
	return jingliu(a) and a.skill_ids.has(10194) and int(a.level) >= level


## normalizeJingliuSkills（Game_Actor.setup 包装；读档时 state 给读进来的那份，进阶次数从它取）
static func setup(a, state: XState = null) -> void:
	if not jingliu(a):
		return
	var r := XAdvance.rank(state, JINGLIU) if state != null else rank(a)
	for id in J_UNLOCKS:
		if int(a.level) >= int(J_UNLOCKS[id]):
			a.learn_skill(id)
		else:
			a.forget_skill(id)
	for id in [10197, 10198, 10199]:
		a.forget_skill(id)
	for id in [10200, 10201, 10202]:
		if r >= 1:
			a.learn_skill(id)
		else:
			a.forget_skill(id)


## Game_Actor.paramBase 包装：v 是原 paramBase；星魂 20／40 级各再加一份最大生命，35 级再加一份攻击
static func param_base(a, i: int, v: float) -> float:
	if not jingliu(a):
		return v
	var out := v
	if i == 0:
		if soul(a, 20):
			out += v
		if soul(a, 40):
			out += v
	if i == 2 and soul(a, 35):
		out += v
	return out


## CodexJingliu.damage(a,b,id)；calculating＝在伤害计算里（CodexDamage.isCalculating，战斗结算都是），守势项恒为 1，
## 否则乘 1/(1＋目标防御/max(1, 10×攻击＋2×最大生命))
static func j_formula(a, b, item: Dictionary, calculating := true) -> float:
	var id := int(item.get("id", 0))
	if not jingliu(a) or not J_ROWS.has(id):
		return 0.0
	var row: Array = J_ROWS[id]
	var atk := maxf(0.0, a.atk)
	var hp := maxf(0.0, a.mhp)
	var scaled := hp * (17463.0 / 136584.0)
	var high := maxf(atk, scaled)
	var low := minf(atk, scaled)
	var balance := low / high if high > 0.0 else 0.0
	var mine: bool = is_same(_j_frame.get("user"), a) and _j_frame.has("moon_before")
	var m: int = int(_j_frame.moon_before) if mine else moon(a)
	if mine and _j_frame.get("extra_row") != null:
		row = _j_frame.extra_row
	var blood: float = float(_j_frame.get("blood", 1.0)) if mine else 1.0
	var marks := 1.0 + (0.10 if b.state_ids.has(J_FROST) else 0.0) + (0.10 if b.state_ids.has(J_GAP) else 0.0)
	var guard := 1.0 if calculating else 1.0 / (1.0 + maxf(0.0, b.param(3)) / maxf(1.0, 10.0 * atk + 2.0 * hp))
	return (atk * row[0] + hp * row[1]) * (0.85 + 0.15 * balance) * (1.0 + 0.06 * (m - 2.5)) * marks * guard * blood


## 伤害钩子 yomi-jingliu 的镜流部分
static func j_damage_ops(item: Dictionary, a) -> Array:
	var id := int(item.get("id", 0))
	var ops := []
	if jingliu_skill(id):
		ops.append({"op": "set", "field": "mode", "value": "physical"})
	if a.has_base_equip("armor", J_ARMOR) and int(item.get("stypeId", 0)) != 4:
		ops.append({"op": "add", "field": "normalAdd", "value": 0.25})
	if int(item.get("damage", {}).get("elementId", 0)) == 3:
		if soul(a, 25):
			ops.append({"op": "add", "field": "elementAdd", "element": 3, "value": 1.0})
		if jingliu_skill(id):
			if [10187, 10189, 10191].has(id) and soul(a, 30):
				ops.append({"op": "mul", "field": "skillMultiplier", "value": 2.0})
			if J_ENHANCED.has(id) and soul(a, 45):
				ops.append({"op": "mul", "field": "skillMultiplier", "value": 2.0})
			if id == 10192 and is_same(_j_frame.get("user"), a) and bool(_j_frame.get("bloom", false)):
				ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.0666})
			if id == 10192 and a.skill_ids.has(10202):
				ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.1})
	return ops


static func _j_mine(u, skill: Dictionary) -> bool:
	return _j_action(u, skill) and is_same(_j_frame.get("user"), u) and not bool(_j_frame.get("supplemental", false))


## Game_Action.apply 包装（原 apply 之前）：第一次打到活着的敌人时准备——主目标、昙华绽放、放血、记下印记
static func j_before(logic, u, skill: Dictionary, t) -> void:
	if not _j_mine(u, skill) or not (t is XEnemy and t.is_alive()) or _j_frame.has("main"):
		return
	var id := int(skill.id)
	_j_frame["main"] = t
	var key = u.get_instance_id()
	_j_frame["bloom"] = id == 10192 and bool(_bloom.get(key, false))
	if _j_frame.bloom:
		_bloom[key] = false
	if J_ENHANCED.has(id):
		var p: Array = {10188: [0.03, 1.25], 10190: [0.05, 1.50], 10192: [0.08, 2.50 if u.skill_ids.has(10202) else 1.80]}[id]
		_pay_blood(logic, u, float(p[0]), float(p[1]))
		_j_frame["had_frost"] = t.state_ids.has(J_FROST)
		_j_frame["had_gap"] = t.state_ids.has(J_GAP)


## payBlood
static func _pay_blood(logic, u, percent: float, cap: float) -> void:
	var total := 0.0
	for ally in logic.actors:
		if is_same(ally, u) or not ally.is_alive():
			continue
		var actual := minf(floorf(ally.mhp * percent), maxf(0.0, ally.hp - 1.0))
		if actual > 0.0:
			logic.gain_hp(ally, -actual)
			total += actual
	var key = u.get_instance_id()
	_blood[key] = float(_blood.get(key, 0.0)) + total
	_j_frame["lost"] = total > 0.0
	_j_frame["blood"] = 1.0 + minf(float(_blood[key]) / maxf(1.0, 5.0 * u.mhp), cap - 1.0)


## Game_Action.apply 包装（原 apply 之后）：命中记下
static func j_applied(u, skill: Dictionary, t, r: Dictionary, alive_before: bool) -> void:
	if not _j_mine(u, skill) or not (t is XEnemy and alive_before) or not _j_frame.has("main"):
		return
	if not bool(r.get("missed", false)) and not bool(r.get("evaded", false)):
		_j_frame["hit"] = true


static func _advanced_row(u, id: int) -> Array:
	var c: Array = J_ADVANCED[id]
	var row: Array = (c[0] as Array).duplicate()
	if u.skill_ids.has(int(c[1])):
		row[0] += c[2][0]
		row[1] += c[2][1]
	return row


## supplemental：直接 apply（不走 apply 包装），公式换进阶行
static func _supplemental(logic, u, skill: Dictionary, t, row: Array) -> Array:
	if not (t is XEnemy and t.is_alive()):
		return []
	_j_frame["supplemental"] = true
	_j_frame["extra_row"] = row
	var r: Dictionary = logic.apply(u, skill, t)
	_j_frame["supplemental"] = false
	_j_frame["extra_row"] = null
	r["supplemental"] = true
	return logic.mark_views([r])


## BattleManager.endAction 包装（原 endAction 之前）：追加段与去印记、霜痕／裂隙、月魄回复、昙华绽放、追加行动；返回追加段的记录
static func j_finish(logic, u, skill) -> Array:
	var logs := []
	if not skill is Dictionary or not _j_action(u, skill) or not is_same(_j_frame.get("user"), u) or not _j_frame.has("main") or _j_frame.get("finished", false):
		return logs
	_j_frame["finished"] = true
	var id := int(skill.id)
	var hit := bool(_j_frame.get("hit", false))
	var main = _j_frame.main
	var key = u.get_instance_id()
	var extra := false
	if id == 10188 and bool(_j_frame.get("had_frost", false)):
		logs.append_array(_supplemental(logic, u, skill, main, _advanced_row(u, 10188)))
		logic._state_remove(main, J_FROST)
	if id == 10190 and bool(_j_frame.get("had_gap", false)):
		var row := _advanced_row(u, 10190)
		for e in logic.enemies.filter(func(x): return x.is_alive()):
			if not is_same(e, main):
				logs.append_array(_supplemental(logic, u, skill, e, row))
		logic._state_remove(main, J_GAP)
	if id == 10192:
		var row := _advanced_row(u, 10192)
		for e in logic.enemies.filter(func(x): return x.is_alive()):
			logs.append_array(_supplemental(logic, u, skill, e, row))
		if main.state_ids.has(J_GAP):
			logic._state_remove(main, J_GAP)
	if hit and id == 10187:
		logic._state_add(main, J_FROST)
	if hit and id == 10189:
		logic._state_add(main, J_GAP)
		main.set_meta("jingliu_gap_evolved", u.skill_ids.has(10201))
	if ([10187, 10189, 10191].has(id) and hit) or id == 10193:
		var previous := moon(u)
		var gain := 2 if id != 10193 and int(u.level) >= 25 and u.skill_ids.has(10195) else 1
		_moon[key] = mini(3, previous + gain)
		if previous < 2 and moon(u) >= 2 and not bool(_moon_extra.get(key, false)):
			_moon_extra[key] = true
			extra = true
	if id == 10193:
		_bloom[key] = true
	if id == 10192 and bool(_j_frame.get("lost", false)) and u.skill_ids.has(10202) and not bool(_blood_extra.get(key, false)):
		_blood_extra[key] = true
		extra = true
	if extra:
		_queued = u
	return logs


## queueJingliu（原 endAction 之后）：活着且本回合行动不到 5 次时插到行动队首
static func queue_extra(logic, u) -> void:
	if _queued == null or not is_same(_queued, u):
		return
	_queued = null
	if u.is_alive() and int(logic._acted.get(u, 0)) < 5:
		logic.current_order.push_front(u)


## 裂隙演化：Game_Enemy.param(3) 包装
static func enemy_param(e, i: int, v: float) -> float:
	return floorf(v * 0.89) if i == 3 and _gap_evolved(e) else v


## 裂隙演化：elementRate(3) 包装
static func element_rate(b, element: int, v: float) -> float:
	return v + 0.0111 if element == 3 and _gap_evolved(b) else v


static func _gap_evolved(b) -> bool:
	return b is XEnemy and bool(b.get_meta("jingliu_gap_evolved", false)) and b.state_ids.has(J_GAP)


## BattleManager.startBattle 包装：放血累计清零
static func start_battle(logic) -> void:
	var s: XState = logic.state
	if s != null and s.actors.has(JINGLIU):
		_blood.erase(s.actors[JINGLIU].get_instance_id())


## extractSaveContents 包装：读档时整理技能、放血累计清零
static func after_load(s: XState) -> void:
	if s.actors.has(JINGLIU):
		setup(s.actors[JINGLIU], s)
		_blood.erase(s.actors[JINGLIU].get_instance_id())


## BattleManager.startTurn 包装：月魄满 3
static func start_turn(logic) -> void:
	var s: XState = logic.state
	if s != null and s.actors.has(JINGLIU):
		var key = s.actors[JINGLIU].get_instance_id()
		_moon[key] = 3
		_moon_extra[key] = false
		_blood_extra[key] = false
