class_name XRaven
extends RefCounted
## 167 渡鸦（正式 js/codex/runtime/installNativeRavenRuntime.js，W.CodexRaven）第一期：招募、开机数据、技能解锁、公式、被动、伤害钩子；
## 第二期：灵魂积累与铸印。
## - 阶位 stage＝原版 _codexRavenStage（取 _AdvancedNum 与它的较大者，进阶时两者同步），重制读 XAdvance.rank，夹在 0～5。
## - 开机数据（isDatabaseLoaded 的 finishRavenDatabaseCompatibility）：给原版角色进阶表补渡鸦 0～4 次的 5 行（需求等级 15／25／35／45／45、
##   冥羽进阶印 2901×1，学 10131／10132／10133／10134／[10127,10170]），由转换器 boot_database_records 写进 Plugins.json。
## - 技能解锁 SKILL_GATE（技能 → [等级, 阶位]）：setup 与每次升级后（setupRaven）按职业习得表重排——到级且到阶的职业技能补学，
##   渡鸦专属技能 10122～10139 与 10170 未解锁的忘掉；职业一的旧技能 160／311／502／1746 与 10168 也去掉。
## - 公式（5 个伤害技能整条公式）：(魔攻×k1＋MP 上限×k2)×legionStrikeRate×skillCoefficient；黑翼裁决按目标失血加成。
##   legionStrikeRate：学了 10138「魄」时 [6,10,20,33,66,99][阶]/11，否则 1；skillCoefficient 按阶位查表。
## - 被动（initPassiveCache 包装）：学了 10137 时暴伤池、终伤池按等级插值（1／10／25／40／55／70 级）加进 critHarmRi／globalHarmRi（÷100）。
## - 面板暴击（NumberBoost 的 xparam 包装，学了 10137）：+10×灵魂进度；伤害钩子 raven 见 XActorDamageHooks。
## - 灵魂值 soul（_codexRavenSoul）与已铸印的阶 forged（_codexRavenForgedStage，没铸过 −1）存在 XState.raven（存档 codexRaven，旧档没有＝0／−1）。
##   得魂（Game_Enemy.die 包装 gainSoulFrom，XBattler 阵亡分支调 on_enemy_death）：渡鸦在 $gameParty.members()（战斗中＝出战成员）里、
##   这个敌人没算过时，clamp(10..50, floor(12＋5×log2(1＋经验/100)))，神话 ×3、备注 <Boss>／<boss> ×10，再夹到 50；随后判铸印。
##   经验取 Game_Enemy.exp()：数据库经验 × 神话倍率（enemy_exp）。
##   铸印（awardRavenAdvanceSeal）：阶 < 5、本阶没铸过、灵魂 ≥ REQUIRE[阶＋1] → 记本阶已铸；背包没有冥羽进阶印 2901 才给一枚。
##   进阶确认（Scene_ActorAdvanced.onConfirmOk 包装，XAdvance.advance 末尾调 after_advance）：渡鸦升了一阶 → 灵魂清零、重排技能、再判铸印。
##   新局／读档时原版再判一次铸印（restoreRavenState）：重制的灵魂只在倒敌（当场判过）和进阶（清零）时变，读进来的档不会处在
##   「够了却没铸」的状态（只有 MV 旧档会，不迁移），不移植。
##   参照 mv_oracle/raven_soul_probe.cjs。
## - 招募（公共事件 9002 的 CodexRaven.recruit()）：不在队就入队；重排技能；队伍（含已装备）没有冥河断罪镰 4001 才给一件；
##   提示「渡鸦加入队伍，获得专属法宝：冥河断罪镰！」。总是返回 true。
## 第三期：战斗内机制（参照 mv_oracle/raven_battle_probe.cjs，测试 tests/xiyou_raven_battle）。
## - 神话形态 myth（_codexRavenMythTurns，只在战斗内，存在 XState.raven 但不存档）：Game_Action.apply 包装里 <CodexRavenMyth> 技能 10127
##   打到目标、学了 10127、不在形态中 → 3 回合；endTurn 减一；得魂时不到 5 回合加一；endBattle 与 setupRaven（sync）清零。
##   神话之力＝形态中且学了 10170：伤害钩子普通／黑暗伤害 +1、最终伤害 +1.5，魔防穿透 +5%（封顶 95%）。形态中战斗图换 Raven_Mythic_SV（battler_name）、逐帧图 UserSV_RavenMythic（XAppearance.sv_form）。
## - 残响 residue（_codexRavenResidue，0～3）与狩猎 hunter（_codexRavenHunter）存在 XState.raven（存档 codexRaven）：学了 10132 时得魂后 +1，
##   本回合（startTurn 起）没有敌人倒下时 endTurn 也 +1（渡鸦要在出战成员里）；学了 10133 且满 3 进入狩猎。sync 时没学 10132 清残响、没学 10133 清狩猎。
## - 追加伤害（endAction 之前，<CodexRavenDamage> 技能）：施放帧按目标累计实际 HP 伤害；狩猎中先消耗狩猎与残响，对存活目标直接扣
##   累计 ×1（神话之力 ×1.5，冥界收割）；神话之力时对仍存活的目标再扣 ×0.85（回响）。直接扣血不经伤害计算，倒下照常得魂。
## - apply 包装：鸦啄 10122 每次施放第一次命中回 floor(2% 最大 MP)（至少 1）；盛宴 10124／万魂 10126 命中时学了 10134 直接附加黑暗侵蚀 1663，
##   否则二阶的盛宴按普通附加状态（效果 21）附加。numRepeats：冥羽连葬 10123 加 floor(额外攻击次数)。
## 第四期：法宝 4001 装着时的 paramPlus（param_plus，参照 raven_artifact_probe → tests/xiyou_raven_artifact）。
## 未移植：魔法反射时原版同一行动对渡鸦自己累计伤害、行动结束对自己追加（重制反射支不记帧）；收割／回响等特效（R.Fx）、
## 熟练度上限（重制无熟练度）、战斗里实际掉落的亡魂汲取 +100%（battle_logic._roll_drops 没走 team_drop_factor，待规则车道核）、
## 插件指令 RavenAdd（冻结数据里没有事件用到；商店价格与限购字段转换器已从运行时记录导出）、表现模块（RavenSkillEffects／RavenMonsterVisual）、旧档迁移。

