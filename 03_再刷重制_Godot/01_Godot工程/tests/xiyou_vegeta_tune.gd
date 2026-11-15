extends Node
## 贝吉特优化调整（XVegetaTune，v0.01.08）专项：
## 一、读表改原件：吃瘪之力 2561 受伤倍率、自我终伤 2777 每层倍率、公共事件 1722 层数封顶、合体赛亚人 2565（乙档）、技能说明。
## 二、按真实状态效果程序结算：吃瘪之力承伤、自我极意功按层数的终伤、合体赛亚人终伤／暴击。
## 三、自我极意功层数每场战斗开局清零（XBattleLogic.setup）。
## 四、别的状态、技能不动；ENABLED＝false 回原版。
## 五、合体赛亚人拆开（Kyo 11-15 拍板 D3 选 B）：9940 改挂 2565 的复制 2803，9933「普通一拳」照旧挂 2565；
##     甲档 9940 挂的状态结算与原版逐值相同、2803 与 2565 除号外一字不差；乙档只改 2803，2565 与 9933 不变。
## 六、2565 与 2803 互斥（co 核查 P2）：两技能都会、先有 2565 再学 9940，整场出手伤害与原版相同；战中存读档往返、关掉开关回退也相同。
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _reload() -> void:
	for n in ["Skills", "States", "CommonEvents"]:
		XDB._tables.erase(n)


func _run() -> void:
	XMessageBox.auto = true
	_check("defaults", XVegetaTune.ENABLED and XVegetaTune.TIER == "甲")
	var orig := _snapshot(false, "甲")
	var a := _snapshot(true, "甲")
	var b := _snapshot(true, "乙")
	_check("orig_chibie", is_equal_approx(orig.chibie, 10.0), orig.chibie)
	_check("orig_ego20", is_equal_approx(orig.ego20, 100.0 + ceilf(100.0 * 30.0)), orig.ego20)
	_check("orig_ego_cap", orig.cap == 20)
	_check("orig_fusion", is_equal_approx(orig.fusion, 288.0) and is_equal_approx(orig.fusion_crit, 288.0 + ceilf(288.0 * 1.88)), [orig.fusion, orig.fusion_crit])
	_check("jia_chibie", is_equal_approx(a.chibie, 50.0), a.chibie)
	_check("jia_ego10", is_equal_approx(a.ego10, 100.0 + 500.0), a.ego10)
	_check("jia_ego_cap", a.cap == 10)
	_check("jia_fusion_same", a.fusion == orig.fusion and a.fusion_crit == orig.fusion_crit)
	_check("jia_desc", a.desc_chibie.contains("减少50%受到的伤害") and a.desc_ego.contains("增加50%终伤，最多叠加10次") and a.desc_fusion.contains("最终伤害+188%"), [a.desc_chibie, a.desc_ego])
	_check("jia_meta_desc", str(a.meta_chibie).contains("减少50%受到的伤害") and not str(a.meta_chibie).contains("90%"))
	_check("yi_chibie", is_equal_approx(b.chibie, 70.0), b.chibie)
	_check("yi_ego10", is_equal_approx(b.ego10, 100.0 + 300.0), b.ego10)
	_check("yi_fusion", is_equal_approx(b.fusion, 200.0) and is_equal_approx(b.fusion_crit, 200.0 + 100.0), [b.fusion, b.fusion_crit])
	_check("yi_desc", b.desc_fusion.contains("最终伤害+100%，暴击时再+50%") and b.desc_ego.contains("增加30%终伤") and b.desc_chibie.contains("减少30%"))
	_check("others_untouched", a.others == orig.others and b.others == orig.others)
	# 五、合体赛亚人拆开
	_check("orig_9940_on_2565", orig.st_9940 == 2565 and orig.st_9933 == 2565 and orig.copy.is_empty(), [orig.st_9940, orig.st_9933])
	_check("jia_9940_on_copy", a.st_9940 == XVegetaTune.ST_FUSION and a.st_9940 != 2565 and a.st_9933 == 2565, [a.st_9940, a.st_9933])
	_check("jia_copy_identical", a.copy == orig.src, [a.copy.length(), orig.src.length()])
	_check("jia_fusion_zero_change", a.fusion == orig.fusion and a.fusion_crit == orig.fusion_crit and a.src_fusion == orig.fusion and a.src_fusion_crit == orig.fusion_crit,
		[a.fusion, a.fusion_crit, a.src_fusion, a.src_fusion_crit])
	_check("jia_9940_note_only_repoint", a.note_9940 == orig.note_9940.replace("<StartPushState2565:", "<StartPushState%d:" % XVegetaTune.ST_FUSION), a.note_9940)
	_check("jia_9940_meta_order", a.meta_keys_9940 == orig.meta_keys_9940.map(func(k): return "StartPushState%d" % XVegetaTune.ST_FUSION if k == "StartPushState2565" else k), a.meta_keys_9940)
	_check("jia_9933_same", a.rec_9933 == orig.rec_9933 and a.src == orig.src)
	_check("jia_start_tags", a.tags_9940 == [["StartPushState", XVegetaTune.ST_FUSION, 100.0]] and a.tags_9933 == [["StartPushState", 2565, 100.0]], [a.tags_9940, a.tags_9933])
	_check("yi_only_9940", b.st_9940 == XVegetaTune.ST_FUSION and b.rec_9933 == orig.rec_9933 and b.src == orig.src
		and b.src_fusion == orig.fusion and b.src_fusion_crit == orig.fusion_crit, [b.src_fusion, b.src_fusion_crit])
	_reset_per_battle()
	_migrate()
	_fusion_battles()
	XVegetaTune.ENABLED = true
	XVegetaTune.TIER = "甲"
	_reload()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 按某档读表，算各效果的结果
