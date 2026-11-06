extends SceneTree
## 逐张核对：游戏里读到的贴图（导入后的 .ctex）解出来的像素，与源图（PNG／JPG）直接解码的像素是否完全相同。
## 用法：godot --headless --path <工程> --script <本文件> -- <工程内目录，如 modes/xiyou/generated/img> [更多目录…]
## 输出：TEXTURE_CHECK={"files":…, "same":…, "diff":[…], "ctexBytes":…, "sourceBytes":…, "ctexFormats":{…}}

func _init() -> void:
	var dirs := OS.get_cmdline_user_args()
	var files: Array[String] = []
	for d in dirs:
		_walk("res://" + d.trim_suffix("/"), files)
	var same := 0
	var fixed := 0
	var diff: Array = []
	var ctex_bytes := 0
	var source_bytes := 0
	var formats := {}
	for path in files:
		source_bytes += FileAccess.get_file_as_bytes(path).size()
		var cfg := ConfigFile.new()
		if cfg.load(path + ".import") == OK:
			var imported := str(cfg.get_value("remap", "path", ""))
			if imported != "":
				var head := FileAccess.get_file_as_bytes(imported)
				ctex_bytes += head.size()
				var kind := "webp" if head.slice(0, 256).get_string_from_ascii().contains("WEBP") or _find(head, "WEBP".to_ascii_buffer()) else ("png" if _find(head, PackedByteArray([0x89, 0x50, 0x4E, 0x47])) else "other")
				formats[kind] = int(formats.get(kind, 0)) + 1
		var tex := load(path) as Texture2D
		var src := Image.load_from_file(ProjectSettings.globalize_path(path))
		if tex == null or src == null:
			diff.append([path, "读不出"])
			continue
		var img := tex.get_image()
		if img.get_size() != src.get_size():
			diff.append([path, "尺寸不同"])
			continue
		if src.get_format() != img.get_format():
			src.convert(img.get_format())
		if src.get_data() == img.get_data():
			same += 1
		elif _fixed_same(src, img):  # 导入的 process/fix_alpha_border：全透明像素的颜色被改成邻近色，看得见的像素不变
			same += 1
			fixed += 1
		else:
			diff.append([path, "像素不同"])
	print("TEXTURE_CHECK=" + JSON.stringify({"files": files.size(), "same": same, "diff": diff.slice(0, 50), "diffCount": diff.size(), "sameAfterAlphaBorder": fixed,
		"ctexBytes": ctex_bytes, "sourceBytes": source_bytes, "ctexFormats": formats}))
	quit(0 if diff.is_empty() else 1)


func _fixed_same(src: Image, img: Image) -> bool:
	var a := src.duplicate() as Image
	if a.detect_alpha() == Image.ALPHA_NONE:
		return false
	a.fix_alpha_edges()
	return a.get_data() == img.get_data()


func _find(data: PackedByteArray, needle: PackedByteArray) -> bool:
	var n := mini(data.size(), 512) - needle.size()
	for i in maxi(n, 0):
		if data.slice(i, i + needle.size()) == needle:
			return true
	return false


func _walk(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), out)
