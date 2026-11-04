class_name XTestModeScene
extends Control
## 设置「GM 工具」（原版 Scene_CodexGM 的功能移植，界面用 Godot 控件，不照原版 HTML 排版）。
## 只有本机解锁并开了测试模式时才由设置页打开（XTestMode）；功能全在 XTestMode 里，本页只管界面。
## 取消键（Esc／右键）返回设置。

signal closed

var kind: OptionButton
var query: LineEdit
var results: ItemList
var count: SpinBox
var add_button: Button
var selected_label: Label
var gold: SpinBox
var actor: OptionButton
var exp_box: SpinBox
var resource: OptionButton
var resource_label: Label
var resource_count: SpinBox
var status: Label
var _rows: Array = []
var _selected := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.055, 0.086, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "GM 工具"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := Button.new()
	back.text = "返回游戏"
	back.pressed.connect(close)
	head.add_child(back)
	var tip := Label.new()
	tip.text = "测试模式已开启 · 战斗经验 ×10 · 技能使用后升至当前上限 · 普通怪更易掉带高品质词条的装备（最多 4 个）。培养与添加结果随存档保存。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(tip)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 20)
	root.add_child(cols)
	# 左：添加物品
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(_title("添加物品"))
	var row := HBoxContainer.new()
	left.add_child(row)
	kind = OptionButton.new()
	for k in [["items", "物品／材料"], ["weapons", "武器"], ["armors", "防具／法宝"]]:
		kind.add_item(k[1])
		kind.set_item_metadata(kind.item_count - 1, k[0])
	kind.item_selected.connect(func(_i): _refresh_results())
	row.add_child(kind)
	query = LineEdit.new()
	query.placeholder_text = "搜索名称或编号"
	query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query.text_changed.connect(func(_t): _refresh_results())
	row.add_child(query)
	results = ItemList.new()
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.custom_minimum_size = Vector2(0, 200)
	results.item_selected.connect(_on_pick)
	left.add_child(results)
	selected_label = Label.new()
	selected_label.text = "先选择物品。装备每次最多 99 件。"
	left.add_child(selected_label)
	var row2 := HBoxContainer.new()
	left.add_child(row2)
	count = _spin(1, 9999, 1)
	row2.add_child(count)
	add_button = Button.new()
	add_button.text = "添加所选物品"
	add_button.disabled = true
	add_button.pressed.connect(_do_item)
	row2.add_child(add_button)
	# 右：金币、经验、恢复、资源
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_title("金币与角色"))
	var g := HBoxContainer.new()
	right.add_child(g)
	gold = _spin(1, 999999999, 100000)
	g.add_child(gold)
	g.add_child(_button("加钱", _do_gold))
	actor = OptionButton.new()
	actor.add_item("全队角色")
	actor.set_item_metadata(0, 0)
	var s := XState.current
	if s != null:
		for a in s.members():
			actor.add_item("%s · Lv.%d" % [a.display_name(), a.level])
			actor.set_item_metadata(actor.item_count - 1, a.actor_id)
	right.add_child(actor)
	var e := HBoxContainer.new()
	right.add_child(e)
	exp_box = _spin(1, 999999999, 100000)
	e.add_child(exp_box)
	e.add_child(_button("加经验", _do_exp))
	right.add_child(_button("全队恢复生命／魔法并复活", _do_recover))
	right.add_child(_title("自定义资源"))
	resource = OptionButton.new()
	for r in XTestMode.RESOURCES:
		resource.add_item(r[1])
		resource.set_item_metadata(resource.item_count - 1, r[0])
	resource.item_selected.connect(func(_i): _refresh_resource())
	right.add_child(resource)
	resource_label = Label.new()
	right.add_child(resource_label)
	resource_count = _spin(0, 999999999, 10000)
	right.add_child(resource_count)
	var rr := HBoxContainer.new()
	right.add_child(rr)
	rr.add_child(_button("增加", func(): _do_resource("add")))
	rr.add_child(_button("设为此数量", func(): _do_resource("set")))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)
	_refresh_results()
	_refresh_resource()


func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	return l


func _spin(lo: float, hi: float, v: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.value = v
	sp.step = 1
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sp


func _button(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	return b


func _kind() -> String:
	return str(kind.get_item_metadata(kind.selected))


func _refresh_results() -> void:
	_selected = -1
	add_button.disabled = true
	selected_label.text = "先选择物品。装备每次最多 99 件。"
	results.clear()
	_rows = XTestMode.catalog(_kind(), query.text)
	for rec in _rows.slice(0, 200):
		results.add_item("#%d  %s" % [int(rec.id), rec.name])
	if _rows.is_empty():
		selected_label.text = "没有匹配的物品。"
	elif _rows.size() > 200:
		selected_label.text = "显示前 200 项，请输入名称或编号缩小范围。"


func _on_pick(i: int) -> void:
	_selected = i
	add_button.disabled = false
	selected_label.text = "已选择：%s（#%d）" % [_rows[i].name, int(_rows[i].id)]


func _report(r: Dictionary) -> void:
	if not r.ok:
		XSound.system(3)
	status.text = str(r.text)
	status.modulate = Color("a9dfb7") if r.ok else Color("ffb8ae")


func _do_item() -> void:
	if _selected < 0:
		_report({"ok": false, "text": "请先选择物品。"})
		return
	_report(XTestMode.give_item(XState.current, _kind(), int(_rows[_selected].id), count.value))


func _do_gold() -> void:
	_report(XTestMode.give_gold(XState.current, gold.value))


func _do_exp() -> void:
	_report(XTestMode.give_exp(XState.current, int(actor.get_item_metadata(actor.selected)), exp_box.value))


func _do_recover() -> void:
	_report(XTestMode.recover(XState.current))


func _refresh_resource() -> void:
	var key := str(resource.get_item_metadata(resource.selected))
	resource_label.text = "当前%s：%d" % [resource.get_item_text(resource.selected), XTestMode.resource_amount(XState.current, key)]


func _do_resource(mode: String) -> void:
	_report(XTestMode.change_resource(XState.current, str(resource.get_item_metadata(resource.selected)), resource_count.value, mode))
	_refresh_resource()


func close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()
