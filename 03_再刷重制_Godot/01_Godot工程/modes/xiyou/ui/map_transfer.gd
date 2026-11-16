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
##   原版此时掉落窗口仍处理方向键与 Q/E（详情不变、框在后面移动），原版缺陷，修好（O-229，rules-bugfix1 照搬清单第 3 条）：
##   详情开着时方向键、翻页只归详情（详情不用它们，等于不动）。回退开关 DETAIL_LOCKS_DROPS = false：照原版后面的框跟着动。
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
static var DETAIL_LOCKS_DROPS := true
## O-380：点选也能传送。原版只认键盘 F（mapTransferConfirm），手机没有 F 键：选好地图进了掉落页就再也传不出去，
## 点列表也没反应，玩家以为卡死（Kyo 11-13 转安卓玩家反馈 v0.01.07「一点传送就卡了」）。
## 现在掉落页里再点一次选中的地图名、或点底部提示行＝按 F；点别的地图名回到列表并选中它；提示写「再点地图名传送」。
## 设 false 恢复原版（只有 F 键能传送）。
static var TAP_TRANSFER := true
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
var list_pager: XListPager   # T050 翻页件（新界面关着时为 null）
var info_win: XMVWindow
var detail_win: XMVWindow
var confirm_win: XMVWindow
var _header: Control
var _hints: XSkinKeyHints
var _wide_requested := false


func _ready() -> void:
	if XUiSkin.on():
		add_to_group(XUiSkin.FULLSCREEN_GROUP)   # 收口批：新皮肤全屏页开着时收起虚拟摇杆／AB 键（小A核 P2-2）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skinned := XUiSkin.on()
	theme = XUiSkin.theme() if skinned else XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if skinned:
		XSkinLayout.request_wide(self)
		_wide_requested = true
		XUI.menu_background(self)
	else:
		var black := ColorRect.new()
		black.color = Color.BLACK
		black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(black)
		if background:
			add_child(XUI.blurred_background(background))
	list_win = XMVWindow.make(self, LIST_RECT, 255, _paint_list)
	list_win.canvas.blink = true
	list_pager = XListPager.attach(list_win, _pager_step)
	info_win = XMVWindow.make(self, INFO_RECT, 255, _paint_info)
	detail_win = XMVWindow.make(self, DETAIL_RECT, 255, _paint_detail)
	detail_win.openness = 0
	detail_win.visible = false
	confirm_win = XMVWindow.make(self, CONFIRM_RECT, 255, _paint_confirm)
	confirm_win.canvas.blink = true
	confirm_win.openness = 0
	confirm_win.visible = false
	if skinned:
		_header = Control.new()
		_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_header.draw.connect(_draw_header)
		add_child(_header)
		_hints = XSkinKeyHints.new()
		add_child(_hints)
		resized.connect(_relayout_skin)
		get_viewport().size_changed.connect(_relayout_skin)
		_relayout_skin()
	_select(0)


func _view_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1280, 720)


func _relayout_skin() -> void:
	if not XUiSkin.on() or list_win == null:
		return
	var vs := _view_size()
	var m := XSkinLayout.margin_for(vs.x)
	var top_y := float(XUiSkin.TOP)
	var bot_y := vs.y - 52.0
	var h := maxf(240.0, bot_y - top_y)
	var lw := 240.0
	var gap := float(XUiSkin.PANEL_GAP)
	list_win.position = Vector2(m, top_y)
	list_win.size = Vector2(lw, h)
	info_win.position = Vector2(m + lw + gap, top_y)
	info_win.size = Vector2(maxf(400.0, vs.x - m * 2.0 - lw - gap), h)
	var dw := minf(620.0, vs.x - m * 2.0)
	var dh := minf(440.0, vs.y - 120.0)
	detail_win.position = Vector2(roundf((vs.x - dw) / 2.0), roundf((vs.y - dh) / 2.0))
	detail_win.size = Vector2(dw, dh)
	var cw := 420.0
	var ch := 180.0
	confirm_win.position = Vector2(roundf((vs.x - cw) / 2.0), roundf((vs.y - ch) / 2.0))
	confirm_win.size = Vector2(cw, ch)
	if _header != null:
		_header.position = Vector2.ZERO
		_header.size = Vector2(vs.x, top_y)
		_header.queue_redraw()
	_sync_hints()
	_layout_pages()
	_refresh_list()


