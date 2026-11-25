extends Node
## 【cc·T263】天启篇：命运编织者 94「命运之手」6861 → 公共事件 1213 → 强制放 6862～6867、6875 的副本进卡（T255 B 组）。
## 稿《天启篇_全角色技能重构 v0.2》94 节：六种命运各三段合计 2.0～5.0（平均 3.6，物攻魔攻各半）、混沌 1.0～7.2、
## 连锁反应「连续同一种每次 +20%，最多 +60%」、终极命运「全体 6.0（六段）」。公共事件 1213（随机选命运、连锁状态、六种计数开关）原样保留。
## 一、卡面：七种命运的模块公式系数、浮动、范围；连锁状态 1481～1510 的 SkillPass 换成增量 20／20／20／0／0%（五级同存相加，R1）、全部战斗结束移除；6875 表头对象改敌方全体。
## 二、实打：天启篇档 94 一人上场连放命运之手，七种（混沌只在没穿法宝 4521 命运骰子时出，照原版公共事件）各至少出一次；打出的每一下都在卡的范围里；
##    （六种：没穿法宝 4521 命运骰子；穿了只抽五种、没有混沌，照原版）卡开关前后（XTianqiBase.PHASE4）各打一场，打印每种命运平均一发的伤害（交付单对比表从这里抄）。
##    连锁（R1）：1213 选命运那句随机改定值，连放同一种 8 发，第 1～8 发出手时 SkillPass 依次 +0/+20/+40/+60/+60/+60/+60/+60%；换别的命运后归零。
## 附带效果（T264）：火灼伤 18、风自己敏捷 +10%（10831）、地自己承伤 −10%（10832）、雷 10% 麻痹 100、冰敏捷 −10%（22），卡面与实打各查；混沌见 T268。
## 三、西游档：6875、连锁状态记录不变，6861 照旧调公共事件 1213。
## T268（引擎补完）：副属性抬下限（stat_floor：区间下限抬到合计 3、上限不动、浮动收窄）；终极 6875 逐段各一属性；6872 命运感知 −10%（天启篇九种属性 0.9、西游档 0.7）；
##   命运骰子 4521 每场一次自动重掷（第二次不触发、下一场重置、公共事件实跑走到钩子）；雷 10% 麻痹按整招掷（cast_pick）；混沌五选一（每发至多挂一项、五项都出过）；
##   self_states_on_hit 每次行动只挂一次、end_action 不再挂。

var results: Array = []
const FATES := [6862, 6863, 6864, 6865, 6866, 6867, 6875]
const NAMES := {6862: "火", 6863: "风", 6864: "地", 6865: "雷", 6866: "冰", 6867: "混沌", 6875: "终极"}


func _ready() -> void:
	XTianqiBalance.data()["combat_rules"]["base_damage"] = 0.13  # T501：本测试测机制不测 K，木桩血量按 K=0.13、敌人生命不折算写的；
	XTianqiBalance.data()["combat_rules"]["enemy_hp_pct"] = 100  # K 0.5＋敌人生命 ×40% 等于有效伤害 ×9.6，木桩会被一击打死，这里两项一起钉回旧口径
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


## 公共事件 1213 里给变量 1281（这次出哪种命运）赋随机数的指令，临时改成定值 v（1 火…6 混沌）；返回原指令表以便还原
func _force_fate(v: int) -> Array:
	var ce: Dictionary = XDB.rec("CommonEvents", 1213)
	var keep: Array = (ce.list as Array).duplicate(true)
	for c in ce.list:
		var p: Array = c.parameters
		if int(c.code) == 122 and int(p[0]) <= 1281 and 1281 <= int(p[1]) and int(p[3]) == 2:
			c.parameters = [p[0], p[1], 0, 0, v]
	return keep


