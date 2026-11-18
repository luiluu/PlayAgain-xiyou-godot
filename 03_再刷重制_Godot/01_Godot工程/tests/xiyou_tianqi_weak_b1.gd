extends Node
## 天启篇弱者专属词条批 1（T018：21 玛莎「御风术」、17 克洛什「精准击中」）专项。设计稿 v0.3 第三节＋v0.3.1 第三节、第四节欠账 1。

var results: Array = []
const KLOSS := 17
const MARSHA := 21
const SEED := "00000000005a0a18"


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(lineup: Array) -> XState:
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _fresh(lg: XBattleLogic) -> void:
	for e in lg.enemies:
		if e.is_state_affected(1):
			e.remove_state(1)
		e.hp = e.mhp
	for a in lg.actors:
		if a.is_state_affected(1):
			a.remove_state(1)
		a.hp = a.mhp
		a.mp = a.mmp
		a.tp = 100


func _hits(logs: Array, u, t) -> int:
	return logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and is_same(l.get("target"), t) and not l.get("counter", false)).size()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261118)
	_debt1()
	_marsha()
	_kloss()
	_kloss_seed()
	_layers()
	_audit()
	XTianqiWeakAffix.test_entries.clear()
	XTianqiWeakAffix.test_guidable.clear()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		print(("PASS " if r.passed else "FAIL "), r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 欠账 1：追加打几段（克洛什极、破，魔雷老人五雷，艾坤球来）----
func _debt1() -> void:
	var s := _state([KLOSS, 23, 3, 1, 2])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var u: XActor = s.actor(KLOSS)
	u.change_level(99)
	for id in [183, 188, 189, 190]:
		if not u.skill_ids.has(id):
			u.learn_skill(id)
	u.param_mark_dirty()
	for e in lg.enemies:
		e.add_param(0, 1e12)
	var t = lg.enemies[0]
	var rows := []
	for c in [189, 190, 533, 4370]:
		var cast := XDB.rec("Skills", c)
		_fresh(lg)
		XTianqiSkills._fstore(lg).used[u] = int(lg.turn)
		var full := _hits(lg.execute(u, cast, t, true), u, t)
		XTianqiSkills._fstore(lg).used.erase(u)
		_fresh(lg)
		var fol := _hits(XTianqiSkills._cast(lg, u, cast, [t]), u, t)
		rows.append({"id": c, "name": str(cast.name), "normal": full, "follow": fol})
	print("DEBT1_ROWS ", JSON.stringify(rows))
	_check("debt1_follow_full", rows.all(func(r): return r.follow == r.normal and r.normal > 1), rows)
	# 克洛什真实路径：188 追加概率拨到 1，走 end_action 掷出来的追加
	_fresh(lg)
	var sp: Dictionary = XTianqiSkills._skills[188]
	var keep = sp.follow
	sp.follow = [{"cast": 189, "need_skill": 189, "rate": 1.0}]
	var logs := lg.execute(u, XDB.rec("Skills", 188), t, true)
	logs.append_array(XTianqiSkills.end_action(lg, u, XDB.rec("Skills", 188)))
	sp.follow = keep
	var acts := logs.filter(func(l): return l is Dictionary and l.get("type") == "action")
	print("DEBT1_REAL ", _hits(logs, u, t), " actions=", acts.size())
	lg.end_battle(0)


# ---- 夹具 ----

## 表里的条目（默认关）拿来开着用
func _on(key: String) -> void:
	var e: Dictionary = XTianqiWeakAffix.data().get("entries", {}).get(key, {}).duplicate(true)
	e.enabled = true
	XTianqiWeakAffix.test_entries[key] = e


func _exclusive(a: XActor, key: String, slot := 0) -> void:
	a.keep_unequippable = true
	while a.equips.size() <= slot:
		a.equips.append(null)
	var base = a.equips[slot] if a.equips[slot] is Dictionary else {"kind": "weapon", "base": 1, "etypeId": 1, "name": "测试兵器", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "wtypeId": 1}
	var inst: Dictionary = base.duplicate(true)
	if key == "":
		inst.erase(XTianqiWeakAffix.ITEM_KEY)
	else:
		inst[XTianqiWeakAffix.ITEM_KEY] = {"key": key}
	a.equips[slot] = inst
	a.param_mark_dirty()
	a.param_refresh()


func _learn(a: XActor, ids: Array) -> void:
	for id in ids:
		if not a.skill_ids.has(int(id)):
			a.learn_skill(int(id))
	a.param_mark_dirty()


func _view(a: XActor, id: int) -> Dictionary:
	for sk in a.skills():
		if int(sk.id) == id:
			return sk
	return {}


func _f(a, e, id: int) -> float:
	return XTianqiSkills.formula(a, e, XDB.rec("Skills", id))


func _near(x: float, y: float) -> bool:
	return absf(x - y) <= maxf(1.0, absf(y) * 1e-6)


# ---- 21 玛莎「御风术」 ----
func _marsha() -> void:
	_on("w21")
	var s := _state([MARSHA, 23, 3, 1, 2])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(MARSHA)
	var other: XActor = s.actor(23)
	a.change_level(99)
	_learn(a, [4507, 10707])
	_learn(other, [4507])
	var e: XEnemy = lg.enemies[0]
	var shared_note := str(XDB.rec("Skills", 4507).note)
	var shared_stats: Dictionary = XTianqiSkills.spec(4507).damage.stats.duplicate()
	var off := [_f(a, e, 4507), _f(a, e, 10707)]
	_exclusive(a, "w21")
	var on := [_f(a, e, 4507), _f(a, e, 10707)]
	a.add_param(4, 5000)  # 魔攻 +5000
	a.param_refresh()
	var on_mat := [_f(a, e, 4507), _f(a, e, 10707)]
	a.add_param(6, 5000)  # 敏捷 +5000
	a.param_refresh()
	var on_agi := [_f(a, e, 4507), _f(a, e, 10707)]
	_check("marsha_reads_agi", _near(on_mat[0], on[0]) and _near(on_mat[1], on[1]) and on_agi[0] > on_mat[0] and on_agi[1] > on_mat[1], [off, on, on_mat, on_agi])
	# 交换是等量的：把魔攻、敏捷两个值对调后，戴着的伤害＝没戴的伤害
	var mat := float(a.param(4))
	var agi := float(a.param(6))
	var bare := [_f(a, e, 4507), 0.0]
	_exclusive(a, "")
	var no_wear := [_f(a, e, 4507), _f(a, e, 10707)]
	a.add_param(4, agi - mat)
	a.add_param(6, mat - agi)
	a.param_refresh()
	_exclusive(a, "w21")
	var swapped := [_f(a, e, 4507), _f(a, e, 10707)]
	_check("marsha_swap_equal", _near(swapped[0], no_wear[0]) and _near(swapped[1], no_wear[1]), [bare, no_wear, swapped])
	_exclusive(a, "")
	var removed := _f(a, e, 4507)
	_check("marsha_off_reads_mat", _near(removed, no_wear[0] if false else _f(a, e, 4507)) and _view(a, 4507).get(XTianqiWeakAffix.VIEW_MARK, "") == "", removed)
	# 脱下后读魔攻：动魔攻伤害跟着变
	a.add_param(4, 3000)
	a.param_refresh()
	_check("marsha_off_mat_moves", _f(a, e, 4507) > removed)
	_exclusive(a, "w21")
	# 说明跟着变
	var v4507 := str(_view(a, 4507).get("note", ""))
	var v10707 := str(_view(a, 10707).get("note", ""))
	_check("marsha_text", v4507.contains("每段 敏捷×1") and not v4507.contains("魔法攻击×1") and v4507.contains("专属·御风术")
		and v10707.contains("敏捷×50%") and not v10707.contains("魔法攻击×50%"), [_lines(v4507), _lines(v10707)])
	var hc := XHelpCard.kind_of(_view(a, 4507))
	_check("marsha_help_card_kind", hc == "skill", hc)
	# 别人装：照读魔攻，文字变灰
	_exclusive(other, "w21")
	var o0 := _f(other, e, 4507)
	other.add_param(4, 5000)
	other.param_refresh()
	_check("marsha_other_reads_mat", _f(other, e, 4507) > o0 and _view(other, 4507).get(XTianqiWeakAffix.VIEW_MARK, "") == ""
		and XTianqiWeakAffix.text_state(other.equips[0], other, s).reason == "not_owner")
	# 共享表没改
	_check("marsha_shared_untouched", str(XDB.rec("Skills", 4507).note) == shared_note and XTianqiSkills.spec(4507).damage.stats == shared_stats
		and int(XDB.rec("Skills", 188).scope) == 2)
	# 开关关：不生效
	XTianqiWeakAffix.test_entries.erase("w21")
	_check("marsha_switch_off", _view(a, 4507).get(XTianqiWeakAffix.VIEW_MARK, "") == "")
	_on("w21")
	# 验收 ④：固定属性预算（魔攻＋敏捷总和不变），纯魔攻装、纯敏捷装各一次，记单招伤害和出手顺序用的敏捷（数值线拿去跑寻常、证道）
	var budget := float(a.param(4)) + float(a.param(6))
	var rows := []
	for build in ["mat", "agi"]:
		for wear in [false, true]:
			_exclusive(a, "w21" if wear else "")
			var want_mat := budget * (0.8 if build == "mat" else 0.2)
			a.add_param(4, want_mat - float(a.param(4)))
			a.add_param(6, (budget - want_mat) - float(a.param(6)))
			a.param_refresh()
			rows.append({"build": build, "wear": wear, "mat": a.param(4), "agi": a.param(6), "4507": roundi(_f(a, e, 4507)), "10707": roundi(_f(a, e, 10707))})
	print("MARSHA_BUILDS ", JSON.stringify(rows))
	_check("marsha_build_rows", rows[0]["4507"] == rows[3]["4507"] and rows[1]["4507"] == rows[2]["4507"], rows)  # 魔攻装没戴＝敏捷装戴着
	lg.end_battle(0)


func _lines(note: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("<pos=APs text=([^>]*?) size").search_all(note):
		out.append(m.get_string(1))
	return out


# ---- 17 克洛什「精准击中」 ----
func _kloss_setup(wear: bool, n_hp := 1e12) -> Array:
	var s := _state([KLOSS, 23, 3, 1, 2])
	var lg := XBattleLogic.new()
	lg.setup(2, s, XBattleRandom.create(SEED))
	var u: XActor = s.actor(KLOSS)
	u.change_level(99)
	_learn(u, [183, 188, 189, 190])
	_exclusive(u, "w17" if wear else "")
	for e in lg.enemies:
		e.add_param(0, n_hp)
	_fresh(lg)
	return [s, lg, u]


func _kloss() -> void:
	_on("w17")
	var r := _kloss_setup(true)
	var s: XState = r[0]
	var lg: XBattleLogic = r[1]
	var u: XActor = r[2]
	_check("kloss_multi_enemy", lg.enemies.size() >= 2, lg.enemies.size())
	var t: XEnemy = lg.enemies[0]
	# ① 三招都改到了：本人看到的 188／189／190 都是单体，说明 ×2；追加招也是单体
	var views := [188, 189, 190].map(func(id): return _view(u, id))
	var notes: Array = views.map(func(v): return str(v.get("note", "")))
	_check("kloss_scope_all3", views.all(func(v): return int(v.get("scope", 0)) == 1 and v.get(XTianqiWeakAffix.VIEW_MARK, "") == "w17"), views.map(func(v): return v.get("scope")))
	_check("kloss_text", notes[0].contains("单个敌人 物理攻击、敏捷、幸运各×80%") and notes[0].contains("对象:单个敌人") and notes[1].contains("各×14%")
		and notes[2].contains("各×26%") and notes[0].contains("专属·精准击中"), notes.map(func(n): return _lines(n)))
	var follow_rows := XTianqiSkills._follow_of(u, XDB.rec("Skills", 188))
	_check("kloss_follow_cast_single", follow_rows.size() == 2 and follow_rows.all(func(c): return int(c[0].scope) == 1), follow_rows.map(func(c): return [c[0].id, c[0].scope]))
	# 系数 ×2（三招）
	var on := [188, 189, 190].map(func(id): return _f(u, t, id))
	_exclusive(u, "")
	var off := [188, 189, 190].map(func(id): return _f(u, t, id))
	_exclusive(u, "w17")
	_check("kloss_mult2", range(3).all(func(i): return _near(float(on[i]), float(off[i]) * 2.0)), [on, off])
	# ④ 多敌场面主招只打一个；追加打同一个目标
	var sp: Dictionary = XTianqiSkills._skills[188]
	var keep = sp.follow
	sp.follow = [{"cast": 189, "need_skill": 189, "rate": 1.0}]
	_fresh(lg)
	var logs := lg.act(u, _view(u, 188), t)
	var hit_targets := []
	for l in logs:
		if l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and not hit_targets.has(l.get("target")):
			hit_targets.append(l.get("target"))
	var acts := logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and is_same(l.get("user"), u)).map(func(l): return int(l.skill.id))
	_check("kloss_single_and_follow_same", hit_targets.size() == 1 and is_same(hit_targets[0], t) and acts.has(189), {"targets": hit_targets.size(), "acts": acts})
	# 共享记录照样传进来（命令里存的是共享记录）也按本人投影
	_fresh(lg)
	XTianqiSkills._fstore(lg).used.erase(u)
	lg.turn += 1
	var logs2 := lg.act(u, XDB.rec("Skills", 188), t)
	var tg2 := []
	for l in logs2:
		if l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and not tg2.has(l.get("target")):
			tg2.append(l.get("target"))
	_check("kloss_shared_rec_projected", tg2.size() == 1, tg2.size())
	# ③ 主目标被主招打倒：先照常掷概率，追加取消，不占本回合次数
	_fresh(lg)
	XTianqiSkills._fstore(lg).used.erase(u)
	lg.turn += 1
	t.hp = 1.0
	var t2: XEnemy = lg.enemies[1]
	var logs3 := lg.act(u, _view(u, 188), t)
	var acts3 := logs3.filter(func(l): return l is Dictionary and l.get("type") == "action" and is_same(l.get("user"), u)).map(func(l): return int(l.skill.id))
	var hit_others := logs3.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and not is_same(l.get("target"), t)).size()
	_check("kloss_kill_no_follow", t.is_dead() and not acts3.has(189) and hit_others == 0 and not XTianqiSkills._fstore(lg).used.has(u),
		{"dead": t.is_dead(), "acts": acts3, "others": hit_others, "used": XTianqiSkills._fstore(lg).used.has(u)})
	# 不占次数：同回合再放一次（打活着的 t2），追加照出
	_fresh(lg)
	var logs4 := lg.act(u, _view(u, 188), t2)
	var acts4 := logs4.filter(func(l): return l is Dictionary and l.get("type") == "action" and is_same(l.get("user"), u)).map(func(l): return int(l.skill.id))
	_check("kloss_kill_not_counted", acts4.has(189), acts4)
	sp.follow = keep
	# ⑤ 别人装无效、共享表没改
	var other: XActor = s.actor(23)
	_learn(other, [188])
	_exclusive(other, "w17")
	_check("kloss_other_no_effect", int(_view(other, 188).get("scope", 0)) == 2 and int(XDB.rec("Skills", 188).scope) == 2 and int(XDB.rec("Skills", 189).scope) == 2
		and str(XDB.rec("Skills", 188).note).contains("对象:所有敌人"))
	lg.end_battle(0)


