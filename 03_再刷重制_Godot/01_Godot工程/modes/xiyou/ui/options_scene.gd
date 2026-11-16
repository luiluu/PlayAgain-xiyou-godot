class_name XOptionsScene
extends Control
## 主菜单「设置」：MV Scene_Options，按正式 v0.16 运行时复现（参照 04_验证/本地结果/原版参照/claude_options_00）。
## - 背景同主菜单（MOG_MenuBackground 底图＋粒子），窗口不透明度 30、背景 192。
## - Window_Options (440,130,400,460)：行高 36、字号 26、可见 12 行；名字左对齐在 itemRectForText (6,宽 360) 的前 240，
##   状态右对齐在内容 x 240、宽 120（statusWidth）。33 项与正式版同序；「挂机设置」只在挂机未禁用时出现（needAddHangUp）。
## - 已重制：坐标、智能AI、始终跑步、记住指令、Battle Camera（YEP_X_ActSeqPack3，行动序列镜头）、伤害数字、技能动画、掉落动画、战斗伤害记录开关，挂机设置，四路音量与四档战斗变速，
##   战力显示与估算（ON/OFF，确定取反、右开左关；切换时清掉战力缓存，XPower），
##   消息提醒（状态「全部显示」/「N项关闭」，确定音后打开 XNoticeOptionsScene，左右无作用），
##   核心杂项开关（只遇稀有/罕见/极其稀有、穿墙、三条宣传行、对话跳过、禁用遇敌、步步遇敌）：确定取反、右开左关；
##   除穿墙外不存配置，开局未设置时状态空白（正式版 statusText 返回 undefined）。
##   队列跟随：变量 24 为 0 时 ON；切换写变量 24（开 0、关 1）并显示/隐藏跟随（重制版只能在游戏中打开设置，不会是「进入游戏」）。
##   角色换装（XCostumes）：状态「打开」，确定不播音直接打开 XCostumesScene，左右无作用（战斗外观的接入见 XCostumes）。
##   屏蔽掉落：状态恒空白，确定无音效直接打开 XPingbiScene，左右只改无作用的 pingbiDrop（值变了播光标音）。
##   灰显（不显示状态，确定时蜂鸣）的只剩三项：测试模式、GM 工具（本机有解锁文件时可点，见 XTestMode），待提交反馈（要原版服务器，未移植）。
## - 上下键：按住连续移动、首按可首尾循环，换行播光标音；取消（Esc/右键）播取消音返回主菜单。

signal closed

const RECT := Rect2(440, 130, 400, 460)
const LH := 36.0
const ROWS := 12
const STATUS_W := 120.0
## O-024：从挂机设置/消息提醒子页返回时保留光标位置（原版 Scene_Options 重建，回到第 0 项）
static var KEEP_INDEX_AFTER_PAGE := true
## [名字, 符号, 已重制]（正式 v0.19 Window_Options._list 顺序：v0.19 加「消息提醒」、去掉「技能升级通告」）
const OPTIONS := [["坐标显示", "MapXy", true], ["挂机设置", "HangUp", true], ["始终跑步", "alwaysDash", true],
	["记住指令", "commandRemember", true], ["战斗镜头", "battleCamera", true], ["开启掉落动画", "MOG_TrPopUpBattle_Key", true],
	["战斗伤害记录", "CombatDamageRecordKey", true], ["显示伤害数字", "CombatDamageShow", true], ["显示技能动画", "CombatSkillAnimation", true],
	["屏蔽掉落", "pingbiDrop", true], ["智能战斗AI（自动战斗）", "codexSmartAI", true], ["BGM 音量", "bgmVolume", true],
	["BGS 音量", "bgsVolume", true], ["ME 音量", "meVolume", true], ["SE 音量", "seVolume", true], ["只遇稀有", "Boss", true],
	["只遇罕见", "BOSS", true], ["极其稀有", "boss", true], ["穿墙开关", "cq", true], ["此游戏为免费游戏！", "wxxonoff", true],
	["总群请加906327865！", "wxlonoff", true], ["不要在闲鱼买到这个版本！", "wxtonoff", true], ["战斗变速", "battleAniSpeed", true],
	["对话跳过", "dhtg", true], ["禁用遇敌", "ydgb", true], ["步步遇敌", "yd100", true], ["消息提醒", "codexNotices", true],
	["队列跟随", "codexFollow", true],
	["战力显示与估算", "codexPowerEnabled", true], ["测试模式", "codexTestMode", false], ["GM 工具", "codexGM", false],
	["角色换装", "codexCostumes", true], ["待提交反馈", "codexFeedbackPending", false]]

