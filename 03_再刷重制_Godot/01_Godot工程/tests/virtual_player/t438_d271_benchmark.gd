extends Node
## 【小A·T438】按 Kyo 11-23 D271 标尺实测天启篇 31～36 层五档毕业胜率，并纳入成长神器对照（只测不改游戏本体与数值表）。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑（务必带 --audio-driver Dummy）：
##   03_再刷重制_Godot/07_开发环境/godot --headless --audio-driver Dummy --path 03_再刷重制_Godot/01_Godot工程 \
##     -s res://tests/test_main_loop.gd res://tests/virtual_player/t438_d271_benchmark.tscn -- \
##     [--templates=A,B,C,D] [--floors=31-36] [--lines=war,famine,death,plague] [--teams=4] [--seeds=1,2] \
##     [--artifact=none|mid|cap|hh_mid|hh_cap|crown_mid|crown_cap] [--max-turns=50] [--force-diff=] [--out=<json>] [--verbose]
##
## 4 套 D271 标准测算模板（严格按装备需求等级 req_level ＋ 品质区分同层毕业装，严禁低级不朽混充毕业装）：
## - A（艰险 jianxian）：顺推混搭对照（对标 T432 均 req_level ≈ 58，无七印神话、随机常规词条、2强2弱合理职责阵容）
## - B（九死 jiusi）：4 强者＋同级毕业装（含不少常规词条神话装，100% req_level≥70，31～33层 Lv70～75、34～35层 Lv70～80、36层含 Lv80～81，常规随机词条不拉满）
## - C（炼狱 lianyu）：2 超强 2 强＋同级毕业装（养成 ~80%，100% req_level≥70，成套七印神话＋上品 2 槽优选词条＋熟练度80%＋秘籍80%＋种族5阶＋输出烙印75%）
## - D（证道 zhengdao）：2 超强 2 强＋助力超强拉满（95%+ 养成与优化词条，同级真印七印全套＋全 4 阶极品职责优选词条＋熟练度100%＋秘籍号卷满＋种族7阶＋输出烙印100%）
##
## 成长神器对照（--artifact，对应 tianqi_data/gear_table.json artifact_cap：心钢10阶／狂妄10阶／头顶+300%）：
## - none：无成长神器基线（栏位 17 留空）
## - mid：三神器按职责中度刷高（1物理主C杰作无我6阶［若法系则头顶+150%］、另1输出头顶+150%、坦辅杰作利维坦6阶）
## - cap：三神器按职责刷满上限（1物理主C杰作无我10阶［若法系则头顶+300%］、另1输出头顶+300%、坦辅杰作利维坦10阶）
## - hh_mid / hh_cap：仅杰作无我＋杰作利维坦（不含头顶）中度 6 阶 / 满上限 10 阶（拆解头顶 vs 狂妄心钢各自贡献）
## - crown_mid / crown_cap：全员头顶 7940 中度 +150% / 满上限 +300%（极端上限对照）

const TB := preload("res://tests/virtual_player/team_builder.gd")
const VPLogic := preload("res://tests/virtual_player/vp_battle_logic.gd")
const K := preload("res://tests/virtual_player/k_calibrate.gd")
const AFF := preload("res://modes/xiyou/core/tianqi_affix_table.gd")

const GUARDIAN := {31: 467, 32: 468, 33: 469}
const GENERAL_ATK := 3557   # 破攻
const GENERAL_MAT := 3556   # 尊魔
const MOUNT_HIGH := 4473    # 嘶风逐日驹（Lv75 不朽坐骑）
const MOUNT_MID := 4472     # 白马（Lv45 普通坐骑）

var template_keys: Array = ["A", "B", "C", "D"]
var floors: Array = [31, 32, 33, 34, 35, 36]
var lines: Array = ["war", "famine", "death", "plague"]
var teams_n := 4
var seeds: Array = [1, 2]
var max_turns := 50
var base_seed := 20261123
var force_diff := ""
var artifact_mode := "none"
var out_path := ""
var verbose := false

static var _db_cache := {}
static var _pick_cache := {}
static var _secret_ids: Array = []
static var _secret_cache := {}
static var _revive_item_id := 0
static var _pool_probe_cache := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--templates="):
			template_keys = Array(a.substr(12).split(","))
		elif a.begins_with("--floors="):
			var v := a.substr(9)
			if v.contains(","):
				floors = Array(v.split(",")).map(func(x): return int(x))
			else:
				var p := v.split("-")
				floors = range(int(p[0]), int(p[p.size() - 1]) + 1)
		elif a.begins_with("--lines="):
			lines = Array(a.substr(8).split(","))
		elif a.begins_with("--teams="):
			teams_n = maxi(1, int(a.substr(8)))
		elif a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(x): return int(x))
		elif a.begins_with("--max-turns="):
			max_turns = maxi(5, int(a.substr(12)))
		elif a.begins_with("--seed="):
			base_seed = int(a.substr(7))
		elif a.begins_with("--force-diff="):
			force_diff = a.substr(13)
		elif a.begins_with("--artifact="):
			artifact_mode = a.substr(11)
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a == "--verbose":
			verbose = true
	_run.call_deferred()


## 严格按 XTianqiSummit.level_cap 口径：31～33 层 Lv75，34～35 层 Lv80，36 层 Lv81
static func floor_level_cap(f: int) -> int:
	if f >= 36:
		return 81
	if f >= 34:
		return 80
	return 75


static func template_diff(tpl: String) -> String:
	match tpl:
		"A": return "jianxian"
		"B": return "jiusi"
		"C": return "lianyu"
		"D": return "zhengdao"
	return "jianxian"


static func template_label(tpl: String) -> String:
	match tpl:
		"A": return "A_艰险顺推混搭对照(均req≈58)"
		"B": return "B_九死4强同级毕业装(含常规神话)"
		"C": return "C_炼狱2超2强同级毕业(养成80%)"
		"D": return "D_证道2超2强+助力超强拉满(95%+)"
	return tpl


