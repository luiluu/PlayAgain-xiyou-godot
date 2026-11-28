class_name XXufeng
extends RefCounted
## 【小A·未经审查】西游档 152 徐凤年数值重做（D272，Kyo 11-23 定案，T440）。
## 仅在已载入西游档（XState.current != null 且非天启篇）时经 XDB.rec 返回重做副本，
## 不修改 XDB.table 共享原表，天启篇徐凤年（skill_rework.json，T411）与无存档表校验完全读原表。
## 读档时（XState.from_dict → XXufeng.after_load）按当前开关双向同步既有专属装备实例（76/129/143），
## 保留随机属性浮动、强化、等级经验与词缀。
## 保留原版全部技能与状态机制（大黄庭、大帝转世、剑一～剑八、剑九、九阶基因锁、天下第一、
## 剑气滚龙壁·封印、真·剑九、绣冬、春雷、不朽法宝），去掉 9998 随目标血量无限膨胀的 b.hp*0.000015，
## 各乘区倍率与属性均匀调整（系数全整数，附则 E），西游档 50/70/75(全套)/80(全套) 级五回合木桩（满级法宝 99 级主口径）
## 均稳落在 1.15～1.25× 狂刀（70 级锚定 1.20× 狂刀；75/80 级采用方案 B：绣冬承接主输出、春雷保留再动+1与生存成长及轻输出）。
## 开关 REWORK = false 后 clear_cache() 回原版数据；原版参照测试由 XCanglong.original_data() 一并关闭。

static var REWORK := true
## 剑一～剑九、九阶基因锁收口（T585，Kyo 11-27 事项 95 定「直接去掉经验锁，老档读档自动好」，O-686）：
## 原版 1704／1705 两条公共事件是空的（徐凤年原版停用、没做完），9996 自带经验 −100% 又没法撕开，正常升级卡死在 60 级。
## 开着时西游档：9996 去掉 passiveSPBST9 与公共事件、改不可点纯被动，卡面写已解开；
## 剑一～剑八场合改「永不」（同其它被动，菜单不再写「战斗专用」），删卡面打不出的「伤害:xxx」。
## 剑九 9995 不在这里改（Kyo 11-27 另开新卡做成主动战技）。
## 开战附伤状态 2530～2538、元素增伤与穿透照旧（D272 平衡不动）。只在 xiyou_save_on() 时经 rec 分派，天启篇不读。
## 回退：LOCK_FIX = false（回到 T440 口径：60 级起经验 −100%、基因锁可点但无事发生、剑一～剑八写「战斗专用」）。
static var LOCK_FIX := true
## 剑一·龙蛇、剑二·并蒂莲、剑三·三斤、剑九·六千里做成主动战技（T586，Kyo 11-27 事项 95「做成主动……避免徐凤年太超模，
## 还是符合我们标定的强度」；同日改口径：剑一～剑三有名字的也做主动、剑九开场冷却 1 回合后冷却 2、
## 「放完剑九当前回合就不能再行动了，下一回合全属性-50%」，O-待定）。
## 西游档副本：9987～9989、9995 改战技（stypeId 1、战斗中用），原被动加成标签（物理/寒冰伤、穿抗，D272）照留；
## 剑四～剑八照旧被动。剑九放完给自己挂表外状态「收剑」ST_SHOUJIAN（本回合剩下的行动作废）与「力竭」ST_LIJIE（下一回合全属性 ×50%）。
## 去掉 9995 的空公共事件 1704、Hide in Battle、空效果开战状态 2538。只在 xiyou_save_on() 时经 rec 分派，天启篇（skill_rework.json）不读。
## 回退：JIAN9 = false（回到 T585 口径：剑一～剑三纯被动、9995 原样）。
static var JIAN9 := true
## T586 R2：力竭在属性最外层 ×50%（装备、被动等比率照乘，实际属性真减半），施放当回合状态栏只列收剑。
## 设 false 回到 R1：力竭挂八项 −50% 能力值比率特性（与装备比率加算，全套时最大魔法只少约 25%）、收剑挂 +50% 抵消
static var LIJIE_MUL := true

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
const ST_TIANXIA := 19501       # 表外号段：西游档 9997 专属「神秘成圣」副本（仅西游档可读，不改 States 表长与 2525）
const ST_TRUE_SWORD9 := 2539
const ST_SHOUJIAN := 19502      # 表外号段：西游档剑九「收剑」（本回合不能再行动；复制自 29 眩晕改名，仅西游档可读）
const ST_LIJIE := 19503         # 表外号段：西游档剑九「力竭」（下一回合全属性 ×50%；仅西游档可读）
const ST_STUN_SRC := 29         # 原版「眩晕」（1 回合、回合末解除、不能行动）
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
const TIANXIA_STATE_PCT := 1  # 神秘成圣（19501）终伤、暴击各 +%（原 2525 70%；T440 1）（T586 v0.4 平摊）
const TIANXIA_HARM := 6  # 终伤/爆伤 +%（原 200；T440 1）（T586 v0.4 平摊）
const TIANXIA_ELUP := 5  # 全属性伤害 +%（原 180；T440 1）（T586 v0.4 平摊）
const TIANXIA_DEHARM := 30  # 无视所有抵抗 %（原 30；T440 10）（T586 v0.4 平摊）
const TIANXIA_STAT_PCT := 3  # 六维属性 +%（原 200；T440 1）（T586 v0.4 平摊）
const TIANXIA_MHP_FLAT := 50000  # 最大生命 +（原 100000；T440 20000）（T586 v0.4 平摊）
const TIANXIA_MHP_PCT := 250  # 最大生命 +%（原 500；T440 50）（T586 v0.4 平摊）
const TIANXIA_MMP_FLAT := 15000  # 最大魔法 +（原 30000；T440 10000）（T586 v0.4 平摊）
const TIANXIA_MMP_PCT := 150  # 最大魔法 +%（原 300；T440 50）（T586 v0.4 平摊）
const TIANXIA_CRIT_HIT := 250  # 暴击/命中 +%（原 500；T440 50）（T586 v0.4 平摊）
const TIANXIA_APLUS := 2  # 再次行动几率 %（原 100；T440 1）（T586 v0.4 平摊）

## 9998 剑气滚龙壁·封印（每段公式，去 b.hp*0.000015）与 State 2539 真·剑九
const GUNLONG_BASE := 666666         # 保留原版固定底数
const GUNLONG_ATK_MUL_888 := 92000  # 物攻整数系数（原 3000 + b.hp*0.000015；T468 法宝 99→888 折算开启口径；T440 130000；T586 剑九多给、9998 抵回）
const GUNLONG_ATK_MUL_99 := 139000  # 物攻整数系数（99 级法宝口径，SCALE_99_TO_888 关闭时联动回退；T440 209000）
const ST2539_RATE := 2               # 真·剑九终伤加成整数倍（2 → +200%，原 5 → +500%）

