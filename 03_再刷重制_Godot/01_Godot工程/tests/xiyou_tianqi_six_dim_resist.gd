extends Node
## 天启篇六维②韧性控制抗性（T276，卡 2）专项：XTianqiSixDim.control_state_rate 乘进 battle_logic.state_rate。
## 韧性档位全用测试里自设的（T280 正重算全员分数，不写死角色档位），控制抗性表照定稿 E−10 D−5 C0 B2 A5 S7 SS9 SSS10。
## 一、我方三档（S／C／E）乘数精确 93／100、100／100、110／100，效果 21 的命中门槛跟着变。
## 二、敌方 8 档乘数精确、命中门槛跟着变。
## 三、硬免控零冲突：四骑士、霸体首领、TRAIT_STATE_RESIST、TRAIT_STATE_RATE＝0，韧性 E 也一次都附不上。
## 四、非控制（中毒、流血、降防、死亡）不变；满烙印发作几率与发作回合开关开／关一致。
## 五、ENABLED＝false、西游档：state_rate 与原式（特性 × 词条）逐位一致，取随机数次数一致。

class FixStream extends XRandomStream:
	var floats := {}
	var default_float := 0.99
	var reasons := {}
	func _note(reason: String) -> void:
		draws += 1
		reasons[reason] = int(reasons.get(reason, 0)) + 1
	func next_float(reason: String, _event_key := "") -> float:
		_note(reason)
		return float(floats.get(reason, default_float))
	func next_uint(reason: String, _event_key := "") -> int:
		_note(reason)
		return 0
	func next_index_mod(_n: int, reason: String, _event_key := "") -> int:
		_note(reason)
		return 0
	func next_int_inclusive(lo: int, _hi: int, reason: String, _event_key := "") -> int:
		_note(reason)
		return lo

const PCT := {"E": -10, "D": -5, "C": 0, "B": 2, "A": 5, "S": 7, "SS": 9, "SSS": 10}

var results: Array = []
var _saved: Dictionary = {}
var CTL := 0  # 一个控制状态（boss_control_state）
var NONCTL: Array = []  # 中毒、流血、降防等非控制有害状态＋死亡
var _last_fs: FixStream = null


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(tianqi := true) -> XState:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(id).recover_all()
	return s


func _logic(tianqi := true, troop := 2) -> XBattleLogic:
	var s := _state(tianqi)
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _fix(lg: XBattleLogic, roll: float) -> FixStream:
	var fs := FixStream.new()
	fs.domain = "rule"
	fs.floats["add_state"] = roll
	lg.random.rule = fs
	return fs


## 自设韧性档（只改内存表，结尾还原）
func _set_actor(id: int, l: String) -> void:
	XTianqiSixDim.data().get("actors", {})[str(id)] = {"resolve": l}


func _set_enemy(id: int, l: String) -> void:
	XTianqiSixDim.data().get("enemies", {})[str(id)] = {"resolve": l}


func _set_knight(line: String, l: String) -> void:
	XTianqiSixDim.data().get("knights", {})[line] = {"resolve": l}


## 原式：特性 × 词条（T276 以前的 state_rate）
func _base(b: XBattler, id: int) -> float:
	return b.traits_pi(XBattler.TRAIT_STATE_RATE, id) * XTianqiAffixBattle.state_rate(b, id)


## 效果 21（指定状态、非必中）对 t 掷一次：roll 固定；返回附上没有
func _try(lg: XBattleLogic, u: XBattler, t: XBattler, id: int, v1: float, roll: float) -> bool:
	if t.state_ids.has(id):
		t.remove_state(id)
	_last_fs = _fix(lg, roll)
	var r := {"skill": {"id": 99999, "hitType": 1}, "added": []}
	lg._apply_effect(u, t, {"code": 21, "dataId": id, "value1": v1, "value2": 0.0}, r)
	var got := t.state_ids.has(id)
	if got:
		t.remove_state(id)
	return got


## 命中门槛：几率正下方必中、正上方必不中
func _edge(lg: XBattleLogic, u: XBattler, t: XBattler, id: int, v1: float) -> Array:
	var chance := v1 * lg.state_rate(t, id) * lg._luk_rate(u, t)
	return [chance, _try(lg, u, t, id, v1, chance * 0.999999), _try(lg, u, t, id, v1, chance * 1.000001)]


func _pick_states() -> void:
	var harmful_names := ["中毒", "流血", "防御下降", "降防", "灼伤"]
	for st in XDB.table("States"):
		if not st is Dictionary or st.is_empty():
			continue
		var id := int(st.get("id", 0))
		if id <= 1:
			continue
		if CTL == 0 and XEnemy.boss_control_state(id) and int(st.get("restriction", 0)) > 0:
			CTL = id
		var nm := str(st.get("name", ""))
		if not XEnemy.boss_control_state(id) and NONCTL.size() < 6 and harmful_names.any(func(n): return nm.contains(n)):
			NONCTL.append(id)
	NONCTL.append(1)  # 死亡


