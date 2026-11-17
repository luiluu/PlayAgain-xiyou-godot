class_name XTianqiGear
extends RefCounted
## 天启篇第③步：装备栏（数值重构方案第八节第 9 条，Kyo 2026-11-08 14:36／14:39／14:42／14:43；神器栏 Kyo 2026-11-11 00:23）。
## 只在天启篇存档生效（XTianqi.active：flags.tianqi 规则版本），原版开局建的档、测试直接建的状态照原版 19 栏。
##
## 13 个栏位，排列（Kyo 14:42 采纳）：武器、副手｜头部、盔甲、护手、腰带、裤子、鞋子｜项链、戒指｜法宝、坐骑｜神器。
## - 戒指只有 1 个（原版本来就只有一个戒指类型 10）。
## - 删掉宝物 11、护符 12、灵兽 14、圣器 15、宝宝 18、形态 19：不显示、不能装；身上已有的卸回背包，开局自带的（天虎令、长崎爽世、椎名立希）直接不装。
## - 神器（Kyo 11-11 加的第 13 栏）：放独特物件，沿用原神武的装备类型 17，只认 ARTIFACTS 白名单；原神武里不在名单上的（黎明—破晓、禁锢之皇冕）不能装。
##   法宝因此只剩通用、专属两类（专属靠 <req_actors> 挡别人，原有判定）。
## - 坐骑：难度适应 1691 开战封印坐骑（特性 54 → 16）不再沿用（方案第八节第 9 条）；1691 对圣器、宝宝、形态的封印随栏位删除失效。
##
## 删除栏位上的软绑定（删除栏位角色专属物清单 v0.1，Kyo 11-11 00:04「根据你的建议来」）：
## - 茉蕾：觉醒（1752）时学「嘤雄」（沿用 6242 究极嘤雄的技能号，动作序列里 _skills.includes(6242) 那 3 段只算一次），
##   入队学「强化·嘤嘤嘤」2797（只留一档）。
## - 宇智波·鼬：入队学「通灵·乌鸦」7475，天启篇里补成生效的被动，不要求装备乌鸦。
## - 小龙人加段、渡鸦旧档配方、开局自带装：不迁移（栏位删了自然失效）。
## 两个被动的增伤是占位（SOFT_PASSIVES 里的 rate），档位数值那一步按标准线重标；嘤雄改名和说明都只在天启篇的技能视图里换，原版数据不动。

## 开关（O-266）：true＝天启篇存档按 13 栏；false＝天启篇存档也照原版 19 栏（含软绑定被动、坐骑封印）。
static var ENABLED := true

const MOUNT := 16
const ARTIFACT := 17
const ARTIFACT_NAME := "神器"
## 天启篇栏位排列（装备类型号）；装备数组照旧 19 格、按原槽位存（存档格式不变），这里只决定显示哪些、按什么顺序。
const ORDER := [1, 2, 3, 4, 6, 8, 5, 7, 9, 10, 13, 16, 17]
## 神器栏白名单（Armors 编号）：五件成长物（心之钢、杰作利维坦、狂妄、杰作无我、"头顶"）＋三件玩家纪念物（仙道模式两版、神魔战纹、游戏王的嘴炮）。
## 纪念物效果到设计神器时重做；成长物的成长上限在档位数值那一步加。
const ARTIFACTS := [7900, 7901, 7902, 7903, 7940, 4279, 5198, 4536, 4538]

const MOLEI := 7
const MOLEI_AWAKEN := 1752
const ITACHI := 91
## 天启篇给的技能：角色 → [[技能, 学会时机（0＝入队，否则学会该技能时）], …]
const GRANTS := {MOLEI: [[2797, 0], [6242, MOLEI_AWAKEN]], ITACHI: [[7475, 0]]}
## 软绑定被动在天启篇的技能视图（占位数值：Kyo 数值规则，整数、不带 4）
const SOFT_PASSIVES := {
	6242: {"name": "嘤雄", "skills": [3518, 4774, 4775], "rate": 100,
		"text": "茉蕾的「一袋米扛几楼」和「一桶油喝几斤」额外增加三段伤害，伤害+%d%%",
		"desc": "嘤嘤怪的力量已经化为茉蕾自己的本事。"},
	7475: {"name": "", "skills": [7465, 7466, 7467, 7471, 7472, 7473], "rate": 100,
		"text": "独特技能增伤+%d%%", "desc": ""},
}


