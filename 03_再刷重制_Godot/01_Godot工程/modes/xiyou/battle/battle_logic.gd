class_name XBattleLogic
extends RefCounted
## 战斗规则（不含画面）：MV 回合制——全员选好行动后按速度排序依次执行。
## 伤害交给 XDamage（与正式版对照过），这里负责命中/闪避/会心、技能消耗、效果、状态回合、敌人 AI、奖励。
## 每次行动返回一组记录（log），画面层按记录播放；无界面测试也直接用这些记录。
## 另含：技能冷却/预热（YEP_X_SkillCooldowns）、战斗中用物品、反击/魔法反射（MV invokeAction）、神话敌人（XEnemy）。
## 行动顺序按 Olivia_BattleSysOTB（见「回合」一节）。

const DEATH_STATE := 1
const GUARD_SKILL := 2
const ATTACK_SKILL := 1

var troop_id := 0
var actors: Array = []          # XActor（出战）
var enemies: Array = []         # XEnemy
var turn := 0
var can_escape := true
var escaped := false
## MOG_TrPopUpBattle：掉落已在敌人倒下时实时获得，胜利时不再发放物品（$gameTemp._trBatDropLock）
var drop_lock := false
## 每个敌人的掉落（Game_Enemy._treasure.item）：倒下时或结算时第一次取用时抽定，之后不变
var _treasure := {}
var _drop_granted := {}
var _rewards_granted := false
## 开战时出战栏里的饿狼（G._battleGarou）、是否 Boss 战（G._bossBattle）与胜利结算要提示的文字（神之触媒；画面还没接）
var _garou = null
var _garou_boss := false
var victory_texts: Array = []
## Rule parameter captured at battle start; icon visibility is presentation only.
var advance_loot_on_collapse := false
var auto := false
var state: XState
var random: XBattleRandom
## Debug replay boundaries, captured before enemy setup consumes any random value.
var replay_runtime_start := {}
var replay_battle_start := {}
var _ids := {}
var _action_resources: XResourceContext
var _battle_resources: XResourceContext
var battle_start_effects := {}
var lifecycle_effects: Array = []
var _formula_outcome := {}
var _damage_record := {}
## 魔法反射回行动者自己的这次 apply（导入角色平衡照样缩放）
var _reflecting := false

func _rule() -> XRandomStream:
	if random == null and state != null and troop_id == 0:
		return state.world_random()
	if random == null:
		random = state.reserve_battle_random() if state != null else XBattleRandom.create(XRandomStream.hex64(XState._fresh_seed()))
	return random.rule

func _float(reason: String) -> float:
	return _rule().next_float(reason, str(turn))

func _int(lo: int, hi: int, reason: String) -> int:
	return _rule().next_int_inclusive(lo, hi, reason, str(turn))

func _mod(n: int, reason: String) -> int:
	return _rule().next_index_mod(n, reason, str(turn))

func stable_id(b: XBattler) -> String:
	if _ids.has(b):
		return _ids[b]
	return ("actor:" + str(actors.find(b)) if b is XActor else "enemy:" + str(enemies.find(b)))
## 测试用：>= 0 时固定神话判定（0 必为神话，100 必不是）
var elite_roll := -1.0
## 测试用：敌人等级浮动的随机数（<0 为随机）
var level_roll := -1.0


## O-026：轮回困难（1460/1461）Establish 附加伤害时，原版本次普通伤害的弹字被 gainHp 改写成最后一次附加值
##（如普通伤害 380 弹成 70），true 时普通伤害照实显示；附加的 atk/mat 两次弹字不变。
const ESTABLISH_TRUE_POPUP := true

## 敌群事件（Game_Troop._eventFlags）：页序号 → 已执行（span 0 战斗、1 回合各一次；1 在回合开始时清除）
var _event_flags := {}
## 强制行动清掉的首位行动者（OTB startTurn 先取出首位并 makeActions，事件里 forceAction 的 clearActions 把它清空）
var _cleared := {}
## 敌群事件里尚未翻译、本次跳过的指令（"代码 内容 页"）
var troop_event_skipped: Array = []
## 技能／物品公共事件（XBattleCommonEvent）里尚未翻译、本次跳过的指令（"代码 内容 公共事件N"）
var common_event_skipped: Array = []
## 战斗内事件的游标（XBattleEventRunner）：当前页没执行完时非空；本次检查的条件 {first, turn_end, moment, guard}
var _runner: XBattleEventRunner = null
var _check := {}
## 等待画面应答的消息 {token, frame, msg}；token 每场战斗递增，旧 token 无效
var _waiting := {}
var _event_token := 0
## 无界面宿主（run_turn）的消息应答：msg -> 选项序号／数值／null；未设置时确认（选项取默认项）
var message_responder: Callable
## makeUniqueNames：敌人 → 字母（出现时才分配）、原名 → 已分配个数
var _letters := {}
var _names_count := {}

func setup(troop: int, s: XState, random_context: XBattleRandom = null) -> void:
	XGuyu.setup(self)  # 谷雨 BattleManager.setup 包装（原 setup 之前）：reset、activeBattle
	s.sync_difficulty_on_battle()
	random = random_context if random_context != null else s.reserve_battle_random()
	replay_runtime_start = s.runtime_random_snapshot()
	replay_battle_start = random.snapshot()
	_ids.clear()
	turn = 0
	escaped = false
	drop_lock = false
	_event_flags.clear()
	_cleared.clear()
	troop_event_skipped.clear()
	_clear_event_cursor()
	_letters.clear()
	_names_count.clear()
	_treasure.clear()
	_drop_granted.clear()
	_rewards_granted = false
	advance_loot_on_collapse = XConfig.flag("MOG_TrPopUpBattle_Key")
	current_order.clear()
	next_order.clear()
	_acted.clear()
	_speed.clear()
	_orders_made = false
	state = s
	_battle_resources = null
	battle_start_effects.clear()
	lifecycle_effects.clear()
	troop_id = troop
	XImportedBalance.set_acting(null)
	actors = s.battle_members()
	XYomiJingliu.start_battle(self)  # 镜流 startBattle 包装：放血累计清零
	XGuyu.after_load(s)  # 谷雨 startBattle 包装：syncAll（同读档）
	_garou = XGarou.start_battle(actors)  # 饿狼 startBattle 包装：同步、记下出战的饿狼
	victory_texts.clear()
	XZhenqi.battle_setup(s, troop)  # 真气：本场路线、楼层、溢出计数（BattleManager.setup）
	enemies.clear()
	var t := XDB.rec("Troops", troop)
	# Game_Troop.setup：所有成员 slot 都建出（隐藏成员也是，序号与敌群成员一致，335 出现时只改隐藏标记）
	var strong_count := XEnemy.deployed_strong_count(actors)
	for m in t.get("members", []):
		var e := XEnemy.new().setup(int(m.enemyId), s.difficulty, elite_roll, _rule(), strong_count)
		e.setup_level(actors.reduce(func(acc, x): return maxi(acc, int(x.level)), 1), level_roll, _rule())
		e.set_meta("x", float(m.x))
		e.set_meta("y", float(m.y))
		e.hidden = bool(m.get("hidden", false))
		enemies.append(e)
	XEnemyBook.bind_battle(s, enemies)
	_garou_boss = XGarou.boss_battle(enemies)  # 开战时的敌群成员（含隐藏）有没有 Boss 血条
	XZhenqi.troop_setup(enemies.filter(func(e): return not e.hidden), s.difficulty, elite_roll, _rule())  # 瓶颈之战：幻化为参照守层者之力（Game_Troop.setup）
	for i in range(actors.size()):
		_ids[actors[i]] = "actor:%d:%d" % [i, actors[i].actor_id]
	# 包含隐藏 slot；335 出现和 336 变身都不改变本场成员身份。
	for i in range(enemies.size()):
		_ids[enemies[i]] = "enemy:%d:%d" % [i, enemies[i].enemy_id]
	make_unique_names()
	# 异化夺舍：原版锁队在 startBattle 最外层，之前的（敌人等级、强敌计数、逃跑率、成员身份）算上要被夺舍的队友，
	# 原 startBattle 里的（开战移除状态、初始 TP、开战状态效果、预热）与种族包装（锁队之后）不算；锁队本身用全员
	var everyone: Array = actors
	var leaving := XAlienBattle.possession_partners(self)
	if not leaving.is_empty():
		actors = everyone.filter(func(a): return not leaving.has(a))
	XToji.start_battle(self)  # 甚尔 startBattle 包装（原 startBattle 之前）：设第一形态（随后开战清 removeAtBattleEnd 状态）
	XSukuna.start_battle(self)  # 宿傩 startBattle 包装（之前）：清战斗数据、同步技能
	XBlackFlash.start_battle(self)  # 黑闪 startBattle 包装（宿傩之内）：round 归 0、清数据
	for a in actors:
		for sid in a.state_ids.duplicate():
			if not bool(XDB.rec("States", sid).get("removeAtBattleEnd", false)):
				continue
			_state_remove(a, sid)
	_start_battle_effects()
	for b in actors + enemies:
		b.start_warmups()
	_escape_ratio = 0.5 * _avg_agi(everyone) / maxf(_avg_agi(enemies), 1.0)
	# BattleManager.startBattle：inBattle 起敌人走 krz 能力值缓存；逃跑率等开战前的读取不留在格子里
	for e in enemies:
		e.param_cache_begin()
	XRaceBattle.start(self)  # 种族祝福：BattleManager.startBattle 包装清本场数据，出战成员建数据（记开战最大生命）
	actors = everyone
	XYunshang.start_battle(self)  # 云裳 startBattle 包装：建战斗数据、天衣无缝全醒
	XAlienBattle.start(self)  # 异化：Game_Troop.setup 的遭遇＋startBattle 的锁队、蜕壳护盾与提示
	XSukuna.start_tp(self)  # 宿傩 startBattle 包装（之后）：TP 至少 60
	XCat.trial_start_battle(self)  # 小猫试炼 startBattle 包装（之后）：178 回满、TP 满
	# 本版改过的 BattleManager.startBattle：每场开战预约公共事件 1320「战斗开始时调整变量」，开战第一次事件检查先跑它
	XBattleCommonEvent.reserve(self, XBattleCommonEvent.START_EVENT)

func _new_lifecycle_resources() -> XResourceContext:
	var resources := XResourceContext.new()
	resources.in_battle = random != null
	resources.random = _rule()
	resources.lifecycle_inputs = {"variables": vars(), "switches": state.switches if state != null else {}, "party_members": actors}
	return resources

func _start_battle_effects() -> void:
	_battle_resources = _new_lifecycle_resources()
	for b in state.members() + enemies:
		if not _ids.has(b):
			_ids[b] = "reserve:%d" % b.actor_id if b is XActor else stable_id(b)
		_battle_resources.labels[b] = stable_id(b)
		_battle_resources.seed_result(b, b.runtime_result)
	# Native Game_Unit: initialize all unit members, then evaluate Battle effects.
	for members in [actors, enemies]:
		for b in members:
			if not b.is_preserve_tp():
				var initial := float(_mod(25, "initial_tp"))
				_battle_resources.silent_gain(b, "tp", initial - b.tp)
			b.param_mark_dirty()
		var effect_members: Array = state.members() if members == actors else enemies
		for b in effect_members:
			_refresh_battler(b)
			XStateEffects.run("battle", b, _battle_resources.state_context(b))
	_battle_start_states()
	var snapshots := {}
	for b in state.members() + enemies:
		snapshots[stable_id(b)] = _battle_resources.snapshot(b).duplicate(true)
	battle_start_effects = {"members": snapshots, "journal": _battle_resources.journal.duplicate(true), "error": _battle_resources.error}
	_battle_resources.publish()
	_battle_resources = null

func _operation_resources(b: XBattler) -> XResourceContext:
	var resources := _action_resources if _action_resources != null else _battle_resources
	if resources == null:
		resources = _new_lifecycle_resources()
		resources.labels[b] = stable_id(b)
		resources.seed_result(b, b.runtime_result)
	return resources

func _finish_lifecycle_operation(resources: XResourceContext, b: XBattler) -> void:
	if resources != _action_resources and resources != _battle_resources:
		resources.publish()
		lifecycle_effects.append({"member": stable_id(b), "after": resources.snapshot(b).duplicate(true), "journal": resources.journal.duplicate(true), "error": resources.error})

func _state_add(b: XBattler, id: int) -> void:
	var resources := _operation_resources(b)
	resources.add_state(b, id)
	_finish_lifecycle_operation(resources, b)

## Game_Battler.gainHp：走资源上下文（宿傩伤口、异化 wrapHp 帧内归零／烈变加成、连命／嫁祸／空壳路由、首领扣血上限），
## 给模块里不经伤害计算的直接扣血用（渡鸦收割／回响、米拉劫火追加；审查第 14 期 P3）
func gain_hp(b: XBattler, amount: float) -> void:
	var resources := _operation_resources(b)
	resources.gain(b, "hp", amount)
	_finish_lifecycle_operation(resources, b)

func _state_remove(b: XBattler, id: int, automatic := false) -> void:
	var resources := _operation_resources(b)
	b.remove_state_with_context(id, resources.state_context(b), automatic)
	_finish_lifecycle_operation(resources, b)

func _refresh_battler(b: XBattler) -> void:
	var resources := _operation_resources(b)
	b.refresh_with_context(_rule(), resources.state_context(b))
	_finish_lifecycle_operation(resources, b)


## dsPassiveSkill Scene_Battle.start：每个出战角色依次处理开战状态标签——自己、随机队友、随机敌人、随机任一目标、
## 全体敌人、全队；之后刷新所有角色的被动缓存。
func _battle_start_states() -> void:
	for a in actors:
		for tag in a.battle_start_state_tags():
			if _float("start_state") * 100.0 >= float(tag[2]):
				continue
			var sid := int(tag[1])
			match str(tag[0]):
				"StartPushState":
					_state_add(a, sid)
				"StartRomActPushState":
					var others := actors.filter(func(x): return x != a)
					if not others.is_empty():
						_state_add(others[_mod(others.size(), "start_ally")], sid)
				"StartRomEmePushState":
					var foes := alive(enemies)
					if not foes.is_empty():
						_state_add(foes[_mod(foes.size(), "start_enemy")], sid)
				"StartRomPushState":
					var all: Array = actors + alive(enemies)
					_state_add(all[_mod(all.size(), "start_any")], sid)
				"StartAEPushState":
					for e in alive(enemies):
						_state_add(e, sid)
				"StartWTPushState":
					for x in actors:
						_state_add(x, sid)
	for a in actors:
		a.refresh_passive()
	for e in enemies:
		e.refresh_passive()


func alive(list: Array) -> Array:
	return list.filter(func(b): return b.is_alive())


# ---- 画面快照：日志写入时记下表现要用的值，表现层只读日志（整次行动先结算完才演出，播放时的实时状态已是最终值） ----
## 一个战斗者此刻的画面读数（血条、状态栏、待机动作、能否行动）
func view_of(b: XBattler) -> Dictionary:
	var icons := []
	for st in b.states():
		if int(st.get("iconIndex", 0)) > 0:
			icons.append(int(st.iconIndex))
	return {"hp": b.hp, "mp": b.mp, "tp": b.tp, "mhp": b.mhp, "mmp": b.mmp, "mtp": b.max_tp(), "dead": b.is_dead(),
		"guarding": b.guarding, "can_move": can_move(b), "icons": icons, "shield": b.shield, "look": XAppearance.battler_key(b),
		"guyu_shield": XGuyu.shield_of(b), "guyu_text": XGuyu.status_text(b)}  # look：换装卡换图；guyu_*：谷雨花荫与侧栏状态字（画面用）


## 全体战斗者 → view_of
func views(list: Array = []) -> Dictionary:
	var out := {}
	for b in (list if not list.is_empty() else actors + enemies):
		if b != null and not out.has(b):
			out[b] = view_of(b)
	return out


## 全体战斗者 → 能否行动（spriteCanMove）与是否活着，行动序列每条指令执行前记一次（MOVE/JUMP/FACE 等按当时的状态）
func move_flags() -> Dictionary:
	var out := {}
	for b in actors + enemies:
		out[b] = [can_move(b), b.is_alive()]
	return out


## 命中记录（含反击、反射的命中）写入时附上行动者与目标的结算后读数
func mark_views(entries: Array) -> Array:
	for l in entries:
		if l is Dictionary and l.get("type") == "hit":
			var list := [l.target]
			if l.get("user") is XBattler:
				list.append(l.user)
			l.views = views(list)
	return entries

func is_won() -> bool:
	return alive(enemies).is_empty()

func is_lost() -> bool:
	return alive(actors).is_empty()

func vars() -> Array:
	return state.variable_array()


# ---- 技能可用 ----
static func is_item(rec: Dictionary) -> bool:
	return rec.has("itypeId")

