class_name XActorModules
extends RefCounted
## 专属角色模块（167～177）在 XActor 上的公共挂点：XActor 只调这里，这里按角色分派到各模块。
## 不在 IDS 里的角色走快速路径（直接返回／原值），行为与没有挂点时完全一样。沙僧改 actor.gd 时请保留这些挂点。
## 各挂点对应原版包的哪一层：
## - setup：Game_Actor.setup 包装（XActor.setup 末尾）——饿狼 G.sync＋recoverAll、渡鸦 setupRaven。
## - can_learn：Game_Actor.learnSkill 包装（XActor.learn_skill 开头；false 就不学）——只有饿狼包了 learnSkill
##   （10265～10269 未到形态／等级不学），所以事件学技能、技能共享／羁绊／领袖、进阶学技能也一样被挡。
##   渡鸦没包 learnSkill，只在 setup／levelUp 后重排（setupRaven），不放这里。
## - level_up／level_down：Game_Actor.levelUp／levelDown 包装（XActor._level_up 末尾、change_level_mv 逐级降级处）——
##   饿狼两个都包（G.sync），渡鸦只包 levelUp。原版 changeLevel／changeExp 都是逐级走 levelUp／levelDown。
## - level_changed：XActor.change_level（读档、测试夹具直接设等级）结束时，按升降调一次 level_up／level_down 等价的同步。
## - param／xparam：Game_Actor.param／xparam 包装（v 是包装前的值）——米拉 param、MiraRavenNumberBoost xparam(2)。
## - passive_cache：initPassiveCache 包装（XActor.refresh_passive 写回缓存前）——渡鸦魂海刻度。

const IDS := [167, 168, 173]


static func _module(a) -> bool:
	return a is XActor and IDS.has(int(a.actor_id))


static func setup(a) -> void:
	if not _module(a):
		return
	XGarou.setup(a)
	XRaven.setup(a)


static func can_learn(a, id: int) -> bool:
	return not _module(a) or XGarou.can_learn(a, id)


static func level_up(a) -> void:
	if not _module(a):
		return
	XGarou.level_up(a)
	XRaven.level_up(a)


static func level_down(a) -> void:
	if not _module(a):
		return
	XGarou.level_up(a)  # G.sync 同样挂在 levelDown


static func level_changed(a, before: int) -> void:
	if not _module(a) or int(a.level) == before:
		return
	if int(a.level) > before:
		level_up(a)
	else:
		level_down(a)


static func param(a, i: int, v: float) -> float:
	return XMira.param(a, i, v) if _module(a) else v


static func xparam(a, i: int, v: float) -> float:
	return XNumberBoost.xparam(a, i, v) if _module(a) else v


static func passive_cache(a, c: Dictionary) -> void:
	if _module(a):
		XRaven.passive_cache(a, c)
