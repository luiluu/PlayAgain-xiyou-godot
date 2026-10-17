class_name GameFont
extends RefCounted
## 当前西游正式版 installDisplayPreferencesRuntime 指定的用户字体。
## 字体原件由转换器只读复制，所有文字界面共用，避免标题入口与西游页面各自回落。
const PATH := "res://modes/xiyou/generated/fonts/FZLanTYJW_ZhongCu.TTF"
static var _font: Font

static func current() -> Font:
	if _font == null:
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei UI", "sans-serif"])
		# 导出后字体会重映射到导入资源，FileAccess／load_dynamic_font 读原始 TTF 会漏掉它。
		if ResourceLoader.exists(PATH):
			var font := load(PATH) as FontFile
			if font != null:
				font.fallbacks = [fallback]
				_font = font
		if _font == null:
			_font = fallback
	return _font
