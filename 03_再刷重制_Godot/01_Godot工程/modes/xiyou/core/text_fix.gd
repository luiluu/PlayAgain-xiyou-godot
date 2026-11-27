class_name XTextFix
extends RefCounted
## 【cc·未经审查】原版文字错的加载时修正（乙类文字审 00_项目管理/核查/文字审查乙类_xa_text-audit-b.md，cc/text-fix-b）。
## XDB 读进数据库表、地图时就地改玩家看得到的字，不动 generated 产物；重制版与天启篇都生效。
##
## 改哪些字段：数据库 name／nickname／profile／description／message1～4、备注里 <pos=… text=… size=…> 的 text 段、
## 公共事件／敌群／地图事件的 401／405 对话行与 102 选项。备注的其余部分（notetag、动作序列、脚本）、伤害公式、插件参数都不碰。
##
## 天启篇词典 tianqi_dict（D126 去西游化）跟 DICT 开关，只在天启篇存档套用，换档清缓存（sync_mode）。
## tianqi_dict 里带 "note": true 的条目（T193 D202「天道*」→「启示·」）不进字段词典，只对整段备注按字面替换，
## 用来改 <StateNote>、<RightDownNote:"…"> 这类不在 <pos> 行里的说明；from 写带上下文的字面（如整个 RightDownNote 标签），不碰脚本。
## rules.json 的 tianqi_note_by_id（T199，T187 文案草稿）：按「表名→记录号→[[原文, 改成]]」只改那一条记录的备注，用来把归池增伤的旧乘数说明改成「伤害加成 +20%」；同样只在天启篇套用、跟 DICT 开关。
## 六个开关各一个 O 号（00_设计/优化登记.md），默认开；关掉后 clear_cache() 让表重读即回原版文字：
## - STRIP_ZW（O-489）：剥零宽控制符 U+FEFF、U+200B、U+200C。
## - NAMEBOX（O-490）：事件对话名字框——行首 <名字> 补前导 \n、/n< 写反改 \n<、\c\[ 双转义改 \c[、行首孤立 \n（后面不是 <、[、字母）删掉。
## - PAIRS（O-491）：成对标点——只有左单引号／只有右双引号的成对改回 ‘…’／“…”；括号能配平而半角全角混搭的一对改全角。
## - DICT（O-492）：词典替换（text_fix/rules.json 的 dict：挑符文、超级Boos、奥数→奥术、终级、枪决……）。
## - TRAD（O-493）：繁体异体字逐字转简体（rules.json 的 trad）。
## - OVERRIDES（O-494）：逐条覆盖表 text_fix/overrides.json（位置＋原文子串＋改成，原文对不上就不套用并报警）。
## 次序：先逐条覆盖（from 按原版原文写），再套统一规则。
## 代码里按名字认敌人档位的（XZhenqi.is_named_boss、XEncounterTarget）同时认「超级Boos」「超级Boss」与 D126 新前缀「霸主」（「远古首领」＝原【DOTABOSS】本来不按名认首领，照旧不认，与参照一致）。

static var STRIP_ZW := true
static var NAMEBOX := true
static var PAIRS := true
static var DICT := true
static var TRAD := true
static var OVERRIDES := true

const RULES_PATH := "res://modes/xiyou/text_fix/rules.json"
const OVERRIDES_PATH := "res://modes/xiyou/text_fix/overrides.json"
const ACTOR_NAMES_PATH := "res://modes/xiyou/tianqi_data/actor_names.json"
## 改了修正逻辑（不只是 rules／overrides 数据）就加 1，让旧的修正缓存作废（导出版脚本源码可能读不到，不能只靠源码哈希）
const CACHE_VER := 5
const TABLES := ["Actors", "Classes", "Skills", "Items", "Weapons", "Armors", "Enemies", "States", "Troops", "CommonEvents",
	"MapInfos", "EquipSuits", "Runewords"]
const TEXT_KEYS := ["name", "nickname", "profile", "description", "message1", "message2", "message3", "message4"]

## 覆盖表原文对不上的条目（「位置：原因」），测试与 07_开发环境/文字审 导出脚本读它
static var warnings: Array = []
static var _rules = null
static var _overrides = null  # {"Skills": [条目…], "Map004": […]}
static var _dict := []  # [[RegEx 或 null, from, to]]
## 只在天启篇存档套用的词典（rules.json 的 tianqi_dict，D126 去西游化；西游档 1:1 原貌）
static var _tq_dict := []
static var _tq_gate: RegEx
## tianqi_dict 里 "note": true 的条目：[[from, to]]，只在天启篇对整段备注字面替换（T193）
static var _tq_note := []
## rules.json 的 tianqi_note_by_id（T199）：{表名: {记录号字符串: [[原文, 改成]]}}，只对那一条记录的备注按字面替换，只在天启篇套用
static var _tq_by_id := {}
## 上一次读表／地图时用的是不是天启篇口径；和现在不一样就要清缓存（sync_mode）
static var _applied_tq := false
static var _gate: RegEx  # 零宽／繁体／词典任一命中的总预筛
static var _pos_re: RegEx
static var _namebox_re: RegEx
static var _lone_n_re: RegEx
static var _actor_names = null


