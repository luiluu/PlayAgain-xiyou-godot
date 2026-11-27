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
static func reload_table() -> void:
	_table = {}
	_drop_pool = []
	_efabao_specs = {}
	_efabao_recs = {}
	_efabao_views = {}
	_efabao_strip_re = null
	_elem_amp_table = {}
	_elem_amp_views = {}


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
	if element_fabaos_on():
		list = list.map(func(e): return element_fabao_view(e))  # 天启篇系别法宝（T442）：老档已有实例去原版特性/标签，只留本系或治疗 +10%
	if elem_amp_on():
		list = list.map(func(e): return elem_amp_view(e))  # T451：通用武器（5～50%）与保留栏位普通防具（5～20%）元素/物理增幅按档重调
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
##   - 符文之语加的八项按 XRunewords.template_id 找回模板重算，当固定加值乘换算比（T082；认不出的才走差值退路）。
##   - 差值退路（稿第五节第 6 条）：实例 params 里剩下的（镶嵌随机值、认不出的符文之语、其它没记录的成长）只有在镶嵌历史里有随机项、
##     或者有认不出的符文之语时才算，乘换算比后夹在新底子的 ±10% 以内；都没有时剩下的就是生成浮动，天启篇不算。
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
	_fabao_main = {}
	_efabao_specs = {}
	_efabao_recs = {}
	_efabao_views = {}
	_efabao_strip_re = null
	_elem_amp_table = {}
	_elem_amp_views = {}


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
	return _req_text(item).is_valid_int() and XQuality.has_quality(item)


## 【T164·D191】补等级覆盖表（gear_base.json level_override）：8 件原版没写 req_level 字段的真装备。开关 LEVEL_OVERRIDE，关着回原样。
## direct：补成这个等级，整件读新底子（秘火 40、超能螺丝刀 40、传承：巨灵大斧 15——说明文字里本来就写着）；
## gem_only：只给宝石算光耀度用的等级（80），装备自身八项不读新表、数值不变，只有宝石那份固定加值按 80 级换算比放大；
## keep_params：direct 里这几列保持原版实例值（巨灵大斧敏捷 −20 的惩罚）。传家宝×2 不在表里（占位，不补）。键 "weapon:1385"＝种类:底装备号
static var LEVEL_OVERRIDE := true


static func _ov_key(item: Dictionary) -> String:
	return "%s:%d" % [_kind(item), int(item.get("base", item.get("id", 0)))]


static func _ov(item: Dictionary, group: String):
	if not LEVEL_OVERRIDE or _kind(item) == "":
		return null
	var t = gear_base().get("level_override", {}).get(group, {})
	return t.get(_ov_key(item)) if t is Dictionary else null


## 有效的等级文字：实例自己的 req_level；没有就看 direct 覆盖表
static func _req_text(item: Dictionary) -> String:
	var t := str(item.get("meta", {}).get("req_level", "")).strip_edges()
	if t.is_valid_int():
		return t
	var o = _ov(item, "direct")
	return str(int(o)) if o != null else t


## 只给宝石用的等级（gem_only）；没有返回 -1
static func gem_only_level(item) -> int:
	if not (item is Dictionary) or not XTianqiBase.on() or item.has(XTianqiRewards.FIELD) or applies(item):
		return -1
	var o = _ov(item, "gem_only")
	return int(o) if o != null else -1


## 宝石固定加值要不要按换算比放大：读表的装备，或表里「只给宝石用等级」的装备
static func gem_applies(item) -> bool:
	return applies(item) or gem_only_level(item) >= 0


## 统一入口：所有读装备八项的地方都走它。不读表时返回实例原来的 params（同一个数组，别改它）
static func effective_params(item: Dictionary) -> Array:
	if not XTianqiBase.PHASE4:
		return item.get("params", [])
	if not applies(item):
		return _gem_only_params(item) if gem_only_level(item) >= 0 else item.get("params", [])
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
			"aff": item.get("affixIds"), "meta": _req_text(item) + "|" + str(item.get("meta", {}).get("quality", "")),
			"orb": JSON.stringify(item.get("augmentSlotItems", [])), "out": out}
	return out


## 一项（不读表时同 float(params[i])）
static func param_of(item: Dictionary, i: int) -> float:
	var p := effective_params(item)
	return float(p[i]) if i >= 0 and i < p.size() else 0.0


