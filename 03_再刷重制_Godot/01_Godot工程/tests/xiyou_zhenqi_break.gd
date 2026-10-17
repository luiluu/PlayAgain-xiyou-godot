extends Node
## 真气第二批（XZhenqi 闭关菜单、瓶颈之战、突破、突破奖励与道法、灵根降服、奖励技能数值）：与 mv_oracle/zhenqi_probe.cjs
## 「break.*」「trial.ref.table」「reward.*」「menu.command」逐例比（generated/oracle/zhenqi.json）。
## 原版闭关是插入的 101/401/102/301 指令列，这里比 XZhenqi.menu 给出的文字、选项、开战敌群与选项走向。
## 另测：输了／逃了算未能突破（end_battle）、spec 随存档、XZhenqiRetreat 流程（固定应答宿主）。

const ORACLE := "res://modes/xiyou/generated/oracle/zhenqi.json"
const Base := preload("res://tests/xiyou_zhenqi.gd")
var results := []
var cur := {}
var s: XState


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


var _cmp = Base.new()


func _same(a, b) -> bool:
	return _cmp._same(a, b)


func _fresh() -> void:
	s = XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.difficulty = 2   # 参照新局的 Vitsuno 难度（敌人能力值倍率）
	XZhenqi.toasts.clear()
	XZhenqi.rand_seq.clear()
	XZhenqi.pending_trial = {}
	XZhenqi.trial_done = {}
	XZhenqi.battle = {}
	cur = {}


func _set_zq(a: XActor, d: Dictionary) -> void:
	var z := XZhenqi.default_data()
	for k in d:
		z[k] = d[k]
	a.zhenqi = XZhenqi.from_save(z)
	XZhenqi.refresh_rewards(a)


func _setup(o: Dictionary) -> void:
	if o.has("route"):
		s.set_switch(int(o.route), true)
	if o.has("progress"):
		s.set_variable(20, int(o.progress) + 1)
	for id in o.get("extra", []):
		s.add_actor(int(id))
	for id in o.get("data", {}):
		_set_zq(s.actor(int(id)), o.data[id])


func _view(m: Dictionary):
	if m.is_empty():
		return null
	var opts: Array = m.get("options", [])
	return {"lines": m.lines, "choices": opts.map(func(o): return o.label) if not opts.is_empty() else null,
		"cancel": opts.size() - 1 if not opts.is_empty() else null, "battle": [0, int(m.battle), false, true] if m.has("battle") else null,
		"then": not opts.is_empty() or m.get("next") != null or m.has("battle")}


func _go(node: Dictionary):
	cur = XZhenqi.menu(s, node)
	return _view(cur)


## 原版 Z._cb(k)：选项回调为空（离开、稍后再选）时指令列不变
func _pick(k: int):
	var opts: Array = cur.get("options", [])
	var nxt = opts[k].next if not opts.is_empty() else cur.get("next")
	if nxt == null:
		return _view(cur)
	return _go(nxt)


func _zq(a: XActor) -> Dictionary:
	var d := XZhenqi.data(a)
	var df: Array = d.daofa.keys()
	df.sort()
	return {"qi": int(d.qi), "realm": int(d.realm), "pending": d.pending.duplicate(), "daofa": df, "stages": d.get("daofaStages", {})}


func _zq_skills(a: XActor) -> Array:
	var out := a.skill_ids.filter(func(id): return str(XDB.rec("Skills", id).get("note", "")).contains("<CodexZhenqi:"))
	out.sort()
	return out


func _spec():
	var sp := s.zhenqi_spec
	if sp.w.is_empty() and sp.e.is_empty():
		return null
	var w: Array = sp.w.keys()
	var e: Array = sp.e.keys()
	w.sort()
	e.sort()
	return {"w": w, "e": e}


func _logic(troop: int) -> XBattleLogic:
	var logic := XBattleLogic.new()
	logic.elite_roll = 50.0     # 参照 Math.random 固定 0.5：神话判定 50 < 50 不成立
	logic.level_roll = 0.5
	logic.setup(troop, s)
	return logic


