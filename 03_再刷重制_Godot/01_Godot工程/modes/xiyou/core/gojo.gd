class_name XGojo
extends RefCounted
## 【cc·未经审查】天启篇超强者 180 五条悟（设计：00_项目管理/交付/五条悟_角色设计_v0.2.md，Kyo 11-12 定乙「苍＋赫＝茈」、开放方式「最强之名」）。
## 重制新加的角色，原版数据里没有：开数据库表时（XDB.table）把角色、职业、技能、状态、进阶行补进去，编号见下面的常量；
## 编号被正式源占用时不覆盖、报错（以后正式版加了同号记录，要把这里整体挪号）。素材在 content/gojo/（XDB.img_path）。
## 只在天启篇：天启篇以外 XImportedBalance 当他停用（不能入队）、图鉴和仓库不列，所有角色学技能的事件循环跳过他（hidden）。
## 技能数值走技能重构的技能表（tianqi_data/skill_rework.json，XTianqiSkills）：普攻、苍、赫、反转术式、两招最大出力、领域按表里的
## 系数、费用、冷却算；茈的系数按对数取表里 gojo_pairs（module "gojo"，XGojo.formula），等级缩放照表（1 级一半）。
##
## 战斗（battle_logic 各包装点）：
## - 苍印、赫印（0～3，超出作废）：苍类（苍、苍·最大出力）+1／+2 苍印，赫类 +1／+2 赫印，反转术式 +1 赫印；跨回合保留，阵亡、战斗结束清空。
##   身上挂 苍印·一～三、赫印·一～三 状态显示层数。
## - 上一个术式 last：只有苍类、赫类改它。茈要两种印都 ≥1，对数 n＝较少的一个；last 是苍 → 茈「收」（10640 全体），是赫 → 茈「放」（10641 单体）；
##   战斗技能列表只列当前形状的那一招。施放后两种印清空。
## - 六眼 10643：这次苍类／赫类和 last 不同类时，苍、赫的 MP 消耗为 0，并有 10% 几率再动（每回合最多一次，接在本次行动后）。
## - 无下限 10644：每回合第一次被敌人单体攻击（生命伤害）时，有苍印就花 1 苍印整次拦下（不扣血、不附状态）。
## - 最强 10645：最终伤害 +10%（被动标签，表里）。
## - 黑闪 10225（XBlackFlash，和甚尔、宿傩共用）：咒力打击可触发；觉醒（学了 10646）3 回合，苍、赫、茈、领域吃 ×1.2；
##   五条悟专属：每次黑闪回最大 MP 10%；觉醒中咒力打击给较少的那种印 +1（一样多给苍印）。
## - 无量空处 10642：展开时全体伤害，之后 3 回合（含展开这回合）：用苍类时赫印另 +1、赫类时苍印另 +1；敌人每次行动前判一次信息过载，
##   普通敌人 30%、首领 15% 这次不能行动；五条悟的术式必中。
## - 进阶（XAdvance，插件「Advanced 501～504」）：一 茈「收」命中减速 10% 一回合；二 茈「放」无视目标 50% 防御；
##   三 每场一次生命掉到 30% 以下立刻回复 30%；四 展开领域时苍印、赫印各 +1。每次进阶另学通用的超越极限 I～IV（增伤 +5%）。
## 第二期（cc/gojo-p2）：
## - 专属法宝「眼罩」（护甲 8001，装备类型 13，只能五条悟装）：茈结算后返还苍印、赫印各 1。五条悟在天启篇入队时（XState.add_actor）
##   背包有就拿、没有就生成，装进装备类型 13 的槽（照宿傩神武解）。
## - 开放方式「最强之名」：证道难度（证道开放前临时炼狱，Kyo 11-14）、36 层骑士战（XTianqiRewards.after_final）赢了、那场上场的人里有宿傩 172 或甚尔 171
##  （开战时记下出战的人，中途阵亡也算）→ 全局配置 codexTianqiGojo 记一次（跨存档），右上角提示。没解锁时天启篇也当他停用
##  （XImportedBalance.is_disabled_actor、XTianqiSkills.tier_of 返回空），解锁后按技能表名单进超强者候选池（寻常、艰险照超强者上限抽不到）。
## - 头像：还是战斗图截的临时图，等 GPT 出的正式图。
## 开关：ENABLED＝false 不补数据、不挂机制（O-365）。

