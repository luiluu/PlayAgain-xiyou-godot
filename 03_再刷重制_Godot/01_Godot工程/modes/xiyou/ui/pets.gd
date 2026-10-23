class_name XPetScene
extends Control
## 宠物（Star_PetSystem 的 Scene_PetSystem；主菜单「宠物」＝公共事件 169 SceneManager.push）。数据与出战在 XPets。
## 版面与逐条绘制按冻结 v0.28 浏览器参照（tests/fixtures/pet_oracle.json）；窗口不透明度照 MOG 菜单 30：
## - 目录 (0,0,426,440)（变量 21 为 0 时高 = 720 − fittingHeight(7)）：宠物名（去掉「【变异】」），出战的带「[出战]」。
## - 状态窗 (426,0,854,720)，内容宽 826：SV 图以窗口内 (206.5, 206.5) 为中心（宽超过 413 时缩小；<Sideview Battler> 走侧视图 0-1-2-1 每 12 帧）；
##   x 420 起名字（变异的另在左边写橙色「变异」）、「等级N」「可学习技能次数:已用/上限」；y 144 起七行两列加成（标签 systemColor 在 420／672，
##   值在「标签＋两个空格」之后，前 8 项取整、后 6 项 ×100 取整加「%」）；y 486「技能数:N」，y 522 起技能 drawItemName，每 4 个换一列（x +280）。
## - 底部指令 (0,456,427,264)：出战／休息／放生／修改共享角色／查看技能，一直显示，目录确定后才可选。
## - 技能列表 (426,540,854,180)：drawItemName（宽 826−6−textWidth("000")），说明卡（宽 400）跟在选中行右下；取消回底部指令。
## - 共享角色窗 (426.67,548,854,172)：「N号角色」，当前的加「[当前共享]」；确定后换共享角色并重学宠物技能。
## 目录为空时确定不做事（原版会打开底部指令，选了出战等会因宠物不存在报错）。

signal closed

const INDEX_RECT := Rect2(0, 0, 426, 440)
const STATUS_RECT := Rect2(426, 0, 854, 720)
const SKILL_RECT := Rect2(426, 540, 854, 180)
const BOTTOM_RECT := Rect2(0, 456, 427, 264)
const TEAM_RECT := Rect2(1280.0 / 3.0, 548, 854, 172)
const LH := 36.0
const CW := 826.0
const COL2 := CW / 2.0 + 7.0              # 420
const COLW := CW / 2.0 - 14.0             # 399
const ROWS := 11                          # floor((440 − 28) / 36)
const SKILL_ROWS := 4                     # floor((180 − 28) / 36)
const SPRITE_CENTER := Vector2(CW / 4.0, CW / 4.0)
const ATTR := ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运", "命中", "闪避", "暴击", "暴击闪避", "魔法闪避", "反击"]
## 状态窗七行两列：[左, 右]（加成序号）
const ATTR_ROWS := [[0, 1], [2, 6], [4, 7], [3, 8], [5, 9], [11, 10], [12, 13]]
## Star_PetSynthesis 在变量 21 为 0 时加「合成」，Star_PetUpLevel 加「喂养」（期二，暂时灰显）；窗口可见 6 行，第 7 行要滚动
const COMMANDS := [["出战", "war"], ["休息", "rest"], ["放生", "release"], ["修改共享角色", "team"], ["查看技能", "skills"], ["合成", "synthesis"], ["喂养", "feed"]]
const NOT_YET := ["synthesis", "feed"]
const BOTTOM_ROWS := 6
const MUTANT := "【变异】"

var mode := "index"          # index / bottom / team / skills
var index := 0
var top := 0
var cmd := -1
var cmd_top := 0
var team := -1
var skill_index := -1
var skill_top := 0
var index_win: XMVWindow
var status_win: XMVWindow
var skill_win: XMVWindow
var bottom_win: XMVWindow
var team_win: XMVWindow
var help_card: XHelpCard
var _status_ops: Array = []
var _sprite_tex: Texture2D
var _sprite_sv := false
var _frame := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	index_win = XMVWindow.make(self, INDEX_RECT, op, _paint_index)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	skill_win = XMVWindow.make(self, SKILL_RECT, op, _paint_skills)
	bottom_win = XMVWindow.make(self, BOTTOM_RECT, op, _paint_bottom)
	team_win = XMVWindow.make(self, TEAM_RECT, op, _paint_team)
	for w in [index_win, skill_win, bottom_win, team_win]:
		w.canvas.blink = true
	skill_win.openness = 0
	team_win.openness = 0
	help_card = XHelpCard.new()
	add_child(help_card)
	help_card.show_for({})
	_select_pet()


