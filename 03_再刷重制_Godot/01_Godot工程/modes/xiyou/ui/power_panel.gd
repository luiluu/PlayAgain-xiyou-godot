class_name XPowerPanel
extends XWebPanel
## 角色战力面板（正式西游 v0.28 installEquipmentStatusRuntime renderPower，网页覆盖层＋installGamePanelTheme 外观）。
## 状态页右上角「战力 N」按钮（toolbar，与装备检索按钮同款：右上 (−8, 8)、17 号、内边距 5/9、高 39.2）点开；
## 正式版运行时读数见 tests/fixtures/power_panel_oracle.json（参照截图 04_验证/本地结果/原版参照/bajie8_power_*）。
## - 标题「<名字> · 战力」，说明「等级 N · 按当前装备、技能与成长评估。」；下面队伍页签（全体队员，当前角色光标色），
##   切换只换面板里的角色，不改状态页。
## - 详情框 (40,165.79,1200,468.02) 可滚动：胶囊「总战力／自身战力／装备战力」（装备战力＝各件装备评分之和 gearScore）；
##   「人物属性：」元素名（元素色，「／」隔开，没有写「无属性」）；各元素承伤（CodexElements.activeIds 2～9、11～15，
##   元素色，横间距 12、行距 6 换行）；h3「能力构成」三张卡（输出／生存／辅助 N，「自身 N · 装备提升 ±N」）；
##   「3回合平均输出 N · 10回合平均输出 N」，有则加「尚未完整评估的技能：」「战力未计入：名字（原因）」；
##   h3「已穿装备」每件一卡（「部位 · 名字」「战力 N（· 法宝 N级）」「输出 N · 生存 N · 辅助 N」），没穿写空行说明；
##   h3「自身成长来源」说明（正式版明细 rows 恒为空）。
## - 底部栏左说明、右「返回游戏」；Esc／关闭／返回游戏都关掉。
## 数值全部取 XPower.actor（与正式版一致）；未做：路线比较（routes，变身钩子角色未接入）。

const ACTIVE_ELEMENTS := [2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15]
const GROWTH_NOTE := "等级、进阶、永久属性、当前灵魂与技能熟练度按实际效果计入；自身战力在卸下装备的条件下评估。装备综合提升包含百分比属性和机制联动。"
const FOOT_NOTE := "标准条件下的能力参考值；特殊脚本和条件触发仍逐步完善，不代表所有敌人的实战结果。"
const DETAIL := Rect2(40, 165.79, 1200, 468.02)
const WIDTH := 1164.0

var actor_id := 0
var detail_box: Control
var detail_scroll: ScrollContainer


## 工具条按钮「战力 N」（状态页右上角）；关掉战力时不建
static func make_button(a: XActor, on_open: Callable) -> Button:
	if not XPower.enabled():
		return null
	var b := Button.new()
	b.text = button_text(a)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "查看角色战力"
	style_button(b, Vector2(9, 5))
	b.custom_minimum_size.y = 39.2
	b.size = b.get_combined_minimum_size()
	b.position = Vector2(1280 - 8 - b.size.x, 8)
	b.resized.connect(func(): b.position = Vector2(1280 - 8 - b.size.x, 8))
	b.pressed.connect(on_open)
	return b


static func button_text(a: XActor) -> String:
	return "战力 " + XPower.format(float(XPower.actor(a).total))


static func open(parent: Control, a: XActor) -> XPowerPanel:
	var p := XPowerPanel.new()
	p.actor_id = a.actor_id if a != null else 0
	parent.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	render()


func _draw() -> void:
	draw_frame()


## renderPower 的成员表：全体队员；当前角色不在队里时接在后面
func actors() -> Array:
	var s := XState.current
	var list: Array = s.party.map(func(id): return s.actor(int(id)))
	if actor_id > 0 and not s.party.has(actor_id):
		list.append(s.actor(actor_id))
	return list


func actor() -> XActor:
	var list := actors()
	for a in list:
		if a.actor_id == actor_id:
			return a
	return list[0] if not list.is_empty() else null


func pick(id: int) -> void:
	actor_id = id
	render()


func render() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var a := actor()
	if not XPower.enabled():
		head("角色战力", "战力显示与估算已关闭，可在设置中开启。")
		return
	if a == null:
		head("角色战力", "暂无可查看的角色。")
		return
	actor_id = a.actor_id
	var data := XPower.actor(a)
	head(a.display_name() + " · 战力", "等级 %d · 按当前装备、技能与成长评估。" % a.level)
	# 队伍页签 .cq-tabs：间距 6
	var x := CONTENT_X
	for m in actors():
		var b := _button(m.display_name(), pick.bind(m.actor_id))
		if m == a:
			for k in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(k, _box(CURSOR, CURSOR_EDGE))
		b.position = Vector2(x, 116.59)
		b.set_meta("tab", true)
		add_child(b)
		b.size = b.get_combined_minimum_size()
		b.size.y = 41.2
		x += b.size.x + 6
	detail_scroll = _panel_scroll(DETAIL, 13)
	var old := detail_scroll.get_child(0)
	detail_scroll.remove_child(old)
	old.queue_free()
	detail_box = stack(blocks(a, data), WIDTH)
	detail_scroll.add_child(detail_box)
	footer(FOOT_NOTE, "返回游戏", close)
	queue_redraw()


