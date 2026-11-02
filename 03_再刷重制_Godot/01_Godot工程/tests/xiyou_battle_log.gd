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
	s.actor_max_level = 99
	s.switches[2494] = true  # 超强角色可出战
	s.party.clear()
	s.battle_slots.clear()
	for id in [XSukuna.ACTOR, XRaven.ACTOR, XGarou.ACTOR]:
		s.actor(id).change_level_mv(55)
		s.add_actor(id)
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
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
	toji_anim_case(b, raven, foes)
	await indicator_case(b, sukuna, raven)
	await garou_case(b, garou, foes)
	skill_types(b, [sukuna, raven, garou])
	ledger(raven)
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


## 角色形象（CharacterVisual）甚尔命中动画：命中记录的 toji_anims 在目标身上放动画，延迟记在 wait（Sprite_Animation._delay）
func toji_anim_case(b: XBattleScene, a: XActor, foes: Array) -> void:
	var keep := XConfig.flag("CombatSkillAnimation")
	XConfig.set_flag("CombatSkillAnimation", true)
	var before := b.fx.get_children()
	b._hit_visual(hit(a, foes[0], XDB.rec("Skills", 10216), {"toji_anims": [[1, 6], [12, 0]]}))
	var added: Array = b.fx.get_children().filter(func(n): return n is MVAnimation and not before.has(n))
	check("toji.anims", added.size() == 2 and added.map(func(n): return [int(n.anim.id), n.wait]) == [[1, 6], [12, 0]]
		and added.all(func(n): return n.target == b.sprites[foes[0]]), added.map(func(n): return [n.anim.get("id"), n.wait]))
	before = b.fx.get_children()
	b._hit_visual(hit(a, foes[0], XDB.rec("Skills", 10216)))
	check("toji.no-anims", not b.fx.get_children().any(func(n): return n is MVAnimation and not before.has(n)))
	XConfig.set_flag("CombatSkillAnimation", keep)
	for n in b.fx.get_children():
		if n is MVAnimation:
			n.queue_free()


## 角色形象 CodexBattleIndicators：宿傩领域法阵（影子之下、可见脚底、呼吸与转动）、黑闪觉醒描边（身体之下 16 个剪影、跟身体同帧）；
## 回放时按命中记录的读数；阵亡、别的角色不显示
func indicator_case(b: XBattleScene, a: XActor, other: XActor) -> void:
	var sp: XBattlerSprite = b.sprites[a]
	check("indicator.none", sp._domain_circle == null and sp._outline == null)
	XSukuna.temp(a).domain = 2
	b.logic._state_add(a, XSukuna.DOMAIN)
	await frames(3)
	var c := sp._domain_circle
	check("indicator.domain", c != null and c.visible and c.get_index() == 0 and c.position == sp.sprite.position and is_equal_approx(c.scale.y, 0.34),
		[c != null, c.get_index() if c else -1])
	if c != null:
		var t0 := c.tick
		var r0 := c.drawing.rotation
		await frames(10)
		check("indicator.domain-anim", c.tick == t0 + 10 and is_equal_approx(c.drawing.rotation, r0 + 0.03)
			and is_equal_approx(c.modulate.a, 0.82 + cos(c.tick * 0.04) * 0.08), [c.tick, t0, c.drawing.rotation, c.modulate.a])
		b.show_views({a: b.logic.view_of(a).merged({"domain": false}, true)})
		await frames(1)
		check("indicator.domain-view", not c.visible)
		b.clear_views()
		await frames(1)
		check("indicator.domain-live", c.visible)
	check("indicator.other-actor", b.sprites[other]._domain_circle == null)
	# 黑闪觉醒：学 10225 与觉醒技 10242、觉醒状态 2639、未到期
	a.learn_skill(XBlackFlash.SKILL)
	a.learn_skill(10242)
	b.logic._state_add(a, 2639)
	XBlackFlash.temp(a).expires = XBlackFlash.round + 3
	await frames(2)
	var o := sp._outline
	var body := sp.sprite as Sprite2D
	check("indicator.outline", o != null and o.visible and o.get_child_count() == 16 and o.get_index() == body.get_index() - 1, [o != null])
	if o != null:
		var c0: Sprite2D = o.get_child(0)
		var c9: Sprite2D = o.get_child(9)
		check("indicator.outline-sync", c0.texture == body.texture and c0.region_rect == body.region_rect and c0.offset == body.offset
			and c0.scale == body.scale and c0.position.is_equal_approx(body.position + Vector2(3.5, 0))
			and c9.position.is_equal_approx(body.position + Vector2.from_angle(PI / 4.0) * 2.0)
			and c0.material.get_shader_parameter("fill") == XBattleIndicators.OUTLINE_COLORS[0]
			and c9.material.get_shader_parameter("fill") == XBattleIndicators.OUTLINE_COLORS[1], [c0.position, c9.position, body.position])
	XBlackFlash.temp(a).expires = XBlackFlash.round - 1
	await frames(1)
	check("indicator.outline-expired", o == null or not o.visible)
	XBlackFlash.temp(a).expires = XBlackFlash.round + 3
	b.logic._state_add(a, XBattleLogic.DEATH_STATE)
	await frames(1)
	check("indicator.dead", (c == null or not c.visible) and (o == null or not o.visible))
	b.logic._state_remove(a, XBattleLogic.DEATH_STATE)
	a.hp = a.mhp
	b.logic._state_remove(a, XSukuna.DOMAIN)
	b.logic._state_remove(a, 2639)
	XSukuna.temp(a).domain = 0
	await frames(1)


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


