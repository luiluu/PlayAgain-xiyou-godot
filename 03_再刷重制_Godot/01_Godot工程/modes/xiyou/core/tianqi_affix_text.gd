class_name XTianqiAffixText
extends RefCounted
## 天启篇词条的玩家文字（来源：天启篇词条重构设计稿 v0.3），模板在 tianqi_data/affix_text.json。
## 只做文字：数值一律从 XTianqiAffixTable 取来填进模板，文字表里不存数；不接装备界面、不掷词条、不碰存档。
## 行的样子：〔成色标记〕〔稀有标记〕〔光环前缀〕正文，如「物攻 +8%」「极·〔稀有〕每回合有 20% 几率多行动一次」
## 「〔四阶·上品〕全队·八项属性 +5%」。普通不标；连击固定 +1，不标成色。
## extra 传掷出来的变体：{"element": "fire"}（元素增伤、元素抗性）、{"variant": "draw"/"avoid"}（引敌／避敌）；
## 不传时行里写「某一系」「引敌／避敌 ±」，详细说明照样写全。
## Python 那边 03_转换工具/天启篇数据校验.py 的 affix_text 检查用同一套填法，改一边要改另一边。

const DATA := "res://modes/xiyou/tianqi_data/affix_text.json"
const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = d if d is Dictionary else {}
	return _data


## 测试用：换掉文字表（传空字典＝下次重新读文件）
static func reload(d := {}) -> void:
	_data = d


static func entry(key: String) -> Dictionary:
	for x in data().get("affixes", []):
		if str(x.get("key", "")) == key:
			return x
	return {}


## 数字照表里原样：整数不带小数点，小数去掉尾零（0.5、1.5）
static func num_text(x) -> String:
	var f := float(x)
	if f == floorf(f):
		return str(int(f))
	var s := String.num(f, 6)
	return s.rstrip("0").rstrip(".") if "." in s else s


static func _fixed(key: String) -> bool:
	return bool(T.affix(key).get("fixed", false))


static func _list_names(list_key: String) -> Array:
	return T.data().get(list_key, []).map(func(e): return str(e.get("name", "")))


static func _element_name(key: String) -> String:
	for e in T.data().get("elements", []):
		if str(e.get("key", "")) == key:
			return str(e.get("name", ""))
	return ""


## 填模板要用的全部值；不能出（阶不够、键不认识）返回空字典
static func _fills(key: String, tier: int, grade: String, extra: Dictionary) -> Dictionary:
	var v = T.value(key, tier, grade)
	if v == null or entry(key).is_empty():
		return {}
	var a := T.affix(key)
	var d := data()
	var tier_names: Array = d.get("tier_names", [])
	var f := {
		"v": num_text(v),
		"tier": str(tier_names[tier - 1]) if tier - 1 < tier_names.size() else "",
		"elements": str(d.get("element_join", "、")).join(PackedStringArray(_list_names("elements"))),
	}
	var v2 = T.secondary_value(key, tier, grade)
	if v2 != null:
		f["v2"] = num_text(v2)
	var el := _element_name(str(extra.get("element", "")))
	f["element"] = el if el != "" else str(d.get("element_any", ""))
	var variants: Array = a.get("variants", [])
	if not variants.is_empty():
		f["variants"] = "、".join(PackedStringArray(variants.map(func(x): return str(x.name))))
		f["variant"] = str(a.get("name", ""))
		f["sign"] = str(d.get("variant_any_sign", ""))
		for x in variants:
			if str(x.key) == str(extra.get("variant", "")):
				f["variant"] = str(x.name)
				f["sign"] = str(d.get("variant_signs", {}).get(str(x.get("direction", "")), ""))
	for k in ["cap_total", "cap_per_hit_mhp"]:
		if a.has(k):
			f["cap"] = num_text(a[k])
	if a.get("condition", {}).has("rate"):
		f["rate"] = num_text(a.condition.rate)
	if a.has("turns"):
		f["turns"] = num_text(a.turns)
	return f


static func _fill(template: String, f: Dictionary) -> String:
	return template.format(f)


## 正文（不带成色、稀有标记；光环带「全队·」前缀）。不能出返回 ""。
static func body(key: String, tier: int, grade: String, extra := {}) -> String:
	var f := _fills(key, tier, grade, extra)
	if f.is_empty():
		return ""
	var prefix := str(data().get("aura_prefix", "")) if str(T.affix(key).get("layer", "")) == "aura" else ""
	return prefix + _fill(str(entry(key).get("line", "")), f)


## 行首标记：[{text, color}]，先成色（普通没有；连击没有成色）、再稀有。color 是 XQuality.ICI_COLORS 的编号。
static func marks(key: String, tier: int, grade: String) -> Array:
	var f := _fills(key, tier, grade, {})
	if f.is_empty():
		return []
	var out := []
	var g: Dictionary = data().get("grades", {}).get(grade, {})
	if not _fixed(key) and str(g.get("mark", "")) != "":
		out.append({"text": _fill(str(g.mark), f), "color": g.get("color")})
	if bool(T.affix(key).get("rare", false)):
		var r: Dictionary = data().get("rare", {})
		out.append({"text": str(r.get("mark", "")), "color": r.get("color")})
	return out


## 装备说明里的一行：标记＋正文。不能出返回 ""。
static func line(key: String, tier: int, grade: String, extra := {}) -> String:
	var b := body(key, tier, grade, extra)
	if b == "":
		return ""
	return "".join(PackedStringArray(marks(key, tier, grade).map(func(m): return str(m.text)))) + b


## 正文颜色：极用金色，其余按层
static func line_color(key: String, grade: String) -> int:
	var g: Dictionary = data().get("grades", {}).get(grade, {})
	if not _fixed(key) and g.get("line_color") != null:
		return int(g.line_color)
	return int(data().get("layers", {}).get(str(T.affix(key).get("layer", "")), {}).get("color", 1))


## 给界面拼富文本：[{text, color}]，标记各用自己的颜色，正文用 line_color
static func segments(key: String, tier: int, grade: String, extra := {}) -> Array:
	var b := body(key, tier, grade, extra)
	if b == "":
		return []
	var out := marks(key, tier, grade)
	out.append({"text": b, "color": line_color(key, grade)})
	return out


## 查看词条时的完整说明：第一行「层词条 · 阶 · 成色」，再写效果、稀有、叠法，用换行分开。不能出返回 ""。
static func detail(key: String, tier: int, grade: String, extra := {}) -> String:
	var f := _fills(key, tier, grade, extra)
	if f.is_empty():
		return ""
	var d := data()
	var a := T.affix(key)
	var hf := f.duplicate()
	hf["layer"] = str(d.get("layers", {}).get(str(a.get("layer", "")), {}).get("name", ""))
	hf["grade"] = str(d.get("grades", {}).get(grade, {}).get("name", ""))
	var head := str(d.get("detail_header_fixed" if _fixed(key) else "detail_header", ""))
	var lines := [_fill(head, hf), _fill(str(entry(key).get("detail", "")), f)]
	if bool(a.get("rare", false)):
		lines.append(str(d.get("rare", {}).get("detail", "")))
	var st := str(d.get("stack_text", {}).get(str(a.get("stack", "")), ""))
	if st != "":
		lines.append(st)
	return "\n".join(PackedStringArray(lines))
