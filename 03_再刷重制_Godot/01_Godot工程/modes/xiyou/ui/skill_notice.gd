class_name XSkillNotice
extends CanvasLayer
## 【cc·八戒·未经审查】技能升级通告（installSkillLevelNoticeRuntime v1.0.0；外观经 installGamePanelTheme 覆盖）：
## - 触发：setSkillMasteryLevel／gainSkillMasteryLevel 之后等级升高（XSkillMastery.set_level／gain_level 调 report）；只报角色，
##   设置「消息提醒 → 技能升级通告」关掉时不报，标题画面与新局、读档期间不报（原版 suppressed／_codexGmReady；重制新局、读档不经
##   set_level／gain_level，标题画面没有 XState.current）。饿狼进阶继承熟练度（_garouAdvancing）期三接。
## - 同一帧里同一角色同一技能合并成一行 from→to（原版 Promise 微任务；重制 call_deferred 到本帧末）。
## - 网页层：右上角（right 16、top 16）宽 380 的竖排，间隔 8；最多同时 3 条，每条 5.5 秒后移走、补上排队的下一条。
##   一条：1 像素边 rgba(255,255,255,0.55)、圆角 8、底 #16161f（--gp-panel）、内边距上下 12 左右 16、阴影 (0,4) 模糊 14 rgba(0,0,0,0.53)；
##   第一行「技能升级」15 号系统色 #84aaff，下距 4；第二行「角色名 · 技能名」18 号白字；第三行「Lv.a → Lv.b」18 号 #d4e9ff，上距 5；
##   字都有四向 1 像素黑描边（--gp-outline），字体 sans-serif（不是游戏字体）。行高取字体的正常行高（CSS line-height: normal），
##   没有逐像素对过浏览器（交付单记着）。

const RIGHT := 16.0
const TOP := 16.0
const WIDTH := 380.0
const GAP := 8.0
const PAD := Vector2(16, 12)
const BORDER := 1
const MAX_VISIBLE := 3
const TIMEOUT := 5.5
const TITLE_SIZE := 15
const BODY_SIZE := 18
const TITLE_GAP := 4.0
const LEVEL_GAP := 5.0
const SYSTEM := Color("#84aaff")
const LEVEL := Color("#d4e9ff")
const BACK := Color("#16161f")
const EDGE := Color(1, 1, 1, 0.55)
const SHADOW := Color(0, 0, 0, 0x88 / 255.0)

## 本帧待合并的 {"角色:技能": 行}；已排队、正在显示的行（测试核对用）
static var _pending := {}
static var _scheduled := false
static var queue := []
static var shown := []
## 每条发出的行（原版 document 事件 codex-skill-level-up，测试核对用）
static var dispatched := []


## XSkillMastery 改等级之后调：before→after 升高才报
static func report(b, skill_id: int, before: int, after: int) -> void:
	if not (b is XActor) or after <= before or XState.current == null or not XConfig.notice_on("skillLevel") or (XGarou.advancing and XGarou.own(b)):  # actor._garouAdvancing
		return
	var rec := XDB.rec("Skills", skill_id)
	if rec.is_empty():
		return
	var key := "%d:%d" % [b.actor_id, skill_id]
	if _pending.has(key):
		_pending[key].to = after
	else:
		_pending[key] = {"actorId": b.actor_id, "skillId": skill_id, "actorName": b.display_name(), "skillName": str(rec.get("name", "")),
			"from": before, "to": after}
	if not _scheduled:
		_scheduled = true
		XSkillNotice._flush.call_deferred()


## 本帧末：待合并的行进队列、补显示
static func _flush() -> void:
	_scheduled = false
	for k in _pending:
		queue.append(_pending[k])
	_pending.clear()
	_layer().pump()


## 换局、回标题：清空（原版 setupNewGame／loadGame 的 clear）
static func clear() -> void:
	_pending.clear()
	queue.clear()
	var l := _existing()
	if l != null:
		l.epoch += 1
		for c in l.host.get_children():
			c.queue_free()
		shown.clear()


static func _existing() -> XSkillNotice:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("XSkillNotice") as XSkillNotice if tree else null


static func _layer() -> XSkillNotice:
	var l := _existing()
	if l == null:
		l = XSkillNotice.new()
		l.name = "XSkillNotice"
		(Engine.get_main_loop() as SceneTree).root.add_child(l)
	return l


static func font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["sans-serif"])
	return f


var host := Control.new()
var epoch := 0


func _init() -> void:
	layer = 100
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)


func pump() -> void:
	if XState.current == null or not XConfig.notice_on("skillLevel"):
		queue.clear()
		return
	while shown.size() < MAX_VISIBLE and not queue.is_empty():
		var row: Dictionary = queue.pop_front()
		var box := NoticeBox.new()
		box.row = row
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(box)
		shown.append(box)
		dispatched.append(row)
		var gen := epoch
		get_tree().create_timer(TIMEOUT).timeout.connect(func():
			if gen != epoch or not is_instance_valid(box):
				return
			shown.erase(box)
			box.queue_free()
			_layout()
			pump())
	_layout()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	var w := minf(WIDTH, vs.x - RIGHT * 2)
	var y := TOP
	for box in shown:
		if not is_instance_valid(box):
			continue
		box.size = Vector2(w, box.height())
		box.position = Vector2(vs.x - RIGHT - w, y)
		box.queue_redraw()
		y += box.size.y + GAP


## 一条通告：自己画字
class NoticeBox extends Control:
	var row := {}
	var font: Font = XSkillNotice.font()
	var style := StyleBoxFlat.new()

	func _init() -> void:
		style.bg_color = BACK
		style.border_color = EDGE
		style.set_border_width_all(BORDER)
		style.set_corner_radius_all(8)
		style.shadow_color = SHADOW
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 4)

	func lines() -> Array:
		return [["技能升级", TITLE_SIZE, SYSTEM, 0.0], [str(row.actorName) + " · " + str(row.skillName), BODY_SIZE, Color.WHITE, TITLE_GAP],
			["Lv.%d → Lv.%d" % [int(row.from), int(row.to)], BODY_SIZE, LEVEL, LEVEL_GAP]]

	func height() -> float:
		var h := (BORDER + PAD.y) * 2.0
		for l in lines():
			h += float(l[3]) + font.get_height(int(l[1]))
		return h

	func _draw() -> void:
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		var y := BORDER + PAD.y
		for l in lines():
			y += float(l[3])
			var at := Vector2(BORDER + PAD.x, roundf(y + font.get_ascent(int(l[1]))))
			draw_string_outline(font, at, str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, size.x - (BORDER + PAD.x) * 2, int(l[1]), 2, Color.BLACK)
			draw_string(font, at, str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, size.x - (BORDER + PAD.x) * 2, int(l[1]), l[2])
			y += font.get_height(int(l[1]))
