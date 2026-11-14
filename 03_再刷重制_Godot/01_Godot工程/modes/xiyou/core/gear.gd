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
## Test-only bounded tape. The native fixture explicitly materializes its repeated sequence.
static var roll_seq: Array = []
static var roll_count := 0
## 没有当前存档时（无界面测试）用的池
static var _fallback := {}
static var _fallback_random := XRandomStream.create("68fcb84301a4a9e1", "equipment")

## 临时换掉 Math.random（深渊商人抽取 M.generate 把 Math.random 换成本轮种子的随机数；见 XAbyssMerchant.generate）
static var roll_fn := Callable()

## 相当于 Math.random
static func roll(owner: XState = null) -> float:
	if roll_fn.is_valid():
		return float(roll_fn.call())
	if not roll_seq.is_empty():
		roll_count += 1
		if roll_count > roll_seq.size():
			push_error("equipment_random_tape_exhausted")
			return 0.0
		return float(roll_seq[roll_count - 1])
	if force_roll >= 0:
		return force_roll
	var actual_owner := owner if owner != null else XState.current
	return (actual_owner.equipment_random() if actual_owner != null else _fallback_random).next_float("equipment")

static func _rom(owner: XState = null) -> Dictionary:
	var actual_owner := owner if owner != null else XState.current
	return actual_owner.rom if actual_owner != null else _fallback

## 测试用：清空随机池（参照探针每件装备前也清空）
static func reset_pool() -> void:
	var r := _rom()
	r.x = []
	r.xn = 0
	r.xs = []
	r.xsn = 0

static func _pool_enter(with_bits := false, owner: XState = null) -> void:
	var r := _rom(owner)
	if r.get("x", []).size() != ROM_LENGTH or int(r.get("xn", 0)) > ROM_REFRESH:
		var x := []
		for i in range(ROM_LENGTH):
			x.append(roll(owner))
		r.x = x
		r.xn = 0
	if with_bits and (r.get("xs", []).size() != ROM_LENGTH or int(r.get("xsn", 0)) > ROM_REFRESH):
		var xs := []
		for i in range(ROM_LENGTH):
			xs.append(floori(roll(owner) * 2))
		r.xs = xs
		r.xsn = int(r.get("xsn", 0))

static func _pool_next(owner: XState = null) -> float:
	var r := _rom(owner)
	var i := int(r.xn)
	r.xn = i + 1
	return float(r.x[i]) if i < r.x.size() else roll(owner)

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
	_apply_note_params(item)
	return item

## YEP_CoreEngine 备注参数（<atk: +20> 等）覆盖基础值；初始装备不掷浮动，但这一步照做（天虎令的布丁 atk／mat 20 而非数据库 25）。
static func _apply_note_params(item: Dictionary) -> void:
	for m in RegEx.create_from_string("(?i)<(HP|MAXHP|MAX HP|MHP|MP|MAXMP|MAX MP|MMP|ATK|STR|DEF|MAT|INT|SPI|MDF|RES|AGI|SPD|LUK):\\s*([+-]\\d+)>").search_all(str(item.note)):
		item.params[param_id(m.get_string(1))] = int(m.get_string(2))

static func create(kind: String, id: int, owner: XState = null) -> Dictionary:
	return roll_item(template(kind, id), owner)

## 对一份已备好的模板掷词缀、属性浮动与插槽（DreamX.RandomPrefixSuffix.makeItem 那段）；云裳天衣铺开工时用改过的模板调它
static func roll_item(item: Dictionary, owner: XState = null) -> Dictionary:
	if item.is_empty(): return {}
	var kind := str(item.kind)
	var definition: Dictionary = item.get("equipment", {})
	var table := "Weapons" if kind == "weapon" else "Armors"
	if item.get("meta", {}).has("prefixSuffixUseArmorDatabase"): table = "Armors"
	if item.get("meta", {}).has("prefixSuffixUseWeaponDatabase"): table = "Weapons"
	for row in ([] if XTestMode.boost_depth > 0 else definition.get("affixes", [])):
		if XTianqiAffixRoll.skips_row(row, owner if owner != null else XState.current, table):
			continue  # 天启篇：原版随机词缀行不掷（必出的行照合），改掷天启篇词条（XTianqiAffixRoll，见末尾）
		var affix_id := choose_affix(row.choices, table, owner)
		if affix_id > 0:
			combine(item, XDB.rec(table, affix_id), str(row.kind))
			item.affixIds.append({"table": table, "id": affix_id, "kind": row.kind})
	if XTestMode.boost_depth > 0:
		XTestMode.roll_affixes(item, definition.get("affixes", []), table)  # 测试模式：掉落装备词缀加速
	# YEP_CoreEngine 备注参数覆盖合并值；原版处理完这些标签才掷属性浮动。
	_apply_note_params(item)
	var variance := int(item.get("meta", {}).get("Random Variance", definition.get("variance",0)))
	_pool_enter(false, owner)             # ItemManager.randomizeInitialStats
	for i in range(8):
		if float(item.params[i]) != 0 and variance >= 0:
			var original := float(item.params[i])
			var value := original + floorf(_pool_next(owner) * (variance*2+1) - variance)
			item.params[i] = maxf(0,value) if original>=0 else value
	var slots := int(item.upgradeSlots)
	var span := int(definition.get("slotVariance",6))
	if slots > 0 and span > 0:
		slots = clampi(slots + floori(roll(owner) * (span*2+1)-span),0,int(XDB.plugin("YEP_X_ItemUpgradeSlots").get("MAX Slots",12)))
	item.upgradeSlots = slots
	item.originalUpgradeSlots = slots
	item.baseName = str(item.name)
	XTianqiAffixRoll.apply(item, owner if owner != null else XState.current)  # 天启篇：掷天启篇词条
	return item

