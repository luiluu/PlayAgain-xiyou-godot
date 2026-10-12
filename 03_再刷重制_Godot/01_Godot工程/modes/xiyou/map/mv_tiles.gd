class_name MVTiles
extends RefCounted
## MV 图块常量与 ID 判定，移植自 rpg_core.js（Tilemap）。图块 48×48，自动图块按 4 个 24×24 四分块拼合。

const TILE_SIZE := 48
const TILE_ID_B := 0
const TILE_ID_C := 256
const TILE_ID_D := 512
const TILE_ID_E := 768
const TILE_ID_A5 := 1536
const TILE_ID_A1 := 2048
const TILE_ID_A2 := 2816
const TILE_ID_A3 := 4352
const TILE_ID_A4 := 5888
const TILE_ID_MAX := 8192

const FLOOR_AUTOTILE_TABLE := [
	[[2,4],[1,4],[2,3],[1,3]],
	[[2,0],[1,4],[2,3],[1,3]],
	[[2,4],[3,0],[2,3],[1,3]],
	[[2,0],[3,0],[2,3],[1,3]],
	[[2,4],[1,4],[2,3],[3,1]],
	[[2,0],[1,4],[2,3],[3,1]],
	[[2,4],[3,0],[2,3],[3,1]],
	[[2,0],[3,0],[2,3],[3,1]],
	[[2,4],[1,4],[2,1],[1,3]],
	[[2,0],[1,4],[2,1],[1,3]],
	[[2,4],[3,0],[2,1],[1,3]],
	[[2,0],[3,0],[2,1],[1,3]],
	[[2,4],[1,4],[2,1],[3,1]],
	[[2,0],[1,4],[2,1],[3,1]],
	[[2,4],[3,0],[2,1],[3,1]],
	[[2,0],[3,0],[2,1],[3,1]],
	[[0,4],[1,4],[0,3],[1,3]],
	[[0,4],[3,0],[0,3],[1,3]],
	[[0,4],[1,4],[0,3],[3,1]],
	[[0,4],[3,0],[0,3],[3,1]],
	[[2,2],[1,2],[2,3],[1,3]],
	[[2,2],[1,2],[2,3],[3,1]],
	[[2,2],[1,2],[2,1],[1,3]],
	[[2,2],[1,2],[2,1],[3,1]],
	[[2,4],[3,4],[2,3],[3,3]],
	[[2,4],[3,4],[2,1],[3,3]],
	[[2,0],[3,4],[2,3],[3,3]],
	[[2,0],[3,4],[2,1],[3,3]],
	[[2,4],[1,4],[2,5],[1,5]],
	[[2,0],[1,4],[2,5],[1,5]],
	[[2,4],[3,0],[2,5],[1,5]],
	[[2,0],[3,0],[2,5],[1,5]],
	[[0,4],[3,4],[0,3],[3,3]],
	[[2,2],[1,2],[2,5],[1,5]],
	[[0,2],[1,2],[0,3],[1,3]],
	[[0,2],[1,2],[0,3],[3,1]],
	[[2,2],[3,2],[2,3],[3,3]],
	[[2,2],[3,2],[2,1],[3,3]],
	[[2,4],[3,4],[2,5],[3,5]],
	[[2,0],[3,4],[2,5],[3,5]],
	[[0,4],[1,4],[0,5],[1,5]],
	[[0,4],[3,0],[0,5],[1,5]],
	[[0,2],[3,2],[0,3],[3,3]],
	[[0,2],[1,2],[0,5],[1,5]],
	[[0,4],[3,4],[0,5],[3,5]],
	[[2,2],[3,2],[2,5],[3,5]],
	[[0,2],[3,2],[0,5],[3,5]],
	[[0,0],[1,0],[0,1],[1,1]]
]

const WALL_AUTOTILE_TABLE := [
	[[2,2],[1,2],[2,1],[1,1]],
	[[0,2],[1,2],[0,1],[1,1]],
	[[2,0],[1,0],[2,1],[1,1]],
	[[0,0],[1,0],[0,1],[1,1]],
	[[2,2],[3,2],[2,1],[3,1]],
	[[0,2],[3,2],[0,1],[3,1]],
	[[2,0],[3,0],[2,1],[3,1]],
	[[0,0],[3,0],[0,1],[3,1]],
	[[2,2],[1,2],[2,3],[1,3]],
	[[0,2],[1,2],[0,3],[1,3]],
	[[2,0],[1,0],[2,3],[1,3]],
	[[0,0],[1,0],[0,3],[1,3]],
	[[2,2],[3,2],[2,3],[3,3]],
	[[0,2],[3,2],[0,3],[3,3]],
	[[2,0],[3,0],[2,3],[3,3]],
	[[0,0],[3,0],[0,3],[3,3]]
]

const WATERFALL_AUTOTILE_TABLE := [
	[[2,0],[1,0],[2,1],[1,1]],
	[[0,0],[1,0],[0,1],[1,1]],
	[[2,0],[3,0],[2,1],[3,1]],
	[[0,0],[3,0],[0,1],[3,1]]
]


static func is_visible(id: int) -> bool:
	return id > 0 and id < TILE_ID_MAX

static func is_autotile(id: int) -> bool:
	return id >= TILE_ID_A1

static func autotile_kind(id: int) -> int:
	return floori((id - TILE_ID_A1) / 48.0)

static func autotile_shape(id: int) -> int:
	return (id - TILE_ID_A1) % 48

static func is_a1(id: int) -> bool:
	return id >= TILE_ID_A1 and id < TILE_ID_A2

static func is_a2(id: int) -> bool:
	return id >= TILE_ID_A2 and id < TILE_ID_A3

static func is_a3(id: int) -> bool:
	return id >= TILE_ID_A3 and id < TILE_ID_A4

static func is_a4(id: int) -> bool:
	return id >= TILE_ID_A4 and id < TILE_ID_MAX

static func is_a5(id: int) -> bool:
	return id >= TILE_ID_A5 and id < TILE_ID_A1

static func is_water(id: int) -> bool:
	if is_a1(id):
		return not (id >= TILE_ID_A1 + 96 and id < TILE_ID_A1 + 192)
	return false

static func is_waterfall(id: int) -> bool:
	if id >= TILE_ID_A1 + 192 and id < TILE_ID_A2:
		return autotile_kind(id) % 2 == 1
	return false

static func is_roof(id: int) -> bool:
	return is_a3(id) and autotile_kind(id) % 16 < 8

static func is_wall_top(id: int) -> bool:
	return is_a4(id) and autotile_kind(id) % 16 < 8

static func is_wall_side(id: int) -> bool:
	return (is_a3(id) or is_a4(id)) and autotile_kind(id) % 16 >= 8

static func is_shadowing(id: int) -> bool:
	return is_a3(id) or is_a4(id)
