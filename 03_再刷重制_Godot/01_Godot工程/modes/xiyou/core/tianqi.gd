class_name XTianqi
extends RefCounted
## 天启篇第一批：新开局（Kyo 2026-11-10「目前的入口就是天启篇」，按数值重构方案第五～七节）。
## 新游戏 → 选存档位 → 选难度（五档，证道暂锁）→ 随机阵容（5 人、无限重抽，第一个是 1 号位）→ 方桌大厅 → 引路人问道号。
## 原版开局 Map001（存档位、难度、名字、天道使者规则）→ Map002（选英雄、初始化）→ Map221（教派）整段跳过，
## 它们留下的状态由 opening_commands 拼成一份事件指令，在大厅里用原版事件解释器一次跑完（顺序照原版），
## 跑完再由 Map004 EV020 的首次到达自动事件存档并按难度学被动，与原版相同。
##
## 规则版本记在存档 flags["tianqi"]（rules／difficulty／lineup）。新规则只认 active(s)：原版开局建的档、测试直接建的状态都不受影响，
## 还原期的原版对照照旧。
##
## 本批不动数值：五档先各借一档原版难度（legacy，寻常＝简单 … 证道＝天灾）跑原版的难度分支，难度被动、天道诅咒等留到数值批按新难度表重做。
## 删掉的东西：开局对话与选择、教派（2301／2302 不再设）、宝宝路线（五档里没有）、伙伴号角里德（招募改通关抽角色，下一批）、羁绊（XBonds.enabled）。

## 开关（O-260）：true＝新游戏走天启篇开局；false＝回到原版 Map001 开局。
static var ENABLED := true
## 发行开关（O-307）：Kyo 11-11「新整包只有天启篇的标题和载入界面，完整天启篇内容以后单独更新」。
## false＝发行构建（ReleaseEntry.is_release）里新游戏走原版开局，天启篇规则（都只认存档里的天启篇标记）一条都不生效；
## 开发版、测试照 ENABLED。天启篇做完发补丁把它改成 true 即开放。
static var RELEASE_OPEN := false
## 证道一命通关：Kyo 平衡好之前不开放（数值重构方案第五节），选难度页显示锁定。
static var ZHENGDAO_OPEN := false

const RULES_VERSION := 1
const HALL_MAP := 4
const HALL_POS := Vector3i(14, 23, 8)  # 原版 Map002／Map221 进大厅的场所移动（x, y, 朝向）
const LINEUP_SIZE := 5
## 上场 4 人＋1 个助力位（出战栏第 5 格，下标 4）
const FIGHTERS := 4
const HELPER_SLOT := 4
const GUIDE_NAME := "小小鱼"
const BADGE_DIR := "res://modes/xiyou/ui/tianqi/"

## 五档难度（数值重构方案第五、六节；出战上限与弱者下限是试算起点）。
## legacy：第一、二批借用的原版难度（Vitsuno 难度号，2 简单 3 普通 4 困难 5 地狱 6 天灾）；第三批起只在 UNIFIED_LEGACY＝false 时用。
## super_cap（同一场上阵的超强者上限）、min_weak（每次随机阵容至少几名弱者）、候选池的档位：第三批起只认数值表
## （XTianqiBalance，balance_table.json），difficulty() 把它们并进来，这里不再写一份。
const DIFFICULTIES := [
	{"key": "xunchang", "name": "寻常", "desc": "初入西行，熟悉玩法", "legacy": 2, "badge": "01_xunchang.png"},
	{"key": "jianxian", "name": "艰险", "desc": "标准体验", "legacy": 3, "badge": "02_jianxian.png"},
	{"key": "jiusi", "name": "九死", "desc": "需要搭配与养成", "legacy": 4, "badge": "03_jiusi.png"},
	{"key": "lianyu", "name": "炼狱", "desc": "敌人大幅强化，可上阵更多超强者", "legacy": 5, "badge": "04_lianyu.png"},
	{"key": "zhengdao", "name": "证道", "desc": "一命通关，全灭即删档", "legacy": 6, "badge": "05_zhengdao.png"},
]
## 第三批（XTianqiCombat）：五档在数值上都按「艰险」跑，艰险借原版普通（3）。开关（O-278，与 XTianqiCombat.ENABLED 一起）：
## true＝开局一律走原版普通难度分支，难度差别只来自数值表（敌人血量、攻击等）；false＝回到第二批，各档借各自的原版难度。
static var UNIFIED_LEGACY := true
const NUMERIC_LEGACY := 3

