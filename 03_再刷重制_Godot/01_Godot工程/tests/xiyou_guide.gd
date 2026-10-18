extends Node
## 修行指引第二阶段（XGuide：区段里程碑、方桌大厅「商店向导」→「下一步建议」）：与 mv_oracle/guide_probe.cjs 逐例比（generated/oracle/guide.json）。
## advice.* 比参照里去掉 CodexZones 的文字（战力短板段不移植，O-050），另查完整文字只多这一段。
## 另测：区段表与 guide_atlas.json 一致、看过标记随存档、商店向导事件（参照里的 Map004 事件 73 指令列）选「下一步建议」的显示、
## 消息窗 <WordWrap>（YEP setWordWrap）。

const ORACLE := "res://modes/xiyou/generated/oracle/guide.json"
const Base := preload("res://tests/xiyou_zhenqi.gd")
var results := []
var s: XState
var _cmp = Base.new()


func _ready() -> void:
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
			var want = c.observed
			if c.id.begins_with("advice."):
				# 原版完整文字＝去掉五乘区的文字＋末尾「战力短板」一段（O-050）
				var full: Array = want.full
				check(c.id + ".zones_only_extra", full.size() == want.texts.size() + 1 and _same(full.slice(0, -1), want.texts) and str(full[-1]).contains("战力短板"), full)
				want = {"texts": want.texts, "list": want.list}
			check(c.id, got != null and _same(got, want), [got, want])
	check("guide_cases", n >= 22, n)
	_atlas_file()
	_word_wrap()
	await _shop_flow(shop_list)
	var failed := results.filter(func(r): return not r.passed)
	_cmp.free()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_guide", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)


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
