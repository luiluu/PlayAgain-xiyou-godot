class_name XBattleScene
extends Control
## 侧视战斗画面，照原版界面（用户 2026-10-12 要求「界面风格用原版界面风格」）：
## - 布局按 Olivia_SideBattleUI：我方站位 x = 宽/2+128+序号×64、y = 高-235-(5-序号-1)×48；
##   右侧每人一条状态（缩放 0.6：名字、HP/MP/TP 量条、左侧状态图标，轮到谁谁左移 48）；
##   指令窗（宽 220、缩放 0.8）出现在行动角色身旁，技能/物品列表（宽 450）在其右下；顶部暗底说明栏。
## - 敌人在敌群编辑器坐标（原版 1280×720 原样使用），1 倍大小，神话 1.8 倍并偏色；
##   YEP_X_VisualHpGauge：敌人脚下 12px 粗血条（受伤或选目标时显示，带数值）。
## - 伤害数字用原版 Damage.png（XDamagePopup，MOG 弹跳＋放大）。
## 规则在 XBattleLogic；结束时发出 finished(0 胜利 / 1 逃跑 / 2 战败)。

signal finished(result: int)
signal _picked(value)

const BOX := Vector2(1280, 720)           # 原版画面尺寸（坐标基准）
const STATUS_SCALE := 0.6
const STATUS_W := 200.0
const STATUS_MOVE := 48.0
const CMD_W := 220.0
const CMD_SCALE := 0.8
const LIST_W := 450.0
const LIST_MAX := 16
const ENEMY_GAUGE_W := 180.0

var logic := XBattleLogic.new()
var map_data: Dictionary
var troop_id := 0
var can_lose := false
var sprites := {}                 # XBattler -> XBattlerSprite
var gauges := {}                  # XEnemy -> {box, timer}
var status_rows := {}             # XActor -> {root, home}
var field: Node2D
var fx: Node2D
var ui: Control
var help_bar: Control
var help_label: Label
var help_cancel: Button
var cmd_win: PanelContainer
var list_win: PanelContainer
var auto_btn: Button
var speed_btn: Button
var bgm: AudioStreamPlayer
var se: AudioStreamPlayer
var _target_mode := ""            # "enemy" / "ally" / ""
var _target_pool: Array = []
var _active: XActor = null
var _fast := false
var _origin := Vector2.ZERO       # 原版坐标 → 画面坐标的偏移
## 自动测试用：强制自动战斗，胜利界面自动关闭。
static var force_auto := false


func setup(troop: int, escape: bool, lose: bool, map: Dictionary) -> void:
	troop_id = troop
	can_lose = lose
	map_data = map
	logic.can_escape = escape
	logic.setup(troop, XState.current)
	logic.auto = force_auto


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport_rect().size
	_origin = Vector2((vs.x - BOX.x) / 2.0, (vs.y - BOX.y) / 2.0)
	_build_background()
	field = Node2D.new()
	field.position = _origin
	add_child(field)
	fx = Node2D.new()
	fx.position = _origin
	add_child(fx)
	_place_battlers()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	_build_ui(vs)
	bgm = AudioStreamPlayer.new()
	add_child(bgm)
	se = AudioStreamPlayer.new()
	add_child(se)
	var music: Dictionary = XDB.system().battleBgm
	var p := XDB.audio_path("bgm", str(music.name))
	if p != "":
		bgm.stream = load(p)
		bgm.volume_db = linear_to_db(float(music.volume) / 100.0)
		bgm.play()
	_main.call_deferred()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---- 布局 ----
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var names := [str(map_data.get("battleback1Name", "")), str(map_data.get("battleback2Name", ""))]
	if names[0] == "":
		names = [str(XDB.system().battleback1Name), str(XDB.system().battleback2Name)]
	for i in range(2):
		var p := XDB.img_path("battlebacks%d" % (i + 1), names[i]) if names[i] != "" else ""
		if p == "":
			continue
		var t := TextureRect.new()
		t.texture = load(p)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(t)


