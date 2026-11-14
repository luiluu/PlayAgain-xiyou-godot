extends Node
## 天启篇五条悟两次进阶与专属试炼（XTianqiGojoTrial，设计 v0.3；数值表 tianqi_data/gojo_trials.json）专项：
## 一、进阶表两行（25／55 级、10 万／50 万、无材料、学会分组）、茈 25／领域 55 级学、影子的招和状态补进表。
## 二、条件：只差试炼时可挑战、缺等级／金钱照常列；金钱不走金钱重构四阶价；别的角色、西游档不受影响。
## 三、单挑换队、输了恢复（队伍、生命魔法 TP 状态、不扣钱、可重打）、赢了恢复并扣钱进阶、存读档、读档还原进行中的试炼、旧四阶迁移。
## 四、怀玉每条机制：换成影子（外观、色调、无奖励）、出招表、每回合 2 次、天逆鉾破无下限并拆印、只有茈能打倒、领悟反转术式（留 1 点、回满、印满、一次）。
## 五、新宿每条机制：第 2 回合展开、回合末必中斩击（无下限挡不住）、领域对拼抵消斩击和无量空处的必中／信息过载、到期下一回合神灶：开、每 5 回合再开。
## 六、脚本化整场：25／55 级常规养成（只戴眼罩）会用机制能赢；不放茈打不倒甚尔、不开领域打不过宿傩。
## 七、开关：ENABLED 关回四阶表与 50／60 级、没有试炼；OWN_GOLD、SHADOW_TINT、RESTORE_ON_WIN 分项。

const GOJO := 180
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114)
	XTianqiSkills.reload()
	XGojo.unlock_override = 1
	_tables()
	_conditions()
	_solo_and_restore()
	_migrate()
	_disk_roundtrip()
	_huaiyu_mechanics()
	_huaiyu_last_resort()
	_xinsu_mechanics()
	_scripted()
	await _page_and_request()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 换开关后重建数据表（进阶行、职业习得、技能、状态在开表时补）
func _reload_tables() -> void:
	for n in ["Plugins", "Classes", "Skills", "States"]:
		XDB._tables.erase(n)
	XAdvance._rows = []


func _state(level := 25) -> XState:
	var w := XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2]]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	XState.current = s
	for id in lineup + [GOJO]:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 132
	var a: XActor = s.actor(GOJO)
	a.change_level(level)
	for id in [5548, 5980, 6168]:  # 真实开局借原版「普通」学的三个难度被动（结算 ×1.5×5×0.8、治疗 ×5）；不发被动的车道合并后学会被拦、改读表，强度一样
		a.learn_skill(id)
	a.recover_all()
	a.refresh_passive()
	return s


func _rows() -> Array:
	return XAdvance.rows().filter(func(r): return int(r.actor) == GOJO)


func _tables() -> void:
	var rows := _rows()
	_check("rows_two", rows.size() == 2, rows.size())
	if rows.size() == 2:
		_check("row1", int(rows[0].level) == 25 and int(rows[0].gold) == 100000 and (rows[0].items as Array).is_empty() and rows[0].learn == [1240, 1241, XGojo.ADV[2], XGojo.ADV[1]] and int(rows[0].max) == 2, rows[0])
		_check("row2", int(rows[1].level) == 55 and int(rows[1].gold) == 500000 and (rows[1].items as Array).is_empty() and rows[1].learn == [1242, 1244, XGojo.ADV[3], XGojo.ADV[0]], rows[1])
	var lv := {}
	for l in XDB.rec("Classes", XGojo.CLASS).learnings:
		lv[int(l.skillId)] = int(l.level)
	_check("learn_shift", lv.get(XGojo.PURPLE_IN) == 25 and lv.get(XGojo.PURPLE_OUT) == 25 and lv.get(XGojo.DOMAIN) == 55 and lv.get(XGojo.BLUE_MAX) == 30, lv)
	var names := []
	for id in range(XTianqiGojoTrial.FIRST_SKILL, XTianqiGojoTrial.LAST_SKILL + 1):
		names.append(str(XDB.rec("Skills", id).get("name", "")))
	_check("trial_skills", names == ["天逆鉾", "游云", "释魂刀", "解", "捌", "领域展开「伏魔御厨子」", "御厨子·斩击", "神灶：开"], names)
	_check("trial_states", str(XDB.rec("States", XTianqiGojoTrial.ST_SHRINE).get("name", "")) == "伏魔御厨子" and str(XDB.rec("States", XTianqiGojoTrial.ST_CLASH).get("name", "")) == "领域对拼")
	_check("trial_skill_module", str(XDB.rec("Skills", XTianqiGojoTrial.SPEAR).damage.formulaProgram.get("module", "")) == "gojo" and int(XDB.rec("Skills", XTianqiGojoTrial.SPEAR).hitType) == 0)
	_check("data_nice", not JSON.stringify(XTianqiGojoTrial.data().get("trials", {})).contains("4"), XTianqiGojoTrial.data().get("trials"))


