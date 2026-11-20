class_name XSkinSavePage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T292 存读档新布局（T254 3.2；左列表＋右大牌、不画环）。版型一 XSkinTemplatePage 的手动用法：
## 只管「怎么摆、怎么画、点了等于按了哪个键」——读、存、删、确认、存档校验失败的提示、系统音全部还是 XSaveScene 原来的代码
## （同一套 index／act／_phase／confirm_index，最后都走 XSaveScene._perform → XSave.save／load_slot／remove），存档读写结果与旧页一字节不差。
## 旧页 → 新页（T254 3.2 对应表）：
## - 帮助窗两行 → 右下按键提示；说明并进按钮和确认弹窗。
## - 列表 30 格 → 左列表（x 40、宽 392、行高 46）：图标、「文件 N」、小字地点、行尾游戏时间；空格变灰写「空」；校验失败行尾写「存档校验失败」；
##   天启篇选过线的档名字后一枚本线颜色的小标（旧页右边那道色条）。初始选中照旧（XSaveScene.first_index）。
## - 操作窗「读取／保存／删除」→ 右牌底三枚按钮，能不能点照旧（XSaveScene.action_enabled）；默认焦点读档在「读取」、存档在「保存」。
##   键盘／手柄：列表上 确定＝当前那枚（默认那枚；← / → 换），X＝删除；触屏直接点三枚。不再有「先进操作窗」这一层。
## - 信息窗 → 右牌：大标题＝地点（最近存的那格加「最近存的」小标）、小字＝游戏名＋文件号；「队伍」一排 5 个头像圆 76＋名字＋Lv；
##   「这一档」两列六项（保存次数、游戏时间、精魂、变量 20、变量 206、存档容量，名字照旧取系统里的叫法）；天启篇再加一行「天启之路」。
## - 空格 → 右牌正中「空」＋一行小字；校验失败 → 正中「存档校验失败」＋原来那句说明。
## - 确认窗 → 统一确认弹窗 XSkinConfirm：读取灰边、停在「读取」；覆盖、删除橙边、停在「取消」，后果一句写清是哪一档；
##   校验失败读不了的提示 → 同一个弹窗只有一枚「知道了」。
## 新皮肤关着、ENABLED＝false、或标题传 use_skin＝false 时 XSaveScene 不建这一页，旧页一行不变。

## T292 回退开关：false＝天启篇新皮肤下存读档也回旧页
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_LOAD_TITLE := "读档"
const T_SAVE_TITLE := "存档"
const T_EMPTY := "空"
const T_RECENT := "最近存的"
const T_PARTY := "队伍"
const T_THIS := "这一档"
const T_LINE := "天启之路"
const LIST_W := 392.0
const FACE_D := 76.0

var scene: XSaveScene
var body: Control            # 右牌上画内容的一层（XSkinCard 自己的 _draw 只画面板和按钮）
var dialog: XSkinConfirm
var _syncing := false
var _list_key := []
var _recent := -1             # 最近存的一格（1 起；没有为 -1）


func _init(s: XSaveScene, from_menu := false) -> void:
	scene = s
	name = "SkinSavePage"
	title = T_SAVE_TITLE if s.mode == "save" else T_LOAD_TITLE
	group_key = "system" if from_menu else ""   # 只有从主菜单进的页画页签条；标题、地图事件进来的不画
	columns = 1
	row_height = XUiSkin.ROW_H
	left_w = 0.0
	show_ring = false
	auto_nav = false
	focus = "list"
	currencies = []
	hint_list = []


func _ready() -> void:
	super()
	list.right2_w = 0.0
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	card_button.connect(_on_card_button)
	body = Control.new()
	body.name = "SaveBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.draw.connect(_draw_body)
	card.add_child(body)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if scene.use_skin == true:
		XSkinLayout.request_wide(self, true)   # 标题进来还没有存档，XUiSkin.on() 恒假：照开局页放宽这道门（横屏铺满）
	_recent = _most_recent()


## 列表宽 392 贴左；右牌吃掉剩下的宽（20:9 跟着变宽）
func relayout() -> void:
	if layout != null:
		var vw := layout.view_size().x
		var m := XSkinLayout.margin_for(vw)
		right_w = maxf(vw - m * 2.0 - layout.gap * 2.0 - LIST_W, 320.0)
	super()
	if body != null:
		body.queue_redraw()