## Armor 143 徐凤年·不朽法宝（保留全部 11 条 traits）
const FABAO_MMP_PCT := 200       # 魔法 *200%（原 300%）
const FABAO_CRIT_PCT := 100      # 暴击率 +100%（原 200%）
const FABAO_GROW_ALL := 12       # 每级全属性 +12（原 15）
const FABAO_GROW_MMP_EXTRA := 18 # 魔法额外 +18，即每级 +30（原额外 +35，即 +50）

## Weapon 76 绣冬（75 级专属主手，方案 B：承接主要输出，保留 2301 紫炎与成长）
const XIUDONG_ATK_PCT_888 := 176     # 物攻能力值 *176%（原 300%；T468 法宝 99→888 折算开启口径）
const XIUDONG_ATK_PCT_99 := 137      # 物攻能力值 *137%（T440 原 99 级法宝口径，SCALE_99_TO_888 关闭时联动回退）
const XIUDONG_EL_AMP := 290      # 11 元素增幅 +290%（原 +600%）
const XIUDONG_HARM := 120        # 终伤/爆伤 +120%（原 +450%）
const XIUDONG_GROW := 4          # 绣冬 76 每级物攻/魔攻 +4（原 +10）

## Armor 129 春雷（75 级专属副手，方案 B：保留再动+1、完整生存成长 mhp*200/mmp*150/agi*25 与 2301 紫炎，配轻输出词条）
## T586 v0.4：春雷各项都有份（不再把终伤、成长压到 1%），物攻回 T440 的 105%
const CHUNLEI_ATK_PCT_888 := 105  # 物攻能力值 *%（原 300%；T440 105%）（T586 v0.4 平摊）
const CHUNLEI_ATK_PCT_99 := 105  # 物攻能力值 *%（SCALE_99_TO_888 关闭时联动回退；T440 105%）（T586 v0.4 平摊）
const CHUNLEI_EL_AMP := 90  # 11 元素增幅 +%（原 +600%；T440 45）（T586 v0.4 平摊）
const CHUNLEI_HARM := 25  # 终伤/爆伤 +%（原 +450%；T440 5）（T586 v0.4 平摊）
const CHUNLEI_ATK_GROW := 5  # 每级物攻/魔攻 +（原 +30；T440 1；生命 +200、魔法 +150、敏捷 +25 保留原值）（T586 v0.4 平摊）

## T586 主动四招：每段 (GUNLONG_BASE + 物攻×系数)×(1+熟练度)，与 9998 同形；系数整数、联动 SCALE_99_TO_888 [888 口径, 99 口径]
## 9998 每段 92000／148000（T586 第 3 轮同比，原按 130000／209000 定）、五段，下面「约 X 次 9998」都按此折算
const ACTIVE_SWORDS := {
	9987: {"name": "剑一·龙蛇", "hits": 1, "scope": 6, "mul": [69000, 110000], "mp": 0, "tp": 0, "tp_gain": 5, "cd": 0},     # 随机敌人四段，合计约 0.6 次 9998；每段命中回 TP；1 级就学会、1 级最大魔法只有 1，不耗 MP（方案原写 500MP）
	9988: {"name": "剑二·并蒂莲", "hits": 2, "scope": 2, "mul": [184000, 296000], "mp": 0, "tp": 20, "tp_gain": 0, "cd": 2},   # 敌方全体两段，每个敌人约 0.8 次
	9989: {"name": "剑三·三斤", "hits": 1, "scope": 1, "mul": [368000, 592000], "mp": 0, "tp": 30, "tp_gain": 0, "cd": 3},     # 单体一击约 0.8 次，50% 眩晕 1 回合
}
const SWORD3_STUN_PCT := 50
## T586 v0.4 平摊（Kyo 11-27「平摊一下削弱给其他地方」）：T440 没动的两条高档被动也分担削弱
const SK_SHENGZHE := 9976            # 圣者境界（60 级）
const SHENGZHE_HARM := 90            # 暴伤／终伤 +%（原 100）
const SK_JIANDAO := 10085            # 剑道唯吾（75 级）
const JIANDAO_ELUP := 275            # 物理伤 +%（原 350）
const JIAN9_HITS := 9
const JIAN9_ATK_MUL_888 := 361000  # 九段合计约 5.5 次 T440 的 9998（Kyo 11-28「剑9多给一点，因为背负的代价太大」）
const JIAN9_ATK_MUL_99 := 545000  # 99 级法宝口径
const JIAN9_TP := 50
const JIAN9_WARMUP := 2              # 预热：每回合开始减 1，到 0 才能用 → 2 即开场冷却 1 回合、第 2 回合起可用（T586 专项实测）
const JIAN9_COOLDOWN := 2            # 之后冷却 2 回合（战后冷却 −10 必清零）
const LIJIE_PARAM_PCT := 50          # 力竭：全属性 ×50%

static var _st_tianxia_cache: Array = []  # [src_ref, copy_dict]
static var _st_out_cache := {}            # 表外状态号 -> [src_ref, copy_dict]
static var _rec_cache := {}               # "Table:id" -> [base_ref, copy_dict]
static var _gear_tpl_cache := {}          # "kind:id" -> [orig_ref, rework_copy]


static func on() -> bool:
	return REWORK


## 9998 剑气滚龙壁·封印物攻倍率：联动 XMagicWeapon.SCALE_99_TO_888（开 130000，关回退 209000）
static func gunlong_atk_mul() -> int:
	return GUNLONG_ATK_MUL_888 if XMagicWeapon.SCALE_99_TO_888 else GUNLONG_ATK_MUL_99


## 76 绣冬物攻能力值百分比：联动 XMagicWeapon.SCALE_99_TO_888（开 176，关回退 137）
static func xiudong_atk_pct() -> int:
	return XIUDONG_ATK_PCT_888 if XMagicWeapon.SCALE_99_TO_888 else XIUDONG_ATK_PCT_99


## 129 春雷物攻能力值百分比：联动 XMagicWeapon.SCALE_99_TO_888（开 118，关 120）
static func chunlei_atk_pct() -> int:
	return CHUNLEI_ATK_PCT_888 if XMagicWeapon.SCALE_99_TO_888 else CHUNLEI_ATK_PCT_99


## 9995 剑九物攻系数：联动 XMagicWeapon.SCALE_99_TO_888
static func jian9_atk_mul() -> int:
	return JIAN9_ATK_MUL_888 if XMagicWeapon.SCALE_99_TO_888 else JIAN9_ATK_MUL_99


static func sword_atk_mul(id: int) -> int:
	var m: Array = ACTIVE_SWORDS[id].mul
	return int(m[0]) if XMagicWeapon.SCALE_99_TO_888 else int(m[1])


## 仅在已载入西游档（非天启篇、非无存档静态表校验）时生效的记录分派
static func xiyou_save_on() -> bool:
	return REWORK and XState.current != null and not XTianqi.active(XState.current)


## 原版参照测试用：关闭开关并清除受影响缓存
static func original_data() -> void:
	REWORK = false
	clear_cache()


