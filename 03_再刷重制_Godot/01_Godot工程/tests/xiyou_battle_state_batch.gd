extends Node
## 【cc·未经审查】整批加减状态（进出战斗卡顿 C 车道，Kyo 11-13）。
## 开战每人挂二十来个状态、收场逐个拿掉；refresh 的次数、先后不变，只省重复的计算。三个开关，开与关结果逐项相同：
## - XActor.STATE_BATCH：批里加减状态按类别只作废会变的表（技能表、特性表、按特性码取的集合、「一件都不用卸」），被动缓存延后到读或批末；
## - XActor.RELEASE_ONCE：拿掉状态后第二遍卸装判断在输入没变时跳过；
## - XBattleLogic.LIFECYCLE_LOG：角色的逐次快照默认不留。
## 查法：状态分类；全库状态逐个在批里加上再拿掉，开关两态每一步读到的技能表、特性、上限、装备、被动缓存相同；
## 混着轻状态、带特性的、封装备的、带挂上／拿掉效果的整场战斗，开关两态整份日志相同，开全程比对零不一致。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _on() -> void:
	XActor.STATE_BATCH = true
	XActor.RELEASE_ONCE = true
	XBattleLogic.LIFECYCLE_LOG = false


func _off() -> void:
	XActor.STATE_BATCH = false
	XActor.RELEASE_ONCE = false
	XBattleLogic.LIFECYCLE_LOG = true


func _plain(v, logic: XBattleLogic):
	if v is XBattler:
		return logic.stable_id(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(_plain(k, logic))] = _plain(v[k], logic)
		return out
	if v is Array:
		return v.map(func(x): return _plain(x, logic))
	if v is Object:
		return "<%s>" % v.get_class()
	if v is Callable:
		return "<callable>"
	return v


## 四人 99 级，各自穿上能穿的装备（同 xiyou_battle_enter_exit_lag 的挑法）
func _new_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.random_master = XRandomStream.hex64(20261113)
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(99)
		for pick in [["weapon", 37], ["armor", 53], ["armor", 71], ["armor", 113], ["armor", 157], ["armor", 211]]:
			var table: Array = XDB.table("Weapons" if pick[0] == "weapon" else "Armors")
			for step in 40:
				var gid := 1 + (int(pick[1]) * (step + 1) + id * 7) % (table.size() - 1)
				if table[gid] == null or str(table[gid].get("name", "")) == "":
					continue
				var before := s.gear.size()
				s.gain_gear(str(pick[0]), gid, 1)
				if s.gear.size() == before:
					continue
				var item: Dictionary = s.gear[-1]
				var slot := a.equip_slots().find(1 if pick[0] == "weapon" else int(item.etypeId))
				if slot >= 0 and a.equips[slot] == null and a.can_equip(item) and XEquipment.change(s, a, slot, item):
					break
		a.refresh_passive()
		a.recover_all()
	return s


## 一名角色此刻读得到的全部：资源、上限、状态、技能表、特性、几组特性集合、装备、被动缓存
func _sig(a: XActor) -> Array:
	return [a.hp, a.mp, a.tp, a.mhp, a.mmp, a.max_tp(), a.state_ids.duplicate(), a.skills().map(func(s): return int(s.id)),
		JSON.stringify(a.all_traits()).hash(), a.traits_set(14), a.traits_set(51), a.traits_set(52), a.traits_set(54), a.traits_set(55),
		a.equip_list().size(), JSON.stringify(a.passive_cache()).hash(), a.atk, a.agi]


func _states_where(pred: Callable, n: int) -> Array:
	var out := []
	for id in range(2, XDB.table("States").size()):
		var r := XDB.rec("States", id)
		if r.is_empty() or str(r.get("name", "")) == "":
			continue
		if pred.call(id, r):
			out.append(id)
			if out.size() >= n:
				break
	return out


