class_name XActorAdvancedScene
extends Control
## 角色进阶（Star_ActorAdvanced 的 Scene_ActorAdvanced；兑换大厅奉神老妪 Map132 EV6「进阶」）。数据与规则在 XAdvance。
## 版面按冻结 v0.28 浏览器参照（tests/fixtures/actor_advanced_oracle.json，ui_reference/review_system_pages.js 的 actor_advanced）：
## - 名单 (0,0,426,720)：队伍全体名字 x=6、行高 36，开场选第 1 行；状态 (426,0,854,720)；金钱 (0,656,426,64)；
##   底部「进阶」(426.67,656,854,64，压在状态窗下沿，开场无光标)；确认窗 Window_SaveConfirm (568,292,144,136)「是否进阶」「是／否」。
## - 状态（内容宽 826，column2x=420）：SV 战斗图（第 0 行、锚点居中、窗内 (82.6,82.6)、在窗口底层；每 12 帧按 0,1,2,1 换格）；
##   （带空格的横坐标按浏览器字宽 XActorBook.js_width 算：本工程字体空格 7、原版 7.21）
##   x=140 名字／等级／进阶次数／最大进阶次数；y=144 起 8 项能力（系统色标签在 0／252／504，值在「标签＋两空格」之后，第 1 行第三列「当前值」）；
##   y=288 有下一阶时左栏「进阶需求:」物品（图标＋名字＋「xN」）、「等级:N」、金钱（图标 3781），右栏 x=420「进化技能:」与技能；已满只写「已达最大进阶次数」。
## - 操作：名单移动重画状态与金钱；确定 → 有下一阶开底部，已满原地；取消关闭。底部确定 → 条件满足开确认窗，否则提示「进阶条件未达成」回名单；
##   底部取消回名单。确认「是」→ 进阶、提示「进阶完成」、回名单；「否」／取消 → 回名单。
## O-094（可回退，XAdvance.SHOW_MISSING／MAX_BUZZER）：条件不足时提示列出缺项；已满时确定放蜂鸣（原版无反馈）。
## 【cc·白龙_12·未经审查】云裳 174（installNativeYunshangRuntime.js 第 561～583 行的三个包装，规则在 XYunshangOrders）：
## - 底部确定（onBottomConfirmOk 包装，不调原来的）：底部窗关掉；条件不够（Y.advanceRequirements）蜂鸣＋提示原因、回名单；
##   够了在画面正中开 XYunChoicesWindow 逐件选背包里的天衣——第一行「选择进阶所需天衣 n/N」（灰）＋没选过的天衣「名字　编号K」，
##   取消回名单、选的作废；选够开确认窗「消耗N件天衣，确认进阶」。
## - 确认「是」（onConfirmOk 包装）：XYunshangOrders.advance（扣碎片、移除所选天衣、账本进阶＋1，提示「云裳完成第N次进阶」），出错蜂鸣＋提示；
##   不走进阶表那一行的学技能、扣金钱。「否」／取消：选的作废。
## - 状态窗（drawAllContents 包装）：还有下一阶时，第 12 行起用 18 号字写「背包天衣×N（确认时选择）」「已装备的天衣须先卸下」。
## 天启篇五条悟专属试炼（XTianqiGojoTrial，设计 v0.3）：进阶需求下多一行「试炼：怀玉（未通过／已通过）」；底部确定时缺的只有试炼，
## 确认窗写「挑战试炼「怀玉」」，选「是」记下请求、关掉本页（地图上 mv_script 接着开战）。云裳天衣铺里打开的本页不开试炼（allow_trial）。
## 【cc·T307 卡 O·未经审查】天启篇新界面（XUiSkin.on() 且 XSkinRosterPage.ENABLED）：版型二名单页（XSkinRosterPage），状态机一行不改，旧窗藏起：
## - 左名单＝旧名单（头像、名字、Lv、行尾「进阶 1 / 3」，到顶「已到顶」灰字）；中块＝旧状态窗（法阵上的侧视战斗图照旧每 12 帧换格、名字、Lv、职业、
##   「进阶 ◆◇◇ 1 / 3」、现在的能力八项、进阶后学会）；右牌＝进阶需求清单（✓／✗、持有 / 需要、一直写着「还差：…」）＋主按钮「进阶」（旧底部窗：
##   名单确定后焦点落到这枚按钮＝旧 mode bottom）；确认窗换统一确认弹窗；金钱窗进右上货币。
## - 云裳：「要求」里一行「天衣 n / N」，两行小字进右牌；按进阶后中间换成天衣列表逐件选（面包屑「进阶 › 选天衣」，旧 XYunChoicesWindow 不开）。
## - 五条悟：「要求」里试炼一行带 ✓／✗；只缺试炼时主按钮写「挑战试炼」。

signal closed

const LIST_RECT := Rect2(0, 0, 426, 720)
const STATUS_RECT := Rect2(426, 0, 854, 720)
const GOLD_RECT := Rect2(0, 656, 426, 64)
const BOTTOM_RECT := Rect2(1280.0 / 3.0, 656, 854, 64)
const CONFIRM_RECT := Rect2(568, 292, 144, 136)
const LH := 36.0
const ATTR := ["生命", "魔法", "力量", "物防", "智力", "魔防", "敏捷", "幸运"]
const GOLD_ICON := 3781
const BOTTOM_TEXT := "                                            进阶"
const CONFIRM_TEXT := "是否进阶"
const SPRITE_TICK := 12
const PATTERNS := [0, 1, 2, 1]

