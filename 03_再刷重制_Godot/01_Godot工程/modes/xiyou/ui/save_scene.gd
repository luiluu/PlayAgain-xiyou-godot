class_name XSaveScene
extends Control
## 存档／读档页（正式 YEP_SaveCore＋SaveHistory_FullData 的 Scene_File：标题「旧的回忆」是读档模式 Scene_Load，
## 一键存档还没存过档时打开存档模式 Scene_Save）。按正式 v0.28 运行时读数复现（tests/fixtures/save_page_oracle.json，
## 截图 04_验证/本地结果/原版参照/存读档页/）：
## - 帮助 (0,0,1280,100)：两行说明窗，文字 (6,0)；选格时「请选择一个文件插槽。」，操作窗里随选中项换说明。
## - 列表 (0,100,240,620)：30 格、行高 36、可见 16 行；图标 907（有档）／905（空）在 (2,y+2)，「文件 N」x 36 宽 180，
##   空格整行半透明。读档模式初始选最近保存的一格（按存档时间），存档模式选最近存读的一格；首行为选中行上两行。
## - 操作 (240,100,1040,64)：读取／保存／删除横排三格（宽 329、间距 12，文字居中）。读取＝这格是有效存档，
##   保存＝存档模式，删除＝这格有文件。列表确定后激活操作窗，读档模式停在读取、存档模式停在保存；未激活不画光标。
## - 信息 (240,164,1040,556)，内容 1012×528：顶上游戏名（居中）；队伍前 5 格每格宽 202：头像 (列×202＋29, 36)、
##   名字 y 180、「Lv 等级」y 216（字号 20）；数据两列（宽 506，右边留 6）从 y 252 起每行 36、底 #202040 不透明度 160：
##   左列 地点（居中）、保存次数、游戏时间、「精魂:」金钱、变量 20、变量 206（名字字号 20、下移 3，值右对齐），
##   右列 存档容量（O-042：实际文件大小）。空格只画整块暗底与居中的「空」（系统色）。
## - 确认 (居中，宽＝说明宽＋40，高 136)：说明 (6,0)，「是／否」两行居中；读取总要确认，保存在这格已有档时确认，删除确认。
## 未做（照搬差异）：保存次数（Godot 存档没有 $gameSystem._saveCount，画「—」，见交付单）。

signal closed
signal loaded

const HELP_RECT := Rect2(0, 0, 1280, 100)
const LIST_RECT := Rect2(0, 100, 240, 620)
const ACTION_RECT := Rect2(240, 100, 1040, 64)
const INFO_RECT := Rect2(240, 164, 1040, 556)
const LH := 36.0
const ACTIONS := [["读取", "load"], ["保存", "save"], ["删除", "delete"]]
const COL_W := 202.0
const DATA_Y := 252.0
const FACE_TOP := 36.0
const DARK_ALPHA := 160.0 / 255.0

var mode := "load"                  # load / save
var _phase := "list"                # list / action / confirm
var index := 0
var top := 0
var act := 0
var confirm_index := 0
var confirm_text := ""
var help_text := ""
var help_win: XMVWindow
var list_win: XMVWindow
var action_win: XMVWindow
var info_win: XMVWindow
var confirm_win: XMVWindow
var _cache := {}                    # 格 → 读出的存档字典（无效为 null）


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	help_win = XMVWindow.make(self, HELP_RECT, op, _paint_help)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	action_win = XMVWindow.make(self, ACTION_RECT, op, _paint_action)
	info_win = XMVWindow.make(self, INFO_RECT, op, _paint_info)
	confirm_win = XMVWindow.make(self, Rect2(0, 0, 300, 136), op, _paint_confirm)
	confirm_win.visible = false
	for w in [list_win, action_win, confirm_win]:
		w.canvas.blink = true
	index = first_index()
	top = clampi(index - 2, 0, maxi(0, XSave.SLOTS - page_rows()))
	help_text = str(XDB.plugin("YEP_SaveCore").get("Select Help", "请选择一个文件插槽。"))
	_refresh()


func plugin(key: String, def := "") -> String:
	return str(XDB.plugin("YEP_SaveCore").get(key, def))


func page_rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


