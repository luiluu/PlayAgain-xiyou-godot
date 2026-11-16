class_name XToast
extends CanvasLayer
## 事件脚本与一键存档的 $.toaster 提示（AXY_Toast，正式版参数）：网页层的提示框，盖在地图和菜单之上，换场景也不消失。
## 容器 (450,20) 宽 280；每条外边距 10、内边距 10，底色 rgba(0,0,0,0.7)，白字 18（游戏字体）、四向 1 像素阴影 rgba(0,0,0,0.5)；
## 淡入 0.6 秒（jQuery "slow"），出现 3 秒后用 0.6 秒淡出并收起高度，后面的提示随之上移。消息里的 <br> 换行，其余标签去掉。
## 消息提醒（installV019UsabilityRuntime）：按文字分类，类别关闭时不弹；菜单里操作得到的反馈（in_menu）照常显示。
## 原版种族/真气两类靠调用栈识别，这里由调用方传 key。
## 弹窗字号（XFontScale toast，重制新增，默认 100＝原版）：字号、行高按百分比放大，框宽跟着放宽、最多 1.5 倍（左边不动）。

const LEFT := 450.0
const TOP := 20.0
const WIDTH := 280.0
const MARGIN := 10.0
const PADDING := 10.0
const FONT_SIZE := 18
# 冻结源同字体 CSS normal 的实际行高为21。Label 字高取主字体与回退字体里最高的（Mac 有苹方时 27，Linux 文泉驿时 22），
# 所以不写死每侧减 3，而是按当前字高把行高收到 21（Mac 上仍是每侧减 3，结果不变）。
const LINE_HEIGHT := 21
const BACK := Color(0, 0, 0, 0.7)
const SHADOW := Color(0, 0, 0, 0.5)
const FADE := 0.6
const TIMEOUT := 3.0
const MAX_WIDEN := 1.5

static var shown: Array = []        # 出现过的提示文字（测试核对用）
var stack: VBoxContainer


## 显示一条提示（挂在场景树根上，跨场景保留，与原版网页层一样）
static func show_text(message: String, in_menu := false, key := "") -> void:
	if key == "":
		key = classify(message)
	if key != "" and not in_menu and not XConfig.notice_on(key):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := tree.root.get_node_or_null("XToast") as XToast
	if layer == null:
		layer = XToast.new()
		layer.name = "XToast"
		tree.root.add_child(layer)
	layer._add(message)


## U.classify 的文字规则（正则同原版）
static func classify(message: String) -> String:
	for rule in [["^宝箱收获", "chest"], ["肝帝积分 *[+＋]|滑稽值 *[+＋]|抽奖券额外", "points"],
			["专属掉落|权能掉落|获得锻造材料", "drop"], ["已领悟", "learn"],
			["副本挑战完成|逃离副本|进入副本，关闭挂机", "dungeon"], ["^技能共享|^羁绊：", "share"]]:
		if RegEx.create_from_string(rule[0]).search(message):
			return rule[1]
	return ""


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


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)


## 按弹窗字号算出的 [字号, 行高, 框宽]
static func metrics() -> Array:
	var k := XFontScale.scaled(1.0, "toast")
	if XUiSkin.on():
		return [maxi(XUiSkin.FS_MIN, roundi(17.0 * k)), roundi(25.0 * k), 340.0 * minf(k, MAX_WIDEN)]
	return [roundi(FONT_SIZE * k), roundi(LINE_HEIGHT * k), WIDTH * minf(k, MAX_WIDEN)]


