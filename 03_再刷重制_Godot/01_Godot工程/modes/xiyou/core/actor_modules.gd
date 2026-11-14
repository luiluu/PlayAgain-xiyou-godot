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
## - 屠苏 176／璇 177（XTusuXuan）：levelUp／levelDown 后按职业习得表同步专属技能（bindGrowth）。
## - 云裳 174（XYunshang）：setup、levelUp、changeLevel 后 Y.sync；param 最大生命／魔攻／敏捷按等级与进阶的倍率。
## - 流萤 179（XLiuying）：levelUp、changeLevel 后 L.sync；paramPlus 逐火与专武、actionPlusSet。param 在云裳夹值之外（XActor.param），learnSkill 连带见 XActor.learn_skill。

const IDS := [167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 179]


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
	XTusuXuan.sync(a)  # 屠苏／璇 bindGrowth levelUp 包装：专属技能按习得表同步
	XLiuying.sync(a)  # 流萤 levelUp／changeLevel 包装：按等级、进阶学忘


static func level_down(a) -> void:
	if not _module(a):
		return
	XGarou.level_up(a)  # G.sync 同样挂在 levelDown
	XSkillProgression.sync(a)  # CodexSkillProgression 包的是 changeLevel：逐级降级每步都同步
	XSukuna.sync(a)  # 宿傩包的是 changeLevel：逐级降级每步都同步，结果与降完再同步一次相同
	XYunshang.sync(a)  # 云裳同宿傩（changeLevel）
	XGuyu.sync(a)  # 谷雨同样包 changeLevel（不包 levelDown），同宿傩
	XTusuXuan.sync(a)  # 屠苏／璇 bindGrowth 包 levelDown
	XLiuying.sync(a)  # 流萤包 changeLevel：逐级降级每步都同步，同宿傩


static func level_changed(a, before: int) -> void:
	if not _module(a):
		return
	if int(a.level) >= before:  # 同级也同步：change_level 会按职业习得表补学，要重排回原版 changeLevel 包装后的结果
		level_up(a)
	else:
		level_down(a)


static func param(a, i: int, v: float) -> float:
	return XYomiJingliu.param(a, i, XSukuna.param(a, i, XToji.param(a, i, XMira.param(a, i, v)))) if _module(a) else v  # 云裳那层在小猫剑圣外面，见 XActor.param_before_alien


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
	return XLiuying.param_plus(a, i, XRaven.param_plus(a, i, XYomiJingliu.param_plus(a, i, v))) if _module(a) else v


static func action_plus_set(a, rates: Array) -> void:
	if _module(a):
		XYomiJingliu.action_plus_set(a, rates)
		XLiuying.action_plus_set(a, rates)  # 流萤：过载 0.3、法宝 1、一阶 1
		XGarou.action_plus_set(a, rates)  # 天启篇饿狼：四臂、星空再动 10%
	XCat.action_plus_set(a, rates)  # 天启篇哈基米：进阶后再动 10%


static func passive_cache(a, c: Dictionary) -> void:
	if _module(a):
		XRaven.passive_cache(a, c)
		XSukuna.passive_cache(a, c)
		XToji.passive_cache(a, c)
		XYunshang.passive_cache(a, c)


## Game_Actor.addedSkillTypes 包装（菜单技能分类；Window_SkillType 照 YEP_CoreEngine 再升序排）：渡鸦（不在战斗）［2,1,5,3,4］、
## 宿傩［2,1,5,3,4］、饿狼［2,1,5,4］、云裳［2,1,5,4］，没学到那类技能也列出；别的角色返回 null（照特性 41）。
## 这是 addedSkillTypes 的原值，含「呼吸法」3；真正列出时 Window_SkillType／Window_ActorCommand 一律不加 3
## （installNativeYomiJingliuRuntime 的 Window_Command.addCommand 包装，symbol=skill 且 ext=3 直接丢；2026-11-05 白龙在原版实机量过，
## 33 个角色的技能菜单与战斗指令都没有 3），所以用 visible_skill_types 过一遍再显示。
const MENU_SKILL_TYPES := {167: [2, 1, 5, 3, 4], 172: [2, 1, 5, 3, 4], 173: [2, 1, 5, 4], 174: [2, 1, 5, 4]}
## 隐藏的技能分类（技能类型 3「呼吸法」：Window_Command.addCommand 对 skill＋ext 3 直接不加，对所有角色）
const HIDDEN_SKILL_TYPE := 3
## Window_ActorCommand.addSkillCommands 包装（战斗指令，照这个次序、不排序、不再按 CP_MagicWeapon 去掉 3～6）：
## 渡鸦［2,1,5］、宿傩［2,1,5］（原值 addSkillCommands 含 3，但 addCommand 丢掉它）、饿狼［2,1,5］、云裳［2,1,5］（云裳原版直接包 addSkillCommands，固定 [2,1,5]、不列被动 4，参照 p6.cmd*；addedSkillTypes 的 [2,1,5,4] 只管技能菜单）；别的角色返回 null
const BATTLE_SKILL_TYPES := {167: [2, 1, 5], 172: [2, 1, 5], 173: [2, 1, 5], 174: [2, 1, 5]}


## 技能分类列表里实际显示的：去掉被 addCommand 丢掉的 3（保持次序）
static func visible_skill_types(types: Array) -> Array:
	return types.filter(func(t): return int(t) != HIDDEN_SKILL_TYPE)


## 技能菜单（Window_SkillType.makeCommandList）对 167～177 号新角色和流萤 179 固定多一页「功法」（技能类型 6，没学功法也列）：
## 先去掉已有的 6，再插到被动 4 前面；没有 4 就插到 min(2, 长度) 位。只管技能菜单，战斗指令保持原样
## （installV010UsabilityRuntime 的 newActor＋Window_SkillType.makeCommandList 包装，冻结源 v0.62.12：
## newActor＝id>=167 && id<=177 || id===179；ui7 移植时只照了 167～177，流萤 179 漏了，v0.01.09 玩家反馈「流萤看不到功法页面」，dev.578 补上）。
## 178 不在内（原版也不在）；180 五条悟只进天启篇、原版没有，不加。
const GONGFA_SKILL_TYPE := 6
const GONGFA_ACTOR_MIN := 167
const GONGFA_ACTOR_MAX := 177
const GONGFA_ACTOR_EXTRA := [179]


static func has_gongfa_page(actor_id: int) -> bool:
	return (actor_id >= GONGFA_ACTOR_MIN and actor_id <= GONGFA_ACTOR_MAX) or GONGFA_ACTOR_EXTRA.has(actor_id)


static func menu_page_types(actor_id: int, types: Array) -> Array:
	if not has_gongfa_page(actor_id):
		return types
	var list := types.filter(func(t): return int(t) != GONGFA_SKILL_TYPE)
	var at := list.find(4)
	list.insert(minf(2, list.size()) as int if at < 0 else at, GONGFA_SKILL_TYPE)
	return list


static func menu_skill_types(a):
	return (MENU_SKILL_TYPES[int(a.actor_id)] as Array).duplicate() if a is XActor and MENU_SKILL_TYPES.has(int(a.actor_id)) else null


static func battle_skill_types(a):
	return (BATTLE_SKILL_TYPES[int(a.actor_id)] as Array).duplicate() if a is XActor and BATTLE_SKILL_TYPES.has(int(a.actor_id)) else null