func _place_battlers() -> void:
	for e in logic.enemies:
		var s := XBattlerSprite.new()
		field.add_child(s)
		s.setup(e, 1.8 if e.elite else 1.0)
		s.breathing = true
		s.home = Vector2(float(e.get_meta("x")), float(e.get_meta("y")))
		s.position = s.home
		sprites[e] = s
		_make_enemy_gauge(e)
	var n := logic.actors.size()
	var max_members := 5
	for i in range(n):
		var a: XActor = logic.actors[i]
		var s := XBattlerSprite.new()
		field.add_child(s)
		s.setup(a, 1.0)
		s.home = Vector2(BOX.x * 0.5 + 128 + i * 64, BOX.y - 235 - (max_members - i - 1) * 48)
		s.position = s.home + Vector2(300, 0)
		sprites[a] = s
		var t := create_tween()
		t.tween_property(s, "position", s.home, 0.4).set_delay(0.05 * i)


## YEP_X_VisualHpGauge：宽 max(180, 图宽)、高 12，底色 19、渐变 20→21，显示当前 HP 数值。
func _make_enemy_gauge(e: XEnemy) -> void:
	var s: XBattlerSprite = sprites[e]
	var w := maxf(ENEMY_GAUGE_W, s.width())
	var box := Control.new()
	box.position = s.home + Vector2(-w / 2.0, -16 + 4)
	box.size = Vector2(w, 34)
	box.visible = false
	box.z_index = 5
	field.add_child(box)
	var name := XUI.label(e.display_name(), 15, _enemy_name_color(e))
	name.add_theme_constant_override("outline_size", 4)
	name.position = Vector2(0, -2)
	box.add_child(name)
	gauges[e] = {"box": box, "timer": 0.0, "name": name}
	_refresh_enemy_gauge(e)


## EnemyNameColorByDifficulty：名字与数据库原名完全相同时按难度上色（带 ＡＢＣ 或前缀的不变）。
func _enemy_name_color(e: XEnemy) -> Color:
	var colors := {1: "#ffffff", 2: "#39ff39", 3: "#4499ff", 4: "#b050ff", 5: "#ff9922", 6: "#ffd700", 7: "#ff2222", 8: "#ee77ee"}
	if e.display_name() == str(e.data().get("name", "")) and colors.has(e.difficulty_id):
		return Color(colors[e.difficulty_id])
	return XUI.TEXT


func _refresh_enemy_gauge(e: XEnemy) -> void:
	var g: Dictionary = gauges[e]
	var box: Control = g.box
	for c in box.get_children():
		if c != g.name:
			c.queue_free()
	var w := box.size.x
	var bar := XUI.gauge(e.hp, e.mhp, "hp", w, 12)
	bar.position = Vector2(0, 18)
	box.add_child(bar)
	var v := XUI.label(str(int(e.hp)), 16)
	v.position = Vector2(0, 10)
	v.size = Vector2(w - 4, 20)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(v)


func _show_enemy_gauge(e: XBattler, seconds := 1.5) -> void:
	if not gauges.has(e):
		return
	_refresh_enemy_gauge(e)
	gauges[e].timer = seconds
	gauges[e].box.visible = e.is_alive() or seconds > 0.0


func _build_ui(vs: Vector2) -> void:
	# 顶部说明栏（Olivia：Window_Help 不透明度 0、暗底；YEP 行动名也显示在顶部）
	help_bar = XUI.dimmer(false, true)
	help_bar.position = Vector2.ZERO
	help_bar.size = Vector2(vs.x - STATUS_W, XUI.LINE_HEIGHT * 2 + 28)
	help_bar.visible = false
	ui.add_child(help_bar)
	help_label = XUI.label("", XUI.FONT_SIZE)
	help_label.position = Vector2(18, 14)
	help_label.size = Vector2(help_bar.size.x - 160, help_bar.size.y - 28)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_bar.add_child(help_label)
	help_cancel = XUI.button("返回", 44)
	help_cancel.alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_cancel.add_theme_stylebox_override("normal", XUI.panel())
	help_cancel.position = Vector2(help_bar.size.x - 340, 20)
	help_cancel.size = Vector2(110, 48)
	help_cancel.visible = false
	help_cancel.pressed.connect(func(): _picked.emit("cancel"))
	help_bar.add_child(help_cancel)
	# 右侧状态条
	var row_h := _status_height()
	for i in range(logic.actors.size()):
		var a: XActor = logic.actors[i]
		var root := Control.new()
		root.position = Vector2(vs.x - STATUS_W, row_h * i)
		root.size = Vector2(STATUS_W + STATUS_MOVE * 2, row_h)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(root)
		status_rows[a] = {"root": root, "home": root.position.x}
	_refresh_status()
	# 自动/加速：左下角小窗（原版 SSEP 加速开关、挂机）
	var side := HBoxContainer.new()
	side.position = Vector2(12, vs.y - 60)
	side.add_theme_constant_override("separation", 8)
	ui.add_child(side)
	auto_btn = _small_button("自动：关")
	auto_btn.pressed.connect(func():
		logic.auto = not logic.auto
		_refresh_auto()
		if logic.auto:
			_picked.emit("auto"))
	side.add_child(auto_btn)
	speed_btn = _small_button("速度 ×1")
	speed_btn.pressed.connect(func():
		_fast = not _fast
		Engine.time_scale = 2.0 if _fast else 1.0
		speed_btn.text = "速度 ×2" if _fast else "速度 ×1")
	side.add_child(speed_btn)
	_refresh_auto()


