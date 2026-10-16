class_name XStatusPage
extends XActorPage
## 主菜单「状态」：JAH_StatusMenuCore（Scene_Status＋JAH_Window_Status_*），按正式 v0.28 运行时读数逐像素复现
## （夹具 tests/fixtures/status_page_oracle.json：各窗口矩形与每页 contents 上的 drawText／blt／fillRect 调用；
##  参照截图 04_验证/本地结果/原版参照/bajie8_status_p0～p2）。
## - 选页窗 (0,0,1280,64)：4 列（项宽 304、间距 12），文字居中（内边距 6）；左右换页（按下时循环），上下滚动当前页，
##   Q/W 与 PageUp/PageDown 换角色，取消返回。页窗在下面，不活动，只显示。
## - 页窗原在 (0,72,1280,648)；开着战力时上面插战力条 XPowerStrip (24,72,1232,36)，页窗下移到 (0,108,1280,612)。
##   每页一个可滚动窗口（行高 36，可见 contents 高 ÷ 36 行），按角色重置滚动；超出时右下有翻页箭头。
## - 表头（drawVanillaHeader，ExtraVanillaBlank）：脸 (14,18)；名字 (204,0,168)＋昵称「, "昵称"」紧接其后；职业 (204,36)；
##   状态图标 (204,72)；「Lv」与等级 (204,144)；HP/MP/TP 量条 (780,0/36/72, 宽 458)；经验条 (780,144)：右「EXP」、
##   左「距离下一Lv」、剩余经验右对齐；分隔线 y 197（白 48/255，高 2）。表头 6 行，页内容从 y 216 起。
## - 第 1 页「状态」：两列各 13 项（名 160 系统色＋值 60 右对齐；列 x 82、466，空项留空行）；装备列 x 850，按部位逐行。
## - 第 2 页「加成与抗性」：元素／加成（CodexElements 元素伤害加成，两位小数）／穿透（百分比）／承伤（按档位着色），
##   武器类型加成，其他加成 13 项（爆伤、终伤、全队掉率、再次行动、攻击次数、技能档位、消耗、连击、元素转换）；元素名用元素色。
## - 第 3 页「掌握」：「角色可使用」，职业特性可装备的武器／防具类型（mpGaugeColor2），超出窗口高时换列。
## - 第 4 页：正式版是「修行」（installNativeGuidanceRuntime 真气页，真气未移植）；这里先放「套装」（O-032，见优化登记）。
## - 右上角「战力 N」按钮（XPowerPanel.make_button）打开角色战力面板（XPowerPanel）；关掉战力时没有按钮和战力条。

const SELECT_RECT := Rect2(0, 0, 1280, 64)
const PAGE_Y := 72.0
const LH := 36.0
const PAD := 14.0
## O-032：第 4 页正式版是「修行」（真气未移植），改放「套装」；PAGE_NAMES[3] 改回「修行」并实现真气页即恢复
const PAGE_NAMES := ["状态", "加成与抗性", "掌握", "套装"]
const ITEM_W := 304.0
const ITEM_STEP := 316.0
const HEADER_LINES := 6
## JAH 参数：每列项数、名宽、值宽、装备列（RequiredColumnWidth 440、EquipColumnWidth 320）
const PARAM_COLS := 2
const PARAM_ROWS := 13
const NAME_W := 160.0
const VALUE_W := 60.0
const PARAM_X := [82.0, 466.0]
const EQUIP_X := 850.0
## 承伤档位（ResistanceThresholds／ResistanceColors，textColor 编号；-1 不换色）
const RESIST_THRESHOLDS := [2.01, 1.01, 1.0, 0.5, 0.01, 0.0, -0.99, -10.0]
const RESIST_COLORS := [10, 2, -1, 5, 13, 14, 3, 11]

var page := 0
var tops := [0, 0, 0, 0]
var select_win: XMVWindow
var page_win: XMVWindow
var power_strip: XPowerStrip
var power_button: Button
var power_panel: XPowerPanel
var _last_actor := -1


