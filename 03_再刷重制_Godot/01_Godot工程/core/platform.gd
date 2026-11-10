class_name XPlatform
extends Node
## 平台差异集中在这里（跨平台适配二期，cc BH 2026-11-05；设计见 00_设计/跨平台适配.md）。
## GameApp 建一个挂在自己下面；别的文件要按平台分支时问这里，不直接 OS.has_feature。
## - 两指点按＝取消：照 MV TouchInput（第二指按下即 _onCancel，与鼠标右键同一路），这里转成一次右键点击；
##   第一指照 Godot 的触屏转鼠标（emulate_mouse_from_touch）当左键，第二指本身不再往下传，免得地图把它当成走路目标。
## - 返回键＝取消（原版 android-integration 的 AndroidPort.back 发 escape）；顶层（入口菜单、发行包的西游标题页）两秒内按两次退出（O-202）。
## - 切后台：松开虚拟按键；挂机中切后台、回来时按离开的时间补跑（O-201，BACKGROUND_IDLE）。
## - 挂机中手机不锁屏（原版要了 WAKE_LOCK）。
## - 切后台自动存档：调 pause_hook（西游地图挂 XAutoSave，O-215·安卓切后台存档）。

## 测试用：强制当成触屏／手机（null＝按真实平台）。
static var force_mobile = null
## O-201：安卓后台挂机。原版用前台服务在后台按真实时间继续跑；Godot 切后台主循环就停了，这里改成回到前台时
## 把离开的时间加速补跑（最多 BACKGROUND_CAP_SEC 秒游戏时间，CATCH_UP_SPEED 倍速，点屏幕可停）。false＝切后台就停，回来接着玩。
static var BACKGROUND_IDLE := true
const BACKGROUND_CAP_SEC := 1800.0
const CATCH_UP_SPEED := 8
## 离开不到这么久不补跑（切出去看一眼消息）。
const CATCH_UP_MIN_SEC := 5.0
## O-248 安卓后台挂机前台服务（Kyo 2026-11-09 定 C，cc 平台 android-bgidle1）：照原版，挂机中切后台起前台服务
## （安卓插件 XiyouBgIdle：通知栏常驻计时、点通知回游戏、「停止挂机」按钮），进程不被系统杀掉。Godot 切后台渲染表面被收走、
## 主循环照样停，所以离开的时间仍在回前台时补跑：按真实离开时间（含锁屏睡眠；按了停止只算到按的那一刻），上限 SERVICE_CAP_SEC；
## 按过停止的，补完就结束挂机（idle_stopper）。false＝回到 O-201：不起服务，离开时间按游戏计时、最多 BACKGROUND_CAP_SEC。
## 没有插件（桌面、非 Gradle 包、插件没编进去）时自动走 O-201。
static var BACKGROUND_SERVICE := true
## 有前台服务时补跑上限（游戏秒；CATCH_UP_SPEED 倍速下 4 小时补 30 分钟）。
static var SERVICE_CAP_SEC := 14400.0
## 测试用：替身插件（有 setArmed／lastAwayMsec／lastStoppedByUser／requestNotificationPermission）；null＝安卓上找 XiyouBgIdle 单例。
static var bg_service_override = null

## 挂机是否进行中：GameApp 不认识各模式，由模式（西游地图）在 _ready 里设；没设当成没挂机。
static var idle_probe := Callable()
## 切后台时调一次（参数：当前毫秒）：西游地图挂上自动存档（XAutoSave）；离开地图失效。
static var pause_hook := Callable()
## 结束挂机（通知上按了「停止挂机」、补跑完后调）：西游地图设成 XHangUp.stop；没设就只停补跑。
static var idle_stopper := Callable()

signal virtual_keys_release_requested
signal catch_up_changed(active: bool)

