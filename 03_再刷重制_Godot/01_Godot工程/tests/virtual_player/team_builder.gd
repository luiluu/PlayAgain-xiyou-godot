extends RefCounted
## 【cc·T162】配队器（Kyo 11-18 23:26～23:29 定）：量数的队伍按「职责模板＋档位规则」配，不再只按档位人数随机抽。
## 纯静态函数，c_tier、baseline_dps、zhengdao_scenarios、swap_calibrate 都能 preload 了调：
##   const TB := preload("res://tests/virtual_player/team_builder.gd")
##   TB.random_teams("A", 8, seed, "jianxian")   # 合理随机队（量中位）：模板内、合法档位内随机抽
##   TB.strongest("A", "jianxian")               # 最强队（量上限）：每个职责位挑同档最强的人
##   TB.strongest_all("jianxian")                # {模板: 队}，调用方四个都量、取表现最好的那支
##   TB.report("jianxian")                       # 缺人／缺职责的清单（不静默补），含并入输出池的「均衡」名单
##
## 职责模板（Kyo 11-18）：A 2输出＋1坦克＋1辅助；B 1输出＋1坦克＋2辅助；C 1输出＋3辅助；D 2输出＋2辅助。
## 职责读 base_line.json 的 actors[id].role（输出／坦克／辅助／均衡）。「均衡」先并入输出池（协调 11-18；要 Kyo 定「均衡算哪个职责」，report 列名单）。
## 队伍是上场 4 人，顺序＝模板里的职责顺序（输出、坦克、辅助）；助力位（第 5 格）一律空着，同稿第九节「助力位空着」。
## 档位规则（balance_table.json difficulties[].roster，游戏里的 XTianqi.lineup_ok 是 5 人整栏校验）：
##   - 候选池＝本档 pool 里的档位（艰险只有弱者、强者；九死起有超强者），停用的角色不要（XTianqi.pool 已滤），上不了场的不要；
##   - 上场 4 人里超强者 ≤ super_cap；弱者 ≥ min_weak − 1（第 5 格助力位可以补一名弱者，所以上场 4 人最少 min_weak − 1 名弱者；
##     艰险 min_weak 3 ⇒ 上场 4 人至少 2 弱者、最多 2 强，同协调说的「艰险场上最多 2 强」）。
## 排序（最强队用）：
##   - 输出：team_rank.json（T220 v4 定稿甲档量数的每人峰值；超强者的次序即 Kyo D209 名次），没有量数的输出排最后；
##   - 坦克、辅助：没有现成的可量排序。暂按「同档里 81 级生命×(物防＋魔防)」从高到低（承伤厚度），辅助同样；这条是我定的权宜口径，
##     辅助的「治疗／增益能力」没有数能排——交付单已写明，等有排序再换（RANK_SUPPORT 可替换）。
## 缺人或缺职责：report() 列出；random_teams／strongest 配不出来时返回空数组，不静默补。
## 【cc·T328】辅助位带复活（Kyo 11-21「阵容尽量选择带复活的奶妈」）：REVIVE_FIRST 开着时，有辅助位的模板先保一名会复活技能的辅助
##   （同档、合法的里面，最强队挑承伤最厚的那个，随机队从会复活的辅助里抽），其余辅助位照旧；本档没有会复活的辅助就照旧配、
##   report 写「靠复活道具」。只保一名：第二个辅助位不强塞复活，免得挤掉别的辅助（出手时也只由一人复活，见 vp_battle_logic）。
##   「会复活」＝81 级（天启篇档）会的技能里有目标为倒下队友、解除战斗不能或回生命的（vp_battle_logic.revives，从数据判，不看名字），
##   且不靠特殊道具（<Item n Cost>）；revive_skill_names(id, 等级) 可按别的等级判（换人时用存档当前等级）。

const TEMPLATES := {
	"A": {"输出": 2, "坦克": 1, "辅助": 1},
	"B": {"输出": 1, "坦克": 1, "辅助": 2},
	"C": {"输出": 1, "辅助": 3},
	"D": {"输出": 2, "辅助": 2},
}
const ROLE_ORDER := ["输出", "坦克", "辅助"]
const RANK_FILE := "res://tests/virtual_player/team_rank.json"
const LEVEL := 81

static var _rank := {}
static var _bulk := {}
static var _playable := {}
static var _revive := {}

## 【cc·T328】辅助位先保一名会复活的（关掉＝T162 原配法）
static var REVIVE_FIRST := true


