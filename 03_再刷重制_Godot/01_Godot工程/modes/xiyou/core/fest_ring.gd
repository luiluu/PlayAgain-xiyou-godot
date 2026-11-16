class_name XFestRing
extends RefCounted
## 【cc·未经审查】冠军庆典·冠军戒指（Kyo 11-15 定 D46「丰富」档；方案：私密设计仓 重制设定/冠军庆典活动_v0.3.1.md 2.2、第 3 节、第 7 节 2～5 条）。
## 三枚戒指，冠军之路三档各给一枚（四关全胜，输过也算；每个存档每档一枚）：欢庆档→史诗、天灾档→传说、洪荒档→不朽。
##
## - 定义常驻（第 3 节第 4 条）：XDB 读 Armors 表时追加三件（8010～8012），不看 XFest.ENABLED、不看活动日期。
##   活动结束、开关关掉以后，老存档里的戒指照样查得到定义、照样生效（成长、终伤、一穿四都跟着装备走，不跟活动走）。
## - 0 浮动、无随机词缀、固定 6 孔：equipment.variance 0、slotVariance 0、slots 6、affixes 空（读档重刷不出更好的）。
## - 成长（欢庆）：物攻、魔攻每级 +1，60 级封顶。不拼 <Custom Parameters> 备注（那是转换器预编译的，运行时拼了不生效），
##   直接写编译好的 customParams（与转换器同格式）＋ levelCap 60（XActor.custom_param 认这个上限）。
## - 一穿四（天灾、洪荒）：本场每倒下一个敌人，佩戴者伤害 +5%／+8%，最多 4 层。XActorDamageHooks 的 finalMultiplier（和「势如破竹」同一种接法），
##   所有战斗都生效；层数记在战斗里的角色身上（meta），开战清零、战斗结束清零。
## - 防刷（第 3 节）：实例 meta["PushDct"]=true（星级仓库只看 meta）＋备注 <PushDct>；法宝喂装备拦（XFabaoFeed.reason）；
##   发放时默认锁定（名字带「[锁定]」，玩家可以手动解锁）；卖价 0、一键出售和挂机自动卖都跳过（XItemMarks）。
## 开关 GRANT＝false：冠军之路全胜不再发戒指（已发的照旧在）。O-511。

static var GRANT := true

## 号段：Armors 表外追加（原表到 8000，五条悟眼罩占 8001）
const ARMORS := [8010, 8011, 8012]
## 结构照「悲伤之戒」复制（戒指栏 etypeId 10、atypeId 5），字段全部重写
const TEMPLATE := 245
const ETYPE := 10
## 一穿四：每层加成、最多层数（按档；欢庆档没有）
const STACK_STEP := [0.0, 0.05, 0.08]
const STACK_MAX := 4
## 欢庆戒指成长到 60 级
const GROWTH_CAP := 60

## 三枚戒指（v0.3.1 2.2）。params：生命、魔力、物攻、物防、魔攻、魔防、敏捷、幸运
const RINGS := [
	{"name": "冠军戒指·欢庆", "quality": 4, "icon": 1532, "params": [0, 0, 0, 0, 0, 0, 0, 0],
		"crit": 0.10, "hit": 0.10, "final": 10, "all": 0, "growth": 1,
		"desc": "戒指\n冠军庆典的纪念戒指。戴着它的人，越打越有劲。"},
	{"name": "冠军戒指·天灾", "quality": 6, "icon": 2267, "params": [600, 0, 60, 20, 60, 20, 20, 0],
		"crit": 0.25, "hit": 0.25, "final": 25, "all": 0, "growth": 0,
		"desc": "戒指\n冠军庆典的纪念戒指。一个接一个，倒下的都算数。"},
	{"name": "冠军戒指·洪荒", "quality": 8, "icon": 2817, "params": [1500, 0, 120, 40, 120, 40, 40, 0],
		"crit": 0.40, "hit": 0.40, "final": 30, "all": 35, "growth": 0,
		"desc": "戒指\n冠军庆典的纪念戒指。一穿四，说的就是戴着它的人。"},
]