## 读档初选的那一格就是「最近存的」（按存档时间，同 XSaveScene.first_index 读档模式）
func _most_recent() -> int:
	var best := -1
	var best_at := ""
	for i in range(1, XSave.SLOTS + 1):
		var d = scene.data(i)
		if d != null and str(d.get("savedAt", "")) >= best_at:
			best_at = str(d.get("savedAt", ""))
			best = i
	return best


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.help_win, sc.list_win, sc.action_win, sc.info_win, sc.confirm_win]:
		w.visible = false
	sc.confirm_back.visible = false
	if sc._phase == "action":
		sc._phase = "list"   # 新页没有「先进操作窗」这一层：动作做完（或被拦下）回列表
	_recent = _most_recent()
	set_focus("none" if sc._phase in ["confirm", "notice"] else "list")   # 先换焦点（set_focus 会清掉牌上的按钮焦点），再画牌
	list.active = true
	_sync_list()
	_sync_card()
	_sync_dialog()
	set_hint_list(_hints())
	_syncing = false
	body.queue_redraw()
	top_layer.queue_redraw()


func _sync_list() -> void:
	var rows := []
	for i in XSave.SLOTS:
		rows.append(slot_row(i + 1))
	var key := rows.map(func(r): return [r.text, r.get("sub", ""), r.get("right", ""), r.get("tags", []), r.get("color", Color.WHITE)])
	list_title = "文件"
	if key != _list_key:
		_list_key = key
		set_items(rows, scene.index)
	if list.index != scene.index:
		list.select(scene.index)


## 一格的行：图标、「文件 N」、小字地点、行尾游戏时间；空格变灰写「空」
func slot_row(slot_no: int) -> Dictionary:
	var sc := scene
	var d = sc.data(slot_no)
	var valid: bool = d != null
	var r := {"text": file_name(slot_no), "icon": int(sc.plugin("Saved Icon" if valid else "Empty Icon", "0"))}
	if sc.seal_failed(slot_no):
		r.right = XSaveSeal.FAIL_TEXT
		r.right_color = XUiSkin.DOWN
		r.color = XUiSkin.TEXT_3
		return r
	if not valid:
		r.right = T_EMPTY
		r.right_color = XUiSkin.TEXT_3
		r.color = XUiSkin.TEXT_3
		return r
	r.sub = location(d)
	r.right = XSaveScene.playtime(float(d.playSeconds))
	r.right_color = XUiSkin.TEXT_2
	var line := XSaveScene.save_line(d)
	if line != "":
		r.tags = [{"text": str(XTianqi.line_info(line).get("name", "")), "color": XTianqiLook.main_color(line)}]
	return r


static func file_name(slot_no: int) -> String:
	return "%s %d" % [str(XDB.system().get("terms", {}).get("messages", {}).get("file", "文件")), slot_no]


## 地点（同旧信息窗：地图显示名，没有用地图名）
static func location(d: Dictionary) -> String:
	var name := str(XDB.map(int(d.mapId)).get("displayName", ""))
	if name == "":
		name = str(XDB.rec("MapInfos", int(d.mapId)).get("name", ""))
	return name


func _sync_card() -> void:
	var sc := scene
	var buttons := []
	for i in XSaveScene.ACTIONS.size():
		buttons.append({"text": sc.plugin(["Load Command", "Save Command", "Delete Command"][i], XSaveScene.ACTIONS[i][0]),
			"primary": i == sc.act, "disabled": not sc.action_enabled(i)})
	card.setup({"icon": null, "title": "", "subtitle": "", "notice": "", "desc": "", "sections": [], "buttons": buttons,
		"button_index": sc.act if sc._phase == "list" else -1})


