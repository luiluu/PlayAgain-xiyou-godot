extends Node
## 【cc·八戒·未经审查】成长装备期二b 魔冠 XDemonCrown：照参照 demon_crown_probe（tests/fixtures/demon_crown_oracle.json）逐例比。
## 开战／收战直接调 XDemonCrown.begin／finish（参照是真 BattleManager.setup／startBattle／endBattle，不跑回合），存读档走 before_save／to_dict 与 from_dict／after_load。
## 不比的：品质（参照的词缀掷出 14，重制自己掷）、八项能力值、别的模块的提示（降服…）；battle.bigbonus（参照改账本文件后内存不变，照旧）只比 item 的成长与特性。
const FIXTURE := "res://tests/fixtures/demon_crown_oracle.json"
const PARTY := [1, 8, 9, 10]
var checks := 0
var failures: Array = []
var s: XState


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))


func _same(got, want) -> bool:
	if want == null:
		return got == null
	if want is float or want is int:
		return (got is float or got is int) and absf(float(got) - float(want)) < 1e-5
	if want is Array:
		if not (got is Array) or got.size() != want.size():
			return false
		for i in want.size():
			if not _same(got[i], want[i]):
				return false
		return true
	if want is Dictionary:
		if not (got is Dictionary):
			return false
		for k in want:
			if not got.has(k) or not _same(got[k], want[k]):
				return false
		return true
	return typeof(got) == typeof(want) and got == want


func _cmp(tag: String, got, want) -> void:
	if want is Dictionary and got is Dictionary:
		for k in want:
			if k in ["quality", "ici"]:
				continue
			check(tag + "." + k, got.has(k) and _same(got[k], want[k]), [got.get(k), want[k]])
	else:
		check(tag, _same(got, want), [got, want])


func _fresh() -> void:
	DirAccess.remove_absolute(XDemonCrown.path_override)
	XDemonCrown.reload()
	s = XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	s.battle_slots = PARTY.duplicate()
	s.map_id = 4  # 参照新局在 Map004
	for id in PARTY:
		var a: XActor = s.actor(id)
		a._lv = 60
		a.refresh_passive()
		a.recover_all()


func _crowns() -> Array:
	return XDemonCrown.owned(s)


func _grant() -> Dictionary:
	s.gain_gear("armor", XDemonCrown.ARMOR, 1)
	return s.gear.filter(XDemonCrown.is_gear).back()


func _equip(a: XActor, it) -> void:
	var slot := a.equip_slots().find(17)
	XEquipment.change(s, a, slot, it)
	a.refresh_passive()
	a.param_mark_dirty()


func _wearing(a: XActor):
	var g := XDemonCrown.gear(a)
	return XDemonCrown.bonus(g) if not g.is_empty() else null


func _seq() -> int:
	return int(s.flags.get(XDemonCrown.SEQ_FLAG, 0))


func _ledger():
	var p = XDemonCrown.record(s)
	if p == null:
		return null
	var keys: Array = (p.battles as Dictionary).keys()
	keys.sort()
	return {"items": (p.items as Dictionary).values().map(func(r): return [float(r.bonus), bool(r.removed)]),
		"battles": keys.map(func(k):
			var r: Dictionary = p.battles[k]
			return [k, int(r.troop), int(r.map), bool(r.eligible), r.roll, (r.wears as Array).size(), (r.deaths as Dictionary).size(), bool(r.settled), r.get("result"), str(r.get("dropUid", "")) != ""]),
		"worldDeaths": (p.worldDeaths as Dictionary).size()}


func _snap(it: Dictionary) -> Dictionary:
	var pos: Array = RegEx.create_from_string("<pos=APs text=成长[^>]*?size=").search_all(str(it.note)).map(func(m): return m.get_string())
	return {"name": it.name, "baseName": it.baseName, "description": it.description, "icon": int(it.iconIndex), "uid": str(it.get(XDemonCrown.UID, "")) != "",
		"bonus": XDemonCrown.bonus(it), "pos": pos,
		"crown": (it.traits as Array).filter(func(t): return bool(t.get("_codexCrown", false))).map(func(t): return [int(t.code), int(t.dataId), float(t.value)])}


