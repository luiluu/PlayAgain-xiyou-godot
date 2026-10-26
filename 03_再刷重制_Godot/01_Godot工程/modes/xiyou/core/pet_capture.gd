class_name XPetCapture
extends RefCounted
## 宠物来源（Star_PetSystem）：战斗捕捉与神秘生物刷新。宠物本身怎么造见 XPets.create。参照 tests/fixtures/pet_capture_oracle.json。
## - 可捕捉（Scene_Battle.start 包装）：每个敌人（含隐藏成员）有备注 <Capture: …> 就取第一个整数 N，掷一次「随机×100 ≤ N」；
##   掷不中保持原值（敌群 1 在 Game_Troop.setup 已强制可捕捉）。可捕捉的敌人名字加「宝宝」（XEnemy.display_name）。
## - 逃跑（BattleManager.endTurn 包装）：第 5 回合结束，可捕捉且活着的敌人提示「敌人逃跑」，die＋hide。原版判的是「不算阵亡」，
##   隐藏成员也算：已被捕走（die＋hide）的敌人会再提示一次「敌人逃跑」，还没出现的隐藏成员也被「逃跑」掉、之后 335 出现的是
##   一具 0 血尸体。O-098：只让活着的逃跑（FLEE_ALIVE_ONLY），设 false 恢复原版。
## - 捕捉（物品 200／315／316／317 的公共事件 173 Star.PetSystem.PetGet）：先掷「随机×100 ≤ 物品成功率」，中了且目标可捕捉 →
##   造宠物入列、目标 die＋hide、「捕捉成功」；目标不可捕捉 →「不可捕捉」并退还一件；否则「捕捉失败」。
##   宠物的学习次数上限（extraLSMax）原版在建敌人时（initMembers）就掷了，这里捕到时才掷（XPets.create 最后一次抽取），分布相同。
##   原版读全局 Star.PetSystem.Game_Action（最后一个 setItem 的行动），OTB 下轮到谁谁才输入并立即行动，就是这次行动本身。
## - die＋hide 后 HP 0、带阵亡状态但隐藏：不算阵亡也不算活着（isAppeared），不给经验、金钱、掉落，全灭判定照常成立。
## - 随机数：原版是 Math.random。重制不占战斗 rule 流（会让所有战斗对照的抽取顺序错位），用本场 XBattleRandom 的 "pet" 流。
## - 神秘生物（isrefreshGTEveWar，真实时钟）：每小时 0～4、30～34 分是刷新窗口。窗口外（或本窗口已打过敌群 1）把 PetMap 各图的
##   事件独立开关全关；窗口内从候选里随机挑一处打开（不关别处），PetEneId 里随机一个写进敌群 1（$dataTroops，不存档），
##   PetShowTextT 时提示 PetShowText（空时「在<地图名>出现了神秘生物」）。候选：PetRef_Capture 关时取 PetRefNum 以外的
##   （PetMap 1～4），开时只取 PetRefNum 里的（12～15 奇兽）。敌群 1 开战时记下日／时／分（PetRefDay/Hour/Minute）。
## 存档：XState.pets 的 ref_capture、ref_day、ref_hour、ref_minute（$gameParty.PetRef_Capture／PetRefDay…）。
## O-098：提示开关 $gameParty.PetShowTextT 原版没有任何地方打开，刷新的「天生异象……」提示永远不弹，玩家不知道神秘生物出现了。
##   重制默认弹（SHOW_REFRESH_TEXT），设 false 恢复原版（只在存档 pets.show_text 为真时弹）。

const FLEE_TURN := 5
## O-098（见文件头）
static var SHOW_REFRESH_TEXT := true
static var FLEE_ALIVE_ONLY := true

## 测试用：返回 {day, hour, minute} 的时钟（缺省读系统时间）
static var clock := Callable()


static func now() -> Dictionary:
	if clock.is_valid():
		return clock.call()
	var t := Time.get_datetime_dict_from_system()
	return {"day": int(t.day), "hour": int(t.hour), "minute": int(t.minute)}


## <Capture: N%> 的 N（/(\d+)/ 第一个整数）；没有标签 −1
static func threshold(enemy_id: int) -> int:
	var note := str(XDB.rec("Enemies", enemy_id).get("note", ""))
	var m := RegEx.create_from_string("<Capture:([^>]*)>").search(note)
	if m == null:
		return -1
	var n := RegEx.create_from_string("(\\d+)").search(m.get_string(1))
	return int(n.get_string(1)) if n != null else -1