func _draw_header() -> void:
	if _header == null or not XUiSkin.on():
		return
	var vs := _view_size()
	var m := XSkinLayout.margin_for(vs.x)
	var head := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var title_txt := "传送"
	_header.draw_string(head, Vector2(m, 50), title_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE, XUiSkin.TEXT)
	var cur := current_map()
	var sub := "???" if cur.is_empty() or XMapTransfer.is_locked(XState.current, cur) else str(cur.get("name", ""))
	if sub != "":
		var tw := head.get_string_size(title_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE).x
		_header.draw_string(body, Vector2(m + tw + 16.0, 48), "·  " + sub, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST, XUiSkin.GOLD_LIGHT)


func _sync_hints() -> void:
	if _hints == null or not XUiSkin.on():
		return
	var arr := []
	match mode:
		"list":
			arr = [["确定", "查看掉落"], ["Q / E", "翻页"], ["取消", "返回"]]
		"drops":
			var m := current_map()
			var can_go := not m.is_empty() and bool(m.canTransfer) and not (XMapTransfer.REQUIRE_UNLOCK and XMapTransfer.is_locked(XState.current, m))
			if can_go:
				var k := "再点地图名" if (TAP_TRANSFER and XPlatform.is_touch()) else "F"
				arr = [[k, "传送"], ["确定", "掉落详情"], ["Q / E", "翻页"], ["取消", "重选地图"]]
			else:
				arr = [["确定", "掉落详情"], ["Q / E", "翻页"], ["取消", "重选地图"]]
		"detail":
			arr = [["确定", "关闭"], ["取消", "返回掉落"]]
		"confirm":
			arr = [["确定", "确认传送"], ["取消", "返回"]]
	_hints.set_hints(arr)
	_hints.place(_view_size())


## T050：新界面下列表窗高随屏幕定，超一页时再少放一行给翻页件腾地方（见 XListPager.rows_for）
func _list_rows() -> int:
	var base := LIST_ROWS
	if XUiSkin.on() and list_win != null:
		base = maxi(1, floori((list_win.size.y - XMVWindow.PADDING * 2.0) / LH))
	return XListPager.rows_for(base, XMapTransfer.maps().size())


## 翻页件：整页翻（页首对齐），列表态选中项跟着挪同样的行数；掉落态只翻不换地图
func _pager_step(d: int) -> void:
	var n := XMapTransfer.maps().size()
	var rows := _list_rows()
	var nt := XListPager.top_of(XListPager.page_of(top, rows, n) + d, rows, n)
	if nt == top:
		return
	var moved := nt - top
	top = nt
	if mode == "list":
		XSound.system(0)
		_select(clampi(index + moved, 0, n - 1))
	else:
		_refresh_list()


func _info_inner_w() -> float:
	if XUiSkin.on() and info_win != null:
		return maxf(320.0, info_win.size.x - XMVWindow.PADDING * 2.0)
	return 1072.0


func _info_inner_h() -> float:
	if XUiSkin.on() and info_win != null:
		return maxf(200.0, info_win.size.y - XMVWindow.PADDING * 2.0)
	return CONTENT_H


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
	var limit := _info_inner_h() - LH * 2
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
	if _header != null:
		_header.queue_redraw()
	_sync_hints()


func _drop_width() -> float:
	var right_w := _info_inner_w() - ENEMY_COL - PAD * 3
	return (right_w - PAD * (DROP_COLS - 1)) / DROP_COLS


func selected_drop() -> Dictionary:
	return current_drops[drop_index] if drop_index >= 0 and drop_index < current_drops.size() else {}


