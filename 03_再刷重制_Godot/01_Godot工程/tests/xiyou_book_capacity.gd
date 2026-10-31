extends Node
## Native menu fixture; mismatch-selected cases also exercise the effect API explicitly.
var checks := 0
var failures: Array = []
var s: XState
var page: XItemScene
class EventHost:
	extends Node
	func toast(text: String) -> void:
		XToast.show_text(text)

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 15:
			print("FAIL ",tag," ",JSON.stringify(detail).left(1500))

func compare(tag: String, got, want) -> void:
	if want is Array:
		check(tag+".size",got is Array and got.size() == want.size(),[got,want])
		if got is Array:
			for i in mini(got.size(),want.size()):
				compare(tag+".%d" % i,got[i],want[i])
	elif want is Dictionary:
		for key in want:
			compare(tag+"."+key,got.get(key),want[key])
	else:
		check(tag,got == want,[got,want])

# 原版探针直接走 Scene_ItemBase（没有 Scene_Item.useItem 的道具续用包装），所以不比物品页的结果提示（见 xiyou_item_bag）
func snapshot(a: XActor, item: int) -> Dictionary:
	var messages := XToast.shown.filter(func(t): return not XItemBagReturn.is_result_text(str(t)))
	return {"skills":a.skill_ids.duplicate(),"passives":XPassiveBooks.learned(a),"book":s.item_count(item),"reserved":s.peek_common_event(),"wentMap":page.to_map,"messages":messages}

func run_case(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	s = XState.new_game_blank()
	var aid := int(spec.get("actor",2))
	s.party.assign([aid])
	s.battle_slots = [aid,0,0,0,0]
	var a := s.actor(aid)
	s.set_variable(9,spec.limit)
	for id in spec.pre:
		a.learn_skill(int(id))
	var selected := s.actor(int(spec.get("selected",aid)))
	for id in spec.get("selectedPre",[]):
		selected.learn_skill(int(id))
	s.item_target_actor_id = selected.actor_id
	var sequence: Array = spec.get("sequence",[]).duplicate()
	if sequence.is_empty():
		for i in int(spec.get("times",1)):
			sequence.append(spec.item)
	for id in sequence:
		if not spec.get("missing",false):
			s.gain_item(int(id),3)
	if spec.has("reserved"):
		s.reserve_common_event(int(spec.reserved))
	XToast.shown.clear()
	page = XItemScene.new()
	add_child(page)
	compare(c.id+".before",snapshot(a,int(spec.item)),c.observed.before)
	for index in sequence.size():
		var item := int(sequence[index])
		var row: Dictionary = c.observed.rows[index]
		page._item = XDB.rec("Items",item)
		page._actor = 0
		var allowed := s.item_count(item) > 0 and page._effective(a)
		compare(c.id+".allowed",allowed,row.allowed)
		compare(c.id+".pre",snapshot(a,item),row.pre)
		if spec.get("direct",false):
			a.learn_skill(int(page._item.effects[0].dataId))
		elif spec.has("selected") and allowed:
			# Explicitly sample stale selection separately from ordinary UI, as in native fixture.
			var ctx := XItemBagReturn.begin(s,page._item,0,0)
			s.gain_item(item,-1)
			var logic := XBattleLogic.new()
			logic.state = s
			logic._effect(a,a,page._item.effects[0],{"skill":page._item})
			page._after_use(ctx)
		elif not spec.get("cancel",false):
			page._use()
		compare(c.id+".after-effect",snapshot(a,item),row.after)
		if row.event != null:
			check(c.id+".event-reserved",s.peek_common_event() == 1317)
			var ce := XDB.rec("CommonEvents",s.peek_common_event())
			var host := EventHost.new()
			add_child(host)
			var interp := MVInterpreter.new(host,4,0,ce.list)
			s.clear_common_event()
			await interp.run()
			check(c.id+".event-translated",interp.skipped.is_empty(),interp.skipped)
			compare(c.id+".event",snapshot(a,item),row.event.after)
			host.queue_free()
	compare(c.id+".after",snapshot(a,int(sequence[-1])),c.observed.after)
	compare(c.id+".selected",XPassiveBooks.learned(selected),c.observed.selectedPassives)
	page.queue_free()
	await get_tree().process_frame

# Continuation is runtime context (XItemBagReturn): only after its own event started, same map, nothing else queued.
func return_context_guards() -> void:
	var item := XDB.rec("Items",1461)
	for mode in ["ok","overwritten","pending","map","state","scene"]:
		s = XState.new_game_blank()
		s.map_id = 5
		s.item_target_actor_id = 2
		s.set_variable(9,0)
		var ctx := XItemBagReturn.begin(s,item,0,2)
		check("return."+mode+".rejected",XPassiveBooks.refund_if_full(s,6301,item))
		XItemBagReturn.hold(s,ctx)
		check("return."+mode+".captured",s.has_meta(XItemBagReturn.META))
		s.clear_common_event()
		var consumed := 1317
		match mode:
			"overwritten": consumed = 1316
			"pending": s.reserve_common_event(1316)
			"map": s.map_id = 6
			"state": XState.new_game_blank()
		XItemBagReturn.event_started(s,consumed)
		if mode == "scene":
			XItemBagReturn.scene_opened(s)
		var target := XState.current if mode == "state" else s
		var saved := XItemBagReturn.take(target,false)
		check("return."+mode+".scope",not saved.is_empty() if mode == "ok" else saved.is_empty(),saved)
		if mode == "ok":
			check("return.ok.message",saved.message == "事件已执行："+str(item.name)+"（未检测到可确认的变化）",saved.message)
		check("return."+mode+".one-shot",XItemBagReturn.take(target,false).is_empty())
		# 另有预约时是等，不是放弃：那条跑完再回
		if mode == "pending":
			s.clear_common_event()
			check("return.pending.after-queue",not XItemBagReturn.take(s,false).is_empty())

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/book_capacity_oracle.json"))
	check("source",f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete",f.cases.size() == 18)
	var ids := {}
	for c in f.cases:
		check(c.id+".unique",not ids.has(c.id))
		ids[c.id] = true
		check(c.id+".native",c.errors.is_empty())
		await run_case(c)
	return_context_guards()
	for player in XSound._players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	await get_tree().create_timer(0.5,true,false,true).timeout
	print("TEST_RESULT="+JSON.stringify({"passed":checks-failures.size(),"total":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