func _snapshot(on: bool, tier: String) -> Dictionary:
	XVegetaTune.ENABLED = on
	XVegetaTune.TIER = tier
	_reload()
	var s := XState.new_game(3, 1, [])
	XState.current = s
	var v := s.actor(1)
	var e := XEnemy.new().setup(1, 3, 100.0)
	var out := {}
	out.chibie = _run_state("react", v, 2561, 100.0, {"attacker": e, "defender": v})
	s.set_variable(1543, 10)
	out.ego10 = _run_state("confirm", v, 2777, 100.0, {"attacker": v, "defender": e})
	s.set_variable(1543, 20)
	out.ego20 = _run_state("confirm", v, 2777, 100.0, {"attacker": v, "defender": e})
	# 合体赛亚人：9940 实际挂的那个状态（原版 2565，拆开后 2803）；2565 本身另算（9933 挂它）
	out.st_9940 = _start_state(9940)
	out.st_9933 = _start_state(9933)
	out.fusion = _run_state("confirm", v, out.st_9940, 100.0, {"attacker": v, "defender": e})
	out.fusion_crit = _run_state("confirm", v, out.st_9940, 100.0, {"attacker": v, "defender": e, "critical": true})
	out.src_fusion = _run_state("confirm", v, 2565, 100.0, {"attacker": v, "defender": e})
	out.src_fusion_crit = _run_state("confirm", v, 2565, 100.0, {"attacker": v, "defender": e, "critical": true})
	out.src = JSON.stringify(XDB.rec("States", 2565))
	var cp := XDB.rec("States", XVegetaTune.ST_FUSION).duplicate(true)
	if not cp.is_empty():
		cp.id = XDB.rec("States", 2565).id  # 表里的号是 JSON 读出的浮点
		cp.erase("_vegeta")
	out.copy = "" if cp.is_empty() else JSON.stringify(cp)
	out.note_9940 = str(XDB.rec("Skills", 9940).note)
	out.meta_keys_9940 = (XDB.rec("Skills", 9940).meta as Dictionary).keys()
	out.rec_9933 = JSON.stringify(XDB.rec("Skills", 9933))
	out.tags_9940 = _tags(v, 9940)
	out.tags_9933 = _tags(v, 9933)
	out.cap = -1
	for l in XDB.table("CommonEvents")[1722].list:
		if int(l.code) == 111 and int(l.parameters[1]) == 1543:
			out.cap = int(l.parameters[3])
	out.desc_chibie = str(XDB.rec("Skills", 9942).note)
	out.meta_chibie = XDB.rec("Skills", 9942).get("meta", {})
	out.desc_ego = str(XDB.rec("Skills", 10568).note)
	out.desc_fusion = str(XDB.rec("Skills", 9940).note)
	var others := []
	for id in [2560, 2562, 2566, 2567, 2770, 2775, 2776, 1421]:
		others.append(JSON.stringify(XDB.rec("States", id)))
	for id in [9941, 9943, 9944, 9945, 10567, 101]:
		others.append(JSON.stringify(XDB.rec("Skills", id)))
	others.append(JSON.stringify(XDB.table("CommonEvents")[1721]))
	out.others = others
	return out


