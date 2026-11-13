class_name XFontScale
extends RefCounted
## 字体大小（重制新增，Kyo 2026-11-13：v0.01.07 安卓上「肝帝积分 +1」这类弹窗字太小）。设置在「画质设置」子页，
## 存在配置的一个键 codexFontSize（字典）里，两项互不影响，默认都是 100（＝原版字号）：
## - global 全局字号：XMVCanvas.text（MV 窗口里几乎所有文字）、XMVText 逐字排版、XUI.theme／XUI.label 的字号按百分比放大。
##   行高、窗口大小不变；放大后超出 maxWidth 的照原版横向压缩，所以档位只到 130（26 号字放大到 34，仍在 36 的行高里）。
##   另有少数页面自己写死字号的 Label 不跟（如测试页、更新页），只在 MV 画布与共用主题上生效。
## - toast 弹窗字号：XToast（地图／菜单上的 $.toaster 提示）的字号和行高按百分比放大，提示框宽度跟着放宽（最多 1.5 倍）。
## 回退：ENABLED = false 时不论设置都按原版字号，画质设置子页也不列这两行。

static var ENABLED := true

const KEY := "codexFontSize"
const DEFAULTS := {"global": 100, "toast": 100}
const CHOICES := {"global": [100, 110, 120, 130], "toast": [100, 125, 150, 175, 200]}


## 把存盘读回来的值校正成完整的字典（缺项、不在档位里的值按默认）
static func sanitize(saved: Variant) -> Dictionary:
	var out := DEFAULTS.duplicate()
	if saved is Dictionary:
		for k in DEFAULTS:
			var v = saved.get(k)
			if (v is int or v is float) and CHOICES[k].has(int(v)):
				out[k] = int(v)
	return out


## 某一项现在的百分比（关掉回退开关时恒 100）
static func percent(kind: String) -> int:
	if not ENABLED:
		return 100
	return XConfig.font_size_percent(kind)


## 改一项；值变了才存盘，返回是否变了
static func set_value(kind: String, pct: int) -> bool:
	if not CHOICES.has(kind) or not CHOICES[kind].has(pct) or XConfig.font_size_percent(kind) == pct:
		return false
	XConfig.set_font_size_percent(kind, pct)
	return true


static func scaled(base: float, kind := "global") -> float:
	var p := percent(kind)
	return base if p == 100 else base * p / 100.0


## 字号按全局档位放大（取整）
static func size(base: int) -> int:
	var p := percent("global")
	return base if p == 100 else roundi(base * p / 100.0)
