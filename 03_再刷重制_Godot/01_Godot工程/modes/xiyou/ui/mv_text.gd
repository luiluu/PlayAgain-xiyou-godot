class_name XMVText
extends RefCounted
## MV 文字代码的逐字处理（Window_Base.drawTextEx / processCharacter），照正式版实际生效的插件：
## - convert_escapes()：convertEscapeCharacters，\\ → ESC，\V[n] \N[n] \P[n] \G 替换；YEP_X_MessageEvalText 的 \evalText<<…>>
##   只认识正式版切片里出现的表达式（不执行任意代码）。
## - 每次 step() 处理一个字符或一个代码（MV 每帧一次 processCharacter）：
##   \c[n] 颜色、\i[n] 图标（前进 36）、\{ \} 字号 ±12（YEP_MessageCore：上限 96、下限 12）、\fs[n] 字号、\px[n] \py[n]；
##   消息窗另有 \. \| 等待 15/60 帧、\! 等待按键、\> \< 本行瞬显开关、\^ 结尾不等待、\$ 金钱窗（未做，忽略）。
## - 自动换行（zidonghuanhang 插件）：普通字符放不下（窗口宽 − 2×内边距 − x < 字宽）时先换行。
## - 行高 calcTextHeight：从当前位置到本行结尾的最大字号 + 8（字号 26 → 34）。
## 结果放在 glyphs（{t, x, y, h, size, color} 或 {icon, x, y}），由 XMVCanvas 画出。

const ESC := "\u001b"
const FONT_STEP := 12
const FONT_MAX := 96
const FONT_MIN := 12

var text := ""
var index := 0
var x := 0.0
var y := 0.0
var left := 0.0
var height := 0.0
var size := XUI.FONT_SIZE
var color := XUI.TEXT
var wrap_width := 0.0           # 内容区宽（窗口宽 − 2×内边距）；0 表示不换行
var glyphs: Array = []
var _font: Font


func _init(converted := "", start_x := 0.0, start_y := 0.0, contents_width := 0.0, font_size := XUI.FONT_SIZE) -> void:
	_font = XUI.font()
	text = converted
	x = start_x
	y = start_y
	left = start_x
	wrap_width = contents_width
	size = font_size
	height = calc_height()


## Window_Base.convertEscapeCharacters（不含消息窗专用的名字框/头像代码）
static func convert_escapes(raw: String) -> String:
	var s := raw.replace("\\", ESC)
	s = s.replace(ESC + ESC, "\\")
	var st := XState.current
	for _i in range(2):
		s = _sub(s, "(?i)\u001bV\\[(\\d+)\\]", func(g): return str(int(st.variable(int(g)))) if st else "0")
	s = _sub(s, "(?i)\u001bN\\[(\\d+)\\]", func(g): return _actor_name(int(g)))
	s = _sub(s, "(?i)\u001bP\\[(\\d+)\\]", func(g):
		if st and int(g) >= 1 and int(g) <= st.party.size():
			return st.actor(st.party[int(g) - 1]).display_name()
		return "")
	s = _sub(s, "(?i)\u001bG", func(_g): return str(XDB.system().get("currencyUnit", "")), false)
	s = _sub(s, "(?i)\u001bevalText<<(.*?)>>", func(g): return _eval_text(g))
	return s


static func _actor_name(id: int) -> String:
	var st := XState.current
	if st and st.actors.has(id):
		return st.actor(id).display_name()
	return str(XDB.rec("Actors", id).get("name", ""))


## YEP_X_MessageEvalText：只支持切片里实际出现的表达式。
static func _eval_text(expr: String) -> String:
	if expr.replace(" ", "") == "$dataArmors.length+$dataWeapons.length-12000":
		var arm = XDB.table("Armors")
		var wpn = XDB.table("Weapons")
		return str((arm.size() if arm is Array else 0) + (wpn.size() if wpn is Array else 0) - 12000)
	return ""


static func _sub(s: String, pattern: String, fn: Callable, has_group := true) -> String:
	var re := RegEx.create_from_string(pattern)
	var m := re.search(s)
	while m:
		var rep: String = fn.call(m.get_string(1) if has_group else "")
		s = s.substr(0, m.get_start()) + rep + s.substr(m.get_end())
		m = re.search(s, m.get_start() + rep.length())
	return s