## 开关（O-267）：true＝天启篇存档只能在大厅通关抽角色，号角拿不到、商店不卖，事件和别的入口不再让新角色入队；
## false＝照原版（号角、招募事件照旧）。
static var NO_RECRUIT := true
## 开关（O-279）：true＝天启篇存档不学一线生机 6212、天道注视 6213（公共事件 1330 整段不做；Kyo 11-08 数值重构「删掉一线生机和天道注视」）；
## false＝照原版。
static var NO_HEAVEN_GAZE := true
## 开关（O-268）：true＝战斗中多一条「换人」指令，和助力位互换（用掉这次行动）；false＝不能换
static var SWAP_IN_BATTLE := true
## 开关（O-281，审查 78 P3-1）：true＝换上来的助力位补开战初始化（初始 TP、预热、开战状态标签、种族本场数据）；
## false＝照第二批，换上来什么都不补
static var SWAP_INIT := true

## 通关抽角色（数值重构方案「招募改成通关抽角色」，Kyo 11-08 定的表）：每通关 5 层一次，最多 6 次。
## 每档 6 行，依次是第 1～6 次：[档位, 几选一]；几选一为 0＝自选（档位内本局还没有的全部）。不能重抽。
const DRAW_EVERY := 5
const DRAW_MAX := 6
const _W := ["弱者"]
const _S := ["强者"]
const _U := ["超强者"]
const _WS := ["弱者", "强者"]
const _SU := ["强者", "超强者"]
const _ALL := ["弱者", "强者", "超强者"]
const DRAW_TABLE := {
	"xunchang": [[_W, 1], [_W, 1], [_W, 1], [_WS, 1], [_S, 1], [_WS, 0]],
	"jianxian": [[_W, 1], [_W, 2], [_WS, 2], [_S, 2], [_S, 3], [_WS, 0]],
	"jiusi": [[_W, 2], [_WS, 2], [_S, 3], [_SU, 3], [_U, 3], [_ALL, 0]],
	"lianyu": [[_W, 3], [_WS, 3], [_S, 3], [_SU, 5], [_U, 5], [_ALL, 0]],
	"zhengdao": [[_W, 5], [_WS, 5], [_S, 5], [_U, 5], [_ALL, 0], [_ALL, 0]],
}
## 抽角色、开局阵容入队时为真（NO_RECRUIT 下只有这两处能让新角色入队）
static var _joining := false

## 开局要在大厅里跑的指令（start_new_game 放进来，地图场景 take_pending 取走）；不存档。
static var _pending: Array = []


static func difficulty(key: String) -> Dictionary:
	for d in DIFFICULTIES:
		if d.key == key:
			var out: Dictionary = d.duplicate()
			var row := XTianqiBalance.difficulty(key)
			out["super_cap"] = int(row.get("super_cap", 0))
			out["min_weak"] = int(row.get("min_weak", 0))
			out["pool"] = row.get("pool", [])
			return out
	return {}


## 开局借的原版难度号：UNIFIED_LEGACY 下五档都是 NUMERIC_LEGACY（普通）
static func legacy_of(key: String) -> int:
	return NUMERIC_LEGACY if UNIFIED_LEGACY else int(difficulty(key).get("legacy", NUMERIC_LEGACY))


static func locked(key: String) -> bool:
	return key == "zhengdao" and not ZHENGDAO_OPEN


