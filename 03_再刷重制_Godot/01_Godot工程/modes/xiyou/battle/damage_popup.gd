class_name XDamagePopup
extends Node2D
## 伤害数字，照正式版 LGP_BetterDamagePopup（＋MOG_DmgPopupEffects 位置）运行时逐帧读数：
## - 文字弹出：字号 38、正式版字体；位图宽 = 字宽 + 10、高 38，文字靠左（原版量宽时其实按 28 号，字被横向压窄，见 WIDE_TEXT）。
## - 颜色（文字/描边）：HP 伤害 rgb(255,50,50)/(100,0,0)、暴击 (255,128,0)/(100,25,0)、HP 回复 (50,255,50)/(0,100,0)、
##   MP 伤害 (100,150,150)/(0,50,50)、MP 回复 (150,255,255)/(50,100,100)、Miss (168,145,200)/(100,100,100)。
## - 格式：伤害「数字」，回复「治疗  数字」（数字带负号，照原样），暴击「暴击  数字  ！」；
##   ≥1 万显示「x.xx万」，≥1 亿「亿」，再往上 兆/京/垓/秭/穰。
## - 动作（插件每帧更新两次）：总 90 次（45 帧），最后 10 次淡出；伤害数字每次放大 0.1 到 1，
##   敌人 x −0.3、y = 0.2/x² + 5x（向左上），角色 x +0.3、y = −(−0.2/x² + 5x)（向右上）；
##   暴击放大 = clamp(0.2×暴击剩余, 1, 2)（暴击剩余 20 次）；回复在暴击计时走完后才出现，每次上移 0.4；
##   Miss 每次 x −0.5（角色 +0.5）、y = 0.1/x² + 5x。
## - 锚点 (0.5, y)：drawDefaultNumber 先设 y = 1，再加「该目标此刻存活的回复弹数（含自己）− 1」，所以普通伤害无回复时 y = 0
##   （数字顶在根点）、回复 y = 1；YEP Popup Overlap Rate 0.9 加在 setup 时还没有子精灵的新弹数上，实际不起作用
##   （原版读数 tests/fixtures/popup_anchor_oracle.json，七种普通伤害／回复叠加 × 敌人／角色）。Miss 为 (0.5, 0.5)。

## 原版缺陷，修好（O-252，八戒 rules-battle-pixel 截图对照）：LGP getTextWidth 把字号写进 bitmap._fontSize（Bitmap 认的是 fontSize），
## 量宽时仍按默认 28 号，位图宽＝28 号字宽＋10；再用 38 号 drawText(…, 0, 0, 位图宽) 画，canvas 按 maxWidth 把整串字横向压到约 74%
## （原版读数：「1.23万」38 号宽 117.4、位图宽 96）。WIDE_TEXT = true 不压（重制一直是这样画的，现在登记成修好）；
## false 照原版：位图宽按 28 号量，字横向压进去。
static var WIDE_TEXT := true
const MEASURE_SIZE := 28
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
	"tp": [Color8(150, 150, 100), Color8(50, 50, 0)],
	"tp_heal": [Color8(255, 255, 150), Color8(100, 100, 50)],
	"miss": [Color8(168, 145, 200), Color8(100, 100, 100)],
	"custom": [Color8(255, 50, 50), Color8(100, 0, 0)],
}

var text := ""
var kind := "hp"            # hp / crit / hp_heal / mp / mp_heal / miss
var on_actor := false
var stack := 0             # 同一目标此前仍存活的回复弹数
var _duration := UPDATES
var _crit := CRIT_UPDATES
var _x := 0.0
var _y := 0.0
var _scale := 0.0
var _alpha := 1.0
var _font: Font


## value > 0 伤害、< 0 回复；text "miss" 只显示 Miss。
func setup(value: float, is_mp := false, critical := false, miss := false, actor_target := false, stacked := 0, is_tp := false) -> void:
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
		kind = "tp_heal" if is_tp else "mp_heal" if is_mp else "hp_heal"
		text = "治疗  " + shown
	elif critical and value != 0:
		kind = "crit"
		text = "暴击  " + shown + "  ！"
	else:
		kind = "tp" if is_tp else "mp" if is_mp else "hp"
		text = shown
	if value < 0:
		_scale = 0.0


## 状态行（结果里有附加／解除状态）：原版 drawDefaultState 的绘制整段注释掉了，只剩空精灵——画面上什么都没有，
## 但这个 Sprite_Damage 照样占弹数队列的一帧、存活 90 次（每次上移 0.5），所以要建出来（不画）
func setup_state() -> void:
	kind = "state"


