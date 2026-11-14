class_name XTianqiWeakClear
extends RefCounted
## 【cc·天启篇·未经审查】天启篇全弱者通关资格（天启篇设计总览 v0.2 第二节 3「全弱者通关资格跟本档走，奖励另行标定」，Kyo 11-08；
## 对重制内容影响审查 v0.6 第 245、268 行：原版弱者挑战在天启篇作废，换成「全弱者通关 36 层」）。
## - 判定（Kyo 11-14 定，默认口径）：36 层决战（XTianqiLine.run_final）打赢时，这一场出现过的我方角色全是弱者档才记。
##   「出现过」＝出战栏 5 格（上场＋助力位）里出现过的角色和行动者。出战栏的写入收拢在 XState：整列赋值走 battle_slots 的 setter，
##   单格写入走 set_battle_slot，写入那一刻就记（同一事件里写进又改回也接得住，gpt 复核 P2）；开战前、每回合开头、每次行动开头、
##   结束时再各扫一次出战栏，作兜底。
##   档位读 XTianqiSkills.battle_tier（五条悟照天启篇表），每次见到时按当时档位记，见到一次不是弱者就一直不算。
##   成长型角色（数值表 tiers.growth，现在是三笠 95、饿狼 173）不管练没练一律不算弱者（Kyo 11-14 定）；只管这里，别处档位、弱者光环照旧。
##   名单读不到或为空时失败即关闭：一律不授予（growth_ok，报一次错）。
## - 跟踪绑定存档（_state）：战斗中断没走到 finish 时，下一次 begin 重置；换了存档不记也不能收。
## - 记在存档 flags.tianqi.weak_clear：{本档难度 key: {"line": 线, "members": [角色号]}}，跟本档走（一份存档只有一档难度）。
## - 只认 36 层首通路线（run_final；之后从门再打 36 层也算）；大厅再挑战（XTianqiSummit.rechallenge 36，不记通关）不算。
## - 原版弱者挑战（XWeakChallenge）要 Map157、敌群 469、混沌难度 9，天启篇借的原版难度最高 6、牢妲改难度菜单已删（O-405），走不到。
##   新资格达成时点亮原版成就 142（开关 ACHIEVEMENT）；不写全局 codexWeakFiveClearV2（那是西游档新局学 10357 的奖励）。
## - 奖励不做（另行标定）：达成时调 reward(s, diff)，现在是空的。
## - 玩家看得到：达成时结算多一行「全弱者通关（本档）」；读档界面天启之路一行末尾标「全弱者」。
## 开关（O-待定）：ENABLED＝false 整套不判不记（已记的存档字段留着，界面不显示）。

static var ENABLED := true
## 达成时点亮原版成就 142「弱者挑战」（XAchievement.reward：成就本身带的物品照发）
static var ACHIEVEMENT := true
const ACHIEVEMENT_ID := 142
const FLAG := "weak_clear"

## 本场 36 层决战见过的我方角色：角色号 → 每次见到时都是弱者档（见到一次不是就一直 false）。begin 开始记，finish 收
static var _seen := {}
static var _tracking := false
## 跟踪的是哪份存档（中途回标题、读档没走到 finish 时，换了存档的战斗不记、不能收）
static var _state: XState = null


static func on(s) -> bool:
	return ENABLED and s is XState and XTianqi.active(s)


## 成长型角色名单（skill_rework.json tiers.growth：三笠 95 按锻炼、饿狼 173 按进阶变档）；读不到或不是非空字典返回 {}
static func growth_table() -> Dictionary:
	var t = XTianqiSkills.data().get("tiers", {})
	var g = t.get("growth") if t is Dictionary else null
	return g if g is Dictionary else {}


## 成长型角色：全弱者判定里一律不算弱者（Kyo 11-14）
static func is_growth(id: int) -> bool:
	return growth_table().has(str(id))


static var _growth_warned := false


## 成长型名单读得到且非空；读不到（缺失、为空）就失败即关闭：不授予资格、不点亮成就，报一次错（gpt 复核 P2）
static func growth_ok() -> bool:
	if not growth_table().is_empty():
		return true
	if not _growth_warned:
		_growth_warned = true
		push_error("XTianqiWeakClear: skill_rework.json tiers.growth 读不到或为空，全弱者通关资格不授予")
	return false