## 本场的 "pet" 随机流（XBattleRandom.pet）；测试可用 logic 的 meta "pet_random" 换成脚本流
static func random(logic) -> XRandomStream:
	if logic.has_meta("pet_random"):
		return logic.get_meta("pet_random")
	if logic.random == null:
		return XRandomStream.create(XRandomStream.fresh_seed(), "pet")  # 没有本场随机（不应发生：只在战斗里调）
	return logic.random.pet


## 开战（XBattleScene.setup 里 logic.setup 之后＝Scene_Battle.start；只建 logic 的规则测试不掷，名字不带「宝宝」）：敌群 1 强制可捕捉并记时间，再按 <Capture> 掷。rnd：本场的 pet 流（测试传入脚本流），缺省新派生
static func roll_battle(logic, rnd: XRandomStream = null) -> void:
	if rnd != null:
		logic.set_meta("pet_random", rnd)
	if int(logic.troop_id) == 1 and not logic.enemies.is_empty():
		logic.enemies[0].capture = true
		var t := now()
		var d := XPets._data(logic.state)
		d.ref_day = t.day
		d.ref_hour = t.hour
		d.ref_minute = t.minute
	for e in logic.enemies:
		var n := threshold(e.enemy_id)
		if n >= 0 and random(logic).next_float("capture", str(e.enemy_id)) * 100.0 <= n:
			e.capture = true


## die＋hide（Game_BattlerBase.die → refresh 加阵亡 → hide）；返回画面记录
static func _vanish(logic, e: XEnemy) -> Array:
	var slot: int = logic.enemies.find(e)
	var before: Dictionary = logic._enemy_reading(e)
	e.hp = 0.0
	e.clear_states()
	logic._die(e)
	e.hidden = true
	return [logic._enemy_change("vanish", slot, before)]


static func _toast(text: String) -> Dictionary:
	return {"type": "toast", "text": text}


## 回合结束（XBattleLogic.end_turn 开头）：第 5 回合可捕捉的敌人逃跑
static func end_turn(logic) -> Array:
	var out := []
	if int(logic.turn) != FLEE_TURN:
		return out
	for e in logic.enemies:
		if e.capture and (e.is_alive() if FLEE_ALIVE_ONLY else not e.is_dead()):
			out.append(_toast("敌人逃跑"))
			out.append_array(_vanish(logic, e))
	return out


## 公共事件 173 的脚本 Star.PetSystem.PetGet()（XBattleEventRunner 的 355 分支调）：道具与目标取「最后一个用道具的行动」
## （Star.PetSystem.Game_Action，见 XBattleCommonEvent.last_item_action）。返回记录
static func pet_get(logic) -> Array:
	var act := XBattleCommonEvent.last_item_action(logic)
	if act.is_empty() or not act.get("target") is XEnemy:
		return []
	return capture(logic, act.item, act.target)


## PetGet 的判定：先掷「随机×100 ≤ 道具成功率」，中了且目标可捕捉＝捕到；不可捕捉退还一件；否则失败
static func capture(logic, item: Dictionary, target: XEnemy) -> Array:
	var rnd := random(logic)
	var hit := rnd.next_float("capture_item", str(item.get("id", 0))) * 100.0 <= float(item.get("successRate", 100))
	var out := []
	if hit and target.capture:
		var pet := XPets.create(target.enemy_id, target.elite, target.letter, func(): return rnd.next_float("pet_create"))
		XPets.list(logic.state).append(pet)
		out.append(_toast("捕捉成功"))
		out.append_array(_vanish(logic, target))
	elif not target.capture:
		out.append(_toast("不可捕捉"))
		logic.state.gain_item(int(item.get("id", 0)), 1)
	else:
		out.append(_toast("捕捉失败"))
	return out


