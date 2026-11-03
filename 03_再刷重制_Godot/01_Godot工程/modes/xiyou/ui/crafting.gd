class_name XCraftingScene
extends Control
## 制作（hc.js Scene_Crafting；主菜单「制作」＝Scene_Menu.commandRecipe）。规则在 XCrafting。
## 版面与逐条绘制按冻结 v0.28 浏览器参照（tests/fixtures/crafting_oracle.json）；窗口不透明度照 MOG 菜单 30：
## - 帮助窗 (0,0,1280,100)：列表选中配方的结果说明（类别窗活动时清空）。
## - 类别窗 (0,100,1280,64)：横排 4 格（每格宽 1280/5=256、间隔 12），图标在格左、名字在 +32。类别窗光标决定列表的类别。
## - 配方列表 (0,172,640,476)：已知且类别等级够的配方，drawItemName（宽 312）＋右端「x可做数」；做不了的半透明。
## - 详情 (640,172,640,476)：「制作等级需求:」＋玩家等级（图标 1045）＋「类别等级 |」（类别图标）；y 46「制作材料需求:」，
##   y 78 起每种材料一行（图标 x12、名字 x44、持有数 textColor 3／18、「 / 需要」），行距 32；有费用时底部「制作费用:」与金额＋货币单位。
## - 数量确认窗 (640,648,640,72)：「制作」居中，可做时右端「x数量」；←→ ±1、↑↓ ±10（在 1 与可做数之间）。当前配方可做时窗口与内容不透明 255，否则 75。
## - 金币窗 (640,648,640,64) 盖在确认窗上（原版内容层按初始宽 240 建好后没重建，金额与图标挤在左边，照画）；确认时关上，取消确认再打开，
##   做完弹窗确定后不再打开（原版如此）。
## - 类别等级窗 (0,656,640,64)：图标、等级、经验条（tp 色）与「经验/下一级」，满级（99）写 MAX LEVEL。
## - 结果弹窗：屏幕中线 y 328，「N x 名字 制作成功!」（全失败写 Crafting failed!），宽按文字；x 照原版算法（没扣内边距，略偏右）。
## - 数量按钮（Scene_Crafting.createButtons／placeButtons）：ButtonSet 五个 Sprite_Button（−10／−1／+1／+10／确定），
##   x 在详情窗内居中（间隔 16）、y = 确认窗 y − 行高×2.5；进确认时显示，弹窗确定或取消确认时藏（做完弹窗期间仍在）。
##   松开时在同一按钮上才算点（Sprite_Button.processTouch），按住时用下一排（hot 帧）。确定键：弹窗时数量清回再关弹窗，确认时制作。
## - MV WindowLayer 把后建的金币窗范围从确认窗里挖掉：金币窗开着时确认窗内容（「制作」等）看不见。
## - 锻造配方 457／458（installNativeLeviathanForge.patchCraftScene）：列表确定后先在列表窗位置选一件原件（mode "pick"，一列、行高 72，
##   名字 22 号字、第二行 18 号字「品质 · 层数:N · 已装备／背包」，不能锻造的半透明、按了蜂鸣）；选好进数量确认，取消回列表。
##   帮助窗换成 XGrowthForge.help_text，详情窗 y 224 起多画几行锻造说明（18 号字、行距 25）。锻造不成蜂鸣并回列表（不弹失败窗）。
##   选原件时按 Shift 看原件词条：详情窗位置另开一张说明卡（字号压到 14 以下，O-007 最小字号照常），藏起详情窗；再按 Shift、取消、
##   选定都收起，移光标时跟着换（原版 _codexShowSourceHelp，sourceHelp 在 picker.updateHelp 里重画）；帮助窗提示换成「返回升级预览」。

signal closed

