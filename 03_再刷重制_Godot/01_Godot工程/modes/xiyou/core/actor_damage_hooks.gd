class_name XActorDamageHooks
extends RefCounted
## 专属角色模块的伤害钩子（原版 CodexDamageHooks 里的 raven、native-number-pools、mira、sukuna、yomi-jingliu、toji、garou、yunshang、xuan-host-offense、tusu、liuying）：宿主侧 capture 按当时的
## 行动者／目标算好帧操作（只含数值），处理函数只把它们原样交回注册表。各操作都是加或乘（mode 为设定），彼此次序无关。
## 顺序号 3：原版 CodexDamageHooks 里 raven 1、mira 2、native-number-pools 3、yomi-jingliu 4、toji 5、sukuna 7 都在 cat-sword 9 之前，重制序号＝2×序＋1，
## 六个合成一条取最前的 raven（3），仍在小猫剑圣（18／19）、宝珠套装（39）、种族祝福（41）之前。

static func descriptor() -> Dictionary:
	return {"id": "actor-modules", "version": "1", "capabilities": ["damage.actor_modules"],
		"contexts": ["facts"], "hooks": [{"point": "damage.before", "order": 3, "reads": ["facts.actorModules"],
			"writes": ["mode", "kind", "elements", "physicalDefenseRate", "physicalIncomingPierce", "resistancePierce", "magicalDefenseRate", "elementAdd", "normalAdd", "finalAdd", "finalMultiplier", "skillMultiplier",
				"settlementMultiplier", "criticalAdd", "incomingMultiplier", "categoryMax", "healingMultiplier"], "handler": build}]}


## 15 个专属模块钩子的总账来源名（XTianqiLedger，damage_ledger.json 的 module.* 行），和 capture 里的调用一一对应、次序相同
const MODULE_TAGS := ["module.raven", "module.number_boost", "module.mira", "module.sukuna", "module.yomi_jingliu", "module.toji", "module.toji_incoming",
	"module.garou", "module.yunshang", "module.black_flash", "module.xuan_cast", "module.xuan_incoming", "module.xuan_damage", "module.tusu", "module.liuying"]
const REST_TAGS := ["hubris", "weak_challenge", "qiyin", "affix_skill", "tianqi_skills", "module.tianqi_modules", "trumpet", "module.gojo", "fest_road"]


## 各钩子分段算、按原来的次序拼（和原来一行相加逐项相同）。MODULE_CAP 逐段收口（它是逐条过滤，分段与整段结果相同），段名交给白名单；
## 天启篇总账守卫开着时多带一份 tags（跟 ops 一一对应的来源名），原版档不带、返回值和原来一样。
## 专项 xiyou_tianqi_ledger 的逐号清单用：非 null 时把 15 个模块钩子 MODULE_CAP 之前的原始操作逐段记进来；
## RECORD_ACT 由专项在每次出手前填 {subject, skill}，对不上的（模块内部再打一下、借普攻号的追加段）记成派生。游戏里恒 null。
static var RECORD = null
static var RECORD_ACT := {}


static func capture(item: Dictionary, a: XBattler, b: XBattler) -> Dictionary:
	var parts := module_parts(item, a, b)
	if RECORD is Array:
		var id := int(item.get("id", 0))
		for i in MODULE_TAGS.size():
			if not (parts[i] as Array).is_empty():
				RECORD.append({"tag": MODULE_TAGS[i], "skill": id, "actor": int(a.actor_id) if a is XActor else 0,
					"derived": not (is_same(RECORD_ACT.get("subject"), a) and int(RECORD_ACT.get("skill", -1)) == id), "ops": (parts[i] as Array).duplicate(true)})
	var ops := []
	var tags := []
	var tagging := XTianqiLedger.auditing(a)
	for i in parts.size():
		var part: Array = XTianqiSkills.module_ops(item, a, parts[i], MODULE_TAGS[i]) if i < MODULE_TAGS.size() else parts[i]
		ops.append_array(part)
		if tagging:
			var tag: String = MODULE_TAGS[i] if i < MODULE_TAGS.size() else REST_TAGS[i - MODULE_TAGS.size()]
			for _o in part:
				tags.append(tag)
	return {"ops": ops, "tags": tags} if tagging else {"ops": ops}


## 分段的原始操作（MODULE_CAP 之前）：前 15 段是专属模块钩子，后 9 段是狂妄、弱者挑战、七印、词条、技能卡、天启篇专属模块、号卷、五条悟、冠军庆典（冠军之路「势如破竹」＋冠军戒指「一穿四」，天启篇档为空）
## （天启篇技能重构：专属物无视双防、治疗量；天启篇七印装备、天启篇词条的出伤、承伤、治疗（原版档为空）；狂妄 hubris：物防率 ×0.82／0.73；弱者挑战 weak-new-game 终伤 ×3）
static func module_parts(item: Dictionary, a: XBattler, b: XBattler) -> Array:
	return [XRaven.damage_ops(item, a), XNumberBoost.damage_ops(item, a, b), mira_ops(item, a, b), XSukuna.damage_ops(item, a), XYomiJingliu.damage_ops(item, a, b),
		XToji.damage_ops(item, a), XToji.incoming_ops(item, a, b), XGarou.damage_ops(item, a, b), XYunshang.damage_ops(item, a, b), XBlackFlash.damage_ops(b),
		XXuanBattle.cast_ops(item, a), XXuanBattle.incoming_ops(item, a, b), XXuanBattle.damage_ops(item, a), XTusu.damage_ops(item, a, b), XLiuying.damage_ops(item, a, b),
		XHubris.damage_ops(item, a), XWeakChallenge.damage_ops(a), XTianqiQiyinEffects.damage_ops(item, a, b), XTianqiAffixBattle.damage_ops(item, a, b),
		XTianqiSkills.damage_ops(item, a, b), XTianqiModules.damage_ops(item, a, b), XTianqiTrumpet.damage_ops(item, a, b), XGojo.damage_ops(item, a),
		XFestRoad.damage_ops(a)]


## 伤害钩子 mira：米拉 10140～10151 按技能定物理／魔法／混合；黑龙形态学了 10154（进阶 3 次）时受到的伤害 ×0.8
static func mira_ops(item: Dictionary, a: XBattler, b: XBattler) -> Array:
	var ops := []
	var id := int(item.get("id", 0))
	if XMira.own(a) and id >= 10140 and id <= 10151:
		ops.append({"op": "set", "field": "mode", "value": "magical" if id in [10142, 10143, 10149] else ("mixed" if id in [10146, 10147, 10151] else "physical")})
	if XMira.dragon(b) and XMira.has(b, 10154, 3):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": 0.9 if XTianqiSkills.cards_on() else 0.8})  # 天启篇：受伤 −10%
	return ops


static func build(context: Dictionary, _frame: Dictionary) -> Dictionary:
	return {"ops": context.facts.actorModules.ops}
