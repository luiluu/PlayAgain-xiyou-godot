extends Node
## 全弱者证道编队规则（D57／D76／D77，XTianqi.HELPER_RULES，O-513）：
## 一、数值表：超强者上场上限 0／0／1／2／2，只有证道 helper_super。
## 二、整队页 can_deploy：各难度上场上限、助力位只有证道能放超强者、整栏模拟（非超强者挪进助力位把超强者顶上场的漏洞）、slot<0。
## 三、翻页键两格对调 can_swap_slots。
## 四、enforce_party 旧档迁移：九死／炼狱／艰险助力位超强者清走；证道上场 3（4）个超强者挪助力位或去替补；幂等、不丢人、提示。
## 五、随机阵容 roll_lineup／lineup_ok：每档 1000 次不变量、证道最多 3 个（第 3 个在第 5 位）、确定性排位、同种子复现、开局入队后出战栏。
## 六、战斗中换人 can_tianqi_swap：证道满 2 超时助力位超强者不能换下强者（换下的强者倒下也一样）、超↔超可以、强换超可以；九死防守。
## 七、开关回退。

var results: Array = []
var w: Array = []
var sup: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTianqiSkills.ids(tier, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and not [95, 173].has(id))


## key 难度的天启篇存档：开局 5 人（w0～w4）入队，再收 extra（超强者等）进队伍；出战栏照 slots 直接写（模拟旧档）
func _state(key: String, extra: Array, slots: Array) -> XState:
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		s.add_actor(int(id))
	XTianqi._joining = true
	for id in extra:
		s.add_actor(int(id))
	XTianqi._joining = false
	s.map_id = 4
	s.battle_slots = slots.duplicate()
	s._rearrange_actors()  # 旧档里 party 已按出战栏排好（出战栏在前、其余按编号）
	XState.current = s
	return s


func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func _run() -> void:
	XMessageBox.auto = true
	XSave.dir_override = "user://test_xiyou_tianqi_zhengdao_party"
	w = _ids(XTier.WEAK)
	sup = _ids(XTier.SUPER)
	_check("fixture", w.size() >= 7 and sup.size() >= 4, [w.size(), sup.size()])
	_table()
	_deploy()
	_swap_slots()
	_enforce()
	_lineups()
	_battle_swap()
	_rollback()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 一、数值表
func _table() -> void:
	var want := {"xunchang": [0, false], "jianxian": [0, false], "jiusi": [1, false], "lianyu": [2, false], "zhengdao": [2, true]}
	for k in want:
		var d := XTianqi.difficulty(k)
		_check("table_" + k, int(d.super_cap) == want[k][0] and bool(d.helper_super) == want[k][1]
			and XTianqiBalance.difficulty(k).get("helper_super") == want[k][1] and XTianqi.helper_super_key(k) == want[k][1], d)
	_check("lineup_super_max", XTianqi.lineup_super_max("zhengdao") == 3 and XTianqi.lineup_super_max("lianyu") == 2
		and XTianqi.lineup_super_max("jiusi") == 1 and XTianqi.lineup_super_max("xunchang") == 0)
	_check("helper_ok_legacy", XTianqi.helper_super_ok(XState.new_game_blank()))