func _fight(result: int, o := {}) -> void:
	if o.has("map"):
		s.map_id = int(o.map)
	if o.has("origin"):
		if o.origin == null:
			s.flags.erase(XYunshangOrders.ORIGIN_FLAG)
		else:
			s.flags[XYunshangOrders.ORIGIN_FLAG] = o.origin
	var roll: float = o.get("roll", 0.5) if o.get("roll") != null else 0.5
	XDemonCrown.begin(s, int(o.get("troop", 3)), func(): return roll)
	if o.has("during"):
		(o.during as Callable).call()
	XDemonCrown.finish(s, result)


func _encode() -> String:
	XDemonCrown.before_save(s)
	return JSON.stringify(s.to_dict())


func _restore(text: String) -> void:
	XState.from_dict(JSON.parse_string(text))
	s = XState.current
	XDemonCrown.after_load(s, XDemonCrown.identity(text))


func _die(a: XActor) -> void:
	a.add_state(1)


func _revive(a: XActor) -> void:
	a.remove_state(1)
	a.hp = 1.0


func _strip(v) -> void:
	if v is Dictionary:
		if v.has(XDemonCrown.UID):
			v.erase(XDemonCrown.UID)
			v[XDemonCrown.BONUS] = 37.5
		for k in v.keys():
			_strip(v[k])
	elif v is Array:
		for x in v:
			_strip(x)


