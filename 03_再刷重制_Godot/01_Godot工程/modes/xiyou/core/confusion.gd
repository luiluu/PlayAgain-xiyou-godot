class_name XConfusion
extends RefCounted
## 混乱类状态（restriction 1～3：愤怒 7／2504、混乱 8／124／2505、魅惑 9／1045／2506 等 13 个）。
## 原版 Game_BattlerBase.isConfused：restriction 在 1～3 之间（≥4 是不能行动）；confusionLevel 就是这个数。参照 mv_oracle/confusion_probe.cjs
## （夹具 tests/fixtures/confusion_oracle.json，专项 tests/xiyou_confusion.gd），量到的规则：
## - 可以行动，状态回合数照常（行动结束 -1），不能输入（canInput 假：角色没有指令窗，OTB 直接 startAction）。
## - 行动内容：敌人 processTurn 的 Game_Action.prepare 把技能换成普通攻击（行动选择的随机数照取，换在其后）；
##   角色 makeActions 里 makeConfusionActions 也是普通攻击，但自动战斗（挂机、自动战斗特性）优先：isAutoBattle 时保留自动选的技能，
##   startOTBInput 不走 prepare，只有目标走混乱。强制行动（forceAction）整个绕过混乱。
## - 目标（YEP_WeaponUnleash makeConfusionTargets 在最外层，Custom Target Eval 不走）：
##   · 单体（scope 非 2／8／10，含随机、自己）：1 级＝对方随机一个；2 级＝掷 randomInt(2)，0 对方、1 己方，再在那一方随机一个；3 级＝己方随机一个（含自己）。
##   · 全体（scope 2／8／10）：1 级＝对方全部存活；2 级＝掷 randomInt(2)，0 对方全部、1 己方全部；3 级＝己方全部存活，不掷随机数。
##   随机一个按 tgr 加权，只在存活者里挑（量过：已倒下的人不会被选中）。
## 原版疑似缺陷（照原版做，不改）：魅惑（3 级）和混乱的己方一侧可以选到行动者自己（己方随机含自己）。

const MAX_LEVEL := 3
const ALL_SCOPES := [2, 8, 10]

## 行动者此刻的混乱等级（0＝没有）。restriction ≥4 是不能行动，不算混乱
static func level(b: XBattler) -> int:
	if b == null or not b.is_alive():
		return 0
	var r := 0
	for s in b.states():
		r = maxi(r, int(s.restriction))
	return r if r >= 1 and r <= MAX_LEVEL else 0

static func confused(b: XBattler) -> bool:
	return level(b) > 0

## 敌人 Game_Action.prepare：行动被换成普通攻击；没有行动（null）保持没有
static func prepare_enemy(b: XBattler, decision: Array) -> Array:
	if decision[0] == null or not confused(b):
		return decision
	return [b.attack_skill(), null]

## Game_Action.confusionTarget／WUL makeConfusionTargets 的目标列表
static func targets(logic, a: XBattler, skill: Dictionary) -> Array:
	var foes: Array = logic.enemies if a.is_actor() else logic.actors
	var friends: Array = logic.actors if a.is_actor() else logic.enemies
	var lv := level(a)
	var side: Array
	match lv:
		1:
			side = foes
		2:
			side = foes if logic._int(0, 1, "confusion") == 0 else friends
		_:
			side = friends
	var pool: Array = logic.alive(side)
	if ALL_SCOPES.has(int(skill.get("scope", 1))):
		return pool
	return [logic._random_target(pool)] if not pool.is_empty() else []