# ---- 画面 ----
func _paint_list(c: XMVCanvas) -> void:
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	var list := XMapTransfer.maps()
	var rows := _list_rows()
	for i in range(top, mini(list.size(), top + rows)):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "list")
		var m: Dictionary = list[i]
		var locked := XMapTransfer.is_locked(XState.current, m)
		var col := (XUiSkin.TEXT_3 if locked else (XUiSkin.GOLD_LIGHT if i == index else XUiSkin.TEXT)) if on else XUI.TEXT
		c.text("???" if locked else str(m.name), 6, y, c.size.x - 12, "left" if on else "center", col)


func _paint_info(c: XMVCanvas) -> void:
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	var w := c.size.x
	if map_id < 0 or XMapTransfer.setting(map_id).is_empty():
		c.text("请从左侧选择地图", 0, (c.size.y - LH) / 2.0 if on else 0.0, w, "center", XUiSkin.TEXT_2 if on else XUI.TEXT)
		return
	var m := XMapTransfer.setting(map_id)
	if XMapTransfer.is_locked(XState.current, m):
		c.text("未解锁该地图", 0, (c.size.y - LH) / 2.0 if on else 0.0, w, "center", XUiSkin.TEXT_3 if on else XUI.TEXT)
		return
	if enemies.is_empty():
		c.text("该地图没有敌人信息", 0, (c.size.y - LH) / 2.0 if on else 0.0, w, "center", XUiSkin.TEXT_2 if on else XUI.TEXT)
		return
	if pages.is_empty():
		return
	var y := 0.0
	var n := 0
	var difficulty := XState.current.difficulty if XState.current else 2
	var inner_w := _info_inner_w()
	for i in pages[page]:
		var e: Dictionary = enemies[i]
		if on:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(1, 1, 1, 0.028)
			box.border_color = Color(XUiSkin.LINE, 0.14)
			box.set_border_width_all(1)
			box.set_corner_radius_all(8)
			c.draw_style_box(box, Rect2(0.0, y + 3.0, w, heights[i] - 6.0))
			c.font = XUiSkin.font("title")
		c.text(str(e.name), PAD, y + PAD, ENEMY_COL, "left", XEnemy.name_color(str(e.name), difficulty, XUiSkin.TEXT if on else XUI.TEXT))
		if on:
			c.font = XUiSkin.font("body")
		var tex := XMapTransfer.enemy_texture(e)
		var image_y := y + PAD + LH + 5
		var hp_y := image_y + LH + 10
		if tex:
			var s := _scale(tex)
			c.draw_texture_rect(tex, Rect2(PAD, image_y, tex.get_width() * s, tex.get_height() * s), false)
			hp_y = image_y + tex.get_height() * s + 10
		else:
			c.text("（图片加载中……）", PAD, image_y, 150, "left", XUiSkin.TEXT_3 if on else XUI.TEXT)
			hp_y = image_y + 10
		if on:
			c.font = XUiSkin.font("num")
		c.text(("HP " if on else "HP: ") + XMapTransfer.format_hp(float(e.get("params", [0])[0])), PAD, hp_y, ENEMY_COL, "left", XUiSkin.TEXT_2 if on else XUI.TEXT)
		if on:
			c.font = XUiSkin.font("body")
		var list: Array = drops[int(e.id)]
		if list.is_empty():
			c.text("没有掉落物品", ENEMY_COL + PAD * 2, y + PAD, inner_w - ENEMY_COL - PAD * 3, "left", XUiSkin.TEXT_3 if on else XUI.TEXT)
		for d in list:
			var r: Rect2 = drop_rects[n]
			_paint_drop(c, d, r, difficulty)
			if mode in ["drops", "detail"] and n == drop_index:
				_select_rect(c, r)
			n += 1
		y += heights[i]
	var prompt_y := c.size.y - LH
	var sys_col := XUiSkin.GOLD if on else XUI.SYSTEM
	if mode in ["drops", "detail", "confirm"]:
		if not bool(m.canTransfer):
			c.text("当前地图不可传送", 0, prompt_y, w, "left", XUiSkin.DOWN if on else sys_col)
		elif int(m.transferItem) > 0:
			var item := XDB.rec("Items", int(m.transferItem))
			var has_item := XState.current and XState.current.item_count(int(m.transferItem)) > 0
			var head := (("消耗 " if on else "确定查看详情 / %s，消耗 " % _transfer_hint()) if has_item else ("缺少传送凭证，需 " if on else "确定查看详情；不可传送，需 "))
			c.text(head, 0, prompt_y, w, "left", (XUiSkin.GOLD if has_item else XUiSkin.DOWN) if on else sys_col)
			var tw := c.text_width(head)
			c.icon(int(item.get("iconIndex", 0)), tw, prompt_y + 2)
			c.text(str(item.get("name", "")), tw + 36, prompt_y, w - tw - 48 - 36, "left", XUiSkin.TEXT if on else XUI.TEXT)
			c.text(" × 1" if on else "x1", tw + c.text_width(str(item.get("name", ""))) + 36, prompt_y, 48, "left", XUiSkin.GOLD_LIGHT if on else sys_col)
		else:
			var msg := ("可传送至当前选中地图" if on else ("确定查看详情 / " + _transfer_hint()))
			c.text(msg, 0, prompt_y, w, "left", sys_col)
	else:
		c.text("确认地图后可选择掉落物查看详情", 0, prompt_y, w, "left", XUiSkin.TEXT_2 if on else sys_col)
	var elem_line := XTianqiElements.transfer_floor_line(XState.current, map_id)
	if elem_line != "":
		c.text(elem_line, 0, prompt_y - LH, w, "left", Color("#9be4ff"))
	if pages.size() > 1:
		var t := ("第 %d / %d 页" % [page + 1, pages.size()]) if on else ("第 %d/%d 页（Q上一页 / E下一页）" % [page + 1, pages.size()])
		var tw := c.text_width(t)
		c.text(t, w - tw, c.size.y - (LH if on else LH * 2), tw, "right", XUiSkin.TEXT_2 if on else XUI.TEXT)


