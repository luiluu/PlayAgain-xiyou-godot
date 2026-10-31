class_name XBattler
extends RefCounted
## 战斗者基类：能力值、特性、状态、增减益。规则按 MV Game_BattlerBase，
## 加上西游正式版的元素/减伤加算池（installDamageElementRuntime 的 additiveRate）。
## 公式里用到的 a.atk、b.def 等由下面的属性提供，Expression 通过 get() 读取。

const TRAIT_ELEMENT_RATE := 11
const TRAIT_DEBUFF_RATE := 12
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
## krz_state_re 的能力值缓存（Game_Enemy.param 的 _ParamCache2／need_refresh_param，正式版战斗中才用）：开战后读过的格子
## 一直返回旧值，只有 param_dirty（need_refresh）为真时的下一次刷新（param_refresh）才让八格一起变冷；冷格首次读取才算新值。
## dirty 与格子有效分开：加减状态、buff、非零 gain、回合开始／结束先标 dirty，当场读取仍旧。336 变身不标 dirty，
## 所以变身前读过的格子（含生命／魔法上限）留旧形态的值。目前只有敌人启用（XEnemy.param），角色仍每次重算。
var param_cache_on := false
var param_dirty := false
## 8 格，null＝冷格；数值 0 也算命中
var param_cells: Array = []
# KRZ need_refresh / states / typestates are separate from enemy parameter cells.
# These caches contain detached database records, so formula shadow copies stay isolated.
var effect_dirty := true
var effect_snapshot: Array = []
var effect_snapshot_valid := false
var effect_lists := {}
static var _adding_state := false
static var _leaving_state := false
static var _outside_random: XRandomStream
## Scoped host capability, never persisted; wrappers restore the previous owner.
var lifecycle_context := {}
var runtime_result := XResourceContext.empty_result()
var mp := 0.0
var tp := 0.0
var state_ids: Array[int] = []
var state_turns := {}
## YEP stateOrigin：状态 ID → 附加时行动者的 WeakRef（XImportedBalance.acting_battler）；导入角色平衡的持续伤害按来源判断。
## 用弱引用：自己给自己加状态、双方互相记来源都会成环，RefCounted 环在退出时泄漏
var state_origins := {}
## 状态脚本写在战斗者身上的私有字段，按原名存（如叠毒 `_stackingPoison`），所有状态共用；角色的随存档（stateData）
var state_data := {}
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
## ShieldSystem 护盾（Game_Battler._shield）：受击先吸收，击穿后剩余伤害减半；每回合末衰减；战斗结束清零。
var shield := 0.0

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


# ---- 护盾（ShieldSystem v2.8；参数 decayRate／damageReduction 取自插件设置）----
static var _shield_effect_re: RegEx

static func _shield_param(key: String, def: String) -> float:
	return float(XDB.plugin("ShieldSystem").get(key, def))

## shieldEffectBonus：特性对象备注 <ShieldEffect:n> 各取第一处相加（n/100），再加真气道法「金身」。
func shield_effect_bonus() -> float:
	if _shield_effect_re == null:
		_shield_effect_re = RegEx.create_from_string("(?i)<ShieldEffect\\s*:\\s*(\\d+)>")
	var bonus := 0.0
	for obj in trait_objects():
		var m := _shield_effect_re.search(str(obj.get("note", "")))
		if m:
			bonus += int(m.get_string(1)) / 100.0
	return bonus + XZhenqi.shield_effect_bonus(self)

## addShield：正数乘 (1＋加成)，负数直接扣；不取整，不低于 0。非有限数按 0。
func add_shield(value: float) -> void:
	if is_nan(value) or is_inf(value):
		value = 0.0
	if XAlienBattle.blocks_life_shield(self) or XAlienBattle.route_shield(self, value):
		return  # 异化嫁祸、绝缘拒收外来护盾，舍身转给队友（addShield 包装）
	if value > 0.0:
		value *= 1.0 + shield_effect_bonus()
	shield = maxf(0.0, shield + value)
	XAlienBattle.clamp_hollow_shield(self)  # 异化空壳：护盾不超过开场生命上限

