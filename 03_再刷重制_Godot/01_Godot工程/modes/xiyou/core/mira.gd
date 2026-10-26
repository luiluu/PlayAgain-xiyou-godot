class_name XMira
extends RefCounted
## 168 米拉（正式 js/codex/runtime/installNativeMiraRuntime.js，W.CodexMira）第一期：招募、能力值包装、公式。
## - 进阶次数 rank＝原版 a._AdvancedNum（XAdvance.rank）；has(技能, 需要次数)＝进阶够且学会。
## - 能力值（Game_Actor.param 包装，对最终面板乘算后取整、夹上限）：非黑龙形态时 30 级起学了 10144 物防／魔防
##   ×1.25×(1＋0.25×min(1,(等级−30)/5))；40 级起学了 10145 攻击／魔攻 ×1.10、速度再 ×(1＋0.25×min(1,(等级−40)/5))；
##   进阶 2 次起学了 10166 八项 ×1.5。
## - 公式 CodexMira.damage(a,b,id)：照原版逐技能写；技能熟练度经 skillMasteryLevel（重制首期恒 0）。
##   CodexDamage 结算里减防项为 0（原版 CodexDamage.isCalculating() 时去掉 35×b.def 之类）。
## - 黑龙形态 dragon()：原版要在战斗中、进阶 3 次以上、学了 10161 且带状态 2592；重制以带状态 2592 代替「在战斗中」
##   （2592 只由解放·黑龙在战斗里加、战斗结束即删）。第一期不做解放，所以实际不会进入黑龙形态。
## - 强者分档（6216／6235 等）在 XActor._fix_strong_classification，不在这里。
## - 招募（公共事件 9003 的 CodexMira.recruit()）：已在队返回 false；没戴黑龙心鳞 4577 时，背包里有同款就拿、没有就生成独立法宝，
##   装进它装备类型的槽；入队。
## 未移植（第二期起）：解放·黑龙与黑龙形态（变身、技能可用条件、免疫状态、受伤 ×0.8、回合回血、劫火追加伤害）、禁忌的减耗与扣血、
## 深渊掉落 2903、Map132 商店补号角 2904、伤害钩子 mira 的 mode（第一期各技能 hitType 与它一致）、名字与外观、旧档迁移。
## 共用的 MiraRavenNumberBoost 在 XNumberBoost。

const ACTOR := 168
const ARMOR := 4577
const DRAGON := 2592
const DRAGON_ATTACKS := [10148, 10149, 10150, 10151]
const LIBERATE := 10146


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
