class_name XQualityIcons
extends RefCounted
## 【cc·悟空·未经审查】CodexQualityIcons（installNativeYomiJingliuRuntime）与 Codex_GuyuSukunaIconArt、谷雨图标条：超出 IconSet 网格的图标号。
## - 6400～6409：独立小图（customIconName）；9001：渡鸦法宝 pictures/Raven_Artifact_Icon；220000 起：谷雨图标条（32 格）。
## - 130229～130249（宿傩）、130288～130299（谷雨）：128 的 HD 图集，原色。
## - 130225、130250～130269 带 <CodexQualityIcon:n> 的技能：从 IconSet 第 n 格取亮白的笔画（不透明度 >100，三通道最小 >150，和 >550），按技能品质色铺在透明底上，
##   只看第 3～28 行列；5789 不取图，画两个同心圆加八个点（伏魔御厨子同款）。
## - 6410 宿傩法宝（Codex_Sukuna_Artifact）、6411～6417 破限之心（Garou_Relics 4 列）：按品质色调色（shade＋高光留白）。
## 云裳、屠苏璇、小猫、魔冠各有自己的图集，在 XUI.icon_texture 前面分流。参照 mv_oracle/quality_icons_probe.cjs，专项 tests/xiyou_quality_icons。

const CUSTOM := {6400: "Codex_Yomi_Seal", 6401: "Codex_Jingliu_Seal", 6402: "Codex_Yomi_Artifact", 6403: "Codex_Jingliu_Artifact",
	6404: "Codex_Toji_Artifact", 6405: "Codex_Heartsteel", 6406: "Codex_Leviathan", 6407: "Codex_Ornn_Masterwork_Upgrade", 6408: "Codex_Hubris", 6409: "Codex_Ataraxia"}
const GUYU_ATLAS := 220000
const GUYU_COUNT := 16
const SKILL_BASE := 120000
const HD_CELL := 128
const GAROU_RELICS := [7904, 7905, 7906, 7908, 7909, 7910, 7911]
const SUKUNA_ARTIFACT := 4581

static var _cache := {}


## Q.lookup（含 GuyuSukuna、谷雨条）：{image, picture?, native?, source, skill?, hd?, item?}；不归这里管的返回空
static func info(index: int) -> Dictionary:
	if CUSTOM.has(index):
		return {"image": CUSTOM[index], "native": true}
	if index == 9001:
		return {"image": "Raven_Artifact_Icon", "picture": true, "native": true}
	if index >= GUYU_ATLAS and index < GUYU_ATLAS + GUYU_COUNT:
		return {"image": "Guyu_Icons", "strip": index - GUYU_ATLAS}
	var s := index - SKILL_BASE
	if s >= 10288 and s <= 10299:
		return {"image": "Codex_Guyu_SkillIcons_v2", "hd": s - 10288}
	if s >= 10229 and s <= 10249:
		return {"image": "Codex_Sukuna_SkillIcons_v2", "hd": s - 10229}
	if s == 10225 or (s >= 10250 and s <= 10269):
		var item := XDB.rec("Skills", s)
		var q = item.get("meta", {}).get("CodexQualityIcon")
		if q != null:
			return {"item": item, "source": int(str(q)), "skill": true}
		return {}
	if index == 6410:
		return {"item": XDB.rec("Armors", SUKUNA_ARTIFACT), "image": "Codex_Sukuna_Artifact", "source": 0}
	if index >= 6411 and index <= 6417:
		var relic := XDB.rec("Armors", GAROU_RELICS[index - 6411])
		if relic.get("meta", {}).has("GarouRelicStage"):
			return {"item": relic, "image": "Garou_Relics", "source": index - 6411}
	return {}


static func _image(folder: String, name: String) -> Image:
	var p := XDB.img_path(folder, name)
	if p == "":
		return null
	var img: Image = (load(p) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## IconSet 第 n 格（512×12800 切成四张 IconSet_1～4，每张 1600 格）
static func _iconset_cell(n: int) -> Image:
	var img := _image("system", "IconSet_%d" % (floori(n / 1600.0) + 1))
	if img == null:
		return null
	var local := n % 1600
	return img.get_region(Rect2i((local % 16) * 32, floori(local / 16.0) * 32, 32, 32))


## info.skill：亮白笔画铺品质色
static func _skill_image(i: Dictionary) -> Image:
	var color := XQuality.color(i.item)
	var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	if int(i.source) == 5789:
		_ring(out, 10.0, 2.0, color)
		_ring(out, 4.0, 2.0, color)
		for n in 8:
			var t := n * PI / 4.0
			out.fill_rect(Rect2i(roundi(14 + 10 * cos(t)), roundi(14 + 10 * sin(t)), 4, 4), color)
		return out
	var cell := _iconset_cell(int(i.source))
	if cell == null:
		return null
	for y in range(3, 29):
		for x in range(3, 29):
			var c := cell.get_pixel(x, y)
			if c.a8 > 100 and mini(mini(c.r8, c.g8), c.b8) > 150 and c.r8 + c.g8 + c.b8 > 550:
				out.set_pixel(x, y, color)
	return out


static func _ring(img: Image, r: float, w: float, color: Color) -> void:
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length()
			var a := clampf(w / 2.0 + 0.5 - absf(d - r), 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(color, a))


## 法宝调色：亮度 → shade＝.18＋.82×亮度，高光（亮度 >.76）往白留
static func _tone_image(i: Dictionary) -> Image:
	var src := _image("system", str(i.image))
	if src == null:
		return null
	var sx := 0
	var sy := 0
	if str(i.image) == "Garou_Relics":
		sx = (int(i.source) % 4) * 32
		sy = floori(int(i.source) / 4.0) * 32
	var out := src.get_region(Rect2i(sx, sy, 32, 32))
	var color := XQuality.color(i.item)
	for y in 32:
		for x in 32:
			var c := out.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var light := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			var shade := 0.18 + 0.82 * light
			var white := maxf(0.0, (light - 0.76) / 0.24) * 0.75
			out.set_pixel(x, y, Color(color.r * shade * (1.0 - white) + white, color.g * shade * (1.0 - white) + white, color.b * shade * (1.0 - white) + white, c.a))
	return out


## 按 size 取图（XUI.icon_texture 用 32、大图标用 128）；HD 平滑缩，其余最近邻（原版关平滑）
static func icon_texture(index: int, size := 32) -> AtlasTexture:
	var i := info(index)
	if i.is_empty():
		return null
	var key := "%d:%d" % [index, size]
	if _cache.has(key):
		return _cache[key]
	var img: Image = null
	if i.has("hd"):
		var src := _image("system", str(i.image))
		if src != null:
			img = src.get_region(Rect2i(int(i.hd) * HD_CELL, 0, HD_CELL, HD_CELL))
			if size != HD_CELL:
				img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	else:
		if i.has("strip"):
			var src := _image("system", str(i.image))
			img = src.get_region(Rect2i(int(i.strip) * 32, 0, 32, 32)) if src != null else null
		elif i.get("native", false):
			img = _image("pictures" if i.get("picture", false) else "system", str(i.image))
		elif i.get("skill", false):
			img = _skill_image(i)
		else:
			img = _tone_image(i)
		if img != null and (img.get_width() != size or img.get_height() != size):
			img = img.duplicate() as Image
			img.resize(size, size, Image.INTERPOLATE_NEAREST)
	if img == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = ImageTexture.create_from_image(img)
	a.region = Rect2(0, 0, size, size)
	_cache[key] = a
	return a