## 「均衡」职责并入输出池（协调 11-18 定，待 Kyo 定「均衡算哪个职责」）：BALANCED_AS_OUTPUT 关掉就回到「均衡不入队」
static var BALANCED_AS_OUTPUT := true


## id → 职责（base_line.json；均衡按 BALANCED_AS_OUTPUT 并入输出）
static func role_of(id: int) -> String:
	var r := raw_role(id)
	return "输出" if r == "均衡" and BALANCED_AS_OUTPUT else r


static func raw_role(id: int) -> String:
	return str(XTianqiBase.line_data().get("actors", {}).get(str(id), {}).get("role", ""))


static func rule(difficulty: String) -> Dictionary:
	for d in XTianqiBalance.data().get("difficulties", []):
		if str(d.get("key", "")) == difficulty:
			var r: Dictionary = d.get("roster", {})
			return {"super_cap": int(r.get("super_cap", 0)), "min_weak": int(r.get("min_weak", 0)), "pool": r.get("pool", [])}
	return {}


## 上场 4 人至少几名弱者（第 5 格助力位可补一名）
static func min_weak_field(difficulty: String) -> int:
	return maxi(0, int(rule(difficulty).get("min_weak", 0)) - 1)


static func playable(id: int, difficulty: String) -> bool:
	var key := "%s:%d" % [difficulty, id]
	if not _playable.has(key):
		var t := XState.new_game(XTianqi.legacy_of(difficulty), id, [])
		_playable[key] = t.battle_members().map(func(x): return int(x.actor_id)).has(id)
	return bool(_playable[key])


## 本档合法候选：{职责: [id…]}（排好序：升序，抽签要可复现）。上不了场的、停用的、「均衡」的都不在里面
static func candidates(difficulty: String) -> Dictionary:
	var pool: Dictionary = XTianqi.pool(difficulty)
	var out := {"输出": [], "坦克": [], "辅助": []}
	var all := []
	for tier in pool:
		all.append_array(pool[tier])
	all.sort()
	for id in all:
		var r := role_of(int(id))
		if out.has(r) and playable(int(id), difficulty):
			out[r].append(int(id))
	return out


## 上场 4 人是否合法（档位规则，见文件头）
static func legal(team: Array, difficulty: String) -> bool:
	var r := rule(difficulty)
	if r.is_empty() or team.size() != 4:
		return false
	var supers := 0
	var weak := 0
	var seen := {}
	for id in team:
		if seen.has(int(id)):
			return false
		seen[int(id)] = true
		supers += 1 if XTianqiSkills.is_super(int(id), true) else 0
		weak += 1 if XTianqiSkills.is_weak(int(id), true) else 0
	return supers <= int(r.super_cap) and weak >= min_weak_field(difficulty)


## 一支队的职责构成是否等于模板
static func matches(team: Array, template: String) -> bool:
	var want: Dictionary = TEMPLATES[template]
	var got := {}
	for id in team:
		var r := role_of(int(id))
		got[r] = int(got.get(r, 0)) + 1
	for r in ROLE_ORDER:
		if int(got.get(r, 0)) != int(want.get(r, 0)):
			return false
	return team.size() == 4


## 合理随机队：模板内、合法档位内随机抽 n 队（互不相同）；配不出来（缺职责或合法的抽不到）返回比 n 少的数组，调用方看 report
static func random_teams(template: String, n: int, seed_val: int, difficulty: String) -> Array:
	var cand := candidates(difficulty)
	var want: Dictionary = TEMPLATES[template]
	for r in want:
		if (cand[r] as Array).size() < int(want[r]):
			return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + template.unicode_at(0) * 131
	var out := []
	var seen := {}
	var tries := 0
	while out.size() < n and tries < n * 400:
		tries += 1
		var team := []
		for r in ROLE_ORDER:
			var bag: Array = (cand[r] as Array).duplicate()
			for _i in int(want.get(r, 0)):
				var pick_from := bag
				if REVIVE_FIRST and r == "辅助" and _i == 0:   # T328：第一个辅助位从会复活的里抽（没有就照旧）
					var rv := bag.filter(func(x): return can_revive(int(x)))
					if not rv.is_empty():
						pick_from = rv
				var got = pick_from[rng.randi_range(0, pick_from.size() - 1)]
				bag.erase(got)
				team.append(got)
		if not legal(team, difficulty):
			continue
		var sorted_key := team.duplicate()
		sorted_key.sort()
		var key := str(sorted_key)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(team)
	return out


