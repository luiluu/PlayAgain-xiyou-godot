extends Node
## 角色换装（XCostumes／XCostumesScene）：对照冻结 v0.28 参照 tests/fixtures/costume_oracle.json（mv_oracle/costume_probe.cjs）。
## - registry.*：58 张换装卡（技能、状态、图、名字）。
## - actor.*：角色 1 学两张卡、上卡状态 1201、关掉、存档往返、再开：开关、卡名、战斗外观（重制只算战斗中，地图外观原版是卡图，
##   因为状态 Custom Apply Effect 改了 _battlerName，重制没有这层，不比）。
## - owned：队伍＋角色仓库去重。options.*：设置页状态「打开」（重制设置只在游戏中打开，标题与战斗那两步不比）。
## - page.*：页面几何、行文字、确定切换与音效、取消返回；设置页确定打开换装页。
const FIXTURE := "res://tests/fixtures/costume_oracle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _ready() -> void:
	XConfig.path_override = ""
	_run.call_deferred()


func _case(ref: Dictionary, id: String) -> Dictionary:
	for c in ref.cases:
		if c.id == id:
			check(id + ".errors", c.errors.is_empty(), c.errors)
			return c.observed
	check(id + ".missing", false)
	return {}


func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	# 登记
	var want: Array = _case(ref, "registry").cards
	var got := []
	for row in want:
		var hit = null
		for card in XCostumes.registry().values():
			if int(card.skill) == int(row[0]):
				hit = [int(card.skill), int(card.state), card.image, card.name]
		got.append(hit if hit != null else [int(row[0]), null])
	check("registry.cards", JSON.stringify(got) == JSON.stringify(want.map(func(r): return [int(r[0])] + (r.slice(1) if r[1] == null else [int(r[1]), r[2], r[3]]))), got.slice(0, 3))
	check("registry.size", XCostumes.registry().size() == 58, XCostumes.registry().size())
	# 角色
	var s := XState.new_game_blank()
	XState.current = s
	s.party.assign([1, 8])
	var a := s.actor(1)
	var rows: Array = _case(ref, "actor").rows
	var snap := func(tag: String, st: XState, b: XActor) -> Dictionary:
		return {"tag": tag, "enabled": XCostumes.enabled(st, b.actor_id), "cards": XCostumes.cards(b).map(func(c): return c.name),
			"current": XCostumes.current(b).state if XCostumes.current(b) != null else null, "battle": XCostumes.battler_name(st, b)}
	var pick := func(r: Dictionary) -> Dictionary:
		var o := {"tag": r.tag}
		for k in ["enabled", "cards", "current", "battle"]:
			if r.has(k):
				o[k] = int(r[k]) if k == "current" and r[k] != null else r[k]
		return o
	var mine := [snap.call("fresh", s, a)]
	a.learn_skill(6801)
	a.learn_skill(6803)
	mine.append(snap.call("learned", s, a))
	a.state_ids.append(1201)
	mine.append(snap.call("state", s, a))
	XCostumes.set_enabled(s, 1, false)
	mine.append(snap.call("disabled", s, a))
	var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	mine.append({"tag": "reloaded", "enabled": XCostumes.enabled(s2, 1)})
	XCostumes.set_enabled(s2, 1, true)
	mine.append({"tag": "reenabled", "enabled": XCostumes.enabled(s2, 1), "battle": XCostumes.battler_name(s2, s2.actor(1))})
	for i in rows.size():
		var w: Dictionary = pick.call(rows[i])
		var g: Dictionary = mine[i]
		var g2 := {}
		for k in w:
			g2[k] = g.get(k)
		check("actor." + str(w.tag), JSON.stringify(g2) == JSON.stringify(w), {"got": g2, "want": w})
	check("actor.not_in_battle", XCostumes.battler_name(s, a, false) == str(a.data().battlerName))
	check("save.old_has_none", XState.from_dict(_without(XState.new_game_blank().to_dict(), "costumeOff")).costume_off.is_empty())
	# 拥有的角色
	var s3 := XState.new_game_blank()
	s3.party.assign([1, 8, 9])
	s3.saved_actors.assign([10, 8, 29])
	check("owned", XCostumes.owned_actors(s3).map(func(x): return x.actor_id) == _case(ref, "owned").owned.map(func(v): return int(v)))
	# 设置页
	var opt_rows: Array = _case(ref, "options").rows
	XState.current = s
	var opt := XOptionsScene.new()
	add_child(opt)
	await get_tree().process_frame
	var oi: int = opt.symbols().find("codexCostumes")
	check("options.game", oi >= 0 and opt._list[oi][2] and opt.status_text(oi) == opt_rows[1].status, opt.status_text(oi))
	opt.index = oi
	XSound.system_log.clear()
	opt.ok()
	await get_tree().process_frame
	check("options.opens_page", opt._page is XCostumesScene and XSound.system_log.is_empty(), XSound.system_log)
	var page: XCostumesScene = opt._page
	check("page.rects", page.head_win.position == Vector2(24, 18) and page.head_win.size == Vector2(1232, 120)
		and page.list_win.position == Vector2(150, 150) and page.list_win.size == Vector2(980, 546), [page.list_win.position, page.list_win.size])
	var first := XCostumesScene.row_texts(page.actors[0])
	check("page.row0", page.actors[0].actor_id == 1 and first == [a.display_name(), "深渊骑士、狼人", "关闭"], first)
	var other := XCostumesScene.row_texts(page.actors[1])
	check("page.row1", other[1] == XCostumesScene.NO_CARD and other[2] == "启用", other)
	XSound.system_log.clear()
	page.ok()
	check("page.toggle", XCostumes.enabled(s, 1) and XCostumesScene.row_texts(page.actors[0])[2] == "启用" and XSound.system_log == [1], XSound.system_log)
	page.cancel()
	await get_tree().process_frame
	check("page.cancel", opt._page == null and XSound.system_log == [1, 2], XSound.system_log)
	opt.queue_free()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _without(d: Dictionary, key: String) -> Dictionary:
	d.erase(key)
	return d
