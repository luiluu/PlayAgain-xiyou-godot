extends Node
## 【小A·未经审查】三阶徐凤年回归漫画动画播放器骨架专项（T425；分镜 v0.5 拆卡 2，文字按 v0.5 第 7 节定稿）。
## 覆盖：available() 资源与开关守卫、CanvasLayer 层级 88、Engine.time_scale=1.6 真实秒计时、
## 0.8s 保护期单次跳过、1.0s/10.0s/23.0s 与临界阈值写 missed_lines、播满 26.0s missed_lines 为空、
## 四段状态机、7 拟声＋1 刀意字「斩」叠字时间码、P1 去标头旁白框、P11 名签常驻整句即显、after 字色 #DCDCE0、
## 5 句正文直读 XRift.RIFT3_LINES 零重复写死。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestEnv.isolate("xiyou_rift3_anim_player", false)
	var old_enabled := XRift3Anim.ENABLED
	var old_stage3 := XRift.STAGE3
	var old_ts := Engine.time_scale
	XRift3Anim.ENABLED = true
	XRift.STAGE3 = true
	XRift3Anim._asset_exists_override = Callable()

	_test_available_guard()
	_test_source_no_duplicate_lines()
	_test_v05_sfx_metadata()
	await _test_time_scale_real_seconds()
	await _test_skip_guard_and_missed_lines()
	await _test_full_play_and_cues()

	XRift3Anim._asset_exists_override = Callable()
	XRift3Anim.missed_lines.clear()
	XRift3Anim.ENABLED = old_enabled
	XRift.STAGE3 = old_stage3
	Engine.time_scale = old_ts
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _test_available_guard() -> void:
	# 1) 当前工程尚无 4 个必需漫画资产，available() 必为 false 且 play() 返回 null 不报错
	check("avail.missing_assets_false", not XRift3Anim.available())
	check("avail.play_null_when_missing", XRift3Anim.play(self) == null)

	# 2) 模拟 4 个必需资产全齐 → available() 为 true
	XRift3Anim._asset_exists_override = func(_p: String) -> bool: return true
	check("avail.all_present_true", XRift3Anim.available())

	# 3) 逐个缺任一必需资产 → available() 为 false
	for i in XRift3Anim.REQUIRED_ASSETS.size():
		var missing := XRift3Anim.REQUIRED_ASSETS[i]
		XRift3Anim._asset_exists_override = func(p: String) -> bool: return p != missing
		check("avail.missing_one_%d" % i, not XRift3Anim.available(), missing)

	# 4) 开关守卫：ENABLED=false 或 XRift.STAGE3=false 时即使资产全齐也返回 false
	XRift3Anim._asset_exists_override = func(_p: String) -> bool: return true
	XRift3Anim.ENABLED = false
	check("avail.switch_enabled_off", not XRift3Anim.available())
	XRift3Anim.ENABLED = true
	XRift.STAGE3 = false
	check("avail.switch_stage3_off", not XRift3Anim.available())
	XRift.STAGE3 = true
	XRift3Anim._asset_exists_override = Callable()


func _test_source_no_duplicate_lines() -> void:
	var src := FileAccess.get_file_as_string("res://modes/xiyou/ui/rift3_anim.gd")
	check("src.readable", src.length() > 100)
	# 5 句审定台词正文直读 XRift.RIFT3_LINES，源码零重复写死
	var snippets := [
		"从那头漏过来了",
		"天地气机一乱",
		"怕是连模样都要换了",
		"这一程，我跟你走",
		"好像又来了一个人",
	]
	for i in snippets.size():
		check("src.no_hardcoded_line_%d" % i, not src.contains(snippets[i]), snippets[i])
	# 禁止直调 set_input_as_handled（必须走 XKeyMap.handled）
	check("src.uses_xkeymap_handled", src.contains("XKeyMap.handled(self)") and not src.contains("set_input_as_handled"))


func _test_v05_sfx_metadata() -> void:
	# v0.5 第 7.2 节定稿：7 处拟声字＋1 处唯一刀意字「斩」，零双叹号
	var sfx_count := 0
	var blade_texts: Array[String] = []
	var texts: Array[String] = []
	for cue in XRift3Anim.SFX_CUES:
		texts.append(str(cue.text))
		if str(cue.kind) == "sfx":
			sfx_count += 1
		elif str(cue.kind) == "blade":
			blade_texts.append(str(cue.text))
	check("v05.sfx_7_plus_blade_1", sfx_count == 7 and blade_texts == ["斩"], {"sfx": sfx_count, "blade": blade_texts})
	check("v05.sfx_exact_texts", texts == ["嗡——", "咔嚓！", "嘶啦！", "轰——！", "唰！", "铮！", "锵——！", "斩"], texts)


