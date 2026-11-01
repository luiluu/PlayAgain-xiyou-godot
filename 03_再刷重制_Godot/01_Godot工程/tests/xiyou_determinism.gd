extends Node
## Real OTB/AI/sequence execution with owned rule/reward/equipment streams.
class QuietBattle extends XBattleScene:
 func _main() -> void:
  pass
var checks := 0
var failures := []
var noise := false
var noise_draws := 0
func check(label: String, ok: bool, detail = null) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  print("FAIL ", label, " ", detail)
func _ready() -> void:
 _run.call_deferred()
func _physics_process(_delta: float) -> void:
 if noise:
  randf(); randi(); randf(); randi()
  noise_draws += 4
func same(a, b) -> bool:
 return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func _run() -> void:
 XSave.dir_override = "user://test_xiyou_determinism"
 XConfig.path_override = XSave.dir().path_join("options.json")
 Engine.physics_ticks_per_second = 600
 # Fixture trait envelopes keep three real rounds alive. Native skills/sequences,
 # animation sound timings, smart AI and rated enemy choices remain intact.
 var enemy_data := XDB.rec("Enemies", 1)
 enemy_data.dropItems = [{"kind":1,"dataId":1,"denominator":1},{"kind":2,"dataId":56,"denominator":1}]
 enemy_data.actions = [{"skillId":1,"rating":5,"conditionType":0,"conditionParam1":0,"conditionParam2":0}, {"skillId":104,"rating":4,"conditionType":0,"conditionParam1":0,"conditionParam2":0}]
 enemy_data.traits.append_array([{"code":22,"dataId":5,"value":0.17},{"code":22,"dataId":6,"value":0.19},{"code":61,"dataId":0,"value":0.25}])
 XEnemy.force_roll = -1
 var outputs := []
 for advance in [false, true]:
  var base := await replay(20261019, false, false, false, false, 1, 30.0, advance)
  outputs.append(base)
  for row in [[true,false,false,false,1,30.0],[true,true,false,false,1,30.0],[true,false,true,false,2,20.0],[true,true,true,true,1,30.0],[true,true,true,false,3,15.0]]:
   var got := await replay(20261019,row[0],row[1],row[2],row[3],row[4],row[5],advance)
   check("visual_matrix:" + str([advance,row]), same(got,base), [str(base).sha256_text(),str(got).sha256_text()])
  var repeat := await replay(20261019,false,false,false,false,1,30.0,advance)
  check("same_seed:" + str(advance), same(repeat,base))
  var different := await replay(20261020,false,false,false,false,1,30.0,advance)
  check("different_seed:" + str(advance), not same(different.journal,base.journal))
 check("rule_parameter_inventory", outputs[0].items.size()>0 and outputs[1].items.size()>0)
 check("actual_wait_noise", noise_draws > 0)
 Engine.time_scale = 1.0
 Engine.physics_ticks_per_second = 60
 noise = false
 for player in XSound._players:
  if is_instance_valid(player):
   player.stop();player.stream = null
 await get_tree().create_timer(0.5,true,false,true).timeout
 print("TEST_RESULT=" + JSON.stringify({"passed":checks-failures.size(),"total":checks}))
 get_tree().quit(0 if failures.is_empty() else 1)