## 固定加值（词缀、镶嵌、宝珠）在这件装备上的换算比；不读表时 1
static func flat_ratio(item, i: int) -> float:
	if not gem_applies(item):
		return 1.0
	return _ratio(_level(item), i)


## 光耀 100% 时的换算比＝80 级那一行；CAP_80 关着返回 1（显示回到「基础值」口径）
static func full_ratio(i: int) -> float:
	return _ratio(CAP_LEVEL, i) if CAP_80 else 1.0


static func _eff_fresh(c: Dictionary, item: Dictionary) -> bool:
	var p: Array = item.get("params", [])
	if not is_same(c.pref, p) or c.p != p or not is_same(c.aff, item.get("affixIds")):  # 不比对象本身：卡的改写视图（XTianqiSkills.gear_view）每次是新的浅拷贝，八项、词缀数组和本体是同一个
		return false
	if c.un != (item.get("upgrades", []) as Array).size():
		return false
	var meta: Dictionary = item.get("meta", {})
	if c.meta != _req_text(item) + "|" + str(meta.get("quality", "")):
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
	var t := _req_text(item)
	var lv := int(t) if t.is_valid_int() else maxi(gem_only_level(item), 0)
	return clampi(lv, int(r[0]), int(r[1]))


## 【T164·D190】换算比取表时装备等级夹到 CAP_LEVEL（80）：光耀度最高 100%，超 80 级的特例（81、99、100 级共 5 件）按 80 级算固定加值。
## CAP_80 关掉回原样（读到 90 级）。只影响词缀／强化／镶嵌／宝珠的固定加值，不影响新底子（new_base 仍按原等级折算）
static var CAP_80 := true
const CAP_LEVEL := 80


static func _ratio(level: int, i: int) -> float:
	if CAP_80:
		level = mini(level, CAP_LEVEL)
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


## T163（D187，Kyo 11-17「直接修法宝」）：法宝读表——成长满时相当于半件同级装备（gear_base.json 的 fabao 节）。
## 开着（PHASE4＋天启篇存档）时 XActor.magic_param 改问这里：
##   攻击、生命 ＝ 标准线(1＋折算装备等级×98÷90, 这一项) × share × 法宝自己的品质系数；折算装备等级＝法宝等级×80÷99（99 级＝80 级装备）。
##   攻击给物攻还是魔攻看原版每级成长哪个大；一样大（含都为 0）两项都给。魔法、双防、敏捷、幸运不给。
## 法宝等级照旧受 XMagicWeapon.FLOOR_CAP 封顶（读表只把「等级 → 属性」换掉）。三法宝 60 级成长翻倍（XThreeGrowth）在读表时不算。
## 回退：`XTianqiGear.FABAO_TABLE = false`（照原版每级成长）。
static var FABAO_TABLE := true
static var _fabao_main := {}


## 只认法宝栏（etypeId 13，同 XTianqiAffixRoll）：别的栏带 Magic Weapon 备注的不读表（T163 甲核 P3-1）
static func fabao_applies(item) -> bool:
	return FABAO_TABLE and XTianqiBase.PHASE4 and item is Dictionary and XMagicWeapon.is_magic(item) and int(item.get("etypeId", 0)) == 13 \
		and XTianqiBase.on() and gear_base().has("fabao")


## 读表时这件法宝第 i 项给多少（不读表的项 0）；lv＜0 时 0
static func fabao_param(item: Dictionary, i: int) -> float:
	if i != 0 and i != 2 and i != 4:
		return 0.0
	var lv := float(XEquipmentView.level(item))
	if lv < 0.0:
		return 0.0
	var fb: Dictionary = gear_base().get("fabao", {})
	var key := str(item.get("kind", "")) + ":" + str(int(item.get("base", item.get("id", 0))))
	if i != 0:
		if not _fabao_main.has(key):
			var rec := XDB.rec("Weapons" if str(item.get("kind", "")) == "weapon" else "Armors", int(item.get("base", item.get("id", 0))))
			var g := XPower.magic_growth(rec if not rec.is_empty() else item)
			_fabao_main[key] = [g[2] >= g[4], g[4] >= g[2]]
		if not _fabao_main[key][0 if i == 2 else 1]:
			return 0.0
	var eq_lv := minf(lv, float(fb.get("full_level", 99))) * float(fb.get("equip_level_at_full", 80)) / float(fb.get("full_level", 99))
	var conv := 1.0 + eq_lv * 98.0 / 90.0
	var grade := float(_gb.get("grades", {}).get(XTianqiAffixRoll.QUALITY_KEYS[clampi(XQuality.grade(item), 0, 6)], 1.0))
	var share := float(fb.get("share", {}).get("hp" if i == 0 else "atk", 0.0))
	return floorf(XTianqiBase.line(conv, XTianqiBase.STATS[i]) * share * grade)


