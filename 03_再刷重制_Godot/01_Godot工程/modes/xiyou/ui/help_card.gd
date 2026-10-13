class_name XHelpCard
extends Control
## 物品/装备/技能说明卡，照正式版 HelpExtend（Sprite_ItemHelp）＋ItemQuality＋Codex 运行模块复现，
## 并按用户方向「根据原版说明卡去优化」做了可回退的优化（优化登记 O-007、O-008）。
##
## 内容（content()，与 tests/xiyou_help_card 对 generated/oracle/help_cards.json 逐行核对）：
## 1. HelpExtend getDescParams：名字（20 号、品质色、居中）、描述（10 号、品质色）；物品「消耗品」、
##    装备 8 项能力（12 号、各自颜色，最后一项后分隔）、技能 MP/TP 消耗（12 号）；买卖价格（12 号、黄）。
## 2. 备注 <pos=位置 text=… size=… color=… line=… align=…> 逐条插入（位置 AN/AD/AP/APs/AC；同位置后插的在前）；
##    ItemQuality 在描述后插「品质：名称」（18 号、品质色）。CodexDisplay.text：全伤→全属性伤害。
## 3. installDamageElementRuntime（setItem 外层）：装备文字的元素别名（阴阳/奥数/暗黑），去掉备注里的「伤害属性」行，
##    在名字后插入：技能「伤害属性：元素」（伤害类型 1/2/5/6）、装备的元素增伤/追加/承伤/减伤穿透与「攻击属性」（14 号）。
## 4. installDisplayPreferencesRuntime genericHelpView（普通技能）：改名合并（对象→目标、命中类型＋能否暴击 → 命中；暴击、
##    MP/TP 消耗 → 消耗：nTP），分成 抬头／公式（\c[5]）／基本信息（\c[0]，按 伤害属性→目标→…排序）／效果（\c[1]）／
##    成长（\c[3]）／价格 六组，组间分隔；正文统一为最常见字号。
## 未做：installCombatPowerRuntime 的「装备战力」行（依赖战力估算，随主菜单「战力」一起做）；特殊角色（ID 10122～10299）
##    与心钢、狂妄等专属装备的动态说明（切片里没有）。
##
## 版面（layout()）：宽 400、内边距 4；每行按 RJO.SW 逐字排版：可用宽 392−x，放不下换行；行高 = 该行最大字号 + 8；
## 居中/靠右的行只算第一行；有分隔的行之后加 3；卡高 = 8 + Σ行高 + 3×分隔数。\i[n] 占 36、画在 (x+2, y−3)；
## \{ \} 字号 ±6；\C[2000+e] 为元素颜色。
## 外观：四层品质窗口（Window{品质}.png，不透明度 60）套在卡外 10px，卡内实心 #161c25（Codex 覆盖）。

const WIDTH := 400.0
const PAD := 4.0
const SEP := 3.0
const NAME_SIZE := 20
const DESC_SIZE := 10
const OTHER_SIZE := 12
const CONSUMABLE_COLOR := "rgba(255,128,128,1)"
const PRICE_COLOR := "rgba(255,255,0,1)"
const MP_COLOR := "rgba(128,128,255,1)"
const TP_COLOR := "rgba(128,255,128,1)"
const PARAM_COLORS := ["rgba(255,128,128,1)", "rgba(76,76,255,1)", "rgba(255,76,76,1)", "rgba(128,128,128,1)",
	"rgba(255,76,255,1)", "rgba(76,255,255,1)", "rgba(128,255,128,1)", "rgba(255,255,128,1)"]
const VIEW_COLOR := "rgba(235,240,247,1)"
const ELEMENT_ROW_COLOR := "rgba(170,215,245,1)"
const ELEMENT_COLORS := ["#c1c9d5", "#d5dce6", "#ff846b", "#9be4ff", "#d8ac74", "#f7db62", "#83d784", "#a99bff",
	"#fff0b0", "#bd8bc9", "#6fe4c0", "#b59cf0", "#f497c8", "#7eb8ff", "#65ccef", "#bce986"]
const BACK := Color8(0x16, 0x1c, 0x25)
## 优化 O-007：说明卡最小字号（原版描述 10、能力/价格 12、元素行 14，在 1280×720 上难以看清）。设 0 恢复原版。
const MIN_FONT := 16

