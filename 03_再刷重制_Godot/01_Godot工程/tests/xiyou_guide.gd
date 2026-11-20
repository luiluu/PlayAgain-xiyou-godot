extends Node
const Z := preload("res://tests/lib/zh_fwd.gd")
## 修行指引第二阶段（XGuide：区段里程碑、方桌大厅「商店向导」→「下一步建议」）：与 mv_oracle/guide_probe.cjs 逐例比（generated/oracle/guide.json）。
## advice.* 比参照里去掉 CodexZones 的文字（战力短板段不移植，O-050），另查完整文字只多这一段。
## 另测：区段表与 guide_atlas.json 一致、看过标记随存档、商店向导事件（参照里的 Map004 事件 73 指令列）选「下一步建议」的显示、
## 消息窗 <WordWrap>（YEP setWordWrap）。

const ORACLE := "res://modes/xiyou/generated/oracle/guide.json"
const Base := preload("res://tests/xiyou_zhenqi.gd")
const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results := []
var s: XState
var _cmp = Base.new()
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _same(a, b) -> bool:
	return _cmp._same(a, b)


func _fresh() -> void:
	s = XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	XState._become_current(s)


func _set_zq(a: XActor, d: Dictionary) -> void:
	var z := XZhenqi.default_data()
	for k in d:
		z[k] = d[k]
	a.zhenqi = XZhenqi.from_save(z)


func _setup(o: Dictionary) -> void:
	if o.has("route"):
		s.set_switch(int(o.route), true)
	if o.has("progress"):
		s.set_variable(20, int(o.progress) + 1)
	for id in o.get("extra", []):
		s.add_actor(int(id))
	for id in o.get("data", {}):
		_set_zq(s.actor(int(id)), o.data[id])
	if o.has("supplyFirst"):
		var first := {}
		for k in o.supplyFirst:
			first[str(k)] = true
		s.race_supply = {"counts": {}, "first": first, "inbox": {}}


func _case(id: String, setup: Dictionary):
	_fresh()
	if id == "atlas":
		return XGuide.atlas()
	if id == "segment.floors":
		var out := []
		for v in range(37):
			s.set_variable(20, v)
			var f := XZhenqi.progress_floor(s)
			out.append([v, f, XGuide.segment_of(f).get("key")])
		return out
	if id == "milestone.pick":
		var out := []
		for row in [["new", 0, []], ["seenA", 0, ["seg:a"]], ["f7", 7, ["seg:a"]], ["f7.fresh", 7, []], ["f33", 33, []], ["f36", 36, []]]:
			_fresh()
			s.set_variable(20, int(row[1]) + 1)
			for k in row[2]:
				XGuide.seen(s, k, true)
			var seg := XGuide.segment_of(XZhenqi.progress_floor(s))
			out.append([row[0], seg.get("key"), XGuide.seen(s, "seg:" + str(seg.key))])
			# pending_milestone 与原版判定一致：看过就不再弹
			check("pending." + str(row[0]), XGuide.pending_milestone(s).is_empty() == XGuide.seen(s, "seg:" + str(seg.key)))
		return out
	if id == "milestone.save":
		XGuide.seen(s, "seg:a", true)
		XGuide.seen(s, "seg:b", true)
		var d = JSON.parse_string(JSON.stringify(s.to_dict()))
		_fresh()
		var before := XGuide.seen(s, "seg:a")
		var back := XState.from_dict(d)
		return {"beforeRestore": before, "a": XGuide.seen(back, "seg:a"), "b": XGuide.seen(back, "seg:b"), "c": XGuide.seen(back, "seg:c"), "raw": back.guide_seen}
	if id.begins_with("milestone."):
		var seg := {}
		for x in XGuide.atlas():
			if str(x.key) == str(setup.segment):
				seg = x
		var t := XGuide.milestone_texts(seg)
		return {"texts": t, "list": XGuide.page_list(t)}
	if id.begins_with("advice."):
		_setup(setup)
		var t := XGuide.advice_texts(s)
		return {"texts": t, "list": XGuide.page_list(t)}
	if id == "race.bands":
		var r = XDB.table("CodexRaces")
		return {"bands": r.bands, "stones": r.stones.map(func(i): return [int(i), str(XDB.rec("Items", int(i)).name)])}
	return null


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	var n := 0
	var shop_list := []
	if check("guide_oracle_loaded", data is Dictionary, ORACLE):
		for c in data.cases:
			if not c.errors.is_empty():
				check("oracle_" + c.id, false, c.errors)
				continue
			if c.id == "shopGuide.event":
				shop_list = c.observed.list
				check("shop_guide_note", c.observed.note == "<CodexEconomy: guide>" and c.observed.name == "商店向导", c.observed)
				continue
			n += 1
			var got = _case(c.id, c.setup)
			var want = Z.fwd(c.observed)  # T027：参照里的 Boss 换成首领
			if c.id.begins_with("advice."):
				# 原版完整文字＝去掉五乘区的文字＋末尾「战力短板」一段（O-050）
				var full: Array = want.full
				check(c.id + ".zones_only_extra", full.size() == want.texts.size() + 1 and _same(full.slice(0, -1), want.texts) and str(full[-1]).contains("战力短板"), full)
				want = {"texts": want.texts, "list": want.list}
			if c.id.begins_with("milestone.") and c.id != "milestone.pick" and c.id != "milestone.save":
				want = _adapt_milestone(c.setup, want)
			check(c.id, got != null and _same(got, want), [got, want])
	check("guide_cases", n >= 22, n)
	_milestone_content()
	_atlas_file()
	_word_wrap()
	await _shop_flow(shop_list)
	await _map_milestone()
	await _tianqi_milestone()
	await _tianqi_advice_and_status()
	var failed := results.filter(func(r): return not r.passed)
	_cmp.free()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_guide", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)


