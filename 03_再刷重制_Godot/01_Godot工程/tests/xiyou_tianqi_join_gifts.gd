extends Node
## T398（O-267 连带，Kyo 11-22「我怎么没有璇的法宝可以装备或者买」「法宝改成所有人入队都穿在身上」「号角送的技能：给」）：
## 天启篇第一次入队（开局阵容、通关抽角色）照原版号角入队那段给专属法宝／专属武器防具、学号角技能，给的装备穿在本人身上（XTianqi.on_join）。
## 一、14 名模块与号角法宝角色（167～179、84 小毒、85 爱莉）逐个：入队、法宝穿上、队伍顺序不变、只记一次、再入队不重复给。
## 二、17 名超强者（141～166 去掉天启篇停用的 9 人）：号角脚本里的专属武器／防具穿上（同类栏不够的留背包）、超越极限 I～IV；诸葛孔明两招。
## 三、开局阵容（不走 _joining、靠 lineup）同样给；停用角色不入队也不给；原有同栏装备回背包。
## 四、号角仍不进背包；开关 JOIN_GIFTS 关＝不给；西游档零变化。

const MODULE_GEAR := {167: [["armor", 4001]], 168: [["armor", 4577]], 169: [["armor", 0]], 170: [["armor", 0]], 171: [["armor", 4580]],
	172: [["armor", 4581]], 173: [["armor", -1]], 174: [["armor", 7935]], 175: [["armor", 7912]], 176: [["armor", 4047]], 177: [["armor", 4048]],
	178: [["armor", 7999]], 179: [["weapon", 4004], ["armor", 4582]]}
const HORN_GEAR := {84: [["armor", 4514]], 85: [["armor", 4515]]}
const LIMIT_SKILLS := [1240, 1241, 1242, 1244]
const LIMIT_ACTORS := [150, 151, 153, 154, 155, 156, 158, 159, 162, 163, 164, 165]

var results: Array = []
var _w: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(lineup: Array, via_lineup := false) -> XState:
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	XState.current = s
	for id in lineup:
		XTianqi._joining = not via_lineup
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	return s


func _join(s: XState, id: int) -> void:
	XTianqi._joining = true
	s.add_actor(id)
	XTianqi._joining = false


func _wears(a: XActor, kind: String, base: int) -> bool:
	return a.equips.any(func(e): return e is Dictionary and str(e.get("kind", "")) == kind and int(e.get("base", 0)) == base)


## 背包＋全队身上同底本的件数
func _total(s: XState, kind: String, base: int) -> int:
	var n := s.gear_count(kind, base)
	for a in s.members():
		for e in a.equips:
			if e is Dictionary and str(e.get("kind", "")) == kind and int(e.get("base", 0)) == base:
				n += 1
	return n


func _expected(id: int) -> Array:
	if MODULE_GEAR.has(id):
		var out := []
		for g in MODULE_GEAR[id]:
			var base := int(g[1])
			if base == 0:
				base = int(XYomiJingliu.RECRUIT[id][0])
			out.append([g[0], base])
		return out
	if HORN_GEAR.has(id):
		return HORN_GEAR[id]
	return XTianqi.horn_gifts(id).gear.map(func(g): return [g.kind, int(g.base)])


func _run() -> void:
	XMessageBox.auto = true
	XSave.dir_override = "user://test_xiyou_tianqi_join_gifts"
	seed(20261122)
	_w = XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) \
		and XTianqi.horn_gifts(id).gear.is_empty() and XTianqi.horn_gifts(id).skills.is_empty()).slice(0, 5)
	_modules_and_horns()
	_supers()
	_lineup()
	_guards()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _one(id: int, tag: String) -> void:
	var s := _state(_w)
	var bag_before := s.gear.size()
	_join(s, id)
	var a := s.actor(id)
	_check("%s_%d_joined" % [tag, id], s.party == _w + [id], s.party)
	var want := _expected(id)
	var worn := []
	var gear_ok := not want.is_empty()
	for g in want:
		var base := int(g[1])
		var on := a.equips.any(func(e): return e is Dictionary and XGarou.is_relic(e)) if base == -1 else _wears(a, str(g[0]), base)
		worn.append([g, on])
		if tag != "super":
			gear_ok = gear_ok and on
	if tag == "super":  # 同类栏不够时（两把武器一个武器栏）后面的留背包：至少穿上一件、每件都拿到
		gear_ok = gear_ok and worn.any(func(x): return x[1]) and want.all(func(g): return _total(s, str(g[0]), int(g[1])) >= 1)
	_check("%s_%d_gear_worn" % [tag, id], gear_ok, worn)
	_check("%s_%d_once_flag" % [tag, id], (s.flags.tianqi.get(XTianqi.JOIN_GIFTS_KEY, []) as Array).count(id) == 1, s.flags.tianqi.get(XTianqi.JOIN_GIFTS_KEY))
	# 移出再入队：不再给（件数不变）
	var counts := want.map(func(g): return _total(s, str(g[0]), int(g[1])) if int(g[1]) > 0 else 0)
	var gear_n: int = s.gear.size() + s.members().reduce(func(n, m): return n + m.equips.filter(func(e): return e is Dictionary and not e.is_empty()).size(), 0)
	s.remove_actor(id)
	_join(s, id)
	var counts2 := want.map(func(g): return _total(s, str(g[0]), int(g[1])) if int(g[1]) > 0 else 0)
	var gear_n2: int = s.gear.size() + s.members().reduce(func(n, m): return n + m.equips.filter(func(e): return e is Dictionary and not e.is_empty()).size(), 0)
	_check("%s_%d_no_repeat" % [tag, id], s.party.has(id) and counts == counts2 and (gear_n2 == gear_n or MODULE_GEAR.has(id)), [counts, counts2, gear_n, gear_n2, bag_before])