const ACTOR := 167
const CLASS := 165
const ARTIFACT := 4001
const HORN := 2902
const SEAL := 2901
const LEGION := 10138
const SOUL_LEDGER := 10137
const PECK := 10122
const FEATHER := 10123
const FEAST := 10124
const SOULS := 10126
const MYTH := 10127
const MYTH_PASSIVE := 10170
const RESIDUE := 10132
const HUNTER := 10133
const EMBER := 10134
const EROSION := 1663
const SKILL_GATE := {10129: [5, 0], 10130: [10, 0], 10131: [15, 0], 10123: [20, 1], 10132: [25, 0], 10124: [30, 2],
	10133: [35, 3], 10125: [40, 3], 10134: [45, 0], 10126: [50, 4], 10138: [1, 0], 10139: [55, 3],
	10127: [1, 5], 10136: [60, 5], 10170: [1, 5]}
const SKILL_COEFFICIENTS := {10122: [9, 6.9, 3.9, 2.0, 1.3, 1], 10123: [0, 6.9, 3.9, 2.0, 1.3, 1],
	10124: [0, 0, 0.39, 0.19, 0.13, 0.1], 10125: [0, 0, 0, 0.6, 0.39, 0.33], 10126: [0, 0, 0, 0, 0.19, 0.2]}
const LEGACY := [160, 311, 502, 1746]
const GROWTH := {10: 16, 15: 35, 20: 50, 25: 33, 30: 27, 35: 191, 40: 22, 45: 6, 50: 7, 55: 3, 60: 1.2, 65: 1, 70: 2.66, 75: 2.66, 80: 2.66}
const REQUIRE := [0, 3000, 12000, 35000, 80000, 150000]
const RECRUIT_TEXT := "渡鸦加入队伍，获得专属法宝：冥河断罪镰！"


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func stage(a) -> int:
	return clampi(XAdvance.rank(XState.current, ACTOR), 0, 5) if own(a) else 0


static func soul(a) -> float:
	return float(_store().get("soul", 0.0)) if own(a) else 0.0


static func _store() -> Dictionary:
	return XState.current.raven if XState.current != null else {}


static func forged() -> int:
	return int(_store().get("forged", -1))


## Game_Enemy.exp()：数据库经验 × 神话倍率（EliteEnemy）。Vitsuno_Difficulty 的难度经验倍率包在里层，被后装的 exp 改写盖掉，
## 原版这里读不到（参照：难度 2 的经验倍率是 3，敌人 3 的 exp() 仍是 40）
static func enemy_exp(e) -> int:
	return e.exp_reward()


