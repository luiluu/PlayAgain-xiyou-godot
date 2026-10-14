class_name XMapTransferScene
extends Control
## 地图传送页（MapTransferPlugin 的 Scene_MapTransfer），按正式 v0.13 运行时逐像素复现
## （参照 04_验证/本地结果/原版参照/v013_transfer_*，读数见 界面风格.md）。数据部分在 core/map_transfer.gd。
## - 背景：地图截图（隐藏地图名）按 MV Bitmap.blur 模糊；不是菜单底图。窗口不透明度照常（背景 192）。
## - 地图列表 (0,0,180,720)：90 项，可见 19 行，名字居中；hidden 且未解锁写 ???。Q/E（PageUp/PageDown）跳 19 项。
##   选中项变化即刷新右侧预览；确定进入掉落选择（选中第一个掉落），取消关闭本页。
## - 预览 (180,0,1100,720)：每个敌人一块——左列宽 230 名字、战斗图（缩放 min(0.5, 230/宽, 120/高)）、HP；
##   右侧掉落每行 3 个（宽 264、行高 46）：图标、名字（ici 色，超 12 字截断）、右侧掉率 %.2f%%。
##   按高度分页（每页高 ≤ 内容高 − 72）；多页时右下「第 n/m 页（Q上一页 / E下一页）」，地图列表活动时左右键翻页。
##   底行系统色提示：未确认地图「确认地图后可选择掉落物查看详情」，确认后「确定查看详情 / F传送」或「当前地图不可传送」。
## - 掉落选择：黄色 2px 框；方向键按本页全部掉落的序号移动（上/左越界到最后一个，下/右不越界），每次移动后 10 帧冷却；
##   Q/E 翻页并选回第一个；确定开掉落详情（不传送）；F 传送确认；取消回地图列表（无音效）。
## - 掉落详情 (360,160,560,400)：名字、掉落概率 %.3f%%、类型与品质、基础属性、说明、装备固定特性；确定/取消关闭。
##   原版此时掉落窗口仍处理方向键（详情不变、框在后面移动），照做。
## - 传送确认 (450,276,380,168)：「是否传送至 名字?」与 确认/取消；确认播 Laser1，关闭本页后由地图从黑场淡入。
## 优化：O-012 事件中不开放按钮（map_scene）、O-013 预览掉率不随机神话、O-014 未解锁地图不能传送（XMapTransfer）。

signal closed(target: Dictionary)

const LIST_RECT := Rect2(0, 0, 180, 720)
const INFO_RECT := Rect2(180, 0, 1100, 720)
const DETAIL_RECT := Rect2(360, 160, 560, 400)
const CONFIRM_RECT := Rect2(450, 276, 380, 168)
const LH := 36.0
const LIST_ROWS := 19                # floor((720 − 28) / 36)
const CONTENT_H := 692.0             # 720 − 内边距×2
const PAD := 10.0
const ENEMY_COL := 230.0             # min(230, floor(1072 × 0.28))
const DROP_COLS := 3                 # floor((1072 − 230 − 30) / 190) 限 1～3
const COOLDOWN := 10
const SELECT_COLOR := Color("ffff00")
const PARAM_NAMES := ["生命", "魔法", "物攻", "物防", "魔攻", "魔防", "敏捷", "幸运"]
var background: Texture2D
var mode := "list"                   # list / drops / detail / confirm
var index := 0
var top := 0
var map_id := -1
var enemies: Array = []
var drops := {}                      # 敌人 ID -> XMapTransfer.drops
var heights: Array = []
var pages: Array = []
var page := 0
var drop_index := 0
var current_drops: Array = []        # 本页依次画出的掉落（选择序号）
var drop_rects: Array = []           # 对应的内容坐标矩形
var confirm_index := 0
var _cooldown_until := 0
var _entered_frame := -1
var _detail: Dictionary = {}
var list_win: XMVWindow
var info_win: XMVWindow
var detail_win: XMVWindow
var confirm_win: XMVWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	if background:
		add_child(XUI.blurred_background(background))
	list_win = XMVWindow.make(self, LIST_RECT, 255, _paint_list)
	list_win.canvas.blink = true
	info_win = XMVWindow.make(self, INFO_RECT, 255, _paint_info)
	detail_win = XMVWindow.make(self, DETAIL_RECT, 255, _paint_detail)
	detail_win.openness = 0
	detail_win.visible = false
	confirm_win = XMVWindow.make(self, CONFIRM_RECT, 255, _paint_confirm)
	confirm_win.canvas.blink = true
	confirm_win.openness = 0
	confirm_win.visible = false
	_select(0)


