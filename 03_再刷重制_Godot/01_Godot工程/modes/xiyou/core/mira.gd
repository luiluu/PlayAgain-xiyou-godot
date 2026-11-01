class_name XMira
extends RefCounted
## 168 米拉（正式 js/codex/runtime/installNativeMiraRuntime.js，W.CodexMira）：招募、能力值包装、公式（第一期），解放·黑龙与黑龙形态（第二期）。
## - 进阶次数 rank＝原版 a._AdvancedNum（XAdvance.rank）；has(技能, 需要次数)＝进阶够且学会。
## - 能力值（Game_Actor.param 包装，对最终面板乘算后取整、夹上限）：非黑龙形态时 30 级起学了 10144 物防／魔防
##   ×1.25×(1＋0.25×min(1,(等级−30)/5))；40 级起学了 10145 攻击／魔攻 ×1.10、速度再 ×(1＋0.25×min(1,(等级−40)/5))；
##   进阶 2 次起学了 10166 八项 ×1.5。
## - 公式 CodexMira.damage(a,b,id)：照原版逐技能写；技能熟练度经 skillMasteryLevel（重制首期恒 0）。
##   CodexDamage 结算里减防项为 0（原版 CodexDamage.isCalculating() 时去掉 35×b.def 之类）。
## - 黑龙形态 dragon()：原版要在战斗中、进阶 3 次以上、学了 10161 且带状态 2592；重制以带状态 2592 代替「在战斗中」
##   （2592 只由解放·黑龙在战斗里加，战斗结束必删：它 removeAtBattleEnd，end_battle 也删；战斗中不能存档）。
## - 强者分档（6216／6235 等）在 XActor._fix_strong_classification，不在这里。
## - 招募（公共事件 9003 的 CodexMira.recruit()）：已在队返回 false；没戴黑龙心鳞 4577 时，背包里有同款就拿、没有就生成独立法宝，
##   装进它装备类型的槽；入队。
## 第二期（参照 mv_oracle/mira_battle_probe.cjs）：
## - meetsSkillConditions（meets）：黑龙技 10148～10152 只在黑龙形态，人形技 10140～10143 黑龙形态不能用，解放 10146 要进阶 3、50 级、
##   学会且不在黑龙形态，10147 永远不能单放。
## - 禁忌 10166（进阶 2）：主动技（人形 4＋解放＋劫焰＋黑龙 5）skillMpCost／skillTpCost ×0.75 取整（cost）；paySkillCost 登记生命代价
##   max(1, floor(mhp×10%))（pay），本次行动结束（原 endAction 之前）扣，未命中照扣、最低留 1（pay_hp）。
## - 解放（原 endAction 之后，liberate）：用 10146 且进阶 3、学了 10146 → 加 2592；学了终焉 10167 再清名单状态与全部减益。
##   原版清减益调的是不存在的 removeDebuff，身上有减益时这里抛 TypeError（正式游戏报错），重制照字面意思清掉（O-123，DEBUFF_FIX）。
##   原版随后 clearActions：OTB 每个行动位开头都重新 makeActions，清掉也不影响本回合后面的行动位，重制不做（按代码阅读，未单测）。
## - 终焉（黑龙形态且学了 10167）：名单状态 isStateResist／addState 挡（resists，XActor.add_state），addDebuff 全挡（blocks_debuff）。
## - 不灭龙血 10154（进阶 3）：黑龙形态受伤 ×0.8（伤害钩子 mira，XActorDamageHooks.mira_ops）；onTurnEnd 之后活着回 floor(mhp×5%)（turn_end）。
## - 修雷德劫火 10162（55 级、进阶 3）：黑龙形态或用解放时，本回合对每个敌人命中的火属性（元素 2）生命伤害累计（after_apply）；
##   endTurn（原 endTurn 之前）对活着的目标再扣 floor(累计×30%)（end_turn）；startTurn 清空。累计只在战斗内、不存档。
## - endBattle：删 2592／2597／2598／2599，清代价与劫火（end_battle）。
## 深渊掉落（makeRewards 包装，第 392～401 行；【cc·白龙_12·未经审查】）：MapInfos 名字以「深渊」开头的地图上胜利，每场判一次，
## 1/30（Math.randomInt(30)===0，重制取战斗奖励随机数）多给一个黑龙进阶石 2903（米拉三次进阶都要 1 个，原版只有这一处来源）。见 abyss_bonus。
## 未移植：战斗图换成 sv_enemies/BlackDragon_Mira_Enemy（Sprite_Actor.updateBitmap 包装，缩 0.55、下移、藏武器）、名字与外观、旧档迁移。
## 共用的 MiraRavenNumberBoost 在 XNumberBoost。

