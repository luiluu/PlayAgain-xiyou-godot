extends Node
## 天启篇开局不发难度被动（XTianqiNoDiffPassive，O-421；天启篇设计总览 v0.2 第二节，Kyo 11-08）：
## 一、学不到：天启篇存档里原版教这三个被动的脚本（开局 learnSkill 5980、公共事件 1319 天道诅咒、大厅 EV020 的 learnSkill 5548）都不生效；
##     开关关掉照学；西游档照学；难度同步（主角没有就按开关 2491 补）不再补。
## 二、等价：同一角色同一技能打同一敌人，「新（不学被动、读数值表）」和「旧（开关关、学三个被动、挂上开战状态）」逐项相等：
##     物理／魔法、暴击／不暴击、治疗（难度适应 ×5 连治疗）、和因果丝线 1254／2709 同一乘区连乘；敌人打角色；战斗中敏捷、暴击率、
##     掉率加成、金钱加成、难度奖励倍率。另验「新」和「什么都不乘」不同（等价项真乘上了）。容差：伤害、敏捷逐项完全相等（同样逐步 ceil），小数项 1e-9。
## 三、老存档：手造带三个被动和常驻状态的天启篇档，存读一轮后被动和状态都没了，伤害与旧相等、没有叠两遍；开战同步不补回。
## 四、实跑开局：艰险、固定阵容 → 大厅跑完开局指令与 EV020 → 全部有名字的角色都没学这三个被动。
## 五、回退（gpt 甲档核查 P2）：开关关掉再读档，本功能接管过的天启篇档（老档剥过的、开关开着新开局的）按原开局补回三个被动，
##     开战照原样挂状态，伤害／敏捷／暴击和旧做法相等；开→关→开→关往返两次不叠加、不丢；实跑开局建的档同样能回退；
##     五条悟在本功能开着时（实跑开局后入队）伤害和旧做法相等。
## 存档写到 user://test_xiyou_tianqi_ndp，测试结束删除。

const SKILLS := [5548, 5980, 6168]
const STATES := [1631, 1691, 995]

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-9) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _ids(tier: String) -> Array:
	return XTianqiSkills.ids(tier, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and not [95, 173].has(id))


func _state(key: String, lineup: Array) -> XState:
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		XParamPlus.add(s, int(id), 6, 1000.0)  # 弱者开局敏捷是 0，×0.8 量不出差别：补 1000 点
		s.actor(int(id)).recover_all()
	return s


func _lineup() -> Array:
	var w := _ids(XTier.WEAK)
	var st := _ids(XTier.STRONG)
	var late: Array = w.filter(func(id): return int(id) >= 167)  # ≥167 的角色走难度同步（inherit_difficulty）
	var first = late[0] if not late.is_empty() else w[4]
	var rest: Array = w.filter(func(id): return id != first)
	return [st[0], rest[0], rest[1], first, rest[2]]


func _learn_all_script(sid: int) -> String:
	return "\n".join(XTianqi._learn_all(sid).map(func(c): return str(c.parameters[0])))


func _wait(cond: Callable, timeout := 6000) -> bool:
	for i in range(timeout):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XSave.dir_override = "user://test_xiyou_tianqi_ndp"
	seed(20261114)
	await _learn_blocked()
	_equivalence()
	_old_save()
	_rollback_old_save()
	await _real_opening()
	for slot in range(1, 11):
		DirAccess.remove_absolute(XSave.path(slot))
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _has_any(a: XActor) -> Array:
	return SKILLS.filter(func(sid): return a.skill_ids.has(sid))


# ---- 一、学不到 ----