const PUSH_DCT := "PushDct"


static func armor_id(tier: int) -> int:
	return int(ARMORS[tier])


## 装备实例或记录是不是冠军戒指；是的话返回档（0～2），否则 -1
static func tier_of(rec) -> int:
	if not rec is Dictionary or str(rec.get("kind", "armor")) != "armor":
		return -1
	return ARMORS.find(int(rec.get("base", rec.get("id", 0))))


static func is_ring(rec) -> bool:
	return tier_of(rec) >= 0


## 一条戒指的备注（显示行用原版戒指同款的 pos=APs 写法）
static func note_of(tier: int) -> String:
	var r: Dictionary = RINGS[tier]
	var lines := ["<req_level:1>", "<ici:%d>" % int(r.quality), "<quality:%d>" % int(r.quality), "<" + PUSH_DCT + ">",
		"<passiveHarmRi:%d>" % int(r.final)]
	if int(r.all) > 0:
		for e in range(1, 10):
			lines.append("<Element Amplify %d: +%d%%>" % [e, int(r.all)])
	var line := func(text: String) -> String:
		return "<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>" % text
	lines.append(line.call("等级需求:1"))
	var fx := "伤害+%d%%" % int(r.final)
	if int(r.all) > 0:
		fx += "，全属性伤害+%d%%" % int(r.all)
	lines.append(line.call("\\c[1]特效:冠军(%s)" % fx))
	if tier > 0:
		lines.append(line.call("\\c[1]特效:一穿四(本场每倒下一个敌人，伤害+%d%%，最多%d层)" % [int(round(STACK_STEP[tier] * 100)), STACK_MAX]))
	if int(r.growth) > 0:
		lines.append(line.call("\\c[1]成长:物攻、魔攻每级+%d(%d级封顶)" % [int(r.growth), GROWTH_CAP]))
	lines.append(line.call("暴击率+%d%%" % int(round(float(r.crit) * 100))))
	lines.append(line.call("命中率+%d%%" % int(round(float(r.hit) * 100))))
	lines.append(line.call("\\c[2]冠军庆典限定:不能出售、不能存入星级仓库、不能喂给法宝"))
	return "\n".join(lines)


## 编好的 customParams（与转换器解析 <Custom Parameters> 的格式相同）：物攻、魔攻每级 +growth，到 GROWTH_CAP 级止
static func custom_params(tier: int) -> Dictionary:
	var g := float(RINGS[tier].growth)
	var terms := []
	for i in 8:
		terms.append({"k": 0.0, "level": g if (i == 2 or i == 4) else 0.0, "vars": {}})
	return {"params": terms, "ignored": [], "levelCap": GROWTH_CAP}


## XDB.table("Armors") 读表时追加（常驻：不看活动开关和日期）
static func patch_armors(t: Array) -> void:
	if TEMPLATE >= t.size() or not t[TEMPLATE] is Dictionary:
		return
	for tier in RINGS.size():
		var id := armor_id(tier)
		while t.size() <= id:
			t.append(null)
		if t[id] is Dictionary and str(t[id].get("name", "")) != "" and not bool(t[id].get("_fest", false)):
			push_error("XFestRing: 防具 %d 已被正式源占用，冠军戒指没有补进去（要整体挪号）" % id)
			continue
		t[id] = build(tier, t[TEMPLATE])


