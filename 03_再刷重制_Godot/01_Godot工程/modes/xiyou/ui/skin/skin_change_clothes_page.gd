class_name XSkinChangeClothesPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T365 卡 Q：更衣新布局（T254 3.13；版型一）。
## 衣橱条目、解锁表、分类 8 档、换上／还原、O-093 修正、提示文字（替换完成／还原完成／未解锁）全部还是 XChangeClothesScene／XChangeClothes 原来的代码；
## 本页只换画法，按键里列表的上下左右、翻页、取消由本页转成对 scene 的原操作，其余照旧。
## 旧页 → 新页（T254 3.13 对应表）：
## - 底部指令「更换／还原当前形象」→ 右牌两枚按钮：主「换上」、次「还原形象」（X 键）。旧页进页先停在这两项上，新页没有这一层：进页就在分类环上。
## - 分类 8 档 → 环上 8 个球（球 52，球里写档名第一个字），环心「N / M 已解锁」（整个衣橱）；这一档的「n / m」写在列表标题右边小字。
## - 名单（已解锁＝行走图上半＋名字；未解锁「？？？」）→ 两列：小人缩略＋名字；未解锁「？？？」变灰；正穿着的加「穿着」小标。
## - 状态窗（形象展示：行走图正面放大 2 倍、每 20 帧换一格；获得途径；状态:已解锁／未解锁）→ 右牌：名字、「档位 · 已解锁／未解锁」、「怎么拿到」一节；
##   小人 3 倍（脚下一圈淡金光、每 20 帧换一格）放在牌的下半、按钮上方（通用牌件不能在牌头留位）；未解锁不画小人。
## - 提示「替换完成」「还原完成」「未解锁」→ 仍走 XToast（提示道）。
## 新皮肤关着、或 ENABLED＝false 时 XChangeClothesScene 不建这一页，旧页一行不变。

## T365 回退开关：false＝天启篇新皮肤下更衣也回旧页
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_TITLE := "更衣"
const T_UNLOCKED := "已解锁"
const T_LOCKED_STATE := "未解锁"
const T_WEAR := "换上"
const T_RESTORE := "还原形象"
const T_WORN := "穿着"
const T_HOW := "怎么拿到"
const T_UNKNOWN := "？？？"
const FIG_H := 168.0        # 小人区高（3 倍 48＝144＋脚下光）
const FIG_SCALE := 3.0

var scene: XChangeClothesScene
var fig_layer: Control
var list_right := ""
var _syncing := false
var _reserve := 0.0
var _list_key := []
var _ref := 0
var _tick := 0
static var _thumbs := {}
static var _tot: Array = []
static var _tot_key := -1


func _init(s: XChangeClothesScene) -> void:
	scene = s
	name = "SkinChangeClothesPage"
	title = T_TITLE
	group_key = ""            # 从方桌衣橱管理员进的页：不画页签条（T254 3.0）
	columns = 2
	row_height = 52
	left_w = 312.0
	right_w = 312.0
	orb_radius = 26.0         # 球 52
	auto_nav = false
	focus = "ring"
	currencies = []
	hint_list = []


func _ready() -> void:
	super()
	list.empty_center = true
	list.icon_size = 40
	list.empty_text = "这一档没有形象"
	list.index_changed.connect(_on_list_index)
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(func(_i): if not _syncing and scene.mode == "category": scene.ok())
	list_panel.draw.connect(_draw_list_right)
	card_button.connect(_on_card_button)
	fig_layer = Control.new()
	fig_layer.name = "Figure"
	fig_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fig_layer.draw.connect(_draw_figure)
	card.add_child(fig_layer)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


# ---- 数据 ----

## 名单当前预览的条目：选了行用那一行，还在选档时预览这一档第一项
func entry():
	var sc := scene
	if sc.data.is_empty():
		return null
	return sc.data[sc.index] if sc.index >= 0 and sc.index < sc.data.size() else sc.data[0]


static func is_worn(s: XState, e: Dictionary) -> bool:
	var c: Dictionary = s.player_costume if s != null else {}
	return not c.is_empty() and str(c.get("characterName", "")) == str(e.get("characterName", "")) and int(c.get("characterIndex", 0)) == int(e.get("characterIndex", 0))


## 行走图中间帧的缩略（取一次缓存）
static func thumb(e: Dictionary) -> Texture2D:
	var cname := str(e.get("characterName", ""))
	var tex := XSkinPartyPage.walker_texture(cname)
	if tex == null:
		return null
	var k := "%s#%d" % [cname, int(e.get("characterIndex", 0))]
	if not _thumbs.has(k):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = frame_rect(tex, int(e.get("characterIndex", 0)), 1)
		_thumbs[k] = at
	return _thumbs[k]