var mode := "list"          # list / bottom / confirm / yun（云裳选天衣）
var confirm_text := CONFIRM_TEXT
var trial_tier := 0         # 确认窗是「挑战试炼」时是第几阶（XTianqiGojoTrial）
var allow_trial := true     # 云裳天衣铺里打开时为 false：关页后没人接着开战
var yun_win: XYunChoicesWindow
var yun_selection = null    # 云裳选好的天衣 {actor, stage, items}（_yunAdvanceSelection）
var index := 0
var top := 0
var bottom := -1
var confirm_index := 0
var members: Array = []
var shown_actor: XActor     # 状态窗画着的角色（Scene_ActorAdvanced._windowIdx 对应）
var sprite: Sprite2D
var sprite_count := 0       # _spriteFrameCount（不随换人清零）
var list_win: XMVWindow
var status_win: XMVWindow
var gold_win: XMVWindow
var bottom_win: XMVWindow
var confirm_win: XMVWindow
var confirm_back: Control
var confirm_background: Control
var skin: XSkinRosterPage       # T307 新界面（关着为 null）
var yun_rows: Array = []        # 新界面选天衣：旧选择窗的行（第 0 行是「选择进阶所需天衣 n/N」）
var _yun_chosen: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	gold_win = XMVWindow.make(self, GOLD_RECT, op, _paint_gold)
	bottom_win = XMVWindow.make(self, BOTTOM_RECT, op, _paint_bottom)
	# MV WindowLayer 会清掉确认窗矩形内下层窗口的内容；保留菜单底图（同存读档页）
	confirm_back = Control.new()
	confirm_back.clip_contents = true
	confirm_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(confirm_back)
	confirm_background = get_child(0).duplicate()
	confirm_back.add_child(confirm_background)
	confirm_background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	confirm_win = XMVWindow.make(self, CONFIRM_RECT, op, _paint_confirm)
	confirm_win.visible = false
	for w in [list_win, bottom_win, confirm_win]:
		w.canvas.blink = true
	# addChildToBack：精灵在窗口皮肤之下
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	sprite.centered = true
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	status_win.add_child(sprite)
	members = XState.current.members()
	XTianqiGojoTrial.request(0)
	if XUiSkin.on() and XSkinRosterPage.ENABLED:
		_skin_build()
	_select(0)


func rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


func current_actor() -> XActor:
	return members[index] if index >= 0 and index < members.size() else null


func _refresh() -> void:
	confirm_back.visible = confirm_win.visible
	confirm_back.position = confirm_win.position
	confirm_back.size = confirm_win.size
	confirm_background.position = -confirm_back.position
	confirm_background.size = size
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + rows() < members.size()
	for w in [list_win, status_win, gold_win, bottom_win, confirm_win]:
		w.refresh()
	if skin != null:
		_skin_sync()


## Window_ActorAdvancedStatus.setupWhenCheck → drawAllContents：换图并定在第 1 格，缩放复位后由 update 重算
func _draw_status() -> void:
	shown_actor = current_actor()
	if shown_actor != null:
		var p := XDB.img_path("sv_actors", str(shown_actor.data().get("battlerName", "")))
		sprite.texture = load(p) if p != "" else null
	else:
		sprite.texture = null
	sprite.visible = sprite.texture != null
	var w := status_win.canvas.size.x
	sprite.position = Vector2(w / 10.0, w / 10.0)
	sprite.scale = Vector2.ONE
	_set_frame(1)
	_refresh()


func _set_frame(pattern: int) -> void:
	if sprite.texture == null:
		return
	var cw := sprite.texture.get_width() / 9.0
	var ch := sprite.texture.get_height() / 6.0
	sprite.region_rect = Rect2(pattern * cw, 0, cw, ch)


## Window_ActorAdvancedStatus.update（每帧）：每 12 帧按 0,1,2,1 换格；格宽大于内容宽一半才缩小
func _physics_process(_delta: float) -> void:
	if skin != null and sprite_count % SPRITE_TICK == 0:
		skin.center_view.queue_redraw()
	if sprite.texture == null:
		return
	if sprite_count % SPRITE_TICK == 0:
		_set_frame(PATTERNS[floori(sprite_count / float(SPRITE_TICK)) % 4])
	var cw := sprite.texture.get_width() / 9.0
	var half := status_win.canvas.size.x / 2.0
	var k := half / cw if cw > half else 1.0
	_v108(k, cw)
	if shown_actor != null and XYunshang.own(shown_actor):
		k = yunshang_scale()  # 云裳 Window_ActorAdvancedStatus.update 包装（原 update 之后）：按 CodexSV 档 Yunshang 缩放
	if v108_scale > 0.0 and not (shown_actor != null and XYunshang.own(shown_actor)):
		k = v108_scale
	sprite.scale = Vector2(k, k)
	sprite_count += 1


## v0.62 Codex_MiraRavenMultiFrame v1.08 包装 Window_ActorAdvancedStatus.update（原 update 之后、云裳包装之前）：战斗图是登记了
## 归一档的 9×6 图、格宽大于 64（且与档宽差不超过 1）时，按图鉴同尺寸（归一缩放×bookScale）显示，只缩小不放大；锚点改左上、
## 平滑采样，中线对齐 w/10+32、脚底对齐 w/10+64（老角色 64px 格的位置）。实际只碰到流萤 179（128px 格，原生约是老角色两倍大）。
## O-300（进阶界面大图）：ADV_V108 = false 回到 v0.28（原生大小）。
static var ADV_V108 := true

