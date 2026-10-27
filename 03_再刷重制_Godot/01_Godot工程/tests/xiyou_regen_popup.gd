extends Node
## regen 记录与播放器的符号契约：记录 hp 与 hpDamage 同号（正伤害、负回复），播放器原样传给 XDamagePopup。
## 真实生产者：HP 再生（正、负）、叠毒 Regenerate 脚本、异化 gainHp 扣血；断言实际弹字的 kind 与数值。
var passed := 0
var total := 0

class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

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
	await live._play(logs)
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

	live.logic.end_battle()
	live.queue_free()
	print("TEST_RESULT=" + JSON.stringify({"total": total, "passed": passed}))
	get_tree().quit(0 if passed == total else 1)
