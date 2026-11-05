class_name ReleaseEntry
extends RefCounted
## 正式入口（BI，Kyo 2026-11-05「游戏需要一个正式入口」；O-待定）。
## 发行构建（导出时用 release 模板，OS.is_debug_build() 为 false）启动直接进西游标题，
## 不经过模式选择；调试构建（编辑器、测试、「macOS 验收」包）照旧先到入口菜单。
## 只按构建类型区分，不认命令行参数。
## 应用名「再刷一把：天启篇」是 Kyo 2026-11-05 16:06 指定的，所有平台发行包同名（取代原版名）。

const APP_NAME := "再刷一把：天启篇"
const DIRECT_MODE := "xiyou"

## O-待定 开关：false 回退为发行构建也先显示入口菜单（重制原样）。
static var direct_title := true
## 只给测试用：把调试构建当成发行构建跑，验证发行分支。
static var simulate_release := false


static func is_release() -> bool:
	return simulate_release or not OS.is_debug_build()


## 发行构建是否跳过入口菜单、直达西游标题。
static func skips_menu() -> bool:
	return direct_title and is_release()
