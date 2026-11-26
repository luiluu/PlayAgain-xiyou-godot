extends Node
## T545 复量（T544 探针照抄，加 --memo=0 关回退开关＝修复前、--lite 只量打开／切页／移动，跳过逐环节拆分）
## T544 量数探针（只量不改；不是回归测试，没有 .tscn，不进检查.sh）：
## 主菜单技能页按「被动」技能数量分档，量打开、首帧、光标移动一格（含下一帧绘制）的耗时，并拆分各环节。
## 跑法：本文件复制进 01_Godot工程/tests/，临时建一个挂它的 .tscn，godot --headless --audio-driver Dummy --path . res://tests/<临时>.tscn [-- --skin=1 --tiers=20,120]；量完删掉复制件
var TIERS := [20, 60, 120, 240, 400]
const MOVES := 12
var skin_force := false
var lite := false
var out := []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--skin=1":
			skin_force = true
		if arg == "--memo=0":
			XSkillScene.PAGE_READ_MEMO = false
		if arg == "--lite":
			lite = true
		if arg.begins_with("--tiers="):
			TIERS = Array(arg.substr(8).split(",")).map(func(x): return int(x))
	_run.call_deferred()


func frame_us() -> int:
	var t := Time.get_ticks_usec()
	await get_tree().process_frame
	return Time.get_ticks_usec() - t


func timed(f: Callable, n := 1) -> float:
	var t := Time.get_ticks_usec()
	for i in n:
		f.call()
	return float(Time.get_ticks_usec() - t) / n / 1000.0


func passive_pool() -> Array:
	var ids := []
	var rows: Array = XDB.table("Skills")
	for i in range(1, rows.size()):
		var r = rows[i]
		if r is Dictionary and int(r.get("stypeId", 0)) == 4 and str(r.get("name", "")) != "" and not XTianqiSkills.is_shell(i):
			ids.append(i)
	return ids


