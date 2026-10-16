class_name XDungeon
extends RefCounted
## 副本系统（框架维护约定「跨楼层共性系统 → 副本入口与上下文」）。参照：oracle/dungeon.json（mv_oracle/dungeon_probe.cjs，冻结 v0.28）。
## 副本本身是普通 MV 事件：入口门按开关 1561～1660 每档一页，选档后「Difficulty SetID 档」、扣挑战符文、变量 21/5 加一、
## 变量 6＝副本编号、变量 94＝宝箱档次、变量 450＝所选档、传进副本、ProhibitHangUp；逃离／通关／重置时把这些减回并「Difficulty SetID 1」。
## 解释器只把两条插件指令和事件结束、事件战斗交给这里；这里记一份副本上下文（随存档），并接副本 Boss 奖励（CE1439 的 Codex 脚本）。
## - 难度：Vitsuno「Difficulty SetID」直接改游戏难度。原版离开副本后难度停在 1（宝宝），选档后没进成（缺符文／要重置）也停在所选档，
##   要到下次换层／回大厅时公共事件 714 按难度开关恢复。O-038 改为离开或没进成时立即恢复进门前的难度。
## - 挂机：ProhibitHangUp 只关开关（$gameParty._hangUpSiwitch），运行中的挂机状态不动；原版要到大厅大工匠（Map004 EV7）处重开。
##   O-040 改为离开副本时恢复成进门前的开关。
## - 上下文：入口地图／事件、副本编号（变量 6）、所选档（450）、进门前难度与挂机开关、挑战符文、进入后的地图。不另存变量 5/6/21/94/450
##   与开关（它们本来就在 XState 里随存档），重读后照原版继续，不会重复扣符文。

const VAR_SEALED := 5      # 副本未重置（入口「请重置副本！」）
const VAR_ID := 6          # 当前副本编号
const VAR_INSIDE := 21     # 在副本内（枫叶回城、地图传送都被禁）
const VAR_LOOT := 94       # 宝箱档次
const VAR_TIER := 450      # 所选档：1 普通 2 冒险 3 勇士 4 王者

## O-038：离开副本（变量 21 归零后的 Difficulty SetID）或选档后没进成时，难度恢复成进门前；false 恢复原版。
static var restore_difficulty := true
## O-040：离开副本时挂机开关恢复成进门前；false 恢复原版（到大厅大工匠处重开）。
static var restore_hang_up := true

## installNativeEconomyRuntime：副本 Boss 熟练度与抽奖券
const TICKET := 1639
const FLOOR_DIV := 3
const MASTERY := [[1, 10, 1], [10, 30, 2], [50, 100, 3]]
const BOOK_RATE := 0.05
const BOSS_BOOKS := {221: 2240, 377: 2236, 603: 2237, 604: 2237, 605: 2237, 695: 2337}
## 甚尔、宿傩进阶石（installNativeTojiRuntime／installNativeSukunaRuntime 的 rollAdvanceStone）
const TOJI := {"actor": 171, "stone": 2935}
const SUKUNA := {"actor": 172, "stone": 2937}

## 最近一场事件战斗（BattleManager.setup 时记楼层，endBattle 记胜负）：Boss 奖励、神秘珠、种族补给只认这一场，各领一次
static var battle := {}
## 地图事件对照用：参照的 event_probe 只回调战斗结果、不走 BattleManager.endBattle，胜负不记（神秘珠、种族补给不发）
static var battle_end_counts := true


# ---- 入口定义 ----

