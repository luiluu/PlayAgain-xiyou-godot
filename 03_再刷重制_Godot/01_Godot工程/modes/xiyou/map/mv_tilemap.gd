class_name MVTilemap
extends Node2D
## 绘制一层 MV 地图图块（upper=false 为角色下方，true 为星号图块等角色上方）。
## 拼图规则移植自 rpg_core.js Tilemap._paintTiles/_drawTile/_drawAutotile/_drawTableEdge/_drawShadow。
## A1 水面每 30 帧换一帧（与 MV 相同），只有含 A1 图块的层会重绘。
## 循环地图（MV scrollType 1 纵向、2 横向、3 双向；正式版只有十四层 Map030 横向循环）：通行与移动照
## Game_Map.roundX/roundY/deltaX，绘制时在循环方向两侧多画一屏（Tilemap 的 horizontalWrap/verticalWrap）。

const TS := MVTiles.TILE_SIZE
const HALF := TS / 2

var map: Dictionary
var flags: Array = []
var sheets: Array = []          # 9 张：A1 A2 A3 A4 A5 B C D E
var upper := false
var anim_frame := 0
var _has_a1 := false
var _tick := 0
var width := 0
var height := 0
var data: Array = []
var loop_x := false
var loop_y := false
## 循环方向两侧多画的格数：画面 1280×720 ÷ 48 向上取整再加 1
const LOOP_MARGIN := Vector2i(28, 16)
## 循环地图上角色的显示位置取离这一点（玩家的 real）最近的那一份，同 Game_Map.adjustX/adjustY
var view_anchor := Vector2.ZERO


func setup(map_data: Dictionary, upper_layer: bool) -> void:
	map = map_data
	upper = upper_layer
	width = int(map.width)
	height = int(map.height)
	data = map.data
	var scroll := int(map.get("scrollType", 0))
	loop_x = scroll == 2 or scroll == 3
	loop_y = scroll == 1 or scroll == 3
	var ts := XDB.rec("Tilesets", int(map.tilesetId))
	flags = ts.flags
	sheets.clear()
	for name in ts.tilesetNames:
		var p := XDB.img_path("tilesets", str(name)) if str(name) != "" else ""
		sheets.append(load(p) if p != "" else null)
	for i in range(width * height * 4):
		if MVTiles.is_a1(int(data[i])):
			_has_a1 = true
			break
	queue_redraw()


func _process(_delta: float) -> void:
	if not _has_a1:
		return
	_tick += 1
	if _tick % 30 == 0:
		anim_frame += 1
		queue_redraw()


func tile(x: int, y: int, z: int) -> int:
	if loop_x:
		x = posmod(x, width)
	if loop_y:
		y = posmod(y, height)
	if x < 0 or y < 0 or x >= width or y >= height:
		return 0
	return int(data[(z * height + y) * width + x])

func _flag(id: int) -> int:
	return int(flags[id]) if id >= 0 and id < flags.size() else 0

func _is_higher(id: int) -> bool:
	return _flag(id) & 0x10 != 0

func _is_table(id: int) -> bool:
	return MVTiles.is_a2(id) and _flag(id) & 0x80 != 0


func _draw() -> void:
	var mx := LOOP_MARGIN.x if loop_x else 0
	var my := LOOP_MARGIN.y if loop_y else 0
	for y in range(-my, height + my):
		for x in range(-mx, width + mx):
			var dx := x * TS
			var dy := y * TS
			for id in _tiles_at(x, y):
				if id < 0:
					_draw_shadow(-id, dx, dy)
				elif id >= 10000:
					_draw_table_edge(id - 10000, dx, dy)
				else:
					_draw_tile(id, dx, dy)