const ACTOR := 168
const ARMOR := 4577
const DRAGON := 2592
const DRAGON_ATTACKS := [10148, 10149, 10150, 10151]
const LIBERATE := 10146
const FLAME := 10147
const HUMAN_SKILLS := [10140, 10141, 10142, 10143]
const DRAGON_SKILLS := [10148, 10149, 10150, 10151, 10152]
const ACTIVE_SKILLS := [10140, 10141, 10142, 10143, 10146, 10148, 10149, 10150, 10151, 10152]
const BATTLE_STATES := [2592, 2597, 2598, 2599]
## M.endOfAllImmuneStates
const END_OF_ALL_IMMUNE := [4, 6, 10, 29, 30, 33, 35, 46, 100, 107, 126, 127, 128, 130, 131, 150, 178, 184, 234, 263, 264, 274, 320, 741, 742,
	927, 995, 1082, 1101, 1102, 1114, 1119, 1264, 1544, 2016, 2042, 2043, 2503, 2507, 2513]
## O-123：解放时终焉照说明清掉全部减益（原版调不存在的 removeDebuff 抛错）；false＝不清（不照搬报错）
static var DEBUFF_FIX := true
## 本次施放登记的禁忌生命代价 {skill, cost}（_codexMiraForbiddenHpDue）
static var _due = null
## 本回合劫火累计 [[目标, 量], …]（_codexMiraTurnFlame）
static var _flame := []


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func rank(a) -> int:
	return XAdvance.rank(XState.current, ACTOR) if own(a) else 0


static func has(a, skill: int, needed := 0) -> bool:
	return own(a) and rank(a) >= needed and a.skill_ids.has(skill)


static func dragon(a) -> bool:
	return own(a) and rank(a) >= 3 and has(a, 10161, 3) and a.state_ids.has(DRAGON)


static func heart_equipped(a) -> bool:
	return a.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == ARMOR)


## Game_Actor.param 包装（v 是包装前、已取整夹值的值）
static func param(a, i: int, v: float) -> float:
	if not own(a):
		return v
	var lv := int(a.level)
	if not dragon(a):
		if (i == 3 or i == 5) and lv >= 30 and has(a, 10144):
			v *= 1.25 * (1 + 0.25 * minf(1.0, maxf(0.0, (lv - 30) / 5.0)))
		if (i == 2 or i == 4 or i == 6) and lv >= 40 and has(a, 10145):
			v *= 1.10 * ((1 + 0.25 * minf(1.0, maxf(0.0, (lv - 40) / 5.0))) if i == 6 else 1.0)
	if has(a, 10166, 2):
		v *= 1.5
	return XPower.js_round(minf(a.param_max(i), v))


