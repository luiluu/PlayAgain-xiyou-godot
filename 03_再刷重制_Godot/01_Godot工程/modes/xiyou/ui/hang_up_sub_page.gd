class_name XHangUpSubPage
extends Control
## 挂机设置的子页（XdRs_HangUp 的 Star_Scene_* 八个 Scene_MenuBase），按正式 v0.17 运行时复现
## （参照 原版参照/claude_hu_actor_00、_counts_00、_order_00、_med_00、_hpitems_00、_sell_00）。数据与规则在 XHangUpAuto。
## - 底图同主菜单，一个 Window_Command：宽 400、高按行数（最多 12 行）fittingHeight、画面居中，不透明度 30、行高 36；
##   名字左对齐在 (6, 宽 240)，状态右对齐在 (240, 宽 120)；选人页只写名字。
## - kind：actors_count/actors_order（出战成员）→ counts（技能次数）/ order（技能顺序）；medication（自动吃药）→ hp/mp（药品开关）；sell（自动卖出）。
## - 确定都是各页自己的处理，不播确定音（原版覆盖了 processOk）；只有卖出页的七档切换播确定音。上下移动播光标音，取消播取消音。
##   技能次数页 →/← 加减（0～20 循环），顺序页 → 与确定一样把该项提前一位；没有内容的页一打开就退回（药品页另提示「没药了」）。
## - 安全出售（XSafeSell，O-293）开着时卖出页：窗宽 680、状态宽 250，末行「保留词条品质」（确定往后一档、播确定音，←/→ 前后一档、播光标音），
##   上方加两行说明窗（Window_Help(2)，(0,0,1280,100)）。

signal closed

const W := 400.0
const LH := 36.0
const MAX_ROWS := 12
const STATUS_W := 120.0
const SAFE_W := 680.0
const SAFE_STATUS_W := 250.0

var kind := ""
var actor: XActor
var index := 0
var top := 0
var win: XMVWindow
var _logic: XBattleLogic
var _skills: Array = []
var _order := {}
var _potions: Array = []
var _child: Control
var help_win: XMVWindow
## T304 卡 M：新界面开着时的版型三（XSkinSubPage）；关着为 null，旧页一行不变
var skin: XSkinSubPage
## 子页名（挂机设置那一行的名字，面包屑最后一段）
var page_name := ""
## 新版型：选人不再单独一页，左块放当前角色，Q／E 换人
var switch_actor := false
## 新版型的自动吃药（kind＝med_tabs）：0＝回生命的，1＝回魔法的
var tab := 0
var _left: Control
var _tabs: Control
const TAB_NAMES := ["生命药", "魔法药"]


func _safe() -> bool:
	return kind == "sell" and XSafeSell.ENABLED


func _w() -> float:
	return SAFE_W if _safe() else W


func _status_w() -> float:
	return SAFE_STATUS_W if _safe() else STATUS_W


func setup(k: String, a: XActor = null) -> XHangUpSubPage:
	kind = k
	actor = a
	return self


func _s() -> XState:
	return XState.current


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_logic = XBattleLogic.new()
	_logic.state = _s()
	if XHangUpOptionsScene.skin_wanted():
		_skin_kind()
	_load()
	XUI.menu_background(self)
	var n := mini(rows().size(), MAX_ROWS)
	var h := n * LH + XMVWindow.PADDING * 2
	win = XMVWindow.make(self, Rect2((1280 - _w()) / 2.0, (720 - h) / 2.0, _w(), h), XUI.MENU_WINDOW_OPACITY, _paint)
	win.canvas.blink = true
	if _safe():
		help_win = XMVWindow.make(self, Rect2(0, 0, 1280, 2 * LH + XMVWindow.PADDING * 2), XUI.MENU_WINDOW_OPACITY, _paint_help)
	if XHangUpOptionsScene.skin_wanted():
		win.hide()
		if help_win != null:
			help_win.hide()
		skin = XSkinSubPage.attach(self)
		_skin_extras()
	_refresh()
	if rows().is_empty():
		if kind in ["hp", "mp"]:
			XToast.show_text("没药了", true)
		closed.emit.call_deferred()


func _load() -> void:
	var s := _s()
	match kind:
		"counts":
			_skills = XHangUpAuto.bet_skills(_logic, actor)
			XHangUpAuto.counts(s, actor, _skills)
		"order":
			_order = XHangUpAuto.order_list(s, actor, XHangUpAuto.bet_skills(_logic, actor))
		"medication":
			XHangUpAuto.open_medication(s)
		"med_tabs":
			XHangUpAuto.open_medication(s)
			_potions = XHangUpAuto.potion_list(s, tab == 1)
			XHangUpAuto.rebuild_potions(s, tab == 1, _potions)
		"hp", "mp":
			_potions = XHangUpAuto.potion_list(s, kind == "mp")
			XHangUpAuto.rebuild_potions(s, kind == "mp", _potions)
		"sell":
			XHangUpAuto.sell_config(s)