func _test_time_scale_real_seconds() -> void:
	var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.25, 1.0))
	var tex := ImageTexture.create_from_image(img)
	var anim := XRift3Anim.play(self, tex, true)
	check("ts.created", anim != null)
	if anim == null:
		return
	check("ts.layer_88", anim.layer == 88 and anim is CanvasLayer, anim.layer)
	check("ts.placeholder_mode", anim.state().placeholder_mode)
	check("ts.viewport_tex_bound", anim._p1_tex_rect.texture == tex)

	# 1) 确定性 _process 校验：Engine.time_scale = 1.6 时，真实 0.10s 对应引擎 delta = 0.16s
	anim.set_process(false)
	Engine.time_scale = 1.6
	anim._process(0.16)
	check("ts.process_real_sec", absf(float(anim.state().t) - 0.10) < 0.001, anim.state().t)
	check("ts.video_speed_scale", absf(anim._video_player.speed_scale - (1.0 / 1.6)) < 0.001, anim._video_player.speed_scale)

	# 2) 再推进 10 次真实 0.05s（每次传 delta = 0.08s），累计应为 0.60s 而非 0.96s
	for _i in range(10):
		anim._process(0.08)
	check("ts.process_accum_real_sec", absf(float(anim.state().t) - 0.60) < 0.002, anim.state().t)

	# 3) 真实帧循环回归：在 process_frame 信号点（各节点 _process 之前）开关并累加当帧 delta，6 帧精确一一对应
	await get_tree().process_frame
	var t_before := float(anim.state().t)
	var raw_delta_sum := 0.0
	anim.set_process(true)
	for _i in range(6):
		raw_delta_sum += get_process_delta_time()
		await get_tree().process_frame
	anim.set_process(false)
	var anim_delta := float(anim.state().t) - t_before
	check("ts.live_frame_not_accelerated", raw_delta_sum > 0.0 and absf(anim_delta - raw_delta_sum / 1.6) < 0.001, {"anim_delta": anim_delta, "raw_delta_sum": raw_delta_sum, "expected": raw_delta_sum / 1.6})

	Engine.time_scale = 1.0
	anim.queue_free()
	await get_tree().process_frame


func _make_key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.echo = false
	return ev


func _run_skip_case(skip_at: float) -> Dictionary:
	var anim := XRift3Anim.play(self, null, true)
	anim.set_process(false)
	var done_flag := [false]
	anim.finished.connect(func(): done_flag[0] = true)
	anim.step(skip_at, true)
	var mid_state := anim.state()
	var finished_immediately: bool = done_flag[0]
	anim.step(XRift3Anim.SKIP_FADE_SEC * 0.5)
	var half_done: bool = done_flag[0]
	var half_fade := float(anim.state().fade)
	anim.step(XRift3Anim.SKIP_FADE_SEC)
	var end_done: bool = done_flag[0]
	var end_fade := float(anim.state().fade)
	var missed := XRift3Anim.missed_lines.duplicate()
	await get_tree().process_frame
	return {
		"mid_skipping": bool(mid_state.skipping),
		"skip_time": float(mid_state.skip_time),
		"finished_immediately": finished_immediately,
		"half_done": half_done,
		"half_fade": half_fade,
		"end_done": end_done,
		"end_fade": end_fade,
		"missed": missed,
	}


