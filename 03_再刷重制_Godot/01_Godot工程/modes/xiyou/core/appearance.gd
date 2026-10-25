class_name XAppearance
extends RefCounted
## 战斗者与行走图的外观（图像格式）。战斗/地图代码只按「动作名 + 帧号」取图，不再写死 MV 格式。
## 默认照正式版：
##   - MV 侧视图（Sprite_Actor.updateFrame：格子＝图宽÷9 × 图高÷6，18 种动作各 3 格，循环动作按 0,1,2,1）；
##   - Mx_SuperSV 逐帧图（备注 <sv:名>、<SVzs动作:帧数>、<SVspeed:n>、<Cfdz动作:[…]>、<YCyy:true>，
##     图在 sv_actors/sv/名/名动作_帧.png；没配的动作仍用原侧视图）；
##   - 敌人单图（sv_enemies，不播放动作）；
##   - 行走图 3×4（文件名带 $ 为单人图，否则一张 8 人）。
## appearances.json 可按图片名覆盖成任意格式（见 框架维护约定「角色外观接口」），新美术只需登记，不用改战斗/地图代码：
##   battlers["sv_actors/名"] 或 ["sv_enemies/名"]：
##     {"kind": "grid", "cell": [宽, 高], "wait": 每格帧数, "motions": {"walk": {"row": 0, "col": 0, "frames": 8, "loop": true}, …}}
##     {"kind": "frames", "wait": n, "motions": {"walk": {"images": ["sv_actors/x/walk_0", …], "loop": true}, …}}
##     {"kind": "scene", "scene": "res://…tscn", "size": [宽, 高], "portrait": "faces/名"}（骨骼、AnimationPlayer 等）
##     共用可选项：scale（显示倍率）、hideShadow、portrait（行动条头像图）。
##   characters["名"]：{"cell": [宽, 高], "frames": n, "sequence": [...], "stand": 序号, "rows": {"2": 行, "4": 行, "6": 行, "8": 行}}

const CONFIG := "res://modes/xiyou/appearances.json"
const MOTIONS := ["walk", "wait", "chant", "guard", "damage", "evade", "thrust", "swing", "missile", "skill", "spell",
	"item", "escape", "victory", "dying", "abnormal", "sleep", "dead"]
const LOOP := ["walk", "wait", "chant", "guard", "dying", "abnormal", "sleep", "dead", "victory"]
## 自定义格式缺某个动作时依次退到的动作（最后退到 walk，再退到表里第一个）
const FALLBACK := {"wait": "walk", "chant": "wait", "guard": "wait", "damage": "wait", "evade": "damage",
	"thrust": "swing", "swing": "skill", "missile": "swing", "skill": "spell", "spell": "wait", "item": "skill",
	"escape": "walk", "victory": "wait", "dying": "wait", "abnormal": "dying", "sleep": "dead", "dead": "dying"}

## 测试可直接赋值（Dictionary）；null 时读 CONFIG
static var overrides = null

var kind := "frames"         # frames（逐帧取图：MV 侧视图、Mx_SuperSV、grid 都归为这一种）/ single / scene
## 动作名 -> {"frames": [{"tex": Texture2D, "rect": Rect2（空＝整张）}…], "loop": bool, "wait": 帧数（0＝默认）}
var motions := {}
var cell := Vector2.ZERO     # 基准显示尺寸（MV：一格；单图：整张；场景：size）
var sideview := false        # 按侧视图处理（光标高度、敌人朝向）
var scene: PackedScene
var scale := 1.0
var hide_shadow := false
var portrait_tex: Texture2D
var portrait_rect := Rect2()


static func config() -> Dictionary:
	if overrides == null:
		var d = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else null
		overrides = d if d is Dictionary else {}
	return overrides


static func _tex(path: String) -> Texture2D:
	var cut := path.rfind("/")
	var p := XDB.img_path(path.substr(0, cut), path.substr(cut + 1)) if cut > 0 else ""
	return load(p) if p != "" else null


## 战斗者外观：角色用 battlerName 侧视图；敌人有 <Sideview Battler> 时用侧视图，否则 sv_enemies 单图。
## 角色的 battlerName 走 XCostumes.battler_name（换装卡：战斗中有卡状态且启用＝卡图，参照 costume_oracle 的 battle_image），
## 启用卡图时 Mx.SuperSVMetaProvider 去掉角色自身的 SV 标签（XCostumes.sv_meta），卡图按原侧视图播放。
static func for_battler(b: XBattler) -> XAppearance:
	var data: Dictionary = (b as XActor).data() if b is XActor else (b as XEnemy).data()
	if b is XActor:
		var s := XState.current
		return for_image("sv_actors/" + XCostumes.battler_name(s, b), XCostumes.sv_meta(s, b, data.get("meta", {})))
	var side = data.get("meta", {}).get("Sideview Battler")
	var key := "sv_actors/" + str(side).strip_edges() if side != null else "sv_enemies/" + str(data.get("battlerName", ""))
	return for_image(key, data.get("meta", {}))


