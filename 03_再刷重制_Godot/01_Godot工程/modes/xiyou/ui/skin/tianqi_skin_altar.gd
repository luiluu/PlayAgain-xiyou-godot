class_name XTianqiSkinAltar
extends Control
## 【cc·天启篇·未经审查】七印祭坛新界面（界面风格提案 v0.7 样稿 altar、README 第一节「七印祭坛」；盘点清册 #80、#81；新界面第 3A 批）。
## 旧的是对话框选单（「七印祭坛。印钥：n　印屑：n」＋揭印／揭开封着的／看印库／熔炼……／离开），新界面开着时换成这一页：
##   左：七印环——通用法阵慢转、主环、七道旧金刻痕、七枚封蜡（七印徽记，按印序从正上顺时针），每枚旁边写名字和状态
##       （已揭开＝首通过 Boss，绿；可揭开＝揭开了还没打过，旧金；未开启＝灰）；选中的那枚放大，背后封蜡光晕（旧金），
##       主环上焦点光弧转到它；环心写「已揭开几 / 7」。
##   右：选中印的牌——大印、名字、状态、开启条件（躁动中另写一行）、「本印封存」（印库里这一印封着的套装件、毕业武器各几件），
##       底下一列入口：揭印（进里副本）／再进里副本（首通过的）＋祭坛原有的其它入口（揭开封着的、看印库、熔炼分解兑换、七首之龙、外观）。
##   顶：页名＋右上印钥、印屑、印库件数；右下按键提示（让出版本号）。Y 打开「怎么玩」（五条规则＋这一印的里副本和规则）。
## 只做选择：选了什么交回 XTianqiQiyin.run_altar，后面照旧走原来的流程（对话、选项、演出、掉落、随机数一概不动）；
## 揭印时把环上选中的印带过去，省掉「选哪一印」那一问（XTianqiQiyin.choose_and_run 的 preset）。
## 开关：沿用新界面总开关（XUiSkin.on()，O-467）；关着或宿主不是真地图场景（测试的假宿主）时照旧弹对话框选单。
## 类名带 XTianqi 前缀：发行包里整份换成空壳，只有天启篇代码（XTianqiQiyin）调它。

signal chosen(result: Dictionary)

const CARD_W := 380.0
const SEAL_SIZE := 96.0
const RING_R := 212.0
const BUTTON_H := 44.0
## 三种状态的字（小A文字审：「可以揭」→「可揭开」）
const STATE_TEXT := ["未开启", "可揭开", "已揭开"]
const RULES := [
	"打过对应的层，这一印就开启，可以进它的里副本",
	"掉下来的东西都是封着的，先进印库",
	"结算时可以当场揭，也可以回这里揭；揭开才能穿",
	"首通过的印可以「直取」只打首领",
	"进之前可以献印屑，定第一件掉哪个部位",
]

## 上次停在哪一印（同一次开祭坛里来回，回到这一页还停在那）
static var last_seal := ""

var state: XState
var options: Array = []      # XTianqiQiyin.altar_options 的结果
var rows: Array = []         # seal_rows
var index := 0
var button := 0
var rules_open := false
var buttons: Array = []      # 当前印的入口 [{id, text, primary, disabled}]
var _arc := -90.0
var _arc_to := -90.0
var _spin := 0.0
var _done := false

var backdrop: Control
var ring: Control
var card: Control
var top: Control
var hints: XSkinKeyHints
var rules: Control


## 新界面开着、宿主是真的地图场景时用这一页
static func use(host) -> bool:
	return XUiSkin.on() and host is Node and (host as Node).is_inside_tree()


