class_name XTextFix
extends RefCounted
## 【cc·未经审查】原版文字错的加载时修正（乙类文字审 00_项目管理/核查/文字审查乙类_xa_text-audit-b.md，cc/text-fix-b）。
## XDB 读进数据库表、地图时就地改玩家看得到的字，不动 generated 产物；重制版与天启篇都生效。
##
## 改哪些字段：数据库 name／nickname／profile／description／message1～4、备注里 <pos=… text=… size=…> 的 text 段、
## 公共事件／敌群／地图事件的 401／405 对话行与 102 选项。备注的其余部分（notetag、动作序列、脚本）、伤害公式、插件参数都不碰。
##
## 六个开关各一个 O 号（00_设计/优化登记.md），默认开；关掉后 clear_cache() 让表重读即回原版文字：
## - STRIP_ZW（O-489）：剥零宽控制符 U+FEFF、U+200B、U+200C。
## - NAMEBOX（O-490）：事件对话名字框——行首 <名字> 补前导 \n、/n< 写反改 \n<、\c\[ 双转义改 \c[、行首孤立 \n（后面不是 <、[、字母）删掉。
## - PAIRS（O-491）：成对标点——只有左单引号／只有右双引号的成对改回 ‘…’／“…”；括号能配平而半角全角混搭的一对改全角。
## - DICT（O-492）：词典替换（text_fix/rules.json 的 dict：挑符文、超级Boos、奥数→奥术、终级、枪决……）。
## - TRAD（O-493）：繁体异体字逐字转简体（rules.json 的 trad）。
## - OVERRIDES（O-494）：逐条覆盖表 text_fix/overrides.json（位置＋原文子串＋改成，原文对不上就不套用并报警）。
## 次序：先逐条覆盖（from 按原版原文写），再套统一规则。
## 代码里按名字认敌人档位的（XZhenqi.is_named_boss、XEncounterTarget）同时认「超级Boos」「超级Boss」。

static var STRIP_ZW := true
static var NAMEBOX := true
static var PAIRS := true
static var DICT := true
static var TRAD := true
static var OVERRIDES := true

const RULES_PATH := "res://modes/xiyou/text_fix/rules.json"
const OVERRIDES_PATH := "res://modes/xiyou/text_fix/overrides.json"
## 改了修正逻辑（不只是 rules／overrides 数据）就加 1，让旧的修正缓存作废（导出版脚本源码可能读不到，不能只靠源码哈希）
const CACHE_VER := 3
const TABLES := ["Actors", "Classes", "Skills", "Items", "Weapons", "Armors", "Enemies", "States", "Troops", "CommonEvents",
	"MapInfos", "EquipSuits", "Runewords"]
const TEXT_KEYS := ["name", "nickname", "profile", "description", "message1", "message2", "message3", "message4"]

## 覆盖表原文对不上的条目（「位置：原因」），测试与 07_开发环境/文字审 导出脚本读它
static var warnings: Array = []
static var _rules = null
static var _overrides = null  # {"Skills": [条目…], "Map004": […]}
static var _dict := []  # [[RegEx 或 null, from, to]]
static var _gate: RegEx  # 零宽／繁体／词典任一命中的总预筛
static var _pos_re: RegEx
static var _namebox_re: RegEx
static var _lone_n_re: RegEx


## 测试用：一次开关全部（按原版比对时关掉），并清缓存让表重读
static func set_all(on: bool) -> void:
	STRIP_ZW = on
	NAMEBOX = on
	PAIRS = on
	DICT = on
	TRAD = on
	OVERRIDES = on
	clear_cache()


static func any_on() -> bool:
	return STRIP_ZW or NAMEBOX or PAIRS or DICT or TRAD or OVERRIDES


## 清掉 XDB 里受影响的表与地图缓存，下次读按当前开关重新处理
static func clear_cache() -> void:
	for k in XDB._tables.keys():
		if str(k).begins_with("map:") or TABLES.has(k):
			XDB._tables.erase(k)