## 二、整队页 can_deploy
func _deploy() -> void:
	# 寻常、艰险：超强者哪都放不进
	for k in ["xunchang", "jianxian"]:
		var s := _state(k, [sup[0]], [w[0], w[1], w[2], w[3], w[4]])
		_check("deploy_%s_none" % k, range(5).all(func(i): return not XItemMarks.can_deploy(s, sup[0], i)) and not XItemMarks.can_deploy(s, sup[0]),
			range(5).map(func(i): return XItemMarks.can_deploy(s, sup[0], i)))
	# 九死：上场 1 个，助力位不行
	var j := _state("jiusi", [sup[0], sup[1]], [sup[0], w[1], w[2], w[3], w[4]])
	_check("deploy_jiusi_field_full", not XItemMarks.can_deploy(j, sup[1], 1) and XItemMarks.can_deploy(j, sup[1], 0))
	_check("deploy_jiusi_helper_no", not XItemMarks.can_deploy(j, sup[1], 4) and not XItemMarks.can_deploy(j, sup[0], 4))
	_check("deploy_jiusi_any", XItemMarks.can_deploy(j, sup[1]) and XItemMarks.can_deploy(j, w[5] if j.party.has(w[5]) else w[1], 4))
	# 炼狱：上场 2 个，助力位不行
	var l := _state("lianyu", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], w[4]])
	_check("deploy_lianyu", not XItemMarks.can_deploy(l, sup[2], 2) and XItemMarks.can_deploy(l, sup[2], 1)
		and not XItemMarks.can_deploy(l, sup[2], 4) and not XItemMarks.can_deploy(l, sup[1], 4))
	# 证道：上场 2 个，助力位能放
	var z := _state("zhengdao", [sup[0], sup[1], sup[2], sup[3], w[5]], [sup[0], sup[1], w[2], w[3], w[4]])
	_check("deploy_zhengdao_helper", XItemMarks.can_deploy(z, sup[2], 4) and not XItemMarks.can_deploy(z, sup[2], 2))
	z.battle_slots = [sup[0], sup[1], w[2], w[3], sup[2]]
	# 漏洞：非超强者挪进助力位会把助力位的超强者顶到他原来的上场格（3 超）
	_check("deploy_swap_leak_plain", not XItemMarks.can_deploy(z, w[2], 4) and not XItemMarks.can_deploy(z, w[3], 4), z.battle_slots)
	_check("deploy_swap_leak_super", not XItemMarks.can_deploy(z, sup[2], 2) and XItemMarks.can_deploy(z, sup[2], 0))
	_check("deploy_reserve_to_helper", XItemMarks.can_deploy(z, w[5], 4) and XItemMarks.can_deploy(z, sup[3], 4)
		and not XItemMarks.can_deploy(z, sup[3], 2) and XItemMarks.can_deploy(z, sup[3], 1))
	_check("deploy_remove_ok", XItemMarks.can_deploy(z, 0, 4) and XItemMarks.can_deploy(z, 0, 0))
	_check("deploy_bad_slot", not XItemMarks.can_deploy(z, w[5], 5) and not XItemMarks.can_deploy(z, w[5], 9))
	_check("deploy_not_in_party", not XItemMarks.can_deploy(z, w[6], 4) and not XItemMarks.can_deploy(z, w[6]) and not z.party.has(w[6]))
	_check("deploy_full_field_super_swap", XItemMarks.can_deploy(z, sup[0], 1) and XItemMarks.can_deploy(z, sup[1], 0) and XItemMarks.can_deploy(z, sup[2], 4))
	# 非天启篇存档：照原版 canDeploy（不按整栏、不看助力位）
	var old := XState.new_game_blank()
	_check("deploy_legacy", XItemMarks.can_deploy(old, w[0], 4) == XItemMarks.can_acquire_actor(old, w[0])
		and XItemMarks.can_deploy(old, sup[0], 4) == XItemMarks.can_acquire_actor(old, sup[0]))
	_check("deploy_readonly", z.battle_slots == [sup[0], sup[1], w[2], w[3], sup[2]], z.battle_slots)


## 三、翻页键对调
func _swap_slots() -> void:
	var z := _state("zhengdao", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], sup[2]])
	_check("swap_zhengdao", not XItemMarks.can_swap_slots(z, 3, 4) and not XItemMarks.can_swap_slots(z, 4, 2)
		and XItemMarks.can_swap_slots(z, 0, 4) and XItemMarks.can_swap_slots(z, 2, 3))
	var j := _state("jiusi", [sup[0]], [sup[0], w[1], w[2], w[3], w[4]])
	_check("swap_jiusi", not XItemMarks.can_swap_slots(j, 0, 4) and XItemMarks.can_swap_slots(j, 3, 4) and XItemMarks.can_swap_slots(j, 0, 1))
	_check("swap_overflow_slot", not XItemMarks.can_swap_slots(j, 5, 3) and not XItemMarks.can_swap_slots(j, 3, 5))
	_check("swap_negative_slot", not XItemMarks.can_swap_slots(j, -1, 3) and not XItemMarks.can_swap_slots(j, 3, -1))
	# 整队页翻页键：被拦时蜂鸣、出战栏不变
	var page := XPartyScene.new()
	add_child(page)
	page.mode = "slot"
	page.slot_index = 0
	var before := j.battle_slots.duplicate()
	XSound.system_log.clear()
	page.page(-1)  # 第 0 格和第 4 格（助力位）对调：超强者进助力位
	_check("swap_page_blocked", XSound.system_log.has(3) and j.battle_slots == before and page.slot_index == 0, [XSound.system_log, j.battle_slots])
	page.slot_index = 3
	page.page(1)
	_check("swap_page_ok", j.battle_slots[4] == w[3] and j.battle_slots[3] == w[4] and page.slot_index == 4, j.battle_slots)
	page.queue_free()