## [名字, 状态] 各行
func rows() -> Array:
	var s := _s()
	match kind:
		"actors_count", "actors_order":
			return XHangUpAuto.actors(s).map(func(a): return [a.display_name(), ""])
		"counts":
			var n := XHangUpAuto.counts(s, actor, _skills)
			var out := []
			for i in _skills.size():
				out.append([str(_skills[i].name), str(n[i])])
			return out
		"order":
			var out := []
			for i in _order.skills.size():
				out.append([str(_order.skills[i].skill.name), str(_order.order[i])])
			return out
		"medication":
			var r := XHangUpAuto.recovery(s)
			var enter := "进入" if XUiSkin.on() else "Open"
			return [["Hp恢复开关", enter], ["Mp恢复开关", enter], ["Hp恢复比例", str(r.HpV)], ["Mp恢复比例", str(r.MpV)]]
		"med_tabs":
			var key := "MpV" if tab == 1 else "HpV"
			var out := [["Mp恢复比例" if tab == 1 else "Hp恢复比例", str(XHangUpAuto.recovery(s)[key])]]
			for e in _potions:
				out.append([str(XDB.rec("Items", int(e.id)).get("name", "")),
					"开" if XHangUpAuto.potion_on(s, tab == 1, int(e.id)) else "关"])
			return out
		"hp", "mp":
			var on_txt := "开" if XUiSkin.on() else "ON"
			var off_txt := "关" if XUiSkin.on() else "OFF"
			return _potions.map(func(e): return ["%s 剩余:%d" % [XDB.rec("Items", int(e.id)).get("name", ""), int(e.num)],
				on_txt if XHangUpAuto.potion_on(s, kind == "mp", int(e.id)) else off_txt])
		"sell":
			var out := [["自动卖出间隔场数（0 为不卖出）", str(int(XHangUpAuto.sell_config(s).SellQuality))]]
			var names: Array = XQuality.config().names
			for g in names.size():
				out.append([str(names[g]), {"none": "不卖", "all": "卖", "partial": "部分"}[XHangUpAuto.grade_state(s, g)]])
			if XSafeSell.ENABLED:
				out.append(["保留词条品质", XSafeSell.label(s)])
			return out
	return []


func _refresh() -> void:
	var n := rows().size()
	win.up_arrow = top > 0
	win.down_arrow = top < n - MAX_ROWS
	win.refresh()


