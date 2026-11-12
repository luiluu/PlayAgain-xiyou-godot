class_name XTianqiLook
extends RefCounted
## 【cc·天启篇·未经审查】四线的画面：线色、骑士立绘与剪影、异化纹路贴图、楼层异化色调（天启篇车道「庚 画面」）。
## 依据：四线剧情与关卡设计稿 v0.4 第 2 节（选线竖卡、方桌裂纹、读档线色）、四线异化 v0.8 第 1.3 节（线色、纹）与第 2.2 节（核心计量）。
## 素材在 res://content/tianqi/（来源见同目录 README.md）。
##
## 线色（v0.8 第 1.3 节，Kyo 11-08「颜色没问题」）：主色＋点缀色；旧稿的「白、赤、黑、灰白」作废。
## 纹路贴图（O12）是按旧稿四色画的，这里只取亮度当遮罩、再染成本线主色。
##
## 回退开关（都只认天启篇存档；发行构建里天启篇没开放时整个不出现，见 shown）：
## - CARDS（O-322）：选线用四张竖卡；false 回到对话框里四个选项。
## - CARD_PORTRAIT（O-322 同号）：竖卡上画骑士立绘；false 只画本线颜色的剪影（立绘还在待看稿，默认剪影，设计稿「立绘画好之前用剪影」）。
## - TABLE（O-323）：大厅方桌的裂纹（细裂纹→裂成四块→留下本线颜色的一块）；false 不画。
## - SAVE_COLOR（O-324）：读档页这一格加本线颜色；false 不加。
## - METER（O-325）：战斗里的本线计量条（火花、饥饿、死期、病灶）；false 只在战斗日志里报（各线原来的做法）。
## - FLOOR_TINT（O-326）：6～30 层换本线色调；false 照原图。

static var CARDS := true
static var CARD_PORTRAIT := false
static var TABLE := true
static var SAVE_COLOR := true
static var METER := true
static var FLOOR_TINT := true

const DIR := "res://content/tianqi/"
## 换色调的楼层（31 层起由 31～36 层重做那边管）
const TINT_FLOORS := Vector2i(6, 30)

## 每条线：主色、点缀色、暗色（剪影描边、计量条底）、楼层色调（乘在整张地图上）、计量名
const LOOK := {
	"war": {"main": Color8(232, 85, 39), "accent": Color8(239, 197, 72), "dark": Color8(62, 18, 10),
		"tint": Color(1.0, 0.87, 0.79), "meter": "火花"},
	"death": {"main": Color8(230, 223, 203), "accent": Color8(110, 155, 226), "dark": Color8(26, 32, 50),
		"tint": Color(0.85, 0.89, 0.96), "meter": "死期"},
	"famine": {"main": Color8(216, 192, 138), "accent": Color8(198, 39, 32), "dark": Color8(28, 26, 32),
		"tint": Color(0.93, 0.88, 0.75), "meter": "饥饿"},
	"plague": {"main": Color8(131, 193, 63), "accent": Color8(106, 58, 153), "dark": Color8(26, 36, 18),
		"tint": Color(0.86, 0.95, 0.83), "meter": "病灶"},
}

static var _tex := {}


static func info(key: String) -> Dictionary:
	var l = LOOK.get(key)
	return l if l is Dictionary else {}


static func main_color(key: String, fallback := Color.WHITE) -> Color:
	return info(key).get("main", fallback)


static func accent_color(key: String, fallback := Color.WHITE) -> Color:
	return info(key).get("accent", fallback)


static func dark_color(key: String, fallback := Color.BLACK) -> Color:
	return info(key).get("dark", fallback)


## 这一档画不画天启篇的画面：天启篇存档，发行构建里还要天启篇已开放
static func shown(s: XState) -> bool:
	return s != null and XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


static func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## 骑士立绘（512×768 透明，脚底约 y752）
static func portrait(key: String) -> Texture2D:
	return _load(DIR + "knight_%s.png" % key) if LOOK.has(key) else null


## 本线异化纹路（512×512 可平铺，透明）
static func mark(key: String) -> Texture2D:
	return _load(DIR + "mark_%s.png" % key) if LOOK.has(key) else null


# ---- 着色器：剪影、纹路染色 ----

const SILHOUETTE_SHADER := """
shader_type canvas_item;
// 立绘的不透明部分填成本线颜色：上暗下亮，像被桌面裂纹里的光从下面照着
uniform vec4 fill : source_color = vec4(1.0);
uniform vec4 rim : source_color = vec4(1.0);
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec3 c = mix(fill.rgb, rim.rgb, smoothstep(0.35, 1.0, UV.y));
	COLOR = vec4(c, a * fill.a * COLOR.a);
}
"""

const TINT_MARK_SHADER := """
shader_type canvas_item;
// 纹路贴图只取亮度×透明度当遮罩，染成一个颜色（O12 是按旧稿四色画的）
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float m = t.a * clamp(max(max(t.r, t.g), t.b) * 0.6 + 0.4, 0.0, 1.0);
	COLOR = vec4(tint.rgb, m * tint.a * COLOR.a);
}
"""

static var _shaders := {}


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var sh := Shader.new()
		sh.code = code
		_shaders[code] = sh
	return _shaders[code]


static func silhouette_material(key: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(SILHOUETTE_SHADER)
	m.set_shader_parameter("fill", main_color(key).darkened(0.35))
	m.set_shader_parameter("rim", main_color(key).lightened(0.25))
	return m


static func mark_material(key: String, alpha := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(TINT_MARK_SHADER)
	m.set_shader_parameter("tint", Color(main_color(key), alpha))
	return m


# ---- 读档线色 ----

## 存档字典（XState.to_dict 的结果）里选的线；不是天启篇存档、没选线为空串
static func line_of_save(d) -> String:
	if not d is Dictionary:
		return ""
	var t = d.get("flags", {}).get("tianqi")
	if not t is Dictionary or int(t.get("rules", 0)) < 1:   # 同 XTianqi.active
		return ""
	var key := str(t.get("line", ""))
	return key if LOOK.has(key) else ""


# ---- 楼层异化色调 ----

## 这张图该乘的色调（不换为白色）：开关开着、能看天启篇画面、选了线、楼层在 6～30 层
static func floor_tint(s: XState, map_id: int) -> Color:
	if not FLOOR_TINT or not shown(s):
		return Color.WHITE
	var key := XTianqi.line_of(s)
	if not LOOK.has(key):
		return Color.WHITE
	var f := XDungeon.map_floor(map_id)
	if f < TINT_FLOORS.x or f > TINT_FLOORS.y:
		return Color.WHITE
	return info(key).tint


## 地图场景换图时调：按需加／去 CanvasModulate（地图世界整张乘色，窗口在 CanvasLayer 里不受影响）
static func apply_floor_tint(map: Node, s: XState, map_id: int) -> void:
	var cm := map.get_node_or_null("TianqiFloorTint") as CanvasModulate
	var col := floor_tint(s, map_id)
	if col == Color.WHITE:
		if cm != null:
			cm.queue_free()
		return
	if cm == null:
		cm = CanvasModulate.new()
		cm.name = "TianqiFloorTint"
		map.add_child(cm)
	cm.color = col