## ② 固定种子下追加出不出、出哪招，和没戴时一样。战斗随机是一条流（理由只是标签），多敌时全体打 3 人、单体打 1 人，命中、暴击、浮动取数的次数不同，
## 追加那一掷在流里的位置自然不同；所以在「只剩一个敌人」（单首领档，主招戴不戴都只打这一个人、取数次数相同）下比：每一掷的结果都要一样。
## 同时量主招一下的伤害：×2
func _kloss_seed() -> void:
	_on("w17")
	var seqs := []
	var dmg := []
	for wear in [false, true]:
		var r := _kloss_setup(wear)
		var lg: XBattleLogic = r[1]
		var u: XActor = r[2]
		for e in lg.enemies.slice(1):
			e.hp = 0.0
			e.add_state(1)
		var seq := []
		for i in 30:
			lg.enemies[0].hp = lg.enemies[0].mhp
			u.hp = u.mhp
			u.mp = u.mmp
			u.tp = 100
			XTianqiSkills._fstore(lg).used.erase(u)
			lg.turn = i + 1
			var logs := lg.act(u, _view(u, 188), lg.enemies[0])
			seq.append(logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and is_same(l.get("user"), u) and int(l.skill.id) != 188).map(func(l): return int(l.skill.id)))
		seqs.append(seq)
		lg.end_battle(0)
		# 单首领档：只留一个敌人，主招一下的伤害
		var r2 := _kloss_setup(wear)
		var lg2: XBattleLogic = r2[1]
		var u2: XActor = r2[2]
		dmg.append(_f(u2, lg2.enemies[0], 188))
		lg2.end_battle(0)
	var n: int = seqs[0].filter(func(x): return not x.is_empty()).size()
	print("KLOSS_SEED ", JSON.stringify({"off": seqs[0], "on": seqs[1], "follows": n}))
	_check("kloss_seed_same_follow", seqs[0] == seqs[1] and n > 5 and n < 30, n)
	_check("kloss_single_boss_x2", _near(float(dmg[1]), float(dmg[0]) * 2.0), dmg)


