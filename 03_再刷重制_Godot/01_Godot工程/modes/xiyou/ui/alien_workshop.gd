class_name XAlienWorkshop
extends Control
## 异化工坊（主菜单「异化工坊」→ CodexAlienation.openWorkshop；正式 installAlienationWorkshop）。原版不是 MV 窗口，是盖在菜单上的
## 网页叠加层 #alien-workshop（暗底 #070912e8，居中面板宽 1080、底 #151325、边 #72618d 圆角 12、内边距 22，字 17px）。
## 这里先按原版 render() 搭出同样的节点树（build：标签、class、文字、按钮可否点），再照它的 CSS 摆成 Godot 控件；
## 测试直接比对节点树（tests/xiyou_alien_workshop，参照 alien_workshop_probe.cjs 的 jsdom 读数）。
## 页：标题＋返回；能量与异化石＋合成；有待选重抽时只显示两张选择卡；否则左列表右详情（重抽、分解与确认、配置异化），
## 没有异化装备时右侧是获取说明；最后是可展开的「最近异化掉落」。Esc 关闭。规则在 XAlienation。
## 「配置异化」按钮照原版显示与灰显，配置页属期二，点了暂不打开。

signal closed

const BACKDROP := Color("070912e8")
const PANE := Color("151325")
const PANE_BORDER := Color("72618d")
const TEXT := Color("e9e5f3")
const NOTE := Color("b8aec7")
const BUTTON := Color("29233e")
const BUTTON_BORDER := Color("76618e")
const BUTTON_FOCUS := Color("473459")
const SELECTED := Color("53385f")
const SELECTED_BORDER := Color("c6a2df")
const ERROR := Color("ffb5ba")
const ERROR_BACK := Color("512934")
const SIZES := {"h1": 28, "h2": 22, "h3": 18}
const BODY_SIZE := 17
const PARAM_NAMES := ["生命", "法力", "物攻", "物防", "魔攻", "魔防", "速度", "幸运"]

## 选中的异化装备 uid：原版是工坊模块的变量，关掉再开、读档后都还记着（uid 对上才生效）
static var selected := ""
var confirming := false
var error_text := ""
var recent_open := false
var root: Control
## 最近一次 render 的节点树（屏上显示的就是它；测试读它、按它点按钮）
var tree: Array = []
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = XUI.font()  # 原版是系统字（PingFang SC）；系统字回退会缺字（如「敌」），用游戏字体
	XUI.menu_background(self)
	var back := ColorRect.new()
	back.color = BACKDROP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	render()


func s() -> XState:
	return XState.current


func close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## ---- 节点树（原版 render 的 DOM） ----

static func el(tag: String, text = null, cls := "", children := []) -> Dictionary:
	var n := {"tag": tag, "children": children}
	if text != null:
		n.text = str(text)
	if cls != "":
		n.class = cls
	return n


static func btn(text: String, on: Callable, disabled := false, cls := "") -> Dictionary:
	var n := el("button", text, cls)
	n.disabled = disabled
	n.on = on
	return n


static func num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


