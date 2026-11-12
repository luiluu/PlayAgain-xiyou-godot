class_name XAlienHide
extends RefCounted
## 异化隐藏的物品侧（正式 v0.58 installAlienationHide 第 3、4 件：六件物品不可得／不可见／不可装备，读档把异化实例还原成普通装备）。
## 遭遇、奖励、工坊在 XAlienBattle（setup_encounter／grant／encounter）与主菜单（XMenu.commands 去掉「异化工坊」）。
## 生效条件 XAlienBattle.hidden()：HIDDEN_V058（O-283，开发版默认 false）或发行构建里的 RELEASE_HIDE（默认 true，Kyo 11-11「新整包里异化相关装备和词条都不开放」）。
## 六件物品：异化能量 2872、异化石 2873（物品）；深渊残刃 3980、深渊残杖 3981（武器底子）；深渊残甲 7980、深渊残环 7981（防具底子）。
## 各入口：
## - 得到：XState.gain_item／gain_gear 数量为正时挡下（原版 Game_Party.gainItem 包装）；减少照常。掉落、事件、商店、合成都经这两个口。
## - 看见：背包物品列表（XItemMarks.apply_list，物品页与商店出售共用）、装备列表（XItemScene.bag_gear，物品页／装备页／出售／两种仓库存放共用）、
##   商店进货（XItemMarks.shop_goods）去掉（原版 Game_Party.items／weapons／armors 过滤、Window_ShopBuy.makeItemList）。
## - 装备：XActor.can_equip 返回 false（原版 canEquip／changeEquip 包装）。
## - 当词缀：XGear.valid_affix 不收（原版 DreamX.RandomPrefixSuffix.isValidItem 包装）。
## - 星级仓库（跨存档，原版没管，重制另补）：取出列表不列残响，取出的异化装备还原成普通装备。
## 读档迁移 migrate（XState.from_dict 里，原版 extractSaveContents 包装）：只跑一次，标记 flags.alienHiddenV058 随存档。
## 与原版的差别：原版把残响留在队伍容器里、打隐藏标记，靠各列表过滤看不见；重制把它们（连同身上卸下的、仓库里的）
## 整件移进 flags.alienHiddenGear 归档，背包里就没有这件，不用每个列表都过滤；归档的实例原样保存，以后开放可以退回。
## 物品数量照原版 stash 累加进 flags.alienHiddenItems；卸装、仓库移出记录分别累加进 alienHiddenEquip、alienHiddenWarehouse。

const ITEM_IDS := [2872, 2873]
const WEAPON_BASES := [3980, 3981]
const ARMOR_BASES := [7980, 7981]
const MARKER := "alienHiddenV058"
const RESTORED := "_alienRestoredV058"
const STASH_ITEMS := "alienHiddenItems"
const STASH_GEAR := "alienHiddenGear"
const STASH_EQUIP := "alienHiddenEquip"
const STASH_WAREHOUSE := "alienHiddenWarehouse"

## 最近一次迁移的报告（测试看）；没跑为空
static var last_report := {}


static func active() -> bool:
	return XAlienBattle.hidden()


static func hidden_item_id(id: int) -> bool:
	return ITEM_IDS.has(id)


static func hidden_base(kind: String, base_id: int) -> bool:
	return (WEAPON_BASES if kind == "weapon" else ARMOR_BASES if kind == "armor" else []).has(base_id)


## 装备实例是不是残响（按底子）
static func hidden_gear(item) -> bool:
	return item is Dictionary and item.has("kind") and hidden_base(str(item.kind), int(item.get("base", item.get("id", 0))))


## 生效时是否挡下：物品 ID
static func blocks_item(id: int) -> bool:
	return hidden_item_id(id) and active()


## 生效时是否挡下：装备底子
static func blocks_base(kind: String, base_id: int) -> bool:
	return hidden_base(kind, base_id) and active()


static func blocks_gear(item) -> bool:
	return hidden_gear(item) and active()


## 物品列表条目 {rec, …}：rec 是物品记录（没有 kind）或装备实例
static func entry_hidden(e: Dictionary) -> bool:
	var rec = e.get("rec", {})
	if not rec is Dictionary:
		return false
	if rec.has("kind"):
		return hidden_gear(rec)
	return hidden_item_id(int(rec.get("id", 0)))


## 生效时去掉列表里的隐藏条目；不生效原样返回
static func filter_entries(entries: Array) -> Array:
	if not active():
		return entries
	return entries.filter(func(e): return not (e is Dictionary and entry_hidden(e)))


static func filter_gear(list: Array) -> Array:
	if not active():
		return list
	return list.filter(func(e): return not hidden_gear(e))


## 商店进货行 [类型 0物品/1武器/2防具, ID, …]
static func filter_goods(rows: Array) -> Array:
	if not active():
		return rows
	return rows.filter(func(g): return not (int(g[0]) == 0 and hidden_item_id(int(g[1])) \
		or int(g[0]) == 1 and hidden_base("weapon", int(g[1])) or int(g[0]) == 2 and hidden_base("armor", int(g[1]))))