static func rules() -> Dictionary:
	if _rules == null:
		var d = XDB.parse_file(RULES_PATH) if FileAccess.file_exists(RULES_PATH) else null
		_rules = d if d is Dictionary else {}
		_dict = []
		var gate := []
		for k in _rules.get("trad", {}):
			gate.append(_escape(str(k)))
		for e in _rules.get("dict", []):
			var from := str(e.get("from", ""))
			if from == "":
				continue
			var re: RegEx = null
			if bool(e.get("re", false)):
				re = RegEx.create_from_string(from)
				if re == null or not re.is_valid():
					push_warning("XTextFix: rules.json 词典正则无效 " + from)
					continue
				gate.append(_escape(str(e.get("gate", ""))) if str(e.get("gate", "")) != "" else from.trim_prefix("^"))  # 预筛只用字面文字（正则里的后顾、行首锚点会让整段预筛变慢或对不上）
			else:
				gate.append(_escape(from))
			_dict.append([re, from, str(e.get("to", ""))])
		gate.append("\ufeff")
		gate.append("\u200b")
		gate.append("\u200c")
		_gate = RegEx.create_from_string("|".join(gate))
		_pos_re = RegEx.create_from_string("^(<pos=\\S+\\s+text=)([\\s\\S]*?)(\\s+size=[\\s\\S]*)$")
		_namebox_re = RegEx.create_from_string("^<([^<>\\\\:]{1,20})>")
		_lone_n_re = RegEx.create_from_string("^\\\\n(?=[^<\\[A-Za-z])")
	return _rules


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if "\\^$.|?*+()[]{}".contains(ch) else ch
	return out


static func overrides() -> Dictionary:
	if _overrides == null:
		_overrides = {}
		var d = XDB.parse_file(OVERRIDES_PATH) if FileAccess.file_exists(OVERRIDES_PATH) else null
		for e in (d.get("overrides", []) if d is Dictionary else []):
			var at := str(e.get("at", ""))
			var key := at.get_slice(":", 0)
			if not _overrides.has(key):
				_overrides[key] = []
			_overrides[key].append(e)
	return _overrides


# ---------- 入口（XDB.table／XDB.map 读进来时调） ----------

## 读一张表并修正（XDB.table 调）。修正要扫十几万行（Skills 约 0.25 秒），所以修正后的结果连同覆盖表报警一起
## 存进 XDB 的解析缓存，键＝源文件内容＋开关状态＋rules／overrides 内容；XIYOU_JSON_CACHE=0 时每次现算。
static func load_table(name: String) -> Variant:
	var rel := "db/%s.json" % name
	var path := XDB.BASE + rel
	var bytes := FileAccess.get_file_as_bytes(path) if XDB.json_cache and any_on() else PackedByteArray()
	if bytes.is_empty():
		var v = XDB.load_json(rel)
		patch_table(name, v)
		return v
	var key := path + "#textfix" + _signature()
	var file := XDB._cache_file(key, bytes)
	var hit = XDB._cache_read(file)
	if hit[0] and hit[1] is Dictionary and hit[1].has("data"):
		for w in hit[1].get("warnings", []):
			_warn(str(w))
		return hit[1].data
	var value = XDB._parse(path)
	if value == null:
		return null
	var before := warnings.size()
	patch_table(name, value)
	XDB._cache_write(key, file, {"data": value, "warnings": warnings.slice(before)})
	return value


static var _sig_files := ""


static func _signature() -> String:
	if _sig_files == "":
		var h := HashingContext.new()
		h.start(HashingContext.HASH_SHA256)
		h.update(str(CACHE_VER).to_utf8_buffer())
		for p in [RULES_PATH, OVERRIDES_PATH, "res://modes/xiyou/core/text_fix.gd"]:
			h.update(FileAccess.get_file_as_bytes(p))
		_sig_files = h.finish().hex_encode().substr(0, 16)
	return "%d%d%d%d%d%d.%s" % [int(STRIP_ZW), int(NAMEBOX), int(PAIRS), int(DICT), int(TRAD), int(OVERRIDES), _sig_files]


static func _warn(msg: String) -> void:
	if not warnings.has(msg):
		warnings.append(msg)
		push_warning("XTextFix 覆盖表没套用 " + msg)


static func patch_table(name: String, data) -> void:
	if not any_on() or not TABLES.has(name) or not data is Array:
		return
	if OVERRIDES:
		for e in overrides().get(name, []):
			_apply_override(e, data, name)
	if not (STRIP_ZW or NAMEBOX or PAIRS or DICT or TRAD):
		return
	rules()
	for r in data:
		if not r is Dictionary:
			continue
		for k in TEXT_KEYS:
			var v = r.get(k)
			if v is String and v != "":
				r[k] = fix(v)
		var note = r.get("note")
		if note is String and note.contains("<pos="):
			r["note"] = _fix_note(note)
		match name:
			"CommonEvents":
				_fix_list(r.get("list"))
			"Troops":
				for p in r.get("pages", []):
					if p is Dictionary:
						_fix_list(p.get("list"))