## executeHpDamage／gainHp／setHp 三处钩子的共同部分：正伤害先扣护盾，扣完还有剩余就按 damageReduction 减免后取整。
func absorb_shield(damage: float) -> float:
	if damage <= 0.0 or shield <= 0.0:
		return damage
	var absorb := minf(shield, damage)
	shield = maxf(0.0, shield - absorb)
	damage -= absorb
	return floorf(damage * (1.0 - _shield_param("damageReduction", "0.5"))) if damage > 0.0 else 0.0

## regenerateAll 之后（不论存活）：护盾减 floor(护盾×decayRate)。
func decay_shield() -> void:
	if shield > 0.0:
		var decrease := floorf(shield * _shield_param("decayRate", "0.25"))
		if decrease > 0.0:
			shield = maxf(0.0, shield - decrease)


# ---- 状态 ----
func states() -> Array:
	var out := []
	for id in state_ids:
		var s := XDB.rec("States", id)
		if not s.is_empty():
			out.append(XZhenqi.pojia_state(s, zq_pojia_rate) if id == XZhenqi.POJIA_STATE else s)
	return out

## KRZ cached phase lists can retain removed states until a dirty refresh.
## Preview reads an existing list, or computes a private list without warming it.
func effect_states(phase: String, execute := true) -> Array:
	if effect_lists.has(phase):
		return effect_lists[phase]
	var source: Array = effect_snapshot if effect_snapshot_valid else states()
	var rows := source.filter(func(st): return st.get("effects", []).any(func(e): return str(e.get("phase", "")) == phase))
	if execute:
		if not effect_snapshot_valid:
			effect_snapshot = source.duplicate()
			effect_snapshot_valid = true
		effect_lists[phase] = rows
	return rows

func is_state_affected(id: int) -> bool:
	return state_ids.has(id)

func add_state_with_context(id: int, random: XRandomStream, ctx: Dictionary) -> void:
	var previous := lifecycle_context
	lifecycle_context = ctx
	add_state(id, random)
	lifecycle_context = previous

func remove_state_with_context(id: int, ctx: Dictionary, automatic := false) -> void:
	var previous := lifecycle_context
	lifecycle_context = ctx
	if automatic:
		remove_state_auto(id)
	else:
		remove_state(id)
	lifecycle_context = previous

func refresh_with_context(random: XRandomStream, ctx: Dictionary) -> void:
	var previous := lifecycle_context
	lifecycle_context = ctx
	refresh_resources(random)
	lifecycle_context = previous

func push_state_result(key: String, id: int) -> void:
	var resources: XResourceContext = lifecycle_context.get("resources")
	if resources != null:
		var result := resources.result(self)
		if not result[key].has(id):
			result[key].append(id)

func add_state(id: int, random: XRandomStream = null) -> void:
	# _Fix_StackOverflow: one global lock, including additions to another battler.
	if _adding_state:
		return
	if XAlienBattle.blocks_state(self):
		return  # 异化归墟 addState 包装：归墟者攻击期间不给别人附加状态
	if XAlienBattle.route_state(self, id):
		return  # 异化绝缘拒收、舍身转给队友（addState 包装）
	var alien_rev := XAlienBattle.revision(self, id)
	_adding_state = true
	_add_state(id, random)
	_adding_state = false
	XAlienBattle.after_add_state(self, id, alien_rev)  # 异化囚厄：其他角色得到的 jailStates 转给囚厄者

