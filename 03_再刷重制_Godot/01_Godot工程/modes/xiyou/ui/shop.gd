class_name XShop
extends Control
## 商店（MV 商店处理）：goods = [[类型 0物品/1武器/2防具, ID, 价格类型 0标准/1指定, 价格], ...]。
## 买入用数据库价格或指定价格；卖出半价（MV 规则），装备卖背包里的实例。
## 画面照原版 YEP_ShopMenuCore：上方说明窗，指令窗＋金钱窗，左侧商品列表（宽 boxWidth/2+boxWidth/10），
## 右侧持有数与队员装备对比；菜单底图，窗口不透明度 30。

signal closed

var goods: Array = []
var purchase_only := false
var _list: VBoxContainer
var _gold: Label
var _help: Label
var _info: VBoxContainer
var _mode := "buy"


func setup(g: Array, only: bool) -> void:
	goods = g
	purchase_only = only


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var vs := get_viewport_rect().size
	var op := XUI.MENU_WINDOW_OPACITY
	var help_h := XUI.LINE_HEIGHT * 2 + 28
	var help := _win(Rect2(0, 0, vs.x, help_h), op)
	_help = XUI.label("")
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_child(_help)
	var list_w := vs.x / 2.0 + vs.x / 10.0
	var cmd := _win(Rect2(0, help_h, list_w, 72), op)
	var top := HBoxContainer.new()
	cmd.add_child(top)
	for m in [["购买", "buy"], ["出售", "sell"], ["离开", "leave"]]:
		if m[1] == "sell" and purchase_only:
			continue
		var b := XUI.button(m[0], 44)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = m[1]
		b.pressed.connect(func():
			if key == "leave":
				closed.emit()
				return
			_mode = key
			_refresh())
		top.add_child(b)
	(top.get_child(0) as Button).grab_focus.call_deferred()
	var gw := _win(Rect2(list_w, help_h, vs.x - list_w, 72), op)
	var grow := HBoxContainer.new()
	gw.add_child(grow)
	_gold = XUI.label("")
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grow.add_child(_gold)
	grow.add_child(XUI.label(" " + str(XDB.system().currencyUnit), XUI.FONT_SIZE, XUI.SYSTEM))
	var body_y := help_h + 72
	var lw := _win(Rect2(0, body_y, list_w, vs.y - body_y), op)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lw.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)
	var iw := _win(Rect2(list_w, body_y, vs.x - list_w, vs.y - body_y), op)
	_info = VBoxContainer.new()
	iw.add_child(_info)
	_refresh()


func _win(r: Rect2, opacity: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", XUI.panel(opacity))
	p.position = r.position
	p.size = r.size
	add_child(p)
	return p


static func table_of(kind: int) -> String:
	return ["Items", "Weapons", "Armors"][kind]


func _price(g: Array) -> int:
	var rec := XDB.rec(table_of(int(g[0])), int(g[1]))
	return int(g[3]) if int(g[2]) == 1 else int(rec.get("price", 0))


## 一行商品：图标＋名字，右侧价格。
func _row(rec: Dictionary, price_text: String, enabled: bool, on_press: Callable, kind: int) -> void:
	var b := XUI.button(str(rec.get("name", "")), 44)
	b.icon = XUI.icon_texture(int(rec.get("iconIndex", 0)))
	b.disabled = not enabled
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p := XUI.label(price_text, XUI.FONT_SIZE, XUI.TEXT if enabled else XUI.DIM)
	p.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_left = -200
	p.offset_right = -12
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(p)
	var show := func():
		_help.text = XText.plain(str(rec.get("description", "")))
		_show_info(rec, kind)
	b.mouse_entered.connect(show)
	b.focus_entered.connect(show)
	b.pressed.connect(on_press)
	_list.add_child(b)


func _refresh() -> void:
	var s := XState.current
	_gold.text = str(s.gold)
	_help.text = ""
	for c in _list.get_children():
		c.queue_free()
	for c in _info.get_children():
		c.queue_free()
	if _mode == "buy":
		for g in goods:
			var rec := XDB.rec(table_of(int(g[0])), int(g[1]))
			if rec.is_empty():
				continue
			var price := _price(g)
			var gg: Array = g
			_row(rec, str(price), s.gold >= price, func(): _buy(gg), int(g[0]))
	else:
		for id in s.items.keys():
			var rec := XDB.rec("Items", int(id))
			if rec.is_empty() or int(rec.get("price", 0)) <= 0 or int(rec.get("itypeId", 1)) == 2:
				continue
			var iid := int(id)
			_row(rec, "%d   ×%d" % [int(rec.price) / 2, s.items[id]], true, func():
				s.gain_item(iid, -1)
				s.gain_gold(int(rec.price) / 2)
				_refresh(), 0)
		for i in range(s.gear.size()):
			var inst: Dictionary = s.gear[i]
			_row(inst, str(int(inst.get("price", 0)) / 2), true, func():
				s.gear.erase(inst)
				s.gain_gold(int(inst.get("price", 0)) / 2)
				_refresh(), 1 if inst.kind == "weapon" else 2)
	if _list.get_child_count() == 0:
		_list.add_child(XUI.label("（没有可交易的东西）", XUI.FONT_SIZE, XUI.DIM))


## 右侧：持有数；装备类再列出各队员换上后的攻防变化（MV Window_ShopStatus）。
func _show_info(rec: Dictionary, kind: int) -> void:
	for c in _info.get_children():
		c.queue_free()
	var s := XState.current
	var owned := 0
	var kind_name: String = ["item", "weapon", "armor"][kind]
	if kind == 0:
		owned = int(s.items.get(int(rec.get("id", 0)), s.items.get(str(rec.get("id", 0)), 0)))
	else:
		# 商品是数据库记录（无 kind/base），出售列表是背包实例（有 kind/base）
		if not rec.has("kind"):
			rec = rec.duplicate()
			rec.kind = kind_name
			rec.base = int(rec.id)
		owned = s.gear_count(kind_name, int(rec.base))
	var row := HBoxContainer.new()
	row.add_child(XUI.label("持有数", XUI.FONT_SIZE, XUI.SYSTEM))
	var n := XUI.label(str(owned))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n)
	_info.add_child(row)
	if kind == 0 or not rec.has("etypeId"):
		return
	var param := 2 if kind == 1 else 3
	for a in s.members():
		var r := HBoxContainer.new()
		var name := XUI.label(a.display_name(), 22, XUI.TEXT if a.can_equip(rec) else XUI.DIM)
		name.custom_minimum_size.x = 150
		r.add_child(name)
		if not a.can_equip(rec):
			r.add_child(XUI.label("无法装备", 22, XUI.DIM))
		else:
			var slot: int = a.equip_slots().find(int(rec.etypeId))
			var cur = a.equips[slot] if slot >= 0 and slot < a.equips.size() else null
			var d := int(rec.params[param]) - (int(cur.params[param]) if cur != null and not cur.is_empty() else 0)
			r.add_child(XUI.label(["", "攻击", "防御"][kind] + " ", 22, XUI.SYSTEM))
			r.add_child(XUI.label("%+d" % d, 22, XUI.POWER_UP if d > 0 else (XUI.POWER_DOWN if d < 0 else XUI.TEXT)))
		_info.add_child(r)


func _buy(g: Array) -> void:
	var s := XState.current
	var price := _price(g)
	if s.gold < price:
		return
	s.gain_gold(-price)
	match int(g[0]):
		0: s.gain_item(int(g[1]), 1)
		1: s.gain_gear("weapon", int(g[1]), 1)
		2: s.gain_gear("armor", int(g[1]), 1)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
