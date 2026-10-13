class_name MVCharacter
extends Node2D
## 地图上的角色（玩家与事件共用），移植 MV Game_CharacterBase 的格子移动、行走图与动画规则。
## 行走图：文件名带 $ 为单人图（3×4 帧），否则一张 8 人（每人 3×4 帧）；带 ! 的物件不上移 6 像素。

const TS := MVTiles.TILE_SIZE

var grid := Vector2i.ZERO
var real := Vector2.ZERO           # 以格为单位的实际位置（移动中为小数）
var direction := 2
var move_speed := 4                # MV 1..6，4 为标准
var move_frequency := 3
var pattern := 1
var through := false
var priority_type := 1             # 0 角色下方 1 同层 2 角色上方
var walk_anime := true
var step_anime := false
var direction_fix := false
var transparent := false
var character_name := ""
var character_index := 0
var tile_id := 0
var opacity := 255
var _tex: Texture2D
var _anime_count := 0.0
var _stop_count := 0
var tilemap: MVTilemap
## 移动路线（Game_Character.forceMoveRoute / updateRoutineMove）
var _route: Dictionary = {}
var _route_index := 0
var _route_wait := 0
var _route_forcing := false
var _route_ok := true
## 跳跃（Game_CharacterBase.jump / updateJump）
var _jump_peak := 0
var _jump_count := 0
## 气泡（Sprite_Balloon：8 帧 × 速度 8 ＋ 停留 12 帧，图 Balloon.png 每格 48）
var balloon_id := 0
var _balloon_t := 0
static var _balloon_tex: Texture2D


func set_image(name: String, index: int) -> void:
	character_name = name
	character_index = index
	tile_id = 0
	var p := XDB.img_path("characters", name) if name != "" else ""
	_tex = load(p) if p != "" else null
	queue_redraw()

func set_tile_image(id: int) -> void:
	tile_id = id
	character_name = ""
	_tex = null
	queue_redraw()

func locate(x: int, y: int) -> void:
	grid = Vector2i(x, y)
	real = Vector2(x, y)
	_sync_position()

func is_big() -> bool:
	return character_name.begins_with("$") or character_name.begins_with("!$")

func is_object() -> bool:
	return character_name.begins_with("!")

func is_moving() -> bool:
	return not real.is_equal_approx(Vector2(grid))

func is_jumping() -> bool:
	return _jump_count > 0

func jump_height() -> float:
	return (_jump_peak * _jump_peak - pow(absf(_jump_count - _jump_peak), 2)) / 2.0

func distance_per_frame() -> float:
	return pow(2.0, move_speed) / 256.0

static func dir_offset(d: int) -> Vector2i:
	match d:
		2: return Vector2i(0, 1)
		4: return Vector2i(-1, 0)
		6: return Vector2i(1, 0)
		8: return Vector2i(0, -1)
	return Vector2i.ZERO

static func reverse_dir(d: int) -> int:
	return 10 - d


func set_direction(d: int) -> void:
	if not direction_fix and d > 0:
		direction = d
	queue_redraw()


## 能否朝 d 走一步：地图双向通行＋与其他同层角色碰撞（由地图场景提供 is_blocked）。
func can_pass(d: int) -> bool:
	var to := grid + dir_offset(d)
	if tilemap == null or to.x < 0 or to.y < 0 or to.x >= tilemap.width or to.y >= tilemap.height:
		return false
	if through:
		return true
	if not tilemap.is_passable(grid.x, grid.y, d) or not tilemap.is_passable(to.x, to.y, reverse_dir(d)):
		return false
	var scene = get_parent().get_parent() if get_parent() else null
	if scene and scene.has_method("is_blocked") and scene.is_blocked(to, self):
		return false
	return true

func move_straight(d: int) -> bool:
	set_direction(d)
	if can_pass(d):
		grid += dir_offset(d)
		return true
	return false


func _physics_process(_delta: float) -> void:
	update_character()

func update_character() -> void:
	if not is_moving() and not is_jumping() and _route_forcing:
		_update_route()
	if is_jumping():
		_jump_count -= 1
		real.x = (real.x * _jump_count + grid.x) / (_jump_count + 1.0)
		real.y = (real.y * _jump_count + grid.y) / (_jump_count + 1.0)
		if _jump_count == 0:
			real = Vector2(grid)
		_sync_position()
	elif is_moving():
		var dist := distance_per_frame()
		real.x = move_toward(real.x, grid.x, dist)
		real.y = move_toward(real.y, grid.y, dist)
		_sync_position()
	_update_animation()
	if balloon_id > 0:
		_balloon_t -= 1
		if _balloon_t <= 0:
			balloon_id = 0
		queue_redraw()


# ---- 移动路线（MV Game_Character.processMoveCommand 的常用部分）----
func force_move_route(route: Dictionary) -> void:
	_route = route
	_route_index = 0
	_route_wait = 0
	_route_forcing = true

func is_route_forcing() -> bool:
	return _route_forcing

func _update_route() -> void:
	if _route_wait > 0:
		_route_wait -= 1
		return
	var list: Array = _route.get("list", [])
	_route_ok = true
	if _route_index >= list.size():
		_route_forcing = false
		return
	_process_move(list[_route_index])
	if _route_ok or bool(_route.get("skippable", false)):
		_route_index += 1
		if bool(_route.get("repeat", false)) and _route_index >= list.size() - 1:
			_route_index = 0

