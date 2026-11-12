class_name XTianqiMeter
extends Control
## 【cc·天启篇·未经审查】战斗里的本线核心计量（四线异化 v0.8 第 2.2 节：「每条线一个看得见的计量，只要场上有本线异化怪就会出现」）。
## 火花（战争）：条，n／满几点；饥饿（饥荒）：消耗倍率、回复倍率；死期（死亡）：被挂死期的人，右侧状态栏旁加死期标记；
## 病灶（瘟疫）：条，层数／满几层。只读各线异化模块记在战斗对象上的数据（meta），不改结算。
##
## 各线模块不一定都合进来了（死亡线、瘟疫线在各自分支），所以按 meta 键读数据、按全局类表动态取模块，
## 哪条线不在都能编译；模块不在时那条线不显示。开关 XTianqiLook.METER（O-325）。

const ROW_H := 30.0
const BAR_W := 150.0
const W := 300.0
const POLL := 0.1

## 线 → [战斗对象上的 meta 键, 模块类名]
const SOURCES := {
	"war": ["xwar_alien", "XTianqiWarAlien"],
	"famine": ["xfamine_alien", "XTianqiFamineAlien"],
	"death": ["xdeath_alien", "XTianqiDeathAlien"],
	"plague": ["xplague_alien", "XTianqiPlagueAlien"],
}
const ORDER := ["war", "death", "famine", "plague"]

var logic
## 右侧状态栏：Callable，返回 {角色: XSideStatus}（死期标记画在这些行旁边）
var rows_source: Callable
## 当前显示的行：[{key, label, text, value, full}]；测试读它
var rows: Array = []
## 被挂死期的角色（测试读）
var doomed: Array = []
var _t := 0.0
var _flash := {}          # 线 → 剩余闪烁秒数（火花满、病灶爆发）
var _last := {}           # 线 → 上次的值（看火花归零、病灶过线）
static var _classes := {}


static func make(battle_logic, rows_fn := Callable()) -> XTianqiMeter:
	var m := XTianqiMeter.new()
	m.logic = battle_logic
	m.rows_source = rows_fn
	return m


func _ready() -> void:
	name = "TianqiMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	refresh()


static func module(cls: String):
	if not _classes.has(cls):
		var script = null
		for c in ProjectSettings.get_global_class_list():
			if str(c.get("class", "")) == cls:
				script = load(str(c.path))
				break
		_classes[cls] = script
	return _classes[cls]


static func _call(cls: String, method: String, args: Array, def = null):
	var m = module(cls)
	if m == null or not m.has_method(method):
		return def
	return m.callv(method, args)


func _fight(key: String) -> Dictionary:
	if not (logic is Object) or not is_instance_valid(logic):
		return {}
	var meta := str(SOURCES[key][0])
	if not logic.has_meta(meta):
		return {}
	var f = logic.get_meta(meta)
	return f if f is Dictionary else {}


func _any_alien_alive(f: Dictionary) -> bool:
	for e in f.get("units", {}):
		if is_instance_valid(e) and e.is_alive():
			return true
	return false