func _small_button(text: String) -> Button:
	var b := XUI.button(text, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", XUI.panel())
	b.custom_minimum_size.x = 120
	return b


func _status_height() -> float:
	# Window_BattleSideStatus：fittingHeight(4.5)（行高 36×0.6=22，无内边距）＋显示 TP 时再加一行
	var lh := roundf(XUI.LINE_HEIGHT * STATUS_SCALE)
	return lh * 4.5 + (lh if bool(XDB.system().get("optDisplayTp", false)) else 0.0)


func _refresh_auto() -> void:
	auto_btn.text = "自动：开" if logic.auto else "自动：关"


func _refresh_status() -> void:
	var lh := roundf(XUI.LINE_HEIGHT * STATUS_SCALE)
	var fs := roundi(XUI.FONT_SIZE * STATUS_SCALE)
	var show_tp := bool(XDB.system().get("optDisplayTp", false))
	for a in status_rows:
		var root: Control = status_rows[a].root
		for c in root.get_children():
			c.queue_free()
		var dim := XUI.dimmer(true, false)
		dim.size = root.size
		root.add_child(dim)
		var name := XUI.label(a.display_name(), fs, XUI.DEATH if a.is_dead() else XUI.TEXT)
		name.position = Vector2(4, ceilf(lh / 4.0) - 2)
		root.add_child(name)
		var rows := [["HP", a.hp, a.mhp, "hp"], ["MP", a.mp, a.mmp, "mp"]]
		if show_tp:
			rows.append(["TP", a.tp, 100.0, "tp"])
		for i in range(rows.size()):
			var r: Array = rows[i]
			var g := XUI.param_gauge(r[0], r[1], r[2], r[3], 160, fs)
			g.position = Vector2(8 * (i + 1) + 4, ceilf(lh / 4.0) + lh * (i + 1))
			root.add_child(g)
		# 状态图标：状态条左侧，最多 4 个
		var icons := HBoxContainer.new()
		icons.add_theme_constant_override("separation", 0)
		icons.alignment = BoxContainer.ALIGNMENT_END
		icons.size = Vector2(4 * 32 + 4, 32)
		icons.position = Vector2(-icons.size.x, lh - 2)
		root.add_child(icons)
		var n := 0
		for st in a.states():
			if int(st.get("iconIndex", 0)) > 0 and n < 4:
				var ic := TextureRect.new()
				ic.texture = XUI.icon_texture(int(st.iconIndex))
				icons.add_child(ic)
				n += 1
	for s in sprites.values():
		s.refresh_idle()


## 轮到输入指令的角色：状态条左移 48，角色前进一步（MV Sprite_Actor：输入中 stepForward）。
func _set_active(a: XActor) -> void:
	_active = a
	for b in logic.actors:
		var sp: XBattlerSprite = sprites[b]
		var tw := create_tween()
		tw.tween_property(sp, "position", sp.home + (Vector2(-48, 0) if b == a and b.is_alive() else Vector2.ZERO), 0.15)
	for b in status_rows:
		var row: Dictionary = status_rows[b]
		var target_x: float = row.home - (STATUS_MOVE if b == a else 0.0)
		var tw := create_tween()
		tw.tween_property(row.root, "position:x", target_x, 0.15)


func _help(text: String, cancel := false) -> void:
	help_bar.visible = text != ""
	help_label.text = text
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help_cancel.visible = cancel


func _banner(text: String) -> void:
	help_bar.visible = text != ""
	help_label.text = text
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_cancel.visible = false


func _process(delta: float) -> void:
	for e in gauges:
		var g: Dictionary = gauges[e]
		if _target_mode == "enemy" and _target_pool.has(e):
			g.box.visible = true
			continue
		if g.timer > 0.0:
			g.timer -= delta
			if g.timer <= 0.0:
				g.box.visible = false


# ---- 主循环 ----
func _main() -> void:
	await _say("%s 出现了！" % "、".join(logic.enemies.map(func(e): return e.display_name())), 0.9)
	while true:
		if logic.is_won():
			await _victory()
			finished.emit(0)
			return
		if logic.is_lost():
			await _say("全军覆没……", 1.2)
			logic.end_battle()
			finished.emit(2)
			return
		var cmds = {} if logic.auto else await _input_commands()
		if cmds is String and cmds == "escape":
			_close_windows()
			if logic.try_escape():
				await _say("成功逃跑了。", 0.8)
				logic.end_battle()
				finished.emit(1)
				return
			await _say("没能逃掉！", 0.8)
			cmds = {}
			for a in logic.actors:
				cmds[a] = [null, null]
		_close_windows()
		_set_active(null)
		var logs := logic.run_turn(cmds if cmds is Dictionary else {})
		await _play(logs)
		_refresh_status()


func _close_windows() -> void:
	for w in [cmd_win, list_win]:
		if w and is_instance_valid(w):
			w.queue_free()
	cmd_win = null
	list_win = null
	_help("")


## 依次为每位能行动的角色选指令；返回 {actor: [技能或物品, 目标]}，或 "escape"。
func _input_commands():
	var cmds := {}
	var members := logic.alive(logic.actors).filter(func(a): return not logic._restricted(a))
	var i := 0
	while i < members.size():
		var a: XActor = members[i]
		_set_active(a)
		var r = await _command_for(a)
		if logic.auto:
			_close_windows()
			return {}
		if r is String and r == "escape":
			return "escape"
		if r is String and r == "back":
			i = maxi(0, i - 1)
			continue
		cmds[a] = r
		i += 1
	_set_active(null)
	return cmds


## 窗口（指令窗/列表窗）：MV 窗口皮肤，缩放 0.8 的行。
func _list_window(width: float) -> Array:
	var w := PanelContainer.new()
	var st := XUI.panel()
	for side in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + side, roundf(14 * CMD_SCALE))
	w.add_theme_stylebox_override("panel", st)
	w.custom_minimum_size.x = width
	ui.add_child(w)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	w.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	scroll.add_child(col)
	return [w, scroll, col]


