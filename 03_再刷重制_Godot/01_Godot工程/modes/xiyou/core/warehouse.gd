class_name XWarehouse
extends RefCounted
## PH_Warehouse（PHWarehouseManager）：方桌大厅仓库管理员 Map4 EV8「装备道具仓库」＝PHWarehouse create <仓库:999> 再 show <仓库>，
## 「重置仓库」＝remove 再 create（里面的东西全部清掉）。正式版参数：All Together 0（分四类）、Stack Item Quantity 0（容量按件数）。
## 存档：XState.warehouses（正式版 contents.phwarehouse）＝{名字: {title, maxCapacity, currentCapacity, rule, lootBonus,
##   items: {item: [ID], weapon: [装备实例], armor: [装备实例], keyItem: [ID]}, qtty: {item: {"ID": 数}, keyItem: {"ID": 数}}}}；
##   旧Godot档缺字段时为空；已开 EV8 自开关 A 的旧档由 XState.from_dict 补空「仓库:999」，免得第二页只有 show 无法打开。
## 原版的武器、防具都是 YEP 独立装备，仓库记的是实例自己的 ID（存入后实例仍留在数据库里），这里直接存实例；每件 qtty 1。
## 当前仓库、取出／储存、分类（_lastActive／_lastOption／_lastCategory）不存档，读档后回到初值。
## 规则（rule）、loot、add、capacity 指令正式版事件里没有用到，只实现 create／show／remove（其余认作无操作并留在 skipped 外）。

const CATEGORIES := ["item", "weapon", "armor", "keyItem"]
const DEFAULT_CAPACITY := 50

static var last_active := ""
static var last_option := 0          # 0 取出、1 储存
static var last_category := "item"
## O-待定-4（优化登记）：原版存放（PH_Warehouse.js 1099～1103）先记进仓库再 loseItem，吞器占用的供体被 Adv:88 挡下没失去，
## 背包和仓库各有一件（复制）。true＝照常移走（仓库里一件、背包里没了）；false＝照原版复制
static var o_reserved_no_dup := true


## checkSentence：取 <…> 里的内容
static func sentence(s: String) -> String:
	var m := RegEx.create_from_string("<([^)]+)>").search(s)
	return m.get_string(1) if m != null else ""


## createWarehouse：<名字> 或 <名字:容量[:规则]>；已存在不动；都设为当前仓库
static func create(s: XState, text: String) -> void:
	var body := sentence(text)
	if body == "":
		return
	var parts := body.split(":")
	var title := parts[0]
	if not s.warehouses.has(title):
		var cap := DEFAULT_CAPACITY
		if parts.size() >= 2:
			cap = int(parts[1]) if parts[1].strip_edges().is_valid_int() else 0
			if cap <= 0:
				cap = DEFAULT_CAPACITY
		s.warehouses[title] = {"title": title, "maxCapacity": cap, "currentCapacity": 0, "rule": null, "lootBonus": true,
			"items": {"item": [], "weapon": [], "armor": [], "keyItem": []}, "qtty": {"item": {}, "weapon": {}, "armor": {}, "keyItem": {}}}
	last_active = title


## openWarehouse：设为当前仓库（loot 奖励关掉）；返回要不要打开画面（不存在的仓库原版会报错，这里不打开）
static func open(s: XState, text: String) -> bool:
	var title := sentence(text)
	if title == "" or not s.warehouses.has(title):
		return false
	last_active = title
	s.warehouses[title].lootBonus = false
	return true


static func remove(s: XState, text: String) -> void:
	s.warehouses.erase(sentence(text))


## 插件指令 PHWarehouse …（show 由宿主打开画面，见 MVInterpreter）
static func plugin_command(s: XState, args: PackedStringArray) -> bool:
	if args.size() < 3:
		return false
	var rest := " ".join(args.slice(2))
	match args[1]:
		"create":
			create(s, rest)
			return true
		"remove":
			remove(s, rest)
			return true
	return false


static func current(s: XState) -> Dictionary:
	return s.warehouses.get(last_active, {})


static func max_capacity(s: XState) -> int:
	return int(current(s).get("maxCapacity", 0))


static func used(s: XState) -> int:
	return int(current(s).get("currentCapacity", 0))


## checkCapacity
static func has_space(s: XState) -> bool:
	return used(s) < max_capacity(s)


## Window_WarehouseInfo：「可用空间: 剩余 / 上限」
static func info_text(s: XState) -> String:
	return "%s %d / %d" % [str(XDB.plugin("PH_Warehouse").get("Available Space Text", "可用空间:")), max_capacity(s) - used(s), max_capacity(s)]