## 原版副属性留的那一小份（D182，Kyo 11-17：主属性的 10%～15%，T082 量 K 时定数；gear_base.json 的 sub_stat.ratio）；表里没有按 0（不留）
static func sub_ratio() -> float:
	var sub = gear_base().get("sub_stat", {})
	return float(sub.get("ratio", 0.0)) if sub is Dictionary else 0.0


## 新底子（第五节第 1 条）。ref：判主攻用的原版八项（模板）。
## D182：部位表里没有、原版这一项又不为零的（匕首的敏捷、法袍的魔法、物理武器上的魔攻等）给一小份：
## 标准线(这一项) × 本部位最大的部位系数 × 品质 × sub_stat.ratio，正负随原版。七印装备（实例八项是占位）不给
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
	var sub := 0.0 if _qiyin_mult(item) != 0.0 else sub_ratio()
	var k_main := 0.0
	for col in ["atk", "hp", "def", "agi", "luk"]:
		k_main = maxf(k_main, float(slot.get(col, 0.0)))
	var out := []
	for i in 8:
		var col: String = SLOT_COLS[i]
		var k := float(slot.get(col, 0.0)) if col != "" else 0.0
		var v := XTianqiBase.line(conv, XTianqiBase.STATS[i]) * k * grade * float(share[i]) * mult
		if v == 0.0 and sub > 0.0 and float(ref[i]) != 0.0:
			v = XTianqiBase.line(conv, XTianqiBase.STATS[i]) * k_main * grade * sub * signf(float(ref[i]))
		out.append(v)
	return out


## 符文之语加的八项（T082，T104 小A 核第 3 条：按 XRunewords.template_id 找回做成时加的那件模板，替代差值退路的 ±10% 夹值）。
## 认不出（名字对不上任何对这件装备有模板的配方）返回空，调用方退回差值退路
static func runeword_params(item: Dictionary) -> Array:
	var name := str(item.get("runewordName", ""))
	if name == "":
		return []
	var kind := _kind(item)
	var probe := item
	if str(item.get("kind", "")) != kind:
		probe = item.duplicate()
		probe["kind"] = kind
	for r in XDB.table("Runewords"):
		if not r is Dictionary:
			continue
		var tid := XRunewords.template_id(r, probe)
		if tid == 0:
			continue
		var tpl := XDB.rec("Weapons" if kind == "weapon" else "Armors", tid)
		if str(tpl.get("name", "")) == name:
			return tpl.get("params", [])
	return []


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


## ---- T164 光耀度（D186）：只读取值，不改上面任何算式 ----
## 这件装备上宝石类固定值的「基础值」八项（镶嵌固定值＋符文之语＋宝珠固定加减，不含词缀、随机镶嵌、吸取），
## 正是 _compute 里乘换算比的那三项；实际值＝换算比×基础值。不读表（关着、不适用）返回八个 0
static func gem_base(item) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if not XTianqiBase.PHASE4 or not gem_applies(item):
		return out
	var src: Dictionary = item
	if item.has(XAffixAbsorb.VIEW_FLAG):
		var raw = XAffixAbsorb.real(item)
		if raw is Dictionary and not is_same(raw, item):
			src = raw
	var orb := orb_fixed(src)
	var qiyin := _qiyin_mult(src) != 0.0
	var b := {} if qiyin else XGear.template(_kind(src), int(src.get("base", src.get("id", 0))))
	if qiyin or b.is_empty():
		return orb
	var t := XGear.affix_template(src, b)
	var tp: Array = t.get("params", b.get("params", [])) if not t.is_empty() else b.get("params", src.get("params", []))
	var up := upgrade_fixed(src, tp)
	var rw := runeword_params(src)
	for i in 8:
		out[i] = float(up.fixed[i]) + float(orb[i]) + (float(rw[i]) if rw.size() >= 8 else 0.0)
	return out