func _run() -> void:
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	# 魔冠账本定向到临时文件，严禁读写玩家真实存档目录
	var tmp_crown := OS.get_cache_dir().path_join("t438_crown_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_msec()])
	var prev_crown_path := XDemonCrown.path_override
	XDemonCrown.path_override = tmp_crown
	var t0 := Time.get_ticks_msec()
	var results := {}
	for tpl in template_keys:
		var diff := force_diff if force_diff != "" else template_diff(str(tpl))
		var t_p0 := Time.get_ticks_msec()
		var team_list := _pick_template_teams(str(tpl))
		if verbose:
			print("  [TIME] pick_teams=%dms" % [Time.get_ticks_msec() - t_p0])
		if team_list.is_empty():
			push_error("T438: 模板 %s 抽不出合法阵容" % str(tpl))
			_cleanup_crown(tmp_crown, prev_crown_path)
			get_tree().quit(2)
			return
		var tpl_out := {
			"template": str(tpl),
			"label": template_label(str(tpl)),
			"difficulty": diff,
			"artifact_mode": artifact_mode,
			"teams": team_list,
			"floors": {},
			"gear_summary": {},
		}
		print("=== T438 TEMPLATE %s (%s) diff=%s artifact=%s teams=%d ===" % [
			str(tpl), template_label(str(tpl)), diff, artifact_mode, team_list.size()])
		for f in floors:
			var fi := int(f)
			var lv := floor_level_cap(fi)
			if fi <= 34:
				var cases := []
				var gear_samples := []
				for ti in team_list.size():
					var tinfo: Dictionary = team_list[ti]
					for si in seeds.size():
						var sd := int(seeds[si])
						var ln := str(lines[(ti * seeds.size() + si) % lines.size()])
						var build_seed := base_seed + _tpl_offset(str(tpl)) + fi * 1000 + ti * 100 + sd
						_reset_crown_file(tmp_crown)
						var tb0 := Time.get_ticks_msec()
						var built := _build_state(str(tpl), diff, tinfo, fi, lv, ln, build_seed)
						var tb1 := Time.get_ticks_msec()
						if si == 0:
							gear_samples.append(built.gear_stats)
						var rec := _fight_floor(built.state, fi, ln, build_seed)
						var tf1 := Time.get_ticks_msec()
						if verbose:
							print("  [TIME] f=%d build=%dms fight=%dms ehp=%d eleft=%.1f%%" % [fi, tb1 - tb0, tf1 - tb1, int(rec.enemy_hp0), float(rec.enemy_hp_left_pct) * 100.0])
						rec["team_idx"] = ti
						rec["team"] = tinfo.field
						rec["helper"] = int(tinfo.helper)
						rec["seed"] = sd
						rec["line"] = ln
						rec["artifacts"] = built.artifacts
						cases.append(rec)
						if verbose:
							print("  [%s f=%d %s t%d s%d] won=%s turns=%d dead=%d falls=%d hp0=%d alien=%s art=%s" % [
								str(tpl), fi, ln, ti, sd, str(rec.won), int(rec.turns), int(rec.deaths), int(rec.falls_total), int(rec.party_hp0), str(rec.alien), str(built.artifacts)])
				var agg := _aggregate(cases)
				var gagg := _aggregate_gear(gear_samples)
				tpl_out.floors[str(fi)] = {"level": lv, "summary": agg, "gear": gagg, "cases": cases}
				tpl_out.gear_summary[str(fi)] = gagg
				print("T438_ROW tpl=%s diff=%s art=%s floor=%d line=ALL lv=%d win=%d/%d(%.1f%%) inst=%d turns=%.1f dead=%.2f falls=%.2f req=%.1f(med=%.0f,%d..%d) myth=%.1f%%" % [
					str(tpl), diff, artifact_mode, fi, lv, int(agg.wins), int(agg.n), float(agg.win_rate) * 100.0, int(agg.instant_losses),
					float(agg.turns_mean), float(agg.deaths_mean), float(agg.falls_mean),
					float(gagg.req_mean), float(gagg.req_median), int(gagg.req_min), int(gagg.req_max), float(gagg.myth_ratio) * 100.0])
			else:
				var by_line := {}
				var all_cases := []
				var gear_samples := []
				for ln_raw in lines:
					var ln := str(ln_raw)
					var lcases := []
					for ti in team_list.size():
						var tinfo: Dictionary = team_list[ti]
						for si in seeds.size():
							var sd := int(seeds[si])
							var build_seed := base_seed + _tpl_offset(str(tpl)) + fi * 1000 + _line_offset(ln) + ti * 100 + sd
							_reset_crown_file(tmp_crown)
							var built := _build_state(str(tpl), diff, tinfo, fi, lv, ln, build_seed)
							if ln == str(lines[0]) and si == 0:
								gear_samples.append(built.gear_stats)
							var rec := _fight_floor(built.state, fi, ln, build_seed)
							rec["team_idx"] = ti
							rec["team"] = tinfo.field
							rec["helper"] = int(tinfo.helper)
							rec["seed"] = sd
							rec["line"] = ln
							rec["artifacts"] = built.artifacts
							lcases.append(rec)
							all_cases.append(rec)
							if verbose:
								print("  [%s f=%d %s t%d s%d] won=%s turns=%d dead=%d falls=%d hp0=%d" % [
									str(tpl), fi, ln, ti, sd, str(rec.won), int(rec.turns), int(rec.deaths), int(rec.falls_total), int(rec.party_hp0)])
					var lagg := _aggregate(lcases)
					by_line[ln] = {"summary": lagg, "cases": lcases}
					print("T438_ROW tpl=%s diff=%s art=%s floor=%d line=%s lv=%d win=%d/%d(%.1f%%) inst=%d turns=%.1f dead=%.2f falls=%.2f" % [
						str(tpl), diff, artifact_mode, fi, ln, lv, int(lagg.wins), int(lagg.n), float(lagg.win_rate) * 100.0, int(lagg.instant_losses),
						float(lagg.turns_mean), float(lagg.deaths_mean), float(lagg.falls_mean)])
				var agg := _aggregate(all_cases)
				var gagg := _aggregate_gear(gear_samples)
				tpl_out.floors[str(fi)] = {"level": lv, "summary": agg, "by_line": by_line, "gear": gagg}
				tpl_out.gear_summary[str(fi)] = gagg
				print("T438_ROW tpl=%s diff=%s art=%s floor=%d line=TOTAL lv=%d win=%d/%d(%.1f%%) inst=%d turns=%.1f dead=%.2f falls=%.2f req=%.1f(med=%.0f,%d..%d) myth=%.1f%%" % [
					str(tpl), diff, artifact_mode, fi, lv, int(agg.wins), int(agg.n), float(agg.win_rate) * 100.0, int(agg.instant_losses),
					float(agg.turns_mean), float(agg.deaths_mean), float(agg.falls_mean),
					float(gagg.req_mean), float(gagg.req_median), int(gagg.req_min), int(gagg.req_max), float(gagg.myth_ratio) * 100.0])
		results[str(tpl)] = tpl_out
	XEnemy.force_roll = -1.0
	_cleanup_crown(tmp_crown, prev_crown_path)
	var out := {
		"version": 2,
		"task": "T438",
		"basis": "D271",
		"floors": floors,
		"lines": lines,
		"teams_per_template": teams_n,
		"seeds": seeds,
		"max_turns": max_turns,
		"base_seed": base_seed,
		"force_diff": force_diff,
		"artifact_mode": artifact_mode,
		"artifact_cap_table": XTianqiGear.table().get("artifact_cap", {}),
		"seconds": (Time.get_ticks_msec() - t0) / 1000.0,
		"templates": results,
	}
	if out_path != "":
		var dir := out_path.get_base_dir()
		if dir != "":
			DirAccess.make_dir_recursive_absolute(dir)
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		if fh != null:
			fh.store_string(JSON.stringify(out, "  "))
			fh.close()
		else:
			push_error("T438: 无法写入 " + out_path)
	print("T438_DONE seconds=%.2f" % float(out.seconds))
	get_tree().quit.call_deferred(0)


static func _reset_crown_file(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	XDemonCrown._loaded_path = "<unloaded>"
	XDemonCrown._ledger = null
	XDemonCrown.storage_error = ""
	XDemonCrown.error = ""
	XDemonCrown.battle = null


static func _cleanup_crown(p: String, prev: String) -> void:
	_reset_crown_file(p)
	XDemonCrown.path_override = prev


static func _tpl_offset(tpl: String) -> int:
	return {"A": 100000, "B": 200000, "C": 300000, "D": 400000}.get(tpl, 500000)


static func _line_offset(ln: String) -> int:
	return {"war": 10000, "famine": 20000, "death": 30000, "plague": 40000}.get(ln, 50000)


# ---- 1. 快速合法阵容抽取（只建 1 个共享 XState 探测，避免重复 new_game） ----

func _ensure_pool_probe() -> Dictionary:
	if not _pool_probe_cache.is_empty():
		return _pool_probe_cache
	var prev := XState.current
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), 1, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao"}
	s.actor_max_level = 81
	XState._become_current(s)
	var peaks: Dictionary = TB._peaks()
	var info := {}
	var full_pool: Dictionary = XTianqi.pool("zhengdao")
	for tier in [XTier.WEAK, XTier.STRONG, XTier.SUPER]:
		for id_raw in full_pool.get(tier, []):
			var id := int(id_raw)
			if XActorModules.IDS.has(id) or info.has(id):
				continue
			var role := TB.role_of(id)
			if not ["输出", "坦克", "辅助"].has(role):
				continue
			var can_rev := false
			var bulk := 0.0
			# 只对坦克和辅助升级探测承伤与复活技能（约 35 人），输出直接读 team_rank.json，节省 ~18 秒
			if role == "坦克" or role == "辅助":
				var a := s.actor(id)
				if a == null:
					continue
				a.change_level_mv(75)
				can_rev = (role == "辅助") and (not VPLogic.free_revive_skills(a).is_empty())
				bulk = float(a.param(0)) * (float(a.param(3)) + float(a.param(5)))
			var peak := float(peaks.get(str(id), {}).get("peak", 0.0))
			info[id] = {"tier": tier, "role": role, "revive": can_rev, "bulk": bulk, "peak": peak}
	if prev != null:
		XState._become_current(prev)
	else:
		XState.current = null
	_pool_probe_cache = info
	return _pool_probe_cache


func _tier_role_pools(diff: String) -> Dictionary:
	var probe := _ensure_pool_probe()
	var pool: Dictionary = XTianqi.pool(diff)
	var out := {}
	for tier in [XTier.WEAK, XTier.STRONG, XTier.SUPER]:
		out[tier] = {"输出": [], "坦克": [], "辅助": [], "复活辅助": [], "全部": []}
		var ids: Array = (pool.get(tier, []) as Array).duplicate()
		ids.sort()
		for id_raw in ids:
			var id := int(id_raw)
			if not probe.has(id):
				continue
			var row: Dictionary = probe[id]
			var r := str(row.role)
			out[tier]["全部"].append(id)
			out[tier][r].append(id)
			if bool(row.revive):
				out[tier]["复活辅助"].append(id)
	return out


func _pick_template_teams(tpl: String) -> Array:
	var pool_diff := template_diff(tpl)
	var pools := _tier_role_pools(pool_diff)
	var probe := _ensure_pool_probe()
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed + _tpl_offset(tpl) + 777
	var out := []
	var seen := {}
	var tries := 0
	var top_super_out: Array = (pools[XTier.SUPER]["输出"] as Array).duplicate()
	top_super_out.sort_custom(func(x, y): return float(probe[int(x)].peak) > float(probe[int(y)].peak))
	var top_strong_tank: Array = (pools[XTier.STRONG]["坦克"] as Array).duplicate()
	top_strong_tank.sort_custom(func(x, y): return float(probe[int(x)].bulk) > float(probe[int(y)].bulk))
	var top_strong_rev: Array = (pools[XTier.STRONG]["复活辅助"] as Array).duplicate()
	top_strong_rev.sort_custom(func(x, y): return float(probe[int(x)].bulk) > float(probe[int(y)].bulk))
	var top_strong_sup: Array = (pools[XTier.STRONG]["辅助"] as Array).duplicate()
	top_strong_sup.sort_custom(func(x, y): return float(probe[int(x)].bulk) > float(probe[int(y)].bulk))

	while out.size() < teams_n and tries < teams_n * 300:
		tries += 1
		var shape := "A" if out.size() % 2 == 0 else "D"
		var field := []
		var roles := []
		var helper := 0
		var used := {}
		match tpl:
			"A":
				var d1 := _pick_one(pools[XTier.STRONG]["输出"], used, rng)
				var d2 := _pick_one(pools[XTier.WEAK]["输出"], used, rng)
				var s3 := 0
				var r3 := ""
				if shape == "A":
					s3 = _pick_one(pools[XTier.WEAK]["坦克"] if not pools[XTier.WEAK]["坦克"].is_empty() else pools[XTier.STRONG]["坦克"], used, rng)
					r3 = "坦克"
				else:
					s3 = _pick_one(pools[XTier.WEAK]["辅助"], used, rng)
					r3 = "辅助"
				var rev_pool: Array = pools[XTier.STRONG]["复活辅助"] if not pools[XTier.STRONG]["复活辅助"].is_empty() else pools[XTier.STRONG]["辅助"]
				var s4 := _pick_one(rev_pool, used, rng)
				field = [d1, d2, s3, s4]
				roles = ["输出", "输出", r3, "辅助"]
				helper = _pick_one(pools[XTier.WEAK]["全部"], used, rng)
			"B":
				var d1 := _pick_one(pools[XTier.STRONG]["输出"], used, rng)
				var d2 := _pick_one(pools[XTier.STRONG]["输出"], used, rng)
				var s3 := 0
				var r3 := ""
				if shape == "A" and not pools[XTier.STRONG]["坦克"].is_empty():
					s3 = _pick_one(pools[XTier.STRONG]["坦克"], used, rng)
					r3 = "坦克"
				else:
					s3 = _pick_one(pools[XTier.STRONG]["辅助"], used, rng)
					r3 = "辅助"
				var s4 := _pick_one(pools[XTier.STRONG]["复活辅助"] if not pools[XTier.STRONG]["复活辅助"].is_empty() else pools[XTier.STRONG]["辅助"], used, rng)
				field = [d1, d2, s3, s4]
				roles = ["输出", "输出", r3, "辅助"]
				helper = _pick_one(pools[XTier.STRONG]["全部"], used, rng)
			"C":
				var d1 := _pick_one(pools[XTier.SUPER]["输出"], used, rng)
				var d2 := _pick_one(pools[XTier.SUPER]["输出"], used, rng)
				var s3 := 0
				var r3 := ""
				if shape == "A" and not pools[XTier.STRONG]["坦克"].is_empty():
					s3 = _pick_one(pools[XTier.STRONG]["坦克"], used, rng)
					r3 = "坦克"
				else:
					s3 = _pick_one(pools[XTier.STRONG]["辅助"], used, rng)
					r3 = "辅助"
				var s4 := _pick_one(pools[XTier.STRONG]["复活辅助"] if not pools[XTier.STRONG]["复活辅助"].is_empty() else pools[XTier.STRONG]["辅助"], used, rng)
				field = [d1, d2, s3, s4]
				roles = ["输出", "输出", r3, "辅助"]
				helper = _pick_one(pools[XTier.STRONG]["全部"], used, rng)
			"D":
				var top_n_sup := mini(top_super_out.size(), 10)
				var sup_slice := top_super_out.slice(0, top_n_sup)
				var d1 := _pick_one(sup_slice, used, rng)
				var d2 := _pick_one(sup_slice, used, rng)
				var s3 := 0
				var r3 := ""
				if shape == "A" and not top_strong_tank.is_empty():
					s3 = _pick_one(top_strong_tank.slice(0, mini(top_strong_tank.size(), 4)), used, rng)
					r3 = "坦克"
				else:
					s3 = _pick_one(top_strong_sup.slice(0, mini(top_strong_sup.size(), 6)), used, rng)
					r3 = "辅助"
				var rev_src := top_strong_rev.slice(0, mini(top_strong_rev.size(), 4)) if not top_strong_rev.is_empty() else top_strong_sup
				var s4 := _pick_one(rev_src, used, rng)
				field = [d1, d2, s3, s4]
				roles = ["输出", "输出", r3, "辅助"]
				helper = _pick_one(pools[XTier.SUPER]["全部"], used, rng)
		if field.any(func(x): return int(x) <= 0) or helper <= 0:
			continue
		var sk := field.duplicate()
		sk.sort()
		var key := str(sk) + "|" + str(helper)
		if seen.has(key):
			continue
		seen[key] = true
		out.append({
			"shape": shape,
			"field": field,
			"roles": roles,
			"helper": helper,
			"names": field.map(func(id): return str(XDB.rec("Actors", int(id)).get("name", str(id)))),
			"helper_name": str(XDB.rec("Actors", helper).get("name", str(helper))),
			"tiers": field.map(func(id): return XTianqiSkills.tier_of(int(id), true)),
			"helper_tier": XTianqiSkills.tier_of(helper, true),
		})
	return out


static func _pick_one(list: Array, used: Dictionary, rng: RandomNumberGenerator) -> int:
	var cands := list.filter(func(id): return not used.has(int(id)))
	if cands.is_empty():
		return 0
	var got := int(cands[rng.randi_range(0, cands.size() - 1)])
	used[got] = true
	return got


# ---- 2. 状态、严格 req_level 装备、神器成长构造 ----

func _build_state(tpl: String, diff: String, tinfo: Dictionary, f: int, lv: int, ln: String, sd: int) -> Dictionary:
	var ids: Array = tinfo.field.duplicate()
	var helper_id := int(tinfo.helper)
	var all_ids := ids + [helper_id]
	var s := XState.new_game(XTianqi.legacy_of(diff), int(ids[0]), ids.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": diff, "lineup": all_ids.duplicate(), "line": ln}
	s.random_master = XRandomStream.hex64(sd)
	s.orb_seed = sd
	seed(sd)
	s.set_variable(20, f)
	s.actor_max_level = lv
	XState._become_current(s)
	for id in all_ids:
		if not s.party.has(int(id)):
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	for i in 4:
		s.set_battle_slot(i, int(ids[i]))
	s.set_battle_slot(4, helper_id)

	var rng := RandomNumberGenerator.new()
	rng.seed = sd + 31337
	var qstream := XRandomStream.create(XRandomStream.hex64(sd + 99991), "rule")

	var gear_rows := []
	var art_desc := []
	for idx in all_ids.size():
		var aid := int(all_ids[idx])
		var is_helper := idx == 4
		var role := str(tinfo.roles[idx]) if not is_helper else TB.role_of(aid)
		if role == "" or role == "均衡":
			role = "输出"
		var a := s.actor(aid)
		var ts0 := Time.get_ticks_msec()
		a.change_level_mv(lv)
		_apply_advance(s, a, tpl)
		var ts1 := Time.get_ticks_msec()
		var eq_log := _equip_actor(s, a, tpl, diff, role, f, lv, rng, qstream)
		var ts2 := Time.get_ticks_msec()
		if not is_helper:
			gear_rows.append_array(eq_log)
		var ad := _equip_fabao_mount_artifact(s, a, tpl, role, idx, is_helper, rng)
		if not is_helper and ad != "":
			art_desc.append(ad)
		var ts3 := Time.get_ticks_msec()
		_apply_growth(s, a, tpl, role)
		var ts4 := Time.get_ticks_msec()
		a.param_mark_dirty()
		a.refresh_passive()
		a.recover_all()
		if verbose and not is_helper:
			print("    [ACTOR] %d %s(%s) mhp=%d atk=%d mat=%d def=%d mdf=%d adv=%dms eq=%dms fb=%dms gr=%dms" % [
				aid, a.display_name(), role, roundi(a.mhp), roundi(a.param(2)), roundi(a.param(4)), roundi(a.param(3)), roundi(a.param(5)),
				ts1 - ts0, ts2 - ts1, ts3 - ts2, ts4 - ts3])

	var goods := ["wine"]
	if tpl in ["C", "D"]:
		goods.append("oil")
	XTianqiMoney.money(s)["scale"] = {"floor": f, "goods": goods, "buys": goods.size()}

	var rev_id := _get_revive_item_id()
	if rev_id > 0:
		s.gain_item(rev_id, 5 if tpl == "D" else 3)

	XState._become_current(s)
	return {"state": s, "gear_stats": _summarize_gear_rows(gear_rows), "artifacts": art_desc}


static func _get_revive_item_id() -> int:
	if _revive_item_id == 0:
		var all: Array = VPLogic.revive_items_all()
		_revive_item_id = int(all[0]) if not all.is_empty() else -1
	return _revive_item_id


static func _apply_advance(s: XState, a: XActor, tpl: String) -> void:
	var max_steps := 2 if tpl == "A" else 12
	s.gain_gold(999999999)
	if XGarou.own(a):
		s.gain_item(XGarou.CATALYST, 1)
	for _n in max_steps:
		if XGarou.own(a):
			s.garou["breakthroughs"] = 999
		var r = XAdvance.row(s, int(a.actor_id))
		if r != null:
			for p in r.items:
				s.gain_item(int(p[0]), int(p[1]))
		if not XAdvance.advance(s, a):
			break
	a.refresh_passive()


static func _db_items(et: int) -> Array:
	if not _db_cache.has(et):
		var out := []
		for rec in XDB.table("Weapons" if et == 1 else "Armors"):
			if not rec is Dictionary or str(rec.get("name", "")) == "":
				continue
			if et != 1 and int(rec.get("etypeId", 0)) != et:
				continue
			var m: Dictionary = rec.get("meta", {})
			if m.has("Magic Weapon") or m.has("req_actors"):
				continue
			var rls := str(m.get("req_level", "")).strip_edges()
			var qs := str(m.get("quality", "")).strip_edges()
			if not rls.is_valid_int() or not qs.is_valid_int():
				continue
			out.append({"rec": rec, "req": int(rls), "q": int(qs), "grade": XQuality.grade_of(int(qs))})
		_db_cache[et] = out
	return _db_cache[et]


## 带缓存的数据库精选装备：按 (actor_id, lv, et, role, min_req, max_req, min_grade, max_grade) 缓存最佳 ID
static func _changes_dummy_defense(item: Dictionary) -> bool:
	var note := str(item.get("note", "")).to_lower()
	return "pushstate0329:" in note or "pushsubstate0335:" in note


static func _pick_db_item(a: XActor, et: int, role: String, w: Dictionary, min_req: int, max_req: int, min_grade: int, max_grade: int, inst_id: String, neutral_dummy := false) -> Dictionary:
	var key := "%d|%d|%d|%s|%d|%d|%d|%d|%s" % [int(a.actor_id), int(a.level), et, role, min_req, max_req, min_grade, max_grade, neutral_dummy]
	if _pick_cache.has(key):
		var cached_id := int(_pick_cache[key])
		if cached_id <= 0:
			return {}
		var it := XGear.template("weapon" if et == 1 else "armor", cached_id)
		it["instanceId"] = inst_id
		return it
	var best_id := 0
	var best_score := -1.0
	for row in _db_items(et):
		var req := int(row.req)
		var g := int(row.grade)
		if req < min_req or req > max_req or g < min_grade or g > max_grade:
			continue
		var rec: Dictionary = row.rec
		var item := XGear.template("weapon" if et == 1 else "armor", int(rec.id))
		if not a.can_equip(item) or not XTianqiGear.applies(item):
			continue
		if neutral_dummy and _changes_dummy_defense(item):
			continue
		var p := XTianqiGear.effective_params(item)
		var score := _role_gear_score(p, role, w, et) + float(req) * 2.0 + float(g) * 50.0
		if score > best_score:
			best_score = score
			best_id = int(rec.id)
	_pick_cache[key] = best_id
	if best_id <= 0:
		return {}
	var out := XGear.template("weapon" if et == 1 else "armor", best_id)
	out["instanceId"] = inst_id
	return out


static func _role_gear_score(p: Array, role: String, w: Dictionary, et: int) -> float:
	if role == "坦克":
		return float(p[0]) * 0.25 + float(p[3]) * 2.0 + float(p[5]) * 2.0 + float(p[2]) * 0.3
	if role == "辅助":
		return float(p[0]) * 0.2 + float(p[4]) * 1.5 + float(p[3]) * 1.2 + float(p[5]) * 1.5 + float(p[6]) * 0.8
	if et == 1:
		return K._wscore(p, w)
	return K._wscore(p, w) + float(p[0]) * 0.05 + (float(p[3]) + float(p[5])) * 0.2


static func _make_legal_qiyin_weapon(a: XActor, seal_prefer: String, lv: int, true_seal: bool, grades: Array, diff: String, qstream: XRandomStream, inst_id: String, preferred_weapon := "") -> Dictionary:
	var wtypes := a.traits_set(51)
	var chosen_name := ""
	var chosen_seal := seal_prefer
	var physical := a.param(2) >= a.param(4)
	var magic_keys := ["staff", "book"]
	for t in XTianqiQiyinGear.weapon_types():
		if not wtypes.has(int(t.get("wtype_id", -1))):
			continue
		var k := str(t.get("key", ""))
		if preferred_weapon != "":
			if k == preferred_weapon:
				chosen_name = str(t.name)
				break
			continue
		if (not physical and magic_keys.has(k)) or (physical and not magic_keys.has(k)):
			chosen_name = str(t.name)
			break
	if chosen_name == "" and preferred_weapon == "":
		for t in XTianqiQiyinGear.weapon_types():
			if wtypes.has(int(t.get("wtype_id", -1))):
				chosen_name = str(t.name)
				break
	if chosen_name == "":
		return {}
	if preferred_weapon != "":
		var weapon := XTianqiQiyinGear.weapon_of_type(chosen_name)
		if weapon.is_empty():
			return {}
		chosen_seal = str(weapon.seal)
	else:
		# 保留 T438 历史模板取件，便于按原口径复跑旧报告。
		for wrec in XTianqiQiyinGear.data().get("weapons", []):
			if str(wrec.get("type", "")) == chosen_name:
				chosen_seal = str(wrec.get("seal", seal_prefer))
				break
	var item := XTianqiQiyinEquip.make({
		"kind": "weapon", "seal": chosen_seal, "wtype": chosen_name,
		"true_seal": true_seal, "level": lv, "grades": grades,
	}, diff, qstream)
	if not item.is_empty() and a.can_equip(item):
		item["instanceId"] = inst_id
		return item
	return {}


static func _seal_for_role(role: String, aid: int) -> String:
	if role == "坦克":
		return "xun"
	if role == "辅助":
		return "mo"
	return "hui" if aid % 2 == 0 else "zhen"


static func _qiyin_part_of(et: int) -> String:
	match et:
		3: return "head"
		4: return "body"
		6: return "hands"
		8: return "waist"
		5: return "legs"
		7: return "feet"
	return ""


func _equip_actor(s: XState, a: XActor, tpl: String, diff: String, role: String, f: int, lv: int, rng: RandomNumberGenerator, qstream: XRandomStream, preferred_weapon := "") -> Array:
	var slots := a.equip_slots()
	var w := K.main_weights(a)
	var aid := int(a.actor_id)
	var seal := _seal_for_role(role, aid)
	var log_rows := []
	var b_qiyin_etypes := [3, 4, 5, 7] if f <= 33 else [3, 4, 5, 6, 7]
	var c_true_etypes := [3, 4, 5]
	var neutral_dummy := preferred_weapon != ""
	var primary_weapon := true

	for i in slots.size():
		var et := int(slots[i])
		if et == 13 or et == 16 or et == 17 or not XTianqiGear.open_type(et):
			continue
		var inst := "t438_%s_%d_%d_%d" % [tpl, f, aid, i]
		var item := {}
		var q_part := _qiyin_part_of(et)

		if tpl == "A":
			if et in [1, 4, 7]:
				item = _pick_db_item(a, et, role, w, 65, mini(75, lv), 5, 5, inst)
				if item.is_empty():
					item = _pick_db_item(a, et, role, w, 58, mini(75, lv), 4, 5, inst)
			elif et in [3, 5, 6]:
				item = _pick_db_item(a, et, role, w, 50, 65, 4, 5, inst)
				if item.is_empty():
					item = _pick_db_item(a, et, role, w, 45, 70, 4, 5, inst)
			else:
				item = _pick_db_item(a, et, role, w, 40, 58, 3, 4, inst)
				if item.is_empty():
					item = _pick_db_item(a, et, role, w, 35, 65, 3, 5, inst)
			if not item.is_empty():
				XTianqiAffixRoll.apply(item, s, func(): return rng.randf())

		elif tpl == "B":
			var q_lv := 75 if f <= 33 else 80
			var rand_grades := _roll_normal_qiyin_grades(rng)
			if q_part != "" and b_qiyin_etypes.has(et):
				item = XTianqiQiyinEquip.make({
					"kind": "set", "seal": seal, "part": q_part,
					"true_seal": false, "level": q_lv, "grades": rand_grades,
				}, diff, qstream)
				if not item.is_empty():
					item["instanceId"] = inst
			elif et == 1 and f >= 36:
				item = _make_legal_qiyin_weapon(a, seal, 80, false, rand_grades, diff, qstream, inst)
			elif et == 1 and f >= 34:
				item = _pick_db_item(a, 1, role, w, 80, 80, 6, 6, inst)
				if not item.is_empty():
					XTianqiAffixRoll.apply(item, s, func(): return rng.randf())
			elif et == 9 and f >= 34:
				item = _pick_db_item(a, 9, role, w, 80, 80, 6, 6, inst)
				if not item.is_empty():
					XTianqiAffixRoll.apply(item, s, func(): return rng.randf())
			elif et == 8 and f >= 36:
				item = _pick_db_item(a, 8, role, w, 80, 80, 6, 6, inst)
				if not item.is_empty():
					XTianqiAffixRoll.apply(item, s, func(): return rng.randf())
			if item.is_empty():
				item = _pick_db_item(a, et, role, w, 70, mini(75, lv), 5, 6, inst)
				if item.is_empty():
					item = _pick_db_item(a, et, role, w, 65, mini(75, lv), 5, 6, inst)
				if not item.is_empty():
					XTianqiAffixRoll.apply(item, s, func(): return rng.randf())

		elif tpl == "C":
			var q_lv := 75 if f <= 33 else 80
			var fine_grades := ["shangpin", "shangpin", "putong"]
			if q_part != "":
				var is_true := (f >= 34) and c_true_etypes.has(et)
				item = XTianqiQiyinEquip.make({
					"kind": "set", "seal": seal, "part": q_part,
					"true_seal": is_true, "level": q_lv, "grades": fine_grades,
				}, diff, qstream)
				if not item.is_empty():
					item["instanceId"] = inst
			elif et == 1:
				var is_true_w := f >= 36 and (not neutral_dummy or primary_weapon)
				item = _make_legal_qiyin_weapon(a, seal, q_lv, is_true_w, fine_grades, diff, qstream, inst, preferred_weapon)
				primary_weapon = false
			elif et == 9 and f >= 34 and not neutral_dummy:
				item = _pick_db_item(a, 9, role, w, 80, 80, 6, 6, inst)
			if item.is_empty():
				item = _pick_db_item(a, et, role, w, 70, mini(lv, 81), 5, 6, inst, neutral_dummy)
				if item.is_empty():
					item = _pick_db_item(a, et, role, w, 65, mini(lv, 81), 5, 6, inst, neutral_dummy)
			if not item.is_empty():
				_apply_curated_affixes(item, a, role, "C", diff, rng, w if neutral_dummy else {})

		elif tpl == "D":
			var q_lv := 75 if f <= 33 else 80
			var perf_grades := ["ji", "ji", "ji"]
			if q_part != "":
				item = XTianqiQiyinEquip.make({
					"kind": "set", "seal": seal, "part": q_part,
					"true_seal": true, "level": q_lv, "grades": perf_grades,
				}, diff, qstream)
				if not item.is_empty():
					item["instanceId"] = inst
			elif et == 1:
				item = _make_legal_qiyin_weapon(a, seal, q_lv, true, perf_grades, diff, qstream, inst)
				if item.is_empty() and f >= 36:
					item = _pick_db_item(a, 1, role, w, 80, 81, 6, 6, inst)
			elif et == 9 and f >= 34:
				item = _pick_db_item(a, 9, role, w, 80, 80, 6, 6, inst)
			if item.is_empty():
				item = _pick_db_item(a, et, role, w, 70, mini(lv, 81), 5, 6, inst)
				if item.is_empty():
					item = _pick_db_item(a, et, role, w, 65, mini(lv, 81), 5, 6, inst)
			if not item.is_empty():
				_apply_curated_affixes(item, a, role, "D", diff, rng)

		if not item.is_empty():
			a.equips[i] = item
			var rl := int(str(item.get("meta", {}).get("req_level", "0")).strip_edges())
			var qg := XQuality.grade(item)
			var qm: Dictionary = item.get("qiyin", {}) if item.get("qiyin") is Dictionary else {}
			log_rows.append({
				"actor": aid, "etype": et, "name": str(item.get("name", "")),
				"req_level": rl, "grade": qg, "grade_name": _grade_cn(qg),
				"qiyin": not qm.is_empty(), "true_seal": bool(qm.get("true_seal", false)),
			})
	return log_rows


static func _roll_normal_qiyin_grades(rng: RandomNumberGenerator) -> Array:
	var out := []
	for _i in 3:
		var r := rng.randf()
		if r < 0.03:
			out.append("ji")
		elif r < 0.33:
			out.append("shangpin")
		else:
			out.append("putong")
	return out


static func _apply_curated_affixes(item: Dictionary, a: XActor, role: String, tpl: String, diff: String, rng: RandomNumberGenerator, weights := {}) -> void:
	var slot := XTianqiAffixRoll.slot_key(item)
	if slot == "":
		return
	var group := AFF.slot_group(slot)
	var qk := XTianqiAffixRoll.quality_key(item)
	var max_slots := AFF.slot_count(qk)
	if max_slots <= 0:
		return
	var tier := 4
	var grade := "perfect" if tpl == "D" else "fine"
	var want_curated := max_slots if tpl == "D" else mini(2, max_slots)
	var physical := a.param(2) >= a.param(4) if weights.is_empty() else float(weights.get("atk", 0)) >= float(weights.get("mat", 0))
	var atk_key := "atk" if physical else "mat"

	var pref := []
	if slot == "necklace":
		if role == "输出":
			pref = ["aura_fervor" if physical else "aura_arcane", "headhunter", "final_damage", "crit_damage", "skill_damage", atk_key]
		elif role == "坦克":
			pref = ["aura_shelter", "bulwark", "damage_reduction", "mhp", "def", "mdf"]
		else:
			pref = ["aura_recovery", "rejuvenate", "heal_dealt", "damage_reduction", "mhp", "mdf"]
	elif role == "输出":
		if group == "bingqi":
			pref = ["headhunter", "final_damage", "crit_damage", "skill_damage", "cri", atk_key, "expose"]
		elif group == "fangju":
			pref = ["bulwark", "unyielding", "damage_reduction", "mhp", "def", "mdf", "cri", "final_damage"]
		else:
			pref = ["headhunter", "final_damage", "crit_damage", "skill_damage", "cri", atk_key]
	elif role == "坦克":
		pref = ["bulwark", "tenacity", "unyielding", "damage_reduction", "heal_received", "mhp", "def", "mdf"]
	else:
		pref = ["rejuvenate", "bulwark", "heal_dealt", "damage_reduction", "skill_cost", "mhp", "mdf", "def"]

	var allowed_layers: Array = AFF.quality_layers(qk)
	var list := []
	var used_keys := {}
	var layer_cnt := {}
	var els: Array = AFF.data().get("elements", []).filter(func(e): return str(e.key) != "physical")

	for k in pref:
		if list.size() >= want_curated:
			break
		if used_keys.has(k):
			continue
		var af := AFF.affix(str(k))
		if af.is_empty():
			continue
		var ly := str(af.get("layer", ""))
		if ly == "aura":
			if slot != "necklace":
				continue
		else:
			if not allowed_layers.has(ly):
				continue
		if not AFF.candidates(ly, group).has(k) or not AFF.available(str(k), tier):
			continue
		var cap = AFF.layer(ly).get("per_item_max")
		if cap != null and int(layer_cnt.get(ly, 0)) >= int(cap):
			continue
		var ex := {}
		if bool(af.get("random_element", false)) and not els.is_empty():
			ex.element = str(els[rng.randi_range(0, els.size() - 1)].key)
		var vars: Array = af.get("variants", [])
		if not vars.is_empty():
			ex.variant = str(vars[0].key)
		list.append({"key": str(k), "tier": tier, "grade": grade, "extra": ex})
		used_keys[k] = true
		layer_cnt[ly] = int(layer_cnt.get(ly, 0)) + 1

	if list.size() < max_slots:
		var rolled := XTianqiAffixRoll.roll(item, slot, diff, func(): return rng.randf())
		for r in rolled:
			if list.size() >= max_slots:
				break
			var k := str(r.key)
			if used_keys.has(k):
				continue
			var ly := str(AFF.affix(k).get("layer", ""))
			var cap = AFF.layer(ly).get("per_item_max")
			if cap != null and int(layer_cnt.get(ly, 0)) >= int(cap):
				continue
			list.append(r)
			used_keys[k] = true
			layer_cnt[ly] = int(layer_cnt.get(ly, 0)) + 1

	if item.has("qiyin"):
		item.qiyin["affixes"] = list
	else:
		XTianqiAffixRoll.set_affixes(item, list)


## 构造法宝、坐骑、成长神器（7901 杰作利维坦 / 7903 杰作无我 / 7940 头顶）
func _equip_fabao_mount_artifact(s: XState, a: XActor, tpl: String, role: String, idx: int, is_helper: bool, rng: RandomNumberGenerator) -> String:
	var aid := int(a.actor_id)
	var fb_lv := 90 if tpl == "A" else 99
	var fid := K._own_fabao(aid)
	var is_general := false
	if fid == 0:
		var mw := K.main_weights(a)
		fid = GENERAL_ATK if float(mw.get("atk", 0.0)) >= float(mw.get("mat", 0.0)) else GENERAL_MAT
		is_general = true
	var fb := XGear.template("armor", fid)
	fb.level = float(mini(fb_lv, int(XMagicWeapon.max_level(fb))))
	fb.exp = 0.0
	if is_general and tpl in ["C", "D"]:
		var aura_key := "aura_fury" if role == "输出" else "aura_shelter"
		XTianqiAffixRoll.set_affixes(fb, [{"key": aura_key, "tier": 4, "grade": "perfect" if tpl == "D" else "fine", "extra": {}, "growth": true}])
	elif is_general and tpl in ["A", "B"]:
		XTianqiAffixRoll.apply(fb, s, func(): return rng.randf())
	var fslot := a.equip_slots().find(13)
	if fslot >= 0:
		a.equips[fslot] = fb

	var mslot := a.equip_slots().find(16)
	if mslot >= 0:
		var mid := MOUNT_MID if tpl == "A" else MOUNT_HIGH
		var mt := XGear.template("armor", mid)
		if a.can_equip(mt):
			a.equips[mslot] = mt

	# 成长神器对照（栏位 17）：严格走 XHeartsteel / XHubris / XDemonCrown 真实机制与 artifact_cap
	var aslot := a.equip_slots().find(17)
	if aslot < 0 or artifact_mode == "none" or (is_helper and tpl != "D"):
		return ""
	var cap_tbl: Dictionary = XTianqiGear.table().get("artifact_cap", {})
	var cap_hs := int(cap_tbl.get("heartsteel_stage", 10))
	var cap_hb := int(cap_tbl.get("hubris_stage", 10))
	var cap_cr := float(cap_tbl.get("crown_bonus_pct", 300))

	var stage_hs := 6 if artifact_mode in ["mid", "hh_mid"] else cap_hs
	var stage_hb := 6 if artifact_mode in ["mid", "hh_mid"] else cap_hb
	var bonus_cr := 150.0 if artifact_mode in ["mid", "crown_mid"] else cap_cr
	var physical := a.param(2) >= a.param(4)

	var kind_pick := ""
	if artifact_mode in ["crown_mid", "crown_cap"]:
		kind_pick = "crown"
	elif artifact_mode in ["hh_mid", "hh_cap"]:
		kind_pick = "hubris" if role == "输出" else "heart"
	else:
		# mid / cap：三神器按职责搭配（idx==0 物理输出带杰作无我、法系带头顶；idx==1 输出带头顶；坦辅带杰作利维坦）
		if role == "输出":
			if idx == 0 and physical:
				kind_pick = "hubris"
			else:
				kind_pick = "crown"
		else:
			kind_pick = "heart"

	var art := {}
	var desc := ""
	match kind_pick:
		"heart":
			art = XGear.template("armor", XHeartsteel.LEVIATHAN)
			art["instanceId"] = "t438_hs_%d_%d" % [aid, stage_hs]
			art[XHeartsteel.STACKS] = XHeartsteel.stage_need(stage_hs)
			desc = "利维坦%d阶" % XHeartsteel.eff_stage(art)
		"hubris":
			art = XGear.template("armor", XHubris.ATARAXIA)
			art["instanceId"] = "t438_hb_%d_%d" % [aid, stage_hb]
			art[XHubris.FAME] = XHeartsteel.stage_need(stage_hb)
			desc = "无我%d阶" % XTianqiGear.hubris_stage(stage_hb)
		"crown":
			art = XGear.template("armor", XDemonCrown.ARMOR)
			art["instanceId"] = "t438_cr_%d_%d" % [aid, int(bonus_cr)]
			art[XDemonCrown.BONUS] = bonus_cr
			XDemonCrown.describe(art)
			desc = "头顶+%d%%" % roundi(XTianqiGear.crown_bonus(bonus_cr))
	if not art.is_empty() and a.can_equip(art):
		a.equips[aslot] = art
		return desc
	return ""


func _apply_growth(s: XState, a: XActor, tpl: String, role: String, fill_secrets := true) -> void:
	var mastery_ratio := 0.0
	match tpl:
		"A": mastery_ratio = 0.0
		"B": mastery_ratio = 0.5
		"C": mastery_ratio = 0.8
		"D": mastery_ratio = 1.0
	if mastery_ratio > 0.0:
		for sid in a.skill_ids:
			var mx := XSkillMastery.max_level(int(sid))
			if mx > 0:
				XSkillMastery.set_level(a, int(sid), maxi(1, floori(float(mx) * mastery_ratio)))

	if tpl == "C" and role == "输出":
		var sc := XTianqiTrumpet.scroll(2)
		if not sc.is_empty() and XTianqiTrumpet.limit(a) > 0:
			a.learn_skill(int(sc.skill))
	elif tpl == "D":
		var lim := XTianqiTrumpet.limit(a)
		var picks := [2, 1, 3] if role == "输出" else [1, 3, 5]
		var learned := 0
		for num in picks:
			if learned >= lim:
				break
			var sc := XTianqiTrumpet.scroll(int(num))
			if not sc.is_empty():
				a.learn_skill(int(sc.skill))
				learned += 1

	var secret_ratio := 0.0
	match tpl:
		"A": secret_ratio = 0.0
		"B": secret_ratio = 0.5
		"C": secret_ratio = 0.8
		"D": secret_ratio = 1.0
	if fill_secrets and secret_ratio > 0.0:
		_learn_secrets_cached(a, secret_ratio)

	var brand_pct := 0.0
	match tpl:
		"A": brand_pct = 40.0 if role == "输出" else 20.0
		"B": brand_pct = 55.0 if role == "输出" else 30.0
		"C": brand_pct = 75.0 if role == "输出" else 40.0
		"D": brand_pct = 100.0 if role == "输出" else 40.0
	if brand_pct > 0.0:
		XZhenqi.data(a)
		a.zhenqi["brand_carved"] = 1 if brand_pct > 40.0 else 0
		a.zhenqi["brand_realm"] = XTianqiBrand.last_realm() if brand_pct > 40.0 else 2
		a.zhenqi["brand"] = roundi(brand_pct * XTianqiBrand.scale())

	var race_rank := 1
	match tpl:
		"A": race_rank = 1
		"B": race_rank = 3
		"C": race_rank = 5
		"D": race_rank = 7
	if race_rank >= 2 and not XRace.config().is_empty():
		var d := XRace.data(s, a)
		if int(d.race) < 0:
			XRace.set_default(s, 0)
			d = XRace.data(s, a)
		var stones: Array = XRace.config().get("stones", [])
		while int(d.rank) < race_rank and int(d.rank) - 1 < stones.size():
			var nxt := int(d.rank) + 1
			s.gain_item(int(stones[nxt - 2]), 1)
			var res := XRace.upgrade(s, a, nxt)
			if not bool(res.get("ok", false)):
				break

	if tpl in ["C", "D"]:
		var gfrac := 0.7 if tpl == "C" else 1.0
		if int(a.actor_id) == 108:
			var book: Dictionary = s.flags.get(XNanoha.ADAPT_FLAG, {})
			book[str(a.actor_id)] = 2000.0 * gfrac
			s.flags[XNanoha.ADAPT_FLAG] = book
			a.param_mark_dirty()
		elif int(a.actor_id) == 167:
			s.raven["soul"] = float(XTianqiGrowth.actor_row(XTianqiGrowth.RAVEN).get("base", 200000)) * gfrac
		elif XLiuying.own(a):
			a.state_data["_codexLbEmber"] = 3000.0 * gfrac
			a.state_data["_codexLbEmberWins"] = 0.0


static func _learn_secrets_cached(a: XActor, ratio: float) -> void:
	var ckey := "%d|%.2f" % [int(a.actor_id), ratio]
	if _secret_cache.has(ckey):
		for sid in _secret_cache[ckey]:
			if not a.skill_ids.has(int(sid)):
				a.learn_skill(int(sid))
		return
	if _secret_ids.is_empty():
		var retired_names := []
		for it in XTianqiTrumpet.data().get("retired", {}).get("items", []):
			var nm := str(XDB.rec("Items", int(it)).get("name", "")).replace("权能书：", "")
			retired_names.append("权能·" + nm)
		for sk in XDB.table("Skills"):
			if sk is Dictionary and int(sk.get("id", 0)) > 0 and str(sk.get("name", "")) != "" \
					and not retired_names.has(str(sk.get("name", ""))) \
					and XTianqiLedger.is_secret_skill(int(sk.id), int(sk.get("stypeId", 0))):
				_secret_ids.append(int(sk.id))
	var had := a.skill_ids.duplicate()
	for sid in _secret_ids:
		if not had.has(sid):
			a.learn_skill(sid)
	a.param_mark_dirty()
	a.refresh_passive()
	var by: Dictionary = a.passive_cache().get("bySource", {})
	var kept: Array = XTianqiLedger.secret_kept(a, by).map(func(b): return int(str(b).substr(1)))
	var keep_n := maxi(1, roundi(float(kept.size()) * ratio)) if not kept.is_empty() else 0
	var final_kept := kept.slice(0, keep_n)
	for sid in _secret_ids:
		if not had.has(sid) and not final_kept.has(sid):
			a.forget_skill(sid)
	_secret_cache[ckey] = final_kept


# ---- 3. 战斗执行 ----

func _fight_floor(s: XState, f: int, ln: String, sd: int) -> Dictionary:
	XState._become_current(s)
	seed(sd + 55555)
	var troop := 0
	var run_events := f <= 34
	if f <= 33:
		troop = int(GUARDIAN[f])
	elif f == 34:
		XTianqiSummit.prepare_hongjun(s)
		troop = int(XTianqiSummit.data().hongjun.troop)
	elif f == 35:
		var ok := XTianqiHorsemen.prepare(ln, s, "shadow")
		if not ok:
			return {"error": "prepare shadow 失败: " + ln, "won": false, "turns": 0, "deaths": 4, "falls_total": 0}
		troop = int(XTianqiLine.data(ln).shell_troop)
	else:
		var ok := XTianqiHorsemen.prepare(ln, s, "body")
		if not ok:
			return {"error": "prepare body 失败: " + ln, "won": false, "turns": 0, "deaths": 4, "falls_total": 0}
		troop = int(XTianqiLine.data(ln).shell_troop)

	var logic := VPLogic.new()
	logic.setup(troop, s, XBattleRandom.create(str(s.random_master)))
	logic.auto = true
	if run_events:
		_drain(logic, logic.troop_events())

	var enemy_hp0 := 0.0
	for e in logic.enemies:
		if e.is_alive():
			enemy_hp0 += float(e.mhp)
	var party_hp0 := 0.0
	for a in logic.actors:
		party_hp0 += float(a.mhp)

	var done := 0
	for _r in max_turns:
		if logic.is_over():
			break
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		var turn_first := true
		while count < 120:
			var u := logic.next_subject()
			if run_events:
				_drain(logic, logic.troop_events(u if turn_first else null))
				turn_first = false
				if logic.is_over():
					break
			if u == null:
				break
			count += 1
			var cmd := [null, null] if run_events and logic.take_cleared(u) else logic.decide(u)
			logic.act(u, cmd[0], cmd[1])
			if logic.is_over():
				break
		if not logic.is_over():
			logic.end_turn()
			if run_events:
				_drain(logic, logic.troop_events(null, true))
		done += 1
		if logic.is_over():
			break

	var won := logic.is_won()
	var lost := logic.is_lost()
	var timeout := (not won) and (not lost)
	var deaths := logic.actors.filter(func(a): return a.is_dead()).size()
	var falls_total := 0
	for v in logic.falls.values():
		falls_total += int(v)
	var enemy_hp_left := 0.0
	for e in logic.enemies:
		if e.is_alive():
			enemy_hp_left += maxf(0.0, float(e.hp))
	var alien := _alien_desc(logic)
	logic.end_battle(0 if won else 2)
	return {
		"won": won,
		"lost": lost,
		"timeout": timeout,
		"instant_loss": (not won) and done <= 3,
		"turns": done,
		"deaths": deaths,
		"falls_total": falls_total,
		"revive_casts": logic.revive_casts,
		"revive_items": logic.revive_items,
		"enemy_hp0": roundi(enemy_hp0),
		"enemy_hp_left_pct": snappedf(enemy_hp_left / maxf(1.0, enemy_hp0), 0.001),
		"party_hp0": roundi(party_hp0),
		"alien": alien,
	}


static func _drain(logic: XBattleLogic, logs: Array) -> void:
	var guard := 0
	while logic.is_event_waiting() and guard < 50:
		guard += 1
		var last: Dictionary = logs[-1] if not logs.is_empty() and logs[-1] is Dictionary else {}
		logs = logic.resume_event(int(last.get("token", 0)), 0)


static func _alien_desc(logic: XBattleLogic) -> Array:
	var out := []
	for mod in [XTianqiWarAlien, XTianqiFamineAlien, XTianqiDeathAlien, XTianqiPlagueAlien]:
		var f: Dictionary = mod.fight(logic)
		for e in f.get("units", {}):
			var u: Dictionary = f.units[e]
			out.append("%d:%s:%s" % [int(e.enemy_id), str(u.get("tier", "")), str(u.get("kind", ""))])
	return out


# ---- 4. 统计 ----

static func _grade_cn(g: int) -> String:
	var names := ["普通", "优秀", "精良", "史诗", "传说", "不朽", "神话"]
	return names[clampi(g, 0, names.size() - 1)]


static func _summarize_gear_rows(rows: Array) -> Dictionary:
	if rows.is_empty():
		return {"count": 0, "req_mean": 0.0, "req_median": 0.0, "req_min": 0, "req_max": 0, "myth_ratio": 0.0, "bands": {}, "grades": {}, "qiyin": 0, "true_seal": 0}
	var reqs := []
	var bands := {"<60": 0, "60-69": 0, "70-75": 0, "80-81": 0}
	var grades := {"史诗及以下": 0, "传说": 0, "不朽": 0, "神话": 0}
	var qiyin_n := 0
	var true_n := 0
	for r in rows:
		var rl := int(r.req_level)
		reqs.append(rl)
		if rl < 60:
			bands["<60"] += 1
		elif rl < 70:
			bands["60-69"] += 1
		elif rl <= 75:
			bands["70-75"] += 1
		else:
			bands["80-81"] += 1
		var g := int(r.grade)
		if g >= 6:
			grades["神话"] += 1
		elif g == 5:
			grades["不朽"] += 1
		elif g == 4:
			grades["传说"] += 1
		else:
			grades["史诗及以下"] += 1
		if bool(r.qiyin):
			qiyin_n += 1
		if bool(r.true_seal):
			true_n += 1
	reqs.sort()
	var sum_r := 0.0
	for v in reqs:
		sum_r += float(v)
	var med := (float(reqs[(reqs.size() - 1) / 2]) + float(reqs[reqs.size() / 2])) / 2.0
	return {
		"count": rows.size(),
		"req_mean": snappedf(sum_r / float(rows.size()), 0.1),
		"req_median": med,
		"req_min": int(reqs[0]),
		"req_max": int(reqs[-1]),
		"myth_ratio": snappedf(float(grades["神话"]) / float(rows.size()), 0.001),
		"bands": bands,
		"grades": grades,
		"qiyin": qiyin_n,
		"true_seal": true_n,
	}


static func _aggregate_gear(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {}
	var n := float(samples.size())
	var total_cnt := 0
	var req_sum := 0.0
	var meds := []
	var mn := 999
	var mx := 0
	var bands := {"<60": 0, "60-69": 0, "70-75": 0, "80-81": 0}
	var grades := {"史诗及以下": 0, "传说": 0, "不朽": 0, "神话": 0}
	var qiyin_n := 0
	var true_n := 0
	for g in samples:
		total_cnt += int(g.count)
		req_sum += float(g.req_mean) * float(g.count)
		meds.append(float(g.req_median))
		mn = mini(mn, int(g.req_min))
		mx = maxi(mx, int(g.req_max))
		for k in bands:
			bands[k] += int(g.bands.get(k, 0))
		for k in grades:
			grades[k] += int(g.grades.get(k, 0))
		qiyin_n += int(g.qiyin)
		true_n += int(g.true_seal)
	meds.sort()
	var med := (float(meds[(meds.size() - 1) / 2]) + float(meds[meds.size() / 2])) / 2.0
	return {
		"teams": int(n),
		"total_items": total_cnt,
		"req_mean": snappedf(req_sum / maxf(1.0, float(total_cnt)), 0.1),
		"req_median": med,
		"req_min": mn,
		"req_max": mx,
		"myth_ratio": snappedf(float(grades["神话"]) / maxf(1.0, float(total_cnt)), 0.001),
		"bands": bands,
		"grades": grades,
		"qiyin": qiyin_n,
		"true_seal": true_n,
	}


static func _aggregate(cases: Array) -> Dictionary:
	var n := cases.size()
	if n == 0:
		return {"n": 0, "wins": 0, "win_rate": 0.0, "instant_losses": 0, "timeouts": 0, "turns_mean": 0.0, "turns_won_mean": 0.0, "deaths_mean": 0.0, "falls_mean": 0.0}
	var wins := 0
	var inst := 0
	var timeouts := 0
	var turns_sum := 0.0
	var won_turns_sum := 0.0
	var deaths_sum := 0.0
	var falls_sum := 0.0
	var left_hp_sum := 0.0
	var loss_n := 0
	for c in cases:
		if bool(c.get("won", false)):
			wins += 1
			won_turns_sum += float(c.turns)
		else:
			loss_n += 1
			left_hp_sum += float(c.get("enemy_hp_left_pct", 0.0))
		if bool(c.get("instant_loss", false)):
			inst += 1
		if bool(c.get("timeout", false)):
			timeouts += 1
		turns_sum += float(c.turns)
		deaths_sum += float(c.deaths)
		falls_sum += float(c.get("falls_total", 0))
	return {
		"n": n,
		"wins": wins,
		"win_rate": snappedf(float(wins) / float(n), 0.001),
		"instant_losses": inst,
		"timeouts": timeouts,
		"turns_mean": snappedf(turns_sum / float(n), 0.1),
		"turns_won_mean": snappedf(won_turns_sum / float(wins), 0.1) if wins > 0 else -1.0,
		"deaths_mean": snappedf(deaths_sum / float(n), 0.01),
		"falls_mean": snappedf(falls_sum / float(n), 0.01),
		"loss_enemy_hp_left_pct": snappedf(left_hp_sum / float(loss_n), 0.001) if loss_n > 0 else 0.0,
	}