## 技能 meta 里 <StartPushStateN> 的 N（只认一个）
func _start_state(skill: int) -> int:
	var found := []
	for k in XDB.rec("Skills", skill).get("meta", {}):
		if str(k).begins_with("StartPushState") and str(k).substr(14).is_valid_int():
			found.append(int(str(k).substr(14)))
	return found[0] if found.size() == 1 else -1


## 角色只会这一招、不穿装备时开战加的状态标签（XActor.battle_start_state_tags 真读）
func _tags(v, skill: int) -> Array:
	var keep_sk: Array[int] = v.skill_ids.duplicate()
	var keep_eq: Array = v.equips.duplicate()
	v.skill_ids.assign([skill])
	for k in v.equips.size():
		v.equips[k] = null
	v.read_touch()
	var out: Array = v.battle_start_state_tags().filter(func(t): return str(t[0]) == "StartPushState" and [2565, XVegetaTune.ST_FUSION].has(int(t[1])))
	v.skill_ids = keep_sk
	v.equips = keep_eq
	v.read_touch()
	return out


func _run_state(phase: String, holder, id: int, value: float, ctx: Dictionary) -> float:
	var c := ctx.duplicate()
	c.execute = false
	c.value = value
	c.item = {"damage": {"type": 1}, "hitType": 1}
	return XStateEffects.run_one(phase, holder, XDB.rec("States", id), c)


## 每场开局清零：setup 时 1543 归零；关掉开关不清
func _reset_per_battle() -> void:
	for on in [true, false]:
		XVegetaTune.ENABLED = on
		var s := XState.new_game(3, 1, [])
		XState.current = s
		s.set_variable(1543, 20)
		var lg := XBattleLogic.new()
		lg.setup(2, s)
		_check("reset_%s" % ("on" if on else "off"), int(s.variable(1543)) == (0 if on else 20), s.variable(1543))
		lg.end_battle(0)


## 存档迁移：2565／2803 战斗结束不去掉。开着时只会 9940 的人身上留的旧 2565 开局去掉（不叠两份）；
## 也会 9933 的保留 2565；关掉时身上的 2803 去掉
func _migrate() -> void:
	XVegetaTune.ENABLED = true
	XVegetaTune.TIER = "甲"
	_reload()
	var s := XState.new_game(3, 1, [])
	XState.current = s
	var v := s.actor(1)
	v.skill_ids.assign([9940])
	v.state_ids.append(2565)
	v.read_touch()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var after: Array = v.state_ids.duplicate()
	lg.end_battle(0)
	_check("migrate_drop_old_2565", not after.has(2565) and after.has(XVegetaTune.ST_FUSION), after)
	var s2 := XState.new_game(3, 1, [])
	XState.current = s2
	var w := s2.actor(1)
	w.skill_ids.assign([9940, 9933])
	w.state_ids.append(2565)
	w.read_touch()
	var lg2 := XBattleLogic.new()
	lg2.setup(2, s2)
	var after2: Array = w.state_ids.duplicate()
	lg2.end_battle(0)
	_check("migrate_keep_9933", after2.has(2565) and after2.has(XVegetaTune.ST_FUSION), after2)
	XVegetaTune.original_data()
	var s3 := XState.new_game(3, 1, [])
	XState.current = s3
	var x := s3.actor(1)
	x.skill_ids.assign([9940])
	x.state_ids.append(XVegetaTune.ST_FUSION)
	x.read_touch()
	var lg3 := XBattleLogic.new()
	lg3.setup(2, s3)
	var after3: Array = x.state_ids.duplicate()
	lg3.end_battle(0)
	_check("migrate_off_back_to_2565", not after3.has(XVegetaTune.ST_FUSION) and after3.has(2565), after3)
	XVegetaTune.ENABLED = true
	_reload()



const FB_SEED := "c0ffee0011223344"