## 这格的右牌内容（测试按对应表逐行核）：{empty, failed, title, recent, subtitle, party: [{name, lv, face}], data: [[名, 值]], line: [名, 值, 色]}
func card_info() -> Dictionary:
	var sc := scene
	var slot_no := sc.slot()
	if sc.seal_failed(slot_no) and sc.data(slot_no) == null:
		return {"failed": true, "title": XSaveSeal.FAIL_TEXT, "subtitle": XSaveSeal.FAIL_HINT}
	var d = sc.data(slot_no)
	if d == null:
		return {"empty": true, "title": sc.plugin("Empty Game Text", T_EMPTY),
			"subtitle": "按确定把现在的进度存到这里。" if sc.mode == "save" else "这一格还没有存档。"}
	var out := {"title": location(d), "recent": slot_no == _recent,
		"subtitle": "%s · %s" % [str(XDB.system().get("gameTitle", "")), file_name(slot_no)]}
	var party := []
	var p: Array = d.party
	var lv_word := "Lv"
	var basic: Array = XDB.system().get("terms", {}).get("basic", [])
	if basic.size() > 1 and str(basic[1]) != "":
		lv_word = str(basic[1])
	for i in mini(XState.MAX_BATTLE_MEMBERS, p.size()):
		var id := int(p[i])
		var rec := XDB.rec("Actors", id)
		var row: Dictionary = d.actors.get(str(id), {})
		party.append({"name": str(rec.get("name", "")), "lv": "%s %s" % [lv_word, XMenu._group(int(row.get("level", 1)))],
			"face": XUiSkin.face(str(rec.get("faceName", "")), int(rec.get("faceIndex", 0)))})
	out.party = party
	var data := []
	data.append([sc.plugin("Save Count", "保存次数"), XMenu._group(int(d.get("saveCount", 0)))])
	data.append([sc.plugin("Playtime", "游戏时间"), XSaveScene.playtime(float(d.playSeconds))])
	data.append([sc.plugin("Gold Count", "%1:").replace("%1", str(XDB.system().get("currencyUnit", ""))).trim_suffix(":").trim_suffix("："), XMenu._group(int(d.gold))])
	for vid in [20, 206]:
		data.append([var_name(vid), XMenu._group(int(d.variables.get(str(vid), 0)))])
	data.append([sc.plugin("File Size", "存档容量：%1KB").get_slice("：", 0), XSaveScene.file_size(slot_no)])
	out.data = data
	var line := XSaveScene.save_line(d)
	if line != "":
		var l := XTianqi.line_info(line)
		out.line = [T_LINE, "%s·%s%s" % [str(l.get("name", "")), str(l.get("knight", "")), XSaveScene.clear_mark(d, line) + XTianqiWeakClear.save_mark(d)], XTianqiLook.main_color(line)]
	return out


## 系统变量名（去掉 <<…>> 备注和转义码，同旧页）
static func var_name(id: int) -> String:
	var raw := RegEx.create_from_string("<<(.*?)>>").sub(str(XDB.system().variables[id]), "")
	return RegEx.create_from_string("(?i)\\\\[a-z]+\\[[^\\]]*\\]|\\\\.").sub(raw, "", true).strip_edges()


# ---- 确认弹窗 ----

func _sync_dialog() -> void:
	var sc := scene
	if not sc._phase in ["confirm", "notice"]:
		if dialog != null:
			dialog.queue_free()
			dialog = null
			sc.act = default_act()   # 弹窗关了（做完或取消）：按钮焦点回默认那枚
		return
	if dialog == null:
		dialog = XSkinConfirm.new()
		dialog.chosen.connect(_on_dialog_chosen)
		dialog.index_changed.connect(_on_dialog_index)
		dialog.cancelled.connect(func(): scene.cancel())
		add_child(dialog)
		if sc._phase == "confirm" and bool(confirm_data().get("danger", false)):
			sc.confirm_index = 1   # 覆盖、删除：光标停在「取消」（旧确认窗停在「是」；T254 统一确认弹窗）
	var d := confirm_data()
	d.index = 0 if sc._phase == "notice" else sc.confirm_index
	dialog.setup(d)


## 弹窗内容：钮的序号＝XSaveScene.confirm_index（0 做、1 不做）
func confirm_data() -> Dictionary:
	var sc := scene
	if sc._phase == "notice":
		return {"title": XSaveSeal.FAIL_TEXT + "，无法读取", "body": XSaveSeal.FAIL_HINT, "buttons": ["知道了"]}
	var what := file_name(sc.slot())
	var d = sc.data(sc.slot())
	if d != null:
		what += "（%s · %s）" % [location(d), XSaveScene.playtime(float(d.playSeconds))]
	match str(XSaveScene.ACTIONS[sc.act][1]):
		"load":
			return {"title": "读取这份存档？", "body": "回到%s的进度，现在没存的进度不会留下。" % what, "buttons": ["读取", "取消"]}
		"save":
			return {"title": "覆盖这份存档？", "body": "%s会被现在的进度换掉，换掉就找不回来。" % what, "buttons": ["覆盖", "取消"], "danger": true}
	return {"title": "删除这份存档？", "body": "%s会被删掉，删掉就找不回来。" % what, "buttons": ["删除", "取消"], "danger": true}


func _on_dialog_index(i: int) -> void:
	if _syncing or scene._phase != "confirm":
		return
	scene.confirm_index = i
	XSound.system(0)
	scene._refresh()


func _on_dialog_chosen(i: int) -> void:
	if scene._phase == "confirm":
		scene.confirm_index = i
	scene.ok()


# ---- 按键提示 ----