func _chain_check() -> void:
	var lg := _logic(true, false)
	var a: XActor = lg.state.actor(94)
	var ce: Dictionary = XDB.rec("CommonEvents", 1213)
	var keep := _force_fate(1)  # 1＝火 6862
	var want := [0.0, 0.2, 0.4, 0.6, 0.6, 0.6, 0.6, 0.6]
	var seen := []
	var ok := true
	var hand := XDB.rec("Skills", 6861)
	for i in want.size():
		var row: Dictionary = a.passive_cache().skillPass.get(6862, {"rate": 0.0})
		var before := float(row.rate)
		var f := _fight_once(lg, a, hand)
		seen.append([i + 1, before, f, lg.state.variable(1282), (a.state_ids as Array).filter(func(id): return int(id) >= 1481 and int(id) <= 1510)])
		ok = ok and f == [6862] and absf(before - float(want[i])) < 0.0001
	_check("chain.same_fate_1_to_8", ok, seen)
	ce.list = keep
	keep = _force_fate(2)  # 换一种（2 号分支）：火的连锁清零
	var other := _fight_once(lg, a, hand)
	var after := float(a.passive_cache().skillPass.get(6862, {"rate": 0.0}).rate)
	_check("chain.switch_clears", other.size() == 1 and other[0] != 6862 and after == 0.0, [other, after])
	ce.list = keep
	# 再连放火 5 发到 5 级（1485），胜利收口后连锁状态全清（原版 1485 会留到下一场）
	keep = _force_fate(1)
	for i in 12:  # 偶有一回合 94 没出手（日志里只有敌人行动），放够 5 发为止
		if lg.state.variable(1282) >= 5:
			break
		_fight_once(lg, a, hand)
	ce.list = keep
	var had := (a.state_ids as Array).has(1485)
	lg.end_battle(0)
	var left := (a.state_ids as Array).filter(func(id): return int(id) >= 1481 and int(id) <= 1510)
	_check("chain.battle_end_clears", had and left.is_empty(), [had, left])
	print("FATE_CHAIN ", seen)


