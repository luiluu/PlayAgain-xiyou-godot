class_name XSkinSelectStyle
extends StyleBox
## 【cc·天启篇·未经审查】红乙选中条的静态 StyleBox（XUiSkin.draw_select）：给 Button 主题和 MV 光标框用。
## 会动的那条（行间滑动、连按不排队、呼吸）是 XSkinSelectBar。
## state（XUiSkin.SelState）：FOCUS 焦点、HOVER 悬停（减淡、无光标）、PRESSED 按下（压暗、下沉 1px）；cc/ui-skin-p1fix 起三态分开。

var alpha := 1.0
var state := XUiSkin.SelState.FOCUS
## T349 D1b：框形控件（XSkinButton）用的双环模式。FOCUS＝淡金双环（只在键盘／手柄态画）；HOVER＝只抬到 S4 底；PRESSED 照旧压暗选中条
var ring := false


func _draw(ci: RID, rect: Rect2) -> void:
	if ring and XUiSkin.detail_on():
		if state == XUiSkin.SelState.FOCUS:
			if XUiSkin.show_focus_ring():
				XUiSkin.draw_focus_ring(ci, rect, XUiSkin.ROW_RADIUS, false, alpha)
			return
		if state == XUiSkin.SelState.HOVER:
			var sb := StyleBoxFlat.new()
			sb.bg_color = XUiSkin.surface_overlay("s4")
			sb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
			sb.draw(ci, rect)
			return
	XUiSkin.draw_select(ci, rect, XUiSkin.breath_alpha(), alpha, state)