## 从入口页的指令里读出副本入口：挑战符文、传送目的地、各档（Difficulty SetID 与变量 94 的范围）。
## 同时有 ProhibitHangUp、变量 21 加一与持有物品条件的才算副本入口，否则返回 {}（Map001 选难度、大厅挑战等不算）。
static func entry_spec(list: Array) -> Dictionary:
	var spec := {"rune": 0, "transfers": [], "tiers": [], "loot": []}
	var prohibit := false
	var enters := false
	for c in list:
		var p: Array = c.get("parameters", [])
		match int(c.code):
			356:
				var line := str(p[0])
				if line == "ProhibitHangUp":
					prohibit = true
				elif line.begins_with("Difficulty SetID "):
					var n := int(line.get_slice(" ", 2))
					if not spec.tiers.has(n):
						spec.tiers.append(n)
			111:
				if int(p[0]) == 8 and spec.rune == 0:
					spec.rune = int(p[1])
			122:
				if int(p[0]) == VAR_INSIDE and int(p[2]) == 1:
					enters = true
				if int(p[0]) == VAR_LOOT and int(p[3]) == 2:
					spec.loot.append([int(p[4]), int(p[5])])
			201:
				if int(p[0]) == 0:
					var to := [int(p[1]), int(p[2]), int(p[3])]
					if not spec.transfers.has(to):
						spec.transfers.append(to)
	return spec if prohibit and enters and spec.rune > 0 else {}


static func context(s: XState) -> Dictionary:
	return s.dungeon.get("context", {})


static func inside(s: XState) -> bool:
	return s.variable(VAR_INSIDE) != 0


# ---- 插件指令与事件钩子（MVInterpreter 调用） ----

## Vitsuno「Difficulty SetID N」
static func set_difficulty(s: XState, n: int, interp) -> void:
	var ctx := context(s)
	if not ctx.is_empty() and not inside(s):
		s.difficulty = n
		leave(s)
		return
	if ctx.is_empty() and not inside(s) and not s.dungeon.has("pending") and interp != null and interp._depth == 0:
		var spec := entry_spec(interp.list)
		if not spec.is_empty():
			s.dungeon.pending = {"entryMap": interp.map_id, "entryEvent": interp.event_id, "baseDifficulty": s.difficulty,
				"hangEnabled": XHangUp.enabled(s), "rune": spec.rune}
	s.difficulty = n


## XdRs_HangUp「ProhibitHangUp / EnableHangUp」：只改开关
static func set_hang_up(s: XState, enabled: bool) -> void:
	s.flags["HangUpProhibited"] = not enabled


## 顶层事件结束：入口事件进了副本就记上下文，没进成就清掉（O-038 恢复难度）
static func event_finished(s: XState) -> void:
	if s == null or not s.dungeon.has("pending"):
		return
	var pending: Dictionary = s.dungeon.pending
	s.dungeon.erase("pending")
	if inside(s):
		pending.merge({"id": int(s.variable(VAR_ID)), "tier": int(s.variable(VAR_TIER)), "difficulty": s.difficulty, "map": s.map_id})
		s.dungeon["context"] = pending
	elif restore_difficulty:
		s.difficulty = int(pending.baseDifficulty)


## 离开副本（逃离、通关传回、入口重置）：清上下文；O-038 恢复难度，O-040 恢复挂机开关
static func leave(s: XState) -> void:
	var ctx := context(s)
	s.dungeon.erase("context")
	if ctx.is_empty():
		return
	if restore_difficulty:
		s.difficulty = int(ctx.baseDifficulty)
	if restore_hang_up and bool(ctx.hangEnabled):
		set_hang_up(s, true)


## 事件战斗（指令 301）：setup 时取 Boss 所在楼层，结束记胜负（result 0 为胜）
static func battle_finished(troop: int, result: int, map_id: int) -> void:
	battle = {"troop": troop, "floor": boss_floor(map_id), "won": result == 0 and battle_end_counts, "orb": false, "supply": false}


# ---- 副本 Boss 奖励（CE1439 的 Codex 脚本） ----

## installNativeHonghuangRuntime.mapFloor：沿地图树往上找名字里的「N层」或「十二层」
static func map_floor(map_id: int) -> int:
	var i := map_id
	var guard := 0
	while i > 0 and guard < 20:
		guard += 1
		var info := XDB.rec("MapInfos", i)
		if info.is_empty():
			break
		var f := parse_floor(str(info.get("name", "")))
		if f > 0:
			return f
		i = int(info.get("parentId", 0))
	return 0