## 一组 <Augment Attach> 行（某类型下）的固定加减八项（同 orb_fixed 的认法；镶嵌预览用，宝珠还没镶进去）
static func orb_lines_fixed(lines: Array) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if _orb_res.is_empty():
		for n in XRaceBattle.BODY_NAMES:
			_orb_res.append(RegEx.create_from_string("(?i)^" + n + "\\s*:\\s*([+-]\\d+)$"))
	for line in lines:
		for p in 8:
			var m: RegExMatch = _orb_res[p].search(str(line).strip_edges())
			if m:
				out[p] += float(m.get_string(1))
	return out


## 某一个宝珠孔的固定加减（同 orb_fixed 的认法，只算这一孔）
static func orb_slot_fixed(eq: Dictionary, slot: int) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var slots: Array = eq.get("augmentSlots", [])
	var gem := XOrbs.gem_in_slot(eq, slot)
	var type := str(slots[slot] if slot >= 0 and slot < slots.size() else "").to_upper().strip_edges()
	if gem.is_empty() or type == "":
		return out
	if _orb_res.is_empty():
		for n in XRaceBattle.BODY_NAMES:
			_orb_res.append(RegEx.create_from_string("(?i)^" + n + "\\s*:\\s*([+-]\\d+)$"))
	for line in XOrbs.parse(gem).attach.get(type, []):
		for p in 8:
			var m: RegExMatch = _orb_res[p].search(str(line).strip_edges())
			if m:
				out[p] += float(m.get_string(1))
	return out


static func _compute(item: Dictionary) -> Array:
	var out := _compute_core(item)
	var keep = _ov(item, "keep_params")
	if keep is Array:   # D191：这几列保持原版实例值（巨灵大斧敏捷 −20）
		var raw: Dictionary = item
		if item.has(XAffixAbsorb.VIEW_FLAG):
			var real = XAffixAbsorb.real(item)
			if real is Dictionary and not is_same(real, item):
				raw = real
		var p: Array = raw.get("params", [])
		for c in keep:
			if int(c) >= 0 and int(c) < 8 and int(c) < p.size():
				out[int(c)] = float(p[int(c)])
	return out


## D191 gem_only：自身八项原样，宝石固定加值（镶嵌、宝珠、符文之语）在原值里已按 1 倍算过，这里补到换算比倍：params＋(换算比−1)×宝石基础值
static func _gem_only_params(item: Dictionary) -> Array:
	var base: Array = item.get("params", [])
	if base.size() < 8:
		return base
	var gb := gem_base(item)
	var out := []
	for i in 8:
		out.append(roundf(float(base[i]) + (_ratio(_level(item), i) - 1.0) * float(gb[i])))
	return out


static func _compute_core(item: Dictionary) -> Array:
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
	var rw := runeword_params(src)
	if rw.size() < 8:
		rw = []
	var keep := bool(up.random) or (rw.is_empty() and (src.has("runewordName") or not (src.get("runewords", []) as Array).is_empty()))
	for i in 8:
		var r := _ratio(lv, i)
		var affix := float(tp[i]) - float(bp[i])
		var rwi := float(rw[i]) if not rw.is_empty() else 0.0
		var fixed: float = affix + float(up.fixed[i]) + float(orb[i]) + rwi
		var v: float = float(nb[i]) + r * (fixed + float(absorb[i]))
		if keep:
			var resid: float = float(params[i]) - float(tp[i]) - float(up.fixed[i]) - float(orb[i]) - rwi
			if float(nb[i]) == 0.0:  # 新底子为 0 的项（MP、副属性）：没有「±10%」可夹，符文之语／随机石加的数照比例放行（T148，T104 小A P3）
				v += r * resid
			else:
				var band: float = absf(float(nb[i])) * RESID_BAND
				v += clampf(r * resid, -band, band)
		out.append(roundf(maxf(0.0, v) if float(params[i]) >= 0.0 else v))
	return out


