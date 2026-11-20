class_name XGuardianRework
extends RefCounted
## 守层者按新成长重算（法宝与积分重构方案 v0.3 第三节、三之二节，O-402）。只管天启篇存档（现在的新开局；原版档照旧）。
## - ATK：守层者对我方的最终 HP 伤害乘 ATK_SCALE[层]（XEnemy.output_scale）。按基准队（弱者 4 人、等级与法宝按层上限、
##   精良以下装备）实测反推：守层者每回合打掉基准队合计生命的 1/6.4，即不治疗约 8 回合团灭。1～4 层原版就几乎不打人，不放大（取 1）。
## - RESIST：19 层起守层者自带的「伤害抵抗」（技能备注 passiveHarmRe，原版 5000～50 兆，24 层起把基准队每一下都扣成 0）
##   换成 RESIST_TABLE[层]，约等于基准队单下伤害中位数的 30%。
##   34 层鸿钧（借鸿蒙老祖那场、能力值 × rate）单独一档 HONGJUN_SCALE；七印里副本的敌人、七首之龙都按鸿蒙老祖重标能力值
##   （记录里 _ref），出伤一律乘 REF_SCALE（＝33 层的倍率：它们的攻击就是鸿蒙老祖的几成）。35、36 层骑士走自己的数值表，不在这里。
## - HP：守层者那场（含同场小怪）的总血量 ＝ HP_BASE[层] × 本档目标回合（寻常 6、艰险 8、九死 10、炼狱 12、证道 15），
##   各成员按原来的血量比例分；34 层鸿钧用 HP_BASE[34]。七印里副本的敌人（按鸿蒙老祖重标）血量一律乘
##   HP_BASE[33] × 本档回合 ÷ 鸿蒙老祖原血量。35、36 层骑士和七首之龙是天启篇自己的数值，不动。
##   ELEM：20 层起守层者九系一刀切的抗性（每系只受 50%～5%）折进血量：受到伤害时抗性 ÷ elem_factor（0.5 → 1），血量不再乘。
##   血量是按元素中性量的，这样九系、无属性、水风虚空混沌空间（数据里没抗性条）打上去都一样，回合数对得上。
##   吸收元素（19、28～33 层）照旧，等元素重做定了再说；元素重做去掉一刀切时把 ELEM 关掉即可。
##   HP_BASE 暂用基准队（只算等级、法宝、精良装备）每回合伤害的平滑值，Kyo 11-13 定改用虚拟玩家每层实队（C）重量，量好换表。
## - PARAMS（T237）：31～34 层守层者（女娲、伏羲、鸿蒙老祖、鸿钧）的物防、魔防按 tianqi_data/guardian_params.json 重锚到
##   「30 层玉皇大帝原数据 × 整数%」（期四我方 80 级攻击约 4000，原数据 3.3 万～48 万的物防把防御率压到下限 0.05）。
## - PARAMS_QIYIN（T245）：七印里副本的敌人、七首之龙（按鸿蒙老祖重标的，_ref qiyin／dragon）的物防、魔防，把参照的鸿蒙老祖
##   那一项换成表里 qiyin 行「30 层玉皇大帝原数据 × 整数%」（跟出伤、血量一样认 33 层一档），elite／boss／龙的 rate 照旧乘在上面。
## 回退：`XGuardianRework.ATK = false`；`XGuardianRework.HP = false`；`XGuardianRework.WORLD = false`（只改守层者）；`XGuardianRework.RESIST = false`；
## `XGuardianRework.PARAMS = false`（31～34 层守层者能力值照原数据）；`XGuardianRework.PARAMS_QIYIN = false`（七印里副本、七首之龙双防照鸿蒙老祖原数据）。
## 量数接口（tests/virtual_player/baseline_dps.tscn）：measure_resist、measure_neutral。

static var ATK := true
static var HP := true
## 楼层里别的敌人（小怪、副本首领、精英）跟着本层守层者一起缩：血量按「本层守层者新血量 ÷ 原血量」同比缩，
## 出伤、伤害抵抗用本层守层者那一档。层数按战斗所在地图（XDungeon.map_floor，沿地图树找「N层」）。
## 虚拟玩家 11-13 实测：只改守层者时 20 层的普通敌群 2.1 万亿血、打掉 0%，后面的层根本走不动。
static var WORLD := true
static var ELEM := true
static var RESIST := true
## T237：31～34 层守层者能力值按 guardian_params.json 重锚（见头注释）；false＝照原数据
static var PARAMS := true
## T245：七印里副本的敌人、七首之龙（按鸿蒙老祖重标的）双防按 guardian_params.json 的 qiyin 行重锚；false＝照鸿蒙老祖原数据
static var PARAMS_QIYIN := true
const PARAMS_PATH := "res://modes/xiyou/tianqi_data/guardian_params.json"
static var _params_data := {}