func _conditions() -> void:
	var s := _state(25)
	var a: XActor = s.actor(GOJO)
	s.gold = 100000
	_check("pending_1", XTianqiGojoTrial.pending_tier(s, a) == 1)
	var miss := XAdvance.missing(s, a)
	_check("missing_only_trial", miss == ["试炼：怀玉"], miss)
	_check("challengeable", XTianqiGojoTrial.challengeable(s, a, miss) == 1)
	s.gold = 99999
	miss = XAdvance.missing(s, a)
	_check("missing_gold_too", miss.size() == 2 and XTianqiGojoTrial.challengeable(s, a, miss) == 0, miss)
	s.gold = 100000
	a.change_level(24)
	miss = XAdvance.missing(s, a)
	_check("missing_level_too", miss.size() == 2 and str(miss[0]).begins_with("等级24/25"), miss)
	a.change_level(25)
	_check("own_gold_rank0", int(XAdvance.row(s, GOJO).gold) == 100000)
	s.actor_advance[GOJO] = 1
	_check("own_gold_rank1", int(XAdvance.row(s, GOJO).gold) == 500000 and XTianqiGojoTrial.pending_tier(s, a) == 2, XAdvance.row(s, GOJO).gold)
	XTianqiGojoTrial.OWN_GOLD = false
	_check("own_gold_off", int(XAdvance.row(s, GOJO).gold) == XTianqiMoney.advance_gold(s, 1), [XAdvance.row(s, GOJO).gold, XTianqiMoney.advance_gold(s, 1)])
	XTianqiGojoTrial.OWN_GOLD = true
	s.actor_advance[GOJO] = 2
	_check("full_no_trial", XTianqiGojoTrial.pending_tier(s, a) == 0 and XAdvance.row(s, GOJO) == null)
	s.actor_advance.erase(GOJO)
	var other: XActor = s.actor(int(s.party[0]))
	_check("other_actor_untouched", XTianqiGojoTrial.lack(s, other).is_empty() and XTianqiGojoTrial.pending_tier(s, other) == 0)
	var plain := XState.new()
	_check("xiyou_untouched", not XTianqiGojoTrial.applies(plain, a) and XTianqiGojoTrial.lack(plain, a).is_empty())


func _solo_and_restore() -> void:
	var s := _state(25)
	var a: XActor = s.actor(GOJO)
	s.gold = 150000
	var party := s.party.duplicate()
	var slots := s.battle_slots.duplicate()
	a.hp = floorf(a.mhp * 0.7)
	a.mp = 33.0
	var hp0: float = a.hp
	_check("begin", XTianqiGojoTrial.begin(s, 1) and s.party == [GOJO] and s.battle_slots == [GOJO, 0, 0, 0, 0] and XTianqiGojoTrial.in_trial(s))
	_check("begin_once", not XTianqiGojoTrial.begin(s, 1))
	a.hp = 0.0
	a.add_state(1)
	a.mp = 0.0
	var note := XTianqiGojoTrial.finish(s, 2)
	_check("lose_text", note == XTianqiGojoTrial.TEXT_LOST, note)
	_check("lose_restore", s.party == party and s.battle_slots == slots and not XTianqiGojoTrial.in_trial(s) and a.hp == hp0 and a.mp == 33.0 and not a.is_dead(), [s.party, a.hp, hp0, a.mp])
	_check("lose_no_cost", s.gold == 150000 and XAdvance.rank(s, GOJO) == 0 and not XTianqiGojoTrial.has_passed(s, 1))
	XTianqiGojoTrial.begin(s, 1)
	note = XTianqiGojoTrial.finish(s, 1)
	_check("escape_same_as_lose", note == XTianqiGojoTrial.TEXT_LOST and XAdvance.rank(s, GOJO) == 0)
	XTianqiGojoTrial.begin(s, 1)
	a.hp = 5.0
	note = XTianqiGojoTrial.finish(s, 0)
	_check("win_text", note.contains("怀玉") and note.contains("一阶"), note)
	_check("win_advance", XAdvance.rank(s, GOJO) == 1 and s.gold == 50000 and XTianqiGojoTrial.has_passed(s, 1), [XAdvance.rank(s, GOJO), s.gold])
	_check("win_learn", [1240, 1241, XGojo.ADV[2], XGojo.ADV[1]].all(func(id): return a.skill_ids.has(id)) and not a.skill_ids.has(XGojo.ADV[3]))
	_check("win_restore", a.hp == hp0, [a.hp, hp0])
	var d := s.to_dict()
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check("save_roundtrip", XTianqiGojoTrial.has_passed(back, 1) and XAdvance.rank(back, GOJO) == 1 and XTianqiGojoTrial.pending_tier(back, back.actor(GOJO)) == 2,
		[XTianqiGojoTrial.passed(back), XAdvance.rank(back, GOJO), XTianqiGojoTrial.pending_tier(back, back.actor(GOJO)), back.flags.get("tianqi", {}).keys()])
	# 读档还原：存档里留着进行中的试炼
	XTianqiGojoTrial.begin(s, 2)
	var mid := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check("mid_saved", XTianqiGojoTrial.in_trial(mid) and mid.party == [GOJO])
	mid.actor(GOJO).hp = 3.0
	XTianqiGojoTrial.after_load(mid)
	_check("load_restores", not XTianqiGojoTrial.in_trial(mid) and mid.party == party and mid.actor(GOJO).hp == hp0, [mid.party, mid.actor(GOJO).hp, hp0])
	XTianqiGojoTrial.finish(s, 2)
	# 赢了但 RESTORE_ON_WIN 关：生命不回到战前
	s.gold = 600000
	a.change_level(55)
	XTianqiGojoTrial.RESTORE_ON_WIN = false
	XTianqiGojoTrial.begin(s, 2)
	a.hp = 7.0
	XTianqiGojoTrial.finish(s, 0)
	_check("restore_on_win_off", a.hp == 7.0 and XAdvance.rank(s, GOJO) == 2 and s.gold == 100000, [a.hp, XAdvance.rank(s, GOJO), s.gold])
	XTianqiGojoTrial.RESTORE_ON_WIN = true


func _migrate() -> void:
	var s := _state(72)
	var a: XActor = s.actor(GOJO)
	s.flags.tianqi.erase(XTianqiGojoTrial.MIGRATE_KEY)
	s.actor_advance[GOJO] = 3
	for id in [1240, 1241, 1242, XGojo.ADV[0], XGojo.ADV[1], XGojo.ADV[2]]:
		a.learn_skill(id)
	XTianqiGojoTrial.migrate(s)
	_check("migrate_rank", XAdvance.rank(s, GOJO) == 1 and XTianqiGojoTrial.passed(s) == [1], [XAdvance.rank(s, GOJO), XTianqiGojoTrial.passed(s)])
	_check("migrate_keep", [1240, 1241, 1242, XGojo.ADV[0], XGojo.ADV[1], XGojo.ADV[2]].all(func(id): return a.skill_ids.has(id)))
	XTianqiGojoTrial.migrate(s)
	_check("migrate_once", XAdvance.rank(s, GOJO) == 1)
	var s1 := _state(30)
	var a1: XActor = s1.actor(GOJO)
	s1.flags.tianqi.erase(XTianqiGojoTrial.MIGRATE_KEY)
	s1.actor_advance[GOJO] = 1
	a1.forget_skill(XGojo.PURPLE_IN)
	XTianqiGojoTrial.migrate(s1)
	_check("migrate_rank1_to_0", XAdvance.rank(s1, GOJO) == 0 and XTianqiGojoTrial.passed(s1).is_empty() and a1.skill_ids.has(XGojo.PURPLE_IN))