const HELP_RECT := Rect2(0, 0, 1280, 100)
const CAT_RECT := Rect2(0, 100, 1280, 64)
const LIST_RECT := Rect2(0, 172, 640, 476)
const DETAIL_RECT := Rect2(640, 172, 640, 476)
const CONFIRM_RECT := Rect2(640, 648, 640, 72)
const GOLD_RECT := Rect2(640, 648, 640, 64)
const GAUGE_RECT := Rect2(0, 656, 640, 64)
const LH := 36.0
const CW := 612.0                          # 640 宽窗口的内容宽
const DETAIL_CH := 448.0                   # 详情内容高
const CAT_W := 256.0                       # Window_RecCategory.itemWidth = 1280 / 5
const CAT_GAP := 12.0
const LIST_ROWS := 12                      # floor((476 − 28) / 36)
const NAME_W := 312.0                      # drawItemName 不给宽时 hc.js 的缺省
const DIM := 160                           # MV translucentOpacity
const GOLD_ICON := 416
const CRAFTED_TEXT := "制作成功!"
const FAILED_TEXT := "Crafting failed!"
const MAX_LEVEL_TEXT := "MAX LEVEL"
const REQ_LEVEL := "制作等级需求:"
const REQ_MATERIAL := "制作材料需求:"
const COST_TEXT := "制作费用:"
const CRAFT_TEXT := "制作"
## ButtonSet.png 冷帧（y 0）；按下时 y 48。第 5 个宽 96
const BUTTON_SRC := [Rect2(0, 0, 48, 48), Rect2(48, 0, 48, 48), Rect2(96, 0, 48, 48), Rect2(144, 0, 48, 48), Rect2(192, 0, 96, 48)]
const BUTTON_STEPS := [-10, -1, 1, 10, 0]

var mode := "category"        # category / list / confirm / popup
var cat_index := 0
var index := -1
var top := 0
var amount := 1
var list: Array = []
var popup_text := ""
var popup_icon := 0
var help_win: XMVWindow
var cat_win: XMVWindow
var list_win: XMVWindow
var detail_win: XMVWindow
var confirm_win: XMVWindow
var gold_win: XMVWindow
var gauge_win: XMVWindow
var popup_win: XMVWindow
var buttons_visible := false
var _button_down := -1
var _buttons: Control
var _gold_covering := true
var _gold_band := 0.0
var picks: Array = []                # 锻造：可选的原件实例
var pick_index := 0
var pick_top := 0
const PICK_H := 72.0
const PICK_ROWS := 6                 # floor(448 / 72)
var source_card: XHelpCard           # 锻造选原件时 Shift 看的原件说明卡
var source_shown := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	help_win = XMVWindow.make(self, HELP_RECT, op, _paint_help)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	detail_win = XMVWindow.make(self, DETAIL_RECT, op, _paint_detail)
	confirm_win = XMVWindow.make(self, CONFIRM_RECT, op, _paint_confirm)
	gold_win = XMVWindow.make(self, GOLD_RECT, op, _paint_gold)
	popup_win = XMVWindow.make(self, Rect2(580, 328, 120, 64), op, _paint_popup)
	cat_win = XMVWindow.make(self, CAT_RECT, op, _paint_category)
	gauge_win = XMVWindow.make(self, GAUGE_RECT, op, _paint_gauge)
	list_win.canvas.blink = true
	cat_win.canvas.blink = true
	confirm_win.canvas.blink = true
	popup_win.openness = 0
	confirm_win.draw.connect(_clip_confirm)
	_buttons = Control.new()
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.draw.connect(_draw_buttons)
	add_child(_buttons)
	source_card = XHelpCard.new()
	source_card.visible = false
	add_child(source_card)
	_reset_list()
	_refresh()


## 金币窗开合跨过 0 时重画确认窗（挖掉／露出）；窗口本身按金币窗的开合范围截掉（金币窗全开时只剩底下 8px 的边）
func _process(_delta: float) -> void:
	var cover := gold_win.openness > 0
	if cover != _gold_covering:
		_gold_covering = cover
		confirm_win.refresh()
	var band := 0.0
	if cover:
		band = GOLD_RECT.size.y / 2.0 * gold_win.openness / 255.0
	if band != _gold_band:
		_gold_band = band
		confirm_win.queue_redraw()


## Control 每次重画都会重设自己的裁剪矩形，所以在 draw 信号（重设之后）里再套上
func _clip_confirm() -> void:
	if _gold_band <= 0.0:
		return
	# 金币窗以中线 y 680 上下展开；确认窗只留下面露出的部分（展开途中上面露出的一小段也一并截掉）
	var top := GOLD_RECT.position.y + GOLD_RECT.size.y / 2.0 + _gold_band - CONFIRM_RECT.position.y
	var ci := confirm_win.get_canvas_item()
	RenderingServer.canvas_item_set_custom_rect(ci, true, Rect2(0, top, CONFIRM_RECT.size.x, CONFIRM_RECT.size.y - top))
	RenderingServer.canvas_item_set_clip(ci, true)