const ATK_SCALE := {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.00884, 6: 3.07, 7: 1.29, 8: 1.9, 9: 0.589, 10: 1.09, 11: 0.952,
	12: 0.511, 13: 0.946, 14: 0.0151, 15: 0.284, 16: 0.439, 17: 0.115, 18: 0.634, 19: 0.33, 20: 0.074, 21: 0.0303, 22: 0.0585,
	23: 0.0903, 24: 0.0243, 25: 0.0164, 26: 0.00149, 27: 0.0107, 28: 0.00191, 29: 0.00521, 30: 0.00417, 31: 0.00121,
	32: 0.000161, 33: 0.0000256}
const HP_BASE := {1: 583000, 2: 626000, 3: 672000, 4: 722000, 5: 775000, 6: 832000, 7: 893000, 8: 959000, 9: 1030000,
	10: 1110000, 11: 1190000, 12: 1280000, 13: 1370000, 14: 1470000, 15: 1580000, 16: 1700000, 17: 1820000, 18: 1960000,
	19: 2100000, 20: 2250000, 21: 2420000, 22: 2600000, 23: 2790000, 24: 3000000, 25: 3220000, 26: 3460000, 27: 3710000,
	28: 3980000, 29: 4280000, 30: 4590000, 31: 4930000, 32: 5300000, 33: 5690000, 34: 6110000}
const TURNS := {"xunchang": 6, "jianxian": 8, "jiusi": 10, "lianyu": 12, "zhengdao": 15}
const HONGJUN_SCALE := 0.0000109
const REF_SCALE := 0.0000256
const RESIST_TABLE := {19: 4500, 20: 4900, 21: 5500, 22: 6000, 23: 6700, 24: 7300, 25: 8100, 26: 8900, 27: 9900, 28: 10900,
	29: 12000, 30: 13300, 31: 14600, 32: 16200, 33: 17800}

## 每层守层者那场的敌群号（地图事件里「战斗后变量 20 加一」的那一场；5 层取群狼森林、7 层取科维努斯镇）
const TROOPS := {1: 4, 2: 5, 3: 8, 4: 22, 5: 28, 6: 39, 7: 52, 8: 53, 9: 67, 10: 69, 11: 109, 12: 110, 13: 111, 14: 118, 15: 138,
	16: 172, 17: 173, 18: 174, 19: 333, 20: 456, 21: 457, 22: 458, 23: 459, 24: 460, 25: 461, 26: 462, 27: 463, 28: 464, 29: 465,
	30: 466, 31: 467, 32: 468, 33: 469}

## 工具用：≥0 时守层者的伤害抵抗（技能备注 passiveHarmRe，20 层起 200 万～50 兆）一律换成这个值；-1 不动
static var measure_resist := -1.0
## 工具用：≥0 时守层者（含鸿钧、按鸿蒙老祖重标的）出伤倍率一律取这个值；-1 照表
static var measure_atk := -1.0

## 工具用：为真时我方打守层者一律按元素中性（抗性 1，不吸收、不免疫），量「不挑元素」的基准伤害
static var measure_neutral := false

static var _floor_of := {}

## 守层者领域关掉（T229，Kyo 11-19「220丙」：天启篇里交不交见面礼都不开）。只管天启篇存档、13～33 层守层者那场（34 层鸿钧借 469 同场）。
## 原版 13～19 层第 1 回合（变量 842＝0）调公共事件 1398 大道领域、强制 6069；20～30 层 1399 天道领域／交礼走 1400 伪领域，强制 6070／6071；
## 20～22 层首领血 ≤20%＋变量 853 再开 1399；30 层变身页、31～33 层第 1 回合与残血页的 1397 霸者领域／1399，强制 6068／6070。
## 关掉时：这几个公共事件只跑开头的 334「敌人完全恢复」（回满是阶段机制，不是领域；第 1 回合本来就满血），
## 后面加我方减益（696／698／695／1106）、守层者增益（691／686／1103／1104／1110／1108／44）、解我方 996／997／1008 都不跑；
## 强制的领域技能（全能力强化一级＋公共事件 1401 回满）不放。轮回困难 8111、天道屠灭／回归／放逐、破阵阶段状态等照旧。
## 回退：`XGuardianRework.DOMAIN_OFF = false`。
static var DOMAIN_OFF := true
const DOMAIN_EVENTS := [1397, 1398, 1399, 1400]
const DOMAIN_SKILLS := [6068, 6069, 6070, 6071]
const DOMAIN_FLOORS := [13, 33]


