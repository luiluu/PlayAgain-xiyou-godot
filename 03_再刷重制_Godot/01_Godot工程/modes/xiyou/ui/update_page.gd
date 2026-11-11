class_name XUpdatePage
extends Control
## 自动更新第①批：「检查更新」页（弹在标题上面的一页）。
## 标题的按钮这样接：actions["check_update"] = func(): XUpdatePage.open(self)；红点看 XUpdateClient.instance(get_tree()).has_update()。
## 打开就查一次（手动查不受每天一次的限制），按结果显示五种状态：
##   正在检查／已是最新／有补丁／要换整包／读不到。
## 有补丁时：第②批装上下载器（patch_installer）之前，按「要换整包」同样提示去 QQ 群。
## 确定／取消键、点按钮、点页面外的暗处都能关。不自动打开网页、不下载任何东西。

signal closed

const GROUP_HINT := "请到 QQ 群文件下载"
const W := 640.0

## 第②批接进来：Callable(page: XUpdatePage, result: Dictionary)。空＝还不能在游戏内装补丁。
static var patch_installer: Callable

var client: XUpdateClient
var state := "checking"
var _title: Label
var _body: Label
var _buttons: HBoxContainer
var _primary: Button


static func open(host: Node) -> XUpdatePage:
	var p := XUpdatePage.new()
	p.name = "UpdatePage"
	host.add_child(p)
	return p


## 各状态显示的标题和正文（纯函数，测试直接比文字）。
static func texts(result: Dictionary, can_install: bool) -> Dictionary:
	var cur := str(result.get("current", ""))
	match str(result.get("state", "")):
		"checking":
			return {"title": "检查更新", "body": "正在检查……", "primary": ""}
		XUpdateCheck.LATEST:
			return {"title": "已是最新版本", "body": "当前版本 %s" % cur, "primary": ""}
		XUpdateCheck.PATCH, XUpdateCheck.FULL:
			var lines := PackedStringArray()
			var date := str(result.get("date", ""))
			lines.append("新版本 %s%s" % [result.get("version", ""), "（%s）" % date if date != "" else ""])
			lines.append("当前版本 %s" % cur)
			for n in result.get("notes", PackedStringArray()):
				lines.append("· " + str(n))
			var patch: Dictionary = result.get("patch", {})
			if result["state"] == XUpdateCheck.PATCH and can_install:
				lines.append("更新大小 %s" % size_text(int(patch.get("size", 0))))
				return {"title": "有新版本", "body": "\n".join(lines), "primary": "立即更新"}
			lines.append("%s %s" % [GROUP_HINT, result.get("version", "")])
			return {"title": "有新版本", "body": "\n".join(lines), "primary": ""}
		_:
			return {"title": "暂时查不到", "body": "连不上更新服务器。\n当前版本 %s，新版本%s。" % [cur, GROUP_HINT], "primary": ""}


static func size_text(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.1f MB" % (bytes / 1048576.0)
	return "%d KB" % maxi(1, int(ceil(bytes / 1024.0)))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = XUI.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(W, 0)
	panel.add_theme_stylebox_override("panel", XUI.panel(240))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_title = XUI.label("", 28, XUI.SYSTEM)
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = XUI.label("", 22)
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(W - 48, 0)
	box.add_child(_body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 24)
	box.add_child(_buttons)
	_primary = XUI.button("立即更新")
	_primary.name = "Primary"
	_primary.pressed.connect(_on_primary)
	_buttons.add_child(_primary)
	var close := XUI.button("关闭")
	close.name = "Close"
	close.pressed.connect(close_page)
	_buttons.add_child(close)
	show_result({"state": "checking"})
	client = XUpdateClient.instance(get_tree())
	_check.call_deferred()


func _check() -> void:
	var r: Dictionary = await client.check()
	if is_inside_tree():
		show_result(r)


func show_result(result: Dictionary) -> void:
	state = str(result.get("state", XUpdateCheck.BAD))
	set_meta("result", result)
	var t := texts(result, patch_installer.is_valid())
	_title.text = t["title"]
	_body.text = t["body"]
	_primary.visible = t["primary"] != ""
	_primary.text = t["primary"] if t["primary"] != "" else "立即更新"
	((_primary if _primary.visible else _buttons.get_node("Close")) as Button).grab_focus.call_deferred()


func _on_primary() -> void:
	if state == XUpdateCheck.PATCH and patch_installer.is_valid():
		patch_installer.call(self, get_meta("result"))


func close_page() -> void:
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:  # 点到页面外的暗处
		accept_event()
		close_page()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_page()
	elif event is InputEventKey or event is InputEventJoypadButton:
		# 这一页开着时键盘和手柄不漏到下面的标题菜单；确定键交给有焦点的按钮
		if not event.is_action("ui_accept") and not event.is_action("ui_left") and not event.is_action("ui_right") \
				and not event.is_action("ui_focus_next") and not event.is_action("ui_focus_prev"):
			get_viewport().set_input_as_handled()