## 技能分类（battlelog2）：指令窗照 addSkillCommands 包装固定几栏、照次序；菜单照 addedSkillTypes 包装、升序；别的角色照特性
func skill_types(b: XBattleScene, who: Array) -> void:
	var stypes: Array = XDB.system().skillTypes
	var want := {XSukuna.ACTOR: [2, 1, 5, 3], XRaven.ACTOR: [2, 1, 5], XGarou.ACTOR: [2, 1, 5]}
	for a in who:
		var keys: Array = b._command_entries(a).map(func(o): return str(o.key)).filter(func(k): return k.begins_with("stype:"))
		var texts: Array = b._command_entries(a).filter(func(o): return str(o.key).begins_with("stype:")).map(func(o): return o.text)
		check("types.battle.%d" % a.actor_id, keys == want[a.actor_id].map(func(t): return "stype:%d" % t)
			and texts == want[a.actor_id].map(func(t): return str(stypes[t])), [keys, texts])
	check("types.menu", XActorModules.menu_skill_types(who[0]) == [2, 1, 5, 3, 4] and XActorModules.menu_skill_types(who[2]) == [2, 1, 5, 4]
		and XActorModules.menu_skill_types(XState.current.actor(1)) == null and XActorModules.battle_skill_types(XState.current.actor(1)) == null)
	var page := XSkillScene.new()
	add_child(page)
	page.actor_index = XState.current.party.find(XGarou.ACTOR)
	check("types.menu-sorted", page.types() == [1, 2, 4, 5], page.types())
	page.queue_free()


## 渡鸦魂簿（10137）的说明卡：当前存档的灵魂、进阶、进阶印与下一阶门槛（千分位）
func ledger(a: XActor) -> void:
	var s := XState.current
	s.raven["soul"] = 12345.0
	var lines := XRaven.ledger_help(a, XDB.rec("Skills", XRaven.SOUL_LEDGER))
	var st := XRaven.stage(a)
	var next: String = ["", "3,000", "12,000", "35,000", "80,000", "150,000"][mini(5, st + 1)]
	check("ledger.text", lines == ["灵魂：12,345　进阶：%d/5　进阶印：%d" % [st, s.item_count(XRaven.SEAL)], "本阶达" + next + "魂得印；进阶后清零"], lines)
	check("ledger.other-skill", XRaven.ledger_help(a, XDB.rec("Skills", XRaven.PECK)).is_empty())
	check("ledger.other-actor", XRaven.ledger_help(s.actor(XSukuna.ACTOR), XDB.rec("Skills", XRaven.SOUL_LEDGER)).is_empty())


func finish() -> void:
	XMessageBox.auto = false
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
