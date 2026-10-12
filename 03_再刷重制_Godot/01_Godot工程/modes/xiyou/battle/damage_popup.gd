class_name XDamagePopup
extends Node2D
## 伤害数字，照原版 MV Sprite_Damage ＋ MOG_DmgPopupEffects（弹跳型、放大效果、持续 90 帧）：
## img/system/Damage.png 每格 宽/10 × 高/8；行 0 HP 伤害、1 HP 回复、2 MP 伤害、3 MP 回复、
## 4 「未击中」、5 「暴击！」、6 「反击！」、7 「反射！」。
## 每位数字从 y=-40 落下弹跳（dy 初值 -i，每帧 +0.5，触底反弹 ×-0.6），并从 2.5 倍缩到 1 倍；
## 第 i 位延迟 5i 帧出现。会心时整体闪红（MV setupCriticalEffect：rgba(255,0,0,160)，60 帧）。

const FRAME := 1.0 / 60.0

var _digits: Array = []     # [{sprite, dy, ry, yf, yf2, zt}]
var _duration := 90
var _flash := 0
var _acc := 0.0


## kind: "hp" / "mp"；value > 0 伤害、< 0 回复。text: "miss" / "counter" / "reflect" 时只显示文字行。
func setup(value: float, kind := "hp", critical := false, text := "") -> void:
	var tex := _tex()
	if tex == null:
		return
	var w := tex.get_width() / 10.0
	var h := tex.get_height() / 8.0
	match text:
		"miss":
			_word(tex, 4, w, h, 0.0)
			return
		"counter":
			_word(tex, 6, w, h, 0.0)
			return
		"reflect":
			_word(tex, 7, w, h, 0.0)
			return
	var s := str(absi(roundi(value)))
	var row := (0 if kind == "hp" else 2) + (1 if value < 0 else 0)
	for i in range(s.length()):
		var sp := _sprite(tex, Rect2(int(s[i]) * w, row * h, w, h))
		sp.position.x = (i - (s.length() - 1) / 2.0) * w
		sp.scale = Vector2.ONE * 2.5
		_digits.append({"sprite": sp, "dy": -float(i), "ry": -40.0, "yf": h / 2.0, "yf2": 0.0, "zt": 5 * i, "zoom": true})
	_duration += s.length() * 2
	if critical:
		_word(tex, 5, w, h, h + 5.0)
		_flash = 60


func _word(tex: Texture2D, row: int, w: float, h: float, yf2: float) -> void:
	var sp := _sprite(tex, Rect2(0, row * h, 10 * w, h))
	sp.position.x = 0
	_digits.append({"sprite": sp, "dy": 0.0, "ry": -40.0, "yf": 0.0, "yf2": yf2, "zt": 0, "zoom": false})


static var _cached: Texture2D
static func _tex() -> Texture2D:
	if _cached == null:
		var p := XDB.img_path("system", "Damage")
		_cached = load(p) if p != "" else null
	return _cached


func _sprite(tex: Texture2D, region: Rect2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.region_enabled = true
	sp.region_rect = region
	sp.centered = true
	sp.modulate.a = 0.0
	add_child(sp)
	return sp


func _process(delta: float) -> void:
	_acc += delta
	while _acc >= FRAME:
		_acc -= FRAME
		_step()
		if _duration <= 0:
			queue_free()
			return


func _step() -> void:
	_duration -= 1
	for d in _digits:
		var sp: Sprite2D = d.sprite
		if d.zt > 0:
			d.zt -= 1
			sp.modulate.a = 0.0
			continue
		sp.modulate.a = minf(1.0, sp.modulate.a + 35.0 / 255.0)
		d.dy += 0.5
		d.ry += d.dy
		if d.ry >= 0.0:
			d.ry = 0.0
			d.dy *= -0.6
		sp.position.y = roundf(d.ry) - d.yf - d.yf2
		if d.zoom and sp.scale.x > 1.0:
			sp.scale = Vector2.ONE * maxf(1.0, sp.scale.x - 0.05)
		if _duration < 10:
			sp.modulate.a = _duration / 10.0
		if _flash > 0:
			var k := _flash / 60.0 * (160.0 / 255.0)
			sp.modulate = Color(1.0, 1.0 - k, 1.0 - k, sp.modulate.a)
	if _flash > 0:
		_flash -= 1
