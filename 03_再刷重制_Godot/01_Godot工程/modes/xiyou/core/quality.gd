class_name XQuality
extends RefCounted
## 七档品质（正式西游 v0.15～v0.19 installUnifiedQualityRuntime）：只换名称、颜色与说明卡边框；
## 旧 0～15 档（备注 <quality:N>）的数值、掉落、排序先后都不变，排序仍按旧档细分（XGear.quality）。
## 旧档 → 七档：0粗糙/1普通→普通、2→优秀、3→精良、4→史诗、5神器/6传说/7传承→传说、
## 8不朽/9传家宝/10远古/11太古/13 Mod专属→不朽、12超·神器/14神话Mod/15混沌Mod→神话。
## 列表名字：有品质标记的按七档色，没有的照 ItemColor 按 <ici>（缺省 1 白）；战斗技能/物品列表原版白字，不走这里。

const NAMES := ["普通", "优秀", "精良", "史诗", "传说", "不朽", "神话"]
const COLORS := ["rgba(235,240,247,1)", "rgba(128,255,28,1)", "rgba(57,185,255,1)", "rgba(128,100,254,1)",
	"rgba(255,160,64,1)", "rgba(255,214,90,1)", "rgba(255,72,60,1)"]
## 说明卡发光边框（system/Window{N}）：白、绿、蓝、紫、橙、金（不朽）、红（神话）
const WINDOWS := [1, 2, 3, 4, 7, 8, 10]
const ITEM_GRADES := [0, 0, 1, 2, 3, 4, 4, 4, 5, 5, 5, 5, 6, 5, 6, 6]
const GEAR_TAGS := {7: "传承", 9: "传家宝", 10: "远古", 11: "太古", 13: "Mod专属", 14: "神话Mod", 15: "混沌Mod"}
## ItemColor 改写后的 Window_Base.itemColor（1 为 textColor(0) 白）
const ICI_COLORS := {1: "ffffff", 2: "80ff80", 3: "39b9ff", 4: "8064f5", 5: "ff28ff", 6: "ff8000", 7: "ffff00",
	8: "b0b0b0", 9: "ffb100", 10: "8d0919", 11: "ab716e", 12: "a891c8", 13: "2c968c", 14: "fffa32", 15: "a873b9"}


static func has_quality(item: Dictionary) -> bool:
	return item.get("meta", {}).has("quality")


## 旧档（Q.legacy：没有标记或不是数字时为 1）
static func legacy(item: Dictionary) -> int:
	var q := str(item.get("meta", {}).get("quality", "")).strip_edges()
	return maxi(0, int(q)) if q.is_valid_int() and int(q) >= 0 else 1


static func grade_of(q: int) -> int:
	return ITEM_GRADES[q] if q >= 0 and q < ITEM_GRADES.size() else (6 if q >= 12 else 0)


static func grade(item: Dictionary) -> int:
	return grade_of(legacy(item))


static func grade_name(item: Dictionary) -> String:
	return NAMES[grade(item)]


static func color_text(item: Dictionary) -> String:
	return COLORS[grade(item)]


static func color(item: Dictionary) -> Color:
	return parse_rgba(color_text(item))


## 说明卡品质行：装备带标签，例如「不朽（传家宝）」；神武为防具类型 17
static func label(item: Dictionary, kind: String) -> String:
	var tags := []
	if kind == "weapon" or kind == "armor":
		var t = GEAR_TAGS.get(legacy(item))
		if t != null:
			tags.append(t)
		if kind == "armor" and int(item.get("etypeId", 0)) == 17:
			tags.append("神武")
	return grade_name(item) + ("（%s）" % "·".join(tags) if not tags.is_empty() else "")


## 说明卡边框：旧档 0～15 换成七档代表图
static func window_skin(q: int) -> int:
	return WINDOWS[grade_of(q)] if q >= 0 and q <= 15 else q


## 列表名字色：有品质按七档，否则按 <ici>
static func list_color(item: Dictionary) -> Color:
	if has_quality(item):
		return color(item)
	var ici := str(item.get("meta", {}).get("ici", "1")).strip_edges()
	return Color(ICI_COLORS.get(int(ici) if ici.is_valid_int() else 1, "ffffff"))


static func parse_rgba(text: String) -> Color:
	var m := RegEx.create_from_string("rgba\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*([\\d.]+)\\s*\\)").search(text)
	if m == null:
		return Color.WHITE
	return Color(float(m.get_string(1)) / 255, float(m.get_string(2)) / 255, float(m.get_string(3)) / 255, float(m.get_string(4)))