## YEP_SkillCore 的消耗备注（逐行、冒号后恰一个空格、只认整数）：<MP Cost: n> 改基础 MP、<MP Cost: n%> 记最大 MP 比例，TP、HP 同理（HP 默认 0）。
## 「<MP Cost: 7.5%>」这类带小数的写法原版认不出（7225 降众天华比例为 0）；O-129 开着时 MP 比例认小数（按 7.5% 收）。按备注缓存
## O-129（用户 10-31 定：做）：false＝原版，只扣基础 MP
static var o_decimal_mp_cost := true
static var _note_cost_cache := {}
static func note_costs(skill: Dictionary) -> Dictionary:
	var note := str(skill.get("note", ""))
	var key := note if not o_decimal_mp_cost else "o129:" + note
	if not _note_cost_cache.has(key):
		var out := {}
		for line in note.split("\n"):
			for kind in ["MP", "TP", "HP"]:
				var m := RegEx.create_from_string("(?i)<(?:%s COST):[ ](\\d+)>" % kind).search(line)
				if m != null:
					out[kind.to_lower() + "Cost"] = int(m.get_string(1))
					break
				# O-129：MP 比例认小数（7225 降众天华 <MP Cost: 7.5%>；原版 YEP 正则只认整数，比例 0、只扣基础）
				var digits := "\\d+(?:\\.\\d+)?" if o_decimal_mp_cost and kind == "MP" else "\\d+"
				m = RegEx.create_from_string("(?i)<(?:%s COST):[ ](%s)([%%％])>" % [kind, digits]).search(line)
				if m != null:
					out[kind.to_lower() + "CostPer"] = float(m.get_string(1)) * 0.01
					break
		_note_cost_cache[key] = out
	return _note_cost_cache[key]

## YEP_SkillCore skillHpCost：⌊基础＋最大HP×比例⌋、不低于 0（熟练度公式原样、费用为正时至少 1，等于不变）。
## 异化空壳在战斗中按开场参照生命上限算（Adv:126），见 XAlienBattle.hp_cost_mhp
static func skill_hp_cost(a: XBattler, skill: Dictionary) -> int:
	if is_item(skill):
		return 0
	var nc := note_costs(skill)
	if not nc.has("hpCost") and not nc.has("hpCostPer"):
		return 0
	return maxi(0, floori(float(nc.get("hpCost", 0)) + XAlienBattle.hp_cost_mhp(a) * float(nc.get("hpCostPer", 0.0))))

## canPaySkillHpCost：费用为 0 能付，否则生命要大于费用；异化空壳／嫁祸／连命另看护盾、保护者、生命池（Adv:127）
static func can_pay_hp(a: XBattler, skill: Dictionary) -> bool:
	var cost := skill_hp_cost(a, skill)
	var alien = XAlienBattle.can_pay_hp(a, cost)
	if alien != null:
		return alien
	return cost <= 0 or a.hp > cost

## 最大 MP 比例部分占整笔 MP 的份额（installSkillCostRuntime C.percentShare）
static func percent_share(a: XBattler, skill: Dictionary) -> float:
	var nc := note_costs(skill)
	var per := float(nc.get("mpCostPer", 0.0))
	if per <= 0.0:
		return 0.0
	var pct := a.mmp * per
	var flat := maxf(0.0, float(nc.get("mpCost", skill.get("mpCost", 0))))
	return pct / (pct + flat) if pct > 0.0 else 0.0

## installSkillCostRuntime 第 5 节：最大 MP 比例部分的合计减耗下限 −100%（挑战加耗最多 ×2）
const PERCENT_FLOOR := -100.0

## 实扣与显示共用的费用（Game_Actor.skillMpCost／skillTpCost 全链）。
## installSkillCostRuntime 最后安装、在最外层：角色的技能带最大 MP 比例且合计减耗低于 −100% 时，按原减耗与按下限各算一次，
## 再按比例部分的份额合成（固定部分、TP 不变）。
## panel：异化缄默的面板费用（A.panelMpCost：mcr 记 1、不按缄默归零）
func skill_cost(a: XBattler, skill: Dictionary, panel := false) -> Dictionary:
	var cost := _skill_cost(a, skill, panel, 0.0)
	if panel or not (a is XActor) or is_item(skill):
		return cost
	var share := percent_share(a, skill)
	var r := consume_reduce(a, skill)
	if share <= 0.0 or r >= PERCENT_FLOOR:
		return cost
	var floored := _skill_cost(a, skill, panel, PERCENT_FLOOR - r)
	cost.mp = maxi(0, floori(floored.mp + (cost.mp - floored.mp) * (1.0 - share)))
	return cost

## dsPassiveSkill 减耗：指定技能＋类型（1 战技、2 魔法）＋全体，相加后封顶 100（只算角色）
static func consume_reduce(a: XBattler, skill: Dictionary, shift := 0.0) -> float:
	if not (a is XActor):
		return 0.0
	var cache: Dictionary = a.passive_cache().get("consumeReduce", {})
	var reduce := float(cache.get("bySkill", {}).get(int(skill.get("id", 0)), 0))
	var stype := int(skill.get("stypeId", 0))
	if stype in [1, 2]:
		reduce += float(cache.get("byType", {}).get("Zj" if stype == 1 else "Mf", 0))
	reduce += float(cache.get("all", 0)) + shift
	return minf(reduce, 100.0)

## shift：加到全体减耗上的量（下限那一遍用）
func _skill_cost(a: XBattler, skill: Dictionary, panel: bool, shift: float) -> Dictionary:
	if is_item(skill):
		return {"mp": 0, "tp": 0}
	var nc := note_costs(skill)
	# YEP skillMpCost：(基础＋最大MP×比例)×mcr 向下取整、不低于 0；skillTpCost：基础＋最大TP×比例 向下取整
	var mp := float(nc.get("mpCost", skill.get("mpCost", 0))) + a.mmp * float(nc.get("mpCostPer", 0.0))
	var tp := float(nc.get("tpCost", skill.get("tpCost", 0))) + a.max_tp() * float(nc.get("tpCostPer", 0.0))
	var cost := {"mp": maxi(0, floori(mp * (1.0 if panel else a.mcr))), "tp": maxi(0, floori(tp))}
	if a is XActor:
		var reduce := consume_reduce(a, skill, shift)
		cost.mp = floori(cost.mp * (1.0 - reduce / 100.0))
		cost.tp = floori(cost.tp * (1.0 - reduce / 100.0))
	cost = {"mp": XMira.cost(a, skill, int(cost.mp)), "tp": XMira.cost(a, skill, int(cost.tp))}  # 米拉禁忌 skillMpCost／skillTpCost 包装：主动技 ×0.75
	cost.tp = XSukuna.tp_cost(a, skill, int(cost.tp))  # 宿傩 skillTpCost 包装：领域中解／捌减半（种族包装在外）
	if not panel and XAlienBattle.silence_skill(a, skill):
		cost.mp = 0  # 异化缄默 skillMpCost 包装（Adv:132）：选定技能不花 MP，改锁生命上限
	var guyu := XGuyu.mp_cost(a, skill, 1.0 if panel else a.mcr, consume_reduce(a, skill, shift))
	if guyu >= 0:
		cost.mp = guyu  # 谷雨 skillMpCost 包装（米拉、异化之外，种族之内）：五个主动技按最大 MP 比例
	return {"mp": XRaceBattle.cost(a, int(cost.mp)), "tp": XRaceBattle.cost(a, int(cost.tp))}

## paySkillHpCost：直接减生命（_hp -= 费用，不走伤害）；异化连命扣池、嫁祸扣保护者、空壳扣护盾（Adv:128）
func pay_hp(u: XBattler, skill: Dictionary) -> void:
	var cost := skill_hp_cost(u, skill)
	if not XAlienBattle.pay_hp(self, u, cost):
		u.hp -= cost

func can_use(a: XBattler, skill: Dictionary) -> bool:
	if skill.is_empty():
		return false
	var occ := int(skill.get("occasion", 0))
	if occ != 0 and occ != 1:
		return false
	if XImportedBalance.is_disabled_actor(a):  # installImportedBalanceRuntime：禁用的导入角色 canUse 全否
		return false
	if is_item(skill):
		return a.is_actor() and state.items.get(int(skill.id), 0) > 0
	# 云裳九曲回针 meetsSkillConditions：醒着的针眼每回合一次不看冷却（原版临时把冷却设 0 再判，预热照判）
	if (a.cooldown_left(int(skill.id)) if not XYunshang.eye_bypass(a, skill) else ceili(float(a.warmups.get(int(skill.id), 0)))) > 0:
		return false
	if not XCat.legal(self, a, skill):  # 小猫剑圣的剑技／试炼条件、178 没持剑不能用物理技能
		return false
	if not XTusuXuan.meets(a, skill):  # 屠苏／璇 bindGrowth meetsSkillConditions：没解锁的专属技能、归形
		return false
	if a.is_actor() and int(skill.stypeId) > 0:
		if not a.traits_set(XBattler.TRAIT_STYPE_ADD).has(int(skill.stypeId)):
			return false
		# 异化缄默 isSkillTypeSealed 包装：选定技能不受魔法沉默封印
		if a.traits_set(XBattler.TRAIT_STYPE_SEAL).has(int(skill.stypeId)) and not XAlienBattle.silence_bypass(a, skill) and not XToji.switch_unsealed(a, skill):  # 甚尔：切换技能不受战技类别封印
			return false
	if a.traits_set(XBattler.TRAIT_SKILL_SEAL).has(int(skill.id)):
		return false
	if XAlienBattle.sealed(self, a, skill):  # 异化蚀术 isSkillSealed 包装：被封印的技能
		return false
	if not wtype_ok(a, skill):
		return false
	if not XGarou.meets(a, skill):  # 饿狼 meetsSkillConditions：未到形态、追击不能用，认真一拳要琦玉模式
		return false
	if not XYomiJingliu.meets(a, skill):  # 黄泉 meetsSkillConditions：残梦不满 9 不能用 10174
		return false
	if not XYunshang.meets(a, skill, self):  # 云裳 meetsSkillConditions：没解锁、敕衣点神要有人穿天衣、收针要有人觉醒
		return false
	if not XToji.meets(a, skill):  # 甚尔 meetsSkillConditions：主技能只能用当前形态、切换技能要可切且不是当前形态
		return false
	if not XSukuna.meets(a, skill, self):  # 宿傩 meetsSkillConditions：解锁、领域冷却、神灶要蓄力目标、神灶：开要准备层
		return false
	if not XMira.meets(a, skill):  # 米拉 meetsSkillConditions：人形／黑龙技按形态、解放的进阶与等级、劫焰不能单放
		return false
	if not XGuyu.meets(a, skill):  # 谷雨 meetsSkillConditions：五个主动技只有谷雨能用、要解锁，花期／终结／花荫／转移看战斗内状态
		return false
	if XAlienBattle.blocks_skill(a, skill):  # 异化逆祷 meetsSkillConditions：模板外的伤害技能不能用
		return false
	if XAlienBattle.blocks_borrowed(state, a, skill):  # 异化百相、无面 meetsSkillConditions：被替换的、没选中的仿形、来源不会了的借来技能
		return false
	if XAlienBattle.silence_blocks(self, a, skill):  # 异化缄默 canPaySkillCost：生命上限锁不下了
		return false
	if not can_pay_hp(a, skill):  # YEP_SkillCore canPaySkillCost：先看 HP 费用
		return false
	var c := skill_cost(a, skill)
	var mp = XAlienBattle.glutton_mp(a)  # 异化饕餮 canPaySkillCost：MP 费用看饥饿储备
	return (a.mp if mp == null else float(mp)) >= c.mp and a.tp >= c.tp

## Game_Actor.isSkillWtypeOk：技能没有武器类型要求，或装着其中一种（敌人恒真）。
## isWtypeEquipped 经 dsPassiveSkill 改写：被动 <SkETypeAll: t> 装着任一列出类型的武器时全部类型都算装着；
## <SkEquipType: t> 有值时只认该类型（正式数据未用）；否则看身上武器的类型。
static func wtype_ok(a: XBattler, skill: Dictionary) -> bool:
	if not a is XActor:
		return true
	var need := [int(skill.get("requiredWtypeId1", 0)), int(skill.get("requiredWtypeId2", 0))]
	if need == [0, 0]:
		return true
	return (need[0] > 0 and wtype_equipped(a, need[0])) or (need[1] > 0 and wtype_equipped(a, need[1]))


static func wtype_equipped(a: XActor, wtype: int) -> bool:
	var weapons := []
	for e in a.equip_list():
		if str(e.get("kind", "")) == "weapon" or e.has("wtypeId"):
			weapons.append(int(e.get("wtypeId", 0)))
	var all_types := []
	var only := 0
	for o in a.equip_list() + a.skills() + a.states():
		var meta: Dictionary = o.get("meta", {})
		if meta.has("SkETypeAll") and str(meta.SkETypeAll).strip_edges().is_valid_int():
			all_types.append(int(str(meta.SkETypeAll).strip_edges()))
		if meta.has("SkEquipType") and str(meta.SkEquipType).strip_edges().is_valid_int() and int(str(meta.SkEquipType).strip_edges()) != 0:
			only = int(str(meta.SkEquipType).strip_edges())
	if all_types.any(func(t): return weapons.has(t)):
		return true
	if only != 0:
		return only == wtype
	return weapons.has(wtype)


## 角色的可用主动技能（隐藏的被动不列出）
func usable_skills(a: XActor) -> Array:
	return battle_skills(a).filter(func(s): return can_use(a, s))

## 技能列表里显示的全部主动技能（含冷却中/魔法不足的，画面上显示为灰色）
func battle_skills(a: XActor) -> Array:
	var out := []
	for s in a.skills():
		if int(s.id) > GUARD_SKILL and int(s.stypeId) != 4 and not s.get("meta", {}).has("Hide in Battle") and XSukuna.listed(a, s) and XToji.listed(a, s):
			out.append(s)
	return out

## 战斗中可用的物品（MV Window_BattleItem：场合为「总是」或「战斗中」且持有）
func battle_items() -> Array:
	var out := []
	for id in state.items.keys():
		var rec := XDB.rec("Items", int(id))
		if not rec.is_empty() and int(state.items[id]) > 0 and [0, 1].has(int(rec.get("occasion", 3))):
			out.append(rec)
	out.sort_custom(func(x, y): return int(x.id) < int(y.id))
	return out


# ---- 目标 ----
func targets_for(a: XBattler, skill: Dictionary, chosen: XBattler = null) -> Array:
	# 异化 makeTargets 包装：逆祷原 scope 3～6 改随机友方 n 个，恶愿去掉自己
	var n := XAlienBattle.prayer_random_count(skill)
	if n > 0:
		var friends := actors if a.is_actor() else enemies
		var out := []
		for i in range(n):
			if not alive(friends).is_empty():
				out.append(_random_target(alive(friends)))
		XYunshang.set_primary(a, out)
		return out
	var list := XAlienBattle.filter_targets(a, skill, XYunshang.targets(self, a, skill, _targets_for(a, skill, chosen), chosen))  # 云裳云丝展幅、千军入袖收袖 makeTargets 包装在异化之内
	XYunshang.set_primary(a, list)  # 云裳 startAction 包装：_yunPrimary＝第一个目标
	return list


func _targets_for(a: XBattler, skill: Dictionary, chosen: XBattler = null) -> Array:
	var foes := enemies if a.is_actor() else actors
	var friends := actors if a.is_actor() else enemies
	var scope := int(skill.get("scope", 1))
	match scope:
		1:
			if chosen and chosen.is_alive() and foes.has(chosen):
				return [chosen]
			return [_random_target(alive(foes))] if not alive(foes).is_empty() else []
		2:
			return alive(foes)
		3, 4, 5, 6:
			var out := []
			for i in range(scope - 2):
				if not alive(foes).is_empty():
					out.append(_random_target(alive(foes)))
			return out
		7:
			if chosen and chosen.is_alive() and friends.has(chosen):
				return [chosen]
			var low := alive(friends)
			low.sort_custom(func(x, y): return x.hp_rate() < y.hp_rate())
			return low.slice(0, 1)
		8:
			return alive(friends)
		9:
			if chosen and chosen.is_dead() and friends.has(chosen):
				return [chosen]
			return friends.filter(func(b): return b.is_dead()).slice(0, 1)
		10:
			return friends.filter(func(b): return b.is_dead())
		11:
			return [a]
	return []

## MV：按目标的 tgr（受击率）加权随机
func _random_target(list: Array) -> XBattler:
	var total := 0.0
	for b in list:
		total += b.tgr
	var r := _float("target") * total
	for b in list:
		r -= b.tgr
		if r <= 0.0:
			return b
	return list[0]


# ---- 敌人 AI（MV Game_Enemy.selectAllActions）----
## 没有可用行动（行动列表空，如木桩；或条件、canUse 全不满足）返回 {}：Game_Enemy.makeActions 不设行动，这一轮不行动（参照 attack_query_probe skip 组）。
func enemy_action(e: XEnemy) -> Dictionary:
	var list: Array = e.data().get("actions", []).filter(func(act): return _meets(e, act) and can_use(e, XDB.rec("Skills", int(act.skillId))))
	if list.is_empty():
		return {}
	var rmax := 0
	for act in list:
		rmax = maxi(rmax, int(act.rating))
	var zero := rmax - 3
	list = list.filter(func(act): return int(act.rating) > zero)
	var sum := 0
	for act in list:
		sum += int(act.rating) - zero
	var r := _int(0, sum - 1, "enemy_action")
	for act in list:
		r -= int(act.rating) - zero
		if r < 0:
			return XDB.rec("Skills", int(act.skillId))
	return XDB.rec("Skills", int(list[0].skillId))

