class_name XMapTransfer
extends RefCounted
## MapTransferPlugin 的数据部分：90 项地图配置、进入地图自动解锁、敌人/掉落预览。界面在 ui/map_transfer.gd。
## 配置取插件参数（db/Plugins.json），预览敌群取转换器导出的 db/MapPreview.json（各配置地图 encounterList 的敌群）。
## - 解锁：Game_Player.performTransfer 之后，配置里有的地图记为已解锁（$gameSystem._unlockedMaps）；
##   hidden 且未解锁的地图在列表显示 ???，预览只写「未解锁该地图」。
## - 敌人：遇敌敌群成员按出现顺序去重，再接额外怪物 extraEnemies。
## - 掉率：min(round(1/分母 × dropItemRate × 100000)/1000, 100)，按品质从高到低排（稳定排序）。
##   dropItemRate 照正式版运行时的实际链：EliteEnemy（双倍掉落 ? 1 : 0.2）× Codex 全队掉率（套装倍率 × 出战成员
##   passiveIRUP 逐个连乘）。O-013：不随机抽神话（原版每次预览新建 Game_Enemy，50% 显示成神话 ×5 的掉率）。

## O-013：预览掉率固定按非神话敌人；设 false 恢复原版的随机神话（几率与倍率同 XEnemy）。
const PREVIEW_FIXED_NORMAL := true
## O-014：未解锁（???）的地图不能传送；设 false 恢复原版（F 可直接传送到未到过的楼层）。
const REQUIRE_UNLOCK := true
## Game_Party.ABILITY_DROP_ITEM_DOUBLE（特性 64 队伍能力，dataId 5）
const DROP_ITEM_DOUBLE := 5
const TYPES := {1: "Item", 2: "Weapon", 3: "Armor"}
const TABLES := {1: "Items", 2: "Weapons", 3: "Armors"}

static var _maps: Array = []
static var _by_id := {}
static var _textures := {}


## 配置顺序即列表顺序：{id, tsid, name, x, y, extraEnemies, hidden, canTransfer, transferItem}
static func maps() -> Array:
	if _maps.is_empty():
		_parse()
	return _maps


static func setting(map_id: int) -> Dictionary:
	maps()
	return _by_id.get(map_id, {})


static func _parse() -> void:
	var raw = JSON.parse_string(str(XDB.plugin("MapTransferPlugin").get("Map Settings", "[]")))
	var infos = XDB.table("MapInfos")
	for text in (raw if raw is Array else []):
		var s = JSON.parse_string(str(text))
		if not s is Dictionary:
			continue
		var id := int(str(s.get("id", "0")))
		var name := str(s.get("name", ""))
		if name == "":
			var info = infos[id] if infos is Array and id > 0 and id < infos.size() else null
			name = str(info.name) if info is Dictionary else "地图%d" % id
		var extra: Array = []
		for part in str(s.get("extraEnemies", "")).split(","):
			if part.strip_edges().is_valid_int():
				extra.append(int(part.strip_edges()))
		var m := {"id": id, "tsid": int(str(s.get("transmitid", "0"))) if str(s.get("transmitid", "")).is_valid_int() else 0,
			"name": name, "x": _int(s.get("x")), "y": _int(s.get("y")), "extraEnemies": extra,
			"hidden": str(s.get("hidden", "")) == "true", "canTransfer": str(s.get("canTransfer", "")) != "false",
			"transferItem": _int(s.get("transferItem"))}
		_maps.append(m)
		_by_id[id] = m


static func _int(v) -> int:
	return int(str(v)) if str(v).is_valid_int() else 0


# ---- 解锁 ----
static func is_unlocked(s: XState, map_id: int) -> bool:
	return s != null and bool(s.unlocked_maps.get(map_id, false))


## performTransfer 之后：只解锁配置里有的地图
static func on_arrive(s: XState, map_id: int) -> void:
	if s and not setting(map_id).is_empty():
		s.unlocked_maps[map_id] = true