func _process(_delta: float) -> void:
	_frame += 1
	if _sprite_tex != null and _sprite_sv and _frame % 12 == 0:
		status_win.canvas.queue_redraw()


# ---- 数据 ----
func pets() -> Array:
	return XPets.list(XState.current)


func current() -> Dictionary:
	var l := pets()
	return l[index] if index >= 0 and index < l.size() else {}


## EnemyNameColorByDifficulty 改的是 Bitmap.drawText：与数据库敌人原名相同的文字换成难度色（宠物名常是敌人原名）
static func _t(text: String, x: float, y: float, w: float, color := XUI.TEXT, size := XUI.FONT_SIZE) -> Array:
	var diff := XState.current.difficulty if XState.current != null else 2
	return ["t", text, x, y, w, LH, "left", size, XEnemy.name_color(text, diff, color)]


## Window_PetSystemStatus.drawAllContents
static func status_ops(s: XState, pet: Dictionary) -> Array:
	var ops := []
	if pet.is_empty():
		return ops
	var name := XPets.pet_name(s, pet)
	if name.contains(MUTANT):
		ops.append(_t("变异", 0, 0, COLW, Color("FFAF00")))
		ops.append(_t(name.replace(MUTANT, ""), COL2, 0, COLW))
	else:
		ops.append(_t(name, COL2, 0, COLW))
	ops.append(_t("等级" + str(XPets.level(pet)), COL2, LH, COLW))
	ops.append(_t("可学习技能次数:%d/%d" % [int(pet.get("ls", 0)), int(pet.get("ls_max", 1))], COL2, LH * 2, COLW))
	var y := LH * 3
	var right := COL2 * 8.0 / 5.0
	for k in ATTR_ROWS.size():
		ops.append(_t(ATTR[ATTR_ROWS[k][0]], COL2, y + LH * (k + 1), COLW, XUI.SYSTEM))
		ops.append(_t(ATTR[ATTR_ROWS[k][1]], right, y + LH * (k + 1), COLW, XUI.SYSTEM))
	var push: Array = pet.get("push", [])
	for k in ATTR_ROWS.size():
		for side in 2:
			var i: int = ATTR_ROWS[k][side]
			var v := float(push[i]) if i < push.size() else 0.0
			var text := str(floori(v)) if i < 8 else str(floori(v * 100.0)) + "%"
			var x := (COL2 if side == 0 else right) + XActorBook.js_width(ATTR[i] + "  ", XUI.FONT_SIZE)
			ops.append(_t(text, x, y + LH * (k + 1), COLW))
	y += LH * 19.0 / 2.0 + LH
	var skills := skill_ids(pet)
	ops.append(_t("技能数:" + str(skills.size()), 0, y, COLW))
	y += LH
	var x := 0.0
	for i in skills.size():
		var sk := XDB.rec("Skills", int(skills[i]))
		ops.append(["i", int(sk.get("iconIndex", 0)), x + 2, y + 2])
		ops.append(_t(str(sk.get("name", "")), x + 36, y, COLW - 36, XQuality.list_color(sk)))
		y += LH
		if (i + 1) % 4 == 0:
			x += COL2 * 2.0 / 3.0
			y -= LH * 4
	return ops


## Star.PetSystem.Reduplication：技能去重（保留先出现的）
static func skill_ids(pet: Dictionary) -> Array:
	var out := []
	for id in pet.get("skills", []):
		if not out.has(int(id)):
			out.append(int(id))
	return out


func team_names() -> Array:
	var cur := int(XPets._data(XState.current).team_a)
	var out := []
	for i in 4:
		out.append("%d号角色%s" % [i + 1, "[当前共享]" if cur == i else ""])
	return out


