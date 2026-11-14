class_name XTianqiGojoTrial
extends RefCounted
## 【cc·未经审查】天启篇五条悟 180 的两次进阶与专属试炼战（设计：私密仓 重制设定/天启篇_五条悟_角色设计_v0.3.md，Kyo 2026-11-14 细案）。
## 数值表 tianqi_data/gojo_trials.json（只读）。只在天启篇（XTianqi.active），西游档里五条悟本来就不出现。
##
## 进阶（XGojo.patch_plugins 写进 Star_ActorAdvanced「Advanced 501／502」）：
## - 一阶「怀玉」25 级、10 万：学超越极限 I、II，进阶·自动反转、进阶·茈贯穿；二阶「新宿」55 级、50 万：学 III、IV，进阶·领域强化、进阶·茈收束。
##   不要材料；金钱不走金钱重构的四阶价（OWN_GOLD，XAdvance.row 问 own_gold）。进阶条件另加「打赢这一阶的试炼」（XAdvance.missing 问 lack）。
## - 学技能：茈 25 级、无量空处 55 级（LEARN_SHIFT，XGojo.patch_classes 问 learn_level）。
## 试炼（进阶界面 XActorAdvancedScene：只差试炼时确认窗写「挑战试炼「怀玉」」，选「是」request 后关界面；mv_script 在
## open_actor_advanced 之后调 run_request 开战）：
## - 单挑：记下队伍、出战栏和五条悟的生命／魔法／TP／状态（存档 flags._gojoTrial，读档还在就还原，after_load），只留五条悟；
##   开战（敌群 troop 借壳，可逃、可输），setup 时整组换成影子。输了／逃了：恢复、不扣钱、可重打；赢了：恢复（RESTORE_ON_WIN）、
##   记 flags.tianqi.gojo_trials、扣钱进阶（XAdvance.advance）。
## - 影子（XEnemy.setup_horseman 的合成记录：不进图鉴、不吃难度倍率；外观 <Sideview Battler> 借甚尔／宿傩战斗图，SHADOW_TINT 压暗紫）：
##   生命＝hp_units × U（U＝职业 L 级本体魔攻 × 等级缩放 × 天启出伤倍率 × 我方结算乘区 settle）；攻击＝本体防御 × atk_def；出招伤害＝本体生命 × 比例 ÷ 承伤倍率
##   ÷ def_nominal（公式模块走 XGojo.formula）；出手按回合表（decide），每回合 actions 次（action_times），不掷随机数。没有任何战斗奖励。
## - 怀玉（甚尔）：单数回合第 1 次天逆鉾（无下限挡不住，命中打掉 1 个印）、双数游云；第 2 次 3 的倍数回合释魂刀、否则游云。
##   五条悟生命第一次掉到 30% 以下（会被打死就留 1 点）领悟反转术式：回满、印补满 3／3（在进阶·自动反转之前）；
##   只有茈能打倒影子（别的伤害最多压到 1 点）。
## - 新宿（宿傩）：第 2 回合起每 5 回合展开伏魔御厨子 3 回合（含当回合），每回合结束必中斩击（不判命中、无下限挡不住）；
##   领域到期的下一回合神灶：开；其余回合 3 的倍数捌、否则解。两边领域都开着＝领域对拼：御厨子斩击不落、无量空处的必中和信息过载失效
##  （给印照常）。
## 战斗挂点：battle_logic setup／decide／make_action_times／rewards／grant 各一行；扣血底层 XResourceContext._set_resource（final_loss）、阵亡兜底 XBattler.add_state（blocks_death）各一行；其余走 XGojo 的现成挂点（begin、finish、end_round、
## infinity_block、overload、sure、after_apply、after_hit、formula）。影子色调在 battler_sprite 一行。
## 开关（O-待定）：ENABLED＝false 回到 v0.2 四阶表、没有试炼；LEARN_SHIFT／OWN_GOLD／RESTORE_ON_WIN／SHADOW_TINT 分项回退。

const PATH := "res://modes/xiyou/tianqi_data/gojo_trials.json"
const META := "xgojo_trial"
const SAVE_KEY := "_gojoTrial"  # s.flags：进行中的试炼（队伍、出战栏、战前状态）
const PASSED_KEY := "gojo_trials"  # s.flags.tianqi：通过的试炼 [1, 2]
const MIGRATE_KEY := "gojo_adv_v"  # s.flags.tianqi：进阶表版本（3＝本稿两阶）
const TABLE_VERSION := 3
const OLD_VERSION := 2  # 关开关反迁移后记的：阶数明确是旧四阶表的

