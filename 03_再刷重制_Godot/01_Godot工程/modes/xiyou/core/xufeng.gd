class_name XXufeng
extends RefCounted
## 【小A·未经审查】西游档 152 徐凤年数值重做（D272，Kyo 11-23 定案，T440）。
## 仅对西游档（XDB.table 读表就地打补丁＋XDB.rec 仅在非天启篇分派 9997 独立状态）生效；
## 天启篇徐凤年（skill_rework.json，T411）不受任何影响。
## 保留原版全部技能与状态机制（大黄庭、大帝转世、剑一～剑八、剑九、九阶基因锁、天下第一、
## 剑气滚龙壁·封印、真·剑九、绣冬、春雷、不朽法宝），去掉 9998 随目标血量无限膨胀的 b.hp*0.000015，
## 各乘区倍率与属性均匀调整（系数全整数，附则 E），西游档 50/70/75/80 级五回合木桩（满级法宝 99 级主口径）
## 均稳落在 1.15～1.25× 狂刀（70 级锚定 1.20× 狂刀）。
## 开关 REWORK = false 后 clear_cache() 回原版数据；原版参照测试由 XCanglong.original_data() 一并关闭。

static var REWORK := true

const ACTOR := 152
const SK_DAHUANGTING := 9985
const SK_DADI := 9986
const SK_SWORD_FIRST := 9987
const SK_SWORD_LAST := 9994
const SK_SWORD9 := 9995
const SK_GENELOCK := 9996
const SK_TIANXIA := 9997
const SK_GUNLONG := 9998
const ST_SHENG_SRC := 2525      # 公共状态「神秘成圣」（9984/9997/10512 共用），原件不动
const ST_TIANXIA := 19501       # 表外号段：西游档 9997 专属「神秘成圣」副本（不改 States 表长与 2525，不串天启篇）
const ST_TRUE_SWORD9 := 2539
const WPN_XIUDONG := 76
const ARM_CHUNLEI := 129
const ARM_FABAO := 143

## ---- 定稿参数（全部整数，附则 E） ----
## 9985 大黄庭：物攻加成百分比（原 150）
const DAHUANGTING_ATK_PCT := 100

## 9987～9994 剑一～剑八：[物理/寒冰伤%, 无视物理/寒冰抗性%, 固定伤害公式]
## 原版：[10/3/5e6, 15/5/2e7, 20/6/1e8, 25/8/1e9, 25/8/5e9, 25/8/3e10, 25/8/1.5e11, 25/8/1e12]
const SWORDS := {
	9987: [6, 2, 500000],
	9988: [8, 2, 2000000],
	9989: [10, 3, 10000000],
	9990: [12, 4, 50000000],
	9991: [14, 4, 200000000],
	9992: [16, 5, 1000000000],
	9993: [16, 5, 5000000000],
	9994: [18, 5, 20000000000],
}

## 9997 天下第一（80 级被动）＋ 表外状态 ST_TIANXIA（19501，保留神秘成圣双步机制）
const TIANXIA_STATE_PCT := 1     # 神秘成圣（19501）终伤 +1%、暴击再 +1%（原 2525 为 +70%/+70%）
const TIANXIA_HARM := 1          # 终伤/爆伤 +%（原 200）
const TIANXIA_ELUP := 1          # 全属性伤害 +%（原 180）
const TIANXIA_DEHARM := 10       # 无视所有抵抗 %（原 30）
const TIANXIA_STAT_PCT := 1      # 六维属性 +%（原 200）
const TIANXIA_MHP_FLAT := 20000  # 最大生命 +（原 100000）
const TIANXIA_MHP_PCT := 50      # 最大生命 +%（原 500）
const TIANXIA_MMP_FLAT := 10000  # 最大魔法 +（原 30000）
const TIANXIA_MMP_PCT := 50      # 最大魔法 +%（原 300）
const TIANXIA_CRIT_HIT := 50     # 暴击/命中 +%（原 500）
const TIANXIA_APLUS := 1         # 再次行动几率 %（原 100）

## 9998 剑气滚龙壁·封印（每段公式，去 b.hp*0.000015）与 State 2539 真·剑九
const GUNLONG_BASE := 666666     # 保留原版固定底数
const GUNLONG_ATK_MUL := 209000  # 物攻整数系数（原 3000 + b.hp*0.000015）
const ST2539_RATE := 2           # 真·剑九终伤加成整数倍（2 → +200%，原 5 → +500%）

