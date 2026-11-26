extends Node
## 守层者基准伤害（法宝与积分重构 v0.2 第五节，cc 11-13）：弱阵容基准队对每层守层者每回合打多少。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑：
##   godot --headless --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- [--out=<json>] [--floors=1-33] [--teams=8] [--turns=8] [--difficulty=jianxian]
##
## 基准队（每层重新建）：
## - 天启篇存档（难度默认艰险，五档敌人防御一样、只差血量与攻击，所以伤害量一次就够）；弱者 4 人上场，从本难度候选池的弱者里按种子抽 teams 队；
## - 等级＝这一层的等级上限（原版守层者打赢后 maxlevel equal 的那张表：1～4 层 10、5 层 15……30 层 75）；
## - 装备＝每个栏位从「这一层能穿上的（需求等级 ≤ 等级上限）、精良及以下品质、不是专属」里挑主属性最高的一件（--no-gear 只留开局自带，
##   --quality=N 放宽品质）＋一件法宝，等级＝这一层的法宝上限 min(99, 9＋3×层)：兑换大厅有本人专属法宝就穿专属的，
##   没有就穿通用的「破攻」（物攻 +20／级）或「尊魔」（魔攻 +20／级），看本人物攻、魔攻哪个高；
## - 不算真气、宝珠、种族、技能书这些养成（「最弱的正常玩家」口径）。
## 敌人：这一层守层者那场敌群（不是神话），血量用真值、每回合开始补满（状态不动），自动战斗打 turns 回合，量我方每次行动让敌方掉的血（敌人回血不抵扣，
## 回合末的持续伤害不算），按回合平均；
## 我方全灭或敌人被打死就按打了几回合算（打死那回合按掉的血算，偏低，表里记 won）。
## 输出：每层各队伍的每回合伤害、中位数、我方全灭的队伍数，以及按目标回合（寻常 6／艰险 8／九死 10／炼狱 12／证道 15）乘出来的血量。

const LEVEL_CAP := [[1, 10], [5, 15], [6, 20], [8, 25], [10, 30], [12, 33], [13, 35], [14, 38], [15, 40], [16, 43], [17, 45],
	[18, 48], [19, 50], [21, 55], [23, 60], [25, 65], [29, 75], [31, 80], [36, 81]]
## 每层守层者那场的敌群号（地图事件里「战斗后变量 20 加一」的那一场；5 层取群狼森林、7 层取科维努斯镇）
const GUARDIAN := {1: 4, 2: 5, 3: 8, 4: 22, 5: 28, 6: 39, 7: 52, 8: 53, 9: 67, 10: 69, 11: 109, 12: 110, 13: 111, 14: 118, 15: 138,
	16: 172, 17: 173, 18: 174, 19: 333, 20: 456, 21: 457, 22: 458, 23: 459, 24: 460, 25: 461, 26: 462, 27: 463, 28: 464, 29: 465,
	30: 466, 31: 467, 32: 468, 33: 469}
const TARGET_TURNS := {"xunchang": 6, "jianxian": 8, "jiusi": 10, "lianyu": 12, "zhengdao": 15}
const GENERAL_ATK := 3557   # 破攻
const GENERAL_MAT := 3556   # 尊魔

var floors: Array = range(1, 34)
var teams := 8
var turns := 8
var difficulty := "jianxian"
var out_path := ""
var seed := 20261113
var no_fabao := false
var gear := true
var debug := false
var keep_trace := false
var atk_search := false
var atk_target := 10.0   # --atk-search：找让基准队中位数撑到这么多回合团灭的攻击倍率
var atk_scale := 1.0
var iters := 7
var atk_table := {}   # --atk-table=<json>：{"层": 攻击倍率}，--both 时按层设 output_scale
var _cur_floor := 0
var line := "war"   # --line=：35、36 层（天启篇影子、骑士本体）按哪条线
var force_difficulty := ""   # T392：--force-difficulty=<难度键>：快照存档的天启篇难度换成这一档（只改敌人强度：血量倍率、目标回合、吸血封顶；随机阵容仍按 --difficulty 的规则抽）
var snapshots := ""   # --snapshots=<目录>：虚拟玩家每层挑战守层者前的存档（floor_<层>*.json，XState.to_dict()），用它的真实队伍量（Kyo 11-13 定 C）
var raw_mode := true   # T239：--both 每次我方出手前补满敌人、按日志原始伤害量；敌人被打死当场复活补满、不提前收场，量满 turns 回合（T239 核 P1-1）
                      # （--no-raw 完整回到旧量法：每回合开头补满、按掉血量、打死就收场、输出不写 dmgRaw）
