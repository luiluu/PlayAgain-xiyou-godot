class_name XCasinoBatch
extends RefCounted
## 批量抽奖（正式西游 v0.28 Codex installCasinoBatchRuntime，CodexCasino v3）：大厅 Map004 EV60 希禾的「自定义单抽」（页 0／1）
## 与「自定义20连抽」（页 2）。脚本 `if(window.CodexCasino)CodexCasino.open(this[,"twenty"]);else …` 由 MVScript 交到 open。
## - open：不在大厅地图、已有一局或模式不对就不开（不出消息）；券连一抽都不够时只加一句消息（下一次等待时显示）。
##   开了就弹数量框（XCasinoDialog），本事件停在这条脚本上，直到 finish（原版 setWaitMode('codexCasinoBatch')）。
## - 每帧（Scene_Map.update 包装）最多 4 抽、8 毫秒；每抽前按原版次序判停止：已停止 → 完成 → 券不足 → 积分低于门槛 → 赌场关闭（开关 2495）。
##   扣券后用 MVInterpreter 把抽奖公共事件（单抽 1432／20 连 1431）的副本整条跑完：批量模式见 MVEventCore.casino_draw
##   （文字跳过、选项选第 0 项「赢下所有」、最外层跳过 212／230），抽取中 $.toaster 静音（XMapScene.toast）。
##   最外层缩进 5 的选项记「二阶段」，抽取中 learnSkill(8101) 记「欧皇达标」（这里看本抽新增的全员技能操作）。
## - finish：记 last_result，关掉弹窗，抽过才加一句三行（停下的再加原因）结果消息。
## O-待定（一抽没跑就结束要说明）：原版点「开始抽取」后第一抽前就停（积分已低于门槛、赌场已关）时 used 为 0，不出任何消息，
## 弹窗直接消失；重制加一句「未开始」与原因。取消不算。恢复方法：`XCasinoBatch.notify_unstarted = false`。

const TICKET := 1639
const VAR_POINTS := 206
const SWITCH_OPEN := 2495
const LOBBY_MAP := 4
const PROOF_SKILL := 8101
const MODES := {
	"single": {"event": 1432, "cost": 1, "threshold": -30000, "title": "自定义单抽", "unit": "抽"},
	"twenty": {"event": 1431, "cost": 20, "threshold": -200000, "title": "自定义20连抽", "unit": "次20连抽"},
}
const DRAWS_PER_FRAME := 4
## 原版每帧抽取的时间上限（毫秒）；专项为对齐参照放宽
static var frame_budget_ms := 8
## O-待定：一抽没跑就结束时说明原因；false 恢复原版（不出消息）
static var notify_unstarted := true
## 进行中的一局（原版 C.session）；没有为空字典
static var session: Dictionary = {}
static var last_result: Dictionary = {}
## 正在跑一抽（$.toaster 静音）
static var drawing := false


static func stock(s: XState) -> int:
	return maxi(0, s.item_count(TICKET))


static func maximum(s: XState, mode := "single") -> int:
	var rules: Dictionary = MODES.get(mode, {})
	return floori(stock(s) / float(rules.cost)) if not rules.is_empty() else 0


static func is_open() -> bool:
	return not session.is_empty()


## CodexCasino.open(parent, mode)：开了返回 true，并等到这一局结束
static func open(parent, mode := "single") -> bool:
	var rules: Dictionary = MODES.get(mode, {})
	var s := XState.current
	var host = parent.host
	if rules.is_empty() or not session.is_empty() or s == null or not (host is XMapScene) or s.map_id != LOBBY_MAP:
		return false
	if maximum(s, mode) < 1:
		parent.pending_lines.append("20连抽至少需要20张肝帝积分抽奖券。" if mode == "twenty" else "肝帝积分抽奖券不足。")
		return false
	var se := {"parent": parent, "host": host, "mode": mode, "rules": rules, "state": "quantity", "requested": 0, "used": 0,
		"second": 0, "proof": 0, "new_proof": false, "initial_proof": _party_proof(s), "points": int(s.variable(VAR_POINTS)),
		"samples": [], "stop": false}
	session = se
	var dialog := XCasinoDialog.new()
	dialog.session = se
	se.dialog = dialog
	host.ui.add_child(dialog)
	while session == se:
		await Engine.get_main_loop().process_frame
		await update()
	return true


## CodexCasino.begin(count)：数量框确认
static func begin(count: int) -> bool:
	var se := session
	if se.is_empty() or se.state != "quantity" or count < 1 or count > maximum(XState.current, se.mode):
		return false
	se.requested = count
	se.state = "drawing"
	if is_instance_valid(se.get("dialog")):
		se.dialog.drawing_started()
	return true


## 「取消」／「停止后续抽取」
static func cancel() -> void:
	var se := session
	if se.is_empty():
		return
	if se.state == "quantity":
		finish("取消")
	else:
		se.stop = true
		if is_instance_valid(se.get("dialog")):
			se.dialog.stopping()


