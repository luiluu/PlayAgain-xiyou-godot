extends Node
var save_path := ""
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save_path = arg.substr(7)
	_run.call_deferred()

func _t(label: String, n: int, f: Callable) -> float:
	var t := Time.get_ticks_usec()
	for i in n:
		f.call()
	var us := float(Time.get_ticks_usec() - t)
	print("MICRO %-40s n=%d total_ms=%.2f per_us=%.3f" % [label, n, us / 1000.0, us / n])
	return us / n

func _run() -> void:
	XSave.dir_override = "user://t572_bench"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	XSave._load_data(d, 1, JSON.stringify(d))
	var s := XState.current
	var logic := XBattleLogic.new()
	logic.setup(454, s)
	var a: XActor = s.battle_members()[3]
	var ids: Array = []
	for m in s.battle_members():
		for id in m.skill_ids: ids.append(id)
	var sk: Array = XDB.table("Skills")
	var st: Array = XDB.table("States")
	var sids := range(1, mini(st.size(), 2000))
	var bad := 0
	var total := 0
	for nm in ["Actors", "Classes", "Skills", "Weapons", "Armors", "Enemies", "Troops", "States", "Animations"]:
		var tt: Array = XDB.table(nm)
		for i in range(-1, tt.size() + 2):
			XDB.XIYOU_REC_FAST = true
			var a1 := XDB.rec(nm, i)
			XDB.XIYOU_REC_FAST = false
			var a2 := XDB.rec(nm, i)
			XDB.XIYOU_REC_FAST = true
			total += 1
			if not is_same(a1, a2) and a1 != a2:
				bad += 1
				if bad < 10: print("DIFF ", nm, " ", i)
	print("EQUIV total=%d bad=%d" % [total, bad])
	XDB.XIYOU_REC_FAST = false
	var k0 := [0]
	_t("XDB.rec Skills SLOW", 100000, func(): k0[0] = (k0[0] + 1) % ids.size(); return XDB.rec("Skills", ids[k0[0]]))
	XDB.XIYOU_REC_FAST = true
	# loop overhead baseline
	_t("empty loop", 1000000, func(): pass)
	_t("XTianqi.active(s)", 1000000, func(): XTianqi.active(s))
	_t("XTianqiSecrets.on()", 300000, func(): XTianqiSecrets.on())
	_t("XXufeng.xiyou_save_on()", 300000, func(): XXufeng.xiyou_save_on())
	var k := [0]
	_t("raw Skills[id]", 200000, func(): k[0] = (k[0] + 1) % ids.size(); return sk[ids[k[0]]])
	_t("XDB.rec Skills party ids", 200000, func(): k[0] = (k[0] + 1) % ids.size(); return XDB.rec("Skills", ids[k[0]]))
	_t("XDB.rec States 1..2000", 200000, func(): k[0] = (k[0] + 1) % sids.size(); return XDB.rec("States", sids[k[0]]))
	_t("XDB.rec Weapons 1..50", 100000, func(): k[0] = (k[0] + 1) % 50; return XDB.rec("Weapons", k[0] + 1))
	for m in s.battle_members():
		var am: XActor = m
		print("actor ", am.actor_id, " ids=", am._skill_ids_now().size())
		_t("  _skill_ids_now %d" % am.actor_id, 300, func(): am._skill_ids_now())
		_t("  native_skill_ids %d" % am.actor_id, 300, func(): am.native_skill_ids())
		_t("  has_absorb_weapon %d" % am.actor_id, 300, func(): am.has_absorb_weapon())
		var nid := am.native_skill_ids()
		_t("  XTusuXuan.skill_ids %d" % am.actor_id, 300, func(): XTusuXuan.skill_ids(am, nid))
		_t("  XAlienBattle.skill_ids %d" % am.actor_id, 300, func(): XAlienBattle.skill_ids(am, nid))
		_t("  XGuyu.skill_ids %d" % am.actor_id, 300, func(): XGuyu.skill_ids(am, nid))
		_t("  XHeartsteel.skill_ids %d" % am.actor_id, 300, func(): XHeartsteel.skill_ids(am, nid))
		_t("  _skills_entry %d" % am.actor_id, 300, func(): XActor.skills_touch(); am._skills_entry())
		_t("  _skill_records %d" % am.actor_id, 100, func(): am._skill_records(nid))
		_t("  mhp (fresh) %d" % am.actor_id, 100, func(): XActor.read_touch(); return am.mhp)
		_t("  all_traits (fresh) %d" % am.actor_id, 100, func(): XActor.read_touch(); return am.all_traits())
	get_tree().quit(0)