var rows: Array = []          # content() 的结果
var quality := 0
var min_font := MIN_FONT
var _lines: Array = []        # layout() 的结果：[{glyphs, y, h, line}]
var canvas: XMVCanvas
var frame: Control


# ======================================================================
# 内容
# ======================================================================

## obj：数据库条目或装备实例；kind：item / weapon / armor / skill（省略时自动判断）
static func content(obj: Dictionary, kind := "") -> Array:
	if obj.is_empty():
		return []
	if kind == "":
		kind = kind_of(obj)
	var type := {"item": 0, "weapon": 1, "armor": 2, "skill": 3}.get(kind, 0)
	var rows := desc_params(obj, type)
	rows = _element_wrapper(obj, type, rows)
	if type == 3 and not _special_target(obj):
		rows = _generic_view(obj, rows)
	for r in rows:
		r[0] = _terms(str(r[0]))
	return rows


static func kind_of(obj: Dictionary) -> String:
	if obj.has("kind"):
		return str(obj.kind)
	if obj.has("stypeId"):
		return "skill"
	if obj.has("wtypeId"):
		return "weapon"
	if obj.has("atypeId"):
		return "armor"
	return "item"


static func _quality(obj: Dictionary) -> int:
	var q = obj.get("meta", {}).get("quality", 0)
	return int(str(q).strip_edges()) if str(q).strip_edges().is_valid_int() else 0


static func quality_color_text(obj: Dictionary) -> String:
	var list := _list_param(str(XDB.plugin("ItemQuality").get("QualitiesColor", "")))
	var q := _quality(obj)
	return list[q] if q < list.size() else "rgba(255,255,255,1)"


static func quality_name(obj: Dictionary) -> String:
	var raw = JSON.parse_string(str(XDB.plugin("ItemQuality").get("QualitiesName", "[]")))
	var q := _quality(obj)
	return str(raw[q]) if raw is Array and q < raw.size() else ""


## "['a','b']" 形式的参数（JS 数组字面量，单引号）
static func _list_param(text: String) -> Array:
	var out := []
	var re := RegEx.create_from_string("'([^']*)'")
	for m in re.search_all(text):
		out.append(m.get_string(1))
	return out


static func _num(v) -> String:
	var f := float(v)
	if is_equal_approx(f, roundf(f)):
		return str(int(roundf(f)))
	return str(f)


## RJO.HE.getDescParams（＋ItemQuality 品质行、备注插入行）
static func desc_params(obj: Dictionary, type: int) -> Array:
	var normal := quality_color_text(obj)
	var name := str(obj.get("name", ""))
	var desc := str(obj.get("description", ""))
	var rows := []
	var pos := [1, 2, 2, 2, 2]
	rows.append([name, NAME_SIZE, normal, name != "", 1])
	rows.append([desc, DESC_SIZE, normal, desc != "", null])
	var terms: Dictionary = XDB.system().get("terms", {})
	match type:
		0:
			if bool(obj.get("consumable", false)):
				rows.append(["消耗品", OTHER_SIZE, CONSUMABLE_COLOR, false, null])
			_prices(obj, rows)
			pos[2] = rows.size()
		1, 2:
			var params: Array = obj.get("params", [])
			for i in range(params.size()):
				if params[i] != null and float(params[i]) != 0.0:
					rows.append([str(terms.get("params", [])[i]) + ":" + _num(params[i]), OTHER_SIZE, PARAM_COLORS[i], false, null])
			rows[rows.size() - 1][3] = true
			pos[3] = rows.size()
			_prices(obj, rows)
			pos[2] = rows.size()
		3:
			var basic: Array = terms.get("basic", [])
			if int(obj.get("mpCost", 0)) > 0:
				rows.append([str(basic[4]) + "消耗：" + str(int(obj.mpCost)), OTHER_SIZE, MP_COLOR, false, null])
			if int(obj.get("tpCost", 0)) > 0:
				rows.append([str(basic[6]) + "消耗：" + str(int(obj.tpCost)), OTHER_SIZE, TP_COLOR, false, null])
			pos[4] = rows.size()
	for line in str(obj.get("note", "")).split("\n"):
		_extra_row(rows, pos, line.strip_edges(false, true), normal)
	# ItemQuality：<pos=AD text=品质：名称 size=18 color=normalcolor line=false align=0>
	_extra_row(rows, pos, "<pos=AD text=品质：%s size=18 color=normalcolor line=false align=0>" % quality_name(obj), normal)
	for r in rows:
		r[0] = _terms(str(r[0]))
	return rows


