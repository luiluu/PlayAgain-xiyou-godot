class_name XUiSkin
extends RefCounted
## 【cc·天启篇·未经审查】新界面皮肤层（界面风格提案 v0.7「红乙」，Kyo 2026-11-15 定 D29 红乙、D25 菜单分组、D26 横屏铺满；第 0 期底层）。
## 设计稿：私密设计仓 重制设定/界面风格提案_v0.7/README.md 第二节（打磨）、第三节（颜色）、第四节（实装清单）。
##
## 这里是新界面的「一处定义」：颜色（第三节）、字号四级与行高、间距（8 的倍数）、动效档、三款字体、面板与选中条的画法、菜单底。
## 现有窗口不逐个改：XWindowStyle（MV 窗口框与光标框，约 120 处窗口都走它）、XUI.menu_background、MV 窗口的翻页／滚动箭头
## 在画的那一刻问 on()，开着就改画黑面板＋细线、红乙选中条、黑底；关着一行旧代码都不变。新组件（ui/skin/skin_*.gd）只读这里的常量。
##
## 开关（O-467）：ENABLED＝false 时一律旧界面。true 时只在天启篇存档里（XTianqiLine.open_for：天启篇标记＋发行门）换新皮肤，
## 重制版（玩家现在玩的 0.01.x）、标题画面、西游存档都保持旧界面，等 Kyo 另说才给重制版开。
## 调试强开：FORCE＝true，或调试构建的启动参数 --ui-skin=new（--ui-skin=old 强关），重制版里也能看效果；发行构建不认启动参数。
## GLOBAL_FONT：旧页面的文字也换思源黑体（XUI.font）。第 0 期默认关——旧页面的排版是按方正兰亭量的，换字会挤行；
## 各期把页面按新稿重排后再打开。

static var ENABLED := true
static var FORCE := false
static var GLOBAL_FONT := false

## ---- 收口批（cc/ui-skin-close，Fable／小A 三审 2026-11-15 汇总，Kyo 定）----
## CORE_V2（O-498，换芯）：详情牌里旧说明卡的行过「旧颜色对照表」（legacy_color：纯黄→淡金、大红属性→正文、青蓝说明→次要灰、荧光绿→正文），
## 去掉品质／武器种类／买卖价格行（牌上小字已有，价格只在商店看），装备按「自带／词条／套装／说明」分节；战斗里旧说明卡不再盖行动条。
## false＝详情牌照旧原样灌说明卡的行、战斗说明卡照旧位置。
static var CORE_V2 := true
## TOUCH_V2（O-500，触屏）：底部按键提示触屏时变成能点的胶囊、整页左上「‹」返回、列表手指拖动、进全屏菜单收起虚拟摇杆／AB 键、
## 触屏战斗指令环固定右下（Kyo 定；D171 起由 TOUCH_RING_FIXED 单独管）。false＝同 p1fix（提示只看、没有返回钮、指令环跟着角色）。
static var TOUCH_V2 := true
## TOUCH_RING_FIXED（T126，Kyo 2026-11-17 D171「改回去」）：触屏时战斗指令环固定右下（D41）。false（现在）＝触屏也跟着当前行动的角色，
## 同 p1fix；TOUCH_V2 其余各项不受影响。环跟角色时照旧让开 A／B 键组与右上队伍面板（XBattleScene._place_near_actor）。回退：改 true。
static var TOUCH_RING_FIXED := false
## COMFORT_V2（O-502，舒适）：正文骨白、禁用灰提亮、「优秀」绿调柔、常驻主按钮平时旧金选中才红、行动条选目标去 2Hz 急闪（改 2.4 秒慢呼吸）、
## 队伍血条 5→8px、七印状态字加 ◆／◇／·、u4 组图标选中红底调暗。false＝同 p1fix。
static var COMFORT_V2 := true
## WARM_BG（D44，只出对比图，默认 false＝冷黑）：底、面板、线换暖炭黑（小A审 美化 1）
static var WARM_BG := false
## T309 新界面整体美化总开关（默认 true；false 时逐像素回退至美化前；不改动 WARM_BG 等既有开关的默认常量）
static var POLISH_V1 := true
const POLISH_BG := Color("090808")
const POLISH_PANEL := Color("1e1b1b")
const POLISH_PANEL_LOW := Color("131112")
const POLISH_LINE := Color("b5ab9c")
const POLISH_TEXT_2 := Color("bab4aa")
const POLISH_ORB_HI := Color("38322f")
const POLISH_ORB_LOW := Color("161312")
const POLISH_DOWN := Color("e88252")
const POLISH_MYTHIC := Color("ff5c84")
const POLISH_MYTHIC_RAW := Color("ff483c")
const POLISH_BREATH_TIME := 2.4
const POLISH_BREATH_MIN := 0.82


static func polish_on() -> bool:
	return POLISH_V1 and on()


static func bg_c() -> Color:
	return POLISH_BG if polish_on() else BG


static func panel_c() -> Color:
	return POLISH_PANEL if polish_on() else PANEL


static func panel_low_c() -> Color:
	return POLISH_PANEL_LOW if polish_on() else PANEL_LOW


static func line_c() -> Color:
	return POLISH_LINE if polish_on() else LINE


static func text2_c() -> Color:
	return POLISH_TEXT_2 if polish_on() else TEXT_2


static func orb_hi_c() -> Color:
	return POLISH_ORB_HI if polish_on() else ORB_HI


static func orb_low_c() -> Color:
	return POLISH_ORB_LOW if polish_on() else ORB_LOW


static func down_c() -> Color:
	return POLISH_DOWN if polish_on() else DOWN


static func mythic_c() -> Color:
	return POLISH_MYTHIC if polish_on() else POLISH_MYTHIC_RAW


## 绘制层语义色温映射：不改动既有常量值（保旧测试断言与 POLISH_V1=false 逐像素回退），绘制时统一柔化冷灰/下降橙/神话红
static func paint_color(c: Color) -> Color:
	if not polish_on():
		return c
	if is_equal_approx(c.r, TEXT_2.r) and is_equal_approx(c.g, TEXT_2.g) and is_equal_approx(c.b, TEXT_2.b):
		return Color(POLISH_TEXT_2, c.a)
	if is_equal_approx(c.r, DOWN.r) and is_equal_approx(c.g, DOWN.g) and is_equal_approx(c.b, DOWN.b):
		return Color(POLISH_DOWN, c.a)
	if is_equal_approx(c.r, POLISH_MYTHIC_RAW.r) and is_equal_approx(c.g, POLISH_MYTHIC_RAW.g) and is_equal_approx(c.b, POLISH_MYTHIC_RAW.b):
		return Color(POLISH_MYTHIC, c.a)
	return c


## 共用渐隐分割线（P3）：两端渐隐暖锡／旧金细线，主分隔（gold=true）中点点缀微菱形；POLISH_V1=false 回退为原 1px 平灰线
static func draw_divider(ci: CanvasItem, x0: float, x1: float, y: float, gold := false, alpha := 1.0, legacy_alpha := 0.14) -> void:
	if x1 <= x0 + 2.0 or alpha <= 0.0:
		return
	if not polish_on():
		ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(LINE, legacy_alpha * alpha), 1.0)
		return
	var base := GOLD if gold else POLISH_LINE
	var mid_a := (0.38 if gold else 0.26) * alpha
	var side_a := (0.22 if gold else 0.17) * alpha
	var xs := [x0, lerpf(x0, x1, 0.18), lerpf(x0, x1, 0.50), lerpf(x0, x1, 0.82), x1]
	var als := [0.0, side_a, mid_a, side_a, 0.0]
	for i in 4:
		var c0 := Color(base, als[i])
		var c1 := Color(base, als[i + 1])
		ci.draw_polygon(
			PackedVector2Array([Vector2(xs[i], y - 0.5), Vector2(xs[i + 1], y - 0.5), Vector2(xs[i + 1], y + 0.5), Vector2(xs[i], y + 0.5)]),
			PackedColorArray([c0, c1, c1, c0]))
	if gold and (x1 - x0) >= 64.0:
		var mx := (x0 + x1) * 0.5
		ci.draw_colored_polygon(
			PackedVector2Array([Vector2(mx, y - 2.5), Vector2(mx + 3.0, y), Vector2(mx, y + 2.5), Vector2(mx - 3.0, y)]),
			Color(GOLD, 0.62 * alpha))


## 面板小标题下渐隐微金短线（P3）；POLISH_V1=false 不绘制
static func draw_title_accent(ci: CanvasItem, x: float, y: float, w := 56.0, alpha := 1.0) -> void:
	if not polish_on() or w <= 8.0 or alpha <= 0.0:
		return
	ci.draw_colored_polygon(
		PackedVector2Array([Vector2(x + 2.0, y - 2.0), Vector2(x + 4.5, y), Vector2(x + 2.0, y + 2.0), Vector2(x - 0.5, y)]),
		Color(GOLD, 0.65 * alpha))
	var x0 := x + 7.0
	var xm := x0 + w * 0.58
	var x1 := x0 + w
	var c0 := Color(GOLD, 0.45 * alpha)
	var cm := Color(GOLD, 0.22 * alpha)
	var c1 := Color(GOLD, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y - 0.5), Vector2(xm, y - 0.5), Vector2(xm, y + 0.5), Vector2(x0, y + 0.5)]),
		PackedColorArray([c0, cm, cm, c0]))
	ci.draw_polygon(PackedVector2Array([Vector2(xm, y - 0.5), Vector2(x1, y - 0.5), Vector2(x1, y + 0.5), Vector2(xm, y + 0.5)]),
		PackedColorArray([cm, c1, c1, cm]))


