class_name XBattler
extends RefCounted
## 战斗者基类：能力值、特性、状态、增减益。规则按 MV Game_BattlerBase，
## 加上西游正式版的元素/减伤加算池（installDamageElementRuntime 的 additiveRate）。
## 公式里用到的 a.atk、b.def 等由下面的属性提供，Expression 通过 get() 读取。

const TRAIT_ELEMENT_RATE := 11
const TRAIT_STATE_RATE := 13
const TRAIT_STATE_RESIST := 14
const TRAIT_PARAM := 21
const TRAIT_XPARAM := 22
const TRAIT_SPARAM := 23
const TRAIT_ATTACK_ELEMENT := 31
const TRAIT_ATTACK_STATE := 32
const TRAIT_ATTACK_SPEED := 33
const TRAIT_ATTACK_TIMES := 34
const TRAIT_STYPE_ADD := 41
const TRAIT_STYPE_SEAL := 42
const TRAIT_SKILL_ADD := 43
const TRAIT_SKILL_SEAL := 44

var hp := 0.0
## YEP 行动序列的 IMMORTAL（Game_Battler._immortalState）：期间 HP 为 0 也不倒下、阵亡状态视为抵抗
var immortal := false
## A resource refresh can leave HP zero while death is resisted/removed in this result.
var resource_death_blocked := false
var mp := 0.0
var tp := 0.0
var state_ids: Array[int] = []
var state_turns := {}
var buffs: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var buff_turns: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var guarding := false
## Game_Battler._lastTargetIndex：最近一次行动作用到的目标在其队伍里的序号（强制行动「上次目标」用）
var last_target_index := 0
## YEP_X_SkillCooldowns：技能 ID → 剩余回合（冷却 / 预热）。冷却跨战斗保留（随存档），预热只在战斗内。
var cooldowns := {}
var warmups := {}
## 真气道法（XZhenqi）：元婴护体本场已用（_codexZqGuard，BattleManager.setup 时清）；破甲·真气 2705 的双防倍率（_codexZqPojiaRate，0.5＝原状态）
var zq_guard := false
var zq_pojia_rate := 0.5

var mhp: float:
	get: return param(0)
var mmp: float:
	get: return param(1)
var atk: float:
	get: return param(2)
var def: float:
	get: return param(3)
var mat: float:
	get: return param(4)
var mdf: float:
	get: return param(5)
var agi: float:
	get: return param(6)
var luk: float:
	get: return param(7)
var hit: float:
	get: return xparam(0)
var eva: float:
	get: return xparam(1)
var cri: float:
	get: return xparam(2)
var cev: float:
	get: return xparam(3)
var mev: float:
	get: return xparam(4)
var mrf: float:
	get: return xparam(5)
var cnt: float:
	get: return xparam(6)
var hrg: float:
	get: return xparam(7)
var mrg: float:
	get: return xparam(8)
var trg: float:
	get: return xparam(9)
var tgr: float:
	get: return sparam(0)
var grd: float:
	get: return sparam(1)
var rec: float:
	get: return sparam(2)
var pha: float:
	get: return sparam(3)
var mcr: float:
	get: return sparam(4)
var tcr: float:
	get: return sparam(5)
var pdr: float:
	get: return sparam(6)
var mdr: float:
	get: return sparam(7)
var fdr: float:
	get: return sparam(8)
var exr: float:
	get: return sparam(9)
var level: int:
	get: return _level()


# ---- 子类实现 ----
func is_actor() -> bool:
	return false

func display_name() -> String:
	return ""

func _level() -> int:
	return 1

func param_base(_i: int) -> float:
	return 0.0

func param_plus(_i: int) -> float:
	return 0.0

## 数据库对象（角色/职业/装备/敌人/状态），各自带 traits、note、meta。
func trait_objects() -> Array:
	return states()

func skills() -> Array:
	return []

func passive_cache() -> Dictionary:
	return {}

func passive_values(_tag: String) -> Array:
	return []

func race_ids() -> Array:
	return []

# ---- 技能冷却（YEP_X_SkillCooldowns，回合制）----
## 技能 1~7 不受冷却影响（插件参数 Cooldown Bypass）。
static func cooldown_bypass(skill_id: int) -> bool:
	var ids := str(XDB.plugin("YEP_X_SkillCooldowns").get("Cooldown Bypass", "")).split(" ", false)
	return ids.has(str(skill_id))

## 剩余回合：冷却与预热取大者；> 0 时不能使用。
func cooldown_left(skill_id: int) -> int:
	return maxi(ceili(float(cooldowns.get(skill_id, 0))), ceili(float(warmups.get(skill_id, 0))))

