class_name XSkinMainMenu
extends Control
## 【cc·天启篇·未经审查】新界面第 1A 批：主菜单（盘点清册 #21；界面风格提案 v0.7 样稿 menu、README 第一节「主菜单」）。
## 只在 XUiSkin.on() 时由 XMenu._ready 建（XMenu.skin）；关着时 XMenu 走旧三个窗口，这个文件一行不跑。
## 布局（XSkinLayout 三块，横屏铺满）：
## - 左块：环形导航（XSkinRingNav），一组一个球（XUiSkin.GROUPS 里当前存档看得到的组，天启篇 6 组），环心是当前角色的圆头像；
## - 中块：分组子项列表——没选中的组收成一行（组名＋子项名），选中的组展开：组名（旧金）＋每个子项一行（行高 56、名字＋一句话说明）；
##   只剩一项的组（物品、装备）不展开，组那一行就是子项，确定直接进；
## - 右块：本局条（第几层 · 难度 · 哪条线；七印进度：首通几印）＋队伍条（XSkinPartyStrip）；
## - 顶上：页名「菜单」、货币（精魂；能进七印祭坛的档另显示印屑）；右下：按键提示（给右下角版本号让位）。
## 操作（TWO_LEVEL＝false，旧一级）：上下在子项间走（到组头尾跨到上／下一组）；左右或 Q／E 换组；确定进入；取消回地图。
## 两级操作（TWO_LEVEL＝true 默认，Kyo 11-15「先选大类，移到哪个大类右边显示其子类，大类确认后进入子类菜单」）：
## - 第一级（level 0）：焦点在环上，方向键／Q E／点环在大类间走；中块只列当前大类的子项（预览，不画选中条，同屏一个焦点）；
##   只一项的大类（物品、装备）中块写一句说明，确定直接打开；确定＝进第二级（记得的子项，否则第一项）；取消回地图；
## - 第二级（level 1）：上下在本大类子项间走（循环）、Q／E 换大类（留在第二级、第一项）；确定打开；取消回环上；
## - 触屏：点环上大类＝选中并进第二级（只一项的直接打开）；点中块子项＝直接打开；
## - 记住上次的大类和子项（按键名，_mem），重开菜单停在那个大类的第一级。
## 技能、装备、状态先到队伍条选人（XMenu._mode＝"actor"），确定进页、取消回列表。
## 打开各页、可不可用都走 XMenu（run_command／open_actor_page／symbol_enabled），和旧菜单是同一套。

const TITLE := "菜单"
const ROW_GROUP := 46.0      # 收起的组一行
const ROW_HEADER := 46.0     # 展开组的组名行
const ROW_ITEM := float(XUiSkin.ROW_H_MENU)   # 子项 56
const LEFT_W := 416.0
const RIGHT_W := 360.0
const RUN_H := 96.0          # 本局条（有七印行）
const RUN_H_SHORT := 60.0    # 本局条（没有七印行）
const SEALS := 7
const ACTOR_CMDS := ["skill", "equip", "status"]

var host: XMenu
var layout: XSkinLayout
var ring: XSkinRingNav
var face: Control
var pane: Panel
var bar: XSkinSelectBar
var text_layer: Control
## T024 选中放大：选中子项的名字放大（行高 56、选中条不变；说明小字跟着往右让）
var item_scale: XSkinSelScale
var run_panel: Control
var party: XSkinPartyStrip
var hints: XSkinKeyHints
var top: Control
var groups: Array = []
## 当前组、组里第几项
var gi := 0
var ii := 0
var party_top := 0
var _rows: Array = []
var _wide_token: Node
## 两级操作开关（cc/ui-skin-p1fix 追加，O-486）：false＝回旧的一级分组列表
static var TWO_LEVEL := true
## 第几级：0 环上选大类、1 中块选子项（TWO_LEVEL 时才用）
var level := 0
## 上次停在哪：{g: 组键, items: {组键: 子项键}}（跨次打开菜单；每个大类各记各的子项）
static var _mem := {}
const NOTE_H := 56.0
## 右栏队伍框加助力位卡（Kyo 11-15「不是还有助力位置吗」，O-487）：天启篇第 5 张卡＝出战栏第 5 格（XState.helper），
## 空着写「助力位 · 空」；队伍框拉到和中间栏底边对齐、卡按高度均分（最高 ROW_MAX）。false＝旧的随人数排、框高随内容。
static var HELPER_CARD := true
const PARTY_ROW_MAX := 120.0