var _paused_at_msec := -1
var _paused_idle := false
var _catch_up_left := 0.0
## 补跑中（平台 EH，Codex 报告第 6 项）：活动与否单独记，不拿剩余秒数判断——自然耗尽时剩余先减到 0 以下，
## 旧代码 stop 以为没在补跑、直接返回，倍速一直不恢复。
var _catch_up_active := false
var _saved_engine := {}
var _keep_on := false
## 已告诉插件「挂机中」（切后台就起服务）
var _service_armed := false
var _notify_asked := false
## 这次补跑完要结束挂机（通知上按过停止）
var _stop_idle_after := false
## 冒烟用（安卓实机冒烟.py）：启动参数 --smoke-arm-bgidle＝不挂机也让插件切后台起服务
var _force_arm := false


static func is_mobile() -> bool:
	if force_mobile != null:
		return bool(force_mobile)
	return OS.has_feature("mobile")

static func is_android() -> bool:
	return OS.has_feature("android")


## 测试用：假装屏幕的安全区（屏幕像素）；size 为 0＝按真实 DisplayServer。
static var safe_area_override := Rect2i()


## 刘海／圆角安全区换成画面坐标（1280×720）后，四边各缩进多少（左、上、右、下；不缩是 0）。
## 画面按 canvas_items＋keep 留黑边，安全区落在黑边里的部分不算；没有安全区信息（桌面、headless）时全是 0。
static func safe_insets(viewport: Viewport) -> Array:
	var safe := safe_area_override if safe_area_override.size != Vector2i.ZERO else DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0 or viewport == null:
		return [0.0, 0.0, 0.0, 0.0]
	var win := Vector2(DisplayServer.window_get_position()) if safe_area_override.size == Vector2i.ZERO else Vector2.ZERO
	var inv := viewport.get_final_transform().affine_inverse()
	var a := inv * (Vector2(safe.position) - win)
	var b := inv * (Vector2(safe.end) - win)
	var size := viewport.get_visible_rect().size
	return [maxf(0, a.x), maxf(0, a.y), maxf(0, size.x - b.x), maxf(0, size.y - b.y)]

## 触屏设备（显示虚拟按键）。
static func is_touch() -> bool:
	if force_mobile != null:
		return bool(force_mobile)
	return is_mobile() and DisplayServer.is_touchscreen_available()

static func idle_active() -> bool:
	return idle_probe.is_valid() and bool(idle_probe.call())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_force_arm = OS.get_cmdline_user_args().has("--smoke-arm-bgidle")
	if is_mobile():
		get_tree().quit_on_go_back = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index >= 1:
		XKeyMap.handled(self)
		if event.pressed:
			two_finger_cancel((event as InputEventScreenTouch).position)
		return
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index >= 1:
		XKeyMap.handled(self)
		return
	if is_catching_up() and (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		stop_catch_up()
		XKeyMap.handled(self)


## 两指点按：把第一指正按着的左键挪出画面（按钮松开时就不算点中），再在第一指处点一下右键。
func two_finger_cancel(at: Vector2) -> void:
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-10000, -10000)
	away.global_position = away.position
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(away)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED:
			on_paused()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# 安卓切后台时 FOCUS_OUT 和 PAUSED 都会来、先后不定；只给切后台存档用，桌面切窗口不算
			if is_mobile():
				_call_pause_hook(Time.get_ticks_msec())
		NOTIFICATION_APPLICATION_RESUMED:
			on_resumed()


## O-202：顶层（入口菜单；发行包跳过入口菜单时的西游标题页）按返回键，第一次提示「再按一次返回键退出」，
## 两秒内再按就退出。原版 MainActivity.onBackPressed 只执行 AndroidPort.back()（发 Esc），MV 标题不响应 Esc，
## 所以在标题上按返回没反应、也不退出（cc 2026-11-05 dexdump 看过）。false＝回到原版：顶层也只当取消键。
static var BACK_EXIT_ON_TOP := true
const BACK_EXIT_WINDOW_MSEC := 2000
const XIYOU_TITLE := "res://modes/xiyou/entry.tscn"
## 测试关掉，免得真的退出。
var quit_on_back := true
var _last_back_msec := -100000
var _hint: Label

