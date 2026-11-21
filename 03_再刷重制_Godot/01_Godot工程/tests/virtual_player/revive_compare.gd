extends Node
## 【cc·T328】复活改前／改后对比（不进检查.sh）：读虚拟玩家某层存档，对这层守层者用无画面自动战斗真打（同 vp_fastforward.sample 的回合循环、
## 开战与回合末跑敌群事件，不提前收场），每份存档四组各打 --n 场（第 k 场各组同一个战斗种子）：
##   改前        存档原队、游戏原自动战斗（VPLogic.REVIVE 关）
##   只改出手    存档原队、虚拟玩家复活决策开（原队没人会复活技能时背包带 3 个复活道具，同逛店新规矩）
##   只改配队    换上一名会复活的辅助（team_builder 口径）、原自动战斗
##   改后        换上会复活的辅助＋复活决策开
##   开场倒一人·原出手／·改后：同「只改配队／改后」的队，开打就让攻击最高、不会复活的那人倒下（倒下不计入「倒下」次数），看复活有没有真放出来
## 换人：先用队伍里坐冷板凳的、会复活的辅助，没有才从本档候选里挑（等级同队、装备从被换下的人身上卸下后按游戏的「最强装备」重配）；
## 换下的是上场 4 人里换完仍合法、物攻魔攻较高项最低的那个。
## godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/revive_compare.tscn -- \
##   --snaps=<floor_10_2.json>,… [--n=3] [--turns=40] [--difficulty=jianxian] [--items=183:3] [--out=<json>]
const VPLogic := preload("res://tests/virtual_player/vp_battle_logic.gd")
const TB := preload("res://tests/virtual_player/team_builder.gd")
const Baseline := preload("res://tests/virtual_player/baseline_dps.gd")
const FF := preload("res://tests/virtual_player/vp_fastforward.gd")