func _v108(native_k: float, cw: float) -> void:
	var w := status_win.canvas.size.x
	var key := str(shown_actor.data().get("battlerName", "")) if shown_actor != null else ""
	var p: Array = XAppearance.profile_of(key)
	var on := ADV_V108 and p.size() >= 6 and float(p[0]) > 64 and absf(cw - float(p[0])) <= 1.0
	var sc := 0.0
	if on:
		var b := Rect2(p[2], p[3], p[4] - p[2], p[5] - p[3])
		sc = minf((p[6] if p.size() > 6 else XAppearance.PROFILE_H) / b.size.y, (p[7] if p.size() > 7 else XAppearance.PROFILE_W) / b.size.x)
		sc *= float(XAppearance.BOOK_SCALE.get(key, 1.0))
		on = sc < native_k - 1e-6
		if on:
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.position = Vector2(w / 10.0 + 32.0 - (b.position.x + b.end.x) / 2.0 * sc, w / 10.0 + 64.0 - b.end.y * sc)
	if not on:
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(w / 10.0, w / 10.0)
	v108_scale = sc if on else 0.0


var v108_scale := 0.0  # 本帧 v1.08 用的缩放（0＝没用）


## CodexSV.scaleFor(profiles.Yunshang)：可见高缩到 72、宽 129，取小
static func yunshang_scale() -> float:
	if XYunshang.art_path("sv_actors", "Yunshang") != "":
		return 1.0
	var p: Array = XAppearance.PROFILES.Yunshang
	return minf(XAppearance.PROFILE_H / float(p[5] - p[3]), XAppearance.PROFILE_W / float(p[4] - p[2]))


# ---- 绘制 ----
func _paint_list(c: XMVCanvas) -> void:
	if index >= top and index < top + rows():
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "list")
	for i in range(top, mini(top + rows(), members.size())):
		c.text(members[i].display_name(), 6, (i - top) * LH, c.size.x - 12)


func _paint_status(c: XMVCanvas) -> void:
	var a := shown_actor
	if a == null:
		return
	var s := XState.current
	var w := c.size.x
	var pad := XMVWindow.PADDING
	var c2 := w / 2.0 + pad / 2.0
	var cw := w / 2.0 - pad
	var y := 0.0
	for t in [a.display_name(), "等级:%d" % a.level, "进阶次数:%d" % XAdvance.rank(s, a.actor_id), "最大进阶次数:%d" % XAdvance.max_text(s, a.actor_id)]:
		c.text(t, c2 / 3.0, y, cw)
		y += LH
	# 三列：标签 x、行；值在「标签＋两空格」之后
	var cols := [0.0, c2 * 3.0 / 5.0, c2 * 6.0 / 5.0]
	var cells := [[0, 0, 0], [1, 1, 0], [2, 0, 1], [3, 1, 1], [6, 2, 1], [4, 0, 2], [5, 1, 2], [7, 2, 2]]
	for cell in cells:
		var lx: float = cols[cell[1]]
		var ly: float = y + LH * cell[2]
		c.text(ATTR[cell[0]], lx, ly, cw, "left", XUI.SYSTEM)
		c.text(str(roundi(a.param(cell[0]))), lx + XActorBook.js_width(ATTR[cell[0]] + "  ", XUI.FONT_SIZE), ly, cw)
	c.text("当前值", cols[2], y, cw)
	y += LH * 4
	var r = XAdvance.row(s, a.actor_id)
	if r == null:
		c.text("已达最大进阶次数", 0, y, cw)
		return
	var top_y := y
	c.text("进阶需求:", 0, y, cw)
	y += LH
	for p in r.items:
		var item := XDB.rec("Items", int(p[0]))
		_item_name(c, item, 0, y, cw)
		c.text("x%d" % int(p[1]), XActorBook.js_width(str(item.get("name", "")) + "      ", XUI.FONT_SIZE), y, cw)
		y += LH
	c.text("等级:%d" % int(r.level), 0, y, cw)
	y += LH
	_currency(c, int(r.gold), 0, y, cw * 2)
	if XTianqiGojoTrial.applies(s, a):
		var tier := XAdvance.rank(s, a.actor_id) + 1
		y += LH
		c.text("试炼:%s（%s）" % [XTianqiGojoTrial.trial_name(tier), "已通过" if XTianqiGojoTrial.has_passed(s, tier) else "未通过"], 0, y, cw * 2)
	y = top_y
	c.text("进化技能:", c2, y, cw)
	y += LH
	for id in r.learn:
		_item_name(c, XDB.rec("Skills", int(id)), c2, y, cw)
		y += LH
	if XYunshang.own(a) and XYunshang.stage(a) < XYunshangOrders.ADVANCE.size():
		c.text("背包天衣×%d（确认时选择）" % XYunshangOrders.needed(a), 0, LH * 12, cw, "left", XUI.TEXT, 18)
		c.text("已装备的天衣须先卸下", 0, LH * 13, cw, "left", XUI.TEXT, 18)


## Window_Base.drawItemName：图标 (x+2, y+2)，名字 x+36（品质色）
func _item_name(c: XMVCanvas, item: Dictionary, x: float, y: float, width: float) -> void:
	if item.is_empty():
		return
	c.icon(int(item.get("iconIndex", 0)), x + 2, y + 2)
	c.text(str(item.get("name", "")), x + 36, y, width - 36, "left", XQuality.list_color(item))