var both := false   # --both：两边每回合都补满（我方倒下的复活），同时量我方每回合打多少、守层者每回合打多少、我方每次出手打多少
var neutral := false   # --neutral：守层者元素抗性一律按 1 量
var resist := -1.0   # --resist=N：守层者伤害抵抗换成 N（0＝去掉）；-1 照数据
var duel := false   # --duel：不补血、打到分出胜负或 turns 回合，量真实回合数（去全队 ×6 开关对照，cc/tianqi-no-x6）
var events := false   # --events（配 --duel）：照游戏跑敌群事件（开场领域、轮回困难、残血页等），量「真打能不能过」（T229）
var max_quality := 3   # UnifiedQuality：0、1 普通，2 优秀，3 精良，4 史诗
var skipped_ids: Array = []
## T162（Kyo 11-18）：--shape=tb 用配队器（tests/virtual_player/team_builder.gd）的职责模板 A～D 随机队，--teams 是每个模板几队。
## T162（协调 11-18）：--shape=3s1w（3 强＋1 弱）／2s2w（2 强＋2 弱，艰险合法最大强者数）：队伍按层等级、按掉落表掷 sets 套取中位的装备（c_tier.floor_gears）、
## 本人法宝、输出职责烙印 75%、天平酒——和丙档、U 同口径；缺省 4w＝原来的弱者 4 人白装基准队。
const CT := preload("res://tests/virtual_player/c_tier.gd")
## T239（T328 合入后）：--revive-team 给存档队伍换上一名会复活的辅助（规则同 revive_compare：冷板凳上已会复活的辅助先，没有再从候选池按队伍等级挑；
## 换下换完仍合法、本层实测出伤最低的那个〔第 5 轮改：先用原队在本层按 --both 量各人出伤；出伤第一的不换，有断言〕，装备卸下后按游戏「最强装备」重配），并用虚拟玩家出手层（VPLogic：有人倒下先复活）打
const VPLogic := preload("res://tests/virtual_player/vp_battle_logic.gd")
var revive_team := false
## T239 第 6 轮（D248 甲′）：--lineups=N 每份存档除原队外再随机抽 N-1 支合法上场 4 人（助力位不动，装备卸下按「最强装备」重配）；
## --rng-seeds=a,b 每支队按这几个战斗随机种子各打一遍；--add-healer 另加一支「奶妈队」（原队按 --revive-team 规则换上会复活的辅助，单列不进表）。
## 这三个任一开着，出手一律用 VPLogic（同虚拟玩家：有人倒下先复活）。
var lineups := 1
var rng_seeds: Array = []
var add_healer := false
## T244：--all-weak 随机阵容只抽 4 个弱者（4 弱者／真·无名者之路量数；原队不是全弱者时照旧量、结果里 allWeak=false）
var all_weak := false
## T244：--troop=N 量数／真打时把守层者那场换成敌群 N（如 1 层副本首领嘤孙 422）；0＝照层号取守层者
var troop_override := 0
## T244：--weak-assist=出伤%,承伤% 把 4 弱全队协力换成这两个整数百分比（4 人合计，如 33,-22＝九死档补偿），只改内存里的表、不写文件
var weak_assist := ""
## T456：--equip=armor:2617[,weapon:123] 给每支参战队伍额外穿上的装备（缺省前缀按 armor）；优先穿在第一位能穿的出战成员对应栏位
var extra_equips: Array = []
var shape := "4w"
var templates: Array = ["A", "B", "C", "D"]   # --shape=tb 时的职责模板
var sets := 20
var battles := 10
var brand_pct := 75.0
var _gears := {}   # 队伍键 → {层: gear}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--teams="):
			teams = int(a.substr(8))
		elif a.begins_with("--turns="):
			turns = int(a.substr(8))
		elif a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a.begins_with("--iters="):
			iters = int(a.substr(8))
		elif a.begins_with("--atk-table="):
			atk_table = JSON.parse_string(FileAccess.get_file_as_string(a.substr(12)))
		elif a == "--neutral":
			neutral = true
		elif a.begins_with("--line="):
			line = a.substr(7)
		elif a.begins_with("--force-difficulty="):
			force_difficulty = a.substr(19)
			if not XTianqiBalance.difficulty_keys().has(force_difficulty):
				push_error("--force-difficulty 不认识：" + force_difficulty)
				get_tree().quit(2)
				return
		elif a.begins_with("--snapshots="):
			snapshots = a.substr(12)   # 缺省按 --both 量；配 --duel 时真打（T239）
		elif a == "--revive-team":
			revive_team = true
		elif a.begins_with("--lineups="):
			lineups = int(a.substr(10))
		elif a.begins_with("--rng-seeds="):
			rng_seeds = Array(a.substr(12).split(",")).map(func(x): return int(x))
		elif a.begins_with("--seg-alien="):
			var v := a.substr(12)   # T363：off＝按段异化不出（XTianqiSegAlien.ENABLED=false）；种类名（berserk 等）＝抽中的换成这一种
			if v == "off":
				XTianqiSegAlien.ENABLED = false
			else:
				XTianqiSegAlien.FORCE_KIND = v
		elif a == "--bomb-scale=off":
			XTianqiWarAlien.BOMB_SCALE = false   # T394：终焉烟火师轰炸回到修前（不乘出伤倍率、系数 1.5）
		elif a.begins_with("--bomb-coef="):
			XTianqiWarAlien.kind_info("pyro")["finale_bomb"] = float(a.substr(12))   # T394：轰炸系数换成这个数，只改内存里的表
		elif a.begins_with("--hp-pct="):
			var hp := a.substr(9).split(":")   # T406：层:整数%，只改内存里的 guardian_phase4.hp_pct；off＝HP_PCT 关
			if hp[0] == "off":
				XGuardianRework.HP_PCT = false
			else:
				var gp: Dictionary = XTianqiBalance.data().get("guardian_phase4", {})
				if not gp.get("hp_pct") is Dictionary:
					gp["hp_pct"] = {}
				gp["hp_pct"][hp[0]] = int(hp[1])
		elif a == "--focus=off":
			XGuardianRework.FOCUS = false   # T406：守层者集火招不单独乘倍率（照 atk_scale），拆败因用
		elif a == "--bomb-pct=off":
			XTianqiWarAlien.BOMB_PCT = false   # T407：轰炸回到 T394 按攻击算的口径
		elif a.begins_with("--bomb-pct="):
			XTianqiWarAlien.kind_info("pyro")["finale_bomb_pct"] = int(a.substr(11))   # T407：轰炸百分比换成这个整数，只改内存里的表
		elif a == "--add-healer":
			add_healer = true
		elif a == "--all-weak":
			all_weak = true
		elif a.begins_with("--troop="):
			troop_override = int(a.substr(8))
		elif a.begins_with("--weak-assist="):
			weak_assist = a.substr(14)
		elif a == "--no-raw":
			raw_mode = false
		elif a == "--duel":
			duel = true
		elif a == "--events":
			events = true
		elif a == "--x6=off":
			XTianqiNoX6.ENABLED = false   # 回到全队 ×6 与原血量（O-470 关）
		elif a == "--ledger=off":
			XTianqiLedger.set_all_p2(false)   # 伤害加成总账期二归池清场全关（回到期一的单独相乘），开关对照用
		elif a == "--guardian-heal=off":
			XTianqiNoX6.GUARDIAN_HEAL = false   # 守层者回血只缩 1/6、不乘重算缩放比（O-469 关）
		elif a == "--dot-pct=off":
			XGuardianRework.DOT_PCT = false   # T402：守层者按层单列的持续伤害比例关（22 层毒回到 T080 换算），前后对照用
		elif a == "--boss-neg-hrg-cap=off":
			XTianqiCombat.BOSS_NEG_HRG_CAP = false   # T405（D273）：守层者／首领回合末负 HP 再生封顶关，前后对照用
		elif a.begins_with("--equip="):
			for tok in a.substr(8).split(","):   # T456：额外装备（如 --equip=2617 或 --equip=armor:2617,weapon:123）
				var s_tok := tok.strip_edges()
				if s_tok == "":
					continue
				if s_tok.contains(":"):
					var kv := s_tok.split(":")
					extra_equips.append({"kind": kv[0].strip_edges(), "id": int(kv[1])})
				else:
					extra_equips.append({"kind": "armor", "id": int(s_tok)})
		elif a == "--both":
			both = true
		elif a.begins_with("--resist="):
			resist = float(a.substr(9))
		elif a == "--atk-search":
			atk_search = true
		elif a.begins_with("--atk-target="):
			atk_target = float(a.substr(13))
		elif a == "--debug":
			debug = true
		elif a == "--keep-trace":
			keep_trace = true
		elif a == "--no-gear":
			gear = false
		elif a.begins_with("--quality="):
			max_quality = int(a.substr(10))
		elif a == "--no-fabao":
			no_fabao = true
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--shape="):
			shape = a.substr(8)
		elif a.begins_with("--templates="):
			templates = Array(a.substr(12).split(","))
		elif a.begins_with("--sets="):
			sets = int(a.substr(7))
		elif a.begins_with("--battles="):
			battles = int(a.substr(10))
		elif a.begins_with("--brand="):
			brand_pct = float(a.substr(8))
		elif a.begins_with("--floors="):
			if a.contains(","):
				floors = Array(a.substr(9).split(",")).map(func(x): return int(x))
			else:
				var p := a.substr(9).split("-")
				floors = range(int(p[0]), int(p[p.size() - 1]) + 1)
	if weak_assist != "":
		var wp := weak_assist.split(",")
		var wa: Dictionary = XTianqiBalance.data().get("weak_assist", {})
		wa["damage_dealt_per"] = float(int(wp[0])) / 100.0 / float(XTianqiBalance.FIELD_SIZE)
		wa["damage_taken_per"] = float(int(wp[1])) / 100.0 / float(XTianqiBalance.FIELD_SIZE) if wp.size() > 1 else float(wa.get("damage_taken_per", 0.0))
		print("WEAK_ASSIST 4 弱合计 出伤 %+d%% 承伤 %+d%%" % [roundi(float(wa.damage_dealt_per) * 400.0), roundi(float(wa.damage_taken_per) * 400.0)])
	_run.call_deferred()


static func level_cap(f: int) -> int:
	var cap := 10
	for row in LEVEL_CAP:
		if f >= int(row[0]):
			cap = int(row[1])
	return cap


static func fabao_cap(f: int) -> int:
	return mini(99, 9 + 3 * maxi(1, f))


## 兑换大厅有卖、备注 <req_actors> 含本人的法宝
static var _own := {}
static func own_fabao(actor_id: int) -> int:
	if _own.is_empty():
		for r in XDB.table("Armors"):
			if r is Dictionary and r.get("meta", {}).has("Magic Weapon") and r.meta.has("req_actors"):
				for x in str(r.meta.req_actors).split(","):
					if str(x).strip_edges().is_valid_int():
						var aid := int(str(x).strip_edges())
						if not _own.has(aid):
							_own[aid] = int(r.id)
		_own[-1] = 0
	return int(_own.get(actor_id, 0))