func current_map() -> Dictionary:
	var list := XMapTransfer.maps()
	return list[index] if index >= 0 and index < list.size() else {}


# ---- 预览数据（Window_EnemyInfo.setMapId / refresh）----
func set_map(id: int) -> void:
	if id == map_id:
		return
	map_id = id
	page = 0
	enemies.clear()
	drops.clear()
	if not XMapTransfer.is_locked(XState.current, XMapTransfer.setting(id)):
		enemies = XMapTransfer.preview_enemies(id)
		for e in enemies:
			drops[int(e.id)] = XMapTransfer.drops(XState.current, e)
	_layout_pages()


func _layout_pages() -> void:
	heights.clear()
	pages.clear()
	var limit := CONTENT_H - LH * 2
	var cur: Array = []
	var h := 0.0
	for i in enemies.size():
		heights.append(item_height(i))
		if h + heights[i] > limit and not cur.is_empty():
			pages.append(cur)
			cur = []
			h = 0.0
		cur.append(i)
		h += heights[i]
	if not cur.is_empty():
		pages.append(cur)
	if page >= pages.size():
		page = 0
	_refresh_info()


func _scale(tex: Texture2D) -> float:
	return minf(0.5, minf(ENEMY_COL / maxf(1, tex.get_width()), 120.0 / maxf(1, tex.get_height())))


## calcItemHeight：左列 名字 + 图 + HP + 内边距×4，右列 掉落行数×46 + 内边距×2，取高者
func item_height(i: int) -> float:
	var e: Dictionary = enemies[i]
	var tex := XMapTransfer.enemy_texture(e)
	var image_h := tex.get_height() * _scale(tex) if tex else LH * 2
	var left := LH + image_h + LH + PAD * 4
	var rows := ceili(drops[int(e.id)].size() / float(DROP_COLS))
	return maxf(left, rows * (LH + 10) + PAD * 2)


func _refresh_info() -> void:
	# drawCurrentPage 每次重画都重新登记本页的掉落顺序
	current_drops.clear()
	drop_rects.clear()
	if not pages.is_empty():
		var y := 0.0
		var dw := _drop_width()
		for i in pages[page]:
			for k: int in drops[int(enemies[i].id)].size():
				var x := ENEMY_COL + PAD * 2 + (k % DROP_COLS) * (dw + PAD)
				current_drops.append(drops[int(enemies[i].id)][k])
				drop_rects.append(Rect2(x, y + PAD + floori(k / float(DROP_COLS)) * (LH + 10), dw, LH))
			y += heights[i]
	info_win.refresh()


func _drop_width() -> float:
	var right_w := 1072.0 - ENEMY_COL - PAD * 3
	return (right_w - PAD * (DROP_COLS - 1)) / DROP_COLS


func selected_drop() -> Dictionary:
	return current_drops[drop_index] if drop_index >= 0 and drop_index < current_drops.size() else {}


# ---- 画面 ----
func _paint_list(c: XMVCanvas) -> void:
	var list := XMapTransfer.maps()
	for i in range(top, mini(list.size(), top + LIST_ROWS)):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "list")
		var m: Dictionary = list[i]
		c.text("???" if XMapTransfer.is_locked(XState.current, m) else str(m.name), 6, y, c.size.x - 12, "center")