# ---- 真实写盘读档（XSave.save → load_slot → _load_data → after_load） ----

const SAVE_DIR := "user://test_xiyou_gojo_trials"


func _clean_dir() -> void:
	var d := DirAccess.open(SAVE_DIR)
	if d != null:
		for f in d.get_files():
			d.remove(f)


## 存到第 1 格再读回来，返回读回的当前状态
func _disk(s: XState) -> XState:
	XState.current = s
	var ok := XSave.save(1)
	var back := XSave.load_slot(1)
	if not ok or not back:
		_check("disk_io", false, [ok, back])
	return XState.current


func _learned(a: XActor, ids: Array) -> bool:
	return ids.all(func(id): return a.skill_ids.has(int(id)))


## 旧四阶表 v0.2 的学会（第 n 阶学超越极限 I～IV 和 ADV[n]）
const OLD_LEARN := [[1240, 10647], [1241, 10648], [1242, 10649], [1244, 10650]]


func _disk_roundtrip() -> void:
	XSave.dir_override = SAVE_DIR
	XConfig.path_override = SAVE_DIR.path_join("config.json")
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_clean_dir()
	# 新档：一阶后存读、二阶后存读，阶数、技能、金钱都不变，不会再付一次一阶
	var s := _state(25)
	_check("new_game_marked", int(s.flags.tianqi.get(XTianqiGojoTrial.MIGRATE_KEY, 0)) == XTianqiGojoTrial.TABLE_VERSION)
	s.gold = 700000
	XTianqiGojoTrial.begin(s, 1)
	XTianqiGojoTrial.finish(s, 0)
	var t1 := _disk(s)
	var a1: XActor = t1.actor(GOJO)
	_check("disk_tier1_rank", XAdvance.rank(t1, GOJO) == 1 and t1.gold == 600000 and XTianqiGojoTrial.passed(t1) == [1], [XAdvance.rank(t1, GOJO), t1.gold, XTianqiGojoTrial.passed(t1)])
	_check("disk_tier1_skills", _learned(a1, XTianqiGojoTrial.TIERS[0].learn))
	_check("disk_tier1_next_is_tier2", XTianqiGojoTrial.pending_tier(t1, a1) == 2 and int(XAdvance.row(t1, GOJO).level) == 55 and int(XAdvance.row(t1, GOJO).gold) == 500000)
	a1.change_level(55)
	XTianqiGojoTrial.begin(t1, 2)
	XTianqiGojoTrial.finish(t1, 0)
	var t2 := _disk(t1)
	_check("disk_tier2_rank", XAdvance.rank(t2, GOJO) == 2 and t2.gold == 100000 and XTianqiGojoTrial.passed(t2) == [1, 2], [XAdvance.rank(t2, GOJO), t2.gold])
	_check("disk_tier2_skills", _learned(t2.actor(GOJO), XTianqiGojoTrial.TIERS[0].learn + XTianqiGojoTrial.TIERS[1].learn))
	var t2b := _disk(t2)
	_check("disk_tier2_again", XAdvance.rank(t2b, GOJO) == 2 and t2b.gold == 100000 and XTianqiGojoTrial.pending_tier(t2b, t2b.actor(GOJO)) == 0 and XAdvance.row(t2b, GOJO) == null)
	# 旧四阶表的档（没有标记）：0～4 阶迁移成 0、0、1、1、2 阶；再存读不二次迁移
	for old in range(5):
		var o := _state(80)
		o.flags.tianqi.erase(XTianqiGojoTrial.MIGRATE_KEY)
		o.gold = 12345
		var oa: XActor = o.actor(GOJO)
		for i in range(old):
			for id in OLD_LEARN[i]:
				oa.learn_skill(id)
		if old > 0:
			o.actor_advance[GOJO] = old
		var m := _disk(o)
		var ma: XActor = m.actor(GOJO)
		var want := old / 2
		var keep := []
		for i in range(old):
			keep.append_array(OLD_LEARN[i])
		for i in range(want):
			keep.append_array(XTianqiGojoTrial.TIERS[i].learn)
		_check("disk_old%d_migrated" % old, XAdvance.rank(m, GOJO) == want and XTianqiGojoTrial.passed(m).size() == want and m.gold == 12345 and _learned(ma, keep)
			and int(m.flags.tianqi.get(XTianqiGojoTrial.MIGRATE_KEY, 0)) == XTianqiGojoTrial.TABLE_VERSION, [old, XAdvance.rank(m, GOJO), XTianqiGojoTrial.passed(m)])
		var m2 := _disk(m)
		_check("disk_old%d_once" % old, XAdvance.rank(m2, GOJO) == want and XTianqiGojoTrial.passed(m2).size() == want and m2.gold == 12345)
	# 本功能早期版本建的档（有试炼通过、没有标记）：阶数已是两阶表的，只补标记不折半
	var e := _state(55)
	e.flags.tianqi.erase(XTianqiGojoTrial.MIGRATE_KEY)
	e.flags.tianqi[XTianqiGojoTrial.PASSED_KEY] = [1]
	e.actor_advance[GOJO] = 1
	var eb := _disk(e)
	_check("disk_early_unmarked", XAdvance.rank(eb, GOJO) == 1 and XTianqiGojoTrial.pending_tier(eb, eb.actor(GOJO)) == 2)
	# 以标记为准：有两阶表标记的档，就算没有通过记录（调试工具改过阶数之类）也不折半
	var k := _state(55)
	k.actor_advance[GOJO] = 2
	var kb := _disk(k)
	_check("disk_marker_rules", XAdvance.rank(kb, GOJO) == 2 and XTianqiGojoTrial.passed(kb).is_empty(), XAdvance.rank(kb, GOJO))
	# 关开关读档：反迁移成旧四阶（×2、去标记）；再开读档折半回来
	XTianqiGojoTrial.ENABLED = false
	var off := _disk(eb)
	_check("disk_off_reverse", XAdvance.rank(off, GOJO) == 2 and int(off.flags.tianqi.get(XTianqiGojoTrial.MIGRATE_KEY, 0)) == XTianqiGojoTrial.OLD_VERSION, XAdvance.rank(off, GOJO))
	var off2 := _disk(off)
	_check("disk_off_once", XAdvance.rank(off2, GOJO) == 2)
	XTianqiGojoTrial.ENABLED = true
	var on := _disk(off)
	_check("disk_on_again", XAdvance.rank(on, GOJO) == 1 and int(on.flags.tianqi.get(XTianqiGojoTrial.MIGRATE_KEY, 0)) == XTianqiGojoTrial.TABLE_VERSION, XAdvance.rank(on, GOJO))
	# 五条悟中途入队的档也记上（老档读档时已先迁移）
	var j := _state(25)
	j.flags.tianqi.erase(XTianqiGojoTrial.MIGRATE_KEY)
	XGojo.on_join(j, GOJO)
	_check("join_marks", int(j.flags.tianqi.get(XTianqiGojoTrial.MIGRATE_KEY, 0)) == XTianqiGojoTrial.TABLE_VERSION)
	_clean_dir()
	XSave.dir_override = ""
	XConfig.path_override = ""