## 按 battler_key（显示中的读数里记的）取角色外观：「图名」或「图名|card」（去掉自身 SV 标签）
static func for_look(a: XActor, key: String) -> XAppearance:
	var meta: Dictionary = a.data().get("meta", {})
	return for_image("sv_actors/" + key.trim_suffix("|card"), XCostumes.strip_sv(meta) if key.ends_with("|card") else meta)


## for_battler 会取的图与标签取舍；精灵比对它决定要不要换外观（Sprite_Actor.updateBitmap 每帧比 battlerName）
static func battler_key(b: XBattler) -> String:
	if b is XActor:
		var s := XState.current
		return XCostumes.battler_name(s, b) + ("|card" if XCostumes.active(s, b) else "")
	return ""


## key：「文件夹/名」。meta：数据库备注（Mx_SuperSV 标签）。
static func for_image(key: String, meta := {}) -> XAppearance:
	var a := XAppearance.new()
	var o = config().get("battlers", {}).get(key)
	if o is Dictionary:
		var spec: Dictionary = o.duplicate(true)
		if not spec.has("image"):
			spec.image = key
		a._from_override(spec)
	elif key.begins_with("sv_actors/"):
		a._mv_sheet(_tex(key))
		a._super_sv(meta)
	else:
		a._single(_tex(key))
	if a.portrait_tex == null and a.kind != "scene":
		var f := a.frame("walk", 0)
		a.portrait_tex = f.get("tex")
		a.portrait_rect = f.get("rect", Rect2())
	return a


func _single(t: Texture2D) -> void:
	kind = "single"
	if t:
		cell = t.get_size()
		motions["walk"] = {"frames": [{"tex": t, "rect": Rect2()}], "loop": true, "wait": 0}


func _mv_sheet(t: Texture2D) -> void:
	sideview = true
	if t == null:
		cell = Vector2(64, 64)
		return
	var cw := t.get_width() / 9.0
	var ch := t.get_height() / 6.0
	cell = Vector2(cw, ch)
	for i in range(MOTIONS.size()):
		var m: String = MOTIONS[i]
		var rects := []
		for p in ([0, 1, 2, 1] if LOOP.has(m) else [0, 1, 2]):
			rects.append({"tex": t, "rect": Rect2((floori(i / 6.0) * 3 + p) * cw, (i % 6) * ch, cw, ch)})
		motions[m] = {"frames": rects, "loop": LOOP.has(m), "wait": 0}


## Mx_SuperSV：有 <sv:名> 与 <SVzs动作:帧数> 的动作改用逐帧图（全部帧都在才用，否则保留原侧视图）；
## <Cfdz源:[动作…]> 让这些动作共用源动作的图（同一动作被多次映射时编号大的源优先）。状态换图（<sv:> 写在状态上）未接。
func _super_sv(meta: Dictionary) -> void:
	var name := str(meta.get("sv", "")).strip_edges()
	if name == "" or name.contains("/"):
		return
	var counts := {}
	for i in range(MOTIONS.size()):
		var n := int(str(meta.get("SVzs%d" % i, "0")).strip_edges()) if str(meta.get("SVzs%d" % i, "0")).strip_edges().is_valid_int() else 0
		if n > 0 and n <= 4096:
			counts[i] = n
	var source := {}
	for i in range(MOTIONS.size()):
		source[i] = i
	for i in range(MOTIONS.size()):
		var list = JSON.parse_string(str(meta.get("Cfdz%d" % i, ""))) if meta.has("Cfdz%d" % i) else null
		if list is Array:
			for x in list:
				if str(x).strip_edges().is_valid_int() and int(x) >= 0 and int(x) < MOTIONS.size():
					source[int(x)] = i
	var speed_s := str(meta.get("SVspeed", "")).strip_edges()
	var speed := int(speed_s) if speed_s.is_valid_int() and int(speed_s) > 0 else 0
	for i in range(MOTIONS.size()):
		var src: int = source[i]
		if not counts.has(src):
			continue
		var frames := []
		for f in range(counts[src]):
			var t := _tex("sv_actors/sv/%s/%s%d_%d" % [name, name, src, f])
			if t == null:
				frames.clear()
				break
			frames.append({"tex": t, "rect": Rect2()})
		if not frames.is_empty():
			motions[MOTIONS[i]] = {"frames": frames, "loop": LOOP.has(MOTIONS[i]), "wait": speed}
	hide_shadow = str(meta.get("YCyy", "")).strip_edges().to_lower() == "true"