## 2026-10-18 核查第二批：里程碑介绍在显示层改写（原表保留）——神秘珠掉率读实际配置（10%），
## 不介绍未移植的五乘区预算与未开放的洪荒入口。参照文字里只换这一句介绍，其余逐字照比；分页按改写后的文字重算。
func _adapt_milestone(setup: Dictionary, want: Dictionary) -> Dictionary:
	var seg := {}
	for x in XGuide.atlas():
		if str(x.key) == str(setup.segment):
			seg = x
	var texts: Array = want.texts.duplicate()
	if seg.is_empty() or texts.is_empty():
		return want
	texts[0] = str(texts[0]).replace(str(seg.intro), XGuide.milestone_intro(seg))
	return {"texts": texts, "list": XGuide.page_list(texts)}


func _milestone_content() -> void:
	var by := {}
	for x in XGuide.atlas():
		by[str(x.key)] = x
	var all := ""
	for k in by:
		all += "\n".join(XGuide.milestone_texts(by[k]))
	var rate := XGuide.pct(float(XDB.table("CodexOrbs").get("dropRate", 0.1)))
	check("milestone_orb_rate", rate == "10%" and XGuide.milestone_intro(by.a).contains("10%") and not XGuide.milestone_intro(by.a).contains("20%"), XGuide.milestone_intro(by.a))
	check("milestone_no_zones", not all.contains("乘区") and not all.contains("溢出"), all)
	check("milestone_no_honghuang", not all.contains("洪荒") and not all.contains("诅咒"), all)
	check("milestone_atlas_kept", str(by.a.intro).contains("20%") and str(by.c.intro).contains("洪荒"), [by.a.intro, by.c.intro])


func _atlas_file() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/guide_atlas.json"))
	check("atlas_file", d is Dictionary and str(d.get("sha256", "")).length() == 64 and d.atlas.size() == 7, d.keys() if d is Dictionary else d)