func _ready() -> void:
	add_to_group(XUiSkin.FULLSCREEN_GROUP)   # 收口批：开着时收起虚拟摇杆／AB 键
	back_button = XSkinBackButton.attach(self)
	if back_button != null:
		back_button.z_index = 10   # 在后加的底图、面板之上
	name = "SkinMainMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = XUiSkin.theme()
	layout = XSkinLayout.new()
	layout.left_w = LEFT_W
	layout.right_w = RIGHT_W
	add_child(layout)
	groups = XUiSkin.visible_groups(XUiSkin.GROUPS, _state())
	_restore_mem()
	# 左块：环
	ring = XSkinRingNav.new()
	ring.radius = 160
	ring.orb_radius = 33
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.set_items(groups.map(func(g): return XSkinRingNav.group_item(g)))
	ring.select(gi, false)
	layout.left.add_child(ring)
	face = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.draw.connect(_draw_face)
	_ensure_sprite_layer()
	ring.add_child(face)
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(func(_i):
		if host != null and host._mode == "command":
			if TWO_LEVEL:
				enter()
			else:
				activate())
	# 中块：分组子项
	pane = Panel.new()
	pane.name = "Groups"
	pane.mouse_filter = Control.MOUSE_FILTER_STOP
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.center.add_child(pane)
	bar = XSkinSelectBar.new()
	pane.add_child(bar)
	text_layer = Control.new()   # 文字在选中条上面（选中条的底光不压字）
	text_layer.name = "Text"
	text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane.add_child(text_layer)
	text_layer.draw.connect(_draw_pane)
	item_scale = XSkinSelScale.attach(text_layer)
	pane.gui_input.connect(_pane_input)
	pane.resized.connect(func(): _place_bar(true))
	# 右块：本局条＋队伍条
	run_panel = Control.new()
	run_panel.name = "Run"
	run_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_panel.draw.connect(_draw_run)
	layout.right.add_child(run_panel)
	party = XSkinPartyStrip.new()
	party.title = "队伍"
	layout.right.add_child(party)
	party.activated.connect(_on_party_activated)
	party.index_changed.connect(_on_party_index)
	# 顶上、右下
	top = Control.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.draw.connect(_draw_top)
	add_child(top)
	hints = XSkinKeyHints.new()
	add_child(hints)
	resized.connect(_place)
	get_viewport().size_changed.connect(_place)
	visibility_changed.connect(_sync_wide)
	_sync_wide()
	refresh()


func _state() -> XState:
	return XState.current


## 页面在显示时让窗口横向铺满（XSkinLayout.request_wide）；进子页（旧布局，按 1280×720 排）时还原
func _sync_wide() -> void:
	if is_visible_in_tree() and is_inside_tree():
		if _wide_token == null:
			_wide_token = Node.new()
			_wide_token.name = "WideToken"
			add_child(_wide_token)
			XSkinLayout.request_wide(_wide_token)
	elif _wide_token != null:
		_wide_token.queue_free()
		remove_child(_wide_token)
		_wide_token = null


## ---- 数据 ----

func current_group() -> Dictionary:
	return groups[gi] if gi >= 0 and gi < groups.size() else {}


func group_items(g: Dictionary) -> Array:
	return g.get("items", [])


func current_item() -> Dictionary:
	var items := group_items(current_group())
	return items[ii] if ii >= 0 and ii < items.size() else {}


func item_enabled(it: Dictionary) -> bool:
	return host != null and host.symbol_enabled(str(it.get("cmd", "")))


## 本局条第一行：第几层 · 难度 · 哪条线（天启篇存档才有难度和线；变量 20＝现在要打的层）
static func run_text(s: XState) -> String:
	if s == null:
		return ""
	var parts := ["第 %d 层" % maxi(1, int(s.variable(20)))]
	var d := XTianqi.difficulty_of(s)
	if not d.is_empty():
		parts.append(str(d.name))
	var line := XTianqi.line_info(XTianqi.line_of(s))
	if not line.is_empty():
		parts.append(str(line.name) + "线")
	return " · ".join(parts)


## 七印进度：每印 2＝首通过 Boss、1＝揭开了没打过、0＝没揭开（按祭坛的印序）；不能进祭坛的档返回 []
static func seal_states(s: XState) -> Array:
	if s == null or not XTianqiQiyin.allowed(s):
		return []
	var cleared: Dictionary = XTianqiQiyin.progress(s).drop.get("first_clear", {})
	var out := []
	for k in XTianqiQiyin.seal_keys():
		out.append(2 if bool(cleared.get(k, false)) else (1 if XTianqiQiyin.unlocked(s, k) else 0))
	return out