## 守层者成长招削弱＋改名（T302 第二步，Kyo 11-20「240不关。但是削弱和改名」）：6104（13～30 层随机）、6106（30 层必放）、6056（31～33 层必放）。
## 只管天启篇存档。改前：每层 +25%、封顶 4 层（×2）、回血 35／40%，8 回合有效血量约 ×1.75、第 12 回合起全属性 ×2。
## 改后（推荐档）：技能记录里回血 6104 10%、6106／6056 12%（growth_rec）；守层者（13～33 层，DOMAIN_FLOORS）自己的正向强化每层 +12%（XEnemy.param_buff_rate）、
## 最多 3 层（XEnemy.buff_limit），封顶 ×1.36，不再有「第 12 回合 ×2」。别的敌人用这三招时只吃到回血和改名，每层加成与封顶不变。
## 更轻一档（备选，交付单给 Kyo 选）：GROWTH_LAYER_PCT 8、GROWTH_CAP 2、GROWTH_HEAL 6104 5%／6106／6056 6%。
## 回退：`XGuardianRework.GROWTH_NERF = false`（名字、说明、回血、每层加成、封顶全部回原版）。
static var GROWTH_NERF := true
const GROWTH_SKILLS := [6104, 6106, 6056]
const GROWTH_LAYER_PCT := 12
const GROWTH_CAP := 3
const GROWTH_HEAL := {6104: 10, 6106: 12, 6056: 12}
## 名字与说明（待小A 审）
const GROWTH_TEXT := {
	6104: {"name": "伤痕淬体", "desc": ["效果：自身最大生命 +1 层（每层 +12%，最多 3 层）", "治疗：自身最大生命的 10%"]},
	6106: {"name": "裂隙共鸣", "desc": ["效果：自身最大生命与六项能力各 +1 层（每层 +12%，最多 3 层）", "治疗：自身最大生命的 12%"]},
	6056: {"name": "灾厄淬炼", "desc": ["效果：自身最大生命与六项能力各 +1 层（每层 +12%，最多 3 层）", "治疗：自身最大生命的 12%"]},
}
static var _growth_recs := {}


## 成长招改写后的技能记录（XDB.rec 调）：天启篇存档且开关开着才改，其余原样返回
static func growth_rec(id: int, base: Dictionary) -> Dictionary:
	if not GROWTH_NERF or not GROWTH_SKILLS.has(id) or base.is_empty() or not _on():
		return base
	var hit = _growth_recs.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var r: Dictionary = base.duplicate(true)
	var tx: Dictionary = GROWTH_TEXT[id]
	r.name = str(tx.name)
	r.description = "战技\n" + "\n".join(tx.desc)
	for e in r.get("effects", []):
		if int(e.get("code", 0)) == 11:
			e["value1"] = float(GROWTH_HEAL[id]) / 100.0
	var note := RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\][^>]*>").sub(str(r.get("note", "")), "", true)
	for line in tx.desc:
		note += "\n<pos=APs text=\\c[1]%s size=18 color=rgba(255,255,255,1) line=false align=0>" % str(line)
	r.note = note
	r.meta = XTianqiSkills.parse_meta(note)
	_growth_recs[id] = [base, r]
	return r


## 这个敌人吃不吃成长削弱：天启篇存档、开关开、本人是 13～33 层守层者
static func growth_on(e) -> bool:
	if not GROWTH_NERF or not e is XEnemy or not _on():
		return false
	var f := floor_of((e as XEnemy).enemy_id)
	return f >= DOMAIN_FLOORS[0] and f <= DOMAIN_FLOORS[1]


## 这场战斗的守层者领域关着没有（天启篇存档、13～33 层守层者敌群）
static func domain_off(logic) -> bool:
	if not DOMAIN_OFF or logic == null or not XTianqi.active(logic.state):
		return false
	for f in range(DOMAIN_FLOORS[0], DOMAIN_FLOORS[1] + 1):
		if int(TROOPS[f]) == int(logic.troop_id):
			return true
	return false