func replay(trial_seed: int, visual: bool, icons: bool, camera: bool, sound: bool, speed: int, scale: float, advance: bool) -> Dictionary:
 Engine.time_scale = scale
 noise = visual
 XConfig.set_flag("CombatSkillAnimation",visual)
 XConfig.set_flag("MOG_TrPopUpBattle_Key",icons)
 XConfig.set_flag("battleCamera",camera)
 XConfig.set_battle_speed(speed)
 XAudio.apply_volumes({"seVolume":100 if sound else 0})
 var s := XState.new_game(3,1,[])
 s.random_master = XRandomStream.hex64(trial_seed)
 s.orb_seed = 7319
 s.hang_up_active = visual and camera and sound
 s.hang_up_origin = Vector2i.ZERO
 XHangUp.settings(s).fastFt = s.hang_up_active
 var actor := s.actor(1)
 # Native req_level: weapon56 is released below level3; keep the three-round fixture equipped.
 actor.change_level_mv(3)
 var gear := XGear.template("weapon",56)
 gear.params[0] = 1000000
 gear.traits.append_array([{"code":22,"dataId":6,"value":0.18},{"code":22,"dataId":5,"value":0.16},{"code":61,"dataId":0,"value":0.25},{"code":64,"dataId":XMapTransfer.DROP_ITEM_DOUBLE,"value":1}])
 actor.equips[0] = gear
 actor.learn_skill(104)
 actor.refresh_passive();actor.recover_all()
 var initial := s.to_dict().duplicate(true)
 var scene: QuietBattle
 var logic: XBattleLogic
 if visual:
  scene = QuietBattle.new()
  scene.setup(2,true,false,{})
  add_child(scene)
  logic = scene.logic
 else:
  logic = XBattleLogic.new()
  logic.setup(2,s)
 logic.auto = true
 logic.advance_loot_on_collapse = advance
 for e in logic.enemies:
  e._rates[0] *= 1000
  # 掉落照原版（dev.257：dropItemRate／分母，0.2 底）后要让夹具必掉：上面装备给双倍掉落（rate 1）、这里分母改 1
  for d: Dictionary in e.data().get("dropItems", []):
   d.denominator = 1
  e.recover_all()
 logic.sequence_add_state(logic.enemies[1],5) # real 3–5 turn state duration
 var all_logs := []
 var sound_before := XSound.play_count + MVAnimation.se_play_count
 var commands := []
 var rounds := []
 for round_index in range(3):
  logic.start_turn()
  var count := 0
  while true:
   var u := logic.next_subject()
   if u == null:break
   count += 1
   if count > 50:
    check("finite_turn",false)
    break
   var cmd := logic.decide(u)
   # Real physical multi-hit sequence once per round, plus smart AI for added actions.
   if u == actor and count == 1:
    cmd = [XDB.rec("Skills",104),null]
   commands.append([round_index,logic.stable_id(u),int(cmd[0].id) if cmd[0] != null else 0])
   var before := logic.random.snapshot()
   XDamage.eval_formula(XDB.rec("Skills",857),actor,logic.enemies[0],logic.vars())
   check("preview_zero_draw",same(before,logic.random.snapshot()))
   var logs := logic.act(u,cmd[0],cmd[1])
   all_logs.append_array(logs)
   if visual:await scene._play(logs)
  var end := logic.end_turn()
  all_logs.append_array(end)
  if visual:await scene._play(end)
  if round_index==0:
   var early: XEnemy=logic.enemies[0]
   early.hp=1
   var early_logs:=logic.act(actor,XDB.rec("Skills",1),early)
   all_logs.append_array(early_logs)
   if visual:await scene._play(early_logs)
   if early.is_alive():
    logic.sequence_gain(early,"HP",-early.hp)
    logic.resolve_collapses()
   check("early_inventory_rule",(s.gear.size()>0)==advance,{"advance":advance,"visual":visual,"gear":s.gear.size(),"dead":early.is_dead(),"hp":early.hp,"drop_lock":logic.drop_lock})
  rounds.append([logic.turn,actor.hp,actor.mp,actor.tp,logic.enemies.map(func(e):return [e.hp,e.mp,e.tp,e.state_ids.duplicate(),e.state_turns.duplicate(true)])])
 # At least two actual collapse opportunities and one persistent equipment grant.
 for e in logic.enemies:
  if e.is_dead():continue
  e.hp = 1
  var logs := logic.act(actor,XDB.rec("Skills",1),e)
  all_logs.append_array(logs)
  if visual:await scene._play(logs)
  if e.is_alive():
   logic.sequence_gain(e,"HP",-e.hp)
   logic.resolve_collapses()
  var before := [logic.random.snapshot(),s.items.duplicate(true),s.gear.duplicate(true)]
  logic.resolve_collapse(e)
  if visual:scene._enemy_collapsed(e)
  check("collapse_token",same(before,[logic.random.snapshot(),s.items,s.gear]))
 var reward := logic.rewards()
 logic.grant(reward)
 var granted := s.to_dict().duplicate(true)
 logic.grant(reward)
 check("reward_once",same(granted,s.to_dict()))
 var artifact := XBattleReplay.record(logic,initial,commands,all_logs)
 check("replay_identity",XBattleReplay.valid(artifact))
 var bad := artifact.duplicate(true)
 bad.identity.engine = "different-engine"
 check("replay_mismatch",not XBattleReplay.valid(bad))
 check("real_three_rounds",rounds.size()==3 and logic.turn==3 and commands.size()>=9)
 check("persistent_gear_reward",not s.gear.is_empty())
 check("duration_consumed",logic.random.rule.journal.any(func(row):return row.reason=="state_duration"))
 check("streams_clean",logic.random.rule.error.is_empty() and logic.random.reward.error.is_empty())
 if visual and sound:
  check("real_animation_audio",XSound.play_count + MVAnimation.se_play_count > sound_before)
 var out := {"rounds":rounds,"commands":commands,"logs":artifact.logs,"journal":artifact.journal,"enemies":artifact.enemies,
  "reward":reward,"items":s.items.duplicate(true),"gear":s.gear.duplicate(true),"rom":s.rom.duplicate(true),"random":s.runtime_random_snapshot(),"actors":s.to_dict().actors}
 logic.end_battle()
 if visual:scene.free()
 return out
