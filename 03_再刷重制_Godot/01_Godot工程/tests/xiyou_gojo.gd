extends Node
## 天启篇五条悟 180（XGojo）第一期专项：
## 一、数据：角色、职业、技能、状态、进阶行补进表里；素材路径；天启篇以外停用、图鉴不列；天启篇名单暂列「不开放」（等最强之名）。
## 二、苍印赫印：苍类、赫类加印，上限 3；反转术式加赫印；领域里另加对面的印；进阶四展开领域各 +1。
## 三、茈：要两种印、形状看上一个术式（苍→收、赫→放），技能列表只列当前形状；对数取较少的一个、系数按表；施放后清空。
## 四、六眼：交替时苍、赫不耗魔法；同类照扣。无下限：每回合一次、花 1 苍印拦下敌人单体攻击。
## 五、领域信息过载（敌人才判）、术式必中；黑闪回魔法 10%、觉醒中咒力打击补较少的印；自动反转每场一次；进阶二茈·放的防御钩子。
## 六、开关：ENABLED 关掉不补数据。

const GOJO := 180
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XTianqiSkills.reload()
	XGojo.unlock_override = 1  # 默认按已解锁最强之名（不读本机配置）；解锁的专门检查见 _unlock
	_data()
	_marks()
	_purple()
	_six_eyes_infinity()
	_domain_flash()
	_real_turns()
	_unlock()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state() -> XState:
	var w := XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2]]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	XState.current = s
	for id in lineup + [GOJO]:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	_check("in_battle_slots", s.battle_slots.has(GOJO), s.battle_slots)
	return s


func _gojo(s: XState) -> XActor:
	var a: XActor = s.actor(GOJO)
	a.change_level(99)
	for id in XGojo.ADV:
		a.learn_skill(id)
	a.refresh_passive()
	return a


func _logic(s: XState) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _cast(lg: XBattleLogic, a, id: int) -> void:
	var sk := XDB.rec("Skills", id)
	XGojo.begin(lg, a, sk)
	XGojo.finish(lg, a, sk)