func _has_code(r: Dictionary, codes: Array, data_id := -1) -> bool:
	return (r.get("traits", []) as Array).any(func(t): return int(t.code) in codes and (data_id < 0 or int(t.dataId) == data_id))


func _has_phase(r: Dictionary, phases: Array) -> bool:
	return (r.get("effects", []) as Array).any(func(e): return str(e.get("phase", "")) in phases)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_state_batch"
	XConfig.path_override = XSave.dir().path_join("options.json")
	_class_rules()
	_sweep()
	_battles()
	_clamp_order()
	_passive_owed()
	_misc()
	_on()
	XActor.READ_VERIFY = false
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _class_rules() -> void:
	var light := _states_where(func(_id, r): return (r.get("traits", []) as Array).is_empty() and not _has_phase(r, ["apply", "remove", "leave"]), 3)
	var traited := _states_where(func(_id, r): return _has_code(r, [21]) and not _has_code(r, [43]) and not _has_phase(r, ["apply", "remove", "leave"]), 3)
	var effect := _states_where(func(_id, r): return _has_phase(r, ["apply", "remove", "leave"]), 3)
	var skill := _states_where(func(_id, r): return _has_code(r, [43]), 3)
	check("class.samples", light.size() == 3 and traited.size() == 3 and effect.size() == 3, [light, traited, effect, skill])
	check("class.light", light.all(func(id): return XBattler.state_class(id) == XBattler.STATE_LIGHT and XBattler.state_trait_mask(id) == 0), light)
	check("class.traits", traited.all(func(id): return XBattler.state_class(id) == XBattler.STATE_TRAITS and XBattler.state_trait_mask(id) & (1 << 21) != 0), traited)
	check("class.effects_hard", effect.all(func(id): return XBattler.state_class(id) == XBattler.STATE_HARD), effect)
	check("class.skill_add_hard", skill.all(func(id): return XBattler.state_class(id) == XBattler.STATE_HARD), skill)
	check("class.death_pojia_missing_hard", XBattler.state_class(1) == XBattler.STATE_HARD and XBattler.state_class(XZhenqi.POJIA_STATE) == XBattler.STATE_HARD
		and XBattler.state_class(999999) == XBattler.STATE_HARD)
	# 不在批里：一律按普通写入作废
	XActor._batch_depth = 0
	var w := XActor._write_gen
	XActor.state_touch(int(light[0]))
	check("touch.outside_batch_hard", XActor._write_gen == w + 1)
	XActor.batch_begin()
	w = XActor._write_gen
	var r := XActor._read_gen
	XActor.state_touch(int(light[0]))
	XActor.state_touch(int(traited[0]))
	check("touch.batch_soft", XActor._write_gen == w and XActor._read_gen == r + 2, [XActor._write_gen - w, XActor._read_gen - r])
	XActor.state_touch(int(effect[0]))
	check("touch.batch_hard", XActor._write_gen == w + 1)
	XActor.STATE_BATCH = false
	w = XActor._write_gen
	XActor.state_touch(int(light[0]))
	check("touch.switch_off_hard", XActor._write_gen == w + 1)
	XActor.STATE_BATCH = true
	XActor.batch_end()
	check("batch.closed", XActor._batch_depth == 0 and XActor._carry.is_empty())


## 全库状态逐个在批里加上、读一遍、拿掉、再读一遍：返回每一步读到的值的摘要
func _sweep_pass(ids: Array) -> Dictionary:
	var s := _new_state()
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var rows := []
	var hits := XActor.carry_hits
	XActor.batch_begin()
	for n in ids.size():
		var a: XActor = logic.actors[n % 2]
		var id := int(ids[n])
		logic._state_add(a, id)
		var one := [id, _sig(a).hash()]
		logic._state_remove(a, id)
		one.append(_sig(a).hash())
		one.append(a.state_ids.size())
		rows.append(one)
	XActor.batch_end()
	return {"rows": rows, "hits": XActor.carry_hits - hits, "end": logic.actors.map(func(a): return _sig(a))}