func _meets(e: XEnemy, act: Dictionary) -> bool:
	var p1 := float(act.conditionParam1)
	var p2 := float(act.conditionParam2)
	match int(act.conditionType):
		1:
			var n := turn
			return n == int(p1) if p2 == 0 else (n > 0 and n >= p1 and int(n - p1) % int(p2) == 0)
		2:
			return e.hp_rate() >= p1 and e.hp_rate() <= p2
		3:
			return e.mp / maxf(e.mmp, 1.0) >= p1 and e.mp / maxf(e.mmp, 1.0) <= p2
		4:
			return e.is_state_affected(int(p1))
		5:
			return actors.any(func(a): return a.level >= p1)
		6:
			return state.switch(int(p1))
	return true


## 自动战斗（挂机或自动按钮）一次行动，照正式版 Game_Actor.makeAction 链：
## 智能AI开着（默认）——技能顺序表排了且能用就照表（XdRs_HangUp makeAction），否则 XSmartAI 选；没有可选的退回普通攻击。
## 智能AI关着——照表，否则普通攻击（XdRs_HangUp 的 makeAction 不再走 MV 原生评估）。
func auto_battle_action(a: XActor) -> Array:
	var guyu := XGuyu.auto_action(self, a)  # 谷雨 makeAutoBattleActions 包装（云裳之外：modules.json 谷雨第 37、云裳第 30）：固定判断压过挂机与智能 AI
	if not guyu.is_empty():
		return guyu
	var r := _auto_battle_action(a)
	XYunshang.auto_battle(self, a)  # 云裳 makeAutoBattleActions 包装（原选择之后）：免费赠行、放行、六衡裁身、收袖
	return r


func _auto_battle_action(a: XActor) -> Array:
	# 异化饕餮 makeAction 包装（Adv:138-142）：原生挂机选技比的是实际 MP（恒 0），饕餮改按手动输入的合法性（canUse 读饥饿储备）
	if XAlienBattle.devours(a):
		var id := int(XHangUpAuto.data(state, "ActSkill").get(a.display_name() + XHangUpAuto.three(turn), 0))
		if id > 2 and a.skills().any(func(x): return int(x.id) == id) and can_use(a, XDB.rec("Skills", id)):
			return [XDB.rec("Skills", id), null]
	var planned := XHangUpAuto.scheduled_skill(state, self, a, turn)
	if not planned.is_empty():
		return [planned, null]
	if XConfig.smart_ai():
		var r := XSmartAI.choose(self, a)
		if r.has("skill"):
			return [r.skill, r.target]
	return [a.attack_skill(), null]  # makeAction：setSkill(attackSkillId)



# ---- 回合（Olivia_BattleSysOTB：行动顺序回合制）----
## 正式版强制使用 OTB（Force Battle System = true）。与 MV 默认回合制不同：
## - 不再「全员先选指令再统一执行」，而是按行动顺序轮到谁、谁当场选指令并立即行动。
## - 每回合开始时同时排好「当前回合」和「下个回合」两条顺序；下一回合直接沿用已排好的顺序。
##   速度 = 敏捷 + 随机(0 ~ 5+敏捷/4 - 1)（Static AGI Calculation = false）；不能行动者速度为无穷大（醒来后排最前）。
## - 技能速度不再参与排序，而是使用后把自己在下个回合的位置前移「速度」格（Action Speed Convert）：
##   攻击速度 -1 → 后移 1 格；防御速度 2000 → 移到最前。物品不移位（只有技能付费时触发）。
## - 增加敏捷增益的技能命中后，目标下个回合前移 1 格（Buff/Debuff AGI Convert；正式版减益判断写错，不移位，照搬）。
## - 追加行动（特性 61）：同一人在顺序中连续出现多次；正式版改为每回合最多 5 次（文件末尾的修复段）。
## - 无法行动（死亡、行动限制）的人从当前回合移除；下个回合若一回合后仍不能动也移除；恢复行动时补回顺序末尾。
## 超过上限的追加行动：原 _actionDMG 已被真气取代（installNativeZhenqiRuntime：首回合超额次数记真气，见 XZhenqi）。

const OTB_MAX_ACTIONS := 5
const AGI_PARAM := 6

var current_order: Array = []   # 本回合尚未行动的顺序（XBattler，可重复）
var next_order: Array = []      # 下个回合的顺序
var _orders_made := false
var _acted := {}                # XBattler -> 本回合已行动次数（_otbTimesActedThisTurn）
var _speed := {}                # XBattler -> 最近一次排序时的速度
var _escape_ratio := -1.0


## 回合开始（YEP startTurn）：回合数 +1、冷却 -1、排顺序。
func start_turn() -> void:
	XGuyu.start_turn(turn + 1)  # 谷雨 startTurn 包装（最外层）：原 startTurn 期间 round＝turnCount＋1
	# Game_Troop.increaseTurn：span 1（回合）的页重新可执行
	var pages: Array = XDB.rec("Troops", troop_id).get("pages", [])
	for i in range(pages.size()):
		if int(pages[i].get("span", 0)) == 1:
			_event_flags.erase(i)
	_cleared.clear()
	XRaven.start_turn()  # 渡鸦 BattleManager.startTurn 包装：清「本回合有敌人倒下」
	XYomiJingliu.start_turn(self)  # 镜流 BattleManager.startTurn 包装：月魄满 3
	XMira.start_turn()  # 米拉 BattleManager.startTurn 包装：清劫火累计
	turn += 1
	# YEP_X_SkillCooldowns：Game_Troop.increaseTurn 时双方冷却/预热各减 1
	for b in actors + enemies:
		b.update_cooldowns()
	# installBossDifficultyRuntime 包在 increaseTurn 外；在单位 onTurnStart／refresh 之前同步。
	for e in enemies:
		e.sync_boss_armor(turn % 2 == 0, _rule())
	for b in actors + enemies:
		XStateEffects.run("turn_start", b, {"random": _rule(), "variables": vars()})  # Custom Turn Start Effect：onTurnStart 内，Unit.refresh 之前
		# krz onTurnStart 标 dirty，Game_Unit.onTurnStart 紧接 refresh：本回合起能力值重新读取
		b.param_mark_dirty()
		b.param_refresh()
	_make_action_orders()
	XYunshang.start_turn(self)  # 云裳 startTurn 包装：resetRound（储行加份、神纹自鸣随机唤醒）
	XAlienBattle.start_turn(self)  # 异化 startTurn 包装：镜骸重新充能
	XGuyu.start_turn(turn)  # 谷雨 startTurn 包装：跑完原 startTurn 设回 turnCount


## 取出下一位行动者；本回合结束时返回 null。
func next_subject() -> XBattler:
	while not current_order.is_empty():
		var b: XBattler = current_order.pop_front()
		if b.is_alive() and (actors.has(b) or enemies.has(b)):
			XYunshang.took(b)  # 云裳 getNextSubject 包装：这次行动的来源（原有／赠行／储行）
			return b
	return null


## 行动者当场决定的行动：敌人按 AI，角色在自动战斗时按自动规则，否则普通攻击。返回 [技能, 目标]。
func decide(b: XBattler) -> Array:
	if b is XEnemy:
		var cat := XCat.dragon_action(self, b)  # 小猫试炼巨龙 makeActions 包装：按回合轮换出招，不掷随机数
		if not cat.is_empty():
			return cat
		var sk := enemy_action(b)
		return [null if sk.is_empty() else sk, null]  # 没有行动：同逃跑失败的放弃（processTurn 没有 currentAction 就 endAction）
	return auto_battle_action(b) if auto else [b.attack_skill(), null]


## 执行一位行动者的一次行动，返回记录。skill 为 null（或 {}）表示放弃本次行动（逃跑失败、敌人没有可用行动）。
func act(u: XBattler, skill, target) -> Array:
	var logs := []
	var before := _movable_snapshot()
	if is_won() or is_lost() or u.is_dead():
		return logs
	# 行动无效（敌人没有行动、或 isValid 假整次跳过）：原版 processTurn 不 startAction／endAction，onAllActionsEnd 在
	# _processTurn 里不 updateStateActionEnd（YEP_BattleEngineCore:4166），行动结束的状态不减回合
	var started := true
	var skipped := not can_move(u)
	if skipped:
		XBlackFlash.break_chain(u)  # 黑闪 processTurn／OTB 包装：不能行动连闪归 0
		logs.append({"type": "skip", "user": u})
	elif skill == null or (skill is Dictionary and skill.is_empty()):
		started = false
	elif int(skill.id) == GUARD_SKILL and not is_item(skill):
		XAlienBattle.start_action(self, u, skill)  # 异化蚀术 startAction 包装：防御也算原有合法行动窗口
		XBlackFlash.begin(u, skill, [])  # 黑闪 startAction 包装：防御也建帧（不 eligible，结束时连闪归 0）
		XSukuna.begin(self, u, skill, [])  # 宿傩 startAction 包装：清上一帧
		XStateEffects.run("action_start", u)  # 防御也走 startAction
		# 防御技能在原版也对自己 Game_Action.apply 一次：initiate／select／deselect／conclude 四段都跑（无伤害段）
		u.param_refresh()  # native useItem refresh precedes guard apply
		var gctx := {"attacker": u, "defender": u, "item": skill}
		XStateEffects.run("initiate", u, gctx)
		XStateEffects.run("select", u, gctx)
		u.guarding = true
		_user_tp_gain(u, skill)  # apply 命中后的 applyItemUserEffect：防御技能 2 的 tpGain 10（参照 battle_gaps guard.*）
		_otb_user_shift(u, skill)
		XStateEffects.run("deselect", u, gctx)
		XStateEffects.run("conclude", u, gctx)
		logs.append({"type": "guard", "user": u})
	else:
		started = u.is_actor() or can_use(u, skill)  # 同 execute 开头的行动无效判断（非强制）
		logs.append_array(execute(u, skill, target))
		XImportedBalance.set_acting(null)
	XAlienBattle.idle_window(self, u)  # O-116：敌人能动却没有有效行动，也算蚀术的原有合法行动窗口
	XGuyu.end_action()  # 谷雨 endAction 包装（原 endAction 之前）：结束行动事件，代命成立就归根
	logs.append_array(XGuyu.take_visuals())  # 谷雨 queueVisual：本次行动里的归根反馈（画面）
	if started and not skipped:
		logs.append_array(XGarou.finish(self, u, skill))  # 饿狼 endAction 包装（原 endAction 之前）：进化、解析、追击、流水回 TP；敌人命中饿狼的进化、解析、反击
		logs.append_array(XSukuna.finish(self, u, skill))  # 宿傩 endAction 包装（原 endAction 之前）：神灶：开、追斩、看破、适应
		XBlackFlash.finish(self, u, skill)  # 黑闪 endAction 包装（宿傩之内）：集中、连闪、觉醒
		logs.append_array(XYomiJingliu.j_finish(self, u, skill))  # 镜流 endAction 包装（黑闪之内、渡鸦之外）：追加段、霜痕／裂隙、月魄、追加行动
		XToji.finish(self, u, skill)  # 甚尔 endAction 包装（原 endAction 之后，镜流在里层）：切换技能换形态
		logs.append_array(XRaven.finish(self, u, skill))  # 渡鸦 endAction 包装（各专属模块最内层，原 endAction 之前）：冥界收割、回响
		logs.append_array(XYunshang.finish(self, u, skill))  # 云裳 endAction 包装（finishAction）：赊账还债、一身两世复演、衣魂计次
	XRaceBattle.finish(self, logs)  # BattleManager.endAction 的种族包装：毒鸡汤、残响、反攻
	XCat.end_action(self, u, skill)  # BattleManager.endAction 的小猫剑圣包装：剑技收尾、防御喵铃
	XAlienBattle.finish(self, logs)  # 异化 endAction 包装（原 endAction 之后）：镜骸反噬
	_acted[u] = int(_acted.get(u, 0)) + 1
	XYomiJingliu.queue_extra(self, u)  # 镜流 queueJingliu（原 endAction 之后）：追加行动插队
	if started:
		XMira.pay_hp(u, skill)  # 米拉 endAction 包装（原 endAction 之前）：禁忌生命代价
		_tick_states(u, 1)
		XMira.liberate(self, u, skill)  # 米拉 endAction 包装（原 endAction 之后）：解放·黑龙
		logs.append_array(mark_views(XGuyu.after_action(self, u, skill)))  # 谷雨 endAction 包装（原 endAction 之后）afterAction：花期里队友用技能后绽放
	_sync_orders(before, true)
	resolve_collapses()
	return logs


## 回合结束（MV onTurnEnd）：解除防御、再生、状态回合 -1；恢复行动的人只补进下个回合。
func end_turn() -> Array:
	var logs := []
	var before := _movable_snapshot()
	_acted.clear()
	XAlienBattle.spread_pest(self)  # 异化疫囊 endTurn 包装（原 endTurn 之前）：传播异常与减益
	XCat.end_turn(self)  # BattleManager.endTurn 的小猫剑圣包装：删过期的识破／剑痕
	logs.append_array(XSukuna.end_round(self))  # 宿傩 endTurn 包装（原 endTurn 之前，在米拉外层）：领域斩击、神灶：开、伤口到期
	XBlackFlash.end_round(self)  # 黑闪 endTurn 包装（宿傩之内、米拉之外）：觉醒到期
	logs.append_array(XMira.end_turn(self))  # 米拉 endTurn 包装（原 endTurn 之前）：修雷德劫火追加
	XRaven.end_turn(self)  # 渡鸦 endTurn 包装（原 endTurn 之前，在米拉之内、宠物捕捉插件之外）：残响、神话形态减一回合
	logs.append_array(XPetCapture.end_turn(self))  # Star_PetSystem 的 endTurn 包装：第 5 回合可捕捉的敌人逃跑
	for b in actors + enemies:
		turn_end_battler(b, logs)
	# BattleManager.refreshAllMembers
	for b in actors + enemies:
		b.param_refresh()
	logs.append_array(XAlienBattle.round_end(self))  # endTurn 的异化包装（在种族包装之内）：蚀能、腐蚀
	logs.append_array(XRaceBattle.round_end(self))  # endTurn 的种族包装：毒鸡汤结算、残响交接
	XYunshang.end_turn(self)  # 云裳 endTurn 包装：六衡裁身回合末清除
	XGuyu.end_round()  # 谷雨 endTurn 包装（原 endTurn 之后）endRound：花期到期收束
	logs.append_array(XGuyu.take_visuals())  # 谷雨 queueVisual：回合末扣血引起的归根反馈（画面）
	_sync_orders(before, false)
	resolve_collapses()
	return logs


## 单个战斗者的 onTurnEnd。krz 前后各标一次 dirty，中间 regenerateAll 已 refresh（活着时）。
func turn_end_battler(b: XBattler, logs: Array) -> void:
	b.runtime_result = XResourceContext.empty_result()  # Game_Battler.onTurnEnd 首句 clearResult（之前去掉的状态这时起可以再附加）
	b.guarding = false
	b.param_mark_dirty()
	if b.is_alive():
		b.param_refresh()
		_regenerate(b, logs)
		_tick_states(b, 2)
	# Custom Regenerate → Custom Turn End（regenerateAll 外层与 onTurnEnd 不看存活，倒下的也跑）
	# 叠毒等 Regenerate 脚本的扣血按状态各弹一次字（regenerateStateEffects 每个状态 clearResult → eval → startDamagePopup）
	# regenerateStateEffects：进去时活着、脚本后倒下就 performCollapse（叠毒脚本弹字后自己也调一次），紧跟这次弹字；同一次倒下只记一条
	var alive := [b.is_alive()]
	var collapse := func() -> void:
		if alive[0] and b.is_dead():
			alive[0] = false
			logs.append({"type": "collapse", "target": b, "views": views([b])})
	var emit := func(entry: Dictionary) -> void:
		entry.views = views([entry.target])
		logs.append(entry)
		collapse.call()
	XStateEffects.run("regenerate", b, {"random": _rule(), "variables": vars(), "emit": emit})
	collapse.call()
	XStateEffects.run("turn_end", b)
	b.decay_shield()  # ShieldSystem 包在 regenerateAll 最外层，倒下的也衰减
	b.param_mark_dirty()
	XMira.turn_end(self, b, logs)  # 米拉 Game_Actor.onTurnEnd 包装（之后）：不灭龙血回 5%
	XGarou.turn_end(b)  # 饿狼 Game_Actor.onTurnEnd 包装（之后）：清本回合受过伤、琦玉模式


## 无界面测试用：跑完一整个回合。commands: actor -> [技能, 目标]（[null, null] 表示放弃）。
func run_turn(commands: Dictionary) -> Array:
	var logs := run_events() if turn == 0 else []
	start_turn()
	var first := true
	while true:
		var u := next_subject()
		logs.append_array(run_events(u if first else null))
		first = false
		if u == null or is_won() or is_lost():
			break
		var cmd: Array = [null, null] if cleared_action(u) else ((commands[u] if commands.has(u) else decide(u)) if u is XActor else decide(u))
		logs.append_array(act(u, cmd[0], cmd[1]))
	if not is_won() and not is_lost():
		logs.append_array(end_turn())
		logs.append_array(run_events(null, true))
	return logs


