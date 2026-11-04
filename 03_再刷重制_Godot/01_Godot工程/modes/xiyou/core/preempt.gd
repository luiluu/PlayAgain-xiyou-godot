class_name XPreempt
extends RefCounted
## 先制／偷袭（BattleManager.onEncounter、Game_Party.ratePreemptive／rateSurprise，参照 tests/fixtures/preempt_oracle.json）。
## 只有随机遇敌（Game_Player.executeEncounter）才掷；事件触发的战斗（指令 301）不走 onEncounter，两个标志都是 false。
## 先制率：我方（全名册 members()，未进战斗时不是出战栏）平均敏捷 ≥ 敌方平均敏捷 → 0.05，否则 0.03；队伍能力 3「先发制人率上升」×4；
##   再加出战成员每个 passivePREE 的 v×0.01（逐个相加，倒下的出战成员也算），夹到 0～1。
## 偷袭率：我方 ≥ 敌方 → 0.03，否则 0.05；队伍能力 2「防偷袭」→ 0；再对出战成员每个 passiveASUP 做 rate −= v×0.01×rate，夹到 0～1。
## 掷骰：两次随机数总是各取一次（先制 r1 < 先制率；偷袭 r2 < 偷袭率 且没先制）。
## 先制：第一回合只排我方（敌人不行动），逃跑必成功；偷袭：第一回合只排敌人（我方不行动）。第一个回合结束（endTurn）标志清掉，
## 「下个回合」顺序仍是全员。开场文字 TextManager.preemptive／surprise（YEP Show Pre-Emptive／Surprise Text 都开；Show Emerge Text 关，不显示「出现了」）。


## Game_Unit.agility：成员平均敏捷，没有成员是 1。
static func unit_agility(members: Array) -> float:
	if members.is_empty():
		return 1.0
	var sum := 0.0
	for b in members:
		sum += float(b.agi)
	return sum / members.size()


## 先制率／偷袭率。party_agi／troop_agi 传负数＝按 state／enemies 现算（测试里拿参照的敏捷值压住两边能力值的差异）。
static func rates(state: XState, enemies: Array, party_agi := -1.0, troop_agi := -1.0) -> Dictionary:
	var pre_vals := []
	var asup_vals := []
	for a in state.battle_members():
		for v in a.passive_values("passivePREE"):
			pre_vals.append(XActor._num(v))
		for v in a.passive_values("passiveASUP"):
			asup_vals.append(XActor._num(v))
	return compute(party_agi if party_agi >= 0.0 else unit_agility(state.members()), troop_agi if troop_agi >= 0.0 else unit_agility(enemies),
		state.party_ability(3), state.party_ability(2), pre_vals, asup_vals)


## 纯公式：raise＝队伍能力 3（先制率 ×4），cancel＝队伍能力 2（偷袭率 0）；pre_vals／asup_vals 是出战成员逐个被动的数值（按顺序）。
static func compute(party_agi: float, troop_agi: float, raise: bool, cancel: bool, pre_vals: Array, asup_vals: Array) -> Dictionary:
	var party_wins := party_agi >= troop_agi
	var pre := 0.05 if party_wins else 0.03
	if raise:
		pre *= 4.0
	var sur := 0.03 if party_wins else 0.05
	if cancel:
		sur = 0.0
	for v in pre_vals:
		pre += float(v) * 0.01
	for v in asup_vals:
		sur -= float(v) * 0.01 * sur
	return {"pre": clampf(pre, 0.0, 1.0), "sur": clampf(sur, 0.0, 1.0)}


## 两次随机数各取一次：先制 r1 < 先制率；偷袭 r2 < 偷袭率 且没先制。返回 [先制, 偷袭]。
static func roll(r1: float, r2: float, rate: Dictionary) -> Array:
	var pre: bool = r1 < float(rate.pre)
	return [pre, r2 < float(rate.sur) and not pre]


## Game_Party.name：出战 1 人时为其名字，否则 partyName「%1的队伍」。
static func party_name(actors: Array) -> String:
	if actors.is_empty():
		return ""
	var leader: String = actors[0].display_name()
	return leader if actors.size() == 1 else str(XDB.system().terms.messages.get("partyName", "%1的队伍")).replace("%1", leader)


## 开场文字（TextManager.preemptive／surprise）：没有先制／偷袭返回空。
static func start_text(logic) -> String:
	var key := "preemptive" if logic.preemptive else ("surprise" if logic.surprise else "")
	return "" if key == "" else str(XDB.system().terms.messages[key]).replace("%1", party_name(logic.actors))