## 原版格子：图宽÷12 × 图高÷8（不分 $ 单人图）；序号 >3 在下半；ref 是 0～2 的那一列
static func frame_rect(tex: Texture2D, idx: int, ref: int) -> Rect2:
	var cw := tex.get_width() / 12.0
	var ch := tex.get_height() / 8.0
	var col := (idx * 3 - 12 if idx > 3 else idx * 3) + ref
	return Rect2(col * cw, (4 if idx > 3 else 0) * ch, cw, ch)


## 一行（测试按对应表核）
func row_for(e: Dictionary) -> Dictionary:
	var open := XChangeClothes.unlocked(int(e.id))
	if not open:
		return {"text": T_UNKNOWN, "_id": int(e.id), "_open": false, "disabled": true}
	var row := {"text": str(e.name), "_id": int(e.id), "_open": true, "icon": thumb(e)}
	if is_worn(XState.current, e):
		row["tags"] = [T_WORN]
	return row


## 整个衣橱已解锁／总数（环心）
static func totals() -> Array:
	var lite := XConfig.clothes_unlocked().size()
	if _tot_key == lite and not _tot.is_empty():
		return _tot
	var have := 0
	var all := 0
	for k in XChangeClothes.CATEGORIES.size():
		for e in XChangeClothes.list(k):
			all += 1
			if XChangeClothes.unlocked(int(e.id)):
				have += 1
	_tot_key = lite
	_tot = [have, all]
	return _tot


## 右牌（测试按对应表核）
func card_data() -> Dictionary:
	var e = entry()
	var sc := scene
	if e == null:
		return {"title": "", "sections": [], "buttons": []}
	var open := XChangeClothes.unlocked(int(e.id))
	var tier := str(XChangeClothes.CATEGORIES[sc.shown_category])
	var how := XChangeClothes.source_text(e).trim_prefix("获得途径：")
	var can_wear := open and sc.mode == "list"
	return {"icon": null, "title": str(e.name) if open else T_UNKNOWN, "title_color": XUiSkin.TEXT_HI if open else XUiSkin.TEXT_3,
		"subtitle": "%s · %s" % [tier, T_UNLOCKED if open else T_LOCKED_STATE],
		"sections": [{"title": T_HOW, "rows": [{"text": how, "color": XUiSkin.TEXT}]}],
		"buttons": [{"text": T_WEAR, "primary": true, "disabled": not can_wear}, {"text": T_RESTORE}],
		"reserve_bottom": FIG_H if open else 0.0, "_can_wear": can_wear}


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.cat_win, sc.list_win, sc.status_win, sc.bottom_win]:
		w.visible = false
	var cats := []
	for t in XChangeClothes.CATEGORIES:
		cats.append({"key": str(t), "name": str(t), "icon": 0, "glyph": str(t).left(1)})
	if ring.items.size() != cats.size():
		set_categories(cats, maxi(sc.category, 0))
	elif ring.index != maxi(sc.category, 0):
		ring.select(maxi(sc.category, 0), false)
	var tot := totals()
	ring_center = ["%d / %d" % tot, T_UNLOCKED]
	var have := 0
	for e in sc.data:
		if XChangeClothes.unlocked(int(e.id)):
			have += 1
	list_title = str(XChangeClothes.CATEGORIES[sc.shown_category])
	list_right = "%d / %d" % [have, sc.data.size()]
	var rows := []
	for e in sc.data:
		rows.append(row_for(e))
	var key := [sc.shown_category, rows.map(func(r): return [r._id, r._open, r.get("tags", [])])]
	var idx := clampi(sc.index, 0, maxi(rows.size() - 1, 0))
	if key != _list_key:
		_list_key = key
		set_items(rows, idx)
	elif list.index != idx and not rows.is_empty() and sc.mode == "list":
		list.select(idx, false)
	set_focus("list" if sc.mode == "list" else "ring")
	list.active = sc.mode == "list"
	_sync_card()
	if sc.mode == "list":
		set_hint_list([["确定", "换上"], ["X", "还原形象"], ["Q / E", "翻页"], ["取消", "回到分类"]])
	else:
		set_hint_list([["确定", "进入列表"], ["X", "还原形象"], ["取消", "离开"]])
	_syncing = false
	ring.queue_redraw()
	list.queue_redraw()
	list_panel.queue_redraw()


func _sync_card() -> void:
	var d := card_data()
	card.visible = not scene.data.is_empty()
	d.erase("_can_wear")
	d.button_index = -1
	_reserve = float(d.get("reserve_bottom", 0.0))
	set_card(d)
	_place_targets()
	if fig_layer != null:
		fig_layer.queue_redraw()


