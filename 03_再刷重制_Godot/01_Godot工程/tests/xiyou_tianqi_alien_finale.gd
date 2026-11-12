extends Node
## 天启篇各线异化的终焉效果与补做的化形效果专项（四线异化 v0.8 第 3 节；cc/tianqi-alien-finale）。
## 战争：战狂免疫能力值减益、号令官按怪数多动、烟火师火花满轰炸、战意满层再动加倍（化形清减益）。
## 饥荒：枯竭者降 MP 上限、荒年者复活这一下不回、熬夜者 TP 归零、透支者扣 MP。
## 瘟疫：病灶阈值 8、病弱上限 −60%、毒腺中毒不能治疗、混乱 2 回合、全体挑衅与打它的人混乱、疫源让减益免疫无效。
## 死亡：骑士队长让别的模块的保命失效。蚀骨（非终焉）的同种异化不触发这些。数字避开 4。

const CONFIG := "user://xiyou_tianqi_alien_finale_config.json"
const TROOP3 := 2   # 嘤嘤怪×3
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(line: String) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	s.set_variable(20, 3)
	XState.current = s
	s.flags.tianqi["line"] = line
	XTianqiLine.progress(line, s)["stage"] = XTianqiLine.stage_done(line)
	for a in s.members():
		a.add_param(0, 100000.0)
		a.recover_all()
	return s


## 开一场，第 i 只敌人变成 line 的 kind（tier 级）
func _fight(line: String, rows: Array) -> XBattleLogic:
	var s := _state(line)
	var lg := XBattleLogic.new()
	lg.setup(TROOP3, s)
	var list := []
	for r in rows:
		list.append({"enemy": lg.enemies[int(r[0])], "tier": str(r[1]), "kind": str(r[2])})
	XTianqiLine.alien_apply(line, lg, s, list)
	return lg


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	_war()
	_famine()
	_plague()
	_death()
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 战争 ----

func _war() -> void:
	# 战狂：终焉免疫能力值减益，蚀骨不免疫
	var lg := _fight("war", [[0, "zhongyan", "berserk"], [1, "shigu", "berserk"]])
	lg.sequence_buff(lg.enemies[0], 2, true, false, 3)
	lg.sequence_buff(lg.enemies[1], 2, true, false, 3)
	_check("berserk_immune", int(lg.enemies[0].buffs[2]) == 0 and int(lg.enemies[1].buffs[2]) == -1, [lg.enemies[0].buffs[2], lg.enemies[1].buffs[2]])
	lg.end_battle(1)
	# 号令官：终焉自己按其他活着的怪多动（上限 3）；蚀骨不加
	var lc := _fight("war", [[0, "zhongyan", "commander"]])
	var cmd: XEnemy = lc.enemies[0]
	_check("commander_finale", XTianqiWarAlien.extra_actions(lc, cmd) == 2 + 2 and XTianqiWarAlien.extra_actions(lc, lc.enemies[1]) == 2,
		[XTianqiWarAlien.extra_actions(lc, cmd), XTianqiWarAlien.extra_actions(lc, lc.enemies[1])])
	lc.enemies[2].hp = 0.0
	lc.enemies[2].add_state(1)
	_check("commander_counts_alive", XTianqiWarAlien.extra_actions(lc, cmd) == 2 + 1)
	lc.end_battle(1)
	var lc2 := _fight("war", [[0, "shigu", "commander"]])
	_check("commander_shigu", XTianqiWarAlien.extra_actions(lc2, lc2.enemies[0]) == 1)
	lc2.end_battle(1)
	# 烟火师：终焉火花满时轰炸我方全体
	var lp := _fight("war", [[0, "zhongyan", "pyro"]])
	var f := XTianqiWarAlien.fight(lp)
	f.sparks = XTianqiWarAlien.spark_full(lp) - 1
	var before := lp.actors.map(func(a): return a.hp)
	var logs := XTianqiWarAlien.after_action(lp, lp.enemies[0])
	var hurt := 0
	for i in lp.actors.size():
		if lp.actors[i].hp < before[i]:
			hurt += 1
	_check("pyro_bomb", hurt == lp.actors.size() and logs.any(func(l): return str(l.get("text", "")).contains("轰炸")), [hurt, lp.actors.size()])
	lp.end_battle(1)
	var lp2 := _fight("war", [[0, "huaxing", "pyro"]])
	XTianqiWarAlien.fight(lp2).sparks = XTianqiWarAlien.spark_full(lp2) - 1
	var b2 := lp2.actors.map(func(a): return a.hp)
	XTianqiWarAlien.after_action(lp2, lp2.enemies[0])
	_check("pyro_huaxing_no_bomb", lp2.actors.map(func(a): return a.hp) == b2)
	lp2.end_battle(1)
	# 战意：终焉满层那次再动伤害 ×2，打完清；化形起清一个减益
	var lf := _fight("war", [[0, "zhongyan", "fervor"]])
	var fv: XEnemy = lf.enemies[0]
	var ff := XTianqiWarAlien.fight(lf)
	var r: Dictionary = ff.units[fv]
	lf.sequence_buff(fv, 3, true, false, 3)
	r.fervor = int(XTianqiWarAlien.kind_info("fervor").full[3]) - 1
	ff.hit[fv] = true
	var a: XActor = lf.actors[0]
	XTianqiWarAlien.after_action(lf, a)
	_check("fervor_cleanse", int(fv.buffs[3]) == 0, fv.buffs)
	var normal := XTianqiWarAlien.hp_damage(lf, lf.enemies[1], a, 100.0)
	var boosted := XTianqiWarAlien.hp_damage(lf, fv, a, 100.0)
	_check("fervor_double", is_equal_approx(boosted, normal * 2.0), [normal, boosted])
	XTianqiWarAlien.after_action(lf, fv)
	_check("fervor_cleared", is_equal_approx(XTianqiWarAlien.hp_damage(lf, fv, a, 100.0), normal))
	lf.end_battle(1)


