extends Node
## 天启篇第二批（XTianqi，Kyo 2026-11-10「开始吧」）：
## 一、上场 4 人＋1 个助力位：battle_members 只取前 4 格，helper 是第 5 格；超强者上限只算上场的；原版档照旧 5 人。
## 二、招募：新角色只从开局阵容和通关抽角色来（事件入队、号角、号角上架都拦）；开关回退。
## 三、通关抽角色：每通关 5 层一次、最多 6 次；按难度表的档位与几选一；候选记进存档不能重抽；自选给整池；大厅对话走完。
## 四、真实战斗：助力位不上场、拿满经验；「换人」指令；战斗中换人（角色图、状态行、出战栏），换完照常打完。

class QuickBattle extends XBattleScene:
	func _defeat_message() -> void:
		await get_tree().process_frame


## 大厅对话的替身宿主：文字直接过，选项依次取 answers（取完选第一个）
class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	func show_text(_f: String, _i: int, _lines: Array) -> void:
		pass
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else 0


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTianqiSkills.ids(tier, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and not [95, 173].has(id))  # 三笠、饿狼的战斗档位跟成长走，夹具不用


func _state(key: String, lineup: Array) -> XState:
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		s.add_actor(int(id))
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XSave.dir_override = "user://test_xiyou_tianqi_party"
	Engine.time_scale = 6.0
	seed(20261111)
	_slots()
	_recruit()
	_draws()
	await _draw_dialog()
	await _battle()
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _slots() -> void:
	var w := _ids(XTier.WEAK)
	var sup := _ids(XTier.SUPER)
	var s := _state("jiusi", [w[0], w[1], w[2], w[3], w[4]])
	_check("party_lineup", s.party == [w[0], w[1], w[2], w[3], w[4]], s.party)
	_check("fighters_four", s.battle_members().map(func(a): return a.actor_id) == [w[0], w[1], w[2], w[3]], s.battle_slots)
	_check("helper_fifth", s.helper() != null and s.helper().actor_id == w[4])
	# 超强者：九死上限 1，只算上场 4 格；助力位放超强者不算
	XTianqi._joining = true
	for id in sup.slice(0, 3):
		s.add_actor(id)
	XTianqi._joining = false
	s.battle_slots = [sup[0], w[1], w[2], w[3], sup[1]]
	XItemMarks.enforce_party(s)
	_check("helper_super_kept", s.battle_slots == [sup[0], w[1], w[2], w[3], sup[1]], s.battle_slots)
	_check("can_deploy_slot", not XItemMarks.can_deploy(s, sup[2], 1) and XItemMarks.can_deploy(s, sup[2], XTianqi.HELPER_SLOT)
		and XItemMarks.can_deploy(s, sup[2], 0) and XItemMarks.can_deploy(s, sup[2]))
	s.battle_slots = [sup[0], sup[1], w[2], w[3], w[4]]
	XItemMarks.enforce_party(s)
	_check("fighter_cap_enforced", s.battle_slots.slice(0, 4).filter(func(id): return XTianqiSkills.is_super(int(id), true)).size() == 1 and s.battle_slots[0] == sup[0], s.battle_slots)
	# 原版档：5 人上场、没有助力位
	var old := XState.new_game_blank()
	old.party.clear()
	for id in w.slice(0, 5):
		old.add_actor(id)
	_check("legacy_five", old.battle_members().size() == 5 and old.helper() == null and XTianqi.fighter_slots(old) == 5)


func _recruit() -> void:
	var w := _ids(XTier.WEAK)
	var st := _ids(XTier.STRONG)
	var s := _state("jianxian", [w[0], w[1], w[2], w[3], st[0]])
	s.add_actor(st[1])
	_check("event_join_blocked", not s.party.has(st[1]), s.party)
	var horn := 0
	for rec in XDB.table("Items"):
		if rec is Dictionary and XItemMarks.recruit_actor_id(rec) > 0 and not XImportedBalance.DISABLED_HORNS.has(int(rec.id)):
			horn = int(rec.id)
			break
	s.gain_item(horn, 1)
	_check("horn_blocked", horn > 0 and s.item_count(horn) == 0 and not XItemMarks.can_buy(s, XDB.rec("Items", horn), 0), horn)
	XTianqi.NO_RECRUIT = false
	s.add_actor(st[1])
	s.gain_item(horn, 1)
	_check("recruit_switch_back", s.party.has(st[1]) and s.item_count(horn) == 1 and not XTianqi.draw_ready(s))
	XTianqi.NO_RECRUIT = true
	var old := XState.new_game_blank()
	old.add_actor(st[2])
	_check("legacy_join", old.party.has(st[2]))


