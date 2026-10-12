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
	if is_moving():
		var dist := distance_per_frame()
		real.x = move_toward(real.x, grid.x, dist)
		real.y = move_toward(real.y, grid.y, dist)
		_sync_position()
	_update_animation()

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
	position = Vector2(real.x * TS + TS / 2.0, real.y * TS + TS)
	z_index = (0 if priority_type == 1 else (-1 if priority_type == 0 else 1))
	queue_redraw()


func _draw() -> void:
	if transparent or opacity <= 0:
		return
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