# ---- 敌群事件（Game_Troop.setupBattleEvent / meetsConditions；YEP_BattleEngineCore + OTB 的强制行动）----
## 正式版在 start/turn/turnEnd 阶段每次 update 都检查：开战（第 0 回合）、每回合开始（OTB startTurn 已取出首位行动者）、
## 每次行动结束后、回合最后一人之后、回合结束（turn_end）。一次检查里依次执行所有满足条件的页（每页执行完再找下一页；
## span 2「瞬间」的页每次检查最多一次，避免条件一直成立时死循环）。
## first_subject：回合开始时已取出的首位行动者；它被强制行动时本回合的普通行动被清掉（见 _cleared / cleared_action）。
## 页内指令由 XBattleEventRunner（共用核心 MVEventCore）执行，没翻译的指令记入 troop_event_skipped。返回已提交的记录。
## 遇到 101 文字时停在游标处：记录最后一条是 {type: "message", msg, token}，is_event_waiting() 为 true，
## 画面显示完调 resume_event(token, 应答) 续上（同 MV 消息忙时 BattleManager 不推进）；等待中不能开始新的检查。
## 与源一致，选页时就提交 span≤1 的 event flag；等待中不重新选页，span 1 只在 start_turn 清除。
func troop_events(first_subject: XBattler = null, turn_end := false) -> Array:
	if is_event_waiting():
		return []
	_check = {"first": first_subject, "turn_end": turn_end, "moment": {}, "guard": 0}
	return _drive_events()


## 画面确认消息后续上游标；token 不对（重复确认、上一场战斗的消息）时什么也不做
func resume_event(token: int, response = null) -> Array:
	if _waiting.is_empty() or int(_waiting.token) != token:
		return []
	var frame: MVEventCore = _waiting.frame
	_waiting = {}
	frame.resume(response)
	return _drive_events()


func is_event_waiting() -> bool:
	return not _waiting.is_empty()


## 等待中的消息 {token, msg}；不在等待时为空
func event_waiting() -> Dictionary:
	return {} if _waiting.is_empty() else {"token": _waiting.token, "msg": _waiting.msg}


## 无界面宿主：检查一次敌群事件，消息由 message_responder 应答（未设置时确认），一直执行到这次检查结束
func run_events(first_subject: XBattler = null, turn_end := false) -> Array:
	var logs := troop_events(first_subject, turn_end)
	while is_event_waiting():
		var w := event_waiting()
		var response = message_responder.call(w.msg) if message_responder.is_valid() else w.msg.get("default", null)
		logs.append_array(resume_event(int(w.token), response))
	return logs


func _drive_events() -> Array:
	var logs := []
	var pages: Array = XDB.rec("Troops", troop_id).get("pages", [])
	while not _check.is_empty():
		if _runner == null: _runner = XBattleCommonEvent.take(self)  # setupBattleEvent：预约的公共事件（技能／物品效果 44）先于敌群页
		if _runner == null:
			if is_won() or is_lost() or int(_check.guard) > pages.size():
				break
			_check.guard = int(_check.guard) + 1
			var found := -1
			for i in range(pages.size()):
				if not _event_flags.has(i) and not _check.moment.has(i) and _page_meets(pages[i], bool(_check.turn_end)):
					found = i
					break
			if found < 0:
				break
			if int(pages[found].get("span", 0)) <= 1:
				_event_flags[found] = true
			else:
				_check.moment[found] = true
			_runner = XBattleEventRunner.new(self, pages[found].get("list", []), _check.first)
			_runner.set_meta("page", found)
		var r := _runner.advance()
		logs.append_array(_runner.take_logs())
		match str(r.kind):
			"message":
				_event_token += 1
				_waiting = {"token": _event_token, "frame": _runner.waiting_frame(), "msg": r.msg}
				logs.append({"type": "message", "msg": r.msg, "token": _event_token})
				return logs
			"forced_action":
				pass
			_:
				for sk in _runner.skipped:
					if _runner.has_meta("common_event"): common_event_skipped.append("%d %s 公共事件%d" % [int(sk.code), str(sk.text), int(_runner.get_meta("common_event"))])
					else: troop_event_skipped.append("%d %s 第%d页" % [int(sk.code), str(sk.text), int(_runner.get_meta("page")) + 1])
				_runner = null
	_runner = null
	_check = {}
	return logs


## 退出战斗、重新开战：游标、等待中的消息全部作废
func _clear_event_cursor() -> void:
	_runner = null
	_check = {}
	_waiting = {}


## $gameTroop.members()[i]（含隐藏成员）
func enemy_at(i: int) -> XEnemy:
	return enemies[i] if i >= 0 and i < enemies.size() else null


## iterateEnemyIndex：-1 为全体成员（含隐藏），否则该序号
func _enemy_slots(i: int) -> Array:
	if i < 0:
		return range(enemies.size())
	return [i] if i < enemies.size() else []


## 敌人变化的记录：稳定 slot、前后读数（画面按记录刷新同一个成员，不再执行规则）
func _enemy_change(kind: String, slot: int, before: Dictionary) -> Dictionary:
	var e: XEnemy = enemies[slot]
	return {"type": "enemy_change", "kind": kind, "slot": slot, "target": e, "before": before, "after": _enemy_reading(e),
		"views": views([e])}


func _enemy_reading(e: XEnemy) -> Dictionary:
	return {"enemy_id": e.enemy_id, "name": e.display_name(), "hidden": e.hidden, "hp": e.hp, "mp": e.mp, "tp": e.tp,
		"states": e.state_ids.duplicate()}


## 334 敌人完全回复（Game_BattlerBase.recoverAll：清状态、HP/MP 回满；TP、buff 不变；隐藏成员也回复，仍隐藏）。
## krz 能力值缓存：回满读的是缓存里的上限——状态 77 使最大 HP ×0.8 后已读过上限时，清掉 77 仍按旧上限回满；336 变身后
## 缓存还没重算时按变身前的上限（玉皇 466 变 538 后 1399 的 334 按 466 的上限回满）。随后的 refresh 才消费此前的 dirty。
func enemy_recover_all(index: int) -> Array:
	var out := []
	for i in _enemy_slots(index):
		var e: XEnemy = enemies[i]
		var before := _enemy_reading(e)
		# Boss recoverAll can re-add armor: keep that nested duration in this battle's rule stream.
		var resources := _operation_resources(e)
		var previous := e.lifecycle_context
		e.lifecycle_context = resources.state_context(e)
		e.recover_all()
		e.lifecycle_context = previous
		_finish_lifecycle_operation(resources, e)
		_refresh_battler(e)
		e.refresh_passive()
		out.append(_enemy_change("recover", i, before))
	return out


## 335 敌人出现（Game_Enemy.appear）：只去掉隐藏标记，HP/MP/TP/状态不变（死亡的出现后仍死亡），再 makeUniqueNames。
## 行动顺序不当场改：冻结源 AB_EnemyBook 盖掉了 OTB 的 appear 入队，出现的成员到下次重建 next 队列才排进（首次行动在下下回合）。
func enemy_appear(index: int) -> Array:
	var out := []
	for i in _enemy_slots(index):
		var e: XEnemy = enemies[i]
		var before := _enemy_reading(e)
		e.hidden = false
		make_unique_names()
		out.append(_enemy_change("appear", i, before))
	return out


## 336 敌人变身（Game_Enemy.transform）：原地换数据身份，HP/MP 按绝对值保留后截到新上限，TP、状态、buff 不变，
## 不重新抽神话、等级，不走开战流程；原名变了就清字母，再 makeUniqueNames。
## 本工程敌人在轮到时才决定行动（decide），变身后轮到时自然按新形态选招，不另生成待行动。
## CodexBossDifficulty 在原变身前重判Boss，原流程后按当前回合同步2651；人数保留开战快照。
## krz 能力值缓存不随变身清空（变身不标 dirty，内部 refresh 只截资源）：读过的格子留旧形态的值，截 HP 也按缓存上限。
func enemy_transform(index: int, enemy_id: int) -> Array:
	var out := []
	var e := enemy_at(index)
	if e == null or XDB.rec("Enemies", enemy_id).is_empty():
		return out
	var before := _enemy_reading(e)
	var old_name := e.original_name()
	e.boss_difficulty_boss = XEnemy.boss_id(enemy_id)
	e.enemy_id = enemy_id
	if e.original_name() != old_name:
		e.letter = ""
		_letters.erase(e)
	e.refresh_passive()
	_refresh_battler(e)
	e.sync_boss_armor(turn > 0 and turn % 2 == 0, _rule())
	make_unique_names()
	out.append(_enemy_change("transform", index, before))
	return out


## Game_Troop.makeUniqueNames：出现着（isAlive）且还没字母的成员按原名（originalName，神话带前缀）依次分配 Ａ Ｂ Ｃ…；
## 同名已分配 2 个以上时才显示字母（plural）
func make_unique_names() -> void:
	const TABLE := "ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ"
	for e in enemies:
		if e.is_alive() and not _letters.has(e):
			var n: String = e.original_name()
			var k := int(_names_count.get(n, 0))
			_letters[e] = TABLE[k % TABLE.length()]
			_names_count[n] = k + 1
	for e in enemies:
		if _letters.has(e) and int(_names_count.get(e.original_name(), 0)) >= 2:
			e.letter = _letters[e]


## 313 [0 固定／1 变量, 角色（0 全队）, 0 附加／1 解除, 状态]（command313 / iterateActorEx：全队是战斗成员）
func _change_actor_state(p: Array) -> void:
	var id := int(p[1]) if int(p[0]) == 0 else int(state.variable(int(p[1])))
	var targets: Array = actors.duplicate() if id == 0 else []
	if id > 0:
		var a := state.actor(id)
		if a != null:
			targets = [a]
	for a in targets:
		if int(p[2]) == 0:
			sequence_add_state(a, int(p[3]))
		elif a.is_state_affected(int(p[3])):
			_state_remove(a, int(p[3]))
		_refresh_battler(a)


func _page_meets(page: Dictionary, turn_end: bool) -> bool:
	var c: Dictionary = page.get("conditions", {})
	if not (c.get("turnEnding", false) or c.get("turnValid", false) or c.get("enemyValid", false) or c.get("actorValid", false) or c.get("switchValid", false)):
		return false
	if c.get("turnEnding", false) and not turn_end:
		return false
	if c.get("turnValid", false):
		var a := int(c.turnA)
		var b := int(c.turnB)
		if b == 0 and turn != a:
			return false
		if b > 0 and (turn < 1 or turn < a or turn % b != a % b):
			return false
	if c.get("enemyValid", false):
		var idx := int(c.enemyIndex)
		if idx >= enemies.size() or enemies[idx].hp_rate() * 100.0 > float(c.enemyHp):
			return false
	if c.get("actorValid", false):
		var actor := state.actor(int(c.actorId))
		if actor == null or actor.hp_rate() * 100.0 > float(c.actorHp):
			return false
	if c.get("switchValid", false) and not state.switch(int(c.switchId)):
		return false
	return true


## 339 [敌我(0 敌人/1 角色), 敌人序号（<0 全体）或角色 ID, 技能, 目标(-2 上次目标、-1 随机、≥0 序号)]：
## 不在阵亡状态的才行动（Game_Interpreter.command339）；Game_Battler.forceAction 不检查能否使用（Game_Action._forcing），
## 行动后 onAllActionsEnd（行动结束的状态回合）；OTB 不计入本回合行动次数。
func _force_action(p: Array, first_subject: XBattler) -> Array:
	var users := []
	if int(p[0]) == 0:
		if int(p[1]) < 0:
			users = enemies.duplicate()
		elif int(p[1]) < enemies.size():
			users = [enemies[int(p[1])]]
	else:
		var a := state.actor(int(p[1]))
		if a != null and actors.has(a):
			users = [a]
	var logs := []
	var skill := XDB.rec("Skills", int(p[2]))
	for u in users:
		if u.is_dead() or skill.is_empty():
			continue
		if u == first_subject:
			_cleared[u] = true
		var before := _movable_snapshot()
		logs.append_array(execute(u, skill, _forced_target(u, skill, int(p[3])), true))
		logs.append_array(XGarou.finish(self, u, skill))
		logs.append_array(XSukuna.finish(self, u, skill, true))
		logs.append_array(XYomiJingliu.j_finish(self, u, skill))
		logs.append_array(XRaven.finish(self, u, skill))
		logs.append_array(XYunshang.finish(self, u, skill))
		XRaceBattle.finish(self, logs)
		XCat.end_action(self, u, skill)
		XAlienBattle.finish(self, logs)
		XMira.pay_hp(u, skill)
		_tick_states(u, 1)
		XMira.liberate(self, u, skill)
		_sync_orders(before, true)
	return logs


## 333 [敌人序号（<0 全体）, 0 附加／1 解除, 状态]（Game_Interpreter.command333 / iterateEnemyIndex）：
## 附加照 Game_Battler.addState（同行动序列 ADD STATE），解除照 removeState。十层守层者（敌群 69）第 1 回合给自己加 44「再次行动」。
func _change_enemy_state(p: Array) -> void:
	var targets: Array = enemies.duplicate() if int(p[0]) < 0 else ([enemies[int(p[0])]] if int(p[0]) < enemies.size() else [])
	for e in targets:
		if int(p[1]) == 0:
			sequence_add_state(e, int(p[2]))
		elif e.is_state_affected(int(p[2])):
			_state_remove(e, int(p[2]))
		# 补的截资源对应 addState／removeState 内部的 refresh，原版在 krz 标 dirty 之前：不能当场消费刚标的 dirty
		var dirty: bool = e.param_dirty
		e.param_dirty = false
		_refresh_battler(e)
		e.param_dirty = dirty


## Game_Action.setTarget 的序号按 smoothTarget（该序号不是活着的就取第一个活着的；对阵亡者的技能按 smoothDeadTarget）；
## -1 交给 targets_for 随机。没出现的隐藏敌人既不算活着也不算阵亡，两边都不选。
func _forced_target(u: XBattler, skill: Dictionary, index: int) -> XBattler:
	if index == -1:
		return null
	if index == -2:
		index = u.last_target_index
	var scope := int(skill.get("scope", 1))
	var foe_side := scope <= 6
	var unit: Array = (enemies if u.is_actor() else actors) if foe_side else (actors if u.is_actor() else enemies)
	var dead_ok := [9, 10].has(scope)
	var fits := func(b: XBattler) -> bool: return b.is_dead() if dead_ok else b.is_alive()
	if index >= 0 and index < unit.size() and fits.call(unit[index]):
		return unit[index]
	var pool := unit.filter(fits)
	return pool[0] if not pool.is_empty() else null


## 回合开始时首位行动者的行动被强制行动清掉：本回合只剩 onAllActionsEnd（照 act 的「放弃行动」处理）。
func cleared_action(b: XBattler) -> bool:
	return _cleared.has(b)


func can_move(b: XBattler) -> bool:
	return b.is_alive() and not _restricted(b)

func _restricted(b: XBattler) -> bool:
	for s in b.states():
		if int(s.restriction) >= 4:
			return true
	return false


## OTB makeActionOrdersOTB：当前回合 = 上回合排好的「下个回合」；再排新的「下个回合」。
## 首回合另排一次当前回合（速度重新随机）。排序稳定，同速时我方在前（JS sort 稳定）。
func _make_action_orders() -> void:
	if _orders_made:
		current_order = next_order
	next_order = _sorted_by_speed(alive(actors) + alive(enemies))
	if not _orders_made:
		current_order = _sorted_by_speed(actors + enemies)
		_action_times_modification(current_order, true)
	_clear_unable()
	_action_times_modification(next_order)
	_orders_made = true
	XRaceBattle.insert_human(self, current_order)  # 人族九九六（makeActionOrders 的 OTB 分支）


func _sorted_by_speed(list: Array) -> Array:
	var keyed := []
	for i in range(list.size()):
		var b: XBattler = list[i]
		var sp := INF
		if can_move(b):
			var a := b.agi
			sp = a + _int(0, maxi(floori(5 + a / 4.0), 1) - 1, "otb_speed")
		_speed[b] = sp
		keyed.append([sp, i, b])
	keyed.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	return keyed.map(func(k): return k[2])


## 追加行动：按 MV makeActionTimes 掷骰，在此人第一次出现的位置连续插入；每回合总数不超过 5。
## 首回合的当前顺序（first_current）里，追加次数超过 4 的部分记作真气溢出（XZhenqi.note_overflow，原 _actionDMG）。
func _action_times_modification(order: Array, first_current := false) -> void:
	for b in actors + enemies:
		if not order.has(b):
			continue
		var existing := order.count(b)
		var max_extra := OTB_MAX_ACTIONS - existing
		if max_extra <= 0:
			continue
		var extra := make_action_times(b) - 1
		if first_current and b is XActor:
			XZhenqi.note_overflow(b, extra)
		var n := mini(extra, max_extra)
		var at := order.find(b)
		for i in range(n):
			order.insert(at, b)


## MV makeActionTimes：每个「追加行动」几率（actionPlusSet，含道法分神的 [1]）各掷一次，成功加 1 次。
func make_action_times(b: XBattler) -> int:
	if XGarou.own(b):  # 饿狼 makeActionTimes 包装：形态行动次数，不掷追加行动
		return XGarou.action_times(b)
	var n := 1
	for p in b.action_plus_set():
		if _float("action_times") < float(p):
			n += 1
	return n + XCat.extra_actions(b)  # 小猫剑圣 makeActionTimes 包装：进阶学了速剑多 1 次


## otbClearActionOrdersOfUnableBattlers
func _clear_unable() -> void:
	var members := actors + enemies
	current_order = current_order.filter(func(b): return members.has(b) and can_move(b))
	next_order = next_order.filter(func(b): return members.has(b) and b.is_alive() and (can_move(b) or _movable_after_turn_end(b)))


