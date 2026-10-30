class_name XYomiJingliu
extends RefCounted
## 169 黄泉、170 镜流（正式 js/codex/runtime/installNativeYomiJingliuRuntime.js，W.CodexYomi／W.CodexJingliu，两人共用一个模块）。
## 本期（第一期）做共用框架与黄泉：招募、能力值／被动、公式、伤害钩子；镜流整套留下一期（只留共用的招募表与判定）。
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
## 未移植：隐藏呼吸技能分类、图标与品质色、Map132 商店补号角 2931／2932、旧档迁移。镜流（170）全部留下一期。

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
	return _yomi_action(u, skill)


## numRepeats 包装：黄泉技能换成 repeats()，否则原次数；同时开始新行动（清已施印）
static func begin_action(u, skill: Dictionary, base: int) -> int:
	_marked = false
	spread_rate = 0.0
	return repeats(u, int(skill.id)) if _yomi_action(u, skill) else base


static func dream(a) -> int:
	return clampi(int(_dream.get(a.get_instance_id(), 0)), 0, 9) if a != null else 0


static func set_dream(a, n: int) -> void:
	_dream[a.get_instance_id()] = n


## meetsSkillConditions：10174 残梦不满 9 不能用
static func meets(a, skill: Dictionary) -> bool:
	return not (yomi(a) and int(skill.get("id", 0)) == DREAM_SKILL and not XBattleLogic.is_item(skill) and dream(a) < 9)


## paySkillCost：10174 扣 9 层
static func pay(a, skill: Dictionary) -> void:
	if yomi(a) and int(skill.get("id", 0)) == DREAM_SKILL and not XBattleLogic.is_item(skill):
		set_dream(a, maxi(0, dream(a) - 9))


## BattleManager.endBattle：清残梦
static func end_battle() -> void:
	_dream.clear()
	_marked = false
	spread_rate = 0.0


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
