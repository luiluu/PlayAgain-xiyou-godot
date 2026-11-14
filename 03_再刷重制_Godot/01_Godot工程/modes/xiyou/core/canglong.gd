class_name XCanglong
extends RefCounted
## 【cc·未经审查】146 苍龙破晓重做（Kyo 11-11，O-314；方案见交付单 cc_rift2-canglong.md 与 00_设计/苍龙破晓数值/数值表.md）。
## 原版 v0.30 起停用并隐藏；职业 144 只给一个主动招「雷霆天罚*诛灭」，公式乘天海麒麟星的除魔值 v[1540]，苍龙自己攒不了，伤害恒为 0；
## 10093～10096 四招数据都在但职业表没有习得。本文件在 XDB.table 读 Skills／Classes／Armors 时就地打补丁：
## - 习得：玉玺禁章 10093 10 级、血浪 10094 20 级、飞霄 10095 30 级、诛灭 10092 50 级（原 2 级）、逐道 10096 60 级；三个被动不动。
## - 五招公式改走模块 "canglong"（XCanglong.formula），每段：
##   玉玺／血浪 (物攻＋魔攻)×(1＋熟练)×5000、飞霄 (物攻＋魔攻＋幸运)×(1＋熟练)×3200、诛灭 八项属性和×85000、
##   逐道 (物攻＋魔攻＋幸运)×TP×1000；全部再乘真龙之力 1＋等级²×2%（不封顶，Kyo 11-11 15:38／15:59）。
##   段数仍由各自的动作序列定（2／3／4／1／4），诛灭冷却 3 不变，逐道新加冷却 3。
## - 玉玺禁章去掉 9 类武器限制（说明本来就写「武器限制:无」）。
## - 文字：各招「伤害」行换成新公式；苍龙*破晓的「真龙之力:\v[1497]」（v1497 是传承强化·极，跟苍龙无关）换成真龙之力的说明；
##   法宝【上邪】137「专属:云无迹」改「专属:苍龙破晓」。
## 开关 REWORK＝false 后 clear_cache() 回原版数据。解放（停用、隐藏、号角）另见 XImportedBalance.RELEASE_CANGLONG。

static var REWORK := true
## O-待定：10091「觉醒*苍龙」说明补明雷霆天罚*诛灭+250%（与实际备注 SkillPass10092 一致，原版漏标）
static var FIX_10091_DESC := true

const ACTOR := 146
const CLASS := 144
const SHANGXIE := 137
const PASSIVE := 10089
const AWAKEN := 10091
const ZHUMIE := 10092
const YUXI := 10093
const XUELANG := 10094
const FEIXIAO := 10095
const ZHUDAO := 10096
const SKILLS := [ZHUMIE, YUXI, XUELANG, FEIXIAO, ZHUDAO]

## 每段倍率（数值表 v0.3，五回合木桩 70 级约 0.8 倍狂刀）
const RATE := {YUXI: 5000.0, XUELANG: 5000.0, FEIXIAO: 3200.0, ZHUMIE: 85000.0, ZHUDAO: 1000.0}

## 习得（等级, 技能），替换职业 144 的整张表
const LEARNINGS := [[2, PASSIVE], [10, YUXI], [20, XUELANG], [30, FEIXIAO], [33, 10090], [50, 10091], [50, ZHUMIE], [60, ZHUDAO]]

const _Z := "*(1+a.level*a.level*0.02)"
const FORMULAS := {
	YUXI: "(a.atk+a.mat)*(1+user.skillMasteryLevel(item.id))*5000" + _Z,
	XUELANG: "(a.atk+a.mat)*(1+user.skillMasteryLevel(item.id))*5000" + _Z,
	FEIXIAO: "(a.atk+a.mat+a.luk)*(1+user.skillMasteryLevel(item.id))*3200" + _Z,
	ZHUMIE: "(a.mmp+a.mhp+a.atk+a.mat+a.def+a.mdf+a.agi+a.luk)*85000" + _Z,
	ZHUDAO: "(a.atk+a.mat+a.luk)*a.tp*1000" + _Z,
}
const DAMAGE_TEXT := {
	YUXI: "(物攻+魔攻)*(1+技能等级)*5000*真龙之力",
	XUELANG: "(物攻+魔攻)*(1+技能等级)*5000*真龙之力",
	FEIXIAO: "(物攻+魔攻+幸运)*(1+技能等级)*3200*真龙之力",
	ZHUMIE: "全属性相加之和*85000*真龙之力",
	ZHUDAO: "(物攻+魔攻+幸运)*TP*1000*真龙之力",
}
const DRAGON_TEXT := "效果:真龙之力＝1+等级×等级×2%，独特技能伤害都乘它，不封顶"
const AWAKEN_TEXT := "苍龙独特技能伤害+125%（雷霆天罚*诛灭+250%）"
const _APS_TAIL := " size=18 color=rgba(255,255,255,1) line=false align=0"