## DreamX.RandomPrefixSuffix.choose（Star_RomGetItems 版，外面再包 v0.62 CodexAffixRate）：一行词条选项掷一次，返回词条编号，不中为 0。
## 先取一个预掷随机数 r；高阶行且难度倍率≠1 走 XAffixRate.pick（roll＝r×100 比浮动后的概率），否则原掷法（整数骰 floor(r×100)+1）。
## 中了再取一个预掷随机数挑行内词条（DreamX.randomArrayElement）。
static func choose_affix(row_choices: Array, table: String, owner: XState = null) -> int:
	_pool_enter(true, owner)
	var r := _pool_next(owner)
	var route_state := owner if owner != null else XState.current
	var hit := []
	if XAffixRate.applies(route_state, row_choices, table):
		hit = XAffixRate.pick(route_state, row_choices, table, r)
	else:
		var dice := floori(r * 100) + 1
		var choices: Array = row_choices.duplicate()
		choices.sort_custom(func(a, b): return a.chance < b.chance)
		for choice in choices:
			var ids: Array = choice.ids.filter(func(n): return valid_affix(table, int(n)))
			if ids.is_empty(): continue
			if dice > int(choice.chance):
				dice -= int(choice.chance)
				continue
			hit = ids
			break
	if hit.is_empty():
		return 0
	_pool_enter(false, owner)         # DreamX.randomArrayElement
	return int(hit[mini(floori(_pool_next(owner) * hit.size()), hit.size() - 1)])

## DreamX.RandomPrefixSuffix.isValidItem：记录存在，且不是角色专武（v0.37 起「天外天·」开头、v0.56.01 起备注带 <req_actors:>
## 的装备不再当词缀，见 v0.62.12 installIntegratedV029Runtime.js exclusiveAffix；已生成的旧装备不改）
## O-289·专武不当词缀（跟到 v0.62.12）：false＝回到 v0.28，专武照样能被抽成词缀
static var EXCLUSIVE_V056 := true
static func valid_affix(table: String, id: int) -> bool:
	var r := XDB.rec(table, id)
	if XAlienHide.blocks_base("weapon" if table == "Weapons" else "armor", id):
		return false  # installAlienationHide 包 isValidItem：隐藏生效时残响不当词缀（O-283）
	return not r.is_empty() and not (EXCLUSIVE_V056 and exclusive_affix(r))