func _learn_blocked() -> void:
	var lineup := _lineup()
	var s := _state("jianxian", lineup)
	for sid in SKILLS:
		await MVScript.run(_learn_all_script(sid), MVInterpreter.new(self, 0, 0, []))
	var leaked := []
	for aid in s.actors.keys():
		if not _has_any(s.actors[aid]).is_empty():
			leaked.append(aid)
	_check("tianqi_learn_all_blocked", leaked.is_empty() and lineup.all(func(id): return s.actors.has(int(id))), leaked)
	# 公共事件 1319（天道诅咒：变量 14＝1 时全员学 6168）
	s.set_variable(14, 1)
	var ce: Array = XDB.rec("CommonEvents", 1319).get("list", [])
	var interp := MVInterpreter.new(self, 0, 0, ce)
	await interp.run()
	_check("tianqi_ce1319_blocked", not s.actor(lineup[0]).skill_ids.has(6168) and not s.actor(lineup[3]).skill_ids.has(6168))
	# 难度同步：开关 2491（普通）开着、主角没学，也不再按开关补 5548／5980
	s.set_switch(2491, true)
	var late := s.actor(lineup[3])
	s.inherit_difficulty(late)
	s.sync_difficulty_on_battle()
	_check("tianqi_profile_no_refill", _has_any(late).is_empty(), late.skill_ids.filter(func(x): return x > 5500 and x < 6300))
	# 开关关：照原版学
	XTianqiNoDiffPassive.ENABLED = false
	for sid in SKILLS:
		await MVScript.run(_learn_all_script(sid), MVInterpreter.new(self, 0, 0, []))
	_check("switch_off_learns", _has_any(s.actor(lineup[0])) == SKILLS and _has_any(late) == SKILLS, [_has_any(s.actor(lineup[0])), _has_any(late)])
	XTianqiNoDiffPassive.ENABLED = true
	# 西游档：照原版学，读档不剥
	var p := XState.new_game_blank()
	for id in lineup.slice(0, 2):
		p.add_actor(int(id))
	XState.current = p
	for sid in SKILLS:
		await MVScript.run(_learn_all_script(sid), MVInterpreter.new(self, 0, 0, []))
	_check("xiyou_learns", _has_any(p.actor(lineup[0])) == SKILLS, _has_any(p.actor(lineup[0])))
	p.actor(lineup[0]).add_state(995)
	var p2 := XState.from_dict(p.to_dict())
	_check("xiyou_load_untouched", _has_any(p2.actor(lineup[0])) == SKILLS and p2.actor(lineup[0]).state_ids.has(995) and XTianqiNoDiffPassive.strip(p2) == 0)


# ---- 二、等价 ----

func _hit(item: Dictionary, a: XBattler, b: XBattler, crit: bool) -> float:
	var res := XDamage.calculate(item, a, b, {"critical": crit, "variance": false})
	return XDamage.finish(res, item, a, b, false)


## 一份读数：几种出伤、治疗、承伤、敏捷、暴击、掉率、金钱
func _snapshot(s: XState, a: XActor, enemy: XEnemy, ally: XActor) -> Dictionary:
	a.param_cache_begin()  # 战斗中（开战挂状态之后）
	var out := {}
	for sid in [1, 902, 908]:
		for crit in [false, true]:
			out["dmg_%d_%s" % [sid, crit]] = _hit(XDB.rec("Skills", sid), a, enemy, crit)
	out["heal_8"] = _hit(XDB.rec("Skills", 8), a, ally, false)
	out["heal_335"] = _hit(XDB.rec("Skills", 335), a, ally, false)
	out["taken_1"] = _hit(XDB.rec("Skills", 1), enemy, a, false)
	out["agi"] = a.param(6)
	out["cri"] = a.xparam(2)
	out["drop_bonus"] = XTianqiDrop.party_bonus(s, [a])
	out["drop_diff"] = XTianqiDrop.difficulty_mult(s)
	out["gold_bonus"] = XTianqiMoney.income_bonus([a], s)
	a.param_cache_end()
	out["agi_field"] = a.param(6)
	return out


func _legacy_on(a: XActor) -> void:
	XTianqiNoDiffPassive.ENABLED = false
	for sid in SKILLS:
		a.learn_skill(sid)
	for st in STATES:
		a.add_state(st)  # 开战 StartPushState 挂上的
	a.refresh_passive()