## Armor 143 徐凤年·不朽法宝（保留全部 11 条 traits）
const FABAO_MMP_PCT := 200       # 魔法 *200%（原 300%）
const FABAO_CRIT_PCT := 100      # 暴击率 +100%（原 200%）
const FABAO_GROW_ALL := 12       # 每级全属性 +12（原 15）
const FABAO_GROW_MMP_EXTRA := 18 # 魔法额外 +18，即每级 +30（原额外 +35，即 +50）

## Weapon 76 绣冬 & Armor 129 春雷（75 级专属，保留 2301 紫炎与成长）
const GEAR_ATK_PCT := 150        # 物攻能力值 *150%（原 300%）
const GEAR_EL_AMP := 195         # 11 元素增幅 +195%（原 +600%）
const GEAR_HARM := 125           # 终伤/爆伤 +125%（原 +450%）
const XIUDONG_GROW := 6          # 绣冬 76 每级物攻/魔攻 +6（原 +10）

static var _st_tianxia_cache: Array = []  # [src_ref, copy_dict]
static var _st_2539_cache: Array = []     # [src_ref, copy_dict]
static var _sk9997_cache: Array = []      # [src_ref, copy_dict]


static func on() -> bool:
	return REWORK


## 仅在已载入西游档（非天启篇、非无存档静态表校验）时生效的状态／记录分派
static func xiyou_save_on() -> bool:
	return REWORK and XState.current != null and not XTianqi.active(XState.current)


## 原版参照测试用：关闭开关并清除受影响表缓存
static func original_data() -> void:
	REWORK = false
	clear_cache()


## 清掉 XDB 与 XActor 里受影响的缓存，下次读按当前开关重新打补丁
static func clear_cache() -> void:
	for t in ["Skills", "States", "Armors", "Weapons"]:
		XDB._tables.erase(t)
	_st_tianxia_cache.clear()
	_st_2539_cache.clear()
	_sk9997_cache.clear()
	XActor._magic_growth_cache.erase("armor:%d" % ARM_FABAO)
	XActor._custom_param_cache.erase("weapon:%d" % WPN_XIUDONG)
	XActor._custom_param_cache.erase("armor:%d" % ARM_CHUNLEI)
	XActor.read_touch()


## 西游档（非天启篇）2539 真·剑九读记录时返回副本（k = ST2539_RATE），不改 XDB.table("States")[2539] 原件，
## 避免破坏天启篇总账 damage_ledger 对 States 表原值的核对（xiyou_tianqi_live_sample）
static func state_2539_rec(base: Dictionary) -> Dictionary:
	if not REWORK or base.is_empty():
		return base
	if _st_2539_cache.size() == 2 and is_same(_st_2539_cache[0], base):
		return _st_2539_cache[1]
	var r: Dictionary = base.duplicate(true)
	for e in r.get("effects", []):
		for g in e.get("groups", []):
			for step in g.get("steps", []):
				if is_equal_approx(float(step.get("k", 0.0)), 5.0):
					step.k = float(ST2539_RATE)
	r.note = str(r.get("note", "")).replace("var finalRate = 5.0;", "var finalRate = %d.0;" % ST2539_RATE)
	_st_2539_cache = [base, r]
	return r


## 表外状态 ST_TIANXIA（19501）：从原版 2525 复制并均匀下调 finalRate／bonusRate，仅由 XDB.rec("States", 19501) 返回
static func tianxia_state_rec(t: Array) -> Dictionary:
	if not REWORK or ST_SHENG_SRC >= t.size() or not (t[ST_SHENG_SRC] is Dictionary):
		return {}
	var src: Dictionary = t[ST_SHENG_SRC]
	if _st_tianxia_cache.size() == 2 and is_same(_st_tianxia_cache[0], src):
		return _st_tianxia_cache[1]
	var r: Dictionary = src.duplicate(true)
	r.id = ST_TIANXIA
	var k := float(TIANXIA_STATE_PCT) / 100.0
	for e in r.get("effects", []):
		for g in e.get("groups", []):
			for step in g.get("steps", []):
				if is_equal_approx(float(step.get("k", 0.0)), 0.7):
					step.k = k
	r.note = str(r.get("note", "")).replace("var finalRate = 0.7;", "var finalRate = %.2f;" % k).replace("var bonusRate = 0.7;", "var bonusRate = %.2f;" % k)
	_st_tianxia_cache = [src, r]
	return r


