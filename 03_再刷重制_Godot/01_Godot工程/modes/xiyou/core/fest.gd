class_name XFest
extends RefCounted
## 【cc·未经审查】冠军庆典限时活动的总开关与日期（Kyo 11-15；方案：私密设计仓 重制设定/冠军庆典活动_v0.2.md）。
## 活动各模块（甲车道冠军之路 XFestRoad、乙车道大厅庆典叠加层、第 2 天的签到／兑换／成就／彩蛋）都只读这里，不各自判断日期。
## 时间只看本机日期（游戏没有服务器时间）；改本机时间能提前或延后，单机防不住、奖励也不值钱，不做防护（方案 2.4）。
##
## 三个阶段（D20 Kyo 11-15 定开半个月：15 天＋3 天收尾；改 START／DAYS／GRACE_DAYS 即可）：
## - 进行中 active()：START 起 DAYS 天（含 START 当天）。大厅装饰、使者、冠军之路、签到都开。
## - 收尾期 in_grace()：之后 GRACE_DAYS 天。只留使者兑换（方案第 4 节「没花完的庆典币留 3 天」），冠军之路、装饰、签到都关。
## - 结束：都关；已拿到的称号永久保留（称号表照常列，见 XDesignation.table）。
## 开关 ENABLED＝false：活动整件不存在（不出 NPC、不进冠军之路、称号表不列庆典称号、伤害加成不生效），回到没有活动时的样子。O-待定。

static var ENABLED := true

## 活动开始日（本机日期，含当天）。补丁哪天推，Kyo 定；默认 11-15（Kyo 拍板做庆典的当天）
static var START := "2026-11-16"
## 进行天数（D20 Kyo 11-15 定：半个月）
static var DAYS := 15
## 收尾天数（D20 推荐 3 天）
static var GRACE_DAYS := 3

## 测试与调试用：非空时当作「今天」（格式 YYYY-MM-DD），不读本机时钟
static var TODAY_OVERRIDE := ""

## 贺词：真实名称只出现这一处（方案第 5 节）
const CONGRATS := "恭喜 BLG 夺得 2026 全球总决赛冠军"

## 庆典称号编号（XDesignation 表里接在原版 1～30、kyo 专属 31 之后；全局解锁、所有存档共用、永久；称号都不带数值）
## 41～44 的编号不能变（v0.3.1 第 7 节第 1 条）。45「冠军之路·洪荒」是改三档前分支里的，没发给玩家过，并进 41（读档时手里有 45 的补成 41，见 XFestReward），不再列、不再发。
const TITLE_ROAD := 41        # 冠军之路：任一档四关全胜（XFestRoad 发）
const TITLE_ONE_FOUR := 42    # 一穿四（金）：欢庆档一次不败连穿四关（XFestRoad 发）
const TITLE_WATCH := 43       # 冠军观赛团：兑换店 100 币；天启篇存档由使者直接送（XFestReward）
const TITLE_ATTEND := 44      # 全勤观众：签到累计满 3 天（XFestReward）
const TITLE_ROAD_HARD := 45   # 已并进 41，只留编号做迁移
const TITLE_ONE_FOUR_HARD := 46  # 一穿四·洪荒（金红）：洪荒档一次不败连穿
const TITLE_ONE_FOUR_DISASTER := 47  # 一穿四·天灾（橙）：天灾档一次不败连穿
const TITLES := [
	{"id": TITLE_ROAD, "name": "冠军之路", "icon": 6420, "color": "#f5f7fa"},
	{"id": TITLE_ONE_FOUR, "name": "一穿四", "icon": 6421, "color": "#ffd700"},
	{"id": TITLE_WATCH, "name": "冠军观赛团", "icon": 6424, "color": "#00bfff"},
	{"id": TITLE_ATTEND, "name": "全勤观众", "icon": 6425, "color": "#00ff00"},
	{"id": TITLE_ONE_FOUR_DISASTER, "name": "一穿四·天灾", "icon": 6422, "color": "#ff8c00"},
	{"id": TITLE_ONE_FOUR_HARD, "name": "一穿四·洪荒", "icon": 6423, "color": "#ff4500"},
]

## 存档里活动数据都放在 flags 这一个键下（每个存档各算各的）：{"coins": 庆典币, "road": 冠军之路进度, …}；旧档没有就当空
const FLAG_KEY := "fest_champion"


## 本机今天，YYYY-MM-DD
static func today() -> String:
	if TODAY_OVERRIDE != "":
		return TODAY_OVERRIDE
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


## 日期字符串转「从 1970-01-01 起第几天」；格式不对返回 -1
static func day_number(date: String) -> int:
	var parts := date.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return -1
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12, "minute": 0, "second": 0})
	return int(floor(unix / 86400.0))


## 今天是活动第几天（START 当天＝1）；START 之前为 0 或负数；START 写错返回 -9999
static func day_index() -> int:
	var s := day_number(START)
	var t := day_number(today())
	if s < 0 or t < 0:
		return -9999
	return t - s + 1


## 活动进行中
static func active() -> bool:
	if not ENABLED:
		return false
	var i := day_index()
	return i >= 1 and i <= DAYS


## 收尾期（只留兑换）
static func in_grace() -> bool:
	if not ENABLED:
		return false
	var i := day_index()
	return i > DAYS and i <= DAYS + GRACE_DAYS


## 进行中或收尾期（使者还在）
static func visible() -> bool:
	return active() or in_grace()


## 本存档的活动数据（没有就建一个空的；s 为空返回临时空表）
static func data(s) -> Dictionary:
	if s == null:
		return {}
	if not s.flags.get(FLAG_KEY) is Dictionary:
		s.flags[FLAG_KEY] = {}
	return s.flags[FLAG_KEY]


## 庆典币（存档里的一个数，不占物品编号；方案 2.5）
static func coins(s) -> int:
	return int(data(s).get("coins", 0)) if s != null else 0


static func add_coins(s, n: int) -> void:
	if s == null:
		return
	var d := data(s)
	d["coins"] = max(0, int(d.get("coins", 0)) + n)


## 解锁庆典称号（全局，所有存档共用）；开关关着不发
static func unlock_title(id: int) -> void:
	if ENABLED and TITLES.any(func(t): return int(t.id) == id):
		XDesignation.unlock(id)