## 去掉所有代码，只留文字（测试记录、帮助用）。
static func plain(raw: String) -> String:
	var t := XMVText.new(convert_escapes(raw))
	var out := ""
	while not t.at_end():
		var r := t.step()
		if r.get("glyph", false):
			out += str(t.glyphs.back().get("t", ""))
		elif r.get("newline", false):
			out += "\n"
	return out


## Window_Base.drawTextEx：一次处理完，返回宽度（textState.x − 起点）。
func run() -> float:
	var x0 := left
	while not at_end():
		step()
	return x - x0


func at_end() -> bool:
	return index >= text.length()


func text_width(s: String, font_size := -1) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size if font_size < 0 else font_size).x


## Window_Base.calcTextHeight(textState, false)
func calc_height() -> float:
	var rest := text.substr(index)
	var nl := rest.find("\n")
	var line := rest if nl < 0 else rest.substr(0, nl)
	var cur := size
	var max_size := size
	var i := line.find(ESC)
	while i >= 0 and i + 1 < line.length():
		var c := line[i + 1]
		if c == "{":
			cur = _bigger(cur)
		elif c == "}":
			cur = _smaller(cur)
		max_size = maxi(max_size, cur)
		i = line.find(ESC, i + 1)
	return max_size + 8


static func _bigger(s: int) -> int:
	return mini(s + FONT_STEP, FONT_MAX)


static func _smaller(s: int) -> int:
	return maxi(s - FONT_STEP, FONT_MIN)


## 处理一个字符或代码；返回本次的事件：
## {glyph}、{newline}、{newpage}、{wait: 帧}、{pause}、{fast: bool}、{pause_skip}、{gold}
func step() -> Dictionary:
	var c := text[index]
	if c == "\n":
		new_line()
		index += 1
		return {"newline": true}
	if c == "\f":
		index += 1
		return {"newpage": true}
	if c == ESC:
		index += 1
		return _escape()
	# zidonghuanhang：放不下就先换行再画
	var w := text_width(c)
	if wrap_width > 0.0 and wrap_width - x < w:
		new_line()
		return {"newline": true, "wrapped": true}
	glyphs.append({"t": c, "x": x, "y": y, "h": height, "size": size, "color": color, "w": w})
	x += w
	index += 1
	return {"glyph": true}


## Window_Base.processNewLine（计算高度时 index 还在换行符上，所以只看换行符之前，即空串 → 当前字号 + 8）
func new_line() -> void:
	x = left
	y += height
	height = calc_height()


func _escape() -> Dictionary:
	var rest := text.substr(index)
	var m := RegEx.create_from_string("^[\\$\\.\\|\\^!><\\{\\}\\\\]|^[A-Za-z]+").search(rest)
	if m == null:
		return {}
	var code := m.get_string(0).to_upper()
	index += code.length()
	match code:
		"C":
			color = XUI.text_color(_param())
		"I":
			var n := _param()
			glyphs.append({"icon": n, "x": x + 2, "y": y + 2})
			x += 36
			return {"glyph": true}
		"{":
			size = _bigger(size)
		"}":
			size = _smaller(size)
		"FS":
			size = _param()
		"PX":
			x = _param()
		"PY":
			y = _param()
		".":
			return {"wait": 15}
		"|":
			return {"wait": 60}
		"!":
			return {"pause": true}
		">":
			return {"fast": true}
		"<":
			return {"fast": false}
		"^":
			return {"pause_skip": true}
		"$":
			return {"gold": true}
	return {}


## Window_Base.obtainEscapeParam：/^\[\d+\]/
func _param() -> int:
	var m := RegEx.create_from_string("^\\[(\\d+)\\]").search(text.substr(index))
	if m == null:
		return 0
	index += m.get_string(0).length()
	return int(m.get_string(1))


## 把 glyphs 画到 XMVCanvas 上（MV drawText(c, x, y, 字宽×2, 行高)）。
static func paint(c: XMVCanvas, list: Array, dx := 0.0, dy := 0.0, alpha := 1.0) -> void:
	for g in list:
		if g.has("icon"):
			c.icon(int(g.icon), g.x + dx, g.y + dy, alpha)
		else:
			c.text(g.t, g.x + dx, g.y + dy, g.w * 2.0, "left", g.color, g.size, g.h, alpha)
