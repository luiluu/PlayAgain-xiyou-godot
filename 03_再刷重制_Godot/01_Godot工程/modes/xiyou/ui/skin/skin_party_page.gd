class_name XSkinPartyPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T292 整队新布局（T254 3.3；上面一排出战位，下面名单＋右牌）。只管「怎么摆、怎么画、按了等于旧页的哪一步」：
## 换人、离队、互换、还原、超强者拦截、完成前的技能共享／羁绊／领袖刷新全部还是 XPartyScene 原来的代码（同一套 mode／slot_index／list_index）。
## 旧页 → 新页（T254 3.3 对应表）：
## - 指令窗「整队／离队／还原／完成」→ 不要指令窗：进页光标就在出战位上（mode＝slot、cmd＝整队）；确定＝给这一格选人；
##   名单第一行「空出这一格」＝离队；X＝还原；取消＝完成并返回（出战栏全空／全员阵亡时拦住、提示道出原因、留在本页）。
## - 出战栏 5 格 → 上排 5 张格子牌：格号、像素小人（行走图）、名字、Lv；空位虚线框「＋ 空位」；首位是领袖角色时右上「领队」，
##   天启篇第 5 格右上「助力」；选中的格子红框红底。Q／E 和旁边换位（照旧）。
## - 名单（首尾「离队」＋队伍全体）→ 首行「空出这一格」＋每人一行：头像、名字、「出战 N」「助力」小标、Lv、生命条＋数、魔法条＋数；
##   TP 不显示（5AB-6 默认：不在战斗里永远是 0）。放不进这一格的（超强者没开挑战、天启篇超上限）变灰带小标，确定照旧蜂鸣。
## - 天启篇本层元素一行（旧页出战栏底下）→ 名单标题右边。
## - 右牌：选中的人的头像、名字、Lv、职业、出没出战；生命、魔法条；「换上后」一句话说清这次确定会发生什么；主按钮「放进第 N 格」。
## 新皮肤关着、或 ENABLED＝false 时 XPartyScene 不建这一页，旧页一行不变。

## T292 回退开关：false＝天启篇新皮肤下整队也回旧页（带指令窗的旧操作层级）
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_TITLE := "整队"
const T_REMOVE := "空出这一格"
const T_EMPTY_SLOT := "＋ 空位"
const T_LEADER := "领队"
const T_HELPER := "助力"
const T_NO_SUPER := "没开挑战"
const T_CANT := "放不进这格"
const T_FINISH_BLOCK := "出战栏至少保留一位存活角色，才能离开。"
const SLOT_H := 156.0
const ROW_H := 52
const BAR_W := 150.0
const BAR_GAP := 20.0

var scene: XPartyScene
var slot_row: Control
var body: Control
var _syncing := false
var _list_key := []
var _list_right := ""


func _init(s: XPartyScene) -> void:
	scene = s
	name = "SkinPartyPage"
	title = T_TITLE
	group_key = "actor"
	columns = 1
	row_height = ROW_H
	left_w = 0.0
	right_w = 408.0
	show_ring = false
	auto_nav = false
	focus = "list"
	currencies = []
	hint_list = []


func _ready() -> void:
	super()
	list.icon_size = 40
	list.right2_w = BAR_W * 2.0 + BAR_GAP + 16.0
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	list.draw.connect(_draw_bars)
	list_panel.draw.connect(_draw_list_right)
	card_button.connect(_on_card_button)
	slot_row = Control.new()
	slot_row.name = "SlotRow"
	slot_row.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_row.draw.connect(_draw_slots)
	slot_row.gui_input.connect(_on_slot_gui)
	add_child(slot_row)
	move_child(slot_row, top_layer.get_index())
	body = Control.new()
	body.name = "PartyBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.draw.connect(_draw_body)
	card.add_child(body)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


