class_name XTianqiQiyinShow
extends RefCounted
## 【cc·天启篇·未经审查】七印祭坛的演出：掉落、揭开、龙隙（七印祭坛方案 v0.4 第 6.1 节第 6 条、第 3.1 节「演出」）。
## 参数在 tianqi_data/qiyin_show.json（颜色、音效、时长、美术路径）。
##
## - 套装件掉落：画面闪本印的颜色，中间亮起本印的印（S1），专属音效。
## - 毕业武器掉落：全屏压暗定格，印和「毕业武器（类型）」停住一下。
## - 真印：红光（外圈红边）加震屏。
## - 神器：整屏变暗，七道印依次亮起，再亮出神器大图（P1～P5）。
## - 揭开：封着的印碎开（闪本印色），真印再加红光、小震。
## - 龙隙：地面裂开（P6），七道印的光一起灭，震屏。
##
## 美术没到的先由引擎画（色块、圆印、文字），图放进 qiyin_show.json 的 art 路径就自动换上。
## 只在真的地图场景（Node）上画；测试的假宿主不画，只记进 played（测试看）。
## 开关 ENABLED：false＝一概不演，流程照走（文字照出）。

const PATH := "res://modes/xiyou/tianqi_data/qiyin_show.json"
## 盖在地图上、对话框下（ui 是 10 层）
const LAYER := 8

## 开关：false＝不演出
static var ENABLED := true
## 测试看：每次演出记一条 {kind, seal, true_seal, …}
static var played: Array = []

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiQiyinShow: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiQiyinShow: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", data().get("nice_number_exempt", []), out)
	return out


static func _sec(key: String) -> Dictionary:
	var v = data().get(key)
	return v if v is Dictionary else {}


static func seal_color(seal: String) -> Color:
	return Color.html(str(_sec("seals").get(seal, {}).get("color", "#FFFFFF")))


static func seal_accent(seal: String) -> Color:
	return Color.html(str(_sec("seals").get(seal, {}).get("accent", "#FFFFFF")))


static func seal_glyph(seal: String) -> String:
	return str(_sec("seals").get(seal, {}).get("glyph", "?"))


static func seal_order() -> Array:
	return _sec("seals").keys()


## 取过的图留着：_draw 里现取的贴图没人拿着，画完就被释放，这一帧画成白块（七印徽记接入时实测）
static var _art := {}

