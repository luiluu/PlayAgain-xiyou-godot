extends Node
## 【cc·悟空·未经审查】渡鸦施放特效屏蔽支（installRavenSkillEffectsRuntime 84～86、108～115 行，v0.62.12 与 v0.28 同文）
## 与 mv_oracle/raven_fx_probe.cjs 的参照（tests/fixtures/raven_fx_oracle.json）逐例比：
## - 10122～10127 由渡鸦放：一次行动一组施放特效（目标数同参照），R.Fx 的 slash／ring 不画；神话＋狩猎时收割／回响照画（个数、次序同参照）；
## - 每组放够 life 帧才结束（isAnimationPlaying 算没放完）；两次行动的特效可以同时在，最多 6 组；
## - 别的角色放同一技能：不换施放特效（参照 V.play 返回 false）。
## 真战斗画面（敌群 3、地图 5），走 logic.act → _play，数 XRavenFx.played。
const FIXTURE := "res://tests/fixtures/raven_fx_oracle.json"
var results: Array = []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	XMessageBox.auto = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if check("oracle", d is Dictionary and d.cases.size() == 14 and d.cases.all(func(c): return c.errors.is_empty()), FIXTURE):
		var cases := {}
		for c in d.cases:
			cases[str(c.id)] = c.observed
		await _cases(cases)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _cases(want: Dictionary) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XRaven.ACTOR] = 5
	var a := s.actor(XRaven.ACTOR)
	a.change_level_mv(99)
	check("setup.recruit", XRaven.recruit(s))
	for id in [10122, 10123, 10124, 10125, 10126, 10127, 10133, 10170]:
		a.learn_skill(id)
	s.add_actor(1)
	for id in s.party:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var b := XBattleScene.new()
	b.setup(3, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	for e in b.logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	var foes: Array = b.logic.alive(b.logic.enemies)
	check("setup.foes", foes.size() == 3, foes.size())
	var fx := b._raven_layer()
	for id in [10122, 10123, 10124, 10125, 10126, 10127]:
		for mode in ["normal", "myth"]:
			var key := "cast.%d.%s" % [id, mode]
			var w: Dictionary = want.get(key, {})
			var st: Dictionary = s.raven
			st["myth"] = 3 if mode == "myth" else 0
			st["hunter"] = mode == "myth"
			st["residue"] = 0
			a.mp = a.mmp
			fx.played.clear()
			await b._play(b.logic.act(a, XDB.rec("Skills", id), foes[0]))
			var got: Array = fx.played.map(func(p): return ["cast", int(p.skill), int(p.spots)] if p.type == "cast" else [str(p.type)])
			var exp: Array = []
			for l in w.get("log", []):
				if l.kind == "cast":
					if l.played:
						exp.append(["cast", int(l.skill), int(l.targets)])
				elif l.drawn:
					exp.append([str(l.type)])
			check(key + ".fx", got == exp, [got, exp])
			check(key + ".myth", XRaven.myth_turns(a) == int(w.get("myth", -1)), [XRaven.myth_turns(a), w.get("myth")])
			check(key + ".ended", not fx.busy())
			# 一组放够 life 帧（参照逐帧 update 到结束的次数）
			fx.play_cast(id, [Vector2(200, 200)], Vector2(600, 200))
			var n := 0
			while fx.busy() and n < 500:
				await frames()
				n += 1
			check(key + ".frames", n == int(w.get("frames", -1)), [n, w.get("frames")])
	# 放完前再放一次：两组都在；连放到 8 组封顶 6
	fx.play_cast(10122, [Vector2(200, 200)], Vector2(600, 200))
	fx.play_cast(10122, [Vector2(200, 200)], Vector2(600, 200))
	check("twice.two", fx.casts.size() == int(want.twice.two), [fx.casts.size(), want.twice])
	for i in 6:
		fx.play_cast(10123, [Vector2(200, 200)], Vector2(600, 200))
	check("twice.capped", fx.casts.size() == int(want.twice.capped), [fx.casts.size(), want.twice])
	while fx.busy():
		await frames()
	# 别的角色放同一技能：参照 V.play 返回 false、没有特效组
	var other := s.actor(1)
	other.learn_skill(10122)
	other.mp = other.mmp
	fx.played.clear()
	await b._play(b.logic.act(other, XDB.rec("Skills", 10122), foes[0]))
	var cast_ok: bool = want.other.log.any(func(l): return l.kind == "cast" and l.played)
	check("other.no-cast", fx.played.filter(func(p): return p.type == "cast").is_empty() == not cast_ok and int(want.other.groups) == 0, fx.played)