func _paint(c: XMVCanvas) -> void:
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	var list := rows()
	var title_w := c.size.x - 12.0 - _status_w()
	for i in range(top, mini(top + MAX_ROWS, list.size())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		c.text(list[i][0], 6, y, title_w, "left", XUiSkin.TEXT if on else XUI.TEXT, XUI.FONT_SIZE, LH)
		c.text(list[i][1], title_w, y, _status_w(), "right", XUiSkin.GOLD_LIGHT if on else XUI.TEXT, XUI.FONT_SIZE, LH)


func _paint_help(c: XMVCanvas) -> void:
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	var lines := XSafeSell.HELP.split("\n")
	for i in lines.size():
		c.text(lines[i], 6, i * LH, c.size.x - 12, "left", XUiSkin.TEXT_2 if on else XUI.TEXT, XUI.FONT_SIZE, LH)


# ---- 操作 ----
func select(i: int) -> void:
	if i == index:
		return
	index = i
	if index < top:
		top = index
	elif index >= top + MAX_ROWS:
		top = index - MAX_ROWS + 1
	XSound.system(0)
	_refresh()


func ok() -> void:
	var s := _s()
	if kind == "med_tabs" and _potions.is_empty() and index == 1:
		XSound.system(3)   # 没药那一行（灰行）：按确定给蜂鸣（T304 小A核 P3-2）
		return
	if index < 0 or index >= rows().size():
		return
	match kind:
		"actors_count", "actors_order":
			_open(XHangUpSubPage.new().setup("counts" if kind == "actors_count" else "order", XHangUpAuto.actors(s)[index]))
		"counts":
			XHangUpAuto.change_count(s, actor, _skills[index], true)
		"order":
			XHangUpAuto.move_earlier(s, _order, index)
		"medication":
			match index:
				0: _open(XHangUpSubPage.new().setup("hp"))
				1: _open(XHangUpSubPage.new().setup("mp"))
				2: XHangUpAuto.change_rate(s, "HpV")
				3: XHangUpAuto.change_rate(s, "MpV")
		"hp", "mp":
			XHangUpAuto.toggle_potion(s, kind == "mp", _potions, index)
		"med_tabs":
			if index == 0:
				XHangUpAuto.change_rate(s, "MpV" if tab == 1 else "HpV")
			else:
				XHangUpAuto.toggle_potion(s, tab == 1, _potions, index - 1)
		"sell":
			if index == 0:
				XHangUpAuto.change_sell_every(s)
			elif _safe() and index == rows().size() - 1:
				XSafeSell.cycle(s, 1)
				XSound.system(1)
			else:
				XHangUpAuto.toggle_grade(s, index - 1)
				XSound.system(1)
	_refresh()


## Star_Window_AutomaticCombatSkills/Skill.update：→ 与 ← 按住连续（只有这两页）
func side(right: bool) -> void:
	if rows().is_empty():
		return
	match kind:
		"counts":
			XHangUpAuto.change_count(_s(), actor, _skills[index], right)
		"order":
			if right:
				XHangUpAuto.move_earlier(_s(), _order, index)
		"sell":
			if not (_safe() and index == rows().size() - 1):
				return
			XSafeSell.cycle(_s(), 1 if right else -1)
			XSound.system(0)
		_:
			return
	_refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _open(page: XHangUpSubPage) -> void:
	_child = page
	for node in get_children():
		if node is CanvasItem:
			node.hide()
	add_child(page)
	page.closed.connect(func():
		page.queue_free()
		_child = null
		_load()
		for node in get_children():
			if node is CanvasItem and node != page:
				node.show()
		_refresh())


func _gui_input(event: InputEvent) -> void:
	if skin != null:
		return   # 新版型的点击由列表自己接（XSkinSubPage）
	if _child or not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, rows().size() - MAX_ROWS))
			_refresh()
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - win.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not Rect2(win.position, win.size).has_point(event.position) or p.y < 0 or p.y >= MAX_ROWS * LH:
				return
			var i := top + floori(p.y / LH)
			if i >= rows().size():
				return
			if i == index:
				ok()
			else:
				select(i)


func _unhandled_input(event: InputEvent) -> void:
	if _child:
		return
	if skin != null and XMenu.page_dir(event) != 0:
		XKeyMap.handled(self)
		page_step(XMenu.page_dir(event))
		return
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		var n := skin_rows().size() if skin != null else rows().size()   # 新版型：没药的灰行也能用键盘停上去（按确定蜂鸣）
		if n > 0:
			select(XMenu._move(index, 1 if event.is_action_pressed("ui_down", true) else -1, n, not event.is_echo()))
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		XKeyMap.handled(self)
		side(event.is_action_pressed("ui_right", true))



# ---- T304 卡 M：新版型（XSkinSubPage 向这里要行和牌）----

## 新版型合掉的层：选人页直接进第一个出战成员的技能页（Q／E 换人）；吃药页两个开关子页并成一页两枚页签。没有出战成员时照旧（列表空、退回）
func _skin_kind() -> void:
	match kind:
		"actors_count", "actors_order":
			var list := XHangUpAuto.actors(_s())
			if not list.is_empty():
				kind = "counts" if kind == "actors_count" else "order"
				actor = list[0]
				switch_actor = true
		"medication":
			kind = "med_tabs"


func skin_self_hosted() -> bool:
	return XHangUpOptionsScene.skin_wanted()


func skin_name() -> String:
	return page_name if page_name != "" else {"counts": "技能次数", "order": "技能顺序", "med_tabs": "自动吃药", "sell": "自动卖出"}.get(kind, "")


func skin_cat() -> String:
	return "hangup"


func skin_crumb() -> Array:
	return [skin._cat_name if skin != null else "挂机与操作", "挂机设置", skin_name()]


