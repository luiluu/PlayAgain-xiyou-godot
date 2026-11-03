class_name XXuanChart
## 【cc·哪吒·未经审查】xuan1 璇的星谱规则（正式 js/codex/runtime/installNativeXuanRuntime.js 第 60、428～445、513～561、576～578 行）：
## 星砂（胜利一场＋3，含 Boss 的敌群＋12）、星纹学习／强化／回收／配槽、命主名册、并轨副宿主、同调元素、星契自律开关，
## 以及星谱各页的行文（画面在 ui/xuan_chart_page.gd）。星谱本身（chart）与按槽学技能（sync_marks）仍在 XTusuXuan（白龙 tusu1）。
## 参照 mv_oracle/xuan_chart_probe.cjs（tests/fixtures/xuan_chart_oracle.json），专项 tests/xiyou_xuan_chart.gd。
## 星纹在战斗里的效果和璇的绑定战斗机制在 XXuanBattle（xuan2 期起）。
## 星契自律只存开关（原版 a._codexXuanControl，重制记 s.flags._codexXuanControl），自动战斗的行为不在这里。

const NAMES := {
	"mark_yuhui": "余辉", "mark_dingxing": "定星", "mark_xianzhao": "先照", "mark_tongdiao": "同调", "mark_fenguang": "分光", "mark_shihui": "蚀辉",
	"mark_yiguang": "移光", "mark_binggui": "并轨", "mark_liuhui": "留辉",
	"markDesc_yuhui": "回光的溢出治疗按20%/35%/50%转为护盾", "markDesc_dingxing": "净化控制后，下一回合内阻止一次可净化的硬控制",
	"markDesc_xianzhao": "手动璃壁先制；自动可预支1星契（每3回合一次）", "markDesc_tongdiao": "棱光跟随宿主攻击的元素",
	"markDesc_fenguang": "宿主群攻时，棱光分配给最多2/3/4名敌人", "markDesc_shihui": "棱光命中时驱散一项增益（每3/2/1回合一次）",
	"markDesc_yiguang": "换宿主时迁移50%/75%/100%璇护盾", "markDesc_binggui": "指定副宿主，主宿主安全时也支援副宿主",
	"markDesc_liuhui": "换宿主后旧宿主保留共宿增益1/2/3回合",
}
const SLOT_NAMES := ["护主", "协同", "结缘"]
const UNLOCK_LEVELS := [10, 20, 30]
const COST := [10, 15, 25]
const SAND := 3
const BOSS_SAND := 12
const ELEMENT_INFO := "同调熟练1：本场棱光使用指定元素"
const TUSU := 176
## O-待定：满级（3 级）星纹的「强化」行原版读 cost[3] 得 undefined，显示「强化（星砂undefined）」；开着写「强化（已满级）」
static var MAX_LABEL_FIX := true


static func chart(s: XState) -> Dictionary:
	return XTusuXuan.chart(s)


## 在队伍里的璇；不在队返回 null（openStarchart 的 $gameParty._actors.indexOf < 0）
static func xuan(s: XState):
	return s.actor(XTusuXuan.XUAN) if s != null and s.party.has(XTusuXuan.XUAN) else null


static func stage(s: XState) -> int:
	return clampi(XAdvance.rank(s, XTusuXuan.XUAN), 0, 3)


## markLevel：开槽等级够、且槽里装的就是它，才有熟练度
static func mark_level(s: XState, a, m: String) -> int:
	if a == null or int(a.level) < UNLOCK_LEVELS[XTusuXuan.SLOT_OF[m]]:
		return 0
	var c := chart(s)
	return int(c.level.get(m, 0)) if c.slots[XTusuXuan.SLOT_OF[m]] == m else 0


# ---- 学习、强化、回收、配槽（X.learn／X.refund／X.equip）：{ret, error}；error 是原版 throw 的文字 ----
static func learn(s: XState, a, m: String) -> Dictionary:
	var c := chart(s)
	var lv := int(c.level.get(m, 0))
	if int(a.level) < UNLOCK_LEVELS[XTusuXuan.SLOT_OF[m]] or lv >= 3:
		return {"ret": false, "error": ""}
	var cost: int = COST[lv]
	if int(c.sand) < cost:
		return {"ret": false, "error": "星砂不足（需要%d）" % cost}
	c.sand = int(c.sand) - cost
	c.level[m] = lv + 1
	if lv > 0:
		c.spent[m] = int(c.spent.get(m, 0)) + cost
	XTusuXuan.sync_marks(s, a)
	return {"ret": true, "error": ""}


static func refund(s: XState, a, m: String) -> Dictionary:
	var c := chart(s)
	if int(c.level.get(m, 0)) <= 1:
		return {"ret": false, "error": ""}
	c.sand = int(c.sand) + int(c.spent.get(m, 0))
	c.spent[m] = 0
	c.level[m] = 1
	XTusuXuan.sync_marks(s, a)
	return {"ret": true, "error": ""}


static func equip(s: XState, a, m: String) -> Dictionary:
	var c := chart(s)
	if int(a.level) < UNLOCK_LEVELS[XTusuXuan.SLOT_OF[m]] or not int(c.level.get(m, 0)):
		return {"ret": false, "error": ""}
	c.slots[XTusuXuan.SLOT_OF[m]] = m
	XTusuXuan.sync_marks(s, a)
	return {"ret": true, "error": ""}