## 列表与预览：hidden 且未解锁时显示 ???
static func is_locked(s: XState, m: Dictionary) -> bool:
	return bool(m.hidden) and not is_unlocked(s, int(m.id))


## 能否从地图传送页传送（不含道具检查）：切片外地图在 Godot 里没有数据，一律不能去
static func can_transfer(s: XState, m: Dictionary) -> bool:
	if not bool(m.canTransfer) or (REQUIRE_UNLOCK and is_locked(s, m)):
		return false
	var target := target_map(m)
	return target > 0 and XMapScene.slice().get("maps", []).map(func(v): return int(v)).has(target)


static func target_map(m: Dictionary) -> int:
	return int(m.tsid) if int(m.tsid) > 0 else int(m.id)


# ---- 预览 ----
## 敌人记录（Enemies 表），顺序同 populatePreview 的 Set 插入顺序
static func preview_enemies(map_id: int) -> Array:
	var ids: Array = []
	var troops = XDB.table("MapPreview")
	for tid in (troops.get(str(map_id), []) if troops is Dictionary else []):
		var t := XDB.rec("Troops", int(tid))
		for mem in t.get("members", []):
			var eid := int(mem.enemyId)
			if eid > 0 and not ids.has(eid):
				ids.append(eid)
	for eid in setting(map_id).get("extraEnemies", []):
		if int(eid) > 0 and not ids.has(int(eid)):
			ids.append(int(eid))
	var out := []
	for eid in ids:
		var e := XDB.rec("Enemies", eid)
		if not e.is_empty():
			out.append(e)
	return out


## Codex 全队掉率：套装倍率（全体队员）× 出战成员每个 passiveIRUP 依次 ×(1 + v/100)
static func team_drop_factor(s: XState) -> float:
	if s == null:
		return 1.0
	var f := XEquipSuits.reward(s.members(), 1.0, 2)
	for a in s.battle_members():
		for v in a.passive_values("passiveIRUP"):
			f += XActor._num(v) * 0.01 * f
	return maxf(0.0, f)


static func has_drop_item_double(s: XState) -> bool:
	if s == null:
		return false
	for a in s.battle_members():
		if not a.traits_with_id(64, DROP_ITEM_DOUBLE).is_empty():
			return true
	return false


## Game_Enemy.dropItemRate（预览用新建的敌人；O-013 固定非神话）
static func drop_item_rate(s: XState, enemy: Dictionary) -> float:
	var elite := 1.0
	if not PREVIEW_FIXED_NORMAL:
		var e := XEnemy.new().setup(int(enemy.id), s.difficulty if s else 2)
		elite = e.drop_rate_bonus()
	return (1.0 if has_drop_item_double(s) else 0.2) * elite * team_drop_factor(s)


## parseEnemyDrops：[{type, kind, id, rate, item}]，按品质降序（同品质保持原顺序）
static func drops(s: XState, enemy: Dictionary) -> Array:
	var base := drop_item_rate(s, enemy)
	var out := []
	# YEP_ExtraEnemyDrops 在读数据库时把 <Enemy Drops> 的「Armor N: x%」追加进 dropItems（分母 = 1/几率）
	var list: Array = enemy.get("dropItems", []).duplicate()
	for x in XBattleLogic._extra_drops(enemy):
		list.append({"kind": x.kind, "dataId": x.id, "denominator": 1.0 / x.rate if x.rate > 0 else 0.0})
	for d in list:
		var kind := int(d.kind)
		if not TYPES.has(kind) or float(d.denominator) <= 0:
			continue
		var item := XDB.rec(TABLES[kind], int(d.dataId))
		var rate := minf(XPower.js_round((1.0 / float(d.denominator)) * base * 100000.0) / 1000.0, 100.0)
		out.append({"type": TYPES[kind], "kind": kind, "id": int(d.dataId), "rate": rate, "item": item, "order": out.size()})
	out.sort_custom(func(a, b):
		var qa := quality(a.item)
		var qb := quality(b.item)
		return qa > qb or (qa == qb and int(a.order) < int(b.order)))
	return out