## 使用技能后：<Cooldown: x> 设为 x。
func pay_cooldown(skill: Dictionary) -> void:
	var cd = skill.get("meta", {}).get("Cooldown")
	if cd == null or cooldown_bypass(int(skill.id)):
		return
	cooldowns[int(skill.id)] = maxf(0.0, float(str(cd).strip_edges()))

## 战斗开始：<Warmup: x> 的技能设预热。
func start_warmups() -> void:
	warmups.clear()
	for sk in skills():
		var wu = sk.get("meta", {}).get("Warmup")
		if wu != null and not cooldown_bypass(int(sk.id)):
			warmups[int(sk.id)] = float(str(wu).strip_edges())

## 每回合开始（MV Game_Troop.increaseTurn）各减 1。
func update_cooldowns() -> void:
	for k in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) - 1.0
		if cooldowns[k] <= 0.0:
			cooldowns.erase(k)
	for k in warmups.keys():
		warmups[k] = float(warmups[k]) - 1.0
		if warmups[k] <= 0.0:
			warmups.erase(k)

## 战斗结束：冷却加上 Cooldown After Battle（-10），清除预热。
func end_battle_cooldowns() -> void:
	var after := float(XDB.plugin("YEP_X_SkillCooldowns").get("Cooldown After Battle", "0"))
	for k in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) + after
		if cooldowns[k] <= 0.0:
			cooldowns.erase(k)
	warmups.clear()


## 公式兼容：技能熟练度（YEP_SkillMasteryLevels），首期统一为 0。
func skillMasteryLevel(_skill_id: int) -> int:
	return 0


# ---- 状态 ----
func states() -> Array:
	var out := []
	for id in state_ids:
		var s := XDB.rec("States", id)
		if not s.is_empty():
			out.append(XZhenqi.pojia_state(s, zq_pojia_rate) if id == XZhenqi.POJIA_STATE else s)
	return out

func is_state_affected(id: int) -> bool:
	return state_ids.has(id)

func add_state(id: int, random: XRandomStream = null) -> void:
	if XDB.rec("States", id).is_empty():
		return
	if id == XZhenqi.POJIA_STATE:
		zq_pojia_rate = XZhenqi.pojia_rate()  # 本次行动者有破甲道法时 1−0.5×scale，否则 0.5
	if id == 1:
		if state_ids.has(1) or immortal or traits_set(TRAIT_STATE_RESIST).has(1):
			return
		zq_pojia_rate = 0.5
		hp = 0.0
		for sid in state_ids.duplicate():
			if not XResourceContext.permanent(sid):
				state_ids.erase(sid)
				state_turns.erase(sid)
		buffs.fill(0)
		buff_turns.fill(0)
	if not state_ids.has(id):
		state_ids.append(id)
		_sort_states()
	var s := XDB.rec("States", id)
	var lo := int(s.get("minTurns", 1))
	var hi := maxi(lo, int(s.get("maxTurns", lo)))
	state_turns[id] = random.next_int_inclusive(lo, hi, "state_duration", str(id)) if random != null else randi_range(lo, hi)

func remove_state(id: int) -> void:
	if id == 1 and state_ids.has(id) and hp <= 0.0:
		hp = 1.0  # MV removeState(deathStateId) 先 revive，再去除阵亡状态。
	state_ids.erase(id)
	state_turns.erase(id)
	if id == XZhenqi.POJIA_STATE:
		zq_pojia_rate = 0.5

func _sort_states() -> void:
	# MV：按优先级降序，同优先级按 ID 升序
	state_ids.sort_custom(func(a, b):
		var pa := int(XDB.rec("States", a).get("priority", 0))
		var pb := int(XDB.rec("States", b).get("priority", 0))
		return pa > pb or (pa == pb and a < b))


# ---- 特性 ----
func all_traits() -> Array:
	var out := []
	for o in trait_objects():
		out.append_array(o.get("traits", []))
	return out

func traits_with_id(code: int, id: int) -> Array:
	return all_traits().filter(func(t): return int(t.code) == code and int(t.dataId) == id)

## MV traitsPi 经 CP_StateFloor（State Added Type: true，正式版启用）改为加算：1＋Σ(值−1)，小于 0 取 0。
## 能力值比率、特殊能力、元素有效度、状态有效度都走这里（正式 traitsPiToSum）。
func traits_pi(code: int, id: int) -> float:
	var v := 1.0
	for t in traits_with_id(code, id):
		v += float(t.value) - 1.0
	return maxf(0.0, v)

func traits_sum(code: int, id: int) -> float:
	var v := 0.0
	for t in traits_with_id(code, id):
		v += float(t.value)
	return v

