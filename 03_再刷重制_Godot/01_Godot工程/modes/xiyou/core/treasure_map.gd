class_name XTreasureMap
extends RefCounted
## 藏宝图（Star_RomGetItems 的 Star.RomGetItems.RunGetFun(a, b)；公共事件 117、174～189、1381～1384），照冻结 v0.28 原版
## （mv_oracle/common_script_probe.cjs → generated/oracle/common_scripts.json，tests/xiyou_common_scripts）：
## - 宝点表是插件参数「RomItems i」：地图、坐标、物品／防具／武器／公共事件候选、对应藏宝图物品 ItID。
## - 先检查预掷池 $gameParty.RomGet（XState.rom.g）：长度不是 RomLength（20）或已用次数 RomGetNum（rom.gn）超过 RomLengthRef（15）
##   就重掷 20 个 floor(random×9999)+1，次数归零。
## - 从 a 到 b 找第一个本轮没挖过的宝点（$gameParty.GameMapxy，rom.m 记挖过的编号）：玩家正站在那一格就挖（提示「挖宝成功」，
##   按预掷值发奖并记为挖过），否则提示当前地图名与坐标、目标地图名与坐标。只看这一个宝点。
## - a～b 全挖过：全部清掉重来一轮（同一次调用里接着从 a 找）。
## - 发奖（GetRomItem）：v＝RomGet[RomGetNum]，v%80 <20 物品、<40 防具、<60 武器、<80 预约公共事件，候选取第 v%长度 个；
##   先扣一张藏宝图，候选为空时还回来并提示「…失败: 请重新使用」；之后 RomGetNum+1。

const LENGTH := 20
const REFRESH := 15
static var _spots: Array = []


static func spots() -> Array:
	if not _spots.is_empty():
		return _spots
	var out := [null]
	var p := XDB.plugin("Star_RomGetItems")
	var i := 1
	while p.has("RomItems %d" % i):
		var raw = JSON.parse_string(str(p["RomItems %d" % i])) if str(p["RomItems %d" % i]) != "" else null
		if raw is Dictionary:
			out.append({"id": i, "map": int(raw.get("RomItemsMapId", 0)), "x": int(raw.get("RomItemsMapx", 0)), "y": int(raw.get("RomItemsMapy", 0)),
				"item": _ids(raw.get("RomItemsItems", "")), "armor": _ids(raw.get("RomItemsArmors", "")),
				"weapon": _ids(raw.get("RomItemsWeapons", "")), "common": _ids(raw.get("RomItemsComs", "")), "ticket": int(raw.get("RomItemsItID", 0))})
		else:
			out.append(null)
		i += 1
	_spots = out
	return out


static func _ids(text) -> Array:
	var v = JSON.parse_string(str(text)) if str(text).strip_edges() != "" else null
	return (v as Array).map(func(x): return int(x)) if v is Array else []


## ---- 新源 v0.29 起（installTreasureBatchRuntime 包 RunGetFun）----
## 表里 21 种藏宝图 [物品, 公共事件, 首, 尾]：不看站位（去掉坐标门槛），也不提示「挖宝成功」。藏宝图取正在跑的那条公共事件对应的物品
## （T.current，command355 时按公共事件列表认），对不上首尾时按首尾找（同首尾的 117／189 后写的 189 覆盖）。物品要带「效果 44＝这条公共事件」、
## 背包里至少一张，宝点只算四类候选都不空的；取第一个没挖过的，全挖过就整段清掉取第一个；发奖照原生 GetRomItem，扣的是这张藏宝图（ItID 换成它）。
## 首尾不在表里的照原生（上面那套）。旧源没有这个运行时（manifest 的 runtimeInputs 里没有）时全照原生
const V029_SPECS := [[212, 117, 1, 10], [319, 174, 11, 14], [320, 175, 15, 18], [321, 176, 19, 22], [322, 177, 23, 25], [323, 178, 26, 28],
	[324, 179, 29, 32], [330, 180, 33, 36], [331, 181, 37, 40], [332, 182, 41, 44], [336, 183, 45, 48], [337, 184, 49, 53], [338, 185, 54, 57],
	[339, 186, 58, 61], [340, 187, 62, 65], [341, 188, 66, 69], [342, 189, 1, 10], [1679, 1381, 76, 79], [1680, 1382, 80, 83], [1681, 1383, 84, 87],
	[1682, 1384, 88, 91]]
static var _v029 = null


static func v029() -> bool:
	if _v029 == null:
		var m = XDB.load_json("manifest.json") if FileAccess.file_exists(XDB.BASE + "manifest.json") else null
		_v029 = m is Dictionary and (m.get("runtimeInputs", {}) as Dictionary).has("js/codex/runtime/installTreasureBatchRuntime.js")
	return bool(_v029)


static func _v029_spec(common_id: int, first: int, last: int) -> Array:
	for sp in V029_SPECS:
		if int(sp[1]) == common_id and int(sp[2]) == first and int(sp[3]) == last:
			return sp
	var found := []
	for sp in V029_SPECS:
		if int(sp[2]) == first and int(sp[3]) == last:
			found = sp   # byRange：后写的覆盖
	return found


