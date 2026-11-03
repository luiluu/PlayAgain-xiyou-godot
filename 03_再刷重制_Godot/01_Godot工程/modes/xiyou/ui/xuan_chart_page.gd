class_name XXuanChartPage
extends Control
## 【cc·哪吒·未经审查】xuan1 璇的星谱页（installNativeXuanRuntime.js 第 522～561 行 X.openStarchart／starMenu／slotMenu／pickActor；
## 公共事件 9015 → B.openMenu → Scene_CodexBindMenu）。菜单背景上一个 XChoiceWindow（原版 CodexYunshang.choose），打开时光标在第一项。
## 行文与次序在 core/xuan_chart.gd（照参照 xuan_chart_probe 逐字）。取消＝逐层退回，首页取消＝关页。
signal closed

var choice: XChoiceWindow
## 测试用：每次打开的页 {info, rows}
var log: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	choice = XChoiceWindow.new()
	add_child(choice)
	home()


func s() -> XState:
	return XState.current


func a():
	return XXuanChart.xuan(s())


func choose(rows: Array, ok: Callable, cancel: Callable, lines := []) -> void:
	var wrapped := XOrbShop.wrap_info(lines)
	log.append({"info": wrapped, "rows": rows.map(func(r): return {"label": str(r.label), "enabled": r.get("enabled", true) != false})})
	choice.open(rows, ok, cancel, wrapped)


func close() -> void:
	closed.emit()


func home() -> void:
	choose(XXuanChart.home_rows(s(), a()), _home_pick, close, XXuanChart.home_info(s()))


func _home_pick(r: Dictionary) -> void:
	match str(r.kind):
		"control":
			XXuanChart.set_control(s(), a(), "manual" if XXuanChart.control(s()) == "auto" else "auto")
			home()
		"slot":
			slot_menu(int(r.slot))
		"partner":
			pick_actor("并轨副宿主", func(id): XXuanChart.set_partner(s(), id))
		"roster":
			pick_actor("命主名册（最多%d人）" % XXuanChart.stage(s()), func(id): XXuanChart.toggle_roster(s(), id))
		"element":
			choose(XXuanChart.element_rows(), _element_pick, home, [XXuanChart.ELEMENT_INFO])


func _element_pick(x: Dictionary) -> void:
	XXuanChart.set_element(s(), int(x.id))
	home()


func slot_menu(slot: int) -> void:
	choose(XXuanChart.slot_rows(s(), slot), func(r): mark_menu(slot, str(r.m)), home, ["星砂 %d" % int(XXuanChart.chart(s()).sand)])


func mark_menu(slot: int, m: String) -> void:
	choose(XXuanChart.mark_rows(s(), m), func(x):
		var res: Dictionary
		match str(x.act):
			"equip":
				res = XXuanChart.equip(s(), a(), m)
			"learn":
				res = XXuanChart.learn(s(), a(), m)
			_:
				res = XXuanChart.refund(s(), a(), m)
		if str(res.error) != "":
			XToast.show_text(str(res.error), true)
		slot_menu(slot), func(): slot_menu(slot), [XXuanChart.NAMES["mark_" + m], XXuanChart.NAMES["markDesc_" + m]])


func pick_actor(title: String, fn: Callable) -> void:
	choose(XXuanChart.party_rows(s()), func(r):
		fn.call(int(r.id))
		home(), home, [title])