func rebuild() -> void:
	super.rebuild()
	var a := actor()
	if a.actor_id != _last_actor:
		tops = [0, 0, 0, 0]
		_last_actor = a.actor_id
	# 战力条占页窗原位置的上 36，页窗下移；关掉战力时没有
	var page_y := PAGE_Y
	power_strip = XPowerStrip.make(content, a, PAGE_Y, 1280)
	if power_strip != null:
		page_y += XPowerStrip.HEIGHT
	page_win = XMVWindow.make(content, Rect2(0, page_y, 1280, 720 - page_y), XUI.MENU_WINDOW_OPACITY, _paint_page)
	select_win = XMVWindow.make(content, SELECT_RECT, XUI.MENU_WINDOW_OPACITY, _paint_select)
	select_win.canvas.blink = true
	power_button = XPowerPanel.make_button(a, open_power)
	if power_button != null:
		content.add_child(power_button)
	_scroll(0)


func open_power() -> void:
	if power_panel != null and is_instance_valid(power_panel):
		return
	power_panel = XPowerPanel.open(self, actor())
	power_panel.closed.connect(func(): power_panel = null)


## 可见行数（Window_Selectable.maxPageRows）
func page_rows() -> int:
	return floori((page_win.size.y - PAD * 2) / LH)


func max_top() -> int:
	return maxi(0, line_count(actor(), page) - page_rows())


func _scroll(d: int) -> void:
	tops[page] = clampi(tops[page] + d, 0, max_top())
	page_win.up_arrow = tops[page] > 0
	page_win.down_arrow = tops[page] < max_top()
	select_win.refresh()
	page_win.refresh()


func set_page(i: int) -> void:
	if i == page:
		return
	page = i
	XSound.system(0)
	_scroll(0)


## 当前页画出的全部文字（测试用）
func all_text() -> String:
	return "\n".join(PAGE_NAMES + page_ops(actor(), page, page_win.size.y).filter(func(op): return op[0] == "text").map(func(op): return str(op[1])))


# ---- 绘制 ----
func _paint_select(c: XMVCanvas) -> void:
	for i in range(PAGE_NAMES.size()):
		var r := Rect2(i * ITEM_STEP, 0, ITEM_W, LH)
		if i == page:
			c.cursor(r, true)
		c.text(PAGE_NAMES[i], r.position.x + 6, 0, ITEM_W - 12, "center")


func _paint_page(c: XMVCanvas) -> void:
	var dy: float = -tops[page] * LH
	for op in page_ops(actor(), page, page_win.size.y):
		match str(op[0]):
			"text":
				c.text(op[1], op[2], op[3] + dy, op[4], op[6], Color(op[8]), op[7], op[5])
			"face":
				c.face(op[1], op[2], op[3], op[4] + dy)
			"icon":
				c.icon(op[1], op[2], op[3] + dy)
			"gauge":
				var w: float = op[3]
				c.gauge(op[1], op[2] + dy, w, (op[4] + 2.0) / w if op[4] > 0 else 0.0, Color(op[5]), Color(op[6]))
			"line":
				c.draw_rect(Rect2(op[1], op[2] + LH / 2 - 1 + dy, op[3], 2), Color(1, 1, 1, 48 / 255.0))


## 各页行数（getLineCount：表头 6 行＋页内容）
static func line_count(a: XActor, p: int) -> int:
	match p:
		0:
			return HEADER_LINES + PARAM_ROWS
		1:
			return HEADER_LINES + 14
		2:
			return HEADER_LINES + 10
		_:
			return HEADER_LINES + _suit_lines(a).size()


# ---- 绘制调用（与正式版 contents 上的调用一一对应，测试直接比对） ----
## ["text", 文字, x, y, 宽, 行高, 对齐, 字号, 颜色] ["face", 文件, 序号, x, y] ["icon", 序号, x, y]
## ["gauge", x, y, 宽, 填充宽, 色1, 色2] ["line", x, y, 宽]（drawHorzLine 的 y：线画在 y+17）
static func page_ops(a: XActor, p: int, window_h := 612.0) -> Array:
	var ops := header_ops(a)
	match p:
		0:
			ops += _params_ops(a)
		1:
			ops += _resist_ops(a)
		2:
			ops += _mastery_ops(a, window_h)
		_:
			ops += _suit_ops(a)
	return ops


static func _t(s: String, x: float, y: float, w: float, align := "left", color := XUI.TEXT) -> Array:
	return ["text", s, x, y, w, LH, align, XUI.FONT_SIZE, "#" + color.to_html(false)]


static func _tw(s: String) -> float:
	return XUI.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, XUI.FONT_SIZE).x


static func _term(i: int) -> String:
	return str(XDB.system().get("terms", {}).get("basic", [])[i])


