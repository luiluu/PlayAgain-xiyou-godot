extends Node
## T578 图标取图微基准（只量不改）：XUI.icon_texture 在「没人攥着图集」和「有人攥着」两种情况下每次多少毫秒；另量 XDB.img_path、face_texture。
## 跑法同 t578_skill_page_probe.gd（复制进 tests/、临时 .tscn），参数 [--release]

func _ready() -> void:
	if "--release" in OS.get_cmdline_user_args():
		ReleaseEntry.simulate_release = true
	_run.call_deferred()


func us(f: Callable, n: int) -> float:
	var t := Time.get_ticks_usec()
	for i in n:
		f.call()
	return float(Time.get_ticks_usec() - t) / n


func _run() -> void:
	var idx := 100  # IconSet_1 普通格
	var n := 30
	print("img_path_us=%.1f" % us(func(): XDB.img_path("system", "IconSet_1"), 200))
	# 不攥着：每次取完就丢（等同画面重画前 _keep.clear() 之后）
	print("icon_cold_us=%.1f" % us(func(): XUI.icon_texture(idx), n))
	# 攥着一份图集
	var hold = XUI.icon_texture(idx)
	print("icon_held_us=%.1f" % us(func(): XUI.icon_texture(idx), n))
	hold = null
	print("icon_cold_again_us=%.1f" % us(func(): XUI.icon_texture(idx), n))
	var p := XDB.img_path("system", "IconSet_1")
	print("path=%s cached_now=%s" % [p.get_file(), str(ResourceLoader.has_cached(p))])
	print("load_cold_us=%.1f" % us(func(): load(p), n))
	get_tree().quit(0)
