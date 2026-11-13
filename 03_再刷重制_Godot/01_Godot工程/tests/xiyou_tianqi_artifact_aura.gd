extends Node
## 天启篇通用法宝光环专项（XTianqiAffixRoll 法宝分支；词条稿 v0.3 第 7 节）。
## 通用法宝 50% 带一条光环（只出光环），阶按等级／满级随养成；升级时重定阶、说明跟着变；专属法宝不掷；全队光环生效；原版档不掷。

const CONFIG := "user://xiyou_tianqi_artifact_aura_config.json"
const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state() -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	return s


func _find(general: bool) -> int:
	var table: Array = XDB.table("Armors")
	for r in table:
		if r is Dictionary and int(r.get("etypeId", 0)) == 13 and str(r.get("note", "")).contains("Magic Weapon"):
			if XTianqiAffixRoll.general_artifact(XGear.template("armor", int(r.id))) == general:
				return int(r.id)
	return 0


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	var s := _state()
	var gid := _find(true)
	var xid := _find(false)
	_check("found", gid > 0 and xid > 0, [gid, xid])
	# 必带（掷数 0）：只出光环、阶按等级
	XGear.roll_fn = func(): return 0.0
	var it := XGear.create("armor", gid, s)
	var list: Array = it.get("tianqi_affixes", [])
	_check("one_aura", list.size() == 1 and str(T.affix(str(list[0].key)).layer) == "aura" and bool(list[0].growth), list)
	_check("tier_by_growth", list.size() == 1 and int(list[0].tier) == XTianqiAffixRoll.artifact_tier_of(it), [XMagicWeapon.level_of(it), XMagicWeapon.max_level(it)])
	# 不带（掷数接近 1）
	XGear.roll_fn = func(): return 0.99
	_check("half_none", not XGear.create("armor", gid, s).has("tianqi_affixes"))
	# 专属法宝不掷
	XGear.roll_fn = func(): return 0.0
	_check("exclusive_none", not XGear.create("armor", xid, s).has("tianqi_affixes"))
	XGear.roll_fn = Callable()
	# 升级：阶跟着变，说明跟着变
	s.set_variable(20, 30)  # 法宝上限跟楼层走（O-待定-1）：30 层上限才到 99
	var mx := XMagicWeapon.max_level(it)
	it.level = 1.0
	XTianqiAffixRoll.refresh_growth(it)
	var low := int(it.tianqi_affixes[0].tier)
	var desc_low := str(it.description)
	it.level = mx - 1.0
	it.exp = XMagicWeapon.next_level_exp(it)
	XMagicWeapon.level_up(it)
	_check("level_up_tier", low == 2 and int(it.tianqi_affixes[0].tier) == 4 and str(it.description) != desc_low, [low, it.tianqi_affixes[0].tier, mx])
	_check("tier_steps", T.artifact_tier(0.2) == 2 and T.artifact_tier(0.5) == 3 and T.artifact_tier(0.9) == 4)
	# 全队光环：穿上后上场的人吃到
	var a: XActor = s.battle_members()[0]
	var slot := a.equip_slots().find(13)
	s.register_gear(it)
	s.gear.append(it)
	_check("slot_found", slot >= 0)
	if slot >= 0:
		XEquipment.change(s, a, slot, it)
		_check("party_aura", XTianqiAffixBattle.party_aura(XTianqiAffixBattle.members(s)).size() == 1, XTianqiAffixBattle.party_aura(XTianqiAffixBattle.members(s)))
	# 原版档不掷
	var plain := XState.new_game(3, 1, [8, 9, 10])
	XState.current = plain
	XGear.roll_fn = func(): return 0.0
	_check("plain_none", not XGear.create("armor", gid, plain).has("tianqi_affixes"))
	XGear.roll_fn = Callable()
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