static func badge_path(d: Dictionary) -> String:
	return BADGE_DIR + str(d.get("badge", ""))


## 这份存档按天启篇规则（新开局建的档）
## 「新的游戏」走不走天启篇开局：ENABLED 且（不是发行构建或发行已开放）
static func new_game_enabled() -> bool:
	return ENABLED and (RELEASE_OPEN or not ReleaseEntry.is_release())


static func active(s: XState) -> bool:
	return s != null and s.flags.get("tianqi") is Dictionary and int(s.flags.tianqi.get("rules", 0)) >= 1


static func difficulty_of(s: XState) -> Dictionary:
	return difficulty(str(s.flags.tianqi.get("difficulty", ""))) if active(s) else {}


## 本档同一场能上阵的超强者人数（不是天启篇存档返回 -1＝照原版规则）
static func super_cap(s: XState) -> int:
	var d := difficulty_of(s)
	return int(d.super_cap) if not d.is_empty() else -1


# ---- 随机阵容 ----

## 能抽到的角色：有名字、分了档（XTier）、没停用（导入角色 143～145、157、160 等）。
## 候选池按数值表本档的 pool：寻常、艰险只出弱者和强者，九死起全部。
static func pool(key: String) -> Dictionary:
	var d := difficulty(key)
	var allowed: Array = d.get("pool", [])
	var out := {XTier.WEAK: [], XTier.STRONG: [], XTier.SUPER: []}
	for tier in out:
		if not allowed.has(tier):
			continue
		for id in XTier.ids(tier):
			if not XImportedBalance.is_disabled_actor(id):
				out[tier].append(id)
	return out


## 抽一次阵容：先抽够弱者下限，再从全池补满（超强者不超过本难度上限），最后打乱顺序（第一个是 1 号位）。
static func roll_lineup(key: String, rng: RandomNumberGenerator) -> Array:
	var d := difficulty(key)
	var p := pool(key)
	var picked := []
	var weak: Array = p[XTier.WEAK].duplicate()
	_shuffle(weak, rng)
	for id in weak.slice(0, mini(int(d.get("min_weak", 0)), LINEUP_SIZE)):
		picked.append(id)
	var rest: Array = (p[XTier.WEAK] + p[XTier.STRONG] + p[XTier.SUPER]).filter(func(id): return not picked.has(id))
	_shuffle(rest, rng)
	var supers := 0
	for id in rest:
		if picked.size() >= LINEUP_SIZE:
			break
		if XTier.is_super(id):
			if supers >= int(d.get("super_cap", 0)):
				continue
			supers += 1
		picked.append(id)
	_shuffle(picked, rng)
	return picked


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## 阵容是否合法（选定时再查一次）
static func lineup_ok(key: String, lineup: Array) -> bool:
	var d := difficulty(key)
	if d.is_empty() or lineup.size() != LINEUP_SIZE:
		return false
	var p := pool(key)
	var all: Array = p[XTier.WEAK] + p[XTier.STRONG] + p[XTier.SUPER]
	var seen := {}
	var weak := 0
	var supers := 0
	for id in lineup:
		if not all.has(int(id)) or seen.has(int(id)):
			return false
		seen[int(id)] = true
		weak += 1 if XTier.is_weak(id) else 0
		supers += 1 if XTier.is_super(id) else 0
	return weak >= int(d.min_weak) and supers <= int(d.super_cap)


# ---- 开新档 ----

## 建新局并把开局指令放进待跑：存档位 slot（1～10）、难度 key、阵容 lineup（第一个是 1 号位）。
## 之后切到地图场景，地图场景在大厅里先跑完这份指令再放玩家走。
static func start_new_game(slot: int, key: String, lineup: Array) -> XState:
	var s := XState.new_game_blank()
	s.map_id = HALL_MAP
	s.x = HALL_POS.x
	s.y = HALL_POS.y
	s.direction = HALL_POS.z
	s.flags["tianqi"] = {"rules": RULES_VERSION, "difficulty": key, "lineup": lineup.map(func(v): return int(v))}
	_pending = opening_commands(slot, key, lineup)
	return s


