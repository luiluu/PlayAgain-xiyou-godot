class_name XMerchant29Page
extends Control
## 【cc·八戒·未经审查】深渊／不朽商人界面（installAbyssMerchantRuntime 的 Scene_Merchant29 merchant 模式；XAbyssMerchant.open_current 打开）。
## 版面照原版 Scene_Merchant29.create（期二）：
## - 上方 Window_Help(2) 标题（两行，行高 36）；左边 Window_Merchant29 列表 (0,100, floor(1280×0.43)=550, 620)，可见 16 行；
##   右边 Window_MerchantDetail29 详情 (550,100,730,556)；右下 Window_Help(1) 翻页条 (550,656,730,64)「◀ 上一页     n／m     下一页 ▶」（20 号）。
## - 列表 updateHelp：行带装备（装备池那一页）就显示该装备的 RJO.HE.getDescParams 行（XHelpCard.desc_params），
##   否则显示 help 文字（22 号白），默认「确认选择；取消返回上一级。」。
## - 详情 render29：每行按自己的字号、颜色、对齐排版，行与行之间再加 8；超出高度时分页，
##   页数 1＋ceil(溢出 ÷ (内容高−40))，第 p 页从 p×(内容高−40) 起（不超过最后一屏）。换内容回第一页。
## - 翻页：PageUp／PageDown（列表的 pageup／pagedown 处理器，不翻列表）、详情上滚轮（列表照 Window_Selectable 也跟着滚）、点翻页条左半往前、右半往后。
## - 装备池那一页确定：详情翻到下一页（equipmentDetail29）。抽取出错：提示错误文字，详情也显示它。
## 页面与文字照原版：
## - 首页：标题「深渊商人　路线名」「战利品点 N　剩余抽取 n 次」；查看本副本完整装备池、抽取武器／防具／饰品（该分组池空时不能选）、离开。
## - 装备池：标题「路线名　完整装备池（n件）」「先选分组时，该分组内每件基础装备等概率。」；每行「名字　分组」，取消回首页。
## - 抽取：标题「分组抽奖　路线名」「同一分组内基础装备等概率，必出本档指定类别1条。」；三行「30点　必出1条Mod特效」等（点数够且次数没用完才能选），
##   行的说明「消耗本路线战利品点30；装备本体和具体特效随机。」；抽到提示「获得 名字（类别）」并刷新本页。取消回首页。
## 详情字号沿用说明卡的 O-007（XHelpCard.MIN_FONT，设 0＝原版 10／12 号）。
## 专武·特效吸取（openAbsorb，mode＝"absorb"）：技能页用 10455 打开，见下方「专武·特效吸取」与 XAffixAbsorb。
## 还没移植：路线预览（openPreview），见交付单 cc_bajie-newsrc4.md。
signal closed

const LEFT_W := 550.0          # Math.floor(Graphics.boxWidth × 0.43)
const HEADER_H := 100.0        # Window_Help(2)：fittingHeight(2) = 2×36 + 28
const NAV_H := 64.0            # fittingHeight(1)
const HEADER_RECT := Rect2(0, 0, 1280, HEADER_H)
const LIST_RECT := Rect2(0, HEADER_H, LEFT_W, 720 - HEADER_H)
const DETAIL_RECT := Rect2(LEFT_W, HEADER_H, 1280 - LEFT_W, 720 - HEADER_H - NAV_H)
const NAV_RECT := Rect2(LEFT_W, 720 - NAV_H, 1280 - LEFT_W, NAV_H)
const LIST_ROWS := 16          # floor((620 − 28) / 36)
const ROW_GAP := 8.0           # render29：每行 textHeight + 8
const TEXT_SIZE := 22          # setText：[text, 22, '#ffffff', false, 0]
const NAV_SIZE := 20
const DEFAULT_HELP := "确认选择；取消返回上一级。"


## Window_Merchant29：Window_Command 单列；pageup／pagedown 设了处理器，翻的是详情页
class List29 extends XYunChoicesWindow:
	signal turn(d: int)
	var detail_rect := Rect2()

	func _unhandled_input(event: InputEvent) -> void:
		if active and is_visible_in_tree():
			if event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
				turn.emit(1 if event.is_action_pressed("ui_page_down") else -1)
				XKeyMap.handled(self)
				return
			if event is InputEventMouseButton and event.pressed and detail_rect.has_point(event.position):
				var b: int = event.button_index
				if b == MOUSE_BUTTON_WHEEL_DOWN or b == MOUSE_BUTTON_WHEEL_UP:
					turn.emit(1 if b == MOUSE_BUTTON_WHEEL_DOWN else -1)
		super(event)


