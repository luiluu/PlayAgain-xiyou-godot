extends Node
## 175 谷雨战斗界面：与 mv_oracle/guyu_ui_probe.cjs 的冻结 v0.28 参照（generated/oracle/guyu_ui.json）比——
## 每步之后两人的侧栏状态字（XGuyu.status_text）、护盾合计、储备、可选比例、选择窗命令表（XGuyu.transfer_commands）、
## 两种方向 × 四种比例 × 两个目标的转移预览（是否合法、数量、受限、原因）与说明（XGuyu.transfer_text）、行动上没写方向比例时的默认；
## shortNumber、战斗外与谷雨不在队时没有状态字、选择窗宽高与打开时的光标／顶行（FIT_ROWS 关掉时照原版 2 行）、
## 五个主动技的动作、法宝说明卡条目（XThreeGrowth：名字、说明、APs 行、每级成长标签）。
## 另在真实战斗画面走一遍：选转移先开选择窗（技能窗留着不可操作）、取消回技能列表、选还春 25% 后选目标、说明卡写转移说明并贴在队员左侧
## （TRANSFER_HELP_NEAR 关掉时照原版从上一张卡的位置修正）、选自己蜂鸣留下、选 1 号按所选方向比例转移、行动后设回给出 50%；
## 侧栏状态字、谷雨待机定在第 0 帧、归根反馈记录与 48 帧画面。只在内存，不写存档。窗口模式加 -- --out=<目录> 截图。
const ORACLE := "oracle/guyu_ui.json"
const DIFFICULTY := 2
var results := []
var out_dir := ""


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 25:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


func _state(rank: int, relic := false) -> XState:
	var s := XState.new_game(DIFFICULTY, 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XGuyu.ACTOR] = rank
	if relic:
		XGuyu._notified_relic = false
		XGuyu.recruit(s)
	s.add_actor(XGuyu.ACTOR)
	s.add_actor(1)
	return s


## 同 xiyou_guyu_battle._battle（参照 battle()）
func _battle(level: int, rank: int, relic := false) -> XBattleLogic:
	var s := _state(rank, relic)
	for id in [XGuyu.ACTOR, 1]:
		s.actor(id).change_level_mv(level)
	XGuyu.sync(s.actor(XGuyu.ACTOR))
	for id in [XGuyu.ACTOR, 1]:
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 99.0
	logic.level_roll = 0.99
	var rand := XBattleRandom.create("0000000000000175")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	logic.start_turn()
	for b in logic.actors + logic.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return logic


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	return v


func _ui(g: XActor, hero: XActor) -> Dictionary:
	var out := {"status": [XGuyu.status_text(g), XGuyu.status_text(hero)], "totalShield": [XGuyu.total_shield(g), XGuyu.total_shield(hero)],
		"reserve": [XGuyu.reserve(g), XGuyu.reserve(hero)], "ratios": XGuyu.transfer_ratios(g),
		"commands": XGuyu.transfer_commands(g).map(func(e): return {"name": e.text, "enabled": e.enabled, "mode": e.mode, "ratio": e.ratio}),
		"transfer": []}
	for mode in ["give", "back"]:
		for ratio in [0.25, 0.5, 0.75, 0.6]:
			for t in [[g, "g"], [hero, "h"]]:
				var p := XGuyu.transfer_preview(g, t[0], mode, ratio)
				out.transfer.append({"mode": mode, "ratio": ratio, "target": t[1], "valid": p.valid, "amount": p.amount, "capped": bool(p.get("capped", false)),
					"reason": p.reason, "text": XGuyu.transfer_text(g, t[0], mode, ratio)})
	var d := XGuyu.transfer_preview(g, hero)
	out.transferDefault = {"valid": d.valid, "amount": d.amount, "text": XGuyu.transfer_text(g, hero)}
	return out


