class_name XActorAdvancedScene
extends Control
## 角色进阶（Star_ActorAdvanced 的 Scene_ActorAdvanced；兑换大厅奉神老妪 Map132 EV6「进阶」）。数据与规则在 XAdvance。
## 版面按冻结 v0.28 浏览器参照（tests/fixtures/actor_advanced_oracle.json，ui_reference/review_system_pages.js 的 actor_advanced）：
## - 名单 (0,0,426,720)：队伍全体名字 x=6、行高 36，开场选第 1 行；状态 (426,0,854,720)；金钱 (0,656,426,64)；
##   底部「进阶」(426.67,656,854,64，压在状态窗下沿，开场无光标)；确认窗 Window_SaveConfirm (568,292,144,136)「是否进阶」「是／否」。
## - 状态（内容宽 826，column2x=420）：SV 战斗图（第 0 行、锚点居中、窗内 (82.6,82.6)、在窗口底层；每 12 帧按 0,1,2,1 换格）；
##   （带空格的横坐标按浏览器字宽 XActorBook.js_width 算：本工程字体空格 7、原版 7.21）
##   x=140 名字／等级／进阶次数／最大进阶次数；y=144 起 8 项能力（系统色标签在 0／252／504，值在「标签＋两空格」之后，第 1 行第三列「当前值」）；
##   y=288 有下一阶时左栏「进阶需求:」物品（图标＋名字＋「xN」）、「等级:N」、金钱（图标 3781），右栏 x=420「进化技能:」与技能；已满只写「已达最大进阶次数」。
## - 操作：名单移动重画状态与金钱；确定 → 有下一阶开底部，已满原地；取消关闭。底部确定 → 条件满足开确认窗，否则提示「进阶条件未达成」回名单；
##   底部取消回名单。确认「是」→ 进阶、提示「进阶完成」、回名单；「否」／取消 → 回名单。
## O-094（可回退，XAdvance.SHOW_MISSING／MAX_BUZZER）：条件不足时提示列出缺项；已满时确定放蜂鸣（原版无反馈）。

signal closed

const LIST_RECT := Rect2(0, 0, 426, 720)
const STATUS_RECT := Rect2(426, 0, 854, 720)
const GOLD_RECT := Rect2(0, 656, 426, 64)
const BOTTOM_RECT := Rect2(1280.0 / 3.0, 656, 854, 64)
const CONFIRM_RECT := Rect2(568, 292, 144, 136)
const LH := 36.0
const ATTR := ["生命", "魔法", "力量", "物防", "智力", "魔防", "敏捷", "幸运"]
const GOLD_ICON := 3781
const BOTTOM_TEXT := "                                            进阶"
const CONFIRM_TEXT := "是否进阶"
const SPRITE_TICK := 12
const PATTERNS := [0, 1, 2, 1]

var mode := "list"          # list / bottom / confirm
var index := 0
var top := 0
var bottom := -1
var confirm_index := 0
var members: Array = []
var shown_actor: XActor     # 状态窗画着的角色（Scene_ActorAdvanced._windowIdx 对应）
var sprite: Sprite2D
var sprite_count := 0       # _spriteFrameCount（不随换人清零）
var list_win: XMVWindow
var status_win: XMVWindow
var gold_win: XMVWindow
var bottom_win: XMVWindow
var confirm_win: XMVWindow
var confirm_back: Control
var confirm_background: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	gold_win = XMVWindow.make(self, GOLD_RECT, op, _paint_gold)
	bottom_win = XMVWindow.make(self, BOTTOM_RECT, op, _paint_bottom)
	# MV WindowLayer 会清掉确认窗矩形内下层窗口的内容；保留菜单底图（同存读档页）
	confirm_back = Control.new()
	confirm_back.clip_contents = true
	confirm_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(confirm_back)
	confirm_background = get_child(0).duplicate()
	confirm_back.add_child(confirm_background)
	confirm_background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	confirm_win = XMVWindow.make(self, CONFIRM_RECT, op, _paint_confirm)
	confirm_win.visible = false
	for w in [list_win, bottom_win, confirm_win]:
		w.canvas.blink = true
	# addChildToBack：精灵在窗口皮肤之下
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	sprite.centered = true
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	status_win.add_child(sprite)
	members = XState.current.members()
	_select(0)


func rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


func current_actor() -> XActor:
	return members[index] if index >= 0 and index < members.size() else null


func _refresh() -> void:
	confirm_back.visible = confirm_win.visible
	confirm_back.position = confirm_win.position
	confirm_back.size = confirm_win.size
	confirm_background.position = -confirm_back.position
	confirm_background.size = size
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + rows() < members.size()
	for w in [list_win, status_win, gold_win, bottom_win, confirm_win]:
		w.refresh()