func _teams() -> Array:
	if shape == "tb":   # 配队器：每个职责模板 teams 支合理随机队（缺省 A～D 四个模板），汇总取各队中位
		var out := []
		for tpl in templates:
			out.append_array(CT.TB.random_teams(tpl, teams, seed, difficulty))
		return out
	if shape != "4w":
		var sn := int(shape.substr(0, 1))
		return CT.pick_teams(teams, seed, sn, 4 - sn)
	var weak: Array = XTianqi.pool(difficulty)[XTier.WEAK].duplicate()
	weak.sort()
	# 上不了场的不要（如 156：建了队也不进出战成员）
	weak = weak.filter(func(id):
		var t := XState.new_game(XTianqi.legacy_of(difficulty), int(id), [])
		return t.battle_members().map(func(x): return int(x.actor_id)).has(int(id)))
	skipped_ids = XTianqi.pool(difficulty)[XTier.WEAK].filter(func(id): return not weak.has(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := []
	for t in teams:
		var pick := []
		var bag := weak.duplicate()
		for i in 4:
			pick.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
		out.append(pick)
	return out


func _shape_state(team: Array, f: int) -> XState:
	var key := ",".join(team.map(func(x): return str(x)))
	if not _gears.has(key):
		_gears[key] = CT.floor_gears(team, floors, sets, battles, seed, func(x): return level_cap(int(x)), difficulty)
	var s := CT.build_state(team, _gears[key][f], f, level_cap(f), fabao_cap(f), seed, brand_pct, true, difficulty)
	s.set_variable(20, f)
	return s


func _state(team: Array, f: int) -> XState:
	if shape != "4w":
		return _shape_state(team, f)
	var s := XState.new_game(XTianqi.legacy_of(difficulty), int(team[0]), team.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": difficulty, "lineup": team.duplicate()}
	s.random_master = XRandomStream.hex64(seed + f)
	s.orb_seed = seed * 1000 + f   # 装备孔、底子等按存档种子派生；新档是现开的随机数，不定住同一设置两遍穿的装备就不同
	seed(seed * 1000 + f)   # 全局随机也定住（兜底；cc/tianqi-no-x6 返修：不定住时同一设置跑两遍 25/72 队不同）
	s.set_variable(20, f)
	s.actor_max_level = level_cap(f)
	for id in team:
		var a := s.actor(int(id))
		a.change_level_mv(level_cap(f))
		if gear:
			_dress(a)
		var fid := own_fabao(int(id))
		var how := "own"
		if fid == 0:
			fid = GENERAL_ATK if a.param(2) >= a.param(4) else GENERAL_MAT
			how = "general"
		var item := XGear.template("armor", fid)
		item.level = float(mini(fabao_cap(f), int(XMagicWeapon.max_level(item))))
		item.exp = 0.0
		var slot := a.equip_slots().find(int(item.etypeId))
		if slot >= 0 and not no_fabao:
			a.equips[slot] = item
		a.set_meta("baseline_fabao", [fid, how, int(item.level)])
		a.refresh_passive()
		a.recover_all()
	return s


## 栏位逐个挑：武器看物攻、魔攻里高的那项（按本人物攻、魔攻哪个高），防具看四项之和；法宝栏另外处理
static var _pool := {}
func _dress(a: XActor) -> void:
	var slots := a.equip_slots()
	var physical := a.param(2) >= a.param(4)
	for i in slots.size():
		var et := int(slots[i])
		if et == 13:
			continue
		var best := {}
		var best_score := -1.0
		for rec in _candidates(et):
			var item := XGear.template("weapon" if et == 1 else "armor", int(rec.id))
			if not a.can_equip(item):
				continue
			var p: Array = rec.params
			var score := float(p[2] if physical else p[4]) if et == 1 else float(p[2]) + float(p[3]) + float(p[4]) + float(p[5]) + float(p[0]) / 10.0
			if score > best_score:
				best_score = score
				best = item
		if not best.is_empty():
			a.equips[i] = best


func _candidates(et: int) -> Array:
	var key := "%d:%d" % [et, max_quality]
	if not _pool.has(key):
		var out := []
		for rec in XDB.table("Weapons" if et == 1 else "Armors"):
			if not rec is Dictionary or str(rec.get("name", "")) == "" or (et != 1 and int(rec.get("etypeId", 0)) != et):
				continue
			var m: Dictionary = rec.get("meta", {})
			if m.has("Magic Weapon") or m.has("req_actors") or not str(m.get("quality", "0")).strip_edges().is_valid_int():
				continue
			if int(str(m.get("quality", "0")).strip_edges()) > max_quality:
				continue
			out.append(rec)
		_pool[key] = out
	return _pool[key]


## 敌方现存血量（死了按 0）
static func _enemy_hp(logic: XBattleLogic) -> float:
	var t := 0.0
	for e in logic.enemies:
		t += maxf(0.0, float(e.hp)) if e.is_alive() else 0.0
	return t


func _use_vp() -> bool:
	return revive_team or lineups > 1 or add_healer or not rng_seeds.is_empty()


## T456：给当前状态出战成员穿上 --equip 指定的装备（使用 template 避免随机词缀波动）；返回穿戴记录
func _apply_extra_equips(s: XState) -> Array:
	if extra_equips.is_empty():
		return []
	var applied := []
	var members: Array = s.battle_members()
	for spec in extra_equips:
		var kind := str(spec.kind)
		var gid := int(spec.id)
		var item := XGear.template(kind, gid)
		if item.is_empty():
			push_warning("--equip 未找到装备：%s:%d" % [kind, gid])
			continue
		var target_actor: XActor = null
		var target_slot := -1
		for a in members:
			if a.can_equip(item):
				var sl: int = a.equip_slots().find(int(item.etypeId))
				if sl >= 0:
					target_actor = a
					target_slot = sl
					break
		if target_actor == null:
			for a in members:
				var sl: int = a.equip_slots().find(int(item.etypeId))
				if sl >= 0:
					target_actor = a
					target_slot = sl
					break
		if target_actor != null and target_slot >= 0:
			target_actor.equips[target_slot] = item
			target_actor.refresh_passive()
			target_actor.recover_all()
			applied.append({"kind": kind, "id": gid, "name": str(item.get("name", "")), "actor": int(target_actor.actor_id), "slot": target_slot})
	return applied


func _fight(s: XState, troop: int) -> Dictionary:
	XTianqiWarAlien.BOMB_STATS_ON = true   # T407：记每下轰炸占血比
	XTianqiWarAlien.bomb_stats = []
	var applied_equips := _apply_extra_equips(s)
	var logic: XBattleLogic = VPLogic.new() if _use_vp() else XBattleLogic.new()
	logic.end_turn_audit = true   # T456：回合末掉血按来源拆账
	if s.has_meta("t239_rng"):
		seed(int(s.get_meta("t239_rng")))   # T239 第 6 轮：全局随机（VPLogic 选招等）也按这支队的种子定住
	var k_tab := float(atk_table.get(str(_cur_floor), atk_scale))   # T239 第 6 轮：--duel 也认 --atk-table（A 口径对照：只换出伤倍率、不设集火）
	XGuardianRework.measure_atk = k_tab if atk_table.has(str(_cur_floor)) or atk_scale != 1.0 else -1.0   # 守层者有不少固定伤害技能（如 771 固定 15000），只调能力值没用，整体乘出伤
	# 战斗随机流按本层种子给定：天启篇档回合内的随机取运行时主种子（R3 设计，读档可变），不给定同一设置跑两遍也对不上
	logic.setup(troop, s, XBattleRandom.create(str(s.random_master)) if duel else null)
	logic.auto = true
	if events:
		_drain(logic, logic.troop_events())
	var total := 0.0
	var end_total := 0.0
	var end_by_src := {}
	var end_by_state := {}
	var mhp_peak := 0.0
	var cap_pct_max := 0.0
	var done := 0
	var hp0 := 0.0
	var trace := []   # --duel：每次行动 [回合, 行动者, 技能, 目标, 敌方各人血量, 我方各人血量]，开关对照找首个分歧点
	for e in logic.enemies:
		hp0 += float(e.mhp) if e.is_alive() else 0.0
	mhp_peak = hp0
	for r in turns:
		# 每回合开始把敌人血量补满（不动状态），这一回合掉的血就是这一回合的伤害；血量用真值，按比例扣血的技能才不失真
		for e in logic.enemies:
			if e.is_alive() and not duel:
				e.hp = e.mhp
		var turn_dmg := 0.0
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		var turn_first := true
		while count < 80:
			var u := logic.next_subject()
			if events:
				_drain(logic, logic.troop_events(u if turn_first else null))
				turn_first = false
				if logic.is_over():
					break
			if u == null:
				break
			count += 1
			var cmd := [null, null] if events and logic.take_cleared(u) else logic.decide(u)   # T239（T229 核 P3-1）：首位被强制行动清掉的那格放弃，同战斗画面
			var hp_before := _enemy_hp(logic)
			var logs = logic.act(u, cmd[0], cmd[1])
			if u is XActor:
				turn_dmg += maxf(0.0, hp_before - _enemy_hp(logic))
			if duel:
				trace.append([r, logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, logic.stable_id(cmd[1]) if cmd[1] is XBattler else str(cmd[1]),
					logic.enemies.map(func(e): return int(e.hp)), logic.actors.map(func(a): return int(a.hp))])
			if debug:
				print("DBG t%d %s skill=%s enemyHp=%s logs=%s" % [r, logic.stable_id(u), str(int(cmd[0].id)) if cmd[0] != null else "-",
					str(logic.enemies.map(func(e): return int(e.hp))), JSON.stringify(logs).left(300)])
		if not logic.is_over():
			var cur_mhp := 0.0
			for e in logic.enemies:
				if e.is_alive():
					cur_mhp += float(e.mhp)
			mhp_peak = maxf(mhp_peak, cur_mhp)
			var hp_before_end := _enemy_hp(logic)
			logic.end_turn()
			end_total += maxf(0.0, hp_before_end - _enemy_hp(logic))
			var cap_turn := maxf(0.0, float(logic.end_turn_sources.get("extdot", 0.0))) + maxf(0.0, float(logic.end_turn_sources.get("regen", 0.0)))
			if cur_mhp > 0.0:
				cap_pct_max = maxf(cap_pct_max, cap_turn / cur_mhp * 100.0)
			for k in logic.end_turn_sources:
				end_by_src[k] = float(end_by_src.get(k, 0.0)) + float(logic.end_turn_sources[k])
			for k in logic.end_turn_states:
				end_by_state[k] = float(end_by_state.get(k, 0.0)) + float(logic.end_turn_states[k])
			if events:
				_drain(logic, logic.troop_events(null, true))   # T239（T229 核 P3-1）：回合末的敌群事件页（残血变身、阶段页等），同战斗画面
		total += turn_dmg
		done += 1
		if logic.is_over():
			break
	var alive := logic.actors.filter(func(a): return a.hp > 0).size()
	var d_n := maxf(1.0, float(done))
	var end_src_avg := {}
	for k in end_by_src:
		end_src_avg[k] = float(end_by_src[k]) / d_n
	var end_state_avg := {}
	for k in end_by_state:
		end_state_avg[k] = float(end_by_state[k]) / d_n
	var out := {"trace": trace, "atkScale": _out_scale(logic), "alien": _alien_desc(logic), "dmg": total / d_n, "endTurnDmg": end_total / d_n,
		"endTurnBySource": end_src_avg, "endTurnStates": end_state_avg, "enemyMhpPeak": mhp_peak, "endTurnCapPctMax": cap_pct_max, "turns": done, "alive": alive, "won": logic.is_won(), "lost": logic.is_lost(),
		"aborted": logic.aborted, "enemyHp": hp0, "enemyAtk": logic.enemies.map(func(e): return int(e.param(2))), "enemyDef": logic.enemies.map(func(e): return [int(e.param(3)), int(e.param(5))]),
		"partyAtk": logic.actors.map(func(a): return [int(a.param(2)), int(a.param(4))]),
		"party": logic.actors.map(func(a): return int(a.actor_id)), "members": s.battle_members().map(func(a): return int(a.actor_id)),
		"allWeak": s.battle_members().all(func(a): return XTianqiSkills.is_weak(int(a.actor_id), true)), "partyHp": logic.actors.map(func(a): return int(a.mhp)),
		"bomb": XTianqiWarAlien.bomb_stats.duplicate()}   # T407：这场每下轰炸占血比（每人每下一笔）
	if not applied_equips.is_empty():
		out["extraEquips"] = applied_equips
	return out


## 撑到第几回合团灭（没团灭记 turns＋1）
func _survive(r: Dictionary) -> float:
	return float(r.turns) if bool(r.lost) else float(turns + 1)


static func _median(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return (float(b[(b.size() - 1) / 2]) + float(b[b.size() / 2])) / 2.0


func _measure(list: Array, f: int) -> Dictionary:
	var per := []
	for team in list:
		per.append(_fight(_state(team, f), int(GUARDIAN[f])))
	return {"survive": _median(per.map(func(r): return _survive(r))), "dmg": _median(per.map(func(r): return float(r.dmg))), "per": per}


## 每层按对数二分找攻击倍率：中位数撑到 atk_target 回合左右团灭；倍率上限 4（前几层原版就偏弱时可以加）
func _search(list: Array) -> void:
	XEnemy.force_roll = 100.0
	turns = int(atk_target) + 4
	var rows := []
	for f in floors:
		var lo := log(1.0e-5)
		var hi := log(8.0)
		var best := {}
		var best_k := 1.0
		for it in iters:
			var mid := (lo + hi) / 2.0
			atk_scale = exp(mid)
			var m := _measure(list, f)
			if best.is_empty() or absf(float(m.survive) - atk_target) <= absf(float(best.survive) - atk_target):
				best = m
				best_k = atk_scale
			if float(m.survive) < atk_target:
				hi = mid   # 死得太快：降攻击
			else:
				lo = mid
		atk_scale = 1.0
		rows.append({"floor": f, "level": level_cap(f), "fabao": fabao_cap(f), "atkScale": best_k, "survive": best.survive, "median": best.dmg,
			"teams": best.per.map(func(r): return {"dmg": r.dmg, "turns": r.turns, "lost": r.lost, "partyHp": r.partyHp, "enemyAtk": r.enemyAtk})})
		print("ATKSEARCH floor=%d atk_scale=%.5f survive=%.1f median=%.0f" % [f, best_k, float(best.survive), float(best.dmg)])
	XEnemy.force_roll = -1.0
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"mode": "atk-search", "target": atk_target, "turns": turns, "teams": list, "rows": rows}, "\t"))
	print("BASELINE_DONE")
	get_tree().quit(0)


func _run() -> void:
	XEnemy.force_roll = 100.0   # 守层者不按神话
	var list := _teams()
	var rows := []
	XGuardianRework.measure_resist = resist
	XGuardianRework.measure_neutral = neutral
	if atk_search:
		_search(list)
		return
	if both or (snapshots != "" and not duel):
		_run_both(list)
		return
	if snapshots != "":
		_run_duel_snapshots()
		return
	for f in floors:
		var per := []
		for team in list:
			var s := _state(team, f)
			var r := _fight(s, int(GUARDIAN[f]))
			r["team"] = team
			r["fabao"] = team.map(func(id): return s.actor(int(id)).get_meta("baseline_fabao"))
			r["equips"] = team.map(func(id): return s.actor(int(id)).equips.map(func(e): return str(e.get("name", "")) if e is Dictionary else ""))
			per.append(r)
		var dmg: Array = per.map(func(r): return float(r.dmg))
		dmg.sort()
		var median: float = (dmg[(dmg.size() - 1) / 2] + dmg[dmg.size() / 2]) / 2.0
		var hp := {}
		for k in TARGET_TURNS:
			hp[k] = median * float(TARGET_TURNS[k])
		var wiped := per.filter(func(r): return int(r.alive) == 0).size()
		rows.append({"floor": f, "troop": GUARDIAN[f], "level": level_cap(f), "fabao": fabao_cap(f), "median": median,
			"min": dmg[0], "max": dmg[-1], "wiped": wiped, "hp": hp, "teams": per})
		var won: Array = per.filter(func(r): return bool(r.won))
		var won_turns: Array = won.map(func(r): return float(r.turns))
		rows[-1]["won"] = won.size()
		rows[-1]["wonTurnsMedian"] = _median(won_turns) if not won_turns.is_empty() else -1.0
		rows[-1]["enemyHp"] = _median(per.map(func(r): return float(r.enemyHp)))
		print("BASELINE floor=%d level=%d fabao=%d median=%.0f min=%.0f max=%.0f wiped=%d/%d won=%d wonTurns=%.1f enemyHp=%.0f" % [f, level_cap(f), fabao_cap(f), median, dmg[0], dmg[-1], wiped, per.size(),
			won.size(), float(rows[-1].wonTurnsMedian), float(rows[-1].enemyHp)])
	XEnemy.force_roll = -1.0
	var out := {"gear": gear, "maxQuality": max_quality, "skippedActors": skipped_ids, "noFabao": no_fabao, "difficulty": difficulty, "teams": list, "turns": turns, "seed": seed, "rows": rows}
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify(out, "\t"))
	print("BASELINE_DONE")
	get_tree().quit(0)


