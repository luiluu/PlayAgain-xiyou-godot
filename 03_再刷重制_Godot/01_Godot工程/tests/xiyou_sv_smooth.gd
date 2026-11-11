extends Node
## 【cc·悟空·未经审查】v0.62 SV 归一平滑（Codex_MiraRavenMultiFrame v1.06 applyVisual：bitmap.smooth = scale < 1）守卫。
## 参照 mv_oracle/real/actor_sv.result.json（actor_sv_real.cjs 在无头 Chrome 量 v0.62.12）：168、174、175、179 归一缩小 → 平滑；
## 167、169～173、176～178 放大或原尺寸、162～165 旧角色 → 不平滑。
## 162 诛仙另守：原版图 guanxi7_1 是 .png 扩展名的 JPEG，早年导入失败留下 valid=false 的 .import，转成真 PNG 后 Godot 不重导，战斗图是空的；
## 这里查 generated/img 下没有 valid=false 的 .import（xiyou_export.py 遇到会删掉重导）。开关 XBattlerSprite.SV_NORM_SMOOTH（O-298）开、关各一组：
## 身体采样方式；画的那一帧与源 PNG 逐像素相同（开关只换采样，不换图、不改像素）；变大装备（fd）把缩放推到 ≥1 时回到最近邻。
## 无头跑没有真实渲染，画到屏幕上的像素这里量不到，靠 tests/xiyou_actor_sv_compare.tscn 对原版量具比采样标记。
const SMOOTH := [168, 174, 175, 179]
const CRISP := [162, 163, 165, 167, 169, 170, 172, 173, 176, 178]
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _body(sp: XBattlerSprite) -> Sprite2D:
	return sp.sprite as Sprite2D


func _smooth(sp: XBattlerSprite) -> bool:
	var body := _body(sp)
	var f := body.texture_filter
	if f == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		f = sp.texture_filter
	return f in [CanvasItem.TEXTURE_FILTER_LINEAR, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS]


func _pixels(sp: XBattlerSprite) -> PackedByteArray:
	var body := _body(sp)
	var img := body.texture.get_image()
	if img == null:
		return PackedByteArray()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if body.region_enabled:
		img = img.get_region(Rect2i(body.region_rect))
	return img.get_data()


## 一场里放这几名，等入场走完，量每名身体；返回 {id: {smooth, scale, px, tex}}
func _measure(ids: Array) -> Dictionary:
	var out := {}
	for i in range(0, ids.size(), 4):
		var batch: Array = ids.slice(i, i + 4)
		var s := XState.new_game_blank()
		XState.current = s
		s.actor_max_level = 99
		s.switches[2494] = true
		s.party.clear()
		s.battle_slots.clear()
		for id in batch:
			s.actor(id).change_level_mv(60)
			s.add_actor(id)
			s.actor(id).recover_all()
		var b := XBattleScene.new()
		b.setup(1, true, false, XDB.map(5))
		add_child(b)
		await frames(60)
		for a in b.logic.actors:
			var sp: XBattlerSprite = b.sprites[a]
			if _body(sp) == null or _body(sp).texture == null:
				out[int(a.actor_id)] = {"error": "没身体"}
				continue
			var rec := {"smooth": _smooth(sp), "scale": absf(_body(sp).scale.y), "px": _pixels(sp),
				"tex": _body(sp).texture.resource_path, "region": _body(sp).region_rect}
			# 变大装备把缩放推到 ≥1：照原版 scaleFor（baseScale×growth）回到最近邻；推回 1 再恢复
			if int(a.actor_id) in SMOOTH:
				var keep := sp.fd
				sp.fd = 2.0
				sp._apply_smooth()
				rec["grown"] = _smooth(sp)
				sp.fd = keep
				sp._apply_smooth()
				rec["back"] = _smooth(sp)
			out[int(a.actor_id)] = rec
		b.queue_free()
		await frames(2)
	return out


func _source_pixels(path: String, region: Rect2) -> PackedByteArray:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return PackedByteArray()
	img.convert(Image.FORMAT_RGBA8)
	if region.has_area():
		img = img.get_region(Rect2i(region))
	return img.get_data()


## 逐像素差：透明度不同的点数；alpha≥20 的点颜色不同的点数（alpha<20 的点 RGB 导入时被 fix_alpha_border 改过，不算；透明度照样逐点比）
func _diff(a: PackedByteArray, b: PackedByteArray) -> Dictionary:
	if a.size() != b.size():
		return {"alpha": -1, "rgb": -1, "size": [a.size(), b.size()]}
	var da := 0
	var dc := 0
	for i in range(0, a.size(), 4):
		if a[i + 3] != b[i + 3]:
			da += 1
		elif a[i + 3] >= 20 and (a[i] != b[i] or a[i + 1] != b[i + 1] or a[i + 2] != b[i + 2]):
			dc += 1
	return {"alpha": da, "rgb": dc}


func _invalid_imports(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import") and FileAccess.get_file_as_string(dir + "/" + f).contains("valid=false"):
			out.append(dir.trim_prefix("res://modes/xiyou/generated/") + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_invalid_imports(dir + "/" + d))
	return out


func _run() -> void:
	XMessageBox.auto = true
	var ids: Array = SMOOTH + CRISP
	check("switch_default_on", XBattlerSprite.SV_NORM_SMOOTH == true)
	var bad := _invalid_imports("res://modes/xiyou/generated/img")
	check("imports_valid", bad.is_empty(), bad)
	XBattlerSprite.SV_NORM_SMOOTH = true
	var on := await _measure(ids)
	XBattlerSprite.SV_NORM_SMOOTH = false
	var off := await _measure(ids)
	XBattlerSprite.SV_NORM_SMOOTH = true
	for id in ids:
		var a: Dictionary = on.get(id, {"error": "没出战"})
		var z: Dictionary = off.get(id, {"error": "没出战"})
		check("on.%d.measured" % id, not a.has("error"), a.get("error"))
		check("off.%d.measured" % id, not z.has("error"), z.get("error"))
		if a.has("error") or z.has("error"):
			continue
		var want: bool = id in SMOOTH
		check("on.%d.smooth" % id, a.smooth == want, [a.smooth, a.scale])
		check("off.%d.crisp" % id, z.smooth == false, [z.smooth, z.scale])
		check("on.%d.scale_side" % id, (a.scale < 1.0) == want or not (id >= 167), a.scale)
		# 逐像素：画的那一帧（贴图＋区域）与磁盘上的源 PNG 同区域逐字节相同，开、关各比一次（开关只换采样，不换图、不改像素）
		for side in [["on", a], ["off", z]]:
			var r: Dictionary = side[1]
			var src := _source_pixels(r.tex, r.region)
			check("px.%s.%d.nonempty" % [side[0], id], (r.px as PackedByteArray).size() > 0, r.tex)
			var d := _diff(r.px, src)
			check("px.%s.%d.matches_png" % [side[0], id], src.size() > 0 and d.alpha == 0 and d.rgb == 0, [r.tex, d])
		if want:
			check("on.%d.grown_crisp" % id, a.grown == false)
			check("on.%d.back_smooth" % id, a.back == true)
			check("off.%d.grown_crisp" % id, z.grown == false)
			check("off.%d.back_crisp" % id, z.back == false)
	_finish()


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
