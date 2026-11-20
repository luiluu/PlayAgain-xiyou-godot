class_name XTrainingScene
extends Control
## 修炼（Star_ActorAttributePlusPoints 的 Scene_ActorAttributePlusPoints；魔塔教师、二十六层小萝莉等事件 SceneManager.push）。数据在 XTraining。
## 版面与逐条绘制按冻结 v0.28 浏览器参照（tests/fixtures/training_ui_oracle.json）；窗口不透明度照 MOG 菜单 30：
## - 队员目录 (0,0,426,720)：$gameParty.members() 的名字，光标一直显示（目录不活动时不闪）。
## - 状态窗 (426,0,854,720)，内容宽 826：SV 图以窗口内 (103.25, 103.25) 为中心（0-1-2-1 每 12 帧）；名字、「等级:N」在 x 140，
##   八项能力值「生命 485」照原版的三列 280／462／630 与三行（敏捷、幸运在第三列，第一行第三列空着）。
## - 精魂窗 (0,656,426,64)：图标 272，「数值＋精魂」在 x 34.67。
## - 底部「修炼」窗 (426.67,656,854,64)：一行（原版用 44 个空格把「修炼」推到中间），目录确定后才可选。
##   本工程字体的空格比原版窄，「修炼」按原版实测的空格宽（SPACE_W）定横坐标（ui_reference review_system_pages 的 training 读数）。
## - 修炼项窗 (426.67,136,854,388)：一直显示，XTraining.lines 的行文；「修炼」确定后才可选，修炼后留在本窗。
## 流程：目录确定 → 底部「修炼」→ 修炼项确定（XTraining.confirm，提示照原版 $.toaster）；修炼项取消回底部，底部取消回目录，目录取消关闭。
## 优化 O-082（ALIGN_COST，可回退）：原版用空格补齐「下一级费用」，中文字宽不同，各行对不齐（参照截图里差 3～20 像素）；
## 这里把「下一级费用…」画在同一列（各行左半段最宽者之后），文字不变。设 false 恢复原版的空格排法。
## 【cc·T307 卡 O·未经审查】天启篇新界面（XUiSkin.on() 且 XSkinRosterPage.ENABLED）：版型二名单页（XSkinRosterPage），旧窗藏起：
## - 左名单＝队员目录；中间列表＝修炼项（名字、小字「每级 +N」、「第 N 级」、行尾下一级费用；修满的变灰写「修满了」，数取自 XTraining 同一份表）；
## - 右牌：这次修炼会变的那一项「89 → 92 ▲3」、下一级费用、主按钮「修炼」；八项全表收起（T254 5AB-5 推荐默认），Y 或点牌底「展开八项 ▾」展开；
## - 目录确定直接进列表（少一层底部「修炼」窗：mode 从 index 直接到 list），列表确定就修，取消回目录；精魂窗进右上货币；提示照旧走 XToast。

signal closed

const INDEX_RECT := Rect2(0, 0, 426, 720)
const STATUS_RECT := Rect2(426, 0, 854, 720)
const GOLD_RECT := Rect2(0, 656, 426, 64)
const BOTTOM_RECT := Rect2(1280.0 / 3.0, 656, 854, 64)
const LIST_RECT := Rect2(1280.0 / 3.0, 136, 854, 388)
const LH := 36.0
const CW := 826.0
const COL2 := CW / 2.0 + 7.0              # 420
const COLW := CW / 2.0 - 14.0             # 399
const INDEX_ROWS := 19                    # floor((720 − 28) / 36)
const LIST_ROWS := 10                     # fittingHeight(10)
const SPRITE_CENTER := Vector2(CW / 8.0, CW / 8.0)
const ATTR := ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"]
## drawAllContents 的八项：[能力编号, x, 行]
const ATTR_CELLS := [[0, COL2 / 3.0 * 2.0, 0], [1, COL2 / 10.0 * 11.0, 0], [2, COL2 / 3.0 * 2.0, 1], [3, COL2 / 10.0 * 11.0, 1],
	[6, COL2 / 10.0 * 15.0, 1], [4, COL2 / 3.0 * 2.0, 2], [5, COL2 / 10.0 * 11.0, 2], [7, COL2 / 10.0 * 15.0, 2]]
