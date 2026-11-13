class_name XTianqiQiyinGear
extends RefCounted
## 天启篇「七印祭坛」装备的只读数据层：modes/xiyou/tianqi_data/qiyin_gear.json（Kyo 2026-11-11 派单，数值是占位，表头 draft）。
## 七套套装（每套头部、盔甲、护手、腰带、裤子、鞋子 6 件，2／3／5 件各一档）、13 把毕业武器（前六印各一流派两类，默印一把随机类）、5 件神器（类型 17）。
##
## 本类只读数据，还没接进战斗、掉落、界面，也不改原版数据库。
## 效果都是 {code, 参数…, text}：code 的含义在表头 _note.effect_codes，text 给界面。
## 印的键按揭开顺序：bai 白、hong 红、hei 黑、hui 灰、xun 殉、zhen 震、mo 默；部位键 head／body／hands／waist／legs／feet，
## 装备类型号与 XTianqiGear.ORDER 一致（头部 3、盔甲 4、护手 6、腰带 8、裤子 5、鞋子 7）。

const PATH := "res://modes/xiyou/tianqi_data/qiyin_gear.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiQiyinGear: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiQiyinGear: JSON 解析失败 " + PATH)
	return _data


## 测试用：清掉缓存，下次重新读文件
static func reload() -> void:
	_data = {}


# ---- 七印与部位 ----

## 七印的键，按揭开顺序
static func seal_keys() -> Array:
	return data().get("seals", []).map(func(s): return str(s.get("key", "")))


## 一印：key、name、order。没有为空。
static func seal(key: String) -> Dictionary:
	return _find(data().get("seals", []), key)


## 六个部位：key、name、etype（装备类型号）
static func parts() -> Array:
	return data().get("parts", []).duplicate(true)


## 部位的装备类型号；不认识的部位返回 0
static func part_etype(part_key: String) -> int:
	return int(_find(data().get("parts", []), part_key).get("etype", 0))


## 词条成色权重：{normal, fine, perfect}（百分数）
static func grade_weights() -> Dictionary:
	return data().get("grade_weights", {}).duplicate()


# ---- 套装 ----

## 套装共用规则：quality、level、first_kill_level、first_kill_floors、armor_kind、affixes、true_seal
static func set_rule() -> Dictionary:
	return data().get("set_rule", {}).duplicate(true)


## 某印的套装：name、role、pieces（6 件：part、name、etype）、bonuses（count 2／3／5 各一档，effects）。没有为空。
static func set_of(seal_key: String) -> Dictionary:
	var s = data().get("sets", {}).get(seal_key)
	return s.duplicate(true) if s is Dictionary else {}


## 某印套装某档（2／3／5 件）的效果列表；没有这一档为空
static func set_bonus(seal_key: String, count: int) -> Array:
	for b in set_of(seal_key).get("bonuses", []):
		if int(b.get("count", 0)) == count:
			return b.get("effects", [])
	return []


# ---- 毕业武器 ----

## 毕业武器共用规则：quality、level、base_mult、affixes、true_seal
static func weapon_rule() -> Dictionary:
	return data().get("weapon_rule", {}).duplicate(true)


## 12 个武器类：key、name、wtype_id（原版 System.weaponTypes 的编号）
static func weapon_types() -> Array:
	return data().get("weapon_types", []).duplicate(true)


## 某印的流派：name、types（两类的键；默印是 "any"）、mark（流派印记效果）、true_extra（真印追加）。没有为空。
static func school(seal_key: String) -> Dictionary:
	var s = data().get("schools", {}).get(seal_key)
	return s.duplicate(true) if s is Dictionary else {}


## 全部毕业武器：key、seal、type（武器类键；默印为 null，type_random 为 true）、name、effects（独有效果）
static func weapons() -> Array:
	return data().get("weapons", []).duplicate(true)


## 某印的毕业武器（前六印各两把，默印一把）
static func weapons_of_seal(seal_key: String) -> Array:
	return weapons().filter(func(w): return str(w.get("seal", "")) == seal_key)


## 某武器类（键或中文类名）的毕业武器；默印那把随机类，不在这里返回。没有为空。
static func weapon_of_type(type_key_or_name: String) -> Dictionary:
	var key := type_key_or_name
	for t in data().get("weapon_types", []):
		if str(t.get("name", "")) == type_key_or_name:
			key = str(t.get("key", ""))
	for w in data().get("weapons", []):
		if w.get("type") != null and str(w.get("type")) == key:
			return w.duplicate(true)
	return {}


## 按键查毕业武器
static func weapon(key: String) -> Dictionary:
	return _find(data().get("weapons", []), key).duplicate(true)


# ---- 神器 ----

## 神器规则：etype（17）、team_active_max（全队同时生效几件）
static func artifact_rule() -> Dictionary:
	return data().get("artifact_rule", {}).duplicate()


## 神器列表：key、name、effects、costs
static func artifacts() -> Array:
	return data().get("artifacts", []).duplicate(true)


static func artifact(key: String) -> Dictionary:
	return _find(data().get("artifacts", []), key).duplicate(true)


# ---- 效果码 ----

## 表头登记的效果码：{code: 含义}
static func effect_codes() -> Dictionary:
	return data().get("_note", {}).get("effect_codes", {})


## 表里实际用到的效果码（去重，按出现顺序）
static func used_effect_codes() -> Array:
	var out := []
	for k in data():
		if k != "_note":
			_scan_codes(data()[k], out)
	return out


static func _scan_codes(v, out: Array) -> void:
	if v is Dictionary:
		if v.has("code") and not out.has(str(v.code)):
			out.append(str(v.code))
		for k in v:
			_scan_codes(v[k], out)
	elif v is Array:
		for x in v:
			_scan_codes(x, out)


# ---- 数值要好看（Kyo 11-10）----

## 表里设计数值含数字 4 的：返回「路径=值」列表。豁免键（编号、类型号、层数、件数）写在表头 nice_number_exempt。
static func nice_number_violations() -> Array:
	var exempt: Array = data().get("nice_number_exempt", [])
	var out := []
	_scan_nice(data(), "", exempt, out)
	return out


static func _scan_nice(v, path: String, exempt: Array, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if not exempt.has(k):
				_scan_nice(v[k], path + "/" + str(k), exempt, out)
	elif v is Array:
		for i in v.size():
			_scan_nice(v[i], path + "/" + str(i), exempt, out)
	elif v is float or v is int:
		var s := _num_text(float(v))
		if s.contains("4"):
			out.append(path + "=" + s)


## 和 XTianqiBalance 一样的写法：整数不带小数点，其余去掉尾零
static func _num_text(x: float) -> String:
	if x == floorf(x):
		return str(int(x))
	return String.num(x, 6).rstrip("0").rstrip(".")


static func _find(rows: Array, key: String) -> Dictionary:
	for r in rows:
		if r is Dictionary and str(r.get("key", "")) == key:
			return r
	return {}