static func _prices(obj: Dictionary, rows: Array) -> void:
	var price := float(obj.get("price", 0))
	if price > 0:
		rows.append(["购买价格：" + str(int(roundf(price))), OTHER_SIZE, PRICE_COLOR, false, null])
		rows.append(["出售价格：" + str(int(roundf(price / 2.0))), OTHER_SIZE, PRICE_COLOR, false, null])
	else:
		rows.append(["无法出售给普通商店", OTHER_SIZE, PRICE_COLOR, false, null])


static var _pos_re: RegEx

## RJO.HE.processExtraDescParams：插在当时的位置（位置数组不随插入更新，所以同位置后插的在前）
static func _extra_row(rows: Array, pos: Array, line: String, normal: String) -> void:
	if _pos_re == null:
		_pos_re = RegEx.create_from_string("(?i)<pos=(.+) text=(.+) size=(.+) color=(.+) line=(true|false) align=(0|1|2)>")
	var m := _pos_re.search(line)
	if m == null:
		return
	var text := m.get_string(2)
	if text.contains("DreamX_bonus"):
		return
	var p := m.get_string(1)
	var at := {"AN": pos[0], "AD": pos[1], "AP": pos[2], "APs": pos[3], "AC": pos[4]}.get(p, -1)
	if at == -1:
		at = int(p) if p.is_valid_int() else 0
	var size := m.get_string(3)
	var color := m.get_string(4)
	var row := [text, OTHER_SIZE if size == "normalsize" else int(float(size)), normal if color == "normalcolor" else color,
		m.get_string(5).to_lower() == "true", int(m.get_string(6))]
	rows.insert(clampi(at, 0, rows.size()), row)


## CodexDisplay.text
static func _terms(text: String) -> String:
	return RegEx.create_from_string("全伤(?:害)?").sub(text, "全属性伤害", true)


static func _special_target(obj: Dictionary) -> bool:
	var id := int(obj.get("id", 0))
	return id >= 10122 and id <= 10299


# ---- installDamageElementRuntime ----
static func _element_data() -> Dictionary:
	var d = XDB.load_json("db/CodexDamageElements.json")
	return d if d is Dictionary else {}


static func element_name(e: int) -> String:
	var names: Array = _element_data().get("names", [])
	return str(names[e]) if e >= 0 and e < names.size() and str(names[e]) != "" else "无属性"


static func rich(ids: Array) -> String:
	if ids.is_empty():
		return "无属性"
	return "／".join(ids.map(func(e): return "\\C[%d]%s\\C[0]" % [2000 + int(e), element_name(int(e))]))


## 装备文字的元素别名（阴阳→虚空、奥数→奥术、暗黑→黑暗），只在作为元素用时替换（照 gearText）
static func gear_text(text: String) -> String:
	var aliases := {"阴阳": "虚空", "奥数": "奥术", "暗黑": "黑暗"}
	var tail := RegEx.create_from_string("^(?:\\s|[、，,／/·（(]|物理|火焰|寒冰|冰|火|大地|雷电|雷|自然|奥术|奥数|神圣|黑暗|暗黑|阴阳|虚空|混沌|空间|水|风)*(?:伤害|伤|增伤|抗性|穿透|承伤|属性)")
	var direct := RegEx.create_from_string("^(?:伤害|伤|增伤|抗性|穿透|承伤|属性)")
	var before_sep := RegEx.create_from_string("[\\s、，,／/·（(：:]$")
	var attr_before := RegEx.create_from_string("(?:伤害属性|攻击属性|元素)\\s*[:：][^:：\\n]*$")
	var attr_after := RegEx.create_from_string("^(?:$|[\\s、，,／/·）)])")
	var out := ""
	var i := 0
	while i < text.length():
		var hit := ""
		for k in aliases:
			if text.substr(i, k.length()) == k:
				hit = k
				break
		if hit == "":
			out += text[i]
			i += 1
			continue
		var before := text.substr(0, i)
		var after := text.substr(i + hit.length())
		var ok := direct.search(after) != null
		ok = ok or ((i == 0 or before_sep.search(before) != null) and tail.search(after) != null)
		ok = ok or (attr_before.search(before) != null and attr_after.search(after) != null)
		out += aliases[hit] if ok else hit
		i += hit.length()
	return out