const BOTTOM_TEXT := "                                            修炼"
## 原版 CodexUserUI 26 号下 44 个空格实测宽 317.28125（training_bottom 读数），即每个空格 7.2109375
const SPACE_W := 317.28125 / 44.0
const GOLD_ICON := 272
const COST_MARK := "下一级费用"

static var ALIGN_COST := true

var mode := "index"          # index / bottom / list
var index := 0
var top := 0
var cmd := -1                # 底部「修炼」窗的选择（-1 不选）
var row := -1                # 修炼项窗的选择
var index_win: XMVWindow
var index_pager: XListPager   # T050 翻页件（新界面关着时为 null）
var status_win: XMVWindow
var gold_win: XMVWindow
var bottom_win: XMVWindow
var list_win: XMVWindow
var _status_ops: Array = []
var _sprite_tex: Texture2D
var _frame := 0
var skin: XSkinRosterPage      # T307 新界面（关着为 null）
var skin_row := 0              # 新界面：目录上时右牌说的是哪一项（进列表时光标落这里）
var skin_open := false         # 右牌八项展开着


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	index_win = XMVWindow.make(self, INDEX_RECT, op, _paint_index)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	gold_win = XMVWindow.make(self, GOLD_RECT, op, _paint_gold)
	bottom_win = XMVWindow.make(self, BOTTOM_RECT, op, _paint_bottom)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	for w in [index_win, bottom_win, list_win]:
		w.canvas.blink = true
	index_pager = XListPager.attach(index_win, page)
	if index_pager != null:   # 精魂窗（GOLD_RECT）盖在目录窗底部 64px，翻页件摆在它上面
		index_pager.position.y = GOLD_RECT.position.y - XListPager.DEFAULT_SIZE.y - 2.0
	if XUiSkin.on() and XSkinRosterPage.ENABLED:
		_skin_build()
	_select_actor()


func _process(_delta: float) -> void:
	_frame += 1
	if _sprite_tex != null and _frame % 12 == 0:
		status_win.canvas.queue_redraw()


# ---- 数据 ----
func members() -> Array:
	return XState.current.members()


func current() -> XActor:
	var l := members()
	return l[index] if index >= 0 and index < l.size() else null


static func _t(text: String, x: float, y: float, w: float, color := XUI.TEXT) -> Array:
	return ["t", text, x, y, w, LH, "left", XUI.FONT_SIZE, color]


## Window_ActorAttributePlusPointsIndex.drawItem
static func index_ops(s: XState) -> Array:
	var ops := []
	var l := s.members()
	for i in l.size():
		ops.append(_t((l[i] as XActor).display_name(), 6, i * LH, INDEX_RECT.size.x - 28.0 - 12.0))  # itemRectForText：398 − 12
	return ops


## Window_ActorAttributePlusPointsStatus.drawAllContents
static func status_ops(a: XActor) -> Array:
	var ops := []
	if a == null:
		return ops
	ops.append(_t(a.display_name(), COL2 / 3.0, 0, COLW))
	for cell in ATTR_CELLS:
		ops.append(_t("%s %d" % [ATTR[cell[0]], int(a.param(cell[0]))], cell[1], LH * cell[2], COLW))
	ops.append(_t("等级:" + str(a.level), COL2 / 3.0, LH, COLW))
	return ops


## Window_ActorAttributePlusPointsGold.drawCurrencyValue：先画「数值＋单位」（单位宽 2/3 处），再在 0 画图标
static func gold_ops(s: XState) -> Array:
	var unit := str(XDB.system().get("currencyUnit", ""))
	var unit_w := minf(80.0, XActorBook.js_width(unit, XUI.FONT_SIZE))
	var col_w := (GOLD_RECT.size.x - 28.0) / 2.0 - 14.0
	return [_t(str(s.gold) + unit, unit_w * 2.0 / 3.0, 0, col_w * 2.0 - unit_w - 6.0), ["i", GOLD_ICON, 0.0, 0.0]]


static func bottom_ops() -> Array:
	return [_t(BOTTOM_TEXT, 6, 0, CW - 12.0)]


