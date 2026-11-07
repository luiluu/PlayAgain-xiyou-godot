class_name XPrestigeNotice
extends CanvasLayer
## 【cc·界面·未经审查】至臻装备入包闪光（installTreasureBatchRuntime 的 T.updateNotice，v0.29；队列在 XTreasureBatch）。
## 原版在 Scene_Item／Scene_Map／Scene_Battle 每次 update 后调：队列有东西且上一次的闪光已经结束时，开一个通知：
## - 全屏闪光（ScreenSprite，颜色 255,219,130）：不透明度 floor(128 × 剩余帧／45)，45 帧。
## - 窗（Window_Base，宽 min(700, 画面宽−24)＝700、fittingHeight(4)＝4×36＋28＝172，水平居中、y＝max(12, floor(画面高×0.12))＝86，
##   底色不透明）：第 0 行「至臻现世 · 获得 N 件」（#ffe28a 居中）；前两种各一行：图标 (0, 行高×i)、名字（多于 1 件加「 ×n」）在 x 40；
##   多于两种时第 3 行「另有 k 种至臻装备」居中。共 150 帧，文字不透明度 min(255, 剩余帧×12)，到 0 关窗。
## 重制挂在当前场景（地图场景；物品页、战斗都是它的子节点）上，按物理帧走（齿轮 1.6 倍时同原版按 updateScene 计）。

const FLASH_COLOR := Color8(255, 219, 130)
const RECT := Rect2(290, 86, 700, 172)
const TITLE_COLOR := "#ffe28a"
const FRAMES := 150
const FLASH_FRAMES := 45

var flash: ColorRect
var win: XMVWindow
var frames := 0
var flash_frames := 0
var items: Array = []
var count := 0


## 当前场景上没有就挂一个
static func ensure() -> XPrestigeNotice:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var node := tree.current_scene.get_node_or_null("XPrestigeNotice") as XPrestigeNotice
	if node == null:
		node = XPrestigeNotice.new()
		node.name = "XPrestigeNotice"
		tree.current_scene.add_child(node)
	return node


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(FLASH_COLOR, 0.0)
	flash.size = Vector2(1280, 720)
	add_child(flash)
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(1280, 720)
	add_child(host)
	win = XMVWindow.make(host, RECT, 255, _paint)
	win.visible = false


func _physics_process(_delta: float) -> void:
	step()


## T.updateNotice 一次
func step() -> void:
	if flash_frames <= 0 and not XTreasureBatch.queue.is_empty():
		items = XTreasureBatch.take_queue()
		if not items.is_empty():
			count = 0
			for r in items:
				count += int(r.count)
			frames = FRAMES
			flash_frames = FLASH_FRAMES
			win.visible = true
			win.canvas.modulate.a = 1.0
			win.refresh()
	if flash_frames > 0:
		flash.color.a = floorf(128.0 * flash_frames / FLASH_FRAMES) / 255.0
		flash_frames -= 1
	else:
		flash.color.a = 0.0
	if frames > 0:
		frames -= 1
		win.canvas.modulate.a = minf(255.0, frames * 12.0) / 255.0
		if frames == 0:
			win.visible = false


func _paint(c: XMVCanvas) -> void:
	var w := c.size.x
	var lh := XUI.LINE_HEIGHT
	c.text("至臻现世 · 获得 %d 件" % count, 0, 0, w, "center", Color(TITLE_COLOR))
	for i in mini(2, items.size()):
		var r: Dictionary = items[i]
		c.icon(int(r.icon), 0, lh * (i + 1))
		c.text(str(r.name) + (" ×%d" % int(r.count) if int(r.count) > 1 else ""), 40, lh * (i + 1), w - 40)
	if items.size() > 2:
		c.text("另有 %d 种至臻装备" % (items.size() - 2), 0, lh * 3, w, "center")