static func _party_hp(logic: XBattleLogic) -> float:
	var t := 0.0
	for a in logic.actors:
		t += maxf(0.0, float(a.hp))
	return t


## --both：两边每回合开始补满（我方倒下的先复活），量我方每回合伤害、守层者每回合对我方伤害、我方每次出手的伤害
## 34～36 层（天启篇重做）：34 鸿钧（鸿蒙老祖那场换能力值）、35 本线影子、36 本线骑士本体；之前的层照守层者敌群
func _troop_for(s: XState, f: int) -> int:
	if troop_override > 0:
		return troop_override
	if f <= 33:
		return int(GUARDIAN[f])
	s.flags.tianqi["line"] = line
	if f == 34:
		XTianqiSummit.prepare_hongjun(s)
		return int(XTianqiSummit.data().hongjun.troop)
	XTianqiHorsemen.prepare(line, s, "shadow" if f == 35 else "body")
	return int(XTianqiLine.data(line).shell_troop)


func _fight_both(s: XState, troop: int) -> Dictionary:
	_apply_extra_equips(s)
	var logic: XBattleLogic = VPLogic.new() if _use_vp() else XBattleLogic.new()
	XState._become_current(s)
	if troop <= 0:
		troop = _troop_for(s, _cur_floor)
	var k := float(atk_table.get(str(_cur_floor), atk_scale))
	XGuardianRework.measure_atk = k if atk_table.has(str(_cur_floor)) or atk_scale != 1.0 else -1.0   # 没给就照游戏里的表
	if s.has_meta("t239_rng"):
		seed(int(s.get_meta("t239_rng")))
	logic.setup(troop, s, XBattleRandom.create(str(s.random_master)) if s.has_meta("t239_rng") else null)   # T239 第 6 轮：按种子定住战斗随机流
	logic.auto = true
	_drain(logic, logic.troop_events())   # 开战的敌群事件（守层者开场强制技能：天道屠灭、大道领域、轮回困难等）
	var ours := 0.0
	var theirs := 0.0
	var dot := 0.0   # T239（核 P2-3）：回合末结算（持续伤害、按最大生命百分比的毒伤等，不吃出伤倍率）打我方的，单列不进 enemyDmg
	var raw := 0.0   # 守层者打出的伤害（扣血前、不截断；含反击）
	var raw_ours := 0.0
	var per_turn := []   # 每回合我方原始伤害（看破阵免疫回合打 0 的有几回合）
	var hits := []
	var by_actor := {}   # T239 第 5 轮：每人出伤合计（actor_id → 原始伤害，--no-raw 时按掉血量），--revive-team 换人按它挑
	var done := 0
	var revived := {}   # T239 r2：本回合被复活过的守层者 → 下一回合出手次数（断言：复活后下一回合必须出手）
	var silent := []   # 复活后下一回合一次没出手的 [回合, 敌人]
	var revive_turns := 0   # 有敌人被复活过的回合数
	# T239 第 6 轮（D248 甲′）：我方每回合回复，分开记。heal＝我方出手让队友（含自己，非攻击行动）回的血；steal＝攻击行动里出手者自己回的血（吸血、吸取）；
	# regen＝回合末结算回的血（再生等，也算治疗）；shield＝我方出手给我方加的护盾（原生护盾＋护盾账本）。都按实际回上的量（每回合开头补满，回满就截住）；
	# healTry＝治疗类命中记录的原值（不截断，看「奶得动多少」）。focus＝守层者每下打中我方一人占其最大生命的比例（集火口径）；atkHits＝我方普攻单下（每个目标一条）
	var heal := 0.0
	var steal := 0.0
	var regen := 0.0
	var shield := 0.0
	var heal_try := 0.0
	var focus := []
	var atk_hits := []
	var focus_excess := 0.0   # T363：集火招按表里倍率比统一倍率多打的（enemyDmgBase＝enemyDmg 扣掉它）
	var by_skill := {}   # T239 第 6 轮（D248 C）：守层者成员每招 {dmg 打我方掉血合计, uses 次数, ratios 每下占目标最大生命比例, scope}，挑集火招、摊预算用
	for r in turns:
		for e in logic.enemies:
			if e.is_alive():
				e.hp = e.mhp
		for a in logic.actors:
			if a.hp <= 0:
				a.remove_state(1)
				if raw_mode and not logic.next_order.has(a):
					logic.next_order.append(a)   # T239 r2（核 P1-1 附）：倒下时被清出下回合队列，复活后补回（排末位），不缺席
			a.hp = a.mhp
		var watch := revived
		if not watch.is_empty():
			revive_turns += 1
		revived = {}
		var acted := {}
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		var turn_first := true
		var turn_raw := 0.0
		while count < 80:
			var u := logic.next_subject()
			if u != null:
				acted[u] = true
			var pb0 := _party_hp(logic)
			var snap := _enemy_snap(logic) if raw_mode else {}
			_drain(logic, logic.troop_events(u if turn_first else null))
			theirs += maxf(0.0, pb0 - _party_hp(logic))   # 敌群事件里的伤害（强制技能）算守层者的
			turn_first = false
			if raw_mode:
				_revive_enemies(logic, snap, revived)
			if u == null or logic.is_over():
				break
			count += 1
			var cmd := [null, null] if logic.take_cleared(u) else logic.decide(u)   # T239（核 P3-2）：首位被强制行动清掉的那格放弃，同战斗画面
			var eb := _enemy_hp(logic)
			var pb := _party_hp(logic)
			var db: float = logic.enemies.reduce(func(t, e): return t + float(e.dealt), 0.0)
			if u is XActor and raw_mode:
				for e in logic.enemies:   # T239：每次我方出手前补满，一下打不满就不会被剩余血量截断
					if e.is_alive():
						e.hp = e.mhp
				eb = _enemy_hp(logic)
			var snap_act := _enemy_snap(logic) if raw_mode else {}
			var hp_m := _hp_map(logic)
			var sh_m := _shield_map(logic)
			var logs = logic.act(u, cmd[0], cmd[1])
			_tally_hits(u, cmd[0], logs, focus, atk_hits)
			if u is XActor:
				var g := _gains(logic, hp_m, sh_m)
				var offensive := _raw_hits(logs) > 0.0 or eb - _enemy_hp(logic) > 0.0
				for a in g.hp:
					if offensive and is_same(a, u):
						steal += float(g.hp[a])
					else:
						heal += float(g.hp[a])
				shield += float(g.shield)
				heal_try += _heal_try(logs)
			if u is XActor:
				var d := maxf(0.0, eb - _enemy_hp(logic))
				ours += d
				by_actor[int(u.actor_id)] = float(by_actor.get(int(u.actor_id), 0.0)) + (maxf(d, _raw_hits(logs)) if raw_mode else d)
				if raw_mode:
					# T239：出手前已补满，没打穿时掉血量 d 就是真伤害（含状态效果脚本里直接 gainHp 的附伤，这类日志里没有，25 层劫运神镖）；
					# 一下打穿全部血量（马氏双节棍等）时 d 被截断，日志原始伤害 rd（hpDamage 扣血前、不截断，含附加段）更大。两者取大
					var rd := maxf(d, _raw_hits(logs))
					if debug and d > _raw_hits(logs) + 1.0:
						print("DBGRAW t%d %s skill=%s d=%.0f logRaw=%.0f" % [r, logic.stable_id(u), str(int(cmd[0].id)) if cmd[0] != null else "-", d, _raw_hits(logs)])
					raw_ours += rd
					turn_raw += rd
					if rd > 0.0:
						hits.append(rd)
				else:
					turn_raw += d
					if d > 0.0:
						hits.append(d)   # --no-raw：旧量法，单下伤害按掉血量
			raw += float(logic.enemies.reduce(func(t, e): return t + float(e.dealt), 0.0)) - db
			if not u is XActor:
				theirs += maxf(0.0, pb - _party_hp(logic))
				if cmd[0] is Dictionary and _is_guardian(u):
					var sk := str(int(cmd[0].get("id", 0)))
					var rec: Dictionary = by_skill.get(sk, {"dmg": 0.0, "dmgAct": 0.0, "uses": 0, "ratios": [], "scope": int(cmd[0].get("scope", 0)), "type": int(cmd[0].get("damage", {}).get("type", 0)), "scale": 1.0})
					# T363（T239 核 P2-5）：只记 XDamage.finish 那条路打我方 HP 的（命中记录 hp＞0），不再把这一步里别的扣血（反伤、状态即时伤害、事件）算进这招，
					# 再按实际掉血封顶（过量伤害不算）。集火招在表里另有倍率时（量数不给 --atk-table、照游戏表打），按 skill_scale÷output_scale 折回统一倍率口径，
					# 三表工具拿它和别的招同一口径算；实际打的记 dmgAct
					var fin := 0.0
					var ks := float(u.skill_scale(cmd[0])) / maxf(1e-12, float(u.output_scale)) if u is XEnemy and float(u.output_scale) > 0.0 else 1.0
					for l in (logs if logs is Array else []):
						if l is Dictionary and str(l.get("type", "")) == "hit" and l.get("target") is XActor and float(l.get("hp", 0.0)) > 0.0 and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
							fin += float(l.hp)
							rec.ratios.append(float(l.hp) / maxf(1.0, float(l.target.mhp)) / ks)
					fin = minf(fin, maxf(0.0, pb - _party_hp(logic)))
					rec.dmg = float(rec.dmg) + fin / ks
					rec.dmgAct = float(rec.dmgAct) + fin
					rec.scale = ks
					focus_excess += fin - fin / ks
					rec.uses = int(rec.uses) + 1
					by_skill[sk] = rec
			if debug:
				print("DBG2 t%d %s skill=%s partyLoss=%.0f enemyLoss=%.0f" % [r, logic.stable_id(u), str(int(cmd[0].id)) if cmd[0] != null else "-", pb - _party_hp(logic), eb - _enemy_hp(logic)])
			if raw_mode:
				_revive_enemies(logic, snap_act, revived)   # T239（核 P1-1）：谁的行动（含反击、事件）打死了敌人都当场复活补满，不让一下秒杀提前收场
			if logic.is_over():
				break
		done += 1
		per_turn.append(turn_raw)
		for e in watch:
			if not acted.has(e):
				silent.append([r, logic.stable_id(e)])
				push_error("T239 断言：%s 上回合被复活，第 %d 回合一次没出手" % [logic.stable_id(e), r])
		if logic.is_won() or logic.aborted:
			break   # raw 模式敌人已复活、到这里只剩中止；--no-raw 照旧打死就收场
		if logic.is_lost():
			continue   # 一回合内团灭：下回合开头复活补满接着量
		var snap_end := _enemy_snap(logic) if raw_mode else {}
		var pb_end := _party_hp(logic)
		var hp_end := _hp_map(logic)
		logic.end_turn()
		dot += maxf(0.0, pb_end - _party_hp(logic))
		for a in _gains(logic, hp_end, _shield_map(logic)).hp.values():
			regen += float(a)
		var pb_ev := _party_hp(logic)
		_drain(logic, logic.troop_events(null, true))   # T239（核 P3-2）：回合末的敌群事件页，同战斗画面与 _fight
		theirs += maxf(0.0, pb_ev - _party_hp(logic))   # T239 r2（核 P3-4）：回合末敌群页打我方的算守层者的（先跑事件再复活）；回合末持续伤害不算（P2-3）
		if raw_mode:
			_revive_enemies(logic, snap_end, revived)   # 回合末持续伤害、事件打死的也复活
	hits.sort()
	var n := maxf(1.0, float(done))
	var out := {"dmg": ours / n, "perTurn": per_turn, "enemyDmg": theirs / n, "enemyDot": dot / n, "enemyRaw": raw / n, "turns": done, "won": logic.is_won(), "hitMedian": _median(hits) if not hits.is_empty() else 0.0,
		"hits": hits.size(), "byActor": by_actor, "partyHp": logic.actors.reduce(func(t, a): return t + float(a.mhp), 0.0),
		"enemyHp": logic.enemies.reduce(func(t, e): return t + float(e.mhp), 0.0),
		"heal": heal / n, "steal": steal / n, "regen": regen / n, "shield": shield / n, "healTry": heal_try / n,
		"focus": _median(focus) if not focus.is_empty() else 0.0, "focusHits": focus.size(),
		"bySkill": _skill_summary(by_skill, n),
		"atkHit": _median(atk_hits) if not atk_hits.is_empty() else 0.0, "atkHits": atk_hits.size(),
		"mhp": logic.actors.map(func(a): return int(a.mhp)), "team": str(s.get_meta("t239_team", "")), "rng": int(s.get_meta("t239_rng", 0)),
		"enemyDmgBase": (theirs - focus_excess) / n, "alien": _alien_desc(logic),
		"atkScale": _out_scale(logic)}   # T229：守层者这场实际用的出伤倍率（没给 --atk-table 时是游戏里的表）
	if raw_mode:
		out["dmgRaw"] = raw_ours / n   # --no-raw 不写，三表脚本退回 dmg（T239 核 P2-2）
		out["revivedSilent"] = silent   # 应为空：复活后下一回合没出手的守层者
		out["reviveTurns"] = revive_turns + (1 if not revived.is_empty() else 0)
	return out