static func seals_cleared(states: Array) -> int:
	return states.count(2)


## 货币：[[名字, 数值文字]]；精魂一直有，印屑只在能进七印祭坛的档
static func currencies(s: XState) -> Array:
	if s == null:
		return []
	var out := [["精魂", XMenu._group(s.gold)]]
	if XTianqiQiyin.allowed(s):
		out.append([str(XTianqiQiyin.data().get("shards_name", "印屑")), XMenu._group(XTianqiQiyin.shards(s))])
	return out


## ---- 刷新与摆放 ----

func refresh() -> void:
	if host == null:
		return
	gi = clampi(gi, 0, maxi(groups.size() - 1, 0))
	ii = clampi(ii, 0, maxi(group_items(current_group()).size() - 1, 0))
	if ring.index != gi:
		ring.select(gi, false)
	var members := host._members()
	var actor_mode := host._mode == "actor"
	party.selectable = actor_mode
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE if actor_mode else Control.MOUSE_FILTER_STOP
	var order := party_order()
	party.row_height = party_row_height(order.size())
	var rows := party_rows()
	if actor_mode:
		var ai := maxi(order.find(clampi(host._actor_index, 0, maxi(members.size() - 1, 0))), 0)
		if ai < party_top:
			party_top = ai
		elif ai >= party_top + rows:
			party_top = ai - rows + 1
	party_top = clampi(party_top, 0, maxi(order.size() - rows, 0))
	var helper_i := helper_index()
	party.set_members(order.slice(party_top, party_top + rows).map(func(k): return _card(k, helper_i)))
	party.index = (order.find(host._actor_index) - party_top) if actor_mode else -1
	party._place_bar(true)
	party.queue_redraw()
	hints.set_hints(hint_list())
	_place()
	_place_bar(false)
	text_layer.queue_redraw()
	run_panel.queue_redraw()
	face.queue_redraw()
	top.queue_redraw()


## 底部按键提示：随选人／层级变
func hint_list() -> Array:
	if host != null and host._mode == "actor":
		return [["确定", "进入"], ["取消", "返回"]]
	if TWO_LEVEL and level == 1:
		return [["确定", "打开"], ["取消", "返回"], ["Q / E", "换组"]]
	return [["确定", "进入"], ["取消", "回地图"], ["Q / E", "换组"]]


func _restore_mem() -> void:
	if not TWO_LEVEL or _mem.is_empty():
		return
	for k in groups.size():
		if str(groups[k].key) == str(_mem.get("g", "")):
			gi = k
			ii = mem_index(k)
			return


## 第 g 组记住的子项（没记过、或记的那项现在藏了：0）
func mem_index(g: int) -> int:
	if g < 0 or g >= groups.size():
		return 0
	var key := str((_mem.get("items", {}) as Dictionary).get(str(groups[g].key), ""))
	var items := group_items(groups[g])
	for j in items.size():
		if str(items[j].key) == key:
			return j
	return 0


## 记下现在的大类；第二级时（或打开时）连子项一起记
func _remember() -> void:
	var g := current_group()
	if g.is_empty():
		return
	if not _mem.has("items"):
		_mem["items"] = {}
	_mem["g"] = str(g.key)
	if level == 1 or group_items(g).size() <= 1:
		_mem.items[str(g.key)] = str(current_item().get("key", ""))


## 第一级 → 第二级（只一项的大类直接打开）
func enter() -> void:
	if host == null or current_group().is_empty():
		return
	if group_items(current_group()).size() <= 1:
		ii = 0
		activate()
		return
	if level == 0:
		XSound.system(1)
		level = 1
		_remember()
		refresh()


## 第二级 → 第一级
func leave() -> void:
	if level == 1:
		XSound.system(2)
		level = 0
		refresh()


## 队伍条最多放几行（右块高减本局条）
func party_rows() -> int:
	return maxi(1, floori(party_space() / party.row_height + 0.001))


## 队伍条里放卡的高度（右块高减本局条、标题）
func party_space() -> float:
	return (layout.rects().right as Rect2).size.y - run_height() - XUiSkin.PANEL_GAP - XSkinPartyStrip.TITLE_H - 8


## 有没有助力位卡：开关开、天启篇存档
func helper_card_on() -> bool:
	return HELPER_CARD and XTianqi.active(_state())


