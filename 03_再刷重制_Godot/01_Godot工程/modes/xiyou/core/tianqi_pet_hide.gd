class_name XTianqiPetHide
extends RefCounted
## 【cc·天启篇·未经审查】天启篇存档隐藏宠物系统（四线异化与异化装备重构 v0.8 第 2.4 节，Kyo 2026-11-08 已确认）。
## 「隐藏」不是删代码：西游存档里宠物照常，天启篇存档按标记关掉各入口（学 XAlienHide 的口子）：
## - 主菜单没有「宠物」（XMenu.commands）；地图事件里的公共事件 169（SceneManager.push(Scene_PetSystem)）不开宠物页。
## - 战斗捕捉：不掷可捕捉（敌人不会变「宝宝」，敌群 1 也不强制），自然也不会第 5 回合逃跑（XPetCapture.roll_battle）。
## - 神秘生物：不刷新，已开的刷新点关掉（XPetCapture.check 走 stop）。
## - 物品：捕获网等（用公共事件 173 的）、魔兽要诀（公共事件里调 ComEveLearnSkill 的）、宠物口粮（Star_PetUpLevel 的 PetEatItem）
##   得不到（XState.gain_item 数量为正时挡下：掉落、事件、商店都经这里）、背包和出售列表里不列、商店不上架。
## - 星级仓库：分类只剩「装备」，宠物那一格不画、选不到。
## - 宠物出战加成：天启篇里拿不到宠物，自然没有；已有的（不该有）不清，只是看不见入口。
## 只认天启篇存档（XTianqiLine.open_for：发行构建里还要 XTianqi.RELEASE_OPEN）。
##
## 开关（O-343）：false＝天启篇存档里宠物系统照原版都在

## 开关：false＝天启篇存档也照常有宠物系统
static var ENABLED := true

const CAPTURE_EVENT := 173
static var _ids := {}


static func active(s: XState = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return s != null and XTianqiLine.open_for(s)


## 要藏的物品号（捕获道具、魔兽要诀、宠物口粮），第一次用时从数据库算
static func item_ids() -> Dictionary:
	if not _ids.is_empty():
		return _ids
	var learn := {}
	var ces = XDB.table("CommonEvents")
	if ces is Array:
		for ce in ces:
			if ce is Dictionary and ce.get("list", []).any(func(c): return str(c.get("parameters", [])).contains("ComEveLearnSkill")):
				learn[int(ce.id)] = true
	for it in XDB.table("Items"):
		if not it is Dictionary:
			continue
		for e in it.get("effects", []):
			if int(e.get("code", 0)) == 44 and (int(e.dataId) == CAPTURE_EVENT or learn.has(int(e.dataId))):
				_ids[int(it.id)] = true
	for id in XPets.food_items():
		_ids[int(id)] = true
	return _ids


static func blocks_item(id: int) -> bool:
	return active() and item_ids().has(id)


## 背包、出售列表 [{rec, …}]
static func filter_entries(entries: Array) -> Array:
	if not active():
		return entries
	return entries.filter(func(e): return not (e is Dictionary and e.get("rec") is Dictionary and not e.rec.has("kind") and item_ids().has(int(e.rec.get("id", 0)))))


## 商店进货 [[类, 号, …]…]（类 0＝物品）
static func filter_goods(rows: Array) -> Array:
	if not active():
		return rows
	return rows.filter(func(g): return not (int(g[0]) == 0 and item_ids().has(int(g[1]))))
