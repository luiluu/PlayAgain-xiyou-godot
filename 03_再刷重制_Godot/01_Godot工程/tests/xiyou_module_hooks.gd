extends Node
## Production cat-sword handlers against frozen native observations, plus the
## default host bridge when the separately owned character base is installed.
const ORACLE := "res://modes/xiyou/generated/oracle/module_hooks.json"
var total := 0
var failures := []

class ProbeActor extends XActor:
	var fixture := {}
	func param(i: int) -> float: return [1000000.0, 1000.0, 321.0, 456.0, 210.0, 789.0, 100.0, 100.0][i]
	func trait_objects() -> Array: return [{"note":"<SelfPhysRate: 2><SelfElemRate: 3>"}] if fixture.get("selfRates",false) else []
	func skills() -> Array: return []
	func passive_cache() -> Dictionary: return {"harmRe": {1: 11.0, 8: 22.0}}
	func passive_values(_tag: String) -> Array: return []
	func attack_elements() -> Array: return [1]

class CatBaseFixture extends RefCounted:
	static func advanced(a: XActor) -> bool: return a.level>=35

class ViewActor extends ProbeActor:
	var view: Array = []
	func stat_equips() -> Array: return view

class ProbeEnemy extends XEnemy:
	var fixture := {}
	func sparam(i: int) -> float: return float(fixture.get("pdr",1)) if i==6 else float(fixture.get("mdr",1)) if i==7 else 1.0
	func param(i: int) -> float: return [1000000.0, 1000.0, 321.0, 456.0, 210.0, 789.0, 100.0, 100.0][i]
	func trait_objects() -> Array: return []
	func skills() -> Array: return []
	func passive_cache() -> Dictionary: return {"harmRe": {1: 11.0, 8: 22.0}}
	func element_rate(e: int) -> float: return -0.5 if fixture.get("absorb", false) and e == 8 else 0.0 if fixture.get("immune", false) else float(fixture.get("resistance",1))

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if not ok:
		failures.append(label)
		if failures.size() < 15: print("FAIL ", label, " ", JSON.stringify(detail))

func same(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) <= maxf(0.000001,absf(float(b))*0.000000000001)
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	return a == b

func op(field: String, value: float, element := -1, operation := "add") -> Dictionary:
	var result := {"op": operation, "field": field, "value": value}
	if element >= 0: result.element = element
	return result

func cat_facts(setup: Dictionary) -> Dictionary:
	return {"enabled": true, "subjectSword": int(setup.actor)==178 and not setup.has("target") and setup.get("sword",false),
		"targetSword": int(setup.get("target",0))==178 and setup.get("sword",false), "heart": setup.get("heart",false),
		"advanced": setup.get("advanced",false), "targetSpeed": float(setup.get("agi",100)), "round": int(setup.get("round",1))}

func frame_probe(context: Dictionary,_frame: Dictionary) -> Dictionary:
	var ops: Array = context.facts.fixture.patches.duplicate(true)
	for operation in ops:
		if operation.has("element"): operation.element=int(operation.element)
		if operation.field=="elements": operation.value=operation.value.map(func(e):return int(e))
	return {"ops":ops}

func descriptor(id: String, order: int, handler: Callable, writes: Array) -> Dictionary:
	return {"id":id,"version":"test-1","capabilities":["test."+id],"contexts":XModuleRegistry.CONTEXTS.duplicate(),
		"hooks":[{"point":"damage.before","order":order,"reads":["facts"],"writes":writes,"handler":handler}]}

func cat_descriptor() -> Dictionary:
	return XCatDamageHooks.descriptor()

func fixture_pair(setup: Dictionary) -> Array:
	var a := ProbeActor.new();a.actor_id=int(setup.actor);a.fixture=setup if not setup.has("target") else {}
	var b: XBattler
	if setup.has("target"):
		b=ProbeActor.new();b.actor_id=int(setup.target)
	else:
		b=ProbeEnemy.new();b.enemy_id=1999 if setup.get("dragon",false) else 1;b.fixture=setup
	for member in [a,b]:
		member.hp=999999;member.mp=1000;member.tp=33
	b.guarding=setup.get("guard",false)
	return [a,b]