## 上排出战位占 72～228；名单和右牌从 244 起；名单不受中块 720 封顶（左边贴页边，右边到右牌前）
func relayout() -> void:
	if layout != null:
		layout.top = XUiSkin.TOP + SLOT_H + XUiSkin.PANEL_GAP
	super()
	if layout == null or slot_row == null:
		return
	var view := layout.view_size()
	var m := XSkinLayout.margin_for(view.x)
	var x0 := m + 32.0
	var rr: Rect2 = layout.rects().right
	layout.center.position = Vector2(x0, layout.center.position.y)
	layout.center.size = Vector2(rr.position.x - 52.0 - x0, layout.center.size.y)
	var lx := list.position.x
	list.size = Vector2(layout.center.size.x - lx - 8.0, list.size.y)
	slot_row.position = Vector2(x0, XUiSkin.TOP)
	slot_row.size = Vector2(rr.end.x - x0, SLOT_H)
	slot_row.queue_redraw()


func slot_rect(i: int) -> Rect2:
	var n := XState.MAX_BATTLE_MEMBERS
	var g := 16.0
	var w := minf((slot_row.size.x - g * (n - 1)) / n, 280.0)
	var total := w * n + g * (n - 1)
	var x := (slot_row.size.x - total) / 2.0
	return Rect2(x + i * (w + g), 0, w, SLOT_H)


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.cmd_win, sc.slot_win, sc.list_win]:
		w.visible = false
	set_focus("list")
	list.active = sc.mode == "list"
	_sync_list()
	_sync_card()
	set_hint_list(_hints())
	_syncing = false
	slot_row.queue_redraw()
	body.queue_redraw()
	list_panel.queue_redraw()


## 名单行（新行号 k ↔ 旧 list_data 第 k 行；旧名单末尾那行「离队」不画）
func _sync_list() -> void:
	var sc := scene
	var data := sc.list_data()
	sc.list_index = clampi(sc.list_index, 0, roster_size() - 1)   # 旧名单末尾那行「离队」新页不画：光标不许落上去（小A核 P1-1）
	var rows := []
	for k in data.size() - 1:
		rows.append(roster_row_for(int(data[k])))
	list_title = "名单"
	_list_right = deck_line()
	var key := rows.map(func(r): return [r.text, r.get("tags", []), r.get("right", ""), r.get("color", Color.WHITE), r.get("_hp", 0), r.get("_mp", 0)])
	var idx := clampi(sc.list_index, 0, maxi(rows.size() - 1, 0))
	if key != _list_key:
		_list_key = key
		set_items(rows, idx)
	elif list.index != idx:
		list.select(idx)


func roster_row_for(id: int) -> Dictionary:
	var sc := scene
	if id <= 0:
		return {"text": T_REMOVE, "icon": XPartyScene.REMOVE_ICON, "color": XUiSkin.TEXT_2}
	var s := XState.current
	var target := sc.slot_index if XTianqi.HELPER_RULES and XTianqi.active(s) else -1
	return roster_row(s.actor(id), XItemMarks.can_deploy(s, id, target), deploy_block_tag(s, id))


## 放不进时的小标：超强者没开挑战（原版档）／天启篇超上限或助力位规则
static func deploy_block_tag(s: XState, _id: int) -> String:
	return T_CANT if XTianqi.active(s) else T_NO_SUPER


## 名单一行（角色仓库共用）：头像、名字、出战小标、Lv；生命、魔法条由 draw_bars 画在 right2 那一列。enabled＝false 变灰带 block_tag
static func roster_row(a: XActor, enabled := true, block_tag := "") -> Dictionary:
	var s := XState.current
	var tags := []
	var at := s.battle_slots.find(a.actor_id)
	if at >= 0:
		if at == XTianqi.HELPER_SLOT and XTianqi.active(s):
			tags.append(T_HELPER)
		else:
			tags.append("出战 %d" % (at + 1))
	if not enabled and block_tag != "":
		tags.append(block_tag)
	var r := {"text": a.display_name(), "icon": XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0))),
		"tags": tags, "right": "Lv %s" % XMenu._group(a.level), "right2": "", "color": XUiSkin.TEXT if enabled else XUiSkin.TEXT_3,
		"_hp": a.hp, "_mhp": a.mhp, "_mp": a.mp, "_mmp": a.mmp, "_dead": a.is_dead(), "_off": not enabled}
	return r


