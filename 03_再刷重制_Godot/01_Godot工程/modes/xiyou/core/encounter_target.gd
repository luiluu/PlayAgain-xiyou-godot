class_name XEncounterTarget
extends RefCounted
## 设置「定向遇怪」（O-384，Kyo 11-13「设置里那几个遇怪的开关都优化一下」「整个到一个定向的功能」）：
## 原版三项「只遇稀有」（Boss）、「只遇罕见」（BOSS）、「极其稀有」（boss）按遇敌表里的位置算抽签值，名字和效果对不上
## （只遇罕见单开几乎总是第一组普通怪；极其稀有＋只遇罕见同开落到第二组罕见），每次启动还要重开。
## 合成一项，按敌群成员名字的【前缀】认档：关／罕见／十分罕见／稀有／前所未见／亘古未有，存进配置。
## - 选了某档：在本次可遇的敌群（已按区域过滤）里取「不高于所选档的最高档」，本层没有低于等于它的档时取最低档；
##   同档有几组时按权重抽（用原来那次抽签值等比缩放，随机流不变）。所以选「亘古未有」＝本层最稀有。
## - 认不出的前缀（未知存在、洪荒、外界…、超级Boos／超级Boss（文字修正后的写法）、守层者、被封印者等）和没前缀的都算普通（0 档）。
## - 关（0）：照原版算法，仍认三个本次运行的旧开关（设置页不再列，开关只剩回退用）。
## - 全表同档（各组前缀都认不出或都一样，如特殊秘境:肝帝之地全是【外界…】）时按表里位置从后往前定档（T048，D114）：
##   亘古未有＝最后一项、前所未见＝倒数第二……罕见＝倒数第五，每档固定一种；组数不够时低档落到第一项。
##   原版三开关在这类表上也是按位置出固定的怪（极其稀有＝表末），按档认的话全表 0 档、各档都在整表随机。
## 回退：ENABLED＝false，设置页恢复原版三行，遇敌照原版；POSITION_FALLBACK＝false，全表同档时照旧在整表按权重抽。

static var ENABLED := true
static var POSITION_FALLBACK := true
const KEY := "codexEncounterTarget"
const NAMES := ["关", "罕见", "十分罕见", "稀有", "前所未见", "亘古未有"]
const TIERS := {"罕见": 1, "十分罕见": 2, "稀有": 3, "精英": 3, "前所未见": 4, "首领": 4, "亘古未有": 5, "亘古未见": 5}
static var _tier_cache := {}


static func level() -> int:
	return XConfig.encounter_target() if ENABLED else 0


static func text() -> String:
	return NAMES[clampi(level(), 0, NAMES.size() - 1)]


## 敌群的档：成员名字【前缀】里最高的一档
static func troop_tier(troop_id: int) -> int:
	if _tier_cache.has(troop_id):
		return _tier_cache[troop_id]
	var best := 0
	var re := RegEx.create_from_string("【([^】]*)】")
	for m in XDB.rec("Troops", troop_id).get("members", []):
		var name := str(XDB.rec("Enemies", int(m.get("enemyId", 0))).get("name", ""))
		for hit in re.search_all(name):
			best = maxi(best, int(TIERS.get(hit.get_string(1), 0)))
	_tier_cache[troop_id] = best
	return best


## 定向抽签：list 是可遇的遇敌表项（troopId、weight），r 是原来 0～权重和−1 的抽签值。没开（0 档）返回 -1，照原版。
static func pick(list: Array, r: int, total: int) -> int:
	var want := level()
	if want <= 0 or list.is_empty() or total <= 0:
		return -1
	var tiers := list.map(func(en): return troop_tier(int(en.troopId)))
	if POSITION_FALLBACK and tiers.min() == tiers.max():
		return _pick_by_position(list, want)
	var below := tiers.filter(func(t): return t <= want)
	var tier: int = below.max() if not below.is_empty() else tiers.min()
	var picked := []
	var sub := 0
	for i in list.size():
		if tiers[i] == tier and int(list[i].weight) > 0:
			picked.append(list[i])
			sub += int(list[i].weight)
	if sub <= 0:
		return -1
	var value := int(floor(float(clampi(r, 0, total - 1)) * sub / total))
	for en in picked:
		value -= int(en.weight)
		if value < 0:
			return int(en.troopId)
	return int(picked.back().troopId)


## 全表同档：只看权重大于 0 的项，档 want 取倒数第 (6−want) 项，不够就取第一项
static func _pick_by_position(list: Array, want: int) -> int:
	var live := list.filter(func(en): return int(en.weight) > 0)
	if live.is_empty():
		return -1
	var idx := maxi(live.size() - 1 - (NAMES.size() - 1 - want), 0)
	return int(live[idx].troopId)