static func on(s: XState = null) -> bool:
	if not ENABLED:
		return false
	return XTianqi.active(s if s != null else XState.current)


## 这个装备类型的栏位在天启篇还在
static func open_type(etype: int) -> bool:
	return not on() or ORDER.has(etype)


## 栏位名：天启篇里类型 17 叫神器
static func type_name(etype: int) -> String:
	if etype == ARTIFACT and on():
		return ARTIFACT_NAME
	var types: Array = XDB.system().get("equipTypes", [])
	return str(types[etype]) if etype >= 0 and etype < types.size() else ""


## 显示用的槽位（槽位序号的列表，按天启篇排列；不是天启篇就是 0..n-1）
## 槽位序号 → 原装备类型（和 view 同源：双持时第 2 格照旧算副手 2；178 哈基米没有副手，槽 1 起是类型 3…）
static func base_types(a: XActor) -> Array:
	var base := []
	for i in range(a.equip_slots().size() + (1 if XCat.own(a) else 0)):
		base.append(i + 1)
	if XCat.own(a):
		base = base.filter(func(t): return t != 2)
	return base


static func view(a: XActor) -> Array:
	var slots := a.equip_slots()
	var out := []
	if not on():
		for i in range(slots.size()):
			out.append(i)
		return out
	var base := []  # 槽位序号 → 原装备类型（双持时第 2 格类型变成 1，排列仍按副手位置）
	for i in range(slots.size()):
		base.append(i + 1)
	if XCat.own(a):
		base = base.filter(func(t): return t != 2)
	for t in ORDER:
		var i := base.find(t)
		if i >= 0 and i < slots.size():
			out.append(i)
	return out


## 天启篇里这件装备能不能穿（只看栏位与神器白名单；角色、等级等照 can_equip 原判定）
static func allows(item: Dictionary) -> bool:
	if not on() or item.is_empty() or str(item.get("kind", "")) == "weapon":
		return true
	var etype := int(item.get("etypeId", 0))
	if not ORDER.has(etype):
		return false
	return etype != ARTIFACT or ARTIFACTS.has(int(item.get("base", item.get("id", 0)))) or XTianqiRewards.is_relic(item) \
		or str(XTianqiQiyinEffects.mark_of(item).get("kind", "")) == "artifact"  # 骑士遗物、七印神器


## 特性 54 的封印在天启篇不算的：坐骑（难度适应 1691 的封印不再沿用）
static func seal_ignored(etype: int) -> bool:
	return etype == MOUNT and on()


## 角色建好时（XActor.setup 末尾）：天启篇给的入队技能
static func on_setup(a: XActor) -> void:
	if not on():
		return
	for g in GRANTS.get(a.actor_id, []):
		if int(g[1]) == 0 or a.skill_ids.has(int(g[1])):
			a.learn_skill(int(g[0]))


## learn_skill 之后：学会觉醒等时机技能时给对应的技能
static func learned(a: XActor, id: int) -> void:
	if not on():
		return
	for g in GRANTS.get(a.actor_id, []):
		if int(g[1]) == id and not a.skill_ids.has(int(g[0])):
			a.learn_skill(int(g[0]))


## 技能视图（XActor._skill_records）：天启篇里软绑定被动换成生效的版本
static func skill_view(s: Dictionary) -> Dictionary:
	var id := int(s.get("id", 0))
	if not SOFT_PASSIVES.has(id) or not on():
		return s
	var p: Dictionary = SOFT_PASSIVES[id]
	if _views.has(id) and is_same(_views[id][0], s):
		return _views[id][1]
	var v := s.duplicate(true)
	if str(p.name) != "":
		v.name = p.name
	if str(p.desc) != "":
		v.description = "被动\n" + str(p.desc)
	var meta: Dictionary = v.get("meta", {}).duplicate()
	for sid in p.skills:
		meta["SkillPass%04d" % int(sid)] = "%d%%" % int(p.rate)
	v.meta = meta
	# 说明卡读备注里的 <pos=APs text=…>：换成天启篇的效果行
	var note := _APS.sub(str(v.get("note", "")), "", true)
	v.note = note + "<pos=APs text=\\c[1]效果:%s size=18 color=rgba(255,255,255,1) line=false align=0> " % (str(p.text) % int(p.rate))
	_views[id] = [s, v]
	return v