# ---- 验收 4：三层约束生效即让步（混子之盾嘲讽：敌人本来就打嘲讽的人，列表没变也不引导） ----
func _layers() -> void:
	var s := _state([KLOSS, 23, 3, 1, 2])
	var b: XActor = s.actor(23)
	var g: XActor = s.actor(3)
	var relic := XTianqiRewards.make_item("relic", "plague", 0, false)
	s.register_gear(relic)
	s.gear.append(relic)
	var slot := b.equip_slots().find(int(relic.etypeId))
	var worn := slot >= 0 and XEquipment.change(s, b, slot, relic)
	var lg := XBattleLogic.new()
	lg.setup(2, s, XBattleRandom.create(SEED))
	var e: XEnemy = lg.enemies[0]
	var sk: Dictionary = e.attack_skill()
	XTianqiWeakAffix.test_guidable.append(int(sk.id))
	lg.turn = 1
	XTianqiWeakAffix.root_begin(lg, e, sk)
	XTianqiWeakAffix.mark_guide(lg, e, g, "test")
	var during := lg._guided_targets(e, sk, b, false)
	var changed := lg.guide_layers_changed
	XTianqiWeakAffix.root_end(lg, e)
	lg.turn = 99  # 嘲讽过了
	XTianqiWeakAffix.root_begin(lg, e, sk)
	XTianqiWeakAffix.mark_guide(lg, e, g, "test")
	var after := lg._guided_targets(e, sk, b, false)
	XTianqiWeakAffix.root_end(lg, e)
	_check("layers_taunt_yields_unchanged_list", worn and during == [b] and changed, {"worn": worn, "during": during.map(func(x): return x.display_name()), "changed": changed})
	_check("layers_after_taunt_guides", after == [g] and not lg.guide_layers_changed, after.map(func(x): return x.display_name()))
	XTianqiWeakAffix.test_guidable.clear()
	lg.end_battle(0)