## 测试用：一次开关全部（按原版比对时关掉），并清缓存让表重读
static func set_all(on: bool) -> void:
	STRIP_ZW = on
	NAMEBOX = on
	PAIRS = on
	DICT = on
	TRAD = on
	OVERRIDES = on
	clear_cache()


## 现在是不是天启篇存档（D126 去西游化词典 tianqi_dict 只在天启篇套用；西游档 1:1 原貌）
static func tq_on() -> bool:
	if _loading_tq != null:
		return bool(_loading_tq)
	return XState.current != null and XTianqi.active(XState.current)


## 读档期间（XState.from_dict 到 _become_current）按目标存档的档位取表：角色 setup 的默认称号等要取目标档的文字，
## 不能沿用上一档（T562 P1-1：天启档里读西游档会把天启称号带进西游档并在存档时写成显式称号）。
static var _loading_tq = null

static func begin_load(tq: bool) -> void:
	_loading_tq = tq
	sync_mode()


static func end_load() -> void:
	_loading_tq = null


## 存档模式（西游档／天启篇）变了就清缓存让表与地图按新口径重读。
## 换档（XState._become_current）、天启篇开局建档（XTianqi.start_new_game）时调；磁盘缓存的键里也编了模式位。
static func sync_mode() -> void:
	if tq_on() != _applied_tq:
		_applied_tq = tq_on()
		clear_cache()


static func any_on() -> bool:
	return STRIP_ZW or NAMEBOX or PAIRS or DICT or TRAD or OVERRIDES


## 清掉 XDB 里受影响的表与地图缓存，下次读按当前开关重新处理
static func clear_cache() -> void:
	for k in XDB._tables.keys():
		if str(k).begins_with("map:") or TABLES.has(k) or k in ["System", "Plugins"]:
			XDB._tables.erase(k)


static func actor_names() -> Dictionary:
	if _actor_names == null:
		var data = XDB.parse_file(ACTOR_NAMES_PATH) if FileAccess.file_exists(ACTOR_NAMES_PATH) else null
		_actor_names = data if data is Dictionary else {}
	return _actor_names


## 共用文案按当前存档取名。调用方提供西游档原文，发行空壳也可直接走原文。
static func actor_name(id: int, original: String) -> String:
	return str(actor_names().get("names", {}).get(str(id), original)) if tq_on() else original


## 按指定档位取角色名（T562 P2-1）：标题态的天启篇阵容、存档格预览等不在目标档里时用。
## current_text 是现在 Actors 表里的名字；表可能按任一档位口径读过（标题态、刚换档），所以不看 tq_on()，
## 两个方向都按 actor_names.json 直接换：要天启篇取 names，要西游档且现在是天启名就换回 saved_names 的原名。
static func actor_name_in(id: int, tq: bool, current_text: String) -> String:
	var nm = actor_names().get("names", {}).get(str(id))
	if nm == null:
		return current_text
	if tq:
		return str(nm)
	var orig: Array = actor_names().get("saved_names", {}).get(str(id), [])
	return str(orig[0]) if not orig.is_empty() and current_text == str(nm) else current_text


## 按指定档位取默认称号（同 actor_name_in，两向都幂等，不看 tq_on()）
static func actor_nickname_in(id: int, tq: bool, current_text: String) -> String:
	var pairs: Array = actor_names().get("tables", {}).get("Actors", {}).get("%d/nickname" % id, [])
	if tq:
		return rename_actor_reference(current_text, pairs)
	for pair in pairs:
		var to := tianqi_actor_text(pair[1])
		if current_text.contains(to):
			current_text = current_text.replace(to, pair[0])
	return current_text


## 角色记录按指定档位取名字（读 Actors 表后换口径）
static func actor_rec_name(id: int, tq: bool) -> String:
	return actor_name_in(id, tq, str(XDB.rec("Actors", id).get("name", "")))


