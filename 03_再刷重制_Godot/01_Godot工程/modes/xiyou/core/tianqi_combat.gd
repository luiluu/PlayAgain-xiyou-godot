class_name XTianqiCombat
extends RefCounted
## 【cc·天启篇·未经审查】天启篇第三批：把五档难度与档位数值表（XTianqiBalance）接进战斗。只对天启篇存档（XTianqi.active）生效，原版档不变。
##
## 怎么接（数值重构方案第三～六节、天启篇数值测算）：
## - 基准：五档在数值上都按「艰险」跑，艰险借原版「普通」难度（Vitsuno 难度 3：敌人能力倍率、普通难度被动、难度适应），
##   开局见 XTianqi.opening_commands（XTianqi.UNIFIED_LEGACY）。原版各难度自带的倍率（敌人血量 ×75～×750、结算伤害 ×3／×1.5、难度适应 ×5）
##   彼此差得太远，不叠在新表上。
## - 敌人：在基准倍率上再乘表里本档的敌人血量（mhp）、敌人攻击（atk、mat）；其余能力照基准。
## - 我方出伤：档位出伤（读攻击者档位）、本档我方伤害系数、上场弱者协力、助力位光环，四项各成一个乘区，只乘一次；只算角色打出的伤害。
## - 我方承伤：档位承伤（读目标档位）、上场弱者协力承伤，只算打到角色身上的伤害。
## - 治疗、吸收不乘。
## 开关（O-278）：ENABLED＝false 回到第二批的做法（五档各借一档原版难度、伤害不读档位表）。

static var ENABLED := true