## 清掉本模块与 XActor 里受影响的缓存（共享原表 XDB._tables 从未被修改，无需驱逐）
static func clear_cache() -> void:
	_st_tianxia_cache.clear()
	_st_out_cache.clear()
	_rec_cache.clear()
	_gear_tpl_cache.clear()
	for suffix in ["", ":xy"]:
		XActor._magic_growth_cache.erase("armor:%d%s" % [ARM_FABAO, suffix])
		XActor._custom_param_cache.erase("weapon:%d%s" % [WPN_XIUDONG, suffix])
		XActor._custom_param_cache.erase("armor:%d%s" % [ARM_CHUNLEI, suffix])
	XActor.read_touch()


## 本模块经 XDB.rec 改写哪些表内记录（仅在 xiyou_save_on() 时分派副本）
static func touches(table_name: String, id: int) -> bool:
	match table_name:
		"Skills":
			return id == SK_DAHUANGTING or id == SK_TIANXIA or id == SK_GUNLONG or SWORDS.has(id) \
				or (LOCK_FIX and id == SK_GENELOCK) or (JIAN9 and id == SK_SWORD9) or id == SK_SHENGZHE or id == SK_JIANDAO
		"States":
			return id == ST_TRUE_SWORD9
		"Armors":
			return id == ARM_FABAO or id == ARM_CHUNLEI
		"Weapons":
			return id == WPN_XIUDONG
	return false


## 西游档经 XDB.rec 取副本（缓存按原件引用与 SCALE_99_TO_888 状态校验，不改共享原表）
static func rec(table_name: String, id: int, base: Dictionary) -> Dictionary:
	if not REWORK or base.is_empty():
		return base
	var scale_tag := (":s1" if XMagicWeapon.SCALE_99_TO_888 else ":s0") + (":L1" if LOCK_FIX else ":L0") + (":J1" if JIAN9 else ":J0")
	var key := "%s:%d%s" % [table_name, id, scale_tag]
	var cached = _rec_cache.get(key)
	if cached is Array and cached.size() == 2 and is_same(cached[0], base):
		return cached[1]
	var r: Dictionary = base.duplicate(true)
	match table_name:
		"Skills":
			if id == SK_DAHUANGTING:
				_patch_9985(r)
			elif SWORDS.has(id):
				_patch_sword(r, id, SWORDS[id])
				if LOCK_FIX:
					_fix_sword_passive(r)
				if JIAN9 and ACTIVE_SWORDS.has(id):
					_patch_active_sword(r, id)
			elif id == SK_GENELOCK and LOCK_FIX:
				_fix_genelock(r)
			elif id == SK_SWORD9 and JIAN9:
				_patch_jian9(r)
			elif id == SK_SHENGZHE:
				_replace_tag(r, "passiveHarmRi", str(SHENGZHE_HARM))
				_replace_tag(r, "passiveCrHarmRi", str(SHENGZHE_HARM))
				_replace_note_meta(r, "暴击伤害、最终伤害各＋100%", "暴击伤害、最终伤害各＋%d%%" % SHENGZHE_HARM)
			elif id == SK_JIANDAO:
				_replace_tag(r, "passiveELUP01", "%d%%" % JIANDAO_ELUP)
				_replace_note_meta(r, "物理伤害+350%", "物理伤害+%d%%" % JIANDAO_ELUP)
			elif id == SK_TIANXIA:
				_patch_9997(r)
				_redirect_9997_state(r)
			elif id == SK_GUNLONG:
				_patch_9998(r)
		"States":
			if id == ST_TRUE_SWORD9:
				_patch_state_2539(r)
		"Armors":
			if id == ARM_FABAO:
				_patch_fabao_143(r)
			elif id == ARM_CHUNLEI:
				_patch_chunlei_129(r)
		"Weapons":
			if id == WPN_XIUDONG:
				_patch_xiudong_76(r)
	_rec_cache[key] = [base, r]
	return r


## 表外状态 ST_TIANXIA（19501）：从原版 2525 复制并均匀下调 finalRate／bonusRate，仅在西游档经 XDB.rec 返回
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


## 西游档表外状态（XDB.rec 分派入口）：19501 天下第一神秘成圣；T586 19502 收剑、19503 力竭
static func has_out_state(id: int) -> bool:
	return id == ST_TIANXIA or (JIAN9 and (id == ST_SHOUJIAN or id == ST_LIJIE))


static func out_state_rec(id: int, t: Array) -> Dictionary:
	if id == ST_TIANXIA:
		return tianxia_state_rec(t)
	if not REWORK or not JIAN9 or not (id == ST_SHOUJIAN or id == ST_LIJIE):
		return {}
	if ST_STUN_SRC >= t.size() or not (t[ST_STUN_SRC] is Dictionary):
		return {}
	var src: Dictionary = t[ST_STUN_SRC]
	var cached = _st_out_cache.get(id)
	if cached is Array and cached.size() == 2 and is_same(cached[0], src):
		return cached[1]
	var r: Dictionary = src.duplicate(true)
	r.id = id
	r.removeAtBattleEnd = true
	r.autoRemovalTiming = 2
	r.message3 = ""
	r.message4 = ""
	if id == ST_SHOUJIAN:
		# 29 眩晕：不能行动、持续 1、回合末解除 → 放剑九的这一回合剩下的行动作废
		r.name = "收剑"
		r.message1 = "%1收剑了！"
		r.message2 = "%1收剑了！"
		r.minTurns = 1
		r.maxTurns = 1
		if not LIJIE_MUL:
			var traits: Array = (r.get("traits", []) as Array).duplicate(true)
			for pid in 8:
				traits.append({"code": 21, "dataId": pid, "value": float(200 - LIJIE_PARAM_PCT) / 100.0})
			r.traits = traits
		r.note = "<BuffType:收剑>\n<StateNote>\n剑九已出，本回合不能再行动\n收剑期间属性不变，下一回合力竭：全属性-%d%%\n</StateNote>" % (100 - LIJIE_PARAM_PCT) if LIJIE_MUL else "<BuffType:收剑>\n<StateNote>\n剑九已出，本回合不能再行动\n</StateNote>"
	else:
		# 持续 2、回合末解除：挂上的这回合（收剑在，属性不变、状态栏不显示）＋下一整回合（八项属性 ×50%），能行动
		# T586 R2：不挂能力值比率特性——比率是加算 1＋Σ(值−1)（XBattler.traits_pi），装备 +100% 时 −50% 只剩少 25%；
		# 改在 XActor._param_now 最外层乘 lijie_param，同等条件下实际属性真减半
		r.name = "力竭"
		r.message1 = "%1力竭了！"
		r.message2 = "%1力竭了！"
		r.restriction = 0
		r.motion = 0
		r.minTurns = 2
		r.maxTurns = 2
		r.traits = []
		if not LIJIE_MUL:
			for pid in 8:
				r.traits.append({"code": 21, "dataId": pid, "value": float(LIJIE_PARAM_PCT) / 100.0})
		r.note = "<BuffType:力竭>\n<StateNote>\n全属性-%d%%\n</StateNote>" % (100 - LIJIE_PARAM_PCT)
	r.meta = XZhenqi.extract_meta(r.note)
	_st_out_cache[id] = [src, r]
	return r


