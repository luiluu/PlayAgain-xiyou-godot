extends Node
## 天启篇新装备词条读档重掷修复专项（XTianqiAffixRoll.SEED_FROM_SAVE）：天启篇存档里新装备掷天启篇词条的随机由存档派生
## （orb_seed＋flags.tianqi.affix_roll_n）。走真实写盘读档（XSave.save → XSave.load_slot）：
##   存→生成装备→读→再生成，词条一样；存→打出掉落→读→再打同一场（战斗流钉住，只剩装备这一条流不同），词条一样；
##   老档缺计数字段能补；开关关掉回到运行时装备流（两次读档不同）；西游档照旧走 XGear.roll、不写计数。

const CONFIG := "user://xiyou_tianqi_affix_seed_config.json"
const SLOT := 1
const BATTLE_SEED := "0123456789abcdef"
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


func _find_weapon() -> int:
	for r in XDB.table("Weapons"):
		if r is Dictionary and str(r.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(r.id))
			if XQuality.grade(tpl) == 6 and XTianqiAffixRoll.tier_of(tpl) == 4 and not XEquipment.is_exclusive(tpl):
				return int(r.id)
	return 0


func _load() -> XState:
	return XState.current if XSave.load_slot(SLOT) else null


func _strip_file(fn: Callable) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	fn.call(d)
	XSave._write(XSave.path(SLOT), d)


## 读档后连生成 n 件同一把武器，返回各件的天启篇词条
func _create_run(wid: int, n: int) -> Array:
	var s := _load()
	var out := []
	if s == null:
		return out
	for k in n:
		out.append(JSON.stringify(XGear.create("weapon", wid, s).get("tianqi_affixes", [])))
	return out


func _direct() -> void:
	var wid := _find_weapon()
	_check("weapon", wid > 0)
	var s := _state()
	_check("saved", XSave.save(SLOT))
	var n0 := int(s.flags.tianqi.get("affix_roll_n", 0))
	var a := _create_run(wid, 6)
	var b := _create_run(wid, 6)
	_check("create_same", a.size() == 6 and a == b, [a, b])
	_check("create_varies", a.any(func(x): return x != a[0]), a)
	_check("create_affixed", a.all(func(x): return x != "[]"), a)
	_check("counter", int(XState.current.flags.tianqi.get("affix_roll_n", -1)) == n0 + 6, XState.current.flags.tianqi.get("affix_roll_n"))
	_check("prefix", _create_run(wid, 3) == a.slice(0, 3))
	# 老档：flags.tianqi 没有 affix_roll_n
	_strip_file(func(d): (d.flags.tianqi as Dictionary).erase("affix_roll_n"))
	var raw = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	_check("legacy_stripped", not (raw.flags.tianqi as Dictionary).has("affix_roll_n"))
	var l1 := _create_run(wid, 3)
	_check("legacy_init", int(XState.current.flags.tianqi.get("affix_roll_n", -1)) == 3 and l1 == _create_run(wid, 3), l1)
	# 开关关掉：运行时装备流（每次读档换一条），两次读档词条不同，不写计数
	XTianqiAffixRoll.SEED_FROM_SAVE = false
	var o1 := _create_run(wid, 6)
	var o2 := _create_run(wid, 6)
	_check("off_differs", o1 != o2, [o1, o2])
	_check("off_no_counter", not XState.current.flags.tianqi.has("affix_roll_n"))
	XTianqiAffixRoll.SEED_FROM_SAVE = true
	# 测试磁带、深渊商人的本轮种子照旧优先
	var s2 := _load()
	XGear.roll_fn = func(): return 0.0
	var f1 := JSON.stringify(XGear.create("weapon", wid, s2).get("tianqi_affixes", []))
	var f2 := JSON.stringify(XGear.create("weapon", wid, s2).get("tianqi_affixes", []))
	XGear.roll_fn = Callable()
	_check("roll_fn_first", f1 == f2 and not s2.flags.tianqi.has("affix_roll_n"), [f1, f2])
	# 西游档：不掷天启篇词条、不写计数
	var plain := XState.new_game(3, 1, [8, 9, 10])
	XState.current = plain
	var pi := XGear.create("weapon", wid, plain)
	_check("plain_untouched", not pi.has("tianqi_affixes") and not (plain.flags.get("tianqi", {}) as Dictionary).has("affix_roll_n"))


## 读档后在 map 打 troop 一场：战斗流钉成 BATTLE_SEED（同一场的掉落件一样），发奖，返回新得的装备（底子＋词条）
func _battle_run(map: int, troop: int) -> Array:
	var s := _load()
	if s == null:
		return []
	s.map_id = map
	var before := s.gear.duplicate()
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	lg.random = XBattleRandom.create(BATTLE_SEED, 0)
	for e in lg.enemies:
		e.hp = 0
		e.add_state(1)
	lg.grant(lg.rewards())
	lg.end_battle(0)
	var out := []
	for g in s.gear:
		if not before.any(func(x): return is_same(x, g)):
			out.append("%s:%d:%s" % [str(g.kind), int(g.base), JSON.stringify(g.get("tianqi_affixes", []))])
	return out