## 开这一页、等玩家选，返回 {id, seal}（id 同 altar_options；取消＝leave）
static func pick(host, s: XState, opts: Array) -> Dictionary:
	var page: XTianqiSkinAltar = XTianqiSkinAltar.new()
	page.setup(s, opts)
	var hud = host.get("hud")
	var hud_was: bool = hud.visible if hud is CanvasItem else false
	if hud is CanvasItem:
		hud.visible = false
	if host.has_method("_add_scene_page"):
		host._add_scene_page(page)
	else:
		(host as Node).add_child(page)
	var r: Dictionary = await page.chosen
	if is_instance_valid(page):
		if page.get_parent() != null:
			page.get_parent().remove_child(page)
		page.queue_free()
	if hud is CanvasItem and is_instance_valid(hud):
		hud.visible = hud_was
	return r


## 七印各一行：{key, seal（白印）, place（里副本名）, state 0/1/2, cond, restless, set, weapon}
static func seal_rows(s: XState) -> Array:
	var states := XSkinMainMenu.seal_states(s)
	var keys := XTianqiQiyin.seal_keys()
	var restless := str(XTianqiQiyin.progress(s).drop.get("restless", "")) if s != null and XTianqiQiyin.allowed(s) else ""
	var sealed := XTianqiQiyin.sealed_items(s) if s != null and XTianqiQiyin.allowed(s) else []
	var out := []
	for i in keys.size():
		var k := str(keys[i])
		var info := XTianqiQiyin.seal_info(k)
		var n_set := 0
		var n_weapon := 0
		for it in sealed:
			if str(it.get("seal", "")) != k:
				continue
			if str(it.get("kind", "")) == XTianqiQiyinDrop.KIND_WEAPON:
				n_weapon += 1
			else:
				n_set += 1
		out.append({"key": k, "seal": str(info.get("seal", k)), "place": str(info.get("name", "")),
			"rule_name": str(info.get("rule_name", "")), "rule_text": str(info.get("rule_text", "")),
			"state": int(states[i]) if i < states.size() else 0, "cond": cond_text(k), "restless": restless == k,
			"set": n_set, "weapon": n_weapon})
	return out


## 开启条件一句话（qiyin_altar.json unlock）
static func cond_text(key: String) -> String:
	var u = XTianqiQiyin.data().get("unlock", {}).get(key)
	if not u is Dictionary:
		return ""
	if u.has("floor"):
		return "打过第 %d 层开启" % int(u.floor)
	if u.has("after_seals"):
		return "前六印的首领都打过后开启"
	return ""


## 这一印的入口：第一个是进里副本（没开启时不能按），后面是祭坛的其它入口（离开不列，取消就是离开）
static func card_buttons(row: Dictionary, opts: Array) -> Array:
	var st := int(row.get("state", 0))
	var out := [{"id": "enter", "text": "再进里副本" if st == 2 else "揭印（进里副本）", "primary": st > 0, "disabled": st == 0}]
	for o in opts:
		var id := str(o.get("id", ""))
		if id == "enter" or id == "leave":
			continue
		out.append({"id": id, "text": str(o.get("label", "")), "primary": false, "disabled": false})
	return out


func setup(s: XState, opts: Array) -> void:
	state = s
	options = opts
	rows = seal_rows(s)
	index = 0
	for i in rows.size():
		if str(rows[i].key) == last_seal:
			index = i
	if last_seal == "" or index >= rows.size():
		# 第一次开：停在第一枚「可揭开」的，没有就第一枚开启了的
		index = 0
		for want in [1, 2]:
			var hit := rows.map(func(r): return int(r.state)).find(want)
			if hit >= 0:
				index = hit
				break
	_arc = _deg(index)
	_arc_to = _arc
	_refresh_buttons()


func _ready() -> void:
	add_to_group(XUiSkin.FULLSCREEN_GROUP)   # 收口批：开着时收起虚拟摇杆／AB 键
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = XUiSkin.theme()
	backdrop = XUiSkin.menu_backdrop(self)
	XSkinLayout.request_wide(self)
	ring = _layer("Ring", _draw_ring)
	card = _layer("Card", _draw_card)
	top = _layer("Top", _draw_top)
	hints = XSkinKeyHints.new()
	add_child(hints)
	rules = _layer("Rules", _draw_rules)
	rules.visible = false
	resized.connect(relayout)
	get_viewport().size_changed.connect(relayout)
	relayout()


