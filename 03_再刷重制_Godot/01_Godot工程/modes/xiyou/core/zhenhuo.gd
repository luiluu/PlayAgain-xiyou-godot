class_name XZhenhuo
extends RefCounted
## 【cc·白龙·未经审查】至尊宝 36「真火印记」追击（新源 v0.62.12 js/codex/runtime/installZhenhuoMarkRuntime.js，
## W.__codexZhenhuoV05301，v0.53.01～v0.53.03；main.js 在 CodexRuntime 第 80 个之后装，包在已移植的 Game_Action.apply 包装外层）。
## 参照 mv_oracle/zhenhuo_probe.cjs → tests/fixtures/zhenhuo_oracle.json（tests/xiyou_zhenhuo）。
## - 被动 1089（只认已学 _skills，装备给的不算）的角色是「印记来源」。
## - 独特技能 1083 真火连击、1086 横扫千军（火属性）由来源施放时：本次行动对每个目标第一次 apply 之前先挂印记 108、
##   回合数至少 2（Z.mark：addState 后 _stateTurns 取较大值）。同一次行动多段不重复挂。
## - 追击：任何我方角色的火属性行动（action_elements 含 2）打中「本次行动开始前就带印记」的目标、造成正伤害、目标还活着时，
##   每个目标每次行动只追一次：印记来源（stateOrigin(108) 是来源角色时取它，否则出手者自己是来源就取出手者）
##   queueForceAction(来源, 1090, 敌群完整队位含已阵亡)。1090 自己不触发追击（它是物理属性，本来也不含火）。
## - 1090 由来源施放时 makeDamageValue 最外层 ×(0.6＋0.01×等级)，round、至少 1（Z.noScale 测试开关重制不做）。
## - 旧「追击」状态 109 对角色一律不挂（Game_Battler.addState 包装）：1086 行动序列的 Add State 109: user 被挡下，
##   旧自动施法（按我方队位打敌人）不再出手。敌人照常可挂（原版只挡 isActor）。原版这层没生效，见 FIX_OLD_CHASE。
## 挂点（battle_logic 一行钩子，交付单逐行列出）：execute 开头 start_action、apply 首尾 apply_begin／apply_end、
## _apply 伤害值 scale；battler.add_state 的 blocks_state。

const ACTOR := 36
const MARK := 108
const OLD_CHASE := 109
const PASSIVE := 1089
const CHASE := 1090
const FIRE := 2
const UNIQUE := [1083, 1086]

## 本次行动按目标各一格：{target, marked_before, chased, marked}（原版记在 Game_Action._zhenhuoInfo 上）
static var _slots: Array = []
## 原版 Z.runs／Z.last（只给测试看）
## 开关关着时本次行动已按原版排过旧自动施法的角色（battler.add_state 与资源上下文 add_state 两层都会问，只排一次）
static var _old_queued: Array = []
static var runs := 0
static var last := {}


static func is_owner(u) -> bool:
	return u is XActor and (u as XActor).skill_ids.has(PASSIVE)


static func scale_of(u) -> float:
	if XTianqiSkills.cards_on():
		return 0.5  # 天启篇技能重构：追击的横扫千军半伤（系数在卡里，不再随等级涨）
	return 0.6 + 0.01 * float(u.level if u != null else 0)


static func reset() -> void:
	_slots.clear()
	_old_queued.clear()
	runs = 0
	last = {}


## BattleManager.startAction：新的 Game_Action，格子清空
static func start_action() -> void:
	_slots.clear()
	_old_queued.clear()


## O-234（原版 bug，默认修好）：新源想在 Game_Battler.addState 上挡掉角色的 109，但 Game_Actor.addState 早被
## StrongActorClassification／Toji／Qiyu 包过（各自拿的是包装前的 Game_Battler.addState），角色走不到这层，屏蔽没生效：
## 1086 的 Add State 109: user 照挂，109 的 <Custom Apply Effect> 照旧 queueForceAction(至尊宝, 1090, 至尊宝的我方队位)，
## 多敌人时打错目标、和新的追击叠成两次（参照 mark.*.p1089、chase.a36.s1086）。true＝照作者本意挡下；false＝照原版挂上并按队位排一次 1090。
static var FIX_OLD_CHASE := true


