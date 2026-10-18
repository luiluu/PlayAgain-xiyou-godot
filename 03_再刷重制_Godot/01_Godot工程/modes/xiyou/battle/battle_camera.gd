class_name XBattleCamera
extends RefCounted
## YEP_X_ActSeqPack3 战斗镜头：BattleManager 的镜头点（_cameraX/Y、聚焦组、偏移、夹边）与 $gameScreen 的
## _zoomX/_zoomY/_zoomScale。每帧 update() 照 Game_Screen.update（先 updateZoom，再 updateBattleCamera）：
## 镜头点与缩放都按剩余帧数线性逼近（v ×(d−1)/d + 目标/d）。screen_offset() 照 Spriteset_Battle.updatePosition。
## 镜头命令受设置「Battle Camera」控制（关时镜头命令直接跳过，RESET CAMERA/RESET ZOOM 照常）。

const BOX := Vector2(1280, 720)

var sprites: Dictionary            # XBattler -> XBattlerSprite（取位置、帧大小、浮空跳跃）
var x := BOX.x / 2.0                # $gameScreen._zoomX
var y := BOX.y / 2.0
var scale := 1.0                    # _zoomScale
var scale_target := 1.0
var zoom_dur := 0
var cam_dur := 0
var cam_x := BOX.x / 2.0            # BattleManager._cameraX
var cam_y := BOX.y / 2.0
var off_x := 0.0
var off_y := 0.0
var focus: Array = []
var focus_x := "BASE"
var focus_y := "BASE"
var clamp_on := true


func reset(duration: int) -> void:
	cam_x = BOX.x / 2.0
	cam_y = BOX.y / 2.0
	off_x = 0.0
	off_y = 0.0
	focus = []
	focus_x = "BASE"
	focus_y = "BASE"
	clamp_on = true
	cam_dur = duration


func zoom_to(s: float, duration: int) -> void:
	scale_target = s
	zoom_dur = duration


func is_zooming() -> bool:
	return zoom_dur > 0


func is_panning() -> bool:
	return cam_dur > 0


## 有镜头变化（不在初始状态）
func active() -> bool:
	return scale != 1.0 or zoom_dur > 0 or cam_dur > 0 or not is_equal_approx(x, BOX.x / 2.0) or not is_equal_approx(y, BOX.y / 2.0)


func update() -> void:
	if zoom_dur > 0:
		scale = (scale * (zoom_dur - 1) + scale_target) / zoom_dur
		zoom_dur -= 1
	var tx := camera_x()
	var ty := camera_y()
	if cam_dur > 0:
		x = (x * (cam_dur - 1) + tx) / cam_dur
		y = (y * (cam_dur - 1) + ty) / cam_dur
		cam_dur -= 1
	else:
		x = tx
		y = ty


func camera_x() -> float:
	return (target_pos_x(focus, focus_x) if not focus.is_empty() else cam_x) + off_x


func camera_y() -> float:
	return (target_pos_y(focus, focus_y) if not focus.is_empty() else cam_y) + off_y


## 场景层位置（Spriteset_Battle.updatePosition，不含震屏）；Math.round 的 .5 向正无穷取整
func screen_offset() -> Vector2:
	var sx := -x * scale + BOX.x / 2.0
	var sy := -y * scale + BOX.y / 2.0
	if clamp_on and scale >= 1.0:
		return Vector2(_round(clampf(sx, BOX.x - BOX.x * scale, 0.0)), _round(clampf(sy, BOX.y - BOX.y * scale, 0.0)))
	if clamp_on:
		return Vector2(_round((BOX.x - BOX.x * scale) / 2.0), _round((BOX.y - BOX.y * scale) / 2.0))
	return Vector2(_round(sx), _round(sy))


static func _round(v: float) -> float:
	return floorf(v + 0.5)


# ---- BattleManager.targetPosX/Y 与 Game_Battler.cameraPosX/Y ----
func _sp(b: XBattler) -> XBattlerSprite:
	return sprites.get(b)


func pos_x(b: XBattler) -> float:
	var sp := _sp(b)
	return sp.position.x if sp else 0.0


## cameraPosY：脚底 y 减去浮空、跳跃的高度（取浮空高度会让它再走一步，同正式版）
func pos_y(b: XBattler) -> float:
	var sp := _sp(b)
	if sp == null:
		return 0.0
	var h := sp.frame_size().y
	return sp.position.y - sp.float_step() * h - sp.jump_height() * h


func target_pos_x(group: Array, position: String) -> float:
	var value := 0.0
	if group.is_empty():
		return 0.0
	match position:
		"MIDDLE":
			for b in group:
				value += pos_x(b)
		"FRONT":
			for b in group:
				var w: float = _sp(b).frame_size().x if _sp(b) else 1.0
				value = maxf(pos_x(b) + (-w / 2.0 if b is XActor else w / 2.0), value)
			value *= group.size()
		"BACK":
			value = BOX.x
			for b in group:
				var w: float = _sp(b).frame_size().x if _sp(b) else 1.0
				value = minf(pos_x(b) + (w / 2.0 if b is XActor else -w / 2.0), value)
			value *= group.size()
	return value / group.size()


func target_pos_y(group: Array, position: String) -> float:
	var value := 0.0
	if group.is_empty():
		return 0.0
	match position:
		"BASE":
			for b in group:
				value = maxf(pos_y(b), value)
			value *= group.size()
		"MIDDLE":
			for b in group:
				var h: float = _sp(b).frame_size().y if _sp(b) else 1.0
				value += pos_y(b) - h / 2.0
		"TOP":
			value = BOX.y
			for b in group:
				var h: float = _sp(b).frame_size().y if _sp(b) else 1.0
				value = minf(pos_y(b) - h, value)
			value *= group.size()
	return value / group.size()


## actionCameraFocus 的位置写法 → [X 位置, Y 位置]
static func focus_type(type: String) -> Array:
	match type:
		"FRONT BASE", "FRONT FOOT", "FRONT FEET": return ["FRONT", "BASE"]
		"BASE", "FOOT", "FEET": return ["MIDDLE", "BASE"]
		"BACK BASE", "BACK FOOT", "BACK FEET": return ["BACK", "BASE"]
		"FRONT CENTER", "FRONT MIDDLE", "FRONT": return ["FRONT", "MIDDLE"]
		"CENTER", "MIDDLE": return ["MIDDLE", "MIDDLE"]
		"BACK CENTER", "BACK MIDDLE", "BACK": return ["BACK", "MIDDLE"]
		"FRONT HEAD", "FRONT TOP": return ["FRONT", "TOP"]
		"HEAD", "TOP": return ["MIDDLE", "TOP"]
		"BACK HEAD", "BACK TOP": return ["BACK", "TOP"]
	return ["MIDDLE", "MIDDLE"]
