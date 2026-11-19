extends Node
## 【cc·T263】天启篇：命运编织者 94「命运之手」6861 → 公共事件 1213 → 强制放 6862～6867、6875 的副本进卡（T255 B 组）。
## 稿《天启篇_全角色技能重构 v0.2》94 节：六种命运各三段合计 2.0～5.0（平均 3.6，物攻魔攻各半）、混沌 1.0～7.2、
## 连锁反应「连续同一种每次 +20%，最多 +60%」、终极命运「全体 6.0（六段）」。公共事件 1213（随机选命运、连锁状态、六种计数开关）原样保留。
## 一、卡面：七种命运的模块公式系数、浮动、范围；连锁状态 1481～1510 的 SkillPass 换成 0／20／40／60／60%。
## 二、实打：天启篇档 94 一人上场连放命运之手，七种（混沌要学 4521，照原版公共事件）各至少出一次；打出的每一下都在卡的范围里；
##    （六种：没穿法宝 4521 命运骰子；穿了只抽五种、没有混沌，照原版）卡开关前后（XTianqiBase.PHASE4）各打一场，打印每种命运平均一发的伤害（交付单对比表从这里抄）。
## 三、西游档：6875、连锁状态记录不变，6861 照旧调公共事件 1213。

var results: Array = []
const FATES := [6862, 6863, 6864, 6865, 6866, 6867, 6875]
const NAMES := {6862: "火", 6863: "风", 6864: "地", 6865: "雷", 6866: "冰", 6867: "混沌", 6875: "终极"}


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _logic(tianqi: bool, dice: bool) -> XBattleLogic:
	var lineup := [94]
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
	s.random_master = XRandomStream.hex64(20261119)
	var a: XActor = s.actor(94)
	a.change_level(99)
	a.learn_skill(6861)
	if dice:  # 原版公共事件 1213：穿着专属法宝 4521 命运骰子（正式版）只在五种里抽、没有混沌；没穿六种（照原版，不改）
		var slots := a.equip_slots()
		for i in slots.size():
			if int(slots[i]) == 13:
				a.equips[i] = XActor.make_equip("armor", 4521)
				break
		a.refresh_passive()
	a.recover_all()
	for sw in range(2261, 2267):
		s.set_switch(sw, false)
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	_heal_foes(lg)
	return lg


func _heal_foes(lg: XBattleLogic) -> void:
	for e in lg.enemies:
		if e.mhp < 900000000:
			e.add_param(0, 999999999)
		e.recover_all()


func _has_effect(rec: Dictionary, code: int, data_id: int) -> bool:
	for e in rec.get("effects", []):
		if int(e.get("code", -1)) == code and int(e.get("dataId", -1)) == data_id:
			return true
	return false


## 连放 n 回合命运之手；返回 {casts: {技能号: [[第一个敌人这一发的合计伤害, 段数, 打到几个敌人]…]}, base: (攻＋魔攻)÷2, bad: 负血等}
func _fight(lg: XBattleLogic, turns: int) -> Dictionary:
	var a: XActor = lg.state.actor(94)
	var casts := {}
	var bad := []
	var hand := XDB.rec("Skills", 6861)
	for i in turns:
		if lg.is_over():
			bad.append("battle_over_at_%d" % i)
			break
		var logs := lg.run_turn({a: [hand, lg.enemies[0]]})
		var cur := {}
		for r in logs:
			if not (r is Dictionary):
				continue
			if r.get("type") == "action":
				_flush(cur, casts)
				cur = {}
				var sid := int((r.skill as Dictionary).get("id", 0)) if r.get("skill") is Dictionary else 0
				if FATES.has(sid):
					cur = {"id": sid, "dmg": 0.0, "hits": 0, "foes": {}}
			elif r.get("type") == "hit" and not cur.is_empty() and r.get("skill") is Dictionary and int(r.skill.get("id", 0)) == int(cur.id):
				var hp := float(r.get("hp", 0.0))
				if hp < 0.0:
					bad.append("heal_on_foe %d" % int(cur.id))
				cur.foes[r.target] = true
				if r.target == lg.enemies[0]:
					cur.dmg += hp
					cur.hits += 1
		_flush(cur, casts)
		if a.hp < 0 or lg.state.gold < 0:
			bad.append("neg_hp_or_gold")
		_heal_foes(lg)
		a.recover_all()
	return {"casts": casts, "base": (a.atk + a.mat) / 2.0, "bad": bad}


func _flush(cur: Dictionary, casts: Dictionary) -> void:
	if cur.is_empty():
		return
	if not casts.has(cur.id):
		casts[cur.id] = []
	casts[cur.id].append([cur.dmg, cur.hits, cur.foes.size()])


func _avg(rows: Array) -> float:
	if rows.is_empty():
		return 0.0
	var t := 0.0
	for r in rows:
		t += float(r[0])
	return t / rows.size()


func _report(tag: String, f: Dictionary) -> void:
	var line := []
	for sid in FATES:
		var rows: Array = f.casts.get(sid, [])
		line.append("%s %d 次 平均 %.0f（÷(攻+魔攻)/2＝%.2f）" % [NAMES[sid], rows.size(), _avg(rows), _avg(rows) / maxf(1.0, f.base)])
	print("FATE_DMG[%s] base=%.0f | %s" % [tag, f.base, " | ".join(line)])