## Window_ActorAdvancedStatus.setupWhenCheck → drawAllContents：换图并定在第 1 格，缩放复位后由 update 重算
func _draw_status() -> void:
	shown_actor = current_actor()
	if shown_actor != null:
		var p := XDB.img_path("sv_actors", str(shown_actor.data().get("battlerName", "")))
		sprite.texture = load(p) if p != "" else null
	else:
		sprite.texture = null
	sprite.visible = sprite.texture != null
	var w := status_win.canvas.size.x
	sprite.position = Vector2(w / 10.0, w / 10.0)
	sprite.scale = Vector2.ONE
	_set_frame(1)
	_refresh()


func _set_frame(pattern: int) -> void:
	if sprite.texture == null:
		return
	var cw := sprite.texture.get_width() / 9.0
	var ch := sprite.texture.get_height() / 6.0
	sprite.region_rect = Rect2(pattern * cw, 0, cw, ch)


## Window_ActorAdvancedStatus.update（每帧）：每 12 帧按 0,1,2,1 换格；格宽大于内容宽一半才缩小
func _physics_process(_delta: float) -> void:
	if sprite.texture == null:
		return
	if sprite_count % SPRITE_TICK == 0:
		_set_frame(PATTERNS[floori(sprite_count / float(SPRITE_TICK)) % 4])
	var cw := sprite.texture.get_width() / 9.0
	var half := status_win.canvas.size.x / 2.0
	var k := half / cw if cw > half else 1.0
	sprite.scale = Vector2(k, k)
	sprite_count += 1


# ---- 绘制 ----
func _paint_list(c: XMVCanvas) -> void:
	if index >= top and index < top + rows():
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "list")
	for i in range(top, mini(top + rows(), members.size())):
		c.text(members[i].display_name(), 6, (i - top) * LH, c.size.x - 12)


func _paint_status(c: XMVCanvas) -> void:
	var a := shown_actor
	if a == null:
		return
	var s := XState.current
	var w := c.size.x
	var pad := XMVWindow.PADDING
	var c2 := w / 2.0 + pad / 2.0
	var cw := w / 2.0 - pad
	var y := 0.0
	for t in [a.display_name(), "等级:%d" % a.level, "进阶次数:%d" % XAdvance.rank(s, a.actor_id), "最大进阶次数:%d" % XAdvance.max_text(s, a.actor_id)]:
		c.text(t, c2 / 3.0, y, cw)
		y += LH
	# 三列：标签 x、行；值在「标签＋两空格」之后
	var cols := [0.0, c2 * 3.0 / 5.0, c2 * 6.0 / 5.0]
	var cells := [[0, 0, 0], [1, 1, 0], [2, 0, 1], [3, 1, 1], [6, 2, 1], [4, 0, 2], [5, 1, 2], [7, 2, 2]]
	for cell in cells:
		var lx: float = cols[cell[1]]
		var ly: float = y + LH * cell[2]
		c.text(ATTR[cell[0]], lx, ly, cw, "left", XUI.SYSTEM)
		c.text(str(roundi(a.param(cell[0]))), lx + XActorBook.js_width(ATTR[cell[0]] + "  ", XUI.FONT_SIZE), ly, cw)
	c.text("当前值", cols[2], y, cw)
	y += LH * 4
	var r = XAdvance.row(s, a.actor_id)
	if r == null:
		c.text("已达最大进阶次数", 0, y, cw)
		return
	var top_y := y
	c.text("进阶需求:", 0, y, cw)
	y += LH
	for p in r.items:
		var item := XDB.rec("Items", int(p[0]))
		_item_name(c, item, 0, y, cw)
		c.text("x%d" % int(p[1]), XActorBook.js_width(str(item.get("name", "")) + "      ", XUI.FONT_SIZE), y, cw)
		y += LH
	c.text("等级:%d" % int(r.level), 0, y, cw)
	y += LH
	_currency(c, int(r.gold), 0, y, cw * 2)
	y = top_y
	c.text("进化技能:", c2, y, cw)
	y += LH
	for id in r.learn:
		_item_name(c, XDB.rec("Skills", int(id)), c2, y, cw)
		y += LH


## Window_Base.drawItemName：图标 (x+2, y+2)，名字 x+36（品质色）
func _item_name(c: XMVCanvas, item: Dictionary, x: float, y: float, width: float) -> void:
	if item.is_empty():
		return
	c.icon(int(item.get("iconIndex", 0)), x + 2, y + 2)
	c.text(str(item.get("name", "")), x + 36, y, width - 36, "left", XQuality.list_color(item))


## drawCurrencyValue：图标 3781 在 x，「数值单位」在 x＋单位宽×2/3
func _currency(c: XMVCanvas, value: int, x: float, y: float, width: float) -> void:
	var unit := str(XDB.system().get("currencyUnit", ""))
	var uw := minf(80.0, c.text_width(unit))
	c.text(str(value) + unit, x + uw * 2.0 / 3.0, y, width - uw - 6)
	c.icon(GOLD_ICON, x, y)