static var ENABLED := true
static var LEARN_SHIFT := true
static var OWN_GOLD := true
static var RESTORE_ON_WIN := true
static var SHADOW_TINT := true

## 两阶进阶：等级、金钱、学会
const TIERS := [
	{"level": 25, "gold": 100000, "learn": [1240, 1241, 10649, 10648]},
	{"level": 55, "gold": 500000, "learn": [1242, 1244, 10650, 10647]},
]
const LEARN_LEVELS := {10640: 25, 10641: 25, 10642: 55}  # 茈收、茈放、无量空处

# 影子的招（XGojo 的号段之后；XGojo.patch_skills 末尾补）
const SPEAR := 10651  # 天逆鉾
const CLOUD := 10652  # 游云
const SOUL := 10653  # 释魂刀
const DISMANTLE := 10654  # 解
const CLEAVE := 10655  # 捌
const SHRINE := 10656  # 领域展开「伏魔御厨子」
const SLASH := 10657  # 御厨子·斩击（领域效果，horseman_strike 直接结算）
const FUGA := 10658  # 神灶：开
const FIRST_SKILL := 10651
const LAST_SKILL := 10658
const ST_SHRINE := 2801  # 伏魔御厨子（宿傩影子身上，显示）
const ST_CLASH := 2802  # 领域对拼（双方身上，显示）
const FIRST_STATE := 2801
const LAST_STATE := 2802

const TEXT_LOST := "试炼未通过，可以再次挑战。"
const TEXT_WIN := "试炼「%s」通过！五条悟完成%s进阶。"
const TEXT_PASSED := "试炼「%s」通过！条件够了就能在进阶界面进阶。"
const TEXT_LACK := "试炼：%s"

static var _data := {}
static var _pending := 0  # 下一场开战换成哪一阶的影子（run_request 设、setup 取走）
static var _request := 0  # 进阶界面要挑战的那一阶（界面设、mv_script 取走）
static var _logic_ref: WeakRef = null


# ---- 数据 ----

static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（天启篇内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiGojoTrial: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiGojoTrial: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


static func trial(tier: int) -> Dictionary:
	var t = data().get("trials", {}).get(str(tier))
	return t if t is Dictionary else {}


static func trial_name(tier: int) -> String:
	return str(trial(tier).get("name", ["", "怀玉", "新宿"][clampi(tier, 0, 2)]))


## 两阶表开着（打开数据表时问；关掉回到 v0.2 四阶表）
static func on() -> bool:
	return ENABLED and XGojo.ENABLED


static func learn_level(id: int, old: int) -> int:
	if not on() or not LEARN_SHIFT:
		return old  # 发行空壳照搬这一句：天启篇没开放时原样
	return int(LEARN_LEVELS.get(id, old))


## XAdvance.row：五条悟的进阶金钱不走金钱重构的四阶价
static func own_gold(actor_id: int) -> bool:
	return on() and OWN_GOLD and actor_id == XGojo.ACTOR


## Star_ActorAdvanced 的两行（XGojo.patch_plugins）
static func advance_rows() -> Array:
	var out := []
	for i in TIERS.size():
		var t: Dictionary = TIERS[i]
		out.append({"AdvancedName": "五条悟%s" % ["一阶", "二阶"][i], "AdvancedActNum": str(i), "AdvancedActNumMaX": str(TIERS.size()),
			"AdvancedActId": str(XGojo.ACTOR), "AdvancedActLevel": str(t.level), "AdvancedGold": str(t.gold), "AdvancedItem": "[]",
			"AdvancedSkiId": JSON.stringify(t.learn), "AdvancedForId": "[]", "AdvancedNote": "\"\""})
	return out


# ---- 存档：通过记录、迁移、进行中的试炼 ----

static func applies(s: XState, a) -> bool:
	return on() and s != null and XGojo.own(a) and XTianqi.active(s)


static func passed(s: XState) -> Array:
	if s == null or not s.flags.get("tianqi") is Dictionary:
		return []
	var v = s.flags.tianqi.get(PASSED_KEY, [])
	return (v as Array).map(func(x): return int(x)) if v is Array else []


static func has_passed(s: XState, tier: int) -> bool:
	return passed(s).has(tier)


static func _mark_passed(s: XState, tier: int) -> void:
	var p := passed(s)
	if not p.has(tier):
		p.append(tier)
		p.sort()
	s.flags.tianqi[PASSED_KEY] = p


## 这一阶还差试炼（0＝不差：不是五条悟、不在天启篇、已满、已经通过）
static func pending_tier(s: XState, a) -> int:
	if not applies(s, a):
		return 0
	var r := XAdvance.rank(s, XGojo.ACTOR)
	if r >= TIERS.size():
		return 0
	return 0 if has_passed(s, r + 1) else r + 1