static func _element_wrapper(obj: Dictionary, type: int, rows: Array) -> Array:
	if type == 1 or type == 2:
		for r in rows:
			r[0] = _terms(gear_text(str(r[0])))
	var dmg_attr := RegEx.create_from_string("(?i)^(?:\\\\c\\[\\d+\\])?伤害属性\\s*[:：]")
	rows = rows.filter(func(r): return dmg_attr.search(str(r[0])) == null)
	var lines := []
	var data := _element_data()
	var active: Array = data.get("activeElements", [])
	if type == 3:
		var d: Dictionary = obj.get("damage", {})
		if [1, 2, 5, 6].has(int(d.get("type", 0))):
			var eid := _migrated_element(obj)
			var es := [eid]
			es.append_array(obj.get("yep", {}).get("multipleElements", []))
			es = es.map(func(e): return int(e)).filter(func(e): return e > 0)
			var uniq := []
			for e in es:
				if not uniq.has(e):
					uniq.append(e)
			var text := "伤害属性：" + (rich(uniq) if not uniq.is_empty() else ("随武器属性" if eid < 0 else "无属性"))
			if es.size() > 1:
				text += "（均分伤害）"
			lines.append(text)
	var trig = obj.get("meta", {}).get("CodexTriggeredElement")
	if trig != null:
		lines.append("触发攻击属性：" + rich([int(str(trig).strip_edges())]) + "（真实伤害）")
	if type == 1 or type == 2:
		var yep: Dictionary = obj.get("yep", {})
		_group(lines, active, _int_keys(yep.get("elementAmplify", {})), "增伤", _percent, 0.0)
		_group(lines, active, _int_keys(_note_rates(str(obj.get("note", "")), "Element Magnify")), "增伤", _percent, 0.0)
		_group(lines, active, _int_keys(yep.get("elementAmplifyN", {})), "追加", _num, 0.0)
		var resist := {}
		for t in obj.get("traits", []):
			if int(t.code) == 11 and active.has(int(t.dataId)):
				var e := int(t.dataId)
				if resist.get(e, -1.0) == 0.0:
					continue
				resist[e] = 0.0 if float(t.value) == 0.0 else float(resist.get(e, 1.0)) + float(t.value) - 1.0
		_group(lines, active, resist, "承伤", _percent, 1.0)
		var pierce := {}
		for m in RegEx.create_from_string("(?i)<DepassiveHarmRe(\\d+)\\s*:\\s*([^>]+)>").search_all(str(obj.get("note", ""))):
			if active.has(int(m.get_string(1))):
				pierce[int(m.get_string(1))] = m.get_string(2)
		_group(lines, active, pierce, "减伤穿透", func(v): return str(v), 0.0)
		var attack := []
		for t in obj.get("traits", []):
			if int(t.code) == 31 and not attack.has(int(t.dataId)):
				attack.append(int(t.dataId))
		if not attack.is_empty():
			lines.append("攻击属性：" + rich(attack))
	for i in range(lines.size() - 1, -1, -1):
		rows.insert(1, [lines[i], 14, ELEMENT_ROW_COLOR, false, 0])
	return rows


static func _migrated_element(skill: Dictionary) -> int:
	var eid := int(skill.get("damage", {}).get("elementId", 0))
	for m in _element_data().get("elementMigrations", []):
		if int(m.get("id", 0)) == int(skill.get("id", 0)) and int(m.get("from", -99)) == eid:
			return int(m.to)
	return eid


static func _int_keys(d) -> Dictionary:
	var out := {}
	if d is Dictionary:
		for k in d:
			out[int(k)] = d[k]
	return out