## T363：这一场按段异化／本线预设异化出了什么（战争线：["敌人号:级:种类"]），看 34 层终焉战狂有没有上
static func _alien_desc(logic) -> Array:
	var out := []
	for e in XTianqiWarAlien.fight(logic).get("units", {}):
		var u: Dictionary = XTianqiWarAlien.fight(logic).units[e]
		out.append("%d:%s:%s" % [int(e.enemy_id), str(u.get("tier", "")), str(u.get("kind", ""))])
	return out


static func _is_guardian(e) -> bool:
	return e is XEnemy and (XGuardianRework.guardian_floor(e) > 0 or str(e.horseman.get("rec", {}).get("_ref", "")) != "")


## 每招按回合平均：dmg 每回合打我方、uses 每回合用几次、ratio 每下占目标最大生命中位、hits 命中条数
static func _skill_summary(by_skill: Dictionary, n: float) -> Dictionary:
	var out := {}
	for k in by_skill:
		var r: Dictionary = by_skill[k]
		var rs: Array = r.ratios
		out[k] = {"dmg": float(r.dmg) / n, "dmgAct": float(r.get("dmgAct", r.dmg)) / n, "scale": float(r.get("scale", 1.0)), "uses": float(r.uses) / n, "ratio": _median(rs) if not rs.is_empty() else 0.0, "ratioMax": rs.max() if not rs.is_empty() else 0.0,
			"hits": rs.size(), "scope": int(r.scope), "type": int(r.type),
			"useRatio": rs.reduce(func(t, x): return t + float(x), 0.0) / maxf(1.0, float(r.uses))}   # 一次出手合计打掉目标最大生命的比例（单体招＝打一人）
	return out


