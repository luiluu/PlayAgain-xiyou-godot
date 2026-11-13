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

const GROUP_HINT := "请到 QQ 群 " + XFeedback.QQ_GROUP + " 的群文件下载"
const W := 760.0
const LAYER := 90
const SCROLL_STEP := 72.0

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
var _close: Button
var _panel: PanelContainer
var _scroll: ScrollContainer
var _more: Label
var _rollback: Button
var _rollback_armed := false
var _notice := ""
var installer: XUpdateInstall


## 页面放进单独的 CanvasLayer（盖在标题、logo 和一切画面之上，按整个视口居中），挂在 host 下，关页面时一起删。
static func open(host: Node) -> XUpdatePage:
	var layer := CanvasLayer.new()
	layer.name = "UpdateLayer"
	layer.layer = LAYER
	var p := XUpdatePage.new()
	p.name = "UpdatePage"
	layer.add_child(p)
	host.add_child(layer)
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
			# 版本、大小或去哪下放在前面，更新说明放最后（说明长了在框里滚动，按钮始终看得见）
			var lines := PackedStringArray()
			var date := str(result.get("date", ""))
			lines.append("新版本 %s%s" % [result.get("version", ""), "（%s）" % date if date != "" else ""])
			lines.append("当前版本 %s" % cur)
			var patch: Dictionary = result.get("patch", {})
			var installable: bool = result["state"] == XUpdateCheck.PATCH and can_install
			if installable:
				lines.append("更新大小 %s" % size_text(int(patch.get("size", 0))))
			else:
				lines.append("%s %s" % [GROUP_HINT, result.get("version", "")])
			var notes: Array = Array(result.get("notes", PackedStringArray()))
			if not notes.is_empty():
				lines.append("")
				lines.append("更新内容")
				for n in notes:
					lines.append("· " + str(n))
			return {"title": "有新版本", "body": "\n".join(lines), "primary": "立即更新" if installable else ""}
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
	# 挂在自己的 CanvasLayer 下（open 里建），锚点铺满就是整个视口
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = XUI.theme()
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # 点框里不算点外面
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.96)
	style.border_color = Color(0.86, 0.72, 0.38, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 18
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_title = XUI.label("", 32, Color(1.0, 0.86, 0.5))
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var line := ColorRect.new()
	line.color = Color(0.86, 0.72, 0.38, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	box.add_child(_scroll)
	_body = XUI.label("", 22)
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_more = XUI.label("↑↓ 滚动查看全部内容", 16, XUI.DIM)
	_more.name = "More"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_more)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 32)
	box.add_child(_buttons)
	_primary = _make_button("立即更新")
	_primary.name = "Primary"
	_primary.pressed.connect(_on_primary)
	_buttons.add_child(_primary)
	_close = _make_button("关闭")
	_close.name = "Close"
	_close.pressed.connect(close_page)
	_buttons.add_child(_close)
	# 反馈群（XFeedback）：按钮下面一行，点一下复制群号；不抢焦点，确定／取消键照旧
	if XFeedback.SHOW:
		var fb := XFeedback.make_button(18)
		fb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(fb)
	_rollback = XUI.button("退回安装包自带版本", 36)
	_rollback.name = "Rollback"
	_rollback.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rollback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rollback.add_theme_font_size_override("font_size", 18)
	_rollback.pressed.connect(_on_rollback)
	_rollback.visible = bool(XUpdateInstall.BootPatchScript.result.get("loaded", false))
	box.add_child(_rollback)
	_fit()
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
	_set_body(_notice + t["body"])
	_primary.visible = t["primary"] != ""
	_primary.text = t["primary"] if t["primary"] != "" else "立即更新"
	_close.text = "稍后再说" if state == XUpdateCheck.PATCH and _primary.visible else "关闭"
	_scroll.scroll_vertical = 0
	_focus_default.call_deferred()


func _set_body(text: String) -> void:
	_body.text = text
	_fit()


## 框的宽高跟着视口：说明区最多占到放得下按钮为止，超出就在框里滚动。
func _fit() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var w := minf(W, vp.x - 64.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	var inner := w - 64.0
	_body.custom_minimum_size = Vector2(inner - 12.0, 0)
	var lh := float(_body.get_line_height())
	var lines := _wrapped_lines(inner - 12.0)
	var want := lines * (lh + 2.0) + 4.0
	# 标题、分隔线、提示、按钮、退回、上下边距大约占的高度
	var chrome := 44.0 + 2.0 + 22.0 + 48.0 + (44.0 if _rollback != null and _rollback.visible else 0.0) + 44.0 + 12.0 * 5
	var cap := maxf(120.0, vp.y - 64.0 - chrome)
	var h := minf(want, cap)
	_scroll.custom_minimum_size = Vector2(inner, h)
	_more.visible = want > cap + 1.0


## 按给定宽度估算换行后的行数（Label 还没排版时 get_line_count 不准）
func _wrapped_lines(width: float) -> int:
	var font := _body.get_theme_font("font")
	var fs := _body.get_theme_font_size("font_size")
	var n := 0
	for para in _body.text.split("\n"):
		var pw := font.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		n += maxi(1, int(ceil(pw / maxf(1.0, width))))
	return n


func _focus_default() -> void:
	if is_inside_tree():
		(_primary if _primary.visible else _close).grab_focus()


func _focus_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b in [_primary, _close, _rollback]:
		if b != null and b.visible:
			out.append(b)
	return out


## 当前选中的按钮（焦点不在本页按钮上时按默认算）
func focused_button() -> Button:
	var f := get_viewport().gui_get_focus_owner()
	var bs := _focus_buttons()
	if f in bs:
		return f
	return _primary if _primary.visible else _close


func _make_button(text: String) -> Button:
	var b := XUI.button(text, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size.x = 200
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.border_color = Color(0.86, 0.72, 0.38, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.86, 0.72, 0.38, 0.28)
	hot.border_color = Color(1.0, 0.86, 0.5)
	hot.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hot)
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.7))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.7))
	return b


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
	if is_queued_for_deletion():
		return
	closed.emit()
	var layer := get_parent()
	if layer is CanvasLayer and layer.name == "UpdateLayer":
		layer.queue_free()
	else:
		queue_free()


func _gui_input(event: InputEvent) -> void:
	# 点到框外的暗处才关（框里的空白、滚轮都不算）
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		if not _panel.get_global_rect().has_point(event.global_position):
			close_page()


## 这一页开着时键盘、手柄全部在这里处理，一个都不漏到下面的标题菜单：
## 左右／Tab 换按钮，上下／翻页键滚动说明，确定键按下选中的按钮，取消键关掉。
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return
	XKeyMap.handled(self)
	if is_queued_for_deletion() or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel"):
		close_page()
	elif event.is_action_pressed("ui_accept"):
		focused_button().pressed.emit()
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_focus_prev", true):
		_move_focus(-1)
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_focus_next", true):
		_move_focus(1)
	elif event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= int(SCROLL_STEP)
	elif event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += int(SCROLL_STEP)
	elif event.is_action_pressed("ui_page_up", true):
		_scroll.scroll_vertical -= int(_scroll.size.y * 0.8)
	elif event.is_action_pressed("ui_page_down", true):
		_scroll.scroll_vertical += int(_scroll.size.y * 0.8)


func _move_focus(d: int) -> void:
	var bs := _focus_buttons()
	if bs.is_empty():
		return
	var i := bs.find(focused_button())
	bs[posmod(i + d, bs.size())].grab_focus()