## 下个回合是否能动：模拟一次回合结束的状态回合递减（YEP updateStateTurns 会移除到期的回合结束型状态）。
func _movable_after_turn_end(b: XBattler) -> bool:
	if b.is_dead():
		return false
	for id in b.state_ids:
		var st := XDB.rec("States", id)
		if int(st.get("restriction", 0)) < 4:
			continue
		if int(st.get("autoRemovalTiming", 0)) == 2 and int(b.state_turns.get(id, 1)) <= 1:
			continue
		return false
	return true


func _movable_snapshot() -> Dictionary:
	var out := {}
	for b in actors + enemies:
		out[b] = can_move(b)
	return out


## 行动/回合结束后：刚失去行动能力的移出顺序；刚恢复的补回（otbInsertRevivalActionOrders）。
## 回合结束时只补下个回合（正式版 onTurnEnd 临时关闭 Current Turn Wakeup）。
func _sync_orders(before: Dictionary, allow_current: bool) -> void:
	var lost := false
	for b in before:
		var now := can_move(b)
		if before[b] and not now:
			lost = true
		elif not before[b] and now:
			if allow_current and mini(make_action_times(b), OTB_MAX_ACTIONS) > int(_acted.get(b, 0)):
				_insert_orders(b, current_order)
			_insert_orders(b, next_order)
	if lost:
		_clear_unable()


func _insert_orders(b: XBattler, order: Array) -> void:
	if order.has(b):
		return
	var times := maxi(mini(make_action_times(b), OTB_MAX_ACTIONS) - int(_acted.get(b, 0)), 1)
	for i in range(times):
		order.append(b)


## otbNextTurnChange：把 b 在顺序中的每个位置前移 change 格（负数后移），不越过速度无穷大的人。
func _shift(b: XBattler, change: int, current: bool) -> void:
	var order := current_order if current else next_order
	var idx := []
	for i in range(order.size()):
		if order[i] == b:
			idx.append(i)
	if idx.is_empty():
		return
	for i in range(idx.size() - 1, -1, -1):
		order.remove_at(idx[i])
	var minimum := order.size()
	for i in range(order.size()):
		if _speed.get(order[i], 0.0) != INF:
			minimum = i
			break
	for i in idx:
		order.insert(clampi(i - change, minimum, order.size()), b)


## 技能付费时：下个回合位置按技能速度前移（Action Speed Convert）。
func _otb_user_shift(u: XBattler, skill: Dictionary) -> void:
	var change := int(skill.get("speed", 0)) + _note_int(skill, "OTB User Next Turn")
	if change != 0:
		_shift(u, change, false)


## 命中后对目标：OTB Target Current/Next/Follow Turn 备注，及敏捷增益换算的「下个回合 +1」。
func _otb_target_shift(skill: Dictionary, t: XBattler) -> void:
	var cur := _note_int(skill, "OTB Target Current Turn")
	var nxt := _note_int(skill, "OTB Target Next Turn")
	var follow := _note_int(skill, "OTB Target Follow Turn")
	if follow != 0:
		if current_order.has(t):
			cur += follow
		else:
			nxt += follow
	if not str(skill.get("note", "")).contains("<OTB Target Next Turn:"):
		for eff in skill.get("effects", []):
			if int(eff.code) == 31 and int(eff.dataId) == AGI_PARAM:
				nxt += 1
				break
	if cur != 0:
		_shift(t, cur, true)
	if nxt != 0:
		_shift(t, nxt, false)


static func _note_int(rec: Dictionary, tag: String) -> int:
	var m := RegEx.create_from_string("(?i)<" + tag + ":\\s*([+-]\\d+)>").search(str(rec.get("note", "")))
	return int(m.get_string(1)) if m else 0


## Game_Action.numRepeats 的 MV 本体：次数＋普通攻击（isAttack，看此刻的 attackSkillId）时的追加次数，取整
static func attack_repeats(u: XBattler, skill: Dictionary, base: int) -> int:
	return floori(base + u.attack_times_add()) if u.is_attack(skill) else base


## 执行一次行动：消耗、目标、连击、命中、伤害、效果。
func execute(u: XBattler, skill: Dictionary, chosen: XBattler, forcing := false) -> Array:
	var logs := []
	# 行动无效（原版没有退回攻击）：敌人走核心 processTurn，isValid 为假整次跳过（不 startAction、不付费）；
	# 角色在 OTB 下输入完（或不能输入时 makeActions 后）直接 startAction，不看 isValid，照原样执行。参照 attack_query_probe skip 组。
	if not forcing and not u.is_actor() and not can_use(u, skill):
		return logs
	XGuyu.begin(u)  # 谷雨 startAction 包装：清特效标记、开行动事件（众生之劫记各人最大生命）
	XGarou.begin(u, skill)  # 饿狼 startAction 包装：开施放帧（记施放开始时的进化层）
	XRaven.begin(u, skill)  # 渡鸦：新行动的施放帧（原版记在 Game_Action 上）
	XAlienBattle.start_action(self, u, skill)  # 异化蚀术 startAction 包装（最外层）：记上次用的技能、列出要解的封印
	logs.append_array(XYunshang.prepare(self, u, skill))  # 云裳 startAction 包装（prepareAction）：敌人引爆符针、钉影虚弱、余辉、收针
	if u.is_dead():
		return logs  # 被引爆的符针打倒：原版 _subject 清空，整次行动不执行
	skill = change_to(u, skill)  # TorigoyaMZ_SkillChangeTo：startAction 链里在行动开始状态效果之前
	XStateEffects.run("action_start", u)  # Custom Action Start：BattleManager.startAction 之前（强制行动同）
	skill = weapon_unleash(u, skill)  # YEP_WeaponUnleash：行动开始状态效果之后、付费之前
	skill = XAlienBattle.project(u, skill)  # 异化行动道具投影（A.project 换掉 Game_Action.item）：祸祝等，之后各处都读投影
	# 导入角色平衡：禁用角色／禁用号角的 useItem 直接返回（不扣物品、不付费、不进冷却、不前移），行动（含行动序列）对目标无效
	var blocked := XImportedBalance.blocks(u, skill)
	if not blocked and is_item(skill):
		if bool(skill.get("consumable", true)):
			state.gain_item(int(skill.id), -1)
	elif not blocked:
		var c := skill_cost(u, skill)
		# 异化 paySkillCost 包装：缄默先锁生命上限（付不起整次不付 MP／TP），饕餮的 MP 费用从饥饿储备扣
		if XAlienBattle.pay_silence(self, u, skill):
			XYomiJingliu.pay(u, skill)  # 黄泉 paySkillCost 包装：10174 扣 9 层残梦
			XMira.pay(u, skill)  # 米拉禁忌 paySkillCost 包装：登记生命代价
			if XAlienBattle.glutton_mp(u) != null:
				XAlienBattle.pay_glutton(u, c.mp)
			else:
				u.mp -= c.mp
			u.tp -= c.tp
			pay_hp(u, skill)  # YEP_SkillCore paySkillCost：MP／TP 之后扣 HP 费用
		u.pay_cooldown(skill)
		_otb_user_shift(u, skill)
	# YEP_BattleEngineCore useItem：付费后 refresh，消费行动者此前的 dirty，并照 Game_BattlerBase.refresh 把 MP／TP 截回 [0, 上限]
	# （付不起时 MP 4 用 5 的技能记 0，不是 -1；沙僧第六期 P1）。被挡的 useItem 原版直接返回、不 refresh，只刷缓存
	if blocked:
		u.param_refresh()
	else:
		u.refresh_resources()
	logs.append({"type": "action", "user": u, "skill": skill, "views": views()})
	logs.append_array(XCat.start_action(u, skill))  # 小猫试炼 startAction 包装：巨龙蓄息时日志加一行
	if blocked:
		return logs
	if XToji.suppressed(self, u, skill):  # 甚尔天逆鉾封印 applyGlobal 包装：这次主动技能失效（扣一次），整段序列跳过
		return logs
	XImportedBalance.set_acting(u)  # YEP 附加状态记 BattleManager._subject 为来源
	# YEP 行动序列（yepSeq）：运行时 repeats 都已改成 1，段数在序列里；Game_Action.numRepeats＝1＋普通攻击（isAttack：此刻的 attackSkillId）的追加次数，
	# makeTargets 把每个目标按 numRepeats 重复（repeatTargets）。
	if XActionSequence.has_sequence(skill):
		var times := XYunshang.repeats(u, skill, XYomiJingliu.begin_action(u, skill, XRaven.repeats(u, skill, attack_repeats(u, skill, 1))))  # 黄泉 numRepeats 包装（也开始新行动）；渡鸦包装在里层、云裳双针 ×2 在外层
		var list := []
		for t in targets_for(u, skill, chosen):
			for i in range(maxi(1, times)):
				list.append(t)
		XAlienBattle.set_heal_targets(skill, list.size())  # 逆祷治疗按目标数（含重复）分摊
		XRaceBattle.begin(self, u, skill, list, logs)  # 种族祝福行动根（startAction＋makeTargets 包装），endAction 时 finish
		XAlienBattle.begin(self, u, skill)  # 异化行动根（startAction 包装）
		logs.append_array(mark_views(XToji.begin(self, u, skill, list)))  # 甚尔 startAction 包装（黑闪之内）：切换记形态；武器库追击；主技能收成单目标、记段数
		XBlackFlash.begin(u, skill, list, forcing)  # 黑闪 startAction 包装（宿傩之内）：建施放帧
		logs.append_array(XSukuna.begin(self, u, skill, list))  # 宿傩 startAction 包装：领域展开、施放帧
		logs.append_array(XActionSequence.create(self, u, skill, list).run())
		return logs
	var repeats := XYunshang.repeats(u, skill, XYomiJingliu.begin_action(u, skill, XRaven.repeats(u, skill, attack_repeats(u, skill, int(skill.get("repeats", 1))))))  # 黄泉 numRepeats 包装；渡鸦冥羽连葬在里层
	var targets := targets_for(u, skill, chosen)
	XAlienBattle.set_heal_targets(skill, targets.size() * maxi(1, repeats))  # 逆祷治疗按目标数（含重复）分摊
	XRaceBattle.begin(self, u, skill, targets, logs)  # 种族祝福行动根（startAction＋makeTargets 包装），endAction 时 finish
	XAlienBattle.begin(self, u, skill)  # 异化行动根（startAction 包装）
	XBlackFlash.begin(u, skill, targets, forcing)  # 黑闪 startAction 包装（宿傩之内）：建施放帧
	logs.append_array(XSukuna.begin(self, u, skill, targets))  # 宿傩 startAction 包装：领域展开、施放帧
	for t in targets:
		for i in range(maxi(1, repeats)):
			if t.is_dead() and not [9, 10].has(int(skill.scope)):
				break
			if u.is_dead():
				break
			logs.append_array(mark_views(_invoke(u, skill, t)))
	# YEP 默认收尾序列 immortal: targets, false → removeImmortal 逐个 refresh
	for t in targets:
		t.param_refresh()
	return logs


## TorigoyaMZ_SkillChangeTo（BattleManager.startAction 链，在行动开始状态效果与武器解放之前）：技能／物品备注的
## <ChangeTo[id]: 条件> 按备注顺序逐条求值（a＝行动者），第一条为真就换成 id（技能换技能、物品换物品）。
## 不看换出来的能不能用、不递归。条件里的 Math.random() 每求值一次掷一次（rule 流 "changeto"）；
## 求值失败或写法不认识算假（原版 eval 抛错也算假）。参照 skill_change_to_probe。
func change_to(u: XBattler, skill: Dictionary) -> Dictionary:
	for e in change_to_conditions(skill):
		if _change_to_test(u, str(e[1])):
			return XDB.rec("Items" if is_item(skill) else "Skills", int(e[0]))
	return skill


static var _change_to_cache := {}
static var _change_to_exprs := {}
## MV extractMetadata 的 <键:值>：键含 ChangeTo[数字] 的逐条 [id, 条件]，同键后者覆盖、位置不变（对象键序）。
static func change_to_conditions(rec: Dictionary) -> Array:
	var note := str(rec.get("note", ""))
	if not note.contains("ChangeTo["):
		return []
	if _change_to_cache.has(note):
		return _change_to_cache[note]
	var meta := {}
	var key_re := RegEx.create_from_string("ChangeTo\\[(\\d+)]")
	for m in RegEx.create_from_string("<([^<>:]+)(:?)([^>]*)>").search_all(note):
		if key_re.search(m.get_string(1)):
			meta[m.get_string(1)] = m.get_string(3) if m.get_string(2) == ":" else ""
	var out := []
	for k in meta:
		out.append([int(key_re.search(k).get_string(1)), meta[k]])
	_change_to_cache[note] = out
	return out


## 条件求值：只认正式数据用到的写法（Math.random() 比较、a.hp／a.mhp 算式），换成 Godot Expression；别的标识符一律算假。
func _change_to_test(u: XBattler, code: String) -> bool:
	if not _change_to_exprs.has(code):
		var e := code.strip_edges().replace("小于", "<").replace("大于", ">").replace("&lt;", "<").replace("&gt;", ">")
		e = e.replace("Math.random()", "change_to_roll()")
		var ok := true
		for w in RegEx.create_from_string("[A-Za-z_$][A-Za-z_0-9$.]*").search_all(e):
			if not ["change_to_roll", "a.hp", "a.mhp"].has(w.get_string()):
				ok = false
		var ex := Expression.new()
		_change_to_exprs[code] = ex if ok and ex.parse(e, ["a"]) == OK else null
	var expr: Expression = _change_to_exprs[code]
	if expr == null:
		return false
	var v = expr.execute([u], self, false)
	return not expr.has_execute_failed() and bool(v)


## 条件里的 Math.random()：Expression 以本对象为 base 调用
func change_to_roll() -> float:
	return _float("changeto")


## YEP_WeaponUnleash processUnleash（BattleManager.startAction 链）：这一招是此刻的普攻（物品、别的技能不换）时，
## 按 weapon_unleashes() 的顺序逐条试：技能此刻不能用就跳过（不掷），能用才掷一次（rule 流 "unleash"），掷数不大于几率就换成它。
## 「能用」照原版 canUse 含 meetsUsableItemConditions 的 canMove：不能行动（强制行动）时全跳过，原技能照常执行。
## 走 execute 的都算（手动、自动、挂机、智能 AI、强制行动）；反击不走 startAction，不换。参照 weapon_unleash_probe。
func weapon_unleash(u: XBattler, skill: Dictionary) -> Dictionary:
	if is_item(skill) or int(skill.get("id", 0)) != u.attack_skill_id():
		return skill
	for e in u.weapon_unleashes():
		var sk := XDB.rec("Skills", int(e[0]))
		if sk.is_empty() or not can_move(u) or not can_use(u, sk):
			continue
		if _float("unleash") > float(e[1]):
			continue
		return sk
	return skill


## YEP_BattleEngineCore 的 invokeAction：先判魔法反射（魔法、几率 mrf），再判反击（物理、目标能行动、几率 cnt），否则正常生效。
## 反射：行动作用到行动者自己。反击：目标对行动者普通攻击，原行动对该目标无效。
## dsPassiveSkill 必中（角色的 SkillCertainHit 被动）时不会被反射/反击。MV 不区分敌我。
func _invoke(u: XBattler, skill: Dictionary, t: XBattler) -> Array:
	# Game_Battler.setLastTarget（YEP invokeAction）：强制行动「上次目标」用
	u.last_target_index = maxi(0, (actors if t.is_actor() else enemies).find(t))
	var sure := certain_hit(u, skill)
	var mrf := t.mrf if XDamage.is_magical(skill) and not sure else 0.0
	if _float("reflection") < mrf:
		_reflecting = true  # 导入角色平衡：反射回行动者自己的结算照样缩放
		var race_prev = XRaceBattle.derived_begin(self)  # 种族：反射是独立数值来源，不是原行动
		XBlackFlash.nested += 1  # 黑闪 invokeMagicReflection 包装
		var rs := XSukuna.apply(self, u, skill, u) if XSukuna.wraps(u, skill) else [apply(u, skill, u)]  # 宿傩 Game_Action.apply 包装
		XBlackFlash.nested -= 1
		XRaceBattle.derived_end(self, race_prev)
		_reflecting = false
		for r in rs:
			r.reflected = true
		return [{"type": "reflect", "user": u, "target": t}] + rs
	var cnt := t.cnt if XDamage.is_physical(skill) and t.is_alive() and not _restricted(t) and not sure and not XGarou.no_counter(t) else 0.0  # 饿狼 itemCnt 包装：不被原生反击
	if _float("counter") < cnt:
		var race_prev = XRaceBattle.derived_begin(self)  # 种族：反击是独立数值来源，不是原行动
		XBlackFlash.nested += 1  # 黑闪 invokeCounterAttack 包装
		var r := apply(t, XAlienBattle.project(t, t.attack_skill()), u)  # invokeCounterAttack：反击者 setAttack（异化逆祷：反击也读投影）
		XBlackFlash.nested -= 1
		XRaceBattle.derived_end(self, race_prev)
		r.counter = true
		return [{"type": "counter", "user": t, "target": u}, r]
	var tt := substitute_for(skill, t)
	# 黄泉 Game_Action.apply 包装：施集真赤、充残梦、扩散到其余敌人（扩散各次接在主目标之后）
	if XYomiJingliu.wraps(u, skill, tt):
		XYomiJingliu.before_apply(self, u, skill, tt)
		var r := apply(u, skill, tt)
		return [r] + XYomiJingliu.after_apply(self, u, skill, tt, r)
	if XSukuna.wraps(u, skill):
		return XSukuna.apply(self, u, skill, tt)  # 宿傩 Game_Action.apply 包装：捌两段、伤口、神灶蓄力
	if XToji.wraps(u, skill):
		return XToji.apply(self, u, skill, tt)  # 甚尔 Game_Action.apply 包装：计段、天逆鉾封印、万里锁溅射
	var used := (int(skill.get("scope", 0)) in [9, 10]) == tt.is_dead()
	XYomiJingliu.j_before(self, u, skill, tt)  # 镜流 apply 包装（原 apply 之前）：主目标、绽放、放血、记印记
	var r := apply(u, skill, tt)
	XGarou.applied(u, skill, tt, r, used)  # 饿狼 Game_Action.apply 包装：本帧命中与伤害、琦玉模式
	XYomiJingliu.j_applied(u, skill, tt, r, used)  # （j_before 在 apply 之前）  # 镜流 Game_Action.apply 包装：主目标、命中
	XRaven.applied(self, u, skill, tt, r, used)  # 渡鸦 Game_Action.apply 包装：神话形态、鸦啄回 MP、黑暗侵蚀、按目标累计伤害
	return [r] + XToji.reflect(self, tt) + XYunshang.applied(self, u, skill, tt, r, used)  # Game_Action.apply 包装：甚尔术师杀手反弹给出手者；云裳指令、种针、拆神驱散、觉醒引爆


