class_name XSkinSelectStyle
extends StyleBox
## 【cc·天启篇·未经审查】红乙选中条的静态 StyleBox（XUiSkin.draw_select）：给 Button 主题和 MV 光标框用。
## 会动的那条（行间滑动、连按不排队、呼吸）是 XSkinSelectBar。

var alpha := 1.0


func _draw(ci: RID, rect: Rect2) -> void:
	XUiSkin.draw_select(ci, rect, XUiSkin.breath_alpha(), alpha)