func _legacy_off(a: XActor) -> void:
	for st in STATES:
		a.remove_state(st)
	for sid in SKILLS:
		a.forget_skill(sid)
	a.refresh_passive()
	XTianqiNoDiffPassive.ENABLED = true


func _compare(tag: String, new: Dictionary, old: Dictionary) -> void:
	for k in old.keys():
		if k == "agi_field":
			continue  # 战斗外：旧做法首战后状态留在身上 ×0.8，新做法只在战斗中算（交付单写明）
		var ok: bool = new[k] == old[k] if k.begins_with("dmg") or k.begins_with("heal") or k.begins_with("taken") or k == "agi" else _near(float(new[k]), float(old[k]))
		_check("%s_%s" % [tag, k], ok, [new[k], old[k]])


func _equivalence() -> void:
	var lineup := _lineup()
	var s := _state("jianxian", lineup)
	var a := s.actor(lineup[0])
	var ally := s.actor(lineup[1])
	ally.hp = 1
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	_check("fixture_clean", _has_any(a).is_empty() and STATES.all(func(st): return not a.state_ids.has(st)) and a.param(6) > 0.0, a.param(6))
	# 什么都不乘：开关开但把数值表这一节拿掉
	var tbl: Dictionary = XTianqiBalance.data()
	var saved = tbl.get("legacy_passive")
	tbl.erase("legacy_passive")
	var bare := _snapshot(s, a, enemy, ally)
	tbl["legacy_passive"] = saved
	var new := _snapshot(s, a, enemy, ally)
	_legacy_on(a)
	var old := _snapshot(s, a, enemy, ally)
	_legacy_off(a)
	_compare("eq", new, old)
	# 等价项真乘上了：正伤害约 ×6、治疗约 ×5、敏捷少两成、暴击 +0.5
	var r1 := float(new["dmg_1_false"]) / maxf(1.0, float(bare["dmg_1_false"]))
	_check("bites_damage_x6", r1 > 5.9 and r1 < 6.1, [new["dmg_1_false"], bare["dmg_1_false"]])
	var rh := float(new["heal_8"]) / float(bare["heal_8"]) if float(bare["heal_8"]) != 0.0 else 0.0
	_check("bites_heal_x5", rh > 4.9 and rh < 5.1, [new["heal_8"], bare["heal_8"]])
	_check("bites_agi", float(new["agi"]) < float(bare["agi"]) and float(new["agi_field"]) == float(bare["agi_field"]), [new["agi"], bare["agi"], new["agi_field"]])
	_check("bites_crit", _near(float(new["cri"]) - float(bare["cri"]), 0.5), [new["cri"], bare["cri"]])
	# 和因果丝线（1254 ×3、2709 ×1.5，同为确认阶段 ceil 乘、优先级同 50）同一乘区逐个连乘，次序照状态号
	for extra in [[1254], [2709], [1254, 2709]]:
		for st in extra:
			a.add_state(st)
		var n2 := _snapshot(s, a, enemy, ally)
		_legacy_on(a)
		var o2 := _snapshot(s, a, enemy, ally)
		_legacy_off(a)
		for st in extra:
			a.remove_state(st)
		_compare("chain_%s" % "_".join(extra.map(func(x): return str(x))), n2, o2)
		_check("chain_bites_%s" % "_".join(extra.map(func(x): return str(x))), float(n2["dmg_1_false"]) > float(new["dmg_1_false"]) * 1.4, [n2["dmg_1_false"], new["dmg_1_false"]])
	# 其它难度（九死）：数值表的等价项不分档，一样等价
	var s9 := _state("jiusi", lineup)
	var a9 := s9.actor(lineup[0])
	var n9 := _snapshot(s9, a9, enemy, s9.actor(lineup[1]))
	_legacy_on(a9)
	var o9 := _snapshot(s9, a9, enemy, s9.actor(lineup[1]))
	_legacy_off(a9)
	_compare("jiusi", n9, o9)
	# 开关关：不加等价项（关掉就回到「学被动」的老路，没学时什么都不乘）
	XTianqiNoDiffPassive.ENABLED = false
	var off := _snapshot(s, a, enemy, ally)
	XTianqiNoDiffPassive.ENABLED = true
	_check("switch_off_bare", off["dmg_1_false"] == bare["dmg_1_false"] and off["agi"] == bare["agi"] and _near(float(off["cri"]), float(bare["cri"])), [off["dmg_1_false"], bare["dmg_1_false"]])
	# 西游档：确认阶段不插、敏捷暴击不改
	var p := XState.new_game_blank()
	p.add_actor(int(lineup[0]))
	XState.current = p
	var pa := p.actor(lineup[0])
	XParamPlus.add(p, int(lineup[0]), 6, 1000.0)
	pa.recover_all()
	pa.param_cache_begin()
	var pv := _hit(XDB.rec("Skills", 1), pa, enemy, false)
	var pagi := pa.param(6)
	var pcri := pa.xparam(2)
	XTianqiNoDiffPassive.ENABLED = false
	var pv_off := _hit(XDB.rec("Skills", 1), pa, enemy, false)
	var pagi_off := pa.param(6)
	var pcri_off := pa.xparam(2)
	XTianqiNoDiffPassive.ENABLED = true
	pa.param_cache_end()
	_check("xiyou_untouched", pv == pv_off and pagi == pagi_off and pcri == pcri_off, [pv, pv_off, pagi, pagi_off, pcri, pcri_off])


