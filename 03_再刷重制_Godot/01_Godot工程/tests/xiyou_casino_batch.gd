extends Node
## 批量抽奖（installCasinoBatchRuntime，XCasinoBatch／XCasinoDialog）对原版参照 tests/fixtures/casino_batch_oracle.json
## （mv_oracle/casino_batch_probe.cjs，12 例，Math.random 固定 0.5）：真地图 Map004，地图解释器（事件 60）跑大厅 EV60 那句
## CodexCasino.open 脚本，在数量框里填数／MAX／取消、开始抽取，抽取中按例关赌场或点停止。
## 比：开没开、数量框文字（标签、预览、MAX 后）、抽取结果（次数、积分、券、停止原因、前 20 抽样本）、结果消息、提示静音、
## 抽后的变量与全员技能。O-待定（一抽没跑就结束要说明）：先关掉开关对原版，再开着看「未开始」消息。
var checks := 0
var failures: Array = []
var map: XMapScene
var scripts := {}


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XPetCapture.clock = func(): return {"day": 1, "hour": 12, "minute": 15}
	XMessageBox.auto = true
	MVEventCore.fixed_random = 0.5
	XCasinoBatch.frame_budget_ms = 1000000  # 参照一帧跑满 4 抽（停止那例靠它）
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/casino_batch_oracle.json"))
	check("source", f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete", f.cases.size() == 12)
	find_scripts()
	rules()
	for c in f.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		XCasinoBatch.notify_unstarted = false
		await run_case(c, c.observed)
		if c.id == "single.below":
			XCasinoBatch.notify_unstarted = true
			var fixed: Dictionary = c.observed.duplicate(true)
			fixed.messages = ["自定义单抽未开始：肝帝积分低于原单抽门槛\n积分 -30001；剩余券 5"]
			await run_case(c, fixed, ".o-unstarted")
	await random_draws()
	XCasinoBatch.notify_unstarted = true
	XCasinoBatch.frame_budget_ms = 8
	MVEventCore.fixed_random = -1.0
	finish()


## 大厅 EV60 三页的那句脚本（单抽两页相同、20 连一页）
func find_scripts() -> void:
	var ev = null
	for e in XDB.map(4).get("events", []):
		if e is Dictionary and int(e.get("id", 0)) == 60:
			ev = e
	check("ev60", ev != null)
	if ev == null:
		return
	for i in ev.pages.size():
		for cmd in ev.pages[i].list:
			if int(cmd.code) == 355 and str(cmd.parameters[0]).contains("CodexCasino.open"):
				scripts[i] = str(cmd.parameters[0])
	check("ev60.scripts", scripts.size() == 3 and scripts[0] == scripts[1] and scripts[2].contains("\"twenty\""), scripts)


## 纯规则：最大次数、解释器批量模式（文字跳过、选项第 0 项、最外层跳 212／230、子游标继承）
func rules() -> void:
	var s := XState.new_game_blank()
	s.gain_item(XCasinoBatch.TICKET, 45)
	check("rule.max", XCasinoBatch.maximum(s, "single") == 45 and XCasinoBatch.maximum(s, "twenty") == 2 and XCasinoBatch.maximum(s, "x") == 0)
	var core := MVEventCore.new()
	core.list = [{"code": 101, "indent": 0, "parameters": ["", 0, 0, 2, ""]}, {"code": 401, "indent": 0, "parameters": ["a"]},
		{"code": 102, "indent": 5, "parameters": [["赢下所有", "一无所有"], 1, 0, 2, 0]}, {"code": 402, "indent": 5, "parameters": [0, "赢下所有"]},
		{"code": 122, "indent": 6, "parameters": [1197, 1197, 0, 0, 7]}, {"code": 0, "indent": 6, "parameters": []},
		{"code": 402, "indent": 5, "parameters": [1, "一无所有"]}, {"code": 122, "indent": 6, "parameters": [1197, 1197, 0, 0, 9]},
		{"code": 0, "indent": 6, "parameters": []}, {"code": 404, "indent": 5, "parameters": []},
		{"code": 230, "indent": 0, "parameters": [60]}, {"code": 0, "indent": 0, "parameters": []}]
	core.casino_draw = {"second": false}
	core.casino_root = true
	var r := core.advance()
	check("rule.batch-runs-through", r.kind == "done" and s.variable(1197) == 7 and core.casino_draw.second and core.skipped.is_empty(), [r, s.variable(1197), core.skipped])
	var child := MVEventCore.new()
	child.list = [{"code": 230, "indent": 0, "parameters": [60]}, {"code": 0, "indent": 0, "parameters": []}]
	child.casino_draw = {"second": false}
	check("rule.child-waits", child.advance().kind == "done" and child.skipped.size() == 1, child.skipped)
	var plain := MVEventCore.new()
	plain.list = core.list
	check("rule.plain-asks", plain.advance().kind == "message")
	var list := XCasinoBatch.native_list(1432)
	var ce: Array = XDB.rec("CommonEvents", 1432).list
	check("rule.native-list", list.size() == ce.size() and int(list[0].code) == int(ce[0].code) and str(list[65].parameters[0]) == "if(actor)actor.learnSkill(8101);", list[65])


func new_state(spec: Dictionary) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.direction = 8
	var segment := XGuide.segment_of(XZhenqi.progress_floor(s))
	if not segment.is_empty():
		XGuide.seen(s, "seg:" + str(segment.key), true)
	return s


func open_map() -> bool:
	map = XMapScene.new()
	add_child(map)
	for i in 600:
		if map.player != null and map.map_id == 4 and not map.busy:
			break
		await frames(1)
	await frames(2)
	return map.player != null and not map.busy


## JSON 读进来的数字都是 float：整数值换成 int 再比
static func norm(v):
	if v is float and v == floorf(v):
		return int(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	if v is Array:
		return v.map(func(x): return norm(x))
	return v


func run_case(c: Dictionary, want: Dictionary, tag := "") -> void:
	var spec: Dictionary = c.setup
	var id: String = c.id + tag
	var s := new_state(spec)
	check(id + ".map", await open_map())
	s.set_switch(XCasinoBatch.SWITCH_OPEN, true)
	s.set_variable(XCasinoBatch.VAR_POINTS, float(spec.points))
	if int(spec.tickets) > 0:
		s.gain_item(XCasinoBatch.TICKET, int(spec.tickets))
	if spec.get("proofBefore", false):
		s.actor(1).learn_skill(XCasinoBatch.PROOF_SKILL)
	if spec.has("map"):
		s.map_id = int(spec.map)  # 原版 $gameMap.mapId()；地图画面还是大厅
	var mode: String = spec.mode
	var before := {"points": int(s.variable(XCasinoBatch.VAR_POINTS)), "tickets": s.item_count(XCasinoBatch.TICKET), "max": XCasinoBatch.maximum(s, mode)}
	check(id + ".before", before == norm(want.before), [before, want.before])
	XCasinoBatch.last_result = {}
	XMessageBox.transcript.clear()
	map.toasts.clear()
	var parent := MVInterpreter.new(map, 4, 60, [{"code": 355, "indent": 0, "parameters": [scripts.get(2 if mode == "twenty" else 0, "")]},
		{"code": 0, "indent": 0, "parameters": []}])
	var done := [false]
	parent.finished.connect(func(): done[0] = true)
	parent.run()
	var dialog: XCasinoDialog
	for i in 30:
		var found := map.ui.get_children().filter(func(n): return n is XCasinoDialog and not n.is_queued_for_deletion())
		if not found.is_empty() or done[0]:
			dialog = found[0] if not found.is_empty() else null
			break
		await frames(1)
	var opened := dialog != null
	check(id + ".opened", opened == bool(want.opened), [opened, want.opened])
	var begun = null
	if opened:
		await frames(1)
		var d: Dictionary = want.dialog
		check(id + ".dialog.title", dialog.title.text == d.title, [dialog.title.text, d.title])
		check(id + ".dialog.desc", dialog.desc.text == d.desc, [dialog.desc.text, d.desc])
		check(id + ".dialog.label", dialog.label.text == d.label, [dialog.label.text, d.label])
		check(id + ".dialog.status", dialog.status.text == d.status, [dialog.status.text, d.status])
		check(id + ".dialog.focus", dialog.input.has_focus())
		if spec.count is float and int(spec.count) == 0:
			dialog.cancel_button.pressed.emit()
		else:
			if str(spec.count) == "max":
				dialog.max_button.pressed.emit()
				check(id + ".dialog.max", dialog.input.text == d.afterMax.value and dialog.status.text == d.afterMax.status, [dialog.input.text, dialog.status.text, d.afterMax])
			else:
				dialog.input.text = str(int(spec.count))
				dialog.input.text_changed.emit(dialog.input.text)
				check(id + ".dialog.preview", dialog.status.text == d.preview, [dialog.status.text, d.preview])
			dialog.ok_button.pressed.emit()
			begun = XCasinoBatch.session.get("state")
			check(id + ".dialog.drawing", not dialog.ok_button.visible and not dialog.input.editable and dialog.max_button.disabled and dialog.cancel_button.text == "停止后续抽取")
			for i in 5000:
				if not XCasinoBatch.is_open():
					break
				await frames(1)
				var se := XCasinoBatch.session
				if se.is_empty():
					break
				if spec.has("closeAfter") and int(se.used) >= int(spec.closeAfter):
					s.set_switch(XCasinoBatch.SWITCH_OPEN, false)
				if spec.has("stopAfter") and int(se.used) >= int(spec.stopAfter) and not se.stop:
					dialog.cancel_button.pressed.emit()
					check(id + ".dialog.stopping", dialog.cancel_button.text == d.stopping and dialog.cancel_button.disabled, dialog.cancel_button.text)
	check(id + ".begun", begun == want.begun, [begun, want.begun])
	for i in 120:
		if done[0]:
			break
		await frames(1)
	check(id + ".finished", done[0] and not XCasinoBatch.is_open() and map.ui.get_children().all(func(n): return not n is XCasinoDialog or n.is_queued_for_deletion()))
	if want.result != null:
		check(id + ".result", norm(XCasinoBatch.last_result) == norm(want.result), [XCasinoBatch.last_result, want.result])
	else:
		check(id + ".no-result", XCasinoBatch.last_result.is_empty(), XCasinoBatch.last_result)
	check(id + ".messages", XMessageBox.transcript == Array(want.messages), [XMessageBox.transcript, want.messages])
	check(id + ".toasts", map.toasts.is_empty() == Array(want.toasts).is_empty(), map.toasts)
	var a: Dictionary = want.after
	var after := {"points": int(s.variable(XCasinoBatch.VAR_POINTS)), "tickets": s.item_count(XCasinoBatch.TICKET),
		"v1197": int(s.variable(1197)), "v1196": int(s.variable(1196))}
	check(id + ".after", after == norm({"points": a.points, "tickets": a.tickets, "v1197": a.v1197, "v1196": a.v1196}), [after, a])
	var actors: Array = s.party.map(func(aid): return {"id": int(aid), "proof": s.actor(int(aid)).skill_ids.has(8101),
		"loss": s.actor(int(aid)).skill_ids.has(8102), "gift": s.actor(int(aid)).skill_ids.has(8091)})
	check(id + ".actors", actors == norm(a.actors), [actors, a.actors])
	check(id + ".skipped", parent.skipped.is_empty(), parent.skipped)
	await close_map()


## 不固定成 0.5 的抽法（参照没有）：二阶段、欧皇与结果消息一致，欧皇的全员都学会
func random_draws() -> void:
	MVEventCore.fixed_random = -1.0
	var s := new_state({})
	check("random.map", await open_map())
	s.set_switch(XCasinoBatch.SWITCH_OPEN, true)
	s.gain_item(XCasinoBatch.TICKET, 60)
	XCasinoBatch.last_result = {}
	XMessageBox.transcript.clear()
	var parent := MVInterpreter.new(map, 4, 60, [{"code": 355, "indent": 0, "parameters": [scripts.get(0, "")]}, {"code": 0, "indent": 0, "parameters": []}])
	var done := [false]
	parent.finished.connect(func(): done[0] = true)
	parent.run()
	await frames(2)
	var dialog: XCasinoDialog = map.ui.get_children().filter(func(n): return n is XCasinoDialog)[0]
	dialog.max_button.pressed.emit()
	dialog.ok_button.pressed.emit()
	for i in 600:
		if done[0]:
			break
		await frames(1)
	var r := XCasinoBatch.last_result
	var proof_now: bool = s.party.all(func(aid): return s.actor(int(aid)).skill_ids.has(8101))
	check("random.done", done[0] and int(r.get("used", 0)) > 0, r)
	check("random.counts", int(r.second) <= int(r.used) and int(r.proof) <= int(r.second) and r.newProof == (int(r.proof) > 0) and proof_now == (int(r.proof) > 0), r)
	check("random.tickets", int(r.ticketsUsed) == int(r.used) and int(r.remaining) == 60 - int(r.used) and s.item_count(XCasinoBatch.TICKET) == int(r.remaining), r)
	check("random.message", XMessageBox.transcript.size() == 1 and str(XMessageBox.transcript[0]).begins_with("自定义单抽%s：%d/%d抽" % ["完成", int(r.used), int(r.requested)]), XMessageBox.transcript)
	check("random.skipped", parent.skipped.is_empty(), parent.skipped)
	print("random draws: used %d, second %d, proof %d, %s" % [int(r.used), int(r.second), int(r.proof), str(r.reason)])
	await close_map()


func close_map() -> void:
	for player in [map.bgm, map.bgs, map.me, map.se]:
		player.stop()
		player.stream = null
	map.queue_free()
	await frames(3)


func finish() -> void:
	XPetCapture.clock = Callable()
	XMessageBox.auto = false
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