# ---- 战斗 ----

func _battle(s: XState, tier: int) -> XBattleLogic:
	XTianqiGojoTrial.begin(s, tier)
	XTianqiGojoTrial.prepare(tier)
	var lg := XBattleLogic.new()
	lg.setup(int(XTianqiGojoTrial.data().troop), s)
	return lg


func _huaiyu_mechanics() -> void:
	var s := _state(25)
	var a: XActor = s.actor(GOJO)
	var lg := _battle(s, 1)
	_check("h_active", XTianqiGojoTrial.active(lg) and lg.enemies.size() == 1 and lg.actors.size() == 1)
	var e: XEnemy = lg.enemies[0]
	_check("h_shadow", e.display_name() == "伏黑甚尔的影子" and str(e.data().meta.get("Sideview Battler", "")) == "Codex_Toji_SV" and XTianqiGojoTrial.is_shadow(lg, e))
	_check("h_tint", XTianqiGojoTrial.tint(e) != Color.WHITE and XTianqiGojoTrial.tint(a) == Color.WHITE)
	XTianqiGojoTrial.SHADOW_TINT = false
	_check("h_tint_off", XTianqiGojoTrial.tint(e) == Color.WHITE)
	XTianqiGojoTrial.SHADOW_TINT = true
	_check("h_appearance", XAppearance.for_battler(e) != null)
	_check("h_actions", XTianqiGojoTrial.action_times(lg, e) == 2 and XTianqiGojoTrial.action_times(lg, a) == 0 and lg.make_action_times(e) == 2)
	e.data().exp = 500
	e.data().gold = 500
	_check("h_rewards", lg.rewards() == {"exp": 0, "gold": 0, "drops": []}, lg.rewards())
	var gold0 := s.gold
	_check("h_grant_none", lg.grant({"exp": 999, "gold": 999, "drops": [{"kind": 1, "id": 1}]}) == [] and s.gold == gold0 and s.item_count(1) == 0, [s.gold, gold0])
	e.data().exp = 0
	e.data().gold = 0
	_check("h_fast", e.agi > a.agi)
	lg.turn = 1
	var seq := []
	for n in [1, 1, 2, 2, 3, 3]:
		lg.turn = n
		seq.append(int(lg.decide(e)[0].id))
	_check("h_schedule", seq == [XTianqiGojoTrial.SPEAR, XTianqiGojoTrial.CLOUD, XTianqiGojoTrial.CLOUD, XTianqiGojoTrial.CLOUD, XTianqiGojoTrial.SPEAR, XTianqiGojoTrial.SOUL], seq)
	# 天逆鉾：无下限挡不住，命中打掉多的那种印
	XGojo.temp(a).blue = 2
	XGojo.temp(a).red = 1
	var spear := XDB.rec("Skills", XTianqiGojoTrial.SPEAR)
	_check("h_spear_pierce", not XGojo.infinity_block(lg, e, spear, a) and XGojo.infinity_block(lg, e, XDB.rec("Skills", XTianqiGojoTrial.CLOUD), a))
	XGojo.temp(a).guard_round = -1
	XGojo.temp(a).blue = 2
	a.hp = a.mhp
	var r: Dictionary = lg.apply(e, spear, a)
	_check("h_spear_hits", not bool(r.evaded) and a.hp < a.mhp and XGojo.marks(a) == [1, 1], [r.get("evaded"), a.hp, XGojo.marks(a)])
	lg.apply(e, spear, a)
	_check("h_spear_tie_blue", XGojo.marks(a) == [0, 1], XGojo.marks(a))
	var dmg: float = a.mhp - a.hp
	var expect := float(XTianqiGojoTrial.fight(lg).base.mhp) * 0.1 * 2.0
	_check("h_spear_scale", dmg > expect * 0.5 and dmg < expect * 1.5, [dmg, expect])
	# 只有茈能打倒（走真实付伤链：horseman_strike → execute_hp_damage → 各倍率 → XResourceContext._gain）
	var red := XDB.rec("Skills", XGojo.RED)
	e.hp = 10.0
	XTianqiGojoTrial.fight(lg).queue = []
	var hit := lg.horseman_strike(a, e, red, 999999.0, false)
	_check("h_lock", e.hp == 1.0 and e.is_alive() and not hit.is_empty(), [e.hp, hit.get("hp")])
	lg.horseman_strike(a, e, red, 999999.0, false)
	_check("h_lock_any", e.hp == 1.0 and e.is_alive())
	_check("h_lock_said", XTianqiGojoTrial.fight(lg).held and XTianqiGojoTrial.take_logs(lg).size() == 1)
	# 直接写生命再判阵亡的路（种族伤害、七印行动外扣血、反弹、即死）：阵亡兜底
	e.hp = 0.0
	e.refresh_resources()
	_check("h_lock_direct_refresh", e.hp == 1.0 and e.is_alive(), e.hp)
	e.hp = 0.0
	lg._die(e)
	_check("h_lock_direct_die", e.hp == 1.0 and e.is_alive(), e.hp)
	e.add_state(1)
	_check("h_lock_instant_death", e.is_alive() and not e.state_ids.has(1))
	lg.gain_hp(e, -999999.0)
	_check("h_lock_gain", e.hp == 1.0 and e.is_alive())
	XGojo.cast = {"skill": XGojo.PURPLE_OUT}
	e.hp = 10.0
	lg.horseman_strike(a, e, XDB.rec("Skills", XGojo.PURPLE_OUT), 999999.0, false)
	_check("h_purple_kills", e.is_dead(), e.hp)
	XGojo.cast = {}
	e.remove_state(1)
	e.hp = e.mhp
	XGojo.cast = {"skill": XGojo.PURPLE_IN}
	e.hp = 0.0
	e.add_state(1)
	_check("h_purple_kills_direct", e.is_dead())
	XGojo.cast = {}
	e.remove_state(1)
	e.hp = e.mhp
	# 领悟反转术式：会被打死时留 1 点，回满、印满，只一次
	a.hp = 50.0
	XGojo.temp(a).blue = 0
	XGojo.temp(a).red = 1
	var soul := XDB.rec("Skills", XTianqiGojoTrial.SOUL)
	var cut := lg.horseman_strike(e, a, soul, 999999.0, false)
	_check("h_one_left", a.hp == 1.0 and a.is_alive() and not cut.is_empty(), [a.hp, cut.get("hp")])
	XGojo.after_hit(lg, a)
	_check("h_awaken", a.hp == a.mhp and XGojo.marks(a) == [3, 3] and XTianqiGojoTrial.fight(lg).awakened, [a.hp, a.mhp, XGojo.marks(a)])
	var said: Array = XGojo.finish(lg, e, soul)
	_check("h_awaken_lines", said.any(func(l): return str(l.get("text", "")).contains("天上天下")), said)
	a.hp = floorf(a.mhp * 0.1)
	XGojo.after_hit(lg, a)
	_check("h_awaken_once", a.hp == floorf(a.mhp * 0.1))
	lg.horseman_strike(e, a, soul, 999999.0, false)
	_check("h_can_die_after", a.is_dead())
	lg.end_battle(2)
	_check("h_end_clears", not XTianqiGojoTrial.active(lg))
	XTianqiGojoTrial.finish(s, 2)


