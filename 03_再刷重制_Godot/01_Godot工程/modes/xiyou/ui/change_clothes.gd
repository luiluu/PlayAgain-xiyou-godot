class_name XChangeClothesScene
extends Control
## 更衣（Star_ChangeClothes 的 Scene_ChangeClothes；方桌大厅衣橱管理员 Map4 EV17「查看衣橱」）。数据与规则在 XChangeClothes。
## 版面按冻结 v0.28 浏览器参照（tests/fixtures/change_clothes_oracle.json，ui_reference/review_system_pages.js 的 change_clothes）：
## - 分类 (0,0,426,620)：普通～典藏 8 行；名单 (426,0,426,720) 行高 36、可见 19 行；状态 (852,0,428,720)；底部指令 (0,620,427,100)「更换／还原当前形象」。
## - 名单一行：已解锁＝行走图上半（同整队名单）＋名字 x=36；未解锁「？？？」x=6。开场显示普通档、无光标。
## - 状态：已解锁时「形象展示」(207−字宽「形象0」, 0)、行走图正面放大 2 倍（窗内 (213.33,360) 居中，在窗口底层，每 20 帧换一格 0→1→2）；
##   y=432 获得途径、y=468「状态:已解锁／未解锁」。未解锁不画图、不写「形象展示」。
##   原版 update：画着图时每 20 帧检查一次名单当前项，不是已解锁项（含名单光标 −1）就清掉图和文字；没画图时不清。
## - 操作：底部「更换」→ 分类选第 1 行；「还原当前形象」→ 清替换形象、提示「还原完成」；底部取消关闭。
##   分类上下移动名单跟着换档；确定 → 名单选第 1 行、重画状态；取消 → 回底部选第 1 项。
##   名单确定：已解锁 → 替换形象「替换完成」，未解锁 →「未解锁」，都留在名单；空表确定蜂鸣（O-093，原版报错）；取消 → 回分类。

signal closed

const CAT_RECT := Rect2(0, 0, 426, 620)
const LIST_RECT := Rect2(426, 0, 426, 720)
const STATUS_RECT := Rect2(852, 0, 428, 720)
const BOTTOM_RECT := Rect2(0, 620, 427, 100)
const LH := 36.0
const BOTTOM := ["更换", "还原当前形象"]
const SPRITE_POS := Vector2(1280.0 / 6.0, 360.0)
const SPRITE_TICK := 20

var mode := "bottom"        # bottom / category / list
var bottom := 0
var category := -1
var shown_category := 0     # 名单显示的档（Lid；开场 refresh(1) 即普通档）
var index := -1
var top := 0
var data: Array = []
## 状态窗：画着的条目（null＝空）与精灵（Window_ChangeClothesStatus._Sprite）
var status_entry = null
var sprite: Sprite2D
var sprite_count := 0       # _spriteFrameCount
var sprite_ref := 0         # _spriteFRef
var _last_list_index := -1  # Scene_ChangeClothes.update 的 _AIdx
var cat_win: XMVWindow
var list_win: XMVWindow
var status_win: XMVWindow
var bottom_win: XMVWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XChangeClothes.on_open(XState.current)
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	cat_win = XMVWindow.make(self, CAT_RECT, op, _paint_category)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	bottom_win = XMVWindow.make(self, BOTTOM_RECT, op, _paint_bottom)
	for w in [cat_win, list_win, bottom_win]:
		w.canvas.blink = true
	# addChildToBack：精灵在窗口皮肤之下
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	sprite.centered = true
	sprite.region_enabled = true
	sprite.scale = Vector2(2, 2)
	sprite.position = SPRITE_POS
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = false
	status_win.add_child(sprite)
	_load_list(0)


func rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


func current_entry():
	return data[index] if index >= 0 and index < data.size() else null


func _load_list(cat: int) -> void:
	shown_category = cat
	data = XChangeClothes.list(cat)
	_refresh()


func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + rows() < data.size()
	for w in [cat_win, list_win, status_win, bottom_win]:
		w.refresh()


## Window_ChangeClothesStatus.setupWhenCheck → drawAllContents：按名单当前项重画
func _draw_status() -> void:
	status_entry = current_entry()
	var e = status_entry
	if e != null and XChangeClothes.unlocked(int(e.id)):
		var p := XDB.img_path("characters", str(e.characterName)) if str(e.characterName) != "" else ""
		var tex: Texture2D = load(p) if p != "" else null
		sprite.texture = tex
		sprite.visible = tex != null
		_set_frame(true)
	else:
		_clear_sprite()
	status_win.refresh()


func _clear_sprite() -> void:
	sprite.texture = null
	sprite.visible = false


## 原版格子：图宽÷12 × 图高÷8（不分 $ 单人图）；序号 >3 在下半（行 4）。center＝drawAllContents 的中间一格，否则按 _spriteFRef
func _set_frame(center: bool) -> void:
	if sprite.texture == null or status_entry == null:
		return
	var idx := int(status_entry.characterIndex)
	var cw := sprite.texture.get_width() / 12.0
	var ch := sprite.texture.get_height() / 8.0
	var col := (idx * 3 - 12 if idx > 3 else idx * 3) + (1 if center else sprite_ref)
	var row := 4 if idx > 3 else 0
	sprite.region_rect = Rect2(col * cw, row * ch, cw, ch)


## Window_ChangeClothesStatus.update（每帧）：画着图时每 20 帧换一格，名单当前项不是已解锁项就清空
func _physics_process(_delta: float) -> void:
	if sprite.texture == null:
		return
	if sprite_count % SPRITE_TICK == 0:
		var e = current_entry()
		if e != null and XChangeClothes.unlocked(int(e.id)):
			_set_frame(false)
		else:
			_clear_sprite()
			status_entry = null
			status_win.refresh()
		sprite_ref = (sprite_ref + 1) % 3
	sprite_count += 1


