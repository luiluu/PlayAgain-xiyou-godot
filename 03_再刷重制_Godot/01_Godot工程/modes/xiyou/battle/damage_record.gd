class_name XDamageRecord
extends Control
## 设置「战斗伤害记录」（Star_CombatDamageRecord v1.1 ＋ Bailong_StarDamageRecord_ExactAction）：战斗右下角统计出战成员造成的伤害。
## - 开战时（Window_BattleLog 建立）设置开着才建出；胜利、逃跑、全灭（BattleManager.endBattle）立即移除。
## - 窗口 Star_Record：宽 248、高 36 + 18×出战人数，放在 (1280−248−12, 720−高−12)；内边距 6、行高 18；
##   窗口皮肤透明，暗底横向渐变（左半 透明→黑 0.6，右半 黑 0.6，上下各留内边距）。
## - 第 0 行：「伤害统计」（字号 15、系统色，宽 80）＋ 合计（右对齐）；第 i 个出战栏位在 y = 24 + 18i（字号 14）：
##   名字（宽 92）、伤害（x 94 右对齐，宽 内容宽 −140）、占比（系统色，右对齐在内容最右 44 宽）。空栏位不画但留出行位。
## - 计数（Bailong 精确版）：角色对敌人的每次 Action.apply，HP 伤害（>0，取整）计入该角色所在的出战栏位；持续伤害等不计。
## - 数字写法 formatDamage：<1 万原样，否则 万/亿/兆/京/垓/秭/穰，保留两位小数（JS 数字写法，末尾的 0 去掉）。
## 原版在手机上会避开虚拟按键（installV019UsabilityRuntime），Mac 没有虚拟按键，不做。

const WIDTH := 248.0
const PADDING := 6.0
const LH := 18.0
const UNITS := [[1e4, 1e8, "万"], [1e8, 1e12, "亿"], [1e12, 1e16, "兆"], [1e16, 1e20, "京"], [1e20, 1e24, "垓"], [1e24, 1e28, "秭"]]

var slots: Array = []        # 出战栏位的角色 ID（0 为空）
var values: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var canvas: XMVCanvas


## slot_ids：XState.battle_slots；members：出战人数（battleMembers().length）
func setup(slot_ids: Array, members: int) -> void:
	slots = slot_ids.duplicate()
	var h := 36.0 + LH * members
	size = Vector2(WIDTH, h)
	position = Vector2(1280.0 - WIDTH - 12.0, 720.0 - h - 12.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = XMVCanvas.new()
	canvas.position = Vector2(PADDING, PADDING)
	canvas.size = size - Vector2(PADDING, PADDING) * 2.0
	canvas.painter = _paint
	add_child(canvas)


func total() -> float:
	var t := 0.0
	for v in values:
		t += v
	return t


## 一次 Action.apply 的结果：使用者是出战角色、目标是敌人时计入
func record(user: XBattler, target: XBattler, hp_damage: float) -> void:
	if not (user is XActor and target is XEnemy):
		return
	var i := slots.find(user.actor_id)
	var dmg := floorf(maxf(0.0, hp_damage))
	if i < 0 or i >= values.size() or dmg <= 0.0:
		return
	values[i] += dmg
	canvas.queue_redraw()


static func format_damage(d: float) -> String:
	if d < 1e4:
		return _js_number(d)
	for u in UNITS:
		if d < u[1]:
			return _js_number(roundf(d / u[0] * 100.0) / 100.0) + u[2]
	return _js_number(roundf(d / 1e28 * 100.0) / 100.0) + "穰"


## JS Number → 字符串（整数不带小数点，小数去掉末尾 0）
static func _js_number(v: float) -> String:
	if v == floorf(v) and absf(v) < 1e21:
		return "%d" % int(v) if absf(v) < 9.2e18 else String.num(v, 0)
	return String.num(v, 2)


func _draw() -> void:
	# Star_Record.refreshDimmerBitmap：左半 dimColor2→dimColor1 横向渐变，右半实心 dimColor1，上下各留内边距
	var c1 := Color(0, 0, 0, 0.6)
	var c2 := Color(0, 0, 0, 0)
	var w1 := ceilf(size.x / 2.0)
	var h1 := size.y - PADDING * 2.0
	draw_polygon(PackedVector2Array([Vector2(0, PADDING), Vector2(w1, PADDING), Vector2(w1, PADDING + h1), Vector2(0, PADDING + h1)]),
		PackedColorArray([c2, c1, c1, c2]))
	draw_rect(Rect2(w1, PADDING, w1, h1), c1)


func _paint(c: XMVCanvas) -> void:
	var t := total()
	var w := c.size.x
	var sys := XUI.text_color(16)
	c.text("伤害统计", 0, 0, 80, "left", sys, 15, LH)
	c.text(format_damage(t), 80, 0, w - 80, "right", XUI.TEXT, 15, LH)
	for i in range(mini(5, slots.size())):
		var id := int(slots[i])
		if id <= 0:
			continue
		var a: XActor = XState.current.actor(id) if XState.current else null
		if a == null:
			continue
		var y := 24.0 + i * LH
		var pct := roundi(values[i] / t * 100.0) if t > 0 else 0
		c.text(a.display_name(), 0, y, 92, "left", XUI.TEXT, 14, LH)
		c.text(format_damage(values[i]), 94, y, w - 140, "right", XUI.TEXT, 14, LH)
		c.text("%d%%" % pct, w - 44, y, 44, "right", sys, 14, LH)
