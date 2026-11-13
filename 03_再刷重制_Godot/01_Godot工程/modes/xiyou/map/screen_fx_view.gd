class_name XScreenFxView
extends Node
## 地图画面的色调与天气（Spriteset_Base 的 ToneFilter、Weather）。
## 色调只作用在地图世界（不含窗口），天气画在世界之上、窗口之下；状态在 XState.current.screen。

const TONE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 offset = vec3(0.0);
uniform float gray = 0.0;
void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	// ToneFilter：先 adjustSaturation(-灰度)，再叠加 adjustTone 的偏移
	float t = clamp(gray, 0.0, 255.0) / 255.0;
	float x = 1.0 - t * 2.0 / 3.0;
	float y = t / 3.0;
	vec3 s = vec3(c.r * x + c.g * y + c.b * y, c.r * y + c.g * x + c.b * y, c.r * y + c.g * y + c.b * x);
	COLOR = vec4(clamp(s + offset / 255.0, 0.0, 1.0), c.a);
}
"""

## 回退开关（O-待定-1）：true＝天气的暗幕与全部雨／雪合成一次绘制；false＝回到逐片设变换、逐片画（下雪 70 片＝多 70 次绘制）
static var BATCH_WEATHER := true

var camera: Camera2D
var _tone_layer: CanvasLayer
var _tone_rect: ColorRect
var _tone_mat: ShaderMaterial
var _weather_layer: CanvasLayer
var _weather: _WeatherCanvas


func _init() -> void:
	_tone_layer = CanvasLayer.new()
	_tone_layer.layer = 1
	add_child(_tone_layer)
	_tone_rect = ColorRect.new()
	_tone_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tone_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = TONE_SHADER
	_tone_mat = ShaderMaterial.new()
	_tone_mat.shader = sh
	_tone_rect.material = _tone_mat
	_tone_rect.visible = false
	_tone_layer.add_child(_tone_rect)
	_weather_layer = CanvasLayer.new()
	_weather_layer.layer = 2
	add_child(_weather_layer)
	_weather = _WeatherCanvas.new()
	_weather.visible = false
	_weather_layer.add_child(_weather)


func _physics_process(_delta: float) -> void:
	var s := XState.current
	if s == null:
		return
	var fx := s.screen
	var tinted := fx.has_tone()
	_tone_rect.visible = tinted
	if tinted:
		_tone_mat.set_shader_parameter("offset", Vector3(fx.tone[0], fx.tone[1], fx.tone[2]))
		_tone_mat.set_shader_parameter("gray", float(fx.tone[3]))
	var raining: bool = fx.weather_type != "none" or fx.weather_power > 0.0
	_weather.visible = raining or _weather.has_sprites()
	if _weather.visible:
		var origin := Vector2.ZERO
		if camera != null and camera.is_inside_tree():
			origin = camera.get_screen_center_position() - Vector2(640, 360)
		_weather.step(fx.weather_type, fx.weather_power, origin)


## Weather：power×10 个粒子，类型决定位图、角度、速度；整屏叠一层 (80,80,80) 不透明度 power×6 的暗幕
class _WeatherCanvas extends Node2D:
	var _type := "none"
	var _power := 0.0
	var _origin := Vector2.ZERO
	var _sprites: Array = []     # {ax, ay, op}
	## 粒子只是画面效果，用自己的随机流，不动全局随机（遇敌、事件、战斗各有各的流）
	var _rng := RandomNumberGenerator.new()
	const SNOW_SEGMENTS := 64
	static var _snow_ring: Array = []

	func _init() -> void:
		if _snow_ring.is_empty():
			for k in SNOW_SEGMENTS:
				_snow_ring.append(Vector2(4, 0).rotated(TAU * k / SNOW_SEGMENTS))

	func has_sprites() -> bool:
		return not _sprites.is_empty()

	func step(type: String, power: float, origin: Vector2) -> void:
		_type = type
		_power = power
		_origin = origin
		var maxn := int(floor(power * 10.0))
		while _sprites.size() < maxn:
			_sprites.append({"ax": 0.0, "ay": 0.0, "op": 0.0})
		while _sprites.size() > maxn:
			_sprites.pop_back()
		var speed := 0.0
		match type:
			"rain":
				speed = 6.0
			"storm":
				speed = 8.0
			"snow":
				speed = 3.0
		var rot := _rotation()
		for sp in _sprites:
			if speed > 0.0:
				sp.ax -= speed * sin(rot)
				sp.ay += speed * cos(rot)
				sp.op -= speed
			if sp.op < 40.0:
				sp.ax = float(_rng.randi() % 1380) - 100.0 + origin.x
				sp.ay = float(_rng.randi() % 920) - 200.0 + origin.y
				sp.op = 160.0 + float(_rng.randi() % 60)
		queue_redraw()

	func _rotation() -> float:
		return PI / 8.0 if _type == "storm" else PI / 16.0

	func _draw() -> void:
		var dim := Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, floorf(_power * 6.0) / 255.0)
		if XScreenFxView.BATCH_WEATHER:
			_draw_batched(dim)
			return
		draw_rect(Rect2(0, 0, 1280, 720), dim)
		if _type == "none":
			return
		var rot := _rotation()
		for sp in _sprites:
			var col := Color(1, 1, 1, clampf(sp.op / 255.0, 0.0, 1.0))
			var pos := Vector2(sp.ax, sp.ay) - _origin
			draw_set_transform(pos, rot, Vector2.ONE)
			match _type:
				"rain":
					draw_rect(Rect2(0, 0, 1, 60), col)
				"storm":
					draw_rect(Rect2(0, 0, 2, 100), col)
				"snow":
					draw_circle(Vector2(4, 4), 4, col)

	## 暗幕和全部粒子拼成一组三角形、一次画完（原先每片雨／雪各设一次变换、各算一次绘制，下雪 70 片＝多 70 次绘制）。
	## 形状、位置、旋转、透明度与逐片画相同：雨／暴风雨是绕左上角旋转的 1×60／2×100 长条，雪是圆心 (4,4) 跟着旋转的半径 4 圆（64 边形，同 draw_circle，逐像素一致）。
	func _draw_batched(dim: Color) -> void:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		_quad(pts, cols, idx, [Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)], dim)
		if _type != "none":
			var rot := _rotation()
			var size := Vector2(1, 60) if _type == "rain" else Vector2(2, 100)
			for sp in _sprites:
				var col := Color(1, 1, 1, clampf(sp.op / 255.0, 0.0, 1.0))
				var pos := Vector2(sp.ax, sp.ay) - _origin
				if _type == "snow":
					var c := pos + Vector2(4, 4).rotated(rot)
					var base := pts.size()
					pts.append(c)
					cols.append(col)
					for k in SNOW_SEGMENTS:
						pts.append(c + _snow_ring[k])
						cols.append(col)
						idx.append_array([base, base + 1 + k, base + 1 + (k + 1) % SNOW_SEGMENTS])
				else:
					_quad(pts, cols, idx, [pos, pos + Vector2(size.x, 0).rotated(rot), pos + size.rotated(rot), pos + Vector2(0, size.y).rotated(rot)], col)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)

	static func _quad(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, corners: Array, col: Color) -> void:
		var base := pts.size()
		for v in corners:
			pts.append(v)
			cols.append(col)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
