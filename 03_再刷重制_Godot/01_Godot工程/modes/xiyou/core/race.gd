class_name XRace
extends RefCounted
## 种族祝福（installNativeRaceRuntime）的菜单侧数据与操作；选单页在 ui/race_menu.gd，参照 race_menu_probe.cjs（测试 tests/xiyou_race_menu）。
## 存档 XState.race：default 开局默认（$gameSystem._codexRaceDefault，-1＝未选）、guideChosen（_codexRaceGuideChosen）、
## actors 每名角色 {race, rank, free, blood, legacy}（Game_Actor._codexRace；race -1＝未选，rank 1～7，free 下次换族免费，
## blood 魔族血契开关，legacy 旧技能推出的 [{race, rank}]）。种族技能 CodexRaces.skills[race][rank-1] 写在角色技能里（sync）。
## 原版角色建出、入队、学会种族技能时就补上数据（migrateActor）；这里在 XState.actor 建出角色时补（on_actor_created），读到旧档里没有的也补。
## 战斗与能力值效果（七族增伤、猎物、血契扣血、回响、反攻、能力值倍率、鬼族耗蓝）在 race_battle.gd（XRaceBattle）。

const SWITCHES := [285, 282, 283, 284, 286, 287, 281]   # 神妖人魔鬼灵蛮 → 开关
const RANKS := ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ"]


static func config() -> Dictionary:
	var c = XDB.table("CodexRaces")
	return c if c is Dictionary else {}


static func state(s: XState) -> Dictionary:
	if not s.race.has("actors"):
		s.race["actors"] = {}
	if not s.race.has("default"):
		s.race["default"] = -1
	return s.race


static func default_race(s: XState) -> int:
	return int(state(s).default)


static func race_name(r: int) -> String:
	return str(config().names[r])


## skillInfo：种族技能 → {race, rank}；不是种族技能返回空
static func skill_info(id: int) -> Dictionary:
	var skills: Array = config().get("skills", [])
	for r in skills.size():
		for n in skills[r].size():
			if int(skills[r][n]) == id:
				return {"race": r, "rank": n + 1}
	return {}


static func race_skill(r: int, rank: int) -> int:
	return int(config().skills[r][rank - 1])


## data：角色的种族数据（没有就按 migrateActor 补上）
static func data(s: XState, a: XActor) -> Dictionary:
	var all: Dictionary = state(s).actors
	var key := str(a.actor_id)
	if not all.has(key):
		_migrate_actor(s, a)
	return all[key]


## Game_Actor.setup 包装（migrateActor）：角色一建出就补种族数据（种族数据表在才做）
static func on_actor_created(s: XState, a: XActor) -> void:
	if not config().is_empty() and not state(s).actors.has(str(a.actor_id)):
		_migrate_actor(s, a)


static func rate(s: XState, a: XActor) -> float:
	var d := data(s, a)
	return float(config().rates[int(d.rank) - 1]) if int(d.race) >= 0 else 0.0


## migrateActor：按已学会的种族技能推出种族（只有一族就是它，多族记 -1 待选），阶位取最高；都没有就用开局默认
static func _migrate_actor(s: XState, a: XActor) -> void:
	var old := []
	for id in a.skill_ids:
		var info := skill_info(id)
		if not info.is_empty():
			old.append(info)
	var rank := 1
	var types := []
	for x in old:
		rank = maxi(rank, int(x.rank))
		if not types.has(int(x.race)):
			types.append(int(x.race))
	var r: int = types[0] if types.size() == 1 else (-1 if types.size() > 1 else default_race(s))
	state(s).actors[str(a.actor_id)] = {"race": r, "rank": rank, "free": true, "blood": false, "legacy": old}
	sync(s, a)


## sync：去掉角色身上所有种族技能，再按当前种族与阶位加一个
static func sync(s: XState, a: XActor) -> void:
	var d: Dictionary = state(s).actors[str(a.actor_id)]
	var kept: Array[int] = []
	for id in a.skill_ids:
		if skill_info(id).is_empty():
			kept.append(id)
	if int(d.race) >= 0:
		kept.append(race_skill(int(d.race), int(d.rank)))
	kept.sort()
	a.skill_ids = kept
	a.refresh_passive()


## Game_Actor.learnSkill 包装：学会种族技能不走原 learnSkill——没数据就按该技能建（换族免费），同族阶位取较大，
## 别族不变；再 sync（角色身上只留当前种族该阶的一个）。返回 true＝已接管。原版入口：兑换大厅「修复种族技能」等事件 318。
static func learn(s: XState, a: XActor, id: int) -> bool:
	if s == null or config().is_empty():
		return false
	var info := skill_info(id)
	if info.is_empty():
		return false
	var all: Dictionary = state(s).actors
	var key := str(a.actor_id)
	if not all.has(key):
		all[key] = {"race": int(info.race), "rank": int(info.rank), "free": true, "blood": false, "legacy": []}
	elif int(all[key].race) == int(info.race):
		all[key].rank = maxi(int(all[key].rank), int(info.rank))
	sync(s, a)
	return true