static func _hp_map(logic: XBattleLogic) -> Dictionary:
	var m := {}
	for a in logic.actors:
		m[a] = float(a.hp)
	return m


static func _shield_map(logic: XBattleLogic) -> Dictionary:
	var m := {}
	for a in logic.actors:
		m[a] = float(a.shield) + XShieldLedger.total(a)
	return m


## 一步前后我方各人回了多少血（只算涨的）、护盾合计涨了多少
static func _gains(logic: XBattleLogic, hp_m: Dictionary, sh_m: Dictionary) -> Dictionary:
	var hp := {}
	var sh := 0.0
	for a in logic.actors:
		var g := float(a.hp) - float(hp_m.get(a, a.hp))
		if g > 0.0:
			hp[a] = g
		sh += maxf(0.0, float(a.shield) + XShieldLedger.total(a) - float(sh_m.get(a, 0.0)))
	return {"hp": hp, "shield": sh}


## 治疗类命中记录（目标是我方、hp＜0）的原值合计
static func _heal_try(logs) -> float:
	var t := 0.0
	if logs is Array:
		for l in logs:
			if l is Dictionary and str(l.get("type", "")) == "hit" and l.get("target") is XActor and float(l.get("hp", 0.0)) < 0.0:
				t += -float(l.hp)
	return t


## 守层者出手：每下打中我方一人的伤害占其最大生命的比例（集火口径）；我方普攻：每个敌人一条单下伤害（主段＋附加段）
static func _tally_hits(u, skill, logs, focus: Array, atk_hits: Array) -> void:
	if not logs is Array or u == null:
		return
	var normal: bool = u is XActor and skill is Dictionary and int(skill.get("id", 0)) == int(u.attack_skill_id())
	for l in logs:
		if not (l is Dictionary and str(l.get("type", "")) == "hit") or bool(l.get("missed", false)) or bool(l.get("evaded", false)):
			continue
		var tgt = l.get("target")
		var v := float(l.get("hp", 0.0))
		if not u is XActor and tgt is XActor and v > 0.0 and float(tgt.mhp) > 0.0:
			focus.append(v / float(tgt.mhp))
		elif normal and tgt is XEnemy and v > 0.0:
			atk_hits.append(_raw_hits([l]))


## raw 模式复活用的快照（每个可能打死敌人的步骤之前拍）：活着的敌人的状态、状态回合、增减益，和本回合／下回合行动队列
static func _enemy_snap(logic: XBattleLogic) -> Dictionary:
	var per := {}
	for e in logic.enemies:
		if e.hidden or not e.is_alive():
			continue
		per[e] = {"ids": e.state_ids.duplicate(), "turns": e.state_turns.duplicate(true), "floors": e.state_floors.duplicate(true),
			"origins": e.state_origins.duplicate(true), "data": e.state_data.duplicate(true), "buffs": e.buffs.duplicate(), "buff_turns": e.buff_turns.duplicate()}
	return {"per": per, "cur": logic.current_order.duplicate(), "next": logic.next_order.duplicate()}