## 领域公共事件关掉时留下的指令：只留顶层的 334（敌人完全恢复），收尾补一条结束
static func domain_keep(ce_list: Array) -> Array:
	var out := []
	for c in ce_list:
		if int(c.get("code", 0)) == 334 and int(c.get("indent", 0)) == 0:
			out.append(c)
	out.append({"code": 0, "indent": 0, "parameters": []})
	return out


## 敌人号是哪一层的守层者（不是返回 0）
static func floor_of(enemy_id: int) -> int:
	if _floor_of.is_empty():
		for f in TROOPS:
			var t := XDB.rec("Troops", int(TROOPS[f]))
			for m in t.get("members", []):
				var id := int(m.get("enemyId", 0))
				if id > 0 and not _floor_of.has(id) and str(XDB.rec("Enemies", id).get("name", "")).contains("守层者"):
					_floor_of[id] = int(f)
	return int(_floor_of.get(enemy_id, 0))


## XEnemy.refresh_passive 末尾调：守层者的元素固定减伤
static func harm_re(e: XEnemy, table: Dictionary) -> Dictionary:
	var f := _floor(e)
	if f == 0 or table.is_empty():
		return table
	var v := measure_resist
	if v < 0.0:
		var rt := XTianqiBase.guardian_table("resist", RESIST_TABLE)  # 期四总开关开着读新表（T012-c 量；缺就退回旧表）
		if not rt.has(f):
			rt = RESIST_TABLE  # T229：新表缺这一层时逐层退回旧表
		if not RESIST or not rt.has(f) or not _on():
			return table
		v = float(rt[f])
	var out := {}
	for k in table:
		out[k] = v
	return out


## XEnemy.setup 末尾调：守层者的出伤倍率（不是守层者、没开、不是天启篇存档为 1）
static func atk_scale(e: XEnemy) -> float:
	var rec: Dictionary = e.horseman.get("rec", {}) if not bool(e.horseman.get("knight", false)) else {}
	var f := _floor(e) if e.horseman.is_empty() else 0
	var ref := rec.has("_ref")
	if f == 0 and not ref:
		return 1.0
	if measure_atk >= 0.0:
		return measure_atk
	if not ATK or not _on():
		return 1.0
	if ref:
		return HONGJUN_SCALE if str(rec.get("_ref", "")) == "hongjun" else REF_SCALE
	return float(XTianqiBase.guardian_table("atk_scale", ATK_SCALE).get(f, ATK_SCALE.get(f, 1.0)))  # 期四总开关开着读新表（缺就退回旧表；T229 起缺的层逐层退回）


## 守层者认敌人号；楼层里别的敌人认 setup 记下的层（WORLD）
static func _floor(e: XEnemy) -> int:
	var f := floor_of(e.enemy_id)
	return f if f > 0 else int(e.get_meta(META_FLOOR, 0))


const META_FLOOR := "xgr_floor"
static var _old_total := {}


## 第 f 层守层者那场原来的总血量（数据里的生命，不含难度倍率）
static func old_total(f: int) -> float:
	if not _old_total.has(f):
		var t := 0.0
		for m in XDB.rec("Troops", int(TROOPS.get(f, 0))).get("members", []):
			t += float(XDB.rec("Enemies", int(m.get("enemyId", 0))).get("params", [0])[0])
		_old_total[f] = t
	return float(_old_total[f])


static var _elem := {}


## 第 f 层守层者元素有效倍率：守层者身上「属性有效度」特性（code 11）各值的中位数，没有为 1
static func elem_factor(f: int) -> float:
	if not ELEM:
		return 1.0
	if not _elem.has(f):
		var vals := []
		for m in XDB.rec("Troops", int(TROOPS.get(f, 0))).get("members", []):
			var id := int(m.get("enemyId", 0))
			if floor_of(id) != f:
				continue
			for t in XDB.rec("Enemies", id).get("traits", []):
				if int(t.get("code", 0)) == 11:
					vals.append(float(t.get("value", 1.0)))
		vals.sort()
		_elem[f] = clampf(float(vals[vals.size() / 2]), 0.01, 1.0) if not vals.is_empty() else 1.0
	return float(_elem[f])


static func _on() -> bool:
	return XState.current != null and XTianqi.active(XState.current)