## XAdvance.missing 末尾：差试炼就多列一项
static func lack(s: XState, a) -> Array:
	var t := pending_tier(s, a)
	return [TEXT_LACK % trial_name(t)] if t > 0 else []


## 进阶界面：缺的只有试炼 → 可以挑战（返回第几阶，否则 0）
static func challengeable(s: XState, a, missing: Array) -> int:
	if not applies(s, a):
		return 0
	var t := pending_tier(s, a)
	return t if t > 0 and missing == lack(s, a) else 0


static func request(tier: int) -> void:
	_request = tier


static func has_request() -> bool:
	return _request > 0


## 这份档的五条悟阶数按两阶表算（标记 MIGRATE_KEY＝3）。新开局（XTianqi.start_new_game）、五条悟入队（XGojo.on_join）、
## 开始和结束试炼都记；记了以后读档不再迁移。只在两阶表开着时记（关着时阶数是旧四阶的）
static func mark_table(s: XState) -> void:
	if on() and s != null and XTianqi.active(s) and s.flags.get("tianqi") is Dictionary:
		s.flags.tianqi[MIGRATE_KEY] = TABLE_VERSION


## 读档（XSave._load_data）：进行中的试炼还原队伍和战前状态；进阶表版本对不上就迁移一次
static func after_load(s: XState) -> void:
	if s == null:
		return
	if s.flags.has(SAVE_KEY):
		_restore(s)
	migrate(s)


## 读档时按标记迁移（幂等：以标记为准，迁移完就记上 3，再读不动）。档型（返修第二轮，协调 11-14 定）：
## - 标记 3：阶数就是两阶表的，不动。
## - 没有标记、也没有任何试炼通过记录＝纯旧四阶表（v0.2）的档，旧规则下正当拿到的：新阶数＝旧阶数 ÷ 2，
##   补上包含的试炼通过记录，这几阶的学会缺哪个补哪个。
## - 有任何试炼通过记录，或是标记 2（关开关反迁移留下的，阶数是旧四阶的）＝碰过两阶表、阶数来历不纯：
##   新阶数＝min(旧阶数 ÷ 2, 从一阶起连续通过的试炼数)；不补通过记录、不补技能，多退少不补；已付的钱不退，以后进阶照常收。
## 已学的技能任何情况都不收回。
## - 两阶表关着（ENABLED＝false，五条悟本身开着）、档里标记是 3：反迁移成旧四阶阶数 ×2、标记记成 2（再开时按上面第三种折半封顶）。
static func migrate(s: XState) -> void:
	if s == null or not XTianqi.active(s) or not s.flags.get("tianqi") is Dictionary:
		return
	var v := int(s.flags.tianqi.get(MIGRATE_KEY, 0))
	if not on():
		if XGojo.ENABLED and v >= TABLE_VERSION:
			s.flags.tianqi[MIGRATE_KEY] = OLD_VERSION
			var r := XAdvance.rank(s, XGojo.ACTOR)
			if r > 0:
				s.actor_advance[XGojo.ACTOR] = mini(r * 2, 4)
		return
	if v >= TABLE_VERSION:
		return
	mark_table(s)  # 先记上：下面迁移完以后再读档不再动
	if not s.actors.has(XGojo.ACTOR):
		return
	var a: XActor = s.actors[XGojo.ACTOR]
	var old := XAdvance.rank(s, XGojo.ACTOR)
	var done := passed(s)
	var pure := v == 0 and done.is_empty()
	var n := mini(old / 2, TIERS.size())
	if not pure:
		var streak := 0
		while streak < TIERS.size() and done.has(streak + 1):
			streak += 1
		n = mini(n, streak)
	if n > 0:
		s.actor_advance[XGojo.ACTOR] = n
	else:
		s.actor_advance.erase(XGojo.ACTOR)
	if pure:
		for i in range(n):
			_mark_passed(s, i + 1)
			for id in TIERS[i].learn:
				if not a.skill_ids.has(int(id)):
					a.learn_skill(int(id))
	for id in LEARN_LEVELS:  # 学技能等级提前：已经到级的补学
		if LEARN_SHIFT and a.level >= int(LEARN_LEVELS[id]) and not a.skill_ids.has(int(id)):
			a.learn_skill(int(id))
	a.refresh_passive()


static func in_trial(s: XState) -> bool:
	return s != null and s.flags.has(SAVE_KEY)


