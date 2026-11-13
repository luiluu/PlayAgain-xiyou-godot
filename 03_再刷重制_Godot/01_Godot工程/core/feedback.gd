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
## 存档包（Kyo 同日「还想要有问题的存档」）：打开问卷前把存档目录整个打成 zip，放进系统「下载」文件夹（没有就桌面），
## 电脑上顺手打开那个文件夹；问卷最后一题让玩家上传。只读存档、不改存档。回退开关 EXPORT_SAVES = false：不打包。

static var SHOW := true

const QQ_GROUP := "1097315054"
const LINE := "问题反馈 QQ 群：" + QQ_GROUP
const COPY_HINT := "（点击复制）"
const COPIED := "已复制群号 " + QQ_GROUP
const COPIED_SECONDS := 2.0

static var FORM := true
static var FORM_URL := "https://wj.qq.com/s2/28674932/wf54/"
const FORM_LINE := "填写反馈问卷（免登录）"
const FORM_DONE := "已复制游戏信息，请粘贴到问卷第一题"
const FORM_DONE_SAVES := "已复制游戏信息；存档包已放进「下载」文件夹，请在问卷里上传"
const FORM_DONE_SECONDS := 6.0
static var EXPORT_SAVES := true
const ZIP_PREFIX := "再刷一把_存档_"
## 测试用：存档包放到这里，不写真「下载」文件夹
static var export_dir_override := ""
## 最近一次打的存档包路径（没打成为空）
static var last_export := ""
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


## 存档包放哪：系统「下载」文件夹，没有就桌面，再没有就存档目录旁边
static func export_dir() -> String:
	if export_dir_override != "":
		return export_dir_override
	for d in [OS.SYSTEM_DIR_DOWNLOADS, OS.SYSTEM_DIR_DESKTOP]:
		var p := OS.get_system_dir(d)
		if p != "" and DirAccess.dir_exists_absolute(p):
			return p
	return ProjectSettings.globalize_path("user://")


## 把存档目录（XSave.dir，含子目录）整个打成 zip；返回 zip 路径，没有存档或写不了返回 ""
static func export_saves() -> String:
	last_export = ""
	var src := XSave.dir()
	var files := _list_files(src, "")
	if files.is_empty():
		return ""
	var out := export_dir().path_join(ZIP_PREFIX + Time.get_datetime_string_from_system().replace(":", "").replace("T", "_") + ".zip")
	var zip := ZIPPacker.new()
	if zip.open(out) != OK:
		return ""
	for rel in files:
		var bytes := FileAccess.get_file_as_bytes(src.path_join(rel))
		if zip.start_file(rel) != OK or zip.write_file(bytes) != OK or zip.close_file() != OK:
			zip.close()
			DirAccess.remove_absolute(out)
			return ""
	if zip.close() != OK:
		return ""
	last_export = out
	return out


static func _list_files(root: String, rel: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(root.path_join(rel))
	if d == null:
		return out
	for f in d.get_files():
		out.append(rel.path_join(f) if rel != "" else f)
	for sub in d.get_directories():
		out.append_array(_list_files(root, rel.path_join(sub) if rel != "" else sub))
	return out


## 复制游戏信息、打存档包、打开问卷；返回复制进去的文字（测试比对用）
static func open_form() -> String:
	var info := info_line()
	last_export = ""
	if EXPORT_SAVES:
		var zip := export_saves()
		if zip != "":
			info += " · 存档包 " + zip.get_file()
			if not opener.is_valid() and not OS.has_feature("mobile"):  # 测试设了 opener 时也不开文件夹
				OS.shell_show_in_file_manager(zip)
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
	_on_press(b, FORM_LINE, FORM_DONE, open_form, FORM_DONE_SECONDS, func(): return FORM_DONE_SAVES if last_export != "" else FORM_DONE)
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
static func _on_press(b: Button, idle: String, done: String, action: Callable, seconds := COPIED_SECONDS, done_text := Callable()) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	t.timeout.connect(func(): b.text = idle)
	b.add_child(t)
	b.pressed.connect(func():
		action.call()
		b.text = done_text.call() if done_text.is_valid() else done
		if t.is_inside_tree():
			t.start())