func _add_state(id: int, random: XRandomStream = null) -> void:
	if XDB.rec("States", id).is_empty():
		return
	var fresh := not state_ids.has(id)
	var alien_before = state_turns.get(id) if not fresh else null
	if id == XZhenqi.POJIA_STATE:
		zq_pojia_rate = XZhenqi.pojia_rate()  # 本次行动者有破甲道法时 1−0.5×scale，否则 0.5
	if id == 1:
		if state_ids.has(1) or immortal or traits_set(TRAIT_STATE_RESIST).has(1):
			return
		zq_pojia_rate = 0.5
		hp = 0.0
		# die：clearStates／clearBuffs；异化包装保留疫囊（此刻还没有阵亡状态，算活着）、囚厄接收、绝缘的外来保护等
		XAlienBattle.dying = self
		for sid in state_ids.duplicate():
			if not XResourceContext.permanent(sid) and not XAlienBattle.keeps_state(self, sid):
				state_ids.erase(sid)
				state_turns.erase(sid)
		for pid in buffs.size():
			if not XAlienBattle.keeps_buff(self, pid):
				buffs[pid] = 0
				buff_turns[pid] = 0
		XAlienBattle.dying = null
		if self is XEnemy:
			XEnemyBook.note_death(self)  # AB_EnemyBook Game_Enemy.die：击败数即时 +1
			XRaven.on_enemy_death(self)  # 渡鸦 Game_Enemy.die 包装：得魂、判铸印
		XRaceBattle.on_death(self)  # 种族 die 包装：清反攻
	if not state_ids.has(id):
		state_ids.append(id)
		_sort_states()
	var s := XDB.rec("States", id)
	var lo := int(s.get("minTurns", 1))
	var hi := maxi(lo, int(s.get("maxTurns", lo)))
	state_turns[id] = roll_state_duration(lo, hi, random, str(lifecycle_context.get("duration_key", str(id))))
	if id == XAlienBattle.corrosion_id():
		XAlienBattle.sync_corrosion(self)  # 异化 resetStateCounts：沿生命周期时长结算之后同步
	XAlienBattle.on_reset_state(self, id, alien_before)  # 异化 resetStateCounts：附加次数、疫囊回合取较长
	var source := XImportedBalance.acting_battler()
	if source != null:
		state_origins[id] = weakref(source)
	# Game_Battler.addState：新附加的状态 refresh 后由 krz 标 dirty；已有状态（_Fix_StackOverflow 分支）只续回合
	if fresh:
		if lifecycle_context.get("resources") != null:
			refresh_resources(random)
		else:
			param_refresh()
	push_state_result("addedStates", id)
	if fresh:
		XStateEffects.run_one("apply", self, s)
		param_mark_dirty()

func roll_state_duration(lo: int, hi: int, random: XRandomStream = null, event_key := "") -> int:
	if lifecycle_context.get("preview", false):
		return floori(0.5 * (hi - lo + 1)) + lo
	if random != null:
		return random.next_int_inclusive(lo, hi, "state_duration", event_key)
	if XState.current != null:
		return XState.current.world_random().next_int_inclusive(lo, hi, "state_duration", event_key)
	if _outside_random == null:
		_outside_random = XRandomStream.create(XRandomStream.hex64(XState._fresh_seed()), "world")
	return _outside_random.next_int_inclusive(lo, hi, "state_duration", event_key)

func remove_state_auto(id: int) -> void:
	_leaving_state = true
	remove_state(id)
	_leaving_state = false

func remove_state(id: int) -> void:
	if XAlienBattle.blocks_removal(self, id, _leaving_state):
		return  # 异化疫囊、囚厄、绝缘 removeState 包装：只能自然到期
	if id == 1 and state_ids.has(id) and hp <= 0.0 and XAlienBattle.route_revive(self):
		return  # 异化 revive 包装（O-108）：连命复活回池，嫁祸的保护者倒下不能复活
	var had := state_ids.has(id)
	if id == 1 and state_ids.has(id) and hp <= 0.0:
		hp = 1.0  # MV removeState(deathStateId) 先 revive，再去除阵亡状态。
	state_ids.erase(id)
	state_turns.erase(id)
	if had:
		XRaceBattle.on_state_removed(self, id)  # 种族：去掉毒鸡汤时清待结算记录
	if id == XZhenqi.POJIA_STATE:
		zq_pojia_rate = 0.5
	# YEP_BuffsStatesCore removeState：不论有没有该状态都清掉它的状态计数（死亡、抵抗等直接去状态的路径不清）
	if state_data.has("_stateCounter"):
		state_data._stateCounter.erase(str(id))
	# Game_Battler.removeState：有该状态才 refresh；krz 的 Game_Enemy.removeState 之后总标 dirty
	if had:
		if lifecycle_context.get("resources") != null:
			refresh_resources(lifecycle_context.get("random"))
		else:
			param_refresh()
		push_state_result("removedStates", id)
		var st := XDB.rec("States", id)
		XStateEffects.run_one("remove", self, st)
		if _leaving_state:
			XStateEffects.run_one("leave", self, st)
		state_origins.erase(id)  # remove AND leave still see the original source
	param_mark_dirty()
	XAlienBattle.after_removal(self, id, _leaving_state)

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

## Game_BattlerBase.debuffRate：特性 12（减益有效度）
func debuff_rate(pid: int) -> float:
	return traits_pi(TRAIT_DEBUFF_RATE, pid)


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