## 共用量条槽（P5）：深炭内凹底槽＋1px 淡暖锡内框＋填充顶缘柔和亮线；POLISH_V1=false 回退为原浅灰条槽
static func draw_gauge(ci: RID, rect: Rect2, ratio: float, fill_col: Color, alpha := 1.0, legacy_bg := Color(1, 1, 1, 0.12), round_r := 3, legacy_flat := false) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var r := clampf(ratio, 0.0, 1.0)
	if not polish_on():
		if legacy_flat:
			RenderingServer.canvas_item_add_rect(ci, rect, legacy_bg)
			var lfw := rect.size.x * r
			if lfw > 0.0:
				RenderingServer.canvas_item_add_rect(ci, Rect2(rect.position, Vector2(lfw, rect.size.y)), Color(fill_col, fill_col.a * alpha))
			return
		var lbg := StyleBoxFlat.new()
		lbg.bg_color = legacy_bg
		lbg.set_corner_radius_all(round_r)
		lbg.draw(ci, rect)
		var lfw2 := rect.size.x * r
		if lfw2 > 0.0:
			var lfg := StyleBoxFlat.new()
			lfg.bg_color = Color(fill_col, fill_col.a * alpha)
			lfg.set_corner_radius_all(round_r)
			lfg.draw(ci, Rect2(rect.position, Vector2(lfw2, rect.size.y)))
		return
	var cr := mini(round_r, maxi(1, int(rect.size.y * 0.5)))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.032, 0.025, 0.024, 0.72 * alpha)
	bg.border_color = Color(0.76, 0.70, 0.62, 0.20 * alpha)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(cr)
	bg.draw(ci, rect)
	var fw := rect.size.x * r
	if fw > 0.5:
		var fc := paint_color(fill_col)
		var fg_rect := Rect2(rect.position, Vector2(fw, rect.size.y))
		var fg := StyleBoxFlat.new()
		fg.bg_color = Color(fc, fc.a * alpha)
		fg.set_corner_radius_all(cr)
		fg.draw(ci, fg_rect)
		if rect.size.y >= 4.0 and fw >= 3.0:
			var hi_x := rect.position.x + minf(1.0, fw * 0.25)
			var hi_w := maxf(1.0, fw - minf(2.0, fw * 0.5))
			RenderingServer.canvas_item_add_rect(ci, Rect2(hi_x, rect.position.y + 0.5, hi_w, 1.0), Color(1.0, 0.96, 0.90, 0.26 * alpha * fc.a))


## 共用圆角暖金滚动条（P6）；POLISH_V1=false 回退为原直角灰条
static func draw_scrollbar(ci: CanvasItem, track: Rect2, thumb_y: float, thumb_h: float, legacy_track := Color(1, 1, 1, 0.06), legacy_thumb := Color(0, 0, 0, 0)) -> void:
	if track.size.x <= 0.0 or track.size.y <= 0.0:
		return
	var lt := legacy_thumb if legacy_thumb.a > 0.0 else Color(LINE, 0.55)
	if not polish_on():
		if legacy_track.a > 0.0:
			ci.draw_rect(track, legacy_track)
		ci.draw_rect(Rect2(track.position.x, thumb_y, track.size.x, thumb_h), lt)
		return
	var rid := ci.get_canvas_item()
	var rad := maxi(2, int(track.size.x * 0.5))
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.04, 0.033, 0.032, 0.52)
	tsb.border_color = Color(0.76, 0.70, 0.62, 0.14)
	tsb.set_border_width_all(1)
	tsb.set_corner_radius_all(rad)
	tsb.draw(rid, track)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.78, 0.69, 0.54, 0.68)
	gsb.set_corner_radius_all(rad)
	gsb.draw(rid, Rect2(track.position.x + 0.5, thumb_y, maxf(2.0, track.size.x - 1.0), maxf(8.0, thumb_h)))
## D45／D48（Kyo：环心「会动的像素小人」和「角色头像」都要；11-15 定 A）：SPRITE＝方案 A 环心像素小人、头像留在右栏队伍卡（默认）；
## FACE＝原来的大圆头像（回退：`XUiSkin.CENTER_STYLE = 0`）；SPRITE_BADGE＝方案 B 环心小人＋右下叠一枚小圆头像（没选，留着）
enum CenterStyle { FACE, SPRITE, SPRITE_BADGE }
static var CENTER_STYLE := CenterStyle.SPRITE
const U4_SEL_DISC := Color("7a1a14")     # u4 组图标选中时的暗红圆底
const BTN_IDLE_FILL := Color("2b2318")   # 主按钮平时：深褐金底
const TARGET_PULSE := 2.4                 # 选目标金圈一呼一吸的秒数（原 sin·TAU 绝对值＝每秒 2 闪）


## 量条高：COMFORT_V2 时血条 8、其余 5
static func bar_h(kind: String) -> float:
	return 8.0 if COMFORT_V2 and kind == "hp" else 5.0


## 主按钮（使用、装备、揭印）的底：COMFORT_V2 时平时深褐金底＋旧金边、焦点或按下才红；false＝一直红
static func primary_button_style(sb: StyleBoxFlat, focused: bool) -> void:
	if not COMFORT_V2 or focused:
		sb.bg_color = SEL_FILL
		sb.shadow_color = Color(SEL_FILL, 0.5)
		sb.shadow_size = 7
		return
	sb.bg_color = BTN_IDLE_FILL
	sb.border_color = Color(GOLD, 0.85)
	sb.set_border_width_all(2)


## 选目标的金圈亮度（0.6～1）：COMFORT_V2 时 2.4 秒余弦慢呼吸；false＝原来每秒两闪
static func target_pulse(t: float) -> float:
	if COMFORT_V2:
		return 0.6 + 0.4 * (0.5 - 0.5 * cos(t * TAU / TARGET_PULSE))
	return 0.6 + 0.4 * absf(sin(t * TAU))


## 测试用：-1 按设备（XPlatform.is_touch）；0 强制非触屏；1 强制触屏
static var touch_override := -1


## 现在是不是触屏（收口批的触屏样式都问这里）
static func touch() -> bool:
	if touch_override >= 0:
		return touch_override == 1
	return XPlatform.is_touch()


## 新皮肤的全屏菜单页（模板页、主菜单、七印祭坛进 FULLSCREEN_GROUP 组）现在开着没有：开着时虚拟摇杆、AB 键收起（TOUCH_V2）
const FULLSCREEN_GROUP := "skin_fullscreen"


static func fullscreen_menu_open(tree: SceneTree) -> bool:
	if not TOUCH_V2 or tree == null:
		return false
	for n in tree.get_nodes_in_group(FULLSCREEN_GROUP):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return true
	return false


## 字号倍率（FONT_V2）：字体大小设置 × 触屏一档，封顶 FONT_MULT_MAX
static func font_mult() -> float:
	if not FONT_V2:
		return 1.0
	var m := XFontScale.percent("global") / 100.0
	if touch():
		m *= TOUCH_FONT_STEP
	return minf(m, FONT_MULT_MAX)


static func fs(base: int) -> int:
	return roundi(base * font_mult())

## ---- 颜色（第三节定稿）----
static var BG: Color:                  # 底（WARM_BG：暖炭黑 D44 对比方案，默认冷黑）
	get: return Color("080708") if WARM_BG else Color("050506")
static var BG_MID: Color:              # 底的径向渐变中段
	get: return Color("0f0d0e") if WARM_BG else Color("0b0b0d")
static var BG_HI: Color:               # 底的径向渐变亮心
	get: return Color("1f1b1c") if WARM_BG else Color("1b1c20")
static var PANEL: Color:               # 面板（渐变上沿）
	get: return Color("1c1a1d") if WARM_BG else Color("18191c")
static var PANEL_LOW: Color:           # 面板（渐变下沿）
	get: return Color("121113") if WARM_BG else Color("0e0e10")
static var LINE: Color:                # 线
	get: return Color("b0a79b") if WARM_BG else Color("a2a5ab")
const ORB_HI := Color("34363b")      # 环上圆球的亮面
const ORB_LOW := Color("121315")     # 环上圆球的暗面
static var TEXT: Color:                # 正文（COMFORT_V2：骨白 #e6e2dc，原 #f0f0ee 只留给 TEXT_HI）
	get: return Color("e6e2dc") if COMFORT_V2 else Color("f0f0ee")
const TEXT_HI := Color("f0f0ee")       # 最亮的字（收口批后只给名字、选中行用；现在没有地方用，留着给后续页）
const TEXT_2 := Color("a8aaaf")      # 次要字
static var TEXT_3: Color:              # 最暗的字（禁用、「空」；COMFORT_V2 提亮到 #8e8982，面板上对比度过 5）
	get: return Color("8e8982") if COMFORT_V2 else Color("7d8086")
const SEL_LINE := Color("ff5a48")    # 选中：细线用朱红
const SEL_FILL := Color("cf2a1f")    # 选中：大块用绯红
const GOLD := Color("e3bd72")        # 旧金：标题、提醒、点缀；事件（回合提示、换装成功）
const GOLD_LIGHT := Color("f2d08a")  # 淡金：数值、货币
const HP := Color("ff78b0")          # 生命（玫粉）
const MP := Color("4d8dff")          # 魔法
const TP := Color("46e0b0")
const HP_TEXT := Color("ffd3e6")     # 量条旁的数字（样稿 .bar b）
const MP_TEXT := Color("bcd6ff")
const TP_TEXT := Color("bff3e2")
const UP := Color("6fe3a1")          # 提升
const DOWN := Color("ffa35c")        # 下降、不够（橙）
## 品质七档：普通、优秀、精良、史诗（v0.7 改 #9d88ff）、传说、不朽、神话
## COMFORT_V2：「优秀」绿 #80ff1c→#8fdc5a 调柔（Kyo 11-15 定）
static var QUALITY: Array:
	get: return [Color("ebf0f7"), Color("8fdc5a") if COMFORT_V2 else Color("80ff1c"), Color("39b9ff"), Color("9d88ff"), Color("ffa040"), Color("ffd65a"), Color("ff483c")]
