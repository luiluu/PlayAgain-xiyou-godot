extends Node
## 【cc·未经审查】T074：夏娜专武贽殿遮那普攻（XBattler.SHANA_ZHUANWU_ATTACK_FIX）。
## 原版 MOD 数据错：武器 77／83 写 <Replace Attack: 5769>＋<Weapon Unleash 100%: 5769>，5769 是科比被动「8秒肘击24下」（occasion 3），
## 夏娜普攻显示成八秒肘击且用不了（v0.03 玩家反馈）；说明写的天破壤碎是 10556。
## 开：普攻＝10556、能用、不再有 5769 的武器解放；关：逐字回原版 5769；科比学 5769 被动、带别的武器照旧。

const SHANA := 154
const KOBE := 109
const WRONG := 5769
const TIANPO := 10556
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _logic() -> XBattleLogic:
	var s := XState.new_game(3, 1, [8])
	s.switches[2494] = true  # 超强者开放
	s.add_actor(SHANA)
	s.add_actor(KOBE)
	XState.current = s
	var logic := XBattleLogic.new()
	logic.setup(222, s)
	for id in [SHANA, KOBE]:
		var a: XActor = s.actor(id)
		a.change_level_mv(35)
		a.refresh_passive()
		a.recover_all()
	return logic


func _equip(a: XActor, base: int) -> void:
	a.keep_unequippable = true
	a.equips[0] = XGear.template("weapon", base)
	a.refresh_passive()


func _unleash_ids(a: XActor) -> Array:
	return a.weapon_unleashes().map(func(u): return int(u[0]))


func _run() -> void:
	var logic := _logic()
	var s := logic.state
	var shana: XActor = s.actor(SHANA)
	var kobe: XActor = s.actor(KOBE)
	# 原版数据证据：两把武器确实写着 5769，5769 是永不可用的被动，10556 才是天破壤碎
	for w in [77, 83]:
		var note := str(XDB.rec("Weapons", w).get("note", ""))
		check("data.w%d_note_5769" % w, note.contains("<Replace Attack: 5769>") and note.contains("<Weapon Unleash 100%: 5769>"), w)
	check("data.5769_passive", str(XDB.rec("Skills", WRONG).name) == "8秒肘击24下" and int(XDB.rec("Skills", WRONG).occasion) == 3)
	check("data.10556_tianpo", str(XDB.rec("Skills", TIANPO).name) == "天破壤碎" and int(XDB.rec("Skills", TIANPO).occasion) in [0, 1])
	for w in [77, 83]:
		XBattler.SHANA_ZHUANWU_ATTACK_FIX = true
		_equip(shana, w)
		check("on.w%d.attack_is_tianpo" % w, shana.attack_skill_id() == TIANPO, shana.attack_skill_id())
		check("on.w%d.attack_name" % w, str(shana.attack_skill().name) == "天破壤碎", shana.attack_skill().get("name"))
		check("on.w%d.can_use" % w, logic.can_use(shana, shana.attack_skill()))
		check("on.w%d.no_5769_unleash" % w, not _unleash_ids(shana).has(WRONG), _unleash_ids(shana))
		check("on.w%d.is_attack" % w, shana.is_attack(XDB.rec("Skills", TIANPO)))
		XBattler.SHANA_ZHUANWU_ATTACK_FIX = false
		check("off.w%d.attack_is_5769" % w, shana.attack_skill_id() == WRONG, shana.attack_skill_id())
		check("off.w%d.cannot_use" % w, not logic.can_use(shana, shana.attack_skill()))
		check("off.w%d.unleash_5769" % w, _unleash_ids(shana).has(WRONG), _unleash_ids(shana))
	XBattler.SHANA_ZHUANWU_ATTACK_FIX = true
	# 不带专武：普攻是技能 1
	shana.equips[0] = XGear.template("weapon", 1)
	shana.refresh_passive()
	check("shana.no_zhuanwu_attack1", shana.attack_skill_id() == 1, shana.attack_skill_id())
	# 科比：被动 5769 照旧，普攻不受开关影响；同一把武器的修正只看武器号，不看持有者（换给科比也一样是 10556）
	kobe.learn_skill(WRONG)
	kobe.refresh_passive()
	var kobe_attack := kobe.attack_skill_id()
	XBattler.SHANA_ZHUANWU_ATTACK_FIX = false
	check("kobe.attack_unchanged_by_switch", kobe.attack_skill_id() == kobe_attack, [kobe_attack, kobe.attack_skill_id()])
	XBattler.SHANA_ZHUANWU_ATTACK_FIX = true
	check("kobe.attack_not_tianpo", kobe_attack != TIANPO and kobe_attack != WRONG, kobe_attack)
	check("kobe.has_5769_passive", kobe.skill_ids.has(WRONG) and str(kobe.skills().filter(func(k): return int(k.id) == WRONG)[0].get("note", "")).contains("SkillPass5762"))
	# 修正只认武器 77／83：别的武器（假造）写 5769 不改、防具同号不改
	var fake := {"id": 78, "base": 78.0, "wtypeId": 1, "note": "<Replace Attack: 5769>\n<Weapon Unleash 100%: 5769>"}
	check("fake_weapon.untouched", XBattler.replace_attack_of(fake) == WRONG and XBattler.weapon_unleash_of(fake).size() == 1)
	var armor := {"id": 77, "atypeId": 1, "note": "<Replace Attack: 5769>"}
	check("armor_same_id.untouched", XBattler.replace_attack_of(armor) == WRONG)
	# 别的武器的 <Replace Attack> 不受影响（火精灵文书 1109 → 1004）
	_equip(kobe, 1109)
	check("other_weapon.unchanged", kobe.attack_skill_id() == 1004, kobe.attack_skill_id())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