func _sweep() -> void:
	var ids := _states_where(func(id, r): return int(r.get("restriction", 0)) == 0 and id != XZhenqi.POJIA_STATE, 100000)
	var by_class := [0, 0, 0]
	for id in ids:
		by_class[XBattler.state_class(id)] += 1
	_off()
	var off := _sweep_pass(ids)
	_on()
	var on := _sweep_pass(ids)
	var diff := []
	for i in ids.size():
		if off.rows[i] != on.rows[i] and diff.size() < 8:
			diff.append([off.rows[i], on.rows[i]])
	check("sweep.population", ids.size() > 1000 and by_class[0] > 200 and by_class[1] > 200 and by_class[2] > 50, [ids.size(), by_class])
	check("sweep.same", diff.is_empty() and off.end == on.end, diff)
	check("sweep.carry_used", int(on.hits) > ids.size() and int(off.hits) == 0, [on.hits, off.hits])


## 混着各类状态的清单：轻的、带能力特性的（含抬高、压低生命上限的）、带装备类特性的、加技能的、带挂上／拿掉效果的
func _mix() -> Array:
	var end := func(_id, r): return int(r.get("restriction", 0)) == 0 and bool(r.get("removeAtBattleEnd", false))
	var out := []
	out.append_array(_states_where(func(id, r): return end.call(id, r) and XBattler.state_class(id) == XBattler.STATE_LIGHT, 8))
	out.append_array(_states_where(func(id, r): return end.call(id, r) and XBattler.state_class(id) == XBattler.STATE_TRAITS and _has_code(r, [21], 0), 3))
	out.append_array(_states_where(func(id, r): return end.call(id, r) and XBattler.state_class(id) == XBattler.STATE_TRAITS and _has_code(r, [22, 23, 61, 62, 14]), 4))
	out.append_array(_states_where(func(id, r): return int(r.get("restriction", 0)) == 0 and _has_code(r, [51, 52, 54, 55]), 2))
	out.append_array(_states_where(func(id, r): return end.call(id, r) and _has_phase(r, ["apply", "remove"]), 3))
	out.append_array(_states_where(func(id, r): return int(r.get("restriction", 0)) == 0 and _has_code(r, [43]), 1))
	var uniq := []
	for id in out:
		if not uniq.has(id):
			uniq.append(id)
	return uniq


## 一场：批里给四人挂上清单里的状态（mid＝每挂一个读一遍），两回合自动战斗，胜利收场。返回整份日志的摘要
func _battle(troop: int, mid: bool) -> Dictionary:
	var s := _new_state()
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	var ids := _mix()
	for e in logic.enemies:
		e._rates[0] *= 1000
		e.recover_all()
	var journal := []
	var gear_before := s.gear.size()
	XActor.batch_begin()
	for a in logic.actors:
		for id in ids:
			logic._state_add(a, id)
			if mid:
				journal.append(_sig(a))
	XActor.batch_end()
	journal.append([_plain(logic.views(), logic), logic.actors.map(func(a): return _sig(a)), s.gear.size() - gear_before])
	var out := {"acts": 0, "states": 0, "ids": ids.size(), "unequipped": s.gear.size() - gear_before}
	for a in logic.actors:
		out.states += a.state_ids.size()
	logic.auto = true
	for round_index in 2:
		logic.start_turn()
		journal.append(_plain(logic.take_turn_start_logs(), logic))
		var count := 0
		while count < 40:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			var logs := logic.act(u, cmd[0], cmd[1])
			out.acts += 1
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logs, logic)])
		journal.append(_plain(logic.end_turn(), logic))
		if logic.is_over():
			break
	for a in logic.actors:
		a.hp = a.mhp  # 满血收场：拿掉抬高上限的状态时要夹回
	journal.append(logic.actors.map(func(a): return _sig(a)))
	logic.end_battle(0)
	journal.append([logic.random.snapshot(), s.members().map(func(a): return _sig(a)), s.gear.size(), s.gear.map(func(g): return int(g.get("uid", g.get("id", 0))))])
	out.lifecycle = logic.lifecycle_effects.size()
	out.sig = JSON.stringify(journal).sha256_text()
	out.size = JSON.stringify(journal).length()
	return out


