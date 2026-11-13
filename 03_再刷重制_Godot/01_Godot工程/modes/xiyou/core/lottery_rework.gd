class_name XLotteryRework
extends RefCounted
## 抽奖重构（法宝与积分重构方案 v0.2 第四节，Kyo 11-13 通过）。只管抽奖类公共事件：
## 1431 小欧皇 20 连、1432 小欧皇（大厅希禾单抽）、1433 欧皇活动、1434 未知存在胜利后的深渊赌场。
##
## O-待定（SAVED_STREAM）：这几个事件里「变量 = 随机」都改用一条单独的随机流，种子和进度存进存档（XState.lottery_random）。
##   原版用 Math.random，重制原先用世界随机流（不进存档），读档后能重抽；现在读档后同一抽结果相同，做别的事也不推进它。
##   固定随机（MVInterpreter.fixed_random／random_sequence，参照对照用）时照旧走固定值。
## O-待定（EV_NOT_POSITIVE）：一抽的期望从正调到零或略负，二阶段照样高风险（模拟器 6 万抽、减免变量 1186 取 0／200／400）：
##   1432 一阶段 −400～600 → −500～500，二阶段附加 −300～850 → −650～500：期望 ＋164 → −6～−17；
##   1431 一阶段 −8000～12500 → −10250～10250，二阶段附加 −5000～9000 → −9000～5000：＋2809 → −40～−80；
##   1434 一阶段与二阶段附加 −300～330 → −315～315：＋17 → 0；
##   1433 二阶段格子 −350～380／−350～500 → −365～365／−425～425、附加 −50～60 → −55～55：＋11 → 0。
##   对话框里写的范围同步改。只换下表列出的（下限, 上限）组合，别的随机（选格子、星神瞥视）不动。
## 回退：`XLotteryRework.SAVED_STREAM = false`（回世界随机流）；`XLotteryRework.EV_NOT_POSITIVE = false`（原版范围与文字）。

static var SAVED_STREAM := true
static var EV_NOT_POSITIVE := true

const EVENTS := [1431, 1432, 1433, 1434]

## 事件 → {"下限,上限": [新下限, 新上限]}
const RANGES := {
	1432: {"-400,600": [-500, 500], "-300,850": [-650, 500]},
	1431: {"-8000,12500": [-10250, 10250], "-5000,9000": [-9000, 5000]},
	1434: {"-300,330": [-315, 315]},
	1433: {"-350,380": [-365, 365], "-350,500": [-425, 425], "-50,60": [-55, 55]},
}
## 事件 → {原文片段: 新片段}（401 文字）
const TEXTS := {
	1432: {"-400~+600": "-500~+500", "-1800~+2500": "-2150~+2150"},
	1431: {"-8000~+12500": "-10250~+10250", "-35000~+43000": "-39000~+39000"},
	1434: {"-300~+330": "-315~+315", "-3000~+3000": "-3015~+3015"},
}


static func is_lottery(ce_id: int) -> bool:
	return EVENTS.has(ce_id)


## 换范围：返回 [lo, hi]
static func remap(ce_id: int, lo: int, hi: int) -> Array:
	if not EV_NOT_POSITIVE:
		return [lo, hi]
	var r = RANGES.get(ce_id, {}).get("%d,%d" % [lo, hi])
	return [int(r[0]), int(r[1])] if r != null else [lo, hi]


static func text(ce_id: int, line: String) -> String:
	if not EV_NOT_POSITIVE:
		return line
	for k in TEXTS.get(ce_id, {}):
		if line.contains(k):
			line = line.replace(k, TEXTS[ce_id][k])
	return line


## 抽奖用的随机流（存档里存种子与状态）；没有存档对象或开关关了返回 null
static func stream(s: XState) -> RandomNumberGenerator:
	if not SAVED_STREAM or s == null:
		return null
	if s._lottery_rng == null:
		var rng := RandomNumberGenerator.new()
		var saved: Dictionary = s.lottery_random
		if saved.get("seed") is String and XRandomStream.valid_hex(saved.seed) and saved.get("state") is String and XRandomStream.valid_hex(saved.state):
			rng.seed = XRandomStream.parse64(saved.seed)
			rng.state = XRandomStream.parse64(saved.state)
		else:
			var seed_hex := XRandomStream.fresh_seed()
			rng.seed = XRandomStream.parse64(seed_hex)
			saved = {"seed": seed_hex, "draws": 0}
		s._lottery_rng = rng
		s.lottery_random = saved
	return s._lottery_rng


## 抽奖事件里的「变量 = 随机 lo～hi」
static func roll(s: XState, lo: int, hi: int) -> int:
	var rng := stream(s)
	var v := rng.randi_range(lo, hi)
	s.lottery_random.state = XRandomStream.hex64(rng.state)
	s.lottery_random.draws = int(s.lottery_random.get("draws", 0)) + 1
	return v
