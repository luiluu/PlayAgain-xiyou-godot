class_name XBattleStream
extends RefCounted
## T225 多段技能逐段结算（O-待定）：画面演到哪一段才结算哪一段，开招那一帧不再一次算完全部段数。
##
## 做法：行动的结算（XBattleLogic.act）照旧是同一份同步代码、同一个先后顺序，只是放到一条交接线程上跑，
## 根序列（主行动 execute 里的 XActionSequence）每条 ACTION EFFECT 之前停下（gate），等画面要下一段时（pull）再往下算。
## 两条线程严格轮流：画面等着逻辑算这一段，逻辑停着时画面才动，同一时刻只有一边在跑，结算的先后与一次算完完全相同，
## 所以结果（伤害、随机数、状态、日志）不变，只是摊到了各段的帧上。
## 记录：act → execute → 根序列三层各自的记录数组按引用登记在 parts，拼起来就是「到此为止」的记录前缀；
## 前缀只追加不改写，画面拿到的 out 永远是最终 act 返回值的前缀（不是就报错，见 _collect）。
## 回退：PER_SEGMENT = false（战斗画面照旧一次算完再演）。无界面测试、回放、参照对照不走这里。

## false＝回退：开招那一帧一次算完全部段数（T225 之前）
static var PER_SEGMENT := true

var logic
## 画面已拿到的记录（最终 act 返回值的前缀，只追加）
var out: Array = []
## 逻辑线程上正在累积的各层记录（act、execute、根序列的 logs，按引用）
var parts: Array = []
var done := false
## 停过几次（每次＝根序列的一条 ACTION EFFECT）
var gates := 0
## 前缀对不上的次数（应为 0）
var mismatches := 0
## 量数（专项用）：开招那一帧在逻辑上花的微秒（算到第一段之前）、单次 pull 最多花的微秒、pull 次数
var start_usec := 0
var max_pull_usec := 0
var pulls := 0
var _result: Array = []
var _thread: Thread
var _to_logic := Semaphore.new()
var _to_main := Semaphore.new()
var _args: Array = []


## 开一次行动：先算到第一段之前（或整次行动算完）再返回
static func start(l, u, skill, target) -> XBattleStream:
	var s := XBattleStream.new()
	s.logic = l
	s._args = [u, skill, target]
	l._stream = s
	var t0 := Time.get_ticks_usec()
	s._thread = Thread.new()
	s._thread.start(s._run)
	s._to_main.wait()
	s._collect()
	s.start_usec = Time.get_ticks_usec() - t0
	return s


func _run() -> void:
	var r = logic.act(_args[0], _args[1], _args[2])
	_result = r if r is Array else []
	done = true
	_to_main.post()


## 逻辑线程：根序列的一条 ACTION EFFECT 之前停下，把已经算出的记录交给画面，等画面要下一段
func gate() -> void:
	if done or _thread == null or OS.get_thread_caller_id() == OS.get_main_thread_id():
		return
	gates += 1
	_to_main.post()
	_to_logic.wait()


## 画面：再往下结算一段（到下一条 ACTION EFFECT 之前，或整次行动结束）。已经结束返回 false
func pull() -> bool:
	if done:
		return false
	var t0 := Time.get_ticks_usec()
	_to_logic.post()
	_to_main.wait()
	_collect()
	pulls += 1
	max_pull_usec = maxi(max_pull_usec, Time.get_ticks_usec() - t0)
	return true


## 剩下的一次算完，收线程
func finish() -> void:
	while pull():
		pass
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if logic != null and logic._stream == self:
		logic._stream = null


func _collect() -> void:
	var full: Array = _result
	if not done:
		full = []
		for p in parts:
			full.append_array(p)
	if full.size() < out.size() or (not out.is_empty() and not is_same(full[out.size() - 1], out[out.size() - 1])):
		mismatches += 1
		push_error("XBattleStream：记录前缀对不上（%d → %d 条）" % [out.size(), full.size()])
		return
	out.append_array(full.slice(out.size()))