# ---- 绘制 ----
func _paint_index(c: XMVCanvas) -> void:
	var s := XState.current
	var l := pets()
	if index >= top and index < top + ROWS and not l.is_empty():
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "index")
	for i in range(top, mini(top + ROWS, l.size())):
		_paint_ops(c, [_t(XPets.pet_name(s, l[i]).replace(MUTANT, ""), 6, (i - top) * LH, c.size.x - 12)])


func _paint_status(c: XMVCanvas) -> void:
	if _sprite_tex != null:
		var center := SPRITE_CENTER - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
		var src := Rect2(Vector2.ZERO, _sprite_tex.get_size())
		if _sprite_sv:
			var cw := _sprite_tex.get_width() / 9.0
			var ch := _sprite_tex.get_height() / 6.0
			src = Rect2([0, 1, 2, 1][floori(_frame / 12.0) % 4] * cw, 0, cw, ch)
		var scale := 1.0
		if src.size.x > CW / 2.0:
			scale = CW / src.size.x / 2.0
		var sz := src.size * scale
		c.draw_texture_rect_region(_sprite_tex, Rect2(center - sz / 2.0, sz), src)
	# 技能列表打开时 MV WindowLayer 把它的范围从状态窗里挖掉（y 540 以下）
	var ops := _status_ops
	if skill_win.openness > 0:
		ops = ops.filter(func(o): return STATUS_RECT.position.y + XMVWindow.PADDING + float(o[3]) + LH <= SKILL_RECT.position.y + 4)
	_paint_ops(c, ops)


static func _paint_ops(c: XMVCanvas, ops: Array) -> void:
	for o in ops:
		if o[0] == "i":
			c.icon(int(o[1]), o[2], o[3])
		else:
			c.text(o[1], o[2], o[3], o[4], o[6], o[8], int(o[7]), o[5])


func _paint_bottom(c: XMVCanvas) -> void:
	if mode == "bottom" and cmd >= cmd_top and cmd < cmd_top + BOTTOM_ROWS:
		c.cursor(Rect2(0, (cmd - cmd_top) * LH, c.size.x, LH), true)
	for i in range(cmd_top, mini(cmd_top + BOTTOM_ROWS, COMMANDS.size())):
		c.text(COMMANDS[i][0], 6, (i - cmd_top) * LH, c.size.x - 12, "left", XUI.TEXT, XUI.FONT_SIZE, LH, XUI.DIM.a if NOT_YET.has(COMMANDS[i][1]) else 1.0)


func _paint_team(c: XMVCanvas) -> void:
	if team >= 0:
		c.cursor(Rect2(0, team * LH, c.size.x, LH), mode == "team")
	var names := team_names()
	for i in names.size():
		c.text(names[i], 6, i * LH, c.size.x - 12)


func _paint_skills(c: XMVCanvas) -> void:
	var ids := skill_ids(current())
	if skill_index >= skill_top and skill_index < skill_top + SKILL_ROWS:
		c.cursor(Rect2(0, (skill_index - skill_top) * LH, c.size.x, LH), mode == "skills")
	for i in range(skill_top, mini(skill_top + SKILL_ROWS, ids.size())):
		var sk := XDB.rec("Skills", int(ids[i]))
		var y := (i - skill_top) * LH
		c.icon(int(sk.get("iconIndex", 0)), 2, y + 2)
		c.text(str(sk.get("name", "")), 36, y, CW - 6 - XActorBook.js_width("000", XUI.FONT_SIZE) - 36, "left", XQuality.list_color(sk))


# ---- 操作 ----
## Scene_PetSystem.update：目录选中项变了刷新状态窗
func _select_pet() -> void:
	var pet := current()
	_status_ops = status_ops(XState.current, pet)
	_sprite_tex = null
	_sprite_sv = false
	if not pet.is_empty():
		var rec := XDB.rec("Enemies", int(pet.enemy))
		var side := str(rec.get("meta", {}).get("Sideview Battler", "")).strip_edges()
		if side != "":
			var p := XDB.img_path("sv_actors", side)
			_sprite_tex = load(p) if p != "" else null
			_sprite_sv = _sprite_tex != null
		else:
			_sprite_tex = XMapTransfer.enemy_texture(rec)
	_refresh()