func _want_ui(u: Dictionary) -> Dictionary:
	var out: Dictionary = _norm(u.duplicate(true))
	out.commands = (u.commands as Array).map(func(e): return {"name": e.name, "enabled": e.enabled, "mode": e.ext.mode, "ratio": _norm(e.ext.ratio)})
	out.transferDefault = {"valid": u.transferDefault.valid, "amount": _norm(u.transferDefault.amount), "text": u.transferDefault.text}
	return out


func _script(c: Dictionary) -> void:
	var logic := _battle(int(c.setup.level), int(c.setup.rank), bool(c.setup.get("relic", false)))
	var s := logic.state
	var g: XActor = s.actor(XGuyu.ACTOR)
	var hero: XActor = s.actor(1)
	var who := func(x): return g if str(x) == "g" else hero
	var steps: Array = c.observed.steps
	var roots := 0
	for i in steps.size():
		var want: Dictionary = steps[i]
		var st: Array = want.step
		var name := "%s.%d.%s" % [c.id, i, str(st[0])]
		var logs := []
		match str(st[0]):
			"act":
				var skill := XDB.rec("Skills", int(st[2]))
				if st.size() > 4:
					XGuyu.transfer_mode = str(st[4])  # 选择窗写进这次行动
					XGuyu.transfer_ratio = float(st[5])
				var scope := int(skill.get("scope", 0))
				logs = logic.act(who.call(st[1]), skill, logic.enemies[int(st[3])] if scope >= 1 and scope <= 6 else logic.actors[int(st[3])])
				if st.size() > 4:
					check(name + ".reset_after_action", XGuyu.transfer_mode == "give" and XGuyu.transfer_ratio == 0.5, [XGuyu.transfer_mode, XGuyu.transfer_ratio])
			"turn":
				logs = logic.end_turn()
				logic.start_turn()
			"hp":
				who.call(st[1]).hp = float(st[2])
			"mp":
				g.mp = g.mmp
			"foe":
				logs = logic.act(logic.enemies[int(st[1])], XDB.rec("Skills", int(st[2])), logic.actors[int(st[3])])
			"endBattle":
				logic.end_battle(0)
		roots += logs.filter(func(l): return l is Dictionary and l.get("type") == "guyu_visual" and l.target == g and l.kind == "root").size()
		var got: Dictionary = _norm(_ui(g, hero))
		var exp := _want_ui(want.ui)
		for k in exp:
			if k == "transfer":
				for j in exp.transfer.size():
					var a: Dictionary = got.transfer[j]
					var b: Dictionary = exp.transfer[j]
					check("%s.transfer.%s.%s.%s" % [name, b.mode, str(b.ratio), b.target], a == b, [a, b])
			else:
				check(name + "." + k, got[k] == exp[k], [got[k], exp[k]])
	check(c.id + ".root_visuals", roots == (1 if c.id == "script.sub" else 0), roots)
	if XGuyu.active_battle:
		logic.end_battle(0)


func _short(c: Dictionary) -> void:
	var got: Array = c.setup.nums.map(func(n): return XGuyu.short_number(float(n)))
	check("short", got == c.observed.out, [got, c.observed.out])


func _idle(c: Dictionary) -> void:
	var s := _state(0)
	check("status.idle.outside", [XGuyu.status_text(s.actor(XGuyu.ACTOR)), XGuyu.status_text(s.actor(1))] == c.observed.outside)
	var logic := _battle(35, 0)
	logic.actors.erase(logic.state.actor(XGuyu.ACTOR))  # 同参照 _battleMembers 只留 1 号
	check("status.idle.no_guyu", [XGuyu.status_text(logic.state.actor(1))] == c.observed.noGuyu, XGuyu.status_text(logic.state.actor(1)))
	logic.end_battle(0)


