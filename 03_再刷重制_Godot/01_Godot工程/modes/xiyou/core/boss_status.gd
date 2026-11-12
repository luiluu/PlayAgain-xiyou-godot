class_name XBossStatus
extends RefCounted
## Boss 状态面板的只读数据（Codex_BossStatusSummary v0.4.0）：谁算 Boss、状态分「异常／增益」、回合文字、说明。
## 只读状态，不参与结算。画面在 battle/boss_status_panel.gd。

const LABELS := ["生命", "魔法", "物攻", "物防", "魔攻", "魔防", "敏捷", "幸运"]
const XPARAM := ["命中率", "闪避率", "暴击率", "暴击闪避", "魔法闪避", "魔法反射", "反击率", "生命再生", "魔法再生", "怒气再生"]
const SPARAM := ["被锁定率", "防御效果", "恢复效果", "药理知识", "魔法消耗", "怒气充能", "物理承伤", "魔法承伤", "地形承伤", "经验获得"]
const DEBUFF_TYPES := "^(?:减益|异常|削弱|持续伤害|debuff|毒|损伤|疾病|诅咒|暗黑|黑暗|沉默|封印|禁咒|睡眠|眩晕|麻痹|混乱|魅惑|愤怒|破甲|灼伤|冰冷|冰封撕裂)$"
const BUFF_TYPES := "^(?:增益|强化|加成|buff|祝福|食物|合剂)$"
const DEBUFF_NAMES := "(诅咒|中毒|剧毒|疾病|睡眠|失明|封印|沉默|眩晕|麻痹|破甲|碎甲|冰冷|致残|灼伤|流血|气伤|虚弱|减益)"
const PARAM_IDS := {"mhp": 0, "mmp": 1, "atk": 2, "def": 3, "mat": 4, "mdf": 5, "agi": 6, "luk": 7}
const ICON_BUFF_START := 32  # Game_BattlerBase.ICON_BUFF_START
const ICON_DEBUFF_START := 48

static var _re := {}


static func _regex(pattern: String) -> RegEx:
	if not _re.has(pattern):
		_re[pattern] = RegEx.create_from_string(pattern)
	return _re[pattern]


## isBoss：Game_Enemy.setup／transform 记的 _codexBossDifficultyBoss，活着且已现身
static func is_boss(e) -> bool:
	return e is XEnemy and e.boss_difficulty_boss and not e.hidden and not e.is_dead()


## clean：去掉 \c[4] 这类转义和 <标签>
static func clean(text) -> String:
	var s := _regex("(?:\\\\|\\x1b)[A-Za-z]+\\[[^\\]]*\\]").sub(str(text), "", true)
	return _regex("<[^>]+>").sub(s, "", true).strip_edges()


static func note_block(note: String, tag: String) -> String:
	var m := _regex("(?i)<" + tag + "\\s*>([\\s\\S]*?)</" + tag + "\\s*>").search(note)
	if m == null:
		return ""
	var s := _regex("[ \\t]+").sub(clean(m.get_string(1)), " ", true)
	return _regex("\\n\\s*\\n").sub(s, "\n", true)


## JS Math.round(n*1000)/10 带符号，整数不带小数点
static func percent(n: float) -> String:
	var value := floorf(n * 1000.0 + 0.5) / 10.0
	var body := str(int(value)) if value == floorf(value) else str(value)
	return ("+" if value > 0 else "") + body + "%"


static func trait_text(state: Dictionary) -> String:
	var out := []
	for t in state.get("traits", []):
		var code := int(t.code)
		var id := int(t.dataId)
		var n := float(t.value)
		if code == 21 and id < LABELS.size() and n != 1.0:
			out.append(LABELS[id] + percent(n - 1.0))
		elif code == 22 and id < XPARAM.size() and n != 0.0:
			out.append(XPARAM[id] + percent(n))
		elif code == 23 and id < SPARAM.size() and n != 1.0:
			out.append(SPARAM[id] + percent(n - 1.0))
		elif code == 42:
			out.append("封印技能类型")
		elif code == 44:
			out.append("封印技能")
	var tag := _regex("(?i)<g_shuxing>([\\s\\S]*?)</g_shuxing>").search(str(state.get("note", "")))
	if tag:
		for m in _regex("(?i)\\b(mhp|mmp|atk|def|mat|mdf|agi|luk)\\s*=\\s*([+-])\\s*(\\d+(?:\\.\\d+)?)\\s*(%?)").search_all(tag.get_string(1)):
			out.append(LABELS[PARAM_IDS[m.get_string(1).to_lower()]] + m.get_string(2) + m.get_string(3) + m.get_string(4))
	return "，".join(out)