static var _views := {}
static var _APS := RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\]效果:[^>]*>")


# ==== 第二批（交接单「装备栏下一批」，Max 发、Kyo 11-08 规则）：删除栏位物品清理、坐骑管速度先手、神器成长上限 ====
## 三件事都只在天启篇存档生效（on() 为真），原版档、原版对照不变；各一个开关，默认开。
## 数值（坐骑表、神器上限、重抽等级段）在 tianqi_data/gear_table.json，都是占位（draft），不带 4（天启篇数据校验.py 查）。

## A（O-327）：商店不卖删除栏位的防具；随机掉落抽到的换成同品质、同等级段、保留栏位的装备（重抽一次，池空才不给）。
## false＝回到第一批（商店照卖、掉落照给，只是穿不上）。事件、宝箱直接发放的不归这里管（搬图时处理）。
static var CLEAN_DELETED := true
## B（O-328）：坐骑本体只给敏捷百分比与先制几率（按品质查表），原来身上的特性、属性、开战状态在天启篇不算。
## false＝回到第一批（坐骑照原版数据生效，没有表里的加成）。
static var MOUNT_STATS := true
## C（O-329）：心之钢／杰作利维坦、狂妄／杰作无我的阶数、"头顶"的八项加成，算效果时夹上限；存档里的层数、盛名、成长不截。
## false＝回到第一批（无上限，同原版）。
static var ARTIFACT_CAP := true