## 返修 P2-2：觉醒前的致命保护在伤害链最末——戴最后一枚雷火弹（受到的伤害 +15%，在保护原来的位置之后乘）残血挨天逆鉾也留 1 点；
## 持续伤害、直接写生命的路也留 1 点，并在下一个行动开始时补领悟
func _huaiyu_last_resort() -> void:
	var s := _state(25)
	var a: XActor = s.actor(GOJO)
	var relic := XTianqiRewards.make_item("relic", "war", 0, false)
	s.register_gear(relic)
	s.gear.append(relic)
	var slot := a.equip_slots().find(int(relic.etypeId))
	_check("r_relic_worn", slot >= 0 and XEquipment.change(s, a, slot, relic) and not XTianqiRewards.relic_of(a).is_empty())
	var lg := _battle(s, 1)
	var e: XEnemy = lg.enemies[0]
	var spear := XDB.rec("Skills", XTianqiGojoTrial.SPEAR)
	a.hp = a.mhp
	var plain := XTianqiRewards.hp_damage(lg, e, a, 1000.0)
	_check("r_relic_amplifies", plain == 1150.0, plain)
	a.hp = 20.0
	var r: Dictionary = lg.apply(e, spear, a)
	_check("r_relic_survives_and_awakens", a.is_alive() and a.hp == a.mhp and XTianqiGojoTrial.fight(lg).awakened and not bool(r.get("evaded", false)), [a.hp, a.mhp, r.get("hp")])
	lg.end_battle(2)
	XTianqiGojoTrial.finish(s, 2)
	# 持续伤害（不经挨打）：留 1 点，下一个行动开始时领悟
	var s2 := _state(25)
	var a2: XActor = s2.actor(GOJO)
	var lg2 := _battle(s2, 1)
	var e2: XEnemy = lg2.enemies[0]
	a2.hp = 30.0
	lg2.gain_hp(a2, -999999.0)
	_check("r_dot_one_left", a2.hp == 1.0 and a2.is_alive() and not XTianqiGojoTrial.fight(lg2).awakened, a2.hp)
	XGojo.begin(lg2, e2, XDB.rec("Skills", XTianqiGojoTrial.CLOUD))
	_check("r_dot_awaken_next_action", XTianqiGojoTrial.fight(lg2).awakened and a2.hp == a2.mhp)
	# 有盾（返修第二轮）：盾先被打穿，落到生命上的才截成留 1 点
	var s5 := _state(25)
	var a5: XActor = s5.actor(GOJO)
	var lg5 := _battle(s5, 1)
	var e5: XEnemy = lg5.enemies[0]
	a5.hp = 100.0
	a5.shield = 100.0
	lg5.gain_hp(a5, -1000.0)
	_check("r_shield_direct", a5.shield == 0.0 and a5.hp == 1.0 and a5.is_alive(), [a5.shield, a5.hp])
	XGojo.begin(lg5, e5, XDB.rec("Skills", XTianqiGojoTrial.CLOUD))
	_check("r_shield_direct_awaken", XTianqiGojoTrial.fight(lg5).awakened and a5.hp == a5.mhp)
	e5.hp = 10.0
	e5.shield = 50.0
	lg5.gain_hp(e5, -1000.0)
	_check("r_shield_shadow", e5.shield == 0.0 and e5.hp == 1.0 and e5.is_alive(), [e5.shield, e5.hp])
	e5.hp = 500.0
	e5.shield = 300.0
	lg5.gain_hp(e5, -200.0)
	_check("r_shield_untouched_when_not_lethal", e5.shield == 100.0 and e5.hp == 500.0, [e5.shield, e5.hp])
	lg5.end_battle(2)
	XTianqiGojoTrial.finish(s5, 2)
	var s6 := _state(25)
	var a6: XActor = s6.actor(GOJO)
	var lg6 := _battle(s6, 1)
	# 再生率那条持续伤害（中毒）：原版先按「持续伤害不致死」夹到剩 1、再吸收护盾、直接写生命，本来打不死人，也不经过试炼的锁；
	# 这里断言有盾时试炼里的结算和关掉锁时一模一样（锁没改它）
	var dot := func(hp: float, shield: float) -> Array:
		a6.hp = hp
		a6.shield = shield
		lg6.turn_end_battler(a6, [])
		return [a6.hp, a6.shield]
	a6.add_state(4)  # 中毒：回合末最大生命 −10%
	var with_lock: Array = [dot.call(50.0, 30.0), dot.call(2.0, 3.0), dot.call(300.0, 20.0)]
	XTianqiGojoTrial.ENABLED = false
	var no_lock: Array = [dot.call(50.0, 30.0), dot.call(2.0, 3.0), dot.call(300.0, 20.0)]
	XTianqiGojoTrial.ENABLED = true
	_check("r_shield_dot", a6.state_ids.has(4) and with_lock == no_lock and with_lock[0][1] == 0.0 and with_lock[1][0] >= 1.0, [with_lock, no_lock])
	a6.hp = floorf(a6.mhp * 0.2)
	XGojo.begin(lg6, lg6.enemies[0], XDB.rec("Skills", XTianqiGojoTrial.CLOUD))
	_check("r_shield_dot_awaken", XTianqiGojoTrial.fight(lg6).awakened and a6.hp == a6.mhp)
	lg6.end_battle(2)
	XTianqiGojoTrial.finish(s6, 2)
	# 直接写生命再判阵亡（七印行动外扣血、异化词条临终那样）：觉醒前拦下
	var s3 := _state(25)
	var a3: XActor = s3.actor(GOJO)
	var lg3 := _battle(s3, 1)
	a3.hp = 0.0
	a3.refresh_resources()
	_check("r_direct_one_left", a3.hp == 1.0 and a3.is_alive(), a3.hp)
	a3.hp = 0.0
	lg3._state_add(a3, 1)
	_check("r_direct_death_blocked", a3.hp == 1.0 and not a3.state_ids.has(1))
	XTianqiGojoTrial.check_awaken(lg3)
	a3.hp = 0.0
	a3.refresh_resources()
	_check("r_direct_dies_after", a3.is_dead())
	lg3.end_battle(2)
	XTianqiGojoTrial.finish(s3, 2)
	# 新宿和别的战斗：没有这两道锁
	var s4 := _state(55)
	var a4: XActor = s4.actor(GOJO)
	var lg4 := _battle(s4, 2)
	a4.hp = 0.0
	a4.refresh_resources()
	_check("r_xinsu_no_lock", a4.is_dead())
	lg4.end_battle(2)
	XTianqiGojoTrial.finish(s4, 2)


