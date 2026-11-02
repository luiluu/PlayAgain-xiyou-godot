class_name XThreeGrowth
extends RefCounted
## 三法宝成长（正式 js/codex/runtime/installThreeGrowthRelicRuntime.js，W.CodexThreeGrowth v0.4.0 的 R.syncItem；参照 three_growth_probe）：
## 所属人物 60 级时法宝进化——每级成长由 18（定位四项 36）改为 36（72）、改名、说明换成进化后的那句；进化一次后不退
## （_codex60Evolved，人物再降回 60 级以下也不变）。未进化时说明也改成「法宝」＋第一句。
## 原版在 changeLevel／levelUp／changeEquip／startBattle／读档／magicWeaponCustomParam 时同步；重制在算法宝能力（XActor.magic_param）
## 与说明卡显示时（XHelpCard.content）同步，名字与说明跟着变。谷雨 175 百谷生 7912、屠苏 176 止戈环 4047、璇 177 璇玑星盘 4048（后两件 events3 随 176／177 进切片补上，【cc·悟空·未经审查】）。
## 说明卡条目 relicLines（参照 guyu_ui_probe 的 relic 例）：备注里去掉原有的 <pos=APs …>、每级成长、品质标签，补回品质 9 与新的每级成长，
## 再按显示顺序倒序写入 APs 行（HelpExtend 同一位置后插的在前）：「\c[2]专属：谷雨」「等级需求：1」、未进化时「进化：…」、
## 特效倍率按值分组两两成对（生命×130%；物防×120%　魔防×120%）、进化后的特效、法宝每级四行（生命／魔法、物攻／魔攻、物防／魔防、速度／幸运）。
## 同一状态（签名 _codex60Signature）只改一次。
## 特效倍率不改写：原版 syncItem 对新登记的实例按旧版倍率（spec.old）去重再补新倍率，本次启动里法宝原件没先同步过时会多出一条
## 魔攻×1.2（屠苏魔攻 1.4 倍，谷雨生命、物防也多一条），取决于启动后的先后，重制按数据库原件的倍率（O-148，没做开关：原版结果取决于启动后的先后）。
## 未移植：传家宝品质整理（RQ.normalize，原表这些法宝本来就是品质 9）、屠苏与璇的五相／列星特效；
## 原版同步也改数据库原件（$dataArmors），重制只改实例，数据库原件的说明卡按所属人物等级现算（不写回数据库）。

const SPECS := {4047: {"actor": 176, "base": "止戈环", "name": "太初五兵环", "extra": [2, 3, 4, 5],
	"rates": [[2, 1.2], [4, 1.2], [3, 1.2], [5, 1.2]], "who": "屠苏", "hint": "获得五相专属特效",
	"desc": ["缺口的青铜铸环。老君炼她，本意是止息兵祸。", "铸环合拢，五兵归一。"],
	"evolved": ["剑气纵横命中的敌人，本回合下一次受到斩锋或横扫时伤害×1.1", "点射分2段、贯日分3段、敕令分2段，只支付一次消耗",
		"护阵期间，敌方第一次伤害行动命中的队友各获得护盾：屠苏物防与魔防之和×18，持续1回合", "震击、镇魂重击命中有挫势的敌人时，该敌人下一次直接伤害×0.9，持续到下回合结束"]},
	4048: {"actor": 177, "base": "璇玑星盘", "name": "周天命星仪", "extra": [0, 3, 4, 5],
	"rates": [[4, 1.2], [3, 1.3], [5, 1.3]], "who": "璇", "hint": "获得列星专属特效",
	"desc": ["观星的星盘。星谱就刻在盘面上。", "周天星宿都在仪上运转。"],
	"evolved": ["列星期间的第一次回光，额外净化一个可净化的负面状态", "列星期间的第一次璃壁附带星幕：受益者本回合下一次受到的敌方直接伤害×0.9"]},
	7912: {"actor": 175, "base": "百谷生", "name": "万象长春盏", "extra": [0, 3, 5, 6],
	"rates": [[0, 1.3], [3, 1.2], [5, 1.2]], "who": "谷雨", "hint": "获得复活专属特效",
	"desc": ["一盏盛着百谷新芽的瓷盏。", "盏中万象长春，生生不息。"],
	"evolved": ["本场谷雨第一次以骨生花复活时，谷雨与储备比例最低的一名队友各获得谷雨基础最大生命18%的生命储备"]}}