func _paint_drop(c: XMVCanvas, d: Dictionary, r: Rect2, difficulty: int) -> void:
	var on := XUiSkin.on()
	if on:
		var slot := StyleBoxFlat.new()
		slot.bg_color = Color(0, 0, 0, 0.28)
		slot.border_color = Color(XUiSkin.LINE, 0.14)
		slot.set_border_width_all(1)
		slot.set_corner_radius_all(6)
		c.draw_style_box(slot, r)
	var item: Dictionary = d.item
	c.icon(int(item.get("iconIndex", 0)), r.position.x + (4.0 if on else 0.0), r.position.y + (2.0 if on else 0.0))
	var name := str(item.get("name", ""))
	if name.length() > 12:
		name = name.substr(0, 11) + ("…" if on else "...")
	else:
		# 星级（v0.18 在名字前）：starScope 只在画出的文字正好是 item.name 时加星，截断的名字不加
		name = XQuality.stars(item) + name
	# 西游 v0.18：掉落名字与列表一样，有品质按七档色，否则按 <ici>
	var color := XQuality.list_color(item)
	var name_x := r.position.x + (38.0 if on else 32.0)
	var rate_w := 64.0 if on else 60.0
	c.text(name, name_x, r.position.y, r.size.x - (name_x - r.position.x) - rate_w, "left", XEnemy.name_color(name, difficulty, color))
	if on:
		c.font = XUiSkin.font("num")
	c.text("%.2f%%" % float(d.rate), r.position.x + r.size.x - rate_w - (6.0 if on else 0.0), r.position.y, rate_w, "right", XUiSkin.GOLD_LIGHT if on else XUI.TEXT)
	if on:
		c.font = XUiSkin.font("body")


