extends Node
## 战斗补全测试（无画面）：神话敌人、技能冷却/预热、战斗中用物品、反击与魔法反射、必中被动、冷却存档往返。
## 神话数值以 mv_oracle 实测为准（普通难度敌群 2，Math.random 固定 0 时全部为神话）：
##   嘤嘤怪 【神话】 能力值 35000,24,49,53,49,53,70,175，经验 24，金钱 24；里德（NoElite）不变 5000000,8800,…
## 冷却语义取自 YEP_X_SkillCooldowns：使用后设为 x，每回合开始（Game_Troop.increaseTurn）减 1，战斗结束 -10。
## 不读写任何存档。

var results: Array = []

func _ready() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _new_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	# dev.099 起战斗用本场规则流（主种子只在运行时生成），全局 seed() 管不到；固定主种子才能复现
	s.random_master = XRandomStream.hex64(20261012)
	for a in s.members():
		# 原版开局（普通难度）实际所学：天道诅咒、难度适应、普通难度；开局可选的角色另有万众一心、SupperStar
		for sid in [6168, 5980, 5548] + ([2571, 2786] if a.actor_id <= 7 else []):
			a.learn_skill(sid)
		a.refresh_passive()
		a.recover_all()
	return s


func _params(e: XEnemy) -> Array:
	return range(8).map(func(i): return int(e.param(i)))


## 测试专用状态：只有一条 xparam 特性（5 魔法反射 / 6 反击），追加到 States 表末尾。
func _fake_state(xparam_id: int, value: float) -> int:
	var t: Array = XDB.table("States")
	var id := t.size()
	t.append({"id": id, "name": "测试状态%d" % xparam_id, "traits": [{"code": 22, "dataId": xparam_id, "value": value}],
		"note": "", "meta": {}, "iconIndex": 0, "restriction": 0, "autoRemovalTiming": 0, "removeAtBattleEnd": true})
	return id


