class_name XSkinOptionsPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】设置主页新布局（第 5C 批，套 XSkinTemplatePage）。设置页自己的状态机（XOptionsScene 的 _list／index／ok／_side／子页）一行不动，
## 新皮肤开着时只是换了画法：
## - 左：分类小环（常规／战斗／遇敌／画面／声音／挂机与操作／其他），环心是这一类的项数；
## - 中：这一类的设置项，左名右状态；
## - 右：详情牌，写这一项是干什么的、怎么调。
## 按键：上下选项，确定切换（或进子页），左右调整，Q／E 换分类，取消返回；点分类圆球也能换类（触屏没有 Q／E）。
## 新皮肤里不列的行：三条宣传行（「此游戏为免费游戏！」等）、灰着点不了的（测试模式、GM 工具、待提交反馈，本机有解锁文件时才列）；旧界面里照旧都在。
## 新皮肤关着时 XOptionsScene 不建这一页。

## 分类：[键, 名字, 占位图标号（美术出了分类图标再换）, 包含的设置符号]
const CATS := [
	["general", "常规", 688, ["MapXy", "alwaysDash", "commandRemember", "dhtg", "codexFollow", "cq", "codexCostumes", "pingbiDrop", "codexNotices"]],
	["battle", "战斗", 160, ["battleCamera", "MOG_TrPopUpBattle_Key", "CombatDamageRecordKey", "CombatDamageShow", "CombatSkillAnimation",
		"codexSmartAI", "battleAniSpeed", "codexBattleAutoDefault", "codexBossStatusPanel", "codexPowerEnabled"]],
	["encounter", "遇敌", 193, ["Boss", "BOSS", "boss", "codexEncounterTarget", "ydgb", "yd100"]],
	["screen", "画面", 100, ["codexScreenFx", "codexScreenSmooth", "codexQuality", "codexUiSkin", "codexUiMotion"]],
	["sound", "声音", 384, ["bgmVolume", "bgsVolume", "meVolume", "seVolume"]],
	["hangup", "挂机与操作", 1001, ["HangUp", "codexAndroidControls"]],
]
const OTHER := ["other", "其他", 688]
## 新皮肤里不列的宣传行
const HIDDEN_SYMBOLS := ["wxxonoff", "wxlonoff", "wxtonoff"]
## 新皮肤里换个说法的名字（原版是英文）
const RENAME := {"battleCamera": "战斗镜头"}
## 一句话说明（小A文字审）；没写的显示空
const DESC := {
	"MapXy": "在地图上显示当前所在的坐标。",
	"alwaysDash": "开启后角色始终奔跑，不用再按住加速键。",
	"commandRemember": "战斗中记住每个角色上一次选的指令。",
	"dhtg": "对话快速显示并自动跳过（选项除外）。只在本次游戏有效。",
	"codexFollow": "队友是否跟在队长身后行走。",
	"cq": "开启后可以穿过地图上的障碍。",
	"codexCostumes": "选择各角色在战斗里的外观。",
	"pingbiDrop": "屏蔽指定品质的武器与防具掉落，进入后设置。",
	"codexNotices": "选择哪些类别的消息要弹出提醒。",
	"battleCamera": "战斗中的镜头移动和特写演出。",
	"MOG_TrPopUpBattle_Key": "战斗中掉落物品时弹出的动画。",
	"CombatDamageRecordKey": "战斗中在右下角实时统计出战角色的伤害与占比。",
	"CombatDamageShow": "战斗中在敌我双方身上显示伤害与恢复数字。",
	"CombatSkillAnimation": "战斗中播放技能动画。关闭后战斗更快。",
	"codexSmartAI": "自动战斗时，由智能战斗 AI 来选择行动。",
	"battleAniSpeed": "战斗动画与行动节奏的播放速度。倍数越高越快，「原速」为正常速度。",
	"codexBattleAutoDefault": "开启后，每场战斗一开始就是自动战斗。",
	"codexBossStatusPanel": "与首领战斗时，显示首领的状态面板。",
	"codexPowerEnabled": "显示战力数值与估算。",
	"Boss": "本次游戏只遇到「稀有」的敌群。只在本次游戏有效。",
	"BOSS": "本次游戏只遇到「罕见」的敌群。只在本次游戏有效。",
	"boss": "本次游戏只遇到「极其稀有」的敌群。只在本次游戏有效。",
	"codexEncounterTarget": "指定要遇到的敌群稀有度，档位越高对应越稀有的敌群。",
	"ydgb": "本次游戏不再遇到随机战斗。",
	"yd100": "本次游戏每走一步都会遇敌。",
	"codexScreenFx": "大厅里的光尘、庆典粒子与氛围特效。",
	"codexScreenSmooth": "开启后画面柔和放大；关闭后按屏幕分辨率直接绘制，更锐利。",
	"codexQuality": "帧率、窗口大小、省电等画质选项，进入后设置。",
	"codexUiSkin": "「新」是天启篇的新界面，「原版」沿用旧界面。切换后本页立即生效，退出设置将返回地图。",
	"codexUiMotion": "选中条呼吸、法阵转动等界面动画。省电模式下默认为简化。",
	"bgmVolume": "背景音乐的音量。每次调整 20。",
	"bgsVolume": "环境音的音量。每次调整 20。",
	"meVolume": "演出音乐的音量。每次调整 20。",
	"seVolume": "音效的音量。每次调整 20。",
	"HangUp": "设置自动挂机的范围、逃跑、技能、吃药与卖出等规则，进入后设置。",
	"codexAndroidControls": "调整手机屏幕上的虚拟按键，进入后设置。",
	"codexTestMode": "打开本机的测试功能。",
	"codexGM": "打开测试工具。",
}
## 子页类（确定进入，左右无用）
const PAGE_SYMBOLS := ["HangUp", "pingbiDrop", "codexNotices", "codexAndroidControls", "codexQuality", "codexCostumes", "codexGM"]

