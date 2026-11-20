class_name XSkinSubPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T300 卡 L：设置子页的新版型（T254 3.0 版型三「设置子页」）——设置主页本身：分类环不动，
## 中间列表换成子页的行，列表标题下加一行面包屑「画面 › 画质设置」，右牌是「名字、现在的值、说明、可选、操作」。不开小窗、不换场景。
## 本件只是适配层：子页（画质、消息提醒、屏蔽掉落、角色换装、导入导出、手机按键，以及后面卡 M 的挂机子页）的状态机一行不动，
## 键盘照旧由子页自己的 _unhandled_input 处理；本件只负责画（按帧比一下内容，变了才重排）和接鼠标／触屏（点行＝选中，点当前行＝确定，右键＝取消）。
## 子页（owner）要提供的方法（鸭子类型，缺了就用默认）：
##   必有属性／方法：index（当前行）、select(i)、ok()、cancel()
##   skin_rows() -> Array        行，同 XSkinList 的行字典 {text, right, right_color, sub, icon, color, disabled, tags}
##   skin_card(i) -> Dictionary  右牌，同 XSkinCard.setup 的字典（title、subtitle、desc、sections、buttons）
##   skin_crumb() -> Array       面包屑各段（不给＝[分类名, 子页名]）
##   skin_name() -> String       子页名（列表标题）
##   skin_cat() -> String        没有设置主页时（单测、单开）环上高亮哪一类，XSkinOptionsPage.CATS 的键
##   skin_bars() -> Array        每行一个 0～1（行尾数值旁画 80×6 细条）或 -1（不画）；手机按键用
##   skin_hints() -> Array       按键提示；skin_empty() -> String 列表为空时中间一句；skin_button(i)＝点牌上按钮
## 开关：ENABLED＝false 时子页一律旧画法（天启篇存档里也回旧窗口）；新皮肤关着、西游存档本来就不建。
## 用法（子页 _ready 里）：if XSkinSubPage.wanted(): skin = XSkinSubPage.attach(self); 再把旧窗口 hide()。

## 总开关（卡 L 的一个开关）：false＝六个设置子页都回旧画法
static var ENABLED := true

var scene: Control
var crumb: Array = []
var _syncing := false
var _key := ""
var _card_key := ""
var _cat_name := ""
var _fade: Tween
var _bars: Array = []
var _bar_layer: Control
var _bar_top := -1
const BAR_W := 80.0
const BAR_H := 6.0


static func wanted() -> bool:
	return ENABLED and XUiSkin.on()


## 建在 owner 上（铺满）并同步一次；owner 要在树里
static func attach(owner: Control) -> XSkinSubPage:
	var p := XSkinSubPage.new(owner)
	owner.add_child(p)
	p.sync()
	return p


func _init(s: Control) -> void:
	scene = s
	name = "SkinSubPage"
	title = "设置"
	group_key = "system"
	columns = 1
	row_height = XUiSkin.ROW_H
	auto_nav = false
	hint_list = [["确定", "切换"], ["左右", "调整"], ["取消", "返回"]]


func _ready() -> void:
	super()
	if backdrop != null:   # 子页自己（XUI.menu_background）和设置页都已有底，这里不叠
		backdrop.queue_free()
		backdrop = null
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 环只是提示在哪一类，子页里不能点（取消回上一层再换类）
	ring.draw.connect(func(): XSkinOptionsPage.draw_cat_name(ring, _cat_name))
	list.index_changed.connect(func(i):
		if _syncing or i == int(scene.index):
			return
		scene.select(i))
	list.activated.connect(func(i):
		if _syncing:
			return
		if i != int(scene.index):
			scene.select(i)
		scene.ok())
	card_button.connect(func(i):
		if scene.has_method("skin_button"):
			scene.skin_button(i)
		else:
			scene.ok())
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			scene.cancel()
			accept_event())
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bar_layer = Control.new()
	_bar_layer.name = "Bars"
	_bar_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_layer.draw.connect(_draw_bars)
	list.add_child(_bar_layer)
	set_focus("list")
	_build_ring()
	relayout()


func _process(delta: float) -> void:
	super(delta)
	if visible:
		sync()
		if list != null and list.top_row != _bar_top:
			_bar_top = list.top_row
			_bar_layer.queue_redraw()


## 列表往下让出面包屑那一行（8 像素），行数仍是整行
func relayout() -> void:
	super()
	if layout == null or list == null:
		return
	var cs := layout.center.size
	var top := LIST_TOP + 8.0
	list.position.y = top
	list.size.y = floorf((cs.y - top - FOOTER_H) / float(row_height)) * row_height


func _draw_list_panel() -> void:
	super()
	if not crumb.is_empty():
		XSkinCrumb.draw_parts(list_panel, Vector2(XUiSkin.PAD + 8, XUiSkin.PAD + 40), crumb, list_panel.size.x - 48.0)