static func build(tier: int, template: Dictionary) -> Dictionary:
	var r: Dictionary = RINGS[tier]
	var out: Dictionary = template.duplicate(true)
	out["id"] = armor_id(tier)
	out["_fest"] = true
	out["name"] = str(r.name)
	out["description"] = str(r.desc)
	out["iconIndex"] = int(r.icon)
	out["etypeId"] = ETYPE
	out["price"] = 0
	out["params"] = (r.params as Array).duplicate()
	out["traits"] = [{"code": 22, "dataId": 0, "value": float(r.hit)}, {"code": 22, "dataId": 2, "value": float(r.crit)}]
	out["note"] = note_of(tier)
	var meta := XTianqiSkills.parse_meta(str(out.note))
	meta[PUSH_DCT] = true
	out["meta"] = meta
	if int(r.all) > 0:
		var amp := {}
		for e in range(1, 10):
			amp[str(e)] = float(r.all) / 100.0
		out["yep"] = {"elementAmplify": amp}
	else:
		out.erase("yep")
	if int(r.growth) > 0:
		out["customParams"] = custom_params(tier)
	else:
		out.erase("customParams")
	out["equipment"] = {"affixes": [], "suits": [], "variance": 0, "slots": 6, "slotVariance": 0, "requirements": {"actors": []}}
	return out


## 发一枚（冠军之路全胜时 XFestRoad.settle 调）：进背包、写死 PushDct、默认锁定。返回实例（没发成返回 {}）
static func grant(s, tier: int) -> Dictionary:
	if s == null or not GRANT or tier < 0 or tier >= RINGS.size():
		return {}
	var before: int = s.gear.size()
	s.gain_gear("armor", armor_id(tier), 1, "fest")
	if s.gear.size() <= before:
		return {}
	var inst: Dictionary = s.gear.back()
	if tier_of(inst) != tier:
		return {}
	secure(s, inst)
	return inst


## 把一件戒指实例补成防刷状态：meta 带 PushDct、名字带锁定（已锁的不动）
static func secure(s, inst: Dictionary) -> void:
	var meta: Dictionary = inst.get("meta") if inst.get("meta") is Dictionary else {}
	meta[PUSH_DCT] = true
	inst["meta"] = meta
	if not XItemMarks.is_locked(s, inst):
		XItemMarks.toggle_lock(s, inst)


# ==== 一穿四 ====

const META_STACKS := "fest_ring_stacks"
const META_COUNTED := "fest_ring_counted"


## 这名角色戴着的冠军戒指里，一穿四每层最高的那档（没戴或只戴欢庆返回 -1）
static func stack_tier(a) -> int:
	if not (a is XActor):
		return -1
	var best := -1
	for e in (a as XActor).equip_list():
		var t := tier_of(e)
		if t > 0 and (best < 0 or STACK_STEP[t] > STACK_STEP[best]):
			best = t
	return best


static func stacks(a) -> int:
	return int(a.get_meta(META_STACKS, 0)) if a is Object and a.has_meta(META_STACKS) else 0


## 伤害钩子（XActorDamageHooks.capture 末段，和势如破竹并列）：佩戴者出手 ×(1＋每层×层数)
static func damage_ops(a) -> Array:
	var n := stacks(a)
	if n <= 0:
		return []
	var t := stack_tier(a)
	if t <= 0:
		return []
	return [{"op": "mul", "field": "finalMultiplier", "value": 1.0 + float(STACK_STEP[t]) * float(mini(n, STACK_MAX))}]


static func _clear(members: Array) -> void:
	for a in members:
		if a is Object and a.has_meta(META_STACKS):
			a.remove_meta(META_STACKS)


## 开战（XBattleLogic.setup）：清掉上一场残留的层数
static func battle_setup(logic) -> void:
	_clear(logic.actors)


## 每次行动／回合末结算倒下（XBattleLogic.resolve_collapses）：新倒下的敌人每只给戴戒指的出战角色 +1 层（封顶 4）。
## 同一只敌人只算一次（复活再倒不再算）
static func on_collapses(logic) -> void:
	var fresh := 0
	for e in logic.enemies:
		if e.is_dead() and not e.has_meta(META_COUNTED):
			e.set_meta(META_COUNTED, true)
			fresh += 1
	if fresh <= 0:
		return
	for a in logic.actors:
		if stack_tier(a) > 0:
			a.set_meta(META_STACKS, mini(stacks(a) + fresh, STACK_MAX))


## 战斗结束（XBattleLogic.end_battle）：层数清零
static func finish(logic) -> void:
	_clear(logic.actors)
	if logic.state != null:
		_clear(logic.state.members())
