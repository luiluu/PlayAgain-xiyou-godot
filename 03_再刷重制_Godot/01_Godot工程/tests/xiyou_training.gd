extends Node
## 修炼（XTraining／XTrainingScene）：按正式 training_probe.cjs（真实插件的 PoLites、makeCommandList、onConfirmOk、paramBaseBoost）逐项比对——
## 修炼表、七组流程每一步的行文／提示／精魂／存档等级／八项加成与含修炼的能力值（XActor.param_base 读 XTraining.param_bonus）、存读档。
## 界面对照冻结 v0.28 浏览器参照 tests/fixtures/training_ui_oracle.json（新局 1/8/9/10、精魂 1234567890、XiuLian [8,9,14,15]）：
## 五个窗口的几何、目录／状态窗／精魂窗／底部／修炼项的逐条绘制、目录→底部→修炼项→修炼→取消的焦点流转；
## 优化 O-082（ALIGN_COST）开着时「下一级费用」各行同一列、文字与原版拼起来相同；入口脚本（mv_script）与 Map180 EV12 进切片。

const ORACLE := "res://modes/xiyou/generated/oracle/training.json"
const FIXTURE := "res://tests/fixtures/training_ui_oracle.json"
const POS_TOL := 0.05
## actor.gd 的 param_base 已读 XTraining.param_bonus（唐僧_17 批准的独占例外）；设 false 时只报告能力值差异
const PARAMS_HOOKED := true

var results := []
var out_dir := ""


class FakeHost extends Node:
	var opened := 0
	func open_training() -> void:
		opened += 1
		await get_tree().process_frame
	func refresh_events() -> void:
		pass


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


static func want_form(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "blt":
			out.append(["blt", float(o[6]), float(o[7])])
		else:
			out.append([str(o[0]), float(o[1]), float(o[2]), float(o[3]), float(o[6]), Color(str(o[7])).to_html(false)])
	return out


static func got_form(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "i":
			out.append(["blt", float(o[2]), float(o[3])])
		else:
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), float(o[7]), (o[8] as Color).to_html(false)])
	return out


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		var bad := g.size() != w.size()
		if not bad:
			for k in w.size():
				if w[k] is String:
					bad = bad or str(g[k]) != w[k]
				else:
					bad = bad or absf(float(g[k]) - float(w[k])) > POS_TOL
		if bad:
			return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


func _new_state(party: Array, gold: int) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in party:
		s.add_actor(int(id))
	s.gold = gold
	XState.current = s
	return s


## 参照 pushattribute → 等级表（只取等级不为 0 的）
static func levels_from(push) -> Dictionary:
	var out := {}
	if push is Array:
		for i in push.size():
			if push[i] is Array and int(push[i][0]) != 0:
				out[str(i)] = int(push[i][0])
	return out


static func levels_of(s: XState, actor_id: int) -> Dictionary:
	var out := {}
	var mine: Dictionary = s.training.get(str(actor_id), {})
	for k in mine:
		if int(mine[k]) != 0:
			out[str(k)] = int(mine[k])
	return out


func _run() -> void:
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	var ui = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_loaded", oracle is Dictionary and oracle.has("flows") and ui is Dictionary):
		await _finish()
		return
	XTrainingScene.ALIGN_COST = false
	_check_table(oracle)
	_check_flows(oracle)
	_check_save(oracle)
	await _check_ui(ui)
	await _check_entries()
	XTrainingScene.ALIGN_COST = true
	XTraining.xiulian = XTraining.DEFAULT_LIST.duplicate()
	await _finish()


func _check_table(oracle: Dictionary) -> void:
	var got := []
	for id in XTraining.table():
		var e: Dictionary = XTraining.table()[id]
		got.append([int(e.id), e.name, int(e.max), int(e.gold), int(e.param), int(e.value)])
	var want: Array = oracle.table.map(func(e): return [int(e.id), str(e.Name), int(e.MaXNum), int(e.Gold), int(e.PushId), int(e.Value)])
	check("table", got == want, [got.size(), want.size(), got.slice(0, 2), want.slice(0, 2)])
	check("currency_unit", str(XDB.system().get("currencyUnit", "")) == str(oracle.currencyUnit))


