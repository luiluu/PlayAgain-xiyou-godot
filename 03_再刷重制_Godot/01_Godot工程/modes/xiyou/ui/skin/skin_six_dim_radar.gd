class_name XSkinSixDimRadar
extends Control
## 【cc·T278·未经审查】天启篇六维雷达图共用控件（设定稿 天启篇_角色六维_v0.3定稿 第四节、卡 4；Kyo D234）。
## 纯绘制：六角网底（E～SSS 八档，每两档一圈）＋六维多边形＋顶点标签（维度名＋档位字母）。不读存档、不碰战斗。
## 两种用法（T279 怪物图鉴、战斗内首领详情复用同一接口）：
##   1. 静态：XSkinSixDimRadar.paint(ci, center, radius, six, opts) —— 在任意 CanvasItem 的 draw 回调里直接画；
##      six＝{维度键: 字母}（XTianqiSixDim.of_actor／of_enemy／of_knight／of_battler 的返回；缺的补 C）。
##   2. 节点：var r := XSkinSixDimRadar.new(); r.six = …; r.compact = true; add_child(r)；控件按自身 size 居中画，悬停给六维说明。
## opts（都可省）：compact＝紧凑（顶点标签一行「名 档」）、font／text／dim／line／accent／gold＝换字体与配色（人物图鉴用旧窗口字与色）、
##   fs＝标签字号、highlight＝SS／SSS 档字高光（默认开）。
## 画法只管形状；六维名称与说明字见 DIM_NAMES／DIM_HINTS（玩家可见文字，待小A 审）。
## 只在天启篇开着时才该有人调用它；西游档由调用方不画（本控件本身不判断）。

## 顶点顺序：自正上方起顺时针，同 XTianqiSixDim.DIMS
const DIMS := ["output", "survive", "speed", "wit", "resolve", "support"]
const DIM_NAMES := {"output": "输出", "survive": "生存", "speed": "速度", "wit": "战商", "resolve": "韧性", "support": "辅助"}
## 一句话说明（定稿 1.1 的玩家可见草稿；待小A 审）
const DIM_HINTS := {
	"output": "打人有多疼，只看杀伤与爆发烈度",
	"survive": "有多难被打死：血防、护盾、回血、保命机制",
	"speed": "出手快不快、多不多动、节奏灵不灵活",
	"wit": "战斗头脑好不好使：抓弱点、留大招、补刀",
	"resolve": "扛控制、逆风与残血时稳不稳",
	"support": "顾不顾队友：治疗、护盾、增益、援护",
}
const LETTERS := ["E", "D", "C", "B", "A", "S", "SS", "SSS"]
const RINGS := [2, 4, 6, 8]  # 网底画的档分（D、B、S、SSS）

@export var six: Dictionary = {}
@export var compact := false:
	set(v):
		compact = v
		queue_redraw()
@export var show_resist := false  ## 控件内顺带在下方画一行「控制抗性 +x%」（只给节点用法；静态 paint 不画）
var resist_pct := 0
var opts: Dictionary = {}


func set_six(s: Dictionary, resist := 0) -> void:
	six = s
	resist_pct = resist
	tooltip_text = tip_text(s)
	queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(120, 120)


