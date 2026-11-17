extends Node
## regen 记录与播放器的符号契约：记录 hp 与 hpDamage 同号（正伤害、负回复），播放器原样传给 XDamagePopup。
## 真实生产者：HP 再生（正、负）、叠毒 Regenerate 脚本、异化 gainHp 扣血；断言实际弹字的 kind 与数值。
var passed := 0
var total := 0

class QuietBattle extends XBattleScene:
	var seq_popups := 0  # 序列播放器在演时出的弹字（T119 返修专项看序列有没有真演）
	func _main() -> void:
		pass
	func _popup(b: XBattler, value: float, critical: bool, text := "", is_mp := false, is_tp := false) -> void:
		if seq_player != null:
			seq_popups += 1
		super(b, value, critical, text, is_mp, is_tp)

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))

func frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame

## 第一个只有一条 HP 再生率特性（xparam 7）、符号符合要求、没有脚本效果的状态
func hrg_state(positive: bool) -> int:
	for st in XDB.table("States"):
		if st == null or int(st.get("id", 0)) <= 1 or not st.get("effects", []).is_empty():
			continue
		var tr: Array = st.get("traits", [])
		if tr.size() == 1 and int(tr[0].code) == 22 and int(tr[0].dataId) == 7 and (float(tr[0].value) > 0.0) == positive and float(tr[0].value) != 0.0:
			return int(st.id)
	return 0

func popups_after(live: XBattleScene, logs: Array) -> Array:
	for c in live.fx.get_children():
		c.free()
	live._popups.clear()
	await live._play(logs)
	live.drain_popups()  # 弹数每帧每人出一个（POPUP_QUEUE）：排着的也算
	return live.fx.get_children().filter(func(c): return c is XDamagePopup)

func expect(tag: String, live: XBattleScene, logs: Array, kind: String, hp: float) -> void:
	var regen := logs.filter(func(l): return l.type == "regen")
	check(tag + ".produced", regen.size() == 1, regen.size())
	if regen.size() != 1:
		return
	check(tag + ".record_hp", float(regen[0].hp) == hp, [regen[0].hp, hp])
	var shown: Array = await popups_after(live, regen)
	check(tag + ".one_popup", shown.size() == 1, shown.size())
	if shown.size() == 1:
		check(tag + ".kind", shown[0].kind == kind, [shown[0].kind, kind])
		check(tag + ".text", shown[0].text.ends_with(XDamagePopup.format_number(hp)), shown[0].text)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	XConfig.set_flag("CombatDamageShow", true)
	XConfig.set_battle_speed(4)
	XEnemy.force_roll = 100.0
	XState.new_game(3, 1, [8, 9, 10])
	var live := QuietBattle.new()
	live.setup(2, true, false, {})
	add_child(live)
	await frames()
	var e: XEnemy = live.logic.enemies[0]
	var mhp := e.mhp

	# HP 再生为负（持续伤害）：hpDamage 为正，弹伤害字
	var bad := hrg_state(false)
	check("found_negative_hrg", bad > 0)
	e.hp = mhp
	e.add_state(bad)
	e.param_refresh()
	var logs := []
	live.logic._regenerate(e, logs)
	var loss := mhp - e.hp
	check("negative.loses", loss > 0.0, loss)
	await expect("negative", live, logs, "hp", loss)
	e.remove_state(bad)

	# HP 再生为正：hpDamage 为负，弹治疗字
	var good := hrg_state(true)
	check("found_positive_hrg", good > 0)
	e.hp = floorf(mhp / 2.0)
	e.add_state(good)
	e.param_refresh()
	var before := e.hp
	var requested := floorf(e.mhp * e.hrg * e.rec)  # gainHp 结果槽记请求值 −value，不是截到上限后的实际回升
	logs = []
	live.logic._regenerate(e, logs)
	check("positive.gains", e.hp > before and requested > 0.0, [before, e.hp, requested])
	await expect("positive", live, logs, "hp_heal", -requested)
	e.remove_state(good)
	e.param_refresh()

	# 叠毒 Regenerate 脚本（460，角色 1 施加；伤害按来源能力值）：记录 r.hpDamage（实扣，正）
	var poison := 460
	check("found_poison", XDB.rec("States", poison).get("effects", []).any(func(x): return x.get("op") == "poison_tick"))
	e.hp = mhp
	XImportedBalance.set_acting(live.logic.actors[0])
	e.add_state(poison)
	XImportedBalance.set_acting(null)
	before = e.hp
	live.logic.start_turn()
	logs = live.logic.end_turn().filter(func(l): return l.type == "regen" and l.target == e and l.has("state"))
	check("poison.loses", before - e.hp > 0.0, before - e.hp)
	await expect("poison", live, logs, "hp", before - e.hp)
	e.remove_state(poison)

	# 异化 gainHp(-n)：记录 before − after（实扣，正）
	e.hp = mhp
	logs = []
	XAlienBattle._lose_hp(live.logic, e, 10.0, logs)
	await expect("alien", live, logs, "hp", 10.0)

	# T119 返修（小A P1）：烧命 regen 在「行动」之前时，带 yepSeq 的技能照样交给 XSequencePlayer（命中弹字照出）；
	# 夹在「行动」与 seq_phase 之间（返修前的次序）就掉进非序列分支，seq_* 全丢、只剩烧命一个弹字
	e.hp = mhp
	var a: XActor = live.logic.actors[0]
	var act_logs := live.logic.act(a, a.attack_skill(), e)
	var ai := act_logs.find(act_logs.filter(func(l): return l.type == "action").front())
	check("burn_seq.has_seq", XActionSequence.has_sequence(a.attack_skill()) and ai >= 0 and act_logs.slice(ai + 1).any(func(l): return l.type == "seq_phase"))
	var burn := {"type": "regen", "target": a, "hp": 7.0, "views": live.logic.views([a])}
	var fixed := act_logs.duplicate()
	fixed.insert(ai, burn)
	live.seq_popups = 0
	await popups_after(live, fixed)
	var seq_fixed := live.seq_popups
	var broken := act_logs.duplicate()
	broken.insert(ai + 1, burn)
	live.seq_popups = 0
	await popups_after(live, broken)
	check("burn_seq.plays", seq_fixed >= 1 and live.seq_popups == 0, [seq_fixed, live.seq_popups])

	live.logic.end_battle()
	live.queue_free()
	print("TEST_RESULT=" + JSON.stringify({"total": total, "passed": passed}))
	get_tree().quit(0 if passed == total else 1)