func _xinsu_mechanics() -> void:
	var s := _state(55)
	var a: XActor = s.actor(GOJO)
	s.actor_advance[GOJO] = 1
	for id in XTianqiGojoTrial.TIERS[0].learn:
		a.learn_skill(int(id))
	a.refresh_passive()
	var lg := _battle(s, 2)
	var e: XEnemy = lg.enemies[0]
	var f := XTianqiGojoTrial.fight(lg)
	_check("x_shadow", e.display_name() == "两面宿傩的影子" and lg.make_action_times(e) == 1 and e.mdf > 0.0)
	lg.turn = 1
	_check("x_r1", int(lg.decide(e)[0].id) == XTianqiGojoTrial.DISMANTLE)
	lg.turn = 2
	var d2 := lg.decide(e)
	_check("x_r2_shrine", int(d2[0].id) == XTianqiGojoTrial.SHRINE and is_same(d2[1], e))
	XGojo.begin(lg, e, d2[0])
	_check("x_shrine_on", int(f.domain) == 3 and e.state_ids.has(XTianqiGojoTrial.ST_SHRINE) and not f.clash)
	# 回合末必中斩击：有苍印、无下限也挡不住
	XGojo.temp(a).blue = 3
	a.hp = a.mhp
	var logs := XGojo.end_round(lg)
	var cut: float = a.mhp - a.hp
	var expect := float(f.base.mhp) * float(XTianqiGojoTrial.trial(2).ratio.slash)
	_check("x_slash", cut > expect * 0.5 and cut < expect * 1.5 and XGojo.marks(a)[0] == 3, [cut, expect, XGojo.marks(a)])
	_check("x_slash_log", logs.any(func(l): return str(l.get("type", "")) == "hit"))
	_check("x_domain_tick", int(f.domain) == 2)
	# 领域对拼：五条悟展开无量空处
	lg.turn = 3
	XGojo.begin(lg, a, XDB.rec("Skills", XGojo.DOMAIN))
	_check("x_clash", bool(f.clash) and a.state_ids.has(XTianqiGojoTrial.ST_CLASH) and e.state_ids.has(XTianqiGojoTrial.ST_CLASH))
	_check("x_clash_no_sure", not XGojo.sure(a, XDB.rec("Skills", XGojo.RED)))
	var n := 0
	for i in range(100):
		n += 1 if XGojo.overload(lg, e) else 0
	_check("x_clash_no_overload", n == 0, n)
	XGojo.temp(a).blue = 0
	var before := XGojo.marks(a)
	_cast_blue(lg, a)
	_check("x_clash_marks_still", XGojo.marks(a)[1] == before[1] + 1, [before, XGojo.marks(a)])
	a.hp = a.mhp
	logs = XGojo.end_round(lg)
	_check("x_clash_cancels", a.hp == a.mhp and logs.any(func(l): return str(l.get("text", "")).contains("抵消")), a.hp)
	XGojo.end_round(lg)
	_check("x_shrine_ends", int(f.domain) == 0 and bool(f.fuga) and not e.state_ids.has(XTianqiGojoTrial.ST_SHRINE) and not f.clash and not a.state_ids.has(XTianqiGojoTrial.ST_CLASH))
	lg.turn = 5
	_check("x_fuga", int(lg.decide(e)[0].id) == XTianqiGojoTrial.FUGA)
	lg.turn = 6
	_check("x_cleave", int(lg.decide(e)[0].id) == XTianqiGojoTrial.CLEAVE)
	lg.turn = 7
	_check("x_shrine_again", int(lg.decide(e)[0].id) == XTianqiGojoTrial.SHRINE)
	# 无量空处不对拼时（宿傩领域没开）：信息过载按首领 15%
	f.domain = 0
	XTianqiGojoTrial.after_round(lg)
	n = 0
	for i in range(400):
		n += 1 if XGojo.overload(lg, e) else 0
	_check("x_overload_boss_rate", n > 20 and n < 110, n)
	lg.end_battle(2)
	XTianqiGojoTrial.finish(s, 2)


