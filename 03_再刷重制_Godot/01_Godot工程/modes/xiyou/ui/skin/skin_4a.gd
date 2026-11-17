class_name XSkin4A
extends RefCounted
## 【cc·天启篇·未经审查】新界面 4A（地图 HUD、触屏键、全局横向铺满）＋战斗可读性（Fable审 A5／A17、舒适 C7／C8、P1-2）。
## 设计稿：私密设计仓 重制设定/界面风格提案_v0.7/ README 第二节「横屏铺满」、Fable审_实装与方向 A5／A17／C7／C8／P1-2、
## 小A审_美化舒适 9（地图 HUD 统一黑金胶囊）、1（亮图压暗）。
## 只在 XUiSkin.on()（天启篇新皮肤）时生效；五个开关各管一块，关掉＝回 ui-skin-close 的样子，皮肤关闭时一行旧代码都不变。
## 只改画法和摆放：不改战斗时序、结算、随机数（闪白只在画的那一刻按系数压透明度，帧数照旧）。

## HUD_V2（O-503）：地图左上挂机钮、右上「存档备份／地图传送」、左下回城枫叶与坐标难度字换成黑底旧金胶囊（触屏能点），
## 挂机提示条换黑金条；触屏虚拟键（摇杆、A／B、存档、隐藏）换黑底旧金描边。false＝旧样子、旧位置。
static var HUD_V2 := true
## WIDE_V2（O-504）：地图和战斗在比 16:9 宽的屏上横向铺满（XSkinLayout.request_wide），两侧不再留黑边；
## 地图 HUD、虚拟键贴着安全边距摆；4:3 照旧上下留边。地图上开着按 1280 排的旧页面（商店、旧子页等）时自动收回 16:9。false＝地图、战斗照旧 16:9 加黑边。
static var WIDE_V2 := true
## TEXT_V2（O-505，A5）：战斗里没有底板的字（回合提示、首领名、首领血量数字、敌人名字和血量数字）加深色胶囊底。false＝只有原来的描边。
static var TEXT_V2 := true
## DIM_V2（O-506，C8）：设置「战斗背景压暗：关／15%／30%」，在战斗背景和角色、界面之间盖一层黑。false＝设置页不列、不盖。
static var DIM_V2 := true
## FLASH_V2（O-507，C7）：整屏闪光每秒最多 3 次（间隔不到 1/3 秒的整屏闪光不画）；战斗变速越高闪白越弱（2 倍半强、3 倍及以上不画），
## 只压画出来的透明度，闪光帧数、行动时序不变。false＝照旧。
static var FLASH_V2 := true

## ---- 胶囊（小A审 美化 9：#080708 85% 半透明＋1px 暖锡灰细边＋旧金字＋琥珀状态点）----
const CAP_FILL := Color(0.031, 0.027, 0.031, 0.85)
const CAP_LINE := Color("8a8174")          # 暖锡灰
const CAP_LINE_ALPHA := 0.75
const CAP_HOT_FILL := Color("2b2318")       # 按下／悬停：深褐金
const AMBER := Color("f0a43a")             # 琥珀状态点（挂机中）
const CAP_H := 40.0
const CAP_FS := 18
## 战斗浮字的胶囊底（A5）：比 HUD 胶囊再深一点、不描边
const TEXT_CAP := Color(0.02, 0.02, 0.025, 0.62)
## 新美术（小o 在画的 HUD 小图标、面板材质）的替换口：有这个目录下的 hud_<名字>.png 就用图，没有就程序画
const ICON_DIR := "res://content/ui_skin/hud/"

## C8：压暗档（百分比）与默认
const DIM_LEVELS := [0, 15, 30]
const DIM_DEFAULT := 15
const DIM_KEY := "codexBattleDim"
## C7：整屏闪光最短间隔（毫秒）＝每秒最多 3 次
const FLASH_MIN_GAP_MS := 334
static var _last_screen_flash_ms := -100000
## 画过几次浮字胶囊底（测试读）
static var backing_count := 0
## 测试钉住时间（-1＝真实时间）
static var clock_override_ms := -1


static func hud_on() -> bool:
	return HUD_V2 and XUiSkin.on()


static func wide_on() -> bool:
	return WIDE_V2 and XUiSkin.on()


static func text_on() -> bool:
	return TEXT_V2 and XUiSkin.on()


static func dim_on() -> bool:
	return DIM_V2 and XUiSkin.on()


static func flash_on() -> bool:
	return FLASH_V2 and XUiSkin.on()


## 画面可见区大小：铺满开着时取视口（宽屏可能 1600×720），否则就是 1280×720（旧代码的写死值）
static func view_size(node: Node) -> Vector2:
	if wide_on() and node != null and node.is_inside_tree():
		return node.get_viewport().get_visible_rect().size
	return Vector2(1280, 720)


