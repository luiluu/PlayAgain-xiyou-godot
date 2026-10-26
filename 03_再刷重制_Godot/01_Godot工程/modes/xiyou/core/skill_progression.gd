class_name XSkillProgression
extends RefCounted
## 渡鸦 167／米拉 168 的技能解锁同步（正式 js/codex/runtime/installNativeSkillProgressionRuntime.js，W.CodexSkillProgression）。
## - unlocked(a,id)：只管本人的专属技能（渡鸦 10122～10139 与 10170、米拉 10140～10167）；技能备注 CodexRetired 为否、
##   CodexUnlockLevel ≤ 等级、CodexUnlockRank ≤ 进阶次数，有 CodexUnlockMaxRank 时进阶次数不超过它。
## - sync(a)：上述范围内允许就学、不允许就忘。原版挂在 setup、levelUp、changeLevel、入队、读档、进阶确认、开战；
##   重制挂在 XActorModules 的 setup／level_up／level_down／level_changed（入队与进阶走 setup／招募的同步）。
## 未移植：skills() 与 meetsSkillConditions 按 unlocked 过滤（同步后已学列表本就一致，只差同步之外直接 learn_skill 的情形）、开战再同步。

const RANGES := {167: [10122, 10139, [10170]], 168: [10140, 10167, []]}


static func managed(a) -> bool:
	return a is XActor and RANGES.has(int(a.actor_id))


static func _own(a, id: int) -> bool:
	var r: Array = RANGES[int(a.actor_id)]
	return (id >= r[0] and id <= r[1]) or r[2].has(id)


static func rank(a) -> int:
	return maxi(0, XAdvance.rank(XState.current, int(a.actor_id)))


static func unlocked(a, id: int) -> bool:
	if not managed(a) or not _own(a, id):
		return true
	var meta: Dictionary = XDB.rec("Skills", id).get("meta", {})
	if meta.has("CodexRetired"):
		return false
	return int(a.level) >= int(str(meta.get("CodexUnlockLevel", 1)).to_float()) \
		and rank(a) >= int(str(meta.get("CodexUnlockRank", 0)).to_float()) \
		and (not meta.has("CodexUnlockMaxRank") or rank(a) <= int(str(meta.CodexUnlockMaxRank).to_float()))


static func sync(a) -> void:
	if not managed(a):
		return
	var r: Array = RANGES[int(a.actor_id)]
	var ids: Array = range(r[0], r[1] + 1) + r[2]
	var changed := false
	for id in ids:
		if unlocked(a, id):
			if not a.skill_ids.has(id) and not XDB.rec("Skills", id).is_empty():
				a.learn_skill(id)
				changed = a.skill_ids.has(id) or changed
		elif a.skill_ids.has(id):
			a.forget_skill(id)
			changed = true
	if changed:
		a.refresh_passive()
