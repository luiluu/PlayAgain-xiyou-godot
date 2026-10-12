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
		var e := XGear.create(row.kind,int(row.id))
		var tag := "%s%d_%.2f"%[row.kind,row.id,row.roll]
		check(tag+"_params",close_array(e.params,row.params),{"godot":e.params,"mv":row.params})
		check(tag+"_metadata",e.name==row.name and e.traits==row.traits and int(e.price)==int(row.price) and int(e.iconIndex)==int(row.icon) and XGear.quality(e)==int(row.quality),{"godot":e,"mv":row})
		check(tag+"_slots",int(e.upgradeSlots)==int(row.slots) and int(e.originalUpgradeSlots)==int(row.originalSlots))
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
	finish()
func finish() -> void:
	var passed := results.filter(func(r):return r.passed).size()
	print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}))
	get_tree().quit(0 if passed==results.size() else 1)