## raw 模式：死了的敌人（不含没登场的隐藏成员）复活、全员补满血。T239 r2（核 P1-1）：死亡会清掉非永久状态与增减益（Game_BattlerBase.die），
## 又被 _clear_unable 清出本回合、下回合行动队列——按快照还原这三样，不然复活的守层者之后几回合不出手、开场领域增益也没了。
## 队列按快照里的位置插回（不重掷行动次数、不动随机流）；没有快照的（快照时已死）只复活补满。
static func _revive_enemies(logic: XBattleLogic, snap := {}, revived := {}) -> void:
	var per: Dictionary = snap.get("per", {})
	for e in logic.enemies:
		if e.hidden:
			continue
		if e.is_dead():
			e.remove_state(1)
			if per.has(e):
				var k: Dictionary = per[e]
				e.state_ids.assign(k.ids)
				e.state_turns = k.turns.duplicate(true)
				e.state_floors = k.floors.duplicate(true)
				e.state_origins = k.origins.duplicate(true)
				e.state_data = k.data.duplicate(true)
				e.buffs.assign(k.buffs)
				e.buff_turns.assign(k.buff_turns)
				e.effect_lists.clear()
				e.effect_snapshot_valid = false
				e.param_mark_dirty()
				e.param_refresh()   # T239（核 P3-5）：还原增减益后重算能力值
				for key in ["cur", "next"]:
					var order: Array = logic.current_order if key == "cur" else logic.next_order
					var old: Array = snap.get(key, [])
					var missing := old.count(e) - order.count(e)
					var i := 0
					while missing > 0 and i < old.size():
						if is_same(old[i], e):
							order.insert(mini(i, order.size()), e)
							missing -= 1
						i += 1
			revived[e] = true
		e.hp = e.mhp


## 一次行动日志里我方打到敌人身上的原始伤害合计（type hit、目标是敌人、hp＞0）
static func _raw_hits(logs) -> float:
	var t := 0.0
	if not logs is Array:
		return t
	for l in logs:
		if l is Dictionary and str(l.get("type", "")) == "hit" and l.get("target") is XEnemy and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
			var main := maxf(0.0, float(l.get("hp", 0.0)))
			# T239（核 P2-1）：附加段不在 hp 里。r.extra 记轮回困难附伤、空间侵蚀、奈叶多段等；奈叶超出显示的尾段只记进 record_hp，
			# 两边取大（同一段两处都记的不重复算）
			var ex := 0.0
			var extra = l.get("extra", [])
			if extra is Array:
				for v in extra:
					if v is float or v is int:
						ex += maxf(0.0, float(v))
			t += main + maxf(ex, float(l.get("record_hp", 0.0)) - floorf(main))
	return t


## 守层者这场实际用的出伤倍率：先取守层者成员（guardian_floor＞0，含心魔、变身后；鸿钧等按鸿蒙老祖重标的认 _ref）的 output_scale 最大值，
## 没有守层者成员才取全场最大。T239（T229 核 P2-1）：原来取全场最大，5 层同场狼母（不是守层者，倍率 1）顶掉幽灵公主（0.00884），偏大百倍。
static func _out_scale(logic: XBattleLogic) -> float:
	var g := 0.0
	var any := 0.0
	for e in logic.enemies:
		any = maxf(any, float(e.output_scale))
		if XGuardianRework.guardian_floor(e) > 0 or str(e.horseman.get("rec", {}).get("_ref", "")) != "":
			g = maxf(g, float(e.output_scale))
	return g if g > 0.0 else any


func _run_both(list: Array) -> void:
	var rows := []
	for f in floors:
		var per := []
		_cur_floor = f
		var states: Array = _snapshot_states(f) if snapshots != "" else list.map(func(team): return _state(team, f))
		if states.is_empty():
			continue
		for st in states:
			var fr := _fight_both(st, 0)
			fr["swap"] = st.get_meta("t239_swap", {})
			fr["members"] = st.battle_members().map(func(a): return int(a.actor_id))
			per.append(fr)
		var row := {"floor": f, "level": level_cap(f), "fabao": fabao_cap(f), "atkScale": _median(per.map(func(r): return r.atkScale)),
			"heal": _median(per.map(func(r): return r.heal)), "steal": _median(per.map(func(r): return r.steal)), "regen": _median(per.map(func(r): return r.regen)),
			"shield": _median(per.map(func(r): return r.shield)), "focus": _median(per.map(func(r): return r.focus)), "atkHit": _median(per.map(func(r): return r.atkHit)),
			"dmg": _median(per.map(func(r): return r.dmg)), "enemyDmg": _median(per.map(func(r): return r.enemyDmg)), "enemyDot": _median(per.map(func(r): return float(r.get("enemyDot", 0.0)))), "enemyRaw": _median(per.map(func(r): return r.enemyRaw)),
			"hit": _median(per.map(func(r): return r.hitMedian)), "partyHp": _median(per.map(func(r): return r.partyHp)),
			"enemyHp": per[0].enemyHp, "teams": per}
		if raw_mode:
			row["dmgRaw"] = _median(per.map(func(r): return r.dmgRaw))
		rows.append(row)
		row["line"] = line if f >= 35 else ""
		print("BOTH line=%s floor=%d raw=%.0f dmgRaw=%.0f dmg=%.0f enemyDmg=%.0f hit=%.0f partyHp=%.0f enemyHp=%.0f" % [row.line, f, row.enemyRaw, float(row.get("dmgRaw", -1.0)), row.dmg, row.enemyDmg, row.hit, row.partyHp, row.enemyHp])
	XEnemy.force_roll = -1.0
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"mode": "both", "resist": resist, "turns": turns, "teams": list, "rows": rows}, "\t"))
	print("BASELINE_DONE")
	get_tree().quit(0)



## 这一层的快照（同一层可有多个种子）：floor_<层>.json、floor_<层>_<种子>.json
func _snapshot_bases(f: int) -> Array:
	var out := []
	var d := DirAccess.open(snapshots)
	if d == null:
		return out
	for name in d.get_files():
		if not name.ends_with(".json") or not (name == "floor_%d.json" % f or name.begins_with("floor_%d_" % f)):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(snapshots.path_join(name)))
		if not parsed is Dictionary:
			continue
		var st := XState.from_dict(parsed)
		st.set_variable(20, f)
		if force_difficulty != "" and st.flags.get("tianqi") is Dictionary:
			st.flags.tianqi["difficulty"] = force_difficulty
		if revive_team:
			XState._become_current(st)
			# T239 第 5 轮：先用原队在本层量一遍各人出伤（同 --both 量法、存档副本上打），换下的按实测出伤最低挑，主力不动
			var probe := _clone(st)
			for a in probe.battle_members():
				a.recover_all()
			var dmg_by: Dictionary = _fight_both(probe, 0).byActor
			XState._become_current(st)
			var sw := _swap_in_reviver(st, dmg_by)
			if sw.has("out"):
				var top := -1
				for id in dmg_by:
					if top < 0 or float(dmg_by[id]) > float(dmg_by[top]):
						top = int(id)
				sw["top"] = top
				sw["outDmg"] = float(dmg_by.get(sw.out, 0.0))
				sw["dmgBy"] = dmg_by
				if int(sw.out) == top:
					push_error("T239 断言：%d 层被换下的 %d 是本队出伤第一" % [f, int(sw.out)])
			st.set_meta("t239_swap", sw)
		for a in st.battle_members():
			a.recover_all()
		out.append(st)
	if out.is_empty() and f == 34:   # T239：虚拟玩家到 34 层前没留档（33 层打完就是 34），借 33 层的档量鸿钧，结果单独列
		out = _snapshot_bases(33)
		for st in out:
			st.set_variable(20, f)
	return out