const QUALITY_NAMES := ["普通", "优秀", "精良", "史诗", "传说", "不朽", "神话"]

## ---- 字号四级（第二节）：页名 34／牌上的名字 26～38／列表 19～24／辅助 14～17；下限 14 ----
const FS_PAGE := 34
const FS_CARD := 26
const FS_CARD_MAX := 38
## 收口批 FONT_V2（O-499）：列表、辅助两级跟「字体大小」设置（XFontScale 全局档，codexFontSize）放大，触屏设备再大一档（×1.1），
## 合起来封顶 ×1.3（行高不动，130% 时 19 号→25 号仍在 46 的行里）；辅助字下限 14→15（正文不小于 15）。页名、牌上大名字不放大。
## false＝四级字号写死（同 p1fix）。
static var FONT_V2 := true
const TOUCH_FONT_STEP := 1.1
const FONT_MULT_MAX := 1.3
static var FS_LIST: int:
	get: return fs(19)
static var FS_LIST_MAX: int:
	get: return fs(24)
static var FS_AUX: int:
	get: return fs(15 if FONT_V2 else 14)
static var FS_AUX_MAX: int:
	get: return fs(17)
static var FS_MIN: int:
	get: return 15 if FONT_V2 else 14
const FONT_TIERS := {"page": [34, 34], "card": [26, 38], "list": [19, 24], "aux": [14, 17]}

## ---- 间距（8 的倍数）与对齐线 ----
const GRID := 8
const TOP := 72              # 页面上边：页名、页签、面板上沿对齐
const BOTTOM := 668          # 面板下沿
const PANEL_GAP := 16        # 面板之间
const PAD := 16              # 面板内边距 16～24
const PAD_LG := 24
const HINT_BOTTOM := 10      # 底部按键提示离底（稿上特例，不是 8 的倍数）
const EDGE := 24             # 16:9 下页面左右的留白（样稿 .top／.hint）
const SAFE_X := 56           # 比 16:9 宽的屏左右安全边距（刘海、圆角、手握），界面的东西不进去
const CENTER_MAX := 720      # 中间块最宽
const RADIUS := 14           # 面板圆角
const ROW_RADIUS := 6        # 列表行、选中条圆角

## ---- 行高（第二节）----
const ROW_H := 46            # 列表 46～48
const ROW_H_ITEMS := 48      # 物品两列
const ROW_H_MENU := 56       # 主菜单子项
const ROW_H_SKILL := 44      # 战技
const MEMBER_H := 60         # 紧凑角色条一人

## ---- 红乙选中条（第二节「红光标」「光标移动」）----
## 下面四个是 v0.7 打磨版的值（SELECT_V2 = false 时用）；小A审 P1-1 嫌它在手机小屏上看不出焦点，加厚版见 SEL2_*。
const BAR_W := 4.0           # 左侧光标宽（v0.6 是 5）
const BAR_INSET := 5.0       # 上下各缩 5，不顶到头
const OUTLINE_ALPHA := 0.45  # 外圈描边（v0.6 是 60%）
const FILL_ALPHA := 0.40     # 底光（v0.6 是 46%）
## 选中条加厚版（cc/ui-skin-p1fix，小A审 v0.7 P1-1，Kyo 11-15「修」，O-482）：false＝回到 v0.7 打磨版（上面四个常量），可回退。
static var SELECT_V2 := true
const SEL2_BAR_W := 6.0                  # 左侧光标 4→6
const SEL2_BAR_INSET := 2.0              # 上下只缩 2
const SEL2_OUTLINE_W := 2                # 外框 1→2px
const SEL2_OUTLINE_ALPHA := 1.0          # 外框不透明（v0.7 是 45%）
const SEL2_FILL_L := Color("761c14")     # 整行实心暗红底：左端
const SEL2_FILL_R := Color("4e1410")     # 右端略浅（不再掉到透明）
const SEL2_FILL_ALPHA := 0.94
const SEL2_ANCHOR := Color("f2d08a")     # 光标中点的淡金小三角（形状锚点：红字、强光下也认得出）
const SEL2_HOVER_ALPHA := 0.45           # 悬停：只到焦点的这么多（不画光标）
const SEL2_PRESS_DARK := 0.42            # 按下：底色压暗这么多，并整体下沉 1px
const SEL2_PRESS_TIME := 0.12            # 列表点一下的按下反馈停留秒数
## 选中条上的字：红套红时（神话红、选中朱红一类的字）换成亮珊瑚色，别糊进红底
const SEL2_RED_TEXT := Color("ffa094")
enum SelState { FOCUS, HOVER, PRESSED }
const SLIDE_TIME := 0.09     # 行间滑动
const BREATH_TIME := 1.6     # 左侧光标呼吸（单程，0.75→1→0.75）
const BREATH_MIN := 0.75

## ---- 动效档（「界面动效：全部／简化／关」）----
enum Motion { FULL, SIMPLE, OFF }
## 测试写这里（-1＝没设）；玩家在设置页选的档存在 XConfig（codexUiMotion，5C），没选过时省电模式按简化、否则全部。
static var motion_override := -1

## ---- 主菜单的组（D25；Kyo 11-15 更正：整队并入角色，宠物以后单独一组）。组配置只在这一处，页签条、环形导航都按可见组数排。----
## 每组 {key, name, icon（占位图标号，样稿从旧图标里挑的，美术出了再换）, items:[{key, name, cmd（旧菜单 XMenu.COMMANDS 的符号，新主菜单按它打开同一页）, desc（新主菜单子项的一句话说明，第 1A 批）}]}；组或子项可带 hide（按存档判断的隐藏规则，见 hide_rule）或 hidden（写死隐藏）。
## 宠物组现在天启篇随 XTianqiPetHide 整组隐藏（可见 6 组）；放开后自动出现（7 组），不用改布局。文字照小A文字审口径。
const GROUPS := [
	{"key": "items", "name": "物品", "art": "items", "icon": 100, "items": [{"key": "item", "name": "物品", "cmd": "item", "desc": "使用和查看随身物品"}]},
	{"key": "equip", "name": "装备", "art": "equipment", "icon": 160, "items": [{"key": "equip", "name": "装备", "cmd": "equip", "desc": "更换角色装备"}]},
	{"key": "actor", "name": "角色", "art": "character", "icon": 1001, "items": [{"key": "status", "name": "状态", "cmd": "status", "desc": "属性、抗性、掌握"},
		{"key": "skill", "name": "技能", "cmd": "skill", "desc": "查看与使用技能"},
		{"key": "zhenqi", "name": "真气", "cmd": "zhenqi", "desc": "闭关突破"},
		{"key": "race", "name": "种族祝福", "cmd": "race", "desc": "种族加成与进阶"},
		{"key": "formation", "name": "整队", "cmd": "formation", "desc": "调整出战人员和顺序"}]},
	{"key": "pets", "name": "宠物", "icon": 384, "hide": "pet", "items": [{"key": "pets", "name": "宠物", "cmd": "pet", "desc": "查看和培养宠物"}]},
	{"key": "workshop", "name": "工坊", "art": "workshop", "icon": 193, "items": [{"key": "crafting", "name": "制作", "cmd": "crafting", "desc": "用材料做物品和装备"},
		{"key": "orb_shop", "name": "宝珠坊", "cmd": "orbs", "desc": "鉴定、兑换、分解宝珠"},
		{"key": "alien_workshop", "name": "异化工坊", "cmd": "alienation", "hide": "alien", "desc": "分解异化装备、重铸词条"}]},
	{"key": "codex", "name": "图鉴", "art": "codex", "icon": 1360, "items": [{"key": "actor_book", "name": "人物图鉴", "cmd": "actorBook", "desc": "查看角色资料"},
		{"key": "enemy_book", "name": "怪物图鉴", "cmd": "monsterBook", "desc": "查看敌人资料"},
		{"key": "achievement", "name": "成就", "cmd": "achievement", "desc": "查看成就"}]},
	{"key": "system", "name": "系统", "art": "system", "icon": 688, "items": [{"key": "save", "name": "存档", "cmd": "save", "desc": "保存当前进度"},
		{"key": "options", "name": "设置", "cmd": "options", "desc": "画面、声音、挂机与操作"},
		{"key": "feedback", "name": "反馈", "cmd": "feedback", "desc": "提交问题和建议"},
		{"key": "game_end", "name": "返回标题", "cmd": "gameEnd", "desc": "回到标题画面"}]},
]

## ---- 组入口图标 u4（Kyo 11-15 定稿；co 画，content/ui_skin/group_icons/）----
## GROUP_ICONS_U4（默认开，O-485）：组带 art 的用 u4 贴图（{art}_{normal|selected}_{64|32}.png），原生大小、最近邻、选中只换贴图不缩放；
## false＝回旧图标号（icon）和旧画法（40px、选中 ×1.16）。宠物组暂无 art（u4 的 party 号角留着，宠物组放开时再定）。
static var GROUP_ICONS_U4 := true
const GROUP_ICON_DIR := "res://content/ui_skin/group_icons/"