## 西游档（非天启篇）9997 天下第一读记录时把开战状态 2525 重指向表外 19501；天启篇存档走原 2525 由 skill_rework.json 清除
static func skill_9997_rec(base: Dictionary) -> Dictionary:
	if not REWORK or base.is_empty():
		return base
	if _sk9997_cache.size() == 2 and is_same(_sk9997_cache[0], base):
		return _sk9997_cache[1]
	var r: Dictionary = base.duplicate(true)
	var old_k := "StartPushState%d" % ST_SHENG_SRC
	var new_k := "StartPushState%d" % ST_TIANXIA
	r.note = str(r.get("note", "")).replace("<%s:" % old_k, "<%s:" % new_k)
	var meta = r.get("meta", {})
	if meta is Dictionary and meta.has(old_k):
		var m2 := {}
		for k in meta.keys():
			m2[new_k if str(k) == old_k else k] = meta[k]
		r.meta = m2
	_sk9997_cache = [base, r]
	return r


static func patch_skills(t) -> void:
	if not REWORK or not (t is Array) or t.size() <= SK_GUNLONG:
		return
	_patch_9985(t[SK_DAHUANGTING])
	for id in SWORDS:
		_patch_sword(t[id], id, SWORDS[id])
	_patch_9997(t[SK_TIANXIA])
	_patch_9998(t[SK_GUNLONG])


static func patch_states(_t) -> void:
	pass  # 2539 与 19501 均经 XDB.rec 仅在西游档分派副本，不动 States 表原件（保天启篇总账 damage_ledger 一致）


static func patch_armors(t) -> void:
	if not REWORK or not (t is Array):
		return
	if t.size() > ARM_FABAO and t[ARM_FABAO] is Dictionary:
		_patch_fabao_143(t[ARM_FABAO])
	if t.size() > ARM_CHUNLEI and t[ARM_CHUNLEI] is Dictionary:
		_patch_chunlei_129(t[ARM_CHUNLEI])


static func patch_weapons(t) -> void:
	if not REWORK or not (t is Array) or t.size() <= WPN_XIUDONG or not (t[WPN_XIUDONG] is Dictionary):
		return
	_patch_xiudong_76(t[WPN_XIUDONG])


# ---- 逐项补丁 ----

static func _patch_9985(s) -> void:
	if not (s is Dictionary):
		return
	_replace_note_meta(s, "<passivePBST2:150%>", "<passivePBST2:%d%%>" % DAHUANGTING_ATK_PCT)
	if s.get("meta", {}).has("passivePBST2"):
		s.meta["passivePBST2"] = "%d%%" % DAHUANGTING_ATK_PCT
	_replace_note_meta(s, "物理攻击增加150%", "物理攻击增加%d%%" % DAHUANGTING_ATK_PCT)


static func _patch_sword(s, _id: int, cfg: Array) -> void:
	if not (s is Dictionary):
		return
	var el_pct: int = cfg[0]
	var de_pct: int = cfg[1]
	var flat_dmg: int = cfg[2]
	var old_flat := str(s.damage.formula)
	var f_str := str(flat_dmg)
	s.damage.formula = f_str
	s.damage.formulaGd = f_str
	if s.damage.get("formulaProgram") is Dictionary:
		for step in s.damage.formulaProgram.get("steps", []):
			if step is Dictionary and step.get("value") is Dictionary and str(step.value.get("op", "")) == "literal":
				step.value.value = float(flat_dmg)
	var meta: Dictionary = s.get("meta", {})
	var old_el := str(meta.get("passiveELUP01", "")).strip_edges()
	var old_de := str(meta.get("DepassiveHarmRe01", "")).strip_edges()
	for k in ["passiveELUP01", "passiveELUP03"]:
		_replace_tag(s, k, "%d%%" % el_pct)
	for k in ["DepassiveHarmRe01", "DepassiveHarmRe03"]:
		_replace_tag(s, k, " %d%%" % de_pct)
	_replace_note_meta(s, "伤害:%s " % old_flat, "伤害:%s " % f_str)
	if old_el != "" and old_de != "":
		_replace_note_meta(s, "物理/寒冰伤害+%s 无视敌人物理/寒冰抗性+%s" % [old_el, old_de],
			"物理/寒冰伤害+%d%% 无视敌人物理/寒冰抗性+%d%%" % [el_pct, de_pct])