## 天启篇旧装备实例的显示视图（T562 P2-3）：实例自带名字、说明、备注，登记时照抄的是原文模板。
## 按底号取 actor_names.json 的 Weapons／Armors 定向条目，实例里「改名后正好等于现在的模板行」的行才换（保留词缀、强化等实例自有字段）；
## 西游档或没有对应条目时原样返回 obj。
static func gear_actor_view(obj: Dictionary) -> Dictionary:
	var base_id := int(obj.get("base", 0))
	if base_id <= 0 or not tq_on():
		return obj
	var table := "Weapons" if str(obj.get("kind", "")) == "weapon" else "Armors" if str(obj.get("kind", "")) == "armor" else ""
	if table == "":
		return obj
	var entries: Dictionary = actor_names().get("tables", {}).get(table, {})
	var prefix := "%d/" % base_id
	var base := XDB.rec(table, base_id)
	if base.is_empty():
		return obj
	var out := obj
	for path in entries:
		if not str(path).begins_with(prefix):
			continue
		var parts: PackedStringArray = str(path).split("/")
		var field := parts[1]
		if not (obj.get(field) is String) or not (base.get(field) is String):
			continue
		var cur: String = out[field]
		var fixed := cur
		if parts.size() == 2:
			var renamed := rename_actor_reference(cur, entries[path])
			if renamed == str(base[field]):
				fixed = renamed
		elif parts.size() == 3 and parts[2].is_valid_int():
			var want: PackedStringArray = str(base[field]).split("\n")
			var line := int(parts[2])
			if line >= want.size():
				continue
			var lines: PackedStringArray = cur.split("\n")
			for i in lines.size():
				if lines[i] != want[line] and rename_actor_reference(lines[i], entries[path]) == want[line]:
					lines[i] = want[line]
			fixed = "\n".join(lines)
		if fixed != cur:
			if out == obj:
				out = obj.duplicate()
			out[field] = fixed
	return out


## 仅用于明确写入「{角色号}」的天启篇文案。
static func tianqi_actor_text(text: String) -> String:
	return text.format(actor_names().get("names", {})) if text.contains("{") else text


## 旧天启档可能用事件 320 存过原名。只在显示时处理已登记的原文，保留自定义名字与原存档值。
static func saved_actor_name(id: int, text: String) -> String:
	if tq_on() and actor_names().get("saved_names", {}).get(str(id), []).has(text):
		return actor_name(id, text)
	return text


## 称号显示（T562 R3）：只在天启篇、且整串正好是登记过的西游原称号时换成天启篇称号（事件 324 按原文设的、旧天启档存的）；
## 含原名的自订长称号（如「裴钱的旧友」）是玩家／事件写的，原样显示。只换显示，不改存值。
static func actor_nickname(id: int, text: String) -> String:
	if not tq_on():
		return text
	var fields: Dictionary = actor_names().get("tables", {}).get("Actors", {})
	for pair in fields.get("%d/nickname" % id, []):
		if text == str(pair[0]):
			return tianqi_actor_text(pair[1])
	return saved_actor_name(id, text)


static func rename_actor_reference(text: String, pairs: Array) -> String:
	for pair in pairs:
		if text.contains(pair[0]):
			text = text.replace(pair[0], tianqi_actor_text(pair[1]))
	return text


## 天启篇定向覆盖。路径从记录号或事件下标开始，末级数字可取备注中的一行。
static func patch_actor_names(table: String, data) -> void:
	if not tq_on():
		return
	var entries: Dictionary = actor_names().get("tables", {}).get(table, {})
	for path in entries:
		var parts: PackedStringArray = path.split("/")
		var parent = data
		var key: Variant
		for depth in parts.size():
			var part := parts[depth]
			if parent is Array:
				key = int(part)
				if key >= parent.size():
					break
			elif parent is Dictionary and parent.has(part):
				key = part
			else:
				break
			var value = parent[key]
			if value is String:
				var last := parts.size() - 1
				if depth == last:
					parent[key] = rename_actor_reference(value, entries[path])
				elif depth + 1 == last and parts[last].is_valid_int():
					var lines: PackedStringArray = value.split("\n")
					var line := int(parts[last])
					if line < lines.size():
						lines[line] = rename_actor_reference(lines[line], entries[path])
						parent[key] = "\n".join(lines)
				break
			parent = value


static func patch_actor_advance(plugins: Dictionary) -> void:
	if not tq_on():
		return
	var rows: Dictionary = actor_names().get("advance", {})
	var advance: Dictionary = plugins.get("Star_ActorAdvanced", {})
	for id in rows:
		var key := "Advanced " + str(id)
		var row = JSON.parse_string(str(advance.get(key, "null")))
		if row is Dictionary and row.get("AdvancedName") is String:
			row.AdvancedName = rename_actor_reference(row.AdvancedName, rows[id])
			advance[key] = JSON.stringify(row)


