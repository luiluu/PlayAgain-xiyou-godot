class_name XGearQuery
extends RefCounted
## 装备词条检索与排序（正式西游 v0.28 Codex installEquipmentStatusRuntime 的数据部分；面板见 ui/gear_search.gd）。
## - 词条行：备注 <pos=APs text=… size=…>（先经 CodexElements.normalizeEquipmentText＝XHelpCard.gear_text、全伤→全属性伤害，
##   去掉等级需求/DreamX_bonus），每行分类（kinds）、词条键（数字换成 #）、单个数字的绝对值、来源（底材有＝固定，否则随机/附加）。
## - 筛选：搜索词（别名化后全部包含）、分类、部位（w+武器类型 / a+装备类型）、品质（七档或 L+旧档）、指定词条；
##   位置（背包/已装备）只在物品页与面板结果里生效。
## - 排序：原有顺序／战力／品质（默认）／词条数／名称／8 项能力／单项词条数值；同值再按品质名次（七档×16＋旧档）、
##   名字（中文拼音，XZhCollation）、ID（实例先后）、原顺序。排序选择存进配置（ConfigManager.codexEquipmentSort）。

const CATEGORIES := ["输出", "防御", "生存", "控制", "行动", "资源", "掉落", "成长", "特殊"]
const PARAMS := ["生命", "魔法", "物攻", "物防", "魔攻", "魔防", "敏捷", "幸运"]
const SORTS := ["original", "power", "quality", "count", "name", "term",
	"param0", "param1", "param2", "param3", "param4", "param5", "param6", "param7"]
## 面板「排序」下拉的文字（term 只在有可排序的指定词条时列出）
const SORT_NAMES := {"original": "原有顺序", "power": "战力高 → 低", "quality": "品质高 → 低", "count": "词条多 → 少",
	"name": "名称顺序", "term": "单项词条数值高 → 低"}
const SCOPES := [["all", "背包 + 已装备"], ["bag", "仅背包"], ["worn", "仅已装备"]]

static var _cache := {}
static var _re := {}


static func _rx(p: String) -> RegEx:
	if not _re.has(p):
		_re[p] = RegEx.create_from_string(p)
	return _re[p]


## 检索条件（defaults）：sort/sortTerm 来自配置
static func defaults() -> Dictionary:
	return {"query": "", "category": "", "term": "", "sort": "quality", "quality": "", "type": "", "scope": "all", "sortTerm": ""}


static func default_view() -> Dictionary:
	var f := defaults()
	var s := sort_settings(XConfig.equipment_sort())
	f.sort = s.sort
	f.sortTerm = s.term
	return f


## sortSettings：不认识的排序回到品质；词条排序没有词条也回到品质；词条最长 500 字，全属性伤害记作全伤
static func sort_settings(value: Dictionary) -> Dictionary:
	var sort := str(value.get("sort", "quality"))
	if sort not in SORTS:
		sort = "quality"
	var term = value.get("term", "")
	term = str(term).left(500).replace("全属性伤害", "全伤") if term is String else ""
	if sort == "term" and term == "":
		sort = "quality"
	return {"sort": sort, "term": term}


static func set_sort(f: Dictionary, sort: String, term: String) -> void:
	var s := sort_settings({"sort": sort, "term": term})
	XConfig.set_equipment_sort(s)
	f.sort = s.sort
	f.sortTerm = s.term


# ---- 文字 ----
## Codex text()：全伤→全属性伤害，去掉 \c[…] 等转义、<…> 与 \{ \} 等
static func text(s: String) -> String:
	s = _rx("全伤(?:害)?").sub(s, "全属性伤害", true)
	s = _rx("(?i)\\\\[a-z]+\\[[^\\]]*\\]").sub(s, "", true)
	s = _rx("(?i)\u001b[a-z]+\\[[^\\]]*\\]").sub(s, "", true)
	s = _rx("<[^>]*>").sub(s, "", true)
	s = _rx("\\\\[{}.!|><^]").sub(s, "", true)
	return s.strip_edges()


## alias()：小写＋常用别名
static func alias(s: String) -> String:
	s = text(s).to_lower()
	for r in [["(?i)最大\\s*hp|生命值|血量|最大生命", "生命"], ["(?i)最大\\s*mp|魔法值|法力", "魔法"], ["物理攻击|攻击力", "物攻"],
			["魔法攻击|魔法力", "魔攻"], ["物理防御", "物防"], ["魔法防御", "魔防"], ["掉落率|掉落概率|掉宝率", "掉宝"]]:
		s = _rx(r[0]).sub(s, r[1], true)
	return s