## 开战（Game_Battler.onBattleStart 标 need_refresh，随后 refreshAllBattlers）：启用缓存，八格变冷后截资源读上限
func param_cache_begin() -> void:
	param_cache_on = true
	param_dirty = true
	param_refresh()

## 战斗结束（inBattle 为假）：不再走缓存
func param_cache_end() -> void:
	param_cache_on = false
	param_dirty = false
	param_cells = []

func param_mark_dirty() -> void:
	effect_dirty = true
	if param_cache_on:
		param_dirty = true

## krz Game_Enemy.refresh：need_refresh 为真才让八格变冷，再由原 refresh 截 HP／MP 读上限（生命、魔法上限当场重新填入），最后清 need_refresh。
## 只做缓存这一层，不截资源；截资源的 refresh 是 XResourceContext.refresh（开头调用本函数）。
func param_refresh() -> void:
	if effect_dirty:
		effect_lists.clear()
		effect_snapshot = states().duplicate()
		effect_snapshot_valid = true
		effect_dirty = false
	if not param_cache_on:
		return
	if param_dirty or param_cells.size() != 8:
		param_cells = [null, null, null, null, null, null, null, null]
	param_dirty = false
	param(0)
	param(1)

## 惰性读格：冷格才用 compute 重算并填入
func cached_param(i: int, compute: Callable) -> float:
	if not param_cache_on:
		return compute.call(i)
	if param_cells.size() != 8:
		param_cells = [null, null, null, null, null, null, null, null]
	if param_cells[i] == null:
		param_cells[i] = compute.call(i)
	return param_cells[i]

## G_StateParam（未装 YEP_BaseParamControl 的分支）：(基础＋加值)×比率×强化率 之后再加状态备注 <G_ShuXing> 的固定值
func param(i: int) -> float:
	var v := param_base(i) + param_plus(i)
	v *= param_rate(i) * param_buff_rate(i)
	v += param_state(i)
	return roundf(clampf(v, param_min(i), param_max(i)))

## G_StateParam paramState：各状态 <G_ShuXing> 的固定值 × 层数之和。层数取 YEP 状态计数（state_data._stateCounter，
## 状态脚本写入）；原版层数变量在循环外，某状态计数为真后排在后面的状态都沿用它（state_js_probe counter.carry）。
static var _state_param_cache := {}
func param_state(i: int) -> float:
	var v := 0.0
	var ceng := 1.0
	var counters: Dictionary = state_data.get("_stateCounter", {})
	for id in state_ids:
		if not _state_param_cache.has(id):
			_state_param_cache[id] = XPower.state_params(XDB.rec("States", id))
		var c := XStateEffects._truthy_number(counters.get(str(id)))
		if c != 0.0:
			ceng = c
		v += float(_state_param_cache[id][i]) * ceng
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
		sum = sum + v - 1.0
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

## YEP_WeaponUnleash attackSkillId：按 replace_attack_objects() 的顺序找第一个 <Replace Attack: x>，都没有是技能 1。
## 原版把找到的号缓存到下次 refresh（只在忘记技能而没 refresh 时与即时查不同，正式流程碰不到），这里每次即时查。
func attack_skill_id() -> int:
	for o in replace_attack_objects():
		var id := replace_attack_of(o)
		if id > 0:
			return id
	return ATTACK_SKILL_ID

## Game_Battler.replaceAttackSkillId：状态；敌人再看敌人本身（XEnemy），角色另见 XActor
func replace_attack_objects() -> Array:
	return states()

## Game_Action.isAttack：这一招是不是此刻的「攻击」（item === $dataSkills[attackSkillId()]，物品恒否）；
## 异化投影（逆祷等，item() 是副本）不是同一个对象，恒否
func is_attack(item: Dictionary) -> bool:
	return not item.is_empty() and not XBattleLogic.is_item(item) and int(item.get("id", 0)) == attack_skill_id() and not item.has("_alienMode")

## 普通攻击技能记录（指令窗、自动战斗与不能用时的退回用它）
func attack_skill() -> Dictionary:
	return XDB.rec("Skills", attack_skill_id())

const ATTACK_SKILL_ID := 1
static var _replace_attack_cache := {}
static var _replace_attack_line := RegEx.create_from_string("(?i)<(?:ATTACK REPLACE|REPLACE ATTACK):[ ](.*)>")
static var _first_number := RegEx.create_from_string("(\\d+)")