func _check_flows(oracle: Dictionary) -> void:
	var party: Array = oracle.party
	for f in oracle.flows:
		var s := _new_state(party, int(f.gold))
		XTraining.xiulian = XTraining.DEFAULT_LIST.duplicate() if f.xiulian == null else f.xiulian.map(func(v): return int(v))
		var name := str(f.name)
		var base := s.members().map(func(a): return range(8).map(func(i): return a.param(i)))
		var want_base: Array = f.start.members.map(func(m): return m.params.map(func(v): return float(v)))
		check(name + "_base_params", base == want_base, [base, want_base])
		var cur := 0
		check(name + "_start_lines", XTraining.lines(s, int(party[cur])) == f.start.lines, [XTraining.lines(s, int(party[cur])), f.start.lines])
		var k := 0
		for st in f.steps:
			var toasts := []
			if st.op == "actor":
				cur = int(st.n)
			else:
				var listed := XTraining.listed()
				var t := XTraining.confirm(s, int(party[cur]), int(listed[int(st.n)].id))
				if t != "":
					toasts.append(t)
			var tag := "%s_%d" % [name, k]
			check(tag + "_toasts", toasts == st.toasts, [toasts, st.toasts])
			check(tag + "_gold", s.gold == int(st.gold), [s.gold, st.gold])
			check(tag + "_lines", XTraining.lines(s, int(party[cur])) == st.lines, [XTraining.lines(s, int(party[cur])), st.lines])
			var bad := []
			var bad_params := []
			for m_i in st.members.size():
				var m: Dictionary = st.members[m_i]
				var aid := int(m.id)
				if levels_of(s, aid) != levels_from(m.push):
					bad.append([aid, levels_of(s, aid), levels_from(m.push)])
				var a: XActor = s.actor(aid)
				var bonus := range(8).map(func(i): return XTraining.param_bonus(a, i))
				var want_bonus := range(8).map(func(i): return float(m.params[i]) - float(want_base[m_i][i]))
				if bonus != want_bonus:
					bad.append([aid, "bonus", bonus, want_bonus])
				var params := range(8).map(func(i): return a.param(i))
				if params != m.params.map(func(v): return float(v)):
					bad_params.append([aid, params, m.params])
			check(tag + "_levels_bonus", bad.is_empty(), bad)
			if PARAMS_HOOKED:
				check(tag + "_actor_params", bad_params.is_empty(), bad_params)
			elif not bad_params.is_empty() and k == f.steps.size() - 1:
				print("NOTE ", tag, " 能力值未含修炼（actor.gd 未接 XTraining.param_bonus）")
			k += 1


func _check_save(oracle: Dictionary) -> void:
	var s := _new_state(oracle.party, 1000000000)
	XTraining.xiulian = [8, 9, 14, 15]
	XTraining.confirm(s, 1, 8)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = back
	var want := levels_from(oracle.save.reloaded.push)
	check("save_roundtrip", levels_of(back, 1) == want and back.gold == s.gold, [levels_of(back, 1), want])
	check("save_bonus", XTraining.param_bonus(back.actor(1), 0) == 15000.0)
	var old := s.to_dict()
	old.erase("training")
	check("save_old_without_training", XState.from_dict(JSON.parse_string(JSON.stringify(old))).training == {})
	XState.current = s


