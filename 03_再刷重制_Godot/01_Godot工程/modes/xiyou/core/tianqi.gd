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
## 开关（Kyo 11-11「关」；四线异化 v0.8 第 2.3 节）：true＝天启篇存档不出原版的 1% 异化遭遇（XAlienBattle.setup_encounter），
## 异化只走天启篇自己的按段异化和各线预设，免得同一只怪生命加成叠两次；false＝照原版。西游档、发行版不受影响。
static var NO_LEGACY_ALIEN := true
## 开关（同上）：true＝天启篇存档里怪物不变「【神话】」（EliteEnemy：能力 ×3.5、经验金钱 ×1.2、掉率 ×5、放大偏色）；
## 照原版照样掷一次（随机流不变），掷中了也当普通怪。false＝照原版。
static var NO_MYTH := true
## 开关（O-待定）：true＝装备重铸、锁词条重铸、异化词条兜底和重抽、通关抽角色候选的随机由存档种子派生
## （存档种子＋对象标识＋该对象随存档的次数，见 save_roll），先存档再掷、读档再掷结果相同；false＝回到全局随机（可读档重掷）
static var SEED_FROM_SAVE := true


## 存档派生的随机流：种子＝存档种子 orb_seed（随存档；更老的档由存档内容算出，XState.from_dict）＋ key。
## key 由调用方给：对象标识＋该对象的次数（计数随存档，调用方负责推进），同一次操作读档后种子相同，不同次、不同对象各自独立
static func save_stream(s: XState, key: String) -> XRandomStream:
	return XRandomStream.create(XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tianqi|" + key), "tianqi_save")


## 同上，包成返回 [0,1) 的 Callable（重铸、异化用）；开关关着或没有存档时回到全局 randf
static func save_roll(s: XState, key: String) -> Callable:
	if s == null or not SEED_FROM_SAVE:
		return func(): return randf()
	var st := save_stream(s, key)
	return func(): return st.next_float(key)


## 装备的随机身份 tq_seed_id：写在装备字典上随物品走，一经分配永不重编（instanceId、异化 uid 会在星辰仓库取出等路径上重编，
## 不能直接当随机身份）。号只取决于这件装备和本档存档种子，与先洗哪件、什么时候洗无关：
##   - 入包登记时（XState.register_gear，天启篇存档里所有产生装备的入口都经它）立刻分配，分两类：
##     ① 来源本身读档稳定的入口传来源键 source（固定货单商店、事件赠送、号角专属装备、招牌掉落、净印／遗物、七印揭开与神器、
##        天启篇商人、深渊商人、合成），号＝derive(orb_seed, "tq_seed_src|" + source + "|" + 本档该来源键的第几件)，
##        计数在 flags.tianqi.src_n[source]，只看同一来源，先拿别的来源的装备不影响它；
##     ② 来源本身随运行时随机的（普通战斗掉落等）不传，号＝derive(orb_seed, "tq_seed_id|" + instanceId)。这一类掉什么本来就随
##        运行时战斗流变，「普通掉落是否抗读档」是上层问题，不在这里。
##   - 读档（XState.from_dict 末尾）和新开天启篇档时 assign_all 给还没号的老件一次性补号，遍历顺序写死：
##     背包 s.gear（列表顺序）→ 身上（角色号从小到大，每人 raw_equip_list 顺序）→ 各仓库（仓库名排序，类别按 XWarehouse.CATEGORIES，列表顺序）。
##     已有号的不动；新派生的号和已有号撞了（只有原版仓库复制那种同 instanceId 的复制品会撞）就按这个顺序加后缀，结果只取决于存档内容。
##   - 星辰仓库（跨存档）取出的老件在重编 instanceId 之前补号（before_renumber），号用旧 instanceId＋整件内容派生，与取出顺序无关。
## 复制装备的合法路径（魔冠账本重发、云裳订单发货、仓库原版复制）在复制时去掉它，复制品重新登记时另拿新号。
static func seeds_on(s: XState) -> bool:
	return s != null and SEED_FROM_SAVE and active(s)


static func _derive_seed_id(s: XState, who: String) -> String:
	return XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tq_seed_id|" + who)


static func _who(item: Dictionary) -> String:
	var iid := str(item.get("instanceId", ""))
	return iid if iid != "" else "noid|%d" % hash(JSON.stringify(item))


static func has_seed_id(item) -> bool:
	return item is Dictionary and XRandomStream.valid_hex(str(item.get("tq_seed_id", "")))


## 入包登记时调（XState.register_gear）；source 见上
static func on_register(s: XState, item: Dictionary, source := "") -> void:
	if not seeds_on(s) or has_seed_id(item):
		return
	if source == "":
		item["tq_seed_id"] = _derive_seed_id(s, _who(item))
		return
	var tq: Dictionary = s.flags.tianqi
	if not tq.get("src_n") is Dictionary:
		tq["src_n"] = {}
	var n := int(tq.src_n.get(source, 0))
	tq.src_n[source] = n + 1
	item["tq_seed_id"] = XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tq_seed_src|%s|%d" % [source, n])


## 星辰仓库取出、重编 instanceId 之前调：没号的老件用旧 instanceId＋整件内容补号
static func before_renumber(s: XState, item: Dictionary) -> void:
	if seeds_on(s) and not has_seed_id(item):
		item["tq_seed_id"] = _derive_seed_id(s, "star|%s|%d" % [str(item.get("instanceId", "")), hash(JSON.stringify(item))])


## 本档全部装备，按补号的固定顺序（见上）
static func all_gear(s: XState) -> Array:
	var out: Array = s.gear.filter(func(e): return e is Dictionary)
	var ids := s.actors.keys()
	ids.sort()
	for id in ids:
		for e in s.actors[id].raw_equip_list():
			if e is Dictionary:
				out.append(e)
	var titles := s.warehouses.keys()
	titles.sort()
	for title in titles:
		var items = s.warehouses[title].get("items", {})
		for cat in XWarehouse.CATEGORIES:
			for e in (items.get(cat, []) if items is Dictionary else []):
				if e is Dictionary:
					out.append(e)
	return out


## 给本档还没号的装备补号（读档、新开档时）；已有号的不动
static func assign_all(s: XState) -> void:
	if not seeds_on(s):
		return
	var list := all_gear(s)
	var used := {}
	for e in list:
		if has_seed_id(e):
			used[str(e.tq_seed_id)] = true
	for e in list:
		if has_seed_id(e):  # 同一件出现两次（不该有）时第二次已有号，跳过
			continue
		var who := _who(e)
		var id := _derive_seed_id(s, who)
		var k := 1
		while used.has(id):
			k += 1
			id = _derive_seed_id(s, "%s|%d" % [who, k])
		e["tq_seed_id"] = id
		used[id] = true


## 掷的时候取号；正常都已在登记／读档时分好，没有的（没经登记的装备）先整档补一遍再取
static func seed_id(s: XState, item: Dictionary) -> String:
	if not has_seed_id(item):
		assign_all(s)
	if not has_seed_id(item):
		item["tq_seed_id"] = _derive_seed_id(s, _who(item))
	return str(item.tq_seed_id)


## 装备的存档派生流：种子＝随机身份 tq_seed_id＋domain＋装备上的次数 tq_rng_n（随装备存进存档；老装备没有当 0），
## 每开一条计数 +1。流只看装备自己带的东西，存进仓库再取出、换存档都还是那一串。
## 开关关着时不写装备、返回全局 randf
static func item_roll(s: XState, item: Dictionary, domain: String) -> Callable:
	if s == null or not SEED_FROM_SAVE:
		return func(): return randf()
	var id := seed_id(s, item)
	var n := int(item.get("tq_rng_n", 0))
	item["tq_rng_n"] = n + 1
	var key := "%s|%d" % [domain, n]
	var st := XRandomStream.create(XRandomStream.derive(id, "tianqi_item|" + key), "tianqi_item")
	return func(): return st.next_float(key)

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


## 这一档不出原版 1% 异化遭遇
static func legacy_alien_off(s: XState) -> bool:
	return NO_LEGACY_ALIEN and active(s)


## 这一档不出「神话」：掷中了也改回普通怪（能力值、经验、金钱、掉率、图像都按普通算），回满
static func strip_myth(e: XEnemy, s: XState) -> void:
	if not NO_MYTH or not active(s) or e == null or not e.elite:
		return
	e.elite = false
	e.elite_hue = 0.0
	e.refresh_passive()
	e.recover_all()


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
		for id in XTianqiSkills.ids(tier, true):
			if not _disabled(id):
				out[tier].append(id)
	return out


## 候选池里停用的角色；五条悟只看最强之名解锁没有（开新局时当前存档还不是天启篇，XGojo.hidden 不作数）
static func _disabled(id: int) -> bool:
	return XGojo.locked(id) if id == XGojo.ACTOR else XImportedBalance.is_disabled_actor(id)


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
		if XTianqiSkills.is_super(id, true):
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
		weak += 1 if XTianqiSkills.is_weak(id, true) else 0
		supers += 1 if XTianqiSkills.is_super(id, true) else 0
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
	XTianqiNoDiffPassive.mark_new_game(s)  # 开局不发难度被动：记迁移标记，关开关读档能补回（O-421）
	XTianqiGojoTrial.mark_table(s)  # 五条悟两阶进阶：新档一开始就记进阶表版本，读档不当旧四阶折半
	_pending = opening_commands(slot, key, lineup)
	assign_all(s)  # 装备随机身份（seed_id）
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
	var lottery := int(XTianqiBalance.route(key).get("lottery_cap", 0)) if XTianqiTrim.ROUTE_TABLE else 0
	if lottery > 0:
		c.append(_var(9, lottery))  # 抽奖被动上限按吸收的旧路线（O-412；_legacy_difficulty 之后写，盖过借来的难度加的数）
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
	c.append_array(XTianqiSect.opening_commands())  # 大厅两位使者撤了：他们送的副本协会控制器、牛马关指路灯改开局给（XTianqiSect 包甲）
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
		for id in XTianqiSkills.ids(tier, true):
			if not _disabled(id) and not s.party.has(id) and not s.saved_actors.has(id):
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
		if SEED_FROM_SAVE:  # 存档派生：第几次抽（draws 随存档）定种子，没选之前读档也是这几个（O-待定）
			rng.seed = XRandomStream.parse64(XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tianqi|offer|%d" % draws_used(s)))
		else:
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
	return "%s【%s】" % [str(XDB.rec("Actors", id).get("name", "")), XTianqiSkills.tier_of(id, true)]


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
## 四张卡（XTianqiLineCards）：骑士剪影＋一句话＋传闻＋本线特点；选中一张小小鱼补一句，二次确认后写 flags.tianqi.line。
## 只有做好了内容的线能选（line_playable）：XTianqiLine.KEYS 里的线（战争 cc/pro-tianqi-war、饥荒），别的线卡片照列、标「还没修好」。
## 开关（O-280）：LINE_EVENT_OPEN＝false 时大厅不出这个事件、门也不锁（回到第三批之前）。战争线做好后打开（cc/pro-tianqi-war）。
static var LINE_EVENT_OPEN := true
## 选定后能不能再换（Kyo 11-11 09:32 已确认：不能换）
static var LINE_CHANGEABLE := false
## 第一次通关第几层后出选线（已确认：5 层）
const LINE_FLOOR := 5
## 四条线（骑士与原身 Kyo 已定；卡面文字原照设计稿 v0.4 第 2.2 节，Kyo 11-13 改写：本线特点＋传闻（骑士来历，取四线设计稿第 4 节各线一句话）；test 键沿用，内容是传闻）
const LINES := [
	{"key": "war", "name": "战争", "knight": "莉co", "pick": "「烟火大会，开始啦！」",
		"change": "「火花」异化怪每次行动积攒火花，积满时全体再动一轮。", "test": "她把战场当成烟火大会。\n一旦点燃，便不再停歇。",
		"guide": "这个……会让敌人一直动。很吵。"},
	{"key": "death", "name": "死亡", "knight": "勇者", "pick": "「现在一切结束了。」",
		"change": "「死期」每回合宣判一人，回合结束时，此人必死。", "test": "做了十几年替身，仍未转正。\n如今，他来收尾。",
		"guide": "这个……会有人突然死掉。你看得见是谁。"},
	{"key": "plague", "name": "瘟疫", "knight": "混子", "pick": "「不服来打我。」",
		"change": "「病灶」我方不断染上减益，越积越虚弱，积满时爆发。", "test": "他最爱说「不服来打我」。\n后来，这句话成了一种病。",
		"guide": "这个……会让人生病。一直病。"},
	{"key": "famine", "name": "饥荒", "knight": "小镇做题家", "pick": "「噫~我中了！」",
		"change": "「饥饿」技能消耗更高、回复更少，口粮比什么都重要。", "test": "一心刷题、没钱修仙的孩子。\n如今，他怎么也吃不饱。",
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
	return "%s·%s　%s\n传闻：%s\n本线特点：%s" % [l.name, l.knight, l.pick, str(l.test).replace("\n", ""), l.change]  # 传闻在卡上分两行，对话框里接成一句


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
