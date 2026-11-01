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
## 没开卡图时按 battler_key 的形态与状态换图（for_look）。
static func for_battler(b: XBattler) -> XAppearance:
	if b is XActor:
		return for_look(b as XActor, battler_key(b))
	var data: Dictionary = (b as XEnemy).data()
	var side = data.get("meta", {}).get("Sideview Battler")
	var key := "sv_actors/" + str(side).strip_edges() if side != null else "sv_enemies/" + str(data.get("battlerName", ""))
	return for_image(key, data.get("meta", {}))


## 按 battler_key（显示中的读数里记的）取角色外观：「图名」，后面可跟「|card」（卡图，去掉自身 SV 标签、不按状态换图）、
## 「|form:形态」（Codex_MiraRavenMultiFrame 的米拉／渡鸦变身逐帧图）、「|st:状态,…」（Mx_SuperSV 状态换图，ID 从大到小）。
static func for_look(a: XActor, key: String) -> XAppearance:
	var parts := key.split("|")
	var name := parts[0]
	var meta: Dictionary = a.data().get("meta", {})
	var form := ""
	var states := []
	for part in parts.slice(1):
		if part == "card":
			return for_image("sv_actors/" + name, XCostumes.strip_sv(meta))
		if part.begins_with("form:"):
			form = part.substr(5)
		elif part.begins_with("st:"):
			for id in part.substr(3).split(",", false):
				var st: Dictionary = XDB.rec("States", int(id))
				if not st.is_empty():
					states.append(st.get("meta", {}))
	return for_image("sv_actors/" + name, sv_provider(a, name, meta, form), states)


## for_battler 会取的图与标签取舍；精灵比对它决定要不要换外观（Sprite_Actor.updateBitmap 每帧比 battlerName，
## Mx_SuperSV 每帧按形态与状态重选逐帧图）
static func battler_key(b: XBattler) -> String:
	if not b is XActor:
		return ""
	var a := b as XActor
	XSukuna.full_look(a)  # 宿傩 Sprite_Actor.updateBitmap 包装：完全体时把 2643 放进状态（多帧图按状态选）
	var s := XState.current
	var key := XCostumes.battler_name(s, a)
	if XCostumes.active(s, a):
		return key + "|card"
	var form := sv_form(a)
	if form != "":
		key += "|form:" + form
	var ids := sv_states(a)
	if not ids.is_empty():
		key += "|st:" + ",".join(ids.map(func(x): return str(x)))
	return key


## Mx_SuperSV states()：带 <sv:名> 的状态，ID 从大到小（卡图生效时为空，调用方先判）
static func sv_states(a: XActor) -> Array:
	var ids := []
	for id in a.state_ids:
		if str(XDB.rec("States", int(id)).get("meta", {}).get("sv", "")).strip_edges() != "":
			ids.append(int(id))
	ids.sort()
	ids.reverse()
	return ids


## Codex_MiraRavenMultiFrame form()：米拉（168）平时人形，战斗中黑龙条件成立换黑龙（XMira.dragon，2592 只在战斗里有）；
## 渡鸦（167）神话剩余回合 > 0 换神话（只在战斗中有）。卡图生效时没有形态。
static func sv_form(a: XActor) -> String:
	if XMira.own(a):
		return "MiraDragon" if XMira.dragon(a) else "MiraHuman"
	if XRaven.own(a) and XRaven.is_myth(a):
		return "RavenMythic"
	return ""


## 变身逐帧图的标签（configs）：三套都是 UserSV_形态，各 20 张，Cfdz 把 18 种动作并到 0／7／10 号
static func form_meta(form: String) -> Dictionary:
	var m := {"sv": "UserSV_" + form, "SVspeed": "10", "SVzs0": "4", "SVzs7": "4", "SVzs10": "4",
		"Cfdz0": "[1,2,12]", "Cfdz7": "[6,8]", "Cfdz10": "[9,11]", "YCyy": "true" if form == "RavenMythic" else "false"}
	for i in [3, 4, 5, 13, 14, 15, 16, 17]:
		m["SVzs%d" % i] = "1"
	if form != "RavenMythic":
		m["SVzs1"] = "1"
		m["Cfdz0"] = "[2,12]"
	return m


const CAT_SHEET := "CatSwordSaint_SV_v3"
const CAT_FRAMES := "CatSwordSaint_v3"