func _layer(n: String, f: Callable) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(f)
	add_child(c)
	return c


func view() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)


func card_rect() -> Rect2:
	var v := view()
	var m := XSkinLayout.margin_for(v.x)
	return Rect2(v.x - m - CARD_W, XUiSkin.TOP, CARD_W, XUiSkin.BOTTOM - XUiSkin.TOP)


func ring_center() -> Vector2:
	var v := view()
	var m := XSkinLayout.margin_for(v.x)
	var right := card_rect().position.x - XUiSkin.PANEL_GAP
	return Vector2(roundf((m + right) / 2.0), 392.0)


func _deg(i: int) -> float:
	return -90.0 + i * 360.0 / maxf(rows.size(), 1.0)


func seal_pos(i: int) -> Vector2:
	return ring_center() + Vector2.from_angle(deg_to_rad(_deg(i))) * RING_R


func hint_list() -> Array:
	if rules_open:
		return [["Y / 取消", "关闭"]]
	return [["← / →", "切换印"], ["↑ / ↓", "选入口"], ["确定", "选择"], ["Y", "看规则"], ["取消", "离开"]]


func relayout() -> void:
	if hints == null:
		return
	var v := view()
	hints.set_hints(hint_list())
	hints.position = Vector2(XSkinMainMenu.hint_right(v) - hints.total_width(), v.y - XUiSkin.HINT_BOTTOM - XSkinKeyHints.H)
	for c in [ring, card, top, rules]:
		c.queue_redraw()


func current() -> Dictionary:
	return rows[index] if index >= 0 and index < rows.size() else {}


func _refresh_buttons() -> void:
	buttons = card_buttons(current(), options) if not rows.is_empty() else []
	button = clampi(button, 0, maxi(buttons.size() - 1, 0))


# ---- 操作 ----

func select(i: int) -> void:
	if rows.is_empty():
		return
	var to := posmod(i, rows.size())
	var target := _deg(to)
	while target - _arc_to > 180.0:
		target -= 360.0
	while target - _arc_to < -180.0:
		target += 360.0
	index = to
	_arc_to = target
	if XUiSkin.motion() == XUiSkin.Motion.OFF or not is_inside_tree():
		_arc = target
	last_seal = str(current().get("key", ""))
	button = 0
	_refresh_buttons()
	if ring != null:
		ring.queue_redraw()
		card.queue_redraw()


func press(i: int) -> void:
	if i < 0 or i >= buttons.size():
		return
	button = i
	if bool(buttons[i].get("disabled", false)):
		XSound.system(3)
		card.queue_redraw()
		return
	XSound.system(1)
	_finish({"id": str(buttons[i].id), "seal": str(current().get("key", ""))})


func leave() -> void:
	XSound.system(2)
	_finish({"id": "leave", "seal": str(current().get("key", ""))})


func toggle_rules() -> void:
	rules_open = not rules_open
	if rules != null:
		rules.visible = rules_open
		relayout()


func _finish(r: Dictionary) -> void:
	if _done:
		return
	_done = true
	last_seal = str(current().get("key", last_seal))
	chosen.emit(r)


## 按键：用掉了返回 true（测试直接调）
func handle_input(event: InputEvent) -> bool:
	var key := event as InputEventKey
	var fresh := key != null and key.pressed and not key.echo
	var code := (key.physical_keycode if key.physical_keycode != 0 else key.keycode) if key != null else KEY_NONE
	if rules_open:
		if event.is_action_pressed("ui_cancel") or (fresh and code == KEY_Y):
			XSound.system(2)
			toggle_rules()
		return event is InputEventKey or event is InputEventJoypadButton or event.is_action_type()
	if fresh and code == KEY_Y:
		XSound.system(1)
		toggle_rules()
		return true
	if event.is_action_pressed("ui_cancel"):
		leave()
		return true
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		XSound.system(0)
		select(index + (-1 if event.is_action("ui_left") else 1))
		return true
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		if buttons.size() > 1:
			XSound.system(0)
			button = posmod(button + (-1 if event.is_action("ui_up") else 1), buttons.size())
			card.queue_redraw()
		return true
	if event.is_action_pressed("ui_accept"):
		press(button)
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if handle_input(event):
		XKeyMap.handled(self)


