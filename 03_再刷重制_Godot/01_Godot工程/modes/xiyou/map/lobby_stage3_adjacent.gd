class_name XLobbyStage3Adjacent
extends Node2D
## 相连地图的三阶换画。沿用大厅的地面／根脉／前景顺序；通行与事件仍由原地图驱动。

static var ENABLED := true

const ART_DIR := "res://content/lobby/adjacent_stage3/"
## 裁掉贴花周围的透明像素后，各贴图在地图像素坐标中的左上角。
const ROOT_ORIGINS := {
	18: Vector2i(206, 177),
	40: Vector2i(119, 169),
	132: Vector2i(52, 45),
	187: Vector2i(0, 192),
	195: Vector2i(105, 70),
	224: Vector2i(190, 209),
	225: Vector2i(68, 175),
}
const FOREGROUND_ORIGINS := {
	18: Vector2i(232, 455),
	40: Vector2i(252, 248),
	132: Vector2i(108, 488),
	195: Vector2i(386, 0),
	224: Vector2i(208, 192),
}
const ANIMATED_MAPS := [187, 195, 225]
const A1 := 0


static func attach(map_id: int, lower: MVTilemap, upper: MVTilemap) -> void:
	if not ENABLED or not ROOT_ORIGINS.has(map_id) or not XLobbyCorruption.stage3_active():
		return
	var prefix := ART_DIR + "Map%03d_" % map_id
	var ground := _texture(prefix + "ground.png")
	var roots := _texture(prefix + "roots.png")
	if ground == null or roots == null:
		return
	var foreground: Texture2D
	if FOREGROUND_ORIGINS.has(map_id):
		foreground = _texture(prefix + "foreground.png")
		if foreground == null:
			return
	if map_id in ANIMATED_MAPS:
		var a1 := _texture(prefix + "a1.png")
		if a1 == null:
			return
		# 下层在首次分块绘制前换 A1。底图在动画像素处透明，由原拼块逻辑继续播放水面和瀑布。
		lower.sheets[A1] = a1
	var art := XLobbyStage3Adjacent.new()
	art.name = "Stage3Adjacent"
	lower.add_child(art)
	art._add_sprite("Ground", ground, Vector2i.ZERO, -9)
	art._add_sprite("Roots", roots, ROOT_ORIGINS[map_id], -8)
	if foreground != null:
		upper.hide()
		art._add_sprite("Foreground", foreground, FOREGROUND_ORIGINS[map_id], upper.z_index)


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null


func _add_sprite(label: String, texture: Texture2D, origin: Vector2i, depth: int) -> void:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.centered = false
	sprite.position = origin
	sprite.z_as_relative = false
	sprite.z_index = depth
	add_child(sprite)