## v0.57 读档还原专武前缀（v0.62.12 installIntegratedV029Runtime.js U.revertExclusiveAffixes，extractSaveContents 包装）：
## v0.37 前掉落、抽到了专武词缀的武器（如「卍解-斩月练习剑」）读档时转回普通装备。原版拿存档里的模板比对；重制不存模板，
## 按 affixIds 用现在的数据重拼一份模板 t（底装备＋各词缀＋备注参数，就是掉落时那份），底装备 b 是现在的底装备：
## 特效／备注／说明＝b 的那段＋实例在 t 之后追加的，属性＝b＋实例−t（底值不为负的夹到 0），价格同理；名字去掉专武前缀。
## 属性浮动：原版掉落掷两次（makeItem 给模板一次、gainItem 给实例一次），还原丢掉模板那次、留实例那次；重制只掷一次，
## t 取不带浮动的模板，所以留下的是这一次（幅度同原版，是专武词缀的 Random Variance），强化加的照留。
## 原版把整份模板换掉，同一件上的其它词缀（属性、特效）也一起没了、名字里的后缀字留着（原版 bug，审查 53 P3-1）。
## 重制默认只去掉专武那段：b 取「底装备＋其余非专武词缀」重拼的模板（affix_template 只带非专武的 affixIds），
## 下面各项都对这个 b 算，其余词缀的属性、特效、名字、affixIds 照留；REVERT_KEEP_OTHER_AFFIXES = false 回到原版整份换掉。
## 备注解析出的 meta／yep／套装：被词缀改过的项换回 b 的，其余（强化加的等）不动。对不上（实例备注、说明不以 t 开头，特效开头不是 t 的）的不动，记进 skipped。
## 只跑一次：还原前把改动的字段整份存进 _affixRevert，有这个键的不再处理。只管武器（原版 _independentWeapons）。
## 开关同 EXCLUSIVE_V056（false＝v0.28，读档不还原）。
static var last_affix_revert := {}
## O-232·读档还原只去专武词缀：false＝照 v0.62.12 原版整份换回底装备（同件其它词缀一起没了）
static var REVERT_KEEP_OTHER_AFFIXES := true
const AFFIX_REVERT_FIELDS := ["name", "baseName", "note", "description", "traits", "params", "price", "meta", "yep", "affixIds", "equipment"]

static func revert_exclusive_affixes(s: XState) -> Dictionary:
	var stat := {"items": [], "skipped": []}
	last_affix_revert = stat
	if not EXCLUSIVE_V056 or s == null:
		return stat
	var all := s.gear.duplicate()
	for a in s.actors.values():
		all.append_array(a.raw_equip_list())
	for w in s.warehouses.values():
		for list in w.get("items", {}).values():
			for v in list:
				if v is Dictionary:
					all.append(v)
	var seen := []
	for item in all:
		if not item is Dictionary or seen.any(func(x): return is_same(x, item)):
			continue
		seen.append(item)
		match _revert_one(item):
			1: stat.items.append(str(item.get("instanceId", "")))
			-1: stat.skipped.append(str(item.get("instanceId", "")))
	return stat