## 按原版比的参照测试（xiyou_rules、xiyou_help_card 等）用：漩涡二阶段、苍龙重做、解放三个开关全关并清缓存，数据回到原版
static func original_data() -> void:
	XRift.STAGE2 = false
	XRift.clear_cache()
	REWORK = false
	FIX_10091_DESC = false
	clear_cache()
	XImportedBalance.RELEASE_CANGLONG = false


## 真龙之力：1＋等级²×2%
static func dragon_power(level: int) -> float:
	return 1.0 + float(level) * float(level) * 0.02


static func on() -> bool:
	return REWORK


## 清掉 XDB 里受影响的缓存，下次读按当前开关重新打补丁
static func clear_cache() -> void:
	for t in ["Skills", "Classes", "Armors"]:
		XDB._tables.erase(t)


## 模块公式（XFormulaExecution "canglong"）：每段伤害
static func formula(a, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if not RATE.has(id) or a == null:
		return 0.0
	var z := dragon_power(int(a.level))
	var rate: float = RATE[id]
	match id:
		YUXI, XUELANG:
			return (a.atk + a.mat) * (1.0 + a.skillMasteryLevel(id)) * rate * z
		FEIXIAO:
			return (a.atk + a.mat + a.luk) * (1.0 + a.skillMasteryLevel(id)) * rate * z
		ZHUMIE:
			return (a.mmp + a.mhp + a.atk + a.mat + a.def + a.mdf + a.agi + a.luk) * rate * z
		ZHUDAO:
			return (a.atk + a.mat + a.luk) * float(a.tp) * rate * z
	return 0.0


static func patch_skills(t) -> void:
	if not (t is Array):
		return
	if FIX_10091_DESC and t.size() > AWAKEN and t[AWAKEN] is Dictionary:
		_set_aps(t[AWAKEN], "\\c[1]效果", AWAKEN_TEXT)
	if not REWORK or t.size() <= ZHUDAO:
		return
	for id in SKILLS:
		var s = t[id]
		if not (s is Dictionary):
			continue
		s.damage.formula = FORMULAS[id]
		s.damage.formulaGd = str(FORMULAS[id]).replace("user.skillMasteryLevel(item.id)", "a.skillMasteryLevel(%d)" % id)
		s.damage.formulaProgram = {"version": 1, "status": "module", "module": "canglong"}
		_set_aps(s, "\\c[1]伤害", DAMAGE_TEXT[id])
	t[YUXI].requiredWtypeId1 = 0
	var zd: Dictionary = t[ZHUDAO]
	zd.meta["Cooldown"] = " 3"
	zd.note = str(zd.note).replace("<SkillTypes:", "<Cooldown: 3>\n<SkillTypes:")
	_set_aps(zd, "冷却时间", "3回合")
	var p = t[PASSIVE]
	if p is Dictionary:
		# 说明只读 note 的 APs 行（XHelpCard），meta 里同键的旧值去掉即可
		p.meta.erase("pos=APs text=\\c[1]真龙之力")
		p.note = RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\]真龙之力:[^>]*>").sub(str(p.note), "<pos=APs text=\\c[1]" + DRAGON_TEXT + _APS_TAIL + ">")


static func patch_classes(t) -> void:
	if not REWORK or not (t is Array) or t.size() <= CLASS or not (t[CLASS] is Dictionary):
		return
	t[CLASS].learnings = LEARNINGS.map(func(l): return {"level": l[0], "skillId": l[1], "note": ""})


static func patch_armors(t) -> void:
	if not REWORK or not (t is Array) or t.size() <= SHANGXIE or not (t[SHANGXIE] is Dictionary):
		return
	var a: Dictionary = t[SHANGXIE]
	a.note = str(a.note).replace("专属:云无迹", "专属:苍龙破晓")
	for k in a.get("meta", {}).keys():
		if str(k).contains("专属") and str(a.meta[k]).begins_with("云无迹"):
			a.meta[k] = str(a.meta[k]).replace("云无迹", "苍龙破晓")


## 说明行 <pos=APs text=键:值 ...>：note 和 meta 一起改
static func _set_aps(s: Dictionary, key: String, value: String) -> void:
	var mk := "pos=APs text=" + key
	var note := str(s.note)
	var re := RegEx.create_from_string("<pos=APs text=" + _re_escape(key) + ":[^>]*?" + _re_escape(_APS_TAIL) + ">")
	s.note = re.sub(note, "<pos=APs text=" + key + ":" + value + _APS_TAIL + ">")
	if s.get("meta", {}).has(mk):
		s.meta[mk] = value + _APS_TAIL


static func _re_escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if "\\^$.|?*+()[]{}".contains(ch) else ch
	return out
