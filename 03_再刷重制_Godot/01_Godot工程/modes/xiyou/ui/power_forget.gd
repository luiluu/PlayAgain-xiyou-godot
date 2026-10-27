class_name XPowerForget
extends Control
## Native Honghuang openPowerForget: per-book paid removal; no old-MV-save migration.
signal closed
var choice: XChoiceWindow
var log: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	choice = XChoiceWindow.new()
	add_child(choice)
	actors()

func choose(rows: Array, ok: Callable, cancel: Callable, info: Array) -> void:
	var lines := XOrbShop.wrap_info(info)
	log.append({"info":lines,"rows":rows.map(func(r): return {"label":str(r.label),"enabled":r.get("enabled",true) != false})})
	choice.open(rows,ok,cancel,lines)

func back() -> void:
	closed.emit()

func actors() -> void:
	var rows := []
	for a in XState.current.members():
		var n := XPowerBooks.learned(a).size()
		rows.append({"actor":a,"label":a.display_name()+"  %d / %d" % [n,XPowerBooks.limit(a)],"enabled":n > 0})
	choose(rows,func(r): skills(r.actor),back,["权能遗忘符","选择角色；每遗忘一本消耗1枚，不返还书","剩余道具："+str(XState.current.item_count(3044))])

func skills(a: XActor) -> void:
	var ids := XPowerBooks.learned(a)
	var rows := ids.map(func(id): return {"id":id,"label":str(XDB.rec("Skills",id).name)})
	choose(rows,func(r): confirm(a,int(r.id)),actors,[a.display_name()+" · "+XPowerBooks.actor_class(a),"已学权能 %d / %d" % [ids.size(),XPowerBooks.limit(a)],"选择想要遗忘的一项权能"])

func confirm(a: XActor, id: int) -> void:
	choose([{"yes":true,"label":"消耗1枚，遗忘这项权能"},{"label":"取消"}],func(r):
		if not r.get("yes",false):
			skills(a)
			return
		var result := XPowerBooks.forget_paid(XState.current,a,id)
		var title: String = "遗忘完成："+a.display_name()+" · "+str(XDB.rec("Skills",id).name) if result.ok else str(result.reason)
		choose([{"label":"返回物品"}],func(_row): back(),back,[title,"剩余权能：%d / %d" % [XPowerBooks.learned(a).size(),XPowerBooks.limit(a)]])
	,func(): skills(a),["确认遗忘 · "+a.display_name(),str(XDB.rec("Skills",id).name),"消耗1枚权能遗忘符，不返还权能书"])