## YEP_MessageCore setWordWrap（Word Wrap Space 关）
func _word_wrap() -> void:
	check("ww_tag", _same(XMessageBox.word_wrap("<WordWrap>甲\n乙<br>丙"), ["甲乙\n丙", true]))
	check("ww_case", _same(XMessageBox.word_wrap("<wordwrap>甲\r\n\n乙"), ["甲乙", true]))
	check("ww_off_br", _same(XMessageBox.word_wrap("甲\n乙<BR>丙<line break>"), ["甲\n乙丙", false]))


## 固定应答宿主：选项按 picks 依次回答（用完取最后一项＝离开）
class FakeHost:
	extends Node
	var picks: Array = []
	var trace: Array = []

	func show_message(m: Dictionary) -> int:
		trace.append({"lines": m.get("lines", []), "choices": m.get("choices")})
		if m.get("choices") != null:
			return int(picks.pop_front()) if not picks.is_empty() else m.choices.size() - 1
		return 0

	func refresh_events() -> void:
		pass

	func character(_id: int, _this: int):
		return null

	func toast(_t: String) -> void:
		pass


## 商店向导：开场说明＋五个选项 → 「下一步建议」插入建议文字（每段一页）→ 回到原事件结束
func _shop_flow(list: Array) -> void:
	if not check("shop_list", not list.is_empty()):
		return
	_fresh()
	s.set_variable(20, 8)
	_set_zq(s.actor(1), {"qi": 3000, "realm": 1, "pending": [1]})
	var h := FakeHost.new()
	h.picks = [0]
	var interp := MVInterpreter.new(h, 4, 0, list)
	await interp.run()
	var want := XGuide.advice_texts(s).map(func(t): return ["<WordWrap>" + t])
	var shown := h.trace.slice(1).map(func(e): return e.lines)
	check("shop_flow_choices", h.trace.size() > 0 and _same(h.trace[0].choices, ["下一步建议", "方桌大厅", "养成入口与材料", "其他地方", "离开"]), h.trace)
	check("shop_flow_advice", _same(shown, want), [shown, want])
	check("shop_flow_no_skips", interp.skipped.is_empty(), interp.skipped)
	check("shop_flow_pending_name", str(want[0][0]).contains("待选奖励") and str(want[0][0]).contains(s.actor(1).display_name()), want[0])
	h.free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _count(text: String) -> int:
	return XMessageBox.transcript.filter(func(t): return str(t).contains(text)).size()


## 真实地图：方桌大厅新局，30 帧内弹出「神魔之塔 1～6 层」说明一次（记看过）；不再重弹；通过第 7 层后弹 7～12 层
func _map_milestone() -> void:
	XSave.dir_override = "user://test_xiyou_guide"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.whisper_mark("rift1")   # 新源大厅首次进入的漩涡过场（Map4 EV76）另测（xiyou_floor_reach004），这里当作播过，免得盖住里程碑提示
	XConfig.whisper_mark("rift2")   # 漩涡二阶段过场（XRift，Map4 EV203：rift1 看过就播）同样占住大厅，一并记成看过
	XMessageBox.auto = true
	XMessageBox.transcript.clear()
	_fresh()
	s.x = 14
	s.y = 23
	var map := XMapScene.new()
	add_child(map)
	await _frames(90)
	check("map_shop_guide_npc", map.events.any(func(e): return e.event_id == 73 and e.grid == Vector2i(15, 5)), map.events.map(func(e): return e.event_id))
	check("map_milestone_a", _count("神魔之塔 1～6 层") == 1 and XGuide.seen(s, "seg:a"), XMessageBox.transcript)
	await _frames(90)
	check("map_milestone_once", _count("神魔之塔 1～6 层") == 1, XMessageBox.transcript)
	s.set_variable(20, 8)
	await _frames(90)
	check("map_milestone_b", _count("神魔之塔 7～12 层") == 1 and XGuide.seen(s, "seg:b"), XMessageBox.transcript)
	XGuide.MILESTONE_ENABLED = false
	s.set_variable(20, 14)
	await _frames(90)
	check("map_milestone_disabled", _count("神魔之塔 13～15 层") == 0 and not XGuide.seen(s, "seg:c"))
	XGuide.MILESTONE_ENABLED = true
	map.queue_free()
	await _frames(2)
	XMessageBox.auto = false
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())