func _run(c: Dictionary) -> void:
	var id: String = c.id
	var want: Dictionary = c.observed
	match id:
		"next":
			var chain := []
			var b := 0.0
			for i in 5:
				b = XDemonCrown.next(b)
				chain.append(b)
			_cmp(id, {"chain": chain, "at": [0, 1, 499.5, 999, 999.9, 1000, 1200, -5].map(func(v): return XDemonCrown.next(v)),
				"display": [0, 0.4, 0.5, 1.49, 2.5, 99.99].map(func(v): return XDemonCrown.display(v))}, want)
		"grant":
			_fresh()
			var it := _grant()
			s.gain_gear("armor", XDemonCrown.ARMOR, 2)
			_cmp(id + ".item", _snap(it), want.item)
			_cmp(id, {"count": _crowns().size(), "ledger": _ledger(), "seq": _seq()}, {"count": want.count, "ledger": want.ledger, "seq": want.seq})
		"help":
			_fresh()
			var it := _grant()
			it[XDemonCrown.BONUS] = float(c.setup.bonus)
			XDemonCrown.describe(it)
			# 神话词条（品质行的标签、\\c[n] 词条行）是重制自己掷的，不比
			var no_affix := func(t): return not (str(t).begins_with("品质：") or str(t).contains("特效") or (str(t).begins_with("\\c[") and not str(t).begins_with("\\c[1]")))
			_cmp(id, XHelpCard.desc_params(it, 2).map(func(r): return str(r[0])).filter(no_affix), (want.rows as Array).filter(no_affix))
			# getDescParams 包装：带小数的数字（连正负号）换成 D.display（Math.round，正号丢掉）
			var rr := [["物攻+1.5%，暴击-2.49", 12, "", false, null]]
			XDemonCrown.desc_rows(it, rr)
			check(id + ".round", rr[0][0] == "物攻2%，暴击-2", rr[0][0])
			# 图标 290000：整张 Codex_DemonCrown 缩到格子大小（切片 system 图）
			var ic := XUI.icon_texture(XDemonCrown.ICON)
			var big := XDemonCrown.icon_texture(128)
			check(id + ".icon", ic != null and ic.get_width() == 32 and big != null and big.get_width() == 128, [ic, big])
		"battle.win":
			_fresh()
			var a := s.actor(1)
			_equip(a, _grant())
			var rows := []
			for r in [0, 0, 0, 1, 2, 0]:
				_fight(r)
				rows.append([r, _wearing(a), _seq()])
			_cmp(id, {"rows": rows, "ledger": _ledger()}, {"rows": want.rows, "ledger": want.ledger})
			_cmp(id + ".item", _snap(XDemonCrown.gear(a)), want.item)
		"battle.bigbonus":
			_fresh()
			var a := s.actor(1)
			_equip(a, _grant())
			XDemonCrown.replay(s)
			_cmp(id + ".item", _snap(XDemonCrown.gear(a)), want.item)
		"battle.death":
			_fresh()
			var a := s.actor(1)
			_equip(a, _grant())
			for i in 4:
				_fight(0)
			var rows := [["won4", _wearing(a)]]
			_fight(0, {"during": func():
				_die(a)
				rows.append(["died", _wearing(a)])
				_die(a)
				rows.append(["again", _wearing(a)])})
			rows.append(["deadwin", _wearing(a), a.is_dead()])
			_revive(a)
			_fight(0, {"during": func():
				_die(a)
				rows.append(["died2", _wearing(a)])
				_revive(a)
				_die(a)
				rows.append(["died3", _wearing(a)])
				_revive(a)})
			rows.append(["revivedwin", _wearing(a)])
			_die(a)
			rows.append(["world", _wearing(a)])
			_revive(a)
			_die(a)
			rows.append(["world2", _wearing(a)])
			_die(s.actor(8))
			rows.append(["otherdied", _wearing(a)])
			_cmp(id, {"rows": rows, "ledger": _ledger(), "worldSeq": int(s.flags.get(XDemonCrown.WORLD_FLAG, 0))}, want)
		"guyu.root":
			# 审查 31 P3-1：穿魔冠、有死亡抵抗的谷雨强制归根，补的 addNewState 照样触发魔冠死亡（成长减半）
			_fresh()
			s.switches[2494] = true  # 同参照：开超强者（谷雨才进得了出战）
			var party: Array[int] = []
			party.assign((c.setup.party as Array).map(func(x): return int(x)))
			s.party = party
			s.battle_slots = party.duplicate()
			var g := s.actor(XGuyu.ACTOR)
			g._lv = 60
			g.refresh_passive()
			g.recover_all()
			var it := _grant()
			it.traits.append({"code": 14, "dataId": 1, "value": 0.0})
			_equip(g, it)
			for i in 2:
				_fight(0)
			var rows := [["won2", _wearing(g)]]
			var at := {}  # lambda 只捕获引用，往字典里写
			_fight(0, {"during": func():
				XGuyu.reset()
				# 审查 33 P3-1：临时给谷雨一个行动结果上下文，真读补的 pushAddedState（addedStates）
				var rc := XResourceContext.new()
				var previous := g.lifecycle_context
				g.lifecycle_context = {"resources": rc}
				XGuyu.root(g, true)
				g.lifecycle_context = previous
				rows.append(["rooted", _wearing(g), g.is_dead(), g.hp, g.state_ids.duplicate(), rc.result(g).addedStates.duplicate(), g.buffs.slice(0, 8)])
				at.v = _ledger()})
			_cmp(id, {"rows": rows, "ledger": at.get("v")}, want)
		"battle.swap":
			_fresh()
			var a := s.actor(1)
			var it := _grant()
			_equip(a, it)
			var rows := []
			_fight(0, {"during": func():
				_equip(a, null)
				_equip(a, it)})
			rows.append(["swapback", _wearing(a)])
			_fight(0)
			rows.append(["plain", _wearing(a)])
			_fight(0, {"during": func(): _equip(a, null)})
			rows.append(["off", _wearing(a), XDemonCrown.bonus(it)])
			_equip(s.actor(8), it)
			s.battle_slots = [1, 9, 10, 0]
			_fight(0)
			rows.append(["reserve", XDemonCrown.bonus(it)])
			s.battle_slots = PARTY.duplicate()
			_fight(0)
			rows.append(["member", XDemonCrown.bonus(it)])
			_cmp(id, {"rows": rows, "ledger": _ledger()}, want)
		"drop.legacy107":
			_fresh()
			s.variables[107] = 2
			_fight(0, {"troop": 539, "roll": 0.01, "map": 162, "origin": null})
			_cmp(id, {"count": _crowns().size(), "ledger": _ledger()}, want)
		"scum":
			_fresh()
			var a := s.actor(1)
			_equip(a, _grant())
			var save0 := _encode()
			var rows := []
			_fight(0)
			_fight(0)
			rows.append(["won2", _wearing(a), _seq()])
			_restore(save0)
			var a2 := s.actor(1)
			rows.append(["reloaded", _wearing(a2), _seq(), _crowns().size()])
			_fight(0)
			rows.append(["refight", _wearing(a2), _seq()])
			var save1 := _encode()
			_fight(0, {"troop": 539, "roll": 0.01, "map": 162, "origin": 57})
			rows.append(["drop", _crowns().size(), _wearing(a2)])
			_restore(save1)
			rows.append(["reloaded2", _crowns().size(), _seq()])
			_fight(0, {"troop": 539, "roll": 0.9, "map": 162, "origin": 57})
			rows.append(["samekey", _crowns().size(), _wearing(s.actor(1)), _seq()])
			_restore(save1)
			_fight(0, {"troop": 3, "roll": 0.9})
			rows.append(["otherkey", _crowns().size(), _wearing(s.actor(1)), _seq()])
			_cmp(id, {"rows": rows, "ledger": _ledger()}, {"rows": want.rows, "ledger": want.ledger})
		"lose":
			_fresh()
			var it := _grant()
			var save0 := _encode()
			var rows := []
			s.lose_gear(it)
			rows.append(["sold", _crowns().size(), _ledger().items])
			_restore(save0)
			rows.append(["reloaded", _crowns().size()])
			var it2 := _grant()
			var a := s.actor(1)
			_equip(a, it2)
			rows.append(["equipped", _crowns().size(), _ledger().items])
			_equip(a, null)
			rows.append(["unequipped", _crowns().size(), _ledger().items])
			s.gain_gear("armor", XDemonCrown.ARMOR, -1)
			rows.append(["bybase", _crowns().size(), _ledger().items])
			_restore(_encode())
			rows.append(["bybase.reload", _crowns().size()])
			_cmp(id, {"rows": rows}, want)
		"adopt":
			_fresh()
			_grant()
			var d = JSON.parse_string(_encode())
			_strip(d)
			for k in [XDemonCrown.PROFILE_FLAG, XDemonCrown.SEQ_FLAG, XDemonCrown.WORLD_FLAG, XDemonCrown.KNOWN_FLAG]:
				d.flags.erase(k)
			DirAccess.remove_absolute(XDemonCrown.path_override)
			XDemonCrown.reload()
			_restore(JSON.stringify(d))
			var got := _crowns()
			_cmp(id, {"count": got.size(), "ledger": _ledger(), "profile": str(s.flags.get(XDemonCrown.PROFILE_FLAG, "")) != ""},
				{"count": want.count, "ledger": want.ledger, "profile": want.profile})
			if not got.is_empty():
				_cmp(id + ".item", _snap(got[0]), want.item)
		_:
			if id.begins_with("drop."):
				_fresh()
				var st: Dictionary = c.setup
				_fight(int(st.result), {"troop": st.troop, "roll": st.roll, "map": st.map, "origin": st.origin})
				_cmp(id, {"count": _crowns().size(), "ledger": _ledger(), "seq": _seq(), "toast": XDemonCrown.DROP_TEXT in want.toasts},
					{"count": want.count, "ledger": want.ledger, "seq": want.seq, "toast": _crowns().size() > 0})
				if want.item != null and not _crowns().is_empty():
					_cmp(id + ".item", _snap(_crowns()[0]), want.item)
			else:
				check("unknown." + id, false)


func _ready() -> void:
	_main.call_deferred()  # 掉落提示（XToast）要往根节点加子节点，_ready 里根节点还在布置子节点会报 ERROR


func _main() -> void:
	XDemonCrown.path_override = XSave.dir().path_join("crown_progress_test.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in data.cases:
		_run(c)
	DirAccess.remove_absolute(XDemonCrown.path_override)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_demon_crown", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
