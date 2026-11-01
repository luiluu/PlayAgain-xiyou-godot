class_name XActorModules
extends RefCounted
## 专属角色模块（167～177）在 XActor 上的公共挂点：XActor 只调这里，这里按角色分派到各模块。
## 不在 IDS 里的角色走快速路径（直接返回／原值），行为与没有挂点时完全一样。沙僧改 actor.gd 时请保留这些挂点。
## 各挂点对应原版包的哪一层：
## - setup：Game_Actor.setup 包装（XActor.setup 末尾）——饿狼 G.sync＋recoverAll、渡鸦 setupRaven、宿傩 S.sync、甚尔 repair、谷雨 syncSkills。
## - can_learn：Game_Actor.learnSkill 包装（XActor.learn_skill 开头；false 就不学）——只有饿狼包了 learnSkill
##   （10265～10269 未到形态／等级不学），所以事件学技能、技能共享／羁绊／领袖、进阶学技能也一样被挡。
##   渡鸦没包 learnSkill，只在 setup／levelUp 后重排（setupRaven），不放这里。
## - level_up／level_down：Game_Actor.levelUp／levelDown 包装（XActor._level_up 末尾、change_level_mv 逐级降级处）——
##   饿狼两个都包（G.sync），渡鸦只包 levelUp。原版 changeLevel／changeExp 都是逐级走 levelUp／levelDown。
##   宿傩包 levelUp 与 changeLevel（不包 levelDown）：重制在 levelDown 挂点逐级同步（同步只看当时等级与进阶，与降完再同步
##   一次结果相同）；差别只在 changeExp 直接扣经验降级时原版不同步，重制会同步。
## - level_changed：XActor.change_level（读档、测试夹具直接设等级）结束时，按升降调一次 level_up／level_down 等价的同步
##   （同级按升级调：change_level 会补学职业习得表，要再同步一次）。
## - 渡鸦／米拉另有 CodexSkillProgression（XSkillProgression）：setup、levelUp、changeLevel 后按解锁等级／阶位学忘专属技能。
## - param／xparam：Game_Actor.param／xparam 包装（v 是包装前的值）——米拉 param、MiraRavenNumberBoost xparam(2)、
##   宿傩二十指 param ×3 与 xparam(0／2)、黄泉 param(2)＋幸运×1.88 与 xparam(2)＋9.99、甚尔天与咒缚／暴君／血铠／大力 param 与暴君 xparam(2)。
## - param_rate：Game_Actor.paramRate 包装（XActor.param_rate 末尾乘上）——饿狼形态能力倍率。
## - equip_changed：Game_Actor.changeEquip 包装（XEquipment.change 末尾）——饿狼 G.sync（法宝进化）。
## - param_plus：Game_Actor.paramPlus 包装（XActor._param_plus 末尾）——黄泉 10176／10177／10182。
## - action_plus_set：Game_Actor.actionPlusSet 包装（XActor.action_plus_set 末尾，往数组里追加）——黄泉 10175 追加 1。
## - param_base：Game_Actor.paramBase 包装（XActor.param_base 末尾）——镜流星魂 20／40 级最大生命、35 级攻击各再加一份。
## - passive_cache：initPassiveCache 包装（XActor.refresh_passive 写回缓存前）——渡鸦魂海刻度、宿傩十指／二十指终伤与暴伤、甚尔暴君终伤与暴伤、
##   云裳云丝展幅的暴伤／终伤与织神天梭终伤（原版包的是 refreshPassiveCache，按差值增减，与每次重算后加上等价）。
## - 云裳 174（XYunshang）：setup、levelUp、changeLevel 后 Y.sync；param 最大生命／魔攻／敏捷按等级与进阶的倍率。

const IDS := [167, 168, 169, 170, 171, 172, 173, 174, 175]


static func _module(a) -> bool:
	return a is XActor and IDS.has(int(a.actor_id))


static func setup(a) -> void:
	if not _module(a):
		return
	XGarou.setup(a)
	XRaven.setup(a)
	XSkillProgression.sync(a)
	XSukuna.sync(a)
	XToji.repair(a)
	XYomiJingliu.setup(a)  # 镜流 normalizeJingliuSkills
	XYunshang.sync(a)  # 云裳 Y.sync
	XGuyu.sync(a)  # 谷雨 setup 包装：syncSkills


static func can_learn(a, id: int) -> bool:
	return not _module(a) or XGarou.can_learn(a, id)


static func level_up(a) -> void:
	if not _module(a):
		return
	XGarou.level_up(a)
	XRaven.level_up(a)
	XSkillProgression.sync(a)
	XSukuna.sync(a)
	XYunshang.sync(a)  # 云裳包的是 levelUp 与 changeLevel
	XGuyu.sync(a)  # 谷雨 levelUp／changeLevel 包装：syncSkills


static func level_down(a) -> void:
	if not _module(a):
		return
	XGarou.level_up(a)  # G.sync 同样挂在 levelDown
	XSkillProgression.sync(a)  # CodexSkillProgression 包的是 changeLevel：逐级降级每步都同步
	XSukuna.sync(a)  # 宿傩包的是 changeLevel：逐级降级每步都同步，结果与降完再同步一次相同
	XYunshang.sync(a)  # 云裳同宿傩（changeLevel）
	XGuyu.sync(a)  # 谷雨同样包 changeLevel（不包 levelDown），同宿傩


static func level_changed(a, before: int) -> void:
	if not _module(a):
		return
	if int(a.level) >= before:  # 同级也同步：change_level 会按职业习得表补学，要重排回原版 changeLevel 包装后的结果
		level_up(a)
	else:
		level_down(a)


static func param(a, i: int, v: float) -> float:
	return XYunshang.param(a, i, XYomiJingliu.param(a, i, XSukuna.param(a, i, XToji.param(a, i, XMira.param(a, i, v))))) if _module(a) else v


static func xparam(a, i: int, v: float) -> float:
	return XYomiJingliu.xparam(a, i, XSukuna.xparam(a, i, XToji.xparam(a, i, XNumberBoost.xparam(a, i, v)))) if _module(a) else v


static func param_rate(a, i: int) -> float:
	return XGarou.param_rate(a, i) if _module(a) else 1.0


static func equip_changed(a) -> void:
	if _module(a):
		XGarou.sync(a)


static func param_base(a, i: int, v: float) -> float:
	return XYomiJingliu.param_base(a, i, v) if _module(a) else v


static func param_plus(a, i: int, v: float) -> float:
	return XYomiJingliu.param_plus(a, i, v) if _module(a) else v


static func action_plus_set(a, rates: Array) -> void:
	if _module(a):
		XYomiJingliu.action_plus_set(a, rates)


static func passive_cache(a, c: Dictionary) -> void:
	if _module(a):
		XRaven.passive_cache(a, c)
		XSukuna.passive_cache(a, c)
		XToji.passive_cache(a, c)
		XYunshang.passive_cache(a, c)
