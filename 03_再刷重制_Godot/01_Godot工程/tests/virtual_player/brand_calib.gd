extends "res://tests/virtual_player/baseline_dps.gd"
## 【cc·T121】烙印实机标定第 4、5 步（《天启篇_烙印 v0.5》第十一节）：丙档队真打守层者，数发作、回合、倒下人次、通关率。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）。队伍、装备、等级、法宝、天平酒同 baseline_dps --shape=3s1w（＝丙档口径，c_tier.build_state）；
## 照游戏跑敌群事件（--events）、不补血打到分出胜负（--duel）。单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/brand_calib.tscn -- \
##     --floors=30,31,32,33 [--shape=3s1w] [--teams=8] [--reps=4] [--turns=30] [--difficulty=jianxian|zhengdao] \
##     [--carve=all|none] [--carved-brand=<% 或 line>] [--other-brand=7] [--ripe] [--out=<json>]
##     [--xcap=30,50,30]（D242：敌人闪避、暴击、魔法闪避底子上限，改 balance_table 那三格；缺省照表 -1）
##     [--strip-guardian=1,3,4,7|none]（T348 起游戏默认就清守层者（含变身 538／929／930）这四项正值＝XGuardianRework.STRIP；
##      这里改 STRIP_XPARAM 拆开量，如 =3 只清暴闪、=7 只清回血；none＝关开关、照原数据。缺省照游戏默认）
##     [--pozhen-type]（T317：XTianqiElements.POZHEN_BY_TYPE 打开＝破阵认伤害类型）
##     [--brand-set=sear.per_hit.终焉=12;sear.cap.base=70]（T390：进程内改 brand.json 的整数项量候选值，不写文件；键用点分路径、分号隔开）
##     [--snapshots=<存档目录> --lineups=4 --rng-seeds=1,2]（T390：改用虚拟玩家每层存档链，同 T363 真打口径，不用配队器丙档队；
##      上场 4 人按职责改写烙印，出手走虚拟玩家层 VPLogic。--carved-brand=line 取首通 1～f−1 层之和，node＝旧口径「≤f 最近节点」）
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
var brand_set := {}   # T390 --brand-set：{"sear.per_hit.终焉": 12, ...}


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
			strip_ids = [-1] if a.substr(17) == "none" else Array(a.substr(17).split(",")).map(func(x): return int(x))
		elif a.begins_with("--gear-floors="):
			gear_floors = Array(a.substr(14).split(",")).map(func(x): return int(x))
		elif a.begins_with("--gear-cache="):
			gear_cache = a.substr(13)
		elif a.begins_with("--brand-set="):
			for kv in a.substr(12).split(";", false):
				brand_set[kv.get_slice("=", 0)] = int(kv.get_slice("=", 1))
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
	if not strip_ids.is_empty():
		XGuardianRework.STRIP = strip_ids != [-1]  # T348：改游戏里的开关（数据层钩子，建档重载数据表也照认；含变身二阶段）
		if XGuardianRework.STRIP:
			XGuardianRework.STRIP_XPARAM = strip_ids.duplicate()
	for path in brand_set:   # T390：每次都改（建档可能清缓存重读 brand.json）
		var keys: PackedStringArray = str(path).split(".")
		var node = XTianqiBrand.data()
		for i in keys.size() - 1:
			node = node.get(keys[i], {})
		if node is Dictionary and node.has(keys[keys.size() - 1]):
			node[keys[keys.size() - 1]] = brand_set[path]
		else:
			push_error("brand_calib --brand-set 找不到 " + str(path))
	var seen := {}
	for f in floors:
		for m in XDB.rec("Troops", int(GUARDIAN[f])).get("members", []):
			var id := int(m.get("enemyId", 0))
			if id > 0 and XGuardianRework.strip_touches(id):
				seen[id] = true
	if not _knobs_printed:
		_knobs_printed = true
		print("BRAND_KNOBS xcap=%s strip=%s strip_on=%s enemies=%s pozhen_type=%s brand_set=%s" % [str(xcap), str(XGuardianRework.STRIP_XPARAM), str(XGuardianRework.STRIP), str(seen.keys()), str(XTianqiElements.POZHEN_BY_TYPE), JSON.stringify(brand_set)])