static func _peaks() -> Dictionary:
	if _rank.is_empty():
		var p = JSON.parse_string(FileAccess.get_file_as_string(RANK_FILE))
		_rank = p.get("peaks", {}) if p is Dictionary else {"_": 0}
	return _rank


## 81 级生命×(物防＋魔防)：坦克、辅助的承伤厚度（权宜口径，见文件头）
static func bulk(id: int) -> float:
	if not _bulk.has(id):
		var t := XState.new_game(XTianqi.legacy_of("jianxian"), id, [])
		var a := t.actor(id)
		t.actor_max_level = LEVEL
		a.change_level_mv(LEVEL)
		_bulk[id] = float(a.param(0)) * (float(a.param(3)) + float(a.param(5)))
	return float(_bulk[id])


## 某级（默认 81）会、而且不靠特殊道具就能放的复活技能名（「id 名字」）；空＝不会复活。
## 在天启篇档里判（flags.tianqi.rules＝1，技能重构卡照天启篇走；T328 核查 P1-3：不设的话测的是西游档）。
## 靠特殊道具的（<Item n Cost>，如玉兔精 3760 沉鱼萝雁要萝卜 1722）不算，单列在 revive_item_bound（T328 核查 P2-1）
static func revive_skill_names(id: int, level := LEVEL) -> Array:
	return _revive_info(id, level).free


static func revive_item_bound(id: int, level := LEVEL) -> Array:
	return _revive_info(id, level).bound


static func _revive_info(id: int, level: int) -> Dictionary:
	var key := "%d:%d" % [id, level]
	if not _revive.has(key):
		var prev := XState.current
		var t := XState.new_game(XTianqi.legacy_of("jianxian"), id, [])
		t.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
		XState._become_current(t)
		var a := t.actor(id)
		t.actor_max_level = maxi(LEVEL, level)
		a.change_level_mv(level)
		var VPL = load("res://tests/virtual_player/vp_battle_logic.gd")
		var names := func(list: Array) -> Array: return list.map(func(s): return "%d %s" % [int(s.id), str(s.get("name", ""))])
		var free: Array = VPL.free_revive_skills(a)
		_revive[key] = {"free": names.call(free), "bound": names.call(VPL.revive_skills(a).filter(func(s): return not free.has(s)))}
		if prev != null:
			XState._become_current(prev)
		else:
			XState.current = null
	return _revive[key]


static func can_revive(id: int, level := LEVEL) -> bool:
	return not revive_skill_names(id, level).is_empty()


## 队里会复活的人（报告用）：[{id, role, skills}]
static func revivers_in(team: Array) -> Array:
	var out := []
	for id in team:
		if can_revive(int(id)):
			out.append({"id": int(id), "role": role_of(int(id)), "skills": revive_skill_names(int(id))})
	return out


## 排序键：越大越强。输出看量数峰值，坦克、辅助看承伤厚度
static func rank_score(id: int, role: String) -> float:
	if role == "输出":
		return float(_peaks().get(str(id), {}).get("peak", 0))
	return bulk(id)


## 最强队：每个职责位在同档里挑最强的人。档位规则卡住时（比如艰险最多 2 强）：先按职责顺序贪心挑最强，
## 超出强者名额的位置改挑该职责里最强的弱者。配不出来返回 []。
static func strongest(template: String, difficulty: String) -> Array:
	var cand := candidates(difficulty)
	var want: Dictionary = TEMPLATES[template]
	var r := rule(difficulty)
	var weak_need := min_weak_field(difficulty)
	var ranked := {}
	for role in ROLE_ORDER:
		var list: Array = (cand[role] as Array).duplicate()
		list.sort_custom(func(x, y): return rank_score(int(x), role) > rank_score(int(y), role))
		if list.size() < int(want.get(role, 0)):
			return []
		if REVIVE_FIRST and role == "辅助":   # T328：会复活的辅助整体排前（贪心挑第一个辅助位时先试它们）；第二个辅助位起再按承伤排，见下
			var rv := list.filter(func(x): return can_revive(int(x)))
			ranked["辅助复活"] = rv
		ranked[role] = list
	# 贪心：按「职责顺序、每职责从强到弱」依次挑；放得下（挑完之后弱者数仍有办法 ≥ 下限、超强者 ≤ 上限）才要
	var team := []
	var slots := []
	for role in ROLE_ORDER:
		for _i in int(want.get(role, 0)):
			slots.append(role)
	for i in slots.size():
		var role: String = slots[i]
		var left := slots.size() - team.size() - 1  # 这一位之后还剩几个位置
		var picked := -1
		var order: Array = ranked[role]
		if role == "辅助" and ranked.has("辅助复活") and not team.any(func(x): return can_revive(int(x))):
			order = (ranked["辅助复活"] as Array) + order   # 队里还没有会复活的：先试会复活的辅助
		for id in order:
			if team.has(int(id)):
				continue
			var weak_now := team.filter(func(x): return XTianqiSkills.is_weak(int(x), true)).size() + (1 if XTianqiSkills.is_weak(int(id), true) else 0)
			var supers_now := team.filter(func(x): return XTianqiSkills.is_super(int(x), true)).size() + (1 if XTianqiSkills.is_super(int(id), true) else 0)
			if supers_now <= int(r.super_cap) and weak_now + left >= weak_need:
				picked = int(id)
				break
		if picked < 0:
			return []
		team.append(picked)
	return team if legal(team, difficulty) and matches(team, template) else []