func _row_button(text: String, icon_index := 0) -> Button:
	var b := XUI.button(text, roundf(XUI.LINE_HEIGHT * CMD_SCALE) + 8)
	b.add_theme_font_size_override("font_size", roundi(XUI.FONT_SIZE * CMD_SCALE))
	if icon_index > 0:
		b.icon = XUI.icon_texture(icon_index)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", roundi(32 * CMD_SCALE))
	return b


## 窗口贴着角色：x = 角色右侧，y = 角色头顶；超出画面时收回（Olivia correctScreenPosition）。
func _place_near_actor(w: Control, a: XActor, offset := Vector2.ZERO) -> void:
	var vs := get_viewport_rect().size
	var s: XBattlerSprite = sprites[a]
	await get_tree().process_frame
	if not is_instance_valid(w):
		return
	var p := _origin + s.home + Vector2(s.width() / 2.0, -s.height()) + offset
	p.x = minf(p.x, vs.x - w.size.x)
	p.y = clampf(p.y, 0.0, vs.y - w.size.y)
	w.position = p


func _command_for(a: XActor):
	while true:
		_close_windows()
		var parts := _list_window(CMD_W)
		cmd_win = parts[0]
		var col: VBoxContainer = parts[2]
		var terms: Array = XDB.system().terms.commands
		var opts := [[str(terms[2]), "attack"]]
		var stypes: Array = XDB.system().skillTypes
		var added := a.traits_set(XBattler.TRAIT_STYPE_ADD)
		added.sort()
		for t in added:
			if int(t) != 4 and int(t) < stypes.size() and logic.battle_skills(a).any(func(s): return int(s.stypeId) == int(t)):
				opts.append([str(stypes[int(t)]), "stype:%d" % int(t)])
		opts.append([str(terms[3]), "guard"])
		opts.append([str(terms[4]), "item"])
		if logic.can_escape:
			opts.append([str(terms[1]), "escape"])
		(parts[1] as ScrollContainer).custom_minimum_size.y = (roundf(XUI.LINE_HEIGHT * CMD_SCALE) + 8) * opts.size()
		for o in opts:
			var b := _row_button(o[0])
			var key: String = o[1]
			b.pressed.connect(func(): _picked.emit(key))
			col.add_child(b)
		(col.get_child(0) as Button).grab_focus.call_deferred()
		_place_near_actor(cmd_win, a)
		var pick = await _picked
		if pick is String and pick == "auto":
			return "auto"
		if pick is String and pick.begins_with("stype:"):
			var s = await _pick_from_list(a, logic.battle_skills(a).filter(func(x): return int(x.stypeId) == int(pick.substr(6))), false)
			if logic.auto:
				return "auto"
			if s is Dictionary:
				var t = await _pick_target(s, a)
				if logic.auto:
					return "auto"
				if t != null:
					return [s, t]
			continue
		match pick:
			"attack":
				var atk := XDB.rec("Skills", XBattleLogic.ATTACK_SKILL)
				var t = await _pick_target(atk, a)
				if logic.auto:
					return "auto"
				if t != null:
					return [atk, t]
			"guard":
				return [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null]
			"escape":
				return "escape"
			"item":
				var it = await _pick_from_list(a, logic.battle_items(), true)
				if logic.auto:
					return "auto"
				if it is Dictionary:
					var t = await _pick_target(it, a)
					if logic.auto:
						return "auto"
					if t != null:
						return [it, t]
			"back", "cancel":
				return "back"
	return null