## 换成单挑：记下队伍、出战栏、五条悟的战前状态，只留五条悟（助力位也空）
static func begin(s: XState, tier: int) -> bool:
	if in_trial(s) or not s.actors.has(XGojo.ACTOR):
		return false
	var a: XActor = s.actors[XGojo.ACTOR]
	var turns := {}
	for k in a.state_turns:
		turns[str(k)] = a.state_turns[k]
	s.flags[SAVE_KEY] = {"tier": tier, "actors": s.party.duplicate(), "slots": s.battle_slots.duplicate(),
		"hp": a.hp, "mp": a.mp, "tp": a.tp, "states": a.state_ids.duplicate(), "turns": turns}
	s.party.assign([XGojo.ACTOR])
	s.battle_slots = [XGojo.ACTOR, 0, 0, 0, 0]
	mark_table(s)
	XZhenqi.pending_trial = {}  # 不让一笔待开的瓶颈之战吃掉这场（同小猫试炼）
	return true


## 还原队伍、出战栏；restore_actor 时五条悟的生命、魔法、TP、状态回到战前
static func _restore(s: XState, restore_actor := true) -> void:
	var d: Dictionary = s.flags[SAVE_KEY]
	s.flags.erase(SAVE_KEY)
	s.party.assign((d.get("actors", []) as Array).map(func(v): return int(v)))
	s.battle_slots = (d.get("slots", []) as Array).map(func(v): return int(v))
	if not s.actors.has(XGojo.ACTOR):
		return
	var a: XActor = s.actors[XGojo.ACTOR]
	if not restore_actor and not a.is_dead():
		return
	var want: Array = (d.get("states", []) as Array).map(func(v): return int(v))
	for id in a.state_ids.duplicate():
		if not want.has(int(id)):
			a.remove_state(int(id))
	for id in want:
		if not a.state_ids.has(id):
			a.add_state(id)
	var turns := {}
	for k in d.get("turns", {}):
		turns[int(k)] = d.turns[k]
	a.state_turns = turns
	a.refresh_passive()
	a.hp = clampf(float(d.get("hp", a.mhp)), 1.0, a.mhp)
	a.mp = clampf(float(d.get("mp", 0.0)), 0.0, a.mmp)
	a.tp = clampf(float(d.get("tp", 0.0)), 0.0, a.max_tp())


## 打完：还原；赢了记通过、扣钱进阶。返回要提示的文字
static func finish(s: XState, result: int) -> String:
	if not in_trial(s):
		return ""
	var tier := int(s.flags[SAVE_KEY].get("tier", 0))
	_restore(s, result != 0 or RESTORE_ON_WIN)
	mark_table(s)
	if result != 0 or tier <= 0:
		return TEXT_LOST
	_mark_passed(s, tier)
	var a: XActor = s.actor(XGojo.ACTOR)
	if XAdvance.rank(s, XGojo.ACTOR) != tier - 1 or not XAdvance.missing(s, a).is_empty():
		return TEXT_PASSED % trial_name(tier)  # 界面开战前查过等级金钱，正常走不到；记了通过，之后照常进阶
	XAdvance.advance(s, a)
	return TEXT_WIN % [trial_name(tier), ["", "一阶", "二阶"][clampi(tier, 0, 2)]]


## 进阶界面选了挑战：存检查点、换单挑、开战、还原、提示。返回战斗结果（-1 没开）
static func run_request(host) -> int:
	var tier := _request
	_request = 0
	var s := XState.current
	if tier <= 0 or s == null or not s.actors.has(XGojo.ACTOR):
		return -1
	var a: XActor = s.actors[XGojo.ACTOR]
	if pending_tier(s, a) != tier or challengeable(s, a, XAdvance.missing(s, a)) != tier or not host.has_method("start_battle"):
		return -1
	if host is XMapScene:
		XAutoSave.battle_checkpoint(host, true)  # 开战前检查点（O-221），要在换成单挑之前（同小猫试炼）
	if not begin(s, tier):
		return -1
	if host.has_method("refresh_party_sprites"):
		host.refresh_party_sprites()
	_pending = tier
	var r: int = await host.start_battle(int(data().get("troop", 30)), true, true)
	_pending = 0
	var note := finish(s, r)
	if host.has_method("refresh_party_sprites"):
		host.refresh_party_sprites()
	if host.has_method("refresh_events"):
		host.refresh_events()
	if note != "" and host.has_method("toast"):
		host.toast(note)
	return r


## 测试用：下一场开战换成这一阶的影子（不经界面）
static func prepare(tier: int) -> void:
	_pending = tier


# ---- 战斗：开战 ----

static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if logic != null and logic.has_meta(META) else {}


