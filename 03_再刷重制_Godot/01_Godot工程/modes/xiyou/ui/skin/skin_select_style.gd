class_name XSkinSelectStyle
extends StyleBox
## 【cc·天启篇·未经审查】红乙选中条的静态 StyleBox（XUiSkin.draw_select）：给 Button 主题和 MV 光标框用。
## 会动的那条（行间滑动、连按不排队、呼吸）是 XSkinSelectBar。
## state（XUiSkin.SelState）：FOCUS 焦点、HOVER 悬停（减淡、无光标）、PRESSED 按下（压暗、下沉 1px）；cc/ui-skin-p1fix 起三态分开。

var alpha := 1.0
var state := XUiSkin.SelState.FOCUS


func _draw(ci: RID, rect: Rect2) -> void:
	XUiSkin.draw_select(ci, rect, XUiSkin.breath_alpha(), alpha, state)
