class_name XSkinActorWarehousePage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T292 角色仓库新布局（T254 3.4；版型一、不画环，左块放选中角色的像素小人＋名字）。
## 存取规则、停用角色蜂鸣、「队伍最少保留一位角色」提示、空行蜂鸣、退出时技能共享／羁绊／领袖刷新全部还是 XActorWarehouseScene／XActorWarehouse 原来的代码。
## 旧页 → 新页（T254 3.4 对应表）：
## - 标题「角色仓库」黄字 → 页名。
## - 指令「存入／取出」（名单跟着换成队伍／仓库）→ 列表上方两枚页内页签「队伍 N」「仓库 N」，Q／E 切换（旧 cmd）；不再有「先进指令窗」这一层。
## - 名单一行同整队名单 → 同整队新页的名单行（XSkinPartyPage.roster_row：头像、名字、出战小标、Lv、生命条、魔法条；TP 不显示）；停用角色变灰带「停用」。
## - 确定即存入／取出、光标不动 → 照旧；右牌写「存进仓库后」／「取出来后」会怎样（只写 XActorWarehouse 里核对过的事）＋「队伍至少留一个人」；
##   主按钮「存入」／「取出」。取消＝离开（旧页先回指令窗再离开）。
## 新皮肤关着、或 ENABLED＝false 时 XActorWarehouseScene 不建这一页，旧页一行不变。

## T292 回退开关：false＝天启篇新皮肤下角色仓库也回旧页
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_TITLE := "角色仓库"
const T_TABS := ["队伍", "仓库"]
const T_EMPTY_STORE := "仓库是空的"
const T_MIN_ONE := XActorWarehouse.LAST_ACTOR_TEXT   # 「队伍最少保留一位角色」，同旧页提示（小A文字审）
const T_OFF := "停用"

var scene: XActorWarehouseScene
var inner_tabs: XSkinInnerTabs
var _syncing := false
var _list_key := []


func _init(s: XActorWarehouseScene) -> void:
	scene = s
	name = "SkinActorWarehousePage"
	title = T_TITLE
	group_key = ""            # 从 NPC 进的页不画页签条（T254 3.0）
	columns = 1
	row_height = XSkinPartyPage.ROW_H
	left_w = 312.0
	right_w = 312.0
	show_ring = false
	auto_nav = false
	focus = "list"
	currencies = []
	hint_list = []


func _ready() -> void:
	super()
	list.empty_center = true
	list.icon_size = 40
	list.right2_w = 110.0 * 2.0 + XSkinPartyPage.BAR_GAP + 16.0
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	list.draw.connect(func(): XSkinPartyPage.draw_bars(list))
	card_button.connect(func(_i): scene.ok())
	card.gui_input.connect(_on_card_gui)
	inner_tabs = XSkinInnerTabs.new()
	inner_tabs.changed.connect(_on_tab)
	list_panel.add_child(inner_tabs)
	layout.left.draw.connect(_draw_left)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


## 页签在列表标题那一行，列表整体下移（同商店 XSkinShopPage._place_tabs）
func relayout() -> void:
	super()
	if inner_tabs == null:
		return
	var cs := layout.center.size
	var lx := list.position.x
	inner_tabs.position = Vector2(XUiSkin.PAD + 8, LIST_TOP - 6.0)
	inner_tabs.size = Vector2(cs.x - XUiSkin.PAD * 2 - 8, XSkinInnerTabs.H)
	var shift := XSkinInnerTabs.H + 4.0
	list.position = Vector2(lx, LIST_TOP + shift)
	var rows := floori((cs.y - LIST_TOP - shift - FOOTER_H) / float(row_height))
	list.size = Vector2(cs.x - lx - 8.0, rows * row_height)


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.title_win, sc.cmd_win, sc.list_win]:
		w.visible = false
	var s := XState.current
	var counts := [s.party.size(), XActorWarehouse.stored(s).size()]
	inner_tabs.set_tabs([0, 1].map(func(i): return "%s %d" % [T_TABS[i], counts[i]]), sc.cmd)
	list_title = ""
	list.empty_text = T_EMPTY_STORE
	var rows := []
	for id in sc.data:
		rows.append(row_for(int(id)))
	var key := [sc.cmd, rows.map(func(r): return [r.text, r.get("tags", []), r.get("right", ""), r.get("_hp", 0), r.get("_mp", 0)])]
	var idx := clampi(sc.index, 0, maxi(rows.size() - 1, 0))
	if not rows.is_empty() and sc.index != idx:
		sc.index = idx   # 存／取走末尾一行后旧页光标停在空行（O-091）；新页没有空行，夹回最后一行（小A核 P1-2）
	if key != _list_key:
		_list_key = key
		set_items(rows, idx)
	elif list.index != idx and not rows.is_empty():
		list.select(idx)
	set_focus("list")
	_sync_card()
	set_hint_list([["确定", "存入" if sc.deposit_mode() else "取出"], ["Q / E", "队伍 / 仓库"], ["取消", "离开"]])
	_syncing = false
	layout.left.queue_redraw()
	list_panel.queue_redraw()


func row_for(id: int) -> Dictionary:
	var on := XActorWarehouse.enabled(id)
	return XSkinPartyPage.roster_row(XState.current.actor(id), on, T_OFF)


