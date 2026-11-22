class_name XSkinInnerTabs
extends Control
## 【cc·天启篇·未经审查】T283 通用小件「页内页签」（T254 3.0）：一排字，17 号 TEXT_2；当前页 TEXT_HI＋2px 旧金下划线。
## 红色只给光标，不给页签（页签自己不画选中条）。放在列表标题下面一行（商店出售的「物品 消耗品 武器 护甲 重要物品」）。
## - 按键：handle_input 认 Q／E（XMenu.page_dir：Q 前一个、E 后一个，到头循环），发 changed(i)。别的键不接。
##   要不要响音由页面定（sound＝true 时自己响光标音）。
## - 点：点哪个字就换到哪个（发 changed）。
## - 项多放不下：按每项字宽从左排，超出的不画（商店五项、设置子页三四项都放得下）。
## 用法：
##   var tabs := XSkinInnerTabs.new(); list_panel.add_child(tabs)
##   tabs.set_tabs(["物品", "消耗品", "武器", "护甲", "重要物品"], 0)
##   tabs.changed.connect(func(i): …换列表…)
##   # 页面按键：if tabs.visible and tabs.handle_input(event): return true

signal changed(index: int)

const H := 32.0
const FS := 17
const GAP := 24.0
const LINE_W := 2.0

var tabs: Array = []
var index := 0
var sound := false
## T359 D255：页签条的焦点态。Q／E 换页（或点页签）＝页签条拿到焦点，当前页签外画淡金双环（键盘／手柄态才画）；
## 之后按了别的键（上下左右、确定、取消等）就放掉。DETAIL_V1 关＝不画。页面不用管，条自己听输入
## 页签拿焦点时要一起降静默的列表（可空）；页面自己的静默条件（数量态等）另算，别把它冲掉
var linked_list: XSkinList
var focused := false:
	set(v):
		if focused == v:
			return
		focused = v
		if linked_list != null and is_instance_valid(linked_list):
			linked_list.quiet = v   # 页签亮焦点时同屏的列表选中行降静默
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, H)
	resized.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not XUiSkin.detail_on():
		if focused:
			focused = false
		return
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed():
		return
	if event is InputEventKey and event.echo:
		return
	focused = XMenu.page_dir(event) != 0 and tabs.size() > 1


func set_tabs(arr: Array, i := 0) -> void:
	tabs = arr.map(func(t): return str(t))
	index = clampi(i, 0, maxi(tabs.size() - 1, 0))
	queue_redraw()


## 换到第 i 个；变了发 changed
func select(i: int, emit := true) -> bool:
	if tabs.is_empty():
		return false
	i = posmod(i, tabs.size())
	if i == index:
		return false
	index = i
	queue_redraw()
	if sound:
		XSound.system(0)
	if emit:
		changed.emit(index)
	return true


func handle_input(event: InputEvent) -> bool:
	var d := XMenu.page_dir(event)
	if d == 0 or tabs.size() < 2:
		return false
	select(index + d)
	return true


func tab_rect(i: int) -> Rect2:
	var f := XUiSkin.font("body")
	var fs := XUiSkin.fs(FS)
	var x := 0.0
	for j in tabs.size():
		var w := f.get_string_size(str(tabs[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if j == i:
			return Rect2(x - GAP / 2.0, 0, w + GAP, size.y)
		x += w + GAP
	return Rect2()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in tabs.size():
			if tab_rect(i).has_point(event.position):
				select(i)
				accept_event()
				return


func _draw() -> void:
	var f := XUiSkin.font("body")
	var fs := XUiSkin.fs(FS)
	var pol := XUiSkin.polish_on()
	var ci := get_canvas_item()
	var x := 0.0
	var base := size.y / 2.0 + fs * 0.36 - 2.0
	for i in tabs.size():
		var t := str(tabs[i])
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if x + w > size.x + 0.5:
			break
		var cur := i == index
		if pol:
			# 两侧留白对称：首尾页签贴着控件边时左右一起收窄，不画出控件
			var pad_x := clampf(minf(x, size.x - x - w), 0.0, 8.0)
			var tr := Rect2(x - pad_x, 2.0, w + pad_x * 2.0, size.y - 5.0)
			var tsb := StyleBoxFlat.new()
			tsb.bg_color = Color(XUiSkin.GOLD, 0.10) if cur else Color(0.05, 0.042, 0.04, 0.28)
			tsb.set_corner_radius_all(5)
			tsb.draw(ci, tr)
		XUiSkin.ds(self, f, Vector2(x, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_HI if cur else XUiSkin.TEXT_2)
		if cur:
			if pol:
				draw_rect(Rect2(x - 2.0, size.y - LINE_W - 2.0, w + 4.0, LINE_W + 2.0), Color(XUiSkin.GOLD, 0.22))
			draw_rect(Rect2(x, size.y - LINE_W - 1.0, w, LINE_W), XUiSkin.GOLD)
		x += w + GAP
	if focused and XUiSkin.detail_on() and XUiSkin.show_focus_ring() and index >= 0 and index < tabs.size():
		XUiSkin.draw_focus_ring(ci, ring_rect(), 5)


## 焦点环围着的矩形：当前页签的底托（左右各 8、上 2、高 size.y-5，同 _draw 里 polish 的底托）
func ring_rect() -> Rect2:
	var r := tab_rect(index)
	var f := XUiSkin.font("body")
	var w := f.get_string_size(str(tabs[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(FS)).x
	var x := r.position.x + GAP / 2.0
	var pad_x := clampf(minf(x, size.x - x - w), 0.0, 8.0)
	return Rect2(x - pad_x, 2.0, w + pad_x * 2.0, size.y - 5.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		focused = false