## 技能/物品列表（Olivia：宽 450、最多 16 行、缩放 0.8）。
## 技能右侧显示消耗（MP 用颜色 23）；冷却中显示「nCD」（颜色 6），预热「nWU」（颜色 4），不可用时整行半透明。
func _pick_from_list(a: XActor, entries: Array, items: bool):
	if list_win and is_instance_valid(list_win):
		list_win.queue_free()
	var parts := _list_window(LIST_W)
	list_win = parts[0]
	var scroll: ScrollContainer = parts[1]
	var col: VBoxContainer = parts[2]
	var row_h := roundf(XUI.LINE_HEIGHT * CMD_SCALE) + 8
	scroll.custom_minimum_size.y = row_h * mini(maxi(entries.size(), 1), LIST_MAX)
	var fs := roundi(XUI.FONT_SIZE * CMD_SCALE)
	if entries.is_empty():
		col.add_child(XUI.label("（没有可用的%s）" % ("物品" if items else "技能"), fs, XUI.DIM))
	for e in entries:
		var ok := logic.can_use(a, e)
		var b := _row_button(str(e.name), int(e.get("iconIndex", 0)))
		b.disabled = not ok
		var right := ""
		var color := XUI.TEXT
		if items:
			right = ":%d" % int(XState.current.items.get(int(e.id), 0))
		else:
			var cd := int(ceilf(float(a.cooldowns.get(int(e.id), 0))))
			var wu := int(ceilf(float(a.warmups.get(int(e.id), 0))))
			if wu > 0:
				right = "%dWU" % wu
				color = XUI.text_color(4)
			elif cd > 0:
				right = "%dCD" % cd
				color = XUI.text_color(6)
			else:
				var c := logic.skill_cost(a, e)
				if c.tp > 0:
					right = str(c.tp)
					color = XUI.TP_COST
				elif c.mp > 0:
					right = str(c.mp)
					color = XUI.MP_COST
		if right != "":
			var r := XUI.label(right, fs, color if ok else Color(color, 0.63))
			r.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			r.offset_left = -110
			r.offset_right = -8
			r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(r)
		var desc := XText.plain(str(e.get("description", "")))
		b.focus_entered.connect(func(): _help(desc))
		b.mouse_entered.connect(func(): _help(desc))
		var rec: Dictionary = e
		b.pressed.connect(func(): _picked.emit(rec))
		col.add_child(b)
	_place_near_actor(list_win, a, Vector2(16, 16))
	_help("")
	for i in range(col.get_child_count()):
		var c := col.get_child(i)
		if c is Button and not c.disabled:
			c.grab_focus.call_deferred()
			_help(XText.plain(str(entries[i].get("description", ""))))
			break
	while true:
		var r = await _picked
		if r is Dictionary:
			_close_list()
			return r
		if r is String and (r == "cancel" or r == "back" or r == "auto"):
			_close_list()
			return null


