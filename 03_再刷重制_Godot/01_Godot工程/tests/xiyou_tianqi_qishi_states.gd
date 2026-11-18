extends Node
const Kit := preload("res://tests/lib/tq_save_kit.gd")
## T193（Kyo 11-18 D202 选 A）：天启篇「天道*」状态组改名「启示·」，只在天启篇存档套用（XTextFix tianqi_dict）。
## 一、状态名：264、686、691～696、698、1101～1104、2420 前缀「天道*」→「启示·」，后半截不动；995「破阵——启示诅咒」。
## 二、备注：995 RightDownNote、996／997 StateNote「启示状态」、1001～1003 与 2442 RightDownNote「挣脱启示的枷锁」；胜天半子名字保留。
##     备注除了这几处字面，其余（脚本、notetag）逐字不变。
## 三、技能：施放技能名同步；6162、5510、6176、6177、5568、5580 说明里的「天道」改；5568／5580 天启篇重构卡面同步。
## 四、西游档 1:1 原貌；天启篇里 XTextFix.DICT 关掉也回原貌。
const STATES := {264: "启示·放逐", 686: "启示·祝福", 691: "启示·眷顾", 692: "启示·无情", 693: "启示·泯灭", 694: "启示·压制",
	695: "启示·屠戮", 696: "启示·灭绝", 698: "启示·终焉", 1101: "启示·封魔", 1102: "启示·封技", 1103: "启示·不灭",
	1104: "启示·永恒", 2420: "启示·道争（神魔战纹）", 995: "破阵——启示诅咒", 996: "破阵——胜天半子", 997: "破阵——胜天半子*伪"}
const SKILLS := {3778: "启示·终焉", 3789: "启示·祝福", 3794: "启示·眷顾", 3795: "启示·灭绝", 3813: "启示·无情", 3814: "启示·泯灭",
	3815: "启示·压制", 3816: "启示·屠戮", 6107: "启示·放逐", 6102: "启示·封魔", 6103: "启示·封技",
	# T198（D202 补漏）：同族技能名
	6070: "启示领域", 6071: "启示领域*伪", 6101: "启示·屠灭", 6104: "启示·成长", 6105: "启示·回归", 6106: "启示·茁壮",
	2570: "启示·裁决", 2572: "启示·裁决"}
## T198：这些技能名的后半截（去掉旧前缀后）必须与原名后半截一致
const T198_OLD := {6070: ["天道", "启示"], 6071: ["天道", "启示"], 6101: ["天道*", "启示·"], 6104: ["天道*", "启示·"],
	6105: ["天道*", "启示·"], 6106: ["天道*", "启示·"], 2570: ["天道*", "启示·"], 2572: ["天道*", "启示·"]}
## 备注（字段 note）里天启篇该换的字面：旧 → 新
const NOTE_SWAPS := [["<RightDownNote:\"天道诅咒\">", "<RightDownNote:\"启示诅咒\">"], ["所有天道状态有效度", "所有启示状态有效度"],
	["<RightDownNote:\"挣脱天道的枷锁\">", "<RightDownNote:\"挣脱启示的枷锁\">"], ["能释放天道状态", "能释放启示状态"],
	["天道·封魔", "启示·封魔"], ["天道·封技", "启示·封技"]]
const NOTE_STATES := [995, 996, 997, 1001, 1002, 1003, 2442]
const NOTE_SKILLS := [6162, 5510, 6176, 6177, 5568, 5580]

var results: Array = []
var raw_states: Array
var raw_skills: Array
## 西游档读到的记录（已过统一文字修正：零宽符等），天启篇备注按它换字面比对，排除别的修正干扰
var plain := {}


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _t(table: String, id: int) -> Dictionary:
	return XDB.table(table)[id]


## 西游档备注按 NOTE_SWAPS 换一遍（天启篇备注应当恰好等于它；6162 另有 T177 的「天道眷顾者」→「启示眷属」）
func _swapped(s: String) -> String:
	for p in NOTE_SWAPS:
		s = s.replace(p[0], p[1])
	return s.replace("天道眷顾者", "启示眷属")