## 环：有设置主页就照它（同样的类、同样高亮），没有（单开）就用全部分类、按 skin_cat 高亮
func _build_ring() -> void:
	var main := _main()
	var items: Array = []
	var cur := 0
	if main != null and not main.cats.is_empty():
		items = main.cats.map(func(c): return {"key": c.key, "name": c.name, "icon": c.icon})
		cur = main.cur
	else:
		var want: String = scene.skin_cat() if scene.has_method("skin_cat") else "general"
		for c in XSkinOptionsPage.CATS:
			items.append({"key": c[0], "name": c[1], "icon": c[2]})
		items.append({"key": XSkinOptionsPage.OTHER[0], "name": XSkinOptionsPage.OTHER[1], "icon": XSkinOptionsPage.OTHER[2]})
		for k in items.size():
			if items[k].key == want:
				cur = k
	set_categories(items, cur)
	if XSkinRingNav.INNER_V2:
		for k in ring.items.size():
			ring.items[k]["glyph"] = str(XSkinOptionsPage.GLYPH.get(str(ring.items[k].get("key", "")), "他"))
	_cat_name = str(items[cur].name) if not items.is_empty() else ""
	ring.queue_redraw()


## 往上找设置页（XOptionsScene）拿它的新布局；找不到＝null
func _main() -> XSkinOptionsPage:
	var n: Node = scene.get_parent() if scene != null else null
	while n != null:
		if n is XOptionsScene:
			return (n as XOptionsScene).skin
		n = n.get_parent()
	return null


## 内容变了才重排。子页状态机改了什么（选中、值、文字）都在这一帧后跟上
func sync() -> void:
	if layout == null or scene == null or not is_instance_valid(scene):
		return
	var rows: Array = scene.skin_rows()
	var bars: Array = scene.skin_bars() if scene.has_method("skin_bars") else []
	for k in mini(rows.size(), bars.size()):
		if float(bars[k]) >= 0.0:
			rows[k]["right2"] = ""   # 给细条留位置（XSkinList 的 right2 只占宽）
	list.right2_w = BAR_W + 16.0
	if bars != _bars:
		_bars = bars
		_bar_layer.queue_redraw()
	var cname: String = str(scene.skin_name()) if scene.has_method("skin_name") else ""
	var parts: Array = scene.skin_crumb() if scene.has_method("skin_crumb") else [_cat_name, cname]
	if parts != crumb:
		crumb = parts
		list_panel.queue_redraw()
	if cname != list_title:
		list_title = cname
		list_panel.queue_redraw()
	var hints_now: Array = scene.skin_hints() if scene.has_method("skin_hints") else hint_list
	set_hint_list(hints_now)
	_syncing = true
	var pos := clampi(int(scene.index), 0, maxi(rows.size() - 1, 0))
	var key := str(rows)
	list.empty_center = true
	list.empty_text = str(scene.skin_empty()) if scene.has_method("skin_empty") else "这里没有东西"
	if key != _key:
		_key = key
		set_items(rows, pos)
	elif list.index != pos and not rows.is_empty():
		list.select(pos, false)
	var card_d: Dictionary = scene.skin_card(pos) if not rows.is_empty() else {}
	var ck := str(card_d) + "|%d" % pos
	if ck != _card_key:
		_card_key = ck
		if rows.is_empty():
			set_card({})
			card.visible = false
		else:
			card.visible = true
			set_card(card_d)
		card.queue_redraw()
	_syncing = false


## 行尾的细条：贴着行右缘（右边 14 像素边距里），80×6，底 TEXT_3、填充 GOLD；灰掉的行（disabled）不画
func _draw_bars() -> void:
	if list == null:
		return
	var first := list.top_row
	var last := mini(list.items.size(), first + list.visible_rows())
	for i in range(first, last):
		if i >= _bars.size() or float(_bars[i]) < 0.0 or bool(list.items[i].get("disabled", false)):
			continue
		var r := list.cell_rect(i)
		var x := r.end.x - 14.0 - BAR_W
		var y := r.position.y + (r.size.y - BAR_H) / 2.0
		_bar_layer.draw_rect(Rect2(x, y, BAR_W, BAR_H), Color(XUiSkin.TEXT_3, 0.45))
		_bar_layer.draw_rect(Rect2(x, y, BAR_W * clampf(float(_bars[i]), 0.0, 1.0), BAR_H), XUiSkin.GOLD)


# ---- 子页常用的牌内容 ----

## 「可选」一节：labels＝各档的字，cur＝现在第几档，default＝默认第几档（-1 不标）。当前档右边标「现在」，默认档标「默认」
static func choices_section(labels: Array, cur: int, default_idx := -1) -> Dictionary:
	var lines := []
	for k in labels.size():
		var tags := []
		if k == cur:
			tags.append("现在")
		if k == default_idx:
			tags.append("默认")
		lines.append({"left": str(labels[k]), "right": "·".join(tags),
			"color": XUiSkin.TEXT_HI if k == cur else XUiSkin.TEXT_2,
			"right_color": XUiSkin.GOLD if k == cur else XUiSkin.TEXT_3})
	return {"title": "可选", "lines": lines}


## 「开／关」的行尾色：开＝GOLD_LIGHT，关＝TEXT_2
static func on_color(on: bool) -> Color:
	return XUiSkin.GOLD_LIGHT if on else XUiSkin.TEXT_2


# ---- 淡出／淡入（手机按键拖动态）----

## 整页淡出（0.12 秒；动效关＝立刻）。淡完隐藏，不挡拖动
func fade_out() -> void:
	if _fade != null:
		_fade.kill()
	if XUiSkin.motion() == XUiSkin.Motion.OFF or not is_inside_tree():
		modulate.a = 0.0
		hide()
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.12)
	_fade.tween_callback(hide)


func fade_in() -> void:
	if _fade != null:
		_fade.kill()
	show()
	if XUiSkin.motion() == XUiSkin.Motion.OFF or not is_inside_tree():
		modulate.a = 1.0
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.12)
