class_name XAchievementPopup
extends Control
## 成就获取弹窗（Star_AchievementShowPic：Window_AchievementPopup＋Star_Tween，正式参数 宽 300、停留 5 秒、「获得新成就！」、音效 Saint5）。
## 挂在当前场景上（原版 SceneManager._scene.addChild，换场景即消失）。参照 achievement_probe 的 popupLayout／popupSettings。
## - 窗口 300×50、内边距 0；x = (1280 − 300 − 10) / 2；y 从画面 2/3（480）起，被占用就往下 60（高 50＋间隔 10）。
## - 30 帧 easeOutCircular 淡入，停 300 帧，30 帧 easeInCircular 上移一个窗高并淡出后移除。
## - MOG_MenuBackground：菜单场景（Scene_MenuBase）里每帧把窗口 opacity 设为 30，弹窗的框与底也只剩 30，只有内容随渐变；
##   重制的菜单类画面加入 MBACK_GROUP 组（XMenu 及其子页、成就界面）。
## - 内容：图标 (10,10)；标题 \c[1] 成就名，字号 16，(50,5)；说明字号 12，(50,29) 宽 240。

const WIDTH := 300.0
const HEIGHT := 50.0
const GAP := 10.0
const IN_FRAMES := 30
const OUT_FRAMES := 30
const SCREEN := Vector2(1280, 720)
const MBACK_GROUP := "xiyou_mback"

static var _stack: Array = []

var item := {}
var win: XMVWindow
var base_y := 0.0
var frame := 0
var wait_frames := 300


static func settings() -> Dictionary:
	return XDB.plugin("Star_AchievementShowPic")


## AchievementPopupManager.onNotify
static func show_for(d: Dictionary) -> void:
	var st := settings()
	if str(st.get("Use Popup", "ON")) != "ON":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var layer := tree.current_scene.get_node_or_null("XAchievementPopups") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "XAchievementPopups"
		layer.layer = 85
		tree.current_scene.add_child(layer)
	_stack = _stack.filter(func(p): return is_instance_valid(p))
	var pop := XAchievementPopup.new()
	pop.item = d
	pop.wait_frames = floori(float(str(st.get("Popup Wait", "0.75"))) * 60)
	var y := SCREEN.y * 2.0 / 3.0
	for p in _stack:
		if p.position.y != y:
			break
		y += HEIGHT + GAP
	pop.base_y = y
	pop.position = Vector2((SCREEN.x - WIDTH - GAP) / 2.0, y)
	layer.add_child(pop)
	_stack.append(pop)
	_stack.sort_custom(func(a, b): return a.position.y < b.position.y)
	XSound.play(str(st.get("Popup Sound", "")), 90, 100)


func _ready() -> void:
	size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	win = XMVWindow.make(self, Rect2(Vector2.ZERO, size), 255, _paint)
	win.padding = 0.0
	_apply(0.0)


## Tween 的 opacity／backOpacity／contentsOpacity 同步变化；菜单场景里框与底固定 30
func _apply(a: float) -> void:
	var mback := is_inside_tree() and not get_tree().get_nodes_in_group(MBACK_GROUP).filter(func(n): return n.is_visible_in_tree()).is_empty()
	var o := XUI.MENU_WINDOW_OPACITY if mback else roundi(255 * a)
	if win.opacity != o:
		win.opacity = o
		win.queue_redraw()
	win.canvas.modulate.a = a


func _paint(c: XMVCanvas) -> void:
	c.icon(int(item.get("icon", 0)), 10, 10)
	c.text(str(item.get("name", "")), 50, 5, WIDTH - 50, "left", XUI.text_color(1), 16, 24)
	c.text(str(XAchievementPopup.settings().get("Popup Message", "")), 50, 29, WIDTH - 60, "left", XUI.TEXT, 12, 12)


static func _out_circ(n: float) -> float:
	n -= 1.0
	return sqrt(1.0 - n * n)


static func _in_circ(n: float) -> float:
	return 1.0 - sqrt(1.0 - n * n)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame <= IN_FRAMES:
		_apply(_out_circ(frame / float(IN_FRAMES)))
	elif frame <= IN_FRAMES + wait_frames:
		_apply(1.0)
	elif frame <= IN_FRAMES + wait_frames + OUT_FRAMES:
		var n := _in_circ((frame - IN_FRAMES - wait_frames) / float(OUT_FRAMES))
		_apply(1.0 - n)
		position.y = base_y - HEIGHT * n
	else:
		_stack.erase(self)
		queue_free()