static func soul_gain(e) -> int:
	var gain := clampi(floori(12 + 5 * log(1 + maxf(0.0, enemy_exp(e)) / 100.0) / log(2.0)), 10, 50)
	if e.elite:
		gain *= 3
	var meta: Dictionary = e.data().get("meta", {})
	if meta.has("boss") or meta.has("Boss"):
		gain *= 10
	return mini(50, gain)


## $gameParty.members()：战斗中是出战成员，战斗外是全队
static func active(a) -> bool:
	var logic = XRaceBattle.active_logic()
	return (logic.actors if logic != null else XState.current.members()).has(a)


## Game_Enemy.die 包装（只在第一次倒下时调）
static func on_enemy_death(e) -> void:
	any_death = true  # BattleManager._codexRavenAnyDeath（得魂之后设，次序无关）
	var s := XState.current
	if s == null or not s.actors.has(ACTOR) or e.has_meta("raven_soul_counted"):
		return
	var a: XActor = s.actors[ACTOR]
	if not active(a):
		return
	e.set_meta("raven_soul_counted", true)
	s.raven["soul"] = soul(a) + soul_gain(e)
	a.param_mark_dirty()
	award_seal(s, a)
	if has(a, RESIDUE):
		_add_residue(a)
	if is_myth(a) and myth_turns(a) < 5:
		s.raven["myth"] = myth_turns(a) + 1


static func can_forge(a) -> bool:
	var next := stage(a) + 1
	return own(a) and next <= 5 and forged() != stage(a) and soul(a) >= REQUIRE[next]


## awardRavenAdvanceSeal
static func award_seal(s: XState, a) -> bool:
	if not can_forge(a) or not active(a):
		return false
	s.raven["forged"] = stage(a)
	if s.item_count(SEAL) <= 0:
		s.gain_item(SEAL, 1)
	return true


## 进阶确认之后（previous 是进阶前的阶）
static func after_advance(s: XState, a, previous: int) -> void:
	if own(a) and stage(a) == previous + 1:
		s.raven["soul"] = 0.0
		sync(a)
		award_seal(s, a)


## 神话形态回合数只在战斗内（endBattle 清零），不存档
static func to_save(v: Dictionary) -> Dictionary:
	return {"soul": float(v.get("soul", 0.0)), "forged": int(v.get("forged", -1)), "residue": int(v.get("residue", 0)), "hunter": bool(v.get("hunter", false))}


static func from_save(v) -> Dictionary:
	if not v is Dictionary:
		return {}
	return {"soul": maxf(0.0, float(v.get("soul", 0.0))), "forged": int(v.get("forged", -1)),
		"residue": clampi(int(v.get("residue", 0)), 0, 3), "hunter": bool(v.get("hunter", false))}


static func progress(a) -> float:
	return clampf(soul(a) / REQUIRE[5], 0.0, 1.0)


static func unlocked(a, skill: int) -> bool:
	var gate = SKILL_GATE.get(skill)
	return gate == null or own(a) and int(a.level) >= gate[0] and stage(a) >= gate[1]


static func has(a, skill: int) -> bool:
	return unlocked(a, skill) and own(a) and a.skill_ids.has(skill)


## setupRaven（setup、levelUp 后）
static func sync(a) -> void:
	if not own(a):
		return
	for id in LEGACY + [10168]:
		a.forget_skill(id)
	var all := []
	for l in XDB.rec("Classes", CLASS).get("learnings", []):
		if int(l.get("level", 1)) <= int(a.level) and unlocked(a, int(l.skillId)):
			all.append(int(l.skillId))
	for id in a.skill_ids.duplicate():
		if (id == 10170 or (id >= 10122 and id <= 10139)) and not all.has(id):
			a.forget_skill(id)
	for id in all:
		a.learn_skill(id)
	var st := _store()
	st["myth"] = 0
	if not has(a, RESIDUE):
		st["residue"] = 0
	if not has(a, HUNTER):
		st["hunter"] = false
	a.refresh_passive()


static func setup(a) -> void:
	sync(a)


static func level_up(a) -> void:
	sync(a)