## T199：这几条记录同时在 rules.json tianqi_note_by_id 里的话（1001～1003、2442 的 StateNote「造成的所有伤害结果*…」），天启篇备注也换了说明，比对时一起换
func _by_id_swap(table: String, id: int, s: String) -> String:
	var by_id: Dictionary = XDB.parse_file("res://modes/xiyou/text_fix/rules.json").get("tianqi_note_by_id", {})
	for p in by_id.get(table, {}).get(str(id), []):
		s = s.replace(p[0], p[1])
	return s


func _keys() -> Array:
	var out := []
	for id in STATES.keys() + NOTE_STATES:
		out.append(["States", id])
	for id in SKILLS.keys() + NOTE_SKILLS:
		out.append(["Skills", id])
	return out


## 西游档：名字、描述、备注里「天道」个数与 generated 原文相同（T193 一处没换）；again＝与第一次西游档读到的逐字相同
func _plain_same(tag: String, again := false) -> void:
	var bad := []
	for tk in _keys():
		var raw: Dictionary = (raw_states if tk[0] == "States" else raw_skills)[tk[1]]
		for k in ["name", "description", "note"]:
			var v := str(_t(tk[0], tk[1]).get(k, ""))
			if v.count("天道") != str(raw.get(k, "")).count("天道") or v.contains("启示"):
				bad.append([tk, k])
			if again and v != str(plain[tk][k]):
				bad.append([tk, k, "changed"])
			elif not again:
				plain[tk] = plain.get(tk, {})
				plain[tk][k] = v
	_check(tag, bad.is_empty(), bad)