const ACTOR := 180
const CLASS := 178
const STRIKE := 10634
const BLUE := 10635
const RED := 10636
const REVERSE := 10637
const BLUE_MAX := 10638
const RED_MAX := 10639
const PURPLE_IN := 10640  # 茈「收」全体
const PURPLE_OUT := 10641  # 茈「放」单体
const DOMAIN := 10642
const SIX_EYES := 10643
const INFINITY := 10644
const STRONGEST := 10645
const AWAKENING := 10646
const ADV := [10647, 10648, 10649, 10650]
const FIRST_SKILL := 10634
const LAST_SKILL := 10650
const ST_BLUE := 2792  # 2792～2794 苍印·一～三
const ST_RED := 2795  # 2795～2797 赫印·一～三
const ST_DOMAIN := 2798
const ST_AWAKE := 2799
const ST_SLOW := 2800
const LAST_STATE := 2800
const ADVANCE_ROW := 501  # 插件 Star_ActorAdvanced「Advanced 501～504」
const BLUE_SET := [BLUE, BLUE_MAX]
const RED_SET := [RED, RED_MAX]
const TECHNIQUES := [BLUE, RED, BLUE_MAX, RED_MAX, PURPLE_IN, PURPLE_OUT, DOMAIN]
const MARK_CAP := 3
const AGAIN_RATE := 0.1
const OVERLOAD := 0.3
const OVERLOAD_BOSS := 0.15
const DOMAIN_TURNS := 3
const MP_ON_FLASH := 0.1
const AUTO_REVERSE_BELOW := 0.3
const AUTO_REVERSE_HEAL := 0.3
const TEMPLATE_SKILL := 10229  # 宿傩「解」：主动技能记录的样子（行动序列、消息）
const TEMPLATE_PASSIVE := 10242
const TEMPLATE_CLASS := 170
const TEMPLATE_ACTOR := 172
const ARMOR := 8001  # 专属法宝「眼罩」
const ARMOR_SLOT_TYPE := 13
const TEMPLATE_ARMOR := 4581  # 宿傩「神武解」
const UNLOCK_KEY := "codexTianqiGojo"
const UNLOCK_DIFFICULTY := "zhengdao"
## 证道开放前临时降到炼狱（Kyo 11-14）：XTianqi.ZHENGDAO_OPEN 还关着时炼狱 36 层也解锁；证道一开放自动只认证道。
## 已解锁的记在全局配置里、不收回。开关（O-463）：false 回到只认证道
static var BEFORE_ZHENGDAO_LIANYU := true
const UNLOCK_DIFFICULTY_BEFORE_OPEN := "lianyu"
const UNLOCK_WITH := [171, 172]
const UNLOCK_TEXT := "五条悟：「你们打得不错嘛。」\n最强之名已解锁：之后天启篇的候选池里会出现五条悟。"
## 测试用：-1 读全局配置，0／1 强制没解锁／已解锁
static var unlock_override := -1

static var ENABLED := true


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


## 天启篇以外不出现（停用、图鉴仓库不列、全角色循环跳过）
static func hidden(id: int) -> bool:
	return ENABLED and id == ACTOR and not XTianqi.active(XState.current)


## 最强之名解锁了没有（跨存档）
static func unlocked() -> bool:
	if unlock_override >= 0:
		return unlock_override == 1
	return XConfig.flag(UNLOCK_KEY)


## 天启篇里还没解锁：不能入队、不进候选池
static func locked(id: int) -> bool:
	return ENABLED and id == ACTOR and not unlocked()


static func knows(a, id: int) -> bool:
	return own(a) and a.skill_ids.has(id)


# ---- 数据（XDB.table 打开表时补） ----

static func _free(t: Array, id: int, what: String) -> bool:
	while t.size() <= id:
		t.append(null)
	if t[id] is Dictionary and str(t[id].get("name", "")) != "" and not bool(t[id].get("_gojo", false)):
		push_error("XGojo: %s %d 已被正式源占用，五条悟没有补进去（要整体挪号）" % [what, id])
		return false
	return true


static func patch_actors(t: Array) -> void:
	if not ENABLED or not _free(t, ACTOR, "角色"):
		return
	var r: Dictionary = (t[TEMPLATE_ACTOR] as Dictionary).duplicate(true)
	r.id = ACTOR
	r._gojo = true
	r.name = "五条悟"
	r.nickname = "最强"
	r.classId = CLASS
	r.battlerName = "Codex_Gojo_SV"
	r.characterName = "$Codex_Gojo_Walk"
	r.characterIndex = 0
	r.faceName = "Codex_Gojo_Face"
	r.faceIndex = 0
	r.profile = "攒苍、攒赫，合成茈，一发定胜负。"
	r.note = "<Actorquality: 10>\n<ActorNote>六眼与无下限术式的继承者。</ActorNote>\n<KyoTier:超强者>\n<Replace Attack: %d>" % STRIKE
	r.meta = XTianqiSkills.parse_meta(r.note)
	t[ACTOR] = r