func skin_rows() -> Array:
	var s := _s()
	var out := []
	match kind:
		"counts":
			var n := XHangUpAuto.counts(s, actor, _skills)
			for i in _skills.size():
				var k := int(n[i])
				out.append({"text": str(_skills[i].name), "icon": int(_skills[i].get("iconIndex", 0)),
					"right": "%d 次" % k if k > 0 else "不用", "right_color": XUiSkin.GOLD_LIGHT if k > 0 else XUiSkin.TEXT_2})
		"order":
			for i in _order.skills.size():
				var sk: Dictionary = _order.skills[i].skill
				out.append({"text": "%s　%s" % [str(_order.order[i]), str(sk.name)], "icon": int(sk.get("iconIndex", 0))})
		"med_tabs":
			var r: Array = rows()
			out.append({"text": r[0][0], "right": r[0][1] + "%", "right_color": XUiSkin.GOLD_LIGHT})
			if _potions.is_empty():
				out.append({"text": "背包里没有这类药", "disabled": true})
			for k in _potions.size():
				var e: Dictionary = _potions[k]
				var it := XDB.rec("Items", int(e.id))
				var on := XHangUpAuto.potion_on(s, tab == 1, int(e.id))
				out.append({"text": str(it.get("name", "")), "icon": int(it.get("iconIndex", 0)), "sub": "剩余 %d" % int(e.num),
					"right": "开" if on else "关", "right_color": XSkinSubPage.on_color(on)})
		"sell":
			var r: Array = rows()
			for k in r.size():
				var v := str(r[k][1])
				var col: Color = XUiSkin.GOLD_LIGHT
				if v == "不卖":
					col = XUiSkin.TEXT_2
				elif v == "部分":
					col = XUiSkin.GOLD
				out.append({"text": str(r[k][0]), "right": v, "right_color": col})
		_:
			for r in rows():
				out.append({"text": str(r[0]), "right": str(r[1])})
	return out


func skin_card(i: int) -> Dictionary:
	var s := _s()
	var rs := skin_rows()
	if i < 0 or i >= rs.size():
		return {}
	var row: Dictionary = rs[i]
	var d := {"title": str(row.text), "subtitle": str(row.get("right", "")), "desc": "", "sections": []}
	match kind:
		"counts":
			d.subtitle = actor.display_name() + "　" + str(row.right)
			d.desc = str(_skills[i].get("description", ""))
			d.sections = [{"title": "操作", "text": "这个技能在挂机出招顺序里排几次，0 次＝不用。→ 加一次、← 减一次（0～20 循环），确定也是加一次。Q／E 换人。"}]
		"order":
			d.title = str(_order.skills[i].skill.name)
			d.subtitle = "%s　第 %s 个出手" % [actor.display_name(), str(_order.order[i])]
			d.desc = str(_order.skills[i].skill.get("description", ""))
			d.sections = [{"title": "操作", "text": "挂机时按序号从小到大轮流出招。确定或 → 把这一项提前一位。Q／E 换人。"}]
		"med_tabs":
			if i == 0:
				d.desc = "战斗结束后，%s低于这个比例的人自动吃药。" % ("魔法" if tab == 1 else "生命")
				d.sections = [{"title": "操作", "text": "确定 +10%，到 100% 后回到 10%。Q／E 换页签。"}]
			elif _potions.is_empty():
				d.subtitle = ""
				d.desc = "背包里没有能%s的药，获得后会显示在这里。" % ("回魔法" if tab == 1 else "回生命")
				d.sections = [{"title": "操作", "text": "Q／E 换页签。"}]
			else:
				var it := XDB.rec("Items", int(_potions[i - 1].id))
				d.desc = str(it.get("description", ""))
				var on := XHangUpAuto.potion_on(s, tab == 1, int(_potions[i - 1].id))
				d.sections = [{"title": "", "text": "剩余 %d 个，开启的药会自动使用。" % int(_potions[i - 1].num)},
					XSkinSubPage.choices_section(["开", "关"], 0 if on else 1),
					{"title": "操作", "text": "确定切换。Q／E 换页签。"}]
		"sell":
			var last := _safe() and i == rs.size() - 1
			if i == 0:
				d.desc = "每自动战斗指定场数后卖一次装备；0 为不卖出。"
				d.sections = [{"title": "操作", "text": "确定 +1，到 11 后回到 0。"}]
			elif last:
				d.desc = "词条品质达到这一档的装备整件保留，不卖。"
				d.sections = [{"title": "操作", "text": "确定或 → 往后一档，← 往前一档。"}]
			else:
				var st := XHangUpAuto.grade_state(s, i - 1)
				d.desc = "开着时，挂机自动卖出这一品质的装备。"
				d.sections = [XSkinSubPage.choices_section(["卖", "不卖", "部分"], {"all": 0, "none": 1, "partial": 2}[st]),
					{"title": "", "text": "「部分」：这一档里有的旧品质卖、有的不卖。确定一次：全不卖变全卖，否则全不卖。"},
					{"title": "操作", "text": "确定整档切换。"}]
			if _safe():
				d.sections.append({"title": "安全出售", "text": XSafeSell.HELP})
	return d