## Window_AddLittleConfirm：每行一项（行文见 XTraining.line）；ALIGN_COST 时「下一级费用…」另起一段画在同一列
static func list_ops(s: XState, actor_id: int) -> Array:
	var lines := XTraining.lines(s, actor_id)
	var ops := []
	if not ALIGN_COST:
		for i in lines.size():
			ops.append(_t(lines[i], 6, i * LH, CW - 12.0))
		return ops
	var col := 0.0
	var heads := []
	for l in lines:
		var at := str(l).find(COST_MARK)
		var head := str(l).substr(0, at).strip_edges(false, true) if at >= 0 else str(l)
		heads.append(head)
		if at >= 0:
			col = maxf(col, XActorBook.js_width(head, XUI.FONT_SIZE))
	col = ceilf(col + XActorBook.js_width("    ", XUI.FONT_SIZE))
	for i in lines.size():
		var l := str(lines[i])
		var at := l.find(COST_MARK)
		ops.append(_t(heads[i], 6, i * LH, CW - 12.0))
		if at >= 0:
			ops.append(_t(l.substr(at), 6 + col, i * LH, CW - 12.0 - col))
	return ops


# ---- 绘制 ----
static func _paint_ops(c: XMVCanvas, ops: Array) -> void:
	for o in ops:
		if o[0] == "i":
			c.icon(int(o[1]), o[2], o[3])
		else:
			c.text(o[1], o[2], o[3], o[4], o[6], o[8], int(o[7]), o[5])


func _paint_index(c: XMVCanvas) -> void:
	var n := members().size()
	if index >= top and index < top + index_rows() and n > 0:
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "index")
	var ops := index_ops(XState.current)
	for i in range(top, mini(top + index_rows(), ops.size())):
		var o: Array = ops[i].duplicate()
		o[3] = (i - top) * LH
		_paint_ops(c, [o])


func _paint_status(c: XMVCanvas) -> void:
	if _sprite_tex != null:
		var center := SPRITE_CENTER - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
		var cw := _sprite_tex.get_width() / 9.0
		var ch := _sprite_tex.get_height() / 6.0
		var src := Rect2([0, 1, 2, 1][floori(_frame / 12.0) % 4] * cw, 0, cw, ch)
		var scale := 1.0
		if cw > CW / 2.0:
			scale = CW / cw / 2.0
		var sz := src.size * scale
		c.draw_texture_rect_region(_sprite_tex, Rect2(center - sz / 2.0, sz), src)
	_paint_ops(c, _status_ops)


func _paint_gold(c: XMVCanvas) -> void:
	_paint_ops(c, gold_ops(XState.current))


func _paint_bottom(c: XMVCanvas) -> void:
	if cmd == 0:
		c.cursor(Rect2(0, 0, c.size.x, LH), mode == "bottom")
	# 行首空格按原版空格宽折成横坐标，免得「修炼」随本工程字体的空格宽偏左
	for o in bottom_ops():
		var word := str(o[1]).strip_edges(true, false)
		var pad := (str(o[1]).length() - word.length()) * SPACE_W
		c.text(word, o[2] + pad, o[3], o[4] - pad, o[6], o[8], int(o[7]), o[5])


func _paint_list(c: XMVCanvas) -> void:
	var a := current()
	if a == null:
		return
	if row >= 0 and row < LIST_ROWS:
		c.cursor(Rect2(0, row * LH, c.size.x, LH), mode == "list")
	_paint_ops(c, list_ops(XState.current, a.actor_id))


# ---- 操作 ----
## Scene_ActorAttributePlusPoints.update：目录选中项变了刷新状态窗、精魂窗与修炼项
func _select_actor() -> void:
	var a := current()
	_status_ops = status_ops(a)
	_sprite_tex = null
	if a != null:
		var p := XDB.img_path("sv_actors", str(a.data().get("battlerName", "")))
		_sprite_tex = load(p) if p != "" else null
	_refresh()


## T050：目录窗底部 64px 被精魂窗盖住，原版 19 行里实际露出 17 行；新界面开着且队员超 17 个时只放 16 行，
## 翻页件摆在精魂窗之上（不超 17 个或西游档：行数不变）。修炼项窗（LIST_ROWS）一屏放全、不滚动，不挂。
func index_rows() -> int:
	return 16 if XUiSkin.on() and members().size() > 17 else INDEX_ROWS


