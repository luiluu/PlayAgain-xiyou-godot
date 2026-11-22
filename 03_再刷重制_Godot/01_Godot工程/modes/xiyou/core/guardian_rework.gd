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
## 后来加的各节自己的开关写在各节注释里：DOMAIN_OFF（T229 领域）、GROWTH_NERF（T302 成长招）、TRANSFORM_ANCHOR／TRANSFORM_IDENTITY（T317／T322 残血变身）、
## XINMO（T315 心魔对齐）、STRIP（T348 守层者清正值双闪暴闪回血，见文末）。「守层者的层」统一问 guardian_floor（敌人号 → 对齐过的心魔 → 变身前是守层者的），
## 楼层里别的敌人另记 META_FLOOR，只给出伤、伤害抵抗用（_floor），不算守层者。
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
## T317：守层者残血变身（30 层玉皇大帝→入魔 538，31／32 层→天道·魔神 929，33 层→天道·混沌至高 930）后：
## - 新敌人号不在守层者表里，出伤倍率（atk_scale）、伤害抵抗（harm_re）原来掉回「不是守层者」（出伤 ×1，31 层魔神一招团灭），
##   现在记下变身前的层（_floor 认的 META_FLOOR），出伤、伤害抵抗照本层守层者算；
## - 八项能力值倍率按新记录重算：每项乘「变身前原数据 ÷ 新记录原数据」，变身后能力值＝变身前（本层重锚后的数，含难度、血量重标），
##   不再拿女娲那份重锚倍率去乘魔神的原数据（物攻魔攻 2.36 倍、血 3.3 倍）。技能、行动表照新记录。
## 只管天启篇存档、楼层守层者（鸿钧借鸿蒙老祖的合成记录、骑士、七印不走这里）。回退：`XGuardianRework.TRANSFORM_ANCHOR = false`
static var TRANSFORM_ANCHOR := true
## T322（T317 核查 P2-1／P2-2）：变身前是守层者（guardian_floor > 0）的，变身后另记守层者身份（META_TRANSFORM），guardian_floor 认它：
## 成长招削弱（growth_on，每层 +12%、最多 3 层）、元素牌组（XTianqiElements 按本层守层者那副，不走新号的 dungeon_boss 或空牌组）、
## 首领判定（XTianqiElements.is_boss_enemy）、一刀切抗性折算（resistance）都照本层守层者。不改读 META_FLOOR：那个楼层小怪也记（_world），
## 读它会把同场小怪也当成守层者。变身前不是守层者（楼层小怪变身）的不记。随 TRANSFORM_ANCHOR 一起只管天启篇存档。
## 回退：`XGuardianRework.TRANSFORM_IDENTITY = false`（变身后成长、牌组、首领、抗性照新敌人号，与 T317 一致）。
static var TRANSFORM_IDENTITY := true
const META_TRANSFORM := "xgr_tf_guardian"
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
	if f <= 0:
		f = transform_floor(e)  # T322：变身后照本层守层者（心魔不算：它的成长招已滤掉，别的强化照原版）
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
		if str(rec.get("_ref", "")) == "xinmo":  # T315：心魔取对齐那层守层者的一档 × XINMO_ATK_PCT%
			var xf := int(rec.get("_xinmo_floor", 0))
			return float(XTianqiBase.guardian_table("atk_scale", ATK_SCALE).get(xf, ATK_SCALE.get(xf, 1.0))) * XINMO_ATK_PCT / 100.0
		return HONGJUN_SCALE if str(rec.get("_ref", "")) == "hongjun" else REF_SCALE
	return float(XTianqiBase.guardian_table("atk_scale", ATK_SCALE).get(f, ATK_SCALE.get(f, 1.0)))  # 期四总开关开着读新表（缺就退回旧表；T229 起缺的层逐层退回）