func _modules_and_horns() -> void:
	for id in MODULE_GEAR.keys() + HORN_GEAR.keys():
		_one(int(id), "mod" if MODULE_GEAR.has(id) else "horn")


func _supers() -> void:
	var ids := []
	for id in range(141, 167):
		if XImportedBalance.is_disabled_actor(id):
			continue
		ids.append(id)
	_check("super_count_17", ids.size() == 17, ids)  # 141～166 共 26 人，停用 9 人（DISABLED_ACTORS 去掉已放出的 146）
	for id in ids:
		_check("super_%d_has_gear" % id, not XTianqi.horn_gifts(id).gear.is_empty(), XTianqi.horn_gifts(id))
		_one(id, "super")
	for id in LIMIT_ACTORS:
		var s := _state(_w)
		_join(s, id)
		var a := s.actor(id)
		_check("limit_%d_skills" % id, LIMIT_SKILLS.all(func(k): return a.skill_ids.has(k)), a.skill_ids)
	var s2 := _state(_w)
	_join(s2, 71)
	_check("kongming_skills", s2.actor(71).skill_ids.has(2498) and s2.actor(71).skill_ids.has(2511), s2.actor(71).skill_ids)
	# 原有同栏装备回背包（照换装规则）：150 桐人开局武器栏原本的那件
	var s3 := _state(_w)
	var a3 := s3.actor(150)
	var old = a3.equips[0]
	_join(s3, 150)
	var swapped := true
	if old is Dictionary and not old.is_empty():
		swapped = s3.gear.any(func(e): return is_same(e, old))
	_check("swap_old_to_bag", _wears(a3, "weapon", 81) and swapped, [old, a3.equips[0]])


func _lineup() -> void:
	var lineup := [177, 84, 150, _w[0], _w[1]]
	var s := _state(lineup, true)
	_check("lineup_party", s.party == lineup, s.party)
	_check("lineup_xuan_relic", _wears(s.actor(177), "armor", 4048) and s.gear_count("armor", 4048) == 0)
	_check("lineup_xiaodu_relic", _wears(s.actor(84), "armor", 4514))
	_check("lineup_kirito", _wears(s.actor(150), "weapon", 81) and s.actor(150).skill_ids.has(1240))
	_check("lineup_slots", s.battle_slots.slice(0, 5) == lineup, s.battle_slots)
	var bag := s.gear.size()
	_join(s, _w[2])
	_check("plain_join_no_gift", s.gear.size() == bag and not (s.flags.tianqi.get(XTianqi.JOIN_GIFTS_KEY, []) as Array).has(_w[2]))


func _guards() -> void:
	# 停用角色（143 初代萌王）不入队、不给
	var s := _state(_w)
	_join(s, 143)
	_check("disabled_not_joined", not s.party.has(143) and s.gear_count("armor", 140) == 0 and not (s.flags.tianqi.get(XTianqi.JOIN_GIFTS_KEY, []) as Array).has(143))
	# 号角仍不进背包（O-267 不变）
	s.gain_item(2946, 1)
	_check("horn_still_blocked", s.item_count(2946) == 0)
	# 开关关：不给
	XTianqi.JOIN_GIFTS = false
	var s2 := _state(_w)
	_join(s2, 177)
	_join(s2, 150)
	_check("switch_off_no_gift", s2.party.has(177) and _total(s2, "armor", 4048) == 0 and _total(s2, "weapon", 81) == 0
		and not s2.actor(150).skill_ids.has(1240) and not s2.flags.tianqi.has(XTianqi.JOIN_GIFTS_KEY))
	XTianqi.JOIN_GIFTS = true
	# 西游档零变化：同样 add_actor（不是号角），什么都不给、不记
	var x := XState.new_game_blank()
	XState.current = x
	var gear0 := x.gear.size()
	for id in [177, 84, 150, 71]:
		x.add_actor(id)
	_check("xiyou_no_gift", x.gear.size() == gear0 and _total(x, "armor", 4048) == 0 and _total(x, "armor", 4514) == 0 and _total(x, "weapon", 81) == 0
		and not x.actor(150).skill_ids.has(1240) and not x.actor(71).skill_ids.has(2498), [x.gear.size(), gear0])
	_check("xiyou_no_flag", not (x.flags.get("tianqi", {}) as Dictionary).has(XTianqi.JOIN_GIFTS_KEY))
	x.gain_item(1542, 1)
	_check("xiyou_horn_ok", x.item_count(1542) == 1, x.item_count(1542))  # 伙伴号角：蜘蛛精（非超强者，西游档照常能拿）
