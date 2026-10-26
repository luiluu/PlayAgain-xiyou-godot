extends "res://tests/xiyou_book_capacity.gd"
## Real map -> main menu -> item list -> actor -> shared reservation -> real map interpreter.
class PaintCapture extends XMVCanvas:
	var texts: Array = []
	func _draw() -> void:
		texts.clear()
		super._draw()
	func text(value: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
		texts.append([value,x,y,max_w,align,size,"#"+color.to_html(false)])
		super.text(value,x,y,max_w,align,color,size,lh,alpha,zoom,pivot,outline)

class MapCapture extends XMapScene:
	var event_trace: Array = []
	func run_reserved_common_event(owner: XState) -> void:
		event_trace.append({"phase":"before","event":owner.peek_common_event(),"busy":busy,"menuOpen":_menu_open,"saved":owner.get_meta("capacity_bag_return",{}).duplicate(true)})
		await super.run_reserved_common_event(owner)
		event_trace.append({"phase":"after","event":owner.peek_common_event(),"busy":busy,"menuOpen":_menu_open,"saved":owner.get_meta("capacity_bag_return",{}).duplicate(true)})
	func open_menu(resume_items: Dictionary = {}) -> void:
		event_trace.append({"phase":"open","resume":resume_items.duplicate(true),"busy":busy,"menuOpen":_menu_open})
		await super.open_menu(resume_items)

var out_dir := ""
var native: Dictionary
var map: MapCapture

func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String, data: Dictionary) -> void:
	if out_dir.is_empty():
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(name+".png"))
	FileAccess.open(out_dir.path_join(name+".json"),FileAccess.WRITE).store_string(JSON.stringify(data," "))

func state_read(scene: String) -> Dictionary:
	return {"scene":scene,"map":s.map_id,"position":[s.x,s.y,s.direction],"book":s.item_count(1461),"skills":s.actor(2).skill_ids.duplicate(),"selected":s.item_target_actor_id,"reserved":s.peek_common_event()}

func help_read(card: XHelpCard) -> Dictionary:
	var fonts: Array = []
	for line in card._lines:
		for glyph in line.glyphs:
			if not fonts.has(glyph.size): fonts.append(glyph.size)
	return {"rect":[card.global_position.x,card.global_position.y,card.size.x,card.size.y],
		"padding":XHelpCard.PAD,"rows":card.rows.duplicate(true),"quality":card.quality,
		"fontSizes":fonts,"visible":card.visible,"extras":card.extras.map(func(c): return help_read(c))}

