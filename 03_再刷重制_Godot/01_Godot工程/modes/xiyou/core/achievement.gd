class_name XAchievement
extends RefCounted
## 成就（Star_AchievementSystem＋Star_AchievementShowPic；142 由 installWeakChallengeRuntime、143 由 installKyoAchievementRuntime 注册）。
## 参照：mv_oracle/achievement_probe（generated/oracle/achievements.json）。
## - 定义：插件参数 Achievement 1～200（JSON），类型表 AchievementTypeList；物品清单 AchievementItemList N {AcItem, AcId}。
##   冻结 v0.28 的 124 条全都没有物品／武器／防具奖励与脚本奖励，「获得称号…」只是 AcEvalRewardText 说明文字。
## - 记录：全局 ConfigManager.SAchievementS（XConfig.achievements：ID→true、"<ID>Time"→首次完成时间「2026年1月2日 3:4:5」，不补零）
##   与本局 $gameParty.SAchievementS（XState.achievements）。
## - GetAcReward(ID)：本局已有就什么都不做；否则记全局（时间只在全局第一次记）、记本局、弹窗、发奖励、执行脚本奖励。
##   所以别的存档已得的成就在新存档再达成一次会再弹窗、补记本局。
## - 得到物品（Game_Party.gainItem）：物品在某个清单里且全局还没有该成就时 GetAcReward。全局已有、本局没有时不补记（原版如此）。
## - 界面里的「已获得」只看全局；左下角计数要全局和本局都有。
## 优化 O-076（可回退，见 00_设计/优化登记.md）：
## - GAIN_ONLY：原版失去物品（gainItem 负数）也触发；改为只在得到时触发。
## - BEFORE_REDIRECT：原版在 CodexEconomy 改记之后判定，魂灯 184～187 一律改记成 188，108～111 正常游戏拿不到；改为改记前的物品也判定。
## - SAVE_NOW：原版不写配置（要等设置等页面关闭时 ConfigManager.save），中途退出游戏就丢；改为达成即写。

const GAIN_ONLY := true
const BEFORE_REDIRECT := true
const SAVE_NOW := true
const PLUGIN := "Star_AchievementSystem"
## installKyoAchievementRuntime：测试模式授权后才能首次获得（重制没有测试模式，故只有全局已得时才照常记）
const KYO_ID := 143
const EXTRA := {
	142: {"AcName": "本质高手", "AcType": "光辉事迹", "AcIconId": 240201, "AcTriggerT": "以五名弱者战胜混沌难度的最终守层者·鸿蒙老祖",
		"AcShowText": "以最终战出战阵容判定；阵亡队员计入，替补不计。"},
	143: {"AcName": "kyo专属", "AcType": "光辉事迹", "AcIconId": 240202, "AcTriggerT": "", "AcShowText": ""}}

static var _defs := {}
static var _ids: Array = []
static var _types: Array = []
static var _item_lists: Array = []
## 测试用：固定完成时间（空＝系统时间）
static var time_override := ""
## 弹窗出现过的成就 ID（测试核对用）
static var shown: Array = []


static func _ensure() -> void:
	if not _ids.is_empty():
		return
	var p := XDB.plugin(PLUGIN)
	var t = _json(p.get("AchievementTypeList"))
	_types = t if t is Array else []
	for i in range(1, 201):
		var raw = _json(p.get("Achievement %d" % i))
		if raw is Dictionary:
			_defs[i] = _def(i, raw)
		var lst = _json(p.get("AchievementItemList %d" % i))
		if lst is Dictionary:
			var items = _json(lst.get("AcItem"))
			_item_lists.append({"acId": int(lst.get("AcId", 0)), "items": (items if items is Array else []).map(func(v): return int(v))})
	for id in EXTRA:
		_defs[id] = _def(id, EXTRA[id])
	_ids = _defs.keys()
	_ids.sort()


## 插件参数里的 JSON 文字（空或缺省为 null）
static func _json(v) -> Variant:
	var t := str(v) if v != null else ""
	return JSON.parse_string(t) if t.strip_edges() != "" else null


static func _def(id: int, raw: Dictionary) -> Dictionary:
	var ids := func(key: String) -> Array:
		var v = raw.get(key, "[]")
		var a = _json(v) if v is String else v
		return (a if a is Array else []).map(func(x): return int(x)).filter(func(x): return x > 0)
	return {"id": id, "name": str(raw.get("AcName", "")), "type": str(raw.get("AcType", "")), "icon": int(str(raw.get("AcIconId", "0"))),
		"trigger": str(raw.get("AcTriggerT", "")), "items": ids.call("AcItemReward"), "weapons": ids.call("AcWeaponReward"),
		"armors": ids.call("AcArmorReward"), "eval": str(raw.get("AcEvalReward", "")), "evalText": str(raw.get("AcEvalRewardText", "")),
		"show": str(raw.get("AcShowText", ""))}


static func ids() -> Array:
	_ensure()
	return _ids


static func def(id: int) -> Dictionary:
	_ensure()
	return _defs.get(id, {})


static func types() -> Array:
	_ensure()
	return _types


static func item_lists() -> Array:
	_ensure()
	return _item_lists


## 界面某类型的成就（按 ID 顺序）
static func of_type(type: String) -> Array:
	return ids().filter(func(id): return _defs[id].type == type)


static func global_has(id: int) -> bool:
	return XConfig.achievements().get(str(id)) == true


static func global_time(id: int) -> String:
	var t = XConfig.achievements().get("%dTime" % id)
	return str(t) if t != null and str(t) != "" else ""


static func party_has(s: XState, id: int) -> bool:
	return s != null and s.achievements.get(str(id)) == true


## Window_AchievementSystemNumOc：[全局和本局都有的条数, 定义总数]
static func count(s: XState) -> Array:
	return [ids().filter(func(id): return global_has(id) and party_has(s, id)).size(), ids().size()]


static func now_text() -> String:
	if time_override != "":
		return time_override
	var t := Time.get_datetime_dict_from_system()
	return "%d年%d月%d日 %d:%d:%d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]


## Star.AchievementSystem.GetAcReward
static func reward(id: int, s: XState = null) -> void:
	if s == null:
		s = XState.current
	if s == null or party_has(s, id):
		return
	if id == KYO_ID and not global_has(id):
		return
	var g := XConfig.achievements()
	g[str(id)] = true
	if not g.has("%dTime" % id) or str(g["%dTime" % id]) == "":
		g["%dTime" % id] = now_text()
	s.achievements[str(id)] = true
	if SAVE_NOW:
		XConfig.save_achievements()
	var d := def(id)
	if d.is_empty():
		return
	shown.append(id)
	XAchievementPopup.show_for(d)
	for item in d.items:
		s.gain_item(int(item), 1)
	for w in d.weapons:
		s.gain_gear("weapon", int(w), 1)
	for a in d.armors:
		s.gain_gear("armor", int(a), 1)


## Game_Party.gainItem 的物品清单判定（id：实际进背包的物品；before：改记前的物品，BEFORE_REDIRECT 用）
static func on_item_gain(s: XState, id: int, amount: int, before := 0) -> void:
	if GAIN_ONLY and amount <= 0:
		return
	var check := [id]
	if BEFORE_REDIRECT and before > 0 and before != id:
		check.append(before)
	for lst in item_lists():
		for item in lst.items:
			if item in check and not global_has(int(lst.acId)):
				reward(int(lst.acId), s)