## 暴伤池、终伤池（百分数）
static func growth_pools(a) -> Array:
	var lv := clampi(int(a.level), 1, 70)
	var knots := [[1, 0, 0], [10, 20, 15], [25, 80, 60], [40, 180, 140], [55, 300, 240], [70, 500, 399]]
	for i in range(1, knots.size()):
		if lv <= knots[i][0]:
			var p: float = float(lv - knots[i - 1][0]) / (knots[i][0] - knots[i - 1][0])
			return [knots[i - 1][1] + p * (knots[i][1] - knots[i - 1][1]), knots[i - 1][2] + p * (knots[i][2] - knots[i - 1][2])]
	return [500.0, 399.0]


## initPassiveCache 包装
static func passive_cache(a, c: Dictionary) -> void:
	if own(a) and a.skill_ids.has(SOUL_LEDGER):
		var p := growth_pools(a)
		c.critHarmRi += p[0] / 100.0
		c.globalHarmRi += p[1] / 100.0


static func legion_rate(a) -> float:
	if not own(a) or not has(a, LEGION):
		return 1.0
	return [6, 10, 20, 33, 66, 99][stage(a)] / 11.0


static func skill_coefficient(a, id: int) -> float:
	if not own(a):
		return 1.0
	var rates = SKILL_COEFFICIENTS.get(id)
	return float(rates[stage(a)]) if rates != null else 1.0


## 5 个伤害技能的整条公式
static func formula(a, b, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	var base := 0.0
	match id:
		10122, 10123: base = a.mat * 78 + a.mmp * 39
		10124: base = a.mat * 798 + a.mmp * 399
		10125: base = a.mat * (3999 + 3999 * (1 - b.hp_rate()))
		10126: base = a.mat * 33333 + a.mmp * 3333
	return base * (legion_rate(a) * skill_coefficient(a, id))


static func crown_rate(a) -> float:
	if not own(a) or not has(a, 10139):
		return 1.0
	var base: float = [1, 1, 1, 1.5, 1.5, 2][stage(a)]
	var overflow := maxf(0.0, soul(a) - REQUIRE[5])
	return base * (1 + 0.06 * log(1 + overflow / REQUIRE[5]) / log(2.0)) if stage(a) >= 5 and has(a, 10136) else base


static func defense_factor(a) -> float:
	if not own(a) or not has(a, 10130):
		return 1.0
	var pierce := minf(0.90, 0.60 + 0.30 * progress(a))
	if myth_power(a):
		pierce = minf(0.95, pierce + 0.05)
	return 1.0 - pierce


static func growth_rate(a) -> float:
	if not own(a):
		return 1.0
	# 不到 10 级也按 10 级那档（原版从最小的键起步，再取不超过等级的最大键）
	var best := 10
	for k in GROWTH.keys():
		if int(a.level) >= k:
			best = maxi(best, k)
	return float(GROWTH[best])


## 冥河断罪镰 4001 装着时的 paramPlus（installNativeRavenRuntime 的 Game_Actor.paramPlus 包装；参照 raven_artifact_probe）：
## 固定 ARTIFACT_BASE_BONUS，魔攻另加 ⌊阶×50＋魂×(0.02＋阶×0.006)⌋，生命另加 ⌊阶×400＋魂×(0.04＋阶×0.008)⌋。
## 每级成长 R.ARTIFACT_LEVEL_GROWTH 与备注的 <… Param +n per Level> 相同、上限 888 同 <Max Level>，照 CP_MagicWeapon 原路算（XActor.magic_param）。
const ARTIFACT_BASE_BONUS := [350, 100, 0, 80, 150, 80, 90, 35]
## 亡魂汲取：出战时全队掉率 +100%（XMapTransfer.team_drop_factor）
const SOUL_DRAIN := 10129


static func param_plus(a, i: int, v: float) -> float:
	if not artifact_equipped(a):
		return v
	v += ARTIFACT_BASE_BONUS[i]
	if i == 4:
		v += artifact_mat_bonus(a)
	elif i == 0:
		v += artifact_hp_bonus(a)
	return v


static func artifact_mat_bonus(a) -> float:
	return floorf(stage(a) * 50 + soul(a) * (0.02 + stage(a) * 0.006)) if artifact_equipped(a) else 0.0


static func artifact_hp_bonus(a) -> float:
	return floorf(stage(a) * 400 + soul(a) * (0.04 + stage(a) * 0.008)) if artifact_equipped(a) else 0.0


static func artifact_equipped(a) -> bool:
	return own(a) and a.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == ARTIFACT and str(e.get("kind", "")) == "armor")