func traits_sum_all(code: int) -> float:
	var v := 0.0
	for t in all_traits():
		if int(t.code) == code:
			v += float(t.value)
	return v

func traits_set(code: int) -> Array:
	var out := []
	for t in all_traits():
		if int(t.code) == code and not out.has(int(t.dataId)):
			out.append(int(t.dataId))
	return out


# ---- 能力值（MV Game_BattlerBase.param）----
func param_min(i: int) -> float:
	return 1.0 if i == 0 else 0.0

func param_max(_i: int) -> float:
	return 1e30  # 正式版经 YEP_CoreEngine 放开上限

func param_rate(i: int) -> float:
	return traits_pi(TRAIT_PARAM, i)

func param_buff_rate(i: int) -> float:
	return buffs[i] * 0.25 + 1.0

## G_StateParam（未装 YEP_BaseParamControl 的分支）：(基础＋加值)×比率×强化率 之后再加状态备注 <G_ShuXing> 的固定值
func param(i: int) -> float:
	var v := param_base(i) + param_plus(i)
	v *= param_rate(i) * param_buff_rate(i)
	v += param_state(i)
	return roundf(clampf(v, param_min(i), param_max(i)))

## G_StateParam paramState：各状态 <G_ShuXing> 的固定值之和。原版乘以 YEP 状态计数（_stateCounter，层数）；
## Godot 没有状态计数，按 1 层（正式版没设计数时同样是 1）。
static var _state_param_cache := {}
func param_state(i: int) -> float:
	var v := 0.0
	for id in state_ids:
		if not _state_param_cache.has(id):
			_state_param_cache[id] = XPower.state_params(XDB.rec("States", id))
		v += float(_state_param_cache[id][i])
	return v

func xparam(i: int) -> float:
	return traits_sum(TRAIT_XPARAM, i)

func sparam(i: int) -> float:
	var v := traits_pi(TRAIT_SPARAM, i)
	if i == 6 or i == 7:
		return additive_rate(TRAIT_SPARAM, i, v, [])
	return v


# ---- 元素 ----
## 额外的承伤倍率（角色被动 passiveELEMxx），子类提供。
func passive_element_values(_e: int) -> Array:
	return []

func element_rate(e: int) -> float:
	# 原生链（MV 连乘＋dsPassiveSkill 再乘被动）得到 current，再交给加算池
	var passive := passive_element_values(e)
	var current := traits_pi(TRAIT_ELEMENT_RATE, e)
	# YEP_ElementCore：吸收的元素在倍率为正时降 200%（不是取反），至少吸收 0.01%
	if current > 0.0 and is_absorb_element(e):
		current = minf(current - 2.0, -0.01)
	for p in passive:
		current *= p
	return additive_rate(TRAIT_ELEMENT_RATE, e, current, passive)

## 正式版的加算池（installDamageElementRuntime.additiveRate）：多项抗性/减伤按 1+Σ(v-1) 相加，
## 不再连乘；任意一项为 0 视为免疫；敌人不低于 min(0.01, 连乘)。
func additive_rate(code: int, id: int, current: float, passive: Array) -> float:
	var values: Array = traits_with_id(code, id).map(func(t): return float(t.value))
	var passive_product := 1.0
	for p in passive:
		values.append(p)
		passive_product *= p
	if current == 0.0 and is_actor():
		return 0.0
	if values.is_empty():
		return current
	if values.any(func(v): return v == 0.0):
		return 0.0
	var pure := 1.0
	var sum := 1.0
	for v in values:
		pure *= v
		sum += v - 1.0
	if current == 0.0:
		return maxf(minf(0.01, pure), sum)
	var product := traits_pi(code, id) * passive_product
	if current < 0.0:
		if is_absorb_element(id) and product > 0.0:
			return minf(sum - 2.0 + (current - (product - 2.0)), -0.01)
		return current
	var r := sum + current - product
	if not is_actor():
		var low := minf(0.01, product)
		if r < low:
			return low
	return maxf(0.0, r)

## YEP_ElementCore isAbsorbElement：特性对象（角色、职业、装备、状态；敌人、状态）备注
## <Element Absorb: x>、<Element Absorb: x, x>、<Element Absorb: x to y>、<Element Absorb: 名字, 名字>
static var _absorb_cache := {}
func is_absorb_element(e: int) -> bool:
	for o in trait_objects():
		var note := str(o.get("note", ""))
		if note == "":
			continue
		if not _absorb_cache.has(note):
			_absorb_cache[note] = _parse_element_absorb(note)
		if _absorb_cache[note].has(e):
			return true
	return false