## BattleManager.applySubstitute：目标濒死（活着且 hp < mhp/4）、技能不是必中时，同队出战成员里第一个能掩护的替它挨打
## （第一个就是目标自己时不换）。掩护要能行动：特殊旗标同原版；dsPassiveSkill 的 passiveSUBS 原版倒下也挡，改为要能行动（O-048）。
const SUBSTITUTE_NEEDS_MOVE := true

func substitute_for(skill: Dictionary, t: XBattler) -> XBattler:
	if not (t.is_alive() and t.hp < t.mhp / 4.0) or int(skill.get("hitType", 0)) == 0:
		return t
	for m in (actors if t.is_actor() else enemies):
		if m.is_substitute() and (can_move(m) or not SUBSTITUTE_NEEDS_MOVE and not m.traits_set(62).has(2)):
			return m
	return t


static func certain_hit(u: XBattler, skill: Dictionary) -> bool:
	if not u.is_actor():
		return false
	if XQiyu.certain_skill(u, skill):  # 琦玉 163 的技能必中、不被反击反射（installQiyuDimensionRuntime）
		return true
	if XCat.sure_segment(u):  # 哈基米剑技的必中剑段：itemHit 1、itemEva／itemCnt 0（技能都是物理，魔法反射本来就是 0）
		return true
	var ch: Dictionary = u.passive_cache().get("certainHit", {})
	return bool(ch.get("global", false)) or ch.get("bySkill", {}).has(int(skill.id))


## Game_Action.itemHit 正式版链：dsPassiveSkill 必中被动 → 1；否则 YEP_HitAccuracy 的命中公式
##（参数「Accuracy Formula」，西游为 skillHitRate * (userHitRate - targetEvadeRate) * 1.2；
## userHitRate 物理 user.hit、魔法 user.hit*1.1、必中 10000000；targetEvadeRate 物理 target.eva、魔法 target.mev、必中 0）；
## 最后 installDamageElementRuntime 夹到 0～1。Olivia_AntiPlayerStress 的命中修正在西游关闭（Hit Rate Stacking=false）。
func item_hit(u: XBattler, skill: Dictionary, t: XBattler) -> float:
	if XGuyu.sure(skill):  # 谷雨 itemHit 包装：绽放、终结、治疗必中
		return 1.0
	if certain_hit(u, skill) or XYomiJingliu.sure(u, skill) or XYunshang.sure(u, skill):  # 黄泉技能、云裳伤害技能 itemHit 包装：必中
		return 1.0
	return clampf(_hit_formula("Accuracy Formula", "skillHitRate * (userHitRate - targetEvadeRate)", u, skill, t) + XToji.hit_bonus(u, skill, t), 0.0, 1.0)  # 甚尔 itemHit 包装：天与咒缚影速


## itemCri（各包装由内到外）
func item_cri(u: XBattler, skill: Dictionary, dt: XBattler) -> float:
	if XGuyu.sure(skill):  # 谷雨 itemCri 包装：绽放、终结、治疗不暴击
		return 0.0
	var cri := u.cri * (1.0 - dt.cev * XToji.cev_rate(u, skill)) if bool(skill.damage.critical) else 0.0  # 甚尔 itemCri 包装：五感时目标暴击闪避 ×0.34
	if XCat.weak_segment(u):  # 哈基米必中剑段且学了至圣喵心：itemCri 1
		cri = 1.0
	cri = XYunshang.cri(u, skill, cri)  # 云裳 itemCri 包装：戴织神天梭 +3
	return clampf(cri, 0.0, 1.0)


## itemEva：YEP「Evade Formula」（西游为 0）夹到 0～1。原版闪避已并入命中公式。
func item_eva(u: XBattler, skill: Dictionary, t: XBattler) -> float:
	if XGuyu.sure(skill):  # 谷雨 itemEva 包装：绽放、终结、治疗不闪避
		return 0.0
	if XYunshang.sure(u, skill) or XSukuna.no_evade(u, skill, t) or XToji.sure(u, skill):  # 云裳伤害技能、宿傩斩击打有看破的目标、甚尔五感主技能／武器库 itemEva 包装：不闪避
		return 0.0
	# 镜流黄泉的包装在甚尔里面：必中只把内层闪避压成 0，甚尔照样加目标的影速（审查第 18 期 P3②，参照 toji_eva_probe）
	var base := 0.0 if XYomiJingliu.sure(u, skill) else _hit_formula("Evade Formula", "0", u, skill, t)
	return clampf(base + XToji.eva_bonus(u, skill, t), 0.0, 1.0)  # 甚尔 itemEva 包装：被打时天与咒缚影速


static var _hit_exprs := {}

func _hit_formula(key: String, fallback: String, u: XBattler, skill: Dictionary, t: XBattler) -> float:
	var p := XDB.plugin("YEP_HitAccuracy")
	var kind := "Physical" if XDamage.is_physical(skill) else "Magical" if XDamage.is_magical(skill) else "Certain"
	var user_rate := _eval_hit(str(p.get("User %s Hit" % kind, "user.hit")), u, t, {})
	var target_rate := _eval_hit(str(p.get("Target %s Evade" % kind, "0")), u, t, {})
	return _eval_hit(str(p.get(key, fallback)), u, t, {"skillHitRate": float(skill.get("successRate", 100)) * 0.01,
		"userHitRate": user_rate, "targetEvadeRate": target_rate})


func _eval_hit(code: String, u: XBattler, t: XBattler, extra: Dictionary) -> float:
	var names := ["user", "target", "a", "b", "subject"] + extra.keys()
	var key := code + "|" + ",".join(names)
	if not _hit_exprs.has(key):
		var e := Expression.new()
		_hit_exprs[key] = e if e.parse(code, names) == OK else null
	var expr: Expression = _hit_exprs[key]
	if expr == null:
		return 0.0
	var v = expr.execute([u, t, u, t, u] + extra.values(), null, false)
	return float(v) if not expr.has_execute_failed() and (v is float or v is int) else 0.0


## 兼容现有扩展：_damage_value 覆写的是已结算终值，不能在其返回后再乘一轮状态倍率。
## 新的基础数值夹具／扩展覆写 _calculate_damage，默认路径会统一执行 Confirm→固定减伤→React。
## push：本次是 _apply 的结算（伤害／治疗时挂状态在 Confirm 之后、React 之前，见 _push_states）；逆祷算预算的内层调用不挂
## （原版逆祷包装在 Codex 之外，内层 heal 动作的结果不进结算，参照 pushstate prayer 读码）
func _damage_value(u: XBattler, skill: Dictionary, t: XBattler, critical: bool, push := false) -> float:
	if skill.get("_alienMode", "") == "prayer":
		return XAlienBattle.prayer_heal(self, u, skill, t)  # 异化逆祷 makeDamageValue 包装：按治疗技能算预算再分摊
	var calc := _calculate_damage(u, skill, t, critical)
	var ctx := _state_context(u, skill, t, _damage_record)
	if push:
		var sign := float(calc.value)  # 按 makeDamageValue（CodexDamage.calculate）的正负
		ctx.after_confirm = func(): _push_states(u, skill, t, sign)
	return XToji.record(u, skill, t, calc, XDamage.finish(calc, skill, u, t, true, ctx))  # 甚尔术师杀手：结算后记反弹


func _calculate_damage(u: XBattler, skill: Dictionary, t: XBattler, critical: bool) -> Dictionary:
	var raw := _formula_raw(u, skill, t)
	critical = critical or XBlackFlash.boosted(t)  # 黑闪 modifyCritical 包装：黑闪必暴击
	var options := {"critical": critical, "vars": vars(), "rawValue": raw, "random": _rule(),
		"battleRound": maxi(1, turn), "raceAction": true}  # 自然回合（原版 round()＝max(1, turnCount)），哈基米巨龙减伤钩子要
	var outcome := _formula_outcome
	# 云裳伤害钩子 split：七曜流霞元素、万法同裳两路、千军入袖收袖的各目标（公式对别的目标重新求值；没有就照常算一次）
	var res := XYunshang.calculate_split(skill, u, t, options, func(pt): return _formula_raw(u, skill, pt))
	_formula_outcome = outcome
	return res


## evalDamageFormula(target)：执行公式（实战路径），再经黑闪包装（觉醒 ×1.2、判黑闪）
func _formula_raw(u: XBattler, skill: Dictionary, t: XBattler) -> float:
	_formula_outcome = XFormulaExecution.run_item(skill, u, t, vars(), state.switches if state != null else {}, true, _rule(), _action_resources)
	_formula_outcome.value = XBlackFlash.formula(self, u, skill, t, float(_formula_outcome.value))
	return float(_formula_outcome.value)


func _state_context(u: XBattler, skill: Dictionary, t: XBattler, record := {}) -> Dictionary:
	return {"attacker": u, "defender": t, "item": skill, "resources": _action_resources, "record": record,
		"party_members": actors,
		"variables": vars(), "switches": state.switches if state != null else {}, "random": _rule(),
		"critical": bool(record.get("critical", false)), "value": float(record.get("state_value", 0.0))}


## Game_Action.apply：行动者有道法「破甲」时，期间附加的破甲·真气（2705）用它的倍率（XZhenqi.pojia_actor）
func apply(u: XBattler, skill: Dictionary, t: XBattler) -> Dictionary:
	return XGuyu.apply(self, u, skill, t)  # 谷雨 Game_Action.apply 包装：治疗来源、花期／终结生效（没生效整次不结算）、行动执行标记


func _apply_core(u: XBattler, skill: Dictionary, t: XBattler) -> Dictionary:
	# 异化恶愿 apply 包装（最外层，Adv:180）：第一次先付代价，付不起整次行动对谁都不生效
	if skill.get("_alienMode", "") == "wish" and not XAlienBattle.pay_wish(u, skill):
		return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
			"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}
	# 异化饕餮吞噬 apply 包装（Adv:152，在 YEP 包装之外）：吞目标的登记增益状态或增益，结果清空只记成功
	if XAlienBattle.devour(u, skill, t) != null:
		return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
			"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}
	# 异化百相切换仿形 apply 包装（Affixes:26）：换仿形，不走原 apply
	if XAlienBattle.apply_switch(self, u, skill):
		return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
			"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}
	var black_flash = XBlackFlash.apply_begin(u, skill, t)  # 黑闪 Game_Action.apply 包装（在异化之内）：本次 apply 的命中帧
	var before = XZhenqi.pojia_actor
	XZhenqi.pojia_actor = u if XZhenqi.has_daofa(u, "pojia") else null
	var previous_resources := _action_resources
	_action_resources = _new_lifecycle_resources()
	if previous_resources != null:
		_action_resources.boss_output = previous_resources.boss_output
	_action_resources.boss_output.enter_action(u, t)
	_action_resources.labels = {u: "a"}
	if u != t:
		_action_resources.labels[t] = "b"
	_formula_outcome = {}
	# Game_Action.apply 的 YEP 包装：initiate（行动者）→ select（目标）→ 原 apply → deselect（目标）→ conclude（行动者）；
	# 未命中也四段齐全；导入平衡禁用的行动在更外层直接返回，不跑
	var blocked := XImportedBalance.blocks(u, skill)
	var ctx := _state_context(u, skill, t)
	XAlienBattle.push_action(u, skill)  # 异化 apply 包装的行动帧（在 YEP 包装之外）：归墟拦截附加状态
	if not blocked:
		XStateEffects.run("initiate", u, ctx)
		XStateEffects.run("select", t, ctx)
	var used := not blocked and (int(skill.get("scope", 0)) in [9, 10]) == t.is_dead()  # result.used（testApply：isForDeadFriend() === target.isDead()，复活类打活目标不算）
	var r := _apply(u, skill, t)
	XAlienBattle.after_apply(self, u, skill, t, r)  # 异化 apply 包装：灾疫附加腐蚀
	XAlienBattle.seal_last(self, u, skill, t, used and not r.missed and not r.evaded)  # 异化蚀术 apply 包装：命中后封印
	if not blocked:
		XStateEffects.run("deselect", t, ctx)
		XStateEffects.run("conclude", u, ctx)
	XAlienBattle.pop_action()
	var result := _action_resources.result(t)
	result.missed = r.missed
	result.evaded = r.evaded
	result.critical = r.critical
	r.result = result.duplicate(true)
	r.popupQueue = XResourceContext.popup_queue(result)
	r.effectJournal = _action_resources.journal.duplicate(true)
	r.formulaDiagnostic = _formula_outcome.get("diagnostic", "")
	r.hp = r.hp if ESTABLISH_TRUE_POPUP and r.has("extra") else result.hpDamage
	r.mp = result.mpDamage
	r.tp = result.tpDamage
	r.added = result.addedStates.duplicate()
	r.removed = result.removedStates.duplicate()
	_action_resources.publish()
	_action_resources.boss_output.leave_action()
	_action_resources = previous_resources
	XZhenqi.pojia_actor = before
	XMira.after_apply(u, skill, t, r)  # 米拉 Game_Action.apply 包装：记劫火累计
	XBlackFlash.apply_end(black_flash)
	return r