## drawCurrencyValue：图标 3781 在 x，「数值单位」在 x＋单位宽×2/3
func _currency(c: XMVCanvas, value: int, x: float, y: float, width: float) -> void:
	var unit := str(XDB.system().get("currencyUnit", ""))
	var uw := minf(80.0, c.text_width(unit))
	c.text(str(value) + unit, x + uw * 2.0 / 3.0, y, width - uw - 6)
	c.icon(GOLD_ICON, x, y)


func _paint_gold(c: XMVCanvas) -> void:
	_currency(c, XState.current.gold, 0, 0, (c.size.x / 2.0 - XMVWindow.PADDING) * 2)


func _paint_bottom(c: XMVCanvas) -> void:
	if bottom >= 0:
		c.cursor(Rect2(0, 0, c.size.x, LH), mode == "bottom")
	# 行首 44 个空格按原版空格宽折成横坐标（同修炼页底部），免得「进阶」随本工程字体的空格宽偏左
	var word := BOTTOM_TEXT.strip_edges(true, false)
	var pad := (BOTTOM_TEXT.length() - word.length()) * XTrainingScene.SPACE_W
	c.text(word, 6 + pad, 0, c.size.x - 12 - pad)


func _paint_confirm(c: XMVCanvas) -> void:
	var t := XMVText.new(confirm_text, 6, 0, c.size.x)
	t.run()
	XMVText.paint(c, t.glyphs)
	for i in range(2):
		var y := LH * (i + 1)
		if i == confirm_index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "confirm")
		c.text(["是", "否"][i], 6, y, c.size.x - 12, "center")


# ---- 操作 ----
func ok() -> void:
	match mode:
		"list":
			var a := current_actor()
			if a == null:
				return
			if XAdvance.row(XState.current, a.actor_id) == null:
				# onRangeOk 没有下一阶：名单原地重新活动（O-094：蜂鸣）
				XSound.system(3 if XAdvance.MAX_BUZZER else 1)
				return
			XSound.system(1)
			# startBottomConfirmWindow
			XSound.system(1)
			mode = "bottom"
			bottom = 0
			bottom_win.visible = true
			_refresh()
		"bottom":
			XSound.system(1)
			if XYunshang.own(current_actor()):
				_yun_bottom()
				return
			# onBottomConfirmOk
			XSound.system(1)
			var s := XState.current
			var lack := lack_of(s, current_actor())
			bottom = -1
			trial_tier = XTianqiGojoTrial.challengeable(s, current_actor(), lack) if allow_trial else 0
			if lack.is_empty() or trial_tier > 0:
				XSound.system(1)
				confirm_text = CONFIRM_TEXT if trial_tier == 0 else "挑战试炼「%s」" % XTianqiGojoTrial.trial_name(trial_tier)
				mode = "confirm"
				confirm_index = 0
				confirm_win.visible = true
			elif XGarou.own(current_actor()):
				# 饿狼 onBottomConfirmOk 包装：蜂鸣＋$gameMessage.add(原因)，不走原确认、不出「进阶条件未达成」；
				# 原版菜单里没有消息窗，这句回地图才出，重制当场右上角提示（同 O-094）
				XSound.system(3)
				mode = "list"
				XToast.show_text(str(lack[0]), true)
			else:
				XSound.system(1)
				mode = "list"
				XToast.show_text(XAdvance.fail_text(lack), true)
			_refresh()
		"confirm":
			XSound.system(1)
			if confirm_index == 1:
				_close_confirm()
				return
			if trial_tier > 0:  # 天启篇五条悟：挑战试炼，关掉本页由地图开战
				XTianqiGojoTrial.request(trial_tier)
				_close_confirm()
				closed.emit()
				return
			# onConfirmOk
			if XYunshang.own(current_actor()):
				_yun_confirm()
			else:
				XAdvance.advance(XState.current, current_actor())
				XToast.show_text(XAdvance.DONE_TEXT, true)
			_close_confirm()
			_draw_status()


func _close_confirm() -> void:
	confirm_win.visible = false
	trial_tier = 0
	yun_selection = null
	mode = "list"
	_refresh()


# ---- 云裳：底部确定选天衣、确认进阶 ----
func _yun_bottom() -> void:
	var s := XState.current
	var a := current_actor()
	var why := XYunshangOrders.requirements(s, a)
	bottom = -1
	bottom_win.visible = false
	if why != "":
		XSound.system(3)
		XToast.show_text(why, true)
		mode = "list"
		_refresh()
		return
	_yun_pick(a, [])


func _yun_pick(a: XActor, chosen: Array) -> void:
	var s := XState.current
	var need := XYunshangOrders.needed(a)
	if chosen.size() == need:
		_yun_close_win()
		yun_selection = {"actor": a, "stage": XYunshang.stage(a), "items": chosen}
		# startConfirmWindow：确定音，确认窗换字
		XSound.system(1)
		confirm_text = "消耗%d件天衣，确认进阶" % need
		mode = "confirm"
		confirm_index = 0
		confirm_win.visible = true
		_refresh()
		return
	var rows := [{"text": "选择进阶所需天衣 %d/%d" % [chosen.size(), need], "enabled": false}]
	for e in XYunshangOrders.owned(s):
		if not chosen.any(func(x): return is_same(x, e)):
			rows.append({"text": XYunshangOrders.robe_label(s, e), "item": e})
	_yun_close_win()
	mode = "yun"
	if skin != null:   # T307：不开旧选择窗，中间列表换成天衣（同一份行）
		yun_rows = rows
		_yun_chosen = chosen
		_refresh()
		skin.list.select(0, false)
		return
	_refresh()
	yun_win = XYunChoicesWindow.for_rows(self, rows)
	var w := yun_win
	w.chosen.connect(func(i): if w == yun_win: _yun_pick(a, chosen + [w.entries[i].item]))
	w.cancelled.connect(func(): if w == yun_win:
		_yun_close_win()
		yun_selection = null
		mode = "list"
		_refresh())