static func _patch_9997(s) -> void:
	if not (s is Dictionary):
		return
	_replace_tag(s, "passiveCrHarmRi", str(TIANXIA_HARM))
	_replace_tag(s, "passiveHarmRi", str(TIANXIA_HARM))
	for i in range(1, 16):
		_replace_tag(s, "passiveELUP%02d" % i, "%d%%" % TIANXIA_ELUP)
	for i in range(1, 16):
		if i == 10:
			continue
		_replace_tag(s, "DepassiveHarmRe%02d" % i, " %d%%" % TIANXIA_DEHARM)
	for i in range(2, 8):
		_replace_tag(s, "passivePBST%d" % i, "%d%%" % TIANXIA_STAT_PCT)
	s.note = str(s.note).replace("<passivePBST0:100000>", "<passivePBST0:%d>" % TIANXIA_MHP_FLAT)
	s.note = str(s.note).replace("<passivePBST0:500%>", "<passivePBST0:%d%%>" % TIANXIA_MHP_PCT)
	s.note = str(s.note).replace("<passivePBST1:30000>", "<passivePBST1:%d>" % TIANXIA_MMP_FLAT)
	s.note = str(s.note).replace("<passivePBST1:300%>", "<passivePBST1:%d%%>" % TIANXIA_MMP_PCT)
	if s.get("meta", {}) is Dictionary:
		s.meta["passivePBST0"] = "%d%%" % TIANXIA_MHP_PCT
		s.meta["passivePBST1"] = "%d%%" % TIANXIA_MMP_PCT
	_replace_tag(s, "passiveXPBST1", str(TIANXIA_CRIT_HIT))
	_replace_tag(s, "passiveXPBST2", str(TIANXIA_CRIT_HIT))
	_replace_tag(s, "passiveAPLUS", "%d%%" % TIANXIA_APLUS)
	# 说明文字（兼容 XTextFix 把「终伤+200%」改为「伤害+200%」）
	_replace_note_meta(s, "你有100%的几率再次行动", "你有%d%%的几率再次行动" % TIANXIA_APLUS)
	if str(s.note).contains("爆伤+200%，终伤+200%"):
		_replace_note_meta(s, "爆伤+200%，终伤+200%", "爆伤+%d%%，终伤+%d%%" % [TIANXIA_HARM, TIANXIA_HARM])
	else:
		_replace_note_meta(s, "爆伤+200%，伤害+200%", "爆伤+%d%%，伤害+%d%%" % [TIANXIA_HARM, TIANXIA_HARM])
	_replace_note_meta(s, "所有伤害+180%", "所有伤害+%d%%" % TIANXIA_ELUP)
	_replace_note_meta(s, "暴击率+500%", "暴击率+%d%%" % TIANXIA_CRIT_HIT)
	_replace_note_meta(s, "命中率+500%", "命中率+%d%%" % TIANXIA_CRIT_HIT)
	_replace_note_meta(s, "所有属性+200%", "所有属性+%d%%" % TIANXIA_STAT_PCT)
	_replace_note_meta(s, "最大魔法值+30000 +300%", "最大魔法值+%d +%d%%" % [TIANXIA_MMP_FLAT, TIANXIA_MMP_PCT])
	_replace_note_meta(s, "最大生命值+100000 +500%", "最大生命值+%d +%d%%" % [TIANXIA_MHP_FLAT, TIANXIA_MHP_PCT])
	_replace_note_meta(s, "无视敌人所有抵抗30%", "无视敌人所有抵抗%d%%" % TIANXIA_DEHARM)