## T239 第 6 轮（D248 C，协调 11-21）：集火招。守层者每回合总出伤照 atk_scale 的续航口径（实测治疗＋合计生命÷目标回合），其中挑一招单体攻击
## （balance_table.guardian_phase4.focus[层] ＝ {"skill": 技能号, "scale": 倍率}）单独乘 scale，让它一下打掉目标约 40% 最大生命；其余招照 atk_scale。
## 只认守层者本身（敌人号或变身前是守层者的；心魔、鸿钧、七印里副本、骑士、同层小怪都不认）。量数（measure_atk ≥ 0）时不用，好按统一倍率量。
## 回退：`XGuardianRework.FOCUS = false`（集火招也照 atk_scale）。
## T363（Kyo 11-21 事项17 问2）：没有单体伤害招的层（12、15、25）表里写 "single": 1，那招在这名守层者手里改成只打一人（scope 1），
## 技能数据本身不动（别的敌人、角色用同一招照旧）；见 single_action。回退：`XGuardianRework.FOCUS_SINGLE = false`（照原范围）。
static var FOCUS := true
static var FOCUS_SINGLE := true


static func focus(e: XEnemy) -> Dictionary:
	if not FOCUS or not ATK or measure_atk >= 0.0 or not e.horseman.is_empty() or xinmo_floor(e) > 0 or not _on() or not XTianqiBase.on():
		return {}
	var f := guardian_floor(e)
	if f <= 0:
		return {}
	var g = XTianqiBalance.data().get("guardian_phase4", {})
	var t = g.get("focus", {}) if g is Dictionary else {}
	var row = t.get(str(f), {}) if t is Dictionary else {}
	if not row is Dictionary or int(row.get("skill", 0)) <= 0 or float(row.get("scale", 0.0)) <= 0.0:
		return {}
	return {"skill": int(row.skill), "scale": float(row.scale), "single": FOCUS_SINGLE and int(row.get("single", 0)) == 1}


## T363：BattleLogic.decide 敌人选好招之后调。这名守层者的集火招标了 single 时，把这一次行动的技能换成只打一人的副本
## （scope 2～6 → 1，目标照单体随机点名）；别的情况原样返回。
static func single_action(e, dec: Array) -> Array:
	if not e is XEnemy or not e.focus_single or e.focus_skill <= 0 or dec.is_empty() or not dec[0] is Dictionary:
		return dec
	var sk: Dictionary = dec[0]
	if int(sk.get("id", 0)) != e.focus_skill or not int(sk.get("scope", 0)) in [2, 3, 4, 5, 6]:
		return dec
	var one := sk.duplicate()
	one["scope"] = 1
	return [one, dec[1] if dec.size() > 1 else null]


## 守层者认敌人号；对齐过的心魔认它的层（T315）；楼层里别的敌人认 setup 记下的层（WORLD）
static func _floor(e: XEnemy) -> int:
	var f := guardian_floor(e)
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
	var f := guardian_floor(b)  # T315：对齐过的心魔按它的层
	if f == 0 or r >= 1.0:
		return r
	return minf(1.0, r / elem_factor(f))   # 只折回抗性；没有抗性条的系（水、风等）本来就是 1，不放大


static func neutral(b: XBattler) -> bool:
	return measure_neutral and b is XEnemy and guardian_floor(b) > 0



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
	if xinmo_on(logic):
		return  # T315：心魔战在幻化之后由 xinmo_setup 重标（这里早于 XZhenqi.troop_setup）
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


## 这只敌人按哪一层重锚能力值（鸿钧 34；31～33 层守层者认敌人号；对齐过的心魔认它的层；别的 0）
static func params_floor(e: XEnemy) -> int:
	var rec: Dictionary = e.horseman.get("rec", {})
	if str(rec.get("_ref", "")) == "hongjun":
		return 34
	if str(rec.get("_ref", "")) == "xinmo":
		return int(rec.get("_xinmo_floor", 0))  # T315：对齐过的心魔（31～33 层吃双防重锚；T285 暴击闪避按层封顶）
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


## T317：BattleLogic.enemy_transform 换敌人号之前调，记下本层与变身前的原数据（不含难度倍率）；不管的返回空
static func transform_before(e: XEnemy) -> Dictionary:
	if not TRANSFORM_ANCHOR or not _on() or e == null or not e.horseman.is_empty():
		return {}
	var f := _floor(e)
	if f <= 0:
		return {}
	var raw := []
	for i in range(8):
		raw.append(e.param_base_unscaled(i))
	return {"floor": f, "raw": raw, "guardian": guardian_floor(e)}