## 左右安全边距（同 XSkinLayout：16:9 是 24，宽屏到 56）再并上设备安全区缩进
static func safe_rect(node: Node) -> Rect2:
	var vs := view_size(node)
	var m := XSkinLayout.margin_for(vs.x)
	var ins := [0.0, 0.0, 0.0, 0.0]
	if node != null and node.is_inside_tree():
		ins = XPlatform.safe_insets(node.get_viewport())
	var l := maxf(m, ins[0])
	var r := maxf(m, ins[2])
	var t := maxf(8.0, ins[1])
	var b := maxf(8.0, ins[3])
	return Rect2(l, t, vs.x - l - r, vs.y - t - b)


## ---- 画法 ----
## 黑金胶囊（HUD 按钮、挂机条）：hot＝按下或悬停（底换深褐金）；disabled＝字和边都压暗
static func draw_capsule(ci: CanvasItem, r: Rect2, hot := false, disabled := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CAP_HOT_FILL if hot and not disabled else CAP_FILL
	sb.set_corner_radius_all(int(r.size.y / 2.0))
	sb.set_border_width_all(1)
	sb.border_color = Color(XUiSkin.GOLD if hot and not disabled else CAP_LINE, CAP_LINE_ALPHA * (0.5 if disabled else 1.0))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## 战斗浮字的深色胶囊底（A5）：文字基线在 base_y、宽 w、字号 fs；左边 x0
static func draw_text_backing(ci: CanvasItem, x0: float, base_y: float, w: float, fs: int, alpha := 1.0) -> void:
	if w <= 0.0 or alpha <= 0.0:
		return
	backing_count += 1
	var h := roundf(fs * 1.35)
	var pad := roundf(fs * 0.55)
	var r := Rect2(x0 - pad, base_y - fs * 0.98, w + pad * 2.0, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(TEXT_CAP, TEXT_CAP.a * alpha)
	sb.set_corner_radius_all(int(h / 2.0))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## 带胶囊底的字：底＋2px 深描边＋字（底只在 TEXT_V2 时画）
static func backed_text(ci: CanvasItem, font: Font, pos: Vector2, s: String, fs: int, color: Color, alpha := 1.0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if text_on():
		draw_text_backing(ci, pos.x, pos.y, w, fs, alpha)
	ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75 * alpha))
	XUiSkin.ds(ci, font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, color.a * alpha))


## HUD 小图标：有替换图（ICON_DIR/hud_<name>.png）就画图，否则程序画（u4 组图标的画法：旧金主色、左上受光、1px 硬黑边）
static func draw_hud_icon(ci: CanvasItem, name: String, c: Vector2, s: float, alpha := 1.0) -> void:
	var p := ICON_DIR + "hud_%s.png" % name
	if ResourceLoader.exists(p):
		var tex: Texture2D = load(p)
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(1, 1, 1, alpha))
			return
	var gold := Color(XUiSkin.GOLD, alpha)
	var hi := Color(XUiSkin.GOLD_LIGHT, alpha)
	var edge := Color(0, 0, 0, 0.9 * alpha)
	var h := s / 2.0
	match name:
		"save":   # 存档：小方盒（软盘）
			var r := Rect2(c - Vector2(h, h) * 0.8, Vector2(h, h) * 1.6)
			ci.draw_rect(r.grow(1), edge)
			ci.draw_rect(r, gold)
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.22, 0), Vector2(r.size.x * 0.5, r.size.y * 0.36)), Color(0.1, 0.09, 0.08, alpha))
			ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), hi)
		"transfer":   # 传送：菱形罗盘
			var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.7, 0), c + Vector2(0, h), c + Vector2(-h * 0.7, 0)])
			ci.draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(0, -1), pts[1] + Vector2(1, 0), pts[2] + Vector2(0, 1), pts[3] + Vector2(-1, 0)]), edge)
			ci.draw_colored_polygon(pts, gold)
			ci.draw_colored_polygon(PackedVector2Array([pts[0], c, pts[3]]), hi)
			ci.draw_circle(c, maxf(1.5, h * 0.18), Color(0.1, 0.09, 0.08, alpha))
		"return":   # 回城：门洞（拱）
			var w := h * 1.4
			var r := Rect2(c + Vector2(-w / 2.0, -h * 0.2), Vector2(w, h * 1.1))
			ci.draw_circle(c + Vector2(0, -h * 0.2), w / 2.0 + 1.0, edge)
			ci.draw_rect(r.grow(1), edge)
			ci.draw_circle(c + Vector2(0, -h * 0.2), w / 2.0, gold)
			ci.draw_rect(r, gold)
			ci.draw_rect(Rect2(c + Vector2(-w * 0.2, h * 0.1), Vector2(w * 0.4, h * 0.8)), Color(0.1, 0.09, 0.08, alpha))
		"hangup":   # 挂机：沙漏
			var pts := PackedVector2Array([c + Vector2(-h * 0.7, -h), c + Vector2(h * 0.7, -h), c + Vector2(0, 0), c + Vector2(h * 0.7, h), c + Vector2(-h * 0.7, h), c])
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), edge, 3.0, true)
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), gold, 1.6, true)
		_:
			ci.draw_circle(c, h * 0.6 + 1.0, edge)
			ci.draw_circle(c, h * 0.6, gold)