static func header_ops(a: XActor) -> Array:
	var ops := []
	var d := a.data()
	ops.append(["face", str(d.get("faceName", "")), int(d.get("faceIndex", 0)), PAD, ceilf(LH / 2)])
	# drawBasicInfo：x 204，宽 max(367, 204 + 窗宽 × 0.45) = 780
	var x := 204.0
	var w := maxf(367.0, 204.0 + 1280 * 0.45)
	var name := a.display_name()
	var nick := str(a.nickname)
	if nick != "":
		var nw := _tw(name)
		ops.append(_t(", \"%s\"" % nick, x + nw, 0, w - nw - PAD))
	ops.append(_t(name, x, 0, 168, "left", XMenu._hp_color(a)))
	var cls := str(a.class_data().get("name", ""))
	if cls != "":
		ops.append(_t(cls, x, LH, 168))
	var n := 0
	for st in a.states():
		if int(st.get("iconIndex", 0)) > 0 and n < 4:
			ops.append(["icon", int(st.iconIndex), x + n * 32, LH * 2 + 2])
			n += 1
	var lv := _term(1)
	var lw := _tw(lv)
	ops.append(_t(lv, x, LH * 4, lw, "left", XUI.SYSTEM))
	ops.append(_t(XMenu._group(a.level), x + lw, LH * 4, _tw(XMenu._group(a.max_level())), "right"))
	# drawGauges：x max(571, 780)，宽 contents 1252 − x − 14 = 458
	var gx := maxf(571.0, w)
	var gw := 1252.0 - gx - PAD
	ops += _param_gauge(_term(3), a.hp, a.mhp, gx, 0, gw, "hp", XMenu._hp_color(a))
	ops += _param_gauge(_term(5), a.mp, a.mmp, gx, LH, gw, "mp", XUI.TEXT)
	var tp_rate := a.tp / a.max_tp() if a.max_tp() > 0 else 0.0
	ops.append(_gauge(gx, LH * 2, gw, tp_rate, "tp"))
	ops.append(_t(_term(7), gx, LH * 2, 44, "left", XUI.SYSTEM))
	ops.append(_t(str(int(a.tp)), gx + gw - 64, LH * 2, 64, "right"))
	# drawActorXp（只显示剩余）：经验条宽 max(458, 320)
	var max_lv := a.level >= a.max_level()
	var v1 := float(a.exp_total - a.exp_for_level(a.level))
	var need := float(a.exp_for_level(a.level + 1) - a.exp_total)
	var v2 := need + v1
	var rate := 1.0 if max_lv else (v1 / v2 if v2 > 0 else 0.0)
	var v3 := 0.0 if max_lv else v2 - v1
	ops.append(_gauge(gx, LH * 4, gw, rate, "xp"))
	var exp_a := _term(9)
	var ew := _tw(exp_a)
	ops.append(_t(exp_a, gx + gw - ew, LH * 4, ew, "right", XUI.SYSTEM))
	var next := str(XDB.system().get("terms", {}).get("messages", {}).get("expNext", "")).replace("%1", lv)
	ops.append(_t(next, gx, LH * 4, _tw(next), "left", XUI.SYSTEM))
	ops.append(_t(XMenu._group(v3), gx, LH * 4, gw - ew - _tw(" "), "right"))
	ops.append(["line", 0.0, LH * 5, 1252.0])
	return ops


## YEP drawGauge：填充宽 floor(宽 × 比例) − 2
static func _gauge(x: float, y: float, w: float, rate: float, kind: String) -> Array:
	var cols: Array = XUI.GAUGES[kind]
	return ["gauge", x, y, w, maxf(floorf(w * clampf(rate, 0.0, 1.0)) - 2.0, 0.0), "#" + cols[0].to_html(false), "#" + cols[1].to_html(false)]


## drawActorHp/Mp：量条、标签（宽 44）、「当前 / 最大」（数值宽按最大值）
static func _param_gauge(label: String, cur: float, mx: float, x: float, y: float, w: float, kind: String, color: Color) -> Array:
	var ops := [_gauge(x, y, w, cur / maxf(mx, 1.0), kind), _t(label, x, y, 44, "left", XUI.SYSTEM)]
	var vw := _tw(XMenu._group(mx))
	var sw := _tw("/")
	var x1 := x + w - vw
	var x2 := x1 - sw
	var x3 := x2 - vw
	if x3 >= x + _tw(label):
		ops.append(_t(XMenu._group(cur), x3, y, vw, "right", color))
		ops.append(_t("/", x2, y, sw, "right"))
		ops.append(_t(XMenu._group(mx), x1, y, vw, "right"))
	else:
		ops.append(_t(XMenu._group(cur), x1, y, vw, "right", color))
	return ops


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) and absf(v) < 1e15 else str(v)