## XDamage 取抗性时调：守层者（含鸿钧）的抗性按本层一刀切的值折回 1（吸收、免疫不动）
static func resistance(b: XBattler, r: float) -> float:
	if not ELEM or r <= 0.0 or not b is XEnemy or not _on():
		return r
	var e := b as XEnemy
	var f := floor_of(e.enemy_id)
	if f == 0 or r >= 1.0:
		return r
	return minf(1.0, r / elem_factor(f))   # 只折回抗性；没有抗性条的系（水、风等）本来就是 1，不放大


static func neutral(b: XBattler) -> bool:
	return measure_neutral and b is XEnemy and floor_of((b as XEnemy).enemy_id) > 0



## 这一场是第几层的守层者那场（34＝鸿钧；不是返回 0）
static func troop_floor(logic) -> int:
	for e in logic.enemies:
		if str(e.horseman.get("rec", {}).get("_ref", "")) == "hongjun":
			return 34
	for f in TROOPS:
		if int(TROOPS[f]) == int(logic.troop_id):
			return int(f)
	return 0


## 第 f 层每回合基准血量：HP_BASE 是 11-13 带全队 ×6 实测的，去 ×6（XTianqiNoX6，O-470）开着时乘 1/6。
## 以后用虚拟玩家按去 ×6 后的伤害重量、换表时，把这里的 hp_unit 去掉。
static func hp_base(f: int) -> float:
	var t := XTianqiBase.guardian_table("hp_base", HP_BASE)  # 期四总开关开着读新表（T012-c 按新口径实机量，不再乘 hp_unit；缺就退回旧表照旧乘）
	if not is_same(t, HP_BASE) and t.has(f):  # T229：新表缺这一层（如 31～34 层没写）时逐层退回旧表，不按 0 取
		return float(t[f])
	return float(HP_BASE[f]) * XTianqiNoX6.hp_unit()


## 本档目标回合（不是天启篇五档的按艰险）
static func turns(s: XState) -> int:
	return int(TURNS.get(str(s.flags.get("tianqi", {}).get("difficulty", "")), 8))


## BattleLogic.setup 末尾（各种重标之后）调：守层者那场、鸿钧、七印里副本的血量
static func setup(logic, s: XState) -> void:
	if s == null or not XTianqi.active(s) or logic.enemies.is_empty():
		return
	rescale_params(logic)
	if not HP:
		return
	var qiyin: bool = logic.enemies.any(func(e): return str(e.horseman.get("rec", {}).get("_ref", "")) == "qiyin")
	if qiyin:
		var ref_hp := float(XDB.rec("Enemies", 537).get("params", [1])[0])
		for e in logic.enemies:
			if str(e.horseman.get("rec", {}).get("_ref", "")) == "qiyin":
				# 鸿蒙老祖原血量（含本档难度倍率）换成 33 层的目标血量，按这只占鸿蒙老祖的几成同比缩
				_scale_hp(e, hp_base(33) * turns(s) / maxf(1.0, ref_hp * float(e._rates[0])))
		return
	var f := troop_floor(logic)
	if f == 0:
		_world(logic, s)
		return
	if not HP_BASE.has(f):
		return
	var total := 0.0
	for e in logic.enemies:
		total += float(e.mhp)
	if total <= 0.0:
		return
	var k := hp_base(f) * turns(s) / total
	for e in logic.enemies:
		_scale_hp(e, k)


static func _scale_hp(e: XEnemy, k: float) -> void:
	e.set_meta(XTianqiNoX6.META_HP_K, float(e.get_meta(XTianqiNoX6.META_HP_K, 1.0)) * k)  # 守层者回血同比缩用（O-469）
	e._rates = e._rates.duplicate()
	e._rates[0] = float(e._rates[0]) * k
	e.param_mark_dirty()
	e.recover_all()



## 楼层里别的敌群：按所在地图的层同比缩血量，出伤、伤害抵抗跟本层守层者（天启篇骑士、七首之龙、按鸿蒙老祖重标的不动）
static func _world(logic, s: XState) -> void:
	if not WORLD:
		return
	var f := mini(XDungeon.map_floor(s.map_id), 33)
	if f <= 0 or not HP_BASE.has(f) or old_total(f) <= 0.0:
		return
	for e in logic.enemies:
		if not e.horseman.is_empty() or floor_of(e.enemy_id) > 0:
			continue
		e.set_meta(META_FLOOR, f)
		e.refresh_passive()
		# 本层守层者原总血量（乘本档难度倍率）→ 新总血量，同一比例
		_scale_hp(e, hp_base(f) * turns(s) / (old_total(f) * float(e._rates[0])))