func _run() -> void:
	XMessageBox.auto = true
	seed(20261120)
	XTianqiSixDim.ENABLED = true
	_pick_states()
	_check("picked_states", CTL > 0 and NONCTL.size() >= 3, [CTL, NONCTL])
	var lg := _logic()
	_saved = XTianqiSixDim.data().duplicate(true)
	_actor_side(lg)
	_enemy_side(lg)
	_immune(lg)
	_non_control(lg)
	_brand()
	_off_and_legacy()
	XTianqiSixDim._data = _saved
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# 一、我方三档
func _actor_side(lg: XBattleLogic) -> void:
	var e: XEnemy = lg.enemies[0]
	var want := {"S": 93, "C": 100, "E": 110}
	var i := 0
	for l in want:
		var a: XActor = lg.actors[i]
		i += 1
		_set_actor(a.actor_id, l)
		var f := XTianqiSixDim.control_state_rate(a, CTL, lg)
		_check("actor_factor_" + l, f == float(want[l]) / 100.0, f)
		_check("actor_rate_" + l, lg.state_rate(a, CTL) == _base(a, CTL) * (float(want[l]) / 100.0), [lg.state_rate(a, CTL), _base(a, CTL)])
		var ed := _edge(lg, e, a, CTL, 0.5)
		_check("actor_edge_" + l, ed[1] and not ed[2], ed)
	# 门槛真跟着档位走：E 档 0.55 的门槛下 C 档附不上
	var a0: XActor = lg.actors[0]
	_set_actor(a0.actor_id, "E")
	var ce := 0.5 * lg.state_rate(a0, CTL) * lg._luk_rate(e, a0)
	_set_actor(a0.actor_id, "C")
	_check("actor_E_vs_C", not _try(lg, e, a0, CTL, 0.5, ce * 0.999999) or ce <= 0.0, ce)


# 二、敌方 8 档
func _enemy_side(lg: XBattleLogic) -> void:
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	var prev := 0.0
	var mono := true
	for l in XTianqiSixDim.LETTERS:
		_set_enemy(e.enemy_id, l)
		var want := float(100 - int(PCT[l])) / 100.0
		var f := XTianqiSixDim.control_state_rate(e, CTL, lg)
		_check("enemy_factor_" + l, f == want and XTianqiSixDim.control_resist_pct(e, lg) == int(PCT[l]), [f, want])
		_check("enemy_rate_" + l, lg.state_rate(e, CTL) == _base(e, CTL) * want, [lg.state_rate(e, CTL), _base(e, CTL)])
		var ed := _edge(lg, a, e, CTL, 0.5)
		_check("enemy_edge_" + l, ed[1] and not ed[2], ed)
		if prev > 0.0 and ed[0] >= prev:
			mono = false
		prev = ed[0]
	_check("enemy_monotonic_E_to_SSS", mono)
	XTianqiSixDim._data = _saved.duplicate(true)


# 三、硬免控
func _immune(lg: XBattleLogic) -> void:
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	_set_enemy(e.enemy_id, "E")
	_check("immune_setup_E", XTianqiSixDim.control_state_rate(e, CTL, lg) == 1.1)
	_check("immune_plain_hits", _try(lg, a, e, CTL, 1.0, 0.0))  # 对照：不免控的同一只照附
	# 霸体首领
	var was := [e.boss_difficulty_boss, e.boss_hyper_armor]
	e.boss_difficulty_boss = true
	e.boss_hyper_armor = true
	_check("immune_hyper_armor", not _try(lg, a, e, CTL, 1.0, 0.0))
	e.boss_difficulty_boss = was[0]
	e.boss_hyper_armor = was[1]
	# 特性：状态无效（TRAIT_STATE_RESIST）、状态有效度 0（TRAIT_STATE_RATE）
	var traits: Array = e.data().get("traits", [])
	var resist := {"code": XBattler.TRAIT_STATE_RESIST, "dataId": CTL, "value": 1.0}
	traits.append(resist)
	e.param_mark_dirty()
	_check("immune_trait_resist", e.traits_set(XBattler.TRAIT_STATE_RESIST).has(CTL) and not _try(lg, a, e, CTL, 1.0, 0.0))
	traits.erase(resist)
	var zero := {"code": XBattler.TRAIT_STATE_RATE, "dataId": CTL, "value": 0.0}
	traits.append(zero)
	e.param_mark_dirty()
	_check("immune_rate_zero", lg.state_rate(e, CTL) == 0.0 and not _try(lg, a, e, CTL, 1.0, 0.0), lg.state_rate(e, CTL))
	traits.erase(zero)
	e.param_mark_dirty()
	_check("immune_trait_restored", _try(lg, a, e, CTL, 1.0, 0.0))
	lg.end_battle()
	# 四骑士（骑士键自设 E）
	for line in XTianqiHorsemen.LINES:
		_set_knight(line, "E")
		var s := _state()
		XTianqiHorsemen.prepare(line, s)
		var kl := XBattleLogic.new()
		kl.setup(0, s)
		var kn: XEnemy = kl.enemies[0]
		_check("knight_is_" + line, XTianqiHorsemen.is_knight(kl, kn) and XTianqiSixDim.control_resist_pct(kn, kl) == -10, XTianqiSixDim.control_resist_pct(kn, kl))
		_check("knight_immune_" + line, not _try(kl, kl.actors[0], kn, CTL, 1.0, 0.0))
		kl.end_battle()
	XTianqiSixDim._data = _saved.duplicate(true)