## 地图场景开图后取一次（没有为空）
static func take_pending() -> Array:
	var out := _pending
	_pending = []
	return out


static func has_pending() -> bool:
	return not _pending.is_empty()


## 原版开局三张图留下的状态，按原版顺序拼成事件指令（对话、选项、场所移动、教派、号角不要）。
static func opening_commands(slot: int, key: String, lineup: Array) -> Array:
	var legacy := legacy_of(key)
	var c := []
	# Map001 EV1：新存档、Hand、存档位、西游模式与其清零的变量
	c.append(_script("$gameParty.DCultyL1 = true;"))
	c.append(_sw(166, true))
	c.append(_sw(18, true))
	c.append(_sw(161 + slot - 1 if slot <= 5 else 276 + slot - 6, true))
	for i in range(1, 9):
		c.append(_script("$gameParty.DCultyL%d = %s;" % [i, "true" if i == 1 else "false"]))
	c.append(_sw(682, true))
	for v in [1496, 1497, 1491, 1547, 1552, 1553, 1554, 1555, 1556]:
		c.append(_var(v, 0))
	# 天道使者的规则（技能等级上限 8、抽奖被动上限 5、禁矿工装备、天道枷锁、高难度）：数值批再定，先照原版
	c.append(_var(8, 8))
	c.append(_var(9, 5))
	c.append(_var(12, 1))
	c.append(_var(13, 1))
	c.append(_var(14, 1))
	c.append_array(_legacy_difficulty(legacy))
	# Map002 EV2 第 1 页：预掷池、阎王剧情做完
	c.append_array(_lines([
		"",
		"$gameParty.RomGet = $gameParty.RomGet || [];",
		"$gameParty.RomGetNum = $gameParty.RomGetNum || 0;",
		"if($gameParty.RomGet.length < 35 ){",
		"for(var i = 0;i < 35;i++){",
		"$gameParty.RomGet[i] = Math.floor(Math.random() * 9999) + 1;",
		"};",
		"$gameParty.RomGetNum = 0;",
		"};"]))
	for id in [2, 683, 3, 4, 5, 6]:
		c.append(_sw(id, true))
	# Map002 EV2 第 4 页：入队（随机阵容取代所选英雄与修、罗琳、美娜）、初始化
	c.append(_sw(15, true))
	for id in lineup:
		c.append({"code": 129, "indent": 0, "parameters": [int(id), 0, false]})
	for ce in [50, 407, 408, 409, 812, 822, 1097]:
		c.append({"code": 117, "indent": 0, "parameters": [ce]})
	c.append(_sw(14, true))
	c.append(_sw(2224, false))
	c.append(_var(20, 1))
	for v in [1191, 1192, 1193, 1194, 1195]:
		c.append(_rand(v, -900, 900))
	c.append(_rand(1196, 1, 5))
	for v in [1241, 1242, 1243, 1244, 1245]:
		c.append(_rand(v, -8000, 8000))
	c.append(_rand(1246, 1, 5))
	c.append(_rand(1247, 0, 5))
	# 原版这里进教派选择（Map221），雕像给指路灯与难度修正后进大厅；教派删了，物品照给
	c.append(_item(4, 1))
	c.append(_item(2896, 1))
	for ce in [839, 1319, 1322, 1328]:
		c.append({"code": 117, "indent": 0, "parameters": [ce]})
	# 原版开局英雄在大厅 EV020 学「万众一心」「SupperStar」，天启篇给 1 号位
	if not lineup.is_empty():
		for sid in [2571, 2786]:
			c.append({"code": 318, "indent": 0, "parameters": [0, int(lineup[0]), 0, sid]})
	# 引路人问道号（原版 Map001 的名字，存在 $gamePlayer.SaveActorName，称号牌上显示）
	c.append_array(_say("你终于来了。这里是方桌大厅，往后每一次出发，都从这里开始。"))
	c.append_array(_say("在出发之前……该怎么称呼你？"))
	c.append(_script("$gamePlayer.SaveActorName = prompt(\"请输入你的道号\",\"\");"))
	c.append_array(_say("记住了。去吧，塔就在前面。"))
	c.append({"code": 0, "indent": 0, "parameters": []})
	return c