# ---- 第 1 页：能力值与装备 ----
static func _params_ops(a: XActor) -> Array:
	var ops := []
	var params := XDB.plugin("JAH_StatusMenuCore")
	var y0 := LH * HEADER_LINES
	for col in range(PARAM_COLS):
		for row in range(PARAM_ROWS):
			var i := col * PARAM_ROWS + row + 1
			var symbol := str(params.get("Parameter %d Symbol" % i, ""))
			if symbol == "":
				continue
			var y := y0 + row * LH
			ops.append(_t(str(params.get("Parameter %d Name" % i, symbol)), PARAM_X[col], y, NAME_W, "left", XUI.SYSTEM))
			var v := float(a.get(symbol))
			var s := "%d%%" % int(XPower.js_round(v * 100)) if str(params.get("Parameter %d as %%" % i, "true")) == "true" else _num(v)
			ops.append(_t(s, PARAM_X[col] + NAME_W, y, VALUE_W, "right"))
	# drawEquipments：每个部位一行（空部位留空），图标 (x+2, y+2)、名字 (x+36, 宽 276)
	for slot in range(a.equips.size()):
		var e = a.equips[slot]
		if not e is Dictionary or e.is_empty():
			continue
		var y := y0 + slot * LH
		ops.append(["icon", int(e.get("iconIndex", 0)), EQUIP_X + 2, y + 2])
		ops.append(_t(XQuality.list_name(e), EQUIP_X + 36, y, 276, "left", XGear.color(e)))
	return ops


# ---- 第 2 页：加成与抗性 ----
static func _resist_ops(a: XActor) -> Array:
	var ops := []
	var sys := XDB.system()
	var elements: Array = sys.elements
	var wtypes: Array = sys.weaponTypes
	var name_w := 0.0
	for i in range(1, elements.size()):
		name_w = maxf(name_w, _tw(str(elements[i])))
	var wt_w := 0.0
	for i in range(1, wtypes.size()):
		if str(wtypes[i]) != "":
			wt_w = maxf(wt_w, _tw(str(wtypes[i])))
	var passive_w := _tw("-999%") + PAD
	var pen_w := _tw("9999%") + PAD
	var resist_w := _tw("-999%") + PAD
	var wbonus_w := _tw("9999%") + PAD
	name_w += PAD
	wt_w += PAD
	var left := PAD * 2
	var gap := PAD
	var col7 := 170 + left + name_w + passive_w + pen_w + resist_w + wt_w + wbonus_w + gap * 6
	var col8 := col7 + 100 + gap + 15
	var y := LH * HEADER_LINES
	var tx := left + 120
	ops.append(_t("元素", tx, y, name_w, "left", XUI.SYSTEM))
	tx += name_w + gap
	ops.append(_t("加成", tx, y, passive_w, "center", XUI.SYSTEM))
	tx += passive_w + gap
	ops.append(_t("穿透", tx, y, pen_w, "center", XUI.SYSTEM))
	tx += pen_w + gap
	ops.append(_t("承伤", tx, y, resist_w, "center", XUI.SYSTEM))
	tx += resist_w + gap
	ops.append(_t("武器", tx + 50, y, wt_w, "center", XUI.SYSTEM))
	tx += wt_w + gap
	ops.append(_t("加成", tx + 50, y, wbonus_w, "center", XUI.SYSTEM))
	ops.append(_t("其他加成", col7 + 65, y, 100, "left", XUI.SYSTEM))
	y += LH
	var cache := a.passive_cache()
	for e in range(1, elements.size()):
		var x := left + 120
		ops.append(_t(str(elements[e]) if str(elements[e]) != "" else "元素%d" % e, x, y, name_w, "left", _element_color(e)))
		x += name_w + gap
		ops.append(_t(_pct2(XDamage.element_bonus(a, e)), x, y, passive_w, "center"))
		x += passive_w + gap
		ops.append(_t(_num(float(cache.get("penetratePercent", {}).get(e, 0.0))) + "%", x, y, pen_w, "center"))
		x += pen_w + gap
		var rate := a.element_rate(e)
		var color := XUI.TEXT
		for k in range(RESIST_THRESHOLDS.size()):
			if rate >= RESIST_THRESHOLDS[k]:
				if RESIST_COLORS[k] >= 0:
					color = XUI.text_color(RESIST_COLORS[k])
				break
		ops.append(_t("%d%%" % int(XPower.js_round(rate * 100)), x, y, resist_w, "center", color))
		y += LH
	var wy := LH * (HEADER_LINES + 1)
	for i in range(1, wtypes.size()):
		var x := left + name_w + passive_w + pen_w + resist_w + gap * 4 + 170
		ops.append(_t(str(wtypes[i]) if str(wtypes[i]) != "" else "武器类型%d" % i, x, wy, wt_w, "center", XUI.SYSTEM))
		x += wt_w + gap
		ops.append(_t(_num(float(cache.get("SkETypeHarmRi", {}).get(i, 0.0)) * 100) + "%", x, wy, wbonus_w, "center"))
		wy += LH
	var qy := LH * (HEADER_LINES + 1)
	for row in global_bonuses(a):
		ops.append(_t(row[0], col7, qy, 100, "center", XUI.SYSTEM))
		ops.append(_t(row[1], col8, qy, 80, "center", _element_color(_element_index(row[1]))))
		qy += LH
	return ops


