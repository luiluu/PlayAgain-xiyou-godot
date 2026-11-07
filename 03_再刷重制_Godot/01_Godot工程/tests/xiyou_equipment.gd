extends Node
## 固定随机数与正式运行插件对照；全部使用内存装备，不读取玩家存档。
var results := []
func _ready() -> void:
	_run.call_deferred()
func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name":name,"passed":ok})
	if not ok:print("FAIL ",name," ",JSON.stringify(detail))
func close_array(a: Array,b: Array) -> bool:
	return a.size()==b.size() and range(a.size()).all(func(i):return is_equal_approx(float(a[i]),float(b[i])))
func _run() -> void:
	var ref = XDB.load_json("oracle/equipment.json")
	if not ref is Dictionary:
		check("equipment_reference_present",false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("version",ref.releaseVersion==manifest.releaseVersion)
	check("all_runtime_identity",ref.sourceIdentity.runtimeInputs==manifest.runtimeInputs)
	check("data_identity",manifest.inputs.keys().filter(func(k):return k.begins_with("data/") or k=="package.json").all(func(k):return ref.sourceIdentity.inputs.get(k)==manifest.inputs[k]))
	for rel in ref.sourceHashes:
		check("source_"+rel,ref.sourceHashes[rel]==manifest.runtimeInputs.get(rel))
	var defs: Array = XDB.table("EquipSuits")
	var fields := ["requirePieces","states","statesResist","skills","paramPlus","paramRate","xparamPlus","xparamRate","sparamPlus","sparamRate","bResultPlus","bResultRate"]
	for original in ref.suitDefinitions:
		if not original is Dictionary:continue
		for bonus in original.bonuses:
			for k in ["states","statesResist","skills"]:bonus[k]=bonus[k].filter(func(v):return v!=null)
		var mine: Dictionary = defs[int(original.id)]
		check("suit_definition_%d"%int(original.id),mine.name==original.name and mine.bonuses.size()==original.bonuses.size() and range(mine.bonuses.size()).all(func(i):return fields.all(func(k):return mine.bonuses[i][k]==original.bonuses[i][k])))
	for row in ref.gear:
		XGear.force_roll=float(row.roll)
		XGear.reset_pool()
		var e := XGear.create(row.kind,int(row.id))
		var tag := "%s%d_%.2f"%[row.kind,row.id,row.roll]
		check(tag+"_params",close_array(e.params,row.params),{"godot":e.params,"mv":row.params})
		check(tag+"_metadata",e.name==row.name and e.traits==row.traits and int(e.price)==int(row.price) and int(e.iconIndex)==int(row.icon) and XGear.quality(e)==int(row.quality),{"godot":e,"mv":row})
		check(tag+"_slots",int(e.upgradeSlots)==int(row.slots) and int(e.originalUpgradeSlots)==int(row.originalSlots))
	# 变化随机序列：名字、属性、插槽一致且取随机数的次数相同，才说明取数先后与正式版一致。
	for row in ref.get("sequenced", []):
		XGear.force_roll = -1.0
		XGear.roll_seq = range(int(row.draws)).map(func(i): return ref.sequence[i % ref.sequence.size()])
		XGear.roll_count = 0
		XGear.reset_pool()
		var e := XGear.create(row.kind, int(row.id))
		var tag := "seq_%s%d" % [row.kind, int(row.id)]
		check(tag, close_array(e.params, row.params) and e.name == row.name and e.traits == row.traits and int(e.upgradeSlots) == int(row.slots) and XGear.roll_count == int(row.draws),
			{"godot": [e.name, e.params, e.upgradeSlots, XGear.roll_count], "mv": [row.name, row.params, row.slots, row.draws]})
	XGear.roll_seq = []
	for row in ref.upgrades:
		if int(row.itemId) in [170,242]:continue # 正式版旧标签只扣费，不作为有效强化开放。
		XGear.force_roll=0.5
		var s := XState.new_game(3,1,[])
		s.gain_gear(row.kind,int(row.id),1);s.gain_item(int(row.itemId),1)
		var e: Dictionary = s.gear.back()
		XGear.force_roll=float(row.roll)
		check("upgrade_%d_allowed"%int(row.itemId),XGearUpgrade.apply(s,e,int(row.itemId)),XGearUpgrade.reason(e,XDB.rec("Items",int(row.itemId)),1))
		check("upgrade_%d_result"%int(row.itemId),close_array(e.params,row.params) and e.traits==row.traits and int(e.upgradeSlots)==int(row.slots) and int(e.boostCount)==int(row.boost) and e.get("yep",{}).get("elementAmplify",{})==row.elementAmplify,{"godot":e,"mv":row})
		check("upgrade_%d_cost"%int(row.itemId),s.item_count(int(row.itemId))==0)
	for row in ref.runewords:
		XGear.force_roll=0.5
		var e:=XGear.create(row.kind,int(row.id))
		e.upgrades=row.materials.map(func(id):return {"item":int(id),"name":"","cost":1})
		XRunewords.check(e)
		var once:=JSON.stringify(e)
		XRunewords.check(e)
		check("runeword_%d_%s"%[int(row.recipeId),row.kind],close_array(e.params,row.params) and e.traits==row.traits and e.get("yep",{}).get("elementAmplify",{})==row.elementAmplify and e.name==row.name and e.get("runewords",[])==row.runewords.map(func(v):return int(v)),{"godot":e,"mv":row})
		check("runeword_%d_once"%int(row.recipeId),once==JSON.stringify(e))
	# 两个跟到 v0.62.12 的开关关掉时回到 v0.28：专武 67 照样抽成「卍解-斩月」前缀；单颗符石的配方镶上就结算，不挂起
	XGear.EXCLUSIVE_V056 = false
	XGear.force_roll = 0.0
	XGear.reset_pool()
	var old_affix := XGear.create("weapon", 56)
	check("v028_exclusive_affix", old_affix.affixIds.size() == 1 and int(old_affix.affixIds[0].id) == 67 and str(old_affix.name).begins_with("卍解-斩月"), old_affix.affixIds)
	XGear.EXCLUSIVE_V056 = true
	XGear.reset_pool()
	check("exclusive_affix_skipped", XGear.create("weapon", 56).affixIds.is_empty())
	# v0.57 读档还原专武前缀：照 v0.28 造出旧装备（有的再强化一次），存档往返后与原版 revertExclusiveAffixes 的结果比
	var revert_rows: Array = ref.get("affixRevert", [])
	check("affix_revert_reference_present", revert_rows.size() == 3)
	for row in revert_rows:
		var tag := "affix_revert_%d_%.1f_%d" % [int(row.id), float(row.roll), int(row.upgradeItem)]
		var s := XState.new_game(3, 1, [])
		XGear.EXCLUSIVE_V056 = false
		# roll<0：同探针，前两个随机数 0（抽中第一个专武词缀）、其余 0.5（浮动为 0）
		XGear.force_roll = float(row.roll) if float(row.roll) >= 0 else -1.0
		XGear.roll_seq = [] if float(row.roll) >= 0 else [0.0, 0.0] + range(300).map(func(_i): return 0.5)
		XGear.roll_count = 0
		XGear.reset_pool()
		var g := XGear.create("weapon", int(row.id))
		XGear.roll_seq = []
		s.register_gear(g)
		s.gear.append(g)
		if int(row.upgradeItem) > 0:
			XGear.force_roll = 0.5
			s.gain_item(int(row.upgradeItem), 1)
			XGearUpgrade.apply(s, g, int(row.upgradeItem))
		var b: Dictionary = row.before
		check(tag + "_before", g.name == b.name and close_array(g.params, b.params) and g.traits == b.traits and int(g.price) == int(b.price), {"godot": [g.name, g.params, g.traits.size(), g.price], "mv": [b.name, b.params, b.traits.size(), b.price]})
		var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
		var id := str(g.instanceId)
		# 开关关着＝v0.28：读档不动
		var kept := XState.from_dict(saved.duplicate(true))
		var k: Dictionary = kept.gear.filter(func(e): return str(e.instanceId) == id)[0]
		check(tag + "_v028_kept", k.name == b.name and not k.has("_affixRevert") and XGear.last_affix_revert.items.is_empty())
		XGear.EXCLUSIVE_V056 = true
		var loaded := XState.from_dict(saved.duplicate(true))
		var e: Dictionary = loaded.gear.filter(func(x): return str(x.instanceId) == id)[0]
		var a: Dictionary = row.after
		check(tag + "_reverted", XGear.last_affix_revert.items.has(id) == bool(row.reverted) and XGear.last_affix_revert.skipped.has(id) == bool(row.skipped), XGear.last_affix_revert)
		check(tag + "_after", e.name == a.name and close_array(e.params, a.params) and e.traits == a.traits and int(e.price) == int(a.price) and str(e.description) == str(a.description) and XGear.quality(e) == int(a.quality),
			{"godot": [e.name, e.params, e.traits, e.price, e.description], "mv": [a.name, a.params, a.traits, a.price, a.description]})
		if bool(row.reverted):
			check(tag + "_backup", e.has("_affixRevert") and e._affixRevert.name == b.name and e.affixIds.is_empty() and not str(e.note).to_lower().contains("<req_actors") and int(e.get("boostCount", 0)) == int(row.before.boost))
			# 只跑一次：存档里已带备份的再读一遍不变
			var once := JSON.stringify(e)
			var again := XState.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
			var e2: Dictionary = again.gear.filter(func(x): return str(x.instanceId) == id)[0]
			check(tag + "_once", XGear.last_affix_revert.items.is_empty() and e2.name == e.name and close_array(e2.params, e.params) and e2.traits == e.traits, [once.length(), XGear.last_affix_revert])
	# 审查 53 P3-1：专武前缀＋另一个普通词缀的武器，读档只去掉专武那段，普通词缀（属性、特效、名字、affixIds）留着；
	# 回退开关 REVERT_KEEP_OTHER_AFFIXES = false 照原版整份换回底装备
	# 现有数据里没有「专武行＋普通行」同时在的武器（专武只和专武同一行），这里手拼：普通词缀取带名字、带特效的「（传家宝）」1500
	var other_id := 1500 if XGear.valid_affix("Weapons", 1500) and not str(XDB.rec("Weapons", 1500).get("name", "")).is_empty() else 0
	check("affix_revert_other_present", other_id > 0)
	if other_id > 0:
		var mixed_ids := [{"table": "Weapons", "id": 67, "kind": "prefix"}, {"table": "Weapons", "id": other_id, "kind": "suffix"}]
		var kept_ids := [{"table": "Weapons", "id": other_id, "kind": "suffix"}]
		var want := XGear.affix_template({"kind": "weapon", "base": 56, "affixIds": kept_ids})
		var plain := XGear.template("weapon", 56)
		for keep in [true, false]:
			XGear.REVERT_KEEP_OTHER_AFFIXES = keep
			var s := XState.new_game(3, 1, [])
			var g := XGear.affix_template({"kind": "weapon", "base": 56, "affixIds": mixed_ids})
			g.affixIds = mixed_ids.duplicate(true)
			s.register_gear(g)
			s.gear.append(g)
			var id := str(g.instanceId)
			var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
			var e: Dictionary = loaded.gear.filter(func(x): return str(x.instanceId) == id)[0]
			var expect_e: Dictionary = want if keep else plain
			var tag := "affix_revert_mixed_" + ("keep" if keep else "orig")
			# 原版整份换掉时名字里的后缀字留着（P3-1 说的那种），属性特效回到底装备
			var want_name := str(want.name) if keep else str(plain.name) + str(XDB.rec("Weapons", other_id).name)
			check(tag, XGear.last_affix_revert.items.has(id) and e.name == want_name and close_array(e.params, expect_e.params) and e.traits == expect_e.traits and int(e.price) == int(expect_e.price) \
					and str(e.description) == str(expect_e.description) and not str(e.note).to_lower().contains("<req_actors") and e.affixIds.size() == (1 if keep else 0) and e._affixRevert.affixIds.size() == 2,
				{"godot": [e.name, e.params, e.traits, e.price, e.affixIds], "want": [want_name, expect_e.params, expect_e.traits, expect_e.price]})
			if keep:
				var again := XState.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
				var e2: Dictionary = again.gear.filter(func(x): return str(x.instanceId) == id)[0]
				check(tag + "_once", XGear.last_affix_revert.items.is_empty() and e2.name == e.name and e2.affixIds.size() == 1)
		XGear.REVERT_KEEP_OTHER_AFFIXES = true
	var one: Dictionary = {}
	for row in ref.runewords:
		if (row.materials as Array).size() == 1:
			one = row
			break
	check("runeword_single_present", not one.is_empty())
	if not one.is_empty():
		for pending in [true, false]:
			XRunewords.PENDING_V062 = pending
			XGear.force_roll = 0.5
			var g := XGear.create(one.kind, int(one.id))
			g.upgrades = one.materials.map(func(id): return {"item": int(id), "name": "", "cost": 1})
			XRunewords.check(g)
			check("runeword_pending_%s" % pending, g.get("runewords", []).is_empty() == pending and g.has("runewordPending") == pending, [g.get("runewords"), g.get("runewordPending")])
		XRunewords.PENDING_V062 = true
	for row in ref.sets:
		var a := XActor.new().setup(1);a.change_level(30);a.equips.fill(null);a.refresh_passive()
		var before: Array = range(8).map(func(i):return a.param(i))
		var before_x: Array = range(10).map(func(i):return a.xparam(i))
		var before_s: Array = range(10).map(func(i):return a.sparam(i))
		var before_skills: Array = a.skills().map(func(v):return int(v.id))
		for id in row.armorIds:
			var e := XGear.template("armor",int(id));a.equips[int(e.etypeId)-1]=e
		a.refresh_passive()
		var tag := "set_"+str(row.armorIds)
		check(tag+"_param_delta",close_array(range(8).map(func(i):return a.param(i)-before[i]),range(8).map(func(i):return row.params[i]-row.before.params[i])))
		check(tag+"_xparam_delta",close_array(range(10).map(func(i):return a.xparam(i)-before_x[i]),range(10).map(func(i):return row.xparams[i]-row.before.xparams[i])))
		check(tag+"_sparam_delta",close_array(range(10).map(func(i):return a.sparam(i)-before_s[i]),range(10).map(func(i):return row.sparams[i]-row.before.sparams[i])))
		check(tag+"_skills",a.skills().map(func(v):return int(v.id)).filter(func(id):return not before_skills.has(id))==row.skills.filter(func(id):return not row.before.skills.has(id)).map(func(v):return int(v)))
		check(tag+"_states",XEquipSuits.ids(a,"states")==row.get("activeStates",row.states).map(func(v):return int(v)))
		check(tag+"_reward",range(3).all(func(i):return is_equal_approx(XEquipSuits.value(a,"bResult",i,false),float(row.bResult[i][0])) and is_equal_approx(XEquipSuits.value(a,"bResult",i,true),float(row.bResult[i][1]))))
		a.equips.fill(null);a.refresh_passive()
		check(tag+"_removed",XEquipSuits.active(a).is_empty() and close_array(before,range(8).map(func(i):return a.param(i))))
	var s := XState.new_game(3,1,[])
	XGear.force_roll=0.5
	s.gain_gear("weapon",56,2);s.gain_item(258,4)
	var e: Dictionary = s.gear[0];var twin: Dictionary=s.gear[1]
	check("unique_instances",e.instanceId!=twin.instanceId)
	var before := JSON.stringify(s.to_dict())
	XGearUpgrade.preview(e,XDB.rec("Items",258))
	check("upgrade_preview_no_mutation",before==JSON.stringify(s.to_dict()))
	check("reject_unowned_clone",not XGearUpgrade.apply(s,e.duplicate(true),258) and before==JSON.stringify(s.to_dict()))
	check("reject_legacy_effect",not XGearUpgrade.apply(s,e,170) and before==JSON.stringify(s.to_dict()))
	check("upgrade_atomic",XGearUpgrade.apply(s,e,258) and int(twin.boostCount)==0 and s.item_count(258)==3)
	var restored := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("save_roundtrip",JSON.parse_string(JSON.stringify(s.to_dict()))==JSON.parse_string(JSON.stringify(restored.to_dict())))
	XGear.force_roll=0.99
	check("load_no_reroll",restored.gear[0].params==e.params and restored.gear[0].affixIds==e.affixIds and JSON.parse_string(JSON.stringify(restored.gear[0].upgrades))==JSON.parse_string(JSON.stringify(e.upgrades)))
	restored.gain_gear("weapon",56,1)
	check("load_id_sequence",restored.gear.back().instanceId!=e.instanceId and restored.gear.back().instanceId!=twin.instanceId)
	var old: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()));old.version=1;old.erase("nextGearId")
	for gear in old.gear:
		for key in ["instanceId","equipment","upgradeSlots","originalUpgradeSlots","boostCount","upgrades","affixIds","baseName"]:gear.erase(key)
	var old_params: Array=old.gear[0].params.duplicate()
	var migrated := XState.from_dict(old)
	check("godot_v1_keeps_stats",migrated.gear[0].params==old_params and migrated.gear[0].has("equipment") and migrated.gear[0].has("instanceId"))
	XGear.force_roll=-1
	# 预掷随机池随存档：存档后获得的装备，读档再获得一次结果相同（Star_RomGetItems）
	var rs := XState.new_game(3,1,[])
	rs.gain_gear("weapon",56,1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(rs.to_dict()))
	rs.gain_gear("weapon",56,1)
	var first: Dictionary = rs.gear.back()
	var again := XState.from_dict(saved)
	again.gain_gear("weapon",56,1)
	var second: Dictionary = again.gear.back()
	check("rom_pool_same_after_reload",second.params==first.params and second.name==first.name and second.affixIds==first.affixIds,{"first":[first.name,first.params],"second":[second.name,second.params]})
	finish()
func finish() -> void:
	var passed := results.filter(func(r):return r.passed).size()
	print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}))
	get_tree().quit(0 if passed==results.size() else 1)