func _cast_blue(lg: XBattleLogic, a) -> void:
	var sk := XDB.rec("Skills", XGojo.BLUE)
	XGojo.begin(lg, a, sk)
	XGojo.finish(lg, a, sk)


# ---- 脚本化整场 ----

## 五条悟按策略选招；返回 {won, rounds, shadow_hp}
func _fight(s: XState, tier: int, policy: String) -> Dictionary:
	var lg := _battle(s, tier)
	var a: XActor = s.actor(GOJO)
	var e: XEnemy = lg.enemies[0]
	var rounds := 0
	for round_i in range(30):
		if lg.is_over():
			break
		rounds += 1
		lg.start_turn()
		var guard := 0
		while not lg.is_over():
			var u := lg.next_subject()
			if u == null:
				break
			guard += 1
			if guard > 20:
				break
			var cmd: Array = [_pick(lg, a, e, tier, policy), e] if u == a else lg.decide(u)
			lg.act(u, cmd[0], cmd[1])
		if lg.is_over():
			break
		lg.end_turn()
	var out := {"shadow_states": e.state_ids.duplicate(), "gojo_states": a.state_ids.duplicate(), "won": lg.is_won(), "lost": lg.is_lost(), "rounds": rounds, "awakened": XTianqiGojoTrial.fight(lg).get("awakened"), "held": XTianqiGojoTrial.fight(lg).get("held"), "shadow_hp": e.hp, "shadow_mhp": e.mhp, "gojo_hp": a.hp, "mhp": a.mhp}
	lg.end_battle(0 if lg.is_won() else 2)
	out.note = XTianqiGojoTrial.finish(s, 0 if out.won else 2)
	return out


func _ok(lg: XBattleLogic, a, id: int) -> bool:
	return a.skill_ids.has(id) and lg.can_use(a, XDB.rec("Skills", id))


func _pick(lg: XBattleLogic, a, e, tier: int, policy: String) -> Dictionary:
	var f := XTianqiGojoTrial.fight(lg)
	var pairs := XGojo.pairs(a)
	var last := str(XGojo.temp(a).last)
	if tier == 2 and policy == "smart" and int(f.domain) > 0 and not XGojo.active_domain(a) and _ok(lg, a, XGojo.DOMAIN):
		return XDB.rec("Skills", XGojo.DOMAIN)
	if a.hp < a.mhp * 0.5 and _ok(lg, a, XGojo.REVERSE):
		return XDB.rec("Skills", XGojo.REVERSE)
	var purple := XGojo.shape(a)
	var finish_ready: bool = tier == 1 and e.hp <= 1.0
	if policy != "no_purple" and pairs >= 1 and (pairs >= 3 or finish_ready) and _ok(lg, a, purple):
		return XDB.rec("Skills", purple)
	var order := [XGojo.RED_MAX, XGojo.RED, XGojo.BLUE_MAX, XGojo.BLUE] if last == "blue" else [XGojo.BLUE_MAX, XGojo.BLUE, XGojo.RED_MAX, XGojo.RED]
	for id in order:
		if _ok(lg, a, id):
			return XDB.rec("Skills", id)
	return XDB.rec("Skills", XGojo.STRIKE)


## 每种打法跑 SEEDS 个存档种子（新开局的种子本来随机，这里固定成 1～5）：会用机制的每个都要赢，不用机制的每个都要输
const SEEDS := 5


func _seeded(level: int, k: int) -> XState:
	var s := _state(level)
	s.random_master = XRandomStream.hex64(20261114 + k)
	s.battle_serial = 0
	return s


func _xinsu_ready(s: XState) -> void:
	var a: XActor = s.actor(GOJO)
	s.actor_advance[GOJO] = 1
	for id in XTianqiGojoTrial.TIERS[0].learn:
		a.learn_skill(int(id))
	a.refresh_passive()
	a.recover_all()


