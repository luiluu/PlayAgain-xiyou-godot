class_name XPowerStrip
extends XMVCanvas
## 状态页战力条（installCombatPowerRuntime Scene_Status.create／refreshCombatPowerSummary，正式 v0.28 运行时读数）：
## - 不在窗口里：独立精灵 (24, 第一页窗口原 y, 画面宽−48, 36)，各页窗口下移 36、高减 36；关掉「战力显示与估算」时不建、不下移。
##   正式版选页窗 (0,0,1280,64)、页窗原 y 72 → 战力条 (24,72,1232,36)、页窗 (0,108,1280,612)。
## - 底色 rgba(12,25,35,0.45) 铺满；「战力：N」(12, 宽 300) 23 号 rgb(255,211,115)；
##   「人物属性：火焰／水」(325, 宽 220) 18 号 rgb(180,201,220)、元素名用元素色，总宽超过 220 时按比例缩小字号（CodexElements.drawAttributes）；
##   「自身 N  ·  装备战力 N」(550, 宽 条宽−565) 18 号 rgb(180,201,220)；装备战力是身上各件装备评分之和（gearScore）。
## - O-031：自身与装备战力之间加「装备提升 +N」（总战力−自身，= 正式版 gear），三个数能对上总战力；SHOW_GEAR_GAIN 关掉即恢复原版。
## - 右端 300 宽的真气段（installNativeGuidanceRuntime refreshCombatPowerSummary）：先清再铺底色 rgba(12,25,35,0.45)，
##   「真气·境界 ×加成（待选／瓶颈）」18 号右对齐（宽 288），瓶颈或待选 rgb(255,170,120)，否则 rgb(150,220,255)（XGuide.strip_text）。
##   原版这一段会擦掉第三段文字的右端；O-046 把第三段限宽到真气段左边（SHOW_ZHENQI_CLEAR 设 false 回到原版宽度）。
## - 数值都取 XPower.actor（与正式版一致，dev.046）。

const HEIGHT := 36.0
const SIDE := 24.0
const BACK := Color(12 / 255.0, 25 / 255.0, 35 / 255.0, 0.45)
const GOLD := Color8(255, 211, 115)
const INK := Color8(180, 201, 220)
const TOTAL_SIZE := 23
const DETAIL_SIZE := 18
const ATTR_X := 325.0
const ATTR_W := 220.0
const DETAIL_X := 550.0
## O-031（优化登记）：false 恢复原版「自身 N  ·  装备战力 N」
const SHOW_GEAR_GAIN := true
const ZHENQI_W := 300.0
const ZHENQI_SIZE := 18
const ZHENQI_WARN := Color8(255, 170, 120)
const ZHENQI_INK := Color8(150, 220, 255)
## O-046：第三段限宽到真气段左边，不被真气段截掉；false 照原版宽度（右端被擦掉）
static var SHOW_ZHENQI_CLEAR := true
## CodexElements 元素色（installDamageElementRuntime colors，下标即元素 ID）
const ELEMENT_COLORS := XHelpCard.ELEMENT_COLORS

var actor: XActor


## 状态页用：开着战力时在 rect 位置建条并返回，关掉时返回 null（调用方不下移页窗）
static func make(parent: Control, a: XActor, y: float, width: float) -> XPowerStrip:
	if not XPower.enabled():
		return null
	var s := XPowerStrip.new()
	s.actor = a
	s.position = Vector2(SIDE, y)
	s.size = Vector2(width - SIDE * 2, HEIGHT)
	s.painter = s._paint
	parent.add_child(s)
	return s


## 第三段文字（测试核对用）
static func detail_text(p: Dictionary) -> String:
	var gain := "  ·  装备提升 " + XPowerNotice.delta(float(p.get("gear", 0))) if SHOW_GEAR_GAIN else ""
	return "自身 " + XPower.format(float(p.get("self", 0))) + gain + "  ·  装备战力 " + XPower.format(float(p.get("gearScore", 0)))


## [[文字, 颜色], …]：「人物属性：」＋元素名（用「／」隔开，最多两个），没有元素写「无属性」
static func attribute_parts(a: XActor) -> Array:
	var names: Array = XDamage.elements_data().get("names", [])
	var parts := [["人物属性：", INK]]
	var ids := XDamage.affinity(a)
	if ids.is_empty():
		parts.append(["无属性", Color(ELEMENT_COLORS[0])])
	for i in range(ids.size()):
		if i > 0:
			parts.append(["／", INK])
		var e: int = ids[i]
		parts.append([str(names[e]) if e < names.size() else "无属性", Color(ELEMENT_COLORS[e] if e < ELEMENT_COLORS.size() else ELEMENT_COLORS[0])])
	return parts


func _paint(c: XMVCanvas) -> void:
	if actor == null:
		return
	c.draw_rect(Rect2(Vector2.ZERO, size), BACK)
	for d in layout():
		c.text(d[0], d[1], 0, d[2], d[6], d[5], d[4], d[3])


## 各段 drawText [文字, x, 最大宽, 行高, 字号, 颜色, 对齐]（测试与正式版读数比对用）
func layout() -> Array:
	var p := XPower.actor(actor)
	var out := [["战力：" + XPower.format(float(p.total)), 12.0, 300.0, HEIGHT, TOTAL_SIZE, GOLD, "left"]]
	# CodexElements.drawAttributes：逐段接着画，每段宽 = 字宽 + 1；总宽超过 220 时字号 × 220/总宽（Godot 字号取整）
	var parts := attribute_parts(actor)
	var total := 0.0
	for part in parts:
		total += text_width(part[0], DETAIL_SIZE)
	var fs := DETAIL_SIZE if total <= ATTR_W else int(roundf(DETAIL_SIZE * ATTR_W / total))
	var x := ATTR_X
	for part in parts:
		var w := text_width(part[0], fs)
		out.append([part[0], x, w + 1, HEIGHT, fs, part[1], "left"])
		x += w
	out.append([detail_text(p), DETAIL_X, (size.x - ZHENQI_W - DETAIL_X) if SHOW_ZHENQI_CLEAR else size.x - 565, HEIGHT, DETAIL_SIZE, INK, "left"])
	var zq := XGuide.strip_text(XState.current, actor)
	out.append([zq[0], size.x - ZHENQI_W, ZHENQI_W - 12, HEIGHT, ZHENQI_SIZE, ZHENQI_WARN if zq[1] else ZHENQI_INK, "right"])
	return out
