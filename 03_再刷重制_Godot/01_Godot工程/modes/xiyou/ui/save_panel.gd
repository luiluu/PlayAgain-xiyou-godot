class_name XSavePanel
extends PanelContainer
## 选格存档页（Godot 独立存档 10 格，对应 YEP 的 Scene_Save）：新游戏后还没存过档时，一键存档打开这里选格。
## 平时的「存档」照原版走公共事件 1，存到开局选的固定存档位。

signal closed

var _col: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", XUI.panel(XUI.MENU_WINDOW_OPACITY))
	_col = VBoxContainer.new()
	add_child(_col)
	_build("")


func _build(note: String) -> void:
	for c in _col.get_children():
		c.queue_free()
	_col.add_child(XUI.label("请选择一个文件插槽。（西游重制版独立存档，与 MV 版无关）", 22, XUI.DIM))
	var first: Button = null
	for i in range(1, XSave.SLOTS + 1):
		var b := XUI.button(XSave.summary(i), 56)
		b.icon = XUI.icon_texture(int(XDB.plugin("YEP_SaveCore").get("Saved Icon" if XSave.exists(i) else "Empty Icon", 0)))
		var slot := i
		b.pressed.connect(func():
			var ok := XSave.save(slot)
			_build("已保存到存档 %d。" % slot if ok else "保存失败。"))
		_col.add_child(b)
		if first == null:
			first = b
	if note != "":
		_col.add_child(XUI.label(note, 22, XUI.POWER_UP if note.begins_with("已") else XUI.DEATH))
	first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
