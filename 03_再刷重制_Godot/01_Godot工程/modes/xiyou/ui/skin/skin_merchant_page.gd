class_name XSkinMerchantPage
extends XSkinMenuTreePage
## 【cc·天启篇·未经审查】T306 卡 N：深渊商人新布局（T254 3.18；版型一不画环＝卡 K 的层级菜单页 XSkinMenuTreePage 加几样本页专有的）。
## 每一层的选项、说明文字、抽取／吸取规则、回调（home／preview／tiers／_collection／absorb_*）全部还是 XMerchant29Page 原来的代码；
## 它的 choose 在新界面开着时把这一层交给 open_layer（旧窗不画），回调一行不改。
## 旧页 → 新页（T254 3.18 对应表）：
## - 标题两行（第二行是战利品点、剩余次数，或这一层的说明）→ 页名「深渊商人」／「特效吸取」＋面包屑（「深渊商人 · 路线名 › 抽取武器」）；第二行进列表标题右边小字。
## - 列表 16 行 → 中间列表（一屏 11 行，多的滚动，翻页件）；点数不够或次数用完的行变灰（旧 enabled），选中时右牌写还差多少、主按钮变灰。
## - 详情窗：行带装备（装备池、吸取要选的装备）→ 右牌标准详情牌（名字、品质、类型），说明行（RJO.HE.getDescParams）按牌高分页放；
##   其余行写这一行原来的 help 文字；没有 help 的（首页）右牌写这一层的标题几行；默认那句「确认选择；取消返回上一级。」放左块。
## - 翻页条「◀ 上一页 n／m 下一页 ▶」（翻的是右边详情）→ 挪到右牌底「‹ 上一页　详情 n / m　下一页 ›」：Q／E（同 PageUp／PageDown）、牌上滚轮、点两头都翻详情；
##   装备池那层按确定也是翻详情下一页；列表不翻页（点列表底的翻页件才翻列表）。只有 1 页时不画这一条。
## - 抽到提示走提示道；出错的字同时进右牌（flash，换行或换层清掉）。
## - 右上货币写战利品点（merchant 模式；这家店只收这个）。
## 新皮肤关着、或 XSkinWarehousePage.ENABLED＝false（T306 一个开关管三页）时 XMerchant29Page 不建这一页，旧页一行不变。

## 玩家可见文字（待小A 审）
const T_PAGE_MERCHANT := "深渊商人"
const T_PAGE_ABSORB := "特效吸取"
const T_DEFAULT_HELP := XMerchant29Page.DEFAULT_HELP
const T_PRIOR := "‹ 上一页"
const T_NEXT := "下一页 ›"
const T_DETAIL := "详情"
const T_DRAW := "抽取"
const T_SHORT_POINTS := "点数不够"
const T_SHORT_TIMES := "次数用完"
const T_UNAVAILABLE := "不可选"
const T_ERROR := "出错了"
const PAGER_H := 36.0
const LINE_H := 30.0
const HEAD_RESERVE := 132.0     # 牌头（图标、名字、小字）占掉的高，分页时先扣

var scene: XMerchant29Page
var list_right := ""
var flash := ""
var detail_page := 0
var detail_pages := 1
var pager_bar: Control
var _detail_key := ""
var _pages: Array = []


func _init(s: XMerchant29Page) -> void:
	scene = s
	super(T_PAGE_ABSORB if s.mode == "absorb" else T_PAGE_MERCHANT)
	name = "SkinMerchantPage"
	left_draw = _left_wax
	if s.mode != "absorb":
		currencies = [["战利品点", "0"]]


func _ready() -> void:
	super()
	list_panel.draw.connect(_draw_list_right)
	pager_bar = Control.new()
	pager_bar.name = "DetailPager"
	pager_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	pager_bar.visible = false
	pager_bar.draw.connect(_draw_pager)
	pager_bar.gui_input.connect(_on_pager_gui)
	card.add_child(pager_bar)
	card.gui_input.connect(_on_card_wheel)


# ---- 换一层：scene.choose 交过来 ----

## crumb：这一层的面包屑（含根）；info：原来标题的几行（第 2 行进列表标题右边小字）
func open_layer(list_rows: Array, ok_cb: Callable, cancel_cb: Callable, info_lines: Array, crumb_parts: Array) -> void:
	flash = ""
	list_right = str(info_lines[1]) if info_lines.size() > 1 else ""
	_refresh_currency()
	open(list_rows, ok_cb, cancel_cb, info_lines, {
		"crumb": crumb_parts, "card_for": _card_for, "card_button": _on_button, "list_title": str(crumb_parts.back()),
	})
	list.right2_w = 0.0


func _refresh_currency() -> void:
	if scene.mode == "absorb":
		return
	var s := XState.current
	var cur := XMerchant29Page._run_of()
	var key := str(cur.get("identity", {}).get("key", ""))
	currencies = [["战利品点", XSkinTemplatePage._group(XAbyssMerchant.balance(s, key))]]


## 出错：提示字同时进右牌（旧 set_text）
func show_error(t: String) -> void:
	flash = t
	sync()


