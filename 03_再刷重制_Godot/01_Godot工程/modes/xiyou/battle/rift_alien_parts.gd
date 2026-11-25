class_name XRiftAlienParts
extends Node2D
## 【cc·未经审查】T505 西游档异化怪三级附加件（侵染／蚀骨／化形，Kyo 11-25 事项 67 定稿；素材 T504 content/monsters/rift/）。
## XBattlerSprite（敌人）每帧调 sync(self)：这只敌人有异化级（XRiftAlien.LOOK 的 tier）且 XRiftAlien.on(当前存档)
## （含天启篇守卫 not XTianqi.active）时，按怪归属模板（profiles.json：敌人 ID → 外观键兜底）挂 anchors.json 的 stack[级]：
## - 前件（depth front：侵染 stain、蚀骨 tear_front、化形 root_front）：身体 Sprite2D 的子节点，身体开 clip_children
##   （按身体透明度裁切）；模板避让区（脸、眼、武器、站脚）只在覆盖表 mask_avoid 点名时挖空（返修 P2-1）。跟身体的帧、缩放、呼吸、浮空、翻面、闪白、淡出走。
## - 后件（depth back：蚀骨 bone_back、化形 limb_back）：本节点，放在战场里所有战斗者精灵之前（画在全部身体后面，
##   伸出的长肢不压邻怪、我方和血条），每帧由 RemoteTransform2D 跟身体的变换，可见与透明度照身体。
## 摆放：按身体待机首帧的可见范围（非透明外框，翻面时按显示方向）定根点＝可见左上＋root_uv×可见大小；
## 附加件倍数 k＝max(可见宽,高)÷max(样本可见宽,高)，夹在 [K_MIN, K_MAX]，再乘身体自己的缩放；样本怪本身 k＝1，与定稿板逐像素同位。
## 技能动作帧不重量（武器、大裁切区不拉长模板）。退场（倒下粉碎、淡出）跟身体一起不见；换外观（敌人变身）时战斗场景新建精灵，旧件随旧精灵清掉。
## 挂上时给敌人设 XRiftAlien.PARTS，整体偏色改用 look.parts_tier_glow（0.04／0.06／0.08）；没挂上照旧 tier_glow。
## 不挂（回到原偏色）：开关关、素材或锚点不齐、场景外观（骨骼动画等）、清单里查不到模板。
##
## 开关（O-待定，T505）：ENABLED＝false 回到 T504 前（只有偏色，不挂件）。

const DIR := "res://content/monsters/rift/"
const ANCHORS := DIR + "anchors.json"
const PROFILES := DIR + "profiles.json"
## 返修 P2-2：按实战外观键的单独锚点覆盖（root_uv 换根点、k_mul 整体倍数、k_max 倍数上限、back_mul 后件再乘、
## back_flip 后件绕根点左右翻（长肢往身后伸，不伸向我方）、hide 不挂的件、mask_avoid 前件按模板避让区挖空）；没登记的外观照模板
const OVERRIDES := DIR + "overrides.json"
const K_MIN := 0.35
const K_MAX := 2.55

## 回退开关：false＝不挂附加件（异化怪只有原来的幽紫偏色）
static var ENABLED := true

static var _anchors = null
static var _profiles = null
static var _overrides = null
static var _vis_cache := {}

const AVOID_SHADER := """
shader_type canvas_item;
uniform vec4 avoid[4];
uniform int n = 0;
void fragment() {
	for (int i = 0; i < n; i++) {
		vec4 r = avoid[i];
		if (UV.x >= r.x && UV.x < r.z && UV.y >= r.y && UV.y < r.w) {
			COLOR.a = 0.0;
		}
	}
}
"""
static var _avoid_shader: Shader

var host: XBattlerSprite
var tier := ""
var profile := ""
var front: Node2D
var _remote: RemoteTransform2D


static func anchors() -> Dictionary:
	if _anchors == null:
		_anchors = _read(ANCHORS)
	return _anchors


static func profiles() -> Dictionary:
	if _profiles == null:
		_profiles = _read(PROFILES)
	return _profiles


static func overrides() -> Dictionary:
	if _overrides == null:
		_overrides = _read(OVERRIDES)
	return _overrides


## 实战外观键（同 XAppearance.for_battler）
static func look_key(e: XEnemy) -> String:
	var data: Dictionary = e.data()
	var side = data.get("meta", {}).get("Sideview Battler")
	return "sv_actors/" + str(side).strip_edges() if side != null else "sv_enemies/" + str(data.get("battlerName", ""))


static func override_of(e: XEnemy) -> Dictionary:
	var o = overrides().get("by_key", {}).get(look_key(e))
	return o if o is Dictionary else {}


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


static func reload() -> void:
	_anchors = null
	_profiles = null
	_overrides = null
	_vis_cache.clear()


