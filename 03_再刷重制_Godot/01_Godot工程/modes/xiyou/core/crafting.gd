class_name XCrafting
extends RefCounted
## 制作（hc.js Recipe Crafting）的数据部分；界面在 ui/crafting.gd。配方取 modes/xiyou/recipes.json（03_转换工具/配方转换.py 由冻结正式源 Recipes.txt 生成）。
## 原版插件在 plugins.js 里叫 hc，代码读 PluginManager.parameters('RecipeCrafting')，一项参数都取不到，所以下面全是 hc.js 的代码缺省。
## 存档字段 XState.crafting：{known: {配方ID: bool}（$gameParty._recipesKnown）, level: [4 类别等级], exp: [4 类别经验]}。
## - 材料计数（Recipe.getMaterialCount）：物品按持有数，武器防具按背包里的实例（不算装备着的）；材料一律消耗（数据里的 cons:false 原版不认）。
## - 制作一件（Recipe.craft）：先扣材料与金币，再按成功率（配方都没写，恒 100）得结果、类别经验 xpGain、全队经验 pxp（数据里都是 0）。
## - 类别升级：经验 ≥ 50×等级 就减去并升一级；等级到 99（User Definable Max Level 缺省）以上不再得经验。
## - 产出宝珠的配方当作未学会（installNativeOrbRuntime，宝珠只从副本神秘珠来）。
## - 插件指令 crafting learn／forget N（设计图物品的公共事件）；crafting call 正式数据没有，不接。
## - 配方 457／458（杰作利维坦／杰作无我）被利维坦锻造改写：解锁、材料数、能做几件、制作都转给 XGrowthForge。

const CATEGORIES := ["炼金术", "打造", "加工", "珠宝"]
const CATEGORY_ICONS := [1240, 1296, 1263, 1277]
const PLAYER_LEVEL_ICON := 1045
const MAX_LEVEL := 99
const RECIPES_PATH := "res://modes/xiyou/recipes.json"
const TABLES := {"item": "Items", "weapon": "Weapons", "armor": "Armors"}

static var _recipes: Array = []


## 全部配方（按 ID 顺序，[0] 是 1 号）
static func recipes() -> Array:
	if _recipes.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(RECIPES_PATH))
		_recipes = d.recipes if d is Dictionary else []
	return _recipes


static func recipe(id: int) -> Dictionary:
	var all := recipes()
	return all[id - 1] if id >= 1 and id <= all.size() else {}


static func _data(s: XState) -> Dictionary:
	var c := s.crafting
	if not c.get("known") is Dictionary:
		c.known = {}
	for k in ["level", "exp"]:
		if not c.get(k) is Array or (c[k] as Array).size() != CATEGORIES.size():
			c[k] = [1, 1, 1, 1] if k == "level" else [0, 0, 0, 0]
	return c


## 材料或结果对应的数据库条目
static func item_of(m: Dictionary) -> Dictionary:
	return XDB.rec(TABLES.get(str(m.get("type", "")), "Items"), int(m.get("id", 0)))


static func category_id(r: Dictionary) -> int:
	return CATEGORIES.find(str(r.get("category", "")))


## installNativeOrbRuntime（2026-10-10 稀有化）给 Recipe.known 加了一层：产出宝珠的配方一律当作未学会，列表不显示
static func is_orb_recipe(r: Dictionary) -> bool:
	return str(r.result.type) == "item" and XOrbs.is_orb_item(int(r.result.id))


static func known(s: XState, r: Dictionary) -> bool:
	if is_orb_recipe(r):
		return false
	if XGrowthForge.is_forge_recipe(int(r.id)):
		XGrowthForge.unlocked(s, int(r.id))  # 旧档读进来、或别的路子拿到装备时补查解锁
	var k: Dictionary = _data(s).known
	return bool(k.get(str(int(r.id)), r.get("known", false)))


static func learn(s: XState, id: int, on := true) -> void:
	_data(s).known[str(id)] = on


static func craft_level(s: XState, cat: int) -> int:
	return int(_data(s).level[cat]) if cat >= 0 else 0


static func craft_exp(s: XState, cat: int) -> int:
	return int(_data(s).exp[cat]) if cat >= 0 else 0


## Crafting XP Formula 缺省「50 * lvl」
static func exp_next(s: XState, cat: int) -> int:
	return 50 * craft_level(s, cat)


static func gain_exp(s: XState, cat: int, value: int) -> void:
	if cat < 0:
		return
	var d := _data(s)
	d.exp[cat] = int(d.exp[cat]) + value
	while int(d.exp[cat]) >= exp_next(s, cat):
		d.exp[cat] = int(d.exp[cat]) - exp_next(s, cat)
		d.level[cat] = int(d.level[cat]) + 1


