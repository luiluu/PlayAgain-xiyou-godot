extends "res://tests/virtual_player/baseline_dps.gd"
## 【cc·T121】烙印实机标定第 4、5 步（《天启篇_烙印 v0.5》第十一节）：丙档队真打守层者，数发作、回合、倒下人次、通关率。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）。队伍、装备、等级、法宝、天平酒同 baseline_dps --shape=3s1w（＝丙档口径，c_tier.build_state）；
## 照游戏跑敌群事件（--events）、不补血打到分出胜负（--duel）。单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/brand_calib.tscn -- \
##     --floors=30,31,32,33 [--shape=3s1w] [--teams=8] [--reps=4] [--turns=30] [--difficulty=jianxian|zhengdao] \
##     [--carve=all|none] [--carved-brand=<% 或 line>] [--other-brand=7] [--ripe] [--out=<json>]
##     [--xcap=30,50,30]（D242：敌人闪避、暴击、魔法闪避底子上限，改 balance_table 那三格；缺省照表 -1）
##     [--strip-guardian=1,3,4,7]（T315：守层者敌群里的敌人去掉这几项正值 xparam 特性＝闪避、暴击闪避、魔法闪避、每回合回血，同心魔对齐）
##     [--pozhen-type]（T317：XTianqiElements.POZHEN_BY_TYPE 打开＝破阵认伤害类型）
##
## 口径：
## - 输出职责（team_rank 的 role＝输出）：--carve=all 刻印、烙印 --carved-brand（line＝按层线 layer_line 取这一层的值，缺省 line）；
##   --carve=none 不刻印、烙印 --other-brand。坦克、辅助一律不刻印、烙印 --other-brand（缺省 7，稿第十一节第 3 步「正常局坦克首通完约 7%」）。
##   境（brand_realm）取能装下这个值的最低一段，不截断。
## - 生熟：缺省生（首胜表空）；--ripe 把这一层的守层者键记进首胜表（档位 1）＝打赢过、再打同一位。
## - 每队 --reps 个战斗随机流（random_master 换种子），样本数＝队数×reps。
## - 发作：读 XTianqiBrand 本场的 fit_log（source＝self 自己疯／sear 被打疯；test 不会出现），按职责分；花样里抽自己、六亲不认单列。
## - 倒下人次：每次行动、回合末前后我方「活→倒」的次数（被复活后再倒算两次）。
## 输出 BRAND_ROW 每层一行、BRAND_DONE；--out 写完整 json（每场明细）。

var carve_mode := "all"
var carved_brand := "line"
var other_brand := 7.0
var ripe_mode := false
var reps := 4
var xcap := []
var gear_cache := ""
var _knobs_printed := false
var gear_floors: Array = [10, 20, 25, 30, 31, 32, 33]   # 装备按这一组层掷（缺省和第一轮 s45_raw 同一组，换层数不改装备）；--gear-floors= 换一组（要换缓存文件）
var strip_ids := []


func _ready() -> void:
	shape = "3s1w"
	duel = true
	events = true
	turns = 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--carve="):
			carve_mode = a.substr(8)
		elif a.begins_with("--carved-brand="):
			carved_brand = a.substr(15)
		elif a.begins_with("--other-brand="):
			other_brand = float(a.substr(14))
		elif a == "--ripe":
			ripe_mode = true
		elif a.begins_with("--reps="):
			reps = int(a.substr(7))
		elif a.begins_with("--xcap="):
			xcap = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--strip-guardian="):
			strip_ids = Array(a.substr(17).split(",")).map(func(x): return int(x))
		elif a.begins_with("--gear-floors="):
			gear_floors = Array(a.substr(14).split(",")).map(func(x): return int(x))
		elif a.begins_with("--gear-cache="):
			gear_cache = a.substr(13)
		elif a == "--pozhen-type":
			XTianqiElements.POZHEN_BY_TYPE = true
	super._ready()