static func quality(item: Dictionary) -> int:
	var q := str(item.get("meta", {}).get("quality", "1"))
	return int(q) if q.is_valid_int() else 1


## formatHp：万/亿/兆/京，保留两位小数后去掉多余的 0
static func format_hp(hp: float) -> String:
	var units := ["", "万", "亿", "兆", "京"]
	var i := 0
	while hp >= 10000 and i < units.size() - 1:
		hp /= 10000.0
		i += 1
	var s := "%.2f" % hp
	if s.ends_with(".00"):
		s = "%.0f" % hp
	elif s.ends_with("0"):
		s = "%.1f" % hp
	return s + units[i]


## 预览图：<Sideview Battler> 取角色侧视图第一格（宽/9、高/6），否则 sv_enemies 按 battlerHue 转色相（MV Bitmap.rotateHue）
static func enemy_texture(enemy: Dictionary) -> Texture2D:
	var key := int(enemy.get("id", 0))
	if _textures.has(key):
		return _textures[key]
	var tex: Texture2D = null
	var side = enemy.get("meta", {}).get("Sideview Battler")
	if side != null and str(side).strip_edges() != "":
		var p := XDB.img_path("sv_actors", str(side).strip_edges())
		if p != "":
			var src: Texture2D = load(p)
			var a := AtlasTexture.new()
			a.atlas = src
			a.region = Rect2(0, 0, src.get_width() / 9.0, src.get_height() / 6.0)
			tex = a
	else:
		var p := XDB.img_path("sv_enemies", str(enemy.get("battlerName", "")))
		if p != "":
			tex = load(p)
			var hue := int(enemy.get("battlerHue", 0))
			if hue != 0:
				tex = ImageTexture.create_from_image(rotate_hue(tex.get_image(), hue))
	_textures[key] = tex
	return tex


## MV Bitmap.rotateHue：逐像素 RGB→HSL、色相加 offset、再转回（Uint8ClampedArray 四舍五入）
static func rotate_hue(src: Image, offset: int) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	offset = ((offset % 360) + 360) % 360
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		var r := float(data[i])
		var g := float(data[i + 1])
		var b := float(data[i + 2])
		var cmin := minf(r, minf(g, b))
		var cmax := maxf(r, maxf(g, b))
		var h := 0.0
		var s := 0.0
		var l := (cmin + cmax) / 2.0
		var delta := cmax - cmin
		if delta > 0:
			if r == cmax:
				h = 60.0 * fmod((g - b) / delta + 6.0, 6.0)
			elif g == cmax:
				h = 60.0 * ((b - r) / delta + 2.0)
			else:
				h = 60.0 * ((r - g) / delta + 4.0)
			s = delta / (255.0 - absf(2.0 * l - 255.0))
		h = fmod(h + offset, 360.0)
		var c := (255.0 - absf(2.0 * l - 255.0)) * s
		var x := c * (1.0 - absf(fmod(h / 60.0, 2.0) - 1.0))
		var m := l - c / 2.0
		var cm := c + m
		var xm := x + m
		var rgb: Array
		if h < 60:
			rgb = [cm, xm, m]
		elif h < 120:
			rgb = [xm, cm, m]
		elif h < 180:
			rgb = [m, cm, xm]
		elif h < 240:
			rgb = [m, xm, cm]
		elif h < 300:
			rgb = [xm, m, cm]
		else:
			rgb = [cm, m, xm]
		for k in 3:
			data[i + k] = _clamp8(rgb[k])
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## ToUint8Clamp：小数恰为 .5 时取偶数
static func _clamp8(v: float) -> int:
	if v <= 0.0:
		return 0
	if v >= 255.0:
		return 255
	var f := floorf(v)
	var d := v - f
	if d < 0.5:
		return int(f)
	if d > 0.5:
		return int(f) + 1
	return int(f) if int(f) % 2 == 0 else int(f) + 1