func _process_move(cmd: Dictionary) -> void:
	var p: Array = cmd.get("parameters", [])
	match int(cmd.get("code", 0)):
		0:
			if bool(_route.get("repeat", false)):
				_route_index = -1
			else:
				_route_forcing = false
		1, 2, 3, 4:
			_route_ok = move_straight([2, 4, 6, 8][int(cmd.code) - 1])
		12:
			_route_ok = move_straight(direction)
		13:
			var d := direction
			var fix := direction_fix
			direction_fix = true
			_route_ok = move_straight(reverse_dir(d))
			direction_fix = fix
		14:
			jump(int(p[0]), int(p[1]))
		15:
			_route_wait = int(p[0]) - 1
		16, 17, 18, 19:
			set_direction([2, 4, 6, 8][int(cmd.code) - 16])
		22:
			set_direction(reverse_dir(direction))
		29:
			move_speed = int(p[0])
		30:
			move_frequency = int(p[0])
		31, 32:
			walk_anime = int(cmd.code) == 31
		33, 34:
			step_anime = int(cmd.code) == 33
		35, 36:
			direction_fix = int(cmd.code) == 35
		37, 38:
			through = int(cmd.code) == 37
		39, 40:
			transparent = int(cmd.code) == 39
			queue_redraw()
		41:
			set_image(str(p[0]), int(p[1]))
		42:
			opacity = int(p[0])
			queue_redraw()
		44:
			var path := XDB.audio_path("se", str(p[0].get("name", ""))) if p.size() > 0 and p[0] is Dictionary else ""
			if path != "":
				var player := AudioStreamPlayer.new()
				player.stream = load(path)
				player.volume_db = linear_to_db(float(p[0].get("volume", 90)) / 100.0)
				player.pitch_scale = float(p[0].get("pitch", 100)) / 100.0
				add_child(player)
				player.play()
				player.finished.connect(player.queue_free)
		_:
			push_warning("移动路线指令 %d 尚未支持" % int(cmd.get("code", 0)))

## Game_CharacterBase.jump：朝位移方向转身，峰高 10 + 距离 − 速度，帧数为峰高的两倍
func jump(dx: int, dy: int) -> void:
	if absi(dx) > absi(dy):
		if dx != 0:
			set_direction(4 if dx < 0 else 6)
	elif dy != 0:
		set_direction(8 if dy < 0 else 2)
	grid += Vector2i(dx, dy)
	var distance := roundi(sqrt(dx * dx + dy * dy))
	_jump_peak = 10 + distance - move_speed
	_jump_count = _jump_peak * 2
	_stop_count = 0
	pattern = 1


# ---- 气泡 ----
func start_balloon(id: int) -> void:
	balloon_id = id
	_balloon_t = 8 * 8 + 12
	queue_redraw()

func is_balloon_playing() -> bool:
	return balloon_id > 0

func _update_animation() -> void:
	if is_moving() and walk_anime or step_anime:
		_anime_count += 1.5 if is_moving() else 1.0
	elif pattern != 1:
		_stop_count += 1
		if _stop_count > 6:
			pattern = 1
			_anime_count = 0
			queue_redraw()
	var wait := (9 - move_speed) * 3
	if _anime_count >= wait:
		_anime_count = 0
		_stop_count = 0
		pattern = (pattern + 1) % 4
		queue_redraw()

func _sync_position() -> void:
	position = Vector2(real.x * TS + TS / 2.0, real.y * TS + TS - (jump_height() if is_jumping() else 0.0))
	z_index = (0 if priority_type == 1 else (-1 if priority_type == 0 else 1))
	queue_redraw()


func _draw() -> void:
	if transparent or opacity <= 0:
		return
	_draw_body()
	if balloon_id > 0:
		_draw_balloon()


## 行走图高度（气泡、动画定位用）
func sprite_height() -> float:
	if tile_id > 0:
		return TS
	if _tex == null:
		return 0.0
	return _tex.get_height() / (4.0 if is_big() else 8.0)


## Sprite_Balloon：帧号 = 7 − floor((剩余 − 12) / 8)，画在角色头顶（行走图高度处）
func _draw_balloon() -> void:
	if _balloon_tex == null:
		var p := XDB.img_path("system", "Balloon")
		if p != "":
			_balloon_tex = load(p)
	if _balloon_tex == null:
		return
	var frame := 7 - maxi(floori((_balloon_t - 12) / 8.0), 0)
	var shift := 0.0 if is_object() else 6.0
	draw_texture_rect_region(_balloon_tex, Rect2(-24, -sprite_height() - shift - 48, 48, 48), Rect2(frame * 48, (balloon_id - 1) * 48, 48, 48))


func _draw_body() -> void:
	var mod := Color(1, 1, 1, opacity / 255.0)
	if tile_id > 0 and tilemap != null:
		_draw_tile_image(mod)
		return
	if _tex == null:
		return
	var pw: float = _tex.get_width() / (3.0 if is_big() else 12.0)
	var ph: float = _tex.get_height() / (4.0 if is_big() else 8.0)
	var block := Vector2.ZERO if is_big() else Vector2((character_index % 4) * 3 * pw, floori(character_index / 4.0) * 4 * ph)
	var pat: int = [0, 1, 2, 1][pattern % 4]
	var row := (direction - 2) / 2
	var src := Rect2(block.x + pat * pw, block.y + row * ph, pw, ph)
	var shift := 0.0 if is_object() else 6.0
	draw_texture_rect_region(_tex, Rect2(-pw / 2.0, -ph - shift, pw, ph), src, mod)

func _draw_tile_image(mod: Color) -> void:
	var set_number := 5 + floori(tile_id / 256.0)
	var tex: Texture2D = tilemap.sheets[set_number] if set_number < tilemap.sheets.size() else null
	if tex == null:
		return
	var sx := (floori(tile_id / 128.0) % 2 * 8 + tile_id % 8) * TS
	var sy := (floori(tile_id % 256 / 8.0) % 16) * TS
	draw_texture_rect_region(tex, Rect2(-TS / 2.0, -TS, TS, TS), Rect2(sx, sy, TS, TS), mod)