# ---- 数据 ----
func current() -> Dictionary:
	return list[index] if index >= 0 and index < list.size() else {}


## Window_RecipeList.include／resetRecipes：已知、类别等级够、属于当前类别
func _reset_list() -> void:
	var s := XState.current
	var cat: String = XCrafting.CATEGORIES[cat_index]
	list = XCrafting.recipes().filter(func(r): return XCrafting.known(s, r) and XCrafting.has_craft_level(s, r) and str(r.category) == cat)
	if index >= list.size():
		index = list.size() - 1 if mode != "category" else -1
	top = clampi(top, 0, maxi(0, list.size() - LIST_ROWS))


## 文字操作 ["t", 文字, x, y, 宽, 行高, 对齐, 字号, 颜色, 不透明度]；图标 ["i", 图标号, x, y, 不透明度]
static func _t(text: String, x: float, y: float, w: float, color := XUI.TEXT, align := "left", op := 255, size := XUI.FONT_SIZE) -> Array:
	return ["t", text, x, y, w, LH, align, size, color, op]


static func paint_ops(c: XMVCanvas, ops: Array) -> void:
	for o in ops:
		if o[0] == "i":
			c.icon(int(o[1]), o[2], o[3], o[4] / 255.0)
		else:
			c.text(o[1], o[2], o[3], o[4], o[6], o[8], int(o[7]), o[5], o[9] / 255.0)


## Window_Base.drawItemName（CP_MagicWeapon 包过：法宝在图标上写等级）；width 缺省 312
static func item_name_ops(ops: Array, item: Dictionary, x: float, y: float, op: int, width := NAME_W) -> void:
	ops.append(["i", int(item.get("iconIndex", 0)), x + 2, y + 2, op])
	ops.append(_t(str(item.get("name", "")), x + 36, y, width - 36, XQuality.list_color(item), "left", op))
	var lv = XEquipmentView.level(item)
	if lv is float and lv >= 0.0:
		var p := XDB.plugin("CP_MagicWeapon")
		var size := int(str(p.get("Level Font Size", "16")))
		ops.append(_t(XEnemyBookPage.js_num(lv), x + 16, y - 6, XActorBook.js_width("00", size), XUI.text_color(int(str(p.get("Level Font Color", "12")))), "right", op, size))


static func category_ops() -> Array:
	var ops := []
	for i in XCrafting.CATEGORIES.size():
		var x := i * (CAT_W + CAT_GAP)
		ops.append(_t(XCrafting.CATEGORIES[i], x + 32, 0, CAT_W - 32))
		ops.append(["i", XCrafting.CATEGORY_ICONS[i], x, 2, 255])
	return ops


static func list_row_ops(s: XState, r: Dictionary, y: float) -> Array:
	var ops := []
	var op := 255 if XCrafting.craftable(s, r) else DIM
	item_name_ops(ops, XCrafting.item_of(r.result), 0, y, op)
	var n := XCrafting.amount_craftable(s, r)
	if n > 0:
		ops.append(_t("x" + str(n), 0, y, CW, XUI.TEXT, "right", op))
	return ops