## CodexMira.damage(a,b,id)
static func formula(a, b, item: Dictionary) -> float:
	var id := int(item.get("damage", {}).get("formula", "").get_slice(",", 2).to_int())
	if not own(a):
		return 0.0
	var lv := float(a.skillMasteryLevel(id))
	var dragon_attack := DRAGON_ATTACKS.has(id)
	if dragon_attack and not dragon(a):
		return 0.0
	if id == LIBERATE and (rank(a) < 3 or int(a.level) < 50 or dragon(a)):
		return 0.0
	var raw := 0.0
	var coeff := 0.15
	match id:
		10140: raw = 80000 * a.atk + 20000 * a.def
		10141: raw = (48000 * a.atk + 12000 * a.def) * (1 + 0.75 * (1 - clampf(b.hp_rate(), 0.0, 1.0)))
		10142: raw = 80000 * a.mat + 20000 * a.mdf
		10143: raw = (48000 * a.mat + 12000 * a.mdf) / 3.0 * (1.25 if b.state_ids.has(2594) else 1.0)
		10146, 10147:
			raw = 220 * a.atk + 220 * a.mat + 40 * a.mhp
			coeff = 0.1
		10148: raw = 800 * a.atk + 240 * a.def
		10149: raw = 600 * a.mat + 160 * a.mdf + 80 * a.mmp
		10150:
			raw = 500 * a.atk + 180 * a.def + 300 * a.agi
			coeff = 0.18
		10151:
			raw = 500 * a.mhp + 140 * a.mmp + 1200 * a.atk + 680 * a.def + 1200 * a.mat + 680 * a.mdf + 900 * a.agi + 240 * a.luk
			coeff = 0.20
		_:
			return 0.0
	var total := maxf(0.0, raw) * (1 + coeff * lv)
	var level := int(a.level)
	if not dragon_attack and has(a, 10156):
		var foundation := 2.0 if level >= 60 else (1.8 + 0.02 * (level - 50) if level >= 50 else
			(1.66 + 0.14 * (level - 15) / 35.0 if level >= 15 else 1.15 + 0.051 * maxi(0, level - 5)))
		total *= foundation
	if rank(a) >= 2 and has(a, 10158, 2):
		total *= 2.5
	if heart_equipped(a):
		total *= 1.2
	if dragon_attack:
		total *= 2
		if has(a, 10161, 3):
			total *= 17.77
		if level >= 60 and has(a, 10163, 3):
			total *= 1.5
		if level >= 70 and has(a, 10164, 3):
			total *= 2
	elif rank(a) == 2 and has(a, 10159, 2):
		var attr: float = a.mat if (id == 10142 or id == 10143) else a.atk
		total *= 1.1 * pow(maxf(1.0, attr) / 40000.0, 0.5)
	elif rank(a) >= 3 and has(a, 10160, 3):
		total *= 2.88
	if id == LIBERATE or id == 10147:
		total *= 2
	if has(a, 10165, 1):
		total *= 1.15
	if has(a, 10166, 2):
		total *= 1.15
	if id == 10151 and dragon(a) and has(a, 10167, 3):
		total *= 1.2
	return floorf(total)


## CodexMira.recruit()
static func recruit(s: XState) -> bool:
	if s.party.has(ACTOR):
		return false
	var a := s.actor(ACTOR)
	var etype := int(XDB.rec("Armors", ARMOR).get("etypeId", 0))
	var slot := a.equip_slots().find(etype)
	if slot < 0:
		push_error("[xiyou] 米拉法宝装备槽不可用")
		return false
	var worn = a.equips[slot]
	if not (worn is Dictionary and int(worn.get("base", 0)) == ARMOR):
		var idx := s.gear.find_custom(func(e): return e.kind == "armor" and int(e.base) == ARMOR)
		if idx < 0:
			s.gain_gear("armor", ARMOR, 1)
			idx = s.gear.size() - 1
		var relic: Dictionary = s.gear[idx]
		s.gear.remove_at(idx)
		if worn is Dictionary and not worn.is_empty():
			s.gear.append(worn)
		a.equips[slot] = relic
		a.refresh_passive()
	s.add_actor(ACTOR)
	return true


static func end_of_all(a) -> bool:
	return dragon(a) and has(a, 10167, 3)


## 终焉 isStateResist／addState 包装
static func resists(b, id: int) -> bool:
	return END_OF_ALL_IMMUNE.has(id) and end_of_all(b)


## 终焉 addDebuff 包装
static func blocks_debuff(b) -> bool:
	return end_of_all(b)


## Game_Actor.meetsSkillConditions 包装
static func meets(a, skill: Dictionary) -> bool:
	if not own(a) or skill.is_empty():
		return true
	var id := int(skill.get("id", 0))
	if DRAGON_SKILLS.has(id) and not dragon(a):
		return false
	if HUMAN_SKILLS.has(id) and dragon(a):
		return false
	if id == LIBERATE and (rank(a) < 3 or int(a.level) < 50 or not has(a, LIBERATE, 3) or dragon(a)):
		return false
	return id != FLAME


## 禁忌 skillMpCost／skillTpCost 包装（v 是包装前的费用）
static func cost(a, skill: Dictionary, v: int) -> int:
	return floori(v * 0.75) if ACTIVE_SKILLS.has(int(skill.get("id", 0))) and has(a, 10166, 2) else v


## 禁忌 paySkillCost 包装：只登记，行动结束才扣
static func pay(a, skill: Dictionary) -> void:
	if not own(a):
		return
	_due = null
	if ACTIVE_SKILLS.has(int(skill.get("id", 0))) and has(a, 10166, 2):
		_due = {"skill": int(skill.id), "cost": maxf(1.0, floorf(a.mhp * 0.1))}