func _add(message: String) -> void:
	var on := XUiSkin.on()
	var text := plain(message)
	shown.append(text)
	var m := metrics()
	var font_size: int = m[0]
	var line_height: int = m[1]
	var width: float = m[2]
	var vs := _view_size()
	if on:
		width = minf(width, vs.x - XSkinLayout.margin_for(vs.x) * 2.0)
		stack.position = Vector2(roundf((vs.x - width) / 2.0) + MARGIN, TOP + MARGIN)
	else:
		stack.position = Vector2(LEFT + MARGIN, TOP + MARGIN)
	stack.custom_minimum_size.x = width - MARGIN * 2
	var pad_x := 16.0 if on else PADDING
	var pad_y := 12.0 if on else PADDING
	var inner := width - MARGIN * 2 - pad_x * 2
	var font := FontVariation.new()
	font.base_font = XUiSkin.font("body") if on else XUI.font()
	var trim := line_height - int(font.get_height(font_size))   # 上下合计要减的像素（回退字体更矮时可能为 -1 之类）
	font.spacing_top = floori(trim / 2.0)
	font.spacing_bottom = trim - floori(trim / 2.0)
	# 外层只占高度、裁掉内容：收起时把高度缩到 0，后面的提示跟着上移（jQuery animate height → 0）
	var slot := Control.new()
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size.x = width - MARGIN * 2
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size.x = width - MARGIN * 2
	var style := StyleBoxFlat.new()
	if on:
		style.bg_color = Color(XUiSkin.PANEL_LOW.lerp(XUiSkin.PANEL, 0.45), 0.94)
		style.border_color = Color(XUiSkin.GOLD if text.begins_with("已生效") or text.begins_with("已使用") else XUiSkin.LINE, 0.48)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.shadow_color = Color(0, 0, 0, 0.48)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
		style.content_margin_left = pad_x + 6.0
		style.content_margin_right = pad_x
		style.content_margin_top = pad_y
		style.content_margin_bottom = pad_y
	else:
		style.bg_color = BACK
		style.set_content_margin_all(PADDING)
	box.add_theme_stylebox_override("panel", style)
	var accent: ColorRect = null
	if on:
		# 左边 3px 金色竖条。T095（Kyo 11-16「存档成功」带一条黄底）：原先挂在 PanelContainer 下，容器把它撑满内容区，
		# 成了字底下一整块金底；改挂在外层 slot（普通 Control，锚点生效），画在框上面
		accent = ColorRect.new()
		accent.name = "Accent"
		accent.color = XUiSkin.GOLD
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		accent.offset_left = 8
		accent.offset_right = 11
		accent.offset_top = 8
		accent.offset_bottom = -8
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 与浏览器一样：句末标点不单独起行
	label.add_theme_font_override("font", font)
	label.add_theme_constant_override("line_spacing", 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", XUiSkin.TEXT if on else Color.WHITE)
	if on:
		label.add_theme_constant_override("outline_size", 0)
	else:
		label.add_theme_color_override("font_outline_color", SHADOW)
		label.add_theme_constant_override("outline_size", 2)
	label.size.x = inner - (6.0 if on else 0.0)
	box.add_child(label)
	# 用Label实际塑形后的高度排栈，避免预估字体尚未加载回退度量。
	var h := label.get_minimum_size().y + pad_y * 2
	box.size.y = h
	slot.custom_minimum_size.y = h
	slot.add_child(box)
	if accent != null:
		slot.add_child(accent)
	slot.modulate.a = 0.0
	stack.add_child(slot)
	# 入树后的Container排序与回退字形塑形会再修正最小高度；栈同步实际框高。
	var fit := func(): slot.custom_minimum_size.y = box.get_combined_minimum_size().y
	box.minimum_size_changed.connect(fit)
	fit.call_deferred()
	var tw := slot.create_tween()
	tw.tween_property(slot, "modulate:a", 1.0, FADE)
	tw.tween_interval(TIMEOUT - FADE)
	tw.tween_callback(func(): box.minimum_size_changed.disconnect(fit))
	tw.tween_property(slot, "modulate:a", 0.0, FADE)
	tw.parallel().tween_property(slot, "custom_minimum_size:y", 0.0, FADE)
	tw.tween_callback(slot.queue_free)