func skin_hints() -> Array:
	var back := ["取消", "返回"]
	match kind:
		"counts":
			return [["左右", "加减"], ["Q/E", "换人"], back]
		"order":
			return [["确定", "提前一位"], ["Q/E", "换人"], back]
		"med_tabs":
			return [["确定", "切换"], ["Q/E", "换页签"], back]
		"sell":
			if _safe() and index == rows().size() - 1:
				return [["确定", "下一档"], ["左右", "前后一档"], back]
			return [["确定", "切换"], back]
	return [["确定", "选择"], back]


func skin_empty() -> String:
	return "这里没有东西"


## Q／E：技能页换人，吃药页换页签（播光标音，回到第一行）
func page_step(d: int) -> void:
	if switch_actor:
		var list := XHangUpAuto.actors(_s())
		if list.size() < 2:
			return
		actor = list[posmod(list.find(actor) + d, list.size())]
	elif kind == "med_tabs":
		tab = posmod(tab + d, 2)
	else:
		return
	_load()
	index = 0
	top = 0
	XSound.system(0)
	if _left != null:
		_left.queue_redraw()
	if _tabs != null:
		_tabs.queue_redraw()
	_refresh()


## 新版型多的两件：技能页左块的像素小人（环藏起）、吃药页列表头右边的两枚页签
func _skin_extras() -> void:
	if switch_actor:
		skin.ring.visible = false
		_left = Control.new()
		_left.name = "ActorBlock"
		_left.mouse_filter = Control.MOUSE_FILTER_STOP
		_left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_left.draw.connect(_draw_left)
		_left.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				page_step(-1 if e.position.x < _left.size.x / 2.0 else 1)
				_left.accept_event())
		skin.layout.left.add_child(_left)
	if kind == "med_tabs":
		_tabs = Control.new()
		_tabs.name = "MedTabs"
		_tabs.mouse_filter = Control.MOUSE_FILTER_STOP
		_tabs.draw.connect(_draw_tabs)
		_tabs.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var k := 0 if e.position.x < tab_rect(1).position.x else 1
				if k != tab:
					page_step(k - tab)
				_tabs.accept_event())
		skin.list_panel.add_child(_tabs)
		skin.list_panel.resized.connect(_place_tabs)
		_place_tabs()


func _draw_left() -> void:
	var lb := _left.size
	var foot := Vector2(lb.x / 2.0, lb.y / 2.0 + 40.0)
	var dat := actor.data()
	XSkinPartyPage.draw_walker(_left, str(dat.get("characterName", "")), int(dat.get("characterIndex", 0)), foot, 150.0)
	var f := XUiSkin.font("title")
	var fit := XSkinList.fit_text(f, actor.display_name(), lb.x - 16, XUiSkin.FS_CARD, 18)
	var tw := f.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
	XUiSkin.ds(_left, f, Vector2((lb.x - tw) / 2.0, foot.y + 44), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT)
	var list := XHangUpAuto.actors(_s())
	var body := XUiSkin.font("body")
	var sub := "‹ Q　%d / %d　E ›" % [list.find(actor) + 1, list.size()]
	var sw := body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
	XUiSkin.ds(_left, body, Vector2((lb.x - sw) / 2.0, foot.y + 44 + XUiSkin.FS_AUX * 1.8), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)


## 页签：列表标题那一行的右边，17 号 TEXT_2，当前页 TEXT_HI＋2px 旧金下划线（T254 3.0 页内页签）
func tab_rect(k: int) -> Rect2:
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX_MAX
	var x := _tabs.size.x
	var r := Rect2()
	for j in range(TAB_NAMES.size() - 1, -1, -1):
		var w := body.get_string_size(TAB_NAMES[j], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
		x -= w
		if j == k:
			r = Rect2(x, 0, w, _tabs.size.y)
		x -= 8.0
	return r


func _place_tabs() -> void:
	var lp := skin.list_panel
	_tabs.position = Vector2(lp.size.x * 0.45, XUiSkin.PAD - 4.0)
	_tabs.size = Vector2(lp.size.x * 0.55 - XUiSkin.PAD - 8.0, 34.0)
	_tabs.queue_redraw()


func _draw_tabs() -> void:
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX_MAX
	for k in TAB_NAMES.size():
		var r := tab_rect(k)
		var cur := k == tab
		XUiSkin.ds(_tabs, body, Vector2(r.position.x + 8.0, r.position.y + r.size.y / 2.0 + fs * 0.36), TAB_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			XUiSkin.TEXT_HI if cur else XUiSkin.TEXT_2)
		if cur:
			_tabs.draw_rect(Rect2(r.position.x + 8.0, r.end.y - 3.0, r.size.x - 16.0, 2.0), XUiSkin.GOLD)
