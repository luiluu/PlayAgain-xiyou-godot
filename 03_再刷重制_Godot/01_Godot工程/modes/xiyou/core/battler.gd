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
var mp := 0.0
var tp := 0.0
var state_ids: Array[int] = []
var state_turns := {}
var buffs: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var buff_turns: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var guarding := false
## YEP_X_SkillCooldowns：技能 ID → 剩余回合（冷却 / 预热）。冷却跨战斗保留（随存档），预热只在战斗内。
var cooldowns := {}
var warmups := {}

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
			out.append(s)
	return out

func is_state_affected(id: int) -> bool:
	return state_ids.has(id)

func add_state(id: int) -> void:
	if XDB.rec("States", id).is_empty():
		return
	if id == 1:
		hp = 0.0
		state_ids.clear()
		state_turns.clear()
		buffs.fill(0)
		buff_turns.fill(0)
	if not state_ids.has(id):
		state_ids.append(id)
		_sort_states()
	var s := XDB.rec("States", id)
	state_turns[id] = int(s.get("minTurns", 1)) + randi_range(0, max(0, int(s.get("maxTurns", 1)) - int(s.get("minTurns", 1))))

func remove_state(id: int) -> void:
	if id == 1 and state_ids.has(id) and hp <= 0.0:
		hp = 1.0  # MV removeState(deathStateId) 先 revive，再去除阵亡状态。
	state_ids.erase(id)
	state_turns.erase(id)

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

func traits_pi(code: int, id: int) -> float:
	var v := 1.0
	for t in traits_with_id(code, id):
		v *= float(t.value)
	return v

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

func param(i: int) -> float:
	var v := param_base(i) + param_plus(i)
	v *= param_rate(i) * param_buff_rate(i)
	return roundf(clampf(v, param_min(i), param_max(i)))

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
		return current
	var r := sum + current - product
	if not is_actor():
		var low := minf(0.01, product)
		if r < low:
			return low
	return maxf(0.0, r)

## 没有攻击元素特性时（如空手）按物理(1)处理，与正式版一致。
func attack_elements() -> Array:
	var es := traits_set(TRAIT_ATTACK_ELEMENT)
	return es if not es.is_empty() else [1]


# ---- 资源 ----
func recover_all() -> void:
	state_ids.clear()
	state_turns.clear()
	hp = mhp
	mp = mmp

func is_dead() -> bool:
	return hp <= 0.0

func is_alive() -> bool:
	return hp > 0.0

func hp_rate() -> float:
	return hp / maxf(mhp, 1.0)