## T239 第 6 轮：每份存档展开成多支队（原队＋随机抽的合法阵容＋奶妈队）×战斗随机种子；三个开关都没开就照旧只有存档原队
func _snapshot_states(f: int) -> Array:
	var bases := _snapshot_bases(f)
	if lineups <= 1 and not add_healer and rng_seeds.is_empty():
		return bases
	var out := []
	for bi in bases.size():
		var st: XState = bases[bi]
		var helper_id := int(st.battle_slots[XTianqi.HELPER_SLOT])
		var orig: Array = st.battle_members().map(func(a): return int(a.actor_id))
		var variants := [_tagged(_clone(st), "原队")]
		var seen := {_team_key(orig): true}
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * f + bi
		var guard := 0
		while variants.size() < lineups and guard < 300:
			guard += 1
			var bag: Array = st.party.filter(func(id): return int(id) != helper_id)
			var pick := []
			for i in 4:
				if bag.is_empty():
					break
				pick.append(int(bag.pop_at(rng.randi_range(0, bag.size() - 1))))
			if pick.size() != 4 or seen.has(_team_key(pick)) or not CT.TB.legal(pick, difficulty):
				continue
			if all_weak and not pick.all(func(id): return XTianqiSkills.is_weak(int(id), true)):
				continue
			seen[_team_key(pick)] = true
			variants.append(_tagged(_relineup(_clone(st), pick, helper_id), "随机%d" % (variants.size())))
		if add_healer:
			var h := _clone(st)
			XState._become_current(h)
			var probe := _clone(h)
			for a in probe.battle_members():
				a.recover_all()
			var dmg_by: Dictionary = _fight_both(probe, 0).byActor
			XState._become_current(h)
			var sw := _swap_in_reviver(h, dmg_by)
			h.set_meta("t239_swap", sw)
			if sw.has("out") or sw.has("note"):
				for a in h.battle_members():
					a.recover_all()
				variants.append(_tagged(h, "奶妈队"))
		for v in variants:
			if rng_seeds.is_empty():
				out.append(v)
				continue
			for rs in rng_seeds:
				var c := _clone(v)
				c.set_meta("t239_team", v.get_meta("t239_team"))
				c.set_meta("t239_swap", v.get_meta("t239_swap", {}))
				c.set_meta("t239_rng", int(rs) * 100000 + f)
				c.random_master = XRandomStream.hex64(int(rs) * 100000 + f)
				out.append(c)
	return out


static func _team_key(team: Array) -> String:
	var t := team.duplicate()
	t.sort()
	return ",".join(t.map(func(x): return str(x)))


static func _clone(st: XState) -> XState:
	# T541：to_dict() 内 equips/gear/flags 为原数组/字典引用，from_dict 会直接挂回；先深拷贝避免多阵容 _relineup 互相串装备
	var c := XState.from_dict(st.to_dict().duplicate(true))
	c.set_variable(20, st.variable(20))
	return c


static func _tagged(st: XState, label: String) -> XState:
	st.set_meta("t239_team", label)
	for a in st.battle_members():
		a.recover_all()
	return st


## 换上场 4 人：全队（助力位除外）卸下装备，新 4 人依次按游戏「最强装备」重配
static func _relineup(st: XState, pick: Array, helper_id: int) -> XState:
	for id in st.party:
		if int(id) != helper_id:
			XEquipment.clear(st, st.actor(int(id)))
	for i in 4:
		st.set_battle_slot(i, int(pick[i]))
	st.rearrange_actors()
	for id in pick:
		XEquipment.optimize(st, st.actor(int(id)))
	return st


## --revive-team：换上一名会复活的辅助（照抄 revive_compare._swap_in_reviver，T328）；返回 {out, in, from, level}，原队已有会复活的返回 note，配不出来返回 {}
func _swap_in_reviver(st: XState, dmg_by := {}) -> Dictionary:
	var TB = CT.TB
	var field: Array = st.battle_members().map(func(a): return int(a.actor_id))
	for a in st.battle_members():
		if not VPLogic.free_revive_skills(a).is_empty():
			return {"note": "原队已有会复活的", "who": int(a.actor_id)}
	var lv0 := int(st.battle_members()[0].level) if not st.battle_members().is_empty() else int(TB.LEVEL)
	var pool := []
	for id in st.party:
		if not field.has(int(id)) and int(id) != int(st.battle_slots[XTianqi.HELPER_SLOT]) and TB.role_of(int(id)) == "辅助" \
				and not VPLogic.free_revive_skills(st.actor(int(id))).is_empty():
			pool.append([int(id), "冷板凳"])
	var others: Array = (TB.candidates(difficulty)["辅助"] as Array).filter(func(x): return TB.can_revive(int(x), lv0) and not st.party.has(int(x)))
	others.sort_custom(func(x, y): return TB.bulk(int(x)) > TB.bulk(int(y)))
	for id in others:
		pool.append([int(id), "候选池"])
	var outs := field.duplicate()
	if dmg_by.is_empty():
		outs.sort_custom(func(x, y): return _power(st.actor(int(x))) < _power(st.actor(int(y))))
	else:   # T239 第 5 轮：按本层实测出伤从低到高；出伤第一的不换（不在候选里）
		outs.sort_custom(func(x, y): return float(dmg_by.get(int(x), 0.0)) < float(dmg_by.get(int(y), 0.0)))
		outs.pop_back()
	for pk in pool:
		for o in outs:
			var team := field.duplicate()
			team[team.find(o)] = pk[0]
			if not TB.legal(team, difficulty):
				continue
			var lv := int(st.actor(int(o)).level)
			if not st.party.has(int(pk[0])):
				st.party.append(int(pk[0]))
				st.actor(int(pk[0])).change_level_mv(lv)
			XEquipment.clear(st, st.actor(int(o)))
			st.set_battle_slot(st.battle_slots.find(int(o)), int(pk[0]))
			st.rearrange_actors()
			XEquipment.optimize(st, st.actor(int(pk[0])))
			return {"out": int(o), "in": int(pk[0]), "from": pk[1], "level": int(st.actor(int(pk[0])).level)}
	return {}


static func _power(a: XActor) -> float:
	return maxf(float(a.param(2)), float(a.param(4)))


## 敌群事件停在文字上就一路按确定续上
static func _drain(logic: XBattleLogic, logs: Array) -> void:
	var guard := 0
	while logic.is_event_waiting() and guard < 50:
		guard += 1
		var last: Dictionary = logs[-1] if not logs.is_empty() and logs[-1] is Dictionary else {}
		logs = logic.resume_event(int(last.get("token", 0)), 0)



## --snapshots 配 --duel（T239）：拿虚拟玩家每层存档真打守层者（不补血，打到分出胜负或 turns 回合），量真实回合数、是否打赢
func _run_duel_snapshots() -> void:
	var rows := []
	for f in floors:
		_cur_floor = f
		var states := _snapshot_states(f)
		if states.is_empty() or f > 34:
			continue
		var per := []
		var tid := 0
		for st in states:
			XState._become_current(st)
			tid = _troop_for(st, f)
			var r := _fight(st, tid)   # T239（核 P3-1）：34 层借 33 层档真打鸿钧
			if not keep_trace:
				r.erase("trace")   # T406：--keep-trace 留着逐步血量，拆败因用
			r["swap"] = st.get_meta("t239_swap", {})
			r["team"] = str(st.get_meta("t239_team", ""))
			r["rng"] = int(st.get_meta("t239_rng", 0))
			per.append(r)
		var row := {"floor": f, "troop": tid, "won": per.filter(func(r): return bool(r.won)).size(), "teams": per.size(),
			"turns": _median(per.map(func(r): return float(r.turns))), "dmg": _median(per.map(func(r): return float(r.dmg))),
			"enemyHp": _median(per.map(func(r): return float(r.enemyHp))), "atkScale": _median(per.map(func(r): return float(r.atkScale))), "per": per}
		rows.append(row)
		print("DUEL floor=%d won=%d/%d turns=%.1f dmg=%.0f enemyHp=%.0f alive=%s atk=%s" % [f, int(row.won), per.size(), float(row.turns), float(row.dmg), float(row.enemyHp),
			str(per.map(func(r): return int(r.alive))), str(row.atkScale)])
		if out_path != "":   # T244：每层写一次，长跑被中途停掉也留得下已量的层
			var fp := FileAccess.open(out_path, FileAccess.WRITE)
			fp.store_string(JSON.stringify({"mode": "duel-snapshots", "forceDifficulty": force_difficulty, "dotPct": XGuardianRework.DOT_PCT, "bossNegHrgCap": XTianqiCombat.BOSS_NEG_HRG_CAP, "extraEquips": extra_equips, "events": events, "turns": turns, "partial": true, "rows": rows}, "\t"))
	XEnemy.force_roll = -1.0
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"mode": "duel-snapshots", "forceDifficulty": force_difficulty, "dotPct": XGuardianRework.DOT_PCT, "bossNegHrgCap": XTianqiCombat.BOSS_NEG_HRG_CAP, "extraEquips": extra_equips, "events": events, "turns": turns, "rows": rows}, "\t"))
	print("BASELINE_DONE")
	get_tree().quit(0)