## drawSelectionRect：2px 黄框，外扩 2；新皮肤用红乙选中框
func _select_rect(c: XMVCanvas, r: Rect2) -> void:
	if XUiSkin.on():
		XUiSkin.draw_select(c.get_canvas_item(), r.grow(2), XUiSkin.breath_alpha())
		return
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
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	var lbl_col := XUiSkin.GOLD if on else XUI.SYSTEM
	var val_col := XUiSkin.TEXT if on else XUI.TEXT
	var w := c.size.x
	var y := 0.0
	if on:
		c.font = XUiSkin.font("title")
	c.text("掉落物详情", 0, y, w, "center", lbl_col)
	if on:
		c.font = XUiSkin.font("body")
		c.draw_line(Vector2(8, y + LH + 2), Vector2(w - 8, y + LH + 2), Color(XUiSkin.LINE, 0.2), 1.0)
	y += LH + 8
	c.icon(int(item.get("iconIndex", 0)), 8, y)
	var difficulty := XState.current.difficulty if XState.current else 2
	var name := str(item.get("name", "未知物品"))
	if on:
		c.font = XUiSkin.font("title")
	c.text(name, 32 + 16, y, w - 32 - 16, "left", XEnemy.name_color(name, difficulty, XQuality.list_color(item) if on else XUI.TEXT))
	if on:
		c.font = XUiSkin.font("body")
	y += LH + 8
	var meta: Dictionary = item.get("meta", {})
	var quality := "　品质：" + str(meta.quality) if meta.has("quality") and str(meta.quality) != "" else ""
	c.text("掉落概率：", 8, y, 120, "left", lbl_col)
	if on:
		c.font = XUiSkin.font("num")
	c.text("%.3f%%" % float(_detail.rate), 118, y, 120, "left", XUiSkin.GOLD_LIGHT if on else val_col)
	if on:
		c.font = XUiSkin.font("body")
	c.text("类型：", 250, y, 70, "left", lbl_col)
	c.text(str(_detail.type) + quality, 305, y, w - 305, "left", val_col)
	y += LH + 8
	var stats: Array = []
	var params: Array = item.get("params", [])
	for i in params.size():
		var v := int(params[i])
		if v != 0:
			stats.append("%s%s%d" % [PARAM_NAMES[i], "+" if v > 0 else "", v])
	if not stats.is_empty():
		c.text("基础属性：", 8, y, 100, "left", lbl_col)
		y = _wrapped(c, "　".join(stats), 108, y, w - 116) + 4
	c.text("说明：", 8, y, 70, "left", lbl_col)
	var desc := str(item.get("description", ""))
	y = _wrapped(c, desc if desc != "" else "暂无说明", 8, y + LH, w - 16) + 8
	var traits := fixed_traits(item)
	if not traits.is_empty() and y < c.size.y - LH * 2:
		c.text("装备固定特性", 8, y, w - 16, "left", lbl_col)
		y += LH
		for t in traits:
			if y >= c.size.y - LH * 2:
				break
			y = _wrapped(c, t, 12, y, w - 24) + 2
	c.text("确认或取消返回掉落列表", 0, c.size.y - LH, w, "center", XUiSkin.TEXT_3 if on else lbl_col)


## drawWrapped：逐字量宽折行，换行符当空格；返回下一行 y
func _wrapped(c: XMVCanvas, text: String, x: float, y: float, width: float) -> float:
	var chars := RegEx.create_from_string("[\\r\\n]+").sub(text, " ", true)
	var line := ""
	var row := 0
	var col := XUiSkin.TEXT_2 if XUiSkin.on() else XUI.TEXT
	for ch in chars:
		if c.text_width(line + ch) > width:
			c.text(line, x, y + row * LH, width, "left", col)
			row += 1
			line = ch
		else:
			line += ch
	if line != "":
		c.text(line, x, y + row * LH, width, "left", col)
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
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	for i in 2:
		var y := LH + 12 + i * LH
		if i == confirm_index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "confirm")
		c.text(["确认", "取消"][i], 6, y, c.size.x - 12, "center" if on else "left", XUiSkin.TEXT if on else XUI.TEXT)
	if on:
		c.font = XUiSkin.font("title")
	var q_txt := ("确认传送至 %s？" if on else "是否传送至 %s？") % str(current_map().get("name", "未知地图"))
	c.text(q_txt, 0, 0, c.size.x, "center", XUiSkin.GOLD_LIGHT if on else XUI.TEXT)