## 名单标题右：天启篇本层元素一行（旧页出战栏底下那行，原文照搬）
func deck_line() -> String:
	var s := XState.current
	if not XTianqiElements.deck_on(s):
		return ""
	var fl := XDungeon.map_floor(s.map_id)
	if fl < 1 or fl > 33:
		return ""
	var prof := XTianqiElements.floor_deck(s, fl)
	var cov := XTianqiElements.party_coverage(s, prof)
	var w_tx := "可击弱点：" + ("、".join((cov.weak_hits as Array).map(func(e): return XTianqiElements.element_name(int(e)))) if not cov.weak_hits.is_empty() else "无")
	if cov.has_higher:
		w_tx += "　高阶：有"
	return "%s  |  %s" % [XTianqiElements.format_profile_line(prof), w_tx]


## 生命、魔法条（画在列表的 right2 那一列；列表行带 _hp/_mhp/_mp/_mmp）
static func draw_bars(l: XSkinList) -> void:
	var num := XUiSkin.font("num")
	var first := l.top_row
	var last := mini(l.items.size(), l.top_row + l.visible_rows())
	for i in range(first, last):
		var it: Dictionary = l.items[i]
		if not it.has("_hp"):
			continue
		var r := l.cell_rect(i)
		var bw := (l.right2_w - 16.0 - BAR_GAP) / 2.0   # 两条量条平分 right2 那一列（角色仓库中块窄，条也窄）
		var x := r.end.x - 14.0 - (bw * 2.0 + BAR_GAP)
		var cy := r.position.y + r.size.y / 2.0
		var dim := 0.45 if bool(it.get("_off", false)) else 1.0
		_bar(l, num, Rect2(x, cy, bw, 0), float(it._hp), float(it._mhp), XUiSkin.HP, XUiSkin.DOWN if bool(it.get("_dead", false)) else XUiSkin.HP_TEXT, dim)
		_bar(l, num, Rect2(x + bw + BAR_GAP, cy, bw, 0), float(it._mp), float(it._mmp), XUiSkin.MP, XUiSkin.MP_TEXT, dim)


## 一条量条：数在上、条在下（r.position.y＝行中线）
static func _bar(ci: CanvasItem, num: Font, r: Rect2, cur: float, mx: float, col: Color, tcol: Color, dim := 1.0) -> void:
	var fs := XUiSkin.FS_AUX
	var t := XMenu._group(int(cur))
	var tw := num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(ci, num, Vector2(r.position.x + r.size.x - tw, r.position.y + 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tcol, dim))
	var by := r.position.y + 8
	XUiSkin.draw_gauge(ci.get_canvas_item(), Rect2(r.position.x, by, r.size.x, 5),
		cur / maxf(mx, 1.0), col, dim, Color(1, 1, 1, 0.10 * dim), 2, true)


func _draw_bars() -> void:
	draw_bars(list)


func _draw_list_right() -> void:
	if _list_right == "":
		return
	var f := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX
	var max_w := list_panel.size.x - XUiSkin.PAD * 2 - 80.0
	var fit := XSkinList.fit_text(f, _list_right, max_w, fs, fs)
	var tw := f.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(list_panel, f, Vector2(list_panel.size.x - XUiSkin.PAD - 8 - tw, XUiSkin.PAD + 20), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("9be4ff"))


# ---- 右牌 ----