static func _note_rates(note: String, tag: String) -> Dictionary:
	var out := {}
	for m in RegEx.create_from_string("(?i)<" + tag + " (\\d+):\\s*([+-]?[\\d.]+)%\\s*>").search_all(note):
		out[int(m.get_string(1))] = float(out.get(int(m.get_string(1)), 0.0)) + float(m.get_string(2)) / 100.0
	return out


static func _percent(v) -> String:
	return _num(roundf(float(v) * 10000.0) / 100.0) + "%"


static func _group(lines: Array, active: Array, values: Dictionary, label: String, fmt: Callable, neutral) -> void:
	var es := active.filter(func(e): return values.has(int(e)) and values[int(e)] != null and str(values[int(e)]) != str(neutral) and not (values[int(e)] is float and is_equal_approx(float(values[int(e)]), float(neutral))))
	if es.is_empty():
		return
	if es.size() == active.size() and es.all(func(e): return str(values[int(e)]) == str(values[int(es[0])])):
		lines.append("全部元素" + label + " " + fmt.call(values[int(es[0])]))
		return
	var i := 0
	while i < es.size():
		var chunk := es.slice(i, i + 3)
		lines.append(" · ".join(chunk.map(func(e): return rich([int(e)]) + label + " " + fmt.call(values[int(e)]))))
		i += 3


# ---- genericHelpView ----
static func plain(text: String) -> String:
	return RegEx.create_from_string("(?i)(?:\\\\|\u001b)c\\[\\d+\\]").sub(text, "", true)


static func _compact(text: String) -> String:
	var t := plain(text)
	var reps := [["^([^:：]{1,18}):", "$1："], ["^命中类型：", "命中："], ["^能否暴击：是$", "暴击：可"], ["^能否暴击：否$", "暴击：不可"],
		["^(?:攻击次数|实际段数)：", "段数："], ["^特效：", "效果："], ["^(?:熟练成长|技能熟练|成长规则|成长说明|节点)[：:]", "成长："],
		["^伤害受技能等级加成。$", "成长：伤害随技能等级提高"], ["^目标：(?:单个敌人|单体敌人|敌人单体)$", "目标：敌方单体"],
		["^目标：(?:所有敌人|全体敌人|敌人全体)$", "目标：敌方全体"], ["^能否暴击：能$", "暴击：可"], ["^能否暴击：不能$", "暴击：不可"],
		["^等级成长[：:]", "成长："], ["；实际消耗以技能列表为准", ""], ["；无(?:MP、TP|魔法、TP)消耗", ""],
		["^生效条件：(.+?)(?:且|、)已(?:学会|习得)本被动$", "生效条件：$1"]]
	for r in reps:
		t = RegEx.create_from_string(r[0]).sub(t, r[1], true)
	return t


static func _re(p: String, t: String) -> bool:
	return RegEx.create_from_string(p).search(t) != null


static func _is_info(t: String) -> bool:
	return _re("^(?:类型|元素|武器限制|专属|(?:生效|完成|制作|双重集真赤)?条件|装备限制|使用限制|限制|(?:(?:基础)?(?:MP|TP)?)?消耗|代价|制作材料|材料|目标|伤害类型|伤害属性|命中(?:类型)?|能否暴击|暴击|攻击次数|实际段数|段数|冷却(?:时间)?|准备时间|可用场合|使用方式|施放前|时点|来源|当前等级|当前经验|法宝经验|等级需求|等级上限|法宝形态|咒具熟练|进阶继承|储存上限)[：:]", t) or _re("^(?:当前咒具|切换至此咒具)", t)


static func _is_growth(t: String) -> bool:
	return _re("^(?:成长|熟练成长|技能熟练|每级|法宝每级|星魂预览|节点|升级)", t) or _re("(?:随等级|按等级|每级|平滑|线性|成长|熟练度提高|实际成长上限)", t)


static func _is_formula(t: String) -> bool:
	return _re("^(?:基础治疗|基础护盾|伤害|真实伤害|斩击|体术|自动斩击|每段(?:基础)?|基础伤害|基式|有效魔攻|有效双防|蓄势附加伤害|阶位系数|魄倍率|冠冕倍率|形态系数|防御系数|速度加成|倍率|术式威力|生命增量|魔攻增量)[：:=＝]", t) or _re("^[＋+×－−-]", t)


