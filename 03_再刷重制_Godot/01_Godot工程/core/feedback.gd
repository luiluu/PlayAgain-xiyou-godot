class_name XFeedback
## 【cc·界面·未经审查】玩家反馈 QQ 群入口（Kyo 2026-11-13：让玩家加群反馈）。
## 群号只写在这里；标题右下角、开场警告屏、检查更新页、发行说明都从这里取。
## 点一下复制群号到剪贴板（DisplayServer.clipboard_set，Mac／Windows／安卓都能用）。
## 回退开关 SHOW = false：标题和警告屏不放群号行，更新页不加「复制群号」按钮（更新页文字照旧带群号）。

static var SHOW := true

const QQ_GROUP := "1097315054"
const LINE := "问题反馈 QQ 群：" + QQ_GROUP
const COPY_HINT := "（点击复制）"
const COPIED := "已复制群号 " + QQ_GROUP
const COPIED_SECONDS := 2.0


## 复制群号；返回复制进去的文字（测试比对用）
static func copy() -> String:
	DisplayServer.clipboard_set(QQ_GROUP)
	return QQ_GROUP


## 一个「点一下复制群号」的扁平按钮：不抢焦点（不影响键盘选菜单），点完两秒内显示「已复制」
static func make_button(font_size := 16, color := Color(1.0, 0.86, 0.5, 0.85)) -> Button:
	var b := Button.new()
	b.name = "FeedbackGroup"
	b.text = LINE + COPY_HINT
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", font_size)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, color if k == "font_color" else Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 4)
	# 「已复制」两秒后变回：计时器挂在按钮下面，按钮先没了（换页）计时器跟着没，不会回调到已释放的按钮
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = COPIED_SECONDS
	t.timeout.connect(func(): b.text = LINE + COPY_HINT)
	b.add_child(t)
	b.pressed.connect(func():
		copy()
		b.text = COPIED
		if t.is_inside_tree():
			t.start())
	return b
