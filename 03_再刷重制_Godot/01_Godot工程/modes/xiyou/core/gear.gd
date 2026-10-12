class_name XGear
extends RefCounted
## 装备实例工厂：模板保持不变；随机属性/词缀只在获得时掷骰，存档读回不重掷。
## 与正式版 DreamX/YEP 顺序相同：词缀合并 -> 重解析备注 -> 属性浮动 -> 插槽浮动。
##
## 预掷随机池（Star_RomGetItems）：词缀掷骰、词缀选取、属性浮动不现掷，而是从队伍身上一组预先掷好的
## 20 个随机数里按序号取（$gameParty.RomDreamX / RomDreamXNum），随存档保存，所以读档后获得同一件装备结果不变。
## 每个取数函数进入时检查：池长度不是 20 或序号已超过 15 就整组重掷、序号归零。另有一组 0/1 池（RomDreamXs）
## 只在同几率词缀排序时使用，当前数据没有同几率，但重掷时同样消耗 20 次随机数；它的序号重掷后不归零（照搬）。
## 插槽浮动与强化随机值仍是现掷（YEP 直接用 Math.random）。
## 有意修正：正式版属性浮动循环可越过池末尾（序号 20 起取到 undefined，属性变成 NaN）；这里越界时改为现掷。
const ROM_LENGTH := 20
const ROM_REFRESH := 15
static var force_roll := -1.0
## 测试用：非空时按顺序循环取值（与参照引擎的 Math.random 序列对照取数次数与先后）。
static var roll_seq: Array = []
static var roll_count := 0
## 没有当前存档时（无界面测试）用的池
static var _fallback := {}

## 相当于 Math.random
static func roll() -> float:
	if not roll_seq.is_empty():
		roll_count += 1
		return float(roll_seq[(roll_count - 1) % roll_seq.size()])
	return force_roll if force_roll >= 0 else randf()

static func _rom() -> Dictionary:
	return XState.current.rom if XState.current != null else _fallback

## 测试用：清空随机池（参照探针每件装备前也清空）
static func reset_pool() -> void:
	var r := _rom()
	r.x = []
	r.xn = 0
	r.xs = []
	r.xsn = 0

static func _pool_enter(with_bits := false) -> void:
	var r := _rom()
	if r.get("x", []).size() != ROM_LENGTH or int(r.get("xn", 0)) > ROM_REFRESH:
		var x := []
		for i in range(ROM_LENGTH):
			x.append(roll())
		r.x = x
		r.xn = 0
	if with_bits and (r.get("xs", []).size() != ROM_LENGTH or int(r.get("xsn", 0)) > ROM_REFRESH):
		var xs := []
		for i in range(ROM_LENGTH):
			xs.append(floori(roll() * 2))
		r.xs = xs
		r.xsn = int(r.get("xsn", 0))

static func _pool_next() -> float:
	var r := _rom()
	var i := int(r.xn)
	r.xn = i + 1
	return float(r.x[i]) if i < r.x.size() else roll()

static func template(kind: String, id: int) -> Dictionary:
	var src := XDB.rec("Weapons" if kind == "weapon" else "Armors", id)
	if src.is_empty(): return {}
	var item := src.duplicate(true)
	item.kind = kind
	item.base = float(id)
	item["affixIds"] = []
	item["upgradeSlots"] = int(item.get("equipment", {}).get("slots", 6))
	item["originalUpgradeSlots"] = item.upgradeSlots
	item["boostCount"] = 0
	item["upgrades"] = []
	item["baseName"] = str(item.name)
	return item