## 选择窗：原版建窗时 2 行（100 高）之后不变；FIT_ROWS 按命令行数
func _window(c: Dictionary) -> void:
	var parent := Control.new()
	add_child(parent)
	for lv in [5, 35]:
		var want: Dictionary = c.observed["lv%d" % lv]
		var logic := _battle(lv, 0)
		var g: XActor = logic.state.actor(XGuyu.ACTOR)
		logic.act(g, XDB.rec("Skills", 10288), g)
		for fit in [false, true]:
			XGuyuTransferWindow.FIT_ROWS = fit
			var w := XGuyuTransferWindow.for_actor(parent, g)
			var op: Dictionary = want.opened
			var rows := int(op.items) if fit else int(want.created.pageRows)
			var h := rows * 36.0 + 28.0
			var name := "window.lv%d.%s" % [lv, "fit" if fit else "original"]
			check(name + ".rect", w.position == Vector2(480, (720.0 - h) / 2.0) and w.size == Vector2(320, h)
				and (fit or w.size.y == float(want.created.height)), [w.position, w.size])
			check(name + ".list", w.entries.map(func(e): return e.text) == op.names and w.entries.map(func(e): return e.enabled) == op.enabled, w.entries)
			check(name + ".cursor", w.index == int(op.index) and w.top == (0 if fit else int(op.top)) and w.rows == rows, [w.index, w.top, w.rows])
			w.queue_free()
		XGuyuTransferWindow.FIT_ROWS = true
		logic.end_battle(0)
	parent.queue_free()


func _motion(c: Dictionary) -> void:
	var logic := _battle(35, 0)
	var g: XActor = logic.state.actor(XGuyu.ACTOR)
	for r in c.observed.rows:
		var perform: Array = r.perform
		var want := str(perform[1]) if perform.size() == 2 and not r.get("internal", false) else ""
		var got := "" if r.get("internal", false) else XGuyu.action_motion(g, XDB.rec("Skills", int(r.skill)))
		check("motion.%d%s" % [int(r.skill), ".internal" if r.get("internal", false) else ""], got == want, [got, want])
	check("motion.bloom_none", XGuyu.action_motion(g, XDB.rec("Skills", XGuyu.BLOOM)) == "")
	check("motion.table", XGuyu.MOTIONS == c.observed.visuals.motions, XGuyu.MOTIONS)
	logic.end_battle(0)


func _relic(c: Dictionary) -> void:
	var s := _state(0, true)
	var g: XActor = s.actor(XGuyu.ACTOR)
	var slot := g.equips.find_custom(func(e): return e is Dictionary and not e.is_empty() and int(e.get("base", e.get("id", 0))) == XGuyu.RELIC)
	if not check("relic.equipped", slot >= 0):
		return
	var aps := RegEx.create_from_string("<pos=APs text=(.*) size=18 color=rgba\\(255,255,255,1\\) line=false align=0>")
	var tags := RegEx.create_from_string("<\\w+ Param \\+\\d+ per Level>")
	var q := RegEx.create_from_string("<(?:quality|ici):\\d+>")
	for lv in [1, 59, 60, 50]:
		g.change_level_mv(lv)
		var e: Dictionary = g.equips[slot]
		XThreeGrowth.sync_item(e)
		var note := str(e.note)
		var got := {"name": e.name, "description": e.description, "aps": aps.search_all(note).map(func(m): return m.get_string(1)),
			"perLevel": tags.search_all(note).map(func(m): return m.get_string()), "quality": q.search_all(note).map(func(m): return m.get_string())}
		var want: Dictionary = c.observed["lv%d" % lv]
		for k in want:
			check("relic.lv%d.%s" % [lv, k], got[k] == want[k], [got[k], want[k]])
	# 说明卡：实例显示改写后的条目（逆序插在 APs 位置）；数据库原件不改
	var rows := XHelpCard.content(g.equips[slot], "armor")
	var texts := rows.map(func(r): return str(r[0]))
	check("relic.help_card_rows", texts.has("万象长春盏") and texts.has("\\c[2]专属：谷雨") and texts.find("\\c[2]专属：谷雨") < texts.find("等级需求：1"), texts)
	g.change_level_mv(60)  # 数据库原件按所属人物现在的等级（原版是同步时把原件也改了，降级后原件仍是进化后的；重制不写回数据库）
	var db := XDB.rec("Armors", XGuyu.RELIC)
	check("relic.database_untouched", str(db.name) == "百谷生" and not str(db.note).contains("专属：谷雨"), db.name)
	var db_rows := XHelpCard.content(db, "armor").map(func(r): return str(r[0]))
	check("relic.database_card_by_owner_level", db_rows.has("万象长春盏") and db_rows.has("\\c[2]专属：谷雨"), db_rows)


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := 0
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		seen += 1
		match str(c.id):
			"short":
				_short(c)
			"status.idle":
				_idle(c)
			"window":
				_window(c)
			"motion":
				_motion(c)
			"relic":
				_relic(c)
			_:
				_script(c)
	check("covers_all", seen == 9, seen)
	await _scene()
	finish()