static func active(logic) -> bool:
	return ENABLED and logic != null and logic.has_meta(META)


static func active_logic():
	var l = _logic_ref.get_ref() if _logic_ref != null else null
	return l if active(l) else null


static func is_shadow(logic, b) -> bool:
	return active(logic) and b != null and is_same(fight(logic).shadow, b)


static func shadow_of(b) -> bool:
	return b is XEnemy and is_shadow(active_logic(), b)


## BattleLogic.setup（XTianqiHorsemen.setup 之后）：prepare 过就把整组换成影子
static func setup(logic, s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	var tier := _pending
	_pending = 0
	var t := trial(tier)
	if tier <= 0 or t.is_empty() or not on() or not XTianqi.active(s):
		return
	var g = logic.actors.filter(func(x): return XGojo.own(x))
	if g.is_empty():
		return
	var a: XActor = g[0]
	var dealt := XTianqiCombat.dealt_parts(a, s)
	var taken := XTianqiCombat.taken_parts(a, s)
	var base := {"mhp": a.param_base_direct(0), "def": a.param_base_direct(3), "mat": a.param_base_direct(4), "mdf": a.param_base_direct(5)}
	var unit := float(base.mat) * XTianqiSkills.level_scale(a) * float(dealt.get("tier", 1.0)) * float(dealt.get("party", 1.0)) * float(data().get("settle", 1.0))
	var rec: Dictionary = XDB.rec("Enemies", int(data().get("shell_enemy", 71))).duplicate(true)
	rec.name = str(t.foe)
	rec.params = [roundf(unit * float(t.hp_units)), 1000.0, roundf(float(base.def) * float(t.atk_def)), 0.0,
		roundf(float(base.mdf) * float(t.atk_def)), roundf(float(base.mat) * float(t.mdf_mat)), roundf(float(a.agi) * float(t.agi_rate)), 100.0]
	rec.actions = []
	rec.note = "NoElite\n<Sideview Battler: %s>\n<Sideview Show Shadow>" % str(t.sv)
	rec.meta = {"Sideview Battler": str(t.sv), "Sideview Show Shadow": true}
	rec.traits = []
	rec.dropItems = []
	rec.exp = 0
	rec.gold = 0
	var e := XEnemy.new()
	e.setup_horseman(int(data().get("shell_enemy", 71)), rec, true)
	e.set_meta("x", 420.0)
	e.set_meta("y", 380.0)
	e.set_meta("shadow_tint", data().get("tint", [0.55, 0.5, 0.8]))
	logic.enemies.clear()
	logic.enemies.append(e)
	var dom: Dictionary = t.get("domain", {})
	logic.set_meta(META, {"tier": tier, "shadow": e, "gojo": a, "base": base, "taken": maxf(0.01, float(taken.get("mult", 1.0))),
		"unit": unit, "awakened": false, "held": false, "round": 0, "nth": 0, "domain": 0, "next_domain": int(dom.get("first", 2)),
		"fuga": false, "clash": false, "queue": []})
	_logic_ref = weakref(logic)
	var open := "伏黑甚尔的影子：「……来收钱了。」" if tier == 1 else "两面宿傩的影子：「让我见识一下吧，现代最强。」"
	logic.turn_start_logs.append(_text("试炼「%s」：%s" % [trial_name(tier), str(t.foe)]))
	logic.turn_start_logs.append(_text(open))


static func end(logic) -> void:
	if logic != null and logic.has_meta(META):
		logic.remove_meta(META)
	_logic_ref = null


static func _text(text: String) -> Dictionary:
	return {"type": "battle_text", "text": text}


static func _say(logic, text: String) -> void:
	fight(logic).queue.append(_text(text))


static func take_logs(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


# ---- 战斗：影子出手 ----

## BattleLogic.make_action_times：影子每回合固定次数（不掷追加行动）；不是影子返回 0
static func action_times(logic, b) -> int:
	if not is_shadow(logic, b):
		return 0
	return maxi(1, int(trial(int(fight(logic).tier)).get("actions", 1)))


## BattleLogic.decide：影子按回合表出招 [技能, 目标]；不是影子返回 []
static func decide(logic, b) -> Array:
	if not is_shadow(logic, b):
		return []
	var f := fight(logic)
	var n := maxi(1, int(logic.turn))
	if int(f.round) != n:
		f.round = n
		f.nth = 0
	f.nth = int(f.nth) + 1
	var target = f.gojo if f.gojo.is_alive() else null
	if target == null:
		return [null, null]
	var id := 0
	if int(f.tier) == 1:
		if int(f.nth) == 1:
			id = SPEAR if n % 2 == 1 else CLOUD
		else:
			id = SOUL if n % 3 == 0 else CLOUD
	else:
		var dom: Dictionary = trial(2).get("domain", {})
		if int(f.domain) <= 0 and n >= int(f.next_domain):
			id = SHRINE
			f.next_domain = n + int(dom.get("every", 5))
		elif bool(f.fuga):
			id = FUGA
			f.fuga = false
		else:
			id = CLEAVE if n % 3 == 0 else DISMANTLE
	var sk := XDB.rec("Skills", id)
	return [sk, b if id == SHRINE else target]


## 影子招式的伤害（XGojo.formula 分到这里）：本体生命 × 比例 ÷ 承伤倍率 ÷ def_nominal
static func formula(_a, _b, item: Dictionary) -> float:
	var logic = active_logic()
	if logic == null:
		return 0.0
	var f := fight(logic)
	var key: String = {SPEAR: "spear", CLOUD: "cloud", SOUL: "soul", DISMANTLE: "dismantle", CLEAVE: "cleave", FUGA: "fuga", SLASH: "slash"}.get(int(item.get("id", 0)), "")
	var ratio := float(trial(int(f.tier)).get("ratio", {}).get(key, 0.0))
	return float(f.base.mhp) * ratio / float(f.taken) / maxf(0.05, float(data().get("def_nominal", 0.75)))


static func owns_skill(id: int) -> bool:
	return id >= FIRST_SKILL and id <= LAST_SKILL


## XGojo.begin（行动开始，影子也调）：宿傩影子展开伏魔御厨子
static func begin_action(logic, u, skill: Dictionary) -> Array:
	if not is_shadow(logic, u) or int(skill.get("id", 0)) != SHRINE:
		return []
	var f := fight(logic)
	f.domain = int(trial(2).get("domain", {}).get("turns", 3))
	logic._state_add(u, ST_SHRINE)
	var logs := [_text("两面宿傩的影子：「领域展开——伏魔御厨子。」")]
	logs.append_array(_sync_clash(logic))
	return logs


## 无量空处展开时（XGojo.begin）：对拼开始
static func gojo_domain(logic) -> Array:
	return _sync_clash(logic) if active(logic) else []


## 两边领域都开着＝领域对拼（双方挂「领域对拼」，开始时报一句）
static func _sync_clash(logic) -> Array:
	var f := fight(logic)
	var now := int(f.domain) > 0 and XGojo.active_domain(f.gojo)
	var logs := []
	if now and not bool(f.clash):
		logs.append(_text("领域对拼！双方领域的必中效果互相抵消。"))
	f.clash = now
	for b in [f.shadow, f.gojo]:
		if now and b.is_alive() and not b.state_ids.has(ST_CLASH):
			logic._state_add(b, ST_CLASH)
		elif not now and b.state_ids.has(ST_CLASH):
			logic._state_remove(b, ST_CLASH)
	return logs


## 领域对拼中：无量空处的必中、信息过载失效（XGojo.sure／overload 问）
static func clashing(logic = null) -> bool:
	if logic == null:
		logic = active_logic()
	return active(logic) and bool(fight(logic).clash)


## XGojo.end_round（无量空处计时之前）：伏魔御厨子的必中斩击、到期
static func end_round(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var logs: Array = take_logs(logic)
	if int(f.tier) != 2 or int(f.domain) <= 0 or not f.shadow.is_alive():
		return logs
	logs.append_array(_sync_clash(logic))
	if bool(f.clash):
		logs.append(_text("无量空处与伏魔御厨子互相抵消，斩击没有落下。"))
	elif f.gojo.is_alive():
		var sk := XDB.rec("Skills", SLASH)
		logs.append(_text("伏魔御厨子的斩击落下了！"))
		logs.append(logic.horseman_strike(f.shadow, f.gojo, sk, floorf(formula(f.shadow, f.gojo, sk) * float(data().get("def_nominal", 0.75))), false))
		logs.append_array(take_logs(logic))
	f.domain = int(f.domain) - 1
	if int(f.domain) <= 0:
		f.domain = 0
		f.fuga = true
		if f.shadow.state_ids.has(ST_SHRINE):
			logic._state_remove(f.shadow, ST_SHRINE)
		logs.append(_text("伏魔御厨子消散了。"))
		f.clash = false
		for b in [f.shadow, f.gojo]:
			if b.state_ids.has(ST_CLASH):
				logic._state_remove(b, ST_CLASH)
	return logs


## 回合末无量空处到期后（XGojo.end_round 末尾）：对拼跟着结束
static func after_round(logic) -> void:
	if active(logic) and int(fight(logic).tier) == 2:
		_sync_clash(logic)


# ---- 战斗：挂钩 ----

## XGojo.infinity_block：天逆鉾破术式，无下限挡不住
static func pierces_infinity(logic, skill: Dictionary) -> bool:
	return active(logic) and int(skill.get("id", 0)) == SPEAR


## XGojo.after_apply：天逆鉾命中打掉 1 个印（多的那种，一样多打苍印）
static func after_apply(logic, u, skill: Dictionary, t, r: Dictionary) -> void:
	if not is_shadow(logic, u) or int(skill.get("id", 0)) != SPEAR or not XGojo.own(t) or bool(r.get("missed", false)) or bool(r.get("evaded", false)):
		return
	var m := XGojo.marks(t)
	if m[0] + m[1] <= 0:
		return
	if m[0] >= m[1]:
		XGojo.add_marks(logic, t, -1, 0)
		_say(logic, "天逆鉾强制解除了术式：苍印 −1。")
	else:
		XGojo.add_marks(logic, t, 0, -1)
		_say(logic, "天逆鉾强制解除了术式：赫印 −1。")


## 茈「收」「放」正在结算（XGojo.cast：五条悟的行动开始时记、结束时清；别人的行动开始也清）
static func purple_casting() -> bool:
	return int(XGojo.cast.get("skill", 0)) in [XGojo.PURPLE_IN, XGojo.PURPLE_OUT]


## XResourceContext._set_resource（gainHp、setHp 两条路最后都到这里：技能伤害、持续伤害、模块直接扣血；在各种倍率、遗物增伤、
## Boss 输出、护盾账本和原生护盾吸收之后，真写生命之前，只截落到生命上的那部分）：怀玉里五条悟觉醒前这一下会打死他就留 1 点（记下待领悟）；甚尔影子不是茈打的最多压到 1 点。返回实际要扣的量。
## live＝false（伤害预览）只算不记。
static func final_loss(b, loss: float, live := true) -> float:
	if loss <= 0.0:
		return loss
	var logic = active_logic()
	if logic == null:
		return loss
	var f := fight(logic)
	if int(f.tier) != 1:
		return loss
	if is_same(b, f.gojo) and not bool(f.awakened) and loss >= float(b.hp):
		return maxf(0.0, float(b.hp) - 1.0)
	if is_same(b, f.shadow) and not purple_casting() and loss >= float(b.hp) - 1.0:
		if live:
			_held(logic)
		return maxf(0.0, float(b.hp) - 1.0)
	return loss


## XBattler.add_state(1) 兜底：不经 _gain 直接写生命再判阵亡的路（种族伤害、七印行动外扣血、反弹、即死、异化词条临终等）。
## 怀玉里觉醒前的五条悟、不是茈打的甚尔影子：生命改 1、不加阵亡（同谷雨代命的写法）。返回 true＝拦下了。
static func blocks_death(b) -> bool:
	var logic = active_logic()
	if logic == null:
		return false
	var f := fight(logic)
	if int(f.tier) != 1:
		return false
	if is_same(b, f.gojo) and not bool(f.awakened):
		b.hp = maxf(1.0, float(b.hp))
		return true
	if is_same(b, f.shadow) and not purple_casting():
		b.hp = maxf(1.0, float(b.hp))
		_held(logic)
		return true
	return false


static func _held(logic) -> void:
	var f := fight(logic)
	if not bool(f.held):
		f.held = true
		_say(logic, "伏黑甚尔的影子还站着——只有虚式「茈」才能打倒他。")


## 怀玉：五条悟第一次掉到 30% 以下领悟反转术式（挨打后 XGojo.after_hit；持续伤害等别的路在下一个行动开始／结束时补）
static func after_hit(logic, t) -> void:
	if active(logic) and is_same(t, fight(logic).gojo):
		check_awaken(logic)


static func check_awaken(logic) -> void:
	if not active(logic):
		return
	var f := fight(logic)
	var t = f.gojo
	if int(f.tier) != 1 or bool(f.awakened) or not t.is_alive():
		return
	if float(t.hp) >= float(t.mhp) * float(trial(1).get("awaken_below", 0.3)):
		return
	f.awakened = true
	logic.gain_hp(t, float(t.mhp))
	XGojo.add_marks(logic, t, XGojo.MARK_CAP, XGojo.MARK_CAP)
	_say(logic, "五条悟：「……原来如此，是这种感觉啊。」")
	_say(logic, "五条悟：「天上天下，唯我独尊。」")
	_say(logic, "五条悟领悟了反转术式！生命回满，苍印、赫印补满。")


## 影子倒下（XGojo.finish 收尾时看）：台词
static func defeat_line(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	if f.shadow.is_alive() or bool(f.get("said_down", false)):
		return []
	f.said_down = true
	return [_text("伏黑甚尔的影子：「……真是输给你了。」" if int(f.tier) == 1 else "两面宿傩的影子：「……真是愉快啊，五条悟。」")]


## BattleLogic.rewards／grant：试炼没有任何战斗奖励
static func no_rewards(logic) -> bool:
	return active(logic)


## battler_sprite：影子压暗紫色调（没有返回白色）
static func tint(b) -> Color:
	if not SHADOW_TINT or not b is XEnemy or not (b as XEnemy).has_meta("shadow_tint"):
		return Color.WHITE  # 发行空壳：特例表给白色（按类型空值是透明，会把敌人画没）
	var c: Array = (b as XEnemy).get_meta("shadow_tint")
	return Color(float(c[0]), float(c[1]), float(c[2])) if c.size() >= 3 else Color.WHITE


# ---- 数据表：影子的招与状态（XGojo.patch_skills／patch_states 末尾调） ----

static func patch_skills(t: Array) -> void:
	if not on():
		return
	for id in range(FIRST_SKILL, LAST_SKILL + 1):
		if not XGojo._free(t, id, "技能"):
			return
	# 名字、借图标和动画的原技能（甚尔、宿傩）、范围（1 敌单体、11 自己）、伤害类型（0 无、1 伤害）、说明
	var defs := {
		SPEAR: ["天逆鉾", 10219, 1, 1, "强制解除术式：无下限挡不住；命中打掉1个印"],
		CLOUD: ["游云", 10216, 1, 1, "三节棍连打"],
		SOUL: ["释魂刀", 10218, 1, 1, "斩向灵魂的一刀"],
		DISMANTLE: ["解", 10229, 1, 1, "无形的斩击"],
		CLEAVE: ["捌", 10230, 1, 1, "按对象的强度调整的斩击"],
		SHRINE: ["领域展开「伏魔御厨子」", 10231, 11, 0, "展开3回合：每回合结束对五条悟必中斩击"],
		SLASH: ["御厨子·斩击", 10237, 1, 1, "领域的必中斩击"],
		FUGA: ["神灶：开", 10233, 1, 1, "领域消散后的烈焰之矢"],
	}
	for id in defs:
		var d: Array = defs[id]
		var src: Dictionary = t[d[1]] if d[1] < t.size() and t[d[1]] is Dictionary else {}
		var r: Dictionary = (t[XGojo.TEMPLATE_SKILL] as Dictionary).duplicate(true)
		r.id = id
		r._gojo = true
		r.name = d[0]
		r.iconIndex = int(src.get("iconIndex", r.get("iconIndex", 0)))
		r.animationId = int(src.get("animationId", r.get("animationId", 0)))
		r.hitType = 0
		r.scope = d[2]
		r.tpCost = 0
		r.mpCost = 0
		r.tpGain = 0
		r.stypeId = 1
		r.effects = []
		r.description = d[4]
		r.note = "<StateNote>%s</StateNote>" % d[4]
		r.meta = XTianqiSkills.parse_meta(r.note)
		r.damage.type = d[3]
		r.damage.elementId = 0
		r.damage.critical = false
		r.damage.variance = 0
		r.damage.erase("formulaIssue")
		r.damage.formula = "XGojo(a,b,%d)" % id  # 伤害类型 0 的不算；算的走 XGojo.formula → formula
		r.damage.formulaGd = r.damage.formula
		r.damage.formulaProgram = {"version": 1, "status": "module", "module": "gojo"}
		t[id] = r


static func patch_states(t: Array) -> void:
	if not on():
		return
	for id in range(FIRST_STATE, LAST_STATE + 1):
		if not XGojo._free(t, id, "状态"):
			return
	var defs := {ST_SHRINE: ["伏魔御厨子", "领域展开中：每回合结束对五条悟必中斩击。", 10231], ST_CLASH: ["领域对拼", "双方领域的必中效果互相抵消。", 0]}
	for id in defs:
		var d: Array = defs[id]
		var r: Dictionary = (t[2640] as Dictionary).duplicate(true)  # 同 XGojo：宿傩「看破·一」，没有特性、战斗结束去掉的显示状态
		r.id = id
		r._gojo = true
		r.name = d[0]
		r.iconIndex = XGojo.icon(10)
		r.note = "<BuffType:祝福>\n<StateNote>%s</StateNote>" % d[1]
		r.meta = XTianqiSkills.parse_meta(r.note)
		t[id] = r