signal quit_requested


## 返回键到了顶层：入口菜单；或发行包跳过了入口菜单，且西游标题停在标题页（不在读档、设置子页）。
func is_top_level(scene: Node = null) -> bool:
	if scene == null:
		scene = get_tree().current_scene
	if scene == null:
		return false
	if scene.scene_file_path == "res://scenes/entry_menu.tscn":
		return true
	return ReleaseEntry.skips_menu() and scene.scene_file_path == XIYOU_TITLE \
		and scene.has_method("is_title_page") and bool(scene.call("is_title_page"))


## 返回键。返回做了什么（测试看）："quit" 退出、"hint" 提示再按一次、"cancel" 当取消键。
func go_back(now_msec := Time.get_ticks_msec(), scene: Node = null) -> String:
	virtual_keys_release_requested.emit()
	var touch := get_node_or_null("TouchControls") as XTouchControls
	if touch != null and touch.layout_editing:  # 原版：调位置时返回键＝完成
		touch.finish_layout()
		return "layout"
	if BACK_EXIT_ON_TOP and is_top_level(scene):
		if now_msec - _last_back_msec <= BACK_EXIT_WINDOW_MSEC:
			_last_back_msec = -100000
			quit_requested.emit()
			if quit_on_back:
				get_tree().quit()
			return "quit"
		_last_back_msec = now_msec
		_show_hint("再按一次返回键退出")
		return "hint"
	_last_back_msec = -100000
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = "ui_cancel"
		e.pressed = pressed
		Input.parse_input_event(e)
	return "cancel"


func _show_hint(text: String) -> void:
	if _hint == null:
		var layer := CanvasLayer.new()
		layer.layer = 125
		add_child(layer)
		_hint = Label.new()
		_hint.position = Vector2(440, 620)
		_hint.size = Vector2(400, 40)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_font_size_override("font_size", 20)
		_hint.add_theme_color_override("font_color", Color(1, 1, 1))
		_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_hint.add_theme_constant_override("outline_size", 6)
		layer.add_child(_hint)
	_hint.text = text
	_hint.visible = true
	get_tree().create_timer(BACK_EXIT_WINDOW_MSEC / 1000.0, true, false, true).timeout.connect(func(): _hint.visible = false)


func hint_text() -> String:
	return _hint.text if _hint != null and _hint.visible else ""


func on_paused(now_msec := Time.get_ticks_msec()) -> void:
	virtual_keys_release_requested.emit()
	_paused_at_msec = now_msec
	_paused_idle = idle_active()
	_call_pause_hook(now_msec)


func _call_pause_hook(now_msec: int) -> void:
	if pause_hook.is_valid():
		pause_hook.call(now_msec)


## 回到前台。返回补跑的游戏秒数（0＝不补跑）。
func on_resumed(now_msec := Time.get_ticks_msec()) -> float:
	var away := (now_msec - _paused_at_msec) / 1000.0 if _paused_at_msec >= 0 else 0.0
	_paused_at_msec = -1
	var was_idle := _paused_idle
	_paused_idle = false
	# 前台服务陪着的这次离开：用插件量的真实时间（Time.get_ticks_msec 不算锁屏睡眠）
	var svc_away := service_away_sec()
	var stopped := svc_away >= 0.0 and bool(bg_service().lastStoppedByUser())
	if svc_away >= 0.0:
		away = svc_away
	if not BACKGROUND_IDLE or not was_idle or not idle_active():
		return 0.0
	if away < CATCH_UP_MIN_SEC:
		if stopped:
			_stop_idle()
		return 0.0
	var seconds := minf(away, SERVICE_CAP_SEC if svc_away >= 0.0 else BACKGROUND_CAP_SEC)
	start_catch_up(seconds)
	_stop_idle_after = stopped
	return seconds