func _params(e: XEnemy, f: Callable) -> Array:
	return range(8).map(func(i): return f.call(e, i))


func _trial_battle(aid: int, o: Dictionary) -> Dictionary:
	_go({"page": "trial", "id": aid})
	var troop := int(XZhenqi.pending_trial.troopId)
	var logic := _logic(troop)
	var b := XZhenqi.battle
	var en := []
	for e in logic.enemies:
		en.append({"enemyId": e.enemy_id, "base": _params(e, func(x, i): return x.param_base(i) / float(x._rates[i])), "param": _params(e, func(x, i): return x.param(i)),
			"hp": e.hp, "mp": e.mp, "drops": logic.drops_of(e).size()})
	var rw := logic.rewards()
	for id in o.get("dead", []):
		s.actor(int(id)).hp = 0
	XZhenqi.toasts.clear()
	var before := int(XZhenqi.data(s.actor(aid)).qi)
	XZhenqi.on_victory(s, logic.actors, logic.enemies)
	var t := XZhenqi.trial_done
	var done = {"won": t.won, "actorId": t.actorId, "target": t.target} if not t.is_empty() else null
	for id in o.get("dead", []):
		s.actor(int(id)).hp = 1
	var qi_after := int(XZhenqi.data(s.actor(aid)).qi)
	var end = _go({"page": "trial_end"})
	var r := {"troop": troop, "battle": {"trial": not b.trial.is_empty(), "guardianFloor": b.guardianFloor, "floor": b.floor, "comp": b.comp, "route": b.route.key},
		"enemies": en, "rewards": {"exp": rw.exp, "gold": rw.gold, "items": rw.drops.size()}, "done": done, "qiGain": qi_after - before,
		"after": _zq(s.actor(aid)), "skills": _zq_skills(s.actor(aid)), "toasts": XZhenqi.toasts.duplicate(), "end": end,
		"cleared": XZhenqi.pending_trial.is_empty() and XZhenqi.trial_done.is_empty()}
	r.next = _pick(0)
	return r


