class_name XVictoryScreen
extends Control
## Olivia_VictorySequenceUI：无窗口边框的奖励条、左侧四人经验条、右侧掉落清单。
## 奖励已由逻辑层一次性发放；这里仅从战前快照动画到最终经验，不重复写状态。
signal continued
var rewards: Dictionary
var snapshots: Dictionary
var actors: Array
var automatic := false
var _elapsed := 0.0
var _ready_to_close := false
var rows := []
var hint: Label
var _origin := Vector2.ZERO
var _sound: AudioStreamPlayer

func setup(r: Dictionary, before: Dictionary, members: Array, auto_close: bool) -> void:
	rewards = r
	snapshots = before
	actors = members
	automatic = auto_close

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_origin = (get_viewport_rect().size - Vector2(1280, 720)) / 2
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	_text("战斗胜利！", Vector2(96, 100), Vector2(600, 80), 60)
	_reward(str(XDB.system().currencyUnit), int(rewards.gold), 180)
	_reward("经验值", int(rewards.exp), 218)
	for i in range(actors.size()):
		var a: XActor = actors[i]
		var pos := Vector2(96, 315 + i * 81)
		var name_label := _text(a.display_name(), pos + Vector2(18, 0), Vector2(340, 36), 20)
		var lv := _text("Lv.%d" % int(snapshots[a].level), pos + Vector2(320, 0), Vector2(176, 36), 20)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var exp := _text("", pos + Vector2(18, 36), Vector2(478, 36), 18)
		exp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var gauge := Control.new()
		gauge.position = _origin + pos + Vector2(18, 46)
		gauge.size = Vector2(460, 18)
		add_child(gauge)
		move_child(gauge, gauge.get_index() - 1)
		var data := {"actor": a, "name": name_label, "level": lv, "exp": exp, "gauge": gauge, "rate": 0.0, "display_level": int(snapshots[a].level), "notified": false}
		gauge.draw.connect(func():
			gauge.draw_rect(Rect2(Vector2.ZERO, gauge.size), XUI.GAUGE_BACK)
			var rect := Rect2(1, 1, (gauge.size.x - 2) * data.rate, gauge.size.y - 2)
			if rect.size.x > 0:
				gauge.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([XUI.text_color(30), XUI.text_color(31), XUI.text_color(31), XUI.text_color(30)])))
		rows.append(data)
	_text("获得物品", Vector2(688, 144), Vector2(500, 72), 36)
	var scroll := ScrollContainer.new()
	scroll.position = _origin + Vector2(688, 234)
	scroll.size = Vector2(496, 408)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	for d in grouped_drops(rewards.get("drops", [])):
		var rec := XDB.rec({1: "Items", 2: "Weapons", 3: "Armors"}[int(d.kind)], int(d.id))
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 36
		col.add_child(row)
		var icon := TextureRect.new()
		icon.texture = XUI.icon_texture(int(rec.get("iconIndex", 0)))
		icon.custom_minimum_size = Vector2(32, 32)
		row.add_child(icon)
		var label := XUI.label(str(rec.get("name", "?")), 24)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.tooltip_text = label.text
		row.add_child(label)
		row.add_child(XUI.label("×%d" % int(d.count), 24))
	if rewards.get("drops", []).is_empty():
		col.add_child(XUI.label("没有获得物品", 24, XUI.DIM))
	hint = _text("ESC 或者 点击屏幕 退出界面", Vector2(688, 666), Vector2(496, 36), 22, XUI.text_color(27))
	hint.visible = false
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 32.0 / 60.0)
	_update_exp(0)

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
	return out

func _text(text: String, pos: Vector2, dims: Vector2, font_size: int, color := XUI.TEXT) -> Label:
	var label := XUI.label(text, font_size, color)
	label.position = _origin + pos
	label.size = dims
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _reward(caption: String, amount: int, y: float) -> void:
	_text(caption, Vector2(114, y), Vector2(200, 36), 20, XUI.text_color(8))
	var value := _text(str(amount), Vector2(320, y), Vector2(254, 36), 28)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _draw() -> void:
	var pos := _origin
	draw_rect(Rect2(pos + Vector2(0, 144), Vector2(1280, 512)), Color(0, 0, 0, 0.6))
	for y in [142, 656]:
		draw_line(pos + Vector2(0, y), pos + Vector2(1280, y), Color(1, 1, 1, 0.4), 2)
	draw_line(pos + Vector2(640, 216), pos + Vector2(1184, 216), Color(1, 1, 1, 0.4), 2)
	for y in [180, 218]:
		var points := PackedVector2Array([pos + Vector2(114, y), pos + Vector2(96, y + 18), pos + Vector2(114, y + 36), pos + Vector2(496, y + 36), pos + Vector2(574, y), pos + Vector2(114, y)])
		draw_colored_polygon(points, Color(1, 1, 1, 0.2))
	for i in range(actors.size()):
		var y := 315 + i * 81
		var points := PackedVector2Array([pos + Vector2(114, y), pos + Vector2(96, y + 18), pos + Vector2(114, y + 36), pos + Vector2(592, y + 36), pos + Vector2(592, y)])
		draw_colored_polygon(points, Color(0, 0, 0, 0.6))

func _process(delta: float) -> void:
	_elapsed += delta
	_update_exp(clampf(_elapsed / 3.0, 0, 1))
	if _elapsed >= 3.0:
		_ready_to_close = true
		hint.visible = true
		hint.modulate.a = 0.6 + 0.4 * sin(_elapsed * TAU)
	if automatic and _elapsed >= 3.4:
		set_process(false)
		continued.emit()

func _update_exp(progress: float) -> void:
	for row in rows:
		var a: XActor = row.actor
		var before: Dictionary = snapshots[a]
		var exp := roundi(lerpf(float(before.exp), float(a.exp_total), progress))
		var lv := int(before.level)
		while lv < a.max_level() and exp >= a.exp_for_level(lv + 1):
			lv += 1
		var maxed := lv == a.max_level()
		var base := a.exp_for_level(lv)
		var next := a.exp_for_level(lv + 1) if not maxed else base
		row.rate = 1.0 if maxed else clampf(float(exp - base) / maxf(next - base, 1), 0, 1)
		row.level.text = "Lv.%d" % lv
		row.exp.text = "EXP  ------ / ------" if maxed else "EXP  %d / %d" % [exp - base, next - base]
		row.gauge.queue_redraw()
		if lv > int(before.level):
			row.name.text = a.display_name() + "   等级提升！"
			row.name.add_theme_color_override("font_color", XUI.CRISIS)
			if not row.notified:
				row.notified = true
				var path := XDB.audio_path("se", str(XDB.plugin("Olivia_VictorySequenceUI").get("Victory Screen Level Sound", "Skill2")))
				if path != "":
					_sound.stream = load(path)
					_sound.volume_db = linear_to_db(0.9)
					_sound.play()

func _input(event: InputEvent) -> void:
	if not visible:
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
