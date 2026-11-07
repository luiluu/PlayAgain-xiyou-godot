extends Node
## 【cc·悟空·未经审查】切片角色战斗图逐张比（工具，不进检查）：读 mv_oracle/real/actor_sv_real.cjs 在无头 Chrome 量的冻结正式源结果，
## 每 4 名一场重制战斗（敌群 1、地图 5、等级 60），等入场走完，量每名角色 XBattlerSprite 的身体：贴图、帧大小、缩放、画出来的矩形
## （相对精灵原点）、精灵位置、平滑、武器／影子；再把两边用到的图逐像素比（原版 app.nw 的 PNG 与 generated 里的源 PNG）。
## 环境变量：XIYOU_SV_REAL＝result.json，XIYOU_APP＝…/app.nw，XIYOU_SV_OUT＝输出前缀（写 .json 与 .md，只列有差异的）。
## 跑法：godot --headless --path . tests/xiyou_actor_sv_compare.tscn
const EPS_PX := 0.6
const EPS_SCALE := 0.002


func _ready() -> void:
	_run.call_deferred()


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	XMessageBox.auto = true
	if OS.get_environment("XIYOU_SV_REAL") == "":
		# 检查里（并行测试按 tests/*.tscn 全跑）没给量具结果：不比，记过
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1, "skipped": "工具场景：设 XIYOU_SV_REAL 才比"}))
		get_tree().quit.call_deferred(0)
		return
	var real = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("XIYOU_SV_REAL")))
	var app := OS.get_environment("XIYOU_APP")
	var out_prefix := OS.get_environment("XIYOU_SV_OUT")
	var ids: Array = real.actors.map(func(v): return int(v))
	# 分场跟原版量法一致：原版那场只有一名（站位 y＝378，量具一批失败后逐个重量）就单独一场，否则按次序 4 名一场
	var batches := []
	var cur := []
	for id in ids:
		var w = real.result.get(str(id), {})
		if w is Dictionary and w.has("spr") and is_equal_approx(float(w.spr[1]), 378.0):
			batches.append([id])
			continue
		cur.append(id)
		if cur.size() == 4:
			batches.append(cur)
			cur = []
	if not cur.is_empty():
		batches.append(cur)
	var got := {}
	for batch in batches:
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
		await frames(120)
		for a in b.logic.actors:
			got[int(a.actor_id)] = _snap(b.sprites[a])
		b.queue_free()
		await frames(2)
	var rows := []
	var table := []
	for id in ids:
		var w = real.result.get(str(id), {})
		var g: Dictionary = got.get(id, {})
		var diffs := _compare(w, g, app)
		rows.append({"actor": id, "name": XDB.rec("Actors", id).get("name", ""), "real": w, "remake": g, "diffs": diffs})
		for d in diffs:
			table.append("| %d %s | %s | %s | %s |" % [id, XDB.rec("Actors", id).get("name", ""), d.image, d.what, d.verdict])
	var f := FileAccess.open(out_prefix + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, " "))
	f.close()
	f = FileAccess.open(out_prefix + ".md", FileAccess.WRITE)
	f.store_string("| 角色 | 图 | 差异 | 判定 |\n| --- | --- | --- | --- |\n" + "\n".join(table) + "\n")
	f.close()
	print("SV_COMPARE=" + JSON.stringify({"actors": ids.size(), "measured": got.size(), "diffRows": table.size(),
		"actorsWithDiff": rows.filter(func(r): return not r.diffs.is_empty()).size()}))
	get_tree().quit.call_deferred(0)


func _snap(sp: XBattlerSprite) -> Dictionary:
	var body := sp.sprite as Sprite2D
	if body == null or body.texture == null:
		return {"error": "身体不是 Sprite2D 或没贴图", "kind": sp.look.kind}
	var size: Vector2 = body.region_rect.size if body.region_enabled else Vector2(body.texture.get_size())
	var sc := body.scale.abs()
	var center := body.position + body.offset * body.scale
	var rect := Rect2(center - size * sc / 2.0, size * sc)
	var filt := body.texture_filter
	if filt == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		filt = sp.texture_filter
	return {"tex": body.texture.resource_path.replace("res://modes/xiyou/generated/", ""), "frame": [size.x, size.y],
		"scale": [sc.x, sc.y], "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "pos": [sp.position.x, sp.position.y],
		"smooth": filt in [CanvasItem.TEXTURE_FILTER_LINEAR, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS],
		"weapon": sp.weapon != null and sp.weapon.visible, "shadow": sp.shadow != null and sp.shadow.visible, "motion": sp.motion}


