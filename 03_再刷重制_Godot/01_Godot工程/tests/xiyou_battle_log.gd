extends Node
## 专属角色战斗画面遗留（悟空 battlelog1）：逻辑层早已出的记录接到战斗画面 XBattleScene。
## - 宿傩：battle_text 记录（S.log → _logWindow.push('addText')）在技能名那行之后再加一行；神灶（10232）选目标只列蓄力敌人
##   （Window_BattleEnemy.refresh 包装）。
## - 渡鸦：命中记录上的 raven_fx（神话封解 ring、伤害技能每次 apply 的 slash）与收割／回响的 regen（directDamage 的弹字、
##   performDamage 闪烁，R.Fx harvest／echo）放进 XRavenFx；特效每帧透明度 ×0.88、缩放 +0.025，16／28 帧后隐藏。
## - 饿狼：G.trigger 追击／反击的命中记录带 garou_trigger，画面在日志里再加一行技能名（displayAction）；原生反击不加。
## 用真战斗画面（敌群 2、地图 5），队伍宿傩、渡鸦、饿狼；记录多为手搓，文字取各模块自己的函数。
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	var s := XState.new_game_blank()
	s.party.clear()
	s.battle_slots.clear()
	for id in [XSukuna.ACTOR, XRaven.ACTOR, XGarou.ACTOR]:
		s.add_actor(id)
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	var sukuna := s.actor(XSukuna.ACTOR)
	var raven := s.actor(XRaven.ACTOR)
	var garou := s.actor(XGarou.ACTOR)
	var foes: Array = b.logic.alive(b.logic.enemies)
	check("setup", b.logic.actors.size() == 3 and foes.size() >= 2, [b.logic.actors.size(), foes.size()])
	await sukuna_case(b, sukuna, foes)
	await raven_case(b, raven, foes)
	await garou_case(b, garou, foes)
	b.queue_free()
	await frames(3)
	finish()


func hit(u, t, skill: Dictionary, extra := {}) -> Dictionary:
	var r := {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
		"hp": 0.0, "mp": 0.0, "died": false, "added": [], "removed": []}
	r.merge(extra, true)
	return r


## 跑 _play，逐帧看日志行，返回最后一次不空的日志（_play 结束时清日志）
func play_and_peek(b: XBattleScene, logs: Array) -> Array:
	var seen := []
	var done := [false]
	var run := func():
		await b._play(logs)
		done[0] = true
	run.call()
	for i in 900:
		var now: Array = b._log_lines.map(func(l): return [str(l.text), bool(l.simple)])
		if not now.is_empty():
			seen = now
		if done[0]:
			break
		await frames(1)
	check("play-finished", done[0])
	return seen


func sukuna_case(b: XBattleScene, a: XActor, foes: Array) -> void:
	var skill := XDB.rec("Skills", 10232)
	var text: Dictionary = XSukuna._text(a.display_name() + "发动了神灶：开！")
	check("sukuna.record", text.type == "battle_text")
	var lines := await play_and_peek(b, [{"type": "action", "user": a, "skill": skill, "views": b.logic.views()}, text])
	var name := "\\i[%d]%s" % [int(skill.iconIndex), str(skill.name)]
	check("sukuna.log-lines", lines == [[name, true], [str(text.text), false]], lines)
	check("sukuna.log-cleared", b._log_lines.is_empty())
	# 回合末那种不跟行动的：只有这一行
	lines = await play_and_peek(b, [text, hit(a, foes[0], XDB.rec("Skills", 10237))])
	check("sukuna.round-text", lines == [[str(text.text), false]], lines)
	# 日志最多 10 行
	for i in 12:
		b._log_add(str(i))
	check("log.max-lines", b._log_lines.size() == 10 and b._log_lines[0].text == "2")
	b._banner("")
	# 神灶：只列蓄力敌人；别的技能、别的角色照旧
	for t in foes:
		XSukuna.target_data(t).charged = false
	XSukuna.target_data(foes[1]).charged = true
	check("sukuna.filter", XSukuna.selectable_enemies(a, skill, foes) == [foes[1]])
	check("sukuna.filter-other-skill", XSukuna.selectable_enemies(a, XDB.rec("Skills", 10229), foes) == foes)
	check("sukuna.filter-other-actor", XSukuna.selectable_enemies(b.logic.actors[1], skill, foes) == foes)
	var seen := []
	get_tree().create_timer(0.3).timeout.connect(func():
		seen.append(b._target_pool.duplicate())
		b._picked.emit(null), CONNECT_ONE_SHOT)
	await b._pick_target(skill, a)
	check("sukuna.pick-pool", seen.size() == 1 and seen[0] == [foes[1]], seen)
	await frames(3)
	for t in foes:
		XSukuna.target_data(t).charged = false


