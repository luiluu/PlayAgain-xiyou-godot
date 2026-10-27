class_name XGarou
extends RefCounted
## 173 饿狼（正式 js/codex/runtime/installNativeGarouRuntime.js，W.CodexGarou）第一期：招募、开机同步、能力值与基础拳公式。
## - 形态 stage＝进阶次数（原版 a._AdvancedNum，重制读 XAdvance.rank），夹在 0～6。STAGES 照 G.config.stages 抄录。
## - 开机同步（Game_Actor.setup 包装 → G.sync ＋ recoverAll）：只留当前形态的形态状态（2644～2650）；
##   按 0～当前形态逐段「忘 forget、学 learn」得到应学的拳法，非 triggered 的拳法多退少补；
##   被动 10265～10269 按备注 CodexUnlockRank／CodexUnlockLevel 准入（准入就学、不准就忘）。升级（levelUp 包装）后再同步一次。
## - 学技能（learnSkill 包装）：10265～10269 未到形态或等级时不学（职业 20／30／45 级的 10266～10268 因此要进阶后才有）。
## - 公式 CodexGarou.base(a,b,id)：per_hit_formula 去掉 *CURRENT_FORM_SCALE，A＝atk、M＝mat；在 CodexDamage 结算里 D＝R＝0
##   （防御另由结算按物防／魔防率处理），再 × 当前形态 damage_scale。非饿狼或非饿狼拳法为 0。
## - 招募（公共事件 9009 的 CodexGarou.recruit()）：已在队返回 false；没戴饿狼法宝时，背包里有就拿、没有就生成当前形态的
##   独立法宝（人类形态 7904「破限之心·人类」）装进装备类型 13 的槽；同步、入队，提示「饿狼加入队伍，获得并装备破限之心。」。
## 未移植（第二期起）：形态能力倍率 paramRate（人类形态全为 1）、paramMax、每回合行动次数（人类 1）、进阶（G.advance、
## 进阶界面、累计突破、神之触媒）、法宝进化 evolveRelic、进化／解析／反击／追击与伤害钩子 garou（人类形态进化未学、解析 0 层时
## 不改伤害）、itemCnt、技能使用条件、Map132 商店补号角 2940、技能分类与界面、图鉴立绘、旧档迁移（不迁移 MV 旧存档）。
## 参照：slice_probe（切片角色行与伤害行）、actor_passive_probe（各等级技能表）；测试 tests/xiyou_garou.gd。

const ACTOR := 173
const HORN := 2940
const RELICS := [7904, 7905, 7906, 7908, 7909, 7910, 7911]
const STATES := [2644, 2645, 2646, 2647, 2648, 2649, 2650]
## 形态：damage_scale、每回合行动、学／忘的拳法（G.config.stages 的 learn_skill_ids／forget_skill_ids）
const STAGES := [
	{"scale": 66, "actions": 1, "learn": [10250], "forget": []},
	{"scale": 188, "actions": 1, "learn": [10251], "forget": [10250]},
	{"scale": 999, "actions": 1, "learn": [10252], "forget": [10251]},
	{"scale": 3888, "actions": 1, "learn": [10253, 10254], "forget": [10252]},
	{"scale": 3999, "actions": 1, "learn": [10255, 10256], "forget": [10253]},
	{"scale": 5000, "actions": 2, "learn": [10257], "forget": [10256]},
	{"scale": 7000, "actions": 2, "learn": [10259, 10260, 10261, 10262, 10263], "forget": [10255, 10257, 10254]},
]
## G.config.skills 里 role 不是 triggered 的拳法（10258 神杀瞬击是追击，不由同步学忘）
const FISTS := [10250, 10251, 10252, 10253, 10254, 10255, 10256, 10257, 10259, 10260, 10261, 10262, 10263]
const TRIGGERED := 10258
const PASSIVES := [10265, 10266, 10267, 10268, 10269]
## 各拳法 per_hit_formula 去掉 *CURRENT_FORM_SCALE 后、D＝R＝0 时剩下的系数：[A 系数, M 系数]
const COEFF := {10250: [1.88, 0.0], 10251: [1.88, 0.0], 10252: [3.33, 0.0], 10253: [3.33, 0.0], 10254: [3.33, 0.0],
	10255: [3.33, 0.0], 10256: [22.22, 0.0], 10257: [33.33, 0.0], 10258: [3.33, 0.0], 10259: [6.66, 9.99],
	10260: [9.99, 6.66], 10261: [3.33, 6.66], 10262: [0.0, 0.0], 10263: [99.99, 66.66]}