static func parse_floor(t: String) -> int:
	var m := RegEx.create_from_string("(\\d+)\\s*层").search(t)
	if m:
		return int(m.get_string(1))
	m = RegEx.create_from_string("([一二三四五六七八九十]+)层").search(t)
	if not m:
		return 0
	const CN := "零一二三四五六七八九十"
	var s := m.get_string(1)
	if not s.contains("十"):
		return CN.find(s)
	var parts := s.split("十")
	return (CN.find(parts[0]) if parts[0] != "" else 1) * 10 + (CN.find(parts[1]) if parts[1] != "" else 0)


## CodexHonghuang.bossFloor：地图所在层，否则修行进度层（CodexZhenqi.progressFloor：变量 20 − 1，限 0～33）
static func boss_floor(map_id: int) -> int:
	var f := map_floor(map_id)
	if f > 0:
		return f
	var s := XState.current
	return clampi(int(s.variable(20)) - 1, 0, 33) if s else 0


## 熟练度达到的最高一档的专属书掉率倍数（CodexEconomy.powerFactor）
static func power_factor(s: XState, troop: int) -> float:
	var n := int(s.boss_mastery.get(str(troop), 0))
	var f := 1.0
	for r in MASTERY:
		if n >= int(r[0]):
			f = float(r[2])
	return f


## CodexEconomy.bossReward（含 installNativeOrbRuntime 的神秘珠、installNativeRaceRuntime 的种族补给）。返回提示文字列表。
static func boss_reward(s: XState) -> Array:
	var toasts := []
	var t := int(battle.get("troop", 0))
	if t == 0:
		return toasts
	var n := int(s.boss_mastery.get(str(t), 0)) + 1
	s.boss_mastery[str(t)] = n
	var f := boss_floor(s.map_id)
	var extra := floori(maxi(0, f) / float(FLOOR_DIV))
	var bonus := 0
	var next := []
	for r in MASTERY:
		if n == int(r[0]):
			bonus += int(r[1])
		if next.is_empty() and n < int(r[0]):
			next = r
	var total := extra + bonus
	if total > 0:
		s.gain_item(TICKET, total)
	var name := RegEx.create_from_string("【[^】]*】").sub(str(XDB.rec("Troops", t).get("name", "")), "", true).split(",")[0].strip_edges()
	var msg := "%s 熟练度 %d 次：抽奖券 +%d" % [name, n, total]
	if extra > 0:
		msg += "（%d层 +%d%s）" % [f, extra, ("，熟练度 +%d" % bonus) if bonus > 0 else ""]
	if not next.is_empty():
		msg += "，再打 %d 次领 +%d%s" % [int(next[0]) - n, int(next[1]), ("、专属书掉率×%d" % int(next[2])) if int(next[2]) > 1 else ""]
	toasts.append(msg)
	var book := int(BOSS_BOOKS.get(t, 0))
	if book > 0 and MVInterpreter.random_float() < minf(1.0, BOOK_RATE * power_factor(s, t)):
		s.gain_item(book, 1)
		toasts.append("副本Boss专属掉落：%s！" % str(XDB.rec("Items", book).get("name", "")))
	# 神秘珠（O.dropBossPearl：本场胜利、每场一次）
	if bool(battle.get("won", false)) and not bool(battle.get("orb", false)):
		battle.orb = true
		var drop := XOrbs.drop_boss_pearl(s, int(battle.floor))
		if not drop.is_empty():
			toasts.append(str(drop.toast))
	# 种族补给（R.claimSupply）
	var supply := race_supply(s)
	if supply != "":
		toasts.append(supply)
	return toasts


