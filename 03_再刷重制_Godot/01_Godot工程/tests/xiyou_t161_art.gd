extends Node
var total := 0
var failed := 0
func check(label: String, ok: bool) -> void:
 total += 1
 if not ok:
  failed += 1
  print("FAIL ",label)
func _ready() -> void:
 var s := XState.new_game_blank()
 XState.current = s
 for id in [177,178]:
  var folder := "/xuan_v2/" if id==177 else "/hajimi_v2/"
  var a := s.actor(id)
  var look := XAppearance.for_battler(a)
  for motion in XAppearance.MOTIONS:
   for f in 3:
    var frame := look.frame(motion,f)
    check(str(id)+motion+str(f), str(frame.tex.resource_path).contains(folder) and frame.rect.size == Vector2(64,64) and XAppearance.profile(frame,motion).get("native_pixels",false))
  check("walk",XDB.img_path("characters",str(a.data().characterName)).contains(folder))
  check("book",XActorBook.sprite_path(id).contains(folder))
  check("missing fallback",XXuanTusuArt.xuan_path("characters","missing")=="")
  XXuanTusuArt.XUAN_ART=false
  XCat.ART=false
  var old := XAppearance.for_battler(a).frame("wait",0)
  check("rollback",not str(old.tex.resource_path).contains(folder))
  XXuanTusuArt.XUAN_ART=true
  XCat.ART=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out=") and DisplayServer.get_name() != "headless":
   for id in [177,178]:
    await capture(arg.substr(6).path_join(str(id)),id)
 print("TEST_RESULT=",JSON.stringify({"passed":total-failed,"total":total}))
 get_tree().quit(0 if failed==0 else 1)

func capture(dir: String, leader: int) -> void:
 DirAccess.make_dir_recursive_absolute(dir)
 XMessageBox.auto = true
 var s := XState.new_game_blank()
 XState.current = s
 # Cached actor table already contains Gojo; fixture skips campaign/recruit gates.
 XGojo.ENABLED = false
 XGojo.unlock_override = 1
 s.actor_max_level = 99
 s.switches[2494] = true
 s.party.clear()
 s.battle_slots.clear()
 for id in [176,177,178]:
  s.actor(id).change_level_mv(55)
  # fixture bypasses recruitment gates; no real saves touched.
  s.actor(id).recover_all()
 s.party = [176,177,178]
 s.battle_slots = [176,177,178]
 var battle := XBattleScene.new()
 battle.setup(1,true,false,XDB.map(5))
 add_child(battle)
 for i in 90:await get_tree().process_frame
 var evidence := []
 for a in battle.sprites:
  if a is XActor:
   var sp: XBattlerSprite = battle.sprites[a]
   var body := sp.sprite as Sprite2D
   evidence.append({"actor":a.actor_id,"scale":sp.body_scale,"filter":body.texture_filter,"path":body.texture.resource_path})
 check("battle.three_actors", evidence.size() == 3)
 var file := FileAccess.open(dir.path_join("render_evidence.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(evidence,"  "))
 file.close()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(dir.path_join("battle_wait.png"))
 for motion_name in ["swing", "damage"]:
  for a in battle.sprites:
   if a is XActor and a.actor_id == leader:
    var actor_sprite: XBattlerSprite = battle.sprites[a]
    actor_sprite.set_process(false)
    actor_sprite.set_motion(motion_name)
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(dir.path_join("battle_" + motion_name + ".png"))
 battle.queue_free()

 await get_tree().process_frame
 s.party = [leader]
 s.battle_slots = [leader]
 s.map_id = 4
 s.x = 12
 s.y = 12
 var map := XMapScene.new()
 add_child(map)
 for i in 15: await get_tree().process_frame
 map.player.direction = 6
 map.player.move_straight(6)
 for i in 5: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(dir.path_join("map_walk.png"))
 map.queue_free()