## T586 R2：力竭生效中（收剑已解除）＝八项属性在最外层 ×LIJIE_PARAM_PCT%；收剑还在的施放当回合不减
static func lijie_active(b) -> bool:
	return JIAN9 and LIJIE_MUL and b.state_ids.has(ST_LIJIE) and not b.state_ids.has(ST_SHOUJIAN)

## XActor._param_now 最外层：力竭时属性乘 LIJIE_PARAM_PCT%（与装备、被动等各层相乘，不跟比率特性加算）
static func lijie_param(b, _i: int, v: float) -> float:
	if not lijie_active(b):
		return v
	return roundf(v * float(LIJIE_PARAM_PCT) / 100.0)

## 状态栏与侧栏格子：施放当回合力竭还没生效，不显示（收剑的说明里写了下一回合力竭）
static func lijie_hidden(b, id: int) -> bool:
	return id == ST_LIJIE and JIAN9 and LIJIE_MUL and b.state_ids.has(ST_SHOUJIAN)


# ---- 读档双向同步既有专属装备实例（P1-2） ----

## XState.from_dict 末尾调用：按当前 REWORK 开关与存档模式（仅西游档启用重做，天启篇与 REWORK=false 均还原原版）
## 双向同步角色已穿戴、背包及仓库中的 76 绣冬／129 春雷／143 不朽法宝实例，保留随机浮动 params、强化、等级经验与词缀。
static func after_load(s: XState) -> int:
	if s == null:
		return 0
	var want_rework := REWORK and not XTianqi.active(s)
	var all := s.gear.duplicate()
	for a in s.actors.values():
		all.append_array(a.raw_equip_list())
	for w in s.warehouses.values():
		for list in w.get("items", {}).values():
			for v in list:
				if v is Dictionary:
					all.append(v)
	var seen := []
	var changed := 0
	for item in all:
		if not (item is Dictionary) or seen.any(func(x): return is_same(x, item)):
			continue
		seen.append(item)
		if sync_gear_item(item, want_rework):
			changed += 1
	# 2525「神秘成圣」removeAtBattleEnd = false，旧档战斗后可能常驻在 152 身上；切换 REWORK 时清掉陈旧状态防双叠或残留
	var xf: XActor = s.actors.get(ACTOR)
	if xf != null:
		if want_rework and xf.state_ids.has(ST_SHENG_SRC) and not xf.skill_ids.has(9984) and not xf.skill_ids.has(10512):
			xf.state_ids.erase(ST_SHENG_SRC)
			xf.state_turns.erase(ST_SHENG_SRC)
			changed += 1
		elif not want_rework and xf.state_ids.has(ST_TIANXIA):
			xf.state_ids.erase(ST_TIANXIA)
			xf.state_turns.erase(ST_TIANXIA)
			changed += 1
	if changed > 0:
		for a in s.actors.values():
			a.refresh_passive()
	return changed


static func _is_xufeng_gear(kind: String, base_id: int) -> bool:
	return (kind == "weapon" and base_id == WPN_XIUDONG) or (kind == "armor" and (base_id == ARM_CHUNLEI or base_id == ARM_FABAO))


## 是否为本模块跟踪同步的三件徐凤年专属装备（76 绣冬 / 129 春雷 / 143 不朽法宝）
static func is_tracked_gear(item: Dictionary) -> bool:
	return _is_xufeng_gear(str(item.get("kind", "")), int(item.get("base", item.get("id", 0))))


## 按给定存档模式（仅西游档且 REWORK=true 启用重做，天启篇与 REWORK=false 均还原原版）同步单件装备实例；
## 供跨存档星级仓库（XStarWarehouse.deposit_gear / withdraw_gear）在存取瞬间调用，取出即可直接穿戴正确数值。
static func sync_gear_for_state(s: XState, item: Dictionary) -> bool:
	var want_rework := REWORK and s != null and not XTianqi.active(s)
	return sync_gear_item(item, want_rework)


static func _gear_pair(kind: String, base_id: int) -> Array:
	var tbl := "Weapons" if kind == "weapon" else "Armors"
	var arr = XDB.table(tbl)
	if not (arr is Array) or base_id <= 0 or base_id >= arr.size() or not (arr[base_id] is Dictionary):
		return []
	var orig: Dictionary = arr[base_id]
	var scale_tag := ":s1" if XMagicWeapon.SCALE_99_TO_888 else ":s0"
	var key := "%s:%d%s" % [kind, base_id, scale_tag]
	var cached = _gear_tpl_cache.get(key)
	if cached is Array and cached.size() == 2 and is_same(cached[0], orig):
		return cached
	var rw: Dictionary = orig.duplicate(true)
	if kind == "weapon" and base_id == WPN_XIUDONG:
		_patch_xiudong_76(rw)
	elif kind == "armor" and base_id == ARM_CHUNLEI:
		_patch_chunlei_129(rw)
	elif kind == "armor" and base_id == ARM_FABAO:
		_patch_fabao_143(rw)
	var pair := [orig, rw]
	_gear_tpl_cache[key] = pair
	return pair


static func _traits_prefix_eq(own: Array, prefix: Array) -> bool:
	if own.size() < prefix.size():
		return false
	for i in range(prefix.size()):
		if JSON.stringify(own[i]) != JSON.stringify(prefix[i]):
			return false
	return true


static func _traits_codes_match(own: Array, ref: Array) -> bool:
	if own.size() < ref.size():
		return false
	for i in range(ref.size()):
		if not (own[i] is Dictionary):
			return false
		if int(own[i].get("code", -1)) != int(ref[i].get("code", -2)) or int(own[i].get("dataId", -1)) != int(ref[i].get("dataId", -2)):
			return false
	return true


## 识别原版、当前 R1 或历史重做版本（如 R0 9da929fa4）的基础 traits 前缀长度，保留后面词缀／强化／符文之语追加的 traits
static func _base_trait_prefix_len(kind: String, base_id: int, own_traits: Array, orig_traits: Array, rw_traits: Array) -> int:
	if _traits_prefix_eq(own_traits, orig_traits):
		return orig_traits.size()
	if _traits_prefix_eq(own_traits, rw_traits):
		return rw_traits.size()
	if kind == "weapon" and base_id == WPN_XIUDONG:
		return orig_traits.size() if _traits_codes_match(own_traits, orig_traits) else -1
	if kind == "armor" and base_id == ARM_FABAO:
		return orig_traits.size() if _traits_codes_match(own_traits, orig_traits) else -1
	if kind == "armor" and base_id == ARM_CHUNLEI:
		if _traits_codes_match(own_traits, orig_traits) and is_equal_approx(float(own_traits[0].get("value", 0.0)), 3.0):
			return orig_traits.size()
		if _traits_codes_match(own_traits, rw_traits):
			return rw_traits.size()
	return -1


