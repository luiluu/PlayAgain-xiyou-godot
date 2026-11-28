class_name XSkillHelpFix
extends RefCounted
## 【cc·未经审查】技能说明卡的显示修正（T590，优化登记）：只改说明卡上的字，不改公式、伤害、消耗。XHelpCard._content 里接。
## 一、随机倍率：原版公式 Math.floor(Math.random()*N)+M 实际取 M～M+N−1，备注里却写「?」「未知」、没写，或区间对不上
##    （多数写 1～N，实际 0～N−1）。照公式实际区间改写。只在公式还带 Math.random 时套（天启篇改写过的招换成了模块公式，说明另写）。
##    10530、10531、10544 的「伤害:?」公式没有随机项（随剧情变量），照原样不动。
## 二、消耗：说明卡原来读技能表的基础值；实际消耗还要过 skillMpCost／skillTpCost 全链（难度被动的负数 ConsumeReduce 会让消耗变高，
##    至尊宝擎天棍法 30 → 72TP）。技能页、战斗、遗忘页按正在看的角色算（XHelpCard.cost_actor）；别处用固定值（备注 <TP Cost: n> 优先于表值）。
##    备注里只写一个定值的消耗行（「TP消耗:50」「消耗：200TP」）换成算出来的值。专属角色技能（XCharacterHelp）本来就按实际算，不经这里。

## 回退开关：false＝照原版说明
static var RANGE_FIX := true
static var COST_FIX := true

const LINE := "\n<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>"
const PURE_COST := "<pos=APs text=(?:\\\\c\\[\\d+\\])?(?:(MP|TP)消耗[：:]\\s*(\\d+)\\s*|消耗[：:]\\s*(\\d+)\\s*(MP|TP|魔法)\\s*) size=[^>]*>"