static func _patch_9998(s) -> void:
	if not (s is Dictionary):
		return
	var f_js := "(%d+a.atk*%d)*(1+user.skillMasteryLevel(item.id))" % [GUNLONG_BASE, GUNLONG_ATK_MUL]
	var f_gd := "(%d+a.atk*%d)*(1+a.skillMasteryLevel(%d))" % [GUNLONG_BASE, GUNLONG_ATK_MUL, SK_GUNLONG]
	s.damage.formula = f_js
	s.damage.formulaGd = f_gd
	var old_src: Dictionary = s.damage.get("formulaProgram", {}).get("source", {"table": "Skills", "id": SK_GUNLONG, "custom": false})
	s.damage.formulaProgram = {
		"version": 1,
		"source": old_src,
		"status": "pure",
		"capabilities": ["read.battler"],
		"locals": [],
		"steps": [{
			"op": "expr",
			"pos": 0,
			"value": {
				"op": "binary",
				"pos": 0,
				"operator": "*",
				"left": {
					"op": "binary",
					"pos": 1,
					"operator": "+",
					"left": {"op": "literal", "pos": 1, "value": float(GUNLONG_BASE)},
					"right": {
						"op": "binary",
						"pos": 8,
						"operator": "*",
						"left": {"op": "property", "pos": 8, "receiver": "a", "name": "atk"},
						"right": {"op": "literal", "pos": 14, "value": float(GUNLONG_ATK_MUL)},
					},
				},
				"right": {
					"op": "binary",
					"pos": 25,
					"operator": "+",
					"left": {"op": "literal", "pos": 25, "value": 1.0},
					"right": {
						"op": "read",
						"pos": 27,
						"receiver": "a",
						"name": "mastery",
						"args": [{"op": "literal", "pos": 50, "value": SK_GUNLONG}],
					},
				},
			},
		}],
		"result": "completion",
	}
	_replace_note_meta(s,
		"[666666+己·攻击力*3000+敌·生命值*0.00001]*[1+技能等级]",
		"[%d+己·攻击力*%d]*[1+技能等级]" % [GUNLONG_BASE, GUNLONG_ATK_MUL])
	_replace_note_meta(s, "老剑神李淳罡的绝学,消耗15tp", "老剑神李淳罡的绝学,消耗10tp")


static func _patch_fabao_143(a: Dictionary) -> void:
	for tr in a.get("traits", []):
		if int(tr.get("code", 0)) == 21 and int(tr.get("dataId", 0)) == 1:
			tr.value = float(FABAO_MMP_PCT) / 100.0
		elif int(tr.get("code", 0)) == 22 and int(tr.get("dataId", 0)) == 2:
			tr.value = float(FABAO_CRIT_PCT) / 100.0
	var mmp_per := FABAO_GROW_ALL + FABAO_GROW_MMP_EXTRA
	for tag in ["mhp", "atk", "mat", "def", "mdf", "agi", "luk"]:
		var old_t := "<%s Param +15 per Level>" % tag
		var new_t := "<%s Param +%d per Level>" % [tag, FABAO_GROW_ALL]
		_replace_note_meta(a, old_t, new_t)
		var mk_old := "%s Param +15 per Level" % tag
		var mk_new := "%s Param +%d per Level" % [tag, FABAO_GROW_ALL]
		if a.get("meta", {}).has(mk_old):
			a.meta.erase(mk_old)
			a.meta[mk_new] = true
	_replace_note_meta(a, "<mmp Param +50 per Level>", "<mmp Param +%d per Level>" % mmp_per)
	if a.get("meta", {}).has("mmp Param +50 per Level"):
		a.meta.erase("mmp Param +50 per Level")
		a.meta["mmp Param +%d per Level" % mmp_per] = true
	_replace_note_meta(a, "魔法*300%", "魔法*%d%%" % FABAO_MMP_PCT)
	_replace_note_meta(a, "法宝每级增加15全属性魔法额外+35", "法宝每级增加%d全属性魔法额外+%d" % [FABAO_GROW_ALL, FABAO_GROW_MMP_EXTRA])
	_replace_note_meta(a, "暴击率+200%", "暴击率+%d%%" % FABAO_CRIT_PCT)