## 天启篇存档（皮肤有机会开）的旧列表：防骗三行（原版是三行 ON/OFF 空白的宣传行）不再当列表项，合成页底一行静态提示；西游档照原版 33 行不动（T051）
const ADS_SYMBOLS := ["wxxonoff", "wxlonoff", "wxtonoff"]
const ADS_TIP := "本游戏免费，勿在闲鱼购买；总群 1097315054"

## 重制新增：大厅初步异化（XLobbyCorruption）的光尘与氛围小字，关掉不放
const FX_OPTION := ["画面特效", "codexScreenFx", true]
## 重制新增：画面平滑（XScreenScale，玩家反馈 v0.01「画面锐化太高」）：开＝先画 1280×720 再整幅柔和放大（同原版），关＝按屏幕分辨率直接画
const SMOOTH_OPTION := ["画面平滑", "codexScreenSmooth", true]
## 重制新增：定向遇怪（O-384，XEncounterTarget）：替换原版「只遇稀有／只遇罕见／极其稀有」三行，左右与确定切换档位，存配置
const TARGET_OPTION := ["定向遇怪", XEncounterTarget.KEY, true]
## 重制新增：进战斗默认自动（O-383，XBattleScene.AUTO_DEFAULT）：ON 时每场战斗开局自动按钮就是开；默认 OFF
const AUTO_OPTION := ["进战斗默认自动", "codexBattleAutoDefault", true]
## 重制新增：战斗站位（O-473，XPartyFormation）：两排错开／菱形／原版竖排，左右与确定切换，存配置，下一场战斗生效
const FORMATION_OPTION := ["战斗站位", XPartyFormation.KEY, true]
## 重制新增：画质设置（XGraphics）：状态「调整」，确定音后打开 XGraphicsOptionsScene，左右无作用
const QUALITY_OPTION := ["画质设置", "codexQuality", true]

## 新界面（第 5C 批）：「界面风格：新／原版」「界面动效：全部／简化／关」。只在新皮肤有机会开的存档里（天启篇，XUiSkin.selectable()）出现，重制版里不列；
## 动效一行只在新皮肤开着时列（原版界面没有这些动画）。排在画质设置之后、进战斗默认自动之前。
const SKIN_OPTION := ["界面风格", "codexUiSkin", true]
const MOTION_OPTION := ["界面动效", "codexUiMotion", true]
const MOTION_NAMES := ["全部", "简化", "关"]
## 新界面 4A（C8，XSkin4A.DIM_V2）：「战斗背景压暗：关／15%／30%」，只在新皮肤开着时列，排在界面动效后
const DIM_OPTION := ["战斗背景压暗", "codexBattleDim", true]
## 天启篇「装备环纹」（XTianqiRingStyle，D101）：开／关，默认开；只在新界面开着时列（环纹只画在新界面装备页），排在界面动效后
const RING_STYLE_OPTION := ["装备环纹", "codexRingStyle", true]

## 重制新增：本次更新内容（XWhatsNew，update-whatsnew）：现在运行的这一版有更新说明时才列，状态「查看」，确定再看一次「本次更新内容」弹窗
const WHATS_NEW_OPTION := ["本次更新内容", "codexWhatsNew", true]

## 只在触屏（安卓）出现，排在最后；状态「调整」，确定音后打开 XTouchOptionsScene，左右无作用。
const TOUCH_OPTION := ["手机按键设置", "codexAndroidControls", true]