static func patch_classes(t: Array) -> void:
	if not ENABLED or not _free(t, CLASS, "职业"):
		return
	var r: Dictionary = (t[TEMPLATE_CLASS] as Dictionary).duplicate(true)
	r.id = CLASS
	r._gojo = true
	r.name = "最强咒术师"
	# 主属性魔攻：宿傩的攻击、魔攻两条曲线对调；输出型生命 ×0.9
	var p: Array = r.params
	var atk = p[2]
	p[2] = p[4]
	p[4] = atk
	p[0] = (p[0] as Array).map(func(v): return roundi(float(v) * 0.9))
	r.learnings = []
	for row in [[1, STRIKE], [1, BLUE], [10, RED], [20, REVERSE], [30, BLUE_MAX], [30, RED_MAX], [50, PURPLE_IN], [50, PURPLE_OUT], [60, DOMAIN],
			[1, SIX_EYES], [1, INFINITY], [1, STRONGEST], [1, XBlackFlash.SKILL], [15, AWAKENING]]:
		r.learnings.append({"level": XTianqiGojoTrial.learn_level(row[1], row[0]), "skillId": row[1], "note": ""})  # 试炼版（v0.3）：茈 25、领域 55
	t[CLASS] = r


## 技能：主动按宿傩「解」的样子、被动按「黑闪觉醒：宿傩」的样子建底子，再按技能表改写（XTianqiSkills.build：费用、冷却、被动标签、说明）
static func patch_skills(t: Array) -> void:
	if not ENABLED:
		return
	for id in range(FIRST_SKILL, LAST_SKILL + 1):
		if not _free(t, id, "技能"):
			return
	var defs := {
		STRIKE: ["咒力打击", 1, 1, 1, icon(2), 1],
		BLUE: ["术式顺转「苍」", 2, 2, 1, icon(3), 473],
		RED: ["术式反转「赫」", 2, 1, 1, icon(4), 697],
		REVERSE: ["反转术式", 2, 11, 3, icon(5), 45],
		BLUE_MAX: ["苍·最大出力", 2, 2, 1, icon(6), 561],
		RED_MAX: ["赫·最大出力", 2, 1, 1, icon(7), 697],
		PURPLE_IN: ["虚式「茈」·收", 2, 2, 1, icon(8), 120],
		PURPLE_OUT: ["虚式「茈」·放", 2, 1, 1, icon(9), 120],
		DOMAIN: ["领域展开「无量空处」", 2, 2, 1, icon(10), 784],
	}  # 名字、命中类型、范围（1 敌单体、2 敌全体、11 自己）、伤害类型（1 伤害、3 回复）、图标、动画
	for id in defs:
		var d: Array = defs[id]
		var r: Dictionary = (t[TEMPLATE_SKILL] as Dictionary).duplicate(true)
		r.id = id
		r._gojo = true
		r.name = d[0]
		r.hitType = d[1]
		r.scope = d[2]
		r.iconIndex = d[4]
		r.animationId = d[5]
		r.tpCost = 0
		r.mpCost = 0
		r.stypeId = 1
		r.effects = []
		r.damage.type = d[3]
		r.damage.elementId = 0
		r.damage.critical = d[3] == 1
		r.damage.erase("formulaIssue")
		r.note = "<quality:13>\n<ici:9>\n<HelpWidth: 520>\n<pos=APs text=目标：%s size=18 color=rgba(255,255,255,1) line=false align=0>" % ("自己" if d[2] == 11 else "敌方全体" if d[2] == 2 else "敌方单体")
		if id == RED:
			r.effects = [{"code": 21, "dataId": ST_SLOW, "value1": 1, "value2": 0}]
		_set_module(r, "gojo" if id in [PURPLE_IN, PURPLE_OUT] else XTianqiSkills.MODULE)
		t[id] = XTianqiSkills.build(id, r) if XTianqiSkills.has(id) else r
		t[id].id = id
	var passives := {SIX_EYES: ["六眼", icon(11)], INFINITY: ["无下限", icon(12)], STRONGEST: ["最强", icon(13)], AWAKENING: ["黑闪觉醒：五条悟", icon(14)],
		ADV[0]: ["进阶·茈收束", icon(15)], ADV[1]: ["进阶·茈贯穿", icon(16)], ADV[2]: ["进阶·自动反转", icon(17)], ADV[3]: ["进阶·领域强化", icon(10)]}
	for id in passives:
		var r: Dictionary = (t[TEMPLATE_PASSIVE] as Dictionary).duplicate(true)
		r.id = id
		r._gojo = true
		r.name = passives[id][0]
		r.iconIndex = passives[id][1]
		r.note = "<quality:13>\n<ici:13>\n<Hide in Battle>\n<Max Mastery Level: 0>\n<No Damage Mastery Effect>\n<HelpWidth: 520>"
		t[id] = XTianqiSkills.build(id, r) if XTianqiSkills.has(id) else r
		t[id].id = id
	XTianqiGojoTrial.patch_skills(t)  # 专属试炼战影子的招（10651～10658）