## installDamageElementRuntime：页上画到元素名时用元素色（物理及以后；不是元素名用系统色/原色由调用方给）
static func _element_color(e: int) -> Color:
	if e > 0 and e < XHelpCard.ELEMENT_COLORS.size():
		return Color(XHelpCard.ELEMENT_COLORS[e])
	return XUI.TEXT


static func _element_index(s: String) -> int:
	return XDB.system().elements.find(s)


## Math.round(x × 10000) / 100 + "%"
static func _pct2(v: float) -> String:
	return _num(XPower.js_round(v * 10000) / 100.0) + "%"


## 其他加成 13 项 [名, 值]（dsPassiveSkill refreshPassiveCache 的字段＋JAH 的写法）
static func global_bonuses(a: XActor) -> Array:
	var cache := a.passive_cache()
	var again_action := 0.0
	var again_atk := 0.0
	for t in a.all_traits():
		if int(t.code) == 34:
			again_atk += float(t.value)
		elif int(t.code) == 61:
			again_action += float(t.value)
	var consume := {"All": 0, "Zj": 0, "Mf": 0}
	var again_use := {"All": 0, "Zj": 0, "Mf": 0}
	var element := 0
	for o in a.equip_list() + a.skills() + a.states():
		var note := str(o.get("note", ""))
		for m in RegEx.create_from_string("<passiveAPLUS:\\s*([^>]*)>").search_all(note):
			again_action += m.get_string(1).replace("%", "").strip_edges().to_float() / 100.0
		for m in RegEx.create_from_string("<(ConsumeReduce|AgainUse)(All|Zj|Mf):\\s*([^>]*)>").search_all(note):
			var pool := consume if m.get_string(1) == "ConsumeReduce" else again_use
			pool[m.get_string(2)] += m.get_string(3).strip_edges().to_int()
		var de := RegEx.create_from_string("<DamageElements:\\s*(\\d+)>").search(note)
		if de:
			element = int(de.get_string(1))
	var dvup: Dictionary = cache.get("skillTypeDvup", {})
	var pct := func(v: float) -> String: return "%d%%" % int(XPower.js_round(v * 100))
	return [["爆伤加成", pct.call(float(cache.get("critHarmRi", 0.0)))],
		["终伤加成", pct.call(float(cache.get("globalHarmRi", 0.0)))],
		["全队掉率", drop_rate_text()],
		["再次行动", pct.call(again_action)],
		["攻击次数", _num(again_atk + 1)],
		["1-30技能", pct.call(float(dvup.get("A", 0.0)))],
		["40级技能", pct.call(float(dvup.get("B", 0.0)))],
		["45级技能", pct.call(float(dvup.get("C", 0.0)))],
		["战技消耗", "%d%%" % maxi(1, 100 - (consume.All + consume.Zj))],
		["战技连击", "%d%%" % (again_use.All + again_use.Zj)],
		["魔法消耗", "%d%%" % maxi(1, 100 - (consume.All + consume.Mf))],
		["魔法连击", "%d%%" % (again_use.All + again_use.Mf)],
		["元素转换", str(XDB.system().elements[element]) if element > 0 and element < XDB.system().elements.size() else "无"]]