func _from_override(o: Dictionary) -> void:
	kind = str(o.get("kind", "grid"))
	scale = float(o.get("scale", 1.0))
	hide_shadow = bool(o.get("hideShadow", false))
	sideview = kind != "single"
	var wait := int(o.get("wait", 0))
	if o.has("portrait"):
		portrait_tex = _tex(str(o.portrait))
	match kind:
		"scene":
			scene = load(str(o.scene)) if ResourceLoader.exists(str(o.get("scene", ""))) else null
			var sz: Array = o.get("size", [64, 64])
			cell = Vector2(float(sz[0]), float(sz[1]))
			sideview = true
		"single":
			_single(_tex(str(o.get("image", ""))))
		"grid":
			kind = "frames"
			var t := _tex(str(o.get("image", "")))
			var cz: Array = o.get("cell", [64, 64])
			cell = Vector2(float(cz[0]), float(cz[1]))
			for m in o.get("motions", {}):
				var d: Dictionary = o.motions[m]
				var rects := []
				for f in range(int(d.get("frames", 1))):
					rects.append({"tex": t, "rect": Rect2((int(d.get("col", 0)) + f) * cell.x, int(d.get("row", 0)) * cell.y, cell.x, cell.y)})
				motions[m] = {"frames": rects, "loop": bool(d.get("loop", LOOP.has(m))), "wait": int(d.get("wait", wait))}
		"frames":
			for m in o.get("motions", {}):
				var d: Dictionary = o.motions[m]
				var list := []
				for path in d.get("images", []):
					var t := _tex(str(path))
					if t:
						list.append({"tex": t, "rect": Rect2()})
				if not list.is_empty():
					motions[m] = {"frames": list, "loop": bool(d.get("loop", LOOP.has(m))), "wait": int(d.get("wait", wait))}
			var first := frame("walk", 0)
			if first.has("tex"):
				cell = _frame_size(first)


## 实际用到的动作名：自己有就用，否则按 FALLBACK 退，最后退到 walk 或表里第一个。
func resolve(m: String) -> String:
	var seen := {}
	var cur := m
	while cur != "" and not seen.has(cur):
		if motions.has(cur):
			return cur
		seen[cur] = true
		cur = FALLBACK.get(cur, "")
	if motions.has("walk"):
		return "walk"
	return motions.keys()[0] if not motions.is_empty() else ""


func frame_count(m: String) -> int:
	var r := resolve(m)
	return motions[r].frames.size() if r != "" else 0


func is_loop(m: String) -> bool:
	var r := resolve(m)
	return bool(motions[r].loop) if r != "" else LOOP.has(m)


## 每格停留帧数（0＝调用方默认）
func wait_of(m: String) -> int:
	var r := resolve(m)
	return int(motions[r].wait) if r != "" else 0


## {"tex": Texture2D, "rect": Rect2}；取不到时为空字典
func frame(m: String, i: int) -> Dictionary:
	var r := resolve(m)
	if r == "":
		return {}
	var list: Array = motions[r].frames
	return list[clampi(i, 0, list.size() - 1)]


static func _frame_size(f: Dictionary) -> Vector2:
	var r: Rect2 = f.get("rect", Rect2())
	return r.size if r.has_area() else (f.tex as Texture2D).get_size()


## 会逐帧播放动作（侧视图、逐帧、场景）；敌人单图不播放
func animated() -> bool:
	return kind != "single"


# ---- 行走图 ----
## 行走图格式：{"cell": Vector2, "origin": Vector2（该角色在图上的左上角）, "sequence": [列…], "stand": 停步时的序号, "rows": {方向: 行}}
## 默认 MV（Sprite_Character：3 列 4 行，序列 0,1,2,1，停步 1，行＝(方向−2)/2）。
static func walk(name: String, index: int, tex: Texture2D) -> Dictionary:
	var o = config().get("characters", {}).get(name)
	var rows := {2: 0, 4: 1, 6: 2, 8: 3}
	if o is Dictionary:
		var n := int(o.get("frames", 3))
		var seq: Array = o.get("sequence", range(n))
		var cz: Array = o.get("cell", [tex.get_width() / float(n) if tex else 48.0, tex.get_height() / 4.0 if tex else 48.0])
		for k in o.get("rows", {}):
			rows[int(k)] = int(o.rows[k])
		return {"cell": Vector2(float(cz[0]), float(cz[1])), "origin": Vector2.ZERO, "sequence": seq,
			"stand": int(o.get("stand", 0)), "rows": rows}
	var big := name.begins_with("$") or name.begins_with("!$")
	var pw := (tex.get_width() / (3.0 if big else 12.0)) if tex else 48.0
	var ph := (tex.get_height() / (4.0 if big else 8.0)) if tex else 48.0
	var origin := Vector2.ZERO if big else Vector2((index % 4) * 3 * pw, floori(index / 4.0) * 4 * ph)
	return {"cell": Vector2(pw, ph), "origin": origin, "sequence": [0, 1, 2, 1], "stand": 1, "rows": rows}