func _gui_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton) or not event.pressed:
		return
	accept_event()
	if rules_open:
		toggle_rules()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		leave()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = event.position
	for i in rows.size():
		if p.distance_to(seal_pos(i)) <= SEAL_SIZE * 0.55:
			if i != index:
				XSound.system(0)
				select(i)
			return
	var cr := card_rect()
	for i in buttons.size():
		if button_rect(i).has_point(p - cr.position):
			press(i)
			return


func _process(delta: float) -> void:
	var redraw := false
	if absf(_arc - _arc_to) > 0.01:
		_arc = lerpf(_arc, _arc_to, minf(1.0, delta * 14.0))
		if absf(_arc - _arc_to) < 0.3:
			_arc = _arc_to
		redraw = true
	if XUiSkin.breathing():
		_spin += delta
		redraw = true
	if redraw and ring != null:
		ring.queue_redraw()
		card.queue_redraw()


# ---- 画 ----

func seal_texture(key: String, st: int) -> Texture2D:
	var t := XTianqiQiyinShow.art("seal", key)
	return XTianqiQiyinArt.dim(t) if st == 0 and t != null else t


func state_color(st: int) -> Color:
	return [XUiSkin.TEXT_3, XUiSkin.GOLD, XUiSkin.UP][clampi(st, 0, 2)]