func _test_skip_guard_and_missed_lines() -> void:
	# 1) <0.8s 保护期：按键与 step(skip=true) 均被忽略，且不会延迟到 0.8s 后触发
	var guard := XRift3Anim.play(self, null, true)
	guard.set_process(false)
	guard.step(0.3, true)
	check("guard.ignore_0_3s", not guard.state().skipping and XRift3Anim.missed_lines.is_empty(), guard.state())
	guard._input(_make_key_event(KEY_SPACE))
	guard.step(0.49, true)  # t = 0.79s，仍在保护期
	check("guard.ignore_0_79s", not guard.state().skipping and not guard._pressed, guard.state())
	guard.step(0.10, false)  # 跨过 0.8s 到 0.89s，不按键不应自动跳过
	check("guard.no_delayed_skip", not guard.state().skipping and XRift3Anim.missed_lines.is_empty(), guard.state())
	# 跨过 0.8s 后通过真实 _input 触发跳过
	guard._input(_make_key_event(KEY_SPACE))
	check("guard.input_accepted_after_0_8s", guard._pressed)
	guard.step(0.01, guard._pressed)
	guard._pressed = false
	check("guard.skip_started_after_0_8s", guard.state().skipping and XRift3Anim.missed_lines.size() == 5, XRift3Anim.missed_lines)
	guard.step(XRift3Anim.SKIP_FADE_SEC)
	await get_tree().process_frame

	# 2) 分镜验收 3 个代表时刻：1.0s → 5 条，10.0s → 4 条，23.0s → 2 条
	var c1 := await _run_skip_case(1.0)
	check("skip.1_0s_missed_5", c1.mid_skipping and not c1.finished_immediately and not c1.half_done and c1.end_done and absf(c1.end_fade - 1.0) < 0.001 and c1.missed == ["whisper", "sense", "hint", "follow", "after"], c1)

	var c10 := await _run_skip_case(10.0)
	check("skip.10_0s_missed_4", c10.end_done and c10.missed == ["sense", "hint", "follow", "after"], c10)

	var c23 := await _run_skip_case(23.0)
	check("skip.23_0s_missed_2", c23.end_done and c23.missed == ["follow", "after"], c23)

	# 3) 跳过瞬间时间码冻结校验：2.10s 跳过走完 0.25s 压黑后仍按 2.10s (<2.2s) 计，whisper 仍要补播
	var c21 := await _run_skip_case(2.10)
	check("skip.2_10s_freeze_before_fade", c21.end_done and absf(c21.skip_time - 2.10) < 0.001 and c21.missed == ["whisper", "sense", "hint", "follow", "after"], c21)

	# 4) 临界阈值校验：2.20s 已看全 whisper，25.69s 仅缺 after，25.70s 全看全
	var c22 := await _run_skip_case(2.20)
	check("skip.2_20s_whisper_seen", c22.missed == ["sense", "hint", "follow", "after"], c22)
	var c2569 := await _run_skip_case(25.69)
	check("skip.25_69s_only_after", c2569.missed == ["after"], c2569)
	var c2570 := await _run_skip_case(25.70)
	check("skip.25_70s_all_seen", c2570.missed.is_empty(), c2570)