func _scripted() -> void:
	var stats := {"huaiyu_smart": [], "huaiyu_no_purple": [], "xinsu_smart": [], "xinsu_no_domain": []}
	var awakened := 0
	for k in range(SEEDS):
		var s1 := _seeded(25, k)
		var r1 := _fight(s1, 1, "smart")
		stats.huaiyu_smart.append(r1)
		awakened += 1 if bool(r1.awakened) else 0
		_check("huaiyu_smart_wins_%d" % k, r1.won and int(r1.rounds) >= 5 and int(r1.rounds) <= 20, r1)
		_check("huaiyu_win_marks_passed_%d" % k, XTianqiGojoTrial.has_passed(s1, 1) and XAdvance.rank(s1, GOJO) == 0 and r1.note == XTianqiGojoTrial.TEXT_PASSED % "怀玉", r1.note)  # 金钱不够：记通过、不进阶
		var r1b := _fight(_seeded(25, k), 1, "no_purple")
		stats.huaiyu_no_purple.append(r1b)
		_check("huaiyu_no_purple_fails_%d" % k, not r1b.won and float(r1b.shadow_hp) >= 1.0, r1b)
		var s2 := _seeded(55, k)
		_xinsu_ready(s2)
		var r2 := _fight(s2, 2, "smart")
		stats.xinsu_smart.append(r2)
		_check("xinsu_smart_wins_%d" % k, r2.won and int(r2.rounds) >= 6 and int(r2.rounds) <= 20, r2)
		var s2b := _seeded(55, k)
		_xinsu_ready(s2b)
		var r2b := _fight(s2b, 2, "no_domain")
		stats.xinsu_no_domain.append(r2b)
		_check("xinsu_no_domain_fails_%d" % k, not r2b.won and r2b.lost, r2b)
	_check("huaiyu_awakening_usual", awakened * 2 >= SEEDS, awakened)
	for key in stats:
		print("%s rounds=%s won=%s shadow_left=%s" % [key, str(stats[key].map(func(r): return r.rounds)), str(stats[key].map(func(r): return r.won)),
			str(stats[key].map(func(r): return snappedf(float(r.shadow_hp) / maxf(1.0, float(r.shadow_mhp)), 0.01)))])


## 假地图：start_battle 照真的建战斗（换不换影子看 XTianqiGojoTrial.setup），按 result 收场
class FakeHost extends Node:
	var result := 0
	var shadow_seen := false
	var solo := false
	var toasts := []

	func start_battle(troop: int, _can_escape: bool, _can_lose: bool) -> int:
		var lg := XBattleLogic.new()
		lg.setup(troop, XState.current)
		shadow_seen = XTianqiGojoTrial.active(lg) and lg.enemies.size() == 1
		solo = lg.actors.size() == 1
		lg.end_battle(result)
		await get_tree().process_frame
		return result

	func toast(text: String) -> void:
		toasts.append(text)


## 进阶界面：只差试炼时确认窗写「挑战试炼」、选是关页记请求；mv_script 接着 run_request 开战、还原、进阶
func _page_and_request() -> void:
	var s := _state(25)
	s.gold = 120000
	var a: XActor = s.actor(GOJO)
	var page := XActorAdvancedScene.new()
	add_child(page)
	await get_tree().process_frame
	var idx := page.members.find(a)
	page._select(idx)
	page.ok()
	page.ok()
	_check("page_confirm_trial", page.mode == "confirm" and page.confirm_text == "挑战试炼「怀玉」" and page.trial_tier == 1, [page.mode, page.confirm_text])
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.ok()
	_check("page_request", closed[0] and XTianqiGojoTrial.has_request() and s.gold == 120000 and XAdvance.rank(s, GOJO) == 0)
	page.queue_free()
	var host := FakeHost.new()
	add_child(host)
	var party := s.party.duplicate()
	host.result = 2
	var r: int = await XTianqiGojoTrial.run_request(host)
	_check("run_lose", r == 2 and host.shadow_seen and host.solo and s.party == party and s.gold == 120000 and not XTianqiGojoTrial.has_request() and host.toasts == [XTianqiGojoTrial.TEXT_LOST], [r, host.toasts])
	XTianqiGojoTrial.request(1)
	host.result = 0
	r = await XTianqiGojoTrial.run_request(host)
	_check("run_win", r == 0 and XAdvance.rank(s, GOJO) == 1 and s.gold == 20000 and s.party == party and str(host.toasts.back()).contains("通过"), [r, XAdvance.rank(s, GOJO), s.gold, host.toasts])
	XTianqiGojoTrial.request(1)
	_check("run_stale_request", await XTianqiGojoTrial.run_request(host) == -1)
	# 云裳天衣铺里打开的进阶页：不开试炼，照常提示缺什么
	s.actor_advance.erase(GOJO)
	XTianqiGojoTrial.passed(s)
	s.flags.tianqi[XTianqiGojoTrial.PASSED_KEY] = []
	var page2 := XActorAdvancedScene.new()
	page2.allow_trial = false
	add_child(page2)
	await get_tree().process_frame
	page2._select(page2.members.find(a))
	page2.ok()
	page2.ok()
	_check("page_no_trial_in_shop", page2.mode == "list" and page2.trial_tier == 0 and not XTianqiGojoTrial.has_request())
	page2.queue_free()
	host.queue_free()


func _switches() -> void:
	XTianqiGojoTrial.ENABLED = false
	_reload_tables()
	var rows := _rows()
	_check("off_rows_four", rows.size() == 4 and int(rows[0].level) == 50, rows.size())
	var lv := {}
	for l in XDB.rec("Classes", XGojo.CLASS).learnings:
		lv[int(l.skillId)] = int(l.level)
	_check("off_learn_old", lv.get(XGojo.PURPLE_IN) == 50 and lv.get(XGojo.DOMAIN) == 60, lv)
	var s := _state(50)
	var a: XActor = s.actor(GOJO)
	_check("off_no_trial", XTianqiGojoTrial.lack(s, a).is_empty() and XTianqiGojoTrial.pending_tier(s, a) == 0)
	XTianqiGojoTrial.prepare(1)
	var lg := XBattleLogic.new()
	lg.setup(int(XTianqiGojoTrial.data().troop), s)
	_check("off_no_shadow", not XTianqiGojoTrial.active(lg) and not lg.enemies.any(func(x): return x.display_name() == "伏黑甚尔的影子"))
	lg.end_battle(0)
	XTianqiGojoTrial.ENABLED = true
	XTianqiGojoTrial.LEARN_SHIFT = false
	_reload_tables()
	lv = {}
	for l in XDB.rec("Classes", XGojo.CLASS).learnings:
		lv[int(l.skillId)] = int(l.level)
	_check("learn_shift_off", lv.get(XGojo.PURPLE_IN) == 50 and _rows().size() == 2, lv)
	XTianqiGojoTrial.LEARN_SHIFT = true
	_reload_tables()