## 触屏虚拟键（右下 A／B／信息那一组）开着时，把 c（画面坐标）往左挪到键组左边再空 12；最左不过 min_x。HUD_V2 关着不动
static func avoid_touch_keys(c: Control, min_x: float) -> void:
	var pad := XTouchControls.instance
	if not hud_on() or pad == null or not pad.is_inside_tree() or not pad.visible or pad.hidden or pad._menu_hidden:
		return
	var act = pad.group_rects.get("actions")
	if not (act is Rect2):
		return
	var r := Rect2(c.position, c.size)
	if not r.intersects(act):
		return
	c.position.x = maxf(min_x, (act as Rect2).position.x - 12.0 - c.size.x)


## 小A核查 P3-1：c 实际画出来的范围（drawn，画面坐标）压到 avoid（如 5 人出战时的队伍面板）就再往左挪到它左边空 8；最左不过 min_x。HUD_V2 关着不动
static func avoid_rect(c: Control, drawn: Rect2, avoid: Rect2, min_x: float) -> void:
	if not hud_on() or avoid.size == Vector2.ZERO or not drawn.intersects(avoid):
		return
	c.position.x = maxf(min_x, c.position.x - (drawn.end.x - (avoid.position.x - 8.0)))


## ---- C8 战斗背景压暗 ----
## 现在的压暗档（0／15／30）；没开（皮肤关、DIM_V2 关）恒为 0
static func dim_percent() -> int:
	if not dim_on():
		return 0
	return XConfig.battle_dim()


## 设置页：下一档／上一档
static func dim_step(cur: int, right: bool) -> int:
	var i := DIM_LEVELS.find(cur)
	if i < 0:
		i = DIM_LEVELS.find(DIM_DEFAULT)
	return DIM_LEVELS[clampi(i + (1 if right else -1), 0, DIM_LEVELS.size() - 1)]


static func dim_text(p: int) -> String:
	return "关" if p <= 0 else "%d%%" % p


## 战斗背景之上、角色之下的那层黑（XBattleScene._build_background 之后加）。比画面大三倍，镜头拉近拉远都盖得住
static func make_dim_layer(vs: Vector2) -> ColorRect:
	var p := dim_percent()
	if p <= 0:
		return null
	var r := ColorRect.new()
	r.name = "BattleDim"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(0, 0, 0, p / 100.0)
	r.position = -vs
	r.size = vs * 3.0
	return r


## ---- C7 闪烁硬线 ----
## 变速倍数 m（1＝原速；战斗动画的 rate 是 MV 的帧间隔 4/2/…，m＝4/rate）再乘全局变速齿轮
static func speed_mult_for_rate(rate: int) -> float:
	return 4.0 / maxf(1.0, float(rate)) * maxf(1.0, Engine.time_scale)


## 战斗变速（XConfig.battleAniSpeed 1～4 ＝ 四倍～原速）的倍数
static func battle_speed_mult() -> float:
	return float(5 - clampi(XConfig.battle_speed(), 1, 4)) * maxf(1.0, Engine.time_scale)


## 闪白强度系数：原速 1、2 倍 0.5、3 倍及以上 0（不画，只留伤害数字）；开关关着恒 1
static func flash_gain(mult: float) -> float:
	if not flash_on():
		return 1.0
	if mult >= 2.75:
		return 0.0
	if mult >= 1.75:
		return 0.5
	return 1.0


static func _now_ms() -> int:
	return clock_override_ms if clock_override_ms >= 0 else Time.get_ticks_msec()


## 一次整屏闪光开始时问：这次画多强（0＝不画）。离上一次画出来的整屏闪光不到 1/3 秒的整屏闪光不画（每秒最多 3 次），再乘变速系数
static func screen_flash_gain(mult: float) -> float:
	if not flash_on():
		return 1.0
	var g := flash_gain(mult)
	if g <= 0.0:
		return 0.0
	var now := _now_ms()
	if now - _last_screen_flash_ms < FLASH_MIN_GAP_MS:
		return 0.0
	_last_screen_flash_ms = now
	return g


static func reset_flash_clock() -> void:
	_last_screen_flash_ms = -100000