var scene: XOptionsScene
var cats: Array = []   # [{key, name, icon, idx:[_list 下标]}]
var cur := 0
var _syncing := false
var _rows_key := []
var _cats_key := []


func _init(s: XOptionsScene) -> void:
	scene = s
	name = "SkinOptionsPage"
	title = "设置"
	group_key = "system"
	columns = 1
	row_height = XUiSkin.ROW_H
	auto_nav = false
	hint_list = [["确定", "切换"], ["左右", "调整"], ["Q / E", "换分类"], ["取消", "返回"]]


func _ready() -> void:
	super()
	if backdrop != null:   # 设置页自己已有一层黑底（子页盖在上面时也要有），这里不再叠第二层
		backdrop.queue_free()
		backdrop = null
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(func(_i): set_focus("list"))
	list.index_changed.connect(func(i):
		if _syncing or cur >= cats.size():
			return
		var idx: Array = cats[cur].idx
		if i < idx.size() and idx[i] != scene.index:
			scene.index = idx[i]
			XSound.system(0)
			scene._refresh())
	list.activated.connect(func(i):
		if _syncing or cur >= cats.size():
			return
		var idx: Array = cats[cur].idx
		if i < idx.size():
			scene.index = idx[i]
			scene.ok())
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			scene.cancel()
			accept_event())
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_focus("list")
	relayout()


## 一项显示在不在新布局里
func shown(i: int) -> bool:
	var o: Array = scene._list[i]
	return bool(o[2]) and not HIDDEN_SYMBOLS.has(str(o[1]))


func _build_cats() -> void:
	cats = []
	var placed := {}
	for c in CATS:
		var idx := []
		for sym in c[3]:
			var i := scene._list.find_custom(func(o): return o[1] == sym)
			if i >= 0 and shown(i):
				idx.append(i)
				placed[i] = true
		if not idx.is_empty():
			cats.append({"key": c[0], "name": c[1], "icon": c[2], "idx": idx})
	var rest := []
	for i in scene._list.size():
		if not placed.has(i) and shown(i):
			rest.append(i)
	if not rest.is_empty():
		cats.append({"key": OTHER[0], "name": OTHER[1], "icon": OTHER[2], "idx": rest})