# ==== E. 系别法宝归法宝线（T442 / T013-1a，养成线方案 v0.3 第三节第 9 条）====
## 开关（T442）：true＝天启篇存档里 12 把系别法宝（原 4543～4552＋表外水 8101／风 8102）去掉原版全属性倍率（特性 21）、
## 暴击命中（特性 22）、再动（特性 61）、攻击次数（特性 34）、抗性/受治疗倍率（特性 11）与大额增伤/终伤/爆伤/穿透标签，
## 只留本系或治疗 +10%、FABAO_TABLE 成长与 1 条通用法宝光环；4548 改名「森罗灵剑」避免与风系冲突（标待小A·文字审）。
## false＝回退（4543～4552 照原版，8101／8102 不存在）。西游档恒不生效。
static var ELEMENT_FABAOS := true
const EFABAO_VER := 2
static var _efabao_specs: Dictionary = {}
static var _efabao_recs: Dictionary = {}
static var _efabao_views: Dictionary = {}
static var _efabao_strip_re: RegEx = null
static var _efabao_re_aps := RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\]特效[^>]*>\\r?\\n?")
static var _efabao_re_price := RegEx.create_from_string("(?i)<item\\s+2530\\s+Buy\\s+Price:[^>]*>")


static func element_fabaos_on(s: XState = null) -> bool:
	return ELEMENT_FABAOS and on(s)


static func _efabao_map() -> Dictionary:
	if _efabao_specs.is_empty():
		var items = table().get("element_fabaos", {}).get("items", [])
		if items is Array:
			for row in items:
				if row is Dictionary and int(row.get("id", 0)) > 0:
					_efabao_specs[int(row.id)] = row
	return _efabao_specs


static func element_fabao_ids() -> Array:
	var ids: Array = _efabao_map().keys()
	ids.sort()
	return ids


## XDB.rec("Armors", id) 挂点：天启篇存档且开着时接管 12 把系别法宝（含表外水/风 8101/8102）
static func touches_element_fabao(id: int) -> bool:
	if not element_fabaos_on():
		return false
	return _efabao_map().has(id)


## XDB.rec("Armors", id) 返回的改写记录（原 10 把就地改视图，表外 8101/8102 按 template 复制构造）
static func element_fabao_rec(id: int, base_table: Array) -> Dictionary:
	if not element_fabaos_on():
		return {}
	var sp: Dictionary = _efabao_map().get(id, {})
	if sp.is_empty():
		return {}
	var src_id := int(sp.get("template", id))
	if src_id <= 0 or src_id >= base_table.size() or not (base_table[src_id] is Dictionary):
		return {}
	var src: Dictionary = base_table[src_id]
	var hit = _efabao_recs.get(id)
	if hit is Array and is_same(hit[0], src):
		return hit[1]
	var out := _build_element_fabao(src, sp, id)
	_efabao_recs[id] = [src, out]
	return out


static func _strip_re() -> RegEx:
	if _efabao_strip_re == null:
		var tags: Array = table().get("element_fabaos", {}).get("strip_note_tags", ["Element Amplify \\d+", "DepassiveHarmRe\\d+", "passiveCrHarmRi", "passiveHarmRi"])
		var parts: PackedStringArray = []
		for t in tags:
			parts.append(str(t))
		_efabao_strip_re = RegEx.create_from_string("(?i)<(?:" + "|".join(parts) + ")(?::[^>]*)?>\\r?\\n?")
	return _efabao_strip_re


static func _rewrite_efabao_note(src_note: String, sp: Dictionary, elem: int, pct: int) -> String:
	var note := _strip_re().sub(src_note, "", true)
	note = _efabao_re_aps.sub(note, "", true).strip_edges()
	var ef: Dictionary = table().get("element_fabaos", {})
	var add_lines: PackedStringArray = []
	if sp.has("buy_price"):
		var bp := int(sp.buy_price)
		if _efabao_re_price.search(note) != null:
			note = _efabao_re_price.sub(note, "<item 2530 Buy Price: %d>" % bp, true)
		else:
			add_lines.append("<item 2530 Buy Price: %d>" % bp)
	var lbl := str(sp.get("effect_label", ""))
	if lbl != "":
		add_lines.append("<pos=APs text=\\c[1]特效：%s+%d%% size=18 color=rgba(255,255,255,1) line=false align=0>" % [lbl, pct])
	var aura_line := str(ef.get("aura_line", ""))
	if aura_line != "":
		add_lines.append("<pos=APs text=\\c[1]特效：%s size=18 color=rgba(255,255,255,1) line=false align=0>" % aura_line)
	add_lines.append("<Element Amplify %d: +%d%%>" % [elem, pct])
	return (note + "\n" if note != "" else "") + "\n".join(add_lines)