## customPopup：drawCustomText 锚点 (0.5, 0.5)、格式 2 伤害色／1 回复色；默认移动码不动它，最后 10 次整体淡出
func setup_custom(value: String, format: int) -> void:
	_font = XUI.font()
	kind = "custom"
	text = value
	_scale = 1.0
	if format == 1:
		_heal_color = true


var _heal_color := false  # customPopup 格式 1


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


## 原版每帧更新两次：先 Sprite_Battler.updateDamagePopup 逐个一次（第 0 次），再 Spriteset_Battle 的 children 一次（第 1 次）；
## 新建当帧只有第 0 次（建出时 _spawn_popup 直接调一次 _update）。update 开头若已走完（_duration ≤ 0 且不透明度 ≤ 0）
## 就 remove（从 Spriteset 的 children 里摘掉）：摘在第 1 次（children 的 forEach 里）时数组前移，紧跟其后加入的那个
## 弹数（不论哪个战斗者）这一帧的第 1 次被跳过——正式版读数 s2800、s3772 里紧跟其后的弹数只走 1 次。
var skip := 0
var on_removed := Callable()   # 第 1 次里被摘掉时调，参数为自己：由战斗画面给下一个弹数记 skip


func _physics_process(_delta: float) -> void:
	var n := 2 - skip
	skip = 0
	for i in range(n):
		if _duration <= 0 and _alpha <= 0.0:
			if i == 1 and on_removed.is_valid():
				on_removed.call(self)
			queue_free()
			return
		_update()
	queue_redraw()


func _update() -> void:
	if _duration > 0:
		_duration -= 1
	if _crit > 0:
		_crit -= 1
	var dir := 1.0 if on_actor else -1.0
	match kind:
		"hp", "mp", "tp", "crit":
			_scale = minf(1.0, _scale + 0.1)
			_x += 0.3 * dir
			if on_actor:
				_y = -(-0.2 * pow(_x, -2) + 5 * _x)
			else:
				_y = 0.2 * pow(_x, -2) + 5 * _x
			if kind == "crit":
				_scale = clampf(CRIT_UPDATES / 100.0 * _crit, 1.0, 2.0)
		"hp_heal", "mp_heal", "tp_heal":
			if _crit == 0:
				_scale = 1.0
				_y -= 0.4
		"state":
			_y -= 0.5
		"miss":
			_x += 0.5 * dir
			if on_actor:
				_y = -(-0.1 * pow(_x, -2) + 5 * _x)
			else:
				_y = 0.1 * pow(_x, -2) + 5 * _x
	if _duration < 10:
		_alpha = _duration / 10.0


## 位图宽（LGP：getTextWidth＋缓冲 10）：修好时按 38 号量，原版按 28 号量
func bitmap_width() -> float:
	if _font == null:
		_font = XUI.font()
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE if WIDE_TEXT else MEASURE_SIZE).x + BUFFER


## 横向压缩比：drawText 的 maxWidth＝位图宽，38 号字比它宽时 canvas 整串压窄（修好时恒 1）
func squeeze() -> float:
	if WIDE_TEXT:
		return 1.0
	var full := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	return minf(1.0, bitmap_width() / maxf(full, 1.0))


func is_heal() -> bool:
	return kind.ends_with("_heal")


## 文字精灵的纵向锚点（见文件头）
func anchor_y() -> float:
	return 0.5 if kind in ["miss", "custom"] else float(stack + (1 if is_heal() else 0))


func _draw() -> void:
	if _scale <= 0.0 or text == "":
		return
	var bw := bitmap_width()
	var sx := squeeze()
	var h := float(FONT_SIZE)
	var ay := anchor_y()
	var base := FONT_SIZE - (FONT_SIZE - FONT_SIZE * 0.7) / 2.0
	var c: Array = COLORS["hp_heal"] if kind == "custom" and _heal_color else COLORS[kind]
	draw_set_transform(Vector2(_x, _y), 0.0, Vector2(_scale * sx, _scale))
	# 位图左边在 −宽/2（锚点 0.5）；横向压缩时文字坐标要除回去
	var pos := Vector2(-bw * 0.5 / sx, -h * ay + base)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 1, Color(c[1], _alpha))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(c[0], _alpha))
	draw_set_transform(Vector2.ZERO)