## 助力位上的人在 host._members() 里第几个（没有：-1）
func helper_index() -> int:
	if not helper_card_on():
		return -1
	var h := _state().helper()
	return host._members().find(h) if h != null else -1


## 队伍条的显示顺序：host._members() 的下标；有助力位卡时助力位的人挪到最后，没人时末尾放 -1（空位占位）
func party_order() -> Array:
	var n := host._members().size()
	var out := range(n)
	if not helper_card_on():
		return out
	var h := helper_index()
	if h >= 0:
		out.erase(h)
		out.append(h)
	else:
		out.append(-1)
	return out


## 卡高：有助力位卡时把队伍框填到中间栏底边（均分，最高 PARTY_ROW_MAX）；否则照旧 60
func party_row_height(n: int) -> float:
	if not helper_card_on() or n <= 0:
		return float(XUiSkin.MEMBER_H)
	var fit := floori(party_space() / XUiSkin.MEMBER_H)
	var shown := clampi(n, 1, maxi(fit, 1))
	return clampf(floorf(party_space() / shown), XUiSkin.MEMBER_H, PARTY_ROW_MAX)


func _card(k: int, helper_i: int) -> Dictionary:
	if k < 0:
		return {"name": "助力位 · 空", "placeholder": true, "helper": true}
	var d := XSkinPartyStrip.from_actor(host._members()[k])
	if k == helper_i:
		d["helper"] = true
	return d


func run_height() -> float:
	return RUN_H if not seal_states(_state()).is_empty() else RUN_H_SHORT


func _place() -> void:
	if layout == null:
		return
	layout.relayout()
	var rh := run_height()
	run_panel.position = Vector2.ZERO
	run_panel.size = Vector2(RIGHT_W, rh)
	party.position = Vector2(0, rh + XUiSkin.PANEL_GAP)
	party.size = Vector2(RIGHT_W, party.custom_minimum_size.y)
	if helper_card_on():   # 助力位卡：框底边对齐中间栏（卡少时卡在上、框照样拉齐）
		party.size.y = maxf(party.size.y, (layout.rects().right as Rect2).size.y - party.position.y)
	var view := layout.view_size()
	hints.place(view)
	_layout_rows()
	_place_bar(true)
	top.queue_redraw()


## 按键提示的右边：ui-skin-3b 起统一在 XSkinKeyHints.right_edge（place() 自带让位）；留着这个名字给旧调用
static func hint_right(view: Vector2) -> float:
	return XSkinKeyHints.right_edge(view)


## 中块各行：[{kind: group／header／item／note, g, i, rect}]
func _layout_rows() -> void:
	_rows = []
	if TWO_LEVEL:
		_layout_rows_two()
		return
	var h := pane.size.y - XUiSkin.PAD * 2
	var fixed := 0.0
	var collapsed := 0
	for k in groups.size():
		var n := group_items(groups[k]).size()
		if k != gi:
			collapsed += 1
		elif n <= 1:
			fixed += ROW_ITEM
		else:
			fixed += ROW_HEADER + ROW_ITEM * n
	var gh := ROW_GROUP
	if collapsed > 0:
		gh = clampf((h - fixed) / collapsed, 30.0, ROW_GROUP)
	var y := float(XUiSkin.PAD)
	var w := pane.size.x - row_x() - 10.0
	for k in groups.size():
		var n := group_items(groups[k]).size()
		if k != gi:
			_rows.append({"kind": "group", "g": k, "i": 0, "rect": Rect2(row_x(), y, w, gh)})
			y += gh
		elif n <= 1:
			_rows.append({"kind": "item", "g": k, "i": 0, "rect": Rect2(row_x(), y, w, ROW_ITEM)})
			y += ROW_ITEM
		else:
			_rows.append({"kind": "header", "g": k, "i": -1, "rect": Rect2(row_x(), y, w, ROW_HEADER)})
			y += ROW_HEADER
			for i in n:
				_rows.append({"kind": "item", "g": k, "i": i, "rect": Rect2(row_x(), y, w, ROW_ITEM)})
				y += ROW_ITEM


## 行左边：第一期正式美术的选中条箭头外置在行左外 22px，行往里收到 28，箭头收在烟底面板里（小A核 P2-1）；否则照旧 10
static func row_x() -> float:
	return 28.0 if XSkinArt.select_on() else 10.0


