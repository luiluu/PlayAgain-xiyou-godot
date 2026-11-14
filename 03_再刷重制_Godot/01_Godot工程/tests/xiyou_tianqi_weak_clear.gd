extends Node
## 天启篇全弱者通关资格专项（XTianqiWeakClear）。
## 一、全弱者打赢 36 层决战：本档资格记上、别的档没有、结算有一行、成就 142 点亮、读档后还在、读档界面标「全弱者」。
## 二、输了、上场有强者、助力位是强者、战斗中换进强者（行动过再换回去、中途加入又撤下没行动、换上来没行动就倒下）、战斗中变档：不记。
## 五、战斗中断留下的跟踪：换了存档不记不收，下一次开战重置。
## 三、另开一档（寻常）：只记寻常，和艰险档互不影响。
## 四、原版弱者挑战在天启篇走不到；原版档一切照旧；开关关掉不记、成就开关关掉只记不点亮。

const DIR := "user://test_xiyou_tianqi_weak_clear"

class FakeHost extends RefCounted:
	var said: Array = []
	var results: Array = []
	var during := Callable()
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		return options.size() - 1
	func start_battle(_troop: int, _can_escape: bool, _can_lose: bool, _random := false) -> int:
		XTianqiHorsemen._pending = ""
		XTianqiHorsemen._pending_mode = "body"
		if during.is_valid():
			during.call()
		return int(results.pop_front()) if not results.is_empty() else 0


var results: Array = []
var weak: Array = []
var strong: Array = []


func _ready() -> void:
	XSave.dir_override = DIR
	XConfig.path_override = DIR.path_join("options.json")
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _usable(id) -> bool:
	return not XImportedBalance.is_disabled_actor(int(id)) and not XActorModules.IDS.has(int(id)) and int(id) != XGojo.ACTOR


## 天启篇存档（难度 diff，战争线开场已打完）；slots 是出战栏 5 格（第 5 格助力位）
func _state(diff: String, slots: Array) -> XState:
	var lineup := weak.slice(0, 5)
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup + slots:
		if not s.party.has(int(id)):
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	s.battle_slots = slots.duplicate()
	s.map_id = 4
	s.set_variable(20, 36)
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XState.current = s
	return s


func _run() -> void:
	XMessageBox.auto = true
	seed(20261113)
	XTianqiWarLine.reload()
	XTianqiHorsemen.reload()
	weak = XTianqiSkills.ids(XTier.WEAK, true).filter(_usable)
	strong = XTianqiSkills.ids(XTier.STRONG, true).filter(_usable)
	_check("pool", weak.size() >= 6 and strong.size() >= 1, [weak.size(), strong.size()])
	await _all_weak()
	await _not_weak()
	await _other_difficulty()
	await _legacy_and_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _all_weak() -> void:
	var s := _state("jianxian", weak.slice(0, 5))
	_check("lineup_weak", s.battle_members().size() == 4 and s.helper() != null
		and s.battle_members().all(func(a): return XTianqiWeakClear.is_weak(a.actor_id, s)) and XTianqiWeakClear.is_weak(s.helper().actor_id, s))
	var host := FakeHost.new()
	host.results = [2, 0]
	_check("lost_no_record", await XTianqiWarLine.run_final(host, s) == 2 and not XTianqiWeakClear.has(s))
	_check("lost_no_line", not host.said.any(func(t): return str(t).contains("全弱者通关")))
	_check("win", await XTianqiWarLine.run_final(host, s) == 0 and XTianqiWeakClear.has(s) and XTianqiWeakClear.has(s, "jianxian"))
	_check("only_this_difficulty", ["xunchang", "jiusi", "lianyu", "zhengdao"].all(func(k): return not XTianqiWeakClear.has(s, k)))
	var rec: Dictionary = s.flags.tianqi.weak_clear.jianxian
	var expect := weak.slice(0, 5)
	expect.sort()
	_check("record_members", rec.line == "war" and rec.members == expect, rec)
	_check("result_line", host.said.any(func(t): return str(t).contains("全弱者通关（本档）") and str(t).contains("艰险")), host.said)
	_check("achievement_142", s.achievements.get("142") == true)
	_check("no_global_weak_flag", not XConfig.flag(XWeakChallenge.CONFIG_KEY) and s.flags.get(XWeakChallenge.FLAG) != true)
	var d := s.to_dict()
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check("after_load", XTianqiWeakClear.has(back, "jianxian") and not XTianqiWeakClear.has(back, "xunchang"))
	_check("save_mark", XTianqiWeakClear.save_mark(d) == "　全弱者" and XTianqiWeakClear.save_mark(_state("jianxian", weak.slice(0, 5)).to_dict()) == "")
	# 再打一次：不重复记（成员不覆盖），结算照说一行
	host.said.clear()
	_check("second_win_keeps", await XTianqiWarLine.run_final(host, s) == 0 and s.flags.tianqi.weak_clear.size() == 1
		and host.said.any(func(t): return str(t).contains("全弱者通关")))


