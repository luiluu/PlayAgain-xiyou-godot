extends Node
## 去掉难度被动折成的全队 ×6（XTianqiNoX6，O-待定-1；守层者回血同比缩 O-待定-2；方案见交付单 cc_tianqi-no-x6）。开关开、关逐项对照：
## 一、我方出手：HP 伤害「关」≈「开」×6（三步逐个 ceil，1% 容差）；物理、魔法、暴击都验。
##     治疗（难度适应 ×5 照旧）、MP 伤害（×6 照旧）、敌人打角色：开关两边逐项相等。
## 二、固定减伤：守层者伤害抵抗定成「关」时打掉一半，「开」×6 ≈「关」（max(0,x−F/6)×6＝max(0,6x−F)）。
## 三、敌人血量：普通敌人 ÷6；24 层守层者那场、20 层楼层敌群、34 层鸿钧、七印里副本按守层者重算的新总血 ÷6；骑士不变。
## 四、敌人回血：守层者清心咒（450＋魔攻×1000，读不到 mhp）开＝关×1/6×守层者重算缩放比 k（O-待定-2），GUARDIAN_HEAL 关只 ×1/6；
##     我方治疗、骑士回血不缩；公式读 mhp 的不缩。敌人打敌人（混乱、反射）÷6。
## 五、吸取、直接扣血：我方吸取回血 ×6（按 ×6 前）、敌人吸取回血 ÷6；scale_direct 我方打敌人 ÷6、别的不动；五条悟试炼 settle 开 1 关 6。
## 六、西游档：开关两边伤害、治疗、敌人血量逐项相等；天启篇档存读一轮不多存键、读回来照样按新数。
## 七、依赖：O-421 关掉时本功能跟着关（三个被动是真状态，照旧 ×6）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


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


func _ids(tier: String) -> Array:
	return XTianqiSkills.ids(tier, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and not [95, 173].has(id))


func _state(key: String) -> XState:
	var w := _ids(XTier.WEAK)
	var lineup := [_ids(XTier.STRONG)[0], w[0], w[1], w[2], w[3]]
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(int(id)).recover_all()
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_no_x6")
	seed(20261114)
	_damage()
	_flat()
	_enemy_hp()
	_enemy_heal()
	_drain_direct()
	_mp_flat_absorb()
	_programs()
	_xiyou()
	_save_and_dependency()
	XTianqiNoX6.ENABLED = true
	XTianqiNoX6.GUARDIAN_HEAL = true
	XTianqiNoDiffPassive.ENABLED = true
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _hit(item: Dictionary, a: XBattler, b: XBattler, crit := false) -> float:
	var res := XDamage.calculate(item, a, b, {"critical": crit, "variance": false})
	return XDamage.finish(res, item, a, b, false)


## 开关开、关各算一次
func _both(f: Callable) -> Array:
	XTianqiNoX6.ENABLED = true
	var on = f.call()
	XTianqiNoX6.ENABLED = false
	var off = f.call()
	XTianqiNoX6.ENABLED = true
	return [on, off]


## 关＝开 ×6（三步逐个 ceil，还和别的确认、受击效果交错取整，所以给 1% 容差）
static func _x6(on: float, off: float) -> bool:
	return on > 0.0 and absf(off - on * 6.0) <= maxf(6.0, off * 0.01)


# ---- 一、我方出手 ----

func _damage() -> void:
	var s := _state("jianxian")
	var a := s.actor(int(s.battle_slots[0]))
	var ally := s.actor(int(s.battle_slots[1]))
	ally.hp = 1
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	for sid in [1, 902, 908]:
		for crit in [false, true]:
			var v := _both(func(): return _hit(XDB.rec("Skills", sid), a, enemy, crit))
			_check("dmg_%d_%s" % [sid, crit], _x6(float(v[0]), float(v[1])), v)
	for sid in [8, 335]:
		var h := _both(func(): return _hit(XDB.rec("Skills", sid), a, ally))
		_check("heal_%d_kept_x5" % sid, float(h[0]) < 0.0 and h[0] == h[1], h)
	var mp: Dictionary = XDB.rec("Skills", 1).duplicate(true)
	mp.damage.type = 2
	var m := _both(func(): return _hit(mp, a, enemy))
	_check("mp_damage_kept_x6", float(m[0]) > 0.0 and m[0] == m[1], m)
	var t := _both(func(): return _hit(XDB.rec("Skills", 1), enemy, a))
	_check("taken_same", t[0] == t[1], t)
	# 九死：不分档
	var s9 := _state("jiusi")
	var a9 := s9.actor(int(s9.battle_slots[0]))
	var v9 := _both(func(): return _hit(XDB.rec("Skills", 1), a9, enemy))
	_check("dmg_jiusi", _x6(float(v9[0]), float(v9[1])), v9)