## 伤害钩子 raven 的帧操作（XActorDamageHooks 在宿主侧取值）
static func damage_ops(item: Dictionary, a) -> Array:
	if not own(a) or not item.get("meta", {}).has("CodexRavenDamage"):
		return []
	var p := progress(a)
	var tempered := has(a, 10131)
	var ops := [{"op": "set", "field": "mode", "value": "magical"},
		{"op": "mul", "field": "magicalDefenseRate", "value": defense_factor(a)}]
	var power := 1.0 if myth_power(a) else 0.0
	if int(item.get("damage", {}).get("elementId", 0)) == 9:
		ops.append({"op": "add", "field": "elementAdd", "element": 9, "value": ((2 + p) if tempered else 0.0) + power})
	else:
		ops.append({"op": "add", "field": "normalAdd", "value": ((1.5 + p) if tempered else 0.0) + power})
	ops.append({"op": "add", "field": "finalAdd", "value": (1.5 * minf(1.0, (stage(a) + p) / 5.0) if tempered else 0.0) + 1.5 * power})
	if has(a, 10136):
		ops.append({"op": "mul", "field": "finalMultiplier", "value": 1.1})
	ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.6 if artifact_equipped(a) else 1.0})
	ops.append({"op": "mul", "field": "settlementMultiplier", "value": crown_rate(a) * growth_rate(a)})
	return ops


## CodexRaven.recruit()
static func recruit(s: XState) -> bool:
	if not s.party.has(ACTOR):
		s.add_actor(ACTOR)
	var a := s.actor(ACTOR)
	sync(a)
	var held := s.gear.any(func(e): return e.kind == "armor" and int(e.base) == ARTIFACT)
	for id in s.party:
		held = held or s.actor(id).has_base_equip("armor", ARTIFACT)
	if not held:
		s.gain_gear("armor", ARTIFACT, 1)
	return true


## ---- 第三期：战斗内机制 ----
## BattleManager._codexRavenAnyDeath：startTurn 清，任何敌人倒下（Game_Enemy.die）置位
static var any_death := false
## 施放帧（原版记在 Game_Action 上）：行动者、鸦啄回过 MP 没有、各目标累计伤害 [目标, 伤害]、是否已结算
static var frame := {}


static func myth_turns(a) -> int:
	return int(_store().get("myth", 0)) if own(a) else 0


static func is_myth(a) -> bool:
	return myth_turns(a) > 0


## Game_Actor.battlerName 包装（在换装卡那层里面）：渡鸦战斗中神话＝Raven_Mythic_SV，否则 Raven_Normal_SV；别人照 own
static func battler_name(a, own_name: String, in_battle := true) -> String:
	if not own(a):
		return own_name
	return "Raven_Mythic_SV" if is_myth(a) and in_battle else "Raven_Normal_SV"


static func myth_power(a) -> bool:
	return is_myth(a) and has(a, MYTH_PASSIVE)


static func residue(a) -> int:
	return int(_store().get("residue", 0)) if own(a) else 0


static func hunter(a) -> bool:
	return bool(_store().get("hunter", false)) if own(a) else false


static func _add_residue(a) -> void:
	var st := _store()
	st["residue"] = mini(3, residue(a) + 1)
	if has(a, HUNTER) and int(st.residue) >= 3:
		st["hunter"] = true


static func _meta(item) -> Dictionary:
	return item.get("meta", {}) if item is Dictionary and not XBattleLogic.is_item(item) else {}


## numRepeats 包装：冥羽连葬加额外攻击次数（取整）
static func repeats(u, skill: Dictionary, n: int) -> int:
	if own(u) and int(skill.get("id", 0)) == FEATHER and not XBattleLogic.is_item(skill):
		return n + maxi(0, floori(u.attack_times_add()))
	return n


## BattleManager.startAction：每次行动一个新的 Game_Action
static func begin(u, skill) -> void:
	frame = {"user": u, "skill": skill, "peck": false, "targets": [], "handled": false}