## 后台挂机插件；没有（桌面、插件没编进包）是 null。
func bg_service():
	if bg_service_override != null:
		return bg_service_override
	if is_android() and Engine.has_singleton("XiyouBgIdle"):
		return Engine.get_singleton("XiyouBgIdle")
	return null


## 上一次由前台服务陪着的离开秒数；-1＝没起服务（没挂机、插件没有、BACKGROUND_SERVICE 关着、起服务失败）。
func service_away_sec() -> float:
	var svc = bg_service()
	if svc == null or not BACKGROUND_SERVICE:
		return -1.0
	var ms := int(svc.lastAwayMsec())
	return ms / 1000.0 if ms >= 0 else -1.0


func service_armed() -> bool:
	return _service_armed


## 挂机中就告诉插件「切后台时起服务」；切后台的瞬间（活动 onPause）GDScript 已经跑不到，只能提前设好。
## 第一次挂机时顺带申请通知权限（安卓 13+；不给也能起服务，只是看不到通知）。
func _sync_service_arm() -> void:
	var svc = bg_service()
	var want := svc != null and BACKGROUND_IDLE and BACKGROUND_SERVICE and (idle_active() or _force_arm)
	if want == _service_armed:
		return
	_service_armed = want
	if svc == null:
		return
	svc.setArmed(want)
	if _force_arm:
		print("BGIDLE_ARMED=%s" % want)
	if want and not _notify_asked:
		_notify_asked = true
		svc.requestNotificationPermission()


func _stop_idle() -> void:
	_stop_idle_after = false
	if idle_stopper.is_valid() and idle_active():
		idle_stopper.call()


func is_catching_up() -> bool:
	return _catch_up_active


## 按 CATCH_UP_SPEED 倍速跑 seconds 秒游戏时间（物理帧率、time_scale 一起乘，同测试快进的做法）。
func start_catch_up(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if not is_catching_up():
		_saved_engine = {"tps": Engine.physics_ticks_per_second, "steps": Engine.max_physics_steps_per_frame, "scale": Engine.time_scale}
		# 相对入口设好的基准倍率（变速齿轮 XSpeedGear 1.6 时是 96 帧／1.6 倍）再乘 CATCH_UP_SPEED，停下回到这个基准，不写死 1 倍
		Engine.physics_ticks_per_second = int(_saved_engine.tps) * CATCH_UP_SPEED
		Engine.max_physics_steps_per_frame = int(_saved_engine.steps) * CATCH_UP_SPEED
		Engine.time_scale = float(_saved_engine.scale) * CATCH_UP_SPEED
		_catch_up_active = true
		catch_up_changed.emit(true)
	_catch_up_left = seconds


func stop_catch_up() -> void:
	if not is_catching_up():
		return
	_catch_up_active = false
	_catch_up_left = 0.0
	Engine.physics_ticks_per_second = int(_saved_engine.get("tps", 60))
	Engine.max_physics_steps_per_frame = int(_saved_engine.get("steps", 8))
	Engine.time_scale = float(_saved_engine.get("scale", 1.0))
	catch_up_changed.emit(false)
	if _stop_idle_after:
		_stop_idle()


func catch_up_left() -> float:
	return _catch_up_left


func _process(delta: float) -> void:
	# delta 已乘 time_scale（基准×CATCH_UP_SPEED）；按「平常速度下的秒数」扣：除以基准倍率。
	# 变速齿轮 1.6 时 delta 含 1.6，直接扣会只补离开时长的 1/1.6（界面车道 FD 发现，cc 平台 FB 2026-11-07 修）
	if is_catching_up():
		_catch_up_left -= delta / maxf(float(_saved_engine.get("scale", 1.0)), 0.001)
		if _catch_up_left <= 0.0 or not idle_active():
			stop_catch_up()
	_sync_service_arm()
	var want_on := is_mobile() and idle_active()
	if want_on != _keep_on:
		_keep_on = want_on
		DisplayServer.screen_set_keep_on(want_on)
