extends "res://tests/virtual_player/t438_d271_benchmark.gd"
## 【cc·T534】老承伤率对必中招 开／关 对照量数：在 T438 D271 脚手架上跑，多两个参数：
##   --t534=on|off   XDamage.CERTAIN_INCOMING 开（默认）／关
##   --t534-scan     每场开打前打一行守层者招表（伤害招里必中几个、物理几个、魔法几个），再逐个出战角色打开战前的物承、魔承、必中承伤率（开／关）：
##                   T534_ENEMY|模板|层|种子|敌号|伤害招数|必中|物理|魔法|必中招号
##                   T534_ACTOR|模板|层|种子|角色号|角色名|物承|魔承|必中开|必中关
## 其余参数同 t438_d271_benchmark.gd。不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑务必带 --audio-driver Dummy、临时 HOME。

var _scan := false
var _cur_tpl := ""


func _ready() -> void:
	var on := true
	for a in OS.get_cmdline_user_args():
		if a == "--t534=off":
			on = false
		elif a == "--t534-scan":
			_scan = true
	XDamage.CERTAIN_INCOMING = on
	print("T534_BENCH|switch=%s|scan=%s" % ["on" if on else "off", str(_scan)])
	super._ready()


func _build_state(tpl: String, diff: String, tinfo: Dictionary, f: int, lv: int, ln: String, sd: int) -> Dictionary:
	_cur_tpl = tpl
	return super._build_state(tpl, diff, tinfo, f, lv, ln, sd)


func _fight_floor(s: XState, f: int, ln: String, sd: int) -> Dictionary:
	if _scan and f <= 33:
		XState._become_current(s)
		var troop: Dictionary = XDB.rec("Troops", int(GUARDIAN[f]))
		for m in troop.get("members", []):
			var eid := int(m.get("enemyId", 0))
			if eid <= 0:
				continue
			var n := 0
			var cert: Array = []
			var ph := 0
			var mg := 0
			for act in XDB.rec("Enemies", eid).get("actions", []):
				var it: Dictionary = XDB.rec("Skills", int(act.get("skillId", 0)))
				if it.is_empty() or not int(it.get("damage", {}).get("type", 0)) in [1, 5]:
					continue
				n += 1
				match int(it.get("hitType", 0)):
					0: cert.append(int(it.id))
					1: ph += 1
					2: mg += 1
			print("T534_ENEMY|%s|%d|%d|%d|%d|%d|%d|%d|%s" % [_cur_tpl, f, sd, eid, n, cert.size(), ph, mg, ",".join(cert.map(func(x): return str(x)))])
		var was := XDamage.CERTAIN_INCOMING
		for a in s.battle_members():
			var fr := {"incomingMultiplier": 1.0, "physicalIncomingPierce": 0.0, "magicalIncomingPierce": 0.0}
			XDamage.CERTAIN_INCOMING = true
			var r_on := XDamage._calc_incoming(a, false, false, "normal", fr, true)
			XDamage.CERTAIN_INCOMING = false
			var r_off := XDamage._calc_incoming(a, false, false, "normal", fr, true)
			XDamage.CERTAIN_INCOMING = was
			print("T534_ACTOR|%s|%d|%d|%d|%s|%.4f|%.4f|%.4f|%.4f" % [_cur_tpl, f, sd, int(a.actor_id), a.display_name(), a.pdr, a.mdr, r_on, r_off])
	return super._fight_floor(s, f, ln, sd)