# ---- 三、老存档 ----

func _old_save() -> void:
	var lineup := _lineup()
	var s := _state("jianxian", lineup)
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	var a := s.actor(lineup[0])
	# 旧读数：开关关、学三个被动、挂开战状态
	_legacy_on(a)
	var old := _snapshot(s, a, enemy, s.actor(lineup[1]))
	_legacy_off(a)
	# 手造老档：开关开着也硬塞进去（老版本学过）；1691、995 不随战斗结束拿掉，留在档里
	for id in lineup:
		var x := s.actor(int(id))
		for sid in SKILLS:
			if not x.skill_ids.has(sid):
				x.skill_ids.append(sid)
		for st in [1691, 995]:
			if not x.state_ids.has(st):
				x.state_ids.append(st)
	s.set_switch(2491, true)
	var d := s.to_dict()
	var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	XState.current = s2
	var left := []
	for id in lineup:
		var x := s2.actor(int(id))
		if not _has_any(x).is_empty() or STATES.any(func(st): return x.state_ids.has(st)):
			left.append([id, _has_any(x), x.state_ids.filter(func(st): return STATES.has(st))])
	_check("old_save_stripped", left.is_empty() and XTianqi.active(s2), left)
	s2.sync_difficulty_on_battle()
	_check("old_save_battle_sync_no_refill", lineup.all(func(id): return _has_any(s2.actor(int(id))).is_empty()))
	var a2 := s2.actor(lineup[0])
	a2.recover_all()
	var new := _snapshot(s2, a2, enemy, s2.actor(lineup[1]))
	_compare("old_save", new, old)
	_check("old_save_strip_idempotent", XTianqiNoDiffPassive.strip(s2) == 0)


# ---- 四、实跑开局 ----