## 技能号 → [[备注里的原文, 换成], …]
const RANGES := {
	3586: [[" * ?", " ×1～100 随机"]],
	3589: [[" * ?", " ×50～249 随机"]],
	3907: [[" * ?", " ×50～249 随机"]],
	3908: [[" * ?", " ×50～249 随机"]],
	3909: [[" * ?", " ×50～349 随机"]],
	3910: [[" * ?", " ×50～349 随机"]],
	3911: [[" * ?", " ×50～369 随机"]],
	597: [["伤害:1500+未知", "伤害:(1500+物攻×15−敌·魔攻)×(1+技能等级)×1～100 随机"]],
	9909: [["伤害:1500+未知", "伤害:(1500+物攻×15−敌·魔攻)×1～25 随机"]],
	9924: [["伤害:1500+未知", "伤害:(1500+物攻×15−敌·魔攻)×1～25 随机"]],
	9925: [["伤害:1500+未知", "伤害:(1500+物攻×15−敌·魔攻)×1～50 随机"]],
	1086: [["（2000+己·物理攻击x36）*；", "（2000+己·物理攻击x36）×15～214 随机；"]],
	1083: [["350+己·物理攻击x24；", "（350+己·物理攻击x24）×5～54 随机；"]],
	1090: [["2000+己·物理攻击x72；", "（2000+己·物理攻击x72）×1～200 随机；"]],
	1212: [["10000+己·魔法攻击x55；", "（10000+己·魔法攻击x55）×10～29 随机；"]],
	5132: [["10000+己·魔法攻击x55；", "（10000+己·魔法攻击x55）×20～59 随机；"]],
	5913: [["10000+己·魔法攻击x55；", "（10000+己·魔法攻击x55）×1～60 随机；"]],
	6875: [["伤害: size=", "伤害:按属性计算后×5～9 随机 size="]],
	3517: [["*(1~50随机数)", " ×10～49 随机"]],
	5588: [["*[1~20随机倍率]", " ×0～19 随机"]],
	5592: [["*[1~300随机倍率]", " ×0～299 随机"]],
	5596: [["伤害在1倍-8倍之间徘徊", "伤害×0～7 随机"]],
	6013: [["随机造成5-10倍伤害", "伤害×5～14 随机"]],
	6225: [["该技能会在5-50倍之间波动", "伤害×5～49 随机"]],
	6226: [["该技能会在50-100倍之间波动", "伤害×50～99 随机"]],
	6227: [["该技能会在100-175倍之间波动", "伤害×100～174 随机"]],
	6228: [["该技能会在150-250倍之间波动", "伤害×150～249 随机"]],
	6270: [["伤害在1~20倍浮动", "目标生命值不高于上限的30%时，公式中的120000改为1200000，伤害×0～99 随机。其余情况伤害×0～19 随机"],
		["<pos=APs text=特性:对低于30%生命值怪物随机伤害倍率*5 size=18 color=rgba(255,255,255,1) line=false align=0>", ""]],
	6271: [["伤害在1~10倍浮动", "伤害×0～9 随机"]],
	6272: [["伤害在1~15倍浮动", "伤害×0～14 随机"]],
	6273: [["伤害在1~10倍浮动", "伤害×0～9 随机"]],
	6275: [["伤害在1~20倍浮动", "伤害×0～19 随机"]],
	6276: [["伤害在1~18倍浮动", "伤害×0～17 随机"]],
	6277: [["伤害在1~20倍浮动", "伤害×0～19 随机"]],
	6862: [["随机5-10倍的波动", "×5～9 随机"]],
	6863: [["随机4-8倍的波动", "×5～9 随机"]],
	6864: [["随机5-10倍的波动", "×5～9 随机"]],
	6865: [["随机5-10倍的波动", "×10～14 随机"]],
	6866: [["随机5-10倍的波动", "×5～9 随机"]],
	6867: [["随机5-10倍的波动", "×5～9 随机"]],
	7030: [["伤害在10倍-30倍之间徘徊", "伤害×10～29 随机"]],
	7032: [["伤害在10倍-30倍之间徘徊", "伤害×10～29 随机"]],
	7089: [["伤害在1倍-4倍之间徘徊", "伤害×4～7 随机"]],
	7090: [["伤害在1倍-4倍之间徘徊", "伤害×4～7 随机"]],
	7091: [["伤害在1倍-4倍之间徘徊", "伤害×4～7 随机"]],
	7103: [["伤害在5倍-30倍之间徘徊", "伤害×5～29 随机"]],
	7107: [["伤害在1倍-3倍之间徘徊", "伤害×0～2 随机"]],
	7128: [["伤害在1倍-3倍之间徘徊", "伤害×0～2 随机"]],
	7222: [["伤害在1倍-8倍之间徘徊", "伤害×0～7 随机"]],
	7224: [["伤害在1倍-15倍之间徘徊", "伤害×0～14 随机"]],
	9926: [["*1~10*", " ×0～9 随机 *"]],
	10015: [["伤害在1倍-80倍之间徘徊", "伤害×0～79 随机"]],
	10016: [["伤害在1倍-50倍之间徘徊", "伤害×0～49 随机"]],
	10067: [["伤害在1~50倍浮动", "伤害×0～49 随机"]],
	10070: [["伤害在1~100倍浮动", "伤害×0～99 随机"]],
	10071: [["伤害在1~50倍浮动", "伤害×0～49 随机"]],
	10556: [["伤害在1倍-180倍之间徘徊", "伤害×0～179 随机"]],
}

## 夹在介绍文字里的定值消耗（PURE_COST 认不出整行）：技能号 → [正则, 换成]，数字交给下面的消耗行按实扣写；随 COST_FIX
## 9998 导出表写 15tp、运行时记录写 10tp，按数字通配
const STALE_COST := {
	9998: ["(老剑神李淳罡的绝学),消耗\\d+tp", "$1"],
	# 原句里的「最大生命」不扣生命（<HP Cost: 99.99%> 解析器不认）：招式收尾挂状态 2720，生命上限×0.01、2 回合
	10458: ["消耗：75怒气、最大生命的99\\.99%", "施放后生命上限降至原来的1%，持续2回合"],
	10462: ["消耗：150怒气、9999魔法与最大魔法的15%", "基础魔法消耗另加最大魔法的15%"],
}
## 整行删掉的旧费用行（整个标签，不留空行）。10462「释放需求」跟消耗栏冲突
const STALE_LINES := {10462: "\\n*<pos=APs text=释放需求[：:][^>]*>"}
## 按角色出卡时消耗栏已是最终值，这些说明句整行删掉
const NO_ACTOR_LINES := {10462: "\\n*<pos=APs text=基础魔法消耗另加最大魔法的15% [^>]*>"}