func build() -> Array:
	var st := s()
	var cfg := XAlienation.config()
	var energy := st.item_count(XAlienation.energy_id())
	var stones := st.item_count(XAlienation.stone_id())
	var lg := XAlienation.ledger(st)
	var pane := []
	pane.append(el("div", null, "alien-heading", [el("h1", "异化工坊"), btn("返回", close)]))
	pane.append(el("div", null, "alien-summary", [el("span", "异化能量 %d　异化石 %d" % [energy, stones]),
		btn("20点能量 → 1颗异化石", _act.bind(func(): return XAlienation.craft(st, 1)), lg.pending != null or energy < 20)]))
	var err := el("p", error_text, "alien-error")
	if error_text == "":
		err.hidden = true
	pane.append(err)
	if lg.pending != null:
		var p: Dictionary = lg.pending
		var i = XAlienation.pending_item(st)
		pane.append(el("h2", "选择本次重抽结果"))
		pane.append(el("p", "异化石已经消耗。两种选择均不返还材料，关闭界面会保留本次待选结果。"))
		if i == null:
			err.text = "待选装备不可用，请保留当前存档以便检查。"
			err.erase("hidden")
			return [el("div", null, "alien-pane", pane)]
		pane.append(el("h3", i.name))
		var cards := []
		for x in [[p.old, "保留旧异化", false], [p.next, "采用新异化", true]]:
			var f := XAlienation.affix(str(x[0]))
			cards.append(el("section", null, "", [el("h2", f.name), el("p", "收益：" + str(f.benefit), "alien-benefit"),
				el("p", "代价：" + str(f.cost), "alien-cost"), btn(x[1], _act.bind(XAlienation.resolve.bind(st, x[2])))]))
		pane.append(el("div", null, "alien-choices", cards))
		return [el("div", null, "alien-pane", pane)]
	pane.append(el("p", "普通装备不能使用异化石。每名角色最多穿戴一件异化装备；需配置的词条请先配置再穿戴。", "alien-note"))
	var list := []
	var detail := []
	var all := XAlienation.owned(st).filter(func(e): return not XAlienation.mark(e).is_empty())
	if all.is_empty():
		list.append(el("p", "尚未获得异化装备。"))
		var maps := []
		for id in cfg.get("mobMaps", []):
			var info := XDB.rec("MapInfos", int(id))
			if not info.is_empty() and str(info.get("name", "")) != "":
				maps.append(str(info.name))
		var guide := [el("h2", "如何获得异化装备")]
		for t in ["在" + "、".join(PackedStringArray(maps)) + "的小怪战斗中，每场有1%机会出现紫色的异化敌人。" if not maps.is_empty() else "",
				"部分Boss每场最多有1%机会异化，奖励来自该Boss装备池的强力异化装备。",
				"击败异化敌人并赢得战斗，必定掉落一件异化装备；逃跑或失败不会掉落。",
				"重复的异化装备可以分解为异化能量（小怪装备1点、Boss装备5点），%d点合成1颗异化石，用来重抽已有异化装备的词条。" % int(cfg.energyCost)]:
			if t != "":
				guide.append(el("p", t))
		detail.append(el("div", null, "alien-guide", guide))
	for i in all:
		var uid := str(XAlienation.mark(i).uid)
		list.append(btn(str(i.name) + ("　[锁定]" if XAlienation.locked(i) else ""), _select.bind(uid), false, "selected" if uid == selected else ""))
	var picked = all.filter(func(e): return str(XAlienation.mark(e).uid) == selected)
	var item = picked[0] if not picked.is_empty() else (all[0] if not all.is_empty() else null)
	if item != null:
		selected = str(XAlienation.mark(item).uid)
		detail.append(el("h2", item.name))
		for t in XAlienation.details(st, item):
			detail.append(el("p", t, "alien-benefit" if t.begins_with("收益：") else ("alien-cost" if t.begins_with("代价：") else "")))
		detail.append(el("p", "品质、普通词条、强化、镶嵌和独立成长全部保留。"))
		var stats := []
		for n in 8:
			var v := float(item.get("params", [0, 0, 0, 0, 0, 0, 0, 0])[n])
			if v != 0:
				stats.append(PARAM_NAMES[n] + ("+" if v > 0 else "") + num(v))
		detail.append(el("p", "装备属性：" + "　".join(PackedStringArray(stats)), "alien-note"))
		var eligible := XAlienation.can_operate(st, item)
		if not eligible:
			detail.append(el("p", "操作前请卸下装备、解除锁定与绑定。"))
		var boss := str(XAlienation.mark(item).origin) == "boss"
		var actions := [btn("使用1颗异化石重抽", _act.bind(XAlienation.reroll.bind(st, item)), not eligible or stones < 1),
			btn("分解为%d点能量" % (5 if boss else 1), _confirm, not eligible)]
		if XAlienation.needs_configuration(item):
			actions.append(btn("配置异化", func(): pass, not eligible))
		detail.append(el("div", null, "alien-actions", actions))
		if confirming:
			detail.append(el("section", null, "alien-confirm", [el("h3", "确认分解 " + str(item.name)),
				el("p", "整件装备及其普通词条、强化、宝石、经验和成长将全部销毁。分解不会保留异化词条。"),
				btn("确认分解", _dismantle.bind(item)), btn("取消", _cancel_confirm)]))
	pane.append(el("div", null, "alien-body", [el("div", null, "alien-list", list), el("div", null, "alien-detail", detail)]))
	var recent: Array = lg.recent
	if not recent.is_empty():
		var rows := [btn("最近异化掉落（%d）" % recent.size(), _toggle_recent, false, "summary")]
		rows[0].tag = "summary"
		for r in recent.slice(0, 10):
			rows.append(el("p", str(r.name) + "　" + ("Boss" if str(r.origin) == "boss" else "小怪")))
		pane.append(el("details", null, "", rows))
	return [el("div", null, "alien-pane", pane)]