func _paint_info(c: XMVCanvas) -> void:
	var w := c.size.x
	if map_id < 0 or XMapTransfer.setting(map_id).is_empty():
		c.text("请从左侧选择地图", 0, 0, w, "center")
		return
	var m := XMapTransfer.setting(map_id)
	if XMapTransfer.is_locked(XState.current, m):
		c.text("未解锁该地图", 0, 0, w, "center")
		return
	if enemies.is_empty():
		c.text("该地图没有敌人信息", 0, 0, w, "center")
		return
	if pages.is_empty():
		return
	var y := 0.0
	var n := 0
	var difficulty := XState.current.difficulty if XState.current else 2
	for i in pages[page]:
		var e: Dictionary = enemies[i]
		c.text(str(e.name), PAD, y + PAD, ENEMY_COL, "left", XEnemy.name_color(str(e.name), difficulty))
		var tex := XMapTransfer.enemy_texture(e)
		var image_y := y + PAD + LH + 5
		var hp_y := image_y + LH + 10
		if tex:
			var s := _scale(tex)
			c.draw_texture_rect(tex, Rect2(PAD, image_y, tex.get_width() * s, tex.get_height() * s), false)
			hp_y = image_y + tex.get_height() * s + 10
		else:
			c.text("(图片加载中...)", PAD, image_y, 150)
			hp_y = image_y + 10
		c.text("HP: " + XMapTransfer.format_hp(float(e.get("params", [0])[0])), PAD, hp_y, ENEMY_COL)
		var list: Array = drops[int(e.id)]
		if list.is_empty():
			c.text("没有掉落物品", ENEMY_COL + PAD * 2, y + PAD, 1072.0 - ENEMY_COL - PAD * 3)
		for d in list:
			var r: Rect2 = drop_rects[n]
			_paint_drop(c, d, r, difficulty)
			if mode in ["drops", "detail"] and n == drop_index:
				_select_rect(c, r)
			n += 1
		y += heights[i]
	var prompt_y := c.size.y - LH
	if mode in ["drops", "detail", "confirm"]:
		if not bool(m.canTransfer):
			c.text("当前地图不可传送", 0, prompt_y, INFO_RECT.size.x, "left", XUI.SYSTEM)
		elif int(m.transferItem) > 0:
			var item := XDB.rec("Items", int(m.transferItem))
			var head := "确定看详情 / F传送，消耗 " if XState.current and XState.current.item_count(int(m.transferItem)) > 0 else "确定看详情；不可传送，需 "
			c.text(head, 0, prompt_y, INFO_RECT.size.x, "left", XUI.SYSTEM)
			var tw := c.text_width(head)
			c.icon(int(item.get("iconIndex", 0)), tw, prompt_y + 2)
			c.text(str(item.get("name", "")), tw + 36, prompt_y, INFO_RECT.size.x - tw - 30 - 36)
			c.text("x1", tw + c.text_width(str(item.get("name", ""))) + 36, prompt_y, 30, "left", XUI.SYSTEM)
		else:
			c.text("确定查看详情 / F传送", 0, prompt_y, INFO_RECT.size.x, "left", XUI.SYSTEM)
	else:
		c.text("确认地图后可选择掉落物查看详情", 0, prompt_y, INFO_RECT.size.x, "left", XUI.SYSTEM)
	if pages.size() > 1:
		var t := "第 %d/%d 页（Q上一页 / E下一页）" % [page + 1, pages.size()]
		var tw := c.text_width(t)
		c.text(t, w - tw, c.size.y - LH * 2, tw, "right")


func _paint_drop(c: XMVCanvas, d: Dictionary, r: Rect2, difficulty: int) -> void:
	var item: Dictionary = d.item
	c.icon(int(item.get("iconIndex", 0)), r.position.x, r.position.y)
	var name := str(item.get("name", ""))
	if name.length() > 12:
		name = name.substr(0, 11) + "..."
	# 西游 v0.18：掉落名字与列表一样，有品质按七档色，否则按 <ici>
	var color := XQuality.list_color(item)
	c.text(name, r.position.x + 32, r.position.y, r.size.x - 32 - 60, "left", XEnemy.name_color(name, difficulty, color))
	c.text("%.2f%%" % float(d.rate), r.position.x + r.size.x - 60, r.position.y, 60, "right")