# ---- 数据 ----
## 这格的存档（有效才返回字典）
func data(slot: int):
	if not _cache.has(slot):
		var d = null
		if XSave.exists(slot):
			d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(slot)))
			if not XSave.valid_data(d):
				d = null
		_cache[slot] = d
	return _cache[slot]


func slot() -> int:
	return index + 1


## Scene_Load：最近保存的一格（按存档时间）；Scene_Save：最近存读的一格
func first_index() -> int:
	if mode == "save":
		return maxi(0, XSave.current_slot - 1)
	var best := 0
	var best_at := ""
	for i in range(1, XSave.SLOTS + 1):
		var d = data(i)
		if d != null and str(d.get("savedAt", "")) > best_at:
			best_at = str(d.get("savedAt", ""))
			best = i - 1
	return best


func action_enabled(i: int) -> bool:
	match str(ACTIONS[i][1]):
		"load":
			return data(slot()) != null
		"save":
			return mode == "save"
		_:
			return XSave.exists(slot())


# ---- 刷新与绘制 ----
func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + page_rows() < XSave.SLOTS
	for w in [help_win, list_win, action_win, info_win, confirm_win]:
		w.refresh()


func _paint_help(c: XMVCanvas) -> void:
	var t := XMVText.new(XMVText.convert_escapes(help_text), 6, 0, c.size.x - 12)
	t.run()
	XMVText.paint(c, t.glyphs)


func _paint_list(c: XMVCanvas) -> void:
	for i in range(top, mini(XSave.SLOTS, top + page_rows())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH), _phase == "list")
		var valid := data(i + 1) != null
		var a := 1.0 if valid else XUI.DIM.a
		c.icon(int(plugin("Saved Icon" if valid else "Empty Icon", "0")), 2, y + 2, a)
		c.text("%s %d" % [str(XDB.system().get("terms", {}).get("messages", {}).get("file", "文件")), i + 1], 36, y, 180, "left", XUI.TEXT, XUI.FONT_SIZE, LH, a)


func action_rect(i: int) -> Rect2:
	var w := floorf((ACTION_RECT.size.x - XMVWindow.PADDING * 2 - 12.0 * 2) / 3.0)
	return Rect2(i * (w + 12.0), 0, w, LH)


func _paint_action(c: XMVCanvas) -> void:
	for i in range(ACTIONS.size()):
		var r := action_rect(i)
		if _phase in ["action", "confirm"] and i == act:
			c.cursor(r, _phase == "action")
		c.text(plugin(["Load Command", "Save Command", "Delete Command"][i], ACTIONS[i][0]), r.position.x + 6, 0, r.size.x - 12, "center",
			XUI.TEXT, XUI.FONT_SIZE, LH, 1.0 if action_enabled(i) else XUI.DIM.a)


func _dark(c: XMVCanvas, r: Rect2) -> void:
	c.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Color(XUI.GAUGE_BACK, DARK_ALPHA))


func _paint_info(c: XMVCanvas) -> void:
	var d = data(slot())
	var w := c.size.x
	if d == null:
		# drawInvalidText：没有存档信息时整块暗底＋「空」
		_dark(c, Rect2(0, 0, w, c.size.y))
		c.text(plugin("Empty Game Text", "空"), 0, floorf((c.size.y - LH) / 2.0), w, "center", XUI.SYSTEM, XUI.FONT_SIZE, LH)
		return
	c.text(str(XDB.system().get("gameTitle", "")), 0, 0, w, "center", XUI.TEXT, XUI.FONT_SIZE, LH)
	var cols := XState.MAX_BATTLE_MEMBERS
	var dw := floorf(w / cols)
	var party: Array = d.party
	for i in range(mini(cols, party.size())):
		var id := int(party[i])
		var rec := XDB.rec("Actors", id)
		var row: Dictionary = d.actors.get(str(id), {})
		c.face(str(rec.get("faceName", "")), int(rec.get("faceIndex", 0)), i * dw, FACE_TOP, dw, 144)
		c.text(str(rec.get("name", "")), i * dw, 180, dw, "center", XUI.TEXT, 20, LH)
		var lv_text := "\\c[16]%s \\c[0]%s" % [str(XDB.system().get("terms", {}).get("basic", ["", "", "Lv"])[1] if XDB.system().get("terms", {}).get("basic", []).size() > 1 else "Lv"), XMenu._group(int(row.get("level", 1)))]
		var t := XMVText.new(XMVText.convert_escapes(lv_text), 0, 0, dw, 20)
		t.run()
		var tw := _width(t.glyphs)
		XMVText.paint(c, t.glyphs, i * dw + floorf(maxf(0, dw - tw) / 2.0), 216)
	# 数据两列：左列地点等，右列存档容量
	var cw := floorf(w / 2.0)
	var left := ["location", "save count", "playtime", "gold count", "variable 20", "variable 206"]
	for i in range(left.size()):
		_data_row(c, d, str(left[i]), 0, DATA_Y + i * LH, cw - 6)
	_data_row(c, d, "file size", cw, DATA_Y, cw - 6)


