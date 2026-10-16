class_name XOrbs
extends RefCounted
## 宝珠镶嵌规则（正式 installNativeOrbRuntime v2＋YEP_X_AttachAugments＋Star_EquipmentMosaic 的 <继承词缀>），
## 参照 mv_oracle/orb_probe.cjs → generated/oracle/orbs.json，测试 tests/xiyou_orbs。
## - 孔：装备实例获得时排一次（setNewIndependentItem → layoutItem），孔数 = 存档种子＋实例编号的 32 位哈希落到
##   CodexOrbs.sockets 权重（武器 0～3：15/35/35/15，防具 0～2：35/45/20），读档重来不变。武器、副手、神武
##   （etype 1/2/17）是「武器宝珠」孔，其余「防具宝珠」孔。字段照 YEP：augmentSlots／augmentSlotEnable／augmentSlotItems。
##   实例编号用 Godot 的 instanceId 序号（正式版用独立装备在 $dataWeapons/$dataArmors 里的编号），两边哈希函数逐位相同。
## - 可镶（Window_AugmentItemList）：背包里注明了这种孔的物品（<Augment: 类型>），按物品 ID；孔里已有宝珠时首行是「取下」。
##   新宝珠（CodexOrbs.items）只能镶自己那种孔，同一件装备同类只能一颗（canAttach）；原作宝珠不查。
## - 镶嵌（applyAugmentEffects，gain 1）：孔里有宝珠先取下（执行卸下行、退回背包），再执行镶嵌行、扣一颗。
##   数据里用到的效果行只有 Element Amplify n: ±x%（装备的元素增幅）、参数: ±x%（特性 21／22／23）、参数: ±x（装备属性）；
##   其余 YEP 效果行（攻击属性、状态、技能、改名、改图标……）数据未用，未移植。卸下行照 reverseAugmentAutoLine 反转。
##   新宝珠加的特性带「类:阶」标记（_codexOrb），角色身上同类只保留阶位最高的 3 件装备的标记特性（capDrops，阶位同则装备栏靠前优先）。
## - <继承词缀>：原作宝珠把这段备注接到装备备注、标签并入 meta（正式 re 带 g 标志跨行续用 lastIndex，照搬：
##   紧接一次命中的下一行从上次位置起找，通常落空）。其中 ShareLearnSkill（Star_SkilsShare 共享学技能）尚未移植，所以原作宝珠的技能效果暂不生效。
## - 套装（activeSets）：全身装备集齐某套的 2／3 种组件（同类取最高阶）按最低阶位算，通用效果只取最高一套（全部伤害 ×(1+x%)）。
## 未移植：神秘珠掉落、宝珠坊（鉴定、兑换、分解、暂存）、旧档孔位重排（Godot 存档从来没有旧孔位）、套装伤害钩子（见 general_set）。

const NONE := "none"
const WEAPON_TYPE := "武器宝珠"
const ARMOR_TYPE := "防具宝珠"
const TOAST_SLOT := "宝珠孔已变化，请重新选择装备孔位"
const TOAST_ATTACH := "宝珠孔类型不符，或同一件装备已有同类新宝珠"
const XPARAMS := ["HIT", "EVA", "CRI", "CEV", "MEV", "MRF", "CNT", "HRG", "MRG", "TRG"]
const SPARAMS := ["TGR", "GRD", "REC", "PHA", "MCR", "TCR", "PDR", "MDR", "FDR", "EXR"]
const PARAM_NAMES := [["MAXHP", "MHP", "MAX HP", "HP"], ["MAXMP", "MMP", "MAX MP", "MP"], ["ATK", "STR"], ["DEF"], ["MAT", "INT", "SPI"], ["MDF", "RES"], ["AGI", "SPD"], ["LUK"]]

static var _parsed := {}


static func config() -> Dictionary:
	var c = XDB.table("CodexOrbs")
	return c if c is Dictionary else {}