func _compare(w, g: Dictionary, app: String) -> Array:
	var out := []
	if not (w is Dictionary) or w.has("error") or w.is_empty():
		return [{"image": "战斗图", "what": "原版没量到：" + str(w.get("error", "") if w is Dictionary else w), "verdict": "待查"}]
	if g.has("error") or g.is_empty():
		return [{"image": "战斗图", "what": "重制没量到：" + str(g.get("error", "没出战")), "verdict": "待查"}]
	var wu := str(w.url).trim_prefix("img/")
	var gu := str(g.tex).trim_prefix("img/")
	var img := wu.get_file()
	# 167 号以后的逐帧图（sv_actors/sv/<名>/ 每帧一张）：两边取到的帧随动作相位不同，只比文件夹，像素按两边各自那张同名比
	var multi := wu.contains("/sv/")
	if (wu.get_base_dir() != gu.get_base_dir()) if multi else (wu != gu):
		out.append({"image": img, "what": "图不同：原版 %s，重制 %s" % [wu, gu], "verdict": "待查"})
	var wf: Array = w.frame
	if absf(float(wf[2]) - float(g.frame[0])) > 0.01 or absf(float(wf[3]) - float(g.frame[1])) > 0.01:
		out.append({"image": img, "what": "帧大小 %s×%s→%s×%s" % [wf[2], wf[3], g.frame[0], g.frame[1]], "verdict": "待查"})
	var ws: Array = w.scale
	if absf(absf(float(ws[0])) - float(g.scale[0])) > EPS_SCALE or absf(float(ws[1]) - float(g.scale[1])) > EPS_SCALE:
		out.append({"image": img, "what": "缩放 %s→%s" % [_fmt(ws), _fmt(g.scale)], "verdict": "会改变显示"})
	var sx := absf(float(ws[0]))
	var sy := float(ws[1])
	var wr := [float(w.pos[0]) - float(w.anchor[0]) * float(wf[2]) * sx, float(w.pos[1]) - float(w.anchor[1]) * float(wf[3]) * sy, float(wf[2]) * sx, float(wf[3]) * sy]
	var bad := false
	for k in 4:
		if absf(wr[k] - float(g.rect[k])) > EPS_PX:
			bad = true
	if bad:
		out.append({"image": img, "what": "画出的矩形（左,上,宽,高）%s→%s" % [_fmt(wr), _fmt(g.rect)], "verdict": "会改变显示"})
	if absf(float(w.spr[0]) - float(g.pos[0])) > 1.0 or absf(float(w.spr[1]) - float(g.pos[1])) > 1.0:
		out.append({"image": img, "what": "站位 %s→%s" % [_fmt(w.spr), _fmt(g.pos)], "verdict": "会改变显示"})
	if bool(w.smooth) != bool(g.smooth):
		out.append({"image": img, "what": "平滑 %s→%s" % [w.smooth, g.smooth], "verdict": "会改变显示"})
	# 武器不比：待机时原版武器精灵 visible 恒真但没图（只有攻击动作才放武器）
	if bool(w.shadow) != bool(g.shadow):
		out.append({"image": img, "what": "影子 %s→%s" % [w.shadow, g.shadow], "verdict": "待查"})
	# 逐像素：同一张图（原版 app.nw 的源 PNG 与 generated 的源 PNG）；逐帧图两边各取的那张都比
	for name in ([wu, gu] if multi and wu != gu else [wu]):
		_pixels(out, app, name)
	return out


func _pixels(out: Array, app: String, name: String) -> void:
	var img := name.get_file()
	var src := _load_by_content(app.path_join("img").path_join(name))
	var dst := Image.load_from_file(ProjectSettings.globalize_path("res://modes/xiyou/generated/img/" + name))
	if src == null or dst == null:
		out.append({"image": img, "what": "读不出图（原版 %s，重制 %s）" % [src != null, dst != null], "verdict": "待查"})
	elif src.get_size() != dst.get_size():
		out.append({"image": img, "what": "图尺寸 %s→%s" % [src.get_size(), dst.get_size()], "verdict": "待查"})
	else:
		src.convert(Image.FORMAT_RGBA8)
		dst.convert(Image.FORMAT_RGBA8)
		if src.get_data() != dst.get_data():
			var n := 0
			for y in src.get_height():
				for x in src.get_width():
					if src.get_pixel(x, y) != dst.get_pixel(x, y):
						n += 1
			out.append({"image": img, "what": "像素不同 %d 个（共 %d）" % [n, src.get_width() * src.get_height()], "verdict": "待查"})


## 原版有 .png 扩展名、内容是 JPEG／WebP 的图（162 诛仙 guanxi7_1）：NW.js 按内容解码，这里也按内容读
func _load_by_content(path: String) -> Image:
	var buf := FileAccess.get_file_as_bytes(path)
	if buf.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if buf[0] == 0xFF and buf[1] == 0xD8:
		err = img.load_jpg_from_buffer(buf)
	elif buf.slice(0, 4).get_string_from_ascii() == "RIFF" and buf.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(buf)
	else:
		err = img.load_png_from_buffer(buf)
	return img if err == OK else null


func _fmt(v: Array) -> String:
	return "(" + ",".join(v.map(func(x): return str(snappedf(float(x), 0.01)))) + ")"