static func patch_armors(t: Array) -> void:
	if not ENABLED or not _free(t, ARMOR, "护甲"):
		return
	var r: Dictionary = (t[TEMPLATE_ARMOR] as Dictionary).duplicate(true)
	r.id = ARMOR
	r._gojo = true
	r.name = "眼罩"
	r.description = "法宝\n五条悟遮住六眼的黑色眼罩。"
	r.iconIndex = icon(18)
	r.traits = []
	r.note = "<req_level:1>\n<req_actors: %d>\n<pos=APs text=\\c[2]专属：五条悟 size=18 color=rgba(255,255,255,1) line=false align=0>\n<pos=APs text=\\c[1]特效：虚式「茈」结算后，返还苍印、赫印各1 size=18 color=rgba(255,255,255,1) line=false align=0>" % ACTOR
	r.meta = XTianqiSkills.parse_meta(r.note)
	if r.get("equipment") is Dictionary:
		r.equipment.requirements = {"actors": [ACTOR]}
		r.equipment.variance = 0
	t[ARMOR] = r


static func wears_blindfold(a) -> bool:
	return own(a) and a.equip_list().any(func(e): return e is Dictionary and int(e.get("base", e.get("id", 0))) == ARMOR)


## 天启篇入队（XState.add_actor）：没戴眼罩就背包里拿或生成一件，装进装备类型 13 的槽
static func on_join(s, id: int) -> void:
	if not ENABLED or id != ACTOR or not XTianqi.active(s):
		return
	XTianqiGojoTrial.mark_table(s)  # 两阶进阶表版本（老天启篇档在读档时先迁移再记）
	var a: XActor = s.actor(ACTOR)
	var slot := a.equip_slots().find(ARMOR_SLOT_TYPE)
	if slot < 0 or wears_blindfold(a):
		return
	var idx: int = s.gear.find_custom(func(e): return e.kind == "armor" and int(e.base) == ARMOR)
	if idx < 0:
		s.gain_gear("armor", ARMOR, 1)
		idx = s.gear.size() - 1
	var item: Dictionary = s.gear[idx]
	s.gear.remove_at(idx)
	var worn = a.equips[slot]
	if worn is Dictionary and not worn.is_empty():
		s.gear.append(worn)
	a.equips[slot] = item
	a.refresh_passive()


## 这会儿哪些难度通关算数：证道开放了只认证道，没开放时临时也认炼狱
static func unlock_difficulties() -> Array:
	return [UNLOCK_DIFFICULTY_BEFORE_OPEN, UNLOCK_DIFFICULTY] if BEFORE_ZHENGDAO_LIANYU and not XTianqi.ZHENGDAO_OPEN else [UNLOCK_DIFFICULTY]


## 骑士战（36 层）打赢后：证道（证道开放前是炼狱）、上场的人里有宿傩或甚尔，就解锁最强之名；返回这次是不是新解锁
static func strongest_check(s) -> bool:
	if not ENABLED or unlocked() or not XTianqi.active(s):
		return false
	if not unlock_difficulties().has(str(s.flags.tianqi.get("difficulty", ""))):
		return false
	if not _fighters.any(func(id): return UNLOCK_WITH.has(int(id))):
		return false
	if unlock_override >= 0:
		unlock_override = 1
	else:
		XConfig.set_flag(UNLOCK_KEY, true)
	return true


static func _set_module(r: Dictionary, module: String) -> void:
	r.damage.formula = "XGojo(a,b,%d)" % int(r.id)
	r.damage.formulaGd = r.damage.formula
	r.damage.formulaProgram = {"version": 1, "status": "module", "module": module}


