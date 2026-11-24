extends Node
## T449 量数：skill_rework.json 里带 <passiveELUP01> 的被动，逐个角色单人打木桩（31 层守层者，同一只），修前（PHYS_AMP_ON_DECK=false）修后对照。
## 不是专项（不在 tests/ 顶层）；单独跑（带 --audio-driver Dummy）：
##   07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/t449_dummy.tscn -- [--out=<json>]
## 招式用固定底数 100000 的物理招（elementId 1）／无属性招（0）／普攻（-1），只看属性乘区变化；角色学会自己全部带 passiveELUP01 的被动。

var out_path := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	_run.call_deferred()


func _stub(id: int, elem: int) -> Dictionary:
	var prog := {
		"version": 1, "status": "pure", "locals": ["value"],
		"source": {"sha256": "t449d_%d" % id},
		"steps": [{"op": "set", "name": "value", "value": {"op": "literal", "value": 100000.0}}],
		"result": "value",
	}
	return {"id": id, "name": "T449D_%d" % id, "scope": 1, "hitType": 1, "stypeId": 1, "mpCost": 0, "tpCost": 0, "effects": [], "note": "", "meta": {},
		"damage": {"type": 1, "elementId": elem, "critical": false, "variance": 0, "formula": "100000", "formulaProgram": prog}}


func _touch(a: XActor) -> void:
	a.read_touch()
	a._pm_base = {}
	a.refresh_passive()


func _run() -> void:
	var rework: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/tianqi_data/skill_rework.json"))
	var rx := RegEx.create_from_string("<passiveELUP0?1\\s*:\\s*([+-]?[\\d.]+)%?\\s*>")
	var by_actor := {}
	for k in rework.skills:
		var v: Dictionary = rework.skills[k]
		var m := rx.search(str(v.get("note_add", "")))
		if m == null:
			continue
		var aid := int(v.get("actor", 0))
		if not by_actor.has(aid):
			by_actor[aid] = []
		by_actor[aid].append({"skill": int(k), "name": str(v.get("name", "")), "pct": float(m.get_string(1))})
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	s.map_id = 4
	XState.current = s
	var eid := int(XDB.table("Troops")[int(XGuardianRework.TROOPS[12])].members[0].enemyId)
	var b := XEnemy.new()
	b.setup(eid, 3)
	b.recover_all()
	var phys := _stub(98481, 1)
	var none := _stub(98482, 0)
	var atk := _stub(98483, -1)
	var rows := []
	var ids := by_actor.keys()
	ids.sort()
	for aid in ids:
		if aid <= 0 or XDB.rec("Actors", aid).is_empty():
			rows.append({"actor": aid, "skip": "no actor"})
			continue
		XTianqi._joining = true
		s.add_actor(aid)
		XTianqi._joining = false
		var a: XActor = s.actor(aid)
		if a == null:
			rows.append({"actor": aid, "skip": "add failed"})
			continue
		a.recover_all()
		for p in by_actor[aid]:
			a.learn_skill(int(p.skill))
		_touch(a)
		var elup := a.passive_values("passiveELUP01")
		var after := [XDamage.preview_hit(phys, a, b), XDamage.preview_hit(none, a, b), XDamage.preview_hit(atk, a, b)]
		XDamage.PHYS_AMP_ON_DECK = false
		var before := [XDamage.preview_hit(phys, a, b), XDamage.preview_hit(none, a, b), XDamage.preview_hit(atk, a, b)]
		XDamage.PHYS_AMP_ON_DECK = true
		var sum := 0.0
		for p in by_actor[aid]:
			sum += float(p.pct)
		var row := {"actor": aid, "name": str(XDB.rec("Actors", aid).get("name", "")), "passives": by_actor[aid], "table_sum_pct": sum,
			"read_elup01": elup, "before": before, "after": after,
			"phys_change_pct": (after[0] / before[0] - 1.0) * 100.0 if before[0] > 0.0 else 0.0,
			"attack_change_pct": (after[2] / before[2] - 1.0) * 100.0 if before[2] > 0.0 else 0.0,
			"none_change_pct": (after[1] / before[1] - 1.0) * 100.0 if before[1] > 0.0 else 0.0}
		rows.append(row)
		print("T449_DUMMY actor=%d %s sum=%.0f%% read=%s phys %.0f->%.0f (%+.1f%%) atk %+.1f%% none %+.1f%%" % [aid, row.name, sum, str(elup), before[0], after[0], row.phys_change_pct, row.attack_change_pct, row.none_change_pct])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"enemy": eid, "rows": rows}, "  "))
		f.close()
	XState.current = null
	print("T449_DUMMY_DONE actors=%d" % rows.size())
	get_tree().quit(0)
