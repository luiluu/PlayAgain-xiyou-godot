class_name XWeakChallenge
extends RefCounted
## 【cc·weak1·未经审查】弱者挑战（正式 js/codex/runtime/installWeakChallengeRuntime.js，CodexWeakChallenge v2）一期：
## 参照 mv_oracle/weak_challenge_probe（generated/oracle/weak_challenge.json），专项 xiyou_weak_challenge。
## - 弱者 is_weak：有名字、不在公共事件 1345 的 actorIds（原生强者分类）、不是 167～174、备注没有 <GuyuActor>／<CodexSuperStrong>、
##   不在超强者名单（XItemMarks）与强者名单（XPowerBooks.STRONG_IDS，同 installBossDifficultyRuntime strongIds）。品质与此无关。
## - 标记：全局 ConfigManager.codexWeakFiveClearV2（XConfig「codexWeakFiveClearV2」，所有存档共用）与本局 $gameSystem._codexWeakClearV2
##   （XState.flags[FLAG]，只在为真时写）。新局把本局标记设成全局的；之后学不学只看本局标记（读档不看全局）。
## - sync：本局标记开且是弱者 → 学 10357「你才是真正的强者」，否则忘掉。时机：角色建出（Game_Actor.setup，学到时回满）、
##   新局结束、读档后、每场 BattleManager.setup 之前、最终战胜利后。learnSkill(10357) 在标记关或不是弱者时不学（事件也学不到）。
## - 10357 本身：备注 passivePBST0～7 各 +500%（八项基础属性 ×6，走通用被动）；持有者 sparam 6／7（物理／魔法承伤率）×0.5，
##   主动造成的伤害 finalMultiplier ×3（伤害钩子 weak-new-game；恢复类不经伤害钩子）。
## - 最终战：Map157 敌群 469、混沌（难度 9）开战时出战五人全是弱者才算；之后入队／离队／换位、改难度时重判（不满足就作废，
##   中途换回来也不恢复），强者行动也作废；胜利（result 0）且敌群全灭、仍是五名弱者 → 本局与全局标记开、全员同步、成就 142、写配置。
##   阵亡的出战队员照算，替补不算。
## 回退开关 ENABLED（O-186，见 00_设计/优化登记.md）：false 时整个弱者挑战不生效，回到移植前（成就 142 拿不到、10357 没人学）。
## 未移植（二期）：说明卡里 10357 的「品质：」行改成「品质：神话」（RJO.HE.getItemExtraDescParams2 包装）。
## 不移植：command117 对旧存档解释器里 Map48／49／54／85 公共事件 1431 的跳过（重制存档不存解释器现场）。

static var ENABLED := true
const SKILL := 10357
const ACHIEVEMENT := 142
const FINAL_MAP := 157
const FINAL_TROOP := 469
const CHAOS := 9
const FLAG := "codexWeakClearV2"
const CONFIG_KEY := "codexWeakFiveClearV2"

## 本场最终战判定（原版闭包里的 finalBattle）：null 或 {"eligible": bool}
static var final_battle = null
static var _granting := false
static var _bad_note := RegEx.create_from_string("(?i)<GuyuActor>|<CodexSuperStrong>")


static func is_weak(a) -> bool:
	if not a is XActor:
		return false
	var d: Dictionary = a.data()
	var id := int(a.actor_id)
	if d.is_empty() or str(d.get("name", "")) == "" or XState.difficulty_native_ids(1345, "actorIds").has(id):
		return false
	if (id >= 167 and id <= 174) or _bad_note.search(str(d.get("note", ""))) != null:
		return false
	return not XItemMarks.is_super_strong(id) and not XPowerBooks.STRONG_IDS.has(id)


static func enabled(s: XState) -> bool:
	return ENABLED and s != null and s.flags.get(FLAG) == true


static func active(a) -> bool:
	return enabled(XState.current) and is_weak(a) and a.skill_ids.has(SKILL)


## XActor.learn_skill 开头：false 就不学
static func can_learn(a, id: int) -> bool:
	if id != SKILL or not ENABLED or _granting:
		return true
	return enabled(XState.current) and is_weak(a)


static func sync(s: XState, a) -> bool:
	if not ENABLED or not a is XActor:
		return false
	var should := enabled(s) and is_weak(a)
	if should == a.skill_ids.has(SKILL):
		return false
	if should:
		_granting = true
		a.learn_skill(SKILL)
		_granting = false
	else:
		a.forget_skill(SKILL)
	a.refresh_passive()
	a.param_mark_dirty()
	a.param_refresh()
	# Game_Actor.refresh：忘掉后上限变小，HP／MP 夹回（参照 load.forget：MP 1200 → 200，HP 1 不动）
	a.hp = minf(a.hp, a.mhp)
	a.mp = minf(a.mp, a.mmp)
	return true


static func sync_actors(s: XState) -> void:
	if not ENABLED or s == null:
		return
	var ids := s.actors.keys()
	ids.sort()
	for id in ids:
		sync(s, s.actors[id])


## XState.actor 建出角色后（Game_Actor.setup 包装）：新学到就回满到新的上限
static func on_setup(s: XState, a) -> void:
	if sync(s, a) and enabled(s):
		a.param_refresh()
		a.recover_all()


## 新局开始（建队之前）：本局标记取全局的
static func new_game(s: XState) -> void:
	final_battle = null
	if not ENABLED:
		return
	if XConfig.flag(CONFIG_KEY):
		s.flags[FLAG] = true
	else:
		s.flags.erase(FLAG)


static func after_load(s: XState) -> void:
	final_battle = null
	sync_actors(s)


static func sparam(a, i: int, v: float) -> float:
	return v * 0.5 if (i == 6 or i == 7) and active(a) else v


static func damage_ops(a) -> Array:
	return [{"op": "mul", "field": "finalMultiplier", "value": 3.0}] if active(a) else []


static func _all_weak(s: XState) -> bool:
	var members: Array = s.battle_members()
	return members.size() == 5 and members.all(func(b): return is_weak(b))


## 入队、离队、重排、改难度之后（checkFinalBattle）
static func check(s: XState) -> void:
	if final_battle != null and s != null and (s.difficulty != CHAOS or not _all_weak(s)):
		final_battle.eligible = false


## BattleManager.setup 包装：先同步，再看是不是最终战
static func battle_setup(s: XState, troop: int) -> void:
	if not ENABLED:
		return
	sync_actors(s)
	final_battle = null
	if s.map_id == FINAL_MAP and troop == FINAL_TROOP and s.difficulty == CHAOS:
		final_battle = {"eligible": _all_weak(s)}


## BattleManager.startAction 包装
static func start_action(s: XState, u) -> void:
	if not ENABLED:
		return
	check(s)
	if final_battle != null and u is XActor and not is_weak(u):
		final_battle.eligible = false


## BattleManager.endBattle 包装（原 endBattle 之前）：返回这场给不给
static func before_end(logic, result: int) -> bool:
	if not ENABLED:
		return false
	var s: XState = logic.state
	check(s)
	var award: bool = result == 0 and final_battle != null and bool(final_battle.eligible) and s.map_id == FINAL_MAP \
		and int(logic.troop_id) == FINAL_TROOP and s.difficulty == CHAOS and _all_weak(s) and logic.is_won()
	final_battle = null
	return award


## 原 endBattle 之后
static func after_end(s: XState, award: bool) -> void:
	if not award:
		return
	s.flags[FLAG] = true
	XConfig.set_flag(CONFIG_KEY, true)
	sync_actors(s)
	XAchievement.reward(ACHIEVEMENT, s)