## 四、enforce_party 旧档迁移
func _enforce() -> void:
	# 艰险：上限 0，助力位超强者也清
	var jx := _state("jianxian", [sup[0]], [w[0], w[1], w[2], w[3], sup[0]])
	_check("enf_jianxian", XItemMarks.enforce_party(jx) and jx.battle_slots == [w[0], w[1], w[2], w[3], w[4]], jx.battle_slots)
	# 九死旧档：助力位超强者→替补，助力位补一个非超强者
	var j := _state("jiusi", [sup[0], sup[1]], [sup[0], w[1], w[2], w[3], sup[1]])
	var party_before := _sorted(j.party)
	_check("enf_jiusi", XItemMarks.enforce_party(j) and j.battle_slots.slice(0, 4) == [sup[0], w[1], w[2], w[3]] and [w[0], w[4]].has(j.battle_slots[4]), j.battle_slots)
	var j_after := j.battle_slots.duplicate()
	_check("enf_jiusi_notice", XItemMarks._deploy_notice_text == XItemMarks.TIANQI_HELPER_NOTICE, XItemMarks._deploy_notice_text)
	_check("enf_jiusi_party_kept", _sorted(j.party) == party_before, j.party)
	XItemMarks.flush_deploy_notice(j)
	_check("enf_idempotent", not XItemMarks.enforce_party(j) and XItemMarks._deploy_notice == null and j.battle_slots == j_after)
	# 九死：上场 2 超＋助力位超，两类合并一次提示
	var j2 := _state("jiusi", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], sup[2]])
	XItemMarks.enforce_party(j2)
	_check("enf_jiusi_both", j2.battle_slots[0] == sup[0] and j2.battle_slots[2] == w[2] and j2.battle_slots[3] == w[3]
		and [w[0], w[1], w[4]].has(j2.battle_slots[1]) and [w[0], w[1], w[4]].has(j2.battle_slots[4]), j2.battle_slots)
	_check("enf_jiusi_both_notice", XItemMarks._deploy_notice_text == (XItemMarks.TIANQI_DEPLOY_NOTICE % 1) + XItemMarks.TIANQI_HELPER_NOTICE, XItemMarks._deploy_notice_text)
	_check("enf_jiusi_both_unique", _sorted(j2.battle_slots.filter(func(id): return int(id) > 0)).size() == 5
		and j2.battle_slots.filter(func(id): return int(id) > 0).all(func(id): return j2.battle_slots.count(id) == 1), j2.battle_slots)
	# 炼狱：没有替补可补时助力位留空
	var l := _state("lianyu", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], sup[2]])
	for id in [w[0], w[1], w[4]]:
		l.party.erase(id)
	XItemMarks.enforce_party(l)
	_check("enf_lianyu_empty_helper", l.battle_slots == [sup[0], sup[1], w[2], w[3], 0] and l.party.has(sup[2]), [l.battle_slots, l.party])
	# 证道合规档不动
	var z0 := _state("zhengdao", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], sup[2]])
	_check("enf_zhengdao_legal_untouched", not XItemMarks.enforce_party(z0) and z0.battle_slots == [sup[0], sup[1], w[2], w[3], sup[2]], z0.battle_slots)
	# D77：证道上场 3 个超强者、助力位是强／弱者 → 第 3 个挪助力位，原助力位的人去替补后按补位顺序补回空出的格
	var z1 := _state("zhengdao", [sup[0], sup[1], sup[2]], [sup[0], sup[1], sup[2], w[3], w[4]])
	party_before = _sorted(z1.party)
	_check("enf_d77_to_helper", XItemMarks.enforce_party(z1) and z1.battle_slots == [sup[0], sup[1], w[4], w[3], sup[2]], z1.battle_slots)
	_check("enf_d77_notice", XItemMarks._deploy_notice_text == XItemMarks.TIANQI_TO_HELPER_NOTICE % 2, XItemMarks._deploy_notice_text)
	_check("enf_d77_party_kept", _sorted(z1.party) == party_before)
	_check("enf_d77_idempotent", not XItemMarks.enforce_party(z1))
	# 助力位空着：第 3 个超强者进助力位，空出的上场格从替补补
	var z2 := _state("zhengdao", [sup[0], sup[1], sup[2]], [sup[0], sup[1], sup[2], w[3], 0])
	XItemMarks.enforce_party(z2)
	_check("enf_d77_empty_helper", z2.battle_slots[4] == sup[2] and z2.battle_slots.slice(0, 4).filter(func(id): return XItemMarks._super_in(z2, int(id))).size() == 2
		and not XItemMarks._super_in(z2, int(z2.battle_slots[2])) and int(z2.battle_slots[2]) > 0, z2.battle_slots)
	# 助力位已经是超强者：第 3 个去替补
	var z3 := _state("zhengdao", [sup[0], sup[1], sup[2], sup[3]], [sup[0], sup[1], sup[2], w[3], sup[3]])
	XItemMarks.enforce_party(z3)
	_check("enf_d77_helper_super", z3.battle_slots[4] == sup[3] and not z3.battle_slots.has(sup[2]) and z3.party.has(sup[2])
		and not XItemMarks._super_in(z3, int(z3.battle_slots[2])), z3.battle_slots)
	_check("enf_d77_helper_super_notice", XItemMarks._deploy_notice_text == XItemMarks.TIANQI_DEPLOY_NOTICE % 2, XItemMarks._deploy_notice_text)
	# 上场 4 个超强者、助力位弱者：一个挪助力位、一个去替补，两格从替补补（原助力位的人排第一）
	var z4 := _state("zhengdao", [sup[0], sup[1], sup[2], sup[3]], [sup[0], sup[1], sup[2], sup[3], w[4]])
	XItemMarks.enforce_party(z4)
	_check("enf_d77_four", z4.battle_slots[0] == sup[0] and z4.battle_slots[1] == sup[1] and z4.battle_slots[4] == sup[2]
		and z4.battle_slots[2] == w[4] and not XItemMarks._super_in(z4, int(z4.battle_slots[3])) and int(z4.battle_slots[3]) > 0, z4.battle_slots)
	_check("enf_d77_four_notice", XItemMarks._deploy_notice_text == (XItemMarks.TIANQI_TO_HELPER_NOTICE % 2) + (XItemMarks.TIANQI_DEPLOY_NOTICE % 2), XItemMarks._deploy_notice_text)
	# 读档入口：battle_members 前会清（不靠手调 enforce_party）
	var z5 := _state("zhengdao", [sup[0], sup[1], sup[2]], [sup[0], sup[1], sup[2], w[3], w[4]])
	var fighters := z5.battle_members().map(func(a): return a.actor_id)
	_check("enf_via_battle_members", fighters.filter(func(id): return XItemMarks._super_in(z5, id)).size() == 2 and z5.helper() != null and z5.helper().actor_id == sup[2], [fighters, z5.battle_slots])
	# 各入口都会清（init_battle_slots、add_actor、rearrange_actors、remove_actor、进图 deploy_start、battle_members）
	var entries := {
		"rearrange": func(x: XState): x.rearrange_actors(),
		"add_actor": func(x: XState): XTianqi._joining = true; x.add_actor(w[6]); XTianqi._joining = false,
		"remove_actor": func(x: XState): x.remove_actor(w[2]),
		"deploy_start": func(x: XState): XItemMarks.deploy_start(x),
		"battle_members": func(x: XState): x.battle_members(),
	}
	for name in entries:
		var e := _state("lianyu", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], sup[2]])
		entries[name].call(e)
		_check("enf_entry_" + name, XItemMarks.tianqi_slots_ok(e, e.battle_slots) and e.party.has(sup[2]), [name, e.battle_slots])
	var ib := _state("lianyu", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], sup[2]])
	ib.party = [sup[0], sup[1], sup[2], w[0], w[1], w[2], w[3], w[4]]
	ib.init_battle_slots()  # 按队伍前 5 人重建：3 超在前 → 清成合规
	_check("enf_entry_init_battle_slots", XItemMarks.tianqi_slots_ok(ib, ib.battle_slots), ib.battle_slots)
	# 非天启篇存档：清理照原版（不动助力位规则）
	var old := XState.new_game_blank()
	old.party = [w[0], w[1], w[2], w[3], w[4]]
	old.battle_slots = [w[0], w[1], w[2], w[3], w[4]]
	_check("enf_legacy_untouched", not XItemMarks.enforce_party(old) and old.battle_slots == [w[0], w[1], w[2], w[3], w[4]])
	# 存档往返后照样（旧档存着违规出战栏，读回再清）
	var j3 := _state("jiusi", [sup[0], sup[1]], [sup[0], w[1], w[2], w[3], sup[1]])
	var back: XState = XState.from_dict(j3.to_dict())
	_check("enf_after_load", back.battle_members().size() == 4 and back.helper() != null and not XItemMarks._super_in(back, back.helper().actor_id), back.battle_slots)