func _not_weak() -> void:
	var host := FakeHost.new()
	# 上场有一名强者
	var slots := weak.slice(0, 5)
	slots[1] = strong[0]
	var s := _state("jianxian", slots)
	_check("fighter_strong", await XTianqiWarLine.run_final(host, s) == 0 and not XTianqiWeakClear.has(s))
	# 助力位是强者
	slots = weak.slice(0, 4) + [strong[0]]
	s = _state("jianxian", slots)
	_check("helper_strong", await XTianqiWarLine.run_final(host, s) == 0 and not XTianqiWeakClear.has(s))
	# 战斗中换进强者：开战全弱者，打到一半助力位换成强者、换上场行动一回合，再换回去——结束时又是全弱者，也不记
	s = _state("jianxian", weak.slice(0, 5))
	var acted := {}
	host.during = func():
		var lg := XBattleLogic.new()
		lg.setup(1, s)
		var w: XActor = s.helper()
		XTianqi._joining = true
		s.add_actor(int(strong[0]))  # 中途入队的强者
		XTianqi._joining = false
		s.battle_slots[XTianqi.HELPER_SLOT] = int(strong[0])
		var st: XActor = lg.tianqi_swap(lg.actors[0])
		var c := {}
		for a in lg.actors:
			c[a] = [XDB.rec("Skills", 2), null]
		lg.run_turn(c)
		acted["seen"] = XTianqiWeakClear._seen.has(int(strong[0]))
		acted["swap"] = st != null and int(st.actor_id) == int(strong[0])
		acted["back"] = lg.tianqi_swap(st) != null
		s.battle_slots[XTianqi.HELPER_SLOT] = w.actor_id  # 强者再从助力位撤下（结束时出战栏又是开战时的 5 个弱者）
		lg.end_battle(0)
	_check("swap_in_strong", await XTianqiWarLine.run_final(host, s) == 0 and not XTianqiWeakClear.has(s), acted)
	_check("swap_seen_by_action", acted.get("swap") == true and acted.get("seen") == true and acted.get("back") == true, acted)
	_check("swap_back_all_weak", s.battle_members().all(func(a): return XTianqiWeakClear.is_weak(a.actor_id, s))
		and not s.battle_slots.has(int(strong[0])), s.battle_slots)
	# 战斗中强者入队进了助力位、没上场没行动：结束时出战栏有他，不记
	s = _state("jianxian", weak.slice(0, 5))
	host.during = func():
		XTianqi._joining = true
		s.add_actor(int(strong[0]))
		XTianqi._joining = false
		s.battle_slots[XTianqi.HELPER_SLOT] = int(strong[0])
	_check("join_helper_mid_battle", await XTianqiWarLine.run_final(host, s) == 0 and not XTianqiWeakClear.has(s))
	# gpt 甲档核查 P2：中途加入又撤下、没行动（助力位不行动也在吃光环）——每回合开头记出战栏
	s = _state("jianxian", weak.slice(0, 5))
	var seen_turn := {}
	host.during = func():
		var lg := XBattleLogic.new()
		lg.setup(1, s)
		var w: XActor = s.helper()
		XTianqi._joining = true
		s.add_actor(int(strong[0]))
		XTianqi._joining = false
		s.battle_slots[XTianqi.HELPER_SLOT] = int(strong[0])
		var c := {}
		for a in lg.actors:
			c[a] = [XDB.rec("Skills", 2), null]
		lg.run_turn(c)
		seen_turn["acted"] = lg.actors.any(func(a): return a is XActor and int(a.actor_id) == int(strong[0]))
		s.battle_slots[XTianqi.HELPER_SLOT] = w.actor_id
		lg.end_battle(0)
	_check("join_then_leave_no_action", await XTianqiWarLine.run_final(host, s) == 0 and not XTianqiWeakClear.has(s)
		and seen_turn.get("acted") == false and not s.battle_slots.has(int(strong[0])), seen_turn)
	# 换上来没行动就倒下、再撤走——换人那一刻记
	s = _state("jianxian", weak.slice(0, 5))
	var sw := {}
	host.during = func():
		var lg := XBattleLogic.new()
		lg.setup(1, s)
		var w: XActor = s.helper()
		XTianqi._joining = true
		s.add_actor(int(strong[0]))
		XTianqi._joining = false
		s.battle_slots[XTianqi.HELPER_SLOT] = int(strong[0])
		var st: XActor = lg.tianqi_swap(lg.actors[0])
		sw["in"] = st != null and int(st.actor_id) == int(strong[0])
		if st != null:
			st.hp = 0
			sw["dead"] = st.is_dead()
			sw["back"] = lg.tianqi_swap(st) != null
		s.battle_slots[XTianqi.HELPER_SLOT] = w.actor_id
		lg.end_battle(0)
	_check("swap_in_dead_no_action", await XTianqiWarLine.run_final(host, s) == 0 and not XTianqiWeakClear.has(s)
		and sw.get("in") == true and sw.get("dead") == true and sw.get("back") == true and not s.battle_slots.has(int(strong[0])), sw)
	# 战斗中变档：三笠（95）锻炼没满是弱者，打到一半满了（强者）再改回去——见到时按当时档位记
	var mk := 95
	var tier_slots := weak.slice(0, 4) + [mk]
	s = _state("jianxian", tier_slots)
	s.set_variable(1490, 0)
	var tw := {"start_weak": XTianqiWeakClear.is_weak(mk, s)}
	host.during = func():
		var lg := XBattleLogic.new()
		lg.setup(1, s)
		s.set_variable(1490, 10)
		tw["mid_strong"] = not XTianqiWeakClear.is_weak(mk, s)
		var c := {}
		for a in lg.actors:
			c[a] = [XDB.rec("Skills", 2), null]
		lg.run_turn(c)
		s.set_variable(1490, 0)
		lg.end_battle(0)
	_check("tier_change_mid_battle", await XTianqiWarLine.run_final(host, s) == 0 and not XTianqiWeakClear.has(s)
		and tw.get("start_weak") == true and tw.get("mid_strong") == true and XTianqiWeakClear.is_weak(mk, s), tw)
	# 对照：同样阵容全程没变档就记
	var s3 := _state("jianxian", tier_slots)
	s3.set_variable(1490, 0)
	host.during = Callable()
	_check("tier_steady_records", await XTianqiWarLine.run_final(host, s3) == 0 and XTianqiWeakClear.has(s3))
	host.during = Callable()
	# 再挑战 36 层（不记通关）不算
	var s2 := _state("jianxian", weak.slice(0, 5))
	XTianqiSummit.progress(s2)["cleared"] = true
	await XTianqiSummit.rechallenge(host, s2, 36)
	_check("rechallenge_not_counted", not XTianqiWeakClear.has(s2))