func _draw() -> void:
	var s := six if not six.is_empty() else _neutral()
	var extra := 22.0 if show_resist else 0.0
	var m := margin(compact)
	var r := minf(size.x / 2.0 - m.x, (size.y - extra) / 2.0 - m.y)
	if r < 10.0:
		return
	var o := opts.duplicate()
	var c := Vector2(size.x / 2.0, (size.y - extra) / 2.0)
	paint(self, c, r, s, o)
	if show_resist:
		var f: Font = o.get("font", XUiSkin.font("body"))
		var t := resist_text(resist_pct)
		var fs := 15
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		XUiSkin.ds(self, f, Vector2((size.x - tw) / 2.0, size.y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, o.get("dim", XUiSkin.TEXT_2))


## 标签占的边距（横、纵），算半径用
static func margin(compact_mode: bool) -> Vector2:
	return Vector2(46, 30) if compact_mode else Vector2(30, 44)


static func _neutral() -> Dictionary:
	var r := {}
	for d in DIMS:
		r[d] = "C"
	return r


static func score(letter: String) -> int:
	var i := LETTERS.find(letter)
	return i + 1 if i >= 0 else 3


## 「控制抗性 +7%」；C 档「控制抗性 0%」
static func resist_text(pct: int) -> String:
	return "控制抗性 %s%d%%" % ["+" if pct > 0 else "", pct]


## 悬停说明：六行「名 档　一句话」
static func tip_text(s: Dictionary) -> String:
	var lines := []
	for d in DIMS:
		lines.append("%s %s　%s" % [DIM_NAMES[d], str(s.get(d, "C")), DIM_HINTS[d]])
	return "\n".join(lines)


## 顶点方向（单位向量）：第 i 维，自正上方起顺时针
static func dir(i: int) -> Vector2:
	var a := -PI / 2.0 + TAU * i / 6.0
	return Vector2(cos(a), sin(a))


## 六个多边形顶点（供测试与别处复用）：半径 r × 档分 / 8
static func points(center: Vector2, r: float, s: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(center + dir(i) * r * float(score(str(s.get(DIMS[i], "C")))) / 8.0)
	return pts


static func paint(ci: CanvasItem, center: Vector2, r: float, s: Dictionary, o := {}) -> void:
	var font: Font = o.get("font", XUiSkin.font("body"))
	var txt: Color = o.get("text", XUiSkin.TEXT)
	var dim: Color = o.get("dim", XUiSkin.TEXT_2)
	var line: Color = o.get("line", XUiSkin.line_c())
	var accent: Color = o.get("accent", Color("c8503c"))
	var gold: Color = o.get("gold", XUiSkin.GOLD)
	var compact_mode: bool = o.get("compact", false)
	var hi: bool = o.get("highlight", true)
	var fs: int = int(o.get("fs", 13 if compact_mode else 14))
	# 网底：四圈六边形＋六根轴
	for k in RINGS:
		var ring := PackedVector2Array()
		for i in 6:
			ring.append(center + dir(i) * r * float(k) / 8.0)
		ring.append(ring[0])
		ci.draw_polyline(ring, Color(line, 0.55 if k == 8 else 0.26), 1.0, true)
	for i in 6:
		ci.draw_line(center, center + dir(i) * r, Color(line, 0.22), 1.0, true)
	# 数据多边形
	var pts := points(center, r, s)
	ci.draw_colored_polygon(pts, Color(accent, 0.30))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(accent, 0.95), 2.0, true)
	for p in pts:
		ci.draw_circle(p, 2.5, Color(gold, 0.95))
	# 顶点标签
	for i in 6:
		var d: String = DIMS[i]
		var letter := str(s.get(d, "C"))
		var special := hi and (letter == "SS" or letter == "SSS")
		var lc := gold if special else txt
		var v := dir(i)
		var anchor := center + v * (r + 8.0)
		if compact_mode:
			var name_s: String = DIM_NAMES[d]
			var nw := font.get_string_size(name_s + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2).x
			var tw := nw + lw
			var x := anchor.x - tw / 2.0 + v.x * tw / 2.0
			var y := anchor.y + fs * 0.36 + v.y * (fs * 0.7)
			XUiSkin.ds(ci, font, Vector2(x, y), name_s + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
			XUiSkin.ds(ci, font, Vector2(x + nw, y), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, lc)
		else:
			# 两行：名字（小、次要色）在内侧、档位（大）在外侧；上顶点档位在上，下顶点档位在下，左右顶点两行贴边
			var name_s2: String = DIM_NAMES[d]
			var nw2 := font.get_string_size(name_s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var big := fs + 6
			var lw2 := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
			var bw := maxf(nw2, lw2)
			var cx := anchor.x + v.x * bw / 2.0
			var cy := anchor.y + v.y * (big + fs) * 0.5
			var top := cy - (big + fs) * 0.5
			XUiSkin.ds(ci, font, Vector2(cx - nw2 / 2.0, top + fs * 0.86), name_s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
			XUiSkin.ds(ci, font, Vector2(cx - lw2 / 2.0, top + fs + big * 0.82), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, big, lc)