## 1＝还原了，-1＝像旧专武前缀装备但对不上（不动），0＝不相干
static func _revert_one(item: Dictionary) -> int:
	if str(item.get("kind", "")) != "weapon" or item.has("_affixRevert") or (item.get("affixIds", []) as Array).is_empty():
		return 0
	var b := template("weapon", int(item.get("base", 0)))
	if b.is_empty() or exclusive_affix(b):
		return 0
	var t := affix_template(item, b)
	if t.is_empty() or _req_actors_re.search(str(t.note)) == null:
		return 0
	var kept_affixes: Array = []
	if REVERT_KEEP_OTHER_AFFIXES:
		kept_affixes = (item.get("affixIds", []) as Array).filter(func(x): return not exclusive_affix(XDB.rec(str(x.get("table", "Weapons")), int(x.get("id", 0)))))
		if not kept_affixes.is_empty():
			b = affix_template({"kind": "weapon", "base": item.get("base", 0), "affixIds": kept_affixes}, b)
			if b.is_empty():
				return 0
	var own_note := str(item.get("note", ""))
	var own_desc := str(item.get("description", ""))
	var own_traits: Array = item.get("traits", [])
	var t_traits: Array = t.traits
	if not own_note.begins_with(str(t.note)) or not own_desc.begins_with(str(t.description)) or own_traits.size() < t_traits.size() \
			or range(t_traits.size()).any(func(k): return JSON.stringify(own_traits[k]) != JSON.stringify(t_traits[k])):
		return -1
	var backup := {}
	for k in AFFIX_REVERT_FIELDS:
		if item.has(k):
			backup[k] = item[k].duplicate(true) if (item[k] is Dictionary or item[k] is Array) else item[k]
	item["_affixRevert"] = backup
	# 名字：去掉专武前缀（最长的专武名），找不到就把 t 的名字里底装备名之前那段当前缀
	var t_name := str(t.name)
	var prefix := _affix_prefix(t_name)
	var plain := t_name.substr(prefix.length()) if prefix != "" else ""
	var b_name := str(b.name)
	if prefix == "" and t_name.ends_with(b_name):
		prefix = t_name.left(t_name.length() - b_name.length())
		plain = b_name
	if plain == "":
		plain = b_name
	if not kept_affixes.is_empty():
		plain = b_name
	var rename := func(x: String) -> String:
		if not kept_affixes.is_empty() and x.find(t_name) >= 0:
			var at0 := x.find(t_name)
			return x.left(at0) + plain + x.substr(at0 + t_name.length())
		if prefix != "" and x.begins_with(prefix):
			return x.substr(prefix.length())
		var at := x.find(t_name)
		return x if at < 0 else x.left(at) + plain + x.substr(at + t_name.length())
	item.traits = (b.traits as Array).duplicate(true) + own_traits.slice(t_traits.size()).duplicate(true)
	var params: Array = item.params
	for k in range(8):
		var v := float(b.params[k]) + float(params[k]) - float(t.params[k])
		params[k] = maxf(0.0, v) if float(b.params[k]) >= 0 else v
	item.price = maxi(0, int(b.price) + int(item.get("price", 0)) - int(t.price))
	item.description = str(b.description) + own_desc.substr(str(t.description).length())
	item.note = str(b.note) + "\n" + own_note.substr(str(t.note).length())
	item.name = rename.call(str(item.name))
	if item.has("baseName"):
		item.baseName = rename.call(str(item.baseName))
	# 备注解析出的：meta 照原版取 b 的、再留实例上不是备注来的键；yep、套装只换回被词缀改过的项
	var meta: Dictionary = (b.get("meta", {}) as Dictionary).duplicate(true)
	var own_meta: Dictionary = item.get("meta", {})
	for k in own_meta:
		if not (t.get("meta", {}) as Dictionary).has(k):
			meta[k] = own_meta[k]
	item.meta = meta
	var yep: Dictionary = item.get("yep", {})
	var b_yep: Dictionary = b.get("yep", {})
	var t_yep: Dictionary = t.get("yep", {})
	for k in t_yep.keys() + b_yep.keys():
		if JSON.stringify(t_yep.get(k)) == JSON.stringify(b_yep.get(k)):
			continue
		if b_yep.has(k):
			yep[k] = b_yep[k] if not (b_yep[k] is Dictionary or b_yep[k] is Array) else b_yep[k].duplicate(true)
		else:
			yep.erase(k)
	if item.has("yep") or not yep.is_empty():
		item.yep = yep
	var t_suits = t.get("equipment", {}).get("suits", [])
	var b_suits = b.get("equipment", {}).get("suits", [])
	if JSON.stringify(t_suits) != JSON.stringify(b_suits) and item.get("equipment") is Dictionary:
		item.equipment.suits = (b_suits as Array).duplicate(true)
	item.affixIds = kept_affixes.duplicate(true)
	return 1

## DreamX 生成时的模板（getBaseItem 取到的那份）：底装备＋affixIds 里各词缀＋备注参数，不掷浮动。没有词缀就是底装备；
## 词缀记录找不到返回空。b 可传已备好的底装备模板。
static func affix_template(item: Dictionary, b := {}) -> Dictionary:
	if b.is_empty():
		b = template(str(item.get("kind", "")), int(item.get("base", 0)))
	if b.is_empty():
		return {}
	var affixes: Array = item.get("affixIds", [])
	if affixes.is_empty():
		return b
	var t := b.duplicate(true)
	for affix in affixes:
		var rec := XDB.rec(str(affix.get("table", "Weapons")), int(affix.get("id", 0)))
		if rec.is_empty():
			return {}
		combine(t, rec, str(affix.get("kind", "prefix")))
	_apply_note_params(t)
	return t

## 原版 affixPrefix：名字开头最长的专武词缀名（只看数据库里的武器）
static func _affix_prefix(name: String) -> String:
	var best := ""
	var weapons = XDB.table("Weapons")
	for x in (weapons if weapons is Array else []):
		if not x is Dictionary or not exclusive_affix(x):
			continue
		var n := str(x.get("meta", {}).get("prefixSuffixName", x.get("name", "")))
		if n != "" and name.begins_with(n) and n.length() > best.length():
			best = n
	return best

static var _req_actors_re := RegEx.create_from_string("(?i)<req_actors\\s*:")
static func exclusive_affix(r: Dictionary) -> bool:
	if not (r.has("wtypeId") or r.has("atypeId")):
		return false
	return str(r.get("name", "")).begins_with("天外天·") or _req_actors_re.search(str(r.get("note", ""))) != null

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

## 七档品质名（XQuality；排序仍按 quality 的旧档）
static func quality_name(item: Dictionary) -> String:
	return XQuality.grade_name(item)

## 列表名字色（西游 v0.18：有品质按七档，否则按 <ici>）
static func color(item: Dictionary) -> Color:
	return XQuality.list_color(item)

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