# ---- 32 位整数运算（JS Math.imul、>>>、|0 逐位照搬）----
static func _u32(x: int) -> int:
	return x & 0xFFFFFFFF

static func _imul(a: int, b: int) -> int:
	a = _u32(a)
	b = _u32(b)
	return _u32(((((a >> 16) * b) & 0xFFFF) << 16) + (a & 0xFFFF) * b)

## hash32（字符串按 UTF-16 码元，同 JS charCodeAt）
static func hash32(text: String) -> int:
	var units := text.to_utf16_buffer()
	var n := units.size() / 2
	var h := _u32(1779033703 ^ n)
	for i in range(n):
		var c := units[i * 2] | (units[i * 2 + 1] << 8)
		h = _imul(h ^ c, 3432918353)
		h = _u32((h << 13) | (h >> 19))
	h = _imul(h ^ (h >> 16), 2246822507)
	h = _imul(h ^ (h >> 13), 3266489909)
	return _u32(h ^ (h >> 16))

## 由哈希得 [0,1) 的值（roll／socketCount 共用的混合步骤）
static func mix(h: int) -> float:
	var t := _u32(h + 0x6D2B79F5)
	t = _imul(t ^ (t >> 15), t | 1)
	t = _u32(t ^ _u32(t + _imul(t ^ (t >> 7), t | 61)))
	return float(_u32(t ^ (t >> 14))) / 4294967296.0


# ---- 孔 ----
static func is_weapon_socket(eq: Dictionary) -> bool:
	var etypes: Array = config().get("sockets", {}).get("weaponEtypes", [1, 2, 17])
	return str(eq.get("kind", "")) == "weapon" or etypes.any(func(v): return int(v) == int(eq.get("etypeId", 0)))

static func socket_type(eq: Dictionary) -> String:
	return WEAPON_TYPE if is_weapon_socket(eq) else ARMOR_TYPE

## socketCount：key ＝ w/a ＋实例编号；权重取 sockets.weapon／armor
static func socket_count_for(seed: int, weapon_socket: bool, is_weapon: bool, number: int) -> int:
	var sockets: Dictionary = config().get("sockets", {})
	var weights: Array = sockets.get("weapon", [15, 35, 35, 15]) if weapon_socket else sockets.get("armor", [35, 45, 20])
	var key := ("w" if is_weapon else "a") + str(number)
	var x := mix(hash32(str(seed) + ":socket:" + key)) * 100.0
	var sum := 0.0
	for i in range(weights.size()):
		sum += float(weights[i])
		if x < sum:
			return i
	return weights.size() - 1

static func instance_number(eq: Dictionary) -> int:
	return int(str(eq.get("instanceId", "xg:0")).get_slice(":", 1))

## 获得时排孔的键：正式 DataManager.isWeapon（DreamX）先看 wtypeId 非 0，否则查 $dataWeapons——此刻新实例还没放进去，
## 所以无类型武器（wtypeId 0，如水果刀）与防具同样用 a＋编号（照搬）
static func socket_count(eq: Dictionary, seed: int) -> int:
	var w := str(eq.get("kind", "")) == "weapon" and int(eq.get("wtypeId", 0)) != 0
	return socket_count_for(seed, is_weapon_socket(eq), w, instance_number(eq))

## layoutItem：新实例排孔（已有孔的不动）
static func layout(eq: Dictionary, seed: int) -> void:
	if eq.is_empty() or eq.has("augmentSlots") or config().is_empty():
		return
	var type := socket_type(eq)
	var n := socket_count(eq, seed)
	var slots := []
	var enable := []
	var held := []
	for i in range(n):
		slots.append(type)
		enable.append(true)
		held.append(NONE)
	eq.augmentSlots = slots
	eq.augmentSlotEnable = enable
	eq.augmentSlotItems = held