func _run() -> void:
	XMessageBox.auto = true
	var kit := Kit.new("xiyou_tianqi_qishi_states")
	raw_states = XDB.parse_file(XDB.BASE + "db/States.json")
	raw_skills = XDB.parse_file(XDB.BASE + "db/Skills.json")
	_check("raw_old_names", str(raw_states[264].name) == "天道*放逐" and str(raw_skills[3778].name) == "天道*终焉", [raw_states[264].name])
	# 四、西游档原貌
	XState.current = XState.new_game_blank()
	XTextFix.sync_mode()
	_check("plain_mode", not XTextFix.tq_on())
	_plain_same("plain_identical")
	XTianqiSkills.CARDS = true  # 期四角色卡默认关（PHASE4），专项单独打开看 5568／5580 重构卡面
	_check("plain_5568_card", str(XDB.rec("Skills", 5568).note).contains("天道·封魔"))
	# 天启篇档
	var s := Kit.new_game("jiusi")
	_check("tq_mode", XTextFix.tq_on())
	# 一、状态名
	var bad := []
	for id in STATES:
		if str(_t("States", id).name) != STATES[id]:
			bad.append([id, _t("States", id).name])
	_check("tq_state_names", bad.is_empty(), bad)
	# 后半截不动：去掉前缀与原名后半截一致
	bad = []
	for id in [264, 686, 691, 692, 693, 694, 695, 696, 698, 1101, 1102, 1103, 1104, 2420]:
		if str(raw_states[id].name).trim_prefix("天道*") != str(_t("States", id).name).trim_prefix("启示·"):
			bad.append(id)
	_check("tq_state_suffix_kept", bad.is_empty(), bad)
	# 一、施放技能名
	bad = []
	for id in SKILLS:
		if str(_t("Skills", id).name) != SKILLS[id]:
			bad.append([id, _t("Skills", id).name])
	_check("tq_skill_names", bad.is_empty(), bad)
	# 二、状态备注：恰好只换了这几处字面
	bad = []
	for id in NOTE_STATES:
		var want := _by_id_swap("States", id, _swapped(str(plain[["States", id]].note)))
		if str(_t("States", id).note) != want or want == str(plain[["States", id]].note):
			bad.append([id, _t("States", id).note])
	_check("tq_state_notes", bad.is_empty(), bad)
	_check("tq_995_rdn", str(_t("States", 995).note).contains("<RightDownNote:\"启示诅咒\">"))
	_check("tq_996_note", str(_t("States", 996).note).contains("所有启示状态有效度*60%") and str(_t("States", 996).note).contains("<RightDownNote:\"胜天半子\">"))
	_check("tq_997_note", str(_t("States", 997).note).contains("所有启示状态有效度*60%") and str(_t("States", 997).note).contains("<RightDownNote:\"胜天半子……吗？\">"))
	_check("tq_1001_rdn", str(_t("States", 1001).note).contains("挣脱启示的枷锁") and str(_t("States", 2442).note).contains("挣脱启示的枷锁"))
	# 三、技能说明
	bad = []
	for id in NOTE_SKILLS:
		var want := _by_id_swap("Skills", id, _swapped(str(plain[["Skills", id]].note)))
		if str(_t("Skills", id).note) != want or want == str(plain[["Skills", id]].note):
			bad.append([id, _t("Skills", id).note])
	_check("tq_skill_notes", bad.is_empty(), bad)
	_check("tq_6176_desc", str(_t("Skills", 6176).description).contains("启示……又如何？") and not str(_t("Skills", 6176).description).contains("天道"), _t("Skills", 6176).description)
	_check("tq_6162_desc", str(_t("Skills", 6162).description) == "被动\n劫取启示之运，加持己身", _t("Skills", 6162).description)
	# T198：后半截不动
	bad = []
	for id in T198_OLD:
		var pf: Array = T198_OLD[id]
		if str(raw_skills[id].name).trim_prefix(pf[0]) != str(_t("Skills", id).name).trim_prefix(pf[1]):
			bad.append(id)
	_check("tq_t198_suffix_kept", bad.is_empty(), bad)
	_check("tq_6162_paren", str(_t("Skills", 6162).note).contains("启示眷属(能释放启示状态)"))
	# 天启篇重构卡面（skill_rework.json desc）
	var c68 := str(XDB.rec("Skills", 5568).note)
	var c80 := str(XDB.rec("Skills", 5580).note)
	_check("tq_rework_cards", c68.contains("启示·封魔、启示·封技") and c80.contains("免疫启示·封魔、启示·封技") and not c68.contains("天道") and not c80.contains("天道"), [c68, c80])
	# 看得到的字里不再有「天道」（T193＋T198 范围内的记录）
	bad = []
	for tk in _keys():
		for k in ["name", "description", "note"]:
			if str(_t(tk[0], tk[1]).get(k, "")).contains("天道"):
				bad.append([tk, k])
	_check("tq_no_tiandao_left", bad.is_empty(), bad)
	# 范围外不动：被动 6168「天道诅咒」（名字与描述）、6213「天道注视」
	_check("tq_out_of_scope_kept", str(_t("Skills", 6168).name) == "天道诅咒" and str(_t("Skills", 6213).name) == "天道注视" and str(_t("Skills", 6168).description) == str(raw_skills[6168].description))
	# 四、DICT 开关关掉回原貌
	XTextFix.DICT = false
	XTextFix.clear_cache()
	_check("tq_dict_off", str(_t("States", 264).name) == "天道*放逐" and str(_t("States", 995).note) == str(raw_states[995].note) and str(_t("Skills", 6070).name) == "天道领域" and str(_t("Skills", 6162).description) == str(raw_skills[6162].description))
	XTextFix.DICT = true
	XTextFix.clear_cache()
	# 换回西游档：缓存按模式位隔离，仍是原貌
	XState.current = XState.new_game_blank()
	XTextFix.sync_mode()
	_plain_same("plain_identical_again", true)
	XState.current = s
	XTextFix.sync_mode()
	_check("tq_switch_back", str(_t("States", 264).name) == "启示·放逐")
	XTianqiSkills.CARDS = false
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