## r：材料所属的配方（锻造配方的原件那一项另算）
static func material_count(s: XState, m: Dictionary, r := {}) -> int:
	if not r.is_empty() and XGrowthForge.is_forge_recipe(int(r.id)):
		var n := XGrowthForge.material_count(s, int(r.id), m)
		if n >= 0:
			return n
	var t := str(m.get("type", ""))
	if t == "item":
		return s.item_count(int(m.id))
	if t == "weapon" or t == "armor":
		return s.gear_count(t, int(m.id))
	return 0


static func has_materials(s: XState, r: Dictionary) -> bool:
	for m in r.materials:
		if material_count(s, m, r) < int(m.amount):
			return false
	return true


static func has_gold(s: XState, r: Dictionary) -> bool:
	return s.gold >= int(r.goldCost)


static func has_craft_level(s: XState, r: Dictionary) -> bool:
	return int(r.craftLevel) <= craft_level(s, category_id(r))


## $gameParty.highestLevel：全队（含后备）最高等级
static func highest_level(s: XState) -> int:
	var lv := 0
	for a in s.members():
		lv = maxi(lv, a.level)
	return lv


static func has_level(s: XState, r: Dictionary) -> bool:
	return int(r.level) <= highest_level(s) and has_craft_level(s, r)


static func craftable(s: XState, r: Dictionary) -> bool:
	if XGrowthForge.is_forge_recipe(int(r.id)):
		return XGrowthForge.craftable(s, r)
	return has_gold(s, r) and has_materials(s, r) and has_level(s, r)


## Recipe.amountCraftable：各材料 持有/需要 的最小值，再与 金币/费用（费用 0 时为 99）取小，向下取整
static func amount_craftable(s: XState, r: Dictionary) -> int:
	if XGrowthForge.is_forge_recipe(int(r.id)):
		return 1 if XGrowthForge.craftable(s, r) else 0
	if not has_materials(s, r):
		return 0
	var amount := -1.0
	for m in r.materials:
		var next := float(material_count(s, m, r)) / float(m.amount)
		if amount < 0.0 or next < amount:
			amount = next
	var gold_amount := float(s.gold) / float(r.goldCost) if int(r.goldCost) > 0 else 99.0
	return floori(minf(amount, gold_amount))


static func success_rate(s: XState, r: Dictionary) -> float:
	var diff := craft_level(s, category_id(r)) - int(r.craftLevel)
	return minf(float(r.success) + float(r.successGain) * diff, 100.0)


static func xp_gain(s: XState, r: Dictionary) -> int:
	var cat := category_id(r)
	if craft_level(s, cat) > MAX_LEVEL:
		return 0
	var diff := craft_level(s, cat) - int(r.craftLevel)
	return maxi(int(r.xp) - int(r.xpDeprac) * diff, 0)


## Recipe.removeMaterials：物品按数量减，武器防具逐件移除（背包里先找到的那件），再扣费用
static func remove_materials(s: XState, r: Dictionary) -> void:
	for m in r.materials:
		var t := str(m.type)
		if t == "item":
			s.gain_item(int(m.id), -int(m.amount))
		elif t == "weapon" or t == "armor":
			s.gain_gear(t, int(m.id), -mini(int(m.amount), s.gear_count(t, int(m.id))))
	s.gain_gold(-int(r.goldCost))


## Recipe.craft(Math.random()×100)：成功返回结果的数据库条目，失败返回 {}。roll 缺省时只在成功率不足 100 才抽随机数
## 锻造配方：把界面选好的原件（XGrowthForge.forge_source）改成杰作，返回这件；不能锻造为空，什么都不扣
static func craft(s: XState, r: Dictionary, roll := -1.0) -> Dictionary:
	if XGrowthForge.is_forge_recipe(int(r.id)):
		return XGrowthForge.forge(s, int(r.id), XGrowthForge.forge_source)
	remove_materials(s, r)
	var rate := success_rate(s, r)
	if roll < 0.0:
		roll = randf() * 100.0 if rate < 100.0 else 0.0
	if roll >= rate:
		return {}
	var res: Dictionary = r.result
	var t := str(res.type)
	if t == "item":
		s.gain_item(int(res.id), int(res.amount))
	else:
		s.gain_gear(t, int(res.id), int(res.amount))
	gain_exp(s, category_id(r), xp_gain(s, r))
	if int(r.get("pxp", 0)) != 0:
		for a in s.members():
			a.gain_exp(int(r.pxp))
	return item_of(res)


## 插件指令 crafting learn／forget N；返回是否认得
static func plugin_command(s: XState, args: PackedStringArray) -> bool:
	if args.size() < 3:
		return false
	match args[1]:
		"learn": learn(s, int(args[2]))
		"forget": learn(s, int(args[2]), false)
		_:
			return false
	return true