## T317：换完敌人号（refresh_passive 之前）调：新号不是守层者时记本层；八项倍率乘「变身前原数据 ÷ 新原数据」
static func transform_after(e: XEnemy, before: Dictionary) -> void:
	if before.is_empty() or e == null:
		return
	if floor_of(e.enemy_id) <= 0:
		e.set_meta(META_FLOOR, int(before.floor))
		if int(before.get("guardian", 0)) > 0:
			e.set_meta(META_TRANSFORM, int(before.guardian))  # T322：变身前是守层者才记身份
	elif e.has_meta(META_TRANSFORM):
		e.remove_meta(META_TRANSFORM)  # 变回守层者号：认敌人号
	var raw: Array = before.raw
	var changed := false
	for i in range(8):
		var now := e.param_base_unscaled(i)
		if now <= 0.0 or float(raw[i]) <= 0.0 or now == float(raw[i]):
			continue
		if not changed:
			e._rates = e._rates.duplicate()
			changed = true
		e._rates[i] = float(e._rates[i]) * float(raw[i]) / now
	if changed:
		e.param_mark_dirty()


# ---- 心魔对齐同层守层者（T315，D244 甲；Kyo 11-20「甲，不同境界的心魔也要有自己的特点」）----
## 天启篇心魔（立境，敌群 901 心魔／770 狗逍遥·心魔）整套按「当前通关层守层者」（XZhenqi.trial_ref 的参照敌人）重算后的口径走：
## - 记录：借 XEnemy.horseman 的合成记录口子（同鸿钧）。名字、外观、备注、经验金钱照心魔；能力值、特性、行动表换成参照守层者的
##   （XDB.rec，天启篇数据层改写过的照用），记录里 _ref＝"xinmo"、_xinmo_floor＝层。首领身份（霸体、首领属性）跟参照守层者。
## - 招式：借参照守层者的行动表（atk_scale 那张表就是按这些招反推的，借招才不会倒挂，T314 评审 P1-1），滤掉成长招、领域招、
##   放逐（XINMO_SKIP_SKILLS）、吸血 ≥ XINMO_LIFESTEAL_MAX% 的招和回血招（_heal_skill）；滤完没有能出手的招时补一个「攻击」。
## - 只认闭关开的心魔试炼（xinmo_trial）：25 层上行天打完嫦娥开的 770、公共事件 1600 开的 901 不算，照旧按楼层缩放、敌群页照跑。
## - 特性：借参照守层者的，去掉闪避、暴击闪避、魔法闪避、每回合回血的正值（XINMO_DROP_XPARAM，D244 甲「清掉双闪、暴闪、回血」）。
## - 血量：本层守层者重算后的血量（hp_base × 本档回合 × 守层者占本层那场原血量的份额）× XINMO_HP_PCT%；
##   出伤 atk_scale 取本层那一档 × XINMO_ATK_PCT%；伤害抵抗 harm_re、一刀切抗性 resistance、31～33 层双防 rescale_params 都按本层。
## - 敌群事件：901 第 3 回合强制 6104 与随机 6101～6104、770 第 1 回合霸者领域（CE1397／6068）、6055、放逐 6057、每 3 回合 6051～6053／6056
##   全部不跑（xinmo_troop 去掉敌群页，XDB.rec 调）。不带守层者领域、不带异化计量（大厅不在楼层上，按段异化本来就不认）。
## - 各境特点：xinmo_traits(logic, s)（xinmo_setup 末尾调，转 XTianqiXinmoTraits.setup；T316 v0.3、T318）。
## 只管天启篇存档。回退：`XGuardianRework.XINMO = false`（心魔照原版记录、敌群事件照跑，与 T315 之前一致）。
static var XINMO := true
const XINMO_TROOPS := [901, 770]
## 心魔血量、出伤取同层守层者的整数百分比（Kyo 没说按 100%）
const XINMO_HP_PCT := 100
const XINMO_ATK_PCT := 100
## 借来的行动表里不要的招：成长（4239 心魔原招；6101～6104、6106、6056 守层者成长）、霸者招（6051～6053、6055、6057 放逐）、放逐 2599、领域（DOMAIN_SKILLS）
const XINMO_SKIP_SKILLS := [4239, 6101, 6102, 6103, 6104, 6106, 6056, 6051, 6052, 6053, 6055, 6057, 2599]
## 吸血达到这个百分比的招不借（原版守层者、心魔的 5000%～15000% 吸血）
const XINMO_LIFESTEAL_MAX := 1000
## 特性 22（附加能力值）里去掉正值的项：1 闪避、3 暴击闪避、4 魔法闪避、7 每回合回血（D244 甲「清掉双闪、暴闪、回血」）
static var XINMO_DROP_XPARAM := [1, 3, 4, 7]   # 探针 --keep-xparam 置空＝照守层者留着（对照用）
const META_XINMO := "xgr_xinmo"
static var _xinmo_troops := {}
static var _ls_re := RegEx.create_from_string("(?i)<HP Life Steal:\\s*([\\d.]+)%?>")