## 右牌上的人：选人时是名单那一行的人（「空出这一格」时是这格原来的人），在出战位上时是这格的人；没有为 0
func card_actor_id() -> int:
	var sc := scene
	if sc.mode == "list":
		var id := int(sc.list_data()[clampi(sc.list_index, 0, sc.list_data().size() - 1)])
		if id > 0:
			return id
	return int(sc.slots()[sc.slot_index]) if sc.slot_index >= 0 else 0


## 这次确定会发生什么（一句话）
func outcome() -> String:
	var sc := scene
	var s := XState.current
	var n := sc.slot_index
	if n < 0:
		return ""
	var cur := int(sc.slots()[n])
	if sc.mode != "list":
		return "按确定给第 %d 格选人；Q / E 和旁边换位。" % (n + 1)
	var id := int(sc.list_data()[sc.list_index])
	if id <= 0:
		return "%s离开第 %d 格，回到待命。" % [_name(cur), n + 1] if cur > 0 else "第 %d 格原本就是空的。" % (n + 1)
	if not XItemMarks.can_deploy(s, id, n):
		return "超强者没开挑战，不能出战。" if not XTianqi.active(s) else "%s放不进第 %d 格（超强者上限或助力位规则）。" % [_name(id), n + 1]
	var at := sc.slots().find(id)
	if at == n:
		return "%s已经在第 %d 格。" % [_name(id), n + 1]
	if at >= 0:
		return "%s换到第 %d 格，%s换到第 %d 格。" % [_name(id), n + 1, _name(cur), at + 1] if cur > 0 else "%s从第 %d 格挪到第 %d 格。" % [_name(id), at + 1, n + 1]
	return "%s放入第 %d 格，%s回到待命。" % [_name(id), n + 1, _name(cur)] if cur > 0 else "%s放入第 %d 格。" % [_name(id), n + 1]


static func _name(id: int) -> String:
	return XState.current.actor(id).display_name() if id > 0 else ""


func button_text() -> String:
	var sc := scene
	var n := sc.slot_index + 1
	if sc.mode != "list":
		return "给第 %d 格选人" % n
	return "空出第 %d 格" % n if int(sc.list_data()[sc.list_index]) <= 0 else "放进第 %d 格" % n


func _sync_card() -> void:
	card.setup({"icon": null, "title": "", "subtitle": "", "notice": "", "desc": "", "sections": [],
		"buttons": [{"text": button_text(), "primary": true}], "button_index": -1})


## 右牌内容（测试按对应表核）：{id, name, lv, class, state, hp, mhp, mp, mmp, outcome}
func card_info() -> Dictionary:
	var id := card_actor_id()
	var out := {"id": id, "outcome": outcome()}
	if id <= 0:
		return out
	var s := XState.current
	var a := s.actor(id)
	var at := s.battle_slots.find(id)
	out.name = a.display_name()
	out.lv = "Lv %s" % XMenu._group(a.level)
	out["class"] = str(XDB.rec("Classes", a.class_id).get("name", ""))
	out.state = "待命" if at < 0 else (T_HELPER + "位" if at == XTianqi.HELPER_SLOT and XTianqi.active(s) else "出战第 %d 格" % (at + 1))
	out.hp = a.hp
	out.mhp = a.mhp
	out.mp = a.mp
	out.mmp = a.mmp
	out.face = XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
	return out


