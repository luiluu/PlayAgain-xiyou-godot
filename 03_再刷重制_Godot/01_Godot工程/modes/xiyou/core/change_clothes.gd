class_name XChangeClothes
extends RefCounted
## 更衣（Star_ChangeClothes 的 Scene_ChangeClothes；方桌大厅衣橱管理员 Map4 EV17「查看衣橱」）。界面在 XChangeClothesScene。
## 照冻结 v0.28 原版（tests/fixtures/change_clothes_oracle.json）：
## - 衣橱条目：数据库角色（名字非空，编号为正）与换装表（插件参数「ChangeClothes i」，编号 −i：名称、行走图、序号、获得途径）。
## - 解锁表 ConfigManager.ChangeClothesLite（全局配置，所有存档共用，XConfig.clothes_unlocked）：事件脚本
##   `if(ConfigManager.ChangeClothesLite.indexOf(N) == -1){ ConfigManager.ChangeClothesLite.push(N); }` 解锁换装表项；
##   打开界面时（Scene_ChangeClothes.initialize）补进队伍与角色仓库里的角色。
## - 替换形象：$gamePlayer.Set_OcharacterName／Set_OcharacterIndex（随局内存档，XState.player_costume）。只换玩家（队首）
##   的地图行走图，跟随、脸图、战斗图都不变（插件只改 Game_Player 的 characterName／characterIndex）。还原＝清空。
## - 分类 8 档：第 k 档（k=0..5）列 CodexQuality.actorGrade == k 的角色。
## O-093（可回退，FIX_TABS）：原版 v0.15 插入「神话」后入口序号没改，第 6 档「神话」列的是换装表（actorGrade==−1 没有角色），
##   第 7 档「典藏」是空表，64 个神话角色永远看不到；重制改成「神话」列神话角色、「典藏」列换装表。
##   另外典藏空表上按确定原版抛 TypeError，重制蜂鸣（界面）；解锁表原版要等别处存配置才落盘，重制解锁时就存。

const CATEGORIES := ["普通", "优秀", "精良", "史诗", "传说", "不朽", "神话", "典藏"]
const ACTOR_GRADES := {0: 0, 1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 4, 8: 5, 9: 5, 10: 6, 12: 6}
const MAX_ENTRIES := 150
const DONE_TEXT := "替换完成"
const LOCKED_TEXT := "未解锁"
const RESTORE_TEXT := "还原完成"

## O-093 开关：false 时照原版（神话档＝换装表、典藏档空）
static var FIX_TABS := true
static var _entries: Array = []


## DataManager.Star_GetChangeClothesOpt：换装表 1～150 项（空项跳过），编号 −i
static func entries() -> Array:
	if _entries.is_empty():
		var p := XDB.plugin("Star_ChangeClothes")
		for i in range(1, MAX_ENTRIES + 1):
			var raw := str(p.get("ChangeClothes %d" % i, ""))
			var d = JSON.parse_string(raw) if raw.strip_edges() != "" else null
			if d is Dictionary:
				_entries.append({"id": -i, "name": str(d.get("name", "")), "characterName": str(d.get("characterName", "")),
					"characterIndex": int(float(str(d.get("characterIndex", "0")))) if str(d.get("characterIndex", "")).is_valid_float() else 0,
					"GetFs": str(d.get("GetFs", ""))})
	return _entries


## CodexQuality.actorGrade：Number(meta.Actorquality)（非数为 0）查表，表外为 0
static func actor_grade(d: Dictionary) -> int:
	var q := str(d.get("meta", {}).get("Actorquality", "")).strip_edges()
	if not q.is_valid_float() or float(q) != floorf(float(q)):
		return 0
	return int(ACTOR_GRADES.get(int(float(q)), 0))


## Window_ChangeClothesIndex.refresh：分类序号 → 条目（数据库角色记录或换装表项）
static func list(category: int) -> Array:
	var grade := category
	var with_entries := false
	if FIX_TABS:
		with_entries = category == 7
		grade = -1 if category == 7 else category
	else:
		# 原版：第 6 档 refresh(0) → actorGrade == −1 ＋换装表；第 7 档 refresh(8) → actorGrade == 7
		with_entries = category == 6
		grade = -1 if category == 6 else category
	var out := []
	var actors: Array = XDB.table("Actors")
	for i in range(1, actors.size()):
		var d = actors[i]
		if d is Dictionary and str(d.get("name", "")) != "" and actor_grade(d) == grade:
			out.append(d)
	if with_entries:
		out.append_array(entries())
	return out


static func unlocked(id: int) -> bool:
	return XConfig.clothes_unlocked().has(id)


## 事件脚本的解锁写法（不在表里才加）
static func unlock(id: int) -> void:
	var lite := XConfig.clothes_unlocked()
	if not lite.has(id):
		lite.append(id)
		XConfig.save_clothes()


## Scene_ChangeClothes.initialize：把队伍与角色仓库的角色补进解锁表
static func on_open(s: XState) -> void:
	var lite := XConfig.clothes_unlocked()
	var n := lite.size()
	for id in s.party + s.saved_actors:
		if not lite.has(id):
			lite.append(id)
	if lite.size() != n:
		XConfig.save_clothes()


## Window_ChangeClothesStatus.drawAllContents 的获得途径
static func source_text(e: Dictionary) -> String:
	var fs := str(e.get("GetFs", ""))
	return "获得途径:" + (fs if fs != "" else "获得伙伴" + str(e.get("name", "")))


## onRefSzOk：已解锁 → 替换形象，返回 true；未解锁返回 false
static func apply(s: XState, e: Dictionary) -> bool:
	if not unlocked(int(e.get("id", 0))):
		return false
	s.player_costume = {"characterName": str(e.get("characterName", "")), "characterIndex": int(e.get("characterIndex", 0))}
	return true


## onHYOk
static func restore(s: XState) -> void:
	s.player_costume = {}


## Game_CharacterBase.characterName／characterIndex 对 Game_Player：替换名非空才换名；序号单独判断
static func player_image(s: XState, name: String, index: int) -> Array:
	var c: Dictionary = s.player_costume if s else {}
	var n := str(c.get("characterName", ""))
	return [n if n != "" else name, int(c.characterIndex) if c.has("characterIndex") else index]


static func from_save(v) -> Dictionary:
	if v is Dictionary and v.has("characterName"):
		return {"characterName": str(v.characterName), "characterIndex": int(v.get("characterIndex", 0))}
	return {}
