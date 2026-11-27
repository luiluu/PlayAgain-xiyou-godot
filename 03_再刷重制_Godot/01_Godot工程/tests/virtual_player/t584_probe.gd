extends Node
## 临时探针：角色 162 诛仙 加 2720 前后 hp／mhp
func _ready() -> void:
	_run.call_deferred()

func _p(tag: String, a: XBattler) -> void:
	print("T584|%s hp=%s mhp=%s states=%s dirty=%s cells=%s" % [tag, a.hp, a.mhp, a.state_ids, a.param_dirty, a.param_cells])

func _run() -> void:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(1, 8, [])
	s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)
	s.add_actor(162)
	s.random_master = XRandomStream.hex64(584)
	var a0: XActor = s.actor(162)
	print("T584|party=", s.party, " members=", s.members().map(func(m): return m.actor_id))
	a0.change_level(25)
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var a: XBattler = logic.actors.filter(func(x): return x.actor_id == 162)[0]
	print("T584|actor id=", a.actor_id)
	a.hp = a.mhp
	_p("start", a)
	a.hp = a.mhp * 0.025
	a.add_state(2720)
	_p("after_add_2720", a)
	a.refresh_resources()
	_p("after_refresh", a)
	# 走真技能
	var b: XBattler = a
	b.remove_state(2720)
	_p("after_remove", b)
	b.remove_state(1)
	b.hp = b.mhp
	b.tp = 1000
	var logs := logic.execute(b, XDB.rec("Skills", 10458), logic.enemies[0], true)
	_p("after_10458", b)
	for l in logs:
		if str(l.get("type","")) in ["damage","hp","cost","state"]:
			pass
	pass
	_p("after_end_turn", b)
	get_tree().quit(0)