const PN := ["生命", "魔法", "物攻", "物防", "魔攻", "魔防", "速度", "幸运"]
const PAIRS := [[0, 1], [2, 4], [3, 5], [6, 7]]
const PARAM_TAGS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]
const SIGNATURE := "v05text6-"


static func spec_of(e: Dictionary) -> Dictionary:
	return SPECS.get(int(e.get("base", e.get("id", 0))), {})


static func _evolved(e: Dictionary, spec: Dictionary) -> bool:
	var s := XState.current
	var a = s.actors.get(int(spec.actor)) if s != null else null
	return bool(e.get("_codex60Evolved", false)) or (a != null and int(a.level) >= 60)


## R.syncItem：返回这件法宝现在的每级成长（不归这里管返回空）
static func sync_item(e: Dictionary) -> Array:
	var spec := spec_of(e)
	if spec.is_empty() or str(e.get("kind", "armor")) != "armor":
		return []
	var evolved := _evolved(e, spec)
	var sig := SIGNATURE + ("evolved" if evolved else "base")
	if str(e.get("_codex60Signature", "")) == sig and e.has("paramPlusPerLevel"):
		return e.paramPlusPerLevel
	var unit := 36 if evolved else 18
	var per := []
	for i in 8:
		per.append(unit * (2 if (spec.extra as Array).has(i) else 1))
	var name: String = spec.name if evolved else spec.base
	var original := str(e.get("baseItemName", e.get("name", spec.base)))
	var now := str(e.get("name", spec.base)).replace(original, name)
	if now == original or now in [spec.base, spec.name]:
		now = name
	e["name"] = now
	e["baseItemName"] = name
	e["paramPlusPerLevel"] = per
	e["note"] = relic_note(str(e.get("note", "")), spec, evolved, unit)
	e["description"] = "法宝\n" + str(spec.desc[1 if evolved else 0])
	e["_codex60Signature"] = sig
	if evolved:
		e["_codex60Evolved"] = true
	return per


## 说明卡用：数据库原件不改，复制一份按现在的状态改写；实例照常同步（与原版同步时机一样会定下进化）
static func view(obj: Dictionary) -> Dictionary:
	if spec_of(obj).is_empty():
		return obj
	if obj.has("kind"):
		sync_item(obj)
		return obj
	var copy := obj.duplicate(true)
	copy["kind"] = "armor"
	sync_item(copy)
	copy.erase("kind")
	return copy


## R.syncItem 的备注改写：去掉 APs 行、每级成长、GuyuHealStrength、品质标签，补品质 9、每级成长，再倒序写 relicLines
static func relic_note(note: String, spec: Dictionary, evolved: bool, unit: int) -> String:
	var out := RegEx.create_from_string("\\n?<pos=APs [^>]*>").sub(note, "", true)
	out = RegEx.create_from_string("\\n?<(?:\\w+ Param \\+\\d+ per Level|GuyuHealStrength[^>]*|quality:\\d+|ici:\\d+)>").sub(out, "", true)
	out += "\n<quality:9>\n<ici:9>\n"
	for i in 8:
		out += "<%s Param +%d per Level>\n" % [PARAM_TAGS[i], unit * (2 if (spec.extra as Array).has(i) else 1)]
	var lines := relic_lines(spec, evolved, unit)
	lines.reverse()
	for t in lines:
		out += "<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>\n" % t
	return out


## relicLines（显示顺序）
static func relic_lines(spec: Dictionary, evolved: bool, unit: int) -> Array:
	var rows := ["\\c[2]专属：" + str(spec.who), "等级需求：1"]
	if not evolved:
		rows.append("进化：%s60级时进化为%s，%s" % [spec.who, spec.name, spec.hint])
	var values := []
	for r in spec.rates:
		if not values.has(r[1]):
			values.append(r[1])
	for v in values:
		var group: Array = (spec.rates as Array).filter(func(r): return r[1] == v)
		for i in range(0, group.size(), 2):
			var pair := group.slice(i, i + 2).map(func(r): return "%s×%d%%" % [PN[r[0]], roundi(float(r[1]) * 100.0)])
			rows.append("\\c[1]特效：" + "　".join(PackedStringArray(pair)))
	if evolved:
		for t in spec.evolved:
			rows.append("\\c[1]特效：" + str(t))
	for pr in PAIRS:
		rows.append("\\c[1]法宝每级：" + "　".join(PackedStringArray(pr.map(func(i): return "%s＋%d" % [PN[i], unit * (2 if (spec.extra as Array).has(i) else 1)]))))
	return rows
