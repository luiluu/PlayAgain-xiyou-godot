class_name XSkinDamagePopup
extends RefCounted
## 【cc·天启篇·未经审查】T096 伤害数字按 v0.7 样稿 battle（.dmg）：窄体数字字（XUiSkin.font("num")）、千分位「4,567」、粗描边＋外晕；
## 暴击把「暴击」两个字（标题宋体、拉开字距）写在数字上面，不再是一行「暴击  4567  ！」。只换画法：
## 弹出位置、轨迹、停留和淡出时长、排队、谁先谁后全是 XDamagePopup 原来的（照 LGP_BetterDamagePopup），text 字段也不变（测试、记录照读）。
## 暴击原版是先 2 倍再缩回 1，新画法压成「1.22 倍弹一下再回 1」（同样稿 dmg 关键帧）。
## 只在新皮肤开着时用；ENABLED＝false 回到原版画法（可回退）。

static var ENABLED := true

const FS := 44            # 普通数字
const FS_CRIT := 60       # 暴击数字（样稿 96 是首领特写，实际一场里一屏好几个数字，压到 60）
const FS_LABEL := 20      # 「暴击」「治疗」小字
const FS_MISS := 30
const STROKE := 5
const CRIT_PEAK := 1.22
## 字色／描边：暴击淡金黄（样稿 #ffe08a／#241a00）；普通伤害近白；回复绿；魔法、TP 按资源色；未命中次要灰
const COLORS := {
	"hp": [Color("f0f0ee"), Color("1a0d0d")],
	"crit": [Color("ffe08a"), Color("241a00")],
	"hp_heal": [Color("6fe3a1"), Color("0b2a18")],
	"mp": [Color("bcd6ff"), Color("0b1830")],
	"mp_heal": [Color("bcd6ff"), Color("0b1830")],
	"tp": [Color("46e0b0"), Color("06261c")],
	"tp_heal": [Color("bff3e2"), Color("06261c")],
	"miss": [Color("a8aaaf"), Color("111114")],
}


static func on() -> bool:
	return ENABLED and XUiSkin.on()


## 数字部分（千分位；万以上沿用原版缩写「1.23万」）
static func number_text(value: float) -> String:
	var v := absf(value)
	if v >= 1e4:
		return XDamagePopup.format_number(v)
	return XMenu._group(v)


## 上面的小字和下面的数字：[label, number]
static func parts(p: XDamagePopup) -> Array:
	match p.kind:
		"miss":
			return ["", "未命中"]
		"crit":
			return ["暴击", number_text(p.raw_value)]
		"hp_heal", "mp_heal", "tp_heal":
			return ["", "+" + number_text(p.raw_value)]
		"hp", "mp", "tp":
			return ["", number_text(p.raw_value)]
	return ["", p.text]


## 新画法的倍数：暴击 2→1 压成 1.22→1
static func scale_of(p: XDamagePopup) -> float:
	if p.kind == "crit":
		return 1.0 + (p._scale - 1.0) * (CRIT_PEAK - 1.0)
	return p._scale


static func draw(p: XDamagePopup) -> void:
	var s := scale_of(p)
	if s <= 0.0 or p.text == "":
		return
	var pr := parts(p)
	var label: String = pr[0]
	var num_text: String = pr[1]
	var c: Array = COLORS.get(p.kind, [])
	if c.is_empty():   # 自定义弹字（customPopup）：正文字、伤害近白／回复绿
		c = COLORS["hp_heal"] if p._heal_color else COLORS["hp"]
	var font := XUiSkin.font("title") if p.kind == "miss" or p.kind == "custom" else XUiSkin.font("num")
	var fs := FS_MISS if p.kind == "miss" else (FS_CRIT if p.kind == "crit" else (FS_LABEL + 6 if p.kind == "custom" else FS))
	var a := p._alpha
	p.draw_set_transform(Vector2(p._x, p._y), 0.0, Vector2(s, s))
	# 纵向锚点同原版（anchor_y：叠着的回复往上让一行）；一行高按本字号
	var w := font.get_string_size(num_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := fs * 0.82 - fs * p.anchor_y()
	var pos := Vector2(-w / 2.0, base)
	if p.kind == "crit":   # 外晕
		var g := XUiSkin.glow_texture()
		p.draw_texture_rect(g, Rect2(Vector2(-w / 2.0 - 24, base - fs - 10), Vector2(w + 48, fs + 30)), false, Color(c[0], 0.35 * a))
	p.draw_string_outline(font, pos, num_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, STROKE * 2, Color(c[1], a))
	p.draw_string(font, pos, num_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(c[0], a))
	if label != "":
		var lf := XUiSkin.font("title")
		var spaced := " ".join(label.split(""))   # 样稿 letter-spacing:8px
		var lw := lf.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_LABEL).x
		var lp := Vector2(-lw / 2.0, base - fs * 0.86 - 2.0)
		p.draw_string_outline(lf, lp, spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_LABEL, 4, Color(c[1], a))
		p.draw_string(lf, lp, spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_LABEL, Color(c[0], a))
	p.draw_set_transform(Vector2.ZERO)