func _yun_close_win() -> void:
	if yun_win and is_instance_valid(yun_win):
		yun_win.queue_free()
	yun_win = null


func _yun_confirm() -> void:
	var a := current_actor()
	var sel = yun_selection
	var why := "进阶选择已失效，请重新选择"
	if sel != null and sel.actor == a and int(sel.stage) == XYunshang.stage(a):
		why = XYunshangOrders.advance(XState.current, sel.items)
	if why != "":
		XSound.system(3)
		XToast.show_text(why, true)


func cancel() -> void:
	XSound.system(2)
	match mode:
		"list":
			closed.emit()
		"bottom":
			# onBottomConfirmCancel
			bottom = -1
			mode = "list"
			_refresh()
		"confirm":
			_close_confirm()


## 名单是 Window_Selectable、不接管 pageup／pagedown：照 cursorPagedown／cursorPageup 整页翻，光标变了就重画状态（ui11）
func page(d: int) -> void:
	var r := XMenu.page(top, index, members.size(), rows(), d)
	top = r[0]
	if r[1] != index:
		XSound.system(0)
		index = r[1]
		_draw_status()
	_refresh()


func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(i, top, rows())
	# Scene_ActorAdvanced.update：名单光标变了就重画状态与金钱
	_draw_status()


func _move(d: int, wrap: bool) -> void:
	match mode:
		"list":
			if members.is_empty():
				return
			var i := XMenu._move(index, d, members.size(), wrap)
			if i != index:
				XSound.system(0)
				_select(i)
		"confirm":
			var i := XMenu._move(confirm_index, d, 2, wrap)
			if i != confirm_index:
				XSound.system(0)
				confirm_index = i
				_refresh()


func _gui_input(event: InputEvent) -> void:
	if skin != null:   # 新界面的点击由各组件自己接；右键＝取消
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			_skin_cancel()
		return
	if not (event is InputEventMouseButton and event.pressed) or mode == "yun":
		return
	var p: Vector2 = event.position
	var pad := XMVWindow.PADDING
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "list" and LIST_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, members.size() - rows()))
				_refresh()
		MOUSE_BUTTON_LEFT:
			var rect: Rect2 = {"list": LIST_RECT, "bottom": BOTTOM_RECT, "confirm": CONFIRM_RECT}[mode]
			if not rect.grow(-pad).has_point(p):
				return
			var row := floori((p.y - rect.position.y - pad) / LH)
			match mode:
				"list":
					var i := top + row
					if i >= 0 and i < members.size():
						if i == index:
							ok()
						else:
							XSound.system(0)
							_select(i)
				"bottom":
					if row == 0:
						ok()
				"confirm":
					var i := row - 1
					if i == 0 or i == 1:
						if i == confirm_index:
							ok()
						else:
							XSound.system(0)
							confirm_index = i
							_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if skin != null and _skin_input(event):
		XKeyMap.handled(self)
		return
	if mode == "yun":
		return
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif mode == "list" and XMenu.page_dir(event) != 0:
		XKeyMap.handled(self)
		page(XMenu.page_dir(event))


# ---- T307 卡 O：天启篇新界面（版型二名单页）----
## 玩家可见新字（待小A 审）
const T_TITLE := "进阶"
const T_TOP := "已到顶"
const T_NOW := "现在的能力"
const T_LEARN := "进阶后学会"
const T_REQ := "要求"
const T_LACK := "还差："
const T_TRIAL_BTN := "挑战试炼"
const T_CRUMB_YUN := "选天衣"
const T_COST := "消耗："
const T_NONE := "无"


func _skin_build() -> void:
	skin = XSkinRosterPage.new()
	skin.title = T_TITLE
	add_child(skin)
	skin.center_draw = _skin_center
	skin.show_center_list(false)
	skin.roster_changed.connect(func(i):
		if i == index:
			return
		if mode == "bottom":   # 旧底部窗开着时换人＝先回名单
			bottom = -1
			mode = "list"
		if mode == "list":
			XSound.system(0)
			_select(i))
	skin.roster_activated.connect(func(i):
		if i == index and mode in ["list", "bottom"]:
			ok())
	skin.card_button.connect(func(_i): _skin_card_ok())
	skin.list.index_changed.connect(func(_i): if mode == "yun": skin.queue_redraw())
	skin.list.activated.connect(func(i): if mode == "yun": _skin_yun_choose(i))


## 主按钮：名单上点＝先到底部（旧确定）再按；底部上点＝按
func _skin_card_ok() -> void:
	if mode == "list":
		var a := current_actor()
		if a == null or XAdvance.row(XState.current, a.actor_id) == null:
			XSound.system(3)
			return
		ok()
	if mode == "bottom":
		ok()


func _skin_cancel() -> void:
	if mode == "yun":
		_skin_yun_cancel()
		return
	cancel()


func _skin_yun_choose(i: int) -> void:
	var r := i + 1   # 第 0 行是「选择进阶所需天衣 n/N」，列表里不放
	if r <= 0 or r >= yun_rows.size():
		return
	XSound.system(1)
	_yun_pick(current_actor(), _yun_chosen + [yun_rows[r].item])