# ---- 二、固定减伤 ----

func _flat() -> void:
	var s := _state("jianxian")
	var a := s.actor(int(s.battle_slots[0]))
	var g := XEnemy.new().setup(527, 3, 100.0)  # 24 层守层者
	XGuardianRework.measure_neutral = true
	var raw := _both(func(): return _hit(XDB.rec("Skills", 1), a, g))
	var hr := {}
	for el in range(0, 16):
		hr[el] = float(raw[1]) * 0.5  # 关：×6 后的一半
	var v := _both(func():
		g.passive_cache()["harmRe"] = hr
		return _hit(XDB.rec("Skills", 1), a, g))
	XGuardianRework.measure_neutral = false
	g.refresh_passive()
	_check("flat_scaled", float(v[0]) > 0.0 and absf(float(v[0]) * 6.0 - float(v[1])) <= 12.0 and float(v[1]) < float(raw[1]) * 0.6, [raw, v])


# ---- 三、敌人血量 ----

func _total(troop: int, s: XState) -> float:
	var l := XBattleLogic.new()
	l.setup(troop, s)
	return l.enemies.reduce(func(t, x): return t + x.mhp, 0.0)


func _enemy_hp() -> void:
	var s := _state("jianxian")
	var n := _both(func(): return XEnemy.new().setup(1, 3, 100.0).mhp)
	_check("normal_hp_div6", absf(float(n[0]) * 6.0 - float(n[1])) <= 6.0, n)
	var g := _both(func(): return _total(XGuardianRework.TROOPS[24], s))
	_check("guardian24_hp", absf(float(g[0]) - 3000000.0 * 8 / 6.0) < 10.0 and absf(float(g[1]) - 3000000.0 * 8) < 10.0, g)
	var m20 := -1
	for i in range(1, 400):
		if not XDB.rec("MapInfos", i).is_empty() and XDungeon.map_floor(i) == 20:
			m20 = i
			break
	s.map_id = m20
	var w := _both(func(): return _total(453, s))
	_check("world20_hp", m20 > 0 and absf(float(w[0]) * 6.0 - float(w[1])) / float(w[1]) < 0.001, [m20, w])
	s.map_id = 4
	s.flags.tianqi["line"] = "war"  # 鸿钧要选过线（XTianqiSummit.allowed）
	var h := _both(func():
		XTianqiSummit.prepare_hongjun(s)
		return _total(int(XTianqiSummit.data().hongjun.troop), s))
	_check("hongjun_hp", absf(float(h[0]) - 6110000.0 * 8 / 6.0) < 10.0 and absf(float(h[1]) - 6110000.0 * 8) < 10.0, h)
	var q := _both(func():
		XTianqiQiyinRule.prepare("bai", true)
		return _total(int(XTianqiQiyin.seal_info("bai").troops[-1]), s))
	_check("qiyin_hp", float(q[0]) > 0.0 and absf(float(q[0]) * 6.0 - float(q[1])) / float(q[1]) < 0.001, q)
	var k := _both(func():
		XTianqiHorsemen.prepare("war", s, "body")
		return _total(int(XTianqiLine.data("war").shell_troop), s))
	_check("knight_untouched", float(k[0]) > 0.0 and k[0] == k[1], k)
	# 五条悟试炼：影子生命里的我方结算乘区
	var st := _both(func(): return XTianqiGojoTrial.settle())
	_check("gojo_settle", st == [1.0, 6.0], st)


# ---- 四、敌人回血 ----