static func kind_of(state: Dictionary) -> String:
	var note := str(state.get("note", ""))
	var type := _regex("(?i)<BuffType:\\s*([^>]+)>").search(note)
	if type:
		var name := type.get_string(1).strip_edges()
		if name != "":
			if _regex("(?i)" + DEBUFF_TYPES).search(name):
				return "Debuff"
			if _regex("(?i)" + BUFF_TYPES).search(name):
				return "Buff"
	if int(state.get("restriction", 0)) > 0:
		return "Debuff"
	for t in state.get("traits", []):
		var code := int(t.code)
		if (code == 21 and float(t.value) < 1.0) or (code == 22 and float(t.value) < 0.0) or code == 42 or code == 44:
			return "Debuff"
	var values := _regex("(?i)<g_shuxing>([\\s\\S]*?)</g_shuxing>").search(note)
	if values and _regex("=\\s*-\\s*\\d").search(values.get_string(1)):
		return "Debuff"
	return "Debuff" if _regex(DEBUFF_NAMES).search(str(state.get("name", ""))) else "Buff"


## duration：turns 为空表示没有回合数（NaN）
static func duration(turns, state: Dictionary) -> String:
	var has_turns: bool = turns != null and is_finite(float(turns))
	var timing := int(state.get("autoRemovalTiming", 0))
	if int(state.get("id", 0)) != 0 and int(state.get("id", 0)) == XAlienBattle.corrosion_id():
		return "%d回合" % maxi(1, ceili(float(turns) if has_turns else 0.0))
	if timing > 0 and has_turns:
		if float(turns) > 0.0:
			return "%d回合" % ceili(float(turns))
		if float(turns) == 0.0:
			return "行动后结束" if timing == 1 else "回合末结束"
	if _regex("(?i)<Permanent>").search(str(state.get("note", ""))):
		return "常驻"
	return "本场战斗" if state.get("removeAtBattleEnd", false) else "持续"


static func entries(b) -> Array:
	if b == null:
		return []
	var rows := []
	var seen := {}
	var counters: Dictionary = b.state_data.get("_stateCounter", {})
	for id in b.state_ids:
		if seen.has(id):
			continue
		seen[id] = true
		var state := XDB.rec("States", id)
		if state.is_empty() or str(state.get("name", "")) == "" or id == 1:
			continue
		var meta := []
		var counter = counters.get(str(id))
		if counter is float or counter is int:
			meta.append("计数 " + str(counter))
		var turns = b.state_turns.get(id)
		var finite: bool = turns != null and is_finite(float(turns))
		var counted: bool = int(state.get("autoRemovalTiming", 0)) > 0 or id == XAlienBattle.corrosion_id()
		var note := str(state.get("note", ""))
		var desc := note_block(note, "StateNote")
		if desc == "":
			desc = note_block(note, "STATE_HELP")
		if desc == "":
			desc = note_block(note, "ステートヘルプ")
		if desc == "":
			desc = trait_text(state)
		rows.append({"id": id, "kind": kind_of(state), "name": clean(state.name), "icon": int(state.get("iconIndex", 0)),
			"stack": " · ".join(meta), "turns": duration(turns, state),
			"remaining": float(turns) if counted and finite else INF,
			"description": desc if desc != "" else "此状态没有文字说明。"})
	for i in range(b.buffs.size()):
		var level: int = b.buffs[i]
		if level == 0 or i >= LABELS.size():
			continue
		var turns: int = b.buff_turns[i]
		var icon := (ICON_BUFF_START + (level - 1) * 8 + i) if level > 0 else (ICON_DEBUFF_START + (-level - 1) * 8 + i)
		rows.append({"id": "buff%d" % i, "kind": "Buff" if level > 0 else "Debuff", "name": LABELS[i] + ("强化" if level > 0 else "弱化"),
			"icon": icon, "stack": "%d层" % absi(level), "turns": duration(turns, {"autoRemovalTiming": 2}),
			"remaining": float(turns), "description": LABELS[i] + percent(b.param_buff_rate(i) - 1.0)})
	rows.sort_custom(_before)
	return rows


## 排序：异常在前；剩余回合少的在前；再按编号（localeCompare numeric：数字在字母前）
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.kind != b.kind:
		return a.kind == "Debuff"
	if a.remaining != b.remaining:
		return a.remaining < b.remaining
	var ax = a.id
	var bx = b.id
	if ax is int and bx is int:
		return ax < bx
	if ax is int:
		return true
	if bx is int:
		return false
	return str(ax).naturalnocasecmp_to(str(bx)) < 0