## checkAugmentSlots：补齐 enable／items
static func ensure(eq: Dictionary) -> void:
	if not eq.has("augmentSlots"):
		eq.augmentSlots = []
	var enable: Array = eq.get("augmentSlotEnable", [])
	var held: Array = eq.get("augmentSlotItems", [])
	for i in range(eq.augmentSlots.size()):
		if enable.size() <= i:
			enable.append(true)
		if held.size() <= i:
			held.append(NONE)
	eq.augmentSlotEnable = enable
	eq.augmentSlotItems = held

static func slots(eq: Dictionary) -> Array:
	return eq.get("augmentSlots", [])

static func valid_slot(eq: Dictionary, slot: int) -> bool:
	var s: Array = slots(eq)
	return not eq.is_empty() and slot >= 0 and slot < s.size() and s[slot] is String and str(s[slot]).strip_edges() != "" \
		and not (eq.get("augmentSlotEnable", []).size() > slot and eq.augmentSlotEnable[slot] == false)

## augmentInSlot：孔里的宝珠物品（空孔或找不到返回 {}）
static func gem_in_slot(eq: Dictionary, slot: int) -> Dictionary:
	var held: Array = eq.get("augmentSlotItems", [])
	if slot < 0 or slot >= held.size():
		return {}
	var m := RegEx.create_from_string("(?i)ITEM (\\d+)").search(str(held[slot]))
	return XDB.rec("Items", int(m.get_string(1))) if m else {}


# ---- 宝珠数据 ----
## processAugmentNotetags2：{types, attach{类型: 行}, detach{类型: 行}}
static func parse(gem: Dictionary) -> Dictionary:
	var id := int(gem.get("id", 0))
	if _parsed.has(id):
		return _parsed[id]
	var out := {"types": [], "attach": {}, "detach": {}}
	var mode := "NONE"
	var type := ""
	var open := RegEx.create_from_string("(?i)<AUGMENT( ATTACH| DETACH| ATTACH EVAL| DETACH EVAL)?:[ ](.*)>")
	var close := RegEx.create_from_string("(?i)<\\/AUGMENT( ATTACH| DETACH| ATTACH EVAL| DETACH EVAL)?:[ ](.*)>")
	for line in RegEx.create_from_string("[\\r\\n]+").sub(str(gem.get("note", "")), "\n", true).split("\n"):
		var c := close.search(line)
		if c:
			mode = "NONE"
			continue
		var o := open.search(line)
		if o:
			mode = o.get_string(1).strip_edges().to_upper()
			if mode == "":
				mode = "AUTO"
			type = o.get_string(2).to_upper().strip_edges()
			if not out.types.has(type):
				out.types.append(type)
			for k in ["attach", "detach"]:
				if not out[k].has(type):
					out[k][type] = []
			continue
		match mode:
			"NONE":
				pass
			"ATTACH":
				out.attach[type].append(line)
			"DETACH":
				out.detach[type].append(line)
			"ATTACH EVAL", "DETACH EVAL":
				pass   # 数据未用
			_:
				out.attach[type].append(line)
				out.detach[type].append(reverse_line(line))
	_parsed[id] = out
	return out

## reverseAugmentAutoLine
static func reverse_line(line: String) -> String:
	for pair in [["ADD", "REMOVE"], ["REMOVE", "ADD"], ["CHANGE", "CANCEL"], ["CANCEL", "CHANGE"]]:
		var m := RegEx.create_from_string("(?i)" + pair[0] + "[ ](.*):(.*)").search(line)
		if m:
			return pair[1] + " " + m.get_string(1) + ":" + m.get_string(2)
	if RegEx.create_from_string("(?i)(.*):[ ]([\\+\\-]\\d+)([%％])").search(line):
		return line
	var m := RegEx.create_from_string("(?i)(.*):[ ]([\\+\\-]\\d+)").search(line)
	if m:
		var v := -int(m.get_string(2))
		return m.get_string(1) + ": " + ("+" + str(v) if v > 0 else str(v))
	return line