func _tianqi_milestone() -> void:
	var kit = Kit.new("xiyou_guide_tq")
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	var tq := Kit.new_game("jiusi")
	var by := {}
	for x in XGuide.atlas():
		by[str(x.key)] = x
	var all_tq := ""
	for k in by:
		var seg: Dictionary = by[k]
		var tt := XGuide.milestone_title(seg, tq)
		var txt := "\n".join(XGuide.milestone_texts(seg, tq))
		all_tq += txt + "\n"
		check("tq_title_" + k, tt.begins_with("高塔 ") and not tt.contains("神魔之塔"), tt)
	var bad_tq := ["神魔之塔", "洪荒", "诅咒", "权能", "境界", "大境界", "大圆满", "赌场", "乘区", "真气", "闭关", "道法", "本命兵", "灵根", "兵仙", "神兵试炼"]
	var leaks := bad_tq.filter(func(b): return all_tq.contains(b))
	check("tq_milestone_no_residue", leaks.is_empty(), leaks)
	check("tq_milestone_content", XGuide.milestone_intro(by.a, tq).contains("5 层高塔") and XGuide.milestone_intro(by.a, tq).contains("10%") and XGuide.milestone_intro(by.b, tq).contains("阶段成长入口") and XGuide.milestone_intro(by.b, tq).contains("通用祝福石") and XGuide.milestone_intro(by.c, tq).contains("秘境被动书") and XGuide.milestone_intro(by.c, tq).contains("心之钢") and XGuide.milestone_intro(by.d, tq).contains("修行·详细") and XGuide.milestone_intro(by.e, tq).contains("19层起") and XGuide.milestone_intro(by.f, tq).contains("固定减伤") and XGuide.milestone_intro(by.g, tq).contains("34～36层") and XGuide.milestone_intro(by.g, tq).contains("号卷"), all_tq)
	# 回退开关：关掉后回到西游原样文字
	XGuide.TIANQI_MILESTONE_ENABLED = false
	check("tq_milestone_rollback", XGuide.milestone_title(by.a, tq) == "神魔之塔 1～6 层" and "\n".join(XGuide.milestone_texts(by.c, tq)).contains("突破境界"), XGuide.milestone_texts(by.a, tq))
	XGuide.TIANQI_MILESTONE_ENABLED = true
	# 西游档：里程碑文字保持西游版
	_fresh()
	check("plain_milestone_kept", XGuide.milestone_title(by.a, s) == "神魔之塔 1～6 层" and "\n".join(XGuide.milestone_texts(by.c, s)).contains("突破境界"), XGuide.milestone_texts(by.a, s))
	# 真地图：天启篇档进大厅首弹「高塔 1～6 层」且仅弹一次
	tq = Kit.new_game("jiusi")
	tq.map_id = 4
	tq.x = 14
	tq.y = 23
	XMessageBox.auto = true
	XMessageBox.transcript.clear()
	var map := XMapScene.new()
	add_child(map)
	await _frames(90)
	check("tq_map_milestone_a", _count("高塔 1～6 层") == 1 and _count("神魔之塔") == 0 and _count("5 层高塔") == 1 and XGuide.seen(tq, "seg:a"), XMessageBox.transcript)
	await _frames(90)
	check("tq_map_milestone_once", _count("高塔 1～6 层") == 1, XMessageBox.transcript)
	map.queue_free()
	await _frames(2)
	XMessageBox.auto = false
	kit.teardown()


func _until(cond: Callable, n := 600) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().physics_frame
	return false


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await get_tree().physics_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(6)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var err := get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	check("shot_" + name, err == OK, err)