## Window_RecipeDetail.refresh（显示参数缺省：玩家等级、类别等级、金币，不显示成功率）
static func detail_ops(s: XState, r: Dictionary) -> Array:
	var ops := []
	if r.is_empty():
		return ops
	var op := 255 if XCrafting.has_level(s, r) else DIM
	ops.append(_t(REQ_LEVEL, 0, 0, CW, XUI.SYSTEM, "left", op))
	ops.append(_t(str(int(r.level)), 0, 0, CW, XUI.TEXT, "right", op))
	ops.append(["i", XCrafting.PLAYER_LEVEL_ICON, CW - 24 - 32, 0, op])
	ops.append(_t(str(int(r.craftLevel)) + " |", 0, 0, CW - 68, XUI.TEXT, "right", op))
	var cat := XCrafting.category_id(r)
	ops.append(["i", XCrafting.CATEGORY_ICONS[cat] if cat >= 0 else 0, CW - 75 - 68, 0, op])
	var yy := XUI.FONT_SIZE + 20.0
	op = 255 if XCrafting.craftable(s, r) else DIM
	ops.append(_t(REQ_MATERIAL, 0, yy, 640, XUI.SYSTEM, "left", op))
	yy += XUI.FONT_SIZE + 6
	for m in r.materials:
		var have := XCrafting.material_count(s, m, r)
		var enough := have >= int(m.amount)
		op = 255 if enough else DIM
		var it := XCrafting.item_of(m)
		ops.append(["i", int(it.get("iconIndex", 0)), 12, yy, op])
		ops.append(_t(str(it.get("name", "")), 44, yy, 640, XUI.TEXT, "left", op))
		ops.append(_t(str(have), 0, yy, CW - 72, XUI.text_color(3 if enough else 18), "right", op))
		ops.append(_t(" / " + str(int(m.amount)), 0, yy, CW - 12, XUI.TEXT, "right", op))
		yy += XUI.FONT_SIZE + 6
	if int(r.goldCost) > 0:
		op = 255 if XCrafting.has_gold(s, r) else DIM
		var y := DETAIL_CH - XUI.FONT_SIZE * 2
		ops.append(_t(COST_TEXT, 0, y, CW, XUI.SYSTEM, "left", op))
		var unit := str(XDB.system().get("currencyUnit", ""))
		var uw := minf(80.0, XActorBook.js_width(unit, XUI.FONT_SIZE))
		ops.append(_t(str(int(r.goldCost)), 0, y, CW - uw - 6, XUI.TEXT, "right", op))
		ops.append(_t(unit, CW - uw, y, uw, XUI.SYSTEM, "right", op))
	return ops


static func gauge_ops(s: XState, cat: int) -> Array:
	var lv := XCrafting.craft_level(s, cat)
	var ops := [["i", XCrafting.CATEGORY_ICONS[cat], 0, 0, 255], _t(str(lv), 32, 0, CW)]
	if lv == XCrafting.MAX_LEVEL:
		ops.append(_t(MAX_LEVEL_TEXT, 0, 0, CW, XUI.text_color(20), "right"))
	else:
		ops.append(_t("%d/%d" % [XCrafting.craft_exp(s, cat), XCrafting.exp_next(s, cat)], 0, 0, CW, XUI.TEXT, "right"))
	return ops


func confirm_ops() -> Array:
	var ops := [_t(CRAFT_TEXT, 0, 0, CW, XUI.TEXT, "center")]
	var r := current()
	if not r.is_empty() and XCrafting.craftable(XState.current, r):
		ops.append(_t("x" + str(amount), 0, 0, CW, XUI.TEXT, "right"))
	return ops


# ---- 绘制 ----
## 锻造配方：选原件时为光标处的一件，否则为已选好的（XGrowthForge.forge_source）
func forge_shown() -> Dictionary:
	if mode == "pick":
		return picks[pick_index] if pick_index >= 0 and pick_index < picks.size() else {}
	return XGrowthForge.forge_source


static func pick_row_ops(s: XState, id: int, item: Dictionary, y: float) -> Array:
	var op := 255 if XGrowthForge.can_forge(s, id, item) else DIM
	return [["i", int(item.get("iconIndex", 0)), 2, y + 2, op], _t(str(item.get("name", "")), 36, y, CW - 36, XQuality.list_color(item), "left", op, 22),
		_t(XGrowthForge.source_row(s, id, item), 0, y + 32, CW, XUI.TEXT, "left", op, 18)]


## forgeDetailLines：详情窗 y 224 起，18 号字、行距 25
static func forge_detail_ops(id: int, source) -> Array:
	var ops := []
	var y := 224.0
	for text in XGrowthForge.detail_lines(id, source):
		ops.append(_t(text, 0, y, CW, XUI.TEXT, "left", 255, 18))
		y += 25
	return ops


func _paint_help(c: XMVCanvas) -> void:
	var r := current()
	if r.is_empty() or mode == "category":
		return
	var text := str(XCrafting.item_of(r.result).get("description", ""))
	if XGrowthForge.is_forge_recipe(int(r.id)):
		text = XGrowthForge.help_text(int(r.id), forge_shown(), mode == "pick", source_shown)
	var t := XMVText.new(XMVText.convert_escapes(text), 6, 0, c.size.x - 12)
	t.run()
	XMVText.paint(c, t.glyphs)