# 四、非控制与烙印
func _non_control(lg: XBattleLogic) -> void:
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	for l in ["E", "SSS"]:
		_set_actor(a.actor_id, l)
		_set_enemy(e.enemy_id, l)
		for id in NONCTL:
			_check("nonctl_%s_%d" % [l, id], XTianqiSixDim.control_state_rate(a, id, lg) == 1.0 and XTianqiSixDim.control_state_rate(e, id, lg) == 1.0
				and lg.state_rate(a, id) == _base(a, id) and lg.state_rate(e, id) == _base(e, id))
	_check("nonctl_hyper_armor_state", XTianqiSixDim.control_state_rate(e, XEnemy.BOSS_ARMOR_STATE, lg) == 1.0)
	XTianqiSixDim._data = _saved.duplicate(true)


## 满烙印、韧性 E：开关开／关，发作几率、发作回合、发作花样一致（烙印走 forced_action，不经 state_rate）
func _brand_run(on: bool) -> Array:
	XTianqiSixDim.ENABLED = on
	var s := _state()
	for x in s.battle_members():
		XZhenqi.data(x)
		x.zhenqi["brand"] = 0
		x.zhenqi["brand_realm"] = 0
		x.zhenqi["brand_carved"] = 1
	var lg := XBattleLogic.new()
	lg.setup(1, s)
	XTianqiBrand.fight(lg)["ripe"] = false
	var a: XActor = lg.actors[0]
	_set_actor(a.actor_id, "E")
	var r := 0
	while r < XTianqiBrand.last_realm() and XTianqiBrand.node_of(r) <= 10000:
		r += 1
	a.zhenqi["brand"] = 10000
	a.zhenqi["brand_realm"] = r
	a.hp = a.mhp
	var fs := _fix(lg, 0.99)
	fs.floats["brand_fit"] = 0.1
	var chance := XTianqiBrand.fit_chance(lg, a)
	var forced := []
	for i in 6:
		lg.start_turn()
		var fa := lg.brand_forced(a)
		forced.append(str(fa[0].get(XTianqiBrand.FIT_KEY, "")) if not fa.is_empty() and fa[0] is Dictionary else "")
	var turns: Array = XTianqiBrand.fight(lg).get("fit_log", []).filter(func(x): return int(x.actor) == a.actor_id).map(func(x): return int(x.turn))
	lg.end_battle()
	XTianqiSixDim.ENABLED = true
	return [chance, turns, forced, fs.draws]


func _brand() -> void:
	var on := _brand_run(true)
	var off := _brand_run(false)
	_check("brand_has_fits", not (on[1] as Array).is_empty(), on)
	_check("brand_on_off_same", on == off, [on, off])
	XTianqiSixDim._data = _saved.duplicate(true)


# 五、开关关、西游档
func _off_and_legacy() -> void:
	var ids: Array = [CTL] + NONCTL
	var lg := _logic()
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	_set_actor(a.actor_id, "E")
	_set_enemy(e.enemy_id, "SSS")
	_try(lg, e, a, CTL, 0.5, 0.3)
	var draws_on := _last_fs
	XTianqiSixDim.ENABLED = false
	var ok := true
	for id in ids:
		for b in [a, e]:
			if XTianqiSixDim.control_state_rate(b, id, lg) != 1.0 or lg.state_rate(b, id) != _base(b, id):
				ok = false
	_check("off_bitwise", ok)
	_try(lg, e, a, CTL, 0.5, 0.3)
	var draws_off := _last_fs
	_check("off_same_draws", draws_on.draws == draws_off.draws and draws_on.draws > 0, [draws_on.draws, draws_off.draws])
	XTianqiSixDim.ENABLED = true
	lg.end_battle()
	var lgl := _logic(false)
	var la: XActor = lgl.actors[0]
	var le: XEnemy = lgl.enemies[0]
	_set_actor(la.actor_id, "E")
	_set_enemy(le.enemy_id, "E")
	ok = not XTianqiSixDim.active()
	for id in ids:
		for b in [la, le]:
			if XTianqiSixDim.control_state_rate(b, id, lgl) != 1.0 or lgl.state_rate(b, id) != _base(b, id):
				ok = false
	_check("legacy_bitwise", ok)
	lgl.end_battle()
	XState.current = null
	_check("nostate_neutral", XTianqiSixDim.control_state_rate(la, CTL) == 1.0 and XTianqiSixDim.control_state_rate(null, CTL) == 1.0)
