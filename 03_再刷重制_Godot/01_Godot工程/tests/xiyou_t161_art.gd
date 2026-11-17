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
 for id in [177]:
  var a := s.actor(id)
  var look := XAppearance.for_battler(a)
  for motion in XAppearance.MOTIONS:
   for f in 3:
    var frame := look.frame(motion,f)
    check(str(id)+motion+str(f), str(frame.tex.resource_path).contains("/xuan_v2/") and frame.rect.size == Vector2(64,64) and XAppearance.profile(frame,motion).get("native_pixels",false))
  check("walk",XDB.img_path("characters",str(a.data().characterName)).contains("/xuan_v2/"))
  check("book",XActorBook.sprite_path(id).contains("/xuan_v2/"))
  check("missing fallback",XXuanTusuArt.xuan_path("characters","missing")=="")
  XXuanTusuArt.XUAN_ART=false
  var old := XAppearance.for_battler(a).frame("wait",0)
  check("rollback",not str(old.tex.resource_path).contains("/xuan_v2/"))
  XXuanTusuArt.XUAN_ART=true
 print("TEST_RESULT=",JSON.stringify({"passed":total-failed,"total":total}))
 get_tree().quit(0 if failed==0 else 1)