static func rules() -> Dictionary:
	if _rules == null:
		var d = XDB.parse_file(RULES_PATH) if FileAccess.file_exists(RULES_PATH) else null
		_rules = d if d is Dictionary else {}
		_dict = []
		var gate := []
		for k in _rules.get("trad", {}):
			gate.append(_escape(str(k)))
		_dict = _build_dict(_rules.get("dict", []), gate)
		gate.append("\ufeff")
		gate.append("\u200b")
		gate.append("\u200c")
		_gate = RegEx.create_from_string("|".join(gate))
		var tq_gate := []
		var tq_fields := []
		_tq_note = []
		for e in _rules.get("tianqi_dict", []):
			if bool(e.get("note", false)):
				if str(e.get("from", "")) != "":
					_tq_note.append([str(e.get("from", "")), str(e.get("to", ""))])
			else:
				tq_fields.append(e)
		_tq_by_id = {}
		var by_id = _rules.get("tianqi_note_by_id", {})
		if by_id is Dictionary:
			for tab in by_id:
				if not str(tab).begins_with("_") and by_id[tab] is Dictionary:
					_tq_by_id[str(tab)] = by_id[tab]
		_tq_dict = _build_dict(tq_fields, tq_gate)
		_tq_gate = RegEx.create_from_string("|".join(tq_gate)) if not tq_gate.is_empty() else null
		_pos_re = RegEx.create_from_string("^(<pos=\\S+\\s+text=)([\\s\\S]*?)(\\s+size=[\\s\\S]*)$")
		_namebox_re = RegEx.create_from_string("^<([^<>\\\\:]{1,20})>")
		_lone_n_re = RegEx.create_from_string("^\\\\n(?=[^<\\[A-Za-z])")
	return _rules


## rules.json 的词典条目 → [[RegEx 或 null, from, to]]，预筛字面文字追加进 gate
static func _build_dict(entries: Array, gate: Array) -> Array:
	var out := []
	for e in entries:
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
		out.append([re, from, str(e.get("to", ""))])
	return out


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
	_applied_tq = tq_on()
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
		for p in [RULES_PATH, OVERRIDES_PATH, ACTOR_NAMES_PATH, "res://modes/xiyou/core/text_fix.gd"]:
			h.update(FileAccess.get_file_as_bytes(p))
		_sig_files = h.finish().hex_encode().substr(0, 16)
	return "%d%d%d%d%d%d%d.%s" % [int(STRIP_ZW), int(NAMEBOX), int(PAIRS), int(DICT), int(TRAD), int(OVERRIDES), int(tq_on()), _sig_files]


static func _warn(msg: String) -> void:
	if not warnings.has(msg):
		warnings.append(msg)
		push_warning("XTextFix 覆盖表没套用 " + msg)


static func patch_table(name: String, data) -> void:
	if not TABLES.has(name) or not data is Array:
		return
	if OVERRIDES:
		for e in overrides().get(name, []):
			_apply_override(e, data, name)
	patch_actor_names(name, data)
	if not (STRIP_ZW or NAMEBOX or PAIRS or DICT or TRAD):
		return
	rules()
	var tq_on_now := DICT and tq_on()
	var tq_note := tq_on_now and not _tq_note.is_empty()
	var by_id: Dictionary = _tq_by_id.get(name, {}) if tq_on_now else {}
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
		if tq_note and r.get("note") is String:
			r["note"] = _fix_tq_note(r["note"])
		if not by_id.is_empty() and r.get("note") is String and by_id.has(str(int(r.get("id", 0)))):
			r["note"] = _fix_tq_by_id(r["note"], by_id[str(int(r.get("id", 0)))])
		match name:
			"CommonEvents":
				_fix_list(r.get("list"))
			"Troops":
				for p in r.get("pages", []):
					if p is Dictionary:
						_fix_list(p.get("list"))


static func patch_map(map_id: int, data) -> void:
	if not data is Dictionary:
		return
	_applied_tq = tq_on()
	var table := "Map%03d" % map_id
	if OVERRIDES:
		for e in overrides().get(table, []):
			_apply_override(e, data, table)
	patch_actor_names(table, data)
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
	if DICT and _tq_gate != null and tq_on() and _tq_gate.search(s) != null:
		for d in _tq_dict:
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


## 天启篇备注字面替换（tianqi_dict 的 "note": true 条目；调用方已判 DICT 与天启篇）
static func _fix_tq_note(note: String) -> String:
	for d in _tq_note:
		if note.contains(d[0]):
			note = note.replace(d[0], d[1])
	return note


## 天启篇按记录号的备注字面替换（tianqi_note_by_id；调用方已判 DICT 与天启篇）
static func _fix_tq_by_id(note: String, pairs: Array) -> String:
	for d in pairs:
		if d is Array and d.size() >= 2 and note.contains(str(d[0])):
			note = note.replace(str(d[0]), str(d[1]))
	return note


static func _fix_pos_line(line: String) -> String:
	var tq_hit := DICT and _tq_gate != null and tq_on() and _tq_gate.search(line) != null  # 天启篇词典单独命中也要改（T193：5568「免疫天道·封魔」行不含统一规则的字）
	if not tq_hit and _gate.search(line) == null and not (PAIRS and _pair_hint(line)):
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