func _test_full_play_and_cues() -> void:
	# 预先写入脏数据，验证新一轮 play() 会立即清空 missed_lines
	XRift3Anim.missed_lines = ["whisper"]
	var anim := XRift3Anim.play(self, null, true)
	check("full.clears_prev_missed", XRift3Anim.missed_lines.is_empty())
	anim.set_process(false)
	var done_flag := [false]
	anim.finished.connect(func(): done_flag[0] = true)

	# 5 句预期纯正文与名签（从 XRift.RIFT3_LINES 现剥离对照，核实控件实际渲染的文字）
	var expected_whisper := XRift3Anim.parse_rift_line("whisper")
	var expected_sense := XRift3Anim.parse_rift_line("sense")
	var expected_hint := XRift3Anim.parse_rift_line("hint")
	var expected_follow := XRift3Anim.parse_rift_line("follow")
	var expected_after := XRift3Anim.parse_rift_line("after")
	check("parse.whisper_clean", expected_whisper.speaker == "??????" and not str(expected_whisper.text).contains("??????") and str(expected_whisper.text) == str(expected_whisper.text).strip_edges(), expected_whisper)
	check("parse.sense_speaker", expected_sense.speaker == "徐凤年" and not str(expected_sense.text).contains("\\n<"), expected_sense)
	check("parse.after_clean", expected_after.speaker == "" and not str(expected_after.text).contains("\\c["), expected_after)

	# P1 (0.0 - 2.6s)：0.2s 无对白，1.0s 出 whisper 黑底细白边旁白框（去 <??????> 标头，整句即显）
	anim.step(0.2)
	check("phase.p1_before_whisper", anim.state().phase == XRift3Anim.Phase.P1 and anim.state().active_dialogue_key == "" and not anim._narration_p1_box.visible)
	anim.step(0.8)  # t = 1.0s
	check("cue.whisper_shown", anim._narration_p1_box.visible and anim._narration_p1_label.text == expected_whisper.text and anim._narration_p1_label.visible_ratio == 1.0 and anim.state().active_dialogue_speaker == "", anim.state())

	# 逐个采样 8 处漫画字时间码与四段状态切换（v0.5：7 拟声＋1 刀意字「斩」）
	var sfx_probes := [
		[3.2, XRift3Anim.Phase.MID, "P2", "p2_hum"],
		[5.0, XRift3Anim.Phase.MID, "P3", "p3_crack"],
		[6.8, XRift3Anim.Phase.MID, "P4", "p4_rip"],
		[8.5, XRift3Anim.Phase.MID, "P5", "p5_boom"],
		[10.0, XRift3Anim.Phase.MID, "P6", "p6_whoosh"],
		[11.8, XRift3Anim.Phase.MID, "P8", "p8_zheng"],
		[13.5, XRift3Anim.Phase.MID, "P9", "p9_clang"],
		[15.2, XRift3Anim.Phase.P10, "P10", "p10_slash"],
	]
	for probe in sfx_probes:
		var target_t := float(probe[0])
		anim.step(target_t - float(anim.state().t))
		var st := anim.state()
		check("sfx.%s" % probe[3], int(st.phase) == int(probe[1]) and str(st.active_panel) == str(probe[2]) and (st.active_sfx_ids as Array).has(str(probe[3])), st)

	# P10 末段（16.0s）：刀意字「斩」0.45s 后已消失
	anim.step(16.0 - float(anim.state().t))
	check("sfx.p10_slash_gone", not (anim.state().active_sfx_ids as Array).has("p10_slash") and anim.state().phase == XRift3Anim.Phase.P10, anim.state())

	# P11a (18.0s)：左侧立绘残格可见，名签常驻，右侧气泡整句即显 sense
	anim.step(18.0 - float(anim.state().t))
	check("cue.sense_shown", anim.state().phase == XRift3Anim.Phase.P11 and anim._p11_portrait_box.visible and anim.state().nameplate_visible and anim._speech_bubble_box.visible and anim._speech_speaker_label.text == expected_sense.speaker and anim._speech_text_label.text == expected_sense.text and anim._speech_text_label.visible_ratio == 1.0, anim.state())

	# P11a→P11b 句间空隙 (19.8s)：v0.5 要求名签「徐凤年」常驻不闪烁
	anim.step(19.8 - float(anim.state().t))
	check("cue.p11_nameplate_persists_in_gap", anim.state().nameplate_visible and not anim._speech_bubble_box.visible, anim.state())

	# P11b (21.0s)：hint（整句即显、正文仍深墨不变紫）
	anim.step(21.0 - float(anim.state().t))
	check("cue.hint_shown", anim.state().nameplate_visible and anim._speech_bubble_box.visible and anim._speech_text_label.text == expected_hint.text and anim._speech_text_label.visible_ratio == 1.0 and anim.state().active_panel == "P11b", anim.state())

	# P11c (23.5s)：follow
	anim.step(23.5 - float(anim.state().t))
	check("cue.follow_shown", anim.state().nameplate_visible and anim._speech_bubble_box.visible and anim._speech_text_label.text == expected_follow.text and anim._speech_text_label.visible_ratio == 1.0 and anim.state().active_panel == "P11c", anim.state())

	# P11d (25.2s)：左侧立绘残格与常驻名签退场，底部居中收尾旁白条出 after 且字色为 #DCDCE0
	anim.step(25.2 - float(anim.state().t))
	var after_color: Color = anim._narration_end_label.get_theme_color("font_color")
	check("cue.after_shown_and_color", not anim._p11_portrait_box.visible and not anim.state().nameplate_visible and not anim._speech_bubble_box.visible and anim._narration_end_box.visible and anim._narration_end_label.text == expected_after.text and after_color.is_equal_approx(Color("dcdce0")) and anim.state().active_panel == "P11d", {"color": after_color.to_html(false), "state": anim.state()})

	# 自然播满 26.0s：finished 触发、done=true、skipped=false、missed_lines=[]
	anim.step(26.0 - float(anim.state().t))
	check("full.done_at_26s", done_flag[0] and anim.state().done and not anim.state().skipped and XRift3Anim.missed_lines.is_empty(), anim.state())
	await get_tree().process_frame
