class_name XActorModules
extends RefCounted
## 专属角色模块（167～177）在 XActor 上的公共挂点：XActor 只调这里，这里按角色分派到各模块。
## - setup：Game_Actor.setup 包装（XActor.setup 末尾）
## - can_learn：Game_Actor.learnSkill 包装（XActor.learn_skill 开头；false 就不学）
## - level_up：Game_Actor.levelUp 包装（XActor._level_up 末尾）


static func setup(a) -> void:
	XGarou.setup(a)


static func can_learn(a, id: int) -> bool:
	return XGarou.can_learn(a, id)


static func level_up(a) -> void:
	XGarou.level_up(a)