## 美术到了没有：有图返回贴图，没有返回 null（画占位）
static func art(kind: String, key := "") -> Texture2D:
	var a := _sec("art")
	var path := ""
	match kind:
		"seal":
			path = str(a.get("seal_dir", "")) + key + ".png"
		"artifact":
			path = str(a.get("artifact_dir", "")) + key + ".png"
		"rift":
			path = str(a.get("rift", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _art.has(path):
		_art[path] = load(path) as Texture2D
	return _art[path]


static func _record(kind: String, info: Dictionary) -> void:
	var row := info.duplicate()
	row["kind"] = kind
	played.append(row)


static func _live(host) -> bool:
	return ENABLED and host is Node and (host as Node).is_inside_tree()


# ---- 对外：流程里在出字之前 await 一下 ----

## 一件掉落（封着的；物品字典照 XTianqiQiyinDrop）
static func drop(host, item: Dictionary) -> void:
	var seal := str(item.get("seal", ""))
	var weapon := str(item.get("kind", "")) == XTianqiQiyinDrop.KIND_WEAPON
	var ts := bool(item.get("true_seal", false))
	_record("drop", {"seal": seal, "weapon": weapon, "true_seal": ts})
	if not _live(host):
		return
	var ov := _overlay(host)
	ov.seal = seal  # 原来漏了：中间那枚印一直画成没颜色的白圆（七印徽记接入时截图看到）
	var label := XTianqiQiyin.sealed_label(item)
	if weapon:
		var w := _sec("weapon")
		_se(host, str(w.get("se", "")))
		await _tween(ov, {"dim": float(w.get("dim", 0.66)), "emblem": 1.0}, 0.2)
		ov.label = label
		if ts:
			await _true_seal(host, ov)
		await _wait(host, float(w.get("hold", 1.0)))
	else:
		var st := _sec("set")
		_se(host, str(st.get("se", "")))
		_flash(host, seal_color(seal), float(st.get("flash", 0.5)))
		await _tween(ov, {"emblem": 1.0}, 0.2)
		ov.label = label
		if ts:
			await _true_seal(host, ov)
		await _wait(host, float(st.get("hold", 0.8)))
	await _close(ov)


## 神器掉落：整屏变暗，七道印依次亮起，再亮出神器大图
static func artifact(host, key: String) -> void:
	_record("artifact", {"key": key})
	if not _live(host):
		return
	var a := _sec("artifact")
	var ov := _overlay(host)
	ov.mode = "artifact"
	ov.art_key = key
	ov.picture = art("artifact", key)
	await _tween(ov, {"dim": float(a.get("dim", 0.88))}, 0.33)
	var step := float(a.get("step", 0.33))
	for i in ov.lights.size():
		_se(host, str(a.get("light_se", "")))
		await _tween_light(ov, i, 1.0, step)
	_se(host, str(a.get("se", "")))
	_flash(host, Color(1, 0.9, 0.6), 0.5)
	ov.label = "神器「%s」" % str(XTianqiQiyinGear.artifact(key).get("name", key))
	await _tween(ov, {"emblem": 1.0}, 0.33)
	await _wait(host, float(a.get("hold", 1.5)))
	await _close(ov)


## 揭开一件：封着的印碎开（闪本印色），真印再加红光、小震
static func reveal(host, item: Dictionary) -> void:
	var seal := str(item.get("seal", ""))
	var ts := bool(item.get("true_seal", false))
	_record("reveal", {"seal": seal, "true_seal": ts})
	if not _live(host):
		return
	var r := _sec("reveal")
	var ov := _overlay(host)
	ov.seal = seal
	ov.mode = "reveal"
	await _tween(ov, {"emblem": 1.0}, 0.15)
	_se(host, str(r.get("se", "")))
	_flash(host, seal_color(seal), 0.33)
	await _tween(ov, {"shatter": 1.0}, 0.33)
	if ts:
		await _true_seal(host, ov)
	await _wait(host, float(r.get("hold", 0.5)))
	await _close(ov)


## 龙隙：地面裂开，七道印的光一起灭
static func rift(host) -> void:
	_record("rift", {})
	if not _live(host):
		return
	var r := _sec("rift")
	var ov := _overlay(host)
	ov.mode = "rift"
	ov.picture = art("rift")
	for i in ov.lights.size():
		ov.lights[i] = 1.0
	await _tween(ov, {"dim": 0.33}, 0.2)
	_se(host, str(r.get("se", "")))
	_shake(host, int(r.get("power", 9)), int(r.get("speed", 5)), int(r.get("frames", 60)))
	await _tween(ov, {"crack": 1.0}, 0.66)
	var t := ov.create_tween().set_parallel(true)
	for i in ov.lights.size():
		t.tween_method(func(v): ov.set_light(i, v), 1.0, 0.0, float(r.get("fade_out", 0.8)))
	await t.finished
	await _wait(host, float(r.get("hold", 1.0)))
	await _close(ov)


## 战斗里断一首：报音效（藏头在 XTianqiQiyinArt.update_sprite）
static func dragon_cut_se() -> String:
	return str(_sec("dragon_cut").get("se", ""))


# ---- 内部 ----

static func _true_seal(host, ov) -> void:
	var t := _sec("true_seal")
	_se(host, str(t.get("se", "")))
	_shake(host, int(t.get("power", 6)), int(t.get("speed", 9)), int(t.get("frames", 30)))
	await _tween(ov, {"glow": 1.0}, 0.2)
	await _wait(host, float(t.get("hold", 0.5)))


static func _overlay(host) -> Overlay:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	(host as Node).add_child(layer)
	var ov := Overlay.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ov)
	return ov


static func _close(ov: Overlay) -> void:
	await _tween(ov, {"modulate:a": 0.0}, 0.2)
	ov.get_parent().queue_free()


static func _tween(ov: Overlay, props: Dictionary, time: float) -> void:
	var t := ov.create_tween().set_parallel(true)
	for k in props:
		t.tween_property(ov, NodePath(k), props[k], time)
	await t.finished


static func _tween_light(ov: Overlay, i: int, to: float, time: float) -> void:
	var t := ov.create_tween()
	t.tween_method(func(v): ov.set_light(i, v), ov.lights[i], to, time)
	await t.finished


static func _wait(host, sec: float) -> void:
	await (host as Node).get_tree().create_timer(sec).timeout


static func _se(host, name: String) -> void:
	if name != "" and host.has_method("play_se"):
		host.play_se({"name": name, "volume": 90, "pitch": 100, "pan": 0})


static func _flash(host, c: Color, strength: float) -> void:
	if host.has_method("flash_screen"):
		host.flash_screen([roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0), roundi(strength * 255.0)], 20)


static func _shake(host, power: int, speed: int, frames: int) -> void:
	if host.has_method("shake_screen"):
		host.shake_screen(power, speed, frames)