## Mx.SuperSVMetaProvider 链（里到外：Codex_MiraRavenMultiFrame → 原生角色画面 installNativeCharacterVisualRuntime；
## 卡图那层在 for_look 里先判）。name：此刻的 battlerName。
static func sv_provider(_a: XActor, name: String, meta: Dictionary, form: String) -> Dictionary:
	var out := meta
	if form != "":
		out = meta.duplicate()
		for i in range(MOTIONS.size()):
			out.erase("Cfdz%d" % i)  # 变身那套自带全部动作映射，留下别的数据库标签
		out.merge(form_meta(form), true)
	# 小猫剑圣（battlerName 为 CatSwordSaint_SV_v3、没开卡图）：逐帧图 CatSwordSaint_v3，每个动作 3 帧（1 号 1 帧），速度 12
	if name == CAT_SHEET and (str(out.get("sv", "")) == "" or str(out.get("sv", "")) == CAT_FRAMES):
		out = out.duplicate()
		for i in range(MOTIONS.size()):
			out.erase("Cfdz%d" % i)
			out["SVzs%d" % i] = "1" if i == 1 else "3"
		out.merge({"sv": CAT_FRAMES, "SVspeed": "12", "YCyy": "false"}, true)
	return out


## key：「文件夹/名」。meta：数据库备注（Mx_SuperSV 标签）。states：状态换图的状态备注（优先的在前）。
static func for_image(key: String, meta := {}, states := []) -> XAppearance:
	var a := XAppearance.new()
	var o = config().get("battlers", {}).get(key)
	if o is Dictionary:
		var spec: Dictionary = o.duplicate(true)
		if not spec.has("image"):
			spec.image = key
		a._from_override(spec)
	elif key.begins_with("sv_actors/"):
		a._mv_sheet(_tex(key), key.trim_prefix("sv_actors/"))
		a._super_sv(meta)
		a._state_sv(states, meta)
	else:
		a._single(_tex(key))
	if a.portrait_tex == null and a.kind != "scene":
		var f := a.frame("walk", 0)
		a.portrait_tex = f.get("tex")
		a.portrait_rect = f.get("rect", Rect2())
	return a


# ---- 新增角色的站姿归一（Codex_MiraRavenMultiFrame normProfiles／profile／applyVisual） ----
## 角色 ID ≥ 167 的战斗图按此刻显示的那张图（逐帧图按文件夹名、侧视图按文件名）取档：[画布宽, 高, 可见范围 左, 上, 右, 下]。
## 缩放＝min(72／可见高, 129／可见宽)，脚底锚在可见范围底边中点；没有档的照 inferProfile 从站姿那格量（透明度 ≥ 12），
## 量不出（逐帧图在走路／待机以外的动作）就照旧式 ×0.75。小猫剑圣两张的档来自 installNativeCharacterVisualRuntime（同一张表）。
const PROFILES := {
	"Raven_Normal_SV": [64, 64, 9, 4, 60, 64], "BlackDragon_Mira_SV": [64, 64, 10, 2, 55, 64],
	"Codex_Yomi_SV": [64, 64, 0, 4, 63, 64], "Codex_Jingliu_SV": [64, 64, 11, 2, 54, 64],
	"Codex_Toji_SV": [64, 64, 9, 3, 51, 64], "Codex_Sukuna_SV": [64, 64, 14, 5, 48, 63],
	"Garou_Human": [64, 64, 7, 0, 51, 64], "Raven_Mythic_SV": [64, 64, 11, 4, 58, 63],
	"Garou_Cosmic": [64, 64, 18, 14, 46, 55], "UserSV_MiraHuman": [260, 240, 43, 48, 196, 178],
	"UserSV_MiraDragon": [340, 280, 61, 58, 260, 217], "UserSV_RavenMythic": [380, 280, 84, 55, 268, 211],
	"Codex_Sukuna_Full": [270, 260, 79, 42, 190, 222], "garou_human_v2": [192, 176, 50, 37, 146, 172],
	"garou_cosmic": [128, 128, 28, 8, 99, 120], "yunshang": [192, 192, 34, 52, 158, 184],
	"Yunshang": [192, 192, 34, 52, 158, 184], "Codex_Garou_QHuman": [64, 64, 7, 0, 51, 64],
	"Codex_Garou_QCosmic": [112, 112, 32, 24, 80, 96], "Codex_Sukuna_QFull": [64, 64, 8, 6, 47, 62],
	"CatSwordSaint_v3": [192, 160, 65, 72, 128, 144], "CatSwordSaint_SV_v3": [128, 128, 43, 64, 85, 113],
}
const PROFILE_H := 72.0
const PROFILE_W := 129.0
## inferProfile 量过的（按图名记一次）
static var _inferred := {}


