extends Node
## 天启篇装备掷词条与深渊商人货架专项（XTianqiAffixRoll、XTianqiMerchant；词条稿 v0.3 第 3、8.2 节）。
## 一、掷词条：槽数按品质、阶按等级需求、栏位组只出对口的、每件特效最多 2 传说最多 1、同名不重复；原版随机词缀行不掷、必出行照合；
##    普通品质、法宝、坐骑不掷；原版档、开关关掉照原版；XTianqiAffixBattle 认得掷出来的词条。
## 二、深渊商人：寻宝必带一条特效、珍藏必带指定的传说词条、本体够格、扣点与次数、稀有另价、货架不可用时的原因。
## 数字避开 4。

const CONFIG := "user://xiyou_tianqi_affix_roll_config.json"
const ROUTE := 184   # 深渊:孽镜深渊（池里都是三阶以上的不朽装备）
const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(diff := "jianxian") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	return s


## 找一件：kind、品质档（0～6）、阶、栏位键
func _find(kind: String, grade: int, tier: int, slot: String) -> int:
	var table: Array = XDB.table("Weapons" if kind == "weapon" else "Armors")
	for r in table:
		if not r is Dictionary or str(r.get("name", "")) == "":
			continue
		var tpl := XGear.template(kind, int(r.id))
		if XQuality.grade(tpl) == grade and XTianqiAffixRoll.tier_of(tpl) == tier and XTianqiAffixRoll.slot_key(tpl) == slot and not XEquipment.is_exclusive(tpl):
			return int(r.id)
	return 0


func _layer_count(list: Array, layer: String) -> int:
	return list.filter(func(a): return str(T.affix(str(a.key)).get("layer", "")) == layer).size()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	_roll()
	_rows()
	_merchant()
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


# ---- 一、掷词条 ----

func _roll() -> void:
	var s := _state("lianyu")
	var wid := _find("weapon", 6, 4, "weapon")
	_check("found_weapon", wid > 0)
	var hits := 0
	var layers_ok := true
	var group_ok := true
	for i in 30:
		var it := XGear.create("weapon", wid, s)
		var list: Array = it.get("tianqi_affixes", [])
		if list.size() == 3:
			hits += 1
		var keys := list.map(func(a): return str(a.key))
		layers_ok = layers_ok and _layer_count(list, "special") <= 2 and _layer_count(list, "legendary") <= 1 and keys.size() == _unique(keys)
		for a in list:
			group_ok = group_ok and int(a.tier) == 4 and XTianqiAffixRoll.layer_candidates(it, str(T.affix(str(a.key)).layer)).has(str(a.key))
	_check("mythic_three_slots", hits == 30, hits)
	_check("layer_caps_unique", layers_ok)
	_check("slot_group", group_ok)
	var one := XGear.create("weapon", wid, s)
	_check("battle_reads", XTianqiAffixBattle.item_affixes(one).size() == 3)
	_check("desc_lines", str(one.description).split("\n").size() >= 3, one.description)
	# 全掷传说：一件只出 1 条传说，其余往下退
	var always_top := func(): return 0.999
	var list2 := XTianqiAffixRoll.roll(XGear.template("weapon", wid), "weapon", "zhengdao", always_top)
	_check("legendary_cap", _layer_count(list2, "legendary") == 1 and list2.size() == 3, list2)
	# 传说品质（三阶）出不了传说词条：全掷传说也退到别的层
	var epic4 := _find("weapon", 4, 3, "weapon")
	_check("found_legend3", epic4 > 0)
	if epic4 > 0:
		var l3 := XTianqiAffixRoll.roll(XGear.template("weapon", epic4), "weapon", "zhengdao", always_top)
		_check("epic_no_legendary", _layer_count(l3, "legendary") == 0 and l3.size() == 2, l3)
	# 普通品质不掷；一阶不出特效
	var plain_id := _find("armor", 0, 1, "head")
	if plain_id > 0:
		_check("putong_none", not XGear.create("armor", plain_id, s).has("tianqi_affixes"))
	var epic1 := _find("armor", 3, 1, "body")
	if epic1 > 0:
		var ok := true
		for i in 20:
			var e: Dictionary = XGear.create("armor", epic1, s)
			ok = ok and _layer_count(e.get("tianqi_affixes", []), "special") == 0
		_check("tier1_no_special", ok)
	# 项链：二阶起有光环几率；戒指没有光环
	var ring := _find("armor", 6, 4, "ring")
	if ring > 0:
		var no_aura := true
		for i in 20:
			no_aura = no_aura and _layer_count(XGear.create("armor", ring, s).get("tianqi_affixes", []), "aura") == 0
		_check("ring_no_aura", no_aura)
	var neck := _find("armor", 6, 4, "necklace")
	if neck > 0:
		var aura_list := XTianqiAffixRoll.roll(XGear.template("armor", neck), "necklace", "jianxian", func(): return 0.0)
		_check("necklace_aura", _layer_count(aura_list, "aura") == 1, aura_list)
	# 开关关掉、原版档：不掷
	XTianqiAffixRoll.ENABLED = false
	_check("off_none", not XGear.create("weapon", wid, s).has("tianqi_affixes"))
	XTianqiAffixRoll.ENABLED = true
	var plain := XState.new_game(3, 1, [8, 9, 10])
	XState.current = plain
	_check("plain_none", not XGear.create("weapon", wid, plain).has("tianqi_affixes"))
	XState.current = s
	# 保证带指定词条（珍藏用）
	var it2 := XGear.create("weapon", wid, s)
	_check("ensure_legendary", XTianqiAffixRoll.ensure_affix(it2, "headhunter", func(): return 0.5)
		and (it2.tianqi_affixes as Array).any(func(a): return str(a.key) == "headhunter") and _layer_count(it2.tianqi_affixes, "legendary") == 1
		and (it2.tianqi_affixes as Array).size() == 3 and str(it2.description).contains("对精英、首领、守层者伤害"))
	_check("ensure_wrong_group", not XTianqiAffixRoll.ensure_affix(it2, "bulwark", func(): return 0.5))


