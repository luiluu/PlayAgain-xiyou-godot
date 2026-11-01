class_name XDesignationPlate
extends XMVCanvas
## 【cc·悟空·未经审查】玩家头顶名牌（Star_Designation Sprite_Character.initialize／updateOther，单机分支）：
## 玩家与载具的精灵各挂一张 180×78 画布，anchor (0.5, 1)、在精灵原点上方 offsetY（48）处；字号 16、粗体、黑色描边。
## 画布内：图标 drawIcon(icon, 58, 0)（Star 版 drawIcon 再右移半格 16 → x 74，32×32）、称号名 y 32 行高 22 居中（称号颜色）、
## 开局名字 $gamePlayer.SaveActorName y 54 行高 22 居中（白色）。玩家精灵透明时随精灵隐藏；载具的那张只在玩家坐着它、位置重合时显示。
## installDisplayPreferencesRuntime 另有一张名牌，只在精灵没有 _nameSpriteOL 时画，单机玩家与载具都有，所以不出现。
## 参照为读码（参照引擎里 Sprite 是桩，量不了画面）；常量见下。
const W := 180.0
const H := 78.0
const FONT_SIZE := 16
const ICON_X := 74.0   # drawIcon(…, 58, 0)：Star 版 blt 到 x + pw/2
const TITLE_Y := 32.0
const NAME_Y := 54.0
const LINE := 22.0

var _sig := ""


static func offset_y() -> float:
	return absf(float(str(XDesignation.params().get("offsetY", "48"))))


func _init() -> void:
	super()
	var bold := FontVariation.new()
	bold.base_font = XUI.font()
	bold.variation_embolden = 0.7  # Bitmap.fontBold
	font = bold
	size = Vector2(W, H)
	painter = _paint
	clip_contents = false


## shift：行走图上移 6（物件图 0），名牌跟着精灵画的位置走
func place(shift: float) -> void:
	position = Vector2(-W / 2.0, -shift - offset_y() - H)


func refresh(s: XState) -> void:
	var d := s.designation if s != null else {}
	var sig := "%s|%s|%s|%s" % [s.actor_name if s != null else "", d.get("name", ""), d.get("icon", 0), d.get("color", "")]
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _paint(c: XMVCanvas) -> void:
	var s := XState.current
	if s == null:
		return
	var d := s.designation
	c.icon(int(d.get("icon", 0)), ICON_X, 0.0)
	var col := Color.from_string(str(d.get("color", "#ffffff")), Color.WHITE)
	c.text(str(d.get("name", "")), 0.0, TITLE_Y, W, "center", col, FONT_SIZE, LINE, 1.0, 1.0, Vector2.ZERO, Color.BLACK)
	c.text(s.actor_name, 0.0, NAME_Y, W, "center", Color.WHITE, FONT_SIZE, LINE, 1.0, 1.0, Vector2.ZERO, Color.BLACK)
