extends "res://tests/virtual_player/t438_d271_benchmark.gd"
## 【cc·T533】防御通过率按主属性 开／关 对照量数：在 T438 D271 脚手架上跑，多两个参数：
##   --t533=on|off   XDamage.MAIN_STAT_PASS 开（默认）／关
##   --t533-list     每场开打前，按出战角色真实配装逐招打 T533_GEAR 行（目标双防取这一层守层者 setup 后的值，不含开战事件加成）：
##                   T533_GEAR|模板|层|种子|角色号|角色名|招号|招名|mode|卡上属性|目标物防|目标魔防|改前|A|B|物攻|魔攻|主属性A|主属性B
## 其余参数同 t438_d271_benchmark.gd。不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑务必带 --audio-driver Dummy、临时 HOME。

var _list := false
var _cur_tpl := ""


func _ready() -> void:
	var on := true
	for a in OS.get_cmdline_user_args():
		if a == "--t533=off":
			on = false
		elif a == "--t533-list":
			_list = true
	XDamage.MAIN_STAT_PASS = on
	print("T533_BENCH|switch=%s|list=%s" % ["on" if on else "off", str(_list)])
	super._ready()


func _build_state(tpl: String, diff: String, tinfo: Dictionary, f: int, lv: int, ln: String, sd: int) -> Dictionary:
	_cur_tpl = tpl
	return super._build_state(tpl, diff, tinfo, f, lv, ln, sd)


func _fight_floor(s: XState, f: int, ln: String, sd: int) -> Dictionary:
	if _list and f <= 33:
		XState._become_current(s)
		var troop: Dictionary = XDB.rec("Troops", int(GUARDIAN[f]))
		var eid := 0
		for m in troop.get("members", []):
			if int(m.get("enemyId", 0)) > 0:
				eid = int(m.enemyId)
				break
		var e := XEnemy.new().setup(eid, s.difficulty, 100.0)
		for a in s.battle_members():
			for item in a.skills():
				var d := XDamage.card_damage_spec(item, a)
				if d.is_empty() or not int(item.get("damage", {}).get("type", 0)) in [1, 2, 5, 6]:
					continue
				var mode := XDamage.item_mode(item)
				var w := [0.0, 1.0] if mode == "magical" else ([1.0, 0.0])
				if mode == "mixed":
					w = XDamage._mixed_weights(item, a, e, [])  # 同正式结算：按公式对物攻、魔攻微扰取权重
				var before: float = w[0] * XDamage.defense_rate(a.atk, e.def) + w[1] * XDamage.defense_rate(a.mat, e.mdf)
				var va := XDamage.main_stat_value(d, a, "A")
				var vb := XDamage.main_stat_value(d, a, "B")
				var pa: float = w[0] * XDamage.defense_rate(va, e.def) + w[1] * XDamage.defense_rate(va, e.mdf)
				var pb: float = w[0] * XDamage.defense_rate(vb, e.def) + w[1] * XDamage.defense_rate(vb, e.mdf)
				var stats := str(d.get("stats", {"atk": 1})) + (" max_of%s" % str(d.max_of) if d.has("max_of") else "")
				print("T533_GEAR|%s|%d|%d|%d|%s|%d|%s|%s|%s|%.0f|%.0f|%.4f|%.4f|%.4f|%.0f|%.0f|%.0f|%.0f" % [_cur_tpl, f, sd, int(a.actor_id), a.display_name(), int(item.id), str(item.get("name", "")), mode, stats.replace("|", "/"), e.def, e.mdf, before, pa, pb, a.atk, a.mat, va, vb])
	return super._fight_floor(s, f, ln, sd)