## 开关类符号只在这里列一份：存配置的 ON/OFF 开关、四路音量用 XConfig.VOLUMES、本次运行开关用 XConfig.SESSION_FLAGS
## （含 pingbiDrop：状态恒空白、确定打开屏蔽页，只有左右键会改它）
const FLAG_SYMBOLS := ["MapXy", "codexSmartAI", "alwaysDash", "commandRemember", "battleCamera", "CombatDamageShow",
	"CombatSkillAnimation", "cq", "MOG_TrPopUpBattle_Key", "CombatDamageRecordKey", "codexPowerEnabled", "codexBossStatusPanel",
	"codexScreenFx", "codexScreenSmooth", "codexBattleAutoDefault", "codexRingStyle"]

## 挂机设置页用：打开菜单前的地图截图与玩家所在的画面格（由地图经主菜单传入）
var map_shot: Texture2D
var player_tile := Vector2.ZERO
var index := 0
var top := 0
var win: XMVWindow
var _list: Array = []
var _page: Control
## 新界面（XUiSkin.on() 时）：设置主页换成 XSkinOptionsPage 的布局（状态机不变）；关着时为 null，旧页一行不变
var skin: XSkinOptionsPage
## 本页自己加的背景节点（切换界面风格时整套换掉）
var _bg_nodes: Array = []
## 本次改过「界面风格」：关设置页时连菜单一起关回地图（菜单是按旧风格建的，重开才换）；XMenu 读 to_map
var to_map := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_list()
	_add_backdrop()
	win = XMVWindow.make(self, RECT, XUI.MENU_WINDOW_OPACITY, _paint)
	win.canvas.blink = true
	if XUiSkin.on():
		_show_skin(true)
	_build_ads_tip()
	_refresh()


func _build_list() -> void:
	_list = OPTIONS.filter(func(o): return o[1] != "HangUp" or XHangUp.enabled(XState.current))
	if XUiSkin.selectable():  # 天启篇存档：防骗三行改页底提示（皮肤开时新布局本来就藏；存档里没有这三项的值，无兼容问题）
		_list = _list.filter(func(o): return not ADS_SYMBOLS.has(o[1]))
	if XEncounterTarget.ENABLED:  # 定向遇怪占原「只遇稀有」的位子，另两行去掉
		_list = _list.filter(func(o): return o[1] != "BOSS" and o[1] != "boss").map(func(o): return TARGET_OPTION if o[1] == "Boss" else o)
	if XBossStatusPanel.TOGGLE:  # v0.56：「Boss状态面板」在「步步遇敌」后、「消息提醒」前（v0.62.12 options_probe 的行序）
		_list.insert(_list.find_custom(func(o): return o[1] == "codexNotices"), ["首领状态面板", "codexBossStatusPanel", true])
	if not XPower.SHOW_POWER_UI:  # 战力先藏：设置页也不列「战力显示与估算」（回退＝XPower.SHOW_POWER_UI 设 true）
		_list = _list.filter(func(o): return o[1] != "codexPowerEnabled")
	if XTestMode.unlocked():  # 只有 Kyo 本机有解锁文件时，测试模式／GM 工具两项才可点（没有时照旧留灰）
		_list = _list.map(func(o): return [o[0], o[1], true] if o[1] == "codexTestMode" or o[1] == "codexGM" else o)
	if XLobbyCorruption.ENABLED:  # 重制新增「画面特效」（大厅初步异化的光尘与小字）排在原版各项之后；开关关掉时不列
		_list.append(FX_OPTION)
	if XScreenScale.ENABLED:  # 画面平滑排在画面特效后、手机按键设置前；开关关掉时不列
		_list.append(SMOOTH_OPTION)
	if XGraphics.ENABLED:  # 画质设置排在画面平滑后、手机按键设置前；开关关掉时不列
		_list.append(QUALITY_OPTION)
	if XUiSkin.selectable():  # 界面风格、界面动效（5C）：天启篇才列；动效只在新界面开着时列
		_list.append(SKIN_OPTION)
		if XUiSkin.on():
			_list.append(MOTION_OPTION)
			if XTianqiRingStyle.ENABLED:
				_list.append(RING_STYLE_OPTION)
			if XSkin4A.DIM_V2:
				_list.append(DIM_OPTION)
	if XBattleScene.AUTO_DEFAULT:  # 进战斗默认自动排在画质设置后、手机按键设置前；开关关掉时不列
		_list.append(AUTO_OPTION)
	if XPartyFormation.ENABLED:  # 战斗站位排在进战斗默认自动后、手机按键设置前；开关关掉时不列
		_list.append(FORMATION_OPTION)
	if XWhatsNew.ENABLED and not XWhatsNew.current(XUpdateClient.current_code()).is_empty():  # 本次更新内容排在手机按键设置前；没有说明或开关关掉时不列
		_list.append(WHATS_NEW_OPTION)
	if XPlatform.is_touch():  # 原版二合一包 Codex_AndroidTouchSettings：安卓在列表末尾加「手机按键设置」（平台三期 BP）
		_list.append(TOUCH_OPTION)