## Map001 选难度的五个分支（宝宝分支不用），去掉提示文字
static func _legacy_difficulty(legacy: int) -> Array:
	var c := []
	c.append({"code": 356, "indent": 0, "parameters": ["Difficulty SetID %d" % legacy]})
	for i in range(1, 9):
		c.append(_script("$gameParty.DCultyL%d = %s;" % [i, "true" if i == legacy else "false"]))
	match legacy:
		2:
			c.append(_sw(2492, true))
			c.append(_var(1491, 1))
			c.append(_item(1639, 100))
			c.append(_item(2530, 150))
			c.append_array(_learn_all(5980))
		3:
			c.append(_sw(2491, true))
			c.append(_var(1491, 1))
			c.append_array(_learn_all(5980))
		4:
			c.append(_var(1491, 2))
			c.append({"code": 122, "indent": 0, "parameters": [9, 9, 1, 0, 5]})
			c.append(_sw(2500, true))
			c.append(_sw(2490, true))
			c.append(_sw(2497, true))
			c.append(_item(1395, 1))
			c.append(_item(1639, 100))
			c.append(_sw(2485, true))
			c.append_array(_learn_all(5980))
		5:
			c.append(_var(1491, 3))
			c.append({"code": 122, "indent": 0, "parameters": [9, 9, 1, 0, 8]})
			c.append(_sw(2494, true))
			c.append(_sw(2493, true))
			c.append(_item(1395, 1))
			c.append(_item(1396, 1))
			c.append(_item(1639, 100))
			c.append(_sw(2486, true))
		6:
			c.append(_var(1491, 5))
			c.append(_sw(2493, true))
			c.append({"code": 122, "indent": 0, "parameters": [9, 9, 1, 0, 12]})
			c.append(_sw(2489, true))
			c.append(_item(1395, 1))
			c.append(_item(1396, 1))
			c.append(_item(1397, 1))
			c.append(_item(1639, 100))
			c.append(_sw(2486, true))
			c.append(_sw(2461, true))
			c.append({"code": 117, "indent": 0, "parameters": [1443]})
	return c


static func _learn_all(skill: int) -> Array:
	return _lines(["for (var j = 1; j < $dataActors.length; j++) {", "if($dataActors[j].name != ''){",
		"$gameActors.actor(j).learnSkill(%d);" % skill, "}", "}"])


static func _sw(id: int, on: bool) -> Dictionary:
	return {"code": 121, "indent": 0, "parameters": [id, id, 0 if on else 1]}


static func _var(id: int, v: int) -> Dictionary:
	return {"code": 122, "indent": 0, "parameters": [id, id, 0, 0, v]}


static func _rand(id: int, lo: int, hi: int) -> Dictionary:
	return {"code": 122, "indent": 0, "parameters": [id, id, 0, 2, lo, hi]}


static func _item(id: int, n: int) -> Dictionary:
	return {"code": 126, "indent": 0, "parameters": [id, 0, 0, n]}


static func _script(line: String) -> Dictionary:
	return {"code": 355, "indent": 0, "parameters": [line]}


## 多行脚本：第一行 355，其余 655（与原版事件同样的分行）
static func _lines(lines: Array) -> Array:
	var out := []
	for i in lines.size():
		out.append({"code": 355 if i == 0 else 655, "indent": 0, "parameters": [lines[i]]})
	return out


static func _say(text: String) -> Array:
	return [{"code": 101, "indent": 0, "parameters": ["", 0, 0, 2, ""]},
		{"code": 401, "indent": 0, "parameters": ["\\n<%s>%s" % [GUIDE_NAME, text]]}]