func _skin_yun_cancel() -> void:
	XSound.system(2)
	yun_rows = []
	_yun_chosen = []
	yun_selection = null
	mode = "list"
	_refresh()


## 新界面先吃的按键：弹窗、Y；选天衣时上下、确定、取消；底部时上下不动（同旧）
func _skin_input(event: InputEvent) -> bool:
	if skin.input(event):
		return true
	if mode == "yun":
		if event.is_action_pressed("ui_cancel"):
			_skin_yun_cancel()
		elif event.is_action_pressed("ui_accept"):
			_skin_yun_choose(skin.list.index)
		elif skin.list.handle_input(event):
			XSound.system(0)
		return true
	return false


func _skin_sync() -> void:
	for w in [list_win, status_win, gold_win, bottom_win, confirm_win]:
		w.visible = false
	confirm_back.visible = false
	var s := XState.current
	var rows := []
	for m: XActor in members:
		var r = XAdvance.row(s, m.actor_id)
		if r == null:
			rows.append(XSkinRosterPage.roster_row(m, T_TOP, XUiSkin.TEXT_3))
		else:
			rows.append(XSkinRosterPage.roster_row(m, "进阶 %d / %d" % [XAdvance.rank(s, m.actor_id), XAdvance.max_text(s, m.actor_id)], XUiSkin.GOLD_LIGHT))
	skin.set_roster(rows, index)
	var yun := mode == "yun"
	skin.show_center_list(yun)
	skin.set_crumb([T_TITLE, T_CRUMB_YUN] if yun else [])
	if yun:
		skin.list_title = str(yun_rows[0].text) if not yun_rows.is_empty() else ""
		var items := []
		for k in range(1, yun_rows.size()):
			var it: Dictionary = yun_rows[k].item
			items.append({"text": str(yun_rows[k].text), "icon": int(it.get("iconIndex", XDB.rec("Armors", int(it.get("base", 0))).get("iconIndex", 0)))})
		var keep := clampi(skin.list.index, 0, maxi(items.size() - 1, 0))
		skin.set_items(items, keep)
	else:
		skin.list_title = ""
	var f := "roster"
	if mode == "bottom":
		f = "card"
	elif yun:
		f = "list"
	skin.set_focus(f)
	skin.set_card(skin_card())
	if mode == "bottom":
		skin.card.button_index = 0
		skin.card.queue_redraw()
	if mode == "confirm":
		var fresh := skin.dialog == null
		var title := confirm_text
		if yun_selection != null:   # 新页弹窗标题按小A文字审加空格；旧确认窗字照旧（参照用例比它）
			title = "消耗 %d 件天衣，确认进阶" % (yun_selection.items as Array).size()
		var dlg := skin.ask({"title": title, "body": skin_confirm_body(), "buttons": ["确定", "取消"], "index": confirm_index})
		if fresh:
			dlg.chosen.connect(func(i):
				confirm_index = i
				ok())
			dlg.index_changed.connect(func(i):
				if i != confirm_index:
					confirm_index = i
					XSound.system(0))
			dlg.cancelled.connect(cancel)
	else:
		skin.close_dialog()
	var h := [["确定", "进阶"], ["取消", "离开"]]
	match mode:
		"bottom":
			h = [["确定", skin_button_text()], ["取消", "返回"]]
		"yun":
			h = [["确定", "选这件"], ["取消", "返回"]]
		"confirm":
			h = [["← / →", "切换"], ["确定", "选择"], ["取消", "返回"]]
	skin.set_hint_list(h)
	skin.center_view.queue_redraw()
	skin.layout.left.queue_redraw()


## 主按钮的字：只缺五条悟试炼（且这页开得了试炼）时「挑战试炼」，否则「进阶」
## 缺什么：一般角色＝XAdvance.missing；饿狼只看 XGarou.reason（等级、累计突破、四臂进星空的神之触媒）——饿狼进阶走 XGarou.advance，
## 不扣表里的金钱、物品，而天启篇金钱重构给每行套了进阶金钱（XTianqiMoney.advance_gold），missing 会误报「精魂不足」挡住进阶（小A核 T307 P2-2）
static func lack_of(s: XState, a: XActor) -> Array:
	if a != null and XGarou.own(a):
		var why := XGarou.reason(s, a)
		return [why] if why != "" else []
	return XAdvance.missing(s, a)


func skin_button_text() -> String:
	var a := current_actor()
	if a == null:
		return "进阶"
	var s := XState.current
	var lack := lack_of(s, a)
	if allow_trial and not lack.is_empty() and XTianqiGojoTrial.challengeable(s, a, lack) > 0:
		return T_TRIAL_BTN
	return "进阶"


## 确认弹窗的正文：这次会扣掉的东西（旧确认窗只写「是否进阶」）
func skin_confirm_body() -> String:
	var a := current_actor()
	if a == null or trial_tier > 0:
		return ""
	if XYunshang.own(a):
		return ""
	if XGarou.own(a):   # 饿狼只有四臂进星空扣神之触媒 ×1
		return T_COST + "%s ×1" % str(XDB.rec("Items", XGarou.CATALYST).get("name", "")) if XGarou.stage(a) == 5 else ""
	var r = XAdvance.row(XState.current, a.actor_id)
	if r == null:
		return ""
	var parts := []
	for p in r.items:
		parts.append("%s ×%d" % [str(XDB.rec("Items", int(p[0])).get("name", "")), int(p[1])])
	if int(r.gold) > 0:
		parts.append("%s %s" % [str(XDB.system().get("currencyUnit", "")), XMenu._group(int(r.gold))])
	return T_COST + "、".join(parts) if not parts.is_empty() else ""