## 组入口 u4 贴图；没有 art、开关关着或文件缺失时 null（调用方回旧图标）
static func group_icon(art: String, selected := false, px := 64) -> Texture2D:
	if not GROUP_ICONS_U4 or art == "":
		return null
	var path := "%s%s_%s_%d.png" % [GROUP_ICON_DIR, art, "selected" if selected else "normal", px]
	if not ResourceLoader.exists(path):
		return null
	return load(path)


const FONT_DIR := "res://content/ui_skin/fonts/"
## 裁过字、改过名的字体（07_开发环境/裁字.py 生成；思源宋体 Heavy、思源黑体 Medium、Barlow Condensed Medium，SIL OFL）
const FONT_FILES := {"title": "TianqiUiSerif-Heavy.otf", "body": "TianqiUiSans-Medium.otf", "num": "TianqiUiNum-Medium.ttf"}
const CIRCLE_PATH := "res://content/ui_skin/circle_generic.svg"

## FONT_V00300（T100，Kyo 2026-11-16 D153「玩家玩的 v00300 字体就很舒服」）：新皮肤的 title／body／num 一律用玩家版
## 正文字体 GameFont（方正兰亭中粗），描边也同旧页（1px、黑 0.45）。数字不再用 Barlow 窄体：混排时数字与汉字不同族，
## 且玩家版一直是这款数字；列宽按旧页数字量过，换了反而对不齐。false＝回到思源宋体／黑体／Barlow 三款（content/ui_skin/fonts/）。
static var FONT_V00300 := true
static var _fonts := {}
static var _cli_mode := -2   # -2 没读；-1 没给；0 强关；1 强开
static var _tex := {}
static var _styles := {}
static var _clock_ms := -1   # 测试钉住时间（-1＝用真实时间）


## 新皮肤现在开没开（每次画都问，切换存档后下一帧就跟上）
static func on() -> bool:
	_ensure_input_tracker()   # T339 P2-1：早点挂上，首次问聚焦环之前的输入也记得到（挂过之后只是一句 is_instance_valid）
	if not ENABLED:
		return false
	if FORCE:
		return true
	var c := cli_mode()
	if c >= 0:
		return c == 1
	return XTianqiLine.open_for(XState.current) and XConfig.ui_skin_new()   # 设置页「界面风格」选了原版就回旧界面（5C）


## 设置页要不要列「界面风格」「界面动效」：新皮肤在这个存档里有机会开（总开关开着，且天启篇存档或调试强开）；重制版（西游存档）里不出现。
## 和 on() 的区别：玩家选了「原版」时 on() 是 false，但这一行还得在，好让人选回「新」。
static func selectable() -> bool:
	if not ENABLED:
		return false
	if FORCE:
		return true
	var c := cli_mode()
	if c >= 0:
		return c == 1
	return XTianqiLine.open_for(XState.current)


## 调试构建的启动参数 --ui-skin=new／old；发行构建恒 -1（不认）
static func cli_mode() -> int:
	if _cli_mode == -2:
		_cli_mode = parse_cli(OS.get_cmdline_user_args() + OS.get_cmdline_args(), ReleaseEntry.is_release())
	return _cli_mode


static func parse_cli(args: PackedStringArray, release: bool) -> int:
	if release:
		return -1
	for a in args:
		if a == "--ui-skin=new":
			return 1
		if a == "--ui-skin=old":
			return 0
	return -1


## 动效档：没设时省电模式按简化
static func motion() -> int:
	if motion_override >= 0:
		return clampi(motion_override, Motion.FULL, Motion.OFF)
	var chosen := XConfig.ui_motion()
	if chosen >= 0:
		return clampi(chosen, Motion.FULL, Motion.OFF)
	return Motion.SIMPLE if XGraphics.low_power() else Motion.FULL


## 选中条呼吸、法阵慢转、火星只在「全部」档
static func breathing() -> bool:
	return motion() == Motion.FULL


## ---- 选中放大（Kyo 11-16：选中的东西稍微放大、带一点过渡；先用在装备栏位环，T024 推广到新界面各页的选中项）----
## 用法：每项存一个当前倍数 cur（初值 1），每帧 cur = XUiSkin.sel_scale_step(cur, 选中否, delta)，变了就重画；
## 画球／图标／名字时乘 cur（名字字号可按 sel_scale_frac(cur) 加几号）。动效关时直接到位。
const SEL_SCALE := 1.15
const SEL_TIME := 0.12


static func sel_scale_target(on: bool) -> float:
	return SEL_SCALE if on else 1.0


static func sel_scale_step(cur: float, on: bool, delta: float) -> float:
	var target := sel_scale_target(on)
	if motion() == Motion.OFF:
		return target
	return move_toward(cur, target, (SEL_SCALE - 1.0) * delta / SEL_TIME)


## 放大进度 0～1（给字号加几号用）
static func sel_scale_frac(cur: float) -> float:
	return clampf((cur - 1.0) / (SEL_SCALE - 1.0), 0.0, 1.0)


## 行间滑动用时：动效关时 0（直接跳）
static func slide_time() -> float:
	return 0.0 if motion() == Motion.OFF else SLIDE_TIME


## 秒（测试可钉住）
static func now() -> float:
	return (_clock_ms if _clock_ms >= 0 else Time.get_ticks_msec()) / 1000.0


## 左侧光标的呼吸透明度：0.75→1 走 1.6 秒、再回来（缓入缓出，同样稿 ease-in-out alternate；美化态放缓至 2.4 秒、下限 0.82）；不呼吸时恒 1
static func breath_alpha(t := -1.0) -> float:
	if not breathing():
		return 1.0
	if t < 0.0:
		t = now()
	var bt := POLISH_BREATH_TIME if polish_on() else BREATH_TIME
	var bmin := POLISH_BREATH_MIN if polish_on() else BREATH_MIN
	var phase := fmod(t, bt * 2.0) / bt   # 0..2
	var x := phase if phase <= 1.0 else 2.0 - phase
	var eased := 0.5 - 0.5 * cos(PI * x)
	return lerpf(bmin, 1.0, eased)


## 品质色（0 普通 … 6 神话）
static func quality_color(q: int) -> Color:
	return QUALITY[clampi(q, 0, QUALITY.size() - 1)]


## 旧颜色对照表（CORE_V2）：说明卡里 MV 老颜色（\\c[n]、rgba）→ 皮肤色。只给详情牌的说明行用，品质名的颜色不走这里。
static func legacy_color(c: Color) -> Color:
	if not CORE_V2:
		return c
	if c.s < 0.18:   # 白、灰：亮的当正文，暗的当次要字
		return TEXT if c.v > 0.8 else TEXT_2
	var h := c.h
	if h >= 0.11 and h < 0.2 and c.s > 0.45:   # 纯黄（价格、旧强调）→ 淡金
		return GOLD_LIGHT
	if (h < 0.045 or h > 0.93) and c.s > 0.3:   # 红、粉红（属性、消耗品）→ 正文
		return TEXT
	if h >= 0.2 and h < 0.42 and c.s > 0.4:   # 荧光绿（旧 TP、强调）→ 正文；绿只留给「优秀」品质名
		return TEXT
	if h >= 0.42 and h < 0.75:   # 青、蓝、蓝紫说明字 → 次要字
		return TEXT_2
	if h >= 0.045 and h < 0.11:   # 橙：保留（下降、警示），压到皮肤的橙
		return DOWN
	return TEXT_2


## 八的倍数（向上取）
static func snap(v: float) -> int:
	return ceili(v / GRID) * GRID


## ---- 字体 ----

## kind：title 思源宋体 Heavy（页名、牌上的名字）／body 思源黑体 Medium（正文）／num 窄体数字字（数值）。
## 裁过的字缺字时落回游戏原字体（GameFont），再落回系统字体。
static func font(kind := "body") -> Font:
	if FONT_V00300:   # T100：标题／正文／数字都用玩家版那一款（GameFont），三种 kind 同一字体，选中、换级都不会换字
		return GameFont.current()
	var f := _font_file(kind)
	# T336 D1a（界面细节规范 1.1）：三字体模式下数字字包一层 FontVariation 开 tnum／lnum（Barlow 0–9 统一 457/1000）；DETAIL_V1=false 照旧原字
	if kind == "num" and DETAIL_V1 and f != GameFont.current():
		if not _fonts.has("num_tabular"):
			_fonts["num_tabular"] = _make_tabular(f)
		return _fonts["num_tabular"]
	return f