static func raw_lines(note: String) -> Array:
	note = XHelpCard.gear_text(note)
	var out := []
	for m in _rx("(?i)<pos=APs\\s+text=([\\s\\S]*?)\\s+size=").search_all(note):
		var line := text(m.get_string(1))
		if line != "" and _rx("(?i)等级需求|需求等级|DreamX_bonus").search(line) == null:
			out.append(line)
	return out


static func kinds(line: String) -> Array:
	var s := alias(line)
	var a := []
	for k in [["掉宝|掉落|金币|金钱|寻宝|稀有", "掉落"], ["经验|成长|熟练|升级|永久|盛名|叠生命", "成长"],
			["消耗|技能费用|回蓝|魔法再生|怒气|特技恢复|tp|mp", "资源"], ["复活|回复|恢复|再生|生命|吸血|治疗|回血", "生存"],
			["减伤|防御|物防|魔防|闪避|回避|免疫|护盾|抗性|抵抗|受到", "防御"],
			["诅咒|中毒|剧毒|眩晕|麻痹|封印|沉默|灼伤|流血|睡眠|控制|削弱|减速", "控制"],
			["再动|行动|攻击次数|攻击速度|敏捷|先制|连击", "行动"], ["物攻|魔攻|伤害|暴击|穿透|命中|攻击|全伤|增伤|元素", "输出"]]:
		if _rx(k[0]).search(s) != null:
			a.append(k[1])
	return a if not a.is_empty() else ["特殊"]


static func term_key(line: String) -> String:
	var s := alias(line).replace("全属性伤害", "全伤")
	s = _rx("(?i)^(?:混沌神话|神话|太古|mod)?特效\\s*[:：]\\s*").sub(s, "")
	s = _rx("[+\\-＋－]?\\d+(?:\\.\\d+)?").sub(s, "#", true)
	return _rx("\\s+").sub(s, "", true)


## 品质：备注 <quality:N>（没有为 0）；名次 = 七档×16＋旧档（CodexQuality.rank）
static func quality(item: Dictionary) -> int:
	return XGear.quality(item)


static func rank(q: int) -> int:
	return XQuality.grade_of(q) * 16 + q


static func is_gear(item: Dictionary) -> bool:
	return XItemMarks.is_gear(item)


## record()：词条行、分类与搜索文字（按备注/描述/品质/能力缓存）
static func record(item: Dictionary) -> Dictionary:
	var description := text(XHelpCard.gear_text(str(item.get("description", ""))))
	# 正式版 WeakMap 按装备对象隔离；这里按内容缓存，必须包含名字与底材身份。
	var sig := JSON.stringify([item.get("kind", ""), item.get("base"), item.get("name", ""),
		item.get("note", ""), item.get("description", ""), quality(item), item.get("params", [])])
	var c = _cache.get(sig)
	if c != null:
		return c
	var base := XGear.template(str(item.get("kind", "")), int(item.get("base", 0))) if item.has("base") else item
	var remaining := raw_lines(str(base.get("note", "")))
	var rows := []
	for line in raw_lines(str(item.get("note", ""))):
		var i := remaining.find(line)
		var source := "固定" if i >= 0 or not item.has("base") else "随机 / 附加"
		if i >= 0:
			remaining.remove_at(i)
		var nums := _rx("[+\\-＋－]?\\d+(?:\\.\\d+)?").search_all(line)
		var n = absf(float(nums[0].get_string().replace("＋", "+").replace("－", "-"))) if nums.size() == 1 else null
		rows.append({"text": line, "categories": kinds(line), "key": term_key(line), "number": n, "source": source})
	if rows.is_empty() and description != "":
		rows.append({"text": description, "categories": kinds(description), "key": term_key(description), "number": null, "source": "固定"})
	var cats := CATEGORIES.filter(func(cat): return rows.any(func(r): return r.categories.has(cat)))
	var search := alias(str(item.get("name", "")) + " " + description + " " + " ".join(rows.map(func(r): return r.text)))
	var value := {"rows": rows, "categories": cats, "search": search, "quality": quality(item), "description": description}
	_cache[sig] = value
	return value