var header: XMVWindow
var list: List29
var detail: XMVWindow
var nav: XMVWindow
var title_lines: Array = []
var rows: Array = []           # 当前列表的行：{text, enabled, item, help, ...}
var detail_rows: Array = []    # [文字, 字号, 颜色, 分隔, 对齐]
var detail_key := ""
var page := 0
var pages := 1
var full_h := 1.0
var origin_y := 0.0
var _lines: Array = []
var _ok: Callable
var _back: Callable
## M.mode：merchant（商人）／absorb（专武·特效吸取）
var mode := "merchant"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	header = XMVWindow.make(self, HEADER_RECT, op, _paint_header)
	detail = XMVWindow.make(self, DETAIL_RECT, op, _paint_detail)
	nav = XMVWindow.make(self, NAV_RECT, op, _paint_nav)
	list = List29.new()
	list.opacity = op
	list.rows = LIST_ROWS
	list.position = LIST_RECT.position
	list.size = LIST_RECT.size
	list.detail_rect = DETAIL_RECT
	add_child(list)
	list.canvas.painter = list._paint
	list.canvas.blink = true
	list.index_changed.connect(func(_i): update_help())
	list.chosen.connect(func(i): if i >= 0 and i < rows.size(): _ok.call(rows[i]))
	list.cancelled.connect(func(): _back.call())
	list.turn.connect(turn)
	if mode == "absorb":
		absorb_home()
	else:
		home()


## Scene_Merchant29.list29：换标题与行，光标回第一项，刷新详情
func choose(list_rows: Array, ok: Callable, back: Callable, info := []) -> void:
	title_lines = info
	rows = list_rows
	_ok = ok
	_back = back
	header.refresh()
	list.entries = rows
	list.top = 0
	list.select(0 if not rows.is_empty() else -1)
	update_help()


## Window_Merchant29.updateHelp
func update_help() -> void:
	var i := list.index
	if i < 0 or i >= rows.size():
		return
	var r: Dictionary = rows[i]
	if r.has("item"):
		set_equipment(r.item)
	else:
		set_text(str(r.get("help", DEFAULT_HELP)))


func set_text(t: String) -> void:
	if detail_key == "text:" + t:
		return
	detail_key = "text:" + t
	detail_rows = [[t, TEXT_SIZE, "#ffffff", false, 0]]
	_render()


## setEquipment29：absorbView（池里是数据库原件，没有吸取）后 RJO.HE.getDescParams，武器 1、防具 2
func set_equipment(e: Dictionary) -> void:
	e = XAffixAbsorb.view(e)
	var key := "item:%s:%s:%s" % [str(e.get("id", "")), str(e.get("note", "")), JSON.stringify(e.get("params", []))]
	if detail_key == key:
		return
	detail_key = key
	detail_rows = XHelpCard.desc_params(e, 1 if XHelpCard.kind_of(e) == "weapon" else 2)
	_render()


func _content_h() -> float:
	return DETAIL_RECT.size.y - XMVWindow.PADDING * 2


func _render() -> void:
	var cw := DETAIL_RECT.size.x - XMVWindow.PADDING * 2
	var lay := XHelpCard.layout(detail_rows, XHelpCard.MIN_FONT, cw + XHelpCard.PAD * 2)
	_lines = lay.lines
	full_h = maxf(1.0, float(lay.height) - XHelpCard.PAD * 2 + ROW_GAP * _lines.size())
	var ch := _content_h()
	page = 0
	pages = maxi(1, 1 + ceili(maxf(0.0, full_h - ch) / maxf(1.0, ch - 40.0)))
	origin_y = 0.0
	detail.refresh()
	nav.refresh()


## turn29
func turn(d: int) -> void:
	var ch := _content_h()
	page = clampi(page + d, 0, pages - 1)
	origin_y = minf(maxf(0.0, full_h - ch), page * maxf(1.0, ch - 40.0))
	detail.refresh()
	nav.refresh()


func nav_text() -> String:
	return "◀ 上一页     %d／%d     下一页 ▶" % [page + 1, pages]


func _paint_header(c: XMVCanvas) -> void:
	for i in title_lines.size():
		c.text(str(title_lines[i]), 6, i * XUI.LINE_HEIGHT, c.size.x - 6, "left", XUI.TEXT, XUI.FONT_SIZE, XUI.LINE_HEIGHT)


