class_name XSkinCrumb
extends Control
## 【cc·天启篇·未经审查】T283 通用小件「面包屑」（T254 3.0）：「画面 › 画质设置」，15 号 TEXT_2，分隔「›」TEXT_3，最后一段旧金 GOLD。
## 放在列表标题下面一行（设置子页、层级菜单页用；商店不用）。只显示，不接点击、不接按键（返回上一层＝取消键，页面自己管）。
## 太长放不下时从最前面一段起换成「…」，最后一段永远完整。
## 用法：
##   var crumb := XSkinCrumb.new(); list_panel.add_child(crumb)
##   crumb.set_parts(["画面", "画质设置"])
##   或者不建节点，在自己的 _draw 里：XSkinCrumb.draw_parts(self, Vector2(x, baseline), ["画面", "画质设置"], max_w)

const H := 24.0
const FS := 15
const SEP := "›"

var parts: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, H)
	resized.connect(queue_redraw)


func set_parts(arr: Array) -> void:
	parts = arr.map(func(p): return str(p))
	queue_redraw()


func _draw() -> void:
	draw_parts(self, Vector2(0, size.y / 2.0 + XUiSkin.fs(FS) * 0.36), parts, size.x)


## 在 ci 上从 pos（左缘、基线）画一串；max_w≤0 不限宽。返回画了多宽
static func draw_parts(ci: CanvasItem, pos: Vector2, arr: Array, max_w := -1.0) -> float:
	if arr.is_empty():
		return 0.0
	var f := XUiSkin.font("body")
	var fs := XUiSkin.fs(FS)
	var shown := fit_parts(arr, max_w)
	var x := pos.x
	for i in shown.size():
		if i > 0:
			var sep := " %s " % SEP
			XUiSkin.ds(ci, f, Vector2(x, pos.y), sep, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_3)
			x += f.get_string_size(sep, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var t := str(shown[i])
		XUiSkin.ds(ci, f, Vector2(x, pos.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.GOLD if i == shown.size() - 1 else XUiSkin.TEXT_2)
		x += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return x - pos.x


## 放不下时从前往后把段换成「…」（连续的「…」并成一个），最后一段不动
static func fit_parts(arr: Array, max_w: float) -> Array:
	var out: Array = arr.map(func(p): return str(p))
	if max_w <= 0.0:
		return out
	var k := 0
	while width_of(out) > max_w and k < arr.size() - 1:
		out = ["…"] + arr.slice(k + 1).map(func(p): return str(p))
		k += 1
	return out


static func width_of(arr: Array) -> float:
	var f := XUiSkin.font("body")
	var fs := XUiSkin.fs(FS)
	var w := 0.0
	for i in arr.size():
		if i > 0:
			w += f.get_string_size(" %s " % SEP, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		w += f.get_string_size(str(arr[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w