func current_id() -> int:
	var sc := scene
	return sc.data[sc.index] if sc.index >= 0 and sc.index < sc.data.size() else 0


## 右牌（测试按对应表核）：存入／取出会怎样只写 XActorWarehouse.deposit／withdraw 里做的事
func card_data() -> Dictionary:
	var sc := scene
	var s := XState.current
	var id := current_id()
	if id <= 0:
		return {"title": "", "sections": [], "buttons": []}
	var a := s.actor(id)
	var cls := str(XDB.rec("Classes", a.class_id).get("name", ""))
	var lines := [{"left": "生命", "right": "%s / %s" % [XMenu._group(a.hp), XMenu._group(a.mhp)], "right_color": XUiSkin.HP_TEXT},
		{"left": "魔法", "right": "%s / %s" % [XMenu._group(a.mp), XMenu._group(a.mmp)], "right_color": XUiSkin.MP_TEXT}]
	var rows := []
	var head := ""
	var verb := "存入" if sc.deposit_mode() else "取出"
	var disabled := false
	head = verb + "后"   # 「存入后」「取出后」，同按钮（小A文字审）
	if not XActorWarehouse.enabled(id):
		rows.append({"text": "该角色已停用，无法存取。", "color": XUiSkin.DOWN})
		disabled = true
	elif sc.deposit_mode():
		if s.party.size() <= 1:
			rows.append({"text": "队伍只剩最后一人，无法存入。", "color": XUiSkin.DOWN})
			disabled = true
		else:
			rows.append({"text": "暂离队伍；等级、技能、装备都会保留，随时可取出。", "color": XUiSkin.TEXT})
			if s.battle_slots.has(id):
				rows.append({"text": "当前在出战栏中：存入后将按队伍前 5 人重排出战位。", "color": XUiSkin.TEXT})
		rows.append({"text": T_MIN_ONE, "color": XUiSkin.TEXT_2})
	else:
		rows.append({"text": "回到队伍末尾，暂不出战；需出战请到「整队」编入。", "color": XUiSkin.TEXT})
	return {"icon": null, "title": a.display_name(), "subtitle": "Lv %s%s" % [XMenu._group(a.level), " · " + cls if cls != "" else ""],
		"sections": [{"title": "", "lines": lines}, {"title": head, "rows": rows}],
		"buttons": [{"text": verb, "primary": true, "disabled": disabled}], "_disabled": disabled}


func _sync_card() -> void:
	var d := card_data()
	card.visible = current_id() > 0   # 空列表右牌不画（T254 3.0「空列表」）
	d.erase("_disabled")
	d.button_index = -1
	set_card(d)


# ---- 按键：Q／E 换页签、取消离开；上下、确定照旧走 XActorWarehouseScene ----

func input(event: InputEvent) -> bool:
	var sc := scene
	if event.is_action_pressed("ui_cancel"):
		sc.mode = "command"   # 旧页列表上取消先回指令窗；新页没有这一层，直接离开
		sc.cancel()
		return true
	if XMenu.page_dir(event) != 0:
		switch_tab(posmod(sc.cmd + XMenu.page_dir(event), 2))
		return true
	return false


func switch_tab(i: int) -> void:
	var sc := scene
	if i == sc.cmd:
		return
	sc._move_cmd(i - sc.cmd, false)   # 旧指令窗左右：换列表、回到顶端、响光标音
	sc.index = 0
	sc._refresh()


func _on_tab(i: int) -> void:
	if _syncing:
		return
	switch_tab(i)


func _on_list_index(i: int) -> void:
	if _syncing or i == scene.index:
		return
	XSound.system(0)
	scene._select(i)


func _on_list_click(i: int) -> void:
	if _syncing:
		return
	if i == scene.index:
		scene.ok()


## 点到灰掉的主按钮：蜂鸣（同按确定），焦点框不留在灰按钮上（小A核 P3-1；XSkinCard 点禁用钮也会挪焦点，这里事后还原）
func _on_card_gui(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in card.buttons.size():
		if card.button_rect(i).has_point(event.position) and bool(card.buttons[i].get("disabled", false)):
			XSound.system(3)
			_clear_card_focus.call_deferred()
			return


func _clear_card_focus() -> void:
	card.button_index = -1
	card.queue_redraw()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene.mode = "command"
		scene.cancel()
		accept_event()


# ---- 左块：选中角色的像素小人（3 倍）＋名字 ----

func _draw_left() -> void:
	var id := current_id()
	if id <= 0:
		return
	var a := XState.current.actor(id)
	var lb := layout.left.size
	var foot := Vector2(lb.x / 2.0, lb.y / 2.0 + 40.0)
	XSkinPartyPage.draw_walker(layout.left, str(a.data().get("characterName", "")), int(a.data().get("characterIndex", 0)), foot, 150.0)
	var f := XUiSkin.font("title")
	var fs := XUiSkin.FS_CARD
	var fit := XSkinList.fit_text(f, a.display_name(), lb.x - 16, fs, 18)
	var tw := f.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
	XUiSkin.ds(layout.left, f, Vector2((lb.x - tw) / 2.0, foot.y + 44), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT)