# ---- 真实战斗画面 ----
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in n:
		if cond.call():
			return true
		await get_tree().physics_frame
	return false


func _scene() -> void:
	XMessageBox.auto = true
	var s := _state(0)
	for id in [XGuyu.ACTOR, 1]:
		s.actor(id).change_level_mv(35)
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var g: XActor = s.actor(XGuyu.ACTOR)
	var hero: XActor = s.actor(1)
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	# 轮到谷雨：别人先防御
	var ok := await _until(func():
		if b.cmd_win == null or not is_instance_valid(b.cmd_win) or not b.cmd_win.active:
			return false
		if b._active == g:
			return true
		b._picked.emit("guard")
		return false, 3000)
	if not check("scene.guyu_command", ok):
		b.queue_free()
		return
	XGuyu.reserves[g.actor_id] = 3000.0
	g.mp = g.mmp
	var sp: XBattlerSprite = b.sprites[g]
	await _frames(4)
	check("scene.planted_wait", sp.motion == "wait" and sp._frame == 0 and b.sprites[hero].motion == "walk", [sp.motion, sp._frame, b.sprites[hero].motion])
	await _frames(20)
	check("scene.planted_still", sp.motion == "wait" and sp._frame == 0, [sp.motion, sp._frame])
	# 站姿归一用谷雨运行时登记的档 Codex_Guyu（160×160，可见 [23,45,137,145]）：缩放 min(72/100, 129/114)＝0.72，不走 inferProfile
	check("scene.guyu_profile", not sp._profile.is_empty() and sp._profile.bounds == Rect2(23, 45, 114, 100) and is_equal_approx(sp.body_scale, 0.72),
		[sp._profile, sp.body_scale])
	b.status_rows[g].refresh()
	await _shot("guyu_ui_side")
	check("scene.side_text", b.status_rows[g]._v().guyu_text == "储3000 生长" and b.status_rows[hero]._v().guyu_text == "储0", [b.status_rows[g]._v().guyu_text, b.status_rows[hero]._v().guyu_text])
	# 技能（类型 2）→ 借一枝春色
	b._picked.emit("stype:2")
	await _frames(3)
	var idx := -1
	if b.list_win != null:
		idx = b.list_win.entries.find_custom(func(e): return str(e.text) == str(XDB.rec("Skills", 10290).name))
	if not check("scene.skill_listed", idx >= 0 and b.list_win.entries[idx].enabled, idx):
		b.queue_free()
		return
	b.list_win.select(idx)
	b.list_win.chosen.emit(idx)
	await _frames(3)
	var w := b.transfer_win
	check("scene.window_open", w != null and b.list_win != null and not b.list_win.active and b.list_win.visible and not b.help_card.visible,
		[w != null, b.list_win != null])
	if w == null:
		b.queue_free()
		return
	check("scene.window_rect", w.position - b._origin == Vector2(480, (720.0 - 244.0) / 2.0) and w.size == Vector2(320, 244) and w.index == 2, [w.position, w.size, w.index])
	await _shot("guyu_ui_window")
	w.cancelled.emit()
	await _frames(3)
	check("scene.window_cancel", b.transfer_win == null and b.list_win != null and b.list_win.active and b.help_card.visible, b.transfer_win != null)
	XGuyuTransferWindow.FIT_ROWS = false
	b.list_win.chosen.emit(idx)
	await _frames(3)
	w = b.transfer_win
	check("scene.window_original_rows", w != null and w.size == Vector2(320, 100) and w.top == 1 and w.index == 2, null if w == null else [w.size, w.top])
	await _shot("guyu_ui_window_2rows")
	XGuyuTransferWindow.FIT_ROWS = true
	var back25 := w.entries.find_custom(func(e): return e.mode == "back" and e.ratio == 0.25) if w != null else -1
	# 还春要 1 号有储备：先给 1 号一些
	XGuyu.reserves[hero.actor_id] = 800.0
	w.entries = XGuyu.transfer_commands(g)
	w.select(back25)
	w.chosen.emit(back25)
	await _frames(3)
	check("scene.target_mode", b._target_mode == "ally" and XGuyu.transfer_mode == "back" and XGuyu.transfer_ratio == 0.25, [b._target_mode, XGuyu.transfer_mode])
	var first = b._hover
	check("scene.help_text", first is XActor and b.help_card.visible and b.help_card.rows[0][0] == XGuyu.transfer_text(g, first, "back", 0.25), b.help_card.rows)
	b._select_target(hero)
	var hs: XBattlerSprite = b.sprites[hero]
	var card_x := b.help_card.position.x - b._origin.x
	check("scene.help_near_left", card_x + b.help_card.size.x <= hs.position.x and b.help_card.rows[0][0] == "还春 25%：狗逍遥 → 谷雨，储备 200。\n转移不回复HP。",
		[card_x, b.help_card.size.x, hs.position.x, b.help_card.rows[0][0]])
	await _shot("guyu_ui_help")
	# 原版：每次换目标都在上一张卡的位置上再修正一次
	XBattleScene.TRANSFER_HELP_NEAR = false
	var before := b.help_card.position - b._origin
	b._select_target(g)
	var after := b.help_card.position - b._origin
	var exp := before
	exp.x += 52 if exp.x < 900 else -10
	if exp.y < 220:
		exp.y += 32
	if exp.y > 400:
		exp.y -= 100
	if exp.y > 500:
		exp.y -= 250
	if exp.x + b.help_card.size.x > 1280:
		exp.x = 1280 - b.help_card.size.x - 30
	if exp.y + b.help_card.size.y > 720:
		exp.y = 720 - b.help_card.size.y - 30
	check("scene.help_original_drift", after == exp and b.help_card.rows[0][0] == "请选择存活的出战队友", [before, after, exp])
	XBattleScene.TRANSFER_HELP_NEAR = true
	# 选自己：不合法，蜂鸣、留在选目标
	b._picked.emit(g)
	await _frames(3)
	check("scene.self_rejected", b._target_mode == "ally", b._target_mode)
	var amount := float(XGuyu.transfer_preview(g, hero, "back", 0.25).amount)
	var e0 := XGuyu.reserve(g)
	b._picked.emit(hero)
	ok = await _until(func(): return XGuyu.reserve(g) != e0, 600)
	check("scene.transfer_done", ok and is_equal_approx(XGuyu.reserve(g), e0 + amount) and is_equal_approx(XGuyu.reserve(hero), 800.0 - amount),
		[XGuyu.reserve(g), e0, amount, XGuyu.reserve(hero)])
	check("scene.reset_after", XGuyu.transfer_mode == "give" and XGuyu.transfer_ratio == 0.5, [XGuyu.transfer_mode, XGuyu.transfer_ratio])
	# 归根反馈：48 帧后收起
	sp.guyu_visual("root")
	await _frames(2)
	check("scene.root_fx_on", sp._fx != null and sp._fx.visible and sp._fx_kind == "root")
	await _frames(50)
	check("scene.root_fx_off", sp._fx != null and not sp._fx.visible and sp._fx_kind == "")
	b.logic.auto = true
	b.queue_free()
	await _frames(2)
	XMessageBox.auto = false


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_guyu_ui", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