## 这份存档按天启篇数值跑
static func on(s = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and XTianqi.active(s)


## 天启篇常驻战斗规则（balance_table.json 的 combat_rules：暴击率 ＋50%、战斗中敏捷 ×0.8，伤害加成总账期二从「难度被动等价」挪来，数不变）
static func combat_rule(key: String, fallback := 0.0) -> float:
	var t = XTianqiBalance.data().get("combat_rules", {})
	return float(t.get(key, fallback)) if t is Dictionary else fallback


## 本档数值行（XTianqiBalance.difficulty 拍平的一行）；不是天启篇存档为空
static func row(s = null) -> Dictionary:
	if s == null:
		s = XState.current
	if not on(s):
		return {}
	return XTianqiBalance.difficulty(str(s.flags.tianqi.get("difficulty", "")))


# ---- 敌人 ----

## 敌人倍率的基准难度号：本档开局借的原版难度（XTianqi.legacy_of）
static func base_legacy(s = null) -> int:
	if s == null:
		s = XState.current
	return XTianqi.legacy_of(str(s.flags.tianqi.get("difficulty", "")))

## 敌人八项能力倍率（mhp, mmp, atk, def, mat, mdf, agi, luk）。天启篇：基准难度的倍率，mhp 乘敌人血量，atk、mat 乘敌人攻击；否则照原版传进来的难度。
## 基准难度跟本档开局借的原版难度走（XTianqi.legacy_of）：UNIFIED_LEGACY 开着时五档都是普通，关掉时各档借各自的原版难度，
## 和开局一致，两个开关能各自回退（审查 79 P3-1）。
static func enemy_rates(difficulty: int, s = null) -> Array:
	if s == null:
		s = XState.current
	var r := row(s)
	if r.is_empty():
		return XEnemy.difficulty_rates(difficulty)
	var out := XEnemy.difficulty_rates(base_legacy(s))
	var dt := dungeon_tier(s)
	out[0] = float(out[0]) * float(r.enemy_hp) * float(dt.get("enemy_hp", 1.0)) * XTianqiNoX6.hp_unit(s)  # 去全队 ×6：敌人生命同缩 1/6（O-470）
	out[2] = float(out[2]) * float(r.enemy_atk) * float(dt.get("enemy_atk", 1.0))
	out[4] = float(out[4]) * float(r.enemy_atk) * float(dt.get("enemy_atk", 1.0))
	return out


## 开关（O-411，Kyo 11-13「副本档位也跟着变强」）：true＝副本里敌人血量、攻击再乘副本档系数（balance_table 的 dungeon_tiers，draft）；
## false＝副本里和塔里一样只看本档难度
static var DUNGEON_TIER := true


## 在副本里时本副本所选档（变量 450）的系数 {enemy_hp, enemy_atk}；不在副本、开关关着为空
static func dungeon_tier(s: XState) -> Dictionary:
	if not DUNGEON_TIER or s == null or not XDungeon.inside(s):
		return {}
	return XTianqiBalance.dungeon_tier(int(s.variable(XDungeon.VAR_TIER)))


# ---- 我方 ----

## 出战栏上场格（前 4 格）里的弱者人数。直接读出战栏，不走 battle_members（那里每次都整理队伍，伤害结算里调太重）。
static func field_weak_count(s: XState) -> int:
	var n := 0
	for i in mini(XTianqi.FIGHTERS, s.battle_slots.size()):
		var id := int(s.battle_slots[i])
		if id > 0 and s.party.has(id) and XTianqiSkills.is_weak(id, true):  # 弱者协力按名单（成长型角色按名单档算）
			n += 1
	return n


static func has_helper(s: XState) -> bool:
	return s.battle_slots.size() > XTianqi.HELPER_SLOT and int(s.battle_slots[XTianqi.HELPER_SLOT]) > 0 \
		and s.party.has(int(s.battle_slots[XTianqi.HELPER_SLOT]))


static func _is_party_actor(x, s: XState) -> bool:
	return x != null and x.is_actor() and x is XActor and s.party.has(int((x as XActor).actor_id))


## 角色打出的伤害要乘的倍率（档位出伤 × 我方伤害 × 弱者协力 × 助力位光环）；返回 {mult, tier, party, assist, aura}
static func dealt_parts(a, s = null) -> Dictionary:
	if s == null:
		s = XState.current
	var r := row(s)
	if r.is_empty() or not _is_party_actor(a, s):
		return {"mult": 1.0}
	var tier := XTianqiBalance.tier_damage_mult(XTianqiSkills.battle_tier(a, s))
	var party := float(r.party_damage)
	var assist := 1.0 + float(XTianqiBalance.assist_bonus(field_weak_count(s)).damage_dealt)
	var aura := 1.0 + (XTianqiBalance.assist_slot_aura() if has_helper(s) else 0.0)
	var scale := XTianqiMoney.scale_dealt_mult(s)  # 天平「酒」
	var k := XTianqiBase.k_for(a, s)  # 期四 K「天启注视」（总开关关着 1）
	return {"mult": tier * party * assist * aura * scale * k, "tier": tier, "party": party, "assist": assist, "aura": aura, "scale": scale, "k": k}


## 打到角色身上的伤害要乘的倍率（档位承伤 × 弱者协力承伤）
static func taken_parts(b, s = null) -> Dictionary:
	if s == null:
		s = XState.current
	if row(s).is_empty() or not _is_party_actor(b, s):
		return {"mult": 1.0}
	var tier := XTianqiBalance.tier_taken_mult(XTianqiSkills.battle_tier(b, s))
	var assist := 1.0 + float(XTianqiBalance.assist_bonus(field_weak_count(s)).damage_taken)
	var scale := XTianqiMoney.scale_taken_mult(s)  # 天平「油」
	return {"mult": maxf(0.0, tier * assist * scale), "tier": tier, "assist": assist, "scale": scale}


## 伤害结算用：攻击者 a 打目标 b 的天启篇倍率（出伤 × 承伤）。不是天启篇存档恒 1。
static func damage_mult(a, b) -> float:
	var s := XState.current
	if not on(s):
		return 1.0
	return float(dealt_parts(a, s).mult) * float(taken_parts(b, s).mult) * XTianqiHorsemen.taken_mult(b)  # 天启四骑士：混子减伤、嘲讽削伤


# ---- 敌人暴击闪避（T285，D237 丙：首领暴击闪避评估 v0.2 第二节丙、第五节草稿卡） ----
## 开关：true＝天启篇敌人闪避、暴击、暴击闪避、魔法闪避（xparam 1～4）里，表上有上限（≥0）的项拆成「底子」和「我方减益」两块，
## 都不再乘仓库倍率（天启篇开局 DCultyL3 的 ×2，D237 丙「去 ×2」）：底子（数据特性＋敌人身上的正值状态特性）按 balance_table 的
## combat_rules.enemy_xparam_cap 夹上限（暴击闪避按层段×难度查表），原值低于上限的照原值；我方减益（负值状态特性）加在夹完的底子上；
## 再扣词条「压制」；最后不低于 0。上限填 -1 的项（现在 eva／cri／mev）一律照原路，逐字节不变（r2 P1-1）。
## false＝照旧：底子＋减益一起乘仓库倍率，不封顶、不夹 0。西游存档不走这里。
static var ENEMY_XPARAM_CAP := true
## 开关：true＝天启篇里我方打敌人的暴击率改成减法（面板暴击＋critPush − 有效暴击闪避，夹 0～1，对齐指引「暴击率还要减去敌人的暴击闪避」）；
## false＝退回原版乘法 暴击×(1−暴击闪避)。只管目标是敌人的；敌人打我方、我方打我方照旧乘法。
static var SUBTRACTIVE_CEV := true


static func cap_on() -> bool:
	return ENEMY_XPARAM_CAP and on()


## 开关（T332，D249 乙）：true＝天启篇敌人回合末 HP 再生合计为负（灼伤等百分比掉血）时，hrg 与恢复效果率 rec 都不乘仓库倍率
## （天启篇开局 DCultyL3 的 ×2；原版两处各乘一次，floor(mhp×hrg×rec) 叠成 ×4，灼伤 V −5% 变 −20%，T327）。
## 只改 BattleLogic._regenerate 的负再生这一路：正再生、pdr／mdr、恢复效果对治疗的倍率、面板读的 hrg／rec 都照旧。
## false＝照原版 ×4。西游存档不走这里。
static var DOT_NO_WAREHOUSE := true


static func regen_unscaled() -> bool:
	return DOT_NO_WAREHOUSE and on()


## combat_rules.enemy_xparam_cap 整张表（读不到为空）
static func xparam_cap_table() -> Dictionary:
	var t = XTianqiBalance.data().get("combat_rules", {})
	var c = t.get("enemy_xparam_cap", {}) if t is Dictionary else {}
	return c if c is Dictionary else {}


## 敌人所在层：守层者按敌群定层（鸿钧 34）；骑士、援军、七印里副本、七首之龙 0；别的敌人取楼层缩放时记下的层，再不行取当前地图的层
static func enemy_floor(e) -> int:
	var f := XGuardianRework.params_floor(e)
	if f > 0 or not e.horseman.is_empty():
		return f
	f = int(e.get_meta(META_KEEP_FLOOR, 0))  # 守层者变身前记下的层（keep_floor）
	if f > 0:
		return f
	f = int(e.get_meta(XGuardianRework.META_FLOOR, 0))
	if f > 0:
		return f
	var s := XState.current
	return XDungeon.map_floor(s.map_id) if s != null else 0


const META_KEEP_FLOOR := "t285_floor"


## BattleLogic.enemy_transform 换身份前调：守层者（按敌群定层）变成别的敌人号后记住原层（只记一次；不用 XGuardianRework.META_FLOOR，免得动到守层者出伤、减伤那几张表）
static func keep_floor(e) -> void:
	if not cap_on() or e.has_meta(META_KEEP_FLOOR) or not e.horseman.is_empty():
		return
	var f := XGuardianRework.params_floor(e)
	if f > 0:
		e.set_meta(META_KEEP_FLOOR, f)


## 第 i 项底子上限（整数百分比，-1＝不封顶）。暴击闪避：cev_tiers 第一行 max_floor ≥ 所在层的那行，按本档难度取；
## 层数 0（骑士、七印、七首之龙等）按第一行；超过最后一行按最后一行
static func xparam_cap_pct(e, i: int) -> int:
	var t := xparam_cap_table()
	match i:
		1:
			return int(t.get("eva", -1))
		2:
			return int(t.get("cri", -1))
		4:
			return int(t.get("mev", -1))
		3:
			var tiers: Array = t.get("cev_tiers", [])
			if tiers.is_empty():
				return -1
			var f := enemy_floor(e)
			var row: Dictionary = tiers[tiers.size() - 1]
			for r in tiers:
				if f <= int(r.get("max_floor", 0)):
					row = r
					break
			var caps = row.get("cap", -1)
			if caps is Dictionary:
				var s := XState.current
				var key := str(s.flags.tianqi.get("difficulty", "")) if s != null else ""
				return int(caps.get(key, caps.values().min() if not caps.is_empty() else -1))
			return int(caps)
	return -1


## 免暴击标记（T285 r3）：敌人身上 set_meta(META_CRIT_IMMUNE, true) 就免暴击。和死亡骑士 crit_immune、七印魔塔 no_crit 一样
## 在 battle_logic.item_cri 最前面拦，不经暴击闪避，所以不受底子封顶（ENEMY_XPARAM_CAP）、减法（SUBTRACTIVE_CEV）影响。
## 用暴击闪避特性（如 +1000%）做免暴击在天启篇不再成立：那是底子，会按层段封顶（D237 丙）。现在只有木桩标尺（c_tier）挂它。
const META_CRIT_IMMUNE := "t285_crit_immune"


static func crit_immune(dt) -> bool:
	return dt != null and dt.has_meta(META_CRIT_IMMUNE) and bool(dt.get_meta(META_CRIT_IMMUNE))


## 天启篇敌人 xparam 1～4（cap_on 时 XEnemy.xparam 调）。base_pct：底子夹完上限后再乘的整数百分比（甚尔五感 50，平时 100）
static func enemy_xparam(e, i: int, base_pct := 100) -> float:
	var parts: Array = e.xparam_parts(i)
	var base: float = float(parts[0])  # 去仓库 ×2（D237 丙，r2 P1-2）：原值低于上限的照原值
	var cap := xparam_cap_pct(e, i)
	if cap >= 0:
		base = minf(base, float(cap) / 100.0)
	if base_pct != 100:
		base = base * float(base_pct) / 100.0
	var v := XTianqiAffixBattle.enemy_xparam(e, i, base + float(parts[1]))  # 天启篇词条「压制」
	return maxf(0.0, v)


## itemCri 里「暴击率 × 目标暴击闪避」那一步（battle_logic.item_cri 调）。rate：攻击方暴击＋critPush。
## 不是天启篇存档（或两个开关都关）时照原版：max(rate,0)×(1−暴击闪避×甚尔系数)
static func crit_after_cev(rate: float, u, skill: Dictionary, dt) -> float:
	var k := XToji.cev_rate(u, skill)
	if not (ENEMY_XPARAM_CAP or SUBTRACTIVE_CEV) or not on():
		return maxf(rate, 0.0) * (1.0 - dt.cev * k)
	var cev: float
	if k < 1.0 and XToji.TIANQI_CEV_HALF and dt is XEnemy and cap_on() and xparam_cap_pct(dt, 3) >= 0:
		cev = (dt as XEnemy).cev_for_toji(int(xparam_cap_table().get("toji_cev_pct", 50)))  # 甚尔五感：底子减半，再扣队友的降暴击闪避
	else:
		cev = dt.cev * k
	if SUBTRACTIVE_CEV and dt is XEnemy:
		return maxf(rate - cev, 0.0) if rate > 0.0 else 0.0  # 攻击方这一项 ≤0 时按 0 算、不再减（installCritFloor 口径，同乘法 0×任何数＝0）：封顶关着时负暴击闪避也不负负得正（r2 P3-1）
	return maxf(rate, 0.0) * (1.0 - cev)