func _hints() -> Array:
	var sc := scene
	if sc._phase in ["confirm", "notice"]:
		return [["← / →", "切换"], ["确定", "选择"], ["取消", "返回"]]
	var verb := str(XSaveScene.ACTIONS[sc.act][0])
	var h := [["确定", verb], ["← / →", "换按钮"]]
	if sc.action_enabled(2):
		h.append(["X", "删除"])
	h.append(["取消", "离开"])
	return h


# ---- 按键：列表上下、翻页照旧走 XSaveScene；确定＝当前那枚按钮，X＝删除，左右换按钮 ----

## 用掉了返回 true（XSaveScene._unhandled_input 开头调）
func input(event: InputEvent) -> bool:
	var sc := scene
	if sc._phase in ["confirm", "notice"] and dialog != null:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			return false   # 确定、取消照旧页走（ok／cancel：音、做不做、回到哪）
		return dialog.handle_input(event)
	if sc._phase != "list":
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X:
		press_action(2)
		return true
	if event.is_action_pressed("ui_accept"):
		press_action(sc.act)
		return true
	var d := 0
	if event.is_action_pressed("ui_left", true):
		d = -1
	elif event.is_action_pressed("ui_right", true):
		d = 1
	if d != 0:
		sc.act = posmod(sc.act + d, XSaveScene.ACTIONS.size())
		XSound.system(0)
		sc._refresh()
		return true
	if XMenu.page_dir(event) != 0:
		var before := sc.index
		list.page(XMenu.page_dir(event))
		sc.index = list.index
		if sc.index != before:
			XSound.system(0)
			sc.act = default_act()
		sc._refresh()
		return true
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		var before2 := sc.index
		sc.move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
		if sc.index != before2:
			sc.act = default_act()
			sc._refresh()
		return true
	return false


## 默认那枚：读档在「读取」、存档在「保存」
func default_act() -> int:
	return 0 if scene.mode == "load" else 1


## 按下第 i 枚（同旧页：列表确定 → 操作窗停在第 i 格 → 确定）；不能点的蜂鸣、留在列表
func press_action(i: int) -> void:
	var sc := scene
	var before := sc.act
	sc.act = i
	sc._phase = "action"
	sc.ok()
	if sc._phase == "action":
		sc._phase = "list"
		sc.act = before   # 不能点（蜂鸣）：按钮焦点留在原来那枚
	sc._refresh()


# ---- 点击 → 同样的状态变化 ----