func _shot_advice(box: XMessageBox, texts: Array, tag: String) -> void:
	var picks := [0, 1, texts.size() - 1]
	var names := ["advice_p1_" + tag, "advice_p2_" + tag, "advice_entry_" + tag]
	for k in picks.size():
		var msg := {"face": "", "index": 0, "position": 2, "lines": ["<WordWrap>" + str(texts[picks[k]])]}
		var done := {"v": null}
		var go := func(): done.v = await box.run(msg)
		go.call()
		await _until(func(): return box.win.pause and box._wait == 0)
		await _frames(8)
		await _shot(names[k])
		while done.v == null:
			await _press("ui_accept")
			await get_tree().physics_frame
		await _frames(6)


func _row_text(rows: Array) -> String:
	var parts := PackedStringArray()
	for r in rows:
		if r.has("text"):
			parts.append(str(r.text))
		elif r.has("cells"):
			parts.append(" ".join(PackedStringArray(r.cells)))
	return "\n".join(parts)


func _tianqi_advice_and_status() -> void:
	var kit = Kit.new("xiyou_guide_tq_t145")
	var tq := Kit.new_game("jiusi")
	_set_zq(tq.actor(tq.party[0]), {"qi": 3000, "realm": 1, "pending": [1]})
	# 1. advice_texts 天启篇全区段校验
	var all_adv := ""
	for prog in [0, 7, 13, 16, 19, 22, 26, 33]:
		tq.set_variable(20, prog + 1)
		all_adv += "\n".join(XGuide.advice_texts(tq)) + "\n"
	var bad_adv := ["神魔之塔", "洪荒", "诅咒", "权能", "境界", "大圆满", "真气", "道法", "闭关", "瓶颈", "神兵试炼", "本命兵", "灵根", "溢出再动", "原作", "Boss", "boss", "锚"]
	var adv_leaks := bad_adv.filter(func(b): return all_adv.contains(b))
	check("tq_advice_no_residue", adv_leaks.is_empty(), adv_leaks)
	check("tq_advice_no_jing", not all_adv.replace("秘境", "").contains("境"), all_adv)
	tq.set_variable(20, 1)
	var adv0 := "\n".join(XGuide.advice_texts(tq))
	check("tq_advice_f0", adv0.contains("难度：九死，已通过第0层") and adv0.contains("下一个守层者在第1层") and adv0.contains("5 层高塔可抽取一位新伙伴") and adv0.contains("高塔 1～6 层") and adv0.contains("10% 掉未鉴定神秘珠（菜单「宝珠坊」鉴定，高层品质更好）") and adv0.contains("状态界面「修行」与「修行·详细」页"), adv0)
	tq.set_variable(20, 34)
	var adv33 := "\n".join(XGuide.advice_texts(tq))
	check("tq_advice_f33", adv33.contains("守层者已全部通过，可继续推进34～36层") and adv33.contains("高塔 26～33 层"), adv33)
	tq.set_variable(20, 8)
	var adv7 := "\n".join(XGuide.advice_texts(tq))
	check("tq_advice_f7_stone", adv7.contains("祝福进阶石·Ⅱ阶"), adv7)
	# 回退开关 & 西游档不变
	XGuide.TIANQI_ADVICE_ENABLED = false
	tq.set_variable(20, 14)
	var adv_rb := "\n".join(XGuide.advice_texts(tq))
	check("tq_advice_rollback", adv_rb.contains("神魔之塔") and adv_rb.contains("权能") and adv_rb.contains("闭关") and adv_rb.contains("真气"), adv_rb)
	XGuide.TIANQI_ADVICE_ENABLED = true
	_fresh()
	s.set_variable(20, 14)
	var adv_xy := "\n".join(XGuide.advice_texts(s))
	check("plain_advice_kept", adv_xy.contains("路线：普通") and adv_xy.contains("神魔之塔") and adv_xy.contains("权能") and adv_xy.contains("真气"), adv_xy)

	# 2. 修行状态页（第 4 页「修行」、第 5 页「修行·详细」、v0.28 单页、建议与战力条）
	XState._become_current(tq)
	tq.set_variable(20, 20) # 第 19 进度层 -> 状态页显示 第20层
	var a: XActor = tq.actor(tq.party[0])
	var pr := _row_text(XGuide.panel_rows(tq, a))
	var dr := _row_text(XGuide.detail_rows(tq, a))
	var vr := _row_text(XGuide.page_rows_v028(tq, a))
	# 覆测“爆伤/结算书学满”与“全达标 ok”分支
	var c_bad := {"now": {"cri": 0.5, "hit": 0.5, "crit": -0.6, "fin": 0.0, "atk": 100.0, "mat": 100.0, "settle": 0.2}, "base": {"cri": 1.0, "hit": 1.0, "crit": 0.0, "fin": 0.0, "atk": 1000.0, "mat": 1000.0, "settle": 1.0}, "diff": {"cri": -0.5, "hit": -0.5, "crit": -0.6, "fin": 0.0, "atk": 0.1, "mat": 0.1, "settle": 0.2}}
	var saved_skills := a.skill_ids.duplicate()
	for sid in [6309, 6310, 6311, 6312, 6325, 6326, 6327, 6328]:
		if not a.skill_ids.has(sid):
			a.skill_ids.append(sid)
	var maxbook_sug := "\n".join(XGuide.panel_suggestions(tq, a, c_bad).map(func(x): return str(x.text)))
	var maxbook_tips := "\n".join(XGuide.tips(tq, a, c_bad))
	var c_ok := {"now": {"cri": 1.0, "hit": 1.0, "crit": 0.5, "fin": 0.0, "atk": 1000.0, "mat": 1000.0, "settle": 1.0}, "base": {"cri": 1.0, "hit": 1.0, "crit": 0.5, "fin": 0.0, "atk": 1000.0, "mat": 1000.0, "settle": 1.0}, "diff": {"cri": 0.0, "hit": 0.0, "crit": 0.0, "fin": 0.0, "atk": 1.0, "mat": 1.0, "settle": 1.0}}
	var ok_sug := "\n".join(XGuide.panel_suggestions(tq, a, c_ok).map(func(x): return str(x.text)))
	var ok_tips := "\n".join(XGuide.tips(tq, a, c_ok))
	a.skill_ids = saved_skills
	var all_st := "\n".join([pr, dr, vr, maxbook_sug, maxbook_tips, ok_sug, ok_tips])
	var bad_st := ["真气", "境界", "道祖", "道法", "天道加持", "天道补偿", "待选突破", "突破奖励", "突破条件", "大圆满", "淬元丹", "裂山霸力丹", "九霄焚天丹", "蜜雪冰城", "洪荒女皇", "丹药", "神兵试炼", "溢出再动", "锚"]
	var st_leaks := bad_st.filter(func(b): return all_st.contains(b))
	check("tq_status_no_residue", st_leaks.is_empty(), st_leaks)
	check("tq_status_no_jing", not all_st.replace("秘境", "").contains("境"), all_st)
	check("tq_panel_rows_keep", pr.contains("九死·第20层") and pr.contains("挑战评估：") and pr.contains("结算伤害：") and pr.contains("必备属性：") and pr.contains("建议：1. ") and pr.contains("详细数据：见「修行·详细」页"), pr)
	var det := XGuide.detail_rows(tq, a)
	# T121：烙印开着时第 5 页先是「烙印」段，再是难度对照
	var diff_head := det.filter(func(x): return x.type == "head" and str(x.text).begins_with("难度对照　九死·第20层"))
	var brand_first: bool = (str(det[0].text) == "烙印") if XTianqiBrand.on(tq) else str(det[0].text).begins_with("难度对照")
	check("tq_detail_starts_diff", not det.is_empty() and det[0].type == "head" and brand_first and diff_head.size() == 1, det.slice(0, 3))
	check("tq_maxbook_sources", maxbook_sug.contains("从装备、词条与种族祝福补充爆伤") and maxbook_sug.contains("从装备、词条、秘境被动书与种族祝福提升攻击") and maxbook_sug.contains("从装备与结算类被动补充伤害"), maxbook_sug)
	check("tq_ok_sources", ok_sug.contains("抽奖券、神秘珠与专属掉落") and ok_tips.contains("装备、词条、结算类被动"), [ok_sug, ok_tips])
	check("tq_strip_empty", _same(XGuide.strip_text(tq, a), ["", false]), XGuide.strip_text(tq, a))
	# 真 StatusPage 控件验证（含新皮肤）
	var p := XStatusPage.new()
	add_child(p)
	await _frames(4)
	p.set_page(3)
	await _frames(2)
	var p3_ops := "\n".join(XStatusPage.page_ops(a, 3, 612.0).filter(func(op): return op[0] == "text").map(func(op): return str(op[1])))
	var p4_ops := "\n".join(XStatusPage.page_ops(a, 4, 612.0).filter(func(op): return op[0] == "text").map(func(op): return str(op[1])))
	check("tq_status_page_ui", not p3_ops.contains("真气") and not p3_ops.contains("境界") and not p3_ops.contains("洪荒女皇") and not p4_ops.contains("真气") and not p4_ops.contains("道法") and p3_ops.contains("挑战评估：") and p4_ops.contains("难度对照"), [p3_ops, p4_ops])
	p.queue_free()
	await _frames(2)
	# 回退开关 & 西游档不变
	XGuide.TIANQI_STATUS_ENABLED = false
	var pr_rb := _row_text(XGuide.panel_rows(tq, a))
	var det_rb := XGuide.detail_rows(tq, a)
	check("tq_status_rollback", pr_rb.contains("境界：") and pr_rb.contains("真气：伤害") and str(det_rb[0].text) == "真气", [pr_rb, det_rb[0]])
	XGuide.TIANQI_STATUS_ENABLED = true
	_fresh()
	s.set_variable(20, 20)
	var ax := s.actor(s.party[0])
	var pr_xy := _row_text(XGuide.panel_rows(s, ax))
	var det_xy := XGuide.detail_rows(s, ax)
	check("plain_status_kept", pr_xy.contains("境界：") and pr_xy.contains("真气：伤害") and str(det_xy[0].text) == "真气" and str(XGuide.strip_text(s, ax)[0]).begins_with("真气·"), [pr_xy, det_xy[0]])

	# 3. 可选改前／改后真画面截图（传入 -- --out=<目录> 且非 headless 时）
	if out_dir != "" and DisplayServer.get_name() != "headless":
		XMessageBox.auto = false
		XState._become_current(tq)
		var bg := ColorRect.new()
		bg.color = Color(0.1, 0.12, 0.16)
		bg.size = Vector2(1280, 720)
		add_child(bg)
		var box := XMessageBox.new()
		add_child(box)
		await _frames(4)
		for on in [false, true]:
			var tag := "after" if on else "before"
			XGuide.TIANQI_ADVICE_ENABLED = on
			XGuide.TIANQI_STATUS_ENABLED = on
			tq.set_variable(20, 14)
			await _shot_advice(box, XGuide.advice_texts(tq), tag)
			tq.set_variable(20, 20)
			var sp := XStatusPage.new()
			add_child(sp)
			await _frames(6)
			sp.set_page(3)
			await _shot("status_p4_" + tag)
			sp.set_page(4)
			await _shot("status_p5_" + tag)
			sp.queue_free()
			await _frames(4)
		box.queue_free()
		bg.queue_free()
		await _frames(3)
		XGuide.TIANQI_ADVICE_ENABLED = true
		XGuide.TIANQI_STATUS_ENABLED = true
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	kit.teardown()