func _unique(keys: Array) -> int:
	var d := {}
	for k in keys:
		d[k] = true
	return d.size()


## 原版随机词缀行：天启篇不掷，必出行照合
func _rows() -> void:
	var s := _state()
	var rand_id := 0
	var sure_id := 0
	for r in XDB.table("Weapons"):
		if not r is Dictionary:
			continue
		var rows: Array = r.get("equipment", {}).get("affixes", [])
		for row in rows:
			var total := 0
			for c in row.get("choices", []):
				total += int(c.get("chance", 0))
			if total < 100 and rand_id == 0 and rows.size() == 1:
				rand_id = int(r.id)
			if total >= 100 and sure_id == 0 and rows.size() == 1:
				sure_id = int(r.id)
	XGear.roll_fn = func(): return 0.0  # 原版下每行都中
	var a := XGear.create("weapon", rand_id, s)
	var b: Dictionary = XGear.create("weapon", sure_id, s) if sure_id > 0 else {}
	var plain := XState.new_game(3, 1, [8, 9, 10])
	var c := XGear.create("weapon", rand_id, plain)
	XGear.roll_fn = Callable()
	_check("random_row_skipped", (a.affixIds as Array).is_empty() and not (c.affixIds as Array).is_empty(), [rand_id, a.affixIds, c.affixIds])
	if sure_id > 0:
		_check("sure_row_kept", not (b.affixIds as Array).is_empty(), [sure_id, b.affixIds])
	XState.current = s


# ---- 二、深渊商人 ----

func _open(s: XState, bal: int) -> String:
	s.map_id = ROUTE
	s.flags[XAbyssMerchant.RUN_FLAG] = {"sequence": 1, "claimed": true, "appeared": true, "used": 0, "seed": 12345,
		"identity": {"key": "abyss:", "kind": "深渊商人"}}
	XAbyssMerchant.ledger(s).balances["abyss:"] = bal
	return "abyss:"


func _merchant() -> void:
	var s := _state()
	var key := _open(s, 300)
	var groups := ["武器", "防具", "饰品"].filter(func(g): return not XAbyssMerchant.pool(s, g).is_empty())
	var g: String = groups[0]
	var got = XTianqiMerchant.draw(s, "treasure", g)
	_check("treasure_item", got is Dictionary and _layer_count(got.get("tianqi_affixes", []), "special") >= 1, got if got is String else got.get("tianqi_affixes"))
	_check("treasure_paid", XAbyssMerchant.balance(s, key) == 290 and int(XAbyssMerchant.run(s).used) == 1 and s.gear.has(got))
	var choices := XTianqiMerchant.collection_choices(s, g)
	_check("collection_choices", not choices.is_empty() and choices.all(func(c): return str(T.affix(str(c.key)).layer) == "legendary"), choices)
	var pick: Dictionary = choices.filter(func(c): return not c.rare)[0]
	var got2 = XTianqiMerchant.draw(s, "collection", g, str(pick.key))
	_check("collection_item", got2 is Dictionary and (got2.tianqi_affixes as Array).any(func(a): return str(a.key) == str(pick.key))
		and XTianqiAffixRoll.tier_of(got2) >= 3 and XQuality.grade(got2) >= 5)
	_check("collection_paid", XAbyssMerchant.balance(s, key) == 230)
	var rare: Array = choices.filter(func(c): return c.rare)
	if not rare.is_empty():
		_check("rare_cost", int(rare[0].cost) == 100)
	var got3 = XTianqiMerchant.draw(s, "treasure", g)
	_check("visit_limit", got3 is Dictionary and XTianqiMerchant.draw(s, "treasure", g) is String)
	# 点数不够
	var s2 := _state()
	_open(s2, 5)
	_check("poor", XTianqiMerchant.draw(s2, "treasure", g) is String and XAbyssMerchant.balance(s2, "abyss:") == 5)
	# 低阶路线：珍藏不可用
	var s3 := _state()
	_open(s3, 300)
	s3.map_id = 37
	var low := ["武器", "防具", "饰品"].filter(func(x): return not XAbyssMerchant.pool(s3, x).is_empty())
	_check("collection_unavailable", low.all(func(x): return XTianqiMerchant.collection_choices(s3, x).is_empty()))
	var rows := XMerchant29Page.tianqi_rows(s3, low[0])
	_check("rows_reason", rows.size() == 2 and not bool(rows[1].enabled) and str(rows[1].help).contains("不可用"), rows)
	# 混合路线：珍藏的本体只出三阶以上、不朽及以上
	var s4 := _state()
	_open(s4, 300)
	s4.map_id = 141
	var mixed_ok := true
	var fewer := false
	for x in ["武器", "防具", "饰品"]:
		var bs := XTianqiMerchant.bodies(s4, x, "collection")
		fewer = fewer or bs.size() < XAbyssMerchant.pool(s4, x).size()
		for d in bs:
			var tpl := XGear.template("weapon" if str(d.db) == "Weapons" else "armor", int(d.id))
			mixed_ok = mixed_ok and XTianqiAffixRoll.tier_of(tpl) >= 3 and XQuality.grade(tpl) >= 5
	_check("collection_threshold", mixed_ok and fewer)
	# 原版档／开关关掉：照原版三档
	XTianqiMerchant.ENABLED = false
	_check("off", not XTianqiMerchant.on(s))
	XTianqiMerchant.ENABLED = true