static func _parse_element_absorb(note: String) -> Array:
	var out := []
	var names := {}
	var elements: Array = XDB.system().get("elements", [])
	for i in range(elements.size()):
		names[str(elements[i]).to_upper()] = i
	for line in note.split("\n"):
		var m := RegEx.create_from_string("(?i)<(?:ELEMENT ABSORB):[ ]*(\\d+(?:\\s*,\\s*\\d+)*)>").search(line)
		if m:
			for n in m.get_string(1).split(","):
				out.append(int(n.strip_edges()))
			continue
		m = RegEx.create_from_string("(?i)<(?:ELEMENT ABSORB):[ ](\\d+)[ ](?:THROUGH|to)[ ](\\d+)>").search(line)
		if m:
			for i in range(int(m.get_string(1)), int(m.get_string(2)) + 1):
				out.append(i)
			continue
		m = RegEx.create_from_string("(?i)<(?:ELEMENT ABSORB):[ ](.*)>").search(line)
		if m:
			for n in m.get_string(1).split(","):
				var id := int(names.get(n.to_upper().strip_edges(), 0))
				if id > 0:
					out.append(id)
	return out

## Game_BattlerBase.attackStates／attackStatesRate（特性 32）；角色另加 dsPassiveSkill passiveATKST（XActor）
func attack_states() -> Array:
	return traits_set(TRAIT_ATTACK_STATE)

func attack_states_rate(id: int) -> float:
	return traits_sum(TRAIT_ATTACK_STATE, id)

## Game_BattlerBase.attackTimesAdd：普攻追加次数（特性 34，不小于 0）；角色另加道法「连击」
func attack_times_add() -> float:
	return maxf(traits_sum_all(TRAIT_ATTACK_TIMES), 0.0)

## Game_BattlerBase.actionPlusSet：各「追加行动」特性（61 号 0）的几率；角色另加道法「分神」[1]
func action_plus_set() -> Array:
	var out := []
	for t in all_traits():
		if int(t.code) == 61 and int(t.dataId) == 0:
			out.append(float(t.value))
	return out

## 特殊旗标（62）：2 掩护、3 保留 TP；角色另加 dsPassiveSkill passiveSUBS／passivePRETP。掩护还要能行动（BattleLogic 判）
func is_substitute() -> bool:
	return traits_set(62).has(2)

func is_preserve_tp() -> bool:
	return traits_set(62).has(3)

## 没有攻击元素特性时（如空手）按物理(1)处理，与正式版一致。
func attack_elements() -> Array:
	var es := traits_set(TRAIT_ATTACK_ELEMENT)
	return es if not es.is_empty() else [1]


# ---- 资源 ----
## 正式 rpg_οbjects.js 的 maxTp 为 200（角色另有 dsPassiveSkill passiveEXTTP）。
func max_tp() -> float:
	return 200.0


## Game_Battler.refresh：夹资源并同步阵亡状态（序列 HP + 恢复时也必须去除阵亡）。
func refresh_resources(random: XRandomStream = null) -> void:
	var context := XResourceContext.new()
	context.random = random
	context.refresh(self)


## YEP_BuffsStatesCore：默认层数 4、绝对上限 8，加上状态／角色／职业／装备／敌人备注的 <Max 能力 Buff/Debuff: ±N>。
func buff_limit(pid: int, positive: bool) -> int:
	var p := XDB.plugin("YEP_BuffsStatesCore")
	var limit := int(p.get("Default Limit", "2"))
	var tag := "BUFF" if positive else "DEBUFF"
	for obj in trait_objects():
		var bonus := 0
		for m in RegEx.create_from_string("(?i)<MAX (.*) " + tag + ": ([+-]\\d+)>").search_all(str(obj.get("note", ""))):
			if XActionSequence.PARAMS.get(m.get_string(1).to_upper(), -1) == pid:
				bonus = int(m.get_string(2))
		limit += bonus
	return clampi(limit, 1, int(p.get("Maximum Limit", "8"))) * (1 if positive else -1)


func recover_all() -> void:
	for sid in state_ids.duplicate():
		if not XResourceContext.permanent(sid):
			state_ids.erase(sid)
			state_turns.erase(sid)
	resource_death_blocked = false
	hp = mhp
	mp = mmp

func is_dead() -> bool:
	return state_ids.has(1) or (hp <= 0.0 and not immortal and not resource_death_blocked and not traits_set(TRAIT_STATE_RESIST).has(1))

func is_alive() -> bool:
	return not is_dead()

func hp_rate() -> float:
	return hp / maxf(mhp, 1.0)