## T390（T121 核 P2-2）：职责口径同配队器（均衡按 BALANCED_AS_OUTPUT 并入输出），不再自己读 line_data
static func role_of(id: int) -> String:
	return CT.TB.role_of(id)


## T390（T121 核 P2-4 截断偏差）：打第 f 层守层者之前的层线烙印＝首通 1～f−1 层每层给的数之和（first_clear.segments），
## 不再取「≤f 的最近节点」（26～29 层原来都按 70 算、实际 73～82；30 层原来 85、打之前其实 82）。到节点就打心魔，所以不按节点截断
static func line_before(f: int) -> float:
	var segs: Array = XTianqiBrand.data().get("gain", {}).get("first_clear", {}).get("segments", [])
	var t := 0.0
	for k in range(1, f):
		for sg in segs:
			if k >= int(sg.get("from", 0)) and k <= int(sg.get("to", 0)):
				t += float(sg.get("each", 0))
				break
	return t


## 旧口径（--carved-brand=node）：≤f 的最近层线节点
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
	_brand_team(s, team, f)
	XState.current = s
	_apply_knobs()  # 建档（new_game）会重载数据表，改敌人记录／上限要在建档之后、每场再改一次
	return s


func carved_value(f: int) -> float:
	if carved_brand == "line":
		return line_before(f)
	if carved_brand == "node":
		return line_pct(f)
	return float(carved_brand)


func _brand_team(s: XState, team: Array, f: int) -> void:
	var cb := carved_value(f)
	for id in team:
		var a := s.actor(int(id))
		if role_of(int(id)) == "输出" and carve_mode == "all":
			_set_brand(a, cb, true)
		else:
			_set_brand(a, other_brand, false)
	if ripe_mode:
		XTianqiBrand._firsts_rw(s)["guardian:%d" % f] = 1
	else:
		XTianqiBrand._firsts_rw(s).erase("guardian:%d" % f)


## T390 --snapshots：虚拟玩家存档链（同 T363 真打：原队＋--lineups 随机阵容 × --rng-seeds），上场 4 人按职责改写烙印
func _snap_calib_states(f: int) -> Array:
	var out := []
	for st in _snapshot_states(f):
		XState._become_current(st)
		var team: Array = st.battle_members().map(func(a): return int(a.actor_id))
		st.flags["tianqi"]["difficulty"] = difficulty
		_brand_team(st, team, f)
		_apply_knobs()
		st.set_meta("t390_team", team)
		out.append(st)
	return out


func _alive_set(logic: XBattleLogic) -> Array:
	return logic.actors.map(func(a): return a.is_alive())


func _downs(before: Array, after: Array) -> int:
	var n := 0
	for i in mini(before.size(), after.size()):
		if bool(before[i]) and not bool(after[i]):
			n += 1
	return n


