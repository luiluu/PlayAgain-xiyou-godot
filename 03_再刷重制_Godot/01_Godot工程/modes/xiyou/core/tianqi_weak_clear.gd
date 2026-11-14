class_name XTianqiWeakClear
extends RefCounted
## 【cc·天启篇·未经审查】天启篇全弱者通关资格（天启篇设计总览 v0.2 第二节 3「全弱者通关资格跟本档走，奖励另行标定」，Kyo 11-08；
## 对重制内容影响审查 v0.6 第 245、268 行：原版弱者挑战在天启篇作废，换成「全弱者通关 36 层」）。
## - 判定（默认口径，待 Kyo 确认）：36 层决战（XTianqiLine.run_final）打赢时，这一场出现过的我方角色全是弱者档才记。
##   「出现过」＝开战时的上场 4 人＋助力位、结束时的上场 4 人＋助力位、战斗中每个行动过的我方角色（XBattleLogic 行动开头一行，
##   接住战斗中换人、事件入队这类中途换进来的）。档位读 XTianqiSkills.battle_tier（成长型角色按当前进度，五条悟照天启篇表）。
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

## 本场 36 层决战见过的我方角色号（begin 开始记，finish 收）
static var _seen := {}
static var _tracking := false


static func on(s) -> bool:
	return ENABLED and s is XState and XTianqi.active(s)


static func is_weak(id: int, s: XState) -> bool:
	return XTianqiSkills.battle_tier(id, s) == XTier.WEAK


## 36 层决战开战前（XTianqiLine.run_final）
static func begin(s: XState) -> void:
	_seen = {}
	_tracking = on(s)
	if _tracking:
		_note_party(s)


## XBattleLogic 行动开头：行动的我方角色记下（战斗中换上来的也在这里接住）
static func note_actor(u) -> void:
	if _tracking and u is XActor:
		_seen[int(u.actor_id)] = true


static func _note_party(s: XState) -> void:
	for a in s.battle_members():
		_seen[int(a.actor_id)] = true
	var h := s.helper()
	if h != null:
		_seen[int(h.actor_id)] = true


## 本场到现在算不算全弱者（结束时再并一次当前的上场＋助力位）
static func eligible(s: XState) -> bool:
	if not _tracking or not on(s):
		return false
	_note_party(s)
	return not _seen.is_empty() and _seen.keys().all(func(id): return is_weak(int(id), s))


## 36 层决战结束（r 是战斗结果，0 胜）：全弱者打赢就记本档资格。返回这次新记上没有
static func finish(host, s: XState, r: int) -> bool:
	var ok := r == 0 and eligible(s)
	var members := _seen.keys()
	members.sort()
	_seen = {}
	_tracking = false
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
