class_name XAutosaveNotice
extends CanvasLayer
## 【cc·界面·未经审查】YEP_X_Autosave 的 Window_Autosave（地图右下「存档成功！」「存档加载成功！」小字）。
## 原版参数：ShowAutosave true；AutosaveMsgSave「\i[907]存档成功！」、AutosaveMsgLoad「\i[2997]存档加载成功！」；
## MsgX＝boxWidth−280＝1000、MsgY＝boxHeight−fittingHeight(1)×2＝720−72＝648；宽＝boxWidth 1280、高 fittingHeight(1)＝36、内边距 0；
## 窗框不透明度 0、文字层开始 0；MsgDuration 120、FadeSpeed 16。
## - 什么时候出：Scene_Map.performAutosave 存档成功后 reveal（事件插件指令 Autosave，见 mv_event_core）；
##   DataManager.loadGameWithoutRescue 读档后 _autosaveLoading＝true，下一个 Scene_Map 建窗时 reveal 一次，写「存档加载成功！」。
##   重制读档有两条：XSave.load_slot（存档页读档、标题「旧的回忆」）照原版；切后台自动存档 load_auto 是重制自己加的，也算读档，同样出。
## - 画法（MsgGradientCode）：textWidth＝drawTextEx 宽（图标 36＋字宽），half＝textPadding 6＋ceil(textWidth/2)；
##   (0,0,half,36) 横向渐变 rgba(0,0,0,0)→rgba(0,0,0,0.6)，(half,0,1280−half,36) 0.6→0；文字 drawTextEx 在 (6,0)。
## - 动画：reveal 时 showCount＝120（已在显示就不重来）；每帧 showCount>0 时文字不透明度 +16、否则 −16（夹在 0～255）。
## 回退：ENABLED = false 不显示（存读档照常）。复现原版，不登 O 号。

static var ENABLED := true
const RECT := Rect2(1000, 648, 1280, 36)
const MSG_SAVE := "\\i[907]存档成功！"
const MSG_LOAD := "\\i[2997]存档加载成功！"
const DURATION := 120
const FADE := 16
const PAD := 6.0

## $gameTemp._autosaveLoading：读档成功设上，下一次进地图场景时出一次「存档加载成功！」
static var loading := false

var win: XMVWindow
var show_count := 0
var contents_opacity := 0
var message := MSG_SAVE


## 当前场景上没有就挂一个
static func ensure() -> XAutosaveNotice:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var node := tree.current_scene.get_node_or_null("XAutosaveNotice") as XAutosaveNotice
	if node == null:
		node = XAutosaveNotice.new()
		node.name = "XAutosaveNotice"
		tree.current_scene.add_child(node)
	return node


## Scene_Map.performAutosave 存好之后
static func saved() -> void:
	loading = false  # saveGameWithoutRescue 清 _autosaveLoading
	if not ENABLED:
		return
	var n := ensure()
	if n != null:
		n.reveal(MSG_SAVE)


## 地图场景建好（Scene_Map.createAllWindows → new Window_Autosave）：刚读过档就出「存档加载成功！」
static func map_ready(scene: Node) -> void:
	if not loading:
		return
	loading = false
	if not ENABLED or scene == null:
		return
	var n := scene.get_node_or_null("XAutosaveNotice") as XAutosaveNotice
	if n == null:
		n = XAutosaveNotice.new()
		n.name = "XAutosaveNotice"
		scene.add_child(n)
	n.reveal(MSG_LOAD)


func _init() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(1280, 720)
	add_child(host)
	win = XMVWindow.make(host, RECT, 0, _paint)
	win.padding = 0.0
	win.canvas.modulate.a = 0.0


## Window_Autosave.reveal：正在显示时不重来
func reveal(msg: String) -> void:
	if show_count > 0:
		return
	message = msg
	show_count = DURATION
	win.refresh()


func _physics_process(_delta: float) -> void:
	step()


## Window_Autosave.update 一次
func step() -> void:
	if show_count > 0:
		contents_opacity = mini(255, contents_opacity + FADE)
		show_count -= 1
	else:
		contents_opacity = maxi(0, contents_opacity - FADE)
	win.canvas.modulate.a = contents_opacity / 255.0


## drawTextEx 宽（图标 36＋字宽）
static func text_width(msg: String) -> float:
	var t := XMVText.new(XMVText.convert_escapes(msg), 0, 0)
	return t.run()


func _paint(c: XMVCanvas) -> void:
	var half := PAD + ceilf(text_width(message) / 2.0)
	var h := RECT.size.y
	var c1 := Color(0, 0, 0, 0)
	var c2 := Color(0, 0, 0, 0.6)
	c.gradient(Rect2(0, 0, half, h), c1, c2)
	c.gradient(Rect2(half, 0, RECT.size.x - half, h), c2, c1)
	var t := XMVText.new(XMVText.convert_escapes(message), PAD, 0)
	t.run()
	XMVText.paint(c, t.glyphs)