## 战斗指令「血契」：data(a).blood 取反（原版 raceBlood 处理器，指令窗随后 setup 重画）
static func toggle_blood(s: XState, a: XActor) -> void:
	var d := data(s, a)
	d.blood = not bool(d.blood)


## R.migrate：开关 281～287 恰好开了一个时把它当开局默认，再给全队补数据
static func migrate(s: XState) -> void:
	if default_race(s) < 0:
		var chosen := []
		for i in SWITCHES.size():
			if s.switch(SWITCHES[i]):
				chosen.append(i)
		if chosen.size() == 1:
			state(s).default = chosen[0]
	for a in s.members():
		data(s, a)


static func label(s: XState, a: XActor) -> String:
	var d := data(s, a)
	if int(d.race) < 0:
		return "待选择种族祝福"
	return race_name(int(d.race)) + "族祝福·" + RANKS[int(d.rank) - 1] + "阶"


## R.effects：该族该阶种族技能的说明按「；」拆开
static func effects(r: int, rank: int) -> Array:
	var sk := XDB.rec("Skills", race_skill(r, rank))
	return Array(str(sk.get("description", "")).split("；")) if not sk.is_empty() else []


## R.setDefault：记开局默认，没选种族也没有旧技能的角色改成这一族，开关只开对应的一个
static func set_default(s: XState, r: int, in_menu := false) -> bool:
	if r < 0 or r > 6:
		return false
	state(s).default = r
	for a in s.members():
		var d := data(s, a)
		if int(d.race) < 0 and (d.legacy as Array).is_empty():
			d.race = r
			sync(s, a)
	for key in state(s).actors.keys():
		var d: Dictionary = state(s).actors[key]
		if int(d.race) < 0 and (d.legacy as Array).is_empty():
			d.race = r
			sync(s, s.actor(int(key)))
	for i in SWITCHES.size():
		s.set_switch(SWITCHES[i], i == r)
	state(s).guideChosen = true
	XToast.show_text("开局默认祝福：" + race_name(r) + "族", in_menu, "race")
	return true


static func _member(s: XState, a: XActor) -> bool:
	return a != null and s.party.has(a.actor_id)


## 换族、进阶后按原比例恢复生命与法力（能力值变了，比例不变；生命为 0 的仍为 0）
static func _keep_ratio(s: XState, a: XActor, fn: Callable) -> void:
	var ratio := a.hp / a.mhp if a.mhp > 0 else 0.0
	var mp_ratio := a.mp / a.mmp if a.mmp > 0 else 0.0
	fn.call()
	a.hp = maxf(1.0, floorf(a.mhp * ratio)) if ratio > 0 else 0.0
	a.mp = floorf(a.mmp * mp_ratio)


## R.change：换族（每名角色第一次免费，之后消耗忘情水），血契关掉，旧技能记录清空
static func change(s: XState, a: XActor, r: int) -> Dictionary:
	if not _member(s, a) or r < 0 or r > 6:
		return {"ok": false, "reason": "只能在战斗外调整队伍角色"}
	var d := data(s, a)
	if int(d.race) == r:
		return {"ok": false, "reason": "已经是这个种族"}
	var water := int(config().water)
	if not bool(d.free) and s.item_count(water) < 1:
		return {"ok": false, "reason": "需要一份忘情水"}
	_keep_ratio(s, a, func():
		if not bool(d.free):
			s.gain_item(water, -1)
		d.free = false
		d.race = r
		d.blood = false
		d.legacy = []
		sync(s, a))
	state(s).guideChosen = true
	return {"ok": true}


## R.upgrade：消耗该阶进阶石（七族通用）升一阶
static func upgrade(s: XState, a: XActor, rank: int) -> Dictionary:
	if not _member(s, a) or rank < 2 or rank > 7:
		return {"ok": false, "reason": "只能在战斗外进阶"}
	var d := data(s, a)
	var stone := int(config().stones[rank - 2])
	if int(d.race) < 0:
		return {"ok": false, "reason": "请先选择一种祝福"}
	if int(d.rank) != rank - 1:
		return {"ok": false, "reason": "需要先拥有第%d阶祝福" % (rank - 1)}
	if s.item_count(stone) < 1:
		return {"ok": false, "reason": "缺少" + str(XDB.rec("Items", stone).get("name", ""))}
	_keep_ratio(s, a, func():
		s.gain_item(stone, -1)
		d.rank = rank
		sync(s, a))
	return {"ok": true}


## R.claimInbox：种族补给暂存箱（背包满时没拿到的进阶石）能放多少放多少
static func claim_inbox(s: XState) -> void:
	var inbox = s.race_supply.get("inbox", null)
	if not (inbox is Dictionary):
		return
	for k in inbox.keys():
		var id := int(k)
		var n := mini(int(inbox[k]), maxi(0, 9999 - s.item_count(id)))
		if n > 0:
			s.gain_item(id, n)
			inbox[k] = int(inbox[k]) - n
		if int(inbox[k]) <= 0:
			inbox.erase(k)