func _draws() -> void:
	for key in XTianqi.DRAW_TABLE:
		var rows: Array = XTianqi.DRAW_TABLE[key]
		var low: bool = key == "xunchang" or key == "jianxian"
		_check("table_%s" % key, rows.size() == XTianqi.DRAW_MAX and (not low or rows.all(func(r): return not r[0].has(XTier.SUPER))), rows)
	var w := _ids(XTier.WEAK)
	var s := _state("jiusi", [w[0], w[1], w[2], w[3], w[4]])
	s.set_variable(20, 5)
	_check("not_yet", not XTianqi.draw_ready(s) and XTianqi.draws_earned(s) == 0)
	s.set_variable(20, 6)
	var offer := XTianqi.draw_offer(s)
	_check("first_offer", XTianqi.draw_ready(s) and offer.size() == 2 and offer.all(func(id): return XTianqiSkills.is_weak(id, true) and not s.party.has(id)), offer)
	_check("offer_kept", XTianqi.draw_offer(s) == offer and s.flags.tianqi.get("offer") == offer)
	_check("take_outside_offer", not XTianqi.take_draw(s, w[10]) if not offer.has(w[10]) else true)
	_check("take_draw", XTianqi.take_draw(s, offer[1]) and s.party.has(offer[1]) and XTianqi.draws_used(s) == 1 and not s.flags.tianqi.has("offer"))
	_check("one_per_five", not XTianqi.draw_ready(s))
	s.set_variable(20, 99)
	_check("capped_six", XTianqi.draws_earned(s) == 6)
	var counts := []
	while XTianqi.draw_ready(s):
		var r := XTianqi.draw_rule(s, XTianqi.draws_used(s))
		var o := XTianqi.draw_offer(s)
		counts.append(o.size() if int(r.count) > 0 else 0)
		var ok: bool = o.all(func(id): return r.tiers.has(XTianqiSkills.tier_of(id, true)))
		if not ok or not XTianqi.take_draw(s, o[o.size() - 1]):
			break
	_check("all_draws", XTianqi.draws_used(s) == 6 and s.party.size() == 11 and counts == [2, 3, 3, 3, 0], [counts, s.party.size()])


func _draw_dialog() -> void:
	var w := _ids(XTier.WEAK)
	var s := _state("lianyu", [w[0], w[1], w[2], w[3], w[4]])
	s.set_variable(20, 11)
	var host := FakeHost.new()
	host.answers = [3]  # 第一次（弱者三选一）选「稍后再选」
	await XTianqi.run_draw(host, s)
	_check("dialog_later", XTianqi.draws_used(s) == 0 and host.asked.size() == 1 and host.asked[0].size() == 4)
	var kept: Array = s.flags.tianqi.get("offer", [])
	host.answers = [2, 0]
	await XTianqi.run_draw(host, s)
	_check("dialog_two", XTianqi.draws_used(s) == 2 and s.party.has(kept[2]) and host.asked[1].slice(0, 3) == kept.map(func(id): return XTianqi._actor_label(id)), [kept, s.party])


func _battle() -> void:
	var w := _ids(XTier.WEAK)
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := _state("jiusi", lineup)
	for id in lineup:
		s.actor(id).recover_all()
	var scene := QuickBattle.new()
	scene.setup(2, true, false, XDB.map(4))
	var lg := scene.logic
	_check("battle_four", lg.actors.size() == 4 and not lg.actors.has(s.helper()))
	_check("swap_command", scene._command_entries(lg.actors[0]).any(func(o): return o.key == "tianqiSwap"))
	XTianqi.SWAP_IN_BATTLE = false
	_check("swap_switch_off", not lg.can_tianqi_swap(lg.actors[0]) and not scene._command_entries(lg.actors[0]).any(func(o): return o.key == "tianqiSwap"))
	XTianqi.SWAP_IN_BATTLE = true
	get_tree().root.add_child(scene)
	await _until(func(): return scene.sprites.size() > 0 and scene.status_rows.size() == 4)
	var out: XActor = lg.actors[0]
	var h := s.helper()
	await scene._tianqi_swap(out)
	_check("swapped_logic", lg.actors[0] == h and not lg.actors.has(out) and s.battle_slots[0] == h.actor_id and s.battle_slots[4] == out.actor_id,
		[s.battle_slots, lg.actors.map(func(a): return a.actor_id)])
	_check("swapped_scene", scene.sprites.has(h) and not scene.sprites.has(out) and scene.status_rows.has(h) and not scene.status_rows.has(out))
	var result: int = await scene.finished
	_check("battle_won", result == 0, result)
	# 经验直接按一份固定奖励发（敌群 2 自动战斗的掉落经验在不同机器上会是 0，云端 11-11 碰到过）：上场的和助力位一样多，替补按后备比例（西游 optExtraExp 开着，后备也拿满，各人 exr 不同）
	XTianqi._joining = true
	s.add_actor(w[5])
	XTianqi._joining = false
	var lg2 := XBattleLogic.new()
	lg2.setup(2, s)
	var ids := [lg2.actors[0].actor_id, s.helper().actor_id, w[5]]
	var before := ids.map(func(id): return s.actor(id).exp_total)
	lg2.grant({"exp": 50, "gold": 0, "drops": []})
	var gained := range(3).map(func(i): return s.actor(ids[i]).exp_total - before[i])
	var bench := 50 if bool(XDB.system().get("optExtraExp", false)) else 0
	_check("helper_full_exp", gained[0] > 0 and gained[1] == gained[0] and (gained[2] > 0) == (bench > 0), [ids, gained])
	scene.bgm.stop()
	scene.se.stop()
	scene.queue_free()
	await get_tree().create_timer(0.3, true, false, true).timeout


func _until(cond: Callable, frames := 3000) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false