static func _generic_view(obj: Dictionary, rows: Array) -> Array:
	var header := []
	var formula := []
	var info := []
	var effects := []
	var growth := []
	var footer := []
	var element_rows := []
	var seen := {}
	var name := str(obj.get("name", ""))
	var desc := str(obj.get("description", ""))
	var unlock := RegEx.create_from_string("^(?:人物等级解锁|解锁等级|解锁(?:条件)?)[：:]\\s*(?:[\\x{4e00}-\\x{9fff}]{0,4})?\\d+级?\\s*$")
	for row in rows:
		var raw := str(row[0])
		var p := plain(raw)
		if p.strip_edges() == "":
			continue
		if raw == name or raw == desc or _re("^品质[：:]", p) or _re("^(?:战技|魔法|被动|呼吸法|其他|功法|鬼灭呼吸法)$", p):
			header.append(row)
			continue
		if _re("^(?:购买价格|出售价格|无法出售)", p):
			footer.append(row)
			continue
		if _re("^(?:伤害属性|攻击属性|触发攻击属性)[：:]", p):
			var er: Array = row.duplicate()
			er[0] = "\\c[0]" + RegEx.create_from_string("(?i)^(?:\\\\c\\[\\d+\\])+").sub(raw, "")
			er[2] = VIEW_COLOR
			er[3] = false
			er[4] = 0
			element_rows.append(er)
			continue
		var t := RegEx.create_from_string("^对象[：:]").sub(p, "目标：")
		t = RegEx.create_from_string("^(MP|TP)消耗[：:]\\s*(\\d+)\\s*$").sub(t, "消耗：$2$1")
		t = _compact(t)
		t = RegEx.create_from_string("^冷却时间：").sub(t, "冷却：")
		t = RegEx.create_from_string("^特性：").sub(t, "效果：")
		t = RegEx.create_from_string("[-－]\\s*\\[敌·(?:物抗|魔抗|物防|魔防)\\s*[*×]\\s*[\\d.]+\\](?:\\s*[*×]\\s*\\[[^\\]]*\\])*").sub(t, "", true)
		t = RegEx.create_from_string("[-－]\\s*敌·(?:物抗|魔抗|物防|魔防)(?:\\s*[*×]\\s*[\\d.]+)?").sub(t, "", true)
		t = RegEx.create_from_string("\\(\\s*\\)").sub(t, "", true)
		if unlock.search(t) != null or _re("^(?:装备限制|冷却)[：:]无$", t) or seen.has(t):
			continue
		seen[t] = true
		var s: Array = row.duplicate()
		s[2] = VIEW_COLOR
		s[3] = false
		s[4] = 0
		if _is_info(t):
			s[0] = "\\c[0]" + RegEx.create_from_string("([\\x{4e00}-\\x{9fff}])[:]").sub(t, "$1：", true)
			info.append(s)
		elif _is_formula(t):
			s[0] = "\\c[5]" + t
			formula.append(s)
		elif _is_growth(t):
			s[0] = "\\c[3]" + t
			growth.append(s)
		else:
			s[0] = "\\c[1]" + t
			effects.append(s)
	var priority := ["伤害属性", "目标", "伤害类型", "命中", "暴击", "段数", "冷却", "准备时间"]
	var basic := []
	var other := []
	for row in element_rows + info:
		var label := plain(str(row[0])).split("：")[0]
		var rank := priority.find(label)
		if rank < 0:
			other.append(row)
		else:
			basic.append([rank, basic.size(), row])
	basic.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	info = basic.map(func(x): return x[2]) + other
	var body := formula + info + effects + growth
	var sizes := {}
	var order := []
	for r in body:
		if not sizes.has(r[1]):
			order.append(r[1])
		sizes[r[1]] = int(sizes.get(r[1], 0)) + 1
	if not order.is_empty():
		var common = order[0]
		for k in order:
			if sizes[k] > sizes[common] or (sizes[k] == sizes[common] and _js_key_before(k, common)):
				common = k
		for r in body:
			r[1] = common
	var compact := []
	for row in info:
		var last = compact.back() if not compact.is_empty() else null
		var left := plain(str(last[0])) if last != null else ""
		var right := plain(str(row[0]))
		var pair := last != null and ((_re("^命中[：:]", left) and _re("^暴击[：:]", right)) or (_re("^(?:暴击|段数)[：:]", left) and _re("^(?:段数|冷却)[：:]", right)))
		if pair and left.length() + right.length() <= 28 and last[1] == row[1]:
			last[0] = str(last[0]) + "；" + RegEx.create_from_string("^\\\\c\\[0\\]").sub(str(row[0]), "")
		else:
			compact.append(row.duplicate())
	info = compact
	var groups := [header, formula, info, effects, growth, footer].filter(func(g): return not g.is_empty())
	for i in range(groups.size() - 1):
		var g: Array = groups[i]
		var last: Array = g.back().duplicate()
		last[3] = true
		g[g.size() - 1] = last
	var out := []
	for g in groups:
		out.append_array(g)
	return out