static func strongest_all(difficulty: String) -> Dictionary:
	var out := {}
	for t in TEMPLATES:
		var team := strongest(t, difficulty)
		if not team.is_empty():
			out[t] = team
	return out


## 缺人／缺职责清单：{counts: {职责: {档位: 人数}}, balanced: 均衡人数, short: [模板…], no_peak: [输出里没有量数的 id], notes: [文字]}
static func report(difficulty: String) -> Dictionary:
	var cand := candidates(difficulty)
	var counts := {}
	for role in ROLE_ORDER:
		counts[role] = {}
		for id in cand[role]:
			var t := XTianqiSkills.tier_of(int(id), true)
			counts[role][t] = int(counts[role].get(t, 0)) + 1
	var pool: Dictionary = XTianqi.pool(difficulty)
	var balanced := []
	var unrole := []
	for tier in pool:
		for id in pool[tier]:
			var r := raw_role(int(id))
			if r == "均衡":
				balanced.append(int(id))
			elif not ROLE_ORDER.has(r):
				unrole.append(int(id))
	balanced.sort()
	var short := []
	for t in TEMPLATES:
		for role in TEMPLATES[t]:
			if (cand[role] as Array).size() < int(TEMPLATES[t][role]):
				short.append("%s 缺 %s" % [t, role])
		if strongest(t, difficulty).is_empty():
			short.append("%s 配不出最强队" % t)
	var no_peak := []
	for id in cand["输出"]:
		if not _peaks().has(str(id)):
			no_peak.append(int(id))
	var notes := []
	if not balanced.is_empty():
		notes.append("%d 人职责是「均衡」，%s：%s（要 Kyo 定：均衡算哪个职责）" % [balanced.size(), "先并入输出池" if BALANCED_AS_OUTPUT else "不入队", str(balanced)])
	if not unrole.is_empty():
		notes.append("职责表里没有这些角色（候选池里有）：%s" % str(unrole))
	if not no_peak.is_empty():
		notes.append("这些输出没有甲档量数，最强队排序排最后：%s" % str(no_peak))
	# T328：会复活的名单（全职责都列，辅助位只用辅助里的），各模板最强队里谁带复活
	var revivers := {}
	var item_bound := {}   # 复活技要特殊道具（不算会复活）
	for role in ROLE_ORDER:
		for id in cand[role]:
			if can_revive(int(id)):
				revivers[str(id)] = {"role": role, "skills": revive_skill_names(int(id))}
			elif not revive_item_bound(int(id)).is_empty():
				item_bound[str(id)] = {"role": role, "skills": revive_item_bound(int(id))}
	var team_revive := {}
	for t in TEMPLATES:
		var team := strongest(t, difficulty)
		team_revive[t] = revivers_in(team)
		if not team.is_empty() and team_revive[t].is_empty():
			notes.append("%s 最强队没有会复活的人（%s），靠复活道具" % [t, "模板没有辅助位" if not TEMPLATES[t].has("辅助") else "本档辅助里没有会复活的"])
	return {"counts": counts, "balanced": balanced, "short": short, "no_peak": no_peak, "unrole": unrole, "notes": notes,
		"revivers": revivers, "revive_item_bound": item_bound, "team_revive": team_revive}