# ---- 绘制 ----
func _paint_category(c: XMVCanvas) -> void:
	if category >= 0:
		c.cursor(Rect2(0, category * LH, c.size.x, LH), mode == "category")
	for i in XChangeClothes.CATEGORIES.size():
		c.text(XChangeClothes.CATEGORIES[i], 6, i * LH, c.size.x - 12)


func _paint_list(c: XMVCanvas) -> void:
	if index >= top and index < top + rows():
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "list")
	for i in range(top, mini(top + rows(), data.size())):
		var e: Dictionary = data[i]
		var y := (i - top) * LH
		if XChangeClothes.unlocked(int(e.id)):
			c.character(str(e.characterName), int(e.characterIndex), 32.0 / 2.0 + 6.0 / 2.0, y + LH + 16.0, LH - 4.0)
			c.text(str(e.name), 36, y, c.size.x - 36)
		else:
			c.text("？？？", 6, y, c.size.x - 12)


func _paint_status(c: XMVCanvas) -> void:
	var e = status_entry
	if e == null:
		return
	var open := XChangeClothes.unlocked(int(e.id))
	if open:
		c.text("形象展示", c.size.x / 2.0 + XMVWindow.PADDING / 2.0 - c.text_width("形象0"), 0, c.size.x)
	c.text(XChangeClothes.source_text(e), 0, LH * 12, c.size.x)
	c.text("状态:已解锁" if open else "状态:未解锁", 0, LH * 13, c.size.x)


func _paint_bottom(c: XMVCanvas) -> void:
	if bottom >= 0:
		c.cursor(Rect2(0, bottom * LH, c.size.x, LH), mode == "bottom")
	for i in BOTTOM.size():
		c.text(BOTTOM[i], 6, i * LH, c.size.x - 12)


# ---- 操作 ----
func ok() -> void:
	match mode:
		"bottom":
			XSound.system(1)
			if bottom == 0:
				# onGHOk
				bottom = -1
				mode = "category"
				_select_category(0)
			else:
				# onHYOk
				XChangeClothes.restore(XState.current)
				XToast.show_text(XChangeClothes.RESTORE_TEXT, true)
				_refresh()
		"category":
			# onRangeOk：名单换到当前档、选第 1 行、状态重画
			XSound.system(1)
			_load_list(category)
			mode = "list"
			_select(0)
			_draw_status()
		"list":
			var e = current_entry()
			if e == null:
				XSound.system(3)  # O-093：原版空表确定抛 TypeError
				return
			XSound.system(1)
			if XChangeClothes.apply(XState.current, e):
				XToast.show_text(XChangeClothes.DONE_TEXT, true)
			else:
				XToast.show_text(XChangeClothes.LOCKED_TEXT, true)


func cancel() -> void:
	XSound.system(2)
	match mode:
		"list":
			# Rancancel（原版取消音之外再放一次确定音，下同）
			XSound.system(1)
			mode = "category"
			index = -1
			_refresh()
		"category":
			# RancancelA
			XSound.system(1)
			mode = "bottom"
			category = -1
			bottom = 0
			_refresh()
		"bottom":
			closed.emit()


func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(i, top, rows()) if i >= 0 else top
	_refresh()
	# Scene_ChangeClothes.update：名单光标变到新的有效行就重画状态
	if i >= 0 and i != _last_list_index:
		_last_list_index = i
		_draw_status()


## 分类光标换档：名单跟着刷新（光标与滚动不动）
func _select_category(i: int) -> void:
	category = i
	if i != shown_category:
		_load_list(i)
	else:
		_refresh()


func _move(d: int, wrap: bool) -> void:
	match mode:
		"bottom":
			var i := XMenu._move(bottom, d, BOTTOM.size(), wrap)
			if i != bottom:
				XSound.system(0)
				bottom = i
				_refresh()
		"category":
			var i := XMenu._move(category, d, XChangeClothes.CATEGORIES.size(), wrap)
			if i != category:
				XSound.system(0)
				_select_category(i)
		"list":
			if data.is_empty():
				return
			var i := XMenu._move(index, d, data.size(), wrap)
			if i != index:
				XSound.system(0)
				_select(i)


func page(d: int) -> void:
	if mode != "list" or data.is_empty():
		return
	var before := index
	if (d < 0 and top > 0) or (d > 0 and top + rows() < data.size()):
		top = clampi(top + d * rows(), 0, maxi(0, data.size() - rows()))
		index = clampi(index + d * rows(), 0, data.size() - 1)
	if index != before:
		XSound.system(0)
		_select(index)
	else:
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
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, data.size() - rows()))
				_refresh()
		MOUSE_BUTTON_LEFT:
			var rect: Rect2 = {"bottom": BOTTOM_RECT, "category": CAT_RECT, "list": LIST_RECT}[mode]
			if not rect.grow(-pad).has_point(p):
				return
			var row := floori((p.y - rect.position.y - pad) / LH)
			match mode:
				"bottom":
					if row >= 0 and row < BOTTOM.size():
						if row == bottom:
							ok()
						else:
							XSound.system(0)
							bottom = row
							_refresh()
				"category":
					if row >= 0 and row < XChangeClothes.CATEGORIES.size():
						if row == category:
							ok()
						else:
							XSound.system(0)
							_select_category(row)
				"list":
					var i := top + row
					if i >= 0 and i < data.size():
						if i == index:
							ok()
						else:
							XSound.system(0)
							_select(i)


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
	elif event.is_action_pressed("ui_page_up", true) or event.is_action_pressed("ui_page_down", true):
		get_viewport().set_input_as_handled()
		page(-1 if event.is_action_pressed("ui_page_up", true) else 1)
