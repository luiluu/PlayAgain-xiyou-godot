class_name XToast
extends CanvasLayer
## 事件脚本与一键存档的 $.toaster 提示（AXY_Toast，正式版参数）：网页层的提示框，盖在地图和菜单之上，换场景也不消失。
## 容器 (450,20) 宽 280；每条外边距 10、内边距 10，底色 rgba(0,0,0,0.7)，白字 18（游戏字体）、四向 1 像素阴影 rgba(0,0,0,0.5)；
## 淡入 0.6 秒（jQuery "slow"），出现 3 秒后用 0.6 秒淡出并收起高度，后面的提示随之上移。消息里的 <br> 换行，其余标签去掉。

const LEFT := 450.0
const TOP := 20.0
const WIDTH := 280.0
const MARGIN := 10.0
const PADDING := 10.0
const FONT_SIZE := 18
const BACK := Color(0, 0, 0, 0.7)
const SHADOW := Color(0, 0, 0, 0.5)
const FADE := 0.6
const TIMEOUT := 3.0

static var shown: Array = []        # 出现过的提示文字（测试核对用）
var stack: VBoxContainer


## 显示一条提示（挂在场景树根上，跨场景保留，与原版网页层一样）
static func show_text(message: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := tree.root.get_node_or_null("XToast") as XToast
	if layer == null:
		layer = XToast.new()
		layer.name = "XToast"
		tree.root.add_child(layer)
	layer._add(message)


static func plain(message: String) -> String:
	var t := message.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
	return RegEx.create_from_string("<[^>]*>").sub(t, "", true).replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&")


func _init() -> void:
	layer = 90
	stack = VBoxContainer.new()
	stack.position = Vector2(LEFT + MARGIN, TOP + MARGIN)
	stack.custom_minimum_size.x = WIDTH - MARGIN * 2
	stack.add_theme_constant_override("separation", int(MARGIN))
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)


func _add(message: String) -> void:
	var text := plain(message)
	shown.append(text)
	var inner := WIDTH - MARGIN * 2 - PADDING * 2
	var h := XUI.font().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT_SIZE).y + PADDING * 2
	# 外层只占高度、裁掉内容：收起时把高度缩到 0，后面的提示跟着上移（jQuery animate height → 0）
	var slot := Control.new()
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(WIDTH - MARGIN * 2, h)
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(WIDTH - MARGIN * 2, h)
	var style := StyleBoxFlat.new()
	style.bg_color = BACK
	style.set_content_margin_all(PADDING)
	box.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.add_theme_font_override("font", XUI.font())
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", SHADOW)
	label.add_theme_constant_override("outline_size", 2)
	box.add_child(label)
	slot.add_child(box)
	slot.modulate.a = 0.0
	stack.add_child(slot)
	var tw := slot.create_tween()
	tw.tween_property(slot, "modulate:a", 1.0, FADE)
	tw.tween_interval(TIMEOUT - FADE)
	tw.tween_property(slot, "modulate:a", 0.0, FADE)
	tw.parallel().tween_method(func(v: float): slot.custom_minimum_size.y = v, h, 0.0, FADE)
	tw.tween_callback(slot.queue_free)
