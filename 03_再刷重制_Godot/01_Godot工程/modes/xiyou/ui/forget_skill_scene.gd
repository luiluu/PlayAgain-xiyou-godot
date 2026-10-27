class_name XForgetSkillScene
extends Control
## 技能遗忘（Star_ForgetSkills 的 Star_Scene_ForgetSkill；遗忘河之水 → 公共事件 83 Star.RunForgetSkill()），照冻结 v0.28 原版语义：
## - 角色是用物品时选中的那位（原版 Star.ForgetSkills.NewActor，取自物品选人窗）。
## - 打开时列出该角色已学技能（_skills，按编号）里技能类型 1、2、5 的；每行右侧「未遗忘／已遗忘」。
## - 确定：未遗忘的遗忘、已遗忘的重新学会，状态翻转，列表不变；取消关闭。
## 外观暂用通用选择窗（XChoiceWindow），原版是居中 400 宽的命令窗，界面对照留给界面车道。
signal closed

const TYPES := [1, 2, 5]
var actor: XActor
var choice: XChoiceWindow
var rows: Array = []


static func listed_skills(a: XActor) -> Array:
	return a.skill_ids.filter(func(id): return TYPES.has(int(XDB.rec("Skills", id).get("stypeId", 0))))


func setup(a: XActor) -> XForgetSkillScene:
	actor = a
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	choice = XChoiceWindow.new()
	add_child(choice)
	rows = listed_skills(actor).map(func(id): return {"id": id, "kept": true})
	_open(0)


func _open(at: int) -> void:
	var list := rows.map(func(r): return {"id": r.id, "label": "%s    %s" % [str(XDB.rec("Skills", r.id).get("name", "")), "未遗忘" if r.kept else "已遗忘"]})
	choice.open(list, _toggle, func(): closed.emit())
	choice.index = clampi(at, 0, maxi(0, list.size() - 1))
	choice.top = XMenu._scroll_to(choice.index, 0, choice.page_rows())
	choice._refresh()


func _toggle(row: Dictionary) -> void:
	var at := rows.find_custom(func(r): return r.id == row.id)
	var r: Dictionary = rows[at]
	toggle(actor, r)
	_open(at)


## processOk：未遗忘的遗忘、已遗忘的学会，再翻转
static func toggle(a: XActor, r: Dictionary) -> void:
	if r.kept:
		a.forget_skill(int(r.id))
	else:
		a.learn_skill(int(r.id))
	a.refresh_passive()
	r.kept = not r.kept