static func patch_map(map_id: int, data) -> void:
	if not any_on() or not data is Dictionary:
		return
	if OVERRIDES:
		for e in overrides().get("Map%03d" % map_id, []):
			_apply_override(e, data, "Map%03d" % map_id)
	if not (STRIP_ZW or NAMEBOX or PAIRS or DICT or TRAD):
		return
	rules()
	if data.get("displayName") is String and data.displayName != "":
		data.displayName = fix(data.displayName)
	for ev in data.get("events", []):
		if ev is Dictionary:
			for p in ev.get("pages", []):
				if p is Dictionary:
					_fix_list(p.get("list"))


# ---------- 统一规则 ----------

## 一段玩家可见文字过一遍统一规则（event＝事件对话行，才做名字框那一组）
static func fix(s: String, event := false) -> String:
	rules()
	if event and NAMEBOX:
		s = _namebox(s)
	if _gate.search(s) != null:
		if STRIP_ZW:
			s = s.replace("\ufeff", "").replace("\u200b", "").replace("\u200c", "")
		if TRAD:
			var trad: Dictionary = _rules.get("trad", {})
			for k in trad:
				if s.contains(k):
					s = s.replace(k, str(trad[k]))
		if DICT:
			for d in _dict:
				if d[0] != null:
					s = (d[0] as RegEx).sub(s, d[2], true)
				elif s.contains(d[1]):
					s = s.replace(d[1], d[2])
	if PAIRS and _pair_hint(s):
		s = _pairs(s)
	return s


static func _namebox(s: String) -> String:
	if s.begins_with("/n<"):
		s = "\\n<" + s.substr(3)
	var m := _namebox_re.search(s)
	if m != null and not (_rules.get("namebox_skip", []) as Array).has(m.get_string(1)):
		s = "\\n" + s
	elif _lone_n_re.search(s) != null:
		s = s.substr(2)
	if s.contains("\\["):
		s = s.replace("\\c\\[", "\\c[").replace("\\C\\[", "\\C[")
	return s


## 备注里只处理 <pos=… text=… size=…> 行（其余是 notetag、动作序列、脚本，体积大，不扫）
static func _fix_note(note: String) -> String:
	var i := note.find("<pos=")
	if i < 0:
		return note
	var out := ""
	var last := 0
	while i >= 0:
		var e := note.find("\n", i)
		if e < 0:
			e = note.length()
		var line := note.substr(i, e - i)  # 不要求行首：原版有「<<pos=」的笔误行（Items:800），help_card 照样显示
		var u := _fix_pos_line(line)
		if u != line:
			out += note.substr(last, i - last) + u
			last = e
		i = note.find("<pos=", e)
	return note if last == 0 else out + note.substr(last)


static func _fix_pos_line(line: String) -> String:
	if _gate.search(line) == null and not (PAIRS and _pair_hint(line)):
		return line
	var m := _pos_re.search(line)
	if m == null:
		return line
	var t := m.get_string(2)
	var u := fix(t)
	return line if u == t else m.get_string(1) + u + m.get_string(3)


static func _fix_list(list) -> void:
	if not list is Array:
		return
	for c in list:
		if not c is Dictionary:
			continue
		var code := int(c.get("code", 0))
		var ps = c.get("parameters")
		if not ps is Array or ps.is_empty():
			continue
		if code == 401 or code == 405:
			if ps[0] is String and ps[0] != "":
				ps[0] = fix(ps[0], code == 401)
		elif code == 102 and ps[0] is Array:
			for j in ps[0].size():
				if ps[0][j] is String:
					ps[0][j] = fix(ps[0][j])


## 成对标点：只有一种引号且个数成双的，改成左右交替；括号按半全角一视同仁配对，能配平时把半全角混搭的一对改成全角
## 成对标点要不要细看：有引号字符，或半角、全角括号同时出现
static func _pair_hint(s: String) -> bool:
	if s.contains("‘") or s.contains("“") or s.contains("”"):
		return true
	return (s.contains("（") or s.contains("）")) and (s.contains("(") or s.contains(")"))


static func _pairs(s: String) -> String:
	if s.contains("‘") and not s.contains("’") and s.count("‘") % 2 == 0:
		s = _alternate(s, "‘", "’")
	if s.contains("”") and not s.contains("“") and s.count("”") % 2 == 0:
		s = _alternate(s, "”", "“", true)
	elif s.contains("“") and not s.contains("”") and s.count("“") % 2 == 0:
		s = _alternate(s, "“", "”")
	var half := s.contains("(") or s.contains(")")
	var full := s.contains("（") or s.contains("）")
	if half and full:
		s = _brackets(s)
	return s


static func _alternate(s: String, ch: String, other: String, first_other := false) -> String:
	var out := ""
	var k := 0
	for c in s:
		if c == ch:
			var use_other := (k % 2 == 1) != first_other
			out += other if use_other else ch
			k += 1
		else:
			out += c
	return out


