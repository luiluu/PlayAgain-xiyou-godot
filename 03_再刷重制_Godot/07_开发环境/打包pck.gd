extends SceneTree
## 把一个目录（安卓 apk 解出的 assets/）原样打成 Godot 资源包 .pck（cc BH 2026-11-05，导出冒烟 --platform android 用）。
## 导出模板只认可执行文件旁的同名 .pck（不认 zip、不认 --main-pack），所以要真打一个 pck。
##   godot --headless --path <空目录> --script 打包pck.gd -- <源目录> <输出.pck>
## 只读源目录、只写输出文件。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("用法：-- <源目录> <输出.pck>")
		quit(2)
		return
	var src: String = args[0].trim_suffix("/")
	var packer := PCKPacker.new()
	if packer.pck_start(args[1]) != OK:
		printerr("写不了 ", args[1])
		quit(2)
		return
	var count := [0]
	if not _add_dir(packer, src, "", count):
		quit(2)
		return
	if packer.flush() != OK:
		printerr("写入失败")
		quit(2)
		return
	print("PCK_FILES=", count[0])
	quit(0)

func _add_dir(packer: PCKPacker, root: String, rel: String, count: Array) -> bool:
	var dir := DirAccess.open(root.path_join(rel))
	if dir == null:
		printerr("打不开 ", root.path_join(rel))
		return false
	dir.include_hidden = true
	for name in dir.get_directories():
		if not _add_dir(packer, root, rel.path_join(name), count):
			return false
	for name in dir.get_files():
		var r := rel.path_join(name)
		if packer.add_file("res://" + r, root.path_join(r)) != OK:
			printerr("加不进 ", r)
			return false
		count[0] += 1
	return true