static func patch_states(t: Array) -> void:
	if not ENABLED:
		return
	for id in range(ST_BLUE, LAST_STATE + 1):
		if not _free(t, id, "状态"):
			return
	var names := {ST_BLUE: "苍印·一", ST_BLUE + 1: "苍印·二", ST_BLUE + 2: "苍印·三", ST_RED: "赫印·一", ST_RED + 1: "赫印·二", ST_RED + 2: "赫印·三",
		ST_DOMAIN: "无量空处", ST_AWAKE: "觉醒：五条悟", ST_SLOW: "赫·减速"}
	var icons := {ST_BLUE: icon(3), ST_RED: icon(4), ST_DOMAIN: icon(10), ST_AWAKE: icon(14), ST_SLOW: 828}
	var notes := {ST_DOMAIN: "无量空处：用苍类赫印另＋1、用赫类苍印另＋1；敌人行动前判信息过载；五条悟的术式必中。",
		ST_AWAKE: "直接术式伤害×1.2，黑闪概率＋15%；咒力打击给较少的那种印＋1。持续后续3个完整回合。", ST_SLOW: "速度－10%"}
	for id in names:
		var r: Dictionary = (t[2640] as Dictionary).duplicate(true)  # 宿傩「看破·一」：没有特性、战斗结束去掉的显示状态
		r.id = id
		r._gojo = true
		r.name = names[id]
		r.iconIndex = icons.get(id, icons[ST_BLUE] if id < ST_RED else icons[ST_RED])
		r.note = "<BuffType:%s>\n<StateNote>%s</StateNote>" % ["减益" if id == ST_SLOW else "祝福", notes.get(id, names[id])]
		r.meta = XTianqiSkills.parse_meta(r.note)
		if id == ST_SLOW:
			r.traits = [{"code": 21, "dataId": 6, "value": 0.9}]
			r.autoRemovalTiming = 2
			r.minTurns = 1
			r.maxTurns = 1
		t[id] = r
	XTianqiGojoTrial.patch_states(t)  # 专属试炼战：伏魔御厨子、领域对拼（2801、2802）


## 进阶四次（照狗逍遥的花费；每次另学通用的超越极限 I～IV）。试炼版（XTianqiGojoTrial.on，设计 v0.3）：两次（25／55 级），条件另加打赢试炼
static func patch_plugins(p: Dictionary) -> void:
	if not ENABLED or not p.get("Star_ActorAdvanced") is Dictionary:
		return
	var adv: Dictionary = p.Star_ActorAdvanced
	if XTianqiGojoTrial.on():
		var two := XTianqiGojoTrial.advance_rows()
		for i in two.size():
			var key2 := "Advanced %d" % (ADVANCE_ROW + i)
			if str(adv.get(key2, "")).strip_edges() != "":
				push_error("XGojo: 进阶行 %s 已被占用" % key2)
				return
			adv[key2] = JSON.stringify(two[i])
		return
	var rows := [[0, 50, 100000, "[[186,1]]", 1240], [1, 60, 500000, "[[186,2],[180,15]]", 1241], [2, 70, 100000, "[[186,3],[180,30]]", 1242], [3, 80, 100000, "[[186,6],[180,30]]", 1244]]
	for i in rows.size():
		var key := "Advanced %d" % (ADVANCE_ROW + i)
		if str(adv.get(key, "")).strip_edges() != "":
			push_error("XGojo: 进阶行 %s 已被占用" % key)
			return
		var r: Array = rows[i]
		adv[key] = JSON.stringify({"AdvancedName": "五条悟%s" % ["一阶", "二阶", "三阶", "四阶"][i], "AdvancedActNum": str(r[0]), "AdvancedActNumMaX": "4",
			"AdvancedActId": str(ACTOR), "AdvancedActLevel": str(r[1]), "AdvancedGold": str(r[2]), "AdvancedItem": r[3],
			"AdvancedSkiId": "[%d,%d]" % [r[4], ADV[i]], "AdvancedForId": "[]", "AdvancedNote": "\"\""})


# ---- 正式美术（content/gojo/，导出 03_转换工具/五条悟美术导出.py） ----
## 图标号 ICON_BASE＋序号（序号＝定稿任务号：2～10 主动、11～14 被动、15～17 进阶、18 眼罩），图在 icons/NN.png（128×128）；
## XUI.icon_texture 分流到这里。ART＝false 时技能、状态、眼罩照旧借原来的图标（开表时定）。
const ICON_BASE := 320000
const ICON_COUNT := 19
const ART_DIR := "res://content/gojo/"
const DOMAIN_BG := "res://content/gojo/domain_bg.png"
static var ART := true
static var _icons := {}
const _OLD_ICONS := {2: 64, 3: 512, 4: 426, 5: 72, 6: 512, 7: 426, 8: 467, 9: 467, 10: 5789, 11: 615, 12: 622, 13: 881, 14: 881, 15: 467, 16: 467, 17: 72, 18: 6410}