static func _width(glyphs: Array) -> float:
	var r := 0.0
	for g in glyphs:
		r = maxf(r, float(g.x) + float(g.get("w", 32.0 if g.has("icon") else 0.0)) + (4.0 if g.has("icon") else 0.0))
	return r


func _data_row(c: XMVCanvas, d: Dictionary, kind: String, dx: float, dy: float, dw: float) -> void:
	_dark(c, Rect2(dx, dy, dw, LH))
	var x := dx + 6
	var tw := dw - 12
	match kind:
		"location":
			var name := str(XDB.map(int(d.mapId)).get("displayName", ""))
			if name == "":
				name = str(XDB.rec("MapInfos", int(d.mapId)).get("name", ""))
			c.text(name, x, dy, tw, "center", XUI.TEXT, 20, LH)
		"save count":
			c.text(plugin("Save Count", "保存次数"), x, dy, tw, "left", XUI.SYSTEM, 20, LH)
			c.text(XMenu._group(int(d.saveCount)) if d.has("saveCount") else "—", x, dy, tw, "right", XUI.TEXT, 20, LH)
		"playtime":
			c.text(plugin("Playtime", "游戏时间"), x, dy, tw, "left", XUI.SYSTEM, 20, LH)
			c.text(playtime(float(d.playSeconds)), x, dy, tw, "right", XUI.TEXT, 20, LH)
		"gold count":
			c.text(plugin("Gold Count", "%1:").replace("%1", str(XDB.system().get("currencyUnit", ""))), x, dy, tw, "left", XUI.SYSTEM, 20, LH)
			c.text(XMenu._group(int(d.gold)), x, dy, tw, "right", XUI.TEXT, 20, LH)
		"variable 20", "variable 206":
			var id := int(kind.get_slice(" ", 1))
			var vname := RegEx.create_from_string("<<(.*?)>>").sub(str(XDB.system().variables[id]), "")
			var t := XMVText.new(XMVText.convert_escapes("\\c[16]" + vname), x, dy + 3, tw, 20)
			t.run()
			XMVText.paint(c, t.glyphs)
			c.text(XMenu._group(int(d.variables.get(str(id), 0))), x, dy, tw, "right", XUI.TEXT, 20, LH)
		"file size":
			c.text(plugin("File Size", "存档容量：%1KB").get_slice("：", 0) + "：" + file_size(slot()), x, dy, tw, "center", XUI.TEXT, 20, LH)


## $gameSystem.playtimeText：时:分:秒 各两位
static func playtime(sec: float) -> String:
	var s := floori(sec)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


## 存档容量（O-042：实际存档文件大小，B／KB／MB 一位小数；正式版只数 encodeURI 的转义字节）
static func file_size(slot_no: int) -> String:
	var f := FileAccess.open(XSave.path(slot_no), FileAccess.READ)
	if f == null:
		return "0B"
	var bytes := f.get_length()
	f.close()
	if bytes < 1024:
		return "%dB" % bytes
	if bytes < 1048576:
		return "%.1fKB" % (bytes / 1024.0)
	return "%.1fMB" % (bytes / 1048576.0)