func _data() -> void:
	XState.current = null
	var actor := XDB.rec("Actors", GOJO)
	_check("actor", str(actor.get("name", "")) == "五条悟" and int(actor.classId) == XGojo.CLASS and str(actor.note).contains("<Replace Attack: 10634>"), actor.get("name"))
	var cls := XDB.rec("Classes", XGojo.CLASS)
	var learned: Array = cls.get("learnings", []).map(func(l): return int(l.skillId))
	_check("class_learnings", learned.has(XGojo.PURPLE_IN) and learned.has(XGojo.DOMAIN) and learned.has(XBlackFlash.SKILL) and learned.has(XGojo.AWAKENING), learned)
	var mat99: float = float(cls.params[4][50])
	var atk99: float = float(cls.params[2][50])
	_check("class_mat_main", mat99 > atk99, [mat99, atk99])
	var names := []
	for id in range(XGojo.FIRST_SKILL, XGojo.LAST_SKILL + 1):
		names.append(str(XDB.rec("Skills", id).get("name", "")))
	_check("skills", not names.has("") and names[0] == "咒力打击" and names[6] == "虚式「茈」·收", names)
	_check("states", str(XDB.rec("States", XGojo.ST_BLUE + 2).get("name", "")) == "苍印·三" and str(XDB.rec("States", XGojo.ST_SLOW).get("name", "")) == "赫·减速")
	var row = XAdvance.rows().filter(func(r): return int(r.actor) == GOJO)
	_check("advance_rows", row.size() == 2 and (row[0].learn as Array).has(1240) and (row[1].learn as Array).has(XGojo.ADV[3]), row.size())  # 试炼版两阶（XTianqiGojoTrial；四阶在 xiyou_gojo_trials 的开关检查）
	_check("art", XDB.img_path("sv_actors", "Codex_Gojo_SV") != "" and XDB.img_path("characters", "$Codex_Gojo_Walk") != "" and XDB.img_path("faces", "Codex_Gojo_Face") != "")
	var icon_ids := [int(XDB.rec("Skills", XGojo.STRIKE).iconIndex), int(XDB.rec("Skills", XGojo.ADV[3]).iconIndex), int(XDB.rec("Armors", XGojo.ARMOR).iconIndex), int(XDB.rec("States", XGojo.ST_BLUE).iconIndex)]
	_check("art_icon_ids", icon_ids == [XGojo.ICON_BASE + 2, XGojo.ICON_BASE + 10, XGojo.ICON_BASE + 18, XGojo.ICON_BASE + 3], icon_ids)
	var missing := []
	for n in range(2, 19):
		var tex := XUI.icon_texture(XGojo.ICON_BASE + n)
		if tex == null or tex.get_size() != Vector2(128, 128):
			missing.append(n)
	_check("art_icons_load", missing.is_empty(), missing)
	_check("art_domain_bg", ResourceLoader.exists(XGojo.DOMAIN_BG))
	_check("hidden_outside", XImportedBalance.is_disabled_actor(GOJO) and XImportedBalance.is_hidden_actor(GOJO) and not XActorBook.index_ids().has(GOJO))
	XGojo.unlock_override = 0
	_check("locked_closed", XTianqiSkills.tier_of(GOJO, true) == "" and not XTianqi.pool("lianyu")[XTier.SUPER].has(GOJO) and XGojo.locked(GOJO))
	XGojo.unlock_override = 1
	var pool := XTianqi.pool("lianyu")
	_check("unlocked_pool", XTianqiSkills.tier_of(GOJO, true) == XTier.SUPER and pool[XTier.SUPER].has(GOJO) and not XTianqi.pool("jianxian").get(XTier.SUPER, []).has(GOJO), pool[XTier.SUPER])
	_check("main_tier_hidden", XTier.tier_of(GOJO) == "" and not XTier.ids(XTier.SUPER).has(GOJO))
	var armor := XDB.rec("Armors", XGojo.ARMOR)
	_check("blindfold_rec", str(armor.get("name", "")) == "眼罩" and int(armor.etypeId) == 13 and str(armor.note).contains("<req_actors: 180>"))
	var s := _state()
	_check("tianqi_join", s.party.has(GOJO) and not XImportedBalance.is_disabled_actor(GOJO))
	_check("join_blindfold", XGojo.wears_blindfold(s.actor(GOJO)), s.actor(GOJO).equips)
	var a := _gojo(s)
	_check("attack_replaced", a.attack_skill_id() == XGojo.STRIKE)
	_check("skill_ids", a.skill_ids.has(XGojo.DOMAIN) and a.skill_ids.has(XGojo.SIX_EYES), a.skill_ids.size())
	var blue := XDB.rec("Skills", XGojo.BLUE)
	_check("blue_cost_pct", is_equal_approx(float(XBattleLogic.note_costs(blue).get("mpCostPer", 0.0)), 0.1), XBattleLogic.note_costs(blue))
	_check("max_cooldown", str(XDB.rec("Skills", XGojo.RED_MAX).meta.get("Cooldown", "")).strip_edges() == "3" and str(XDB.rec("Skills", XGojo.DOMAIN).meta.get("Cooldown", "")).strip_edges() == "6")
	_check("strongest_tag", str(XDB.rec("Skills", XGojo.STRONGEST).meta.get("passiveHarmRi", "")) == "10")


func _marks() -> void:
	var s := _state()
	var a := _gojo(s)
	var lg := _logic(s)
	_cast(lg, a, XGojo.BLUE)
	_check("blue_1", XGojo.marks(a) == [1, 0] and a.state_ids.has(XGojo.ST_BLUE), XGojo.marks(a))
	_cast(lg, a, XGojo.RED_MAX)
	_check("red_max_2", XGojo.marks(a) == [1, 2] and a.state_ids.has(XGojo.ST_RED + 1) and not a.state_ids.has(XGojo.ST_RED), XGojo.marks(a))
	_cast(lg, a, XGojo.RED_MAX)
	_check("cap_3", XGojo.marks(a) == [1, 3], XGojo.marks(a))
	_cast(lg, a, XGojo.REVERSE)
	_check("reverse_red_keeps_last", XGojo.marks(a) == [1, 3] and str(XGojo.temp(a).last) == "red")
	XGojo.temp(a).blue = 0
	XGojo.temp(a).red = 0
	_cast(lg, a, XGojo.DOMAIN)
	_check("domain_adv4", XGojo.marks(a) == [1, 1] and XGojo.active_domain(a) and a.state_ids.has(XGojo.ST_DOMAIN), XGojo.marks(a))
	_cast(lg, a, XGojo.BLUE)
	_check("domain_extra", XGojo.marks(a) == [2, 2], XGojo.marks(a))
	for i in range(3):
		lg.end_turn()
	_check("domain_ends", not XGojo.active_domain(a) and not a.state_ids.has(XGojo.ST_DOMAIN))
	a.add_new_state(1)
	_check("death_clears", XGojo.marks(a) == [0, 0])
	lg.end_battle(0)