func _draw_body() -> void:
	var info := card_info()
	var w := card.size.x
	var pad := card.pad
	var bottom := card.content_bottom()
	var head := XUiSkin.font("title")
	var f := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var y := pad
	if int(info.id) > 0:
		XSkinSavePage.draw_face_circle(body, info.face, Vector2(pad + 32, y + 32), 32)
		var x := pad + 64 + 14
		var tfs := XUiSkin.fs(XUiSkin.FS_CARD)
		var fit := XSkinList.fit_text(head, str(info.name), w - x - pad, tfs, 18)
		XUiSkin.ds(body, head, Vector2(x, y + tfs * 0.95), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT)
		var sub := "%s · %s" % [info.lv, info["class"]] if str(info["class"]) != "" else str(info.lv)
		XUiSkin.ds(body, f, Vector2(x, y + tfs * 1.0 + XUiSkin.FS_AUX + 8), sub, HORIZONTAL_ALIGNMENT_LEFT, w - x - pad, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		XUiSkin.ds(body, f, Vector2(x, y + tfs * 1.0 + XUiSkin.FS_AUX * 2 + 16), str(info.state), HORIZONTAL_ALIGNMENT_LEFT, w - x - pad, XUiSkin.FS_AUX,
			XUiSkin.GOLD if str(info.state) != "待命" else XUiSkin.TEXT_2)
		y += 64 + 30
		for k in [["生命", "hp", "mhp", XUiSkin.HP, XUiSkin.HP_TEXT], ["魔法", "mp", "mmp", XUiSkin.MP, XUiSkin.MP_TEXT]]:
			XUiSkin.ds(body, f, Vector2(pad, y + XUiSkin.FS_AUX), str(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
			var t := "%s / %s" % [XMenu._group(int(info[k[1]])), XMenu._group(int(info[k[2]]))]
			var tw := num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
			XUiSkin.ds(body, num, Vector2(w - pad - tw, y + XUiSkin.FS_AUX), t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, k[4])
			XUiSkin.draw_gauge(body.get_canvas_item(), Rect2(pad, y + XUiSkin.FS_AUX + 8, w - pad * 2, 6),
				float(info[k[1]]) / maxf(float(info[k[2]]), 1.0), k[3], 1.0, Color(1, 1, 1, 0.10), 3, true)
			y += XUiSkin.FS_AUX + 26
	y += 6
	if y + 40 > bottom:
		return
	XUiSkin.draw_divider(body, pad, w - pad, y, true, 0.85 if XUiSkin.polish_on() else 1.0)
	XUiSkin.ds(body, f, Vector2(pad, y + 8 + XUiSkin.FS_AUX_MAX), "换上后", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
	y += 16 + XUiSkin.FS_AUX_MAX + 6
	var para := TextParagraph.new()
	para.width = w - pad * 2
	var ofs := XUiSkin.FS_AUX_MAX
	para.add_string(str(info.outcome), f, ofs)
	for li in para.get_line_count():
		if y + ofs * 1.5 > bottom:
			break
		var rg := para.get_line_range(li)
		XUiSkin.ds(body, f, Vector2(pad, y + ofs), str(info.outcome).substr(rg.x, rg.y - rg.x), HORIZONTAL_ALIGNMENT_LEFT, -1, ofs, XUiSkin.TEXT)
		y += ofs * 1.5


# ---- 出战位 ----

## 一格的显示（测试按对应表核）：{id, label, name, lv, leader, helper, empty}
func slot_info(i: int) -> Dictionary:
	var s := XState.current
	var id := int(scene.slots()[i])
	var out := {"id": id, "label": "第 %d 格" % (i + 1), "helper": i == XTianqi.HELPER_SLOT and XTianqi.active(s), "empty": id <= 0}
	if id > 0:
		var a := s.actor(id)
		out.name = a.display_name()
		out.lv = "Lv %s" % XMenu._group(a.level)
		out.leader = XLeadActor.is_leader(s, id)
		out.dead = a.is_dead()
	return out


func _draw_slots() -> void:
	var ci := slot_row.get_canvas_item()
	var f := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	for i in XState.MAX_BATTLE_MEMBERS:
		var r := slot_rect(i)
		var info := slot_info(i)
		var sel: bool = i == scene.slot_index
		if info.empty:
			_dashed(r.grow(-1), Color(XUiSkin.line_c(), 0.6))
		else:
			XUiSkin.draw_panel(ci, r)
			var edge := StyleBoxFlat.new()
			edge.draw_center = false
			edge.set_corner_radius_all(XUiSkin.RADIUS)
			edge.border_color = Color(XUiSkin.line_c(), 0.35)
			edge.set_border_width_all(1)
			edge.draw(ci, r)
		if sel:   # 选中的格子红框红底（选人时这格还亮着、减淡）
			XUiSkin.draw_select(ci, r, XUiSkin.breath_alpha() if scene.mode == "slot" else 0.6, 1.0 if scene.mode == "slot" else 0.55)
		XUiSkin.ds(slot_row, f, Vector2(r.position.x + 12, r.position.y + 10 + XUiSkin.FS_AUX), str(info.label), HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		var tag := ""
		if info.get("leader", false):
			tag = T_LEADER
		elif info.helper:
			tag = T_HELPER
		if tag != "":
			XSkinTag.draw(slot_row, Vector2(r.end.x - 10 - XSkinTag.width(tag), r.position.y + 10 + XSkinTag.height() / 2.0), tag)
		if info.empty:
			var t := T_EMPTY_SLOT
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST).x
			XUiSkin.ds(slot_row, f, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST, XUiSkin.TEXT_3)
			continue
		var a := XState.current.actor(int(info.id))
		draw_walker(slot_row, str(a.data().get("characterName", "")), int(a.data().get("characterIndex", 0)), Vector2(r.get_center().x, r.position.y + 104), 88.0)
		var nfs := XUiSkin.fs(19)
		var nf := XSkinList.fit_text(f, str(info.name), r.size.x - 16, nfs, 14)
		var nw := f.get_string_size(str(nf[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(nf[1])).x
		XUiSkin.ds(slot_row, f, Vector2(r.position.x + (r.size.x - nw) / 2.0, r.position.y + 128), str(nf[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(nf[1]),
			XUiSkin.DOWN if info.get("dead", false) else XUiSkin.TEXT)
		var lv := str(info.lv)
		var lw := num.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		XUiSkin.ds(slot_row, num, Vector2(r.position.x + (r.size.x - lw) / 2.0, r.position.y + 148), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.GOLD_LIGHT)


func _dashed(r: Rect2, c: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		slot_row.draw_dashed_line(pts[k], pts[k + 1], c, 1.0, 6.0)


## 画过的行走图留着引用（T304 小A核 P1-1）：局部 load() 一返回纹理就被释放，画出来是实心白块（同 XMVCanvas._cache）
static var _walker_cache := {}


static func walker_texture(cname: String) -> Texture2D:
	var p := XDB.img_path("characters", cname) if cname != "" else ""
	if p == "":
		return null
	if not _walker_cache.has(p):
		_walker_cache[p] = load(p) as Texture2D
	return _walker_cache[p]


## 行走图朝下中间一帧（像素小人）：底边中点在 foot，整数倍放大到不超过 max_h 高（最近邻）
static func draw_walker(ci: CanvasItem, cname: String, index: int, foot: Vector2, max_h: float) -> void:
	var tex := walker_texture(cname)
	if tex == null:
		return
	var big := cname.begins_with("$") or cname.begins_with("!$")
	var pw := tex.get_width() / (3.0 if big else 12.0)
	var ph := tex.get_height() / (4.0 if big else 8.0)
	var sx := ((index % 4) * 3 + 1) * pw if not big else pw
	var sy := floorf(index / 4.0) * 4.0 * ph if not big else 0.0
	var k := maxf(1.0, floorf(max_h / ph))
	var dst := Rect2(foot.x - pw * k / 2.0, foot.y - ph * k, pw * k, ph * k)
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	ci.draw_texture_rect_region(tex, dst, Rect2(sx, sy, pw, ph))


# ---- 按键提示 ----

func _hints() -> Array:
	if scene.mode == "list":
		return [["确定", "放进这格"], ["Q / E", "翻页"], ["取消", "回到出战位"]]
	return [["确定", "选人"], ["← / →", "换格"], ["Q / E", "和旁边换位"], ["X", "还原"], ["取消", "完成"]]


# ---- 按键：出战位上 确定＝选人、X＝还原、取消＝完成；名单上照旧 ----

func input(event: InputEvent) -> bool:
	var sc := scene
	if sc.mode == "list":
		return _list_input(event)
	if sc.mode == "slot":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X:
			revert()
			return true
		if event.is_action_pressed("ui_cancel"):
			finish()
			return true
	return false


## 新名单的行数（旧 list_data 去掉末尾那行「离队」）
func roster_size() -> int:
	return scene.list_data().size() - 1


## 选人时的上下、翻页由新页自己管（小A核 P1-1）：旧页按 [0]+队伍+[0] 循环、按 14 行翻页，新页只画前 n 行、一屏 6 行
func _list_input(event: InputEvent) -> bool:
	var sc := scene
	var key := event as InputEventKey
	var pressed := key != null and key.pressed
	var n := roster_size()
	var d := 0
	if event.is_action_pressed("ui_down", true) or (pressed and key.physical_keycode == KEY_S):
		d = 1
	elif event.is_action_pressed("ui_up", true) or (pressed and key.physical_keycode == KEY_W):
		d = -1
	if d != 0:
		var before := sc.list_index
		sc.list_index = XMenu._move(sc.list_index, d, n, not event.is_echo())
		if sc.list_index != before:
			XSound.system(0)
		sc._refresh()
		return true
	var pg := XMenu.page_dir(event)
	if pg == 0 and pressed and key.echo and key.physical_keycode in [KEY_Q, KEY_E]:
		return true   # 按住 Q／E 的连发：不翻（同按一下翻一页），也别漏给旧页按 14 行翻
	if pg == 0 and (event.is_action_pressed("ui_page_up", true) or event.is_action_pressed("ui_page_down", true)):
		return true
	if pg != 0:
		var before2 := sc.list_index
		list.select(clampi(sc.list_index, 0, n - 1), false)
		list.page(pg)
		sc.list_index = clampi(list.index, 0, n - 1)
		if sc.list_index != before2:
			XSound.system(0)
		sc._refresh()
		return true
	return false


## 还原（旧指令窗「还原」）
func revert() -> void:
	XSound.system(1)
	XState.current.battle_slots = scene._former.duplicate()
	XState.current.rearrange_actors()
	scene._refresh()


## 完成并返回（旧指令窗「完成」）；出战栏全空／全员阵亡时拦住，提示原因、留在本页
func finish() -> void:
	if not scene.finish_enabled():
		XSound.system(3)
		XToast.show_text(T_FINISH_BLOCK, true)
		return
	XSound.system(2)
	XPartySkills.finish(XState.current)
	scene.closed.emit()


# ---- 点击 ----

func _on_slot_gui(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	slot_row.accept_event()
	for i in XState.MAX_BATTLE_MEMBERS:
		if slot_rect(i).has_point(event.position):
			var sc := scene
			if sc.mode == "list":
				sc.mode = "slot"   # 选人时点了别的格：回出战位、换到那一格
				sc.slot_index = i
				XSound.system(0)
				sc._refresh()
			else:
				sc._pick(i, XState.MAX_BATTLE_MEMBERS, "slot_index")
			return


func _on_list_index(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc.mode == "slot":
		sc.ok()   # 出战位上点名单的行：先进选人（同按确定），再落到点的那一行
	if sc.mode == "list" and i != sc.list_index:
		sc.list_index = i
		XSound.system(0)
	sc._refresh()


func _on_list_click(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc.mode == "slot":
		sc.ok()
		sc.list_index = i
		sc._refresh()
		return
	if sc.mode == "list" and i == sc.list_index:
		sc.ok()


func _on_card_button(_i: int) -> void:
	scene.ok()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if scene.mode == "slot":
			finish()
		else:
			scene.cancel()
		accept_event()