func _refresh() -> void:
	index_win.up_arrow = top > 0
	index_win.down_arrow = top + index_rows() < members().size()
	if index_pager != null:   # 有翻页件时它自己画页码，底边的下箭头不要
		index_pager.set_state(top, index_rows(), members().size())
		index_win.down_arrow = index_win.down_arrow and not index_pager.visible
	for w in [index_win, status_win, gold_win, bottom_win, list_win]:
		w.refresh()
	if skin != null:
		_skin_sync()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	top = XMenu._scroll_to(index, top, index_rows())
	_select_actor()


func ok() -> void:
	match mode:
		"index":
			if members().is_empty():
				return
			XSound.system(1)  # onRangeOk → startBottomConfirmWindow
			if skin != null:   # T307：新界面没有底部「修炼」窗，目录确定直接进修炼项列表
				mode = "list"
				row = clampi(skin_row, 0, maxi(XTraining.listed().size() - 1, 0))
				_refresh()
				return
			mode = "bottom"
			cmd = 0
		"bottom":
			XSound.system(1)  # onBottomConfirmOk → startConfirmWindow
			mode = "list"
			cmd = -1
			row = 0
		"list":
			var a := current()
			var listed := XTraining.listed()
			if a == null or row < 0 or row >= listed.size():
				return
			XSound.system(1)
			var text := XTraining.confirm(XState.current, a.actor_id, int(listed[row].id))
			if text != "":
				XToast.show_text(text, true)
			_select_actor()
			return
	_refresh()


func cancel() -> void:
	XSound.system(2)
	match mode:
		"index":
			closed.emit()
			return
		"bottom":
			mode = "index"  # onBottomConfirmCancel
			cmd = -1
		"list":
			if skin != null:   # T307：取消直接回目录，右牌仍说这一项
				skin_row = maxi(row, 0)
				mode = "index"
				row = -1
				_refresh()
				return
			mode = "bottom"  # onConfirmCancel
			row = -1
			cmd = 0
	_refresh()


func _move(d: int, wrap: bool) -> void:
	match mode:
		"index":
			if not members().is_empty():
				select(XMenu._move(index, d, members().size(), wrap))
		"list":
			var n := XTraining.listed().size()
			if n > 0:
				row = XMenu._move(row, d, n, wrap)
				XSound.system(0)
				_refresh()


func _gui_input(event: InputEvent) -> void:
	if skin != null:   # 新界面的点击由各组件自己接；右键＝取消
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			cancel()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	elif mode == "index" and XMenu.wheel_dir(event) != 0 and INDEX_RECT.has_point(event.position):
		# Window_Selectable.processWheel：目录只滚窗口、光标不动（ui11）
		top = XMenu.wheel(top, members().size(), index_rows(), XMenu.wheel_dir(event))
		_refresh()


## 队员目录是 Window_Selectable、不接管 pageup／pagedown：照 cursorPagedown／cursorPageup 整页翻（ui11）
func page(d: int) -> void:
	var r := XMenu.page(top, index, members().size(), index_rows(), d)
	top = r[0]
	if r[1] != index:
		index = r[1]
		XSound.system(0)
		_select_actor()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if skin != null and skin.input(event):
		XKeyMap.handled(self)
		return
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif mode == "index" and XMenu.page_dir(event) != 0:
		XKeyMap.handled(self)
		page(XMenu.page_dir(event))


# ---- T307 卡 O：天启篇新界面（版型二名单页）----
## 玩家可见新字（待小A 审）
const T_TITLE := "修炼场"
const T_LIST := "修炼项"
const T_FULL := "修满了"
const T_PER := "每级 +%s"
const T_LV := "第 %d 级"
const T_CHANGE := "这次修炼"
const T_COST := "下一级费用"
const T_ALL := "八项能力"
const T_OPEN := "展开八项"
const T_CLOSE := "收起八项"