# ---- 饥荒 ----

func _famine() -> void:
	var lg := _fight("famine", [[0, "zhongyan", "night"], [1, "zhongyan", "exhaust"], [2, "zhongyan", "overdraw"]])
	var a: XActor = lg.actors[0]
	var mmp0 := a.mmp
	for x in lg.actors:
		x.tp = 50.0
	XTianqiFamineAlien.start_turn(lg)
	_check("night_tp_zero", lg.actors.all(func(x): return float(x.tp) == 0.0))
	_check("exhaust_mmp", a.mmp < mmp0 and a.mmp >= floorf(mmp0 * 0.95) - 1.0, [mmp0, a.mmp])
	XTianqiFamineAlien.start_turn(lg)
	_check("exhaust_mmp_stacks", a.mmp < floorf(mmp0 * 0.95), [mmp0, a.mmp])
	a.mp = 100.0
	XTianqiFamineAlien.after_pay(lg, a, XDB.rec("Skills", 10), {"mp": 5, "tp": 0})
	_check("overdraw_mp", a.mp <= 90.0, a.mp)
	lg.end_battle(1)
	_check("mmp_back", a.mmp == mmp0, [mmp0, a.mmp])
	# 荒年者：终焉复活这一下不回
	var ll := _fight("famine", [[0, "zhongyan", "lean"]])
	var d: XActor = ll.actors[1]
	d.hp = 0.0
	d.add_state(1)
	d.remove_state(1)
	_check("lean_revive_blocked", d.hp == 1.0 and XTianqiFamineAlien.gain(d, "hp", 100.0) == 0.0)
	XTianqiFamineAlien.take_logs(ll)
	_check("lean_after_action", XTianqiFamineAlien.gain(d, "hp", 100.0) > 0.0)
	ll.end_battle(1)
	var ll2 := _fight("famine", [[0, "shigu", "lean"]])
	var d2: XActor = ll2.actors[1]
	d2.hp = 0.0
	d2.add_state(1)
	d2.remove_state(1)
	_check("lean_shigu", XTianqiFamineAlien.gain(d2, "hp", 100.0) > 0.0)
	ll2.end_battle(1)


# ---- 瘟疫 ----

func _debuff_state() -> int:
	for st in XDB.table("States"):
		if st is Dictionary and int(st.get("id", 0)) > 1 and XBossStatus.kind_of(st) == "Debuff":
			return int(st.id)
	return 0


