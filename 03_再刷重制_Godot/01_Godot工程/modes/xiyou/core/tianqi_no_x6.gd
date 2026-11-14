class_name XTianqiNoX6
extends RefCounted
## 【cc·天启篇·未经审查】数值线第一步：去掉难度被动折成的全队 ×6（天启篇设计总览 v0.4 第六节 A2，Kyo 11-14 定；方案见交付单 cc_tianqi-no-x6）。
## 只对天启篇存档（XTianqi.active）生效，西游档一个字不改。
##
## ×6 原来只有一处：XTianqiNoDiffPassive.confirm_rows 在攻击方确认阶段替三个难度被动插 ×1.5、×5、×0.8（legacy_passive.settle）。
## 本功能开着时（ENABLED，O-待定-1）：
## - HP 伤害、HP 吸取（类型 1、5）不再插这三步：我方输出 ÷6。MP 伤害照旧 ×6、HP／MP 回复照旧 ×5（我方治疗绝对值不变，
##   留到数值线第 4 步并进技能预算）。合成行带 skipTypes，XStateEffects._active 认它；三步本来就不掷随机数，同一种子随机流不变。
## - 敌人生命 ×hp_unit()（＝1/6）：XTianqiCombat.enemy_rates 管走难度倍率的敌人，XGuardianRework.hp_base 管按绝对值重标的
##   守层者、楼层敌群、七印里副本、鸿钧（两处互相约掉，所以两处都乘）。骑士、援军、影子、七首之龙按数值测算定（本来不含 ×6），不动。
## - 固定减伤（伤害抵抗 harmRe、种族减免、扣过穿透之后）在攻击方是天启篇角色时 ×hp_unit()：max(0, x－F/6)＝max(0, 6x－F)/6，和原来等价。
## - 我方吸取回血、YEP 吸血、词条吸血按 ×6 前的伤害算（steal_mult）。
## - 敌人回血：绝对值回复（公式不读 mhp 的技能回复、吸取回血、吸血、元素吸收）×1/6（heal_scale）；GUARDIAN_HEAL（O-待定-2）开着时，
##   按敌人自己能力值算的技能回复再乘守层者重算的血量缩放比 k（守层者、楼层敌群、七印里副本、鸿钧；例 26 层清心咒 450＋魔攻×1000）。
## - 五条悟试炼影子生命的 settle 改读 settle_product()（开 1、关 6）。
## - 绕过确认阶段直接扣敌人血的我方效果：按目标生命百分比的不动；按绝对值的逐条见交付单分类表（scale_direct）。
## 开关只在代码里，不写存档，老档读进来下一场起按新数；关掉＝回到 ×6 和原血量。

static var ENABLED := true
## O-待定-2：守层者等按绝对值重标血量的敌人，回血跟着血量缩放比同比缩（Kyo 11-14 协调批，默认开）
static var GUARDIAN_HEAL := true

## 敌人记下的守层者重算血量缩放比（XGuardianRework._scale_hp 累乘）
const META_HP_K := "xgr_hp_k"


## 依赖 O-421（XTianqiNoDiffPassive）：那个关掉时三个难度被动是真状态、照旧 ×6，这里跟着关，免得只缩了敌人血量
static func on(s = null) -> bool:
	if not ENABLED or not XTianqiNoDiffPassive.ENABLED:
		return false
	if s == null:
		s = XState.current
	return s != null and XTianqi.active(s)


## 原来 settle 里正伤害三步的乘积（1.5×5×0.8＝6）
static func settle_product() -> float:
	var p := 1.0
	for row in XTianqiNoDiffPassive.table().get("settle", []):
		if str(row.get("cond", "")) in ["positive", "nonzero"]:
			p *= float(row.get("k", 1.0))
	return p


## 开着时敌人生命、固定减伤的缩放（1/6）；关着 1
static func hp_unit(s = null) -> float:
	if not on(s):
		return 1.0
	var p := settle_product()
	return 1.0 / p if p > 0.0 else 1.0


## 天启篇我方角色（持有过三个难度被动的一方）
static func party_actor(x) -> bool:
	return x != null and x is XActor and XState.current != null and XState.current.party.has(int((x as XActor).actor_id))


## 合成行（XTianqiNoDiffPassive.confirm_rows）要带的类型过滤：开着时 HP 伤害、HP 吸取不乘
static func skip_types() -> Array:
	return [1, 5] if on() else []


## 攻击方是天启篇角色时固定减伤的缩放
static func flat_unit(a) -> float:
	return hp_unit() if party_actor(a) else 1.0


## 我方吸取、吸血按 ×6 前的伤害算
static func steal_mult(u) -> float:
	if not party_actor(u) or not on():
		return 1.0
	return settle_product()


## 敌人回血的缩放（甲）：本功能开着 ×1/6。with_k（只给按敌人自己能力值算的技能回复用）且 GUARDIAN_HEAL 开着时，
## 再乘守层者重算记下的血量缩放比 k——那类公式是原版敌人数值的口径，血量缩了 k 倍它没缩。
## 元素吸收、吸取、吸血的回血量来自伤害（我方伤害、按层重算过的守层者出伤），已经是新口径，只乘 1/6。
static func heal_scale(e, with_k := false) -> float:
	if not e is XEnemy or not on():
		return 1.0
	var en := e as XEnemy
	if not en.horseman.is_empty() and not en.horseman.get("rec", {}).has("_ref"):
		return 1.0   # 骑士、援军、影子、七首之龙、五条悟影子：天启篇自己的数值，不缩
	var k := hp_unit()
	if with_k and GUARDIAN_HEAL:
		k *= float(en.get_meta(META_HP_K, 1.0))
	return k


## 敌人给敌人的技能回复（XDamage._healing）：公式读 mhp 的是按生命百分比，已经跟着血量缩了，不动
static func enemy_heal(item: Dictionary, a, b) -> float:
	if not a is XEnemy or not b is XEnemy:
		return 1.0
	if str(item.get("damage", {}).get("formula", "")).contains("mhp"):
		return 1.0
	return heal_scale(b, true)


## 吸取（类型 5）给攻击方的回血：我方按 ×6 前算，敌人跟血量同缩
static func drain_gain(u, value: float) -> float:
	if value <= 0.0:
		return value
	return value * steal_mult(u) * heal_scale(u)


## 绕过确认阶段、按绝对值直接扣敌人血的我方效果（分类表里标「缩」的）：缩了才向下取整、至少 1；不缩原样返回
static func scale_direct(u, t, value: float) -> float:
	if value <= 0.0 or not t is XEnemy or not party_actor(u) or not on():
		return value
	return maxf(1.0, floorf(value * hp_unit()))
