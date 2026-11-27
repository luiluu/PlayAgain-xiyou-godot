#!/bin/zsh
# instrument.sh <stub tree> <src project>
T=$1; SRC=$2; P=$(dirname $0)
for f in modes/xiyou/core/actor.gd modes/xiyou/core/battler.gd modes/xiyou/battle/battle_logic.gd modes/xiyou/core/resource_context.gd modes/xiyou/core/state_effects.gd; do cp $SRC/$f $T/$f; done
cd $T
python3 - <<'PY'
p='modes/xiyou/core/actor.gd'
s=open(p).read()
helper='''
static var PROF := {}
static func _prof_add(k: String, v: int) -> void:
	PROF[k] = PROF.get(k, 0) + v
static var PROF_STACK := false
static var _pst: Array = []
static func _prof_enter(k: String) -> void:
	_pst.append([k, Time.get_ticks_usec(), 0])
static func _prof_exit(k: String) -> void:
	var fr = _pst.pop_back()
	var incl: int = Time.get_ticks_usec() - fr[1]
	_prof_add("X_" + k, incl - fr[2])
	_prof_add("N_" + k, 1)
	if not _pst.is_empty():
		_pst[-1][2] += incl
'''
i=s.index('\nfunc _skill_ids_now()')
s=s[:i]+helper+s[i:]
s=s.replace('''static func state_touch(id: int) -> void:
''','''static func state_touch(id: int) -> void:
	_prof_add("st_%s_%d" % ["b" if _batch_depth > 0 else "o", XBattler.state_class(id)], 1)
''')
s=s.replace('''static func read_touch() -> void:
''','''static func read_touch() -> void:
	_prof_add("read_touch", 1)
''')
open(p,'w').write(s)
PY
I=$P/inject.py
python3 $I modes/xiyou/core/actor.gd _skill_ids_now _skill_records _skills_entry native_skill_ids _all_traits_now _param_now _refresh_passive_now stat_equips param_rate param_plus param_base _passive_values_now _traits_set_now passive_state_resists _xparam_now _sparam_now _max_tp_now trait_objects equip_list $EXTRA_ACTOR >/dev/null
python3 $I modes/xiyou/core/battler.gd states param_refresh refresh_resources add_state remove_state element_rate traits_sum traits_pi traits $EXTRA_BATTLER
python3 $I modes/xiyou/battle/battle_logic.gd _forced_run execute _tick_states _sync_orders _movable_snapshot _mastery_end _drive_events _apply _effect _apply_effect _calculate_damage _damage_value _execute_hp_damage sequence_add_state _state_add _refresh_battler item_hit _invoke_normal targets_for $EXTRA_LOGIC
python3 $I modes/xiyou/core/resource_context.gd _refresh_base _refresh_type_after refresh
python3 $I modes/xiyou/core/state_effects.gd run_one
