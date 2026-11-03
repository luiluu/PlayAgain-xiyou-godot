class_name XNanoha
extends RefCounted
## 【cc·悟空·未经审查】108 奈叶共享击杀（js/codex/runtime/installNanohaSharedKillRuntime.js）：
## - Game_Action.apply 包装：行动者是出战队伍里别的角色、奈叶学会并肩适应 10168 与适应 5683 且活着、也在出战队伍里时，
##   打中（isHit）一个 apply 前还活着的敌人，就记进本次行动的目标表（同一目标只记一次）；
## - BattleManager.endAction 包装（原 endAction 之后）：目标表里每个已死的敌人给奈叶 addParam(0,10)、addParam(1,30)（永久，存档）。
## 奈叶自己的击杀不走这里（actorId===108 排除），由状态 1768 Conclude 给。
## 目标表挂在本次行动的 Game_Action 上：追击、反击等另建的行动不算；重制只在 act／强制行动的 execute 期间开表（begin／end_execute）。
## 读档补学 10168（ensureLearned）是给旧存档的，重制不迁移 MV 旧存档、新局按职业 1 级习得，不移植。
## 参照：mv_oracle/nanoha_kill_probe.cjs（tests/fixtures/nanoha_kill_oracle.json），专项 tests/xiyou_nanoha.gd。

const ACTOR := 108
const SHARED := 10168
const ADAPT := 5683


## eligibleNanoha(subject)：在战斗中、行动者是出战的别的角色时返回奈叶，否则 null
static func eligible(subject) -> XActor:
	if not subject is XActor or subject.actor_id == ACTOR or XState.current == null:
		return null
	var n: XActor = XState.current.actors.get(ACTOR)
	if n == null or not n.skill_ids.has(SHARED) or not n.skill_ids.has(ADAPT) or not n.is_alive():
		return null
	var members: Array = XState.current.battle_members()
	return n if members.has(n) and members.has(subject) else null


## 本次行动开表（startAction 之后的 execute 之前）
static func begin(logic) -> void:
	logic.nanoha_frame = {"open": true, "targets": []}


## execute 结束：之后的追击、反击、追加段另建 Game_Action，不再记
static func end_execute(logic) -> void:
	logic.nanoha_frame.open = false


## apply 包装：live 是 apply 前目标是不是活着的敌人
static func applied(logic, u, t, live: bool, r: Dictionary) -> void:
	var f: Dictionary = logic.nanoha_frame
	if not live or not bool(f.get("open", false)) or eligible(u) == null:
		return
	if bool(r.get("missed", false)) or bool(r.get("evaded", false)):
		return
	if not f.targets.has(t):
		f.targets.append(t)


## endAction 包装（原 endAction 之后）：subject 是 BattleManager._subject
static func finish(logic, subject) -> void:
	var f: Dictionary = logic.nanoha_frame
	logic.nanoha_frame = {}
	if f.is_empty() or f.targets.is_empty():
		return
	var n := eligible(subject)
	if n == null:
		return
	for e in f.targets:
		if e != null and e.is_dead():
			n.add_param(0, 10.0)
			n.add_param(1, 30.0)


## ---- 二期①：大招 5703～5709 的自定义 MP 消耗与伤害后多段（参照 mv_oracle/nanoha3_probe.cjs，tests/fixtures/nanoha3_oracle.json）----
## 转换器把 <Custom MP Cost> 翻成 mpCostCurrentRate／costHitPer、<Post-Damage Eval> 翻成 postDamageCostRepeat（只认完整形状）。
## 费用本身在 battle_logic._skill_cost；这里管 _costmp（原版挂在行动者上，付费那次 skillMpCost 按付前 MP 写）与补段。
## Bailong_NaiyeACS_FastSettlement：总段数超 512 时只留 96 段（桌面）逐段 gainHp＋弹字，其余同值尾段合成一次扣血（不走 gainHp 包装），伤害记录按 ⌊每段⌋×段数补。
const ACS_EXACT := 512
const ACS_VISIBLE := 96


## paySkillCost 里那次 skillMpCost：_costmp＝⌊付前 MP×比例/每段⌋
static func note_cost(u, skill: Dictionary) -> void:
	if skill.has("mpCostCurrentRate") and u is Object:
		u.set_meta("costmp", floori(u.mp * float(skill.mpCostCurrentRate) / float(skill.get("costHitPer", 2000))))


## applyPostDamageEval：_costmp>0 时再 target.gainHp(-value)＋弹字 _costmp-1 次；value 是进 executeHpDamage 之前的值（Boss 输出等包装在里层，不乘）
static func post_damage(logic, u, t: XBattler, skill: Dictionary, value: float, r: Dictionary) -> void:
	if not bool(skill.get("postDamageCostRepeat", false)):
		return
	var hits := int(u.get_meta("costmp", 0))
	if hits <= 1:
		return
	var extra := hits - 1
	var fast := hits > ACS_EXACT and t is XEnemy and value > 0.0 and value == floorf(value)
	var shown := mini(extra, ACS_VISIBLE - 1) if fast else extra
	var popups: Array = r.get("extra", [])
	for i in shown:
		var amount := t.absorb_shield(value)  # ShieldSystem gainHp 包装：护盾先吸收、击穿后减半
		logic._action_resources.gain(t, "hp", -amount)
		popups.append(amount)
		r.record_hp = float(r.get("record_hp", 0.0)) + floorf(maxf(0.0, amount))
	if fast and extra > shown:
		var tail := extra - shown
		logic._action_resources.gain(t, "hp", -value * tail)
		r.record_hp = float(r.get("record_hp", 0.0)) + floorf(value) * tail
	r.extra = popups