static func create(kind: String, id: int) -> Dictionary:
	var item := template(kind, id)
	if item.is_empty(): return {}
	var definition: Dictionary = item.get("equipment", {})
	var table := "Weapons" if kind == "weapon" else "Armors"
	if item.get("meta", {}).has("prefixSuffixUseArmorDatabase"): table = "Armors"
	if item.get("meta", {}).has("prefixSuffixUseWeaponDatabase"): table = "Weapons"
	for row in definition.get("affixes", []):
		_pool_enter(true)     # DreamX.RandomPrefixSuffix.choose
		var dice := floori(_pool_next() * 100) + 1
		var choices: Array = row.choices.duplicate()
		choices.sort_custom(func(a,b):return a.chance < b.chance)
		for choice in choices:
			var ids: Array = choice.ids.filter(func(n): return not XDB.rec(table,int(n)).is_empty())
			if ids.is_empty(): continue
			if dice > int(choice.chance):
				dice -= int(choice.chance)
				continue
			_pool_enter()         # DreamX.randomArrayElement
			var affix_id := int(ids[mini(floori(_pool_next()*ids.size()),ids.size()-1)])
			combine(item, XDB.rec(table,affix_id), str(row.kind))
			item.affixIds.append({"table":table,"id":affix_id,"kind":row.kind})
			break
	# YEP_CoreEngine 备注参数覆盖合并值；原版处理完这些标签才掷属性浮动。
	for m in RegEx.create_from_string("(?i)<(HP|MAXHP|MAX HP|MHP|MP|MAXMP|MAX MP|MMP|ATK|STR|DEF|MAT|INT|SPI|MDF|RES|AGI|SPD|LUK):\\s*([+-]\\d+)>").search_all(str(item.note)):
		var p := param_id(m.get_string(1))
		item.params[p] = int(m.get_string(2))
	var variance := int(item.get("meta", {}).get("Random Variance", definition.get("variance",0)))
	_pool_enter()             # ItemManager.randomizeInitialStats
	for i in range(8):
		if float(item.params[i]) != 0 and variance >= 0:
			var original := float(item.params[i])
			var value := original + floorf(_pool_next() * (variance*2+1) - variance)
			item.params[i] = maxf(0,value) if original>=0 else value
	var slots := int(item.upgradeSlots)
	var span := int(definition.get("slotVariance",6))
	if slots > 0 and span > 0:
		slots = clampi(slots + floori(roll() * (span*2+1)-span),0,int(XDB.plugin("YEP_X_ItemUpgradeSlots").get("MAX Slots",12)))
	item.upgradeSlots = slots
	item.originalUpgradeSlots = slots
	item.baseName = str(item.name)
	return item

static func combine(item: Dictionary, affix: Dictionary, kind: String) -> void:
	var meta: Dictionary = affix.get("meta", {})
	if not meta.has("prefixSuffixDontAddName"):
		var text := str(meta.get("prefixSuffixName",affix.name))
		item.name = (text + str(item.name) if kind == "prefix" else str(item.name) + text).strip_edges()
	item.price = int(item.price) + int(affix.get("price",0))
	item.description = str(item.description) + str(affix.get("description",""))
	item.note = str(item.note) + "\n" + str(affix.get("note",""))
	item.meta.merge(meta,true)
	item.traits.append_array(affix.get("traits",[]).duplicate(true))
	for i in range(8): item.params[i] = float(item.params[i]) + float(affix.params[i])
	if meta.has("prefixSuffixReplaceIcon"):item.iconIndex = affix.iconIndex
	if meta.has("prefixSuffixReplaceAnim"):item.animationId = affix.animationId
	if meta.has("prefixSuffixReplaceWeaponType"):item.wtypeId = affix.wtypeId
	if meta.has("prefixSuffixReplaceArmorType"):item.atypeId = affix.atypeId
	merge_yep(item,affix)
	# 词缀上的套装标签也计入同一实例。
	var suits: Array = item.equipment.get("suits",[])
	suits.append_array(affix.get("equipment",{}).get("suits",[]))
	item.equipment.suits = suits

static func param_id(text: String) -> int:
	var aliases := {"HP":0,"MAXHP":0,"MAX HP":0,"MHP":0,"MP":1,"MAXMP":1,"MAX MP":1,"MMP":1,"ATK":2,"STR":2,"DEF":3,"MAT":4,"INT":4,"SPI":4,"MDF":5,"RES":5,"AGI":6,"SPD":6,"LUK":7}
	return int(aliases.get(text.to_upper(),-1))

static func quality(item: Dictionary) -> int:
	return clampi(int(item.get("meta",{}).get("quality",0)),0,15)

static func quality_name(item: Dictionary) -> String:
	var names = JSON.parse_string(str(XDB.plugin("ItemQuality").get("QualitiesName","[]")))
	return str(names[quality(item)]) if names is Array and names.size() > quality(item) else "普通"

static func color(item: Dictionary) -> Color:
	var text := str(XDB.plugin("ItemQuality").get("QualitiesColor",""))
	var colors := RegEx.create_from_string("rgba\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*([\\d.]+)\\s*\\)").search_all(text)
	if colors.size() <= quality(item):return XUI.TEXT
	var c: RegExMatch = colors[quality(item)]
	return Color(float(c.get_string(1))/255,float(c.get_string(2))/255,float(c.get_string(3))/255,float(c.get_string(4)))

static func merge_yep(item: Dictionary, affix: Dictionary) -> void:
	var yep: Dictionary = item.get("yep",{})
	for k in affix.get("yep",{}):
		var value = affix.yep[k]
		if value is Dictionary:
			var pool: Dictionary = yep.get(k,{}).duplicate()
			for id in value: pool[id] = float(pool.get(id,0)) + float(value[id])
			yep[k] = pool
		elif value is Array:
			var list: Array = yep.get(k,[]).duplicate(); list.append_array(value); yep[k] = list
		else:
			yep[k] = float(yep.get(k,0)) + float(value)
	item.yep = yep
