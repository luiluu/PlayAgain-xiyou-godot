extends Node
class ProbeActor extends XActor:
 var fixed := [10000.0, 1000.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
 var mastery := 0
 var fixed_cri := 0.0
 func param(i: int) -> float:
  return fixed[i]
 func xparam(i: int) -> float:
  return fixed_cri if i == 2 else 0.0
 func skillMasteryLevel(_id: int) -> int:
  return mastery
var checks := 0
var failures := []
func check(label: String, ok: bool, detail = null) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  if failures.size() < 8: print("FAIL ", label, " ", detail)
func _ready() -> void:
 var reference = XDB.load_json("oracle/formula_equipment.json")
 check("source_24x14", reference is Dictionary and reference.cases.size() == 336)
 var ids := {}
 for c in reference.cases:
  check(c.id + ".clean", c.errors.is_empty())
  if not c.errors.is_empty(): continue
  var item := XDB.rec("Skills", int(c.setup.skill))
  ids[int(item.id)] = true
  var a := ProbeActor.new()
  a.actor_id = 1
  a.fixed = c.setup.params
  a.mastery = int(c.setup.mastery)
  a.fixed_cri = float(c.observed.subjectCrit)
  for row in c.setup.equipment:
   a.equips.append({"kind": row.kind, "base": row.baseItemId, "level": row.level, "meta": row.meta})
  var b := ProbeActor.new()
  b.actor_id = 8
  a.hp = 10000; b.hp = 10000; a.mp = 1000; b.mp = 1000; a.tp = 55; b.tp = 55
  var variables: Dictionary = c.setup.variables
  var before := JSON.stringify([a.equips, a.hp, a.mp, b.hp, variables])
  var context := XFormulaContext.capture(a, b, variables, {}, int(item.id), item.damage.formulaProgram)
  var out := XFormulaProgram.evaluate(item.damage.formulaProgram, context, int(item.damage.type))
  check(c.id + ".source", item.damage.formulaProgram.source.sha256 == c.observed.formulaSHA256)
  check(c.id + ".value", out.available and is_equal_approx(float(out.value), float(c.observed.value)) and out.sourceValueKind == c.observed.valueKind, [out, c.observed])
  check(c.id + ".level", XEquipmentView.first_armor_level(a.equip_list(), int(item.damage.formulaProgram.steps[0].steps[0].value.value)) == c.observed.firstLevel)
  check(c.id + ".preview", before == JSON.stringify([a.equips, a.hp, a.mp, b.hp, variables]) and out.randomDraws == 0)
 check("all24", ids.size() == 24)
 print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
 get_tree().quit(0 if failures.is_empty() else 1)
