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
	out[0] = float(out[0]) * float(r.enemy_hp) * float(dt.get("enemy_hp", 1.0))
	out[2] = float(out[2]) * float(r.enemy_atk) * float(dt.get("enemy_atk", 1.0))
	out[4] = float(out[4]) * float(r.enemy_atk) * float(dt.get("enemy_atk", 1.0))
	return out


## 开关（O-待定-7，Kyo 11-13「副本档位也跟着变强」）：true＝副本里敌人血量、攻击再乘副本档系数（balance_table 的 dungeon_tiers，draft）；
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
	return {"mult": tier * party * assist * aura, "tier": tier, "party": party, "assist": assist, "aura": aura}


## 打到角色身上的伤害要乘的倍率（档位承伤 × 弱者协力承伤）
static func taken_parts(b, s = null) -> Dictionary:
	if s == null:
		s = XState.current
	if row(s).is_empty() or not _is_party_actor(b, s):
		return {"mult": 1.0}
	var tier := XTianqiBalance.tier_taken_mult(XTianqiSkills.battle_tier(b, s))
	var assist := 1.0 + float(XTianqiBalance.assist_bonus(field_weak_count(s)).damage_taken)
	return {"mult": maxf(0.0, tier * assist), "tier": tier, "assist": assist}


## 伤害结算用：攻击者 a 打目标 b 的天启篇倍率（出伤 × 承伤）。不是天启篇存档恒 1。
static func damage_mult(a, b) -> float:
	var s := XState.current
	if not on(s):
		return 1.0
	return float(dealt_parts(a, s).mult) * float(taken_parts(b, s).mult) * XTianqiHorsemen.taken_mult(b)  # 天启四骑士：混子减伤、嘲讽削伤