## 新宝珠 {family, rank}；不是新宝珠返回 {}
static func spec(id: int) -> Dictionary:
	var s = config().get("items", {}).get(str(id))
	return s if s is Dictionary else {}

static func slot_of(id: int) -> String:
	var s := spec(id)
	if s.is_empty():
		return WEAPON_TYPE
	return str(config().families[int(s.family)].get("slot", WEAPON_TYPE))

## canAttach（新宝珠：孔类型相符、同一件装备没有同类新宝珠；原作宝珠一律可以）
static func can_attach(eq: Dictionary, gem: Dictionary, slot: int) -> bool:
	var s := spec(int(gem.get("id", 0))) if not gem.is_empty() else {}
	if s.is_empty():
		return true
	var ss: Array = slots(eq)
	if slot < 0 or slot >= ss.size() or str(ss[slot]).to_upper().strip_edges() != slot_of(int(gem.id)):
		return false
	if eq.get("augmentSlotEnable", []).size() > slot and eq.augmentSlotEnable[slot] == false:
		return false
	var held: Array = eq.get("augmentSlotItems", [])
	for i in range(held.size()):
		if i == slot:
			continue
		var other := spec(int(gem_in_slot(eq, i).get("id", 0)))
		if not other.is_empty() and int(other.family) == int(s.family):
			return false
	return true

## Window_AugmentItemList 的行：[{rec（取下为 {}）, count, enabled}]
static func list(eq: Dictionary, slot: int, s: XState) -> Array:
	var out := []
	if not valid_slot(eq, slot):
		return out
	ensure(eq)
	var type := str(eq.augmentSlots[slot]).to_upper().strip_edges()
	var ids: Array = s.items.keys().map(func(k): return int(k))
	ids.sort()
	for id in ids:
		var rec := XDB.rec("Items", id)
		if rec.is_empty() or s.item_count(id) <= 0 or not parse(rec).types.has(type):
			continue
		out.append({"rec": rec, "count": s.item_count(id), "enabled": can_attach(eq, rec, slot)})
	if str(eq.augmentSlotItems[slot]) != NONE:
		out.push_front({"rec": {}, "count": 0, "enabled": true})
	return out


# ---- 镶嵌／取下 ----
## applyAugmentEffects（Codex 外层先查孔与可镶）；成功返回 ""，否则返回提示文字（正式版同时响蜂鸣）
static func apply(eq: Dictionary, gem: Dictionary, slot: int, s: XState, gain := 1) -> String:
	if eq.is_empty():
		return TOAST_SLOT
	ensure(eq)
	if not valid_slot(eq, slot):
		return TOAST_SLOT
	if not gem.is_empty() and not spec(int(gem.id)).is_empty() and (not can_attach(eq, gem, slot) or (gain > 0 and s.item_count(int(gem.id)) < gain)):
		return TOAST_ATTACH
	if str(eq.augmentSlotItems[slot]) != NONE:
		var old := remove_from_slot(eq, slot)
		if not old.is_empty():
			s.gain_item(int(old.id), gain)
	install_to_slot(eq, gem, slot)
	if not gem.is_empty():
		s.gain_item(int(gem.id), -gain)
	return ""

## installAugmentToSlot（YEP）＋ Codex「类:阶」标记 ＋ Star_EquipmentMosaic 继承词缀
static func install_to_slot(eq: Dictionary, gem: Dictionary, slot: int) -> void:
	if gem.is_empty():
		eq.augmentSlotItems[slot] = NONE
		return
	var type := str(eq.augmentSlots[slot]).to_upper().strip_edges()
	eq.augmentSlotItems[slot] = "item %d" % int(gem.id)
	var s := spec(int(gem.id))
	var tag := "" if s.is_empty() else "%d:%d" % [int(s.family), int(s.rank)]
	for line in parse(gem).attach.get(type, []):
		effect(line, eq, true, tag)
	_inherit(eq, gem, true)

