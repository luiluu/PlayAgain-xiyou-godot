extends Node
## 心魔探针（T315，D244 甲）：心魔（立境，敌群 901／770）跟同层守层者同一口径各打一遍，报胜负。不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/xinmo_probe.tscn -- \
##     [--passed=5,10,15,20,25,30] [--teams=3] [--turns=40] [--seed=20261113] [--sets=20] [--battles=10] [--xinmo=off] [--no-guardian] [--out=<json>]
## 口径（同 T314 评估、baseline_dps --shape=3s1w）：3 强 1 弱实队、按层等级、掷中位装备（c_tier.floor_gears）、本人法宝、输出职责刻印 75%、天平酒。
## 存档照天启篇开局置 DCultyL（敌人特性 22 等 ×2，同 T314）。
## 「通关 C 层」：等级、装备、法宝取 C＋1 层，变量 20＝C＋1（XZhenqi.progress_floor＝C，心魔参照第 C 层守层者）。
## 每队两场：心魔（打心魔的是队里第一个输出职责的人，1 号走 770）、同层守层者（第 C 层那场）；都照游戏跑敌群事件，自动战斗打到分出胜负，最多 turns 回合。
## --keep-xparam：心魔不去守层者的闪避、魔闪、每回合回血（XGuardianRework.XINMO_DROP_XPARAM 置空），量胜率差是不是这几项带来的。
## 心魔「立住」＝赢且打心魔的人活着（XZhenqi.on_victory 同口径）。--xinmo=off：关 XGuardianRework.XINMO（心魔照原版，对照用）。
## 输出每行：XINMO passed=C team=[…] who=立境人 xinmo=won/stand/turns guardian=won/turns，末尾汇总 XINMO_SUMMARY。

const BD := preload("res://tests/virtual_player/baseline_dps.gd")
const CT := preload("res://tests/virtual_player/c_tier.gd")

var passed: Array = [5, 10, 15, 20, 25, 30]
var teams := 3
var turns := 40
var seed_v := 20261113
var sets := 20
var battles := 10
var brand_pct := 75.0
var guardian := true
var out_path := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--passed="):
			passed = Array(a.substr(9).split(",")).map(func(x): return int(x))
		elif a.begins_with("--teams="):
			teams = int(a.substr(8))
		elif a.begins_with("--turns="):
			turns = int(a.substr(8))
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--sets="):
			sets = int(a.substr(7))
		elif a.begins_with("--battles="):
			battles = int(a.substr(10))
		elif a == "--xinmo=off":
			XGuardianRework.XINMO = false
		elif a == "--keep-xparam":
			XGuardianRework.XINMO_DROP_XPARAM = []   # 心魔照守层者留着闪避、魔闪、每回合回血（对照：差距是不是这几项）
		elif a == "--no-guardian":
			guardian = false
		elif a.begins_with("--out="):
			out_path = a.substr(6)
	_run.call_deferred()


func _state(team: Array, gears: Dictionary, c: int) -> XState:
	var f := c + 1
	var s := CT.build_state(team, gears[f], f, BD.level_cap(f), BD.fabao_cap(f), seed_v, brand_pct, true)
	s.map_id = 4   # 大厅（闭关之所在大厅）
	for k in range(1, 9):   # 天启篇开局照公共事件 714 置难度怪物属性（借普通＝DCultyL3，仓库倍率 ×2；c_tier.build_state 没置）
		s.flags["DCultyL%d" % k] = k == XTianqi.legacy_of(CT.DIFFICULTY)
	return s


## 打心魔的人：队里第一个输出职责（刻了印的）的人，没有就第一个
static func trial_actor(s: XState, team: Array) -> XActor:
	for id in team:
		if str(XTianqiBase.line_data().get("actors", {}).get(str(id), {}).get("role", "")) == "输出":
			return s.actor(int(id))
	return s.actor(int(team[0]))


## 按游戏开心魔战（XZhenqi._brand_trial 同样的 pending_trial），返回敌群号
static func start_xinmo(s: XState, a: XActor, c: int) -> int:
	var troop := int(XZhenqi.HEART_TROOP.get(a.actor_id, 0))
	if troop == 0:
		troop = int(XZhenqi.TRIAL_TROOP["心魔"])
	XZhenqi.pending_trial = {"actorId": a.actor_id, "target": maxi(1, c / 5), "ref": XZhenqi.trial_ref(s, 1), "kind": "心魔", "troopId": troop, "brand": true}
	return troop