## 两级：只列当前大类——组名行＋子项；只一项的大类是组名行＋一句说明（note，点它／确定直接打开）
func _layout_rows_two() -> void:
	if current_group().is_empty():
		return
	var y := float(XUiSkin.PAD)
	var w := pane.size.x - row_x() - 10.0
	var n := group_items(current_group()).size()
	_rows.append({"kind": "header", "g": gi, "i": -1, "rect": Rect2(row_x(), y, w, ROW_HEADER)})
	y += ROW_HEADER
	if n <= 1:
		_rows.append({"kind": "note", "g": gi, "i": 0, "rect": Rect2(row_x(), y, w, NOTE_H)})
		return
	for i in n:
		_rows.append({"kind": "item", "g": gi, "i": i, "rect": Rect2(row_x(), y, w, ROW_ITEM)})
		y += ROW_ITEM


func rows() -> Array:
	return _rows


func selected_row_rect() -> Rect2:
	for r in _rows:
		if r.kind == "item" and r.g == gi and r.i == ii:
			return r.rect
	return Rect2()


func _place_bar(instant: bool) -> void:
	if bar == null:
		return
	var r := selected_row_rect()
	bar.visible = r.size != Vector2.ZERO and (not TWO_LEVEL or level == 1)
	if bar.visible:
		bar.move_to(r, instant)


## ---- 操作 ----

## 换组（环、列表同步）；d＝±1，到头循环
func step_group(d: int) -> void:
	if groups.size() <= 1:
		return
	var ng := posmod(gi + d, groups.size())
	_set_group(ng, mem_index(ng) if TWO_LEVEL else 0)


func _set_group(g: int, i: int) -> void:
	var changed := g != gi or i != ii
	gi = g
	ii = i
	if ring.index != gi:
		ring.select(gi)
	if changed:
		XSound.system(0)
	if TWO_LEVEL:
		if level == 1 and group_items(current_group()).size() <= 1:   # 小A核 P2-1：切到单项组不留在「幽灵第二级」
			level = 0
		_remember()
		hints.set_hints(hint_list())
	_layout_rows()
	_place_bar(false)
	text_layer.queue_redraw()


## 上下走一项；到组头尾跨到上／下一组（上一组落在最后一项）；wrap＝false 时（按住连发）到整个列表头尾停住
func move_item(d: int, wrap := true) -> void:
	var n := group_items(current_group()).size()
	var i := ii + d
	if i >= 0 and i < n:
		_set_group(gi, i)
		return
	var g := gi + d
	if g < 0 or g >= groups.size():
		if not wrap:
			return
		g = posmod(g, groups.size())
	_set_group(g, 0 if d > 0 else group_items(groups[g]).size() - 1)


## 确定当前子项
func activate() -> void:
	var it := current_item()
	if it.is_empty() or host == null:
		return
	if not item_enabled(it):
		XSound.system(3)
		return
	XSound.system(1)
	if TWO_LEVEL:
		level = 1 if group_items(current_group()).size() > 1 else level
		_remember()
	host.run_command(str(it.cmd))


func _on_ring_changed(i: int) -> void:
	if host != null and host._mode != "command":  # 选人时环不收鼠标（refresh 里关了），这里再兜一次：转回当前组
		ring.select(gi, false)
		return
	if i != gi:
		_set_group(i, mem_index(i) if TWO_LEVEL else 0)
		if TWO_LEVEL:   # 点环上别的大类＝选中并进第二级（只一项的直接打开）
			level = 0
			enter()


## 收起的组那一行右边：多项组列子项名；只一项的组写那一项的说明（不重复组名，小A核查 P2）
static func collapsed_text(g: Dictionary) -> String:
	var items: Array = g.get("items", [])
	if items.size() == 1:
		return str(items[0].get("desc", ""))
	return "　".join(items.map(func(it): return str(it.name)))


func _on_party_index(i: int) -> void:
	if host != null and host._mode == "actor":
		var k: int = party_order()[party_top + i] if party_top + i < party_order().size() else -1
		if k < 0:   # 空的助力位不能选：退回原来那张
			refresh()
			return
		host._actor_index = k
		XSound.system(0)
		face.queue_redraw()


func _on_party_activated(i: int) -> void:
	if host == null or host._mode != "actor":
		return
	var k: int = party_order()[party_top + i] if party_top + i < party_order().size() else -1
	if k < 0:
		XSound.system(3)
		return
	host._actor_index = k
	XSound.system(1)
	host.open_actor_page(host._pending, host._actor_index)