## 敌人归哪套模板：先按敌人 ID，再按实战外观键（同 XAppearance.for_battler 的键）；都没有＝""（不挂）
static func profile_of(e: XEnemy) -> String:
	var p := profiles()
	var by_id: Dictionary = p.get("by_enemy", {})
	var id := str(int(e.enemy_id))
	if by_id.has(id):
		return str(by_id[id])
	return str(p.get("by_key", {}).get(look_key(e), ""))


## 这一级要挂的件（anchors.stack[级]）在这套模板里都有登记、图都在；缺一件就整级不挂
static func parts_ready(prof: String, t: String) -> bool:
	var a := anchors()
	var pr: Dictionary = a.get("profiles", {}).get(prof, {})
	var stack: Array = a.get("stack", {}).get(t, [])
	if pr.is_empty() or stack.is_empty():
		return false
	for name in stack:
		var part: Dictionary = pr.get("parts", {}).get(name, {})
		if part.is_empty() or not ResourceLoader.exists(DIR + str(part.get("path", ""))):
			return false
	return true


## 此刻该挂哪一级（""＝不挂）
static func want_tier(e) -> String:
	if not ENABLED or not e is XEnemy or not e.has_meta(XRiftAlien.LOOK):
		return ""
	if not XRiftAlien.on(XState.current):
		return ""
	return str((e.get_meta(XRiftAlien.LOOK) as Dictionary).get("tier", ""))


## XBattlerSprite._process（敌人）每帧调：级变了就重挂，没有了就拆
static func sync(s: XBattlerSprite) -> void:
	var cur: XRiftAlienParts = s.rift_parts if s.rift_parts != null and is_instance_valid(s.rift_parts) else null
	var t := want_tier(s.battler)
	if cur != null and cur.tier == t:
		if not is_instance_valid(instance_from_id(int(s.battler.get_meta(XRiftAlien.PARTS, 0)))):  # 标记的主人已不在（旧精灵退场等）：现任挂件接回
			s.battler.set_meta(XRiftAlien.PARTS, cur.get_instance_id())
		cur._follow()
		return
	if cur != null:
		cur.detach()
		s.rift_parts = null
	if t == "":
		return
	var body := s.sprite as Sprite2D
	if body == null or (s.look != null and s.look.kind == "scene"):
		return
	var prof := profile_of(s.battler as XEnemy)
	if prof == "" or not parts_ready(prof, t):
		return
	var n := XRiftAlienParts.new()
	if not n._attach(s, prof, t):
		n.free()
		return
	s.rift_parts = n
	n._follow()


## 身体待机首帧（look.frame("walk", 0)）的可见外框，按显示方向（flip_h 时左右翻），单位是原图像素、原点在一格左上
static func visible_rect(tex: Texture2D, region: Rect2, flipped: bool) -> Rect2:
	if tex == null:
		return Rect2()
	var key := "%s|%s" % [tex.resource_path if tex.resource_path != "" else str(tex.get_rid()), region]
	var r: Rect2
	if _vis_cache.has(key):
		r = _vis_cache[key]
	else:
		var img := tex.get_image()
		if img == null:
			return Rect2()
		if img.is_compressed():
			img.decompress()
		if region.has_area():
			img = img.get_region(Rect2i(region))
		var used := img.get_used_rect()
		r = Rect2(used)
		_vis_cache[key] = r
	if flipped and r.has_area():
		var w := region.size.x if region.has_area() else float(tex.get_width())
		r.position.x = w - r.end.x
	return r