func _run() -> void:
	XSave.dir_override = "user://t544_probe"
	XUiSkin.FORCE = skin_force
	var pool := passive_pool()
	# 打乱但固定
	var picked := []
	var k := 0
	while picked.size() < TIERS[TIERS.size() - 1] and k < pool.size() * 3:
		var id: int = pool[(k * 7919) % pool.size()]
		k += 1
		if not picked.has(id):
			picked.append(id)
	# 空帧基线
	var idle := 0
	for i in 10:
		idle += await frame_us()
	print("IDLE_FRAME_MS=%.3f" % (idle / 10.0 / 1000.0))
	for n in TIERS:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var a := s.actor(1)
		for id in picked.slice(0, n):
			a.learn_skill(id)
		a.change_level(80)
		a.refresh_passive()
		a.recover_all()
		var row := {"n_passive": n, "skin": skin_force}
		row.all_skills = a.skills().size()
		# —— 打开 ——
		var t0 := Time.get_ticks_usec()
		var page := XSkillScene.new()
		page.actor_index = 0
		add_child(page)
		row.open_ready_ms = (Time.get_ticks_usec() - t0) / 1000.0
		row.open_first_frame_ms = await frame_us() / 1000.0
		await frame_us()
		# 切到被动类型（模拟按下移动到被动，再确定进列表）
		var types := page.types()
		var ti := types.find(4)
		row.types = types.map(func(t): return page.type_name(t))
		t0 = Time.get_ticks_usec()
		page.type_index = ti
		page._refresh()
		row.switch_type_refresh_ms = (Time.get_ticks_usec() - t0) / 1000.0
		row.switch_type_frame_ms = await frame_us() / 1000.0
		t0 = Time.get_ticks_usec()
		page.mode = "list"
		page.index = 0
		page._refresh()
		row.enter_list_refresh_ms = (Time.get_ticks_usec() - t0) / 1000.0
		row.enter_list_frame_ms = await frame_us() / 1000.0
		row.n_entries = page.entries().size()
		# —— 光标移动（往下，含滚动） ——
		var mv_ref := 0.0
		var mv_frame := 0.0
		for i in MOVES:
			t0 = Time.get_ticks_usec()
			page._move(1, false, false)
			mv_ref += (Time.get_ticks_usec() - t0) / 1000.0
			mv_frame += await frame_us() / 1000.0
		row.move_refresh_ms = mv_ref / MOVES
		row.move_frame_ms = mv_frame / MOVES
		row.page_read_memo = XSkillScene.PAGE_READ_MEMO
		row.read_mismatches = XActor.read_mismatches.size()
		if lite:
			print("ROW=" + JSON.stringify(row))
			page.queue_free()
			await frame_us()
			continue
		# —— 拆分 ——
		row.split_skills_ms = timed(func(): a.skills(), 5)
		row.split_entries_ms = timed(func(): page.entries(), 5)
		row.split_types_ms = timed(func(): page.types(), 5)
		var ents := page.entries()
		row.split_usable_all_ms = timed(func():
			for e in ents:
				page.usable(e), 3)
		row.split_costs_all_ms = timed(func():
			for e in ents:
				page._costs(a, e), 3)
		row.split_custom_cost_all_ms = timed(func():
			for e in ents:
				XSkillScene.custom_cost_row(e, 28), 3)
		row.split_mastery_all_ms = timed(func():
			for e in ents:
				a.skillMasteryLevelOf(int(e.id)), 3)
		row.split_row_meta_all_ms = timed(func():
			for e in ents:
				XTianqiSecrets.ui_row_meta(a, e), 3)
		var cur := page.current()
		row.split_skill_view_ms = timed(func(): XGrowthHelp.skill_view(cur, a), 5)
		row.split_help_show_ms = timed(func(): page._update_help(), 5)
		row.split_current_ms = timed(func(): page.current(), 5)
		if page.skin != null:
			row.split_skin_sync_ms = timed(func(): page.skin.sync(), 3)
			row.split_skin_rows_all_ms = timed(func():
				for e in ents:
					page.skin._row(a, e), 3)
			row.split_skin_reason_all_ms = timed(func():
				for e in ents:
					page.skin.skill_reason(a, e), 3)
		# 列表绘制（旧界面）：包一层 painter 计时
		var paint_ms := [0.0, 0]
		var orig: Callable = page.list_win.canvas.painter
		page.list_win.canvas.painter = func(c):
			var tt := Time.get_ticks_usec()
			orig.call(c)
			paint_ms[0] += (Time.get_ticks_usec() - tt) / 1000.0
			paint_ms[1] += 1
		page.list_win.canvas.queue_redraw()
		await frame_us()
		await frame_us()
		row.list_paint_ms = paint_ms[0] / maxi(paint_ms[1], 1)
		row.list_paint_calls = paint_ms[1]
		# 对照：整次绘制包进只读窗口（XActor.read_begin／read_end，O-348 战斗技能列表已这样做）
		paint_ms[0] = 0.0
		paint_ms[1] = 0
		page.list_win.canvas.painter = func(c):
			var tt := Time.get_ticks_usec()
			XActor.read_begin()
			orig.call(c)
			XActor.read_end()
			paint_ms[0] += (Time.get_ticks_usec() - tt) / 1000.0
			paint_ms[1] += 1
		page.list_win.canvas.queue_redraw()
		await frame_us()
		await frame_us()
		row.memo_list_paint_ms = paint_ms[0] / maxi(paint_ms[1], 1)
		row.memo_costs_all_ms = timed(func():
			XActor.read_begin()
			for e in ents:
				page._costs(a, e)
			XActor.read_end(), 3)
		row.memo_usable_all_ms = timed(func():
			XActor.read_begin()
			for e in ents:
				page.usable(e)
			XActor.read_end(), 3)
		if page.skin != null:
			row.memo_skin_sync_ms = timed(func():
				XActor.read_begin()
				page.skin.sync()
				XActor.read_end(), 3)
		var mv2 := 0.0
		for i in 6:
			t0 = Time.get_ticks_usec()
			XActor.read_begin()
			page._move(-1, false, false)
			XActor.read_end()
			mv2 += (Time.get_ticks_usec() - t0) / 1000.0
			mv2 += await frame_us() / 1000.0
		row.memo_move_total_ms = mv2 / 6
		print("ROW=" + JSON.stringify(row))
		out.append(row)
		page.queue_free()
		await frame_us()
	print("DONE")
	get_tree().quit.call_deferred(0)