static func icon(n: int) -> int:
	return ICON_BASE + n if ART else int(_OLD_ICONS.get(n, 0))


static func is_icon(index: int) -> bool:
	return index >= ICON_BASE and index < ICON_BASE + ICON_COUNT


static func icon_texture(index: int) -> AtlasTexture:
	if _icons.has(index):
		return _icons[index]
	var p := ART_DIR + "icons/%02d.png" % (index - ICON_BASE)
	if not ResourceLoader.exists(p):
		return null
	var tex: Texture2D = load(p)
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(Vector2.ZERO, tex.get_size())
	_icons[index] = a
	return a


## 战斗画面：我方有五条悟的无量空处开着时，铺领域背景（battle_scene 每帧问）
static func domain_shown(logic) -> bool:
	if not ENABLED or not ART or logic == null:
		return false
	for a in _members(logic):
		if active_domain(a):
			return true
	return false


# ---- 公式 ----

## 茈：表里 gojo_pairs 按对数取满级系数（收 1.8／3.6／6.0，放 3.6／7.2／10.8），乘魔攻和等级缩放
static func formula(a, b, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if XTianqiGojoTrial.owns_skill(id):
		return XTianqiGojoTrial.formula(a, b, item)  # 专属试炼战影子的招
	var sp := XTianqiSkills.spec(id)
	var pairs: Array = sp.get("gojo_pairs", [])
	var n := int(cast.get("pairs", 0)) if own(a) else MARK_CAP
	if pairs.is_empty() or n < 1:
		return 0.0
	var coef := float(pairs[mini(n, pairs.size()) - 1])
	return maxf(0.0, float(a.mat) * coef * XTianqiSkills.level_scale(a))


# ---- 战斗内 ----
## 每人：blue／red 印数、last（"blue"／"red"／""）、guard_round 无下限用过的回合、again_round 六眼再动的回合、domain 剩余回合、reversed 自动反转用过
static var round := 0
static var cast := {}  # 本次行动：skill、pairs（茈开始时的对数）、again
static var _temp := {}
static var _queued = null
static var _fighters: Array = []  # 最近一场开战时出战的角色号（最强之名看「上场」，中途阵亡也算）


static func temp(a) -> Dictionary:
	if not _temp.has(a):
		_temp[a] = {"blue": 0, "red": 0, "last": "", "guard_round": -1, "again_round": -1, "domain": 0, "reversed": false}
	return _temp[a]


static func marks(a) -> Array:
	var d := temp(a)
	return [int(d.blue), int(d.red)]


static func pairs(a) -> int:
	return mini(int(temp(a).blue), int(temp(a).red))


static func shape(a) -> int:
	return PURPLE_IN if str(temp(a).last) == "blue" else PURPLE_OUT


static func active_domain(a) -> bool:
	return own(a) and int(temp(a).domain) > 0 and a.is_alive()


static func _members(logic) -> Array:
	return logic.actors.filter(func(x): return own(x))


static func _text(text: String) -> Dictionary:
	return {"type": "battle_text", "text": text}


static func _show(logic, a) -> void:
	var d := temp(a)
	for j in range(MARK_CAP):
		for base in [ST_BLUE, ST_RED]:
			if a.state_ids.has(base + j):
				logic._state_remove(a, base + j)
	if int(d.blue) > 0:
		logic._state_add(a, ST_BLUE + int(d.blue) - 1)
	if int(d.red) > 0:
		logic._state_add(a, ST_RED + int(d.red) - 1)


static func add_marks(logic, a, blue: int, red: int) -> void:
	var d := temp(a)
	d.blue = clampi(int(d.blue) + blue, 0, MARK_CAP)
	d.red = clampi(int(d.red) + red, 0, MARK_CAP)
	if logic != null:
		_show(logic, a)


static func _clear(logic, a) -> void:
	_temp.erase(a)
	if logic != null:
		for id in range(ST_BLUE, ST_DOMAIN + 1):
			if a.state_ids.has(id):
				logic._state_remove(a, id)


static func start_battle(logic) -> void:
	round = 0
	cast = {}
	_queued = null
	_temp.clear()
	_fighters = logic.actors.filter(func(x): return x is XActor).map(func(x): return int(x.actor_id))
	for a in _members(logic):
		_clear(logic, a)


static func end_battle(logic) -> void:
	XTianqiGojoTrial.end(logic)
	for a in _members(logic):
		_clear(logic, a)
	_temp.clear()
	cast = {}
	_queued = null


static func on_death(b) -> void:
	_temp.erase(b)


## startAction：茈记下开始时的对数；领域展开
static func begin(logic, u, skill: Dictionary) -> Array:
	XTianqiGojoTrial.check_awaken(logic)  # 专属试炼战怀玉：持续伤害等不经挨打的路掉到 30% 以下，下一个行动开始前补领悟
	cast = {}
	if not own(u) or XBattleLogic.is_item(skill) or skill.is_empty():
		return XTianqiGojoTrial.begin_action(logic, u, skill) if skill is Dictionary and not skill.is_empty() else []  # 专属试炼战：宿傩影子展开伏魔御厨子
	var id := int(skill.get("id", 0))
	cast = {"skill": id, "pairs": pairs(u)}
	if id == DOMAIN:
		temp(u).domain = DOMAIN_TURNS
		logic._state_add(u, ST_DOMAIN)
		if knows(u, ADV[3]):
			add_marks(logic, u, 1, 1)
		return [_text(u.display_name() + "展开了领域「无量空处」！")] + XTianqiGojoTrial.gojo_domain(logic)  # 专属试炼战：领域对拼
	return []


## endAction：加印、改 last、茈清印、六眼再动
static func finish(logic, u, skill) -> Array:
	XTianqiGojoTrial.check_awaken(logic)
	var logs: Array = XTianqiGojoTrial.take_logs(logic) + XTianqiGojoTrial.defeat_line(logic)  # 专属试炼战：天逆鉾拆印、领悟反转术式、影子压住、倒下的台词
	var id := int(skill.get("id", 0)) if skill is Dictionary and not skill.is_empty() else 0
	if not own(u) or id == 0 or not u.is_alive():
		cast = {}
		return logs
	var d := temp(u)
	var kind := "blue" if BLUE_SET.has(id) else "red" if RED_SET.has(id) else ""
	if kind != "":
		var n := 2 if id in [BLUE_MAX, RED_MAX] else 1
		var alternated := str(d.last) != "" and str(d.last) != kind
		var extra := 1 if active_domain(u) else 0
		if kind == "blue":
			add_marks(logic, u, n, extra)
		else:
			add_marks(logic, u, extra, n)
		d.last = kind
		if alternated and knows(u, SIX_EYES) and int(d.again_round) != round and logic._float("gojo_six_eyes") < AGAIN_RATE:
			d.again_round = round
			_queued = u
			logs.append(_text(u.display_name() + "的六眼看穿了术式的间隙，再次行动！"))
	elif id == REVERSE:
		add_marks(logic, u, 0, 1)
	elif id == STRIKE and XBlackFlash.awake(u):
		if int(d.blue) <= int(d.red):
			add_marks(logic, u, 1, 0)
		else:
			add_marks(logic, u, 0, 1)
	elif id in [PURPLE_IN, PURPLE_OUT]:
		d.blue = 0
		d.red = 0
		if wears_blindfold(u):
			d.blue = 1  # 眼罩：茈后返还苍印、赫印各 1
			d.red = 1
		_show(logic, u)
	cast = {}
	return logs


## 六眼再动：接在本次行动后（act 收尾，和镜流追加行动同一处）
static func queue_again(logic, u) -> void:
	if _queued == null or not is_same(_queued, u):
		return
	_queued = null
	if u.is_alive():
		logic.current_order.push_front(u)


static func end_round(logic) -> Array:
	var logs: Array = XTianqiGojoTrial.end_round(logic)  # 专属试炼战：伏魔御厨子的必中斩击（无量空处计时之前看对拼）
	for a in _members(logic):
		var d := temp(a)
		if int(d.domain) > 0:
			d.domain = int(d.domain) - 1
			if int(d.domain) == 0 and a.state_ids.has(ST_DOMAIN):
				logic._state_remove(a, ST_DOMAIN)
				logs.append(_text(a.display_name() + "的无量空处消散了。"))
	round += 1
	XTianqiGojoTrial.after_round(logic)  # 无量空处到期，对拼跟着结束
	return logs


## 信息过载：有五条悟的领域开着时，敌人每次行动前判一次，中了这次不能行动
static func overload(logic, u) -> bool:
	if not u is XEnemy or not u.is_alive():
		return false
	if XTianqiGojoTrial.clashing(logic):
		return false  # 专属试炼战领域对拼：信息过载失效
	for a in _members(logic):
		if active_domain(a):
			return logic._float("gojo_overload") < (OVERLOAD_BOSS if XBossStatus.is_boss(u) or XTianqiGojoTrial.is_shadow(logic, u) else OVERLOAD)
	return false


static func overload_text(u) -> Dictionary:
	return _text(u.display_name() + "陷入信息过载，无法行动！")


## 无下限：每回合第一次被敌人单体生命伤害攻击，有苍印就花 1 苍印整次拦下
static func infinity_block(logic, u, skill: Dictionary, t) -> bool:
	if not knows(t, INFINITY) or not t.is_alive() or not u is XEnemy or XBattleLogic.is_item(skill) or XTianqiGojoTrial.pierces_infinity(logic, skill):
		return false  # 专属试炼战：天逆鉾破术式
	if int(skill.get("scope", 0)) != 1 or int(skill.get("damage", {}).get("type", 0)) != 1:
		return false
	var d := temp(t)
	if int(d.guard_round) == round or int(d.blue) < 1:
		return false
	d.guard_round = round
	add_marks(logic, t, -1, 0)
	return true


## 自动反转（进阶三）：每场一次，挨打后生命低于 30% 立刻回复 30%
static func after_hit(logic, t) -> void:
	XTianqiGojoTrial.after_hit(logic, t)  # 专属试炼战怀玉：领悟反转术式（在自动反转之前）
	if not knows(t, ADV[2]) or not t.is_alive() or bool(temp(t).reversed) or float(t.hp) >= float(t.mhp) * AUTO_REVERSE_BELOW:
		return
	temp(t).reversed = true
	logic.gain_hp(t, floorf(float(t.mhp) * AUTO_REVERSE_HEAL))


## 五条悟专属：黑闪回最大 MP 10%
static func on_black_flash(u) -> void:
	if own(u):
		u.mp = minf(float(u.mmp), float(u.mp) + floorf(float(u.mmp) * MP_ON_FLASH))


## 六眼：交替时苍、赫不花 MP
static func mp_cost(a, skill: Dictionary, v: int) -> int:
	if not own(a) or not knows(a, SIX_EYES):
		return v
	var id := int(skill.get("id", 0))
	var kind := "blue" if id == BLUE else "red" if id == RED else ""
	var last := str(temp(a).last)
	return 0 if kind != "" and last != "" and last != kind else v


## meetsSkillConditions：茈要两种印都 ≥1、形状对
static func meets(a, skill: Dictionary) -> bool:
	if not own(a):
		return true
	var id := int(skill.get("id", 0))
	if id in [PURPLE_IN, PURPLE_OUT]:
		return pairs(a) >= 1 and shape(a) == id
	if id == DOMAIN:
		return not active_domain(a)
	return true


## 战斗技能列表：茈只列当前形状的那一招
static func listed(a, skill: Dictionary) -> bool:
	if not own(a):
		return true
	var id := int(skill.get("id", 0))
	return not (id in [PURPLE_IN, PURPLE_OUT]) or shape(a) == id


## 领域中术式必中
static func sure(u, skill: Dictionary) -> bool:
	return active_domain(u) and TECHNIQUES.has(int(skill.get("id", 0))) and not XTianqiGojoTrial.clashing()  # 专属试炼战领域对拼：必中失效


## 伤害钩子：进阶二 茈「放」无视 50% 防御
static func damage_ops(item: Dictionary, a) -> Array:
	if not knows(a, ADV[1]) or int(item.get("id", 0)) != PURPLE_OUT:
		return []
	return [{"op": "mul", "field": "physicalDefenseRate", "value": 0.5}, {"op": "mul", "field": "magicalDefenseRate", "value": 0.5}]


## 进阶一：茈「收」命中的敌人减速 10% 一回合
static func after_apply(logic, u, skill: Dictionary, t, r: Dictionary) -> void:
	XTianqiGojoTrial.after_apply(logic, u, skill, t, r)  # 专属试炼战怀玉：天逆鉾打掉 1 个印
	if knows(u, ADV[0]) and int(skill.get("id", 0)) == PURPLE_IN and t is XEnemy and t.is_alive() and not bool(r.get("missed", false)) and not bool(r.get("evaded", false)):
		logic._state_add(t, ST_SLOW)
