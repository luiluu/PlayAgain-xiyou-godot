class_name XTusuForge
extends Control
## 【cc·白龙·未经审查】tusu7 屠苏的器谱（installNativeTusuRuntime.js 第 649～663 行 T.openForge／forgeMenu；公共事件 9014 → B.openMenu → Scene_CodexBindMenu）。
## 菜单背景上一个 XChoiceWindow（原版 CodexYunshang.choose 的 Window_YunChoices），打开时光标在第一项：
## - 首页：说明「每次进阶可开刃一相…」；三道铭文「第n道铭文：开刃·x／未开刃」，没进阶到的前缀「（未开放）」、灰显。
##   T.forgeRows 第一行标题「器谱　开刃 n/3」不可选又没有 slot，被 forgeMenu 的过滤去掉，原版画面上看不到，照搬。取消＝关页。
## - 选一道铭文：说明「第n道铭文：选择开刃的武相」，五相「开刃·x　说明」，已开在别的铭文上的灰显；选定 XTusu.set_kairen，
##   换掉已开的相要人道意志碎片 ×10，不够时提示（原版 $.toaster 抛错的原文）。选定或取消都回首页。
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


func choose(rows: Array, ok: Callable, cancel: Callable, lines := []) -> void:
	var wrapped := XOrbShop.wrap_info(lines)
	log.append({"info": wrapped, "rows": rows.map(func(r): return {"label": str(r.label), "enabled": r.get("enabled", true) != false})})
	choice.open(rows, ok, cancel, wrapped)


func close() -> void:
	closed.emit()


func home() -> void:
	var rows := XTusu.forge_rows(s()).filter(func(r): return r.get("enabled", true) != false or r.has("slot"))
	choose(rows, func(r): if r.has("slot"): weapons(int(r.slot)), close, [XTusu.FORGE_NAMES.forgeInfo])


func weapons(slot: int) -> void:
	var k := XTusu.kairen(s())
	var rows := XTusu.WEAPONS.map(func(w): return {"label": XTusu.FORGE_NAMES["kairen_" + w] + "　" + XTusu.FORGE_NAMES["kairenDesc_" + w], "w": w,
		"enabled": not k.has(w) or k.find(w) == slot})
	choose(rows, func(r):
		var why := XTusu.set_kairen(s(), slot, str(r.w))
		if why != "" and why != "invalid":
			XToast.show_text(why, true)
		home(), home, [XTusu.FORGE_NAMES.forgePick % (slot + 1)])