func _pane_input(event: InputEvent) -> void:
	if host == null or host._mode != "command":
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_item(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1, false)
			pane.accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for r in _rows:
			if (r.rect as Rect2).has_point(mb.position):
				bar.press()
				if TWO_LEVEL:   # 点子项（或单项大类的说明行）＝直接打开；点组名行不做事
					if r.kind == "item" or r.kind == "note":
						_set_group(r.g, r.i)
						if r.kind == "item":
							level = 1
						activate()
						refresh()
				elif r.kind == "group" or r.kind == "header":
					if r.g != gi:
						_set_group(r.g, 0)
				elif r.g == gi and r.i == ii:
					activate()
				else:
					_set_group(r.g, r.i)
				pane.accept_event()
				return


## 鼠标右键／触屏两指（Platform.two_finger_cancel 发的就是右键）＝取消（小A核 P1-1）：
## 子控件 ring／pane／party 都是 MOUSE_FILTER_STOP，右键到不了 XMenu，这里在 GUI 之前接住
func _input(event: InputEvent) -> void:
	if host == null or host._mode == "page" or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		XKeyMap.handled(self)
		cancel()


## 取消一步：选人→回列表；第二级→回环上；第一级（或旧一级）→回地图
func cancel() -> void:
	if host == null:
		return
	if host._mode == "actor":
		XSound.system(2)
		host._mode = "command"
		refresh()
	elif TWO_LEVEL and level == 1:
		leave()
	else:
		host._cancel()


func _unhandled_input(event: InputEvent) -> void:
	if host == null or host._mode == "page" or not is_visible_in_tree():
		return
	if host._mode == "actor":
		_actor_input(event)
		return
	if TWO_LEVEL:
		_two_level_input(event)
		return
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		host._cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		activate()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		move_item(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		XKeyMap.handled(self)
		step_group(1 if event.is_action_pressed("ui_right", true) else -1)
	elif XMenu.page_dir(event) != 0:
		XKeyMap.handled(self)
		step_group(XMenu.page_dir(event))


func _two_level_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		if level == 1:
			leave()
		else:
			host._cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		if level == 1:
			activate()
		else:
			enter()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		if level == 1:
			var n := group_items(current_group()).size()
			if n > 1 and (not event.is_echo() or (ii + d >= 0 and ii + d < n)):
				_set_group(gi, posmod(ii + d, n))
		else:
			step_group(d)
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		XKeyMap.handled(self)
		if level == 0:
			step_group(1 if event.is_action_pressed("ui_right", true) else -1)
	elif XMenu.page_dir(event) != 0:
		XKeyMap.handled(self)
		step_group(XMenu.page_dir(event))


func _actor_input(event: InputEvent) -> void:
	var members := host._members()
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		XSound.system(2)
		host._mode = "command"
		refresh()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		XSound.system(1)
		host.open_actor_page(host._pending, host._actor_index)
	elif (event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true)) and not members.is_empty():
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		var before := host._actor_index
		# 按队伍条的显示顺序走（助力位的人在最后；空的助力位跳过）
		var order := party_order().filter(func(k): return k >= 0)
		var pos := XMenu._move(maxi(order.find(host._actor_index), 0), d, order.size(), not event.is_echo())
		host._actor_index = order[pos]
		if before != host._actor_index:
			XSound.system(0)
		refresh()


## ---- 画 ----

