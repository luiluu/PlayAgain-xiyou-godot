extends Node
## 【小A·天启篇】T415：天启篇大厅不写漩涡 maxStage 与 _remakeLobbyCorruption（T091 P2-6／T412 遗留）。
## 验证：
## 1. rift3 已看（XRift.stage() == 3）时，天启篇存档进大厅（setup()）不写 _remakeLobbyCorruption／maxStage，进大厅前后存档字节一致；
## 2. XTianqiHall.run_host 代调 after_event（希禾 60->50、仓库管理员 8->24）及 wants_after／after_event（大工匠 7、镜子 21）／on_action(裂缝)：
##    天启篇追记台词与裂缝两段文字照常出现、会话内去重不重复，同时不写 _remakeLobbyCorruption／maxStage；
## 3. 已被写过 maxStage=3 的天启篇老档进大厅与存读档无异常、不被改写；
## 4. 西游档照旧写入 maxStage=3、said 与 crack。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const TIMEOUT_FRAMES := 600
var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _open_hall(s: XState) -> XMapScene:
	s.map_id = 4
	s.x = 14
	s.y = 25
	XState.current = s
	var map := XMapScene.new()
	add_child(map)
	for _i in TIMEOUT_FRAMES:
		await _frames(1)
		if map.player != null and map.map_id == 4 and not map.busy:
			break
	await _frames(5)
	return map


func _close_hall(map: XMapScene) -> void:
	map.queue_free()
	await _frames(10)


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if is_instance_valid(e) and e.event_id == id:
			return e
	return null