## BattleManager.endAction 包装（原 endAction 之前）：扣登记的生命代价，最低留 1
static func pay_hp(u, skill) -> void:
	if not own(u):
		return
	var due = _due
	_due = null
	if due == null or not skill is Dictionary or int(skill.get("id", 0)) != int(due.skill):
		return
	var paid := minf(float(due.cost), maxf(0.0, u.hp - 1.0))
	if paid > 0.0:
		u.hp -= paid
		u.refresh_resources()


## BattleManager.endAction 包装（原 endAction 之后）：解放·黑龙
static func liberate(logic, u, skill) -> void:
	if not own(u) or not skill is Dictionary or int(skill.get("id", 0)) != LIBERATE or rank(u) < 3 or not has(u, LIBERATE, 3):
		return
	logic._state_add(u, DRAGON)
	if end_of_all(u):
		for id in END_OF_ALL_IMMUNE:
			if u.state_ids.has(id):
				logic._state_remove(u, id)
		if DEBUFF_FIX:
			for pid in range(8):
				if u.buffs[pid] < 0:
					logic.sequence_buff(u, pid, false, false, 0)
	u.param_refresh()


## Game_Action.apply 包装：黑龙形态或解放命中敌人的火属性生命伤害记进本回合劫火
static func after_apply(u, skill: Dictionary, t, r: Dictionary) -> void:
	if not own(u) or not t is XEnemy:
		return
	var result: Dictionary = r.get("result", {})
	var amount := maxf(0.0, float(result.get("hpDamage", 0.0))) if not bool(r.get("missed", false)) and not bool(r.get("evaded", false)) else 0.0
	if amount <= 0.0 or int(skill.get("damage", {}).get("elementId", 0)) != 2:
		return
	if int(u.level) < 55 or not has(u, 10162, 3) or not (dragon(u) or int(skill.get("id", 0)) == LIBERATE):
		return
	for e in _flame:
		if e[0] == t:
			e[1] += amount
			return
	_flame.append([t, amount])


## BattleManager.startTurn 包装
static func start_turn() -> void:
	_flame.clear()


## BattleManager.endTurn 包装（原 endTurn 之前）：劫火追加 floor(累计×30%)；返回弹字记录
static func end_turn(logic) -> Array:
	var logs := []
	var a = logic.state.actors.get(ACTOR)
	if a == null or int(a.level) < 55 or not has(a, 10162, 3):
		return logs
	for e in _flame:
		var t = e[0]
		var extra := floorf(float(e[1]) * 0.3)
		if t == null or t.is_dead() or extra <= 0.0:
			continue
		var before: float = t.hp
		logic.gain_hp(t, -extra)  # gainHp（审查第 14 期 P3：原来直接写 hp，绕过异化与连命等路由）
		logs.append({"type": "regen", "target": t, "hp": before - t.hp, "views": logic.views([t])})
		if t.is_dead():
			logs.append({"type": "collapse", "target": t, "views": logic.views([t])})
	_flame.clear()
	return logs


## Game_Actor.onTurnEnd 包装（原 onTurnEnd 之后）：不灭龙血回 5%
static func turn_end(logic, b, logs: Array) -> void:
	if not (dragon(b) and has(b, 10154, 3) and b.is_alive()):
		return
	var before: float = b.hp
	b.hp = minf(b.mhp, b.hp + floorf(b.mhp * 0.05))
	b.refresh_resources()
	if b.hp != before:
		logs.append({"type": "regen", "target": b, "hp": before - b.hp, "views": logic.views([b])})


## BattleManager.endBattle 包装
static func end_battle(s: XState) -> void:
	_due = null
	_flame.clear()
	var a = s.actors.get(ACTOR) if s != null else null
	if a != null:
		for id in BATTLE_STATES:
			if a.state_ids.has(id):
				a.remove_state(id)


const ABYSS_STONE := 2903

## makeRewards 包装：深渊地图的胜利 1/30 多一个黑龙进阶石；一场只判一次（结果记在这场的 logic 上，rewards() 再调不重掷）
static func abyss_bonus(logic) -> Array:
	if logic.has_meta("mira_abyss"):
		return logic.get_meta("mira_abyss")
	var out := []
	var s: XState = logic.state
	if s != null and logic.random != null and str(XDB.rec("MapInfos", s.map_id).get("name", "")).begins_with("深渊") and not XDB.rec("Items", ABYSS_STONE).is_empty():
		if floori(logic.random.reward.next_float("mira_abyss_stone", "0") * 30) == 0:
			out.append({"kind": 1, "id": ABYSS_STONE})
	logic.set_meta("mira_abyss", out)
	return out