func _other_difficulty() -> void:
	var host := FakeHost.new()
	var s := _state("xunchang", weak.slice(0, 5))
	_check("xunchang_win", await XTianqiWarLine.run_final(host, s) == 0 and XTianqiWeakClear.has(s, "xunchang") and not XTianqiWeakClear.has(s, "jianxian"))
	_check("xunchang_line", host.said.any(func(t): return str(t).contains("寻常")))


func _legacy_and_switches() -> void:
	# 战斗中断（run_final 没走到 finish）：跟踪绑着旧存档，换了存档不记、不能收；下一次 begin 重置
	var old := _state("jianxian", weak.slice(0, 5))
	XTianqiWeakClear.begin(old)
	var fresh := _state("jiusi", weak.slice(0, 5))
	XTianqiWeakClear.note_slots(fresh)
	var sh := FakeHost.new()
	_check("stale_other_save", XTianqiWeakClear._live(old) and not XTianqiWeakClear._live(fresh)
		and not await XTianqiWeakClear.finish(sh, fresh, 0) and not XTianqiWeakClear.has(fresh) and sh.said.is_empty())
	XTianqiWeakClear.begin(old)
	var slots := weak.slice(0, 5)
	slots[0] = strong[0]
	var s0 := _state("jianxian", slots)
	XTianqiWeakClear.begin(s0)
	var w2 := _state("jianxian", weak.slice(0, 5))
	_check("stale_reset_by_begin", await XTianqiWarLine.run_final(sh, w2) == 0 and XTianqiWeakClear.has(w2)
		and not XTianqiWeakClear._tracking and XTianqiWeakClear._seen.is_empty())
	# 原版弱者挑战：天启篇存档的难度号到不了混沌（9），Map157／敌群 469 也不判
	var s := _state("zhengdao", weak.slice(0, 5))
	s.map_id = XWeakChallenge.FINAL_MAP
	XWeakChallenge.battle_setup(s, XWeakChallenge.FINAL_TROOP)
	_check("legacy_unreachable", s.difficulty != XWeakChallenge.CHAOS and XWeakChallenge.final_battle == null, s.difficulty)
	XWeakChallenge.final_battle = null
	# 原版档：不判、不记、行动不记
	var p := XState.new_game_blank()
	for id in weak.slice(0, 5):
		p.add_actor(int(id))
	XState.current = p
	XTianqiWeakClear.begin(p)
	var lg := XBattleLogic.new()
	lg.setup(1, p)
	var c := {}
	for a in lg.actors:
		c[a] = [XDB.rec("Skills", 2), null]
	lg.run_turn(c)
	_check("plain_not_tracked", not XTianqiWeakClear._tracking and XTianqiWeakClear._seen.is_empty())
	lg.end_battle(0)
	var ph := FakeHost.new()
	_check("plain_finish", not await XTianqiWeakClear.finish(ph, p, 0) and not XTianqiWeakClear.has(p) and ph.said.is_empty()
		and not p.flags.has("tianqi"))
	_check("plain_save_mark", XTianqiWeakClear.save_mark(p.to_dict()) == "")
	# 开关关掉：不记、读档界面不标
	var host := FakeHost.new()
	s = _state("jiusi", weak.slice(0, 5))
	XTianqiWeakClear.ENABLED = false
	_check("switch_off", await XTianqiWarLine.run_final(host, s) == 0 and not s.flags.tianqi.has("weak_clear")
		and not host.said.any(func(t): return str(t).contains("全弱者通关")))
	XTianqiWeakClear.ENABLED = true
	s.flags.tianqi["weak_clear"] = {"jiusi": {}}
	XTianqiWeakClear.ENABLED = false
	_check("switch_off_save_mark", XTianqiWeakClear.save_mark(s.to_dict()) == "")
	XTianqiWeakClear.ENABLED = true
	# 成就开关关掉：只记资格，不点亮 142
	s = _state("lianyu", weak.slice(0, 5))
	s.achievements.erase("142")
	XTianqiWeakClear.ACHIEVEMENT = false
	_check("achievement_off", await XTianqiWarLine.run_final(host, s) == 0 and XTianqiWeakClear.has(s, "lianyu") and not s.achievements.has("142"))
	XTianqiWeakClear.ACHIEVEMENT = true