func _purple() -> void:
	var s := _state()
	var a := _gojo(s)
	var lg := _logic(s)
	var p_in := XDB.rec("Skills", XGojo.PURPLE_IN)
	var p_out := XDB.rec("Skills", XGojo.PURPLE_OUT)
	_check("purple_needs_marks", not XGojo.meets(a, p_in) and not XGojo.meets(a, p_out))
	_cast(lg, a, XGojo.BLUE_MAX)
	_cast(lg, a, XGojo.RED_MAX)
	_cast(lg, a, XGojo.BLUE)
	_check("shape_in_after_blue", XGojo.shape(a) == XGojo.PURPLE_IN and XGojo.meets(a, p_in) and not XGojo.meets(a, p_out) and XGojo.listed(a, p_in) and not XGojo.listed(a, p_out))
	var shown: Array = lg.battle_skills(a).map(func(sk): return int(sk.id))
	_check("battle_list_one_shape", shown.has(XGojo.PURPLE_IN) and not shown.has(XGojo.PURPLE_OUT), shown)
	_cast(lg, a, XGojo.RED)
	_check("shape_out_after_red", XGojo.shape(a) == XGojo.PURPLE_OUT and XGojo.pairs(a) == 3)
	var b: XBattler = lg.enemies[0]
	XGojo.begin(lg, a, p_out)
	var v := XGojo.formula(a, b, p_out)
	_check("purple_out_3", is_equal_approx(v, a.mat * 10.8), [v, a.mat])
	var via: Dictionary = XFormulaExecution.run_item(p_out, a, b, {})
	_check("purple_pipeline", via.available and is_equal_approx(float(via.value), a.mat * 10.8), via)
	XGojo.finish(lg, a, p_out)
	_check("purple_clears_blindfold", XGojo.marks(a) == [1, 1] and not a.state_ids.has(XGojo.ST_BLUE + 2), XGojo.marks(a))
	XGojo.temp(a).blue = 1
	XGojo.temp(a).red = 3
	XGojo.temp(a).last = "blue"
	XGojo.begin(lg, a, p_in)
	_check("purple_in_1", is_equal_approx(XGojo.formula(a, b, p_in), a.mat * 1.8))
	XGojo.cast = {}
	var red := XDB.rec("Skills", XGojo.RED)
	_check("red_table_coef", is_equal_approx(XTianqiSkills.formula(a, b, red), a.mat * 3.6))
	_check("adv2_ops", XGojo.damage_ops(p_out, a).size() == 2 and XGojo.damage_ops(p_in, a).is_empty())
	lg.end_battle(0)


func _six_eyes_infinity() -> void:
	var s := _state()
	var a := _gojo(s)
	var lg := _logic(s)
	var blue := XDB.rec("Skills", XGojo.BLUE)
	var red := XDB.rec("Skills", XGojo.RED)
	_check("first_pays", XGojo.mp_cost(a, blue, 50) == 50)
	_cast(lg, a, XGojo.BLUE)
	_check("same_pays", XGojo.mp_cost(a, blue, 50) == 50)
	_check("alternate_free", XGojo.mp_cost(a, red, 50) == 0)
	_check("max_not_mp", XGojo.mp_cost(a, XDB.rec("Skills", XGojo.RED_MAX), 7) == 7)
	var e: XBattler = lg.enemies[0]
	var hit := {"id": 1, "scope": 1, "damage": {"type": 1}}
	var hp := a.hp
	_check("infinity_blocks", XGojo.infinity_block(lg, e, hit, a) and XGojo.marks(a) == [0, 0])
	XGojo.temp(a).blue = 2
	_check("infinity_once_per_round", not XGojo.infinity_block(lg, e, hit, a) and XGojo.marks(a)[0] == 2)
	lg.end_turn()
	_check("infinity_not_aoe", not XGojo.infinity_block(lg, e, {"id": 1, "scope": 2, "damage": {"type": 1}}, a))
	_check("infinity_next_round", XGojo.infinity_block(lg, e, hit, a) and XGojo.marks(a)[0] == 1)
	XGojo.temp(a).guard_round = -1
	XGojo.temp(a).blue = 1
	var r: Dictionary = lg.apply(e, XDB.rec("Skills", 1), a)
	_check("apply_evaded", bool(r.evaded) and a.hp == hp and XGojo.marks(a)[0] == 0, [r.get("evaded"), a.hp, hp])
	lg.end_battle(0)