## 模板每次摆位都把牌底留白清成「给谁用」列表的高；本页没有那个列表，留白给小人区
func _place_targets() -> void:
	super()
	if card != null:
		card.reserve_bottom = _reserve
		card.queue_redraw()


# ---- 按键 ----

func input(event: InputEvent) -> bool:
	var sc := scene
	if event.is_action_pressed("ui_cancel"):
		if sc.mode == "list":
			sc.cancel()          # 回分类（旧：Rancancel）
		else:
			sc.mode = "bottom"   # 新页没有指令窗这一层：分类上取消直接离开
			sc.cancel()
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X:
		sc.restore_now()
		return true
	if sc.mode == "list" and not sc.data.is_empty():
		if XMenu.page_dir(event) != 0:
			list.page(XMenu.page_dir(event), true)
			return true
		var step := 0
		if event.is_action_pressed("ui_down", true):
			step = 2
		elif event.is_action_pressed("ui_up", true):
			step = -2
		elif event.is_action_pressed("ui_right", true):
			step = 1
		elif event.is_action_pressed("ui_left", true):
			step = -1
		if step != 0:
			_step_list(step, not event.is_echo())
			return true
	elif sc.mode == "category" and (event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true)):
		sc._move(1 if event.is_action_pressed("ui_right", true) else -1, not event.is_echo())
		return true
	return false


## 两列网格里挪光标：上下±2（一整行）、左右±1；到头时（可循环才）绕回同列另一头
func _step_list(step: int, wrap: bool) -> void:
	var sc := scene
	var n := sc.data.size()
	var i := sc.index + step
	if i < 0 or i >= n:
		if not wrap:
			return
		if absi(step) == 2:
			var col := posmod(sc.index, 2)
			i = col if step > 0 else ((n - 1) if posmod(n - 1, 2) == col else n - 2)
			i = clampi(i, 0, n - 1)
		else:
			i = posmod(i, n)
	if i != sc.index:
		XSound.system(0)
		sc._select(i)


func _on_ring_changed(i: int) -> void:
	if _syncing or i == scene.category:
		return
	if scene.mode == "list":
		scene.cancel()
	scene._select_category(i)


func _on_list_index(i: int) -> void:
	if _syncing or i == scene.index:
		return
	if scene.mode == "category":
		scene.ok()
	XSound.system(0)
	scene._select(i)


func _on_card_button(i: int) -> void:
	if i == 0:
		if scene.mode == "list":
			scene.ok()
		else:
			XSound.system(3)
	else:
		scene.restore_now()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		input(_cancel_event())
		accept_event()


static func _cancel_event() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e


# ---- 画 ----

func _draw_list_right() -> void:
	if list_right == "":
		return
	var body := XUiSkin.font("body")
	var fs := XUiSkin.fs(XUiSkin.FS_AUX)
	var tw := body.get_string_size(list_right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(list_panel, body, Vector2(list_panel.size.x - XUiSkin.PAD - 8 - tw, XUiSkin.PAD + 20), list_right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.GOLD_LIGHT)


## 每 20 个物理帧换一格（0→1→2，同旧状态窗 SPRITE_TICK）
func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick % XChangeClothesScene.SPRITE_TICK == 0:
		_ref = (_ref + 1) % 3
		if fig_layer != null and fig_layer.visible:
			fig_layer.queue_redraw()


## 右牌下半：小人 3 倍（脚下淡金光），已解锁才画
func _draw_figure() -> void:
	var e = entry()
	if e == null or not card.visible or not XChangeClothes.unlocked(int(e.id)):
		return
	var tex := XSkinPartyPage.walker_texture(str(e.get("characterName", "")))
	if tex == null:
		return
	var area_top := card.content_bottom()
	var cx := card.size.x / 2.0
	var fr := frame_rect(tex, int(e.get("characterIndex", 0)), _ref)
	var dst := Vector2(fr.size.x, fr.size.y) * FIG_SCALE
	var foot := Vector2(cx, area_top + FIG_H - 14.0)
	# 脚下一圈淡金光（压扁的圆，三层渐淡）
	fig_layer.draw_set_transform(foot, 0.0, Vector2(1.0, 0.32))
	for k in 3:
		fig_layer.draw_circle(Vector2.ZERO, 54.0 - k * 14.0, Color(XUiSkin.GOLD, 0.07 + 0.06 * k))
	fig_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	RenderingServer.canvas_item_set_default_texture_filter(fig_layer.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	fig_layer.draw_texture_rect_region(tex, Rect2(foot.x - dst.x / 2.0, foot.y - dst.y + 8.0, dst.x, dst.y), fr)
