class_name XPartySkills
extends RefCounted
## 队伍技能刷新：技能共享（XSkillShare，Star_SkilsShare）、羁绊（Star_JiBanSiklls）、领袖技能（Star_LeadActor）三套共用的入口与记录。
## 照冻结 v0.28（参照 tests/fixtures/party_skills_oracle.json，mv_oracle/party_skills_probe.cjs）：
## - 整队「完成」（Scene_Party.commandFinish，指令窗取消同此）、角色仓库退出（cancelNowScene）：共享（无条件）→ 羁绊（出战成员变了才刷）
##   → 领袖（plugins.js 里共享 114、羁绊 110、领袖 109，后载入的包在外层，所以共享最先）。→ finish()
## - 开战（BattleManager.startBattle）：共享只在出战成员的装备学技能有变化时刷，羁绊在成员变化时刷，领袖不刷。→ battle_start()
## - 读档（Star_LeadActor 的 DataManager.loadGame 包装）：领袖记录空时依次 领袖 → 羁绊（记录为 null 时）→ 共享（记录为空时）。→ loaded()
## - 原版三套的「上次」记录只在内存（同一会话跨存档、跨新游戏都留着）；学会的技能本身随角色存档。
## O-095（可回退，EXACT）：开着时记录随存档（XState.party_skills，存档键 partySkills），读档用本档记录、每次都刷新；
##   遗忘只忘「本系统学会的」（学之前已有就不记），角色本来就会的同一技能不被忘掉。关掉时照原版：内存记录、不分来源遗忘。
## 提示照 codex installV019UsabilityRuntime：逐条「技能共享：X 激活！」不弹，一次刷新只弹一条新激活的（见 XSkillShare）。

## O-095 开关：false 时照原版（内存记录、不分来源遗忘）
static var EXACT := true
## 原版的内存记录（EXACT 关掉时用）：同一 Godot 会话里一直留着
static var _session := {}


## 当前用的记录：{"share": {...}, "bond": {...}, "lead": {...}}
static func records(s: XState) -> Dictionary:
	return s.party_skills if EXACT else _session


## 测试用：清掉内存记录（相当于重开游戏程序）
static func reset_session() -> void:
	_session = {}


## Scene_Party.commandFinish／Star_Scene_ActorWarehouse.cancelNowScene（都在菜单里，提示总显示）
static func finish(s: XState) -> Array:
	var rec := records(s)
	var out := XSkillShare.refresh(s, rec)
	if XBonds.changed(s, rec):
		out.append_array(XBonds.refresh(s, rec))
	out.append_array(XLeadActor.refresh(s, rec))
	_show(out, true)
	return out


## BattleManager.startBattle 之前
static func battle_start(s: XState) -> Array:
	var out := []
	var rec := records(s)
	if XSkillShare.equip_changed(s, rec):
		out.append_array(XSkillShare.refresh(s, rec))
	if XBonds.changed(s, rec):
		out.append_array(XBonds.refresh(s, rec))
	_show(out, false)
	return out


## DataManager.loadGame 成功之后（XState.current 已换成读出的档）。原版只在领袖记录为空时（本会话第一次读档，或从没有过领袖）刷新，
## 羁绊、共享再各看自己的记录；O-095 开着时三套都按本档记录刷新
static func loaded(s: XState) -> Array:
	var out := []
	var rec := records(s)
	if EXACT or XLeadActor.ranks(rec).is_empty():
		out.append_array(XLeadActor.refresh(s, rec))
		if EXACT or XBonds.never(rec):
			out.append_array(XBonds.refresh(s, rec))
		if EXACT or XSkillShare.shared_ids(rec).is_empty():
			out.append_array(XSkillShare.refresh(s, rec))
	_show(out, false)
	return out


static func _show(messages: Array, in_menu: bool) -> void:
	for m in messages:
		XToast.show_text(str(m), in_menu)


static func to_save(v: Dictionary) -> Dictionary:
	return v.duplicate(true)


static func from_save(v) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}