func _heal_on(e: XEnemy, sid: int) -> float:
	var item := XDB.rec("Skills", sid)
	return float(XDamage.calculate(item, e, e, {"variance": false}).value)


func _enemy_heal() -> void:
	var s := _state("jianxian")
	var l := XBattleLogic.new()
	l.setup(XGuardianRework.TROOPS[26], s)  # 金角、银角：清心咒 450＋魔攻×1000
	var e: XEnemy = l.enemies[0]
	var k := float(e.get_meta(XTianqiNoX6.META_HP_K, 1.0))
	var v := _both(func(): return _heal_on(e, 3570))
	_check("guardian_heal_scaled_k", k < 0.5 and float(v[1]) < 0.0 and absf(float(v[0]) - roundf(float(v[1]) * k / 6.0)) <= 1.0, [k, v])
	XTianqiNoX6.GUARDIAN_HEAL = false
	var v2 := _both(func(): return _heal_on(e, 3570))
	XTianqiNoX6.GUARDIAN_HEAL = true
	_check("guardian_heal_o2_off_div6", absf(float(v2[0]) - roundf(float(v2[1]) / 6.0)) <= 1.0 and v2[1] == v[1], v2)
	var item_mhp := {"damage": {"formula": "b.mhp * 0.3", "type": 3}}
	_check("mhp_formula_untouched", XTianqiNoX6.enemy_heal(item_mhp, e, e) == 1.0)
	var a := s.actor(int(s.battle_slots[0]))
	_check("party_heal_untouched", XTianqiNoX6.enemy_heal(XDB.rec("Skills", 8), a, e) == 1.0 and XTianqiNoX6.heal_scale(a) == 1.0)
	XTianqiHorsemen.prepare("war", s, "body")
	var kl := XBattleLogic.new()
	kl.setup(int(XTianqiLine.data("war").shell_troop), s)
	_check("knight_heal_untouched", not kl.enemies.is_empty() and kl.enemies.all(func(x): return XTianqiNoX6.heal_scale(x, true) == 1.0))
	# 敌人打敌人（混乱、魔法反射）：不带 ×6，跟着血量缩
	var n1 := XEnemy.new().setup(1, 3, 100.0)
	var n2 := XEnemy.new().setup(1, 3, 100.0)
	var ee := _both(func(): return _hit(XDB.rec("Skills", 1), n1, n2))
	_check("enemy_on_enemy_div6", float(ee[1]) > 0.0 and absf(float(ee[0]) - maxf(1.0, roundf(float(ee[1]) / 6.0))) <= 1.0, ee)


# ---- 五、吸取、直接扣血 ----