## 五、随机阵容
func _lineups() -> void:
	for k in ["xunchang", "jianxian", "jiusi", "lianyu", "zhengdao"]:
		var d := XTianqi.difficulty(k)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261115
		var bad := []
		var three := 0
		var helper_super := 0
		for i in 1000:
			var l := XTianqi.roll_lineup(k, rng)
			var front := l.slice(0, 4).filter(func(id): return XTianqiSkills.is_super(id, true)).size()
			var total := l.filter(func(id): return XTianqiSkills.is_super(id, true)).size()
			var h := XTianqiSkills.is_super(l[4], true)
			three += 1 if total == 3 else 0
			helper_super += 1 if h else 0
			if front > int(d.super_cap) or (h and not bool(d.helper_super)) or total > XTianqi.lineup_super_max(k) or not XTianqi.lineup_ok(k, l):
				bad.append(l)
		_check("roll1000_" + k, bad.is_empty(), bad.slice(0, 3))
		if k == "zhengdao":
			_check("roll_zhengdao_three_seen", three > 0 and helper_super > 0, [three, helper_super])
		else:
			_check("roll_%s_no_helper_super" % k, helper_super == 0, helper_super)
	# 同种子复现
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 77
	r2.seed = 77
	_check("roll_reproducible", range(50).all(func(_i): return XTianqi.roll_lineup("zhengdao", r1) == XTianqi.roll_lineup("zhengdao", r2)))
	# 确定性排位：证道 3 超全在前面 → 一个换到第 5 位；九死第 5 位是超强者 → 和前 4 个里一个非超强者对调
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var a := [sup[0], sup[1], sup[2], w[0], w[1]]
	XTianqi._seat_lineup(a, 2, true, rng)
	_check("seat_zhengdao", XTianqiSkills.is_super(a[4], true) and a.slice(0, 4).filter(func(id): return XTianqiSkills.is_super(id, true)).size() == 2
		and _sorted(a) == _sorted([sup[0], sup[1], sup[2], w[0], w[1]]), a)
	var b := [w[0], w[1], w[2], w[3], sup[0]]
	XTianqi._seat_lineup(b, 1, false, rng)
	_check("seat_jiusi", not XTianqiSkills.is_super(b[4], true) and b.has(sup[0]), b)
	var c := [sup[0], w[1], w[2], w[3], w[4]]
	var c0 := c.duplicate()
	var st := rng.state
	XTianqi._seat_lineup(c, 1, false, rng)
	_check("seat_noop_no_rng", c == c0 and rng.state == st)
	# lineup_ok：原有条件保留＋新三条
	_check("lineup_ok_rules", XTianqi.lineup_ok("zhengdao", [sup[0], sup[1], w[0], w[1], sup[2]])
		and not XTianqi.lineup_ok("zhengdao", [sup[0], sup[1], sup[2], w[0], w[1]])
		and not XTianqi.lineup_ok("zhengdao", [sup[0], sup[1], sup[3], w[0], sup[2]])
		and not XTianqi.lineup_ok("lianyu", [sup[0], sup[1], w[0], w[1], sup[2]])
		and not XTianqi.lineup_ok("lianyu", [sup[0], w[2], w[0], w[1], sup[2]])
		and XTianqi.lineup_ok("lianyu", [sup[0], sup[1], w[0], w[1], w[2]])
		and not XTianqi.lineup_ok("zhengdao", [sup[0], sup[0], w[0], w[1], sup[2]])
		and not XTianqi.lineup_ok("zhengdao", [sup[0], sup[1], sup[2], w[1], sup[3]]))
	# 开局入队：出战栏照阵容顺序、助力位是第 3 个超强者、1 号是阵容第一个
	var lineup := [sup[0], w[0], sup[1], w[1], sup[2]]
	var s := XTianqi.start_new_game(3, "zhengdao", lineup)
	XTianqi.take_pending()
	for id in lineup:
		s.add_actor(int(id))
	_check("opening_slots", s.battle_slots == lineup and Array(s.party) == lineup and s.helper() != null and s.helper().actor_id == sup[2]
		and s.battle_members().map(func(x): return x.actor_id) == [sup[0], w[0], sup[1], w[1]], [s.battle_slots, s.party])