# ---- 神秘生物 ----
## 插件参数 PetMap 1～50（序号 → {PetMapIDA…}）与 PetRefNum
static func pet_maps() -> Dictionary:
	var p := XDB.plugin("Star_PetSystem")
	var out := {}
	for i in range(1, 51):
		var raw := str(p.get("PetMap %d" % i, ""))
		if raw == "" or raw == "null":
			continue
		var m = JSON.parse_string(raw)
		if m is Dictionary:
			var ids = JSON.parse_string(str(m.get("PetEneId", "")))
			out[i] = {"name": str(m.get("PetMapName", "")), "maps": [int(str(m.get("PetMapIDA", "0"))), int(str(m.get("PetMapIDB", "0")))],
				"events": [int(str(m.get("PetMapEveIDA", "0"))), int(str(m.get("PetMapEveIDB", "0")))],
				"switches": [str(m.get("PetMapEveSwA", "")), str(m.get("PetMapEveSwB", ""))],
				"enemies": ids if ids is Array else [], "text": str(m.get("PetShowText", ""))}
	return out


static func ref_num() -> Array:
	var raw = JSON.parse_string(str(XDB.plugin("Star_PetSystem").get("PetRefNum", "[]")))
	return (raw if raw is Array else []).map(func(x): return int(str(x)))


## StopGTEveWar：所有刷新图的事件独立开关关掉
static func stop(s: XState) -> void:
	for m in pet_maps().values():
		for k in 2:
			if m.maps[k] > 0:
				s.set_self_switch(m.maps[k], m.events[k], m.switches[k], false)


## 原版 setInterval(isrefreshGTEveWar, 300000)：新游戏／读档成功时先查一次，之后每 5 分钟（真实时间，本次运行只开一个）。
## 重制由地图场景每帧调用：到点返回要弹的提示（可能为空数组），没到点返回 null。战斗、菜单期间到点的，回地图第一帧补查一次。
static var _next_check_ms := -1


static func tick(s: XState) -> Variant:
	var t := Time.get_ticks_msec()
	if _next_check_ms >= 0 and t < _next_check_ms:
		return null
	_next_check_ms = t + 300000
	return check(s)


static func _in_window(minute: int) -> bool:
	return (minute >= 0 and minute < 5) or (minute >= 30 and minute < 35)


## isrefreshGTEveWar；rnd 返回 [0,1)（缺省 randf，原版 Math.random）。返回要弹的提示
static func check(s: XState, rnd := Callable()) -> Array:
	var t := now()
	var d := XPets._data(s)
	if not _in_window(t.minute):
		stop(s)
		return []
	if d.get("ref_day") == t.day and d.get("ref_hour") == t.hour and _in_window(int(d.get("ref_minute", -1))) \
			and (int(d.ref_minute) < 5) == (t.minute < 5):
		stop(s)
		return []
	return refresh(s, rnd)


## refreshGTEveWar
static func refresh(s: XState, rnd := Callable()) -> Array:
	if not rnd.is_valid():
		rnd = func(): return randf()
	var maps := pet_maps()
	var refs := ref_num()
	var on := bool(XPets._data(s).get("ref_capture", false))
	var pool := []
	for i in maps.keys():
		if refs.has(i) == on:
			pool.append(i)
	var out := []
	if pool.is_empty():
		return out
	pool.sort()
	var m: Dictionary = maps[pool[roundi(float(rnd.call()) * 1000.0) % pool.size()]]
	var show := SHOW_REFRESH_TEXT or bool(XPets._data(s).get("show_text", false))
	for k in 2:
		if m.maps[k] > 0:
			s.set_self_switch(m.maps[k], m.events[k], m.switches[k], true)
			if show and m.text == "":
				out.append("在" + str(XDB.rec("MapInfos", m.maps[k]).get("name", "")) + "出现了神秘生物")
	if show and m.text != "":
		out.append(m.text)
	var troop := XDB.rec("Troops", 1)
	if not m.enemies.is_empty() and not troop.get("members", []).is_empty():
		troop.members[0].enemyId = int(m.enemies[roundi(float(rnd.call()) * 1000.0) % m.enemies.size()])
	elif not troop.get("members", []).is_empty():
		var rare := []
		for e in XDB.table("Enemies"):
			if e is Dictionary and str(e.get("note", "")).contains("<Capture") and str(e.get("note", "")).contains("RareCapture"):
				rare.append(int(e.id))
		if not rare.is_empty():
			troop.members[0].enemyId = rare[roundi(float(rnd.call()) * 1000.0) % rare.size()]
	return out