## 每帧一次（Scene_Map.update 包装，open 里的循环调）
static func update() -> void:
	var se := session
	if se.is_empty() or se.state != "drawing":
		return
	if not is_instance_valid(se.host) or not se.host.is_inside_tree():
		finish("离开赌场")
		return
	var s := XState.current
	var started := Time.get_ticks_msec()
	var i := 0
	while i < DRAWS_PER_FRAME and Time.get_ticks_msec() - started < frame_budget_ms:
		i += 1
		var why := _stop_reason(s, se)
		if why != "":
			finish(why)
			return
		s.gain_item(TICKET, -int(se.rules.cost))
		var ops_before := s.actor_ops.size()
		var draw := MVInterpreter.new(se.host, s.map_id, int(se.parent.event_id), native_list(int(se.rules.event)), 1)
		draw.casino_draw = {"second": false}
		draw.casino_root = true
		draw.pending_lines = se.parent.pending_lines
		drawing = true
		await draw.run()
		drawing = false
		if session != se:
			return
		se.parent.skipped.append_array(draw.skipped)
		var hit_proof := s.actor_ops.slice(ops_before).any(func(op): return str(op.op) == "learn" and int(op.skill) == PROOF_SKILL)
		se.used += 1
		if draw.casino_draw.second:
			se.second += 1
		if hit_proof:
			se.proof += 1
		se.new_proof = se.new_proof or (not se.initial_proof and _party_proof(s))
		if se.samples.size() < 20:
			se.samples.append({"draw": se.used, "second": draw.casino_draw.second, "proof": hit_proof, "points": int(s.variable(VAR_POINTS))})
		if is_instance_valid(se.get("dialog")):
			se.dialog.set_status("已完成 %d / %d%s；二阶段 %d 次" % [se.used, se.requested, se.rules.unit, se.second])


static func _stop_reason(s: XState, se: Dictionary) -> String:
	if se.stop:
		return "已停止"
	if se.used >= se.requested:
		return "完成"
	if maximum(s, se.mode) < 1:
		return "抽奖券不足"
	if s.variable(VAR_POINTS) < int(se.rules.threshold):
		return "肝帝积分低于原" + ("20连抽" if se.mode == "twenty" else "单抽") + "门槛"
	if not s.switch(SWITCH_OPEN):
		return "赌场已关闭"
	return ""


## CodexCasino.finish(reason)
static func finish(reason: String) -> void:
	var se := session
	if se.is_empty():
		return
	var s := XState.current
	var points := int(s.variable(VAR_POINTS))
	var cost := int(se.rules.cost)
	last_result = {"mode": se.mode, "eventId": int(se.rules.event), "ticketsPerDraw": cost, "requested": se.requested, "used": se.used,
		"totalDraws": se.used * cost, "ticketsUsed": se.used * cost, "second": se.second, "proof": se.proof, "newProof": se.new_proof,
		"initialPoints": se.points, "finalPoints": points, "pointChange": points - int(se.points), "remaining": stock(s), "reason": reason,
		"samples": se.samples}
	if is_instance_valid(se.get("dialog")):
		se.dialog.queue_free()
	session = {}
	var title: String = se.rules.title
	if se.used > 0:
		var change := points - int(se.points)
		var text := "%s完成：%d/%d%s%s\n二阶段 %d 次，欧皇达标 %d 次%s\n积分 %d → %d（变化 %s%d）；剩余券 %d%s" % [title, se.used,
			se.requested, se.rules.unit, "（共 %d 抽）" % (se.used * cost) if se.mode == "twenty" else "", se.second, se.proof,
			"（新获欧皇之证）" if se.new_proof else "", se.points, points, "+" if change >= 0 else "", change, stock(s),
			"" if reason == "完成" else "\n停止原因：" + reason]
		se.parent.pending_lines.append_array(text.split("\n"))
	elif notify_unstarted and reason != "取消":
		se.parent.pending_lines.append_array([title + "未开始：" + reason, "积分 %d；剩余券 %d" % [points, stock(s)]])


static func _party_proof(s: XState) -> bool:
	return s.party.any(func(id): return s.actor(int(id)).skill_ids.has(PROOF_SKILL))


## 抽奖公共事件的副本：全员学技能循环里没写 if(actor) 的补上（原版 nativeList，v0.28 数据里已都有）
static func native_list(event_id: int) -> Array:
	var out := []
	for c in XDB.rec("CommonEvents", event_id).get("list", []):
		var copy := {"code": int(c.code), "indent": int(c.indent), "parameters": (c.parameters as Array).duplicate()}
		if copy.code in [355, 655] and copy.parameters.size() > 0:
			var line := str(copy.parameters[0])
			if not line.contains("if(actor)") and RegEx.create_from_string("actor\\.learnSkill\\((8101|8102|8091)\\)").search(line) != null:
				copy.parameters[0] = line.replace("actor.learnSkill(", "if(actor)actor.learnSkill(")
		out.append(copy)
	return out