## 说明卡用的技能视图：没有要改的原样返回 obj，否则返回浅拷贝（只换 note、mpCost、tpCost）
## logic：战斗里出卡时传当前这场战斗（消耗和技能列表同一个实例算，本场的加费才算得到）；战斗外为 null
static func view(obj: Dictionary, actor = null, logic: XBattleLogic = null) -> Dictionary:
	var out := obj
	if RANGE_FIX:
		out = _ranges(out)
	if COST_FIX and not XCharacterHelp.target(out):
		out = _costs(obj, _stale_cost(out, actor), actor, logic)
	return out


static func _ranges(obj: Dictionary) -> Dictionary:
	var pairs = RANGES.get(int(obj.get("id", 0)))
	if pairs == null or not str(obj.get("damage", {}).get("formula", "")).contains("Math.random"):
		return obj
	var note := str(obj.get("note", ""))
	var fixed := note
	for p in pairs:
		fixed = fixed.replace(str(p[0]), str(p[1]))
	if fixed == note:
		return obj
	var v := obj.duplicate(false)
	v.note = fixed
	return v


static func _stale_cost(obj: Dictionary, actor) -> Dictionary:
	var id := int(obj.get("id", 0))
	var note := str(obj.get("note", ""))
	var fixed := note
	var pair = STALE_COST.get(id)
	if pair != null:
		fixed = RegEx.create_from_string(str(pair[0])).sub(fixed, str(pair[1]), true)
	if STALE_LINES.has(id):
		fixed = RegEx.create_from_string(str(STALE_LINES[id])).sub(fixed, "", true)
	if actor is XActor and NO_ACTOR_LINES.has(id):
		fixed = RegEx.create_from_string(str(NO_ACTOR_LINES[id])).sub(fixed, "", true)
	if fixed == note:
		return obj
	var v := obj.duplicate(false)
	v.note = fixed
	return v


## raw：数据库记录（算费用用它：费用链按备注认标签）；obj：可能已换过说明字的视图
static func _costs(raw: Dictionary, obj: Dictionary, actor, logic: XBattleLogic) -> Dictionary:
	var note := str(obj.get("note", ""))
	var rx := RegEx.create_from_string(PURE_COST)
	var authored := {}  # "MP"／"TP" → 备注里有定值消耗行
	for m in rx.search_all(note):
		authored[_kind(m)] = true
	var nc := XBattleLogic.note_costs(raw)
	var real := {}
	if actor is XActor:
		real = (logic if logic != null else XBattleLogic.new()).skill_cost(actor, raw)
	var out := {}
	var changed := false
	for kind in ["MP", "TP"]:
		var key: String = kind.to_lower() + "Cost"
		var base := int(obj.get(key, 0))
		var value := int(nc.get(key, base))
		var known := true  # 按最大值比例算的费用，没有角色就算不出定值
		if not real.is_empty():
			value = int(real[kind.to_lower()])
		elif nc.has(key + "Per"):
			known = false
		out[kind] = {"base": base, "value": value, "known": known}
		if known and (value != base or authored.has(kind)):
			changed = true
	if not changed:
		return obj
	var v := obj.duplicate(false)
	var matches := rx.search_all(note)
	matches.reverse()
	for m in matches:
		if out[_kind(m)].known:
			note = note.substr(0, m.get_start()) + note.substr(m.get_end())
	for kind in ["MP", "TP"]:
		var c: Dictionary = out[kind]
		if not c.known:
			continue
		v[kind.to_lower() + "Cost"] = c.value
		if c.value == 0 and (c.base > 0 or authored.has(kind)):  # 表值行只在大于 0 时出：减到 0 或原来写错的补一行
			note += LINE % ("%s消耗：0" % kind)
	v.note = note
	return v


static func _kind(m: RegExMatch) -> String:
	var k := m.get_string(1) if m.get_string(1) != "" else m.get_string(4)
	return "MP" if k == "魔法" else k
