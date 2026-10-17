class_name MVAnimation
extends Node2D
## 播放 MV 动画（Animations.json），按 Sprite_Animation 原样逐帧：
## - 每帧若干格子 [图案, x, y, 缩放%, 旋转, 翻转, 不透明度, 混合]，图案 <100 取 animation1 图，>=100 取 animation2 图；
##   每格 192×192、每行 5 格。动画图按 animation1Hue/animation2Hue 转色相（Bitmap.rotateHue，见 HUE_SHADER）。
## - _duration = 帧数 × rate + 1；每次 advance：_delay 先倒数，否则 _duration−1、updatePosition，
##   _duration 是 rate 的倍数且 >0 时换帧（currentFrameIndex）并处理该帧时间点；然后 updateFlash、updateScreenFlash、updateHiding。
## - 时间点 flashScope：1 目标闪光（target.set_anim_blend，每帧不透明度 ×(d−1)/d）、2 屏幕闪光（子节点，画满整个画面、
##   盖住它之前画的东西，同样衰减）、3 隐藏目标（target.set_anim_hidden，到时显示）。持续 = flashDuration × rate。
## - 播完（_duration 到 0）的下一帧才移除（Sprite_Base.updateAnimationSprites），移除时还原目标的混合色与显示，再发 done。
## - position：0 头上 1 中心 2 脚下 3 画面中央；坐标由调用方给出，或给 follow（每帧取目标位置，updatePosition）。
## - rate：战斗按 ConfigManager.battleAniSpeed；地图保持 4。正式版首次载入动画图要等几帧（异步加载），这里图已预载，不复现。

signal done

const CELL := 192

## Bitmap.rotateHue 逐像素：RGB→HSL、色相加 hue、再转回，写回 Uint8ClampedArray（四舍五入到偶数）。
## 正式版在载入时改图，这里在取样后改；格子缩放时边缘插值次序不同，差别只在半透明边缘。
const HUE_SHADER := """
shader_type canvas_item;
render_mode %s;
uniform float hue;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 p = floor(t.rgb * 255.0 + 0.5);
	float cmin = min(p.r, min(p.g, p.b));
	float cmax = max(p.r, max(p.g, p.b));
	float h = 0.0;
	float s = 0.0;
	float l = (cmin + cmax) / 2.0;
	float d = cmax - cmin;
	if (d > 0.0) {
		if (p.r == cmax) { h = 60.0 * mod((p.g - p.b) / d + 6.0, 6.0); }
		else if (p.g == cmax) { h = 60.0 * ((p.b - p.r) / d + 2.0); }
		else { h = 60.0 * ((p.r - p.g) / d + 4.0); }
		s = d / (255.0 - abs(2.0 * l - 255.0));
	}
	h = mod(h + hue, 360.0);
	float c = (255.0 - abs(2.0 * l - 255.0)) * s;
	float x = c * (1.0 - abs(mod(h / 60.0, 2.0) - 1.0));
	float m = l - c / 2.0;
	float cm = c + m;
	float xm = x + m;
	vec3 o;
	if (h < 60.0) { o = vec3(cm, xm, m); }
	else if (h < 120.0) { o = vec3(xm, cm, m); }
	else if (h < 180.0) { o = vec3(m, cm, xm); }
	else if (h < 240.0) { o = vec3(m, xm, cm); }
	else if (h < 300.0) { o = vec3(xm, m, cm); }
	else { o = vec3(cm, m, xm); }
	COLOR = vec4(clamp(roundEven(o), 0.0, 255.0) / 255.0, t.a) * tint;
}
"""

static var _hue_shaders := {}
static var _materials := {}

var anim: Dictionary
var sheets: Array = [null, null]
var frame := 0
var rate := 4
var duration := 0
var wait := 0                  # Sprite_Animation._delay
## 目标（Sprite_Animation._target）：有 set_anim_blend(Color)、set_anim_hidden(bool) 时才做目标闪光与隐藏
var target: Object
## updatePosition：每帧取目标坐标（本节点父节点里的坐标）；空则保持给定位置
var follow := Callable()
var flash_color := Color(0, 0, 0, 0)
var flash_duration := 0
var screen_color := Color(0, 0, 0, 0)
var screen_duration := 0
var hiding_duration := 0
var flash: Node2D               # 屏幕闪光（ScreenSprite）
var _sprites: Array[Sprite2D] = []
var se_player: AudioStreamPlayer


static func play(parent: Node, anim_id: int, at: Vector2, mirror := false, frame_rate := 4) -> MVAnimation:
	var a := XDB.rec("Animations", anim_id)
	if not usable(a):
		return null
	var n := MVAnimation.new()
	n.anim = a
	n.position = at
	n.scale.x = -1.0 if mirror else 1.0
	n.rate = clampi(frame_rate, 1, 4)
	parent.add_child(n)
	return n


## MV 格式的动画才播：Animations.json 里另有 132 条 MZ 格式（Effekseer，没有 frames/timings），
## 技能、物品、武器都没用到，这里不支持
static func usable(a: Dictionary) -> bool:
	return a.has("frames") and a.has("timings")