## 探针进程内改：balance_table 的 eva／cri／mev 上限；守层者敌群成员的正值 xparam 特性
func _apply_knobs() -> void:
	if xcap.size() == 3:
		var c: Dictionary = XTianqiBalance.data().get("combat_rules", {}).get("enemy_xparam_cap", {})
		c["eva"] = xcap[0]
		c["cri"] = xcap[1]
		c["mev"] = xcap[2]
	if strip_ids.is_empty():
		return
	var seen := {}
	for f in floors:
		for m in XDB.rec("Troops", int(GUARDIAN[f])).get("members", []):
			var id := int(m.get("enemyId", 0))
			if id <= 0 or seen.has(id):
				continue
			seen[id] = true
			var rec := XDB.rec("Enemies", id)
			rec["traits"] = rec.get("traits", []).filter(func(tr): return not (int(tr.get("code", 0)) == XBattler.TRAIT_XPARAM and strip_ids.has(int(tr.get("dataId", -1))) and float(tr.get("value", 0)) > 0.0))
	if not _knobs_printed:
		_knobs_printed = true
		print("BRAND_KNOBS xcap=%s strip=%s enemies=%s pozhen_type=%s" % [str(xcap), str(strip_ids), str(seen.keys()), str(XTianqiElements.POZHEN_BY_TYPE)])


static func role_of(id: int) -> String:
	return str(XTianqiBase.line_data().get("actors", {}).get(str(id), {}).get("role", ""))


static func line_pct(f: int) -> float:
	var ll: Dictionary = XTianqiBrand.data().get("gain", {}).get("layer_line", {})
	var best := 0.0
	var best_f := -1
	for k in ll:
		if int(k) <= f and int(k) > best_f:
			best_f = int(k)
			best = float(ll[k])
	return best


static func realm_for(v: int) -> int:
	for i in XTianqiBrand.last_realm() + 1:
		if XTianqiBrand.node_of(i) >= v:
			return i
	return XTianqiBrand.last_realm()


func _set_brand(a: XActor, pct_v: float, carved: bool) -> void:
	XZhenqi.data(a)
	var v := roundi(pct_v * XTianqiBrand.scale())
	a.zhenqi["brand_carved"] = 1 if carved else 0
	a.zhenqi["brand"] = v
	a.zhenqi["brand_realm"] = realm_for(v)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()


func _calib_state(team: Array, f: int, rep: int) -> XState:
	var s := _state(team, f)
	s.flags["tianqi"]["difficulty"] = difficulty
	s.random_master = XRandomStream.hex64(seed * 7919 + f * 131 + rep * 17 + int(team[0]))
	var cb := line_pct(f) if carved_brand == "line" else float(carved_brand)
	for id in team:
		var a := s.actor(int(id))
		if role_of(int(id)) == "输出" and carve_mode == "all":
			_set_brand(a, cb, true)
		else:
			_set_brand(a, other_brand, false)
	if ripe_mode:
		XTianqiBrand._firsts_rw(s)["guardian:%d" % f] = 1
	XState.current = s
	_apply_knobs()  # 建档（new_game）会重载数据表，改敌人记录／上限要在建档之后、每场再改一次
	return s


func _alive_set(logic: XBattleLogic) -> Array:
	return logic.actors.map(func(a): return a.is_alive())


func _downs(before: Array, after: Array) -> int:
	var n := 0
	for i in mini(before.size(), after.size()):
		if bool(before[i]) and not bool(after[i]):
			n += 1
	return n