func _close_list() -> void:
	if list_win and is_instance_valid(list_win):
		list_win.queue_free()
	list_win = null
	_help("")


## 单体技能：点敌人（或我方）选目标；全体/自身直接返回占位目标。
func _pick_target(skill: Dictionary, a: XActor):
	var scope := int(skill.get("scope", 1))
	if not [1, 7, 9].has(scope):
		return a
	var pool := logic.alive(logic.enemies) if scope == 1 else (logic.alive(logic.actors) if scope == 7 else logic.actors.filter(func(x): return x.is_dead()))
	if pool.size() == 1:
		return pool[0]
	if pool.is_empty():
		return null
	_target_mode = "enemy" if scope == 1 else "ally"
	_target_pool = pool
	if cmd_win and is_instance_valid(cmd_win):
		cmd_win.visible = false
	_help("选择目标（点按）", true)
	for b in pool:
		sprites[b].flash(Color(1, 0.9, 0.5))
		if gauges.has(b):
			_refresh_enemy_gauge(b)
	var r = await _picked
	_target_mode = ""
	_target_pool = []
	_help("")
	if cmd_win and is_instance_valid(cmd_win):
		cmd_win.visible = true
	for e in gauges:
		gauges[e].box.visible = gauges[e].timer > 0.0
	if r is XBattler and pool.has(r):
		return r
	return null


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_picked.emit("cancel" if _target_mode != "" or list_win != null else "back")
			return
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == Vector2.INF or _target_mode == "":
		return
	var best = null
	var best_d := 1e9
	for b in _target_pool:
		var s: XBattlerSprite = sprites[b]
		var c := _origin + s.position + Vector2(0, -s.height() / 2.0)
		var d := c.distance_to(pos)
		if d < best_d and d < maxf(90.0, s.height()):
			best_d = d
			best = b
	if best != null:
		_picked.emit(best)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_picked.emit("cancel" if _target_mode != "" or list_win != null else "back")


# ---- 播放行动记录 ----
func _play(logs: Array) -> void:
	for l in logs:
		match l.type:
			"action":
				var s: XBattlerSprite = sprites[l.user]
				var item := XBattleLogic.is_item(l.skill)
				if item or int(l.skill.id) > XBattleLogic.GUARD_SKILL:
					_banner(str(l.skill.name))
				if l.user is XActor:
					_set_active(l.user)
					await s.step(true)
					s.set_motion("item" if item else ("swing" if int(l.skill.id) == XBattleLogic.ATTACK_SKILL else ("spell" if XDamage.is_magical(l.skill) else "skill")))
				else:
					s.flash(Color(1, 0.6, 0.6))
				await get_tree().create_timer(0.18).timeout
			"hit":
				await _show_hit(l)
			"counter":
				_popup(l.user, 0, false, "counter")
				await get_tree().create_timer(0.3).timeout
			"reflect":
				_popup(l.target, 0, false, "reflect")
				var ra := MVAnimation.play(fx, _reflect_animation(), _center(l.target), false)
				await get_tree().create_timer(0.3 if ra else 0.2).timeout
			"guard":
				sprites[l.user].set_motion("guard")
			"regen":
				if float(l.hp) != 0.0:
					_popup(l.target, -float(l.hp), false)
			"skip":
				pass
		if l.type == "hit" and l.user is XActor and not _next_is_same_action(logs, l):
			await sprites[l.user].step(false)
			_banner("")
		_refresh_status()
	_banner("")
	_set_active(null)
	for s in sprites.values():
		s.position = s.home


func _reflect_animation() -> int:
	return int(XDB.plugin("YEP_BattleEngineCore").get("Reflect Animation", "0"))


func _next_is_same_action(logs: Array, l: Dictionary) -> bool:
	var i := logs.find(l)
	return i + 1 < logs.size() and logs[i + 1].type == "hit" and logs[i + 1].user == l.user


func _center(b: XBattler) -> Vector2:
	var s: XBattlerSprite = sprites[b]
	return s.position + Vector2(0, -s.height() / 2.0)


