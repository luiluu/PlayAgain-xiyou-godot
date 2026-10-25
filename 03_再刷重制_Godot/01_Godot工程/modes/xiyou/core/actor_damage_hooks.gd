class_name XActorDamageHooks
extends RefCounted
## 专属角色模块的伤害钩子（原版 CodexDamageHooks 里的 raven、native-number-pools、mira、sukuna）：宿主侧 capture 按当时的
## 行动者／目标算好帧操作（只含数值），处理函数只把它们原样交回注册表。各操作都是加或乘（mode 为设定），彼此次序无关。

static func descriptor() -> Dictionary:
	return {"id": "actor-modules", "version": "1", "capabilities": ["damage.actor_modules"],
		"contexts": ["facts"], "hooks": [{"point": "damage.before", "order": 41, "reads": ["facts.actorModules"],
			"writes": ["mode", "kind", "elements", "physicalDefenseRate", "magicalDefenseRate", "elementAdd", "normalAdd", "finalAdd", "finalMultiplier", "skillMultiplier",
				"settlementMultiplier", "criticalAdd", "incomingMultiplier"], "handler": build}]}


static func capture(item: Dictionary, a: XBattler, b: XBattler) -> Dictionary:
	var ops: Array = XRaven.damage_ops(item, a) + XNumberBoost.damage_ops(item, a, b) + mira_ops(item, a, b) + XSukuna.damage_ops(item, a)
	return {"ops": ops}


## 伤害钩子 mira：米拉 10140～10151 按技能定物理／魔法／混合；黑龙形态学了 10154（进阶 3 次）时受到的伤害 ×0.8
static func mira_ops(item: Dictionary, a: XBattler, b: XBattler) -> Array:
	var ops := []
	var id := int(item.get("id", 0))
	if XMira.own(a) and id >= 10140 and id <= 10151:
		ops.append({"op": "set", "field": "mode", "value": "magical" if id in [10142, 10143, 10149] else ("mixed" if id in [10146, 10147, 10151] else "physical")})
	if XMira.dragon(b) and XMira.has(b, 10154, 3):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": 0.8})
	return ops


static func build(context: Dictionary, _frame: Dictionary) -> Dictionary:
	return {"ops": context.facts.actorModules.ops}