static func _font_file(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font = null
	var path: String = FONT_DIR + str(FONT_FILES.get(kind, FONT_FILES.body))
	if ResourceLoader.exists(path):
		var ff := load(path) as FontFile
		if ff != null:
			ff = ff.duplicate() as FontFile
			ff.fallbacks = [font("body"), GameFont.current()] if kind == "num" else [GameFont.current()]
			f = ff
	if f == null:
		f = GameFont.current()
	_fonts[kind] = f
	return f


## 描边（玩家版旧页：1px、黑 0.45，XMVCanvas.text／XUI.theme 同值）。FONT_V00300 开着时所有新皮肤自绘字都走 ds，Label／按钮走 theme。
const T100_OUTLINE_PX := 1
const T100_OUTLINE_A := 0.45


static func outline_size() -> int:
	return T100_OUTLINE_PX if FONT_V00300 else 0


static func outline_color(a := 1.0) -> Color:
	return Color(0, 0, 0, T100_OUTLINE_A * a)


## 新皮肤画字的唯一入口（替代 draw_string）：FONT_V00300 开着先描 1px 黑 0.45 边再写字；关着＝原样 draw_string。
static func ds(ci: CanvasItem, font: Font, pos: Vector2, text: String, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, fs: int = 16, color: Color = Color.WHITE, just: int = 3) -> void:
	var col := paint_color(color)
	if FONT_V00300 and col.a > 0.0:
		ci.draw_string_outline(font, pos, text, align, width, fs, T100_OUTLINE_PX, outline_color(col.a))
	ci.draw_string(font, pos, text, align, width, fs, col, just)


static func has_font(kind: String) -> bool:
	return ResourceLoader.exists(FONT_DIR + str(FONT_FILES.get(kind, "")))


## ---- 主题（新组件用；旧页面照旧用 XUI.theme，框和光标在画时换）----
static func theme() -> Theme:
	var t := Theme.new()
	var pol := polish_on()
	t.default_font = font("body")
	t.default_font_size = FS_LIST
	for type in ["Label", "Button", "RichTextLabel", "LineEdit"]:
		t.set_constant("outline_size", type, outline_size())
		if FONT_V00300:
			t.set_color("font_outline_color", type, outline_color())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = PAD
	empty.content_margin_right = PAD
	for state in ["normal", "disabled"]:
		t.set_stylebox(state, "Button", empty)
	t.set_stylebox("focus", "Button", select_style())
	t.set_stylebox("hover", "Button", select_style_for(SelState.HOVER))
	for state in ["pressed", "hover_pressed"]:
		t.set_stylebox(state, "Button", select_style_for(SelState.PRESSED))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_3)
	t.set_font_size("font_size", "Button", FS_LIST)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.78, 0.69, 0.54, 0.65) if pol else Color(LINE, 0.45)
	grab.set_corner_radius_all(3 if pol else 2)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(s, "VScrollBar", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.04, 0.033, 0.032, 0.52) if pol else Color(1, 1, 1, 0.06)
	track.set_corner_radius_all(3 if pol else 2)
	t.set_stylebox("scroll", "VScrollBar", track)
	return t


## 面板（新组件的 StyleBox；MV 窗口框改画时也用它）
static func panel_style() -> StyleBox:
	if XSkinArt.panel_on():   # 第一期正式美术（D50）：R2 无框烟色九宫格
		return XSkinArt.smoke_style()
	var key := "panel_polish" if polish_on() else "panel"
	if not _styles.has(key):
		var s := StyleBoxTexture.new()
		s.texture = panel_texture()
		s.texture_margin_left = 24
		s.texture_margin_right = 24
		s.texture_margin_top = 24
		s.texture_margin_bottom = 24
		s.content_margin_left = PAD
		s.content_margin_right = PAD
		s.content_margin_top = PAD
		s.content_margin_bottom = PAD
		_styles[key] = s
	return _styles[key]


## 面板的投影（0 8 22 rgba(0,0,0,.5)）
static func shadow_style() -> StyleBox:
	if XSkinArt.panel_on():   # 烟底自己渐隐，不再垫投影
		if not _styles.has("shadow_none"):
			_styles["shadow_none"] = StyleBoxEmpty.new()
		return _styles["shadow_none"]
	if not _styles.has("shadow"):
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0, 0, 0, 0)
		s.draw_center = false
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 11
		s.shadow_offset = Vector2(0, 8)
		s.set_corner_radius_all(RADIUS)
		_styles["shadow"] = s
	return _styles["shadow"]


## 选中条（静态一帧，给 Button 主题、MV 光标框）：底光＋描边＋左侧光标
static func select_style() -> StyleBox:
	if not _styles.has("select"):
		_styles["select"] = XSkinSelectStyle.new()
	return _styles["select"]


## 面板贴图：96×96，竖向渐变 #18191c→#0e0e10、圆角 14、1px 细线（线色 42%）；九宫格角 24
static func panel_texture() -> Texture2D:
	var key := "panel_polish" if polish_on() else "panel"
	if _tex.has(key):
		return _tex[key]
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := float(RADIUS)
	var line := Color(line_c(), 0.42)
	var p_hi := panel_c()
	var p_lo := panel_low_c()
	for y in range(n):
		var fill := p_hi.lerp(p_lo, clampf((y - 4.0) / (n - 8.0), 0.0, 1.0))
		for x in range(n):
			var d := _round_rect_dist(Vector2(x + 0.5, y + 0.5), Vector2(n, n), r)   # 到圆角矩形边的有向距离（里面为负）
			if d > 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c := fill
			var edge := clampf(1.0 - absf(d + 0.5), 0.0, 1.0)   # 最外一圈 1px 的线
			c = c.lerp(Color(line.r, line.g, line.b, 1.0), line.a * edge)
			c.a = clampf(0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func _round_rect_dist(p: Vector2, size: Vector2, r: float) -> float:
	var half := size / 2.0
	var q := (p - half).abs() - (half - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


## ---- 发光贴图（程序生成）----

## 焦点光晕：白色径向渐隐（画时乘颜色）
static func glow_texture() -> Texture2D:
	return _radial("glow", 64, PackedFloat32Array([0.0, 0.35, 1.0]), [Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])


## 封蜡光晕：一圈亮环，内外渐隐
static func seal_halo_texture() -> Texture2D:
	return _radial("seal", 128, PackedFloat32Array([0.0, 0.5, 0.68, 0.82, 1.0]),
		[Color(1, 1, 1, 0), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])


## 火星：小亮点＋外晕
static func ember_texture() -> Texture2D:
	return _radial("ember", 16, PackedFloat32Array([0.0, 0.22, 0.45, 1.0]),
		[Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])


static func _radial(key: String, size: int, offsets: PackedFloat32Array, colors: Array) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_tex[key] = t
	return t


## 通用法阵（设计仓 assets/circle_generic.svg，中性金灰七芒阵）
static func circle_texture() -> Texture2D:
	if not _tex.has("circle"):
		_tex["circle"] = load(CIRCLE_PATH) if ResourceLoader.exists(CIRCLE_PATH) else null
	return _tex["circle"]


## ---- 画法（XWindowStyle 在 on() 时转到这里）----

## MV 窗口框：投影＋黑面板＋细线。opacity 是 MV 的 0～1；菜单场景的 30/255 也画满（新稿面板是实的），只在 0 附近渐隐。
static func draw_panel(ci: RID, rect: Rect2, opacity := 1.0) -> void:
	var a := clampf(opacity / (30.0 / 255.0), 0.0, 1.0)
	if a <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if XSkinArt.panel_on():   # 第一期正式美术（D50）：烟色九宫格，矮的用 secondary
		XSkinArt.draw_smoke(ci, rect, a)
		return
	var r := minf(RADIUS, minf(rect.size.x, rect.size.y) / 2.0)
	if r >= RADIUS:
		shadow_style().draw(ci, rect)
		RenderingServer.canvas_item_add_nine_patch(ci, rect, Rect2(0, 0, 96, 96), panel_texture().get_rid(), Vector2(24, 24), Vector2(24, 24),
			RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, Color(1, 1, 1, a))
		return
	# 很矮的窗口（如 28 高的提示条）：九宫格角放不下，改用纯色圆角框
	var s := _flat("panel_small")
	s.bg_color = Color(PANEL, a)
	s.border_color = Color(LINE, 0.42 * a)
	s.set_border_width_all(1)
	s.set_corner_radius_all(int(r))
	s.draw(ci, rect)


## 选中条（静态）。SELECT_V2（默认）：整行实心暗红底（左 #761c14 → 右 #4e1410，不掉透明）＋2px 不透明朱红框＋外晕＋左侧 6px 朱红光标＋光标中点淡金小三角；
## state：FOCUS 焦点（全画）、HOVER 悬停（同样式减淡、不画光标）、PRESSED 按下（底色压暗、整体下沉 1px）。
## SELECT_V2 = false：v0.7 打磨版（绯红底光从左 40% 渐到 68% 处 8%、再到右端透明；朱红 1px 描边 45%＋外晕；左侧 4px 光标，上下各缩 5），state 不区分。
static func draw_select(ci: RID, rect: Rect2, bar_alpha := 1.0, alpha := 1.0, state := SelState.FOCUS, symmetric := false) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if XSkinArt.select_on():   # 第一期正式美术（D51）：渐隐暗红底＋左外小箭头
		XSkinArt.draw_select(ci, rect, alpha, state, "selection_wash_128x24", symmetric and detail_on())   # T359 D254：居中菜单对称
		return
	if SELECT_V2:
		_draw_select_v2(ci, rect, bar_alpha, alpha, state, symmetric and detail_on())   # T366（T359 P3）：美术关着的兜底画法也认居中对称
		return
	var rs := RenderingServer
	# 外晕（0 0 12px 绯红 30%）
	var halo := _flat("sel_halo")
	halo.draw_center = false
	halo.shadow_color = Color(SEL_FILL, 0.30 * alpha)
	halo.shadow_size = 6
	halo.set_corner_radius_all(ROW_RADIUS)
	halo.draw(ci, rect)
	# 底光：三段横向渐变
	var inner := rect.grow(-1)
	var x68 := inner.position.x + inner.size.x * 0.68
	var c0 := Color(SEL_FILL, FILL_ALPHA * alpha)
	var c1 := Color(SEL_FILL, 0.08 * alpha)
	var c2 := Color(SEL_FILL, 0.0)
	_hquad(ci, Rect2(inner.position, Vector2(x68 - inner.position.x, inner.size.y)), c0, c1)
	_hquad(ci, Rect2(Vector2(x68, inner.position.y), Vector2(inner.end.x - x68, inner.size.y)), c1, c2)
	# 描边
	var edge := _flat("sel_edge")
	edge.draw_center = false
	edge.border_color = Color(SEL_LINE, OUTLINE_ALPHA * alpha)
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(ROW_RADIUS)
	edge.draw(ci, rect)
	# 左侧光标
	var bh := rect.size.y - BAR_INSET * 2.0
	if bh > 2.0:
		var bar := Rect2(rect.position.x, rect.position.y + BAR_INSET, BAR_W, bh)
		var ba := bar_alpha * alpha
		var glow := glow_texture()
		rs.canvas_item_add_texture_rect(ci, bar.grow_individual(10, 10, 10, 10), glow.get_rid(), false, Color(SEL_LINE, 0.55 * ba))
		var b := _flat("sel_bar")
		b.bg_color = Color(SEL_LINE, ba)
		b.set_corner_radius_all(2)
		b.draw(ci, bar)


static func _draw_select_v2(ci: RID, rect: Rect2, bar_alpha: float, alpha: float, state: int, symmetric := false) -> void:
	var rs := RenderingServer
	var a := alpha * (SEL2_HOVER_ALPHA if state == SelState.HOVER else 1.0)
	var r := rect
	if state == SelState.PRESSED:
		r.position.y += 1.0   # 按下：整体下沉 1px
	# 外晕
	var halo := _flat("sel_halo")
	halo.draw_center = false
	halo.shadow_color = Color(SEL_FILL, 0.40 * a)
	halo.shadow_size = 6
	halo.set_corner_radius_all(ROW_RADIUS)
	halo.draw(ci, r)
	# 整行实心底：左深右略浅；按下压暗
	var dark := SEL2_PRESS_DARK if state == SelState.PRESSED else 0.0
	var inner := r.grow(-1)
	_hquad(ci, inner, Color(SEL2_FILL_L.darkened(dark), SEL2_FILL_ALPHA * a), Color(SEL2_FILL_R.darkened(dark), SEL2_FILL_ALPHA * a))
	# 外框：2px 不透明朱红
	var edge := _flat("sel_edge")
	edge.draw_center = false
	edge.border_color = Color(SEL_LINE, SEL2_OUTLINE_ALPHA * a)
	edge.set_border_width_all(SEL2_OUTLINE_W)
	edge.set_corner_radius_all(ROW_RADIUS)
	edge.draw(ci, r)
	if state == SelState.HOVER:
		return
	# 左侧光标 6px＋光晕＋中点淡金小三角
	var bh := r.size.y - SEL2_BAR_INSET * 2.0
	if bh > 2.0:
		var bar := Rect2(r.position.x, r.position.y + SEL2_BAR_INSET, SEL2_BAR_W, bh)
		var ba := clampf(bar_alpha, 0.0, 1.0) * alpha
		rs.canvas_item_add_texture_rect(ci, bar.grow_individual(10, 10, 10, 10), glow_texture().get_rid(), false, Color(SEL_LINE, 0.65 * ba))
		var b := _flat("sel_bar")
		b.bg_color = Color(SEL_LINE, maxf(ba, 0.85 * alpha))
		b.set_corner_radius_all(2)
		b.draw(ci, bar)
		var th := clampf(r.size.y * 0.22, 5.0, 8.0)
		var cy := r.position.y + r.size.y / 2.0
		var x0 := bar.end.x + 1.0
		rs.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(x0, cy - th), Vector2(x0 + th * 0.9, cy), Vector2(x0, cy + th)]),
			PackedColorArray([Color(SEL2_ANCHOR, alpha), Color(SEL2_ANCHOR, alpha), Color(SEL2_ANCHOR, alpha)]))
		if symmetric:   # 居中菜单：右端镜像一根光标＋小三角（朝左）
			var bar2 := Rect2(r.end.x - SEL2_BAR_W, bar.position.y, SEL2_BAR_W, bh)
			rs.canvas_item_add_texture_rect(ci, bar2.grow_individual(10, 10, 10, 10), glow_texture().get_rid(), false, Color(SEL_LINE, 0.65 * ba))
			b.draw(ci, bar2)
			var x1 := bar2.position.x - 1.0
			rs.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(x1, cy - th), Vector2(x1 - th * 0.9, cy), Vector2(x1, cy + th)]),
				PackedColorArray([Color(SEL2_ANCHOR, alpha), Color(SEL2_ANCHOR, alpha), Color(SEL2_ANCHOR, alpha)]))