## 出战栏里真正上场的格数：天启篇 4，原版档整栏 5
static func fighter_slots(s) -> int:
	return FIGHTERS if active(s) else XState.MAX_BATTLE_MEMBERS


# ---- 通关抽角色（第二批） ----

## 已通关层数：变量 20「神魔之塔层数」是当前所在层（开局 1），减 1
static func cleared_floors(s: XState) -> int:
	return maxi(0, int(s.variable(20)) - 1)


static func draws_earned(s: XState) -> int:
	return mini(DRAW_MAX, cleared_floors(s) / DRAW_EVERY)


static func draws_used(s: XState) -> int:
	return int(s.flags.tianqi.get("draws", 0)) if active(s) else 0


## 第 n 次（0 起）抽的规则 {tiers, count}；count 0＝自选
static func draw_rule(s: XState, n: int) -> Dictionary:
	var rows: Array = DRAW_TABLE.get(str(s.flags.tianqi.get("difficulty", "")), []) if active(s) else []
	if n < 0 or n >= rows.size():
		return {}
	return {"tiers": rows[n][0], "count": int(rows[n][1])}


## 本局还没有的、档位在 tiers 里的角色（停用的导入角色不出）
static func draw_pool(s: XState, tiers: Array) -> Array:
	var out := []
	for tier in tiers:
		for id in XTier.ids(tier):
			if not XImportedBalance.is_disabled_actor(id) and not s.party.has(id) and not s.saved_actors.has(id):
				out.append(id)
	return out


## 现在能抽：有没用掉的次数，且候选不空
static func draw_ready(s: XState) -> bool:
	if not active(s) or not NO_RECRUIT or draws_used(s) >= draws_earned(s):
		return false
	var r := draw_rule(s, draws_used(s))
	return not r.is_empty() and not draw_pool(s, r.tiers).is_empty()


## 这一次的候选：X 选一掷一次就记进存档（flags.tianqi.offer），没选之前再来也是这几个（不能重抽）；自选给整池
static func draw_offer(s: XState, rng: RandomNumberGenerator = null) -> Array:
	var r := draw_rule(s, draws_used(s))
	if r.is_empty():
		return []
	var pool := draw_pool(s, r.tiers)
	if int(r.count) <= 0:
		return pool
	var saved = s.flags.tianqi.get("offer")
	if saved is Array and not saved.is_empty() and saved.all(func(id): return pool.has(int(id))):
		return saved.map(func(id): return int(id))
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_shuffle(pool, rng)
	var offer := pool.slice(0, int(r.count))
	s.flags.tianqi["offer"] = offer
	return offer


## 选定：在候选里才收，入队、记一次、清候选
static func take_draw(s: XState, id: int) -> bool:
	if not draw_ready(s) or not draw_offer(s).has(id):
		return false
	_joining = true
	s.add_actor(id)
	_joining = false
	s.flags.tianqi["draws"] = draws_used(s) + 1
	s.flags.tianqi.erase("offer")
	return s.party.has(id)


## NO_RECRUIT 下新角色能不能入队：已在队、开局阵容、正在抽的才行
static func join_allowed(s: XState, id: int) -> bool:
	if not active(s) or not NO_RECRUIT or s.party.has(id) or _joining:
		return true
	return s.flags.tianqi.get("lineup", []).has(id)


## 号角（能招人的物品）：天启篇 NO_RECRUIT 下拿不到、不上架
static func horn_blocked(s: XState, rec: Dictionary) -> bool:
	return active(s) and NO_RECRUIT and XItemMarks.recruit_actor_id(rec) > 0


const JOIN_BLOCKED_NOTICE := "天启篇的伙伴只从方桌大厅的通关招募来。"
const DRAW_SPEAKER := "小小鱼"


static func _actor_label(id: int) -> String:
	return "%s【%s】" % [str(XDB.rec("Actors", id).get("name", "")), XTier.tier_of(id)]