## JS Object.keys 对整数键按数值升序；sort 不稳定时的并列按此顺序（近似 V8 稳定排序的结果）
static func _js_key_before(a, b) -> bool:
	return int(a) < int(b)


# ======================================================================
# 版面
# ======================================================================

## 按 RJO.SW 排版，返回 {height, lines:[{glyphs, y, h, line}]}；min_size>0 时把小字号提到该值（优化 O-007）。
static func layout(rows: Array, min_size := 0, width := WIDTH) -> Dictionary:
	var font := XUI.font()
	var cw := width - PAD * 2
	var y := PAD
	var height := PAD * 2
	var lines := []
	for r in rows:
		var size := maxi(int(r[1]), min_size)
		var align := int(r[4]) if r[4] != null else 0
		var color := _css(str(r[2]))
		var text := _escapes(str(r[0]))
		var glyphs := []
		var heights := []
		var x := PAD
		var line_y := y
		var cur := size
		var line_max := size
		var i := 0
		if align != 0:
			# 居中/靠右：整行一次画（RJO.SW.drawText，行高 36）
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var gx := PAD + ((cw - w) / 2.0 if align == 1 else cw - w)
			glyphs.append({"t": text, "x": gx, "y": y, "size": size, "color": color, "lh": 36.0, "w": w})
			var th := float(_first_line_height(text, size))
			lines.append({"glyphs": glyphs, "y": y, "h": th, "line": bool(r[3])})
			y += th
			height += th
			if bool(r[3]):
				y += SEP
				height += SEP
			continue
		var line_h := float(_first_line_height(text, size))
		while i < text.length():
			var c := text[i]
			if c == "\n":
				heights.append(line_max + 8)
				x = PAD
				line_y += line_h
				# RJO.SW.processNewLine：此时位置还在换行符上，算出的行高就是当前字号 + 8
				line_h = cur + 8.0
				line_max = cur
				i += 1
				continue
			if c == "\u001b":
				var m := RegEx.create_from_string("^\u001b([A-Za-z]+)(?:\\[(\\d+)\\])?|^\u001b([{}])").search(text.substr(i))
				if m == null:
					i += 1
					continue
				var code := m.get_string(1).to_upper()
				var param := int(m.get_string(2)) if m.get_string(2) != "" else 0
				if m.get_string(3) == "{":
					if cur <= 96:
						cur += 6
					line_max = maxi(line_max, cur)
				elif m.get_string(3) == "}":
					if cur >= 24:
						cur -= 6
				elif code == "C":
					color = Color(ELEMENT_COLORS[param - 2000]) if param >= 2000 and param <= 2015 else XUI.text_color(param)
				elif code == "I":
					glyphs.append({"icon": param, "x": x + 2, "y": line_y - 3})
					x += 36
				i += m.get_string(0).length()
				continue
			var gw := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, cur).x
			if cw - x < gw:
				heights.append(line_max + 8)
				x = PAD
				line_y += line_h
				line_h = cur + 8.0
				line_max = cur
				continue
			glyphs.append({"t": c, "x": x, "y": line_y, "size": cur, "color": color, "lh": line_h, "w": gw})
			x += gw
			i += 1
		heights.append(line_max + 8)
		var th := 0.0
		for hh in heights:
			th += hh
		lines.append({"glyphs": glyphs, "y": y, "h": th, "line": bool(r[3])})
		y += th
		height += th
		if bool(r[3]):
			y += SEP
			height += SEP
	return {"height": height, "lines": lines}