## 开一场（敌群 4，500 万血首领，漩涡异化关掉免得干扰），角色 1 会 skills、身上先挂 pre；返回 [逻辑, 存档, 角色]
func _fb_setup(skills: Array, pre: Array, s: XState = null) -> Array:
	if s == null:
		s = XState.new_game(3, 1, [])
		var a0 := s.actor(1)
		a0.skill_ids.assign(skills)
		for id in pre:
			a0.state_ids.append(int(id))
		a0.read_touch()
	XState.current = s
	var lg := XBattleLogic.new()
	lg.setup(4, s, XBattleRandom.create(FB_SEED, 1))
	return [lg, s, s.actor(1)]


## 角色 1 普攻首领三下，返回每下伤害
func _fb_hits(lg: XBattleLogic, a) -> Array:
	var out := []
	var e: XEnemy = lg.enemies[0]
	for i in 3:
		var hp0 := e.hp
		lg.execute(a, XDB.rec("Skills", 1), e)
		out.append(hp0 - e.hp)
	return out


func _fb_case(on: bool, skills: Array, pre: Array) -> Dictionary:
	if on:
		XVegetaTune.ENABLED = true
		XVegetaTune.TIER = "甲"
		_reload()
	else:
		XVegetaTune.original_data()
	var r := _fb_setup(skills, pre)
	var a = r[2]
	var out := {"ids": a.state_ids.duplicate(), "rows": a.states().map(func(st): return int(st.id))}
	out.hits = _fb_hits(r[0], a)
	r[0].end_battle(0)
	out.save = JSON.stringify(r[1].to_dict())
	return out


func _fusion_battles() -> void:
	XRiftAlien.ENABLED = false
	var F := XVegetaTune.ST_FUSION
	# 两技能都会：原版只挂一份 2565；新版 2565＋2803 都在身上，但只算 2565
	var o1 := _fb_case(false, [9940, 9933], [])
	var n1 := _fb_case(true, [9940, 9933], [])
	_check("both_orig_one", o1.ids.count(2565) == 1 and not o1.ids.has(F), o1.ids)
	_check("both_new_two_on_body", n1.ids.has(2565) and n1.ids.has(F), n1.ids)
	_check("both_new_rows_shadowed", n1.rows.has(2565) and not n1.rows.has(F), n1.rows)
	_check("both_damage_same", n1.hits == o1.hits and o1.hits.all(func(x): return x > 0.0), [n1.hits, o1.hits])
	# 先有 2565（以前 9933 留下的）再只学 9940
	var o2 := _fb_case(false, [9940], [2565])
	var n2 := _fb_case(true, [9940], [2565])
	_check("pre2565_damage_same", n2.hits == o2.hits, [n2.hits, o2.hits])
	_check("pre2565_one_counted", n2.rows.count(2565) + n2.rows.count(F) == 1, n2.rows)
	# 先有 2565 且仍会 9933，再学 9940（同「两技能都会」，但 2565 是存档带来的）
	var n3 := _fb_case(true, [9933, 9940], [2565])
	_check("pre2565_both_damage_same", n3.hits == o1.hits, [n3.hits, o1.hits])
	# 战中存档再读档：两技能都会的那场，开战后存、读回来接着打，伤害与不存读相同
	XVegetaTune.ENABLED = true
	XVegetaTune.TIER = "甲"
	_reload()
	var r := _fb_setup([9940, 9933], [])
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(r[1].to_dict())))
	r[0].end_battle(0)
	var b = back.actor(1)
	_check("roundtrip_ids", b.state_ids.has(2565) and b.state_ids.has(F) and not b.states().map(func(st): return int(st.id)).has(F), b.state_ids)
	var r2 := _fb_setup([], [], back)
	var h2 := _fb_hits(r2[0], r2[2])
	r2[0].end_battle(0)
	_check("roundtrip_damage_same", h2 == o1.hits, [h2, o1.hits])
	# 关掉开关回退：带着新版存档（身上有 2803）读回原版，2803 抹掉、伤害与原版相同
	XVegetaTune.original_data()
	var old_save := XState.from_dict(JSON.parse_string(n2.save))
	_check("rollback_save_has_copy", old_save.actor(1).state_ids.has(F), old_save.actor(1).state_ids)
	var r3 := _fb_setup([], [], old_save)
	var h3 := _fb_hits(r3[0], r3[2])
	var ids3: Array = r3[2].state_ids.duplicate()
	r3[0].end_battle(0)
	_check("rollback_damage_same", h3 == o2.hits and not ids3.has(F) and ids3.has(2565), [h3, o2.hits, ids3])
	XVegetaTune.ENABLED = true
	_reload()
	XRiftAlien.ENABLED = true