var snaps: Array = []
var n := 3
var turns := 40
var difficulty := "jianxian"
var out_path := ""
var give_items := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--snaps="):
			snaps = Array(a.substr(8).split(","))
		elif a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--turns="):
			turns = int(a.substr(8))
		elif a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--items="):
			for kv in a.substr(8).split(","):
				var p := kv.split(":")
				give_items[int(p[0])] = int(p[1])
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	XConfig.path_override = "user://test_revive_compare/options.json"
	XConfig._loaded_path = ""
	XConfig.ensure_loaded()
	var rows := []
	for path in snaps:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
		if not parsed is Dictionary:
			print("CMP 读不到 %s" % path)
			continue
		var base := XState.from_dict(parsed)
		var floor := int(base.variable(20))
		var troop := int(Baseline.GUARDIAN.get(floor, 0))
		XState._become_current(base)
		for id in give_items:
			base.items[id] = int(base.items.get(id, 0)) + int(give_items[id])
		var swapped := XState.from_dict(base.to_dict())
		XState._become_current(swapped)
		var swap := _swap_in_reviver(swapped)
		print("CMP 层 %d 敌群 %d 原队 %s 换人 %s" % [floor, troop, str(base.battle_members().map(func(a): return a.actor_id)), JSON.stringify(swap)])
		# 只改出手：原队没人会复活技能时，照逛店新规矩（vp_growth.REVIVE_ITEM_KEEP）背包带上复活道具
		var with_items := XState.from_dict(base.to_dict())
		if not with_items.battle_members().any(func(a): return not VPLogic.free_revive_skills(a).is_empty()):   # 按存档里的真实等级判（核查 P1-1）
			var rid := int(VPLogic.revive_items_all()[0])
			with_items.items[rid] = maxi(int(with_items.items.get(rid, 0)), 3)
		XState._become_current(base)
		# 开场倒一人（核查 P1-1：自然打下来带奶妈的队没人倒，复活技能一次没触发）：换人后的队，开打就让攻击最高、不会复活的那人倒下，原自动战斗对复活层
		for arm in [["改前", base, false], ["只改出手", with_items, true], ["只改配队", swapped, false], ["改后", swapped, true],
				["开场倒一人·原出手", swapped, false, true], ["开场倒一人·改后", swapped, true, true]]:
			if arm[1] == swapped and swap.is_empty():
				continue
			var agg := {"floor": floor, "arm": arm[0], "team": (arm[1] as XState).battle_members().map(func(a): return a.actor_id), "fights": []}
			for k in n:
				var r := _fight(arm[1], troop, bool(arm[2]), k, arm.size() > 3)
				agg.fights.append(r)
				print("CMP   层 %d %s 第 %d 场：%s %d 回合 技能复活 %d 道具复活 %d 被救起 %s 倒下 %s 收场倒 %d" % [floor, arm[0], k + 1, "赢" if r.won else "输", r.turns, r.casts, r.items, JSON.stringify(r.raised), JSON.stringify(r.falls), r.dead_end])
			rows.append(_sum(agg))
	print("CMP_TABLE")
	print("| 层 | 组 | 上场 | 胜 | 平均回合 | 技能复活／场 | 道具复活／场 | 被救起／场 | 倒下／场 | 谁倒几次（合计） |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for r in rows:
		print("| %d | %s | %s | %d/%d | %.1f | %.1f | %.1f | %.1f | %.1f | %s |" % [r.floor, r.arm, str(r.team), r.wins, r.n, r.turns, r.casts, r.items, r.raised, r.falls, r.who])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
	get_tree().quit.call_deferred(0)


func _sum(agg: Dictionary) -> Dictionary:
	var fs: Array = agg.fights
	var who := {}
	var tot := {"wins": 0, "turns": 0.0, "casts": 0.0, "items": 0.0, "raised": 0.0, "falls": 0.0}
	for r in fs:
		tot.wins += 1 if r.won else 0
		tot.turns += r.turns
		tot.casts += r.casts
		tot.items += r.items
		for id in r.raised:
			tot.raised += r.raised[id]
		for id in r.falls:
			tot.falls += r.falls[id]
			who[id] = int(who.get(id, 0)) + int(r.falls[id])
	var m := maxf(1.0, fs.size())
	return {"floor": agg.floor, "arm": agg.arm, "team": agg.team, "n": fs.size(), "wins": tot.wins, "turns": tot.turns / m, "casts": tot.casts / m,
		"items": tot.items / m, "raised": tot.raised / m, "falls": tot.falls / m, "who": JSON.stringify(who), "fights": fs}


## 换上一名会复活的辅助；返回 {out, in, from}，配不出来返回 {}
func _swap_in_reviver(st: XState) -> Dictionary:
	var field: Array = st.battle_members().map(func(a): return int(a.actor_id))
	if st.battle_members().any(func(a): return not VPLogic.free_revive_skills(a).is_empty()):
		return {"note": "原队已有会复活的"}
	# 换上来的人按队伍等级判会不会复活（核查 P1-1：30 级绯红蔷薇还没学圣光救赎，35 级才学）
	var lv0 := int(st.battle_members()[0].level) if not st.battle_members().is_empty() else TB.LEVEL
	var pool := []
	for id in st.party:   # 冷板凳上的先（虚拟玩家手里本来就有）：看它自己现在的等级
		if not field.has(int(id)) and int(id) != int(st.battle_slots[XTianqi.HELPER_SLOT]) and TB.role_of(int(id)) == "辅助" \
				and not VPLogic.free_revive_skills(st.actor(int(id))).is_empty():
			pool.append([int(id), "冷板凳"])
	var others := (TB.candidates(difficulty)["辅助"] as Array).filter(func(x): return TB.can_revive(int(x), lv0) and not st.party.has(int(x)))
	others.sort_custom(func(x, y): return TB.bulk(int(x)) > TB.bulk(int(y)))
	for id in others:
		pool.append([int(id), "候选池"])
	var outs := field.duplicate()
	outs.sort_custom(func(x, y): return _power(st.actor(int(x))) < _power(st.actor(int(y))))
	for p in pool:
		for o in outs:
			var team := field.duplicate()
			team[team.find(o)] = p[0]
			if not TB.legal(team, difficulty):
				continue
			var lv := int(st.actor(int(o)).level)
			if not st.party.has(int(p[0])):
				st.party.append(int(p[0]))
				var a := st.actor(int(p[0]))
				a.change_level_mv(lv)
			XEquipment.clear(st, st.actor(int(o)))
			st.set_battle_slot(st.battle_slots.find(int(o)), int(p[0]))
			st.rearrange_actors()
			XEquipment.optimize(st, st.actor(int(p[0])))
			var got := st.actor(int(p[0]))
			return {"out": int(o), "in": int(p[0]), "from": p[1], "level": int(got.level),
				"skills": VPLogic.free_revive_skills(got).map(func(s): return "%d %s" % [int(s.id), str(s.get("name", ""))])}
	return {}


static func _power(a: XActor) -> float:
	return maxf(float(a.param(2)), float(a.param(4)))


func _fight(st: XState, troop: int, revive: bool, k: int, knock := false) -> Dictionary:
	var copy := XState.from_dict(st.to_dict())
	XState._become_current(copy)
	for a in copy.members():
		a.recover_all()
	VPLogic.REVIVE = revive
	var logic = VPLogic.new()
	logic.setup(troop, copy, XBattleRandom.create("%016x" % (0x7328_0000 + k)))
	logic.auto = true
	FF._drain(logic, logic.troop_events())
	if knock:
		var pick = null
		for a in logic.actors:
			if a.is_alive() and VPLogic.free_revive_skills(a).is_empty() and (pick == null or _power(a) > _power(pick)):
				pick = a
		if pick != null:
			pick.add_state(1)
	var falls := {}
	var raised := {}
	var was := {}
	for a in logic.actors:
		was[a] = a.is_dead()
	var note := func():
		for a in logic.actors:
			var d: bool = a.is_dead()
			if d and not bool(was.get(a, false)):
				falls[a.actor_id] = int(falls.get(a.actor_id, 0)) + 1
			elif not d and bool(was.get(a, false)):
				raised[a.actor_id] = int(raised.get(a.actor_id, 0)) + 1
			was[a] = d
	for r in turns:
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		var first := true
		while count < 120:
			var u = logic.next_subject()
			FF._drain(logic, logic.troop_events(u if first else null))
			first = false
			note.call()
			if u == null or logic.is_over():
				break
			count += 1
			var cmd: Array = logic.decide(u)
			logic.act(u, cmd[0], cmd[1])
			note.call()
			if logic.is_over():
				break
		if logic.is_over():
			break
		logic.end_turn()
		FF._drain(logic, logic.troop_events(null, true))
		note.call()
		if logic.is_over():
			break
	var won: bool = logic.is_won() and not logic.is_lost()
	var out := {"won": won, "turns": int(logic.turn), "casts": int(logic.revive_casts), "items": int(logic.revive_items), "falls": falls, "raised": raised,
		"dead_end": logic.actors.filter(func(a): return a.is_dead()).size()}
	logic.end_battle(0 if won else 2)
	VPLogic.REVIVE = true
	return out
