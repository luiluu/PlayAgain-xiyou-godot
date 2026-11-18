class_name XConfigTransferScene
extends Control
## T154 设置「导入／导出配置」子页（玩家建议，Kyo 11-17）。版式照「消息提醒」子页（XNoticeOptionsScene）：
## 上面标题窗（标题＋一行说明／结果），下面列表。逻辑都在 XConfigTransfer。
## - 导出到剪贴板：复制到剪贴板；导出到文件（PC／Mac）：存进「下载」文件夹。
## - 从剪贴板导入／从文件导入（PC／Mac，系统选文件框）：先校验并显示「将导入几项、跳过几项、来自哪个版本」，
##   同一行再按一次确定才导入（导入前自动备份）；按别的行、上下移动或取消都算不导入。
## - 撤回上次导入：有备份才可点，换回导入前的设置。
## 取消返回设置页（导入改了界面风格时，设置页照「界面风格」一行的做法关回地图，见 XOptionsScene）。

signal closed

const HEAD_RECT := Rect2(260, 24, 760, 140)
const LIST_RECT := Rect2(260, 176, 760, 220)
const LH := 36.0
const NAME_W := 190.0
const HINT_SIZE := 20
const TITLE := "导入／导出配置"
const NOTE := "导出的配置带游戏版本号，可以发给别人。窗口、帧率、手机按键位置等本机设置，以及成就、解锁记录不会导出。"

## [键, 名字, 说明]
const ROWS := [["copy", "导出到剪贴板", "复制到剪贴板，可以直接粘贴发给别人。"],
	["save", "导出到文件", "存进「下载」文件夹。"],
	["paste", "从剪贴板导入", "先复制别人发来的配置文本，再点这里。"],
	["open", "从文件导入", "选一个导出的配置文件。"],
	["undo", "撤回上次导入", "换回导入前的设置。"]]

## 选文件（测试换掉）：Callable(on_picked: Callable(path: String))；空＝系统选文件框
static var file_picker: Callable

var index := 0
var head_win: XMVWindow
var list_win: XMVWindow
var message := ""
## 等确认的导入：{"row", "text", "preview"}；空＝没有
var pending := {}
## 这一页里导入／撤回改了界面风格（设置页据此关回地图）
var skin_changed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	head_win = XMVWindow.make(self, HEAD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_head)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	list_win.canvas.blink = true


static func rows() -> Array:
	return ROWS.filter(func(r): return XConfigTransfer.file_supported() or not (r[0] in ["save", "open"]))


func row_key(i: int) -> String:
	return str(rows()[i][0])


func enabled(i: int) -> bool:
	return row_key(i) != "undo" or XConfigTransfer.has_backup()


func _paint_head(c: XMVCanvas) -> void:
	c.text(TITLE, 0, 0, c.size.x, "left", XUI.TEXT, 24)
	var lines := wrap_lines(c, message if message != "" else NOTE, c.size.x, 18)
	for i in mini(lines.size(), 3):
		c.text(lines[i], 0, 36 + i * 22, c.size.x, "left", XUI.TEXT, 18, 22)


## 按宽度折行（中文逐字量，最多 3 行，第 3 行放不下的截掉）
static func wrap_lines(c: XMVCanvas, s: String, w: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for ch in s:
		if line != "" and c.text_width(line + ch, size) > w:
			out.append(line)
			line = ""
		line += ch
	if line != "":
		out.append(line)
	return out


func _paint_list(c: XMVCanvas) -> void:
	var w := c.size.x - 12.0
	var list := rows()
	for i in list.size():
		var y := i * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		var alpha := 1.0 if enabled(i) else XUI.DIM.a
		c.text(list[i][1], 6, y, NAME_W, "left", XUI.TEXT, XUI.FONT_SIZE, LH, alpha)
		c.text(list[i][2], 6 + NAME_W, y, w - NAME_W, "left", XUI.SYSTEM, HINT_SIZE, LH, alpha)


func _refresh() -> void:
	head_win.refresh()
	list_win.refresh()


func _say(text: String) -> void:
	message = text
	_refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	if not pending.is_empty():
		pending = {}
		message = ""
	XSound.system(0)
	_refresh()


func ok() -> void:
	if not enabled(index):
		XSound.system(3)
		return
	match row_key(index):
		"copy":
			XSound.system(1)
			XConfigTransfer.copy_to_clipboard(XConfigTransfer.export_text())
			_say("已复制到剪贴板（版本 %s）。" % XConfigTransfer.game_version())
		"save":
			XSound.system(1)
			var p := XConfigTransfer.export_file()
			_say(("已导出配置文件：%s（已放进「下载」文件夹）。" % p.get_file()) if p != "" else "存文件失败，请改用「导出到剪贴板」。")
		"paste":
			if _confirming("paste"):
				_do_import()
			else:
				_ask_import("paste", XConfigTransfer.read_clipboard())
		"open":
			if _confirming("open"):
				_do_import()
			else:
				_pick_file()
		"undo":
			var before = XConfigTransfer.skin_value()
			if XConfigTransfer.undo():
				XSound.system(1)
				skin_changed = skin_changed or before != XConfigTransfer.skin_value()
				_say("已换回导入前的设置。")
			else:
				XSound.system(3)
				_say("撤回失败：没有找到导入前的备份。")


func _confirming(key: String) -> bool:
	return not pending.is_empty() and pending["row"] == key


func _ask_import(key: String, text: String) -> void:
	var r := XConfigTransfer.preview(text)
	if not r["ok"]:
		XSound.system(3)
		pending = {}
		_say(str(r["error"]))
		return
	XSound.system(1)
	pending = {"row": key, "text": text, "preview": r}
	_say(XConfigTransfer.confirm_text(r))


func _do_import() -> void:
	var before = XConfigTransfer.skin_value()
	var r := XConfigTransfer.apply(str(pending["text"]))
	pending = {}
	XSound.system(1 if r["ok"] else 3)
	if r["ok"]:
		skin_changed = skin_changed or before != XConfigTransfer.skin_value()
	_say(XConfigTransfer.result_text(r) + ("可用「撤回上次导入」换回。" if r["ok"] else ""))


func _pick_file() -> void:
	var on_picked := func(path: String):
		if path == "":
			return
		_ask_import("open", XConfigTransfer.read_file(path))
	if file_picker.is_valid():
		file_picker.call(on_picked)
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		XSound.system(3)
		_say("这台设备不能选文件，请用「从剪贴板导入」。")
		return
	XSound.system(1)
	DisplayServer.file_dialog_show("选择配置文件", XFeedback.export_dir(), "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.txt ; 配置文件"]), func(status: bool, paths: PackedStringArray, _filter: int):
			if status and not paths.is_empty() and is_instance_valid(self) and is_inside_tree():
				on_picked.call(paths[0]))


func cancel() -> void:
	XSound.system(2)
	if not pending.is_empty():
		pending = {}
		_say("")
		return
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - LIST_RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not LIST_RECT.has_point(event.position) or p.y < 0:
				return
			var i := floori(p.y / LH)
			if i >= rows().size():
				return
			if i == index:
				ok()
			else:
				select(i)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		select(XMenu._move(index, d, rows().size(), not event.is_echo()))