func _tiles_at(x: int, y: int) -> Array:
	var t0 := tile(x, y, 0)
	var t1 := tile(x, y, 1)
	var t2 := tile(x, y, 2)
	var t3 := tile(x, y, 3)
	var shadow := tile(x, y, 4)
	var upper_t1 := tile(x, y - 1, 1)
	var lower := []
	var up := []
	(up if _is_higher(t0) else lower).append(t0)
	(up if _is_higher(t1) else lower).append(t1)
	lower.append(-shadow)
	if _is_table(upper_t1) and not _is_table(t1) and not MVTiles.is_shadowing(t0):
		lower.append(10000 + upper_t1)
	(up if _is_higher(t2) else lower).append(t2)
	(up if _is_higher(t3) else lower).append(t3)
	return up if upper else lower


func _draw_tile(id: int, dx: int, dy: int) -> void:
	if not MVTiles.is_visible(id):
		return
	if MVTiles.is_autotile(id):
		_draw_autotile(id, dx, dy)
	else:
		_draw_normal(id, dx, dy)


func _draw_normal(id: int, dx: int, dy: int) -> void:
	var set_number := 4 if MVTiles.is_a5(id) else 5 + floori(id / 256.0)
	var tex: Texture2D = sheets[set_number] if set_number < sheets.size() else null
	if tex == null:
		return
	var sx := (floori(id / 128.0) % 2 * 8 + id % 8) * TS
	var sy := (floori(id % 256 / 8.0) % 16) * TS
	draw_texture_rect_region(tex, Rect2(dx, dy, TS, TS), Rect2(sx, sy, TS, TS))


func _draw_autotile(id: int, dx: int, dy: int) -> void:
	var table_set: Array = MVTiles.FLOOR_AUTOTILE_TABLE
	var kind := MVTiles.autotile_kind(id)
	var shape := MVTiles.autotile_shape(id)
	var tx := kind % 8
	var ty := floori(kind / 8.0)
	var bx := 0
	var by := 0
	var set_number := 0
	var is_table := false
	if MVTiles.is_a1(id):
		var wave: int = [0, 1, 2, 1][anim_frame % 4]
		set_number = 0
		if kind == 0:
			bx = wave * 2
		elif kind == 1:
			bx = wave * 2
			by = 3
		elif kind == 2:
			bx = 6
		elif kind == 3:
			bx = 6
			by = 3
		else:
			bx = floori(tx / 4.0) * 8
			by = ty * 6 + floori(tx / 2.0) % 2 * 3
			if kind % 2 == 0:
				bx += wave * 2
			else:
				bx += 6
				table_set = MVTiles.WATERFALL_AUTOTILE_TABLE
				by += anim_frame % 3
	elif MVTiles.is_a2(id):
		set_number = 1
		bx = tx * 2
		by = (ty - 2) * 3
		is_table = _is_table(id)
	elif MVTiles.is_a3(id):
		set_number = 2
		bx = tx * 2
		by = (ty - 6) * 2
		table_set = MVTiles.WALL_AUTOTILE_TABLE
	elif MVTiles.is_a4(id):
		set_number = 3
		bx = tx * 2
		by = floori((ty - 10) * 2.5 + (0.5 if ty % 2 == 1 else 0.0))
		if ty % 2 == 1:
			table_set = MVTiles.WALL_AUTOTILE_TABLE
	if shape >= table_set.size():
		return
	var tex: Texture2D = sheets[set_number]
	if tex == null:
		return
	var table: Array = table_set[shape]
	for i in range(4):
		var qsx: int = table[i][0]
		var qsy: int = table[i][1]
		var sx1 := (bx * 2 + qsx) * HALF
		var sy1 := (by * 2 + qsy) * HALF
		var dx1 := dx + (i % 2) * HALF
		var dy1 := dy + floori(i / 2.0) * HALF
		if is_table and (qsy == 1 or qsy == 5):
			var qsx2 := qsx
			if qsy == 1:
				qsx2 = [0, 3, 2, 1][qsx]
			var sx2 := (bx * 2 + qsx2) * HALF
			var sy2 := (by * 2 + 3) * HALF
			draw_texture_rect_region(tex, Rect2(dx1, dy1, HALF, HALF), Rect2(sx2, sy2, HALF, HALF))
			draw_texture_rect_region(tex, Rect2(dx1, dy1 + HALF / 2.0, HALF, HALF / 2.0), Rect2(sx1, sy1, HALF, HALF / 2.0))
		else:
			draw_texture_rect_region(tex, Rect2(dx1, dy1, HALF, HALF), Rect2(sx1, sy1, HALF, HALF))


