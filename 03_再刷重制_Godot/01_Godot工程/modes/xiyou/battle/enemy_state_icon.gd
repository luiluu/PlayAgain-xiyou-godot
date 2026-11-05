class_name XEnemyStateIcon
extends RefCounted
## 选敌名字旁的状态图标（ui12）：Olivia_WeaknessDisplay 给每个敌人建的 Window_WeaknessDisplay（640×72、内边距 0）里的
## Sprite_StateIcon（Weakness Show States true），叠 YEP_BuffsStatesCore 的回合数与 CP_StateFloor 的层数。
## 原版读数 tests/fixtures/enemy_state_icon_oracle.json（冻结 v0.28 战斗夹具，2026-11-05）：
## - 位置：名字显示时（Weakness Show Name true、不画血条）图标中心 x＝round(640／2)＋round((名字宽＋32＋4)／2)、y＝round(36／2)−2＝16；
##   不透明度跟名字窗 contentsOpacity。
## - 轮换：animationWait＝SSEP StateIcon÷BattleSpeed(Default)＝40÷2＝20 帧；每次 _animationIndex＋1（越界回 0）、
##   图标取 allIcons()（活着时：带图标的状态，再接强弱化）。图标与数字只在换格时重画。
## - 回合数（drawStateTurns）：状态 showTurns 且 autoRemovalTiming＞0 才画，ceil(剩余回合) 千分位；32×32 位图里 drawText(x−3, y−8, 宽 32, 行高 36, 右对齐)、
##   字号 16、颜色 0；强弱化（drawBuffTurns）同位置，强化色 24、弱化色 2。中毒（timing 0）不画数字，睡眠画。
## - 层数（CP_StateFloor drawStateFloor「%1层」(2, 6) 12 号 #ffffa0 左对齐）：原版把宽度写成 `Window_Base,_iconWidth`
##   （逗号），宽度成了函数，canvas 一个字也不画——原版看不到层数。优化 O-待定（草稿表「敌人状态层数」）：FLOOR_TEXT 开着时照参数画出来，
##   false 回原版不画。
## 整块回退开关 SHOW = false（草稿表「选敌状态图标」）：不画图标与数字（回到重制原来的样子）。

static var SHOW := true
static var FLOOR_TEXT := true
const ICON_BUFF_START := 32
const ICON_DEBUFF_START := 48
const NAME_SIZE := 18          # Olivia Name Font Size
const LINE_H := 36

static var _wait := -1.0


## Sprite_StateIcon.animationWait（SSEP 覆写）
static func wait() -> float:
	if _wait < 0.0:
		var p := XDB.plugin("SSEP_BattleSpeedUp_v2")
		var d := float(str(p.get("BattleSpeed (Default)", "1")))
		_wait = float(str(p.get("StateIcon", "40"))) / (d if d > 0.0 else 1.0)
	return _wait


## Game_BattlerBase.buffIconIndex
static func buff_icon(level: int, param: int) -> int:
	if level > 0:
		return ICON_BUFF_START + mini(level - 1, 1) * 8 + param
	if level < 0:
		return ICON_DEBUFF_START + mini(-level - 1, 1) * 8 + param
	return 0


## statesAndBuffs 与 allIcons 一一对应：[{icon, turns(文字，空＝不画), color(文字色号), floor(文字，空＝不画)}]
static func group(b: XBattler) -> Array:
	var out := []
	if b == null or not b.is_alive():
		return out
	for st in b.states():
		var icon := int(st.get("iconIndex", 0))
		if icon <= 0:
			continue
		var id := int(st.get("id", 0))
		var row := {"icon": icon, "turns": "", "color": 0, "floor": ""}
		if int(st.get("autoRemovalTiming", 0)) > 0 and not str(st.get("note", "")).to_lower().contains("<hide state turns>") and b.state_turns.has(id):
			row.turns = XMenu._group(ceilf(float(b.state_turns[id])))
		if XBattler.FLOOR_STATES.has(id):  # hasStateMoreFloor：带 <Max State Floor> 的状态（canAddedFloor）
			row.floor = "%d层" % b.state_floor(id)
		out.append(row)
	for i in range(b.buffs.size()):
		var lv: int = b.buffs[i]
		if lv == 0:
			continue
		out.append({"icon": buff_icon(lv, i), "turns": XMenu._group(ceilf(float(b.buff_turns[i]))), "color": 24 if lv > 0 else 2, "floor": ""})
	return out


## 图标中心（窗口内容坐标）
static func icon_center(name_width: float) -> Vector2:
	return Vector2(roundf(640.0 / 2.0) + roundf((name_width + 32.0 + 4.0) / 2.0), roundf(LINE_H / 2.0) - 2.0)


## 每帧推进（_animationCount），返回是否换了格；st＝{count, index, cur}（cur＝换格时拍下的那一行，没有为空）
static func tick(st: Dictionary, b: XBattler, frames: float) -> bool:
	st.count = float(st.get("count", 0.0)) + frames
	if st.count < wait():
		return false
	st.count = 0.0
	var g := group(b)
	if g.is_empty():
		st.index = 0
		st.cur = {}
	else:
		st.index = int(st.get("index", 0)) + 1
		if st.index >= g.size():
			st.index = 0
		st.cur = g[st.index]
	return true


## 画在名字窗画布上（name_width 是 18 号字的名字宽）
## 这一格要画的那一行（开关关着或没有图标为空）
static func shown(st: Dictionary) -> Dictionary:
	return st.get("cur", {}) if SHOW else {}


## 层数字样（开关关着照原版不画）
static func floor_text(row: Dictionary) -> String:
	return str(row.get("floor", "")) if FLOOR_TEXT else ""


static func paint(c: XMVCanvas, st: Dictionary, name_width: float, alpha := 1.0) -> void:
	var cur := shown(st)
	if cur.is_empty():
		return
	var p := icon_center(name_width)
	c.icon(int(cur.icon), p.x - 16, p.y - 16, alpha)
	if str(cur.turns) != "":
		c.text(str(cur.turns), p.x - 16 - 3, p.y - 16 - 8, 32, "right", XUI.text_color(int(cur.color)), 16, 36, alpha)
	if floor_text(cur) != "":
		c.text(floor_text(cur), p.x - 16 + 2, p.y - 16 + 6, 32, "left", Color("#ffffa0"), 12, 36, alpha)