## calcDropBonus：(1＋套装加成) × 套装倍率 × 出战成员每个 passiveIRUP 依次 ×(1＋v%)
static func drop_rate_text() -> String:
	var s := XState.current
	var gt := XEquipSuits.reward(s.members(), 1, 2)
	var ds := 1.0
	for m in s.battle_members():
		for v in m.passive_values("passiveIRUP"):
			ds += XActor._num(v) * 0.01 * ds
	return "%d%%" % int(XPower.js_round(gt * ds * 100))


# ---- 第 3 页：掌握 ----
static func _mastery_ops(a: XActor, window_h: float) -> Array:
	var ops := []
	var avail := 1252.0
	var name_w := maxf(_tw("武器"), _tw("防具")) + PAD
	var value_w := 120.0
	var even := (avail - (name_w + value_w) * 2) / 4.0
	var header := "角色可使用"
	var hw := _tw(header)
	var y := LH * HEADER_LINES
	ops.append(_t(header, (avail - hw) / 2, y, hw))
	y += LH * 2
	var weapons := []
	var armors := []
	var sys := XDB.system()
	for t in a.class_data().get("traits", []):
		if int(t.code) == 51:
			weapons.append(str(sys.weaponTypes[int(t.dataId)]))
		elif int(t.code) == 52:
			armors.append(str(sys.armorTypes[int(t.dataId)]))
	var x := even
	ops += _section("武器", weapons, x, y, name_w, value_w, window_h)
	x += name_w + value_w + 1.3 * even
	ops += _section("防具", armors, x, y, name_w, value_w, window_h)
	return ops


## drawSection：标题系统色；各项 mpGaugeColor2 右对齐，y＋40 超过窗口高时换到下一列（右移名宽）
static func _section(title: String, types: Array, x: float, y: float, name_w: float, value_w: float, window_h: float) -> Array:
	var ops := [_t(title, x, y, name_w, "left", XUI.SYSTEM)]
	var top := y
	for t in types:
		if y + 40 > window_h:
			y = top
			x += name_w
		ops.append(_t(t, x + name_w - 30, y, value_w, "right", XUI.MP_COST))
		y += LH
	return ops


# ---- 第 4 页：套装（O-032） ----
static func _suit_lines(a: XActor) -> Array:
	var out := []
	var counts := XEquipSuits.counts(a)
	if counts.is_empty():
		out.append(["当前装备没有套装。", XUI.DIM])
	for id in counts:
		var suit := XDB.rec("EquipSuits", int(id))
		if suit.is_empty():
			continue
		out.append(["%s · 已装备 %d 件" % [suit.name, int(counts[id])], XUI.SYSTEM])
		for bonus in suit.bonuses:
			var active := int(counts[id]) >= int(bonus.requirePieces)
			out.append(["%d 件 %s：%s" % [int(bonus.requirePieces), "已生效" if active else "未激活", XGearInfo.bonus_text(bonus)], XUI.POWER_UP if active else XUI.DIM])
	out.append(["满足件数的各档加成同时生效；队伍奖励按全队套装计算。", XUI.DIM])
	return out


static func _suit_ops(a: XActor) -> Array:
	var ops := []
	var y := LH * HEADER_LINES
	for line in _suit_lines(a):
		var op := _t(line[0], PAD * 2, y, 1252 - PAD * 4, "left", line[1])
		op[8] = "#" + (line[1] as Color).to_html(true)
		ops.append(op)
		y += LH
	return ops


# ---- 操作 ----
func _unhandled_input(event: InputEvent) -> void:
	if power_panel != null and is_instance_valid(power_panel):
		return
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		get_viewport().set_input_as_handled()
		var d := -1 if event.is_action("ui_left") else 1
		var n := PAGE_NAMES.size()
		# 按下时循环，按住连发不越过两端（Window_Selectable.cursorLeft/Right 的 wrap）
		var next := page + d
		if event.is_echo():
			next = clampi(next, 0, n - 1)
		set_page(posmod(next, n))
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_scroll(-1 if event.is_action("ui_up") else 1)
	else:
		super._unhandled_input(event)


## 点选页签（Window_Selectable 触摸选中）
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position - SELECT_RECT.position - Vector2(PAD, PAD)
		if p.y >= 0 and p.y < LH and p.x >= 0:
			var i := int(p.x / ITEM_STEP)
			if i < PAGE_NAMES.size() and p.x - i * ITEM_STEP < ITEM_W:
				accept_event()
				set_page(i)