## 这一帧的归一档 {size, bounds: Rect2, scale}；没有时空字典（调用方照旧式缩放）。motion：此刻的动作（量图只量走路／待机）。
static func profile(f: Dictionary, motion: String) -> Dictionary:
	var key := str(f.get("asset", ""))
	if key == "" or not f.has("tex"):
		return {}
	var multi := not (f.get("rect", Rect2()) as Rect2).has_area()
	var p: Array = PROFILES.get(key, [])
	if p.is_empty():
		if not _inferred.has(key):
			if multi and not motion in ["walk", "wait"]:
				return {}
			_inferred[key] = _infer(f.tex, multi)
		p = _inferred[key]
		if p.is_empty():
			return {}
	var b := Rect2(p[2], p[3], p[4] - p[2], p[5] - p[3])
	return {"size": Vector2(p[0], p[1]), "bounds": b, "multi": multi,
		"scale": minf(PROFILE_H / b.size.y, PROFILE_W / b.size.x)}


## inferProfile：侧视图量第 2 列第 1 行那格（走路第 2 帧），逐帧图量此刻这张；不透明度 ≥ 12 的外接框
static func _infer(t: Texture2D, multi: bool) -> Array:
	var img := t.get_image() if t else null
	if img == null:
		return []
	if img.is_compressed():
		img.decompress()
	var w := img.get_width() if multi else floori(img.get_width() / 9.0)
	var h := img.get_height() if multi else floori(img.get_height() / 6.0)
	var ox := 0 if multi else w
	var l := w
	var top := h
	var r := 0
	var btm := 0
	for y in range(h):
		for x in range(w):
			if img.get_pixel(ox + x, y).a8 >= 12:
				l = mini(l, x)
				top = mini(top, y)
				r = maxi(r, x + 1)
				btm = maxi(btm, y + 1)
	return [w, h, l, top, r, btm] if r > l and btm > top else []


func _single(t: Texture2D) -> void:
	kind = "single"
	if t:
		cell = t.get_size()
		motions["walk"] = {"frames": [{"tex": t, "rect": Rect2()}], "loop": true, "wait": 0}


func _mv_sheet(t: Texture2D, asset := "") -> void:
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
			rects.append({"tex": t, "rect": Rect2((floori(i / 6.0) * 3 + p) * cw, (i % 6) * ch, cw, ch), "asset": asset})
		motions[m] = {"frames": rects, "loop": LOOP.has(m), "wait": 0}


## Mx_SuperSV：有 <sv:名> 与 <SVzs动作:帧数> 的动作改用逐帧图（全部帧都在才用，否则保留原侧视图）；
## <Cfdz源:[动作…]> 让这些动作共用源动作的图（同一动作被多次映射时编号大的源优先）。状态换图见 _state_sv。
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
			frames.append({"tex": t, "rect": Rect2(), "asset": name})
		if not frames.is_empty():
			motions[MOTIONS[i]] = {"frames": frames, "loop": LOOP.has(MOTIONS[i]), "wait": speed}
	hide_shadow = str(meta.get("YCyy", "")).strip_edges().to_lower() == "true"


## Mx_SuperSV 状态换图（select 的 states(battler, index)）：每个动作取第一个有该动作帧数的状态（状态不走 Cfdz 映射），
## 全部帧都在才用，缺图就看下一个状态、再退到角色自身（_super_sv）与原侧视图。
## 速度照原版 motionSpeed：读角色（provider 之后）的 <SVspeed>，不读状态上的（宿傩完全体 2643 写了 10，原版不生效）。
func _state_sv(states: Array, actor_meta: Dictionary) -> void:
	if states.is_empty():
		return
	var speed_s := str(actor_meta.get("SVspeed", "")).strip_edges()
	var speed := int(speed_s) if speed_s.is_valid_int() and int(speed_s) > 0 else 0
	for i in range(MOTIONS.size()):
		for st in states:
			var name := str(st.get("sv", "")).strip_edges()
			var n_s := str(st.get("SVzs%d" % i, "0")).strip_edges()
			var n := int(n_s) if n_s.is_valid_int() else 0
			if name == "" or name.contains("/") or n <= 0 or n > 4096:
				continue
			var frames := []
			for f in range(n):
				var t := _tex("sv_actors/sv/%s/%s%d_%d" % [name, name, i, f])
				if t == null:
					frames.clear()
					break
				frames.append({"tex": t, "rect": Rect2(), "asset": name})
			if not frames.is_empty():
				motions[MOTIONS[i]] = {"frames": frames, "loop": LOOP.has(MOTIONS[i]), "wait": speed}
				break


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