## T264 五种命运附带效果：卡面（effects／self_states）＋实打（定值命运，自己身上状态／敌人身上状态）
func _side_check() -> void:
	var want_eff := {6862: [18, 1.0], 6866: [22, 1.0]}  # 雷 6865 的 10% 麻痹 T268 改成整招掷一次（cast_pick），见 t268.*
	for sid in want_eff:
		var rec := XDB.rec("Skills", sid)
		var hit := false
		for e in rec.get("effects", []):
			if int(e.get("code", -1)) == 21 and int(e.get("dataId", -1)) == int(want_eff[sid][0]) and absf(float(e.get("value1", 0)) - float(want_eff[sid][1])) < 0.0001:
				hit = true
		_check("side.%d_effect" % sid, hit, rec.get("effects"))
	_check("side.6863_self", (XTianqiSkills.spec(6863).get("self_states", []) as Array).map(func(x): return int(x)) == [10831], XTianqiSkills.spec(6863).get("self_states"))
	_check("side.6864_self", (XTianqiSkills.spec(6864).get("self_states", []) as Array).map(func(x): return int(x)) == [10832], XTianqiSkills.spec(6864).get("self_states"))
	var wind := XDB.rec("States", 10831)
	var earth := XDB.rec("States", 10832)
	var wt := (wind.get("traits", []) as Array).filter(func(x): return int(x.code) == 21 and int(x.dataId) == 6 and absf(float(x.value) - 1.1) < 0.0001)
	var et := (earth.get("traits", []) as Array).filter(func(x): return int(x.code) == 23 and absf(float(x.value) - 0.9) < 0.0001)
	_check("side.state_wind_agi_110", wt.size() == 1 and int(wind.get("minTurns", 0)) == 2, wind.get("traits"))
	_check("side.state_earth_dmg_90", et.size() == 2 and int(earth.get("minTurns", 0)) == 2, earth.get("traits"))
	var cx: Array = XDB.rec("Skills", 6867).get("effects", [])
	var cids := cx.filter(func(e): return int(e.get("code", -1)) == 21 and int(e.get("dataId", -1)) in [18, 100, 22]).map(func(e): return int(e.dataId))
	_check("side.6867_no_t264_approx", cids.is_empty(), cx)  # T268：去掉 T264 的三项各 20%
	var th: Array = XDB.rec("Skills", 6865).get("effects", [])
	_check("side.6865_no_per_hit", th.filter(func(e): return int(e.get("code", -1)) == 21 and int(e.get("dataId", -1)) == 100).is_empty(), th)
	# 实打：定值命运连放，读自己身上状态（风、地）与敌人身上状态（火、雷、冰各只看出现过一次即可——雷 10%，放 40 发）
	var seen := {}
	for v in range(1, 7):
		var lg := _logic(true, false)
		var a: XActor = lg.state.actor(94)
		var ce: Dictionary = XDB.rec("CommonEvents", 1213)
		var keep := _force_fate(v)
		var hand := XDB.rec("Skills", 6861)
		for i in 40:
			var fired := []
			var foe_ids := []
			for r in lg.run_turn({a: [hand, lg.enemies[0]]}):
				if r is Dictionary and r.get("type") == "action" and r.get("skill") is Dictionary and FATES.has(int(r.skill.get("id", 0))):
					fired.append(int(r.skill.id))
				if r is Dictionary and r.get("type") == "hit" and r.get("target") == lg.enemies[0]:
					foe_ids.append_array((lg.enemies[0].state_ids as Array).duplicate())  # 每一发打完当场的敌人状态（战斗日志逐条记，结算在回合内）
			if not fired.is_empty():
				var sid: int = fired[0]
				if not seen.has(sid):
					seen[sid] = {"self10831": false, "self10832": false, "foe18": false, "foe100": false, "foe22": false}
				var row: Dictionary = seen[sid]
				row.self10831 = row.self10831 or (a.state_ids as Array).has(10831)
				row.self10832 = row.self10832 or (a.state_ids as Array).has(10832)
				row.foe18 = row.foe18 or foe_ids.has(18) or (lg.enemies[0].state_ids as Array).has(18)
				row.foe100 = row.foe100 or foe_ids.has(100) or (lg.enemies[0].state_ids as Array).has(100)
				row.foe22 = row.foe22 or foe_ids.has(22) or (lg.enemies[0].state_ids as Array).has(22)
			_heal_foes(lg)
			a.hp = a.mhp
			a.mp = a.mmp
		ce.list = keep
	_check("side.fight_fire", seen.has(6862) and seen[6862].foe18, seen.get(6862))
	_check("side.fight_wind", seen.has(6863) and seen[6863].self10831 and not seen[6863].self10832, seen.get(6863))
	_check("side.fight_earth", seen.has(6864) and seen[6864].self10832, seen.get(6864))
	# 雷 10% 麻痹：1 回合状态回合末就解除，实打读不到；只查卡面（side.6865_effect），不做实打断言
	_check("side.fight_ice", seen.has(6866) and seen[6866].foe22, seen.get(6866))
	print("FATE_SIDE ", seen)


class FakeInterp:
	extends RefCounted
	var logic


## 公共事件 1213 里「变量 1281 = 随机 lo～hi」两句（没骰子 1～6、有骰子 1～5）的随机范围临时改成 lo～hi（仍是随机赋值，走得到骰子钩子）
func _fate_range(lo: int, hi: int) -> Array:
	var ce: Dictionary = XDB.rec("CommonEvents", 1213)
	var keep: Array = (ce.list as Array).duplicate(true)
	for c in ce.list:
		var p: Array = c.parameters
		if int(c.code) == 122 and int(p[0]) <= 1281 and 1281 <= int(p[1]) and int(p[3]) == 2:
			c.parameters = [p[0], p[1], 0, 2, lo, hi]
	return keep