func _paint_nav(c: XMVCanvas) -> void:
	c.text(nav_text(), 6, 0, c.size.x - 6, "left", XUI.TEXT, NAV_SIZE, XUI.LINE_HEIGHT)


func _paint_detail(c: XMVCanvas) -> void:
	var ch := c.size.y
	for k in _lines.size():
		var dy := ROW_GAP * k - XHelpCard.PAD - origin_y
		for g in _lines[k].glyphs:
			var y: float = g.y + dy
			if y > ch or y + 48.0 < 0.0:
				continue
			if g.has("icon"):
				c.icon(int(g.icon), g.x - XHelpCard.PAD, y)
			else:
				c.text(g.t, g.x - XHelpCard.PAD, y, g.w * 2.0 if g.lh != 36.0 else g.w + 2, "left", g.color, g.size, g.lh)


## Window_MerchantDetail29.update：点翻页条左半往前、右半往后
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and NAV_RECT.has_point(event.position):
		turn(-1 if event.position.x < NAV_RECT.position.x + NAV_RECT.size.x / 2.0 else 1)
		XKeyMap.handled(self)


static func _run_of() -> Dictionary:
	var r = XAbyssMerchant.run(XState.current)
	return r if r != null else {}


static func home_info(s: XState) -> Array:
	var cur := _run_of()
	var who: Dictionary = cur.get("identity", {})
	var c := XAbyssMerchant.config()
	return ["%s　%s" % [str(who.get("kind", "")), str(XAbyssMerchant.route(int(s.map_id)).get("name", ""))],
		"战利品点 %d　剩余抽取 %d 次" % [XAbyssMerchant.balance(s, str(who.get("key", ""))), int(c.get("visitLimit", 0)) - int(cur.get("used", 0))]]


static func home_rows(s: XState) -> Array:
	return [{"text": "查看本副本完整装备池", "go": "pool"},
		{"text": "抽取武器", "go": "武器", "enabled": not XAbyssMerchant.pool(s, "武器").is_empty()},
		{"text": "抽取防具", "go": "防具", "enabled": not XAbyssMerchant.pool(s, "防具").is_empty()},
		{"text": "抽取饰品", "go": "饰品", "enabled": not XAbyssMerchant.pool(s, "饰品").is_empty()},
		{"text": "离开", "go": "leave"}]


func home() -> void:
	var s := XState.current
	choose(home_rows(s), _home_pick, _close, home_info(s))


func _home_pick(r: Dictionary) -> void:
	var go := str(r.go)
	if go == "pool":
		preview()
	elif go == "leave":
		_close()
	else:
		tiers(go)


static func pool_rows(map_id: int) -> Array:
	return (XAbyssMerchant.route(map_id).get("pool", []) as Array).map(func(d):
		var it := XAbyssMerchant.item(d)
		return {"text": "%s　%s" % [str(it.get("name", "")), XAbyssMerchant.group(d)], "item": it})


func preview() -> void:
	var s := XState.current
	var r := XAbyssMerchant.route(int(s.map_id))
	choose(pool_rows(int(s.map_id)), _pool_pick, home,
		["%s　完整装备池（%d件）" % [str(r.get("name", "")), (r.get("pool", []) as Array).size()], "先选分组时，该分组内每件基础装备等概率。"])


## equipmentDetail29：详情显示这件装备并翻到下一页
func _pool_pick(r: Dictionary) -> void:
	set_equipment(r.item)
	turn(1)


static func tier_rows(s: XState) -> Array:
	var cur := _run_of()
	var c := XAbyssMerchant.config()
	var key := str(cur.get("identity", {}).get("key", ""))
	var out := []
	for tier in XAbyssMerchant.LABELS.size():
		var cost := int(c.costs[tier])
		out.append({"text": "%d点　必出1条%s" % [cost, XAbyssMerchant.LABELS[tier]], "tier": tier,
			"help": "消耗本路线战利品点%d；装备本体和具体特效随机。" % cost,
			"enabled": XAbyssMerchant.balance(s, key) >= cost and int(cur.get("used", 0)) < int(c.get("visitLimit", 0))})
	return out


func tiers(g: String) -> void:
	var s := XState.current
	choose(tier_rows(s), _tier_pick.bind(g), home,
		["%s抽奖　%s" % [g, str(XAbyssMerchant.route(int(s.map_id)).get("name", ""))], "同一分组内基础装备等概率，必出本档指定类别1条。"])