## drawSelectionRect：2px 黄框，外扩 2
func _select_rect(c: XMVCanvas, r: Rect2) -> void:
	var x := r.position.x - 2
	var y := r.position.y - 2
	var w := r.size.x + 4
	var h := r.size.y + 4
	c.draw_rect(Rect2(x, y, w, 2), SELECT_COLOR)
	c.draw_rect(Rect2(x, r.position.y + r.size.y, w, 2), SELECT_COLOR)
	c.draw_rect(Rect2(x, y, 2, h), SELECT_COLOR)
	c.draw_rect(Rect2(r.position.x + r.size.x + 2, y, 2, h), SELECT_COLOR)


func _paint_detail(c: XMVCanvas) -> void:
	var item: Dictionary = _detail.get("item", {})
	if item.is_empty():
		return
	var w := c.size.x
	var y := 0.0
	c.text("掉落物详情", 0, y, w, "center", XUI.SYSTEM)
	y += LH + 8
	c.icon(int(item.get("iconIndex", 0)), 8, y)
	var difficulty := XState.current.difficulty if XState.current else 2
	var name := str(item.get("name", "未知物品"))
	c.text(name, 32 + 16, y, w - 32 - 16, "left", XEnemy.name_color(name, difficulty))
	y += LH + 8
	var meta: Dictionary = item.get("meta", {})
	var quality := "　品质：" + str(meta.quality) if meta.has("quality") and str(meta.quality) != "" else ""
	c.text("掉落概率：", 8, y, 120, "left", XUI.SYSTEM)
	c.text("%.3f%%" % float(_detail.rate), 118, y, 120)
	c.text("类型：", 250, y, 70, "left", XUI.SYSTEM)
	c.text(str(_detail.type) + quality, 305, y, w - 305)
	y += LH + 8
	var stats: Array = []
	var params: Array = item.get("params", [])
	for i in params.size():
		var v := int(params[i])
		if v != 0:
			stats.append("%s%s%d" % [PARAM_NAMES[i], "+" if v > 0 else "", v])
	if not stats.is_empty():
		c.text("基础属性：", 8, y, 100, "left", XUI.SYSTEM)
		y = _wrapped(c, "　".join(stats), 108, y, w - 116) + 4
	c.text("说明：", 8, y, 70, "left", XUI.SYSTEM)
	var desc := str(item.get("description", ""))
	y = _wrapped(c, desc if desc != "" else "暂无说明", 8, y + LH, w - 16) + 8
	var traits := fixed_traits(item)
	if not traits.is_empty() and y < c.size.y - LH * 2:
		c.text("装备固定特性", 8, y, w - 16, "left", XUI.SYSTEM)
		y += LH
		for t in traits:
			if y >= c.size.y - LH * 2:
				break
			y = _wrapped(c, t, 12, y, w - 24) + 2
	c.text("确认或取消返回掉落列表", 0, c.size.y - LH, w, "center", XUI.SYSTEM)


## drawWrapped：逐字量宽折行，换行符当空格；返回下一行 y
func _wrapped(c: XMVCanvas, text: String, x: float, y: float, width: float) -> float:
	var chars := RegEx.create_from_string("[\\r\\n]+").sub(text, " ", true)
	var line := ""
	var row := 0
	for ch in chars:
		if c.text_width(line + ch) > width:
			c.text(line, x, y + row * LH, width)
			row += 1
			line = ch
		else:
			line += ch
	if line != "":
		c.text(line, x, y + row * LH, width)
	return y + (row + 1) * LH