## 转色相（hue≠0）或加法混合的格子材质；同一组合共用
static func cell_material(hue: int, add: bool) -> Material:
	hue = ((hue % 360) + 360) % 360
	if hue == 0 and not add:
		return null
	var key := "%d:%s" % [hue, add]
	if not _materials.has(key):
		if hue == 0:
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_materials[key] = cm
		else:
			var mode := "blend_add" if add else "blend_mix"
			if not _hue_shaders.has(mode):
				var sh := Shader.new()
				sh.code = HUE_SHADER % mode
				_hue_shaders[mode] = sh
			var m := ShaderMaterial.new()
			m.shader = _hue_shaders[mode]
			m.set_shader_parameter("hue", float(hue))
			_materials[key] = m
	return _materials[key]


func _ready() -> void:
	for i in range(2):
		var name := str(anim.get("animation%dName" % (i + 1), ""))
		var p := XDB.img_path("animations", name) if name != "" else ""
		sheets[i] = load(p) if p != "" else null
	se_player = AudioStreamPlayer.new()
	XAudio.bind(se_player, "SE")
	add_child(se_player)
	duration = anim.frames.size() * rate + 1
	flash = Node2D.new()
	flash.visible = false
	flash.draw.connect(_draw_flash)
	add_child(flash)


## 自己跑时：播完的下一帧移除，否则推进一帧
func _physics_process(_delta: float) -> void:
	if not playing():
		finish()
		return
	advance()


func playing() -> bool:
	return duration > 0


## Sprite_Animation.currentFrameIndex
func frame_index() -> int:
	return anim.frames.size() - floori(float(duration + rate - 1) / rate)


## Sprite_Animation.update：updateMain、updateFlash、updateScreenFlash、updateHiding
func advance() -> void:
	if duration > 0:
		if wait > 0:
			wait -= 1
		else:
			duration -= 1
			if follow.is_valid():
				position = follow.call()
			if duration % rate == 0 and duration > 0:
				frame = frame_index()
				_show_frame()
	if flash_duration > 0:
		var d := flash_duration
		flash_duration -= 1
		flash_color.a *= float(d - 1) / d
		_target_call("set_anim_blend", flash_color)
	if screen_duration > 0:
		var d := screen_duration
		screen_duration -= 1
		screen_color.a *= float(d - 1) / d
		flash.visible = screen_duration > 0
		flash.queue_redraw()
	if hiding_duration > 0:
		hiding_duration -= 1
		if hiding_duration == 0:
			_target_call("set_anim_hidden", false)


## Sprite_Animation.remove：还原目标，移除，发 done
func finish() -> void:
	_target_call("set_anim_blend", Color(0, 0, 0, 0))
	_target_call("set_anim_hidden", false)
	done.emit()
	var parent := get_parent()
	if parent:
		# AudioManager.playSe 不随动画移除而停：还在响的音效交给父节点播完
		for player in get_children().filter(func(n): return n is AudioStreamPlayer):
			if player.playing:
				player.reparent(parent)
				player.finished.connect(player.queue_free)
		parent.remove_child(self)
	queue_free()


func _target_call(method: String, arg) -> void:
	if target != null and is_instance_valid(target) and target.has_method(method):
		target.call(method, arg)


func _show_frame() -> void:
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
		var hue := int(anim.get("animation1Hue" if pattern < 100 else "animation2Hue", 0))
		s.material = cell_material(hue, c.size() > 7 and int(c[7]) == 1)
	if flash.get_index() != get_child_count() - 1:
		move_child(flash, -1)     # 屏幕闪光在格子之后（盖住本动画的格子）
	for t in anim.get("timings", []):
		if int(t.frame) == frame:
			_timing(t)


## Sprite_Animation.processTimingData
func _timing(t: Dictionary) -> void:
	var span := int(t.get("flashDuration", 0)) * rate
	var fc: Array = t.get("flashColor", [0, 0, 0, 0])
	var col := Color(fc[0] / 255.0, fc[1] / 255.0, fc[2] / 255.0, fc[3] / 255.0)
	match int(t.get("flashScope", 0)):
		1:
			flash_color = col
			flash_duration = span
		2:
			screen_color = col
			screen_duration = span
		3:
			hiding_duration = span
			_target_call("set_anim_hidden", true)
	var se = t.get("se")
	if se is Dictionary and str(se.get("name", "")) != "":
		var p := XDB.audio_path("se", str(se.name))
		if p != "":
			# AudioManager.playSe 为每次请求新建 buffer；同动画的后一个音效不能截断前一个。
			if se_player.playing:
				se_player = AudioStreamPlayer.new()
				XAudio.bind(se_player, "SE")
				add_child(se_player)
			se_player.stream = load(p)
			se_player.volume_db = linear_to_db(float(se.get("volume", 90)) / 100.0)
			se_player.pitch_scale = float(se.get("pitch", 100)) / 100.0
			se_player.play()


## ScreenSprite：画面 (−5W, −5H) 起 10 倍画面大小的纯色矩形，跟着画面原点（不随动画镜像/镜头）
func _draw_flash() -> void:
	var box := flash.get_viewport_rect().size
	flash.draw_set_transform_matrix(flash.get_global_transform_with_canvas().affine_inverse())
	flash.draw_rect(Rect2(-box * 5.0, box * 10.0), screen_color)


func flash_opacity() -> float:
	return screen_color.a * 255.0
