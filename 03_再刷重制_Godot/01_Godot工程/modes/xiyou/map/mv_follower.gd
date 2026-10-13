class_name MVFollower
extends MVCharacter
## 队伍跟随（MV Game_Follower）：System 勾选「显示队伍跟随」时，出战成员第 2～5 人跟在玩家后面。
## 玩家每走一步前，从最后一个开始各自追前一个人（chaseCharacter：同行同列走直线，否则斜走），速度跟玩家一致；
## 穿透、不挡路；透明跟着玩家。场所移动时全部叠到玩家脚下、朝向相同（synchronize）。

var member_index := 1


func _init() -> void:
	through = true


## Game_Follower.refresh：对应的出战成员不存在时不显示
func refresh_image() -> void:
	var members := XState.current.battle_members() if XState.current else []
	if member_index < members.size():
		var a: XActor = members[member_index]
		set_image(str(a.data().characterName), int(a.data().characterIndex))
	else:
		set_image("", 0)


## Game_Follower.chaseCharacter
func chase(target: MVCharacter, speed: int) -> void:
	var sx := grid.x - target.grid.x
	var sy := grid.y - target.grid.y
	if sx != 0 and sy != 0:
		set_direction(4 if sx > 0 else 6)
		grid += Vector2i(-1 if sx > 0 else 1, -1 if sy > 0 else 1)
	elif sx != 0:
		set_direction(4 if sx > 0 else 6)
		grid += Vector2i(-1 if sx > 0 else 1, 0)
	elif sy != 0:
		set_direction(8 if sy > 0 else 2)
		grid += Vector2i(0, -1 if sy > 0 else 1)
	move_speed = speed


func synchronize(at: Vector2i, d: int) -> void:
	locate(at.x, at.y)
	direction = d
	queue_redraw()