func _run() -> void:
	seed(20261012)
	# ---- 神话敌人 ----
	var s := _new_state()
	var logic := XBattleLogic.new()
	logic.elite_roll = 0.0
	logic.setup(2, s)
	var e: XEnemy = logic.enemies[0]
	_check("elite_all", logic.enemies.all(func(x): return x.elite), logic.enemies.map(func(x): return x.display_name()))
	_check("elite_name", e.display_name() == "【神话】嘤嘤怪Ａ", e.display_name())
	_check("elite_params_oracle", _params(e) == [35000, 24, 49, 53, 49, 53, 70, 175], _params(e))
	_check("elite_exp_gold_oracle", e.exp_reward() == 24 and e.gold_reward() == 24, [e.exp_reward(), e.gold_reward()])
	_check("elite_drop_bonus", is_equal_approx(e.drop_rate_bonus(), 5.0), e.drop_rate_bonus())
	_check("elite_hp_full", e.hp == e.mhp and e.mhp == 35000.0, e.hp)
	var boss := XBattleLogic.new()
	boss.elite_roll = 0.0
	boss.setup(4, s)
	_check("noelite_boss", not boss.enemies[0].elite and _params(boss.enemies[0]) == [5000000, 8800, 70, 38, 70, 38, 50, 125], _params(boss.enemies[0]))
	var plain := XBattleLogic.new()
	plain.elite_roll = 100.0
	plain.setup(2, s)
	_check("plain_params_oracle", _params(plain.enemies[0]) == [10000, 8, 14, 15, 14, 15, 20, 50] and plain.enemies[0].display_name() == "嘤嘤怪Ａ", _params(plain.enemies[0]))
	plain.end_battle()
	logic.end_battle()
	boss.end_battle()

	# ---- 冷却 ----
	s = _new_state()
	var a := s.actor(1)
	a.learn_skill(401)          # 击木楔 <Cooldown: 2>，单体伤害；要求武器类型 5，换上指虎（练习剑是类型 2）
	_equip_wtype5(a)
	a.learn_skill(6028)         # 旋龙斩 <Warmup: 2>
	logic = XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var sk401 := XDB.rec("Skills", 401)
	var sk6028 := XDB.rec("Skills", 6028)
	_check("warmup_start", a.cooldown_left(6028) == 2 and not logic.can_use(a, sk6028), a.warmups)
	a.mp = a.mmp
	logic.execute(a, sk401, logic.enemies[0])
	_check("cooldown_set", a.cooldown_left(401) == 2 and not logic.can_use(a, sk401), a.cooldowns)
	logic.run_turn({})        # 第 1 回合开始：2 → 1
	_check("cooldown_tick1", a.cooldown_left(401) == 1 and not logic.can_use(a, sk401), a.cooldowns)
	_check("warmup_tick1", a.cooldown_left(6028) == 1, a.warmups)
	logic.run_turn({})        # 第 2 回合开始：1 → 0
	_check("cooldown_ready", a.cooldown_left(401) == 0 and logic.can_use(a, sk401), a.cooldowns)
	_check("warmup_ready", a.cooldown_left(6028) == 0, a.warmups)
	_check("bypass_attack", XBattler.cooldown_bypass(1) and not XBattler.cooldown_bypass(401))
	# 冷却 11 的技能战斗结束后 -10 仍剩 1，冷却随存档保存
	a.cooldowns[499] = 11.0
	logic.end_battle()
	_check("after_battle_minus10", is_equal_approx(float(a.cooldowns.get(499, 0)), 1.0) and not a.cooldowns.has(401) and a.warmups.is_empty(), a.cooldowns)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check("cooldown_saved", is_equal_approx(float(back.actor(1).cooldowns.get(499, 0)), 1.0), back.actor(1).cooldowns)

	# ---- 战斗中用物品 ----
	s = _new_state()
	a = s.actor(1)
	s.gain_item(1, 2)          # 治疗药水(小)：HP +500
	logic = XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var potion := XDB.rec("Items", 1)
	_check("battle_items_list", logic.battle_items().any(func(x): return int(x.id) == 1))
	a.hp = 1.0
	var logs := logic.execute(a, potion, a)
	var expect := minf(a.mhp, 1.0 + floorf(500.0 * a.rec * a.pha))
	_check("potion_heal", is_equal_approx(a.hp, expect), [a.hp, expect])
	_check("potion_consumed", int(s.items.get(1, 0)) == 1, s.items)
	_check("potion_no_mp_cost", logs[0].type == "action" and XBattleLogic.is_item(logs[0].skill))
	s.gain_item(1, -1)
	_check("item_unusable_when_none", not logic.can_use(a, potion))
	logic.end_battle()

	# ---- 反击 / 魔法反射 ----
	s = _new_state()
	a = s.actor(1)
	logic = XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var foe: XEnemy = logic.enemies[0]
	# 本 MOD 的普通攻击（技能 1）是魔法型（hitType 2），只会被反射；反击用物理技能 击木楔(401) 测
	a.learn_skill(401)
	_equip_wtype5(a)
	var phys := XDB.rec("Skills", 401)
	_check("attack_is_magical", XDamage.is_magical(XDB.rec("Skills", 1)) and XDamage.is_physical(phys))
	var cnt_state := _fake_state(6, 1.0)
	foe.add_state(cnt_state)
	_check("enemy_cnt_1", is_equal_approx(foe.cnt, 1.0), foe.cnt)
	var foe_hp := foe.hp
	logs = logic.execute(a, phys, foe)
	logs = logs.filter(func(l): return not str(l.type).begins_with("seq"))  # 去掉行动序列的画面条目
	_check("counter_logged", logs.size() >= 3 and logs[1].type == "counter" and logs[1].user == foe and logs[2].user == foe and logs[2].target == a, logs.map(func(l): return l.type))
	_check("counter_negates_hit", foe.hp == foe_hp, [foe.hp, foe_hp])
	# 必中被动：不会被反击
	phys.meta["SkillCertainHitss"] = true # persistent native note capability survives gain/refresh
	a.refresh_passive()
	a.cooldowns.clear()
	logs = logic.execute(a, phys, foe)
	# 技能 401 的正式行动序列有 3 次 ACTION EFFECT（dev.028 起照 yepSeq），目标打到 0 血时在收尾（IMMORTAL 解除）才倒下
	var hits := logs.filter(func(l): return l.type == "hit")
	_check("certain_hit_no_counter", not logs.any(func(l): return l.type == "counter") and hits.size() >= 1 and hits.all(func(l): return not l.missed and not l.evaded), logs.map(func(l): return l.type))
	phys.meta.erase("SkillCertainHitss")
	a.refresh_passive()
	foe = logic.enemies[1]          # 上一步的敌人可能已被打倒，换一只
	var mrf_state := _fake_state(5, 1.0)
	foe.add_state(mrf_state)
	var magic := XDB.rec("Skills", 1)
	_check("enemy_mrf_1", is_equal_approx(foe.mrf, 1.0) and foe.is_alive(), [foe.mrf, foe.hp, foe.state_ids])
	var caster := s.actor(9)
	caster.mp = caster.mmp
	foe_hp = foe.hp
	var caster_hp := caster.hp
	logs = logic.execute(caster, magic, foe)
	logs = logs.filter(func(l): return not str(l.type).begins_with("seq"))
	_check("reflect_logged", logs.size() >= 3 and logs[1].type == "reflect" and logs[2].target == caster, logs.map(func(l): return l.type))
	_check("reflect_hits_user", logs.size() >= 3 and foe.hp == foe_hp and (caster.hp < caster_hp or logs[2].missed or logs[2].evaded), [foe.hp, foe_hp, caster.hp, caster_hp])
	logic.end_battle()

	# ---- 出战人数与经验分配（MrTS 出战 5 人；MV gainExp 全队含阵亡与后备）----
	s = _new_state()
	for id in [2, 3, 4]:
		s.add_actor(id)
	_check("battle_members_5", s.battle_members().size() == 5 and s.members().size() == 7, [s.battle_members().size(), s.members().size()])
	logic = XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	_check("battle_actors_5", logic.actors.size() == 5, logic.actors.size())
	var dead: XActor = logic.actors[1]
	logic._die(dead)
	var bench: XActor = s.members()[5]
	var before_exp := {dead: dead.exp_total, bench: bench.exp_total, s.members()[0]: s.members()[0].exp_total}
	logic.grant({"exp": 10, "gold": 0, "drops": []})
	var bench_rate := 1.0 if bool(XDB.system().get("optExtraExp", false)) else 0.0
	_check("exp_dead_member", dead.exp_total - before_exp[dead] == roundi(10 * dead.exr), [before_exp[dead], dead.exp_total])
	_check("exp_bench_member", bench.exp_total - before_exp[bench] == roundi(10 * bench.exr * bench_rate), [before_exp[bench], bench.exp_total])
	logic.end_battle()

	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 击木楔(401) 要求武器类型 5（isSkillWtypeOk）：换上类型 5 的指虎(武器 6)
func _equip_wtype5(a: XActor) -> void:
	a.equips[0] = XGear.create("weapon", 6)
	a.refresh_passive()