func _domain_flash() -> void:
	var s := _state()
	var a := _gojo(s)
	var lg := _logic(s)
	var e: XBattler = lg.enemies[0]
	_check("no_overload_without_domain", not XGojo.overload(lg, e))
	_cast(lg, a, XGojo.DOMAIN)
	var n := 0
	for i in range(200):
		n += 1 if XGojo.overload(lg, e) else 0
	_check("overload_rate", n > 20 and n < 120, n)
	_check("overload_not_actor", not XGojo.overload(lg, a))
	_check("domain_bg_shown", XGojo.domain_shown(lg))
	_check("domain_sure", XGojo.sure(a, XDB.rec("Skills", XGojo.RED)) and not XGojo.sure(a, XDB.rec("Skills", XGojo.STRIKE)))
	a.mp = 0.0
	XGojo.on_black_flash(a)
	_check("flash_mp", is_equal_approx(a.mp, floorf(a.mmp * 0.1)), [a.mp, a.mmp])
	_check("flash_config", not XBlackFlash.config(a).is_empty() and (XBlackFlash.config(a).trigger as Array).has(XGojo.STRIKE))
	a.hp = floorf(a.mhp * 0.2)
	XGojo.after_hit(lg, a)
	var healed := a.hp
	_check("auto_reverse", healed > floorf(a.mhp * 0.2), [healed, a.mhp])
	a.hp = floorf(a.mhp * 0.2)
	XGojo.after_hit(lg, a)
	_check("auto_reverse_once", a.hp == floorf(a.mhp * 0.2))
	lg.end_battle(0)
	XGojo.ENABLED = false
	var t: Array = []
	t.resize(XGojo.ACTOR + 1)
	XGojo.patch_actors(t)
	_check("switch_off", t[XGojo.ACTOR] == null)
	XGojo.ENABLED = true


## 真走 act：花费、加印、伤害都经过整条链
func _real_turns() -> void:
	# 夹具没跑开局，原来就没学难度被动；天启篇改读数值表后结算 ×6，苍一下就打死敌人、后面几招没对象。
	# 这里测的是五条悟的花费与印记，不测难度被动等价（见 xiyou_tianqi_no_diff_passive），照原来不乘
	XTianqiNoDiffPassive.ENABLED = false
	var s := _state()
	var a := _gojo(s)
	var lg := _logic(s)
	var e: XBattler = lg.enemies[0]
	e.hp = e.mhp
	a.mp = a.mmp
	var mp0 := a.mp
	var hp0 := e.hp
	lg.act(a, XDB.rec("Skills", XGojo.BLUE), e)
	_check("act_blue_pays", a.mp < mp0 and XGojo.marks(a) == [1, 0] and e.hp < hp0, [a.mp, mp0, XGojo.marks(a), e.hp, hp0])
	var mp1 := a.mp
	lg.act(a, XDB.rec("Skills", XGojo.RED), e)
	_check("act_red_free", a.mp == mp1 and XGojo.marks(a) == [1, 1], [a.mp, mp1, XGojo.marks(a)])
	var before := e.hp
	if e.is_alive():
		lg.act(a, XDB.rec("Skills", XGojo.PURPLE_OUT), e)
		_check("act_purple", XGojo.marks(a) == [1, 1] and (e.hp < before or e.is_dead()), [XGojo.marks(a), e.hp, before])
	a.hp = floorf(a.mhp * 0.5)
	var hp1 := a.hp
	lg.act(a, XDB.rec("Skills", XGojo.REVERSE), a)
	_check("act_reverse_heals", a.hp > hp1 and XGojo.marks(a)[1] == 2, [a.hp, hp1, a.mhp, XGojo.marks(a)])
	lg.end_battle(0)
	XTianqiNoDiffPassive.ENABLED = true


## 最强之名：证道、36 层骑士战上场的人里有宿傩或甚尔才解锁
func _unlock() -> void:
	XGojo.unlock_override = 0
	var s := XTianqi.start_new_game(3, "zhengdao", [1])
	XState.current = s
	XGojo._fighters = [1, 2, 3]
	_check("unlock_needs_partner", not XGojo.strongest_check(s) and not XGojo.unlocked())
	XGojo._fighters = [1, 172]
	s.flags.tianqi.difficulty = "lianyu"
	_check("unlock_needs_zhengdao", not XGojo.strongest_check(s) and not XGojo.unlocked())
	s.flags.tianqi.difficulty = "zhengdao"
	_check("unlock_ok", XGojo.strongest_check(s) and XGojo.unlocked())
	_check("unlock_once", not XGojo.strongest_check(s))
	XGojo.unlock_override = 0
	XGojo._fighters = [171]
	var plain := XState.new()
	XState.current = plain
	_check("unlock_not_outside", not XGojo.strongest_check(plain) and not XGojo.unlocked())
	XGojo.unlock_override = 1