func _battles() -> void:
	for troop in [2, 70]:
		for mid in [false, true]:
			var tag := "%d%s" % [troop, ".mid" if mid else ""]
			_off()
			var off := _battle(troop, mid)
			_on()
			var hits := XActor.carry_hits
			var on := _battle(troop, mid)
			check("battle.same:" + tag, off.sig == on.sig and int(off.acts) >= 4 and int(off.states) >= 40 and int(off.ids) >= 15, [off.sig, on.sig, off.acts, off.states, off.ids, off.size])
			check("battle.carry_used:" + tag, XActor.carry_hits - hits > 200, XActor.carry_hits - hits)
			check("battle.lifecycle_log:" + tag, int(off.lifecycle) > 20 and int(on.lifecycle) < int(off.lifecycle), [off.lifecycle, on.lifecycle])
			check("battle.closed:" + tag, XActor._batch_depth == 0 and XActor._read_depth == 0 and XActor._passive_owed.is_empty())
			if mid:
				continue
			XActor.READ_VERIFY = true
			XActor.read_mismatches.clear()
			var verified := _battle(troop, false)
			XActor.READ_VERIFY = false
			check("battle.verify:" + tag, XActor.read_mismatches.is_empty() and verified.sig == off.sig, XActor.read_mismatches.slice(0, 3))
			# 三个开关各自单开
			_off()
			XActor.STATE_BATCH = true
			check("battle.only_STATE_BATCH:" + tag, _battle(troop, false).sig == off.sig)
			_off()
			XActor.RELEASE_ONCE = true
			check("battle.only_RELEASE_ONCE:" + tag, _battle(troop, false).sig == off.sig)
			_off()
			XBattleLogic.LIFECYCLE_LOG = false
			check("battle.only_LIFECYCLE_LOG:" + tag, _battle(troop, false).sig == off.sig)




func _mhp_state(id: int, r: Dictionary, up: bool) -> bool:
	if not bool(r.get("removeAtBattleEnd", false)) or XBattler.state_class(id) != XBattler.STATE_TRAITS:
		return false
	return (r.get("traits", []) as Array).any(func(t): return int(t.code) == 21 and int(t.dataId) == 0 and ((float(t.value) > 1.0) if up else (float(t.value) < 1.0)))


## 先拿掉抬高上限的、后拿掉压低上限的：逐步夹值和只在最后夹一次结果不同——这里每步照夹，开关两态一样
func _clamp_pass() -> Array:
	var s := _new_state()
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var up := _states_where(func(id, r): return _mhp_state(id, r, true), 1)
	var down := _states_where(func(id, r): return _mhp_state(id, r, false), 1)
	if up.is_empty() or down.is_empty():
		return [false]
	var a: XActor = logic.actors[0]
	var plain := a.mhp
	XActor.batch_begin()
	logic._state_add(a, int(up[0]))
	logic._state_add(a, int(down[0]))
	XActor.batch_end()
	var both := a.mhp
	a.hp = both
	var order := a.state_ids.filter(func(id): return id == int(up[0]) or id == int(down[0]))
	logic.end_battle(0)
	return [true, plain, both, a.hp, a.mhp, order, a.state_ids.has(int(up[0])), a.state_ids.has(int(down[0]))]


func _clamp_order() -> void:
	_off()
	var off := _clamp_pass()
	_on()
	var on := _clamp_pass()
	check("clamp.found", bool(off[0]), off)
	if not bool(off[0]):
		return
	check("clamp.same", off == on, [off, on])
	check("clamp.removed_and_clamped", not bool(on[6]) and not bool(on[7]) and float(on[3]) <= float(on[4]) and float(on[4]) == float(on[1]), on)