func _skin_build() -> void:
	skin = XSkinRosterPage.new()
	skin.title = T_TITLE
	add_child(skin)
	skin.list.right2_w = 128.0
	skin.roster_changed.connect(func(i):
		if mode == "list":   # 列表上点名单＝回目录换人
			skin_row = maxi(row, 0)
			mode = "index"
			row = -1
		select(i)
		_refresh())
	skin.roster_activated.connect(func(i):
		if i == index and mode == "index":
			ok())
	skin.list.index_changed.connect(func(i):
		if _skin_syncing:
			return
		if mode == "index":   # 目录上点修炼项＝进列表选这一项
			mode = "list"
		if i != row:
			XSound.system(0)
			row = i
		_refresh())
	skin.list.activated.connect(func(i):
		if mode == "list" and i == row:
			ok())
	skin.card_button.connect(func(_i): _skin_train())
	skin.strip_toggled.connect(func(on):
		skin_open = on
		_refresh())


var _skin_syncing := false


## 主按钮「修炼」（触屏）：练右牌上那一项
func _skin_train() -> void:
	if mode == "index":
		if members().is_empty():
			return
		mode = "list"
		row = clampi(skin_row, 0, maxi(XTraining.listed().size() - 1, 0))
	ok()


## 右牌说的是哪一项
func skin_item() -> int:
	return row if mode == "list" and row >= 0 else skin_row


## 一行修炼项（测试按 T254 3.11 对应表核：数与 XTraining.line 同一份）：{text, sub 每级 +N, right 第 N 级, right2 行尾下一级费用／修满了}
static func skin_row_of(s: XState, actor_id: int, e: Dictionary) -> Dictionary:
	var lv := XTraining.level(s, actor_id, int(e.id))
	var mx := int(e.max)
	var it := {"text": str(e.name), "sub": T_PER % per_level(s, e), "right": T_LV % lv, "right_color": XUiSkin.TEXT_2}
	if lv >= mx:
		it.right2 = T_FULL
		it.disabled = true
		return it
	var cost := next_cost(s, actor_id, e)
	if cost < 0:   # 天启篇：本层没开到下一级
		it.right2 = "本层开到 %d 级" % XTianqiMoney.training_open(s)
		it.right2_color = XUiSkin.DOWN
		return it
	it.right2 = XTraining._wan(cost) + "万"
	it.right2_color = XUiSkin.GOLD_LIGHT if s.gold >= cost else XUiSkin.DOWN
	return it


## 每级加多少：旧表「增加X N」的 N；天启篇「全队X+N%」的 N%
static func per_level(s: XState, e: Dictionary) -> String:
	if e.get("tianqi", false):
		return "%d%%" % roundi(float(XTianqiMoney.data().get("training", {}).get("pct_per_level", 0.01)) * 100.0)
	return str(int(e.value))


## 下一级费用；满了或本层没开到返回 -1
static func next_cost(s: XState, actor_id: int, e: Dictionary) -> int:
	var lv := XTraining.level(s, actor_id, int(e.id))
	if lv >= int(e.max):
		return -1
	if e.get("tianqi", false):
		return XTianqiMoney.training_price(s, lv + 1) if lv < XTianqiMoney.training_open(s) else -1
	return int(e.gold)


## 这次修炼会变的那一项：[现在, 练完]（临时把等级加 1 读能力值再还原；不在战斗里，能力值不走缓存）。满了／没开到返回 []
static func preview(s: XState, a: XActor, e: Dictionary) -> Array:
	if a == null or next_cost(s, a.actor_id, e) < 0:
		return []
	var p := int(e.param)
	var now := int(a.param(p))
	var lv := XTraining.level(s, a.actor_id, int(e.id))
	if e.get("tianqi", false):
		# 小A核 P3：只读——money 节原来没有就临时建、读完连节一起删（不在存档里留下空节）
		var tq = s.flags.get("tianqi", null)
		var had_sec: bool = tq is Dictionary and (tq as Dictionary).has("money")
		var m := XTianqiMoney.money(s)
		var had := m.has("training")
		if not had:
			m["training"] = {}
		var t: Dictionary = m.training
		var key := str(int(e.id))
		var old = t.get(key, null)
		t[key] = lv + 1
		var after := int(a.param(p))
		if old == null:
			t.erase(key)
		else:
			t[key] = old
		if not had:
			m.erase("training")
		if not had_sec and tq is Dictionary:
			(tq as Dictionary).erase("money")
		return [now, after]
	var ak := str(a.actor_id)
	var had_a := s.training.has(ak)
	var mine: Dictionary = s.training.get(ak, {})
	var k2 := str(int(e.id))
	var old2 = mine.get(k2, null)
	mine[k2] = lv + 1
	s.training[ak] = mine
	var after2 := int(a.param(p))
	if old2 == null:
		mine.erase(k2)
	else:
		mine[k2] = old2
	if not had_a:
		s.training.erase(ak)
	return [now, after2]