## 识别原版、当前 R1 或历史重做版本（如 R0 9da929fa4）的基础备注前缀长度，保留后面词缀／符文之语／自定义备注后缀
static func _base_note_prefix_len(kind: String, base_id: int, own_note: String, orig_note: String, rw_note: String) -> int:
	if own_note.begins_with(orig_note):
		return orig_note.length()
	if own_note.begins_with(rw_note):
		return rw_note.length()
	if kind == "weapon" and base_id == WPN_XIUDONG and own_note.begins_with("<req_level:75>"):
		var end_tag := "</Custom Parameters>"
		var pos := own_note.find(end_tag)
		return pos + end_tag.length() if pos >= 0 else -1
	if kind == "armor" and base_id == ARM_CHUNLEI and own_note.begins_with("<Custom Parameters>"):
		var end_tag := "<StartPushState2301: 100%>"
		var pos := own_note.find(end_tag)
		return pos + end_tag.length() if pos >= 0 else -1
	if kind == "armor" and base_id == ARM_FABAO and own_note.begins_with("<req_level:1>"):
		var m := RegEx.create_from_string("<luk Param \\+\\d+ per Level>").search(own_note)
		return m.get_end() if m != null else -1
	return -1


## 查找装备已形成的符文之语模板列表（按 item.runewords 顺序）
static func _runeword_templates(item: Dictionary, kind: String) -> Array:
	var out := []
	var rw_ids: Array = item.get("runewords", [])
	if rw_ids.is_empty():
		return out
	var table = XDB.table("Runewords")
	if not (table is Array):
		return out
	var tbl_name := "Weapons" if kind == "weapon" else "Armors"
	for raw_id in rw_ids:
		var rid := int(raw_id)
		for recipe in table:
			if recipe is Dictionary and int(recipe.get("id", -1)) == rid:
				var tid := XRunewords.template_id(recipe, item)
				if tid > 0:
					var tpl := XDB.rec(tbl_name, tid)
					if not tpl.is_empty():
						out.append(tpl)
				break
	return out


## 按目标模板＋词缀＋符文之语＋强化元素＋镶嵌宝珠重算基础元素增幅（覆盖原版／R0／R1 任意历史实例，同时保留所有合法叠加）
static func _expected_element_amplify(item: Dictionary, kind: String, target: Dictionary, rw_tpls: Array) -> Dictionary:
	var base_ea: Dictionary = target.get("yep", {}).get("elementAmplify", {})
	var out := {}
	for ek in base_ea:
		out[str(ek)] = float(base_ea[ek])
	var default_tbl := "Weapons" if kind == "weapon" else "Armors"
	for affix in item.get("affixIds", []):
		if not (affix is Dictionary):
			continue
		var af_rec := XDB.rec(str(affix.get("table", default_tbl)), int(affix.get("id", 0)))
		var af_ea: Dictionary = af_rec.get("yep", {}).get("elementAmplify", {})
		for ek in out:
			if af_ea.has(ek):
				out[ek] = float(out[ek]) + float(af_ea[ek])
	for tpl in rw_tpls:
		var tpl_ea: Dictionary = tpl.get("yep", {}).get("elementAmplify", {})
		for ek in out:
			if tpl_ea.has(ek):
				out[ek] = float(out[ek]) + float(tpl_ea[ek])
	for upg in item.get("upgrades", []):
		if not (upg is Dictionary) or not upg.has("item"):
			continue
		var u_item := XDB.rec("Items", int(upg.item))
		var u_rule := XGearUpgrade.rule(u_item)
		for eff in u_rule.get(kind, []):
			if eff is Dictionary and str(eff.get("op", "")) == "element":
				var ek := str(int(eff.get("element", 0)))
				if out.has(ek):
					out[ek] = float(out[ek]) + float(eff.get("value", 0.0))
	var orb_ea: Dictionary = _orb_element_amplify(item)
	for ek in out:
		if orb_ea.has(ek):
			out[ek] = float(out[ek]) + float(orb_ea[ek])
	return out


## 读取装备孔里宝珠加的元素增幅（直接调西游核心 XOrbs，不依赖天启篇脚本 XTianqiLedger，保证发行空壳零缺口）
static func _orb_element_amplify(eq: Dictionary) -> Dictionary:
	var out := {}
	var held: Array = eq.get("augmentSlotItems", [])
	if held.is_empty():
		return out
	var sock := XOrbs.socket_type(eq).to_upper()
	var num_re := RegEx.create_from_string("(?i)ELEMENT AMPLIFY[ ](\\d+):[ ]([\\+\\-]\\d+)[%％]")
	var name_re := RegEx.create_from_string("(?i)ELEMENT AMPLIFY[ ](.*):[ ]([\\+\\-]\\d+)[%％]")
	var els: Array = XDB.system().get("elements", []).map(func(n): return str(n).to_upper())
	for i in held.size():
		var gem := XOrbs.gem_in_slot(eq, i)
		if gem.is_empty():
			continue
		var lines: Array = XOrbs.parse(gem).attach.get(sock, [])
		for line in lines:
			var s := str(line)
			var m := num_re.search(s)
			if m:
				var ek := m.get_string(1)
				out[ek] = float(out.get(ek, 0.0)) + float(m.get_string(2)) / 100.0
			else:
				m = name_re.search(s)
				if m:
					var id: int = els.find(m.get_string(1).to_upper().strip_edges())
					if id > 0:
						var ek := str(id)
						out[ek] = float(out.get(ek, 0.0)) + float(m.get_string(2)) / 100.0
	return out