func _draw_pane() -> void:
	var body := XUiSkin.font("body")
	var head := XUiSkin.font("title")
	item_scale.sel("%d:%d" % [gi, ii] if not TWO_LEVEL or level == 1 else null)
	for r in _rows:
		var rect: Rect2 = r.rect
		var g: Dictionary = groups[r.g]
		var base := rect.position.y + rect.size.y / 2.0
		var x := rect.position.x + 16.0
		match str(r.kind):
			"group":
				var nm := str(g.name)
				text_layer.draw_string(body, Vector2(x, base + XUiSkin.FS_LIST * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST, XUiSkin.TEXT)
				var sx := x + maxf(60.0, body.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST).x + 16.0)
				text_layer.draw_string(body, Vector2(sx, base + 15 * 0.36), collapsed_text(g), HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - sx - 8.0, 15, XUiSkin.TEXT_2)
			"header":
				text_layer.draw_string(head, Vector2(x, base + 21 * 0.36), str(g.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD)
			"note":
				var it0: Dictionary = group_items(g)[0]
				var ok0 := item_enabled(it0)
				text_layer.draw_string(body, Vector2(x + 8.0, base + 17 * 0.36), "%s。确定直接打开" % str(it0.get("desc", it0.name)), HORIZONTAL_ALIGNMENT_LEFT,
					rect.size.x - 32.0, 17, XUiSkin.TEXT_2 if ok0 else XUiSkin.TEXT_3)
			"item":
				var it: Dictionary = group_items(g)[r.i]
				var on: bool = r.g == gi and r.i == ii and (not TWO_LEVEL or level == 1)
				var ok := item_enabled(it)
				var ix := x + (8.0 if group_items(g).size() > 1 else 0.0)
				var fs := XSkinSelScale.fs(XUiSkin.FS_LIST_MAX, item_scale.k("%d:%d" % [r.g, r.i]), floori(rect.size.y * 0.62))
				var nm := str(it.name)
				text_layer.draw_string(head if on else body, Vector2(ix, base + fs * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					XUiSkin.TEXT_3 if not ok else (Color.WHITE if on else XUiSkin.TEXT))
				var nw := (head if on else body).get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var desc := str(it.get("desc", ""))
				if desc != "":
					var dx := ix + nw + 14.0
					text_layer.draw_string(body, Vector2(dx, base + 15 * 0.36), desc, HORIZONTAL_ALIGNMENT_LEFT, maxf(rect.end.x - dx - 12.0, 10.0), 15,
						XUiSkin.TEXT_3 if not ok else XUiSkin.TEXT_2)


func _draw_run() -> void:
	var ci := run_panel.get_canvas_item()
	var rect := Rect2(Vector2.ZERO, run_panel.size)
	XUiSkin.shadow_style().draw(ci, rect)
	XUiSkin.panel_style().draw(ci, rect)
	var s := _state()
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	run_panel.draw_string(body, Vector2(XUiSkin.PAD + 4, 18 + 20 * 0.86), run_text(s), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - XUiSkin.PAD * 2, 20, XUiSkin.TEXT)
	var st := seal_states(s)
	if st.is_empty():
		return
	var y := 66.0
	run_panel.draw_string(body, Vector2(XUiSkin.PAD + 4, y + 15 * 0.36), "七印", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_2)
	var x := XUiSkin.PAD + 4 + body.get_string_size("七印", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
	for k in SEALS:
		var v := int(st[k]) if k < st.size() else 0
		var c := Vector2(x + 6, y)
		var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)])
		if v == 2:
			run_panel.draw_colored_polygon(pts, XUiSkin.GOLD)
		elif v == 1:
			pts.append(pts[0])
			run_panel.draw_polyline(pts, XUiSkin.GOLD, 1.5, true)
		else:
			run_panel.draw_colored_polygon(pts, Color(XUiSkin.LINE, 0.3))
		x += 15.0
	var t := "%d / %d" % [seals_cleared(st), SEALS]
	var tw := num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	run_panel.draw_string(num, Vector2(rect.size.x - XUiSkin.PAD - 4 - tw, y + 21 * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD_LIGHT)


## 环心：当前角色（选人时跟着队伍条）的圆头像
func _draw_face() -> void:
	if host == null:
		return
	var members := host._members()
	if members.is_empty():
		return
	var idx := host._actor_index if host._mode == "actor" else host._selected_actor
	var a: XActor = members[clampi(idx, 0, members.size() - 1)]
	var tex := XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
	if tex == null:
		return
	var c := ring.center()
	var rad := ring.radius - 62.0
	if _sprite_layer != null:
		_sprite_layer.queue_redraw()
	if XUiSkin.CENTER_STYLE != XUiSkin.CenterStyle.FACE and sv_frame(a) != null:
		# D45 方案：环心是像素小人（_draw_sprite，最近邻），方案 B 再在环心右下叠一枚小圆头像
		if XUiSkin.CENTER_STYLE == XUiSkin.CenterStyle.SPRITE_BADGE:
			var bc := c + Vector2(rad * 0.55, rad * 0.5)
			var br := 30.0
			face.draw_circle(bc, br + 4.0, Color(0, 0, 0, 0.6))
			XSkinPartyStrip.draw_round_texture(face, tex, bc, br)
			face.draw_circle(bc, br + 1.0, Color(XUiSkin.GOLD, 0.8), false, 2.0, true)
		return
	face.draw_circle(c, rad + 3.0, Color(0, 0, 0, 0.45))
	XSkinPartyStrip.draw_round_texture(face, tex, c, rad)
	face.draw_circle(c, rad, Color(XUiSkin.LINE, 0.5), false, 1.5, true)


## ---- D45（收口批，Kyo 定小人和头像都要；XUiSkin.CENTER_STYLE 选方案，默认仍是头像，等 Kyo 看图定）----
var _sprite_layer: Control
var _sprite_step := 0


## 当前角色战斗侧视图（sv_actors，9×6 格）第 0 行第 1 格（站立）；没有时 null
static func sv_frame(a: XActor, col := 1) -> AtlasTexture:
	if a == null:
		return null
	var p := XDB.img_path("sv_actors", str(a.data().get("battlerName", "")))
	if p == "" or not ResourceLoader.exists(p):
		return null
	var key := "sv:%s#%d" % [p, col]
	if not XUiSkin._icon_cache.has(key):
		var sheet := load(p) as Texture2D
		var at: AtlasTexture = null
		if sheet != null:
			at = AtlasTexture.new()
			at.atlas = sheet
			var cw := sheet.get_width() / 9.0
			var ch := sheet.get_height() / 6.0
			at.region = Rect2(cw * col, 0, cw, ch)
		XUiSkin._icon_cache[key] = at
	return XUiSkin._icon_cache[key]


func _ensure_sprite_layer() -> void:
	if _sprite_layer != null or face == null:
		return
	_sprite_layer = Control.new()
	_sprite_layer.name = "SvSprite"
	_sprite_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite_layer.draw.connect(_draw_sprite)
	face.add_child(_sprite_layer)
	var t := Timer.new()   # 站立动作 0-1-2-1 每格 0.2 秒（动效「全部」档才动）
	t.wait_time = 0.2
	t.autostart = true
	t.timeout.connect(func():
		if XUiSkin.CENTER_STYLE != XUiSkin.CenterStyle.FACE and XUiSkin.breathing():
			_sprite_step += 1
			_sprite_layer.queue_redraw())
	_sprite_layer.add_child(t)


## 像素小人：整数倍放大（最多 3 倍，放不进环心就降），脚下一块半透明黑椭圆影＋一圈淡金受光
func _draw_sprite() -> void:
	if host == null or XUiSkin.CENTER_STYLE == XUiSkin.CenterStyle.FACE:
		return
	var members := host._members()
	if members.is_empty():
		return
	var idx := host._actor_index if host._mode == "actor" else host._selected_actor
	var a: XActor = members[clampi(idx, 0, members.size() - 1)]
	var fr := sv_frame(a, [0, 1, 2, 1][_sprite_step % 4] if XUiSkin.breathing() else 1)
	if fr == null:
		return
	var c := ring.center()
	var rad := ring.radius - 62.0
	var fs := fr.get_size()
	var k := clampi(floori(rad * 2.0 * 0.9 / maxf(fs.x, fs.y)), 1, 3)
	var sz := fs * k
	var feet := c + Vector2(0, sz.y * 0.42)
	var shadow := PackedVector2Array()
	for i in 24:
		shadow.append(feet + Vector2(cos(TAU * i / 24.0) * 48.0, sin(TAU * i / 24.0) * 12.0))
	_sprite_layer.draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
	_sprite_layer.draw_arc(feet, 52.0, 0, TAU, 32, Color(XUiSkin.GOLD, 0.25), 1.5, true)
	_sprite_layer.draw_texture_rect(fr, Rect2((c - sz / 2.0).round(), sz), false)


## 收口批（TOUCH_V2）：左上「‹」返回（点＝取消），_ready 时加上
var back_button: XSkinBackButton


func _draw_top() -> void:
	var view := layout.view_size()
	var m := XSkinLayout.margin_for(view.x)
	XSkinArt.bg_string(top, XUiSkin.font("title"), Vector2(XSkinBackButton.place(back_button, m), 14 + 34 * 0.92), TITLE, XUiSkin.FS_PAGE, XUiSkin.TEXT)
	# 货币：名字次要字 15、数值淡金窄体 26，右对齐（样稿：精魂在左、印屑在右）
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var x := view.x - m
	var cur := currencies(_state())
	cur.reverse()
	for pair in cur:
		var vw := num.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		x -= vw
		XSkinArt.bg_string(top, num, Vector2(x, 42), pair[1], 26, XUiSkin.GOLD_LIGHT)
		var nw := body.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		x -= nw + 6
		XSkinArt.bg_string(top, body, Vector2(x, 42), pair[0], 15, XSkinArt.bg_text_2())
		x -= 18