## removeAugmentFromSlot：执行卸下行，返回取下的宝珠
static func remove_from_slot(eq: Dictionary, slot: int) -> Dictionary:
	var type := str(eq.augmentSlots[slot]).to_upper().strip_edges()
	var gem := gem_in_slot(eq, slot)
	if gem.is_empty():
		return gem
	for line in parse(gem).detach.get(type, []):
		effect(line, eq, false, "")
	_inherit(eq, gem, false)
	return gem

## processAugmentEffect（数据用到的几种）
static func effect(line: String, eq: Dictionary, attach: bool, tag: String) -> void:
	var m := RegEx.create_from_string("(?i)((?:(ELEMENT AMPLIFY))[ ](\\d+):[ ]([\\+\\-]\\d+)([%％]))").search(line)
	if m == null:
		m = RegEx.create_from_string("(?i)((?:ELEMENT AMPLIFY)[ ](.*):[ ]([\\+\\-]\\d+)([%％]))").search(line)
	if m:
		var yep: Dictionary = eq.get("yep", {})
		var amp: Dictionary = yep.get("elementAmplify", {})
		var key := m.get_string(3)
		amp[key] = float(amp.get(key, 0.0)) + (1.0 if attach else -1.0) * float(m.get_string(4)) / 100.0
		yep.elementAmplify = amp
		eq.yep = yep
		return
	m = RegEx.create_from_string("(?i)(.*):[ ]([\\+\\-]\\d+)([%％])").search(line)
	if m:
		_param_rate(eq, m.get_string(1).to_upper().strip_edges(), float(m.get_string(2)), attach, tag)
		return
	m = RegEx.create_from_string("(?i)(.*):[ ]([\\+\\-]\\d+)").search(line)
	if m:
		_param_plus(eq, m.get_string(1).to_upper().strip_edges(), int(m.get_string(2)))

static func _param_id(name: String) -> int:
	for i in range(PARAM_NAMES.size()):
		if PARAM_NAMES[i].has(name):
			return i
	return -1

## applyAugmentParamRate：属性 21（1＋x%），XPARAM 22（x%），SPARAM 23（1＋x%）；卸下删最后一条相同的特性
static func _param_rate(eq: Dictionary, name: String, value: float, attach: bool, tag: String) -> void:
	var v := value * 0.01
	var rate := v + 1.0
	var code := 21
	var id := _param_id(name)
	if id < 0:
		if XPARAMS.has(name):
			code = 22
			id = XPARAMS.find(name)
			rate -= 1.0
		elif SPARAMS.has(name):
			code = 23
			id = SPARAMS.find(name)
		else:
			return
	var traits: Array = eq.traits
	if attach:
		var t := {"code": float(code), "dataId": float(id), "value": rate}
		if tag != "":
			t["_codexOrb"] = tag
		traits.append(t)
		return
	for i in range(traits.size() - 1, -1, -1):
		var t: Dictionary = traits[i]
		if int(t.code) == code and int(t.dataId) == id and float(t.value) == rate:
			traits.remove_at(i)
			return

## applyAugmentParamPlus
static func _param_plus(eq: Dictionary, name: String, value: int) -> void:
	var id := _param_id(name)
	if id >= 0:
		eq.params[id] = float(eq.params[id]) + value
	elif name in ["PRICE", "COST"]:
		eq.price = int(eq.get("price", 0)) + value