static func _build_element_fabao(src: Dictionary, sp: Dictionary, id: int) -> Dictionary:
	var out: Dictionary = src.duplicate(true)
	out["id"] = id
	if sp.has("name") and str(sp.name) != "":
		out["name"] = str(sp.name)
	if sp.has("description"):
		out["description"] = str(sp.description)
	if sp.has("icon"):
		out["iconIndex"] = int(sp.icon)
	out["etypeId"] = 13
	out["traits"] = []
	var elem := int(sp.get("element", 0))
	var pct := int(sp.get("bonus_pct", table().get("element_fabaos", {}).get("bonus_pct", 10)))
	var note := _rewrite_efabao_note(str(src.get("note", "")), sp, elem, pct)
	out["note"] = note
	out["meta"] = XTianqiSkills.parse_meta(note)
	out["yep"] = {"elementAmplify": {str(elem): float(pct) / 100.0}}
	out["_tq_efabao_v"] = EFABAO_VER
	return out


## 替换改名系别法宝的名字，保留 [锁定] 前缀与 (+N) 强化后缀
static func _efabao_sync_name(old_name: String, base_id: int, new_base: String) -> String:
	if new_base == "":
		return old_name
	var raw_t = XDB.table("Armors")
	var raw_name := str(raw_t[base_id].get("name", "")) if raw_t is Array and base_id > 0 and base_id < raw_t.size() and raw_t[base_id] is Dictionary else ""
	if raw_name != "" and old_name.contains(raw_name) and not old_name.contains(new_base):
		return old_name.replace(raw_name, new_base)
	return new_base if old_name == "" else old_name


## 更新系别法宝说明，已有天启篇光环时保留末尾光环行
static func _efabao_apply_desc(item: Dictionary, new_desc: String) -> void:
	if new_desc == "":
		return
	var aff = item.get("tianqi_affixes", null)
	if aff is Array and not (aff as Array).is_empty():
		item["tianqi_desc_base"] = new_desc
		XTianqiAffixRoll.set_affixes(item, aff)
	else:
		item["description"] = new_desc


static func _efabao_clean_traits(src_traits, strip_codes: Array) -> Array:
	var traits: Array = []
	if src_traits is Array:
		for t in src_traits:
			if t is Dictionary and (t.has("_codexOrb") or not strip_codes.any(func(code): return int(code) == int(t.get("code", -1)))):
				traits.append(t)
	return traits


static func _efabao_clean_yep(item: Dictionary, elem: int, pct: int) -> Dictionary:
	var yep: Dictionary = (item.get("yep", {}) as Dictionary).duplicate(true)
	var amp := {str(elem): float(pct) / 100.0}
	var orb_amp := XTianqiLedger.orb_amplify(item)
	for k in orb_amp:
		amp[str(k)] = float(amp.get(str(k), 0.0)) + float(orb_amp[k])
	yep["elementAmplify"] = amp
	return yep


## 战斗/说明卡视图（XTianqiGear.stat_list、XHelpCard 调）：兼容老天启篇存档里已持有的 4543～4552 旧实例
static func element_fabao_view(item):
	if not element_fabaos_on() or not (item is Dictionary) or item.is_empty():
		return item
	if str(item.get("kind", "armor")) != "armor":
		return item
	var base_id := int(item.get("base", item.get("id", 0)))
	var sp: Dictionary = _efabao_map().get(base_id, {})
	if sp.is_empty():
		return item
	var cur_ver := int(item.get("_tq_efabao_v", 0))
	if cur_ver >= EFABAO_VER:
		return item
	var elem := int(sp.get("element", 0))
	var pct := int(sp.get("bonus_pct", table().get("element_fabaos", {}).get("bonus_pct", 10)))
	var src_note := str(item.get("note", ""))
	var src_traits = item.get("traits", [])
	var strip_codes: Array = table().get("element_fabaos", {}).get("strip_trait_codes", [11, 21, 22, 34, 61])
	var c = _efabao_views.get(base_id)
	if not (c is Array and is_same(c[1], src_traits) and c[0] == src_note and int(c[5]) == cur_ver):
		var traits: Array = _efabao_clean_traits(src_traits, strip_codes) if cur_ver < 1 else (src_traits as Array if src_traits is Array else [])
		var note := _rewrite_efabao_note(src_note, sp, elem, pct)
		c = [src_note, src_traits, note, XTianqiSkills.parse_meta(note), traits, cur_ver]
		_efabao_views[base_id] = c
	var v: Dictionary = item.duplicate(false)
	if sp.has("name") and str(sp.name) != "":
		v["name"] = _efabao_sync_name(str(item.get("name", "")), base_id, str(sp.name))
	if sp.has("description"):
		_efabao_apply_desc(v, str(sp.description))
	v["note"] = c[2]
	v["meta"] = c[3]
	v["traits"] = c[4]
	v["yep"] = _efabao_clean_yep(item, elem, pct)
	return v