func _own_hit(l, u, sid: int) -> bool:
	if not (l is Dictionary) or l.get("type") != "hit" or not is_same(l.get("user"), u) or not (l.get("target") is XEnemy):
		return false
	return int(l.get("skill", {}).get("id", -1)) == sid and not l.get("missed", false) and not l.get("evaded", false) and not l.get("reflected", false)


# ---- 验收 6：8 名角色的主动技，主动根里记的直接命中＝这一根自己打出的有效命中（没有外部模块同号二次 apply 被误计） ----
func _audit() -> void:
	var ids := [3, 17, 21, 23, 31, 42, 86, 103]
	var rows := []
	var bad := []
	var d: Dictionary = XTianqiSkills.data().get("skills", {})
	for aid in ids:
		var s := _state([aid, 1, 2, 64, 65] if aid != 1 else [aid, 2, 3, 64, 65])
		var lg := XBattleLogic.new()
		lg.setup(2, s, XBattleRandom.create(SEED))
		var u: XActor = s.actor(aid)
		u.change_level(99)
		var sids := []
		for k in d:
			if int(d[k].get("actor", 0)) == aid and not str(d[k].get("kind", "")) in ["被动", "领袖", "领袖说明", "光环"]:
				sids.append(int(k))
		_learn(u, sids)
		for e in lg.enemies:
			e.add_param(0, 1e12)
		for sid in sids:
			var sk := _view(u, sid)
			if sk.is_empty():
				sk = XDB.rec("Skills", sid)
			if sk.is_empty() or not int(sk.get("damage", {}).get("type", 0)) in [1, 5]:
				continue
			_fresh(lg)
			XTianqiSkills._fstore(lg).used[u] = int(lg.turn)  # 不出追加：只看这一根本身
			XTianqiWeakAffix.root_begin(lg, u, sk)
			var logs := lg.execute(u, sk, lg.enemies[0], true)
			var noted := (XTianqiWeakAffix._frame(lg).get("hits", []) as Array).size()
			var cast_id := int(XTianqiWeakAffix._frame(lg).get("skill", "0"))  # 付费后真正放的那招（魔雷老人 533 进阶后换成 5156）
			XTianqiWeakAffix.root_end(lg, u)
			var own := logs.filter(func(l): return _own_hit(l, u, cast_id)).size()
			var all_hits := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and l.get("target") is XEnemy).size()
			rows.append([aid, sid, cast_id, noted, own, all_hits])
			if noted != own or noted != all_hits:
				bad.append([aid, sid, cast_id, noted, own, all_hits])
		XTianqiSkills._fstore(lg).used.erase(u)
		lg.end_battle(0)
	print("AUDIT_ROWS ", JSON.stringify(rows))
	_check("audit_note_hit_8", bad.is_empty() and rows.size() >= 8, bad)