## 双向同步单件专属装备实例（原版／R0／R1 ↔ 目标状态）；已匹配时不写任何字段，返回是否改动。
static func sync_gear_item(item: Dictionary, want_rework: bool) -> bool:
	var kind := str(item.get("kind", ""))
	var base_id := int(item.get("base", item.get("id", 0)))
	if not _is_xufeng_gear(kind, base_id):
		return false
	var pair := _gear_pair(kind, base_id)
	if pair.size() != 2:
		return false
	var orig: Dictionary = pair[0]
	var rw: Dictionary = pair[1]
	var target: Dictionary = rw if want_rework else orig
	var changed := false

	# 1) traits：替换原版／R0／R1 基础前缀，保留词缀／强化／符文之语追加的 traits
	var own_traits: Array = item.get("traits", [])
	var orig_traits: Array = orig.get("traits", [])
	var rw_traits: Array = rw.get("traits", [])
	var tgt_traits: Array = target.get("traits", [])
	if not _traits_prefix_eq(own_traits, tgt_traits):
		var plen := _base_trait_prefix_len(kind, base_id, own_traits, orig_traits, rw_traits)
		if plen > 0:
			item.traits = tgt_traits.duplicate(true) + own_traits.slice(plen).duplicate(true)
			changed = true

	# 2) note：替换原版／R0／R1 基础备注前缀，保留词缀／符文之语等追加备注
	var own_note := str(item.get("note", ""))
	var orig_note := str(orig.get("note", ""))
	var rw_note := str(rw.get("note", ""))
	var tgt_note := str(target.get("note", ""))
	var replaced_old_note := ""
	if not own_note.begins_with(tgt_note):
		var nlen := _base_note_prefix_len(kind, base_id, own_note, orig_note, rw_note)
		if nlen > 0:
			replaced_old_note = own_note.left(nlen)
			item.note = tgt_note + own_note.substr(nlen)
			changed = true

	# 3) meta：按目标模板→词缀覆盖→符文之语同名数值合并（XRunewords.check 语义）同步差异键，并清理旧版备注遗留的陈旧键
	var orig_meta: Dictionary = orig.get("meta", {})
	var rw_meta: Dictionary = rw.get("meta", {})
	var tgt_meta: Dictionary = target.get("meta", {})
	var diff_keys := {}
	for k in orig_meta:
		if not rw_meta.has(k) or orig_meta[k] != rw_meta[k]:
			diff_keys[k] = true
	for k in rw_meta:
		if not orig_meta.has(k) or orig_meta[k] != rw_meta[k]:
			diff_keys[k] = true
	if replaced_old_note != "":
		for m in RegEx.create_from_string("<([^<>:]+)(?::[^>]*)?>").search_all(replaced_old_note):
			var mk := m.get_string(1)
			if not tgt_meta.has(mk):
				diff_keys[mk] = true
	var desired_meta := {}
	for k in diff_keys:
		if tgt_meta.has(k):
			desired_meta[k] = tgt_meta[k]
	var default_tbl := "Weapons" if kind == "weapon" else "Armors"
	for affix in item.get("affixIds", []):
		if not (affix is Dictionary):
			continue
		var af_rec := XDB.rec(str(affix.get("table", default_tbl)), int(affix.get("id", 0)))
		var af_meta: Dictionary = af_rec.get("meta", {})
		for k in af_meta:
			if diff_keys.has(k):
				desired_meta[k] = af_meta[k]
	var rw_tpls := _runeword_templates(item, kind)
	if not rw_tpls.is_empty():
		var numeric := RegEx.create_from_string("^\\s*(-?\\d+(?:\\.\\d+)?)\\s*(%?)\\s*$")
		var tag_re := RegEx.create_from_string("<([^<>:]+)(:?)([^>]*)>")
		for tpl in rw_tpls:
			for m in tag_re.search_all(str(tpl.get("note", ""))):
				var rk := m.get_string(1)
				if not diff_keys.has(rk):
					continue
				if m.get_string(2) != ":":
					desired_meta[rk] = true
					continue
				var old_m := numeric.search(str(desired_meta.get(rk, "")))
				var extra_m := numeric.search(m.get_string(3))
				desired_meta[rk] = " " + str(float(old_m.get_string(1)) + float(extra_m.get_string(1))) \
					+ (old_m.get_string(2) if old_m.get_string(2) != "" else extra_m.get_string(2)) if (old_m and extra_m) else m.get_string(3)
	var own_meta: Dictionary = item.get("meta", {})
	if not (own_meta is Dictionary):
		own_meta = {}
		item["meta"] = own_meta
	for k in diff_keys:
		if desired_meta.has(k):
			if not own_meta.has(k) or own_meta[k] != desired_meta[k]:
				own_meta[k] = desired_meta[k]
				changed = true
		elif own_meta.has(k):
			own_meta.erase(k)
			changed = true

	# 4) customParams（76 绣冬 / 129 春雷成长表）
	if target.has("customParams"):
		if JSON.stringify(item.get("customParams", {})) != JSON.stringify(target.customParams):
			item["customParams"] = target.customParams.duplicate(true)
			changed = true

	# 5) yep.elementAmplify（76 绣冬 / 129 春雷元素增幅；按目标模板＋词缀＋符文之语＋强化＋宝珠精确重算，覆盖 R0 600% 残留）
	if target.get("yep") is Dictionary and target.yep.get("elementAmplify") is Dictionary:
		var want_ea := _expected_element_amplify(item, kind, target, rw_tpls)
		var own_yep: Dictionary = item.get("yep", {}) if item.get("yep") is Dictionary else {}
		var own_ea: Dictionary = (own_yep.get("elementAmplify", {}) as Dictionary).duplicate() if own_yep.get("elementAmplify") is Dictionary else {}
		var ea_changed := false
		for ek in want_ea:
			var want_v := snappedf(float(want_ea[ek]), 0.0001)
			if not own_ea.has(ek) or not is_equal_approx(float(own_ea[ek]), want_v):
				own_ea[ek] = want_v
				ea_changed = true
		if ea_changed:
			own_yep["elementAmplify"] = own_ea
			item["yep"] = own_yep
			changed = true

	return changed


# ---- 逐项补丁（仅用于生成副本，不改共享原表） ----

static func _patch_state_2539(r: Dictionary) -> void:
	for e in r.get("effects", []):
		for g in e.get("groups", []):
			for step in g.get("steps", []):
				if is_equal_approx(float(step.get("k", 0.0)), 5.0):
					step.k = float(ST2539_RATE)
	r.note = str(r.get("note", "")).replace("var finalRate = 5.0;", "var finalRate = %d.0;" % ST2539_RATE)


static func _redirect_9997_state(r: Dictionary) -> void:
	var old_k := "StartPushState%d" % ST_SHENG_SRC
	var new_k := "StartPushState%d" % ST_TIANXIA
	r.note = str(r.get("note", "")).replace("<%s:" % old_k, "<%s:" % new_k)
	var meta = r.get("meta", {})
	if meta is Dictionary and meta.has(old_k):
		var m2 := {}
		for k in meta.keys():
			m2[new_k if str(k) == old_k else k] = meta[k]
		r.meta = m2


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


## T585：剑一～剑八本是被动（元素增伤＋穿透一直生效），场合改「永不」；卡面「伤害:xxx」是打不出来的固定伤害，删掉
static func _fix_sword_passive(s: Dictionary) -> void:
	s.occasion = 3
	_drop_aps_line(s, "伤害:")


## T585：九阶基因锁去掉经验 −100%（passiveSPBST9）与空公共事件 1705，改不可点纯被动；卡面写已解开
static func _fix_genelock(s: Dictionary) -> void:
	s.occasion = 3
	_drop_effect(s, 44, 1705)
	_drop_tag(s, "passiveSPBST9")
	_drop_aps_line(s, "使用:撕裂基因锁")
	_replace_note_meta(s, "效果:经验获取率-100%", "效果:基因锁已解开")


static func _drop_effect(s: Dictionary, code: int, data_id: int) -> void:
	s.effects = (s.get("effects", []) as Array).filter(func(e): return not (e is Dictionary and int(e.get("code", 0)) == code and int(e.get("dataId", 0)) == data_id))


static func _drop_tag(s: Dictionary, tag: String) -> void:
	var re := RegEx.create_from_string("<" + _re_escape(tag) + ":[^>]*>[ \\t]*\\n?")
	s.note = re.sub(str(s.get("note", "")), "", true)
	var meta = s.get("meta", {})
	if meta is Dictionary:
		meta.erase(tag)