## 详情各块（按正式版顺序）；宽 1164（详情框 1200 − 边框 2 − 内边距 26 − 滚动条 8）
func blocks(a: XActor, data: Dictionary) -> Array:
	var w := WIDTH
	var out := []
	var pill_items := []
	for t in ["总战力 " + XPower.format(float(data.total)), "自身战力 " + XPower.format(float(data.self)),
			"装备战力 " + XPower.format(float(data.get("gearScore", 0)))]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.3), Color(1, 211 / 255.0, 115 / 255.0, 0.45), 6, 1, Vector2(7, 3)))
		p.add_child(_fixed(_label(t, 13, GOLD), 20.8))
		p.set_meta("pill", true)
		pill_items.append(p)
	out.append(spaced(flow(pill_items, w, 7, 7, 28.8), 8, 8, w))
	out.append(_spans(attribute_parts(a), 0))
	out.append(_spans(resistance_parts(a), 12))
	out.append(h3_block("能力构成", w))
	for i in range(XPower.LABELS.size()):
		out.append(card_block([[XPower.LABELS[i] + " " + XPower.format(float(data.parts[i])), 18, TEXT, 28.8, true],
			["自身 " + XPower.format(float(data.selfParts[i])) + " · 装备提升 " + XPowerNotice.delta(float(data.gearParts[i])), 13, MUTED, 20.8]], w))
	for line in evaluation_lines(data):
		out.append(text_block(line, 13, MUTED, 20.8, w))
	out.append(h3_block("已穿装备", w))
	if data.equipment.is_empty():
		out.append(spaced(text_block("未穿装备，自身战力仍然有效。", 18, MUTED, 28.8, w - 40), 20, 20, w))
	for r in data.equipment:
		out.append(card_block([[equipment_title(r), 18, TEXT, 28.8, true], [equipment_meta(r), 13, MUTED, 20.8],
			[" · ".join(range(3).map(func(i): return XPower.LABELS[i] + " " + XPower.format(float(r.score.parts[i])))), 13, MUTED, 20.8]], w))
	# 卡片下距 7 与 h3 上距 12 折叠成 12（CSS 相邻外边距取大者）
	out.append(h3_block("自身成长来源", w, 5.0 if not data.equipment.is_empty() else 12.0))
	out.append(text_block(GROWTH_NOTE, 13, MUTED, 20.8, w))
	return out


## 「3回合平均输出 …」与覆盖说明
static func evaluation_lines(data: Dictionary) -> Array:
	var ev: Dictionary = data.get("evaluation", {})
	if ev.is_empty():
		return []
	var out := ["3回合平均输出 " + XPower.format(float(ev.burst)) + " · 10回合平均输出 " + XPower.format(float(ev.sustained))]
	var cov: Dictionary = ev.coverage
	if not cov.unknown.is_empty():
		out.append("尚未完整评估的技能：" + "、".join(cov.unknown.map(func(r): return str(r.name))))
	if not cov.get("unmodeled", []).is_empty():
		out.append("战力未计入：" + "、".join(cov.unmodeled.map(func(r): return "%s（%s）" % [r.name, r.reason])))
	return out


static func equipment_title(r: Dictionary) -> String:
	var types: Array = XDB.system().get("equipTypes", [])
	var et := int(r.item.get("etypeId", 0))
	var t := str(types[et]) if et > 0 and et < types.size() and str(types[et]) != "" else "装备"
	return t + " · " + XGearQuery.text(str(r.item.get("name", "")))


static func equipment_meta(r: Dictionary) -> String:
	var level := int(r.score.get("level", 0))
	return "战力 " + XPower.format(float(r.score.total)) + (" · 法宝 %d级" % level if level > 0 else "")


## CodexElements.createAttributes：[[文字, 颜色], …]
static func attribute_parts(a: XActor) -> Array:
	var parts := [["人物属性：", MUTED]]
	var names: Array = XDamage.elements_data().get("names", [])
	var ids := XDamage.affinity(a)
	if ids.is_empty():
		parts.append(["无属性", MUTED])
	for i in range(ids.size()):
		if i > 0:
			parts.append(["／", MUTED])
		var e: int = ids[i]
		parts.append([str(names[e]) if e < names.size() else "", Color(XHelpCard.ELEMENT_COLORS[e] if e < XHelpCard.ELEMENT_COLORS.size() else XHelpCard.ELEMENT_COLORS[0])])
	return parts


## CodexElements.createResistance：「火焰承伤 90%」…，元素色
static func resistance_parts(a: XActor) -> Array:
	var names: Array = XDamage.elements_data().get("names", [])
	var out := []
	for e in ACTIVE_ELEMENTS:
		out.append(["%s承伤 %d%%" % [str(names[e]) if e < names.size() else "", int(XPower.js_round(a.element_rate(e) * 100))], Color(XHelpCard.ELEMENT_COLORS[e])])
	return out


## 一行 13 号文字段：gap 为 0 时紧接（人物属性），否则按 flex 换行（横 gap、纵 6）
func _spans(parts: Array, gap: int) -> Control:
	var items := []
	for p in parts:
		var l := _fixed(_label(p[0], 13, p[1]), 20.8)
		l.set_meta("span", true)
		items.append(l)
	return flow(items, WIDTH, gap, 6, 20.8)


## Esc 关闭（XWebPanel._input）；其余按键不传给状态页