## 这一场是不是要对齐的心魔战（天启篇存档、开关开、敌群 901／770、是闭关开的心魔试炼）
static func xinmo_on(logic) -> bool:
	return XINMO and logic != null and xinmo_trial(int(logic.troop_id)) and XTianqi.active(logic.state)


## 现在这场是不是闭关开的心魔试炼（XZhenqi.battle_setup 记下的 trial 非空、敌群号对得上）。
## 901／770 也被别处直接开（25 层上行天 Map147 EV001 打完嫦娥开 770、公共事件 1600 张三丰突破开 901），那些不经 pending_trial，不算，照旧走楼层缩放、敌群页照跑（T315 r2 P1-1）
static func xinmo_trial(troop_id: int) -> bool:
	return XINMO_TROOPS.has(troop_id) and not (XZhenqi.battle.get("trial", {}) as Dictionary).is_empty() and int(XZhenqi.battle.get("troopId", 0)) == troop_id


## 心魔对齐到的层（不是对齐过的心魔为 0）
static func xinmo_floor(e) -> int:
	if not e is XEnemy:
		return 0
	var rec: Dictionary = (e as XEnemy).horseman.get("rec", {})
	return int(rec.get("_xinmo_floor", 0)) if str(rec.get("_ref", "")) == "xinmo" else 0


## 守层者的层：守层者认敌人号，对齐过的心魔认它的层，守层者变身后认变身前的层（T322），别的 0
static func guardian_floor(e) -> int:
	if not e is XEnemy:
		return 0
	var f := xinmo_floor(e)
	if f <= 0:
		f = floor_of((e as XEnemy).enemy_id)
	return f if f > 0 else transform_floor(e)


## T322：守层者残血变身后记下的本层（没变过身、开关关、不是天启篇存档为 0）
static func transform_floor(e) -> int:
	if not TRANSFORM_IDENTITY or not e is XEnemy or not (e as XEnemy).has_meta(META_TRANSFORM) or not _on():
		return 0
	return int((e as XEnemy).get_meta(META_TRANSFORM, 0))


## XDB.rec("Troops", 901／770) 调：天启篇存档、开关开着、正在打闭关心魔试炼时去掉敌群页（心魔原版的成长、霸者领域、放逐都不跑）。
## XZhenqi.battle_setup 在 BattleLogic.setup 读敌群之前、整场有效，战斗结束清空。
static func xinmo_troop(id: int, base: Dictionary) -> Dictionary:
	if not XINMO or base.is_empty() or not _on() or not xinmo_trial(id):
		return base
	var hit = _xinmo_troops.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var r := base.duplicate()
	r["pages"] = []
	_xinmo_troops[id] = [base, r]
	return r