func raven_case(b: XBattleScene, a: XActor, foes: Array) -> void:
	# 逻辑层：伤害技能每次 apply 记 slash（不看命中）；别人不记
	var r := hit(a, foes[0], XDB.rec("Skills", XRaven.PECK), {"missed": true})
	XRaven.applied(b.logic, a, XDB.rec("Skills", XRaven.PECK), foes[0], r, true)
	check("raven.slash-record", r.get("raven_fx", []) == ["slash"], r.get("raven_fx"))
	var other := hit(b.logic.actors[0], foes[0], XDB.rec("Skills", XRaven.PECK))
	XRaven.applied(b.logic, b.logic.actors[0], XDB.rec("Skills", XRaven.PECK), foes[0], other, true)
	check("raven.other-no-fx", not other.has("raven_fx"))
	# 画面：命中记录上的特效、收割／回响 regen
	b._hit_visual(hit(a, foes[0], XDB.rec("Skills", XRaven.MYTH), {"raven_fx": ["ring", "slash"]}))
	check("raven.fx-layer", b.raven_fx != null and b.raven_fx.get_parent() == b.field)
	var t: XBattler = foes[1]
	await play_and_peek(b, [{"type": "regen", "target": t, "hp": 5.0, "raven": "harvest", "views": b.logic.views([t])},
		{"type": "regen", "target": t, "hp": 3.0, "raven": "echo", "views": b.logic.views([t])}])
	await frames(30)
	var played: Array = b.raven_fx.played.map(func(p): return p.type)
	check("raven.played", played == ["ring", "slash", "harvest", "echo"], played)
	check("raven.targets", b.raven_fx.played[2].target == t and b.raven_fx.played[0].target == foes[0])
	# 4 个图形轮流用：四种都在放；位置在目标脚下往上 48；28／16 帧后隐藏
	var shapes: Array = b.raven_fx.pool
	check("raven.pool", shapes.size() == 4 and shapes.all(func(g): return not g.visible), shapes.map(func(g): return [g.kind, g.visible, g.frames]))
	b.raven_fx.play("ring", b.sprites[t].position, t)
	b.raven_fx.play("echo", b.sprites[t].position, t)
	var ring = shapes.filter(func(g): return g.kind == "ring" and g.visible)
	check("raven.ring-start", ring.size() == 1 and ring[0].frames == 28 and ring[0].position == b.sprites[t].position - Vector2(0, 48))
	await frames(1)
	var echo = shapes.filter(func(g): return g.kind == "echo" and g.visible)
	check("raven.echo-fades", echo.size() == 1 and echo[0].frames == 15 and is_equal_approx(echo[0].modulate.a, 0.88) and is_equal_approx(echo[0].scale.x, 1.025),
		[echo.map(func(g): return [g.frames, g.modulate.a, g.scale.x])])
	await frames(16)
	check("raven.echo-hidden", shapes.filter(func(g): return g.kind == "echo" and g.visible).is_empty())
	check("raven.ring-still", shapes.filter(func(g): return g.kind == "ring" and g.visible).size() == 1)
	await frames(12)
	check("raven.all-hidden", shapes.all(func(g): return not g.visible))


func garou_case(b: XBattleScene, a: XActor, foes: Array) -> void:
	var logs: Array = XGarou.trigger(b.logic, a, foes[0], XGarou.WATER, "counter")
	var r: Dictionary = logs[0] if not logs.is_empty() else {}
	check("garou.record", r.get("garou_trigger") == "counter" and r.get("counter") == true, r.keys())
	var main := XDB.rec("Skills", 1)
	var skill := XDB.rec("Skills", XGarou.WATER)
	var follow := hit(a, foes[0], XDB.rec("Skills", XGarou.TRIGGERED), {"followup": true, "garou_trigger": "followup"})
	var lines := await play_and_peek(b, [{"type": "action", "user": a, "skill": main, "views": b.logic.views()}, hit(a, foes[0], main), follow])
	var trig := XDB.rec("Skills", XGarou.TRIGGERED)
	check("garou.followup-line", lines.size() == 2 and lines[1] == ["\\i[%d]%s" % [int(trig.iconIndex), str(trig.name)], true], lines)
	# 原生反击（命中记录也有 counter）不加行，照旧是「%1的反击！」那行
	var native := hit(foes[0], a, main, {"counter": true})
	lines = await play_and_peek(b, [{"type": "counter", "user": foes[0], "target": a}, native])
	check("garou.native-counter", lines.size() == 1 and not lines[0][1], lines)
	check("garou.skill", int(skill.id) == XGarou.WATER)


func finish() -> void:
	XMessageBox.auto = false
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
