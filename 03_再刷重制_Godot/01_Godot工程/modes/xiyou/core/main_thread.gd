class_name XMainThread
extends RefCounted
## 【cc·T225·未经审查】界面入口的线程保险。
## 战斗画面的行动结算（XBattleStream）在交接线程上跑；结算本身是同步的 RefCounted 代码、不持有节点，
## 能碰到场景树的只有一组静态界面入口（提示、成就弹窗、至臻闪光、技能升级通告、自动存档小字、战力提示、界面音效…）。
## 这些入口开头调 defer：不在主线程就把这次调用排到主线程（call_deferred，Godot 的消息队列跨线程安全）再返回 true，
## 入口直接 return；在主线程返回 false，照原样往下走。要返回节点的入口（只该在主线程调）用 require：不在主线程报错。
## 排查清单见交付单 luiluu_t225.md「结算线程能碰到场景树的入口」。

## 被转回主线程的次数（专项核对用）
static var deferred := 0
## require 报错的次数（专项核对用，应为 0）
static var violations := 0


static func is_main() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()


## 不在主线程：把 c（带好参数的 Callable）排到主线程，返回 true（调用方直接 return）
static func defer(c: Callable) -> bool:
	if is_main():
		return false
	deferred += 1
	c.call_deferred()
	return true


## 只该在主线程调的入口：不在主线程报错，返回 false（调用方不要再碰场景树）
static func require(where: String) -> bool:
	if is_main():
		return true
	violations += 1
	push_error("XMainThread：%s 只能在主线程调（当前在结算线程）" % where)
	return false