func _drain_direct() -> void:
	var s := _state("jianxian")
	var a := s.actor(int(s.battle_slots[0]))
	var b := s.actor(int(s.battle_slots[1]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	var e2 := XEnemy.new().setup(1, 3, 100.0)
	var d := _both(func(): return [XTianqiNoX6.drain_gain(a, e, 100.0), XTianqiNoX6.drain_gain(e, a, 600.0), XTianqiNoX6.steal_mult(a),
		XTianqiNoX6.drain_gain(e, e2, 600.0), XTianqiNoX6.drain_gain(a, b, 600.0)])
	_check("drain_gain", d[0] == [600.0, 100.0, 6.0, 600.0, 600.0] and d[1] == [100.0, 600.0, 1.0, 600.0, 600.0], d)
	# 返修 P2-3：普通敌人混乱／反射打普通敌人，伤害已在 finish ÷6，吸取、吸血回血不能再 ÷6（原来成了 1/36）
	var bm := _both(func(): return [XTianqiNoX6.back_mult(e, e2), XTianqiNoX6.back_mult(e, a), XTianqiNoX6.back_mult(a, e), XTianqiNoX6.back_mult(a, b)])
	_check("back_mult", bm[0] == [1.0, 1.0 / 6.0, 6.0, 1.0] and bm[1] == [1.0, 1.0, 1.0, 1.0], bm)
	# 混乱打队友：确认阶段照旧 ×6（只对敌人目标不乘）
	b.hp = b.mhp
	var ff := _both(func(): return _hit(XDB.rec("Skills", 1), a, b))
	_check("party_on_party_kept_x6", float(ff[0]) > 0.0 and ff[0] == ff[1], ff)
	var x := _both(func(): return [XTianqiNoX6.scale_direct(a, e, 600.0), XTianqiNoX6.scale_direct(a, b, 600.0), XTianqiNoX6.scale_direct(e, a, 600.0), XTianqiNoX6.scale_direct(a, e, 3.0)])
	_check("scale_direct", x[0] == [100.0, 600.0, 600.0, 1.0] and x[1] == [600.0, 600.0, 600.0, 3.0], x)
	# YEP 吸血：一次 30% 吸血的技能，按 ×6 前的伤害回
	var item := {"lifeSteal": {"hpRate": 0.3}, "hitType": 1}
	var ls := _both(func(): return XLifeSteal.amount(a, item, 1000.0 * XTianqiNoX6.steal_mult(a)))
	_check("life_steal", ls == [1800.0, 300.0], ls)


# ---- 返修 P2-1：MP 伤害＋固定减伤、元素吸收 ----

func _mp_flat_absorb() -> void:
	var s := _state("jianxian")
	var a := s.actor(int(s.battle_slots[0]))
	var g := XEnemy.new().setup(1, 3, 100.0)
	var mp: Dictionary = XDB.rec("Skills", 1).duplicate(true)
	mp.damage.type = 2
	var raw := _both(func(): return _hit(mp, a, g))
	var hr := {}
	for el in range(0, 16):
		hr[el] = float(raw[1]) * 0.5
	var v := _both(func():
		g.passive_cache()["harmRe"] = hr
		return _hit(mp, a, g))
	g.refresh_passive()
	_check("mp_flat_kept", float(v[1]) > 0.0 and float(v[1]) < float(raw[1]) * 0.6 and v[0] == v[1], [raw, v])
	# 元素吸收（元素牌组关着时才走得到；天启篇默认牌组开、敌人不吸收）：HP 吸收回血 ÷6，MP 吸收不缩
	var deck := XTianqiElements.DECK
	XTianqiElements.DECK = false
	var rec: Dictionary = XDB.rec("Enemies", 1).duplicate(true)
	rec.traits = (rec.get("traits", []) as Array) + [{"code": 11, "dataId": 2, "value": -1.0}]
	rec["_ref"] = "test"  # 按守层者口径重标过的敌人（heal_scale＝1/6）
	var ab := XEnemy.new()
	ab.setup_horseman(1, rec, false)
	var hp_item: Dictionary = XDB.rec("Skills", 1).duplicate(true)
	hp_item.damage.elementId = 2
	var mp_item: Dictionary = hp_item.duplicate(true)
	mp_item.damage.type = 2
	var h := _both(func(): return float(XDamage.calculate(hp_item, a, ab, {"variance": false}).value))
	var m := _both(func(): return float(XDamage.calculate(mp_item, a, ab, {"variance": false}).value))
	XTianqiElements.DECK = deck
	_check("hp_absorb_div6", float(h[1]) < 0.0 and absf(float(h[0]) - XPower.js_round(float(h[1]) / 6.0)) <= 1.0, h)
	_check("mp_absorb_kept", float(m[1]) < 0.0 and m[0] == m[1], m)


# ---- 返修 P2-2：状态脚本里绝对值的 gainHp ----

func _programs() -> void:
	var s := _state("jianxian")
	var a := s.actor(int(s.battle_slots[0]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	var r := _both(func(): return [
		XTianqiNoX6.program_hp({"state_id": 50, "origin": a, "user": a}, e, -1250.0),      # 雷鸣符文手套：我方固定附伤 → ÷6
		XTianqiNoX6.program_hp({"state_id": 260, "origin": a, "user": a}, e, -600.0),      # 附骨之疽：我方来源扣敌人 → ÷6
		XTianqiNoX6.program_hp({"state_id": 260, "origin": e, "user": e}, a, -600.0),      # 敌人来源扣我方 → 不动
		XTianqiNoX6.program_hp({"state_id": 260, "origin": e, "user": e}, e, 2400000.0),   # 敌人来源给自己回（mat×5×4000）→ ×heal_scale
		XTianqiNoX6.program_hp({"state_id": 1061, "origin": a, "user": e}, e, -900.0),     # 混元护体：我方受击反弹给敌人 → ÷6
		XTianqiNoX6.program_hp({"state_id": 1299, "origin": a, "user": a}, e, -600.0),     # 半步真仙：等于本次伤害（新口径）→ 不动
		XTianqiNoX6.program_hp({"state_id": 1642, "origin": a, "user": a}, e, -600.0),     # 千刃乱雨：目标当前生命百分比 → 不动
	])
	_check("program_hp", r[0] == [-208.0, -100.0, -600.0, 400000.0, -150.0, -600.0, -600.0] and r[1] == [-1250.0, -600.0, -600.0, 2400000.0, -900.0, -600.0, -600.0], r)
	# 真跑一次：状态 50（雷鸣符文手套）的确认脚本，我方普攻打敌人：固定 1250×属性有效度的附伤 ÷6；敌人持有时不缩
	var run50 := func(holder: XBattler, target: XBattler) -> float:
		var rc := XResourceContext.new()
		var before: float = target.hp
		var atk: Dictionary = XDB.rec("Skills", 1).duplicate(true)
		atk.hitType = 1  # 脚本只认物理普攻（本作 1 号技能是魔法类型）
		XStateEffects.run_one("confirm", holder, XDB.rec("States", 50), {"attacker": holder, "defender": target, "item": atk,
			"resources": rc, "value": 100.0, "execute": true})
		return before - target.hp
	var t := XEnemy.new().setup(1, 3, 100.0)
	t.add_param(0, 1.0e7)
	var hit50 := _both(func():
		t.recover_all()
		a.recover_all()
		return [run50.call(a, t), ceilf(t.element_rate(5) * 1250.0)])
	_check("state50_extra_div6", absf(float(hit50[1][0]) - float(hit50[1][1])) <= 1.0 and absf(float(hit50[0][0]) - maxf(1.0, floorf(float(hit50[1][1]) / 6.0))) <= 1.0, hit50)


# ---- 六、西游档 ----

func _xiyou() -> void:
	var s := _state("jianxian")
	var lineup: Array = s.battle_slots.slice(0, 2)
	var p := XState.new_game_blank()
	for id in lineup:
		p.add_actor(int(id))
	XState.current = p
	var a := p.actor(int(lineup[0]))
	a.recover_all()
	var ally := p.actor(int(lineup[1]))
	ally.hp = 1
	var v := _both(func():
		var enemy := XEnemy.new().setup(1, 3, 100.0)
		return [enemy.mhp, _hit(XDB.rec("Skills", 1), a, enemy), _hit(XDB.rec("Skills", 8), a, ally), _hit(XDB.rec("Skills", 1), enemy, a),
			XTianqiNoX6.hp_unit(), XTianqiNoX6.skip_types(), XTianqiNoX6.steal_mult(a)])
	_check("xiyou_untouched", v[0] == v[1] and float(v[0][4]) == 1.0 and (v[0][5] as Array).is_empty() and float(v[0][6]) == 1.0, v)


# ---- 六之二、存读；七、依赖 O-421 ----

func _save_and_dependency() -> void:
	var s := _state("jianxian")
	var keys_before: Array = s.flags.tianqi.keys()
	var s2 := kit.roundtrip()
	XState.current = s2
	var keys_after: Array = s2.flags.tianqi.keys()
	keys_before.sort()
	keys_after.sort()
	var a := s2.actor(int(s2.battle_slots[0]))
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	var v := _both(func(): return _hit(XDB.rec("Skills", 1), a, enemy))
	_check("save_no_new_keys", keys_before == keys_after, [keys_before, keys_after])
	_check("save_loaded_uses_new", _x6(float(v[0]), float(v[1])), v)
	XTianqiNoDiffPassive.ENABLED = false
	var dep := [XTianqiNoX6.on(s2), XTianqiNoX6.hp_unit(s2), XTianqiGojoTrial.settle()]
	XTianqiNoDiffPassive.ENABLED = true
	_check("needs_o421", dep == [false, 1.0, 6.0], dep)