## Game_Action.apply 包装（原 apply 之后）
static func applied(logic, u, skill: Dictionary, t, r: Dictionary, used: bool) -> void:
	var meta := _meta(skill)
	if not own(u) or meta.is_empty():
		return
	if meta.has("CodexRavenMyth") and has(u, MYTH) and not is_myth(u):
		_store()["myth"] = 3
		_fx(r, "ring")  # R.Fx.play(subject, target, 'ring')
	if not meta.has("CodexRavenDamage") or t == null:
		return
	_fx(r, "slash")  # 每次 apply 都放（R.Fx.play 'slash'，不看命中）
	var hit: bool = used and not bool(r.get("missed", false)) and not bool(r.get("evaded", false))
	var id := int(skill.get("id", 0))
	var mine: bool = not frame.is_empty() and is_same(frame.user, u)
	if id == PECK and mine and not bool(frame.peck) and hit:
		frame.peck = true
		u.mp = minf(u.mmp, u.mp + maxf(1.0, floorf(u.mmp * 0.02)))  # gainMp
		u.refresh_resources()
	if (id == FEAST or id == SOULS) and hit:
		if has(u, EMBER):
			logic._state_add(t, EROSION)
		elif stage(u) == 2 and id == FEAST and has(u, FEAST):
			logic._effect(u, t, {"code": 21, "dataId": EROSION, "value1": 1.0, "value2": 0.0}, r)  # itemEffectAddNormalState
	if mine:
		var row = null
		for x in frame.targets:
			if is_same(x[0], t):
				row = x
		if row == null:
			row = [t, 0.0]
			frame.targets.append(row)
		row[1] = float(row[1]) + maxf(0.0, float(r.get("hp", 0.0)))


## Window_SkillList.updateHelp 包装：渡鸦选中「魂簿」（10137）时说明卡换成当前存档的灵魂与进阶（toLocaleString 千分位）；别的为空
static func ledger_help(a, skill: Dictionary) -> Array:
	if not own(a) or int(skill.get("id", 0)) != SOUL_LEDGER:
		return []
	var st := stage(a)
	var seals := XState.current.item_count(SEAL) if XState.current != null else 0
	var destination := "已完成五阶；灵魂可继续积累" if st >= 5 else "本阶达" + XMenu._group(REQUIRE[mini(5, st + 1)]) + "魂得印；进阶后清零"
	return ["灵魂：" + XMenu._group(soul(a)) + "　进阶：%d/5　进阶印：%d" % [st, seals], destination]


## 战斗画面要放的渡鸦特效（XRavenFx）记在命中记录上
static func _fx(r: Dictionary, kind: String) -> void:
	if not r.has("raven_fx"):
		r["raven_fx"] = []
	r.raven_fx.append(kind)


## directDamage：gainHp(−floor(值))，不经伤害计算，倒下照常；记录的 hp 是 gainHp 的值（同原版弹出的 hpDamage，可大于剩余生命）
static func _direct(logic, t, value: float, kind: String) -> Array:
	if t == null or t.is_dead() or value <= 0.0:
		return []
	var amount := floorf(value)
	logic.gain_hp(t, -amount)
	var logs := [{"type": "regen", "target": t, "hp": amount, "raven": kind, "views": logic.views([t])}]
	if t.is_dead():
		logs.append({"type": "collapse", "target": t, "views": logic.views([t])})
	return logs


## BattleManager.endAction 包装（原 endAction 之前）：冥界收割与回响
static func finish(logic, u, skill) -> Array:
	var logs := []
	if frame.is_empty() or bool(frame.handled) or not is_same(frame.user, u) or not own(u) or not _meta(skill).has("CodexRavenDamage"):
		return logs
	frame.handled = true
	var st := _store()
	var hunting := hunter(u) and has(u, HUNTER)
	if hunting:
		st["hunter"] = false
		st["residue"] = 0
	for row in frame.targets:
		var t = row[0]
		var base: float = row[1]
		if t == null or t.is_dead() or base <= 0.0:
			continue
		if hunting:
			logs.append_array(_direct(logic, t, base * (1.5 if myth_power(u) else 1.0), "harvest"))
		if myth_power(u) and not t.is_dead():
			logs.append_array(_direct(logic, t, base * 0.85, "echo"))
	return logs


## BattleManager.startTurn 包装
static func start_turn() -> void:
	any_death = false


## BattleManager.endTurn 包装（原 endTurn 之前）：本回合没有敌人倒下时残响 +1；神话形态减一回合
static func end_turn(logic) -> void:
	var s: XState = logic.state
	if s == null or not s.actors.has(ACTOR):
		return
	var a: XActor = s.actors[ACTOR]
	if not active(a):
		return
	if not any_death and has(a, RESIDUE):
		_add_residue(a)
	if is_myth(a):
		s.raven["myth"] = myth_turns(a) - 1


## BattleManager.endBattle 包装：神话形态只在当前战斗
static func end_battle(s: XState) -> void:
	if s != null:
		s.raven["myth"] = 0
	frame = {}