## 重算要显示的行
func refresh() -> void:
	rows = []
	doomed = []
	if not XTianqiLook.METER:
		queue_redraw()
		return
	for key in ORDER:
		var f := _fight(key)
		if f.is_empty():
			continue
		var cls := str(SOURCES[key][1])
		var r := {"key": key, "label": str(XTianqiLook.info(key).meter), "text": "", "value": 0, "full": 0}
		match key:
			"war":
				if not _any_alien_alive(f):
					continue
				r.value = int(f.get("sparks", 0))
				r.full = int(_call(cls, "spark_full", [logic], 10))
				r.text = "%d／%d" % [r.value, r.full]
				if _last.has(key) and r.value < int(_last[key]):
					_flash[key] = 0.6   # 满了归零：全体再动
			"famine":
				if not bool(_call(cls, "hungry", [logic], _any_alien_alive(f))):
					continue
				var cost := float(_call(cls, "cost_mult", [logic], 1.0))
				var heal := float(_call(cls, "heal_mult", [logic], 1.0))
				r.text = "消耗 ×%s　回复 ×%s" % [_num(cost), _num(heal)]
				r.value = -1
			"death":
				for a in f.get("doom", {}):
					if is_instance_valid(a) and a.is_alive():
						doomed.append(a)
				if not _any_alien_alive(f) and doomed.is_empty():
					continue
				var names := PackedStringArray(doomed.map(func(a): return a.display_name()))
				r.text = "、".join(names) + "　回合结束时死" if not names.is_empty() else "暂无"
				r.value = -1
			"plague":
				if not bool(_call(cls, "sick", [logic], _any_alien_alive(f))):
					continue
				var d = _call(cls, "data", [], {})
				r.value = int(f.get("layers", 0))
				r.full = int(d.get("focus", {}).get("full", 12)) if d is Dictionary else 12
				r.text = "%d／%d" % [r.value, r.full]
				if bool(f.get("burst", false)) and not bool(_last.get(key + ":burst", false)):
					_flash[key] = 0.6
				_last[key + ":burst"] = bool(f.get("burst", false))
		_last[key] = r.value
		rows.append(r)
	queue_redraw()


static func _num(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.left(s.length() - 1)
	return s.trim_suffix(".")


func _process(dt: float) -> void:
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - dt
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	_t += dt
	if _t >= POLL:
		_t = 0.0
		refresh()
	elif not _flash.is_empty() or not doomed.is_empty():
		queue_redraw()


func _draw() -> void:
	var font := XUI.font()
	var y := 0.0
	for r in rows:
		var key := str(r.key)
		var main := XTianqiLook.main_color(key)
		var dark := XTianqiLook.dark_color(key)
		var fl := clampf(float(_flash.get(key, 0.0)) / 0.6, 0.0, 1.0)
		var box := Rect2(0, y, W, ROW_H - 4)
		draw_rect(box, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(0, y, 4, ROW_H - 4), main)
		draw_string(font, Vector2(10, y + 20), str(r.label), HORIZONTAL_ALIGNMENT_LEFT, 56, 18, main.lightened(0.15))
		var tx := 66.0
		if int(r.full) > 0:
			var bar := Rect2(66, y + 7, BAR_W, 12)
			draw_rect(bar, Color(dark, 0.9))
			var k := clampf(float(r.value) / float(r.full), 0.0, 1.0)
			var fill := main.lerp(XTianqiLook.accent_color(key), k * k)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), fill)
			draw_rect(bar, Color(main, 0.7), false, 1.0)
			tx = 66.0 + BAR_W + 8.0
		draw_string(font, Vector2(tx, y + 20), str(r.text), HORIZONTAL_ALIGNMENT_LEFT, W - tx - 4, 16, Color(0.95, 0.95, 0.95))
		if fl > 0.0:
			draw_rect(box, Color(XTianqiLook.accent_color(key), 0.45 * fl))
		y += ROW_H
	_draw_doom_marks()


## 死期标记：被挂死期的角色，右侧状态栏左边画一枚骨白小钟（冷蓝指针），一闪一闪
func _draw_doom_marks() -> void:
	if doomed.is_empty() or not rows_source.is_valid():
		return
	var rs = rows_source.call()
	if not rs is Dictionary:
		return
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 160.0)
	var bone := XTianqiLook.main_color("death")
	var blue := XTianqiLook.accent_color("death")
	for a in doomed:
		var row = rs.get(a)
		if row == null or not is_instance_valid(row):
			continue
		var c: Vector2 = row.global_position - global_position + Vector2(-56, 36)
		draw_circle(c, 15, Color(0, 0, 0, 0.6))
		draw_circle(c, 12, Color(bone, pulse))
		draw_arc(c, 12, 0, TAU, 24, Color(blue, pulse), 2.0)
		draw_line(c, c + Vector2(0, -8), Color(blue.darkened(0.3), pulse), 2.0)
		draw_line(c, c + Vector2(6, 2), Color(blue.darkened(0.3), pulse), 2.0)