## 右牌（测试按 T254 3.10 对应表逐行核）：要求清单＋还差＋主按钮；已满只写「已达最大进阶次数」
func skin_card() -> Dictionary:
	var a := current_actor()
	if a == null:
		return {"title": "", "sections": [], "buttons": []}
	var s := XState.current
	var cls := str(XDB.rec("Classes", a.class_id).get("name", ""))
	var d := {"title": a.display_name(), "subtitle": "Lv %s%s" % [XMenu._group(a.level), " · " + cls if cls != "" else ""], "sections": [], "buttons": []}
	var r = XAdvance.row(s, a.actor_id)
	if r == null:
		d.sections = [{"title": "", "rows": [{"text": "已达最大进阶次数", "color": XUiSkin.TEXT_2}]}]
		d.buttons = [{"text": "进阶", "primary": true, "disabled": true}]
		return d
	var lines := []
	var yun := XYunshang.own(a)
	var garou := XGarou.own(a)
	var unit := str(XDB.system().get("currencyUnit", ""))
	if garou:   # 饿狼照 XGarou.reason 列等级、累计突破、（四臂进星空）神之触媒；不列金钱（不扣）
		var st := XGarou.stage(a)
		if st < 6:
			var nx: Dictionary = XGarou.STAGES[st + 1]
			lines.append(_req_line("等级", a.level, int(nx.level), "Lv %d / %d" % [a.level, int(nx.level)]))
			lines.append(_req_line("累计突破", floori(XGarou._raw_breakthroughs()), int(nx.breakthroughs)))
			if st == 5:
				lines.append(_req_line(str(XDB.rec("Items", XGarou.CATALYST).get("name", "")), s.item_count(XGarou.CATALYST), 1))
	elif yun:   # 云裳不走进阶表那一行（不扣物品、金钱）：照 XYunshangOrders.requirements 列等级、人道意志碎片、天衣
		if XYunshang.stage(a) < XYunshangOrders.ADVANCE.size():
			var req: Dictionary = XYunshangOrders.ADVANCE[XYunshang.stage(a)]
			lines.append(_req_line("等级", a.level, int(req.level), "Lv %d / %d" % [a.level, int(req.level)]))
			lines.append(_req_line(str(XDB.rec("Items", XYunshangOrders.SHARD).get("name", "")), s.item_count(XYunshangOrders.SHARD), int(req.shards)))
	else:
		for p in r.items:
			var have := s.item_count(int(p[0]))
			lines.append(_req_line(str(XDB.rec("Items", int(p[0])).get("name", "")), have, int(p[1])))
		lines.append(_req_line("等级", a.level, int(r.level), "Lv %d / %d" % [a.level, int(r.level)]))
		lines.append(_req_line(unit, s.gold, int(r.gold), "%s / %s" % [XMenu._group(s.gold), XMenu._group(int(r.gold))]))
	if XTianqiGojoTrial.applies(s, a):
		var tier := XAdvance.rank(s, a.actor_id) + 1
		var ok_t := XTianqiGojoTrial.has_passed(s, tier)
		lines.append({"left": "%s 试炼：%s（%s）" % ["✓" if ok_t else "✗", XTianqiGojoTrial.trial_name(tier), "已通过" if ok_t else "未通过"], "right": "", "color": XUiSkin.UP if ok_t else XUiSkin.DOWN})
	var secs := [{"title": T_REQ, "lines": lines}]
	var lack: Array = []
	if yun:
		if XYunshang.stage(a) < XYunshangOrders.ADVANCE.size():
			var need := XYunshangOrders.needed(a)
			var own := XYunshangOrders.owned(s).size()
			lines.append(_req_line("天衣", own, need))
			secs.append({"title": "", "rows": [{"text": "背包天衣×%d（确认时选择）" % need, "color": XUiSkin.TEXT_2}, {"text": "已装备的天衣须先卸下", "color": XUiSkin.TEXT_2}]})
		var why := XYunshangOrders.requirements(s, a)
		if why != "":
			lack = [why]
	else:
		lack = lack_of(s, a)
	var btn := skin_button_text()
	var can := lack.is_empty() or btn == T_TRIAL_BTN
	if not lack.is_empty():
		secs.append({"title": "", "rows": [{"text": T_LACK + "、".join(lack.map(func(x): return str(x))), "color": XUiSkin.DOWN}]})
	d.sections = secs
	d.buttons = [{"text": btn, "primary": true, "disabled": not can}]
	return d


func _req_line(name: String, have: int, need: int, right := "") -> Dictionary:
	var ok_ := have >= need
	return {"left": ("✓ " if ok_ else "✗ ") + name, "right": right if right != "" else "%s / %s" % [XMenu._group(have), XMenu._group(need)],
		"color": XUiSkin.UP if ok_ else XUiSkin.DOWN, "right_color": XUiSkin.GOLD_LIGHT if ok_ else XUiSkin.DOWN}