func _draw_table_edge(id: int, dx: int, dy: int) -> void:
	if not MVTiles.is_a2(id):
		return
	var kind := MVTiles.autotile_kind(id)
	var shape := MVTiles.autotile_shape(id)
	var bx := (kind % 8) * 2
	var by := (floori(kind / 8.0) - 2) * 3
	var table: Array = MVTiles.FLOOR_AUTOTILE_TABLE[shape]
	var tex: Texture2D = sheets[1]
	if tex == null:
		return
	for i in range(2):
		var qsx: int = table[2 + i][0]
		var qsy: int = table[2 + i][1]
		var sx1 := (bx * 2 + qsx) * HALF
		var sy1 := (by * 2 + qsy) * HALF + HALF / 2.0
		draw_texture_rect_region(tex, Rect2(dx + (i % 2) * HALF, dy, HALF, HALF / 2.0), Rect2(sx1, sy1, HALF, HALF / 2.0))


func _draw_shadow(bits: int, dx: int, dy: int) -> void:
	if bits & 0x0f == 0:
		return
	for i in range(4):
		if bits & (1 << i):
			draw_rect(Rect2(dx + (i % 2) * HALF, dy + floori(i / 2.0) * HALF, HALF, HALF), Color(0, 0, 0, 0.5))


# ---- 循环（MV Game_Map.roundX/roundY/isValid/deltaX/deltaY）----
func round_cell(c: Vector2i) -> Vector2i:
	return Vector2i(posmod(c.x, width) if loop_x else c.x, posmod(c.y, height) if loop_y else c.y)

func is_valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height

## a − b，循环方向取较短的一边
func delta(a: Vector2i, b: Vector2i) -> Vector2i:
	var r := a - b
	if loop_x and absi(r.x) > width / 2:
		r.x += width if r.x < 0 else -width
	if loop_y and absi(r.y) > height / 2:
		r.y += height if r.y < 0 else -height
	return r

## 角色显示位置的平移（以格计）：循环方向取离 view_anchor 最近的那一份
func loop_shift(real: Vector2) -> Vector2:
	var sx := roundf((view_anchor.x - real.x) / width) * width if loop_x else 0.0
	var sy := roundf((view_anchor.y - real.y) / height) * height if loop_y else 0.0
	return Vector2(sx, sy)


# ---- 通行（MV Game_Map.checkPassage）----
## 图块事件（Game_Map.tileEventsXy：当前页图像是图块、优先级「角色下方」的事件）：(x, y) -> 图块编号数组。
## 地图场景设为本图上的事件；不设时只看地图图块。
var tile_events: Callable

## d 为方向 2/4/6/8；返回该格朝 d 方向能否离开/进入。设置「穿墙开关」开着时一律可通行（地图外仍不行，MV canPass 先查 isValid）。
func is_passable(x: int, y: int, d: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	if XConfig.flag("cq"):
		return true
	var bit := (1 << (d / 2 - 1)) & 0x0f
	# Game_Map.checkPassage 查 allTiles：图块事件的图块排在第 4～1 层之前
	var ids: Array = tile_events.call(x, y) if tile_events.is_valid() else []
	ids.append_array([tile(x, y, 3), tile(x, y, 2), tile(x, y, 1), tile(x, y, 0)])
	for id in ids:
		var flag := _flag(id)
		if flag & 0x10 != 0:
			continue
		if flag & bit == 0:
			return true
		if flag & bit == bit:
			return false
	return false

## MV Game_Map.isBush：四层图块任一有草丛标记 0x40
func is_bush(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	for z in [3, 2, 1, 0]:
		if _flag(tile(x, y, z)) & 0x40 != 0:
			return true
	return false

## 区域 ID（第 6 层）
func region(x: int, y: int) -> int:
	return tile(x, y, 5)