## 删掉备注里含 needle 的 <pos=APs …> 整行，并删掉 meta 里对应的键（APs 行在 meta 里按第一个冒号拆成键、值）
static func _drop_aps_line(s: Dictionary, needle: String) -> void:
	var lines := str(s.get("note", "")).split("\n")
	var kept := PackedStringArray()
	for ln in lines:
		if ln.strip_edges().begins_with("<pos=APs ") and ln.contains(needle):
			continue
		kept.append(ln)
	s.note = "\n".join(kept)
	var meta = s.get("meta", {})
	if meta is Dictionary:
		for k in meta.keys():
			var ks := str(k)
			if not ks.begins_with("pos=APs "):
				continue
			var v = meta[k]
			var whole := ks if v is bool else ks + ":" + str(v)
			if whole.contains(needle):
				meta.erase(k)


## 与 9998 同形的公式 (GUNLONG_BASE + a.atk×mul)×(1+熟练度)
static func _set_atk_formula(s: Dictionary, id: int, atk_mul: int) -> void:
	var src = s.get("damage", {}).get("formulaProgram", {}).get("source", {"table": "Skills", "id": id, "custom": false})
	s.damage = {
		"critical": true, "elementId": 1, "type": 1, "variance": 10, "custom": false,
		"formula": "(%d+a.atk*%d)*(1+user.skillMasteryLevel(item.id))" % [GUNLONG_BASE, atk_mul],
		"formulaGd": "(%d+a.atk*%d)*(1+a.skillMasteryLevel(%d))" % [GUNLONG_BASE, atk_mul, id],
		"formulaProgram": {
			"version": 1, "source": src, "status": "pure", "capabilities": ["read.battler"], "locals": [],
			"steps": [{"op": "expr", "pos": 0, "value": {
				"op": "binary", "pos": 0, "operator": "*",
				"left": {"op": "binary", "pos": 1, "operator": "+",
					"left": {"op": "literal", "pos": 1, "value": float(GUNLONG_BASE)},
					"right": {"op": "binary", "pos": 8, "operator": "*",
						"left": {"op": "property", "pos": 8, "receiver": "a", "name": "atk"},
						"right": {"op": "literal", "pos": 14, "value": float(atk_mul)}}},
				"right": {"op": "binary", "pos": 25, "operator": "+",
					"left": {"op": "literal", "pos": 25, "value": 1.0},
					"right": {"op": "read", "pos": 27, "receiver": "a", "name": "mastery",
						"args": [{"op": "literal", "pos": 50, "value": id}]}}}}],
			"result": "completion",
		},
	}


## 行动序列：咏唱＋剑气动画，hits 段 action effect（目标写法 tgt），tail 追加在最后
static func _set_seq(s: Dictionary, hits: int, tgt: String, tail: Array, effects := -1) -> PackedStringArray:
	var target: Array = [["motion chant", ["user"]], ["Animation 1050", [tgt]]]
	var lines := PackedStringArray(["<Target Action>", "motion chant: user", "Animation 1050: %s" % tgt])
	for i in hits:
		target.append(["wait", ["4"]])
		target.append(["action effect", [tgt]])
		lines.append("wait: 4")
		lines.append("action effect: %s" % tgt)
	for cmd in tail:
		target.append([cmd[0], [cmd[1]]])
		lines.append("%s: %s" % [cmd[0], cmd[1]])
	lines.append("</Target Action>")
	s.yepSeq = {
		"setup": [["CLEAR BATTLE LOG"], ["DISPLAY ACTION"], ["IMMORTAL", ["TARGETS", "TRUE"]], ["PERFORM START"], ["WAIT FOR MOVEMENT"], ["CAST ANIMATION"], ["WAIT FOR ANIMATION"]],
		"whole": [],
		"target": target,
		"follow": [],
		"finish": [["IMMORTAL", ["TARGETS", "FALSE"]], ["WAIT FOR NEW LINE"], ["CLEAR BATTLE LOG"], ["PERFORM FINISH"], ["WAIT FOR MOVEMENT"], ["WAIT FOR EFFECT"], ["ACTION COMMON EVENT"]],
	}
	s.yepEffects = hits if effects < 0 else effects
	return lines


static func _aps(text: String) -> String:
	return "<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>" % text


## T586：剑一～剑三改战技（在 D272 _patch_sword 与 T585 _fix_sword_passive 之后）；被动加成标签与「物理/寒冰伤害+X%」卡面行照留
static func _patch_active_sword(s: Dictionary, id: int) -> void:
	var cfg: Dictionary = ACTIVE_SWORDS[id]
	var hits := int(cfg.hits)
	s.name = str(cfg.name)
	s.stypeId = 1
	s.occasion = 1
	s.scope = int(cfg.scope)
	s.mpCost = int(cfg.mp)
	s.tpCost = int(cfg.tp)
	s.tpGain = int(cfg.tp_gain)
	s.successRate = 100
	var flavor := str(s.get("description", "")).get_slice("\n", 1)
	s.description = "战技\n" + flavor
	_set_atk_formula(s, id, sword_atk_mul(id))
	var seq := _set_seq(s, hits, "target", [])  # 行动序列按目标逐个跑（随机四个／全体），每个目标 hits 段
	var desc := []
	match id:
		9987:
			desc = ["对象:随机敌人四次", "\\c[1]效果:剑走龙蛇，四段剑气随机落在敌人身上，每段命中回复TP"]
		9988:
			desc = ["对象:敌方全体两次", "\\c[1]效果:一剑两花，同时斩向所有敌人"]
		9989:
			desc = ["对象:单体一次", "\\c[1]效果:剑重三斤，命中后有%d%%几率让目标眩晕1回合" % SWORD3_STUN_PCT]
			s.effects = [{"code": 21, "dataId": ST_STUN_SRC, "value1": float(SWORD3_STUN_PCT) / 100.0, "value2": 0}]
	if int(cfg.cd) > 0:
		desc.append("\\c[1]冷却:%d回合" % int(cfg.cd))
	# 原 note：开战状态、品质、卡面与被动标签照留，把行动序列与新卡面行插在「据说是剑九黄的绝学!」之后
	var old_lines := str(s.get("note", "")).split("\n")
	var out := PackedStringArray()
	for ln in old_lines:
		out.append(ln)
		if ln.contains("据说是剑九黄的绝学!"):
			out.append(_aps("伤害属性:物理"))
			for d in desc:
				out.append(_aps(d))
	if int(cfg.cd) > 0:
		out.insert(0, "<Cooldown: %d>" % int(cfg.cd))
	out.append_array(seq)
	s.note = "\n".join(out)
	s.meta = XZhenqi.extract_meta(s.note)