func _paint_category(c: XMVCanvas) -> void:
	c.cursor(Rect2(cat_index * (CAT_W + CAT_GAP), 0, CAT_W, LH), mode == "category")
	paint_ops(c, category_ops())


func _paint_list(c: XMVCanvas) -> void:
	var s := XState.current
	if mode == "pick":
		if pick_index >= pick_top and pick_index < pick_top + PICK_ROWS:
			c.cursor(Rect2(0, (pick_index - pick_top) * PICK_H, c.size.x, PICK_H), true)
		for i in range(pick_top, mini(pick_top + PICK_ROWS, picks.size())):
			paint_ops(c, pick_row_ops(s, int(current().id), picks[i], (i - pick_top) * PICK_H))
		return
	if index >= top and index < top + LIST_ROWS:
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "list")
	for i in range(top, mini(top + LIST_ROWS, list.size())):
		paint_ops(c, list_row_ops(s, list[i], (i - top) * LH))


func _paint_detail(c: XMVCanvas) -> void:
	var r := current()
	paint_ops(c, detail_ops(XState.current, r))
	if not r.is_empty() and XGrowthForge.is_forge_recipe(int(r.id)):
		paint_ops(c, forge_detail_ops(int(r.id), forge_shown()))


func _paint_confirm(c: XMVCanvas) -> void:
	if gold_win.openness > 0:
		return
	if mode == "confirm":
		c.cursor(Rect2(0, 0, c.size.x, LH), true)
	paint_ops(c, confirm_ops())


## 原版金币窗内容层按 Window_Gold 初始宽 240 建好（内容宽 212）后没重建：金额 (6, 宽 164) 靠右、图标在 174
func _paint_gold(c: XMVCanvas) -> void:
	var ww := 240.0 - 28 - 12
	c.text(XMenu.currency_text(c, XState.current.gold, ww - 32), 6, 0, ww - 32 - 4, "right", XUI.TEXT, 20, LH)
	c.icon(GOLD_ICON, 6 + ww - 32, 2)


func _paint_gauge(c: XMVCanvas) -> void:
	var s := XState.current
	var lv := XCrafting.craft_level(s, cat_index)
	if lv != XCrafting.MAX_LEVEL:
		var g: Array = XUI.GAUGES.tp
		c.gauge(96, -3, CW - 96, float(XCrafting.craft_exp(s, cat_index)) / XCrafting.exp_next(s, cat_index), g[0], g[1])
	paint_ops(c, gauge_ops(s, cat_index))


func _paint_popup(c: XMVCanvas) -> void:
	if popup_icon >= 0:
		c.icon(popup_icon, 0, 0)
		c.text(popup_text, 32, 0, c.size.x - 32)
	else:
		c.text(popup_text, 0, 0, c.size.x)


func _refresh() -> void:
	var r := current()
	# Scene_Crafting.update：当前配方可做时确认窗不透明 255，否则 75（没有当前配方时保持）
	if not r.is_empty():
		var a := 255 if XCrafting.craftable(XState.current, r) else 75
		confirm_win.opacity = a
		confirm_win.canvas.modulate.a = a / 255.0
	list_win.up_arrow = pick_top > 0 if mode == "pick" else top > 0
	list_win.down_arrow = pick_top + PICK_ROWS < picks.size() if mode == "pick" else top + LIST_ROWS < list.size()
	_sync_source()
	for w in [help_win, cat_win, list_win, detail_win, confirm_win, gold_win, gauge_win, popup_win]:
		w.refresh()
	_buttons.queue_redraw()


## _codexShowSourceHelp／_codexCloseSourceHelp：选原件且按过 Shift 时，详情窗位置显示光标下那件原件的说明卡，详情窗藏起。
## 原版先把 descParams 字号压到 14 再 setItem，但原件都是成长装备，setItem 包装走 helpView 重算 getDescParams，
## 压的字号被冲掉（installNativeHubrisRuntime.js:175、HelpExtend.js:150），实际按原字号显示，这里照原版不压
func _sync_source() -> void:
	source_shown = source_shown and mode == "pick" and not forge_shown().is_empty()
	if source_shown:
		source_card.show_for(forge_shown(), "armor", false)
		source_card.position = DETAIL_RECT.position
	source_card.visible = source_shown
	detail_win.visible = not source_shown