func _fight(s: XState, troop: int, who: XActor = null) -> Dictionary:
	XState.current = s
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create(str(s.random_master)))
	logic.auto = true
	var foe: Array = logic.enemies.filter(func(e): return not e.hidden)
	var info := {"enemy": foe.map(func(e): return e.display_name()), "hp": foe.map(func(e): return int(e.mhp)),
		"def": foe.map(func(e): return [int(e.param(3)), int(e.param(5))]), "atkScale": foe.map(func(e): return e.output_scale),
		"eva": foe.map(func(e): return snappedf(e.xparam(1), 0.01)), "hrg": foe.map(func(e): return snappedf(e.xparam(7), 0.01)),
		"harmRe": foe.map(func(e): return (e.passive_cache().harmRe as Dictionary).values().reduce(func(m, v): return maxf(m, float(v)), 0.0)),
		"skills": foe.map(func(e): return e.data().get("actions", []).map(func(x): return int(x.skillId)))}
	BD._drain(logic, logic.troop_events())
	var done := 0
	for r in turns:
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		var first := true
		while count < 80:
			var u := logic.next_subject()
			BD._drain(logic, logic.troop_events(u if first else null))
			first = false
			if u == null or logic.is_over():
				break
			count += 1
			var cmd := logic.decide(u)
			logic.act(u, cmd[0], cmd[1])
			if logic.is_over():
				break
		done += 1
		if logic.is_over():
			break
		logic.end_turn()
	var left := 0.0
	for e in logic.enemies:
		left += maxf(0.0, float(e.hp)) if e.is_alive() else 0.0
	info["won"] = logic.is_won()
	info["lost"] = logic.is_lost()
	info["turns"] = done
	info["enemyLeft"] = int(left)
	info["stand"] = logic.is_won() and who != null and who.hp > 0
	XZhenqi.battle = {}
	XZhenqi.pending_trial = {}
	return info


func _run() -> void:
	XEnemy.force_roll = 100.0
	XMessageBox.auto = true
	var list := CT.pick_teams(teams, seed_v, 3, 1)
	var floors: Array = passed.map(func(c): return int(c) + 1)
	var rows := []
	var sum := {"xinmo": 0, "stand": 0, "guardian": 0, "n": 0}
	for team in list:
		var gears := CT.floor_gears(team, floors, sets, battles, seed_v, func(x): return BD.level_cap(int(x)))
		for c in passed:
			var s := _state(team, gears, int(c))
			var who := trial_actor(s, team)
			var troop := start_xinmo(s, who, int(c))
			var xm := _fight(s, troop, who)
			var gd := {}
			if guardian:
				gd = _fight(_state(team, gears, int(c)), int(XGuardianRework.TROOPS[int(c)]))
			rows.append({"passed": c, "team": team, "who": who.actor_id, "troop": troop, "xinmo": xm, "guardian": gd})
			sum.n += 1
			sum.xinmo += 1 if bool(xm.won) else 0
			sum.stand += 1 if bool(xm.stand) else 0
			sum.guardian += 1 if bool(gd.get("won", false)) else 0
			print("XINMO passed=%d team=%s who=%d troop=%d xinmo=won:%s/stand:%s/t%d hp=%s def=%s atk=%s eva=%s hrg=%s harmRe=%s left=%d skills=%s | guardian=%s" % [int(c), str(team), who.actor_id, troop,
				str(xm.won), str(xm.stand), int(xm.turns), str(xm.hp), str(xm.def), str(xm.atkScale), str(xm.eva), str(xm.hrg), str(xm.harmRe), int(xm.enemyLeft), str(xm.skills),
				("won:%s/t%d hp=%s def=%s atk=%s" % [str(gd.won), int(gd.turns), str(gd.hp), str(gd.def), str(gd.atkScale)]) if not gd.is_empty() else "-"])
	XEnemy.force_roll = -1.0
	print("XINMO_SUMMARY drop_xparam=%s xinmo_on=%s won=%d/%d stand=%d/%d guardian_won=%d/%d" % [str(XGuardianRework.XINMO_DROP_XPARAM), str(XGuardianRework.XINMO), int(sum.xinmo), int(sum.n), int(sum.stand), int(sum.n), int(sum.guardian), int(sum.n)])
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"xinmo": XGuardianRework.XINMO, "seed": seed_v, "teams": list, "turns": turns, "rows": rows, "summary": sum}, "\t"))
	get_tree().quit(0)