## T268 命运编织者引擎补完
func _t268_check() -> void:
	var SUBS := {6862: "mdf", 6863: "agi", 6864: "def", 6865: "atk", 6866: "mat", 6867: "luk"}
	# 一、副属性抬下限：标准线以下不抬；2 倍标准线抬满（下限＝合计 3、上限不动）；1.5 倍抬一半
	var floor_rows := []
	var floor_ok := true
	for sid in SUBS:
		var st: String = SUBS[sid]
		var lg := _logic(true, false)
		var a: XActor = lg.state.actor(94)
		var foe: XBattler = lg.enemies[0]
		var sp := XTianqiSkills.spec(sid)
		var c := XTianqiSkills._floor_cond(sp)
		var rec := XDB.rec("Skills", sid)
		var var0 := int(rec.damage.variance)
		var w := 0.0
		for k in sp.damage.stats:
			w += float(sp.damage.stats[k])
		var total := float(sp.damage.coef) * w * 3.0
		var lo := total * (1.0 - var0 / 100.0)
		var hi := total * (1.0 + var0 / 100.0)
		var i := XTianqiSkills.STATS.find(st)
		var line := XTianqiBase.line(float(a.level), st)
		var r0 := float(a.param(i)) / line
		var f0 := XTianqiSkills._floor_lift(a, c, sid)
		var row := {"sid": sid, "stat": st, "ratio0": snappedf(r0, 0.01), "lift0": f0}
		var ok0: bool = str(c.get("stat", "")) == st and (r0 > 1.0 or (float(f0[0]) == 1.0 and int(f0[1]) == var0))
		for target in [1.5, 2.5]:
			a.add_param(i, ceilf(line * target - float(a.param(i))) + 1.0)
			a.param_refresh()
			var f := XTianqiSkills._floor_lift(a, c, sid)
			var m := float(f[0])
			var v := int(f[1])
			var want_lo := lerpf(lo, maxf(lo, 3.0), clampf(float(a.param(i)) / line - 1.0, 0.0, 1.0))
			var got_lo := total * m * (1.0 - v / 100.0)
			var got_hi := total * m * (1.0 + v / 100.0)
			var fm := XTianqiSkills.formula(a, foe, rec) / ((float(sp.damage.stats.get("atk", 0)) * a.atk + float(sp.damage.stats.get("mat", 0)) * a.mat) * float(sp.damage.coef) * XTianqiSkills.level_scale(a))
			var sv := XTianqiSkills.seg_view(a, rec, 0)
			var okt := absf(got_lo - want_lo) < 0.06 and absf(got_hi - hi) < 0.06 and absf(fm - m) < 0.01 and int(sv.damage.variance) == v and XTianqiSkills.seg_on(a, rec)
			row["x%s" % target] = [snappedf(m, 0.001), v, snappedf(got_lo, 0.01), snappedf(got_hi, 0.01), snappedf(fm, 0.001)]
			ok0 = ok0 and okt
		floor_ok = floor_ok and ok0
		floor_rows.append(row)
	_check("t268.floor_lift", floor_ok, floor_rows)
	print("T268_FLOOR ", floor_rows)
	# 二、终极 6875 六段各一属性（六种命运此刻的属性，依次火风地雷冰混沌）
	var lg2 := _logic(true, false)
	var a2: XActor = lg2.state.actor(94)
	for sw in range(2261, 2267):
		lg2.state.set_switch(sw, true)
	var ce: Dictionary = XDB.rec("CommonEvents", 1213)
	var keep := _force_fate(1)
	var els := []
	for r in lg2.run_turn({a2: [XDB.rec("Skills", 6861), lg2.enemies[0]]}):
		if r is Dictionary and r.get("type") == "hit" and r.get("skill") is Dictionary and int(r.skill.get("id", 0)) == 6875 and r.get("target") == lg2.enemies[0]:
			els.append(int(r.skill.damage.elementId))
	ce.list = keep
	var want_els := []
	for sid in [6862, 6863, 6864, 6865, 6866, 6867]:
		want_els.append(int(XDB.rec("Skills", sid).damage.elementId))
	_check("t268.ult_seg_elements", els == want_els and want_els.size() == 6 and not want_els.has(1), [els, want_els])
	_check("t268.ult_record_untouched", int(XDB.rec("Skills", 6875).damage.elementId) == 1)  # 原记录不改（逐段只换视图）
	# 三、6872 命运感知：天启篇九种属性承伤 0.9，西游档照原版 0.7
	var tq_rates := []
	for e in range(1, 10):
		tq_rates.append(snappedf(a2.element_rate(e), 0.0001))
	var og := _logic(false, false)
	var xy_rates := []
	for e in range(1, 10):
		xy_rates.append(snappedf(og.state.actor(94).element_rate(e), 0.0001))
	_check("t268.6872_tq_90", tq_rates.all(func(x): return absf(x - 0.9) < 0.0001), tq_rates)
	_check("t268.6872_xy_70", xy_rates.all(func(x): return absf(x - 0.7) < 0.0001), xy_rates)
	# 四、命运骰子每场一次重掷（钩子单测＋公共事件实跑）
	var fi := FakeInterp.new()
	var mk := func(dice: bool, tianqi := true) -> XBattleLogic:
		var l := _logic(tianqi, dice)
		l.state.set_switch(2261, true)  # 火已集过
		l.state.set_variable(1281, 3)  # 上一发是地（火不接连锁）
		return l
	fi.logic = mk.call(true)
	var first := XTianqiSkills.fate_roll(fi, 1.0, func(): return 4)
	var second := XTianqiSkills.fate_roll(fi, 1.0, func(): return 4)
	fi.logic = mk.call(true)
	var next_battle := XTianqiSkills.fate_roll(fi, 1.0, func(): return 4)
	_check("t268.dice_once_per_battle", first == 4.0 and second == 1.0 and next_battle == 4.0, [first, second, next_battle])
	fi.logic = mk.call(true)
	var fresh := XTianqiSkills.fate_roll(fi, 2.0, func(): return 4)  # 风没集过：不重掷
	fi.logic.state.set_variable(1281, 1)
	var chain := XTianqiSkills.fate_roll(fi, 1.0, func(): return 4)  # 接上一发火（连锁）：不重掷
	fi.logic = mk.call(false)
	var no_dice := XTianqiSkills.fate_roll(fi, 1.0, func(): return 4)
	fi.logic = mk.call(true, false)
	var xiyou := XTianqiSkills.fate_roll(fi, 1.0, func(): return 4)
	XTianqiSkills.FATE_REROLL = false
	fi.logic = mk.call(true)
	var off := XTianqiSkills.fate_roll(fi, 1.0, func(): return 4)
	XTianqiSkills.FATE_REROLL = true
	_check("t268.dice_rules", fresh == 2.0 and chain == 1.0 and no_dice == 1.0 and xiyou == 1.0 and off == 1.0, [fresh, chain, no_dice, xiyou, off])
	var lgi: XBattleLogic = mk.call(true)
	var ai: XActor = lgi.state.actor(94)
	keep = _fate_range(1, 1)  # 只出火：火已集过、上一发是地 → 钩子触发一次（重掷还是火）
	var fired := _fight_once(lgi, ai, XDB.rec("Skills", 6861))
	var meta1 = lgi.get_meta("xtq_fate_reroll") if lgi.has_meta("xtq_fate_reroll") else 0
	ce.list = keep
	_check("t268.dice_hook_in_event", meta1 == 1 and fired.has(6862), [meta1, fired])
	# 五、混沌五选一：每发至多挂一项，五项都出过
	var lgc := _logic(true, false)
	var ac: XActor = lgc.state.actor(94)
	var foe_c: XBattler = lgc.enemies[0]
	keep = _force_fate(6)
	var per_cast_ok := true
	var seen_c := {}
	var multi := []
	for i in 60:
		for id in [18, 100, 22]:
			if foe_c.is_state_affected(id):
				foe_c.remove_state(id)
		for id in [10831, 10832]:
			if ac.is_state_affected(id):
				ac.remove_state(id)
		var got := {}
		var cast := false
		for r in lgc.run_turn({ac: [XDB.rec("Skills", 6861), foe_c]}):
			if r is Dictionary and r.get("type") == "action" and r.get("skill") is Dictionary and int(r.skill.get("id", 0)) == 6867:
				cast = true
			if cast and r is Dictionary and r.get("type") == "hit" and r.get("target") == foe_c:
				for id in [18, 100, 22]:
					if foe_c.is_state_affected(id):
						got[id] = true
		for id in [10831, 10832]:
			if ac.is_state_affected(id):
				got[id] = true
		# 挑中的那项读施放者身上记的最近一次（xtq_cast_pick）；麻痹 1 回合，回合末就解除，身上读不到，按挑中算
		var lp: Array = ac.get_meta("xtq_cast_pick") if ac.has_meta("xtq_cast_pick") else []
		var pk: Dictionary = lp[1] if cast and lp.size() == 2 and int(lp[0]) == 6867 else {}
		if ac.has_meta("xtq_cast_pick"):
			ac.remove_meta("xtq_cast_pick")
		var pid := int(pk.values()[0]) if not pk.is_empty() else 0
		if cast and (got.size() > 1 or pk.is_empty() or (pid != 100 and not got.has(pid))):  # 偶有一回合 94 没出手（同 _chain_check），不算
			per_cast_ok = false
			multi.append([got.keys(), pk])
		if pid > 0:
			seen_c[pid] = int(seen_c.get(pid, 0)) + 1
		_heal_foes(lgc)
		ac.hp = ac.mhp
		ac.mp = ac.mmp
	ce.list = keep
	_check("t268.chaos_one_per_cast", per_cast_ok, multi)
	_check("t268.chaos_all_five", seen_c.size() == 5, seen_c)
	print("T268_CHAOS ", seen_c)
	# 六、雷整招 10%：只查卡面 cast_pick（rate 10、只挑麻痹），没有实打放 60 发
	var tp: Dictionary = XTianqiSkills.spec(6865).get("cast_pick", {})
	_check("t268.thunder_per_cast", int(tp.get("rate", 0)) == 10 and tp.get("pick", []).size() == 1 and int(tp.pick[0].get("foe", 0)) == 100, tp)
	# 七、self_states_on_hit：同一次行动命中多次只挂一次；end_action 不再挂
	var lgs := _logic(true, false)
	var as_: XActor = lgs.state.actor(94)
	var rec3 := XDB.rec("Skills", 6863)
	var stf := XTianqiSkills._fstore(lgs)
	stf.depth = 0
	stf.act = {"u": as_, "skill": rec3, "targets": []}
	XTianqiSkills.after_apply(lgs, as_, rec3, lgs.enemies[0], {})
	var once := as_.is_state_affected(10831)
	as_.remove_state(10831)
	XTianqiSkills.after_apply(lgs, as_, rec3, lgs.enemies[0], {})
	var twice := as_.is_state_affected(10831)
	XTianqiSkills.end_action(lgs, as_, rec3)
	var by_end := as_.is_state_affected(10831)
	_check("t268.self_on_hit_once", once and not twice and not by_end, [once, twice, by_end])