## 与参照 dump 同口径的展平：深度、标签、class、文字、按钮可否点、hidden；带文字的节点不再往下走
static func flatten(nodes: Array, depth := 0, out := []) -> Array:
	for n in nodes:
		var row := {"tag": n.tag, "depth": depth}
		if n.has("class") and n.class != "summary":
			row.class = n.class
		if n.has("text"):
			row.text = n.text
		if n.tag == "button":
			row.disabled = bool(n.get("disabled", false))
		if n.get("hidden", false):
			row.hidden = true
		out.append(row)
		if not n.has("text"):
			flatten(n.children, depth + 1, out)
	return out


## ---- 操作 ----

func _act(fn: Callable) -> void:
	var r: Dictionary = fn.call()
	error_text = str(r.error) if r.has("error") else ""
	render()


func _select(uid: String) -> void:
	selected = uid
	confirming = false
	render()


func _confirm() -> void:
	confirming = true
	render()


func _cancel_confirm() -> void:
	confirming = false
	render()


func _dismantle(item: Dictionary) -> void:
	var r := XAlienation.dismantle(s(), item)
	if r.has("error"):
		error_text = str(r.error)
	else:
		error_text = ""
		selected = ""
		confirming = false
	render()


func _toggle_recent() -> void:
	recent_open = not recent_open
	render()


## 测试用：按按钮文字点（参照路线的写法）；@n 点列表第 n 项
func click(label: String) -> bool:
	var found := _find(tree, label)
	if found.is_empty() or bool(found.get("disabled", false)):
		return false
	found.on.call()
	return true


func _find(nodes: Array, label: String, list_index := [-1]) -> Dictionary:
	for n in nodes:
		if label.begins_with("@") and n.get("class", "") == "alien-list":
			var buttons: Array = n.children.filter(func(c): return c.tag == "button")
			var k := int(label.substr(1))
			return buttons[k] if k < buttons.size() else {}
		if not label.begins_with("@") and n.tag in ["button", "summary"] and n.get("text", "") == label:
			return n
		if not n.has("text"):
			var r := _find(n.children, label)
			if not r.is_empty():
				return r
	return {}


## ---- 摆放（照原版 CSS） ----

func render() -> void:
	var nodes := build()
	tree = nodes
	if root != null:
		root.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 18
	center.offset_top = 18
	center.offset_right = -18
	center.offset_bottom = -18
	add_child(center)
	root = center
	var pane: Dictionary = nodes[0]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANE, PANE_BORDER, 12, 22))
	panel.custom_minimum_size = Vector2(minf(1080.0, size.x - 36.0), 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 0)
	panel.add_child(scroll)
	var box := _vbox()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for n in pane.children:
		var c := _make(n)
		if c != null:
			box.add_child(c)
	# 高度最多 96%（max-height:96vh，超出滚动）
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, size.y * 0.96 - 44.0)
	var first := _first_button(box)
	if first != null:
		first.grab_focus()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and not c.disabled and c.text != "返回":
			return c
		var r := _first_button(c)
		if r != null:
			return r
	return null