## installNativeRaceRuntime.claimSupply：Boss 所在层落在 bands 第 k 段时记一次，第一次与每满 5 次各给一枚该段的祝福进阶石
static func race_supply(s: XState) -> String:
	var races = XDB.table("CodexRaces")
	if not (races is Dictionary) or not bool(battle.get("won", false)) or bool(battle.get("supply", false)):
		return ""
	battle.supply = true
	var rank := 0
	var bands: Array = races.get("bands", [])
	for i in bands.size():
		if int(battle.floor) >= int(bands[i][0]) and int(battle.floor) <= int(bands[i][1]):
			rank = i + 2
	if rank == 0:
		return ""
	var sup: Dictionary = s.race_supply
	for k in ["counts", "first", "inbox"]:
		if not sup.has(k):
			sup[k] = {}
	var key := str(rank)
	var n := int(sup.counts.get(key, 0)) + 1
	sup.counts[key] = n
	var total := 0
	if not bool(sup.first.get(key, false)):
		sup.first[key] = true
		total += 1
	if n >= 5:
		sup.counts[key] = n % 5
		total += 1
	if total == 0:
		return ""
	var id := int(races.stones[rank - 2])
	var before := s.item_count(id)
	s.gain_item(id, total)
	var pending := total - (s.item_count(id) - before)
	if pending > 0:
		sup.inbox[str(id)] = int(sup.inbox.get(str(id), 0)) + pending
	return "获得%s×%d%s" % [str(XDB.rec("Items", id).get("name", "")), total, "；背包已满，暂存祝福管理" if pending > 0 else ""]


## 甚尔／宿傩的进阶石（rollAdvanceStone）：角色未进阶（重制版尚无这两个角色，进阶数按 0）、背包里不够数时 1/50 得一枚
static func roll_advance_stone(s: XState, who: Dictionary) -> String:
	var need := 1 if who == TOJI else 3
	if s.item_count(int(who.stone)) >= need or MVInterpreter.random_int(0, 49) != 0:
		return ""
	s.gain_item(int(who.stone), 1)
	return "获得了 %s！" % ("甚尔进阶石" if who == TOJI else "咒王进阶石")


# ---- 秘境抽奖（installNativeMijingDrawRuntime：CE1440 特殊被动书等） ----

## Lv1、Lv2、Lv3、LvMax 的权重（按档 I～IV）
const MIJING_WEIGHTS := {1: [70, 30, 0, 0], 2: [30, 55, 15, 0], 3: [0, 30, 55, 15], 4: [0, 0, 65, 35]}
static var _mijing := {}

## 物品备注 <CodexMijing: 系列,等级>：系列按物品 ID 顺序第一次出现排列，每系列 [Lv1, Lv2, Lv3, LvMax] 的物品 ID
static func mijing_pool() -> Dictionary:
	if not _mijing.is_empty():
		return _mijing
	var re := RegEx.create_from_string("<CodexMijing:\\s*([^,>]+?)\\s*,\\s*([1-4])\\s*>")
	var items = XDB.table("Items")
	for it in items:
		if not (it is Dictionary):
			continue
		var m := re.search(str(it.get("note", "")))
		if m:
			var fam: Array = _mijing.get(m.get_string(1), [0, 0, 0, 0])
			fam[int(m.get_string(2)) - 1] = int(it.id)
			_mijing[m.get_string(1)] = fam
	return _mijing


static func mijing_tier(floor_no: int) -> int:
	return 4 if floor_no >= 26 else 3 if floor_no >= 19 else 2 if floor_no >= 13 else 1


## CodexMijing.pickHere：先等概率选系列，再按所在塔层的档位掷等级（没有该级的往下找）
static func mijing_pick_here(s: XState) -> int:
	var pool := mijing_pool()
	if pool.is_empty():
		return 0
	var f := map_floor(s.map_id)
	if f <= 0:
		f = int(s.variable(20)) if s.variable(20) != 0 else 1
	var fam: Array = pool.values()[floori(MVInterpreter.random_float() * pool.size())]
	var w: Array = MIJING_WEIGHTS[mijing_tier(f)]
	var r := MVInterpreter.random_float() * 100.0
	var level := w.size() - 1
	for i in w.size():
		if r < float(w[i]):
			level = i
			break
		r -= float(w[i])
	while level > 0 and int(fam[level]) == 0:
		level -= 1
	if int(fam[level]) != 0:
		return int(fam[level])
	for id in fam:
		if int(id) != 0:
			return int(id)
	return 0