## RJO.SW.calcTextHeight(textState, false)：本行（到换行符为止）最大字号 + 8
static func _first_line_height(text: String, size: int) -> int:
	var nl := text.find("\n")
	var line := text if nl < 0 else text.substr(0, nl)
	var cur := size
	var mx := size
	var i := line.find("\u001b")
	while i >= 0 and i + 1 < line.length():
		if line[i + 1] == "{":
			if cur <= 96:
				cur += 6
		elif line[i + 1] == "}":
			if cur >= 24:
				cur -= 6
		mx = maxi(mx, cur)
		i = line.find("\u001b", i + 1)
	return mx + 8


## RJO.SW.convertEscapeCharacters（\\ → ESC，变量/角色名/货币）
static func _escapes(text: String) -> String:
	return XMVText.convert_escapes(text)


static func _css(text: String) -> Color:
	var m := RegEx.create_from_string("rgba?\\(\\s*([\\d.]+)\\s*,\\s*([\\d.]+)\\s*,\\s*([\\d.]+)(?:\\s*,\\s*([\\d.]+))?\\s*\\)").search(text)
	if m:
		return Color8(int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3)), int(float(m.get_string(4)) * 255) if m.get_string(4) != "" else 255)
	if text.begins_with("#"):
		return Color(text)
	return XUI.TEXT


# ======================================================================
# 显示
# ======================================================================

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame)
	add_child(frame)
	canvas = XMVCanvas.new()
	canvas.clip_contents = false
	canvas.painter = _paint
	add_child(canvas)
	visible = false


## 显示 obj 的说明卡（obj 为空时隐藏）
func show_for(obj, kind := "") -> void:
	if not (obj is Dictionary) or obj.is_empty():
		visible = false
		return
	rows = content(obj, kind)
	quality = _quality(obj)
	var lay := layout(rows, min_font)
	_lines = lay.lines
	size = Vector2(WIDTH, lay.height)
	frame.position = Vector2(-10, -10)
	frame.size = size + Vector2(20, 20)
	canvas.position = Vector2.ZERO
	canvas.size = size
	visible = lay.height > PAD * 2
	frame.queue_redraw()
	canvas.queue_redraw()


## 优化 O-008：贴着选中行放，不盖住选中行。side：left（战斗，列表左侧）、right、below（列表内，选中行下方/上方）。
## anchor 为选中行在画布上的矩形；area 为可用范围（默认整个画面，四周留 12）。
func place_near(anchor: Rect2, side := "right", area := Rect2(12, 12, 1256, 696)) -> void:
	var w := size.x
	var h := size.y
	var p := Vector2.ZERO
	var gap := 14.0   # 品质框外扩 10，再留 4
	match side:
		"left":
			p = Vector2(anchor.position.x - gap - w, anchor.position.y)
			if p.x < area.position.x:
				p.x = anchor.end.x + gap
		"below":
			p = Vector2(anchor.end.x - w, anchor.end.y + gap)
			if p.y + h > area.end.y:
				p.y = anchor.position.y - gap - h
		_:
			p = Vector2(anchor.end.x + gap, anchor.position.y)
			if p.x + w > area.end.x:
				p.x = anchor.position.x - gap - w
	p.x = clampf(p.x, area.position.x, area.end.x - w)
	p.y = clampf(p.y, area.position.y, area.end.y - h)
	position = p.round()


func _draw_frame() -> void:
	# ItemQuality：四层 Window{品质} 窗口（不透明度、背景都是 60），覆盖卡外 10px
	var skin_path := XDB.img_path("system", "Window%d" % quality)
	var style := XUI.panel(60)
	if skin_path != "":
		style.skin = load(skin_path)
	style.back_opacity = 60.0 / 255.0
	for i in range(4):
		frame.draw_style_box(style, Rect2(Vector2.ZERO, frame.size))


func _paint(c: XMVCanvas) -> void:
	c.draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), BACK)
	for l in _lines:
		for g in l.glyphs:
			if g.has("icon"):
				c.icon(int(g.icon), g.x, g.y)
			else:
				c.text(g.t, g.x, g.y, g.w * 2.0 if g.lh != 36.0 else g.w + 2, "left", g.color, g.size, g.lh)
