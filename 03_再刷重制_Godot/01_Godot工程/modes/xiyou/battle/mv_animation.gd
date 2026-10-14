class_name MVAnimation
extends Node2D
## 播放 MV 动画（Animations.json）：每帧若干格子 [图案, x, y, 缩放%, 旋转, 翻转, 不透明度, 混合]，
## 图案 <100 取 animation1 图，>=100 取 animation2 图；每格 192×192、每行 5 格；每 4 帧（60fps）换一帧，与 MV 一致。
## position：0 头上 1 中心 2 脚下 3 画面中央（由调用方给出坐标）。

signal done

const CELL := 192
var anim: Dictionary
var sheets: Array = [null, null]
var frame := 0
var _tick := 0
var _sprites: Array[Sprite2D] = []
var se_player: AudioStreamPlayer


static func play(parent: Node, anim_id: int, at: Vector2, mirror := false) -> MVAnimation:
	var a := XDB.rec("Animations", anim_id)
	if a.is_empty():
		return null
	var n := MVAnimation.new()
	n.anim = a
	n.position = at
	n.scale.x = -1.0 if mirror else 1.0
	parent.add_child(n)
	return n


func _ready() -> void:
	for i in range(2):
		var name := str(anim.get("animation%dName" % (i + 1), ""))
		var p := XDB.img_path("animations", name) if name != "" else ""
		sheets[i] = load(p) if p != "" else null
	se_player = AudioStreamPlayer.new()
	XAudio.bind(se_player, "SE")
	add_child(se_player)
	_show_frame()


func _process(_delta: float) -> void:
	_tick += 1
	if _tick % 4 != 0:
		return
	frame += 1
	if frame >= anim.frames.size():
		done.emit()
		queue_free()
		return
	_show_frame()


func _show_frame() -> void:
	for t in anim.get("timings", []):
		if int(t.frame) == frame and t.get("se") and str(t.se.get("name", "")) != "":
			var p := XDB.audio_path("se", str(t.se.name))
			if p != "":
				se_player.stream = load(p)
				se_player.volume_db = linear_to_db(float(t.se.get("volume", 90)) / 100.0)
				se_player.pitch_scale = float(t.se.get("pitch", 100)) / 100.0
				se_player.play()
	var cells: Array = anim.frames[frame] if frame < anim.frames.size() else []
	while _sprites.size() < cells.size():
		var s := Sprite2D.new()
		s.region_enabled = true
		add_child(s)
		_sprites.append(s)
	for i in range(_sprites.size()):
		var s := _sprites[i]
		if i >= cells.size() or int(cells[i][0]) < 0:
			s.visible = false
			continue
		var c: Array = cells[i]
		var pattern := int(c[0])
		var tex: Texture2D = sheets[0 if pattern < 100 else 1]
		if tex == null:
			s.visible = false
			continue
		var local := pattern % 100
		s.visible = true
		s.texture = tex
		s.region_rect = Rect2((local % 5) * CELL, floori(local / 5.0) * CELL, CELL, CELL)
		s.position = Vector2(float(c[1]), float(c[2]))
		s.scale = Vector2.ONE * float(c[3]) / 100.0
		s.rotation_degrees = float(c[4])
		s.flip_h = int(c[5]) == 1
		s.modulate.a = float(c[6]) / 255.0
		var blend := int(c[7]) if c.size() > 7 else 0
		if blend == 1:
			if s.material == null:
				var m := CanvasItemMaterial.new()
				m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				s.material = m
		else:
			s.material = null