## placeButtons：五个按钮总宽 352（含间隔），在详情窗内居中；y 在确认窗上方 2.5 行
static func button_rects() -> Array:
	var total := -16.0
	for b in BUTTON_SRC:
		total += b.size.x + 16
	var x := DETAIL_RECT.position.x + (DETAIL_RECT.size.x - total) / 2.0
	var y := CONFIRM_RECT.position.y - LH * 2.5
	var out := []
	for b in BUTTON_SRC:
		out.append(Rect2(x, y, b.size.x, b.size.y))
		x += b.size.x + 16
	return out


func _draw_buttons() -> void:
	if not buttons_visible:
		return
	var tex: Texture2D = XMessageBox._button_texture()
	if tex == null:
		return
	var rects := button_rects()
	for i in BUTTON_SRC.size():
		var src: Rect2 = BUTTON_SRC[i]
		if i == _button_down:
			src.position.y += 48
		_buttons.draw_texture_rect_region(tex, rects[i], src)


func _button_at(p: Vector2) -> int:
	if not buttons_visible:
		return -1
	var rects := button_rects()
	for i in rects.size():
		if rects[i].has_point(p):
			return i
	return -1


## 按钮点击：前四个改确认窗数量（原版绑在确认窗上，弹窗时也能点），确定键见 onButtonOk
func press_button(i: int) -> void:
	if i < 4:
		change_amount(BUTTON_STEPS[i])
	elif mode == "popup":
		amount = mini(1, XCrafting.amount_craftable(XState.current, current()))
		_popup_ok()
	elif mode == "confirm":
		XSound.system(1)
		craft()


# ---- 操作 ----
func select_category(i: int) -> void:
	if i == cat_index:
		return
	cat_index = i
	XSound.system(0)
	_reset_list()
	_refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	top = XMenu._scroll_to(index, top, LIST_ROWS)
	_refresh()


## Window_RecipeConfirm.changeAmount：在 1 与可做数之间
func change_amount(d: int) -> void:
	var r := current()
	if r.is_empty() or not bool(r.get("craftMultiple", true)):
		return
	XSound.system(0)
	amount = mini(maxi(amount + d, 1), XCrafting.amount_craftable(XState.current, r))
	_refresh()


## Scene_Crafting.craftSuccess：按数量逐件制作（每件抽 Math.random()×100 比成功率），有成功就弹「N x 名字 制作成功!」
func craft() -> void:
	var s := XState.current
	var r := current()
	var forged := {}
	if not r.is_empty() and XGrowthForge.is_forge_recipe(int(r.id)):
		amount = 1
		forged = XCrafting.craft(s, r)
		XGrowthForge.forge_source = {}
		if forged.is_empty():
			# craftSuccess：锻造不成蜂鸣、按取消确认回列表
			XSound.system(3)
			mode = "confirm"
			cancel()
			return
	var made := 0
	var item := {}
	for i in amount:
		var got := forged if XGrowthForge.is_forge_recipe(int(r.id)) else XCrafting.craft(s, r)
		if not got.is_empty():
			made += 1
			item = got
	if not item.is_empty():
		XSound.play("Item3", 90)
		popup_text = "%dx %s %s" % [made, str(item.get("name", "")), CRAFTED_TEXT]
		popup_icon = int(item.get("iconIndex", 0))
		var w := XActorBook.js_width(popup_text, XUI.FONT_SIZE) + 32
		popup_win.size.x = w + 28
		popup_win.position.x = (1280 - w) / 2.0
	else:
		XSound.play("Buzzer2", 90)
		popup_text = FAILED_TEXT
		popup_icon = -1
		var w := XActorBook.js_width(popup_text, XUI.FONT_SIZE)
		popup_win.size.x = w + 28
		popup_win.position.x = (1280 - w) / 2.0
	amount = mini(1, XCrafting.amount_craftable(s, r))
	_reset_list()
	mode = "popup"
	popup_win.open()
	_refresh()