## 引擎画的占位层：压暗、中间的印（或神器大图）、文字、七道印、裂缝、红光
class Overlay extends Control:
	var mode := "drop"
	var seal := ""
	var art_key := ""
	var picture: Texture2D = null
	var label := "":
		set(v):
			label = v
			queue_redraw()
	var dim := 0.0:
		set(v):
			dim = v
			queue_redraw()
	var emblem := 0.0:
		set(v):
			emblem = v
			queue_redraw()
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	var shatter := 0.0:
		set(v):
			shatter = v
			queue_redraw()
	var crack := 0.0:
		set(v):
			crack = v
			queue_redraw()
	var lights: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var _cracks: Array = []

	func set_light(i: int, v: float) -> void:
		lights[i] = v
		queue_redraw()

	func _ready() -> void:
		# 裂缝的折线固定（不抽战斗、掉落的随机数）
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in 7:
			var pts := [Vector2.ZERO]
			var ang := TAU * k / 7.0 + rng.randf_range(-0.3, 0.3)
			var p := Vector2.ZERO
			for j in 6:
				ang += rng.randf_range(-0.5, 0.5)
				p += Vector2.from_angle(ang) * rng.randf_range(30.0, 70.0)
				pts.append(p)
			_cracks.append(pts)

	func _draw() -> void:
		var sz := size
		var c := sz / 2.0
		if dim > 0.0:
			draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, dim))
		if crack > 0.0:
			_draw_crack(c + Vector2(0, sz.y * 0.18))
		if lights.any(func(v): return v > 0.0):
			_draw_lights(Vector2(c.x, sz.y * 0.2))
		if emblem > 0.0:
			if mode == "artifact":
				_draw_artifact(c)
			else:
				_draw_seal(c, minf(sz.x, sz.y) * 0.16)
		if label != "":
			var font := get_theme_default_font()
			var fs := 26
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var y := c.y + minf(sz.x, sz.y) * 0.26
			draw_rect(Rect2(c.x - w / 2.0 - 16, y - fs - 6, w + 32, fs + 18), Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(c.x - w / 2.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if glow > 0.0:
			var red := Color.html(str(XTianqiQiyinShow.data().get("true_glow", "#E0262B")))
			for i in 6:
				var a := glow * (0.5 - i * 0.08)
				draw_rect(Rect2(Vector2(i * 6, i * 6), sz - Vector2(i * 12, i * 12)), Color(red, a), false, 6.0)

	func _draw_seal(at: Vector2, r: float) -> void:
		var tex := XTianqiQiyinShow.art("seal", seal)
		var s := r * (0.6 + 0.4 * emblem) * (1.0 + shatter * 0.6)
		var a := emblem * (1.0 - shatter)
		if tex != null:
			draw_texture_rect(tex, Rect2(at - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(1, 1, 1, a))
		else:
			draw_circle(at, s, Color(XTianqiQiyinShow.seal_color(seal), a))
			draw_arc(at, s, 0.0, TAU, 48, Color(XTianqiQiyinShow.seal_accent(seal), a), 4.0)
			var font := get_theme_default_font()
			var fs := int(s * 0.9)
			var g := XTianqiQiyinShow.seal_glyph(seal)
			var gw := font.get_string_size(g, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			draw_string(font, at + Vector2(-gw.x / 2.0, fs * 0.35), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(XTianqiQiyinShow.seal_accent(seal), a))
		if shatter > 0.0:
			# 碎片：八块往外飞
			for k in 8:
				var dir := Vector2.from_angle(TAU * k / 8.0)
				var p := at + dir * (r + shatter * r * 1.5)
				draw_circle(p, r * 0.12 * (1.0 - shatter), Color(XTianqiQiyinShow.seal_color(seal), 1.0 - shatter))

	func _draw_lights(at: Vector2) -> void:
		var keys := XTianqiQiyinShow.seal_order()
		var gap := minf(size.x / 8.0, 110.0)
		for i in keys.size():
			var p := at + Vector2((i - (keys.size() - 1) / 2.0) * gap, 0)
			var v: float = lights[i]
			var tex := XTianqiQiyinShow.art("seal", str(keys[i]))
			if tex != null:
				# 七印徽记（S1）：暗着是去色压暗的印，亮起来渐变回原色（清单「暗态用引擎去色」）
				var half := gap * 0.4
				var r := Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0)
				draw_texture_rect(XTianqiQiyinArt.dim(tex), r, false, Color(1, 1, 1, 0.85 * (1.0 - v)))
				draw_texture_rect(tex, r, false, Color(1, 1, 1, v))
				continue
			draw_circle(p, gap * 0.32, Color(0.15, 0.15, 0.15, 0.8))
			if v > 0.0:
				draw_circle(p, gap * 0.32 * (0.7 + 0.3 * v), Color(XTianqiQiyinShow.seal_color(str(keys[i])), v))
				draw_arc(p, gap * 0.36, 0.0, TAU, 32, Color(XTianqiQiyinShow.seal_accent(str(keys[i])), v), 3.0)

	func _draw_artifact(at: Vector2) -> void:
		var r := minf(size.x, size.y) * 0.22
		if picture != null:
			draw_texture_rect(picture, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, emblem))
		else:
			draw_circle(at, r, Color(0.2, 0.16, 0.08, emblem))
			draw_arc(at, r, 0.0, TAU, 64, Color(1.0, 0.82, 0.36, emblem), 6.0)

	func _draw_crack(at: Vector2) -> void:
		if picture != null:
			draw_texture_rect(picture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, crack))
			return
		for pts in _cracks:
			var n := int(ceil(crack * (pts.size() - 1)))
			for j in n:
				draw_line(at + pts[j] * 2.0, at + pts[j + 1] * 2.0, Color(0.9, 0.2, 0.1, 0.9), 5.0 - j * 0.6)
				draw_line(at + pts[j] * 2.0, at + pts[j + 1] * 2.0, Color(0.05, 0, 0, 1.0), 2.0)