## 返回 {toasts: [提示…], reserve: 预约的公共事件（0 为无）}；common_id 是正在跑这句的公共事件（0＝不在公共事件里）
static func run(s: XState, first: int, last: int, common_id := 0) -> Dictionary:
	var out := {"toasts": [], "reserve": 0}
	if v029():
		var sp := _v029_spec(common_id, first, last)
		if not sp.is_empty():
			_run_v029(s, sp, out)
			return out
	var g: Array = s.rom.get("g", [])
	if g.size() != LENGTH or int(s.rom.get("gn", 0)) > REFRESH:
		g = []
		for i in range(LENGTH):
			g.append(MVInterpreter.random_int(1, 9999, s))
		s.rom.g = g
		s.rom.gn = 0
	var dug: Array = s.rom.get("m", [])
	s.rom.m = dug
	var list := spots()
	var i := first
	while i <= last:
		var spot = list[i] if i < list.size() else null
		if spot != null and not dug.has(i):
			if s.map_id == spot.map and s.x == spot.x and s.y == spot.y:
				out.toasts.append("挖宝成功")
				_dig(s, spot, out)
				dug.append(i)
			else:
				out.toasts.append("%s 坐标:%d,%d" % [_map_name(s.map_id), s.x, s.y])
				out.toasts.append("目标位置:%s %d,%d" % [_map_name(spot.map), spot.x, spot.y])
			break
		if i == last:
			for a in range(first, last + 1):
				dug.erase(a)
			i = first - 1
		i += 1
	return out


static func _run_v029(s: XState, sp: Array, out: Dictionary) -> void:
	var item := XDB.rec("Items", int(sp[0]))
	if item.is_empty() or not (item.get("effects", []) as Array).any(func(e): return int(e.get("code", 0)) == 44 and int(e.get("dataId", 0)) == int(sp[1])):
		return
	if s.item_count(int(sp[0])) < 1:
		return
	var list := spots()
	var rows := []
	for i in range(int(sp[2]), int(sp[3]) + 1):
		var spot = list[i] if i < list.size() else null
		if spot != null and not spot.item.is_empty() and not spot.armor.is_empty() and not spot.weapon.is_empty() and not spot.common.is_empty():
			rows.append(spot)
	if rows.is_empty():
		return
	var dug: Array = s.rom.get("m", [])
	s.rom.m = dug
	var row = null
	for r in rows:
		if not dug.has(int(r.id)):
			row = r
			break
	if row == null:
		for r in rows:
			dug.erase(int(r.id))
		row = rows[0]
	var g: Array = s.rom.get("g", [])
	if g.size() != LENGTH or int(s.rom.get("gn", 0)) > REFRESH:
		g = []
		for i in range(LENGTH):
			g.append(MVInterpreter.random_int(1, 9999, s))
		s.rom.g = g
		s.rom.gn = 0
	var copy: Dictionary = (row as Dictionary).duplicate()
	copy.ticket = int(sp[0])
	_dig(s, copy, out)
	if not dug.has(int(row.id)):
		dug.append(int(row.id))


static func _map_name(id: int) -> String:
	return str(XDB.rec("MapInfos", id).get("name", ""))


static func _dig(s: XState, spot: Dictionary, out: Dictionary) -> void:
	var v: int = int(s.rom.g[int(s.rom.gn)])
	var roll := v % 80
	var ticket: int = spot.ticket
	s.gain_item(ticket, -1)
	if roll < 20:
		if spot.item.is_empty():
			s.gain_item(ticket, 1)
			out.toasts.append("获取物品失败: 请重新使用")
		else:
			var id: int = spot.item[v % spot.item.size()]
			s.gain_item(id, 1)
			out.toasts.append("获得物品:" + str(XDB.rec("Items", id).get("name", "")))
	elif roll < 40:
		if spot.armor.is_empty():
			s.gain_item(ticket, 1)
			out.toasts.append("获取防具失败: 请重新使用")
		else:
			var id: int = spot.armor[v % spot.armor.size()]
			s.gain_gear("armor", id, 1)
			out.toasts.append("获得防具:" + str(XDB.rec("Armors", id).get("name", "")))
	elif roll < 60:
		if spot.weapon.is_empty():
			s.gain_item(ticket, 1)
			out.toasts.append("获取武器失败: 请重新使用")
		else:
			var id: int = spot.weapon[v % spot.weapon.size()]
			s.gain_gear("weapon", id, 1)
			out.toasts.append("获得武器:" + str(XDB.rec("Weapons", id).get("name", "")))
	else:
		if spot.common.is_empty():
			s.gain_item(ticket, 1)
			out.toasts.append("触发事件失败: 请重新使用")
		else:
			var id: int = spot.common[v % spot.common.size()]
			out.toasts.append("触发事件:" + str(XDB.rec("CommonEvents", id).get("name", "")))
			out.reserve = id
	s.rom.gn = int(s.rom.gn) + 1