## 心魔的合成记录：心魔原记录（名字、外观、备注、经验金钱）＋参照守层者的能力值、特性（去双闪回血）、行动表（滤过）
static func xinmo_rec(shell: Dictionary, g: Dictionary, f: int) -> Dictionary:
	var rec: Dictionary = shell.duplicate(true)
	rec.params = g.get("params", shell.get("params", [])).duplicate()
	var traits := []
	for t in g.get("traits", []):
		if int(t.get("code", 0)) == XBattler.TRAIT_XPARAM and XINMO_DROP_XPARAM.has(int(t.get("dataId", -1))) and float(t.get("value", 0)) > 0.0:
			continue
		traits.append(t.duplicate())
	rec.traits = traits
	var acts := []
	for a in g.get("actions", []):
		var id := int(a.get("skillId", 0))
		if XINMO_SKIP_SKILLS.has(id) or DOMAIN_SKILLS.has(id):
			continue
		var sk := XDB.rec("Skills", id)
		var m := _ls_re.search(str(sk.get("note", "")))
		if m != null and float(m.get_string(1)) >= XINMO_LIFESTEAL_MAX:
			continue
		if _heal_skill(sk):
			continue  # 回血招（17 层治愈之歌回 40%、次级治疗术、魔力愈合、圣光术、清心咒等；D244 甲「清掉回血」，T315 r2 P1-3）
		acts.append(a.duplicate())
	if not acts.any(func(a): return not _passive_skill(int(a.get("skillId", 0)))):
		acts.append({"skillId": 1, "rating": 5, "conditionType": 0, "conditionParam1": 0, "conditionParam2": 0})
	rec.actions = acts
	rec["_ref"] = "xinmo"
	rec["_xinmo_floor"] = f
	rec["_xinmo_guardian"] = int(g.get("id", 0))
	return rec


## 行动表里的被动技能（伤害抵抗等，备注带 passive 标签、不打人；17～19 层「大地／暗黑／火焰吸收」那种没有范围或死后才满足的占位也算）
static func _passive_skill(id: int) -> bool:
	var sk := XDB.rec("Skills", id)
	if int(sk.get("damage", {}).get("type", 0)) != 0:
		return false
	return str(sk.get("note", "")).contains("<passive") or int(sk.get("scope", 0)) == 0


## 回血招：伤害类型 3（HP 回复）或带回复生命效果（code 11）
static func _heal_skill(sk: Dictionary) -> bool:
	if int(sk.get("damage", {}).get("type", 0)) == 3:
		return true
	return sk.get("effects", []).any(func(ef): return int(ef.get("code", 0)) == 11 and (float(ef.get("value1", 0)) > 0.0 or float(ef.get("value2", 0)) > 0.0))


## 心魔第 f 层的目标血量：本层守层者重算后的血量 × XINMO_HP_PCT%（守层者占本层那场原血量的份额）
static func xinmo_hp(f: int, guardian_id: int, s: XState) -> float:
	var g_hp := float(XDB.rec("Enemies", guardian_id).get("params", [0])[0])
	var share := g_hp / old_total(f) if old_total(f) > 0.0 else 1.0
	return hp_base(f) * turns(s) * share * XINMO_HP_PCT / 100.0


## BattleLogic.setup 里 XZhenqi.troop_setup（幻化）之后调：心魔换成参照守层者的合成记录，再按本层重标双防、血量。
## （XGuardianRework.setup 在幻化之前，心魔战在那里直接跳过。）
static func xinmo_setup(logic, s: XState) -> void:
	if not xinmo_on(logic):
		return
	var trial: Dictionary = XZhenqi.battle.get("trial", {})
	var ref: Dictionary = trial.get("ref", {})
	var gid := int(ref.get("enemyId", 0))
	var f := floor_of(gid)
	if gid <= 0 or f <= 0:
		return
	var g := XDB.rec("Enemies", gid)
	for e in logic.enemies:
		if e.hidden or not e.horseman.is_empty():
			continue
		var rec := xinmo_rec(e.data(), g, f)
		e.horseman = {"rec": rec, "knight": false}  # 借骑士战的合成记录口子：XEnemy.data() 读它；难度倍率照旧
		e.zq_ref = {}  # 能力值以合成记录为准（幻化的 zq_ref 会盖掉 data().params、倍数 ≠1 时偷乘攻击；T315 r2 P2-2）。zq_trial_loot 照留（不掉落）
		e.boss_difficulty_boss = XEnemy.boss_id(gid)
		e.set_meta(META_XINMO, f)
		e.refresh_passive()
		e.param_mark_dirty()
	rescale_params(logic)  # 31～33 层：双防按 guardian_params.json 重锚（心魔战里只有心魔）
	for e in logic.enemies:
		if not HP:
			e.recover_all()
		elif xinmo_floor(e) > 0 and float(e.mhp) > 0.0:
			_scale_hp(e, xinmo_hp(f, gid, s) / float(e.mhp))
	xinmo_traits(logic, s)  # HP 开关关着也调（T315 r2 P2-1）


