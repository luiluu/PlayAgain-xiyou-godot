class_name XVersionLabel
extends CanvasLayer
## 右下角版本号（Kyo 2026-11-06「正式版右下角也显示版本号」）：读 project.godot 的 config/version（开发编号，如 dev.377），
## 所有构建（调试、验收、发行）所有页面都显示，半透明小字、不挡鼠标和触屏。
## 回退开关 SHOW = false：不建这个节点。

static var SHOW := true
const MARGIN := Vector2(10, 6)
const FONT_SIZE := 14

var label: Label


static func version_text() -> String:
	# 发行构建有发行版本名（build_info releaseVersion，Kyo 11-11 整包 v0.01）时显示它，补丁是 v0.01.<多几号>；开发版照旧显示开发编号
	if ReleaseEntry.is_release() and XUpdateClient.release_version() != "":
		XUpdateClient.init_versions()
		return "v" + XUpdateCheck.version_of(XUpdateClient.current_code())
	return str(ProjectSettings.get_setting("application/config/version", ""))


func _ready() -> void:
	layer = 125  # 高于触屏按键（120）
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.text = version_text()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GameFont.current())
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -MARGIN.x
	label.offset_bottom = -MARGIN.y
	add_child(label)