static func _line(text: String) -> Array:
	return ["\\n<%s>%s" % [DRAW_SPEAKER, text]]


## 大厅抽角色的对话（地图场景在大厅里、没有别的事件时调）：一次把能抽的都走完，玩家可以「稍后再选」留到下次回大厅
static func run_draw(host, s: XState) -> void:
	while draw_ready(s):
		var r := draw_rule(s, draws_used(s))
		var offer := draw_offer(s)
		var head := "你已通关 %d 层，可以招募一名新伙伴（%s）。" % [cleared_floors(s), "／".join(r.tiers)]
		var pick := 0
		if int(r.count) == 1:
			await host.show_text("", 0, _line(head + "来的是……"))
			pick = int(offer[0])
		elif int(r.count) > 1:
			var opts := offer.map(func(id): return _actor_label(int(id)))
			opts.append("稍后再选")
			var i: int = await host.show_text_with_choices("", 0, _line(head + "这几位愿意跟你走，选一位吧。"), opts, opts.size() - 1)
			if i < 0 or i >= offer.size():
				return
			pick = int(offer[i])
		else:
			pick = await _pick_free(host, s, r.tiers, head)
			if pick <= 0:
				return
		if not take_draw(s, pick):
			return
		await host.show_text("", 0, _line("%s加入了队伍。" % _actor_label(pick)))


## 自选：先选档位，再从该档位本局还没有的角色里选；取消回上一步，最外层取消＝稍后再选
static func _pick_free(host, s: XState, tiers: Array, head: String) -> int:
	while true:
		var have := tiers.filter(func(t): return not draw_pool(s, [t]).is_empty())
		var opts := have.duplicate()
		opts.append("稍后再选")
		var t: int = await host.show_text_with_choices("", 0, _line(head + "这一次你可以自己挑。"), opts, opts.size() - 1)
		if t < 0 or t >= have.size():
			return 0
		var pool := draw_pool(s, [have[t]])
		var names := pool.map(func(id): return _actor_label(int(id)))
		names.append("返回")
		var i: int = await host.show_text_with_choices("", 0, _line("想要哪一位？"), names, names.size() - 1)
		if i >= 0 and i < pool.size():
			return int(pool[i])
	return 0


# ---- 选线（Kyo 11-11「选线做成单独的大厅内事件」；四线剧情与关卡设计稿 v0.4 第 2 节，已确认） ----
## 第一次通关第 5 层、回到大厅抽完角色后，小小鱼在方桌主持选线；选了不能换；没选线时 6 层的门不开（XTianqiLine.door_blocked）。
## 四张卡（XTianqiLineCards）：骑士剪影＋一句话＋它会怎样改变战斗＋考什么；选中一张小小鱼补一句，二次确认后写 flags.tianqi.line。
## 只有做好了内容的线能选（line_playable）：XTianqiLine.KEYS 里的线（战争 cc/pro-tianqi-war、饥荒），别的线卡片照列、标「还没修好」。
## 开关（O-280）：LINE_EVENT_OPEN＝false 时大厅不出这个事件、门也不锁（回到第三批之前）。战争线做好后打开（cc/pro-tianqi-war）。
static var LINE_EVENT_OPEN := true
## 选定后能不能再换（Kyo 11-11 09:32 已确认：不能换）
static var LINE_CHANGEABLE := false
## 第一次通关第几层后出选线（已确认：5 层）
const LINE_FLOOR := 5
## 四条线（骑士与原身 Kyo 已定；卡面文字照设计稿 v0.4 第 2.2 节）
const LINES := [
	{"key": "war", "name": "战争", "knight": "莉co", "pick": "「烟火大会，开始啦！」",
		"change": "敌人属性更高，会再动；火花攒满时一起动", "test": "清场：在下一波之前清掉场面",
		"guide": "这个……会让敌人一直动。很吵。"},
	{"key": "death", "name": "死亡", "knight": "勇者", "pick": "「现在一切结束了。」",
		"change": "有人会被挂上死期，这回合结束时必死", "test": "速度：尽快结束战斗",
		"guide": "这个……会有人突然死掉。你看得见是谁。"},
	{"key": "plague", "name": "瘟疫", "knight": "混子", "pick": "「不服来打我。」",
		"change": "中毒、混乱叠满身，减益越多人越虚", "test": "底子：属性和抗性够不够厚",
		"guide": "这个……会让人生病。一直病。"},
	{"key": "famine", "name": "饥荒", "knight": "小镇做题家", "pick": "「噫~我中了！」",
		"change": "技能更贵、回复更少，不花资源的技能也要交口粮", "test": "储备：开场那份资源怎么花",
		"guide": "这个会让人……很饿。"},
]


