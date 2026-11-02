class_name XTusuXuan
extends RefCounted
## 【cc·白龙_13·未经审查】176 屠苏、177 璇第一期：招募与等级成长（正式 js/codex/runtime/installNativeTusuRuntime.js、installNativeXuanRuntime.js 的
## recruit，installNativeBindingChargeRuntime.js 的 B.curve／B.bindGrowth 第 285～337 行，璇的星谱初值 chart 与 syncMarkSkills 第 52～69 行）。
## - 记录按备注标签 <CodexTusu: 键>／<CodexXuan: 键> 查（同原版 ids()）。成长表照 CFG.growth（安装器从 tusu_design.json／xuan_design.json 写入）。
## - coefficient：本体等级在 1／10／20／30／40／50／60 级之间插值、向下取整；unlocked：本体等级到解锁等级。
## - skills()：任何角色身上的专属技能都按本体（$gameActors 里的 176／177）等级滤掉没解锁的；meetsSkillConditions 同样挡，
##   「归形」return 只在战斗中、本体被绑定且能动时可用（绑定框架二期才有，现在恒不可用）。
## - 同步（levelUp／levelDown／读档／招募后）：职业习得表里的专属技能按等级补学、忘掉。
## - 招募：入队；首次赠送并装上专属法宝（记 s.flags 的 _codexTusuRelicGiven／_codexXuanRelicGiven，原版记在角色上）；
##   璇先建星谱（s.flags._codexXuanChart，原版 a._codexXuanChart）并按槽学星纹技能。
## 不做：屠苏旧名「【最终兵器】屠苏」改回（重制没有改名，名字直接读数据库）；说明卡伤害系数改写（HelpExtend，画面）。
## 未移植：绑定框架、五相武具、支援、噬主、星谱菜单、战斗内全部机制（见交付单 cc_bailong-tusu1「盘点」）。招募的事件脚本还没接（等绑定框架）。
## 参照：mv_oracle/tusu_growth_probe.cjs（tests/fixtures/tusu_growth_oracle.json），测试 tests/xiyou_tusu.gd。

const TUSU := 176
const XUAN := 177
const TAGS := {TUSU: "CodexTusu", XUAN: "CodexXuan"}
const RELICS := {TUSU: 4047, XUAN: 4048}
const LEVELS := [1, 10, 20, 30, 40, 50, 60]
const DAMAGE := {TUSU: {"body_mag": [1800, 3600, 6300, 9000, 11700, 15000, 18000], "body_phys": [3000, 6000, 10500, 15000, 19500, 23500, 30000], "chiling": [5000, 10000, 17500, 25000, 32500, 39500, 50000], "dianshe": [3600, 7200, 12600, 18000, 23500, 28800, 36000], "guanri": [10800, 21600, 37800, 53500, 70200, 86500, 108000], "hengsao": [3000, 6000, 10500, 15000, 19500, 23500, 30000], "jianqi": [3300, 6600, 11550, 16500, 21500, 26500, 33000], "zhanfeng": [3600, 7200, 12600, 18000, 23500, 28800, 36000], "zhenhun": [3600, 7200, 12600, 18000, 23500, 28800, 36000], "zhenji": [2500, 5000, 8750, 12500, 16250, 20000, 25000]},
	XUAN: {"lengguang": [2000, 3500, 7000, 10000, 13000, 16000, 20000]}}
const UNLOCK := {TUSU: {"arm.hengsao": 10, "arm.guanri": 20, "support.jianqi": 5, "support.suoding": 15, "support.jintang": 25, "support.heming": 30, "support.zhenhun": 35, "growth.35": 1, "growth.50": 20, "growth.70": 40},
	XUAN: {"lengguang": 5, "gongsu": 10, "liexing": 30, "growth.35": 1, "growth.50": 20, "growth.70": 30, "mark.yuhui": 10, "mark.dingxing": 10, "mark.xianzhao": 10, "mark.tongdiao": 20, "mark.fenguang": 20, "mark.shihui": 20, "mark.yiguang": 30, "mark.binggui": 30, "mark.liuhui": 30}}
## 璇的星谱：三槽各一组星纹，初值与开槽等级（CFG.chart）
const MARKS := ["yuhui", "dingxing", "xianzhao", "tongdiao", "fenguang", "shihui", "yiguang", "binggui", "liuhui"]
const SLOT_OF := {"yuhui": 0, "dingxing": 0, "xianzhao": 0, "tongdiao": 1, "fenguang": 1, "shihui": 1, "yiguang": 2, "binggui": 2, "liuhui": 2}
const CHART_INITIAL := ["yuhui", "tongdiao", "yiguang"]

static var _keys := {}