func _show_hit(l: Dictionary) -> void:
	var t: XBattler = l.target
	var ts: XBattlerSprite = sprites[t]
	var anim_id := int(l.skill.animationId)
	if anim_id < 0:
		anim_id = _attack_animation(l.user)
	if anim_id > 0:
		var a := MVAnimation.play(fx, anim_id, _center(t), false)
		if a:
			await get_tree().create_timer(0.25).timeout
	if l.missed or l.evaded:
		_popup(t, 0, false, "miss")
		ts.set_motion("evade")
	else:
		if float(l.hp) != 0.0:
			_popup(t, float(l.hp), l.critical)
			if float(l.hp) > 0.0:
				ts.flash(Color(1, 0.5, 0.5))
				ts.set_motion("damage")
		if float(l.mp) != 0.0:
			_popup(t, float(l.mp), false, "", true)
		if t is XEnemy:
			_show_enemy_gauge(t)
	if l.died:
		if gauges.has(t):
			gauges[t].box.visible = false
			gauges[t].timer = 0.0
		await ts.collapse()
	await get_tree().create_timer(0.22).timeout


func _attack_animation(u: XBattler) -> int:
	if u is XActor:
		for e in (u as XActor).equip_list():
			if e.kind == "weapon":
				return int(e.animationId)
		return 1
	return int(XDB.plugin("YEP_BattleEngineCore").get("Enemy Attack Animation", "1"))


## 伤害数字（XDamagePopup）。text: "miss" / "counter" / "reflect"。
func _popup(b: XBattler, value: float, critical: bool, text := "", is_mp := false) -> void:
	var p := XDamagePopup.new()
	p.position = _center(b)
	p.z_index = 20
	fx.add_child(p)
	p.setup(value, "mp" if is_mp else "hp", critical, text)


func _say(text: String, seconds: float) -> void:
	_banner(text)
	await get_tree().create_timer(seconds).timeout
	_banner("")


## 胜利：我方胜利动作；顶部「战斗胜利」，中间窗口列出经验、金钱、掉落与升级（MV 窗口皮肤）。
func _victory() -> void:
	for a in logic.alive(logic.actors):
		sprites[a].set_motion("victory")
	var r := logic.rewards()
	var ups := logic.grant(r)
	logic.end_battle()
	var me: Dictionary = XDB.system().get("victoryMe", {})
	var p := XDB.audio_path("me", str(me.get("name", "")))
	bgm.stop()
	if p != "":
		bgm.stream = load(p)
		bgm.play()
	_close_windows()
	_banner("战斗胜利！")
	var w := PanelContainer.new()
	w.add_theme_stylebox_override("panel", XUI.panel())
	w.custom_minimum_size.x = 560
	ui.add_child(w)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	w.add_child(col)
	var exp_row := HBoxContainer.new()
	exp_row.add_child(XUI.label("经验值", XUI.FONT_SIZE, XUI.SYSTEM))
	var ev := XUI.label("+%d" % r.exp)
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exp_row.add_child(ev)
	col.add_child(exp_row)
	var gold_row := HBoxContainer.new()
	gold_row.add_child(XUI.label(str(XDB.system().currencyUnit), XUI.FONT_SIZE, XUI.SYSTEM))
	var gv := XUI.label("+%d" % r.gold)
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_row.add_child(gv)
	col.add_child(gold_row)
	for d in r.drops:
		var table: String = {1: "Items", 2: "Weapons", 3: "Armors"}[int(d.kind)]
		var rec := XDB.rec(table, int(d.id))
		var row := HBoxContainer.new()
		var ic := TextureRect.new()
		ic.texture = XUI.icon_texture(int(rec.get("iconIndex", 0)))
		ic.custom_minimum_size = Vector2(32, 32)
		row.add_child(ic)
		row.add_child(XUI.label(str(rec.get("name", "?")), 24))
		col.add_child(row)
	for u in ups:
		col.add_child(XUI.label("%s 升到 %d 级！" % [u.actor.display_name(), u.actor.level], 24, XUI.POWER_UP))
	var ok := XUI.button("继续", 44)
	ok.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.pressed.connect(func(): _picked.emit("ok"))
	col.add_child(ok)
	w.resized.connect(func(): w.position = (get_viewport_rect().size - w.size) / 2.0)
	ok.grab_focus.call_deferred()
	if logic.auto:
		await get_tree().create_timer(1.2).timeout
	else:
		while not (str(await _picked) == "ok"):
			pass
	Engine.time_scale = 1.0