func ok() -> void:
	match mode:
		"category":
			# commandOk：列表选第 0 项并激活
			XSound.system(1)
			mode = "list"
			index = 0 if not list.is_empty() else -1
			top = 0
			amount = 1
		"list":
			var r := current()
			if r.is_empty() or not XCrafting.craftable(XState.current, r):
				XSound.system(3)
				return
			XSound.system(1)
			if XGrowthForge.is_forge_recipe(int(r.id)):
				# listSuccess 改写：先选原件
				XGrowthForge.forge_source = {}
				picks = XGrowthForge.forge_sources(XState.current, int(r.id))
				pick_index = 0
				pick_top = 0
				mode = "pick"
				_refresh()
				return
			_enter_confirm()
		"pick":
			var src := forge_shown()
			if not XGrowthForge.can_forge(XState.current, int(current().id), src):
				XSound.system(3)
				return
			XSound.system(1)
			source_shown = false
			XGrowthForge.forge_source = src
			_enter_confirm()
		"confirm":
			XSound.system(1)
			craft()
			return
		"popup":
			_popup_ok()
			return
	_refresh()


func _enter_confirm() -> void:
	mode = "confirm"
	amount = 1
	gold_win.close()
	buttons_visible = true


## popupOk：关弹窗回列表（金币窗不重开）
func _popup_ok() -> void:
	popup_win.close()
	buttons_visible = false
	mode = "list"
	_refresh()


func cancel() -> void:
	match mode:
		"category":
			XSound.system(2)
			closed.emit()
			return
		"list":
			# Scene_Crafting.cancel：列表取消选择、帮助清空，回类别
			XSound.system(2)
			mode = "category"
			index = -1
		"pick":
			XSound.system(2)
			if source_shown:  # 原件说明卡开着：先收起，留在选原件
				source_shown = false
			else:
				XGrowthForge.forge_source = {}
				mode = "list"
		"confirm":
			XSound.system(2)
			XGrowthForge.forge_source = {}  # confirmCancel 改写：清掉选好的原件
			mode = "list"
			gold_win.open()
			buttons_visible = false
		"popup":
			_popup_ok()
			return
	_refresh()


func _move(d: int, wrap: bool) -> void:
	match mode:
		"list":
			if not list.is_empty():
				select(XMenu._move(index, d, list.size(), wrap))
		"pick":
			if not picks.is_empty():
				var i := XMenu._move(pick_index, d, picks.size(), wrap)
				if i != pick_index:
					pick_index = i
					XSound.system(0)
					pick_top = XMenu._scroll_to(pick_index, pick_top, PICK_ROWS)
					_refresh()
		"confirm":
			change_amount(-10 if d > 0 else 10)


func _side(d: int) -> void:
	match mode:
		"category":
			select_category(posmod(cat_index + d, XCrafting.CATEGORIES.size()))
		"confirm":
			change_amount(d)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _button_down >= 0 and not event.pressed:
		var i := _button_down
		_button_down = -1
		_buttons.queue_redraw()
		if _button_at(event.position) == i:
			press_button(i)
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	if event.button_index == MOUSE_BUTTON_LEFT and _button_at(p) >= 0:
		_button_down = _button_at(p)
		_buttons.queue_redraw()
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "list" and LIST_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, list.size() - LIST_ROWS))
				_refresh()
		MOUSE_BUTTON_LEFT:
			if mode == "popup":
				ok()
			elif mode == "category" and CAT_RECT.has_point(p):
				var i := floori((p.x - CAT_RECT.position.x - XMVWindow.PADDING) / (CAT_W + CAT_GAP))
				if i >= 0 and i < XCrafting.CATEGORIES.size():
					if i == cat_index:
						ok()
					else:
						select_category(i)
			elif mode == "list" and LIST_RECT.has_point(p):
				var i := top + floori((p.y - LIST_RECT.position.y - XMVWindow.PADDING) / LH)
				if i >= top and i < mini(top + LIST_ROWS, list.size()):
					if i == index:
						ok()
					else:
						select(i)
			elif mode == "pick" and LIST_RECT.has_point(p):
				var i := pick_top + floori((p.y - LIST_RECT.position.y - XMVWindow.PADDING) / PICK_H)
				if i >= pick_top and i < mini(pick_top + PICK_ROWS, picks.size()):
					if i == pick_index:
						ok()
					else:
						pick_index = i
						XSound.system(0)
						_refresh()
			elif mode == "confirm" and CONFIRM_RECT.has_point(p):
				ok()


## 选原件时 Shift：开／收原件说明卡（Input.isTriggered('shift')）
func toggle_source() -> void:
	if mode == "pick":
		source_shown = not source_shown
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT and mode == "pick":
		get_viewport().set_input_as_handled()
		toggle_source()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_side(1 if event.is_action_pressed("ui_right", true) else -1)