func run_native(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var o: Dictionary = c.observed
	var pair := fixture_pair(setup)
	var a: XBattler=pair[0];var b: XBattler=pair[1]
	var item: Dictionary = o.item.duplicate(true)
	for key in ["id","hitType","stypeId"]: item[key]=int(item[key])
	item.damage.type=int(item.damage.type);item.damage.elementId=int(item.damage.elementId)
	var entries := [XModuleRegistry.orb_descriptor(),cat_descriptor()]
	if setup.has("patches"): entries.append(descriptor("frame-probe",100,frame_probe,XModuleRegistry.SCALARS+XModuleRegistry.MAPS+XModuleRegistry.OTHER))
	var registry := XModuleRegistry.compile(entries)
	item.damage.formulaProgram=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/formula_effect_programs.json"))["runtime.constant1000000"].program
	item.damage.formulaProgram.steps[0].value.value=123457.0
	var before := JSON.stringify([a.hp,a.mp,a.tp,b.hp,b.mp,b.tp,a.passive_cache(),b.passive_cache(),a.effect_snapshot,b.effect_snapshot])
	var live: bool = setup.get("preview",true) == false
	var random := XRandomStream.scripted([{"kind":"uint32","value":2147483648},{"kind":"uint32","value":2147483648}])
	var options := {"critical":setup.get("critical",false),"rawValue":-123457.0 if setup.get("healing",false) else 123457.0,
		"variance":live,"moduleRegistry":registry,"moduleFacts":{"fixture":setup,"cat":cat_facts(setup)},"operationId":c.id}
	if live: options.random=random
	var result := XDamage.calculate(item,a,b,options)
	check(c.id+".available",result.get("available",true),result)
	if not result.get("available",true): return
	var value := float(result.value) if live else XDamage.finish(result,item,a,b)
	check(c.id+".value",same(value,o.value),[value,o.value])
	if o.breakdown.has("rows") and not o.breakdown.rows.is_empty():
		for key in ["element","bonus","defense","matchup","resistance","incoming","terminal","growth","critical","independent","guard","fixedMitigation"]:
			check(c.id+".row."+key,same(result.breakdown.row[key],o.breakdown.rows[0][key]),[result.breakdown.row[key],o.breakdown.rows[0][key]])
	var order := [["cat-sword",18],["cat-sword",19],["orb-sets",39]]
	if setup.has("patches"): order.append(["frame-probe",100])
	check(c.id+".trace_order",result.moduleTrace.map(func(t):return [t.module,t.order])==order,result.moduleTrace)
	var replay_frame := initial_frame()
	var context := {"item":item,"subject":XDamage._module_snapshot(a),"target":XDamage._module_snapshot(b),"options":{},"facts":{"fixture":setup,"orbMultiplier":1.0,"cat":cat_facts(setup)},"operationId":c.id}
	var dispatch := registry.dispatch("damage.before",context,replay_frame)
	for key in o.frame:
		if dispatch.frame.has(key):
			check(c.id+".native_frame."+key,same(dispatch.frame[key],o.frame[key]),[dispatch.frame[key],o.frame[key]])
	check(c.id+".isolated",before==JSON.stringify([a.hp,a.mp,a.tp,b.hp,b.mp,b.tp,a.passive_cache(),b.passive_cache(),a.effect_snapshot,b.effect_snapshot]))
	check(c.id+".native_isolated",o.cachesUnchanged and o.frameRestored and same(o.resourcesBefore,o.resourcesAfter))
	check(c.id+".random",random.error.is_empty() and random.draws==int(o.draws),[random.draws,o.draws,random.error])
	# Repeated targets/hits and explicit replay never reuse a prior overlay.
	if live: options.random=XRandomStream.scripted([{"kind":"uint32","value":2147483648},{"kind":"uint32","value":2147483648}])
	check(c.id+".replay",same(result,XDamage.calculate(item,a,b,options)))
	# Even an accidentally supplied live stream must remain untouched when the
	# caller explicitly requests a preview; the handler gets no RNG capability.
	var preview_options := options.duplicate()
	var untouched := XRandomStream.scripted([])
	preview_options.preview=true;preview_options.variance=true;preview_options.random=untouched
	var preview_result := XDamage.calculate(item,a,b,preview_options)
	check(c.id+".explicit_preview_rng",untouched.draws==0 and untouched.error.is_empty())
	check(c.id+".explicit_preview_value",same(preview_result.value,result.value))

func initial_frame() -> Dictionary:
	var frame := {"mode":"physical","kind":"normal","elements":null,"noElement":false,"categoryMax":false}
	for field in XModuleRegistry.SCALARS:
		frame[field] = 0.0 if field in ["flatSkill","normalAdd","criticalAdd","finalAdd","physicalIncomingPierce","magicalIncomingPierce","resistancePierce"] else 1.0
	for field in XModuleRegistry.MAPS: frame[field]={}
	return frame

func noop(_context: Dictionary,_frame: Dictionary) -> Dictionary: return {"ops":[]}
func add_final(_context: Dictionary,_frame: Dictionary) -> Dictionary: return {"ops":[op("finalAdd",2)]}
func mult_final(_context: Dictionary,_frame: Dictionary) -> Dictionary: return {"ops":[op("finalAdd",3,-1,"mul")]}
func illegal(_context: Dictionary,_frame: Dictionary) -> Dictionary: return {"ops":[op("finalAdd",2),op("criticalAdd",8)]}
func invalid_number(_context: Dictionary,_frame: Dictionary) -> Dictionary: return {"ops":[op("finalAdd",INF)]}
func bad_result(_context: Dictionary,_frame: Dictionary): return 1
func frozen(context: Dictionary,frame: Dictionary) -> Dictionary:
	check("handler.recursive_frozen",context.is_read_only() and context.facts.is_read_only() and context.facts.nested.is_read_only() and frame.is_read_only() and frame.elementAdd.is_read_only())
	return {"ops":[]}
func reentrant(context: Dictionary,_frame: Dictionary) -> Dictionary:
	var child := XModuleRegistry.compile([descriptor("child",0,add_final,["finalAdd"])])
	check("nested.independent",child.dispatch("damage.before",context,initial_frame()).frame.finalAdd==2)
	return {"ops":[op("finalAdd",4)]}

func registration() -> void:
	var entry := descriptor("a",0,noop,[])
	for name in ["duplicate","point","pending","capability","context","handler","arity","shape","cycle","dependency","order","write"]:
		var list := [entry.duplicate(true)]
		match name:
			"duplicate":list.append(entry.duplicate(true))
			"point":list[0].hooks[0].point="typo"
			"pending":list[0].hooks[0].point="damage.after"
			"capability":var other=descriptor("b",1,noop,[]);other.capabilities=list[0].capabilities.duplicate();list.append(other)
			"context":list[0].contexts=["rng"]
			"handler":list[0].hooks[0].handler=Callable()
			"arity":list[0].hooks[0].handler=func(_x): return {}
			"shape":list[0].hooks=[1]
			"cycle":list[0].dependsOn=["a"]
			"dependency":list[0].dependsOn=["absent"]
			"order":list[0].hooks[0].order=0.5
			"write":list[0].hooks[0].writes=["hp"]
		var r := XModuleRegistry.compile(list)
		check("registration."+name,not r.valid() and not r.diagnostics().is_empty(),r.diagnostics())
		check("invalid_manifest."+name,r.manifest() is Array)
	var ctx := {"facts":{"nested":[]},"item":{},"subject":{},"target":{},"options":{},"operationId":"test"}
	var frame := initial_frame()
	var a := descriptor("a",0,add_final,["finalAdd"]);var b := descriptor("b",0,mult_final,["finalAdd"])
	var registry := XModuleRegistry.compile([b,a])
	check("stable_tie",registry.dispatch("damage.before",ctx,frame).frame.finalAdd==6)
	check("compile_copies_input",registry.valid())
	a.hooks[0].order=100
	check("immutable_table",registry.dispatch("damage.before",ctx,frame).frame.finalAdd==6)
	var manifest := registry.manifest();manifest[0].id="changed"
	check("manifest_is_copy",registry.manifest()[0].id!="changed")
	# illegal 故意写没登记的 criticalAdd：这里关掉 push_error（否则日志里的 ERROR: 行让本场景判失败），只看诊断里点了模块和字段名
	XModuleRegistry.REPORT_UNDECLARED = false
	for handler in [illegal,invalid_number,bad_result]:
		var result := XModuleRegistry.compile([descriptor("invalid",0,handler,["finalAdd"])]).dispatch("damage.before",ctx,frame)
		check("invalid_handler."+str(handler.get_method()),not result.available and result.frame.finalAdd==0 and not result.diagnostics.is_empty(),result)
		if handler == illegal:
			check("undeclared_write_names_field",result.diagnostics==["invalid:undeclared_write:criticalAdd"],result.diagnostics)
	XModuleRegistry.REPORT_UNDECLARED = true
	check("missing_context",not registry.dispatch("damage.before",{},frame).available)
	check("missing_nested_context",not XModuleRegistry.standard().dispatch("damage.before",ctx,frame).available)
	var dependency := descriptor("dependent",-1,noop,[]);dependency.dependsOn=["b"]
	check("dependency_source_order",not XModuleRegistry.compile([b,dependency]).valid())
	check("invalid_frame",not registry.dispatch("damage.before",ctx,{}).available)
	var live_context := ctx.duplicate(true);live_context.facts.rng=XRandomStream.create("0000000000000001","rule")
	check("no_live_context",not registry.dispatch("damage.before",live_context,frame).available)
	var freeze_registry := XModuleRegistry.compile([descriptor("frozen",0,frozen,[])])
	check("readonly_handler",freeze_registry.dispatch("damage.before",ctx,frame).available)
	check("parent_nested",XModuleRegistry.compile([descriptor("parent",0,reentrant,["finalAdd"])]).dispatch("damage.before",ctx,frame).frame.finalAdd==4)
	check("caller_unchanged",frame.finalAdd==0 and not ctx.is_read_only() and not ctx.facts.nested.is_read_only())
	check("standard_valid",XModuleRegistry.standard().valid(),XModuleRegistry.standard().diagnostics())

func equipment_view() -> void:
	# Copy of the actor lane's completed frozen-native 671 case; this exercises
	# only this lane's reader, and does not import/activate XCat prematurely.
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/module_equipment_view.json"))
	check("view.same_source",reference.runtimeInputs==XDB.load_json("manifest.json").runtimeInputs)
	var actor := ViewActor.new();actor.actor_id=178
	var raw := XDB.rec("Weapons",671).duplicate(true)
	var view := raw.duplicate(true)
	for field in ["elementAmplify","elementAmplifyN","elementMagnify"]:
		for key in view.get("yep",{}).get(field,{}):view.yep[field][key]*=2.0
	actor.equips=[raw];actor.view=[view]
	var before := JSON.stringify(actor.equips)
	for level in reference.rows:
		var observed := (reference.elementIds as Array).map(func(e):return XDamage.element_bonus(actor,int(e)))
		check("view.native_671.level"+level,same(observed,reference.rows[level]),[observed,reference.rows[level]])
	var legacy := ProbeActor.new();legacy.actor_id=178;legacy.equips=[raw]
	check("view.legacy_actor",same(XDamage.element_bonus(legacy,1),float(reference.rows["1"][0])/2.0))
	check("view.no_instance_write",before==JSON.stringify(actor.equips))

func production_cat() -> void:
	var a:=ProbeActor.new();a.actor_id=178;a._lv=35;a.skill_ids.assign([10441,10443,10444]);a.equips=[{"kind":"weapon","wtypeId":2}]
	var b:=ViewActor.new();b.actor_id=178;b.skill_ids.assign([10441]);b.equips=[{"kind":"weapon","wtypeId":2}]
	var provider:=CatBaseFixture.new()
	var facts:=XCatDamageHooks.capture({},a,b,{"battleRound":4},provider)
	check("cat.production_capture",facts.enabled and facts.subjectSword and facts.targetSword and facts.heart and facts.advanced and facts.targetSpeed==100 and facts.round==4,facts)
	a.equips=[{"kind":"weapon","wtypeId":3}]
	check("cat.non_sword",not XCatDamageHooks.capture({},a,b,{},provider).subjectSword)
	var context:={"item":{"id":10437},"subject":{"kind":"actor","id":178},"target":{"kind":"enemy","id":1999},"facts":{"cat":facts},"options":{},"operationId":"dragon"}
	var registry:=XModuleRegistry.compile([XCatDamageHooks.descriptor()])
	check("cat.dragon_round4_open",registry.dispatch("damage.before",context,initial_frame()).frame.flatMitigationAdd.is_empty())
	context.facts.cat.round=1
	check("cat.dragon_round1_protected",registry.dispatch("damage.before",context,initial_frame()).frame.flatMitigationAdd["1"]==1e11)
	context.facts.cat.round=null
	check("cat.dragon_missing_context",not registry.dispatch("damage.before",context,initial_frame()).available)
	var auto:=XCatDamageHooks.capture({},a,b,{})
	var base:=XCatDamageHooks.base_provider()
	check("cat.base_gate",auto.enabled==(base!=null),auto)
	if base!=null:
		a.equips=[{"kind":"weapon","wtypeId":2}]
		var live:=XCatDamageHooks.capture({},a,b,{"battleRound":9})
		check("cat.base_live_capture",live.enabled and live.subjectSword and live.targetSword and live.advanced==base.call("advanced",a),live)
		# Exercise the default registry through XDamage, without caller-provided
		# facts or a special registry, using the character lane's real base getter.
		var item:=XDB.rec("Skills",10437).duplicate(true)
		var options:={"rawValue":123457.0,"preview":true,"variance":false,"battleRound":9,"operationId":"cat-live-host"}
		var before:=JSON.stringify([a.equips,a.skill_ids,b.equips,b.skill_ids,a.hp,a.mp,a.tp,b.hp,b.mp,b.tp])
		var automatic:=XDamage.calculate(item,a,b,options)
		var explicit:=options.duplicate();explicit.moduleFacts={"cat":live}
		check("cat.default_host_available",automatic.get("available",true),automatic)
		check("cat.default_host_snapshot",same(automatic,XDamage.calculate(item,a,b,explicit)))
		check("cat.default_host_handlers",automatic.moduleTrace.map(func(t):return [t.module,t.order])==[["alienation",1],["actor-modules",3],["cat-sword",18],["cat-sword",19],["alienation",21],["orb-sets",39],["race-blessings",41]] and not automatic.moduleTrace[2].ops.is_empty() and not automatic.moduleTrace[3].ops.is_empty(),automatic.moduleTrace)
		check("cat.default_host_repeat",same(automatic,XDamage.calculate(item,a,b,options)))
		check("cat.default_host_isolated",before==JSON.stringify([a.equips,a.skill_ids,b.equips,b.skill_ids,a.hp,a.mp,a.tp,b.hp,b.mp,b.tp]))

func _ready() -> void:
	registration()
	production_cat()
	equipment_view()
	check("oracle.exists",FileAccess.file_exists(ORACLE))
	if FileAccess.file_exists(ORACLE):
		var data=JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
		check("oracle.same_source",data.sourceIdentity.runtimeInputs==XDB.load_json("manifest.json").runtimeInputs)
		check("oracle.case_count",data.cases.size()==30)
		check("oracle.native_registry",data.cases[0].observed.hooks[9].id=="cat-sword" and data.cases[0].observed.hooks[19].id=="orb-sets")
		for c in data.cases.slice(1):
			check(c.id+".native_errors",c.errors.is_empty(),c.errors)
			if c.errors.is_empty():run_native(c)
	print("TEST_RESULT="+JSON.stringify({"passed":total-failures.size(),"total":total,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
