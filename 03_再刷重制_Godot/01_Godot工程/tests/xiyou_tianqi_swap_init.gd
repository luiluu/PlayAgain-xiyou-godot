extends Node
## 审查 78 P3-1（XTianqi.SWAP_INIT）：战斗中换上来的助力位补开战初始化——初始 TP、技能预热重置、开战状态标签、种族本场数据；
## 心钢蓄力开战时就按全队（含助力位）建了；开关关掉照第二批什么都不补。

const START_SKILL := 5548  # 普通难度：<StartPushState1631: 100%>
const START_STATE := 1631

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _logic() -> XBattleLogic:
	var w := _ids(XTier.WEAK)
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(id).recover_all()
	var h := s.helper()
	if not h.skill_ids.has(START_SKILL):
		h.learn_skill(START_SKILL)
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _run() -> void:
	XMessageBox.auto = true
	seed(20261111)
	_swap(true)
	_swap(false)
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _swap(on: bool) -> void:
	XTianqi.SWAP_INIT = on
	var tag := "on" if on else "off"
	var lg := _logic()
	var s := lg.state
	var h := s.helper()
	_check("fixture_%s" % tag, h != null and not lg.actors.has(h) and h.battle_start_state_tags().any(func(t): return int(t[1]) == START_STATE))
	h.remove_state(START_STATE)
	h.tp = 80.0
	h.warmups = {999999: 5.0}
	var store: Dictionary = lg.get_meta("xrace", {}).get("actors", {})
	_check("race_absent_before_%s" % tag, not store.has(h))
	_check("heartsteel_built_%s" % tag, XHeartsteel._wait.has(h.actor_id))
	var out: XActor = lg.actors[0]
	var got := lg.tianqi_swap(out)
	_check("swapped_%s" % tag, got == h and lg.actors.has(h))
	if on:
		_check("tp_reset", h.is_preserve_tp() or h.tp < 25.0, h.tp)
		_check("warmups_reset", not h.warmups.has(999999), h.warmups)
		_check("start_state", h.state_ids.has(START_STATE), h.state_ids)
		_check("race_built", lg.get_meta("xrace").actors.has(h))
	else:
		_check("off_tp_kept", h.tp == 80.0, h.tp)
		_check("off_warmups_kept", h.warmups.has(999999), h.warmups)
		_check("off_no_start_state", not h.state_ids.has(START_STATE), h.state_ids)
	XTianqi.SWAP_INIT = true