func _on_list_index(i: int) -> void:
	flash = ""
	detail_page = 0
	super(i)


# ---- 右牌 ----

func _card_for(r: Dictionary) -> Dictionary:
	if flash != "":
		detail_pages = 1
		return {"title": T_ERROR, "title_color": XUiSkin.DOWN, "sections": [{"title": "", "rows": [{"text": flash, "color": XUiSkin.DOWN}]}], "buttons": []}
	var key := _row_key(r)
	if key != _detail_key:
		_detail_key = key
		detail_page = 0
	if r.has("item"):
		return _equip_card(r.item)
	detail_pages = 1
	var help := str(r.get("help", ""))
	if help == "":
		return {}   # 回落到这一层的标题几行（首页：路线名、战利品点）
	var d := {"title": str(r.get("text", r.get("label", ""))), "sections": [{"title": "说明", "rows": [{"text": help, "color": XUiSkin.TEXT_2}]}], "buttons": []}
	_add_draw_button(d, r)
	return d


static func _row_key(r: Dictionary) -> String:
	var it: Dictionary = r.get("item", {})
	return "%s|%s|%s" % [str(r.get("text", r.get("label", ""))), str(it.get("id", "")), str(it.get("note", "")).hash()]


func _equip_card(e: Dictionary) -> Dictionary:
	var ev := XAffixAbsorb.view(e)   # 池里是数据库原件，没有吸取；absorbView 后再读说明行（同旧 set_equipment）
	var crec := ev
	if ev.has("etypeId") and not ev.has("itypeId") and not XItemMarks.is_gear(ev):
		crec = ev.duplicate()   # 池里的装备是模板记录（没有 kind）：按装备排牌，不当物品（同商店购买列表）
		crec["kind"] = "weapon" if ev.has("wtypeId") else "armor"
		crec["base"] = int(ev.get("id", 0))
	var d := XSkinItemPage.card_data(crec)
	d.title = str(d.title).replace(XItemMarks.LOCK, "").replace(XItemMarks.TOP, "").strip_edges()
	d.subtitle = " · ".join(Array(str(d.subtitle).split(" · ", false)).filter(func(x): return not str(x).begins_with("持有")))
	var rows := XSkinTemplatePage.help_rows(XHelpCard.desc_params(ev, 1 if XHelpCard.kind_of(ev) == "weapon" else 2))
	_pages = pack_pages(XSkinTemplatePage.help_sections(rows), _page_budget(), _text_w())
	detail_pages = maxi(_pages.size(), 1)
	detail_page = clampi(detail_page, 0, detail_pages - 1)
	d.sections = _pages[detail_page] if not _pages.is_empty() else []
	d.buttons = []
	return d


func _page_budget() -> float:
	var h := card.size.y if card != null and card.size.y > 0.0 else 596.0
	return maxf(h - HEAD_RESERVE - PAGER_H - 16.0 - card.pad * 2.0, LINE_H * 3.0)


func _text_w() -> float:
	var w := card.size.x if card != null and card.size.x > 0.0 else right_w
	return maxf(w - card.pad * 2.0, 120.0)