func _refresh() -> void:
	index_win.up_arrow = top > 0
	index_win.down_arrow = top + ROWS < pets().size()
	bottom_win.up_arrow = cmd_top > 0
	bottom_win.down_arrow = cmd_top + BOTTOM_ROWS < COMMANDS.size()
	skill_win.up_arrow = skill_top > 0
	skill_win.down_arrow = skill_top + SKILL_ROWS < skill_ids(current()).size()
	for w in [index_win, status_win, skill_win, bottom_win, team_win]:
		w.refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	top = XMenu._scroll_to(index, top, ROWS)
	_select_pet()


func _toast(text: String) -> void:
	XToast.show_text(text, true)


func ok() -> void:
	var s := XState.current
	match mode:
		"index":
			if pets().is_empty():
				return
			# onRangeOk → startBottomConfirmWindow
			XSound.system(1)
			mode = "bottom"
			cmd = 0
		"bottom":
			if NOT_YET.has(COMMANDS[cmd][1]):
				XSound.system(3)
				return
			XSound.system(1)
			match COMMANDS[cmd][1]:
				"war":
					_toast("出战成功" if XPets.go_to_war(s, index) else "已出战")
					_back_to_index()
				"rest":
					_toast("已休息" if XPets.rest(s, index) else "未出战")
					_back_to_index()
				"release":
					XPets.release(s, index)
					_toast("已放生")
					# 原版 indexWindow.setup：重建目录、选第 0 项、激活
					mode = "index"
					cmd = -1
					index = 0
					top = 0
					_select_pet()
				"team":
					mode = "team"
					team = 0
					team_win.open()
				"skills":
					mode = "skills"
					skill_index = 0
					skill_top = 0
					skill_win.open()
					_update_help()
		"team":
			XSound.system(1)
			XPets.set_team_a(s, team)
			_close_team()
		"skills":
			pass
	_select_pet()


## onCancel：底部指令停用（不关），回目录
func _back_to_index() -> void:
	mode = "index"
	cmd = -1
	cmd_top = 0


func _close_team() -> void:
	team_win.close()
	team = -1
	mode = "bottom"


func cancel() -> void:
	XSound.system(2)
	match mode:
		"index":
			closed.emit()
			return
		"bottom":
			_back_to_index()
		"team":
			_close_team()
		"skills":
			skill_win.close()
			skill_index = -1
			help_card.show_for({})
			mode = "bottom"
	_select_pet()


## Window_PetSkillList.updateHelp：说明卡在选中行右下（超出画面靠右／靠下）
func _update_help() -> void:
	var ids := skill_ids(current())
	if skill_index < 0 or skill_index >= ids.size():
		help_card.show_for({})
		return
	help_card.show_for(XDB.rec("Skills", int(ids[skill_index])), "skill")
	var sx := SKILL_RECT.position.x + CW - 4.0
	var sy := SKILL_RECT.position.y + (skill_index - skill_top) * LH + LH - 4.0
	if sx + help_card.size.x > 1280:
		sx = 1280 - help_card.size.x
	if sy + help_card.size.y > 720:
		sy = 720 - help_card.size.y - 4
	help_card.position = Vector2(sx, sy)


func _move(d: int, wrap: bool) -> void:
	match mode:
		"index":
			if not pets().is_empty():
				select(XMenu._move(index, d, pets().size(), wrap))
		"bottom":
			cmd = XMenu._move(cmd, d, COMMANDS.size(), wrap)
			cmd_top = XMenu._scroll_to(cmd, cmd_top, BOTTOM_ROWS)
			XSound.system(0)
			_refresh()
		"team":
			team = XMenu._move(team, d, 4, wrap)
			XSound.system(0)
			_refresh()
		"skills":
			var n := skill_ids(current()).size()
			if n > 0:
				skill_index = XMenu._move(skill_index, d, n, wrap)
				skill_top = XMenu._scroll_to(skill_index, skill_top, SKILL_ROWS)
				XSound.system(0)
				_update_help()
				_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
