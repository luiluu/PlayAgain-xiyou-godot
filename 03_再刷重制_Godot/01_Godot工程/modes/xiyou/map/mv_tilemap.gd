class_name MVTilemap
extends Node2D
## 绘制一层 MV 地图图块（upper=false 为角色下方，true 为星号图块等角色上方）。
## 拼图规则移植自 rpg_core.js Tilemap._paintTiles/_drawTile/_drawAutotile/_drawTableEdge/_drawShadow。
## A1 水面每 30 帧换一帧（与 MV 相同），只有含 A1 图块的层会重绘。
## 分块绘制（Codex 审查报告第 15 项）：原先整张图画在本节点上，换水面帧时整张重画；150×150 的天之上（Map069，A1 一万八千多格）
## 每 30 帧卡 300 毫秒左右（上下两层都重画）。现在按 CHUNK 格分块：每块一个静态节点（只画一次）和一个水面节点（只画含 A1 的格），
## 换水面帧时只重画画面内的水面节点，画面外的记脏、进画面时再画。同一格里水面节点画到最后一个 A1 图块为止，静态节点画其余，
## 格与格不重叠，所以叠放次序与整张画一样。回退开关 CHUNKED = false：回到整张画、整张重画。
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
static var CHUNKED := true
const CHUNK := 16
## 当前画到哪个 CanvasItem 上（整张画时是自己，分块时是块节点）
var _canvas: CanvasItem = self
## 分块：[{static, water, rect: Rect2i（格）, px: Rect2（像素）, dirty}]，water 为 null 表示这块没有水面
var _chunks: Array = []
var _water_chunks: Array = []
## 测试看：画过的格数（整张画与静态块算 drawn_cells，水面块算 water_cells）
var drawn_cells := 0
var water_cells := 0


class Part extends Node2D:
	var tm: MVTilemap
	var cells: Rect2i
	var water := false
	func _draw() -> void:
		tm._draw_part(self, cells, water)


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
	if CHUNKED:
		_build_chunks()
	else:
		queue_redraw()


func _build_chunks() -> void:
	for c in _chunks:
		c.static.queue_free()
		if c.water != null:
			c.water.queue_free()
	_chunks.clear()
	_water_chunks.clear()
	_hidden_left = 0
	var mx := LOOP_MARGIN.x if loop_x else 0
	var my := LOOP_MARGIN.y if loop_y else 0
	for cy in range(-my, height + my, CHUNK):
		for cx in range(-mx, width + mx, CHUNK):
			var r := Rect2i(cx, cy, mini(CHUNK, width + mx - cx), mini(CHUNK, height + my - cy))
			var has_water := false
			if _has_a1:
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						# 先看原始四层有没有 A1（便宜），有再按本层的绘制次序确认
						if (MVTiles.is_a1(tile(x, y, 0)) or MVTiles.is_a1(tile(x, y, 1)) or MVTiles.is_a1(tile(x, y, 2)) \
								or MVTiles.is_a1(tile(x, y, 3))) and _water_split(_tiles_at(x, y)) > 0:
							has_water = true
							break
					if has_water:
						break
			var c := {"rect": r, "px": Rect2(r.position * TS, r.size * TS), "dirty": false, "water": null}
			if has_water:
				c.water = _part(r, true)
			c.static = _part(r, false)
			# 画面外的块先不显示（不画），进画面时才第一次画；显示后就一直留着，不再重画
			c.static.visible = false
			if c.water != null:
				c.water.visible = false
			_chunks.append(c)
			_hidden_left += 1
			if has_water:
				_water_chunks.append(c)


## 进画面的块显示出来（第一次显示时画）
var _hidden_left := 0
func _reveal_chunks() -> void:
	if _hidden_left == 0:
		return
	var view := view_rect()
	for c in _chunks:
		if not (c.static as Part).visible and view.intersects(c.px):
			c.static.visible = true
			if c.water != null:
				c.water.visible = true
				c.dirty = false
			_hidden_left -= 1


func _part(r: Rect2i, water: bool) -> Part:
	var p := Part.new()
	p.tm = self
	p.cells = r
	p.water = water
	add_child(p)
	return p


## 一格的图块里，水面节点要画的前几个（到最后一个 A1 为止）；0＝这格没有水面
static func _water_split(ids: Array) -> int:
	for i in range(ids.size() - 1, -1, -1):
		var id: int = ids[i]
		if id > 0 and id < 10000 and MVTiles.is_a1(id):
			return i + 1
	return 0


func _draw_part(part: Part, r: Rect2i, water: bool) -> void:
	_canvas = part
	if water:
		water_cells += r.size.x * r.size.y
	else:
		drawn_cells += r.size.x * r.size.y
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ids := _tiles_at(x, y)
			var split := _water_split(ids) if _has_a1 else 0
			var from := 0 if water else split
			var to := split if water else ids.size()
			for i in range(from, to):
				_draw_id(ids[i], x * TS, y * TS)
	_canvas = self


## 画面在本节点坐标里的范围（多留一格）
func view_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	var r: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	return r.grow(TS)