## fixedTraitLines：装备备注 <pos=APs text=… size= 里的固定特性（专属/特效/套装/成长等），不显示随机词条
static func fixed_traits(item: Dictionary) -> Array:
	var out: Array = []
	var keep := RegEx.create_from_string("(专属|特效|固定|套装|每级|成长|被动|伤害|暴击|穿透|掉宝)")
	var codes := RegEx.create_from_string("(?i)\\\\[ci]\\[\\d+\\]")
	for m in RegEx.create_from_string("(?is)<pos=APs\\s+text=([\\s\\S]*?)\\s+size=").search_all(str(item.get("note", ""))):
		var t := codes.sub(m.get_string(1), "", true).strip_edges()
		if t != "" and keep.search(t) and not out.has(t):
			out.append(t)
	return out


func _paint_confirm(c: XMVCanvas) -> void:
	for i in 2:
		var y := LH + 12 + i * LH
		if i == confirm_index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "confirm")
		c.text(["确认", "取消"][i], 6, y, c.size.x - 12)
	c.text("是否传送至 %s?" % str(current_map().get("name", "未知地图")), 0, 0, c.size.x, "center")


# ---- 操作 ----
func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(index, top, LIST_ROWS)
	set_map(int(current_map().get("id", 0)))
	_refresh_list()


func _refresh_list() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + LIST_ROWS < XMapTransfer.maps().size()
	list_win.refresh()


func _list_move(d: int, wrap: bool) -> void:
	var n := XMapTransfer.maps().size()
	var i := XMenu._move(index, d, n, wrap)
	if i != index:
		XSound.system(0)
		_select(i)


func _list_page(d: int) -> void:
	var n := XMapTransfer.maps().size()
	XSound.system(0)
	_select(clampi(index + d * LIST_ROWS, 0, n - 1))


func confirm_map() -> void:
	XSound.system(1)
	mode = "drops"
	_entered_frame = Engine.get_process_frames()
	drop_index = 0
	_refresh_info()
	_refresh_list()


func back_to_list() -> void:
	mode = "list"
	_refresh_info()
	_refresh_list()


func _flip(d: int) -> void:
	if pages.size() <= 1:
		return
	page = (page + d + pages.size()) % pages.size()
	_refresh_info()


## processDropSelect：按本页掉落序号移动；每次移动后冷却 10 帧
func _drop_move(dir: String) -> void:
	var n := current_drops.size()
	if n <= 0 or Engine.get_process_frames() < _cooldown_until:
		return
	var next := drop_index
	match dir:
		"down":
			if drop_index + DROP_COLS >= n:
				return
			next = drop_index + DROP_COLS
		"up":
			next = drop_index - DROP_COLS if drop_index - DROP_COLS >= 0 else n - 1
		"right":
			if drop_index + 1 >= n:
				return
			next = drop_index + 1
		"left":
			next = drop_index - 1 if drop_index > 0 else n - 1
	_cooldown_until = Engine.get_process_frames() + COOLDOWN + 1
	drop_index = next
	XSound.system(0)
	_refresh_info()


func open_detail() -> void:
	var d := selected_drop()
	if d.is_empty() or (d.item as Dictionary).is_empty():
		XSound.system(3)
		return
	_detail = d
	mode = "detail"
	detail_win.visible = true
	detail_win.openness = 0
	detail_win.open()
	detail_win.refresh()
	XSound.system(1)


func close_detail() -> void:
	detail_win.openness = 0
	detail_win.visible = false
	mode = "drops"
	XSound.system(2)
	_refresh_info()


## F：可传送的地图才开确认；需要道具而没有时蜂鸣
func request_transfer() -> void:
	var m := current_map()
	if m.is_empty() or not bool(m.canTransfer) or (XMapTransfer.REQUIRE_UNLOCK and XMapTransfer.is_locked(XState.current, m)):
		return
	if int(m.transferItem) > 0 and (XState.current == null or XState.current.item_count(int(m.transferItem)) <= 0):
		XSound.system(3)
		return
	mode = "confirm"
	confirm_index = 0
	confirm_win.visible = true
	confirm_win.openness = 0
	confirm_win.open()
	confirm_win.refresh()
	_refresh_info()