## 把分节的行按牌高分页：每行占「折几行 × LINE_H」，分节标题占 36；放不下就换页（新页补回分节标题）。每页至少放一行。
static func pack_pages(secs: Array, budget: float, text_w: float) -> Array:
	var f := XUiSkin.font("body")
	var fs := XUiSkin.fs(XUiSkin.FS_AUX)
	var pages := []
	var cur := []
	var used := 0.0
	for sec in secs:
		var title := str(sec.get("title", ""))
		var head := 36.0 if title != "" else 0.0
		var rows_here := []
		for r in sec.rows:
			var w := f.get_string_size(str(r.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var cost := maxf(1.0, ceilf(w / text_w)) * LINE_H
			var extra := head if rows_here.is_empty() else 0.0
			if used + extra + cost > budget and (not cur.is_empty() or not rows_here.is_empty()):
				if not rows_here.is_empty():
					cur.append({"title": title, "rows": rows_here})
				pages.append(cur)
				cur = []
				rows_here = []
				used = 0.0
				extra = head
			used += extra + cost
			rows_here.append(r)
		if not rows_here.is_empty():
			cur.append({"title": title, "rows": rows_here})
	if not cur.is_empty():
		pages.append(cur)
	return pages


## 抽取类的行（带 cost）：右牌主按钮「抽取」；点数不够／次数用完变灰、牌上橙字写还差多少
func _add_draw_button(d: Dictionary, r: Dictionary) -> void:
	if not r.has("cost"):
		return
	var s := XState.current
	var cur := XMerchant29Page._run_of()
	var bal := XAbyssMerchant.balance(s, str(cur.get("identity", {}).get("key", "")))
	var cost := int(r.cost)
	var used_up := int(cur.get("used", 0)) >= int(XAbyssMerchant.config().get("visitLimit", 0))
	var short := cost - bal
	var rows: Array = d.sections
	if short > 0:
		rows.append({"title": "", "rows": [{"text": "还差 %d 点" % short, "color": XUiSkin.DOWN}]})
	elif used_up:
		rows.append({"title": "", "rows": [{"text": "这次来访的抽取次数用完了", "color": XUiSkin.DOWN}]})
	var blocked: bool = short > 0 or used_up or r.get("enabled", true) == false
	d.buttons = [{"text": (T_SHORT_POINTS if short > 0 else (T_SHORT_TIMES if used_up else T_UNAVAILABLE)) if blocked else T_DRAW, "primary": true, "disabled": blocked}]


func _on_button(_i: int, _row: Dictionary) -> void:
	ok()


# ---- 翻详情 ----

func page_text() -> String:
	return "%s %d / %d" % [T_DETAIL, detail_page + 1, detail_pages]


## turn29：翻详情（Q／E、滚轮、点两头、装备池那层按确定）；到头不动
func turn(d: int) -> void:
	var np := clampi(detail_page + d, 0, detail_pages - 1)
	if np == detail_page:
		return
	detail_page = np
	sync()


## Q／E 翻详情（旧 PageUp／PageDown 同键）；列表不翻页
func page(d: int) -> void:
	turn(d)


func _hints() -> Array:
	var h := super()
	if dialog == null and detail_pages > 1:
		h = h.duplicate()
		h.insert(1, ["Q / E", "翻详情"])
	return h


func _place_targets() -> void:
	super()
	if card == null or pager_bar == null:
		return
	var show := detail_pages > 1
	pager_bar.visible = show
	if not show:
		return
	card.reserve_bottom += PAGER_H + XUiSkin.GRID
	var bottom := card.size.y - card.pad - (XSkinCard.BUTTON_H + XUiSkin.GRID if not card.buttons.is_empty() else 0.0)
	pager_bar.position = Vector2(card.pad, bottom - PAGER_H)
	pager_bar.size = Vector2(card.size.x - card.pad * 2, PAGER_H)
	pager_bar.queue_redraw()


func sync() -> void:
	super()
	if pager_bar != null:   # 翻页数在 card_for 里才算出，牌排好后再按页数摆翻页条
		var was := pager_bar.visible
		_place_targets()
		if was != pager_bar.visible or pager_bar.visible:
			card.queue_redraw()


func _draw_pager() -> void:
	var body := XUiSkin.font("body")
	var fs := XUiSkin.fs(XUiSkin.FS_AUX)
	var w := pager_bar.size.x
	var base := PAGER_H / 2.0 + fs * 0.36
	var can_prior := detail_page > 0
	var can_next := detail_page < detail_pages - 1
	XUiSkin.ds(pager_bar, body, Vector2(0, base), T_PRIOR, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT if can_prior else XUiSkin.TEXT_3)
	var nw := body.get_string_size(T_NEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(pager_bar, body, Vector2(w - nw, base), T_NEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT if can_next else XUiSkin.TEXT_3)
	var t := page_text()
	var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(pager_bar, body, Vector2((w - tw) / 2.0, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.GOLD_LIGHT)


## 点两头翻页：左半往前、右半往后（同旧翻页条）
func _on_pager_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		turn(-1 if event.position.x < pager_bar.size.x / 2.0 else 1)
		pager_bar.accept_event()


## 牌上滚轮翻详情（同旧：详情上滚轮）
func _on_card_wheel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			turn(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			turn(-1)


# ---- 画：列表标题右边小字（旧标题第二行）；左块一枚暗紫色蜡＋默认帮助句 ----

func _draw_list_right() -> void:
	if list_right == "":
		return
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX
	var maxw := list_panel.size.x * 0.6
	var fit := XSkinList.fit_text(body, list_right, maxw, fs, 15)
	var tw := body.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
	XUiSkin.ds(list_panel, body, Vector2(list_panel.size.x - XUiSkin.PAD - 8 - tw, XUiSkin.PAD + 20), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT_2)


func _left_wax(ctrl: Control, _row: Dictionary) -> void:
	var lb := ctrl.size
	var c := Vector2(lb.x / 2.0, lb.y / 2.0 - 40.0)
	ctrl.draw_circle(c + Vector2(0, 6), 52.0, Color(0, 0, 0, 0.35))
	ctrl.draw_circle(c, 50.0, Color("#3b2457"))
	ctrl.draw_circle(c, 40.0, Color("#4a2d6b"))
	ctrl.draw_arc(c, 40.0, 0, TAU, 48, Color("#6d4a94"), 2.0, true)
	ctrl.draw_arc(c + Vector2(-6, -6), 28.0, PI * 1.05, PI * 1.55, 16, Color(1, 1, 1, 0.16), 3.0, true)
	var body := XUiSkin.font("body")
	var fs := XUiSkin.fs(XUiSkin.FS_AUX)
	var fit := XSkinList.fit_text(body, T_DEFAULT_HELP, lb.x - 16.0, fs, 15)
	var tw := body.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
	XUiSkin.ds(ctrl, body, Vector2((lb.x - tw) / 2.0, c.y + 90.0), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT_2)