func _on_list_index(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc._phase != "list" or i == sc.index:
		return
	sc.index = i
	sc.act = default_act()
	XSound.system(0)
	sc._refresh()


func _on_list_click(i: int) -> void:
	if _syncing or scene._phase != "list":
		return
	if i == scene.index:
		press_action(scene.act)


func _on_card_button(i: int) -> void:
	if scene._phase != "list":
		return
	press_action(i)


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene.cancel()
		accept_event()


# ---- 画右牌 ----

func _draw_body() -> void:
	var info := card_info()
	var w := card.size.x
	var pad := card.pad
	var bottom := card.content_bottom()
	var head := XUiSkin.font("title")
	var f := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	if info.get("empty", false) or info.get("failed", false):
		var cy := bottom / 2.0
		var tfs := XUiSkin.fs(XUiSkin.FS_CARD)
		var t := str(info.title)
		var tw := head.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		XUiSkin.ds(body, head, Vector2((w - tw) / 2.0, cy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, XUiSkin.DOWN if info.get("failed", false) else XUiSkin.TEXT_3)
		var sfs := XUiSkin.FS_AUX
		var s := str(info.subtitle)
		var sw := minf(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x, w - pad * 2)
		XUiSkin.ds(body, f, Vector2((w - sw) / 2.0, cy + sfs * 2.0), s, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2, sfs, XUiSkin.TEXT_2)
		return
	var y := pad
	# 大标题＝地点＋「最近存的」小标
	var tfs2 := XUiSkin.fs(30)
	var tag_w := XSkinTag.width(T_RECENT) + XSkinTag.GAP * 2.0 if info.get("recent", false) else 0.0
	var fit := XSkinList.fit_text(head, str(info.title), w - pad * 2 - tag_w, tfs2, 20)
	XUiSkin.ds(body, head, Vector2(pad, y + tfs2 * 0.92), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT)
	if info.get("recent", false):
		var tx := pad + head.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x + XSkinTag.GAP * 2.0
		XSkinTag.draw(body, Vector2(tx, y + tfs2 * 0.6), T_RECENT)
	y += tfs2 * 1.3
	XUiSkin.ds(body, f, Vector2(pad, y + XUiSkin.FS_AUX * 0.9), str(info.subtitle), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
	y += XUiSkin.FS_AUX_MAX + 14
	# 队伍：5 个头像圆
	y = _section(T_PARTY, y, w, pad)
	var party: Array = info.party
	var cols := XState.MAX_BATTLE_MEMBERS
	var cw := (w - pad * 2) / cols
	var name_fs := XUiSkin.fs(17)
	for i in party.size():
		var m: Dictionary = party[i]
		var cx := pad + cw * i + cw / 2.0
		var ctr := Vector2(cx, y + FACE_D / 2.0)
		body.draw_circle(ctr, FACE_D / 2.0 + 1.0, Color(XUiSkin.LINE, 0.55))
		draw_face_circle(body, m.face, ctr, FACE_D / 2.0)
		var nf := XSkinList.fit_text(f, str(m.name), cw - 8.0, name_fs, 14)
		var nw := f.get_string_size(str(nf[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(nf[1])).x
		XUiSkin.ds(body, f, Vector2(cx - nw / 2.0, y + FACE_D + 8 + name_fs), str(nf[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(nf[1]), XUiSkin.TEXT)
		var lv := str(m.lv)
		var lw := num.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		XUiSkin.ds(body, num, Vector2(cx - lw / 2.0, y + FACE_D + 14 + name_fs + XUiSkin.FS_AUX), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.GOLD_LIGHT)
	y += FACE_D + 22 + name_fs + XUiSkin.FS_AUX
	# 这一档：两列六项（左列前三项、右列后三项）
	if y + 40 > bottom:
		return
	y = _section(T_THIS, y, w, pad)
	var data: Array = info.data
	var half := (w - pad * 2 - 24.0) / 2.0
	var lh := roundf(XUiSkin.FS_AUX_MAX * 1.75)
	var rows := ceili(data.size() / 2.0)
	for k in data.size():
		var col := k / rows
		var row := k % rows
		var x := pad + col * (half + 24.0)
		var ry := y + row * lh
		if ry + lh > bottom:
			continue
		_pair(x, ry, half, str(data[k][0]), str(data[k][1]), XUiSkin.GOLD_LIGHT)
	y += rows * lh
	if info.has("line") and y + lh <= bottom:
		var ln: Array = info.line
		body.draw_rect(Rect2(pad, y + 6, 4, lh - 12), ln[2])
		_pair(pad + 12, y, w - pad * 2 - 12, str(ln[0]), str(ln[1]), ln[2])


func _section(t: String, y: float, w: float, pad: float) -> float:
	body.draw_line(Vector2(pad, y), Vector2(w - pad, y), Color(XUiSkin.LINE, 0.14), 1.0)
	var f := XUiSkin.font("body")
	XUiSkin.ds(body, f, Vector2(pad, y + 8 + XUiSkin.FS_AUX_MAX), t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
	return y + 16 + XUiSkin.FS_AUX_MAX + 10


## 左名（次要字）右值
func _pair(x: float, y: float, w: float, left: String, right: String, rc: Color) -> void:
	var f := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var fs := XUiSkin.FS_AUX
	var base := y + roundf(XUiSkin.FS_AUX_MAX * 1.75) / 2.0
	var rfs := XUiSkin.fs(19)
	var rw := minf(num.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x, w * 0.62)
	XUiSkin.ds(body, f, Vector2(x, base + fs * 0.36), left, HORIZONTAL_ALIGNMENT_LEFT, w - rw - 10, fs, XUiSkin.TEXT_2)
	XUiSkin.ds(body, num, Vector2(x + w - rw, base + rfs * 0.36), right, HORIZONTAL_ALIGNMENT_LEFT, w * 0.62, rfs, rc)


## 头像裁成圆（AtlasTexture 按 region 算 UV，画在大图上）
static func draw_face_circle(ci: CanvasItem, tex: Texture2D, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("16151a"))
	if tex == null:
		return
	var atlas := tex
	var region := Rect2(Vector2.ZERO, tex.get_size())
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		atlas = (tex as AtlasTexture).atlas
		region = (tex as AtlasTexture).region
	var asz := atlas.get_size()
	if asz.x <= 0 or asz.y <= 0:
		return
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := 40
	for i in n:
		var a := TAU * i / n
		var v := Vector2(cos(a), sin(a))
		pts.append(c + v * r)
		var local := region.position + region.size * (v * 0.5 + Vector2(0.5, 0.5))
		uvs.append(local / asz)
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, atlas)
