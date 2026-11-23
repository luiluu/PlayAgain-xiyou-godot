extends Node
## 【小A·未经审查】三阶漫画动画③实时特效专项（T428；分镜 v0.5 拆卡 3）：
## 覆盖：comic_halftone.gdshader 加载与 gl_compatibility 兼容、P1 实机 Map004 缩入左格与网点缓推、
## P10 两半斜切滑开透出真实 Map004、CPUParticles2D 碎格粒子总预算 <= 120、
## P11 破边残格与尖尾气泡防遮挡、P11b 21.2s 紫闪仅限框边不染正文、P11d 碎纸退场与播完/跳过零节点泄漏。
## 截图：带窗口跑加 --audio-driver Dummy ++ --shot=<目录>（无头时不截）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var passed := 0
var total := 0
var out_dir := ""


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			out_dir = arg.substr(7)
	_run.call_deferred()


func frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func shot(filename: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	var err := get_viewport().get_texture().get_image().save_png(out_dir.path_join(filename))
	check("shot." + filename.get_basename(), err == OK, err)


func _open_map004() -> XMapScene:
	# 标为已看 rift1/rift2/rift3，既展示二阶幽紫漩涡（CELL=14,19）又避免自动触发旧 rift3 过场抢占镜头
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	XConfig.whisper_mark("rift3")
	XRift.STAGE2 = true
	XRift.STAGE3 = true
	XFestLobby.ENABLED = false
	XGuide.MILESTONE_ENABLED = false
	XRift.clear_cache()
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = XRift.CELL.x
	s.y = XRift.CELL.y + 3
	var map := XMapScene.new()
	add_child(map)
	return map


func _hide_stray_popups() -> void:
	# 测试截屏专用：清掉新档开局自带的 toast／成就弹窗，不干扰漫画层截图
	var root := get_tree().root
	for ch in root.get_children():
		if ch is CanvasLayer and ch.layer >= 89:
			ch.visible = false


func _sum_particle_amounts(node: Node) -> Dictionary:
	var total_amt := 0
	var count := 0
	var detail := {}
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is CPUParticles2D or cur is GPUParticles2D:
			var amt := int(cur.amount)
			total_amt += amt
			count += 1
			detail[cur.name] = amt
		for ch in cur.get_children():
			stack.append(ch)
	return {"total": total_amt, "count": count, "detail": detail}


func _sample_patch_stats(img: Image, rect: Rect2i) -> Dictionary:
	var min_l := 1.0
	var max_l := 0.0
	var sat_sum := 0.0
	var n := 0
	var x0 := clampi(rect.position.x, 0, img.get_width() - 1)
	var y0 := clampi(rect.position.y, 0, img.get_height() - 1)
	var x1 := clampi(rect.position.x + rect.size.x, x0 + 1, img.get_width())
	var y1 := clampi(rect.position.y + rect.size.y, y0 + 1, img.get_height())
	for y in range(y0, y1, 4):
		for x in range(x0, x1, 4):
			var c := img.get_pixel(x, y)
			var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			min_l = minf(min_l, l)
			max_l = maxf(max_l, l)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			sat_sum += (mx - mn)
			n += 1
	return {"min_l": min_l, "max_l": max_l, "contrast": max_l - min_l, "avg_sat": sat_sum / maxf(float(n), 1.0), "samples": n}


func _patch_diff(a: Image, b: Image, rect: Rect2i) -> float:
	var diff := 0.0
	var n := 0
	for y in range(rect.position.y, rect.position.y + rect.size.y, 6):
		for x in range(rect.position.x, rect.position.x + rect.size.x, 6):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			diff += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 1
	return diff / maxf(float(n) * 3.0, 1.0)


func _run() -> void:
	TestEnv.isolate("xiyou_rift3_anim_fx", false)
	var old_enabled := XRift3Anim.ENABLED
	var old_stage3 := XRift.STAGE3
	XRift3Anim.ENABLED = true
	XRift.STAGE3 = true

	_test_shader_asset()
	await _test_fx_over_real_map004()
	await _test_skip_cleanup_no_leak()

	XRift3Anim.ENABLED = old_enabled
	XRift.STAGE3 = old_stage3
	XRift3Anim.missed_lines.clear()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _test_shader_asset() -> void:
	check("shader.exists", ResourceLoader.exists(XRift3Anim.SHADER_HALFTONE))
	var sh = load(XRift3Anim.SHADER_HALFTONE)
	check("shader.is_shader", sh is Shader, sh)
	var code := FileAccess.get_file_as_string(XRift3Anim.SHADER_HALFTONE)
	check("shader.canvas_item", code.contains("shader_type canvas_item;"))
	check("shader.no_hint_screen", not code.contains("hint_screen_texture") and not code.contains("SCREEN_TEXTURE"))
	check("particles.budget_const", XRift3Anim.total_shard_budget() <= XRift3Anim.MAX_TOTAL_SHARDS and XRift3Anim.MAX_TOTAL_SHARDS == 120, XRift3Anim.total_shard_budget())


func _test_fx_over_real_map004() -> void:
	var map := _open_map004()
	await frames(6)
	_hide_stray_popups()
	await frames(1)
	var is_gui := DisplayServer.get_name() != "headless"
	var lobby_baseline: Image = null
	var lobby_tex: Texture2D = null
	if is_gui:
		RenderingServer.force_draw()
		lobby_baseline = get_viewport().get_texture().get_image()
		lobby_tex = ImageTexture.create_from_image(lobby_baseline)
	else:
		# 无头模式仍喂入一张带方桌与紫色漩涡的模拟 Map004 视口纹理
		var img := Image.create(320, 180, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.55, 0.52, 0.48, 1.0))
		img.fill_rect(Rect2i(136, 66, 48, 48), XRift3Anim.COLOR_PURPLE)
		lobby_tex = ImageTexture.create_from_image(img)

	var base_children := get_child_count()
	var anim := XRift3Anim.play(self, lobby_tex, true)
	check("fx.created", anim != null)
	if anim == null:
		map.queue_free()
		await frames(2)
		return
	anim.set_process(false)
	var done_flag := [false]
	anim.finished.connect(func(): done_flag[0] = true)

	# 1) 全树粒子节点审计：CPUParticles2D 总和 <= 120
	var pinfo := _sum_particle_amounts(anim)
	check("particles.tree_sum_le_120", int(pinfo.total) > 0 and int(pinfo.total) <= 120 and int(pinfo.count) == 2, pinfo)
	check("particles.p10_and_p11_split", int(anim.state().p10_shards_amount) == 96 and int(anim.state().p11_shards_amount) == 20 and int(anim.state().total_shard_particles) == 116, anim.state())

	# 2) P1 实时入格 Shader 与 0.0–0.30s 收束、0.30–2.60s 缓推
	check("p1.shader_attached", bool(anim.state().p1_shader_ready) and anim._p1_tex_rect.material is ShaderMaterial)
	anim.step(0.06)
	var st_p1_early := anim.state()
	var early_rect: Rect2 = st_p1_early.p1_frame_rect
	check("p1.shrinking_at_0_06s", early_rect.size.x > XRift3Anim.P1_TARGET_RECT.size.x + 20.0 and float(st_p1_early.p1_mix_amount) > 0.05 and float(st_p1_early.p1_mix_amount) < 0.95, st_p1_early)

	anim.step(1.00 - float(anim.state().t))
	await frames(2)
	var st_p1_settle := anim.state()
	var settle_rect: Rect2 = st_p1_settle.p1_frame_rect
	check("p1.settled_target_rect", settle_rect.position.distance_to(XRift3Anim.P1_TARGET_RECT.position) < 1.5 and settle_rect.size.distance_to(XRift3Anim.P1_TARGET_RECT.size) < 1.5 and absf(float(st_p1_settle.p1_mix_amount) - 1.0) < 0.001, settle_rect)
	check("p1.narration_below_frame", anim._narration_p1_box.visible and anim._narration_p1_box.position.y >= settle_rect.end.y + 10.0, [anim._narration_p1_box.position, settle_rect])
	if is_gui:
		RenderingServer.force_draw()
		var p1_img := get_viewport().get_texture().get_image()
		var p1_stats := _sample_patch_stats(p1_img, Rect2i(64, 72, 220, 220))
		check("p1.gpu_halftone_contrast_and_bw", p1_stats.contrast > 0.45 and p1_stats.avg_sat < 0.14, p1_stats)
		await shot("01_p1_halftone.png")

	anim.step(2.40 - float(anim.state().t))
	check("p1.slow_push_zoom", float(anim.state().p1_zoom) > 1.03 and float(anim.state().p1_zoom) <= 1.041, anim.state().p1_zoom)

	# 3) P10 实时劈页：无全屏不透明遮挡底板，两半斜切滑开实时透出 Map004，碎格粒子触发
	var p10_opaque_bg := false
	for ch in anim._p10_layer.get_children():
		if ch is ColorRect and ch.visible and ch.size.x >= 1200.0 and ch.size.y >= 700.0 and ch.color.a > 0.5:
			p10_opaque_bg = true
	check("p10.no_opaque_backdrop", not p10_opaque_bg)

	# 15.05s 反色冲击帧＋重震屏＋「斩」
	anim.step(15.05 - float(anim.state().t))
	await frames(1)
	check("p10.impact_invert_and_blade", anim.state().phase == XRift3Anim.Phase.P10 and bool(anim.state().p10_halves_visible) and float(anim._p10_half_mat.get_shader_parameter("invert_amount")) > 0.95 and (anim.state().active_sfx_ids as Array).has("p10_slash"), anim.state())

	# 15.22s 斜裂外透白光＋「斩」截图
	anim.step(15.22 - float(anim.state().t))
	await frames(2)
	check("p10.crack_open_glow", float(anim.state().p10_split_gap) > 6.0 and anim._p10_slash_white_poly.visible and anim._p10_slash_red_poly.visible, anim.state())
	await shot("02_p10_slash_split.png")

	# 15.75s 两半大幅滑开＋碎格粒子爆发＋M6 挥斩冲出
	anim.step(15.75 - float(anim.state().t))
	await frames(3)
	check("p10.halves_sliding_and_shards_fired", float(anim.state().p10_split_gap) > 120.0 and bool(anim.state().p10_shards_fired) and anim._p10_slash_rect.visible, anim.state())
	await shot("03_p10_shards_reveal.png")

	# 17.20s 两半与 M6 已清出，裂口后实时透出真实 Map004
	anim.step(17.20 - float(anim.state().t))
	await frames(3)
	check("p10.halves_cleared_reveals_lobby", not bool(anim.state().p10_halves_visible) and not anim._p10_slash_white_poly.visible, anim.state())
	if is_gui and lobby_baseline != null:
		RenderingServer.force_draw()
		var reveal_img := get_viewport().get_texture().get_image()
		var center_diff := _patch_diff(lobby_baseline, reveal_img, Rect2i(420, 200, 440, 320))
		check("p10.gpu_real_map004_visible", center_diff < 0.12, center_diff)

	# 4) P11a~c 破边残格与右侧尖尾气泡（不挡关键读字、2 行自然排版、名签常驻）
	anim.step(18.20 - float(anim.state().t))
	await frames(2)
	var shard_r := anim._p11_portrait_box.get_global_rect()
	var bubble_r := anim._speech_bubble_box.get_global_rect()
	var name_r := anim._speech_nameplate.get_global_rect()
	var text_r := anim._speech_text_label.get_global_rect()
	check("p11a.no_overlap_shard_bubble", shard_r.end.x < bubble_r.position.x, [shard_r, bubble_r])
	check("p11a.no_overlap_nameplate_text", name_r.end.y <= text_r.position.y + 4.0, [name_r, text_r])
	check("p11a.tail_and_2line_fit", anim._speech_tail_white.visible and anim._speech_text_label.get_line_count() <= 2 and bubble_r.end.x <= 1280.0 and bubble_r.end.y <= 720.0, {"lines": anim._speech_text_label.get_line_count(), "bubble": bubble_r})
	await shot("04_p11a_sense_bubble.png")

	# P11b 21.25s：仅残格破边与气泡外角单拍紫闪，正文保持纯深墨 #0B0B0E 不变紫
	anim.step(21.25 - float(anim.state().t))
	await frames(2)
	var hint_col: Color = anim._speech_text_label.get_theme_color("font_color")
	check("p11b.purple_edge_only_not_text", bool(anim.state().p11_purple_edge_active) and anim._speech_purple_corner.visible and hint_col.is_equal_approx(XRift3Anim.COLOR_INK) and anim._speech_text_label.get_line_count() <= 2, {"color": hint_col.to_html(false), "lines": anim._speech_text_label.get_line_count()})
	await shot("05_p11b_hint_purple_edge.png")

	# P11c 23.40s：幽紫退尽，follow 2 行舒展排版
	anim.step(23.40 - float(anim.state().t))
	await frames(2)
	check("p11c.purple_gone_follow_2line", not bool(anim.state().p11_purple_edge_active) and not anim._speech_purple_corner.visible and anim._speech_text_label.get_line_count() <= 2, anim._speech_text_label.get_line_count())

	# P11d 25.05s：残格与气泡退场，末段 20 片碎纸飘散，底部 after 旁白条 #DCDCE0 居中不越界
	anim.step(25.05 - float(anim.state().t))
	await frames(3)
	var end_r := anim._narration_end_box.get_global_rect()
	check("p11d.shards_fired_and_after_bar", not anim._p11_portrait_box.visible and not anim._speech_group.visible and bool(anim.state().p11_shards_fired) and anim._narration_end_box.visible and end_r.position.y >= 580.0 and end_r.end.y <= 710.0, {"fired": anim.state().p11_shards_fired, "end_rect": end_r})
	await shot("06_p11d_scatter_after.png")

	# 5) 播满 26.0s：自动淡出清理干净，零节点泄漏
	anim.step(26.0 - float(anim.state().t))
	await frames(2)
	check("cleanup.natural_finish_freed", done_flag[0] and not is_instance_valid(anim) and get_child_count() == base_children and XRift3Anim.missed_lines.is_empty(), {"children": get_child_count(), "expected": base_children})

	map.queue_free()
	await frames(2)


func _test_skip_cleanup_no_leak() -> void:
	# 粒子发射中途（15.70s）触发跳过：压黑结束后节点与粒子完全释放、无残留
	var base_children := get_child_count()
	var anim := XRift3Anim.play(self, null, true)
	anim.set_process(false)
	var done_flag := [false]
	anim.finished.connect(func(): done_flag[0] = true)
	anim.step(15.70)
	check("skip_leak.shards_active_mid_p10", bool(anim.state().p10_shards_fired))
	anim.step(0.05, true)
	anim.step(XRift3Anim.SKIP_FADE_SEC + 0.05)
	await frames(2)
	check("skip_leak.freed_cleanly", done_flag[0] and not is_instance_valid(anim) and get_child_count() == base_children, {"children": get_child_count(), "expected": base_children})