## Game_Battler.addState 包装：角色不挂 109。开关关着时不挡，照原版在新挂上时跑 109 的 Custom Apply Effect
## （YEP 对已有的状态不重跑）：queueForceAction(user, 1090, origin.index())，origin＝挂状态时的行动者＝自己
static func blocks_state(b, id: int) -> bool:
	if id != OLD_CHASE or not (b is XActor):
		return false
	if FIX_OLD_CHASE:
		return true
	if not b.is_state_affected(OLD_CHASE) and not _old_queued.has(b):
		_old_queued.append(b)
		XStateEffects.queue_force_quiet(b, CHASE, XStateEffects.battle_units.get("actors", []).find(b))
	return false


static func _fire(skill: Dictionary, u) -> bool:
	return not skill.is_empty() and u != null and XDamage.action_elements(skill, u).has(FIRE)


## Game_Action.apply 包装前半：建本目标的格子（记行动开始前有没有印记）；独特技能先挂印记。返回格子（没有为 null）
static func apply_begin(logic, u, skill: Dictionary, t):
	if t == null or skill.is_empty():
		return null
	var slot = null
	for s in _slots:
		if s.target == t:
			slot = s
			break
	if slot == null:
		slot = {"target": t, "marked_before": t.is_state_affected(MARK), "chased": false, "marked": false}
		_slots.append(slot)
	var fire := _fire(skill, u)
	if fire and UNIQUE.has(int(skill.get("id", 0))) and not slot.marked and is_owner(u):
		if mark(logic, t):
			slot.marked = true
	slot.fire = fire
	return slot


## Z.mark：addState(108)，回合数至少 2
static func mark(logic, t) -> bool:
	if t == null or not t.is_alive():
		return false
	logic.sequence_add_state(t, MARK)
	if t.state_turns.has(MARK):
		t.state_turns[MARK] = maxi(int(t.state_turns[MARK]), 2)
	return t.is_state_affected(MARK)


## Game_Action.apply 包装后半：火伤打中行动前已带印记的活目标 → 来源追加 1090
static func apply_end(logic, u, skill: Dictionary, t, slot, r: Dictionary) -> void:
	if slot == null or not bool(slot.get("fire", false)) or t == null or not t.is_alive():
		return
	if not (u is XActor):
		return
	if int(skill.get("id", 0)) == CHASE:
		return
	var damage := float(r.get("result", {}).get("hpDamage", r.get("hp", 0.0)))
	if damage <= 0.0 or not slot.marked_before or slot.chased:
		return
	slot.chased = true
	var owner = null
	var origin = t.state_origins.get(MARK)
	origin = origin.get_ref() if origin is WeakRef else origin
	if is_owner(origin):
		owner = origin
	if owner == null and is_owner(u):
		owner = u
	if owner == null:
		return
	var index: int = logic.enemies.find(t)
	if index < 0:
		return
	# BattleManager.queueForceAction：同 battle_logic._after_eval_force（行动资源上下文在时走 queue_force，否则 quiet）
	if logic._action_resources != null:
		XStateEffects.queue_force(owner, CHASE, index, logic._action_resources)
	else:
		XStateEffects.queue_force_quiet(owner, CHASE, index)
	runs += 1
	last = {"owner": owner.actor_id, "target": index, "scale": scale_of(owner)}


## makeDamageValue 包装（最外层）：来源放 1090 时 ×(0.6＋1%×等级)，round、至少 1
static func scale(u, skill: Dictionary, value: float) -> float:
	if int(skill.get("id", 0)) == CHASE and is_owner(u):
		return maxf(1.0, roundf(value * scale_of(u)))
	return value