func _case(id: String, o: Dictionary):
	_fresh()
	_setup(o)
	var a: XActor = s.actor(1)
	if id.begins_with("break.actor.") and id != "break.actor.nav":
		return _go({"page": "actor", "id": 1})
	if id.begins_with("break.trial."):
		var aid: int = {"notReady": 1, "locked": 1, "heart1": 1, "heart8": 8, "heart.f0": 8, "heart.f21": 9, "tianjie": 9, "xian": 10, "reserve": 6}[id.substr(12)]
		var v = _go({"page": "trial", "id": aid})
		var t := XZhenqi.pending_trial
		return {"view": v, "pending": {"actorId": t.actorId, "target": t.target, "kind": t.kind, "troopId": t.troopId, "ref": t.ref} if not t.is_empty() else null}
	if id.begins_with("break.fight.") and not id in ["break.fight.otherTroop", "break.fight.lost"]:
		var aid: int = {"heart1": 1, "heart8": 8, "jindan": 9, "dead": 8, "otherDead": 8, "tianjie": 9, "hard": 10, "xian": 10}[id.substr(12)]
		return _trial_battle(aid, o)
	if id.begins_with("break.direct."):
		XZhenqi.toasts.clear()
		var ok := XZhenqi.breakthrough(s, a)
		return {"ok": ok, "after": _zq(a), "skills": _zq_skills(a), "toasts": XZhenqi.toasts.duplicate(), "mhp": a.mhp, "cri": snappedf(a.cri, 0.000001)}
	if id.begins_with("break.pick.") and not id in ["break.pick.later", "break.pick.none", "break.pick.allDaofa"]:
		var first = _go({"page": "pick", "id": 1})
		var realm := int(a.zhenqi.realm)
		var steps := []
		for n in range(a.zhenqi.pending.size()):
			var v = _pick(0 if n % 2 == 0 else (0 if realm >= 5 else 2))
			steps.append({"view": v, "after": _zq(a), "skills": _zq_skills(a)})
		return {"first": first, "steps": steps}
	if id.begins_with("break.daofa.k"):
		XZhenqi.rand_seq = [int(id.substr(13)), 4]
		_go({"page": "pick", "id": 1})
		var got = _pick(cur.options.size() - 2)
		var r := {"got": got, "after": _zq(a), "skills": _zq_skills(a)}
		if got.then:
			r.next = _pick(0)
		r.afterNext = _zq(a)
		return r
	if id.begins_with("break.spec."):
		var linggen := id.contains("linggen")
		var known: Dictionary = o.known
		for part in ["w", "e"]:
			for k in known.get(part, {}):
				s.zhenqi_spec[part][str(k)] = 1
		XZhenqi.rand_seq = [4 if linggen else 3, 6]
		_go({"page": "pick", "id": 1})
		var ask = _pick(3)
		var got = _pick(int(id.right(1)))
		return {"ask": ask, "got": got, "after": _zq(a), "skills": _zq_skills(a)}
	if id.begins_with("break.stats."):
		var keys := {"atk1": "attr:atk:1", "def2": "attr:def:2", "sup3": "attr:sup:3", "all5": "attr:all:5", "jindan": "fixed:jindan", "dujie": "fixed:dujie"}
		var base := _params_actor(a)
		var cri0 := snappedf(a.cri, 0.000001)
		a.learn_skill(XZhenqi.skill_key(keys[id.substr(12)]))
		XZhenqi.refresh_rewards(a)
		return {"base": base, "after": _params_actor(a), "cri0": cri0, "cri": snappedf(a.cri, 0.000001)}
	match id:
		"break.retreat.default", "break.retreat.tags":
			return _go({"page": "retreat"})
		"break.retreat.pages":
			var p0 = _go({"page": "retreat"})
			var p1 = _pick(4)
			var p2 = _pick(4)
			return {"p0": p0, "p1": p1, "p2": p2, "back": _pick(4)}
		"break.retreat.page.clamp":
			return _go({"page": "retreat", "p": 9})
		"break.actor.nav":
			_go({"page": "retreat"})
			var page = _pick(0)
			var back = _pick(1)
			_pick(0)
			return {"page": page, "back": back, "leaveIsNull": cur.options[2].next == null}
		"trial.ref.table":
			var out := []
			for f in range(35):
				s.set_variable(20, f + 1)
				out.append(XZhenqi.trial_ref(s, 1))
			return out
		"break.fight.otherTroop":
			_go({"page": "trial", "id": 1})
			var logic := _logic(1)
			return {"trial": not XZhenqi.battle.trial.is_empty(), "pendingCleared": XZhenqi.pending_trial.is_empty(), "params": logic.enemies.map(func(e): return e.param_base(0))}
		"break.fight.lost":
			_go({"page": "trial", "id": 8})
			var logic := _logic(int(XZhenqi.pending_trial.troopId))
			logic.end_battle()
			var end = _go({"page": "trial_end"})
			var after := _zq(s.actor(8))
			return {"end": end, "after": after, "next": _pick(0)}
		"break.pick.later":
			var v = _go({"page": "pick", "id": 1})
			return {"view": v, "laterIsNull": cur.options[cur.options.size() - 1].next == null}
		"break.pick.none", "break.pick.allDaofa":
			return _go({"page": "pick", "id": 1})
		"break.daofa.skipTaken":
			XZhenqi.rand_seq = [0]
			_go({"page": "pick", "id": 1})
			var got = _pick(3)
			return {"got": got, "after": _zq(a), "skills": _zq_skills(a)}
		"break.unlock.element":
			var ids := []
			for t in XDB.table("Troops"):
				if ids.size() >= 3 or not t is Dictionary or t.get("members", []).is_empty():
					continue
				for m in t.members:
					var e := XEnemy.new()
					e.enemy_id = int(m.enemyId)
					if XZhenqi.is_boss_enemy(e) and str(e.data().get("note", "")).containsn("<Element Absorb:"):
						ids.append(int(t.id))
						break
			var out := []
			for t in ids + [ids[0]]:
				var logic := _logic(t)
				XZhenqi.toasts.clear()
				XZhenqi.on_victory(s, logic.actors, logic.enemies)
				out.append({"troop": t, "spec": _spec(), "toasts": XZhenqi.toasts.duplicate()})
			return out
		"break.unlock.trialNoSpec":
			_go({"page": "trial", "id": 9})
			var logic := _logic(int(XZhenqi.pending_trial.troopId))
			XZhenqi.on_victory(s, logic.actors, logic.enemies)
			return _spec()
		"reward.skills":
			var out := []
			for sk in XDB.table("Skills"):
				if not sk is Dictionary or not str(sk.get("note", "")).contains("<CodexZhenqi:"):
					continue
				var tag := RegEx.create_from_string("<CodexZhenqi:\\s*([^>]+)>").search(sk.note).get_string(1).strip_edges()
				var row := {"id": int(sk.id), "tag": tag, "name": sk.name, "views": []}
				for realm in [0, 1, 2, 3, 4, 5, 9]:
					_set_zq(a, {"realm": realm})
					var v := XZhenqi.skill_view(sk, a)
					var meta := {}
					for k in v.get("meta", {}):
						if str(k).begins_with("passive"):
							meta[k] = v.meta[k]
					row.views.append({"realm": realm, "scale": snappedf(XZhenqi.daofa_scale(a), 0.000001), "note": v.note, "meta": meta})
				out.append(row)
			return out
		"reward.keys":
			var out := {}
			for k in ["fixed:jindan", "fixed:yuanying", "fixed:xianyuan:9", "fixed:xianyuan:13", "attr:atk:1", "attr:all:13", "daofa:lianji", "daofa:benming:12", "daofa:linggen:9", "nope"]:
				var v := XZhenqi.skill_key(k)
				out[k] = v if v else null
			return out
		"menu.command":
			var c: Array = XMenu.COMMANDS.filter(func(x): return x[1] == "zhenqi")
			return [{"name": c[0][0], "symbol": "codexZhenqi", "enabled": c[0][2] and s.members().size() > 0}]
	return null