## 被动缓存延后：批里先欠着，读的时候补建，值与当场重建相同；批结束全部补齐
func _passive_owed() -> void:
	_on()
	var s := _new_state()
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var tagged := _states_where(func(id, r): return XBattler.state_class(id) != XBattler.STATE_HARD and str(r.get("note", "")).contains("<passiveHarmRe"), 1)
	check("passive.sample", tagged.size() == 1, tagged)
	if tagged.is_empty():
		return
	var a: XActor = logic.actors[0]
	var b: XActor = logic.actors[1]
	var before := JSON.stringify(a.passive_cache())
	XActor.batch_begin()
	logic._state_add(a, int(tagged[0]))
	logic._state_add(b, int(tagged[0]))
	check("passive.owed", a._passive_pending and b._passive_pending and XActor._passive_owed.size() >= 2)
	var read := JSON.stringify(a.passive_cache())
	check("passive.read_flushes", not a._passive_pending and b._passive_pending and read != before)
	XActor.batch_end()
	check("passive.batch_end_flushes", not b._passive_pending and XActor._passive_owed.is_empty())
	var lazy := [read, JSON.stringify(b.passive_cache())]
	a.refresh_passive()
	b.refresh_passive()
	check("passive.same_as_rebuild", lazy == [JSON.stringify(a.passive_cache()), JSON.stringify(b.passive_cache())])
	check("passive.outside_batch_immediate", not a._passive_pending)
	logic.end_battle(0)


func _misc() -> void:
	_on()
	# 批没关（中途出错跳出）：下一次开战／收场／行动开始复位
	var s := _new_state()
	var logic := XBattleLogic.new()
	XActor.batch_leak_quiet = true
	var leaks := XActor.batch_leaks
	XActor._batch_depth = 2
	logic.setup(2, s)
	check("reset.on_setup", XActor._batch_depth == 0 and XActor.batch_leaks == leaks + 1)
	XActor._batch_depth = 1
	XActor.read_reset()
	check("reset.on_action_start", XActor._batch_depth == 0 and XActor.batch_leaks == leaks + 2)
	XActor.batch_leak_quiet = false
	# 第二遍卸装判断：没有资源上下文时（菜单里拿掉状态）没有第一遍，照判
	var a: XActor = logic.actors[0]
	var light := _states_where(func(id, _r): return XBattler.state_class(id) == XBattler.STATE_LIGHT, 1)
	a.state_ids.append(int(light[0]))
	a._release_mark = []
	a.remove_state(int(light[0]))
	check("release.no_context_runs", a._release_mark.size() == 9 and not a.state_ids.has(int(light[0])))
	# 有资源上下文：第一遍判完留下记号，输入没变就跳过第二遍；RELEASE_ONCE = false 不留记号
	logic._state_add(a, int(light[0]))
	logic._state_remove(a, int(light[0]))
	check("release.mark_consumed", a._release_mark.is_empty())
	XActor.RELEASE_ONCE = false
	a._release_mark = []
	logic._state_add(a, int(light[0]))
	logic._state_remove(a, int(light[0]))
	check("release.switch_off_no_mark", a._release_mark.is_empty() and not a._release_repeat())
	XActor.RELEASE_ONCE = true
	# 逐次快照：默认角色不留，LIFECYCLE_LOG = true 留
	XBattleLogic.LIFECYCLE_LOG = false
	logic.lifecycle_effects.clear()
	logic._state_add(a, int(light[0]))
	var none := logic.lifecycle_effects.size()
	XBattleLogic.LIFECYCLE_LOG = true
	logic._state_remove(a, int(light[0]))
	check("lifecycle.switch", none == 0 and logic.lifecycle_effects.size() == 1, [none, logic.lifecycle_effects.size()])
	XBattleLogic.LIFECYCLE_LOG = false
	logic.end_battle(0)
