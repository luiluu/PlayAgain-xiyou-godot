class_name XKeySmoke
extends Node
## 发行包按键冒烟（platform-crash1，cc 2026-11-06）：只在命令行带 `-- --smoke-keys=<序列>` 时由 GameApp 挂上，平时不存在。
## 11-06 天启篇按空格/J 闪退是发行模板才有的空指针（调试版只报错），无头跑、不按键的冒烟看不到；
## 发行模板又不认 -s 脚本，所以把「按一串键」做进游戏本身，由 07_开发环境/发行入口冒烟.py 带参数启动、看进程活着没有。
## 序列用逗号分隔：accept（回车）／space／j／z／cancel（Esc）／x／k／up／down／left／right，或 wait:<帧数>。
## 每个键都走 Input.parse_input_event（和真按键一样经 Input → 窗口 → 视口 → _input／_unhandled_input），按下、隔 2 帧松开、再等 STEP_FRAMES 帧。
## 每步往 stderr 打 SMOKE_KEY=<键> scene=<当前场景>（stderr 不缓冲，闪退时已按完的步数也留得下），全部按完打 SMOKE_DONE scene=… 并退出（退出码 0）。不读写存档以外的东西；存档目录跟着 HOME 走，冒烟脚本给的是临时 HOME。

const ARG := "--smoke-keys="
const STEP_FRAMES := 30
const KEYS := {
	"accept": KEY_ENTER, "space": KEY_SPACE, "j": KEY_J, "z": KEY_Z,
	"cancel": KEY_ESCAPE, "x": KEY_X, "k": KEY_K,
	"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
}


## 命令行里的序列；没带参数返回空数组。
static func sequence(args: PackedStringArray) -> PackedStringArray:
	for a in args:
		if a.begins_with(ARG):
			return a.substr(ARG.length()).split(",", false)
	return PackedStringArray()


## 一步是否认得：键名或 wait:<非负整数>。
static func valid_step(step: String) -> bool:
	if step.begins_with("wait:"):
		return step.substr(5).is_valid_int() and int(step.substr(5)) >= 0
	return KEYS.has(step)


static func key_event(step: String, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEYS[step]
	e.physical_keycode = KEYS[step]
	e.pressed = pressed
	return e


var steps: PackedStringArray


func _ready() -> void:
	for s in steps:
		if not valid_step(s):
			push_error("--smoke-keys 认不出这一步：" + s)
			print("SMOKE_BAD_STEP=" + s)
			get_tree().quit(2)
			return
	_run.call_deferred()


func _scene() -> String:
	var cur := get_tree().current_scene
	return cur.scene_file_path if cur else "（切换中）"


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	await _wait(STEP_FRAMES)
	for s in steps:
		if s.begins_with("wait:"):
			await _wait(int(s.substr(5)))
			printerr("SMOKE_KEY=%s scene=%s" % [s, _scene()])
			continue
		Input.parse_input_event(key_event(s, true))
		await _wait(2)
		Input.parse_input_event(key_event(s, false))
		await _wait(STEP_FRAMES)
		printerr("SMOKE_KEY=%s scene=%s" % [s, _scene()])
	printerr("SMOKE_DONE scene=" + _scene())
	get_tree().quit(0)
