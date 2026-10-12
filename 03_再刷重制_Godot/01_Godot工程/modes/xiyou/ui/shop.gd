class_name XShop
extends Control
## 商店（MV 商店处理）：goods = [[类型 0物品/1武器/2防具, ID, 价格类型 0标准/1指定, 价格], ...]。
## 买入用数据库价格或指定价格；卖出半价（MV 规则），装备卖背包里的实例。

signal closed

var goods: Array = []
var purchase_only := false
var _list: VBoxContainer
var _gold: Label
var _mode := "buy"


func setup(g: Array, only: bool) -> void:
	goods = g
	purchase_only = only


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", XUI.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 560)
	panel.position = (get_viewport_rect().size - panel.custom_minimum_size) / 2.0
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	for m in [["买入", "buy"], ["卖出", "sell"]]:
		if m[1] == "sell" and purchase_only:
			continue
		var b := XUI.button(m[0], 46)
		var key: String = m[1]
		b.pressed.connect(func():
			_mode = key
			_refresh())
		top.add_child(b)
	var close := XUI.button("离开", 46)
	close.pressed.connect(func(): closed.emit())
	top.add_child(close)
	_gold = XUI.label("", 22, XUI.GOLD)
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_gold)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_refresh()


static func table_of(kind: int) -> String:
	return ["Items", "Weapons", "Armors"][kind]


func _price(g: Array) -> int:
	var rec := XDB.rec(table_of(int(g[0])), int(g[1]))
	return int(g[3]) if int(g[2]) == 1 else int(rec.get("price", 0))


func _refresh() -> void:
	var s := XState.current
	_gold.text = "%d %s" % [s.gold, XDB.system().currencyUnit]
	for c in _list.get_children():
		c.queue_free()
	if _mode == "buy":
		for g in goods:
			var rec := XDB.rec(table_of(int(g[0])), int(g[1]))
			if rec.is_empty():
				continue
			var price := _price(g)
			var b := XUI.button("%s    %d" % [rec.name, price], 48)
			b.icon = XUI.icon_texture(int(rec.get("iconIndex", 0)))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = XText.plain(str(rec.get("description", "")))
			b.disabled = s.gold < price
			var gg: Array = g
			b.pressed.connect(func(): _buy(gg))
			_list.add_child(b)
	else:
		for id in s.items.keys():
			var rec := XDB.rec("Items", int(id))
			if rec.is_empty() or int(rec.get("price", 0)) <= 0 or int(rec.get("itypeId", 1)) == 2:
				continue
			var b := XUI.button("%s ×%d    卖 %d" % [rec.name, s.items[id], int(rec.price) / 2], 48)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var iid := int(id)
			b.pressed.connect(func():
				s.gain_item(iid, -1)
				s.gain_gold(int(rec.price) / 2)
				_refresh())
			_list.add_child(b)
		for i in range(s.gear.size()):
			var e: Dictionary = s.gear[i]
			var b := XUI.button("%s    卖 %d" % [e.name, int(e.get("price", 0)) / 2], 48)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var inst := e
			b.pressed.connect(func():
				s.gear.erase(inst)
				s.gain_gold(int(inst.get("price", 0)) / 2)
				_refresh())
			_list.add_child(b)
	if _list.get_child_count() == 0:
		_list.add_child(XUI.label("（没有可交易的东西）", 20, XUI.DIM))


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