## T586：9995 剑九·六千里改战技（西游档副本）；卡面不写内部系数
static func _patch_jian9(s: Dictionary) -> void:
	s.stypeId = 1
	s.occasion = 1
	s.scope = 1
	s.mpCost = 0
	s.tpCost = JIAN9_TP
	s.successRate = 100
	s.description = "战技\n劣马黄酒六千里"
	s.name = "剑九·六千里"
	_drop_effect(s, 44, 1704)
	_set_atk_formula(s, SK_SWORD9, jian9_atk_mul())
	var seq := _set_seq(s, JIAN9_HITS, "target", [["Add State %d" % ST_SHOUJIAN, "user"], ["Add State %d" % ST_LIJIE, "user"]])  # P1-1：只打所选目标；先收剑再力竭，收剑在的当回合力竭不生效（lijie_active）
	var lines := PackedStringArray([
		"<quality:5>", "<ici:5>",
		"<Warmup: %d>" % JIAN9_WARMUP,
		"<Cooldown: %d>" % JIAN9_COOLDOWN,
		_aps("\\c[1]据说是剑九黄的绝学!"),
		_aps("伤害属性:物理"),
		_aps("对象:单体攻击九次"),
		_aps("\\c[1]效果:九段剑气，伤害随攻击力和技能等级提升，可以暴击"),
		_aps("\\c[1]效果:战斗第%d回合起才能使用，冷却%d回合" % [JIAN9_WARMUP, JIAN9_COOLDOWN]),
		_aps("\\c[1]代价:使出后本回合不能再行动，下一回合力竭，全属性降低%d%%" % (100 - LIJIE_PARAM_PCT)),
	])
	lines.append_array(seq)
	s.note = "\n".join(lines)
	s.meta = XZhenqi.extract_meta(s.note)


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
	var atk_mul := gunlong_atk_mul()
	var f_js := "(%d+a.atk*%d)*(1+user.skillMasteryLevel(item.id))" % [GUNLONG_BASE, atk_mul]
	var f_gd := "(%d+a.atk*%d)*(1+a.skillMasteryLevel(%d))" % [GUNLONG_BASE, atk_mul, SK_GUNLONG]
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
						"right": {"op": "literal", "pos": 14, "value": float(atk_mul)},
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
	# T586 文字审 P2-2：卡面不写内部公式和攻击系数（运行时公式照旧在 damage.formula）
	_replace_note_meta(s,
		"[666666+己·攻击力*3000+敌·生命值*0.00001]*[1+技能等级]",
		"连续攻击敌方全体五次，伤害随攻击力和技能等级提升。")
	_replace_note_meta(s, "对象:单体攻击五次", "对象:敌方全体攻击五次")  # 原版序列就是打全体（D272 保留原版机制），卡面如实写
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
	var atk_pct := xiudong_atk_pct()
	for tr in w.get("traits", []):
		if int(tr.get("code", 0)) == 21 and int(tr.get("dataId", 0)) == 2:
			tr.value = float(atk_pct) / 100.0
	for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
		_replace_tag(w, "Element Amplify %d" % el, " +%d%%" % XIUDONG_EL_AMP)
	if w.get("yep") is Dictionary and w.yep.get("elementAmplify") is Dictionary:
		var ea: Dictionary = w.yep.elementAmplify
		for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
			var ek := str(el)
			if ea.has(ek):
				ea[ek] = float(XIUDONG_EL_AMP) / 100.0
	_replace_tag(w, "passiveHarmRi", str(XIUDONG_HARM))
	_replace_tag(w, "passiveCrHarmRi", str(XIUDONG_HARM))
	if w.get("customParams") is Dictionary and w.customParams.get("params") is Array:
		var ps: Array = w.customParams.params
		if ps.size() > 4:
			ps[2].level = float(XIUDONG_GROW)
			ps[4].level = float(XIUDONG_GROW)
	_replace_note_meta(w, "atk += user.level * 10; mat += user.level * 10;", "atk += user.level * %d; mat += user.level * %d;" % [XIUDONG_GROW, XIUDONG_GROW])
	_replace_note_meta(w, "造成所有伤害结果*350%", "造成所有伤害结果*249%")
	_replace_note_meta(w, "物理 、雷电 阴阳 混沌伤+600%", "物理 、雷电 阴阳 混沌伤+%d%%" % XIUDONG_EL_AMP)
	_replace_note_meta(w, "攻击力能力值*300%", "攻击力能力值*%d%%，爆伤+%d%%，伤害+%d%%" % [atk_pct, XIUDONG_HARM, XIUDONG_HARM])
	_replace_note_meta(w, "每级+10)", "每级+%d)" % XIUDONG_GROW)


static func _patch_chunlei_129(a: Dictionary) -> void:
	var aplus_seen := 0
	var new_traits := []
	for tr in a.get("traits", []):
		if int(tr.get("code", 0)) == 21 and int(tr.get("dataId", 0)) == 2:
			tr.value = float(chunlei_atk_pct()) / 100.0
			new_traits.append(tr)
		elif int(tr.get("code", 0)) == 61 and int(tr.get("dataId", 0)) == 0:
			aplus_seen += 1
			if aplus_seen == 1:
				new_traits.append(tr)  # 再动 +2 → +1
		else:
			new_traits.append(tr)
	a.traits = new_traits
	for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
		_replace_tag(a, "Element Amplify %d" % el, " +%d%%" % CHUNLEI_EL_AMP)
	if a.get("yep") is Dictionary and a.yep.get("elementAmplify") is Dictionary:
		var ea: Dictionary = a.yep.elementAmplify
		for el in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]:
			var ek := str(el)
			if ea.has(ek):
				ea[ek] = float(CHUNLEI_EL_AMP) / 100.0
	_replace_tag(a, "passiveHarmRi", str(CHUNLEI_HARM))
	_replace_tag(a, "passiveCrHarmRi", str(CHUNLEI_HARM))
	if a.get("customParams") is Dictionary and a.customParams.get("params") is Array:
		var ps: Array = a.customParams.params
		if ps.size() > 4:
			ps[2].level = float(CHUNLEI_ATK_GROW)
			ps[4].level = float(CHUNLEI_ATK_GROW)
	_replace_note_meta(a, "atk = user.level * 30;", "atk = user.level * %d;" % CHUNLEI_ATK_GROW)
	_replace_note_meta(a, "mat = user.level * 30;", "mat = user.level * %d;" % CHUNLEI_ATK_GROW)
	_replace_note_meta(a, "等级需求:1 ", "等级需求:75 ")
	_replace_note_meta(a, "造成所有伤害结果*350%", "造成所有伤害结果*249%")
	_replace_note_meta(a, "物理 、雷电 阴阳 混沌伤+600%", "物理 、雷电 阴阳 混沌伤+%d%%" % CHUNLEI_EL_AMP)
	_replace_note_meta(a, "再动+2 ", "再动+1 ")
	_replace_note_meta(a, "攻击力能力值*300%", "攻击力能力值*%d%%，爆伤+%d%%，伤害+%d%%" % [chunlei_atk_pct(), CHUNLEI_HARM, CHUNLEI_HARM])


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