## 取出列表（makeWarehouseItemList）：该类按存入先后；每项 {rec, qty}
static func stored(s: XState, cat: String) -> Array:
	var w := current(s)
	var out := []
	if w.is_empty():
		return out
	for v in w.items[cat]:
		if v is Dictionary:
			out.append({"rec": v, "qty": 1})
		else:
			var rec := XDB.rec("Items", int(v))
			if not rec.is_empty():
				out.append({"rec": rec, "qty": int(w.qtty[cat].get(str(int(v)), 0))})
	return out


## 储存列表（Window_ItemList.makeItemList，Scene_Warehouse 不列身上装备、不走 Codex 排序）：物品按 ID（itypeId 1／2），
## 套道具置顶与锁定标记；装备按 $gameParty.weapons()/armors() 原序，右侧「序号/9,999」。每项 {rec, count | carry}
static func carried(s: XState, cat: String) -> Array:
	var out := []
	if cat == "item" or cat == "keyItem":
		var ids := s.items.keys().map(func(k): return int(k))
		ids.sort()
		for id in ids:
			var rec := XDB.rec("Items", id)
			if rec.is_empty() or s.item_count(id) <= 0:
				continue
			if int(rec.get("itypeId", 1)) == (1 if cat == "item" else 2):
				out.append({"rec": rec, "count": s.item_count(id)})
		return XItemMarks.apply_list(s, out)
	var bag := XItemScene.bag_gear(cat)
	for i in range(bag.size()):
		out.append({"rec": bag[i], "carry": i + 1})
	return out


## deposit：放进当前仓库一件（满了不放）。rec 为物品记录或装备实例
static func deposit(s: XState, cat: String, rec: Dictionary) -> bool:
	if not has_space(s):
		return false
	var w := current(s)
	if rec.has("instanceId"):
		var i := s.gear.find_custom(func(e): return is_same(e, rec))
		if i < 0:
			return false
		if not o_reserved_no_dup and XAlienation.reserved(s, rec):
			# 原版：先 deposit 记进仓库，再 loseItem 被 Adv:88 挡下，供体留在背包，仓库里多一份
			w.items[cat].append(rec.duplicate(true))
			w.currentCapacity = int(w.currentCapacity) + 1
			return true
		s.gear.remove_at(i)
		w.items[cat].append(rec)
	else:
		var id := int(rec.id)
		if s.item_count(id) <= 0:
			return false
		s.gain_item(id, -1)
		var key := str(id)
		if w.items[cat].has(id):
			w.qtty[cat][key] = int(w.qtty[cat].get(key, 0)) + 1
		else:
			w.items[cat].append(id)
			w.qtty[cat][key] = 1
	w.currentCapacity = int(w.currentCapacity) + 1
	return true


## withdraw：取出一件；拿不到（物品已满 9999）返回 false，仓库不变
static func withdraw(s: XState, cat: String, rec: Dictionary) -> bool:
	var w := current(s)
	if w.is_empty():
		return false
	if rec.has("instanceId"):
		var i: int = (w.items[cat] as Array).find_custom(func(e): return is_same(e, rec))
		if i < 0:
			return false
		w.items[cat].remove_at(i)
		s.gear.append(rec)
	else:
		var id := int(rec.id)
		var before := s.item_count(id)
		s.gain_item(id, 1)
		if s.item_count(id) <= before:
			return false
		var key := str(id)
		var n := int(w.qtty[cat].get(key, 0)) - 1
		if n <= 0:
			w.items[cat].erase(id)
			w.qtty[cat].erase(key)
		else:
			w.qtty[cat][key] = n
	w.currentCapacity = int(w.currentCapacity) - 1
	return true


## 读档：整数还原、实例登记（实例编号不与背包重复）
static func from_save(s: XState, raw) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for title in raw:
		var w = raw[title]
		if not w is Dictionary:
			continue
		var items := {}
		var qtty := {}
		for cat in CATEGORIES:
			var list: Array = w.get("items", {}).get(cat, [])
			items[cat] = []
			for v in list:
				if v is Dictionary:
					s.register_gear(v)
					items[cat].append(v)
				else:
					items[cat].append(int(v))
			qtty[cat] = {}
			var q = w.get("qtty", {}).get(cat, {})
			for k in (q if q is Dictionary else {}):
				qtty[cat][str(k)] = int(q[k])
		out[str(title)] = {"title": str(w.get("title", title)), "maxCapacity": int(w.get("maxCapacity", DEFAULT_CAPACITY)),
			"currentCapacity": int(w.get("currentCapacity", 0)), "rule": w.get("rule"), "lootBonus": bool(w.get("lootBonus", true)),
			"items": items, "qtty": qtty}
	return out