# ---- 操作 ----
func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(index, top, _list_rows())
	set_map(int(current_map().get("id", 0)))
	_refresh_list()


func _refresh_list() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + _list_rows() < XMapTransfer.maps().size()
	if list_pager != null:   # 有翻页件时它自己画页码，底边的下箭头不要
		list_pager.size.x = minf(XListPager.DEFAULT_SIZE.x, list_win.size.x - 16.0)   # 窗宽窗高随屏幕变，每次重摆
		list_pager.position = Vector2((list_win.size.x - list_pager.size.x) / 2.0, list_win.size.y - XListPager.DEFAULT_SIZE.y - 2.0)
		list_pager.set_state(top, _list_rows(), XMapTransfer.maps().size())
		list_win.down_arrow = list_win.down_arrow and not list_pager.visible
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
	_select(clampi(index + d * _list_rows(), 0, n - 1))


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
	_sync_hints()
	XSound.system(1)


func close_detail() -> void:
	detail_win.openness = 0
	detail_win.visible = false
	mode = "drops"
	XSound.system(2)
	_refresh_info()


## 提示行里传送的写法：触屏写点选（TAP_TRANSFER），否则照原版「F传送」
func _transfer_hint() -> String:
	return "再点地图名传送" if TAP_TRANSFER and XPlatform.is_touch() else "F传送"


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
## 点选传送（TAP_TRANSFER）：同按 F；不能传送（不可传送、未解锁）时蜂鸣，免得像没反应
func _tap_transfer() -> void:
	var m := current_map()
	if m.is_empty() or not bool(m.canTransfer) or (XMapTransfer.REQUIRE_UNLOCK and XMapTransfer.is_locked(XState.current, m)):
		XSound.system(3)
		return
	request_transfer()  # 缺传送道具时它自己蜂鸣


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
		XKeyMap.handled(self)


func _page_key(d: int) -> void:
	match mode:
		"list":
			_list_page(d)
		"drops", "detail":
			if mode == "detail" and DETAIL_LOCKS_DROPS:
				return
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
			if mode == "detail" and DETAIL_LOCKS_DROPS:
				return
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
	var list_r := list_win.get_rect()
	var info_r := info_win.get_rect()
	var confirm_r := confirm_win.get_rect()
	var rows := _list_rows()
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "list" and list_r.has_point(p):
				var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
				top = clampi(top + d, 0, maxi(0, XMapTransfer.maps().size() - rows))
				_refresh_list()
		MOUSE_BUTTON_LEFT:
			if mode == "list" and list_r.has_point(p):
				var i := top + floori((p - list_r.position - pad).y / LH)
				if i == index:
					confirm_map()
				elif i >= 0 and i < XMapTransfer.maps().size() and i < top + rows:
					XSound.system(0)
					_select(i)
			elif TAP_TRANSFER and mode == "drops" and list_r.has_point(p):
				var i := top + floori((p - list_r.position - pad).y / LH)
				if i == index:
					_tap_transfer()
				elif i >= 0 and i < XMapTransfer.maps().size() and i < top + rows:
					back_to_list()
					XSound.system(0)
					_select(i)
			elif TAP_TRANSFER and mode == "drops" and info_r.has_point(p) and p.y >= info_r.end.y - pad.y - LH:
				_tap_transfer()
			elif mode == "confirm" and confirm_r.has_point(p):
				var row := floori(((p - confirm_r.position - pad).y - LH - 12) / LH)
				if row == confirm_index:
					confirm_ok()
				elif row >= 0 and row < 2:
					confirm_index = row
					XSound.system(0)
					confirm_win.refresh()
		_:
			return
	accept_event()