const RECRUIT_TEXT := "饿狼加入队伍，获得并装备破限之心。"
## 说明卡用（G.config.stages 的 name 与 passives：进化每层增伤、解析每层无视物防／魔防，均为百分数）
const FORM_NAMES := ["人类", "赤发", "半怪人", "螺旋", "翼化", "四臂", "星空"]
const FORM_PASSIVES := [[false, 0, false, 0, 0], [true, 16, false, 0, 0], [true, 22, true, 11, 0], [true, 33, true, 16, 0],
	[true, 50, true, 22, 0], [true, 66, true, 33, 0], [true, 99, true, 33, 33]]


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func stage(_a = null) -> int:
	return clampi(XAdvance.rank(XState.current, ACTOR), 0, 6)


## G.form(a)（说明卡用）：当前形态；进化／解析要学了 10266／10267 才算开，没学 10269 每回合只行动 1 次。a 为 null（预览）时按什么都没学
static func form(a) -> Dictionary:
	var i := stage(a)
	var p: Array = FORM_PASSIVES[i]
	var learned := func(id): return a != null and a.skill_ids.has(id)
	var analysis: bool = p[2] and learned.call(10267)
	return {"name": FORM_NAMES[i], "scale": STAGES[i].scale, "actions": STAGES[i].actions if learned.call(10269) else 1,
		"passives": {"evolution_enabled": p[0] and learned.call(10266), "evolution_base_per_stack_percent": p[1],
			"analysis_defense_ignore_percent_per_stack": p[3] if analysis else 0, "analysis_magic_defense_ignore_percent_per_stack": p[4] if analysis else 0}}


## learnSkill 包装：被动按形态与等级准入
static func can_learn(a, id: int) -> bool:
	return not own(a) or not PASSIVES.has(id) or _passive_allowed(a, id)


static func _passive_allowed(a, id: int) -> bool:
	var meta: Dictionary = XDB.rec("Skills", id).get("meta", {})
	return stage(a) >= int(str(meta.get("CodexUnlockRank", "0")).to_int()) and int(a.level) >= maxi(1, int(str(meta.get("CodexUnlockLevel", "1")).to_int()))


## G.sync（setup、levelUp 后）：被动准入 → 形态状态 → 拳法
static func sync(a) -> void:
	if not own(a):
		return
	for id in PASSIVES:
		var allowed := _passive_allowed(a, id)
		if allowed and not a.skill_ids.has(id):
			a.learn_skill(id)
		elif not allowed and a.skill_ids.has(id):
			a.forget_skill(id)
	var st := stage(a)
	for i in STATES.size():
		if i != st and a.state_ids.has(STATES[i]):
			a.remove_state(STATES[i])
	if not a.state_ids.has(STATES[st]):
		a.add_state(STATES[st])
	var desired := []
	for i in st + 1:
		desired = desired.filter(func(id): return not STAGES[i].forget.has(id))
		desired.append_array(STAGES[i].learn)
	for id in FISTS:
		if desired.has(id) and not a.skill_ids.has(id):
			a.learn_skill(id)
		elif not desired.has(id) and a.skill_ids.has(id):
			a.forget_skill(id)
	a.refresh_passive()


## Game_Actor.setup 包装：同步后回满
static func setup(a) -> void:
	if own(a):
		sync(a)
		a.recover_all()


static func level_up(a) -> void:
	sync(a)


## CodexGarou.base(a,b,id)
static func formula(a, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if not own(a) or not COEFF.has(id):
		return 0.0
	var c: Array = COEFF[id]
	return maxf(0.0, float(a.atk) * c[0] + float(a.mat) * c[1]) * STAGES[stage(a)].scale


static func is_relic(e) -> bool:
	return e is Dictionary and not e.is_empty() and str(e.get("kind", "")) == "armor" and RELICS.has(int(e.get("base", e.get("id", 0))))


## CodexGarou.recruit()
static func recruit(s: XState) -> bool:
	if s.party.has(ACTOR):
		return false
	var a := s.actor(ACTOR)
	var slot := a.equip_slots().find(13)
	if slot < 0:
		push_error("[xiyou] 饿狼法宝槽不存在")
		return false
	if not a.equips.any(is_relic):
		var idx := s.gear.find_custom(is_relic)
		if idx < 0:
			s.gain_gear("armor", RELICS[stage(a)], 1)
			idx = s.gear.size() - 1
		var relic: Dictionary = s.gear[idx]
		s.gear.remove_at(idx)
		if a.equips[slot] is Dictionary and not a.equips[slot].is_empty():
			s.gear.append(a.equips[slot])
		a.equips[slot] = relic
	sync(a)
	s.add_actor(ACTOR)
	return true