func _real_opening() -> void:
	var lineup := _lineup()
	Engine.time_scale = 6.0
	XMessageBox.auto_answers = ["测试道号"]
	XTianqi.start_new_game(3, "jianxian", lineup)
	var s := XState.current
	s.random_master = XRandomStream.hex64(20261114)
	get_tree().change_scene_to_file("res://modes/xiyou/map/map_scene.tscn")
	var ok := await _wait(func():
		var sc = get_tree().current_scene
		return sc is XMapScene and sc.map_id == 4 and sc.player != null and not sc.busy and s.self_switch(4, 20, "A"))
	_check("opening_hub_reached", ok and s.switch(2491) and int(s.variable(14)) == 1, [s.map_id, s.switch(2491), s.variable(14)])
	var leaked := []
	for aid in s.actors.keys():
		if not _has_any(s.actors[aid]).is_empty():
			leaked.append(aid)
	_check("opening_no_passive", leaked.is_empty() and s.actors.size() > 5, [leaked, s.actors.size()])
	_check("opening_first_slot_skills_kept", s.actor(lineup[0]).skill_ids.has(2571) and s.actor(lineup[0]).skill_ids.has(2786))
	await _wait(func():
		var sc = get_tree().current_scene
		return sc is XMapScene and not sc.busy and s.self_switch(4, 76, "A") and (not XRift.STAGE2 or s.self_switch(4, XRift.RIFT2, "A")))
	_rollback_opening(s, lineup)


# ---- 五、回退 ----

const GOJO := 180


## 开战：照 StartPushState 把学着的被动的状态挂上（同 XBattleLogic._battle_start_states）
func _battle_start(a: XActor) -> Array:
	var got := []
	for tag in a.battle_start_state_tags():
		var st := int(tag[1])
		if STATES.has(st):
			got.append(st)
			if not a.state_ids.has(st):
				a.add_state(st)
	a.refresh_passive()
	return got


func _clear_states(a: XActor) -> void:
	for st in STATES:
		if a.state_ids.has(st):
			a.remove_state(st)


func _counts(s: XState, ids: Array) -> Array:
	var out := []
	for id in ids:
		var a := s.actor(int(id))
		out.append(SKILLS.map(func(sid): return a.skill_ids.count(sid)))
	return out


func _reload(s: XState, enabled: bool) -> XState:
	var d = JSON.parse_string(JSON.stringify(s.to_dict()))
	XTianqiNoDiffPassive.ENABLED = enabled
	return XState.from_dict(d)


func _rollback_old_save() -> void:
	var lineup := _lineup()
	var s := _state("jianxian", lineup)
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	var a := s.actor(lineup[0])
	_legacy_on(a)
	var old := _snapshot(s, a, enemy, s.actor(lineup[1]))
	_legacy_off(a)
	for id in lineup:
		var x := s.actor(int(id))
		for sid in SKILLS:
			if not x.skill_ids.has(sid):
				x.skill_ids.append(sid)
		for st in [1691, 995]:
			if not x.state_ids.has(st):
				x.state_ids.append(st)
	s.set_switch(2491, true)
	s.set_variable(14, 1)
	# 开：剥、记标记
	var s1 := _reload(s, true)
	_check("rb_on_marked", int(s1.flags.tianqi.get(XTianqiNoDiffPassive.MARK, 0)) == 1 and _has_any(s1.actor(lineup[0])).is_empty())
	# 关：补回、清标记
	var s2 := _reload(s1, false)
	var a2 := s2.actor(lineup[0])
	_check("rb_off_restored", _counts(s2, lineup).all(func(c): return c == [1, 1, 1]) and not s2.flags.tianqi.has(XTianqiNoDiffPassive.MARK), _counts(s2, lineup))
	var tags: Array = a2.battle_start_state_tags().map(func(tg): return int(tg[1])).filter(func(st): return STATES.has(st))
	_check("rb_off_start_tags", STATES.all(func(st): return tags.count(st) == 1), tags)
	a2.recover_all()
	_battle_start(a2)
	_compare("rb_off1", _snapshot(s2, a2, enemy, s2.actor(lineup[1])), old)
	_clear_states(a2)
	# 再开、再关（往返第二次）：不叠加、不丢
	var s3 := _reload(s2, true)
	var a3 := s3.actor(lineup[0])
	a3.recover_all()
	_check("rb_on2_stripped", lineup.all(func(id): return _has_any(s3.actor(int(id))).is_empty()) and int(s3.flags.tianqi.get(XTianqiNoDiffPassive.MARK, 0)) == 1)
	_compare("rb_on2", _snapshot(s3, a3, enemy, s3.actor(lineup[1])), old)
	var s4 := _reload(s3, false)
	var a4 := s4.actor(lineup[0])
	_check("rb_off2_once", _counts(s4, lineup).all(func(c): return c == [1, 1, 1]), _counts(s4, lineup))
	a4.recover_all()
	_battle_start(a4)
	_battle_start(a4)  # 开战两次也只挂一层
	_check("rb_off2_states_once", STATES.all(func(st): return a4.state_ids.count(st) == 1), a4.state_ids)
	_compare("rb_off2", _snapshot(s4, a4, enemy, s4.actor(lineup[1])), old)
	_clear_states(a4)
	# 关着再读一次：没标记了，不再补（也不重复学）
	var s5 := _reload(s4, false)
	_check("rb_off_again_noop", _counts(s5, lineup).all(func(c): return c == [1, 1, 1]) and XTianqiNoDiffPassive.sync_after_load(s5) == 0)
	# 没标记的老档（功能上线前、开关关着建的）开关关着不碰
	var plain := _state("jianxian", lineup)
	plain.flags.tianqi.erase(XTianqiNoDiffPassive.MARK)
	XTianqiNoDiffPassive.ENABLED = false
	_check("rb_unmarked_untouched", XTianqiNoDiffPassive.sync_after_load(plain) == 0 and _has_any(plain.actor(lineup[0])).is_empty())
	XTianqiNoDiffPassive.ENABLED = true