func _calib_fight(s: XState, troop: int) -> Dictionary:
	var logic: XBattleLogic = VPLogic.new() if (_use_vp() or snapshots != "") else XBattleLogic.new()   # T390：存档链同 T363 真打用虚拟玩家出手层
	if s.has_meta("t239_rng"):
		seed(int(s.get_meta("t239_rng")))
	logic.setup(troop, s, XBattleRandom.create(str(s.random_master)))
	logic.auto = true
	_drain(logic, logic.troop_events())
	var downs := 0
	var done := 0
	var dealt := 0.0   # 我方每次行动让敌方掉的血（不算敌人回血抵扣）
	var foe_heal := 0.0   # 敌方生命在我方行动以外的时候涨了多少（回合首末的回血、敌人自己的回复招）
	var dot := 0.0   # T390（T121 核 P3-1）：回合首末敌方掉的血（持续伤害等），计入 dealt_per_turn
	var mhp0 := logic.enemies.map(func(e): return float(e.mhp))
	for r in turns:
		var al := _alive_set(logic)
		var eh := _enemy_hp(logic)
		logic.start_turn()
		logic.take_turn_start_logs()
		foe_heal += maxf(0.0, _enemy_hp(logic) - eh)
		dot += maxf(0.0, eh - _enemy_hp(logic))
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
			var cmd := [null, null] if logic.take_cleared(u) else logic.decide(u)   # T390：同 baseline_dps 真打（首位被强制行动清掉的那格放弃）
			al = _alive_set(logic)
			eh = _enemy_hp(logic)
			logic.act(u, cmd[0], cmd[1])
			if u is XActor:
				dealt += maxf(0.0, eh - _enemy_hp(logic))
			else:
				foe_heal += maxf(0.0, _enemy_hp(logic) - eh)
				dealt += maxf(0.0, eh - _enemy_hp(logic))   # T390：敌人行动时掉的血（反伤、反击、敌方自伤）也算我方打的
			downs += _downs(al, _alive_set(logic))
			if logic.is_over():
				break
		if not logic.is_over():
			al = _alive_set(logic)
			eh = _enemy_hp(logic)
			logic.end_turn()
			_drain(logic, logic.troop_events(null, true))   # T390：回合末敌群页（残血变身、阶段页），同 baseline_dps 真打；原来漏了
			foe_heal += maxf(0.0, _enemy_hp(logic) - eh)
			dot += maxf(0.0, eh - _enemy_hp(logic))
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
		"dealt_per_turn": (dealt + dot) / maxf(1.0, done), "dot_per_turn": dot / maxf(1.0, done), "capped": not logic.is_over(), "foe_heal_per_turn": foe_heal / maxf(1.0, done), "foe_mhp": mhp0,
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
	var list := [] if snapshots != "" else _teams()
	if snapshots == "":
		_load_gears(list)
	var rows := []
	for f in floors:
		var per := []
		if snapshots != "":
			for st in _snap_calib_states(f):
				XState._become_current(st)
				var r := _calib_fight(st, _troop_for(st, f))
				r["team"] = st.get_meta("t390_team")
				r["label"] = str(st.get_meta("t239_team", ""))
				r["rep"] = int(st.get_meta("t239_rng", 0))
				per.append(r)
		for team in list:
			var gk := ",".join(team.map(func(x): return str(x)))
			if not _gears.has(gk) or not _gears[gk].has(int(f)):
				print("BRAND_SKIP floor=%d team=%s（这一队这一层掷不出装备，跳过）" % [f, gk])
				continue
			for rep in reps:
				var s := _calib_state(team, f, rep)
				var r := _calib_fight(s, int(GUARDIAN[f]))
				r["team"] = team
				r["rep"] = rep
				per.append(r)
		var n := per.size()
		if n == 0:
			print("BRAND_SKIP floor=%d（没有样本）" % f)
			continue
		var won := per.filter(func(r): return bool(r.won))
		var row := {"floor": f, "troop": GUARDIAN[f], "n": n, "won": won.size(), "win_rate": float(won.size()) / maxf(1.0, n),
			"turns_won_avg": _avg(won.map(func(r): return r.turns)), "turns_all_avg": _avg(per.map(func(r): return r.turns)),
			"downs_avg": _avg(per.map(func(r): return r.downs)), "harm_fights": per.filter(func(r): return int(r.harm) > 0).size(),
			"ripe_flag": per.all(func(r): return bool(r.ripe)), "boss_kind": per[0].kind if n else "", "carved_value": carved_value(f)}
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
			# T390（T121 核 P2-4）：折 8 回合按每场自己的回合数折（不再用「平均次数÷平均回合」），分母只算这一职责有人的场；
			# 另给只算分出胜负（没打满封顶回合）的场，封顶僵局的场把发作次数撑大
			var s8 := []
			var r8 := []
			var s8u := []
			var r8u := []
			for r in per:
				var cnt := int(r.roles.get(role, 0))
				if cnt <= 0:
					continue
				var k8 := 8.0 / maxf(1.0, float(r.turns)) / cnt
				var a8 := float(r.fits.get(role, {}).get("self", 0)) * k8
				var b8 := float(r.fits.get(role, {}).get("sear", 0)) * k8
				s8.append(a8)
				r8.append(b8)
				if not bool(r.capped):
					s8u.append(a8)
					r8u.append(b8)
			row["self8_" + role] = _avg(s8)
			row["sear8_" + role] = _avg(r8)
			row["self8u_" + role] = _avg(s8u)
			row["sear8u_" + role] = _avg(r8u)
			row["n8u_" + role] = s8u.size()
		row["dealt_per_turn_avg"] = _avg(per.map(func(r): return r.dealt_per_turn))
		row["dot_per_turn_avg"] = _avg(per.map(func(r): return r.dot_per_turn))
		row["capped"] = per.filter(func(r): return bool(r.capped)).size()
		row["foe_heal_per_turn_avg"] = _avg(per.map(func(r): return r.foe_heal_per_turn))
		row["foe_mhp"] = per[0].foe_mhp if n else []
		row["team_self8"] = _avg(per.map(func(r): return (int(r.fits.get("输出", {}).get("self", 0)) + int(r.fits.get("坦克", {}).get("self", 0)) + int(r.fits.get("辅助", {}).get("self", 0))) * 8.0 / maxf(1.0, float(r.turns))))
		row["team_self_avg"] = _avg(per.map(func(r): return int(r.fits.get("输出", {}).get("self", 0)) + int(r.fits.get("坦克", {}).get("self", 0)) + int(r.fits.get("辅助", {}).get("self", 0))))
		var kinds := {}
		for r in per:
			for k in r.kinds:
				kinds[k] = int(kinds.get(k, 0)) + int(r.kinds[k])
		row["kinds"] = kinds
		row["fights"] = per
		rows.append(row)
		print("BRAND_ROW floor=%d diff=%s carve=%s ripe=%s n=%d won=%d turnsWon=%.2f turnsAll=%.2f downs=%.2f selfOut=%.3f searOut=%.3f selfTank=%.3f searTank=%.3f selfSup=%.3f searSup=%.3f teamSelf=%.3f harmFights=%d capped=%d s8Out=%.3f r8Out=%.3f r8Tank=%.3f s8uOut=%.3f r8uOut=%.3f r8uTank=%.3f n8u=%d teamSelf8=%.3f dealt/t=%.0f dot/t=%.0f foeHeal/t=%.0f foeMhp=%s kind=%s ripeFlag=%s kinds=%s" % [
			f, difficulty, carve_mode, str(ripe_mode), n, won.size(), float(row.turns_won_avg), float(row.turns_all_avg), float(row.downs_avg),
			float(row.get("self_输出", 0)), float(row.get("sear_输出", 0)), float(row.get("self_坦克", 0)), float(row.get("sear_坦克", 0)),
			float(row.get("self_辅助", 0)), float(row.get("sear_辅助", 0)), float(row.team_self_avg), int(row.harm_fights), int(row.capped),
			float(row.get("self8_输出", 0)), float(row.get("sear8_输出", 0)), float(row.get("sear8_坦克", 0)),
			float(row.get("self8u_输出", 0)), float(row.get("sear8u_输出", 0)), float(row.get("sear8u_坦克", 0)), int(row.get("n8u_输出", 0)), float(row.team_self8),
			float(row.dealt_per_turn_avg), float(row.dot_per_turn_avg), float(row.foe_heal_per_turn_avg), str(row.foe_mhp), str(row.boss_kind), str(row.ripe_flag), JSON.stringify(kinds)])
	XEnemy.force_roll = -1.0
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"brand_set": brand_set, "snapshots": snapshots, "lineups": lineups, "rng_seeds": rng_seeds, "xcap": xcap, "strip": XGuardianRework.STRIP_XPARAM if XGuardianRework.STRIP else [], "pozhen_type": XTianqiElements.POZHEN_BY_TYPE, "difficulty": difficulty, "carve": carve_mode, "carved_brand": carved_brand, "other_brand": other_brand,
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
