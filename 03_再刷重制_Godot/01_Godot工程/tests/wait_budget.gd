extends RefCounted
## 测试里「等地图就绪／等事件跑完」的超时（tools30）：原来只看墙钟（90 秒），并行满负载时帧数少、事件还在正常推进就被判失败
## （10-31 第四批收尾 map186、_legions、_legions_b：负载约 27，军团战没打完就到点）。
## 现在要两条都过了才算超时：墙钟过了 limit_ms，而且帧数（Engine.get_process_frames）也过了 limit_ms 按 60 帧/秒折成的帧数。
## 慢机器帧少，自然多等；快机器帧多，仍按墙钟到点。给了进度签名时，签名一变就从头计（事件还在推进就续等），
## 签名一直不变、两条都过了才算卡住，照样判失败（场景 600 秒上限兜底）。
## 用法（循环体不用改）：var w := WaitBudget.new(TIMEOUT_MS)；while not st.done and w.waiting(签名):（循环里照旧 await 一帧）。
## 回退：WaitBudget.USE_FRAMES = false 回到只看墙钟。

static var USE_FRAMES := true
const FPS := 60.0

var limit_ms := 0
var limit_frames := 0
var _since_ms := 0
var _since_frame := 0
var _sig = null


func _init(timeout_ms: int) -> void:
	limit_ms = timeout_ms
	limit_frames = int(timeout_ms / 1000.0 * FPS)
	_since_ms = Time.get_ticks_msec()
	_since_frame = Engine.get_process_frames()


## 还没超时就返回 true。signature 给了且与上次不同就重新计时
func waiting(signature = null) -> bool:
	if signature != null and signature != _sig:
		_sig = signature
		_since_ms = Time.get_ticks_msec()
		_since_frame = Engine.get_process_frames()
	var ms_out := Time.get_ticks_msec() - _since_ms >= limit_ms
	var frames_out := Engine.get_process_frames() - _since_frame >= limit_frames
	return not (ms_out and (frames_out or not USE_FRAMES))