func _paint_gold(c: XMVCanvas) -> void:
	_currency(c, XState.current.gold, 0, 0, (c.size.x / 2.0 - XMVWindow.PADDING) * 2)


func _paint_bottom(c: XMVCanvas) -> void:
	if bottom >= 0:
		c.cursor(Rect2(0, 0, c.size.x, LH), mode == "bottom")
	# 行首 44 个空格按原版空格宽折成横坐标（同修炼页底部），免得「进阶」随本工程字体的空格宽偏左
	var word := BOTTOM_TEXT.strip_edges(true, false)
	var pad := (BOTTOM_TEXT.length() - word.length()) * XTrainingScene.SPACE_W
	c.text(word, 6 + pad, 0, c.size.x - 12 - pad)


func _paint_confirm(c: XMVCanvas) -> void:
	var t := XMVText.new(CONFIRM_TEXT, 6, 0, c.size.x)
	t.run()
	XMVText.paint(c, t.glyphs)
	for i in range(2):
		var y := LH * (i + 1)
		if i == confirm_index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "confirm")
		c.text(["是", "否"][i], 6, y, c.size.x - 12, "center")


# ---- 操作 ----
func ok() -> void:
	match mode:
		"list":
			var a := current_actor()
			if a == null:
				return
			if XAdvance.row(XState.current, a.actor_id) == null:
				# onRangeOk 没有下一阶：名单原地重新活动（O-094：蜂鸣）
				XSound.system(3 if XAdvance.MAX_BUZZER else 1)
				return
			XSound.system(1)
			# startBottomConfirmWindow
			XSound.system(1)
			mode = "bottom"
			bottom = 0
			_refresh()
		"bottom":
			XSound.system(1)
			# onBottomConfirmOk
			XSound.system(1)
			var s := XState.current
			var lack := XAdvance.missing(s, current_actor())
			bottom = -1
			if lack.is_empty():
				XSound.system(1)
				mode = "confirm"
				confirm_index = 0
				confirm_win.visible = true
			elif XGarou.own(current_actor()):
				# 饿狼 onBottomConfirmOk 包装：蜂鸣＋$gameMessage.add(原因)，不走原确认、不出「进阶条件未达成」；
				# 原版菜单里没有消息窗，这句回地图才出，重制当场右上角提示（同 O-094）
				XSound.system(3)
				mode = "list"
				XToast.show_text(str(lack[0]), true)
			else:
				XSound.system(1)
				mode = "list"
				XToast.show_text(XAdvance.fail_text(lack), true)
			_refresh()
		"confirm":
			XSound.system(1)
			if confirm_index == 1:
				_close_confirm()
				return
			# onConfirmOk
			XAdvance.advance(XState.current, current_actor())
			XToast.show_text(XAdvance.DONE_TEXT, true)
			_close_confirm()
			_draw_status()


func _close_confirm() -> void:
	confirm_win.visible = false
	mode = "list"
	_refresh()


func cancel() -> void:
	XSound.system(2)
	match mode:
		"list":
			closed.emit()
		"bottom":
			# onBottomConfirmCancel
			bottom = -1
			mode = "list"
			_refresh()
		"confirm":
			_close_confirm()


func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(i, top, rows())
	# Scene_ActorAdvanced.update：名单光标变了就重画状态与金钱
	_draw_status()


func _move(d: int, wrap: bool) -> void:
	match mode:
		"list":
			if members.is_empty():
				return
			var i := XMenu._move(index, d, members.size(), wrap)
			if i != index:
				XSound.system(0)
				_select(i)
		"confirm":
			var i := XMenu._move(confirm_index, d, 2, wrap)
			if i != confirm_index:
				XSound.system(0)
				confirm_index = i
				_refresh()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	var pad := XMVWindow.PADDING
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "list" and LIST_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, members.size() - rows()))
				_refresh()
		MOUSE_BUTTON_LEFT:
			var rect: Rect2 = {"list": LIST_RECT, "bottom": BOTTOM_RECT, "confirm": CONFIRM_RECT}[mode]
			if not rect.grow(-pad).has_point(p):
				return
			var row := floori((p.y - rect.position.y - pad) / LH)
			match mode:
				"list":
					var i := top + row
					if i >= 0 and i < members.size():
						if i == index:
							ok()
						else:
							XSound.system(0)
							_select(i)
				"bottom":
					if row == 0:
						ok()
				"confirm":
					var i := row - 1
					if i == 0 or i == 1:
						if i == confirm_index:
							ok()
						else:
							XSound.system(0)
							confirm_index = i
							_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