static func line_info(key: String) -> Dictionary:
	for l in LINES:
		if l.key == key:
			return l
	return {}


## 这条线的内容做好了、能选
static func line_playable(key: String) -> bool:
	return XTianqiLine.playable(key)


## 本档选的线（没选为空串；不是天启篇存档也为空）
static func line_of(s: XState) -> String:
	return str(s.flags.tianqi.get("line", "")) if active(s) else ""


## 大厅现在该不该出选线事件：开关开着、天启篇存档（发行构建里还要天启篇已开放）、通关过 5 层、还没选（或允许换）、有能选的线
static func line_ready(s: XState) -> bool:
	return LINE_EVENT_OPEN and active(s) and (RELEASE_OPEN or not ReleaseEntry.is_release()) \
		and cleared_floors(s) >= LINE_FLOOR and (line_of(s) == "" or LINE_CHANGEABLE) \
		and LINES.any(func(l): return line_playable(str(l.key)))


## 选定一条线；不认识的线、没做好的线、或已选且不许换时不收
static func choose_line(s: XState, key: String) -> bool:
	if not active(s) or line_info(key).is_empty() or not line_playable(key):
		return false
	if line_of(s) != "" and not LINE_CHANGEABLE:
		return false
	s.flags.tianqi["line"] = key
	return true


static func _card_text(l: Dictionary) -> String:
	return "%s·%s　%s\n它会怎样改变战斗：%s\n考什么：%s" % [l.name, l.knight, l.pick, l.change, l.test]


## 大厅选线对话（地图场景在大厅里、抽完角色后调）：「再想想」留到下次回大厅；选定后接着跑本线开场
static func run_line_choice(host, s: XState) -> void:
	while line_ready(s):
		var i: int
		# 四张竖卡（XTianqiLineCards，地图场景的 pick_line；XTianqiLook.CARDS 关掉或没有画面时回到对话框选项）
		var cards: bool = XTianqiLook.CARDS and host.has_method("pick_line")
		if cards:
			i = await host.pick_line(LINES, LINES.map(func(l): return line_playable(str(l.key))))
		else:
			var opts := LINES.map(func(l): return "%s·%s　%s" % [l.name, l.knight, l.pick])
			opts.append("再想想")
			var head := "方桌的裂纹裂成了四块，每一块里都映着一位骑士。你要踏上哪一条路？"
			i = await host.show_text_with_choices("", 0, _line(head), opts, opts.size() - 1)
		if i < 0 or i >= LINES.size():
			return
		var l: Dictionary = LINES[i]
		if not cards:
			await host.show_text("", 0, [_card_text(l)])
		await host.show_text("", 0, _line(str(l.guide)))
		if not line_playable(str(l.key)):
			await host.show_text("", 0, _line("……这条路还没修好。换一条吧。"))
			continue
		var sure: int = await host.show_text_with_choices("", 0, _line("选定后这个存档不能再换。确定走%s之路吗？" % l.name), ["确定", "再想想"], 1)
		if sure != 0:
			continue
		if choose_line(s, str(l.key)):
			await XTianqiLine.on_chosen(host, s, str(l.key))
			return