## 选中条上的字色：加厚版下红字（神话红、朱红一类）换亮珊瑚色，其余不变；v0.7 版原样返回
static func sel_text(c: Color) -> Color:
	if not SELECT_V2:
		return c
	if c.s > 0.55 and c.v > 0.7 and (c.h < 0.035 or c.h > 0.95):
		return Color(SEL2_RED_TEXT, c.a)
	return c


## 选中条（静态 StyleBox）按状态取：焦点／悬停／按下（Button 的 focus／hover／pressed 用，各状态看得出区别）
static func select_style_for(state: int) -> StyleBox:
	var key := "select_%d" % state
	if not _styles.has(key):
		var st := XSkinSelectStyle.new()
		st.state = state
		_styles[key] = st
	return _styles[key]


## 画法里反复用的 StyleBoxFlat（选中条每帧都可能重画，不每次新建）；取到后照用处重设颜色再画
static func _flat(key: String) -> StyleBoxFlat:
	if not _styles.has(key):
		_styles[key] = StyleBoxFlat.new()
	return _styles[key]


static func _hquad(ci: RID, r: Rect2, left: Color, right: Color) -> void:
	if r.size.x <= 0.0:
		return
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([left, right, right, left]))


## MV 窗口的上下滚动箭头（旧皮肤是 Window.png 的蓝箭头）：改画旧金小三角
static func draw_arrows(ci: CanvasItem, w: float, h: float, up: bool, down: bool) -> void:
	var c := Color(GOLD, 0.9)
	if up:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0 - 8, 16), Vector2(w / 2.0 + 8, 16), Vector2(w / 2.0, 8)]), c)
	if down:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0 - 8, h - 16), Vector2(w / 2.0 + 8, h - 16), Vector2(w / 2.0, h - 8)]), c)


## MV 窗口的翻页标记（对话等，旧皮肤是 Window.png 的小箭头）：改画旧金菱形，上下轻跳
static func draw_pause(ci: CanvasItem, w: float, h: float, alpha: float, anim: int) -> void:
	var dy := 0.0 if motion() == Motion.OFF else sin(anim / 60.0 * TAU) * 2.0
	var c := Vector2(w / 2.0, h - 14 + dy)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), Color(GOLD, alpha))


## ---- 菜单底（换掉 MOG_MenuBackground 的 Background.png＋上浮粒子）----

## 黑底：径向渐变（亮心在左侧 22%）、底部一层绯红底光、火星（全部档 10 颗、简化档 4 颗、关 0）
static func menu_backdrop(parent: Control) -> Control:
	var root := Control.new()
	root.name = "SkinBackdrop"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(root)
	if XSkinArt.BG and XSkinArt.bg_texture(XSkinArt.route(), Vector2(1280, 720)) != null:   # 第一期正式美术：按骑士线、按比例的背景图
		XSkinArt.add_backdrop(root)
		_add_embers(parent, root, XSkinArt.EMBER_ALPHA)
		return root
	var base := ColorRect.new()
	base.color = BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(base)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.38, 0.75])
	g.colors = PackedColorArray([BG_HI, BG_MID, BG])
	var rad := GradientTexture2D.new()
	rad.gradient = g
	rad.width = 256
	rad.height = 144
	rad.fill = GradientTexture2D.FILL_RADIAL
	rad.fill_from = Vector2(0.22, 0.55)
	rad.fill_to = Vector2(0.22 + 0.75, 0.55)
	root.add_child(_full_tex(rad))
	# 底光：贴底、高 200、往下探 70，椭圆中心在 30%
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.7])
	gg.colors = PackedColorArray([Color(SEL_FILL, 0.28), Color(SEL_FILL, 0.0)])
	var glow := GradientTexture2D.new()
	glow.gradient = gg
	glow.width = 256
	glow.height = 64
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.3, 1.0)
	glow.fill_to = Vector2(1.0, 1.0)
	var gl := _full_tex(glow)
	gl.anchor_top = 1.0
	gl.offset_top = -130
	gl.offset_bottom = 70
	root.add_child(gl)
	_add_embers(parent, root)
	return root


static func _add_embers(parent: Control, root: Control, alpha := 1.0) -> void:
	var n: int = [10, 4, 0][motion()]
	if n > 0:
		var vs := parent.get_viewport_rect().size if parent.is_inside_tree() else Vector2(1280, 720)
		var p := CPUParticles2D.new()
		p.name = "Embers"
		p.texture = ember_texture()
		p.amount = n
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(vs.x / 2.0, 4)
		p.position = Vector2(vs.x / 2.0, vs.y + 10)
		p.direction = Vector2(0, -1)
		p.spread = 6.0
		p.gravity = Vector2.ZERO
		var polished := polish_on()
		p.initial_velocity_min = 48.0 if polished else 110.0
		p.initial_velocity_max = 82.0 if polished else 180.0
		p.scale_amount_min = 0.35
		p.scale_amount_max = 0.6
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 1.0])
		var ea := alpha * (0.78 if polished else 1.0)
		ramp.colors = PackedColorArray([Color(1.0, 0.86, 0.8, 0.9 * ea), Color(SEL_LINE, 0.0)])
		p.color_ramp = ramp
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
		root.add_child(p)