## 异化装备还原成普通装备：名字回原名、去掉 alien 标记；返回有没有改
static func restore(item) -> bool:
	if not item is Dictionary or not item.has("alien"):
		return false
	var m = item.alien
	var plain := ""
	if m is Dictionary:
		plain = str(m.get("plainName", ""))
		# 名字被别处改过（加了锁定等）时，照 relabel 按现名去掉词条前缀
		if str(item.get("name", "")) != str(m.get("lastName", "")):
			plain = ""
	if plain == "":
		var names := PackedStringArray(XAlienation.config().get("affixes", []).map(func(f): return str(f.name)))
		plain = RegEx.create_from_string("^(" + "|".join(names) + ")·").sub(str(item.get("name", "")), "") if not names.is_empty() else str(item.get("name", ""))
	item.name = plain
	item.erase("alien")
	item[RESTORED] = 1
	return true


static func _stash_count(s: XState, key: String, counts: Dictionary) -> void:
	if counts.is_empty():
		return
	var cur: Dictionary = s.flags.get(key, {}) if s.flags.get(key) is Dictionary else {}
	for id in counts:
		cur[str(id)] = int(cur.get(str(id), 0)) + int(counts[id])
	s.flags[key] = cur


static func _stash_list(s: XState, key: String, list: Array) -> void:
	if list.is_empty():
		return
	var cur: Array = s.flags.get(key, []) if s.flags.get(key) is Array else []
	cur.append_array(list)
	s.flags[key] = cur


static func _alien_state_ids() -> Array:
	var out := [XAlienBattle.corrosion_id()]
	var pairs = XAlienation.config().get("templates", {}).get("statePairs", {})
	if pairs is Dictionary:
		for k in pairs:
			out.append(int(pairs[k]))
	return out


## H.migrate：生效时读档跑一次（标记随存档）；不生效或已迁移返回 {}
static func migrate(s: XState) -> Dictionary:
	last_report = {}
	if s == null or not active() or s.flags.get(MARKER):
		return {}
	var report := {"items": {}, "gear": [], "equips": [], "warehouse": [], "restored": [], "actors": 0, "pending": false}
	var restore_one := func(item):
		if restore(item):
			report.restored.append({"id": str(item.get("instanceId", "")), "base": int(item.get("base", 0)), "name": str(item.name)})
	# 1. 背包里的能量、异化石
	for id in ITEM_IDS:
		var n := s.item_count(id)
		if n > 0:
			report.items[id] = int(report.items.get(id, 0)) + n
			s.items.erase(id)
	# 2. 角色身上：异化实例还原；残响卸下归档（不放回背包）
	var state_ids := _alien_state_ids()
	for a in s.actors.values():
		var changed := false
		for slot in a.equips.size():
			var item = a.equips[slot]
			if not item is Dictionary or item.is_empty():
				continue
			if item.has("alien"):
				restore_one.call(item)
				changed = true
			if hidden_gear(item):
				report.equips.append({"actorId": a.actor_id, "slot": slot, "id": str(item.get("instanceId", "")), "base": int(item.base), "name": str(item.name)})
				report.gear.append(item)
				a.equips[slot] = null
				changed = true
		for id in state_ids:
			if a.state_ids.has(id):
				a.remove_state(id)
				changed = true
		if changed:
			report.actors += 1
			a.refresh_passive()
			a.param_mark_dirty()
	# 3. 仓库：能量、异化石记数量移出；残响整件移出归档；其余异化实例还原
	for title in s.warehouses:
		var w: Dictionary = s.warehouses[title]
		var items: Dictionary = w.get("items", {})
		var qtty: Dictionary = w.get("qtty", {})
		for cat in items:
			var list: Array = items[cat]
			for i in range(list.size() - 1, -1, -1):
				var v = list[i]
				var n := 0
				if v is Dictionary:
					if v.has("alien"):
						restore_one.call(v)
					if not hidden_gear(v):
						continue
					n = 1
					report.gear.append(v)
					report.warehouse.append({"title": str(title), "category": str(cat), "id": str(v.get("instanceId", "")), "base": int(v.base), "count": 1})
				else:
					if not hidden_item_id(int(v)):
						continue
					n = maxi(1, int(qtty.get(cat, {}).get(str(int(v)), 1)))
					report.items[int(v)] = int(report.items.get(int(v), 0)) + n
					report.warehouse.append({"title": str(title), "category": str(cat), "id": int(v), "count": n})
					if qtty.get(cat) is Dictionary:
						qtty[cat].erase(str(int(v)))
				list.remove_at(i)
				w.currentCapacity = maxi(0, int(w.get("currentCapacity", 0)) - n)
	# 4. 背包装备：异化实例还原，残响移出归档
	for i in range(s.gear.size() - 1, -1, -1):
		var item = s.gear[i]
		restore_one.call(item)
		if hidden_gear(item):
			report.gear.append(item)
			s.gear.remove_at(i)
	# 5. 待选重抽清掉；最近掉落记录保留
	if s.alien_ledger.get("pending") != null:
		s.alien_ledger.pending = null
		report.pending = true
	_stash_count(s, STASH_ITEMS, report.items)
	_stash_list(s, STASH_GEAR, report.gear)
	_stash_list(s, STASH_EQUIP, report.equips)
	_stash_list(s, STASH_WAREHOUSE, report.warehouse)
	s.flags[MARKER] = 1
	last_report = report
	return report