func _draw_ring() -> void:
	var c := ring_center()
	var R := RING_R
	var line := XUiSkin.LINE
	var circ := XUiSkin.circle_texture()
	if circ != null:
		var d := 364.0
		ring.draw_set_transform(c, deg_to_rad(_spin * 6.0), Vector2.ONE)
		ring.draw_texture_rect(circ, Rect2(-d / 2.0, -d / 2.0, d, d), false, Color(1, 1, 1, 0.5))
		ring.draw_set_transform(Vector2.ZERO)
	# 环心暗红底光（样稿 .core）
	ring.draw_texture_rect(XUiSkin.glow_texture(), Rect2(c - Vector2(110, 110), Vector2(220, 220)), false, Color(XUiSkin.SEL_FILL, 0.16))
	ring.draw_arc(c, R + 5.5, 0, TAU, 128, Color(XUiSkin.SEL_FILL, 0.05), 10.0, true)
	ring.draw_arc(c, R + 10.5, 0, TAU, 128, Color(line, 0.22), 1.0, true)
	ring.draw_arc(c, R, 0, TAU, 160, Color(line, 0.75), 1.5, true)
	var dash_r := R + 22.0
	var off := -_spin * TAU / 50.0
	for k in 80:
		var a0 := off + k * TAU / 80.0
		ring.draw_arc(c, dash_r, a0, a0 + TAU / 160.0, 4, Color(line, 0.30), 1.5, true)
	for k in 7:
		var p := c + Vector2.from_angle(deg_to_rad(-90.0 + k * 360.0 / 7.0 + 360.0 / 14.0)) * (R + 11.0)
		ring.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), XUiSkin.GOLD)
	# 焦点光弧
	if not rows.is_empty():
		var half := PI * 0.045
		var a := deg_to_rad(_arc)
		ring.draw_arc(c, R, a - half, a + half, 24, Color(XUiSkin.SEL_FILL, 0.35), 11.0, true)
		ring.draw_arc(c, R, a - half, a + half, 24, XUiSkin.SEL_LINE, 5.0, true)
	# 环心：已揭开几 / 7
	var num := XUiSkin.font("num")
	var body := XUiSkin.font("body")
	var head := XUiSkin.font("title")
	var done := rows.filter(func(r): return int(r.state) == 2).size()
	var big := "%d / %d" % [done, rows.size()]
	var bw := num.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	ring.draw_string(num, Vector2(c.x - bw / 2.0, c.y + 12), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, XUiSkin.TEXT)
	var sw := body.get_string_size(STATE_TEXT[2], HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX).x
	ring.draw_string(body, Vector2(c.x - sw / 2.0, c.y + 42), STATE_TEXT[2], HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT_2)
	# 七枚封蜡
	for i in rows.size():
		var r: Dictionary = rows[i]
		var p := seal_pos(i)
		var on := i == index
		var st := int(r.state)
		var s := SEAL_SIZE * (1.16 if on else 1.0)
		if on:
			# 封蜡光晕（旧金，呼吸）
			var hs := s * 1.7
			ring.draw_texture_rect(XUiSkin.seal_halo_texture(), Rect2(p - Vector2(hs, hs) / 2.0, Vector2(hs, hs)), false, Color(XUiSkin.GOLD, 0.55 * XUiSkin.breath_alpha()))
			ring.draw_texture_rect(XUiSkin.glow_texture(), Rect2(p - Vector2(hs, hs) / 2.0, Vector2(hs, hs)), false, Color(XUiSkin.GOLD, 0.18))
		ring.draw_circle(p + Vector2(0, 4), s * 0.42, Color(0, 0, 0, 0.5))
		var tex := seal_texture(str(r.key), st)
		if tex != null:
			ring.draw_texture_rect(tex, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(0.8, 0.8, 0.8) if st == 1 and not on else Color.WHITE)
		else:
			# 美术没到：画一枚本印颜色的圆印＋字
			var col := XTianqiQiyinShow.seal_color(str(r.key))
			ring.draw_circle(p, s * 0.42, col.darkened(0.55) if st == 0 else col)
			var g := XTianqiQiyinShow.seal_glyph(str(r.key))
			var gw := head.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
			ring.draw_string(head, Vector2(p.x - gw / 2.0, p.y + 11), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, XTianqiQiyinShow.seal_accent(str(r.key)))
		# 名字和状态：在印外侧
		var dir := Vector2.from_angle(deg_to_rad(_deg(i)))
		var lp := ring_center() + dir * (RING_R + 92.0)
		if absf(dir.x) < 0.3:
			lp = p + Vector2(0, (-s / 2.0 - 34.0) if dir.y < 0 else (s / 2.0 + 18.0))
		var name := str(r.seal)
		var fs := 22 if not on else 24
		var nw := head.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ring.draw_string_outline(head, Vector2(lp.x - nw / 2.0, lp.y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
		ring.draw_string(head, Vector2(lp.x - nw / 2.0, lp.y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if on else XUiSkin.TEXT)
		var stt: String = STATE_TEXT[clampi(st, 0, 2)]
		var tw := body.get_string_size(stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		ring.draw_string(body, Vector2(lp.x - tw / 2.0, lp.y + 22), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, state_color(st))


func button_rect(i: int) -> Rect2:
	var cr := card_rect()
	var pad := float(XUiSkin.PAD_LG)
	var n := buttons.size()
	var gap := float(XUiSkin.GRID)
	var bh := minf(BUTTON_H, (cr.size.y * 0.55 - gap * (n - 1)) / maxf(n, 1.0))
	var y0 := cr.size.y - pad - n * bh - (n - 1) * gap
	return Rect2(pad, y0 + i * (bh + gap), cr.size.x - pad * 2, bh)


func _draw_card() -> void:
	if rows.is_empty():
		return
	var cr := card_rect()
	card.draw_set_transform(cr.position)
	var ci := card.get_canvas_item()
	var box := Rect2(Vector2.ZERO, cr.size)
	XUiSkin.shadow_style().draw(ci, box)
	XUiSkin.panel_style().draw(ci, box)
	var r := current()
	var st := int(r.state)
	var w := cr.size.x
	var pad := float(XUiSkin.PAD_LG)
	var head := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var y := pad
	# 大印
	var cx := w / 2.0
	var tex := seal_texture(str(r.key), st)
	var big := 104.0
	if tex != null:
		card.draw_texture_rect(XUiSkin.seal_halo_texture(), Rect2(cx - big * 0.8, y + big / 2.0 - big * 0.8, big * 1.6, big * 1.6), false, Color(XUiSkin.GOLD, 0.35 if st > 0 else 0.12))
		card.draw_texture_rect(tex, Rect2(cx - big / 2.0, y, big, big), false)
	else:
		card.draw_circle(Vector2(cx, y + big / 2.0), big * 0.42, XTianqiQiyinShow.seal_color(str(r.key)))
	y += big + 8
	var name := str(r.seal)
	var nw := head.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD_MAX).x
	card.draw_string(head, Vector2(cx - nw / 2.0, y + XUiSkin.FS_CARD_MAX * 0.86), name, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD_MAX, XUiSkin.TEXT)
	y += XUiSkin.FS_CARD_MAX + 8
	for ln in _card_lines(r):
		var t := str(ln[0])
		var fs := int(ln[2])
		var lw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		card.draw_string(body, Vector2(cx - lw / 2.0, y + fs * 0.9), t, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2, fs, ln[1])
		y += fs + 8
	# 本印封存
	var bottom := button_rect(0).position.y - XUiSkin.GRID if not buttons.is_empty() else cr.size.y - pad
	if y + 64 <= bottom:
		y += 10
		card.draw_string(body, Vector2(pad, y + XUiSkin.FS_AUX_MAX * 0.9), "本印封存", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
		y += XUiSkin.FS_AUX_MAX + 8
		card.draw_line(Vector2(pad, y), Vector2(w - pad, y), Color(XUiSkin.LINE, 0.22), 1.0)
		y += 6
		var lines := sealed_lines(r)
		if lines.is_empty():
			if y + 28 <= bottom:
				card.draw_string(body, Vector2(pad, y + 19), "这一印没有封着的东西", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_3)
		for ln in lines:
			if y + 28 > bottom:
				break
			card.draw_string(body, Vector2(pad, y + 19), str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, XUiSkin.TEXT)
			var v := "×%d" % int(ln[1])
			var vw := num.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			card.draw_string(num, Vector2(w - pad - vw, y + 20), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, XUiSkin.GOLD_LIGHT)
			y += 28
	# 入口
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var br := button_rect(i)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(br.size.y / 2.0))
		if bool(b.get("primary", false)) and not bool(b.get("disabled", false)):
			sb.bg_color = XUiSkin.SEL_FILL
			sb.shadow_color = Color(XUiSkin.SEL_FILL, 0.5)
			sb.shadow_size = 7
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(XUiSkin.LINE, 0.55)
			sb.set_border_width_all(1)
		sb.draw(ci, br)
		if i == button and not rules_open:
			XUiSkin.draw_select(ci, br.grow(3), XUiSkin.breath_alpha())
		var t := str(b.get("text", ""))
		var fit := XSkinList.fit_text(body, t, br.size.x - 24, XUiSkin.FS_LIST, 15)
		var tw := body.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
		card.draw_string(body, Vector2(br.position.x + (br.size.x - tw) / 2.0, br.position.y + br.size.y / 2.0 + fit[1] * 0.36), fit[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], XUiSkin.TEXT_3 if bool(b.get("disabled", false)) else XUiSkin.TEXT)
	card.draw_set_transform(Vector2.ZERO)


## 牌上名字下面几行：[文字, 颜色, 字号]
static func _card_lines(r: Dictionary) -> Array:
	var st := int(r.get("state", 0))
	var out := [[STATE_TEXT[clampi(st, 0, 2)], [XUiSkin.TEXT_3, XUiSkin.GOLD, XUiSkin.UP][clampi(st, 0, 2)], XUiSkin.FS_AUX_MAX]]
	if str(r.get("cond", "")) != "":
		out.append([str(r.cond), XUiSkin.TEXT_2, 15])
	if bool(r.get("restless", false)):
		out.append(["躁动中", XUiSkin.DOWN, 15])
	return out


## 本印封存的几行：[名字, 件数]
static func sealed_lines(r: Dictionary) -> Array:
	var out := []
	if int(r.get("set", 0)) > 0:
		out.append(["封着的套装件", int(r.set)])
	if int(r.get("weapon", 0)) > 0:
		out.append(["封着的毕业武器", int(r.weapon)])
	return out


## 右上：印钥、印屑、印库件数
func currency_pairs() -> Array:
	var s := state
	if s == null:
		return []
	return [["印钥", str(XTianqiQiyin.keys(s))], ["印屑", str(XTianqiQiyin.shards(s))], ["印库", "%d 件" % XTianqiQiyin.progress(s).bag.size()]]


func _draw_top() -> void:
	var v := view()
	var m := XSkinLayout.margin_for(v.x)
	top.draw_string(XUiSkin.font("title"), Vector2(m, 14 + 34 * 0.92), "七印祭坛", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE, XUiSkin.TEXT)
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var x := v.x - m
	var pairs := currency_pairs()
	for k in range(pairs.size() - 1, -1, -1):
		var pair: Array = pairs[k]
		var val := str(pair[1])
		var vw := num.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		x -= vw
		top.draw_string(num, Vector2(x, 42), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, XUiSkin.GOLD_LIGHT)
		var nw := body.get_string_size(str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		x -= nw + 6
		top.draw_string(body, Vector2(x, 42), str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_2)
		x -= 18


## 「怎么玩」：五条规则，下面写这一印的里副本和规则、进一次花几把印钥
func rules_lines() -> Array:
	var out := []
	for t in RULES:
		out.append(["◆", t])
	out.append(["◆", "进一次里副本花 %d 把印钥，输了不退" % int(XTianqiQiyin.data().get("keys", {}).get("cost", 1))])
	return out


func _draw_rules() -> void:
	if not rules_open:
		return
	var v := view()
	rules.draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.6))
	var w := 640.0
	var h := 420.0
	var box := Rect2(roundf((v.x - w) / 2.0), roundf((v.y - h) / 2.0) - 8, w, h)
	var ci := rules.get_canvas_item()
	XUiSkin.shadow_style().draw(ci, box)
	XUiSkin.panel_style().draw(ci, box)
	var head := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var pad := float(XUiSkin.PAD_LG)
	var x := box.position.x + pad
	var y := box.position.y + pad
	rules.draw_string(head, Vector2(x, y + XUiSkin.FS_CARD * 0.86), "怎么玩", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD, XUiSkin.TEXT)
	y += XUiSkin.FS_CARD + 16
	for ln in rules_lines():
		rules.draw_string(body, Vector2(x, y + 17), str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, XUiSkin.GOLD)
		rules.draw_string(body, Vector2(x + 22, y + 17), str(ln[1]), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2 - 22, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT)
		y += 32
	var r := current()
	if r.is_empty():
		return
	y += 6
	rules.draw_line(Vector2(x, y), Vector2(box.end.x - pad, y), Color(XUiSkin.LINE, 0.22), 1.0)
	y += 12
	rules.draw_string(body, Vector2(x, y + 18), "%s · %s" % [str(r.seal), str(r.place)], HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
	y += 30
	var para := TextParagraph.new()
	para.width = w - pad * 2
	var rt := "规则「%s」：%s" % [str(r.rule_name), str(r.rule_text)]
	para.add_string(rt, body, 16)
	for li in para.get_line_count():
		var rg := para.get_line_range(li)
		rules.draw_string(body, Vector2(x, y + 17), rt.substr(rg.x, rg.y - rg.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, XUiSkin.TEXT_2)
		y += 24