static func is_weak(id: int, s: XState) -> bool:
	return not is_growth(id) and XTianqiSkills.battle_tier(id, s) == XTier.WEAK


static func _live(s) -> bool:
	return _tracking and s != null and is_same(s, _state)


## 36 层决战开战前（XTianqiLine.run_final）
static func begin(s: XState) -> void:
	_seen = {}
	_tracking = on(s)
	_state = s if _tracking else null
	note_slots(s)


static func _note(id: int, s: XState) -> void:
	if id > 0:
		_seen[id] = bool(_seen.get(id, true)) and is_weak(id, s)


## 出战栏 5 格（上场＋助力位）里在队的都记下；直接读栏位，不调 battle_members（那个会清超强者，有副作用）。
## 时机：XState.battle_slots 整列赋值（setter）；兜底：开战前、XBattleLogic 每回合开头和每次行动开头、天启篇换人、结束时
static func note_slots(s) -> void:
	if not _live(s):
		return
	for id in s.battle_slots:
		if int(id) > 0 and s.party.has(int(id)):
			_note(int(id), s)


## XState.set_battle_slot 写入一格之后：写进来的在队角色记下
static func note_slot_id(s, id: int) -> void:
	if _live(s) and id > 0 and s.party.has(id):
		_note(id, s)


## XBattleLogic 行动开头：行动的我方角色＋此刻出战栏
static func note_actor(u, s = null) -> void:
	if s == null:
		s = _state
	if not _live(s):
		return
	if u is XActor:
		_note(int(u.actor_id), s)
	note_slots(s)


## 本场到现在算不算全弱者（结束时再并一次当前出战栏，档位按此刻再核一次）
static func eligible(s: XState) -> bool:
	if not _live(s) or not on(s):
		return false
	note_slots(s)
	if not growth_ok():
		return false
	return not _seen.is_empty() and _seen.keys().all(func(id): return bool(_seen[id]) and is_weak(int(id), s))


## 36 层决战结束（r 是战斗结果，0 胜）：全弱者打赢就记本档资格。返回这次新记上没有
static func finish(host, s: XState, r: int) -> bool:
	var ok := r == 0 and eligible(s)
	var members := _seen.keys()
	members.sort()
	_seen = {}
	_tracking = false
	_state = null
	if not ok:
		return false
	var diff := str(s.flags.tianqi.get("difficulty", ""))
	var rec: Dictionary = s.flags.tianqi.get(FLAG, {}) if s.flags.tianqi.get(FLAG) is Dictionary else {}
	var first := not rec.has(diff)
	if first:
		rec[diff] = {"line": XTianqi.line_of(s), "members": members}
		s.flags.tianqi[FLAG] = rec
		reward(s, diff)
		if ACHIEVEMENT:
			XAchievement.reward(ACHIEVEMENT_ID, s)
	if host != null and host.has_method("show_text"):
		await host.show_text("", 0, ["\\c[2]全弱者通关（本档）\\c[0]　%s难度，出战的全是弱者。" % str(XTianqi.difficulty(diff).get("name", diff))])
	return first


## 奖励接口（另行标定，现在不给东西）
static func reward(_s: XState, _diff: String) -> void:
	pass


## 这份存档在某档（默认本档）有没有全弱者通关资格
static func has(s: XState, diff := "") -> bool:
	if not on(s):
		return false
	if diff == "":
		diff = str(s.flags.tianqi.get("difficulty", ""))
	var rec = s.flags.tianqi.get(FLAG)
	return rec is Dictionary and rec.has(diff)


## 读档界面（XSaveScene，存档字典）：本档有资格就返回「　全弱者」
static func save_mark(d) -> String:
	if not ENABLED or not d is Dictionary or not d.get("flags", {}) is Dictionary:
		return ""
	var t = d.flags.get("tianqi")
	if not t is Dictionary or not t.get(FLAG) is Dictionary:
		return ""
	return "　全弱者" if t[FLAG].has(str(t.get("difficulty", ""))) else ""