func _calib_fight(s: XState, troop: int) -> Dictionary:
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create(str(s.random_master)))
	logic.auto = true
	_drain(logic, logic.troop_events())
	var downs := 0
	var done := 0
	var dealt := 0.0   # 我方每次行动让敌方掉的血（不算敌人回血抵扣）
	var foe_heal := 0.0   # 敌方生命在我方行动以外的时候涨了多少（回合首末的回血、敌人自己的回复招）
	var mhp0 := logic.enemies.map(func(e): return float(e.mhp))
	for r in turns:
		var al := _alive_set(logic)
		var eh := _enemy_hp(logic)
		logic.start_turn()
		logic.take_turn_start_logs()
		foe_heal += maxf(0.0, _enemy_hp(logic) - eh)
		downs += _downs(al, _alive_set(logic))
		var count := 0
		var turn_first := true
		while count < 80:
			var u := logic.next_subject()
			_drain(logic, logic.troop_events(u if turn_first else null))
			turn_first = false
			if logic.is_over():
				break
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			al = _alive_set(logic)
			eh = _enemy_hp(logic)
			logic.act(u, cmd[0], cmd[1])
			if u is XActor:
				dealt += maxf(0.0, eh - _enemy_hp(logic))
			else:
				foe_heal += maxf(0.0, _enemy_hp(logic) - eh)
			downs += _downs(al, _alive_set(logic))
			if logic.is_over():
				break
		if not logic.is_over():
			al = _alive_set(logic)
			eh = _enemy_hp(logic)
			logic.end_turn()
			foe_heal += maxf(0.0, _enemy_hp(logic) - eh)
			downs += _downs(al, _alive_set(logic))
		done += 1
		if logic.is_over():
			break
	var c := XTianqiBrand.fight(logic)
	var fits := {"输出": {"self": 0, "sear": 0}, "坦克": {"self": 0, "sear": 0}, "辅助": {"self": 0, "sear": 0}}
	var harm := 0
	var kinds := {}
	for e in c.get("fit_log", []):
		var role := role_of(int(e.actor))
		if not fits.has(role):
			fits[role] = {"self": 0, "sear": 0}
		var src := str(e.source)
		fits[role][src] = int(fits[role].get(src, 0)) + 1
		kinds[str(e.kind)] = int(kinds.get(str(e.kind), 0)) + 1
		if str(e.kind) in ["hit_self", "hit_ally"]:
			harm += 1
	var roles := {}
	for a in logic.actors:
		var rl := role_of(int(a.actor_id))
		roles[rl] = int(roles.get(rl, 0)) + 1
	return {"turns": done, "won": logic.is_won(), "lost": logic.is_lost(), "downs": downs, "fits": fits, "kinds": kinds, "harm": harm,
		"roles": roles, "ripe": bool(c.get("ripe", false)), "kind": str(c.get("kind", "")), "key": str(c.get("key", "")),
		"fills": c.get("fills", {}).duplicate(),
		"dealt_per_turn": dealt / maxf(1.0, done), "foe_heal_per_turn": foe_heal / maxf(1.0, done), "foe_mhp": mhp0,
		"foe_hp_left": logic.enemies.map(func(e): return [int(e.enemy_id), float(e.hp) / maxf(1.0, float(e.mhp))]),
		"foe_xparam": logic.enemies.map(func(e): return [int(e.enemy_id), snappedf(e.xparam(0), 0.001), snappedf(e.xparam(1), 0.001), snappedf(e.xparam(4), 0.001), snappedf(e.xparam(7), 0.001)]),
		"party_mhp": logic.actors.map(func(a): return int(a.mhp)),
		"brand": logic.actors.map(func(a): return [int(a.actor_id), role_of(int(a.actor_id)), XTianqiBrand.carved(a), XTianqiBrand.pct(a)])}


static func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for x in a:
		t += float(x)
	return t / a.size()


