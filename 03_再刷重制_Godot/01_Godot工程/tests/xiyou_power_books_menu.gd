extends "res://tests/xiyou_power_books.gd"
## Six native menu routes plus the real item-scene learning entry, inventory and modal input.
var out_dir := ""
var ui_fixture: Dictionary

func frames(n := 2) -> void:
	for i in n: await get_tree().process_frame

func menu_state(empty := false) -> XState:
	var state := XState.new_game_blank()
	state.set_switch(2494,true)
	state.set_variable(9,999)
	state.party.assign([1,106,2])
	state.battle_slots = [1,106,2,0,0]
	if not empty:
		state.actor(1).learn_skill(7238)
		state.actor(2).learn_skill(7240)
	state.gain_item(3044,1)
	return state

func menu_snapshot(state: XState) -> Dictionary:
	return {"tokens":state.item_count(3044),"books":[1654,1656,1674,1683,1718].map(func(id): return state.item_count(id)),
		"members":state.members().map(func(a): return {"actor":a.actor_id,"powers":XPowerBooks.learned(a)})}

func open_item(state: XState, id: int) -> XItemScene:
	var page := XItemScene.new()
	add_child(page)
	page._item = XDB.rec("Items",id)
	page._index = maxi(0,page.entries().find_custom(func(r): return int(r.rec.id) == id))
	page._mode = "action"
	page._make_actions()
	page._act = 0
	return page

func menu_case(c: Dictionary) -> void:
	var state := menu_state(bool(c.setup.get("empty",false)))
	var o: Dictionary = c.observed
	compare(c.id+".before",menu_snapshot(state),o.before)
	var page := open_item(state,3044)
	page._ok()
	check(c.id+".opened",page.power_page != null)
	var flow := page.power_page
	if flow == null:
		page.queue_free()
		return
	var log_ref: Array = flow.log
	compare(c.id+".state0",menu_snapshot(state),o.states[0])
	# An input delivered to the parent must leave the modal subpage intact.
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	page._unhandled_input(ev)
	page.open_search()
	check(c.id+".modal",page.power_page == flow and flow.choice.visible and page.search_panel == null and not page.help_card.visible)
	var disabled := flow.choice.rows.find_custom(func(r): return r.get("enabled",true) == false)
	if disabled >= 0:
		flow.choice.index = disabled
		flow.choice.ok()
		check(c.id+".disabled",flow.log.size() == 1 and state.item_count(3044) == 1)
		flow.choice.index = 0
	for i in c.setup.steps.size():
		var step = c.setup.steps[i]
		if step is String and step == "lose-token":
			state.gain_item(3044,-1)
		elif step is String:
			flow.choice.cancel()
		else:
			flow.choice.index = int(step)
			flow.choice.ok()
		compare(c.id+".state%d" % (i+1),menu_snapshot(state),o.states[i+1])
	compare(c.id+".pages",log_ref,o.pages)
	compare(c.id+".after",menu_snapshot(state),o.after)
	check(c.id+".closed",page.power_page == null and page._mode == "list" and not page.to_map)
	page.queue_free()
	await frames()

func learning_items() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/power_books_oracle.json"))
	for c in fixture.cases:
		var a := fresh(int(c.setup.actor))
		var state := s
		for id in [1654,1656,1674,1683,1718]: state.gain_item(id,20)
		var page := open_item(state,1654)
		for row in c.observed.rows:
			var item := int(row.item)
			page._item = XDB.rec("Items",item)
			page._mode = "actor"
			page._actor = 0
			compare(c.id+".item.effective",page._effective(a),row.allowed)
			var count := state.item_count(item)
			var toast := XToast.shown.size()
			page._use()
			check(c.id+".item.count",state.item_count(item) == count - (1 if row.allowed else 0))
			compare(c.id+".item.skills",a.skill_ids,row.learned.skills)
			if not row.allowed:
				check(c.id+".item.reason",XToast.shown.size() == toast+1 and XToast.shown[-1] == row.reason)
			# Native onActorOk refuses a repeated learned power without consuming another book.
			if row.allowed:
				var learned_count := state.item_count(item)
				page._use()
				check(c.id+".item.repeat",state.item_count(item) == learned_count and XToast.shown[-1] == row.repeatReason)
			if row.ordinary != null:
				state.gain_item(3044,1)
				XPowerBooks.forget_paid(state,a,int(row.skill))
		page.queue_free()
		await frames()

func readout(page: XItemScene) -> Dictionary:
	var ch := page.power_page.choice
	return {"rect":[ch.win.position.x,ch.win.position.y,ch.win.size.x,ch.win.size.y],"padding":XMVWindow.PADDING,"lineHeight":XChoiceWindow.LH,
		"infoHeight":ch.info_height(),"pageRows":ch.page_rows(),"info":ch.info,"rows":ch.rows.map(func(r): return {"label":str(r.label),"enabled":r.get("enabled",true) != false}),
		"tokens":XState.current.item_count(3044),"powers":XState.current.members().map(func(a): return {"actor":a.actor_id,"powers":XPowerBooks.learned(a)})}

func geometry() -> void:
	var state := menu_state()
	var page := open_item(state,3044)
	page._ok()
	for name in ["power_0_actors","power_1_skills","power_2_confirm","power_3_result"]:
		if name != "power_0_actors":
			page.power_page.choice.index = 0
			page.power_page.choice.ok()
		var data := readout(page)
		var want: Dictionary = ui_fixture.pages[name].duplicate(true)
		want.erase("texts")
		want.erase("errors")
		compare(name,data,want)
		if out_dir != "":
			FileAccess.open(out_dir.path_join(name+".json"),FileAccess.WRITE).store_string(JSON.stringify(data," "))
			if DisplayServer.get_name() != "headless":
				await frames(3)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir.path_join(name+".png"))
	page.queue_free()
	await frames()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
	if out_dir != "":
		XConfig.screenshot_mode = true
		DirAccess.make_dir_recursive_absolute(out_dir)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/power_books_menu_oracle.json"))
	ui_fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/power_books_ui_oracle.json"))
	check("source",d.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("fixture.complete",d.cases.size() == 6)
	for c in d.cases:
		check(c.id+".native",c.errors.is_empty())
		if c.errors.is_empty(): await menu_case(c)
	await learning_items()
	await geometry()
	for player in XSound._players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	await get_tree().create_timer(0.5,true,false,true).timeout
	print("TEST_RESULT="+JSON.stringify({"passed":checks-failures.size(),"total":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