static func _brackets(s: String) -> String:
	var stack := []
	var pairs := []
	for i in s.length():
		var c := s[i]
		if c == "(" or c == "（":
			stack.append(i)
		elif c == ")" or c == "）":
			if stack.is_empty():
				return s
			pairs.append([stack.pop_back(), i])
	if not stack.is_empty():
		return s
	var chars := []
	for c in s:
		chars.append(c)
	var changed := false
	for p in pairs:
		if (chars[p[0]] == "(") != (chars[p[1]] == ")"):
			chars[p[0]] = "（"
			chars[p[1]] = "）"
			changed = true
	return "".join(chars) if changed else s


# ---------- 逐条覆盖 ----------

static func _apply_override(e: Dictionary, data, table: String) -> void:
	var at := str(e.get("at", ""))
	var from := str(e.get("from", ""))
	var to := str(e.get("to", ""))
	var slots := _resolve(at, data, table)
	var total := 0
	for s in slots:
		var v = s[0][s[1]]
		if v is String:
			total += (v as String).count(from) if from != "" else 0
	var want := int(e.get("count", 0))
	if from == "" or total == 0 or (want > 0 and total != want):
		var why := "位置找不到" if slots.is_empty() else ("原文命中 %d 次，应为 %s" % [total, str(want) if want > 0 else "至少 1"])
		_warn("%s：%s（%s）" % [at, why, str(e.get("ref", ""))])
		return
	for s in slots:
		if s[0][s[1]] is String:
			s[0][s[1]] = (s[0][s[1]] as String).replace(from, to)


## 位置 → [[容器, 键], …]（字符串所在处）。表:编号/字段、CommonEvents:编号[/cmdN]、Troops:编号[/pK][/cmdN]、MapNNN:evE[/pK][/cmdN][/choiceJ]
static func _resolve(at: String, data, table: String) -> Array:
	var parts := at.get_slice(":", 1).split("/")
	if parts.is_empty():
		return []
	var head := parts[0]
	var rest := parts.slice(1)
	if table.begins_with("Map"):
		if not head.begins_with("ev") or not data is Dictionary:
			return []
		var eid := int(head.substr(2))
		var evs: Array = data.get("events", [])
		var ev = evs[eid] if eid > 0 and eid < evs.size() else null
		if not ev is Dictionary or int(ev.get("id", -1)) != eid:
			ev = null
			for x in evs:
				if x is Dictionary and int(x.get("id", -1)) == eid:
					ev = x
		return _resolve_pages(ev.get("pages", []), rest) if ev is Dictionary else []
	var id := int(head)
	if not data is Array or id <= 0 or id >= data.size() or not data[id] is Dictionary:
		return []
	var rec: Dictionary = data[id]
	if table == "CommonEvents":
		return _resolve_list(rec.get("list", []), rest)
	if table == "Troops" and (rest.is_empty() or rest[0].begins_with("p") or rest[0].begins_with("cmd")):
		return _resolve_pages(rec.get("pages", []), rest)
	if rest.size() == 1 and rec.get(rest[0]) is String:
		return [[rec, rest[0]]]
	return []


static func _resolve_pages(pages: Array, rest: Array) -> Array:
	var out := []
	if not rest.is_empty() and rest[0].begins_with("p"):
		var k := int(rest[0].substr(1))
		if k >= 0 and k < pages.size() and pages[k] is Dictionary:
			out = _resolve_list(pages[k].get("list", []), rest.slice(1))
		return out
	for p in pages:
		if p is Dictionary:
			out.append_array(_resolve_list(p.get("list", []), rest))
	return out


static func _resolve_list(list, rest: Array) -> Array:
	var out := []
	if not list is Array:
		return out
	var lo := 0
	var hi: int = list.size()
	if not rest.is_empty() and rest[0].begins_with("cmd"):
		lo = int(rest[0].substr(3))
		hi = lo + 1
		if lo < 0 or lo >= list.size():
			return out
	var choice := int(rest[1].substr(6)) if rest.size() > 1 and rest[1].begins_with("choice") else -1
	for i in range(lo, hi):
		var c = list[i]
		if not c is Dictionary or not c.get("parameters") is Array or c.parameters.is_empty():
			continue
		var code := int(c.get("code", 0))
		if (code == 401 or code == 405) and c.parameters[0] is String and choice < 0:
			out.append([c.parameters, 0])
		elif code == 102 and c.parameters[0] is Array:
			for j in c.parameters[0].size():
				if choice < 0 or choice == j:
					out.append([c.parameters[0], j])
	return out