func _run() -> void:
	XEnemy.force_roll = 100.0   # 守层者不按神话
	XTianqiBrand.ENABLED = true
	_apply_knobs()
	var list := _teams()
	_load_gears(list)
	var rows := []
	for f in floors:
		var per := []
		for team in list:
			for rep in reps:
				var s := _calib_state(team, f, rep)
				var r := _calib_fight(s, int(GUARDIAN[f]))
				r["team"] = team
				r["rep"] = rep
				per.append(r)
		var n := per.size()
		var won := per.filter(func(r): return bool(r.won))
		var row := {"floor": f, "troop": GUARDIAN[f], "n": n, "won": won.size(), "win_rate": float(won.size()) / maxf(1.0, n),
			"turns_won_avg": _avg(won.map(func(r): return r.turns)), "turns_all_avg": _avg(per.map(func(r): return r.turns)),
			"downs_avg": _avg(per.map(func(r): return r.downs)), "harm_fights": per.filter(func(r): return int(r.harm) > 0).size(),
			"ripe_flag": per.all(func(r): return bool(r.ripe)), "boss_kind": per[0].kind if n else ""}
		# 每人每场：按职责平均（每场这个职责的人数分摊）
		for role in ["输出", "坦克", "辅助"]:
			var self_pp := []
			var sear_pp := []
			for r in per:
				var cnt := int(r.roles.get(role, 0))
				if cnt <= 0:
					continue
				self_pp.append(float(r.fits.get(role, {}).get("self", 0)) / cnt)
				sear_pp.append(float(r.fits.get(role, {}).get("sear", 0)) / cnt)
			row["self_" + role] = _avg(self_pp)
			row["sear_" + role] = _avg(sear_pp)
			row["n_" + role] = self_pp.size()
		row["dealt_per_turn_avg"] = _avg(per.map(func(r): return r.dealt_per_turn))
		row["foe_heal_per_turn_avg"] = _avg(per.map(func(r): return r.foe_heal_per_turn))
		row["foe_mhp"] = per[0].foe_mhp if n else []
		row["team_self_avg"] = _avg(per.map(func(r): return int(r.fits.get("输出", {}).get("self", 0)) + int(r.fits.get("坦克", {}).get("self", 0)) + int(r.fits.get("辅助", {}).get("self", 0))))
		var kinds := {}
		for r in per:
			for k in r.kinds:
				kinds[k] = int(kinds.get(k, 0)) + int(r.kinds[k])
		row["kinds"] = kinds
		row["fights"] = per
		rows.append(row)
		print("BRAND_ROW floor=%d diff=%s carve=%s ripe=%s n=%d won=%d turnsWon=%.2f turnsAll=%.2f downs=%.2f selfOut=%.3f searOut=%.3f selfTank=%.3f searTank=%.3f selfSup=%.3f searSup=%.3f teamSelf=%.3f harmFights=%d dealt/t=%.0f foeHeal/t=%.0f foeMhp=%s kind=%s ripeFlag=%s kinds=%s" % [
			f, difficulty, carve_mode, str(ripe_mode), n, won.size(), float(row.turns_won_avg), float(row.turns_all_avg), float(row.downs_avg),
			float(row.get("self_输出", 0)), float(row.get("sear_输出", 0)), float(row.get("self_坦克", 0)), float(row.get("sear_坦克", 0)),
			float(row.get("self_辅助", 0)), float(row.get("sear_辅助", 0)), float(row.team_self_avg), int(row.harm_fights), float(row.dealt_per_turn_avg), float(row.foe_heal_per_turn_avg), str(row.foe_mhp), str(row.boss_kind), str(row.ripe_flag), JSON.stringify(kinds)])
	XEnemy.force_roll = -1.0
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"xcap": xcap, "strip": strip_ids, "pozhen_type": XTianqiElements.POZHEN_BY_TYPE, "difficulty": difficulty, "carve": carve_mode, "carved_brand": carved_brand, "other_brand": other_brand,
			"ripe": ripe_mode, "reps": reps, "teams": list, "turns": turns, "seed": seed, "rows": rows}, "\t"))
	print("BRAND_DONE")
	get_tree().quit(0)


## 装备缓存（--gear-cache=<json>）：有就读，没有就按 gear_floors 掷完写下。键：队伍键 → 层 → actor_id → 栏位表
func _load_gears(list: Array) -> void:
	if gear_cache != "" and FileAccess.file_exists(gear_cache):
		var d = JSON.parse_string(FileAccess.get_file_as_string(gear_cache))
		if d is Dictionary:
			for key in d:
				var per := {}
				for f in d[key]:
					per[int(f)] = d[key][f]
				_gears[key] = per
	var keep := floors
	floors = gear_floors.duplicate()
	var added := false
	for team in list:
		var key := ",".join(team.map(func(x): return str(x)))
		if not _gears.has(key):
			_shape_state(team, int(floors[0]))
			added = true
	floors = keep
	if added and gear_cache != "":
		var fh := FileAccess.open(gear_cache, FileAccess.WRITE)
		fh.store_string(JSON.stringify(_gears))