func _run() -> void:
	XMessageBox.auto = true
	seed(20261119)
	XTianqiBase.clear_cache()
	XTianqiBase.PHASE4 = true
	# 一、卡面
	var lg := _logic(true, false)
	_check("tq.active", XTianqi.active(lg.state))
	var a: XActor = lg.state.actor(94)
	var foe: XBattler = lg.enemies[0]
	var hand := XDB.rec("Skills", 6861)
	_check("tq.6861_keeps_ce", _has_effect(hand, 44, 1213), hand.get("effects"))
	var he: Array = XTianqiSkills.spec(6861).get("effects", [])
	_check("tq.6861_card_same", he.size() == 1 and int(he[0].code) == 21 and int(he[0].dataId) == 1517 and absf(float(he[0].value1) - 0.1) < 0.0001, he)
	var base := (0.6 * a.atk + 0.6 * a.mat) * XTianqiSkills.level_scale(a)
	for sid in [6862, 6863, 6864, 6865, 6866]:
		var r := XDB.rec("Skills", sid)
		var v := XTianqiSkills.formula(a, foe, r)
		_check("card.%d_seg" % sid, absf(v / base - 1.0) < 0.01 and int(r.damage.variance) == 38 and int(r.scope) == 1, [v, base, r.damage.variance])
	var rc := XDB.rec("Skills", 6867)
	var vc := XTianqiSkills.formula(a, foe, rc)
	var base_c := (0.68 * a.atk + 0.68 * a.mat) * XTianqiSkills.level_scale(a)
	_check("card.6867_chaos", absf(vc / base_c - 1.0) < 0.01 and int(rc.damage.variance) == 76, [vc, base_c, rc.damage.variance])
	var ru := XDB.rec("Skills", 6875)
	var vu := XTianqiSkills.formula(a, foe, ru)
	var base_u := (0.5 * a.atk + 0.5 * a.mat) * XTianqiSkills.level_scale(a)
	_check("card.6875_ult", absf(vu / base_u - 1.0) < 0.01 and int(ru.scope) == 2 and int(ru.damage.variance) == 0, [vu, base_u, ru.scope, ru.damage.variance])
	var want := {1: 0, 2: 20, 3: 40, 4: 60, 5: 60}
	var sp_ok := true
	var sp_seen := []
	for k in range(6):
		var first := 1481 + k * 5
		for lv in range(1, 6):
			var st := XDB.rec("States", first + lv - 1)
			var tag := ""
			for key in st.get("meta", {}):
				if str(key).begins_with("SkillPass"):
					tag = str(st.meta[key])
			var exp := "" if want[lv] == 0 else "%d%%" % want[lv]
			if tag.replace(" ", "") != exp:
				sp_ok = false
				sp_seen.append([first + lv - 1, tag])
	_check("card.chain_states", sp_ok, sp_seen)
	# 二、实打：卡开着（天启篇现行）
	var f_on := _fight(lg, 80)
	_report("卡开", f_on)
	for sid in FATES:
		_check("fight.%d_fired" % sid, f_on.casts.has(sid), f_on.casts.keys())
	_check("fight.no_bad", f_on.bad.is_empty(), f_on.bad)
	var hits_ok := true
	var seen_hits := []
	for sid in f_on.casts:
		for row in f_on.casts[sid]:
			var want_hits := 6 if sid == 6875 else 3
			if int(row[1]) != want_hits:
				hits_ok = false
				seen_hits.append([sid, row])
	_check("fight.hits", hits_ok, seen_hits)
	var ult_all := true
	for row in f_on.casts.get(6875, []):
		ult_all = ult_all and int(row[2]) == lg.enemies.size()
	_check("fight.6875_all_foes", ult_all and lg.enemies.size() >= 1, [f_on.casts.get(6875), lg.enemies.size()])
	# 每一发（第一个敌人身上的合计）不超过 卡上限×连锁 +60%×（攻魔各半的上限，防御只减不加）：普通 5.0、混沌 7.2、终极 6.0
	var top := {6867: 7.3, 6875: 6.1}
	var cap_ok := true
	var over := []
	var unit: float = f_on.base * XTianqiSkills.level_scale(a) * 1.25  # 余量：被动、元素有效度
	for sid in f_on.casts:
		for row in f_on.casts[sid]:
			if float(row[0]) > float(top.get(sid, 5.1)) * 1.6 * unit:
				cap_ok = false
				over.append([sid, row[0], unit])
	_check("fight.in_card_range", cap_ok, over)
	# 卡关着（原版公式）对照：只打印，断言原版远大于卡
	XTianqiBase.PHASE4 = false
	XTianqiBase.clear_cache()
	var lg0 := _logic(true, false)
	var f_off := _fight(lg0, 80)
	_report("卡关", f_off)
	XTianqiBase.PHASE4 = true
	XTianqiBase.clear_cache()
	var ratio_ok := true
	for sid in FATES:
		if f_off.casts.has(sid) and f_on.casts.has(sid):
			ratio_ok = ratio_ok and _avg(f_off.casts[sid]) > _avg(f_on.casts[sid]) * 10.0
	_check("fight.raw_much_bigger", ratio_ok)
	# 穿法宝 4521：照原版五种（没有混沌），五种出齐也接终极
	var lg5 := _logic(true, true)
	var f5 := _fight(lg5, 60)
	_check("fight.dice_no_chaos", not f5.casts.has(6867) and f5.casts.has(6862) and f5.casts.has(6875), f5.casts.keys())
	_check("fight.dice_no_bad", f5.bad.is_empty(), f5.bad)
	# 三、西游档对照
	var og := _logic(false, false)
	_check("xy.not_active", not XTianqi.active(og.state))
	var ox := XDB.rec("Skills", 6875)
	_check("xy.6875_raw", str(ox.damage.formula).begins_with("(a.atk+a.mat+2000)*100") and int(ox.scope) == 1, ox.damage.formula)
	_check("xy.6861_ce", _has_effect(XDB.rec("Skills", 6861), 44, 1213))
	_check("xy.chain_raw", str(XDB.rec("States", 1482).get("note", "")).contains("SkillPass6862: 200%"))
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