## Star_EquipmentMosaic：<继承词缀> … </继承词缀> 并入装备备注与 meta；取下时从备注删去、meta 删键
static func _inherit(eq: Dictionary, gem: Dictionary, attach: bool) -> void:
	var lines := RegEx.create_from_string("[\\r\\n]+").sub(str(gem.get("note", "")), "\n", true).split("\n")
	var re := RegEx.create_from_string("<([^<>:]+)(:?)([^>]*)>")
	var inside := false
	var last := 0   # 正式 re 带 g：上次命中后 lastIndex 留在原处，落空归零
	var meta: Dictionary = eq.get("meta", {})
	for line in lines:
		if line == "<继承词缀>" or inside:
			inside = true
			if line == "<继承词缀>":
				eq.note = str(eq.get("note", "")) + "\n"
			if line == "</继承词缀>":
				inside = false
			elif line != "<继承词缀>":
				if attach:
					eq.note = str(eq.get("note", "")) + line
				else:
					var note := str(eq.get("note", ""))
					var at := note.find(line)
					if at >= 0:
						eq.note = note.substr(0, at) + note.substr(at + line.length())
				var m := re.search(line, last) if last <= line.length() else null
				if m:
					last = m.get_end()
					if attach:
						meta[m.get_string(1)] = m.get_string(3) if m.get_string(2) == ":" else true
					else:
						meta.erase(m.get_string(1))
				else:
					last = 0
	eq.meta = meta


# ---- 角色：同类上限与套装 ----
## capDrops：要剔除的特性（按对象身份）；没有超过上限的类时返回 []
static func cap_drops(equips: Array) -> Array:
	var cap := int(config().get("familyCap", 0))
	if cap <= 0:
		return []
	var by := {}
	for i in range(equips.size()):
		var eq = equips[i]
		if eq == null or not eq is Dictionary or eq.is_empty():
			continue
		var seen := {}
		for t in eq.get("traits", []):
			if not t.has("_codexOrb"):
				continue
			var parts := str(t._codexOrb).split(":")
			if seen.has(parts[0]):
				continue
			seen[parts[0]] = true
			if not by.has(parts[0]):
				by[parts[0]] = []
			by[parts[0]].append({"eq": eq, "rank": int(parts[1]), "i": i})
	var drop := []
	for f in by:
		var rows: Array = by[f]
		if rows.size() <= cap:
			continue
		rows.sort_custom(func(x, y): return x.rank > y.rank or (x.rank == y.rank and x.i < y.i))
		for x in rows.slice(cap):
			for t in x.eq.traits:
				if t.has("_codexOrb") and str(t._codexOrb).get_slice(":", 0) == f:
					drop.append(t)
	return drop

static func filter_traits(list: Array, equips: Array) -> Array:
	var drop := cap_drops(equips)
	if drop.is_empty():
		return list
	return list.filter(func(t): return not drop.any(func(d): return is_same(d, t)))

## activeSets：[{index, name, rank, pieces, rate, general, skills}]
static func active_sets(equips: Array) -> Array:
	var cfg := config()
	if cfg.is_empty():
		return []
	var owned := {}
	for eq in equips:
		if eq == null or not eq is Dictionary or eq.is_empty():
			continue
		for i in range(eq.get("augmentSlotItems", []).size()):
			var s := spec(int(gem_in_slot(eq, i).get("id", 0)))
			if not s.is_empty():
				owned[int(s.family)] = maxi(int(owned.get(int(s.family), 0)), int(s.rank))
	var general: Dictionary = cfg.get("general", {"two": [], "three": []})
	var out := []
	for i in range(cfg.sets.size()):
		var set: Dictionary = cfg.sets[i]
		var ranks: Array = set.families.map(func(f): return int(owned.get(int(f), 0))).filter(func(r): return r > 0)
		if ranks.size() < 2:
			continue
		var rank: int = ranks.min()
		var three := ranks.size() == 3
		out.append({"index": i, "name": set.name, "rank": rank, "pieces": ranks.size(),
			"rate": (set.three if three else set.two)[rank - 1], "general": (general.three if three else general.two)[rank - 1],
			"skills": set.skills.duplicate()})
	return out

## generalSet：通用效果最高的一套（没有返回 {}）。伤害钩子（技能伤害 type 非 3/4 时全部伤害 ×(1＋general%)）随
## Codex 伤害钩子框架接入，见 damage.gd 头注释。
static func general_set(equips: Array) -> Dictionary:
	var best := {}
	for s in active_sets(equips):
		if best.is_empty() or float(s.general) > float(best.general):
			best = s
	return best