func category_of(i: int) -> int:
	for k in cats.size():
		if cats[k].idx.has(i):
			return k
	return -1


func row_name(i: int) -> String:
	var o: Array = scene._list[i]
	return str(RENAME.get(str(o[1]), o[0]))


func sync() -> void:
	if layout == null:
		return
	_syncing = true
	_build_cats()
	if cats.is_empty():
		_syncing = false
		return
	var k := category_of(scene.index)
	if k < 0:   # 光标落在新布局不列的行上（旧下标）：挪到第一类第一项
		k = 0
		scene.index = cats[0].idx[0]
	cur = k
	var ckey := cats.map(func(c): return [c.key, c.idx.size()])
	if ckey != _cats_key:
		_cats_key = ckey
		set_categories(cats.map(func(c): return {"key": c.key, "name": c.name, "icon": c.icon}), cur)
	elif ring.index != cur:
		ring.select(cur, false)
	ring_center = [str(cats[cur].idx.size()), "项"]
	list_title = str(cats[cur].name)
	var rows := []
	for i in cats[cur].idx:
		rows.append({"text": row_name(i), "right": status_of(i), "right_color": XUiSkin.GOLD_LIGHT})
	var pos: int = cats[cur].idx.find(scene.index)
	var key := [cur, rows.map(func(r): return [r.text, r.right])]
	if key != _rows_key:
		_rows_key = key
		set_items(rows, pos)
	elif list.index != pos:
		list.select(pos, false)
	_sync_card(scene.index)
	ring.queue_redraw()
	list_panel.queue_redraw()
	_syncing = false


## 状态词只在新页里统一成中文：ON→开、OFF→关、战斗变速的 OFF→原速（旧设置页与 XConfig 存值不动）
func status_of(i: int) -> String:
	var t := scene.status_text(i)
	if t == "OFF" and str(scene._list[i][1]) == "battleAniSpeed":
		return "原速"
	return {"ON": "开", "OFF": "关"}.get(t, t)


func _sync_card(i: int) -> void:
	var sym := str(scene._list[i][1])
	var how := ""
	if PAGE_SYMBOLS.has(sym):   # 先判子页：屏蔽掉落属会话开关，但确定是进子页
		how = "确定进入。"
	elif XOptionsScene._group(sym) in ["flag", "session"] or sym in ["codexFollow", "codexTestMode", "codexUiSkin"]:
		how = "确定切换，左右键直接选择。"
	else:
		how = "确定或左右键调整。"
	var sections := [{"title": "操作", "text": how}]
	set_card({"title": row_name(i), "subtitle": status_of(i), "desc": str(DESC.get(sym, "")), "sections": sections})
	card.queue_redraw()


func _on_ring_changed(i: int) -> void:
	if _syncing or i < 0 or i >= cats.size() or i == cur:
		return
	scene.index = cats[i].idx[0]
	XSound.system(0)
	scene._refresh()


## 换分类（Q／E）：d＝±1，首尾循环
func step_category(d: int) -> void:
	if cats.size() < 2:
		return
	var k := posmod(cur + d, cats.size())
	scene.index = cats[k].idx[0]
	XSound.system(0)
	scene._refresh()


## 用掉了返回 true。上下、确定交给列表（它再回调 scene）；左右＝调整值；Q／E＝换分类；取消＝返回
func input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		scene.cancel()
		return true
	if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		scene._side(event.is_action_pressed("ui_right", true))
		return true
	var pd := XMenu.page_dir(event)
	if pd != 0:
		step_category(pd)
		return true
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_accept"):
		return list.handle_input(event)
	return false
