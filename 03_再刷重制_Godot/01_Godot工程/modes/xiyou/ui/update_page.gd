class_name XUpdatePage
extends Control
## 自动更新第①批：「检查更新」页（弹在标题上面的一页）。
## 标题的按钮这样接：actions["check_update"] = func(): XUpdatePage.open(self)；红点看 XUpdateClient.instance(get_tree()).has_update()。
## 打开就查一次（手动查不受每天一次的限制），按结果显示五种状态：
##   正在检查／已是最新／有补丁／要换整包／读不到。
## 有补丁时（第②批）：点「立即更新」在游戏内下载（XUpdateInstall：多源、续传、校验），下完备份存档、登记，提示重启生效；
## 下载中可以取消，已下的部分留着下次接着下。XUpdateInstall.ENABLED 关着时照「要换整包」提示去 QQ 群。
## 正在用补丁时页面下方有「退回安装包自带版本」（点两次才执行）；启动失败被自动退回、或版本被撤回时在这里说明。
## 确定／取消键、点按钮、点页面外的暗处都能关。不自动打开网页、不下载任何东西。

signal closed

const GROUP_HINT := "请到 QQ 群文件下载"
const W := 640.0

## 换掉下载安装那一步（测试用）：Callable(page: XUpdatePage, result: Dictionary)。空＝用 XUpdateInstall。
static var patch_installer: Callable

const DOWNLOADING := "downloading"
const READY := "ready"          # 已下载登记好，等重启
const FAILED := "failed"
const ROLLED := "rolled"        # 已手动退回，等重启

var client: XUpdateClient
var state := "checking"
var _title: Label
var _body: Label
var _buttons: HBoxContainer
var _primary: Button
var _rollback: Button
var _rollback_armed := false
var _notice := ""
var installer: XUpdateInstall


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
		DOWNLOADING:
			return {"title": "正在下载更新", "body": "%s / %s\n可以取消，已下的部分会留着，下次接着下。" % [size_text(int(result.get("done", 0))), size_text(int(result.get("total", 0)))], "primary": "取消下载"}
		READY:
			return {"title": "更新已准备好", "body": "新版本 %s 已下载，存档已备份。\n重启游戏后生效。" % result.get("version", ""), "primary": "退出游戏" if OS.get_name() == "Android" else "立即重启"}
		FAILED:
			return {"title": "下载没完成", "body": "%s\n已下的部分留着，下次接着下；也可以%s %s。" % [result.get("message", "网络不通或空间不够。"), GROUP_HINT, result.get("version", "")], "primary": "再试一次"}
		ROLLED:
			return {"title": "已退回", "body": "重启游戏后回到%s。" % result.get("target", "安装包自带版本"), "primary": "退出游戏" if OS.get_name() == "Android" else "立即重启"}
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
	_rollback = XUI.button("退回安装包自带版本", 36)
	_rollback.name = "Rollback"
	_rollback.add_theme_font_size_override("font_size", 18)
	_rollback.pressed.connect(_on_rollback)
	_rollback.visible = bool(XUpdateInstall.BootPatchScript.result.get("loaded", false))
	box.add_child(_rollback)
	installer = XUpdateInstall.instance(get_tree())
	installer.progress.connect(_on_progress)
	var rb := XUpdateInstall.take_rollback_notice()
	if not rb.is_empty():
		_notice = "上次的更新 %s 没能用上（%s），已退回。\n" % [XUpdateCheck.version_of(int(rb.get("code", 0))), rb.get("reason", "")]
	client = XUpdateClient.instance(get_tree())
	var pending := XUpdateInstall.pending_code()
	if pending > 0:  # 已经下好登记了，只差重启
		show_result({"state": READY, "version": XUpdateCheck.version_of(pending)})
		return
	show_result({"state": "checking"})
	_check.call_deferred()


func _check() -> void:
	var r: Dictionary = await client.check()
	if not is_inside_tree():
		return
	if r.get("revoked", false):  # 现在用的这一版被撤回了：退回上一份，下次启动生效
		var back := XUpdateInstall.rollback(false, "已撤回")
		_notice += "当前版本已被撤回，重启后回到%s。\n" % (XUpdateCheck.version_of(back) if back > 0 else "安装包自带版本")
	show_result(r)


func show_result(result: Dictionary) -> void:
	state = str(result.get("state", XUpdateCheck.BAD))
	set_meta("result", result)
	var t := texts(result, patch_installer.is_valid() or XUpdateInstall.ENABLED)
	_title.text = t["title"]
	_body.text = _notice + t["body"]
	_primary.visible = t["primary"] != ""
	_primary.text = t["primary"] if t["primary"] != "" else "立即更新"
	((_primary if _primary.visible else _buttons.get_node("Close")) as Button).grab_focus.call_deferred()


func _on_primary() -> void:
	match state:
		XUpdateCheck.PATCH:
			if patch_installer.is_valid():
				patch_installer.call(self, get_meta("result"))
			else:
				_install(get_meta("result"))
		DOWNLOADING:
			installer.cancel()
		FAILED:
			_install(get_meta("result").get("source", {}))
		READY, ROLLED:
			XUpdateInstall.restart(get_tree())


## 下载、校验、备份存档、登记。result 是 state＝patch 的检查结果。
func _install(result: Dictionary) -> void:
	var patch: Dictionary = result.get("patch", {})
	if patch.is_empty() or installer.busy:
		return
	var total := int(patch.get("size", 0))
	if not XUpdateInstall.enough_space(total):
		show_result({"state": FAILED, "version": result.get("version", ""), "message": "剩余空间不够。", "source": result})
		return
	show_result({"state": DOWNLOADING, "done": 0, "total": total, "source": result})
	var base := XUpdateClient.base_code()
	var path := await installer.download(patch, base)
	var ok := path != "" and XUpdateInstall.register(patch, base)
	if not is_inside_tree():
		return
	if ok:
		show_result({"state": READY, "version": result.get("version", "")})
	else:
		show_result({"state": FAILED, "version": result.get("version", ""), "source": result,
			"message": "已取消。" if path == "" and installer._cancelled else ("存档备份或登记没成功。" if path != "" else "网络不通或文件不对。")})


func _on_progress(done: int, total: int) -> void:
	if state == DOWNLOADING:
		var r: Dictionary = get_meta("result")
		r["done"] = done
		r["total"] = total
		_body.text = _notice + texts(r, true)["body"]


func _on_rollback() -> void:
	if not _rollback_armed:
		_rollback_armed = true
		_rollback.text = "再点一次确认退回"
		return
	XUpdateInstall.rollback(true)
	_rollback.visible = false
	show_result({"state": ROLLED})


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