func _run() -> void:
	var kit = Kit.new("xiyou_tianqi_lobby_maxstage")
	var prev_stage2 := XRift.STAGE2
	var prev_stage3 := XRift.STAGE3
	var prev_override := XLobbyCorruption.STAGE_OVERRIDE
	var prev_enabled := XLobbyCorruption.ENABLED
	var prev_guide := XGuide.MILESTONE_ENABLED
	var prev_fest := XFestLobby.ENABLED

	XRift.STAGE2 = true
	XRift.STAGE3 = true
	XRift.clear_cache()
	XLobbyCorruption.STAGE_OVERRIDE = 0
	XLobbyCorruption.ENABLED = true
	XGuide.MILESTONE_ENABLED = false
	XFestLobby.ENABLED = false
	XMessageBox.auto = true
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	XConfig.whisper_mark("rift3")

	_check("pre.stage3_active", XRift.stage() == 3 and XLobbyCorruption.stage() == 3 and XLobbyCorruption.active(), [XRift.stage(), XLobbyCorruption.stage(), XLobbyCorruption.active()])

	# ---- 1. 天启篇初进大厅：lobby_fx 存在，但 setup() 不写 _remakeLobbyCorruption / maxStage ----
	var s := Kit.new_game("jiusi")
	_check("tq.active", XTianqi.active(s) and not s.flags.has(XLobbyCorruption.FLAG_KEY), s.flags.keys())
	var m1 := await _open_hall(s)
	_check("tq.first_enter_layer_built", m1.map_id == 4 and m1.lobby_fx != null and m1.lobby_fx.is_inside_tree(), [m1.map_id, m1.lobby_fx])
	_check("tq.first_enter_no_flag", not s.flags.has(XLobbyCorruption.FLAG_KEY), s.flags.get(XLobbyCorruption.FLAG_KEY))
	await _close_hall(m1)

	# ---- 2. 天启篇再次进大厅：进大厅前后 flags 字节严格一致，_setup_lobby_fx() 建层前后完整存档字节一字不差 ----
	var d1 := s.to_dict()
	var flags_before := JSON.stringify(d1.get("flags", {}))
	var m2 := await _open_hall(s)
	_check("tq.reenter_layer_built", m2.lobby_fx != null and m2.lobby_fx.is_inside_tree(), m2.lobby_fx)
	var d2 := s.to_dict()
	var flags_after := JSON.stringify(d2.get("flags", {}))
	var other_diffs := []
	for k in d2.keys():
		if k != "playSeconds" and k != "mapEvents" and JSON.stringify(d1.get(k)) != JSON.stringify(d2.get(k)):
			other_diffs.append(k)
	_check("tq.reenter_flags_exact", flags_before == flags_after and other_diffs.is_empty() and not s.flags.has(XLobbyCorruption.FLAG_KEY), [other_diffs, s.flags.get(XLobbyCorruption.FLAG_KEY)])
	# 在真大厅里再重建一次 lobby_fx（跑 XLobbyCorruption.setup(m2)），比对建层前后完整存档序列化字节逐字节一致，再真写盘读回确认无该键
	var bytes_before := JSON.stringify(s.to_dict()).to_utf8_buffer()
	m2._setup_lobby_fx()
	var bytes_after := JSON.stringify(s.to_dict()).to_utf8_buffer()
	var back := kit.roundtrip(1)
	_check("tq.setup_save_bytes_exact", bytes_before == bytes_after and back != null and not back.flags.has(XLobbyCorruption.FLAG_KEY), [bytes_before.size(), bytes_after.size(), null if back == null else back.flags.get(XLobbyCorruption.FLAG_KEY)])
	s = back
	XState.current = s

	# ---- 3. tianqi_hall.gd:167 代调 after_event 路径（希禾 60->50、仓库管理员 8->24）：追记台词照常出现、会话内只播一次、不写漩涡键 ----
	s.set_variable(206, -3000)
	var l60 := XTianqiHall.menu(m2, s, 60).map(func(o): return str(o[0]))
	XMessageBox.auto_answers = [l60.find("欠债限制与福利"), 1]
	XMessageBox.transcript.clear()
	await m2.run_event(_event(m2, 60))
	var ev50_text := "\n".join(XMessageBox.transcript)
	_check("tq.hall60_src50_line_shown_no_write", ev50_text.contains("换作别人我早就不客气了") and ev50_text.contains("它是来收账的") and not s.flags.has(XLobbyCorruption.FLAG_KEY), [s.flags.get(XLobbyCorruption.FLAG_KEY), ev50_text])
	# 同会话第二次不再重复追记，且仍不写档
	XMessageBox.auto_answers = [l60.find("欠债限制与福利"), 1]
	XMessageBox.transcript.clear()
	await m2.run_event(_event(m2, 60))
	var ev50_again := "\n".join(XMessageBox.transcript)
	_check("tq.hall60_src50_dedup_no_write", ev50_again.contains("换作别人我早就不客气了") and not ev50_again.contains("它是来收账的") and not s.flags.has(XLobbyCorruption.FLAG_KEY), [s.flags.get(XLobbyCorruption.FLAG_KEY), ev50_again])
	s.set_variable(206, 0)

	var l8 := XTianqiHall.menu(m2, s, 8).map(func(o): return str(o[0]))
	XMessageBox.auto_answers = [l8.find("整理存档"), 1]
	XMessageBox.transcript.clear()
	await m2.run_event(_event(m2, 8))
	var ev24_text := "\n".join(XMessageBox.transcript)
	_check("tq.hall8_src24_line_shown_no_write", ev24_text.contains("别在裂纹边久待") and not s.flags.has(XLobbyCorruption.FLAG_KEY), [s.flags.get(XLobbyCorruption.FLAG_KEY), ev24_text])
	XMessageBox.auto_answers = [l8.find("整理存档"), 1]
	XMessageBox.transcript.clear()
	await m2.run_event(_event(m2, 8))
	var ev24_again := "\n".join(XMessageBox.transcript)
	_check("tq.hall8_src24_dedup_no_write", not ev24_again.contains("别在裂纹边久待") and not s.flags.has(XLobbyCorruption.FLAG_KEY), [s.flags.get(XLobbyCorruption.FLAG_KEY), ev24_again])

	# ---- 4. wants_after / after_event（大工匠 7、镜子 21）与 on_action(裂缝)：台词照常出现、会话内去重、不写漩涡键 ----
	var ev7 := _event(m2, 7)
	var ev21 := _event(m2, 21)
	_check("tq.wants_after_true_no_write", ev7 != null and ev21 != null and m2.lobby_fx.wants_after(ev7) and m2.lobby_fx.wants_after(ev21) and not s.flags.has(XLobbyCorruption.FLAG_KEY), s.flags.get(XLobbyCorruption.FLAG_KEY))
	XMessageBox.transcript.clear()
	await m2.lobby_fx.after_event(7)
	var ev7_after := "\n".join(XMessageBox.transcript)
	XMessageBox.transcript.clear()
	await m2.lobby_fx.after_event(21)
	var ev21_after := "\n".join(XMessageBox.transcript)
	_check("tq.ev7_ev21_after_shown_no_write", ev7_after.contains("地砖不是我弄裂的") and ev21_after.contains("慢了半拍") and not s.flags.has(XLobbyCorruption.FLAG_KEY), [ev7_after, ev21_after, s.flags.get(XLobbyCorruption.FLAG_KEY)])
	XMessageBox.transcript.clear()
	await m2.lobby_fx.after_event(7)
	await m2.lobby_fx.after_event(21)
	_check("tq.ev7_ev21_dedup_no_write", not m2.lobby_fx.wants_after(ev7) and not m2.lobby_fx.wants_after(ev21) and XMessageBox.transcript.is_empty() and not s.flags.has(XLobbyCorruption.FLAG_KEY), [XMessageBox.transcript.duplicate(), s.flags.get(XLobbyCorruption.FLAG_KEY)])
	XMessageBox.transcript.clear()
	var crack1 := await m2.lobby_fx.on_action(XLobbyCorruption.CRACK_CELL)
	var c1_text := "\n".join(XMessageBox.transcript)
	XMessageBox.transcript.clear()
	var crack2 := await m2.lobby_fx.on_action(XLobbyCorruption.CRACK_CELL)
	var c2_text := "\n".join(XMessageBox.transcript)
	_check("tq.crack_two_lines_no_write", crack1 and crack2 and c1_text.contains("缝里不是土") and c2_text.contains("凉的") and not s.flags.has(XLobbyCorruption.FLAG_KEY), [c1_text, c2_text, s.flags.get(XLobbyCorruption.FLAG_KEY)])
	await _close_hall(m2)

	# ---- 5. 已被写过 maxStage=3 的天启篇老档：进大厅与存读档不报错、键原样保持 ----
	s.flags[XLobbyCorruption.FLAG_KEY] = {"said": [], "crack": 0, "maxStage": 3}
	var legacy_before := JSON.stringify(s.flags[XLobbyCorruption.FLAG_KEY])
	var m3 := await _open_hall(s)
	_check("tq.legacy_maxstage3_preserved", JSON.stringify(s.flags.get(XLobbyCorruption.FLAG_KEY)) == legacy_before, s.flags.get(XLobbyCorruption.FLAG_KEY))
	await _close_hall(m3)

	# ---- 6. 西游档照旧：setup() 写 maxStage=3，wants_after / after_event 写 said，裂缝写 crack ----
	var plain := XState.new_game(3, 1, [8, 9, 10])
	plain.set_variable(206, -3000)
	plain.set_variable(20, 1)
	_check("plain.not_tq", not XTianqi.active(plain) and not plain.flags.has(XLobbyCorruption.FLAG_KEY))
	var mp := await _open_hall(plain)
	_check("plain.setup_writes_maxstage3", mp.lobby_fx != null and plain.flags.has(XLobbyCorruption.FLAG_KEY) and int(plain.flags[XLobbyCorruption.FLAG_KEY].get("maxStage", 0)) == 3, plain.flags.get(XLobbyCorruption.FLAG_KEY))
	var pev7 := _event(mp, 7)
	_check("plain.wants_after_true", pev7 != null and mp.lobby_fx.wants_after(pev7))
	XMessageBox.transcript.clear()
	await mp.lobby_fx.after_event(50)
	var plain_said: Array = XLobbyCorruption.record(plain).said
	_check("plain.after_event_writes_said", plain_said.has("50") and "\n".join(XMessageBox.transcript).contains("来收账的"), [plain_said, XMessageBox.transcript.duplicate()])
	XMessageBox.transcript.clear()
	await mp.lobby_fx.on_action(XLobbyCorruption.CRACK_CELL)
	_check("plain.crack_writes_count", int(XLobbyCorruption.record(plain).get("crack", 0)) == 1, plain.flags.get(XLobbyCorruption.FLAG_KEY))
	await _close_hall(mp)

	# ---- 还原全局开关并收尾 ----
	XRift.STAGE2 = prev_stage2
	XRift.STAGE3 = prev_stage3
	XRift.clear_cache()
	XLobbyCorruption.STAGE_OVERRIDE = prev_override
	XLobbyCorruption.ENABLED = prev_enabled
	XGuide.MILESTONE_ENABLED = prev_guide
	XFestLobby.ENABLED = prev_fest
	XMessageBox.auto_answers = []
	kit.teardown()

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