## 背景：旧界面的底图加粒子，新界面的黑底；记下加了哪些节点，切换风格时好整套换掉
func _add_backdrop() -> void:
	var before := get_children()
	XUI.menu_background(self)
	_bg_nodes = get_children().filter(func(n): return not before.has(n))
	for n in _bg_nodes:
		move_child(n, 0)


## 新界面开：建 XSkinOptionsPage、藏旧窗口；关：反过来
func _show_skin(v: bool) -> void:
	if v:
		if skin == null:
			skin = XSkinOptionsPage.new(self)
			add_child(skin)
		win.hide()
	else:
		if skin != null:
			skin.queue_free()
			skin = null
		win.show()
	_build_ads_tip()   # 风格换了：提示跟着显隐（新布局不放，回旧布局补上）


static func _group(symbol: String) -> String:
	if FLAG_SYMBOLS.has(symbol):
		return "flag"
	if XConfig.SESSION_FLAGS.has(symbol):
		return "session"
	return "volume" if XConfig.VOLUMES.has(symbol) else ""


func symbols() -> Array:
	return _list.map(func(o): return o[1])


func status_text(i: int) -> String:
	var symbol := str(_list[i][1])
	match _group(symbol):
		"flag":
			return "ON" if XConfig.flag(symbol) else "OFF"
		"session":
			var v = XConfig.session_value(symbol)
			return "" if v == null or symbol == "pingbiDrop" else ("ON" if v else "OFF")
		"volume":
			return str(XConfig.volume(symbol))
	match symbol:
		"battleAniSpeed":
			return XConfig.battle_speed_text()
		XEncounterTarget.KEY:
			return XEncounterTarget.text()
		XPartyFormation.KEY:
			return XPartyFormation.text()
		"codexNotices":
			return XConfig.notices_text()
		"codexFollow":
			return "ON" if _follow_on() else "OFF"
		"codexAndroidControls", "codexQuality":
			return "调整"
		"codexWhatsNew":
			return "查看"
		"codexUiSkin":
			return "新" if XConfig.ui_skin_new() else "原版"
		"codexUiMotion":
			return MOTION_NAMES[XUiSkin.motion()]
		"codexBattleDim":
			return XSkin4A.dim_text(XConfig.battle_dim())
		"codexCostumes":
			return "打开" if XCostumes.can_open(XState.current) else "进入游戏"
		"codexTestMode":
			return ("ON" if XTestMode.enabled() else "OFF") if XTestMode.unlocked() else ""
		"codexGM":
			if not XTestMode.unlocked():
				return ""
			return "打开" if XTestMode.can_open(XState.current) else ("进入游戏" if XTestMode.enabled() else "需开启")
	return ""


func _refresh() -> void:
	if skin != null:
		skin.sync()
		return
	win.up_arrow = top > 0
	win.down_arrow = top < _list.size() - ROWS
	win.refresh()