## T237：31～34 层守层者能力值表（guardian_params.json）；读不到为空（不动）
static func params_data() -> Dictionary:
	if _params_data.is_empty():
		if XDataFile.missing(PARAMS_PATH):  # 发行包里没有
			return {}
		var f := FileAccess.open(PARAMS_PATH, FileAccess.READ)
		if f == null:
			push_error("XGuardianRework: 读不到 " + PARAMS_PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_params_data = parsed
		else:
			push_error("XGuardianRework: JSON 解析失败 " + PARAMS_PATH)
	return _params_data


## 这只敌人按哪一层重锚能力值（鸿钧 34；31～33 层守层者认敌人号；别的 0）
static func params_floor(e: XEnemy) -> int:
	var rec: Dictionary = e.horseman.get("rec", {})
	if str(rec.get("_ref", "")) == "hongjun":
		return 34
	if not e.horseman.is_empty():
		return 0  # 骑士、援军、七印里副本、七首之龙走自己的数值
	return floor_of(e.enemy_id)


## 第 f 层守层者第 i 项的目标原数据：30 层玉皇大帝（ref_enemy）同一项 × 表里的整数%；表里没写为 -1（不动）
static func params_target(f: int, i: int) -> float:
	var d := params_data()
	var row: Dictionary = d.get("floors", {}).get(str(f), {})
	for k in row:
		if int(d.get("stats", {}).get(k, -1)) == i:
			var ref_p: Array = XDB.rec("Enemies", int(d.get("ref_enemy", 534))).get("params", [])
			if i >= ref_p.size():
				return -1.0
			return roundf(float(ref_p[i]) * int(row[k]) / 100.0)
	return -1.0


## T245：七印里副本、七首之龙第 i 项的参照目标原数据：30 层玉皇大帝（ref_enemy）同一项 × qiyin 行的整数%（顶替鸿蒙老祖那一项）；没写为 -1（不动）
static func qiyin_target(i: int) -> float:
	var d := params_data()
	var row = d.get("qiyin", {})
	if not row is Dictionary:
		return -1.0
	for k in row:
		if int(d.get("stats", {}).get(k, -1)) == i:
			var ref_p: Array = XDB.rec("Enemies", int(d.get("ref_enemy", 534))).get("params", [])
			if i >= ref_p.size():
				return -1.0
			return roundf(float(ref_p[i]) * int(row[k]) / 100.0)
	return -1.0


## 这只敌人是不是七印里副本按鸿蒙老祖重标的（里副本精英、Boss，七首之龙）
static func is_qiyin_ref(e: XEnemy) -> bool:
	var r := str(e.horseman.get("rec", {}).get("_ref", ""))
	return r == "qiyin" or r == "dragon"


## BattleLogic.setup 末尾（鸿钧换记录、七印重标之后）调：
## - 31～34 层守层者表里写了的项，本只敌人这一项的倍率乘「目标原数据 ÷ 自己原数据」（自己原数据：鸿钧是乘过 summit rate 的合成记录）；
## - 七印里副本、七首之龙（T245）：记录是「鸿蒙老祖 × rate」，这一项的倍率乘「qiyin 目标 ÷ 鸿蒙老祖原数据」，rate 照旧。
## 难度倍率、首领倍率、线上异化照旧叠在上面；血量不在这里（HP_BASE）。
static func rescale_params(logic) -> void:
	if logic == null or not XTianqi.active(logic.state):
		return
	var ref_q: Array = []
	for e in logic.enemies:
		var f := params_floor(e)
		var qiyin := PARAMS_QIYIN and is_qiyin_ref(e)
		if not qiyin and (not PARAMS or f < 31 or f > 34):
			continue
		if qiyin and ref_q.is_empty():  # T245 复核 P3：命中七印重标的敌人才读七印表（普通战不碰）
			ref_q = XDB.rec("Enemies", int(XTianqiQiyin.data().get("rebase", {}).get("ref", 537))).get("params", [])
		var p: Array = ref_q if qiyin else e.data().get("params", [])
		var changed := false
		for i in range(1, 8):
			var want := qiyin_target(i) if qiyin else params_target(f, i)
			if want < 0.0 or i >= p.size() or float(p[i]) <= 0.0:
				continue
			if not changed:
				e._rates = e._rates.duplicate()
				changed = true
			e._rates[i] = float(e._rates[i]) * want / float(p[i])
		if changed:
			e.param_mark_dirty()
