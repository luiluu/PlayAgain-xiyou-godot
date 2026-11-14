class_name XStarburstBooks
extends RefCounted
## 【cc·白龙·未经审查】星爆气流斩三本被动书分开获得（新源 v0.62.10 js/codex/runtime/installStarburstBooksRuntime.js，
## window.KyoStarburstBooks；main.js 装在真气、云裳之后，endBattle 包装在它们外层）。
## 参照 mv_oracle/starburst_books_probe.cjs → tests/fixtures/starburst_books_oracle.json（tests/xiyou_starburst_books）。
## - 胜利（endBattle(0)，在原 endBattle 之前＝真气胜利结算之前，重制挂在 grant 里 XZhenqi.on_victory 前）：
##   ① 真气本场不是试炼、不是缩放战、守层者层数是 8／18：每个存档一次送 1121 封弊者／1161 流光闪（「第N层守层者：获得…！」）。
##   ② 在 152 号地图、云裳 isImmortalClear（不朽存在的未知战斗）时掷一次随机数，< 概率送 1141 阐释者（「不朽存在：获得…！」）；
##      概率 1/66×(1＋max(0, 路线系数−5)/8)，最高 1/33（天灾及以下 1/66、灭世 1/66×1.375、洪荒 1/33）。不吃掉率加成。
## - Scene_Map.start：当前路线已通过的层数（真气 progressFloor）≥8／18 时补发没送过的那本（「已通过第N层守层者：获得…！」）。
## - 送过的层记在 $gameSystem._kyoStarburstBooks（{8:1, 18:1}），重制存 XState.flags["kyoStarburstBooks"]（随存档）。

const GIFTS := {8: 1121, 18: 1161}
const IMMORTAL_MAP := 152
const IMMORTAL_BOOK := 1141
const BASE_RATE := 1.0 / 66.0
const MAX_RATE := 1.0 / 33.0
const FLAG := "kyoStarburstBooks"
## 只给测试用：-1 照常问云裳 immortal_clear；0／1 当作不是／是不朽存在（参照探针把 Y.isImmortalClear 换成恒真）
static var IMMORTAL_CLEAR_TEST := -1


static func _given(s: XState) -> Dictionary:
	var d = s.flags.get(FLAG)
	if not (d is Dictionary):
		d = {}
		s.flags[FLAG] = d
	return d


static func _give(s: XState, id: int, why: String) -> void:
	var item := XDB.rec("Items", id)
	if item.is_empty():
		return
	s.gain_item(id, 1)
	XToast.show_text("%s：获得%s！" % [why, str(item.get("name", ""))])


static func _gift(s: XState, floor_no: int, why: String) -> void:
	var given := _given(s)
	if not GIFTS.has(floor_no) or given.has(str(floor_no)):
		return
	given[str(floor_no)] = 1
	_give(s, int(GIFTS[floor_no]), why)


## B.immortalRate：天灾（系数 5）及以下 1/66，往上线性加，洪荒（13）到 1/33 封顶
static func immortal_rate(s: XState) -> float:
	var tq := XTianqiTrim.route(s)  # 天启篇：前四档 1/66、证道 1/33（O-412）
	if float(tq.get("starburst_denom", 0)) > 0.0:
		return 1.0 / float(tq.starburst_denom)
	var coef := float(XZhenqi.route(s).get("coef", 1)) if s != null else 1.0
	return minf(MAX_RATE, BASE_RATE * (1.0 + maxf(0.0, coef - 5.0) / 8.0))


## onVictory（endBattle(0) 包装、原 endBattle 之前）：logic 是本场 XBattleLogic，随机数取规则流
static func on_victory(logic) -> void:
	var s: XState = logic.state
	if s == null:
		return
	var b: Dictionary = XZhenqi.battle
	# 真气 battle 里 trial、scaled 没有时是空字典（原版 null）
	if not b.is_empty() and (b.get("trial", {}) as Dictionary).is_empty() and (b.get("scaled", {}) as Dictionary).is_empty() and GIFTS.has(int(b.get("guardianFloor", 0))):
		var f := int(b.guardianFloor)
		_gift(s, f, "第%d层守层者" % f)
	var immortal: bool = XYunshangOrders.immortal_clear(s, int(logic.troop_id)) if IMMORTAL_CLEAR_TEST < 0 else IMMORTAL_CLEAR_TEST == 1
	if s.map_id == IMMORTAL_MAP and immortal \
			and logic._rule().next_float("starburst.immortal") < immortal_rate(s):
		_give(s, IMMORTAL_BOOK, "不朽存在")


## Scene_Map.start 包装：老存档补发（当前路线已通过的层数够了就送，每个存档一次）
static func map_start(s: XState) -> void:
	if s == null:
		return
	var passed := XZhenqi.progress_floor(s)
	for f in GIFTS:
		if passed >= int(f):
			_gift(s, int(f), "已通过第%d层守层者" % int(f))