func _check_ui(ui: Dictionary) -> void:
	var s := _new_state([1, 8, 9, 10], 1234567890)
	XTraining.xiulian = [8, 9, 14, 15]
	var page := XTrainingScene.new()
	add_child(page)
	await frames()
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	var near := func(a: Array, b: Array) -> bool:
		for i in 4:
			if absf(float(a[i]) - float(b[i])) > 0.7:
				return false
		return true
	var r: Dictionary = ui.rects
	check("geometry", near.call(rect.call(page.index_win), r.index) and near.call(rect.call(page.status_win), r.status)
		and near.call(rect.call(page.gold_win), r.gold) and near.call(rect.call(page.bottom_win), r.bottom) and near.call(rect.call(page.list_win), r.confirm),
		[rect.call(page.index_win), rect.call(page.status_win), rect.call(page.gold_win), rect.call(page.bottom_win), rect.call(page.list_win)])
	var d := diff(got_form(XTrainingScene.index_ops(s)), want_form(ui.index))
	check("oracle_index", d == "", d)
	# 状态窗：原版画的是含修炼的能力值；新局都是 0 级，与没接修炼时相同
	d = diff(got_form(XTrainingScene.status_ops(s.actor(1))), want_form(ui.status))
	check("oracle_status", d == "", d)
	d = diff(got_form(XTrainingScene.gold_ops(s)), want_form(ui.gold))
	check("oracle_gold", d == "", d)
	d = diff(got_form(XTrainingScene.bottom_ops()), want_form(ui.bottom))
	check("oracle_bottom", d == "", d)
	d = diff(got_form(XTrainingScene.list_ops(s, 1)), want_form(ui.confirm))
	check("oracle_list", d == "", d)
	check("sprite", page._sprite_tex != null and absf(XTrainingScene.SPRITE_CENTER.x - float(ui.sprite.x)) < POS_TOL
		and str(ui.sprite.bmp).ends_with(str(s.actor(1).data().battlerName) + ".png"))
	await shot("training_0_index")
	# 焦点流转（参照 flow）
	var fl: Dictionary = ui.flow
	var state := func() -> Array: return [page.mode == "index", page.index, page.mode == "bottom", page.cmd, page.mode == "list", page.row]
	var want_state := func(x: Dictionary) -> Array: return [x.index[0], int(x.index[1]), x.bottom[0], int(x.bottom[1]), x.confirm[0], int(x.confirm[1])]
	page.ok()
	check("flow_index_ok", state.call() == want_state.call(fl.afterIndexOk), state.call())
	await shot("training_2_bottom")
	page.ok()
	check("flow_bottom_ok", state.call() == want_state.call(fl.afterBottomOk), state.call())
	page.ok()
	await frames()
	check("flow_buy", state.call() == want_state.call(fl.afterBuy) and s.gold == int(fl.afterBuy.gold), [state.call(), s.gold])
	check("flow_buy_status", page._status_ops.size() == ui.status.size())
	await shot("training_4_bought")
	page.cancel()
	check("flow_list_cancel", state.call() == want_state.call(fl.afterConfirmCancel), state.call())
	page.cancel()
	check("flow_bottom_cancel", state.call() == want_state.call(fl.afterBottomCancel), state.call())
	page.select(1)
	check("select_actor", page.current().actor_id == 8 and str(ui.actor2Sprite).ends_with(str(s.actor(8).data().battlerName) + ".png"))
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.cancel()
	check("close", closed[0])
	page.queue_free()
	# O-082：费用列对齐，拼回去与原版行文相同
	XTrainingScene.ALIGN_COST = true
	var ops := XTrainingScene.list_ops(s, 8)
	var lines := XTraining.lines(s, 8)
	var cols := ops.filter(func(o): return str(o[1]).begins_with(XTrainingScene.COST_MARK)).map(func(o): return float(o[2]))
	var joined := []
	for o in ops:
		if str(o[1]).begins_with(XTrainingScene.COST_MARK):
			joined[-1] = [joined[-1][0], str(o[1])]
		else:
			joined.append([str(o[1]), ""])
	var same_text := true
	for i in lines.size():
		var l := str(lines[i])
		same_text = same_text and l.begins_with(joined[i][0]) and l.ends_with(joined[i][1]) and l.replace(" ", "") == (joined[i][0] + joined[i][1]).replace(" ", "")
	check("o082_aligned", cols.size() >= 2 and cols.all(func(x): return x == cols[0]) and same_text, [cols, joined])
	XTrainingScene.ALIGN_COST = false


func _check_entries() -> void:
	var host := FakeHost.new()
	add_child(host)
	var interp := MVInterpreter.new(host, 82, 4, [], 0)
	var unknown: Array = await MVScript.run("Star.ActorAttributePlusPoints.XiuLian = [33,34,35,36,37,38,39,40];\nSceneManager.push(Scene_ActorAttributePlusPoints)", interp)
	check("script_entry", unknown.is_empty() and host.opened == 1 and XTraining.xiulian == [33, 34, 35, 36, 37, 38, 39, 40], [unknown, host.opened, XTraining.xiulian])
	var events: Array = XDB.map(180).get("events", [])
	var ev12 := events.filter(func(e): return e is Dictionary and int(e.id) == 12)
	check("map180_ev12_kept", ev12.size() == 1 and ev12[0].pages.size() == 3)
	host.queue_free()


func _finish() -> void:
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
