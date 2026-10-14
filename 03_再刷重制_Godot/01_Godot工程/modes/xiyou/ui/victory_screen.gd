class_name XVictoryScreen
extends Control
## Olivia_VictorySequenceUI：实际 1280×720 矩形与 Bitmap 绘制；奖励由逻辑层发放，页面只动画。
signal continued
const ROW_Y := 291.0
const ROW_STEP := 81.0
const ROW_W := 496.0
const DROP_RECT := Rect2(688, 234, 496, 396)
var rewards: Dictionary
var snapshots: Dictionary
var actors: Array
var automatic := false
var _elapsed := 0.0
var _ready_to_close := false
var rows := []
var hint: XMVCanvas
var canvas: XMVCanvas
var _origin := Vector2.ZERO
var _sound: AudioStreamPlayer
var _drops := []
var _drop_top := 0
var _hint_text: XMVText


func setup(r: Dictionary, before: Dictionary, members: Array, auto_close: bool) -> void:
	rewards = r
	snapshots = before
	actors = members
	automatic = auto_close


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_origin = (get_viewport_rect().size - Vector2(1280, 720)) / 2
	_sound = AudioStreamPlayer.new()
	XAudio.bind(_sound, "SE")
	add_child(_sound)
	canvas = XMVCanvas.new()
	canvas.position = _origin
	canvas.size = Vector2(1280, 720)
	canvas.painter = _paint
	add_child(canvas)
	for a in actors:
		rows.append({"actor": a, "rate": 0.0, "display_level": int(snapshots[a].level), "exp": int(snapshots[a].exp), "notified": false,
			"lv_scale": 0.0, "lv_opacity": 255.0, "lv_fade": 0.0})
	_drops = grouped_drops(rewards.get("drops", []))
	var raw := str(XDB.plugin("Olivia_VictorySequenceUI").get("Victory Screen Continue Text", "\\c[27]ESC\\c[0] 或者 \\c[27]点击屏幕\\c[0] 退出界面"))
	_hint_text = XMVText.new(XMVText.convert_escapes(raw), 6, 0)
	var width := _hint_text.run() + 6
	hint = XMVCanvas.new()
	hint.position = _origin + Vector2(1280 - 96 - width, 666)
	hint.size = Vector2(width, 36)
	hint.painter = func(c): XMVText.paint(c, _hint_text.glyphs)
	hint.visible = false
	add_child(hint)
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 32.0 / 60.0)
	_update_exp(0)


## 正式版先按物品/武器/防具分组，各组按 ID 排序、合并重复掉落。
static func grouped_drops(drops: Array) -> Array:
	var out := []
	var index := {}
	for d in drops:
		var key := "%d:%d" % [int(d.kind), int(d.id)]
		if index.has(key):
			out[index[key]].count += 1
		else:
			index[key] = out.size()
			out.append({"kind": int(d.kind), "id": int(d.id), "count": 1})
	out.sort_custom(func(a, b): return a.kind < b.kind or (a.kind == b.kind and a.id < b.id))
	return out


func _poly(c: XMVCanvas, coords: Array, color: Color) -> void:
	var p := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		p.append(Vector2(coords[i], coords[i + 1]))
	c.draw_colored_polygon(p, color)


func _paint(c: XMVCanvas) -> void:
	# 横向暗底渐隐；Bitmap 原件宽为 2 倍画面，右侧只渐隐了一半。
	c.gradient(Rect2(0, 144, 2560, 512 - 8), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0))
	c.gradient(Rect2(0, 650, 1280, 70), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6))
	for y in [142, 648]:
		c.draw_rect(Rect2(0, y, 1280, 2), Color(1, 1, 1, 160.0 / 255.0))
	for y in [180, 218]:
		_poly(c, [114,y,96,y+18,114,y+36], Color(1, 1, 1, 160.0/255.0))
		c.draw_rect(Rect2(114, y, 379, 36), Color(1, 1, 1, 160.0/255.0))
		c.gradient(Rect2(493, y, 99, 36), Color(1, 1, 1, 160.0/255.0), Color(0, 0, 0, 0))
	c.text("战斗胜利！", 96, 114, 1280, "left", XUI.TEXT, 60, 36)
	_reward(c, str(XDB.system().currencyUnit), int(rewards.gold), 180)
	_reward(c, str(XDB.system().terms.basic[8]), int(rewards.exp), 218)
	if not _drops.is_empty():
		c.draw_rect(Rect2(640, 216, 544, 2), Color(1, 1, 1, 160.0/255.0))
		c.text("获得物品", 688, 144, 496, "left", XUI.TEXT, 36, 72)
		for i in range(_drop_top, mini(_drop_top + 11, _drops.size())):
			var d: Dictionary = _drops[i]
			var rec := XDB.rec({1:"Items",2:"Weapons",3:"Armors"}[int(d.kind)], int(d.id))
			var y := 234.0 + (i - _drop_top) * 36.0
			var x := 694.0
			c.icon(int(rec.get("iconIndex", 0)), x + 2, y + 2)
			c.text(XQuality.list_name(rec) if rec.has("name") else "?", x + 36, y, 484 - c.text_width("000") - 36, "left", XGear.color(rec))
			c.text("×%s" % XMenu._group(d.count), x, y, 484, "right", XUI.TEXT, 20, 36)
	for i in range(rows.size()):
		_paint_actor(c, rows[i], ROW_Y + ROW_STEP * i)