## 六、战斗中换人
func _logic(s: XState) -> XBattleLogic:
	for id in s.party:
		s.actor(id).recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _actor(lg: XBattleLogic, id: int) -> XActor:
	for a in lg.actors:
		if a is XActor and a.actor_id == id:
			return a
	return null


func _battle_swap() -> void:
	# 证道：场上 2 超、助力位超 → 不能换下强／弱者；能换下超强者
	var z := _state("zhengdao", [sup[0], sup[1], sup[2]], [sup[0], sup[1], w[2], w[3], sup[2]])
	var lg := _logic(z)
	_check("bswap_setup", lg.actors.size() == 4 and z.helper() != null and z.helper().actor_id == sup[2], z.battle_slots)
	_check("bswap_cap_blocks", not lg.can_tianqi_swap(_actor(lg, w[2])) and not lg.can_tianqi_swap(_actor(lg, w[3])))
	_check("bswap_super_for_super", lg.can_tianqi_swap(_actor(lg, sup[0])))
	# 小o P1-1 反例：强者倒下后用超强者补位也不行（倒下的仍占出战栏，场上活着的超强者也已 2 个）
	_actor(lg, w[2]).add_state(1)
	_check("bswap_dead_still_blocks", not _actor(lg, w[2]).is_alive() and not lg.can_tianqi_swap(_actor(lg, w[2])))
	var h := lg.tianqi_swap(_actor(lg, w[2]))
	_check("bswap_dead_no_swap", h == null and z.battle_slots == [sup[0], sup[1], w[2], w[3], sup[2]], z.battle_slots)
	h = lg.tianqi_swap(_actor(lg, sup[0]))
	_check("bswap_super_swapped", h != null and h.actor_id == sup[2] and z.battle_slots == [sup[2], sup[1], w[2], w[3], sup[0]]
		and XItemMarks.tianqi_slots_ok(z, z.battle_slots), z.battle_slots)
	# 证道满 2 超、助力位是强／弱者：超强者换下去、强／弱者换上来可以
	var zf := _state("zhengdao", [sup[0], sup[1]], [sup[0], sup[1], w[2], w[3], w[4]])
	var lgf := _logic(zf)
	_check("bswap_super_out_plain_in", lgf.can_tianqi_swap(_actor(lgf, sup[0])) and lgf.can_tianqi_swap(_actor(lgf, w[2])))
	# 倒下的人不能换（不靠上限：场上 1 超时也不行）
	var zd := _state("zhengdao", [sup[0], sup[2]], [sup[0], w[1], w[2], w[3], sup[2]])
	var lgd := _logic(zd)
	_actor(lgd, w[1]).add_state(1)
	_check("bswap_dead_cannot_swap", not lgd.can_tianqi_swap(_actor(lgd, w[1])) and lgd.can_tianqi_swap(_actor(lgd, w[2])))
	# 证道：场上 1 超 → 助力位超强者能换下强者
	var z2 := _state("zhengdao", [sup[0], sup[2]], [sup[0], w[1], w[2], w[3], sup[2]])
	var lg2 := _logic(z2)
	_check("bswap_under_cap", lg2.can_tianqi_swap(_actor(lg2, w[1])))
	h = lg2.tianqi_swap(_actor(lg2, w[1]))
	_check("bswap_under_cap_slots", h != null and XItemMarks.tianqi_slots_ok(z2, z2.battle_slots) and z2.battle_slots[4] == w[1], z2.battle_slots)
	# 九死：场上的超强者不能换进助力位；助力位被写成超强者（漏清）也不能换上来
	var j := _state("jiusi", [sup[0], sup[1]], [sup[0], w[1], w[2], w[3], w[4]])
	var lg3 := _logic(j)
	_check("bswap_jiusi_super_out_blocked", not lg3.can_tianqi_swap(_actor(lg3, sup[0])) and lg3.can_tianqi_swap(_actor(lg3, w[1])))
	j.battle_slots[4] = sup[1]
	_check("bswap_jiusi_helper_super_blocked", not lg3.can_tianqi_swap(_actor(lg3, w[1])))


	# 跨存档：原版超强者在天启篇降档后，换人仍按战斗存档判定。
	var changed := (_ids(XTier.WEAK) + _ids(XTier.STRONG)).filter(func(id): return XTier.is_super(id))
	_check("bswap_cross_save_fixture", not changed.is_empty())
	if not changed.is_empty():
		var cs := _state("jiusi", [sup[0], changed[0]], [sup[0], changed[0], w[2], w[3], w[4]])
		var cl := _logic(cs)
		var saved := XState.current
		for other in [XState.new_game_blank(), null]:
			XState.current = other
			_check("bswap_cross_save_%s" % ("null" if other == null else "legacy"),
				cl.can_tianqi_swap(_actor(cl, changed[0])) and not cl.can_tianqi_swap(_actor(cl, sup[0])))
		XState.current = saved