## 读档后同步老天启篇档里的系别法宝实例（XTianqiSave.after_load 调）：同步名字/说明/备注/特性/yep，西游档与开关关时不动
static func sync_element_fabaos(s: XState) -> void:
	if s == null or not element_fabaos_on(s):
		return
	var all := s.gear.duplicate()
	for a in s.actors.values():
		all.append_array(a.raw_equip_list())
	for w in s.warehouses.values():
		if w is Dictionary and w.get("items") is Dictionary:
			for list in w.items.values():
				if list is Array:
					for v in list:
						if v is Dictionary:
							all.append(v)
	var seen := []
	var touched := false
	var strip_codes: Array = table().get("element_fabaos", {}).get("strip_trait_codes", [11, 21, 22, 34, 61])
	for item in all:
		if not (item is Dictionary) or item.is_empty() or seen.any(func(x): return is_same(x, item)):
			continue
		seen.append(item)
		if str(item.get("kind", "")) != "armor":
			continue
		var base_id := int(item.get("base", item.get("id", 0)))
		var sp: Dictionary = _efabao_map().get(base_id, {})
		if sp.is_empty():
			continue
		var cur_ver := int(item.get("_tq_efabao_v", 0))
		if cur_ver >= EFABAO_VER:
			continue
		var elem := int(sp.get("element", 0))
		var pct := int(sp.get("bonus_pct", table().get("element_fabaos", {}).get("bonus_pct", 10)))
		if sp.has("name") and str(sp.name) != "":
			item["name"] = _efabao_sync_name(str(item.get("name", "")), base_id, str(sp.name))
			if item.has("baseName"):
				item["baseName"] = _efabao_sync_name(str(item.get("baseName", "")), base_id, str(sp.name))
		if sp.has("description"):
			_efabao_apply_desc(item, str(sp.description))
		if cur_ver < 1:
			item["traits"] = _efabao_clean_traits(item.get("traits", []), strip_codes)
		var note := _rewrite_efabao_note(str(item.get("note", "")), sp, elem, pct)
		item["note"] = note
		item["meta"] = XTianqiSkills.parse_meta(note)
		item["yep"] = _efabao_clean_yep(item, elem, pct)
		item["_tq_efabao_v"] = EFABAO_VER
		touched = true
	if touched:
		for a in s.actors.values():
			a.refresh_passive()
			a.param_mark_dirty()


# ==== F. 通用武器与保留栏位普通防具元素/物理增幅分档重调（T451，Kyo 2026-11-24 事项 50）====
## 开关（T451）：true＝天启篇存档里 326 把通用武器按五档重调至 5%～50%（整数避 4）、540 件保留栏位普通防具按档重调至 5%～20%（整数避 4），
## 物理与火/冰/雷等其它元素增幅一并压低，并同步卡面 <pos=APs> 说明行与 <Element Amplify> 备注标签；宝珠／强化增量完整保留。
## false＝回退到原版增幅。西游档恒不生效。
static var GEAR_ELEM_RESCALE := true
const ELEM_AMP_PATH := "res://modes/xiyou/tianqi_data/gear_elem_amp.json"
static var _elem_amp_table: Dictionary = {}
static var _elem_amp_views: Dictionary = {}
static var _elem_amp_tag_re := RegEx.create_from_string("(?i)<ELEMENT AMPLIFY [^:>]+: [+-]\\d+(?:\\.\\d+)?[%％]>\\r?\\n?")