## 技能编号 → 键（按模块）；{TUSU: {id: key}, XUAN: {...}}
static func keys(actor_id: int) -> Dictionary:
	if _keys.is_empty():
		for id in TAGS:
			_keys[id] = {}
		var re := RegEx.create_from_string("<(CodexTusu|CodexXuan):\\s*([^>]+)>")
		for sk in XDB.table("Skills"):
			if sk is Dictionary:
				var m := re.search(str(sk.get("note", "")))
				if m:
					_keys[TUSU if m.get_string(1) == "CodexTusu" else XUAN][int(sk.id)] = m.get_string(2).strip_edges()
	return _keys.get(actor_id, {})


static func skill_id(actor_id: int, key: String) -> int:
	var k := keys(actor_id)
	for id in k:
		if k[id] == key:
			return int(id)
	return 0


## 技能属于哪个模块：[本体编号, 键]；都不是返回 [0, ""]
static func owner_of(id: int) -> Array:
	for actor_id in TAGS:
		var k := keys(actor_id)
		if k.has(id):
			return [actor_id, k[id]]
	return [0, ""]


static func own(a) -> bool:
	return a is XActor and TAGS.has(int(a.actor_id))


## ownerInstance：$gameActors._data 里的本体，只读不建（审查第 22 期 P3-1：原来用 XState.actor() 会新建 1 级本体）；
## 没建过时返回 null：别人的专属技能全滤、不能用，系数按 1 级（B.curve 的 a 为空取 1 级）
static func _owner(actor_id: int):
	return XState.current.actors.get(actor_id) if XState.current != null else null


## M.coefficient(key, a)：a 省略时用本体
static func coefficient(actor_id: int, key: String, a = null) -> int:
	if a == null:
		a = _owner(actor_id)
	var lv := int(a.level) if a != null else 1
	return floori(XGuyu.curve(lv, DAMAGE[actor_id].get(key, [0, 0, 0, 0]), LEVELS))


## M.unlocked(a, key)：没在表里的键 1 级解锁
static func unlocked(actor_id: int, a, key: String) -> bool:
	return a != null and int(a.level) >= int(UNLOCK[actor_id].get(key, 1))