func _paint_confirm(c: XMVCanvas) -> void:
	var t := XMVText.new(XMVText.convert_escapes(confirm_text), 6, 0, c.size.x - 12)
	t.run()
	XMVText.paint(c, t.glyphs)
	for i in range(2):
		var y := LH * (i + 1)
		if i == confirm_index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		c.text(plugin(["Confirm Yes", "Confirm No"][i], ["是", "否"][i]), 6, y, c.size.x - 12, "center", XUI.TEXT, XUI.FONT_SIZE, LH)


# ---- 操作 ----
func _unhandled_input(event: InputEvent) -> void:
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		cancel()
	elif event.is_action_pressed("ui_accept"):
		ok()
	elif event.is_action_pressed("ui_down", true):
		move(1, not event.is_echo())
	elif event.is_action_pressed("ui_up", true):
		move(-1, not event.is_echo())
	elif event.is_action_pressed("ui_right", true) and _phase == "action":
		move(1, not event.is_echo())
	elif event.is_action_pressed("ui_left", true) and _phase == "action":
		move(-1, not event.is_echo())
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func move(d: int, wrap := true) -> void:
	match _phase:
		"list":
			var old := index
			index = XMenu._move(index, d, XSave.SLOTS, wrap)
			top = XMenu._scroll_to(index, top, page_rows())
			if old != index:
				XSound.system(0)
		"action":
			var old := act
			act = XMenu._move(act, d, ACTIONS.size(), wrap)
			if old != act:
				XSound.system(0)
			_update_action_help()
		"confirm":
			confirm_index = XMenu._move(confirm_index, d, 2, wrap)
			XSound.system(0)
	_refresh()


func _update_action_help() -> void:
	help_text = plugin(["Load Help", "Save Help", "Delete Help"][act], "")


func ok() -> void:
	match _phase:
		"list":
			XSound.system(1)
			_phase = "action"
			act = 0 if mode == "load" else 1
			_update_action_help()
		"action":
			if not action_enabled(act):
				XSound.system(3)
				return
			match str(ACTIONS[act][1]):
				"load":
					_start_confirm(plugin("Load Text", "是否加载此保存文件？"))
				"save":
					if XSave.exists(slot()):
						_start_confirm(plugin("Save Text", "是否要覆盖此保存文件？"))
					else:
						_perform("save")
				_:
					_start_confirm(plugin("Delete Text", "是否要删除此保存文件？"))
		"confirm":
			XSound.system(1)
			confirm_win.visible = false
			if confirm_index == 0:
				_perform(str(ACTIONS[act][1]))
			else:
				_phase = "action"
	_refresh()


func cancel() -> void:
	XSound.system(2)
	match _phase:
		"list":
			closed.emit()
			return
		"action":
			_back_to_list()
		"confirm":
			confirm_win.visible = false
			_phase = "action"
	_refresh()


func _back_to_list() -> void:
	_phase = "list"
	help_text = plugin("Select Help", "请选择一个文件插槽。")


## startConfirmWindow：宽按说明文字＋内边距，居中
func _start_confirm(text: String) -> void:
	XSound.system(1)
	confirm_text = text
	confirm_index = 0
	var t := XMVText.new(XMVText.convert_escapes(text), 0, 0, 1280)
	t.run()
	var w := _width(t.glyphs) + XMVWindow.PADDING * 2 + 12.0
	confirm_win.size = Vector2(w, LH * 3 + XMVWindow.PADDING * 2)
	confirm_win.position = Vector2(floorf((1280.0 - w) / 2.0), floorf((720.0 - confirm_win.size.y) / 2.0))
	confirm_win.visible = true
	_phase = "confirm"


func _perform(kind: String) -> void:
	match kind:
		"load":
			if XSave.load_slot(slot()):
				XSound.system(6)
				loaded.emit()
				return
			XSound.system(3)
			_back_to_list()
		"save":
			if XSave.save(slot()):
				XSound.system(5)
				_cache.erase(slot())
			else:
				XSound.system(3)
			_back_to_list()
		"delete":
			XSound.play(plugin("Delete Filename", "Damage2"), int(plugin("Delete Volume", "100")), int(plugin("Delete Pitch", "150")))
			XSave.remove(slot())
			_cache.erase(slot())
			_back_to_list()
