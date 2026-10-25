class_name XCostumes
extends RefCounted
## 角色换装（installCostumePreferencesRuntime 的 CodexCostumes，冻结 v0.28；参照 mv_oracle/costume_probe.cjs）：
## 每个角色一个「战斗中显示换装卡外观」开关，和衣橱（XChangeClothes，玩家行走图）不是一套。卡片的技能、状态与属性加成照旧。
## - 换装卡：技能 6801～6858 备注 <StartPushStateN:…>，状态 N 备注里有 var battlerName = '…' 的才登记（58 张），名字去掉「变身——」。
## - 开关：默认启用；关掉的角色记在 XState.costume_off（原版是 Game_Actor._codexCostumeEnabled，随局内存档；重制不迁移旧档，存成角色 ID 列表）。
## - 外观：battler_name——战斗中角色身上有卡状态时，启用＝卡图，关闭＝自身形态（数据库 battlerName）。
##   重制战斗还没有卡状态的换图（状态 Custom Apply Effect 里的 setBattlerImage），战斗精灵接这里见交付单 claude_bajie-superstrong 提案。
## - 入口：设置「角色换装」，进游戏后（不在战斗）可开，状态「打开」，否则灰、「进入游戏」、确定蜂鸣。主菜单里的同名指令被
##   installDisplayPreferencesRuntime 去掉了，只留设置这一处。

const FIRST_SKILL := 6801
const LAST_SKILL := 6858
static var _registry := {}     # 状态 ID → {skill, state, image, name}
static var _ready_flag := false


static func registry() -> Dictionary:
	if not _ready_flag:
		var re := RegEx.create_from_string("(?i)<StartPushState(\\d+)\\s*:")
		var img := RegEx.create_from_string("var battlerName\\s*=\\s*['\"]([^'\"]+)['\"]")
		for id in range(FIRST_SKILL, LAST_SKILL + 1):
			var skill := XDB.rec("Skills", id)
			var m := re.search(str(skill.get("note", ""))) if not skill.is_empty() else null
			if m == null:
				continue
			var state := XDB.rec("States", int(m.get_string(1)))
			var im := img.search(str(state.get("note", ""))) if not state.is_empty() else null
			if im != null:
				_registry[int(state.id)] = {"skill": id, "state": int(state.id), "image": im.get_string(1),
					"name": str(skill.get("name", "")).trim_prefix("变身——")}
		_ready_flag = true
	return _registry


static func enabled(s: XState, actor_id: int) -> bool:
	return s != null and not s.costume_off.has(actor_id)


## C.setEnabled
static func set_enabled(s: XState, actor_id: int, on: bool) -> void:
	if on:
		s.costume_off.erase(actor_id)
	elif not s.costume_off.has(actor_id):
		s.costume_off.append(actor_id)


## C.cards：学会的换装卡（按登记顺序＝技能编号）
static func cards(a: XActor) -> Array:
	var out := []
	if a == null:
		return out
	for card in registry().values():
		if a.skill_ids.has(int(card.skill)):
			out.append(card)
	return out


## C.current：角色状态里第一张卡
static func current(a: XActor):
	if a == null:
		return null
	for id in a.state_ids:
		if registry().has(int(id)):
			return registry()[int(id)]
	return null


## Game_Actor.battlerName 包装（战斗中）：有卡状态且启用＝卡图，否则自身形态
static func battler_name(s: XState, a: XActor, in_battle := true) -> String:
	var own := str(a.data().get("battlerName", ""))
	var card = current(a)
	if card == null or not in_battle:
		return own
	return str(card.image) if enabled(s, a.actor_id) else own


## C.ownedActors：队伍＋角色仓库，去重、按出现顺序
static func owned_actors(s: XState) -> Array:
	var out := []
	for id in Array(s.party) + Array(s.saved_actors):
		if not out.has(int(id)) and not XDB.rec("Actors", int(id)).is_empty():
			out.append(int(id))
	return out.map(func(id): return s.actor(id))


## C.canOpen：已进游戏且不在战斗（重制的设置页只从地图菜单打开）
static func can_open(s: XState, in_battle := false) -> bool:
	return s != null and not in_battle


static func from_save(v) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for id in v:
			out.append(int(id))
	return out