const TABLE_PATH := "res://modes/xiyou/tianqi_data/gear_table.json"
static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		if XDataFile.missing(TABLE_PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(TABLE_PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiGear: 读不到 " + TABLE_PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_table = parsed
		else:
			push_error("XTianqiGear: JSON 解析失败 " + TABLE_PATH)
	return _table


## 测试用：清掉缓存，下次重新读文件（反向验证改表后用）
static func reload() -> void:
	_table = {}
	_drop_pool = []


# ---- A. 删除栏位的物品不上架、不掉落 ----

## 这件防具（数据库编号）在天启篇的删除栏位上
static func deleted_armor(id: int) -> bool:
	var r := XDB.rec("Armors", id)
	return not r.is_empty() and not ORDER.has(int(r.get("etypeId", 0)))


## Scene_Shop.prepare 外层（XShopStock.prepare_policy 调）：商品表去掉删除栏位的防具。商品 [种类 0 物品／1 武器／2 防具, 编号, 价格类型, 价格]
static func shop_goods(goods: Array) -> Array:
	if not CLEAN_DELETED or not on():
		return goods
	return goods.filter(func(g): return not (int(g[0]) == 2 and deleted_armor(int(g[1]))))


## 重抽的分组：[品质（七档）, 等级段]
static func drop_group(rec: Dictionary) -> Array:
	var band := maxi(1, int(table().get("drop_reroll", {}).get("level_band", 10)))
	return [XQuality.grade(rec), floori(float(int(rec.get("meta", {}).get("req_level", 0))) / band)]


## 能进重抽池的：保留栏位（不含神器栏）、不是专属（<req_actors>）
static func _reroll_ok(kind: int, rec: Dictionary) -> bool:
	if rec.is_empty() or str(rec.get("name", "")) == "":
		return false
	if XEquipment._req_actors_re.search(str(rec.get("note", ""))) != null:
		return false
	if kind == 2:
		return true
	var etype := int(rec.get("etypeId", 0))
	return ORDER.has(etype) and etype != ARTIFACT


## 全部敌人掉落表里出现过的武器、防具 [种类 2／3, 编号]（掉落种类同 dropItems）：重抽只从「本来就会掉的」里挑，不会掉出任务物、专属物
static var _drop_pool: Array = []
static func drop_pool() -> Array:
	if _drop_pool.is_empty():
		var seen := {}
		var enemies = XDB.table("Enemies")
		for e in (enemies if enemies is Array else []):
			if not e is Dictionary:
				continue
			var rows := []
			for d in e.get("dropItems", []):
				if int(d.get("kind", 0)) in [2, 3] and float(d.get("denominator", 0)) > 0:
					rows.append([int(d.kind), int(d.dataId)])
			for x in XBattleLogic._extra_drops(e):
				if int(x.kind) in [2, 3]:
					rows.append([int(x.kind), int(x.id)])
			for r in rows:
				var key := "%d:%d" % r
				if not seen.has(key):
					seen[key] = true
					_drop_pool.append(r)
		_drop_pool.sort()
	return _drop_pool


## 和 rec（删除栏位的防具）同品质、同等级段的保留栏位装备 [[种类, 编号], …]（编号升序，结果可复现）；pool 给数组时代替掉落表（测试用）
static func reroll_pool(rec: Dictionary, pool = null) -> Array:
	var want := drop_group(rec)
	var out := []
	for r in (pool if pool is Array else drop_pool()):
		var other := XDB.rec("Weapons" if int(r[0]) == 2 else "Armors", int(r[1]))
		if _reroll_ok(int(r[0]), other) and drop_group(other) == want and not XTianqiDrop.rare_gear(int(r[0]), int(r[1])):  # T099：低档稀有装备不当替补
			out.append(r)
	return out


## 敌人掉落（XBattleLogic.drops_of，屏蔽掉落之前）：删除栏位的防具在同组里重抽一次（roll 每件取一个 0～1 随机数）；池空就不给
static func reroll_drops(drops: Array, roll: Callable, pool = null) -> Array:
	if not CLEAN_DELETED or not on():
		return drops
	var out := []
	for d in drops:
		if int(d.get("kind", 0)) != 3 or not deleted_armor(int(d.id)):
			out.append(d)
			continue
		var cands := reroll_pool(XDB.rec("Armors", int(d.id)), pool)
		if cands.is_empty():
			continue
		var pick: Array = cands[clampi(floori(float(roll.call()) * cands.size()), 0, cands.size() - 1)]
		var nd: Dictionary = d.duplicate()
		nd.kind = int(pick[0])
		nd.id = int(pick[1])
		nd["tianqi_reroll"] = int(d.id)
		out.append(nd)
	return out


# ---- B. 坐骑管速度和先手 ----

static func mount_on() -> bool:
	return MOUNT_STATS and on()


## 这件是天启篇的普通坐骑（坐骑栏的装备；独特坐骑本批不做，以后在表里另列）
static func plain_mount(item) -> bool:
	return item is Dictionary and not item.is_empty() and str(item.get("kind", "")) == "armor" \
		and int(item.get("etypeId", 0)) == MOUNT and mount_on()


## 坐骑按品质（七档 0 普通～6 神话）的一行：{agi, preempt}，都是百分数
static func mount_row(item: Dictionary) -> Dictionary:
	var m: Dictionary = table().get("mount", {})
	var g := clampi(XQuality.grade(item), 0, 6)
	var agi: Array = m.get("agi_pct", [])
	var pre: Array = m.get("preempt_pct", [])
	return {"agi": float(agi[g]) if g < agi.size() else 0.0, "preempt": float(pre[g]) if g < pre.size() else 0.0}


static func mount_of(a) -> Dictionary:
	if a is XActor:
		for e in a.equip_list():
			if plain_mount(e):
				return e
	return {}


## 算能力值、特性用的装备列表（XActor.stat_equips／_param_plus）：普通坐骑原来的特性、属性、开战状态在天启篇不算
static func stat_list(list: Array) -> Array:
	if XTianqiSkills.cards_flag():
		list = list.map(func(e): return XTianqiSkills.gear_view(e))  # 天启篇技能重构：专属法宝、武器换改写视图
	if not mount_on():
		return list
	return list.filter(func(e): return not plain_mount(e))


## Game_Actor.param 包装（专属模块、心钢、狂妄、小猫剑圣之后，云裳夹值之前）：坐骑的敏捷百分比
static func param(a, i: int, v: float) -> float:
	if i != 6 or not mount_on():
		return v
	var m := mount_of(a)
	if m.is_empty():
		return v
	return roundf(v * (1.0 + float(mount_row(m).agi) / 100.0))


## 全队坐骑先制几率（0～1）：上场成员（battle_members，助力位不算）身上坐骑取最高一件，不相加
static func mount_preempt(s: XState) -> float:
	if not mount_on() or s == null:
		return 0.0
	var best := 0.0
	for a in s.battle_members():
		var m := mount_of(a)
		if not m.is_empty():
			best = maxf(best, float(mount_row(m).preempt))
	return best / 100.0


## 随机遇敌的先制率（XBattleLogic.roll_encounter，XPreempt.rates 之后）：加上坐骑先制，加完不超过总上限；
## 原来的先制率已经超过上限的不往下压（上限只管坐骑加出来的部分）。偷袭率不变。
static func apply_preempt(s: XState, rate: Dictionary) -> Dictionary:
	var bonus := mount_preempt(s)
	if bonus <= 0.0:
		return rate
	var cap := float(table().get("mount", {}).get("preempt_cap_pct", 33)) / 100.0
	rate.pre = maxf(float(rate.pre), minf(float(rate.pre) + bonus, cap))
	return rate


# ---- C. 神器成长上限 ----

static func cap_on() -> bool:
	return ARTIFACT_CAP and on()


static func _cap(key: String) -> float:
	return float(table().get("artifact_cap", {}).get(key, 0))


## 心之钢／杰作利维坦的有效阶数
static func heart_stage(n: int) -> int:
	return mini(n, int(_cap("heartsteel_stage"))) if cap_on() and _cap("heartsteel_stage") > 0.0 else n


## 狂妄／杰作无我的有效阶数
static func hubris_stage(n: int) -> int:
	return mini(n, int(_cap("hubris_stage"))) if cap_on() and _cap("hubris_stage") > 0.0 else n


## "头顶"的有效八项加成（百分数）
static func crown_bonus(b: float) -> float:
	return minf(b, _cap("crown_bonus_pct")) if cap_on() and _cap("crown_bonus_pct") > 0.0 else b


## 说明行后缀：成长到了上限（原值 ≥ 上限）时「（已达上限）」；key 是 artifact_cap 里的键
const CAP_TEXT := "（已达上限）"
static func cap_note(key: String, raw: float) -> String:
	return CAP_TEXT if cap_on() and _cap(key) > 0.0 and raw >= _cap(key) else ""


# ---- D. 装备八项 effective_params（T104：基础数值重构 v0.4 第五节第 1、6 条，第七节第 2 条「装备八项」那一行）----
## 只认期四总开关 XTianqiBase.on()（关着、西游档一律返回实例原来的 params，同一个数组、逐字节不变）。
## 开着、而且这件读表（applies）时：
##   有效八项 ＝ 新底子 ＋ 换算比 ×（词缀固定属性 ＋ 镶嵌固定值 ＋ 宝珠固定值 ＋ 吸取特效加的属性） ［＋ 差值退路］
##   - 新底子：标准线(折算等级, 这一项) × 部位系数 × 品质系数；折算等级＝1＋装备等级×98÷90（等级＝<req_level>，夹在 0～90）。
##     主攻给物攻还是魔攻看原版那件（模板）物攻、魔攻哪个高，一样高各给一半；魔法上限表里没有部位系数，底子为 0。
##     七印装备（实例带 qiyin 标记）照同一张表，武器和真印再 ×weapon_and_true_seal_mult。
##   - 词缀固定属性＝XGear.affix_template（底装备＋affixIds 各词缀＋备注参数）－底装备模板，按记录重拼，不倒推。
##   - 镶嵌固定值按 upgrades 历史从物品数据重算（百分比按底装备算，同 XGearUpgrade.apply_effects）；宝珠按孔里的宝珠重算固定加减。
##   - 差值退路（稿第五节第 6 条）：实例 params 里剩下的（镶嵌随机值、符文之语、其它没记录的成长）只有在镶嵌历史里有随机项、
##     或者有符文之语时才算，乘换算比后夹在新底子的 ±10% 以内；都没有时剩下的就是生成浮动，天启篇不算。
## 只在内存里算，装备实例一个字节不改、不写存档。按 instanceId 缓存，实例的八项、镶嵌、词缀、等级、品质变了就重算。
const GEAR_BASE_PATH := "res://modes/xiyou/tianqi_data/gear_base.json"
## 八项 → 换算比表的列（魔法跟生命同一列：标准线两者都是 ×25）
const RATIO_COLS := ["hp", "hp", "atk", "def", "atk", "def", "agi", "luk"]
## 八项 → 部位系数的键（魔法没有，物攻／魔攻都读主攻 atk，物防／魔防都读 def）
const SLOT_COLS := ["hp", "", "atk", "def", "atk", "def", "agi", "luk"]
const RESID_BAND := 0.1
static var _gb: Dictionary = {}
static var _gb_slots: Dictionary = {}
static var _eff_cache: Dictionary = {}
static var _orb_res: Array = []


static func gear_base() -> Dictionary:
	if _gb.is_empty():
		_gb = {}
		_gb_slots = {}
		if XDataFile.missing(GEAR_BASE_PATH):  # 发行包没有 tianqi_data
			return _gb
		var f := FileAccess.open(GEAR_BASE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			push_error("XTianqiGear: 读不到 " + GEAR_BASE_PATH)
			return _gb
		_gb = parsed
		for k in _gb.get("slots", {}):
			var row: Dictionary = _gb.slots[k]
			_gb_slots[int(row.get("etype", 0))] = row
	return _gb


## 测试用：清表和缓存
static func clear_effective_cache() -> void:
	_gb = {}
	_gb_slots = {}
	_eff_cache = {}


## 这件装备在当前状态下读不读新底子（总开关开着、天启篇存档；武器／防具；部位 1～10 且不在例外里；有等级需求和品质标记；不是天启篇奖励装备）
static func applies(item) -> bool:
	if not (item is Dictionary) or not XTianqiBase.on():
		return false
	if _kind(item) == "" or item.has(XTianqiRewards.FIELD):
		return false
	gear_base()
	var etype := int(item.get("etypeId", 0))
	var ex: Dictionary = _gb.get("exceptions", {})
	if not _gb_slots.has(etype) or (ex.get("etypes", []) as Array).has(float(etype)) or (ex.get("ids", []) as Array).has(float(item.get("base", item.get("id", 0)))):
		return false
	return str(item.get("meta", {}).get("req_level", "")).strip_edges().is_valid_int() and XQuality.has_quality(item)


## 统一入口：所有读装备八项的地方都走它。不读表时返回实例原来的 params（同一个数组，别改它）
static func effective_params(item: Dictionary) -> Array:
	if not XTianqiBase.PHASE4 or not applies(item):
		return item.get("params", [])
	var id := str(item.get("instanceId", ""))
	var c = _eff_cache.get(id) if id != "" else null
	if c != null and _eff_fresh(c, item):
		return c.out
	var out := _compute(item)
	if id != "":
		if _eff_cache.size() > 512:
			_eff_cache.clear()
		var p: Array = item.get("params", [])
		_eff_cache[id] = {"pref": p, "p": p.duplicate(), "un": (item.get("upgrades", []) as Array).size(),
			"aff": item.get("affixIds"), "meta": str(item.get("meta", {}).get("req_level", "")) + "|" + str(item.get("meta", {}).get("quality", "")),
			"orb": JSON.stringify(item.get("augmentSlotItems", [])), "out": out}
	return out


## 一项（不读表时同 float(params[i])）
static func param_of(item: Dictionary, i: int) -> float:
	var p := effective_params(item)
	return float(p[i]) if i >= 0 and i < p.size() else 0.0


## 固定加值（词缀、镶嵌、宝珠）在这件装备上的换算比；不读表时 1
static func flat_ratio(item, i: int) -> float:
	if not applies(item):
		return 1.0
	return _ratio(_level(item), i)


static func _eff_fresh(c: Dictionary, item: Dictionary) -> bool:
	var p: Array = item.get("params", [])
	if not is_same(c.pref, p) or c.p != p or not is_same(c.aff, item.get("affixIds")):  # 不比对象本身：卡的改写视图（XTianqiSkills.gear_view）每次是新的浅拷贝，八项、词缀数组和本体是同一个
		return false
	if c.un != (item.get("upgrades", []) as Array).size():
		return false
	var meta: Dictionary = item.get("meta", {})
	if c.meta != str(meta.get("req_level", "")) + "|" + str(meta.get("quality", "")):
		return false
	return c.orb == JSON.stringify(item.get("augmentSlotItems", []))


static func _kind(item: Dictionary) -> String:
	var k := str(item.get("kind", ""))
	if k == "weapon" or k == "armor":
		return k
	if item.has("wtypeId"):
		return "weapon"
	if item.has("atypeId"):
		return "armor"
	return ""


static func _level(item: Dictionary) -> int:
	var r := gear_base().get("level_map", {}).get("equip_level_range", [0, 90]) as Array
	return clampi(int(str(item.get("meta", {}).get("req_level", "0"))), int(r[0]), int(r[1]))


static func _ratio(level: int, i: int) -> float:
	var row = gear_base().get("ratio", {}).get(str(level), {})
	return float(row.get(RATIO_COLS[i], 1.0)) if row is Dictionary else 1.0


## 七印装备的底子倍率：武器、真印 ×1.1，其余 1；不是七印 0
static func _qiyin_mult(item: Dictionary) -> float:
	var m := XTianqiQiyinEffects.mark_of(item)
	if m.is_empty():
		return 0.0
	if str(m.get("kind", "")) == "weapon" or bool(m.get("true_seal", false)):
		return float(gear_base().get("qiyin", {}).get("weapon_and_true_seal_mult", 1.0))
	return 1.0


## 新底子（第五节第 1 条）。ref：判主攻用的原版八项（模板）
static func new_base(item: Dictionary, ref: Array = []) -> Array:
	gear_base()
	var lv := _level(item)
	var conv := 1.0 + float(lv) * 98.0 / 90.0
	var grade := float(_gb.get("grades", {}).get(XTianqiAffixRoll.QUALITY_KEYS[clampi(XQuality.grade(item), 0, 6)], 1.0))
	var slot: Dictionary = _gb_slots.get(int(item.get("etypeId", 0)), {})
	var mult := _qiyin_mult(item)
	if mult == 0.0:
		mult = 1.0
	if ref.size() < 8:
		ref = item.get("params", [0, 0, 0, 0, 0, 0, 0, 0])
	var atk := float(ref[2])
	var mat := float(ref[4])
	var share := [1.0, 1.0, 1.0 if atk > mat else (0.5 if atk == mat else 0.0), 1.0, 1.0 if mat > atk else (0.5 if atk == mat else 0.0), 1.0, 1.0, 1.0]
	var out := []
	for i in 8:
		var col: String = SLOT_COLS[i]
		var k := float(slot.get(col, 0.0)) if col != "" else 0.0
		out.append(XTianqiBase.line(conv, XTianqiBase.STATS[i]) * k * grade * float(share[i]) * mult)
	return out


## 宝珠孔里各宝珠的固定加减（<Augment Attach> 的「属性: ±N」行，同 XRaceBattle.weapon_body 的认法）
static func orb_fixed(eq: Dictionary) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var slots: Array = eq.get("augmentSlots", [])
	var held: Array = eq.get("augmentSlotItems", [])
	if held.is_empty():
		return out
	if _orb_res.is_empty():
		for n in XRaceBattle.BODY_NAMES:
			_orb_res.append(RegEx.create_from_string("(?i)^" + n + "\\s*:\\s*([+-]\\d+)$"))
	for i in held.size():
		var gem := XOrbs.gem_in_slot(eq, i)
		var type := str(slots[i] if i < slots.size() else "").to_upper().strip_edges()
		if gem.is_empty() or type == "":
			continue
		for line in XOrbs.parse(gem).attach.get(type, []):
			for p in 8:
				var m: RegExMatch = _orb_res[p].search(str(line).strip_edges())
				if m:
					out[p] += float(m.get_string(1))
	return out


## 镶嵌历史里的固定值（随机项不算，has_random 记下来）。base：底装备数据库原件（百分比项按它算）；cur：判 current 项用的八项
static func upgrade_fixed(item: Dictionary, cur: Array) -> Dictionary:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var rnd := false
	var kind := _kind(item)
	var base := XDB.rec("Weapons" if kind == "weapon" else "Armors", int(item.get("base", 0)))
	for u in item.get("upgrades", []):
		var data := XGearUpgrade.rule(XDB.rec("Items", int(u.get("item", 0)) if u is Dictionary else 0))
		for effect in data.get(kind, []):
			if str(effect.get("op", "")) != "param":
				continue
			if bool(effect.get("random", false)):
				rnd = true
				continue
			var ids: Array = range(8) if effect.param is String else [int(effect.param)]
			for i in ids:
				if effect.param is String and effect.param == "current" and float(cur[i]) + out[i] == 0.0:  # 同 XGearUpgrade.apply_effects：看镶到这一步时的当前值（前面已镶的固定值算进去）
					continue
				var n := float(effect.value)
				if bool(effect.get("percent", false)):
					n *= float(base.get("params", [0, 0, 0, 0, 0, 0, 0, 0])[i]) / 100.0
				out[i] += n
	return {"fixed": out, "random": rnd}


static func _compute(item: Dictionary) -> Array:
	var src := item
	var absorb := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if item.has(XAffixAbsorb.VIEW_FLAG):  # 吸取视图：本体照算，视图多出来的（吸取的特效属性）当固定加值
		var raw = XAffixAbsorb.real(item)
		if raw is Dictionary and not is_same(raw, item):
			src = raw
			for i in 8:
				absorb[i] = float(item.params[i]) - float(raw.params[i])
	var params: Array = src.get("params", [0, 0, 0, 0, 0, 0, 0, 0])
	var lv := _level(src)
	var orb := orb_fixed(src)
	var qiyin := _qiyin_mult(src) != 0.0
	var b := {} if qiyin else XGear.template(_kind(src), int(src.get("base", src.get("id", 0))))
	var t := {} if qiyin or b.is_empty() else XGear.affix_template(src, b)
	var bp: Array = b.get("params", params) if not b.is_empty() else params
	var nb := new_base(src, bp)
	var out := []
	if qiyin or b.is_empty():
		# 七印装备：实例八项是占位（底表填 1），只有宝珠是后加的；底装备找不到的退回只换底子
		for i in 8:
			var v: float = float(nb[i]) + _ratio(lv, i) * (float(orb[i]) + float(absorb[i]))
			out.append(roundf(maxf(0.0, v) if float(params[i]) >= 0.0 else v))
		return out
	var tp: Array = t.get("params", bp) if not t.is_empty() else bp
	var up := upgrade_fixed(src, tp)
	var keep := bool(up.random) or src.has("runewordName") or not (src.get("runewords", []) as Array).is_empty()
	for i in 8:
		var r := _ratio(lv, i)
		var affix := float(tp[i]) - float(bp[i])
		var fixed: float = affix + float(up.fixed[i]) + float(orb[i])
		var v: float = float(nb[i]) + r * (fixed + float(absorb[i]))
		if keep:
			var resid: float = float(params[i]) - float(tp[i]) - float(up.fixed[i]) - float(orb[i])
			if float(nb[i]) == 0.0:  # 新底子为 0 的项（MP、副属性）：没有「±10%」可夹，符文之语／随机石加的数照比例放行（T148，T104 小A P3）
				v += r * resid
			else:
				var band: float = absf(float(nb[i])) * RESID_BAND
				v += clampf(r * resid, -band, band)
		out.append(roundf(maxf(0.0, v) if float(params[i]) >= 0.0 else v))
	return out