func _attach(s: XBattlerSprite, prof: String, t: String) -> bool:
	var body := s.sprite as Sprite2D
	var f: Dictionary = s.look.frame("walk", 0)
	var tex: Texture2D = f.get("tex", body.texture)
	var region: Rect2 = f.get("rect", Rect2())
	var cell := region.size if region.has_area() else (Vector2(tex.get_size()) if tex else Vector2.ZERO)
	var vis := visible_rect(tex, region, body.flip_h)
	if not vis.has_area():
		return false
	var pr: Dictionary = anchors().profiles[prof]
	var ref: Array = pr.reference_visible_rect_px
	var ref_max := maxf(float(ref[2]) - float(ref[0]), float(ref[3]) - float(ref[1]))
	var ov := override_of(s.battler as XEnemy)
	var k := clampf(maxf(vis.size.x, vis.size.y) / maxf(ref_max, 1.0) * float(ov.get("k_mul", 1.0)), K_MIN, minf(K_MAX, float(ov.get("k_max", K_MAX))))
	var kb := k * float(ov.get("back_mul", 1.0))
	var back_flip := bool(ov.get("back_flip", false))
	var hide: Array = ov.get("hide", [])
	var ruv: Array = ov.get("root_uv", pr.root_uv)
	# 身体：centered、offset (0, −格高/2) → 一格左上在身体本地 (−格宽/2, −格高)
	var top_left := Vector2(-cell.x / 2.0, -cell.y)
	var root := top_left + vis.position + Vector2(float(ruv[0]), float(ruv[1])) * vis.size
	host = s
	tier = t
	profile = prof
	name = "RiftAlienBack"
	front = Node2D.new()
	front.name = "RiftAlienFront"
	var smooth := k * absf(s.body_scale) < 1.0  # 同 SV_NORM_SMOOTH：缩小时平滑、放大／原尺寸最近邻
	var filt := CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	for part_name in anchors().stack[t]:
		if hide.has(part_name):
			continue
		var part: Dictionary = pr.parts[part_name]
		var sp := Sprite2D.new()
		sp.name = str(part_name).replace("/", "_").get_basename()
		sp.texture = load(DIR + str(part.path))
		sp.centered = false
		sp.texture_filter = filt
		var rp: Array = part.root_px
		var back := str(part.get("depth", "front")) == "back"
		var kk := kb if back else k
		sp.scale = Vector2(kk, kk)
		sp.position = (root - Vector2(float(rp[0]), float(rp[1])) * kk).round()  # 落整像素（root_uv 只给四位小数）
		if back and back_flip:  # 绕根点左右翻：图内根点仍落在 root
			sp.scale.x = -kk
			sp.position.x = roundf(root.x + float(rp[0]) * kk)
		if back:
			add_child(sp)
		else:
			front.add_child(sp)
			if bool(ov.get("mask_avoid", false)):  # 返修 P2-1：模板美术已绕开脸、眼、武器，默认不再挖（挖了样本与定稿板对不上）；单独锚点的外观可点名打开
				_mask_avoid(sp, pr, top_left + vis.position, vis.size)
	body.add_child(front)
	if front.get_child_count() > 0:
		body.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	# 后件：放在战场里所有战斗者精灵前面（画在全部身体后），RemoteTransform2D 跟身体变换
	var field := s.get_parent()
	if field != null and get_child_count() > 0:
		var idx := s.get_index()
		for c in field.get_children():
			if c is XBattlerSprite:
				idx = mini(idx, c.get_index())
		field.add_child(self)
		field.move_child(self, idx)
		_remote = RemoteTransform2D.new()
		_remote.name = "RiftAlienBackFollow"
		body.add_child(_remote)
		_remote.remote_path = _remote.get_path_to(self)
	s.battler.set_meta(XRiftAlien.PARTS, get_instance_id())  # 标记记挂件实例：换图时旧精灵退场只清自己的，不清新精灵挂的
	s.tree_exiting.connect(detach)
	return true


## 前件按模板避让区挖空（区在身体可见范围的归一坐标，换到这件图的 UV）
static func _mask_avoid(sp: Sprite2D, pr: Dictionary, vis_tl: Vector2, vis_size: Vector2) -> void:
	var rects: Array = []
	var size := Vector2(sp.texture.get_size()) * sp.scale
	for r in pr.get("avoid_uv_rects", {}).values():
		if rects.size() >= 4:
			break
		var a := vis_tl + Vector2(float(r[0]), float(r[1])) * vis_size - sp.position
		var b := vis_tl + Vector2(float(r[2]), float(r[3])) * vis_size - sp.position
		rects.append(Vector4(a.x / size.x, a.y / size.y, b.x / size.x, b.y / size.y))
	if rects.is_empty():
		return
	while rects.size() < 4:
		rects.append(Vector4.ZERO)
	if _avoid_shader == null:
		_avoid_shader = Shader.new()
		_avoid_shader.code = AVOID_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _avoid_shader
	mat.set_shader_parameter("avoid", rects)
	mat.set_shader_parameter("n", pr.get("avoid_uv_rects", {}).size())
	sp.material = mat


## 后件的可见与透明度照身体（前件是身体子节点，自己跟着）
func _follow() -> void:
	if host == null or not is_instance_valid(host) or get_child_count() == 0:
		return
	var body := host.sprite
	visible = host.is_visible_in_tree() and body.visible
	modulate = host.modulate * body.modulate


func detach() -> void:
	if host != null and is_instance_valid(host):
		if host.battler != null and host.battler.get_meta(XRiftAlien.PARTS, 0) == get_instance_id():
			host.battler.remove_meta(XRiftAlien.PARTS)
		var body := host.sprite as Sprite2D
		if body != null and is_instance_valid(body):
			body.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		if host.tree_exiting.is_connected(detach):
			host.tree_exiting.disconnect(detach)
	if _remote != null and is_instance_valid(_remote):
		_remote.queue_free()
	if front != null and is_instance_valid(front):
		front.queue_free()
	host = null
	if not is_queued_for_deletion():
		queue_free()