## 七、开关回退：照旧助力位都能放超强者、整队页只查被放进去的人、随机阵容最多 super_cap 个
func _rollback() -> void:
	XTianqi.HELPER_RULES = false
	var j := _state("jiusi", [sup[0], sup[1]], [sup[0], w[1], w[2], w[3], sup[1]])
	_check("off_enforce_keeps_helper", not XItemMarks.enforce_party(j) and j.battle_slots[4] == sup[1], j.battle_slots)
	_check("off_can_deploy_helper", XItemMarks.can_deploy(j, sup[1], 4) and not XTianqi.lineup_ok("jiusi", [sup[0], w[1], w[2], w[3], sup[1]])
		and XTianqi.lineup_ok("jiusi", [w[0], w[1], w[2], w[3], sup[0]]))
	_check("off_lineup_max", XTianqi.lineup_super_max("zhengdao") == 2 and XTianqi.helper_super_key("jiusi") and XItemMarks.can_swap_slots(j, 0, 4))
	var lg := _logic(_state("jiusi", [sup[0], sup[1]], [sup[0], w[1], w[2], w[3], w[4]]))
	_check("off_battle_swap_super_out", lg.can_tianqi_swap(_actor(lg, sup[0])))
	XTianqi.HELPER_RULES = true
	_check("on_again", XItemMarks.enforce_party(j) and j.battle_slots[4] != sup[1], j.battle_slots)