func skin_card() -> Dictionary:
	var a := current()
	var s := XState.current
	var listed := XTraining.listed()
	var i := clampi(skin_item(), 0, maxi(listed.size() - 1, 0))
	if a == null or listed.is_empty():
		return {"title": "", "sections": [], "buttons": []}
	var e: Dictionary = listed[i]
	var lv := XTraining.level(s, a.actor_id, int(e.id))
	var pname: String = XTraining.PARAM_NAMES[int(e.param)]
	var d := {"title": str(e.name), "subtitle": "%s · 修炼 %d / %d 级" % [a.display_name(), lv, int(e.max)], "sections": [], "buttons": []}
	var secs := []
	var pv := preview(s, a, e)
	var cost := next_cost(s, a.actor_id, e)
	if lv >= int(e.max):
		secs.append({"title": T_CHANGE, "rows": [{"text": T_FULL, "color": XUiSkin.TEXT_3}]})
	elif cost < 0:
		secs.append({"title": T_CHANGE, "rows": [{"text": "本层只开放到 %d 级（每 %d 层开 1 级）" % [XTianqiMoney.training_open(s), int(XTianqiMoney.data().get("training", {}).get("floors_per_level", 3))], "color": XUiSkin.DOWN}]})
	else:
		var dv := int(pv[1]) - int(pv[0])
		var lines := [{"left": pname, "right": "%s → %s %s%d" % [XMenu._group(int(pv[0])), XMenu._group(int(pv[1])), "▲" if dv >= 0 else "▼", absi(dv)], "color": XUiSkin.TEXT, "right_color": XUiSkin.UP if dv > 0 else XUiSkin.TEXT_2},
			{"left": T_COST, "right": XTraining._wan(cost) + "万 " + str(XDB.system().get("currencyUnit", "")), "color": XUiSkin.TEXT_2, "right_color": XUiSkin.GOLD_LIGHT if s.gold >= cost else XUiSkin.DOWN}]
		secs.append({"title": T_CHANGE, "lines": lines})
		if e.get("tianqi", false):
			secs.append({"title": "", "rows": [{"text": "全队%s +%s" % [pname, per_level(s, e)], "color": XUiSkin.TEXT_2}]})
	if skin_open:
		var cells := []
		for k in 8:
			cells.append([ATTR[k], XMenu._group(int(a.param(k)))])
		secs.append({"title": T_ALL, "cells": cells})
	d.sections = secs
	d.buttons = [{"text": "修炼", "primary": true, "disabled": lv >= int(e.max) or cost < 0 or s.gold < cost}]   # 层数没开、精魂不够也置灰（同进阶页；按确定照旧出原提示）
	return d


func _skin_sync() -> void:
	_skin_syncing = true
	for w in [index_win, status_win, gold_win, bottom_win, list_win]:
		w.visible = false
	var s := XState.current
	var rows := []
	for m: XActor in members():
		rows.append(XSkinRosterPage.roster_row(m))
	skin.set_roster(rows, index)
	var a := current()
	skin.list_title = T_LIST
	var items := []
	if a != null:
		for e in XTraining.listed():
			items.append(skin_row_of(s, a.actor_id, e))
	skin.set_items(items, clampi(skin_item(), 0, maxi(items.size() - 1, 0)))
	skin.set_focus("list" if mode == "list" else "roster")
	skin.set_card(skin_card())
	skin.set_strip(T_CLOSE if skin_open else T_OPEN, skin_open)
	if mode == "list":
		skin.set_hint_list([["确定", "修炼"], ["Y", T_CLOSE if skin_open else T_OPEN], ["取消", "返回"]])
	else:
		skin.set_hint_list([["确定", "选修炼项"], ["Y", T_CLOSE if skin_open else T_OPEN], ["取消", "离开"]])
	_skin_syncing = false
