class_name XSkinEnemyHp
extends RefCounted
## 【cc·天启篇】T126 小怪血条（Kyo 2026-11-17「首领血条就用糖果粉，小怪血条也按这个风格做一个」）：
## 首领血弧（XSkinBossArc）同色系的细胶囊条：底槽黑 65%、糖果粉渐变（左浅 ffc0dc → 右深 ff5c9e）、扣血先留橙色拖尾再缩（拖尾跟原版
## YEP_X_VisualHpGauge 的显示值 disp 走，30 帧追上）。不写数字，活着一直显示（原版小血条只在挨打／被选中时闪一下）。
## 首领（顶上有血弧的、XBossHpBar.is_meter）与 <HIDE HP GAUGE> 的敌人不画。
## 样式（STYLE）：FEET 脚下，名字正下方；HEAD 头顶，离身体顶 10。
## 回退：ENABLED＝false 回到原版小血条（挨打时 12px 粗条＋数字）。

static var ENABLED := true
enum Style { FEET, HEAD }
static var STYLE := Style.FEET

const HP_LIGHT := Color("ffc0dc")
const HP_DEEP := Color("ff5c9e")
const H := 6.0            # 条高（1280×720 画面）
const W_MIN := 72.0
const W_MAX := 120.0
const FEET_Y := 40.0      # 脚下样式：条顶离名字框顶（名字 18 号字占 0～36）
const HEAD_GAP := 10.0


static func on() -> bool:
	return ENABLED and XUiSkin.on()


## 条宽：身体宽的六成，夹在 72～120
static func bar_width(sprite_w: float) -> float:
	return clampf(roundf(sprite_w * 0.6), W_MIN, W_MAX)


## 条顶 y（画布坐标；画布原点在脚底上方 27，见 XBattleScene.update_gauges）
static func bar_top(sprite_h: float) -> float:
	if STYLE == Style.HEAD:
		return 27.0 - sprite_h - HEAD_GAP - H
	return FEET_Y


## rate＝当前血量比例，trail＝显示值（拖尾）比例；cx＝条中心 x
static func paint(c: CanvasItem, cx: float, top: float, w: float, rate: float, trail: float, alpha := 1.0) -> void:
	if alpha <= 0.0:
		return
	var x := roundf(cx - w / 2.0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.65 * alpha)
	track.set_corner_radius_all(int(H / 2.0) + 1)
	track.border_color = Color(1, 1, 1, 0.10 * alpha)
	track.set_border_width_all(1)
	c.draw_style_box(track, Rect2(x - 1.0, top - 1.0, w + 2.0, H + 2.0))
	rate = clampf(rate, 0.0, 1.0)
	trail = clampf(trail, 0.0, 1.0)
	if trail > rate:  # 扣血残影：橙
		var tb := StyleBoxFlat.new()
		tb.bg_color = Color(XUiSkin.DOWN, alpha)
		tb.set_corner_radius_all(int(H / 2.0))
		c.draw_style_box(tb, Rect2(x, top, maxf(H, w * trail), H))
	if rate <= 0.0:
		return
	var fw := maxf(H, roundf(w * rate))
	# 外发光一层（同血弧的 0.30 光晕，细条上收成 2px）
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(XUiSkin.HP, 0.25 * alpha)
	glow.set_corner_radius_all(int(H / 2.0) + 2)
	c.draw_style_box(glow, Rect2(x - 1.0, top - 1.0, fw + 2.0, H + 2.0))
	# 左浅右深：分段画（胶囊两头用圆角盒，中间按段渐变）
	var segs := 8
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var sx := x + w * t0
		var ex := minf(x + w * t1, x + fw)
		if ex <= sx:
			break
		var col := Color(HP_LIGHT.lerp(HP_DEEP, (t0 + t1) / 2.0), alpha)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		var r := int(H / 2.0)
		sb.corner_radius_top_left = r if i == 0 else 0
		sb.corner_radius_bottom_left = r if i == 0 else 0
		var last := ex >= x + fw - 0.01
		sb.corner_radius_top_right = r if last else 0
		sb.corner_radius_bottom_right = r if last else 0
		c.draw_style_box(sb, Rect2(sx, top, ex - sx, H))
	# 顶上一道高光
	c.draw_rect(Rect2(x + 2.0, top + 1.0, maxf(0.0, fw - 4.0), 1.0), Color(1, 1, 1, 0.35 * alpha))