# CoreText保留分数字宽，Godot同字体取整；仅绘字x/y/宽允许不足1px差。
func compare_actor_texts(got: Array, want: Array) -> void:
	check("actor.texts.size",got.size() == want.size())
	for i in mini(got.size(),want.size()):
		check("actor.texts.%d.size" % i,got[i].size() == want[i].size())
		for j in mini(got[i].size(),want[i].size()):
			if j in [1,2,3]:
				check("actor.texts.%d.%d" % [i,j],absf(float(got[i][j])-float(want[i][j])) < 1.0,[got[i][j],want[i][j]])
			else:
				compare("actor.texts.%d.%d" % [i,j],got[i][j],want[i][j])

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
	native = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/book_capacity_ui_oracle.json"))
	check("source",native.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	s = XState.new_game_blank()
	s.party.assign([2])
	s.battle_slots = [2,0,0,0,0]
	s.map_id = 5
	s.x = 10
	s.y = 10
	s.direction = 2
	s.set_variable(9,1)
	s.actor(2).learn_skill(6301)
	s.gain_item(1461,3)
	# Both sides suppress unrelated guide milestones; no rule, reservation or CE handler is replaced.
	var segment := XGuide.segment_of(XZhenqi.progress_floor(s))
	if not segment.is_empty():
		XGuide.seen(s,"seg:"+str(segment.key),true)
	XToast.shown.clear()
	map = MapCapture.new()
	add_child(map)
	for i in 600:
		if map.player != null and map.map_id == 5 and not map.busy:
			break
		await frames(1)
	check("map.ready",map.player != null and map.map_id == 5 and not map.busy)
	await frames(4)
	map.open_menu()
	var menus: Array = []
	for i in 600:
		menus = map.ui.get_children().filter(func(n): return n is XMenu)
		if not menus.is_empty(): break
		await frames(1)
	check("menu.open",menus.size() == 1)
	if menus.is_empty():
		return finish()
	var menu: XMenu = menus[0]
	menu._cmd_index = 0
	menu._ok()
	await frames(3)
	var pages := menu.get_children().filter(func(n): return n is XItemScene)
	check("item.open",pages.size() == 1)
	if pages.is_empty():
		return finish()
	page = pages[0]
	page._cat = 0
	page._mode = "category"
	page._ok()
	page._index = page.entries().find_custom(func(e): return int(e.rec.id) == 1461)
	check("item.found",page._index >= 0)
	page._refresh()
	var initial_extras: Array = help_read(page.help_card).extras.map(func(c): return c.rows)
	page._ok()  # Real list entry marks item seen.
	page._ok()  # Real action entry opens actor selector.
	check("item.actor",page._mode == "actor" and page.actor_win.visible)
	var capture: PaintCapture
	if DisplayServer.get_name() != "headless":
		var old := page.actor_win.canvas
		capture = PaintCapture.new()
		capture.painter = old.painter
		capture.blink = old.blink
		page.actor_win.remove_child(old)
		old.queue_free()
		page.actor_win.canvas = capture
		page.actor_win.add_child(capture)
		page.actor_win._layout()
	await frames(4)
	var actor_read := state_read("Scene_Item")
	actor_read.actor = {"rect":[page.actor_win.position.x,page.actor_win.position.y,page.actor_win.size.x,page.actor_win.size.y],"padding":XMVWindow.PADDING,"lineHeight":XItemScene.LH,"itemHeight":XItemScene.ACTOR_ROW_H}
	actor_read.help = help_read(page.help_card)
	var actor_expected: Dictionary = native.pages.capacity_0_actor.duplicate(true)
	actor_expected.erase("errors")
	actor_expected.erase("toast")
	actor_expected.erase("notices")
	actor_expected.erase("trace")
	actor_expected.erase("help")
	actor_expected.actor.erase("texts")
	compare("actor",actor_read,actor_expected)
	if capture != null:
		actor_read.actor.texts = capture.texts.duplicate(true)
		compare_actor_texts(actor_read.actor.texts.filter(func(t): return t[0] != ""),native.pages.capacity_0_actor.actor.texts.filter(func(t): return t[0] != ""))
	await shot("capacity_0_actor",actor_read)
	page._actor = 0
	page._ok()
	var returned: XItemScene
	for i in 600:
		menus = map.ui.get_children().filter(func(n): return n is XMenu and not n.is_queued_for_deletion())
		if menus.size() == 1:
			var children: Array = menus[0].get_children().filter(func(n): return n is XItemScene and not n.is_queued_for_deletion())
			if children.size() == 1 and children[0]._mode == "list":
				returned = children[0]
				break
		await frames(1)
	var transition := {"trace":map.event_trace,"menuOpen":map._menu_open,"busy":map.busy,"reserved":s.peek_common_event(),"stateCurrent":s == XState.current,"map":s.map_id,"saved":s.get_meta("capacity_bag_return",{}),"menus":menus.map(func(m): return {"mode":m._mode,"children":m.get_children().map(func(c): return c.get_class())})}
	check("map.menu-restored",map._menu_open and returned != null,transition)
	if returned == null:
		await shot("capacity_1_incomplete",transition)
	check("map.event-consumed",s.peek_common_event() == 0 and not map.busy and map.skipped_log.is_empty(),map.skipped_log)
	check("map.real-toast",map.toasts == [native.pages.capacity_1_limit.notices[0].message.text],map.toasts)
	compare("bag.notices",XToast.shown,native.pages.capacity_1_limit.notices.map(func(n): return n.message.text))
	if returned != null:
		check("bag.selection",returned._cat == 0 and int(returned._current().id) == 1461)
	var result := state_read("Scene_Item")
	result.transition = transition
	var expected: Dictionary = native.pages.capacity_1_limit.duplicate(true)
	for key in ["errors","actor","toast","notices","trace","help"]:
		expected.erase(key)
	compare("result",result,expected)
	if returned != null:
		result.help = help_read(returned.help_card)
		check("help.native-present",native.pages.capacity_1_limit.get("help") is Dictionary)
		if native.pages.capacity_1_limit.get("help") is Dictionary:
			compare("help.rows",result.help.rows,native.pages.capacity_1_limit.help.rows)
		check("help.result-visible",result.help.visible and result.help.quality == 0)
		check("help.extras-retained",not initial_extras.is_empty() and result.help.extras.map(func(c): return c.rows) == initial_extras)
		check("help.minimum-readable",result.help.fontSizes.all(func(n): return n >= 16))
	var layer := get_tree().root.get_node_or_null("XToast") as XToast
	check("toast.exists",layer != null and layer.stack.get_child_count() == 2)
	if layer != null and layer.stack.get_child_count() == 2:
		for i in 120:
			if layer.stack.get_children().all(func(n): return n.modulate.a >= 0.999): break
			await get_tree().create_timer(0.02,true,false,true).timeout
		result.notices = []
		for index in 2:
			var slot := layer.stack.get_child(index) as Control
			var box := slot.get_child(0) as PanelContainer
			var label := box.get_child(0) as Label
			var style := box.get_theme_stylebox("panel") as StyleBoxFlat
			var entry := {"boxRect":[box.global_position.x,box.global_position.y,box.size.x,box.size.y],"textRect":[label.global_position.x,label.global_position.y,label.size.x,label.size.y],"fontSize":label.get_theme_font_size("font_size"),"color":"#"+label.get_theme_color("font_color").to_html(false),"background":style.bg_color.to_html(),"padding":style.content_margin_left,"text":label.text,"opacity":slot.modulate.a,"fontHeight":label.get_theme_font("font").get_height(18),"fontAscent":label.get_theme_font("font").get_ascent(18),"fontDescent":label.get_theme_font("font").get_descent(18),"lineSpacing":label.get_theme_constant("line_spacing"),"lineCount":label.get_line_count(),"expectedTextSize":XUI.font().get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,240,18)}
			result.notices.append(entry)
			var want: Dictionary = native.pages.capacity_1_limit.notices[index]
			compare("toast.%d.boxRect" % index,entry.boxRect,want.box.rect)
			compare("toast.%d.textPosition" % index,entry.textRect.slice(0,2),want.message.rect.slice(0,2))
			compare("toast.%d.textHeight" % index,entry.textRect[3],want.message.rect[3])
			compare("toast.%d.fontSize" % index,entry.fontSize,float(str(want.box.fontSize).trim_suffix("px")))
			compare("toast.%d.text" % index,entry.text,want.message.text)
			compare("toast.%d.padding" % index,entry.padding,float(str(want.box.padding).trim_suffix("px")))
			check("toast.%d.color" % index,label.get_theme_color("font_color") == Color.WHITE and style.bg_color == Color(0,0,0,0.7))
		await shot("capacity_1_limit",result)
	if returned != null:
		# Restored list is interactive; cancel must return to the ordinary main menu.
		returned._cancel()
		check("bag.cancel-to-category",returned._mode == "category")
		returned._cancel()
		await frames(2)
		check("bag.cancel-to-main-menu",menus[0]._mode == "command" and map._menu_open)
	for player in [map.bgm,map.bgs,map.me,map.se]:
		player.stop()
		player.stream = null
	map.queue_free()
	await frames(2)
	finish()

func finish() -> void:
	for player in XSound._players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	await get_tree().create_timer(0.5,true,false,true).timeout
	print("TEST_RESULT="+JSON.stringify({"passed":checks-failures.size(),"total":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
