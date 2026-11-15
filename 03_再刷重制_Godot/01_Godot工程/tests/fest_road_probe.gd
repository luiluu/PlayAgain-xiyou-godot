class_name XFestRoadProbe
extends RefCounted
## 测试替身：冠军之路入口（XFestRoad）合进来之前，xiyou_fest_lobby 用它验证「入口开放后报名处走真入口、称号表全列」。只在测试里把 XFestLobby.ROAD_CLASS 指到这里。
static var ENABLED := true
static var entered := 0


static func enter(_interp) -> void:
	entered += 1
