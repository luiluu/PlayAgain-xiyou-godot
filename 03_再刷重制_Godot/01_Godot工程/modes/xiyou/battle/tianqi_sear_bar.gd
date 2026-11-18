class_name XTianqiSearBar
extends Control
## 【cc·T120·未经审查】天启篇烙印的灼痕槽（《天启篇_烙印 v0.5》第四节第 4 条「灼痕画在角色状态栏里、贴着血条的一条细槽」，第十三节 T073-d2）。
## 右侧状态栏每一行的生命条正下方画一条 3px 的细槽：当前值 ÷ 上限；满了清零的那一下闪一闪。只读 XTianqiBrand.sear_rows，不改结算。
## 烙印开关关着、西游档、不在天启篇战斗里时 sear_rows 为空，什么也不画（行为不变）。不写字（槽名只在战斗记录「…满了！」那一行出现）。

const POLL := 0.1
## 相对状态栏一行左上：生命条在 (12, 28) 起、宽 XSideStatus.GAUGE_W、行高 LH，细槽贴在它下面
const OFFSET := Vector2(12, 28 + 22)
const BAR_H := 3.0
const FILL := Color("#c9a25e")
const BACK := Color(0.12, 0.10, 0.08, 0.85)
const FLASH := Color("#fff1c8")

var logic
## 右侧状态栏：Callable，返回 {角色: XSideStatus}
var rows_source: Callable
## 当前画的：[{actor, value, cap, fills}]（测试读）
var rows: Array = []
var _t := 0.0
var _flash := {}   # 角色 → 剩余闪烁秒数
var _fills := {}   # 角色 → 上次看到的满过几次


static func make(battle_logic, rows_fn := Callable()) -> XTianqiSearBar:
	var m := XTianqiSearBar.new()
	m.logic = battle_logic
	m.rows_source = rows_fn
	return m


func _ready() -> void:
	name = "TianqiSearBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	refresh()


func refresh() -> void:
	rows = []
	if logic is Object and is_instance_valid(logic):
		rows = XTianqiBrand.sear_rows(logic)
	for r in rows:
		var a = r.actor
		if _fills.has(a) and int(r.fills) > int(_fills[a]):
			_flash[a] = 0.6
		_fills[a] = int(r.fills)
	queue_redraw()


func _process(dt: float) -> void:
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - dt
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	_t += dt
	if _t >= POLL:
		_t = 0.0
		refresh()
	elif not _flash.is_empty():
		queue_redraw()


func _draw() -> void:
	if rows.is_empty() or not rows_source.is_valid():
		return
	var rs = rows_source.call()
	if not rs is Dictionary:
		return
	for r in rows:
		var row = rs.get(r.actor)
		if row == null or not is_instance_valid(row) or not row.visible:
			continue
		var p: Vector2 = row.global_position - global_position + OFFSET
		var w := XSideStatus.GAUGE_W
		draw_rect(Rect2(p, Vector2(w, BAR_H)), BACK)
		var k := clampf(float(r.value) / float(maxi(1, int(r.cap))), 0.0, 1.0)
		if k > 0.0:
			draw_rect(Rect2(p, Vector2(floorf(w * k), BAR_H)), FILL)
		var fl := clampf(float(_flash.get(r.actor, 0.0)) / 0.6, 0.0, 1.0)
		if fl > 0.0:
			draw_rect(Rect2(p, Vector2(w, BAR_H)), Color(FLASH, fl))
