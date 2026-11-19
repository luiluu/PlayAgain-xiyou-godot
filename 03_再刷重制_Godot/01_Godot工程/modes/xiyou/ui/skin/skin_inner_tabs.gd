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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, H)
	resized.connect(queue_redraw)


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
	var x := 0.0
	var base := size.y / 2.0 + fs * 0.36 - 2.0
	for i in tabs.size():
		var t := str(tabs[i])
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if x + w > size.x + 0.5:
			break
		var cur := i == index
		XUiSkin.ds(self, f, Vector2(x, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_HI if cur else XUiSkin.TEXT_2)
		if cur:
			draw_rect(Rect2(x, size.y - LINE_W - 1.0, w, LINE_W), XUiSkin.GOLD)
		x += w + GAP
