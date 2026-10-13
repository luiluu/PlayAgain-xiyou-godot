class_name XDamagePopup
extends Node2D
## 伤害数字，照正式版 LGP_BetterDamagePopup（＋MOG_DmgPopupEffects 位置）运行时逐帧读数：
## - 文字弹出：字号 38、正式版字体；位图宽 = 字宽 + 10、高 38，文字靠左，精灵锚点 (0.5, 1)。
## - 颜色（文字/描边）：HP 伤害 rgb(255,50,50)/(100,0,0)、暴击 (255,128,0)/(100,25,0)、HP 回复 (50,255,50)/(0,100,0)、
##   MP 伤害 (100,150,150)/(0,50,50)、MP 回复 (150,255,255)/(50,100,100)、Miss (168,145,200)/(100,100,100)。
## - 格式：伤害「数字」，回复「治疗  数字」（数字带负号，照原样），暴击「暴击  数字  ！」；
##   ≥1 万显示「x.xx万」，≥1 亿「亿」，再往上 兆/京/垓/秭/穰。
## - 动作（插件每帧更新两次）：总 90 次（45 帧），最后 10 次淡出；伤害数字每次放大 0.1 到 1，
##   敌人 x −0.3、y = 0.2/x² + 5x（向左上），角色 x +0.3、y = −(−0.2/x² + 5x)（向右上）；
##   暴击放大 = clamp(0.2×暴击剩余, 1, 2)（暴击剩余 20 次）；回复在暴击计时走完后才出现，每次上移 0.4；
##   Miss 每次 x −0.5（角色 +0.5）、y = 0.1/x² + 5x。
## - 同一目标已有 n 个弹出时，新的锚点 y 再加 0.9×n（YEP Popup Overlap Rate）。

const FONT_SIZE := 38
const BUFFER := 10.0
const UPDATES := 90
const CRIT_UPDATES := 20
const COLORS := {
	"hp": [Color8(255, 50, 50), Color8(100, 0, 0)],
	"crit": [Color8(255, 128, 0), Color8(100, 25, 0)],
	"hp_heal": [Color8(50, 255, 50), Color8(0, 100, 0)],
	"mp": [Color8(100, 150, 150), Color8(0, 50, 50)],
	"mp_heal": [Color8(150, 255, 255), Color8(50, 100, 100)],
	"miss": [Color8(168, 145, 200), Color8(100, 100, 100)],
}

var text := ""
var kind := "hp"            # hp / crit / hp_heal / mp / mp_heal / miss
var on_actor := false
var stack := 0
var _duration := UPDATES
var _crit := CRIT_UPDATES
var _x := 0.0
var _y := 0.0
var _scale := 0.0
var _alpha := 1.0
var _font: Font


## value > 0 伤害、< 0 回复；text "miss" 只显示 Miss。
func setup(value: float, is_mp := false, critical := false, miss := false, actor_target := false, stacked := 0) -> void:
	_font = XUI.font()
	on_actor = actor_target
	stack = stacked
	if miss:
		kind = "miss"
		text = "Miss"
		_scale = 1.0
		return
	var shown := format_number(value)
	if value < 0:
		kind = "mp_heal" if is_mp else "hp_heal"
		text = "治疗  " + shown
	elif critical and value != 0:
		kind = "crit"
		text = "暴击  " + shown + "  ！"
	else:
		kind = "mp" if is_mp else "hp"
		text = shown
	if value < 0:
		_scale = 0.0


## LGP 的数字缩写（万/亿/兆/京/垓/秭/穰，保留两位小数，去掉多余的 0）
static func format_number(value: float) -> String:
	var units := [[1e8, 1e4, "万"], [1e12, 1e8, "亿"], [1e16, 1e12, "兆"], [1e20, 1e16, "京"], [1e24, 1e20, "垓"], [1e28, 1e24, "秭"]]
	for u in units:
		if value < u[0]:
			if value > u[1]:
				return _trim(roundf(value / u[1] * 100.0) / 100.0) + u[2]
			return str(int(value))
	return _trim(roundf(value / 1e28 * 100.0) / 100.0) + "穰"


static func _trim(v: float) -> String:
	if v == floorf(v):
		return str(int(v))
	return String.num(v, 2).rstrip("0").rstrip(".")


func _physics_process(_delta: float) -> void:
	for i in range(2):
		_update()
	queue_redraw()
	if _duration <= 0:
		queue_free()


func _update() -> void:
	if _duration > 0:
		_duration -= 1
	if _crit > 0:
		_crit -= 1
	var dir := 1.0 if on_actor else -1.0
	match kind:
		"hp", "mp", "crit":
			_scale = minf(1.0, _scale + 0.1)
			_x += 0.3 * dir
			if on_actor:
				_y = -(-0.2 * pow(_x, -2) + 5 * _x)
			else:
				_y = 0.2 * pow(_x, -2) + 5 * _x
			if kind == "crit":
				_scale = clampf(CRIT_UPDATES / 100.0 * _crit, 1.0, 2.0)
		"hp_heal", "mp_heal":
			if _crit == 0:
				_scale = 1.0
				_y -= 0.4
		"miss":
			_x += 0.5 * dir
			if on_actor:
				_y = -(-0.1 * pow(_x, -2) + 5 * _x)
			else:
				_y = 0.1 * pow(_x, -2) + 5 * _x
	if _duration < 10:
		_alpha = _duration / 10.0


func _draw() -> void:
	if _scale <= 0.0 or text == "":
		return
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + BUFFER
	var h := float(FONT_SIZE)
	# 锚点：数字/回复 (0.5, 1 + 0.9×叠加)，Miss (0.5, 0.5)
	var ay := 0.5 if kind == "miss" else 1.0 + 0.9 * stack
	var top_left := Vector2(-w * 0.5, -h * ay)
	var base := FONT_SIZE - (FONT_SIZE - FONT_SIZE * 0.7) / 2.0
	var c: Array = COLORS[kind]
	draw_set_transform(Vector2(_x, _y), 0.0, Vector2(_scale, _scale))
	var pos := top_left + Vector2(0, base)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 1, Color(c[1], _alpha))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(c[0], _alpha))
	draw_set_transform(Vector2.ZERO)