static func _full_tex(t: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


## ---- 图标、头像（缓存）----
## XUI.icon_texture／face_texture 每次新建 AtlasTexture，图集（load 出来的贴图）只靠它引用：组件在 _draw 里取完就释放，
## 图集跟着被卸掉，画出来是白块（旧画布 XMVCanvas 靠 _keep 留引用）。新组件一律从这里取，按号缓存住。
static var _icon_cache := {}


static func icon(index: int) -> Texture2D:
	if index <= 0:
		return null
	if not _icon_cache.has(index):
		_icon_cache[index] = XUI.icon_texture(index)
	return _icon_cache[index]


static func face(face_name: String, index: int) -> Texture2D:
	var k := "face:%s#%d" % [face_name, index]
	if not _icon_cache.has(k):
		_icon_cache[k] = XUI.face_texture(face_name, index)
	return _icon_cache[k]


## ---- 组 ----

## 某组在当前存档里看得到的子项
static func visible_items(group: Dictionary, s: XState = null) -> Array:
	if hidden(group, s):
		return []
	return (group.get("items", []) as Array).filter(func(it): return not hidden(it, s))


## 组或子项按存档隐藏没有：hidden 写死；hide 是规则名（pet＝宠物，天启篇随 XTianqiPetHide 隐藏）
static func hidden(entry: Dictionary, s: XState = null) -> bool:
	if bool(entry.get("hidden", false)):
		return true
	return hide_rule(str(entry.get("hide", "")), s)


static func hide_rule(rule: String, s: XState = null) -> bool:
	match rule:
		"pet":
			return XTianqiPetHide.active(s)
		"alien":
			return XAlienBattle.hidden()  # 同旧菜单 XMenu.commands()（O-283）
	return false


## 有可见子项的组（子项只留可见的）
static func visible_groups(groups: Array = GROUPS, s: XState = null) -> Array:
	var out := []
	for g in groups:
		var items := visible_items(g, s)
		if not items.is_empty():
			var c: Dictionary = (g as Dictionary).duplicate()
			c["items"] = items
			out.append(c)
	return out


## 选组时直接进的子项：只剩一项时返回它的键，否则 ""
static func direct_item(group: Dictionary, s: XState = null) -> String:
	var items := visible_items(group, s)
	return str(items[0].key) if items.size() == 1 else ""


## ======================================================================
## ---- 界面细节 D1a（T336，私密仓 重制设定/界面细节规范_v0.1.md 第三节规范 1～4、第五节卡 D1a）----
## 只是底层：定宽数字、双环聚焦、输入模式、表面色阶、文字基线与行内图标出口。本卡不接任何现有页面（D1b／D1c／D2／D3／D4 才接），
## 所以开关开关现有页面都一个像素不变；唯一已生效的是三字体模式（FONT_V00300=false）下 font("num") 开 tnum（规范 1.1）。
## 回退：DETAIL_V1 = false（font("num") 回原字；后续卡接线时一律先问 detail_on()，关着走改造前画法）。
static var DETAIL_V1 := true


static func detail_on() -> bool:
	return DETAIL_V1 and on()


## T359（D251，K2 甲）：框形主／次按钮、数量按钮统一圆角矩形 8～10px（面板 14、列表行 6 的标准嵌套）；全圆角只留键帽与顶部提示道。
## DETAIL_V1 关＝回 height/2 全圆角胶囊。h＝按钮高，矮于 18 时跟着缩（不超过半高）
const BTN_RADIUS := 9


static func btn_radius(h: float) -> int:
	var half := int(h / 2.0)
	return mini(BTN_RADIUS, half) if detail_on() else half


## ---- 规范 1：数字等宽 ----

## 包一层 FontVariation 开 OpenType tnum（等宽数字）＋lnum（等高数字）；字体没有这两个特性时等于原字
static func _make_tabular(base: Font) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	var ts := TextServerManager.get_primary_interface()
	fv.opentype_features = {ts.name_to_tag("tnum"): 1, ts.name_to_tag("lnum"): 1}
	return fv


## 常规数字右对齐的落笔点（不画，测试用）：右缘 right_x 取整像素（防亚像素抖动）
static func num_right_pos(f: Font, right_x: float, baseline_y: float, text: String, fs: int) -> Vector2:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return Vector2(roundf(right_x - tw), roundf(baseline_y))


## 常规数字右对齐：右缘 right_x 取整像素（防亚像素抖动），描边同 ds；返回字宽
static func draw_num_right(ci: CanvasItem, f: Font, right_x: float, baseline_y: float, text: String, fs: int, color: Color) -> float:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ds(ci, f, num_right_pos(f, right_x, baseline_y, text, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	return tw


static var _digit_cell := {}


## 逐位定宽的格宽：0–9 十个字宽取最大（T329 r2 P3-6：只取 0 和 9 会漏掉更宽的数字），按字体＋字号缓存
static func mono_digit_cell(f: Font, fs: int) -> float:
	var key := "%d#%d" % [f.get_instance_id(), fs]
	if not _digit_cell.has(key):
		var w := 0.0
		for d in 10:
			w = maxf(w, f.get_string_size(str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		_digit_cell[key] = w
	return _digit_cell[key]


## 逐位定宽的排位（不画，测试和量宽用）：[[字, 相对起点的 x（已在格内居中）, 字宽, 格宽], …]；数字占一格、别的字按自身宽
static func mono_digit_slots(f: Font, text: String, fs: int) -> Array:
	var cell := mono_digit_cell(f, fs)
	var out := []
	var x := 0.0
	for i in text.length():
		var ch := text.substr(i, 1)
		var gw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sw := cell if (ch >= "0" and ch <= "9") else gw
		out.append([ch, x + (sw - gw) * 0.5, gw, sw])
		x += sw
	return out


static func mono_digits_width(f: Font, text: String, fs: int) -> float:
	var w := 0.0
	for sl in mono_digit_slots(f, text, fs):
		w += float(sl[3])
	return w


## D231 宋体 Heavy 这类数字不等宽、又没有 tnum 的字（连击大数字、胜利大字）：逐位定宽画，1 和 7 在自己的格里居中，跳数不左右晃。
## align 按 anchor_x 左／中／右；outline_px＝-1 跟 ds 一样（FONT_V00300 时 1px 黑 0.45），0 不描边。返回总宽。
static func draw_mono_digits(ci: CanvasItem, f: Font, anchor_x: float, baseline_y: float, text: String, fs: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, outline_px := -1, outline_col := Color(0, 0, 0, 0.85)) -> float:
	var col := paint_color(color)
	var plan := mono_digit_plan(f, anchor_x, baseline_y, text, fs, align)
	var ol := mono_outline(col, outline_px, outline_col)
	for sl in plan.glyphs:
		if int(ol.px) > 0 and col.a > 0.0:
			ci.draw_string_outline(f, sl[1], str(sl[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(ol.px), ol.col)
		ci.draw_string(f, sl[1], str(sl[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return plan.total


## draw_mono_digits 的落笔计划（不画，测试用）：{total: 总宽, glyphs: [[字, 落笔点（已取整）], …]}
static func mono_digit_plan(f: Font, anchor_x: float, baseline_y: float, text: String, fs: int, align := HORIZONTAL_ALIGNMENT_CENTER) -> Dictionary:
	var slots := mono_digit_slots(f, text, fs)
	var total := 0.0
	for sl in slots:
		total += float(sl[3])
	var x0 := anchor_x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x0 -= total * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x0 -= total
	var glyphs := []
	for sl in slots:
		glyphs.append([str(sl[0]), Vector2(roundf(x0 + float(sl[1])), roundf(baseline_y))])
	return {"total": total, "glyphs": glyphs}


## draw_mono_digits 的描边分支（不画，测试用）：outline_px＝-1 跟 ds 一样（outline_size()／outline_color()），否则用传入的
static func mono_outline(col: Color, outline_px: int, outline_col: Color) -> Dictionary:
	if outline_px < 0:
		return {"px": outline_size(), "col": outline_color(col.a)}
	return {"px": outline_px, "col": outline_col}


## ---- 规范 2：双环聚焦与输入模式 ----

## 双环：内黑 #090808 2px 贴控件外缘（0～2px）＋外淡金 #f2d08a 2px（2～4px），总外扩 4px；金底控件外环换骨白。
## 紧凑控件（高 < 32）也是内环 2px、总外扩 4px（T329 r2 P3-7：原稿「1.5px 取整 2px」写死成 2），只把内环透明度降到 0.90、外晕收到 3px。
const FOCUS_IN := Color("090808")
const FOCUS_RING_W := 2
const FOCUS_EXPAND := 4
const FOCUS_COMPACT_H := 32.0
const FOCUS_IN_ALPHA := 0.95
const FOCUS_IN_ALPHA_COMPACT := 0.90
## 横排按钮间距：双环各外扩 4px 后仍留 4px 净缝（规范 2.2）；紧凑控件至少 10
const FOCUS_BTN_GAP := 12
const FOCUS_BTN_GAP_COMPACT := 10

enum InputMode { KEYBOARD, GAMEPAD, MOUSE, TOUCH }
## 合成输入的标记：触屏虚拟按键、底部按键提示胶囊发出的假键盘事件带它，note_input 跳过
const SYNTH_META := "skin_synth_input"
## -1＝还没收到输入（按设备：触屏 TOUCH，否则 KEYBOARD）；测试可直接写
static var input_mode := -1
const JOY_AXIS_DEADZONE := 0.35
const MOUSE_MOVE_MIN := 4.0


static func current_input_mode() -> int:
	if input_mode >= 0:
		return input_mode
	return InputMode.TOUCH if touch() else InputMode.KEYBOARD


## 记一次输入（全局监听节点每个事件都调；只读不吞）。触屏模拟出的鼠标事件（device＝DEVICE_ID_EMULATION）算触屏，
## 同 battle_scene.gd／mv_player.gd 的判据。
static func note_input(event: InputEvent) -> void:
	if event.has_meta(SYNTH_META):
		return   # T339 P3-2：触屏虚拟按键合成的键盘事件不算「用了键盘」（模式由触屏那几下定）
	if event is InputEventKey:
		if event.pressed:
			input_mode = InputMode.KEYBOARD
	elif event is InputEventJoypadButton:
		if event.pressed:
			input_mode = InputMode.GAMEPAD
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > JOY_AXIS_DEADZONE:
			input_mode = InputMode.GAMEPAD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		input_mode = InputMode.TOUCH
	elif event is InputEventMouse:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			input_mode = InputMode.TOUCH
		elif event is InputEventMouseButton:
			if event.pressed:
				input_mode = InputMode.MOUSE
		elif event is InputEventMouseMotion:
			if (event as InputEventMouseMotion).relative.length() > MOUSE_MOVE_MIN:
				input_mode = InputMode.MOUSE


## 聚焦双环该不该画：键盘、手柄常显；鼠标、触屏不画（悬停只抬底色、点完不留环）。「选中」（当前行、当前页签）不归这里管，照常画。
static func show_focus_ring() -> bool:
	_ensure_input_tracker()
	var m := current_input_mode()
	return m == InputMode.KEYBOARD or m == InputMode.GAMEPAD


## 全局输入监听：第一次问 show_focus_ring() 时挂到根节点下（延后一帧挂，免得在绘制里改树）；只看不吞
class _InputTracker extends Node:
	func _init() -> void:
		name = "XUiSkinInputTracker"
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		XUiSkin.note_input(event)


static var _tracker: Node


static func _ensure_input_tracker() -> void:
	if is_instance_valid(_tracker):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_tracker = _InputTracker.new()
	tree.root.add_child.call_deferred(_tracker)
	# T339 P2-1：_input 是「树里排在后面的先收」，切场景后新场景挂在根上、排到监听节点后面，页面 handled 的事件就漏记了。
	# 根下有新增／调序时把监听节点挪回末位（延后一帧做，免得在信号里改树）
	if not tree.root.child_order_changed.is_connected(_keep_tracker_last):
		tree.root.child_order_changed.connect(_keep_tracker_last)


static func _keep_tracker_last() -> void:
	if not is_instance_valid(_tracker) or not _tracker.is_inside_tree():
		return
	var root := _tracker.get_parent()
	if root != null and root.get_child(root.get_child_count() - 1) != _tracker:
		root.move_child.call_deferred(_tracker, -1)


## 框形／胶囊控件的双环聚焦（规范 2.2、2.4）。ci 是 RID（同 draw_select）；corner_r 是控件本身的圆角，环按同心外扩。
## 「全部」动效档外环随 breath_alpha 慢呼吸并加外软晕；简化／关档外环恒亮、无晕。
static func draw_focus_ring(ci: RID, rect: Rect2, corner_r := ROW_RADIUS, gold_bg := false, alpha := 1.0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or alpha <= 0.0:
		return
	var compact := rect.size.y < FOCUS_COMPACT_H
	var ba := breath_alpha() * alpha
	var outer_col := Color(TEXT_HI if gold_bg else GOLD_LIGHT, ba)
	var half := FOCUS_RING_W
	var r_in := clampi(corner_r + half, 0, int((rect.size.y + half * 2) * 0.5))
	var r_out := clampi(corner_r + FOCUS_EXPAND, 0, int((rect.size.y + FOCUS_EXPAND * 2) * 0.5))
	if breathing():
		var halo := _flat("focus_halo")
		halo.draw_center = false
		halo.set_border_width_all(0)
		halo.shadow_color = Color(outer_col.r, outer_col.g, outer_col.b, (0.22 if compact else 0.28) * ba)
		halo.shadow_size = 3 if compact else 4
		halo.shadow_offset = Vector2.ZERO
		halo.set_corner_radius_all(r_out)
		halo.draw(ci, rect.grow(float(FOCUS_EXPAND)))
	var inner := _flat("focus_in")
	inner.draw_center = false
	inner.shadow_size = 0
	inner.anti_aliasing = true
	inner.border_color = Color(FOCUS_IN, (FOCUS_IN_ALPHA_COMPACT if compact else FOCUS_IN_ALPHA) * alpha)
	inner.set_border_width_all(FOCUS_RING_W)
	inner.set_corner_radius_all(r_in)
	inner.draw(ci, rect.grow(float(half)))
	var outer := _flat("focus_out")
	outer.draw_center = false
	outer.shadow_size = 0
	outer.anti_aliasing = true
	outer.border_color = outer_col
	outer.set_border_width_all(FOCUS_RING_W)
	outer.set_corner_radius_all(r_out)
	outer.draw(ci, rect.grow(float(FOCUS_EXPAND)))


## 圆形控件（环节点、头像钮）的双环：内黑贴圆外 0～2px、外淡金 2～4px
static func draw_focus_circle(ci: CanvasItem, center: Vector2, radius: float, gold_bg := false, alpha := 1.0) -> void:
	if radius <= 0.0 or alpha <= 0.0:
		return
	var ba := breath_alpha() * alpha
	ci.draw_arc(center, radius + 1.0, 0.0, TAU, 64, Color(FOCUS_IN, FOCUS_IN_ALPHA * alpha), 2.0, true)
	ci.draw_arc(center, radius + 3.0, 0.0, TAU, 64, Color(TEXT_HI if gold_bg else GOLD_LIGHT, ba), 2.0, true)


## ---- 规范 3：表面色阶（6%～10% 明度阶跃；POLISH_V1 暖炭黑，关着冷黑）----
enum Surface { SUNKEN = -1, S0 = 0, S1 = 1, S2 = 2, S3 = 3, S4 = 4 }
const SURFACE_WARM := {-1: Color("0b0909d1"), 0: Color("090808"), 1: Color("1b1818"), 2: Color("2e2928"), 3: Color("36302e"), 4: Color("413a38")}
const SURFACE_COLD := {-1: Color("070709d1"), 0: Color("050506"), 1: Color("18191c"), 2: Color("26282e"), 3: Color("2e3038"), 4: Color("383b44")}
## 有竖向渐变的两级：[上, 下]（S1 程序兜底面板、S3 浮层）
const SURFACE_GRAD_WARM := {1: [Color("201c1c"), Color("151313")], 3: [Color("36302e"), Color("25201f")]}
const SURFACE_GRAD_COLD := {1: [Color("18191c"), Color("0e0e10")], 3: [Color("2e3038"), Color("1d1f24")]}
const S3_ALPHA := 0.94
const SURFACE_TINT := Color("f0e6d8")
## 叠在烟底上用的透明层（规范 3.2 最右列）
const SURFACE_OVERLAY := {"s2": 0.09, "zebra": 0.08, "s4": 0.09}
const SURFACE_PRESS_DARK := 0.22


## 实心表面色；level 用 Surface（-1 凹槽 … 4 悬停）
static func surface_c(level: int) -> Color:
	var t: Dictionary = SURFACE_WARM if polish_on() else SURFACE_COLD
	return t.get(clampi(level, -1, 4), t[1])


## 渐变表面 [上, 下]；没有渐变的级上下同色。S3 带 94% 不透明
static func surface_grad(level: int) -> Array:
	var t: Dictionary = SURFACE_GRAD_WARM if polish_on() else SURFACE_GRAD_COLD
	var pair: Array = t.get(level, [surface_c(level), surface_c(level)])
	if level == Surface.S3:
		return [Color(pair[0], S3_ALPHA), Color(pair[1], S3_ALPHA)]
	return pair


## 叠在烟底上的透明层：tier＝"s2"／"zebra"／"s4"；"sunken"＝凹槽暗底
static func surface_overlay(tier: String) -> Color:
	if tier == "sunken":
		return sunken_c()
	return Color(SURFACE_TINT, float(SURFACE_OVERLAY.get(tier, 0.09)))


## 列表／对比表斑马纹（S2z：0.08，较 S1 +6.4%，替换原 0.026）
static func zebra_c() -> Color:
	return surface_overlay("zebra")


## 量条底槽、滚动条轨、输入框凹底
static func sunken_c() -> Color:
	return Color(0.03, 0.025, 0.024, 0.78)


## 按下态：所属层压暗 22%
static func pressed_c(c: Color) -> Color:
	return c.darkened(SURFACE_PRESS_DARK)


## ---- 规范 4：文字基线与行内图标 ----
## 文字墨迹中心对行中线：基线＝行中线＋0.36·字号（现有 62 处照旧手写，不替换；新控件调这里）
const TEXT_CY_K := 0.36
## 行内图标相对行中线的下移系数：卡 D2 实量前 0
const ICON_DY_K := 0.0


static func text_baseline_y(row_cy: float, fs: int) -> float:
	return roundf(row_cy + float(fs) * TEXT_CY_K)


static func inline_icon_rect(x: float, row_cy: float, icon_px: float, fs: int) -> Rect2:
	var dy := roundf(float(fs) * ICON_DY_K)
	return Rect2(roundf(x), roundf(row_cy - icon_px * 0.5 + dy), icon_px, icon_px)


## 图标与文字的水平间距（规范 4.1 表末列）
static func inline_icon_gap(fs: int) -> int:
	return maxi(6, roundi(fs * 0.35))