func _apply(u: XBattler, skill: Dictionary, t: XBattler) -> Dictionary:
	var r := {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
		"hp": 0.0, "mp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false}
	var dmg: Dictionary = skill.damage
	if XImportedBalance.blocks(u, skill):
		return r  # 导入角色平衡：Game_Action.apply 对禁用角色／号角直接返回
	if t.is_dead() and not int(skill.get("scope", 0)) in [9, 10]:
		return r
	var physical := XDamage.is_physical(skill)
	var magical := XDamage.is_magical(skill)
	# 异化嫁祸 itemHit／itemEva／itemCri／makeDamageValue／executeDamage 包装：敌人的生命伤害改按保护者结算，效果仍给 t
	var dt: XBattler = XAlienBattle.damage_target(u, skill, t)
	var hit_rate := item_hit(u, skill, dt)
	var eva_rate := item_eva(u, skill, dt)
	if _float("hit") >= clampf(hit_rate, 0.0, 1.0):
		r.missed = true
		return r
	if _float("evade") < clampf(eva_rate, 0.0, 1.0):
		r.evaded = true
		return r
	var type := int(dmg.type)
	if type > 0:
		r.critical = _float("critical") < item_cri(u, skill, dt)
		_action_resources.result(dt).critical = r.critical
		var previous_record := _damage_record
		_damage_record = r
		var value := _damage_value(XGuyu.owner(u), skill, dt, r.critical, true)  # 谷雨 makeDamageValue 包装：绽放按谷雨算（calcOwner）
		if XBlackFlash.boosted(dt):
			r.critical = true  # 黑闪 modifyCritical：结果记为暴击
			_action_resources.result(dt).critical = true
		_damage_record = previous_record
		r.state_value = value
		_action_resources.result(dt).success = true
		match type:
			1, 3, 5:
				var race_mark := XRaceBattle.before_hp(self, u, skill, dt)
				r.hp = execute_hp_damage(u, dt, value, type == 5, skill)
				var flash := XBlackFlash.take_announced()  # 黑闪 announce：出手者头上弹字、日志一行（画面）
				if not flash.is_empty():
					r.custom_popups = flash
				XRaceBattle.after_hp(self, u, skill, dt, race_mark)
				if dt != t:
					XAlienBattle.sync_relations(self)
			2, 4, 6:
				var mp_before := t.mp
				r.mp = execute_mp_damage(u, t, value, type == 6)
				XRaceBattle.after_mp(self, skill, t, mp_before)
		r.record_hp += floorf(maxf(0.0, float(r.hp)))
		_establish(u, t, r)
	for eff in skill.get("effects", []):
		_effect(u, t, eff, r)
	_otb_target_shift(skill, t)
	_user_tp_gain(u, skill)
	if t.hp <= 0.0 and t.is_dead():
		_die(t)
		r.died = true
	return r


## dsPassiveSkill 被动缓存的 PushState／RecPushState／PushsubState，由 installDamageElementRuntime 在结算时按 makeDamageValue 的正负挂：
## 正 → pushStates 给目标、pushSelfStates 给自己；负 → recPushStates 给目标（不看阵营，同原版）；只认角色行动者，异化虚空的攻击伤害除外；
## 每条按概率掷（Math.random()*100 < p），目标已有就不挂。由 XDamage.finish 在 Confirm／固定减伤之后、React 之前调（参照 pushstate order.1580）。
var _push_sign := 0.0
## O-134（审查 17 P2）：归墟（异化 void）的攻击类伤害（类型 1／2／5／6）不挂 PushState／PushsubState。原版 installDamageElementRuntime
## 本意如此，但排除写成 CodexAlienation.isAttackDamage(this)，_after 回调是直调的、严格模式下 this 为 undefined，恒为假，排除从没生效
## （正式引擎实测照挂，参照 pushstate void.*）。true 照本意排除；false 恢复原版照挂。
static var VOID_PUSH_EXCLUDE := true

func _push_states(u: XBattler, skill: Dictionary, t: XBattler, sign: float) -> void:
	_push_sign = sign
	# 反射回行动者自己时目标就是行动者，照样挂给自己（参照 pushstate invoke.reflect）；反击由反击者结算（invoke.counter）
	var void_attack := XAlienBattle.has(u, "void") and XAlienBattle.attack_damage(skill)
	if not (u is XActor) or sign == 0.0 or (void_attack and VOID_PUSH_EXCLUDE):
		return
	if void_attack:
		XAlienBattle.push_action(u, {})  # 原版照挂时归墟的 addState 包装也不拦（参照 void.1580.apply）：垫一层不是攻击的行动帧
	_push_rows(u, t, sign)
	if void_attack:
		XAlienBattle.pop_action()


func _push_rows(u: XBattler, t: XBattler, sign: float) -> void:
	var cache: Dictionary = u.passive_cache()
	for row in cache.get("recPushStates" if sign < 0.0 else "pushStates", []):
		if _float("push_state") * 100.0 < float(row.probability) and not t.is_state_affected(int(row.stateId)):
			_state_add(t, int(row.stateId))
	if sign > 0.0:
		for row in cache.get("pushSelfStates", []):
			if _float("push_self_state") * 100.0 < float(row.probability) and not u.is_state_affected(int(row.stateId)):
				_state_add(u, int(row.stateId))


## Game_Action.applyItemUserEffect：行动者得 floor(tpGain × tcr)（gainSilentTp）
func _user_tp_gain(u: XBattler, skill: Dictionary) -> void:
	var resources := _operation_resources(u)  # 防御支不经 _apply，没有本次行动的资源上下文
	resources.silent_gain(u, "tp", floorf(float(skill.get("tpGain", 0)) * u.tcr))
	_finish_lifecycle_operation(resources, u)


## installBossDifficultyRuntime的最外层普通伤害包装。倍率为1时也floor，非正值及自身代价原样传入。
static func _boss_output_value(u: XBattler, t: XBattler, value: float) -> float:
	if value > 0.0 and t != u:
		return floorf(value * (u.boss_output_rate() if u is XEnemy else 1.0))
	return value


## Game_Action.executeHpDamage（类型 1／3／5），外层到内层：Boss输出→导入平衡→真气（护法减伤、元婴护体，只在战斗中）→ ShieldSystem 护盾吸收、
## 击穿后减半 → 吸取取 min(目标 HP) → 扣血；正伤害 onDamage 按扣量充 TP；吸取再给行动者回血。返回实际扣量。
func execute_hp_damage(u: XBattler, t: XBattler, value: float, drain: bool, item := {}) -> float:
	value = XGuyu.hp_damage(t, value)  # 护盾账本 executeHpDamage 包装（最外层）：花荫先吸收；谷雨记本回合我方受伤（受伤压力）
	# 异化蚀术 executeHpDamage 包装（Adv:124，最外层）：选定技能及其行动根里的正伤害只扣护盾，生命不变
	if XAlienBattle.erosion_shield(self, u, t, value, item):
		var er := _action_resources.result(t)
		er.hpDamage = 0.0
		er.hpAffected = true
		return 0.0
	# 后安装的异化包装在 Boss 输出外层；settled 栈仍只对内层资源结算生效。
	if value > 0.0 and XAlienBattle.blocks_damage(u, t):
		value = 0.0  # 异化逆祷 A.blocksDamage：对敌人的生命伤害全阻断
	value = XAlienBattle.outgoing(self, u, item, value)
	var alien_before := t.hp
	if not _action_resources.boss_output.is_settled(t, "hp"):
		value = _boss_output_value(u, t, value)
	_action_resources.boss_output.enter_settled(t, "hp")
	value = XYunshang.hp_damage(self, u, t, value)  # 云裳 executeHpDamage 包装：山河作骨分担、赊月偿星记债
	var sukuna_shield := XSukuna.strip_shield(u, t, item)  # 宿傩 executeHpDamage 包装：真伤免护盾
	var sukuna_hp := t.hp
	var out := _execute_hp_damage(u, t, value, drain)
	XBlackFlash.after_hp(u, t, sukuna_hp - t.hp, item)  # 黑闪 executeHpDamage 包装（宿傩之内）：记伤害、黑闪成功
	XSukuna.restore_shield(u, t, sukuna_shield, sukuna_hp)
	XYunshang.after_hp(self, u, t, value, item)  # 云裳 executeHpDamage 包装：记每段命中、山河作骨守势反击
	_action_resources.boss_output.leave_settled()
	XAlienBattle.record(self, u, t, maxf(0.0, alien_before - t.hp))
	return out


func _execute_hp_damage(u: XBattler, t: XBattler, value: float, drain: bool) -> float:
	# Boss输出后按行动者的导入倍率缩放正伤害，之后走真气减伤与护盾
	if value > 0.0 and XImportedBalance.scales(u, t, _reflecting):
		value = XImportedBalance.reduced(value, u)
	if troop_id > 0:
		value = XZhenqi.hp_damage(t, value)
	value = t.absorb_shield(value)
	if drain:
		value = minf(value, t.hp)
	# 种族蛮骨（YEP setHp 里的 CodexRaces.limitHp）只限扣血量；受伤充 TP 仍按原值（onDamage(value)）
	_action_resources.gain(t, "hp", -XRaceBattle.limit_loss(self, t, value))
	if value > 0.0:
		_action_resources.silent_gain(t, "tp", floorf(50.0 * value / maxf(t.mhp, 1.0) * t.tcr))
	if drain:
		_action_resources.gain(u, "hp", value)
	return value


## Game_Action.executeMpDamage（类型 2／4／6）：Boss输出→导入角色平衡缩放正伤害；MP 伤害（非回复）以目标现有 MP 为上限；
## 吸取再给行动者回 MP。返回结果槽的 MP 伤害。
func execute_mp_damage(u: XBattler, t: XBattler, value: float, drain: bool) -> float:
	if not _action_resources.boss_output.is_settled(t, "mp"):
		value = _boss_output_value(u, t, value)
	_action_resources.boss_output.enter_settled(t, "mp")
	var out := _execute_mp_damage(u, t, value, drain)
	_action_resources.boss_output.leave_settled()
	return out


func _execute_mp_damage(u: XBattler, t: XBattler, value: float, drain: bool) -> float:
	if value > 0.0 and XImportedBalance.scales(u, t, _reflecting):
		value = XImportedBalance.reduced(value, u)
	if value >= 0.0:
		value = minf(t.mp, value)
	_action_resources.gain(t, "mp", -value)
	if drain:
		_action_resources.gain(u, "mp", value)
	return value


## YEP_BuffsStatesCore onPostDamageStateEffects 的 Establish（行动者的状态）：executeDamage 之后、使用效果之前。
## user_param_damage（轮回困难 1460/1461）：行动者每个为正的能力值各一次 target.gainHp(-值)（不经伤害计算，可致死）并弹字。
## 记录 r.extra（附加值列表）；原版普通伤害弹字被改写为最后一次附加值（r.popup_hp，见 ESTABLISH_TRUE_POPUP）。
func _establish(u: XBattler, t: XBattler, r: Dictionary) -> void:
	var ctx := _state_context(u, r.skill, t, r)
	ctx.value = XStateEffects.run("respond", t, ctx)
	XStateEffects.run("establish", u, ctx)
	if r.has("extra") and not ESTABLISH_TRUE_POPUP:
		r.popup_hp = r.extra[-1]


func _effect(u: XBattler, t: XBattler, eff: Dictionary, r: Dictionary) -> void:
	if XAlienBattle.skips_effect(u, r.get("skill", {}), eff):
		return  # 异化归墟 applyItemEffect 包装：攻击类伤害不附加状态与增减益
	# Menu effects reuse a nested host domain, or own and publish one operation.
	var previous := _action_resources
	var inherited: XResourceContext = t.lifecycle_context.get("resources")
	if bool(t.lifecycle_context.get("preview", false)) or (inherited != null and inherited.preview):
		return
	var owns_context := previous == null and inherited == null
	if previous == null:
		_action_resources = inherited if inherited != null else _new_lifecycle_resources()
		if owns_context:
			for b in [u, t]:
				_action_resources.seed_result(b, b.runtime_result)
	var resources := _action_resources
	var previous_in_battle := resources.in_battle
	resources.in_battle = random != null
	_apply_effect(u, t, eff, r)
	resources.in_battle = previous_in_battle
	_action_resources = previous
	if owns_context:
		_finish_lifecycle_operation(resources, t)


func _apply_effect(u: XBattler, t: XBattler, eff: Dictionary, r: Dictionary) -> void:
	# Learn-skill payloads can omit value1/value2 (native item1998 does).
	# Native effect43 only reads dataId; don't read unrelated numeric fields.
	if int(eff.code) == 43:
		if t is XActor:
			if XPowerBooks.is_power(int(eff.dataId)) and not XPowerBooks.can_learn(t,int(eff.dataId)):
				return
			if XPassiveBooks.refund_if_full(state,int(eff.dataId),r.get("skill",{})):
				return
			t.learn_skill(int(eff.dataId))
			t.refresh_passive()
		return
	var v1 := float(eff.value1)
	var v2 := float(eff.value2)
	match int(eff.code):
		11:
			var v := (t.mhp * v1 + v2) * t.rec * (u.pha if is_item(r.skill) else 1.0)
			v = floorf(v)
			_action_resources.gain(t, "hp", v)
			r.hp = -v
			r.record_hp = float(r.get("record_hp", 0.0)) + floorf(maxf(0.0, -v))
		12:
			var v := (t.mmp * v1 + v2) * t.rec * (u.pha if is_item(r.skill) else 1.0)
			v = floorf(v)
			_action_resources.gain(t, "mp", v)
			r.mp = -v
		13:
			_action_resources.gain(t, "tp", floorf(v1))
		21:
			var sid := int(eff.dataId)
			var ids := u.attack_states() if sid == 0 else [sid]
			for id in ids:
				# 普攻附加状态（itemEffectAddAttackState）另乘行动者的 attackStatesRate（特性 32 的值＋passiveATKST）；
				# 指定状态（YEP_BattleEngineCore itemEffectAddNormalState）对必中（hitType 0）的技能／物品不乘状态有效度与幸运差
				var chance := v1
				if sid == 0:
					chance *= state_rate(t, id) * u.attack_states_rate(id) * _luk_rate(u, t)
				elif int(r.skill.get("hitType", 0)) != 0:
					chance *= state_rate(t, id) * _luk_rate(u, t)
				if t.traits_set(XBattler.TRAIT_STATE_RESIST).has(id) and not XAlienBattle.forced_state(t, id):
					chance = 0.0
				# MV addState → isStateAddable 要求活着：本次伤害已致死时照常掷随机数，但不再附加（不进 r.added）
				if _float("add_state") < chance and t.is_alive():
					if id == DEATH_STATE:
						t.immortal = false  # itemEffectAddNormalState：附加阵亡前先解除 IMMORTAL
						_state_add(t, DEATH_STATE)
					else:
						_state_add(t, id)
						r.added.append(id)
		22:
			if _float("remove_state") < v1:
				_state_remove(t, int(eff.dataId))
				r.removed.append(int(eff.dataId))
		31:
			sequence_buff(t, int(eff.dataId), true, true, int(v1))
		32:
			add_debuff_effect(u, t, int(eff.dataId), int(v1))
		42:
			# itemEffectGrow：addParam(dataId, floor(value1))（丹药加最大生命等；敌人没有永久加成账本，不做）
			if t is XActor:
				(t as XActor).add_param(int(eff.dataId), floorf(v1))
		33, 34:
			var id := int(eff.dataId)
			if XAlienBattle.blocks_buff_removal(t, id):
				return  # 异化 removeBuff 包装：疫囊、囚厄的减益不可驱散，绝缘拒绝外来驱散
			if (int(eff.code) == 33 and t.buffs[id] > 0) or (int(eff.code) == 34 and t.buffs[id] < 0):
				t.buffs[id] = 0
				t.buff_turns[id] = 0
				_refresh_battler(t)
				t.param_mark_dirty()  # krz removeBuff


## 行动序列 ADD STATE（Game_Battler.addState → isStateAddable：活着、未抵抗（IMMORTAL 期间阵亡视为抵抗）；阵亡状态直接倒下）
func sequence_add_state(t: XBattler, id: int) -> void:
	if XDB.rec("States", id).is_empty() or not t.is_alive():
		return
	if (t.traits_set(XBattler.TRAIT_STATE_RESIST).has(id) and not XAlienBattle.forced_state(t, id)) or (id == DEATH_STATE and t.immortal):
		return
	if id == DEATH_STATE:
		_die(t)
		return
	_state_add(t, id)


## 行动序列 HP/MP/TP ±（gainHp/gainMp/gainTp）：HP 归零即倒下
## 返回弹字值：负 HP 与伤害同走护盾吸收链（Game_Battler.gainHp：先吸收、击穿后减半，ShieldSystem）；
## 弹字角色记原值、敌人记减免后（同 XResourceContext.gain）。
## subject：序列的行动者。导入角色平衡：对序列目标的 HP／MP 减少按行动者倍率缩放（actionHpModify／actionMpModify 的 gainHp／gainMp）。
func sequence_gain(t: XBattler, kind: String, value: float, subject: XBattler = null, resources: XResourceContext = null) -> float:
	if value < 0.0 and kind in ["HP", "MP"] and XImportedBalance.scales(subject, t):
		value = -XImportedBalance.reduced(-value, subject)
	if resources != null:
		# 数值行动序列每个目标先clearResult，再gain；沿已对照的Boss→护盾→setter／refresh链。
		# 每次gain只发布本次操作的槽，避免覆盖两条序列指令之间普通行动的新结果。
		resources.slots.clear()
		resources.seed_result(t, XResourceContext.empty_result())
		resources.gain(t, kind.to_lower(), value)
		resources.publish()
		return -float(resources.result(t)[kind.to_lower() + "Damage"])
	var shown := value
	match kind:
		"HP":
			var applied := value
			if value < 0.0:
				applied = -t.absorb_shield(-value)
				if not t is XActor:
					shown = applied
			applied = XSukuna.heal(t, applied)  # 宿傩 gainHp 包装：带伤口的受治疗减半
			t.hp = clampf(t.hp + applied, 0.0, t.mhp)
		"MP":
			t.mp = clampf(t.mp + value, 0.0, t.mmp)
		"TP":
			t.tp = clampf(t.tp + value, 0.0, t.max_tp())
	_refresh_battler(t)
	if value != 0.0:
		t.param_mark_dirty()  # krz gainHp／gainMp／gainTp
	return shown


## 行动序列 ADD/REMOVE BUFF/DEBUFF（Game_Battler.addBuff/addDebuff：活着才加，等级 ±2 封顶，回合取较大者；remove 只去同方向）
func sequence_buff(t: XBattler, pid: int, add: bool, buff: bool, turns: int, alien_routed := false) -> void:
	if add:
		if t.is_dead():
			return
		if not buff and XToji.knows(t, XToji.TYRANT):
			return  # 甚尔 Game_Actor.addDebuff 包装：暴君挡弱化（角色上最外层，在异化路由之前）
		if not alien_routed and XAlienBattle.route_buff(self, t, pid, buff, turns):
			return  # 异化 addBuff／addDebuff 包装：绝缘拒收外来、舍身增益转给队友、囚厄接收队友减益
		if not buff and XMira.blocks_debuff(t):
			return  # 米拉终焉 addDebuff 包装
		if t.buffs[pid] != t.buff_limit(pid, buff):
			t.buffs[pid] += 1 if buff else -1
		if t.buffs[pid] != 0 and t.buff_turns[pid] < turns:
			t.buff_turns[pid] = turns
	elif XAlienBattle.blocks_buff_removal(t, pid):
		return  # 异化 removeBuff 包装
	elif (buff and t.buffs[pid] > 0) or (not buff and t.buffs[pid] < 0):
		t.buffs[pid] = 0
		t.buff_turns[pid] = 0
	_refresh_battler(t)
	if buff or not add:
		t.param_mark_dirty()  # krz 包了 addBuff／removeBuff，没包 addDebuff


## Game_Action.itemEffectAddDebuff：减益有效度 × 幸运差掷一次，中了才加减益
func add_debuff_effect(u: XBattler, t: XBattler, pid: int, turns: int) -> bool:
	if _float("add_debuff") >= t.debuff_rate(pid) * _luk_rate(u, t):
		return false
	sequence_buff(t, pid, true, false, turns)
	return true


## Game_Action.lukEffectRate：1 + (行动者幸运 − 目标幸运) × 0.001，不低于 0
static func _luk_rate(u: XBattler, t: XBattler) -> float:
	return maxf(1.0 + (u.luk - t.luk) * 0.001, 0.0)


func state_rate(b: XBattler, id: int) -> float:
	if XAlienBattle.forced_state(b, id):
		return 1.0  # 异化疫囊、囚厄 stateRate 包装
	return b.traits_pi(XBattler.TRAIT_STATE_RATE, id)


func _die(b: XBattler) -> void:
	# Resource refresh has already performed death. Never clear permanent states or
	# redraw the death duration when another gain/action observes the same corpse.
	if not b.state_ids.has(DEATH_STATE):
		_state_add(b, DEATH_STATE)


## timing 1 = 行动结束，2 = 回合结束（MV autoRemovalTiming）
func _tick_states(b: XBattler, timing: int) -> void:
	for id in b.state_ids.duplicate():
		var s := XDB.rec("States", id)
		if int(s.get("autoRemovalTiming", 0)) != timing or id == DEATH_STATE:
			continue
		b.state_turns[id] = int(b.state_turns.get(id, 1)) - 1
		if b.state_turns[id] <= 0:
			_state_remove(b, id, true)
	if timing == 2:
		for i in range(8):
			if b.buff_turns[i] > 0:
				b.buff_turns[i] -= 1
				if b.buff_turns[i] == 0:
					b.buffs[i] = 0


func _regenerate(b: XBattler, logs: Array) -> void:
	# krz regenerateHp：floor(mhp × hrg × rec)，含目标的恢复效果率（MP 再生不含）
	var dh := floorf(b.mhp * b.hrg * b.rec)
	# 异化逆祷 regenerateHp 包装：敌人身上来源是逆祷者的负再生不算（hrg 扣掉它们再算）
	var prayer_block := XAlienBattle.prayer_regen_block(b)
	if prayer_block != 0.0:
		dh = floorf(b.mhp * (b.hrg - prayer_block) * b.rec)
	# 导入角色平衡：导入角色附加的状态里负的 HP 再生率（持续伤害）那部分 ×0.01（向下取整），其余照常；
	# 两个值都按原顺序先乘 rec 再 floor，之后才拆出导入部分缩放（installImportedBalanceRuntime.js:496／506）
	var imported := []  # 导入角色附加的状态（来源倍率不为 1）
	for id in b.state_ids:
		var src := XImportedBalance.origin(b, id)
		if src != null and src != b and XImportedBalance.outgoing_rate(src) != 1.0:
			imported.append(id)
	if not imported.is_empty():
		# 原版把这些状态的负 hrg 特性换成 0，再按特性对象原顺序重新求和（不能用 hrg 减去它们：浮点会差，floor 后差 1）
		var states := b.states()
		var hrg := 0.0
		var altered := false
		for o in b.trait_objects():
			var dot_state: bool = imported.has(int(o.get("id", -1))) and states.any(func(x): return is_same(x, o))
			for tr in o.get("traits", []):
				if int(tr.code) != XBattler.TRAIT_XPARAM or int(tr.dataId) != 7:
					continue
				if dot_state and float(tr.value) < 0.0:
					altered = true
				else:
					hrg += float(tr.value)
		if altered:
			var other := floorf(b.mhp * hrg * b.rec)
			dh = other - floorf(maxf(0.0, other - dh) * XImportedBalance.DOT_RATE)
	var dm := floorf(b.mmp * b.mrg)
	var alien_hp := b.hp
	if dh != 0.0:
		var shown := dh
		if dh < 0.0:
			# regenerateHp：先按 maxSlipDamage 夹到 hp−1，再吸收护盾、减半（弹字同 gainHp：角色记夹后原值，敌人记减免后）
			shown = maxf(dh, -maxf(b.hp - 1.0, 0.0))
			dh = -b.absorb_shield(-shown)
			if not b is XActor:
				shown = dh
		dh = XSukuna.heal(b, dh)  # 宿傩 gainHp 包装：带伤口的再生回复减半
		shown = XSukuna.heal(b, shown)
		b.hp = clampf(b.hp + dh, 1.0, b.mhp) if dh < 0.0 else minf(b.mhp, b.hp + dh)
		if shown != 0.0:  # 生命 1 时夹成 0，原版不调 gainHp、不弹字
			logs.append({"type": "regen", "target": b, "hp": -shown, "views": views([b])})
	if b.hp != alien_hp and XAlienBattle.routes_regen(b):
		# 异化 regenerateHp 包装（Adv:108-109）：先照原样再生，再退回、按实际差值走 gainHp（空壳、嫁祸不回，舍身转队友，连命进池）
		var delta := b.hp - alien_hp
		b.hp = alien_hp
		var resources := _operation_resources(b)
		resources.gain(b, "hp", delta)
		_finish_lifecycle_operation(resources, b)
	if dm != 0.0:
		var alien_mp := b.mp
		b.mp = clampf(b.mp + dm, 0.0, b.mmp)
		if b.mp > alien_mp and XAlienBattle.route_hollow_mp(b, b.mp - alien_mp):
			b.mp = alien_mp  # 异化 regenerateMp 包装：空壳的回蓝变护盾
	b.tp = minf(b.max_tp(), b.tp + 100.0 * b.trg)


## MV：逃跑率在战斗开始时算一次（0.5×我方平均敏捷/敌方平均敏捷），每失败一次 +0.1。
## 逃跑失败在 OTB 下只消耗这名角色的本次行动（由画面层调用 act(u, null, null)）。
func try_escape() -> bool:
	XBlackFlash.escape(self)  # 黑闪 processEscape 包装：连闪归 0
	escaped = _float("escape") < _escape_ratio
	if not escaped:
		_escape_ratio += 0.1
	return escaped

func _avg_agi(list: Array) -> float:
	var l := list
	var s := 0.0
	for b in l:
		s += b.agi
	return s / maxf(l.size(), 1.0)


# ---- 奖励（经验、金钱；物品掉落见 _roll_drops）----
## BattleManager.makeRewards（正式版 rpg_managers）：金钱 goldTotal×5、经验 expTotal×8。
## 经验：Game_Enemy.exp 被后装的 EliteEnemy 改写成「数据库经验 × 神话倍率」，Vitsuno 难度的经验／金钱倍率包在里层、被盖掉不生效
## （参照 battle_gaps reward.*：难度 1～13 奖励相同；O-130 开关默认按难度乘，见下）；GT_EquipSuitCore 在 expTotal／goldTotal 外再套套装。
## 金钱：dsPassiveSkill 的 goldTotal 按出战成员的每个 passiveGRUP 依次 rate += v×0.01×rate，floor(Σ gold×rate × 金钱双倍)。
## O-130（Kyo 10-31 定：加回来）：难度表的经验／金钱倍率照 Vitsuno 本来的挂点乘在每只敌人的 exp／gold 上；false＝原版（被 EliteEnemy 盖掉、不生效）
static var o_difficulty_reward := true
func rewards() -> Dictionary:
	var exp := 0
	var gold := 0.0
	var drops := []
	var gold_rate := 1.0
	# GT_EquipSuitCore 用 $gameParty.members()，战斗中即出战成员
	var reward_members := actors
	for a in actors:
		for v in a.passive_values("passiveGRUP"):
			gold_rate += XActor._num(v) * 0.01 * gold_rate  # 原式 rate += v×0.01×rate（与连乘差在末位，会差一档取整）
	var rates := _difficulty_rates() if o_difficulty_reward else [1.0, 1.0]
	for e in enemies:
		if e.hidden:
			continue  # deadMembers：没出现的成员不算
		# O-130：Vitsuno 的挂点是 Game_Enemy.exp／gold（每只敌人 floor(值×倍率)），在 expTotal／goldTotal、套装与 ×8／×5 之前
		exp += floori(e.exp_reward() * float(rates[0]))
		gold += floorf(e.gold_reward() * float(rates[1])) * gold_rate
		drops.append_array(drops_of(e))
	drops.append_array(XMira.abyss_bonus(self))  # 米拉 makeRewards 包装：深渊地图 1/30 黑龙进阶石
	var gold_total := floorf(gold * (2.0 if state.party_ability(4) else 1.0))
	return {"exp": int(XEquipSuits.reward(reward_members, exp, 0)) * 8, "gold": int(XEquipSuits.reward(reward_members, gold_total, 1)) * 5, "drops": drops}


func _difficulty_rates() -> Array:
	return Array(str(XDB.plugin("Vitsuno_Difficulty").get("%d : Drop Rate" % state.difficulty, "1,1,1,1,1")).split(",")).map(func(x): return float(x))


## 敌人的掉落（MOG_TrPopUpBattle 把 makeDropItems 的结果存进 _treasure：倒下动画结束时抽一次，结算沿用同一份）。
## 挂机屏蔽掉落（XdRs，在 MOG 之内）与屏蔽掉落（SiShiTan PingBi，在 MOG 之外）都作用在这份结果上。
func drops_of(e: XEnemy) -> Array:
	if e.zq_trial_loot:
		return []
	var id := stable_id(e)
	if not _treasure.has(id):
		_treasure[id] = XPingbi.filter_drops(state, XHangUp.shield_drops(state, _roll_drops(e)))
	return _treasure[id].duplicate(true)


func drop_snapshot(e: XEnemy) -> Array:
	return _treasure.get(stable_id(e), []).duplicate(true)


func resolve_collapses() -> void:
	for e in enemies:
		if e.is_dead():
			resolve_collapse(e)


func resolve_collapse(e: XEnemy) -> void:
	var candidates := drops_of(e)
	var token := stable_id(e)
	if advance_loot_on_collapse and not _drop_granted.has(token):
		_drop_granted[token] = true
		if not candidates.is_empty():
			drop_lock = true
			gain_drops(candidates)


func _roll_drops(e: XEnemy) -> Array:
	if random == null:
		random = XBattleRandom.create(XRandomStream.hex64(XState._fresh_seed())) # standalone fixture owner; real battles initialize in setup
	var drops := []
	for c in drop_chances(e):
		if random.reward.next_float("extra_drop" if c.extra else "drop", stable_id(e)) < c.chance:
			drops.append({"kind": c.kind, "id": c.id})
	return drops


## 各掉落这一次掉出的概率（参照 battle_drop_probe）：MV makeDropItems 的 Math.random()×分母 < dropItemRate()，
## dropItemRate＝EliteEnemy（双倍掉落 ? 1 : 0.2，×神话倍率）×全队掉率（套装、出战 passiveIRUP 连乘、亡魂汲取 +1），同怪物图鉴
## （XAlienBattle.drop_item_rate）。<Enemy Drops> 的 x% 运行时并进 dropItems（分母 100/x），同一式。
## 难度不影响：Vitsuno_Difficulty 的按序号掉率在原版整段注释掉了。原来这里按难度「Drop Rate」×(1＋出战 passiveIRUP 最大值)×套装算，
## 没有 0.2 底、没有亡魂汲取，难度 2 时约多掉十几倍（悟空 drops1 改）。
func drop_chances(e: XEnemy) -> Array:
	var rate := XAlienBattle.drop_item_rate(state, e)
	var out := []
	var di: Array = e.data().get("dropItems", [])
	for drop: Dictionary in di:
		if int(drop.kind) > 0 and float(drop.denominator) > 0:
			out.append({"kind": int(drop.kind), "id": int(drop.dataId), "chance": rate / float(drop.denominator), "extra": false})
	for extra in _extra_drops(e.data()):
		out.append({"kind": extra.kind, "id": extra.id, "chance": extra.rate * rate, "extra": true})
	return out


## 把掉落放进背包（BattleManager.gainDropItems / SpriteEnemyTrP.gainDropItems）
func gain_drops(drops: Array) -> void:
	for d in drops:
		match int(d.kind):
			1: state.gain_item(d.id, 1)
			2: state.gain_gear("weapon", d.id, 1)
			3: state.gain_gear("armor", d.id, 1)


## YEP_ExtraEnemyDrops：<Enemy Drops> Item/Weapon/Armor x: y% </Enemy Drops>
static func _extra_drops(d: Dictionary) -> Array:
	var out := []
	var m := RegEx.create_from_string("(?is)<Enemy Drops>(.*?)</Enemy Drops>").search(str(d.get("note", "")))
	if m == null:
		return out
	for line in m.get_string(1).split("\n"):
		var lm := RegEx.create_from_string("(?i)(Item|Weapon|Armor)\\s+(\\d+):\\s*([\\d.]+)%").search(line)
		if lm:
			out.append({"kind": {"item": 1, "weapon": 2, "armor": 3}[lm.get_string(1).to_lower()], "id": int(lm.get_string(2)), "rate": float(lm.get_string(3)) / 100.0})
	return out


## 发放奖励，返回升级信息 [{actor, levels}]
func grant(r: Dictionary) -> Array:
	if _rewards_granted:
		return []
	_rewards_granted = true
	var garou_text := XGarou.credit_victory(state, _garou, _garou_boss)  # 饿狼 processVictory 包装：累计突破、神之触媒
	if garou_text != "":
		victory_texts.append(garou_text)
	XZhenqi.on_victory(state, actors, XZhenqi.troop_members(troop_id, enemies, state.difficulty))  # 真气胜利结算（含没出场的隐藏成员）（BattleManager.endBattle(0)；每场一次）
	state.gain_gold(r.gold)
	if not drop_lock:
		gain_drops(r.drops)
	XAlienBattle.grant(self)  # 异化 gainDropItems 包装：异化敌人倒下就发奖励装备
	# MV BattleManager.gainExp：全队（含阵亡与后备）都得经验；后备按 System「后备成员获得经验」（optExtraExp）
	var ups := []
	var bench_rate := 1.0 if bool(XDB.system().get("optExtraExp", false)) else 0.0
	for a in state.members():
		var n: int = a.gain_exp(r.exp, 1.0 if actors.has(a) else bench_rate, _rule())
		if n > 0:
			ups.append({"actor": a, "levels": n})
	# CP_MagicWeapon 包在 gainRewards 之后：法宝经验（$gameTroop.members()：enemies 已含没出场的隐藏成员）
	XMagicWeapon.gain_victory_exp(state.members(), actors, enemies)
	return ups


## result：0 胜、1 逃、2 败，-1 不跑胜逃败效果（测试夹具等）。
## Custom Victory／Escape／Defeat Effect 只对我方（含后备），在原 endBattle 之前；胜利时 processVictory 已先 removeBattleStates。
func end_battle(result := -1) -> void:
	XAlienBattle.restore_gear(self)  # 异化 endBattle 包装（Adv:196，最外层，原 endBattle 之前）：吞器、献器空出的装备栏放回
	XGuyu.end_battle(self, result)  # 谷雨 endBattle 包装（原 endBattle 之前）：清储备与花期、生命夹回，胜利掉谷种金缮石
	for e in enemies:
		e.sync_boss_armor(false, _rule())
	if result == 0:
		for b in state.members():
			for id in b.state_ids.duplicate():
				if bool(XDB.rec("States", id).get("removeAtBattleEnd", false)):
					_state_remove(b, id)
	if result >= 0 and result <= 2:
		XStateEffects.run_unit(["victory", "escape", "defeat"][result], state.members(), {"random": _rule(), "variables": vars()})
	_clear_event_cursor()
	XAlienBattle.end(self, result)  # 异化 endBattle 包装：胜利补发、结算、清锁队
	XZhenqi.on_battle_end()  # 瓶颈之战输了／逃了：未能突破（胜利已在 grant 结算）
	XYomiJingliu.end_battle()  # 黄泉 endBattle 包装：残梦清零
	XSukuna.end_battle(self)  # 宿傩 endBattle 包装：清战斗数据与领域、适应、觉醒状态
	XYunshang.end_battle(self, result)  # 云裳 endBattle 包装：不朽天丝，结清赊账、结束衣魂，清战斗数据、御风、余辉、符针
	XBlackFlash.end_battle(self)  # 黑闪 endBattle 包装
	XToji.end_battle(self)  # 甚尔 endBattle 包装：清形态
	XMira.end_battle(state)  # 米拉 endBattle 包装：删黑龙形态等状态，清代价与劫火
	XGarou.clear_battle()  # 饿狼 endBattle 包装：清进化、解析、琦玉
	XRaven.end_battle(state)  # 渡鸦 endBattle 包装：清神话形态
	# Game_Unit.onBattleEnd 先退出战斗，再对全队（含后备）调用 onBattleEnd。
	# ShieldSystem Scene_Battle.terminate：全队与敌群护盾清零
	for e in enemies:
		e.shield = 0.0
		e.param_cache_end()
	for b in state.members():
		b.runtime_result = XResourceContext.empty_result()  # Game_Battler.onBattleEnd 首句 clearResult，再 removeBattleStates
		b.shield = 0.0
		b.immortal = false
		b.guarding = false
		b.buffs.fill(0)
		b.buff_turns.fill(0)
		# MV Game_Battler.onBattleEnd：clearTp（保留 TP 时不清）
		if not b.is_preserve_tp():
			b.tp = 0.0
		b.end_battle_cooldowns()
		for id in b.state_ids.duplicate():
			if bool(XDB.rec("States", id).get("removeAtBattleEnd", false)):
				_state_remove(b, id)
		b.refresh_passive()
		b.hp = minf(b.hp, b.mhp)
		b.mp = minf(b.mp, b.mmp)