static func type_key(item: Dictionary) -> String:
	return "w%d" % int(item.get("wtypeId", 0)) if str(item.get("kind", "")) == "weapon" else "a%d" % int(item.get("etypeId", 0))


static func matches(item: Dictionary, f: Dictionary) -> bool:
	if not is_gear(item):
		return false
	var r := record(item)
	if str(f.type) != "" and type_key(item) != str(f.type):
		return false
	var q := str(f.quality)
	if q.begins_with("L") and q.substr(1).is_valid_int():
		if r.quality != int(q.substr(1)):
			return false
	elif q != "" and XQuality.grade_of(r.quality) != int(q):
		return false
	if str(f.category) != "" and not r.categories.has(str(f.category)):
		return false
	if str(f.term) != "" and not r.rows.any(func(row): return row.key == str(f.term)):
		return false
	for w in _rx("\\s+").sub(alias(str(f.query)), " ", true).split(" ", false):
		if not str(r.search).contains(w):
			return false
	return true


static func metric(item: Dictionary, f: Dictionary) -> float:
	var r := record(item)
	var sort := str(f.sort)
	if sort == "count":
		return r.rows.size()
	if sort == "power":
		return float(XPower.equipment(item).get("total", 0.0))
	if sort.begins_with("param"):
		var params: Array = item.get("params", [])
		var i := int(sort.substr(5))
		return float(params[i]) if i < params.size() else 0.0
	if sort == "term":
		var key := str(f.sortTerm) if str(f.sortTerm) != "" else str(f.term)
		var best := -INF
		for row in r.rows:
			if row.key == key and row.number != null:
				best = maxf(best, float(row.number))
		return best
	return rank(r.quality)


static func _name(item: Dictionary) -> String:
	return text(str(item.get("name", "")))


## compare()：负数 a 在前
static func compare(a: Dictionary, b: Dictionary, f: Dictionary) -> int:
	var sort := str(f.sort)
	if sort == "original":
		return 0
	if sort == "name":
		return XZhCollation.compare(_name(a), _name(b))
	var ma := metric(a, f)
	var mb := metric(b, f)
	if ma != mb:
		return -1 if mb < ma else 1
	var ra := rank(quality(a))
	var rb := rank(quality(b))
	if ra != rb:
		return -1 if rb < ra else 1
	var n := XZhCollation.compare(_name(a), _name(b))
	if n != 0:
		return n
	var ia := _id(a)
	var ib := _id(b)
	return 0 if ia == ib else (-1 if ia < ib else 1)


## 独立装备的 ID 即实例先后
static func _id(item: Dictionary) -> int:
	if item.has("instanceId"):
		return int(str(item.instanceId).get_slice(":", 1))
	return int(item.get("id", 0))


## filterList：列表项 {rec, …}；装备筛选后按 compare 稳定排序，rec 为空的项（「卸载」）留在最后
static func filter_entries(entries: Array, f: Dictionary) -> Array:
	var keyed := []
	var empty := []
	for e in entries:
		if (e.rec as Dictionary).is_empty():
			empty.append(e)
		elif is_gear(e.rec) and matches(e.rec, f):
			keyed.append([e, keyed.size()])
	keyed.sort_custom(func(x, y):
		var c := compare(x[0].rec, y[0].rec, f)
		return c < 0 if c != 0 else x[1] < y[1])
	return keyed.map(func(x): return x[0]) + empty


## collection()：背包武器、防具，再加已有角色身上的装备（不招募角色）；每项 {item, owner, key}
static func collection(s: XState) -> Array:
	var out := []
	var seen := {}
	for kind in ["weapon", "armor"]:
		var bag := s.gear.filter(func(e): return e.kind == kind)
		bag.sort_custom(func(a, b): return _id(a) < _id(b))
		for g in bag:
			_add(out, seen, g, "")
	var ids := s.actors.keys()
	ids.sort()
	for id in ids:
		var a: XActor = s.actors[id]
		for e in a.equip_list():
			_add(out, seen, e, a.display_name())
	return out


static func _add(out: Array, seen: Dictionary, item: Dictionary, owner: String) -> void:
	if not is_gear(item):
		return
	var key := str(item.get("instanceId", type_key(item) + ":" + str(item.get("id", 0)) + ":" + (owner if owner != "" else "bag")))
	if seen.has(key):
		return
	seen[key] = true
	out.append({"item": item, "owner": owner, "key": key})