func _vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _box(bg: Color, border: Color, radius := 7, pad := 12, width := 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	return b


func _label(text: String, size_px := BODY_SIZE, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _make(n: Dictionary) -> Control:
	if n.get("hidden", false):
		return null
	var cls := str(n.get("class", ""))
	match str(n.tag):
		"h1", "h2", "h3":
			return _label(str(n.text), SIZES[n.tag])
		"p", "span":
			if cls == "alien-error":
				var pc := PanelContainer.new()
				pc.add_theme_stylebox_override("panel", _box(ERROR_BACK, ERROR_BACK, 0, 10, 0))
				pc.add_child(_label(str(n.text), BODY_SIZE, ERROR))
				return pc
			return _label(str(n.text), BODY_SIZE, NOTE if cls == "alien-note" else TEXT)
		"button", "summary":
			var b := Button.new()
			b.text = str(n.text)
			b.disabled = bool(n.get("disabled", false))
			b.add_theme_font_override("font", _font)
			b.add_theme_font_size_override("font_size", BODY_SIZE)
			for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				b.add_theme_color_override(c, TEXT)
			b.add_theme_color_override("font_disabled_color", Color(TEXT, 0.4))
			var on_sel := cls == "selected"
			b.add_theme_stylebox_override("normal", _box(SELECTED if on_sel else BUTTON, SELECTED_BORDER if on_sel else BUTTON_BORDER, 7, 9))
			b.add_theme_stylebox_override("hover", _box(BUTTON_FOCUS, Color("b595d1"), 7, 9, 2))
			b.add_theme_stylebox_override("focus", _box(BUTTON_FOCUS, Color("b595d1"), 7, 9, 2))
			b.add_theme_stylebox_override("pressed", _box(BUTTON_FOCUS, Color("b595d1"), 7, 9, 2))
			b.add_theme_stylebox_override("disabled", _box(Color(BUTTON, 0.4), Color(BUTTON_BORDER, 0.4), 7, 9))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT if n.tag == "summary" else HORIZONTAL_ALIGNMENT_CENTER
			if n.has("on"):
				b.pressed.connect(n.on)
			return b
	var kids: Array = n.children
	match cls:
		"alien-heading", "alien-summary", "alien-actions":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 16 if cls != "alien-actions" else 8)
			for k in kids:
				var c := _make(k)
				if c != null:
					if c is Label:
						c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					h.add_child(c)
			return h
		"alien-body", "alien-choices":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 18)
			h.custom_minimum_size.y = 260
			for k in kids:
				var c := _make(k)
				if c != null:
					c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					c.size_flags_stretch_ratio = 1.0 if str(k.get("class", "")) != "alien-detail" else 2.0
					h.add_child(c)
			return h
		"alien-list":
			var sc := ScrollContainer.new()
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc.custom_minimum_size.y = mini(430, 52 * kids.size())
			var v := _vbox(8)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for k in kids:
				var c := _make(k)
				if c is Button:
					c.alignment = HORIZONTAL_ALIGNMENT_LEFT
				v.add_child(c)
			sc.add_child(v)
			return sc
	var v := _vbox()
	var wrap: Control = v
	if n.tag == "section":
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color("b8787a") if cls == "alien-confirm" else Color("675475"), 8, 18 if cls == "" else 15))
		pc.add_child(v)
		wrap = pc
	for k in kids:
		if n.tag == "details" and k.tag != "summary" and not recent_open:
			continue
		var c := _make(k)
		if c != null:
			v.add_child(c)
	return wrap
