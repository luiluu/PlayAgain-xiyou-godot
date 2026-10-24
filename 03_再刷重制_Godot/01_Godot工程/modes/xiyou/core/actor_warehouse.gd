class_name XActorWarehouse
extends RefCounted
## 角色仓库（Star_ActorWarehouse 的 Star_Scene_ActorWarehouse；方桌大厅仓库管理员 Map4 EV8「角色仓库」＝
## SceneManager.push(Star_Scene_ActorWarehouse)）。界面在 XActorWarehouseScene。
## 存档：XState.saved_actors（正式版 $gameParty._saveactors，存档键 saveactors；旧档没有为空仓库）。角色本身（等级、技能、装备）
## 一直在 XState.actors 里，存入只是把编号从队伍挪到仓库。
## 照冻结 v0.28 原版（tests/fixtures/actor_warehouse_oracle.json）：
## - 列表：存入＝队伍全体（$gameParty._actors 顺序）；取出＝仓库（先滤掉已在队伍里的，原版 createActorOrder 每次刷新都滤）。
## - 存入：队伍只剩 1 人时不存（原版 alert「队伍最少保留一位角色」）；否则编号进仓库末尾、从队伍去掉。
##   存的是出战成员时原版从 _battleMembers 里 splice 掉（数组变短），下一次 battleMembers() 发现长度不等于上限就按队伍前 5 人
##   重建出战栏（initializeBattleMembers）——所以存掉出战成员后候补的人会补上来（参照 aw_2：存 8 后出战栏 1/9/10/11/12）。
## - 取出：编号追加到队伍末尾（不重排、不进出战栏），从仓库去掉。
## - 存取后出战栏前 4 格全空时把队伍第 1 人放进第 1 格（原版两处都有这条判断）。
## - 停用角色（installImportedBalanceRuntime：XImportedBalance.DISABLED_ACTORS）在列表里名字半透明、不可确定（蜂鸣）。
## - 退出时原版由 Star_SkilsShare／Star_JiBanSiklls／Star_LeadActor 刷新共享技能、羁绊与领袖技能；这三套重制还没有移植
##   （整队页同样没有），所以这里不刷新。
## O-091：光标停在空行（存／取掉最后一行后原版光标不动）时确定，原版把 undefined 存进仓库或队伍（之后读写都会出错）；
## 重制返回 "empty"，界面蜂鸣不动（deposit／withdraw 开头的空行判断）。

const LAST_ACTOR_TEXT := "队伍最少保留一位角色"


## createActorOrder 的 LoadAct：仓库里滤掉已在队伍里的（原版直接改写 _saveactors）
static func stored(s: XState) -> Array[int]:
	var keep: Array[int] = []
	for id in s.saved_actors:
		if not s.party.has(id):
			keep.append(id)
	s.saved_actors = keep
	return keep.duplicate()


## 列表数据：deposit＝true 时是队伍，否则是仓库
static func list(s: XState, deposit: bool) -> Array[int]:
	return s.party.duplicate() if deposit else stored(s)


## Star_Window_PartyList.isCurrentItemEnabled／actorIsEnabled（Codex 包装）：停用角色不可选；空行原版算可选
static func enabled(id: int) -> bool:
	return not XImportedBalance.is_disabled_actor(id)


## onActorOk 的 SaveAct：返回 "ok"／"last"（只剩 1 人）／"empty"（空行）／"disabled"
static func deposit(s: XState, index: int) -> String:
	var data := list(s, true)
	var id := data[index] if index >= 0 and index < data.size() else 0
	if id == 0:
		return "empty"
	if not enabled(id):
		return "disabled"
	if s.party.size() <= 1:
		return "last"
	s._ensure_slots()
	s.saved_actors.append(id)
	var shrunk := s.battle_slots.has(id)
	s.battle_slots.erase(id)
	s.party.remove_at(index)
	_first_slot_fix(s)
	# YEP toInitializeBattleMembers：出战栏长度不等于上限 → 按队伍前 5 人重建
	if shrunk:
		s.init_battle_slots()
	return "ok"


## onActorOk 的 LoadAct：返回 "ok"／"empty"／"disabled"
static func withdraw(s: XState, index: int) -> String:
	var data := list(s, false)
	var id := data[index] if index >= 0 and index < data.size() else 0
	if id == 0:
		return "empty"
	if not enabled(id):
		return "disabled"
	s.actor(id)
	s.party.append(id)
	s.saved_actors.remove_at(index)
	s._ensure_slots()
	_first_slot_fix(s)
	return "ok"


## 出战栏前 4 格全是 0 时，第 1 格放队伍第 1 人
static func _first_slot_fix(s: XState) -> void:
	if s.battle_slots.size() < 4 or s.party.is_empty():
		return
	for i in 4:
		if int(s.battle_slots[i]) != 0:
			return
	s.battle_slots[0] = s.party[0]


static func from_save(v) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for id in v:
			if id != null and int(id) > 0 and not out.has(int(id)):
				out.append(int(id))
	return out