func _reward(c: XMVCanvas, caption: String, amount: int, y: float) -> void:
	c.text(caption, 114, y, 248, "left", XUI.text_color(8), 20, 36, 160.0/255.0)
	c.text(XMenu._group(amount), 114, y, 372, "right", XUI.TEXT, 28, 36)


func _paint_actor(c: XMVCanvas, row: Dictionary, y: float) -> void:
	var x := 96.0
	_poly(c, [x+18,y,x,y+18,x+18,y+36,x+478,y+36,x+496,y+18,x+478,y], Color(0,0,0,0.6*160.0/255.0))
	c.draw_rect(Rect2(x + 18, y + 70, 460, 2), Color(1,1,1,160.0/255.0))
	c.draw_rect(Rect2(x + 18, y + 48, 460, 18), Color(XUI.GAUGE_BACK,160.0/255.0))
	var fill := roundf(460 * float(row.rate))
	if fill > 0:
		c.gradient(Rect2(x+18,y+48,fill,18), XUI.text_color(30), XUI.text_color(31))
	var a: XActor = row.actor
	c.text(a.display_name(), x+18, y, 460, "left", XUI.TEXT, 20, 36)
	c.text("Lv.%s" % XMenu._group(row.display_level), x+18, y, 460, "right", XUI.TEXT, 20, 36)
	var base := a.exp_for_level(row.display_level)
	var next := a.exp_for_level(row.display_level+1) - base
	var maxed: bool = row.display_level >= a.max_level()
	var current := "------" if maxed else XMenu._group(int(row.exp)-base)
	var tail := "/------" if maxed else "/" + XMenu._group(next)
	var w := 448.0
	c.text(str(XDB.system().terms.basic[8]), x+24, y+36, w, "left", XUI.TEXT, 16, 36)
	c.text(tail, x+24, y+36, w, "right", XUI.text_color(8), 18, 36)
	c.text(current, x+24, y+36, w-c.text_width(tail,18), "right", XUI.TEXT, 20, 36)
	# Olivia createLevelUpSprite：中心 (行宽/2, 18)，升级起每帧放大 0.02 到 1；不透明度每帧 ±4 在 255 与 0 之间往返
	if row.notified and row.lv_scale > 0.0:
		var center := Vector2(x + ROW_W / 2.0, y + 18)
		c.text("等级提升！", x, center.y - 36, ROW_W, "center", XUI.text_color(17), 36, 72, row.lv_opacity / 255.0, row.lv_scale, center)


var _frame_acc := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	# 升级字样按 60 帧/秒逐帧推进（Window_BattleVictoryActorSub.update）
	_frame_acc += delta
	while _frame_acc >= 1.0 / 60.0:
		_frame_acc -= 1.0 / 60.0
		for row in rows:
			if not row.notified:
				continue
			row.lv_scale = minf(1.0, row.lv_scale + 0.02)
			if row.lv_fade == 0.0:
				row.lv_fade = 4.0
			row.lv_opacity = clampf(row.lv_opacity + row.lv_fade, 0.0, 255.0)
			if row.lv_opacity >= 255.0 or row.lv_opacity <= 0.0:
				row.lv_fade = -row.lv_fade
	_update_exp(clampf(_elapsed / 3.0, 0, 1))
	if _elapsed >= 1.0:
		_ready_to_close = true
		hint.visible = true
	if automatic and _elapsed >= 3.4:
		set_process(false)
		continued.emit()


func _update_exp(progress: float) -> void:
	for row in rows:
		var a: XActor = row.actor
		var before: Dictionary = snapshots[a]
		var exp := roundi(lerpf(float(before.exp), float(a.exp_total), progress))
		var lv := int(before.level)
		while lv < a.max_level() and exp >= a.exp_for_level(lv+1):
			lv += 1
		var base := a.exp_for_level(lv)
		var next := a.exp_for_level(lv+1)
		row.rate = 1.0 if lv == a.max_level() else clampf(float(exp-base)/maxf(next-base,1),0,1)
		row.display_level = lv
		row.exp = exp
		if lv > int(before.level) and not row.notified:
			row.notified = true
			var path := XDB.audio_path("se", str(XDB.plugin("Olivia_VictorySequenceUI").get("Victory Screen Level Sound", "Skill2")))
			if path != "":
				_sound.stream = load(path)
				_sound.volume_db = linear_to_db(0.9)
				_sound.play()
	if canvas:
		canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or WindowFit.is_fullscreen_shortcut(event):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
		_drop_top = clampi(_drop_top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0,_drops.size()-11))
		canvas.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down",true) or event.is_action_pressed("ui_up",true):
		_drop_top = clampi(_drop_top + (1 if event.is_action_pressed("ui_down",true) else -1),0,maxi(0,_drops.size()-11))
		canvas.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	var confirm: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if confirm:
		get_viewport().set_input_as_handled()
		if _ready_to_close:
			set_process(false)
			continued.emit()
		else:
			_elapsed = 3.0
			_update_exp(1.0)
			_ready_to_close = true
			hint.visible = true
