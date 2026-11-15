class_name XSkinDrag
extends RefCounted
## 【cc·天启篇·未经审查】收口批（TOUCH_V2，小A核 P2-2）：手指拖动滚动的小件，给状态页、装备详情展开、战斗战技列表用（XSkinList 自带一份同样的）。
## 按下 press(位置, 当前滚动值)；移动 motion(位置) 过了 SLOP 才算拖，返回「按下时的滚动值＋拖过的像素」该滚到哪（没在拖返回 NAN）；
## 松手 release() 返回这次算不算一次点（没拖过）。

const SLOP := 10.0
var from := Vector2.INF
var base := 0.0
var dragging := false


func active() -> bool:
	return from != Vector2.INF


func press(p: Vector2, base_value: float) -> void:
	from = p
	base = base_value
	dragging = false


## 拖着时返回目标滚动值（像素，往上拖为正）；没拖返回 NAN
func motion(p: Vector2) -> float:
	if not active():
		return NAN
	var dy := from.y - p.y
	if not dragging and absf(dy) >= SLOP:
		dragging = true
	return base + dy if dragging else NAN


func release() -> bool:
	var tap := active() and not dragging
	from = Vector2.INF
	dragging = false
	return tap