func _process(_delta: float) -> void:
	if not _chunks.is_empty():
		_reveal_chunks()
	if not _has_a1:
		return
	_tick += 1
	var turn := _tick % 30 == 0
	if turn:
		anim_frame += 1
	if not CHUNKED or _chunks.is_empty():
		if turn:
			queue_redraw()
		return
	var view := view_rect()
	for c in _water_chunks:
		if turn:
			c.dirty = true
		if c.dirty and (c.water as Part).visible and view.intersects(c.px):
			c.dirty = false
			(c.water as Part).queue_redraw()


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
	if not _chunks.is_empty():
		return
	var mx := LOOP_MARGIN.x if loop_x else 0
	var my := LOOP_MARGIN.y if loop_y else 0
	drawn_cells += (width + 2 * mx) * (height + 2 * my)
	for y in range(-my, height + my):
		for x in range(-mx, width + mx):
			var dx := x * TS
			var dy := y * TS
			for id in _tiles_at(x, y):
				_draw_id(id, dx, dy)


func _draw_id(id: int, dx: int, dy: int) -> void:
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
	_canvas.draw_texture_rect_region(tex, Rect2(dx, dy, TS, TS), Rect2(sx, sy, TS, TS))


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
			_canvas.draw_texture_rect_region(tex, Rect2(dx1, dy1, HALF, HALF), Rect2(sx2, sy2, HALF, HALF))
			_canvas.draw_texture_rect_region(tex, Rect2(dx1, dy1 + HALF / 2.0, HALF, HALF / 2.0), Rect2(sx1, sy1, HALF, HALF / 2.0))
		else:
			_canvas.draw_texture_rect_region(tex, Rect2(dx1, dy1, HALF, HALF), Rect2(sx1, sy1, HALF, HALF))


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
		_canvas.draw_texture_rect_region(tex, Rect2(dx + (i % 2) * HALF, dy, HALF, HALF / 2.0), Rect2(sx1, sy1, HALF, HALF / 2.0))


func _draw_shadow(bits: int, dx: int, dy: int) -> void:
	if bits & 0x0f == 0:
		return
	for i in range(4):
		if bits & (1 << i):
			_canvas.draw_rect(Rect2(dx + (i % 2) * HALF, dy + floori(i / 2.0) * HALF, HALF, HALF), Color(0, 0, 0, 0.5))


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

## O-122（B3）：厄运监狱 Map079 的入口落点区域和牢房走廊在图块上完全不连通（(15,8)、(15,10) 两格墙隔开，正式引擎 isPassable
## 逐格 BFS 实测：整座监狱走不进去，只有开「穿墙」才行），首领、牢门都碰不到。这两格改为四向可通行，打通入口到牢房走廊。
## 键＝地图号 → 打通的格；设为空字典 {} 恢复原版（专项要两边都跑，所以是 static var）。
static var open_cells_fix := {79: [Vector2i(15, 8), Vector2i(15, 10)]}
## O-待定·麒麟殿地面（悟空 floor6 传送连通性）：一护副本麒麟殿 Map236 的殿内地面画的是图块组 41「亚特兰蒂斯」的 A1 第 2 种自动图块
## （图块号 2096～2143，这套图块里是深水，四向不可通行）。入口 Map148 EV41 落在 (8,14)，四周全是这种格，人原地动不了，
## 殿顶 (8,4) 的剧情 Boss（EV1，角色下方、按确认触发，要踩上去）碰不到；另外三殿用别的图块组，地面可走。
## 重制把本图第 2 层（z=1）这种自动图块的格和 (8,4) 当作可通行。键＝地图号 → {z, from, to, extra}；设为空字典 {} 恢复原版。
static var open_autotile_fix := {236: {"z": 1, "from": 2096, "to": 2144, "extra": [Vector2i(8, 4)]}}


## 本图按 open_cells_fix 与 open_autotile_fix 要打通的格
static func opened_cells(id: int, map_data: Dictionary) -> Array:
	var out: Array = Array(open_cells_fix.get(id, [])).duplicate()
	var spec = open_autotile_fix.get(id)
	if spec is Dictionary:
		var w := int(map_data.get("width", 0))
		var h := int(map_data.get("height", 0))
		var data: Array = map_data.get("data", [])
		for y in h:
			for x in w:
				var t := int(data[(int(spec.z) * h + y) * w + x])
				if t >= int(spec.from) and t < int(spec.to):
					out.append(Vector2i(x, y))
		out.append_array(spec.extra)
	return out

## 本图被打通的格（地图场景按 open_cells_fix 设置）
var open_cells: Array = []

## d 为方向 2/4/6/8；返回该格朝 d 方向能否离开/进入。设置「穿墙开关」开着时一律可通行（地图外仍不行，MV canPass 先查 isValid）。
func is_passable(x: int, y: int, d: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	if XConfig.flag("cq") or (not open_cells.is_empty() and open_cells.has(Vector2i(x, y))):
		return true
	return check_passage(x, y, (1 << (d / 2 - 1)) & 0x0f)

## MV Game_Map.isAirshipLandOk：飞艇降落标志 0x0800 不挡，且四向不全挡（不看穿墙开关）
func is_airship_land_ok(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	return check_passage(x, y, 0x0800) and check_passage(x, y, 0x0f)

## MV Game_Map.checkPassage：从上往下看图块，0x10（☆）跳过，该位全空可过、全满不可过，部分的看下一层
func check_passage(x: int, y: int, bit: int) -> bool:
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
