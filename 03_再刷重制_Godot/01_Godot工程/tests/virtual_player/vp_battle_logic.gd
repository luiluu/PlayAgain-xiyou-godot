extends XBattleLogic
## 【cc·T328】虚拟玩家的出手层（Kyo 11-21「你让虚拟玩家聪明一点……懂怎么复活倒下的队友」）。
## 只给虚拟玩家无画面打的战斗用（vp_fastforward 的样本闸、vp_ff_probe、revive_compare）：在游戏自己的自动战斗
## （谷雨／璇／屠苏包装 → 挂机技能表 → 智能 AI）前面插一问「有队友倒下了，我该不该去复活」，答「不该」就原样交给游戏。
## 游戏本体、玩家能用的智能 AI（battle/smart_ai*.gd）一行不改；判合法只读调用 XSmartAI.legal。
##   const VPLogic := preload("res://tests/virtual_player/vp_battle_logic.gd")
##   var logic: XBattleLogic = VPLogic.new() if VPLogic.REVIVE else XBattleLogic.new()
##
## 规则（不让满场都去复活）：
##   1. 场上有倒下、能被复活的队友，且轮到的人自己会复活技能、现在能放 → 放复活技能（单体挑最该救的那个：会复活的人优先，其次输出最高的）。
##   2. 自己不会、或现在放不了：只有「这一回合还轮得到、会复活且放得了的队友」一个都没有时，才用复活道具；一回合最多用一次道具复活。
##   3. 同一回合同一个倒下的人只安排一次复活（OTB 当场结算，复活成功后下一个人看到的就是活人；没救起来也不重复排队）。
##   4. 没人倒下、或以上都不成立 → 原自动战斗；这时复活道具对原自动战斗藏起来（不让它绕过第 2 条）。
## 计数（报告用）：revive_casts 技能复活次数、revive_items 道具复活次数、falls[角色号] 倒下次数、raised[角色号] 被救起次数。

## 总开关：关掉＝虚拟玩家照旧用游戏原自动战斗（改前口径）
static var REVIVE := true

var revive_casts := 0
var revive_items := 0
var falls := {}
var raised := {}
var _item_turn := -1
var _planned := {}   # 本回合已安排复活的目标 {XBattler: true}
var _planned_turn := -1
var _was_dead := {}


## 复活效果：目标是倒下的队友（范围 9／10），且解除战斗不能（效果 22 状态 1）或是生命回复
static func revives(rec: Dictionary) -> bool:
	if rec.is_empty() or not XBattleEval.for_dead_friend(rec):
		return false
	return rec.get("effects", []).any(func(e): return int(e.code) == 22 and int(e.dataId) == 1) \
		or int(rec.get("damage", {}).get("type", 0)) == 3


## 这个角色会的复活技能（不看现在能不能放）
static func revive_skills(a: XActor) -> Array:
	return a.skills().filter(func(s): return revives(s))


## 全部复活道具（消耗品、战斗能用）
static var _items_cache: Array = []
static func revive_items_all() -> Array:
	if _items_cache.is_empty():
		for it in XDB.table("Items"):
			if it is Dictionary and not it.is_empty() and bool(it.get("consumable", false)) and int(it.get("occasion", 0)) in [0, 1] and revives(it):
				_items_cache.append(int(it.id))
		if _items_cache.is_empty():
			_items_cache = [-1]
	return _items_cache


func auto_battle_action(a: XActor) -> Array:
	_track()
	if not REVIVE:
		return super(a)
	var r := revive_action(a)
	if not r.is_empty():
		return r
	# 复活道具归这一层管：游戏的智能 AI 也会挑复活道具（估值 60000），不藏起来的话会复活的人还没轮到、别人就先把道具用了。
	# 只在这一次选招期间从背包拿开，选完原数放回（智能 AI 只读调用，不改它）
	var hidden := {}
	for id in revive_items_all():
		if state.items.has(id):
			hidden[id] = state.items[id]
			state.items.erase(id)
	var out: Array = super(a)
	for id in hidden:
		state.items[id] = hidden[id]
	return out


## 倒下／被救起计数：每次有人要出手前看一眼谁从活变倒、从倒变活
func _track() -> void:
	for b in actors:
		var dead: bool = b.is_dead()
		var was: bool = bool(_was_dead.get(b, false))
		if dead and not was:
			falls[int(b.actor_id)] = int(falls.get(int(b.actor_id), 0)) + 1
		elif was and not dead:
			raised[int(b.actor_id)] = int(raised.get(int(b.actor_id), 0)) + 1
		_was_dead[b] = dead


func revive_action(a: XActor) -> Array:
	if _planned_turn != turn:
		_planned_turn = turn
		_planned = {}
	var dead := actors.filter(func(t): return t.is_dead() and not _planned.has(t))
	if dead.is_empty():
		return []
	var ai := XSmartAI.new(self, a)
	var skill := _best(ai, revive_skills(a), false)
	if not skill.is_empty():
		var t = _target(skill, dead)
		revive_casts += 1
		return [skill, t]
	if _item_turn == turn or _skill_reviver_waiting(a):
		return []
	var items := []
	for id in revive_items_all():
		items.append(XDB.rec("Items", id))
	var item := _best(ai, items, true)
	if item.is_empty():
		return []
	_item_turn = turn
	revive_items += 1
	return [item, _target(item, dead)]


## 复活招现在能不能放：智能 AI 的合法判断（只读调用）；它一律不放的「带公共事件的非伤害技」（次级复活术、复苏之歌这类），
## 这里照天启篇放行公共事件技的同一道危险检查（XSmartAI._ce_dangerous：整条公共事件里没有危险指令）放行——玩家手动也会用
static func legal_revive(ai: XSmartAI, rec: Dictionary, item: bool) -> bool:
	if ai.legal(rec, item):
		return true
	if item or rec.is_empty() or str(rec.get("note", "")).to_lower().contains("<hide in battle>") or not ai.can_use(rec):
		return false
	for e in rec.get("effects", []):
		if int(e.code) == 44 and XSmartAI._ce_dangerous(int(e.dataId), {}):
			return false
	return true


## 能放的复活招里挑一个：全体复活优先（倒了两个以上时），否则第一个能放的
func _best(ai: XSmartAI, list: Array, item: bool) -> Dictionary:
	var ok := list.filter(func(s): return legal_revive(ai, s, item))
	if ok.is_empty():
		return {}
	var dead_n := actors.filter(func(t): return t.is_dead()).size()
	for s in ok:
		if XBattleEval.for_all(s) and dead_n >= 2:
			return s
	return ok[0]


## 单体：会复活的人优先（救起来能接着救），其次物攻、魔攻里高的那项最高的；全体返回 null
func _target(rec: Dictionary, dead: Array):
	if XBattleEval.for_all(rec):
		for t in dead:
			_planned[t] = true
		return null
	var best = null
	var best_score := -1.0
	for t in dead:
		var score := maxf(float(t.param(2)), float(t.param(4)))
		if t is XActor and not revive_skills(t).is_empty():
			score += 1e15
		if score > best_score:
			best_score = score
			best = t
	_planned[best] = true
	return best


## 这一回合还轮得到（在本回合剩下的顺序里）、会复活且现在能放的活着的队友
func _skill_reviver_waiting(me: XActor) -> bool:
	for b in current_order:
		if b == me or not (b is XActor) or b.is_dead():
			continue
		var ai := XSmartAI.new(self, b)
		if revive_skills(b).any(func(s): return legal_revive(ai, s, false)):
			return true
	return false