func _battle() -> void:
	var s := _state()
	# 找一张有遇敌的高层地图：打出来的装备里要有带天启篇词条的，才比得出东西
	var pick := []
	for m in range(1, 400):
		var floor := XDungeon.map_floor(m)
		if floor < 20 or not FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % m):
			continue
		var info := XDB.map(m)
		if info.is_empty() or (info.get("encounterList", []) as Array).is_empty():
			continue
		pick.append([m, int(info.encounterList[0].troopId)])
	_check("maps_found", not pick.is_empty(), pick.size())
	var chosen := []
	var first := []
	XSave.save(SLOT)
	for p in pick.slice(0, 40):
		var got := _battle_run(int(p[0]), int(p[1]))
		if got.any(func(x): return not str(x).ends_with(":[]")):
			chosen = p
			first = got
			break
	_check("battle_affixed_drop", not chosen.is_empty(), first)
	if chosen.is_empty():
		return
	var again := _battle_run(int(chosen[0]), int(chosen[1]))
	_check("battle_same", again == first, [first, again])
	XTianqiAffixRoll.SEED_FROM_SAVE = false
	var off1 := _battle_run(int(chosen[0]), int(chosen[1]))
	var off2 := _battle_run(int(chosen[0]), int(chosen[1]))
	var off3 := _battle_run(int(chosen[0]), int(chosen[1]))
	XTianqiAffixRoll.SEED_FROM_SAVE = true
	# 钉住战斗流后掉的是同几件，只有词条随运行时装备流变
	_check("battle_off_same_items", off1.map(func(x): return str(x).get_slice(":", 1)) == first.map(func(x): return str(x).get_slice(":", 1)), [off1, first])
	_check("battle_off_differs", not (off1 == off2 and off2 == off3), [off1, off2, off3])


## 真实战斗结算入口（setup 里 XState.reserve_battle_random 取战斗流，rewards→grant）不钉战斗种子：
## 掉哪几件由战斗奖励流决定，它的根 XState.random_master 只在运行时、不进存档（读档后现开一条），所以读档再打同一场
## 掉落件本身就会不同——这一层是整局既有口径（招牌掉落另走存档里的掉落账，读档一样），不是词条流的问题。
## 这里把这一层查清楚：①存档里没有 random_master；②读档后两次真打，只要战斗流的根一样（restore_runtime_random，正式的调试回放入口），
## 整场掉落（敌人掉落、通用掉落、招牌掉落）连同词条完全一样；③根不同时掉落件可以不同（只记录，不断言相等）。
func _real_run(map: int, troop: int, master: String) -> Dictionary:
	var s := _load()
	if s == null:
		return {}
	s.map_id = map
	if master != "":
		s.restore_runtime_random({"version": 1, "engine": XRandomStream.ENGINE, "master": master, "battleSerial": 0, "world": {}, "equipment": {}})
	var before := s.gear.duplicate()
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	for e in lg.enemies:
		e.hp = 0
		e.add_state(1)
	var rw: Dictionary = lg.rewards()
	lg.grant(rw)
	lg.end_battle(0)
	var got := []
	for g in s.gear:
		if not before.any(func(x): return is_same(x, g)):
			got.append("%s:%d:%s" % [str(g.kind), int(g.base), JSON.stringify(g.get("tianqi_affixes", []))])
	return {"master": s.random_master, "drops": JSON.stringify(rw.drops), "gear": got}


func _real_battle() -> void:
	var s := _state()
	s.reserve_battle_random()  # 开出战斗流的根（运行时）
	XSave.save(SLOT)
	var text := FileAccess.get_file_as_string(XSave.path(SLOT))
	_check("real_master_not_saved", s.random_master != "" and not text.contains(s.random_master), s.random_master)
	var pick := []
	for m in range(1, 400):
		if XDungeon.map_floor(m) < 20 or not FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % m):
			continue
		var info := XDB.map(m)
		if not (info.get("encounterList", []) as Array).is_empty():
			pick.append([m, int(info.encounterList[0].troopId)])
	var master := "00112233445566aa"
	var chosen := []
	var first := {}
	for p in pick.slice(0, 40):
		var r := _real_run(int(p[0]), int(p[1]), master)
		if (r.gear as Array).any(func(x): return not str(x).ends_with(":[]")):
			chosen = p
			first = r
			break
	_check("real_affixed_drop", not chosen.is_empty())
	if chosen.is_empty():
		return
	var again := _real_run(int(chosen[0]), int(chosen[1]), master)
	_check("real_same_root_same", again.drops == first.drops and again.gear == first.gear, [first, again])
	var u1 := _real_run(int(chosen[0]), int(chosen[1]), "")
	var u2 := _real_run(int(chosen[0]), int(chosen[1]), "")
	_check("real_root_fresh_each_load", str(u1.master) != str(u2.master), [u1.master, u2.master])
	print("INFO real_unpinned_drops_equal=", u1.gear == u2.gear, " ", JSON.stringify([u1.gear, u2.gear]))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114)
	XSave.dir_override = "user://test_xiyou_tianqi_affix_seed"
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	XConfig._loaded_path = "<unloaded>"
	_direct()
	_battle()
	_real_battle()
	XTianqiAffixRoll.SEED_FROM_SAVE = true
	XSave.remove(SLOT)
	XSave.dir_override = ""
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