## closeConfirmationWindow：回到掉落选择，并选回第一个掉落（activateDropSelect）
func close_confirm() -> void:
	confirm_win.openness = 0
	confirm_win.visible = false
	mode = "drops"
	drop_index = 0
	_refresh_info()


func confirm_ok() -> void:
	XSound.system(1)
	if confirm_index == 1:
		close_confirm()
		return
	var m := current_map()
	if not XMapTransfer.can_transfer(XState.current, m):
		XSound.system(3)
		return
	if int(m.transferItem) > 0:
		XState.current.gain_item(int(m.transferItem), -1)
	XSound.play("Laser1", 90)
	closed.emit({"map": XMapTransfer.target_map(m), "x": int(m.x), "y": int(m.y)})


func cancel() -> void:
	match mode:
		"list":
			XSound.system(2)
			closed.emit({})
		"drops":
			back_to_list()
		"detail":
			close_detail()
		"confirm":
			XSound.system(2)
			close_confirm()


func ok() -> void:
	match mode:
		"list":
			confirm_map()
		"drops":
			if Engine.get_process_frames() > _entered_frame:
				open_detail()
		"detail":
			close_detail()
		"confirm":
			confirm_ok()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var pressed_key := key != null and key.pressed and not key.echo
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		cancel()
	elif event.is_action_pressed("ui_accept"):
		ok()
	elif pressed_key and key.physical_keycode == KEY_F:
		if mode == "drops":
			request_transfer()
	elif event.is_action_pressed("ui_page_up") or (pressed_key and key.physical_keycode == KEY_Q):
		_page_key(-1)
	elif event.is_action_pressed("ui_page_down") or (pressed_key and key.physical_keycode == KEY_E):
		_page_key(1)
	else:
		var dir := ""
		for d in ["up", "down", "left", "right"]:
			if event.is_action_pressed("ui_" + d, true):
				dir = d
		if dir == "":
			handled = false
		else:
			_arrow(dir, not event.is_echo())
	if handled:
		get_viewport().set_input_as_handled()


func _page_key(d: int) -> void:
	match mode:
		"list":
			_list_page(d)
		"drops", "detail":
			if pages.size() > 1:
				drop_index = 0
				_flip(d)


func _arrow(dir: String, first: bool) -> void:
	match mode:
		"list":
			if dir in ["up", "down"]:
				_list_move(1 if dir == "down" else -1, first)
			elif first and pages.size() > 1 and Engine.get_process_frames() >= _cooldown_until:
				_cooldown_until = Engine.get_process_frames() + COOLDOWN + 1
				_flip(1 if dir == "right" else -1)
		"drops", "detail":
			_drop_move(dir)
		"confirm":
			if dir in ["up", "down"]:
				var i := XMenu._move(confirm_index, 1 if dir == "down" else -1, 2, first)
				if i != confirm_index:
					confirm_index = i
					XSound.system(0)
					confirm_win.refresh()


# ---- 鼠标：列表先选中再点确定、滚轮滚动；右键取消；确认框点选 ----
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	var pad := Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "list" and LIST_RECT.has_point(p):
				var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
				top = clampi(top + d, 0, maxi(0, XMapTransfer.maps().size() - LIST_ROWS))
				_refresh_list()
		MOUSE_BUTTON_LEFT:
			if mode == "list" and LIST_RECT.has_point(p):
				var i := top + floori((p - LIST_RECT.position - pad).y / LH)
				if i == index:
					confirm_map()
				elif i >= 0 and i < XMapTransfer.maps().size() and i < top + LIST_ROWS:
					XSound.system(0)
					_select(i)
			elif mode == "confirm" and CONFIRM_RECT.has_point(p):
				var row := floori(((p - CONFIRM_RECT.position - pad).y - LH - 12) / LH)
				if row == confirm_index:
					confirm_ok()
				elif row >= 0 and row < 2:
					confirm_index = row
					XSound.system(0)
					confirm_win.refresh()
		_:
			return
	accept_event()