## 放一次命运之手，返回这回合放出的命运号
func _fight_once(lg: XBattleLogic, a: XActor, hand: Dictionary) -> Array:
	var out := []
	for r in lg.run_turn({a: [hand, lg.enemies[0]]}):
		if r is Dictionary and r.get("type") == "action" and r.get("skill") is Dictionary:
			var sid := int(r.skill.get("id", 0))
			if FATES.has(sid):
				out.append(sid)
	_heal_foes(lg)
	a.hp = a.mhp  # 不用 recover_all：它会把身上的状态（连锁 1481～1510）一并清掉
	a.mp = a.mmp
	return out


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
	var un := str(ru.get("note", ""))
	_check("card.6875_header_all", un.contains("对象:敌方全体") and not un.contains("单个敌人"), un.substr(0, 200))
	_check("card.6875_ult", absf(vu / base_u - 1.0) < 0.01 and int(ru.scope) == 2 and int(ru.damage.variance) == 0, [vu, base_u, ru.scope, ru.damage.variance])
	var want := {1: 20, 2: 20, 3: 20, 4: 0, 5: 0}  # T263 R1：五级同存、SkillPass 相加，增量 20/20/20/0/0
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
	var be_ok := true
	for i in range(1481, 1511):
		be_ok = be_ok and bool(XDB.rec("States", i).get("removeAtBattleEnd", false))
	_check("card.chain_battle_end", be_ok)  # 原版 1485 不随战斗结束移除，天启篇改成移除
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
	# 二·连锁：公共事件 1213 选命运的随机数换成定值，连放同一种命运 8 发，读每发出手前身上的 SkillPass
	_chain_check()
	_side_check()
	_t268_check()
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