## 中块画的东西（测试按 T254 3.10 对应表核旧状态窗每一项）：名字、等级、职业、进阶次数／最大进阶次数、八项能力、进阶后学会的技能号
func skin_center_data() -> Dictionary:
	var a := shown_actor
	if a == null:
		return {}
	var s := XState.current
	var r = XAdvance.row(s, a.actor_id)
	var params := []
	for k in 8:
		params.append(roundi(a.param(k)))
	return {"name": a.display_name(), "level": a.level, "class": str(XDB.rec("Classes", a.class_id).get("name", "")), "battler": str(a.data().get("battlerName", "")),
		"rank": XAdvance.rank(s, a.actor_id), "max": XAdvance.max_text(s, a.actor_id), "params": params, "learn": (r.learn as Array).map(func(x): return int(x)) if r != null else null}


## 中块：法阵上的侧视战斗图（旧状态窗同一张图、0,1,2,1 每 12 帧）、名字、Lv、职业、进阶次数、八项能力、进阶后学会
func _skin_center(c: Control) -> void:
	var a := shown_actor
	if a == null:
		return
	var cd := skin_center_data()
	var w := c.size.x
	var body := XUiSkin.font("body")
	var head := XUiSkin.font("title")
	var cx := w / 2.0
	var fs_a := XUiSkin.fs(XUiSkin.FS_AUX)
	var fs_l := XUiSkin.fs(19)
	var lh := roundf(fs_a * 1.75)
	var slh := maxf(30.0, fs_a * 1.8)
	var learn: Array = cd.learn if cd.learn != null else []
	var two := learn.size() > 2   # 学会三个以上排两列
	var lrows := ceili(learn.size() / 2.0) if two else maxi(learn.size(), 1)
	# 大字号（130%）放不下时小人和法阵往上收、缩小，下面整体上移（最多 80）
	var need := 206 + fs_a * 1.7 + fs_l * 1.5 + 24.0 + 30.0 + 4 * lh + 14.0 + (30.0 + lrows * slh if cd.learn != null else 0.0)
	var up := clampf(need - (c.size.y - 8.0), 0.0, 80.0)
	XSkinRosterPage.draw_seal(c, Vector2(cx, 150 - up), 92.0 - up * 0.4)
	var pat: int = PATTERNS[floori(sprite_count / float(SPRITE_TICK)) % 4]
	XSkinRosterPage.draw_battler(c, str(cd.battler), pat, Vector2(cx, 158 - up), 132.0 - up * 0.8)
	var ny := 206.0 - up
	var fs_n := XUiSkin.fs(XUiSkin.FS_CARD)
	var fit := XSkinList.fit_text(head, str(cd.name), w - 48, fs_n, 18)
	var tw := head.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
	XUiSkin.ds(c, head, Vector2(cx - tw / 2.0, ny), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT)
	var cls := str(cd["class"])
	var sub := "Lv %s%s" % [XMenu._group(int(cd.level)), "　" + cls if cls != "" else ""]
	tw = body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_a).x
	XUiSkin.ds(c, body, Vector2(cx - tw / 2.0, ny + fs_a * 1.7), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_a, XUiSkin.TEXT_2)
	var rank := int(cd.rank)
	var mx := int(cd.max)
	var pips := ""
	if mx <= 10:
		for k in mx:
			pips += "◆" if k < rank else "◇"
	var adv := "进阶 %s%s / %d" % [pips + " " if pips != "" else "", rank, mx]
	tw = body.get_string_size(adv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_l).x
	XUiSkin.ds(c, body, Vector2(cx - tw / 2.0, ny + fs_a * 1.7 + fs_l * 1.5), adv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_l, XUiSkin.GOLD_LIGHT)
	var y := ny + fs_a * 1.7 + fs_l * 1.5 + 24.0
	var x0 := XUiSkin.PAD_LG
	var iw := w - x0 * 2
	XUiSkin.ds(c, body, Vector2(x0, y + 18), T_NOW, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(17), XUiSkin.GOLD)
	y += 30.0
	for k in 8:
		var col := k % 2
		var row := k / 2
		var px := x0 + col * (iw / 2.0 + 8.0)
		var py := y + row * lh + fs_a
		XUiSkin.ds(c, body, Vector2(px, py), ATTR[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_a, XUiSkin.TEXT_2)
		var v := XMenu._group(int(cd.params[k]))
		var vw := body.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_a).x
		XUiSkin.ds(c, body, Vector2(px + iw / 2.0 - 16.0 - vw, py), v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_a, XUiSkin.TEXT)
	y += 4 * lh + 14.0
	if cd.learn == null:
		return
	XUiSkin.ds(c, body, Vector2(x0, y + 18), T_LEARN, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(17), XUiSkin.GOLD)
	y += 30.0
	if learn.is_empty():
		XUiSkin.ds(c, body, Vector2(x0, y + fs_a), T_NONE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_a, XUiSkin.TEXT_3)
		return
	var colw := (iw / 2.0 - 8.0) if two else iw
	for k in learn.size():
		var lx := x0 + ((k % 2) * (iw / 2.0 + 8.0) if two else 0.0)
		var ly := y + (k / 2 if two else k) * slh
		if ly + slh > c.size.y - 4.0:
			break
		var sk := XDB.rec("Skills", int(learn[k]))
		var ic := XUiSkin.icon(int(sk.get("iconIndex", 0)))
		if ic != null:
			c.draw_texture_rect(ic, Rect2(lx, ly + (slh - 24.0) / 2.0, 24, 24), false)
		var nm := XSkinList.fit_text(body, str(sk.get("name", "")), colw - 32, fs_a, 15)
		XUiSkin.ds(c, body, Vector2(lx + 32, ly + slh / 2.0 + int(nm[1]) * 0.36), str(nm[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(nm[1]), XSkinSkillPage.name_color(sk))