## 抽到：提示并刷新本页；出错（choose29 的 catch）：提示错误文字，详情也显示它
func _tier_pick(r: Dictionary, g: String) -> void:
	var got = XAbyssMerchant.draw(XState.current, int(r.tier), g)
	if got is String:
		XToast.show_text(got, true)
		set_text(got)
	else:
		XToast.show_text("获得 %s（%s）" % [str(got.name), XAbyssMerchant.LABELS[int(r.tier)]], true)
		tiers(g)


func _close() -> void:
	closed.emit()


# ---- 专武·特效吸取（Scene_Merchant29 absorb 模式：absorbHome29 → slots29 → materials29 → affixes29 → 确认） ----

static func absorb_rows(s: XState) -> Array:
	return XAffixAbsorb.targets(s).map(func(t):
		return {"text": "%s（%d／%d条）" % [str(t.get("name", "")), XAffixAbsorb.absorptions(t).filter(func(d): return d != null).size(), XAffixAbsorb.capacity(t, s)],
			"item": t})


func absorb_home() -> void:
	choose(absorb_rows(XState.current), func(r): absorb_slots(r.item), _close,
		["专武·特效吸取", "按所属角色等级开放：1级一条，35级两条，60级三条。"])


static func slot_rows(s: XState, target: Dictionary) -> Array:
	var stored := XAffixAbsorb.absorptions(target)
	var cap := XAffixAbsorb.capacity(target, s)
	var out := []
	for n in 3:
		var d = stored[n] if n < stored.size() else null
		var open := n < cap
		out.append({"text": "槽位%d：%s" % [n + 1, (XAffixAbsorb.label(d) if d != null else "空槽") if open else ("所属角色35级开放" if n == 1 else "所属角色60级开放")],
			"help": XAffixAbsorb.label(d) if d != null else "选择空槽吸取，或替换指定槽位的特效。", "enabled": open, "slot": n})
	return out


func absorb_slots(target: Dictionary) -> void:
	choose(slot_rows(XState.current, target), func(r): absorb_materials(target, int(r.slot)), absorb_home,
		["选择吸取槽位", "替换只影响所选槽位。"])


func absorb_materials(target: Dictionary, slot: int) -> void:
	var rows := XAffixAbsorb.materials(XState.current, target).map(func(i): return {"text": str(i.get("name", "")), "item": i})
	choose(rows, func(r): absorb_affixes(target, r.item, slot), absorb_slots.bind(target),
		["选择要消耗的材料装备", "已装备、锁定装备不会消耗。"])


func absorb_affixes(target: Dictionary, material: Dictionary, slot: int) -> void:
	var rows := XAffixAbsorb.extra_affixes(material).map(func(d):
		var t := XAffixAbsorb.label(d)
		return {"text": t, "help": t, "d": d})
	choose(rows, func(r): absorb_confirm(target, material, r.d, slot), absorb_materials.bind(target, slot), ["选择一条额外特效"])


func absorb_confirm(target: Dictionary, material: Dictionary, d: Dictionary, slot: int) -> void:
	var stored := XAffixAbsorb.absorptions(target)
	var replace: bool = slot < stored.size() and stored[slot] != null
	var t := XAffixAbsorb.label(d)
	choose([{"text": "确认消耗并吸取", "help": t, "go": "ok"}, {"text": "取消", "go": "cancel"}],
		_confirm_pick.bind(target, material, d, slot), absorb_affixes.bind(target, material, slot),
		["确认消耗 " + str(material.get("name", "")), ("原槽位特效会被替换。" if replace else "吸取至空槽位。") + "当前最多保留%d条。" % XAffixAbsorb.capacity(target, XState.current)])


func _confirm_pick(r: Dictionary, target: Dictionary, material: Dictionary, d: Dictionary, slot: int) -> void:
	if str(r.go) == "ok":
		_absorb_now(target, material, d, slot)
	else:
		absorb_affixes(target, material, slot)


## 出错（choose29 的 catch）：提示错误文字，详情也显示它
func _absorb_now(target: Dictionary, material: Dictionary, d: Dictionary, slot: int) -> void:
	var err := XAffixAbsorb.absorb(XState.current, target, material, d, slot)
	if err != "":
		XToast.show_text(err, true)
		set_text(err)
		return
	XToast.show_text("特效吸取完成。", true)
	absorb_slots(target)
