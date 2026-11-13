class_name XFeedback
## 【cc·界面·未经审查】玩家反馈 QQ 群入口（Kyo 2026-11-13：让玩家加群反馈）。
## 群号只写在这里；标题右下角、开场警告屏、检查更新页、发行说明都从这里取。
## 点一下复制群号到剪贴板（DisplayServer.clipboard_set，Mac／Windows／安卓都能用）。
## 回退开关 SHOW = false：标题和警告屏不放群号行，更新页不加「复制群号」按钮（更新页文字照旧带群号）。
##
## 反馈问卷（Kyo 2026-11-13：玩家免账号、不走 Gitee、大陆能用 → 腾讯问卷免费版）：
## 点「填写反馈问卷」先把版本、平台、机型这一行复制到剪贴板，再用系统浏览器打开问卷；问卷第一题让玩家粘贴。
## 免费版不支持链接预填，所以走剪贴板。问卷链接是公开的，不是密钥；包里不放任何密钥。
## FORM_URL 为空＝还没有问卷，不放按钮。回退开关 FORM = false：标题和更新页不放问卷按钮，只留 QQ 群。

static var SHOW := true

const QQ_GROUP := "1097315054"
const LINE := "问题反馈 QQ 群：" + QQ_GROUP
const COPY_HINT := "（点击复制）"
const COPIED := "已复制群号 " + QQ_GROUP
const COPIED_SECONDS := 2.0

static var FORM := true
static var FORM_URL := ""
const FORM_LINE := "填写反馈问卷（免登录）"
const FORM_DONE := "已复制游戏信息，请粘贴到问卷第一题"
## 测试用：替换「打开网页」，收到要打开的链接；不设＝OS.shell_open
static var opener := Callable()


static func has_form() -> bool:
	return FORM and FORM_URL != ""


## 问卷第一题要粘贴的一行：游戏版本、系统、机型、系统版本、屏幕大小
static func info_line() -> String:
	var parts: Array[String] = ["再刷一把 " + XVersionLabel.version_text(), OS.get_name()]
	var model := OS.get_model_name()
	if model != "" and model != "GenericDevice":
		parts.append(model)
	if OS.get_version() != "":
		parts.append(OS.get_version())
	if DisplayServer.get_name() != "headless":
		var sz := DisplayServer.screen_get_size()
		parts.append("%dx%d" % [sz.x, sz.y])
	return " · ".join(parts)


## 复制游戏信息、打开问卷；返回复制进去的文字（测试比对用）
static func open_form() -> String:
	var info := info_line()
	DisplayServer.clipboard_set(info)
	if opener.is_valid():
		opener.call(FORM_URL)
	elif FORM_URL != "":
		OS.shell_open(FORM_URL)
	return info


## 复制群号；返回复制进去的文字（测试比对用）
static func copy() -> String:
	DisplayServer.clipboard_set(QQ_GROUP)
	return QQ_GROUP


## 「填写反馈问卷」扁平按钮：样子同群号按钮，点了复制游戏信息、打开问卷，两秒内提示去粘贴
static func make_form_button(font_size := 16, color := Color(0.6, 0.9, 1.0, 0.9)) -> Button:
	var b := _flat(FORM_LINE, font_size, color)
	b.name = "FeedbackForm"
	_on_press(b, FORM_LINE, FORM_DONE, open_form)
	return b


## 一个「点一下复制群号」的扁平按钮：不抢焦点（不影响键盘选菜单），点完两秒内显示「已复制」
static func make_button(font_size := 16, color := Color(1.0, 0.86, 0.5, 0.85)) -> Button:
	var b := _flat(LINE + COPY_HINT, font_size, color)
	b.name = "FeedbackGroup"
	_on_press(b, LINE + COPY_HINT, COPIED, copy)
	return b


static func _flat(text: String, font_size: int, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", font_size)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, color if k == "font_color" else Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 4)
	return b


## 点了执行 action，按钮文字换成 done，两秒后变回 idle。
## 计时器挂在按钮下面，按钮先没了（换页）计时器跟着没，不会回调到已释放的按钮
static func _on_press(b: Button, idle: String, done: String, action: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = COPIED_SECONDS
	t.timeout.connect(func(): b.text = idle)
	b.add_child(t)
	b.pressed.connect(func():
		action.call()
		b.text = done
		if t.is_inside_tree():
			t.start())
