extends SceneTree
## 测试公共启动（并行测试.py 用 -s 挂上，每个测试场景都经过它；哪吒_10）：场景加载前把神秘生物刷新的真实时钟
## （XPetCapture.clock，每小时 0～4、30～34 分是刷新窗口）固定到窗口外，免得打开真地图的测试碰上整点／半点多弹一条
## 「天生异象……」而偶发（xiyou_book_capacity_ui 10-30 07:30）。要刷新的测试（xiyou_pet_capture）自己再设。
## 不写 class_name、运行时 load：-s 脚本在全局类与自动加载就绪前编译，直接引用 XPetCapture 会编译失败。
## 退出时清掉：静态变量里留着本对象的 lambda，SceneTree 释放后再析构会崩（退出码 134）。

const FIXED := {"day": 1, "hour": 12, "minute": 15}

var _pet_capture: Script


func _initialize() -> void:
	_pet_capture = load("res://modes/xiyou/core/pet_capture.gd")
	_pet_capture.set("clock", func(): return FIXED)


func _finalize() -> void:
	_pet_capture.set("clock", Callable())