## DataManager.processWULNotetags1：逐行认 <Replace Attack: x>／<Attack Replace: x>，取里面第一串数字（技能名写法正式数据没用到，不认）；
## 多行时后写的盖前面的
static func replace_attack_of(o) -> int:
	if not o is Dictionary:
		return 0
	var note := str(o.get("note", ""))
	if note == "":
		return 0
	if _replace_attack_cache.has(note):
		return _replace_attack_cache[note]
	var id := 0
	for line in note.split("\n"):
		var m := _replace_attack_line.search(line)
		if m:
			var n := _first_number.search(m.get_string(1))
			if n:
				id = int(n.get_string(1))
	_replace_attack_cache[note] = id
	return id

## Game_Battler.weaponUnleashes：状态；角色另见 XActor（装备 → 职业 → 角色，不看技能），敌人另见 XEnemy
func weapon_unleash_objects() -> Array:
	return states()

## 按来源顺序逐条列出 <Weapon Unleash x%: 技能>：[技能号, 几率]（加成 <Weapon Unleash: ±x%> 与自定义写法正式数据没用到，不认）
func weapon_unleashes() -> Array:
	var out := []
	for o in weapon_unleash_objects():
		out.append_array(weapon_unleash_of(o))
	return out

static var _weapon_unleash_cache := {}
static var _weapon_unleash_line := RegEx.create_from_string("(?i)<WEAPON UNLEASH[ ](\\d+)([%％]):[ ](.*)>")

## DataManager.processWULNotetags1：逐行认 <Weapon Unleash x%: 技能>，几率 x×0.01，技能取名字里第一串数字（技能名写法正式数据没用到，不认）
static func weapon_unleash_of(o) -> Array:
	if not o is Dictionary:
		return []
	var note := str(o.get("note", ""))
	if note == "":
		return []
	if _weapon_unleash_cache.has(note):
		return _weapon_unleash_cache[note]
	var out := []
	for line in note.split("\n"):
		var m := _weapon_unleash_line.search(line)
		if m:
			var n := _first_number.search(m.get_string(3))
			if n:
				out.append([int(n.get_string(1)), float(m.get_string(1)) * 0.01])
	_weapon_unleash_cache[note] = out
	return out

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

## Game_BattlerBase.attackElements：只取特性 31，可为空（无特性 31 的敌人普攻无属性）；角色的空手物理见 XActor。
func attack_elements() -> Array:
	return traits_set(TRAIT_ATTACK_ELEMENT)


# ---- 资源 ----
## 正式 rpg_οbjects.js 的 maxTp 为 200（角色另有 dsPassiveSkill passiveEXTTP）。
func max_tp() -> float:
	return 200.0


## Game_Battler.refresh：夹资源并同步阵亡状态（序列 HP + 恢复时也必须去除阵亡）。
func refresh_resources(random: XRandomStream = null) -> void:
	var context: XResourceContext = lifecycle_context.get("resources")
	var root := context == null
	if root:
		context = XResourceContext.new()
		context.random = random
		context.seed_result(self, runtime_result)
	context.refresh(self)
	if root:
		runtime_result = context.result(self).duplicate(true)


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


## Game_BattlerBase.clearStates（PermanentState 保留 <Permanent>）：不 refresh、不标 dirty
func clear_states() -> void:
	for sid in state_ids.duplicate():
		if not XResourceContext.permanent(sid) and not XAlienBattle.keeps_state(self, sid):
			state_ids.erase(sid)
			state_turns.erase(sid)
			XRaceBattle.on_state_removed(self, sid)


## Game_BattlerBase.recoverAll：清状态后按（可能是旧缓存的）上限回满，YEP_BattleEngineCore 再 refresh（只消费 dirty，不截资源）
func recover_all() -> void:
	clear_states()
	resource_death_blocked = false
	hp = mhp
	mp = mmp
	param_refresh()

func is_dead() -> bool:
	return state_ids.has(1) or (hp <= 0.0 and not immortal and not resource_death_blocked and not traits_set(TRAIT_STATE_RESIST).has(1))

func is_alive() -> bool:
	return not is_dead()

func hp_rate() -> float:
	return hp / maxf(mhp, 1.0)