## 各境心魔的特点（T316 v0.3，T318 接）：对齐、重标血量之后调，转 XTianqiXinmoTraits.setup（按 trial.target 挂一条，回退 XTianqiXinmoTraits.ENABLED）。
## 行动表里至少留一条能出手的招（xinmo_rec 滤空时补「攻击」1），给【影劫】等挑底招用。
static func xinmo_traits(logic, s: XState) -> void:
	XTianqiXinmoTraits.setup(logic, s)


# ---- T348 守层者清正值双闪、暴闪、每回合回血（Kyo 11-22 待办 10「清掉，再量三表」；照 T315 心魔的清法）----
## 天启篇存档里 1～33 层守层者（敌人名带「守层者」、在 TROOPS 那场里的），加 30～33 层残血变身的二阶段（入魔 538、天道·魔神 929、
## 天道·混沌至高 930），敌人记录（XDB.rec）的特性里去掉 STRIP_XPARAM 这几项的正值：闪避 1、暴击闪避 3、魔法闪避 4、每回合回血 7。
## 负值与别的 xparam 不动；状态、难度、词条给的照旧。34 层鸿钧借鸿蒙老祖 537 的记录（XTianqiSummit.setup 读 XDB.rec），跟着清。
## 心魔借的就是清过的守层者记录，xinmo_rec 再滤一遍不冲突。西游档原样返回。
## 回退：`XGuardianRework.STRIP = false`。量数：STRIP_XPARAM 改成 [3]（只清暴闪）／[7]（只清回血）等（brand_calib --strip-guardian=）。
static var STRIP := true
static var STRIP_XPARAM := [1, 3, 4, 7]
const STRIP_TRANSFORM := [538, 929, 930]
static var _strip_ids := {}
static var _strip_recs := {}


## 这个敌人号要不要清（只看号，不看存档；XDB.rec 调，读原表不走 XDB.rec 以免递归）
static func strip_touches(id: int) -> bool:
	if not STRIP:
		return false
	if _strip_ids.is_empty():
		var t = XDB.table("Enemies")
		for f in TROOPS:
			for m in XDB.rec("Troops", int(TROOPS[f])).get("members", []):
				var eid := int(m.get("enemyId", 0))
				if t is Array and eid > 0 and eid < t.size() and t[eid] is Dictionary and str(t[eid].get("name", "")).contains("守层者"):
					_strip_ids[eid] = int(f)
		for eid in STRIP_TRANSFORM:
			_strip_ids[int(eid)] = -1
	return _strip_ids.has(id)


## 清过的敌人记录（XDB.rec 调）：天启篇存档且开关开着才清，其余原样返回
static func strip_rec(id: int, base: Dictionary) -> Dictionary:
	if not STRIP or base.is_empty() or not _on():
		return base
	var key := str(STRIP_XPARAM)
	var hit = _strip_recs.get(id)
	if hit is Array and is_same(hit[0], base) and str(hit[2]) == key:
		return hit[1]
	var traits := []
	var dropped := false
	for t in base.get("traits", []):
		if int(t.get("code", 0)) == XBattler.TRAIT_XPARAM and STRIP_XPARAM.has(int(t.get("dataId", -1))) and float(t.get("value", 0)) > 0.0:
			dropped = true
			continue
		traits.append(t)
	var r := base
	if dropped:
		r = base.duplicate()
		r["traits"] = traits
	_strip_recs[id] = [base, r, key]
	return r