static func elem_amp_on(s: XState = null) -> bool:
	return GEAR_ELEM_RESCALE and on(s)


static func elem_amp_table() -> Dictionary:
	if _elem_amp_table.is_empty():
		if XDataFile.missing(ELEM_AMP_PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(ELEM_AMP_PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiGear: 读不到 " + ELEM_AMP_PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_elem_amp_table = parsed
		else:
			push_error("XTianqiGear: JSON 解析失败 " + ELEM_AMP_PATH)
	return _elem_amp_table


static func _rewrite_elem_amp_note(src_note: String, sp: Dictionary) -> String:
	var note := src_note
	for pair in sp.get("subs", []):
		if pair is Array and pair.size() >= 3 and str(pair[2]) == "re":  # T549 R1：第三项 re 按正则替换（装备卡面行按锚点换，XTextFix 改过的字逐字对不上）
			note = RegEx.create_from_string("(?s)" + str(pair[0])).sub(note, str(pair[1]), true)
		elif pair is Array and pair.size() >= 2:
			note = note.replace(str(pair[0]), str(pair[1]))
	note = _elem_amp_tag_re.sub(note, "", true).strip_edges()
	var add_lines: PackedStringArray = []
	var amp: Dictionary = sp.get("amp", {})
	var keys := amp.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for ek in keys:
		add_lines.append("<Element Amplify %s: +%d%%>" % [str(ek), int(amp[ek])])
	if add_lines.is_empty():
		return note
	return (note + "\n" if note != "" else "") + "\n".join(add_lines)


static func _rescaled_elem_amp_yep(item: Dictionary, kind: String, base_id: int, amp: Dictionary) -> Dictionary:
	var yep: Dictionary = (item.get("yep", {}) as Dictionary).duplicate(true)
	var cur: Dictionary = yep.get("elementAmplify", {}) if yep.get("elementAmplify") is Dictionary else {}
	var raw_rec := XDB.rec("Weapons" if kind == "weapon" else "Armors", base_id)
	var raw_ea: Dictionary = raw_rec.get("yep", {}).get("elementAmplify", {}) if not raw_rec.is_empty() else {}
	var out_ea := {}
	for ek in cur:
		var ks := str(ek)
		if amp.has(ks):
			var extra := float(cur[ek]) - float(raw_ea.get(ks, 0.0))
			var val := float(amp[ks]) / 100.0 + extra
			if absf(val) >= 1e-9:
				out_ea[ks] = val
		else:
			out_ea[ks] = float(cur[ek])
	for ek in amp:
		var ks := str(ek)
		if not out_ea.has(ks) and not cur.has(ks):
			out_ea[ks] = float(amp[ks]) / 100.0
	if out_ea.is_empty():
		yep.erase("elementAmplify")
	else:
		yep["elementAmplify"] = out_ea
	return yep


## 战斗／说明卡视图（XTianqiGear.stat_list、XHelpCard 调）：按 gear_elem_amp.json 替换元素／物理增幅与卡面文字，保留宝珠／强化增量
static func elem_amp_view(item):
	if not elem_amp_on() or not (item is Dictionary) or item.is_empty() or bool(item.get("_tq_ea_view", false)):
		return item
	var kind := _kind(item)
	if kind != "weapon" and kind != "armor":
		return item
	var base_id := int(item.get("base", item.get("id", 0)))
	var sec := "weapons" if kind == "weapon" else "armors"
	var sp = elem_amp_table().get(sec, {}).get(str(base_id))
	if not (sp is Dictionary) or sp.is_empty():
		return item
	var src_note := str(item.get("note", ""))
	var ckey := "%s:%d" % [kind, base_id]
	var c = _elem_amp_views.get(ckey)
	if not (c is Array and c[0] == src_note):
		var note := _rewrite_elem_amp_note(src_note, sp)
		c = [src_note, note, XTianqiSkills.parse_meta(note)]
		_elem_amp_views[ckey] = c
	var v: Dictionary = item.duplicate(false)
	v["note"] = c[1]
	v["meta"] = c[2]
	v["yep"] = _rescaled_elem_amp_yep(item, kind, base_id, sp.get("amp", {}))
	v["_tq_ea_view"] = true
	return v