func _paint(c: XMVCanvas) -> void:
	for i in range(top, mini(top + ROWS, _list.size())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		var alpha := 1.0 if _list[i][2] else XUI.DIM.a
		var title_w := c.size.x - 12.0 - STATUS_W
		c.text(_list[i][0], 6, y, title_w, "left", XUI.TEXT, XUI.FONT_SIZE, LH, alpha)
		c.text(status_text(i), title_w, y, STATUS_W, "right", XUI.TEXT, XUI.FONT_SIZE, LH, alpha)


## 页底提示是否显示：天启篇存档的旧布局（防骗三行已从列表去掉；新布局 skin 开着时不画）
func ads_tip() -> bool:
	return skin == null and XUiSkin.selectable() and not _list.is_empty() and not symbols().has("wxxonoff")


## 提示画在设置窗口外下方（窗口内 432 px 画布正好装 12 行，下箭头又贴着窗底），不跟列表行和箭头抢位置
func ads_tip_rect() -> Rect2:
	return Rect2(RECT.position.x, RECT.end.y + 6.0, RECT.size.x, 28.0)


func _build_ads_tip() -> void:
	var old := get_node_or_null("AdsTip")
	if old != null:   # 先摘掉旧的（立即不可见、查不到），再按当前状态决定要不要补建
		remove_child(old)
		old.queue_free()
	if not ads_tip():
		return
	var l := Label.new()
	l.name = "AdsTip"
	l.text = ADS_TIP
	l.position = ads_tip_rect().position
	l.size = ads_tip_rect().size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", XUI.TEXT)
	l.modulate.a = XUI.DIM.a
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


# ---- 操作 ----
func _select(i: int) -> void:
	if i == index:
		return
	index = i
	if index < top:
		top = index
	elif index >= top + ROWS:
		top = index - ROWS + 1
	XSound.system(0)
	_refresh()


func ok() -> void:
	var o: Array = _list[index]
	if not o[2]:
		XSound.system(3)
		return
	var symbol := str(o[1])
	match _group(symbol):
		"flag":
			_set_flag(symbol, not XConfig.flag(symbol))
			return
		"session":
			if symbol != "pingbiDrop":
				_set_session(symbol, not XConfig.flag(symbol))
				return
		"volume":
			var value := XConfig.volume(symbol) + 20
			_set_volume(symbol, 0 if value > 100 else value)
			return
	match symbol:
		"battleAniSpeed":
			_set_speed(XConfig.battle_speed() % 4 + 1)
		XEncounterTarget.KEY:
			_set_target((XConfig.encounter_target() + 1) % XEncounterTarget.NAMES.size())
		XPartyFormation.KEY:
			_set_formation((XConfig.party_formation() + 1) % XPartyFormation.NAMES.size())
		"HangUp":
			XSound.system(1)
			_open_hang_up()
		"pingbiDrop":
			_open_page(XPingbiScene.new())
		"codexFollow":
			_set_follow(not _follow_on())
		"codexUiSkin":
			_set_ui_skin(not XConfig.ui_skin_new())
		"codexUiMotion":
			_set_ui_motion((XUiSkin.motion() + 1) % 3)
		"codexBattleDim":
			var cur := XConfig.battle_dim()
			_set_battle_dim(XSkin4A.DIM_LEVELS[(XSkin4A.DIM_LEVELS.find(cur) + 1) % XSkin4A.DIM_LEVELS.size()])
		"codexNotices":
			XSound.system(1)
			_open_page(XNoticeOptionsScene.new())
		"codexAndroidControls":
			XSound.system(1)
			_open_page(XTouchOptionsScene.new())
		"codexQuality":
			XSound.system(1)
			_open_page(XGraphicsOptionsScene.new())
		"codexWhatsNew":
			var rec := XWhatsNew.current(XUpdateClient.current_code())
			if rec.is_empty():
				XSound.system(3)
			else:
				XSound.system(1)
				XWhatsNewPage.open(self, rec, skin != null)
		"codexTestMode":
			if XTestMode.unlocked():
				_set_test_mode(not XTestMode.enabled())
		"codexGM":
			if XTestMode.can_open(XState.current):
				_open_page(XTestModeScene.new())
			else:
				XSound.system(3)
		"codexCostumes":
			# C.open：Window_Options.processOk 被整个换掉，不播确定音；不能开时蜂鸣
			if XCostumes.can_open(XState.current):
				_open_page(XCostumesScene.new())
			else:
				XSound.system(3)


## Window_Options.changeValue：值变了才存、重画并播光标音；HangUp 不改值
func _side(right: bool) -> void:
	var symbol := str(_list[index][1])
	match _group(symbol):
		"flag":
			_set_flag(symbol, right)
		"session":
			_set_session(symbol, right)
		"volume":
			_set_volume(symbol, clampi(XConfig.volume(symbol) + (20 if right else -20), 0, 100))
		_:
			match symbol:
				"codexFollow":
					_set_follow(right)
				"codexUiSkin":
					_set_ui_skin(right)
				"codexUiMotion":
					_set_ui_motion(clampi(XUiSkin.motion() + (1 if right else -1), 0, 2))
				"codexBattleDim":
					_set_battle_dim(XSkin4A.dim_step(XConfig.battle_dim(), right))
				"codexTestMode":
					if XTestMode.unlocked():
						_set_test_mode(right)
				"battleAniSpeed":
					_set_speed(clampi(XConfig.battle_speed() + (1 if right else -1), 1, 4))
				XEncounterTarget.KEY:
					_set_target(clampi(XConfig.encounter_target() + (1 if right else -1), 0, XEncounterTarget.NAMES.size() - 1))
				XPartyFormation.KEY:
					_set_formation(clampi(XConfig.party_formation() + (1 if right else -1), 0, XPartyFormation.NAMES.size() - 1))


func _set_map_xy(v: bool) -> void:
	_set_flag("MapXy", v)


func _set_flag(sym: String, v: bool) -> void:
	if XConfig.flag(sym) == v:
		return
	XConfig.set_flag(sym, v)
	if sym == "codexPowerEnabled":
		XPower.clear_cache()  # installCombatPowerRuntime changeValue：开关变了清缓存
	if sym == XScreenScale.KEY:
		XGraphics.apply()  # 省电模式开着时画面平滑恒生效，别让这里的开关把它切回去
	XSound.system(0)
	_refresh()


## 未设置（null）也算不同：原版 changeValue 用 !== 比较
func _set_session(sym: String, v: bool) -> void:
	if XConfig.session_value(sym) == v:
		return
	XConfig.set_session(sym, v)
	XSound.system(0)
	_refresh()


func _follow_on() -> bool:
	return XState.current != null and XState.current.variable(24) == 0


func _set_follow(v: bool) -> void:
	if _follow_on() == v or XState.current == null:
		return
	XState.current.set_variable(24, 0 if v else 1)
	XState.current.followers_visible = v
	XSound.system(0)
	_refresh()


func _set_test_mode(v: bool) -> void:
	if XTestMode.enabled() == v:
		return
	XTestMode.set_enabled(v)
	XSound.system(0)
	_refresh()


func _set_volume(sym: String, v: int) -> void:
	if XConfig.volume(sym) == v:
		return
	XConfig.set_volume(sym, v)
	XSound.system(0)
	_refresh()


func _set_target(v: int) -> void:
	if XConfig.encounter_target() == v:
		return
	XConfig.set_encounter_target(v)
	XSound.system(0)
	_refresh()


## 界面风格（5C）：存 XConfig，本页立刻换成对应风格；菜单是按旧风格建的，所以关设置页时连菜单一起回地图（to_map），重开菜单就是新风格
func _set_ui_skin(v: bool) -> void:
	if XConfig.ui_skin_new() == v:
		return
	XConfig.set_flag("codexUiSkin", v)
	to_map = true
	XSound.system(0)
	var symbol := str(_list[index][1])
	_build_list()
	for n in _bg_nodes:
		n.queue_free()
	_add_backdrop()
	_show_skin(XUiSkin.on())
	index = maxi(_list.find_custom(func(o): return o[1] == symbol), 0)
	top = clampi(top, 0, maxi(0, _list.size() - ROWS))
	if index < top:
		top = index
	elif index >= top + ROWS:
		top = index - ROWS + 1
	_refresh()


func _set_ui_motion(v: int) -> void:
	if XConfig.ui_motion() == v:
		return
	XConfig.set_ui_motion(v)
	XSound.system(0)
	_refresh()


func _set_battle_dim(v: int) -> void:
	if XConfig.battle_dim() == v:
		return
	XConfig.set_battle_dim(v)
	XSound.system(0)
	_refresh()


func _set_formation(v: int) -> void:
	if XConfig.party_formation() == v:
		return
	XConfig.set_party_formation(v)
	XSound.system(0)
	_refresh()


func _set_speed(v: int) -> void:
	if XConfig.battle_speed() == v:
		return
	XConfig.set_battle_speed(v)
	XSound.system(0)
	_refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _open_hang_up() -> void:
	var page := XHangUpOptionsScene.new()
	page.map_shot = map_shot
	page.player_tile = player_tile
	_open_page(page)


func _open_page(page: Control) -> void:
	if skin != null:
		_open_page_skin(page)
		return
	_page = page
	for node in get_children():
		if node is CanvasItem:
			node.hide()
	add_child(page)
	page.closed.connect(func():
		page.queue_free()
		_page = null
		for node in get_children():
			if node is CanvasItem and node != page:
				node.show()
		if not KEEP_INDEX_AFTER_PAGE:
			index = 0
			top = 0
		_refresh())


## 新界面下开子页（画质、消息提醒、挂机……还是旧页面，按 1280×720 摆）：视口比 16:9 宽时放进居中的 1280×720 外框，背景用本页的（子页自己的新皮肤黑底藏掉，免得接缝）
func _open_page_skin(page: Control) -> void:
	if not page is XTouchOptionsScene:   # 收口批：子页开着时虚拟键也收起；触屏按键设置页要看着键调位置，不收
		page.add_to_group(XUiSkin.FULLSCREEN_GROUP)
	_page = page
	skin.hide()
	var host := Control.new()
	host.name = "SkinSubPageHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(1280, 720)
	var place := func(): host.position = Vector2(maxf(roundf((get_viewport_rect().size.x - 1280.0) / 2.0), 0.0), 0)
	place.call()
	var vp := get_viewport()
	vp.size_changed.connect(place)   # 开着子页时拖窗口、转屏，外框跟着居中
	host.tree_exiting.connect(func(): vp.size_changed.disconnect(place))
	add_child(host)
	host.add_child(page)
	for n in page.get_children():
		if n.name == "SkinBackdrop":
			n.hide()
	page.closed.connect(func():
		page.queue_free()
		host.queue_free()
		_page = null
		skin.show()
		if not KEEP_INDEX_AFTER_PAGE:
			index = 0
			top = 0
		_refresh())


func _gui_input(event: InputEvent) -> void:
	if _page or not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if skin != null:
				return   # 新布局的滚动、点击由列表自己接（XSkinOptionsPage）
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			top = clampi(top + d, 0, maxi(0, _list.size() - ROWS))
			_refresh()
		MOUSE_BUTTON_LEFT:
			if skin != null:
				return
			var p: Vector2 = event.position - RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not RECT.has_point(event.position) or p.y < 0 or p.y >= ROWS * LH:
				return
			var i := top + floori(p.y / LH)
			if i >= _list.size():
				return
			if i == index:
				ok()
			else:
				_select(i)


func _unhandled_input(event: InputEvent) -> void:
	if _page:
		return
	if skin != null and skin.input(event):
		XKeyMap.handled(self)
		return
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		_select(XMenu._move(index, d, _list.size(), not event.is_echo()))
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		XKeyMap.handled(self)
		_side(event.is_action_pressed("ui_right", true))
	elif XMenu.page_dir(event) != 0:
		# Window_Options 不接管 pageup／pagedown：走通用翻页
		XKeyMap.handled(self)
		var r := XMenu.page(top, index, _list.size(), ROWS, XMenu.page_dir(event))
		top = r[0]
		if r[1] != index:
			_select(r[1])
		else:
			_refresh()