# ---- 星契自律（X.autoQualified／setControl）：只在战斗外改 ----
static func auto_qualified(s: XState, a) -> bool:
	return a != null and int(a.level) >= 50 and stage(s) >= 3


static func control(s: XState) -> String:
	return str(s.flags.get("_codexXuanControl", ""))


static func set_control(s: XState, a, mode: String) -> bool:
	if not auto_qualified(s, a) or not mode in ["manual", "auto"]:
		return false
	s.flags["_codexXuanControl"] = mode
	return true


# ---- 胜利星砂（endBattle 包装：璇在出战队、胜利一场；含 Boss 的敌群多给）----
static func credit_victory(s: XState, actors: Array, enemies: Array) -> int:
	if not actors.any(func(x): return int(x.actor_id) == XTusuXuan.XUAN):
		return 0
	var boss := enemies.any(func(e): return e.boss_difficulty_boss)
	var n := BOSS_SAND if boss else SAND
	var c := chart(s)
	c.sand = int(c.sand) + n
	return n


# ---- 名册、副宿主、元素（starMenu 里的闭包）----
## 命主名册：已在就移出，不在就加到末尾，再只留最后 stage 人
static func toggle_roster(s: XState, id: int) -> void:
	var c := chart(s)
	# 读档后名册是 [8.0]（存档走 JSON），[8.0].find(8) 为 -1；先归成整数再找
	c.roster = c.roster.map(func(x): return int(x))
	var i: int = c.roster.find(id)
	if i >= 0:
		c.roster.remove_at(i)
	else:
		c.roster.append(id)
		c.roster = c.roster.slice(maxi(0, c.roster.size() - stage(s)))


static func set_partner(s: XState, id: int) -> void:
	chart(s).partner = id


static func set_element(s: XState, id: int) -> void:
	chart(s).element = id


# ---- 各页行文 ----
static func mark_label(s: XState, m: String) -> String:
	var c := chart(s)
	var lv := int(c.level.get(m, 0))
	return NAMES["mark_" + m] + ("　熟练%d" % lv if lv else "　未学") + ("　[已配]" if c.slots[XTusuXuan.SLOT_OF[m]] == m else "")


static func home_info(s: XState) -> Array:
	var c := chart(s)
	return ["星谱　星砂 %d" % int(c.sand), "护主：%s　协同：%s　结缘：%s" % [NAMES["mark_" + c.slots[0]], NAMES["mark_" + c.slots[1]], NAMES["mark_" + c.slots[2]]]]


## 首页各行；行里的 kind 供画面分派（control／slot／partner／roster／element）
static func home_rows(s: XState, a) -> Array:
	var c := chart(s)
	var qualified := auto_qualified(s, a)
	var rows := [{"kind": "control", "label": "星契自律：" + ("自动" if control(s) == "auto" else "手动") + ("" if qualified else "（50级第三阶解锁）"), "enabled": qualified}]
	for i in 3:
		rows.append({"kind": "slot", "slot": i, "label": SLOT_NAMES[i] + "槽：选择星纹", "enabled": int(a.level) >= UNLOCK_LEVELS[i]})
	var partner := "未指定"
	if int(c.partner):
		partner = s.actor(int(c.partner)).display_name()
	rows.append({"kind": "partner", "label": "并轨副宿主：" + partner, "enabled": true})
	rows.append({"kind": "roster", "label": "命主名册（%d席）" % stage(s), "enabled": stage(s) > 0})
	var elements: Array = XDB.system().elements
	var el := "未指定"
	if int(c.get("element", 0)):
		el = str(elements[int(c.element)])
	rows.append({"kind": "element", "label": "同调指定元素：" + el, "enabled": true})
	return rows


static func slot_rows(s: XState, slot: int) -> Array:
	var rows := []
	for m in XTusuXuan.MARKS:
		if XTusuXuan.SLOT_OF[m] == slot:
			rows.append({"label": mark_label(s, m), "m": m, "enabled": true})
	return rows


static func mark_rows(s: XState, m: String) -> Array:
	var c := chart(s)
	var lv := int(c.level.get(m, 0))
	return [{"label": "配入此槽", "act": "equip", "enabled": lv > 0},
		{"label": (learn_label(lv) if lv else "学习（星砂%d）" % COST[0]), "act": "learn", "enabled": lv < 3},
		{"label": "回收强化星砂", "act": "refund", "enabled": lv > 1}]


## 强化行：COST 只有 3 项，满级时原版越界读到 undefined（这一行本就不可选，配入、回收照常）
static func learn_label(lv: int) -> String:
	if lv < COST.size():
		return "强化（星砂%d）" % COST[lv]
	return "强化（已满级）" if MAX_LABEL_FIX else "强化（星砂undefined）"


## 可指定的队员：除璇本人和屠苏之外的全队（$gameParty.allMembers）
static func party_rows(s: XState) -> Array:
	var rows := []
	for t in s.members():
		if int(t.actor_id) != XTusuXuan.XUAN and int(t.actor_id) != TUSU:
			rows.append({"label": t.display_name(), "id": int(t.actor_id), "enabled": true})
	return rows


## 元素页：系统元素表里第 2 项起有名字的
static func element_rows() -> Array:
	var rows := []
	var elements: Array = XDB.system().elements
	for i in range(2, elements.size()):
		if str(elements[i]) != "":
			rows.append({"label": str(elements[i]), "id": i, "enabled": true})
	return rows