func _plague() -> void:
	var lg := _fight("plague", [[0, "zhongyan", "gland"], [1, "zhongyan", "taunt"], [2, "zhongyan", "source"]])
	_check("focus_eight", XTianqiPlagueAlien._focus_full(lg) == 8)
	var f := XTianqiPlagueAlien.fight(lg)
	var a: XActor = lg.actors[0]
	f.debuffs[a] = 30
	_check("frail_sixty", is_equal_approx(XTianqiPlagueAlien.frail_rate(lg, a), 0.6), XTianqiPlagueAlien.frail_rate(lg, a))
	# 毒腺：中毒的人不能被治疗
	XTianqiPlagueAlien._add_poison(lg, f, lg.enemies[0], a, 3)
	_check("gland_no_heal", XTianqiPlagueAlien.gain(a, "hp", 100.0) == 0.0 and XTianqiPlagueAlien.gain(lg.actors[1], "hp", 100.0) == 100.0)
	# 挑衅者：群体攻击也只打它；打它的人混乱、不再不服
	var all_skill := {"scope": 2, "damage": {"type": 1, "elementId": 0}}
	var kept := XTianqiPlagueAlien.filter_targets(lg, a, all_skill, lg.enemies.duplicate())
	_check("taunt_all", kept.size() == 1 and is_same(kept[0], lg.enemies[1]), kept.size())
	var b: XActor = lg.actors[1]
	XTianqiPlagueAlien.hp_damage(lg, b, lg.enemies[1], 10.0, {"scope": 1})
	_check("taunt_confuse", b.is_state_affected(int(XTianqiPlagueAlien.data().confusion_state)) and int(XTianqiPlagueAlien.mark_of(lg, b).get("defy", 0)) == 0)
	# 疫源：减益免疫无效
	var sid := _debuff_state()
	_check("source_forced", sid > 0 and XTianqiPlagueAlien.forced_state(a, sid) and not XTianqiPlagueAlien.forced_state(lg.enemies[0], sid), sid)
	lg.end_battle(1)
	# 蚀骨：阈值、上限、毒腺、挑衅都照旧
	var ls := _fight("plague", [[0, "shigu", "gland"], [1, "shigu", "taunt"], [2, "shigu", "source"]])
	var fs := XTianqiPlagueAlien.fight(ls)
	var c: XActor = ls.actors[0]
	fs.debuffs[c] = 30
	XTianqiPlagueAlien._add_poison(ls, fs, ls.enemies[0], c, 1)
	_check("shigu_plain", XTianqiPlagueAlien._focus_full(ls) == 12 and is_equal_approx(XTianqiPlagueAlien.frail_rate(ls, c), 0.3)
		and XTianqiPlagueAlien.gain(c, "hp", 100.0) == 100.0 and XTianqiPlagueAlien.filter_targets(ls, c, all_skill, ls.enemies.duplicate()).size() == 3
		and not XTianqiPlagueAlien.forced_state(c, sid))
	ls.end_battle(1)
	# 混乱者：终焉一次 2 回合（几率按表；测试把终焉档几率临时调成必中）
	var lc := _fight("plague", [[0, "zhongyan", "chaos"]])
	var k: Dictionary = XTianqiPlagueAlien.kind_info("chaos")
	var old: float = k.chance[3]
	k.chance[3] = 1.0
	var t: XActor = lc.actors[0]
	XTianqiPlagueAlien.hp_damage(lc, lc.enemies[0], t, 10.0)
	var cid := int(XTianqiPlagueAlien.data().confusion_state)
	_check("chaos_two_turns", t.is_state_affected(cid) and int(t.state_turns.get(cid, 0)) >= 2, t.state_turns)
	k.chance[3] = old
	lc.end_battle(1)


# ---- 死亡 ----

func _death() -> void:
	var lg := _fight("death", [[0, "huaxing", "captain"]])
	_check("captain_breaks_saves", XTianqiDeathAlien.breaks_saves(lg))
	lg.end_battle(1)
	var ln := _fight("death", [[0, "huaxing", "reaper"]])
	_check("no_captain_saves", not XTianqiDeathAlien.breaks_saves(ln))
	ln.end_battle(1)