func _params_actor(a: XActor) -> Array:
	return range(8).map(func(i): return a.param(i))


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	var n := 0
	if check("zhenqi_oracle_loaded", data is Dictionary, ORACLE):
		for c in data.cases:
			if not Base.SECOND.any(func(p): return c.id.begins_with(p)):
				continue
			n += 1
			if not c.errors.is_empty():
				check("oracle_" + c.id, false, c.errors)
				continue
			var got = _case(c.id, c.setup)
			check(c.id, got != null and _same(got, c.observed), [got, c.observed])
	check("second_batch_cases", n >= 60, n)
	_extra()
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_zhenqi_break", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)


## 存档：道法记录与降服记录往返；读档清掉进行中的瓶颈之战
func _extra() -> void:
	_fresh()
	var a := s.actor(1)
	_set_zq(a, {"qi": 3000, "realm": 1, "daofa": {"pojia": 1}, "daofaStages": {"pojia": 1}})
	s.zhenqi_spec.e["2"] = 1
	XZhenqi.pending_trial = {"troopId": 901}
	var d = JSON.parse_string(JSON.stringify(s.to_dict()))
	var back := XState.from_dict(d)
	check("save_daofa", _same(back.actor(1).zhenqi.daofa, {"pojia": 1}) and _same(back.actor(1).zhenqi.daofaStages, {"pojia": 1}), back.actor(1).zhenqi)
	check("save_spec", back.zhenqi_spec.e.has("2"), back.zhenqi_spec)
	XState._become_current(back)
	check("load_clears_trial", XZhenqi.pending_trial.is_empty())