static func _patch_xiudong_76(w: Dictionary) -> void:
	for tr in w.get("traits", []):
		if int(tr.get("code", 0)) == 21 and int(tr.get("dataId", 0)) == 2:
			tr.value = float(GEAR_ATK_PCT) / 100.0
	for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
		_replace_tag(w, "Element Amplify %d" % el, " +%d%%" % GEAR_EL_AMP)
	_replace_tag(w, "passiveHarmRi", str(GEAR_HARM))
	_replace_tag(w, "passiveCrHarmRi", str(GEAR_HARM))
	if w.get("customParams") is Dictionary and w.customParams.get("params") is Array:
		var ps: Array = w.customParams.params
		if ps.size() > 4:
			ps[2].level = float(XIUDONG_GROW)
			ps[4].level = float(XIUDONG_GROW)
	_replace_note_meta(w, "atk += user.level * 10; mat += user.level * 10;", "atk += user.level * %d; mat += user.level * %d;" % [XIUDONG_GROW, XIUDONG_GROW])
	_replace_note_meta(w, "造成所有伤害结果*350%", "造成所有伤害结果*249%")
	_replace_note_meta(w, "物理 、雷电 阴阳 混沌伤+600%", "物理 、雷电 阴阳 混沌伤+%d%%" % GEAR_EL_AMP)
	_replace_note_meta(w, "攻击力能力值*300%", "攻击力能力值*%d%%，爆伤与伤害+%d%%" % [GEAR_ATK_PCT, GEAR_HARM])
	_replace_note_meta(w, "每级+10)", "每级+%d)" % XIUDONG_GROW)


static func _patch_chunlei_129(a: Dictionary) -> void:
	var aplus_seen := 0
	var new_traits := []
	for tr in a.get("traits", []):
		if int(tr.get("code", 0)) == 21 and int(tr.get("dataId", 0)) == 2:
			tr.value = float(GEAR_ATK_PCT) / 100.0
			new_traits.append(tr)
		elif int(tr.get("code", 0)) == 61 and int(tr.get("dataId", 0)) == 0:
			aplus_seen += 1
			if aplus_seen == 1:
				new_traits.append(tr)  # 再动 +2 → +1
		else:
			new_traits.append(tr)
	a.traits = new_traits
	for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
		_replace_tag(a, "Element Amplify %d" % el, " +%d%%" % GEAR_EL_AMP)
	_replace_tag(a, "passiveHarmRi", str(GEAR_HARM))
	_replace_tag(a, "passiveCrHarmRi", str(GEAR_HARM))
	_replace_note_meta(a, "等级需求:1 ", "等级需求:75 ")
	_replace_note_meta(a, "造成所有伤害结果*350%", "造成所有伤害结果*249%")
	_replace_note_meta(a, "物理 、雷电 阴阳 混沌伤+600%", "物理 、雷电 阴阳 混沌伤+%d%%" % GEAR_EL_AMP)
	_replace_note_meta(a, "再动+2 ", "再动+1 ")
	_replace_note_meta(a, "攻击力能力值*300%", "攻击力能力值*%d%%，爆伤与伤害+%d%%" % [GEAR_ATK_PCT, GEAR_HARM])


# ---- 通用替换工具 ----

static func _replace_tag(rec: Dictionary, tag: String, new_val: String) -> void:
	var re := RegEx.create_from_string("<" + _re_escape(tag) + ":[^>]*>")
	var note := str(rec.get("note", ""))
	if re.search(note) != null:
		rec.note = re.sub(note, "<%s:%s>" % [tag, new_val], true)
	var meta = rec.get("meta", {})
	if meta is Dictionary and meta.has(tag):
		meta[tag] = new_val


static func _replace_note_meta(rec: Dictionary, old: String, rep: String) -> void:
	var note := str(rec.get("note", ""))
	if note.contains(old):
		rec.note = note.replace(old, rep)
	var meta = rec.get("meta", {})
	if meta is Dictionary:
		var updated := {}
		var changed := false
		for k in meta.keys():
			var ks := str(k)
			var nk: Variant = ks.replace(old, rep) if ks.contains(old) else k
			var v = meta[k]
			var nv: Variant = str(v).replace(old, rep) if (v is String and str(v).contains(old)) else v
			if nk != k or nv != v:
				changed = true
			updated[nk] = nv
		if changed:
			rec.meta = updated


static func _re_escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if "\\^$.|?*+()[]{}".contains(ch) else ch
	return out