## Game_Actor.skills 包装：滤掉没解锁的专属技能（本体看自己，别人看本体）
static func skill_ids(a, ids: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for id in ids:
		if _listed(a, id):
			out.append(id)
	return out


static func _listed(a, id: int) -> bool:
	var o := owner_of(id)
	if int(o[0]) == 0:
		return true
	var who = a if own(a) and int(a.actor_id) == int(o[0]) else _owner(int(o[0]))
	return unlocked(int(o[0]), who, str(o[1]))


## Game_Actor.meetsSkillConditions 包装：「归形」只在战斗中被绑定、活着、能动时可用（直接返回，不再往里问）；没解锁的不能用
static func meets(a, skill: Dictionary) -> bool:
	if XBattleLogic.is_item(skill):
		return true
	var o := owner_of(int(skill.get("id", 0)))
	if int(o[0]) == 0:
		return true
	if own(a) and int(a.actor_id) == int(o[0]) and (str(o[1]).begins_with("yiwu.") or str(o[1]) in ["jixing.possess", "liexing"]):
		return false  # 【cc·悟空】易武（屠苏 376 行）、寄星·附身与列星（璇 458、460 行）要本人被绑定；绑定框架没进 main 前恒假，屠苏三期／璇的绑定期合进来时删掉这行
	if str(o[1]) == "return" and own(a) and int(a.actor_id) == int(o[0]):
		var logic = XBinding._logic()
		return logic != null and XBinding.is_bound(a) and a.is_alive() and a.hp > 0.0 and logic.can_move(a)  # 战斗中、绑定、活着、能动
	return _listed(a, int(skill.id))


## syncGrowth：职业习得表里的专属技能按等级补学、忘掉
static func sync(a) -> void:
	if not own(a):
		return
	var k := keys(int(a.actor_id))
	for l in a.class_data().get("learnings", []):
		var id := int(l.skillId)
		if not k.has(id):
			continue
		if int(l.level) <= int(a.level) and not a.skill_ids.has(id):
			a.learn_skill(id)
		elif int(l.level) > int(a.level) and a.skill_ids.has(id):
			a.forget_skill(id)


## 读档（extractSaveContents 包装）：两位本体各同步一次
static func after_load(s: XState) -> void:
	for id in TAGS:
		if s.actors.has(id):
			sync(s.actor(id))


## 璇的星谱（chart）：没有就建；各初值纹至少 1 级
static func chart(s: XState) -> Dictionary:
	if not s.flags.get("_codexXuanChart") is Dictionary:
		s.flags["_codexXuanChart"] = {"sand": 0, "level": {}, "slots": CHART_INITIAL.duplicate(), "partner": 0, "roster": [], "spent": {}}
	var c: Dictionary = s.flags["_codexXuanChart"]
	for m in CHART_INITIAL:
		if not int(c.level.get(m, 0)):
			c.level[m] = 1
	return c


## syncMarkSkills：槽里装着、有等级的星纹学会，其余忘掉
static func sync_marks(s: XState, a) -> void:
	var c := chart(s)
	for m in MARKS:
		var id := skill_id(XUAN, "mark." + m)
		if id == 0:
			continue
		if c.slots[SLOT_OF[m]] == m and int(c.level.get(m, 0)):
			a.learn_skill(id)
		else:
			a.forget_skill(id)


## T.recruit／X.recruit（外面包着 syncGrowth）：已在队返回 false
static func recruit(s: XState, actor_id: int) -> bool:
	if s.party.has(actor_id):
		return false
	var a := s.actor(actor_id)
	s.add_actor(actor_id)
	if actor_id == XUAN:
		sync_marks(s, a)
	var flag := "_codexTusuRelicGiven" if actor_id == TUSU else "_codexXuanRelicGiven"
	if not bool(s.flags.get(flag, false)):
		s.flags[flag] = true
		var relic := int(RELICS[actor_id])
		s.gain_gear("armor", relic, 1)
		var slot := a.equip_slots().find(int(XDB.rec("Armors", relic).get("etypeId", 0)))
		if slot >= 0:  # changeEquip：取背包里最后一件同底本的（刚得到的那件），原来装着的回背包
			var idx := -1
			for i in range(s.gear.size()):
				if str(s.gear[i].kind) == "armor" and int(s.gear[i].base) == relic:
					idx = i
			var item: Dictionary = s.gear[idx]
			s.gear.remove_at(idx)
			var worn = a.equips[slot]
			if worn is Dictionary and not worn.is_empty():
				s.gear.append(worn)
			a.equips[slot] = item
			a.refresh_passive()
	sync(a)
	return true


# ---- 模块公式（转换器 MODULE_FORMULAS 的 tusu／xuan，【cc·悟空·未经审查】events3 进切片时接上；屠苏三期 XTusu.damage 合进来后可改调它） ----
## T.armWeapon：武相技能的伤害基准看出战成员里的屠苏（书相取魔攻，其余取物攻）
const TUSU_ARM := {"chiling": "book", "dianshe": "bow", "guanri": "bow", "hengsao": "sword", "zhanfeng": "sword", "zhenji": "hammer"}
const TUSU_MAGIC := ["body_mag"]
static var _formula_key := RegEx.create_from_string("'([a-z_]+)'")


## CodexTusu.damage(a,b,'键')、CodexXuan.damage(a,b,'lengguang')、CodexXuan.heal(a,b)；不认的公式返回 null
static func formula(a, b, item: Dictionary):
	var text := str(item.get("damage", {}).get("formula", ""))
	if text.begins_with("CodexXuan.heal("):
		return xuan_heal(a, b)
	var m := _formula_key.search(text)
	if m == null:
		return null
	if text.begins_with("CodexTusu.damage("):
		return tusu_damage(a, m.get_string(1))
	if text.begins_with("CodexXuan.damage("):
		return float(a.mat) * coefficient(XUAN, m.get_string(1), a)  # X.damage：璇（a）魔攻×系数
	return null


## T.damage：武相取出战屠苏的基准；身相取 a（是屠苏时）或出战屠苏
static func tusu_damage(a, key: String) -> float:
	var t = a if a is XActor and int(a.actor_id) == TUSU else _battle_tusu()
	if TUSU_ARM.has(key):
		t = _battle_tusu()
	if t == null:
		return 0.0
	var arm_book := str(TUSU_ARM.get(key, "")) == "book"
	return float(t.mat if arm_book or TUSU_MAGIC.has(key) else t.atk) * coefficient(TUSU, key)


## X.healAmount：max(魔攻×[10,20]，目标最大生命×[20%,35%])，按璇等级 1～60 插值（不取整）
static func xuan_heal(a, b) -> float:
	var lv := int(a.level)
	return maxf(XGuyu.curve(lv, [10, 20], [1, 60]) * float(a.mat), XGuyu.curve(lv, [0.2, 0.35], [1, 60]) * float(b.mhp) if b != null else 0.0)


## tusu()：$gameParty.battleMembers() 里的屠苏
static func _battle_tusu():
	if XState.current == null:
		return null
	for x in XState.current.battle_members():
		if x is XActor and int(x.actor_id) == TUSU:
			return x
	return null