## 实跑开局建的档：五条悟入队后伤害和旧做法相等；存档后关开关读档，补回被动，伤害相等；再开再关不叠加
func _rollback_opening(s: XState, lineup: Array) -> void:
	_check("op_marked", int(s.flags.tianqi.get(XTianqiNoDiffPassive.MARK, 0)) == 1)
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	XTianqi._joining = true
	s.add_actor(GOJO)
	XTianqi._joining = false
	var g := s.actor(GOJO)
	g.change_level(99)
	g.recover_all()
	_check("op_gojo_clean", _has_any(g).is_empty())
	var items := [XDB.rec("Skills", 1), XDB.rec("Skills", XGojo.BLUE), XDB.rec("Skills", XGojo.RED)]
	var new_g := []
	g.param_cache_begin()
	for it in items:
		new_g.append(_hit(it, g, enemy, false))
	g.param_cache_end()
	_legacy_on(g)
	g.param_cache_begin()
	var old_g := []
	for it in items:
		old_g.append(_hit(it, g, enemy, false))
	g.param_cache_end()
	_legacy_off(g)
	_check("op_gojo_equal", new_g == old_g and float(new_g[1]) > 0.0, [new_g, old_g])
	var a := s.actor(lineup[0])
	var ref := _snapshot(s, a, enemy, s.actor(lineup[1]))
	var s2 := _reload(s, false)
	var named: Array = XDB.table("Actors").filter(func(r): return r != null and str(r.get("name", "")) != "").map(func(r): return int(r.id))
	var missing: Array = named.filter(func(id): return _has_any(s2.actor(id)) != SKILLS)
	_check("op_off_restored_all_named", missing.is_empty(), missing.slice(0, 10))
	var a2 := s2.actor(lineup[0])
	_battle_start(a2)
	_compare("op_off", _snapshot(s2, a2, enemy, s2.actor(lineup[1])), ref)
	var g2 := s2.actor(GOJO)
	_battle_start(g2)
	g2.param_cache_begin()
	var off_g := []
	for it in items:
		off_g.append(_hit(it, g2, enemy, false))
	g2.param_cache_end()
	_check("op_off_gojo_equal", off_g == new_g, [off_g, new_g])
	_clear_states(a2)
	_clear_states(g2)
	var s3 := _reload(_reload(s2, true), false)
	_check("op_roundtrip_once", _counts(s3, lineup + [GOJO]).all(func(c): return c == [1, 1, 1]), _counts(s3, lineup + [GOJO]))
	XTianqiNoDiffPassive.ENABLED = true
